import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
import sys
data = open(sys.argv[1],'rb').read()[0x3000:0x4000]   # $9000-$9FFF
def entry(n):
    bit = 9*n; byte = bit >> 3
    w = (data[byte] << 8) | (data[byte+1] if byte+1 < len(data) else 0)
    k = bit & 7
    v = (w >> (16 - 9 - k)) & 0x1FF
    return v
# emulate the Z80 code exactly for cross-check
def z80(n):
    hl = n
    off = hl + (hl >> 3)
    a = data[off]; c = data[off+1]; b = (hl & 7) + 1; cf = 0
    for _ in range(b):
        cf_c = c >> 7; c = (c << 1) & 0xFF | cf; cf = cf_c   # RL C
        cf_a = a >> 7; a = (a << 1) & 0xFF | cf; cf = cf_a   # RLA
    return a, cf
for n in range(3000):
    v = entry(n); a, cf = z80(n)
    assert v == (cf << 8 | a), (n, v, a, cf)
# parse tree
n = 0
maxd = 0; count = 0; leaves = 0; mcount = 0
def parse(depth):
    global n, maxd, count, leaves, mcount
    while True:
        v = entry(n); n += 1; count += 1
        maxd = max(maxd, depth)
        M, L, S, idx = v >> 8, (v >> 7) & 1, (v >> 6) & 1, v & 63
        mcount += M
        if not L: parse(depth + 1)
        else: leaves += 1
        if not S: return
parse(1)
print('entries', count, 'bits used', 9*n, 'of', 8*len(data), 'max depth', maxd, 'leaves', leaves, 'M set', mcount)
print('first entries:', [hex(entry(i)) for i in range(12)])
tail = data[(9*n+7)//8:]
print('tail bytes after tree:', len(tail), 'nonzero:', sum(1 for b in tail if b))
