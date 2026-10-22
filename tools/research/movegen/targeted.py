import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
import sys
sys.path.insert(0, HERE)
import chess
from compare import load, model, chess_set, to88
from probe import Machine, SNAP, gen, sqname

CASES = [
    # fen, last move uci (or None), flags override
    ('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1', 'd7d5', 0x20),
    ('4k3/8/8/4Pp2/8/8/8/4K3 w - f6 0 1', 'f7f5', 0x20),
    ('4k3/8/8/8/3Pp3/8/8/4K3 b - d3 0 1', 'd2d4', 0x20),
    ('4k3/8/8/8/pP6/8/8/4K3 b - b3 0 1', 'b2b4', 0x20),
    ('4k3/8/8/8/6Pp/8/8/4K3 b - g3 0 1', 'g2g4', 0x20),
    ('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1', None, 0),
    ('r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1', None, 0),
    ('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1', None, 0x80),
    ('r3k2r/8/8/8/8/8/5q2/R3K2R w KQkq - 0 1', None, 0),   # castling through attacked f1? (f2 queen attacks f1,e1)
    ('1r2k3/P6P/8/8/8/8/p6p/1R2K3 w - - 0 1', None, 0),
    ('1r2k3/P6P/8/8/8/8/p6p/1R2K3 b - - 0 1', None, 0),
    ('QQQQ1k2/QQQQ4/8/8/8/8/8/K7 w - - 0 1', None, 0),
    ('3k4/8/8/8/8/8/8/R3K2R w KQ - 0 1', None, 0),
    ('rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2', 'e7e5', 0x00),
    ('rnbqkbnr/ppp1pppp/8/8/3pP3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 2', 'e2e4', 0x20),
    ('7k/8/8/8/8/8/P7/7K w - - 0 1', None, 0),
    ('7k/p7/8/8/8/8/7P/K7 w - - 0 1', None, 0),
    ('7k/p7/8/8/8/8/7P/K7 b - - 0 1', None, 0),
]


def main():
    m = Machine(SNAP)
    mem = m.memory
    for fen, last, fl in CASES:
        b = chess.Board(fen)
        prev = (0, 0, fl)
        if last:
            mv = chess.Move.from_uci(last)
            prev = (to88(mv.from_square), to88(mv.to_square), fl)
        load(mem, b, prev)
        black = b.turn == chess.BLACK
        start, end, hdr, moves = gen(m, black)
        sim = [(x[1], x[2], x[3]) for x in moves]
        mod = model(mem, black)
        cs = chess_set(b)
        ss = {(a, c) for a, c, f in sim if f != 0x10}
        status = 'OK' if sim == mod else 'ORDER-MISMATCH'
        setst = 'set=OK' if cs == ss else f'set: missing {[sqname(a)+sqname(c) for a,c in cs-ss]} extra {[sqname(a)+sqname(c) for a,c in ss-cs]}'
        print(f'{status} {setst} n={len(sim)} hdr={hdr} :: {fen}')
        print('   ', ' '.join(f'{sqname(a)}{sqname(c)}' + (f'/{f:02X}' if f else '') for a, c, f in sim))
        if sim != mod:
            print('  M', ' '.join(f'{sqname(a)}{sqname(c)}' + (f'/{f:02X}' if f else '') for a, c, f in mod))


if __name__ == '__main__':
    main()
