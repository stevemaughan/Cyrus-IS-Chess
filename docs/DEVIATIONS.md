# Deviations from the original

Every behavioural difference between the Zig port and the original 48K Cyrus IS Chess is listed here (AGENTS.md §2.4, §8). Status is one of:
- **planned**: identified in Phase 1, not yet implemented;
- **implemented**: in the code, with a test;
- **pending decision**: needs the project owner.

## DEV-001: Move-list header count wrong for 127 or more moves
- **Class:** A/B. **Status:** implemented.
- **Confirmed** in `tests/golden/edge.jsonl.gz`:
  - Petrović's 218-move position (`R6R/3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/pp1Q4/kBNN1KB1 w`) gets a count of 90;
  - 138 moves give 10, 147 give 20, 154 give 26, 169 give 41.

  The original searches only the first `count` moves of the list.
- **Original:** `$79AF–$79B8` computes the header count as `((n+1) mod 128) − 1`. For n = 127 the count becomes 255, so callers walk past the terminator into stale entries (possible illegal moves, a hang or memory corruption). For n ≥ 128 the count is too small, so moves are ignored.
- **Trigger:** a position with ≥ 127 pseudo-legal moves, which is easy from FEN with several queens, or deep in a search after promotions.
- **Fix:** store the true count `n` (always < 256).
- **Behaviour change where the original worked:** none (identical for n ≤ 126).
- **Test:** `src/movegen.zig`, "DEV-001: Petrovic's 218-move position gets the true count"; the edge golden sessions (`src/game_tests.zig`).

## DEV-002: Illegal book move 6…Be7
- **Class:** B. **Status:** implemented.
- **Confirmed** in `tests/golden/book.jsonl.gz`: probing that position with fresh random inputs, the original plays `f8e7`. The book's continuation of that line cannot be reached by entering moves, because the original rejects 6…Be7 as a human move.
- **Original:** after 1.e4 e5 2.Nf3 Nf6 3.Nxe5 d6 4.Nf3 Nxe4 5.d4 d5 6.Bb5+, the book's only reply is 6…Be7 (index 14), which leaves Black in check. The original plays it.
- **Fix:** check the chosen book move for legality. If it is illegal, treat the probe as a miss (`$BCDF := $FF`) and search normally.
- **Behaviour change where the original worked:** none. This is the only illegal entry among all 2,685 nodes.
- **Test:** `src/book.zig` (the golden probes reach the illegal 6…Be7 reply).

## DEV-003: Book compares the ply count by its low byte
- **Class:** A/B. **Status:** implemented.
- **Original:** `$7AD8` compares the matched ply counter with `$C001 & $FF`. If the book state `$BCDF` is 0 after 256 or more plies, the probe matches only the first `plies mod 256` moves and plays a reply for a different position. That move may be illegal, or an index past the end of the list.
- **Fix:** compare the full 16-bit ply count.
- **Behaviour change where the original worked:** none.
- **Test:** `src/book.zig`, "DEV-003: the ply count is compared in full".

## DEV-004: Move lookup failure ignored at the root
- **Class:** A. **Status:** implemented (`search.Options.guard_find_move`, on by default; every golden test passes with it on).
- **Original:** `$7CBA` (next-best exclusions) and `$7D00` (repetition pre-selection) use `$7BCD`'s result without checking its "not found" carry. If the move is missing, the from-square of the last root move is zeroed, and `$BD29` may point at a misaligned entry.
- **Trigger:** believed unreachable in normal play; possible only with inconsistent state.
- **Fix:** if the move is not found, skip the action.
- **Behaviour change where the original worked:** none.

