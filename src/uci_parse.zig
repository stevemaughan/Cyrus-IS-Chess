//! Parsing of UCI commands (AGENTS.md §9). No allocation: strings and move
//! lists are returned as slices of the input line.

const std = @import("std");

pub const Go = struct {
    /// Text of the `searchmoves` list (space-separated moves), or null.
    searchmoves: ?[]const u8 = null,
    ponder: bool = false,
    wtime: ?u64 = null,
    btime: ?u64 = null,
    winc: u64 = 0,
    binc: u64 = 0,
    movestogo: ?u32 = null,
    depth: ?u32 = null,
    nodes: ?u64 = null,
    mate: ?u32 = null,
    movetime: ?u64 = null,
    infinite: bool = false,
};

pub const Position = struct {
    /// FEN text, or null for `startpos`.
    fen: ?[]const u8,
    /// Text after `moves` (space-separated UCI moves), possibly empty.
    moves: []const u8,
};

pub const SetOption = struct {
    name: []const u8,
    value: ?[]const u8,
};

pub const Command = union(enum) {
    uci,
    isready,
    ucinewgame,
    quit,
    stop,
    ponderhit,
    debug: bool,
    setoption: SetOption,
    position: Position,
    go: Go,
    /// Empty line or unknown command (ignored, as UCI requires).
    unknown,
};

fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

/// Parse one input line.
pub fn parse(line_in: []const u8) error{BadCommand}!Command {
    const line = trim(line_in);
    var it = std.mem.tokenizeAny(u8, line, " \t");
    const word = it.next() orelse return .unknown;
    const rest = trim(it.rest());
    if (std.mem.eql(u8, word, "uci")) return .uci;
    if (std.mem.eql(u8, word, "isready")) return .isready;
    if (std.mem.eql(u8, word, "ucinewgame")) return .ucinewgame;
    if (std.mem.eql(u8, word, "quit")) return .quit;
    if (std.mem.eql(u8, word, "stop")) return .stop;
    if (std.mem.eql(u8, word, "ponderhit")) return .ponderhit;
    if (std.mem.eql(u8, word, "debug")) return .{ .debug = std.mem.eql(u8, rest, "on") };
    if (std.mem.eql(u8, word, "setoption")) return .{ .setoption = try parseSetOption(rest) };
    if (std.mem.eql(u8, word, "position")) return .{ .position = try parsePosition(rest) };
    if (std.mem.eql(u8, word, "go")) return .{ .go = try parseGo(rest) };
    return .unknown;
}

/// `name <id with spaces> [value <rest of line>]`
fn parseSetOption(rest: []const u8) error{BadCommand}!SetOption {
    if (!std.mem.startsWith(u8, rest, "name ")) return error.BadCommand;
    const body = rest["name ".len..];
    if (std.mem.indexOf(u8, body, " value ")) |i| {
        return .{ .name = trim(body[0..i]), .value = trim(body[i + " value ".len ..]) };
    }
    if (std.mem.endsWith(u8, body, " value")) {
        return .{ .name = trim(body[0 .. body.len - " value".len]), .value = "" };
    }
    return .{ .name = trim(body), .value = null };
}

/// `startpos [moves ...]` or `fen <6 fields> [moves ...]`
fn parsePosition(rest: []const u8) error{BadCommand}!Position {
    var fen_part = rest;
    var moves: []const u8 = "";
    if (std.mem.indexOf(u8, rest, "moves")) |i| {
        fen_part = trim(rest[0..i]);
        moves = trim(rest[i + "moves".len ..]);
    }
    if (std.mem.eql(u8, fen_part, "startpos")) return .{ .fen = null, .moves = moves };
    if (std.mem.startsWith(u8, fen_part, "fen ")) return .{ .fen = trim(fen_part["fen ".len..]), .moves = moves };
    return error.BadCommand;
}

fn num(comptime T: type, it: *std.mem.TokenIterator(u8, .any)) error{BadCommand}!T {
    const t = it.next() orelse return error.BadCommand;
    // Negative clock values (some GUIs send them when flagged) count as 0.
    if (t.len > 0 and t[0] == '-') return 0;
    return std.fmt.parseInt(T, t, 10) catch error.BadCommand;
}

const go_keywords = [_][]const u8{ "searchmoves", "ponder", "wtime", "btime", "winc", "binc", "movestogo", "depth", "nodes", "mate", "movetime", "infinite" };

