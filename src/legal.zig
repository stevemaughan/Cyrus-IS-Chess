//! An independent full-legality test (DEV-005, AGENTS.md §8.2) and a legal
//! move generator for the UCI layer. It reads the port's board and piece
//! records but never writes the engine state, and it does not use the
//! original's move generator: it is the safety net that guarantees no illegal
//! `bestmove`, and the source of the root moves for `searchmoves`.
//!
//! Conventions (docs/arch/00-overview.md): square = (8 - rank) * 16 + file;
//! a piece code has bit 7 set for White; its record's type byte has the value
//! in the low nibble (K0 Q9 R5 B3 N3 P1; a bishop also has bit 7); White pawns
//! move towards row 0.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;

pub const Kind = enum { none, king, queen, rook, bishop, knight, pawn };

/// The kind of the piece with code `code` (0 = empty).
pub fn kindOf(s: *const State, code: u8) Kind {
    if (code == 0) return .none;
    const t = s.rec[(code & 0xFB) +% 1];
    return switch (t & 0x0F) {
        0 => .king,
        9 => .queen,
        5 => .rook,
        3 => if (t & 0x80 != 0) .bishop else .knight,
        1 => .pawn,
        else => .none,
    };
}

fn isWhite(code: u8) bool {
    return code & 0x80 != 0;
}

const diagonals = [_]u8{ 0x0F, 0x11, 0xEF, 0xF1 };
const orthogonals = [_]u8{ 0x01, 0xFF, 0x10, 0xF0 };
const knight_steps = [_]u8{ 0x0E, 0x12, 0x1F, 0x21, 0xF2, 0xEE, 0xE1, 0xDF };

/// A position for legality tests: a copy of the board's on-board squares.
const Board = struct {
    sq: [128]u8,
    s: *const State,

    fn at(b: *const Board, x: u8) u8 {
        return if (x & 0x88 != 0) 0 else b.sq[x];
    }

    /// Is `target` attacked by a piece of colour `by_white`?
    fn attacked(b: *const Board, target: u8, by_white: bool) bool {
        // pawns: a White pawn on p attacks p - 15 and p - 17
        const pawn_from = if (by_white) [2]u8{ target +% 0x0F, target +% 0x11 } else [2]u8{ target -% 0x0F, target -% 0x11 };
        for (pawn_from) |p| {
            if (p & 0x88 != 0) continue;
            const c = b.at(p);
            if (c != 0 and isWhite(c) == by_white and kindOf(b.s, c) == .pawn) return true;
        }
        for (knight_steps) |d| {
            const p = target +% d;
            if (p & 0x88 != 0) continue;
            const c = b.at(p);
            if (c != 0 and isWhite(c) == by_white and kindOf(b.s, c) == .knight) return true;
        }
        for (diagonals ++ orthogonals) |d| {
            const p = target +% d;
            if (p & 0x88 != 0) continue;
            const c = b.at(p);
            if (c != 0 and isWhite(c) == by_white and kindOf(b.s, c) == .king) return true;
        }
        inline for (.{ diagonals, orthogonals }, .{ Kind.bishop, Kind.rook }) |dirs, slider| {
            for (dirs) |d| {
                var p = target;
                while (true) {
                    p +%= d;
                    if (p & 0x88 != 0) break;
                    const c = b.at(p);
                    if (c == 0) continue;
                    if (isWhite(c) == by_white) {
                        const k = kindOf(b.s, c);
                        if (k == .queen or k == slider) return true;
                    }
                    break;
                }
            }
        }
        return false;
    }

    fn kingSquare(b: *const Board, white: bool) ?u8 {
        for (0..128) |i| {
            const x: u8 = @intCast(i);
            if (x & 0x88 != 0) continue;
            const c = b.sq[x];
            if (c != 0 and isWhite(c) == white and kindOf(b.s, c) == .king) return x;
        }
        return null;
    }
};

fn snapshot(s: *const State) Board {
    return .{ .sq = s.board, .s = s };
}

/// The side to move: bit 0 of $BD2D (1 = White).
pub fn whiteToMove(s: *const State) bool {
    return s.side_phase & 1 != 0;
}

