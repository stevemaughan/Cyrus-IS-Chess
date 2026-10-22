const std = @import("std");
const cyrus = @import("cyrus");

pub fn main(init: std.process.Init) !void {
    try cyrus.uci.run(init.gpa, init.io);
}
