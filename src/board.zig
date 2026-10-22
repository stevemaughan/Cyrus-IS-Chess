//! Make and unmake move: port of MAKEMOVE ($810F-$81FF), KINGTYPE
//! ($8200-$821B), UNMAKE ($821C-$826D) and UN_PROMO_FIX ($826E-$828B).
//! Spec: docs/arch/20-board-movegen.md §4.3-4.5 (mirrored board convention;
//! the semantics here follow the code). Phase 3 unit 3.3.
//!
//! The original pushes its undo data on the Z80 stack; `Undo` holds the same
//! frames. Captures are decided by board content for Q/R/B/N and by the move's
//! flags for pawns and kings, exactly as in the original.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;

/// What MAKEMOVE pushes on the stack (top first in the original):
/// [old type, marker], then for captures, en passant and castling
/// [square, code] of the captured piece or the castling rook, then
/// [from-square, moving piece code].
pub const Undo = struct {
    from: u8 = 0,
    /// Piece code of the moving piece.
    mover: u8 = 0,
    /// A second frame was pushed (capture, en passant or castling).
    extra: bool = false,
    /// Captured piece's square and code, or the castling rook's origin and code.
    extra_sq: u8 = 0,
    extra_code: u8 = 0,
    /// The "AF" word: A = the mover's type byte before the move,
    /// F = marker: $80 quiet, $84 quiet promotion, $00 capture,
    /// $04 capture-promotion, $01 en passant, $40 castling.
    /// PlayMove ($6323) pops this word to update the 50-move counter.
    old_type: u8 = 0,
    marker: u8 = 0,

    pub const quiet: u8 = 0x80;
    pub const quiet_promotion: u8 = 0x84;
    pub const capture: u8 = 0x00;
    pub const capture_promotion: u8 = 0x04;
    pub const en_passant: u8 = 0x01;
    pub const castling: u8 = 0x40;
};

/// A board write at $BD00 + sq. Generated moves stay on the board; an
/// off-board square (reachable only through the unchecked pawn-capture reads,
/// see `State.offboard`) writes the variable that aliases that byte.
fn putSquare(s: *State, sq: u8, v: u8) void {
    if (sq & 0x88 == 0) {
        s.board[sq] = v;
    } else switch (sq) {
        0x58 => s.root_rec[0] = v,
        0x7F => s.pins[0x7F - 0x79] = v,
        else => {},
    }
}

/// MAKEMOVE ($810F): make the move at `entry` (a list entry, or the root
/// record) and record what is needed to undo it in `undo`. Sets flags bit 0 of
/// the entry for a pawn move to the 6th/7th rank (cleared for a promotion),
/// updates the mover's type byte, marks a captured piece (square bit 7), and
/// adjusts the material delta $BD0D. When castling with the entry's score byte
/// still $FF (root scoring), the KING's code is put on the rook's destination
/// (the square the king passes), which lets the evaluation reject castling
/// through an attacked square.
pub fn make(s: *State, entry: u32, undo: *Undo) void {
    const e = s.entry(entry);
    const from = e[1];
    const to = e[2];
    const mover = s.square(from);
    undo.* = .{ .from = from, .mover = mover };
    putSquare(s, from, 0);
    const captured = s.square(to);
    putSquare(s, to, mover);
    const r = mover & 0xFB; // record offset
    s.rec[r] = to;
    const old = s.rec[r +% 1];
    undo.old_type = old;
    switch (old & 0x0F) {
        0 => makeKing(s, e, r, to, captured, undo),
        1 => makePawn(s, e, r, from, to, captured, undo),
        else => {
            s.rec[r +% 1] |= 0x10; // $8132: moved
            if (captured != 0) {
                takePiece(s, undo, to, captured, Undo.capture);
            } else {
                undo.marker = Undo.quiet;
            }
        },
    }
}

