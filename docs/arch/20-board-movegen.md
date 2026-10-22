# Subsystem B: board, pre-search set-up, move generation, make/unmake

This covers code ranges `$7810–$7AC6` and `$80A7–$83FF`, and the direction tables at `$7800–$780F`. The annotated control files are `disasm/ctl/20-movegen.ctl` and `disasm/ctl/40-makemove.ctl`.

Tags:
- **[V]** verified, by code reading plus a simulator experiment;
- **[C]** read from code, but not exercised dynamically;
- **[I]** inferred.

## Verification summary

All experiments run the original code in SkoolKit's simulator, using the scripts in `tools/research/movegen/` (`compare.py` checks move order and move set against python-chess; `makeunmake.py` checks make/unmake round trips). `probe.py` pokes a position into `$BD00`/`$BE00` and calls `$78CE` directly.

| Test | Result |
|---|---|
| Start position, both sides | `$78CE` output matches the hand-derived order exactly **[V]** |
| 200 random positions from random games (`compare.py`) | Exact order equals the Python model below in **200/200** positions. The move set equals python-chess's pseudo-legal set (promotions collapsed, castling compared separately) in **200/200** |
| 18 targeted positions (`targeted.py`) | En passant both colours, including from the a-file and h-file; castling both sides; castling suppressed by the check flag; castling through an attacked square (generated); promotions and capture-promotions; promoted queens in pawn slots; edge pawns. All match the model and python-chess **[V]** |
| `makeunmake.py` (3,793 legal moves in 120 random positions) | Board and piece records after make match python-chess. `$BD0D` delta correct. Unmake restores `$BD00–$BD7F` and `$BE00–$BEFF` byte-exactly, and SP is restored **[V]** |
| `mu_targeted.py` | En passant, castling (score byte 0 and `$FF`), promotion, capture-promotion: all restore exactly **[V]** |
| `bigcount.py` | A 218-move position generates 218 moves, but the header count byte is 90 (the bug in §6.1) **[V]** |
| `stats.py` (200 s demo at Level 1 and 400 s at Level 4, with interrupts) | Max ply at `$78CE` was 3 / 5; max moves in a list 50 / 52; highest list end `$B778`; lowest SP `$BDCA`. The off-board pawn-capture cells (§6.5) were always 0 **[V]** |

## 1. Routines

| Address | Label | Role |
|---|---|---|
| `$7810` | `PRESEARCH` | Pre-search set-up: eval call, `$BD1E`, `$BD4A`, `$BD2E`, game-phase bits of `$BD2D` |
| `$789D` | `MATERIAL` | Sum of the value nibbles of 15 non-king records; sets the pawns-present flag `$BD6D` |
| `$78BA` | `POLLGEN` | Keyboard poll (search abort), then falls into `$78CE`. Used by the search at every node |
| `$78CE` | `GENMOVES` | Pseudo-legal move generator |
| `$79C8` | `GEN_PROMOTED` | Promoted piece in a pawn slot (dispatch by type byte) |
| `$79E0` | `GEN_PROMOTED_RET` | **Code**, not data: the return point pushed at `$79CF` (`POP BC / EXX / JR $799C`) |
| `$79E4` | `GEN_EP` | En passant capture |
| `$79FC` | `GEN_EPFLAG` | Flag a double push `$20` when an enemy pawn lands beside it |
| `$7A13`/`$7A15` | `GEN_KNIGHT`(`_X`) | Knight (8 jumps via `$7A18`) |
| `$7A18` | `GEN_STEPS` | 8 single steps from the direction table (king, knight) |
| `$7A2E`/`$7A30` | `GEN_ROOK`(`_X`) | Rook: slide over `$780C` (4 directions) |
| `$7A33`/`$7A35` | `GEN_SLIDE4`/`GEN_SLIDE` | Slide loop |
| `$7A4F`/`$7A51` | `GEN_BISHOP`(`_X`) | Bishop: slide over `$7808` (4 directions) |
| `$7A57`/`$7A59` | `GEN_QUEEN`(`_X`) | Queen: slide over `$7808` (8 directions) |
| `$7A61` | `GEN_CASTLE` | Castling (kingside first) |
| `$7A93` | `ADD_CASTLE` | Add a move with flags `$10` |
| `$7A97` | `ADD_CAPTURE` | Add a capture if the target holds an enemy piece |
| `$7A9D` | `ADD_MOVE` | Append an entry; list-full check |
| `$7AC0` | `BOOK_OFF` | `$BCDF = $FF`, return NZ (used by the book code) |
| `$80A7`, `$80AB`, `$80BB` | `PRUNE_*` | Search: move-list pruning targets of `$805F` (see §5) |
| `$80C4` | `HORIZON_CUT` | Search: even-ply cut-off at the depth limit (see §5) |
| `$80E2`, `$80ED`, `$80FA` | `SRCH_*` | Search: select a move, make it, descend (see §5) |
| `$810F` | `MAKEMOVE` | Make |
| `$8200`/`$8203` | `KINGTYPE`(`_X`) | King type byte: moved bit plus centralisation |
| `$821C` | `UNMAKE` | Unmake |
| `$826E` | `UN_PROMO_FIX` | Undo the promotion's `$BD0D` adjustment |
| `$828C–$83FF` | — | Zero padding |

