//! Game layer: the parts of the main loop that build and change the game
//! state, without the user interface. Spec: docs/arch/10-main-ui.md;
//! annotated disassembly disasm/ctl/10-main-ui.ctl. Phase 3 units 3.2, 3.6,
//! 3.12.
//!
//! The original is driven by keys; this module offers the same operations as
//! functions, with exactly the state changes the original makes:
//!   - the main loop ($60B7) up to the point where it waits for the human or
//!     hands over to the computer (`mainLoop`);
//!   - new game (G, Y: $607F, InitBoard $6505, GameStartCommon $60A7);
//!   - set-up mode (C: $6D4D; keys K Q R B N P U A T; exit E: $6ECC);
//!   - the human-move path (HumanMove $61C8 validation, PlayMove $6323);
//!   - E (HUMAN v HUMAN, $6858), M (KeyMove $695D), L (KeyLevel $6932);
//!   - FEN loading by the canonical construction (AGENTS.md §9.4) and the
//!     canonical operator script `Session` (AGENTS.md §9.6), which mirror
//!     tools/oracle/oracle.py (`Oracle.setup_fen`, `Session`).
//!
//! The computer's move itself (ComputerMove $6147 onwards: root scoring,
//! search, book) is the search's job; `Session.go` calls it through `Think`.
//!
//! Not modelled (user interface only, or overwritten before use): the screen,
//! sound, printer and tape; the cursor ($BCCA); the main loop's stirring of
//! $BCCE with the R register ($60EB) and WaitKey's increments of $BCCE (the
//! port sets $BCCE when the computer starts thinking, DEV-006).

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const board = @import("board.zig");
const movegen = @import("movegen.zig");
const eval = @import("eval.zig");
const presearch = @import("presearch.zig");
const scoring = @import("scoring.zig");
const observer = @import("observer.zig");

test {
    _ = @import("game_tests.zig");
}

// ------------------------------------------------------------------ squares

/// Internal 0x88 square of an algebraic square ("e4"): (8 - rank) * 16 + file.
pub fn squareFromName(name: []const u8) !u8 {
    if (name.len < 2) return error.BadSquare;
    const f = name[0];
    const r = name[1];
    if (f < 'a' or f > 'h' or r < '1' or r > '8') return error.BadSquare;
    return (('8' - r) << 4) | (f - 'a');
}

/// A move in coordinate notation: from, to, promotion piece key (0 = none).
pub const Move = struct {
    from: u8,
    to: u8,
    /// 'q', 'r', 'b', 'n' or 0.
    promo: u8 = 0,

    pub fn parse(uci: []const u8) !Move {
        if (uci.len != 4 and uci.len != 5) return error.BadMove;
        var m: Move = .{ .from = try squareFromName(uci[0..2]), .to = try squareFromName(uci[2..4]) };
        if (uci.len == 5) {
            m.promo = switch (uci[4]) {
                'q', 'r', 'b', 'n' => uci[4],
                else => return error.BadMove,
            };
        }
        return m;
    }
};

// --------------------------------------------------------------- main loop

/// What the main loop does next.
pub const Turn = enum {
    /// Waiting for the human's move (HumanMove input, $62B7); the root list
    /// for the side to move has been generated and scored.
    human,
    /// The computer is to move: ComputerMove ($6147) with players != 0.
    computer,
    /// Draw by repetition or the 50-move rule ($6448).
    draw,
    /// No legal move for the human (checkmate or stalemate, $641A).
    no_moves,
};

fn whiteToMove(s: *const State) bool {
    return s.side_phase & 1 != 0;
}

/// MainLoop ($60B7, from $60E3) until the program either waits for the
/// human or hands over to the computer. HUMAN v HUMAN turns of Cyrus's side
/// swap sides ($614B -> $696A) and CYRUS v CYRUS human turns too ($61E6).
pub fn mainLoop(s: *State) Turn {
    while (true) {
        // $60F6: draw tests.
        if (s.reversals == 6 or s.fifty >= 100) return .draw;
        s.game_over = 0; // $6106
        // $611F: next-best in progress: Cyrus plays the side to move now.
        if (s.next_best != 0) {
            s.cyrus_side = (s.side_phase & 1) ^ 1;
            setPlayers(s);
            return .computer;
        }
        // $6134: is it Cyrus's turn?
        const computer = if (whiteToMove(s)) s.cyrus_side == 0 else s.cyrus_side != 0;
        if (computer) {
            if (s.players == 0) {
                swapSides(s); // $614B: HUMAN v HUMAN
                continue;
            }
            return .computer;
        }
        // HumanMove ($61C8): generate and score the root moves.
        s.search_flags = 0;
        const r = movegen.generate(s, st.root_record);
        scoring.scoreMoves(s, r.header, r.count, &observer.none);
        if (s.best_static == 0) return .no_moves; // $61DA
        if (s.players == 3) { // $61E6: CYRUS v CYRUS
            swapSides(s);
            continue;
        }
        if (s.players != 0) setPlayers(s); // $61EC
        return .human;
    }
}

