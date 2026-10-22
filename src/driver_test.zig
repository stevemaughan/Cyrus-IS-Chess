//! Anchor tests of the extended driver (docs/EXTENDED_SEARCH.md §8): from
//! every golden computer move at Level 1, 2, 6, 7 or 8, extended mode at depth
//! 1, 2, 4, 4, 4 (profile = that level) must reproduce the original exactly,
//! including interrupted searches (abort.jsonl.gz).

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const golden = @import("golden.zig");
const search = @import("search.zig");
const driver = @import("driver.zig");
const Observer = @import("observer.zig").Observer;

const Sha256 = std.crypto.hash.sha2.Sha256;

pub const HashProbe = struct {
    sha: Sha256 = .init(.{}),
    makes: i64 = 0,
    evals: i64 = 0,
    nodes: i64 = 0,
    abort_at: ?i64 = null,
    /// Another observer to forward every event to (e.g. the info collector).
    next: ?*const Observer = null,

    pub fn observer(p: *HashProbe) Observer {
        return .{
            .ctx = p,
            .onMake = onMake,
            .onEval = onEval,
            .onNode = onNode,
            .onRootGenerated = fwdRootGenerated,
            .onRootScored = fwdRootScored,
            .onPassStart = fwdPassStart,
            .onRootMove = fwdRootMove,
            .onAlpha = fwdAlpha,
            .onNewBest = fwdNewBest,
            .onCutoff = fwdCutoff,
            .onPassDone = fwdPassDone,
            .onBookMove = fwdBookMove,
        };
    }

    fn self(ctx: ?*anyopaque) *HashProbe {
        return @ptrCast(@alignCast(ctx.?));
    }
    fn onMake(ctx: ?*anyopaque, ply: u8, from: u8, to: u8) void {
        const p = self(ctx);
        p.sha.update(&.{ ply, from, to });
        p.makes += 1;
        if (p.next) |n| n.make(ply, from, to);
    }
    fn onEval(ctx: ?*anyopaque) void {
        const p = self(ctx);
        p.evals += 1;
        if (p.next) |n| n.evaluated();
    }
    fn onNode(ctx: ?*anyopaque, s: *const State) bool {
        const p = self(ctx);
        p.nodes += 1;
        if (p.next) |n| _ = n.node(s);
        return if (p.abort_at) |a| a == p.nodes else false;
    }
    fn fwdRootGenerated(ctx: ?*anyopaque, s: *const State, h: u32, c: u8) void {
        if (self(ctx).next) |n| n.rootGenerated(s, h, c);
    }
    fn fwdRootScored(ctx: ?*anyopaque, s: *const State, h: u32, c: u8) void {
        if (self(ctx).next) |n| n.rootScored(s, h, c);
    }
    fn fwdPassStart(ctx: ?*anyopaque, s: *const State, d: u8, a: u8) void {
        if (self(ctx).next) |n| n.passStart(s, d, a);
    }
    fn fwdRootMove(ctx: ?*anyopaque, s: *const State, e: u32) void {
        if (self(ctx).next) |n| n.rootMove(s, e);
    }
    fn fwdAlpha(ctx: ?*anyopaque, s: *const State, ply: u8, from: u8, to: u8) void {
        if (self(ctx).next) |n| n.alpha(s, ply, from, to);
    }
    fn fwdNewBest(ctx: ?*anyopaque, s: *const State, e: u32) void {
        if (self(ctx).next) |n| n.newBest(s, e);
    }
    fn fwdCutoff(ctx: ?*anyopaque, s: *const State, ply: u8) void {
        if (self(ctx).next) |n| n.cutoff(s, ply);
    }
    fn fwdPassDone(ctx: ?*anyopaque, s: *const State) void {
        if (self(ctx).next) |n| n.passDone(s);
    }
    fn fwdBookMove(ctx: ?*anyopaque, s: *const State, e: u32) void {
        if (self(ctx).next) |n| n.bookMove(s, e);
    }

    pub fn hex(p: *HashProbe) [64]u8 {
        var digest: [32]u8 = undefined;
        p.sha.final(&digest);
        var out: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&out, "{x}", .{&digest}) catch unreachable;
        return out;
    }
};

/// The extended plan that reproduces the original level the search actually
/// ran at: the level index $BCCD of the captured state (a golden file's
/// `level` label is what the session asked for; a continuation move keeps the
/// previous level, as in the oracle). Null for levels without an anchor.
pub fn anchorPlan(level_index: u8) ?driver.Plan {
    return switch (level_index) {
        0 => .{ .max_depth = 1 },
        1 => .{ .max_depth = 2 },
        5 => .{ .max_depth = 4, .profile = .level6 },
        6 => .{ .max_depth = 4, .profile = .level7 },
        7 => .{ .max_depth = 4, .profile = .level8 },
        else => null,
    };
}

