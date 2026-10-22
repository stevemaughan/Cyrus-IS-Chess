import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Capture calls to the evaluation routine $8400 from the original program.

Usage: python -I capture.py SNAPSHOT KEYS SECONDS OUT.jsonl [EVERY]

For every EVERY-th call to $8400 records the state of $BC00-$BEFF, IX, the
4 bytes at IX, then runs to the matching return and records A, B, C and the
same memory afterwards.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cyrus_sim import Machine, parse_script, FRAME  # noqa: E402
from skoolkit.simutils import T, PC, SP  # noqa: E402

EVAL = 0x8400
A, F, B, C, D, E, H, L, IXh, IXl, IYh, IYl = range(12)


def run_until(m, target_t, on_eval):
    sim = m.sim
    registers = sim.registers
    memory = sim.memory
    opcodes = sim.opcodes
    frame_duration = sim.frame_duration
    int_active = sim.int_active
    tstates = registers[T]
    next_int = ((tstates + frame_duration - int_active) // frame_duration) * frame_duration
    pc = registers[PC]
    while tstates < target_t:
        if pc == EVAL:
            on_eval(m)
            tstates = registers[T]
            next_int = ((tstates + frame_duration - int_active) // frame_duration) * frame_duration
            pc = registers[PC]
            continue
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


class Recorder:
    def __init__(self, out, every):
        self.out = out
        self.every = every
        self.count = 0
        self.written = 0
        self.cov = set()

    def __call__(self, m):
        sim = m.sim
        r = sim.registers
        mem = sim.memory
        opcodes = sim.opcodes
        record = (self.count % self.every) == 0
        self.count += 1
        sp = r[SP]
        ret = mem[sp] + 256 * mem[sp + 1]
        ix = r[IXh] * 256 + r[IXl]
        if record:
            before = bytes(mem[0xBC00:0xBF00])
            ixb = list(mem[ix:ix + 4])
        # execute until return to caller
        pc = r[PC]
        n = 0
        cov = self.cov
        while True:
            cov.add(pc)
            opcodes[mem[pc]]()
            n += 1
            pc = r[PC]
            if pc == ret and r[SP] == sp + 2:
                break
        if record:
            after = bytes(mem[0xBC00:0xBF00])
            self.out.write(json.dumps({
                'n': self.count - 1, 'ix': ix, 'ixb': ixb, 'ixa': list(mem[ix:ix + 4]),
                'before': before.hex(), 'after': after.hex(),
                'a': r[A], 'b': r[B], 'c': r[C], 'ret': ret, 'instr': n,
            }) + '\n')
            self.written += 1


def main():
    snap, keys, seconds, outname = sys.argv[1:5]
    every = int(sys.argv[5]) if len(sys.argv) > 5 else 1
    m = Machine(snap)
    with open(outname, 'w') as out:
        rec = Recorder(out, every)
        for step in parse_script(keys):
            if step[0] == 'wait':
                run_until(m, m.sim.registers[T] + step[1] * FRAME, rec)
            else:
                m.tracer.press(step[1])
                run_until(m, m.sim.registers[T] + step[2] * FRAME, rec)
                m.tracer.press([])
                run_until(m, m.sim.registers[T] + 2 * FRAME, rec)
        end = m.sim.registers[T] + int(float(seconds) * 50) * FRAME
        run_until(m, end, rec)
    print(f'{rec.count} eval calls, {rec.written} recorded, {m.seconds():.1f}s emulated')
    with open(outname + '.cov', 'w') as f:
        for a in sorted(rec.cov):
            f.write(f'${a:04X}\n')
    if len(sys.argv) > 6:
        m.save(sys.argv[6])


if __name__ == '__main__':
    main()
