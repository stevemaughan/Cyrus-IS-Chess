//! Test root for unit 3.3/3.4 (make/unmake, move generator): `zig build test-board`.
test {
    _ = @import("board.zig");
    _ = @import("movegen.zig");
    _ = @import("state.zig");
}
