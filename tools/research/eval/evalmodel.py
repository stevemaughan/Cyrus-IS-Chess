import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Reference model of the Cyrus IS Chess evaluation routine $8400.

Operates on a 64K memory image (bytearray). Mirrors the original's register
usage closely enough to reproduce every side effect:
  E   main E: positional/mobility accumulator (8-bit)
  AP  A' accumulator: king-zone/pawn terms (8-bit)
  F   alternate B: pass flags (bit7 colour being processed, bit4 second pass,
      bit5 pin list non-empty, bit6 check seen, bits0-3 game phase)
"""


def s8(x):
    x &= 0xFF
    return x - 256 if x & 0x80 else x


def sra(x):
    x &= 0xFF
    return ((x >> 1) | (x & 0x80)) & 0xFF


class Abort(Exception):
    pass


BD, BE = 0xBD00, 0xBE00


class Eval:
    def __init__(self, mem, ix):
        self.m = mem
        self.ix = ix

    # ----- helpers -------------------------------------------------------
    def friendly(self, code):
        return ((code ^ self.F) & 0x80) == 0

    def add(self, addr, v):
        self.m[addr] = (self.m[addr] + v) & 0xFF

    def run(self):
        m = self.m
        self.E = 0
        self.AP = 0
        s = m[BD + 0x2D]
        a = ((s >> 1) | ((s & 1) << 7)) & 0xFF
        carry = s & 1
        if a & 2:
            self.pawn_mode = 0x8A2B if a & 4 else 0x8A6F
        else:
            self.pawn_mode = 0x8A7A
        self.F = (a + 0x80) & 0xFF
        try:
            if carry:
                self.white_section()
            else:
                self.black_section()
            return self.final()
        except Abort:
            for rec in range(0x08, 0x100, 8):
                for k in range(2, 6):
                    m[BE + rec + k] = 0
            m[BD + 0x79] = 0
            self.B = 0
            return 0

    # ----- sections ------------------------------------------------------
    def black_section(self):                         # $842B
        m = self.m
        self.D = 0x88
        for rec, fn in ((0x88, self.queen), (0x90, self.rook), (0x98, self.rook),
                        (0xA0, self.black_bishop), (0xA8, self.black_bishop),
                        (0xB0, self.black_knight), (0xB8, self.black_knight)):
            sq = m[BE + rec]
            if not sq & 0x80:
                fn(sq)
        self.pawns(0xF1, 0xC0)
        self.after_section()

    def white_section(self):                         # $883A
        m = self.m
        self.D = 0x88
        for rec, fn in ((0x08, self.queen), (0x10, self.rook), (0x18, self.rook),
                        (0x20, self.white_bishop), (0x28, self.white_bishop),
                        (0x30, self.white_knight), (0x38, self.white_knight)):
            sq = m[BE + rec]
            if not sq & 0x80:
                fn(sq)
        self.pawns(0x11, 0x40)
        # kings
        self.white_king(m[BE + 0x01], m[BE + 0x00])
        self.AP = (-self.AP) & 0xFF
        self.E = (-self.E) & 0xFF
        self.F |= 0x80
        self.king(m[BE + 0x81], m[BE + 0x80])
        if self.F & 0x10:
            return                                   # -> $84A9
        self.F |= 0x10
        self.black_section()

    def after_section(self):                         # $84A3
        if self.F & 0x10:
            return                                   # -> $84A9
        self.F = (self.F + 0x90) & 0xFF              # $882C
        self.E = (-self.E) & 0xFF
        self.AP = (-self.AP) & 0xFF
        self.white_section()

    # ----- pawns ---------------------------------------------------------
    def pawns(self, d, base):
        m = self.m
        self.D = d
        self.pb = 0xFF
        self.pc = 0xFF
        for i in range(8):
            rec = base + 8 * i
            sq, typ = m[BE + rec], m[BE + rec + 1]
            if sq & 0x80:
                continue
            self.pawn(sq, typ, i in (3, 4))

    def pawn(self, L, H, centre):
        m = self.m
        if centre and not ((L + 0x20) & 0x40):       # $8A54
            self.E = (self.E - 3) & 0xFF
        if H & 0x0E:                                 # $8A96 promoted
            saveD, saveB, saveC = self.D, self.pb, self.pc
            self.D = 0x88
            if H & 0x08:
                self.queen(L)
            elif H & 0x04:
                self.rook(L)
            elif H & 0x80:
                self.bishop(L)
            else:
                self.knight(L)
            self.D, self.pb, self.pc = saveD, saveB, saveC
            return
        L = (self.D + L) & 0xFF
        f = L & 0x0F
        if f == self.pb or f == self.pc:
            self.E = (self.E - 3) & 0xFF
        self.pc = self.pb
        self.pb = f
        mode = self.pawn_mode
        if mode == 0x8A6F:
            H >>= 1
            if H:
                H >>= 2
                self.AP = (self.AP + H) & 0xFF
        elif mode == 0x8A2B:
            H >>= 2
            self.AP = (self.AP + H) & 0xFF
            if (H & 0x20) and not (self.F & 0x10):
                m[BD + 0x4E] = m[BD + ((L - 1) & 0xFF)]
        a = m[BD + L]
        if a:
            self.pawn_hit(a)
        L = (L - 2) & 0xFF
        a = m[BD + L]
        if a:
            self.pawn_hit(a)

    def pawn_hit(self, code):                        # $8A85
        m = self.m
        if self.friendly(code):
            self.add(BE + code, 1)
        elif not code & 0x78:                        # $8ABA king
            if not self.F & 0x10:
                raise Abort
            m[self.ix + 3] |= 0x80
            self.E = (self.E + 1) & 0xFF
        else:
            self.add(BE + ((code - 2) & 0xFF), 1)

    # ----- knights -------------------------------------------------------
    def white_knight(self, sq):                      # $8CC8
        if not sq & 0x70:
            self.E = (self.E - 3) & 0xFF
        self.knight(sq)

    def black_knight(self, sq):                      # $8CBB
        if (sq | 0x70) == sq:
            self.E = (self.E - 3) & 0xFF
        self.knight(sq)

    def knight(self, sq):                            # $8CCD
        self.C2 = 0x04
        self.E = (self.E - 1) & 0xFF
        self.knight_walk(sq)

    def knight_walk(self, B):                        # $8CD2
        D = self.D
        if not ((B + 0x0E) & 0x80):
            for off in (0x0E, 0x12, 0x1F, 0x21):
                L = (B + off) & 0xFF
                if not L & D:
                    self.knight_target(L, B)
        if (B + 0xF2) & 0x80:
            return
        for off in (0xF2, 0xEE):
            L = (B + off) & 0xFF
            if not L & D:
                self.knight_target(L, B)
        if (B + 0xE1) & 0x80:
            return
        for off in (0xE1, 0xDF):
            L = (B + off) & 0xFF
            if not L & D:
                self.knight_target(L, B)

    def knight_target(self, L, B):                   # $8D15
        m = self.m
        self.E = (self.E + 1) & 0xFF
        code = m[BD + L]
        if not code:
            return
        if self.friendly(code):
            self.add(BE + code, self.C2)
        elif not code & 0x78:                        # $8D2A
            self.king_check(B, double_ap=True)
        else:
            self.add(BE + ((code - 2) & 0xFF), self.C2)

    def king_check(self, B, double_ap):
        """Second-pass king attacked by knight ($8D2A) or slider ($8D4C)."""
        m = self.m
        if not self.F & 0x10:
            raise Abort
        m[self.ix + 3] |= 0x80
        was = self.F & 0x40
        self.F |= 0x40
        if was:
            m[BD + 0x4E] = 0
            self.AP = (self.AP + 0x14) & 0xFF
        else:
            code = m[BD + B]
            m[BE + ((code + 1) & 0xFF)] |= 0x02
            self.E = (self.E + 2) & 0xFF

    # ----- bishops -------------------------------------------------------
    def white_bishop(self, sq):                      # $8D74
        if not sq & 0x70:
            self.E = (self.E - 3) & 0xFF
        self.bishop(sq)

    def black_bishop(self, sq):                      # $8D80
        if (sq | 0x70) == sq:
            self.E = (self.E - 3) & 0xFF
        self.bishop(sq)

    def bishop(self, sq):                            # $8D86
        self.C2 = 0x04
        self.diagonals(sq)

    def diagonals(self, B):                          # $8D89
        self.E2 = 0xC4
        for c in (0x0F, 0x11, 0xEF, 0xF1):
            self.C = c
            L = (B + c) & 0xFF
            if not L & self.D:
                self.ray_mob(L, B)

    def ray_mob(self, L, B):
        """$8DAF/$8DAA: scan counting mobility; handle the first piece hit."""
        m = self.m
        while True:
            self.E = (self.E + 1) & 0xFF
            code = m[BD + L]
            if code:
                break
            L = (L + self.C) & 0xFF
            if L & self.D:
                return
        if self.friendly(code):                      # $8DEC
            self.add(BE + code, self.C2)
            self.after_friendly(code, L)
        else:
            self.enemy_hit(code, L, B)

    def after_friendly(self, code, L):               # $8DEF
        t = self.m[BE + ((code + 2) & 0xFF)] & self.E2
        if not t:
            return
        if t & 0x80:
            self.pawn_xray(t, L)
        else:
            self.xray_chain(L)

    def pawn_xray(self, t, L):                       # $8E5C
        m = self.m
        if not (((t << 1) & 0xFF) ^ self.C) & 0x80:
            return
        L = (L + self.C) & 0xFF
        if L & self.D:
            return
        code = m[BD + L]
        if not code:
            return
        if self.friendly(code):
            self.add(BE + ((code + 1) & 0xFF), self.C2)
        else:
            self.add(BE + ((code - 1) & 0xFF), self.C2)

    def xray_chain(self, L):                         # $8DF8
        m = self.m
        while True:
            L = (L + self.C) & 0xFF
            if L & self.D:
                return
            self.E = (self.E + 1) & 0xFF
            code = m[BD + L]
            if not code:
                continue
            if not self.friendly(code):              # $8E07
                self.add(BE + ((code - 1) & 0xFF), self.C2)
                return
            self.add(BE + ((code + 1) & 0xFF), self.C2)   # $8E0D
            t = m[BE + ((code + 2) & 0xFF)] & self.E2
            if not t:
                return
            if t & 0x80:
                self.pawn_xray(t, L)
                return

    def enemy_hit(self, code, L, B):                 # $8DB9
        m = self.m
        if not code & 0x78:                          # $8D4C king
            self.king_check(B, double_ap=True)
            # $8DAA: continue the ray beyond the king, counting mobility
            L = (L + self.C) & 0xFF
            if L & self.D:
                return
            self.ray_mob(L, B)
            return
        r2 = (code - 2) & 0xFF
        self.add(BE + r2, self.C2)
        r6 = r2 | 0x04
        t = m[BE + r6] & self.E2
        if t and not t & 0x80:
            # enemy slider on this line: look beyond ($8DCD)
            while True:
                L = (L + self.C) & 0xFF
                if L & self.D:
                    return
                code2 = m[BD + L]
                if code2:
                    break
            if self.friendly(code2):                 # $8E15
                self.add(BE + ((code2 + 1) & 0xFF), self.C2)
                return
            self.add(BE + ((code2 - 1) & 0xFF), self.C2)
            self.pin_check(r6, code2)
        else:
            while True:                              # $8E19
                L = (L + self.C) & 0xFF
                if L & self.D:
                    return
                code2 = m[BD + L]
                if code2:
                    break
            if self.friendly(code2):
                return
            self.pin_check(r6, code2)

    def pin_check(self, r6, code2):                  # $8DE1
        t = self.m[BE + ((code2 + 2) & 0xFF)]
        if t & 1:
            self.pin(r6)
        elif t & 2:
            if self.C2 & 0x40:                       # $8E2B queen pinning to queen
                self.E = (self.E + 2) & 0xFF
            else:
                self.pin(r6)

    def pin(self, r6):                               # $8E2F
        m = self.m
        rec = r6 & 0xF9
        L = 0x79
        while True:
            a = m[BD + L]
            if not a:
                break
            L += 2
            if a == rec:
                m[BD + L - 1] = 0
                self.E = (self.E + 1) & 0xFF
                return
        if L >= 0x84:
            self.E = (self.E + 2) & 0xFF
            return
        m[BD + L] = rec
        m[BD + L + 1] = self.C
        m[BD + L + 2] = 0
        self.F |= 0x20
        self.E = (self.E + 2) & 0xFF

    # ----- rooks / queens ------------------------------------------------
    def rook(self, sq):                              # $8C4E
        self.C2 = 0x10
        self.orthogonals(sq)

    def queen(self, sq):                             # $8C43
        self.C2 = 0x40
        self.orthogonals(sq)
        self.diagonals(sq)

    def orthogonals(self, B):                        # $8C52
        m = self.m
        self.E2 = 0x08
        for c in (0x01, 0xFF):
            self.C = c
            L = B
            while True:
                L = (L + c) & 0xFF
                if L & 0x08:
                    break
                code = m[BD + L]
                if code:
                    self.horiz_hit(code, L, B)
                    break
        for c in (0x10, 0xF0):
            self.C = c
            L = B
            while True:
                L = (L + c) & 0xFF
                if L & 0x80:
                    break
                self.E = (self.E + 1) & 0xFF
                code = m[BD + L]
                if code:
                    if self.friendly(code):          # $8C80
                        self.add(BE + code, self.C2)
                        if m[BE + ((code + 2) & 0xFF)] & self.E2:
                            self.xray_chain(L)
                    else:
                        self.enemy_hit(code, L, B)
                    break

    def horiz_hit(self, code, L, B):                 # $8C98
        m = self.m
        if not self.friendly(code):
            self.enemy_hit(code, L, B)
            return
        self.add(BE + code, self.C2)
        if not m[BE + ((code + 2) & 0xFF)] & self.E2:
            return
        while True:                                  # $8CA7
            L = (L + self.C) & 0xFF
            if L & self.D:
                return
            code2 = m[BD + L]
            if code2:
                break
        if self.friendly(code2):
            self.add(BE + ((code2 + 1) & 0xFF), self.C2)
        else:
            self.add(BE + ((code2 - 1) & 0xFF), self.C2)

    # ----- kings ---------------------------------------------------------
    def white_king(self, H, L):                      # $8978
        m = self.m
        if not self.F & 0x01:                        # $8915
            c = ((~m[BD + 0x49]) + 0x0A) & 0xFF
            if (m[BE + 0x89] & 0x10) and not (m[BE + 0x88] & 0x80):
                self.E = (self.E + c) & 0xFF
            if (m[BE + 0x09] & 0x10) and not (m[BE + 0x08] & 0x80):
                self.E = (self.E - c) & 0xFF
        self.king(H, L)

    def king(self, H, L):                            # $897D
        m = self.m
        F = self.F
        if F & 0x04:
            self.endgame_king(H, L)
            return
        if H & 0x20:
            if H & 0xC0:
                self.king_89FB(H, L)
                return
            self.C = 0x0A
            t = (L + 0x1F) & 0xFF
            if t & 0x80:
                t = (t - 0x40) & 0xFF
            if not ((m[BD + t] | m[BD + ((t + 1) & 0xFF)] | m[BD + ((t + 2) & 0xFF)]) & 0x40):
                self.E = (self.E - 2) & 0xFF
            self.king_scan(L)
            return
        if not H & 0x10:                             # $8A0D
            self.C = 0
            self.E = (self.E + 1) & 0xFF
            self.king_scan(L)
            return
        self.E = (self.E - 6) & 0xFF                 # $8A1A
        self.C = 0x08
        if H & 0xC0:
            self.king_89FB(H, L)
            return
        self.king_scan(L)

    def king_89FB(self, H, L):
        self.C = 0x04
        self.E = (self.E - (5 if H & 0x80 else 3)) & 0xFF
        self.king_scan(L)

    def endgame_king(self, H, L):                    # $8943
        m = self.m
        F = self.F
        if not F & 0x08:
            self.C = 0x08
            self.king_scan(L)
            return
        self.C = 0x04                                # $894F
        D = (H & 0xC0) >> 3
        bd1e = m[BD + 0x1E]
        if bd1e and not ((bd1e ^ F) & 0x80):
            a = m[BD + 0x6D]                         # $88D4
            if a:
                self.AP = (self.AP + D) & 0xFF
            else:
                if not D:
                    D = 0xF6
                f = ((L & 7) + 1) >> 1
                r = L & 0x70
                if f == 2 or r in (0x30, 0x40):
                    self.AP = (self.AP + 0x10 + D) & 0xFF
                elif (L & 7) in (2, 5) or r in (0x20, 0x50):
                    self.AP = (self.AP + 0x08 + D) & 0xFF
                else:
                    self.AP = (self.AP + D) & 0xFF
            self.king_scan(L)
            return
        a = m[BD + 0x6D] if bd1e else 0
        D >>= 1                                      # $8966
        if not a and (H & 0x80):
            self.AP = (self.AP + 0x08) & 0xFF
        self.AP = (self.AP + D) & 0xFF
        self.king_scan(L)

    def king_scan(self, B):                          # $89AC
        m = self.m
        for L in ((B - 1) & 0xFF, (B + 1) & 0xFF):
            a = m[BD + L]
            if a:
                self.king_nb(a)
        t = (B + 0x10) & 0xFF
        if not t & 0x80:
            for L in (t, (t + 1) & 0xFF, (t - 1) & 0xFF):
                a = m[BD + L]
                if a:
                    self.king_nb(a)
        t = (B + 0xF0) & 0xFF
        if t & 0x80:
            return
        for L in (t, (t + 1) & 0xFF, (t - 1) & 0xFF):
            a = m[BD + L]
            if a:
                self.king_nb(a)

    def king_nb(self, code):                         # $89E2
        if self.friendly(code):
            p = (code + 1) & 0xFF
        else:
            if not ((code + 1) & 0x78):
                raise Abort
            p = (code - 1) & 0xFF
        self.add(BE + p, 1)
        if p & 0x40:
            self.AP = (self.AP + self.C) & 0xFF

    # ----- pins ----------------------------------------------------------
    def pins(self):                                  # $8E74
        m = self.m
        saveD, saveE = self.D, self.E
        i = 0x79
        while True:
            rec = m[BD + i]
            pdir = m[BD + i + 1]
            self.F = rec & 0x80
            sq = m[BE + rec]
            t = m[BE + rec + 1] & 0x8E
            self.D = 0x88
            if t == 0 or (t & 0x80 and not t & 0x02):
                self.pin_undo_pawn(sq, pdir)
            elif t & 0x80:
                self.C2 = 0xFC
                self.undo_diag(sq, pdir)
            elif t < 4:
                self.C2 = 0xFC
                self.F |= 0x10
                self.knight_walk(sq)
            elif t == 4:
                self.C2 = 0xF0
                self.undo_orth(sq, pdir)
            else:
                self.C2 = 0xC0
                self.undo_orth(sq, pdir)
                self.undo_diag(sq, pdir)
            nxt = m[BD + i + 2]
            if not nxt:
                break
            i += 2
        self.D, self.E = saveD, saveE
        m[BD + 0x79] = 0

    def pin_undo_pawn(self, sq, pdir):               # $8E9F
        m = self.m
        c0 = 0xEF if self.F & 0x80 else 0x0F
        for c in (c0, (c0 + 2) & 0xFF):
            if pdir == c or ((-pdir) & 0xFF) == c:
                continue
            code = m[BD + ((sq + c) & 0xFF)]
            if not code:
                continue
            if self.friendly(code):
                self.add(BE + code, 0xFF)
            else:
                self.add(BE + ((code - 2) & 0xFF), 0xFF)

    def undo_orth(self, sq, pdir):                   # $8ED7
        self.undo_line(sq, pdir, 0x01)
        self.undo_line(sq, pdir, 0x10)

    def undo_diag(self, sq, pdir):                   # $8EED
        self.undo_line(sq, pdir, 0x0F)
        self.undo_line(sq, pdir, 0x11)

    def undo_line(self, B, pdir, c):                 # $8EF4
        if pdir == c or ((-pdir) & 0xFF) == c:
            return
        for d in (c, (-c) & 0xFF):
            self.undo_ray(B, d)

    def undo_ray(self, B, c):                        # $8F05
        m = self.m
        L = B
        while True:
            L = (L + c) & 0xFF
            if L & 0x88:
                return
            code = m[BD + L]
            if code:
                break
        if self.friendly(code):
            self.add(BE + code, self.C2)
        else:
            self.add(BE + ((code - 2) & 0xFF), self.C2)

    # ----- exchange evaluation -------------------------------------------
    def final(self):                                 # $84A9
        m = self.m
        F = self.F
        if not F & 0x40:
            code = m[BD + m[self.ix + 2]]
            if code & 0x04:
                m[BE + ((code + 1) & 0xFF)] |= 0x02
        if F & 0x08:
            if not m[BD + 0x6D]:
                self.E = sra(self.E)
            self.E = sra(self.E)
        if F & 0x20:
            self.pins()
        self.E = (sra(sra(self.AP)) + self.E + m[BD + 0x4A]) & 0xFF
        m[BD + 0x39] = m[BD + 0x3A] = 0
        m[BD + 0x3B] = self.ix & 0xFF
        m[BD + 0x3C] = self.ix >> 8
        self.see_side(0x88)
        self.E = (-self.E) & 0xFF
        black_best, black_second = m[BD + 0x39], m[BD + 0x3A]
        m[BD + 0x39] = m[BD + 0x3A] = 0
        self.see_side(0x08)
        return self.combine(black_best, black_second)

    def see_side(self, base):
        m = self.m
        values = (9, 5, 5, 3, 3, 3, 3)
        for i in range(15):
            rec = base + 8 * i
            a = BE + rec
            if m[a + 2] or m[a + 3]:
                v = values[i] if i < 7 else (m[a + 1] & 0x0F)
                self.see(v, m[a + 2], m[a + 3], m[a + 4], m[a + 5])
                m[a + 2] = m[a + 3] = 0
            m[a + 4] = m[a + 5] = 0

    def gen_att(self, L, H):
        if L:
            for mask, sh, v in ((0x03, 0, 1), (0x0C, 2, 3), (0x30, 4, 5), (0xC0, 6, 9)):
                n = (L & mask) >> sh
                if n:
                    yield v, n
            if not H:
                return
        for mask, sh, v in ((0x0C, 2, 3), (0x30, 4, 5), (0xC0, 6, 9)):
            n = (H & mask) >> sh
            if n:
                yield v, n
        if H & 1:
            yield 13, 1

    def gen_def(self, C, B):
        if C:
            for mask, sh, v in ((0x03, 0, 1), (0x0C, 2, 3), (0x30, 4, 5), (0xC0, 6, 9)):
                n = (C & mask) >> sh
                if n:
                    yield v, n
        if not B:
            return
        for mask, sh, v in ((0x0C, 2, 3), (0x30, 4, 5), (0xC0, 6, 9)):
            n = (B & mask) >> sh
            if n:
                yield v, n
        if B & 1:
            self.E = (self.E - 1) & 0xFF             # $8C1F
            yield 13, 1

    def see(self, V, L, H, C, Bm):                   # $8AD6
        m = self.m
        if not L and not H & 1:
            return
        att = self.gen_att(L, H)
        dfn = self.gen_def(C, Bm)
        attv, attn = next(att, (0, 0))
        defv, defn = next(dfn, (0, 0))
        A = V
        lo = 0xFF
        hi = V
        while True:
            b = 0
            if not defv & 1:
                break
            A = (A - attv) & 0xFF
            attn = (attn - 1) & 0xFF
            if attn == 0:
                attv, n = next(att, (0, None))
                if n is not None:
                    attn = n
            if (A - lo) & 0x80:
                b = 1
            elif not ((A - hi) & 0x80):
                b = 2
            else:
                lo = A
            if not attv & 1:
                break
            A = (A + defv) & 0xFF
            if (A - lo) & 0x80:
                b = (b - 1) & 0xFF
                if b == 0:
                    break
            elif not ((A - hi) & 0x80):
                b = (b - 2) & 0xFF
                if b == 0:
                    break
            else:
                hi = A
            defn = (defn - 1) & 0xFF
            if defn == 0:
                defv, n = next(dfn, (0, None))
                if n is not None:
                    defn = n
        if (A - lo) & 0x80:
            A = lo
        if not ((A - hi) & 0x80):
            A = hi
        if A & 0x80:
            return
        if A:
            best = m[BD + 0x39]
            if A >= best:
                m[BD + 0x39] = A
                A = best
            if A >= m[BD + 0x3A]:
                m[BD + 0x3A] = A
        self.E = (self.E - 1) & 0xFF
        if Bm & 0x02:
            m[self.ix + 3] |= 0x04
            self.E = (self.E - 2) & 0xFF

    def combine(self, bb, bs):                       # $8797
        m = self.m
        pos = self.E
        wb, ws = m[BD + 0x39], m[BD + 0x3A]
        if m[BD + 0x2D] & 1:
            pos = (-pos) & 0xFF
            sb, ss, mb, ms = wb, ws, bb, bs
            A = m[BD + 0x0D]
        else:
            sb, ss, mb, ms = bb, bs, wb, ws
            A = (-m[BD + 0x0D]) & 0xFF
        ix3 = self.ix + 3
        A = (A - mb) & 0xFF
        A = (A + A) & 0xFF
        if not ((mb - 1) & 0x80):
            m[ix3] |= 0x02
            if mb != 1:
                A = (A - 1) & 0xFF
            A = (A - ms) & 0xFF
        if not ((sb - 1) & 0x80):
            goto_e2 = False
            if m[ix3] & 0x04:
                goto_e2 = True
            else:
                pos = (pos + 2) & 0xFF
                if (ss - 1) & 0x80:
                    goto_e2 = True
                else:
                    m[ix3] |= 0x40
                    pos = (pos + 2) & 0xFF
                    if not ((ss - 2) & 0x80):
                        pos = (pos + 2) & 0xFF
            if goto_e2 and ((sb - 1) & 0xFF) >= mb:
                m[ix3] |= 0x40
        self.B = pos
        if not (A < 0x1C or A >= 0xE4):
            return 0x02 if A & 0x80 else 0xFC
        C = (4 * A) & 0xFF
        t = sra(pos)
        t = (t + pos + (pos & 1)) & 0xFF
        t = sra(t)
        m[0xBCCE] = (m[0xBCCE] + 1) & 0xFF
        r = m[0xBCCE] & (3 if m[BD + 0x49] == 1 else 1)
        t = (r + t) & 0xFF
        if not (t < 0x0C or t >= 0xF4):
            t = 0xF4 if t & 0x80 else 0x0C
        return (t + C + 0x80) & 0xFF


def evaluate(mem, ix):
    ev = Eval(mem, ix)
    a = ev.run()
    return a, ev.B
