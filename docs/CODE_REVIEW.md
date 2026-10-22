# Code Review

Reviewed 2026-10-22, against commit `edd2df5b596016e3bfd0dd581132ed4070a66b6c`, using Zig 0.17.0 on Windows x86_64.

The existing differential tests provide substantial evidence that the port preserves the original engine on their covered inputs. However, this review found a reproducible crash during pondering, incorrect handling of fixed levels and restricted searches, and an extended-search capacity setting that is never enabled. These should be addressed before treating the UCI layer and search extension as complete.

This is a review, not a repair: no engine source or reference files were changed. Suggested fixes below should preserve the original evaluation, ordering and search decisions except where the project's approved adaptations require a change.

## Scope and verification

The review covered the search driver and its integration with UCI, command parsing, position loading and checkpoints, timing and pondering, reporting, book selection, move-list capacities, legality safeguards, and relevant tests. Core move generation, make/unmake, evaluation and pre-search were assessed through source inspection and the existing golden tests. This was not an independent instruction-by-instruction re-port or a fresh oracle-corpus generation.

Checks performed:

- All nine files listed in `reference/CHECKSUMS.txt` matched their SHA-256 hashes, including the canonical 48K binary.
- `zig build test -Doptimize=ReleaseSafe` exited successfully. Reported results included 285,188 make/unmake round trips, 17,694 oracle make comparisons, 8,768 root lists, 4,028 positions / 133,648 root legality comparisons, and zero failures in the reported search, edge, rejection and book session comparisons.
- The evaluation test processed 30,000 records: 5,893 were classified by the existing test as containing unrepresentable off-board junk; 605 of those differed. There were zero other mismatches. Those excluded cases are already described in `PORT_STATUS.md`; they are not newly discovered evaluation defects.
- Extended anchors passed: 1,862 search, 57 edge, 4,572 book and 195 interrupted-search comparisons.
- A separate executable was built with `zig build -Doptimize=ReleaseSafe --prefix .zig-cache/review-out`.
- `tools/scripts/uci_smoke.py` passed all 41 checks against that executable.
- Targeted subprocess probes reproduced the findings identified as runtime-confirmed below. Each independent reproduction starts a fresh engine. Where a sequence contains multiple searches, wait for `bestmove` before continuing unless explicitly instructed otherwise.

The earlier 10,000-game self-play, 4,400-game fastchess and extensive perft runs recorded in `ROBUSTNESS.md` were not repeated. GUI and non-Windows execution were not tested. Passing existing tests does not cover the newly reproduced cases.

## Findings

Priority **P1** means a significant correctness or reliability issue to fix before release. **P2** means a narrower protocol, validation or reporting defect. Runtime-confirmed findings were reproduced with the separate ReleaseSafe executable; the capacity finding is established by source inspection.

### CR-01 — P1: `ponderhit` can crash with current-line reporting enabled

**Locations:** [engine.zig](../src/engine.zig), `Control.checkPonderhit` (around line 600) and `Control.onNode` (around line 647).

`checkPonderhit` resets `start_ms`, restarting elapsed time at zero, but leaves `last_currline_ms` in the old time frame. Once the new elapsed time reaches one second, `t - c.last_currline_ms` can underflow. ReleaseSafe terminates with an integer-overflow panic before returning `bestmove`.

**Reproduction:**

```text
setoption name Seed value 7
setoption name OwnBook value false
setoption name UCI_ShowCurrLine value true
position startpos
go ponder wtime 600000 btime 600000
```

Wait for two `info currline` reports, then send `ponderhit`. In the review run the engine terminated with exit code 3 and `panic: integer overflow` roughly one second after the hit. A long remaining clock is important: the search must survive long enough to reach the bad subtraction.

**Suggested repair/test:** Keep reporting time monotonic from `go` and use a separate deadline origin for pondering, or consistently rebase every timer that uses the reset origin. Add a subprocess regression that receives at least two current-line reports before `ponderhit`, then verifies continued operation and exactly one legal `bestmove`. This is a class A crash fix, not a search change.

### CR-02 — P1: Extended search still uses the original move-list capacity

