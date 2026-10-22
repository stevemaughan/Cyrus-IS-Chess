"""Generate search golden files from the original program.

Each record is one scripted session (AGENTS.md §9.6, oracle.Session) and the
result of every computer move in it:
  state        what the search can read, captured when ComputerMove starts
  root/root_scored  the root move list as generated, and after static scoring
  out          make-sequence hash and counts, move played, root value, ...

Usage:
  python tools/oracle/golden_search.py OUT.jsonl --sessions N [--seed S] [--jobs J] [--levels L:W,...]
"""

import argparse
import json
import multiprocessing as mp
import os
import random
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import chess  # noqa: E402  (python-chess: legal moves and FEN only, never the engine's behaviour)

from oracle import Session, OracleError, START_FEN, open_golden  # noqa: E402

VERSION = 1
LEVEL_NAMES = ['Level 1', 'Level 2', 'Level 3', 'Level 4', 'Level 5', 'Level 6', 'Level 7',
               'Level 8', 'Level P1', 'Level P2', 'Level P3']


def random_playout(rng, plies):
    b = chess.Board()
    moves = []
    for _ in range(plies):
        legal = list(b.legal_moves)
        if not legal:
            break
        mv = rng.choice(legal)
        b.push(mv)
        if b.is_game_over(claim_draw=False):
            b.pop()
            break
        moves.append(mv.uci())
    return b, moves


def pick_level(rng, final, levels=None):
    if levels:
        return rng.choices([lv for lv, _ in levels], weights=[w for _, w in levels])[0]
    if final and rng.random() < 0.12:
        return rng.choice([8, 9, 10])
    return rng.choices(range(8), weights=[3, 3, 3, 3, 3, 1, 1, 1])[0]


def cyrus_uci(board, move):
    """Add the promotion suffix to a move reported by the original (it always queens)."""
    mv = chess.Move.from_uci(move)
    p = board.piece_at(mv.from_square)
    if p and p.piece_type == chess.PAWN and chess.square_rank(mv.to_square) in (0, 7):
        mv.promotion = chess.QUEEN
    return mv


def build_and_run(item):
    """item: a seed, or (seed, levels) with levels a list of (level index, weight)."""
    seed, levels = item if isinstance(item, tuple) else (item, None)
    rng = random.Random(seed)
    kind = rng.choices(['prefix', 'fen', 'game', 'multi'], weights=[4, 3, 2, 1])[0]
    session_ops = []
    goes = []
    s = Session()
    board = chess.Board()
    try:
        if kind == 'fen':
            board, _ = random_playout(rng, rng.randint(6, 70))
            fen = board.fen()
            ok, why = s.load(fen, ())
            session_ops.append({'op': 'load', 'fen': fen, 'moves': []})
            if not ok:
                return {'seed': seed, 'kind': kind, 'session': session_ops, 'rejected': why, 'goes': []}
        else:
            plies = 0 if kind == 'game' and rng.random() < 0.5 else rng.randint(0, 40)
            board, moves = random_playout(rng, plies)
            s.load(None, moves)
            session_ops.append({'op': 'load', 'fen': None, 'moves': moves})
        n_goes = {'prefix': 1, 'fen': 1, 'game': rng.randint(3, 8), 'multi': 2}[kind]
        for g in range(n_goes):
            final = g == n_goes - 1
            level = pick_level(rng, final, levels)
            bcce = rng.randrange(256)
            r_bytes = [rng.randrange(256) for _ in range(16)]
            op = {'op': 'go', 'level': level, 'bcce': bcce, 'r': r_bytes}
            state, out = s.go(bcce, r_bytes, level=level)
            session_ops.append(op)
            rec = {'level': LEVEL_NAMES[level], 'state': state, 'out': out}
            if out['result'] == 'move':
                mv = cyrus_uci(board, out['move'])
                rec['legal'] = mv in board.legal_moves
                board.push(mv)
            goes.append(rec)
            if out['result'] != 'move' or board.is_game_over(claim_draw=False) or final:
                break
            # the opponent replies
            if kind == 'multi':
                replies = []
                for _ in range(2):
                    legal = list(board.legal_moves)
                    if not legal:
                        break
                    mv = rng.choice(legal)
                    board.push(mv)
                    replies.append(mv.uci())
                if board.is_game_over(claim_draw=False) or len(replies) < 2:
                    break
            else:
                legal = list(board.legal_moves)
                mv = rng.choice(legal)
                board.push(mv)
                replies = [mv.uci()]
                if board.is_game_over(claim_draw=False):
                    break
            s.continue_with(replies)
            session_ops.append({'op': 'continue', 'moves': replies})
    except OracleError as e:
        return {'seed': seed, 'kind': kind, 'session': session_ops, 'error': str(e), 'goes': goes}
    return {'seed': seed, 'kind': kind, 'session': session_ops, 'goes': goes}