## 2. Data structures

### 2.1 Board `$BD00` (0x88) **[V]**

`$BD00 + sq`, where `sq = rank*16 + file` (0-based; a1 = `$00`, h8 = `$77`). A byte is either 0 (empty) or a piece code.

**Piece code**:
- bit 7 = Black;
- bit 2 = always 1, so a code is never 0;
- `code AND $FB` (bit 2 cleared) is the offset of the piece's record in page `$BE`.

The codes are therefore `$04 + 8*slot` (White) and `$84 + 8*slot` (Black), with slot 0..15. A code stays with the same slot for the whole game; a promoted pawn keeps its pawn-slot code.

The off-board bytes (file nibble 8..F) are variables (see §3). **Pawn capture generation reads columns 8 and F without a bounds check** (§6.5).

### 2.2 Piece records `$BE00` (White) and `$BE80` (Black) **[V]**

There are 16 records of 8 bytes, in fixed slots:

| Slot | Offset | Piece at the start |
|---|---|---|
| 0 | `+$00` | King |
| 1 | `+$08` | Queen |
| 2 | `+$10` | Rook a (queenside: used for O-O-O) |
| 3 | `+$18` | Rook h (kingside: used for O-O) |
| 4, 5 | `+$20`, `+$28` | Bishops c, f |
| 6, 7 | `+$30`, `+$38` | Knights b, g |
| 8–15 | `+$40`…`+$78` | Pawns a…h |

**Slot order is generation order**, so it determines move order and therefore tie-breaking. A FEN loader must assign slots exactly as the original's set-up mode does. That is subsystem A's code (`$660A` and nearby); it is **not** specified here.

| Byte | Meaning |
|---|---|
| +0 | Square (0x88). **Bit 7 set = captured** (set by make, `$81AB`). The generator skips a record with bit 7 set, except the king (§6.6) **[V]** |
| +1 | Type byte, see below **[V]** |
| +2…+5, +7 | 0 at rest. Not touched by subsystem B **[I]**; possibly evaluation working storage (subsystem E) |
| +6 | Per-piece constant: K `$01`, Q `$0E`, R `$08`, B `$04`, N `$00`, P `$C0` (White) / `$80` (Black). Not used by subsystem B **[I]**; evaluation |

**Type byte (+1)**:
- bits 0–3 = material value: K 0, P 1, N 3, B 3, R 5, Q 9.
- bit 7 = bishop (distinguishes B from N).
- bit 4 = has moved (R/Q/B/N: set on every move by make at `$8132`; K: set by `$8200`). For pawns it is part of the advancement nibble.
- **King**: bit 5 = has castled (`$81CF`); bits 6–7 = centralisation `min(file, rank, 7−file, 7−rank)` capped at 3, recomputed on every king move (`$8200`).
- **Pawn**: the high nibble encodes advancement, written by make (`$813D`) from the relative rank of the to-square: 4th rank `$11`, 5th `$31`, 6th `$61`, 7th `$91`. On the 2nd/3rd rank it stays `$01`. On promotion the type becomes `$19` (queen + moved).
- **Promoted piece in a pawn slot**: the generator dispatches on `type AND $0E ≠ 0` (`$7953`): bit 7 → bishop, else bit 1 → knight, else bit 2 → rook, else queen. Search promotions are always to a queen (`$19`). The UI writes `5`/`3`/`$83` for user under-promotions (`$63B1`, subsystem A) **[C]**.

### 2.3 Move lists **[V]**

