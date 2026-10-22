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

    // --- added by units 3.8-3.10 (search): observation points of
    // docs/EXTENDED_SEARCH.md §6.1. All optional; none affects the search.

    /// ComputerMove's root list was generated ($615A; `header3` = header +3,
    /// `count` = header count) / statically scored ($615D).
    onRootGenerated: ?*const fn (ctx: ?*anyopaque, s: *const State, header3: u32, count: u8) void = null,
    onRootScored: ?*const fn (ctx: ?*anyopaque, s: *const State, header3: u32, count: u8) void = null,
    /// A search pass starts with full-width depth `depth` and level parameter `a`.
    onPassStart: ?*const fn (ctx: ?*anyopaque, s: *const State, depth: u8, a: u8) void = null,
    /// A root move is made for searching ($7E06 / $80FD: $BD2B set).
    onRootMove: ?*const fn (ctx: ?*anyopaque, s: *const State, entry: u32) void = null,
    /// Alpha was raised at ply `ply` ($7E58 at full-width plies, $7F63 at
    /// selective plies) by the move (from, to) made at that ply (flag bit 7
    /// of the from-square removed).
    onAlpha: ?*const fn (ctx: ?*anyopaque, s: *const State, ply: u8, from: u8, to: u8) void = null,
    /// A new best root move was recorded in $BD29 ($7E8C).
    onNewBest: ?*const fn (ctx: ?*anyopaque, s: *const State, entry: u32) void = null,
    /// A fail-high cut-off happened at ply `ply` ($7E79 / $7F81).
    onCutoff: ?*const fn (ctx: ?*anyopaque, s: *const State, ply: u8) void = null,
    /// A search pass ended (normally, by book, or after an abort).
    onPassDone: ?*const fn (ctx: ?*anyopaque, s: *const State) void = null,
    /// The opening book chose the move at `entry` ($7C23).
    onBookMove: ?*const fn (ctx: ?*anyopaque, s: *const State, entry: u32) void = null,

    pub fn bookMove(o: *const Observer, s: *const State, entry: u32) void {
        if (o.onBookMove) |f| f(o.ctx, s, entry);
    }

    pub fn rootGenerated(o: *const Observer, s: *const State, header3: u32, count: u8) void {
        if (o.onRootGenerated) |f| f(o.ctx, s, header3, count);
    }
    pub fn rootScored(o: *const Observer, s: *const State, header3: u32, count: u8) void {
        if (o.onRootScored) |f| f(o.ctx, s, header3, count);
    }
    pub fn passStart(o: *const Observer, s: *const State, depth: u8, a: u8) void {
        if (o.onPassStart) |f| f(o.ctx, s, depth, a);
    }
    pub fn rootMove(o: *const Observer, s: *const State, entry: u32) void {
        if (o.onRootMove) |f| f(o.ctx, s, entry);
    }
    pub fn alpha(o: *const Observer, s: *const State, ply: u8, from: u8, to: u8) void {
        if (o.onAlpha) |f| f(o.ctx, s, ply, from & 0x7F, to);
    }
    pub fn newBest(o: *const Observer, s: *const State, entry: u32) void {
        if (o.onNewBest) |f| f(o.ctx, s, entry);
    }
    pub fn cutoff(o: *const Observer, s: *const State, ply: u8) void {
        if (o.onCutoff) |f| f(o.ctx, s, ply);
    }
    pub fn passDone(o: *const Observer, s: *const State) void {
        if (o.onPassDone) |f| f(o.ctx, s);
    }

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
