# Oracle (Phase 2)

The oracle runs the **original Cyrus IS Chess code** in SkoolKit's Z80 simulator and writes golden files in `tests/golden/`, which the Zig tests compare against (AGENTS.md §6 Phase 2). Python is needed only to regenerate golden files.

**Requirements:** Python 3 with `skoolkit` 10.1 and `chess` (python-chess). python-chess is used only to choose random legal moves and FENs for the corpus, never as a reference for the engine's behaviour.

## Files

| File | Purpose |
|---|---|
| `oracle.py` | `Oracle`: one simulated Spectrum. It drives the original through its own key handling (`WaitKey`), enters moves with the cursor, loads FENs through CHANGE POSITION mode (canonical construction, AGENTS.md §9.4), captures state, and runs computer moves with hooks. `Session`: the canonical operator script that maps UCI usage onto the original's UI (AGENTS.md §9.6) |
| `golden_search.py` | Random scripted sessions (game prefixes, FEN set-ups, games against a random opponent with automatic replies, multi-move continuations) → `tests/golden/search.jsonl`. `--epd FILE` searches each FEN at several levels instead |
| `golden_eval.py` | Evaluation fuzz cases and samples from real searches → `tests/golden/eval.jsonl` |
| `edge_fens.py` | Writes `tests/positions/edge.epd`: many-move positions, castling and en passant variants, promotions, mates |
| `verify_state.py` | Re-runs every computer move of a search golden file from its captured state in a fresh machine. Identical results prove the state record is complete |
| `verify_eval.py` | The same for evaluation golden files, plus a cross-check against `tools/research/eval/evalmodel.py` |

## Golden files (`tests/golden/`, gzip-compressed JSON lines)

| File | Made with | Contents |
|---|---|---|
| `search.jsonl.gz` | `golden_search.py … --sessions 2000 --seed 1` | 2,000 sessions, 4,028 computer moves, all levels |
| `edge.jsonl.gz` | `golden_search.py … --epd tests/positions/edge.epd` | 24 edge positions × 7 levels |
| `reject.jsonl.gz` | `golden_search.py … --epd tests/positions/reject.epd` | 17 positions the port must reject |
| `book.jsonl.gz` | `golden_search.py … --book tools/research/book/book-uci.txt` | every book position × 2 random inputs |
| `eval.jsonl.gz` | `golden_eval.py … --fuzz 20000 --samples 10000 --seed 1` | 30,000 evaluations |
| `abort.jsonl.gz` | `golden_abort.py tests/golden/search.jsonl.gz … --count 400` | searches re-run from their state with a key press at a random node (`$78BA`) |
| `board.jsonl.gz` | `golden_board.py` | 17,694 makes (and unmakes) through the original `$810F`/`$821C` from captured states |
| `bookprobe.jsonl.gz` | `golden_bookprobe.py` | 8,600 book probes: exactly what `$7AC7` reads and what it leaves |

All were checked with `verify_state.py` / `verify_eval.py`: every record re-runs identically from its captured state.

## Golden record formats

**State** (`Oracle.capture_state`). Hex strings of original variables in address order. The port maps each byte to the field holding that original variable; `docs/arch` gives the meanings.

| Field | Contents |
|---|---|
| `pieces` | `$BE00–$BEFF`: 32 piece records × 8 bytes (Black slots, then White) |
| `board` | 64 squares, rank 8 first (`$BD00 + row·16 + file`) |
| `offboard` | the variables in the board's off-board columns (`$BD08–$BD0F + row·16`) |
| `bc83` | `$BC83–$BCFF`: search tables (killers, values, list starts) and global variables, including `$BCCE` and the level |
| `bdf6` | `$BDF6` |
| `exclusion` | the next-best list at `$BF00`, as pairs |
| `c000` | `$C000–$C057`: game-record header, start position, promotions |
| `record` | the game record from `$C058`, `$FF`-terminated |

**Search record** (one line per session):
```json
{"seed": …, "kind": "prefix|fen|game|multi|epd", "session": [ops], "goes": [
   {"level": "Level 5", "state": {…}, "legal": true,
    "out": {"result": "move|nomoves|nomate|draw", "move": "e2e4", "index": n,
            "book": false, "make_sha256": "…", "makes": n, "evals": n, "nodes": n,
            "r_used": n, "BCA0": n, "BD0C": n, "bcce_after": n,
            "root_count": n, "root": [[from, to, flags], …], "root_scored": [[score, flags], …]}}]}
```
Each op is `load` (fen or null, moves), `go` (level index 0–10, `bcce`, `r`: the bytes substituted for the book's `LD A,R`) or `continue` (moves).
- **`make_sha256`** is the SHA-256 of the bytes (ply, from, to) of every call to make (`$810F`) from ComputerMove to the move played. Squares are internal 0x88 numbers (row 0 = rank 8).
- **`state`** is captured when ComputerMove starts, after `$BCCE` has been set to `bcce`.

**Evaluation record:** `{"src": "fuzz|sample", "state": {…}, "ix": "4 bytes", "out": {"A", "B", "ix3", "BCCE", "BD4E", "BD39", "BD3A"}}`.

## Determinism

The original never reads a clock while thinking, and its only randomness is the `R` register (book) and `$BCCE`. The oracle sets `$BCCE` at ComputerMove and substitutes the book's `R` reads, so regenerating any golden file is byte-identical.
