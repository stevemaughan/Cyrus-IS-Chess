//! Golden-file tests of the search and the computer-move path against the
//! original (tests/golden: search, edge, book, abort). Each computer move is
//! re-run from its captured state with the oracle's random bytes; the make
//! sequence (SHA-256 of ply, from, to per make), the counts and the results
//! must be identical.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const golden = @import("golden.zig");
const search = @import("search.zig");
const Observer = @import("observer.zig").Observer;
const book = @import("book.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;

/// Test observer: hashes and counts makes, counts evaluations and nodes,
/// presses a key at node `abort_at`, and captures the root list.
const Probe = struct {
    sha: Sha256 = .init(.{}),
    makes: i64 = 0,
    evals: i64 = 0,
    nodes: i64 = 0,
    abort_at: ?i64 = null,
    book: bool = false,
    root_count: u8 = 0,
    root: [256][3]u8 = undefined,
    root_scored: [256][2]u8 = undefined,
    root_len: usize = 0,

    fn observer(p: *Probe) Observer {
        return .{
            .ctx = p,
            .onMake = onMake,
            .onEval = onEval,
            .onNode = onNode,
            .onRootGenerated = onRootGenerated,
            .onRootScored = onRootScored,
            .onBookMove = onBookMove,
        };
    }

    fn self(ctx: ?*anyopaque) *Probe {
        return @ptrCast(@alignCast(ctx.?));
    }

    fn onMake(ctx: ?*anyopaque, ply: u8, from: u8, to: u8) void {
        const p = self(ctx);
        p.sha.update(&.{ ply, from, to });
        p.makes += 1;
    }

    fn onEval(ctx: ?*anyopaque) void {
        self(ctx).evals += 1;
    }

    fn onNode(ctx: ?*anyopaque, s: *const State) bool {
        _ = s;
        const p = self(ctx);
        p.nodes += 1;
        return if (p.abort_at) |n| n == p.nodes else false;
    }

    fn rootEntries(s: *const State, header3: u32) []const u8 {
        const start = st.listOffset(header3 - 3) + 4;
        const end = st.listOffset(s.slot[2]);
        return s.lists[start..end];
    }

    fn onRootGenerated(ctx: ?*anyopaque, s: *const State, header3: u32, count: u8) void {
        const p = self(ctx);
        p.root_count = count;
        const bytes = rootEntries(s, header3);
        p.root_len = bytes.len / 4;
        for (0..p.root_len) |k| p.root[k] = .{ bytes[4 * k + 1], bytes[4 * k + 2], bytes[4 * k + 3] };
    }

    fn onRootScored(ctx: ?*anyopaque, s: *const State, header3: u32, count: u8) void {
        _ = count;
        const p = self(ctx);
        const bytes = rootEntries(s, header3);
        for (0..bytes.len / 4) |k| p.root_scored[k] = .{ bytes[4 * k], bytes[4 * k + 3] };
    }

    fn onBookMove(ctx: ?*anyopaque, s: *const State, entry: u32) void {
        _ = s;
        _ = entry;
        self(ctx).book = true;
    }
};

fn sqName(buf: []u8, sq: u8) []const u8 {
    if (sq & 0x88 != 0) return "??";
    buf[0] = 'a' + (sq & 7);
    buf[1] = '0' + (8 - (sq >> 4));
    return buf[0..2];
}

const Mismatch = error{Mismatch};

/// Run one computer move from a golden `go` and compare everything.
/// Returns the name of the first differing field, or null.
fn checkGo(s: *State, state_obj: std.json.ObjectMap, r_arr: std.json.Array, abort_at: ?i64, out: std.json.ObjectMap) !?[]const u8 {
    s.* = .{};
    try golden.loadState(s, state_obj);
    var rb: [64]u8 = undefined;
    for (r_arr.items, 0..) |v, k| rb[k] = @intCast(v.integer);
    var scripted: st.ScriptedR = .{ .bytes = rb[0..r_arr.items.len] };
    var r = scripted.source();
    var probe: Probe = .{ .abort_at = abort_at };
    const obs = probe.observer();
    const outcome = search.computerMove(s, &r, &obs, .{});

    const result: []const u8 = switch (outcome) {
        .move => "move",
        .no_moves => "nomoves",
        .no_mate => "nomate",
    };
    if (!std.mem.eql(u8, result, out.get("result").?.string)) return "result";
    if (outcome == .move) {
        const e = s.entry(outcome.move);
        var b1: [2]u8 = undefined;
        var b2: [2]u8 = undefined;
        var mv: [4]u8 = undefined;
        @memcpy(mv[0..2], sqName(&b1, e[1]));
        @memcpy(mv[2..4], sqName(&b2, e[2]));
        if (!std.mem.eql(u8, &mv, out.get("move").?.string)) return "move";
        const index = (@as(i64, st.listOffset(outcome.move)) - 4) >> 2;
        if (index != try golden.int(out, "index")) return "index";
        if (probe.book != out.get("book").?.bool) return "book";
    }
    var digest: [32]u8 = undefined;
    probe.sha.final(&digest);
    var hex: [64]u8 = undefined;
    _ = std.fmt.bufPrint(&hex, "{x}", .{&digest}) catch unreachable;
    if (!std.mem.eql(u8, &hex, out.get("make_sha256").?.string)) return "make_sha256";
    if (probe.makes != try golden.int(out, "makes")) return "makes";
    if (probe.evals != try golden.int(out, "evals")) return "evals";
    if (probe.nodes != try golden.int(out, "nodes")) return "nodes";
    if (@as(i64, @intCast(scripted.used)) != try golden.int(out, "r_used")) return "r_used";
    if (s.value[1] != try golden.int(out, "BCA0")) return "BCA0";
    if (s.best_mate_ply != try golden.int(out, "BD0C")) return "BD0C";
    if (s.random != try golden.int(out, "bcce_after")) return "bcce_after";
    if (probe.root_count != try golden.int(out, "root_count")) return "root_count";
    const root = out.get("root").?.array.items;
    if (root.len != probe.root_len) return "root length";
    for (root, 0..) |item, k| {
        for (0..3) |j| if (item.array.items[j].integer != probe.root[k][j]) return "root";
    }
    for (out.get("root_scored").?.array.items, 0..) |item, k| {
        for (0..2) |j| if (item.array.items[j].integer != probe.root_scored[k][j]) return "root_scored";
    }
    return null;
}

const Totals = struct { checked: usize = 0, bad: usize = 0, dev001: usize = 0 };

/// Every `go` of a search-format golden file (search, edge, book).
fn runSessions(name: []const u8) !Totals {
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
            if (state_v != .object) continue; // main loop declared a draw first
            const out = go.object.get("out").?.object;
            if (out.get("root").?.array.items.len >= 127) {
                // DEV-001: the port stores the true move count; these differ.
                t.dev001 += 1;
                continue;
            }
            t.checked += 1;
            if (try checkGo(s, state_v.object, gos[k], null, out)) |field| {
                if (t.bad < 8) std.debug.print("{s} line {d} go {d} (seed {d}, {s}): {s} differs\n", .{ name, i, k, rec.get("seed").?.integer, go.object.get("level").?.string, field });
                t.bad += 1;
            }
        }
    }
    return t;
}