- **Area**: `$B400–$BC83`. A list is a header entry followed by 4-byte move entries and a terminator. Each ply's list starts where the previous ply's list ended (at its terminator). All entries are 4-byte aligned.
- **Ply table**: `$BCA9` = current ply p (1 at the root). The word at `$BCA9 + 2p` is the start (header address) of ply p's list. The generator writes the end address (the terminator) to `$BCA9 + 2(p+1)`. `$BCAB` = `$B400` (ply 1) is set at new game (`$653B`). `$BCAA` is not part of the table; the search uses it for the iteration depth.
- **Header** (at the list start):

  | Byte | Meaning |
  |---|---|
  | +0 | `$FF` |
  | +1 | move count n (**wrong for n ≥ 127**, §6.1) |
  | +2 | 0 (used by the search) |
  | +3 | parent flags `AND $81` (bit 7 = side to move is in check; bit 0 = parent was a pawn move to the 6th/7th rank) |

- **Move entry**:

  | Byte | Meaning |
  |---|---|
  | +0 | score. `$FF` when generated = unscored; root scoring writes the evaluation; the search writes 0 when a move is selected or pruned |
  | +1 | from-square. Bit 7 can be set by the search as a marker (`$8053`) |
  | +2 | to-square |
  | +3 | flags |

- **Terminator**: `$FF` at +0 of the entry after the last move.

**Flags byte (+3)**:

| Bit | Value | Meaning | Set by |
|---|---|---|---|
| 0 | `$01` | pawn moved to the 6th/7th rank (cleared again for a promotion) | make `$814F`/`$815D` **[V]** |
| 1 | `$02` | evaluation-defined | eval `$87BB` **[C]** |
| 2 | `$04` | evaluation-defined (used by pruning, §5) | eval `$8B46` **[C]** |
| 3 | `$08` | capture | generator **[V]** |
| 4 | `$10` | castling | generator **[V]** |
| 5 | `$20` | double pawn push landing beside an enemy pawn (en passant possible) | generator `$7A0D` **[V]** |
| 3+5 | `$28` | en passant capture | generator **[V]** |
| 6 | `$40` | evaluation-defined | eval `$87D3`/`$87E8` **[C]** |
| 7 | `$80` | move gives check | eval `$8ABF`/`$8D2F`/`$8D51` **[C]**. The root record `$BD5B` bit 7 selects CHECKMATE vs STALEMATE at `$641A` |

**Root record `$BD58–$BD5B`**: IX at the root (`$7810`, `$7BF1`). It is a move entry (+0…+3) describing the last move played. The generator reads its flags (+3) for the castling check and en passant, and its to-square (+2) for en passant.

### 2.4 Direction tables `$7800–$780F` **[V]**

| Address | Values | Use |
|---|---|---|
| `$7800` | `0E 12 1F 21 F2 EE E1 DF` | Knight: +14, +18, +31, +33, −14, −18, −31, −33 |
| `$7808` | `0F 11 EF F1` | Diagonals: +15, +17, −17, −15. Bishop (4), and the first half of king/queen (8) |
| `$780C` | `01 FF 10 F0` | Orthogonals: +1, −1, +16, −16. Rook (4), and the second half of king/queen |

## 3. Variables touched by subsystem B

| Address | Width | Meaning | Written by | Read by |
|---|---|---|---|---|
| `$BCA9` | 8 | current ply | search, `$7BF1` | `$78CE`, `$8006`, `$80FD` |
| `$BCAB + 2(p−1)` | 16 | start of ply p's list | `$78CE` (next slot), UI `$653B` | `$78CE`, search |
| `$BD2D` | 8 | bit 0: side for the generator (0 = White, 1 = Black). Bits 1–4: game phase (§4.1) | `$7810`, the search toggles bit 0 per ply (`$7E0A`, …), UI | `$78CE`, eval, search |
| `$BD0D` | 8 signed | material balance change since `$7BF1` cleared it: **Black minus White**, in pawn units (captures ± value, promotions ∓8) | make, unmake | eval/search **[I]** |
| `$BD4C` | 8 | bit 7 = search abort (key pressed at `$78C9`, or **move list full** at `$7AB6`) | `$78BA`, `$7A9D` | search |
| `$BD2E` | 8 signed | 8 × clamp(Black material − White material, −14…+14) | `$7810` | `$7810` (next call), `$7FDA` |
| `$BD1E` | 8 signed | bias from the previous `$BD2E` and `$BCA0` (§4.1) | `$7810` | search/eval **[I]** |
| `$BD4A` | 8 | accumulates the B value returned by eval at `$7810` (wraps) | `$7810` | **[I]** |
| `$BD6D` | 8 | 1 if any pawn of either side is on the board, else 0 | `$7810`/`$789D` | eval **[I]** |
| `$BCA0` | 8 | read by `$7810` (previous root score? +`$80` bias) | search | `$7810` |
| `$BCBE` | 8 | non-zero: negate B and E in `$7810` (the computer plays Black **[I]**) | UI | `$7810` |
| `$BD49` | 8 | move number (phase: < 8 = opening) | UI | `$7810` |
| `$BCDF` | 8 | `$FF` = out of book (`$7AC0`) | book | book |
| `$BD58–$BD5B` | 4 | root move record (IX at the root) | UI/search | generator |

