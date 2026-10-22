//! The engine behind the UCI protocol (AGENTS.md §9): options, the game
//! state with a checkpoint per game ply, the canonical operator script
//! (AGENTS.md §9.6, game.Session), `go` in original mode (the levels) and in
//! extended mode (iterative deepening, docs/EXTENDED_SEARCH.md), search
//! information, time control and pondering. I/O is abstracted: output goes
//! through `Output`, and the stop / ponderhit signals are atomics set by the
//! UCI loop (uci.zig) from another thread.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const game = @import("game.zig");
const search = @import("search.zig");
const book = @import("book.zig");
const driver = @import("driver.zig");
const info_mod = @import("info.zig");
const Info = info_mod.Info;
const legal = @import("legal.zig");
const Rng = @import("rng.zig").Rng;
const timeman = @import("timeman.zig");
const uci_parse = @import("uci_parse.zig");
const Observer = @import("observer.zig").Observer;

pub const name = "Cyrus IS Chess";
pub const author = "Richard Lang";

/// Where the engine's lines go (without the trailing newline).
pub const Output = struct {
    ctx: ?*anyopaque = null,
    lineFn: *const fn (ctx: ?*anyopaque, text: []const u8) void,

    pub fn line(o: Output, text: []const u8) void {
        o.lineFn(o.ctx, text);
    }

    pub fn print(o: Output, comptime fmt: []const u8, args: anytype) void {
        var buf: [8192]u8 = undefined;
        const t = std.fmt.bufPrint(&buf, fmt, args) catch return;
        o.lineFn(o.ctx, t);
    }
};

/// Signals from the input thread to the search.
pub const Signals = struct {
    stop: std.atomic.Value(bool) = .init(false),
    ponderhit: std.atomic.Value(bool) = .init(false),
};

pub const Options = struct {
    /// null: UCI (extended mode); otherwise the level index 0-10
    /// (Level 1-8, P1-P3: original mode).
    level: ?u8 = null,
    profile: driver.Profile = .level8,
    own_book: bool = true,
    ponder: bool = false,
    move_overhead: u64 = 30,
    show_currline: bool = false,
    show_refutations: bool = false,
    seed: u64 = 0,
};

const level_names = [_][]const u8{ "Level 1", "Level 2", "Level 3", "Level 4", "Level 5", "Level 6", "Level 7", "Level 8", "Level P1", "Level P2", "Level P3" };

/// A saved engine state after a game ply: everything but the move-list
/// storage (no later search reads it; see tools/oracle/verify_state.py),
/// plus the root list the main loop generated, which the human-move path
/// looks moves up in.
const Checkpoint = struct {
    bytes: []u8,
    root_list: []u8,
    turn: game.Turn,
    /// The ply was the engine's own move.
    cyrus_moved: bool,
};

fn stateSize() usize {
    var n: usize = 0;
    inline for (comptime std.meta.fieldNames(State)) |fname| {
        if (comptime !std.mem.eql(u8, fname, "lists")) n += @sizeOf(@FieldType(State, fname));
    }
    return n;
}

fn saveState(dst: []u8, s: *const State) void {
    var off: usize = 0;
    inline for (comptime std.meta.fieldNames(State)) |fname| {
        if (comptime !std.mem.eql(u8, fname, "lists")) {
            const b = std.mem.asBytes(&@field(s, fname));
            @memcpy(dst[off..][0..b.len], b);
            off += b.len;
        }
    }
}

fn restoreState(s: *State, src: []const u8) void {
    var off: usize = 0;
    inline for (comptime std.meta.fieldNames(State)) |fname| {
        if (comptime !std.mem.eql(u8, fname, "lists")) {
            const b = std.mem.asBytes(&@field(s, fname));
            @memcpy(b, src[off..][0..b.len]);
            off += b.len;
        }
    }
}

