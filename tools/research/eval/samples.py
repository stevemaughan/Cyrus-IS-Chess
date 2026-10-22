import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Pick diverse eval samples from a capture file and print a markdown table."""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import evalmodel  # noqa: E402

NAMES = 'KQRRBBNN'
FILES = 'abcdefgh'


def sqname(s):
    return FILES[s & 7] + str((s >> 4) + 1) if not s & 0x88 else f'${s:02X}'


def fen(mem):
    rows = []
    for r in range(7, -1, -1):
        row, empty = '', 0
        for f in range(8):
            code = mem[0xBD00 + r * 16 + f]
            if not code:
                empty += 1
                continue
            if empty:
                row += str(empty)
                empty = 0
            slot = (code & 0x78) >> 3
            typ = mem[0xBE00 + (code & 0xFB) + 1]
            if slot >= 8:
                v = typ & 0x0F
                p = {1: 'P', 9: 'Q', 5: 'R', 3: 'B' if typ & 0x80 else 'N'}.get(v, '?')
            else:
                p = NAMES[slot]
            row += p if not code & 0x80 else p.lower()
        if empty:
            row += str(empty)
        rows.append(row)
    stm = 'w' if mem[0xBD2D] & 1 else 'b'
    return '/'.join(rows) + ' ' + stm


def slots(mem):
    out = []
    for base, c in ((0x00, 'W'), (0x80, 'B')):
        parts = []
        for i in range(16):
            rec = 0xBE00 + base + 8 * i
            sq, typ = mem[rec], mem[rec + 1]
            if sq & 0x80:
                parts.append('-')
                continue
            s = sqname(sq)
            default = {0: None, 1: 0x09, 2: 0x05, 3: 0x05, 4: 0x83, 5: 0x83, 6: 0x03, 7: 0x03}.get(i)
            if i == 0 or (i < 8 and typ != default) or (i >= 8 and typ & 0x0F != 1):
                s += f':{typ:02X}'
            parts.append(s)
        out.append(c + ' ' + ','.join(parts[:8]) + ' / ' + ','.join(parts[8:]))
    return '; '.join(out)


def offboard(mem):
    out = []
    for r in range(8):
        for f in (8, 15):
            a = 0xBD00 + r * 16 + f
            if mem[a]:
                out.append(f'{a:04X}={mem[a]:02X}')
    if mem[0xBDFF]:
        out.append(f'BDFF={mem[0xBDFF]:02X}')
    return ' '.join(out)


class Probe(evalmodel.Eval):
    def __init__(self, *a):
        super().__init__(*a)
        self.tags = set()

    def pin(self, r6):
        self.tags.add('pin')
        super().pin(r6)

    def king_check(self, B, double_ap):
        self.tags.add('check2' if self.F & 0x40 else 'check')
        super().king_check(B, double_ap)

    def see(self, *a):
        self.tags.add('see')
        super().see(*a)


def main():
    picked = {}
    for line in open(sys.argv[1]):
        rec = json.loads(line)
        mem = bytearray(65536)
        mem[0xBC00:0xBF00] = bytes.fromhex(rec['before'])
        ix = rec['ix']
        mem[ix:ix + 4] = bytes(rec['ixb'])
        orig = bytes(mem)
        ev = Probe(mem, ix)
        a = ev.run()
        assert a == rec['a']
        phase = orig[0xBD2D] & 0x1E
        keys = [f'phase{phase:02X}']
        if a == 0:
            keys.append('abort')
        if a in (2, 0xFC):
            keys.append('sat')
        keys += sorted(ev.tags - {'see'})
        if orig[0xBD49] == 1:
            keys.append('move1')
        ix3 = mem[ix + 3]
        for bit in (1, 2, 6, 7):
            if ix3 & (1 << bit) and not rec['ixb'][3] & (1 << bit):
                keys.append(f'ixbit{bit}')
        if offboard(orig):
            keys.append('junk')
        for k in keys:
            picked.setdefault(k, (rec, orig, mem, a, ev.B))
        if rec['n'] % 20000 < 23 and rec['n'] > 1000:
            picked.setdefault(f'z-spaced{rec["n"]:06d}', (rec, orig, mem, a, ev.B))
    seen = set()
    print('| # | FEN (board, side to move) | piece-list slots (square[:type]) | move IX+1→IX+2, IX+3 in→out | BD2D BD0D BD4A BD1E BD6D BD49 BCCE | off-board bytes | A | B |')
    print('|---|---|---|---|---|---|---|---|')
    n = 0
    for k in sorted(picked):
        rec, orig, mem, a, b = picked[k]
        if rec['n'] in seen:
            continue
        seen.add(rec['n'])
        n += 1
        ixb, ixa = rec['ixb'], rec['ixa']
        v = ' '.join(f'{orig[x]:02X}' for x in (0xBD2D, 0xBD0D, 0xBD4A, 0xBD1E, 0xBD6D, 0xBD49, 0xBCCE))
        print(f'| {n} ({k}) | `{fen(orig)}` | {slots(orig)} | {sqname(ixb[1])}→{sqname(ixb[2])} {ixb[3]:02X}→{ixa[3]:02X} '
              f'| {v} | {offboard(orig) or "-"} | {a:02X} | {b:02X} |')


if __name__ == '__main__':
    main()