## 4. Pseudocode

All arithmetic is 8-bit and wraps unless marked 16. `sra` is an arithmetic shift right.

### 4.1 `PRESEARCH` (`$7810`) **[C]**

```
IX = $BD58
$BD2D ^= 1
(A0, B) = eval()                       // $8400: subsystem E
E = $BCA0 + $80
if $BCBE != 0: B = -B; E = -E
t = sra(sra($BD2E_old, 1) + sra(E, 1), 2)   // sra(x, 2) = two SRA steps
if t != 0: t += 1                      // also for negative t (e.g. -1 -> 0)
$BD1E = t
$BD4A += B
$BD6D = 0
W = MATERIAL($BE08); Bk = MATERIAL($BE88)  // each sets $BD6D=1 if it sees a pawn
d = Bk - W                              // 8-bit
if !(d < 14 unsigned or d >= $F2): d = (d bit7 ? $F2 : $0E)   // clamp to [-14, 14]
$BD2E = d * 8
phase = 0
if $BD49 >= 8:
    total = Bk + W
    phase = 2;  if total < 52: phase = 6;  if total < 40: phase = 14;  if total < 25: phase = 30
$BD2D = ((($BD2D) + 1) & 1) + phase     // restore bit 0, set bits 1-4, clear bits 5-7
return A0 (flags from OR A)
```

`MATERIAL(hl)`: sum the value nibbles of the 15 records at `hl`, `hl+8`, … whose square byte has bit 7 clear. If any value equals 1, set `$BD6D = 1`.

### 4.2 `GENMOVES` (`$78CE`) **[V]**

```
p = $BCA9
start = word[$BCA9 + 2p]; out = start + 4
side = $BD2D bit 0                      // 1 = Black
rec = side ? $BE80 : $BE00
enemy(c) = ((c XOR side<<7) & $80) != 0        // c != 0
pc(sq) = byte[$BD00 + (sq & $FF)]       // NO off-board test

K = rec[0]                              // even if its bit 7 is set (see 6.6)
if !(rec[1] & $10):                     // king not moved
    if !(IX.flags & $80):               // not in check
        if !(rec[$19] & $10) and !(rec[$18] & $80) and pc(K+1)==0 and pc(K+2)==0:
            add(K, K+2, $10)
        if !(rec[$11] & $10) and !(rec[$10] & $80) and pc(K-1)==0 and pc(K-2)==0 and pc(K-3)==0:
            add(K, K-2, $10)
step(K, DIAG4 + ORTH4)                  // $7808: +15,+17,-17,-15,+1,-1,+16,-16
if alive(rec[$08]): slide(Q, DIAG4 + ORTH4)
if alive(rec[$10]): slide(R, ORTH4)
if alive(rec[$18]): slide(R, ORTH4)
if alive(rec[$20]): slide(B, DIAG4)
if alive(rec[$28]): slide(B, DIAG4)
if alive(rec[$30]): step(N, KNIGHT8)    // $7800: +14,+18,+31,+33,-14,-18,-31,-33
if alive(rec[$38]): step(N, KNIGHT8)
C = side ? $F1 : $11
for slot in 8..15:
    fr = rec[8*slot]; if fr & $80: continue
    t = rec[8*slot+1]
    if t & $0E:                         // promoted
        if t & $80: slide(fr, DIAG4)
        elif t & $02: step(fr, KNIGHT8)
        elif t & $04: slide(fr, ORTH4)
        else: slide(fr, DIAG4 + ORTH4)
        continue
    for tt in (fr + C, fr + C - 2):     // capture right, then left (8-bit, unchecked)
        c = pc(tt); if c and enemy(c): add(fr, tt, $08)
    f = fr + C - 1                      // forward
    if pc(f) == 0:
        add(fr, f, 0)
        if ((fr + $20) & $40) == 0:     // home rank (and White rank 7, rejected next)
            t2 = f + C - 1
            if !(t2 & $80):             // sign: rejects past rank 8 for White
                if pc(t2) == 0:
                    add(fr, t2, 0)
                    for adj in (t2 - 1, t2 + 1):
                        c = pc(adj)
                        if c and enemy(c) and (byte[$BE00 + ((c - 3) & $FF)] & $0F) == 1:
                            last_added.flags = $20
            continue                    // no en passant from the home rank
    if IX.flags & $20 and !(IX.flags & $08):
        if IX.to + 1 == fr: add(fr, f - 1, $28)
        elif IX.to - 1 == fr: add(fr, f + 1, $28)

terminator: byte[out] = $FF
word[$BCA9 + 2(p+1)] = out
n_raw = ((out - start) >> 2) computed as (H bit0, L) >> 2, keeping only 9 bits of (out - start)
count = (n_raw - 1) & $FF               // == n only for n < 127
header = [$FF, count, 0, IX.flags & $81]
return E = count, HL = start + 3
```

