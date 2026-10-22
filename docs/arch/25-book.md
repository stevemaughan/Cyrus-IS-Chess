# Opening book (code `$7AC7–$7B95`, data `$9000–$9BCC`)

Facts are tagged:
- **[V]** verified by code reading **and** simulator experiment;
- **[C]** read from the code only;
- **[I]** inferred.

Generated listing: `docs/arch/book-tree.txt`, produced by `tools/scripts/book_dump.py`.

## 1. Summary

- The book is a **pre-order tree of 2,685 nine-bit entries**, bit-packed MSB-first at `$9000–$9BCC` (24,165 bits) **[V]**.
- Each entry names a move by its **index in the pseudo-legal move list produced by the move generator `$78CE`** for that position (move = `$B404 + 4*index`) **[V]**. The book therefore depends on the **exact move-generation order**, including castling being generated first and castling being suppressed when the side to move is in check.
- Each entry has two structure bits, *leaf* (no continuation stored) and *more siblings follow*. A ninth leading bit, **M**, steers the random choice **[V]**.
- The probe replays the game's moves from the record at `$C058`, then picks one of the stored replies with a crude random generator built on the Z80 `R` register **[V]**.
- Book moves are played **without any legality check**. One stored reply is illegal and the original really plays it (§8.1) **[V]**.
- Contents: White's first moves are 1.e4, 1.d4, 1.c4, 1.Nf3, and also 1.b3 and 1.f4 (M; recognised but never chosen). There are 396 leaves, 123 entries with M set, and a maximum depth of 31 plies **[V]**.
- `$9BCD–$9FFF` is never read: 52 bytes of stale data, then a power-on RAM fill pattern (`FF FF 01 01` …) **[V]**.

## 2. Routines

| Address | Label | Role |
|---|---|---|
| `$7AC7` | `BOOK_PROBE` | Probe. Returns Z with `($BD29)` = chosen move address, or NZ (no book move) |
| `$7AC0` | (inside the `$7A9D` block, in `20-movegen.ctl`) | Book-exit tail: `$BCDF := $FF`, return NZ. **Needs a label/comment in `20-movegen.ctl`** (suggested `BOOK_OUT`) |
| `$7B4C` | `BOOK_SKIP` | Skip an entry's subtree; return the next sibling's entry |
| `$7B57` | `BOOK_READ` | Read an entry and update the subtree counter DE |
| `$7B64` | `BOOK_BITS` | Fetch 9-bit entry n: A = bits 0–7, CF = bit 8 |
| `$7B89` | `BOOK_RANDOM` | `$BCCE := (R xor $BCCE) >> 1`; B = result (0–127) |

The only caller is the search driver at `$7C1E` (`$7BF1`) **[C]**.

## 3. Data format **[V]**

Entry *n* (0 ≤ n ≤ 2684) occupies stream bits `9n … 9n+8`. The stream is MSB-first from `$9000`: stream bit *k* is bit `7 − (k mod 8)` of byte `$9000 + k div 8`. Equivalently, the entry starts at bit `n mod 8` (counting from the MSB) of byte `$9000 + n + n div 8`.

| Entry bit | Name | Meaning |
|---|---|---|
| 8 (first in stream) | **M** | Choice modifier, see §5 |
| 7 | **L** | leaf: no replies stored after this move |
| 6 | **S** | another sibling follows this entry's subtree |
| 5–0 | index | position of the move in `$78CE`'s list for this position (0 = first generated) |

**Tree layout:** pre-order. A non-leaf entry is immediately followed by the sibling list of replies to it (that list's subtrees included). After that comes its next sibling, if S = 1. Entry 0 begins the root list (White's first move).

Worked example: the bytes `26 92 69 C4` give entry 0 = `0 0 1 001101` = `$04D` (M0 L0 S1, index 13 = e2-e4). Entry 1 = `0 0 1 001001` (1…c7-c5). Entry 2 = `1 0 1 001110` (M = 1, index 14 = 2.Ng1-f3).

### `BOOK_BITS` exact behaviour (`$7B64`) **[V]**

```
off  = n + (n >> 3)                    ; 16-bit, n ≤ 2684 so off ≤ 3020
A    = mem[$9000+off]; C = mem[$9000+off+1]
CF   = 0                               ; from the preceding AND/ADD
repeat (n & 7) + 1 times:  RL C ; RLA  ; shift the 16-bit pair A:C left through carry
return A (= entry bits 7..0), CF (= entry bit 8)
```

