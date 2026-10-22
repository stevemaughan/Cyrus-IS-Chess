import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
import sys, collections
sys.path.insert(0, sys.argv[2])
import chess
illegal = []; dup = collections.Counter(); sib = collections.defaultdict(list)
checks_castle = 0
for line in open(sys.argv[1]):
    moves, flags = line.rstrip('\n').split(' | ')
    mv = moves.split()
    b = chess.Board()
    ok = True
    for i, u in enumerate(mv):
        m = chess.Move.from_uci(u)
        if b.piece_type_at(m.from_square) == chess.PAWN and chess.square_rank(m.to_square) in (0, 7):
            m.promotion = chess.QUEEN
        if m not in b.legal_moves:
            if i == len(mv) - 1: illegal.append((moves, b.fen()))
            ok = False; break
        b.push(m)
    sib[tuple(mv[:-1])].append((mv[-1], flags))
for k, v in sib.items():
    c = collections.Counter(x for x, _ in v)
    for mvx, n in c.items():
        if n > 1: dup[(k, mvx)] = n
print('nodes:', sum(len(v) for v in sib.values()), 'illegal book moves:', len(illegal))
for m, f in illegal[:10]: print('  ILLEGAL:', m, '  in', f)
print('duplicate sibling moves:', len(dup))
for (k, mvx), n in list(dup.items())[:10]: print('  DUP:', ' '.join(k), mvx, n, [f for x, f in sib[k] if x == mvx])
