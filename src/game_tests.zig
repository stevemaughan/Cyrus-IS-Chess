//! Golden tests of the game layer against the oracle (tests/golden/*.jsonl.gz).
//!
//! Every golden session started from reference/snapshots/cyrus48-idle-level1.z80
//! (start position, Level 1, waiting at YOUR MOVE?); `powerOn` rebuilds that
//! state from its capture. The session's operations are then replayed through
//! `game.Session` and compared with the state the oracle captured when
//! ComputerMove ($6147) started.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const golden = @import("golden.zig");
const game = @import("game.zig");
const movegen = @import("movegen.zig");
const scoring = @import("scoring.zig");
const observer = @import("observer.zig");

/// Use the ported search for the computer's moves (full comparison of every
/// computer move). When false, the recorded move is played instead and only
/// the game-layer fields are compared after the first computer move.
const use_search = true;

/// The idle Level-1 snapshot's state (oracle.Oracle().capture_state()), with
/// its exclusion list (254 zero bytes and no terminator) set in `powerOn`.
const power_on_json =
    \\{"pieces":"04000000000001000309000000000e00000500000000080007050000000008000283000000000400058300000000040001030000000000000603000000000000100100000000c000110100000000c000120100000000c000130100000000c000140100000000c000150100000000c000160100000000c000170100000000c00074000000040001007309000000000e0070050000000008007705000000000800728300000000040075830000000004007103000000000000760300000000000060010000000080006101000000008000620100000000800063010000000080006401000000008000650100000000800066010000000080006701000000008000",
    \\"board":"1434240c042c3c1c444c545c646c747c0000000000000000000000000000000000000000000000000000000000000000c4ccd4dce4ecf4fc94b4a48c84acbc9c",
    \\"offboard":"0000000000000000008a30b400000000000000000001000000000050b4ecbd000001000000000000000000000000000000000000000000000000000000000000",
    \\"bc83":"0000000000000000000000000000000000000000000000000000000000000000000000000000010000b454b400000000000000000000000000000001004c310100380e08003a5c60ff0000b3000002040001003c0007040600000000000000000000000000000000000000000000000000000000000000000000000000",
    \\"bdf6":0,"exclusion":"","record":"ff",
++ c000_json;

/// $C000-$C057: zero except $C006 = 1 (standard start).
const c000_json = "\"c000\":\"00000000000001" ++ zeros_81 ++ "\"}";
const zeros_81: *const [162]u8 = blk: {
    var z: [162]u8 = undefined;
    @memset(&z, '0');
    const final = z;
    break :blk &final;
};

fn powerOn(s: *State) !void {
    var p = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, power_on_json, .{});
    defer p.deinit();
    s.* = .{};
    try golden.loadState(s, p.value.object);
    s.exclusion_len = 254;
    @memset(s.exclusion[0..254], 0);
}

// ----------------------------------------------------------------- helpers

fn movesOf(alloc: std.mem.Allocator, arr: std.json.Array) ![]game.Move {
    const out = try alloc.alloc(game.Move, arr.items.len);
    for (arr.items, 0..) |v, i| out[i] = try game.Move.parse(v.string);
    return out;
}

/// The oracle's reasons for rejecting a FEN, as categories of `game.FenError`.
fn reasonMatches(reason: []const u8, err: game.FenError) bool {
    const starts = std.mem.startsWith;
    if (starts(u8, reason, "malformed FEN")) return err == error.MalformedFen;
    if (starts(u8, reason, "castling right")) return err == error.CastlingRightWithoutPieces;
    if (starts(u8, reason, "en passant square inconsistent")) return err == error.EnPassantInconsistent;
    if (starts(u8, reason, "predecessor of en passant")) return err == error.EnPassantPredecessorRejected;
    if (starts(u8, reason, "double pawn step")) return err == error.DoubleStepRejected;
    if (starts(u8, reason, "rejected by the original set-up check")) return switch (err) {
        error.PawnOnBackRank, error.NoFreeSlot, error.KingMissing, error.SideNotToMoveInCheck => true,
        else => false,
    };
    return false;
}

