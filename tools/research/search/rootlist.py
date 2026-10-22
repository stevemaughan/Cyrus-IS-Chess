import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
import sys
sys.path.insert(0, HERE)
from hsim import HMachine, parse_script

files = 'abcdefgh'


def csq(s):  # internal square -> chess name
    return files[s & 7] + str(8 - (s >> 4)) if not s & 0x88 else f'?{s:02X}'


snap, level = sys.argv[1], int(sys.argv[2])
m = HMachine(snap)
for _ in range(30):
    if m.m(0xBCCD) == level - 1:
        break
    m.run_script(parse_script('l/3,w15'))
seen = {}


def h_root(mm):           # after root static scoring in the pass ($7C18)
    n = mm.m(0xB401)
    seen.setdefault('static', [(csq(mm.m(0xB405 + 4 * i)) + csq(mm.m(0xB406 + 4 * i)), f'{mm.m(0xB404 + 4 * i):02X}', f'{mm.m(0xB407 + 4 * i):02X}') for i in range(n)])


def h_cut(mm):
    n = mm.m(0xB401)
    seen.setdefault('afterprune', [(csq(mm.m(0xB405 + 4 * i)) + csq(mm.m(0xB406 + 4 * i)), f'{mm.m(0xB404 + 4 * i):02X}') for i in range(n)])


def h_fea(mm):
    seen['7FEA'] = seen.get('7FEA', 0) + 1


def h_done(mm):
    mm.stop_flag = True


m.hooks = {0x7C18: h_root, 0x7CBA: h_cut, 0x7FEA: h_fea, 0x618F: h_done}
m.tracer.press(['m'])
m.run_until(3)
m.tracer.press([])
m.run_until(50 * 60 * 10)
b = m.w(0xBD29)
print('played', csq(m.m(b + 1)) + csq(m.m(b + 2)), 'BCA0', f'{m.m(0xBCA0):02X}', 'BD0B', m.m(0xBD0B), '7FEA', seen.get('7FEA'))
print('static', seen.get('static'))
print('after prune', seen.get('afterprune'))
