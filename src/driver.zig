//! Extended mode: iterative deepening built from the original's own pass
//! mechanism (docs/EXTENDED_SEARCH.md §3). Phase 3 unit 3.13.
//!
//! The original Levels 6-8 run a Level-2 pre-pass and then a depth-4 pass that
//! searches the pre-pass's best move first. Extended mode repeats that
//! second pass at D = 4, 5, 6, ... with the switches of a chosen original
//! level (the profile). The schedule is chosen so that the anchors reproduce
//! the original exactly:
//!   depth 1 = Level 1; depth 2 = Level 2;
//!   depth 4 with profile Level 6/7/8 = that level.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const movegen = @import("movegen.zig");
const scoring = @import("scoring.zig");
const presearch = @import("presearch.zig");
const search = @import("search.zig");
const Observer = @import("observer.zig").Observer;

/// The level parameter `a` of the passes after the pre-pass: 5, 6 or 7 for
/// the switches of Level 6, 7 or 8 (threat extensions: a & 2; forward
/// pruning off: a & 1 with a & 2).
pub const Profile = enum(u8) {
    level6 = 5,
    level7 = 6,
    level8 = 7,

    pub fn a(p: Profile) u8 {
        return @intFromEnum(p);
    }
};

pub const Plan = struct {
    profile: Profile = .level8,
    /// Deepest full-width depth to search (1 .. state.max_depth).
    max_depth: u8 = st.max_depth,
    /// Called after every completed (not aborted) pass with its depth; return
    /// false to stop before the next pass. Null: continue to `max_depth`.
    ctx: ?*anyopaque = null,
    nextPass: ?*const fn (ctx: ?*anyopaque, s: *const State, completed_depth: u8) bool = null,
};

/// The k-th pass (0-based) of the schedule for `max_depth`, or null when the
/// schedule is complete.
pub fn schedule(plan: Plan, k: usize) ?search.PassParams {
    const n = plan.max_depth;
    const first = k == 0;
    if (n <= 1) return if (k == 0) .{ .a = 0, .depth = 1, .first = true } else null;
    if (k == 0) return .{ .a = 1, .depth = 2, .first = true };
    if (n == 2) return null;
    if (n == 3) return if (k == 1) .{ .a = plan.profile.a(), .depth = 3, .first = first } else null;
    const d = 3 + k; // k = 1 -> 4
    if (d > n) return null;
    return .{ .a = plan.profile.a(), .depth = @intCast(d), .first = false };
}

/// THINK for extended mode: the pre-search set-up once, then the pass
/// schedule. A NO MORE MOVES pass (every root move excluded) restarts THINK
/// as the original does ($7CFD). An abort (key press = stop / time / nodes,
/// DEV-007) ends the schedule, except during the pre-pass: the original's
/// Levels 6-8 still run their second pass after an abort in the first, and
/// so does the anchor pass that follows the pre-pass here.
pub fn think(se: *search.Search, plan: Plan) search.PassResult {
    const s = se.s;
    restart: while (true) {
        se.obs.evaluated(); // $7810 calls the evaluation once
        _ = presearch.preSearch(s);
        var k: usize = 0;
        while (schedule(plan, k)) |params| : (k += 1) {
            const aborted_before = s.search_flags & 0x80 != 0;
            if (aborted_before and k > 1) return .done;
            switch (se.pass(params)) {
                .book => return .book,
                .no_move => return .no_move,
                .no_more_moves => continue :restart,
                .done => {},
            }
            if (s.search_flags & 0x80 != 0) {
                // Aborted in this pass: stop, unless this was the pre-pass
                // and the anchor pass follows (the original's second pass).
                if (k == 0 and schedule(plan, 1) != null) continue;
                return .done;
            }
            if (aborted_before) return .done;
            if (plan.nextPass) |f| {
                if (schedule(plan, k + 1) != null and !f(plan.ctx, s, params.depth)) return .done;
            }
        }
        return .done;
    }
}

/// The computer-move path ($6147-$61C1) in extended mode: as
/// search.computerMove, with THINK replaced by the pass schedule. Problem
/// levels do not exist in extended mode (`go mate` is a limit instead).
pub fn computerMove(s: *State, r: *st.RSource, obs: *const Observer, opts: search.Options, plan: Plan) search.Outcome {
    s.search_flags = 0x40; // $614E
    const g = movegen.generate(s, st.root_record); // $6153
    obs.rootGenerated(s, g.header, g.count);
    scoring.scoreMoves(s, g.header, g.count, obs);
    obs.rootScored(s, g.header, g.count);
    if (s.best_static == 0) return .no_moves; // $615D
    if (s.next_best == 0) s.exclusion_len = 0; // $6168
    var se: search.Search = .{ .s = s, .r = r, .obs = obs, .opts = opts };
    _ = think(&se, plan);
    s.next_best = 0; // $6194
    return .{ .move = s.move_to_play };
}

test "schedule" {
    const t = std.testing;
    const p8: Plan = .{ .profile = .level8, .max_depth = 4 };
    try t.expectEqual(search.PassParams{ .a = 1, .depth = 2, .first = true }, schedule(p8, 0).?);
    try t.expectEqual(search.PassParams{ .a = 7, .depth = 4, .first = false }, schedule(p8, 1).?);
    try t.expect(schedule(p8, 2) == null);
    try t.expectEqual(search.PassParams{ .a = 0, .depth = 1, .first = true }, schedule(.{ .max_depth = 1 }, 0).?);
    try t.expect(schedule(.{ .max_depth = 2 }, 1) == null);
    try t.expectEqual(@as(u8, 3), schedule(.{ .max_depth = 3, .profile = .level6 }, 1).?.depth);
    try t.expectEqual(@as(u8, 9), schedule(.{ .max_depth = 60 }, 6).?.depth);
}

test {
    _ = @import("driver_test.zig");
}
