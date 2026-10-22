import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Instrumented simulator for search analysis (agent C)."""
import sys
sys.path.insert(0, SCRIPTS)
from cyrus_sim import Machine, parse_script, FRAME, KEYMAP  # noqa
from skoolkit.simutils import T, PC


class HMachine(Machine):
    def __init__(self, snap):
        super().__init__(snap)
        self.hooks = {}
        self.stop_flag = False

    def run_until(self, max_frames, stop_pc=None):
        """Run with hooks; stop at stop_pc or when a hook sets stop_flag."""
        sim = self.sim
        registers = sim.registers
        memory = sim.memory
        opcodes = sim.opcodes
        hooks = self.hooks
        frame_duration = sim.frame_duration
        int_active = sim.int_active
        tstates = registers[T]
        target = tstates + max_frames * FRAME
        next_int = ((tstates + frame_duration - int_active) // frame_duration) * frame_duration
        pc = registers[PC]
        self.stop_flag = False
        while tstates < target:
            h = hooks.get(pc)
            if h is not None:
                h(self)
                if self.stop_flag:
                    return True
            opcodes[memory[pc]]()
            tstates = registers[T]
            if tstates >= next_int:
                if tstates < next_int + int_active:
                    if registers[26]:
                        sim.accept_interrupt(registers, memory, pc)
                        tstates = registers[T]
                else:
                    next_int += frame_duration
            pc = registers[PC]
            if pc == stop_pc:
                return True
        return False

    def reg(self, name):
        r = self.sim.registers
        idx = {'A': 0, 'F': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'H': 6, 'L': 7}
        if name in ('BC', 'DE', 'HL'):
            return r[idx[name[0]]] * 256 + r[idx[name[1]]]
        if name == 'IX':
            return r[8] * 256 + r[9]
        if name == 'SP':
            return r[12]
        return r[idx[name]]

    def m(self, a):
        return self.sim.memory[a]

    def w(self, a):
        return self.sim.memory[a] + 256 * self.sim.memory[a + 1]


def sq(s):
    return 'abcdefgh'[s & 7] + str((s >> 4) + 1) if not s & 0x88 else f'?{s:02X}'


def board(mm):
    rows = []
    for r in range(7, -1, -1):
        row = ''
        for f in range(8):
            c = mm.m(0xBD00 + r * 16 + f)
            if c == 0:
                row += '.'
            else:
                rec = 0xBE00 + (c & 0xFB)
                v = mm.m(rec + 1)
                t = {0: 'k', 9: 'q', 5: 'r', 3: 'n', 1: 'p'}.get(v & 0x0F, '?')
                if v & 0x80 and (v & 0x0F) == 3:
                    t = 'b'
                row += t if c & 0x80 else t.upper()
        rows.append(row)
    return '\n'.join(rows)
