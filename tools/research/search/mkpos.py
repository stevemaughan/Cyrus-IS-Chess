import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Make idle out-of-book positions: demo at Level 1 for N seconds, then stop the demo."""
import sys
sys.path.insert(0, HERE)
from hsim import HMachine, parse_script, board

SP = WORK
for secs, name in ((130, 'posC'),):
    m = HMachine(LVL1)
    m.run_script(parse_script(f'd,w{secs}s,SPACE/10,w20s'))
    print(name, 'side', m.m(0xBD2D), 'move#', m.m(0xBD49), 'BCDD', m.m(0xBCDD), 'BCDF', m.m(0xBCDF))
    print(board(m))
    m.save(SP + rf'\{name}.z80')
    m.png(SP + rf'\{name}.png')
