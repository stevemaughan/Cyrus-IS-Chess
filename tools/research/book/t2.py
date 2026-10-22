import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
import sys
sys.path.insert(0, SCRIPTS)
import book_dump as bd
m = bd.Machine(ENTRY)
m.run_until(bd.IDLE, 50_000_000)
for idx in (13, 9, 14):   # 1.e4 c5 2.Nf3
    L = m.move_list(); s = m.save()
    r = m.play_index(idx, check=True)
    m.restore(s); m.play_index(idx)
    print('idle :', [(hex(f),hex(t),hex(g)) for f,t,g in L][:8])
    print('replay:', [(hex(f),hex(t),hex(g)) for f,t,g in r][:8], len(L), len(r))
