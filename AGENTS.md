# AGENTS.md — Cyrus IS Chess: a faithful UCI port in Zig

This file tells any agent (human or AI) working in this repository what we are building, how we build it, and the rules that decide every judgement call. Read all of it before you change anything. Where this file and your instincts disagree, this file wins. If this file is silent or ambiguous, stop and ask the project owner rather than guess.

---

## 1. Mission

Produce a UCI chess engine, written in Zig, whose **search and evaluation behave exactly like the 48K version of Richard Lang's *Cyrus IS Chess* for the ZX Spectrum** (Intelligent Software / Sinclair Research, 1983). Given the same position and the same amount of search, it must choose the same move for the same reasons.

"Faithful" means:

- Same move generation **and the same move order**.
- Same evaluation terms, weights, tables, integer widths and overflow behaviour.
- Same search algorithm, including pruning, move ordering, extensions, iteration structure, window handling, tie-breaking, opening book, draw handling and mate scoring.
- Same node counts for a fixed-depth search. This is our strongest proof of fidelity.

There are only three permitted classes of change (see §8):

1. **Crash-class bugs are fixed.** These cover anything that could crash, hang or corrupt the engine's memory.
2. **Illegal moves are fixed.** The engine must never output an illegal move.
3. **Platform adaptation.** This covers I/O, time measurement, the UCI protocol, and loading positions from FEN, with positions the original could not handle being rejected.

Everything else, *including weak play, odd evaluation and chess misconceptions*, is preserved deliberately. We are restoring a historical artefact. We are not improving it.

---

## 2. Non-negotiable rules for agents

1. **The original Z80 binary is the specification.** The canonical binary is `reference/extracted/cyrus48-6000-9FFF.bin`, taken from `reference/original/CyrusISChess-48k.tzx` (provenance in `reference/README.md`). Third-party descriptions of Cyrus, forum posts, your memory of "how chess engines usually work" and the behaviour of later Lang programs (Cyrus II, Psion Chess, Mephisto) are *hints only*. The original manual (`docs/manual/`) is a strong hint, but the code wins if they disagree.
2. **Never "improve" the engine.** Do not add transposition tables, null-move pruning, LMR, better evaluation terms, under-promotion search, or anything else the original does not do. If you notice a weakness, record it in `docs/OBSERVATIONS.md` and leave it alone.
3. **Every ported routine cites its origin.** Each Zig function that ports original code carries a doc comment naming the Z80 address range and the disassembly label, e.g. `/// Port of GENMOV ($7A10–$7B9F).`
4. **Every deviation is logged.** Any behavioural difference from the original, however small, gets an entry in `docs/DEVIATIONS.md` (format in §8.4) and a test that demonstrates it. An unlogged deviation is a bug.
5. **Prove fidelity by differential testing against the original code running in an emulator** (the oracle, §6 Phase 2). "It looks right" is not evidence. A routine is ported only when it matches the oracle on the test corpus.
6. **Mark uncertainty explicitly.** If you port something you have not verified against the oracle, tag it `// UNVERIFIED:` with a reason. `zig build check-unverified` must report zero of these before a release.
7. **The reference binaries are committed and immutable.** The project is abandonware and the owner has decided the tape images, extracted blocks and (later) the 48K ROM live in the repository. Never edit, re-save or regenerate anything under `reference/original/` or `reference/extracted/`. Verify them against `reference/CHECKSUMS.txt` before relying on them. New reference files are added with a hash and a provenance note.
8. **Keep the build green.** `zig build test` must pass on every commit. Fidelity tests that are known to fail must be listed, with a reason, in `tests/known_failures.txt`. They must never be silently skipped.

---

## 3. What we know about the original

### 3.1 The binary (established — see `reference/README.md`)

- **Canonical release:** the Sinclair Research 1983 original, 48K side of the cassette (TZX). Both tape copies of the 48K program are byte-identical, and an independent TAP re-save has an identical code block.
- **Load chain:** BASIC (`CLEAR 24319`) → logo at `$5A00` → loader `CLoad48` at `$5B00` → ROM `LD-BYTES` loads a headerless 16,384-byte block at **`$6000–$9FFF`** → `JP $6000`. There is no copy protection.
- **Entry `$6000`:** `LD HL,$1111 / LD ($5CB2),HL / LD ($5CB4),HL / DI / LD ($BCC8),IY …`. The program runs with interrupts disabled at times and uses RAM above `$9FFF` as workspace. The game record, book state and so on probably live there; map this in Phase 1.
- **16K version:** `reference/original/CyrusISChess-16k.tzx` is the simplified version from the other side of the cassette. It is useful for cross-referencing routines, but it is **not** the specification.

### 3.2 Behaviour documented in the manual (`docs/manual/CyrusISChess.txt`) — verify each in code

