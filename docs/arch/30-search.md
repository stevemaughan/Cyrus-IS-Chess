# Search ($7B96–$80A6)

Subsystem C. Annotated control file: `disasm/ctl/30-search.ctl`. Tags: **[V]** verified (code read and confirmed in the simulator), **[I]** inferred.

## 1. Summary

- **Algorithm** **[V]**: a fixed-depth, fail-hard alpha-beta negamax.
  - It is written as an **iterative state machine**, not recursive code. The search jumps between labels, and an explicit ply counter `$BCA9` drives it.
  - Every interior node first scores all its moves *statically* (make, evaluate, unmake). It then searches in this order: the killer move, the static best, then the rest by descending static score.
  - Beyond the full-width depth `D`, a "selective" ply makes and evaluates every move in generation order. Moves that fail high cut off. Checks and threats can be extended up to `D+2` (rarely `D+3`).
  - Forward pruning discards weak moves by static score.
- **No clock** **[V]**:
  - Nothing in the program reads `FRAMES` or any other timer. Interrupts are disabled while thinking.
  - The level only sets the depth and the selectivity switches (§5). The manual's per-level times are just typical durations on a 3.5 MHz Z80.
  - The only early termination is the **keyboard poll at every node** (§6) and the move-list-overflow guard.
- **Iterative deepening** **[V]**: none, except that Levels 6–8 (and P3) run a two-pass search. The first pass uses Level 2's parameters, and its best move is searched first in the full pass.
- **Score** **[V]**: an unsigned byte, with `$80` = equal.
  - Negation is `NEG` (`x → 256−x`), so `$80+d ↔ $80−d`.
  - The evaluation (`#R$8400`) returns 0 for an illegal position (own king capturable). Otherwise it returns `$02…$FC`; the search adds 1, so a selective-ply value is `eval+1`.
  - A mated side has value 1, so the mating side sees `$FF`.
  - Draws (stalemate, repetition) use `$78` / `$7E` ± the material term `$BD2E`.
  - Value 0 in the value table means −∞.
- **Validation** **[V]**: a Python transliteration of this subsystem (the pseudocode in §4) was driven against the original's own primitives (move generator `$78CE`, make `$810F`, eval `$8400`, unmake `$821C`, pre-search `$7810`, book `$7AC7`). It reproduced the **exact sequence of every `$810F` call** (ply, from, to), the chosen move and the root value in **all 50 searches tried**: every level including P1–P3, middlegames, endgames, mates, stalemates and repetition (§10).

## 2. Data structures and variables

Board, piece lists and move entries are described in `00-overview.md`, **with the corrections in §11**.

### Move lists ($B400–$BC7F) **[V]**

Each ply's list starts with a 4-byte **header**, followed by 4-byte move entries:

| Byte | Header | Move entry |
|---|---|---|
| +0 | `$FF`. This doubles as the previous list's terminator | score: `$FF` unscored; 0 = taken, searched, pruned or illegal; else the static evaluation (`$FD` = pass-1 best at the root) |
| +1 | number of moves | from-square (bit 7 is set on a recapture tried by `#R$802B`) |
| +2 | full-width plies: 0, or the killer's evaluation (written at `$7D93`). Selective plies: number of moves taken so far | to-square |
| +3 | flags: bit 7 = side to move in check; bit 6 = killer was legal and tried; bit 5 = moves statically scored; bit 0 = copied from the move leading here (`(IX+3) & $81` at `$79C1`) | move flags (see below) |

`slot(q)` = word at `$BCA9 + 2q` = address of ply q's header.
- `slot(1)` is always `$B400` (set at new game), so the root header flags are at `$B403` and the root moves start at `$B404`.
- The move generator writes `slot(q+1)` = the end of ply q's list.
- **Slots of deeper plies keep stale values from earlier lines and earlier searches, and the search reads them** (§4, `L7F20` / `L7EB6`). A port must model the move-list memory and slot table byte-for-byte, including their absolute addresses, because the selective-extension rule compares list *addresses* with `$B4xx`.

