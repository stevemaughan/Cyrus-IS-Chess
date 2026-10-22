//! Cyrus IS Chess: a faithful UCI port of Richard Lang's ZX Spectrum engine.
//! See AGENTS.md and docs/ for the specification.

pub const state = @import("state.zig");
pub const tables = @import("tables.zig");
pub const board = @import("board.zig");
pub const movegen = @import("movegen.zig");
pub const eval = @import("eval.zig");
pub const book = @import("book.zig");

test {
    _ = state;
    _ = tables;
    _ = board;
    _ = movegen;
    _ = eval;
    _ = book;
    _ = @import("golden.zig");
}