EPD_LEVELS = (0, 1, 3, 4, 7, 8, 9)       # Levels 1, 2, 4, 5, 8, P1, P2


def run_epd(item):
    """One FEN from an EPD file, searched at one level from a fresh session."""
    idx, fen, name, level = item
    s = Session()
    seed = 900_000_000 + idx * 16 + level
    rng = random.Random(seed)
    ops = []
    try:
        ok, why = s.load(fen, ())
        ops.append({'op': 'load', 'fen': fen, 'moves': []})
        if not ok:
            return {'seed': seed, 'kind': 'epd', 'name': name, 'session': ops, 'rejected': why, 'goes': []}
        bcce, r_bytes = rng.randrange(256), [rng.randrange(256) for _ in range(16)]
        state, out = s.go(bcce, r_bytes, level=level)
        ops.append({'op': 'go', 'level': level, 'bcce': bcce, 'r': r_bytes})
        rec = {'level': LEVEL_NAMES[level], 'state': state, 'out': out}
        if out['result'] == 'move':
            b = chess.Board(fen)
            rec['legal'] = cyrus_uci(b, out['move']) in b.legal_moves
        return {'seed': seed, 'kind': 'epd', 'name': name, 'session': ops, 'goes': [rec]}
    except OracleError as e:
        return {'seed': seed, 'kind': 'epd', 'name': name, 'session': ops, 'error': str(e), 'goes': []}


def run_book(item):
    """One book position (a line of moves from the start), probed with fresh random inputs."""
    idx, moves, k = item
    seed = 800_000_000 + idx * 4 + k
    rng = random.Random(seed)
    s = Session()
    ops = [{'op': 'load', 'fen': None, 'moves': moves}]
    try:
        s.load(None, moves)
        bcce, r_bytes = rng.randrange(256), [rng.randrange(256) for _ in range(16)]
        state, out = s.go(bcce, r_bytes, level=0)
        ops.append({'op': 'go', 'level': 0, 'bcce': bcce, 'r': r_bytes})
        rec = {'level': LEVEL_NAMES[0], 'state': state, 'out': out}
        if out['result'] == 'move':
            b = chess.Board()
            for m in moves:
                b.push_uci(m)
            rec['legal'] = cyrus_uci(b, out['move']) in b.legal_moves
        return {'seed': seed, 'kind': 'book', 'session': ops, 'goes': [rec]}
    except OracleError as e:
        return {'seed': seed, 'kind': 'book', 'session': ops, 'error': str(e), 'goes': []}