/// MK_PAWN ($813D-$81A2).
fn makePawn(s: *State, e: *[4]u8, r: u8, from: u8, to: u8, captured: u8, undo: *Undo) void {
    // Relative rank x 16 of the to-square, from the mover's side: rows count
    // upwards for pawns moving to higher rows, otherwise mirrored (XOR $70).
    var rel = to & 0x70;
    if (rel < from) rel ^= 0x70;
    if (rel >= 0x30) {
        switch (rel) {
            0x30 => s.rec[r +% 1] = 0x11, // 4th rank
            0x40 => s.rec[r +% 1] = 0x31, // 5th rank
            else => {
                e[3] |= 0x01; // $814F: pawn to the 6th/7th rank
                if (rel == 0x50) {
                    s.rec[r +% 1] = 0x61;
                } else if (rel == 0x60) {
                    s.rec[r +% 1] = 0x91;
                } else {
                    // $815D: promotion, always to a queen.
                    e[3] &= ~@as(u8, 0x01);
                    s.rec[r +% 1] = 0x19;
                    // $8163: $BD0D +8 for the records at $BE80, -8 for $BE00.
                    s.material_delta = if (r & 0x80 != 0) s.material_delta +% 8 else s.material_delta -% 8;
                    if (e[3] & 0x08 != 0) {
                        takePiece(s, undo, to, captured, Undo.capture_promotion);
                    } else {
                        undo.marker = Undo.quiet_promotion;
                    }
                    return;
                }
            },
        }
    }
    // $8184: the flags decide whether a pawn move captures.
    if (e[3] & 0x08 == 0) {
        undo.marker = Undo.quiet;
        return;
    }
    if (e[3] & 0x20 == 0) {
        takePiece(s, undo, to, captured, Undo.capture);
        return;
    }
    // En passant ($8191): the captured pawn is behind the to-square.
    const csq = if (to >= from) to -% 0x10 else to +% 0x10;
    const code = s.square(csq);
    putSquare(s, csq, 0);
    takePiece(s, undo, csq, code, Undo.en_passant);
}

/// MK_KING ($81BF-$81FF).
fn makeKing(s: *State, e: *[4]u8, r: u8, to: u8, captured: u8, undo: *Undo) void {
    s.rec[r +% 1] = kingTypeAt(undo.old_type | 0x10, to);
    const f = e[3] & 0x18;
    if (f == 0) {
        undo.marker = Undo.quiet;
        return;
    }
    if (f & 0x08 != 0) {
        takePiece(s, undo, to, captured, Undo.capture);
        return;
    }
    // Castling ($81CF): the rook's origin and destination follow from the
    // to-square's file only (to-square bit 2 set: g-file).
    s.rec[r +% 1] |= 0x20;
    var rook_from: u8 = undefined;
    var rook_to: u8 = undefined;
    if (to & 0x04 != 0) {
        rook_from = to +% 1;
        rook_to = to -% 1;
    } else {
        rook_from = to -% 2;
        rook_to = to +% 1;
    }
    const rook = s.square(rook_from);
    putSquare(s, rook_from, 0);
    // $81EA: score byte $FF (root scoring): the king's code goes on the
    // transit square instead of the rook's (rook code AND $84 = king code).
    putSquare(s, rook_to, if (e[0] == 0xFF) rook & 0x84 else rook);
    undo.extra = true;
    undo.extra_sq = rook_from;
    undo.extra_code = rook;
    s.rec[rook & 0xFB] = rook_to;
    undo.marker = Undo.castling;
}

/// MK_CAPTURE_X ($81A7): mark the captured piece (square bit 7), push its
/// frame and add its signed value to $BD0D (negative for records at $BE80).
fn takePiece(s: *State, undo: *Undo, sq: u8, code: u8, marker: u8) void {
    undo.extra = true;
    undo.extra_sq = sq;
    undo.extra_code = code;
    undo.marker = marker;
    const r = code & 0xFB;
    s.rec[r] |= 0x80;
    var v = s.rec[r +% 1] & 0x0F;
    if (r & 0x80 != 0) v = 0 -% v;
    s.material_delta +%= v;
}

