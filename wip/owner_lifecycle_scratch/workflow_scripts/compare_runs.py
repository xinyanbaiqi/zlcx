"""Compare per-TB xsim.log of a new run against a reference run (scratch, not committed).

usage: compare_runs.py <ref_dir> <new_dir> [<ref_dir2> <new_dir2> ...]
Each dir contains <tb>/xsim.log. For every TB present in new_dir: sorted PASS-line
multiset diff (added/removed), FAIL count, $finish time, final banner line, verdict.
PASS lines: lines starting with 'PASS', '[PASS]', or '[<t>] <ID> PASS' (SSW style).
"""
import re
import sys
from collections import Counter
from pathlib import Path

PASS_RE = re.compile(r"^(PASS\b|\[PASS\]|\[\d+\] \S+ PASS\b)")
FAIL_RE = re.compile(r"^FAIL|^\[FAIL\]|^\[\d+\] \S+ FAIL\b|ERROR:|FATAL")
FIN_RE = re.compile(r"finish called at time : (\d+ \w+)")
BANNER_RE = re.compile(r"_TB_PASS|_TB_FAIL|SELFCHECK_(PASS|FAIL)|INJ_TB_|ALL .* PASS|PASS: .*(completed|passed|verified|matched)|"
                       r"through .* PASS|PASS count=|PHASE_A_ARITH_EQV|ALL FSC|REGRESSION FAIL|TB_CHIP_DIGITAL_TOP")


def norm(line):
    return re.sub(r'File "[^"]*"', "", line).rstrip("\r\n")


def read(p):
    lines = [norm(l) for l in Path(p).read_text(encoding="utf-8", errors="replace").splitlines()]
    passes = Counter(l for l in lines if PASS_RE.search(l))
    fails = sum(1 for l in lines if FAIL_RE.search(l))
    fin = [m.group(1) for l in lines for m in [FIN_RE.search(l)] if m]
    banner = [l for l in lines if BANNER_RE.search(l) and not l.startswith("PASS ") or l.startswith("PASS: ")]
    return passes, fails, fin, (banner[-1] if banner else "-")


args = sys.argv[1:]
for i in range(0, len(args), 2):
    ref, new = Path(args[i]), Path(args[i + 1])
    print(f"### {new}  vs  {ref}")
    print("tb\tpass_ref\tpass_new\tadded\tremoved\tfail_new\tfinish_same\tbanner_same\tbanner_new")
    for d in sorted(p for p in new.iterdir() if (p / "xsim.log").exists()):
        rlog = ref / d.name / "xsim.log"
        np_, nf, nfin, nban = read(d / "xsim.log")
        if not rlog.exists():
            print(f"{d.name}\t-\t{sum(np_.values())}\tNEW\t-\t{nf}\t-\t-\t{nban[:90]}")
            continue
        rp, rf, rfin, rban = read(rlog)
        added = np_ - rp
        removed = rp - np_
        fs = "Y" if rfin == nfin else f"N:{rfin}->{nfin}"
        print(f"{d.name}\t{sum(rp.values())}\t{sum(np_.values())}\t{sum(added.values())}\t{sum(removed.values())}\t{nf}\t{fs}\t{'Y' if rban == nban else 'N'}\t{nban[:90]}")
        for l in sorted(added):
            print(f"    + {l[:160]}")
        for l in sorted(removed):
            print(f"    - {l[:160]}")
        if rban != nban:
            print(f"    banner ref: {rban[:160]}")
            print(f"    banner new: {nban[:160]}")
