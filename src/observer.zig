//! Instrumentation hooks (docs/EXTENDED_SEARCH.md §6). The search calls these
//! at fixed points; nothing the search reads may depend on what an observer
//! does, except `node`, which models the original's key poll at $78BA (a key
//! press = abort request). Golden tests use an observer to count and hash
//! makes; the UCI layer uses one for search information.

const State = @import("state.zig").State;

pub const Observer = struct {
    ctx: ?*anyopaque = null,
    /// A move was made by $810F at ply `ply` (makes during static scoring
    /// included): (ply, from, to) as the original's make sees them.
    onMake: ?*const fn (ctx: ?*anyopaque, ply: u8, from: u8, to: u8) void = null,
    /// The evaluation $8400 was called.
    onEval: ?*const fn (ctx: ?*anyopaque) void = null,
    /// A search node was entered ($7D43, the key poll at $78BA). Return true
    /// to report a key press (the search then sets the abort flag).
    onNode: ?*const fn (ctx: ?*anyopaque, s: *const State) bool = null,

    pub fn make(o: *const Observer, ply: u8, from: u8, to: u8) void {
        if (o.onMake) |f| f(o.ctx, ply, from, to);
    }

    pub fn evaluated(o: *const Observer) void {
        if (o.onEval) |f| f(o.ctx);
    }

    pub fn node(o: *const Observer, s: *const State) bool {
        if (o.onNode) |f| return f(o.ctx, s);
        return false;
    }
};

/// An observer that does nothing (no key is ever pressed).
pub const none: Observer = .{};
