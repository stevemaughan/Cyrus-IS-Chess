const std = @import("std");
const cyrus = @import("cyrus");

/// `cyrus` runs the UCI engine. Test tools:
///   `cyrus perft <depth> <fen...>`        perft split by root move
///   `cyrus perftsuite <epd> [max-nodes]`  check an EPD perft suite (";D1 n ;D2 n ...")
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len >= 2 and (std.mem.eql(u8, args[1], "perft") or std.mem.eql(u8, args[1], "perftsuite"))) {
        return perftTool(init, args);
    }
    try cyrus.uci.run(init.gpa, init.io);
}

fn perftTool(init: std.process.Init, args: []const []const u8) !void {
    var buf: [4096]u8 = undefined;
    var fw: std.Io.File.Writer = .init(.stdout(), init.io, &buf);
    const w = &fw.interface;
    defer w.flush() catch {};
    const s = try init.gpa.create(cyrus.state.State);
    defer init.gpa.destroy(s);
    if (std.mem.eql(u8, args[1], "perft")) {
        if (args.len < 4) return error.Usage;
        const depth = try std.fmt.parseInt(u32, args[2], 10);
        const fen = try std.mem.join(init.arena.allocator(), " ", args[3..]);
        try cyrus.perft.load(s, fen);
        _ = try cyrus.perft.divide(s, depth, w);
        return;
    }
    // perftsuite
    if (args.len < 3) return error.Usage;
    const max_nodes: u64 = if (args.len >= 4) try std.fmt.parseInt(u64, args[3], 10) else 50_000_000;
    const text = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.arena.allocator(), .limited(16 << 20));
    var lines = std.mem.splitScalar(u8, text, '\n');
    var cases: usize = 0;
    var failed: usize = 0;
    var total_nodes: u64 = 0;
    const t0 = std.Io.Clock.awake.now(init.io).nanoseconds;
    while (lines.next()) |line| {
        const c = cyrus.perft.parseLine(line) orelse continue;
        cases += 1;
        cyrus.perft.load(s, c.fen) catch |err| {
            failed += 1;
            try w.print("REJECTED {s}: {t}\n", .{ c.fen, err });
            continue;
        };
        var d: u32 = 1;
        var deepest: u32 = 0;
        while (d < c.counts.len) : (d += 1) {
            const want = c.counts[d] orelse break;
            if (want > max_nodes) break;
            const got = cyrus.perft.perft(s, d, .full);
            total_nodes += got;
            if (got != want) {
                failed += 1;
                try w.print("FAIL {s} depth {d}: got {d}, want {d}\n", .{ c.fen, d, got, want });
                break;
            }
            deepest = d;
        }
        try w.print("ok   depth {d}  {s}\n", .{ deepest, c.fen });
        try w.flush();
    }
    const ms = @divTrunc(std.Io.Clock.awake.now(init.io).nanoseconds - t0, std.time.ns_per_ms);
    try w.print("{d} positions, {d} failed, {d} leaf nodes, {d} ms\n", .{ cases, failed, total_nodes, ms });
}