## DEV-005: Root legality filter
- **Class:** B. **Status:** implemented.
- **Original:** the move generator is pseudo-legal. The root's static scoring (`$7B96`) gives illegal moves score 0, including castling through an attacked square via the king-on-transit-square trick in make (`$81EA`). This was confirmed in Phase 2 (`docs/OPEN_QUESTIONS.md`, resolved). The only illegal move observed is DEV-002's book move. Any path that still yields an illegal `bestmove` must not reach the GUI.
- **Fix (as built):** `src/legal.zig` is an independent legality test. It agrees with the original's root scoring on all 133,648 root moves of the 4,028 search-golden positions, so a separate root filter would never act. The engine therefore checks `bestmove` and, if it were ever illegal, falls back to the first legal root move in the original's order (`src/engine.zig`). A reported PV is cut at its first illegal move: selective plies can contain illegal replies while in check. Every occurrence found in testing gets its own DEV entry identifying the cause.
- **Behaviour change where the original worked:** none. Phase 4 confirmed it: the fallback never fired in 10,000 self-play games, 4,400 fastchess games or the stress suite (`docs/ROBUSTNESS.md`).

## DEV-006: Random sources
- **Class:** platform adaptation. **Status:** implemented.
- **Original:** the random byte `$BCCE` is stirred by the `R` register (`$60EB`, `$7B89`) and by the time spent waiting for a key (`$675A`). The port has neither.
- **Fix:** at each `go`, set `$BCCE` from a seeded PRNG. Replace each `LD A,R` read with the next PRNG byte. All other uses of `$BCCE`, including the per-evaluation increment and noise, are unchanged. `Seed` makes this reproducible.
- **Behaviour change:** none observable beyond randomness. The original's values are unpredictable anyway.

## DEV-007: `stop` and time limits act as the key press
- **Class:** platform adaptation. **Status:** implemented.
- **Original:** a key press sets `$BD4C` bit 7 at the next node entry (`$78BA`).
- **Fix:** UCI `stop`, an exhausted time budget or `go nodes` sets the same flag at the same point. Everything after that is unchanged.

## DEV-012: A move is returned where the original declares a draw
- **Class:** B (missing move). **Status:** implemented.
- **Original:** the main loop declares DRAWN before Cyrus thinks when the reversal counter `$BD5E` reaches 6, or the 50-move counter `$BD0A` reaches 100 ($60F6). No move is made.
- **Fix:** UCI leaves draw claims to the GUI and requires a `bestmove`, so the engine searches as usual. Its main loop skips the draw declaration entirely (`State.ignore_draw_rules`), so the GUI's later moves are also accepted. Self-play found two games where the GUI played on (no FIDE draw yet) and the engine had rejected the position. The search itself is unchanged: inside the search the original still treats a repetition at the root as a draw (`$7D04`).
- **Behaviour change where the original worked:** none in positions the original would search.

## DEV-013: The next-best exclusion list is bounded
- **Class:** A. **Status:** implemented.
- **Original:** every game move is appended to the list at `$BF00` (unless next-best is in progress), and nothing bounds it. In HUMAN v HUMAN mode it is never cleared, so after 128 plies it runs into `$C000–$C006` (tape marker, ply count, replay target, start position data).
- **Trigger:** the operator script enters `position … moves` in HUMAN v HUMAN mode, so any game longer than 128 plies loaded from scratch.
- **Fix:** the list holds 512 bytes (256 moves), and appending stops when it is full (`src/game.zig`).
- **Behaviour change where the original worked:** none. ComputerMove clears the list before every search (`$6168`), so a search never sees its contents unless a next-best search is in progress.

## DEV-014: Games that would wrap the ply counter are rejected
- **Class:** D. **Status:** implemented.
- **Original:** the ply counter `$C001` is 16 bits and wraps after 65,535 plies. The book and replay then read a wrong ply count.
- **Trigger:** a `position … moves` list, or a game continued with `go`, of 65,535 or more plies. In the port the counter's wrap would also panic in a safety-checked build ([game.zig](../src/game.zig) PlayMove).
- **Fix:** `game.humanMove` refuses a move at `max_plies`, and `go` refuses to search when the pending opponent move and the engine's own would pass it. Both report `info string error: position rejected …`, and `go` answers `bestmove 0000` (`src/game.zig`, `src/engine.zig`).
- **Behaviour change where the original worked:** none. The original cannot hold such a game.
- **Test:** `src/engine.zig`, "rejected positions and no-move positions".