/// The en passant target square, if the last game move (the root record)
/// was a double pawn step.
pub fn epTarget(s: *const State) ?u8 {
    const from = s.root_rec[1];
    const to = s.root_rec[2];
    if (from & 0x88 != 0 or to & 0x88 != 0) return null;
    const d = if (to > from) to - from else from - to;
    if (d != 0x20) return null;
    if (kindOf(s, s.square(to)) != .pawn) return null;
    return (from + to) / 2;
}

/// Is the move (from, to) legal for the side to move in the state's
/// position? Promotions are legal with any piece; the caller decides which.
pub fn isLegal(s: *const State, from: u8, to: u8) bool {
    if (from & 0x88 != 0 or to & 0x88 != 0 or from == to) return false;
    const white = whiteToMove(s);
    const mover = s.board[from];
    if (mover == 0 or isWhite(mover) != white) return false;
    const target = s.board[to];
    if (target != 0 and isWhite(target) == white) return false;
    if (target != 0 and kindOf(s, target) == .king) return false;
    const kind = kindOf(s, mover);
    var b = snapshot(s);
    if (!pseudoLegal(s, &b, kind, white, from, to)) return false;
    // castling: not out of, through or into check
    if (kind == .king and (to -% from == 2 or from -% to == 2)) {
        if (b.attacked(from, !white)) return false;
        const transit = if (to > from) from + 1 else from - 1;
        if (b.attacked(transit, !white)) return false;
        const rook_from: u8 = if (to & 0x04 != 0) to + 1 else to - 2;
        const rook_to: u8 = if (to & 0x04 != 0) to - 1 else to + 1;
        b.sq[rook_to] = b.sq[rook_from];
        b.sq[rook_from] = 0;
    }
    // en passant: remove the captured pawn
    if (kind == .pawn and target == 0 and (from & 7) != (to & 7)) {
        const csq: u8 = if (to >= from) to - 0x10 else to + 0x10;
        b.sq[csq] = 0;
    }
    b.sq[to] = mover;
    b.sq[from] = 0;
    const k = b.kingSquare(white) orelse return false;
    return !b.attacked(k, !white);
}

fn pseudoLegal(s: *const State, b: *const Board, kind: Kind, white: bool, from: u8, to: u8) bool {
    const d = to -% from;
    switch (kind) {
        .none => return false,
        .knight => return std.mem.indexOfScalar(u8, &knight_steps, d) != null,
        .king => {
            if (std.mem.indexOfScalar(u8, &(diagonals ++ orthogonals), d) != null) return true;
            // castling: the king and the rook unmoved, the squares between empty
            if (to >> 4 != from >> 4 or (d != 2 and d != 0xFE)) return false;
            const r = s.board[from] & 0xFB;
            if (s.rec[r +% 1] & 0x10 != 0) return false;
            const rook_rec: u8 = (r & 0x80) | (if (d == 2) @as(u8, 0x18) else 0x10);
            if (s.rec[rook_rec] & 0x80 != 0 or s.rec[rook_rec +% 1] & 0x10 != 0) return false;
            const rook_sq = s.rec[rook_rec];
            if (rook_sq != (if (d == 2) from + 3 else from - 4)) return false;
            var x = from;
            while (x != rook_sq) {
                x = if (d == 2) x + 1 else x - 1;
                if (x != rook_sq and b.at(x) != 0) return false;
            }
            return true;
        },
        .pawn => {
            const fwd: u8 = if (white) 0xF0 else 0x10;
            const home_row: u8 = if (white) 6 else 1;
            if (d == fwd) return b.at(to) == 0;
            if (d == fwd *% 2) return from >> 4 == home_row and b.at(from +% fwd) == 0 and b.at(to) == 0;
            if (d == fwd +% 1 or d == fwd -% 1) {
                if (b.at(to) != 0) return true;
                return epTarget(s) == to;
            }
            return false;
        },
        .bishop, .rook, .queen => {
            const dirs: []const u8 = switch (kind) {
                .bishop => &diagonals,
                .rook => &orthogonals,
                else => &(diagonals ++ orthogonals),
            };
            for (dirs) |dir| {
                var x = from;
                while (true) {
                    x +%= dir;
                    if (x & 0x88 != 0) break;
                    if (x == to) return true;
                    if (b.at(x) != 0) break;
                }
            }
            return false;
        },
    }
}

pub const Move = struct { from: u8, to: u8 };