**Locations:** [state.zig](../src/state.zig), `State.list_limit` (line 188); [driver.zig](../src/driver.zig), `computerMove`; [movegen.zig](../src/movegen.zig), `Gen.add` (around line 110).

The state allocates 32,768 entries, but `list_limit` defaults to `$BC80`, the original 544-entry threshold. Neither `Engine.goImpl` nor the extended driver changes it. Searching all source references to `list_limit` finds only one assignment away from that default: the separate perft loader in `src/perft.zig`.

Consequently, UCI extended searches still set the abort flag when a search line fills the original list area. Allocating the larger array alone does not implement DEV-009. Searches that require the additional capacity stop early; `go infinite` can then wait for `stop` after the search has already aborted.

**Evidence:** Source-confirmed. The existing deep test only checks that the largest list address is below the extended upper bound; it does not require use beyond the original bound or assert that the requested depth completed without a capacity abort. No naturally occurring capacity-abort position was isolated in this review.

**Suggested repair/test:** Explicitly select the capacity for each mode, including after checkpoint restoration and when switching back to fixed levels. Test a controlled line that crosses the original threshold: extended mode must continue, original mode must retain its original abort. Reserve space for the generator's trailing terminator when choosing the extended threshold. Re-run the fidelity anchors after the change.

### CR-03 — P1: Fixed levels are interrupted by limits they are specified to ignore

**Locations:** [engine.zig](../src/engine.zig), control initialization (around lines 444–453), `computeLimits` and `onNode`.

Both search modes receive the same time/node controller. `nodes_limit` is copied from `go`, time limits are computed, and `onNode` enforces them regardless of `opts.level`. This contradicts AGENTS.md §9.5 and `UCI.md`: original levels must use their exact fixed search shape, with `stop` as the interruption mechanism.

**Reproduction:** In a fresh process, run:

```text
setoption name Seed value 7
setoption name OwnBook value false
position startpos
setoption name Level value Level 8
go
```

The reviewed build completed depth 4 at 23,919 nodes and returned `bestmove b1c3 ponder d7d5`. Repeating the same setup in fresh processes with either `go nodes 1` or `go wtime 1 btime 1` instead returned `bestmove e2e4` immediately.

**Suggested repair/test:** Disable clock/node enforcement in original mode while preserving `stop` and the required infinite/ponder result holding. Compare moves and make-sequence counts for each fixed level with and without irrelevant `go` limits. This is a fidelity issue in the UCI integration, not evidence that the golden-tested original search algorithm is wrong.

### CR-04 — P1: `searchmoves` is not enforced on all return paths

**Locations:** [engine.zig](../src/engine.zig), `excludeAllBut` and final move validation; [search.zig](../src/search.zig), initial `move_to_play` assignment (around lines 342/354), exclusion application and `NO MORE MOVES` handling (around lines 394–410).

There are three reproducible ways to return an unrequested move:

1. The initial fallback move is chosen before exclusions are applied. An early abort can return that move, and the output guard checks board legality without checking membership in `searchmoves`.
2. If all moves are excluded, the original next-best mechanism clears the exclusion list and restarts unrestricted. That original UI behavior is unsuitable for a UCI search restriction.
3. Membership compares only from/to squares, discarding the promotion suffix. A requested knight promotion therefore admits the engine's queen promotion.

**Reproductions:** With `Seed=7`, `OwnBook=false`, and `position startpos`, each in a fresh process:

| Command | Observed result |
|---|---|
| `go searchmoves a2a3 nodes 1` | `bestmove e2e4` |
| `go searchmoves depth 1` | `bestmove e2e4 ponder e7e5` |
| `go searchmoves e2e5 depth 1` | `bestmove e2e4 ponder e7e5` |

With `OwnBook=false`:

```text
position fen 7k/P7/8/8/8/8/8/7K w - - 0 1
go searchmoves a7a8n depth 1
```

The result was `bestmove a7a8q ponder h8g7`, outside the requested set.

