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

SP = WORK
for secs in (145, 152, 158, 163):
    m = HMachine(LVL1)
    m.run_script(parse_script(f'd,w{secs}s,SPACE/10,w20s'))
    m.save(SP + rf'\late{secs}.z80')
    print(secs, 'side', m.m(0xBD2D), 'move', m.m(0xBD49), 'pieces', sum(1 for a in range(0xBD00, 0xBD78) if a & 8 == 0 and m.m(a)))
