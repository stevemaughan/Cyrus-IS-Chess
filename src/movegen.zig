//! Move generator: port of GENMOVES ($78CE-$7AC6), without the key poll at
//! $78BA (that belongs to the search). Spec: docs/arch/20-board-movegen.md
//! §4.2 (note: that document uses a mirrored board convention; the semantics
//! here follow the code). Phase 3 unit 3.4.
//!
//! The generator is pseudo-legal and its order is part of the behaviour: it is
//! the slot order of the piece records (castling, king, Q, R, R, B, B, N, N,
//! then the eight pawn slots), with fixed direction orders. Pawn captures and
//! a few neighbour tests read the board without an edge check; those reads go
//! through `State.square`, which returns what the original would see.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const tables = @import("tables.zig");

pub const Result = struct {
    /// E: number of moves written. The original computes ((n + 1) mod 128) - 1,
    /// which is wrong for 127 or more moves; this port stores the true count
    /// (DEV-001). `originalCount` gives the original's value.
    count: u8,
    /// HL: address of the header's byte +3 (flags).
    header: u32,
};

/// The header count the original computes for `n` moves ($79AF-$79B8):
/// (end - start) >> 2 keeps only 9 bits, so the result is ((n + 1) & $7F) - 1.
pub fn originalCount(n: u32) u8 {
    return @as(u8, @truncate((n + 1) & 0x7F)) -% 1;
}

/// GENMOVES ($78CE): generate the moves of the side selected by bit 0 of
/// `s.side_phase` (0: records $BE00-$BE7F, 1: records $BE80-$BEFF) into the
/// list of ply `s.ply`, which starts at `s.slot[s.ply]`. Writes the header,
/// the entries [score $FF, from, to, flags] and the terminator, and stores the
/// terminator's address in `s.slot[s.ply + 1]`. `ix` is the move that led here
/// (the root record at the root): its flags bit 7 (in check) suppresses
/// castling, and its to-square and flags drive en passant. If the list area
/// is full, moves are not written and the abort flag (`s.search_flags` bit 7)
/// is set ($7A9D).
pub fn generate(s: *State, ix: u32) Result {
    const p = s.ply;
    const start = st.listOffset(s.slot[p]);
    const ix_entry = s.entry(ix).*;
    const side: u8 = s.side_phase & 1;
    var g: Gen = .{
        .s = s,
        .out = start + 4,
        .side_sign = side << 7,
        .ix_to = ix_entry[2],
        .ix_flags = ix_entry[3],
    };
    const base: u8 = if (side == 1) 0x80 else 0x00; // IY: the side's piece records

    // King ($78F6): castling first if the king has not moved, then 8 steps.
    // The king's square is used even if its captured bit is set.
    const king = s.rec[base];
    if (s.rec[base + 1] & 0x10 == 0) g.castle(king, base);
    g.steps(king, tables.all_offsets);

    // Q, R, R, B, B, N, N in slot order, each if present ($7909-$7939).
    if (s.rec[base + 0x08] & 0x80 == 0) g.slide(s.rec[base + 0x08], tables.all_offsets);
    if (s.rec[base + 0x10] & 0x80 == 0) g.slide(s.rec[base + 0x10], tables.orthogonal_offsets);
    if (s.rec[base + 0x18] & 0x80 == 0) g.slide(s.rec[base + 0x18], tables.orthogonal_offsets);
    if (s.rec[base + 0x20] & 0x80 == 0) g.slide(s.rec[base + 0x20], tables.diagonal_offsets);
    if (s.rec[base + 0x28] & 0x80 == 0) g.slide(s.rec[base + 0x28], tables.diagonal_offsets);
    if (s.rec[base + 0x30] & 0x80 == 0) g.steps(s.rec[base + 0x30], tables.knight_offsets);
    if (s.rec[base + 0x38] & 0x80 == 0) g.steps(s.rec[base + 0x38], tables.knight_offsets);

    // Pawn slots ($793C-$79A2). C = capture-right offset: $11 for the records
    // at $BE00 (moving towards row 7), $F1 for those at $BE80 (towards row 0).
    const c: u8 = if (side == 1) 0xF1 else 0x11;
    var slot: u8 = 0x40;
    while (true) : (slot += 8) {
        g.pawnSlot(base + slot, c);
        if (slot == 0x78) break;
    }

    // Terminator, next ply's list start and header ($79A5-$79C7).
    s.lists[g.out] = 0xFF;
    s.slot[p + 1] = st.listAddr(g.out);
    const n = (g.out - start) / 4 - 1;
    // DEV-001: the true count (the original's is `originalCount(n)`). A legal
    // position has at most 218 legal moves, so n < 256 in practice; saturate
    // rather than wrap if a pathological set-up ever exceeds it.
    const count: u8 = if (n > 255) 255 else @intCast(n);
    s.lists[start] = 0xFF;
    s.lists[start + 1] = count;
    s.lists[start + 2] = 0;
    s.lists[start + 3] = ix_entry[3] & 0x81;
    return .{ .count = count, .header = st.listAddr(start + 3) };
}

