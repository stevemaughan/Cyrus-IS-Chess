import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Agent B probe: poke a position into Cyrus's board/piece lists, call the
move generator $78CE (and optionally make/unmake), and decode the results."""

import sys
sys.path.insert(0, SCRIPTS)

from cyrus_sim import Machine
from skoolkit.simutils import PC, SP, A, F, B, C, D, E, H, L, IXh, IXl, IYh, IYl

SNAP = LVL1
SENTINEL = 0x5CB0   # address of a HALT-free location used as fake return address

FILES = 'abcdefgh'


def sqname(s):
    if s & 0x88:
        return f'?{s:02X}'
    return FILES[s & 7] + str((s >> 4) + 1)


TYPE = {'k': 0x00, 'q': 0x09, 'r': 0x05, 'b': 0x83, 'n': 0x03, 'p': 0x01}
W6 = {'k': 0x01, 'q': 0x0E, 'r': 0x08, 'b': 0x04, 'n': 0x00}


def set_position(mem, fen, castle_ok=True):
    """Fill board $BD00 (on-board squares only) and piece lists $BE00/$BE80."""
    rows = fen.split()[0].split('/')
    for r in range(8):
        for f in range(8):
            mem[0xBD00 + r * 16 + f] = 0
    for base in (0xBE00, 0xBE80):
        for i in range(16):
            rec = base + i * 8
            mem[rec:rec + 8] = [0x80, 0, 0, 0, 0, 0, 0, 0]
    slots = {'k': [0], 'q': [1], 'r': [2, 3], 'b': [4, 5], 'n': [6, 7], 'p': list(range(8, 16))}
    used = {0: set(), 0x80: set()}
    for ri, row in enumerate(rows):
        rank = 7 - ri
        f = 0
        for ch in row:
            if ch.isdigit():
                f += int(ch)
                continue
            colour = 0 if ch.isupper() else 0x80
            p = ch.lower()
            sq = rank * 16 + f
            cand = [s for s in slots[p] if s not in used[colour]]
            if not cand:
                cand = [s for s in range(8, 16) if s not in used[colour]]
            slot = cand[0]
            used[colour].add(slot)
            rec = (0xBE00 if colour == 0 else 0xBE80) + slot * 8
            t = TYPE[p]
            if p != 'k' and p != 'p' and not castle_ok:
                t |= 0x10
            mem[rec] = sq
            mem[rec + 1] = t
            mem[rec + 6] = (0xC0 if colour == 0 else 0x80) if p == 'p' else W6[p]
            mem[0xBD00 + sq] = colour | (slot * 8) | 4
            f += 1


def call(m, addr, regs=None, max_frames=200):
    sim = m.sim
    r = sim.registers
    sp = r[SP] - 2
    m.memory[sp] = SENTINEL & 0xFF
    m.memory[sp + 1] = SENTINEL >> 8
    r[SP] = sp
    for k, v in (regs or {}).items():
        r[k] = v
    r[PC] = addr
    r[26] = 0  # IFF off: avoid interrupts
    if not m.run_frames(max_frames, stop=SENTINEL):
        raise RuntimeError(f'call to ${addr:04X} did not return; PC=${r[PC]:04X}')


def gen(m, side_black, ply=1, ix=0xBD58):
    mem = m.memory
    mem[0xBD2D] = (mem[0xBD2D] & 0xFE) | (1 if side_black else 0)
    mem[0xBCA9] = ply
    r = m.sim.registers
    r[IXh], r[IXl] = ix >> 8, ix & 0xFF
    call(m, 0x78CE)
    tbl = 0xBCA9 + 2 * ply
    start = mem[tbl] | mem[tbl + 1] << 8
    end = mem[tbl + 2] | mem[tbl + 3] << 8
    hdr = mem[start:start + 4]
    moves = []
    a = start + 4
    while a < end:
        moves.append(tuple(mem[a:a + 4]))
        a += 4
    return start, end, hdr, moves


def fmt(mv):
    s, fr, to, fl = mv
    return f'{sqname(fr)}{sqname(to)}' + (f'/{fl:02X}' if fl else '')


if __name__ == '__main__':
    m = Machine(SNAP)
    fen = sys.argv[1] if len(sys.argv) > 1 else 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w'
    side_black = len(fen.split()) > 1 and fen.split()[1] == 'b'
    set_position(m.memory, fen)
    start, end, hdr, moves = gen(m, side_black)
    print(f'list ${start:04X}-${end:04X} header={[hex(x) for x in hdr]} n={len(moves)}')
    print(' '.join(fmt(mv) for mv in moves))
