"""Oracle: run the original Cyrus IS Chess code in SkoolKit's Z80 simulator.

The oracle drives the original exactly as a user would (keys through the
original's own WaitKey routine) or calls its routines directly, and records
results in semantic form for golden files (AGENTS.md §6 Phase 2).
"""

import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'scripts'))

from cyrus_sim import Machine, KEYMAP, FRAME  # noqa: E402
from skoolkit.simutils import A, PC, T  # noqa: E402

ENTRY = os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
IDLE_L1 = os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')

# Original addresses used by the oracle (see docs/arch).
WAIT_KEY = 0x675A            # WaitKey entry (EI; spin until a key)
WAIT_KEY_DONE = 0x676A       # WaitKey: key received (DI)
COMPUTER_MOVE = 0x6147       # ComputerMove entry
COMPUTER_MOVE_PLAY = 0x61C1  # ComputerMovePlay: IX = ($BD29), JP PlayMove
PLAY_MOVE = 0x6323
GAME_OVER_NO_MOVES = 0x641A
GAME_OVER_DRAW = 0x6448
CHANGE_POSITION = 0x6D4D     # also reached after NO MATE FOUND
SETUP_ILLEGAL = 0x6588
SHOW_ILLEGAL = 0x739E        # user move rejected
MAKE = 0x810F
EVALUATE = 0x8400
NODE = 0x7D43                # search node entry (first instruction is the poll at $78BA)
POLL = 0x78BA
BOOK_R_DONE = 0x7B8B         # after LD A,R in the book's random step ($7B89)
BOOK_HIT = 0x7C23            # search driver: book move found (key poll follows)
ROOT_GENERATED = 0x615A      # ComputerMove: root list generated, before scoring
ROOT_SCORED = 0x615D         # ComputerMove: root list statically scored


def open_golden(path, mode='r'):
    """Open a golden file as text. Files ending in .gz are gzip-compressed;
    they are written with a zero timestamp so that regeneration is
    byte-identical."""
    import gzip
    import io
    if not path.endswith('.gz'):
        return open(path, mode, encoding='ascii', newline='\n')
    if mode == 'r':
        return io.TextIOWrapper(gzip.open(path, 'rb'), encoding='ascii')
    raw = open(path, 'wb')
    gz = gzip.GzipFile(filename=os.path.basename(path)[:-3], mode='wb', fileobj=raw, compresslevel=9, mtime=0)
    return _ClosingText(gz, raw)


class _ClosingText(object):
    def __init__(self, gz, raw):
        import io
        self._t = io.TextIOWrapper(gz, encoding='ascii', newline='\n')
        self._gz, self._raw = gz, raw

    def write(self, s):
        return self._t.write(s)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self._t.close()
        self._raw.close()


def sqname(s):
    """Internal 0x88 square (row 0 = rank 8) to algebraic."""
    if s & 0x88:
        return f'?{s:02X}'
    return 'abcdefgh'[s & 7] + str(8 - (s >> 4))


def sqnum(name):
    return (8 - int(name[1])) * 16 + 'abcdefgh'.index(name[0])


class OracleError(Exception):
    pass


START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'


def parse_fen(fen):
    """Minimal strict FEN parser. Board keys are internal squares."""
    parts = fen.split()
    if len(parts) < 4:
        raise ValueError('needs at least 4 fields')
    rows = parts[0].split('/')
    if len(rows) != 8:
        raise ValueError('needs 8 ranks')
    board = {}
    for r, row in enumerate(rows):          # r = 0 is rank 8 = internal row 0
        f = 0
        for ch in row:
            if ch.isdigit():
                f += int(ch)
            elif ch in 'KQRBNPkqrbnp':
                if f > 7:
                    raise ValueError('rank too long')
                board[r * 16 + f] = ch
                f += 1
            else:
                raise ValueError(f'bad character {ch!r}')
        if f != 8:
            raise ValueError('rank length')
    if parts[1] not in ('w', 'b'):
        raise ValueError('side to move')
    castling = '' if parts[2] == '-' else parts[2]
    if any(c not in 'KQkq' for c in castling):
        raise ValueError('castling field')
    ep = None if parts[3] == '-' else sqnum(parts[3])
    return {'board': board, 'white': parts[1] == 'w', 'castling': castling, 'ep': ep}


