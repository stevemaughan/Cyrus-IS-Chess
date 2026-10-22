# Subsystem E: Evaluation (`$8400–$8F2E`)

Annotated control file: `disasm/ctl/50-eval.ctl` (labels `Evaluate`, `Ev*`). Tags: **[V]** verified against the original running in the simulator, **[I]** inferred.

## 1. Summary

`$8400` (`Evaluate`) is the only evaluation routine. It is called after every make-move in the search (`$7B96`, `$7D43`, `$7E8C`), once per computer move from the pre-search set-up `$7810` (IX=`$BD58`), and from the main loop (`$6000`). It is far more than a piece-square sum. In one call it:

1. scans every piece of both sides in two passes, building **attack maps** in the piece records (bytes +2..+5) and accumulating **mobility, development, pawn-structure, pawn-advancement and king-safety** terms; detects **checks**, **illegal positions** (side to move can capture the king, or kings adjacent) and **pins**;
2. removes the attacks of **pinned pieces**;
3. runs a **static exchange evaluation (SEE)** on every attacked piece, using two coroutines that yield attackers and defenders in increasing value order;
4. combines **material change since the search root** (`$BD0D`), the best/second-best **capture gains** for each side, the positional score, and a **pseudo-random term** from `$BCCE`, into one unsigned byte.

**Result [V]:** A = `$80` + 8×(material, in pawns, after expected captures) + clamp(¾×positional + noise, −12..+12), from the point of view of the **side that has just moved** (the side *not* to move in `$BD2D` bit 0). The normal range is `$04..$F8`; `$02`/`$FC` = hopelessly lost/won (material term saturated); **`$00` = illegal position** (abort). B returns the positional term.

**Verification [V]:** a Python reference model (Appendix A) reproduces A, B, the move flags and every byte the routine writes in `$BC00–$BEFF`, for:
- 9,256 calls captured from 25 emulated minutes of Cyrus-v-Cyrus demo games at Level 1 (212,879 eval calls, sampled every 23rd);
- 30,000 random positions/variable settings run directly through `$8400` in the emulator (17,410 aborts);
- 7 hand-built cases.

Together these executed **every instruction** in `$8400–$8F2E`. Section 10 describes the method; section 9 lists 30 regression samples.

## 2. Interface

| | |
|---|---|
| Entry | `CALL $8400`. IX = move-list entry of the move just made (`+1` from, `+2` to, `+3` flags) |
| Exit | A = score, B = positional term (mover's view, signed). C = 4×material term. IX preserved (restored from `$BD3B`). **IY clobbered** (left pointing into a SEE coroutine). Alternate registers clobbered |
| Abort | `$8C28`: SP ← (`$BD3D`), returns A=0 to `$8400`'s caller. Taken when the side to move attacks the enemy king (first pass), or the two kings are adjacent (either pass) |
| Cost | ~2,600 Z80 instructions per call on average (in game play) |

### Inputs read

| Address | Meaning |
|---|---|
| `$BD00–$BD77` | Board (0x88; piece codes). Also reads off-board bytes; see §8.1 |
| `$BE00–$BEFF` | Piece records: +0 square (bit 7 = captured), +1 type byte, +6 line mask |
| `$BD2D` | bit 0 = side to move (1 = White); bits 1–4 = phase (below) |
| `$BD0D` | Material change since the search root, Black-positive (Black − White, in pawns). Maintained by make/unmake (`$816E`, `$81BC`, `$8244`, `$827D`); zeroed at `$7C04` |
| `$BD4A` | Positional drift added in Black's view (updated by `$7810`: `$BD4A += B`) |
| `$BD1E` | Endgame "who is pressing" signed byte (from `$7810`) |
| `$BD6D` | 1 if any pawn (value-1 piece) exists in either side's non-king records, else 0 (`$789D`) |
| `$BD49` | Move number (1 at the start) |
| `$BCCE` | Random byte; **incremented** by every non-saturated evaluation |
| IX+2 | To-square of the move (to mark the moved piece) |

### Phase bits in `$BD2D` (computed by `$7810`) [V]

| `$BD2D` bit | Set when | Effect in eval (bit of B′ after RRCA) |
|---|---|---|
| 1 | move number ≥ 8 | B′ bit 0: early-queen penalty switched off |
| 2 | ≥ move 8 and total non-king material (both sides, Q9 R5 B3 N3 P1, promoted pawns count as their piece) < 52 (`$34`) | B′ bit 1: pawn mode "endgame" (`IY=$8A6F`) |
| 3 | … < 40 (`$28`) | B′ bit 2: endgame king; pawn mode "late" (`IY=$8A2B`, requires bit 2 too) |
| 4 | … < 25 (`$19`) | B′ bit 3: late-endgame king; E halved or quartered |

Phase bits are all zero before move 8.

### Outputs and side effects

| Where | What |
|---|---|
| A, B | Score, positional term |
| IX+3 | bit 7 = move gives check; bit 6 = mover has a double threat or a threat larger than anything the opponent can take; bit 2 = moved (or checking) piece is en prise; bit 1 = side to move can win material (mover left something en prise). Bits are only **set**, never cleared |
| `$BD39`/`$BD3A` | Best/second-best SEE gain against White's pieces (i.e. Black's captures) |
| `$BD3B` | Saved IX. `$BD3D` saved SP |
| `$BD4E` | Late endgame, first pass: content of the square in front of a pawn on its 7th rank (last one wins). Double check: 0. Read by the search at `$7F27` |
| `$BD79–$BD85` | Pin list (≤6 entries, (record, direction), 0-terminated). `$BD79` is 0 on exit; stale entries may remain beyond it |
| `$BE00+rec+2..+5` | Attack bytes, cleared to 0 on exit for all non-king records. **King records' +2..+5 are never cleared** (white king's not even on abort) and accumulate junk; nothing reads them |
| `$BCCE` | +1 (normal path only) |

## 3. Data layouts used [V]

**Piece code**: `rec | 4` (+`$80` for Black). With H′=`$BE`, L′=code points at record+4. Records: K, Q, R, R, B, B, N, N, then 8 pawn records (a..h, by original file; a pawn keeps its record when it captures or promotes).

**Type byte (+1):**
- Low nibble = value: K 0, Q 9, R 5, B 3, N 3, P 1.
- Bit 7 = bishop (`$83`).
- Bit 4 = has moved (set by make `$8132`).
- **King:** bit 5 = castled (`$81CF`). Bits 6–7 = diagonal distance from the edge, k = 0..3, recomputed by `$8200` on every king move: k = the number of steps n = 1, 2, 3 for which both sq±`$11`·n are on the board.
- **Pawn:** `$01` until it reaches its relative 4th rank, then `$11` (4th), `$31` (5th), `$61` (6th), `$91` (7th), set by make `$813D`. Promotion by the engine sets `$19` (queen). A user under-promotion (`$63B1`) sets `$05` / `$03` / `$83` (or `$09`).

**Line mask (+6):**

| Piece | +6 | Bits |
|---|---|---|
| K | `$01` | bit 0 = king |
| Q | `$0E` | bit 1 = queen, bit 2 = diagonal mover, bit 3 = orthogonal mover |
| R | `$08` | |
| B | `$04` | |
| N | `$00` | |
| P (White) | `$C0` | bits 6–7 = pawn; bit 6 distinguishes the capture direction |
| P (Black) | `$80` | |

**Promoted pawns keep the pawn mask** (`$C0`/`$80`), so they are treated as pawns by every +6 test (§7, quirk 5).

**Attack bytes** (zero at rest; built by the scan, consumed by the SEE). Each is four 2-bit counters:

| Byte | bits 0–1 | bits 2–3 | bits 4–5 | bits 6–7 |
|---|---|---|---|---|
| +2 direct attackers (enemy) | pawns (+1 each) | minors (+`$04`) | rooks (+`$10`) | queens (+`$40`) |
| +3 x-ray attackers | enemy **king** (+1) | x-ray minors | x-ray rooks | x-ray queens |
| +4 direct defenders (own) | pawns | minors | rooks | queens |
| +5 x-ray defenders | own **king** (+1); bit 1 = marker (moved piece, or the piece giving check) | x-ray minors | x-ray rooks | x-ray queens |

Counters wrap into the next field (e.g. four minor pieces on one square read as one rook); see §8.

**Pass flags B′:**
- bit 7 = colour being scanned (= "friendly"); bit 4 = second pass;
- bit 5 = pin list non-empty; bit 6 = a check has been seen;
- bits 0–3 = phase (see above).

## 4. Algorithm

All arithmetic is 8-bit with wrap-around. `sra` = arithmetic shift right. "A < B" tests in the original are almost always **the sign of (A−B) truncated to 8 bits**; the model reproduces this exactly.

### 4.1 Set-up

```
E = 0; A' = 0
r = RRCA($BD2D)                      # bit7 = side to move, bits0-3 = phase
pawnmode = $8A7A; if r&2: pawnmode = (r&4) ? $8A2B : $8A6F
F (B') = r + $80                     # bit7 = side to move's colour (1 = black)
if White to move: WHITE_SECTION else BLACK_SECTION     # first pass = side to move
```

### 4.2 Section order (the first pass is always the side to move)