pub const Engine = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    out: Output,
    s: *State,
    /// Scratch state for checking reported lines (never searched).
    scratch: *State,
    session: game.Session,
    opts: Options = .{},
    rng: Rng,
    /// The current position is valid (false after a rejected `position`).
    valid: bool = true,
    /// The game: its start (null = standard start) and the moves applied.
    start_fen: ?[]u8 = null,
    history: std.ArrayList(game.Move) = .empty,
    checkpoints: std.ArrayList(Checkpoint) = .empty,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, out: Output) !*Engine {
        const e = try gpa.create(Engine);
        errdefer gpa.destroy(e);
        const s = try gpa.create(State);
        s.* = .{};
        const scratch = try gpa.create(State);
        e.* = .{ .gpa = gpa, .io = io, .out = out, .s = s, .scratch = scratch, .session = .{ .s = s }, .rng = Rng.init(clockSeed(io)) };
        e.session.turn = game.coldStart(s);
        try e.resetHistory(null);
        return e;
    }

    pub fn deinit(e: *Engine) void {
        e.clearCheckpoints();
        e.checkpoints.deinit(e.gpa);
        e.history.deinit(e.gpa);
        if (e.start_fen) |f| e.gpa.free(f);
        e.gpa.destroy(e.s);
        e.gpa.destroy(e.scratch);
        e.gpa.destroy(e);
    }

    fn clockSeed(io: std.Io) u64 {
        const t = std.Io.Clock.awake.now(io).nanoseconds;
        return @truncate(@as(u96, @bitCast(t)));
    }

    fn clearCheckpoints(e: *Engine) void {
        for (e.checkpoints.items) |c| {
            e.gpa.free(c.bytes);
            e.gpa.free(c.root_list);
        }
        e.checkpoints.clearRetainingCapacity();
    }

    fn checkpoint(e: *Engine, cyrus_moved: bool) !void {
        const bytes = try e.gpa.alloc(u8, stateSize());
        saveState(bytes, e.s);
        const end = @min(st.listOffset(e.s.slot[2]) + 4, st.list_bytes_original);
        const root_list = try e.gpa.dupe(u8, e.s.lists[0..end]);
        try e.checkpoints.append(e.gpa, .{ .bytes = bytes, .root_list = root_list, .turn = e.session.turn, .cyrus_moved = cyrus_moved });
    }

    fn resetHistory(e: *Engine, fen: ?[]const u8) !void {
        e.clearCheckpoints();
        e.history.clearRetainingCapacity();
        if (e.start_fen) |f| e.gpa.free(f);
        e.start_fen = if (fen) |f| try e.gpa.dupe(u8, f) else null;
        e.session.pending = null;
        try e.checkpoint(false);
    }

    // ----------------------------------------------------------- commands
    pub fn printId(e: *Engine) void {
        e.out.print("id name {s}", .{name});
        e.out.print("id author {s}", .{author});
        var buf: [512]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        w.writeAll("option name Level type combo default UCI var UCI") catch {};
        for (level_names) |l| w.print(" var {s}", .{l}) catch {};
        e.out.line(w.buffered());
        e.out.line("option name Profile type combo default Level 8 var Level 6 var Level 7 var Level 8");
        e.out.line("option name OwnBook type check default true");
        e.out.line("option name Ponder type check default false");
        e.out.line("option name Move Overhead type spin default 30 min 0 max 5000");
        e.out.line("option name UCI_ShowCurrLine type check default false");
        e.out.line("option name UCI_ShowRefutations type check default false");
        e.out.line("option name Seed type spin default 0 min 0 max 2147483647");
        e.out.line("uciok");
    }

    pub fn setOption(e: *Engine, o: uci_parse.SetOption) void {
        const v = o.value orelse "";
        if (std.ascii.eqlIgnoreCase(o.name, "Level")) {
            if (std.ascii.eqlIgnoreCase(v, "UCI")) {
                e.opts.level = null;
                return;
            }
            for (level_names, 0..) |l, i| {
                if (std.ascii.eqlIgnoreCase(v, l)) {
                    e.opts.level = @intCast(i);
                    return;
                }
            }
        } else if (std.ascii.eqlIgnoreCase(o.name, "Profile")) {
            if (std.ascii.eqlIgnoreCase(v, "Level 6")) e.opts.profile = .level6 else if (std.ascii.eqlIgnoreCase(v, "Level 7")) e.opts.profile = .level7 else if (std.ascii.eqlIgnoreCase(v, "Level 8")) e.opts.profile = .level8 else return e.unknownValue(o);
            return;
        } else if (std.ascii.eqlIgnoreCase(o.name, "OwnBook")) {
            e.opts.own_book = std.ascii.eqlIgnoreCase(v, "true");
            return;
        } else if (std.ascii.eqlIgnoreCase(o.name, "Ponder")) {
            e.opts.ponder = std.ascii.eqlIgnoreCase(v, "true");
            return;
        } else if (std.ascii.eqlIgnoreCase(o.name, "Move Overhead")) {
            e.opts.move_overhead = std.fmt.parseInt(u64, v, 10) catch return e.unknownValue(o);
            return;
        } else if (std.ascii.eqlIgnoreCase(o.name, "UCI_ShowCurrLine")) {
            e.opts.show_currline = std.ascii.eqlIgnoreCase(v, "true");
            return;
        } else if (std.ascii.eqlIgnoreCase(o.name, "UCI_ShowRefutations")) {
            e.opts.show_refutations = std.ascii.eqlIgnoreCase(v, "true");
            return;
        } else if (std.ascii.eqlIgnoreCase(o.name, "Seed")) {
            e.opts.seed = std.fmt.parseInt(u64, v, 10) catch return e.unknownValue(o);
            e.rng = Rng.init(if (e.opts.seed == 0) clockSeed(e.io) else e.opts.seed);
            return;
        } else {
            e.out.print("info string unknown option {s}", .{o.name});
            return;
        }
        e.unknownValue(o);
    }

    fn unknownValue(e: *Engine, o: uci_parse.SetOption) void {
        e.out.print("info string unknown value '{s}' for option {s}", .{ o.value orelse "", o.name });
    }

    /// `ucinewgame`: the original's new game (G, Y). Like the original it
    /// keeps $BCA0, $BCCE and the level.
    pub fn newGame(e: *Engine) !void {
        e.session.turn = game.newGame(e.s);
        e.valid = true;
        try e.resetHistory(null);
    }

    /// `position`: AGENTS.md §9.4 and §9.6. A rejected position prints the
    /// reason and leaves the engine without a valid position.
    pub fn position(e: *Engine, p: uci_parse.Position) !void {
        var moves: std.ArrayList(game.Move) = .empty;
        defer moves.deinit(e.gpa);
        var it = std.mem.tokenizeAny(u8, p.moves, " \t");
        while (it.next()) |t| {
            const m = game.Move.parse(t) catch {
                e.reject("bad move {s}", .{t});
                return;
            };
            try moves.append(e.gpa, m);
        }
        const same_start = e.valid and e.checkpoints.items.len > 0 and
            ((p.fen == null and e.start_fen == null) or
                (p.fen != null and e.start_fen != null and std.mem.eql(u8, p.fen.?, e.start_fen.?)));
        if (same_start) {
            var i: usize = 0;
            while (i < moves.items.len and i < e.history.items.len and
                std.meta.eql(moves.items[i], e.history.items[i])) : (i += 1)
            {}
            const cp = e.checkpoints.items[i];
            restoreState(e.s, cp.bytes);
            @memcpy(e.s.lists[0..cp.root_list.len], cp.root_list);
            e.session.turn = cp.turn;
            e.session.pending = null;
            for (e.checkpoints.items[i + 1 ..]) |c| {
                e.gpa.free(c.bytes);
                e.gpa.free(c.root_list);
            }
            e.checkpoints.shrinkRetainingCapacity(i + 1);
            e.history.shrinkRetainingCapacity(i);
            const rest = moves.items[i..];
            if (rest.len == 1 and cp.cyrus_moved and e.s.players != 0 and e.session.turn == .human) {
                // Continuing the game after the engine's move: the opponent's
                // move is entered in HUMAN v CYRUS mode when `go` comes.
                e.session.pending = rest[0];
                return;
            }
            e.applyHumanVHuman(rest) catch |err| return e.rejectErr(err);
            return;
        }
        // From scratch: a new game, or set-up for the FEN; then E and the moves.
        if (p.fen) |fen| {
            e.session.turn = game.loadFen(e.s, fen) catch |err| {
                e.valid = false;
                e.reject("{s}", .{@errorName(err)});
                return;
            };
        } else {
            e.session.turn = game.newGame(e.s);
        }
        e.valid = true;
        try e.resetHistory(p.fen);
        e.applyHumanVHuman(moves.items) catch |err| return e.rejectErr(err);
    }

    fn applyHumanVHuman(e: *Engine, moves: []const game.Move) !void {
        if (moves.len == 0) return;
        if (e.s.players != 0) game.humanVHuman(e.s);
        for (moves) |m| {
            if (e.session.turn != .human) return error.GameOver;
            e.session.turn = try game.humanMove(e.s, m);
            try e.history.append(e.gpa, m);
            try e.checkpoint(false);
        }
    }

    fn rejectErr(e: *Engine, err: anyerror) void {
        e.valid = false;
        e.reject("{s}", .{switch (err) {
            error.IllegalMove => "a move is illegal for the original",
            error.GameOver => "the original's game is over (mate, stalemate or its draw rules) before the last move",
            else => @errorName(err),
        }});
    }

    fn reject(e: *Engine, comptime fmt: []const u8, args: anytype) void {
        e.valid = false;
        var buf: [256]u8 = undefined;
        const t = std.fmt.bufPrint(&buf, fmt, args) catch "?";
        e.out.print("info string error: position rejected: {s}", .{t});
    }

    // ------------------------------------------------------------------ go
    /// `go`: search and print `bestmove` (exactly once), then play the move
    /// into the engine's game as the operator script does. Runs on the
    /// search thread; `sig` is set by the input thread.
    pub fn go(e: *Engine, g: uci_parse.Go, sig: *Signals) void {
        e.goImpl(g, sig) catch |err| {
            e.out.print("info string error: {s}", .{@errorName(err)});
            e.out.line("bestmove 0000");
        };
    }

    fn goImpl(e: *Engine, g: uci_parse.Go, sig: *Signals) !void {
        const s = e.s;
        const start_ms = e.nowMs();
        if (!e.valid) return e.finishNoMove(g, sig, "no valid position");

        // Bring the program to ComputerMove ($6147) by the operator script.
        if (e.opts.level) |lv| game.setLevel(s, lv);
        var turn = e.session.turn;
        if (e.session.pending) |m| {
            e.session.pending = null;
            e.session.turn = game.humanMove(s, m) catch {
                e.valid = false;
                return e.finishNoMove(g, sig, "the opponent's move is illegal for the original");
            };
            try e.history.append(e.gpa, m);
            try e.checkpoint(false);
            turn = e.session.turn;
        } else if (turn != .computer) {
            e.session.turn = game.keyMove(s);
            turn = e.session.turn;
        }
        switch (turn) {
            .computer => {},
            .no_moves => return e.finishNoMove(g, sig, "no legal move"),
            .draw => {
                // DEV-012 (class B): the original declares DRAWN (repetition
                // or 50 moves) and would not move; UCI needs a move.
                var buf: [64]legal.Move = undefined;
                if (legal.legalMoves(s, &buf) == 0) return e.finishNoMove(g, sig, "no legal move");
                e.out.line("info string the original declares a draw here; searching anyway");
            },
            .human => return e.finishNoMove(g, sig, "not the engine's turn"),
        }

        // searchmoves: every other root move goes on the next-best exclusion list.
        if (g.searchmoves) |text| try e.excludeAllBut(text);
        // DEV-006: the random byte; OwnBook off = out of book.
        s.random = e.rng.byte();
        if (!e.opts.own_book) s.book_state = 0xFF;

        var ctl: Control = .{
            .e = e,
            .sig = sig,
            .start_ms = start_ms,
            .pondering = g.ponder,
            .infinite = g.infinite,
            .nodes_limit = g.nodes,
            .mate_limit = g.mate,
        };
        ctl.computeLimits(g);
        var info: Info = .{};
        const ctl_obs = ctl.observer();
        info.next = &ctl_obs;
        info.reporter = .{ .ctx = &ctl, .newBest = Control.reportNewBest, .passDone = Control.reportPassDone, .rootMove = Control.reportRootMove, .book = Control.reportBook };
        ctl.info = &info;
        const obs = info.observer();
        var rsrc = e.rng.source();
        const sopts: search.Options = .{ .book = book.fixed_options, .guard_find_move = true };

        const outcome: search.Outcome = if (e.opts.level != null)
            search.computerMove(s, &rsrc, &obs, sopts)
        else
            driver.computerMove(s, &rsrc, &obs, sopts, ctl.plan());

        // `infinite` and `ponder` hold `bestmove` until stop / ponderhit.
        ctl.waitForRelease();

        switch (outcome) {
            .no_moves => {
                e.out.line("bestmove 0000");
                return;
            },
            .no_mate => {
                e.out.line("info string NO MATE FOUND");
                e.out.line("bestmove 0000");
                _ = e.session.finishGo(.no_mate);
                return;
            },
            .move => |entry0| {
                var entry = entry0;
                const em = s.entry(entry);
                if (!legal.isLegal(s, em[1] & 0x7F, em[2])) {
                    // DEV-005: never output an illegal move.
                    const fb = legal.firstLegalRootMove(s) orelse {
                        e.out.line("info string error: the search returned an illegal move and no legal move was found");
                        e.out.line("bestmove 0000");
                        return;
                    };
                    e.out.line("info string DEV-005: the search's move was illegal; playing the first legal root move");
                    entry = fb;
                }
                const mv = s.entry(entry);
                const best: info_mod.Move = .{ .from = mv[1] & 0x7F, .to = mv[2], .promo = info_mod.isPromotion(s, mv[1] & 0x7F, mv[2]) };
                var b1: [5]u8 = undefined;
                var b2: [5]u8 = undefined;
                const ponder_move: ?info_mod.Move = if (ctl.legalPvLen() >= 2 and info.best[0].from == best.from and info.best[0].to == best.to) info.best[1] else null;
                ctl.finalInfo();
                if (ponder_move) |pm| {
                    e.out.print("bestmove {s} ponder {s}", .{ best.uci(&b1), pm.uci(&b2) });
                } else {
                    e.out.print("bestmove {s}", .{best.uci(&b1)});
                }
                // The engine plays its move into its game (PlayMove).
                _ = e.session.finishGo(.{ .move = entry });
                try e.history.append(e.gpa, .{ .from = best.from, .to = best.to, .promo = if (best.promo) 'q' else 0 });
                try e.checkpoint(true);
            },
        }
    }

    fn finishNoMove(e: *Engine, g: uci_parse.Go, sig: *Signals, why: []const u8) void {
        e.out.print("info string {s}", .{why});
        if (g.infinite or g.ponder) {
            while (!sig.stop.load(.acquire) and !(g.ponder and sig.ponderhit.load(.acquire)))
                e.io.sleep(.fromMilliseconds(1), .awake) catch {};
        }
        e.out.line("bestmove 0000");
    }

    fn excludeAllBut(e: *Engine, text: []const u8) !void {
        const s = e.s;
        var keep: std.ArrayList(game.Move) = .empty;
        defer keep.deinit(e.gpa);
        var it = std.mem.tokenizeAny(u8, text, " \t");
        while (it.next()) |t| try keep.append(e.gpa, game.Move.parse(t) catch continue);
        var all: [256]legal.Move = undefined;
        const n = @min(legal.legalMoves(s, &all), all.len);
        s.exclusion_len = 0;
        for (all[0..n]) |m| {
            var listed = false;
            for (keep.items) |k| {
                if (k.from == m.from and k.to == m.to) listed = true;
            }
            if (listed or s.exclusion_len + 2 > s.exclusion.len) continue;
            s.exclusion[s.exclusion_len] = m.from;
            s.exclusion[s.exclusion_len + 1] = m.to;
            s.exclusion_len += 2;
        }
        // Next-best mode keeps the list (and skips the book), as the N key does.
        if (s.exclusion_len != 0) s.next_best = 1;
    }

    pub fn nowMs(e: *Engine) u64 {
        const t = std.Io.Clock.awake.now(e.io).nanoseconds;
        return @intCast(@divTrunc(t, std.time.ns_per_ms));
    }
};

