"""Generate make/unmake golden files from the original's $810F and $821C.

For (state, move) pairs drawn from a search golden file (every castling, en
passant, capture, double push and promotion, plus random quiet moves), the
captured state is loaded into the original, the move entry is put at $B400 and
make is called directly; the resulting position, the entry, $BD0D and the stack
frames make pushed are recorded. Unmake is then called and the restored
position recorded.

Record: {"state", "entry": 4 bytes hex (score, from, to, flags),
         "after": {"board", "pieces", "entry", "bd0d", "af", "frame_from", "frame_extra"},
         "restored": {"board", "pieces", "bd0d"}}
"af" = (old type << 8) | marker; "frame_from" = (from << 8) | mover code;
"frame_extra" = (square << 8) | code of the captured piece / castling rook, or null.

Usage: python tools/oracle/golden_board.py SEARCH.jsonl.gz EDGE.jsonl.gz OUT.jsonl.gz [--seed S] [--random-per-state K]
"""

import argparse
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from oracle import Oracle, open_golden  # noqa: E402

VERSION = 1
TRAP = 0x5B00            # printer buffer: never executed while we call routines
ENTRY = 0xB400
MAKE, UNMAKE = 0x810F, 0x821C


def call(o, addr):
    regs, mem = o.regs, o.mem
    sp = regs[12] - 2
    mem[sp] = TRAP & 0xFF
    mem[sp + 1] = TRAP >> 8
    regs[12] = sp
    regs[24] = addr
    regs[26] = 0
    if o.run(50, (TRAP,)) != TRAP:
        raise RuntimeError(f'call to ${addr:04X} did not return')


def board_hex(mem):
    return bytes(mem[0xBD00 + r * 16 + f] for r in range(8) for f in range(8)).hex()


def interesting(o, entry):
    """Castling, en passant, captures, double pushes and pawn moves to the last rank."""
    frm, to, flags = entry
    if flags & 0x38:
        return True
    code = o.mem[0xBD00 + frm]
    rtype = o.mem[0xBE00 + ((code & 0xFB) + 1 & 0xFF)]
    if rtype & 0x0F == 1 and (to >> 4) in (0, 7):
        return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('search')
    ap.add_argument('edge')
    ap.add_argument('out')
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--random-per-state', type=int, default=1)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    o = Oracle()
    base = bytes(o.mem[0x4000:0x10000])
    sp0 = 0xBDF4
    recs = []
    for path in (args.search, args.edge):
        with open_golden(path) as f:
            next(f)
            for line in f:
                rec = json.loads(line)
                for go in rec['goes']:
                    root = go['out'].get('root')
                    if not root:
                        continue
                    state = go['state']
                    o.mem[0x4000:0x10000] = base
                    o.load_state(state)
                    picks = [e for e in root if interesting(o, e)]
                    quiet = [e for e in root if not interesting(o, e)]
                    picks += rng.sample(quiet, min(args.random_per_state, len(quiet)))
                    for frm, to, flags in picks:
                        for score in ((0xFF, 0x00) if flags & 0x10 else (0xFF,)):
                            o.mem[0x4000:0x10000] = base
                            o.load_state(state)
                            entry = bytes((score, frm, to, flags))
                            o.mem[ENTRY:ENTRY + 4] = entry
                            o.regs[8], o.regs[9] = ENTRY >> 8, ENTRY & 0xFF
                            o.regs[12] = sp0
                            call(o, MAKE)
                            sp = o.regs[12]
                            frames = [o.mem[a] | o.mem[a + 1] << 8 for a in range(sp, sp0, 2)]
                            if len(frames) not in (2, 3):
                                raise RuntimeError(f'unexpected frame count {len(frames)}')
                            after = {
                                'board': board_hex(o.mem),
                                'pieces': bytes(o.mem[0xBE00:0xBF00]).hex(),
                                'entry': bytes(o.mem[ENTRY:ENTRY + 4]).hex(),
                                'bd0d': o.mem[0xBD0D],
                                'af': frames[0],
                                'frame_from': frames[-1],
                                'frame_extra': frames[1] if len(frames) == 3 else None,
                            }
                            call(o, UNMAKE)
                            if o.regs[12] != sp0:
                                raise RuntimeError('unmake did not restore SP')
                            restored = {
                                'board': board_hex(o.mem),
                                'pieces': bytes(o.mem[0xBE00:0xBF00]).hex(),
                                'bd0d': o.mem[0xBD0D],
                            }
                            recs.append({'state': state, 'entry': entry.hex(), 'after': after, 'restored': restored})
    with open_golden(args.out, 'w') as f:
        f.write(json.dumps({'golden': 'board', 'version': VERSION, 'seed': args.seed, 'count': len(recs)}) + '\n')
        for r in recs:
            f.write(json.dumps(r, separators=(',', ':')) + '\n')
    kinds = {}
    for r in recs:
        m = r['after']['af'] & 0xFF
        kinds[m] = kinds.get(m, 0) + 1
    print(f'wrote {args.out}: {len(recs)} makes; markers ' +
          ', '.join(f'${k:02X}: {v}' for k, v in sorted(kinds.items())))


if __name__ == '__main__':
    main()
