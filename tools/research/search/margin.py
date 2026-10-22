import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Check the root margin ($BD09) and root pruning model against the simulator.
Usage: margin.py SNAP LEVEL
"""
import sys
sys.path.insert(0, HERE)
from hsim import HMachine, parse_script, sq

snap, level = sys.argv[1], int(sys.argv[2])
m = HMachine(snap)
for _ in range(30):
    if m.m(0xBCCD) == level - 1:
        break
    m.run_script(parse_script('l/3,w15'))
st = {}


def moves(mm):
    n = mm.m(0xB401)
    return [(mm.m(0xB404 + 4 * i), mm.m(0xB405 + 4 * i), mm.m(0xB406 + 4 * i), mm.m(0xB407 + 4 * i)) for i in range(n)]


def h_pre(mm):
    st['best'] = mm.reg('D')
    st['before'] = moves(mm)
    st['bd2d'] = mm.m(0xBD2D)
    st['hdr2'] = mm.m(0xB402)


def h_post(mm):
    st['D'] = mm.reg('D')
    st['after'] = moves(mm)


def h_end(mm):
    st['bd09'] = mm.m(0xBD09)
    mm.stop_flag = True


m.hooks.update({0x7C93: h_pre, 0x7C96: h_post, 0x7CBA: h_end})
m.tracer.press(['m'])
m.run_until(3)
m.tracer.press([])
if not m.run_until(50 * 60 * 5):
    print('no margin computation reached'); sys.exit()

# model
best = st['best']
mv = st['before']
cnt = len(mv)
A = max(best, st['hdr2'])
D = 2 * cnt
pruned = []
if A >= 9:
    C = A - 9
    for s, f, t, fl in mv:
        if s < C:
            D -= 1                                   # $80BB
            if ((s - C + 16) & 0xFF) < 0x80:         # JP P keep
                continue
            if fl & 0x04 and not fl & 0xC9:          # $80A7 / $80AB
                pruned.append(sq(f) + sq(t))
D &= 0xFF
D = ((((D >> 2) - 1) & 0xFF) >> 1)
bd2d = st['bd2d']
B = 11 if bd2d & 0x10 else (8 if ((((bd2d >> 1) | (bd2d & 0x80)) - 1) & 0xFF) == 0 else 10)
n = D
while True:
    n -= 1
    if n < 0:
        break
    B -= 1
    if B == 0:
        break
pred = B + 2
actual_pruned = [sq(f) + sq(t) for (s0, f, t, fl), (s1, *_r) in zip(st['before'], st['after']) if s0 and not s1]
print(f'best={best:02X} count={cnt} D_model={D} D_actual_after805F={st["D"]} BD09 pred={pred} actual={st["bd09"]} pruned model={pruned} actual={actual_pruned}')
