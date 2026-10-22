# AGENTS.md — Cyrus IS Chess: a faithful UCI port in Zig

This file tells any agent (human or AI) working in this repository what we are building, how we build it, and the rules that decide every judgement call. Read all of it before you change anything. Where this file and your instincts disagree, this file wins. If this file is silent or ambiguous, stop and ask the project owner rather than guess.

---

## 1. Mission

Produce a UCI chess engine, written in Zig, whose **search and evaluation behave exactly like the 48K version of Richard Lang's *Cyrus IS Chess* for the ZX Spectrum** (Intelligent Software / Sinclair Research, 1983). Given the same game state and the same level, it must choose the same move for the same reasons.

"Faithful" means:

- Same move generation **and the same move order**.
- Same evaluation terms, weights, tables, integer widths and overflow behaviour, including the evaluation's pseudo-random term.
- Same search algorithm, including pruning, move ordering, extensions, level structure, tie-breaking, opening book, draw handling and mate scoring.
- Same sequence of moves made during a search, which implies the same node counts. This is our strongest proof of fidelity.

**Deeper search (owner decision, 2026-10-21).** The original's levels stop at a full-width depth of 4. The port may search as deep as time allows, with iterative deepening and time management, to support every UCI `go` command. The guiding question is: *if the original engine had been able to search 20 ply, what would it have looked like?*
- The evaluation and the search algorithm stay faithful: move ordering, extensions, pruning, scoring and draw handling.
- Only the depth limit, the iteration loop and time control are new.
- The original levels remain available unchanged, as an exact reference mode.
- The full design is in `docs/EXTENDED_SEARCH.md`.

There are only four permitted classes of change (see §8):

1. **Crash-class bugs are fixed.** These cover anything that could crash, hang or corrupt the engine's memory.
2. **Illegal moves are fixed.** The engine must never output an illegal move.
3. **Platform adaptation.** This covers I/O, the UCI protocol, random sources, and loading positions from FEN, with positions the original could not handle being rejected.
4. **The approved search extension.** Arbitrary depth, iterative deepening over the original's own pass mechanism, time management, reporting and pondering, exactly as specified in `docs/EXTENDED_SEARCH.md`.

Everything else, *including weak play, odd evaluation and chess misconceptions*, is preserved deliberately. We are restoring a historical artefact. We are not improving it.

---

## 2. Non-negotiable rules for agents

1. **The original Z80 binary is the specification.** The canonical binary is `reference/extracted/cyrus48-6000-9FFF.bin`, taken from `reference/original/CyrusISChess-48k.tzx` (provenance in `reference/README.md`).
   - Its behaviour is documented in `docs/ORIGINAL_ARCHITECTURE.md` and `docs/arch/`.
   - Third-party descriptions of Cyrus, your memory of "how chess engines usually work" and later Lang programs are *hints only*.
   - The manual (`docs/manual/`) is a strong hint, but the code wins if they disagree.
2. **Never "improve" the engine.** Beyond the approved extension (§1), do not add anything the original does not do. That rules out transposition tables, history heuristics, null-move pruning, late-move reductions, aspiration windows, better evaluation terms, under-promotion search, mate-distance scoring and in-tree repetition detection (`docs/EXTENDED_SEARCH.md` §7). If you notice a weakness, record it in `docs/OBSERVATIONS.md` and leave it alone.
3. **Every ported routine cites its origin.** Each Zig function that ports original code carries a doc comment naming the Z80 address range and the disassembly label, e.g. `/// Port of GenMoves ($78CE–$79C7).`
4. **Every deviation is logged.** Any behavioural difference from the original, however small, gets an entry in `docs/DEVIATIONS.md` (format in §8.4) and a test that demonstrates it. An unlogged deviation is a bug.
5. **Prove fidelity by differential testing against the original code** running in the oracle (§6 Phase 2). "It looks right" is not evidence. A routine is ported only when it matches the oracle on the test corpus.
6. **Mark uncertainty explicitly.** If you port something you have not verified against the oracle, tag it `// UNVERIFIED:` with a reason. `zig build check-unverified` must report zero of these before a release.
7. **The reference binaries are committed and immutable.** The project is abandonware, and the owner has decided the tape images, extracted blocks, ROM and reference snapshots live in the repository.
   - Never edit, re-save or regenerate anything under `reference/`.
   - Verify files against `reference/CHECKSUMS.txt` before relying on them.
   - New reference files are added with a hash and a provenance note (including the exact command that made them).
8. **Keep the build green.** `zig build test` must pass on every commit. Fidelity tests that are known to fail must be listed, with a reason, in `tests/known_failures.txt`. They must never be silently skipped.

---

## 3. What we know about the original

Phase 1 is complete; see `docs/ORIGINAL_ARCHITECTURE.md` for the summary and `docs/arch/` for the specifications. The facts that drive the design of the port are below.

- **Binary:** 16 KB at `$6000–$9FFF` (code, tables, and the opening book at `$9000–$9BCC`), loaded by a standard ROM loader, entry `$6000`. The workspace is `$B400–$C0FF`.
- **No clock.** Nothing reads a timer.
  - A level is a fixed search shape (depth D = 1, 2, 2, 2, 3, 4, 4, 4 for Levels 1–8, plus pruning and extension switches, and a Level-2 pre-pass for Levels 6–8).
  - P1/P2/P3 search like Levels 1/4/8.
  - There is no iterative deepening beyond that pre-pass, and the deepest ply is 7. Extended mode generalises this; see `docs/EXTENDED_SEARCH.md`.
  - The manual's "times per level" were just Spectrum speed.