/// SetPlayers ($7562): $BCC2 = 1 (HUMAN v CYRUS) if Cyrus plays Black, else
/// 2 (CYRUS v HUMAN).
pub fn setPlayers(s: *State) void {
    s.players = if (s.cyrus_side == 0) 2 else 1;
}

/// SwapSides ($696A): Cyrus takes the other side; the last root value $BCA0
/// is negated (it is kept from the side Cyrus plays).
pub fn swapSides(s: *State) void {
    s.cyrus_side = if (s.cyrus_side == 0) 1 else 0;
    s.value[1] = 0 -% s.value[1];
}

/// M at a human prompt: KeyMove ($695D) - Cyrus takes over the side to move.
/// Returns the main loop's next turn (normally `.computer`).
pub fn keyMove(s: *State) Turn {
    s.players = if (s.cyrus_side == 0) 1 else 2;
    swapSides(s);
    return mainLoop(s);
}

/// E at a human prompt: KeyEnter ($6858) - HUMAN v HUMAN. Input continues with
/// the same root list (no new main-loop pass).
pub fn humanVHuman(s: *State) void {
    s.players = 0;
}

/// L pressed until the level index is `index` (0-10 = Level 1-8, P1-P3):
/// KeyLevel ($6932) sets the index and the search level parameter.
pub fn setLevel(s: *State, index: u8) void {
    s.level_index = index;
    s.level_param = switch (index) {
        8 => 0,
        9 => 3,
        10 => 7,
        else => index,
    };
}

// ------------------------------------------------------------- new game

/// ColdStart ($605B), the options set once at program load (the engine's
/// initial state): Level 2, next-best off, no standard start yet. Then a new
/// game. `s` must be a freshly initialised State (all program variables 0).
pub fn coldStart(s: *State) Turn {
    s.level_param = 1;
    s.level_index = 1;
    s.next_best = 0;
    s.start_move = 0;
    return newGame(s);
}

/// G, Y: NewGameConfirmed ($607F) -> InitBoard ($6505) -> GameStartCommon
/// ($60A7) -> main loop. $BCA0, $BCCE, the level, the search tables and the
/// game record beyond its first byte are not reset.
pub fn newGame(s: *State) Turn {
    if (s.start_move != 1) s.record[0] = 0xFF; // $607F: not a standard game
    s.players = 1; // $608A: HUMAN v CYRUS
    s.replay_target = 0; // $608F
    initBoard(s);
    gameStartCommon(s);
    return mainLoop(s);
}

/// GameStartCommon ($60A7): empty record, no promotions, book enabled.
fn gameStartCommon(s: *State) void {
    s.plies = 0;
    s.promo_count = 0;
    s.book_state = 0;
}

/// InitBoard ($6505): clear $BD00-$BEFF (board, every variable in the board
/// page and both piece lists), write the initial position as set-up codes
/// (untouched kings and rooks: bit 1 clear) and assign them to slots.
fn initBoard(s: *State) void {
    // $6505: everything that lives in $BD00-$BEFF.
    s.board = @splat(0);
    s.rec = @splat(0);
    s.prune_margin = 0;
    s.fifty = 0;
    s.mate_ply = 0;
    s.best_mate_ply = 0;
    s.material_delta = 0;
    s.score_count = 0;
    s.best_static = 0;
    s.best_static_entry = 0;
    s.pressing = 0;
    s.move_to_play = 0;
    s.root_move = 0;
    s.material_term = 0;
    s.see_best = 0;
    s.see_second = 0;
    s.drift = 0;
    s.sel_flags = 0;
    s.search_flags = 0;
    s.setup_changed = 0;
    s.sel_marker = 0;
    s.root_rec = @splat(0);
    s.prev_from = 0;
    s.prev_to = 0;
    s.reversals = 0;
    s.pawns_exist = 0;
    s.second_pass = 0;
    s.pins = @splat(0);
    s.threat_ext = 0;

    // $6512: set-up codes. Black: colour 0; White: | $80.
    const back = [8]u8{ 0x11, 0x31, 0x21, 0x09, 0x01, 0x21, 0x31, 0x11 }; // $6558
    for (0..8) |f| {
        s.board[0x00 + f] = back[f]; // rank 8
        s.board[0x10 + f] = 0x41; // rank 7: black pawns
        s.board[0x60 + f] = 0xC1; // rank 2: white pawns
        s.board[0x70 + f] = back[f] | 0x81; // rank 1
    }
    // $652A
    s.cyrus_side = 1;
    s.side_phase = 1;
    s.move_number = 1;
    s.ply = 1;
    s.start_move = 1;
    s.slot[1] = st.list_base;
    markAllAbsent(s); // $6541
    assignScan(s) catch unreachable; // the initial position always fits
}

/// MarkAllAbsent ($659C): set bit 7 of the square byte of all 32 records.
fn markAllAbsent(s: *State) void {
    var r: usize = 0;
    while (r < 256) : (r += 8) s.rec[r] |= 0x80;
}

