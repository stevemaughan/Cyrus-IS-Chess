# Research scripts (Phase 1)

These are the probes and Python reference models used to reverse-engineer the original and verify the specifications in `docs/arch/`. They drive the original code in SkoolKit's Z80 simulator. Treat them as executable specifications: each model was checked against the original and found identical.

**Requirements:** Python 3 with `skoolkit` (10.1) and `chess` (python-chess, used only as an independent legality reference): `python -m pip install skoolkit chess`. Scripts write scratch snapshots to their own `work/` folder (git-ignored).

| Folder | Verified model | Check it with |
|---|---|---|
| `movegen/` | `compare.py` (`model()`): move generator order and flags | `python tools/research/movegen/compare.py SEED N` compares N random positions with the original and python-chess. `makeunmake.py` checks make/unmake round trips |
| `book/` | `tools/scripts/book_dump.py` (decoder); `book-uci.txt` lists every book line in UCI notation | `python tools/scripts/book_dump.py --check-replay` |
| `search/` | `model.py`: a full transliteration of the search, driving the original primitives | `python tools/research/search/mkpos2.py` makes mid-game snapshots, then `python tools/research/search/model.py tools/research/search/work/late152.z80 5`. Expect "IDENTICAL make sequence" |
| `eval/` | `evalmodel.py`: a standalone evaluation (`evaluate(mem, ix)`) | `python tools/research/eval/fuzz.py reference/snapshots/cyrus48-idle-level1.z80 300 11`. Expect "300 match, 0 differ" |

These scripts were written quickly during analysis. They are not polished tools, but they are kept because they are the evidence behind the `[V]` claims.