### Move flags used by the search (byte +3) **[I]**, set by make/eval

| Bit | Setter | Use in the search |
|---|---|---|
| 0 | make `$814F` | copied to the child header. `#R$80C4` does not prune when it is set; it protects from forward pruning (`$C9` mask) |
| 1 | eval `$87BB` | "threat": a quiet killer with bit 1 is scored instead of searched (`$7D94`). Selective extension candidate (`$42` mask) |
| 2 | eval `$8B46` | "recapture expected": the child tries the recapture on the same square first (`#R$802B`). Makes the move prunable at the `#R$80A7` test; blocks the check extension at `$7F34` |
| 3 | movegen (capture) | killer captures are always searched immediately; protects from pruning |
| 5 | movegen (double pawn step) | — (used by movegen for en passant) |
| 6 | eval `$87D3` / `$87E8` | selective extension candidate; protects from pruning |
| 7 | eval `$8ABF` / `$8D2F` / `$8D51` | "gives check" **[I]**: becomes header bit 7 (in check) of the child; extension test at `$7F2D`; protects from pruning |

### Search variables

| Address | Width | Meaning |
|---|---|---|
| `$BCA9` | byte | current ply p (root = 1) **[V]** |
| `$BCAA` | byte | full-width depth D (1–4) **[V]** |
| `$BC9F + q` | byte | V(q) = value/alpha of ply q, for q = 0…8. V(0) = `$BC9F` = 0 = −∞; V(1) = `$BCA0` = root value **[V]** |
| `$BC91 + 2(q−1)` | 2 bytes | killer for ply q (from, to). From bit 7 set = none. Reset to `$FF` each pass. Plies 1–7 **[V]** |
| `$BC83 + 2(q−1)` | 2 bytes | move being searched at ply q ≥ 2 (from, to). Bit 7 of from set = do not use as killer **[V]** |
| `$BD0B` | byte | ply at which the most recent mate (no legal move while in check) was detected **[V]** |
| `$BD0C` | byte | shortest root mate ply so far (reset to `$FF`) **[V]** |
| `$BD0D` | byte | incremental material balance, reset to 0 per pass. Maintained by make/unmake and read by the eval **[V]** |
| `$BD0E` | byte | loop counter of `#R$7B96` |
| `$BD19` | byte | best static score from the last `#R$7B96` **[V]** |
| `$BD1A` | word | entry of that best static move **[V]** |
| `$BD29` | word | **move to play** (root entry address) **[V]** |
| `$BD2B` | word | root move currently being searched **[V]** |
| `$BD2D` | byte | bit 0 = side to move (1 = White); bits 1–4 = phase (set by `$7810`): b1 = move ≥ 8, b2/b3/b4 = total material < 52/40/25 **[V]** (bits read here; computation in `$7810`) |
| `$BD2E` | byte | 8 × clamp(material difference, ±14), from `$7810` **[I]**. Used for draw values |
| `$BD09` | byte | forward-pruning margin (2–13). Bit 7 = all forward pruning off **[V]** |
| `$BDF6` | byte | threat-extension switch (0 = off) **[V]** |
| `$BD4B` | byte | header flags of the selective node being processed. Bit 7 = in check = never store a killer. Set to `$80` by the recapture path **[V]** |
| `$BD4E` | byte | set to `$A9+2p` (non-zero) by the selective loop, **and overwritten by the evaluation** (`$8A42` / `$8D44` / `$8D6A`). Zero after the eval makes `#R$7F27` extend unconditionally **[V]** |
| `$BD4C` | byte | bit 7 = abort (key pressed, or move list full); bit 6 = computer is moving (promotion) **[V]** |
| `$BD6E` | byte | second-pass pending **[V]** |
| `$BCBD` | byte | search parameter of the level (0–7) **[V]** |
| `$BCCD` | byte | level index shown in the UI: 0–7 = Level 1–8, 8/9/10 = P1/P2/P3 **[V]** |
| `$BCDD` | byte | next-best mode (skip the book; keep the exclusion list) **[V]** |
| `$BF00…` | — | next-best exclusion list: (from, to) pairs terminated by `$FF`. Cleared before each normal search (`$6FAA`); played moves are appended (`$6398`) **[V]** |
| `$BD58–$BD5B` | 4 bytes | root "move" record = last game move (+1 from, +2 to, +3 flags). IX at the root **[V]** |
| `$BD5C/$BD5D` | 2 bytes | (from, to) of the side to move's previous move **[V]** |
| `$BD5E` | byte | count of consecutive reversing moves (6 = draw by repetition, detected in the main loop) **[V]** |

