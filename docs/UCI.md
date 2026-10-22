# UCI interface (as built)

This describes what the engine (`zig-out/bin/cyrus`) does on the UCI protocol. The requirements are in AGENTS.md §9 and docs/EXTENDED_SEARCH.md; deviations from the original are in docs/DEVIATIONS.md. Source: `src/uci.zig` (loop and threads), `src/engine.zig` (commands), `src/info.zig` (search information), `src/legal.zig` (legality safety net), `src/timeman.zig` (clock), `src/driver.zig` (iterative deepening).

## Identity

```
id name Cyrus IS Chess
id author Richard Lang
```

## Options

| Option | Type | Default | Meaning |
|---|---|---|---|
| `Level` | combo: `UCI`, `Level 1` … `Level 8`, `Level P1` … `Level P3` | `UCI` | `UCI` = extended mode: iterative deepening under the `go` limits. Any other value = original mode: the original's level is set and `go` runs its ComputerMove unchanged; every `go` limit is ignored (only `stop` interrupts, as a key press would). |
| `Profile` | combo: `Level 6`, `Level 7`, `Level 8` | `Level 8` | Extended mode: the original level whose search parameter `a` (5/6/7) the passes at D ≥ 3 use. |
| `OwnBook` | check | `true` | `false` = the book is never consulted (`$BD7F` = `$FF`, "out of book"). |
| `Ponder` | check | `false` | Announces pondering; `go ponder` works whatever its value. |
| `Move Overhead` | spin 0–5000 | 30 | Milliseconds subtracted from the time budget. |
| `UCI_ShowCurrLine` | check | `false` | Prints `info currline` once a second after the first second. |
| `UCI_ShowRefutations` | check | `false` | Prints `info refutation` lines after each completed pass. |
| `Seed` | spin 0–2147483647 | 0 | Seed of the random source (DEV-006); 0 = from the clock. Setting it re-seeds at once; `ucinewgame` does not re-seed. |

Unknown option names or values print `info string unknown …` and are otherwise ignored.

## Commands

| Command | Behaviour |
|---|---|
| `uci` | Identity, options, `uciok`. |
| `isready` | `readyok`: at once while a `go` is running or queued, otherwise after the commands before it. |
| `ucinewgame` | The original's new game (keeps `$BCA0`, `$BCCE` and the level, as the original does). |
| `position …` | Sets the position (below). A `position` line that cannot be parsed is a rejected position. |
| `go …` | Searches. A `go` line that cannot be parsed answers `info string error` and `bestmove 0000`. |
| `stop` | Ends the running search, or a `go` still queued; `bestmove` follows. Ignored when idle. |
| `ponderhit` | The pondered move was played: the search continues on the clock. |
| `setoption` | Sets the option. Check options take `true`/`false`, spin options an integer within their range; anything else is ignored with `info string unknown value …`. |
| `debug`, unknown commands | Ignored. Another line that cannot be parsed gives `info string error: cannot parse '…'`. |
| `quit` | Stops any search (its `bestmove` is still printed), drops queued commands and exits with status 0. End of input stops every search but still runs the queued commands, so each piped `go` gets its `bestmove`. |

`ucinewgame`, `position`, `setoption` and `go` run in order on the engine's worker thread. A `go` runs to its end before the next of them, so a script may send `go depth 5` and the next `position` at once. A `go infinite` or `go ponder` is stopped by any later one of these commands, since a GUI sending one has abandoned that search.

A UTF-8 byte-order mark before the first command is skipped.

Every `go` prints exactly one `bestmove`. The move is in UCI notation, promotions as `e7e8q` (the original always promotes to a queen). `bestmove … ponder …` is given when the reported line has a legal second move.

### Threads

The main thread only reads standard input: it never waits for the engine (code review CR-05). The engine's commands run on one worker thread, which owns the engine state. The input thread sets two atomic flags, `stop` and `ponderhit`. The search reads them only at the original's key poll (`$78BA`, every node entry): `stop` there sets `$BD4C` bit 7 exactly as a key press would (DEV-007). The clock is read at the same point, at the first node entry and every 64 after it. Output lines from both threads go through one mutex and are flushed one at a time. On Windows, pipes are read and written with overlapped I/O (`src/pipe_io.zig`), which works whether the GUI's pipe is synchronous or overlapped.