- **Interruption:** a key press, polled at every search node, sets an abort flag. The search unwinds and plays the best completed root move.
- **Scores** are one unsigned byte with `$80` = equal. Mates are not distance-scored.
- **The evaluation adds noise** from the random byte `$BCCE`, which it increments on every call.
- **Behaviour depends on more than the position.** Some of it comes from memory side effects. The port must reproduce these *effects*; the memory layout itself does not need to be preserved (§6 Phase 3):
  - move order follows piece-*slot* order;
  - the search reads stale per-ply data and compares list addresses;
  - the evaluation and move generator read variables in the board's off-board columns as if they were squares;
  - the previous search's score (`$BCA0`), the repetition counter, the book state and the game record all persist between moves.
- **Positions enter the original two ways:** a new game, or set-up mode. Set-up mode has its own legality check (§9.4) and resets the move number to 10, disables the book and forbids an immediate en passant.
- **Known bugs** are listed in `docs/DEVIATIONS.md`. Preserved quirks are in `docs/OBSERVATIONS.md`. Unresolved points are in `docs/OPEN_QUESTIONS.md`.

---

## 4. Repository layout

```
AGENTS.md                     ← this file
build.zig / build.zig.zon     ← Zig build; pins the Zig version
.zigversion                   ← exact Zig version used
reference/                    ← COMMITTED, IMMUTABLE ground truth (see reference/README.md)
  original/                   ← CyrusISChess-48k.tzx (canonical), CyrusISChess-16k.tzx, 48.rom
  extracted/                  ← raw tape blocks (cyrus48-6000-9FFF.bin etc.)
  snapshots/                  ← cyrus48-entry-6000.z80, cyrus48-idle-level1.z80
disasm/
  ctl/NN-*.ctl                ← SkoolKit control files, one per subsystem (the annotated source)
  cyrus.skool, cyrus.asm      ← generated by tools/scripts/build-disasm.ps1; never hand-edit
docs/
  manual/                     ← original instructions
  ORIGINAL_ARCHITECTURE.md    ← summary spec of the original
  EXTENDED_SEARCH.md          ← approved generalisation: any depth, iterative deepening, time management
  arch/                       ← subsystem specs: 00-overview, 10-main-ui, 20-board-movegen, 25-book, 30-search, 50-eval
  PORT_STATUS.md              ← port units and their verification state
  DEVIATIONS.md               ← every behavioural difference from the original
  OBSERVATIONS.md             ← quirks deliberately preserved
  OPEN_QUESTIONS.md           ← unresolved questions, with addresses
  UCI.md                      ← protocol behaviour and options as implemented
src/
  main.zig                    ← entry point; starts the UCI loop
  uci.zig                     ← UCI parsing, I/O thread, info output
  state.zig                   ← engine state: board, piece records, move lists, search tables, game record (§6 Phase 3)
  game.zig                    ← new game, set-up mode, game-move path, FEN/moves → game state, rejection
  board.zig                   ← make/unmake (ported)
  movegen.zig                 ← move generator (ported)
  presearch.zig               ← pre-search set-up $7810 (ported)
  eval.zig                    ← evaluation (ported)
  search.zig                  ← search state machine (ported; generalised per EXTENDED_SEARCH §2)
  driver.zig                  ← pass schedules: original levels and extended iterative deepening
  book.zig                    ← opening book probe (ported; book data embedded from the binary)
  timeman.zig                 ← time budget, soft/hard limits, abort at the poll point
  pv.zig                      ← reporting-only PV table
  rng.zig                     ← seeded PRNG standing in for R and key-wait timing
tools/
  scripts/                    ← simulator driver, ctl generator, disassembly build, book dumper
  research/                   ← Phase 1 probes and verified Python models (see its README)
  oracle/                     ← Phase 2 oracle (Python, SkoolKit simulator) and golden-file generators
tests/
  golden/                     ← oracle outputs committed as test data
  positions/*.epd             ← test corpora (see §10)
  deviations/                 ← one test per DEVIATIONS.md entry
  known_failures.txt
```

The engine (`src/`) must never depend on `tools/` or on Python. Zig tests read the committed golden files.

---

## 5. Toolchain

