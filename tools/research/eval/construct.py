import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Hand-constructed eval cases run on the original and the model."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fuzz  # noqa: E402
from cyrus_sim import Machine  # noqa: E402
from evalmodel import evaluate  # noqa: E402
from samples import fen, slots, sqname  # noqa: E402


def sq(name):
    return (int(name[1]) - 1) * 16 + 'abcdefgh'.index(name[0])


CASES = [
    ('pawnless late endgame KR v K, centralisation (BD6D=0)',
     [('K', 'w', sq('d4'), {'moved': True}), ('R', 'w', sq('a7'), {}), ('K', 'b', sq('g8'), {'moved': True})],
     {0xBD2D: 0x1E | 0, 0xBD1E: 0x05, 0xBD6D: 0, 0xBD49: 50, 0xBD0D: 0, 0xBD4A: 0, 0xBCCE: 0x10},
     [0xFF, sq('a1'), sq('a7'), 0]),
    ('same, black to move with BD1E sign matching black',
     [('K', 'w', sq('d4'), {'moved': True}), ('R', 'w', sq('a7'), {}), ('K', 'b', sq('g8'), {'moved': True})],
     {0xBD2D: 0x1E | 1, 0xBD1E: 0xFB, 0xBD6D: 0, 0xBD49: 50, 0xBD0D: 0, 0xBD4A: 0, 0xBCCE: 0x10},
     [0xFF, sq('a1'), sq('a7'), 0]),
    ('under-promoted knight and rook in pawn slots',
     [('K', 'w', sq('g1'), {'moved': True, 'castled': True}), ('N', 'w', sq('e8'), {'type': 0x03}),
      ('N', 'w', sq('b1'), {}), ('N', 'w', sq('g5'), {}), ('R', 'w', sq('d1'), {}), ('R', 'w', sq('f1'), {}),
      ('R', 'w', sq('c3'), {'type': 0x05}), ('P', 'w', sq('f2'), {}), ('P', 'w', sq('g2'), {}),
      ('K', 'b', sq('c8'), {'moved': True}), ('Q', 'b', sq('d5'), {}), ('P', 'b', sq('a7'), {})],
     {0xBD2D: 0x02 | 0, 0xBD1E: 0, 0xBD6D: 1, 0xBD49: 30, 0xBD0D: 0, 0xBD4A: 0, 0xBCCE: 0x00},
     [0xFF, sq('e7'), sq('e8'), 0]),
    ('knight + rook double check (second pass)',
     [('K', 'w', sq('g1'), {'moved': True}), ('R', 'w', sq('e1'), {}), ('N', 'w', sq('d6'), {}),
      ('K', 'b', sq('e8'), {}), ('P', 'b', sq('a7'), {}), ('Q', 'b', sq('a5'), {})],
     {0xBD2D: 0x02 | 0, 0xBD1E: 0, 0xBD6D: 1, 0xBD49: 20, 0xBD0D: 0, 0xBD4A: 0, 0xBCCE: 0x00},
     [0xFF, sq('c4'), sq('d6'), 0]),
    ('side to move attacks enemy king: abort (A=0)',
     [('K', 'w', sq('g1'), {}), ('R', 'w', sq('e1'), {}), ('K', 'b', sq('e8'), {})],
     {0xBD2D: 0x02 | 1, 0xBD49: 20, 0xBD0D: 0, 0xBD4A: 0, 0xBCCE: 0x00},
     [0xFF, sq('e7'), sq('e8'), 0]),
    ('off-board junk: $BD28=$C4 read by white h2 pawn as a black pawn',
     [('K', 'w', sq('e1'), {}), ('P', 'w', sq('h2'), {}), ('K', 'b', sq('e8'), {}), ('P', 'b', sq('a7'), {})],
     {0xBD2D: 0x02 | 0, 0xBD49: 20, 0xBD0D: 0, 0xBD4A: 0, 0xBCCE: 0x00, 0xBD28: 0xC4},
     [0xFF, sq('h3'), sq('h2'), 0]),
    ('absolute pin: black knight c6 pinned by Bb5 to Ke8',
     [('K', 'w', sq('e1'), {}), ('B', 'w', sq('b5'), {}), ('P', 'w', sq('d4'), {}),
      ('K', 'b', sq('e8'), {}), ('N', 'b', sq('c6'), {}), ('P', 'b', sq('d7'), {}), ('P', 'b', sq('e5'), {})],
     {0xBD2D: 0x02 | 0, 0xBD49: 20, 0xBD0D: 0, 0xBD4A: 0, 0xBCCE: 0x00},
     [0xFF, sq('f1'), sq('b5'), 0]),
]


def main():
    m = Machine(sys.argv[1])
    base = bytes(m.sim.memory[0xBC00:0xBF00])
    for title, placement, opts, ixb in CASES:
        mem = m.sim.memory
        mem[0xBC00:0xBF00] = base
        fuzz.setup_position(mem, placement, opts)
        state = bytearray(65536)
        state[0xBC00:0xBF00] = bytes(mem[0xBC00:0xBF00])
        state[fuzz.IXADDR:fuzz.IXADDR + 4] = bytes(ixb)
        before = bytes(state)
        a, b = fuzz.run_original(m, ixb)
        ma, mb = evaluate(state, fuzz.IXADDR)
        same = a == ma and (a == 0 or b == mb) and all(
            state[x] == mem[x] for x in range(0xBC00, 0xBF00) if not (0xBDA0 <= x < 0xBE00 or x in (0xBD3D, 0xBD3E)))
        v = ' '.join(f'{before[x]:02X}' for x in (0xBD2D, 0xBD0D, 0xBD4A, 0xBD1E, 0xBD6D, 0xBD49, 0xBCCE))
        junk = 'BD28=C4' if before[0xBD28] else '-'
        print(f'| `{fen(before)}` ({title}; {"model OK" if same else "MISMATCH"}) | {slots(before)} | {sqname(ixb[1])}→{sqname(ixb[2])} {ixb[3]:02X}→{mem[fuzz.IXADDR + 3]:02X} | {v} | {junk} | {a:02X} | {b:02X} |')


if __name__ == '__main__':
    main()