/// Bytes that legitimately differ at $6147: $BCCE (set by the oracle when
/// ComputerMove starts; copied before comparing) and the best static score
/// and its entry ($BD19-$BD1B), which the human-move path's root scoring
/// leaves and which depend on the evaluation's random term (the original's
/// $BCCE there depends on the R register and key timing). ComputerMove
/// overwrites them at $615A before anything reads them.
fn noiseDependent(addr: u16) bool {
    return addr == 0xBCCE or addr == 0xBD19 or addr == 0xBD1A or addr == 0xBD1B;
}

const Mismatch = struct { what: []const u8, addr: u16, got: u32, want: u32 };

/// Compare `s` with the captured state `want` over everything a State can
/// represent. `game_only`: only the game-layer fields (used for computer moves
/// after the first when the search is not used).
fn compareState(s: *const State, want: *const State, game_only: bool) ?Mismatch {
    for (0..128) |sq| {
        if (sq & 0x88 != 0) continue;
        if (s.board[sq] != want.board[sq]) return .{ .what = "board", .addr = @intCast(0xBD00 + sq), .got = s.board[sq], .want = want.board[sq] };
    }
    for (0..256) |i| {
        // King records' attack bytes accumulate junk from every evaluation;
        // without the search they cannot match after the first computer move.
        const king_junk = (i & 0x7F) >= 2 and (i & 0x7F) <= 5;
        if (game_only and king_junk) continue;
        if (game_only and (i & 7) >= 2 and (i & 7) <= 5) continue;
        if (s.rec[i] != want.rec[i]) return .{ .what = "piece record", .addr = @intCast(0xBE00 + i), .got = s.rec[i], .want = want.rec[i] };
    }
    if (s.plies != want.plies) return .{ .what = "plies $C001", .addr = 0xC001, .got = s.plies, .want = want.plies };
    for (0..@as(usize, want.plies) + 1) |i| {
        if (s.record[i] != want.record[i]) return .{ .what = "record", .addr = @intCast(0xC058 + i), .got = s.record[i], .want = want.record[i] };
    }
    const scalars = [_]struct { []const u8, u32, u32 }{
        .{ "start side $C005", s.start_side, want.start_side },
        .{ "start move $C006", s.start_move, want.start_move },
        .{ "promotions $C047", s.promo_count, want.promo_count },
        .{ "exclusion length", s.exclusion_len, want.exclusion_len },
    };
    for (scalars) |c| if (c[1] != c[2]) return .{ .what = c[0], .addr = 0, .got = c[1], .want = c[2] };
    if (!std.mem.eql(u8, &s.start_pos, &want.start_pos)) return .{ .what = "start position $C007", .addr = 0xC007, .got = 0, .want = 0 };
    if (!std.mem.eql(u8, &s.promos, &want.promos)) return .{ .what = "promotion list $C048", .addr = 0xC048, .got = 0, .want = 0 };
    if (!std.mem.eql(u8, s.exclusion[0..s.exclusion_len], want.exclusion[0..want.exclusion_len]))
        return .{ .what = "exclusion list", .addr = 0xBF00, .got = 0, .want = 0 };

    if (game_only) {
        const fields = [_]struct { []const u8, u16, u8, u8 }{
            .{ "side to move", 0xBD2D, s.side_phase & 1, want.side_phase & 1 },
            .{ "move number", 0xBD49, s.move_number, want.move_number },
            .{ "50-move counter", 0xBD0A, s.fifty, want.fifty },
            .{ "root record from", 0xBD59, s.root_rec[1], want.root_rec[1] },
            .{ "root record to", 0xBD5A, s.root_rec[2], want.root_rec[2] },
            .{ "root record flags", 0xBD5B, s.root_rec[3], want.root_rec[3] },
            .{ "previous from", 0xBD5C, s.prev_from, want.prev_from },
            .{ "previous to", 0xBD5D, s.prev_to, want.prev_to },
            .{ "reversals", 0xBD5E, s.reversals, want.reversals },
            .{ "Cyrus's side", 0xBCBE, s.cyrus_side, want.cyrus_side },
            .{ "players", 0xBCC2, s.players, want.players },
            .{ "level index", 0xBCCD, s.level_index, want.level_index },
            .{ "level parameter", 0xBCBD, s.level_param, want.level_param },
            .{ "next-best", 0xBCDD, s.next_best, want.next_best },
        };
        for (fields) |c| if (c[2] != c[3]) return .{ .what = c[0], .addr = c[1], .got = c[2], .want = c[3] };
        return null;
    }
    // Every variable of the captured blocks ($BC83-$BCFF, the board page's
    // off-board columns, $BDF6).
    var addr: u16 = 0xBC83;
    while (addr < 0xBD00) : (addr += 1) {
        if (noiseDependent(addr)) continue;
        const g = s.get(addr) orelse continue;
        const w = want.get(addr).?;
        if (g != w) return .{ .what = "variable", .addr = addr, .got = g, .want = w };
    }
    for (0..8) |row| {
        for (8..16) |col| {
            const a: u16 = @intCast(0xBD00 + row * 16 + col);
            if (noiseDependent(a)) continue;
            const g = s.get(a) orelse continue;
            const w = want.get(a).?;
            if (g != w) return .{ .what = "variable", .addr = a, .got = g, .want = w };
        }
    }
    if (s.threat_ext != want.threat_ext) return .{ .what = "variable", .addr = 0xBDF6, .got = s.threat_ext, .want = want.threat_ext };
    return null;
}

