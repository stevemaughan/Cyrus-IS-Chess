# Plan: fixes from the code review

Response to `docs/Code Review.md` (review of commit `edd2df5`). Every finding was checked against the source, and every runtime finding was reproduced with the current ReleaseSafe build, using a probe script whose cases are to be folded into `tools/scripts/uci_stress.py`. All ten findings are genuine. Two need an owner decision on the exact behaviour (§3).

None of the fixes touches the evaluation, move generation or move ordering. Two touch what the search sees:
- **CR-02:** the extended list capacity that DEV-009 promised.
- **CR-03:** fixed levels stop being cut short by limits they should ignore.

Both bring the code in line with the spec. Every other fix is in the UCI layer, the reporting or the input validation.

## 1. Verdicts

| ID | Finding | Verdict | Reproduced |
|---|---|---|---|
| CR-01 | `ponderhit` + `UCI_ShowCurrLine` crashes | Genuine, class A | yes: `panic: integer overflow`, exit 3 |
| CR-02 | Extended mode keeps the 544-entry list limit | Genuine (DEV-009 never switched on) | source: `list_limit` is only raised in `perft.zig` |
| CR-03 | Fixed levels obey `nodes` / clock limits | Genuine, against §9.5 | yes: Level 8 + `go nodes 1` → `e2e4` at once |
| CR-04 | `searchmoves` can return an unlisted move | Genuine, three paths | yes: all four cases |
| CR-05 | A state-changing command blocks input behind a finite search | Genuine | yes: no `readyok`, `stop` unread |
| CR-06 | Huge `mate` / `winc` overflow | Genuine, class A | yes: both panic, exit 3 |
| CR-07 | FEN syntax not checked after the e.p. field | Genuine; partly a decision (§3.1) | yes: all three accepted |
| CR-08 | Unparsable `position` leaves the old position searchable | Genuine | yes |
| CR-09 | Promotion suffix not validated in `position … moves` | Genuine | yes: `e2e4q` and `a7a8` accepted |
| CR-10 | Refutation (and currline) moves lack promotion suffixes | Genuine, reporting only | yes: `g2g1` |
| Gaps | No `check-unverified` / `test-full` / checksum test; deep test too weak; stale `UCI.md`; per-level coverage below the 500 target; option values unchecked | Genuine | `Move Overhead 999999999` and `OwnBook maybe` accepted silently |

**Severity notes:**
- **CR-02** matters only once the current line's lists exceed 544 entries. That is roughly 12 plies of 45 moves, so middlegames at depth 9 or more: long analysis, not bullet. It is still P1, because it silently caps analysis and leaves `go infinite` idle until `stop`.
- **CR-05** happens only when a GUI changes the position without first sending `stop`. Well-behaved GUIs don't do that, but `quit` must never hang.

## 2. Fixes

### Batch A: crashes (CR-01, CR-06)

**CR-01.** `Control` gets two time origins:
- `start_ms` (from `go`) for reporting: `time`, `nps`, currline and currmove pacing, and pass durations;
- `clock_ms` (from `go`, reset by `ponderhit`) for the time limits only.

`onNode`, `nextPass` and `startNextPass` use the clock origin; everything else uses the reporting origin. This also fixes a quieter bug: a pass that spans the ponderhit was timed as 0 ms (`-|` saturation), which skewed the next-pass prediction.

**CR-06.** Make the new protocol arithmetic saturating:
- `plan`: `2 *| m +| 1`;
- `timeman.budget`: `inc *| 3`, `soft *| 5`, and `t / @max(mtg, 1)` as now.

Audit every other use of `Go` fields the same way (`movetime − overhead` is already guarded). Nothing in the ported core changes.

**Tests:**
- unit tests in `timeman.zig` at `maxInt(u64)` and at the overflow thresholds;
- engine tests for `go mate 2147483648` and the maximum `winc`, each expecting one legal `bestmove`;
- an engine test that pondering with currline on for over 1 s, then `ponderhit`, gives one legal `bestmove`.

### Batch B: search integration (CR-02, CR-03, CR-04)