def write_results(path, header, results):
    results.sort(key=lambda r: r['seed'])
    with open_golden(path, 'w') as f:
        f.write(json.dumps(header) + '\n')
        for rec in results:
            f.write(json.dumps(rec, separators=(',', ':')) + '\n')
    for r in results:
        if 'error' in r or any(g.get('legal') is False for g in r['goes']):
            print(r['seed'], r['kind'], r.get('name', ''), r.get('error') or
                  'ILLEGAL MOVE ' + r['goes'][0]['out']['move'] + ' after ' + ' '.join(r['session'][0]['moves']))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--sessions', type=int, default=100)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--epd', help='instead of random sessions, search each FEN of this file at several levels')
    ap.add_argument('--book', help='instead of random sessions, probe every book position listed in this file '
                                   '(tools/research/book/book-uci.txt) with two random sequences')
    ap.add_argument('--levels', help='random sessions at these levels only, e.g. "Level 6:272,Level P1:416" '
                                     '(name:weight; every computer move picks one by weight)')
    ap.add_argument('--jobs', type=int, default=max(1, os.cpu_count() - 1))
    args = ap.parse_args()
    levels = None
    if args.levels:
        levels = []
        for part in args.levels.split(','):
            name, _, w = part.partition(':')
            levels.append((LEVEL_NAMES.index(name.strip()), float(w or 1)))
    if args.book:
        lines = [[]]
        with open(args.book) as f:
            for l in f:
                moves, info = l.split('|')
                if 'leaf=0' in info:
                    lines.append(moves.split())
        items = [(i, mv, k) for i, mv in enumerate(lines) for k in range(2)]
        with mp.Pool(args.jobs) as pool:
            results = list(pool.imap_unordered(run_book, items))
        write_results(args.out, {'golden': 'search', 'version': VERSION, 'book': args.book,
                                 'sessions': len(results),
                                 'snapshot': 'reference/snapshots/cyrus48-idle-level1.z80'}, results)
        hits = sum(1 for r in results for g in r['goes'] if g['out'].get('book'))
        print(f'wrote {args.out}: {len(results)} probes, {hits} book moves')
        return
    if args.epd:
        with open(args.epd) as f:
            rows = [(l.split(';')[0].strip(), l.split('"')[1] if '"' in l else '') for l in f if l.strip()]
        items = [(i, fen, name, lv) for i, (fen, name) in enumerate(rows) for lv in EPD_LEVELS]
        with mp.Pool(args.jobs) as pool:
            results = list(pool.imap_unordered(run_epd, items))
        results.sort(key=lambda r: r['seed'])
        with open_golden(args.out, 'w') as f:
            f.write(json.dumps({'golden': 'search', 'version': VERSION, 'epd': args.epd,
                                'sessions': len(results),
                                'snapshot': 'reference/snapshots/cyrus48-idle-level1.z80'}) + '\n')
            for rec in results:
                f.write(json.dumps(rec, separators=(',', ':')) + '\n')
        for r in results:
            if 'error' in r or 'rejected' in r or any(g.get('legal') is False for g in r['goes']):
                print(r['name'], r['session'][-1].get('level') if r['session'] else '',
                      r.get('error') or r.get('rejected') or 'ILLEGAL MOVE ' + r['goes'][0]['out']['move'])
        print(f'wrote {args.out}: {len(results)} searches')
        return
    seeds = [args.seed * 1_000_000 + i for i in range(args.sessions)]
    items = [(sd, levels) for sd in seeds] if levels else seeds
    t0 = time.time()
    done = 0
    results = []
    with mp.Pool(args.jobs) as pool:
        for rec in pool.imap_unordered(build_and_run, items):
            results.append(rec)
            done += 1
            if done % 10 == 0:
                print(f'{done}/{len(seeds)} sessions, {time.time() - t0:.0f}s', flush=True)
    results.sort(key=lambda r: r['seed'])
    with open_golden(args.out, 'w') as f:
        f.write(json.dumps({'golden': 'search', 'version': VERSION, 'seed': args.seed,
                            'sessions': len(results), 'levels': args.levels,
                            'snapshot': 'reference/snapshots/cyrus48-idle-level1.z80'}) + '\n')
        for rec in results:
            f.write(json.dumps(rec, separators=(',', ':')) + '\n')
    goes = sum(len(r['goes']) for r in results)
    errors = sum(1 for r in results if 'error' in r)
    illegal = sum(1 for r in results for g in r['goes'] if g.get('legal') is False)
    print(f'wrote {args.out}: {len(results)} sessions, {goes} computer moves, {errors} errors, '
          f'{illegal} illegal moves played by the original, {time.time() - t0:.0f}s')


if __name__ == '__main__':
    main()