## Positions

`position startpos|fen <FEN> [moves …]` is applied by the canonical operator script (AGENTS.md §9.6, `game.Session`):

- **Checkpoints.** After every game ply the engine saves its state (everything except the move-list storage, plus the root list). A `position` with the same start and a move list sharing a prefix with the current game is continued from the checkpoint at the end of the common prefix. This covers takebacks and analysis of the same position, and the original's state (`$BCA0`, the random byte, book state, and so on) is the one it had there.
- **Continuation.** If the only new move follows the engine's own move, it is entered in HUMAN v CYRUS mode when `go` arrives, as an opponent's key entry would be.
- **Otherwise.** The new moves are entered in HUMAN v HUMAN mode. `go` then hands the move to the computer (the M key).
- **From scratch.** A different start uses the original's new game (startpos) or its set-up mode (FEN, `game.loadFen`), then the moves.

A position is **rejected** when:

- the FEN is malformed;
- the set-up position fails the original's ILLEGAL test or any check of AGENTS.md §9.4;
- a move is malformed or illegal for the original;
- the original's game is already over before the last move (mate, stalemate, or its draw rules).

A rejection prints `info string error: position rejected: <reason>`. Every `go` until the next valid `position` or `ucinewgame` answers `info string no valid position` and `bestmove 0000`.

Other cases at `go`:

- **No legal move** (mate or stalemate): `info string no legal move`, `bestmove 0000`.
- **Original declares a draw** (repetition or 50 moves): the engine searches anyway after `info string the original declares a draw here; searching anyway`. This is DEV-012, class B; the original would not move.

After `bestmove`, the engine plays its move into its own game (PlayMove), so the next `position … moves <its move> <reply>` is a continuation.

## go

**Extended mode (`Level` = `UCI`).** Passes run in this order:

| Pass | Search |
|---|---|
| D = 1 | `a` = 0 |
| D = 2 | `a` = 1 |
| D ≥ 3 | a D = 2 pre-pass with `a` = 1, then `a` = profile at D = 3, or at D = 4, 5, … |

At depth 1, 2 and 4 this reproduces the original's Levels 1, 2 and 6–8 exactly (anchor tests).

| Parameter | Behaviour |
|---|---|
| `wtime btime winc binc movestogo` | `soft = t/mtg + 0.75·inc` (mtg = movestogo or 30). `hard = min(5·soft, t/3) − overhead`, or 0 when that is not positive: the engine is nearly flagged and moves at the first node entry (with no `info … score`, since no pass completes). A pass starts only if elapsed + predicted ≤ soft. The prediction is the last pass's duration × max(last growth ratio, 3), or 0 before two passes have been timed. The D = 2 pre-pass is not timed. At `hard` the pass is aborted as by a key press. |
| `movetime T` | soft = hard = T − overhead. Passes keep starting until T is used, and the hard limit aborts the last one. This differs from EXTENDED_SEARCH §4, which would apply the prediction here too; the prediction stopped searches after 3 % of a 1 s movetime. |
| `depth N` | Passes up to D = N (1 ≤ N ≤ 60), no time limit. |
| `nodes N` | The search stops at the next node entry once the node count reaches N, and no further pass starts. |
| `mate N` | Passes up to D = 2N+1. It stops as soon as the best score is a mate in ≤ N. |
| `infinite` | No limits. `bestmove` is held until `stop`. |
| `ponder` | Searches without a clock. After `ponderhit` the clock starts from that moment with the `go`'s time parameters. If the search ends first, `bestmove` is held until `ponderhit` or `stop`. |
| `searchmoves m…` | Every other legal root move goes on the original's next-best exclusion list (`$BD06`, as the N key does). The book is therefore not used. |

When a pass is aborted, the best move so far is kept, as it is in the original.

**Original mode (`Level 1` … `Level 8`).** `go` runs the original's ComputerMove at that level and ignores the limits; only `stop` ends it early. **`Level P1` … `P3`** are the mate-problem levels. If no mate is found, the engine prints `info string NO MATE FOUND` and `bestmove 0000`.

