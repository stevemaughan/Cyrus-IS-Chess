//! Search information (docs/EXTENDED_SEARCH.md §6): an Observer that watches
//! the search at its fixed observation points and builds what a UCI engine
//! reports: nodes, seldepth, a principal variation, the current move, the
//! current line and refutations. Instrumentation only: it never writes
//! anything the search reads, and it forwards every event (including the
//! key-poll result of `node`) to the observer it wraps.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const Observer = @import("observer.zig").Observer;

/// A move for reporting: internal squares and a promotion flag.
pub const Move = struct {
    from: u8 = 0,
    to: u8 = 0,
    /// The move promotes a pawn (the engine always takes a queen).
    promo: bool = false,

    /// UCI coordinate notation, e.g. "e2e4" or "e7e8q".
    pub fn uci(m: Move, buf: *[5]u8) []const u8 {
        buf[0] = 'a' + (m.from & 7);
        buf[1] = '0' + (8 - (m.from >> 4));
        buf[2] = 'a' + (m.to & 7);
        buf[3] = '0' + (8 - (m.to >> 4));
        if (m.promo) {
            buf[4] = 'q';
            return buf[0..5];
        }
        return buf[0..4];
    }
};

/// Whether the move (from, to) is a pawn promotion, judged from the board
/// either before the move (the pawn on `from`) or after it (the promoted
/// queen, type $19, in a pawn slot on `to`). After the move this is a guess:
/// a queen promoted earlier, moving from the 2nd/7th rank to the last, looks
/// the same. Exact where the board is before the move; the reported PV is
/// judged again by `legal.legalPrefix`.
pub fn isPromotion(s: *const State, from: u8, to: u8) bool {
    if (from & 0x88 != 0 or to & 0x88 != 0) return false;
    const to_row = to >> 4;
    if (to_row != 0 and to_row != 7) return false;
    const before = s.square(from);
    if (before != 0 and s.rec[(before & 0xFB) +% 1] & 0x0F == 1) return true;
    const after = s.square(to);
    if (after == 0 or s.square(from) != 0) return false;
    const r = after & 0xFB;
    const from_row = from >> 4;
    return r & 0x7F >= 0x40 and s.rec[r +% 1] == 0x19 and (from_row == 1 or from_row == 6);
}

/// The events an engine wants to print.
pub const Reporter = struct {
    ctx: ?*anyopaque = null,
    /// A new best root move (score and PV are current).
    newBest: ?*const fn (ctx: ?*anyopaque, info: *const Info) void = null,
    /// A pass ended (`aborted` = stopped by a key press / limit).
    passDone: ?*const fn (ctx: ?*anyopaque, info: *const Info, aborted: bool) void = null,
    /// A root move is being searched.
    rootMove: ?*const fn (ctx: ?*anyopaque, info: *const Info) void = null,
    /// The opening book chose the move.
    book: ?*const fn (ctx: ?*anyopaque, info: *const Info) void = null,
};

const max_line = st.ply_slots;

