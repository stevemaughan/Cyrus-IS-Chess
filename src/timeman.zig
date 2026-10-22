//! Time management for extended mode (docs/EXTENDED_SEARCH.md §4). The
//! original has no clock; this decides when to stop starting passes (soft
//! limit) and when to abort a pass as a key press would (hard limit).

const std = @import("std");

pub const Limits = struct {
    /// Milliseconds; null = no time limit (depth, nodes, mate, infinite).
    soft_ms: ?u64,
    hard_ms: ?u64,
    /// `movetime`: the whole time is granted, so passes keep starting until
    /// it is used and the hard limit ends the last one (docs/UCI.md).
    use_all: bool = false,
};

pub const Clock = struct {
    time_ms: ?u64 = null, // our remaining time (wtime or btime)
    inc_ms: u64 = 0, // our increment
    movestogo: ?u32 = null,
    movetime_ms: ?u64 = null,
};

/// Budget for one move. `overhead_ms` is the UCI option "Move Overhead".
pub fn budget(c: Clock, overhead_ms: u64) Limits {
    if (c.movetime_ms) |mt| {
        const t = if (mt > overhead_ms) mt - overhead_ms else 1;
        return .{ .soft_ms = t, .hard_ms = t, .use_all = true };
    }
    const t = c.time_ms orelse return .{ .soft_ms = null, .hard_ms = null };
    const mtg: u64 = c.movestogo orelse 30;
    const soft = t / @max(mtg, 1) + c.inc_ms * 3 / 4;
    const third = t / 3;
    const hard_raw = @min(soft * 5, third);
    const hard = if (hard_raw > overhead_ms) hard_raw - overhead_ms else 1;
    return .{ .soft_ms = @min(soft, hard), .hard_ms = hard };
}

/// Whether the next pass may start (§4): only if the time used plus the
/// predicted duration of the next pass fits the soft limit. The prediction is
/// the last pass's duration times the larger of the last growth ratio and 3,
/// and 0 before two passes exist.
pub fn startNextPass(limits: Limits, elapsed_ms: u64, last_pass_ms: ?u64, prev_pass_ms: ?u64) bool {
    const soft = limits.soft_ms orelse return true;
    if (limits.use_all) return elapsed_ms < soft;
    const last = last_pass_ms orelse return elapsed_ms < soft;
    const prev = prev_pass_ms orelse return elapsed_ms < soft;
    var ratio: u64 = 3;
    if (prev > 0) ratio = @max(ratio, (last + prev - 1) / prev);
    return elapsed_ms + last * ratio <= soft;
}

test "movetime budget" {
    const l = budget(.{ .movetime_ms = 1000 }, 30);
    try std.testing.expectEqual(@as(?u64, 970), l.soft_ms);
    try std.testing.expectEqual(@as(?u64, 970), l.hard_ms);
}

test "clock budget" {
    // 60 s, 1 s increment, no movestogo: 60000/30 + 750 = 2750 soft
    const l = budget(.{ .time_ms = 60_000, .inc_ms = 1000 }, 30);
    try std.testing.expectEqual(@as(?u64, 2750), l.soft_ms);
    try std.testing.expectEqual(@as(?u64, 13_720), l.hard_ms); // min(5 * 2750, 20000) - 30
    // nearly flagged: hard limit a third of the remaining time
    const tiny = budget(.{ .time_ms = 90 }, 30);
    try std.testing.expect(tiny.hard_ms.? <= 30);
}

test "no clock means no limits" {
    const l = budget(.{}, 30);
    try std.testing.expect(l.soft_ms == null and l.hard_ms == null);
}

test "next pass prediction" {
    const l: Limits = .{ .soft_ms = 1000, .hard_ms = 5000 };
    try std.testing.expect(startNextPass(l, 100, 50, 10)); // 100 + 50*5 = 350
    try std.testing.expect(!startNextPass(l, 600, 200, 100)); // 600 + 200*3 = 1200
    try std.testing.expect(startNextPass(l, 0, null, null));
    try std.testing.expect(startNextPass(l, 900, 800, null)); // one pass: predicted 0
    const mt = budget(.{ .movetime_ms = 1000 }, 30);
    try std.testing.expect(startNextPass(mt, 900, 800, 10));
    try std.testing.expect(!startNextPass(mt, 970, 800, 10));
}