// --------------------------------------------------------------- set-up

/// Why a set-up position was rejected (ILLEGAL, $6587/$6588).
pub const SetupError = error{
    /// A pawn on rank 1 or 8 ($6616).
    PawnOnBackRank,
    /// No free slot for a piece: too many of a type, or a second king ($6674).
    NoFreeSlot,
    /// A king is missing ($6607).
    KingMissing,
    /// The side not to move is in check: pre-search returned 0 ($6F09).
    SideNotToMoveInCheck,
};

/// Board writes in set-up mode go to $BD00 + square. The scans also visit the
/// off-board column 8 (see `assignScan`); the only variable there that can be
/// written this way is the root record's first byte.
fn putSquare(s: *State, sq: u8, v: u8) void {
    if (sq & 0x88 == 0) {
        s.board[sq] = v;
    } else if (sq == 0x58) {
        s.root_rec[0] = v;
    }
}

/// The set-up mode keys that put a piece on the cursor square, with the slot
/// offset of the piece table ($6F2E: value, key, slot).
pub const SetupPiece = enum(u8) {
    king = 0x00,
    queen = 0x08,
    rook = 0x10,
    bishop = 0x20,
    knight = 0x30,
    pawn = 0x40,

    pub fn fromLetter(c: u8) ?SetupPiece {
        return switch (std.ascii.toLower(c)) {
            'k' => .king,
            'q' => .queen,
            'r' => .rook,
            'b' => .bishop,
            'n' => .knight,
            'p' => .pawn,
            else => null,
        };
    }
};

/// C: ChangePosition ($6D4D). Nothing changed yet ($BD4D = 0); the colour
/// for new pieces ($BCA2, which is V(3) = value[3]) is the side to move:
/// $83 White, $03 Black.
pub fn setupEnter(s: *State) void {
    s.setup_changed = 0;
    s.value[3] = if (whiteToMove(s)) 0x83 else 0x03;
}

/// K, Q, R, B, N, P in set-up mode ($6E98): the set-up code (slot offset +
/// colour) goes on the square; $BCA3 (V(4)) keeps the slot offset.
pub fn setupPlace(s: *State, sq: u8, piece: SetupPiece) void {
    s.value[4] = @backingInt(piece); // $6EA3
    setupStore(s, sq, s.value[3] +% @backingInt(piece));
}

/// U in set-up mode ($6E8B): empty the square.
pub fn setupRemove(s: *State, sq: u8) void {
    setupStore(s, sq, 0);
}

/// $6EB4: store a code; a real piece that was there (bit 0 clear, bit 2 set)
/// has its record marked absent. The position counts as changed.
fn setupStore(s: *State, sq: u8, code: u8) void {
    const old = s.square(sq);
    putSquare(s, sq, code);
    if (old & 0x01 == 0 and old & 0x04 != 0) s.rec[old & 0xFB] |= 0x80;
    s.setup_changed = 2;
}

/// A in set-up mode ($6E82): ClearBoard ($658E) and MarkAllAbsent.
pub fn setupAllClear(s: *State) void {
    var sq: u8 = 0;
    while (sq < 0x80) : (sq += 1) {
        if (sq & 0x08 == 0) s.board[sq] = 0;
    }
    markAllAbsent(s);
    s.setup_changed = 2;
}

/// T in set-up mode ($6E73): toggle the colour of new pieces (and the side to
/// move on exit). Does not by itself count as a change.
pub fn setupToggle(s: *State) void {
    s.value[3] ^= 0x80;
}

/// E in set-up mode: SetupExit ($6ECC). Installs the position and returns the
/// main loop's next turn, or rejects it (the original shows ILLEGAL; the
/// state is then left half-installed, as in the original, and must not be
/// used).
pub fn setupExit(s: *State) SetupError!Turn {
    // $6ECC: the side to move is the colour shown; Cyrus plays the other one.
    const colour = s.value[3];
    var b = s.side_phase & 0xFE;
    const a = colour -% 3;
    s.cyrus_side = a; // $80 when White is to move, 0 when Black is
    if (a == 0) {
        s.players = 2; // CYRUS v HUMAN
    } else {
        b |= 1;
        s.players = 1; // HUMAN v CYRUS
    }
    if (b != s.side_phase) {
        s.side_phase = b;
        s.setup_changed = 2;
    }
    if (s.setup_changed == 0) return mainLoop(s); // $6EF3: nothing changed
    try assignSetupPieces(s); // $6EF6
    resetGameCounters(s); // $6EF9
    s.move_number = 10; // $6EFC
    s.value[1] = 0x80; // $6F01: $BCA0
    if (presearch.preSearch(s).a == 0) return error.SideNotToMoveInCheck; // $6F06
    saveStartPosition(s); // $6F0C
    s.record[0] = 0xFF; // $6F0F
    gameStartCommon(s); // $6F20 -> $60A7
    return mainLoop(s);
}