/// Stop, time and limit control for one `go`, plus the info printing. It is
/// the observer the Info collector forwards to: its `node` is the key poll.
const Control = struct {
    e: *Engine,
    sig: *Signals,
    info: *Info = undefined,
    start_ms: u64,
    pondering: bool,
    infinite: bool,
    nodes_limit: ?u64,
    mate_limit: ?u32,
    depth_limit: ?u32 = null,
    limits: timeman.Limits = .{ .soft_ms = null, .hard_ms = null },
    clock: timeman.Clock = .{},
    node_entries: u64 = 0,
    last_currline_ms: u64 = 0,
    pass_start_ms: u64 = 0,
    pass_depth: u8 = 0,
    last_pass_ms: ?u64 = null,
    prev_pass_ms: ?u64 = null,
    /// `nodes` of the last PV line printed (no repeat before `bestmove`).
    printed_nodes: ?u64 = null,

    fn computeLimits(c: *Control, g: uci_parse.Go) void {
        const white = legal.whiteToMove(c.e.s);
        c.clock = .{
            .time_ms = if (white) g.wtime else g.btime,
            .inc_ms = if (white) g.winc else g.binc,
            .movestogo = g.movestogo,
            .movetime_ms = g.movetime,
        };
        c.depth_limit = g.depth;
        if (!c.infinite and !c.pondering) c.limits = timeman.budget(c.clock, c.e.opts.move_overhead);
    }

    fn plan(c: *Control) driver.Plan {
        var max: u32 = st.max_depth;
        if (c.depth_limit) |d| max = @min(max, @max(d, 1));
        if (c.mate_limit) |m| max = @min(max, 2 * m + 1);
        return .{ .profile = c.e.opts.profile, .max_depth = @intCast(max), .ctx = c, .nextPass = nextPass };
    }

    fn elapsed(c: *Control) u64 {
        return c.e.nowMs() -| c.start_ms;
    }

    /// ponderhit: from now on the move's clock runs (EXTENDED_SEARCH §5).
    fn checkPonderhit(c: *Control) void {
        if (c.pondering and c.sig.ponderhit.load(.acquire)) {
            c.pondering = false;
            c.start_ms = c.e.nowMs();
            if (!c.infinite) c.limits = timeman.budget(c.clock, c.e.opts.move_overhead);
        }
    }

    fn nextPass(ctx: ?*anyopaque, s: *const State, depth: u8) bool {
        _ = depth;
        const c: *Control = @ptrCast(@alignCast(ctx.?));
        c.checkPonderhit();
        if (c.sig.stop.load(.acquire)) return false;
        if (c.nodes_limit) |n| if (c.info.nodes >= n) return false;
        if (c.mate_limit) |m| {
            if (s.value[1] >= 0xFE) {
                const plies: u32 = if (s.best_mate_ply != 0xFF and s.best_mate_ply >= 2) s.best_mate_ply - 1 else 1;
                if ((plies + 1) / 2 <= m) return false;
            }
        }
        if (c.pondering or c.infinite) return true;
        return timeman.startNextPass(c.limits, c.elapsed(), c.last_pass_ms, c.prev_pass_ms);
    }

    fn observer(c: *Control) Observer {
        return .{ .ctx = c, .onNode = onNode, .onPassStart = onPassStart, .onPassDone = onPassDone };
    }

    fn self(ctx: ?*anyopaque) *Control {
        return @ptrCast(@alignCast(ctx.?));
    }

    /// The key poll at $78BA (DEV-007): stop, node limit, hard time limit.
    fn onNode(ctx: ?*anyopaque, s: *const State) bool {
        _ = s;
        const c = self(ctx);
        c.node_entries += 1;
        if (c.sig.stop.load(.monotonic)) return true;
        if (c.nodes_limit) |n| if (c.info.nodes >= n) return true;
        if (c.node_entries & 1023 == 0) {
            c.checkPonderhit();
            const t = c.elapsed();
            if (!c.pondering and !c.infinite) {
                if (c.limits.hard_ms) |h| if (t >= h) return true;
            }
            if (c.e.opts.show_currline and t >= 1000 and t - c.last_currline_ms >= 1000) {
                c.last_currline_ms = t;
                var buf: [1024]u8 = undefined;
                var w: std.Io.Writer = .fixed(&buf);
                w.writeAll("info ") catch {};
                c.info.writeCurrLine(&w) catch {};
                c.e.out.line(w.buffered());
            }
        }
        return false;
    }

    fn onPassStart(ctx: ?*anyopaque, s: *const State, depth: u8, a: u8) void {
        _ = s;
        _ = a;
        const c = self(ctx);
        c.pass_start_ms = c.elapsed();
        c.pass_depth = depth;
    }

    /// Pass durations for the time prediction; the D = 2 pre-pass is a
    /// different kind of search and is left out of the growth ratio.
    fn onPassDone(ctx: ?*anyopaque, s: *const State) void {
        const c = self(ctx);
        if (s.search_flags & 0x80 != 0) return;
        if (c.pass_depth < 3) return;
        c.prev_pass_ms = c.last_pass_ms;
        c.last_pass_ms = c.elapsed() -| c.pass_start_ms;
    }

    fn writeLine(c: *Control, w: *std.Io.Writer, depth: u8) !void {
        const info = c.info;
        const t = c.elapsed();
        const nps = if (t > 0) info.nodes * 1000 / t else info.nodes * 1000;
        try w.print("info depth {d} seldepth {d} ", .{ depth, @max(info.seldepth, depth) });
        try info.writeScore(w);
        try w.print(" nodes {d} nps {d} time {d} pv", .{ info.nodes, nps, t });
        var b: [5]u8 = undefined;
        for (info.best[0..c.legalPvLen()]) |m| try w.print(" {s}", .{m.uci(&b)});
        c.printed_nodes = info.nodes;
    }

    /// The reported PV, truncated at its first illegal move (AGENTS.md §8.2):
    /// the original's selective plies count illegal replies in check as a
    /// value, so its best line can contain them. Called at the root only.
    fn legalPvLen(c: *Control) usize {
        const info = c.info;
        var line: [st.ply_slots]legal.Move = undefined;
        for (info.best[0..info.best_len], 0..) |m, k| line[k] = .{ .from = m.from, .to = m.to };
        return legal.legalPrefix(c.e.s, c.e.scratch, line[0..info.best_len]);
    }

    fn reportNewBest(ctx: ?*anyopaque, info: *const Info) void {
        const c = self(ctx);
        var buf: [4096]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        c.writeLine(&w, info.depth) catch return;
        c.e.out.line(w.buffered());
    }

    fn reportPassDone(ctx: ?*anyopaque, info: *const Info, aborted: bool) void {
        const c = self(ctx);
        if (aborted or info.best_len == 0) return;
        var buf: [4096]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        c.writeLine(&w, info.depth) catch return;
        c.e.out.line(w.buffered());
        if (c.e.opts.show_refutations) {
            var b1: [5]u8 = undefined;
            var b2: [5]u8 = undefined;
            for (info.refutations[0..info.refutation_count]) |r| {
                c.e.out.print("info refutation {s} {s}", .{ r.root.uci(&b1), r.reply.uci(&b2) });
            }
        }
    }

    fn reportRootMove(ctx: ?*anyopaque, info: *const Info) void {
        const c = self(ctx);
        if (c.elapsed() < 1000) return;
        var b: [5]u8 = undefined;
        c.e.out.print("info depth {d} currmove {s} currmovenumber {d}", .{ info.depth, info.currmove.uci(&b), info.currmovenumber });
    }

    fn reportBook(ctx: ?*anyopaque, info: *const Info) void {
        const c = self(ctx);
        var b: [5]u8 = undefined;
        if (info.book_move) |m| c.e.out.print("info string book move {s}", .{m.uci(&b)});
    }

    /// The last info line before `bestmove` (nodes and time at the end).
    fn finalInfo(c: *Control) void {
        if (c.info.best_len == 0 or c.printed_nodes == c.info.nodes) return;
        var buf: [4096]u8 = undefined;
        var w: std.Io.Writer = .fixed(&buf);
        c.writeLine(&w, if (c.info.completed_depth != 0) c.info.completed_depth else c.info.depth) catch return;
        c.e.out.line(w.buffered());
    }

    /// `go infinite` / `go ponder`: hold `bestmove` until stop (or ponderhit).
    fn waitForRelease(c: *Control) void {
        while (true) {
            if (c.sig.stop.load(.acquire)) return;
            c.checkPonderhit();
            if (!c.infinite and !c.pondering) return;
            c.e.io.sleep(.fromMilliseconds(1), .awake) catch {};
        }
    }
};