## 3. Interfaces

- **Caller:** the main loop calls `#R$7BE1` once per computer move, after generating and statically scoring the root itself (`$614E–$6161`), with `$BD4C=$40`.
  - Result: `$BD29` (entry address); `$BCA0` (root value; ≥ `$FE` means a forced mate was found).
  - Carry is set if there is no legal move.
- **Primitives** (in other subsystems):

  | Routine | Inputs / outputs |
  |---|---|
  | `$7810` | pre-search set-up |
  | `$78BA` | key poll, then falls into the generator `$78CE` (IX = move leading here). Returns E = count and HL = header+3; writes `slot(p+1)` |
  | `$810F` | make (IX = entry; pushes undo data on the machine stack) |
  | `$8400` | evaluate (IX = entry just made). Returns A; sets flags in `(IX+3)` and `$BD4E`; **increments the random byte `$BCCE` on every call** |
  | `$821C` | unmake |
  | `$7AC7` | book probe (Z = hit, move in `$BD29`). Mixes `R` into `$BCCE` |
  | `$6734` | keyboard test |
  | `$7562` | leave demo mode |

## 4. Algorithm (reference pseudocode, verified)

8-bit arithmetic wraps unless noted. `mem[]` is the Z80 memory: the search keeps **all** of its state in memory, and stale contents matter. `make`, `unmake`, `evaluate` and `gen` are the primitives above. "→ L" means continue at label L. `ix` is the current move entry, `c` the last evaluation.

