import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Drive the original Cyrus IS Chess in SkoolKit's Z80 simulator with scripted keypresses.

Usage:
  python -I cyrus_sim.py SNAPSHOT [--keys SCRIPT] [--seconds N] [--map FILE]
                         [--png FILE] [--out FILE] [--frames-png DIR:EVERY]

SCRIPT is a comma-separated list of steps, executed in order:
  KEY[+KEY...][/HOLD]   press keys for HOLD frames (default 3), then release
  wN                    wait N frames with no key pressed
  ws                    wait N seconds (e.g. w2.5s)
Key names: a-z, 0-9, ENTER, SPACE, CS (caps shift), SS (symbol shift).
After the script ends, the simulation continues until --seconds of emulated
time have elapsed in total.
"""

import argparse
import os
import sys

from skoolkit import CSimulator
from skoolkit.graphics import Frame, scr_udgs
from skoolkit.components import get_image_writer
from skoolkit.simulator import Simulator
from skoolkit.simutils import T, PC, from_snapshot, get_state
from skoolkit.snapshot import Snapshot, write_snapshot

FRAME = 69888

# Half-row index (bit cleared in the port's high byte) and bit within it
KEYMAP = {}
for row, keys in enumerate(('CS z x c v', 'a s d f g', 'q w e r t', '1 2 3 4 5',
                            '0 9 8 7 6', 'p o i u y', 'ENTER l k j h', 'SPACE SS m n b')):
    for bit, k in enumerate(keys.split()):
        KEYMAP[k] = (row, 1 << bit)


class KeyTracer:
    def __init__(self):
        self.keyboard = [0] * 8
        self.border = 7
        self.outfe = 0

    def press(self, names):
        self.keyboard = [0] * 8
        for n in names:
            row, bit = KEYMAP[n]
            self.keyboard[row] |= bit

    def read_port(self, registers, port):
        if port % 2 == 0:
            h = (port // 256) ^ 0xFF
            v = 0x40
            i = 0
            while h:
                if h % 2:
                    v |= self.keyboard[i]
                h //= 2
                i += 1
            return v ^ 0xFF
        return 0xFF

    def write_port(self, registers, port, value, offset=0):
        if port % 2 == 0:
            self.outfe = value
            self.border = value & 7


def parse_script(script):
    steps = []
    for item in filter(None, (s.strip() for s in script.split(','))):
        if item[0] == 'w' and len(item) > 1 and (item[1].isdigit() or item[1] == '.'):
            if item.endswith('s'):
                steps.append(('wait', round(float(item[1:-1]) * 50)))
            else:
                steps.append(('wait', int(item[1:])))
        else:
            keys, _, hold = item.partition('/')
            steps.append(('press', keys.split('+'), int(hold) if hold else 3))
    return steps


class Machine:
    def __init__(self, snapshot_file, exec_map=None):
        snap = Snapshot.get(snapshot_file)
        cls = CSimulator or Simulator
        self.sim = from_snapshot(cls, snap, config={'fast_djnz': False, 'fast_ldir': False})
        self.tracer = KeyTracer()
        self.sim.set_tracer(self.tracer)
        self.exec_map = exec_map
        self.profile = None

    @property
    def memory(self):
        return self.sim.memory

    def run_frames(self, n, stop=None):
        """Run n frames (with 50 Hz interrupts); return True if stopped at `stop`."""
        sim = self.sim
        registers = sim.registers
        memory = sim.memory
        opcodes = sim.opcodes
        exec_map = self.exec_map
        frame_duration = sim.frame_duration
        int_active = sim.int_active
        tstates = registers[T]
        target = tstates + n * FRAME
        next_int = ((tstates + frame_duration - int_active) // frame_duration) * frame_duration
        pc = registers[PC]
        profile = self.profile
        while tstates < target:
            opcodes[memory[pc]]()
            if exec_map is not None:
                exec_map.add(pc)
            if profile is not None:
                profile[pc] += 1
            tstates = registers[T]
            if tstates >= next_int:
                if tstates < next_int + int_active:
                    if registers[26]:
                        sim.accept_interrupt(registers, memory, pc)
                        tstates = registers[T]
                else:
                    next_int += frame_duration
            pc = registers[PC]
            if pc == stop:
                return True
        return False

    def run_script(self, steps):
        for step in steps:
            if step[0] == 'wait':
                self.run_frames(step[1])
            else:
                self.tracer.press(step[1])
                self.run_frames(step[2])
                self.tracer.press([])
                self.run_frames(2)

    def seconds(self):
        return self.sim.registers[T] / 3500000

    def png(self, fname):
        scr = scr_udgs(self.sim.memory, 0, 0, 32, 24)
        writer = get_image_writer()
        with open(fname, 'wb') as f:
            writer.write_image([Frame(scr, 2)], f)

    def save(self, fname):
        ram, registers, state, machine = get_state(self.sim)
        write_snapshot(fname, ram, registers, state, machine)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('snapshot')
    ap.add_argument('--keys', default='')
    ap.add_argument('--seconds', type=float, default=0)
    ap.add_argument('--map')
    ap.add_argument('--png')
    ap.add_argument('--out')
    ap.add_argument('--profile', help='write per-address execution counts to FILE')
    args = ap.parse_args()

    exec_map = set() if args.map else None
    m = Machine(args.snapshot, exec_map)
    if args.profile:
        m.profile = [0] * 65536
    start = m.seconds()
    m.run_script(parse_script(args.keys))
    remaining = args.seconds - (m.seconds() - start)
    if remaining > 0:
        m.run_frames(round(remaining * 50))
    print(f'Emulated {m.seconds() - start:.2f}s, PC=${m.sim.registers[PC]:04X}')
    if args.map:
        old = set()
        if os.path.exists(args.map):
            with open(args.map) as f:
                old = {int(l.strip()[1:], 16) for l in f if l.strip()}
        with open(args.map, 'w') as f:
            for a in sorted(exec_map | old):
                f.write(f'${a:04X}\n')
        print(f'Map: {len(exec_map)} addresses this run, {len(exec_map | old)} total')
    if args.profile:
        with open(args.profile, 'w') as f:
            for a, n in enumerate(m.profile):
                if n:
                    f.write(f'${a:04X} {n}\n')
    if args.png:
        m.png(args.png)
    if args.out:
        m.save(args.out)


if __name__ == '__main__':
    main()
