# Subsystem A — main loop, UI and game management ($6000–$780F)

Annotated control file: `disasm/ctl/10-main-ui.ctl`. [V] = verified (code read and/or observed in the simulator); [I] = inferred.

## 1. Headline findings

1. **There is no clock.** [V] No code reads FRAMES ($5C78) or any timer. Interrupts are enabled only inside the key-wait routine `WaitKey` ($675A); during thinking they are disabled. A level is purely a *search-size* setting (`$BCBD`), so the manual's per-level times are just observed averages on a 3.5 MHz Z80. Thinking stops only when the search finishes or a key is pressed.
2. **Keyboard poll points while thinking** [V]: `PollKeyboard` ($6734, any key on any half-row) is called
   - at every search node via `$78BA` (first instruction of `$7D43`), but only until the abort flag `$BD4C` bit 7 is set;
   - once after a book move is found (`$7C23`) — a key then only cancels demo mode.
   On a key press `$78BA` sets `$BD4C` bit 7 (abort) and calls `SetPlayers` ($7562), which also ends CYRUS v CYRUS. The main loop then plays the move left at `($BD29)`.
3. **Levels** [V, confirmed in the simulator]: L cycles the level index `$BCCD` through 0–10 = Level 1…8, P1, P2, P3. The search level `$BCBD` = `$BCCD` for Levels 1–8 (0–7); **P1 → 0, P2 → 3, P3 → 7**. The default is Level 2 (`$BCCD = $BCBD = 1`). The main loop uses `$BCCD ≥ 8` to mean "problem mode". Everything else about levels is in the search (`$7C44`–`$7CB7`): for example `$BCBD ≥ 5` sets `$BD6E` (a second search pass), `$BCAA` = 1,2,2,2,3,4,4,4 for `$BCBD` 0–7 [I, from a quick read of `$7C71`], `$BD09`/`$BDF6` are derived from `$BCBD`, and so on. That analysis belongs to subsystem C.
4. **Set-up legality** (on exit with E, `$6ECC`) [V]. A position is rejected (`ILLEGAL`, back to the set-up menu) if any of these hold:
   - a newly placed pawn is on rank 1 or rank 8;
   - a colour has more pieces of a type than its slots allow. The slots are K 1, Q 1, R 2, B 2, N 2 and P 8. Surplus Q/R/B/N take free *pawn* slots, so the limit is "8 pawns + extra pieces ≤ 8", and a second king is always illegal;
   - either king is missing;
   - **the side not to move is in check**. This is detected by `$7810` → `$8400` returning 0 with the sides flipped [I: the mechanism is in subsystems B/E].

   Nothing else is checked: no check on bishop square colours, the pawn count per file, impossible double checks, and so on.
5. **Board orientation and colours — correction to 00-overview** [V]. Internal 0x88 row 0 is **rank 8**; row 7 is rank 1 (g1 = `$76`, f3 = `$55`, `square = (8 − rank)·16 + file`). **White** pieces have piece-code bit 7 **set** and use the piece list at **`$BE80`**; Black uses `$BE00`. `$BD2D` bit 0 = 1 means White to move. White pawns therefore move towards row 0.

## 2. Corrections and additions to `docs/arch/00-overview.md`

