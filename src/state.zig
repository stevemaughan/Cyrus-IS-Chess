//! Engine state of the Cyrus IS Chess port.
//!
//! Fidelity is behavioural (AGENTS.md §6 Phase 3): the memory layout of the
//! original is not reproduced, but every original variable that influences a
//! decision has one field here, named for its meaning, with the original
//! address in its comment. `get`/`set` map original addresses to fields; they
//! are used to load golden-file states and to compare results, never by the
//! engine itself.

const std = @import("std");

/// Deepest full-width depth in extended mode (docs/EXTENDED_SEARCH.md §2).
pub const max_depth = 60;
/// Deepest ply that can be made: D + 3.
pub const max_ply = max_depth + 3;
/// Per-ply tables are indexed 0 .. max_ply + 2.
pub const ply_slots = max_ply + 3;

/// Move lists. Original list addresses run from $B400; a full area ($BC80)
/// makes the generator abort the search. Extended mode stores more; list
/// addresses past the original area continue at $10000 so that they can never
/// equal another original address such as the root record $BD58.
pub const list_base: u32 = 0xB400;
pub const list_end_original: u32 = 0xBC80;
pub const list_bytes_original: u32 = list_end_original - list_base; // 2176 = 544 entries
pub const list_bytes_extended: u32 = 32768 * 4;

/// Address of the root move record ($BD58-$BD5B). IX points here when the root
/// list is generated; it is the last game move.
pub const root_record: u32 = 0xBD58;

/// Offsets up to $957 keep their original address $B400 + offset (pointer
/// values then match the original even past a list-full abort); larger ones
/// (extended mode only) continue at $10000 so they never reach $BD58.
const original_addressed: u32 = root_record - list_base;

pub fn listAddr(offset: u32) u32 {
    return if (offset < original_addressed) list_base + offset else 0x10000 + offset;
}

pub fn listOffset(addr: u32) u32 {
    return if (addr >= 0x10000) addr - 0x10000 else addr - list_base;
}

/// Source of the values the original reads from the Z80 R register ($7B89 in
/// the book; $60EB in the main loop). The engine uses a seeded PRNG (DEV-006);
/// golden tests replay the oracle's scripted bytes.
pub const RSource = struct {
    ctx: *anyopaque,
    nextFn: *const fn (ctx: *anyopaque) u8,

    pub fn next(r: *RSource) u8 {
        return r.nextFn(r.ctx);
    }
};

/// RSource over a fixed byte sequence (tests); counts the bytes used.
pub const ScriptedR = struct {
    bytes: []const u8,
    used: usize = 0,

    pub fn source(self: *ScriptedR) RSource {
        return .{ .ctx = self, .nextFn = nextImpl };
    }

    fn nextImpl(ctx: *anyopaque) u8 {
        const self: *ScriptedR = @ptrCast(@alignCast(ctx));
        const v = self.bytes[self.used];
        self.used += 1;
        return v;
    }
};

pub const record_capacity = 8192; // plies in the game record (original: up to ~16K)
pub const exclusion_capacity = 512; // bytes in the next-best list (pairs)

