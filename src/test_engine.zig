//! Test root for the engine and UCI layer: `zig build test-engine`.
test {
    _ = @import("info.zig");
    _ = @import("legal.zig");
    _ = @import("rng.zig");
    _ = @import("engine.zig");
}