| Overview says | Actually |
|---|---|
| a1 = `$00`, a8 = `$70` | a8 = `$00`, a1 = `$70`; rank digit = '8' − row (`FormatSquare` $74FB) [V] |
| White list `$BE00`, Black list `$BE80`; bit 7 = Black | White = `$BE80` and code bit 7 set; Black = `$BE00` [V] |
| `$7800` = king offsets | `$7800` = **knight** offsets (+14,+18,+31,+33,−14,−18,−31,−33). `$7808` = diagonals (+15,+17,−17,−15) and `$780C` = orthogonals (+1,−1,+16,−16). King/queen use all eight from `$7808`, bishops `$7808–$780B`, rooks `$780C–$780F` [V] |
| `$BCBD` = level index (1 = Level 1) | `$BCBD` = *search level* 0–7 (Level n → n−1; P1/P2/P3 → 0/3/7). The *displayed* level index is `$BCCD` (0–10) [V] |
| `$BCDD` = demo/problem/next-best flag | `$BCDD` = **next-best in progress** only. Demo is `$BCC2 = 3`; problem mode is `$BCCD ≥ 8` [V] |
| `$BF00` = display move record | `$BF00` = **root exclusion list** of (from, to) pairs ending in `$FF`, used by the search for next-best (`$7CBA`) [V] |
| `$C058+n` = move index per ply | Bits 0–6 = index in the root move list (0 = first move at `$B404`); bit 7 = the move gave check [V] |
| `$5B00` printer buffer [I] | Confirmed [V]: 256-byte ZX Printer line buffer, column in `$BCDC` |
| move-list entry +0 = score | Root moves are made/scored only while +0 = `$FF`. A score of 0 means illegal (`$7B96`, `$6311`) [V] |
| (missing) | `$7200` takes **4 inline bytes** (glyph codes); fixed in the ctl. `$6D25–$6D4C` is **code** (the return point of the ROM tape routines), not data [V] |

## 3. Routine table

| Address | Label | Role |
|---|---|---|
| $6000 | Start | Entry; anti-NEW; save IY/CHARS; title (copyright only if a key is held) |
| $605B | ColdStart | Default options (Level 2, sound on, listing off, colours) |
| $607F | NewGameConfirmed | New game after G/Y; keeps the old record if it was a standard game |
| $608F / $60A4 / $60A7 | NewGameNoConfirm / NewGameBoard / GameStartCommon | Common new-game path; `$60A7` is also used after take-back and set-up |
| $60B7 | MainLoop | Per-ply loop: replay, draw tests, status, dispatch to computer/human |
| $6147 | ComputerMove | Generate+score (mate/stalemate test), search `$7BE1`, problem-mode check, play `($BD29)` |
| $61C8 | HumanMove | Generate+score, command list, cursor input, validate against the list |
| $6323 | PlayMove | Make, promotion, eval (check flag), display, record, 50-move, repetition, side to move, exclusion list |
| $63B1 | ChoosePromotion | Computer: queen; human: PROMOTE TO? R/N/B/(Q) |
| $641A / $6448 | GameOverNoMoves / GameOverDraw | CHECKMATE / STALEMATE / DRAWN; demo restarts after ~20 s |
| $6505 | InitBoard | Standard initial position via set-up codes and slot assignment |
| $6547 / $654A / $6558 | InitBackRank / InitRank / BackRankCodes | Rank writers; back-rank set-up codes |
| $6560 | TrackRepetition | Repetition counter `$BD5E`; last-move records `$BD59–$BD5D` |
| $6587 / $6588 | SetupIllegalPop / SetupIllegal | ILLEGAL → set-up menu |
| $658E / $659C | ClearBoard / MarkAllAbsent | Empty board; mark all 32 slots absent |
| $65A8 | LiftPromotedPieces | Promoted pieces in pawn slots → set-up codes (re-slotted) |
| $65DA / $65E5 | AssignSetupPieces / AssignScan | Slot assignment in scan order; king presence; king edge bits |
| $660A | KingEdgeDistance | → `$8203` (king value byte bits 6–7 = rings from the edge) |
| $6610 / $6678 | AssignSlot / TryPieceSlot | Per-piece slot rules (§6.3) |
| $6690 / $671F | ReplayStep / ReplayEnd | Replay one recorded ply / stop replaying |
| $6734 | PollKeyboard | Any key? (prints *INTERRUPTED*) |
| $675A | WaitKey | EI, spin (incrementing `$BCCE`) until a key; DI |
| $677E | GetCommandKey | Key with S/O/cursor handling |
| $6800 | CommandDispatch | Command letters → handlers |
| $6869 / $6876 | KeyReplay / StartReplayAll | R |
| $68A0 / $68AE / $68B2 | KeyTakeBack / TakeBackOnePly / RestartAndReplay | B (restore the start position, replay n−1 plies) |
| $6916 | KeyForward | F |
| $6932 | KeyLevel | L |
| $695D / $696A | KeyMove / SwapSides | M; swap `$BCBE`, negate `$BCA0` |
| $697F / $6985 | KeyNewGame / AskNewGame | G |
| $69B3 | KeyNextBest | N |
| $69C9 | KeyPrinter | P (board / record / listing toggle) |
| $6A8D, $6B97, $6BBA | KeyAlterColours, GetColourKey, DefaultColours | A |
| $6BCF, $6CF4, $6D0F, $6D16, $6D25 | KeyTape, TapeError, TapeSave, TapeLoad, TapeReturn | T |
| $6D4D / $6D6A / $6E58 / $6ECC | ChangePosition / SetupMenu / SetupKey / SetupExit | C (set-up mode) |
| $6F23 / $6F2E | FindPieceRow / PieceTable | (value, key, slot offset) × 6; hidden copyright string |
| $6F77 | SaveStartPosition | `$C005–$C046` |
| $6F99 | ResetGameCounters | `$BD0A`, `$BD0D`, `$BD59–$BD5E` = 0 |
| $6FAA | ClearExclusionList | `$BF00` = `$FF` |
| $6FB0 | Beep | 2 inline bytes |
| $6FDD–$7063 | SetPrintPosInline, ReadPrintPos, ClearCommandArea, ClearScreen, ClearMoveLines, ClearLine12/11/10 | Screen housekeeping |
| $7065–$70BE | PrinterRule, PrinterFlushLine, PrinterClearBuffer, PrinterSendByte | ZX Printer |
| $70BF–$7226 | ShowFromSquare, ShowToSquare, CursorToStartRank, DrawBoard*, DrawGlyph2x2, PrintChar | Board/text drawing |
| $729B–$75CB | OutputVector, PrinterBoard, PrinterChar, ShowLevel, ShowIllegal, Buzz, Print* routines, PrinterResult, PrinterString, PrinterMove, ShowMove, FormatMove, FormatSquare, move numbers, SetPlayers, ShowPlayers, ShowListing, ShowSound | Messages and move notation |
| $75CC | PieceGraphics | 22 glyph chars `$90–$A5` |
| $767C–$77FF | (unused) | zeros |
| $7800 / $7808 / $780C | KnightOffsets / DiagonalOffsets / OrthogonalOffsets | Move-generation direction tables |