pub const State = struct {
    // ------------------------------------------------------------- position
    /// $BD00-$BD77: 0x88 board, square = (8 - rank) * 16 + file. 0 = empty,
    /// otherwise a piece code (bit 7 White, bit 2 set, code & $FB = record offset).
    /// Off-board squares are never stored here; see `offboard`.
    board: [128]u8 = @splat(0),
    /// $BE00-$BEFF: 32 piece records x 8 bytes, indexed by record offset
    /// (Black $00-$7F, White $80-$FF). +0 square (bit 7 absent), +1 type byte,
    /// +2..+5 evaluation attack counters, +6 line mask, +7 unused.
    rec: [256]u8 = @splat(0),

    // ------------------------------------------------------- side and game
    /// $BD2D: bit 0 = side to move (1 = White); bits 1-4 phase (set by pre-search).
    side_phase: u8 = 0,
    /// $BD49: move number (1 at the start, 10 after set-up; wraps at 256).
    move_number: u8 = 0,
    /// $BD0A: 50-move rule ply counter.
    fifty: u8 = 0,
    /// $BD58-$BD5B: root move record = last game move: score, from, to, flags.
    root_rec: [4]u8 = @splat(0),
    /// $BD5C, $BD5D: from and to of the side to move's previous move.
    prev_from: u8 = 0,
    prev_to: u8 = 0,
    /// $BD5E: count of consecutive reversing moves (6 = draw).
    reversals: u8 = 0,
    /// $BCA0 = V(1): root value of the last search; persists between moves.
    /// Stored as value[1].

    // ---------------------------------------------------- level and players
    /// $BCBD: search level parameter 0-7.
    level_param: u8 = 1,
    /// $BCCD: displayed level index 0-10 (Level 1-8, P1-P3).
    level_index: u8 = 1,
    /// $BCBE: side Cyrus plays (0 = White, non-zero = Black).
    cyrus_side: u8 = 1,
    /// $BCC2: players: 0 HvH, 1 HvC, 2 CvH, 3 CvC.
    players: u8 = 1,
    /// $BCDD: next-best search in progress.
    next_best: u8 = 0,
    /// $BCDF: book state (0 = following the book, $FF = out of book).
    book_state: u8 = 0,
    /// $BCCE: random accumulator (incremented by every evaluation).
    random: u8 = 0,
    /// $BCBF: game over (restricts commands).
    game_over: u8 = 0,
    /// $BCDE: promotion piece of the last move (display).
    promo_display: u8 = 0,
    /// $BD4D: set-up mode: position or side changed.
    setup_changed: u8 = 0,

    // ------------------------------------------------------------- search
    /// $BCA9: current ply (root = 1).
    ply: u8 = 1,
    /// $BCAA: full-width depth D.
    depth: u8 = 0,
    /// V(q) at $BC9F + q: value / alpha of ply q. V(0) = $BC9F = 0 means -inf;
    /// V(1) = $BCA0 is the root value. Set-up mode reuses V(3) = $BCA2 as its colour
    /// toggle ($83 White, $03 Black; initialised on entry at $6D67) and V(4) = $BCA3.
    value: [ply_slots]u8 = @splat(0),
    /// killer(q) at $BC91 + 2(q - 1): from, to. From bit 7 set = none.
    killer: [ply_slots][2]u8 = @splat(.{ 0, 0 }),
    /// curmove(q) at $BC83 + 2(q - 1): from, to of the move searched at ply q.
    curmove: [ply_slots][2]u8 = @splat(.{ 0, 0 }),
    /// slot(q) = word at $BCA9 + 2q: list address of ply q's header.
    /// Deeper slots keep stale values; the search reads them.
    slot: [ply_slots]u32 = @splat(0),
    /// $BD09: forward-pruning margin; bit 7 = pruning off.
    prune_margin: u8 = 0,
    /// $BDF6: threat-extension switch.
    threat_ext: u8 = 0,
    /// $BD0B: ply of the most recent mate detection; $BD0C: shortest root mate ply.
    mate_ply: u8 = 0,
    best_mate_ply: u8 = 0,
    /// $BD0D: material change since the search root (Black - White).
    material_delta: u8 = 0,
    /// $BD0E: loop counter of static scoring.
    score_count: u8 = 0,
    /// $BD19, $BD1A: best static score and its entry.
    best_static: u8 = 0,
    best_static_entry: u32 = 0,
    /// $BD29: entry of the move to play; $BD2B: root move being searched.
    move_to_play: u32 = 0,
    root_move: u32 = 0,
    /// $BD4B: header flags of the selective node being processed.
    sel_flags: u8 = 0,
    /// $BD4C: bit 7 abort, bit 6 computer to move.
    search_flags: u8 = 0,
    /// $BD4E: selective-node marker, overwritten by the evaluation.
    sel_marker: u8 = 0,
    /// $BD6E: second pass pending.
    second_pass: u8 = 0,

    // --------------------------------------------- pre-search and evaluation
    /// $BD1E: endgame "who is pressing" (signed).
    pressing: u8 = 0,
    /// $BD2E: 8 x clamped material difference.
    material_term: u8 = 0,
    /// $BD4A: positional drift.
    drift: u8 = 0,
    /// $BD6D: 1 if any pawn exists.
    pawns_exist: u8 = 0,
    /// $BD39, $BD3A: best and second-best capture gains against White.
    see_best: u8 = 0,
    see_second: u8 = 0,
    /// $BD79-$BD85: pin list ((record, direction) pairs, 0-terminated).
    pins: [13]u8 = @splat(0),

    // ---------------------------------------------------------- move lists
    /// Move-list storage from list address $B400; see `listAddr`.
    lists: [list_bytes_extended]u8 = @splat(0),
    /// Abort threshold: `list_end_original` in original mode.
    list_limit: u32 = list_end_original,

    // ------------------------------------------------------- game record
    /// $C000 tape marker; $C001 plies played; $C003 replay target.
    tape_marker: u8 = 0,
    plies: u16 = 0,
    replay_target: u16 = 0,
    /// $C005: $BD2D of the start position; $C006: start move number
    /// (1 = standard start, book allowed; 10 = set-up).
    start_side: u8 = 0,
    start_move: u8 = 0,
    /// $C007-$C046: start position, 32 x (square, type byte) in slot order.
    start_pos: [64]u8 = @splat(0),
    /// $C047: promotions so far; $C048-$C057: their pieces.
    promo_count: u8 = 0,
    promos: [16]u8 = @splat(0),
    /// $C058...: one byte per ply (bits 0-6 index in the root list, bit 7 check),
    /// terminated by $FF.
    record: [record_capacity]u8 = @splat(0xFF),

    /// $BF00...: next-best root exclusion list, (from, to) pairs; `exclusion_len` bytes.
    exclusion: [exclusion_capacity]u8 = @splat(0),
    exclusion_len: u32 = 0,

    // ------------------------------------------------------------ access
    /// The byte an off-board square read sees (docs/OPEN_QUESTIONS.md, resolved):
    /// the generator and evaluation read $BD00 + sq for a/h-file pieces without
    /// an edge check. Only two such bytes hold variables.
    pub fn offboard(s: *const State, addr: u16) u8 {
        return switch (addr) {
            0xBD58 => s.root_rec[0],
            0xBD7F => s.pins[0xBD7F - 0xBD79],
            else => 0,
        };
    }

    /// Board read as the original does it: on-board squares from `board`,
    /// off-board ones through `offboard`.
    pub fn square(s: *const State, sq: u8) u8 {
        if (sq & 0x88 == 0) return s.board[sq];
        return s.offboard(0xBD00 + @as(u16, sq));
    }

    /// The 4 bytes of a move entry: the root record or a list entry.
    pub fn entry(s: *State, addr: u32) *[4]u8 {
        if (addr == root_record) return &s.root_rec;
        const off = listOffset(addr);
        return s.lists[off..][0..4];
    }

    /// Read an original variable by address (golden files, tests).
    pub fn get(s: *const State, addr: u16) ?u8 {
        return switch (addr) {
            0xBD00...0xBD7F => if (addr & 0x08 == 0) s.board[addr - 0xBD00] else s.offboardVar(addr),
            0xBE00...0xBEFF => s.rec[addr - 0xBE00],
            0xBC83...0xBC90 => s.curmove[(addr - 0xBC83) / 2 + 1][(addr - 0xBC83) % 2],
            0xBC91...0xBC9E => s.killer[(addr - 0xBC91) / 2 + 1][(addr - 0xBC91) % 2],
            0xBC9F...0xBCA7 => s.value[addr - 0xBC9F],
            0xBCA9 => s.ply,
            0xBCAA => s.depth,
            0xBCAB...0xBCBC => blk: {
                const q = (addr - 0xBCA9) / 2;
                const w = s.slot[q];
                break :blk if ((addr - 0xBCA9) % 2 == 0) @truncate(w) else @truncate(w >> 8);
            },
            0xBCBD => s.level_param,
            0xBCBE => s.cyrus_side,
            0xBCBF => s.game_over,
            0xBCC2 => s.players,
            0xBCCD => s.level_index,
            0xBCCE => s.random,
            0xBCDD => s.next_best,
            0xBCDE => s.promo_display,
            0xBCDF => s.book_state,
            0xBDF6 => s.threat_ext,
            else => null,
        };
    }

    fn offboardVar(s: *const State, addr: u16) ?u8 {
        return switch (addr) {
            0xBD09 => s.prune_margin,
            0xBD0A => s.fifty,
            0xBD0B => s.mate_ply,
            0xBD0C => s.best_mate_ply,
            0xBD0D => s.material_delta,
            0xBD0E => s.score_count,
            0xBD19 => s.best_static,
            0xBD1A => @truncate(s.best_static_entry),
            0xBD1B => @truncate(s.best_static_entry >> 8),
            0xBD1E => s.pressing,
            0xBD29 => @truncate(s.move_to_play),
            0xBD2A => @truncate(s.move_to_play >> 8),
            0xBD2B => @truncate(s.root_move),
            0xBD2C => @truncate(s.root_move >> 8),
            0xBD2D => s.side_phase,
            0xBD2E => s.material_term,
            0xBD39 => s.see_best,
            0xBD3A => s.see_second,
            0xBD49 => s.move_number,
            0xBD4A => s.drift,
            0xBD4B => s.sel_flags,
            0xBD4C => s.search_flags,
            0xBD4D => s.setup_changed,
            0xBD4E => s.sel_marker,
            0xBD58...0xBD5B => s.root_rec[addr - 0xBD58],
            0xBD5C => s.prev_from,
            0xBD5D => s.prev_to,
            0xBD5E => s.reversals,
            0xBD6D => s.pawns_exist,
            0xBD6E => s.second_pass,
            0xBD79...0xBD7F => s.pins[addr - 0xBD79],
            else => null,
        };
    }

    /// Write an original variable by address. Returns false for addresses
    /// that have no field (bytes the engine never reads).
    pub fn set(s: *State, addr: u16, v: u8) bool {
        switch (addr) {
            0xBD00...0xBD7F => {
                if (addr & 0x08 == 0) {
                    s.board[addr - 0xBD00] = v;
                    return true;
                }
                return s.setOffboardVar(addr, v);
            },
            0xBE00...0xBEFF => s.rec[addr - 0xBE00] = v,
            0xBC83...0xBC90 => s.curmove[(addr - 0xBC83) / 2 + 1][(addr - 0xBC83) % 2] = v,
            0xBC91...0xBC9E => s.killer[(addr - 0xBC91) / 2 + 1][(addr - 0xBC91) % 2] = v,
            0xBC9F...0xBCA7 => s.value[addr - 0xBC9F] = v,
            0xBCA9 => s.ply = v,
            0xBCAA => s.depth = v,
            0xBCAB...0xBCBC => {
                const q = (addr - 0xBCA9) / 2;
                if ((addr - 0xBCA9) % 2 == 0) {
                    s.slot[q] = (s.slot[q] & 0xFF00) | v;
                } else {
                    s.slot[q] = (s.slot[q] & 0x00FF) | (@as(u32, v) << 8);
                }
            },
            0xBCBD => s.level_param = v,
            0xBCBE => s.cyrus_side = v,
            0xBCBF => s.game_over = v,
            0xBCC2 => s.players = v,
            0xBCCD => s.level_index = v,
            0xBCCE => s.random = v,
            0xBCDD => s.next_best = v,
            0xBCDE => s.promo_display = v,
            0xBCDF => s.book_state = v,
            0xBDF6 => s.threat_ext = v,
            else => return false,
        }
        return true;
    }

    fn setOffboardVar(s: *State, addr: u16, v: u8) bool {
        switch (addr) {
            0xBD09 => s.prune_margin = v,
            0xBD0A => s.fifty = v,
            0xBD0B => s.mate_ply = v,
            0xBD0C => s.best_mate_ply = v,
            0xBD0D => s.material_delta = v,
            0xBD0E => s.score_count = v,
            0xBD19 => s.best_static = v,
            0xBD1A => s.best_static_entry = (s.best_static_entry & 0xFF00) | v,
            0xBD1B => s.best_static_entry = (s.best_static_entry & 0x00FF) | (@as(u32, v) << 8),
            0xBD1E => s.pressing = v,
            0xBD29 => s.move_to_play = (s.move_to_play & 0xFF00) | v,
            0xBD2A => s.move_to_play = (s.move_to_play & 0x00FF) | (@as(u32, v) << 8),
            0xBD2B => s.root_move = (s.root_move & 0xFF00) | v,
            0xBD2C => s.root_move = (s.root_move & 0x00FF) | (@as(u32, v) << 8),
            0xBD2D => s.side_phase = v,
            0xBD2E => s.material_term = v,
            0xBD39 => s.see_best = v,
            0xBD3A => s.see_second = v,
            0xBD49 => s.move_number = v,
            0xBD4A => s.drift = v,
            0xBD4B => s.sel_flags = v,
            0xBD4C => s.search_flags = v,
            0xBD4D => s.setup_changed = v,
            0xBD4E => s.sel_marker = v,
            0xBD58...0xBD5B => s.root_rec[addr - 0xBD58] = v,
            0xBD5C => s.prev_from = v,
            0xBD5D => s.prev_to = v,
            0xBD5E => s.reversals = v,
            0xBD6D => s.pawns_exist = v,
            0xBD6E => s.second_pass = v,
            0xBD79...0xBD7F => s.pins[addr - 0xBD79] = v,
            else => return false,
        }
        return true;
    }
};

