# Reference material — provenance

These files are the ground truth for the port. **Never modify them.** Verify them against `CHECKSUMS.txt` with:

```powershell
Get-FileHash reference\original\*, reference\extracted\* -Algorithm SHA256
```

## Canonical release

| | |
|---|---|
| Title | Cyrus IS Chess (also "Cyrus 1981 European Champion") |
| Author | Richard Lang, Intelligent Software Ltd |
| Publisher | Sinclair Research Ltd (UK), 1983, £9.95 — **original release** |
| Source | Spectrum Computing, ZXDB entry 1214 — https://spectrumcomputing.co.uk/entry/1214 |
| Downloaded | 2026-10-21 from `https://spectrumcomputing.co.uk/pub/sinclair/games/c/CyrusISChess.tzx.zip` |
| Canonical file | `original/CyrusISChess-48k.tzx` (zip member `Cyrus Is Chess - 48k.tzx`, TZX v1.10, "Created with Ramsoft MakeTZX") |

### Why this file

- It is a dump of the original Sinclair Research release. The alternatives are worse sources: the Ventamatic (Spain, 1983) re-release, the unauthorised *Load 'n' Run* #09 covertape copy ("Scacchi", 1984), and the 2015 ZX Spectrum Vega compilation. None has a separate dump in the archive.
- It is the 48K side of the cassette. The manual says one side holds two copies of the 48K version and the other side holds a simplified 16K/48K version. This file contains both 48K copies, and they are **byte-identical** in all four blocks.
- All eight data-block checksums are valid.
- The code contains strings for features that exist only in the 48K version, according to the manual: `NO MATE FOUND`, `Next-best`, `Alter`, `Printer`, `Tape`.
- The archive's separate TAP (`CYRCHESS.TAP`, SHA-256 `4a8249b5…9b1f`) is a later re-save with a different BASIC loader (blocks `Cyrusch1/2/3`). Its 16 KB code block is **byte-identical** to the one here, which independently confirms the engine bytes. It is not kept.

`original/CyrusISChess-16k.tzx` is the other side of the same cassette. It is kept as a secondary reference: comparing it with the 48K code can help identify shared routines. It is **not** the specification.

## Tape layout (48K side; the second copy repeats this exactly)

| # | Block | Header name | Load address | Length | Extracted to |
|---|---|---|---|---|---|
| 1 | BASIC program (autostart line 10) | `IS-Chess48` | — | 277 | `extracted/basic-loader.bin` |
| 2 | CODE (attribute-area logo) | `IS-Logo` | header `$5800`, loaded at `$5A00` by BASIC | 256 | `extracted/is-logo-5A00.bin` |
| 3 | CODE (loader, printer buffer) | `CLoad48` | `$5B00` | 100 | `extracted/cload48-5B00.bin` |
| 4 | Headerless data, flag `$FF` | — | `$6000` | 16384 | `extracted/cyrus48-6000-9FFF.bin` |

The BASIC program, detokenized:

```
10 CLEAR 24319: PRINT AT 3,12;"CYRUS": PRINT AT 4,12;"====="
15 PRINT AT 6,5;"1981 European Champion": REM Author : Richard Lang
20 PRINT AT 12,0;"© 1983 Intelligent Software Ltd."
30 INK 7: LOAD "" CODE 23040: PRINT AT 13,0: LOAD "" CODE 23296: PRINT USR 23296
```

`CLoad48` uses the standard ROM loader, with no protection or turbo:

```
5B00  11 00 40     LD   DE,$4000      ; 16384 bytes
5B03  37           SCF                ; load, not verify
5B04  DD 21 00 60  LD   IX,$6000
5B08  3E FF        LD   A,$FF         ; data block flag
5B0A  CD 56 05     CALL $0556         ; ROM LD-BYTES
5B0D  D2 00 00     JP   NC,$0000      ; reset on load error
5B10  C3 00 60     JP   $6000         ; program entry
```

## First observations on the code block

- The entry point is `$6000`. Its first instructions are `LD HL,$1111 / LD ($5CB2),HL / LD ($5CB4),HL / DI / LD ($BCC8),IY`. So the program uses RAM above `$9FFF` as workspace, which is why it needs a 48K machine. The workspace layout is to be mapped in Phase 1.
- An embedded copyright string reads `1982 Intelligent Software Ltd.`, while the BASIC loader says 1983.

## Other files

- `../docs/manual/CyrusISChess.txt` and `CyrusISChess-EN.pdf` are the original instructions, from the same ZXDB entry.
- `original/48.rom` is the standard Sinclair 48K ROM, copied unmodified from SkoolKit 10.1's bundled resources. Amstrad permits its distribution for emulator use.
- `snapshots/cyrus48-entry-6000.z80` is the machine state at the program entry point. It was made with SkoolKit 10.1:

  ```
  tap2sna.py -s 24576 reference/original/CyrusISChess-48k.tzx reference/snapshots/cyrus48-entry-6000.z80
  ```

  The simulation ran the real BASIC and `CLoad48` loader through the ROM and stopped at `PC=$6000`. Its `$6000–$9FFF` is byte-identical to `extracted/cyrus48-6000-9FFF.bin`.

- `snapshots/cyrus48-idle-level1.z80` is the start position, Level 1 selected, waiting at `YOUR MOVE?`. It was made with:

  ```
  cyrus_sim.py reference/snapshots/cyrus48-entry-6000.z80 --keys "w3s,<l/3,w10 ×10>,w1s" --out …
  ```

  That is: wait 3 s, press L ten times (Level 2 → … → P3 → Level 1), wait 1 s. The result is deterministic; regenerating it is byte-identical. The Phase 1 research scripts use it as their base state.

## Run check

Tracing the snapshot for 3.0 s of emulated time (`trace.py -M 10500000 …`) reaches the idle main loop, with the screen shown in `../docs/images/original-startup.png`. That screen shows `HUMAN v CYRUS`, `YOUR MOVE?`, `LEVEL 2`, `SOUND ON`, `LISTING OFF` and the 48K command bar. This matches the manual's description of the 48K version and its default level.