```
BLACK_SECTION: D=$88; Q, R, R (orthogonal/queen), B, B (black bishop: -3 on rank 8), N, N (-3 on rank 8)
               D=$F1; prevfiles=(FF,FF); pawn records a..h (d,e records: unmoved-centre test)
               if F bit4 clear: F += $90; E=-E; A'=-A'; WHITE_SECTION     (else -> FINAL)
WHITE_SECTION: D=$88; Q, R, R, B, B (-3 on rank 1), N, N (-3 on rank 1)
               D=$11; prevfiles=(FF,FF); pawn records a..h
               white king (early-queen test first, if before move 8)
               A'=-A'; E=-E; F |= $80; black king
               if F bit4 clear: F |= $10; BLACK_SECTION                   (else -> FINAL)
```

Both orders leave E and A′ in **Black's point of view** at FINAL. The pass distinction matters only for:
- abort-vs-check (a king attacked in the first pass means the side to move can capture it: abort);
- `$BD4E`;
- the `$84A9` marker.

### 4.3 Pieces (attack marking and mobility)

Ray scans use main C = direction and D = `$88` as the off-board mask. "Mark" means adding the scanner's weight C′ to the hit piece's record:
- **Friendly piece:** +4.
- **Enemy piece:** +2.
- **Enemy king:** CHECK (below).

**Knight** (C′=4): E −= 1, then for each target among +14, +18, +31, +33 (all skipped if sq+14 ≥ `$80`), −14, −18 (stop if sq−14 < 0), −31, −33 (stop if sq−31 < 0) that is on the board: E += 1, and mark any piece there.

**Bishop** (C′=4, E′=`$C4`), and the queen's diagonals: directions +15, +17, −17, −15. For each step on the board: E += 1. On the first piece:
- **Enemy** → ENEMY_HIT.
- **Friendly** → mark +4. Then:
  - if its +6 AND E′ is a non-pawn diagonal mover (bishop/queen) → XRAY_CHAIN;
  - if it is a pawn and the ray runs in that pawn's capture direction (white pawn: ray upward; black: downward) → the piece on the next square (if any) gets +5 (friendly) or +3 (enemy) += C′.

**Rook** (C′=`$10`, E′=`$08`), and the queen's rook lines (queen C′=`$40`):
- **East/west:** no mobility. First piece: enemy → ENEMY_HIT; friendly → +4, and if it is an orthogonal mover, the next piece beyond it gets +5/+3 (no further chain, no mobility).
- **North/south:** E += 1 per square up to and including the first piece. Friendly orthogonal mover → XRAY_CHAIN.

**XRAY_CHAIN:** continue the ray, E += 1 per square.
- Enemy piece → its +3 += C′; stop.
- Friendly → its +5 += C′; continue only if it also moves along this line (pawn: one-square rule as above).

**ENEMY_HIT** (an enemy non-king piece at the end of a ray; its +2 += C′):
- *Its +6 says it also moves along this line* (non-pawn): look further along the ray. The next piece:
  - friendly to the scanner: +5 += C′;
  - enemy: +3 += C′, then PIN_TEST.
- *Otherwise* (it cannot answer along this line): the next piece, if enemy → PIN_TEST (no x-ray count).

**PIN_TEST** (the piece behind is a king, +6 bit 0, or a queen, bit 1):
- **King behind:** pin the first enemy piece.
- **Queen behind:** pin it too, unless the scanner is a queen, in which case E += 2 and no pin.

**PIN:** search `$BD79`.
- **Already listed:** direction ← 0 (pinned twice), E += 1.
- **New:** append (record, direction C) with a 0 terminator, F |= `$20`, E += 2.
- **List full** (6 entries, terminator would be at `$BD85`): E += 2, not recorded.

**CHECK** (a ray, knight or pawn reaches the enemy king):
- **First pass:** ABORT.
- **Second pass:** IX+3 |= `$80`.
  - Knight/slider:
    - first check (F bit 6 clear): F |= `$40`, set +5 bit 1 of the checking piece's record, E += 2;
    - double check: `$BD4E` ← 0, A′ += `$14`.
  - Slider: the ray then **continues past the king**, counting mobility and marking pieces behind it.
  - Pawn check: E += 1 only.

**Pawn record** (L = square, H = type; D = `$11` White / `$F1` Black):

```
if record is the d- or e-pawn and ((L+$20) & $40) == 0: E -= 3     # rank 2 or rank 7, either colour
if H & $0E: evaluate as Q (H&8) / R (H&4) / B (H&$80) / N, no back-rank penalty; return
L = L + D;  f = L & $0F                     # = pawn file + 1
if f == prev1 or f == prev2: E -= 3         # same file as either of the last two pawn records
prev2 = prev1; prev1 = f
mode $8A6F: if H>>1 != 0: A' += H>>3        # 4th:2 5th:6 6th:12 7th:18
mode $8A2B: A' += H>>2                      # 4th:4 5th:12 6th:24 7th:36
            if (H>>2)&$20 and first pass: $BD4E = board[L-1]     # 7th rank: square in front
mark(board[L]); mark(board[L-2])            # weight 1; NO edge check (see §8.1)
```

**Kings** (H = type, L = square; neighbour weight C):

```
white king only, before move 8:  c = 9 - move
     if black Q present and moved: E += c;  if white Q present and moved: E -= c
if F&4 (endgame): goto ENDGAME_KING
if castled (H&$20):
     if H&$C0: EXPOSED else:
         C = 10
         t = L+$1F; if t>=$80: t -= $40          # two ranks ahead (or behind), file-1
         if no pawn code (bit 6) on t, t+1, t+2: E -= 2
else if not moved (H&$10 == 0): C = 0; E += 1
else: E -= 6; C = 8; if H&$C0: EXPOSED
EXPOSED: C = 4; E -= 3 (5 if H&$80)
NEIGHBOURS: for sq in L-1, L+1, [L+16, L+17, L+15 if L+16<$80], [L-16, L-15, L-17 if L-16>=0]:
     piece there (no file-edge check): friendly -> +5 += 1; enemy king -> ABORT; enemy -> +3 += 1
     if the piece's record is a pawn record (code bit 6): A' += C
ENDGAME_KING: if not F&8: C = 8; NEIGHBOURS
     C = 4; D = (H&$C0)>>3                         # 0, 8, 16, 24
     if $BD1E != 0 and sign($BD1E) == colour (F bit7):
          if $BD6D: A' += D
          else: if D == 0: D = -10
                if file in d,e or rank in 4,5: A' += 16 + D
                elif file in c,f or rank in 3,6: A' += 8 + D
                else: A' += D
     else: D >>= 1; if (($BD1E==0) or $BD6D==0) and H&$80: A' += 8;  A' += D
     NEIGHBOURS
```

(The `else` branch adds 8 when the value tested at `$8966` is 0. That value is 0 when `$BD1E` = 0, or `$BD6D` when `$BD1E` has the other sign.)

### 4.4 FINAL (`$84A9`)

```
if no check seen: piece on IX+2 (if any): its +5 |= 2            # moved-piece marker
if F&8: E = sra(E); if $BD6D == 0: E = sra(E)                    # late endgame
if F&$20: UNDO_PINS
E = sra(sra(A')) + E + $BD4A                                     # Black's view
$BD39 = $BD3A = 0; $BD3B = IX
for black Q(9),R(5),R(5),B(3),B(3),N(3),N(3), pawn records (value = type & $0F):
     if +2 or +3 != 0: SEE(value, +2, +3, +4, +5)
     +2..+5 = 0
E = -E                                                            # White's view
(bb, bs) = ($BD39, $BD3A); $BD39 = $BD3A = 0
same for White's records  ->  (wb, ws) = ($BD39, $BD3A)
COMBINE
```

