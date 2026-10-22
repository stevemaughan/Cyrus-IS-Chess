"""Check that captured states are complete.

Every computer move in a search golden file is re-run in a fresh copy of the
original, entering ComputerMove directly from the captured state (no user
interface, no history). Identical results prove that the state records
everything the search depends on, so a port that rebuilds that state and
reproduces the search must play identically.

Usage: python tools/oracle/verify_state.py GOLDEN.jsonl [--jobs J]
"""

import argparse
import json
import multiprocessing as mp
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from oracle import Oracle, open_golden  # noqa: E402

FIELDS = ('result', 'move', 'make_sha256', 'makes', 'evals', 'nodes', 'BCA0', 'BD0C',
          'r_used', 'book', 'root_count', 'root', 'root_scored', 'bcce_after')


def check(item):
    seed, k, go, r_bytes = item
    o = Oracle()
    out = o.search_from_state(go['state'], r_bytes)
    diffs = [f for f in FIELDS if out.get(f) != go['out'].get(f)]
    return seed, k, diffs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('golden')
    ap.add_argument('--jobs', type=int, default=max(1, os.cpu_count() - 1))
    args = ap.parse_args()
    items = []
    with open_golden(args.golden) as f:
        next(f)
        for line in f:
            rec = json.loads(line)
            gos = [op for op in rec['session'] if op['op'] == 'go']
            for k, go in enumerate(rec['goes']):
                items.append((rec['seed'], k, go, gos[k]['r']))
    bad = 0
    with mp.Pool(args.jobs) as pool:
        for seed, k, diffs in pool.imap_unordered(check, items):
            if diffs:
                bad += 1
                print(f'seed {seed} move {k}: differs in {diffs}')
    print(f'{len(items)} computer moves re-run from captured state: {len(items) - bad} identical, {bad} different')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
