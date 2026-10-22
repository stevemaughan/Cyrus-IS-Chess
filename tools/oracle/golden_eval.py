"""Generate evaluation golden files from the original's $8400.

Two sources:
  fuzz    random positions and variables (tools/research/eval/fuzz.py), with
          the original called directly; includes impossible positions and junk
          in the board's off-board columns
  sample  evaluations captured inside real searches (demo games at Levels 1-3)

Each record: {"src", "state" (oracle.capture_state format), "ix" (the 4-byte
move entry: score, from, to, flags), "out": {A, B, ix3, BCCE, BD4E, BD39, BD3A}}.

Usage: python tools/oracle/golden_eval.py OUT.jsonl [--fuzz N] [--samples N] [--seed S]
"""

import argparse
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
sys.path.append(os.path.join(ROOT, 'tools', 'research', 'eval'))

from oracle import Oracle, EVALUATE, open_golden  # noqa: E402
import fuzz  # noqa: E402

VERSION = 1


def outputs(o, a, b, ix_addr):
    return {'A': a, 'B': b, 'ix3': o.b(ix_addr + 3), 'BCCE': o.b(0xBCCE), 'BD4E': o.b(0xBD4E),
            'BD39': o.b(0xBD39), 'BD3A': o.b(0xBD3A)}


def gen_fuzz(n, seed):
    rng = random.Random(seed)
    o = Oracle()
    base = bytes(o.mem[0xBC00:0xBF00])
    out = []
    for i in range(n):
        placement, opts, ixb = fuzz.random_case(rng)
        o.mem[0xBC00:0xBF00] = base
        fuzz.setup_position(o.mem, placement, opts)
        o.mem[fuzz.IXADDR:fuzz.IXADDR + 4] = bytes(ixb)
        state = o.capture_state()
        a, b = fuzz.run_original(o.m, ixb)
        out.append({'src': 'fuzz', 'state': state, 'ix': bytes(ixb).hex(),
                    'out': outputs(o, a, b, fuzz.IXADDR)})
    return out


def gen_samples(n, seed, every=20):
    """Evaluations inside demo games (CYRUS v CYRUS) at Levels 1-3."""
    rng = random.Random(seed)
    o = Oracle()
    o.set_level(rng.choice([0, 1, 2]))
    out = []
    counter = [0]
    pending = {}

    def h_eval(oo):
        counter[0] += 1
        if counter[0] % every or len(out) + len(pending) >= n:
            return
        sp = oo.regs[12]
        ret = oo.b(sp) + 256 * oo.b(sp + 1)
        ix = oo.regs[8] * 256 + oo.regs[9]
        pending[ret] = {'sp': sp, 'ix_addr': ix, 'ix': bytes(oo.mem[ix:ix + 4]).hex(),
                        'state': oo.capture_state()}
        oo.hooks[ret] = h_ret

    def h_ret(oo):
        p = pending.get(oo.regs[24])
        if p is None or oo.regs[12] != p['sp'] + 2:
            return
        del pending[oo.regs[24]]
        if oo.regs[24] not in pending:
            oo.hooks.pop(oo.regs[24], None)
            oo.hooks[EVALUATE] = h_eval
        out.append({'src': 'sample', 'state': p['state'], 'ix': p['ix'],
                    'out': outputs(oo, oo.regs[0], oo.regs[2], p['ix_addr'])})

    o.hooks[EVALUATE] = h_eval
    o.key_no_wait('d')
    while len(out) < n:
        if o.run(50 * 60) is None and not out and counter[0] == 0:
            raise RuntimeError('demo produced no evaluations')
    return out[:n]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--fuzz', type=int, default=20000)
    ap.add_argument('--samples', type=int, default=10000)
    ap.add_argument('--seed', type=int, default=1)
    args = ap.parse_args()
    recs = gen_fuzz(args.fuzz, args.seed) + gen_samples(args.samples, args.seed)
    with open_golden(args.out, 'w') as f:
        f.write(json.dumps({'golden': 'eval', 'version': VERSION, 'seed': args.seed,
                            'fuzz': args.fuzz, 'samples': args.samples}) + '\n')
        for r in recs:
            f.write(json.dumps(r, separators=(',', ':')) + '\n')
    aborts = sum(1 for r in recs if r['out']['A'] == 0)
    print(f'wrote {args.out}: {len(recs)} evaluations ({aborts} aborts)')


if __name__ == '__main__':
    main()