**UNDO_PINS:** for each pinned record (colour F′ = the record's colour; E and D saved and restored):
- **Pawn:** for both capture directions not along ±pin direction, the piece on sq+dir (no edge check) gets +4 −1 (friendly) or +2 −1 (enemy).
- **Knight:** re-walk with C′ = −4 and F′ bit 4 set. A pinned knight "giving check" is then flagged again rather than aborting. Mobility changes are discarded. A′ (+`$14` on a "double check"), IX+3 bit 7 and the +5 marker set by such a re-walk are **not** undone.
- **Bishop/rook/queen:** for each line not along ±pin direction, the first piece in both directions gets +4/+2 += C′, with C′ = −4 / −`$10` / −`$40`. Only direct attacks are removed; x-rays stay.

Finally `$BD79` = 0.

### 4.5 SEE (`$8AD6`) [V]

Attackers are generated lazily in the order:
1. pawns (1);
2. minors (3);
3. rooks (5);
4. queens (9);
5. then, from +3, x-ray minors (3), x-ray rooks (5), x-ray queens (9);
6. the king (13).

Each kind comes with its count. Defenders are generated the same way from +4 then +5 (king last). **Generating the king as a defender costs E one point** (`$8C1F`).
- If +2 = 0, the piece is only processed when the enemy king attacks it (+3 bit 0).

```
A = V; lo = $FF; hi = V
att = next_attacker(); def = next_defender()
loop:
   b = 0
   if no defender: break
   A -= att.value; att.count -= 1 -> next kind when 0
   if sign(A-lo) < 0: b = 1  elif sign(A-hi) >= 0: b = 2  else lo = A
   if no attacker: break
   A += def.value
   if sign(A-lo) < 0: b -= 1; if b == 0: break
   elif sign(A-hi) >= 0: b -= 2; if b == 0: break
   else hi = A
   def.count -= 1 -> next kind when 0
A = max(A, lo); A = min(A, hi)              # sign-of-difference comparisons
if A < 0: return                            # safe: no effect
if A > 0: insert A into ($BD39 best, $BD3A second) with unsigned >= comparisons
E -= 1; if +5 bit1 (moved/checking piece): IX+3 |= 4; E -= 2
```

### 4.6 COMBINE (`$8797`)

Let **T_stm** be the best/second gains the side to move can make now (gains against the mover's pieces), and **T_mov** the mover's threats against the side to move:

```
pos = E (White's view)
if White to move:  pos = -pos; (T_stm1,T_stm2) = (bb,bs); (T_mov1,T_mov2) = (wb,ws); mat = $BD0D
else:              (T_stm1,T_stm2) = (wb,ws); (T_mov1,T_mov2) = (bb,bs); mat = -$BD0D
A = 2*(mat - T_stm1)
if T_stm1 >= 1 (sign of T-1): IX+3 |= 2; if T_stm1 != 1: A -= 1; A -= T_stm2
if T_mov1 >= 1:
   if IX+3 bit2 clear:
       pos += 2
       if T_mov2 >= 1: IX+3 |= $40; pos += 2; if T_mov2 >= 2: pos += 2; goto done
   if T_mov1-1 >= T_stm1 (unsigned): IX+3 |= $40
done:
B = pos
if not (A < $1C or A >= $E4) (unsigned): return A&$80 ? $02 : $FC
C = 4*A
t = sra(pos); t = sra(t + pos + (pos&1))           # ~3/4 pos, 8-bit wrap
$BCCE += 1; t += $BCCE & (move == 1 ? 3 : 1)
if not (t < $0C or t >= $F4): t = (t&$80) ? $F4 : $0C
return t + C + $80
```

## 5. Constants

| Value | Where | Meaning |
|---|---|---|
| 1 / `$04` / `$10` / `$40` | `$8A92`, `$8CCE`, `$8D87`, `$8C50`, `$8C45` | Attack weights: pawn, minor, rook, queen; king = 1 into +3/+5 |
| `$08` / `$C4` | `$8C52`, `$8D89` | Line masks for orthogonal / diagonal rays |
| 9, 5, 5, 3, 3, 3, 3 | `$84F1`… | SEE values by record slot (Q, R, R, B, B, N, N). Pawn records use type & `$0F`. King = 13 |
| −3 | `$8A4E`, `$8A48`, `$8CC2`, `$8D7A` | Unmoved d/e pawn, doubled pawn, knight/bishop on back rank |
| +1 / −6 / −3 / −5 / −2 | `$8A16`, `$8A1B`, `$8A04`, `$89FD`, `$89A9` | King never moved; moved uncastled; off edge; ≥2 off edge; castled without pawn cover |
| 0 / 8 / 10 / 4 | `$8A14`, `$8A1E`, `$898D`, `$89FB` | Pawn-neighbour weights (A′) |
| 8 / 4 | `$894A`, `$8950` | Endgame / late-endgame pawn-neighbour weights |
| 16 / 8 / −10 | `$88F4`, `$8910`, `$88DC` | Late-endgame centralisation |
| 9 − move | `$8915` | Early-queen penalty |
| +2 / +1 | `$8E58`, `$8E45` | Pin found / repeated |
| +2 / +1 / `$14` | `$8D41`, `$8AC4`, `$8D48` | Check by piece / pawn; double check (A′) |
| −1 / −3 | `$8B39`, `$8B4D` | Piece attacked with SEE ≥ 0 / moved piece attacked |
| +2, +2, +2 | `$87CD`… | Threat bonuses |
| `$1C` / `$E4` | `$87ED` | Material saturation limits (−28..+27 half-pawns) |
| `$0C` / `$F4` | `$8819` | Positional clamp ±12 |

## 6. Variables touched

| Address | R/W | Meaning |
|---|---|---|
| `$BCCE` | RW | random byte, +1 per normal evaluation |
| `$BD0D` | R | material change, Black-positive |
| `$BD1E` | R | late-endgame sign (`$7810`) |
| `$BD2D` | R | side to move + phase |
| `$BD39` / `$BD3A` | W | best / second SEE gain |
| `$BD3B` | W | saved IX |
| `$BD3D` | W | saved SP |
| `$BD49` | R | move number |
| `$BD4A` | R | positional drift (Black's view) |
| `$BD4E` | W | piece in front of a 7th-rank pawn / 0 on double check |
| `$BD6D` | R | pawns present |
| `$BD79–$BD85` | RW | pin list |
| `$BDx8`, `$BDxF`, `$BDFF` | R | off-board bytes read as squares (§8.1) |
| `$BE00–$BEFF` | RW | piece records +2..+5 (working), +0/+1/+6 read |
| IX+2 / IX+3 | R / W | move entry |

## 7. Behaviours to preserve (quirks)

1. **Mobility is asymmetric.** Rooks and queens score only vertical and diagonal squares, never horizontal. Squares behind a friendly x-ray partner, and squares *beyond the enemy king* after a check, also count.
2. **Doubled pawns** are detected only against the previous **two** pawn records in a..h record order, after the "pawn file + 1" mapping. Record order follows original files, not current files.
3. **The "unmoved centre pawn" test** applies to the d- and e-pawn *records*. It fires whenever the pawn stands on rank 2 or rank 7, for either colour (`(rank+2)&4 == 0`). So a black d/e pawn that has reached rank 2 is also penalised.
4. **King shelter:**
   - Pawns of *either* colour adjacent to the king add the weight. So do promoted pieces still in pawn records.
   - The castled king's "pawn two ranks ahead" test looks *behind* when ahead is off the board. It uses the 8-bit sign, not the king's colour.
5. **Promoted pawns keep the pawn line mask** (`$C0`/`$80`) and pawn-record code bit 6. A promoted queen:
   - is not x-rayed through by friendly rooks/bishops;
   - can act as the "pawn" in the bishop-behind-pawn x-ray;
   - counts as king shelter.
6. **Random noise.** Every evaluation adds bit 0 of the incremented `$BCCE` (bits 0–1 on move 1). The search is therefore not a pure function of the position: it depends on `$BCCE` at search start and on the number of evaluations so far. `$BCCE` is also mixed with `R` at `$60EB` / `$7B89` (outside this subsystem).
7. **Material is relative to the search root** (`$BD0D`), not absolute.
8. **SEE uses the sign of 8-bit differences.** Its window logic stops early, as in the original. Kings count as attacker/defender of value 13. The king as defender costs one point when reached.
9. **Pinned-piece undo** removes only direct attacks (not x-rays), on lines other than the pin line. A pinned knight loses all attacks. Pinned pawns lose captures off the pin line.
10. **The opening queen penalty** is evaluated only in the white king call, for both queens, before move 8.
11. **E is halved/quartered in the late endgame** before A′/4 and `$BD4A` are added.

## 8. Capacities and crash risks

### 8.1 Off-board reads (latent class-A risk)

Pawn capture squares (sq + D and sq + D − 2) and king neighbours (sq ± 1, sq ± 16 ± 1), plus the castled-king shelter squares, are **not checked for the board edge**. For a- and h-file pieces they read off-board bytes in the board page:
- `$BD08`, `$BD18`, …, `$BD78` (file 8);
- `$BD0F`, …, `$BD7F` (file 15);
- `$BDFF` (black a2 pawn).

A non-zero byte there is treated as a piece code:
- the eval INCs/DECs `$BE00 + value ± k`, which corrupts piece records or attack bytes;
- it may ABORT (if the value looks like an enemy king), or add to A′ (if bit 6 is set).

Writes stay inside page `$BE` (H′ is fixed).

**Observed: these bytes were 0 in all 9,256 in-game samples.** The variables that live in those columns (`$BD58` = root move record +0, etc.) were 0 whenever the eval ran. The fuzzer confirms the model reproduces the effect when they are non-zero.

**Port:** keep the original variable layout for these addresses, or prove they are always 0 and treat off-board as empty. The latter is a deviation only if they can be non-zero.

### 8.2 Other limits

- **Pin list:** bounded at 6 entries (`$BD79–$BD84`, terminator ≤ `$BD85`). Safe. Stale bytes after the terminator are harmless.
- **2-bit attack counters overflow into the next field:**
  - 4 minors attacking one square → reads as a rook;
  - 4 rooks (needs promotions) → a queen;
  - more than 3 queens → lost.

  Faithful behaviour; not a crash.
- **8-bit accumulators wrap.** E, A′ and the positional term are 8-bit. `pos + pos/2` wraps when |pos| > 85, which is possible if `$BD4A` drifts far. `2*(mat − T)` wraps when |mat − T| ≥ 64: a large material lead would then **saturate the wrong way**. Unlikely within one search; preserve.
- **Stack:** about 12 bytes of nesting plus the coroutine frames. The abort path restores SP from `$BD3D`, so any depth is safe.
- **King records +2..+5 accumulate junk** (8-bit wrap). Nothing in eval reads them. Other subsystems should not rely on them.
- **No loops depend on unbounded data:**
  - rays stop at the board edge;
  - the pin list is bounded;
  - the SEE terminates after at most 15 + 15 generator steps.

## 9. Regression samples [V]

Each row gives the full input. Notation:
- **Board:** FEN piece placement plus side to move (from `$BD2D` bit 0).
- **Piece-list slots:** each side's records in order K, Q, R, R, B, B, N, N | pawn records a..h; `-` means absent. Square with `:type` given for kings and non-default type bytes. `:13` = moved knight, `:19` = moved queen (or engine-promoted queen in a pawn record), `:93` = moved bishop.
- **Pawn type bytes** are always the rank-derived value (§3).
- **Line masks (+6)** are the slot defaults (pawn records keep `$C0`/`$80`).
- **Off-board bytes** are 0 unless listed. IX bytes are `[+0 = $FF, from, to, flags]`.
- **A, B** are the results; IX+3 is shown before→after.

Rows 1–23 are taken from game play; rows 24–30 are constructed.

| # | Board | Piece-list slots | Move, IX+3 | `$BD2D` `$BD0D` `$BD4A` `$BD1E` `$BD6D` `$BD49` `$BCCE` | Off-board | A | B |
|---|---|---|---|---|---|---|---|
| 1 (abort) | `r1bqk2r/pp3ppp/3bpn2/1Bppn3/8/1P2PN2/PBPP1PPP/RN1Q1RK1 w` | W g1:30,d1,a1,f1,b2:93,b5:93,b1,f3:13 / a2,b3,c2,d2,e3,f2,g2,h2; B e8:00,d8,a8,h8,c8,d6:93,e5:13,f6:13 / a7,b7,c5,d5,e6,f7,g7,h7 | c6→e5 00→00 | 01 00 FD 00 01 06 F2 | - | 00 | 00 |
| 2 (check2) | `4Q3/3k2R1/8/5K2/4NP2/8/8/8 b` | W f5:90,-,g7:15,-,-,-,e4:13,- / -,-,-,-,e8:19,f4,-,-; B d7:50,-,-,-,-,-,-,- / -,-,-,-,-,-,-,- | e7→e8 00→82 | 1E F8 12 F6 01 4A 1E | - | 76 | 01 |
| 3 (ixbit1) | `r1bqkbnr/pp2pppp/2n5/2pp4/3N4/4P3/PPPP1PPP/RNBQKB1R b` | W e1:00,d1,a1,h1,c1,f1,b1,d4:13 / a2,b2,c2,d2,e3,f2,g2,h2; B e8:00,d8,a8,h8,c8,f8,c6:13,g8 / a7,b7,c5,d5,e7,f7,g7,h7 | f3→d4 00→06 | 00 00 FD F1 01 03 77 | - | 64 | 00 |
| 4 (ixbit2) | `rnbqkbnr/pp2pppp/8/2p5/3p4/4PN2/PPPP1PPP/RNBQKB1R w` | W e1:00,d1,a1,h1,c1,f1,b1,f3:13 / a2,b2,c2,d2,e3,f2,g2,h2; B e8:00,d8,a8,h8,c8,f8,b8,g8 / a7,b7,c5,d4,e7,f7,g7,h7 | d5→d4 00→04 | 01 00 FD F1 01 03 58 | - | 7A | F7 |
| 5 (ixbit6) | `r1bqk1nr/pp3ppp/2nbp3/1Bpp4/8/1P2PN2/PBPP1PPP/RN1QK2R b` | W e1:00,d1,a1,h1,b2:93,b5:93,b1,f3:13 / a2,b3,c2,d2,e3,f2,g2,h2; B e8:00,d8,a8,h8,c8,d6:93,c6:13,g8 / a7,b7,c5,d5,e6,f7,g7,h7 | c1→b2 00→40 | 00 00 00 F1 01 05 B0 | - | 84 | 04 |
| 6 (ixbit7) | `r1bq1rk1/pp3ppp/2B1pn2/2pp4/8/1P2PN2/PBPP1PPb/RN1Q1RK1 w` | W g1:30,d1,a1,f1,b2:93,c6:93,b1,f3:13 / a2,b3,c2,d2,e3,f2,g2,-; B g8:30,d8,a8,f8,c8,h2:93,-,f6:13 / a7,b7,c5,d5,e6,f7,g7,h7 | d6→h2 08→8E | 01 FE F9 00 01 08 10 | - | 52 | FC |
| 7 (move1) | `r1bqkbnr/pppppppp/2n5/8/8/8/PPPPPPPP/RNBQKBNR w` | W e1:00,d1,a1,h1,c1,f1,b1,g1 / a2,b2,c2,d2,e2,f2,g2,h2; B e8:00,d8,a8,h8,c8,f8,c6:13,g8 / a7,b7,c7,d7,e7,f7,g7,h7 | b8→c6 00→00 | 01 00 00 00 00 01 22 | - | 89 | 08 |
| 8 (phase02) | `r1b2rk1/pp2qppp/2Bbpn2/2pp4/8/1P2PN2/PBPP1PPP/RN1Q1RK1 w` | W g1:30,d1,a1,f1,b2:93,c6:93,b1,f3:13 / a2,b3,c2,d2,e3,f2,g2,h2; B g8:30,e7:19,a8,f8,c8,d6:93,-,f6:13 / a7,b7,c5,d5,e6,f7,g7,h7 | d8→e7 00→40 | 03 00 FB 00 01 08 27 | - | 80 | 00 |
| 9 (phase06) | `2b3k1/2q2p1p/2pbp1N1/p2p4/3r4/1PNPP1P1/2P2P1P/R3R1K1 w` | W g1:30,-,a1,e1:15,-,-,c3:13,g6:13 / b3,-,c2,d3,e3,f2,g3,h2; B g8:30,c7:19,d4:15,-,c8:93,d6:93,-,- / a5,c6,-,d5,e6,f7,-,h7 | a6→c8 00→02 | 07 00 F7 04 01 17 6E | - | 53 | FD |
| 10 (phase0E) | `6k1/5P1p/2p5/p2p3r/R7/1P1b2P1/2q2P1P/3NR1K1 w` | W g1:30,-,a4:15,e1:15,-,-,d1:13,- / b3,-,-,-,f7,f2,g3,h2; B g8:30,c2:19,h5:15,-,d3:93,-,-,- / a5,c6,-,d5,-,-,-,h7 | g5→h5 00→00 | 0F 00 EA 03 01 1E 12 | - | 00 | 00 |
| 11 (phase1E) | `8/5k1p/2p5/R2p2P1/8/1P1b1qP1/5P1K/8 w` | W h2:30,-,a5:15,-,-,-,-,- / b3,-,-,-,-,f2,g3,g5; B f7:70,f3:19,-,-,d3:93,-,-,- / -,c6,-,d5,-,-,-,h7 | d1→f3 00→40 | 1F 00 F4 08 01 22 F3 | - | 7F | FF |
| 12 (pin) | `r1b1kbnr/pp1qpppp/2n5/1Bpp4/8/4PN2/PPPP1PPP/RNBQK2R w` | W e1:00,d1,a1,h1,c1,b5:93,b1,f3:13 / a2,b2,c2,d2,e3,f2,g2,h2; B e8:00,d7:19,a8,h8,c8,f8,c6:13,g8 / a7,b7,c5,d5,e7,f7,g7,h7 | d8→d7 00→00 | 01 00 FD F1 01 04 35 | - | 79 | F7 |
| 13 (sat) | `6k1/2q2p1p/b1pbp1r1/p2p4/3r3N/RPNPP1P1/2P2P1P/4R1K1 b` | W g1:30,-,a3:15,e1:15,-,-,c3:13,h4:13 / b3,-,c2,d3,e3,f2,g3,h2; B g8:30,c7:19,d4:15,g6:15,a6:93,d6:93,-,- / a5,c6,-,d5,e6,f7,-,h7 | a1→a3 00→06 | 02 09 FB 03 01 16 E6 | - | 02 | F3 |
| 14 (z-spaced020010) | `r1bqk1nr/pp1n1ppp/2pb4/3p4/P1PPp3/4P3/1P1N1PPP/RNBQKB1R b` | W e1:00,d1,a1,h1,c1,f1,b1,d2:13 / a4,b2,c4,d4,e3,f2,g2,h2; B e8:00,d8,a8,h8,c8,d6:93,d7:13,g8 / a7,b7,c6,d5,e4,f7,g7,h7 | a2→a4 00→00 | 00 00 F7 F1 01 06 D6 | - | 82 | 01 |
| 15 (z-spaced040020) | `8/1p4p1/5p2/3K1kp1/4qP2/8/8/8 w` | W d5:D0,-,-,-,-,-,-,- / -,-,-,-,-,f4,-,-; B f5:B0,e4:19,-,-,-,-,-,- / -,b7,-,-,-,f6,g7,g5 | e3→e4 00→C0 | 1F 00 F9 0D 01 3A 3C | - | 82 | 01 |
| 16 (z-spaced060007) | `r4kqr/7p/p1Q1p3/3p1b2/5Pn1/2N1P3/PP5P/R1B1K2R w` | W e1:00,c6:19,a1,h1,c1,-,c3:13,- / a2,b2,-,-,e3,f4,-,h2; B f8:10,g8:19,a8,h8,f5:93,-,-,g4:13 / a6,-,-,d5,e6,-,-,h7 | e8→f8 00→02 | 03 FF FC 00 01 10 A8 | - | 45 | F6 |
| 17 (z-spaced080017) | `8/8/8/3nk3/5K2/8/8/7q b` | W f4:90,-,-,-,-,-,-,- / -,-,-,-,-,-,-,-; B e5:D0,-,-,-,-,-,-,d5:13 / -,-,-,-,-,-,-,h1:19 | f3→f4 00→00 | 1E 08 F5 0C 01 44 D1 | - | 00 | 00 |
| 18 (z-spaced100004) | `1r1qk2r/p2bbBpp/5n2/8/4p3/2N1P3/PP1P1PPP/R1BQK2R b` | W e1:00,d1,a1,h1,c1,f7:93,c3:13,- / a2,b2,-,d2,e3,f2,g2,h2; B e8:00,d8,b8:15,h8,d7:93,e7:93,-,f6:13 / a7,-,-,-,e4,-,g7,h7 | d5→f7 08→8E | 02 FF FA FE 01 0B 10 | - | 66 | F7 |
| 19 (z-spaced120014) | `2b5/8/8/2k1K3/4R1p1/2N1P3/P4P2/8 b` | W e5:D0,-,e4:15,-,-,-,c3:13,- / a2,-,-,-,e3,f2,-,-; B c5:90,-,-,-,c8:93,-,-,- / -,-,-,-,-,-,g4,- | d4→e4 00→00 | 1E 00 01 F9 01 38 4C | - | 7F | FE |
| 20 (z-spaced140001) | `8/4P3/2k5/3RKQ2/8/8/8/1N6 b` | W e5:D0,-,d5:15,-,-,-,b1:13,- / -,-,-,-,e7,f5:19,-,-; B c6:90,-,-,-,-,-,-,- / -,-,-,-,-,-,-,- | c3→b1 00→00 | 1E 00 1A EA 01 5A E0 | - | 7C | F9 |
| 21 (z-spaced160011) | `8/4P3/8/2k1KQ2/8/6N1/8/7R b` | W e5:D0,-,h1:15,-,-,-,g3:13,- / -,-,-,-,e7,f5:19,-,-; B c5:90,-,-,-,-,-,-,- / -,-,-,-,-,-,-,- | e2→g3 00→00 | 1E 00 17 EB 01 62 0B | - | 80 | 00 |
| 22 (z-spaced180021) | `8/1k2P3/4N3/8/3Q4/4K3/6R1/8 b` | W e3:90,-,g2:15,-,-,-,e6:13,- / -,-,-,-,e7,d4:19,-,-; B b7:50,-,-,-,-,-,-,- / -,-,-,-,-,-,-,- | e4→e3 00→00 | 1E 00 1D EB 01 69 6A | - | 7E | FC |
| 23 (z-spaced200008) | `8/2k1P3/5R2/3Q4/4KN2/8/8/8 b` | W e4:D0,-,f6:15,-,-,-,f4:13,- / -,-,-,-,e7,d5:19,-,-; B c7:50,-,-,-,-,-,-,- / -,-,-,-,-,-,-,- | e5→e4 00→00 | 1E 00 1D EB 01 70 F3 | - | 7C | FB |
| 24 | `6k1/R7/8/8/3K4/8/8/8 b` (pawnless late endgame KR v K, centralisation (BD6D=0); model OK) | W d4:D0,-,a7,-,-,-,-,- / -,-,-,-,-,-,-,-; B g8:10,-,-,-,-,-,-,- / -,-,-,-,-,-,-,- | a1→a7 00→00 | 1E 00 00 05 00 32 10 | - | 8A | 0C |
| 25 | `6k1/R7/8/8/3K4/8/8/8 w` (same, black to move with BD1E sign matching black; model OK) | W d4:D0,-,a7,-,-,-,-,- / -,-,-,-,-,-,-,-; B g8:10,-,-,-,-,-,-,- / -,-,-,-,-,-,-,- | a1→a7 00→00 | 1F 00 00 FB 00 32 10 | - | 79 | F6 |
| 26 | `2k1N3/p7/8/3q2N1/8/2R5/5PP1/1N1R1RK1 b` (under-promoted knight and rook in pawn slots; model OK) | W g1:30,-,d1,f1,-,-,e8,b1 / g5:03,c3:05,f2,g2,-,-,-,-; B c8:10,d5,-,-,-,-,-,- / a7,-,-,-,-,-,-,- | e7→e8 00→C2 | 02 00 00 00 01 1E 00 | - | 6C | 09 |
| 27 | `4k3/p7/3N4/q7/8/8/8/4R1K1 b` (knight + rook double check (second pass); model OK) | W g1:10,-,e1,-,-,-,d6,- / -,-,-,-,-,-,-,-; B e8:00,a5,-,-,-,-,-,- / a7,-,-,-,-,-,-,- | c4→d6 00→86 | 02 00 00 00 01 14 00 | - | 53 | FE |
| 28 | `4k3/8/8/8/8/8/8/4R1K1 w` (side to move attacks enemy king: abort (A=0); model OK) | W g1:00,-,e1,-,-,-,-,- / -,-,-,-,-,-,-,-; B e8:00,-,-,-,-,-,-,- / -,-,-,-,-,-,-,- | e7→e8 00→00 | 03 00 00 00 00 14 00 | - | 00 | 00 |
| 29 | `4k3/p7/8/8/8/8/7P/4K3 b` (off-board junk: $BD28=$C4 read by white h2 pawn as a black pawn; model OK) | W e1:00,-,-,-,-,-,-,- / h2,-,-,-,-,-,-,-; B e8:00,-,-,-,-,-,-,- / a7,-,-,-,-,-,-,- | h3→h2 00→40 | 02 00 00 00 00 14 00 | BD28=C4 | 83 | 03 |
| 30 | `4k3/3p4/2n5/1B2p3/3P4/8/8/4K3 b` (absolute pin: black knight c6 pinned by Bb5 to Ke8; model OK) | W e1:00,-,-,-,b5,-,-,- / d4,-,-,-,-,-,-,-; B e8:00,-,-,-,-,-,c6,- / d7,e5,-,-,-,-,-,- | f1→b5 00→02 | 02 00 00 00 00 14 00 | - | 7A | 01 |

## 10. Verification method (reproducible)

1. **Capture.** Run the Level 1 demo from the entry snapshot in SkoolKit's simulator. Trap every `PC=$8400`, snapshot `$BC00–$BEFF` and the 4 IX bytes, run to the matching return (same SP), and record A, B and memory after.
2. **Model.** Load the captured "before" image into a 64K array, run the reference model, and compare A, B, IX+3 and every byte of `$BC00–$BEFF`. Exclude only the stack area `$BDA0–$BDFF` and the saved SP `$BD3D/E`.
3. **Fuzz.** Random positions:
   - 0–2 queens, 0–2 rooks/bishops, 0–3 knights, 0–8 pawns per side, with random moved/castled flags and under-promoted types in pawn records;
   - random phase bits, `$BD0D`, `$BD4A`, `$BD1E`, `$BD6D`, `$BD49`, `$BCCE`;
   - random junk in the off-board columns in 30% of cases.

   Each is written into memory and `$8400` is called directly (return trap at `$5B00`), then compared with the model.
4. **Coverage.** The union of instruction addresses executed during the capture and fuzz runs includes all 1,597 instructions of `$8400–$8F2E`.

The scripts are in `tools/research/eval/` (`capture.py`, `evalmodel.py`, `compare.py`, `fuzz.py`, `samples.py`, `construct.py`). For example, `fuzz.py reference/snapshots/cyrus48-idle-level1.z80 300 11` runs 300 random cases. The model is also reproduced verbatim in Appendix A.

## 11. Corrections and additions to `00-overview.md`

- **`$8400`:** returns an 8-bit score with `$80` = equal, from the mover's view. 0 = illegal; `$02`/`$FC` = saturated. **[V]**
- **Piece record +1:**
  - bit 4 = moved (all pieces);
  - king bit 5 = castled, king bits 6–7 = diagonal edge distance;
  - pawn type = rank code `$01`/`$11`/`$31`/`$61`/`$91`;
  - engine promotion = `$19`.
- **Piece record +6** is a line-mover mask (bit 0 K, bit 1 Q, bit 2 diagonal, bit 3 orthogonal, bits 6–7 pawn), not a "constant". Promoted pawns keep the pawn mask.
- **Record +2..+5** are evaluation attack bytes (§3), 0 at rest except in king records.
- **`$BD0D`** = material change since the search root, Black − White.
- **`$BD2D`** bits 1–4 = phase (move ≥ 8; material < 52 / 40 / 25).
- **`$BCCE`** is also incremented by every evaluation.
- **Move entry +3** bits written by eval: 7 check, 6 threat, 2 moved piece en prise, 1 mover left material en prise. (Make uses bit 0 for pawn-to-6th/7th and bit 3/5 for special moves.)
- **New eval variables:** `$BD39/$BD3A`, `$BD3B`, `$BD3D`, `$BD4E`, `$BD79–$BD85`.
- **`$8AB5`** is code (a return stub), not text.

## 12. Open questions

1. `$BD4A` and `$BD1E` are computed in `$7810` from `$BCA0`, `$BCBE` and `$BD2E` (subsystem B). Their exact meaning is outside this subsystem; eval treats them as inputs.
2. `$BD4E` is read by the search at `$7F27` (subsystem C). Its use there (a promotion-square test?) is to be documented by the search analysis.
3. Whether any code path can leave a non-zero byte in the off-board columns while the search runs (§8.1) needs a check by the owners of those variables. If it can, the port must keep the memory layout.

## Appendix A. Reference model (Python, verified)

The model operates on a 64 KB memory image and mirrors the original's register roles. `evaluate(mem, ix)` returns (A, B) and performs every memory side effect of `$8400`.

```python
"""Reference model of the Cyrus IS Chess evaluation routine $8400.

Operates on a 64K memory image (bytearray). Mirrors the original's register
usage closely enough to reproduce every side effect:
  E   main E: positional/mobility accumulator (8-bit)
  AP  A' accumulator: king-zone/pawn terms (8-bit)
  F   alternate B: pass flags (bit7 colour being processed, bit4 second pass,
      bit5 pin list non-empty, bit6 check seen, bits0-3 game phase)
"""


def s8(x):
    x &= 0xFF
    return x - 256 if x & 0x80 else x


def sra(x):
    x &= 0xFF
    return ((x >> 1) | (x & 0x80)) & 0xFF


class Abort(Exception):
    pass


BD, BE = 0xBD00, 0xBE00


class Eval:
    def __init__(self, mem, ix):
        self.m = mem
        self.ix = ix

    # ----- helpers -------------------------------------------------------
    def friendly(self, code):
        return ((code ^ self.F) & 0x80) == 0

    def add(self, addr, v):
        self.m[addr] = (self.m[addr] + v) & 0xFF

    def run(self):
        m = self.m
        self.E = 0
        self.AP = 0
        s = m[BD + 0x2D]
        a = ((s >> 1) | ((s & 1) << 7)) & 0xFF
        carry = s & 1
        if a & 2:
            self.pawn_mode = 0x8A2B if a & 4 else 0x8A6F
        else:
            self.pawn_mode = 0x8A7A
        self.F = (a + 0x80) & 0xFF
        try:
            if carry:
                self.white_section()
            else:
                self.black_section()
            return self.final()
        except Abort:
            for rec in range(0x08, 0x100, 8):
                for k in range(2, 6):
                    m[BE + rec + k] = 0
            m[BD + 0x79] = 0
            self.B = 0
            return 0

    # ----- sections ------------------------------------------------------
    def black_section(self):                         # $842B
        m = self.m
        self.D = 0x88
        for rec, fn in ((0x88, self.queen), (0x90, self.rook), (0x98, self.rook),
                        (0xA0, self.black_bishop), (0xA8, self.black_bishop),
                        (0xB0, self.black_knight), (0xB8, self.black_knight)):
            sq = m[BE + rec]
            if not sq & 0x80:
                fn(sq)
        self.pawns(0xF1, 0xC0)
        self.after_section()

    def white_section(self):                         # $883A
        m = self.m
        self.D = 0x88
        for rec, fn in ((0x08, self.queen), (0x10, self.rook), (0x18, self.rook),
                        (0x20, self.white_bishop), (0x28, self.white_bishop),
                        (0x30, self.white_knight), (0x38, self.white_knight)):
            sq = m[BE + rec]
            if not sq & 0x80:
                fn(sq)
        self.pawns(0x11, 0x40)
        # kings
        self.white_king(m[BE + 0x01], m[BE + 0x00])
        self.AP = (-self.AP) & 0xFF
        self.E = (-self.E) & 0xFF
        self.F |= 0x80
        self.king(m[BE + 0x81], m[BE + 0x80])
        if self.F & 0x10:
            return                                   # -> $84A9
        self.F |= 0x10
        self.black_section()

    def after_section(self):                         # $84A3
        if self.F & 0x10:
            return                                   # -> $84A9
        self.F = (self.F + 0x90) & 0xFF              # $882C
        self.E = (-self.E) & 0xFF
        self.AP = (-self.AP) & 0xFF
        self.white_section()

    # ----- pawns ---------------------------------------------------------
    def pawns(self, d, base):
        m = self.m
        self.D = d
        self.pb = 0xFF
        self.pc = 0xFF
        for i in range(8):
            rec = base + 8 * i
            sq, typ = m[BE + rec], m[BE + rec + 1]
            if sq & 0x80:
                continue
            self.pawn(sq, typ, i in (3, 4))

    def pawn(self, L, H, centre):
        m = self.m
        if centre and not ((L + 0x20) & 0x40):       # $8A54
            self.E = (self.E - 3) & 0xFF
        if H & 0x0E:                                 # $8A96 promoted
            saveD, saveB, saveC = self.D, self.pb, self.pc
            self.D = 0x88
            if H & 0x08:
                self.queen(L)
            elif H & 0x04:
                self.rook(L)
            elif H & 0x80:
                self.bishop(L)
            else:
                self.knight(L)
            self.D, self.pb, self.pc = saveD, saveB, saveC
            return
        L = (self.D + L) & 0xFF
        f = L & 0x0F
        if f == self.pb or f == self.pc:
            self.E = (self.E - 3) & 0xFF
        self.pc = self.pb
        self.pb = f
        mode = self.pawn_mode
        if mode == 0x8A6F:
            H >>= 1
            if H:
                H >>= 2
                self.AP = (self.AP + H) & 0xFF
        elif mode == 0x8A2B:
            H >>= 2
            self.AP = (self.AP + H) & 0xFF
            if (H & 0x20) and not (self.F & 0x10):
                m[BD + 0x4E] = m[BD + ((L - 1) & 0xFF)]
        a = m[BD + L]
        if a:
            self.pawn_hit(a)
        L = (L - 2) & 0xFF
        a = m[BD + L]
        if a:
            self.pawn_hit(a)

    def pawn_hit(self, code):                        # $8A85
        m = self.m
        if self.friendly(code):
            self.add(BE + code, 1)
        elif not code & 0x78:                        # $8ABA king
            if not self.F & 0x10:
                raise Abort
            m[self.ix + 3] |= 0x80
            self.E = (self.E + 1) & 0xFF
        else:
            self.add(BE + ((code - 2) & 0xFF), 1)

    # ----- knights -------------------------------------------------------
    def white_knight(self, sq):                      # $8CC8
        if not sq & 0x70:
            self.E = (self.E - 3) & 0xFF
        self.knight(sq)

    def black_knight(self, sq):                      # $8CBB
        if (sq | 0x70) == sq:
            self.E = (self.E - 3) & 0xFF
        self.knight(sq)

    def knight(self, sq):                            # $8CCD
        self.C2 = 0x04
        self.E = (self.E - 1) & 0xFF
        self.knight_walk(sq)

    def knight_walk(self, B):                        # $8CD2
        D = self.D
        if not ((B + 0x0E) & 0x80):
            for off in (0x0E, 0x12, 0x1F, 0x21):
                L = (B + off) & 0xFF
                if not L & D:
                    self.knight_target(L, B)
        if (B + 0xF2) & 0x80:
            return
        for off in (0xF2, 0xEE):
            L = (B + off) & 0xFF
            if not L & D:
                self.knight_target(L, B)
        if (B + 0xE1) & 0x80:
            return
        for off in (0xE1, 0xDF):
            L = (B + off) & 0xFF
            if not L & D:
                self.knight_target(L, B)

    def knight_target(self, L, B):                   # $8D15
        m = self.m
        self.E = (self.E + 1) & 0xFF
        code = m[BD + L]
        if not code:
            return
        if self.friendly(code):
            self.add(BE + code, self.C2)
        elif not code & 0x78:                        # $8D2A
            self.king_check(B, double_ap=True)
        else:
            self.add(BE + ((code - 2) & 0xFF), self.C2)

    def king_check(self, B, double_ap):
        """Second-pass king attacked by knight ($8D2A) or slider ($8D4C)."""
        m = self.m
        if not self.F & 0x10:
            raise Abort
        m[self.ix + 3] |= 0x80
        was = self.F & 0x40
        self.F |= 0x40
        if was:
            m[BD + 0x4E] = 0
            self.AP = (self.AP + 0x14) & 0xFF
        else:
            code = m[BD + B]
            m[BE + ((code + 1) & 0xFF)] |= 0x02
            self.E = (self.E + 2) & 0xFF

    # ----- bishops -------------------------------------------------------
    def white_bishop(self, sq):                      # $8D74
        if not sq & 0x70:
            self.E = (self.E - 3) & 0xFF
        self.bishop(sq)

    def black_bishop(self, sq):                      # $8D80
        if (sq | 0x70) == sq:
            self.E = (self.E - 3) & 0xFF
        self.bishop(sq)

    def bishop(self, sq):                            # $8D86
        self.C2 = 0x04
        self.diagonals(sq)

    def diagonals(self, B):                          # $8D89
        self.E2 = 0xC4
        for c in (0x0F, 0x11, 0xEF, 0xF1):
            self.C = c
            L = (B + c) & 0xFF
            if not L & self.D:
                self.ray_mob(L, B)

    def ray_mob(self, L, B):
        """$8DAF/$8DAA: scan counting mobility; handle the first piece hit."""
        m = self.m
        while True:
            self.E = (self.E + 1) & 0xFF
            code = m[BD + L]
            if code:
                break
            L = (L + self.C) & 0xFF
            if L & self.D:
                return
        if self.friendly(code):                      # $8DEC
            self.add(BE + code, self.C2)
            self.after_friendly(code, L)
        else:
            self.enemy_hit(code, L, B)

    def after_friendly(self, code, L):               # $8DEF
        t = self.m[BE + ((code + 2) & 0xFF)] & self.E2
        if not t:
            return
        if t & 0x80:
            self.pawn_xray(t, L)
        else:
            self.xray_chain(L)

    def pawn_xray(self, t, L):                       # $8E5C
        m = self.m
        if not (((t << 1) & 0xFF) ^ self.C) & 0x80:
            return
        L = (L + self.C) & 0xFF
        if L & self.D:
            return
        code = m[BD + L]
        if not code:
            return
        if self.friendly(code):
            self.add(BE + ((code + 1) & 0xFF), self.C2)
        else:
            self.add(BE + ((code - 1) & 0xFF), self.C2)

    def xray_chain(self, L):                         # $8DF8
        m = self.m
        while True:
            L = (L + self.C) & 0xFF
            if L & self.D:
                return
            self.E = (self.E + 1) & 0xFF
            code = m[BD + L]
            if not code:
                continue
            if not self.friendly(code):              # $8E07
                self.add(BE + ((code - 1) & 0xFF), self.C2)
                return
            self.add(BE + ((code + 1) & 0xFF), self.C2)   # $8E0D
            t = m[BE + ((code + 2) & 0xFF)] & self.E2
            if not t:
                return
            if t & 0x80:
                self.pawn_xray(t, L)
                return

    def enemy_hit(self, code, L, B):                 # $8DB9
        m = self.m
        if not code & 0x78:                          # $8D4C king
            self.king_check(B, double_ap=True)
            # $8DAA: continue the ray beyond the king, counting mobility
            L = (L + self.C) & 0xFF
            if L & self.D:
                return
            self.ray_mob(L, B)
            return
        r2 = (code - 2) & 0xFF
        self.add(BE + r2, self.C2)
        r6 = r2 | 0x04
        t = m[BE + r6] & self.E2
        if t and not t & 0x80:
            # enemy slider on this line: look beyond ($8DCD)
            while True:
                L = (L + self.C) & 0xFF
                if L & self.D:
                    return
                code2 = m[BD + L]
                if code2:
                    break
            if self.friendly(code2):                 # $8E15
                self.add(BE + ((code2 + 1) & 0xFF), self.C2)
                return
            self.add(BE + ((code2 - 1) & 0xFF), self.C2)
            self.pin_check(r6, code2)
        else:
            while True:                              # $8E19
                L = (L + self.C) & 0xFF
                if L & self.D:
                    return
                code2 = m[BD + L]
                if code2:
                    break
            if self.friendly(code2):
                return
            self.pin_check(r6, code2)

    def pin_check(self, r6, code2):                  # $8DE1
        t = self.m[BE + ((code2 + 2) & 0xFF)]
        if t & 1:
            self.pin(r6)
        elif t & 2:
            if self.C2 & 0x40:                       # $8E2B queen pinning to queen
                self.E = (self.E + 2) & 0xFF
            else:
                self.pin(r6)

    def pin(self, r6):                               # $8E2F
        m = self.m
        rec = r6 & 0xF9
        L = 0x79
        while True:
            a = m[BD + L]
            if not a:
                break
            L += 2
            if a == rec:
                m[BD + L - 1] = 0
                self.E = (self.E + 1) & 0xFF
                return
        if L >= 0x84:
            self.E = (self.E + 2) & 0xFF
            return
        m[BD + L] = rec
        m[BD + L + 1] = self.C
        m[BD + L + 2] = 0
        self.F |= 0x20
        self.E = (self.E + 2) & 0xFF

    # ----- rooks / queens ------------------------------------------------
    def rook(self, sq):                              # $8C4E
        self.C2 = 0x10
        self.orthogonals(sq)

    def queen(self, sq):                             # $8C43
        self.C2 = 0x40
        self.orthogonals(sq)
        self.diagonals(sq)

    def orthogonals(self, B):                        # $8C52
        m = self.m
        self.E2 = 0x08
        for c in (0x01, 0xFF):
            self.C = c
            L = B
            while True:
                L = (L + c) & 0xFF
                if L & 0x08:
                    break
                code = m[BD + L]
                if code:
                    self.horiz_hit(code, L, B)
                    break
        for c in (0x10, 0xF0):
            self.C = c
            L = B
            while True:
                L = (L + c) & 0xFF
                if L & 0x80:
                    break
                self.E = (self.E + 1) & 0xFF
                code = m[BD + L]
                if code:
                    if self.friendly(code):          # $8C80
                        self.add(BE + code, self.C2)
                        if m[BE + ((code + 2) & 0xFF)] & self.E2:
                            self.xray_chain(L)
                    else:
                        self.enemy_hit(code, L, B)
                    break

    def horiz_hit(self, code, L, B):                 # $8C98
        m = self.m
        if not self.friendly(code):
            self.enemy_hit(code, L, B)
            return
        self.add(BE + code, self.C2)
        if not m[BE + ((code + 2) & 0xFF)] & self.E2:
            return
        while True:                                  # $8CA7
            L = (L + self.C) & 0xFF
            if L & self.D:
                return
            code2 = m[BD + L]
            if code2:
                break
        if self.friendly(code2):
            self.add(BE + ((code2 + 1) & 0xFF), self.C2)
        else:
            self.add(BE + ((code2 - 1) & 0xFF), self.C2)

    # ----- kings ---------------------------------------------------------
    def white_king(self, H, L):                      # $8978
        m = self.m
        if not self.F & 0x01:                        # $8915
            c = ((~m[BD + 0x49]) + 0x0A) & 0xFF
            if (m[BE + 0x89] & 0x10) and not (m[BE + 0x88] & 0x80):
                self.E = (self.E + c) & 0xFF
            if (m[BE + 0x09] & 0x10) and not (m[BE + 0x08] & 0x80):
                self.E = (self.E - c) & 0xFF
        self.king(H, L)

    def king(self, H, L):                            # $897D
        m = self.m
        F = self.F
        if F & 0x04:
            self.endgame_king(H, L)
            return
        if H & 0x20:
            if H & 0xC0:
                self.king_89FB(H, L)
                return
            self.C = 0x0A
            t = (L + 0x1F) & 0xFF
            if t & 0x80:
                t = (t - 0x40) & 0xFF
            if not ((m[BD + t] | m[BD + ((t + 1) & 0xFF)] | m[BD + ((t + 2) & 0xFF)]) & 0x40):
                self.E = (self.E - 2) & 0xFF
            self.king_scan(L)
            return
        if not H & 0x10:                             # $8A0D
            self.C = 0
            self.E = (self.E + 1) & 0xFF
            self.king_scan(L)
            return
        self.E = (self.E - 6) & 0xFF                 # $8A1A
        self.C = 0x08
        if H & 0xC0:
            self.king_89FB(H, L)
            return
        self.king_scan(L)

    def king_89FB(self, H, L):
        self.C = 0x04
        self.E = (self.E - (5 if H & 0x80 else 3)) & 0xFF
        self.king_scan(L)

    def endgame_king(self, H, L):                    # $8943
        m = self.m
        F = self.F
        if not F & 0x08:
            self.C = 0x08
            self.king_scan(L)
            return
        self.C = 0x04                                # $894F
        D = (H & 0xC0) >> 3
        bd1e = m[BD + 0x1E]
        if bd1e and not ((bd1e ^ F) & 0x80):
            a = m[BD + 0x6D]                         # $88D4
            if a:
                self.AP = (self.AP + D) & 0xFF
            else:
                if not D:
                    D = 0xF6
                f = ((L & 7) + 1) >> 1
                r = L & 0x70
                if f == 2 or r in (0x30, 0x40):
                    self.AP = (self.AP + 0x10 + D) & 0xFF
                elif (L & 7) in (2, 5) or r in (0x20, 0x50):
                    self.AP = (self.AP + 0x08 + D) & 0xFF
                else:
                    self.AP = (self.AP + D) & 0xFF
            self.king_scan(L)
            return
        a = m[BD + 0x6D] if bd1e else 0
        D >>= 1                                      # $8966
        if not a and (H & 0x80):
            self.AP = (self.AP + 0x08) & 0xFF
        self.AP = (self.AP + D) & 0xFF
        self.king_scan(L)

    def king_scan(self, B):                          # $89AC
        m = self.m
        for L in ((B - 1) & 0xFF, (B + 1) & 0xFF):
            a = m[BD + L]
            if a:
                self.king_nb(a)
        t = (B + 0x10) & 0xFF
        if not t & 0x80:
            for L in (t, (t + 1) & 0xFF, (t - 1) & 0xFF):
                a = m[BD + L]
                if a:
                    self.king_nb(a)
        t = (B + 0xF0) & 0xFF
        if t & 0x80:
            return
        for L in (t, (t + 1) & 0xFF, (t - 1) & 0xFF):
            a = m[BD + L]
            if a:
                self.king_nb(a)

    def king_nb(self, code):                         # $89E2
        if self.friendly(code):
            p = (code + 1) & 0xFF
        else:
            if not ((code + 1) & 0x78):
                raise Abort
            p = (code - 1) & 0xFF
        self.add(BE + p, 1)
        if p & 0x40:
            self.AP = (self.AP + self.C) & 0xFF

    # ----- pins ----------------------------------------------------------
    def pins(self):                                  # $8E74
        m = self.m
        saveD, saveE = self.D, self.E
        i = 0x79
        while True:
            rec = m[BD + i]
            pdir = m[BD + i + 1]
            self.F = rec & 0x80
            sq = m[BE + rec]
            t = m[BE + rec + 1] & 0x8E
            self.D = 0x88
            if t == 0 or (t & 0x80 and not t & 0x02):
                self.pin_undo_pawn(sq, pdir)
            elif t & 0x80:
                self.C2 = 0xFC
                self.undo_diag(sq, pdir)
            elif t < 4:
                self.C2 = 0xFC
                self.F |= 0x10
                self.knight_walk(sq)
            elif t == 4:
                self.C2 = 0xF0
                self.undo_orth(sq, pdir)
            else:
                self.C2 = 0xC0
                self.undo_orth(sq, pdir)
                self.undo_diag(sq, pdir)
            nxt = m[BD + i + 2]
            if not nxt:
                break
            i += 2
        self.D, self.E = saveD, saveE
        m[BD + 0x79] = 0

    def pin_undo_pawn(self, sq, pdir):               # $8E9F
        m = self.m
        c0 = 0xEF if self.F & 0x80 else 0x0F
        for c in (c0, (c0 + 2) & 0xFF):
            if pdir == c or ((-pdir) & 0xFF) == c:
                continue
            code = m[BD + ((sq + c) & 0xFF)]
            if not code:
                continue
            if self.friendly(code):
                self.add(BE + code, 0xFF)
            else:
                self.add(BE + ((code - 2) & 0xFF), 0xFF)

    def undo_orth(self, sq, pdir):                   # $8ED7
        self.undo_line(sq, pdir, 0x01)
        self.undo_line(sq, pdir, 0x10)

    def undo_diag(self, sq, pdir):                   # $8EED
        self.undo_line(sq, pdir, 0x0F)
        self.undo_line(sq, pdir, 0x11)

    def undo_line(self, B, pdir, c):                 # $8EF4
        if pdir == c or ((-pdir) & 0xFF) == c:
            return
        for d in (c, (-c) & 0xFF):
            self.undo_ray(B, d)

    def undo_ray(self, B, c):                        # $8F05
        m = self.m
        L = B
        while True:
            L = (L + c) & 0xFF
            if L & 0x88:
                return
            code = m[BD + L]
            if code:
                break
        if self.friendly(code):
            self.add(BE + code, self.C2)
        else:
            self.add(BE + ((code - 2) & 0xFF), self.C2)

    # ----- exchange evaluation -------------------------------------------
    def final(self):                                 # $84A9
        m = self.m
        F = self.F
        if not F & 0x40:
            code = m[BD + m[self.ix + 2]]
            if code & 0x04:
                m[BE + ((code + 1) & 0xFF)] |= 0x02
        if F & 0x08:
            if not m[BD + 0x6D]:
                self.E = sra(self.E)
            self.E = sra(self.E)
        if F & 0x20:
            self.pins()
        self.E = (sra(sra(self.AP)) + self.E + m[BD + 0x4A]) & 0xFF
        m[BD + 0x39] = m[BD + 0x3A] = 0
        m[BD + 0x3B] = self.ix & 0xFF
        m[BD + 0x3C] = self.ix >> 8
        self.see_side(0x88)
        self.E = (-self.E) & 0xFF
        black_best, black_second = m[BD + 0x39], m[BD + 0x3A]
        m[BD + 0x39] = m[BD + 0x3A] = 0
        self.see_side(0x08)
        return self.combine(black_best, black_second)

    def see_side(self, base):
        m = self.m
        values = (9, 5, 5, 3, 3, 3, 3)
        for i in range(15):
            rec = base + 8 * i
            a = BE + rec
            if m[a + 2] or m[a + 3]:
                v = values[i] if i < 7 else (m[a + 1] & 0x0F)
                self.see(v, m[a + 2], m[a + 3], m[a + 4], m[a + 5])
                m[a + 2] = m[a + 3] = 0
            m[a + 4] = m[a + 5] = 0

    def gen_att(self, L, H):
        if L:
            for mask, sh, v in ((0x03, 0, 1), (0x0C, 2, 3), (0x30, 4, 5), (0xC0, 6, 9)):
                n = (L & mask) >> sh
                if n:
                    yield v, n
            if not H:
                return
        for mask, sh, v in ((0x0C, 2, 3), (0x30, 4, 5), (0xC0, 6, 9)):
            n = (H & mask) >> sh
            if n:
                yield v, n
        if H & 1:
            yield 13, 1

    def gen_def(self, C, B):
        if C:
            for mask, sh, v in ((0x03, 0, 1), (0x0C, 2, 3), (0x30, 4, 5), (0xC0, 6, 9)):
                n = (C & mask) >> sh
                if n:
                    yield v, n
        if not B:
            return
        for mask, sh, v in ((0x0C, 2, 3), (0x30, 4, 5), (0xC0, 6, 9)):
            n = (B & mask) >> sh
            if n:
                yield v, n
        if B & 1:
            self.E = (self.E - 1) & 0xFF             # $8C1F
            yield 13, 1

    def see(self, V, L, H, C, Bm):                   # $8AD6
        m = self.m
        if not L and not H & 1:
            return
        att = self.gen_att(L, H)
        dfn = self.gen_def(C, Bm)
        attv, attn = next(att, (0, 0))
        defv, defn = next(dfn, (0, 0))
        A = V
        lo = 0xFF
        hi = V
        while True:
            b = 0
            if not defv & 1:
                break
            A = (A - attv) & 0xFF
            attn = (attn - 1) & 0xFF
            if attn == 0:
                attv, n = next(att, (0, None))
                if n is not None:
                    attn = n
            if (A - lo) & 0x80:
                b = 1
            elif not ((A - hi) & 0x80):
                b = 2
            else:
                lo = A
            if not attv & 1:
                break
            A = (A + defv) & 0xFF
            if (A - lo) & 0x80:
                b = (b - 1) & 0xFF
                if b == 0:
                    break
            elif not ((A - hi) & 0x80):
                b = (b - 2) & 0xFF
                if b == 0:
                    break
            else:
                hi = A
            defn = (defn - 1) & 0xFF
            if defn == 0:
                defv, n = next(dfn, (0, None))
                if n is not None:
                    defn = n
        if (A - lo) & 0x80:
            A = lo
        if not ((A - hi) & 0x80):
            A = hi
        if A & 0x80:
            return
        if A:
            best = m[BD + 0x39]
            if A >= best:
                m[BD + 0x39] = A
                A = best
            if A >= m[BD + 0x3A]:
                m[BD + 0x3A] = A
        self.E = (self.E - 1) & 0xFF
        if Bm & 0x02:
            m[self.ix + 3] |= 0x04
            self.E = (self.E - 2) & 0xFF

    def combine(self, bb, bs):                       # $8797
        m = self.m
        pos = self.E
        wb, ws = m[BD + 0x39], m[BD + 0x3A]
        if m[BD + 0x2D] & 1:
            pos = (-pos) & 0xFF
            sb, ss, mb, ms = wb, ws, bb, bs
            A = m[BD + 0x0D]
        else:
            sb, ss, mb, ms = bb, bs, wb, ws
            A = (-m[BD + 0x0D]) & 0xFF
        ix3 = self.ix + 3
        A = (A - mb) & 0xFF
        A = (A + A) & 0xFF
        if not ((mb - 1) & 0x80):
            m[ix3] |= 0x02
            if mb != 1:
                A = (A - 1) & 0xFF
            A = (A - ms) & 0xFF
        if not ((sb - 1) & 0x80):
            goto_e2 = False
            if m[ix3] & 0x04:
                goto_e2 = True
            else:
                pos = (pos + 2) & 0xFF
                if (ss - 1) & 0x80:
                    goto_e2 = True
                else:
                    m[ix3] |= 0x40
                    pos = (pos + 2) & 0xFF
                    if not ((ss - 2) & 0x80):
                        pos = (pos + 2) & 0xFF
            if goto_e2 and ((sb - 1) & 0xFF) >= mb:
                m[ix3] |= 0x40
        self.B = pos
        if not (A < 0x1C or A >= 0xE4):
            return 0x02 if A & 0x80 else 0xFC
        C = (4 * A) & 0xFF
        t = sra(pos)
        t = (t + pos + (pos & 1)) & 0xFF
        t = sra(t)
        m[0xBCCE] = (m[0xBCCE] + 1) & 0xFF
        r = m[0xBCCE] & (3 if m[BD + 0x49] == 1 else 1)
        t = (r + t) & 0xFF
        if not (t < 0x0C or t >= 0xF4):
            t = 0xF4 if t & 0x80 else 0x0C
        return (t + C + 0x80) & 0xFF


def evaluate(mem, ix):
    ev = Eval(mem, ix)
    a = ev.run()
    return a, ev.B
```