The highest byte ever read is `$9BCC`.

## 4. Probe algorithm (`$7AC7`) **[V]**

The algorithm below was validated against the original in 512 of 512 simulated probes, using captured `R` values (§5). Widths: `bcdf`, `c` and `a` are u8; `hl` is u16 (entry number); `de` is s16.

```
probe():
  if bcdf != 0:            return NO_BOOK           ; $BCDF: book abandoned this game
  if mem[$C006] != 1:      return NO_BOOK           ; game did not start from the initial position
  b = random()                                       ; result unused (but advances $BCCE)
  hl = 0
  loop:                                              ; $7AD7 (hl pre-incremented from -1)
    i = bcdf; bcdf += 1
    if i == (plycount & $FF): goto choose            ; plycount = $C001 (u16) — LOW BYTE ONLY
    c = mem[$C058 + i] & $7F                         ; game move index (bit 7 = 'gave check' flag)
    a = entry(hl).bits0_7
    while (a & $BF) != c:                            ; RES 6: the leaf bit stays, so leaves never match
        if not (a & $40): bcdf = $FF; return NO_BOOK  ; $7AC0
        hl, a = skip_subtree(hl)                     ; $7B4C
    hl += 1                                          ; first child of the matched move
choose:                                              ; $7B05
  b = random()
  a, m = entry(hl); c = a
  if a & $40 and not ((2 | m) & b):                  ; only move → take; else first-move test
      loop:                                          ; $7B16
          saved = hl
          b = random()
          hl, a, m = skip_subtree(hl)                ; next sibling's entry and its M bit
          if m: hl = saved; c = entry(hl).bits0_7; break   ; M on a later sibling: take the previous one
          c = a
          if not (a & $40): break                    ; last sibling: take it
          if not (b & 1): break                      ; RR B: CF = bit 0; NC → take this one
  index = c & $3F
  ($BD29) = $B404 + 4*index                          ; chosen move (no bounds or legality check)
  if not (c & $80): bcdf = 0                         ; non-leaf: stay in book. Leaf: bcdf stays non-zero
  return BOOK_MOVE (Z)

skip_subtree(hl):                                    ; $7B4C, entry hl has S=1
  de = -1
  do: a = entry(hl); de -= a>>7 & 1; de += a>>6 & 1; hl += 1
  while de >= 0
  a, m = entry(hl)                                   ; next sibling (DE adjusted again, unused)
  return hl, a, m
```

Notes:
- `entry(hl).bits0_7` is A from `$7B57`, which also adjusts DE. Outside `$7B4C`, DE is a don't-care.
- The matching compares `entry & $BF` (bit 7 kept) with `index & $7F`. A game move whose index is ≥ 64 can never match, which is correct because book indices are 6-bit. A game move that matches only a **leaf** entry does not match. The walk then carries on through the siblings and leaves the book.
- `$BCDF` therefore ends up as:
  - 0 after a non-leaf book move;
  - (plies matched + 1) after choosing a leaf;
  - `$FF` after the game leaves the book.

## 5. Random choice **[V]**

`random()` (`$7B89`):

```
acc = ($BCCE xor R) >> 1   ; R is the Z80 refresh register (7-bit counter; bit 7 as last loaded, normally 0)
$BCCE = acc
return acc                  ; 0–127
```

The XOR clears carry, so RRA shifts in 0.

Selection rule, for the sibling list at the current position (siblings e0, e1, …):
- **e0:** if it is the only entry, take it. Otherwise take it if random bit 1 is set, or (when M(e0) = 1) bit 0. That is probability ½, or ¾ when M is set.
- **ek, k ≥ 1:** reached only when the previous candidate was declined. If **M(ek) = 1**, take e(k−1) instead; ek and all later siblings are never chosen. Otherwise, if ek is the last sibling, take it. Otherwise take it if bit 0 of a fresh random byte is 0.

So M on a non-first sibling marks the start of moves the book only *recognises* (when the opponent plays them). 110 of the 123 M bits are on later siblings; 13 are on first entries.

