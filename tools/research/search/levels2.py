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
prev = list(m.sim.memory[0xB400:0xC100])
for i in range(1, 12):
    m.run_script(parse_script('l/3,w10'))
    cur = list(m.sim.memory[0xB400:0xC100])
    d = [(f'{0xB400 + k:04X}', f'{a:02X}->{b:02X}') for k, (a, b) in enumerate(zip(prev, cur)) if a != b and not (0xBD80 <= 0xB400 + k < 0xBE00)]
    print(i, d)
    prev = cur
    if i in (8, 9, 10):
        m.save(SP + rf'\idleP{i - 7}.z80')
    if i <= 7:
        m.save(SP + rf'\idleL{i + 1}.z80')
