# Open questions

Unresolved points about the original, each with the addresses involved. To close one, record the answer (with evidence) and move it to "Resolved".

1. **When can `$BD4E` be zero after an evaluation?** If it is, `$7F27` extends unconditionally. The evaluation clears it on a double check (`$8D44`). Are there other cases? (C/E.) The search golden files exercise it either way; the port must reproduce the evaluation's writes to `$BD4E` exactly.
2. **`ReplayStep` skips `$8400`.** Does a game replayed by take-back or forward differ from the same game played live (check flags, `$BCCE`)? This no longer matters for the port: it never replays; the operator script enters every move live (AGENTS.md §9.6).
3. **`$BD4A` drift.** `$7810` adds the positional term B to `$BD4A` on every computer move; only a new game or set-up resets it. Over a long game it can drift far enough for the evaluation's 8-bit arithmetic to wrap (50-eval §8.2). Measure the observed range in long `game` sessions of the search golden. The port reproduces the drift either way.

## Resolved

- **Castling through an attacked square, and other illegal root moves** (was #1). Evidence from `tests/golden/edge.jsonl.gz`, which generates and scores root lists in the original:
  - In `r3k2r/ppp2ppp/8/8/8/5b2/PPPP1P1P/R3K2R w KQkq`, O-O-O passes the attacked d1, and root scoring gives it 0: the transit-square trick in make (`$81EA`) works.
  - In a position where the side to move is in check, castling is not generated at all. The set-up check's call to `$7810` → `$8400` sets the in-check flag in the last-move record `$BD5B`, which the generator tests.
  - Every pseudo-legal move that leaves the king in check, including a pinned en passant capture, scores 0.
  - In 4,028 searches of the main corpus and all 2,685 book entries except the known DEV-002 entry, the original never played an illegal move.

  DEV-005 therefore stays as a safety net (a legality assertion plus the fallback), not as a behaviour change.
- **Can the off-board column bytes be non-zero while the evaluation or move generator reads them?** (was #2) These reads come from a/h-file pieces: pawn captures, king neighbours, and the castled-king shelter.
  - **Data:** at evaluation entry, every byte in files 8 and 15 (`$BDx8`, `$BDxF`) was 0 in all 10,000 evaluations sampled inside real searches (`tests/golden/eval.jsonl.gz`), and in all 4,028 search start states.
  - **Code:** only two of those addresses hold variables that code writes:
    - `$BD58`, the root move record +0, addressed through `IX = $BD58`;
    - `$BD7F`, which lies inside the pin list `$BD79–$BD85` that the evaluation writes *during* the same call (pin entry 3's record byte).
  - **Port:** an off-board read returns the current value of the variable that aliases that byte (`$BD58`, `$BD7F`), and 0 elsewhere (AGENTS.md §6 Phase 3). The evaluation fuzz golden includes junk in these columns and checks this behaviour.
