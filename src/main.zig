const std = @import("std");
const cyrus = @import("cyrus");

pub fn main(init: std.process.Init) !void {
    _ = cyrus;
    var buf: [256]u8 = undefined;
    var w: std.Io.File.Writer = .init(.stdout(), init.io, &buf);
    try w.interface.writeAll("Cyrus IS Chess (Zig port) - UCI layer not implemented yet\n");
    try w.interface.flush();
}
