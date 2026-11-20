#!/usr/bin/env python3
"""Compare two ACCTEST logs (e.g. base firmware vs new firmware).

    compare.py BASE.LOG NEW.LOG [--all]

Uses the machine-readable lines of the logs:
    R;name;N;parity;reps;real;null   micro-benchmark (CTC counts for reps operations)
    C;name;rows;cols;cpu             rows-vs-columns scenario (us x10, empty = none)
and the "RESULT:" line.  Prints, per operation, the net cost in 7 MHz accelerator
cycles (1 CTC count = 8 cycles) for both logs and the change in percent.  Without
--all only lines whose cost changed by more than 1 % are listed.
"""
import sys


def load(path):
    micro, scen, result = {}, {}, None
    with open(path, encoding="latin-1") as f:
        for line in f:
            line = line.strip()
            if line.startswith("R;"):
                p = line.split(";")
                if len(p) != 7:
                    continue
                _, name, n, par, reps, real, null = p
                reps, real, null = int(reps), int(real), int(null)
                cyc = max(real - null, 0) * 8.0 / reps if reps else 0.0
                key = (name, int(n), par)
                micro.setdefault(key, cyc)   # first occurrence wins
            elif line.startswith("C;"):
                p = line.split(";")
                if len(p) != 5:
                    continue
                vals = [int(v) / 10.0 if v else None for v in p[2:]]
                scen.setdefault(p[1], vals)
            elif line.startswith("RESULT:"):
                result = line
    return micro, scen, result


def pct(a, b):
    if a is None or b is None:
        return None
    if a == 0:
        return 0.0 if b == 0 else float("inf")
    return (b - a) * 100.0 / a


def fmt(v, w=9, d=2):
    return f"{v:{w}.{d}f}" if v is not None else " " * (w - 1) + "-"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    show_all = "--all" in sys.argv
    if len(args) != 2:
        print(__doc__)
        return 2
    m1, s1, r1 = load(args[0])
    m2, s2, r2 = load(args[1])
    print(f"A: {args[0]}  {r1 or '(no RESULT line)'}")
    print(f"B: {args[1]}  {r2 or '(no RESULT line)'}")
    print()
    print("Micro-benchmarks: net cost per operation, 7 MHz cycles")
    print(f"  {'operation':22} {'N':>4} {'addr':>5} {'A':>9} {'B':>9} {'B-A %':>8}")
    shown = 0
    for key in sorted(set(m1) | set(m2), key=lambda k: (k[0], k[2], k[1])):
        a, b = m1.get(key), m2.get(key)
        d = pct(a, b)
        if not show_all and d is not None and abs(d) <= 1.0:
            continue
        name, n, par = key
        print(f"  {name:22} {n:4} {par:>5} {fmt(a)} {fmt(b)} {fmt(d, 8, 1)}")
        shown += 1
    if not shown:
        print("  (no differences above 1 %)")
    print()
    print("Rows versus columns: us")
    print(f"  {'scenario':28} {'rows A':>9} {'rows B':>9} {'cols A':>9} {'cols B':>9} {'cols/rows A':>11} {'cols/rows B':>11}")
    for name in list(dict.fromkeys(list(s1) + list(s2))):
        a = s1.get(name, [None, None, None])
        b = s2.get(name, [None, None, None])
        ra = a[1] / a[0] if a[0] and a[1] else None
        rb = b[1] / b[0] if b[0] and b[1] else None
        print(f"  {name:28} {fmt(a[0], 9, 1)} {fmt(b[0], 9, 1)} {fmt(a[1], 9, 1)} {fmt(b[1], 9, 1)}"
              f" {fmt(ra, 11)} {fmt(rb, 11)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