```text
THINK ($7BE1):
    call $7810
    repeat: r = PASS(); until r in {book, nomove} or mem[$BD6E] == 0

PASS ($7BF1):
    mem[$BC91..$BC9D] = $FF; mem[$BD0C] = $FF; mem[$BD0D] = 0; mem[$BC9F..$BCA7] = 0
    gen(ix=$BD58)                          # root list at $B400 (ply 1)
    mem[$B403] |= $20
    SCOREMOVES($B403)
    if mem[$BCDD] == 0:
        probe book; if hit: (key test) return book
    if mem[$BD19] == 0: return nomove      # $7BEE: carry set
    d = mem[$BD19]
    if mem[$BD6E]:                         # second pass
        h = W($BD29); mem[h] = $FD; W($BD1A) = h; mem[$BD6E] = 0; a = mem[$BCBD]
    else:
        W($BD29) = W($BD1A); a = mem[$BCBD]
        if a >= 5: a = 1; mem[$BD6E] = 1
    mem[$BDF6] = 0; mem[$BD09] = a
    if a & 2: mem[$BDF6] = a; if a & 1: mem[$BD09] |= $80
    mem[$BCAA] = D = (a==0 ? 1 : a<4 ? 2 : a==4 ? 3 : 4)
    b = 7
    if !(mem[$BD09] & $80):
        if !(mem[$B403] & $80):            # root not in check
            n = PRUNE(d)                   # also prunes root moves; n = 2*count - #(score < best-9)
            n = (((n >> 2) - 1) & $FF) >> 1
            f = mem[$BD2D]
            b = (f & $10) ? 11 : ((sra(f) - 1) == 0 ? 8 : 10)    # sra = arithmetic shift right
            loop: n -= 1; if n < 0 (bit 7): break; b -= 1; if b == 0: break
        mem[$BD09] = b + 2
    for (from,to) in list at $BF00 until $FF:    # next-best exclusions
        (found, h) = FINDMOVE($B402, mem[$B401], from, to); mem[h-1] = 0    # see §9: bug if not found
    de = PICKBEST($B403)
    if none: "NO MORE MOVES"; clear $BF00 list; discard return; goto THINK
    W($BD1A) = de
    c = mem[$BD5E]
    if c >= 2:                                    # repetition: reverse of our last move
        (found, h) = FINDMOVE($B402, mem[$B401], from=mem[$BD5D], to=mem[$BD5C]); h -= 1
        if mem[h] != 0:
            mem[h] = 0
            v = mem[$BD2E]; if mem[$BD2D] & 1: v = -v
            v += $7E; if c & 4: v -= 8
            mem[$BCA0] = v; W($BD2B) = h; → L7E9B
    → L7DCF

L7D43 (node entry; ix = move that led here; ply already incremented):
    (key poll, §6) ; (e, hl) = gen(ix)
    if e == 0: → L7DA8
    p = mem[$BCA9]
    if mem[ix+3] & 4: → L802B
    if mem[hl] & $80: → L7DA8                     # in check: no killer
    k = $BC91 + 2(p-1); if mem[k] & $80: → L7DA8
    (found, h) = FINDMOVE(hl-1, e, mem[k], mem[k+1]); if !found: → L7DA8
    h -= 1; mem[h] = 0; ix = h; make(ix); → L7D77

L7D77:
    a = evaluate(ix); if a == 0: unmake; → L7DA8
    c = a; D = mem[$BCAA]; p = mem[$BCA9]
    if D < p: → L7F20
    if D == p and FUTILITY(D): unmake; → L7E79   # $80C4
    hl = header+3 of ply p; mem[hl] |= $40; mem[hl-1] = a
    if !(mem[ix+3] & 2) or (mem[ix+3] & 8): → L7DEE   # search the killer now
    mem[ix] = a; unmake; → L7DA8                     # quiet threat: order it later

L7DA8 (choose next move at ply p):
    D = mem[$BCAA]; p = mem[$BCA9]
    if D < p: → L7EE4
    hl = header+3 of ply p; e = count
    if mem[hl] & $20: → L7DDA
    mem[hl] |= $20; SCOREMOVES(hl)
    if mem[$BD19] == 0: → L7FEA
    if mem[hl] & $80: → L80E2
    PRUNE(mem[$BD19])
L7DCF: ix = W($BD1A); mem[ix] = 0; → L7DEB
L7DDA: if mem[hl] & $80: → L80ED
       de = PICKBEST(hl); if none: → L7E25
       ix = de; mem[de] = 0
L7DEB: make(ix)
L7DEE: p = mem[$BCA9]
       if p == 1: W($BD2B) = ix
       else: mem[$BC83+2(p-1)] = mem[ix+1]; mem[$BC84+2(p-1)] = mem[ix+2]
L7E0A: mem[$BD2D] ^= 1; mem[$BCA9] = p+1; V(p+1) = V(p-1); → L7D43

L80E2: ix = W($BD1A); mem[ix] = 0; → L80FA          # in-check nodes
L80ED: de = PICKBEST(hl); if none: → L7E25; ix = de; mem[de] = 0
L80FA: make(ix); p = mem[$BCA9]
       if p == 1: W($BD2B) = ix
       else: mem[$BC83+2(p-1)] |= $80           # stale from-square only flagged
       → L7E0A

L7E25 (return to parent):
    loop: a = mem[$BCA9]-1; if a == 0: return (end of PASS)
          mem[$BCA9] = a; unmake; mem[$BD2D] ^= 1
          if !(mem[$BD4C] & $80): break          # abort: keep unwinding
    p = a; A = -V(p+1); → L7E49
L7E49 (A = value for side to move at ply p; ply counter = p):
    if (~A) < V(p-1): → L7E79                     # A >= beta: fail high
    if A <= V(p): → L7DA8
    V(p) = A
    if p == 1: → L7E95
    q = p-1; → L7E5F
L7E5F (q = p-1): if mem[$BC83+2q] & $80: → L7DA8
    killer(p) = curmove(p); → L7DA8
L7E79 (fail high at node p): unmake; mem[$BCA9] -= 1; mem[$BD2D] ^= 1; q = mem[$BCA9]; → L7E5F

L7E95: if V(1) != $FF: → L7E9B
       → L7EA1
L7E9B: W($BD29) = W($BD2B); → L7DA8
L7EA1: V(1) = $FE; m = mem[$BD0B]
       if m == 2: W($BD29) = W($BD2B); return (end of PASS)   # mate in 1
       if m >= mem[$BD0C]: → L7DA8
       mem[$BD0C] = m; → L7E9B

L7EE4 (selective node at ply p > D):
    loop:
      L = $A9+2p; mem[$BD4E] = L; hdr = W($BC00+L)
      if hdr[1] == hdr[2]: → L7E25
      t = hdr[2]; hdr[2] = t+1; mem[$BD4B] = hdr[3]
      e = hdr+4+4t; mem[e] += 1; if mem[e] != 0: continue   # only $FF entries
      ix = e; make(ix); c = evaluate(ix)
      if c != 0: → L7F20
      c = 1; if mem[$BD4B] & $80: → L7F43                  # in check: counts as 2
      unmake
L7EDE: unmake; → L7EE4
L7F20: if mem[$BCB2] == $B4: → L7EB6
L7F27: if mem[$BD4E] != 0:
           f = mem[ix+3]; if !(f & $80) or (f & 4): → L7F43
L7F39: A = D
L7F3E: if A+1 >= p: → L7DEE                                  # extend
L7F43: c += 1; A = c                                          # value for the mover
       if (~A) < V(p-1): → L7F81
       if mem[ix+3] & $42: → L7FAD
L7F5B: if c <= V(p): → L7EDE
       V(p) = c; if mem[$BD4B] & $80: → L7EDE
       killer(p) = (mem[ix+1], mem[ix+2]); → L7EDE
L7F81: unmake; unmake; mem[$BD2D] ^= 1; mem[$BCA9] -= 1
       if mem[$BD4B] & $80: → L7DA8
       killer(p) = (mem[ix+1], mem[ix+2]); → L7DA8           # p = old ply
L7FAD: x = D+2; if x < p: → L7F5B
       A = (x == p) ? c : c+1; if overflow: → L7F5B
       if A < V(p): → L7EDE
       if mem[$BDF6] == 0 or c == 2: → L7F5B
       → L7DEE                                                # extend the threat
L7EB6: if mem[$BCB6] == $B4: → L7ED3
       if D < 3 or mem[$BCB3] >= $58: → L7F27
       A = D; → L7F3E                                         # extend to D+1, no threat test
L7ED3: if D < 3: → L7F27
       A = D+1; → L7F3E                                       # extend to D+2

L7FEA (no legal move at full-width node, hl = header+3):
    if mem[hl] & $40: → L7E25                                 # killer was legal
    if mem[hl] & $80: mem[$BD0B] = p; A = 1                   # mated
    else: A = (mem[$BD2D]&1 ? -mem[$BD2E] : mem[$BD2E]) + $78 # stalemate
    → L7E49   (the node's own value: compared with V(p-1), stored in V(p))

L802B (recapture first):
    h = W(slot(p+1)) + 2
    repeat count times: h -= 4; if mem[h] == mem[ix+2]: found
    if not found: → L7DA8
    h -= 2; ix = h; mem[h] = 0; make(ix); mem[ix+1] |= $80; mem[$BD4B] = $80; → L7D77

SCOREMOVES(hl) ($7B96):  mem[$BD19] = 0
    for each of the count entries e (in order):
        if mem[e] == $FF:
            make(e); a = evaluate(e); mem[e] = a
            if a >= mem[$BD19]: mem[$BD19] = a; W($BD1A) = e      # ties: later entry
            unmake

PICKBEST(hl) ($8015): best = 0
    walk entries from hdr+4 until an entry with score $FF;
    keep the first entry whose score is strictly greater than best
    return it, or none (E odd)

FINDMOVE(h, n, from, to) ($7BCD): for n entries after h: h += 4
    if mem[h] == to and mem[h-1] == from: return (found, h-1)
    return (not found, h)                     # h = +2 of the last entry tested

FUTILITY(a) ($80C4, a = D = p):
    if a odd: no; x = mem[$BD09]; if x & $80: no; if x >= c: no
    if (x - c) & $FF >= V(p-1): no
    if header flags of ply p & 1: no
    yes

PRUNE(best) ($805F):
    if mem[$BD09] & $80: return
    (p, hl, e, C) = ply info
    if p >= 3: a = mem[$BD2D] else: n = 2e; a = $10
    test = T_DEFAULT; if a & $10: test = T_LENIENT; if a & 8: test = T_STRICT
    t = max(best, C); if t < 9: return n
    thr = t - 9
    for each of the e entries with score s and flags f:
        if s < thr:
            x = (s - thr) & $FF
            T_DEFAULT: x = (x+16)&$FF; prunable = (x & $80) ? yes : (f & 4)
            T_LENIENT: n -= 1; x = (x+16)&$FF; prunable = (x & $80) ? (f & 4) : no
            T_STRICT:  prunable = f & 4
            if prunable and !(f & $C9): score = 0
    return n
```

