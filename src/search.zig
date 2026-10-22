//! Search: port of $7B96-$80A6 and $80A7-$810E (THINK/PASS driver, the ply
//! state machine, forward pruning, the futility cut, extensions, mate,
//! stalemate and repetition handling) plus the computer-move path of the main
//! loop ($6147-$61C1, without the user interface). Static scoring and the
//! move lookup ($7B96, $7BCD) are in scoring.zig.
//! Spec: docs/arch/30-search.md; executable reference:
//! tools/research/search/model.py. Phase 3 units 3.8-3.10.
//!
//! The original is a jump-driven state machine with an explicit ply counter,
//! not recursive code. It is kept that way here (one switch case per original
//! label) because move order, node counts and the effects of stale per-ply
//! data depend on its exact control flow. Per-ply tables have no 7-ply limit
//! (state.ply_slots) so that a driver can run deeper passes
//! (docs/EXTENDED_SEARCH.md §2-3).
//!
//! Values are unsigned bytes: $80 = equal, NEG = negation; 0 in the value
//! table means -infinity, a mated side is 1, the mating side sees $FF.

const std = @import("std");
const st = @import("state.zig");
const State = st.State;
const board = @import("board.zig");
const movegen = @import("movegen.zig");
const eval = @import("eval.zig");
const book = @import("book.zig");
const presearch = @import("presearch.zig");
const scoring = @import("scoring.zig");
const Observer = @import("observer.zig").Observer;

pub const Options = struct {
    /// Book probe behaviour (book.original_options or book.fixed_options:
    /// DEV-002/DEV-003).
    book: book.Options = book.original_options,
    /// DEV-004: when a next-best exclusion or the repetition move is not in
    /// the root list ($7BCD not found), skip the action instead of corrupting
    /// the last root entry.
    guard_find_move: bool = true,
};

/// What the computer-move path ends with.
pub const Outcome = union(enum) {
    /// The entry ($BD29) the original jumps to PlayMove with.
    move: u32,
    /// No legal move ($641A): checkmate or stalemate.
    no_moves,
    /// Problem level without a forced mate (NO MORE FOUND, $61A6).
    no_mate,
};

/// Parameters of one pass when a driver chooses them (docs/EXTENDED_SEARCH.md
/// §3). `a` is the level parameter that selects the switches (threat
/// extensions, forward pruning); `depth` is the full-width depth D. `first`:
/// the pass starts from the static best root move; otherwise the previous
/// pass's move ($BD29) gets score $FD and is searched first, as in the
/// original's second pass.
pub const PassParams = struct {
    a: u8,
    depth: u8,
    first: bool,
};

pub const PassResult = enum { done, book, no_move, no_more_moves };

/// SetPlayers ($7562): after a key press during the search the original
/// leaves demo mode: $BCC2 = 2 if Cyrus plays White ($BCBE = 0), else 1.
fn setPlayers(s: *State) void {
    s.players = if (s.cyrus_side == 0) 2 else 1;
}

/// ComputerMove ($6147-$61C1) without the user interface: generate and
/// score the root moves, detect "no legal move", clear the exclusion list,
/// THINK, then the problem-level check.
pub fn computerMove(s: *State, r: *st.RSource, obs: *const Observer, opts: Options) Outcome {
    // $614E: bit 6 = the computer is moving (promotions are to a queen).
    s.search_flags = 0x40;
    // $6153: generate and score the root moves (IX = root record).
    const g = movegen.generate(s, st.root_record);
    obs.rootGenerated(s, g.header, g.count);
    scoring.scoreMoves(s, g.header, g.count, obs);
    obs.rootScored(s, g.header, g.count);
    // $615D: best score 0: no legal move.
    if (s.best_static == 0) return .no_moves;
    // $6168: unless a next-best search is in progress, clear the exclusion list.
    if (s.next_best == 0) s.exclusion_len = 0;
    var search: Search = .{ .s = s, .r = r, .obs = obs, .opts = opts };
    search.think();
    // $6194: the next-best request is complete.
    s.next_best = 0;
    // $6198: problem levels play the move only if a mate was found.
    if (s.level_index >= 8 and s.value[1] < 0xFE) return .no_mate;
    return .{ .move = s.move_to_play };
}

