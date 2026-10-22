"""Self-play stress test (AGENTS.md §6 Phase 4).

Plays many fast games between two instances of the engine, with python-chess
as the referee. Every move is checked for legality; crashes, missing moves,
hangs and time losses are failures. Each side gets a randomly chosen
configuration (UCI clock, movetime, depth, nodes, original levels, Profile,
OwnBook, Ponder), so the whole UCI surface is exercised, including
`position ... moves` continuations, takebacks of a pondered move and checkpoints.

Usage: python tools/scripts/selfplay.py ENGINE.exe --games N [--seed S] [--jobs J] [--log FILE]
"""

import argparse
import json
import multiprocessing as mp
import random
import time

import chess
import chess.engine

MAX_PLIES = 300


def random_config(rng):
    """One side's options and per-move limit."""
    opts = {
        'Profile': rng.choice(['Level 6', 'Level 7', 'Level 8']),
        'OwnBook': rng.random() < 0.8,
        'Seed': rng.randrange(1, 2**31 - 1),
    }
    kind = rng.choices(['clock', 'movetime', 'depth', 'nodes', 'level'], weights=[5, 2, 2, 2, 2])[0]
    cfg = {'kind': kind, 'opts': opts, 'ponder': False}
    if kind == 'clock':
        cfg['base'] = rng.choice([500, 1000, 2000, 5000])
        cfg['inc'] = rng.choice([0, 10, 50, 100])
        cfg['ponder'] = rng.random() < 0.3
        opts['Ponder'] = cfg['ponder']
    elif kind == 'movetime':
        cfg['movetime'] = rng.choice([10, 30, 100])
    elif kind == 'depth':
        cfg['depth'] = rng.randint(1, 6)
    elif kind == 'nodes':
        cfg['nodes'] = rng.choice([500, 5000, 50000, 200000])
    else:
        opts['Level'] = f'Level {rng.randint(1, 8)}'
    return cfg


def opening(rng):
    b = chess.Board()
    for _ in range(rng.randint(0, 8)):
        moves = list(b.legal_moves)
        if not moves:
            break
        b.push(rng.choice(moves))
    if b.is_game_over():
        b = chess.Board()
    return b


def play_game(item):
    exe, seed = item
    rng = random.Random(seed)
    cfgs = [random_config(rng), random_config(rng)]
    board = opening(rng)
    engines = []
    failures = []
    clocks = [cfg.get('base', 0) / 1000.0 for cfg in cfgs]
    try:
        for cfg in cfgs:
            e = chess.engine.SimpleEngine.popen_uci([exe], timeout=30)
            e.configure({k: v for k, v in cfg['opts'].items() if k != 'Ponder'})
            engines.append(e)
        while not board.is_game_over(claim_draw=True) and board.ply() < MAX_PLIES:
            side = 0 if board.turn == chess.WHITE else 1
            cfg = cfgs[side]
            if cfg['kind'] == 'clock':
                limit = chess.engine.Limit(white_clock=clocks[0] if cfgs[0]['kind'] == 'clock' else 60,
                                           black_clock=clocks[1] if cfgs[1]['kind'] == 'clock' else 60,
                                           white_inc=cfgs[0].get('inc', 0) / 1000.0,
                                           black_inc=cfgs[1].get('inc', 0) / 1000.0)
            elif cfg['kind'] == 'movetime':
                limit = chess.engine.Limit(time=cfg['movetime'] / 1000.0)
            elif cfg['kind'] == 'depth':
                limit = chess.engine.Limit(depth=cfg['depth'])
            elif cfg['kind'] == 'nodes':
                limit = chess.engine.Limit(nodes=cfg['nodes'])
            else:
                limit = chess.engine.Limit(time=60)     # fixed level: the clock is ignored
            t0 = time.perf_counter()
            try:
                res = engines[side].play(board, limit, ponder=cfg['ponder'])
            except chess.engine.EngineTerminatedError as e:
                failures.append({'type': 'crash', 'ply': board.ply(), 'fen': board.fen(), 'detail': str(e)})
                break
            except chess.engine.EngineError as e:
                failures.append({'type': 'engine-error', 'ply': board.ply(), 'fen': board.fen(), 'detail': str(e)})
                break
            except TimeoutError as e:
                failures.append({'type': 'hang', 'ply': board.ply(), 'fen': board.fen(), 'detail': str(e)})
                break
            dt = time.perf_counter() - t0
            if cfg['kind'] == 'clock':
                clocks[side] -= dt
                if clocks[side] < 0:
                    failures.append({'type': 'time-loss', 'ply': board.ply(), 'fen': board.fen(),
                                     'detail': f'{dt * 1000:.0f} ms used'})
                    break
                clocks[side] += cfg['inc'] / 1000.0
            if res.move is None:
                failures.append({'type': 'no-move', 'ply': board.ply(), 'fen': board.fen(), 'detail': ''})
                break
            if res.move not in board.legal_moves:
                failures.append({'type': 'illegal', 'ply': board.ply(), 'fen': board.fen(), 'detail': res.move.uci()})
                break
            board.push(res.move)
    finally:
        for e in engines:
            try:
                e.quit()
            except Exception:
                try:
                    e.close()
                except Exception:
                    pass
    result = board.result(claim_draw=True) if board.is_game_over(claim_draw=True) else '*'
    return {'seed': seed, 'plies': board.ply(), 'result': result, 'failures': failures,
            'configs': [{k: v for k, v in c.items() if k != 'opts'} | {'opts': c['opts']} for c in cfgs]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('engine')
    ap.add_argument('--games', type=int, default=100)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--jobs', type=int, default=max(1, mp.cpu_count() // 2 - 1))
    ap.add_argument('--log', default=None)
    args = ap.parse_args()
    items = [(args.engine, args.seed * 1_000_000 + i) for i in range(args.games)]
    t0 = time.time()
    done = 0
    counts = {}
    failures = []
    plies = 0
    log = open(args.log, 'w') if args.log else None
    with mp.Pool(args.jobs) as pool:
        for rec in pool.imap_unordered(play_game, items):
            done += 1
            plies += rec['plies']
            counts[rec['result']] = counts.get(rec['result'], 0) + 1
            for f in rec['failures']:
                failures.append((rec['seed'], f))
                print('FAILURE', rec['seed'], json.dumps(f), flush=True)
            if log:
                log.write(json.dumps(rec) + '\n')
            if done % 50 == 0:
                print(f'{done}/{len(items)} games, {plies} plies, {len(failures)} failures, '
                      f'{time.time() - t0:.0f}s', flush=True)
    print(f'{done} games, {plies} plies, results {counts}, {len(failures)} failures, {time.time() - t0:.0f}s')
    kinds = {}
    for _, f in failures:
        kinds[f['type']] = kinds.get(f['type'], 0) + 1
    print('failure types:', kinds)


if __name__ == '__main__':
    main()