// ------------------------------------------------------------------ tests

const TestOut = struct {
    lines: std.ArrayList([]u8) = .empty,
    gpa: std.mem.Allocator,

    fn output(t: *TestOut) Output {
        return .{ .ctx = t, .lineFn = lineFn };
    }

    fn lineFn(ctx: ?*anyopaque, text: []const u8) void {
        const t: *TestOut = @ptrCast(@alignCast(ctx.?));
        const copy = t.gpa.dupe(u8, text) catch return;
        t.lines.append(t.gpa, copy) catch t.gpa.free(copy);
    }

    fn deinit(t: *TestOut) void {
        for (t.lines.items) |l| t.gpa.free(l);
        t.lines.deinit(t.gpa);
    }

    fn last(t: *TestOut) []const u8 {
        return t.lines.items[t.lines.items.len - 1];
    }

    fn has(t: *TestOut, prefix: []const u8) bool {
        for (t.lines.items) |l| if (std.mem.startsWith(u8, l, prefix)) return true;
        return false;
    }

    fn dump(t: *TestOut) void {
        for (t.lines.items) |l| std.debug.print("  > {s}\n", .{l});
    }

    fn clear(t: *TestOut) void {
        for (t.lines.items) |l| t.gpa.free(l);
        t.lines.clearRetainingCapacity();
    }
};