**CR-02.** Set `s.list_limit` explicitly at every `go`, after the checkpoint and baseline restore:
- extended mode (`Level = UCI`): `listAddr(list_bytes_extended − 64)`, leaving headroom for the terminator and the next header;
- original mode and P-levels: `list_end_original`, so the original's abort is kept.

The same applies wherever a test or the oracle replay drives `driver.computerMove`.

Tests:
- a controlled line that crosses offset 2176 in extended mode, which must not abort, while original mode must still abort at the same point;
- re-run all anchors, since they must be unaffected;
- strengthen the `-Ddeep` test to fail on any capacity abort (`search_flags` bit 7 without stop or time), not merely on an illegal move.

**CR-03.** In original mode (`Level 1–8`, `P1–P3`), `computeLimits` sets no time limits, `nodes_limit` and `mate_limit` are null, and `depth` is ignored. `stop`, `infinite` and `ponder` holding are kept, and `searchmoves` too, since it is the original's own mechanism.

Test: for each fixed level and two positions, the same `bestmove` and make count with plain `go` as with `go nodes 1`, `go wtime 1 btime 1` and `go depth 1`.

**CR-04.** Keep the allowed set (full `game.Move`, promotion included) for the `go`. Then:
1. **Before the search:** a listed move is searchable only if it is legal and is not an under-promotion, since the engine searches queen promotions only (AGENTS.md §2: no under-promotion search). A promotion must carry its suffix.
2. **No searchable listed move:** do not search. The original's "NO MORE MOVES" restart would search everything. Instead, answer per §3.2.
3. **After the search:** if `bestmove` is not in the allowed set (an early abort returning the static fallback chosen before the exclusions), play the first searchable allowed move in the original's root order. Print `info string`, as the DEV-005 fallback does. The ponder move goes with it.

Log the output-level restriction as DEV-015 (class B, `searchmoves` is a platform adaptation).

Tests: the four reproductions, plus `searchmoves` with an immediate `stop`, `nodes 1` and `wtime 1`; each must return a listed move or the §3.2 answer.

### Batch C: command flow (CR-05, CR-08)

**CR-05.** Restructure `uci.run`:
- **Input thread:** reads every line. It handles `stop`, `ponderhit`, `isready`, `quit` and `debug` itself, at once. Every other engine command (`position`, `setoption`, `ucinewgame`, `go`) goes in order onto a FIFO.
- **Worker thread:** owns the `Engine` and runs the queue one command at a time. A `go` runs to completion on the worker, and the next queued command waits for it. This keeps the behaviour that scripts which pipe `go …` and then `position …` rely on.
- **`stop`:** applies to the running search or to a `go` already queued. Each `go` gets a sequence number, and `stop` marks every `go` up to the newest queued one.
- **`quit`:** stops the search, drops the queue and joins the worker.
- **`isready`:** is answered at once, as UCI allows during a search.

Update `UCI.md`, whose text now says state-changing commands stop the search.

Tests:
- the review's sequence must give `readyok` within 1 s;
- `quit` during `go depth 60` must exit within 1 s;
- `uci_smoke`, `uci_stress` and the engine tests must pass unchanged.

**CR-08.** A line whose first token is `position` and that fails to parse becomes a queued "reject position" command. It invalidates the position exactly as `Engine.position` does on a bad FEN, with the same `info string error: position rejected …`. Other unparsable lines stay ignorable.

Test: `position startpos`, `position garbage`, `go depth 1` → `bestmove 0000`.

### Batch D: input validation (CR-07, CR-09, options)

**CR-07.** Per decision §3.1 the FEN parser becomes *more* permissive (placement and side only), not stricter. It must reject cleanly, never crash, on anything it cannot interpret.

Tests:
- two-, three-, four- and six-field FENs are accepted;
- repeated castling letters are accepted;
- garbage counters are ignored;
- a bad placement, side, castling letter or en passant token is rejected.

**CR-09.** Validate the suffix against the position before each move:
- in `game.humanMove` (it has the state): a move to the last rank by a pawn needs `q`/`r`/`b`/`n`, and any other move must have no suffix (new `MoveError.BadPromotion`);
- for the deferred one-move continuation, validate when `position` stores the pending move, so the rejection happens at `position` and not at `go`.