## DEV-015: `searchmoves` is enforced at the output
- **Class:** B (platform adaptation of the N key). **Status:** implemented.
- **Original:** next-best mode (`$BF00` exclusions) has three ways out that are wrong for UCI `searchmoves`:
  - the static best is chosen as the move to play before the exclusions are applied (`$7C49` before `$7CBA`), so a search stopped early plays it;
  - when every move is excluded, NO MORE MOVES clears the list and searches everything (`$7CDF`);
  - the list holds from/to only, so an under-promotion cannot be told from the queen promotion.
- **Fix** (`Engine.SearchMoves`, `src/engine.zig`):
  - **Searchable moves:** a listed move is searchable if it is legal and is not an under-promotion (the original searches queen promotions only). A promotion must carry its suffix.
  - **The search:** every other legal root move is excluded through the original's list, as before.
  - **The output:** if `bestmove` is not listed, the first listed move in the original's root order is played instead, with an `info string`.
  - **Nothing searchable** (owner decision 2026-10-22):
    - nothing listed: no restriction;
    - only illegal moves listed: `bestmove 0000`;
    - only an under-promotion listed: it is played unsearched.
- **Behaviour change where the original worked:** none. The search inside next-best mode is unchanged.
- **Test:** `src/engine.zig`, "searchmoves is enforced on every path".

## DEV-008: Extended mode (any depth, iterative deepening)
- **Class:** E, approved extension (owner, 2026-10-21). **Status:** implemented.
- **Original:** the levels fix the full-width depth at 1–4. Levels 6–8 run a Level-2 pre-pass whose best move is searched first (`$BD6E`, `$FD` marker).
- **Change:** in `Level = UCI`, a pass loop repeats that mechanism at D = 4, 5, 6, … up to `MAX_DEPTH` = 60. Pass 1 is the original Level-2 pass; the switches come from the `Profile` level. Specification: `docs/EXTENDED_SEARCH.md` §3.
- **Behaviour where the original worked:** identical at the anchors (`go depth 1/2/4` = Levels 1/2/6–8). Original mode is unchanged.

## DEV-009: Capacities in extended mode
- **Class:** E. **Status:** implemented.
- **Original:** the per-ply tables, the move-list area (544 entries; when full, the search aborts as if a key were pressed) and the undo stack are sized for ply ≤ 7.
- **Change:** original mode keeps the 544-entry limit and its abort. Extended mode uses per-ply arrays sized `MAX_DEPTH+4` and a 32,768-entry list area. The address-based list-size tests become offset tests (`docs/EXTENDED_SEARCH.md` §2).
- **Behaviour where the original worked:** none. The offset tests are exactly the original tests, and the larger capacity only matters where the original would have aborted.
- **As built:** each `go` sets `State.list_limit` (`src/engine.zig`). Until the code review (CR-02) the extended limit was never selected, so extended searches still aborted when one line's lists passed 544 entries (e.g. depth 6 in `3qk3/8/q6q/8/8/Q6Q/8/3QK3 w`).
- **Tests:** `src/engine.zig`, "extended mode uses the extended move-list area"; the `-Ddeep` test fails on any abort.

## DEV-010: Time management
- **Class:** E. **Status:** implemented.
- **Change:** soft and hard limits from the UCI clock (`docs/EXTENDED_SEARCH.md` §4). Between passes, decide whether to start the next pass; within a pass, abort via DEV-007.

## DEV-011: Search information and pondering
- **Class:** E. **Status:** implemented.
- **Change:**
  - rich UCI `info` output (depth, seldepth, score, nodes, nps, time, PV, currmove/currmovenumber, optional currline/refutation), collected by observing the search at fixed points and never read by it (`docs/EXTENDED_SEARCH.md` §6). This includes a reporting-only triangular PV table updated where the original raises alpha. No MultiPV (owner decision);
  - `bestmove … ponder …`;
  - `go ponder` / `ponderhit`;
  - engine-state checkpoints per game ply, so a diverging `position` (ponder miss, takeback) restores state exactly (AGENTS.md §9.6).
