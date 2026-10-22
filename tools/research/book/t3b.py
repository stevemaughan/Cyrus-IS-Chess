import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
import sys, collections
sys.path.insert(0, SCRIPTS)
import book_dump as bd

class KM(bd.Machine):
    keys = 0
    def read_port(self, registers, port):
        if port % 2 == 0:
            v = 0xBF
            if self.keys and not (port >> 8) & 0x80:   # half-row 7: SPACE SS M N B
                v &= ~0x04                               # M
            return v
        return 0xFF

m = KM(ENTRY)
m.run_until(bd.IDLE, 50_000_000)
root = m.save()

def computer_move(state, seed):
    m.restore(state)
    mem = m.sim.memory
    mem[0xBCCE] = seed
    ply = mem[0xC001]
    m.keys = 1
    m.run_until({0x676A}, 20_000_000)        # key accepted (leaves wait loop)
    m.keys = 0
    m.run_until(bd.IDLE, 400_000_000)       # computer has moved, back at YOUR MOVE?
    return mem[0xC058 + ply] & 0x7F, mem[0xBCDF]

for label, state, names in (('start', root, None), ):
    pass
L = m.move_list()
names = [bd.describe(m.sim.memory, mv) for mv in L]
c = collections.Counter()
for seed in range(256):
    idx, bcdf = computer_move(root, seed)
    c[names[idx]] += 1
print('White first move from start (256 seeds):', dict(c))

m.restore(root); m.play_index(13); after_e4 = m.save()
L = m.move_list(); names = [bd.describe(m.sim.memory, mv) for mv in L]
c = collections.Counter()
for seed in range(256):
    idx, bcdf = computer_move(after_e4, seed)
    c[names[idx]] += 1
print('Black reply to 1.e4 (256 seeds):', dict(c))