/// ResetGameCounters ($6F99): 50-move counter, $BD0D and $BD59-$BD5E.
fn resetGameCounters(s: *State) void {
    s.fifty = 0;
    s.material_delta = 0;
    s.root_rec[1] = 0;
    s.root_rec[2] = 0;
    s.root_rec[3] = 0;
    s.prev_from = 0;
    s.prev_to = 0;
    s.reversals = 0;
}

/// SaveStartPosition ($6F77): $C005 = $BD2D, $C006 = move number, $C007-$C046
/// = (square, type byte) of the 32 records.
fn saveStartPosition(s: *State) void {
    s.start_side = s.side_phase;
    s.start_move = s.move_number;
    for (0..32) |k| {
        s.start_pos[2 * k] = s.rec[8 * k];
        s.start_pos[2 * k + 1] = s.rec[8 * k + 1];
    }
}

/// AssignSetupPieces ($65DA): lift promoted pieces out of both sides' pawn
/// slots, then AssignScan.
fn assignSetupPieces(s: *State) SetupError!void {
    liftPromotedPieces(s, 0x40);
    liftPromotedPieces(s, 0xC0);
    try assignScan(s);
}

/// LiftPromotedPieces ($65A8): every present record in the pawn slots from
/// `first` whose value is not 1 is freed, and its piece becomes an entered
/// set-up code again (type from the piece table $6F2E).
fn liftPromotedPieces(s: *State, first: u8) void {
    var l = first;
    while (true) {
        const sq = s.rec[l];
        if (sq & 0x80 == 0) {
            const t = s.rec[l + 1];
            if ((t & 0x0F) -% 1 != 0) {
                s.rec[l] |= 0x80;
                const e = (l & 0x80) | 0x03;
                putSquare(s, sq, slotForValue(t & 0x8F) | e);
            }
        }
        l +%= 8;
        if (l & 0x40 == 0) return;
    }
}

/// FindPieceRow by value ($6F23 from $6F2E): the slot offset of a type byte.
fn slotForValue(v: u8) u8 {
    return switch (v) {
        0x00 => 0x00,
        0x09 => 0x08,
        0x05 => 0x10,
        0x83 => 0x20,
        0x03 => 0x30,
        0x01 => 0x40,
        // Not reached: a promoted piece's value AND $8F is always one of the
        // above. The original would read past the table into the copyright
        // text ($6F42 = '(' ... ), so keep its byte for completeness.
        else => tablesByteAfterPieceTable(),
    };
}

fn tablesByteAfterPieceTable() u8 {
    return @import("tables.zig").binary[0x6F42 - 0x6000];
}

/// AssignScan ($65E5): give each square holding a set-up code (bit 0 set) a
/// slot, scanning file by file (a-file first), each file from row 0 (rank 8)
/// to row 7. The scan's end test lets it also visit column 8 ($BD08, $BD18,
/// ..., $BD78). Then both kings must be present; their type bytes get the
/// edge-distance bits ($660A -> $8203).
fn assignScan(s: *State) SetupError!void {
    var file: u8 = 0;
    while (file <= 8) : (file += 1) {
        var row: u8 = 0;
        while (row < 8) : (row += 1) {
            const sq = (row << 4) | file;
            const code = s.square(sq);
            if (code & 0x01 != 0) try assignSlot(s, code, sq);
        }
    }
    // $65FE: black king's edge bits first, then both kings must be present.
    const black_king = s.rec[0x00];
    s.rec[0x01] = board.kingTypeAt(s.rec[0x01], black_king);
    if ((black_king | s.rec[0x80]) & 0x80 != 0) return error.KingMissing;
    s.rec[0x81] = board.kingTypeAt(s.rec[0x81], s.rec[0x80]);
}

/// AssignSlot ($6610): find a free slot for the set-up code at `sq`.
/// L = code - 1 (bit 1 set = entered by the user, bit 7 = White).
fn assignSlot(s: *State, code: u8, sq: u8) SetupError!void {
    var l = code -% 1;
    var b: u8 = undefined; // type byte
    var c: u8 = undefined; // line mask (+6)
    if (l & 0x40 != 0) {
        // $6616: pawn.
        if (sq & 0x70 == 0 or sq & 0x70 == 0x70) return error.PawnOnBackRank;
        b = 0x01;
        c = if (l & 0x80 != 0) 0x80 else 0xC0;
        return pawnSlots(s, &l, sq, b, c);
    }
    const kind = l & 0x78;
    if (kind == 0) {
        // $662B: king: the king slot only.
        c = 0x01;
        b = if (l & 0x02 != 0) 0x30 else 0x00;
        if (trySlot(s, &l, sq, b, c)) return;
        return error.NoFreeSlot;
    }
    if (kind < 0x10) {
        // $663F: queen: its own slot, then the pawn slots.
        c = 0x0E;
        b = 0x09;
        if (trySlot(s, &l, sq, b, c)) return;
    } else {
        if (kind == 0x10) {
            // $6649: rook
            c = 0x08;
            b = if (l & 0x02 != 0) 0x15 else 0x05;
        } else if (kind == 0x20) {
            // bishop
            b = 0x83;
            c = 0x04;
        } else {
            // knight
            b = 0x03;
            c = 0x00;
        }
        // $6661: the two slots of the type, then the pawn slots.
        if (trySlot(s, &l, sq, b, c)) return;
        if (trySlot(s, &l, sq, b, c)) return;
    }
    l = (l & 0x82) | 0x40; // $6667
    return pawnSlots(s, &l, sq, b, c);
}