## 4. Variables owned or used by this subsystem

All are 8-bit unless noted.

| Address | Meaning | Writers / readers |
|---|---|---|
| `$BCA0` | Last search score (`$80` after set-up; `≥ $FE` = mate found). Negated by SwapSides. **Not reset by a new game** (0 only at program load) | search; `$6976`; `$6F03`; `$619F`; `$7820` |
| `$BCA2` | Set-up colour: `$83` White / `$03` Black | set-up |
| `$BCA9`, `$BCAB` (16-bit) | Search ply = 1 and the first list pointer `$B400` (set by InitBoard) | `$6535`, `$653E` |
| `$BCBD` | Search level 0–7 | ColdStart, KeyLevel; search |
| `$BCBE` | Side Cyrus plays: 0 = White, non-zero (`$01`/`$80`) = Black | many |
| `$BCBF` | Game over (restricts commands) | `$6106`, `$6458` |
| `$BCC0` | Last key (upper case) | WaitKey |
| `$BCC2` | Players: 0 HUMAN v HUMAN, 1 HUMAN v CYRUS, 2 CYRUS v HUMAN, 3 CYRUS v CYRUS. White is named first | many |
| `$BCC3` | Replay (R) mode | |
| `$BCC4`, `$BCC5`, `$BCC6`, `$BCC1` | Text attribute, row, column, current char | print routines |
| `$BCC7` | Board orientation flipped | O key |
| `$BCC8` (16-bit) | Saved IY | Start, WaitKey |
| `$BCCA` | Cursor square (`$FF` = none) | |
| `$BCCB`, `$BCCC` | User move from/to (`$FF` = from not yet chosen) | HumanMove |
| `$BCCD` | Level index 0–10 | KeyLevel, ShowLevel, ComputerMove |
| `$BCCE` | Random accumulator (WaitKey spin, R mixing at `$60EB`; book `$7B89`) | |
| `$BCCF` (16-bit) | Plies left to replay | ReplayStep |
| `$BCD1`, `$BCD2` | Beep duration, pitch | Beep |
| `$BCD3` | Sound off | S key |
| `$BCD4` | Listing **off** (0 = listing on) | P/T |
| `$BCD5` (16-bit) | Saved CHARS | Start, PrintChar |
| `$BCD7`–`$BCDA` | Colours: black-piece ink, white-piece ink, black-square paper, white-square paper | A key |
| `$BCDB` | Printing the move record | P/R |
| `$BCDC` | Printer buffer column | printer |
| `$BCDD` | Next-best in progress | N key, MainLoop, search `$7C18` |
| `$BCDE` | Promotion piece (value byte) for the move display | PlayMove, ReplayStep |
| `$BCDF` | Book state: 0 = still following the book; `$FF` = left the book | `$60B1`; book `$7AC7` |
| `$BD0A` | 50-move ply counter | PlayMove, `$6F99` |
| `$BD0D` | Material delta used by make/unmake; zeroed after set-up/take-back | `$6F99` (owner: B/C) |
| `$BD29` (16-bit) | Pointer to the move chosen by search/book | search, `$61C1` |
| `$BD2D` | Bit 0 side to move (1 = White); bits 1–4 phase flags set by `$7810` | |
| `$BD49` | Move number (1 at start, **10 after set-up**; increments when White is to move again; wraps at 256) | |
| `$BD4C` | Bit 6 = computer's move, bit 7 = abort (key) | ComputerMove, HumanMove, `$78BA` |
| `$BD4D` | Set-up mode: position changed (2) | set-up |
| `$BD58`–`$BD5B` | Last game move record (score, from, to, flags). IX = `$BD58` is passed to the move generator as the "previous move" (en passant) | TrackRepetition, `$6F99` |
| `$BD5C`, `$BD5D` | from, to of the move before the last | TrackRepetition |
| `$BD5E` | Consecutive-reversal counter (draw at 6) | TrackRepetition, MainLoop, search `$7D04` |
| `$BF00…` | Root exclusion list: (from, to) pairs, `$FF`-terminated | §6.7 |
| `$C000` | Tape marker (`$FF` in saved files) | tape |
| `$C001` (16-bit) | Plies played (record length) | |
| `$C003` (16-bit) | Replay target ply (0 = none; `$FFFF` = to the end) | |
| `$C005` | `$BD2D` of the start position (only if `$C006` ≠ 1) | |
| `$C006` | Start move number: 1 = standard start (opening book allowed), 10 = set-up | |
| `$C007`–`$C046` | Start position: 32 × (square, value byte), slot order | |
| `$C047` | Promotion count | |
| `$C048`–`$C057` | Promotion piece values (16 entries) | |
| `$C058…` | Game record, one byte per ply, `$FF`-terminated | |

