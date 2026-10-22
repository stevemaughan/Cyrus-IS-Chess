# Port status

One row per port unit, in Phase 3 order (AGENTS.md Â§6).

| Column | Meaning |
|---|---|
| Spec | Phase 1 document |
| Model | Python model verified against the original (`tools/research/`) |
| Golden | oracle golden files covering the unit (`tests/golden/`) |
| Zig | Zig location |
| Verified | Zig output matches the golden files |

| Step | Unit | Original routines | Spec | Model | Golden | Zig | Verified |
|---|---|---|---|---|---|---|---|
| 3.1 | Tables, book data | `$7800â€“$780F`, `$9000â€“$9BCC` | 20, 25 | n/a | the binary | â€“ | â€“ |
| 3.2 | State structures, new game, set-up / slot assignment, FEN loading, operator script | `$6505`, `$658Eâ€“$6690`, `$6ECC`, `$6F99`, `$660A`/`$8203`, `$695D` | 10 Â§6.3, AGENTS Â§9.4/Â§9.6 | â€“ | `search` (state at each `go` after `load`/`continue`), `reject`, `edge` | â€“ | â€“ |
| 3.3 | Make / unmake | `$810F`, `$821C`, `$8200`, `$826E` | 20 Â§4.3â€“4.5 | `movegen/makeunmake.py` (checks) | indirect: `search` make sequences | â€“ | â€“ |
| 3.4 | Move generator | `$78CE`â€“`$7AC6` | 20 Â§4.2 | `movegen/compare.py` | `search`/`edge`/`book` root lists (`root`, `root_count`) | â€“ | â€“ |
| 3.5 | Pre-search set-up | `$7810`, `$789D` | 20 Â§4.1 | â€“ | indirect: `search` | â€“ | â€“ |
| 3.6 | Set-up legality check | `$6ECC`, AssignSlot, `$7810` â†’ `$8400` | 10 Â§6.3 | â€“ | `reject`, `edge` | â€“ | â€“ |
| 3.7 | Evaluation | `$8400â€“$8F2E` | 50 | `eval/evalmodel.py` | `eval` (30,000); root static scores in `search` (`root_scored`) | â€“ | â€“ |
| 3.8 | Static scoring, pick-best, find-move | `$7B96`, `$8015`, `$7BCD` | 30 Â§4 | `search/model.py` | `search` | â€“ | â€“ |
| 3.9 | Search, pruning, extensions; all levels and P1â€“P3 | `$7BE1`â€“`$80A6`, `$80A7`â€“`$810E` | 30 Â§4â€“5 | `search/model.py` | `search` (â‰¥ 74 per level; ~600 per level for Levels 1â€“5), `edge` | â€“ | â€“ |
| 3.10 | Abort at node N | `$78BA` | 30 Â§6 | `search/model.py` | `abort` (400 searches interrupted at a random node) | â€“ | â€“ |
| 3.11 | Opening book | `$7AC7`â€“`$7B95` | 25 | `tools/scripts/book_dump.py` | `book` (all positions Ã— 2), `search` | â€“ | â€“ |
| 3.12 | Game-move path (PlayMove, 50-move, repetition tracking) | `$6323`, `$6560` | 10 Â§5, Â§6.5 | â€“ | `search` (`game`/`multi` sessions) | â€“ | â€“ |
| 3.13 | Extended driver: pass schedule, per-ply storage | generalises `$7BE1`/`$7BF1` | EXTENDED_SEARCH Â§2â€“3 | â€“ | anchors vs `search` Levels 1/2/6/7/8 | â€“ | â€“ |
| 5 | Time management, PV reporting, pondering, checkpoints | new | EXTENDED_SEARCH Â§4â€“6, AGENTS Â§9.6 | n/a | protocol tests | â€“ | â€“ |