fn run(e: *Engine, sig: *Signals, line: []const u8) !void {
    switch (try uci_parse.parse(line)) {
        .uci => e.printId(),
        .ucinewgame => try e.newGame(),
        .setoption => |o| e.setOption(o),
        .position => |p| try e.position(p),
        .go => |g| e.go(g, sig),
        else => {},
    }
}

fn bestmove(t: *TestOut) []const u8 {
    var i = t.lines.items.len;
    while (i > 0) {
        i -= 1;
        if (std.mem.startsWith(u8, t.lines.items[i], "bestmove ")) {
            var it = std.mem.tokenizeScalar(u8, t.lines.items[i]["bestmove ".len..], ' ');
            return it.next() orelse "";
        }
    }
    return "";
}

test "uci identity and options" {
    const gpa = std.testing.allocator;
    var out: TestOut = .{ .gpa = gpa };
    defer out.deinit();
    errdefer out.dump();
    const e = try Engine.init(gpa, std.testing.io, out.output());
    defer e.deinit();
    var sig: Signals = .{};
    try run(e, &sig, "uci");
    try std.testing.expectEqualStrings("uciok", out.last());
    try std.testing.expect(out.has("option name Level type combo default UCI var UCI var Level 1"));
    try run(e, &sig, "setoption name Level value Level P2");
    try std.testing.expectEqual(@as(?u8, 9), e.opts.level);
    try run(e, &sig, "setoption name Level value UCI");
    try std.testing.expectEqual(@as(?u8, null), e.opts.level);
    try run(e, &sig, "setoption name Profile value Level 7");
    try std.testing.expectEqual(driver.Profile.level7, e.opts.profile);
}