const Gen = struct {
    s: *State,
    /// DE: list offset of the next entry.
    out: u32,
    /// Sign bit of C' ($BD2D rotated right): a piece code whose bit 7 differs
    /// from it belongs to the opponent.
    side_sign: u8,
    ix_to: u8,
    ix_flags: u8,

    fn enemy(g: *const Gen, code: u8) bool {
        return (code ^ g.side_sign) & 0x80 != 0;
    }

    /// ADD_MOVE ($7A9D): append [$FF, from, to, flags] unless the list area is
    /// full, in which case set the abort flag instead.
    fn add(g: *Gen, from: u8, to: u8, flags: u8) void {
        // The original writes while the pointer is <= $BC80 (one entry may
        // still start at $BC80); compared as list offsets so that it holds for
        // both the original and the extended area.
        if (g.out > st.listOffset(g.s.list_limit)) {
            g.s.search_flags |= 0x80;
            return;
        }
        const e = g.s.lists[g.out..][0..4];
        e.* = .{ 0xFF, from, to, flags };
        g.out += 4;
    }

    /// ADD_CAPTURE ($7A97): a capture if `code` belongs to the opponent.
    fn addCapture(g: *Gen, from: u8, to: u8, code: u8) void {
        if (g.enemy(code)) g.add(from, to, 0x08);
    }

    /// GEN_STEPS ($7A18): 8 single steps (king, knight); off-board targets
    /// (sq AND $88) are skipped.
    fn steps(g: *Gen, from: u8, dirs: *const [8]u8) void {
        for (dirs) |d| {
            const to = from +% d;
            if (to & 0x88 != 0) continue;
            const code = g.s.board[to];
            if (code == 0) g.add(from, to, 0) else g.addCapture(from, to, code);
        }
    }

    /// GEN_SLIDE ($7A33/$7A35): slide in each direction until off the board,
    /// adding quiet moves; a piece stops the slide (a capture if it is enemy).
    fn slide(g: *Gen, from: u8, dirs: []const u8) void {
        for (dirs) |d| {
            var to = from;
            while (true) {
                to +%= d;
                if (to & 0x88 != 0) break;
                const code = g.s.board[to];
                if (code != 0) {
                    g.addCapture(from, to, code);
                    break;
                }
                g.add(from, to, 0);
            }
        }
    }

    /// GEN_CASTLE ($7A61): kingside then queenside. Only the parent's check
    /// flag, the rooks' moved/captured bits and the empty squares are tested;
    /// attacked squares are not (root scoring rejects those, see make).
    fn castle(g: *Gen, king: u8, base: u8) void {
        if (g.ix_flags & 0x80 != 0) return;
        const s = g.s;
        if (s.rec[base + 0x19] & 0x10 == 0 and s.rec[base + 0x18] & 0x80 == 0 and
            s.square(king +% 1) == 0 and s.square(king +% 2) == 0)
        {
            g.add(king, king +% 2, 0x10);
        }
        if (s.rec[base + 0x11] & 0x10 != 0) return;
        if (s.rec[base + 0x10] & 0x80 != 0) return;
        if (s.square(king -% 1) != 0) return;
        if (s.square(king -% 2) != 0) return;
        if (s.square(king -% 3) != 0) return;
        g.add(king, king -% 2, 0x10);
    }

    /// One pawn slot ($794C-$799B): a promoted piece is generated as that
    /// piece ($79C8); a pawn gets its captures (right, then left; no edge
    /// check), the single push, the double push from the home rank (flagged
    /// $20 when an enemy pawn lands beside it), and en passant.
    fn pawnSlot(g: *Gen, r: u8, c: u8) void {
        const s = g.s;
        const from = s.rec[r];
        if (from & 0x80 != 0) return; // captured
        const t = s.rec[r + 1];
        if (t & 0x0E != 0) {
            // GEN_PROMOTED ($79C8): dispatch on the type byte.
            if (t & 0x80 != 0) {
                g.slide(from, tables.diagonal_offsets);
            } else if (t & 0x02 != 0) {
                g.steps(from, tables.knight_offsets);
            } else if (t & 0x04 != 0) {
                g.slide(from, tables.orthogonal_offsets);
            } else {
                g.slide(from, tables.all_offsets);
            }
            return;
        }
        var l = from +% c;
        var code = s.square(l);
        if (code != 0) g.addCapture(from, l, code);
        l -%= 2;
        code = s.square(l);
        if (code != 0) g.addCapture(from, l, code);
        l +%= 1; // forward square
        if (s.square(l) == 0) {
            g.add(from, l, 0); // single push; make detects promotion
            if ((from +% 0x20) & 0x40 == 0) {
                // Home rank: double push, then no en passant ($7977-$7991).
                const two = (c -% 1) +% l;
                if (two & 0x80 != 0) return; // JP M: past the board edge
                if (s.square(two) != 0) return;
                g.add(from, two, 0);
                var beside = s.square(two -% 1);
                if (beside != 0) g.flagDoublePush(beside);
                beside = s.square(two +% 1);
                if (beside != 0) g.flagDoublePush(beside);
                return;
            }
        }
        if (g.ix_flags & 0x20 != 0) g.enPassant(from, l);
    }

    /// GEN_EPFLAG ($79FC): if `code` is an enemy pawn (value 1), set the flags
    /// of the last entry to $20. If the double push itself was not written
    /// (list full), this lands on the previous entry, as in the original.
    fn flagDoublePush(g: *Gen, code: u8) void {
        if (!g.enemy(code)) return;
        if (g.s.rec[code -% 3] & 0x0F != 1) return; // type byte at record + 1
        g.s.lists[g.out - 1] = 0x20;
    }

    /// GEN_EP ($79E4): the parent was a double push (flags $20, not a capture)
    /// landing beside this pawn: capture behind it with flags $28.
    fn enPassant(g: *Gen, from: u8, forward: u8) void {
        if (g.ix_flags & 0x08 != 0) return;
        const a = g.ix_to +% 1;
        if (a == from) {
            g.add(from, forward -% 1, 0x28);
        } else if (a -% 2 == from) {
            g.add(from, forward +% 1, 0x28);
        }
    }
};

