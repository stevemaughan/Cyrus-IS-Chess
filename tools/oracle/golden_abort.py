"""Generate abort golden files: a key press at the N-th search node.

Takes computer moves from a search golden file that searched at least a few
nodes, and re-runs each from its captured state with a key press injected at
node entry N (the $78BA poll at $7D43), N chosen at random. This is the
behaviour UCI stop / time limits must reproduce (DEV-007).

Record: {"seed", "level", "state", "r", "abort_at_node", "out"}

Usage: python tools/oracle/golden_abort.py SEARCH.jsonl.gz OUT.jsonl.gz [--count N] [--seed S] [--jobs J]
"""

import argparse
import json
import multiprocessing as mp
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from oracle import Oracle, open_golden  # noqa: E402

VERSION = 1


def run(item):
    seed, level, state, r_bytes, node = item
    out = Oracle().search_from_state(state, r_bytes, abort_at_node=node)
    return {'seed': seed, 'level': level, 'state': state, 'r': r_bytes, 'abort_at_node': node, 'out': out}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('search')
    ap.add_argument('out')
    ap.add_argument('--count', type=int, default=400)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--jobs', type=int, default=max(1, os.cpu_count() - 1))
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cands = []
    with open_golden(args.search) as f:
        next(f)
        for line in f:
            rec = json.loads(line)
            gos = [op for op in rec['session'] if op['op'] == 'go']
            for k, g in enumerate(rec['goes']):
                if g['out']['nodes'] >= 4:
                    cands.append((rec['seed'], g['level'], g['state'], gos[k]['r'], g['out']['nodes']))
    rng.shuffle(cands)
    items = [(s, lv, st, r, rng.randint(1, n)) for s, lv, st, r, n in cands[:args.count]]
    with mp.Pool(args.jobs) as pool:
        results = list(pool.imap_unordered(run, items))
    results.sort(key=lambda r: (r['seed'], r['abort_at_node']))
    with open_golden(args.out, 'w') as f:
        f.write(json.dumps({'golden': 'abort', 'version': VERSION, 'seed': args.seed,
                            'source': os.path.basename(args.search), 'count': len(results)}) + '\n')
        for r in results:
            f.write(json.dumps(r, separators=(',', ':')) + '\n')
    changed = sum(1 for r in results if r['out']['result'] != 'move')
    print(f'wrote {args.out}: {len(results)} aborted searches ({changed} without a move)')


if __name__ == '__main__':
    main()
