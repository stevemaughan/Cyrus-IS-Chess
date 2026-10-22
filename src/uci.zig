//! The UCI loop (AGENTS.md §9.2): the main thread reads commands; each `go`
//! runs on one search thread, which polls the stop / ponderhit atomics at the
//! original's key-poll point. `isready` is answered at once, even while
//! searching; commands that change the engine's state wait for the search.

const std = @import("std");
const engine_mod = @import("engine.zig");
const Engine = engine_mod.Engine;
const uci_parse = @import("uci_parse.zig");

/// Standard output shared by both threads: one line at a time, flushed.
const StdOut = struct {
    io: std.Io,
    mutex: std.Io.Mutex = .init,
    buf: [16384]u8 = undefined,
    writer: std.Io.File.Writer = undefined,

    fn output(o: *StdOut) engine_mod.Output {
        return .{ .ctx = o, .lineFn = lineFn };
    }

    fn lineFn(ctx: ?*anyopaque, text: []const u8) void {
        const o: *StdOut = @ptrCast(@alignCast(ctx.?));
        o.mutex.lockUncancelable(o.io);
        defer o.mutex.unlock(o.io);
        const w = &o.writer.interface;
        w.writeAll(text) catch return;
        w.writeByte('\n') catch return;
        w.flush() catch return;
    }
};

const Search = struct {
    thread: ?std.Thread = null,
    sig: engine_mod.Signals = .{},
    go: uci_parse.Go = .{},
    searchmoves: ?[]u8 = null,

    fn running(s: *Search) bool {
        return s.thread != null;
    }

    /// Stop the search (if any) and wait for it; `bestmove` has then been printed.
    fn finish(s: *Search, gpa: std.mem.Allocator, stop: bool) void {
        if (s.thread) |t| {
            if (stop) s.sig.stop.store(true, .release);
            t.join();
            s.thread = null;
        }
        if (s.searchmoves) |m| gpa.free(m);
        s.searchmoves = null;
    }
};

fn searchMain(e: *Engine, g: uci_parse.Go, sig: *engine_mod.Signals) void {
    e.go(g, sig);
}

pub fn run(gpa: std.mem.Allocator, io: std.Io) !void {
    var out: StdOut = .{ .io = io };
    out.writer = .init(.stdout(), io, &out.buf);
    const e = try Engine.init(gpa, io, out.output());
    defer e.deinit();
    var search: Search = .{};
    defer search.finish(gpa, true);

    var in_buf: [64 * 1024]u8 = undefined;
    var reader = std.Io.File.stdin().reader(io, &in_buf);
    while (true) {
        const raw = reader.interface.takeDelimiter('\n') catch |err| switch (err) {
            error.StreamTooLong => continue,
            else => return err,
        } orelse break;
        // A byte-order mark may precede the first command (e.g. Windows pipes).
        const line = if (std.mem.startsWith(u8, raw, "\xEF\xBB\xBF")) raw[3..] else raw;
        const cmd = uci_parse.parse(line) catch {
            out.output().print("info string error: cannot parse '{s}'", .{std.mem.trim(u8, line, " \r\n\t")});
            continue;
        };
        switch (cmd) {
            .uci => e.printId(),
            .isready => out.output().line("readyok"),
            .debug, .unknown => {},
            .stop => if (search.running()) search.sig.stop.store(true, .release),
            .ponderhit => if (search.running()) search.sig.ponderhit.store(true, .release),
            .quit => break,
            .setoption => |o| {
                search.finish(gpa, true);
                e.setOption(o);
            },
            .ucinewgame => {
                search.finish(gpa, true);
                try e.newGame();
            },
            .position => |p| {
                search.finish(gpa, true);
                try e.position(p);
            },
            .go => |g| {
                search.finish(gpa, true);
                search.sig = .{};
                search.go = g;
                if (g.searchmoves) |m| {
                    search.searchmoves = try gpa.dupe(u8, m);
                    search.go.searchmoves = search.searchmoves;
                }
                search.thread = try std.Thread.spawn(.{}, searchMain, .{ e, search.go, &search.sig });
            },
        }
    }
}
