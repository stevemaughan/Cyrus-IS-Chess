import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Fuzz the evaluation: random positions/variables -> original $8400 vs model.

Usage: python -I fuzz.py SNAPSHOT COUNT SEED [--fen FEN ...]
Also provides setup_position() used by samples.py.
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cyrus_sim import Machine  # noqa: E402
from evalmodel import evaluate  # noqa: E402
from skoolkit.simutils import PC, SP  # noqa: E402

A_, F_, B_, C_, D_, E_, H_, L_, IXh, IXl = range(10)
COV = set()
TRAP = 0x5B00         # printer buffer: unused while we call $8400 directly
IXADDR = 0xB400
PLUS6 = {'K': 0x01, 'Q': 0x0E, 'R': 0x08, 'B': 0x04, 'N': 0x00}
TYPE = {'K': 0x00, 'Q': 0x09, 'R': 0x05, 'B': 0x83, 'N': 0x03}
SLOTS = {'K': [0], 'Q': [1], 'R': [2, 3], 'B': [4, 5], 'N': [6, 7]}
PROMO_TYPE = {'Q': 0x19, 'R': 0x05, 'B': 0x83, 'N': 0x03}


def sq88(file, rank):
    return rank * 16 + file


def king_type(sq, moved, castled):
    t = (0x10 if moved else 0) | (0x20 if castled else 0)
    if not moved:
        return t
    e = 0x11
    while True:
        if ((sq + e) & 0x88) or ((sq - e) & 0x88) or sq - e < 0:
            break
        t = (t + 0x40) & 0xFF
        e += 0x11
    return t


def pawn_type(sq, white):
    r = sq >> 4
    rel = r if white else 7 - r
    return {3: 0x11, 4: 0x31, 5: 0x61, 6: 0x91}.get(rel, 0x01)


def setup_position(mem, placement, opts):
    """placement: list of (piece letter, colour 'w'/'b', square88, extra dict)."""
    for a in range(0xBD00, 0xBD80):
        if not (a & 0x88):
            mem[a] = 0
    for a in range(0xBE00, 0xBF00):
        mem[a] = 0
    for colour in 'wb':
        base = 0x00 if colour == 'w' else 0x80
        for i in range(16):
            rec = 0xBE00 + base + 8 * i
            mem[rec] = 0x80                      # absent
            mem[rec + 1] = 0x01 if i >= 8 else TYPE['KQRRBBNN'[i]]
            mem[rec + 6] = (0xC0 if colour == 'w' else 0x80) if i >= 8 else PLUS6['KQRRBBNN'[i]]
        used = set()
        pawn_slot = 8
        for p, c, sq, ex in placement:
            if c != colour:
                continue
            slot = None
            if p == 'P':
                slot = pawn_slot
                pawn_slot += 1
            else:
                for s in SLOTS[p]:
                    if s not in used:
                        slot = s
                        break
                if slot is None:                 # extra piece -> promoted pawn slot
                    slot = pawn_slot
                    pawn_slot += 1
            used.add(slot)
            rec = 0xBE00 + base + 8 * slot
            code = (base + 8 * slot + 4) & 0xFF
            mem[rec] = sq
            if p == 'P':
                mem[rec + 1] = pawn_type(sq, colour == 'w')
            elif slot >= 8:
                mem[rec + 1] = ex.get('type', PROMO_TYPE[p])
            elif p == 'K':
                mem[rec + 1] = king_type(sq, ex.get('moved', False), ex.get('castled', False))
            else:
                mem[rec + 1] = TYPE[p] | (0x10 if ex.get('moved') else 0)
            mem[0xBD00 + sq] = code
    for k, v in opts.items():
        mem[k] = v


def run_original(m, ixbytes):
    sim = m.sim
    r = sim.registers
    mem = sim.memory
    mem[IXADDR:IXADDR + 4] = ixbytes
    sp = 0xBDF0
    mem[sp] = TRAP & 0xFF
    mem[sp + 1] = TRAP >> 8
    r[SP] = sp
    r[PC] = 0x8400
    r[IXh], r[IXl] = IXADDR >> 8, IXADDR & 0xFF
    r[26] = 0                                    # interrupts off
    opcodes = sim.opcodes
    n = 0
    while r[PC] != TRAP:
        COV.add(r[PC])
        opcodes[mem[r[PC]]]()
        n += 1
        if n > 2_000_000:
            raise RuntimeError('runaway')
    return r[A_], r[B_]


