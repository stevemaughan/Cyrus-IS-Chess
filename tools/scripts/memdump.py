"""Hex-dump a memory range from a Z80/SZX/SNA snapshot.

Usage: python -I memdump.py SNAPSHOT START END [WIDTH]
"""

import sys

from skoolkit.snapshot import Snapshot


def main():
    mem = [0] * 16384 + list(Snapshot.get(sys.argv[1]).ram(-1))
    start, end = int(sys.argv[2], 0), int(sys.argv[3], 0)
    width = int(sys.argv[4]) if len(sys.argv) > 4 else 16
    for a in range(start, end, width):
        row = mem[a:min(a + width, end)]
        print(f'{a:04X}: ' + ' '.join(f'{b:02X}' for b in row))


if __name__ == '__main__':
    main()
