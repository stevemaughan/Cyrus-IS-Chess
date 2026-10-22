"""UCI robustness stress test (AGENTS.md §6 Phase 4, §10.5).

Drives one engine process through hostile and extreme command sequences and
checks that it stays alive, keeps answering `isready`, sends exactly one
legal `bestmove` per `go` (or 0000 where the spec says so) and respects time.

Usage: python tools/scripts/uci_stress.py ENGINE.exe [--seed S] [--infinite-seconds N]
"""

import argparse
import queue
import random
import subprocess
import threading
import time

import chess

FAILS = []


class Engine:
    def __init__(self, exe):
        self.p = subprocess.Popen([exe], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True, bufsize=1)
        self.q = queue.Queue()
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.p.stdout:
            self.q.put(line.rstrip('\r\n'))
        self.q.put(None)

    def send(self, line):
        self.p.stdin.write(line + '\n')
        self.p.stdin.flush()

    def expect(self, prefix, timeout):
        """Wait for a line starting with `prefix`; returns it (others are kept in self.seen)."""
        end = time.time() + timeout
        self.seen = []
        while time.time() < end:
            try:
                line = self.q.get(timeout=max(0.01, end - time.time()))
            except queue.Empty:
                break
            if line is None:
                return None
            self.seen.append(line)
            if line.startswith(prefix):
                return line
        return None

    def alive(self):
        return self.p.poll() is None

    def close(self):
        try:
            self.send('quit')
            self.p.wait(timeout=5)
        except Exception:
            self.p.kill()


def check(cond, what):
    print(('ok    ' if cond else 'FAIL  ') + what, flush=True)
    if not cond:
        FAILS.append(what)


def ready(e, what):
    e.send('isready')
    check(e.expect('readyok', 10) is not None and e.alive(), f'alive and ready after {what}')