## 5. Levels **[V]**

| Level | `$BCCD` | `$BCBD` | Passes (param) | D | `$BDF6` (threat ext.) | Forward pruning (`$BD09`) |
|---|---|---|---|---|---|---|
| 1 | 0 | 0 | 1 (0) | 1 | off | on |
| 2 | 1 | 1 | 1 (1) | 2 | off | on |
| 3 | 2 | 2 | 1 (2) | 2 | on | on |
| 4 | 3 | 3 | 1 (3) | 2 | on | **off** |
| 5 | 4 | 4 | 1 (4) | 3 | off | on |
| 6 | 5 | 5 | 2 (1, then 5) | 2, then 4 | off, off | on, on |
| 7 | 6 | 6 | 2 (1, then 6) | 2, then 4 | off, on | on, on |
| 8 | 7 | 7 | 2 (1, then 7) | 2, then 4 | off, on | on, **off** |
| P1 | 8 | 0 | as Level 1 | | | |
| P2 | 9 | 3 | as Level 4 | | | |
| P3 | 10 | 7 | as Level 8 | | | |

- The problem levels search exactly like Levels 1/4/8. The main loop alone decides "mate found" (`$BCA0` ≥ `$FE`, see `$619F`) or `NO MATE FOUND`.
- The opening book is probed in every level, unless in next-best mode. This applies to P-levels too: whether the main loop suppresses it there is the main loop's concern.
- The deepest made move is at ply D+3 (max 7). The deepest list is ply D+3 (slot D+4).
- Observed node counts (makes, including root scoring): L1 ~100–300, L2 ~400–900, L3–L4 ~800–3,200, L5 ~2,300–7,400, L6 ~13–21 k, L7 20–34 k, L8 ~66 k.