fn stateLevelIndex(state_obj: std.json.ObjectMap) !u8 {
    const hex = state_obj.get("bc83").?.string;
    const i = (0xBCCD - 0xBC83) * 2;
    return std.fmt.parseInt(u8, hex[i .. i + 2], 16);
}

fn sqName(buf: *[2]u8, sq: u8) []const u8 {
    buf[0] = 'a' + (sq & 7);
    buf[1] = '0' + (8 - (sq >> 4));
    return buf;
}

/// Run one golden `go` through the extended driver; the name of the first
/// differing field, or null.
pub fn checkAnchor(s: *State, plan: driver.Plan, state_obj: std.json.ObjectMap, r_arr: std.json.Array, abort_at: ?i64, out: std.json.ObjectMap, next: ?*const Observer) !?[]const u8 {
    s.* = .{};
    try golden.loadState(s, state_obj);
    var rb: [64]u8 = undefined;
    for (r_arr.items, 0..) |v, k| rb[k] = @intCast(v.integer);
    var scripted: st.ScriptedR = .{ .bytes = rb[0..r_arr.items.len] };
    var r = scripted.source();
    var probe: HashProbe = .{ .abort_at = abort_at, .next = next };
    const obs = probe.observer();
    const outcome = driver.computerMove(s, &r, &obs, .{}, plan);
    const result: []const u8 = switch (outcome) {
        .move => "move",
        .no_moves => "nomoves",
        .no_mate => "nomate",
    };
    const want_result = out.get("result").?.string;
    // Problem levels report "nomate" from the main loop; not in this test.
    if (!std.mem.eql(u8, result, want_result)) return "result";
    if (outcome == .move) {
        const e = s.entry(outcome.move);
        var b1: [2]u8 = undefined;
        var b2: [2]u8 = undefined;
        var mv: [4]u8 = undefined;
        @memcpy(mv[0..2], sqName(&b1, e[1]));
        @memcpy(mv[2..4], sqName(&b2, e[2]));
        if (!std.mem.eql(u8, &mv, out.get("move").?.string)) return "move";
    }
    const h = probe.hex();
    if (!std.mem.eql(u8, &h, out.get("make_sha256").?.string)) return "make_sha256";
    if (probe.makes != try golden.int(out, "makes")) return "makes";
    if (probe.evals != try golden.int(out, "evals")) return "evals";
    if (probe.nodes != try golden.int(out, "nodes")) return "nodes";
    if (@as(i64, @intCast(scripted.used)) != try golden.int(out, "r_used")) return "r_used";
    if (s.value[1] != try golden.int(out, "BCA0")) return "BCA0";
    if (s.best_mate_ply != try golden.int(out, "BD0C")) return "BD0C";
    if (s.random != try golden.int(out, "bcce_after")) return "bcce_after";
    return null;
}

pub const Totals = struct { checked: usize = 0, bad: usize = 0 };

/// Every anchor-level `go` of a search-format golden file.
pub fn runAnchors(name: []const u8, next: ?*const Observer) !Totals {
    const gpa = std.testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, name));
    defer g.deinit();
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var t: Totals = .{};
    for (0..g.lines.len) |i| {
        var p = try g.parse(gpa, i);
        defer p.deinit();
        const rec = p.value.object;
        var gos: [16]std.json.Array = undefined;
        var n_gos: usize = 0;
        for (rec.get("session").?.array.items) |op| {
            if (std.mem.eql(u8, op.object.get("op").?.string, "go")) {
                gos[n_gos] = op.object.get("r").?.array;
                n_gos += 1;
            }
        }
        for (rec.get("goes").?.array.items, 0..) |go, k| {
            const state_v = go.object.get("state") orelse continue;
            if (state_v != .object) continue;
            const plan = anchorPlan(try stateLevelIndex(state_v.object)) orelse continue;
            const out = go.object.get("out").?.object;
            if (out.get("root").?.array.items.len >= 127) continue; // DEV-001
            t.checked += 1;
            if (try checkAnchor(s, plan, state_v.object, gos[k], null, out, next)) |field| {
                if (t.bad < 8) std.debug.print("{s} line {d} go {d} ({s}): {s} differs\n", .{ name, i, k, go.object.get("level").?.string, field });
                t.bad += 1;
            }
        }
    }
    return t;
}

test "anchors: extended depth 1/2/4 = original Levels 1/2/6/7/8 (search.jsonl.gz)" {
    const t = try runAnchors("search.jsonl.gz", null);
    std.debug.print("anchors search.jsonl.gz: {d} checked, {d} differ\n", .{ t.checked, t.bad });
    try std.testing.expect(t.checked > 1700);
    try std.testing.expectEqual(@as(usize, 0), t.bad);
}

