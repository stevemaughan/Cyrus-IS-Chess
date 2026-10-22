import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ROOT = _os.path.normpath(_os.path.join(HERE, '..', '..', '..'))
SCRIPTS = _os.path.join(ROOT, 'tools', 'scripts')
ENTRY = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80')
LVL1 = _os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-idle-level1.z80')
WORK = _os.path.join(HERE, 'work')
_os.makedirs(WORK, exist_ok=True)
"""Run a snapshot with keys and log entries to selected addresses with some state."""
import sys
sys.path.insert(0, SCRIPTS)
from cyrus_sim import Machine, parse_script
from skoolkit.simutils import PC, SP, T

snap, keys, watch, limit = sys.argv[1], sys.argv[2], [int(a, 16) for a in sys.argv[3].split(',')], int(sys.argv[4])
m = Machine(snap)
m.run_script(parse_script(keys))
mem = m.memory
r = m.sim.registers
n = 0
frames = 0
while n < limit and frames < 3000:
    hit = False
    for w in watch:
        pass
    # run until any watch address
    stopped = False
    for _ in range(50):
        # run one frame, checking each watch via a small loop
        sim = m.sim
        target = r[T] + 69888
        opcodes = sim.opcodes
        while r[T] < target:
            opcodes[mem[r[PC]]]()
            if r[PC] in watch:
                stopped = True
                break
        if stopped:
            break
    frames += 1
    if not stopped:
        continue
    pc = r[PC]
    sp = r[SP]
    ret = mem[sp] | mem[sp + 1] << 8
    print(f'${pc:04X} from ${ret:04X} BD2D={mem[0xBD2D]:02X} BCA9={mem[0xBCA9]} SP=${sp:04X} T={r[T]}')
    n += 1
    opcodes[mem[r[PC]]]()  # step past
