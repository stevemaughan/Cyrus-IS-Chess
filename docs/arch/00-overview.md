# Cyrus IS Chess (48K): architecture overview

This is the entry point to the subsystem documents. It summarises the shared data structures; details, pseudocode and evidence are in:

| Document | Range | Subject |
|---|---|---|
| [10-main-ui.md](10-main-ui.md) | `$6000–$780F` | Main loop, levels, set-up mode and its legality check, game record, draws, next-best, UI |
| [20-board-movegen.md](20-board-movegen.md) | `$7810–$7AC6`, `$80A7–$83FF` | Board, piece records, pre-search set-up, move generator, make/unmake |
| [25-book.md](25-book.md) | `$7AC7–$7B95`, `$9000–$9BCC` | Opening book format and random choice ([book-tree.txt](book-tree.txt) is the decoded tree) |
| [30-search.md](30-search.md) | `$7B96–$80A6` | Search, levels, termination, mate/draw scoring |
| [50-eval.md](50-eval.md) | `$8400–$8F2E` | Evaluation, including the static exchange evaluation (SEE) and attack maps |

Tags in all documents: **[V]** verified (code read and confirmed in the simulator), **[I]** inferred, **[C]** confirmed by code reading only.

## Tooling

| Tool | Purpose |
|---|---|
| `tools/scripts/cyrus_sim.py` | Run a snapshot in SkoolKit's Z80 simulator with scripted keys. It can write an execution map, a profile, a screenshot and a snapshot |
| `tools/scripts/memdump.py` | Hex-dump memory from a snapshot |
| `tools/scripts/mkctl.py` | Recursive-descent control-file generator (used once to create `disasm/ctl/*.ctl`, which are now hand-maintained) |
| `tools/scripts/build-disasm.ps1` | `disasm/ctl/*.ctl` → `disasm/cyrus.skool`, `disasm/cyrus.asm` |
| `tools/scripts/book_dump.py` | Decode the opening book by replaying it through the original's move generator |
| `tools/research/*/` | Verified Python reference models (move generator, evaluation, search) and the probes used to check them against the original. See `tools/research/README.md` |

Reference snapshots: `reference/snapshots/cyrus48-entry-6000.z80` (entry point) and `cyrus48-idle-level1.z80` (start position, Level 1, waiting for a key).

## Memory map

| Range | Contents |
|---|---|
| `$5B00–$5BFF` | ZX Printer line buffer |
| `$6000–$767B` | Main loop, UI, set-up mode, game record, printer, tape, messages, piece graphics (`$75CC`) |
| `$767C–$77FF` | Unused (zeros) |
| `$7800–$780F` | Direction tables: `$7800` knight (+14 +18 +31 +33 −14 −18 −31 −33); `$7808` diagonals (+15 +17 −17 −15); `$780C` orthogonals (+1 −1 +16 −16). Bishops use `$7808–$780B`, rooks `$780C–$780F`, king and queen all eight from `$7808` |
| `$7810–$7AC6` | Pre-search set-up `$7810`, move generator `$78CE` |
| `$7AC7–$7B95` | Book probe |
| `$7B96–$80A6` | Root/interior static scoring, search state machine, pruning |
| `$80A7–$828B` | Pruning variants, make `$810F`, unmake `$821C` |
| `$828C–$83FF`, `$8F2F–$8FFF` | Zero padding |
| `$8400–$8F2E` | Evaluation |
| `$9000–$9BCC` | Opening book, 2,685 nine-bit entries. `$9BCD–$9FFF` is never read |
| `$B400–$BC7F` | Move lists: a 4-byte header per ply, then 4-byte entries. The generator aborts the search instead of passing `$BC80` |
| `$BC83–$BCFF` | Search tables and global variables |
| `$BD00–$BD7F` | 0x88 board. The off-board columns (`$BDx8–$BDxF`) hold variables |
| `$BD79–$BDF5` | Pin list, more variables, machine stack (`SP = $BDF4` in the main loop) |
| `$BE00–$BEFF` | Piece records: **Black `$BE00–$BE7F`, White `$BE80–$BEFF`** |
| `$BF00…` | Next-best root exclusion list: (from, to) pairs, `$FF`-terminated |
| `$C000–…` | Game record: `$C001` ply count, `$C005–$C046` start position, `$C047–$C057` promotions, `$C058…` one byte per ply |

## Board and pieces [V]

- **Square** = `(8 − rank)·16 + file`, so **a8 = `$00`, h8 = `$07`, a1 = `$70`, e1 = `$74`**. A square is off-board when `sq & $88 ≠ 0`.
- **`$BD00 + sq`** holds 0 if the square is empty, otherwise a **piece code**:
  - bit 7 = **White**;
  - bit 2 is always set;
  - `code & $FB` (bit 2 cleared, colour kept) is the record offset in page `$BE`.