test "search: search.jsonl.gz" {
    const t = try runSessions("search.jsonl.gz");
    std.debug.print("search.jsonl.gz: {d} checked, {d} differ\n", .{ t.checked, t.bad });
    try std.testing.expectEqual(@as(usize, 4028), t.checked);
    try std.testing.expectEqual(@as(usize, 0), t.bad);
}

test "search: edge.jsonl.gz (DEV-001 cases listed separately)" {
    const t = try runSessions("edge.jsonl.gz");
    std.debug.print("edge.jsonl.gz: {d} checked, {d} differ, {d} DEV-001 cases skipped\n", .{ t.checked, t.bad, t.dev001 });
    try std.testing.expect(t.checked > 100);
    try std.testing.expectEqual(@as(usize, 0), t.bad);
}

test "search: book.jsonl.gz" {
    const t = try runSessions("book.jsonl.gz");
    std.debug.print("book.jsonl.gz: {d} checked, {d} differ\n", .{ t.checked, t.bad });
    try std.testing.expectEqual(@as(usize, 4572), t.checked);
    try std.testing.expectEqual(@as(usize, 0), t.bad);
}

test "search: abort.jsonl.gz (key press at node N)" {
    const gpa = std.testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, "abort.jsonl.gz"));
    defer g.deinit();
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var bad: usize = 0;
    for (0..g.lines.len) |i| {
        var p = try g.parse(gpa, i);
        defer p.deinit();
        const rec = p.value.object;
        if (try checkGo(s, rec.get("state").?.object, rec.get("r").?.array, try golden.int(rec, "abort_at_node"), rec.get("out").?.object)) |field| {
            if (bad < 8) std.debug.print("abort line {d}: {s} differs\n", .{ i, field });
            bad += 1;
        }
    }
    std.debug.print("abort.jsonl.gz: {d} checked, {d} differ\n", .{ g.lines.len, bad });
    try std.testing.expectEqual(@as(usize, 400), g.lines.len);
    try std.testing.expectEqual(@as(usize, 0), bad);
}
