//! Random sources (DEV-006). The original's random byte $BCCE is stirred by
//! the Z80 R register and by the time spent waiting for a key; the book reads
//! R directly. The port replaces both with a seeded generator: $BCCE is set
//! from it at each `go`, and every R read takes its next byte. Everything
//! else about $BCCE (the evaluation's increment and noise) is unchanged.

const std = @import("std");
const st = @import("state.zig");

/// SplitMix64: small, fast, and good enough for an 8-bit noise source.
pub const Rng = struct {
    state: u64,

    pub fn init(seed: u64) Rng {
        return .{ .state = seed };
    }

    pub fn next64(r: *Rng) u64 {
        r.state +%= 0x9E3779B97F4A7C15;
        var z = r.state;
        z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
        z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
        return z ^ (z >> 31);
    }

    pub fn byte(r: *Rng) u8 {
        return @truncate(r.next64() >> 56);
    }

    /// An RSource drawing from this generator.
    pub fn source(r: *Rng) st.RSource {
        return .{ .ctx = r, .nextFn = nextImpl };
    }

    fn nextImpl(ctx: *anyopaque) u8 {
        const r: *Rng = @ptrCast(@alignCast(ctx));
        return r.byte();
    }
};

test "deterministic for a seed" {
    var a = Rng.init(42);
    var b = Rng.init(42);
    for (0..100) |_| try std.testing.expectEqual(a.byte(), b.byte());
    var c = Rng.init(43);
    var same: usize = 0;
    a = Rng.init(42);
    for (0..100) |_| {
        if (a.byte() == c.byte()) same += 1;
    }
    try std.testing.expect(same < 10);
    var src = a.source();
    _ = src.next();
}
