//! Move generator: port of $78CE-$7AC6 (without the key poll at $78BA, which
//! belongs to the search). Spec: docs/arch/20-board-movegen.md §4.2.
//! Owner: Phase 3 unit 3.4.
//!
//! Interface:
//!   pub const Result = struct { count: u8, header: u32 };
//!   pub fn generate(s: *State, ix: u32) Result;
//! Generates the moves of the side selected by s.side_phase bit 0 (0 = White,
//! 1 = Black, as the generator sees it) into the list of ply s.ply starting at
//! s.slot[s.ply]; writes the header, the terminator and s.slot[s.ply + 1]; `ix`
//! is the move that led here (root record = state.root_record). Sets the abort
//! flag (s.search_flags bit 7) instead of writing past s.list_limit.
//! Returns E (the header count) and the header address + 3 as in the original.

const std = @import("std");
const State = @import("state.zig").State;
