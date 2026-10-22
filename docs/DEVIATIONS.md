# Deviations from the original

Every behavioural difference between the Zig port and the original 48K Cyrus IS Chess is listed here (AGENTS.md §2.4, §8). Status is one of:
- **planned**: identified in Phase 1, not yet implemented;
- **implemented**: in the code, with a test;
- **pending decision**: needs the project owner.

## DEV-001: Move-list header count wrong for 127 or more moves
- **Class:** A/B. **Status:** planned.
- **Confirmed** in `tests/golden/edge.jsonl.gz`:
  - Petrović's 218-move position (`R6R/3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/pp1Q4/kBNN1KB1 w`) gets a count of 90;
  - 138 moves give 10, 147 give 20, 154 give 26, 169 give 41.

  The original searches only the first `count` moves of the list.
- **Original:** `$79AF–$79B8` computes the header count as `((n+1) mod 128) − 1`. For n = 127 the count becomes 255, so callers walk past the terminator into stale entries (possible illegal moves, a hang or memory corruption). For n ≥ 128 the count is too small, so moves are ignored.
- **Trigger:** a position with ≥ 127 pseudo-legal moves, which is easy from FEN with several queens, or deep in a search after promotions.
- **Fix:** store the true count `n` (always < 256).
- **Behaviour change where the original worked:** none (identical for n ≤ 126).
- **Test:** `tests/deviations/dev001.zig` (to write).

## DEV-002: Illegal book move 6…Be7
- **Class:** B. **Status:** planned.
- **Confirmed** in `tests/golden/book.jsonl.gz`: probing that position with fresh random inputs, the original plays `f8e7`. The book's continuation of that line cannot be reached by entering moves, because the original rejects 6…Be7 as a human move.
- **Original:** after 1.e4 e5 2.Nf3 Nf6 3.Nxe5 d6 4.Nf3 Nxe4 5.d4 d5 6.Bb5+, the book's only reply is 6…Be7 (index 14), which leaves Black in check. The original plays it.
- **Fix:** check the chosen book move for legality. If it is illegal, treat the probe as a miss (`$BCDF := $FF`) and search normally.
- **Behaviour change where the original worked:** none. This is the only illegal entry among all 2,685 nodes.
- **Test:** `tests/deviations/dev002.zig` (to write).

## DEV-003: Book compares the ply count by its low byte
- **Class:** A/B. **Status:** planned.
- **Original:** `$7AD8` compares the matched ply counter with `$C001 & $FF`. If the book state `$BCDF` is 0 after 256 or more plies, the probe matches only the first `plies mod 256` moves and plays a reply for a different position. That move may be illegal, or an index past the end of the list.
- **Fix:** compare the full 16-bit ply count.
- **Behaviour change where the original worked:** none.
- **Test:** `tests/deviations/dev003.zig` (to write).

## DEV-004: Move lookup failure ignored at the root
- **Class:** A. **Status:** planned.
- **Original:** `$7CBA` (next-best exclusions) and `$7D00` (repetition pre-selection) use `$7BCD`'s result without checking its "not found" carry. If the move is missing, the from-square of the last root move is zeroed, and `$BD29` may point at a misaligned entry.
- **Trigger:** believed unreachable in normal play; possible only with inconsistent state.
- **Fix:** if the move is not found, skip the action.
- **Behaviour change where the original worked:** none.

## DEV-005: Root legality filter
- **Class:** B. **Status:** planned.
- **Original:** the move generator is pseudo-legal. The root's static scoring (`$7B96`) gives illegal moves score 0, including castling through an attacked square via the king-on-transit-square trick in make (`$81EA`). This was confirmed in Phase 2 (`docs/OPEN_QUESTIONS.md`, resolved). The only illegal move observed is DEV-002's book move. Any path that still yields an illegal `bestmove` must not reach the GUI.
- **Fix:** AGENTS.md §8.2. Filter the root list with a full legality test before the search, and add a final legality assertion on `bestmove`. Every occurrence found in testing gets its own DEV entry identifying the cause.
- **Behaviour change where the original worked:** none, if the original's own root scoring already rejects every illegal move. This is to be confirmed in Phase 4.

## DEV-006: Random sources
- **Class:** platform adaptation. **Status:** planned.
- **Original:** the random byte `$BCCE` is stirred by the `R` register (`$60EB`, `$7B89`) and by the time spent waiting for a key (`$675A`). The port has neither.
- **Fix:** at each `go`, set `$BCCE` from a seeded PRNG. Replace each `LD A,R` read with the next PRNG byte. All other uses of `$BCCE`, including the per-evaluation increment and noise, are unchanged. `Seed` makes this reproducible.
- **Behaviour change:** none observable beyond randomness. The original's values are unpredictable anyway.

## DEV-007: `stop` and time limits act as the key press
- **Class:** platform adaptation. **Status:** planned.
- **Original:** a key press sets `$BD4C` bit 7 at the next node entry (`$78BA`).
- **Fix:** UCI `stop`, an exhausted time budget or `go nodes` sets the same flag at the same point. Everything after that is unchanged.

## DEV-008: Extended mode (any depth, iterative deepening)
- **Class:** E, approved extension (owner, 2026-10-21). **Status:** planned.
- **Original:** the levels fix the full-width depth at 1–4. Levels 6–8 run a Level-2 pre-pass whose best move is searched first (`$BD6E`, `$FD` marker).
- **Change:** in `Level = UCI`, a pass loop repeats that mechanism at D = 4, 5, 6, … up to `MAX_DEPTH` = 60. Pass 1 is the original Level-2 pass; the switches come from the `Profile` level. Specification: `docs/EXTENDED_SEARCH.md` §3.
- **Behaviour where the original worked:** identical at the anchors (`go depth 1/2/4` = Levels 1/2/6–8). Original mode is unchanged.

## DEV-009: Capacities in extended mode
- **Class:** E. **Status:** planned.
- **Original:** the per-ply tables, the move-list area (544 entries; when full, the search aborts as if a key were pressed) and the undo stack are sized for ply ≤ 7.
- **Change:** original mode keeps the 544-entry limit and its abort. Extended mode uses per-ply arrays sized `MAX_DEPTH+4` and a 32,768-entry list area. The address-based list-size tests become offset tests (`docs/EXTENDED_SEARCH.md` §2).
- **Behaviour where the original worked:** none. The offset tests are exactly the original tests, and the larger capacity only matters where the original would have aborted.

## DEV-010: Time management
- **Class:** E. **Status:** planned.
- **Change:** soft and hard limits from the UCI clock (`docs/EXTENDED_SEARCH.md` §4). Between passes, decide whether to start the next pass; within a pass, abort via DEV-007.

## DEV-011: Reporting PV and pondering
- **Class:** E. **Status:** planned.
- **Change:**
  - a reporting-only triangular PV table, updated where the original raises alpha and never read by the search;
  - `bestmove … ponder …`;
  - `go ponder` / `ponderhit`;
  - engine-state checkpoints per game ply, so a diverging `position` (ponder miss, takeback) restores state exactly (AGENTS.md §9.6).
