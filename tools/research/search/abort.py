import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Press a key after N makes during a search and observe the abort path.
Usage: abort.py SNAP LEVEL N
"""
import sys
sys.path.insert(0, HERE)
from hsim import HMachine, parse_script, sq

snap, level, N = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
m = HMachine(snap)
for _ in range(30):
    if m.m(0xBCCD) == level - 1:
        break
    m.run_script(parse_script('l/3,w15'))
st = {'make': 0, 'after': 0, 'pass': 0, 'aborted': False}


def mv(mm, a):
    return sq(mm.m(a + 1)) + sq(mm.m(a + 2))


def h_make(mm):
    st['make'] += 1
    if st['aborted']:
        st['after'] += 1
    if st['make'] == N:
        mm.tracer.press(['SPACE'])
        print(f"press at make {N}: pass={st['pass']} ply={mm.m(0xBCA9)} BD29={mv(mm, mm.w(0xBD29))} BD2B={mv(mm, mm.w(0xBD2B))} BCA0={mm.m(0xBCA0):02X}")


def h_abort(mm):
    st['aborted'] = True
    mm.tracer.press([])
    print(f"abort flag set at ply {mm.m(0xBCA9)}")


def h_pass(mm):
    st['pass'] += 1
    print(f"pass {st['pass']} start, aborted={st['aborted']} BD4C={mm.m(0xBD4C):02X} BD29={mv(mm, mm.w(0xBD29))}")


def h_ret(mm):
    print(f"search exit $7E29 ply={mm.m(0xBCA9)} BD29={mv(mm, mm.w(0xBD29))} BD2B={mv(mm, mm.w(0xBD2B))} makes after abort={st['after']}")


def h_done(mm):
    mm.stop_flag = True


m.hooks.update({0x810F: h_make, 0x78C9: h_abort, 0x7BF1: h_pass, 0x7E29: h_ret, 0x618F: h_done})
m.tracer.press(['m'])
m.run_until(3)
m.tracer.press([])
m.run_until(50 * 60 * 15)
print('played', mv(m, m.w(0xBD29)), 'BD4C', f'{m.m(0xBD4C):02X}')