- **Levels:** eight playing levels, with average time per move: L1 ≈ 2 s, L2 ≈ 5 s, L3 ≈ 10 s, L4 ≈ 20 s, L5 ≈ 30 s, L6 ≈ 75 s, L7 ≈ 3 min, L8 ≈ 5–12 min. "Thinking time can vary considerably with the complexity of the position". The default after loading is **Level 2**.
- **Problem levels P1, P2, P3:** search for mate in 1/2/3. The engine keeps thinking until it finds a mate or proves by exhaustive analysis that none exists. If there is none, it shows `NO MATE FOUND` and does not move.
- **Interrupt:** any keypress during `LET ME THINK...` makes Cyrus stop and play the best move found so far. So there is a mid-search keyboard poll, and its location is our `stop`/time-check point.
- **Promotion:** the engine *always promotes to a queen*. It cannot solve problems that require under-promotion, so the search probably never generates under-promotions. The user may under-promote, so the game-move path does accept R/B/N promotions.
- **Draws and results:** it recognises checkmate, stalemate, the 50-move rule and "repetition of consecutive moves" (the same pieces moving back and forth three times). Whether and how the *search* uses these is to be determined.
- **Opening book:** in the 48K version only. "First few moves are likely to be made quickly irrespective of the level."
- **Next best (N key):** the engine retracts its move and searches again with previously played root moves excluded. This is a root-move exclusion mechanism, which can support UCI `searchmoves` (§9.2).
- **Set-up mode and legality:** the engine rejects with `ILLEGAL` any position where a side has no king, a pawn is on the back rank, the material is impossible (e.g. "eight pawns in addition to two queens"), or the side *not* to move is in check.
  - A king or rook *entered* in set-up mode cannot castle. Castling is possible only if those pieces are left untouched from the game position.
  - After set-up, the next move cannot be an en passant capture. The manual's workaround is to set up the preceding position and play the double pawn push.
  - Move numbering restarts at 10 after set-up.

### 3.3 To be discovered from the disassembly (do not assume)