// ------------------------------------------------------------------- tests

const golden = @import("golden.zig");

fn expectRootList(s: *State, out: std.json.ObjectMap, dev001: *usize) !void {
    const root = out.get("root").?.array.items;
    const r = generate(s, st.root_record);
    const start = st.listOffset(s.slot[s.ply]);
    const n = (st.listOffset(s.slot[s.ply + 1]) - start) / 4 - 1;
    if (n != root.len) {
        std.debug.print("move count {d}, expected {d}\n", .{ n, root.len });
        return error.TestUnexpectedResult;
    }
    for (root, 0..) |m, i| {
        const e = s.lists[start + 4 + 4 * i ..][0..4];
        const want = m.array.items;
        if (e[0] != 0xFF or e[1] != want[0].integer or e[2] != want[1].integer or e[3] != want[2].integer) {
            std.debug.print("entry {d}: got {x:0>2} {x:0>2} {x:0>2} {x:0>2}, expected {} {} {}\n", .{ i, e[0], e[1], e[2], e[3], want[0].integer, want[1].integer, want[2].integer });
            return error.TestUnexpectedResult;
        }
    }
    const want_count: u8 = @intCast(out.get("root_count").?.integer);
    if (n >= 127) {
        // DEV-001: the original's count is wrong; this port's is the true count.
        try std.testing.expectEqual(originalCount(@intCast(n)), want_count);
        try std.testing.expectEqual(@as(u8, @intCast(n)), r.count);
        dev001.* += 1;
    } else {
        try std.testing.expectEqual(want_count, r.count);
    }
    try std.testing.expectEqual(s.lists[start + 1], r.count);
    try std.testing.expectEqual(st.listAddr(start + 3), r.header);
}

test "root move lists match the original (search, edge, book goldens)" {
    const gpa = std.testing.allocator;
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var total: usize = 0;
    var dev001: usize = 0;
    for ([_][]const u8{ "search.jsonl.gz", "search-high.jsonl.gz", "edge.jsonl.gz", "book.jsonl.gz" }) |name| {
        var buf: [256]u8 = undefined;
        var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, name));
        defer g.deinit();
        for (0..g.lines.len) |i| {
            var p = try g.parse(gpa, i);
            defer p.deinit();
            const goes = p.value.object.get("goes") orelse continue;
            for (goes.array.items) |go| {
                const out = go.object.get("out").?.object;
                if (out.get("root") == null) continue;
                s.* = .{};
                try golden.loadState(s, go.object.get("state").?.object);
                s.search_flags = 0x40; // ComputerMove ($614E) before generating
                expectRootList(s, out, &dev001) catch |err| {
                    std.debug.print("{s} line {d}\n", .{ name, i + 2 });
                    return err;
                };
                total += 1;
            }
        }
    }
    std.debug.print("root lists: {d} identical ({d} with the DEV-001 count)\n", .{ total, dev001 });
    try std.testing.expect(total > 8000);
}

