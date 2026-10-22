//! The UCI loop (AGENTS.md §9.2): the main thread reads commands; each `go`
//! runs on one search thread, which polls the stop / ponderhit atomics at the
//! original's key-poll point. `isready` is answered at once, even while
//! searching; commands that change the engine's state wait for the search.

const std = @import("std");
const engine_mod = @import("engine.zig");
const Engine = engine_mod.Engine;
const uci_parse = @import("uci_parse.zig");
const pipe_io = @import("pipe_io.zig");

/// Standard output shared by both threads: one line at a time, flushed.
const StdOut = struct {
    io: std.Io,
    mutex: std.Io.Mutex = .init,
    stdout: pipe_io.Stdout = undefined,

    fn output(o: *StdOut) engine_mod.Output {
        return .{ .ctx = o, .lineFn = lineFn };
    }

    fn lineFn(ctx: ?*anyopaque, text: []const u8) void {
        const o: *StdOut = @ptrCast(@alignCast(ctx.?));
        o.mutex.lockUncancelable(o.io);
        defer o.mutex.unlock(o.io);
        o.stdout.line(text) catch return;
    }
};

/// The engine's commands (`setoption`, `ucinewgame`, `position`, `go`) run in
/// order on one worker thread, which owns the Engine; a `go` runs to the end
/// before the next command (scripts may send `go depth N` and the next
/// `position` at once). The input thread never waits for them (code review
/// CR-05), so `stop`, `ponderhit`, `isready` and `quit` act at once even
/// while a search runs or commands are queued behind it.
const Worker = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    e: *Engine,
    out: *StdOut,
    mutex: std.Io.Mutex = .init,
    cond: std.Io.Condition = .init,
    /// Raw command lines, owned (the reader's buffer is reused).
    queue: std.ArrayList(Job) = .empty,
    quitting: bool = false,
    /// Signals of the running `go`.
    sig: engine_mod.Signals = .{},
    /// `go` sequence numbers: the newest queued, the running one (0 = none),
    /// and the newest that `stop` / `ponderhit` have reached.
    queued_go: u64 = 0,
    running_go: u64 = 0,
    stopped_go: u64 = 0,
    ponderhit_go: u64 = 0,
    /// The newest queued `go` holds its `bestmove` (`infinite` / `ponder`).
    queued_go_holds: bool = false,

    const Job = struct {
        line: []u8,
        /// For a `go`: its sequence number.
        go_id: u64 = 0,
    };

    /// Queue an engine command. A `go` that only `stop` would end
    /// (`infinite`, `ponder`) is stopped by any later engine command: a GUI
    /// sending one has abandoned that search.
    fn push(w: *Worker, line: []const u8, is_go: bool, holds: bool) !void {
        const copy = try w.gpa.dupe(u8, line);
        errdefer w.gpa.free(copy);
        w.mutex.lockUncancelable(w.io);
        defer w.mutex.unlock(w.io);
        if (w.queued_go_holds) w.stopLocked();
        var job: Job = .{ .line = copy };
        if (is_go) {
            w.queued_go += 1;
            job.go_id = w.queued_go;
            w.queued_go_holds = holds;
        } else {
            w.queued_go_holds = false;
        }
        try w.queue.append(w.gpa, job);
        w.cond.signal(w.io);
    }

    /// `stop`: the running `go` and any queued before this point.
    fn stopLocked(w: *Worker) void {
        w.stopped_go = w.queued_go;
        if (w.running_go != 0) w.sig.stop.store(true, .release);
    }

    fn stop(w: *Worker) void {
        w.mutex.lockUncancelable(w.io);
        defer w.mutex.unlock(w.io);
        w.stopLocked();
    }

    fn ponderhit(w: *Worker) void {
        w.mutex.lockUncancelable(w.io);
        defer w.mutex.unlock(w.io);
        w.ponderhit_go = w.queued_go;
        if (w.running_go != 0) w.sig.ponderhit.store(true, .release);
    }

    /// Whether a `go` is running or queued (then `isready` is answered at
    /// once, as UCI allows during a search; otherwise after the queue).
    fn busy(w: *Worker) bool {
        w.mutex.lockUncancelable(w.io);
        defer w.mutex.unlock(w.io);
        if (w.running_go != 0) return true;
        for (w.queue.items) |j| if (j.go_id != 0) return true;
        return false;
    }

    /// `quit`: stop the search, drop the queue. End of input (`drop` false):
    /// stop every search but still run the queue, so that each `go` piped
    /// in gets its `bestmove`.
    fn quit(w: *Worker, drop: bool) void {
        w.mutex.lockUncancelable(w.io);
        defer w.mutex.unlock(w.io);
        w.quitting = true;
        w.stopLocked();
        if (drop) {
            for (w.queue.items) |j| w.gpa.free(j.line);
            w.queue.clearRetainingCapacity();
        }
        w.cond.signal(w.io);
    }

    fn main(w: *Worker) void {
        while (true) {
            w.mutex.lockUncancelable(w.io);
            while (w.queue.items.len == 0 and !w.quitting) w.cond.waitUncancelable(w.io, &w.mutex);
            if (w.queue.items.len == 0) {
                w.mutex.unlock(w.io);
                return;
            }
            const job = w.queue.orderedRemove(0);
            if (job.go_id != 0) {
                w.sig = .{};
                w.running_go = job.go_id;
                if (job.go_id <= w.stopped_go) w.sig.stop.store(true, .release);
                if (job.go_id <= w.ponderhit_go) w.sig.ponderhit.store(true, .release);
            }
            w.mutex.unlock(w.io);
            defer w.gpa.free(job.line);
            w.execute(job.line) catch |err| {
                w.out.output().print("info string error: {s}", .{@errorName(err)});
            };
            if (job.go_id != 0) {
                w.mutex.lockUncancelable(w.io);
                w.running_go = 0;
                w.mutex.unlock(w.io);
            }
        }
    }

    fn execute(w: *Worker, line: []const u8) !void {
        const e = w.e;
        const cmd = uci_parse.parse(line) catch {
            const trimmed = std.mem.trim(u8, line, " \r\n\t");
            if (std.mem.startsWith(u8, trimmed, "position")) {
                e.rejectPositionCommand(trimmed); // CR-08: no stale position
            } else if (std.mem.startsWith(u8, trimmed, "go")) {
                // Every `go` gets exactly one `bestmove`.
                w.out.output().print("info string error: cannot parse '{s}'", .{trimmed});
                w.out.output().line("bestmove 0000");
            }
            return;
        };
        switch (cmd) {
            .setoption => |o| e.setOption(o),
            .ucinewgame => try e.newGame(),
            .position => |p| try e.position(p),
            .go => |g| e.go(g, &w.sig),
            .isready => w.out.output().line("readyok"),
            else => {},
        }
    }
};

