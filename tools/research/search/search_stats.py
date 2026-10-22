import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Run one computer move from an idle snapshot at a given level and collect search statistics.
Usage: search_stats.py SNAP LEVEL(1-11) [--trace]
"""
import sys
import collections
sys.path.insert(0, HERE)
from hsim import HMachine, parse_script, sq, board

snap, level = sys.argv[1], int(sys.argv[2])
trace = '--trace' in sys.argv
m = HMachine(snap)
for _ in range(30):
    if m.m(0xBCCD) == level - 1:
        break
    m.run_script(parse_script('l/3,w15'))
assert m.m(0xBCCD) == level - 1, m.m(0xBCCD)

st = collections.Counter()
plies = collections.Counter()
passes = []
minsp = [0xFFFF]
listmax = [0]


def h_make(mm):
    st['make'] += 1
    plies[mm.m(0xBCA9)] += 1
    minsp[0] = min(minsp[0], mm.reg('SP'))
    if trace and st['make'] < 400:
        ix = mm.reg('IX')
        print(f"make ply={mm.m(0xBCA9)} {sq(mm.m(ix+1))}{sq(mm.m(ix+2))} fl={mm.m(ix+3):02X} +0={mm.m(ix):02X}")


def h_eval(mm):
    st['eval'] += 1


def h_node(mm):
    st['node'] += 1


def h_gen(mm):
    st['gen'] += 1


def h_gen_end(mm):
    # $79A6: DE = end pointer of list
    listmax[0] = max(listmax[0], mm.reg('DE'))


def h_poll(mm):
    st['poll'] += 1


def h_pass(mm):
    passes.append(dict(BCBD=mm.m(0xBCBD), BD6E=mm.m(0xBD6E), BCCE=mm.m(0xBCCE), make=st['make'], ev=st['eval']))


def h_params(mm):
    # at $7C83, BCAA set; BD09 and BDF6 set
    passes[-1].update(BCAA=mm.m(0xBCAA), BD09=mm.m(0xBD09), BDF6=mm.m(0xBDF6))


def h_after(mm):
    passes[-1].update(BD09_final=mm.m(0xBD09))


def h_done(mm):
    mm.stop_flag = True


m.hooks.update({0x810F: h_make, 0x8400: h_eval, 0x7D43: h_node, 0x78CE: h_gen, 0x79A6: h_gen_end,
                0x6734: h_poll, 0x7BF1: h_pass, 0x7C83: h_params, 0x7CBA: h_after, 0x618F: h_done})
m.tracer.press(['m'])
m.run_until(3)
m.tracer.press([])
t0 = m.seconds()
ok = m.run_until(50 * 60 * 15)
best = m.w(0xBD29)
print(f'level {level}: done={ok} emulated {m.seconds() - t0:.1f}s  move {sq(m.m(best+1))}{sq(m.m(best+2))}  BCA0={m.m(0xBCA0):02X}')
print(' stats', dict(st), 'plies', dict(sorted(plies.items())), f'minSP={minsp[0]:04X} listmax={listmax[0]:04X}')
for p in passes:
    print(' pass', p)