def bestmove(e, board, timeout, what, allow_null=False):
    line = e.expect('bestmove', timeout)
    if line is None:
        check(False, f'{what}: bestmove within {timeout}s')
        return None
    mv = line.split()[1]
    if mv == '0000':
        check(allow_null or not any(board.legal_moves), f'{what}: bestmove 0000 only without legal moves ({line})')
        return None
    ok = chess.Move.from_uci(mv) in board.legal_moves
    check(ok, f'{what}: legal bestmove {mv}')
    return mv


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('engine')
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--infinite-seconds', type=float, default=60)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    e = Engine(args.engine)
    e.send('uci')
    check(e.expect('uciok', 10) is not None, 'uciok')

    # 1. malformed and hostile input
    junk = ['', '   ', 'go depth', 'go wtime', 'go depth x', 'position', 'position fen', 'position fen 8/8',
            'position startpos moves e2e5', 'position startpos moves e2e4 e2e4', 'position startpos moves zz',
            'setoption', 'setoption name', 'setoption name Level value Level 99', 'setoption name Nope value 3',
            'setoption name Seed value -5', 'setoption name Move Overhead value 999999999',
            'xyzzy plugh', '﻿uci', 'uci\r', 'isready\r', 'debug on', 'register later',
            'position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 moves ' + 'e2e4 ' * 10,
            'go searchmoves', 'go searchmoves zz99 depth 2', 'go nodes -1', 'stop', 'ponderhit']
    for j in junk:
        e.send(j)
    e.send('x' * 200_000)            # longer than the input buffer
    for _ in range(200):
        e.send(''.join(rng.choice('abcdefghknpqrxyz0123456789 /-') for _ in range(rng.randint(1, 120))))
    ready(e, 'malformed input')
    # Some junk lines are valid `go` commands: let those searches finish and
    # drain their output so that later checks see only their own answers.
    e.send('stop')
    time.sleep(2)
    e.send('stop')
    ready(e, 'draining')
    time.sleep(1)
    while not e.q.empty():
        e.q.get_nowait()
    e.send('ucinewgame')
    e.send('position startpos')
    e.send('go depth 3')
    bestmove(e, chess.Board(), 30, 'search after malformed input')

    # 2. rejected positions -> bestmove 0000
    for fen in ['4k2P/8/8/8/8/8/8/4K3 w - - 0 1', '8/8/8/8/8/8/8/4K3 w - - 0 1', 'not a fen at all']:
        e.send(f'position fen {fen}')
        e.send('go depth 2')
        line = e.expect('bestmove', 10)
        check(line == 'bestmove 0000', f'rejected position {fen!r} -> bestmove 0000 ({line})')
        check(any('rejected' in s or 'error' in s for s in e.seen), f'rejected position {fen!r} -> info string')

    # 3. very long games through position ... moves
    for n in (300, 600, 1200):
        b = chess.Board()
        while b.ply() < n:
            moves = list(b.legal_moves)
            if not moves or b.is_game_over(claim_draw=False):
                b = chess.Board() if not b.move_stack else b
                break
            b.push(rng.choice(moves))
        e.send('position startpos moves ' + ' '.join(m.uci() for m in b.move_stack))
        e.send('go depth 3')
        bestmove(e, b, 60, f'{b.ply()}-ply game', allow_null=b.is_game_over())

    # 4. the 218-move position and other many-move positions in every mode
    pet = 'R6R/3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/pp1Q4/kBNN1KB1 w - - 0 1'
    q9 = '8/1Q4Q1/4Q3/2k5/Q4Q2/3Q4/1Q1K3Q/3Q4 w - - 0 1'
    for fen in (pet, q9):
        for lvl in ['UCI', 'Level 1', 'Level 4', 'Level 8', 'Level P1', 'Level P3']:
            e.send(f'setoption name Level value {lvl}')
            e.send(f'position fen {fen}')
            e.send('go movetime 300' if lvl == 'UCI' else 'go')
            bestmove(e, chess.Board(fen), 600, f'{fen[:20]} {lvl}', allow_null=lvl.startswith('Level P'))
    e.send('setoption name Level value UCI')

    # 5. stop at once, isready mid-search, ponder flows, tiny clocks
    mid = 'r1bq1rk1/pp2bppp/2n1pn2/3p4/2PP4/2N1PN2/PP3PPP/R2QKB1R w KQ - 0 9'
    for _ in range(20):
        e.send(f'position fen {mid}')
        e.send('go infinite')
        e.send('stop')
        bestmove(e, chess.Board(mid), 5, 'go infinite + immediate stop')
    e.send(f'position fen {mid}')
    e.send('go infinite')
    time.sleep(0.5)
    e.send('isready')
    check(e.expect('readyok', 2) is not None, 'readyok during a search')
    e.send('stop')
    bestmove(e, chess.Board(mid), 5, 'stop after isready')
    e.send('setoption name Ponder value true')
    e.send(f'position fen {mid} moves f1d3')
    e.send('go ponder wtime 5000 btime 5000')
    time.sleep(0.3)
    e.send('ponderhit')
    b = chess.Board(mid)
    b.push_uci('f1d3')
    bestmove(e, b, 15, 'ponder + ponderhit')
    e.send(f'position fen {mid} moves f1d3')
    e.send('go ponder wtime 5000 btime 5000')
    time.sleep(0.3)
    e.send('stop')
    bestmove(e, b, 5, 'ponder + stop (ponder miss)')
    for t in (1, 5, 10, 30):
        e.send(f'position fen {mid}')
        t0 = time.time()
        e.send(f'go wtime {t} btime {t}')
        bestmove(e, chess.Board(mid), 5, f'wtime {t} ms')
        check(time.time() - t0 < 1.0, f'wtime {t} ms answered in {time.time() - t0:.3f}s')

    # 6. searchmoves
    e.send(f'position fen {mid}')
    e.send('go depth 3 searchmoves a2a3')
    mv = bestmove(e, chess.Board(mid), 30, 'searchmoves a2a3')
    check(mv == 'a2a3', f'searchmoves restricts the root ({mv})')
    allm = ' '.join(m.uci() for m in chess.Board(mid).legal_moves)
    e.send(f'go depth 2 searchmoves {allm}')
    bestmove(e, chess.Board(mid), 30, 'searchmoves with every move')

    # 7. problem levels
    e.send('setoption name Level value Level P2')
    e.send('position fen kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1')
    e.send('go')
    mv = bestmove(e, chess.Board('kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1'), 120, 'P2 mate in 2')
    check(mv == 'a1a6', f'P2 finds Morphy\'s 1.Ra6 ({mv})')
    e.send(f'position fen {mid}')
    e.send('go')
    line = e.expect('bestmove', 300)
    check(line == 'bestmove 0000' and any('NO MATE FOUND' in s for s in e.seen), f'P2 without a mate: NO MATE FOUND, bestmove 0000 ({line})')
    e.send('setoption name Level value UCI')

    # 8. long infinite searches: depths the original never reached
    for fen in (chess.STARTING_FEN, mid, '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1'):
        e.send(f'position fen {fen}')
        e.send('go infinite')
        time.sleep(args.infinite_seconds / 3)
        e.send('stop')
        bestmove(e, chess.Board(fen), 30, f'{args.infinite_seconds / 3:.0f}s infinite from {fen[:24]}')
        depths = [int(s.split()[2]) for s in e.seen if s.startswith('info depth')]
        print(f'      deepest depth reached: {max(depths) if depths else 0}')
    ready(e, 'everything')
    e.close()
    print(f'{len(FAILS)} failures')
    raise SystemExit(1 if FAILS else 0)


if __name__ == '__main__':
    main()