- `step(fr, dirs)`: for each d, `t = (fr + d) & $FF`. If `t & $88`, skip. Empty → `add(fr, t, 0)`; enemy → `add(fr, t, $08)`.
- `slide(fr, dirs)`: for each d, step repeatedly: off-board → next direction; empty → add a quiet move and continue; enemy → add a capture, then stop; own piece → stop.
- `add(fr, to, fl)`: if the list pointer's high byte is `$BC` and its low byte is > `$80`, set `$BD4C |= $80` and do not write. Otherwise write `[$FF, fr, to, fl]` and advance by 4.
- **Promotion** is not represented in the generated move. A pawn move to the last rank is an ordinary move (flags 0 or `$08`), and make turns it into a queen. No under-promotions are generated.
- The en passant flag `$20` is set only when an enemy **pawn** (value nibble 1) is beside the landing square. A double push without one has flags 0.

### 4.3 `MAKEMOVE` (`$810F`) **[V]**

```
fr = IX.from; to = IX.to; pcode = board[fr]; cap = board[to]
push (fr, pcode)
board[fr] = 0; board[to] = pcode
R = rec(pcode); R.sq = to; old = R.type
if old & $0F == 0:                         // king
    R.type = KINGTYPE(old, to)             // ((old | $10) & $3F) + $40 * centralisation
    if IX.flags & $18 == 0: push (old, $80); return
    if IX.flags & $08: goto CAPTURE(marker $00)
    // castling
    R.type |= $20
    if to & 4: rfrom = to + 1; rto = to - 1    // g-file
    else:      rfrom = to - 2; rto = to + 1    // c-file
    rcode = board[rfrom]; board[rfrom] = 0
    board[rto] = (IX.score == $FF) ? (rcode & $84) : rcode   // king code as transit marker
    push (rfrom, rcode); rec(rcode).sq = rto; push (old, $40); return
elif old & $0F == 1:                       // pawn
    rr = relative rank of `to` (0-7, from the mover's side)
    if rr == 3: R.type = $11
    elif rr == 4: R.type = $31
    elif rr >= 5:
        IX.flags |= 1
        if rr == 5: R.type = $61
        elif rr == 6: R.type = $91
        else:                              // rr == 7: promotion
            IX.flags &= ~1; R.type = $19
            $BD0D += (white ? -8 : +8)
            if IX.flags & $08: goto CAPTURE(marker $04)
            push (old, $84); return
    if !(IX.flags & $08): push (old, $80); return
    if !(IX.flags & $20): goto CAPTURE(marker $00)
    // en passant
    csq = white ? to - 16 : to + 16; cap = board[csq]; board[csq] = 0
    goto CAPTURE(marker $01, square csq)
else:
    R.type |= $10
    if cap != 0: goto CAPTURE(marker $00)
    push (old, $80); return
CAPTURE(marker, sq = to):
    push (sq, cap); rec(cap).sq |= $80; push (old, marker)
    $BD0D += (cap is White ? +value : -value)
```