/// The labels of the search state machine ($7D43-$810E).
const Label = enum {
    node, // $7D43
    node_eval, // $7D77
    next_move, // $7DA8
    play_best, // $7DCF
    next_scored, // $7DDA
    descend, // $7DEB
    descend_made, // $7DEE
    descend_ply, // $7E0A
    ret, // $7E25
    backup, // $7E49
    killer, // $7E5F
    fail_high, // $7E79
    root_best, // $7E95
    root_best_set, // $7E9B
    root_mate, // $7EA1
    ext_lists, // $7EB6
    ext_deep, // $7ED3
    q_undo, // $7EDE
    q_next, // $7EE4
    q_eval, // $7F20
    q_ext_chk, // $7F27
    q_ext1, // $7F39
    q_ext_cmp, // $7F3E
    q_leaf, // $7F43
    q_best, // $7F5B
    q_fail_high, // $7F81
    q_threat, // $7FAD
    no_moves, // $7FEA
    recapture, // $802B
    check_best, // $80E2
    check_next, // $80ED
    check_descend, // $80FA
    exit, // RET to $7BE4
};

pub const Search = struct {
    s: *State,
    r: *st.RSource,
    obs: *const Observer,
    opts: Options,

    /// Undo frames of the made moves (the original keeps them on the stack).
    undo: [st.ply_slots + 2]board.Undo = undefined,
    sp: usize = 0,

    /// IX: the move entry being handled.
    ix: u32 = 0,
    /// C: the evaluation of the move just made (selective plies: +1 later).
    c: u8 = 0,
    /// Header address of the full-width node's list (from $8006 at $7DA8).
    hdr: u32 = 0,
    /// E: number of moves generated at the node ($7D43).
    count: u8 = 0,
    /// A: the value handed to $7E49 / the ply handed to $7E5F / the limit for $7F3E.
    acc: u8 = 0,
    /// L at $7E49: index of V(p+1) in the value table.
    vi: usize = 0,
    /// L at $7F5B: index of V(p) (alpha) in the value table.
    alpha_i: usize = 0,

    // ------------------------------------------------------------ primitives
    fn make(se: *Search, entry: u32) void {
        const e = se.s.entry(entry);
        se.obs.make(se.s.ply, e[1], e[2]);
        board.make(se.s, entry, &se.undo[se.sp]);
        se.sp += 1;
    }

    fn unmake(se: *Search) void {
        se.sp -= 1;
        board.unmake(se.s, &se.undo[se.sp]);
    }

    fn evaluate(se: *Search, entry: u32) u8 {
        se.obs.evaluated();
        return eval.evaluate(se.s, entry).a;
    }

    fn flipSide(se: *Search) void {
        se.s.side_phase ^= 1;
    }

    /// The byte +n of the header of the list at `hdr`.
    fn hdrByte(se: *Search, hdr: u32, n: usize) *u8 {
        return &se.s.entry(hdr)[n];
    }

    /// The address of entry number `k` (0-based) of the list at `hdr`.
    fn entryAt(hdr: u32, k: u32) u32 {
        return st.listAddr(st.listOffset(hdr) + 4 + 4 * k);
    }

    /// The high byte of a list address as the original compares it with $B4
    /// ($7F20, $7EB6). Extended-mode addresses ($10000+) are never in page $B4.
    fn page(addr: u32) u8 {
        return if (addr >= 0x10000) 0 else @truncate(addr >> 8);
    }

    // --------------------------------------------------------------- helpers
    /// PICKBEST ($8015): the first entry with the strictly highest score,
    /// scanning until a score of $FF (the next list's header, or an unscored
    /// entry). Scores of 0 are never picked. Null if every score is 0.
    fn pickBest(se: *Search, hdr: u32) ?u32 {
        var best: u8 = 0;
        var found: ?u32 = null;
        var a = hdr;
        while (true) {
            a = scoring.nextEntry(a);
            const score = se.s.entry(a)[0];
            if (best >= score) continue;
            best = score;
            if (best == 0xFF) return found;
            found = a;
        }
    }

    /// FUTILITY / HORIZON_CUT ($80C4) at a node whose ply equals the depth:
    /// true if the original unmakes and fails high (via $7E79).
    fn futility(se: *Search, p: u8) bool {
        const s = se.s;
        if (p & 1 != 0) return false;
        const x = s.prune_margin;
        if (x & 0x80 != 0) return false;
        if (x >= se.c) return false; // SUB C: no borrow
        const y = x -% se.c;
        if (y >= s.value[p - 1]) return false; // CP ($BC9E + p)
        if (se.hdrByte(s.slot[s.ply], 3).* & 0x01 != 0) return false;
        return true;
    }

    /// PRUNE ($805F): forward-prune weak moves of the current ply's list after
    /// static scoring. Threshold = max(best, header byte +2) - 9; a move below
    /// it gets score 0 (never searched) according to one of three tests,
    /// unless its flags AND $C9 is non-zero. Returns D: 2 x count minus the
    /// moves that reached the lenient test (meaningful at plies 1-2 only).
    fn prune(se: *Search, best: u8) u8 {
        const s = se.s;
        if (s.prune_margin & 0x80 != 0) return 0;
        const p = s.ply;
        const hdr = s.slot[p];
        const e = se.hdrByte(hdr, 1).*;
        const c = se.hdrByte(hdr, 2).*;
        const Test = enum { default, lenient, strict };
        var t: Test = .default;
        var d: u8 = 0;
        var phase: u8 = undefined;
        if (p >= 3) {
            phase = s.side_phase;
        } else {
            d = e *% 2;
            phase = 0x10;
        }
        if (phase & 0x10 != 0) t = .lenient; // $807F: IY = $80BB
        if (phase & 0x08 != 0) t = .strict; // $8087: IY = $80A7
        var a = best;
        if (a < c) a = c;
        if (a < 9) return d;
        const thr = a - 9;
        var n: u16 = if (e == 0) 256 else e;
        var k: u32 = 0;
        while (n > 0) : ({
            n -= 1;
            k += 1;
        }) {
            const entry = se.s.entry(entryAt(hdr, k));
            if (entry[0] >= thr) continue;
            var x = entry[0] -% thr; // negative
            var strict_step = false;
            var zero_step = false;
            switch (t) {
                // $80A2: more than 16 below: prune; otherwise the bit-2 test.
                .default => {
                    x +%= 0x10;
                    if (x & 0x80 != 0) zero_step = true else strict_step = true;
                },
                // $80BB: D - 1; within 16: keep; otherwise the bit-2 test.
                .lenient => {
                    d -%= 1;
                    x +%= 0x10;
                    if (x & 0x80 != 0) strict_step = true;
                },
                // $80A7: the bit-2 test.
                .strict => strict_step = true,
            }
            if (strict_step and entry[3] & 0x04 != 0) zero_step = true;
            // $80AB: keep checks, threats, captures and pawns to the 6th/7th.
            if (zero_step and entry[3] & 0xC9 == 0) entry[0] = 0;
        }
        return d;
    }

    // --------------------------------------------------------- THINK / PASS
    /// THINK ($7BE1): pre-search set-up, then passes while a second pass is
    /// pending. NO MORE MOVES restarts THINK ($7CFD). Original mode; an
    /// extended driver calls presearch.preSearch (counting one evaluation)
    /// and `pass` with explicit PassParams itself.
    pub fn think(se: *Search) void {
        while (true) {
            se.obs.evaluated(); // $7810 calls the evaluation once
            _ = presearch.preSearch(se.s);
            while (true) {
                switch (se.pass(null)) {
                    .no_move, .book => return,
                    .no_more_moves => break,
                    .done => {},
                }
                if (se.s.second_pass == 0) return;
            }
        }
    }

    /// PASS ($7BF1): one search pass from the root. `params` null: the
    /// original's level logic ($7C2A-$7C82); otherwise the driver's.
    pub fn pass(se: *Search, params: ?PassParams) PassResult {
        const s = se.s;
        // $7BF5: killers off, shortest mate none, material delta 0, values 0.
        for (s.killer[1..]) |*k| k[0] = 0xFF;
        for (s.killer[1..7]) |*k| k[1] = 0xFF; // $BC91-$BC9D (13 bytes)
        s.best_mate_ply = 0xFF;
        s.material_delta = 0;
        @memset(&s.value, 0);
        // $7C10: generate and statically score the root moves.
        const g = movegen.generate(s, st.root_record);
        const root_hdr = g.header - 3;
        se.hdrByte(root_hdr, 3).* |= 0x20;
        scoring.scoreMoves(s, g.header, g.count, se.obs);
        // $7C18: the opening book, unless in next-best mode.
        if (s.next_best == 0) {
            if (book.probeWith(s, se.r, se.opts.book)) |e| {
                // $7C23 polls the keyboard once more; a key only leaves demo
                // mode. Not modelled (DEV-007: stop acts at node entries).
                se.obs.bookMove(s, e);
                se.obs.passDone(s);
                return .book;
            }
        }
        // $7C2A: no legal root move.
        if (s.best_static == 0) return .no_move;
        const d = s.best_static;
        var a: u8 = undefined;
        if (params) |pp| {
            if (!pp.first) {
                const h = s.move_to_play;
                s.entry(h)[0] = 0xFD;
                s.best_static_entry = h;
            } else {
                s.move_to_play = s.best_static_entry;
            }
            a = pp.a;
        } else if (s.second_pass != 0) {
            // $7C38: second pass: the first pass's move is searched first.
            const h = s.move_to_play;
            s.entry(h)[0] = 0xFD;
            s.best_static_entry = h;
            s.second_pass = 0;
            a = s.level_param;
        } else {
            // $7C49: first pass: the static best is the move to play so far.
            s.move_to_play = s.best_static_entry;
            a = s.level_param;
            if (a >= 5) {
                a = 1;
                s.second_pass = 1;
            }
        }
        // $7C5B: switches from the parameter.
        s.threat_ext = 0;
        s.prune_margin = a;
        if (a & 0x02 != 0) {
            s.threat_ext = a;
            if (a & 0x01 != 0) s.prune_margin |= 0x80;
        }
        // $7C71: full-width depth.
        s.depth = if (params) |pp| pp.depth else if (a == 0) 1 else if (a < 4) 2 else if (a == 4) 3 else 4;
        se.obs.passStart(s, s.depth, a);
        // $7C83: the forward-pruning margin.
        if (s.prune_margin & 0x80 == 0) {
            var b: u8 = 7;
            if (se.hdrByte(root_hdr, 3).* & 0x80 == 0) {
                var dd = se.prune(d);
                dd = ((dd >> 2) -% 1) >> 1;
                const f = s.side_phase;
                if (f & 0x10 != 0) {
                    b = 11;
                } else {
                    b = 10;
                    const sra: u8 = @bitCast(@as(i8, @bitCast(f)) >> 1);
                    if (sra -% 1 == 0) b = 8;
                }
                while (true) {
                    dd -%= 1;
                    if (dd & 0x80 != 0) break;
                    b -%= 1;
                    if (b == 0) break;
                }
            }
            s.prune_margin = b + 2;
        }
        // $7CBA: next-best exclusions get score 0.
        var i: usize = 0;
        while (i + 1 < s.exclusion_len) : (i += 2) {
            var last: u32 = 0;
            if (scoring.findMove(s, root_hdr + 2, se.hdrByte(root_hdr, 1).*, s.exclusion[i], s.exclusion[i + 1], &last)) |e| {
                s.entry(e)[0] = 0;
            } else if (!se.opts.guard_find_move) {
                // Original (DEV-004): HL = byte +2 of the last entry tested;
                // DEC L; LD (HL),0 zeroes that entry's from-square.
                s.entry(last - 2)[1] = 0;
            }
        }
        // $7CD5: the first root move to search.
        const first = se.pickBest(root_hdr) orelse {
            // $7CDF: NO MORE MOVES: clear the list and think again.
            s.exclusion_len = 0;
            return .no_more_moves;
        };
        s.best_static_entry = first;
        // $7D04: repetition: the move that undoes our last move.
        const c = s.reversals;
        if (c >= 2) {
            var last: u32 = 0;
            const found = scoring.findMove(s, root_hdr + 2, se.hdrByte(root_hdr, 1).*, s.prev_to, s.prev_from, &last);
            var h: u32 = undefined;
            var ok = true;
            if (found) |e| {
                h = e;
            } else if (se.opts.guard_find_move) {
                ok = false;
            } else {
                // Original (DEV-004): HL = byte +1 of the last entry tested.
                h = last - 1;
            }
            if (ok and s.lists[st.listOffset(h)] != 0) {
                s.lists[st.listOffset(h)] = 0;
                var v = s.material_term;
                if (s.side_phase & 1 != 0) v = 0 -% v;
                v +%= 0x7E;
                if (c & 0x04 != 0) v -%= 8;
                s.value[1] = v;
                s.root_move = h;
                se.run(.root_best_set);
                se.obs.passDone(s);
                return .done;
            }
        }
        se.run(.play_best);
        se.obs.passDone(s);
        return .done;
    }

    // ------------------------------------------------------- state machine
    /// The search loop from `start` until the pass ends (RET to $7BE4).
    fn run(se: *Search, start: Label) void {
        const s = se.s;
        sm: switch (start) {
            // $7D43: new node: key poll ($78BA), generate, then the recapture
            // or the killer first.
            .node => {
                const key = se.obs.node(s);
                if (s.search_flags & 0x80 == 0 and key) {
                    s.search_flags |= 0x80;
                    setPlayers(s);
                }
                const g = movegen.generate(s, se.ix);
                if (g.count == 0) continue :sm .next_move;
                se.count = g.count;
                if (s.entry(se.ix)[3] & 0x04 != 0) continue :sm .recapture;
                if (se.hdrByte(g.header - 3, 3).* & 0x80 != 0) continue :sm .next_move; // in check
                const k = s.killer[s.ply];
                if (k[0] & 0x80 != 0) continue :sm .next_move;
                const e = scoring.findMove(s, g.header - 1, g.count, k[0], k[1], null) orelse continue :sm .next_move;
                s.entry(e)[0] = 0;
                se.ix = e;
                se.make(e);
                continue :sm .node_eval;
            },
            // $7D77: evaluate the killer (or recapture) just made.
            .node_eval => {
                const a = se.evaluate(se.ix);
                if (a == 0) {
                    se.unmake();
                    continue :sm .next_move;
                }
                se.c = a;
                const d = s.depth;
                const p = s.ply;
                if (d < p) continue :sm .q_eval;
                if (d == p and se.futility(d)) {
                    se.unmake();
                    continue :sm .fail_high;
                }
                const hdr = s.slot[p];
                se.hdrByte(hdr, 3).* |= 0x40; // killer searched
                se.hdrByte(hdr, 2).* = a; // its evaluation
                const fl = s.entry(se.ix)[3];
                if (fl & 0x02 == 0 or fl & 0x08 != 0) continue :sm .descend_made;
                // A quiet threat is given its evaluation and ordered later.
                s.entry(se.ix)[0] = a;
                se.unmake();
                continue :sm .next_move;
            },
            // $7DA8: choose the next move at the current node.
            .next_move => {
                if (s.depth < s.ply) continue :sm .q_next;
                se.hdr = s.slot[s.ply];
                const flags = se.hdrByte(se.hdr, 3);
                if (flags.* & 0x20 != 0) continue :sm .next_scored;
                flags.* |= 0x20;
                scoring.scoreMoves(s, se.hdr + 3, se.hdrByte(se.hdr, 1).*, se.obs);
                if (s.best_static == 0) continue :sm .no_moves;
                if (flags.* & 0x80 != 0) continue :sm .check_best;
                _ = se.prune(s.best_static);
                continue :sm .play_best;
            },
            // $7DCF: search the static best.
            .play_best => {
                se.ix = s.best_static_entry;
                s.entry(se.ix)[0] = 0;
                continue :sm .descend;
            },
            // $7DDA: the highest-scored remaining move.
            .next_scored => {
                if (se.hdrByte(se.hdr, 3).* & 0x80 != 0) continue :sm .check_next;
                const e = se.pickBest(se.hdr) orelse continue :sm .ret;
                se.ix = e;
                s.entry(e)[0] = 0;
                continue :sm .descend;
            },
            // $7DEB: make the move.
            .descend => {
                se.make(se.ix);
                continue :sm .descend_made;
            },
            // $7DEE: record the move ($BD2B at the root, curmove(p) below).
            .descend_made => {
                const p = s.ply;
                if (p == 1) {
                    s.root_move = se.ix;
                    se.obs.rootMove(s, se.ix);
                } else {
                    const e = s.entry(se.ix);
                    s.curmove[p] = .{ e[1], e[2] };
                }
                continue :sm .descend_ply;
            },
            // $7E0A: descend: flip the side, p + 1, the child's alpha V(p+1) = V(p-1).
            .descend_ply => {
                se.flipSide();
                const p = s.ply;
                std.debug.assert(p + 2 < st.ply_slots);
                s.ply = p + 1;
                s.value[p + 1] = s.value[p - 1];
                continue :sm .node;
            },
            // $7E25: return to the parent (unwind completely after an abort).
            .ret => {
                while (true) {
                    const a = s.ply - 1;
                    if (a == 0) continue :sm .exit;
                    s.ply = a;
                    se.unmake();
                    se.flipSide();
                    if (s.search_flags & 0x80 == 0) break;
                }
                const p = s.ply;
                se.acc = 0 -% s.value[p + 1];
                se.vi = p + 1;
                continue :sm .backup;
            },
            // $7E49: compare the value with beta V(p-1) and alpha V(p).
            .backup => {
                const a = se.acc;
                // CPL; CP (HL): ~value below beta's complement = value >= beta.
                if ((a ^ 0xFF) < s.value[se.vi - 2]) continue :sm .fail_high;
                const ai = se.vi - 1;
                if (a <= s.value[ai]) continue :sm .next_move;
                s.value[ai] = a;
                const p = s.ply;
                if (p == 1) {
                    const e = s.entry(s.root_move);
                    se.obs.alpha(s, 1, e[1], e[2]);
                } else {
                    se.obs.alpha(s, p, s.curmove[p][0], s.curmove[p][1]);
                }
                const q = p - 1;
                if (q == 0) continue :sm .root_best;
                se.acc = q;
                continue :sm .killer;
            },
            // $7E5F: the move at ply acc+1 becomes its killer (unless flagged).
            .killer => {
                const q = @as(usize, se.acc) + 1;
                if (s.curmove[q][0] & 0x80 != 0) continue :sm .next_move;
                s.killer[q] = s.curmove[q];
                continue :sm .next_move;
            },
            // $7E79: fail high: unmake the move that led here, back to the parent.
            .fail_high => {
                se.obs.cutoff(s, s.ply);
                se.unmake();
                s.ply -= 1;
                se.flipSide();
                se.acc = s.ply;
                continue :sm .killer;
            },
            // $7E95: a new root alpha: forced mate?
            .root_best => {
                if (s.value[1] +% 1 != 0) continue :sm .root_best_set;
                continue :sm .root_mate;
            },
            // $7E9B / $7E8C: the root move becomes the move to play.
            .root_best_set => {
                s.move_to_play = s.root_move;
                se.obs.newBest(s, s.move_to_play);
                continue :sm .next_move;
            },
            // $7EA1: a mate: prefer the shortest; mate in one ends the pass.
            .root_mate => {
                s.value[1] = 0xFE;
                const m = s.mate_ply;
                if (m == 2) {
                    s.move_to_play = s.root_move;
                    se.obs.newBest(s, s.move_to_play);
                    continue :sm .exit;
                }
                if (m >= s.best_mate_ply) continue :sm .next_move;
                s.best_mate_ply = m;
                continue :sm .root_best_set;
            },
            // $7EB6: small-list extensions (slot addresses may be stale).
            .ext_lists => {
                if (page(s.slot[6]) == 0xB4) continue :sm .ext_deep;
                const d = s.depth;
                if (d < 3) continue :sm .q_ext_chk;
                if (@as(u8, @truncate(s.slot[5])) >= 0x58) continue :sm .q_ext_chk;
                se.acc = d;
                continue :sm .q_ext_cmp;
            },
            // $7ED3
            .ext_deep => {
                const d = s.depth;
                if (d < 3) continue :sm .q_ext_chk;
                se.acc = d +% 1;
                continue :sm .q_ext_cmp;
            },
            // $7EDE: unmake the previous selective move.
            .q_undo => {
                se.unmake();
                continue :sm .q_next;
            },
            // $7EE4: selective node: the next move in generation order.
            .q_next => {
                while (true) {
                    const p = s.ply;
                    // $7EE8: $BD4E = the slot's low address byte, never 0.
                    s.sel_marker = @truncate(0xA9 + 2 * @as(u32, p));
                    const hdr = s.slot[p];
                    const h = s.entry(hdr);
                    const tried = h[2];
                    if (h[1] == tried) continue :sm .ret;
                    h[2] = tried +% 1;
                    s.sel_flags = h[3];
                    const e = entryAt(hdr, tried);
                    const sc = &s.entry(e)[0];
                    sc.* +%= 1; // $FF becomes 0: taken
                    if (sc.* != 0) continue; // already scored or searched
                    se.ix = e;
                    se.make(e);
                    const a = se.evaluate(e);
                    se.c = a;
                    if (a != 0) continue :sm .q_eval;
                    // Illegal: while in check it counts as value 2 (C = 1 + 1).
                    se.c = 1;
                    if (s.sel_flags & 0x80 != 0) continue :sm .q_leaf;
                    se.unmake();
                }
            },
            // $7F20: small lists along this line?
            .q_eval => {
                if (page(s.slot[4]) == 0xB4) continue :sm .ext_lists;
                continue :sm .q_ext_chk;
            },
            // $7F27: check extension unless the evaluation cleared $BD4E.
            .q_ext_chk => {
                if (s.sel_marker == 0) continue :sm .q_ext1;
                const f = s.entry(se.ix)[3];
                if (f & 0x80 == 0 or f & 0x04 != 0) continue :sm .q_leaf;
                continue :sm .q_ext1;
            },
            // $7F39
            .q_ext1 => {
                se.acc = s.depth;
                continue :sm .q_ext_cmp;
            },
            // $7F3E: extend if p <= limit + 1.
            .q_ext_cmp => {
                if (se.acc +% 1 >= s.ply) continue :sm .descend_made;
                continue :sm .q_leaf;
            },
            // $7F43: back up the static value (evaluation + 1).
            .q_leaf => {
                const p = s.ply;
                se.c +%= 1;
                if ((se.c ^ 0xFF) < s.value[p - 1]) continue :sm .q_fail_high;
                se.alpha_i = p;
                if (s.entry(se.ix)[3] & 0x42 != 0) continue :sm .q_threat;
                continue :sm .q_best;
            },
            // $7F5B: raise alpha; the move becomes the killer.
            .q_best => {
                if (se.c <= s.value[se.alpha_i]) continue :sm .q_undo;
                s.value[se.alpha_i] = se.c;
                const e = s.entry(se.ix);
                se.obs.alpha(s, s.ply, e[1], e[2]);
                if (s.sel_flags & 0x80 != 0) continue :sm .q_undo;
                s.killer[s.ply] = .{ e[1], e[2] };
                continue :sm .q_undo;
            },
            // $7F81: fail high at a selective node.
            .q_fail_high => {
                se.obs.cutoff(s, s.ply);
                se.unmake();
                se.unmake();
                se.flipSide();
                s.ply -= 1;
                if (s.sel_flags & 0x80 != 0) continue :sm .next_move;
                const e = s.entry(se.ix);
                s.killer[@as(usize, s.ply) + 1] = .{ e[1], e[2] };
                continue :sm .next_move;
            },
            // $7FAD: threat extension.
            .q_threat => {
                const p = s.ply;
                const limit = s.depth +% 2;
                if (limit < p) continue :sm .q_best;
                var v: u16 = se.c;
                if (limit != p) {
                    v += 1;
                    if (v > 0xFF) continue :sm .q_best;
                }
                if (v < s.value[se.alpha_i]) continue :sm .q_undo;
                if (s.threat_ext == 0) continue :sm .q_best;
                if (se.c == 2) continue :sm .q_best;
                continue :sm .descend_made;
            },
            // $7FEA: no legal move at a full-width node.
            .no_moves => {
                const flags = se.hdrByte(se.hdr, 3).*;
                if (flags & 0x40 != 0) continue :sm .ret; // the killer was legal
                const p = s.ply;
                if (flags & 0x80 == 0) {
                    // $7FD2: stalemate: +-$BD2E + $78.
                    var v = s.material_term;
                    if (s.side_phase & 1 != 0) v = 0 -% v;
                    se.acc = v +% 0x78;
                } else {
                    // $7FF3: mated: value 1; record the ply.
                    s.mate_ply = p;
                    se.acc = 1;
                }
                se.vi = @as(usize, p) + 1;
                continue :sm .backup;
            },
            // $802B: the recapture on the opponent's to-square first.
            .recapture => {
                const p = s.ply;
                const end = s.slot[@as(usize, p) + 1];
                const to = s.entry(se.ix)[2];
                var off = st.listOffset(end);
                var n: u16 = if (se.count == 0) 256 else se.count;
                const e: u32 = while (n > 0) : (n -= 1) {
                    off -= 4;
                    if (s.lists[off + 2] == to) break st.listAddr(off);
                } else continue :sm .next_move;
                s.entry(e)[0] = 0;
                se.ix = e;
                se.make(e);
                s.entry(e)[1] |= 0x80; // never matches as a killer
                s.sel_flags = 0x80;
                continue :sm .node_eval;
            },
            // $80E2: in check: the static best, not recorded as a killer.
            .check_best => {
                se.ix = s.best_static_entry;
                s.entry(se.ix)[0] = 0;
                continue :sm .check_descend;
            },
            // $80ED
            .check_next => {
                const e = se.pickBest(se.hdr) orelse continue :sm .ret;
                se.ix = e;
                s.entry(e)[0] = 0;
                continue :sm .check_descend;
            },
            // $80FA
            .check_descend => {
                se.make(se.ix);
                const p = s.ply;
                if (p == 1) {
                    s.root_move = se.ix;
                    se.obs.rootMove(s, se.ix);
                } else {
                    s.curmove[p][0] |= 0x80;
                }
                continue :sm .descend_ply;
            },
            .exit => return,
        }
    }
};
