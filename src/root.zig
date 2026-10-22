//! Cyrus IS Chess: a faithful UCI port of Richard Lang's ZX Spectrum engine.
//! See AGENTS.md and docs/ for the specification.

pub const state = @import("state.zig");
pub const tables = @import("tables.zig");
pub const board = @import("board.zig");
pub const movegen = @import("movegen.zig");
pub const eval = @import("eval.zig");
pub const book = @import("book.zig");
pub const presearch = @import("presearch.zig");
pub const observer = @import("observer.zig");
pub const scoring = @import("scoring.zig");
pub const search = @import("search.zig");
pub const game = @import("game.zig");
pub const timeman = @import("timeman.zig");
pub const uci_parse = @import("uci_parse.zig");

test {
    _ = state;
    _ = tables;
    _ = board;
    _ = movegen;
    _ = eval;
    _ = book;
    _ = presearch;
    _ = observer;
    _ = scoring;
    _ = search;
    _ = game;
    _ = timeman;
    _ = uci_parse;
    _ = @import("golden.zig");
}