pub const Info = struct {
    /// The observer every event is forwarded to (stop / time control).
    next: ?*const Observer = null,
    reporter: Reporter = .{},

    // ---------------------------------------------------------- statistics
    /// Positions visited = calls to make (static scoring included), for the
    /// whole `go`.
    nodes: u64 = 0,
    /// Deepest ply made in the current pass.
    seldepth: u8 = 0,
    /// Full-width depth and level parameter of the current pass.
    depth: u8 = 0,
    pass_a: u8 = 0,
    /// Root moves started in the current pass, and the one being searched.
    currmovenumber: u32 = 0,
    currmove: Move = .{},
    /// Root value V(1) when the best line was recorded ($80 = equal).
    score: u8 = 0x80,
    /// Shortest root mate ply ($BD0C) when the best line was recorded.
    mate_ply: u8 = 0xFF,
    /// The best line found so far (the root move first).
    best: [max_line]Move = undefined,
    best_len: usize = 0,
    /// Depth of the last completed pass (0 = none yet).
    completed_depth: u8 = 0,
    book_move: ?Move = null,
    /// The squares holding a pawn in the root position, so that root moves
    /// (made, or judged after the search) are known exactly as promotions.
    root_pawn: [128]bool = @splat(false),

    // --------------------------------------------------- triangular PV table
    pv: [max_line][max_line]Move = undefined,
    pv_len: [max_line]usize = @splat(0),
    /// The root move that most recently raised the root alpha.
    alpha1: ?Move = null,

    // --------------------------------------------------------- refutations
    /// For each root move searched in the current pass: the ply-2 reply that
    /// cut it off (UCI_ShowRefutations).
    refutations: [256]struct { root: Move, reply: Move } = undefined,
    refutation_count: usize = 0,

    /// The State being searched (for the current line).
    state: ?*const State = null,

    pub fn observer(self: *Info) Observer {
        return .{
            .ctx = self,
            .onMake = onMake,
            .onEval = onEval,
            .onNode = onNode,
            .onRootGenerated = onRootGenerated,
            .onRootScored = onRootScored,
            .onPassStart = onPassStart,
            .onRootMove = onRootMove,
            .onAlpha = onAlpha,
            .onNewBest = onNewBest,
            .onCutoff = onCutoff,
            .onPassDone = onPassDone,
            .onBookMove = onBookMove,
        };
    }

    fn get(ctx: ?*anyopaque) *Info {
        return @ptrCast(@alignCast(ctx.?));
    }

    fn onMake(ctx: ?*anyopaque, ply: u8, from: u8, to: u8) void {
        const self = get(ctx);
        self.nodes += 1;
        if (ply > self.seldepth) self.seldepth = ply;
        // The child line of a move made at this ply is empty until a node
        // below it fills it.
        if (@as(usize, ply) + 1 < max_line) self.pv_len[@as(usize, ply) + 1] = 0;
        if (self.next) |n| n.make(ply, from, to);
    }

    fn onEval(ctx: ?*anyopaque) void {
        if (get(ctx).next) |n| n.evaluated();
    }

    fn onNode(ctx: ?*anyopaque, s: *const State) bool {
        const self = get(ctx);
        self.state = s;
        if (s.ply < max_line) self.pv_len[s.ply] = 0;
        return if (self.next) |n| n.node(s) else false;
    }

    fn onRootGenerated(ctx: ?*anyopaque, s: *const State, h: u32, c: u8) void {
        if (get(ctx).next) |n| n.rootGenerated(s, h, c);
    }

    fn onRootScored(ctx: ?*anyopaque, s: *const State, h: u32, c: u8) void {
        const self = get(ctx);
        for (&self.root_pawn, 0..) |*p, sq| {
            const code = s.board[sq];
            p.* = sq & 0x88 == 0 and code != 0 and s.rec[(code & 0xFB) +% 1] & 0x0F == 1;
        }
        if (self.next) |n| n.rootScored(s, h, c);
    }

    /// A root move: a promotion if a root pawn moves to the last rank.
    fn rootMove(self: *const Info, from: u8, to: u8) Move {
        const promo = from & 0x88 == 0 and self.root_pawn[from] and (to >> 4 == 0 or to >> 4 == 7);
        return .{ .from = from, .to = to, .promo = promo };
    }

    fn onPassStart(ctx: ?*anyopaque, s: *const State, depth: u8, a: u8) void {
        const self = get(ctx);
        self.state = s;
        self.depth = depth;
        self.pass_a = a;
        self.seldepth = 0;
        self.currmovenumber = 0;
        self.pv_len[1] = 0;
        self.alpha1 = null;
        self.refutation_count = 0;
        if (self.next) |n| n.passStart(s, depth, a);
    }

    fn onRootMove(ctx: ?*anyopaque, s: *const State, entry: u32) void {
        const self = get(ctx);
        const e = @constCast(s).entry(entry);
        self.currmove = self.rootMove(e[1] & 0x7F, e[2]);
        self.currmovenumber += 1;
        if (self.reporter.rootMove) |f| f(self.reporter.ctx, self);
        if (self.next) |n| n.rootMove(s, entry);
    }

    fn onAlpha(ctx: ?*anyopaque, s: *const State, ply: u8, from: u8, to: u8) void {
        const self = get(ctx);
        const p: usize = ply;
        if (p + 1 < max_line) {
            const m: Move = .{ .from = from, .to = to, .promo = isPromotion(s, from, to) };
            self.pv[p][0] = m;
            const child = self.pv_len[p + 1];
            @memcpy(self.pv[p][1 .. 1 + child], self.pv[p + 1][0..child]);
            self.pv_len[p] = 1 + child;
            if (p == 1) self.alpha1 = m;
        }
        if (self.next) |n| n.alpha(s, ply, from, to);
    }

    fn onNewBest(ctx: ?*anyopaque, s: *const State, entry: u32) void {
        const self = get(ctx);
        const e = @constCast(s).entry(entry);
        const m = self.rootMove(e[1] & 0x7F, e[2]);
        if (self.alpha1) |a| {
            if (a.from == m.from and a.to == m.to) {
                @memcpy(self.best[0..self.pv_len[1]], self.pv[1][0..self.pv_len[1]]);
                self.best_len = self.pv_len[1];
                self.best[0] = m;
            } else {
                self.best[0] = m;
                self.best_len = 1;
            }
        } else {
            self.best[0] = m;
            self.best_len = 1;
        }
        self.score = s.value[1];
        self.mate_ply = s.best_mate_ply;
        if (self.reporter.newBest) |f| f(self.reporter.ctx, self);
        if (self.next) |n| n.newBest(s, entry);
    }

    fn onCutoff(ctx: ?*anyopaque, s: *const State, ply: u8) void {
        const self = get(ctx);
        if (ply == 2 and s.depth >= 2 and self.refutation_count < self.refutations.len) {
            const r = s.curmove[2];
            self.refutations[self.refutation_count] = .{
                .root = self.currmove,
                .reply = .{ .from = r[0] & 0x7F, .to = r[1], .promo = false },
            };
            self.refutation_count += 1;
        }
        if (self.next) |n| n.cutoff(s, ply);
    }

    fn onPassDone(ctx: ?*anyopaque, s: *const State) void {
        const self = get(ctx);
        const aborted = s.search_flags & 0x80 != 0;
        if (!aborted) self.completed_depth = self.depth;
        if (self.reporter.passDone) |f| f(self.reporter.ctx, self, aborted);
        if (self.next) |n| n.passDone(s);
    }

    fn onBookMove(ctx: ?*anyopaque, s: *const State, entry: u32) void {
        const self = get(ctx);
        const e = @constCast(s).entry(entry);
        const m: Move = .{ .from = e[1], .to = e[2], .promo = isPromotion(s, e[1], e[2]) };
        self.book_move = m;
        self.best[0] = m;
        self.best_len = 1;
        if (self.reporter.book) |f| f(self.reporter.ctx, self);
        if (self.next) |n| n.bookMove(s, entry);
    }

    // ----------------------------------------------------------- formatting
    /// `score cp X` or `score mate M` for the current best line.
    pub fn writeScore(self: *const Info, w: *std.Io.Writer) !void {
        const v = self.score;
        if (v >= 0xFE) {
            // A forced mate for the engine: the shortest root mate ply
            // ($BD0C, the ply of the mated side's node) gives the distance;
            // otherwise the reporting PV's length.
            const plies: usize = if (self.mate_ply != 0xFF and self.mate_ply >= 2) self.mate_ply - 1 else self.best_len;
            try w.print("score mate {d}", .{@max(1, (plies + 1) / 2)});
        } else if (v != 0 and v <= 2) {
            try w.print("score mate -{d}", .{@max(1, self.best_len / 2)});
        } else {
            const cp: i32 = @divTrunc((@as(i32, v) - 0x80) * 100, 8);
            try w.print("score cp {d}", .{cp});
        }
    }

    /// `pv m1 m2 ...` of the best line.
    pub fn writePv(self: *const Info, w: *std.Io.Writer) !void {
        try w.writeAll("pv");
        var buf: [5]u8 = undefined;
        for (self.best[0..self.best_len]) |m| {
            try w.writeAll(" ");
            try w.writeAll(m.uci(&buf));
        }
    }

    /// The current line (UCI_ShowCurrLine): the root move and the moves at
    /// plies 2 .. current ply, from the current-move table. Promotion flags
    /// are left to the caller, which replays the line from the root.
    pub fn currLine(self: *const Info, out: []Move) usize {
        if (out.len == 0) return 0;
        out[0] = self.currmove;
        var n: usize = 1;
        const s = self.state orelse return n;
        var q: usize = 2;
        while (q < s.ply and q < max_line and n < out.len) : (q += 1) {
            const m: Move = .{ .from = s.curmove[q][0] & 0x7F, .to = s.curmove[q][1] };
            if (m.from & 0x88 != 0 or m.to & 0x88 != 0) break;
            out[n] = m;
            n += 1;
        }
        return n;
    }
};

