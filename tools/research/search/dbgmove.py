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
from movein import goto, sqn

SP = WORK
m = HMachine(LVL1)
m.run_script(parse_script('e/3,w20'))
st = lambda tag: print(tag, 'cur', hex(m.m(0xBCCA)), 'BCCB', hex(m.m(0xBCCB)), 'g1', hex(m.m(0xBD06)), 'f3', hex(m.m(0xBD25)))
st('start')
goto(m, sqn('g1'))
st('at g1')
m.run_script(parse_script('ENTER/2,w10'))
st('enter1')
goto(m, sqn('f3'))
st('at f3')
m.run_script(parse_script('ENTER/2,w2s'))
st('enter2')
m.run_script(parse_script('w5s'))
st('later')
for r in range(8):
    print(' '.join(f'{m.m(0xBD00 + r * 16 + f):02X}' for f in range(16)))
print('piece list N g1:', [hex(m.m(0xBE38 + i)) for i in range(8)])
m.png(SP + r'\dbg.png')