## 5. Main loop and how a computer move is produced (item 1)

```
MainLoop ($60B7):  SP = $BDF4
  if replayMode($BCC3):                  # R key
      if record[$C001] == $FF: ReplayEnd
      redraw; wait ~2.5 s polling the keyboard (none while printing); a key → ReplayEnd
  if replayTarget($C003) != 0: ReplayStep; continue        # draw tests skipped
  $BCCE += R + (R >> 2)                                    # 8-bit, wraps
  if $BD5E == 6 or $BD0A >= 100: DRAWN
  $BCBF = 0; refresh the status lines
  if nextBest($BCDD): $BCBE = sideToMove ^ 1; SetPlayers; goto ComputerMove
  computerToMove = (WhiteToMove and $BCBE == 0) or (BlackToMove and $BCBE != 0)
  goto computerToMove ? ComputerMove : HumanMove

ComputerMove ($6147):
  if $BCC2 == 0 (HUMAN v HUMAN): SwapSides; continue
  $BD4C = $40
  IX = $BD58; call $78CE (generate root list at $B400); call $7B96 (make/eval/unmake each move; best in $BD19/$BD1A)
  if $BD19 == 0: GameOverNoMoves
  $BCDB = 0
  if not nextBest: $BF00 = $FF                   # empty exclusion list
  redraw; beep; "LET ME THINK..."
  call $7BE1                                      # SEARCH (book probe inside); result ptr in $BD29
  beep; $BCDD = 0
  if $BCCD >= 8 and $BCA0 < $FE: "NO MATE FOUND"; goto ChangePosition
  IX = ($BD29); PlayMove

PlayMove ($6323):
  call $810F (make; pushes undo data; top word popped as AF)
  $BCDE = 0
  if P/V: ChoosePromotion
  IX+3 bit 7 = 0; call $8400                       # sets IX+3 bit 7 if the move gives check [I]
  show/print the move
  $C001 += 1; record[$C001-1] = (IX+3 & $80) | ((IX - $B404) / 4); record[$C001] = $FF
  $BD0A += 1; if (F.S == 0) or ((A & $0F) == 1): $BD0A = 0
  TrackRepetition
  $BD2D ^= 1; if WhiteToMove: $BD49 += 1
  if not nextBest: append (from, to) to $BF00
  continue
```

