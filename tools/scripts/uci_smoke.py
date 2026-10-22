"""UCI smoke test of the built engine (docs/UCI.md).

Runs zig-out/bin/cyrus(.exe) (or the path given) as a subprocess and drives it
through every `go` parameter, ponder / ponderhit, stop, isready during a
search, rejected positions and the Level combo values. Checks that every `go`
produces exactly one `bestmove`. Exit status 0 = all checks passed.

    python tools/scripts/uci_smoke.py [path-to-engine]
"""

import os
import queue
import subprocess
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXE = os.path.join(ROOT, "zig-out", "bin", "cyrus.exe" if os.name == "nt" else "cyrus")

MIDGAME = "position startpos moves e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6"
LEVELS = ["UCI"] + [f"Level {n}" for n in range(1, 9)] + ["Level P1", "Level P2", "Level P3"]


class Engine:
    def __init__(self, path):
        self.p = subprocess.Popen([path], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  text=True, bufsize=1)
        self.q = queue.Queue()
        self.log = []
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.p.stdout:
            self.q.put(line.rstrip("\r\n"))
        self.q.put(None)

    def send(self, cmd):
        self.log.append("< " + cmd)
        self.p.stdin.write(cmd + "\n")
        self.p.stdin.flush()

    def until(self, prefix, timeout=30.0):
        """Lines up to and including the first one starting with `prefix`."""
        out = []
        end = time.monotonic() + timeout
        while True:
            try:
                line = self.q.get(timeout=max(0.01, end - time.monotonic()))
            except queue.Empty:
                raise AssertionError(f"timeout waiting for {prefix!r}; got {out[-5:]}")
            if line is None:
                raise AssertionError(f"engine exited waiting for {prefix!r}")
            self.log.append("> " + line)
            out.append(line)
            if line.startswith(prefix):
                return out

    def quiet(self, seconds):
        """Lines that arrive within `seconds` (none expected after bestmove)."""
        out = []
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            try:
                line = self.q.get(timeout=max(0.01, end - time.monotonic()))
            except queue.Empty:
                break
            if line is None:
                break
            self.log.append("> " + line)
            out.append(line)
        return out

    def go(self, cmd, timeout=60.0):
        """Send a `go`, return (lines, bestmove token); check bestmove is single."""
        self.send(cmd)
        lines = self.until("bestmove", timeout)
        self.send("isready")
        tail = self.until("readyok")
        assert not any(l.startswith("bestmove") for l in tail), f"second bestmove after {cmd!r}"
        return lines, lines[-1].split()[1]


checks = 0


def check(cond, what):
    global checks
    checks += 1
    if not cond:
        raise AssertionError(what)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else EXE
    e = Engine(path)
    try:
        run(e)
    except AssertionError as err:
        print("FAILED:", err)
        print("\n".join(e.log[-40:]))
        e.p.kill()
        return 1
    print(f"uci_smoke: {checks} checks passed")
    return 0


