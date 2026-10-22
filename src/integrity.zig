//! Repository checks (AGENTS.md §2.6, §2.7, §10.2): the reference files match
//! `reference/CHECKSUMS.txt`, and no source carries an UNVERIFIED tag
//! (`zig build check-unverified`; also part of `zig build test`). Test
//! runs use the build root as their working directory.

const std = @import("std");

test "reference files match reference/CHECKSUMS.txt" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const list = try cwd.readFileAlloc(io, "reference/CHECKSUMS.txt", gpa, .limited(1 << 16));
    defer gpa.free(list);
    var checked: usize = 0;
    var lines = std.mem.tokenizeAny(u8, list, "\r\n");
    while (lines.next()) |line| {
        var it = std.mem.tokenizeAny(u8, line, " \t");
        const want = it.next() orelse continue;
        const path = it.next() orelse return error.BadChecksumLine;
        const data = try cwd.readFileAlloc(io, path, gpa, .limited(64 << 20));
        defer gpa.free(data);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(data, &digest, .{});
        const got = std.fmt.bytesToHex(digest, .lower);
        if (!std.mem.eql(u8, &got, want)) {
            std.debug.print("{s}: sha256 {s}, CHECKSUMS.txt says {s}\n", .{ path, &got, want });
            return error.ChecksumMismatch;
        }
        checked += 1;
    }
    try std.testing.expect(checked >= 9);
}

test "no UNVERIFIED tags in src/" {
    // Built from two parts so that this file does not match itself.
    const tag = "UNVERIFIED" ++ ":";
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var dir = try std.Io.Dir.cwd().openDir(io, "src", .{ .iterate = true });
    defer dir.close(io);
    var found: usize = 0;
    var files: usize = 0;
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
        const text = try dir.readFileAlloc(io, entry.name, gpa, .limited(16 << 20));
        defer gpa.free(text);
        files += 1;
        var pos: usize = 0;
        while (std.mem.indexOfPos(u8, text, pos, tag)) |i| : (pos = i + tag.len) {
            const line_no = std.mem.count(u8, text[0..i], "\n") + 1;
            std.debug.print("src/{s}:{d}: {s}\n", .{ entry.name, line_no, tag });
            found += 1;
        }
    }
    try std.testing.expect(files > 20);
    try std.testing.expectEqual(@as(usize, 0), found);
}
