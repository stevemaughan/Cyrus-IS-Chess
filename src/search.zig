//! Search: port of $7B96-$80A6 and $80A7-$810E (static scoring, pick-best,
//! find-move, the THINK/PASS driver and the ply state machine, pruning,
//! extensions, mate/stalemate/repetition handling), plus the computer-move
//! path of the main loop ($6147-$61C1, without the user interface).
//! Spec: docs/arch/30-search.md; executable reference:
//! tools/research/search/model.py. Phase 3 units 3.8-3.10.
//!
//! Interface (used by the game layer, the driver and the UCI layer):
//!   pub const Observer = ...;  // instrumentation hooks (EXTENDED_SEARCH §6):
//!                              // make, evaluation, node entry (may request an
//!                              // abort = key press at $78BA), ...
//!   pub fn scoreMoves(s: *State, header: u32, obs: *Observer) void;   // $7B96
//!   pub fn findMove(s: *State, header: u32, n: u8, from: u8, to: u8) ?u32; // $7BCD
//!   pub const Outcome = union(enum) { move: u32, no_moves, no_mate };
//!   pub fn computerMove(s: *State, r: *st.RSource, obs: *Observer) Outcome; // $6147
//! `computerMove` runs everything from ComputerMove's entry to the point
//! where the original jumps to PlayMove (or to the game-over / NO MATE FOUND
//! paths), in original mode (the levels' own pass schedule).

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
