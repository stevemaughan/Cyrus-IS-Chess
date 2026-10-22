//! Evaluation: port of $8400-$8F2E. Spec: docs/arch/50-eval.md; executable
//! reference: tools/research/eval/evalmodel.py. Owner: Phase 3 unit 3.7.
//!
//! Interface:
//!   pub const Result = struct { a: u8, b: u8, c: u8 };
//!   pub fn evaluate(s: *State, ix: u32) Result;
//! `ix` is the move entry just made (s.entry(ix)); the routine sets flag bits
//! in its byte +3 and updates s.random, s.sel_marker, s.see_best/second,
//! s.pins and the attack bytes of the piece records exactly as the original.
//! a = 0 means the position is illegal (abort path).

const std = @import("std");
const State = @import("state.zig").State;