test "a short game in extended mode: legal moves, info lines, continuation" {
    const gpa = std.testing.allocator;
    var out: TestOut = .{ .gpa = gpa };
    defer out.deinit();
    errdefer out.dump();
    const e = try Engine.init(gpa, std.testing.io, out.output());
    defer e.deinit();
    var sig: Signals = .{};
    try run(e, &sig, "setoption name Seed value 7");
    try run(e, &sig, "position startpos moves e2e4");
    try run(e, &sig, "go depth 4");
    const m1 = try gpa.dupe(u8, bestmove(&out));
    defer gpa.free(m1);
    try std.testing.expect(m1.len >= 4);
    // continue the game: the engine's move and one more move of ours
    var buf: [128]u8 = undefined;
    const reply: []const u8 = if (std.mem.eql(u8, m1[0..4], "e7e5")) "g1f3" else "d2d4";
    try run(e, &sig, try std.fmt.bufPrint(&buf, "position startpos moves e2e4 {s} {s}", .{ m1[0..4], reply }));
    try std.testing.expect(e.session.pending != null); // continuation, no swap
    out.clear();
    try run(e, &sig, "go depth 5");
    try std.testing.expect(out.has("info depth"));
    const m2 = bestmove(&out);
    try std.testing.expect(m2.len >= 4);
}