/// $666D: try pawn slots from `l` while bit 6 of `l` stays set.
fn pawnSlots(s: *State, l: *u8, sq: u8, b: u8, c: u8) SetupError!void {
    while (true) {
        if (trySlot(s, l, sq, b, c)) return;
        if (l.* & 0x40 == 0) return error.NoFreeSlot;
    }
}

/// TryPieceSlot ($6678): if the slot at `l` (bit 1 cleared) is free, store
/// the square, the board code (slot | 4), the type byte and the line mask;
/// otherwise move `l` to the next slot. Bytes +2..+5 and +7 keep their values.
fn trySlot(s: *State, l: *u8, sq: u8, b: u8, c: u8) bool {
    l.* &= ~@as(u8, 0x02);
    const r = l.*;
    if (s.rec[r] & 0x80 == 0) {
        l.* +%= 8;
        return false;
    }
    s.rec[r] = sq;
    putSquare(s, sq, r | 0x04);
    s.rec[r +% 1] = b;
    s.rec[r +% 6] = c;
    return true;
}

// -------------------------------------------------------- game moves

pub const MoveError = error{
    /// The move is not in the generated list, or its static score is 0
    /// ($6318: ILLEGAL).
    IllegalMove,
};

/// The human's move at the YOUR MOVE? prompt: HumanMoveInput ($62B7-$6321)
/// looks the move up in the root list (it must be there with a non-zero
/// score), starts a new exclusion list and plays it (PlayMove), then the main
/// loop continues. The root list must be the one `mainLoop` generated.
pub fn humanMove(s: *State, m: Move) MoveError!Turn {
    const count = s.lists[1]; // $6309: B = ($B401)
    const e = scoring.findMove(s, st.list_base + 2, count, m.from, m.to, null) orelse return error.IllegalMove;
    if (s.entry(e)[0] == 0) return error.IllegalMove;
    s.exclusion_len = 0; // $631D: ClearExclusionList
    playMove(s, e, m.promo);
    return mainLoop(s);
}

/// The computer's move: PlayMove ($6323) for the entry the search left in
/// $BD29, then the main loop.
pub fn computerPlays(s: *State, entry: u32) Turn {
    playMove(s, entry, 'q');
    return mainLoop(s);
}

/// PlayMove ($6323-$63AE) without the display: make the move, choose the
/// promotion piece (the human's `promo`; the computer always takes a queen),
/// re-evaluate to set the check flag, append the move to the game record,
/// update the 50-move counter, the repetition detector, the side to move,
/// the move number and the exclusion list.
pub fn playMove(s: *State, entry: u32, promo: u8) void {
    var undo: board.Undo = undefined;
    board.make(s, entry, &undo); // $6326
    s.promo_display = 0; // $6329
    if (undo.marker & 0x04 != 0) choosePromotion(s, entry, promo); // $632F: P/V set
    const e = s.entry(entry);
    e[3] &= 0x7F; // $6332
    _ = eval.evaluate(s, entry); // $6336: sets bit 7 if the move gives check

    // $6346: record byte = check flag | index of the move in the root list
    // (E counts in 8 bits). $6359: $C001 + 1; the byte goes to $C057 + $C001,
    // the $FF terminator after it.
    const index: u8 = @truncate((entry -% st.list_base) / 4 -% 1);
    s.plies +%= 1;
    if (s.plies - 1 < s.record.len) s.record[s.plies - 1] = (e[3] & 0x80) | index;
    if (s.plies < s.record.len) s.record[s.plies] = 0xFF;
    afterGameMove(s, entry, undo);
}

/// ChoosePromotion ($63B1): the computer's move ($BD4C bit 6) keeps the
/// queen. A human R, N or B overwrites the promoted piece's type byte with 5,
/// 3 or $83; anything else keeps the queen. The value (9 for a queen) is
/// appended to the promotion list ($C047/$C048, which after 16 entries runs
/// into the game record) and kept for the display ($BCDE).
fn choosePromotion(s: *State, entry: u32, promo: u8) void {
    var b: u8 = 0x09;
    if (s.search_flags & 0x40 == 0) {
        b = switch (promo) {
            'r' => 0x05,
            'n' => 0x03,
            'b' => 0x83,
            else => 0x09,
        };
        if (b != 0x09) {
            const code = s.square(s.entry(entry)[2]); // $6402
            s.rec[(code & 0xFB) +% 1] = b;
        }
    }
    // $640D: count + 1; the entry is $C047 + count within page $C0.
    s.promo_count +%= 1;
    const addr_low: u8 = 0x47 +% s.promo_count;
    setGamePageByte(s, addr_low, b);
    s.promo_display = b;
}

