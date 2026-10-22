//! Static scoring and move lookup, shared by the search and the game layer:
//! SCOREMOVES ($7B96-$7BCC) and FINDMOVE ($7BCD-$7BE0).
//! Spec: docs/arch/30-search.md §4.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const board = @import("board.zig");
const eval = @import("eval.zig");
const Observer = @import("observer.zig").Observer;

/// Make, evaluate and unmake the move at `entry`, counting both for the
/// observer. Returns the evaluation (0 = illegal).
pub fn makeEvalUnmake(s: *State, entry: u32, obs: *const Observer) u8 {
    var undo: board.Undo = undefined;
    const e = s.entry(entry);
    obs.make(s.ply, e[1], e[2]);
    board.make(s, entry, &undo);
    obs.evaluated();
    const a = eval.evaluate(s, entry).a;
    s.entry(entry)[0] = a;
    board.unmake(s, &undo);
    return a;
}

/// SCOREMOVES ($7B96): for each of the `count` entries after the header at
/// `header3` (the header's byte +3) whose score byte is still $FF, make the
/// move, store its evaluation as the score and unmake it. Records the best
/// score in $BD19 and its entry in $BD1A; equal scores go to the later entry.
pub fn scoreMoves(s: *State, header3: u32, count: u8, obs: *const Observer) void {
    var ix = header3 + 1;
    s.best_static = 0;
    // $7B9E: the counter $BD0E = count + 1, decremented before each entry.
    s.score_count = count +% 1;
    while (true) {
        s.score_count -%= 1;
        if (s.score_count == 0) return;
        if (s.entry(ix)[0] == 0xFF) {
            const a = makeEvalUnmake(s, ix, obs);
            if (a >= s.best_static) {
                s.best_static = a;
                s.best_static_entry = ix;
            }
        }
        ix = nextEntry(ix);
    }
}

/// The address of the entry after `addr` (lists are contiguous).
pub fn nextEntry(addr: u32) u32 {
    return st.listAddr(st.listOffset(addr) + 4);
}

/// FINDMOVE ($7BCD): scan `n` entries after `header2` (a header's byte +2) for
/// the move (from, to). A count of 0 means 256 (DJNZ). Returns the entry's
/// address, or null with `last` set to the byte +2 of the last entry tested
/// (callers in the original use that address when they ignore "not found";
/// see DEV-004).
pub fn findMove(s: *State, header2: u32, n: u8, from: u8, to: u8, last: ?*u32) ?u32 {
    var a = header2;
    var b: u16 = if (n == 0) 256 else n;
    while (b > 0) : (b -= 1) {
        a = nextEntry(a);
        const e = s.entry(a - 2);
        if (e[2] == to and e[1] == from) return a - 2;
    }
    if (last) |l| l.* = a;
    return null;
}

test "root scoring matches the original (root_scored in search.jsonl.gz)" {
    const golden = @import("golden.zig");
    const movegen = @import("movegen.zig");
    const gpa = std.testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, "search.jsonl.gz"));
    defer g.deinit();
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var n: usize = 0;
    var bad: usize = 0;
    for (0..g.lines.len) |i| {
        var p = try g.parse(gpa, i);
        defer p.deinit();
        for (p.value.object.get("goes").?.array.items) |go| {
            const out = go.object.get("out").?.object;
            const want = out.get("root_scored") orelse continue;
            s.* = .{};
            try golden.loadState(s, go.object.get("state").?.object);
            s.search_flags = 0x40; // ComputerMove $614E
            const r = movegen.generate(s, st.root_record);
            scoreMoves(s, r.header, r.count, &@import("observer.zig").none);
            n += 1;
            for (want.array.items, 0..) |item, k| {
                const e = s.entry(st.listAddr(4 + 4 * @as(u32, @intCast(k))));
                const score: u8 = @intCast(item.array.items[0].integer);
                const flags: u8 = @intCast(item.array.items[1].integer);
                if (e[0] != score or e[3] != flags) {
                    if (bad < 5) std.debug.print("root scoring {d}/{d}: entry {d} got {x}/{x} want {x}/{x}\n", .{ i, n, k, e[0], e[3], score, flags });
                    bad += 1;
                    break;
                }
            }
        }
    }
    try std.testing.expect(n > 4000);
    try std.testing.expectEqual(@as(usize, 0), bad);
}
