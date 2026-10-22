"""Generate opening-book probe golden files (unit 3.11).

The book probe ($7AC7) runs inside the search driver ($7BF1) after the root
list has been regenerated and statically scored again, so the root lists in
the search golden files are not exactly what it reads. This re-runs computer
moves from captured states (book.jsonl.gz and search.jsonl.gz) in the original,
captures everything the probe reads when it is entered, and its results when it
returns to the driver ($7C21), then stops.

Record:
  {"src", "seed", "k",
   "r": [bytes substituted for LD A,R, starting with the probe's first read],
   "in":  {"list": hex $B400..slot(2) (header + entries), "bcdf", "bcce",
           "plies" ($C001), "start_move" ($C006), "record" hex from $C058 incl. $FF},
   "out": {"hit" (Z flag), "bd29", "bcdf", "bcce", "r_used"}}

Usage: python tools/oracle/golden_bookprobe.py OUT.jsonl.gz [--jobs J]
"""

import argparse
import json
import multiprocessing as mp
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

from oracle import (Oracle, open_golden, COMPUTER_MOVE, COMPUTER_MOVE_PLAY,  # noqa: E402
                    GAME_OVER_NO_MOVES, CHANGE_POSITION, GAME_OVER_DRAW, PC)

VERSION = 1
PROBE = 0x7AC7
PROBE_RETURN = 0x7C21        # the only caller: CALL $7AC7 at $7C1E


def run(item):
    src, seed, k, state, r_bytes = item
    o = Oracle()
    o.load_state(state)
    o.regs[PC] = COMPUTER_MOVE
    o.regs[12] = 0xBDF4
    o.regs[26] = 0
    o.r_bytes = list(r_bytes)
    o.r_used = 0
    rec = {}

    def h_in(oo):
        end = oo.w(0xBCAD)
        rec['r_offset'] = oo.r_used
        rec['in'] = {
            'list': bytes(oo.mem[0xB400:end]).hex(),
            'bcdf': oo.b(0xBCDF), 'bcce': oo.b(0xBCCE),
            'plies': oo.w(0xC001), 'start_move': oo.b(0xC006),
            'record': bytes(oo.mem[0xC058:0xC058 + oo.w(0xC001) + 1]).hex(),
        }

    def h_out(oo):
        rec['out'] = {'hit': bool(oo.regs[1] & 0x40), 'bd29': oo.w(0xBD29), 'bcdf': oo.b(0xBCDF),
                      'bcce': oo.b(0xBCCE), 'r_used': oo.r_used - rec['r_offset']}
        oo.stop_flag = True

    o.hooks[PROBE] = h_in
    o.hooks[PROBE_RETURN] = h_out
    r = o.run(50 * 60 * 60, (COMPUTER_MOVE_PLAY, GAME_OVER_NO_MOVES, CHANGE_POSITION, GAME_OVER_DRAW))
    if r != 'hook':
        return None                  # the probe was not reached (no legal move, next-best ...)
    off = rec.pop('r_offset')
    return {'src': src, 'seed': seed, 'k': k, 'r': list(r_bytes[off:off + 16]), **rec}


def items_from(path, src):
    with open_golden(path) as f:
        next(f)
        for line in f:
            rec = json.loads(line)
            gos = [op for op in rec['session'] if op['op'] == 'go']
            for k, g in enumerate(rec['goes']):
                yield (src, rec['seed'], k, g['state'], gos[k]['r'])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--jobs', type=int, default=max(1, os.cpu_count() - 1))
    args = ap.parse_args()
    gdir = os.path.join(ROOT, 'tests', 'golden')
    items = list(items_from(os.path.join(gdir, 'book.jsonl.gz'), 'book')) + \
        list(items_from(os.path.join(gdir, 'search.jsonl.gz'), 'search'))
    with mp.Pool(args.jobs) as pool:
        results = [r for r in pool.imap(run, items, chunksize=20) if r is not None]
    with open_golden(args.out, 'w') as f:
        f.write(json.dumps({'golden': 'bookprobe', 'version': VERSION, 'count': len(results)}) + '\n')
        for r in results:
            f.write(json.dumps(r, separators=(',', ':')) + '\n')
    hits = sum(1 for r in results if r['out']['hit'])
    walks = sum(1 for r in results if r['in']['bcdf'] == 0 and r['in']['start_move'] == 1)
    print(f'wrote {args.out}: {len(results)} probes, {walks} walked the book, {hits} book moves')


if __name__ == '__main__':
    main()
