# Cyrus IS Chess (48K): architecture overview

This is the shared starting point for the subsystem documents in `docs/arch/`. Facts are tagged:
- **[V]** verified by reading code and/or by observing memory in the simulator;
- **[I]** inferred, still to be confirmed.

Addresses are hexadecimal.

## Tooling

| Tool | Purpose |
|---|---|
| `tools/scripts/cyrus_sim.py` | Run a snapshot in SkoolKit's Z80 simulator with scripted keys. It can write an execution map (`--map`), a per-address execution profile (`--profile`), a screenshot (`--png`) and a snapshot (`--out`). |
| `tools/scripts/memdump.py` | Hex-dump memory from a snapshot. |
| `tools/scripts/mkctl.py` | Recursive-descent control-file generator. It was used once to create the initial `disasm/ctl/*.ctl`, which are now hand-maintained. |
| `tools/scripts/build-disasm.ps1` | `disasm/ctl/*.ctl` + entry snapshot → `disasm/cyrus.skool`, `disasm/cyrus.asm`. |

Keys in `cyrus_sim.py` scripts: `l` = level, `m` = move, `d` = demo, `c` = change position, `5`–`8` = cursor, `ENTER`, and so on (see the manual §21). A useful idle state: run the entry snapshot for 3 s, then press `l` ten times to reach Level 1.

## Memory map

| Range | Contents |
|---|---|
| `$5B00–$5BFF` | Printer buffer (ZX Printer output) **[I]** |
| `$6000–$77FF` | Main loop, UI, display, set-up mode, game record, take-back/replay, printer, tape, messages |
| `$75CC–$780F` | Piece graphics (UDG-style) and direction tables. `$7800` holds king offsets and `$7808` knight offsets; `$780C`, `$7808` and `$7800` are the slider direction sets **[I]** |
| `$7810–$7AC6` | Pre-search set-up (`$7810`) and move generator (`$78CE`) |
| `$7AC7–$7B95` | Opening book lookup; data at `$9000–$9FFF` |
| `$7B96–$80A6` | Root move scoring (`$7B96`), search driver (`$7BE1`/`$7BF1`), search (`$7D43`, `$7E8C`, …) |
| `$80A7–$83FF` | Make (`$810F`) and unmake (`$821C`) move; `$828C–$83FF` is zero padding |
| `$8400–$8F2E` | Evaluation (`$8400`, 1400 bytes) and helpers (`$8978–$8F2E`, the hottest code during search) |
| `$8F2F–$8FFF` | Zero padding |
| `$9000–$9FFF` | Opening book (bit-packed) |
| `$B400–$BC8F` | Move lists: 4 bytes per move; per-ply start pointers at `$BCAB` **[V]** |
| `$BC90–$BCFF` | Global variables (see below) |
| `$BD00–$BD7F` | 0x88 board. The off-board squares (low nibble ≥ 8) hold variables **[V]** |
| `$BD80–$BDF4` | Variables and stack (`SP=$BDF4` in the main loop) **[V]** |
| `$BE00–$BEFF` | Piece lists: White `$BE00–$BE7F`, Black `$BE80–$BEFF` **[V]** |
| `$BF00–…` | Display move record: pairs of (from, to), terminated by `$FF` **[I]** |
| `$C000–…` | Game record: `$C001` = ply count; `$C058+n` = move index per ply **[I]** |

## Board **[V]**
- `$BD00 + sq`, where `sq = rank*16 + file` (0x88). a1 = `$00`, h1 = `$07`, a8 = `$70`. A square is off-board when `sq & $88 != 0`.
- The content is 0 for an empty square, otherwise a **piece code**:
  - bit 7 = Black;
  - bit 2 always set;
  - `code & $7B` (bit 2 cleared, colour kept) is the offset of the piece's record in page `$BE`.
