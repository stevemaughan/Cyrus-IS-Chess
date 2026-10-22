"""Write tests/positions/edge.epd: positions that stress the edges of the
original (many moves, promotions, en passant, castling rights, mates).

Usage: python tools/oracle/edge_fens.py OUT.epd [--seed S]
"""

import argparse
import random

import chess

HAND = [
    # mate in 1 / mated / stalemate
    ('mate1-backrank', '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1'),
    ('mate2-morphy', 'kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1'),
    ('stalemate-in-1', '7k/5Q2/6K1/8/8/8/8/8 w - - 0 1'),
    ('kqk', '8/8/8/4k3/8/8/8/4KQ2 w - - 0 1'),
    ('krk', '8/8/8/4k3/8/8/8/4K2R w - - 0 1'),
    ('kpk', '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1'),
    ('single-legal-move', '7k/5Q2/8/8/8/8/8/K5r1 w - - 0 1'),
    # castling rights variants
    ('castle-all', 'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1'),
    ('castle-none', 'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w - - 0 1'),
    ('castle-K-only', 'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w K - 0 1'),
    ('castle-through-check', 'r3k2r/ppp2ppp/8/8/8/5b2/PPPP1P1P/R3K2R w KQkq - 0 1'),
    ('castle-out-of-check', 'r3k2r/pppp1ppp/8/8/4r3/8/PPPP1PPP/R3K2R w KQkq - 0 1'),
    # en passant
    ('ep-white', 'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3'),
    ('ep-black', 'rnbqkbnr/pppp1ppp/8/8/3Pp3/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 3'),
    ('ep-pinned', '8/8/8/KPp4r/8/8/8/6k1 w - c6 0 1'),
    # promotions
    ('promote-white', '8/P5k1/8/8/8/8/6K1/8 w - - 0 1'),
    ('promote-capture', '1r5k/P7/8/8/8/8/8/K7 w - - 0 1'),
    ('promote-black', '8/8/8/8/8/1K6/6p1/7k b - - 0 1'),
    # Petrovic (1964): 218 legal moves, the accepted maximum for a legal position.
    # White's 16 pieces fill the original's slots exactly (8 queens in pawn slots).
    ('petrovic-218moves', 'R6R/3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/pp1Q4/kBNN1KB1 w - - 0 1'),
]


def many_moves(rng, queens, tries=20000):
    """Random legal positions with `queens` white queens and many legal moves."""
    best = None
    for _ in range(tries):
        b = chess.Board(None)
        sqs = list(chess.SQUARES)
        rng.shuffle(sqs)
        b.set_piece_at(sqs[0], chess.Piece(chess.KING, chess.WHITE))
        b.set_piece_at(sqs[1], chess.Piece(chess.KING, chess.BLACK))
        for s in sqs[2:2 + queens]:
            b.set_piece_at(s, chess.Piece(chess.QUEEN, chess.WHITE))
        b.turn = chess.WHITE
        if not b.is_valid():
            continue
        n = b.legal_moves.count()
        if best is None or n > best[0]:
            best = (n, b.fen())
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--seed', type=int, default=1)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    rows = list(HAND)
    for q in (5, 6, 7, 8, 9):
        n, fen = many_moves(rng, q)
        rows.append((f'queens{q}-{n}moves', fen))
    with open(args.out, 'w', encoding='ascii', newline='\n') as f:
        for name, fen in rows:
            f.write(f'{fen} ; id "{name}"\n')
    print(f'wrote {len(rows)} positions to {args.out}')


if __name__ == '__main__':
    main()
