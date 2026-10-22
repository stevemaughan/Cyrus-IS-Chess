import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Python transliteration of the Cyrus search ($7BE1-$80C3), driven against the
original's primitives (movegen $78CE, make $810F, eval $8400, unmake $821C,
pre-search $7810) running in the simulator. Compares the sequence of make calls
with the original program.

Usage: model.py SNAP LEVEL
"""
import sys
sys.path.insert(0, HERE)
from hsim import HMachine, parse_script, sq

SENT = 0x5B80
COVER = set()


class Bail(Exception):
    pass


def prepare(snap, level):
    m = HMachine(snap)
    for _ in range(30):
        if m.m(0xBCCD) == level - 1:
            break
        m.run_script(parse_script('l/3,w15'))
    assert m.m(0xBCCD) == level - 1
    m.tracer.press(['m'])
    m.run_until(3)
    m.tracer.press([])
    m.hooks = {0x7BE1: lambda mm: setattr(mm, 'stop_flag', True)}
    assert m.run_until(50 * 60 * 5)
    m.hooks = {}
    return m


def run_original(snap, level):
    m = prepare(snap, level)
    log = []

    def h_make(mm):
        ix = mm.reg('IX')
        log.append(('M', mm.m(0xBCA9), mm.m(ix + 1), mm.m(ix + 2)))

    def h_evret(mm):
        pass

    def h_done(mm):
        mm.stop_flag = True

    def h_book(mm):
        BOOK_R.append(mm.sim.registers[15])
    m.hooks = {0x810F: h_make, 0x618F: h_done, 0x7AC7: h_book}
    m.run_until(50 * 60 * 30)
    return log, m.w(0xBD29), m.m(0xBCA0)


BOOK_R = []


class Model:
    def __init__(self, m):
        self.m = m
        self.mem = m.sim.memory
        self.log = []
        self.ix = 0
        self.c = 0

    # --- primitives -------------------------------------------------------
    def call(self, addr, ix=None):
        r = self.m.sim.registers
        if ix is not None:
            r[8], r[9] = ix >> 8, ix & 0xFF
        sp = (r[12] - 2) & 0xFFFF
        r[12] = sp
        self.mem[sp] = SENT & 0xFF
        self.mem[sp + 1] = SENT >> 8
        r[24] = addr
        if not self.m.run_until(50 * 60, stop_pc=SENT):
            raise Bail(f'primitive {addr:04X} did not return')
        return r[0]

    def make(self, ix):
        self.log.append(('M', self.mem[0xBCA9], self.mem[ix + 1], self.mem[ix + 2]))
        self.call(0x810F, ix)

    def unmake(self):
        self.call(0x821C)

    def evaluate(self, ix):
        return self.call(0x8400, ix)

    def gen(self, ix):
        self.call(0x78CE, ix)
        r = self.m.sim.registers
        return r[5], r[6] * 256 + r[7]          # E = count, HL = header+3

    def W(self, a):
        return self.mem[a] + 256 * self.mem[a + 1]

    def SW(self, a, v):
        self.mem[a] = v & 0xFF
        self.mem[a + 1] = v >> 8

    # --- helpers in the search range ---------------------------------------
    def f8006(self):
        mem = self.mem
        p = mem[0xBCA9]
        hl = self.W(0xBC00 + ((0xA9 + 2 * p) & 0xFF))
        return p, hl + 3, mem[hl + 1], mem[hl + 2]

    def findmove(self, hl, b, frm, to):        # $7BCD; hl = header/entry +2
        mem = self.mem
        for _ in range(b or 256):
            hl += 4
            if mem[hl] == to and mem[hl - 1] == frm:
                return True, hl - 1
        return False, hl

    def score_moves(self, hl, e):              # $7B96
        mem = self.mem
        ix = hl + 1
        mem[0xBD19] = 0
        n = (e + 1) & 0xFF
        while True:
            n = (n - 1) & 0xFF
            if n == 0:
                return
            if mem[ix] == 0xFF:
                self.make(ix)
                a = self.evaluate(ix)
                mem[ix] = a
                if a >= mem[0xBD19]:
                    mem[0xBD19] = a
                    self.SW(0xBD1A, ix)
                self.unmake()
            ix += 4

    def pick(self, hl):                        # $8015; hl = header+3
        mem = self.mem
        a = 0
        h = hl - 3
        de = None
        while True:
            h += 4
            if a >= mem[h]:
                continue
            a = mem[h]
            if a == 0xFF:
                return de
            de = h

    def prune(self, best):                     # $805F; returns D (only meaningful for p < 3)
        mem = self.mem
        if mem[0xBD09] & 0x80:
            return None
        p, hl, e, c = self.f8006()
        D = None
        if p >= 3:
            aa = mem[0xBD2D]
        else:
            D = (2 * e) & 0xFF
            aa = 0x10
        iy = 0x80A2
        if aa & 0x10:
            iy = 0x80BB
        if aa & 0x08:
            iy = 0x80A7
        a = max(best, c)
        if a < 9:
            return D
        C = a - 9
        h = hl + 1
        for _ in range(e or 256):
            s = mem[h]
            h += 3
            if s < C:
                x = (s - C) & 0xFF
                tgt = None
                if iy == 0x80A2:
                    x = (x + 16) & 0xFF
                    tgt = 0x80AB if x & 0x80 else 0x80A7
                elif iy == 0x80BB:
                    D = (D - 1) & 0xFF if D is not None else None
                    x = (x + 16) & 0xFF
                    tgt = None if not x & 0x80 else 0x80A7
                else:
                    tgt = 0x80A7
                if tgt == 0x80A7 and not mem[h] & 0x04:
                    tgt = None
                if tgt is not None and not mem[h] & 0xC9:
                    mem[h - 3] = 0
            h += 1
        return D

    # --- the search -------------------------------------------------------
    def think(self):                           # $7BE1
        self.call(0x7810)
        while True:
            r = self.search_pass()
            if r == 'nomove':
                return r
            if self.mem[0xBD6E] == 0:
                return r

    def search_pass(self):                     # $7BF1
        mem = self.mem
        for a in range(0xBC91, 0xBC9E):
            mem[a] = 0xFF
        mem[0xBD0C] = 0xFF
        mem[0xBD0D] = 0
        for a in range(0xBC9F, 0xBCA8):
            mem[a] = 0
        e, hl = self.gen(0xBD58)
        mem[hl] |= 0x20
        self.score_moves(hl, e)
        if mem[0xBCDD] == 0:
            if BOOK_R:
                self.m.sim.registers[15] = BOOK_R.pop(0)
            self.call(0x7AC7)
            if self.m.sim.registers[1] & 0x40:      # Z: book move found
                return 'book'
        if mem[0xBD19] == 0:
            return 'nomove'
        d = mem[0xBD19]
        if mem[0xBD6E]:
            h = self.W(0xBD29)
            mem[h] = 0xFD
            self.SW(0xBD1A, h)
            mem[0xBD6E] = 0
            a = mem[0xBCBD]
        else:
            self.SW(0xBD29, self.W(0xBD1A))
            a = mem[0xBCBD]
            if a >= 5:
                a = 1
                mem[0xBD6E] = 1
        mem[0xBDF6] = 0
        mem[0xBD09] = a
        if a & 2:
            mem[0xBDF6] = a
            if a & 1:
                mem[0xBD09] |= 0x80
        mem[0xBCAA] = 1 if a == 0 else 2 if a < 4 else 3 if a == 4 else 4
        b = 7
        if not mem[0xBD09] & 0x80:
            if not mem[0xB403] & 0x80:
                D = self.prune(d)
                D = (((D >> 2) - 1) & 0xFF) >> 1
                f = mem[0xBD2D]
                if f & 0x10:
                    b = 11
                else:
                    b = 10
                    sra = (f >> 1) | (f & 0x80)
                    if (sra - 1) & 0xFF == 0:
                        b = 8
                while True:
                    D = (D - 1) & 0xFF
                    if D & 0x80:
                        break
                    b -= 1
                    if b == 0:
                        break
            mem[0xBD09] = b + 2
        h = 0xBF00
        while mem[h] != 0xFF:
            frm, to = mem[h], mem[h + 1]
            h += 2
            found, h2 = self.findmove(0xB402, mem[0xB401], frm, to)
            mem[h2 - 1] = 0
        de = self.pick(0xB403)
        if de is None:
            raise Bail('no more moves')
        self.SW(0xBD1A, de)
        c = mem[0xBD5E]
        if c >= 2:
            to, frm = mem[0xBD5C], mem[0xBD5D]
            found, h2 = self.findmove(0xB402, mem[0xB401], frm, to)
            h2 -= 1
            if mem[h2] != 0:
                mem[h2] = 0
                a = mem[0xBD2E]
                if mem[0xBD2D] & 1:
                    a = -a & 0xFF
                a = (a + 0x7E) & 0xFF
                if c & 4:
                    a = (a - 8) & 0xFF
                mem[0xBCA0] = a
                self.SW(0xBD2B, h2)
                return self.run_from('L7E9B')
        return self.run_from('L7DCF')

    def run_from(self, label):
        mem = self.mem
        st = {}
        while True:
            if label == 'EXIT':
                return 'done'
            COVER.add(label)
            label = getattr(self, label)(st)

    # Each label method returns the next label.
    def L7D43(self, st):
        mem = self.mem
        e, hl = self.gen(self.ix)
        if e == 0:
            return 'L7DA8'
        p = mem[0xBCA9]
        st['count'] = e
        if mem[self.ix + 3] & 0x04:
            return 'L802B'
        if mem[hl] & 0x80:
            return 'L7DA8'
        de = 0xBC00 + ((0x91 + 2 * (p - 1)) & 0xFF)
        if mem[de] & 0x80:
            return 'L7DA8'
        found, h = self.findmove(hl - 1, e, mem[de], mem[de + 1])
        if not found:
            return 'L7DA8'
        h -= 1
        mem[h] = 0
        self.ix = h
        self.make(h)
        return 'L7D77'

    def L7D77(self, st):
        mem = self.mem
        a = self.evaluate(self.ix)
        if a == 0:
            self.unmake()
            return 'L7DA8'
        self.c = a
        saved = a
        D, p = mem[0xBCAA], mem[0xBCA9]
        if D < p:
            return 'L7F20'
        if D == p:
            if self.f80C4(D):
                self.unmake()
                return 'L7E79'
        p, hl, e, c = self.f8006()
        mem[hl] |= 0x40
        mem[hl - 1] = saved
        fl = mem[self.ix + 3]
        if not fl & 0x02 or fl & 0x08:
            return 'L7DEE'
        mem[self.ix] = saved
        self.unmake()
        return 'L7DA8'

    def f80C4(self, a):
        mem = self.mem
        if a & 1:
            return False
        x = mem[0xBD09]
        if x & 0x80:
            return False
        if x >= self.c:
            return False
        y = (x - self.c) & 0xFF
        if y >= mem[0xBC00 + ((0x9E + a) & 0xFF)]:
            return False
        p, hl, e, c = self.f8006()
        if mem[hl] & 1:
            return False
        return True

    def L7DA8(self, st):
        mem = self.mem
        D, p = mem[0xBCAA], mem[0xBCA9]
        if D < p:
            return 'L7EE4'
        p, hl, e, c = self.f8006()
        st['hl'] = hl
        if mem[hl] & 0x20:
            return 'L7DDA'
        mem[hl] |= 0x20
        self.score_moves(hl, e)
        if mem[0xBD19] == 0:
            return 'L7FEA'
        if mem[hl] & 0x80:
            return 'L80E2'
        self.prune(mem[0xBD19])
        return 'L7DCF'

    def L7DCF(self, st):
        self.ix = self.W(0xBD1A)
        self.mem[self.ix] = 0
        return 'L7DEB'

    def L7DDA(self, st):
        mem = self.mem
        if mem[st['hl']] & 0x80:
            return 'L80ED'
        de = self.pick(st['hl'])
        if de is None:
            return 'L7E25'
        self.ix = de
        mem[de] = 0
        return 'L7DEB'

    def L7DEB(self, st):
        self.make(self.ix)
        return 'L7DEE'

    def L7DEE(self, st):
        mem = self.mem
        p = mem[0xBCA9]
        if p - 1 == 0:
            self.SW(0xBD2B, self.ix)
            return 'L7E0A'
        h = 0xBC00 + ((0x83 + 2 * (p - 1)) & 0xFF)
        mem[h] = mem[self.ix + 1]
        mem[h + 1] = mem[self.ix + 2]
        return 'L7E0A'

    def L7E0A(self, st):
        mem = self.mem
        mem[0xBD2D] ^= 1
        p = mem[0xBCA9]
        mem[0xBCA9] = p + 1
        mem[0xBC00 + ((0xA0 + p) & 0xFF)] = mem[0xBC00 + ((0xA0 + p - 2) & 0xFF)]
        return 'L7D43'

    def L7E25(self, st):
        mem = self.mem
        while True:
            a = mem[0xBCA9] - 1
            if a == 0:
                return 'EXIT'
            mem[0xBCA9] = a
            self.unmake()
            mem[0xBD2D] ^= 1
            if not mem[0xBD4C] & 0x80:
                break
        p = mem[0xBCA9]
        st['A'] = -mem[0xBC00 + 0xA0 + p] & 0xFF
        st['L'] = 0xA0 + p
        return 'L7E49'

    def L7E49(self, st):
        mem = self.mem
        a, L = st['A'], st['L']
        L -= 2
        a ^= 0xFF
        if a < mem[0xBC00 + L]:
            return 'L7E79'
        a ^= 0xFF
        L += 1
        if a <= mem[0xBC00 + L]:
            return 'L7DA8'
        mem[0xBC00 + L] = a
        a = mem[0xBCA9] - 1
        if a == 0:
            return 'L7E95'
        st['A'] = a
        return 'L7E5F'

    def L7E5F(self, st):
        mem = self.mem
        a = st['A']
        h = 0xBC00 + ((0x91 + 2 * a) & 0xFF)
        de = 0xBC00 + ((0x83 + 2 * a) & 0xFF)
        if mem[de] & 0x80:
            return 'L7DA8'
        mem[h] = mem[de]
        mem[h + 1] = mem[de + 1]
        return 'L7DA8'

    def L7E79(self, st):
        mem = self.mem
        self.unmake()
        mem[0xBCA9] -= 1
        mem[0xBD2D] ^= 1
        st['A'] = mem[0xBCA9]
        return 'L7E5F'

    def f7E8C(self):
        self.SW(0xBD29, self.W(0xBD2B))

    def L7E95(self, st):
        if (self.mem[0xBCA0] + 1) & 0xFF:
            return 'L7E9B'
        return 'L7EA1'

    def L7E9B(self, st):
        self.f7E8C()
        return 'L7DA8'

    def L7EA1(self, st):
        mem = self.mem
        mem[0xBCA0] = 0xFE
        a = mem[0xBD0B]
        if a == 2:
            self.f7E8C()
            return 'EXIT'
        if a >= mem[0xBD0C]:
            return 'L7DA8'
        mem[0xBD0C] = a
        return 'L7E9B'

    def L7EB6(self, st):
        mem = self.mem
        if mem[0xBCB6] == 0xB4:
            return 'L7ED3'
        D = mem[0xBCAA]
        if D < 3:
            return 'L7F27'
        if mem[0xBCB3] >= 0x58:
            return 'L7F27'
        st['A'] = D
        return 'L7F3E'

    def L7ED3(self, st):
        D = self.mem[0xBCAA]
        if D < 3:
            return 'L7F27'
        st['A'] = D + 1
        return 'L7F3E'

    def L7EDE(self, st):
        self.unmake()
        return 'L7EE4'

    def L7EE4(self, st):
        mem = self.mem
        while True:
            p = mem[0xBCA9]
            L = (0xA9 + 2 * p) & 0xFF
            mem[0xBD4E] = L
            hl = self.W(0xBC00 + L)
            cnt, tried = mem[hl + 1], mem[hl + 2]
            if cnt == tried:
                return 'L7E25'
            mem[hl + 2] = (tried + 1) & 0xFF
            mem[0xBD4B] = mem[hl + 3]
            e = hl + 4 + 4 * tried
            mem[e] = (mem[e] + 1) & 0xFF
            if mem[e] != 0:
                continue
            self.ix = e
            self.make(e)
            a = self.evaluate(e)
            self.c = a
            if a != 0:
                return 'L7F20'
            self.c = 1
            if mem[0xBD4B] & 0x80:
                return 'L7F43'
            self.unmake()

    def L7F20(self, st):
        if self.mem[0xBCB2] == 0xB4:
            return 'L7EB6'
        return 'L7F27'

    def L7F27(self, st):
        mem = self.mem
        if mem[0xBD4E] == 0:
            return 'L7F39'
        f = mem[self.ix + 3]
        if not f & 0x80 or f & 0x04:
            return 'L7F43'
        return 'L7F39'

    def L7F39(self, st):
        st['A'] = self.mem[0xBCAA]
        return 'L7F3E'

    def L7F3E(self, st):
        if (st['A'] + 1) & 0xFF >= self.mem[0xBCA9]:
            return 'L7DEE'
        return 'L7F43'

    def L7F43(self, st):
        mem = self.mem
        p = mem[0xBCA9]
        self.c = (self.c + 1) & 0xFF
        a = self.c ^ 0xFF
        L = (0xA0 + p - 2) & 0xFF
        if a < mem[0xBC00 + L]:
            return 'L7F81'
        st['L'] = L + 1
        if mem[self.ix + 3] & 0x42:
            return 'L7FAD'
        return 'L7F5B'

    def L7F5B(self, st):
        mem = self.mem
        L = st['L']
        if self.c <= mem[0xBC00 + L]:
            return 'L7EDE'
        mem[0xBC00 + L] = self.c
        if mem[0xBD4B] & 0x80:
            return 'L7EDE'
        p = mem[0xBCA9]
        h = 0xBC00 + ((0x91 + 2 * (p - 1)) & 0xFF)
        mem[h] = mem[self.ix + 1]
        mem[h + 1] = mem[self.ix + 2]
        return 'L7EDE'

    def L7F81(self, st):
        mem = self.mem
        self.unmake()
        self.unmake()
        mem[0xBD2D] ^= 1
        mem[0xBCA9] -= 1
        if mem[0xBD4B] & 0x80:
            return 'L7DA8'
        q = mem[0xBCA9]
        h = 0xBC00 + ((0x91 + 2 * q) & 0xFF)
        mem[h] = mem[self.ix + 1]
        mem[h + 1] = mem[self.ix + 2]
        return 'L7DA8'

    def L7FAD(self, st):
        mem = self.mem
        p = mem[0xBCA9]
        a = (mem[0xBCAA] + 2) & 0xFF
        if a < p:
            return 'L7F5B'
        if a == p:
            a = self.c
        else:
            a = self.c + 1
            if a > 0xFF:
                return 'L7F5B'
        if a < mem[0xBC00 + st['L']]:
            return 'L7EDE'
        if mem[0xBDF6] == 0:
            return 'L7F5B'
        if self.c == 2:
            return 'L7F5B'
        return 'L7DEE'

    def L7FEA(self, st):
        mem = self.mem
        hl = st['hl']
        if mem[hl] & 0x40:
            return 'L7E25'
        p = mem[0xBCA9]
        if not mem[hl] & 0x80:
            a = mem[0xBD2E]
            if mem[0xBD2D] & 1:
                a = -a & 0xFF
            st['A'] = (a + 0x78) & 0xFF
        else:
            mem[0xBD0B] = p
            st['A'] = 1
        st['L'] = 0xA0 + p
        return 'L7E49'

    def L802B(self, st):
        mem = self.mem
        p = mem[0xBCA9]
        hl = self.W(0xBC00 + ((0xA9 + 2 * (p + 1)) & 0xFF)) + 2
        to = mem[self.ix + 2]
        for _ in range(st['count'] or 256):
            hl -= 4
            if mem[hl] == to:
                break
        else:
            return 'L7DA8'
        hl -= 2
        self.ix = hl
        mem[hl] = 0
        self.make(hl)
        mem[hl + 1] |= 0x80
        mem[0xBD4B] = 0x80
        return 'L7D77'

    def L80E2(self, st):
        self.ix = self.W(0xBD1A)
        self.mem[self.ix] = 0
        return 'L80FA'

    def L80ED(self, st):
        de = self.pick(st['hl'])
        if de is None:
            return 'L7E25'
        self.ix = de
        self.mem[de] = 0
        return 'L80FA'

    def L80FA(self, st):
        mem = self.mem
        self.make(self.ix)
        p = mem[0xBCA9]
        if p - 1 == 0:
            self.SW(0xBD2B, self.ix)
            return 'L7E0A'
        mem[0xBC00 + ((0x83 + 2 * (p - 1)) & 0xFF)] |= 0x80
        return 'L7E0A'


def main():
    snap, level = sys.argv[1], int(sys.argv[2])
    olog, obest, oval = run_original(snap, level)
    m = prepare(snap, level)
    model = Model(m)
    try:
        model.think()
    except Bail as e:
        print('BAIL', e)
    mbest, mval = model.W(0xBD29), model.mem[0xBCA0]
    mlog = model.log
    n = min(len(olog), len(mlog))
    first = next((i for i in range(n) if olog[i] != mlog[i]), None)
    fmt = lambda t: f'p{t[1]}:{sq(t[2])}{sq(t[3])}'
    print(f'L{level}: original makes={len(olog)} model makes={len(mlog)}  best orig={sq(m.m(obest+1)) if False else obest:04X} model={mbest:04X}  BCA0 orig={oval:02X} model={mval:02X}')
    if first is None and len(olog) == len(mlog):
        print('  IDENTICAL make sequence')
    else:
        i = first if first is not None else n
        print('  first divergence at', i, 'orig', [fmt(t) for t in olog[max(0, i - 3):i + 3]], 'model', [fmt(t) for t in mlog[max(0, i - 3):i + 3]])
    labels = {n for n in dir(Model) if n.startswith('L')}
    print('  not visited:', sorted(labels - COVER))


if __name__ == '__main__':
    main()