/// All legal moves of the side to move (promotions once, as the engine
/// always queens). Order: by from-square, then to-square.
pub fn legalMoves(s: *const State, out: []Move) usize {
    var n: usize = 0;
    for (0..128) |f| {
        const from: u8 = @intCast(f);
        if (from & 0x88 != 0 or s.board[from] == 0) continue;
        for (0..128) |t| {
            const to: u8 = @intCast(t);
            if (to & 0x88 != 0) continue;
            if (isLegal(s, from, to)) {
                if (n < out.len) out[n] = .{ .from = from, .to = to };
                n += 1;
            }
        }
    }
    return n;
}

/// Truncate a reported line at its first illegal move (AGENTS.md §8.2 point
/// 4). `scratch` receives a copy of `root` and is used to play the moves;
/// the engine state is not touched. Returns the legal prefix length.
/// `promos`, if given, receives for each legal move whether it promotes a
/// pawn, judged on the board before the move.
pub fn legalPrefix(root: *const State, scratch: *State, line: []const Move, promos: ?[]bool) usize {
    const board = @import("board.zig");
    scratch.* = root.*;
    for (line, 0..) |m, k| {
        if (!isLegal(scratch, m.from, m.to)) return k;
        const mover = scratch.board[m.from];
        const kind = kindOf(scratch, mover);
        if (promos) |p| p[k] = kind == .pawn and (m.to >> 4 == 0 or m.to >> 4 == 7);
        var flags: u8 = 0;
        if (scratch.board[m.to] != 0) flags |= 0x08;
        if (kind == .king and (m.to -% m.from == 2 or m.from -% m.to == 2)) flags = 0x10;
        if (kind == .pawn and scratch.board[m.to] == 0 and (m.from & 7) != (m.to & 7)) flags = 0x28;
        if (kind == .pawn and (m.to -% m.from == 0x20 or m.from -% m.to == 0x20)) flags = 0x20;
        scratch.lists[0..4].* = .{ 0, m.from, m.to, flags };
        var undo: board.Undo = undefined;
        board.make(scratch, st.list_base, &undo);
        scratch.root_rec = .{ 0, m.from, m.to, flags };
        scratch.side_phase ^= 1;
    }
    return line.len;
}

/// DEV-005 fallback: the first legal entry of the root list (generated at
/// `slot[1]`) in the original's order, or null. With `among`, only entries
/// whose (from, to) is listed there count (the `searchmoves` fallback).
pub fn firstLegalRootMove(s: *State, among: ?[]const Move) ?u32 {
    const start = st.listOffset(s.slot[1]) + 4;
    const end = st.listOffset(s.slot[2]);
    var off = start;
    while (off + 4 <= end) : (off += 4) {
        const e = s.lists[off..][0..4];
        const from = e[1] & 0x7F;
        if (!isLegal(s, from, e[2])) continue;
        if (among) |list| {
            for (list) |m| {
                if (m.from == from and m.to == e[2]) return st.listAddr(off);
            }
            continue;
        }
        return st.listAddr(off);
    }
    return null;
}

/// Whether (from, to) moves a pawn to the last rank.
pub fn isPawnPromotion(s: *const State, from: u8, to: u8) bool {
    if (from & 0x88 != 0 or to & 0x88 != 0) return false;
    return kindOf(s, s.board[from]) == .pawn and (to >> 4 == 0 or to >> 4 == 7);
}

