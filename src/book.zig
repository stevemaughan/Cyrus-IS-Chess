//! Opening book probe: port of $7AC7-$7B95; data from the binary
//! (tables.book). Spec: docs/arch/25-book.md; reference decoder:
//! tools/scripts/book_dump.py. Owner: Phase 3 unit 3.11.
//!
//! Interface:
//!   pub fn probe(s: *State, r: *state.RSource) ?u32;
//! Probes with the root list already generated and scored at $B404 (ply 1)
//! and the game record; returns the chosen entry's address (as $BD29 would
//! hold) or null, updating s.book_state and s.random exactly as the original.
//! `r` supplies the values the original reads from the R register (DEV-006).

const std = @import("std");
const State = @import("state.zig").State;
