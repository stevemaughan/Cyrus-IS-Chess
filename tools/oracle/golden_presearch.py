"""Generate pre-search golden files: what $7810 reads and what it leaves.

Re-runs each computer move of a search golden file from its captured state and
captures the state at the call to $7810 (from $7BE1) and the results at its
return ($7BE4): A, B, and the variables it writes.

Record: {"state", "out": {A, B, BD1E, BD2E, BD4A, BD6D, BD2D, root_flags, BCCE}}

Usage: python tools/oracle/golden_presearch.py SEARCH.jsonl.gz OUT.jsonl.gz [--jobs J]
"""

import argparse
import json
import multiprocessing as mp
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from oracle import Oracle, open_golden, state_byte, COMPUTER_MOVE  # noqa: E402

VERSION = 1


def run(state):
    o = Oracle()
    o.load_state(state)
    o.regs[24] = COMPUTER_MOVE
    o.regs[12] = 0xBDF4
    o.regs[26] = 0
    o.poke(0xBCCE, state_byte(state, 0xBCCE))
    got = {}

    def h_entry(oo):
        got['state'] = oo.capture_state()

    def h_ret(oo):
        got['out'] = {'A': oo.regs[0], 'B': oo.regs[2], 'BD1E': oo.b(0xBD1E), 'BD2E': oo.b(0xBD2E),
                      'BD4A': oo.b(0xBD4A), 'BD6D': oo.b(0xBD6D), 'BD2D': oo.b(0xBD2D),
                      'root_flags': oo.b(0xBD5B), 'BCCE': oo.b(0xBCCE)}
        oo.stop_flag = True

    o.hooks = {0x7810: h_entry, 0x7BE4: h_ret}
    r = o.run(50 * 60 * 10, (0x641A, 0x61C1))      # stop early if no search happens
    if r != 'hook':
        return None
    return got


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('search')
    ap.add_argument('out')
    ap.add_argument('--jobs', type=int, default=max(1, os.cpu_count() - 1))
    args = ap.parse_args()
    states = []
    with open_golden(args.search) as f:
        next(f)
        for line in f:
            for g in json.loads(line)['goes']:
                states.append(g['state'])
    with mp.Pool(args.jobs) as pool:
        results = [r for r in pool.imap(run, states, chunksize=20) if r]
    with open_golden(args.out, 'w') as f:
        f.write(json.dumps({'golden': 'presearch', 'version': VERSION,
                            'source': os.path.basename(args.search), 'count': len(results)}) + '\n')
        for r in results:
            f.write(json.dumps(r, separators=(',', ':')) + '\n')
    print(f'wrote {args.out}: {len(results)} pre-search calls')


if __name__ == '__main__':
    main()