- **Piece records**, 8 bytes each, slot order K, Q, R, R, B, B, N, N, then pawns a–h. Slot offsets are `$00 $08 $10 $18 $20 $28 $30 $38 $40–$78`.

  | Byte | Meaning |
  |---|---|
  | +0 | square; bit 7 = captured/absent |
  | +1 | type byte. Low nibble = value (K0 Q9 R5 B3 N3 P1); bit 4 = moved; bishop bit 7; king bit 5 = castled; king bits 6–7 = rings from the edge; pawn high nibble = advancement code; an engine promotion becomes `$19` in the pawn slot |
  | +2…+5 | evaluation attack counters (0 at rest, except in king records) |
  | +6 | line mask: bit 0 K, 1 Q, 2 diagonal, 3 orthogonal, 6–7 pawn (`$C0` Black / `$80` White). Promoted pawns keep the pawn mask |
  | +7 | unused / stale |
- **Slot assignment is part of the position.** The generation order is the slot order. The set-up code assigns slots in a fixed scan order, and promoted pieces stay in their pawn slot.

## Move lists [V]

- Each ply's list has a header `[$FF, count, killer-eval / taken-counter, flags]`, followed by entries `[score, from, to, flags]`.
- **Score:** `$FF` = not yet scored; 0 = taken, pruned or illegal; otherwise the static evaluation.
- **Entry flags:**

  | Bit | Meaning | Set by |
  |---|---|---|
  | 0 | pawn to 6th/7th | make |
  | 1 | mover left material en prise | eval |
  | 2 | moved piece en prise | eval |
  | 3 | capture | movegen |
  | 4 (`$10`) | castling | movegen |
  | 5 (`$20`) | double push beside an enemy pawn | movegen |
  | `$28` | en passant | movegen |
  | 6 | threat | eval |
  | 7 | gives check | eval |
- **Header flags:**
  - bit 7: side to move in check;
  - bit 6: killer tried;
  - bit 5: moves statically scored;
  - bit 0: copied from the move that led here.
- **Slot table:** `slot(q)` = word at `$BCA9 + 2q`. `$BCA9` is the current ply (root = 1); `slot(1) = $B400`.
- **Header count bug:** the count byte is wrong when a list has 127 moves or more (see DEVIATIONS).

## Key variables [V]

| Address | Meaning |
|---|---|
| `$BCA0` | Root value of the last search (`$80` = equal; ≥ `$FE` = mate found). Persists between moves and games; negated when sides swap |
| `$BCA9` / `$BCAA` | Current ply / full-width depth D |
| `$BCBD` | Search level 0–7 (Level n → n−1; P1/P2/P3 → 0/3/7) |
| `$BCBE` | Side Cyrus plays (0 = White) |
| `$BCC2` | Players: 0 HvH, 1 HvC, 2 CvH, 3 CvC (demo) |
| `$BCCD` | Displayed level 0–10 (Level 1–8, P1–P3) |
| `$BCCE` | Random byte. Incremented by every evaluation (its low bit is added as noise); mixed with `R` in the main loop and the book; incremented while waiting for keys |
| `$BCDD` | Next-best in progress (skip book; keep the exclusion list) |
| `$BCDF` | Book state (0 = following the book, `$FF` = out of book) |
| `$BD0A` | 50-move ply counter |
| `$BD0D` | Material change since the search root (Black − White) |
| `$BD29` | Pointer to the move chosen by search/book |
| `$BD2D` | Bit 0 = side to move (**1 = White**); bits 1–4 = phase (move ≥ 8; total material < 52 / 40 / 25) |
| `$BD49` | Move number (1 at the start, **10 after set-up**) |
| `$BD4C` | Bit 7 = abort (key pressed or move list full); bit 6 = computer to move |
| `$BD58–$BD5B` | Last game move record (passed as IX to the root generator: en passant, check) |
| `$BD5E` | Consecutive-reversal counter (draw at 6; read by the root search from 2) |
| `$C006` | Start move number: 1 = standard start (book allowed); 10 = set-up |

## Calling conventions with inline data [V]

| Routine | Inline data after the `CALL` |
|---|---|
| `$6FB0` | beep: 2 bytes |
| `$6FDD` | set print position: 2 bytes |
| `$7200` | 4 glyph bytes |
| `$7415` | position (2 bytes) + bit-7-terminated string |
| `$73F7`, `$73FE`, `$7405`, `$740E`, `$741A`, `$741C` | bit-7-terminated string |

## Search in one paragraph [V]

The search is a fixed-depth, fail-hard alpha-beta, written as a state machine over plies. It has no clock and no iterative deepening; the level sets the depth D (1–4) plus switches for forward pruning and threat extensions, and Levels 6–8 run a Level-2 pre-pass. Every interior node statically scores all its moves with make, eval and unmake. It then searches the killer move, the static best, and the rest in descending order. Beyond D a selective layer evaluates each move and extends checks and threats (to at most ply 7). Scores are single unsigned bytes centred on `$80`. The keyboard is polled at every node; a key sets the abort flag, and the search unwinds and plays the best completed root move.
