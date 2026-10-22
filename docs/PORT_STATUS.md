# Port status

One row per port unit, in Phase 3 order (AGENTS.md §6).

| Column | Meaning |
|---|---|
| Spec | Phase 1 document |
| Model | Python model verified against the original (`tools/research/`) |
| Golden | oracle golden files covering the unit (`tests/golden/`) |
| Zig | Zig location |
| Verified | Zig output matches the golden files |

| Step | Unit | Original routines | Spec | Model | Golden | Zig | Verified |
|---|---|---|---|---|---|---|---|
| 3.1 | Tables, book data | `$7800–$780F`, `$9000–$9BCC` | 20, 25 | n/a | the binary | `src/tables.zig` | ✅ embedded from the binary |
| 3.2 | State structures, new game, set-up / slot assignment, FEN loading, operator script | `$6505`, `$658E–$6690`, `$6ECC`, `$6F99`, `$660A`/`$8203`, `$695D` | 10 §6.3, AGENTS §9.4/§9.6 | – | `search` (state at each `go` after `load`/`continue`), `reject`, `edge` | `src/state.zig`, `src/game.zig` | ✅ every session of `search` (2,000), `book` (4,572) and `edge` replayed through `Session` reaches the original's full state at every computer move. The 35 edge sessions with ≥ 127 moves match on game fields only (DEV-001) |
| 3.3 | Make / unmake | `$810F`, `$821C`, `$8200`, `$826E` | 20 §4.3–4.5 | `movegen/makeunmake.py` (checks) | `board` (17,694 makes through the original) | `src/board.zig` | ✅ all 17,694; 285,188 round trips |
| 3.4 | Move generator | `$78CE`–`$7AC6` | 20 §4.2 | `movegen/compare.py` | `search`/`edge`/`book` root lists (`root`, `root_count`) | `src/movegen.zig` | ✅ 8,768 lists; the 35 with ≥ 127 moves differ only in the count (DEV-001) |
| 3.5 | Pre-search set-up | `$7810`, `$789D` | 20 §4.1 | – | `presearch` (4,028 calls) | `src/presearch.zig` | ✅ all 4,028 |
| 3.6 | Set-up legality check | `$6ECC`, AssignSlot, `$7810` → `$8400` | 10 §6.3 | – | `reject`, `edge` | `src/game.zig` | ✅ all rejections and acceptances, with reasons |
| 3.7 | Evaluation | `$8400–$8F2E` | 50 | `eval/evalmodel.py` | `eval` (30,000); root static scores in `search` (`root_scored`) | `src/eval.zig` | ✅ all 24,107 representable records. The other 5,893 fuzz records put junk in off-board bytes that hold no variable |
| 3.8 | Static scoring, pick-best, find-move | `$7B96`, `$8015`, `$7BCD` | 30 §4 | `search/model.py` | `search` (`root_scored`) | `src/scoring.zig`, `src/search.zig` | ✅ |
| 3.9 | Search, pruning, extensions; all levels and P1–P3 | `$7BE1`–`$80A6`, `$80A7`–`$810E` | 30 §4–5 | `search/model.py` | `search` (≥ 74 per level; ~600 per level for Levels 1–5), `edge`, `book` | `src/search.zig` | ✅ 4,028 + 4,572 + 133: identical make sequences (SHA-256), counts, moves, values. The 35 edge positions with ≥ 127 moves are excluded (DEV-001) |
| 3.10 | Abort at node N | `$78BA` | 30 §6 | `search/model.py` | `abort` (400 searches interrupted at a random node) | `src/search.zig` | ✅ all 400 |
| 3.11 | Opening book | `$7AC7`–`$7B95` | 25 | `tools/scripts/book_dump.py` | `bookprobe` (8,600 probes as the probe sees them) | `src/book.zig` | ✅ all 8,600 (original behaviour); DEV-002/003 fixes tested |
| 3.12 | Game-move path (PlayMove, 50-move, repetition tracking) | `$6323`, `$6560` | 10 §5, §6.5 | – | `search` (`game`/`multi` sessions) | `src/game.zig` | ✅ (full-state match through multi-move sessions) |
| 3.13 | Extended driver: pass schedule, per-ply storage | generalises `$7BE1`/`$7BF1` | EXTENDED_SEARCH §2–3 | – | anchors vs `search` Levels 1/2/6/7/8 | `src/driver.zig` | ✅ anchors identical: 1,862 search + 57 edge + 4,572 book + 195 abort cases. Depth 6–8 robustness on 30 positions (`-Ddeep=true`) |
| 5 | Time management, search information, legality net, random sources, pondering, checkpoints, UCI | new | EXTENDED_SEARCH §4–6, AGENTS §9 | n/a | protocol tests | `src/timeman.zig`, `info.zig`, `legal.zig`, `rng.zig`, `engine.zig`, `uci.zig` | ✅ unit tests; the info observer leaves every anchor hash unchanged; `tools/scripts/uci_smoke.py` 41/41 |
