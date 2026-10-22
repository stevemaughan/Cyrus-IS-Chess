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
m = HMachine(LVL1)
m.run_script(parse_script('e/3,w20'))
for k in ('8', '8', '7', 'ENTER', '7'):
    prev = list(m.sim.memory[0xBC80:0xC100])
    m.run_script(parse_script(f'{k}/2,w6'))
    cur = list(m.sim.memory[0xBC80:0xC100])
    print(k, [(f'{0xBC80 + i:04X}', f'{a:02X}->{b:02X}') for i, (a, b) in enumerate(zip(prev, cur)) if a != b and not 0xBD80 <= 0xBC80 + i < 0xBE00])