**Entropy sources for `$BCCE` and how they correlate:**
- `$675A` increments `$BCCE` once per loop pass while waiting for a key, so the human's thinking time feeds in.
- The main loop mixes `R` in at `$60EB`.
- The evaluation increments `$BCCE` at `$8807` on every call. It also uses `$BCCE` as an evaluation noise term (0–3 on move 1, 0–1 afterwards). That belongs to the evaluation subsystem, but it means root scoring (`$7B96`, which runs just before the probe) advances the accumulator.
- `R` advances deterministically with the instruction count, so successive random bytes within one probe are strongly correlated. In a simulator with identical timing, 256 seeds of `$BCCE` at the start position gave e4 128, c4 64, Nf3 64 and **never d4**. After 1.e4 the replies were c5 128, e6 48, e5 32, c6 24, Nf6 12, d5 6 and Nc6 6. On real hardware `R` at the first call varies with key timing, so the d4 branch is reachable.

**Port implication:** `R` cannot be reproduced. Model `R` with the seeded PRNG (UCI `Seed`), and keep the `$BCCE` accumulator and its update rule exactly, because evaluation shares it. The **candidate set and selection structure** must be exact.

## 6. Variables

| Address | Width | Meaning | Written by | Read by |
|---|---|---|---|---|
| `$BCDF` | u8 | Book state (§4): 0 = probe; non-zero = do not probe | `$60B1` (0: new game, and the restart-and-replay used by take-back `$68A0` and next-best `$69B3`), `$7AC0`, `$7AE0`, `$7B47` | `$7AC7` |
| `$C006` | u8 | **Move number of the game's starting position**: 1 for a new game (`$6538`). `$6F77` copies `$BD49` into it when set-up mode exits (numbering then starts at 10). The book is used only when it is 1 | `$606D`, `$6538`, `$6F80` | `$7ACC`, `$607F`, `$68B5` |
| `$C001` | u16 | plies played (game record length); **only the low byte is compared** | UI | `$7AD8` |
| `$C058+i` | u8 | game record: list index of ply i's move, bit 7 = the move gave check (`$6360`). `$FF` terminates | UI | `$7AEF` |
| `$BD29` | u16 | out: address of the chosen root-list entry. The search also uses it for its best move | `$7B3E`; search `$7C4C` | `$61C1` (plays it via `$6323`), `$7C38` |
| `$BCCE` | u8 | random accumulator (§5) | `$6762`, `$60F5`, `$7B91`, `$880A` | `$7B8C`, `$60F4`, `$880F` |
| `$B404` | — | root move list, 4 bytes per move. The header at `$B400`: +0 `$FF`, +1 count | `$78CE` | `$7B38` |
| `$BCDD` | u8 | Next-best flag (`$69C3`; cleared at `$6195`). When set, the caller skips the book | UI | `$7C18` |

## 7. When the book is consulted **[V]**

- Search driver `$7BF1`: generate root moves (`$78CE`), score them (`$7B96`), then probe the book unless `$BCDD` (Next-best) is set **[C]**.
  - **Book move found:** poll the keyboard (`$6734`). With no key, return Z and the caller plays `($BD29)`. If a key is pressed, `JP $7562` **[C]**.
  - **Otherwise:** normal search.
- Problem levels P1–P3 do not use the book. At the start position, Level P1 + M gives no move and goes to CHANGE POSITION **[V]**. The mechanism is in the level/search code.
- Games from set-up positions never use the book (`$C006 ≠ 1`) **[C]**.
- Take-back and next-best restart the game from its initial position and replay the record (`$68A0` → `$60A4` → `$60A7`). That resets `$BCDF` to 0, so the book becomes available again if the shortened game is still in book **[C]**.
- The probe needs the game record (`$C001`, `$C058…`) to describe the current game. It is consulted for the computer's move at every level 1–8 and in demo mode.

## 8. Bugs, quirks and crash risks

### 8.1 Illegal book move — class B **[V]**

Line: 1.e4 e5 2.Nf3 Nf6 3.Nxe5 d6 4.Nf3 Nxe4 5.d4 d5 **6.Bb5+** (index 14), and the only stored reply is **6…Be7** (index 14), which leaves the king in check.

The rest of the line, 7.O-O Nc3 8.Qd3 Bd6, shows the indices are shifted: the intended line was probably 6.Bd3 Be7 7.O-O Nc6 …. In the simulator, with Cyrus playing Black after 6.Bb5+, it **plays 6…F8-E7** immediately; the screen shows "6 F1-B5+ / …F8-E7".

To reproduce:
1. Replay the 11 plies with `book_dump.Machine.play_index`.
2. Press M.
3. Read `$C058+11`, which is `$0E`.

It is the only illegal move in the book (checked with python-chess over all 2,685 nodes). No sibling list contains a duplicate move.