fn isKeyword(t: []const u8) bool {
    for (go_keywords) |k| if (std.mem.eql(u8, t, k)) return true;
    return false;
}

fn parseGo(rest: []const u8) error{BadCommand}!Go {
    var g: Go = .{};
    var it = std.mem.tokenizeAny(u8, rest, " \t");
    while (it.next()) |t| {
        if (std.mem.eql(u8, t, "searchmoves")) {
            // moves until the next keyword
            const start = it.index;
            var end = start;
            while (it.peek()) |m| {
                if (isKeyword(m)) break;
                _ = it.next();
                end = it.index;
            }
            g.searchmoves = trim(rest[start..end]);
        } else if (std.mem.eql(u8, t, "ponder")) {
            g.ponder = true;
        } else if (std.mem.eql(u8, t, "infinite")) {
            g.infinite = true;
        } else if (std.mem.eql(u8, t, "wtime")) {
            g.wtime = try num(u64, &it);
        } else if (std.mem.eql(u8, t, "btime")) {
            g.btime = try num(u64, &it);
        } else if (std.mem.eql(u8, t, "winc")) {
            g.winc = try num(u64, &it);
        } else if (std.mem.eql(u8, t, "binc")) {
            g.binc = try num(u64, &it);
        } else if (std.mem.eql(u8, t, "movestogo")) {
            g.movestogo = try num(u32, &it);
        } else if (std.mem.eql(u8, t, "depth")) {
            g.depth = try num(u32, &it);
        } else if (std.mem.eql(u8, t, "nodes")) {
            g.nodes = try num(u64, &it);
        } else if (std.mem.eql(u8, t, "mate")) {
            g.mate = try num(u32, &it);
        } else if (std.mem.eql(u8, t, "movetime")) {
            g.movetime = try num(u64, &it);
        } else {
            return error.BadCommand;
        }
    }
    return g;
}

test "parse basic commands" {
    try std.testing.expect((try parse("uci")) == .uci);
    try std.testing.expect((try parse("  isready \r\n")) == .isready);
    try std.testing.expect((try parse("")) == .unknown);
    try std.testing.expect((try parse("xyzzy")) == .unknown);
    try std.testing.expectEqual(true, (try parse("debug on")).debug);
}

test "parse setoption" {
    const o = (try parse("setoption name Level value Level 3")).setoption;
    try std.testing.expectEqualStrings("Level", o.name);
    try std.testing.expectEqualStrings("Level 3", o.value.?);
    const p = (try parse("setoption name Move Overhead value 50")).setoption;
    try std.testing.expectEqualStrings("Move Overhead", p.name);
    try std.testing.expectEqualStrings("50", p.value.?);
    const b = (try parse("setoption name UCI_ShowCurrLine")).setoption;
    try std.testing.expect(b.value == null);
}

test "parse position" {
    const s = (try parse("position startpos moves e2e4 e7e5")).position;
    try std.testing.expect(s.fen == null);
    try std.testing.expectEqualStrings("e2e4 e7e5", s.moves);
    const f = (try parse("position fen 8/8/8/4k3/8/8/8/4K2R w K - 0 1 moves e1g1")).position;
    try std.testing.expectEqualStrings("8/8/8/4k3/8/8/8/4K2R w K - 0 1", f.fen.?);
    try std.testing.expectEqualStrings("e1g1", f.moves);
    try std.testing.expectError(error.BadCommand, parse("position garbage"));
}

test "parse go" {
    const g = (try parse("go wtime 60000 btime 59000 winc 1000 binc 1000 movestogo 20")).go;
    try std.testing.expectEqual(@as(?u64, 60000), g.wtime);
    try std.testing.expectEqual(@as(u64, 1000), g.binc);
    try std.testing.expectEqual(@as(?u32, 20), g.movestogo);
    const s = (try parse("go searchmoves e2e4 d2d4 depth 6")).go;
    try std.testing.expectEqualStrings("e2e4 d2d4", s.searchmoves.?);
    try std.testing.expectEqual(@as(?u32, 6), s.depth);
    try std.testing.expect((try parse("go infinite")).go.infinite);
    try std.testing.expect((try parse("go ponder wtime 1000 btime 1000")).go.ponder);
    try std.testing.expectEqual(@as(?u64, 0), (try parse("go wtime -50 btime 100")).go.wtime);
    try std.testing.expectError(error.BadCommand, parse("go depth x"));
}
