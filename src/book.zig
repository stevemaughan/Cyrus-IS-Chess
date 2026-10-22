//! Opening book probe: port of $7AC7-$7B95; data from the binary
//! (tables.book). Spec: docs/arch/25-book.md; reference decoder:
//! tools/scripts/book_dump.py. Owner: Phase 3 unit 3.11.
//!
//! Interface:
//!   pub fn probe(s: *State, r: *state.RSource) ?u32;
//! Probes with the root list already generated and scored at $B404 (ply 1)
//! and the game record; returns the chosen entry's address (as $BD29 would
//! hold) or null, updating s.book_state and s.random exactly as the original.
//! `r` supplies the values the original reads from the R register (DEV-006).
//!
//! `probe` includes the fixes DEV-002 (an illegal book move, i.e. one whose
//! root static score is 0, is treated as a miss) and DEV-003 (the ply count is
//! compared in full, not by its low byte). `probeOriginal` is the unmodified
//! original, kept for the golden tests.

const std = @import("std");
const state = @import("state.zig");
const State = state.State;
const tables = @import("tables.zig");

/// Number of entries in the book ($9000-$9BCC, nine bits each).
pub const entry_count = 2685;

/// Address of the first root-list entry: the chosen move is $B404 + 4 * index.
const root_entries: u32 = state.list_base + 4;

pub const Options = struct {
    /// DEV-002: treat a book move whose root static score is 0 (illegal) as a miss.
    reject_illegal: bool,
    /// DEV-003: compare the game's ply count in full instead of its low byte.
    full_ply_count: bool,
};

pub const original_options: Options = .{ .reject_illegal = false, .full_ply_count = false };
pub const fixed_options: Options = .{ .reject_illegal = true, .full_ply_count = true };

/// Probe the book with the deviations fixed (the engine's entry point).
pub fn probe(s: *State, r: *state.RSource) ?u32 {
    return probeWith(s, r, fixed_options);
}

/// Probe exactly as the original does (golden tests).
pub fn probeOriginal(s: *State, r: *state.RSource) ?u32 {
    return probeWith(s, r, original_options);
}

/// One 9-bit book entry: `bits` = entry bits 0-7 (bit 7 leaf, bit 6 more
/// siblings follow, bits 0-5 index in the generated move list); `m` = bit 8.
pub const Entry = struct {
    bits: u8,
    m: bool,
};

/// BOOK_BITS ($7B64): fetch entry n. The stream is most significant bit
/// first; entry n starts at bit (n AND 7) of byte $9000 + n + n/8. The two
/// bytes there are shifted left (n AND 7) + 1 times through the carry, leaving
/// entry bits 0-7 in A and bit 8 in the carry. Returns null if the read would
/// leave the 16K binary (only possible on a corrupt walk; the original would
/// read RAM above $A000 there).
pub fn entryAt(n: u16) ?Entry {
    const off: u32 = @as(u32, n) + (n >> 3);
    const at = 0x9000 - 0x6000 + off;
    if (at + 1 >= tables.binary.len) return null;
    var a: u8 = tables.binary[at];
    var c: u8 = tables.binary[at + 1];
    var carry: u1 = 0;
    var k: u4 = @intCast((n & 7) + 1);
    while (k > 0) : (k -= 1) {
        // RL C: C = C << 1 | CF, CF = old bit 7 of C
        const c_out: u1 = @intCast(c >> 7);
        c = (c << 1) | carry;
        carry = c_out;
        // RLA: A = A << 1 | CF, CF = old bit 7 of A
        const a_out: u1 = @intCast(a >> 7);
        a = (a << 1) | carry;
        carry = a_out;
    }
    return .{ .bits = a, .m = carry == 1 };
}

/// BOOK_RANDOM ($7B89): $BCCE = (R XOR $BCCE) >> 1, returned (0-127).
fn random(s: *State, r: *state.RSource) u8 {
    s.random = (s.random ^ r.next()) >> 1;
    return s.random;
}

const Next = struct { n: u16, e: Entry };

/// BOOK_SKIP ($7B4C): skip entry n and its descendants (pre-order) and return
/// the next sibling with its entry. A signed counter starts at -1; each entry
/// read subtracts 1 if it is a leaf and adds 1 if it has more siblings; the walk
/// stops after the first entry that leaves it negative. Only called for an
/// entry whose "more siblings" bit is set. Null on a corrupt walk (see entryAt).
fn skipSubtree(n0: u16) ?Next {
    var de: i32 = -1;
    var n = n0;
    while (true) {
        const e = entryAt(n) orelse return null;
        if (e.bits & 0x80 != 0) de -= 1;
        if (e.bits & 0x40 != 0) de += 1;
        n +%= 1;
        if (de < 0) break;
    }
    return .{ .n = n, .e = entryAt(n) orelse return null };
}

/// BOOK_OUT ($7AC0): the game has left the book.
fn leaveBook(s: *State) ?u32 {
    s.book_state = 0xFF;
    return null;
}

