//! Evaluation: port of $8400-$8F2E. Spec: docs/arch/50-eval.md; executable
//! reference: tools/research/eval/evalmodel.py (bit-exact against the
//! original on 30,000 cases). Owner: Phase 3 unit 3.7.
//!
//! Interface:
//!   pub const Result = struct { a: u8, b: u8, c: u8 };
//!   pub fn evaluate(s: *State, ix: u32) Result;
//! `ix` is the move entry just made (s.entry(ix)); the routine sets flag bits
//! in its byte +3 and updates s.random, s.sel_marker, s.see_best/second,
//! s.pins and the attack bytes of the piece records exactly as the original.
//! a = 0 means the position is illegal (abort path).
//!
//! State read: board (through State.square, including the off-board aliases),
//! rec (squares, type bytes, line masks), side_phase, material_delta, drift,
//! pressing, pawns_exist, move_number, random, pins.
//! State written: rec attack bytes +2..+5 (cleared on exit for every
//! non-king record; king records accumulate), pins, sel_marker, see_best,
//! see_second, random, entry byte +3.
//!
//! Register names in comments follow the original: E (positional and
//! mobility accumulator), A' (king-zone and pawn terms), B' (pass flags F).

const std = @import("std");
const State = @import("state.zig").State;

pub const Result = struct {
    /// Score: $80 = equal, from the view of the side that has just moved;
    /// $02/$FC saturated; 0 = illegal position.
    a: u8,
    /// Positional term (mover's view, signed byte).
    b: u8,
    /// 4 x material term (register C). No caller reads it; 0 when the result
    /// is saturated or the position is illegal.
    c: u8,
};

/// Raised when the side to move can capture the enemy king or the kings touch
/// ($8C28: SP restored from $BD3D, A = 0 returned to the caller).
const Abort = error{Abort};

/// Pawn handling selected from the game phase at $8400 (IY in the original).
const PawnMode = enum {
    /// $8A7A: no advancement term.
    normal,
    /// $8A6F: endgame: advancement / 8.
    endgame,
    /// $8A2B: late endgame: advancement / 4, square before a 7th-rank pawn.
    late,
};

/// Evaluate the position after the move at `ix` ($8400).
pub fn evaluate(s: *State, ix: u32) Result {
    var ev: Eval = .{ .s = s, .flags = &s.entry(ix)[3], .to_sq = s.entry(ix)[2] };
    return ev.run();
}

