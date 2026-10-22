import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Build a repetition position: E mode, Nf3 Nf6 Ng1 Ng8 Nf3 Nf6 Ng1, then idle (Black to move)."""
import sys
sys.path.insert(0, HERE)
from hsim import HMachine, parse_script, board
from movein import enter

SP = WORK
m = HMachine(LVL1)
print('cursor', hex(m.m(0xBCCA)))
m.run_script(parse_script('e/3,w20'))
for mv in ('g1f3', 'g8f6', 'f3g1', 'f6g8', 'g1f3', 'g8f6', 'f3g1'):
    enter(m, mv)
    print(mv, 'BD5E', m.m(0xBD5E), 'BD5C', hex(m.w(0xBD5C)), 'C001', m.w(0xC001))
print(board(m))
m.save(SP + r'\posRep.z80')
m.png(SP + r'\posRep.png')