/// BOOK_PROBE ($7AC7-$7B4B).
pub fn probeWith(s: *State, r: *state.RSource, opts: Options) ?u32 {
    // $7AC7: book already abandoned in this game?
    if (s.book_state != 0) return null;
    // $7ACC: only for games from the standard initial position ($C006 = 1).
    if (s.start_move != 1) return null;
    // $7AD1: a random byte whose value is not used (it advances $BCCE).
    _ = random(s, r);

    // $7AD7 BOOKP_PLY: follow the game's moves down the tree. `n` is the
    // first entry of the sibling list for the position reached so far;
    // $BCDF counts the plies matched.
    var n: u16 = 0;
    while (true) {
        const i = s.book_state;
        s.book_state +%= 1;
        // $7AE4: all plies matched? The original compares the low byte of $C001.
        const matched_all = if (opts.full_ply_count) i == s.plies else i == @as(u8, @truncate(s.plies));
        if (matched_all) break;
        // $7AEF: index of the move played at ply i (bit 7 = 'gave check').
        const c = s.record[i] & 0x7F;
        var e = entryAt(n) orelse return leaveBook(s);
        // $7AF6 BOOKP_CMP: RES 6 keeps the leaf bit, so a leaf never matches.
        while (e.bits & 0xBF != c) {
            // $7AFC: no more siblings: out of book ($7AC0).
            if (e.bits & 0x40 == 0) return leaveBook(s);
            const next = skipSubtree(n) orelse return leaveBook(s);
            n = next.n;
            e = next.e;
        }
        n +%= 1; // first child of the matched move
    }

    // $7B05 BOOKP_CHOOSE: pick one entry of the sibling list at n.
    var b = random(s, r);
    const first = entryAt(n) orelse return leaveBook(s);
    var c = first.bits;
    // $7B0C: the only move is taken; otherwise the first is taken if random
    // bit 1 is set, or (when its M bit is set) bit 0.
    if (first.bits & 0x40 != 0 and (2 | @as(u8, @intFromBool(first.m))) & b == 0) {
        // $7B16 BOOKP_SIB: consider the following siblings in turn.
        while (true) {
            const saved = n;
            b = random(s, r);
            const next = skipSubtree(n) orelse return leaveBook(s);
            n = next.n;
            if (next.e.m) {
                // $7B2B BOOKP_PREV: an M bit on a later sibling: take the previous one.
                n = saved;
                c = (entryAt(n) orelse return leaveBook(s)).bits;
                break;
            }
            c = next.e.bits;
            if (c & 0x40 == 0) break; // last sibling: take it
            if (b & 1 == 0) break; // RR B: no carry: take this one
        }
    }

    // $7B30 BOOKP_TAKE: the chosen move is $B404 + 4 * index (no bounds or
    // legality check in the original).
    const index: u32 = c & 0x3F;
    const addr = root_entries + 4 * index;
    if (opts.reject_illegal) {
        // DEV-002: the root list has been statically scored; score 0 means the
        // move is illegal. An index past the list (only reachable through
        // DEV-003's bug) is treated the same way.
        const root_len = (s.slot[2] -% root_entries) / 4;
        if (index >= root_len or s.lists[state.listOffset(addr)] == 0) return leaveBook(s);
    }
    s.move_to_play = addr;
    // $7B42: a non-leaf keeps the book active ($BCDF = 0); after a leaf
    // $BCDF stays non-zero for the rest of the game.
    if (c & 0x80 == 0) s.book_state = 0;
    return addr;
}

// ------------------------------------------------------------------ tests

const golden = @import("golden.zig");
const testing = std.testing;

fn jint(obj: std.json.ObjectMap, key: []const u8) i64 {
    return obj.get(key).?.integer;
}

fn loadProbeInput(s: *State, in: std.json.ObjectMap) !void {
    const list_hex = in.get("list").?.string;
    const list_len: u32 = @intCast(list_hex.len / 2);
    _ = try std.fmt.hexToBytes(s.lists[0..list_len], list_hex);
    s.slot[1] = state.list_base;
    s.slot[2] = state.list_base + list_len;
    s.book_state = @intCast(jint(in, "bcdf"));
    s.random = @intCast(jint(in, "bcce"));
    s.plies = @intCast(jint(in, "plies"));
    s.start_move = @intCast(jint(in, "start_move"));
    const rec_hex = in.get("record").?.string;
    @memset(&s.record, 0xFF);
    _ = try std.fmt.hexToBytes(s.record[0 .. rec_hex.len / 2], rec_hex);
}

test "entry decoding matches the documented examples and totals" {
    try testing.expectEqual(Entry{ .bits = 0x4D, .m = false }, entryAt(0).?); // e2-e4, more siblings
    try testing.expectEqual(Entry{ .bits = 0x49, .m = false }, entryAt(1).?); // 1...c7-c5
    try testing.expectEqual(Entry{ .bits = 0x4E, .m = true }, entryAt(2).?); // 2.Ng1-f3, M
    var leaves: usize = 0;
    var ms: usize = 0;
    for (0..entry_count) |n| {
        const e = entryAt(@intCast(n)).?;
        leaves += @intFromBool(e.bits & 0x80 != 0);
        ms += @intFromBool(e.m);
    }
    try testing.expectEqual(@as(usize, 396), leaves);
    try testing.expectEqual(@as(usize, 123), ms);
    // The tree ends exactly at the last entry: skip every root move from entry
    // 0, then walk the last root move's subtree (its "more siblings" bit is
    // clear, so the counter starts at 0 instead of BOOK_SKIP's -1).
    var n: u16 = 0;
    while (entryAt(n).?.bits & 0x40 != 0) n = skipSubtree(n).?.n;
    var de: i32 = 0;
    while (true) {
        const e = entryAt(n).?;
        if (e.bits & 0x80 != 0) de -= 1;
        if (e.bits & 0x40 != 0) de += 1;
        n += 1;
        if (de < 0) break;
    }
    try testing.expectEqual(@as(u16, entry_count), n);
}

