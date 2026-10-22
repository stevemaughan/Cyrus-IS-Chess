import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Compare evalmodel against captured $8400 calls.

Usage: python -I compare.py CAPTURE.jsonl [MAXSHOW]
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from evalmodel import evaluate  # noqa: E402


def main():
    maxshow = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    ok = bad = 0
    shown = 0
    for line in open(sys.argv[1]):
        rec = json.loads(line)
        mem = bytearray(65536)
        mem[0xBC00:0xBF00] = bytes.fromhex(rec['before'])
        ix = rec['ix']
        mem[ix:ix + 4] = bytes(rec['ixb'])
        a, b = evaluate(mem, ix)
        after = bytes.fromhex(rec['after'])
        diffs = []
        if a != rec['a']:
            diffs.append(f"A model={a:02X} real={rec['a']:02X}")
        if b != rec['b'] and rec['a'] != 0:
            diffs.append(f"B model={b:02X} real={rec['b']:02X}")
        if list(mem[ix:ix + 4]) != rec['ixa']:
            diffs.append(f"IX model={bytes(mem[ix:ix+4]).hex()} real={bytes(rec['ixa']).hex()}")
        for i in range(0x300):
            addr = 0xBC00 + i
            if 0xBDA0 <= addr < 0xBE00 or addr in (0xBD3D, 0xBD3E):   # stack, saved SP
                continue
            if mem[addr] != after[i]:
                diffs.append(f"{addr:04X} model={mem[addr]:02X} real={after[i]:02X}")
        if diffs:
            bad += 1
            if shown < maxshow:
                shown += 1
                print(f"call {rec['n']}: " + '; '.join(diffs[:12]))
        else:
            ok += 1
    print(f'{ok} match, {bad} differ')


if __name__ == '__main__':
    main()
