"""Re-run every evaluation golden record from its captured state in a fresh
machine (proving the state is complete), and cross-check it against the
Python reference model tools/research/eval/evalmodel.py.

Usage: python tools/oracle/verify_eval.py GOLDEN.jsonl[.gz] [--jobs J]
"""

import argparse
import json
import multiprocessing as mp
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
sys.path.append(os.path.join(ROOT, 'tools', 'research', 'eval'))

from oracle import Oracle, open_golden  # noqa: E402
import fuzz  # noqa: E402
from evalmodel import evaluate  # noqa: E402
from golden_eval import outputs  # noqa: E402

_oracle = None


def check(line):
    global _oracle
    if _oracle is None:
        _oracle = Oracle()
        _oracle.base = bytes(_oracle.mem[0x4000:0x10000])
    o = _oracle
    o.mem[0x4000:0x10000] = o.base                 # fresh memory for every record
    rec = json.loads(line)
    ixb = bytes.fromhex(rec['ix'])
    o.load_state(rec['state'])
    model_mem = bytearray(65536)
    model_mem[0xBC00:0xBF00] = bytes(o.mem[0xBC00:0xBF00])
    model_mem[fuzz.IXADDR:fuzz.IXADDR + 4] = ixb
    a, b = fuzz.run_original(o.m, list(ixb))
    rerun_ok = outputs(o, a, b, fuzz.IXADDR) == rec['out']
    ma, mb = evaluate(model_mem, fuzz.IXADDR)
    model_ok = ma == rec['out']['A'] and (not ma or mb == rec['out']['B']) and \
        model_mem[fuzz.IXADDR + 3] == rec['out']['ix3']
    return rec['src'], rerun_ok, model_ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('golden')
    ap.add_argument('--jobs', type=int, default=max(1, os.cpu_count() - 1))
    args = ap.parse_args()
    with open_golden(args.golden) as f:
        next(f)
        lines = f.read().splitlines()
    bad_rerun = bad_model = 0
    with mp.Pool(args.jobs) as pool:
        for src, rerun_ok, model_ok in pool.imap_unordered(check, lines, chunksize=50):
            bad_rerun += not rerun_ok
            bad_model += not model_ok
    print(f'{len(lines)} evaluations: re-run differs {bad_rerun}, Python model differs {bad_model}')
    sys.exit(1 if bad_rerun or bad_model else 0)


if __name__ == '__main__':
    main()