- Start position codes: `e1=$04 d1=$0C a1=$14 h1=$1C c1=$24 f1=$2C b1=$34 g1=$3C`, pawns `$44…$7C`. Black is the same plus `$80`.

## Piece lists **[V]** (start-position values shown)

8-byte record at `$BE00 + (code & ~4)`, in the order K, Q, R(a), R(h), B(c), B(f), N(b), N(g), P(a…h):

| Offset | Meaning |
|---|---|
| +0 | square (0x88). Bit 7 set = captured/absent **[I]** |
| +1 | low nibble = material value (K 0, Q 9, R 5, B 3, N 3, P 1); bit 7 = bishop **[I]**; bit 4 = has moved **[I]** (tested for castling at `$78F9`, `$7A66`, `$7A7D`) |
| +6 | per-piece constant: K `$01`, Q `$0E`, R `$08`, B `$04`, N `$00`, P `$C0` (White) / `$80` (Black) **[I]** |
| +2…+5, +7 | 0 at rest; working storage **[I]** |

## Move list entries **[V]**

4 bytes, written by `$7A9D`:

| Offset | Meaning |
|---|---|
| +0 | score. Set to `$FF` when generated; overwritten by root scoring |
| +1 | from-square |
| +2 | to-square |
| +3 | flags. `$08` = capture **[I]**; `$10` / `$20` / `$28` = castling / en passant / … **[I]**; bit 7 is tested in many places **[I]** |

A list ends with an entry whose +0 is `$FF` written past the last move **[I]**. `$BCA9` = current ply; the pointer table starts at `$BCAB` **[V]**.

## Calling conventions with inline data **[V]**

| Routine | Inline data after the `CALL` |
|---|---|
| `$6FB0` | beep: 2 bytes (duration, pitch). It spins in `$6FC0–$6FDB`, which takes about 25% of demo-mode time |
| `$6FDD` | set print position: 2 bytes (row, column) |
| `$7415` | print at: 2 bytes (row, column) + string (last byte has bit 7 set) |
| `$73F7`, `$73FE`, `$7405`, `$740E`, `$741A`, `$741C` | print string (bit-7-terminated) at a fixed or current position |

## Known variables (partial)

| Address | Meaning |
|---|---|
| `$BCBD` | level index (1 = Level 1 …) **[I]** |
| `$BCCE` | random accumulator. It is incremented while waiting for a key (`$675A`) and mixed with `R` (`$60EB`, `$7B89`) **[V]** |
| `$BCC8` | saved IY for ROM use **[V]** |
| `$BCD3` | sound off flag **[I]** |
| `$BCDD` | demo/problem/next-best related flag **[I]** |
| `$BD2D` | bit 0 = side to move (1 = White at start) **[I]** |
| `$BD49` | move number **[I]** |
| `$BD4C` | bit 7 = search abort (key pressed, set at `$78C9`) **[V]** |
| `$BD58` | IX base for the root "move" record **[I]** |

## Key routines found so far

| Address | Role |
|---|---|
| `$6000` | entry, then the main loop at `$60B7` |
| `$6734` | **keyboard interrupt poll**: `IN ($FE)` on all half-rows; NZ if any key is pressed (prints `*INTERRUPTED*`). It is called from the search via `$78BA`, which sets `$BD4C` bit 7 |
| `$675A` | wait for a key (EI; spin incrementing `$BCCE` until `LAST_K`) |
| `$7810` | pre-search set-up (flips side, calls eval `$8400`, phase/material bookkeeping) |
| `$78CE` | move generator for the side in `$BD2D`, into the current ply's list |
| `$7AC7` | opening-book probe |
| `$7B96` | score each root move with make / eval / unmake; best in `$BD19` / `$BD1A` |
| `$7BE1`, `$7BF1` | search driver |
| `$810F`, `$821C` | make / unmake (they pop the return address and save state on the stack) |
| `$8400` | evaluation (returns an 8-bit score in A) **[I]** |