const Eval = struct {
    s: *State,
    /// The move entry's flags byte (IX+3).
    flags: *u8,
    /// The move entry's to-square (IX+2).
    to_sq: u8,

    /// E: positional / mobility accumulator.
    e: u8 = 0,
    /// A': king-zone and pawn terms.
    ap: u8 = 0,
    /// B': bit 7 colour being processed, bit 6 check seen, bit 5 pin list
    /// non-empty, bit 4 second pass, bits 0-3 game phase.
    f: u8 = 0,
    /// D: edge mask for rays ($88), or the pawn direction while scanning pawns.
    d: u8 = 0,
    /// C: current ray direction / king-zone weight.
    c: u8 = 0,
    /// C': attack increment of the piece being scanned (pawn 1, minor 4,
    /// rook $10, queen $40; negative values when undoing pins).
    c2: u8 = 0,
    /// E': line-mask filter for x-rays ($C4 diagonal scan, $08 orthogonal).
    e2: u8 = 0,
    /// B, C during the pawn scan: files of the previous two pawn records.
    pb: u8 = 0,
    pc: u8 = 0,
    pawn_mode: PawnMode = .normal,
    /// Positional term for the result (B).
    b_out: u8 = 0,

    // ------------------------------------------------------------ helpers
    fn sq(ev: *const Eval, l: u8) u8 {
        return ev.s.square(l);
    }

    fn friendly(ev: *const Eval, code: u8) bool {
        return (code ^ ev.f) & 0x80 == 0;
    }

    /// Add to a byte of the piece records, addressed by piece code +/- k
    /// (code = record | 4: code-2 = +2, code-1 = +3, code = +4, code+1 = +5,
    /// code+2 = +6 line mask).
    fn add(ev: *Eval, idx: u8, v: u8) void {
        ev.s.rec[idx] +%= v;
    }

    fn rec(ev: *const Eval, idx: u8) u8 {
        return ev.s.rec[idx];
    }

    fn run(ev: *Eval) Result {
        const s = ev.s;
        const phase = s.side_phase;
        // $8400: RRCA of $BD2D: bit 0 (side to move) into bit 7 and carry.
        const a = (phase >> 1) | ((phase & 1) << 7);
        if (a & 2 != 0) {
            ev.pawn_mode = if (a & 4 != 0) .late else .endgame;
        } else {
            ev.pawn_mode = .normal;
        }
        ev.f = a +% 0x80;
        const r = blk: {
            if (phase & 1 != 0) {
                ev.whiteSection() catch break :blk null;
            } else {
                ev.blackSection() catch break :blk null;
            }
            break :blk ev.final();
        };
        if (r) |res| return res;
        // $8C28 abort: attack bytes of every record from $08 cleared (the
        // record at $00 keeps its junk), pin list emptied.
        var off: usize = 0x08;
        while (off < 0x100) : (off += 8) @memset(s.rec[off + 2 .. off + 6], 0);
        s.pins[0] = 0;
        return .{ .a = 0, .b = 0, .c = 0 };
    }

    // ------------------------------------------------------------ sections
    /// $842B: queen, rooks, bishops, knights and pawns of the records $88-$F8.
    fn blackSection(ev: *Eval) Abort!void {
        ev.d = 0x88;
        try ev.pieceIfPresent(0x88, .queen);
        try ev.pieceIfPresent(0x90, .rook);
        try ev.pieceIfPresent(0x98, .rook);
        try ev.pieceIfPresent(0xA0, .bishop_88);
        try ev.pieceIfPresent(0xA8, .bishop_88);
        try ev.pieceIfPresent(0xB0, .knight_88);
        try ev.pieceIfPresent(0xB8, .knight_88);
        try ev.pawns(0xF1, 0xC0);
        try ev.afterSection();
    }

    /// $883A: the same for the records $08-$78, then both kings.
    fn whiteSection(ev: *Eval) Abort!void {
        ev.d = 0x88;
        try ev.pieceIfPresent(0x08, .queen);
        try ev.pieceIfPresent(0x10, .rook);
        try ev.pieceIfPresent(0x18, .rook);
        try ev.pieceIfPresent(0x20, .bishop_08);
        try ev.pieceIfPresent(0x28, .bishop_08);
        try ev.pieceIfPresent(0x30, .knight_08);
        try ev.pieceIfPresent(0x38, .knight_08);
        try ev.pawns(0x11, 0x40);
        try ev.whiteKing(ev.rec(0x01), ev.rec(0x00));
        ev.ap = 0 -% ev.ap;
        ev.e = 0 -% ev.e;
        ev.f |= 0x80;
        try ev.king(ev.rec(0x81), ev.rec(0x80));
        if (ev.f & 0x10 != 0) return; // -> $84A9
        ev.f |= 0x10;
        try ev.blackSection();
    }

    /// $84A3: end of the $842B section: start the second pass or finish.
    fn afterSection(ev: *Eval) Abort!void {
        if (ev.f & 0x10 != 0) return; // -> $84A9
        ev.f +%= 0x90; // $882C
        ev.e = 0 -% ev.e;
        ev.ap = 0 -% ev.ap;
        try ev.whiteSection();
    }

    const PieceKind = enum { queen, rook, bishop_88, bishop_08, knight_88, knight_08 };

    fn pieceIfPresent(ev: *Eval, record: u8, kind: PieceKind) Abort!void {
        const square = ev.rec(record);
        if (square & 0x80 != 0) return; // absent
        switch (kind) {
            .queen => try ev.queen(square),
            .rook => try ev.rook(square),
            .bishop_88 => try ev.bishop88(square),
            .bishop_08 => try ev.bishop08(square),
            .knight_88 => try ev.knight88(square),
            .knight_08 => try ev.knight08(square),
        }
    }

    // ------------------------------------------------------------ pawns
    /// $8A5B: the eight pawn records from `base`, moving in direction `d`.
    fn pawns(ev: *Eval, d: u8, base: u8) Abort!void {
        ev.d = d;
        ev.pb = 0xFF;
        ev.pc = 0xFF;
        for (0..8) |i| {
            const record = base + 8 * @as(u8, @intCast(i));
            const square = ev.rec(record);
            if (square & 0x80 != 0) continue;
            try ev.pawn(square, ev.rec(record + 1), i == 3 or i == 4);
        }
    }

    /// $8A54/$8A96: one pawn record (a promoted piece is scanned as its piece).
    fn pawn(ev: *Eval, square: u8, type_byte: u8, centre: bool) Abort!void {
        // $8A54: unmoved d/e-pawn record (rank 2 or 7, either colour): -3.
        if (centre and (square +% 0x20) & 0x40 == 0) ev.e -%= 3;
        if (type_byte & 0x0E != 0) {
            // $8A96: promoted piece in a pawn record; the return stub $8AB5
            // restores D and the doubled-pawn files.
            const save_d = ev.d;
            const save_b = ev.pb;
            const save_c = ev.pc;
            ev.d = 0x88;
            if (type_byte & 0x08 != 0) {
                try ev.queen(square);
            } else if (type_byte & 0x04 != 0) {
                try ev.rook(square);
            } else if (type_byte & 0x80 != 0) {
                try ev.bishop(square);
            } else {
                try ev.knight(square);
            }
            ev.d = save_d;
            ev.pb = save_b;
            ev.pc = save_c;
            return;
        }
        var l = ev.d +% square;
        // Doubled pawns: compared only with the previous two pawn records.
        const file = l & 0x0F;
        if (file == ev.pb or file == ev.pc) ev.e -%= 3;
        ev.pc = ev.pb;
        ev.pb = file;
        var h = type_byte;
        switch (ev.pawn_mode) {
            .endgame => { // $8A6F
                h >>= 1;
                if (h != 0) {
                    h >>= 2;
                    ev.ap +%= h;
                }
            },
            .late => { // $8A2B
                h >>= 2;
                ev.ap +%= h;
                // first pass only: remember the square in front of a 7th-rank pawn
                if (h & 0x20 != 0 and ev.f & 0x10 == 0) ev.s.sel_marker = ev.sq(l -% 1);
            },
            .normal => {},
        }
        // capture squares: no edge check (off-board reads, see State.square)
        var code = ev.sq(l);
        if (code != 0) try ev.pawnHit(code);
        l -%= 2;
        code = ev.sq(l);
        if (code != 0) try ev.pawnHit(code);
    }

    /// $8A85: a piece on a pawn's capture square.
    fn pawnHit(ev: *Eval, code: u8) Abort!void {
        if (ev.friendly(code)) {
            ev.add(code, 1);
        } else if (code & 0x78 == 0) { // $8ABA: enemy king
            if (ev.f & 0x10 == 0) return error.Abort;
            ev.flags.* |= 0x80;
            ev.e +%= 1;
        } else {
            ev.add(code -% 2, 1);
        }
    }

    // ------------------------------------------------------------ knights
    /// $8CC8: knight of the $08 records: -3 on its back row (row 0).
    fn knight08(ev: *Eval, square: u8) Abort!void {
        if (square & 0x70 == 0) ev.e -%= 3;
        try ev.knight(square);
    }

    /// $8CBB: knight of the $88 records: -3 on row 7.
    fn knight88(ev: *Eval, square: u8) Abort!void {
        if (square | 0x70 == square) ev.e -%= 3;
        try ev.knight(square);
    }

    /// $8CCD
    fn knight(ev: *Eval, square: u8) Abort!void {
        ev.c2 = 0x04;
        ev.e -%= 1;
        try ev.knightWalk(square);
    }

    /// $8CD2: the eight knight targets, in the original's order and with its
    /// early exits for the lower rows.
    fn knightWalk(ev: *Eval, b: u8) Abort!void {
        if ((b +% 0x0E) & 0x80 == 0) {
            for ([_]u8{ 0x0E, 0x12, 0x1F, 0x21 }) |off| try ev.knightStep(b, off);
        }
        if ((b +% 0xF2) & 0x80 != 0) return;
        for ([_]u8{ 0xF2, 0xEE }) |off| try ev.knightStep(b, off);
        if ((b +% 0xE1) & 0x80 != 0) return;
        for ([_]u8{ 0xE1, 0xDF }) |off| try ev.knightStep(b, off);
    }

    fn knightStep(ev: *Eval, b: u8, off: u8) Abort!void {
        const l = b +% off;
        if (l & ev.d == 0) try ev.knightTarget(l, b);
    }

    /// $8D15
    fn knightTarget(ev: *Eval, l: u8, b: u8) Abort!void {
        ev.e +%= 1;
        const code = ev.sq(l);
        if (code == 0) return;
        if (ev.friendly(code)) {
            ev.add(code, ev.c2);
        } else if (code & 0x78 == 0) { // $8D2A
            try ev.kingCheck(b);
        } else {
            ev.add(code -% 2, ev.c2);
        }
    }

    /// $8D2A / $8D4C: the enemy king is attacked. First pass: illegal position.
    fn kingCheck(ev: *Eval, b: u8) Abort!void {
        if (ev.f & 0x10 == 0) return error.Abort;
        ev.flags.* |= 0x80;
        const was = ev.f & 0x40;
        ev.f |= 0x40;
        if (was != 0) {
            // double check
            ev.s.sel_marker = 0;
            ev.ap +%= 0x14;
        } else {
            const code = ev.sq(b);
            ev.s.rec[code +% 1] |= 0x02;
            ev.e +%= 2;
        }
    }

    // ------------------------------------------------------------ bishops
    /// $8D74: bishop of the $08 records: -3 on row 0.
    fn bishop08(ev: *Eval, square: u8) Abort!void {
        if (square & 0x70 == 0) ev.e -%= 3;
        try ev.bishop(square);
    }

    /// $8D80: bishop of the $88 records: -3 on row 7.
    fn bishop88(ev: *Eval, square: u8) Abort!void {
        if (square | 0x70 == square) ev.e -%= 3;
        try ev.bishop(square);
    }

    /// $8D86
    fn bishop(ev: *Eval, square: u8) Abort!void {
        ev.c2 = 0x04;
        try ev.diagonals(square);
    }

    /// $8D89
    fn diagonals(ev: *Eval, b: u8) Abort!void {
        ev.e2 = 0xC4;
        for ([_]u8{ 0x0F, 0x11, 0xEF, 0xF1 }) |c| {
            ev.c = c;
            const l = b +% c;
            if (l & ev.d == 0) try ev.rayMob(l, b);
        }
    }

    /// $8DAF/$8DAA: scan a ray counting mobility; handle the first piece hit.
    fn rayMob(ev: *Eval, start: u8, b: u8) Abort!void {
        var l = start;
        var code: u8 = undefined;
        while (true) {
            ev.e +%= 1;
            code = ev.sq(l);
            if (code != 0) break;
            l +%= ev.c;
            if (l & ev.d != 0) return;
        }
        if (ev.friendly(code)) { // $8DEC
            ev.add(code, ev.c2);
            try ev.afterFriendly(code, l);
        } else {
            try ev.enemyHit(code, l, b);
        }
    }

    /// $8DEF: x-ray through a friendly piece on the same kind of line.
    fn afterFriendly(ev: *Eval, code: u8, l: u8) Abort!void {
        const t = ev.rec(code +% 2) & ev.e2;
        if (t == 0) return;
        if (t & 0x80 != 0) {
            ev.pawnXray(t, l);
        } else {
            ev.xrayChain(l);
        }
    }

    /// $8E5C: bishop (or queen) behind a pawn: the pawn's capture direction.
    fn pawnXray(ev: *Eval, t: u8, start: u8) void {
        if (((t << 1) ^ ev.c) & 0x80 == 0) return;
        const l = start +% ev.c;
        if (l & ev.d != 0) return;
        const code = ev.sq(l);
        if (code == 0) return;
        if (ev.friendly(code)) {
            ev.add(code +% 1, ev.c2);
        } else {
            ev.add(code -% 1, ev.c2);
        }
    }

    /// $8DF8: continue the ray behind friendly line-movers.
    fn xrayChain(ev: *Eval, start: u8) void {
        var l = start;
        while (true) {
            l +%= ev.c;
            if (l & ev.d != 0) return;
            ev.e +%= 1;
            const code = ev.sq(l);
            if (code == 0) continue;
            if (!ev.friendly(code)) { // $8E07
                ev.add(code -% 1, ev.c2);
                return;
            }
            ev.add(code +% 1, ev.c2); // $8E0D
            const t = ev.rec(code +% 2) & ev.e2;
            if (t == 0) return;
            if (t & 0x80 != 0) {
                ev.pawnXray(t, l);
                return;
            }
        }
    }

    /// $8DB9: the first piece on a ray is an enemy.
    fn enemyHit(ev: *Eval, code: u8, start: u8, b: u8) Abort!void {
        var l = start;
        if (code & 0x78 == 0) { // $8D4C: the enemy king
            try ev.kingCheck(b);
            // $8DAA: continue the ray beyond the king, counting mobility
            l +%= ev.c;
            if (l & ev.d != 0) return;
            try ev.rayMob(l, b);
            return;
        }
        const r2 = code -% 2;
        ev.add(r2, ev.c2);
        const r6 = r2 | 0x04;
        const t = ev.rec(r6) & ev.e2;
        var code2: u8 = undefined;
        if (t != 0 and t & 0x80 == 0) {
            // $8DCD: an enemy line-mover on this line: look beyond it
            while (true) {
                l +%= ev.c;
                if (l & ev.d != 0) return;
                code2 = ev.sq(l);
                if (code2 != 0) break;
            }
            if (ev.friendly(code2)) { // $8E15
                ev.add(code2 +% 1, ev.c2);
                return;
            }
            ev.add(code2 -% 1, ev.c2);
            ev.pinCheck(r6, code2);
        } else {
            while (true) { // $8E19
                l +%= ev.c;
                if (l & ev.d != 0) return;
                code2 = ev.sq(l);
                if (code2 != 0) break;
            }
            if (ev.friendly(code2)) return;
            ev.pinCheck(r6, code2);
        }
    }

    /// $8DE1: is the piece behind the hit one a king (pin) or queen?
    fn pinCheck(ev: *Eval, r6: u8, code2: u8) void {
        const t = ev.rec(code2 +% 2);
        if (t & 1 != 0) {
            ev.pin(r6);
        } else if (t & 2 != 0) {
            if (ev.c2 & 0x40 != 0) {
                ev.e +%= 2; // $8E2B: a queen against a queen
            } else {
                ev.pin(r6);
            }
        }
    }

    /// $8E2F: record a pin (record, direction) in the list at $BD79.
    fn pin(ev: *Eval, r6: u8) void {
        const pins = &ev.s.pins;
        const rec_off = r6 & 0xF9;
        var l: usize = 0; // $BD79 + l
        while (true) {
            const a = pins[l];
            if (a == 0) break;
            l += 2;
            if (a == rec_off) {
                pins[l - 1] = 0;
                ev.e +%= 1;
                return;
            }
        }
        if (l + 0x79 >= 0x84) { // list full
            ev.e +%= 2;
            return;
        }
        pins[l] = rec_off;
        pins[l + 1] = ev.c;
        pins[l + 2] = 0;
        ev.f |= 0x20;
        ev.e +%= 2;
    }

    // ------------------------------------------------------- rooks, queens
    /// $8C4E
    fn rook(ev: *Eval, square: u8) Abort!void {
        ev.c2 = 0x10;
        try ev.orthogonals(square);
    }

    /// $8C43
    fn queen(ev: *Eval, square: u8) Abort!void {
        ev.c2 = 0x40;
        try ev.orthogonals(square);
        try ev.diagonals(square);
    }

    /// $8C52: horizontal rays (no mobility counted), then vertical rays.
    fn orthogonals(ev: *Eval, b: u8) Abort!void {
        ev.e2 = 0x08;
        for ([_]u8{ 0x01, 0xFF }) |c| {
            ev.c = c;
            var l = b;
            while (true) {
                l +%= c;
                if (l & 0x08 != 0) break;
                const code = ev.sq(l);
                if (code != 0) {
                    try ev.horizHit(code, l, b);
                    break;
                }
            }
        }
        for ([_]u8{ 0x10, 0xF0 }) |c| {
            ev.c = c;
            var l = b;
            while (true) {
                l +%= c;
                if (l & 0x80 != 0) break;
                ev.e +%= 1;
                const code = ev.sq(l);
                if (code != 0) {
                    if (ev.friendly(code)) { // $8C80
                        ev.add(code, ev.c2);
                        if (ev.rec(code +% 2) & ev.e2 != 0) ev.xrayChain(l);
                    } else {
                        try ev.enemyHit(code, l, b);
                    }
                    break;
                }
            }
        }
    }

    /// $8C98: first piece on a horizontal ray.
    fn horizHit(ev: *Eval, code: u8, start: u8, b: u8) Abort!void {
        if (!ev.friendly(code)) {
            try ev.enemyHit(code, start, b);
            return;
        }
        ev.add(code, ev.c2);
        if (ev.rec(code +% 2) & ev.e2 == 0) return;
        var l = start;
        var code2: u8 = undefined;
        while (true) { // $8CA7
            l +%= ev.c;
            if (l & ev.d != 0) return;
            code2 = ev.sq(l);
            if (code2 != 0) break;
        }
        if (ev.friendly(code2)) {
            ev.add(code2 +% 1, ev.c2);
        } else {
            ev.add(code2 -% 1, ev.c2);
        }
    }

    // ------------------------------------------------------------ kings
    /// $8978 (with $8915): the king of the $00 record; before move 8 the
    /// early-queen penalty (9 - move number) for both queens.
    fn whiteKing(ev: *Eval, h: u8, l: u8) Abort!void {
        if (ev.f & 0x01 == 0) {
            const c = (~ev.s.move_number) +% 0x0A;
            if (ev.rec(0x89) & 0x10 != 0 and ev.rec(0x88) & 0x80 == 0) ev.e +%= c;
            if (ev.rec(0x09) & 0x10 != 0 and ev.rec(0x08) & 0x80 == 0) ev.e -%= c;
        }
        try ev.king(h, l);
    }

    /// $897D: king safety; C = weight of each neighbour in the king zone.
    fn king(ev: *Eval, h: u8, l: u8) Abort!void {
        if (ev.f & 0x04 != 0) return ev.endgameKing(h, l);
        if (h & 0x20 != 0) { // castled
            if (h & 0xC0 != 0) return ev.kingAwayFromEdge(h, l);
            ev.c = 0x0A;
            // pawn shelter two ranks ahead (looks behind when ahead is off the board)
            var t = l +% 0x1F;
            if (t & 0x80 != 0) t -%= 0x40;
            if ((ev.sq(t) | ev.sq(t +% 1) | ev.sq(t +% 2)) & 0x40 == 0) ev.e -%= 2;
            return ev.kingScan(l);
        }
        if (h & 0x10 == 0) { // $8A0D: not moved
            ev.c = 0;
            ev.e +%= 1;
            return ev.kingScan(l);
        }
        ev.e -%= 6; // $8A1A: moved, not castled
        ev.c = 0x08;
        if (h & 0xC0 != 0) return ev.kingAwayFromEdge(h, l);
        return ev.kingScan(l);
    }

    /// $89FB: king away from the edge in the middle game.
    fn kingAwayFromEdge(ev: *Eval, h: u8, l: u8) Abort!void {
        ev.c = 0x04;
        ev.e -%= if (h & 0x80 != 0) 5 else 3;
        try ev.kingScan(l);
    }

    /// $8943: endgame king.
    fn endgameKing(ev: *Eval, h: u8, l: u8) Abort!void {
        const s = ev.s;
        if (ev.f & 0x08 == 0) {
            ev.c = 0x08;
            return ev.kingScan(l);
        }
        ev.c = 0x04; // $894F
        var d: u8 = (h & 0xC0) >> 3;
        const pressing = s.pressing;
        if (pressing != 0 and (pressing ^ ev.f) & 0x80 == 0) {
            if (s.pawns_exist != 0) { // $88D4
                ev.ap +%= d;
            } else {
                // pawnless: drive the king towards the centre
                if (d == 0) d = 0xF6;
                const f = ((l & 7) + 1) >> 1;
                const r = l & 0x70;
                if (f == 2 or r == 0x30 or r == 0x40) {
                    ev.ap +%= 0x10 +% d;
                } else if ((l & 7) == 2 or (l & 7) == 5 or r == 0x20 or r == 0x50) {
                    ev.ap +%= 0x08 +% d;
                } else {
                    ev.ap +%= d;
                }
            }
            return ev.kingScan(l);
        }
        const a: u8 = if (pressing != 0) s.pawns_exist else 0;
        d >>= 1; // $8966
        if (a == 0 and h & 0x80 != 0) ev.ap +%= 0x08;
        ev.ap +%= d;
        try ev.kingScan(l);
    }

    /// $89AC: the king's neighbours (no edge check for the files).
    fn kingScan(ev: *Eval, b: u8) Abort!void {
        for ([_]u8{ b -% 1, b +% 1 }) |l| try ev.kingNeighbourAt(l);
        var t = b +% 0x10;
        if (t & 0x80 == 0) {
            for ([_]u8{ t, t +% 1, t -% 1 }) |l| try ev.kingNeighbourAt(l);
        }
        t = b +% 0xF0;
        if (t & 0x80 != 0) return;
        for ([_]u8{ t, t +% 1, t -% 1 }) |l| try ev.kingNeighbourAt(l);
    }

    fn kingNeighbourAt(ev: *Eval, l: u8) Abort!void {
        const code = ev.sq(l);
        if (code != 0) try ev.kingNeighbour(code);
    }

    /// $89E2: a piece next to the king. Kings touching: illegal.
    fn kingNeighbour(ev: *Eval, code: u8) Abort!void {
        var p: u8 = undefined;
        if (ev.friendly(code)) {
            p = code +% 1;
        } else {
            if ((code +% 1) & 0x78 == 0) return error.Abort;
            p = code -% 1;
        }
        ev.add(p, 1);
        if (p & 0x40 != 0) ev.ap +%= ev.c; // pawn record: shelter
    }

    // ------------------------------------------------------------ pins
    /// $8E74: remove the attacks of pinned pieces (not along the pin line).
    fn removePinnedAttacks(ev: *Eval) void {
        const s = ev.s;
        const save_d = ev.d;
        const save_e = ev.e;
        var i: usize = 0; // $BD79 + i
        while (true) {
            const record = s.pins[i];
            const pdir = s.pins[i + 1];
            ev.f = record & 0x80;
            const square = s.rec[record];
            const t = s.rec[record +% 1] & 0x8E;
            ev.d = 0x88;
            if (t == 0 or (t & 0x80 != 0 and t & 0x02 == 0)) {
                ev.undoPawn(square, pdir);
            } else if (t & 0x80 != 0) {
                ev.c2 = 0xFC;
                ev.undoDiagonals(square, pdir);
            } else if (t < 4) {
                // a pinned knight loses all its attacks; kingCheck cannot
                // abort here because bit 4 (second pass) is set
                ev.c2 = 0xFC;
                ev.f |= 0x10;
                ev.knightWalk(square) catch unreachable;
            } else if (t == 4) {
                ev.c2 = 0xF0;
                ev.undoOrthogonals(square, pdir);
            } else {
                ev.c2 = 0xC0;
                ev.undoOrthogonals(square, pdir);
                ev.undoDiagonals(square, pdir);
            }
            if (s.pins[i + 2] == 0) break;
            i += 2;
        }
        ev.d = save_d;
        ev.e = save_e;
        s.pins[0] = 0;
    }

    /// $8E9F: a pinned pawn loses its captures off the pin line.
    fn undoPawn(ev: *Eval, square: u8, pdir: u8) void {
        const c0: u8 = if (ev.f & 0x80 != 0) 0xEF else 0x0F;
        for ([_]u8{ c0, c0 +% 2 }) |c| {
            if (pdir == c or 0 -% pdir == c) continue;
            const code = ev.sq(square +% c);
            if (code == 0) continue;
            if (ev.friendly(code)) {
                ev.add(code, 0xFF);
            } else {
                ev.add(code -% 2, 0xFF);
            }
        }
    }

    /// $8ED7
    fn undoOrthogonals(ev: *Eval, square: u8, pdir: u8) void {
        ev.undoLine(square, pdir, 0x01);
        ev.undoLine(square, pdir, 0x10);
    }

    /// $8EED
    fn undoDiagonals(ev: *Eval, square: u8, pdir: u8) void {
        ev.undoLine(square, pdir, 0x0F);
        ev.undoLine(square, pdir, 0x11);
    }

    /// $8EF4: both directions of a line unless it is the pin line.
    fn undoLine(ev: *Eval, b: u8, pdir: u8, c: u8) void {
        if (pdir == c or 0 -% pdir == c) return;
        ev.undoRay(b, c);
        ev.undoRay(b, 0 -% c);
    }

    /// $8F05: direct attacks only (no x-rays).
    fn undoRay(ev: *Eval, b: u8, c: u8) void {
        var l = b;
        var code: u8 = undefined;
        while (true) {
            l +%= c;
            if (l & 0x88 != 0) return;
            code = ev.sq(l);
            if (code != 0) break;
        }
        if (ev.friendly(code)) {
            ev.add(code, ev.c2);
        } else {
            ev.add(code -% 2, ev.c2);
        }
    }

    // ------------------------------------------- exchange evaluation, result
    /// $84A9: mark the moved piece, phase scaling, pins, then SEE for both
    /// sides and the combination.
    fn final(ev: *Eval) Result {
        const s = ev.s;
        if (ev.f & 0x40 == 0) {
            // no check given: the moved piece counts as attacked-by-bit 1
            const code = ev.sq(ev.to_sq);
            if (code & 0x04 != 0) s.rec[code +% 1] |= 0x02;
        }
        if (ev.f & 0x08 != 0) {
            if (s.pawns_exist == 0) ev.e = sra(ev.e);
            ev.e = sra(ev.e);
        }
        if (ev.f & 0x20 != 0) ev.removePinnedAttacks();
        ev.e = sra(sra(ev.ap)) +% ev.e +% s.drift;
        s.see_best = 0;
        s.see_second = 0;
        ev.seeSide(0x88);
        ev.e = 0 -% ev.e;
        const black_best = s.see_best;
        const black_second = s.see_second;
        s.see_best = 0;
        s.see_second = 0;
        ev.seeSide(0x08);
        return ev.combine(black_best, black_second);
    }

    /// The 15 non-king records of one side: SEE for each attacked piece;
    /// attack bytes cleared.
    fn seeSide(ev: *Eval, base: u8) void {
        const values = [_]u8{ 9, 5, 5, 3, 3, 3, 3 };
        for (0..15) |i| {
            const a: usize = base + 8 * i;
            const r = ev.s.rec[a..][0..6];
            if (r[2] != 0 or r[3] != 0) {
                const v = if (i < 7) values[i] else r[1] & 0x0F;
                ev.see(v, r[2], r[3], r[4], r[5]);
                r[2] = 0;
                r[3] = 0;
            }
            r[4] = 0;
            r[5] = 0;
        }
    }

    /// $8AD6: static exchange on a piece of value `v`. Attack byte +2 (L) and
    /// +3 (H) list the attackers, +4 (C) and +5 (Bm) the defenders, each as
    /// four 2-bit counts (pawn 1, minor 3, rook 5, queen 9); H bit 0 and Bm
    /// bit 0 are the kings (value 13). The two coroutines of the original
    /// ($8C09, $8C1F; IY/IX continuations) are the `AttackerGen` and
    /// `DefenderGen` state machines below.
    fn see(ev: *Eval, v: u8, l: u8, h: u8, c: u8, bm: u8) void {
        const s = ev.s;
        if (l == 0 and h & 1 == 0) return;
        var att: AttackerGen = .{ .lo = l, .hi = h };
        var dfn: DefenderGen = .{ .lo = c, .hi = bm };
        var attv: u8 = 0;
        var attn: u8 = 0;
        if (att.next()) |p| {
            attv = p.value;
            attn = p.count;
        }
        var defv: u8 = 0;
        var defn: u8 = 0;
        if (dfn.next(ev)) |p| {
            defv = p.value;
            defn = p.count;
        }
        var a = v;
        var lo: u8 = 0xFF;
        var hi = v;
        while (true) {
            var b: u8 = 0;
            if (defv & 1 == 0) break;
            a -%= attv;
            attn -%= 1;
            if (attn == 0) {
                if (att.next()) |p| {
                    attv = p.value;
                    attn = p.count;
                } else attv = 0;
            }
            if ((a -% lo) & 0x80 != 0) {
                b = 1;
            } else if ((a -% hi) & 0x80 == 0) {
                b = 2;
            } else {
                lo = a;
            }
            if (attv & 1 == 0) break;
            a +%= defv;
            if ((a -% lo) & 0x80 != 0) {
                b -%= 1;
                if (b == 0) break;
            } else if ((a -% hi) & 0x80 == 0) {
                b -%= 2;
                if (b == 0) break;
            } else {
                hi = a;
            }
            defn -%= 1;
            if (defn == 0) {
                if (dfn.next(ev)) |p| {
                    defv = p.value;
                    defn = p.count;
                } else defv = 0;
            }
        }
        if ((a -% lo) & 0x80 != 0) a = lo;
        if ((a -% hi) & 0x80 == 0) a = hi;
        if (a & 0x80 != 0) return;
        if (a != 0) {
            const best = s.see_best;
            if (a >= best) {
                s.see_best = a;
                a = best;
            }
            if (a >= s.see_second) s.see_second = a;
        }
        ev.e -%= 1;
        if (bm & 0x02 != 0) {
            ev.flags.* |= 0x04;
            ev.e -%= 2;
        }
    }

    /// $8797: material (relative to the search root) after the expected
    /// captures, plus the clamped positional term and the $BCCE noise.
    fn combine(ev: *Eval, bb: u8, bs: u8) Result {
        const s = ev.s;
        var pos = ev.e;
        const wb = s.see_best;
        const ws = s.see_second;
        var sb: u8 = undefined;
        var ss: u8 = undefined;
        var mb: u8 = undefined;
        var ms: u8 = undefined;
        var a: u8 = undefined;
        if (s.side_phase & 1 != 0) {
            pos = 0 -% pos;
            sb = wb;
            ss = ws;
            mb = bb;
            ms = bs;
            a = s.material_delta;
        } else {
            sb = bb;
            ss = bs;
            mb = wb;
            ms = ws;
            a = 0 -% s.material_delta;
        }
        a -%= mb;
        a +%= a;
        if ((mb -% 1) & 0x80 == 0) {
            // the side to move can win material
            ev.flags.* |= 0x02;
            if (mb != 1) a -%= 1;
            a -%= ms;
        }
        if ((sb -% 1) & 0x80 == 0) {
            // the mover threatens material
            var goto_e2 = false;
            if (ev.flags.* & 0x04 != 0) {
                goto_e2 = true;
            } else {
                pos +%= 2;
                if ((ss -% 1) & 0x80 != 0) {
                    goto_e2 = true;
                } else {
                    ev.flags.* |= 0x40;
                    pos +%= 2;
                    if ((ss -% 2) & 0x80 == 0) pos +%= 2;
                }
            }
            if (goto_e2 and sb -% 1 >= mb) ev.flags.* |= 0x40;
        }
        ev.b_out = pos;
        if (!(a < 0x1C or a >= 0xE4)) {
            return .{ .a = if (a & 0x80 != 0) 0x02 else 0xFC, .b = pos, .c = 0 };
        }
        const c = a *% 4;
        var t = sra(pos);
        t = t +% pos +% (pos & 1);
        t = sra(t);
        s.random +%= 1;
        const r = s.random & @as(u8, if (s.move_number == 1) 3 else 1);
        t +%= r;
        if (!(t < 0x0C or t >= 0xF4)) t = if (t & 0x80 != 0) 0xF4 else 0x0C;
        return .{ .a = t +% c +% 0x80, .b = pos, .c = c };
    }
};