/// Without the search: what ComputerMove does before and around the search
/// that matters to the game layer ($614E-$616C, $6194), then the entry of the
/// recorded move in the regenerated root list.
fn recordedMove(s: *State, index: i64) u32 {
    s.search_flags = 0x40;
    const g = movegen.generate(s, st.root_record);
    scoring.scoreMoves(s, g.header, g.count, &observer.none);
    if (s.next_best == 0) s.exclusion_len = 0;
    s.next_best = 0;
    return st.listAddr(4 + 4 * @as(u32, @intCast(index)));
}

const SessionStats = struct {
    sessions: usize = 0,
    first_go: usize = 0,
    later_go: usize = 0,
    fen_rejected: usize = 0,
    /// FENs the oracle rejects only for missing fields, which the port
    /// accepts (owner decision 2026-10-22, code review CR-07).
    flexible_fen: usize = 0,
    /// Computer moves in positions with 127 or more moves (DEV-001).
    dev001: usize = 0,
    failures: usize = 0,
};

fn runSessions(name: []const u8, stats: *SessionStats) !void {
    const gpa = std.testing.allocator;
    var buf: [1024]u8 = undefined;
    var g = try golden.open(gpa, std.testing.io, try golden.path(&buf, name));
    defer g.deinit();
    const s = try gpa.create(State);
    defer gpa.destroy(s);
    const want = try gpa.create(State);
    defer gpa.destroy(want);

    for (0..g.lines.len) |i| {
        var arena = std.heap.ArenaAllocator.init(gpa);
        defer arena.deinit();
        const a = arena.allocator();
        var p = try g.parse(a, i);
        _ = &p;
        const rec = p.value.object;
        if (rec.get("error") != null) continue;
        const ops = rec.get("session").?.array.items;
        const goes = rec.get("goes").?.array.items;
        try powerOn(s);
        var session: game.Session = .{ .s = s };
        var go_index: usize = 0;
        var failed = false;
        stats.sessions += 1;
        for (ops) |op_v| {
            const op = op_v.object;
            const kind = op.get("op").?.string;
            if (std.mem.eql(u8, kind, "load")) {
                const fen: ?[]const u8 = switch (op.get("fen").?) {
                    .string => |t| t,
                    else => null,
                };
                const moves = try movesOf(a, op.get("moves").?.array);
                session.load(fen, moves) catch |err| {
                    const reason = if (rec.get("rejected")) |r| r.string else "";
                    const fen_err: ?game.FenError = switch (err) {
                        error.MalformedFen, error.CastlingRightWithoutPieces, error.EnPassantInconsistent, error.EnPassantPredecessorRejected, error.DoubleStepRejected, error.PawnOnBackRank, error.NoFreeSlot, error.KingMissing, error.SideNotToMoveInCheck => @errorCast(err),
                        else => null,
                    };
                    if (fen_err != null and reason.len != 0 and reasonMatches(reason, fen_err.?)) {
                        stats.fen_rejected += 1;
                    } else {
                        if (stats.failures < 8) std.debug.print("{s} #{d}: load failed with {t}, golden says '{s}'\n", .{ name, i, err, reason });
                        failed = true;
                    }
                    break;
                };
                if (rec.get("rejected")) |r| {
                    const fields = if (fen) |t| std.mem.count(u8, std.mem.trim(u8, t, " "), " ") + 1 else 6;
                    if (std.mem.startsWith(u8, r.string, "malformed FEN") and fields < 4) {
                        stats.flexible_fen += 1;
                    } else {
                        if (stats.failures < 8) std.debug.print("{s} #{d}: accepted, golden rejected: {s}\n", .{ name, i, r.string });
                        failed = true;
                    }
                    break;
                }
            } else if (std.mem.eql(u8, kind, "continue")) {
                try session.continueWith(try movesOf(a, op.get("moves").?.array));
            } else {
                // go
                const go = goes[go_index].object;
                const out = go.get("out").?.object;
                const result = out.get("result").?.string;
                const level: u8 = @intCast(op.get("level").?.integer);
                const prep = try session.prepareGo(level);
                if (prep) |r| {
                    const ok = switch (r) {
                        .draw => std.mem.eql(u8, result, "draw"),
                        .no_moves => std.mem.eql(u8, result, "nomoves"),
                        else => false,
                    };
                    if (!ok) {
                        if (stats.failures < 8) std.debug.print("{s} #{d} go {d}: main loop gave {t}, golden {s}\n", .{ name, i, go_index, r, result });
                        failed = true;
                    }
                    break;
                }
                // At $6147: compare with the captured state.
                want.* = .{};
                try golden.loadState(want, go.get("state").?.object);
                s.random = want.random;
                // DEV-001: with 127 or more moves the original's list count is
                // wrong, so its root scoring visits fewer moves than the port's
                // and the evaluations' side effects (king-record junk, pins,
                // SEE bytes) differ. Such positions are compared on the game
                // fields only.
                const dev001 = out.get("root").?.array.items.len >= 127;
                if (dev001) stats.dev001 += 1;
                const game_only = (go_index > 0 and !use_search) or dev001;
                if (compareState(s, want, game_only)) |m| {
                    if (stats.failures < 8) std.debug.print("{s} #{d} go {d}: {s} ${x:0>4} got {x} want {x}\n", .{ name, i, go_index, m.what, m.addr, m.got, m.want });
                    failed = true;
                    break;
                }
                if (go_index == 0) stats.first_go += 1 else stats.later_go += 1;
                // The computer's move.
                if (use_search) {
                    const search = @import("search.zig");
                    var r_bytes: [16]u8 = undefined;
                    for (op.get("r").?.array.items, 0..) |v, k| r_bytes[k] = @intCast(v.integer);
                    var sr: st.ScriptedR = .{ .bytes = &r_bytes };
                    var src = sr.source();
                    const outcome = search.computerMove(s, &src, &observer.none, .{});
                    _ = session.finishGo(switch (outcome) {
                        .move => |e| .{ .move = e },
                        .no_moves => .no_moves,
                        .no_mate => .no_mate,
                    });
                } else if (std.mem.eql(u8, result, "move")) {
                    _ = session.finishGo(.{ .move = recordedMove(s, out.get("index").?.integer) });
                } else if (std.mem.eql(u8, result, "nomate")) {
                    _ = session.finishGo(.no_mate);
                } else {
                    _ = session.finishGo(.no_moves);
                }
                go_index += 1;
            }
        }
        if (failed) stats.failures += 1;
    }
}