def run(e):
    e.send("uci")
    ident = e.until("uciok")
    for opt in ("Level", "Profile", "OwnBook", "Ponder", "Move Overhead",
                "UCI_ShowCurrLine", "UCI_ShowRefutations", "Seed"):
        check(any(l.startswith(f"option name {opt} type") for l in ident), f"option {opt}")
    check("id author Richard Lang" in ident, "author")
    e.send("isready")
    e.until("readyok")
    e.send("setoption name Seed value 7")
    e.send("setoption name Move Overhead value 20")
    e.send("ucinewgame")

    # every go parameter
    e.send("position startpos")
    _, bm = e.go("go depth 4")
    check(len(bm) >= 4, "depth")
    e.send("setoption name OwnBook value false")
    e.send(MIDGAME)
    lines, bm = e.go("go depth 5")
    check(any(l.startswith("info depth 5") for l in lines), "info depth 5")
    check(any(" pv " in l and " nodes " in l and " score " in l for l in lines), "info fields")
    _, bm = e.go("go nodes 20000")
    check(len(bm) >= 4, "nodes")
    t = time.monotonic()
    _, bm = e.go("go movetime 500")
    dt = time.monotonic() - t
    check(len(bm) >= 4 and dt < 1.5, f"movetime 500 took {dt:.2f}s")
    e.send(MIDGAME)
    t = time.monotonic()
    _, bm = e.go("go wtime 3000 btime 3000 winc 100 binc 100 movestogo 20")
    dt = time.monotonic() - t
    check(len(bm) >= 4 and dt < 3.0, f"clock took {dt:.2f}s")
    e.send(MIDGAME)
    _, bm = e.go("go searchmoves h2h3 a2a3 depth 4")
    check(bm in ("h2h3", "a2a3"), f"searchmoves gave {bm}")
    e.send("position fen kbK5/pp6/1P6/8/8/8/8/R7 w - - 0 1")
    _, bm = e.go("go mate 2")
    check(bm == "a1a6", f"mate 2 gave {bm}")

    # infinite, isready during the search, stop
    e.send(MIDGAME)
    e.send("go infinite")
    time.sleep(0.5)
    e.send("isready")
    got = e.until("readyok", 5)
    check(not any(l.startswith("bestmove") for l in got), "bestmove before stop (infinite)")
    time.sleep(0.3)
    e.send("stop")
    e.until("bestmove", 5)
    e.send("isready")
    check(not any(l.startswith("bestmove") for l in e.until("readyok")), "second bestmove after stop")

    # ponder: ponderhit, then a ponder miss (stop)
    e.send("setoption name Ponder value true")
    e.send(MIDGAME + " c1e3")
    e.send("go ponder wtime 2000 btime 2000")
    time.sleep(0.3)
    got = e.quiet(0.2)
    check(not any(l.startswith("bestmove") for l in got), "bestmove while pondering")
    e.send("ponderhit")
    e.until("bestmove", 5)
    e.send(MIDGAME + " c1e3")
    e.send("go ponder wtime 2000 btime 2000")
    time.sleep(0.3)
    e.send("stop")
    e.until("bestmove", 5)
    e.send("isready")
    e.until("readyok")

    # stop with nothing running, position during a search
    e.send("stop")
    e.send(MIDGAME)
    e.send("go infinite")
    time.sleep(0.2)
    e.send("position startpos")
    e.until("bestmove", 5)
    e.send("isready")
    e.until("readyok")

    # rejected positions -> info string + bestmove 0000
    for pos in ("position fen 4k2P/8/8/8/8/8/8/4K3 w - - 0 1",
                "position startpos moves e2e5",
                "position fen this is not a fen"):
        e.send(pos)
        _, bm = e.go("go depth 2")
        check(bm == "0000", f"rejected {pos!r} gave {bm}")
    e.send("position fen 7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
    _, bm = e.go("go depth 2")
    check(bm == "0000", "stalemate")

    # every Level combo value
    for lv in LEVELS:
        e.send(f"setoption name Level value {lv}")
        e.send(MIDGAME)
        lines, bm = e.go("go wtime 2000 btime 2000", timeout=120)
        if lv.startswith("Level P"):
            check(bm == "0000" and any("NO MATE FOUND" in l for l in lines), f"{lv}: {bm}")
            e.send("position fen 6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1")
            _, bm = e.go("go", timeout=120)
            check(bm == "d1d8", f"{lv} mate in one gave {bm}")
        else:
            check(len(bm) >= 4 and bm != "0000", f"{lv}: {bm}")
    e.send("setoption name Level value UCI")

    # display options
    e.send("setoption name UCI_ShowRefutations value true")
    e.send("setoption name UCI_ShowCurrLine value true")
    e.send(MIDGAME)
    lines, _ = e.go("go depth 4")
    check(any(l.startswith("info refutation") for l in lines), "refutations")

    e.send("quit")
    e.p.wait(5)
    check(e.p.returncode == 0, f"exit code {e.p.returncode}")


if __name__ == "__main__":
    sys.exit(main())
