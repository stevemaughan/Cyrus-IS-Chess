import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Set up a position via the original's CHANGE POSITION mode.
Usage: mksetup.py NAME 'Kg1 Ra1 kh8 pg7 ph7' [w|b]
Upper case = White, lower case = Black.
"""
import sys
sys.path.insert(0, HERE)
from hsim import HMachine, parse_script, board
from movein import goto, sqn

SP = WORK
name, spec = sys.argv[1], sys.argv[2].split()
stm = sys.argv[3] if len(sys.argv) > 3 else 'w'
m = HMachine(LVL1)
m.run_script(parse_script('c/2,w20,a/2,w20'))
white = True
for colour in (False, True):
    for item in spec:
        if item[0].isupper() != colour:
            continue
        if white != colour:
            m.run_script(parse_script('t/2,w20'))
            white = colour
        goto(m, sqn(item[1:3]))
        m.run_script(parse_script(f'{item[0].lower()}/2,w15'))
if (stm == 'w') != white:
    m.run_script(parse_script('t/2,w20'))
m.run_script(parse_script('e/2,w2s'))
print(board(m))
print('BD2D', m.m(0xBD2D))
m.save(SP + rf'\{name}.z80')
m.png(SP + rf'\{name}.png')
