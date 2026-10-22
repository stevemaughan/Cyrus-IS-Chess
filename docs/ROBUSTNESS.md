# Robustness audit (Phase 4)

AGENTS.md §6 Phase 4: no crashes, hangs, illegal moves or safety panics. This report records what was checked, what was found and what was fixed. Every fix has a DEV entry in `docs/DEVIATIONS.md` and a test.

## 1. Summary

| Check | Result |
|---|---|
| Perft, 126 positions (`cyrus perftsuite`) | 3,732,770,300 leaves, 0 differences |
| Self-play, 10,000 games, ReleaseSafe | 941,836 plies, 0 failures (after the fixes in §3.1) |
| fastchess, ReleaseSafe, UHO openings | 4,400 games at 0.5+0, 1+0.01 and 10+0.1: 0 time losses, illegal moves or disconnects (after the fixes in §7) |
| UCI stress (`tools/scripts/uci_stress.py`), ReleaseSafe | 0 failures |
| UCI smoke (`tools/scripts/uci_smoke.py`) | 41/41 |
| Unit and golden tests (`zig build test`, `test-engine`, `test-perft`) | all pass |

## 2. Move generation: perft

`cyrus perft <depth> <fen>` and `cyrus perftsuite <epd> [max-nodes]` (`src/perft.zig`) count leaves with the ported move generator and make/unmake. Illegal moves are filtered by `src/legal.zig`, because the original's generator is pseudo-legal. The suite is the 126-position EPD from the Chess Engine Benchmark (`resources/perft/perft.epd`): the start position, "Kiwipete", the castling-rights positions and the rest of the standard set, with counts to depth 6.

**Result:** every depth run matches: 3,732,770,300 leaves, 0 differences. Each position ran every listed depth up to the `max-nodes` cap.

**Finding during the run:** a perft-only harness bug, not an engine bug. The original's make uses the move's score byte as a transit marker for castling (`$81EA`: the king passes through the transit square with score `$FF`). Perft reused list entries without resetting the score, so a stale `$FF` made later makes misbehave. `perft.child` now zeroes the score before make, as the root's static scoring does. Under-promotions are perft-only too: the original only promotes to a queen in search, so `child` overrides the type byte (`$05`, `$03`, `$83`) as `ChoosePromotion` does for a human.

This also settles OPEN_QUESTIONS #1, already resolved in Phase 2: castling through an attacked square is generated pseudo-legally and rejected by the root's static scoring. The DEV-005 legality test agrees with the original's root scoring on all 133,648 root moves of the search golden positions.

## 3. Self-play

`tools/scripts/selfplay.py` plays games between two engine processes, with python-chess as referee. Each side draws a random configuration:
- **Limit:** UCI clock (0.5–5 s + 0–100 ms, ponder on in 30% of clock games), `movetime` (10–100 ms), `depth` 1–6, `nodes` (500 to 200,000), or an original Level 1–8;
- **Profile:** Level 6, 7 or 8;
- **OwnBook:** on or off;
- **Seed:** random.

Openings are 0–8 random legal moves, and games stop at 300 plies. Every move goes through `position … moves`, so continuations, ponder hits and misses (checkpoint restores) are exercised.

The following count as failures:
- a crash;
- an engine error;
- a hang (30 s without an answer);
- `bestmove 0000` or an illegal move while legal moves exist;
- a time loss;
- an `info string` reporting the DEV-005 legality fallback or an error. A move that is legal only because the fallback replaced the search's choice is still a bug.

### 3.1 First run (before the fixes)

There were 10,000 games and 968,799 plies, with no crashes or hangs. The failures:

| Failure | Count | Cause | Fix |
|---|---|---|---|
| `bestmove 0000` with legal moves | 2 | The original's main loop declares DRAWN when the reversal counter reaches 6 or the 50-move counter reaches 100. After the GUI played on, the engine rejected the position. | DEV-012: the engine's game skips the draw declaration (`State.ignore_draw_rules`). |
| Time loss | 370 | Only at increments of 0 or 10 ms. The budget's hard limit was floored at 1 ms, and the clock was read every 1,024 node entries. Some moves came back with 1–22 ms left, which the harness's own latency then exceeded. | `timeman.budget` gives `hard = 0` (move now) when `min(5·soft, t/3)` does not exceed the move overhead. The clock is read at the first node entry and every 64 after it (`docs/EXTENDED_SEARCH.md` §4). |

