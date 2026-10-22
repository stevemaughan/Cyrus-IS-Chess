//! Pre-search set-up: port of PRESEARCH ($7810-$789C) and MATERIAL
//! ($789D-$78B9). Spec: docs/arch/20-board-movegen.md §4.1. Phase 3 unit 3.5.
//!
//! Called once per computer move before the search passes, and by the set-up
//! mode's legality check (a result of 0 means the side not to move is in
//! check, so the position is illegal).

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const eval = @import("eval.zig");

/// Arithmetic shift right of a byte (Z80 SRA).
fn sra(x: u8) u8 {
    return @bitCast(@as(i8, @bitCast(x)) >> 1);
}

/// PRESEARCH ($7810): evaluate the last game move (the root record) with the
/// side flipped, derive the endgame "pressing" term $BD1E from the previous
/// root value $BCA0, accumulate the positional drift $BD4A, and recompute the
/// material term $BD2E, the pawns-present flag $BD6D and the phase bits of
/// $BD2D. Returns the evaluation (a = 0: the side not to move is in check).
pub fn preSearch(s: *State) eval.Result {
    // $7814: flip the side for the evaluation call.
    s.side_phase ^= 1;
    const r = eval.evaluate(s, st.root_record);

    // $7820: E = $BCA0 + $80; B and E negated when Cyrus plays Black ($BCBE).
    var b = r.b;
    var e = s.value[1] +% 0x80;
    if (s.cyrus_side != 0) {
        b = 0 -% b;
        e = 0 -% e;
    }
    // $7832: $BD1E = ((old $BD2E SRA 1) + (E SRA 1)) SRA 2, plus 1 if non-zero.
    var t = sra(sra(sra(s.material_term) +% sra(e)));
    if (t != 0) t +%= 1;
    s.pressing = t;
    // $7844: positional drift.
    s.drift +%= b;

    // $784B: material of each side; $BD6D set by MATERIAL if a pawn is seen.
    s.pawns_exist = 0;
    const white = material(s, 0x08);
    const black = material(s, 0x88);
    var d = black -% white;
    // $785D: clamp the difference to -14..+14, then x8.
    if (!(d < 0x0E or d >= 0xF2)) d = if (d & 0x80 != 0) 0xF2 else 0x0E;
    s.material_term = d *% 8;

    // $7872: phase bits from the move number and the total material.
    var phase: u8 = 0;
    if (s.move_number >= 8) {
        const total = black +% white;
        phase = 0x02;
        if (total < 0x34) {
            phase |= 0x04;
            if (total < 0x28) {
                phase |= 0x08;
                if (total < 0x19) phase |= 0x10;
            }
        }
    }
    // $7891: restore bit 0 and set the phase bits (bits 5-7 cleared).
    s.side_phase = ((s.side_phase +% 1) & 1) + phase;
    return r;
}

/// MATERIAL ($789D): the sum of the value nibbles of the 15 records from
/// `first` (Q, R, R, B, B, N, N, 8 pawn slots) that are present; sets
/// `pawns_exist` when a value of 1 is seen.
fn material(s: *State, first: u8) u8 {
    var c: u8 = 0;
    var rec = first;
    for (0..15) |_| {
        if (s.rec[rec] & 0x80 == 0) {
            const v = s.rec[rec + 1] & 0x0F;
            if (v == 1) s.pawns_exist = 1;
            c +%= v;
        }
        rec +%= 8;
    }
    return c;
}

test "pre-search matches the original (tests/golden/presearch.jsonl.gz)" {
    const golden = @import("golden.zig");
    const gpa = std.testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, "presearch.jsonl.gz"));
    defer g.deinit();
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var bad: usize = 0;
    for (0..g.lines.len) |i| {
        var p = try g.parse(gpa, i);
        defer p.deinit();
        const rec = p.value.object;
        s.* = .{};
        try golden.loadState(s, rec.get("state").?.object);
        const r = preSearch(s);
        const out = rec.get("out").?.object;
        const want = [_]i64{
            try golden.int(out, "A"),    try golden.int(out, "B"),    try golden.int(out, "BD1E"),
            try golden.int(out, "BD2E"), try golden.int(out, "BD4A"), try golden.int(out, "BD6D"),
            try golden.int(out, "BD2D"), try golden.int(out, "root_flags"), try golden.int(out, "BCCE"),
        };
        // On return the original's B register holds the phase bits ($7875-$788F).
        const got = [_]i64{ r.a, s.side_phase & 0x1E, s.pressing, s.material_term, s.drift, s.pawns_exist, s.side_phase, s.root_rec[3], s.random };
        if (!std.mem.eql(i64, &got, &want)) {
            if (bad < 5) std.debug.print("presearch {d}: got {any} want {any}\n", .{ i, got, want });
            bad += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), bad);
}

test "material clamp and phase bits" {
    var s: State = .{};
    // all records absent except two white queens' worth of material
    for (0..32) |i| s.rec[i * 8] = 0x80;
    s.rec[0x08] = 0x10;
    s.rec[0x09] = 0x09;
    s.move_number = 20;
    s.side_phase = 1;
    _ = material(&s, 0x08);
    try std.testing.expectEqual(@as(u8, 9), material(&s, 0x08));
    try std.testing.expectEqual(@as(u8, 0), s.pawns_exist);
}