/// Write a byte of page $C0 ($C000-$C0FF) by its low address byte, as the
/// promotion list does when it overflows.
fn setGamePageByte(s: *State, low: u8, v: u8) void {
    switch (low) {
        0x00 => s.tape_marker = v,
        0x01 => s.plies = (s.plies & 0xFF00) | v,
        0x02 => s.plies = (s.plies & 0x00FF) | (@as(u16, v) << 8),
        0x03 => s.replay_target = (s.replay_target & 0xFF00) | v,
        0x04 => s.replay_target = (s.replay_target & 0x00FF) | (@as(u16, v) << 8),
        0x05 => s.start_side = v,
        0x06 => s.start_move = v,
        0x07...0x46 => s.start_pos[low - 0x07] = v,
        0x47 => s.promo_count = v,
        0x48...0x57 => s.promos[low - 0x48] = v,
        else => s.record[low - 0x58] = v,
    }
}

/// AfterGameMove ($636E-$63AE).
fn afterGameMove(s: *State, entry: u32, undo: board.Undo) void {
    // $636E: 50-move counter; reset by a capture, en passant, castling (S
    // clear) or a pawn move (old value 1).
    s.fifty +%= 1;
    if (undo.marker & 0x80 == 0 or (undo.old_type & 0x0F) -% 1 == 0) s.fifty = 0;
    trackRepetition(s, entry); // $6380
    // $6383: change the side to move; move number + 1 when White is to move.
    s.side_phase ^= 1;
    if (whiteToMove(s)) s.move_number +%= 1;
    // $6392: unless next-best, append (from, to) to the exclusion list.
    if (s.next_best == 0) {
        const e = s.entry(entry);
        if (s.exclusion_len + 2 <= s.exclusion.len) {
            s.exclusion[s.exclusion_len] = e[1];
            s.exclusion[s.exclusion_len + 1] = e[2];
            s.exclusion_len += 2;
        }
    }
}

/// TrackRepetition ($6560): count the move if it exactly reverses the move
/// two plies back, else reset the count; shift the last move into
/// $BD5C/$BD5D and store this move's from, to and flags at $BD59-$BD5B.
fn trackRepetition(s: *State, entry: u32) void {
    const e = s.entry(entry);
    const from = e[1];
    const to = e[2];
    if (s.prev_from == to and s.prev_to == from) {
        s.reversals +%= 1;
    } else {
        s.reversals = 0;
    }
    s.prev_from = s.root_rec[1];
    s.prev_to = s.root_rec[2];
    s.root_rec[1] = from;
    s.root_rec[2] = to;
    s.root_rec[3] = e[3];
}

// ------------------------------------------------------------- FEN

/// Why a FEN position was rejected (AGENTS.md §9.4).
pub const FenError = error{
    /// Not a valid FEN.
    MalformedFen,
    /// A castling right whose king and rook are not on their squares.
    CastlingRightWithoutPieces,
    /// The en passant square does not follow a double pawn step.
    EnPassantInconsistent,
    /// The predecessor of an en passant position was rejected.
    EnPassantPredecessorRejected,
    /// The double pawn step of an en passant position was rejected.
    DoubleStepRejected,
} || SetupError;