**Port:** check the chosen book move for legality. If it is illegal, treat the probe as "no book move" (`$BCDF := $FF`) and search normally. Log this as a DEVIATIONS entry.

White's own 6.Bb5+ in that line is legal and must be preserved (class C).

### 8.2 Ply count compared by low byte — class B/A **[C]**

`$7AD8` compares the matched-ply counter with `$C001 & $FF`. Normally harmless, because `$BCDF` is non-zero once the game has left the book.

But `$BCDF` is reset by take-back/next-best (`$60A7`). With ≥ 256 plies, the probe then matches only the first `plies mod 256` moves of the game's opening, and picks a stored reply **for a different position**. Its index selects an arbitrary entry of the current pseudo-legal list. That entry may be illegal, or lie past the list's end (stale data), which could move a piece from an arbitrary square: memory corruption.

**Port:** a stateless UCI port that probes with the equivalent of `$BCDF = 0` on every `go` would hit this whenever a 256+ ply game opened with book moves. Compare the full ply count. This is equivalent to the original in every case where the original works. Log it as class A/B.

### 8.3 Other risks
- No reads beyond `$9BCC` and no overflow of DE, the entry number or `$BCDF` are possible for any valid walk **[V]**.
- The chosen index is not checked against the list length. That only matters in §8.2.
- The game record byte uses bit 7 as the check flag, so a move index ≥ 128 (lists of > 128 pseudo-legal moves) would corrupt the record. That's a UI/record issue, not the book's. A book match is never affected, because the match masks with `$7F`.

## 9. Interaction with move generation **[V]**

- Indices refer to the raw `$78CE` list: castling (`$7A61`, generated before the king's ordinary moves), then K, Q, R, R, B, B, N, N, then pawns, in piece-list order.
  - **Castling is not generated when the previous move gave check.** `$7A61` tests bit 7 of `$BD5B`, which the replay path sets from the game record's bit 7.
  - Mis-modelling this shifts later indices. Before this was handled in `book_dump.py`, one line failed with "index 36 of 30".
- So the port's move generator must reproduce `$78CE`'s order exactly, including its check-dependent castling rule. `book_dump.py` is a ready-made test: replace its list source with the Zig generator's lists, and all 2,685 nodes must resolve to the same moves.
- `book_dump.py` checks that the list the program regenerates during replay (`$66BE`) has the same from/to order as the list at the following YOUR MOVE? prompt. 0 mismatches. Root scoring later adds extra bits to byte +3 (e.g. `$04`, `$40`, and bit 7 = gives check).

## 10. Corrections to `00-overview.md` **[V]**

- **Colours and orientation are the other way round.** Codes with bit 7 set are **White**, and row 0 of the 0x88 board is **rank 8**: square = `(8−rank)*16 + file`, a8 = `$00`, h8 = `$07`, a1 = `$70`, e1 = `$74`.
  - Evidence: after Cyrus played 1 G1-F3, `$BD76` (g1) moved to `$BD55` (f3), code `$BC`.
  - So `$BE00–$BE7F` holds **Black's** pieces and `$BE80–$BEFF` **White's**. Pawn record +6 is `$C0` for Black and `$80` for White.
- `$BD2D` bit 0 = 1 means **White to move** (start position).
- `$C058+i` bit 7 = "this move gave check", not a promotion flag. `$C006` is the starting move number (§6), not a book flag.

## 11. Verification performed

- `BOOK_BITS` reimplemented from the stream definition and checked against an instruction-level model for entries 0–2999.
- `book_dump.py --check-replay`: 2,685 nodes, 0 bad indices, 0 replay/idle list mismatches.
- Python model of `$7AC7` (§4/§5) matched the original's choice in 512 of 512 probes: 256 `$BCCE` seeds each at the start position and after 1.e4, with the captured `LD A,R` values.
- Chosen moves were always within the predicted candidate sets: never 1.d4 in the fixed-timing run, never 1.b3/1.f4 as White, never 1…g6 or 1…d6.
- Legality of every book node checked with python-chess (scratch only); see §8.1.
- Problem level P1 at the start position does not use the book.

## 12. Open questions

1. Why the first-entry M bit raises the probability rather than barring the move. This is presumably intentional author weighting; it is documented as behaviour.
2. The port has to decide how to stand in for `R` and the key-wait increments of `$BCCE`. This is coordinated with the evaluation noise term at `$8807` (evaluation subsystem).