test "anchors: edge.jsonl.gz and book.jsonl.gz" {
    const e = try runAnchors("edge.jsonl.gz", null);
    const b = try runAnchors("book.jsonl.gz", null);
    std.debug.print("anchors edge: {d}/{d} bad; book: {d}/{d} bad\n", .{ e.bad, e.checked, b.bad, b.checked });
    try std.testing.expectEqual(@as(usize, 0), e.bad + b.bad);
}

test "anchors: interrupted searches (abort.jsonl.gz)" {
    const gpa = std.testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, "abort.jsonl.gz"));
    defer g.deinit();
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var checked: usize = 0;
    var bad: usize = 0;
    for (0..g.lines.len) |i| {
        var p = try g.parse(gpa, i);
        defer p.deinit();
        const rec = p.value.object;
        const plan = anchorPlan(try stateLevelIndex(rec.get("state").?.object)) orelse continue;
        checked += 1;
        if (try checkAnchor(s, plan, rec.get("state").?.object, rec.get("r").?.array, try golden.int(rec, "abort_at_node"), rec.get("out").?.object, null)) |field| {
            if (bad < 8) std.debug.print("abort line {d} ({s}): {s} differs\n", .{ i, rec.get("level").?.string, field });
            bad += 1;
        }
    }
    std.debug.print("anchors abort: {d} checked, {d} differ\n", .{ checked, bad });
    try std.testing.expect(checked > 100);
    try std.testing.expectEqual(@as(usize, 0), bad);
}

/// Highest list address reached: the node's header, and the end of the list
/// generated below it (slot[ply + 1], set by the generator).
const ListProbe = struct {
    max_slot: u32 = 0,

    fn onNode(ctx: ?*anyopaque, s: *const State) bool {
        const p: *ListProbe = @ptrCast(@alignCast(ctx.?));
        p.max_slot = @max(p.max_slot, s.slot[s.ply], s.slot[s.ply + 1]);
        return false;
    }
};

test "deep search robustness (zig build test -Ddeep=true)" {
    const deep = @import("build_options").deep;
    if (!deep.enabled) return error.SkipZigTest;
    const gpa = std.testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, "search.jsonl.gz"));
    defer g.deinit();
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var positions: usize = 0;
    var max_slot: u32 = 0;
    var i: usize = 0;
    while (positions < deep.positions and i < g.lines.len) : (i += 7) {
        var p = try g.parse(gpa, i);
        defer p.deinit();
        const goes = p.value.object.get("goes").?.array.items;
        if (goes.len == 0) continue;
        const state_v = goes[goes.len / 2].object.get("state") orelse continue;
        if (state_v != .object) continue;
        s.* = .{};
        try golden.loadState(s, state_v.object);
        max_slot = @max(max_slot, try deepSearch(s, @intCast(6 + positions % 3)));
        positions += 1;
    }
    std.debug.print("deep: {d} positions at depth 6-8, highest list header ${X}\n", .{ positions, max_slot });
    try std.testing.expect(positions > 0);

    // A line that needs more than the original's 544 list entries (CR-02),
    // and a sparse position searched to depth 14 (seldepth 17+).
    const game = @import("game.zig");
    for ([_]struct { fen: []const u8, depth: u8, beyond_original: bool }{
        .{ .fen = "3qk3/8/q6q/8/8/Q6Q/8/3QK3 w - - 0 1", .depth = 6, .beyond_original = true },
        .{ .fen = "k7/2p5/K1P5/8/8/8/8/8 w - - 0 1", .depth = 14, .beyond_original = false },
    }) |c| {
        s.* = .{};
        _ = try game.loadFen(s, c.fen);
        _ = game.keyMove(s);
        const top = try deepSearch(s, c.depth);
        std.debug.print("deep: {s} depth {d}, highest list header ${X}\n", .{ c.fen, c.depth, top });
        if (c.beyond_original) try std.testing.expect(top > st.list_end_original);
    }
}

/// One extended search to `depth` in the extended list area. It must not
/// abort (capacity or otherwise) and must return a legal move. Returns the
/// highest list header reached.
fn deepSearch(s: *State, depth: u8) !u32 {
    const legal = @import("legal.zig");
    s.list_limit = st.listAddr(st.list_bytes_extended - 64);
    var rb: [256]u8 = @splat(0x5A);
    var scripted: st.ScriptedR = .{ .bytes = &rb };
    var r = scripted.source();
    var lp: ListProbe = .{};
    const obs: Observer = .{ .ctx = &lp, .onNode = ListProbe.onNode };
    const outcome = driver.computerMove(s, &r, &obs, .{}, .{ .profile = .level8, .max_depth = depth });
    try std.testing.expect(s.search_flags & 0x80 == 0);
    if (outcome == .move) {
        const e = s.entry(outcome.move);
        try std.testing.expect(legal.isLegal(s, e[1] & 0x7F, e[2]));
    }
    try std.testing.expect(lp.max_slot < 0x10000 + st.list_bytes_extended);
    return lp.max_slot;
}
