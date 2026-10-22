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
pub const driver = @import("driver.zig");
pub const info = @import("info.zig");
pub const legal = @import("legal.zig");
pub const rng = @import("rng.zig");
pub const engine = @import("engine.zig");
pub const uci = @import("uci.zig");
pub const pipe_io = @import("pipe_io.zig");
pub const perft = @import("perft.zig");

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
    _ = driver;
    _ = info;
    _ = legal;
    _ = rng;
    _ = engine;
    _ = uci;
    _ = pipe_io;
    _ = perft;
    _ = @import("golden.zig");
    _ = @import("integrity.zig");
    // The search's golden comparisons (also `zig build test-search`).
    _ = @import("search_test.zig");
}