The undo word (AF) left on the stack by `$810F` [V, from `$8138`–`$81FD`]: F = `$80` (quiet move), `$00` (capture), `$84` (promotion), `$04` (promotion with capture), `$01` (en passant), `$40` (castling). A = the moving piece's value byte *before* the move. Consequences [V]:
- **castling resets the 50-move counter**, because S is clear;
- under-promotion is only possible for human moves.

The stack is reset at every main-loop iteration, so the undo data for game moves is simply discarded.

The human branch is the same up to the generator/scorer. It then looks up the cursor squares with `$7BCD` in the root list, requiring a non-zero score. A move the generator does not produce, or one whose make/eval scored 0, prints `ILLEGAL`.

**Persistent state between searches** relevant to the port [V]: `$BCA0` (previous score; negated on side swaps; untouched by new game), `$BCDF` (book state), `$BD2D` phase bits, `$BD59–$BD5E`, `$BD0A`, `$BD49`, `$C001`/`$C058…` (the book follows the record), and the piece-list slot assignment.

## 6. Detailed specifications

### 6.1 Levels (item 2)

```
KeyLevel: $BCCD = ($BCCD + 1) mod 11
          $BCBD = {8:0, 9:3, 10:7}.get($BCCD, $BCCD)
ShowLevel: "LEVEL " + ('P' if $BCCD & 8 else ' ') + chr('1' + ($BCCD & 7))
```

There is no level table in this range. The search derives its limits from `$BCBD` at `$7C44`–`$7CB7` (subsystem C). Time is not measured anywhere (§1).

### 6.2 Keyboard (item 2)

`PollKeyboard`: `XOR A; IN A,($FE); AND $1F; CP $1F` — any key on any half-row. It is called at every search node (via `$78BA`) until `$BD4C.7` is set, and once after a book hit (`$7C23`). In the main loop it is used only for the title, the replay pause and the demo-restart wait. `WaitKey` is the only place with EI (it uses the ROM key scan via FLAGS/LAST_K).

### 6.3 Set-up mode and slot assignment (item 3)

**Codes.** A real piece code is `slot | 4 | colour($80 = White)`. A *set-up code* has bit 0 set:
- pieces entered by the user: `slot + $83` (White) / `slot + $03` (Black), so bits 0–1 are set;
- initial-position codes from InitBoard: `slot | 1` (`| $80` for White), so bit 1 is clear.

Slot offsets: K `$00`, Q `$08`, R `$10/$18`, B `$20/$28`, N `$30/$38`, P `$40–$78`.