test "list addresses" {
    try std.testing.expectEqual(@as(u32, 0xB400), listAddr(0));
    try std.testing.expectEqual(@as(u32, 0xBC7C), listAddr(list_bytes_original - 4));
    try std.testing.expectEqual(@as(u32, 0xBC84), listAddr(list_bytes_original + 4));
    try std.testing.expectEqual(@as(u32, 0xBD54), listAddr(root_record - list_base - 4));
    try std.testing.expectEqual(@as(u32, 0x10000 + 0x958), listAddr(root_record - list_base));
    try std.testing.expectEqual(@as(u32, 100), listOffset(listAddr(100)));
    try std.testing.expectEqual(@as(u32, 5000), listOffset(listAddr(5000)));
}

test "address map round trip" {
    var s: State = .{};
    const addrs = [_]u16{ 0xBCA0, 0xBC91, 0xBC9E, 0xBC83, 0xBCAB, 0xBCAC, 0xBCB6, 0xBD2D, 0xBD1A, 0xBD1B, 0xBD58, 0xBD7F, 0xBE00, 0xBEFF, 0xBD00, 0xBD77 };
    for (addrs, 0..) |a, i| {
        try std.testing.expect(s.set(a, @intCast(i + 1)));
        try std.testing.expectEqual(@as(?u8, @intCast(i + 1)), s.get(a));
    }
    try std.testing.expectEqual(@as(u8, 12), s.square(0x7F)); // $BD7F aliases pins[6]
    try std.testing.expectEqual(@as(u8, 11), s.square(0x58)); // $BD58 aliases root_rec[0]
    try std.testing.expectEqual(@as(u8, 0), s.square(0xFF)); // $BDFF holds nothing
}