test "DEV-001: Petrovic's 218-move position gets the true count" {
    // The original's count for 218 moves is 90 (docs/DEVIATIONS.md DEV-001).
    try std.testing.expectEqual(@as(u8, 90), originalCount(218));
    try std.testing.expectEqual(@as(u8, 255), originalCount(127));
    try std.testing.expectEqual(@as(u8, 126), originalCount(126));
}

test "list-full abort" {
    const gpa = std.testing.allocator;
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    s.* = .{};
    // White king on e1 ($74), black king on e8 ($04): records $BE80/$BE00.
    s.rec[0x80] = 0x74;
    s.rec[0x81] = 0x10;
    s.rec[0x00] = 0x04;
    s.rec[0x01] = 0x10;
    for ([_]u8{ 0x08, 0x10, 0x18, 0x20, 0x28, 0x30, 0x38 }) |o| {
        s.rec[0x80 + o] = 0x80;
        s.rec[o] = 0x80;
    }
    var o: u8 = 0x40;
    while (o <= 0x78) : (o += 8) {
        s.rec[0x80 + o] = 0x80;
        s.rec[o] = 0x80;
    }
    s.board[0x74] = 0x84;
    s.board[0x04] = 0x04;
    s.side_phase = 1;
    s.ply = 1;
    s.slot[1] = st.list_end_original - 8; // room for one entry only
    const r = generate(s, st.root_record);
    try std.testing.expect(s.search_flags & 0x80 != 0);
    // Two entries fit ($BC7C, $BC80); the terminator lands at offset 2180,
    // the original's $BC84 (listAddr maps it past the original area; the low
    // byte is the same, and the search only compares the high byte with $B4).
    try std.testing.expectEqual(st.listAddr(st.list_bytes_original + 4), s.slot[2]);
    try std.testing.expectEqual(@as(u8, 2), r.count);
    // The king's first two steps: e1-d2 (-17) and e1-f2 (-15).
    try std.testing.expectEqual(@as(u8, 0x63), s.lists[st.list_bytes_original - 4 + 2]);
    try std.testing.expectEqual(@as(u8, 0x65), s.lists[st.list_bytes_original + 2]);
}

test "start position: 20 moves in the original's order" {
    const gpa = std.testing.allocator;
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    s.* = .{};
    // Standard set-up: Black records $BE00 (row 0 = rank 8), White $BE80.
    const back = [_]u8{ 0x04, 0x03, 0x00, 0x07, 0x02, 0x05, 0x01, 0x06 }; // K Q R R B B N N files
    const types = [_]u8{ 0x00, 0x09, 0x05, 0x05, 0x83, 0x83, 0x03, 0x03 };
    for (0..8) |i| {
        s.rec[i * 8] = back[i];
        s.rec[i * 8 + 1] = types[i];
        s.board[back[i]] = @intCast(i * 8 + 4);
        s.rec[0x80 + i * 8] = 0x70 + back[i];
        s.rec[0x80 + i * 8 + 1] = types[i];
        s.board[0x70 + back[i]] = @intCast(0x80 + i * 8 + 4);
        s.rec[0x40 + i * 8] = @intCast(0x10 + i);
        s.rec[0x40 + i * 8 + 1] = 1;
        s.board[0x10 + i] = @intCast(0x44 + i * 8);
        s.rec[0xC0 + i * 8] = @intCast(0x60 + i);
        s.rec[0xC0 + i * 8 + 1] = 1;
        s.board[0x60 + i] = @intCast(0xC4 + i * 8);
    }
    s.side_phase = 1; // White's records
    s.ply = 1;
    s.slot[1] = st.list_base;
    const r = generate(s, st.root_record);
    try std.testing.expectEqual(@as(u8, 20), r.count);
    // Knights first (b1 then g1; offsets -31 before -33), then pawns a..h,
    // each single push then double push.
    const want = [_][2]u8{ .{ 0x71, 0x52 }, .{ 0x71, 0x50 }, .{ 0x76, 0x57 }, .{ 0x76, 0x55 }, .{ 0x60, 0x50 }, .{ 0x60, 0x40 } };
    for (want, 0..) |m, i| {
        try std.testing.expectEqual(m[0], s.lists[4 + 4 * i + 1]);
        try std.testing.expectEqual(m[1], s.lists[4 + 4 * i + 2]);
    }
}
