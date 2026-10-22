//! Perft: a stress test of the ported move generator and make/unmake against
//! published move-path counts (AGENTS.md §6 Phase 4, §10.4).
//!
//! Positions are loaded through the engine's real FEN path (the original's
//! set-up mode, game.loadFen). Moves come from the ported generator ($78CE),
//! filtered by the independent legality test (legal.zig), and are made and
//! unmade with the ported $810F/$821C. The original never generates
//! under-promotions (it always queens), so a true perft adds them the way the
//! original's game-move path does: make the queen promotion, then overwrite
//! the piece's type byte (ChoosePromotion $63B1: rook 5, knight 3, bishop $83).

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const board = @import("board.zig");
const movegen = @import("movegen.zig");
const legal = @import("legal.zig");
const game = @import("game.zig");

/// Type bytes ChoosePromotion writes for an under-promotion (moved bit clear).
const underpromotions = [_]u8{ 0x05, 0x03, 0x83 };

pub const Mode = enum {
    /// Every legal move, under-promotions included: comparable with published
    /// perft counts.
    full,
    /// The moves the original itself would consider: queen promotions only.
    original,
};

/// Count the leaf nodes `depth` plies below the current position.
pub fn perft(s: *State, depth: u32, mode: Mode) u64 {
    if (depth == 0) return 1;
    const p = s.ply;
    _ = movegen.generate(s, st.root_record);
    // Walk the list up to the next ply's start (the header count is the
    // original's, which DEV-001 only fixes for the count byte itself).
    const first = st.listOffset(s.slot[p]) + 4;
    const end = st.listOffset(s.slot[p + 1]);
    var nodes: u64 = 0;
    var off = first;
    while (off < end) : (off += 4) {
        const entry = st.listAddr(off);
        const e = s.entry(entry).*;
        const from = e[1];
        const to = e[2];
        if (!legal.isLegal(s, from, to)) continue;
        const promo = isPromotion(s, from, to);
        const variants: u32 = if (promo and mode == .full) 4 else 1;
        if (depth == 1) {
            nodes += variants;
            continue;
        }
        for (0..variants) |v| nodes += child(s, entry, depth, if (v == 0) null else underpromotions[v - 1]);
    }
    return nodes;
}

/// Perft split by root move (UCI notation and count), for locating errors.
pub fn divide(s: *State, depth: u32, w: *std.Io.Writer) !u64 {
    const p = s.ply;
    _ = movegen.generate(s, st.root_record);
    const end = st.listOffset(s.slot[p + 1]);
    var total: u64 = 0;
    var off = st.listOffset(s.slot[p]) + 4;
    while (off < end) : (off += 4) {
        const entry = st.listAddr(off);
        const e = s.entry(entry).*;
        if (!legal.isLegal(s, e[1], e[2])) continue;
        const promo = isPromotion(s, e[1], e[2]);
        const letters = [_]u8{ 'q', 'r', 'n', 'b' };
        for (0..if (promo) @as(usize, 4) else 1) |v| {
            const n = if (depth <= 1) 1 else child(s, entry, depth, if (v == 0) null else underpromotions[v - 1]);
            total += n;
            try w.print("{s}{s}", .{ name(e[1]), name(e[2]) });
            if (promo) try w.writeByte(letters[v]);
            try w.print(": {d}\n", .{n});
        }
    }
    try w.print("total: {d}\n", .{total});
    return total;
}

fn name(sq: u8) [2]u8 {
    return .{ 'a' + (sq & 7), '8' - (sq >> 4) };
}

fn child(s: *State, entry: u32, depth: u32, under: ?u8) u64 {
    const saved_root = s.root_rec;
    var undo: board.Undo = undefined;
    // A score of $FF makes $810F put the king's code on the castling rook's
    // square (the root-scoring trick); like ReplayStep ($6690), clear it first.
    s.entry(entry)[0] = 0;
    board.make(s, entry, &undo);
    if (under) |t| {
        // ChoosePromotion: overwrite the promoted piece's type byte.
        const r = s.board[s.entry(entry)[2]] & 0xFB;
        s.rec[r +% 1] = t;
    }
    // The move becomes "the last move" for en passant and castling, as the
    // root record is after a game move.
    s.root_rec = s.entry(entry).*;
    s.side_phase ^= 1;
    s.ply += 1;
    const n = perft(s, depth - 1, .full);
    s.ply -= 1;
    s.side_phase ^= 1;
    s.root_rec = saved_root;
    board.unmake(s, &undo);
    return n;
}

fn isPromotion(s: *const State, from: u8, to: u8) bool {
    const code = s.board[from];
    if (code == 0) return false;
    if (s.rec[(code & 0xFB) +% 1] & 0x0F != 1) return false; // not a pawn
    const row = to >> 4;
    return row == 0 or row == 7;
}

/// Load `fen` and prepare the state for perft. Returns an error if the
/// original's set-up mode rejects the position.
pub fn load(s: *State, fen: []const u8) !void {
    s.* = .{};
    _ = game.coldStart(s);
    _ = try game.loadFen(s, fen);
    s.ply = 1;
    s.slot[1] = st.list_base;
    s.list_limit = st.listAddr(st.list_bytes_extended - 4);
    s.search_flags = 0;
}

/// One EPD line: "<fen> ;D1 n ;D2 n ...".
pub const Case = struct {
    fen: []const u8,
    counts: [8]?u64 = @splat(null),
};

pub fn parseLine(line: []const u8) ?Case {
    var it = std.mem.splitScalar(u8, line, ';');
    const fen = std.mem.trim(u8, it.next() orelse return null, " \t\r");
    if (fen.len == 0) return null;
    var c: Case = .{ .fen = fen };
    while (it.next()) |field| {
        const f = std.mem.trim(u8, field, " \t\r");
        if (f.len < 3 or f[0] != 'D') continue;
        var parts = std.mem.tokenizeScalar(u8, f[1..], ' ');
        const d = std.fmt.parseInt(usize, parts.next() orelse continue, 10) catch continue;
        const n = std.fmt.parseInt(u64, parts.next() orelse continue, 10) catch continue;
        if (d < c.counts.len) c.counts[d] = n;
    }
    return c;
}

fn checkCase(s: *State, line: []const u8, max_depth: u32) !void {
    const c = parseLine(line).?;
    try load(s, c.fen);
    var d: u32 = 1;
    while (d <= max_depth) : (d += 1) {
        const want = c.counts[d] orelse break;
        const got = perft(s, d, .full);
        if (got != want) {
            std.debug.print("perft {s} depth {d}: got {d}, want {d}\n", .{ c.fen, d, got, want });
            return error.PerftMismatch;
        }
    }
}

test "perft: start position, Kiwipete, castling, en passant and promotion positions" {
    const gpa = std.testing.allocator;
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    try checkCase(s, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 ;D1 20 ;D2 400 ;D3 8902 ;D4 197281", 4);
    try checkCase(s, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1 ;D1 48 ;D2 2039 ;D3 97862", 3);
    try checkCase(s, "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1 ;D1 26 ;D2 568 ;D3 13744", 3);
    try checkCase(s, "n1n5/PPPk4/8/8/8/8/4Kppp/5N1N b - - 0 1 ;D1 24 ;D2 496 ;D3 9483", 3);
    try checkCase(s, "8/2k1p3/3pP3/3P2K1/8/8/8/8 b - - 0 1 ;D1 5 ;D2 35 ;D3 182 ;D4 1091", 4);
}