/// Arithmetic shift right of a byte (SRA).
fn sra(x: u8) u8 {
    return (x >> 1) | (x & 0x80);
}

const Group = struct { value: u8, count: u8 };

/// Attacker coroutine ($8C09): pawns, minors, rooks, queens from byte +2,
/// then minors, rooks, queens from byte +3 (x-rays) and finally the king.
const AttackerGen = struct {
    lo: u8,
    hi: u8,
    /// Position: 0-3 fields of `lo`, 4-6 fields of `hi`, 7 king, 8 done.
    pos: u8 = 0,

    fn next(g: *AttackerGen) ?Group {
        while (true) {
            switch (g.pos) {
                0...3 => {
                    if (g.pos == 0 and g.lo == 0) {
                        g.pos = 4; // straight to the second byte
                        continue;
                    }
                    const i = g.pos;
                    g.pos += 1;
                    const n = (g.lo >> @intCast(2 * i)) & 3;
                    if (g.pos == 4 and g.hi == 0) g.pos = 8;
                    if (n != 0) return .{ .value = field_value[i], .count = n };
                },
                4...6 => {
                    const i = g.pos - 3;
                    g.pos += 1;
                    const n = (g.hi >> @intCast(2 * i)) & 3;
                    if (n != 0) return .{ .value = field_value[i], .count = n };
                },
                7 => {
                    g.pos = 8;
                    if (g.hi & 1 != 0) return .{ .value = 13, .count = 1 };
                },
                else => return null,
            }
        }
    }
};

