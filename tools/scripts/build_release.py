"""Build the ReleaseFast binaries for every release platform and package them
(AGENTS.md section 6, Phase 6).

One binary per platform, for the baseline CPU of each architecture, so it runs
on any machine of that kind. Linux builds are static (musl). Output: dist/,
with one archive per platform (README.md and LICENSE included) and
SHA256SUMS.txt.

Usage: python tools/scripts/build_release.py VERSION     e.g. 1.0.0
"""

import hashlib
import io
import os
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))

# (asset name, zig target, zig cpu)
TARGETS = [
    ('windows-x86_64', 'x86_64-windows', 'baseline'),
    ('windows-arm64', 'aarch64-windows', 'baseline'),
    ('linux-x86_64', 'x86_64-linux-musl', 'baseline'),
    ('linux-arm64', 'aarch64-linux-musl', 'baseline'),
    # 32-bit Raspberry Pi OS and other ARMv6/v7 hard-float boards
    ('linux-armv6hf', 'arm-linux-musleabihf', 'arm1176jzf_s'),
    ('macos-x86_64', 'x86_64-macos', 'baseline'),
    ('macos-arm64', 'aarch64-macos', 'baseline'),
]

EXTRAS = ['README.md', 'LICENSE']


def build(target, cpu, prefix):
    cmd = ['zig', 'build', '-Doptimize=ReleaseFast', '-Dstrip=true', f'-Dtarget={target}', f'-Dcpu={cpu}', '-p', prefix]
    print(' '.join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def package(version, asset, exe_path, dist):
    base = f'cyrus-is-chess-{version}-{asset}'
    windows = asset.startswith('windows')
    exe_name = 'cyrus.exe' if windows else 'cyrus'
    if windows:
        out = os.path.join(dist, base + '.zip')
        with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            z.write(exe_path, f'{base}/{exe_name}')
            for x in EXTRAS:
                z.write(os.path.join(ROOT, x), f'{base}/{x}')
    else:
        out = os.path.join(dist, base + '.tar.gz')
        with tarfile.open(out, 'w:gz', compresslevel=9) as t:
            def add(path, arcname, mode):
                info = t.gettarinfo(path, arcname)
                info.mode = mode
                info.uid = info.gid = 0
                info.uname = info.gname = ''
                with open(path, 'rb') as f:
                    t.addfile(info, f)
            add(exe_path, f'{base}/{exe_name}', 0o755)
            for x in EXTRAS:
                add(os.path.join(ROOT, x), f'{base}/{x}', 0o644)
    return out


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    version = sys.argv[1]
    dist = os.path.join(ROOT, 'dist')
    shutil.rmtree(dist, ignore_errors=True)
    os.makedirs(dist)
    archives = []
    for asset, target, cpu in TARGETS:
        prefix = os.path.join(dist, 'build', asset)
        build(target, cpu, prefix)
        exe = os.path.join(prefix, 'bin', 'cyrus.exe' if asset.startswith('windows') else 'cyrus')
        archives.append(package(version, asset, exe, dist))
    with open(os.path.join(dist, 'SHA256SUMS.txt'), 'w', newline='\n') as f:
        for a in archives:
            h = hashlib.sha256(open(a, 'rb').read()).hexdigest()
            f.write(f'{h}  {os.path.basename(a)}\n')
    for a in archives:
        print(f'{os.path.getsize(a):>9}  {os.path.basename(a)}')


if __name__ == '__main__':
    main()
