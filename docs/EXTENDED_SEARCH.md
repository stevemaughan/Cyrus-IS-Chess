# Extended search: Cyrus at any depth

**Owner decision, 2026-10-21:** the engine may search deeper than the original and must support every UCI `go` command, which requires iterative deepening and time management. The guiding question is: *if the original engine had been able to search 20 ply, what would it have looked like?* The evaluation and the search algorithm are kept faithful (move ordering, extensions, pruning, scoring); only the depth limit, the iteration loop and time control are new.

This document specifies the generalisation precisely. It builds on [arch/30-search.md](arch/30-search.md); section references (§4 etc.) are to that document.

## 1. Two modes

| Mode | `Level` option | Behaviour | Verified against |
|---|---|---|---|
| **Original** | `Level 1` … `Level 8`, `Level P1` … `P3` | Exactly the original: fixed passes, original switches, original capacities, clock ignored, `stop` = key press | Oracle golden files (identical make sequences and results) |
| **Extended** | `UCI` (default) | Iterative deepening over the original's own pass mechanism, any depth up to `MAX_DEPTH`, with time management | Oracle golden files at the anchor depths (§3); self-consistency and robustness beyond them |

Both modes run **the same ported code**. Original mode is extended mode with the original's pass schedule and capacities. Any difference between the two outside §2 is a bug.

## 2. What generalises, and how

The port does not preserve the memory layout (AGENTS.md §13, decision 8). It uses its own data structures and reproduces only the *behaviour*. The original's limits that tie behaviour to ply ≤ 7 are generalised as follows. Each generalisation **behaves identically whenever the original's limits are not exceeded**.

| Original | Limit | Generalisation |
|---|---|---|
| Full-width depth D from the level parameter: `a==0 ? 1 : a<4 ? 2 : a==4 ? 3 : 4` (`$7C71`) | D ≤ 4 | D is set per pass by the driver (§3). The *switches* still come from a level parameter `a` (§3) |
| Maximum ply D+3 (selective extensions stop at D+2, rarely D+3) | 7 | Unchanged rule relative to D. `MAX_DEPTH` = 60, so the maximum ply is 63 |
| Per-ply tables: values V(q), killers (reset per pass), current move, list start | q ≤ 8 | Arrays indexed by ply, sized `MAX_DEPTH+4`. The killer reset clears all plies. List starts for deeper plies persist between lines and searches, because the original reads them stale (`L7F20`, `L7EB6`) |
| Move-list storage `$B400–$BC7F`; a full area sets the abort flag (`$7AAF`) | 544 entries (2,176 bytes) | Lists are stored contiguously in the original format (4-byte header, then 4-byte entries) and measured in byte offsets from the root list. **Original mode** keeps the 2,176-byte capacity and its abort. **Extended mode** allows 32,768 entries, with the same abort at that limit |
| List-size tests on addresses: high byte of slot(4) `== $B4` (`L7F20`), high byte of slot(6) `== $B4` (`L7EB6`), low byte of slot(5) `≥ $58` | — | Use offsets: `offset(slot4) < 256`, `offset(slot6) < 256`, `offset(slot5) mod 256 ≥ $58`. The root list starts at `$B400`, whose low byte is 0, so these are exactly the original tests. That includes the mod-256 quirk of the third |
| Selective-node marker `$BD4E = $A9+2p` (8-bit), later overwritten by the evaluation | p ≤ 7 | Same formula, same last-writer-wins. It wraps mod 256, but is odd and so never 0 for any p, so it is still non-zero as the search requires |
| Header count byte (DEV-001) | n ≤ 126 | DEV-001 fix (the true count) |
| Undo data on the Z80 stack | ~ply 20 before it would hit the board | An undo stack sized for `MAX_DEPTH+4` |
| Mate plies `$BD0B`/`$BD0C`, ply `$BCA9`, depth `$BCAA` | 8-bit | Unchanged; values stay < 64 |

The other decision-relevant behaviour is reproduced as listed in AGENTS.md §6 Phase 3: off-board-column reads, slot order, persistent variables and the game record.

## 3. Iterative deepening = the original's pass mechanism, repeated

The original Levels 6–8 already run two passes (§4 `PASS`, `$BD6E`):
- **Pass 1** uses parameter `a = 1`, i.e. Level 2: D = 2, forward pruning on, no threat extensions.
- Before **pass 2** (`a` = 5/6/7, D = 4), the pass-1 best move's score byte is set to `$FD`, so it is searched first. `$BD29` keeps the pass-1 result until a pass-2 root move completes with a value.

Extended mode generalises this into an iteration loop:

```
profile a ∈ {5, 6, 7}             # "Profile" option: Level 6 / Level 7 / Level 8 (default 7 = Level 8)
schedule:
    pass 1: a = 1, D = 2          # identical to the original pre-pass (= Level 2)
    pass k ≥ 2: a = profile, D = 4, 5, 6, …, ≤ MAX_DEPTH
              (D = 3 is used only when "go depth 3" asks for it)
between passes: mark the previous pass's best root move $FD   # original second-pass branch
each pass: everything else exactly as PASS (§4): regenerate and re-score the root, book probe,
           repetition pre-selection, exclusion list, margin $BD09, killers reset, V reset
```