test "sessions of the search golden file reach the oracle's states" {
    var stats: SessionStats = .{};
    try runSessions("search.jsonl.gz", &stats);
    std.debug.print("search.jsonl.gz: {d} sessions, {d} first computer moves, {d} later, {d} failures\n", .{ stats.sessions, stats.first_go, stats.later_go, stats.failures });
    try std.testing.expectEqual(@as(usize, 0), stats.failures);
}

test "edge positions: FEN loading and the states they lead to" {
    var stats: SessionStats = .{};
    try runSessions("edge.jsonl.gz", &stats);
    std.debug.print("edge.jsonl.gz: {d} sessions, {d} computer moves ({d} DEV-001 positions on game fields only), {d} rejected as recorded, {d} failures\n", .{ stats.sessions, stats.first_go, stats.dev001, stats.fen_rejected, stats.failures });
    try std.testing.expectEqual(@as(usize, 0), stats.failures);
}

test "rejected positions are rejected for the recorded reason" {
    var stats: SessionStats = .{};
    try runSessions("reject.jsonl.gz", &stats);
    std.debug.print("reject.jsonl.gz: {d} sessions, {d} rejected as recorded, {d} accepted by the flexible FEN rule, {d} failures\n", .{ stats.sessions, stats.fen_rejected, stats.flexible_fen, stats.failures });
    try std.testing.expectEqual(@as(usize, 0), stats.failures);
    try std.testing.expectEqual(stats.sessions, stats.fen_rejected + stats.flexible_fen);
}

