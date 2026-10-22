import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""For random positions, make+unmake every generated move via $810F/$821C.
Check: board after make matches python-chess (piece kinds), $BD0D delta, piece-record
updates; unmake restores $BD00-$BD7F and $BE00-$BEFF byte-exactly."""
import random
import sys
sys.path.insert(0, HERE)
import chess
from compare import load, to88
from probe import Machine, SNAP, gen, sqname, call
from skoolkit.simutils import SP, IXh, IXl

KIND = {0: 'k', 9: 'q', 5: 'r', 3: None, 1: 'p'}
VAL = {chess.PAWN: 1, chess.KNIGHT: 3, chess.BISHOP: 3, chess.ROOK: 5, chess.QUEEN: 9, chess.KING: 0}


def kind_of(mem, code):
    rec = 0xBE00 + (code & 0xFB)
    t = mem[rec + 1]
    v = t & 0x0F
    if v == 3:
        return 'b' if t & 0x80 else 'n'
    return {0: 'k', 9: 'q', 5: 'r', 1: 'p'}[v]


def board_matches(mem, b):
    errs = []
    for s in chess.SQUARES:
        code = mem[0xBD00 + to88(s)]
        p = b.piece_at(s)
        if code == 0:
            if p:
                errs.append(f'{chess.square_name(s)} empty, expected {p.symbol()}')
            continue
        k = kind_of(mem, code)
        col = chess.BLACK if code & 0x80 else chess.WHITE
        if not p or p.piece_type != chess.Piece.from_symbol(k).piece_type or p.color != col:
            errs.append(f'{chess.square_name(s)}={k}{"b" if col == chess.BLACK else "w"} expected {p.symbol() if p else "-"}')
        rec = 0xBE00 + (code & 0xFB)
        if mem[rec] != to88(s):
            errs.append(f'record for {chess.square_name(s)} says {mem[rec]:02X}')
    return errs


def main():
    rnd = random.Random(int(sys.argv[1]))
    npos = int(sys.argv[2])
    m = Machine(SNAP)
    mem = m.memory
    r = m.sim.registers
    nmoves = errors = 0
    seen_flags = {}
    for _ in range(npos):
        b = chess.Board()
        for _ in range(rnd.randint(1, 100)):
            ms = list(b.legal_moves)
            if not ms or b.is_game_over():
                break
            b.push(rnd.choice(ms))
        if b.is_game_over() or not b.move_stack:
            continue
        last = b.peek()
        pb = b.copy(); pb.pop()
        fl = 0x20 if pb.piece_type_at(last.from_square) == chess.PAWN and abs(last.to_square - last.from_square) == 16 else 0
        if b.is_check():
            fl |= 0x80
        load(mem, b, (to88(last.from_square), to88(last.to_square), fl))
        black = b.turn == chess.BLACK
        start, end, hdr, moves = gen(m, black)
        for i, mv in enumerate(moves):
            entry = start + 4 + 4 * i
            fr, to, flags = mv[1], mv[2], mv[3]
            # find python-chess move
            pm = None
            for c in b.pseudo_legal_moves:
                if to88(c.from_square) == fr and to88(c.to_square) == to and (c.promotion in (None, chess.QUEEN)):
                    pm = c
            if pm is None:
                print('no python move for', sqname(fr), sqname(to)); errors += 1; continue
            if not b.is_legal(pm):
                continue   # leaves king in check; Cyrus would make it but we can't compare to a legal board
            before_board = list(mem[0xBD00:0xBD80])
            before_pl = list(mem[0xBE00:0xBF00])
            mem[0xBD0D] = 0x00
            mem[entry] = 0          # search sets score 0 before make
            sp0 = r[SP]
            r[IXh], r[IXl] = entry >> 8, entry & 0xFF
            call(m, 0x810F)
            depth = sp0 - r[SP]
            nb = b.copy(); nb.push(pm)
            errs = board_matches(mem, nb)
            cap = b.piece_at(pm.to_square) if not b.is_en_passant(pm) else chess.Piece(chess.PAWN, not b.turn)
            exp = 0
            if cap:
                exp += VAL[cap.piece_type] * (1 if cap.color == chess.WHITE else -1)
            if pm.promotion:
                exp += -8 if b.turn == chess.WHITE else 8
            if (mem[0xBD0D] - exp) & 0xFF:
                errs.append(f'BD0D={mem[0xBD0D]:02X} expected {exp & 0xFF:02X}')
            key = (flags, mem[entry + 3], depth)
            seen_flags[key] = seen_flags.get(key, 0) + 1
            call(m, 0x821C)
            if r[SP] != sp0:
                errs.append(f'SP not restored {r[SP]:04X} vs {sp0:04X}')
            if list(mem[0xBD00:0xBD80]) != before_board[:0x0D] + [mem[0xBD0D]] + before_board[0x0E:] or mem[0xBD0D] != 0:
                diff = [f'{0xBD00 + k:04X}:{before_board[k]:02X}->{mem[0xBD00 + k]:02X}' for k in range(0x80) if before_board[k] != mem[0xBD00 + k]]
                errs.append(f'board not restored {diff}')
            if list(mem[0xBE00:0xBF00]) != before_pl:
                diff = [f'{0xBE00 + k:04X}:{before_pl[k]:02X}->{mem[0xBE00 + k]:02X}' for k in range(0x100) if before_pl[k] != mem[0xBE00 + k]]
                errs.append(f'piece list not restored {diff}')
            nmoves += 1
            if errs:
                errors += 1
                print(b.fen(), pm.uci(), errs)
    print(f'moves {nmoves}, errors {errors}')
    print('flags (gen, after make, stack bytes): count', sorted(seen_flags.items()))


if __name__ == '__main__':
    main()
