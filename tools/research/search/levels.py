import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Read $BCBD (and screen level text) for each press of L from the Level 1 idle snapshot."""
import sys
sys.path.insert(0, HERE)
from hsim import HMachine, parse_script

SP = WORK
m = HMachine(LVL1)
vals = []
for i in range(12):
    vals.append((i, m.m(0xBCBD), m.m(0xBCC2), m.m(0xBCDD)))
    m.run_script(parse_script('l/3,w10'))
print(vals)