test "flexible FEN fields (owner decision, code review CR-07)" {
    const accept = [_][]const u8{
        "7k/8/8/8/8/8/8/K7 w",
        "7k/8/8/8/8/8/8/K7 w -",
        "7k/8/8/8/8/8/8/K7 w - -",
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - garbage -9 trailing",
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KKKK - 0 1",
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w qkQK",
    };
    for (accept) |t| {
        const f = try game.Fen.parse(t);
        try std.testing.expect(f.castling_len <= 4);
    }
    const reject = [_][]const u8{ "", "7k/8/8/8/8/8/8/K7", "7k/8/8/8/8/8/8/K7 x", "7k/8/8/8/8/8/8/K6 w", "7k/8/8/8/8/8/8/K7 w KX", "7k/8/8/8/8/8/8/K7 w - z9" };
    for (reject) |t| try std.testing.expectError(error.MalformedFen, game.Fen.parse(t));
}

test "promotion suffixes in move lists (code review CR-09)" {
    const s = try std.testing.allocator.create(State);
    defer std.testing.allocator.destroy(s);
    s.* = .{};
    _ = try game.loadFen(s, "7k/P7/8/8/8/8/8/7K w - - 0 1");
    try std.testing.expectError(error.BadPromotion, game.humanMove(s, try game.Move.parse("a7a8")));
    try std.testing.expectError(error.BadPromotion, game.humanMove(s, try game.Move.parse("h1g1q")));
    _ = try game.humanMove(s, try game.Move.parse("a7a8n"));
}

test "book lines entered move by move reach the oracle's states" {
    var stats: SessionStats = .{};
    try runSessions("book.jsonl.gz", &stats);
    std.debug.print("book.jsonl.gz: {d} sessions, {d} computer moves, {d} failures\n", .{ stats.sessions, stats.first_go, stats.failures });
    try std.testing.expectEqual(@as(usize, 0), stats.failures);
}

test "coordinate notation" {
    try std.testing.expectEqual(@as(u8, 0x74), try game.squareFromName("e1"));
    try std.testing.expectEqual(@as(u8, 0x00), try game.squareFromName("a8"));
    const m = try game.Move.parse("a7a8n");
    try std.testing.expectEqual(@as(u8, 'n'), m.promo);
}