**Keys.**
- K/Q/R/B/N/P put a set-up code on the cursor square. If a real piece was there, its slot is marked absent (bit 7 of the square byte).
- U empties the square, with the same marking.
- A clears the board and marks all slots absent.
- T toggles the colour (`$BCA2 ^= $80`), which is also the side to move on exit.
- G offers a new game. Cursor keys, S and O work as usual.

**Exit (E).**
1. Side to move = the colour shown. Cyrus takes the other side (`$BCBE` = `$80` if White is to move, else 0; `$BCC2` = 1 or 2).
2. If neither the position nor the side to move changed (`$BD4D` = 0), return to the game with its history intact.
3. `LiftPromotedPieces`: every pawn slot holding a non-pawn value is freed and its piece turned back into a set-up code with bit 1 set.
4. `AssignScan`: for file a…h, row 0…7 (rank 8 down to rank 1), each set-up code → `AssignSlot`:

   | Type | Value byte B | Byte +6 C | Slots tried, in order | Extra rule |
   |---|---|---|---|---|
   | Pawn | 1 | `$80` W / `$C0` B | `$40,$48,…,$78` | illegal on rank 1/8 |
   | King | `$00` initial / `$30` entered | 1 | `$00` only | — |
   | Queen | 9 | `$0E` | `$08`, then pawn slots | — |
   | Rook | 5 initial / `$15` entered | 8 | `$10`, `$18`, then pawn slots | — |
   | Bishop | `$83` | 4 | `$20`, `$28`, then pawn slots | — |
   | Knight | 3 | 0 | `$30`, `$38`, then pawn slots | — |

   Assigning a slot writes square → +0, `slot|4|colour` → board, B → +1, C → +6. Bytes +2…+5 and +7 keep stale values. No free slot → ILLEGAL (the work done so far is *not* undone).
5. Both kings present (else ILLEGAL); each king's value byte gets bits 6–7 = rings from the edge (`$8203`).
6. `ResetGameCounters`: `$BD0A = $BD0D = 0`, `$BD59–$BD5E = 0` (so no en passant, no repetition history, and the last move carries no check flag).
7. `$BD49 = 10`, `$BCA0 = $80`; `$7810` must return NZ (side not to move not in check), else ILLEGAL.
8. Save the start position (`$C005`–`$C046`), `$C058 = $FF`, then GameStartCommon. `$C006 = 10` disables the opening book for the rest of this game.

**Castling state** is purely the "moved" bit 4 of the king/rook value bytes (entered kings are `$30` and rooks `$15`). An untouched king/rook keeps its flags and slot, which is the manual's recipe: start from a new game and remove pieces. Castling rights in a set-up position are therefore representable exactly when the king and rook stand on their original squares *in their original slots* with bit 4 clear.

**Implication for FEN loading.** Move generation follows slot order, and slot order depends on *how* the position was entered. One FEN maps to many possible original states. The port must choose and document a canonical construction (for example "new game, then remove/enter pieces", with entered pieces slotted in the scan order above). Also: **move number 10** (which drives the `$7810` phase bits), `$BCA0 = $80`, no book, and stale +2…+5 bytes.

### 6.4 Game record, take-back, forward, replay (item 4)

- Record format: §4. The index refers to the generator's order, so the record (and saved tapes) depend on exact move ordering.
- **B (take back):** `RestartAndReplay(target = $C001 − 1)`.
  - If `$C006 == 1`: `InitBoard`.
  - Otherwise: clear the board, restore `$BD2D` from `$C005` (including its phase bits) and the 32 (square, value) pairs, and rebuild the board codes from the slots.
  - Then `ResetGameCounters`, GameStartCommon (`$C001 = 0`, `$C047 = 0`, `$BCDF = 0`), and the main loop replays with `ReplayStep` until `$C001` == target.