Tests: `e2e4q` and `a7a8` are rejected; `a7a8q` and `a7a8n` are accepted (the human may under-promote, as in the original).

**Options.**
- check options accept `true`/`false` only;
- spin options must be integers inside the advertised `min`/`max`;
- anything else gets `info string unknown value …` and the option is unchanged.

Tests: one per option.

### Batch E: reporting (CR-10)

Refutations and currline are replayed through `legal.legalPrefix` on the scratch state, which decides each move's promotion before the move:
- **refutations:** the root move and the reply;
- **currline:** the current line from the root.

The existing `isPromotion` guess remains only as in-search scratch data and is never printed.

Test: the review's position gives `info refutation b1b3 g2g1q`, and currline lines carry suffixes.

### Batch F: gaps

- **Build steps:**
  - `zig build check-unverified` fails on any `UNVERIFIED:` tag in `src/`;
  - a reference-integrity test hashes the nine files in `reference/CHECKSUMS.txt`;
  - `zig build test-full` runs `test` plus `-Ddeep` plus perft on a bounded subset;
  - add `tests/known_failures.txt` (empty, with its format).
- **Deep test:** after CR-02, fail on capacity aborts. Add a narrow position searched to a nominal depth of 20+ (seconds, given its branching factor), so ply ≥ 23 is exercised.
- **`UCI.md`:** fix the clock polling (first node entry, then every 64) and the command semantics (CR-05).
- **Coverage accounting (`PORT_STATUS.md`):** see decision §3.3. For the evaluation, document that 24,107 standalone records plus the 133,648 statically scored root moves (each one evaluation call compared through its score byte) exceed the 50,000-case target.

## 3. Owner decisions (2026-10-22)

### 3.1 FEN fields (CR-07): be as flexible as possible

The owner's instruction: accept the minimum number of fields. This replaces the review's six-field requirement and the "parse strictly" of AGENTS.md §9.4 step 1:
- **Required:** the placement and the side to move.
- **Optional:** castling (default `-`) and en passant (default `-`).
- **Ignored:** the counters and anything after them, never examined. They are discarded anyway (§9.4 step 7).
- **Castling:** any order of `KQkq` letters, repeats tolerated. The existing check that a right's king and rook stand on their home squares still applies.

**Rejected:** only what cannot be interpreted as a position:
- a bad placement;
- a side that is not `w`/`b`;
- castling letters outside `KQkq`;
- an en passant field that is not `-` or a square.

### 3.2 `searchmoves` with nothing searchable (CR-04)

| Case | Behaviour |
|---|---|
| `go searchmoves` with no moves listed | No restriction: search everything (owner). |
| Listed moves, none legal | `info string`, `bestmove 0000` (recommendation, not overruled). |
| Only legal under-promotions listed | Play the first listed one without searching (it is legal and was requested), with an `info string` (recommendation, not overruled). |

### 3.3 Search coverage below the 500-per-level target: top up (owner)

| Level | Golden searches before | Needed for 500 |
|---|---|---|
| Level 6 | 228 | 272 |
| Level 7 | 202 | 298 |
| Level 8 | 206 | 294 |
| P1 | 84 | 416 |
| P2 | 81 | 419 |
| P3 | 74 | 426 |

`golden_search.py --levels` (new) generates sessions at chosen levels only, weighted by those deficits, into `tests/golden/search-high.jsonl.gz`. Every test that reads `search.jsonl.gz` also reads the new file.

## 4. Order and regression

1. Batches A → F in order, each with its own tests and commit.
2. After batches B and C, re-run:
   - `zig build test`, `test-engine` and `-Ddeep` (ReleaseSafe);
   - `uci_smoke`;
   - `uci_stress`, extended with the review's reproductions.
3. At the end:
   - 2,000 self-play games;
   - fastchess 1+0.01 (2,000 games);
   - perft (it sets its own list limit, so it is unaffected).

   Record the results in `ROBUSTNESS.md` §9 ("After the code review").
4. Update `DEVIATIONS.md` (DEV-009 now implemented as described, DEV-015 new), `UCI.md` and `AGENTS.md` (Phase 4 note).