/// KINGTYPE_X ($8203): from `a` (the type byte with the moved bit already
/// set, as KINGTYPE $8200 does), clear bits 6-7 and add $40 for each ring
/// k = 1, 2, 3 for which both sq + $11k and sq - $11k are on the board, i.e.
/// bits 6-7 = min(file, row, 7 - file, 7 - row) capped at 3. The set-up code
/// ($660A) uses this entry directly.
pub fn kingTypeAt(a: u8, sq: u8) u8 {
    var t = a & 0x3F;
    var step: u8 = 0x11;
    while (true) {
        if ((sq +% step) & 0x88 != 0) return t;
        if ((sq -% step) & 0x88 != 0) return t;
        step +%= 0x11;
        t +%= 0x40;
    }
}

/// UNMAKE ($821C): undo the move recorded in `undo`.
pub fn unmake(s: *State, undo: *const Undo) void {
    const marker = undo.marker;
    if (marker & 0x04 != 0) {
        // UN_PROMO_FIX ($826E): reverse the promotion's $BD0D adjustment. For
        // a quiet promotion the test is on the mover; for a capture-promotion
        // on the captured piece (opposite colour, so the test is reversed).
        const plus8 = if (marker & 0x80 != 0) undo.mover & 0x80 == 0 else undo.extra_code & 0x80 != 0;
        s.material_delta = if (plus8) s.material_delta +% 8 else s.material_delta -% 8;
    }
    var to_value: u8 = 0;
    if (marker & 0x80 != 0) {
        // quiet ($8247)
    } else if (marker & 0x40 != 0) {
        // UN_CASTLE ($825F): rook back to its origin, destination cleared.
        putSquare(s, undo.extra_sq, undo.extra_code);
        const r = undo.extra_code & 0xFB;
        const dest = s.rec[r];
        s.rec[r] = undo.extra_sq;
        putSquare(s, dest, 0);
    } else if (marker & 0x01 != 0) {
        // UN_EP ($8258): the captured pawn back on its own square.
        putSquare(s, undo.extra_sq, undo.extra_code);
        restoreCaptured(s, undo.extra_code);
    } else {
        // capture ($822F): the captured piece goes back on the to-square.
        restoreCaptured(s, undo.extra_code);
        to_value = undo.extra_code;
    }
    // UN_RESTORE_MOVER ($8247).
    putSquare(s, undo.from, undo.mover);
    const r = undo.mover & 0xFB;
    const to = s.rec[r];
    s.rec[r] = undo.from;
    s.rec[r +% 1] = undo.old_type;
    putSquare(s, to, to_value);
}

/// UN_RESTORE_CAP ($8230): clear the captured bit and take its signed value
/// back out of $BD0D.
fn restoreCaptured(s: *State, code: u8) void {
    const r = code & 0xFB;
    s.rec[r] &= 0x7F;
    var v = s.rec[r +% 1] & 0x0F;
    if (r & 0x80 == 0) v = 0 -% v;
    s.material_delta +%= v;
}

// ------------------------------------------------------------------- tests

const golden = @import("golden.zig");
const movegen = @import("movegen.zig");

const Snapshot = struct {
    board: [128]u8,
    rec: [256]u8,
    material_delta: u8,
    root_rec: [4]u8,
    pins: [13]u8,

    fn take(s: *const State) Snapshot {
        return .{ .board = s.board, .rec = s.rec, .material_delta = s.material_delta, .root_rec = s.root_rec, .pins = s.pins };
    }

    fn eql(a: Snapshot, b: Snapshot) bool {
        return std.mem.eql(u8, &a.board, &b.board) and std.mem.eql(u8, &a.rec, &b.rec) and
            a.material_delta == b.material_delta and std.mem.eql(u8, &a.root_rec, &b.root_rec) and
            std.mem.eql(u8, &a.pins, &b.pins);
    }
};