- **ReplayStep:**
  1. Regenerate the root list.
  2. Take entry `$B404 + 4·index`; its score `$FF` becomes 0 so that make does not apply its root-only castling trick [I].
  3. Restore the check bit, then make the move. A promotion re-applies the next value from `$C048…`.
  4. Go through AfterGameMove: 50-move counter, repetition, side to move, exclusion list.

  `$8400` is **not** called for replayed moves. `$BCA0` is untouched.
- **F (forward):** target = `$C001 + 1` if `record[$C001] != $FF`.
- **R:** target `$FFFF` plus replay mode (shows each move with a 2.5 s pause).

### 6.5 Draw and result detection (item 5)

| Result | Rule |
|---|---|
| Checkmate / stalemate | The root generator+scorer finds no move with a non-zero score. CHECKMATE if `$BD5B` bit 7 (the last game move gave check), else STALEMATE. After set-up `$BD5B` = 0, so **a mated set-up position is announced as STALEMATE** [V by code] |
| 50 moves | `$BD0A ≥ 100` at the top of the main loop. Reset by captures, en passant, promotions, pawn moves **and castling** |
| Repetition | `TrackRepetition`: `$BD5E` += 1 if this move is the exact reverse of the move two plies earlier, else 0; DRAWN when `$BD5E == 6`. Not checked during replays |
| Insufficient material | Not detected |

**Feed into the search** [V]: the root search (`$7D04`–`$7D3C`) reads `$BD5E` and `$BD5C/$BD5D`. When `$BD5E ≥ 2`, the move that would continue the shuffle (to = `$BD5C`, from = `$BD5D`) gets special treatment. The exclusion list `$BF00` is also applied at the root (`$7CBA`); in normal play it is empty. Details: subsystem C.

### 6.6 User move entry and promotion (item 6)