- **Captures** are decided by board content for R/Q/B/N, but by the flags (bit 3, or `$18` for the king) for pawns and kings.
- **Castling legality**: make performs no legality or attack test. When a castling move is made while its score byte is still `$FF` (that is, during root scoring `$7B96`), the rook's destination (the square the king passes) holds a second **king** code. This presumably lets the evaluation detect an attack on the transit square **[I]**. The square's record still points at the rook.

### 4.4 `UNMAKE` (`$821C`) **[V]**

```
(old, marker) = pop; X = pop
if marker has P/V (promotion): $BD0D -= promotion adjustment  // colour from X (see $826E)
if marker has S (quiet: $80/$84): board[to] = 0 (via the common restore)
elif marker has Z (castling): board[X.square] = X.code (rook back); board[rec(X).sq] = 0; rec(X).sq = X.square
elif marker has C (en passant): board[X.square] = X.code; un-capture rec(X); $BD0D -= its signed value; board[to] = 0
else (capture): un-capture rec(X); $BD0D -= signed value; board[to] = X.code
(fr, mover) = pop (or X, if quiet); board[fr] = mover; rec(mover).sq = fr; rec(mover).type = old
```

### 4.5 `KINGTYPE` (`$8200`; entry `$8203` used by the set-up code `$660A`) **[C]**

`type = (old | $10) & $3F`. Then for k = 1, 2, 3: if both `sq + $11k` and `sq − $11k` are on the board, `type += $40`, else stop. The result is the moved bit, any castled bit, and centralisation in bits 6–7.

## 5. Search helpers in this range (for subsystem C)

These are in `40-makemove.ctl` because of the range split, but they belong to the search.

- **`$805F` pruning loop** (search file) jumps through IY to `$80A2`, `$80A7` or `$80BB` when a move's score is below the threshold C.
  - **`$80A2`** is **code** (`ADD A,$10 / JP M,$80AB`), but it is still marked `b` in `30-search.ctl`, so subsystem C should fix that.
  - Pruning sets the score byte to 0 unless `flags AND $C9` is non-zero (check, bit 6, capture, pawn-to-6th/7th). The variants are described in the ctl. One correction: in `$805F`, phase bit 4 implies bit 3, so `$80A7` overrides `$80BB` whenever bit 4 is set. `$80BB` is used only for ply < 3.
- **`$80C4`** is an even-ply cut-off at the depth limit, using `$BD09`, C and the table `$BC9E + ply`. It unmakes and returns via `$7E79`.
- **`$80ED`** selects the first entry with the highest score byte, using `$8015`. The scan stops at the first `$FF`, so unscored moves stop it. The search sets the selected move's score to 0 and makes it via `$80FA`. At ply 1 it stores the root move (`$7E06`); otherwise it sets bit 7 of the byte at `$BC83 + 2(ply−1)`.

## 6. Capacities and crash/illegal-move risks

1. **Header count wrong for n ≥ 127 moves** (`$79AF–$79B8`) **[V]**. count = `((n+1) mod 128) − 1` (8-bit): n = 127 → 255, n = 128 → 0, n = 218 → 90. Callers loop over the header count. With 255 they walk past the terminator into stale entries, which can produce illegal moves, a hang or memory corruption (**class A/B**). With a small count, moves are silently ignored (class C). This needs ≥ 127 pseudo-legal moves, which arbitrary FEN input can easily provide (several queens).
2. **Ply table** (`$BCA9 + 2p`) **[C]**. The generator at ply p writes `$BCAB + 2p`. At p = 10 it overwrites `$BCBD`/`$BCBE` (level, side flag); p ≤ 9 is safe. Subsystem C must state the maximum ply the search can reach. There are also other per-ply tables (`$BCA0 + p`, `$BC9E + p`, `$BC83 + 2p`).
3. **Move-list area full** **[C]**. `$7A9D` stops writing when the pointer passes `$BC80` and sets the search-abort flag `$BD4C` bit 7, so the search stops as if a key had been pressed. This is a graceful guard (not a crash). One small flaw: if the double push was not written, `$79FC` writes the `$20` flag into the previous entry. With 544 entries in total, it is unlikely to be reached at Spectrum depths, but it could be reached in deep UCI searches, causing early termination.
4. **Stack** **[V]**. `SP = $BDF4` in the main loop. Make pushes 4 bytes (quiet) or 6 bytes (capture, en passant, castling) per ply. The lowest SP observed was `$BDCA` (ply 5). Below `$BD80` the stack would overwrite `$BD7x` = **board rank 8**. Per-ply stack use in the search should be confirmed by subsystem C.
5. **Pawn captures read off-board cells unchecked** **[V]**. These are `$BDx8` (White h-file / Black h-file targets) and `$BDxF` (a-file targets), plus the double-push neighbour tests. If one ever held a non-zero value with the enemy colour bit, the generator would emit a capture to an off-board square (an illegal move). `$BD58` is the only such cell with a name, and it was always 0 during 600 s of demo play. A port must reproduce the read, which is harmless while these bytes are 0, or prove they stay 0.
6. **Captured king** **[C]**. The king's square is not tested for bit 7. If the king has been captured (pseudo-legal search), `B = sq | $80`, and some step offsets wrap back onto the board (e.g. `$84 + $EF = $73`), giving junk moves. Castling could also be generated from such a square. This is relevant only if the search generates after a king capture.
7. **Castling** **[V]**. The generator does not test attacked squares (only the check flag, IX+3 bit 7) and does not check that the rook is on its corner (only "present and unmoved"). A loader must set the moved bits so that unmoved rooks are on their corners.

