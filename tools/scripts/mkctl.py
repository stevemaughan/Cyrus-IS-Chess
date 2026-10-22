"""Generate a SkoolKit control file for Cyrus IS Chess by recursive descent.

Seeds come from execution maps (every executed address is an instruction
start) plus explicit entry points. Calls to routines that read inline data
after the CALL are handled by the INLINE table, so the data that follows is
not disassembled as code.

Usage:
  python -I mkctl.py SNAPSHOT MAPFILE [MAPFILE...] > base.ctl
"""

import re
import sys
from types import SimpleNamespace

from skoolkit.disassembler import Disassembler
from skoolkit.snapshot import Snapshot

START, END = 0x6000, 0xA000

# Routine address -> inline argument layout following the CALL.
#   ('bytes', n)        n bytes
#   ('str',)            string terminated by a byte with bit 7 set
#   ('bytes+str', n)    n bytes, then such a string
INLINE = {
    0x6FB0: ('bytes', 2),       # BEEP: duration, pitch
    0x6FDD: ('bytes', 2),       # AT: row, column
    0x7415: ('bytes+str', 2),   # PRINT AT row, column; string
    0x73F7: ('str',),           # PRINT at message line
    0x73FE: ('str',),
    0x7405: ('str',),
    0x740E: ('str',),
    0x741A: ('str',),           # PRINT string at current position (attribute $38)
    0x741C: ('str',),           # PRINT string at current position (attribute in A)
}

EXTRA_ENTRIES = [0x6000]


def load(snapshot_file):
    return list(Snapshot.get(snapshot_file).ram(-1)) and ([0] * 16384 + list(Snapshot.get(snapshot_file).ram(-1)))


def make_disassembler(mem):
    cfg = SimpleNamespace(asm_hex=True, asm_lower=False, defb_size=8, defm_size=66,
                          defw_size=1, handle_rst=False, opcodes='', wrap=False,
                          imaker=lambda a, o, b: SimpleNamespace(address=a, operation=o, bytes=b))
    return Disassembler(mem, cfg)


def addr_of(op):
    m = re.search(r'\$([0-9A-F]{4})', op)
    return int(m.group(1), 16) if m else None


def inline_length(mem, addr, rule):
    n = 0
    if rule[0] in ('bytes', 'bytes+str'):
        n = rule[1]
    if rule[0] in ('str', 'bytes+str'):
        while not mem[addr + n] & 0x80:
            n += 1
        n += 1
    return n


def analyse(mem, seeds):
    dis = make_disassembler(mem)
    code = {}        # addr -> (length, operation)
    inline = {}      # addr -> (length, rule)
    entries = set()  # call targets / routine starts
    jump_targets = set()
    problems = []
    todo = list(seeds)
    covered = {}     # byte address -> instruction start
    while todo:
        a = todo.pop()
        while START <= a < END and a not in code:
            if a in covered:
                problems.append(f'${a:04X} decodes inside instruction at ${covered[a]:04X}')
                break
            if a in inline:
                problems.append(f'${a:04X} flows into inline data')
                break
            ins = dis.disassemble(a, a + 1, 'h')[0]
            op = ins.operation
            n = len(ins.bytes)
            code[a] = (n, op)
            for i in range(1, n):
                covered[a + i] = a
            mnem = op.split()[0]
            target = addr_of(op) if mnem in ('JP', 'JR', 'DJNZ', 'CALL') else None
            nxt = a + n
            if mnem == 'CALL':
                entries.add(target)
                todo.append(target)
                rule = INLINE.get(target)
                if rule:
                    ln = inline_length(mem, nxt, rule)
                    inline[nxt] = (ln, rule)
                    nxt += ln
            elif mnem in ('JP', 'JR', 'DJNZ') and target is not None:
                jump_targets.add(target)
                todo.append(target)
                if ',' not in op and mnem != 'DJNZ':
                    break
            elif mnem == 'RST':
                pass
            elif op in ('RET', 'RETI', 'RETN', 'JP (HL)', 'JP (IX)', 'JP (IY)'):
                break
            a = nxt
    return code, inline, entries, jump_targets, problems


def is_text(data):
    return all(32 <= (b & 0x7F) < 127 for b in data)


def write_ctl(mem, code, inline, entries, out):
    out.write('@ $6000 start\n@ $6000 org\n')
    a = START
    in_code = False
    while a < END:
        if a in code:
            if a in entries or not in_code:
                out.write(f'c ${a:04X}\n')
                in_code = True
            a += code[a][0]
        elif a in inline:
            n, rule = inline[a]
            if rule[0] == 'bytes':
                out.write(f'  ${a:04X},{n} Inline arguments\n'.replace('  $', 'B $', 1))
            else:
                k = rule[1] if rule[0] == 'bytes+str' else 0
                if k:
                    out.write(f'B ${a:04X},{k} Inline arguments\n')
                if n - k > 1:
                    out.write(f'T ${a + k:04X},{n - k - 1}\n')
                out.write(f'B ${a + n - 1:04X},1 Last character (bit 7 set)\n')
            a += n
        else:
            b = a
            while b < END and b not in code and b not in inline:
                b += 1
            data = mem[a:b]
            kind = 't' if len(data) >= 4 and is_text(data) else 'b'
            out.write(f'{kind} ${a:04X}\n')
            in_code = False
            a = b


def main():
    mem = [0] * 16384 + list(Snapshot.get(sys.argv[1]).ram(-1))
    seeds = list(EXTRA_ENTRIES)
    for fname in sys.argv[2:]:
        with open(fname) as f:
            for line in f:
                line = line.strip()
                if line:
                    v = int(line[1:], 16)
                    if START <= v < END:
                        seeds.append(v)
    code, inline, entries, jumps, problems = analyse(mem, seeds)
    for p in problems:
        sys.stderr.write(p + '\n')
    # Report unhandled routines that look like they read inline data
    for e in sorted(entries):
        if e in code and e not in INLINE and code[e][1] in ('POP HL', 'POP DE', 'POP BC', 'EX (SP),HL'):
            sys.stderr.write(f'Possible inline-argument routine at ${e:04X}: {code[e][1]}\n')
    nbytes = sum(n for n, _ in code.values())
    sys.stderr.write(f'{len(code)} instructions ({nbytes} bytes), {len(inline)} inline data items, {len(entries)} call targets\n')
    write_ctl(mem, code, inline, entries, sys.stdout)


if __name__ == '__main__':
    main()
