//! Reading oracle golden files (tests/golden/*.jsonl.gz, tools/oracle/README.md)
//! and loading their captured states into a `State`. Test support only.

const std = @import("std");
const State = @import("state.zig").State;

pub const Golden = struct {
    arena: std.heap.ArenaAllocator,
    /// Record lines (the header line excluded).
    lines: [][]const u8,
    header: []const u8,

    pub fn deinit(g: *Golden) void {
        g.arena.deinit();
    }

    /// Parse one record line as a dynamic JSON value (allocated in `alloc`).
    pub fn parse(g: *Golden, alloc: std.mem.Allocator, i: usize) !std.json.Parsed(std.json.Value) {
        return std.json.parseFromSlice(std.json.Value, alloc, g.lines[i], .{});
    }
};

/// Read a gzip-compressed JSON-lines golden file completely into memory.
pub fn open(gpa: std.mem.Allocator, io: std.Io, file_path: []const u8) !Golden {
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();
    const a = arena.allocator();

    var file = try std.Io.Dir.cwd().openFile(io, file_path, .{});
    defer file.close(io);
    var file_buf: [64 * 1024]u8 = undefined;
    var file_reader = file.reader(io, &file_buf);
    const window = try a.alloc(u8, std.compress.flate.max_window_len);
    var decompress = std.compress.flate.Decompress.init(&file_reader.interface, .gzip, window);
    const text = try decompress.reader.allocRemaining(a, .unlimited);

    var lines: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, text, '\n');
    const header = it.next() orelse return error.EmptyGolden;
    while (it.next()) |line| {
        if (line.len != 0) try lines.append(a, line);
    }
    return .{ .arena = arena, .lines = try lines.toOwnedSlice(a), .header = header };
}

fn hexInto(out: []u8, hex: []const u8) !void {
    if (hex.len != out.len * 2) return error.BadHexLength;
    _ = try std.fmt.hexToBytes(out, hex);
}

fn str(obj: std.json.ObjectMap, key: []const u8) ![]const u8 {
    const v = obj.get(key) orelse return error.MissingField;
    return switch (v) {
        .string => |s| s,
        else => error.WrongType,
    };
}

pub fn int(obj: std.json.ObjectMap, key: []const u8) !i64 {
    const v = obj.get(key) orelse return error.MissingField;
    return switch (v) {
        .integer => |i| i,
        else => error.WrongType,
    };
}

/// Load a captured state (oracle.capture_state format) into `s`.
/// Bytes of original variables the engine never reads are ignored.
pub fn loadState(s: *State, state: std.json.ObjectMap) !void {
    try hexInto(&s.rec, try str(state, "pieces"));

    var board: [64]u8 = undefined;
    try hexInto(&board, try str(state, "board"));
    var off: [64]u8 = undefined;
    try hexInto(&off, try str(state, "offboard"));
    for (0..8) |r| {
        for (0..8) |f| {
            s.board[r * 16 + f] = board[r * 8 + f];
            _ = s.set(@intCast(0xBD08 + r * 16 + f), off[r * 8 + f]);
        }
    }

    var bc83: [0xBD00 - 0xBC83]u8 = undefined;
    try hexInto(&bc83, try str(state, "bc83"));
    for (bc83, 0..) |v, i| _ = s.set(@intCast(0xBC83 + i), v);
    s.threat_ext = @intCast(try int(state, "bdf6"));

    const excl = try str(state, "exclusion");
    if (excl.len / 2 > s.exclusion.len) return error.ExclusionTooLong;
    s.exclusion_len = @intCast(excl.len / 2);
    try hexInto(s.exclusion[0..s.exclusion_len], excl);

    var c000: [0x58]u8 = undefined;
    try hexInto(&c000, try str(state, "c000"));
    s.tape_marker = c000[0];
    s.plies = std.mem.readInt(u16, c000[1..3], .little);
    s.replay_target = std.mem.readInt(u16, c000[3..5], .little);
    s.start_side = c000[5];
    s.start_move = c000[6];
    @memcpy(&s.start_pos, c000[7..0x47]);
    s.promo_count = c000[0x47];
    @memcpy(&s.promos, c000[0x48..0x58]);

    const rec = try str(state, "record");
    if (rec.len / 2 > s.record.len) return error.RecordTooLong;
    @memset(&s.record, 0xFF);
    try hexInto(s.record[0 .. rec.len / 2], rec);
}

/// Path of a golden file: build option `golden_dir` + name.
pub fn path(buf: []u8, name: []const u8) ![]const u8 {
    const dir = @import("build_options").golden_dir;
    return std.fmt.bufPrint(buf, "{s}/{s}", .{ dir, name });
}

test "load every state of the search golden file" {
    const gpa = std.testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try open(gpa, std.testing.io, try path(&buf, "search.jsonl.gz"));
    defer g.deinit();
    try std.testing.expect(g.lines.len == 2000);
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    var n: usize = 0;
    for (0..g.lines.len) |i| {
        var p = try g.parse(gpa, i);
        defer p.deinit();
        const goes = p.value.object.get("goes").?.array;
        for (goes.items) |go| {
            s.* = .{};
            try loadState(s, go.object.get("state").?.object);
            n += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 4028), n);
}
