#!/usr/bin/env python3
"""Compare two ACCTEST logs (e.g. base firmware vs new firmware).

    compare.py A.LOG B.LOG [--all]

Uses the machine-readable lines of the logs:
    R;name;N;parity;reps;real;null   micro-benchmark (CTC counts for reps operations)
    C;name;rows;cols;cpu             rows-vs-columns scenario (us x10, empty = none)
and the "RESULT:", "CPU:" and "Frame period" lines.

Costs are net accelerator cycles per operation (1 CTC count = 8 cycles; 1 cycle =
142.9 ns = 3 T at 21 MHz).  Sections:
  1. environment check: both logs must come from the same CPU speed;
  2. per operation: the cost per byte fitted over N >= 16 and the mean change;
  3. per line: every (operation, N, parity) whose cost changed by more than 1 % and
     by more than 0.5 cycles (--all: every line);
  4. rows versus columns.
"""
import re
import sys

NOISE_CYCLES = 0.5      # a difference below this is timer resolution, not a change
FIT_FROM = 16           # sizes used for the per-byte fit and the mean change


def load(path):
    micro, scen, info = {}, {}, {"result": None, "cpu": None, "frame": None}
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
                micro.setdefault((name, int(n), par), cyc)   # first occurrence wins
            elif line.startswith("C;"):
                p = line.split(";")
                if len(p) != 5:
                    continue
                scen.setdefault(p[1], [int(v) / 10.0 if v else None for v in p[2:]])
            elif line.startswith("RESULT:"):
                info["result"] = line
            elif line.startswith("CPU:"):
                m = re.search(r"=\s*([\d.]+)\s*MHz", line)
                if m:
                    info["cpu"] = float(m.group(1))
            elif line.startswith("Frame period"):
                info["frame"] = line.split(":", 1)[1].strip()
    return micro, scen, info


def pct(a, b):
    if a is None or b is None or a == 0:
        return None
    return (b - a) * 100.0 / a


def fmt(v, w=9, d=2):
    return f"{v:{w}.{d}f}" if v is not None else " " * (w - 1) + "-"


def slope(points):
    """Least-squares cost per byte over (N, cycles) points."""
    if len(points) < 2:
        return None
    mx = sum(n for n, _ in points) / len(points)
    my = sum(c for _, c in points) / len(points)
    den = sum((n - mx) ** 2 for n, _ in points)
    return sum((n - mx) * (c - my) for n, c in points) / den if den else None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    show_all = "--all" in sys.argv
    if len(args) != 2:
        print(__doc__)
        return 2
    m1, s1, i1 = load(args[0])
    m2, s2, i2 = load(args[1])
    for tag, path, info in (("A", args[0], i1), ("B", args[1], i2)):
        print(f"{tag}: {path}")
        print(f"   {info['result'] or '(no RESULT line: the run did not finish)'}")
        print(f"   CPU {info['cpu'] if info['cpu'] is not None else '?'} MHz effective,"
              f" frame period {info['frame'] or '?'}")
    if i1["cpu"] and i2["cpu"] and abs(i1["cpu"] - i2["cpu"]) > 0.02 * i1["cpu"]:
        print("   WARNING: the CPU speed differs by more than 2 % (turbo on in one run"
              " only?): CPU baselines and the rows/columns times are not comparable.")
    print()

    # ---- per operation
    names = list(dict.fromkeys(k[0] for k in list(m1) + list(m2)))
    print(f"Per operation (N >= {FIT_FROM}): cycles per byte, mean change")
    print(f"  {'operation':22} {'addr':>5} {'A /byte':>8} {'B /byte':>8} {'B-A %':>8}")
    for name in names:
        pars = list(dict.fromkeys(k[2] for k in list(m1) + list(m2) if k[0] == name))
        for par in pars:
            pa = [(k[1], v) for k, v in m1.items() if k[0] == name and k[2] == par and k[1] >= FIT_FROM]
            pb = [(k[1], v) for k, v in m2.items() if k[0] == name and k[2] == par and k[1] >= FIT_FROM]
            if len(pa) < 2 or len(pb) < 2:
                continue
            sa, sb = slope(pa), slope(pb)
            ta = sum(c for _, c in pa)
            tb = sum(c for n, c in pb if (name, n, par) in m1)
            change = (tb - ta) * 100.0 / ta if ta else None
            print(f"  {name:22} {par:>5} {fmt(sa, 8)} {fmt(sb, 8)} {fmt(change, 8, 1)}")
    print()

    # ---- per line
    print("Per line: net cost per operation, cycles"
          + ("" if show_all else f" (changes above 1 % and {NOISE_CYCLES} cycles)"))
    print(f"  {'operation':22} {'N':>4} {'addr':>5} {'A':>9} {'B':>9} {'B-A':>8} {'B-A %':>8}")
    shown = 0
    for key in sorted(set(m1) | set(m2), key=lambda k: (names.index(k[0]), k[2], k[1])):
        a, b = m1.get(key), m2.get(key)
        d = pct(a, b)
        diff = b - a if a is not None and b is not None else None
        if not show_all and diff is not None and (abs(diff) < NOISE_CYCLES or (d is not None and abs(d) <= 1.0)):
            continue
        name, n, par = key
        print(f"  {name:22} {n:4} {par:>5} {fmt(a)} {fmt(b)} {fmt(diff, 8)} {fmt(d, 8, 1)}")
        shown += 1
    if not shown:
        print("  (no differences)")
    print()

    # ---- rows versus columns
    print("Rows versus columns: us per operation (full screen) or per rectangle")
    print(f"  {'scenario':26} {'rows A':>9} {'rows B':>9} {'B-A %':>7} {'cols A':>9} {'cols B':>9}"
          f" {'B-A %':>7} {'c/r A':>6} {'c/r B':>6}")
    for name in list(dict.fromkeys(list(s1) + list(s2))):
        a = s1.get(name, [None, None, None])
        b = s2.get(name, [None, None, None])
        ra = a[1] / a[0] if a[0] and a[1] else None
        rb = b[1] / b[0] if b[0] and b[1] else None
        print(f"  {name:26} {fmt(a[0], 9, 1)} {fmt(b[0], 9, 1)} {fmt(pct(a[0], b[0]), 7, 1)}"
              f" {fmt(a[1], 9, 1)} {fmt(b[1], 9, 1)} {fmt(pct(a[1], b[1]), 7, 1)}"
              f" {fmt(ra, 6)} {fmt(rb, 6)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
