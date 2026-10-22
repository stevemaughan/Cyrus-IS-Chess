import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
import sys
data = open(sys.argv[1],'rb').read()[0x3000:0x4000] + b'\0\0'
def entry(n):
    bit = 9*n; byte = bit >> 3
    w = (data[byte] << 8) | data[byte+1]
    return (w >> (7 - (bit & 7))) & 0x1FF
n = 2685
trees = 0
while 9*n < 8*4096 - 9:
    start = n; cnt = 0; maxd = 0; ok = True
    def parse(d):
        global n, cnt, maxd, ok
        while ok:
            if 9*n >= 8*4096 - 9: ok = False; return
            v = entry(n); n += 1; cnt += 1; maxd = max(maxd, d)
            if not (v >> 7) & 1: parse(d+1)
            if not (v >> 6) & 1: return
    parse(1); trees += 1
    print(f'tree at entry {start} (bit {9*start}, byte ${0x9000 + 9*start//8:04X}): {cnt} entries, depth {maxd}, complete={ok}')
    if trees > 8: break