test "rejected positions and no-move positions" {
    const gpa = std.testing.allocator;
    var out: TestOut = .{ .gpa = gpa };
    defer out.deinit();
    errdefer out.dump();
    const e = try Engine.init(gpa, std.testing.io, out.output());
    defer e.deinit();
    var sig: Signals = .{};
    try run(e, &sig, "position fen 4k2P/8/8/8/8/8/8/4K3 w - - 0 1");
    try std.testing.expect(out.has("info string error: position rejected"));
    try run(e, &sig, "go depth 3");
    try std.testing.expectEqualStrings("0000", bestmove(&out));
    // stalemate: no legal move
    out.clear();
    try run(e, &sig, "position fen 7k/5Q2/6K1/8/8/8/8/8 b - - 0 1");
    try run(e, &sig, "go depth 3");
    try std.testing.expectEqualStrings("0000", bestmove(&out));
    // illegal move in the move list
    out.clear();
    try run(e, &sig, "position startpos moves e2e5");
    try std.testing.expect(out.has("info string error: position rejected"));
}

test "original levels, problem levels, nodes limit, searchmoves, mate" {
    const gpa = std.testing.allocator;
    var out: TestOut = .{ .gpa = gpa };
    defer out.deinit();
    errdefer out.dump();
    const e = try Engine.init(gpa, std.testing.io, out.output());
    defer e.deinit();
    var sig: Signals = .{};
    // Level 2 from a middlegame (out of book)
    try run(e, &sig, "setoption name Level value Level 2");
    try run(e, &sig, "position startpos moves e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 c1e3 e7e5 d4b3 c8e6 f2f3 f8e7");
    try run(e, &sig, "go wtime 1000 btime 1000");
    try std.testing.expect(bestmove(&out).len >= 4);
    // P1 without a mate: NO MATE FOUND
    out.clear();
    try run(e, &sig, "setoption name Level value Level P1");
    try run(e, &sig, "position startpos moves e2e4 e7e5");
    try run(e, &sig, "go");
    try std.testing.expect(out.has("info string NO MATE FOUND"));
    try std.testing.expectEqualStrings("0000", bestmove(&out));
    // P1 with a mate in one
    out.clear();
    try run(e, &sig, "position fen 6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1");
    try run(e, &sig, "go");
    try std.testing.expectEqualStrings("d1d8", bestmove(&out));
    // extended: go mate 2 finds Morphy's mate
    out.clear();
    try run(e, &sig, "setoption name Level value UCI");
    try run(e, &sig, "position fen kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1");
    try run(e, &sig, "go mate 2");
    try std.testing.expectEqualStrings("a1a6", bestmove(&out)[0..4]);
    try std.testing.expect(out.has("info depth"));
    // nodes limit
    out.clear();
    try run(e, &sig, "position startpos moves e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6");
    try run(e, &sig, "go nodes 5000");
    try std.testing.expect(bestmove(&out).len >= 4);
    // searchmoves restricts the root
    out.clear();
    try run(e, &sig, "position startpos moves e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6");
    try run(e, &sig, "go depth 4 searchmoves h2h3 a2a3");
    const bm = bestmove(&out);
    try std.testing.expect(std.mem.eql(u8, bm[0..4], "h2h3") or std.mem.eql(u8, bm[0..4], "a2a3"));
}

test "checkpoints restore the game after a takeback" {
    const gpa = std.testing.allocator;
    var out: TestOut = .{ .gpa = gpa };
    defer out.deinit();
    errdefer out.dump();
    const e = try Engine.init(gpa, std.testing.io, out.output());
    defer e.deinit();
    var sig: Signals = .{};
    try run(e, &sig, "setoption name Seed value 3");
    try run(e, &sig, "position startpos moves d2d4 g8f6 c2c4");
    try run(e, &sig, "go depth 4");
    const first = try gpa.dupe(u8, bestmove(&out));
    defer gpa.free(first);
    const saved = try gpa.alloc(u8, stateSize());
    defer gpa.free(saved);
    // the same position again (analysis): restored from the checkpoint
    try run(e, &sig, "position startpos moves d2d4 g8f6 c2c4");
    try std.testing.expectEqual(@as(usize, 3), e.history.items.len);
    saveState(saved, e.s);
    try std.testing.expectEqualSlices(u8, e.checkpoints.items[3].bytes, saved);
}