**Suggested repair/test:** Preserve the allowed root set in the UCI layer and apply it to initial fallback, abort, restart and final-output paths. Match the complete promotion move. Do not add underpromotion search: that is expressly outside the project scope. Define a clear no-supported-move response for an underpromotion-only or empty allowed set, rather than silently substituting an unrequested move. Test restrictions with immediate stop, exhausted clocks, tiny node limits and all-excluded lists.

### CR-05 — P2: A state-changing command can block the input thread behind a long search

**Location:** [uci.zig](../src/uci.zig), `Search.settle` and `Search.finish` (around lines 44–52).

`settle` only signals stop for searches whose original command contained `infinite` or `ponder`. For a long finite search it immediately joins the search thread. The input thread then cannot read subsequent `stop`, `quit` or `isready` commands. This also disagrees with `UCI.md`, which says `position`, `setoption` and `ucinewgame` stop an active search.

**Reproduction:** Disable the book, set `position startpos`, and send `go depth 60`. After about 100 ms, send:

```text
position startpos
stop
isready
```

The reviewed process continued producing search reports but no `readyok` during the one-second observation window; the probe terminated it externally. Source inspection confirms the input loop cannot resume until the depth search ends. A GUI that always stops and waits before changing position avoids this path.

**Suggested repair/test:** Stop an abandoned search before joining, consistent with the documented command semantics, or keep the input reader independent while queued state changes wait. Test that the sequence above responds and that `quit` also remains effective.

### CR-06 — P2: Accepted numeric inputs can overflow and terminate the engine

**Locations:** [engine.zig](../src/engine.zig), `Control.plan` (around line 591); [timeman.zig](../src/timeman.zig), `budget` (lines 31–33).

The parser accepts the full `u32` mate range and `u64` clock/increment range. Subsequent arithmetic uses unchecked ordinary-width expressions: `2 * m + 1`, `inc_ms * 3`, and `soft * 5`. Clamping the result afterward does not prevent overflow during evaluation.

**Reproduction:** After disabling the book and loading `startpos`, either of these commands in a fresh ReleaseSafe process produced an integer-overflow panic, exit code 3, and no `bestmove`:

```text
go mate 2147483648
go wtime 10000 winc 18446744073709551615
```

These are extreme inputs, but the UCI parser accepts them and the project explicitly requires malformed-input robustness. ReleaseFast is not made safe by removing overflow checks.

**Suggested repair/test:** Bound values before arithmetic or compute in a wider checked type and clamp safely. Add boundary tests at maximum accepted values and the overflow thresholds. Preserve the original byte wrapping only in the ported core; these expressions are new protocol/time-management arithmetic.

### CR-07 — P2: FEN parsing does not enforce the required six-field syntax

**Location:** [game.zig](../src/game.zig), `Fen.parse` (around lines 717–759).

The parser consumes only placement, side, castling and en passant. It never consumes or validates the halfmove/fullmove fields and never rejects trailing tokens. It also accepts repeated castling rights. Ignoring parsed counters when constructing the original set-up state is intentional; accepting malformed or absent counters is a separate defect against AGENTS.md §9.4.

**Reproductions:** These were all accepted and followed by normal non-null `bestmove` output:

```text
position fen 7k/8/8/8/8/8/8/K7 w - -
position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - garbage -9 trailing
position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KKKK - 0 1
```

**Suggested repair/test:** Require and validate six fields, reject extra fields and duplicate rights, and require an exact en passant token. Continue discarding valid counters after parsing, as specified. Test syntax independently from the original set-up legality verdict so no new chess-position restrictions are introduced.

### CR-08 — P2: A malformed `position` command leaves the previous position searchable

**Location:** [uci.zig](../src/uci.zig), the `uci_parse.parse` error handler (around lines 90–93).

Position failures inside `Engine.position` invalidate the position correctly, but a failure in the outer command parser only prints a message and continues. The engine then searches its previous position. AGENTS.md §9.4 requires rejected positions to leave no valid position, with subsequent `go` returning `bestmove 0000`.

**Reproduction:**

```text
setoption name Seed value 7
setoption name OwnBook value false
position startpos
position garbage
go depth 1
```

Observed: `info string error: cannot parse 'position garbage'`, followed by a normal search and `bestmove e2e4 ponder g8f6`.