pub fn run(gpa: std.mem.Allocator, io: std.Io) !void {
    var out: StdOut = .{ .io = io };
    out.stdout.init(io);
    const e = try Engine.init(gpa, io, out.output());
    defer e.deinit();
    var worker: Worker = .{ .gpa = gpa, .io = io, .e = e, .out = &out };
    defer worker.queue.deinit(gpa);
    const thread = try std.Thread.spawn(.{}, Worker.main, .{&worker});
    var quit_command = false;
    defer {
        worker.quit(quit_command);
        thread.join();
    }

    var in_buf: [64 * 1024]u8 = undefined;
    // Overlapped pipes (fastchess on Windows) need pipe_io: std's reader
    // panicked at the first read that had to wait.
    var stdin: pipe_io.Stdin = undefined;
    stdin.init(io, &in_buf);
    const reader = stdin.reader();
    while (true) {
        const raw = reader.takeDelimiter('\n') catch |err| switch (err) {
            error.StreamTooLong => {
                // takeDelimiter leaves an over-long line unread: skip it.
                _ = reader.discardDelimiterInclusive('\n') catch break;
                out.output().line("info string error: input line too long, ignored");
                continue;
            },
            else => return err,
        } orelse break;
        // A byte-order mark may precede the first command (e.g. Windows pipes).
        const line = if (std.mem.startsWith(u8, raw, "\xEF\xBB\xBF")) raw[3..] else raw;
        const cmd = uci_parse.parse(line) catch {
            // A malformed `position` or `go` still reaches the worker, in
            // order (CR-08); anything else is reported and ignored.
            const word = std.mem.trim(u8, line, " \r\n\t");
            const is_go = std.mem.startsWith(u8, word, "go");
            if (is_go or std.mem.startsWith(u8, word, "position")) {
                try worker.push(line, is_go, false);
            } else {
                out.output().print("info string error: cannot parse '{s}'", .{word});
            }
            continue;
        };
        switch (cmd) {
            .uci => e.printId(),
            .isready => if (worker.busy()) out.output().line("readyok") else try worker.push(line, false, false),
            .debug, .unknown => {},
            .stop => worker.stop(),
            .ponderhit => worker.ponderhit(),
            .quit => {
                quit_command = true;
                break;
            },
            .setoption, .ucinewgame, .position => try worker.push(line, false, false),
            .go => |g| try worker.push(line, true, g.infinite or g.ponder),
        }
    }
}