## 6. Termination and the keyboard

- `#R$78BA` is executed at **every node entry** (`#R$7D43`, every new node including selective ones; not the root). If `$BD4C` bit 7 is clear, it calls `$6734` (`IN A,($FE)` on all rows). On a key it sets `$BD4C` bit 7 and calls `$7562` (leave demo mode). The node then continues normally: the generator runs, and the rest is unchanged. **[V]**
- The flag is only acted on in `#R$7E25`, when a child returns. Values are then no longer compared, and every ply unwinds back to the root. **[V]**
- Consequence **[V]**: after a keypress the search keeps going down the current line until it reaches a selective node and finishes that node's whole move list, then unwinds. 50–200 extra makes were observed.
- The move played is `$BD29`: the best *completed* root move, or the static best if none completed yet. In pass 1 of a two-pass level the second pass still runs: it regenerates the root, re-scores it, and descends the first line before unwinding. It does not poll the key again (bit 7 is already set), and its `$BD29` stays the pass-1 result.
- The book path also tests the key once (`$7C23`).
- **Move-list overflow guard** **[V]**: the generator sets the same abort flag instead of writing past `$BC80` (`$7AAF`). The search then unwinds as if a key were pressed.
- For the port's `stop` / time limit: set the abort flag at the next `#R$7D43` node entry and keep everything else identical.