test "make then unmake restores the position (every root move of the goldens)" {
    const gpa = std.testing.allocator;
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var moves: usize = 0;
    for ([_][]const u8{ "search.jsonl.gz", "edge.jsonl.gz" }) |name| {
        var buf: [256]u8 = undefined;
        var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, name));
        defer g.deinit();
        for (0..g.lines.len) |i| {
            var p = try g.parse(gpa, i);
            defer p.deinit();
            const goes = p.value.object.get("goes") orelse continue;
            for (goes.array.items) |go| {
                s.* = .{};
                try golden.loadState(s, go.object.get("state").?.object);
                s.search_flags = 0x40;
                _ = movegen.generate(s, st.root_record);
                const start = st.listOffset(s.slot[1]) + 4;
                const end = st.listOffset(s.slot[2]);
                const before = Snapshot.take(s);
                var off = start;
                while (off < end) : (off += 4) {
                    for ([_]u8{ 0xFF, 0x00 }) |score| {
                        s.lists[off] = score;
                        var u: Undo = undefined;
                        make(s, st.listAddr(off), &u);
                        unmake(s, &u);
                        if (!Snapshot.take(s).eql(before)) {
                            std.debug.print("{s} line {d}: move {x:0>2}{x:0>2} not restored\n", .{ name, i + 2, s.lists[off + 1], s.lists[off + 2] });
                            return error.TestUnexpectedResult;
                        }
                        moves += 1;
                    }
                }
            }
        }
    }
    std.debug.print("make/unmake round trips: {d}\n", .{moves});
    try std.testing.expect(moves > 100000);
}

fn hexEq(want_hex: []const u8, got: []const u8) !bool {
    var buf: [512]u8 = undefined;
    const want = buf[0 .. want_hex.len / 2];
    _ = try std.fmt.hexToBytes(want, want_hex);
    return std.mem.eql(u8, want, got);
}

test "make matches the original (board golden)" {
    const gpa = std.testing.allocator;
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var buf: [256]u8 = undefined;
    var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, "board.jsonl.gz"));
    defer g.deinit();
    var n: usize = 0;
    for (0..g.lines.len) |i| {
        var p = try g.parse(gpa, i);
        defer p.deinit();
        const rec = p.value.object;
        s.* = .{};
        try golden.loadState(s, rec.get("state").?.object);
        const off: u32 = 0;
        _ = try std.fmt.hexToBytes(s.lists[off..][0..4], rec.get("entry").?.string);
        var u: Undo = undefined;
        make(s, st.listAddr(off), &u);
        const after = rec.get("after").?.object;
        var board: [64]u8 = undefined;
        for (0..8) |row| for (0..8) |f| {
            board[row * 8 + f] = s.board[row * 16 + f];
        };
        const ok = try hexEq(after.get("board").?.string, &board) and
            try hexEq(after.get("pieces").?.string, &s.rec) and
            try hexEq(after.get("entry").?.string, s.lists[off..][0..4]) and
            after.get("bd0d").?.integer == s.material_delta and
            after.get("af").?.integer == (@as(i64, u.old_type) << 8 | u.marker) and
            after.get("frame_from").?.integer == (@as(i64, u.from) << 8 | u.mover) and
            (if (after.get("frame_extra").? == .null) !u.extra else u.extra and after.get("frame_extra").?.integer == (@as(i64, u.extra_sq) << 8 | u.extra_code));
        if (!ok) {
            std.debug.print("board golden line {d} ({s}): make differs\n", .{ i + 2, rec.get("entry").?.string });
            return error.TestUnexpectedResult;
        }
        // and unmake restores the captured state
        unmake(s, &u);
        const restored = rec.get("restored").?.object;
        var board2: [64]u8 = undefined;
        for (0..8) |row| for (0..8) |f| {
            board2[row * 8 + f] = s.board[row * 16 + f];
        };
        if (!(try hexEq(restored.get("board").?.string, &board2) and try hexEq(restored.get("pieces").?.string, &s.rec) and
            restored.get("bd0d").?.integer == s.material_delta))
        {
            std.debug.print("board golden line {d}: unmake differs\n", .{i + 2});
            return error.TestUnexpectedResult;
        }
        n += 1;
    }
    std.debug.print("make/unmake vs original: {d} moves identical\n", .{n});
    try std.testing.expect(n > 1000);
}

test "king type centralisation" {
    try std.testing.expectEqual(@as(u8, 0x10), kingTypeAt(0x10, 0x74)); // e1: edge
    try std.testing.expectEqual(@as(u8, 0xD0), kingTypeAt(0x10, 0x33)); // d5: 3 rings
    try std.testing.expectEqual(@as(u8, 0x50), kingTypeAt(0x10, 0x66)); // g2: 1 ring
}