Time losses by configuration (base + increment, in ms):

| Clock | Losses / games |
|---|---|
| 500 + 0 | 83/338 (63/146 with ponder) |
| 1000 + 0 | 63/341 (42/135 with ponder) |
| 2000 + 0 | 30/318 |
| 5000 + 0 | 8/320 |
| 500 + 10 | 18/360 |
| 1000 + 10 | 10/351 |
| 2000 + 10 | 14/357 |
| 5000 + 10 | 0 |
| any + 50 or 100 | 0 |

### 3.2 Second run (after the fixes)

10,000 games (seeds 1,000,000–1,009,999) and 941,836 plies, with 0 failures of any kind:
- no crashes, hangs or engine errors;
- no `bestmove 0000` with legal moves, and no illegal moves;
- no DEV-005 fallbacks or error reports;
- no time losses.

Results: 3,879 White wins, 3,921 Black wins and 2,200 draws.

Coverage by side:

| Limit | Sides |
|---|---|
| UCI clock | 7,629 (1,894 with no increment, 2,219 pondering) |
| `depth` | 3,142 |
| `nodes` | 3,112 |
| `movetime` | 3,083 |
| original levels | 3,034 (Levels 1–8, 365–397 each) |

4,034 sides played with OwnBook off.

## 4. UCI stress