## 7. Mate, stalemate, repetition, next-best, problem levels **[V]**

- **Mate:** a full-width node with no legal move while in check has value 1. `$BD0B` records the ply.
  - At the root, a value of `$FF` triggers `#R$7EA1`. A mate detected at ply 2 (mate in one) ends the pass at once. Otherwise the shortest mate ply (`$BD0C`) wins; ties go to the first move found. V(1) is then held at `$FE`.
  - **Mates are not distance-scored.** All mates are `$FF` in value.
  - In selective nodes a mate is only approximated: illegal replies while in check count as value 2, which the parent sees as `$FE`.
- **Stalemate:** value `±$BD2E + $78`. The sign is negated when `$BD2D` bit 0 is set.
- **Repetition:** if `$BD5E` ≥ 2, the root move that undoes our previous move is pre-selected. Root alpha is set to `±$BD2E + $7E` (−8 if `$BD5E` is 4 or 5), and the other moves must beat it. Repetition is not detected inside the tree. The 50-move rule is not used by the search.
- **Next-best:** the moves in `$BF00` get score 0 at the root, so they are never searched. If none are left: `*NO MORE MOVES`, clear the list, think again.
- **Problem levels:** see §5.

## 8. Node definition for the oracle **[V]**

Count, between the entry and exit of `#R$7BE1`:
- **makes** = calls to `$810F`, including root and interior static scoring (`#R$7B96`);
- **evals** = calls to `$8400`, including the one in `$7810`;
- **nodes** = executions of `#R$7D43` (= keyboard polls = generator calls except the root's).

The make sequence (ply, from, to) is the strongest comparison and is what §1 validated.

**Determinism requires matching `$BCCE` at the start of the search.** The eval adds `($BCCE & 3)` on move 1 and `($BCCE & 1)` after that, incrementing `$BCCE` on every call. The book probe also mixes `R` into `$BCCE`.

## 9. Capacities and crash risks

- **Ply** **[V]**: the maximum is D+3 = 7. The tables are sized for it: killer `$BC91–$BC9E` (plies 1–7), current-move `$BC85–$BC90` (plies 2–7), V(0..8), slots 1–8. These overlap their neighbours if p > 7 (for example V(10) = `$BCA9`, the ply counter itself, and curmove(8) = killer(1)). There is no iterative deepening, so modern hardware can never deepen beyond the level's fixed D. Depth-overflow crashes cannot happen unless the port invents deeper levels.
- **Stack** **[V]**: make pushes undo data (4–8 bytes per ply). The observed minimum SP was `$BDD0` (stack top `$BDF4`). Safe.
- **Move lists** **[V]**: the generator guards against overflow (abort at `$BC80`). The observed maximum was `$B748`.
- **Latent bug A** **[I]**: `#R$7CBA` (next-best exclusions) and `#R$7D00` (repetition) call `#R$7BCD` and use HL without checking carry. If the move is not in the root list:
  - the exclusion path zeroes the **from-square of the last root move** (makes it a1-internal);
  - the repetition path takes the last entry+1 as the "move", zeroes its from-square, and may store a misaligned pointer in `$BD29` (playing garbage).
  - Both are believed unreachable in normal play (the reverse of our own last move is always pseudo-legal after two reversals). A port that loads positions plus move lists should guard this (class A). Check whether a position set-up or `position … moves` sequence can reach it.
- **`B=0` loops** **[V]**: `FINDMOVE` and `PRUNE` treat a count of 0 as 256. Every call site passes a non-zero count (checked by the callers).

## 10. Validation log

The Python model (`tools/research/search/model.py`; usage: `model.py SNAPSHOT LEVEL`) was compared with the original running in SkoolKit's simulator from identical states, and matched in every case:

- posA (move 11), posB (move 25), posC (move 28), from Level-1 demo games: Levels 1–6 → 18/18 identical make sequences, best move and root value.
- posC Levels 7, 8; posA Level 7 → identical (up to 65,727 makes).
- A forced-repetition position (Nf3 Nf6 Ng1 Ng8 Nf3 Nf6 Ng1, `$BD5E`=5): Levels 1, 2, 3, 5 → identical, including the book probe (miss) and the repetition draw path.
- Late-game demo positions (moves 32–35) at Levels 4, 5, P2, P3 → 12/12 identical (up to 31,032 makes).
- Positions set up through the original's CHANGE POSITION mode:
  - back-rank mate in one (Levels 1, 4, P1, P2);
  - K+Q v K with mating and stalemating replies (Levels 1, 2, 5);
  - K+R v K (Levels 5, 6);
  - K+P v K (Levels 5, 6).
  - All 13 identical. Mate found with root value `$FE` and detected at ply 2. The small-list extensions `L7EB6` / `L7ED3` were exercised in K+R v K and K+P v K.
- The root margin and pruned-move set (`$BD09`, `PRUNE`) were checked separately in 12 cases.

**Total: 50 searches, all identical. Every label in §4 was exercised at least once.**

Note: at Level 1 / P1 (D=1) a mate in one is only seen through the selective approximation (value 2 → `$FE`), so `#R$7EA1` is not taken. From D=2 the mated node is a full-width node and the exact mate path runs.

Helper scripts used (`tools/research/search/`; they write snapshots to its `work/` folder):
- `hsim.py`: simulator with PC hooks;
- `search_stats.py`, `abort.py`, `margin.py`;
- `model.py`: the verified transliteration;
- `movein.py`, `mksetup.py`: enter moves / set up positions through the original UI.

They are the starting point for the Phase 2 oracle.

## 11. Corrections to `00-overview.md`

1. **Board orientation and colours are reversed.**
   - The internal square is `(8 − rank)*16 + file`: `$BD00` row 0 is **rank 8**, `$BD70` is rank 1.
   - Piece codes **with bit 7 set are White**; the White piece list is `$BE80`, and Black is `$BE00`.
   - `$BD2D` bit 0 = 1 means White to move.
   - The UI cursor `$BCCA` uses the same internal squares.
   - Verified by entering g1–f3 through the UI: the code at `$BD76` moved to `$BD55`.
2. `$BF00` is the **next-best exclusion list** (pairs of root moves, cleared before normal searches), not a display record.
3. `$BCBD` is the search parameter (0–7). The UI level index is `$BCCD` (0–10).
4. `$BCDD` is next-best mode (set at `$69C3`), not demo/problem.
5. `$BD4C` bit 6 = "computer to move" (used by the promotion code). Bit 7 = abort, set by the key poll **or** by move-list overflow.
6. List headers: +0 `$FF`, +1 count, +2 killer eval / taken counter, +3 flags (see §2).
7. `$80A2–$80A6` is code (the default pruning test), not data. `$7D3F` is unreferenced code (`LD ($BCA0),A / RET`).
8. Nothing reads `FRAMES`, and there is no time control (see §6).

## 12. Open questions

- The exact meaning of move-flag bits 0, 1, 2 and 6 belongs to the make (`$814F`) and eval (`$87BB`, `$87D3`, `$87E8`, `$8B46`) analyses. The search treats them as described in §2.
- When can `$BD4E` be zero after an evaluation (eval sets it at `$8A42` / `$8D44` / `$8D6A`)? This decides the unconditional extension at `#R$7F27`.
- How `$BCA0` (the root value of the last search) feeds `$7810`'s `$BD1E` smoothing. That is in `$7810` (subsystem B).
- Whether the main loop disables the book in problem mode (subsystem A).
