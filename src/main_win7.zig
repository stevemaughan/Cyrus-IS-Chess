//! Entry point of the Windows 7 build (`zig build -Dwin7=true`): the UCI
//! engine on the small I/O layer of win7_io.zig, without `std.Io.Threaded`,
//! which needs Windows 8. The `perft` and `perftsuite` test tools are not in
//! this build; use the standard build for them.

const std = @import("std");
const cyrus = @import("cyrus");
const win7_io = cyrus.win7_io;

comptime {
    if (!win7_io.enabled) @compileError("main_win7.zig is the entry point of -Dwin7=true builds only");
}

// std's panic handler, segfault handler and debug output all print through
// `std.Io.Threaded`. This build replaces the first, switches off the second
// and makes any use of the third a compile error, because win7_io's `Io`
// cannot lock standard error.
pub const panic = std.debug.FullPanic(win7_io.panic);
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
const no_debug_io = "the Windows 7 build cannot use std's debug output: build it ReleaseFast or ReleaseSafe";
pub const std_options_debug_io: std.Io = @compileError(no_debug_io);
pub const std_options_debug_threaded_io: ?*std.Io.Threaded = @compileError(no_debug_io);

pub fn main(init: std.process.Init.Minimal) u8 {
    run(init) catch |err| {
        win7_io.stderrWrite("error: ");
        win7_io.stderrWrite(@errorName(err));
        win7_io.stderrWrite("\n");
        return 1;
    };
    return 0;
}

fn run(init: std.process.Init.Minimal) !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const args = try init.args.toSlice(arena.allocator());
    if (args.len >= 2 and (std.mem.eql(u8, args[1], "perft") or std.mem.eql(u8, args[1], "perftsuite"))) {
        return error.PerftToolsAreNotInTheWindows7Build;
    }
    try cyrus.uci.run(std.heap.smp_allocator, win7_io.io);
}
