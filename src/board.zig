//! Make and unmake move: port of $810F, $821C and helpers ($8200, $826E).
//! Spec: docs/arch/20-board-movegen.md §4.3-4.5. Owner: Phase 3 unit 3.3.
//!
//! Interface (used by search, game layer):
//!   pub const Undo = struct { ... };   // what the original pushes on the stack
//!   pub fn make(s: *State, entry: u32, undo: *Undo) void;    // $810F
//!   pub fn unmake(s: *State, undo: *const Undo) void;        // $821C
//! `Undo` must also expose the "AF" word left by make for game moves
//! (docs/arch/10-main-ui.md §5: F = $80 quiet, $00 capture, $84/$04
//! promotion, $01 en passant, $40 castling; A = mover's type byte before).

const std = @import("std");
const State = @import("state.zig").State;