test "root static scores agree with the legality test (search.jsonl.gz)" {
    const golden = @import("golden.zig");
    const movegen = @import("movegen.zig");
    const scoring = @import("scoring.zig");
    const gpa = std.testing.allocator;
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    const copy = try gpa.create(State);
    defer gpa.destroy(copy);
    var positions: usize = 0;
    var moves: usize = 0;
    var disagree: usize = 0;
    for ([_][]const u8{ "search.jsonl.gz", "search-high.jsonl.gz" }) |name| {
        var buf: [1024]u8 = undefined;
        var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, name));
        defer g.deinit();
        for (0..g.lines.len) |i| {
            var p = try g.parse(gpa, i);
            defer p.deinit();
            for (p.value.object.get("goes").?.array.items) |go| {
                s.* = .{};
                try golden.loadState(s, go.object.get("state").?.object);
                copy.* = s.*;
                s.search_flags = 0x40;
                const r = movegen.generate(s, st.root_record);
                scoring.scoreMoves(s, r.header, r.count, &@import("observer.zig").none);
                positions += 1;
                var off = st.listOffset(s.slot[1]) + 4;
                const end = st.listOffset(s.slot[2]);
                var legal_count: usize = 0;
                while (off < end) : (off += 4) {
                    const e = s.lists[off..][0..4];
                    const legal = isLegal(copy, e[1], e[2]);
                    if (legal) legal_count += 1;
                    moves += 1;
                    if (legal != (e[0] != 0)) {
                        if (disagree < 5) {
                            var b = snapshot(copy);
                            const w = whiteToMove(copy);
                            const r0 = copy.board[e[1]] & 0xFB;
                            std.debug.print("line {d}: {x:0>2}-{x:0>2} score {d} legal {} white {} pseudo {} chk {} transit {} kt {x} rook10 {x}/{x} rook18 {x}/{x}\n", .{ i, e[1], e[2], e[0], legal, w, pseudoLegal(copy, &b, kindOf(copy, copy.board[e[1]]), w, e[1], e[2]), b.attacked(e[1], !w), b.attacked(if (e[2] > e[1]) e[1] + 1 else e[1] - 1, !w), copy.rec[r0 + 1], copy.rec[(r0 & 0x80) | 0x10], copy.rec[(r0 & 0x80) | 0x11], copy.rec[(r0 & 0x80) | 0x18], copy.rec[(r0 & 0x80) | 0x19] });
                        }
                        disagree += 1;
                    }
                }
                var all: [256]Move = undefined;
                try std.testing.expectEqual(legal_count, legalMoves(copy, &all));
            }
        }
    }
    std.debug.print("legality: {d} positions, {d} root moves, {d} disagreements with root scoring\n", .{ positions, moves, disagree });
    try std.testing.expectEqual(@as(usize, 0), disagree);
}

test "hand positions" {
    // Start position via the game layer: 20 legal moves; e2e4 legal; e2e5 not.
    const game = @import("game.zig");
    const s = try std.testing.allocator.create(State);
    defer std.testing.allocator.destroy(s);
    s.* = .{};
    _ = game.coldStart(s);
    var all: [256]Move = undefined;
    try std.testing.expectEqual(@as(usize, 20), legalMoves(s, &all));
    try std.testing.expect(isLegal(s, 0x64, 0x44));
    try std.testing.expect(!isLegal(s, 0x64, 0x34));
    // castling through an attacked square is illegal; kingside is legal
    s.* = .{};
    _ = try game.loadFen(s, "r3k2r/ppp2ppp/8/8/8/5b2/PPPP1P1P/R3K2R w KQkq - 0 1");
    try std.testing.expect(isLegal(s, 0x74, 0x76));
    try std.testing.expect(!isLegal(s, 0x74, 0x72));
    // the pinned en passant capture is illegal
    s.* = .{};
    _ = try game.loadFen(s, "8/8/8/KPp4r/8/8/8/6k1 w - c6 0 1");
    try std.testing.expect(!isLegal(s, 0x31, 0x22));
    try std.testing.expect(isLegal(s, 0x31, 0x21));
}

test "legalPrefix: promotions are judged before the move" {
    // h2h1=Q, then the promoted queen (a pawn-slot queen, type $19) goes
    // h1-h2-g1: its move from the 2nd rank to the 1st is not a promotion.
    // fastchess flagged the PV "... a2b1q" for such a move.
    const game = @import("game.zig");
    const gpa = std.testing.allocator;
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    const scratch = try gpa.create(State);
    defer gpa.destroy(scratch);
    s.* = .{};
    _ = try game.loadFen(s, "k7/8/8/8/8/8/7p/K7 b - - 0 1");
    const line = [_]Move{
        .{ .from = 0x67, .to = 0x77 }, // h2h1=Q
        .{ .from = 0x70, .to = 0x61 }, // Ka1-b2
        .{ .from = 0x77, .to = 0x67 }, // Qh1-h2+
        .{ .from = 0x61, .to = 0x51 }, // Kb2-b3
        .{ .from = 0x67, .to = 0x76 }, // Qh2-g1
    };
    var promos: [line.len]bool = undefined;
    try std.testing.expectEqual(line.len, legalPrefix(s, scratch, &line, &promos));
    try std.testing.expectEqualSlices(bool, &.{ true, false, false, false, false }, &promos);
}
