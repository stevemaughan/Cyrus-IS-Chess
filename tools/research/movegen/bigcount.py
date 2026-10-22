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
from compare import load
from probe import Machine, SNAP, gen

m = Machine(SNAP)
for fen in ['R6R/3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/pp1Q4/kBNN1KB1 w - - 0 1',
            '3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/3Q4/1Q4Q1/K6k w - - 0 1',
            'R6R/3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/3Q4/1B1K1N1k w - - 0 1',
            'QQQQQQQQ/8/8/8/8/8/8/K6k w - - 0 1']:
    b = chess.Board(fen)
    n = sum(1 for _ in b.pseudo_legal_moves)
    load(m.memory, b, (0, 0, 0))
    start, end, hdr, moves = gen(m, False)
    print(f'python pseudo={n} cyrus list={len(moves)} header count byte={hdr[1]} end=${end:04X}')