At each `go`, the random byte `$BCCE` is set from the seeded generator, and the book's R-register reads also come from it (DEV-006).

### Legality safety net (DEV-005)

The original's search can, in rare positions, return a move that leaves its king in check. Before printing, the engine checks `bestmove` with an independent legality test (`src/legal.zig`). If the move is illegal, it prints `info string DEV-005: …` and plays the first legal root move instead. The test agrees with the original's root scoring on all 133,648 root moves of the golden positions. Reported PVs are cut at their first illegal move: the original's selective plies can score an illegal reply when in check.

## Search information

| Field | Meaning |
|---|---|
| `depth` | The full-width depth D of the current pass. The last line before `bestmove` gives the deepest completed pass. |
| `seldepth` | The deepest ply made in the pass (at least `depth`). |
| `score cp X` | X = (V − `$80`) · 100 / 8, where V is the root value byte `$BCA0`. One pawn = 8 units. Scores are from the engine's side. |
| `score mate M` | V ≥ `$FE`: a forced mate. M = ⌈(`$BD0C` − 1)/2⌉, the ply of the shortest mate. When `$BD0C` is unset, the PV length gives it. |
| `score mate −M` | V ≤ 2 (and V ≠ 0): the engine is mated. M = half the PV length. |
| `nodes` | Calls to make (`$810F`), including the makes of static root scoring. |
| `nps`, `time` | From the `go`; `time` is in milliseconds. |
| `pv` | The best line, collected from the alpha raises of the pass. It is truncated at its first illegal move, and replayed from the root to decide which moves are promotions (a promoted queen's later moves look like promotions from the board after the move). |
| `currmove`, `currmovenumber` | Printed for each root move after the first second. |
| `currline` | With `UCI_ShowCurrLine`, once a second: the moves being searched. |
| `refutation` | With `UCI_ShowRefutations`, after each completed pass: for each refuted root move, the reply that cut it off at ply 2. |
| `string book move m` | The move came from the opening book. |

A PV line is printed at each new best root move and at the end of each completed pass. One more is printed before `bestmove` if nodes were searched since the last one.

Collecting information never changes the search. The anchor tests run with the collector attached and still reproduce the original exactly.

## Performance

These figures are from a ReleaseFast build on the development machine, with `OwnBook false`. The middlegame position is `startpos moves e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 c1e3 e7e5 d4b3 c8e6 f2f3 f8e7`.

| Position | Speed | Completed depth, movetime 1 s | Completed depth, movetime 10 s | Time to depth 6 | Time to depth 7 | Time to depth 8 |
|---|---|---|---|---|---|---|
| start | ≈ 3.1–3.3 M nodes/s | 6 (7 started) | 8 | 0.1 s | 0.9 s | 5.3 s |
| middlegame | ≈ 2.8–3.1 M nodes/s | 5 (6 started) | 7 | 1.1 s | 6.2 s | 51 s |

## Testing

- `zig build test`: all unit and golden tests, including the engine flow tests in `src/engine.zig`.
- `zig build test -Ddeep=true [-Ddeep-positions=N]`: also searches about 30 golden positions at depth 6–8. It checks that no search panics, every result is legal and the move-list area stays within capacity. Use it with `-Doptimize=ReleaseSafe`.
- `python tools/scripts/selfplay.py ENGINE --games N`: self-play under python-chess with random limits, levels and options; any crash, hang, illegal or missing move, legality fallback or time loss is a failure.
- `python tools/scripts/uci_stress.py ENGINE`: malformed input, rejected positions, very long games, many-move positions, stop/ponder races, tiny clocks.
- `tools\scripts\fastchess.bat [tc] [rounds] [concurrency] [overhead] [name]`: fastchess self-play of the ReleaseSafe build with UHO openings; output in `fastchess-out\`.
- `python tools/scripts/uci_smoke.py [engine]`: drives the built executable. It covers every `go` parameter, ponder and ponderhit, stop, isready during a search, rejected positions, every `Level` value and the display options. It checks for exactly one `bestmove` per `go`.
