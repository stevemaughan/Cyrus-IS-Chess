//! Game layer: the parts of the main loop that build and change the game
//! state, without the user interface. New game ($6505 InitBoard and
//! $607F-$60A7), set-up mode ($6D4D-$6F22: piece entry, AssignScan, slot
//! rules, legality check, ResetGameCounters), the game-move path (HumanMove's
//! validation and PlayMove $6323 with ChoosePromotion, the record, the
//! 50-move counter, TrackRepetition $6560, side to move, move number,
//! exclusion list), SwapSides/KeyMove ($695D/$696A), FEN loading by the
//! canonical construction (AGENTS.md §9.4) and the canonical operator script
//! (AGENTS.md §9.6; tools/oracle/oracle.py Session). Spec: docs/arch/10-main-ui.md.
//! Phase 3 units 3.2, 3.6, 3.12.
//!
//! Interface (used by the UCI layer):
//!   pub fn newGame(s: *State) void;
//!   pub fn loadFen(s: *State, fen: []const u8, ...) !void;   // error = rejected (reason)
//!   pub fn playMove(s: *State, uci: Move, ...) !void;        // human-move path
//!   pub const Session = ...;                                 // load / continue / go

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
