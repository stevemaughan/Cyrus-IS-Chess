import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Compare Cyrus's $78CE output against (a) a Python model of the documented
algorithm (exact order) and (b) python-chess pseudo-legal moves (as sets)."""
import random
import sys
sys.path.insert(0, HERE)
import chess
from probe import Machine, SNAP, gen, sqname, fmt, TYPE, W6

KDIRS = [0x0F, 0x11, 0xEF, 0xF1, 0x01, 0xFF, 0x10, 0xF0]
RDIRS = [0x01, 0xFF, 0x10, 0xF0]
BDIRS = [0x0F, 0x11, 0xEF, 0xF1]
NDIRS = [0x0E, 0x12, 0x1F, 0x21, 0xF2, 0xEE, 0xE1, 0xDF]


def to88(s):
    return (s >> 3) * 16 + (s & 7)


def load(mem, board, prev):
    """Poke a python-chess board into Cyrus memory. prev = (from88, to88, flags) of the last move."""
    for r in range(8):
        for f in range(8):
            mem[0xBD00 + r * 16 + f] = 0
    for base in (0xBE00, 0xBE80):
        for i in range(16):
            mem[base + i * 8:base + i * 8 + 8] = [0x80, 0, 0, 0, 0, 0, 0, 0]
    for colour, base, cbit in ((chess.WHITE, 0xBE00, 0), (chess.BLACK, 0xBE80, 0x80)):
        home = 0 if colour == chess.WHITE else 7
        free = list(range(8, 16))
        used = set()
        pieces = sorted(board.pieces(chess.KING, colour)) + sorted(board.pieces(chess.QUEEN, colour)) + \
            sorted(board.pieces(chess.ROOK, colour), key=lambda s: (s not in (chess.square(0, home), chess.square(7, home)), s)) + \
            sorted(board.pieces(chess.BISHOP, colour)) + sorted(board.pieces(chess.KNIGHT, colour)) + \
            sorted(board.pieces(chess.PAWN, colour))
        natural = {chess.KING: [0], chess.QUEEN: [1], chess.ROOK: [2, 3], chess.BISHOP: [4, 5], chess.KNIGHT: [6, 7], chess.PAWN: list(range(8, 16))}
        for s in pieces:
            pt = board.piece_type_at(s)
            slots = natural[pt]
            if pt == chess.ROOK:
                if s == chess.square(0, home) and 2 not in used:
                    slots = [2]
                elif s == chess.square(7, home) and 3 not in used:
                    slots = [3]
            cand = [x for x in slots if x not in used] or [x for x in free if x not in used]
            slot = cand[0]
            used.add(slot)
            rec = base + slot * 8
            p = chess.piece_symbol(pt)
            t = TYPE[p]
            if pt == chess.KING and not board.has_castling_rights(colour):
                t |= 0x10
            if pt == chess.ROOK:
                if not (s == chess.square(0, home) and board.has_queenside_castling_rights(colour) and slot == 2) and \
                   not (s == chess.square(7, home) and board.has_kingside_castling_rights(colour) and slot == 3):
                    t |= 0x10
            sq = to88(s)
            mem[rec] = sq
            mem[rec + 1] = t
            mem[rec + 6] = (0xC0 if cbit == 0 else 0x80) if p == 'p' else W6[p]
            mem[0xBD00 + sq] = cbit | (slot * 8) | 4
    fr, to, fl = prev
    mem[0xBD58:0xBD5C] = [0, fr, to, fl]


def model(mem, black):
    base = 0xBE80 if black else 0xBE00
    side = 0x80 if black else 0
    ix = mem[0xBD58:0xBD5C]
    out = []

    def pc(sq):
        return mem[0xBD00 + (sq & 0xFF)]

    def enemy(c):
        return (c ^ side) & 0x80

    def add(fr, to, fl):
        out.append((fr, to & 0xFF, fl))

    def step(fr, dirs):
        for d in dirs:
            t = (fr + d) & 0xFF
            if t & 0x88:
                continue
            c = pc(t)
            if c == 0:
                add(fr, t, 0)
            elif enemy(c):
                add(fr, t, 8)

    def slide(fr, dirs):
        for d in dirs:
            t = fr
            while True:
                t = (t + d) & 0xFF
                if t & 0x88:
                    break
                c = pc(t)
                if c == 0:
                    add(fr, t, 0)
                    continue
                if enemy(c):
                    add(fr, t, 8)
                break

    k = mem[base]
    if not mem[base + 1] & 0x10 and not ix[3] & 0x80:
        if not mem[base + 0x19] & 0x10 and not mem[base + 0x18] & 0x80:
            if pc(k + 1) == 0 and pc(k + 2) == 0:
                add(k, k + 2, 0x10)
        if not mem[base + 0x11] & 0x10 and not mem[base + 0x10] & 0x80:
            if pc(k - 1) == 0 and pc(k - 2) == 0 and pc(k - 3) == 0:
                add(k, k - 2, 0x10)
    step(k, KDIRS)
    for off, fn, dirs in ((8, slide, KDIRS), (0x10, slide, RDIRS), (0x18, slide, RDIRS), (0x20, slide, BDIRS),
                          (0x28, slide, BDIRS), (0x30, step, NDIRS), (0x38, step, NDIRS)):
        if not mem[base + off] & 0x80:
            fn(mem[base + off], dirs)
    cdiag = 0xF1 if black else 0x11
    for off in range(0x40, 0x80, 8):
        fr = mem[base + off]
        if fr & 0x80:
            continue
        t = mem[base + off + 1]
        if t & 0x0E:
            if t & 0x80:
                slide(fr, BDIRS)
            elif t & 0x02:
                step(fr, NDIRS)
            elif t & 0x04:
                slide(fr, RDIRS)
            else:
                slide(fr, KDIRS)
            continue
        t1 = (fr + cdiag) & 0xFF
        for tt in (t1, (t1 - 2) & 0xFF):
            c = pc(tt)
            if c and enemy(c):
                add(fr, tt, 8)
        f = (t1 - 1) & 0xFF
        do_ep = True
        if pc(f) == 0:
            add(fr, f, 0)
            if ((fr + 0x20) & 0x40) == 0:
                do_ep = False
                t2 = (cdiag - 1 + f) & 0xFF
                if not t2 & 0x80 and pc(t2) == 0:
                    add(fr, t2, 0)
                    for adj in ((t2 - 1) & 0xFF, (t2 + 1) & 0xFF):
                        c = pc(adj)
                        if c and enemy(c):
                            if (mem[0xBE00 + ((c - 3) & 0xFF)] & 0x0F) == 1:
                                last = out[-1]
                                out[-1] = (last[0], last[1], 0x20)
        if do_ep and ix[3] & 0x20 and not ix[3] & 0x08:
            if (ix[2] + 1) & 0xFF == fr:
                add(fr, f - 1, 0x28)
            elif (ix[2] - 1) & 0xFF == fr:
                add(fr, f + 1, 0x28)
    return out


def chess_set(board):
    s = set()
    for mv in board.pseudo_legal_moves:
        if board.is_castling(mv):
            continue
        s.add((to88(mv.from_square), to88(mv.to_square)))
    return s


def main():
    rnd = random.Random(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
    npos = int(sys.argv[2]) if len(sys.argv) > 2 else 150
    m = Machine(SNAP)
    mem = m.memory
    bad_order = bad_set = 0
    tested = 0
    stats = {'ep': 0, 'castle': 0, 'promo': 0, 'cap': 0}
    while tested < npos:
        b = chess.Board()
        for _ in range(rnd.randint(1, 120)):
            moves = list(b.legal_moves)
            if not moves or b.is_game_over():
                break
            # bias towards captures/promotions occasionally
            mv = rnd.choice(moves)
            b.push(mv)
        if b.is_game_over() or not b.move_stack:
            continue
        last = b.peek()
        prevb = b.copy()
        prevb.pop()
        flags = 0
        if prevb.piece_type_at(last.from_square) == chess.PAWN and abs(last.to_square - last.from_square) == 16:
            flags = 0x20 if b.ep_square is not None or True else 0
        if b.is_check():
            flags |= 0x80
        load(mem, b, (to88(last.from_square), to88(last.to_square), flags))
        black = b.turn == chess.BLACK
        start, end, hdr, moves = gen(m, black)
        sim = [(mv[1], mv[2], mv[3]) for mv in moves]
        mod = model(mem, black)
        tested += 1
        if sim != mod:
            bad_order += 1
            print('ORDER MISMATCH', b.fen())
            print(' sim  ', ' '.join(f'{sqname(a)}{sqname(c)}/{f:02X}' for a, c, f in sim))
            print(' model', ' '.join(f'{sqname(a)}{sqname(c)}/{f:02X}' for a, c, f in mod))
        cs = chess_set(b)
        ss = {(a, c) for a, c, f in sim if f != 0x10}
        if cs != ss:
            bad_set += 1
            print('SET MISMATCH', b.fen(), 'missing', [sqname(a) + sqname(c) for a, c in cs - ss], 'extra', [sqname(a) + sqname(c) for a, c in ss - cs])
        for a, c, f in sim:
            if f == 0x28: stats['ep'] += 1
            if f == 0x10: stats['castle'] += 1
            if f & 8: stats['cap'] += 1
        if any(mv.promotion for mv in b.pseudo_legal_moves): stats['promo'] += 1
        # castling check vs python-chess ignoring attacks
    print(f'tested {tested}: order mismatches {bad_order}, set mismatches {bad_set}; {stats}')


if __name__ == '__main__':
    main()