Install with [Scoop](https://scoop.sh) where available:

```powershell
scoop install zig@0.17.0 zls python git      # main bucket
python -m pip install skoolkit chess         # disassembler/simulator (10.1 used so far); python-chess for legality cross-checks
scoop bucket add games; scoop install mame   # optional: Spectrum emulation with a strong debugger
```

- On Windows, a fresh shell can resolve `python` to the Microsoft Store alias rather than Scoop's Python. If that happens, call `~\scoop\apps\python\current\python.exe` directly. SkoolKit's scripts are in `~\scoop\apps\python\current\Scripts\`.
- SkoolKit's C simulator extension is not built for Python 3.15, so the pure-Python simulator is used. It runs the original at roughly 10–15× real Spectrum speed, which is enough for the oracle.
- **Zig 0.17.0** is pinned in `.zigversion` and `build.zig.zon` (`minimum_zig_version`). Zig is pre-1.0 and its standard library changes between releases, especially I/O (`Writer`/`Reader`). Check the documentation for *the pinned version* before you use any std API. Upgrading Zig is a deliberate, separate commit.
- **Emulators:** Fuse or ZEsarUX (not in Scoop; download from their project sites) for interactive exploration.
- **UCI test harnesses:** `fastchess` and/or `cutechess-cli` (GitHub releases).
- Run Python that reads downloaded files with `python -I`.

---

## 6. Work plan

The phases are sequential. Each phase has deliverables and exit criteria, and a phase is not done until its exit criteria are met. Keep `docs/PORT_STATUS.md` current.

### Phase 0 — Acquire and pin the original ✅ (2026-10-21)

The canonical release, ROM and entry snapshot are committed and hashed, and the original has been seen playing (Demo mode reached move 43 at Level 1). See `reference/README.md`.

### Phase 1 — Disassemble and document ✅ (2026-10-21)

- **Disassembly:** fully structured. Every instruction executed while thinking is labelled and commented. Main-loop and UI code has routine-level annotation, plus instruction comments wherever it is game logic.
- **Specifications:** `docs/arch/`.
- **Verified Python models:** move generator, evaluation and search (`tools/research/`); book decoder (`tools/scripts/book_dump.py`).

Remaining questions are in `docs/OPEN_QUESTIONS.md`; resolve them as their port units come up.

### Phase 2 — Build the oracle ✅ (2026-10-22)

Done. The oracle is in `tools/oracle/` (see its README). The golden files are in `tests/golden/`:

| File | Contents |
|---|---|
| `search.jsonl.gz` | 2,000 sessions, 4,028 computer moves at every level |
| `edge.jsonl.gz` | 24 edge positions × 7 levels |
| `reject.jsonl.gz` | 17 rejection cases |
| `book.jsonl.gz` | every book position, probed twice |
| `eval.jsonl.gz` | 30,000 evaluations |
| `abort.jsonl.gz` | 400 searches interrupted at a random node |

**Every record re-runs identically from its captured state in a fresh machine**, which proves the state format is complete (`verify_state.py`, `verify_eval.py`). Regeneration is byte-identical. The original was driven through its own user interface, so the goldens are the interactive original's behaviour.

The plan as written before Phase 2 follows.

The oracle runs the **original code** under SkoolKit's Z80 simulator, driven from Python, and writes **golden files** that the Zig tests compare against. Python is needed only to regenerate golden files, never to build or test the engine.

1. Start from `tools/scripts/cyrus_sim.py` and the probes in `tools/research/`. Build `tools/oracle/` with:
   - **Scenarios as inputs.** Golden files describe their inputs in *semantic* terms that the port can reproduce through its own operations, never as memory dumps:
     - a start (new game, or FEN through the canonical set-up construction in §9.4);
     - game moves (entered through the original's move-entry path `$61C8`/`$6323`);
     - settings (level, `$BCCE`, random bytes);
     - for unit-level fuzzing of the move generator and evaluation, an explicit description of piece slots, type bytes and the variables they read (the format of `docs/arch/50-eval.md` §9).
   - **Probes** that call original routines and record **semantic outputs**: the values that decide moves, plus any state that later decisions read:
     - `gen` (`$78CE`): moves in order with their flags; the count;
     - make/unmake: the position and piece state after each;
     - `eval` (`$8400`): A, B, the move flags, and the variables later code reads (`$BCCE`, `$BD4E`, `$BD39/$BD3A`);
     - `presearch` (`$7810`): `$BD1E`, `$BD2E`, `$BD4A`, `$BD6D`, the phase bits;
     - `setup-check`: the verdict and the resulting state;
     - `search(level)`: the full make sequence (ply, from, to), the move played, the root value, and makes/evals/nodes;
     - `book(random bytes)`: the move chosen;
     - `abort-at-node N`: simulates a key press at the N-th `$7D43` entry;
     - **side-effect probes**: the values the original reads through memory quirks, i.e. off-board-column bytes (OPEN_QUESTIONS #2) and stale per-ply slots, wherever they occur in the corpus. These let the port prove it reproduces them.
   - **Golden-file writers:** a stable text or JSON format per probe in `tests/golden/`, recording the oracle version, the corpus, and the snapshot hash.
2. A Zig Z80 core is **not** required. Write one only if golden-file generation becomes a bottleneck; if you do, validate it with ZEXDOC/ZEXALL and the FUSE test suite.

**Exit:** golden files exist for every Phase 3 row. Regenerating them is bit-identical. Spot checks against the interactive original (e.g. the move played after M at Levels 1 and 2 in 10 positions) agree.

### Phase 3 — Port, bottom-up, each layer proved before the next ✅ (2026-10-22)

**Architecture: behavioural equivalence (owner decision, 2026-10-21).** The port must play the same moves under the same constraints, through the same search and evaluation. The memory layout does **not** need to be preserved. Use clear Zig data structures: board, piece records, move lists, per-ply tables, game record. Where a decision in the original depends on a memory side effect, reproduce the *effect* explicitly and document it at the code site. The known cases:

| Original side effect | What the port must reproduce |
|---|---|
| The move generator and evaluation read variables in the board's off-board columns as squares (a/h-file pawn captures, king neighbours) | An off-board read returns the current value of the variable aliasing that byte (`$BD58`, the root record +0; `$BD7F`, inside the pin list, written by the evaluation itself), and 0 elsewhere. Evidence in `docs/OPEN_QUESTIONS.md` (resolved) |
| The search reads stale per-ply list pointers left by earlier lines and searches (`L7F20`, `L7EB6`) | Keep per-ply list starts persistent across lines and searches, exactly as the original leaves them |
| List-size tests done on addresses (high byte of slot(4)/(6) `== $B4`, low byte of slot(5) `≥ $58`) | The equivalent tests on byte offsets from the start of the root list (`docs/EXTENDED_SEARCH.md` §2) |
| `$BD4E` is written by both the search and the evaluation | The same last-writer-wins value |
| Move order = piece-slot order; slots depend on how a position was entered | Slot-ordered piece records and the original slot-assignment rules |
| Evaluation working storage left stale (pin list, king-record attack bytes) | Nothing, if no later decision reads it (confirmed in `docs/arch/50-eval.md`) |
| Capacity limits that change behaviour in original mode (the list area holds 544 entries; when full, the search aborts) | The same limit in original mode (DEV-009) |

A Phase 3 unit is done only when its golden tests pass *and* every side effect it touches is accounted for in this table.

| Step | Port | Differential test (Zig vs golden) |
|---|---|---|
| 3.1 | State structures; tables and book data (extracted from the binary by the build, never retyped) | equality with the binary |
| 3.2 | New game; set-up mode (slot assignment, legality check); FEN → state via the canonical construction | identical position, piece records (slot, square, type byte) and game variables after each operation |
| 3.3 | Make / unmake | identical state after every make/unmake in random walks |
| 3.4 | Move generator | identical list, order, header and flags on the corpus. `book_dump.py`'s 2,685 book nodes must also resolve identically |
| 3.5 | Pre-search set-up (`$7810`) | identical outputs (`$BD1E`, `$BD2E`, `$BD4A`, `$BD6D`, `$BD2D` bits) |
| 3.6 | Evaluation | identical A, B, flags and later-read variables on ≥ 50,000 cases (game samples + fuzz, as in `tools/research/eval/fuzz.py`) |
| 3.7 | Static scoring, pick-best, find-move | identical |
| 3.8 | Search, all levels and P1–P3 | identical make sequence, `$BD29`, `$BCA0` and counts on ≥ 500 positions per level |
| 3.9 | Abort at node N | identical result for injected aborts |
| 3.10 | Opening book | identical choice for the same random bytes; full-tree walk |
| 3.11 | Game-move path (PlayMove: record, 50-move counter, repetition tracking, promotion choice) | identical game state after move sequences |
| 3.12 | Extended driver: pass schedule, iterative deepening (`EXTENDED_SEARCH` §3) | anchors: `go depth 1/2/4` (profile Level 6/7/8) identical to original Level 1/2/6/7/8 on every golden search position |

**Porting style:**
- The Python models in `tools/research/` are executable specifications. Port from them *and* the disassembly. Where they differ, the disassembly wins, and the model gets fixed.
- **Integer widths, signedness and wrap-around must match.** Use `u8`/`i8` and `+%` where the original wraps; saturate where it saturates; make carry explicit.
- The search is a state machine over plies in the original. Recursion is acceptable if it reproduces the same order, counts and stale-data effects; the state-machine shape makes that easiest to prove.

**Exit:** every row is green, `docs/PORT_STATUS.md` is fully verified, and `check-unverified` reports zero.

### Phase 4 — Robustness audit (crashes and illegal moves) ✅ (2026-10-22)

Done; the report is `docs/ROBUSTNESS.md`. In summary:
- **Perft:** 126 positions, 0 differences.
- **Self-play:** 10,000 games with 0 failures.
- **fastchess:** 4,400 games at 0.5+0, 1+0.01 and 10+0.1, with 0 time losses, illegal moves or disconnects.
- **UCI stress:** 0 failures.
- **Fixes:**
  - DEV-012 (the original's draw rules), DEV-013 and DEV-014;
  - tiny-clock time management;
  - overlapped Windows pipes (`src/pipe_io.zig`);
  - PV promotion suffixes.
- **Still open:** `cutechess-cli`, which moves to Phase 5.

The plan as written before Phase 4 follows.

1. **Capacities.** Review every fixed-size structure in `src/` against `docs/arch/*`: move lists, ply tables, undo stack, game record, pin list. Confirm the bounds the original guards, and fix the known bugs (DEV-001…DEV-004).
2. **Safety checks.** Build in `Debug` and `ReleaseSafe` for testing. Every safety panic is either a faithful wrap (make it explicit with `+%`/`-%`) or a real bug (classify it, fix it, log it).
3. **Illegal-move audit.** In debug builds, assert that every `bestmove` and every PV move is legal. Run perft against true perft and classify each divergence: B if it reaches output, C if it stays internal. Resolve OPEN_QUESTIONS #1 (castling through check) here.
4. **Stress tests.**
   - Every level including P1–P3.
   - Extended mode at depth 20+ and `go infinite` for minutes (relocated tables, list capacity, undo stack).
   - Positions with ≥ 127 moves.
   - Long games through `position startpos moves …`, including pondering and takebacks.
   - Promotions galore; no legal moves; one legal move.
   - Malformed UCI input.
   - Thousands of fast self-play and gauntlet games under `fastchess` at bullet and blitz controls, with zero time losses.

**Exit:** zero crashes, hangs, illegal moves or safety panics across a 10,000-game run and the stress suite. Every fix is logged and tested.

### Phase 5 — UCI layer

Implement §9 in `uci.zig`, `game.zig`, `driver.zig`, `timeman.zig` and `pv.zig`. The ported core is driven only through narrow hooks: the abort flag at the `$78BA` poll point, the pass schedule, PV and info reporting, and node counting.

**Exit:** passes the protocol tests (§10.5) under `fastchess` and `cutechess-cli`, and plays in at least two GUIs (e.g. Arena and Cute Chess) in `UCI` mode and at every fixed level.

### Phase 6 — Release

- Build `ReleaseFast` for Windows x86_64, Linux x86_64 and macOS aarch64, plus a `ReleaseSafe` diagnostic build.
- Write `README.md`: history, credits to Richard Lang, a summary of deviations, and the UCI options.
- Tag the release. Record the canonical image hash and the Zig version in the release notes.

---

## 7. Fidelity specification

### 7.1 Must match the original exactly
- Move generation (order, flags, header), make/unmake effects, slot assignment, set-up legality verdicts.
- The evaluation, bit for bit, including memory side effects and the `$BCCE` increment and noise.
- The search: make sequence, value table, killers, pruning, extensions, mate/stalemate/repetition handling, the move chosen (`$BD29`) and the root value (`$BCA0`).
- The book's contents and selection, given the same random inputs.
- Persistent state between moves, exactly as the original carries it (§9.6).
- **Extended mode at its anchors:**
  - `go depth 1` = Level 1;
  - `go depth 2` = Level 2;
  - `go depth 4` with profile Level 6/7/8 = that original level.

  Beyond the anchors, extended mode runs the same code with D larger (`docs/EXTENDED_SEARCH.md`).

### 7.2 May differ (platform adaptation)
- **Where positions and moves come from:** FEN and UCI move lists instead of the keyboard (§9.4, §9.6).
- **Random sources (DEV-006):**
  - At each `go`, `$BCCE` is set from a seeded PRNG. This stands in for the original's key-wait spin and its `R`-register stirring at `$60EB`.
  - Each `LD A,R` in the book (`$7B89`) takes the next PRNG byte.
  - Nothing else about `$BCCE` changes.
- **Termination (DEV-007):** `stop`, time limits and node limits set the original abort flag at the original poll point, exactly like a key press.
- **Depth and iteration (DEV-008 to DEV-011):** extended mode, time management, the relocated per-ply storage, the reporting-only PV and pondering, all as specified in `docs/EXTENDED_SEARCH.md`.
- **Reporting:** UCI `info` lines; scores converted for display only (§9.3).
- **Class A and B fixes** (§8).

### 7.3 Determinism
With a fixed `Seed` (or `OwnBook=false` and the same seed), the same command sequence produces the same output. The oracle tests set `$BCCE` and the random bytes directly.

---

## 8. Bug and deviation policy

### 8.1 Classes

| Class | Definition | Action |
|---|---|---|
| **A: Crash** | Memory corruption, out-of-bounds access, overflow of a fixed area, hang, or a safety panic that is a real bug | **Fix.** Minimal change. |
| **B: Illegal or missing move** | An illegal `bestmove` or PV move; no `bestmove` when legal moves exist | **Fix** (owner decision 2026-10-21; §8.2). |
| **C: Chess bug** | Wrong but non-fatal behaviour that never reaches output as an illegal move | **Preserve**, and record it in `OBSERVATIONS.md`. |
| **D: Unsupported position** | A position or `position … moves` sequence the original could not accept or reach | **Reject** (owner decision 2026-10-21; §9.4). Never extend data structures to accommodate it. |
| **E: Approved extension** | Deeper search, iterative deepening, time management, reporting PV, pondering | **Implement exactly** as `docs/EXTENDED_SEARCH.md` specifies (owner decision 2026-10-21). Anything not in that document needs a new owner decision. |

If the class is unclear, treat the bug as C (preserve) and raise it in `DEVIATIONS.md` under "pending decision".

### 8.2 How illegal moves are fixed

Fix as close to the output as possible, so the search itself is untouched wherever the original was correct:

1. **Root filter (DEV-005):** before the search, give any root move that fails a full legality test the score the original uses for illegal moves (0). Interior nodes are left alone (class C).
2. **Book (DEV-002):** an illegal book move is treated as a book miss.
3. **Fallback:** if a `bestmove` would still be illegal or null while legal moves exist, play the first legal root move in the original's own ordering, and emit `info string`. Every occurrence found in testing is a bug to root-cause and log.
4. **PV sanitising:** truncate a reported PV at its first illegal move. This affects reporting only.

### 8.3 Known items

The known items are already in `docs/DEVIATIONS.md`:
- DEV-001: move-count overflow;
- DEV-002: illegal book move;
- DEV-003: book ply low byte;
- DEV-004: unchecked find-move;
- DEV-005: root filter;
- DEV-006: random sources;
- DEV-007: abort;
- DEV-008 to DEV-011: the extension.

Phase 4 added DEV-012 (the original's draw declaration), DEV-013 (exclusion list bounded) and DEV-014 (ply-counter wrap rejected).

In original mode the maximum ply is 7, so deep-search overflow cannot occur. In extended mode every structure that the original sized for ply ≤ 7 is relocated (`docs/EXTENDED_SEARCH.md` §2). Phase 4 must stress it at depth 20 and beyond.

### 8.4 `DEVIATIONS.md` entry format

```
## DEV-NNN: Title
- Class / Status
- Original: address(es) and behaviour
- Trigger
- Fix (Zig location)
- Behaviour change where the original worked
- Test: tests/deviations/devNNN.zig
```

---

## 9. UCI specification

### 9.1 Identity and options
```
id name Cyrus IS Chess
id author Richard Lang
option name Level type combo default UCI var UCI var Level 1 var Level 2 var Level 3 var Level 4 var Level 5 var Level 6 var Level 7 var Level 8 var Level P1 var Level P2 var Level P3
option name Profile type combo default Level 8 var Level 6 var Level 7 var Level 8
option name OwnBook type check default true
option name Ponder type check default false
option name Move Overhead type spin default 30 min 0 max 5000
option name UCI_ShowCurrLine type check default false
option name UCI_ShowRefutations type check default false
option name Seed type spin default 0 min 0 max 2147483647
```
- `UCI_ShowCurrLine` and `UCI_ShowRefutations` switch on the optional `currline` and `refutation` reports (`docs/EXTENDED_SEARCH.md` §6.2).
- `Profile` chooses which original level's switches extended mode uses beyond the first pass:
  - Level 6: threat extensions off, forward pruning on;
  - Level 7: threat extensions on, forward pruning on;
  - Level 8: threat extensions on, forward pruning off.

  It is ignored in original mode.
- Combo values contain spaces. In `setoption name Level value Level 3`, the value is the rest of the line after `value`. Match it case-insensitively; ignore unknown values with an `info string` warning.
- `Seed` 0 means seed from the clock.
- Do **not** advertise `Hash`, `Threads` or `MultiPV` (owner decision: MultiPV not needed).

### 9.2 Commands
- **Commands:** `uci`, `isready`, `ucinewgame`, `setoption`, `position [startpos | fen <fen>] [moves …]`, `go`, `stop`, `ponderhit`, `quit`, `debug`.
- **`go` parameters:** all of them: `searchmoves ponder wtime btime winc binc movestogo depth nodes mate movetime infinite`. Their meaning in each mode is in §9.5 and `docs/EXTENDED_SEARCH.md` §5.
- **`searchmoves`:** uses the original's next-best exclusion list (`$BF00`). Every root move *not* listed is excluded. This is the original's own mechanism, so it is not a deviation.
- **Threading:** one I/O thread reads stdin. The search runs on one worker thread and checks an atomic stop flag at the original's poll point (`$78BA`, the entry to every node). `isready` is answered promptly even while searching.
- **`bestmove`:** printed exactly once per `go`, and always legal (§8.2). After `stop`, it is the move the original would play when interrupted at that point (`$BD29`).
- **No legal moves** (checkmate or stalemate at the root): `bestmove 0000`.

### 9.3 `info` output (search information)
The engine exports rich search information in both modes (owner request, 2026-10-22):
- per pass: `depth`, `seldepth`, `score` (cp or mate), `nodes`, `nps`, `time`, `pv`;
- on every new best root move: `score` and `pv` at once;
- `currmove` and `currmovenumber`;
- optionally `currline` and `refutation`;
- `info string` for book moves, the level and profile in use, rejections, fallbacks and `NO MATE FOUND`.

All of it is **instrumentation only**: collected at fixed observation points, never read by the search, and verified by running the golden tests with all reporting on. The full definitions (node counting, score conversion at 8 units per pawn, mate distances, the reporting PV) are in `docs/EXTENDED_SEARCH.md` §6. Document the as-built behaviour in `UCI.md`.

### 9.4 Positions: reproduce set-up mode, reject what it rejects

The original accepts a position only through a new game or set-up mode (key C). FEN loading drives the port's implementation of that same code, the way a user following the manual would. The steps run in this order, and the first failure rejects the whole `position` command.

1. **Parse the FEN** strictly; malformed FEN is rejected.
2. **Standard start position.** If the FEN is the standard start position (White to move, `KQkq`, no en passant square), it is a **new game**: the book is allowed and the move number is 1. Skip to step 6.
3. **Canonical set-up construction.**
   1. Start from a new game.
   2. **Keep untouched** every new-game piece that the FEN has on the same square, with these exceptions:
      - a king is kept only if its side keeps at least one castling right;
      - a rook on a corner is kept only if the matching castling right is present;
      - otherwise that king or rook is removed and re-entered, so it counts as moved.
   3. Remove (U) every other new-game piece.
   4. Enter (K/Q/R/B/N/P with the colour toggle) every remaining FEN piece, scanning in the original's order: file a…h, rank 8 → 1.
   5. Set the side to move and exit (E).

   **Castling-rights check:** a FEN castling right whose king or rook is not on its home square is malformed, and is rejected.
4. **The original's exit check** (SetupExit `$6ECC` and AssignSlot) decides legality. It rejects if any of these hold:
   - a pawn is on rank 1 or 8;
   - there is no free slot for a piece (too many of a type: pawns plus surplus pieces > 8, or a second king);
   - either king is missing;
   - the side not to move is in check.

   Add no checks of our own beyond FEN syntax.
5. **En passant square.** The original cannot accept en passant right after set-up, but it can reach the position through the manual's recipe, so the port does the same:
   1. Construct the predecessor (the pawn two squares back, the other side to move).
   2. Run steps 3–4 on it.
   3. Play the double step through the game-move path.

   If the predecessor fails, reject.
6. **Moves.** Apply the `moves …` list through the original's human-move path:
   1. generate the root list (`$78CE` with IX = `$BD58`);
   2. score it statically (`$7B96`);
   3. find the move with `$7BCD`; it must have a non-zero score;
   4. PlayMove (`$6323`), with the UCI promotion suffix selecting Q/R/B/N as the original's PROMOTE TO? prompt does.

   A move the original would answer with `ILLEGAL` rejects the position.
7. **Counters.** The FEN halfmove and fullmove fields are parsed but not loaded. The original restarts at move 10 with zero counters after set-up. Document this in `UCI.md`; it is original behaviour, not a deviation.

**On rejection:** print `info string error: position rejected: <reason>` and mark the engine as having no valid position. The next `go` replies `bestmove 0000`. Never crash, hang or silently substitute another position.

### 9.5 Levels and time

The original has no clock (§3): a level is a fixed search shape.

- **`Level = UCI` (default): extended mode.**
  - Iterative deepening over the original's pass mechanism, with time management and every `go` parameter, exactly as `docs/EXTENDED_SEARCH.md` §3–§5 specifies.
  - Pass 1 is the original Level-2 pass. Later passes use D = 4, 5, 6, … with the `Profile` switches.
  - `go depth N` is the deterministic test mode; depths 1, 2 and 4 are the oracle anchors.
- **`Level = Level 1 … Level 8`: original mode.** That exact level, using the original pass schedule, with clock parameters ignored.
  - `stop` is the key press.
  - With `infinite` or `ponder`, the result is held until `stop` or `ponderhit`.
- **`Level = Level P1/P2/P3`:** the original problem search. If `$BCA0` < `$FE` afterwards, print `info string NO MATE FOUND` and send `bestmove 0000`, because the original makes no move. (In extended mode, `go mate N` handles mates of any length.)
- **Opening book:** probed exactly as the original does, when `OwnBook` is true. That means games from the standard start only, in every level, unless `searchmoves` (next-best mode) is active.

### 9.6 Game state between commands

The engine behaves like one original program left running in HUMAN v CYRUS mode, operated by the **canonical operator script** below. The oracle's `Session` class (`tools/oracle/oracle.py`) implements the same script against the original. The port must reproduce its state transitions exactly, including the side Cyrus plays (`$BCBE`), the players mode (`$BCC2`) and the sign of `$BCA0`.

- **Loading a position from scratch:**
  1. New game (G, Y), or set-up (§9.4).
  2. If there are moves: E (HUMAN v HUMAN), then enter each move. In this mode every turn that falls to Cyrus's side runs SwapSides (`$696A`): `$BCBE` flips and `$BCA0` is negated.
- **`go`, from a position loaded from scratch:** M (KeyMove `$695D`). First `$BCC2` = 1 if `$BCBE` = 0, else 2. Then SwapSides (`$BCBE` flips, `$BCA0` negated). Then ComputerMove.
- **Continuing after Cyrus's move with exactly one opponent move:** the move is entered in HUMAN v CYRUS mode, and ComputerMove starts at once. There is no swap; this is the `go`.
- **Continuing with two or more moves:** E, then the moves, then `go` as M.

- **Engine state persists across commands.** That includes `$BCA0`, `$BCCE`, `$BD4A`, the game record, the book state, and any stale data a later decision reads (§6 Phase 3). Nothing is reset that the original would not reset.
- **`ucinewgame`** = the original's new game (G, Y). Like the original, it does not reset `$BCA0`.
- **After `go`:** the engine plays its `bestmove` into its own game through PlayMove, as the original does.
- **Checkpoints:** after each game move, keep a copy of the engine state (a few KB per ply).
- **The next `position`:** if it shares a start position and a move prefix with the engine's game, restore the checkpoint at the end of the common prefix, then apply the remaining moves (step 6 of §9.4). Normal play extends the game by one or two moves; ponder misses and GUI takebacks diverge from an earlier ply. Otherwise the position is rebuilt from scratch, as a user of the original would: a new game or set-up, then the moves entered.
- **`$BCCE`** is set from the PRNG at each `go` (DEV-006).

---

## 10. Testing strategy

All of the following run via `zig build test` (fast subset) or `zig build test-full`, reading committed golden files.

1. **Unit tests:** inline `test` blocks.
2. **Reference integrity:** hashes of `reference/` match `CHECKSUMS.txt`, and the embedded tables and book match the binary.
3. **Differential tests**, Zig against golden files, for every Phase 3 row. On a mismatch, print the first divergent step (for the search, the index into the make sequence, with ply, from and to on both sides).
4. **Perft:** against true perft *and* against oracle perft. Divergences the oracle shares are original behaviour; classify each as B (fix at the root) or C (preserve).
5. **Protocol tests:** scripted UCI sessions, including:
   - `stop` straight after `go`; `go wtime 10`; `isready` mid-search;
   - every `Level` value and `Profile`;
   - every `go` parameter alone and in combination: `go depth 1..20`, `go mate 1..8`, `go nodes`, `go movetime`, clock controls, `go infinite`, `go ponder` + `ponderhit`/`stop`, `searchmoves`;
   - rejected positions followed by `go`;
   - incremental, diverging (ponder miss, takeback) and rebuilt `position` sequences;
   - malformed input.
6. **Rejection corpus** (`tests/positions/reject.epd`): each position with the expected verdict and reason, covering every condition in §9.4.
7. **Stress and match tests:** self-play and gauntlets under `fastchess` with the `ReleaseSafe` build.
8. **Corpora** (`tests/positions/`): opening, middlegame, endgame, tactics, mate-in-1/2/3 (including no-mate cases), edge cases, ≥ 127-move positions, and positions harvested from inside oracle search trees.

---

## 11. Zig conventions

- Zig 0.17.0 (§5). Run `zig fmt` before committing.
- **State:** use clear data structures. Name fields after their meaning, and give the original address in a comment (e.g. `ply: u8, // $BCA9`). Keep one source of truth per original variable. Two Zig copies of one original byte are a fidelity risk.
- **No heap allocation in the search path.**
- **Integer widths:** use explicit types matching the original (`u8`, `i8`, `u16`). Use wrapping operators only where the original wraps *and* behaviour depends on it, and say so in a comment. Elsewhere, normal operators keep safety checks active.
- Use `@intCast`/`@truncate` deliberately, with a comment when narrowing is intended original behaviour.
- **Naming:** descriptive Zig names. The original label and address go in the doc comment.
- **Errors:** UCI and FEN parsing return error unions and never panic. The ported core uses `unreachable` only where the original's logic guarantees it, proved by tests.
- **Build modes:** `Debug`/`ReleaseSafe` for development and testing, `ReleaseFast` for release.

---

## 12. How to work a task

1. Pick the next unverified row in `docs/PORT_STATUS.md`. Do not skip ahead of the phase order.
2. Read the relevant `docs/arch/` section, the disassembly (`disasm/cyrus.skool`) and the Python model if there is one. If a spec is wrong or incomplete, fix it first, citing addresses and evidence.
3. Generate or extend the golden files, then write the differential test, then the port.
4. Iterate until the test matches on the full corpus. A mismatch is *always* assumed to be a porting error until the oracle proves otherwise.
5. Update `PORT_STATUS.md`. Add `DEVIATIONS.md` and `OBSERVATIONS.md` entries if relevant.
6. Commit small, with messages like `port: GenMoves ($78CE–$79C7), golden-verified on 52k positions`.

**Definition of done for any ported routine:** it cites its original address, matches the golden files on the full corpus, has no `UNVERIFIED` tags, adds no safety panics under stress, and has an up-to-date status row.

When you are stuck, write down what you know, what you tried and the exact address in question in `docs/OPEN_QUESTIONS.md`. Do not paper over it with a guess.

---

## 13. Decisions

### Recorded (project owner, 2026-10-21)
1. **Canonical release:** Sinclair Research 1983 original, 48K side, `reference/original/CyrusISChess-48k.tzx`.
2. **Binaries:** committed to the repository. The program is treated as abandonware.
3. **Illegal moves:** fixed (class B, §8.2).
4. **Unsupported positions:** rejected, not accommodated (class D, §9.4).
5. **Levels:** exposed as the combo option `Level`. The default is `UCI`, followed by `Level 1`–`Level 8` and `Level P1`–`P3` (§9.5). UCI time options are accepted.
6. **UCI identity:** `id name Cyrus IS Chess`, `id author Richard Lang`.
7. **Deeper search** (owner, 2026-10-21): the engine may search deeper than the original and must support every UCI `go` command. Iterative deepening and time management are allowed, provided the evaluation and the search (move ordering, extensions, pruning) stay faithful. Design: `docs/EXTENDED_SEARCH.md`.
8. **Fidelity is behavioural** (owner, 2026-10-21): the engine must play the same moves under the same constraints, through the same search and evaluation. The memory layout does not need to be preserved. Memory side effects that influence decisions are reproduced explicitly (§6 Phase 3).

13. **Rich search information** (owner, 2026-10-22): export PV, node counts, current move, selective depth and the other standard UCI `info` fields, as instrumentation that never affects the search (§9.3, `EXTENDED_SEARCH` §6). MultiPV is not needed.

### Implementer proposals accepted ("proceed as planned", owner, 2026-10-21)
9. **Oracle:** SkoolKit's simulator plus committed golden files, rather than a new Zig Z80 core (§6 Phase 2).
10. **Iterative deepening** built from the original's own two-pass mechanism. Pass 1 is the original Level 2, then D = 4, 5, …, so that depths 1, 2 and 4 reproduce original Levels 1, 2 and 6/7/8 exactly (`EXTENDED_SEARCH` §3).
11. **`Profile` default Level 8:** threat extensions on, forward pruning off. These are the switches of the original's strongest level.
12. **FEN loading:** the canonical set-up construction in §9.4, and the game continuity and checkpoint rules in §9.6.

### Resolved
- *Spectrum-speed levels:* moot. The original has no clock; levels are search shapes, so each level plays the same moves on any hardware.