- Board representation (8×8, 10×12, 0x88, piece lists, or a mixture). How "has moved" / castling state is held.
- Move representation, and the layout and size of the move stack.
- Move generator(s) and their exact order (this matters: it decides ties).
- Search: full-width alpha-beta? Iterative deepening? Aspiration windows? Quiescence rules? Check extensions? Killer or history ordering? Selective components? How the problem levels differ from the playing levels.
- Evaluation: material values, piece-square tables, pawn structure, king safety, mobility, and any root preprocessing (Lang's later programs are known for preparing evaluation tables at the root; check whether Cyrus does this).
- Score units, score width (8-bit or 16-bit), and how mate and draw are encoded.
- **The level → termination mechanism:** a time budget per level? A depth? Both? Where is the clock read (`FRAMES` sysvar `$5C78`, or the program's own interrupt counter, since it runs with interrupts disabled at times)? Exactly where is the keyboard polled?
- Opening book: format, size, lookup and source of randomness (often `R` or `FRAMES`).
- The set-up legality routine, and every condition it checks (§9.4 depends on this).
- The game-record capacity in the 48K version (the manual says "any number" of moves can be retracted, but memory is finite).
- Maximum search depth and every fixed-size buffer.

Record each finding in `docs/ORIGINAL_ARCHITECTURE.md` with the addresses it was derived from. This document becomes the specification that the Zig code is checked against.

---

## 4. Repository layout

```
AGENTS.md                     ← this file
build.zig / build.zig.zon     ← Zig build; pins the Zig version
.zigversion                   ← exact Zig version used
reference/                    ← COMMITTED, IMMUTABLE ground truth
  README.md                   ← provenance, tape layout, loader disassembly
  CHECKSUMS.txt               ← SHA-256 of every reference file
  original/                   ← CyrusISChess-48k.tzx (canonical), CyrusISChess-16k.tzx, 48.rom
  extracted/                  ← raw blocks pulled from the canonical TZX (cyrus48-6000-9FFF.bin etc.)
  snapshots/                  ← cyrus48-entry-6000.z80 and later oracle snapshots (hashed)
disasm/
  cyrus.ctl                   ← SkoolKit control file: the annotated disassembly source
  cyrus.skool                 ← generated; regenerate, don't hand-edit
  labels.zon                  ← address → label map shared with the Zig tools
docs/
  manual/                     ← original instructions (txt + pdf)
  ORIGINAL_ARCHITECTURE.md    ← spec of the original, with addresses
  PORT_STATUS.md              ← table: routine | address | Zig location | oracle-verified?
  DEVIATIONS.md               ← every behavioural difference from the original
  OBSERVATIONS.md             ← weaknesses/quirks noticed and deliberately preserved
  OPEN_QUESTIONS.md           ← unresolved questions, with addresses
  UCI.md                      ← protocol behaviour and options as implemented
src/
  main.zig                    ← entry point; starts the UCI loop
  uci.zig                     ← UCI parsing, I/O thread, info output
  position.zig                ← FEN/moves → original game state; rejection logic
  board.zig                   ← ported board representation and make/unmake
  movegen.zig                 ← ported move generator
  legality.zig                ← ported set-up legality check + root legality filter
  eval.zig                    ← ported evaluation (+ root preprocessing if any)
  search.zig                  ← ported search (playing and problem modes)
  book.zig                    ← ported opening book
  book_data.zig               ← generated from the binary by tools/extract
  tables.zig                  ← generated eval/data tables extracted from the binary
  levels.zig                  ← original level definitions + UCI time mapping
  limits.zig                  ← every fixed capacity of the original, in one place
tools/
  z80/                        ← Z80 CPU core (Zig) used ONLY by the oracle
  oracle/                     ← harness: runs original code on demand, exposes probes
  extract/                    ← pulls tables and book from the binary into src/*_data.zig
  diff/                       ← differential test drivers (movegen/eval/search)
  scripts/                    ← one-off Python/PowerShell helpers
tests/
  positions/*.epd             ← test corpora (see §10)
  perft.epd
  deviations/                 ← one test per DEVIATIONS.md entry
  known_failures.txt
```

The engine (`src/`) must never import anything from `tools/`. The emulator is a test fixture, not part of the product.

---

## 5. Toolchain

Install with [Scoop](https://scoop.sh) where available:

```powershell
scoop install zig@0.17.0 zls python git      # main bucket
python -m pip install skoolkit               # disassembler / tracer (10.1 used so far)
scoop bucket add games; scoop install mame   # optional: Spectrum emulation with a strong debugger
```

On Windows, a fresh shell can resolve `python` to the Microsoft Store alias rather than Scoop's Python. If that happens, call `~\scoop\apps\python\current\python.exe` directly. SkoolKit's scripts are in `~\scoop\apps\python\current\Scripts\`.

- **Zig 0.17.0** is pinned in `.zigversion` and `build.zig.zon` (`minimum_zig_version`). Zig is pre-1.0 and its standard library changes between releases, especially the I/O / `Writer` / `Reader` interfaces. Check the documentation for *the pinned version* before you use any std API, and do not copy snippets written for other versions. Upgrading Zig is a deliberate, separate commit.
- **SkoolKit** (`tapinfo.py`, `tap2sna.py`, `sna2ctl.py`, `sna2skool.py`, `skool2asm.py`, `skool2html.py`, `trace.py`): the main disassembly and annotation tool. The control file (`.ctl`) is the long-lived artefact.
- **An emulator with a debugger** for interactive exploration. Fuse or ZEsarUX are not in Scoop, so download them from their project sites. MAME is in Scoop's `games` bucket.
- **A UCI test harness**: `fastchess` and/or `cutechess-cli`. These are not in Scoop; use their GitHub releases.
- Run Python that reads downloaded files with `python -I`.

---

## 6. Work plan

The phases are sequential. Each phase has deliverables and exit criteria, and a phase is not done until its exit criteria are met. Update `docs/PORT_STATUS.md` as you go.

### Phase 0 — Acquire and pin the original ✅ (done 2026-10-21)

Done:
- Canonical release chosen, verified and committed.
- 48K ROM added (`reference/original/48.rom`).
- Post-load snapshot made (`reference/snapshots/cyrus48-entry-6000.z80`).
- The program traced to its idle main loop, showing Level 2 and the 48K UI (`docs/images/original-startup.png`).

See `reference/README.md` for all of these. Still to do, early in Phase 1: watch the original make at least one move (e.g. press `M` in an emulator) before relying on the snapshot for search work.

### Phase 1 — Disassemble and document

1. Start from `reference/snapshots/cyrus48-entry-6000.z80`. Any further snapshots (e.g. "idle at YOUR MOVE?") go under `reference/snapshots/`, with a hash and the exact command that made them.
2. Generate a first control file (`sna2ctl.py`, using a code map from `trace.py` or emulator execution logging, so that executed bytes are marked as code and the rest as data). Exercise every feature while tracing: all levels, P1–P3, set-up mode, take-back, next-best and promotion.
3. Annotate iteratively. Find, label and comment, roughly in this order:
   - **Main loop and UI**: keyboard reading, board drawing, move entry, the `ILLEGAL` path, the set-up mode and its legality check, and the level selector. These are not ported, except for the legality check and the level table, but they show how the engine is called.
   - **Board and game state**: find these by watching memory writes while a move is made. They include side to move, castling/has-moved state, en passant, the game record and the 50-move/repetition data.
   - **Make/unmake move.**
   - **Move generator(s)**: legal or pseudo-legal; captures-only variant; the in-check test; promotion handling.
   - **Evaluation**: static eval, incremental parts and root preprocessing. Find every table and its index scheme.
   - **Search**: the recursive routine, quiescence, move ordering, score bounds, iteration driver, depth/ply bookkeeping, PV storage, best-move selection, the problem-level variant and the next-best exclusion list.
   - **Level and termination logic**: the per-level parameters, where time is read, where the keyboard is polled, and what happens when each fires.
   - **Opening book**: format, lookup and the source of randomness.
   - **Every fixed-size buffer and its bounds checks, or lack of them.**
4. For each subsystem, write the corresponding section of `docs/ORIGINAL_ARCHITECTURE.md`, including pseudocode precise enough to port from. Confirm or correct every manual claim in §3.2.

**Exit:** every byte the engine executes while thinking is labelled and commented. The architecture document fully specifies board format, move format, movegen order, eval, search (playing and problem), book, levels/termination, the set-up legality rules, buffers, and the score and mate encoding.

### Phase 2 — Build the oracle (reference harness)

Build the oracle before porting anything. It lets us test against the original program running in an emulator, so we are not just trusting our reading of the disassembly.

1. **Z80 core** in `tools/z80/` (Zig). It must be instruction-exact, including undocumented flags. Validate it with ZEXDOC/ZEXALL and the FUSE core test suite. It must be T-state accurate enough to drive a 50 Hz interrupt (69,888 T-states per frame), so that the original's clock behaves as on real hardware.
2. **Harness** in `tools/oracle/`:
   - Load the ROM and the post-load snapshot.
   - `setPosition(fen | startpos + moves)`: drive the original's own state. Where practical, enter positions through its set-up routine and play moves through its move-entry routine, so that game-record, castling and en passant state is built exactly as the original builds it.
   - Probes that call original routines directly and stop at their `RET`:
     - `genMoves()` returns the move list *in generated order*.
     - `evaluate()` returns the raw score.
     - `search(level | depth)` returns the best move, score, PV if available, node count (from a counter the harness adds by trapping the make-move address) and per-iteration results.
     - `bookMove(random)` returns the book move for a controlled random source.
     - `legalityCheck()` returns the set-up routine's accept/reject verdict.
   - Trap ROM and UI calls (keyboard scans, printing, sound). The keyboard is "no key" until the harness injects a keypress at a chosen T-state or node, which simulates `stop`. Time is counted in emulated T-states, so oracle results are **fully deterministic**.
3. Expose the harness as a library to `tools/diff/` and as a CLI (`zig build oracle -- search "<fen>" level=2`).

**Exit:** for 20 hand-picked positions at Levels 1 and 2, the oracle's move equals the move the original plays in a real emulator with the same position. Repeated runs are bit-identical.

### Phase 3 — Port, bottom-up, each layer proved before the next

| Step | Port | Differential test (Zig vs oracle) |
|---|---|---|
| 3.1 | Data tables, extracted by `tools/extract` and never retyped by hand | byte-for-byte equality with the binary |
| 3.2 | Board / game state, FEN + moves → original format | state equals the oracle's after `setPosition` |
| 3.3 | Make/unmake move | board state equal after every make/unmake in perft walks |
| 3.4 | Move generator(s) | identical move list **in identical order** on the full corpus; perft equality with the oracle |
| 3.5 | Attack / in-check detection | equal results on the corpus |
| 3.6 | Set-up legality check | identical accept/reject verdict on a corpus of legal and deliberately illegal positions |
| 3.7 | Evaluation, including root preprocessing | exact raw score on ≥ 50,000 positions (corpus + positions sampled from oracle search trees) |
| 3.8 | Quiescence search | equal score and node count |
| 3.9 | Main search at fixed depth | equal best move, score, PV and **node count** (aim for depth ≥ 4 on 1,000 positions) |
| 3.10 | Problem search (P1–P3) | identical result, mate line and node count on a mate-problem corpus, including "no mate" cases |
| 3.11 | Iteration driver and level termination | identical per-iteration output; identical result per level when stop fires at the same node |
| 3.12 | Opening book | identical candidate set and identical choice given the same random value |

**Porting style:**
- Translate *semantics*, not instructions. Zig code should read like a chess engine, not like Z80 macros. But **integer widths, signedness and wrap-around must match**: if the original adds two 8-bit scores and wraps, use `u8`/`i8` and `+%`. If it saturates, saturate. If it relies on carry, make that explicit.
- Keep the original's data layouts wherever behaviour depends on them, for example when move order follows memory order, or when a sentinel square stops a ray.
- Do not restructure control flow if doing so could change node counts or move order. When in doubt, mirror the original structure.

**Exit:** every row is green, `docs/PORT_STATUS.md` is fully verified, and `check-unverified` reports zero.

### Phase 4 — Robustness audit (crashes and illegal moves)

Modern hardware searches roughly 10⁴–10⁵× faster than a 3.5 MHz Z80. Under UCI the engine will reach depths, node counts, game lengths and positions the original never saw. That is where latent crashes live.

1. Enumerate every fixed capacity in `src/limits.zig`: move stack, max ply, PV length, game record, repetition history, book pointers, counters. For each one, determine whether the original guards it.
2. Build Zig in `Debug` and `ReleaseSafe` for testing. Zig's runtime safety checks (integer overflow, out-of-bounds, unreachable) will catch many latent bugs automatically. Every safety panic is either (a) a faithful wrap-around that must be written explicitly with `+%`/`-%`, or (b) a real bug. Classify each one using the original's behaviour.
3. Run the **illegal-move audit**: assert in debug builds that every `bestmove` and every PV move is legal under full chess rules. Also run perft on the standard suite against true perft. Every divergence is classified: does it reach output (class B, fix) or is it internal only (class C, preserve)?
4. Stress tests:
   - Long searches (`go infinite` for minutes, `go depth 30+`).
   - Very long games via `position startpos moves …` with hundreds of moves (game-record capacity).
   - Positions with many legal moves, many promoted pieces, every under-promotion as an *input* move, near-mate, stalemate, a single legal move, and no legal moves.
   - Every level, including P1–P3 on positions with and without a forced mate.
   - Thousands of fast games against itself and other engines (`fastchess`), checking for crashes, hangs, illegal moves and time losses.
   - Fuzzing UCI input: malformed FEN, illegal moves in `position … moves`, truncated commands, unknown option values.
5. Fix each class A/B bug with the smallest change that removes the failure without changing behaviour on inputs where the original worked. Log every fix in `docs/DEVIATIONS.md`.

**Exit:** zero crashes, hangs, illegal moves or safety panics across a 10,000-game self-play run and the full stress suite, with every fix logged and tested.

### Phase 5 — UCI layer

Implement §9. Keep it isolated in `uci.zig`, `position.zig` and `levels.zig`. It must not modify ported code except through narrow, documented hooks: the stop/time poll at the original's keyboard-poll point, info reporting and node limits.

**Exit:** passes protocol tests (§10.5) under `fastchess` and `cutechess-cli`, and loads and plays in at least two GUIs (e.g. Arena and Cute Chess) in both UCI-time mode and each fixed level.

### Phase 6 — Release

- Build with `ReleaseFast` (Windows x86_64, Linux x86_64, macOS aarch64). Also ship a `ReleaseSafe` build as a diagnostic option.
- `README.md`: history, credits to Richard Lang, a summary of deviations and the UCI options.
- Tag the version. Record the canonical image hash and the Zig version in the release notes.

---

## 7. Fidelity specification

### 7.1 Must match the original exactly
- Move generation order, internal legality decisions, move encoding semantics, and queen-only promotion in search.
- Every evaluation term, table value, scaling step and rounding/truncation, and the width and overflow behaviour of every arithmetic operation that affects the score.
- Search: algorithm, bounds, cut-offs, ordering heuristics and their tie-breaks, extensions, quiescence rules, depth accounting, draw/repetition handling inside the search, problem-mode search and best-move selection when scores are equal.
- Opening book contents and selection logic (given the same random input).
- The set-up legality verdict.
- Node counts at fixed depth.

### 7.2 May differ (platform adaptation)
- **Where moves and positions come from**: FEN and UCI instead of the keyboard and set-up mode. Positions the original cannot accept are **rejected** (§9.4).
- **What triggers termination**: wall-clock time and UCI limits instead of the original's clock and keypresses. But **termination is checked at the same points in the search where the original checked the clock and keyboard**, and it has the same effect: `stop` behaves exactly like the manual's "press any key" (play the best move so far).
- **Random source for the book**: a seeded PRNG instead of the original's source. The default seed comes from the clock. The UCI option `Seed` makes it reproducible.
- **Reporting**: UCI `info` lines, scores converted to centipawns and mate-in-N (§9.3). Counters used *only* for reporting may be widened, but if a counter influences behaviour it keeps its original width.
- **Class A and B fixes** (§8).

### 7.3 Determinism
With `OwnBook=false` (or a fixed `Seed`) and `go depth N` or `go nodes N`, the engine is fully deterministic. Its output must equal the oracle's.

---

## 8. Bug and deviation policy

### 8.1 Classes

| Class | Definition | Action |
|---|---|---|
| **A — Crash** | Memory corruption, out-of-bounds access, stack/buffer overflow, infinite loop or hang, division by zero, or a safety panic that is a real bug | **Fix.** Minimal change. |
| **B — Illegal or missing move** | `bestmove` that is illegal under full chess rules (e.g. castling out of, through or into check; an en passant or pin error; moving into check); no `bestmove` when legal moves exist; a PV containing an illegal move | **Fix** (owner decision 2026-10-21). See §8.2 for how. |
| **C — Chess bug** | Wrong but non-fatal behaviour *inside* the search that never reaches output as an illegal move: misevaluation, pseudo-legal moves searched internally, wrong mate distance, imperfect draw detection | **Preserve.** Record it in `OBSERVATIONS.md`. |
| **D — Unsupported position** | A position, or a `position … moves` sequence, that the original could not accept or reach | **Reject** (owner decision 2026-10-21). See §9.4. Do not extend data structures to accommodate it. |

If a bug's class is unclear, treat it as C (preserve) and raise it in `DEVIATIONS.md` under "Pending decisions".

### 8.2 How illegal moves are fixed

Fix as close to the output as possible, so the search itself is untouched wherever the original was correct:

1. **Root filter**: before searching, test each root move for full legality. A move that the original would have played but that is illegal is removed from the root list. If the original's illegality comes from a generator bug that *also* affects interior nodes, leave the interior nodes alone (class C). Only the root is filtered.
2. **Fallback**: if the search somehow still produces an illegal or null move while legal moves exist, play the best-ordered legal root move by the original's own ordering, and emit `info string` describing the fallback. Each occurrence found in testing is a bug to root-cause.
3. **PV sanitising**: truncate a reported PV at its first illegal move. This affects reporting only.
4. Every distinct cause gets its own `DEVIATIONS.md` entry, identifying the exact original routine at fault.

### 8.3 Expected crash/illegal hotspots (check each)
- Max ply / move-stack overflow at depths the Spectrum never reached.
- 8-bit depth, ply or move counters wrapping.
- PV buffer overrun.
- Move list overflow in positions with very many moves.
- Game-record overflow in very long games. Since `position startpos moves …` can be arbitrarily long, treat this as class A and size the buffer so legal games cannot overflow it. This is a capacity fix, not a behaviour change.
- Book lookup running past the end of the book data.
- No move returned in checkmate or stalemate at the root, or with a single legal move.
- Mate score encoding overflowing at long mate distances.
- Castling legality through attacked squares, en passant discovered-check edge cases, and promotion with capture.

### 8.4 `DEVIATIONS.md` entry format

```
## DEV-007: Search depth capped at original MAXPLY
Class: A
Original: $7F3C — ply counter indexes PLYTAB without a bound; depth ≥ 24 overwrites the move stack.
Trigger: `go infinite` from the start position on modern hardware reaches iteration 24.
Fix: iteration driver stops deepening at MAXPLY-1 (src/search.zig: iterate()).
Behaviour change when original worked: none (original never exceeded depth 23 in practice).
Test: tests/deviations/dev007.zig
```

---

## 9. UCI specification

### 9.1 Identity and options
```
id name Cyrus IS Chess
id author Richard Lang
option name Level type combo default UCI var UCI var Level 1 var Level 2 var Level 3 var Level 4 var Level 5 var Level 6 var Level 7 var Level 8 var Level P1 var Level P2 var Level P3
option name OwnBook type check default true
option name Seed type spin default 0 min 0 max 2147483647
```
- Combo values contain spaces. In `setoption name Level value Level 3`, the value is the rest of the line after `value`. Match it case-insensitively, and ignore unknown values with an `info string` warning.
- `Seed` 0 means seed from the clock.
- Do **not** advertise `Hash`, `Threads`, `MultiPV` or `Ponder`. The original has no equivalents, so there is no `Hash` option because there is no hash table.

### 9.2 Commands
- `uci`, `isready`, `ucinewgame`, `setoption`, `position [startpos | fen <fen>] [moves …]`, `go`, `stop`, `quit`, `debug`. Ignore `ponderhit` safely.
- `go` parameters: `wtime btime winc binc movestogo movetime depth nodes mate infinite searchmoves`.
- `searchmoves` is implemented through the original's next-best root-exclusion mechanism if Phase 1 shows it is suitable. Otherwise it is ignored with an `info string`. Never invent a new root restriction path.
- **Threading**: one I/O thread reads stdin. The search runs on one worker thread and polls an atomic stop flag **at the original's keyboard-poll point(s)**. `isready` must be answered promptly even while searching.
- `bestmove` is printed exactly once per `go`, including after `stop`, and is always legal (§8.2). After `stop`, the move played is the one the original would play when interrupted at that point.
- **No legal moves** (checkmate or stalemate at the root): `bestmove 0000`.

### 9.3 `info` output
- `info depth D seldepth S score cp X nodes N nps R time T pv …` after each completed iteration, plus `currmove`/`currmovenumber` if cheap.
- **Score conversion**: the original's units are converted to centipawns by one fixed factor, derived from its pawn value and documented in `UCI.md`. Mate scores become `score mate ±M`. This affects reporting only, never search.
- `info string` is used for rejections, fallbacks, book moves ("book move") and `NO MATE FOUND`.

### 9.4 Positions — reject what the original could not handle

`position` is processed in this order. The first failure rejects the whole command:

1. **Parse FEN** strictly. Malformed FEN is rejected.
2. **Original legality check**: run the *ported* set-up legality routine (§6 step 3.6) on the piece placement and side to move. Whatever the original rejects with `ILLEGAL` (no king, pawn on the back rank, impossible material, side not to move in check, plus any further conditions found in Phase 1) is rejected. Do not add stricter or looser checks of our own, except where FEN-level validity is required (e.g. two kings on one side, if the original doesn't check that). Log any such addition in `DEVIATIONS.md`.
3. **Castling rights**: the original can castle only with an untouched king and rook. A FEN castling right is accepted if the king and that rook are on their original squares. It then maps to the original's "unmoved" state, which is reachable in the original by setting up from the new-game position. A right whose king or rook is elsewhere is malformed FEN and is rejected. Whether the reverse case (K and R on home squares *without* the right) is representable depends on Phase 1. If it is not, reject.
4. **En passant square**: the original cannot accept an en passant capture right after set-up. It can reach the position the way the manual describes, by setting up the preceding position and playing the double pawn step. So reconstruct the predecessor (pawn back two squares, side to move flipped), check it with step 2, and play the double step through the original's move path. If the predecessor is invalid, reject.
5. **Moves**: apply `moves …` through the ported game-move path, which is the one the original uses for user moves. It accepts user under-promotions, as the manual states. Any move the original would refuse as `ILLEGAL` rejects the position.
6. **Counters**: the original restarts move numbering at 10 after set-up and has no way to enter a 50-move count. So FEN halfmove and fullmove fields are parsed but not loaded. Draw detection behaves exactly as the original's would after set-up plus the given moves. Document this in `UCI.md`. It is not a deviation.

**On rejection**: print `info string error: position rejected: <reason>`. Mark the engine as having no valid position, and on the next `go`, reply with `bestmove 0000`. Never crash, hang or silently substitute another position.

### 9.5 Levels and time

**`Level = UCI` (default):** time comes from the `go` parameters.
- `wtime/btime/winc/binc/movestogo` → a per-move budget fed into **the original's own termination mechanism**, in place of the level's time parameter. The rule is: target = remaining / (`movestogo`, or 30 if absent) + 0.75 × increment, then capped at 1/3 of remaining minus a fixed safety margin. Phase 1 may show the original uses a target plus a hard limit, or similar. In that case derive both from the clock with the same ratio the original's levels use, and record the formula in `UCI.md`.
- `movetime` → budget fixed at that value.
- `depth N`, `nodes N` → stop exactly when the original's iteration/node accounting reaches it. This is the deterministic test mode.
- `infinite` → search until `stop`.
- `mate N` with N = 1, 2 or 3 → the original problem-mode search P*N*. With N > 3 → `info string mate search limited to 3`, then search at P3.
- **Time-forfeit guard:** if the original only checks for termination between iterations, a late iteration can overrun badly at modern speeds. In that case, add a hard-limit check at the original's keyboard-poll point that behaves exactly like a keypress interrupt. This counts as a class B fix (missing move), so log it.

**`Level = Level 1 … Level 8`:** reproduce the original level exactly. The level's own parameters drive termination, using real wall-clock seconds in place of the Spectrum clock. `wtime/btime/winc/binc/movestogo/movetime/depth/nodes` are ignored. Clock safety is the user's choice when they select a fixed level. Two exceptions:
- `stop` acts as the keypress interrupt.
- `infinite` searches until `stop`, because UCI forbids sending `bestmove` before `stop` in infinite mode.

**`Level = Level P1/P2/P3`:** the original problem-mode search. It runs until it finds a mate or proves there is none, and `stop` interrupts it. If there is no mate, print `info string NO MATE FOUND` and send `bestmove 0000`, because the original makes no move. Time parameters are ignored.

**Opening book:** used in UCI and Levels 1–8 when `OwnBook` is true, exactly as the original uses it. The book is not used in problem levels unless Phase 1 shows the original does.

---

## 10. Testing strategy

All of the following run via `zig build test` (fast subset) or `zig build test-full`.

1. **Unit tests**: inline `test` blocks next to the code they test.
2. **Reference integrity**: hashes of `reference/` match `CHECKSUMS.txt`. Generated tables and book data match the binary byte for byte.
3. **Differential tests** (`tools/diff/`), Zig vs oracle: movegen order, make/unmake state, attack detection, set-up legality verdicts, exact evaluation, quiescence, fixed-depth search (move, score, PV, nodes), problem search, level termination with injected stop, and book selection. On mismatch the driver prints the first divergent node: the path from the root, both move lists and both scores.
4. **Perft**: compare against true perft *and* against oracle perft. Differences from true perft that the oracle shares are original behaviour. Classify each as B (reaches output, fix at root) or C (internal, preserve).
5. **Protocol tests**: scripted UCI sessions, including:
   - `stop` immediately after `go`; `go wtime 10`; `isready` mid-search;
   - every `Level` value, including switching levels between games;
   - `go mate 1..5`; `go infinite` under a fixed level; `searchmoves`;
   - rejected positions followed by `go` (expect `bestmove 0000`);
   - repeated `position`/`go` without `ucinewgame`; malformed input.
6. **Rejection corpus** (`tests/positions/reject.epd`): positions with the expected verdict and reason, covering every condition in §9.4.
7. **Stress and match tests**: self-play and gauntlets under `fastchess`, so any crash or illegal move is a failure. Run with the `ReleaseSafe` build.
8. **Corpora** in `tests/positions/`: `opening.epd`, `middlegame.epd`, `endgame.epd`, `tactics.epd`, `mate1-3.epd` (problem levels, including no-mate cases), `edge.epd`, `reject.epd`, and `searchtree.epd` (positions harvested from inside oracle search trees).

---

## 11. Zig conventions

- Zig 0.17.0 (§5). Run `zig fmt` before committing.
- **No heap allocation in the search path.** All engine state lives in fixed-size arrays sized by `src/limits.zig`. Those sizes mirror the original's capacities plus any class-A fixes.
- Use explicit integer types that match the original's widths (`u8`, `i8`, `u16`, `i16`). Use `+%`, `-%` and `*%` only where the original wraps *and* behaviour depends on it, and leave a comment saying so. Everywhere else, use normal operators so safety checks stay active.
- Use `@intCast`/`@truncate` deliberately, with a comment when narrowing is intended original behaviour.
- Use descriptive Zig names, and put the original disassembly label and address in the doc comment.
- Use `comptime` only for *derived* values. Values extracted from the binary are generated into source files by `tools/extract`, so they can be reviewed in diffs.
- Errors: UCI and FEN parsing return error unions and never panic. The ported core uses `unreachable` only where the original's logic guarantees it, and that must be proved by tests.
- Build modes: `Debug`/`ReleaseSafe` for development and testing, `ReleaseFast` for release.

---

## 12. How to work a task

1. Pick the next unverified row in `docs/PORT_STATUS.md`. Do not skip ahead of the phase order.
2. Read the relevant disassembly section and `ORIGINAL_ARCHITECTURE.md`. If the architecture document is wrong or incomplete, fix it first, citing addresses.
3. Write the differential test first, then the port.
4. Iterate until the test matches the oracle on the full corpus. A mismatch is *always* assumed to be a porting error until the oracle trace proves otherwise.
5. Update `PORT_STATUS.md`. Add `DEVIATIONS.md` and `OBSERVATIONS.md` entries if relevant.
6. Commit small, with messages like `port: GENMOV captures ($7A10–$7A6F), oracle-verified on 52k positions`.

**Definition of done for any ported routine:** it cites its original address, is oracle-verified on the full corpus, has no `UNVERIFIED` tags, adds no safety panics under stress, and has an up-to-date status row.

When you are stuck, write down what you know, what you tried and the exact address in question in `docs/OPEN_QUESTIONS.md`. Do not paper over it with a guess.

---

## 13. Decisions

### Recorded (project owner, 2026-10-21)
1. **Canonical release:** Sinclair Research 1983 original, 48K side, `reference/original/CyrusISChess-48k.tzx`.
2. **Binaries:** committed to the repository. The program is treated as abandonware.
3. **Illegal moves:** fixed (class B, §8.2).
4. **Unsupported positions:** rejected, not accommodated (class D, §9.4).
5. **Levels:** exposed as the UCI combo option `Level`. The default is `UCI` (standard UCI time controls), followed by `Level 1`–`Level 8` and `Level P1`–`P3` (§9.5).
6. **UCI identity:** `id name Cyrus IS Chess`, `id author Richard Lang`.

### Open
1. **What a fixed level means on modern hardware.** By default, `Level N` uses the original's *time* parameters in real seconds. Because modern hardware is about 10⁴× faster, Level 1 will search far deeper, and play far stronger, than on a Spectrum. The alternative is *Spectrum-equivalent* levels: stop at the node count the original would have reached in that time. This would be calibrated from oracle T-state measurements, and it would reproduce the historical playing strength and even the historical moves. That could be offered as extra combo values (e.g. `Level 2 (Spectrum speed)`). It needs an owner decision before Phase 5.
