"""Decode the Cyrus IS Chess (48K) opening book into a readable move tree.

The book ($9000-$9BCC) is a pre-order tree of 9-bit entries. Each entry names a
move by its index in the move list that the original move generator ($78CE)
produces for the position, so indices are resolved by replaying every book
line in the original program (SkoolKit simulator), using the program's own
"forward replay" path ($C003 -> $6690), and reading the move list at $B404
when the program is next idle at YOUR MOVE?.

Usage:
  python -I book_dump.py [--snapshot FILE] [--out FILE] [--check-replay]

Output: an indented tree. Each line shows the move, its list index and flags:
  leaf  bit 7: no continuation stored (choosing it ends book play)
  M     the entry's leading (9th) bit (see docs/arch/25-book.md)
"""

import argparse
import os
import sys

from skoolkit.simulator import Simulator
from skoolkit.simutils import PC, T, from_snapshot
from skoolkit.snapshot import Snapshot

BOOK = 0x9000
FRAME = 69888
IDLE = range(0x675F, 0x676A)       # key-wait loop in $675A
REPLAY_GEN_RET = 0x66BE            # just after CALL $78CE in the replay routine
FILES = 'abcdefgh'
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def book_entry(mem, n):
    """Exactly what $7B64 returns: (A, CF) for 9-bit entry n."""
    off = BOOK + n + (n >> 3)
    a, c, cf = mem[off], mem[off + 1], 0
    for _ in range((n & 7) + 1):
        c, cf = ((c << 1) & 0xFF) | cf, c >> 7          # RL C
        a, cf = ((a << 1) & 0xFF) | cf, a >> 7          # RLA
    return a, cf


def parse_tree(mem):
    """Return the root sibling list as nested nodes; also the entry count."""
    pos = [0]

    def siblings():
        out = []
        while True:
            n = pos[0]
            a, m = book_entry(mem, n)
            pos[0] += 1
            node = {'n': n, 'index': a & 0x3F, 'leaf': a >> 7, 'more': (a >> 6) & 1,
                    'M': m, 'children': []}
            if not node['leaf']:
                node['children'] = siblings()
            out.append(node)
            if not node['more']:
                return out

    return siblings(), pos[0]