def fen_is_start(pos):
    s = parse_fen(START_FEN)
    return pos['board'] == s['board'] and pos['white'] and pos['castling'] == 'KQkq' and pos['ep'] is None


def ep_predecessor(pos):
    """Position before the double pawn step that created the en passant square."""
    ep = pos['ep']
    if pos['white']:                       # Black just played ...x7-x5; ep square on rank 6
        pawn, to, frm, own = 'p', ep + 16, ep - 16, ep
    else:                                  # White just played x2-x4; ep square on rank 3
        pawn, to, frm, own = 'P', ep - 16, ep + 16, ep
    b = pos['board']
    if b.get(to) != pawn or own in b or frm in b:
        return None
    pred = dict(pos)
    pred['board'] = dict(b)
    del pred['board'][to]
    pred['board'][frm] = pawn
    pred['white'] = not pos['white']
    pred['ep'] = None
    pred['ep_move'] = (frm, to)
    return pred


class Oracle:
    """One simulated Spectrum running the original program."""

    def __init__(self, snapshot=IDLE_L1):
        self.m = Machine(snapshot)
        self.sim = self.m.sim
        self.mem = self.sim.memory
        self.regs = self.sim.registers
        self.hooks = {}
        self.stop_flag = False
        self.r_bytes = None      # list of values substituted for LD A,R reads (None = real R)
        self.r_used = 0

    # ------------------------------------------------------------------ running
    def run(self, max_frames, stop_pcs=()):
        """Run with hooks until a PC in stop_pcs (returned), a hook sets
        stop_flag (returns 'hook'), or max_frames elapse (returns None)."""
        sim, regs, mem = self.sim, self.regs, self.mem
        opcodes = sim.opcodes
        hooks = self.hooks
        stops = set(stop_pcs)
        frame_duration, int_active = sim.frame_duration, sim.int_active
        tstates = regs[T]
        target = tstates + max_frames * FRAME
        next_int = ((tstates + frame_duration - int_active) // frame_duration) * frame_duration
        pc = regs[PC]
        self.stop_flag = False
        while tstates < target:
            if pc in stops:
                return pc
            h = hooks.get(pc)
            if h is not None:
                h(self)
                if self.stop_flag:
                    return 'hook'
            r_bytes = self.r_bytes
            if r_bytes is not None and pc == BOOK_R_DONE:
                if self.r_used >= len(r_bytes):
                    raise OracleError('ran out of scripted R bytes')
                regs[A] = r_bytes[self.r_used]
                self.r_used += 1
            opcodes[mem[pc]]()
            tstates = regs[T]
            if tstates >= next_int:
                if tstates < next_int + int_active:
                    if regs[26]:
                        sim.accept_interrupt(regs, mem, pc)
                        tstates = regs[T]
                else:
                    next_int += frame_duration
            pc = regs[PC]
        return None

    def _keyboard(self, names):
        self.m.tracer.press(names)

    def at_key_prompt(self):
        return WAIT_KEY <= self.regs[PC] < WAIT_KEY_DONE

    def wait_for_key_prompt(self, max_frames=50 * 60 * 30):
        """Run until the program is in WaitKey's loop (not inside the ROM
        interrupt routine that it lets run); fail on unexpected outcomes."""
        if self.at_key_prompt():
            return
        r = self.run(max_frames, range(WAIT_KEY, WAIT_KEY_DONE))
        if r is None or r == 'hook':
            raise OracleError(f'no key prompt (stopped at {r})')

    def idle_frames(self, n):
        """Spend n frames at a key prompt with no key pressed."""
        self.run(n)
        r = self.run(2, range(WAIT_KEY, WAIT_KEY_DONE))
        if r is None or r == 'hook':
            raise OracleError('left WaitKey while idle')

    def key(self, name):
        """Deliver one key press through WaitKey."""
        if not self.at_key_prompt():
            self.wait_for_key_prompt()
        self.idle_frames(8)               # let the ROM forget the previous key
        self._keyboard([name])
        r = self.run(50, (WAIT_KEY_DONE,))
        self._keyboard([])
        if r != WAIT_KEY_DONE:
            raise OracleError(f'key {name} not accepted')
        self.wait_for_key_prompt()

    # --------------------------------------------------------------- memory views
    def b(self, a):
        return self.mem[a]

    def w(self, a):
        return self.mem[a] + 256 * self.mem[a + 1]

    def poke(self, a, v):
        self.mem[a] = v & 0xFF

    # ------------------------------------------------------------- UI operations
    def side_to_move_white(self):
        return bool(self.b(0xBD2D) & 1)

    def new_game(self):
        self.key('g')
        self.key('y')

    def set_level(self, index):
        """index 0-10 = Level 1-8, P1-P3 (the value of $BCCD)."""
        for _ in range(11):
            if self.b(0xBCCD) == index:
                return
            self.key('l')
        raise OracleError('level not reached')

    def human_v_human(self):
        self.key('e')

    def _goto(self, square):
        for _ in range(40):
            cur = self.b(0xBCCA)
            if cur == square:
                return
            cf, cr, tf, tr = cur & 7, cur >> 4, square & 7, square >> 4
            if cf < tf:
                k = '8'
            elif cf > tf:
                k = '5'
            elif cr < tr:
                k = '6'
            else:
                k = '7'
            self.key(k)
        raise OracleError(f'cursor stuck at {self.b(0xBCCA):02X}')

    def enter_move(self, uci, then_think=False):
        """Enter a move (UCI notation) through the original's move entry.
        With then_think=True the final key is pressed without waiting for the
        next prompt, because the computer starts thinking straight away
        (HUMAN v CYRUS); use it as the trigger of computer_move()."""
        f, t = sqnum(uci[:2]), sqnum(uci[2:4])
        illegal = []
        self.hooks[SHOW_ILLEGAL] = lambda o: illegal.append(1)
        try:
            self._goto(f)
            self.key('ENTER')
            self._goto(t)
            promo = uci[4:5]
            if promo:
                self.key('ENTER')
                if illegal:
                    raise OracleError(f'illegal move {uci}')
                last = promo
            else:
                last = 'ENTER'
            if then_think:
                self.key_no_wait(last)
            else:
                self.key(last)
        finally:
            del self.hooks[SHOW_ILLEGAL]
        if illegal:
            raise OracleError(f'illegal move {uci}')

    # ------------------------------------------------------------ FEN set-up
    def setup_fen(self, fen):
        """Load a FEN through the original's CHANGE POSITION mode, using the
        canonical construction of AGENTS.md §9.4. Must be called at a key
        prompt. Returns (True, '') if the original accepted the position,
        otherwise (False, reason). After acceptance it is the human's turn."""
        try:
            pos = parse_fen(fen)
        except ValueError as e:
            return False, f'malformed FEN: {e}'
        self.new_game()
        if fen_is_start(pos):
            return True, ''
        if pos['ep'] is not None:
            pred = ep_predecessor(pos)
            if pred is None:
                return False, 'en passant square inconsistent with the position'
            ok, why = self._setup_board(pred)
            if not ok:
                return False, 'predecessor of en passant position rejected: ' + why
            f, t = pred['ep_move']
            try:
                self.human_v_human()          # so that Cyrus does not reply to the double step
                self.enter_move(sqname(f) + sqname(t))
            except OracleError:
                return False, 'double pawn step rejected'
            return True, ''
        return self._setup_board(pos)

    def _setup_board(self, pos):
        start = parse_fen(START_FEN)['board']
        target, rights = pos['board'], pos['castling']
        for colour, home_k, corners in (('w', 0x74, {'K': 0x77, 'Q': 0x70}), ('b', 0x04, {'k': 0x07, 'q': 0x00})):
            for right, corner in corners.items():
                if right in rights:
                    if target.get(home_k) != ('K' if colour == 'w' else 'k') or \
                       target.get(corner) != ('R' if colour == 'w' else 'r'):
                        return False, f'castling right {right} without king and rook on their squares'
        keep = set()
        for sq, p in start.items():
            if target.get(sq) != p:
                continue
            if p in 'Kk':
                has = any(r in rights for r in (('K', 'Q') if p == 'K' else ('k', 'q')))
                if not has:
                    continue
            if p in 'Rr':
                right = {0x77: 'K', 0x70: 'Q', 0x07: 'k', 0x00: 'q'}[sq]
                if right not in rights:
                    continue
            keep.add(sq)
        illegal = []
        self.hooks[SETUP_ILLEGAL] = lambda o: illegal.append(1)
        try:
            self.key('c')
            # remove new-game pieces that are not wanted (squares that stay empty)
            for sq in sorted(start):
                if sq not in keep and sq not in target:
                    self._goto(sq)
                    self.key('u')
            # enter the remaining pieces, in the original's scan order (file a-h, rank 8-1)
            for f in range(8):
                for r in range(8):
                    sq = r * 16 + f
                    p = target.get(sq)
                    if p is None or sq in keep:
                        continue
                    self._set_colour(p.isupper())
                    self._goto(sq)
                    self.key(p.lower())
            self._set_colour(pos['white'])
            self.key('e')
        finally:
            del self.hooks[SETUP_ILLEGAL]
        if illegal:
            # leave set-up mode cleanly for the next scenario: start a new game
            self.key('g')
            self.key('y')
            return False, 'rejected by the original set-up check'
        return True, ''

    def _set_colour(self, white):
        if bool(self.b(0xBCA2) & 0x80) != white:
            self.key('t')
        if bool(self.b(0xBCA2) & 0x80) != white:
            raise OracleError('colour toggle failed')

    # ------------------------------------------------------------ state capture
    def capture_state(self):
        """Everything the search, pre-search, evaluation and book can read.

        Fields are hex strings of original variables in address order, so a
        port maps each byte to the field that holds that original variable
        (docs/arch has the meanings):
          pieces   $BE00-$BEFF  32 piece records x 8 bytes (Black slots, then White)
          board    $BD00+row*16+file, rows 0-7 (rank 8 first), files 0-7
          offboard $BD08+row*16 ... $BD0F+row*16: the variables in the board's
                   off-board columns, rows 0-7
          bc83     $BC83-$BCFF  search tables and global variables
          bdf6     $BDF6
          exclusion  next-best list at $BF00 (pairs, without the $FF)
          c000     $C000-$C057  game-record header, start position, promotions
          record   $C058...     one byte per ply, with the $FF terminator
        """
        mem = self.mem
        excl = []
        a = 0xBF00
        while mem[a] != 0xFF and a < 0xBFFE:
            excl.append(mem[a])
            a += 1
        rec_len = self.w(0xC001)
        return {
            'pieces': bytes(mem[0xBE00:0xBF00]).hex(),
            'board': bytes(mem[0xBD00 + r * 16 + f] for r in range(8) for f in range(8)).hex(),
            'offboard': bytes(mem[0xBD00 + r * 16 + f] for r in range(8) for f in range(8, 16)).hex(),
            'bc83': bytes(mem[0xBC83:0xBD00]).hex(),
            'bdf6': mem[0xBDF6],
            'exclusion': bytes(excl).hex(),
            'c000': bytes(mem[0xC000:0xC058]).hex(),
            'record': bytes(mem[0xC058:0xC058 + rec_len + 1]).hex(),
        }

    def root_list(self):
        """Root move list: (header count byte, [[score, from, to, flags], ...]).
        The list ends where the generator started the next ply's list,
        slot(2) = word at $BCAD (the header count is unreliable for >= 127 moves)."""
        mem = self.mem
        end = self.w(0xBCAD)
        entries = [list(mem[a:a + 4]) for a in range(0xB404, end, 4)]
        return mem[0xB401], entries

    # ------------------------------------------------------------------ search
    def computer_move(self, bcce, r_bytes=(), level=None, abort_at_node=None, trace=False,
                      trigger=None, max_frames=50 * 60 * 60):
        """Let the original make one computer move from the current state.

        By default M is pressed at the YOUR MOVE? prompt. `trigger` replaces
        that, e.g. lambda: o.enter_move('e7e5', then_think=True) in HUMAN v
        CYRUS mode. `bcce` is stored in $BCCE when ComputerMove starts;
        `r_bytes` replace the book's R reads.
        Returns (state_at_ComputerMove, result)."""
        if level is not None:
            self.set_level(level)
        out = {'makes': 0, 'evals': 0, 'nodes': 0}
        seq = hashlib.sha256()
        trace_list = [] if trace else None
        captured = {}

        def h_start(o):
            o.poke(0xBCCE, bcce)
            captured['state'] = o.capture_state()
            o.r_bytes = list(r_bytes)
            o.r_used = 0
            # count only from here: a trigger such as entering the opponent's
            # move also makes and evaluates moves (HumanMove's root scoring)
            o.hooks.update({MAKE: h_make, EVALUATE: h_eval, NODE: h_node})

        def h_make(o):
            ix = o.regs[8] * 256 + o.regs[9]
            item = bytes((o.b(0xBCA9), o.b(ix + 1), o.b(ix + 2)))
            seq.update(item)
            out['makes'] += 1
            if trace_list is not None:
                trace_list.append(item.hex())

        def h_eval(o):
            out['evals'] += 1

        def h_node(o):
            out['nodes'] += 1
            if abort_at_node is not None and out['nodes'] == abort_at_node:
                o._keyboard(['SPACE'])
                o.hooks[0x78CE] = h_release

        def h_release(o):
            o._keyboard([])
            del o.hooks[0x78CE]

        def h_book(o):
            out['book'] = True

        def h_root_generated(o):
            out['root_count'], entries = o.root_list()
            out['root'] = [e[1:] for e in entries]          # from, to, flags as generated

        def h_root_scored(o):
            out['root_scored'] = [[e[0], e[3]] for e in o.root_list()[1]]   # score, flags after eval

        out['book'] = False
        self.hooks.update({COMPUTER_MOVE: h_start, BOOK_HIT: h_book,
                           ROOT_GENERATED: h_root_generated, ROOT_SCORED: h_root_scored})
        try:
            if trigger is None:
                self.key_no_wait('m')
            else:
                trigger()
            r = self.run(max_frames, (COMPUTER_MOVE_PLAY, GAME_OVER_NO_MOVES, CHANGE_POSITION,
                                      GAME_OVER_DRAW))
        finally:
            for a in (COMPUTER_MOVE, MAKE, EVALUATE, NODE, BOOK_HIT, ROOT_GENERATED, ROOT_SCORED, 0x78CE):
                self.hooks.pop(a, None)
            self.r_bytes = None
            self._keyboard([])
        if r is None or r == 'hook':
            raise OracleError('computer move did not finish')
        out['r_used'] = self.r_used
        out['make_sha256'] = seq.hexdigest()
        if trace_list is not None:
            out['trace'] = trace_list
        out['bcce_after'] = self.b(0xBCCE)
        out['BCA0'] = self.b(0xBCA0)
        out['BD0C'] = self.b(0xBD0C)
        if r == COMPUTER_MOVE_PLAY:
            ix = self.w(0xBD29)
            out['result'] = 'move'
            out['move'] = sqname(self.b(ix + 1)) + sqname(self.b(ix + 2))
            out['index'] = (ix - 0xB404) // 4
        elif r == GAME_OVER_NO_MOVES:
            out['result'] = 'nomoves'
        elif r == GAME_OVER_DRAW:
            out['result'] = 'draw'          # declared by the main loop before thinking
        else:
            out['result'] = 'nomate'
        return captured.get('state'), out

    def key_no_wait(self, name):
        """Press a key at a prompt without waiting for the next prompt."""
        if not self.at_key_prompt():
            self.wait_for_key_prompt()
        self.idle_frames(8)
        self._keyboard([name])
        r = self.run(50, (WAIT_KEY_DONE,))
        self._keyboard([])
        if r != WAIT_KEY_DONE:
            raise OracleError(f'key {name} not accepted')

    def finish_move(self):
        """After computer_move returned at ComputerMovePlay, let the move be
        played and return to the next prompt."""
        self.wait_for_key_prompt()

    def save(self, path):
        self.m.save(path)

    def load_state(self, state):
        """Write a captured state into memory (the inverse of capture_state)."""
        mem = self.mem
        mem[0xBE00:0xBF00] = bytes.fromhex(state['pieces'])
        board = bytes.fromhex(state['board'])
        off = bytes.fromhex(state['offboard'])
        for r in range(8):
            for f in range(8):
                mem[0xBD00 + r * 16 + f] = board[r * 8 + f]
                mem[0xBD08 + r * 16 + f] = off[r * 8 + f]
        mem[0xBC83:0xBD00] = bytes.fromhex(state['bc83'])
        mem[0xBDF6] = state['bdf6']
        excl = bytes.fromhex(state['exclusion']) + b'\xff'
        mem[0xBF00:0xBF00 + len(excl)] = excl
        mem[0xC000:0xC058] = bytes.fromhex(state['c000'])
        rec = bytes.fromhex(state['record'])
        mem[0xC058:0xC058 + len(rec)] = rec

    def search_from_state(self, state, r_bytes=(), trace=False, abort_at_node=None,
                          max_frames=50 * 60 * 60):
        """Run ComputerMove from a captured state, entering it directly at $6147
        (no user interface). Returns the same `out` dict as computer_move."""
        self.load_state(state)
        self.regs[PC] = COMPUTER_MOVE
        self.regs[12] = 0xBDF4              # SP, as set by the main loop
        self.regs[26] = 0                   # interrupts disabled, as while thinking
        bcce = state_byte(state, 0xBCCE)
        return self.computer_move(bcce, r_bytes, abort_at_node=abort_at_node, trace=trace,
                                  trigger=lambda: None, max_frames=max_frames)[1]


def state_byte(state, addr):
    """Read one original variable from a captured state."""
    if 0xBC83 <= addr < 0xBD00:
        return bytes.fromhex(state['bc83'])[addr - 0xBC83]
    if 0xBD00 <= addr < 0xBD80 and addr & 8:
        return bytes.fromhex(state['offboard'])[((addr - 0xBD00) >> 4) * 8 + (addr & 7)]
    raise KeyError(f'{addr:04X} not in captured state')


class Session:
    """The canonical operator script that maps UCI usage onto the original's
    user interface (AGENTS.md §9.6). The Zig port implements the same state
    transitions; game-path golden files check that it does.

    - load(fen, moves): new game, or set-up for a FEN; then, if there are
      moves, E (HUMAN v HUMAN) and the moves are entered.
    - go(): M (KeyMove: Cyrus takes the side to move; $BCBE flips, $BCA0 is
      negated), unless the previous step was continue_with() of one move,
      after which Cyrus is already thinking (HUMAN v CYRUS).
    - continue_with(moves): after Cyrus has moved, one opponent move is
      entered in HUMAN v CYRUS mode and triggers the reply; two or more moves
      switch to HUMAN v HUMAN first and the reply then needs go().
    """

    def __init__(self, snapshot=IDLE_L1):
        self.o = Oracle(snapshot)
        self.pending = None

    def load(self, fen=None, moves=()):
        o = self.o
        if fen is None:
            o.new_game()
        else:
            ok, why = o.setup_fen(fen)
            if not ok:
                return False, why
        if moves:
            if o.b(0xBCC2) != 0:
                o.human_v_human()
            for mv in moves:
                o.enter_move(mv)
        self.pending = None
        return True, ''

    def continue_with(self, moves):
        o = self.o
        if len(moves) == 1:
            self.pending = lambda: o.enter_move(moves[0], then_think=True)
            return
        o.human_v_human()
        for mv in moves:
            o.enter_move(mv)
        self.pending = None

    def go(self, bcce, r_bytes=(), level=None, abort_at_node=None, trace=False):
        o = self.o
        if level is not None and self.pending is None:
            o.set_level(level)
        state, result = o.computer_move(bcce, r_bytes, None, abort_at_node, trace, trigger=self.pending)
        self.pending = None
        if result['result'] == 'move':
            o.finish_move()
        return state, result