/// A parsed FEN (oracle.parse_fen).
pub const Fen = struct {
    /// Piece letter per internal square (0 = empty).
    board: [128]u8 = @splat(0),
    white: bool = true,
    castling: [4]u8 = @splat(0),
    castling_len: u8 = 0,
    ep: ?u8 = null,

    pub fn parse(text: []const u8) FenError!Fen {
        var f: Fen = .{};
        var it = std.mem.tokenizeAny(u8, text, " \t");
        const placement = it.next() orelse return error.MalformedFen;
        const side = it.next() orelse return error.MalformedFen;
        const castling = it.next() orelse return error.MalformedFen;
        const ep = it.next() orelse return error.MalformedFen;
        var row: u8 = 0;
        var file: u8 = 0;
        for (placement) |ch| {
            if (ch == '/') {
                if (file != 8 or row == 7) return error.MalformedFen;
                row += 1;
                file = 0;
            } else if (ch >= '1' and ch <= '8') {
                file += ch - '0';
                if (file > 8) return error.MalformedFen;
            } else if (std.mem.indexOfScalar(u8, "KQRBNPkqrbnp", ch) != null) {
                if (file > 7) return error.MalformedFen;
                f.board[row * 16 + file] = ch;
                file += 1;
            } else return error.MalformedFen;
        }
        if (row != 7 or file != 8) return error.MalformedFen;
        if (std.mem.eql(u8, side, "w")) {
            f.white = true;
        } else if (std.mem.eql(u8, side, "b")) {
            f.white = false;
        } else return error.MalformedFen;
        if (!std.mem.eql(u8, castling, "-")) {
            if (castling.len > 4) return error.MalformedFen;
            for (castling) |ch| {
                if (std.mem.indexOfScalar(u8, "KQkq", ch) == null) return error.MalformedFen;
                f.castling[f.castling_len] = ch;
                f.castling_len += 1;
            }
        }
        if (!std.mem.eql(u8, ep, "-")) f.ep = squareFromName(ep) catch return error.MalformedFen;
        return f;
    }

    fn hasRight(f: *const Fen, ch: u8) bool {
        return std.mem.indexOfScalar(u8, f.castling[0..f.castling_len], ch) != null;
    }

    fn startBoard() [128]u8 {
        var b: [128]u8 = @splat(0);
        const back = "rnbqkbnr";
        for (0..8) |file| {
            b[file] = back[file];
            b[0x10 + file] = 'p';
            b[0x60 + file] = 'P';
            b[0x70 + file] = std.ascii.toUpper(back[file]);
        }
        return b;
    }

    /// oracle.fen_is_start: the standard position, White to move, castling
    /// field exactly "KQkq", no en passant square.
    fn isStart(f: *const Fen) bool {
        return std.mem.eql(u8, &f.board, &startBoard()) and f.white and
            std.mem.eql(u8, f.castling[0..f.castling_len], "KQkq") and f.ep == null;
    }

    /// oracle.ep_predecessor: the position before the double step.
    fn epPredecessor(f: *const Fen) ?struct { fen: Fen, from: u8, to: u8 } {
        const ep = f.ep.?;
        var pawn: u8 = undefined;
        var to: u8 = undefined;
        var from: u8 = undefined;
        if (f.white) { // Black just played a double step; ep square on rank 6
            pawn = 'p';
            to = ep +% 16;
            from = ep -% 16;
        } else {
            pawn = 'P';
            to = ep -% 16;
            from = ep +% 16;
        }
        if (to & 0x88 != 0 or from & 0x88 != 0) return null;
        if (f.board[to] != pawn or f.board[ep] != 0 or f.board[from] != 0) return null;
        var p = f.*;
        p.board[to] = 0;
        p.board[from] = pawn;
        p.white = !f.white;
        p.ep = null;
        return .{ .fen = p, .from = from, .to = to };
    }
};

/// Load a FEN by the canonical construction (AGENTS.md §9.4;
/// oracle.Oracle.setup_fen): a new game, then - unless the FEN is the
/// standard start - set-up mode keeping the untouched pieces it can, and for
/// an en passant square the predecessor position followed by the double step
/// in HUMAN v HUMAN mode. Returns the main loop's next turn.
pub fn loadFen(s: *State, text: []const u8) FenError!Turn {
    const f = try Fen.parse(text);
    var turn = newGame(s);
    if (f.isStart()) return turn;
    if (f.ep != null) {
        const pred = f.epPredecessor() orelse return error.EnPassantInconsistent;
        _ = setupBoard(s, &pred.fen) catch return error.EnPassantPredecessorRejected;
        humanVHuman(s);
        turn = humanMove(s, .{ .from = pred.from, .to = pred.to }) catch return error.DoubleStepRejected;
        return turn;
    }
    return setupBoard(s, &f);
}

/// oracle._setup_board: the set-up mode key sequence for a position, from a
/// new game.
fn setupBoard(s: *State, f: *const Fen) FenError!Turn {
    const start = Fen.startBoard();
    // Castling rights need the king and the rook on their squares.
    const Rule = struct { right: u8, king_sq: u8, king: u8, rook_sq: u8, rook: u8 };
    const rules = [_]Rule{
        .{ .right = 'K', .king_sq = 0x74, .king = 'K', .rook_sq = 0x77, .rook = 'R' },
        .{ .right = 'Q', .king_sq = 0x74, .king = 'K', .rook_sq = 0x70, .rook = 'R' },
        .{ .right = 'k', .king_sq = 0x04, .king = 'k', .rook_sq = 0x07, .rook = 'r' },
        .{ .right = 'q', .king_sq = 0x04, .king = 'k', .rook_sq = 0x00, .rook = 'r' },
    };
    for (rules) |r| {
        if (f.hasRight(r.right) and (f.board[r.king_sq] != r.king or f.board[r.rook_sq] != r.rook))
            return error.CastlingRightWithoutPieces;
    }
    // Pieces of the new game left untouched.
    var keep: [128]bool = @splat(false);
    for (0..128) |i| {
        const p = start[i];
        if (p == 0 or f.board[i] != p) continue;
        if (p == 'K' and !(f.hasRight('K') or f.hasRight('Q'))) continue;
        if (p == 'k' and !(f.hasRight('k') or f.hasRight('q'))) continue;
        if (p == 'R' or p == 'r') {
            const right: u8 = switch (i) {
                0x77 => 'K',
                0x70 => 'Q',
                0x07 => 'k',
                0x00 => 'q',
                else => unreachable,
            };
            if (!f.hasRight(right)) continue;
        }
        keep[i] = true;
    }
    setupEnter(s);
    // U on every new-game piece that is not kept and not wanted.
    for (0..128) |i| {
        if (start[i] != 0 and !keep[i] and f.board[i] == 0) setupRemove(s, @intCast(i));
    }
    // Enter the other pieces in the scan order (file a-h, rank 8 to rank 1).
    for (0..8) |file| {
        for (0..8) |row| {
            const sq: u8 = @intCast(row * 16 + file);
            const p = f.board[sq];
            if (p == 0 or keep[sq]) continue;
            setColour(s, std.ascii.isUpper(p));
            setupPlace(s, sq, SetupPiece.fromLetter(p).?);
        }
    }
    setColour(s, f.white);
    return setupExit(s);
}