- The cursor starts at a2 (`$60`) for White or a7 (`$10`) for Black.
- First ENTER fixes the from-square; second ENTER the to-square. An illegal pair restarts entry; entering an illegal move is also the documented way to cancel.
- Castling and en passant are just moves in the generated list (castling is entered as the king's move).
- **Promotion:** make always produces a queen (value byte `$19` = 9 | moved). ChoosePromotion then:
  - computer, Q, or any other key: keep it, and record 9;
  - R / N / B: overwrite value byte +1 with 5 / 3 / `$83` (moved bit **clear**). Byte +6 keeps the pawn's `$80`/`$C0`.

  The value is appended at `$C048 + ($C047 − 1)`.

### 6.7 Next-best, problem levels, demo (item 7)

- **Exclusion list `$BF00`.**
  - It is cleared at the start of every computer move (unless next-best), when the human enters a move, and after each replayed ply (unless next-best).
  - Every game move is appended (unless next-best).
  - So it is empty when a normal search runs.
- **N:** `$BCDD = 1`; take back one ply. The list still holds the retracted move. The main loop makes Cyrus play the side to move; after that move `$BCDD = 0` and the move is appended. A repeated N therefore excludes more and more moves. If everything is excluded the search prints NO MORE MOVES, clears the list and searches again (`$7CDF`).
- **Problem levels:** a normal computer move with `$BCBD` = 0/3/7. Success means `$BCA0 ≥ $FE` after the search; otherwise NO MATE FOUND and set-up mode.
- **Demo (D):** `$BCC2 = 3`. On every "human" turn SwapSides flips `$BCBE` and negates `$BCA0`, so Cyrus plays both sides. A key press during thinking ends it via `$78BA` → SetPlayers. After a finished demo game it waits about 20 s (9 × 65536 polls), then starts a new game.

### 6.8 New-game initialisation (item 8)

`ColdStart` (only at load):

| Variable | Value |
|---|---|
| `$BCBD`, `$BCCD`, `$BCD4` | 1 |
| `$BCC7`, `$BCDD`, `$C006`, `$BCDB`, `$BCC3`, `$BCD3` | 0 |

It also sets the default colours and clears the printer buffer.

`NewGame` (`$607F` → `$60A7`):
- `$C058 = $FF` if `$C006 ≠ 1`; `$BCC2 = 1`; `$C003 = 0`;
- `InitBoard`:
  - `$BD00–$BEFF` = 0, which includes every board-page variable (`$BD0A`, `$BD0D`, `$BD19…`, `$BD2D`, `$BD49`, `$BD4C`, `$BD59–$BD5E` …);
  - initial position via set-up codes and AssignScan, with all slots in standard order and untouched kings/rooks;
  - `$BCBE = $BD2D = $BD49 = $BCA9 = $C006 = 1`; `($BCAB) = $B400`;
- `$C001 = 0`, `$C047 = 0`, `$BCDF = 0`.

**Not reset:** `$BCA0`, `$BCCE`, the level, the colours, `$BCC7`, `$BCD3`, `$BCD4`, and the work areas outside `$BD00–$BEFF`.

## 7. Fixed capacities and crash risks

| Item | Capacity / behaviour | Risk |
|---|---|---|
| Promotion list `$C048–$C057` | 16 entries; the 17th overwrites `$C058` (first record byte). The counter is 8-bit and `L` wraps within page `$C0`, so later entries overwrite `$C000–$C046` | Take-back/replay corruption after >16 promotions. Not relevant to UCI search |
| Game record `$C058…` | Unbounded up to `$FFFF` (~16 K plies); the tape loader accepts ≤ `$1F00` bytes | None in practice |
| Move index | 7 bits; root lists with > 128 entries would collide with the check bit | Record only |
| Exclusion list `$BF00…` | Never bounded. In HUMAN v HUMAN mode it is never cleared and grows 2 bytes/ply: after 128 plies it overwrites `$C000–$C006` (record header, replay target) | **Class A in the original**, but irrelevant if the port keeps the list empty for normal searches |
| `$BD49` move number | 8-bit, wraps after move 255. `$7810` phase logic then sees "move < 8" | Class C quirk |
| `$BD0A`, `$BD5E` | 8-bit; `$BD5E` can exceed 6 during replays without a draw being declared | Quirk |
| Set-up ILLEGAL | Partial slot assignment is left in place | Not relevant to the port (it rejects such positions) |

## 8. Open questions

1. `$8400` returning 0 = "side that just moved is in check", and it setting IX+3 bit 7 = "gives check" (SET 7,(IX+3) at `$8ABF`, `$8D2F`, `$8D51`): inferred; confirm in subsystem E.
2. `$810F`/`$81EA`: when the move's score byte is `$FF`, castling stores `C & $84` (a king code) on the rook's square — apparently so that the king's transit square counts during the legality test. That is why ReplayStep turns `$FF` into 0 first. Confirm in subsystem B.
3. ReplayStep skips `$8400`. Does `$8400` have side effects on persistent state (beyond the check flag) that make a replayed game differ from the same game played live? This matters if the port rebuilds UCI `position … moves` by replaying.
4. `$BCA0` carries over between moves and games. How should the port initialise it for UCI `position`/`go`? Options: 0 at `ucinewgame`, then keep the last search score from the side to move's view (negate when the engine switches sides, as SwapSides does).
5. How should `position fen` choose slot assignment and castling flags (§6.3)? This is a design decision for the port.

## 9. Verification performed

- Simulator, from `reference/snapshots/cyrus48-entry-6000.z80`:
  - level presses → `$BCBD/$BCCD` = 7/7, 0/8, 3/9, 7/10 for Level 8, P1, P2, P3;
  - set-up with a second white king on a2 → ILLEGAL;
  - set-up removing the a2 pawn → `$BD49 = 10`, `$C005 = $03`, `$C006 = $0A`, start position saved at `$C007…`, king/rook "moved" bits clear;
  - after 1.Nf3 (book): `$BF00 = 76 55 FF`, `$C058 = 03`, from/to = `$76→$55`, confirming the board orientation;
  - after an 86-ply demo game: record bytes with check bits (`$95`, `$91`, …) and terminator.
- Grep of the whole disassembly: no FRAMES/timer access; EI only at `$675E`; keyboard polls only at `$6027`, `$6056`, `$60D2`, `$6479`, `$78C1`, `$7C23`.
