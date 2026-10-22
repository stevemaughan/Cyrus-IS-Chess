import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Helpers to enter moves through the original UI with the cursor keys."""
import sys
sys.path.insert(0, HERE)
from hsim import parse_script


def sqn(s):
    return (int(s[1]) - 1) * 16 + 'abcdefgh'.index(s[0])


def goto(m, square):
    target = square ^ 0x70          # cursor $BCCA holds the internal square (rank 8 = row 0)
    for _ in range(40):
        cur = m.m(0xBCCA)
        if cur == target:
            return
        cf, cr = cur & 7, cur >> 4
        tf, tr = target & 7, target >> 4
        if cf < tf:
            k = '8'
        elif cf > tf:
            k = '5'
        elif cr < tr:
            k = '6'                     # key 6 increases the cursor rank
        else:
            k = '7'
        m.run_script(parse_script(f'{k}/2,w4'))
    raise RuntimeError(f'cursor stuck at {m.m(0xBCCA):02X}, target {target:02X}')


def enter(m, mv):
    f, t = sqn(mv[:2]) ^ 0x70, sqn(mv[2:4]) ^ 0x70     # internal squares: rank 8 is row 0
    piece = m.m(0xBD00 + f)
    goto(m, f ^ 0x70)
    m.run_script(parse_script('ENTER/2,w10'))
    goto(m, t ^ 0x70)
    m.run_script(parse_script('ENTER/2,w2s'))
    if m.m(0xBD00 + f) != 0 or m.m(0xBD00 + t) != piece:
        raise RuntimeError(f'move {mv} not accepted')
