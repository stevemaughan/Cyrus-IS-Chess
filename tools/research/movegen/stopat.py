import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Run snapshot with keys until PC hits an address (n-th time); dump move list of current ply,
board and selected variables. Optionally save snapshot."""
import sys
sys.path.insert(0, SCRIPTS)
sys.path.insert(0, HERE)
from cyrus_sim import Machine, parse_script
from probe import sqname, fmt
from skoolkit.simutils import PC, SP, T, IXh, IXl

snap, keys, addr, nth = sys.argv[1], sys.argv[2], int(sys.argv[3], 16), int(sys.argv[4])
out = sys.argv[5] if len(sys.argv) > 5 else None
m = Machine(snap)
steps = parse_script(keys)
# press keys but stop as soon as the address is hit
hits = 0
r = m.sim.registers
mem = m.memory
def run_until(frames):
    global hits
    for _ in range(frames):
        if m.run_frames(1, stop=addr):
            hits += 1
            if hits >= nth:
                return True
            m.sim.opcodes[mem[r[PC]]]()
    return False
done = False
for st in steps:
    if st[0] == 'wait':
        if run_until(st[1]): done = True; break
    else:
        m.tracer.press(st[1])
        if run_until(st[2]): done = True; break
        m.tracer.press([])
if not done:
    done = run_until(6000)
m.tracer.press([])
print('stopped' if done else 'NOT stopped', f'PC=${r[PC]:04X} T={r[T]}')
ply = mem[0xBCA9]
tbl = 0xBCA9 + 2 * ply
start = mem[tbl] | mem[tbl + 1] << 8
end = mem[tbl + 2] | mem[tbl + 3] << 8
print(f'ply={ply} BD2D={mem[0xBD2D]:02X} list ${start:04X}-${end:04X} hdr={mem[start:start+4]} IX=${r[IXh]*256+r[IXl]:04X}')
a = start + 4
mv = []
while a < end and a < start + 4 * 130:
    mv.append(tuple(mem[a:a + 4])); a += 4
print(' '.join(f'{fmt(x)}:{x[0]:02X}' for x in mv))
for rank in range(7, -1, -1):
    print(' '.join(f'{mem[0xBD00 + rank * 16 + f]:02X}' for f in range(16)))
if out:
    m.save(out)
