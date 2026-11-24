"""Check that a Windows executable imports nothing Windows 7 lacks.

The Windows 7 build (zig build -Dwin7=true, src/win7_io.zig) exists because
the standard build imports ntdll functions that first appeared in Windows 8,
and Windows refuses to start a program with an import it cannot resolve. This
script reads the import table of each executable given and fails if any import
is outside the list below, so that a change to the engine or to Zig cannot
quietly bring such a function back.

Every name in WIN7_IMPORTS is in Windows 7 (most date from Windows NT 3.1; the
slim lock, condition variable and RtlExitUserProcess calls from Windows Vista).
Add a name only after checking that Windows 7 SP1 exports it.

    python tools/scripts/check_win7_imports.py EXE [EXE ...]

Exit status 0 = every import is on the list.
"""

import struct
import sys

WIN7_IMPORTS = {
    'kernel32.dll': {
        'AcquireSRWLockExclusive', 'CloseHandle', 'CreateEventW', 'CreateThread', 'ExitProcess',
        'GetFileType', 'GetLastError', 'GetOverlappedResult', 'GetStdHandle',
        'GetSystemTimeAsFileTime', 'QueryPerformanceCounter', 'QueryPerformanceFrequency',
        'ReadFile', 'ReleaseSRWLockExclusive', 'Sleep', 'SleepConditionVariableSRW',
        'WaitForSingleObject', 'WakeAllConditionVariable', 'WriteFile',
    },
    'ntdll.dll': {
        'NtAllocateVirtualMemory', 'NtFreeVirtualMemory', 'RtlExitUserProcess',
    },
}


def imports(path):
    """{dll name in lower case: [imported names]} from the PE file at `path`."""
    d = open(path, 'rb').read()
    pe = struct.unpack_from('<I', d, 0x3C)[0]
    if d[:2] != b'MZ' or d[pe:pe + 4] != b'PE\0\0':
        raise ValueError(f'{path}: not a PE file')
    sections = struct.unpack_from('<H', d, pe + 6)[0]
    optional_size = struct.unpack_from('<H', d, pe + 20)[0]
    optional = pe + 24
    pe32_plus = struct.unpack_from('<H', d, optional)[0] == 0x20B
    import_rva = struct.unpack_from('<I', d, optional + (112 if pe32_plus else 96) + 8)[0]
    table = []
    for i in range(sections):
        s = optional + optional_size + 40 * i
        virtual_size, virtual_address, raw_size, raw = struct.unpack_from('<IIII', d, s + 8)
        table.append((virtual_address, max(virtual_size, raw_size), raw))

    def offset(rva):
        for virtual_address, size, raw in table:
            if virtual_address <= rva < virtual_address + size:
                return rva - virtual_address + raw
        raise ValueError(f'{path}: address {rva:#x} is in no section')

    def text(o):
        return d[o:d.index(b'\0', o)].decode('ascii')

    found = {}
    if not import_rva:
        return found
    entry = offset(import_rva)
    size, fmt, by_ordinal = (8, '<Q', 1 << 63) if pe32_plus else (4, '<I', 1 << 31)
    while True:
        lookup, _, _, name, address = struct.unpack_from('<IIIII', d, entry)
        if not name:
            return found
        names = found.setdefault(text(offset(name)).lower(), [])
        thunk = offset(lookup or address)
        while True:
            value = struct.unpack_from(fmt, d, thunk)[0]
            if not value:
                break
            names.append(f'ordinal {value & 0xFFFF}' if value & by_ordinal else text(offset(value & 0x7FFFFFFF) + 2))
            thunk += size
        entry += 20


def unexpected(path):
    """The imports of `path` that are not known to be in Windows 7."""
    return [f'{dll}: {name}' for dll, names in sorted(imports(path).items())
            for name in sorted(names) if name not in WIN7_IMPORTS.get(dll, ())]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    failed = False
    for path in sys.argv[1:]:
        bad = unexpected(path)
        count = sum(len(names) for names in imports(path).values())
        if bad:
            failed = True
            print(f'FAIL {path}: not known to be in Windows 7:')
            for b in bad:
                print(f'    {b}')
        else:
            print(f'ok   {path}: {count} imports, all in Windows 7')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