fn setColour(s: *State, white: bool) void {
    if ((s.value[3] & 0x80 != 0) != white) setupToggle(s);
}

// --------------------------------------------------------- operator script

/// What happened when the computer was asked to move.
pub const Outcome = union(enum) {
    /// The move to play: an entry address, as $BD29 holds it.
    move: u32,
    /// No legal move (checkmate or stalemate, $641A).
    no_moves,
    /// Problem level without a mate (NO MATE FOUND, $61A6).
    no_mate,
};

/// The computer's thinking from ComputerMove ($6147) to the point where the
/// original plays the move ($61C1) or gives up. Provided by the search (or,
/// in tests, by a replay of recorded results).
pub const Think = struct {
    ctx: ?*anyopaque = null,
    run: *const fn (ctx: ?*anyopaque, s: *State) Outcome,
};

/// The result of `Session.go`.
pub const GoResult = union(enum) {
    move: u32,
    no_moves,
    no_mate,
    draw,
};

/// The canonical operator script (AGENTS.md §9.6), mirroring
/// tools/oracle/oracle.py `Session`: how UCI usage maps onto the original's
/// user interface.
pub const Session = struct {
    s: *State,
    /// The single opponent move entered in HUMAN v CYRUS mode, which starts
    /// the computer's thinking when `go` is called.
    pending: ?Move = null,
    /// The main loop's state after the last operation.
    turn: Turn = .human,

    /// From a new game, or set-up for a FEN; then, if there are moves, E
    /// (HUMAN v HUMAN) and the moves are entered.
    pub fn load(self: *Session, fen: ?[]const u8, moves: []const Move) !void {
        const s = self.s;
        self.turn = if (fen) |text| try loadFen(s, text) else newGame(s);
        if (moves.len != 0) {
            if (s.players != 0) humanVHuman(s);
            for (moves) |m| {
                if (self.turn != .human) return error.GameOver;
                self.turn = try humanMove(s, m);
            }
        }
        self.pending = null;
    }

    /// After the computer has moved: one opponent move is entered in HUMAN v
    /// CYRUS mode (the computer starts thinking on `go`); two or more switch
    /// to HUMAN v HUMAN first.
    pub fn continueWith(self: *Session, moves: []const Move) !void {
        if (moves.len == 1) {
            self.pending = moves[0];
            return;
        }
        humanVHuman(self.s);
        for (moves) |m| {
            if (self.turn != .human) return error.GameOver;
            self.turn = try humanMove(self.s, m);
        }
        self.pending = null;
    }

    /// Bring the program to the start of the computer's move (ComputerMove,
    /// $6147): the pending move is entered (no swap), or M is pressed
    /// (KeyMove: Cyrus takes the side to move). `level` is set with L first,
    /// unless a move is pending (as in the oracle). Returns null when the
    /// computer is to think, or the reason it is not.
    pub fn prepareGo(self: *Session, level: ?u8) !?GoResult {
        const s = self.s;
        if (self.pending) |m| {
            self.pending = null;
            self.turn = try humanMove(s, m);
        } else {
            if (level) |l| setLevel(s, l);
            self.turn = keyMove(s);
        }
        return switch (self.turn) {
            .computer => null,
            .draw => .draw,
            .no_moves => .no_moves,
            .human => error.NotComputersTurn,
        };
    }

    /// `prepareGo`, then the computer's thinking, then its move is played
    /// (PlayMove and the main loop), as the original does.
    pub fn go(self: *Session, level: ?u8, think: Think) !GoResult {
        if (try self.prepareGo(level)) |r| return r;
        return self.finishGo(think.run(think.ctx, self.s));
    }

    /// Play the outcome of the computer's thinking.
    pub fn finishGo(self: *Session, outcome: Outcome) GoResult {
        const s = self.s;
        switch (outcome) {
            .move => |e| {
                self.turn = computerPlays(s, e);
                return .{ .move = e };
            },
            .no_moves => return .no_moves,
            .no_mate => {
                setupEnter(s); // $61BE: set-up mode
                return .no_mate;
            },
        }
    }
};