class Machine:
    def __init__(self, snapshot_file):
        snap = Snapshot.get(snapshot_file)
        self.sim = from_snapshot(Simulator, snap, config={'fast_djnz': False, 'fast_ldir': False})
        self.sim.set_tracer(self)

    # tracer interface: no keys pressed
    def read_port(self, registers, port):
        return 0xBF if port % 2 == 0 else 0xFF

    def write_port(self, registers, port, value, offset=0):
        pass

    def run_until(self, pcs, max_tstates):
        sim = self.sim
        registers, memory, opcodes = sim.registers, sim.memory, sim.opcodes
        frame_duration, int_active = sim.frame_duration, sim.int_active
        tstates = registers[T]
        limit = tstates + max_tstates
        next_int = ((tstates + frame_duration - int_active) // frame_duration) * frame_duration
        pc = registers[PC]
        while tstates < limit:
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
            if pc in pcs:
                return pc
        raise RuntimeError(f'timeout, PC=${pc:04X}')

    def save(self):
        return list(self.sim.memory), list(self.sim.registers)

    def restore(self, state):
        mem, regs = state
        self.sim.memory[:] = mem
        for i, v in enumerate(regs):
            self.sim.registers[i] = v

    def move_list(self):
        mem = self.sim.memory
        count = mem[0xB401]
        return [(mem[a + 1], mem[a + 2], mem[a + 3]) for a in range(0xB404, 0xB404 + 4 * count, 4)]

    def play_index(self, index, check=False):
        """Replay one more move through the program's own forward-replay path.

        The game-record byte is the list index plus bit 7 = "this move gives
        check", exactly as $6360 records it. The check bit matters: replay
        ($66C4) restores it into the last-move flags at $BD5B, and the move
        generator ($7A61) omits castling when it is set.
        """
        mem = self.sim.memory
        record = index | (mem[0xB404 + 4 * index + 3] & 0x80)
        ply = mem[0xC001] + 256 * mem[0xC002]
        mem[0xC058 + ply] = record
        mem[0xC059 + ply] = 0xFF
        target = ply + 1
        mem[0xC003], mem[0xC004] = target % 256, target // 256
        self.sim.registers[PC] = 0x60B7
        replay_list = None
        if check:
            self.run_until({REPLAY_GEN_RET}, 50_000_000)
            replay_list = self.move_list()
        self.run_until(IDLE, 200_000_000)
        return replay_list


def square(sq):
    return FILES[sq & 7] + str(8 - (sq >> 4))


def describe(mem, move):
    frm, to, flags = move
    code = mem[0xBD00 + frm]
    kind = mem[0xBE00 + (code & 0xFB) + 1]
    letter = {0: 'K', 9: 'Q', 5: 'R', 3: 'B' if kind & 0x80 else 'N', 1: ''}.get(kind & 0x0F, '?')
    sep = 'x' if mem[0xBD00 + to] else '-'
    return f'{letter}{square(frm)}{sep}{square(to)}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--snapshot', default=os.path.join(ROOT, 'reference', 'snapshots', 'cyrus48-entry-6000.z80'))
    ap.add_argument('--out', default=os.path.join(ROOT, 'docs', 'arch', 'book-tree.txt'))
    ap.add_argument('--check-replay', action='store_true',
                    help='also verify that the replay-time move list equals the idle-time list')
    ap.add_argument('--uci-out', metavar='FILE',
                    help='also write every book node as "<uci moves from the start> | flags" (one per line)')
    args = ap.parse_args()

    m = Machine(args.snapshot)
    m.run_until(IDLE, 50_000_000)          # program start-up → YOUR MOVE? at the start position
    tree, used = parse_tree(m.sim.memory)
    stats = {'nodes': 0, 'leaves': 0, 'M': 0, 'maxdepth': 0, 'mismatch': 0, 'badindex': 0}
    lines = []
    uci_lines = []

    def walk(nodes, depth, state, moves_list, path=()):
        for node in nodes:
            stats['nodes'] += 1
            stats['leaves'] += node['leaf']
            stats['M'] += node['M']
            stats['maxdepth'] = max(stats['maxdepth'], depth)
            idx = node['index']
            m.restore(state)
            mem = m.sim.memory
            if idx >= len(moves_list):
                stats['badindex'] += 1
                text = f'?index {idx} of {len(moves_list)}'
            else:
                text = describe(mem, moves_list[idx])
            uci = square(moves_list[idx][0]) + square(moves_list[idx][1]) if idx < len(moves_list) else '????'
            uci_lines.append(' '.join(path + (uci,)) + f" | index={idx} leaf={node['leaf']} more={node['more']} M={node['M']}")
            ply = depth - 1
            num = f'{ply // 2 + 1}.' if ply % 2 == 0 else f'{ply // 2 + 1}...'
            tags = ' '.join(t for t, on in (('leaf', node['leaf']), ('M', node['M'])) if on)
            lines.append(f"{'  ' * ply}{num}{text}  [{idx}]{('  ' + tags) if tags else ''}")
            if node['children'] and idx < len(moves_list):
                replay = m.play_index(idx, args.check_replay)
                # Root scoring ($7B96, via make/eval) writes extra bits into the
                # flags byte after generation, so compare from/to order only.
                if replay is not None and [(f, t) for f, t, _ in replay] != \
                        [(f, t) for f, t, _ in moves_list]:
                    stats['mismatch'] += 1
                walk(node['children'], depth + 1, m.save(), m.move_list(), path + (uci,))
        m.restore(state)

    walk(tree, 1, m.save(), m.move_list())
    header = [
        'Cyrus IS Chess (48K) opening book, decoded from $9000 by tools/scripts/book_dump.py',
        f"entries: {stats['nodes']} (bits used {9 * used} of 32768; book ends at ${BOOK + (9 * used + 7) // 8 - 1:04X})",
        f"leaf entries: {stats['leaves']}, entries with leading bit M: {stats['M']}, max depth (plies): {stats['maxdepth']}",
        f"bad indices: {stats['badindex']}" + (f", replay/idle list mismatches: {stats['mismatch']}" if args.check_replay else ''),
        'Notation: from-to squares; [n] = index in the generated move list; leaf = no stored continuation;',
        'M = leading bit (raises the first sibling\'s pick chance; on a later sibling it stops the choice there).',
        '',
    ]
    with open(args.out, 'w') as f:
        f.write('\n'.join(header + lines) + '\n')
    if args.uci_out:
        with open(args.uci_out, 'w') as f:
            f.write('\n'.join(uci_lines) + '\n')
    print('\n'.join(header[:4]))


if __name__ == '__main__':
    main()