**Suggested repair/test:** Route malformed position commands through the position-rejection state transition, safely coordinating with any active search. Keep unrelated unknown commands ignorable. Assert that both parser-level and game-level position failures prevent searching stale state.

### CR-09 — P2: Position move lists accept incorrect promotion notation

**Locations:** [game.zig](../src/game.zig), `Move.parse`, `humanMove` (around line 567), and `choosePromotion`.

The move parser accepts any valid promotion suffix on any coordinate move, and `humanMove` looks up only from/to. A suffix on a non-promotion is silently ignored; a promotion without a suffix silently becomes a queen. This accepts malformed UCI move lists rather than rejecting them.

**Reproductions:** With `OwnBook=false`, both commands were accepted and allowed a subsequent `go depth 1`:

```text
position startpos moves e2e4q
position fen 7k/P7/8/8/8/8/8/7K w - - 0 1 moves a7a8
```

The first played ordinary `e2e4`; the second promoted to a queen without an explicit promotion piece.

**Suggested repair/test:** Validate the suffix against the actual moving piece and destination in the UCI position adapter. Require it precisely for promotion and reject it otherwise. Preserve the original human promotion choices and the engine's queen-only search. Cover both rebuilt positions and the deferred one-opponent-move continuation path.

### CR-10 — P2: Refutation reports omit promotion suffixes

**Locations:** [info.zig](../src/info.zig), `Info.onCutoff` (around lines 235–243) and `writeCurrLine`; [engine.zig](../src/engine.zig), `reportPassDone`.

Refutation replies are recorded with `.promo = false` unconditionally and then formatted directly. The reported PV has promotion correction through replay, but refutations do not. Current-line moves after the root likewise default to no promotion flag.

**Reproduction:**

```text
setoption name Seed value 7
setoption name OwnBook value false
setoption name UCI_ShowRefutations value true
position fen 7k/8/8/8/8/8/6p1/KR6 w - - 0 1
go depth 4
```

Observed lines included `info refutation b1b3 g2g1`, `info refutation b1f1 g2f1`, and `info refutation b1h1 g2h1`. Those pawn moves require the suffix `q`. The ordinary PV correctly reported `g2g1q` in the same search.

**Suggested repair/test:** Determine promotions from the position before each reported move, preferably by replaying reporting lines through the existing scratch state. Verify complete UCI notation for quiet and capture promotions in refutation and current-line reports. Runtime reproduction confirms the refutation defect; the corresponding current-line defect follows from the formatting code. This can be corrected entirely within instrumentation.

## Additional coverage and documentation gaps

These are not additional demonstrated core-engine bugs, but they limit the strength of completion claims:

- `build.zig` has no `check-unverified` or `test-full` step, although AGENTS.md names them as verification/release mechanisms. The reference checksums were verified manually for this review; the normal test build does not verify all nine files against `CHECKSUMS.txt`.
- The optional deep test searches depths 6–8, not the 20+ depths specified for extended-search robustness. It allows an aborted search to pass if the returned move is legal and its list address is below the extended limit. Strengthen this before using it as proof of CR-02's repair.
- `PORT_STATUS.md` explicitly records only at least 74 cases per level for some original levels, below the original 500-per-level exit criterion. Likewise, 24,107 representable standalone evaluation records are not by themselves the specified 50,000-case evaluation proof. Other root-scoring tests add coverage, but the aggregate exit criteria need a documented accounting.
- `UCI.md` still says clock polling occurs every 1,024 node entries; the implementation polls at the first entry and every 64 thereafter. Its statement that state-changing commands stop searches also needs to match the CR-05 resolution.
- Invalid check-option values currently become `false`, and spin-option values are not checked against their advertised maxima in `Engine.setOption`. This conflicts with the documented warning-and-ignore behavior for unknown values; add option-validation tests alongside the parser repairs.

The approved differences and preserved quirks in `DEVIATIONS.md` and `OBSERVATIONS.md` remain the right boundaries for subsequent fixes. Nothing found here justifies stronger evaluation terms, different move ordering, modern pruning, underpromotion search, or other chess-strength changes.
