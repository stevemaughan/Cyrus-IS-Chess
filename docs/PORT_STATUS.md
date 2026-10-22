# Port status

One row per port unit, in Phase 3 order (AGENTS.md §6).

| Column | Meaning |
|---|---|
| Spec | Phase 1 document |
| Model | Python model verified against the original (`tools/research/`) |
| Zig | Zig location |
| Oracle | Zig output verified against the oracle |

| Step | Unit | Original routines | Spec | Model | Zig | Oracle |
|---|---|---|---|---|---|---|
| 3.1 | Tables: direction tables, book data | `$7800–$780F`, `$9000–$9BCC` | 20, 25 | n/a | – | – |
| 3.2 | Memory image, new game, set-up / slot assignment, FEN loading | `$6505` InitBoard, `$658E–$6690` set-up/AssignScan, `$6F99`, `$660A`/`$8203` | 10 §6.3, 20 | – | – | – |
| 3.3 | Make / unmake | `$810F`, `$821C`, `$8200`, `$826E` | 20 §4.3–4.5 | `movegen/makeunmake.py` (checks) | – | – |
| 3.4 | Move generator | `$78CE`–`$7AC6` | 20 §4.2 | `movegen/compare.py` | – | – |
| 3.5 | Pre-search set-up | `$7810`, `$789D` | 20 §4.1 | – | – | – |
| 3.6 | Set-up legality check | `$6ECC` SetupExit, AssignSlot, `$7810` → `$8400` | 10 §6.3 | – | – | – |
| 3.7 | Evaluation | `$8400–$8F2E` | 50 | `eval/evalmodel.py` | – | – |
| 3.8 | Static scoring, pick-best, find-move | `$7B96`, `$8015`, `$7BCD` | 30 §4 | `search/model.py` | – | – |
| 3.9 | Search state machine, pruning, extensions | `$7BE1`–`$80A6`, `$80A7`–`$810E` | 30 §4 | `search/model.py` | – | – |
| 3.10 | Problem levels | same as 3.9 (levels 0/3/7) | 30 §5, 10 §6.7 | `search/model.py` | – | – |
| 3.11 | Levels and termination | `$7C44`–`$7CB7`, `$78BA` | 30 §5–6 | `search/model.py` | – | – |
| 3.12 | Opening book | `$7AC7`–`$7B95` | 25 | `tools/scripts/book_dump.py` | – | – |
| 3.11 | Game-move path (PlayMove, 50-move, repetition tracking) | `$6323`, `$6560` | 10 §5, §6.5 | – | – | – |
| 3.12 | Extended driver: pass schedule, relocated per-ply storage | generalises `$7BE1`/`$7BF1` | EXTENDED_SEARCH §2–3 | – | – | anchors vs Levels 1/2/6/7/8 |
| 5 | Time management, PV reporting, pondering, checkpoints | new | EXTENDED_SEARCH §4–6, AGENTS §9.6 | n/a | – | protocol tests |