/// Defender coroutine ($8C1F): byte +4, then byte +5 and the king. Reaching
/// the king costs the side being evaluated one point (E - 1) at that moment.
const DefenderGen = struct {
    lo: u8,
    hi: u8,
    pos: u8 = 0,

    fn next(g: *DefenderGen, ev: *Eval) ?Group {
        while (true) {
            switch (g.pos) {
                0...3 => {
                    if (g.pos == 0 and g.lo == 0) {
                        g.pos = 4;
                        if (g.hi == 0) g.pos = 8;
                        continue;
                    }
                    const i = g.pos;
                    g.pos += 1;
                    const n = (g.lo >> @intCast(2 * i)) & 3;
                    if (g.pos == 4 and g.hi == 0) g.pos = 8;
                    if (n != 0) return .{ .value = field_value[i], .count = n };
                },
                4...6 => {
                    const i = g.pos - 3;
                    g.pos += 1;
                    const n = (g.hi >> @intCast(2 * i)) & 3;
                    if (n != 0) return .{ .value = field_value[i], .count = n };
                },
                7 => {
                    g.pos = 8;
                    if (g.hi & 1 != 0) {
                        ev.e -%= 1;
                        return .{ .value = 13, .count = 1 };
                    }
                },
                else => return null,
            }
        }
    }
};