test "book probe matches the original on every golden probe" {
    const gpa = testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try golden.open(gpa, testing.io, try golden.path(&buf, "bookprobe.jsonl.gz"));
    defer g.deinit();
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var r_bytes: [64]u8 = undefined;
    var hits: usize = 0;
    var illegal: usize = 0;
    for (0..g.lines.len) |i| {
        var p = try g.parse(gpa, i);
        defer p.deinit();
        const rec = p.value.object;
        const in = rec.get("in").?.object;
        const out = rec.get("out").?.object;
        const r_arr = rec.get("r").?.array.items;
        for (r_arr, 0..) |v, k| r_bytes[k] = @intCast(v.integer);

        // the original behaviour
        s.* = .{};
        try loadProbeInput(s, in);
        var scripted: state.ScriptedR = .{ .bytes = r_bytes[0..r_arr.len] };
        var src = scripted.source();
        const got = probeOriginal(s, &src);
        const hit = out.get("hit").?.bool;
        errdefer std.debug.print("probe {d} (seed {d}): got {?x}, expected hit={} bd29={x}\n", .{ i, jint(rec, "seed"), got, hit, jint(out, "bd29") });
        try testing.expectEqual(hit, got != null);
        if (got) |addr| try testing.expectEqual(@as(u32, @intCast(jint(out, "bd29"))), addr);
        try testing.expectEqual(@as(u8, @intCast(jint(out, "bcdf"))), s.book_state);
        try testing.expectEqual(@as(u8, @intCast(jint(out, "bcce"))), s.random);
        try testing.expectEqual(@as(usize, @intCast(jint(out, "r_used"))), scripted.used);

        // the fixed probe agrees, except on an illegal book move (DEV-002)
        const orig_state = s.book_state;
        s.* = .{};
        try loadProbeInput(s, in);
        var scripted2: state.ScriptedR = .{ .bytes = r_bytes[0..r_arr.len] };
        var src2 = scripted2.source();
        const fixed = probe(s, &src2);
        if (got) |addr| {
            hits += 1;
            if (s.lists[state.listOffset(addr)] == 0) {
                illegal += 1;
                try testing.expectEqual(@as(?u32, null), fixed);
                try testing.expectEqual(@as(u8, 0xFF), s.book_state);
            } else {
                try testing.expectEqual(got, fixed);
                try testing.expectEqual(orig_state, s.book_state);
            }
        } else {
            try testing.expectEqual(@as(?u32, null), fixed);
            try testing.expectEqual(orig_state, s.book_state);
        }
    }
    try testing.expectEqual(@as(usize, 8600), g.lines.len);
    try testing.expectEqual(@as(usize, 4876), hits);
    // DEV-002: the illegal 6...Be7 reply is reached in the golden probes.
    try testing.expect(illegal >= 1);
}

test "DEV-003: the ply count is compared in full" {
    const gpa = testing.allocator;
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    // A 256-ply game whose first moves are a book line (1.e4 c5) and then
    // leave the book: index 63 never occurs in the book.
    s.* = .{};
    s.start_move = 1;
    s.plies = 256;
    s.record[0] = 13; // e2-e4
    s.record[1] = 9; // c7-c5
    @memset(s.record[2..256], 63);
    s.record[256] = 0xFF;
    // a root list of 40 entries, all legal (non-zero scores)
    s.slot[1] = state.list_base;
    s.slot[2] = state.list_base + 4 + 40 * 4;
    for (0..40) |k| s.lists[4 + 4 * k] = 0x80;
    const bytes = [_]u8{ 0x55, 0x2A, 0x13, 0x77, 0x01, 0x40, 0x22, 0x08, 0x55, 0x2A, 0x13, 0x77, 0x01, 0x40, 0x22, 0x08 };

    // Original: the low byte of 256 is 0, so it "matches" zero plies and plays
    // a first move of White's from the root of the book.
    var a: state.ScriptedR = .{ .bytes = &bytes };
    var src_a = a.source();
    const orig = probeOriginal(s, &src_a);
    try testing.expect(orig != null);

    // Fixed: the game is followed for real, leaves the book at ply 2.
    s.book_state = 0;
    var b: state.ScriptedR = .{ .bytes = &bytes };
    var src_b = b.source();
    try testing.expectEqual(@as(?u32, null), probe(s, &src_b));
    try testing.expectEqual(@as(u8, 0xFF), s.book_state);
}