def random_case(rng):
    squares = [sq88(f, r) for r in range(8) for f in range(8)]
    rng.shuffle(squares)
    placement = []
    taken = set()

    def take(pred=lambda s: True):
        for s in squares:
            if s not in taken and pred(s):
                taken.add(s)
                return s
        return None

    wk = take()
    bk = take(lambda s: rng.random() < 0.97 or True)
    placement.append(('K', 'w', wk, {'moved': rng.random() < 0.6, 'castled': rng.random() < 0.3}))
    placement.append(('K', 'b', bk, {'moved': rng.random() < 0.6, 'castled': rng.random() < 0.3}))
    for colour in 'wb':
        counts = {'Q': rng.choice([0, 1, 1, 1, 2]), 'R': rng.choice([0, 1, 2, 2]),
                  'B': rng.choice([0, 1, 2, 2]), 'N': rng.choice([0, 1, 2, 2, 3]),
                  'P': rng.choice([0, 2, 4, 6, 8])}
        for p, n in counts.items():
            for _ in range(n):
                if p == 'P':
                    s = take(lambda s: 1 <= (s >> 4) <= 6)
                else:
                    s = take()
                if s is None:
                    continue
                ex = {'moved': rng.random() < 0.5}
                if p != 'P' and rng.random() < 0.15:
                    ex['type'] = rng.choice([0x05, 0x83, 0x03, 0x19])
                placement.append((p, colour, s, ex))
    # cap pawn-slot overflow: at most 8 pawns + extras per side
    for colour in 'wb':
        extra = sum(1 for p, c, _, _ in placement if c == colour and p == 'P')
        extra += max(0, sum(1 for p, c, _, _ in placement if c == colour and p == 'Q') - 1)
        extra += max(0, sum(1 for p, c, _, _ in placement if c == colour and p == 'N') - 2)
        if extra > 8:
            placement = [x for x in placement if not (x[1] == colour and x[0] == 'P')]
    phase = rng.choice([0x00, 0x02, 0x06, 0x0E, 0x1E, 0x0C, 0x08])
    opts = {
        0xBD2D: phase | rng.randint(0, 1),
        0xBD0D: rng.choice([0, 0, 0, 1, 0xFF, 3, 0xFD, 9, 0xF7, 0x10, 0xF0]),
        0xBD4A: rng.choice([0, 0, 2, 0xFE, rng.randint(0, 255)]),
        0xBD1E: rng.choice([0, 0, 1, 0xFF, 3, 0xFD]),
        0xBD6D: rng.choice([0, 1]),
        0xBD49: rng.choice([1, 1, 2, 5, 8, 20, 40]),
        0xBCCE: rng.randint(0, 255),
        0xBD4E: 0, 0xBD79: 0,
    }
    if rng.random() < 0.3:                      # junk in off-board squares
        for r in range(8):
            for f in (8, 15):
                opts[0xBD00 + r * 16 + f] = rng.choice([0, 0, 0, rng.randint(0, 255)])
    pieces = [x for x in placement]
    mv = rng.choice(pieces)
    ixb = [0xFF, rng.choice(squares), mv[2], rng.choice([0, 0, 0x08, 0x10, 0x20, 0x01])]
    return placement, opts, ixb


def protected_vars():
    keep = {}
    return keep


def main():
    snap, count, seed = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    rng = random.Random(seed)
    m = Machine(snap)
    base = bytes(m.sim.memory[0xBC00:0xBF00])
    ok = bad = aborts = 0
    for i in range(count):
        placement, opts, ixb = random_case(rng)
        mem = m.sim.memory
        mem[0xBC00:0xBF00] = base
        # leave off-board variables as in the snapshot unless overridden
        setup_position(mem, placement, opts)
        model_mem = bytearray(65536)
        model_mem[0xBC00:0xBF00] = bytes(mem[0xBC00:0xBF00])
        model_mem[IXADDR:IXADDR + 4] = bytes(ixb)
        a, b = run_original(m, ixb)
        ma, mb = evaluate(model_mem, IXADDR)
        diffs = []
        if a != ma:
            diffs.append(f'A {ma:02X}/{a:02X}')
        if a and b != mb:
            diffs.append(f'B {mb:02X}/{b:02X}')
        for k in range(0x300):
            addr = 0xBC00 + k
            if 0xBDA0 <= addr < 0xBE00 or addr in (0xBD3D, 0xBD3E):
                continue
            if model_mem[addr] != mem[addr]:
                diffs.append(f'{addr:04X} {model_mem[addr]:02X}/{mem[addr]:02X}')
        if list(model_mem[IXADDR:IXADDR + 4]) != list(mem[IXADDR:IXADDR + 4]):
            diffs.append('IX ' + bytes(model_mem[IXADDR:IXADDR + 4]).hex() + '/' + bytes(mem[IXADDR:IXADDR + 4]).hex())
        if a == 0:
            aborts += 1
        if diffs:
            bad += 1
            if bad <= 6:
                print(f'case {i}: ' + '; '.join(diffs[:10]))
        else:
            ok += 1
    print(f'{ok} match, {bad} differ, {aborts} aborts')
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), f'fuzz{seed}.cov'), 'w') as f:
        for a in sorted(COV):
            f.write(f'${a:04X}\n')


if __name__ == '__main__':
    main()