/// Values of the four 2-bit fields: pawn, minor, rook, queen.
const field_value = [_]u8{ 1, 3, 5, 9 };

// ---------------------------------------------------------------- tests

const golden = @import("golden.zig");
const state_mod = @import("state.zig");

test "evaluation matches all 30,000 golden records" {
    const gpa = std.testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, "eval.jsonl.gz"));
    defer g.deinit();
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    var mismatches: usize = 0;
    var junk_cases: usize = 0;
    var junk_mismatches: usize = 0;
    for (0..g.lines.len) |i| {
        _ = arena.reset(.retain_capacity);
        const p = try g.parse(arena.allocator(), i);
        const obj = p.value.object;
        s.* = .{};
        const st = obj.get("state").?.object;
        try golden.loadState(s, st);
        const junk = hasUnrepresentableJunk(st.get("offboard").?.string);
        if (junk) junk_cases += 1;
        const ix = state_mod.list_base;
        _ = try std.fmt.hexToBytes(s.entry(ix), obj.get("ix").?.string);
        const r = evaluate(s, ix);
        const out = obj.get("out").?.object;
        const want_a: u8 = @intCast(try golden.int(out, "A"));
        const ok = r.a == want_a and
            (want_a == 0 or r.b == @as(u8, @intCast(try golden.int(out, "B")))) and
            s.entry(ix)[3] == @as(u8, @intCast(try golden.int(out, "ix3"))) and
            s.random == @as(u8, @intCast(try golden.int(out, "BCCE"))) and
            s.sel_marker == @as(u8, @intCast(try golden.int(out, "BD4E"))) and
            s.see_best == @as(u8, @intCast(try golden.int(out, "BD39"))) and
            s.see_second == @as(u8, @intCast(try golden.int(out, "BD3A")));
        if (!ok and junk) junk_mismatches += 1;
        if (!ok and !junk) {
            mismatches += 1;
            if (mismatches <= 10) std.debug.print(
                "eval record {d} ({s}): got A={X:0>2} B={X:0>2} ix3={X:0>2} BCCE={X:0>2} BD4E={X:0>2} BD39={X:0>2} BD3A={X:0>2}\n",
                .{ i, obj.get("src").?.string, r.a, r.b, s.entry(ix)[3], s.random, s.sel_marker, s.see_best, s.see_second },
            );
        }
    }
    std.debug.print("eval golden: {d} records, {d} with unrepresentable off-board junk ({d} of them differ), {d} other mismatches\n", .{ g.lines.len, junk_cases, junk_mismatches, mismatches });
    try std.testing.expectEqual(@as(usize, 30000), g.lines.len);
    try std.testing.expectEqual(@as(usize, 0), mismatches);
}

/// True if a captured state has a non-zero byte in the board's off-board
/// columns 8 or 15 at an address that holds no original variable.
fn hasUnrepresentableJunk(offboard_hex: []const u8) bool {
    var off: [64]u8 = undefined;
    _ = std.fmt.hexToBytes(&off, offboard_hex) catch return true;
    for (0..8) |r| {
        for ([_]usize{ 0, 7 }) |c| {
            const addr: u16 = @intCast(0xBD08 + r * 16 + c);
            if (off[r * 8 + c] != 0 and addr != 0xBD58 and addr != 0xBD7F) return true;
        }
    }
    return false;
}
