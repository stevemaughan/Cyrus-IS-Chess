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
from skoolkit.graphics import Frame, scr_udgs
from skoolkit.components import get_image_writer

class KM(bd.Machine):
    keys = 0
    def read_port(self, registers, port):
        if port % 2 == 0:
            return 0xBF & ~0x04 if (self.keys and not (port >> 8) & 0x80) else 0xBF
        return 0xFF

m = KM(ENTRY)
m.run_until(bd.IDLE, 50_000_000)
line = 'e2e4 e7e5 g1f3 g8f6 f3e5 d7d6 e5f3 f6e4 d2d4 d6d5 f1b5'.split()
for u in line:
    L = m.move_list()
    idx = [bd.square(f) + bd.square(t) for f, t, _ in L].index(u)
    m.play_index(idx)
mem = m.sim.memory
ply = mem[0xC001]
print('ply', ply, 'BCDF', mem[0xBCDF], 'C006', mem[0xC006])
m.keys = 1; m.run_until({0x676A}, 20_000_000); m.keys = 0
m.run_until(bd.IDLE, 2_000_000_000)
rec = mem[0xC058 + ply]
print('Cyrus played record byte', hex(rec), 'BF00 display record:', [bd.square(x) if x != 0xFF else 'FF' for x in mem[0xBF00 + 2 * ply: 0xBF00 + 2 * ply + 2]])
scr = scr_udgs(mem, 0, 0, 32, 24)
with open(sys.argv[1], 'wb') as f: get_image_writer().write_image([Frame(scr, 2)], f)