The schedule has these properties:
- **Anchors.** After pass 1 the result is exactly original Level 2. After the D = 4 pass it is exactly original Level 6/7/8 for the chosen profile (same `$BCCE`, same state). The oracle checks both on every golden position.
- **Switches beyond D = 4** come from the profile's `a`:
  - `$BDF6` = `a` if `a & 2` (threat extensions on for Levels 7 and 8);
  - `$BD09` bit 7 if `a & 1` (forward pruning **off** for Level 8).

  The pruning margin, futility parity (`FUTILITY`: odd D never prunes), selective-ply extension limits (D+1, D+2, D+3) and the small-list extensions all use D exactly as written in §4.
- **Abort safety is inherited.** In passes ≥ 2, `$BD29` is not reset, so an abort at any point plays either the previous pass's best or a better move completed in the current pass. That is the original's own interruption semantics.
- `go depth 1` runs a single pass with `a = 0` (original Level 1). `go depth 2` runs pass 1 only (original Level 2).

## 4. Time management

**Budget** (per move, milliseconds):

```
if movetime: soft = hard = movetime − overhead
else:
    t = our clock, inc = our increment, mtg = movestogo or 30
    soft = t / mtg + 0.75·inc
    hard = min(5·soft, t/3) − overhead            # overhead ≈ 30 ms, the UCI option "Move Overhead"
```

**Control:**
- **Between passes:** start the next pass only if `elapsed + predicted(next) ≤ soft`. Here `predicted(next)` = duration(last pass) × the larger of (the ratio of the last two passes, 3), and before two passes exist, 0.
- **Within a pass:** at each node entry (the `$78BA` poll point) check the stop flag and, every 1,024 nodes, the clock. If `elapsed ≥ hard` or `stop` was received, set `$BD4C` bit 7 (DEV-007). The search then unwinds exactly as after a key press.
- **Single legal root move:** play it after pass 1, unless `go infinite`, `ponder` or a depth/nodes/mate limit asks for more.
- **Book move:** played immediately (the original returns from the pass at once).

## 5. UCI `go` commands in extended mode

| Command | Behaviour |
|---|---|
| `wtime btime winc binc movestogo` | §4 |
| `movetime T` | §4 |
| `depth N` | schedule up to D = N (N ≤ `MAX_DEPTH`); no time limit |
| `nodes N` | schedule until the node counter (entries to `$7D43` + root makes) reaches N, then abort as a key press |
| `mate N` | schedule until `$BCA0 ≥ $FE` with a mate of ≤ N moves (from `$BD0C`), or until D ≥ 2N+1; no time limit unless clock parameters are also given |
| `infinite` | schedule until `stop`; `bestmove` is held until `stop` even if `MAX_DEPTH` is reached |
| `ponder` | as `infinite` until `ponderhit` (which switches to §4 with the clock values given in the `go ponder` command, measured from the ponderhit) or `stop` |
| `searchmoves m…` | every root move not listed is put on the original's exclusion list `$BF00` (§7 of the search spec) |

Several parameters combine; the first limit reached stops the search.

## 6. Reporting (no effect on search)

- After each completed pass: `info depth D seldepth S score … nodes N nps … time … pv …`. Also `currmove`/`currmovenumber` at the root, at most once per second.
- **PV:** the original keeps no principal variation. The port maintains a **reporting-only** triangular PV table, updated where the original raises alpha (`L7E49` `V(p) = A`, `L7F5B`). It is never read by the search.
- **Score:** cp = (`$BCA0` − `$80`) × 100 / 8 from the engine's view. `$BCA0` ≥ `$FE` → `mate +⌈$BD0C/2⌉`; a root value of 1 or 2 → `mate −…` when a forced loss is detected.
- **`bestmove`:** the move at `$BD29`. It carries `ponder` with the PV's second move when the PV has one.

## 7. What extended mode must never do

- Change move ordering, extensions, pruning, evaluation, scoring, or the treatment of draws and mates.
- Add a transposition table, history heuristic, null move, late-move reductions, aspiration windows, mate-distance scoring, or repetition detection inside the tree.
- Read the clock or the stop flag anywhere except the `$78BA` poll point.

## 8. Verification

1. **Anchors:**
   - for every golden search position, extended mode with `go depth 2` = original Level 2;
   - with `go depth 4` and profile Level 6/7/8 = original Level 6/7/8 (make sequence, `$BD29`, `$BCA0`, counts);
   - `go depth 1` = Level 1.
2. **Original mode** keeps matching the oracle exactly (Phase 3 golden tests: make sequences, moves, values).
3. **Deep searches** (D up to 20+, long `go infinite`): no safety panics, no list overflow aborts in normal positions, legal output, and monotone pass completion.
4. **Generalisation unit tests:** with D ≤ 4, extended-mode structures (larger capacity) produce the same make sequences as original mode.
