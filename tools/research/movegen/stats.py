import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Run demo play and gather move-generator statistics at each $78CE call / return."""
import sys
sys.path.insert(0, SCRIPTS)
from cyrus_sim import Machine, parse_script
from skoolkit.simutils import PC, SP, T

snap, keys, seconds = sys.argv[1], sys.argv[2], float(sys.argv[3])
m = Machine(snap)
m.run_script(parse_script(keys))
mem = m.memory
r = m.sim.registers
op = m.sim.opcodes
cells = [0xBD00 + rank * 16 + c for rank in range(8) for c in (8, 15)]
end_t = r[T] + int(seconds * 3500000)
calls = 0
maxply = 0
minsp = 0xFFFF
maxend = 0
maxn = 0
nonzero = {}
makes = 0
minsp_any = 0xFFFF
hist = {}
next_int = ((r[T] + 69888 - 32) // 69888) * 69888
while r[T] < end_t:
    pc = r[PC]
    if pc == 0x78CE:
        calls += 1
        ply = mem[0xBCA9]
        maxply = max(maxply, ply)
        hist[ply] = hist.get(ply, 0) + 1
        minsp = min(minsp, r[SP])
        for c in cells:
            if mem[c]:
                nonzero.setdefault(f'{c:04X}={mem[c]:02X}', 0)
                nonzero[f'{c:04X}={mem[c]:02X}'] += 1
    elif pc == 0x79C7:
        ply = mem[0xBCA9]
        tbl = 0xBCA9 + 2 * ply
        end = mem[tbl + 2] | mem[tbl + 3] << 8
        start = mem[tbl] | mem[tbl + 1] << 8
        maxend = max(maxend, end)
        maxn = max(maxn, (end - start) // 4 - 1)
    elif pc == 0x810F:
        makes += 1
    if r[SP] < minsp_any and r[SP] > 0x8000:
        minsp_any = r[SP]
    op[mem[pc]]()
    t = r[T]
    if t >= next_int:
        if t < next_int + 32:
            if r[26]:
                m.sim.accept_interrupt(r, mem, r[PC])
        else:
            next_int += 69888
print(f'gen calls={calls} makes={makes} max ply={maxply} ply hist={dict(sorted(hist.items()))}')
print(f'min SP at gen=${minsp:04X} min SP overall=${minsp_any:04X} max list end=${maxend:04X} max moves/list={maxn}')
print('nonzero off-board cells at gen:', nonzero)
m.png(sys.argv[4]) if len(sys.argv) > 4 else None