`tools/scripts/uci_stress.py` drives one ReleaseSafe process through:
- malformed and hostile input: truncated commands, unknown options, out-of-range values, a byte-order mark, a 200,000-byte line and 200 random lines;
- rejected positions (`bestmove 0000` plus `info string`);
- games of 300, 600 and 1,200 plies through `position startpos moves`;
- Petrović's 218-move position and a 9-queen position at `UCI`, Level 1, 4 and 8, and P1 and P3;
- 20 × `go infinite` with an immediate `stop`, `isready` during a search, ponder with `ponderhit` and with `stop`, and `wtime` of 1, 5, 10 and 30 ms (each answered in under a second);
- `searchmoves` with one move and with every move;
- P2 (Morphy's mate in 2 and NO MATE FOUND);
- `go infinite` for 20 s each from three positions.

**Result:** 0 failures. It found and fixed three UCI-layer bugs:
- **Commands aborted searches:** piped commands arriving during a search aborted it. Commands now wait for a running search unless it is `infinite` or `ponder` (`uci.settle`).
- **Hang on a long line:** a line longer than the input buffer hung the reader. The line is now discarded and reported (`uci.zig`).
- **Repeated `go`:** a repeated `go` without a new `position` searched the position after the engine's own last move. The engine now restores the position the GUI set (`Engine.goBaseline`).

## 5. Capacities

| Structure | Original | Port | Bounded by |
|---|---|---|---|
| Move list header count | `((n+1) mod 128) − 1` | the true count n (DEV-001) | n < 256 for any position the set-up accepts (tested up to Petrović's 218) |
| Move-list area | 544 entries; full = abort as a key press | original mode: the same 544 and abort; extended mode: 32,768 entries (DEV-009) | `movegen` tests the offset against `list_limit` before every list |
| Per-ply tables (value, killers, current move, list slots) | ply ≤ 7 | `ply_slots` = `max_depth` (60) + 6 | depth is capped at `max_depth`, and the selective plies add at most 3 |
| Game record (`$C058…`) | to the end of RAM (~16 KB) | 8,192 plies; bytes past that are not stored | only the book (first plies) and replay read it |
| Ply counter `$C001` | 16 bits, wraps | 16 bits; games that would wrap it are rejected (DEV-014) | `game.max_plies` |
| Promotion list `$C048` | 16 entries, then runs into `$C058` | the same overflow, reproduced through `setGamePageByte` | at most 16 promotions in a game, so it never overflows |
| Next-best exclusion list `$BF00` | unbounded; runs into `$C000` after 128 plies in HUMAN v HUMAN mode | 512 bytes (256 moves); appending stops when full (DEV-013) | cleared before every search |
| Pin list `$BD79` | 13 bytes | 13 bytes | at most 6 entries plus the terminator (`docs/arch/50-eval.md`) |

Depth in practice: with no hash table, a nominal depth of 20 is far beyond a game's time budget. In 90 s (ReleaseSafe, about 12 M nodes/s) the engine reaches depth 16–18 and seldepth 20–22 on sparse endgames, and depth 17 / seldepth 21 on a locked pawn structure in 60 s. All per-ply indices are bounds-checked in ReleaseSafe, and no check fired in any run.

## 6. Safety checks

All testing used Debug (unit and golden tests) or ReleaseSafe builds (self-play, stress, smoke), so integer overflow, out-of-bounds access and unreachable code all panic. Wrap-around that the original relies on is written explicitly with `+%`/`-%`. No safety panic occurred in any run.

## 7. fastchess

`tools/scripts/fastchess.bat` plays the ReleaseSafe build against itself under fastchess 1.8.0 (alpha), with random openings from UHO.pgn, `-repeat`, and `Move Overhead` 30 ms.

**Finding (class A, fixed):** the engine crashed at the first command after `uci` and could not play a single game. On Windows, fastchess gives the engine overlapped (asynchronous) pipe handles. The first read succeeded because `uci` was already waiting. The next read had to wait, `NtReadFile` returned `STATUS_PENDING`, and Zig 0.17's `std.Io` treats that on a blocking handle as unreachable, so the engine panicked. Python's subprocess pipes are synchronous, so the python-chess harnesses never hit it. `src/pipe_io.zig` now reads and writes Windows pipes with an `OVERLAPPED` and its own event, waiting with `GetOverlappedResult`; this is correct for both pipe kinds. Consoles, files and other systems keep std's streaming reader and writer. This is I/O only, so there is no DEVIATIONS entry.

**Finding (class B reporting, fixed):** the first full run, after the I/O fix, had 102 "Illegal PV move" warnings (73 at 1+0.01, 29 at 10+0.1), always a move like `a2b1q`. A queen that came from an earlier promotion (a pawn-slot queen, type `$19`), moving from the 2nd/7th rank to the last, was printed with a promotion suffix. The search reports PV moves after making them, and from that board `info.isPromotion` cannot tell an old promoted queen from a new one. `bestmove` was never affected, because it is judged on the root board. Now:
- the reported PV and the ponder move are replayed from the root by `legal.legalPrefix`, which decides promotions on the board before each move;
- root moves (`currmove`, new best) are judged against the root position's pawns.

Test: `src/legal.zig`, "legalPrefix: promotions are judged before the move".

Final run (fixed build):

| Time control | Games | Time losses | Illegal moves | Disconnects / crashes | Result |
|---|---|---|---|---|---|
| 0.5+0 | 2,000 | 0 | 0 | 0 | +292 −253 =1,455 |
| 1+0.01 | 2,000 | 0 | 0 | 0 | +661 −649 =690 |
| 10+0.1 | 400 | 0 | 0 | 0 | +140 −140 =120 |

All 4,400 games ended normally (mate, repetition, stalemate, insufficient material or the 50-move rule). fastchess's remaining warnings are expected behaviour:
- **"PV continues after threefold repetition / fifty-move rule"** (7,500 lines): the original has no in-tree repetition or 50-move detection, and adding it is forbidden (AGENTS.md §2).
- **"Last info string with score not found"** (0.5+0 only): below about 180 ms the budget's hard limit is 0, so the engine moves at the first node entry, as after a key press. No pass completes, so there is no score to report (`docs/UCI.md`).

## 8. Not done here

- **`cutechess-cli`:** not installed on the test machine. It is required for Phase 5's protocol exit criteria, together with GUI play.