## 7. Corrections to `00-overview.md`

- **`$BD2D` bit 0** selects the side whose moves `$78CE` generates: **0 = White, 1 = Black** **[V]**. During play with White to move, the stored value is 1 at the main-loop level. The search toggles bit 0 per ply before generating, so ply-1 generation for White happens with bit 0 = 0. The first generation calls of a computer move (main loop at `$61C8`/`$6153` and `$7BF1`) produce the opponent's list **[V]**; subsystems A/C should explain why. Bits 1–4 = game phase, from `$7810`.
- **Direction tables**: `$7800` = knight, `$7808` = diagonals (bishop) and the first half of king/queen, `$780C` = orthogonals (rook). The overview had knight and king swapped.
- **`$7AAF`** is the move-list-full check (it sets the abort flag), not king-capture detection.
- **Flags**: `$10` = castling, `$20` = double push beside an enemy pawn, `$28` = en passant, bit 0 = pawn to 6th/7th. Bits 1, 2, 6 and 7 are set by the evaluation (bit 7 = check).
- **Type byte**: king bit 5 = castled, king bits 6–7 = centralisation, pawn high nibble = advancement, promoted = `$19`.
- **`$79E0`** and **`$80A2`** are code, not data.
- **`$BD0D`**: material balance change, Black − White.

## 7a. Zig port verification (Phase 3, units 3.3/3.4)

`src/movegen.zig` and `src/board.zig` (`zig build test-board`):
- Root lists generated from 8,768 captured states (`search`, `edge`, `book` goldens) are identical to the original's: entries, order, flags, header. 35 have ≥ 127 moves and differ only in the header count, which the port stores correctly (DEV-001).
- 17,694 makes from `tests/golden/board.jsonl.gz` (made by `tools/oracle/golden_board.py` with the original `$810F`/`$821C`) are identical: board, piece records, entry flags, `$BD0D`, and the pushed frames. They cover every marker: quiet, capture, en passant, castling (score `$FF` and 0), quiet and capture promotions. Unmake restores the original's state in every case.
- 285,188 make/unmake round trips restore the position exactly.
- List-full detail: the original still writes an entry starting at `$BC80`. The port compares list offsets, so this matches in both modes.

## 8. Open questions

1. Who sets the root record `$BD58–$BD5B` after a game move, and its flags bit 7 (in check)? (Subsystem A, `$6560`/`$6332`; `RES 7,(IX+3)` at `$6332`.)
2. Is the king-code-on-the-transit-square trick (`$81EA`) what makes castling through an attacked square illegal? Which code detects it (eval `$8400`, or root scoring `$7B96`)? Inside the search, selected moves have score 0 before make, so the trick is off there. (Subsystems C/E.)
3. What value does the evaluation return for a position where the side to move can capture the king? How is "king capturable" treated in `$7B96`? (Subsystem E.)
4. Exact meaning of flags bits 1, 2 and 6, and of record bytes +2…+7 (subsystem E).
5. Slot assignment in the original's set-up mode (`$660A` and nearby, subsystem A). It is needed so a FEN loader reproduces move order.
6. `$BCA0` and `$BD4A`: the producer and consumer of these values (subsystems C/E).
