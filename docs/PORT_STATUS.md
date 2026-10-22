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
| 3.1 | Tables, book data | `$7800–$780F`, `$9000–$9BCC` | 20, 25 | n/a | the binary | – | – |
| 3.2 | State structures, new game, set-up / slot assignment, FEN loading, operator script | `$6505`, `$658E–$6690`, `$6ECC`, `$6F99`, `$660A`/`$8203`, `$695D` | 10 §6.3, AGENTS §9.4/§9.6 | – | `search` (state at each `go` after `load`/`continue`), `reject`, `edge` | – | – |
| 3.3 | Make / unmake | `$810F`, `$821C`, `$8200`, `$826E` | 20 §4.3–4.5 | `movegen/makeunmake.py` (checks) | indirect: `search` make sequences | – | – |
| 3.4 | Move generator | `$78CE`–`$7AC6` | 20 §4.2 | `movegen/compare.py` | `search`/`edge`/`book` root lists (`root`, `root_count`) | – | – |
| 3.5 | Pre-search set-up | `$7810`, `$789D` | 20 §4.1 | – | indirect: `search` | – | – |
| 3.6 | Set-up legality check | `$6ECC`, AssignSlot, `$7810` → `$8400` | 10 §6.3 | – | `reject`, `edge` | – | – |
| 3.7 | Evaluation | `$8400–$8F2E` | 50 | `eval/evalmodel.py` | `eval` (30,000); root static scores in `search` (`root_scored`) | – | – |
| 3.8 | Static scoring, pick-best, find-move | `$7B96`, `$8015`, `$7BCD` | 30 §4 | `search/model.py` | `search` | – | – |
| 3.9 | Search, pruning, extensions; all levels and P1–P3 | `$7BE1`–`$80A6`, `$80A7`–`$810E` | 30 §4–5 | `search/model.py` | `search` (≥ 74 per level; ~600 per level for Levels 1–5), `edge` | – | – |
| 3.10 | Abort at node N | `$78BA` | 30 §6 | `search/model.py` | `abort` (400 searches interrupted at a random node) | – | – |
| 3.11 | Opening book | `$7AC7`–`$7B95` | 25 | `tools/scripts/book_dump.py` | `book` (all positions × 2), `search` | – | – |
| 3.12 | Game-move path (PlayMove, 50-move, repetition tracking) | `$6323`, `$6560` | 10 §5, §6.5 | – | `search` (`game`/`multi` sessions) | – | – |
| 3.13 | Extended driver: pass schedule, per-ply storage | generalises `$7BE1`/`$7BF1` | EXTENDED_SEARCH §2–3 | – | anchors vs `search` Levels 1/2/6/7/8 | – | – |
| 5 | Time management, PV reporting, pondering, checkpoints | new | EXTENDED_SEARCH §4–6, AGENTS §9.6 | n/a | protocol tests | – | – |
