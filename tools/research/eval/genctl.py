import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Generate disasm/ctl/50-eval.ctl from an annotation spec.

Spec lines (agentE/eval_annot.txt):
  c $ADDR Title          start a code block
  L $ADDR Label          @label directive
  D $ADDR text           block description (may repeat; joined as paragraphs)
  R $ADDR text           register description line
  N $ADDR text           mid-block comment before the instruction at ADDR
  $ADDR text             instruction comment from ADDR up to the next commented address
  ; ...                  ignored
Continuation lines beginning with '+' append to the previous text.
"""

import re
import sys
from types import SimpleNamespace

from skoolkit.disassembler import Disassembler
from skoolkit.snapshot import Snapshot

START, END = 0x8400, 0x8F2F


def main():
    spec, snap, out = sys.argv[1:4]
    mem = [0] * 16384 + list(Snapshot.get(snap).ram(-1))
    cfg = SimpleNamespace(asm_hex=True, asm_lower=False, defb_size=8, defm_size=66,
                          defw_size=1, handle_rst=False, opcodes='', wrap=False,
                          imaker=lambda a, o, b: SimpleNamespace(address=a, operation=o, bytes=b))
    dis = Disassembler(mem, cfg)
    starts = set()
    a = START
    while a < END:
        n = len(dis.disassemble(a, a + 1, 'h')[0].bytes)
        starts.add(a)
        a += n

    items = []
    for raw in open(spec, encoding='utf-8'):
        line = raw.rstrip('\n')
        if not line.strip() or line.lstrip().startswith(';'):
            continue
        if line.startswith('+'):
            items[-1][2] += ' ' + line[1:].strip()
            continue
        m = re.match(r'^([cLDRNE]) \$([0-9A-F]{4})\s?(.*)$', line)
        if m:
            items.append([m.group(1), int(m.group(2), 16), m.group(3)])
            continue
        m = re.match(r'^\s*\$([0-9A-F]{4})\s+(.*)$', line)
        if m:
            items.append(['I', int(m.group(1), 16), m.group(2)])
            continue
        raise SystemExit(f'bad line: {line}')

    blocks = sorted({a for k, a, _ in items if k == 'c'})
    comments = sorted((a, t) for k, a, t in items if k == 'I')
    caddrs = [a for a, _ in comments]
    for a in caddrs + blocks:
        if a not in starts:
            raise SystemExit(f'${a:04X} is not an instruction boundary')
    # every instruction must be covered by a comment
    covered = set()
    lines = []
    bounds = sorted(set(caddrs) | set(blocks) | {END})
    for a, t in comments:
        nxt = min(b for b in bounds if b > a)
        covered.update(s for s in starts if a <= s < nxt)
    missing = sorted(starts - covered)
    if missing:
        sys.stderr.write('uncommented instructions: ' + ' '.join(f'${x:04X}' for x in missing[:40]) + '\n')

    out_lines = []
    by_addr = {}
    for k, a, t in items:
        by_addr.setdefault(a, []).append((k, t))
    comment_map = dict(comments)
    pos = sorted(set(caddrs) | set(blocks) | {a for k, a, _ in items if k in 'LDRNE'})
    for a in pos:
        entries = by_addr.get(a, [])
        for k, t in entries:
            if k == 'L':
                out_lines.append(f'@ ${a:04X} label={t}')
        for k, t in entries:
            if k == 'c':
                out_lines.append(f'c ${a:04X} {t}')
        for k, t in entries:
            if k in 'DRN':
                out_lines.append(f'{k} ${a:04X} {t}')
        if a in comment_map:
            nxt = min(b for b in bounds if b > a)
            out_lines.append(f'  ${a:04X},{nxt - a} {comment_map[a]}')
        for k, t in entries:
            if k == 'E':
                out_lines.append(f'E ${a:04X} {t}')
    with open(out, 'w', encoding='ascii') as f:
        f.write('\n'.join(out_lines) + '\n')
    print(f'{len(blocks)} blocks, {len(comments)} comments, {len(missing)} uncommented')


if __name__ == '__main__':
    main()