test "move notation" {
    var buf: [5]u8 = undefined;
    const m: Move = .{ .from = 0x64, .to = 0x44 }; // e2e4: e2 = row 6, e4 = row 4
    try std.testing.expectEqualStrings("e2e4", m.uci(&buf));
    const p: Move = .{ .from = 0x14, .to = 0x04, .promo = true };
    try std.testing.expectEqualStrings("e7e8q", p.uci(&buf));
}

test "score formatting" {
    var info: Info = .{};
    var buf: [64]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    info.score = 0x88;
    try info.writeScore(&w);
    try std.testing.expectEqualStrings("score cp 100", w.buffered());
    w = .fixed(&buf);
    info.score = 0x7C;
    try info.writeScore(&w);
    try std.testing.expectEqualStrings("score cp -50", w.buffered());
    w = .fixed(&buf);
    info.score = 0xFE;
    info.mate_ply = 4; // mated side's node at ply 4: mate in 2
    try info.writeScore(&w);
    try std.testing.expectEqualStrings("score mate 2", w.buffered());
}

test "reporting does not change the search (anchors with the info observer attached)" {
    const dt = @import("driver_test.zig");
    var info: Info = .{};
    const obs = info.observer();
    const t = try dt.runAnchors("search.jsonl.gz", &obs);
    try std.testing.expectEqual(@as(usize, 0), t.bad);
    try std.testing.expect(info.nodes > 0);
}
