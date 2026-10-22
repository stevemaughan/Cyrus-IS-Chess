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

class KM(bd.Machine):
    keys = 0
    def read_port(self, registers, port):
        if port % 2 == 0:
            return 0xBF & ~0x04 if (self.keys and not (port >> 8) & 0x80) else 0xBF
        return 0xFF

m = KM(ENTRY)
m.run_until(bd.IDLE, 50_000_000)
mem0 = m.sim.memory
root = m.save()
m.play_index(13); after_e4 = m.save()

def model(mem, plies, bcce, rvals):
    """Python model of $7AC7 (book probe). Returns chosen index or None, and new BCDF."""
    rv = iter(rvals)
    def rnd():
        nonlocal bcce
        a = (bcce ^ next(rv)) & 0xFF
        bcce = a >> 1
        return bcce
    def entry(n):
        return bd.book_entry(mem, n)          # (A, CF)
    def read(n, de):                           # $7B57
        a, cf = entry(n)
        if a & 0x80: de -= 1
        if a & 0x40: de += 1
        return a, cf, de
    def skip(hl):                              # $7B4C: returns hl of next sibling, its (A, CF)
        de = -1
        while True:
            a, cf, de = read(hl, de); hl += 1
            if de < 0: break
        a, cf, de = read(hl, de)
        return hl, a, cf
    b = rnd()
    hl = 0; bcdf = 0
    for i in range(plies + 1):
        bcdf += 1
        if i == plies: break
        c = mem[0xC058 + i] & 0x7F
        a, cf, _ = read(hl, 0)
        while True:
            bb = a
            if (a & 0xBF) == c: break          # match
            if not bb & 0x40: return None, 0xFF
            hl, a, cf = skip(hl)
        hl += 1
    b = rnd()
    a, cf, _ = read(hl, 0); c = a
    if a & 0x40 and not ((2 | cf) & b):
        while True:
            saved = hl
            b = rnd()
            hl, a, cf = skip(hl)
            if cf:
                hl = saved; a, _, _ = read(hl, 0); c = a; break
            c = a
            if not a & 0x40: break
            if not (b & 1): break              # RR B: CF = bit 0 of B; NC ? take
    if not c & 0x80: bcdf = 0
    return c & 0x3F, bcdf

def run(state, seed):
    m.restore(state)
    mem = m.sim.memory; mem[0xBCCE] = seed
    ply = mem[0xC001]
    snap_mem = list(mem)
    m.keys = 1; m.run_until({0x676A}, 20_000_000); m.keys = 0
    rvals = []
    bcce_at_probe = None
    while True:
        pc = m.run_until({0x7AD1, 0x7B8B} | set(bd.IDLE), 400_000_000)
        if pc == 0x7AD1 and bcce_at_probe is None:
            bcce_at_probe = mem[0xBCCE]
        elif pc == 0x7B8B:
            rvals.append(m.sim.registers[0])
        else:
            break
    return mem[0xC058 + ply] & 0x7F, rvals, bcce_at_probe, ply

bad = 0; total = 0
for state in (root, after_e4):
    m.restore(state); recmem = list(m.sim.memory)
    for seed in range(256):
        got, rvals, bcce0, ply = run(state, seed)
        exp, _ = model(recmem, ply, bcce0, rvals)
        total += 1
        if exp != got:
            bad += 1
            if bad < 5: print('MISMATCH seed', seed, 'got', got, 'model', exp, 'r', rvals)
print(f'model agreed on {total - bad}/{total} probes; R values per probe e.g. {rvals}')
