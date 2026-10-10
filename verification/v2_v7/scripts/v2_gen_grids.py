#!/usr/bin/env python3
"""V2 sweep grid generator -> grids/*.tsv (data files read by v2_batch.sh).

Grid rule (PRE_TAPEOUT_CLOSURE_PLAN V2 / V2_V7 brief section 3.3):
  * key windows swept tick by tick: macro tick 0~2, 160~162, 248~250, 266, 283~285, 309~311, 385,
    443~445, 477~479, 4499~4503, 4760, 4808~4812, 4999~5001 (5000/5001 = next frame tick 0/1),
    and in every calibration subframe local tick 0~2, 248~250, 385;
  * everywhere else a step of at most 25 ticks.

TSV columns: point_id mode event slot frame tick sf lt param extra
  tick is the macro tick inside `frame`; for calibration targets sf/lt are given and tick = 625*sf+lt.
  extra = additional plusargs separated by ';' (e.g. V2_ADC_DONE_MODE=2).

usage: python v2_gen_grids.py <grids_dir>
"""
import sys
from pathlib import Path

KEY_TICKS = [0, 1, 2, 160, 161, 162, 248, 249, 250, 266, 283, 284, 285, 309, 310, 311, 385,
             443, 444, 445, 477, 478, 479, 4499, 4500, 4501, 4502, 4503, 4760,
             4808, 4809, 4810, 4811, 4812, 4999, 5000, 5001]
KEY_LOCAL = [0, 1, 2, 248, 249, 250, 385]
STEP = 25


def frame_ticks(step=STEP):
    """All key ticks plus a <=step filler over 0..4999 (5000/5001 kept as next-frame aliases)."""
    s = set(KEY_TICKS)
    s.update(range(0, 5000, step))
    return sorted(s)


def local_ticks(step=STEP):
    s = set(KEY_LOCAL)
    s.update(range(0, 625, step))
    return sorted(s)


def norm(frame, tick):
    """5000/5001 are the first ticks of the next frame."""
    if tick >= 5000:
        return frame + 1, tick - 5000
    return frame, tick


HDR = "point_id\tmode\tevent\tslot\tframe\ttick\tsf\tlt\tparam\textra\n"


def row(pid, mode, event, slot, frame, tick, sf=-1, lt=0, param=20, extra=""):
    return f"{pid}\t{mode}\t{event}\t{slot}\t{frame}\t{tick}\t{sf}\t{lt}\t{param}\t{extra}\n"


def normal_rows(mode, events, ticks, frame=3, extra="", tag="", param=20):
    out = []
    for ev in events:
        slots = ["RED", "IR"] if (ev in ("LATE", "BUSY") and mode == "DUAL9") else (["RED"] if ev in ("LATE", "BUSY") else ["ANY"])
        for slot in slots:
            for t in ticks:
                f, tt = norm(frame, t)
                pid = f"{tag}{mode}_{ev}_{slot}_t{t}"
                out.append(row(pid, mode, ev, slot, f, tt, param=param, extra=extra))
    return out


def cal_rows(events, lts, subframes=range(8), frame=0, extra="", tag="", param=20):
    out = []
    for ev in events:
        slot = "CAL" if ev in ("LATE", "BUSY") else "ANY"
        for sf in subframes:
            for lt in lts:
                pid = f"{tag}SEARCH_{ev}_sf{sf}_lt{lt}"
                out.append(row(pid, "SEARCH", ev, slot, frame, 625 * sf + lt, sf=sf, lt=lt, param=param, extra=extra))
    return out


def must_cover():
    """One smoke point per must-cover scenario of brief section 3.3 (see report for the meaning of each)."""
    r = []
    # 1 F-1: real detection chain (GEN_DUAL) precision switch + IR completion loss
    r.append(row("MC1_F1_GEN_DUAL_IR_LOST", "GEN_DUAL", "PREC_IR_LOST", "IR", 0, 0, extra="V2_TIMEOUT_CYCLES=6000000"))
    # 2 calibration owner pure DONE loss crossing into a NORMAL frame (periodic recheck, generator)
    r.append(row("MC2_RECHECK_CAL_LOST_BUSY", "RECHECK", "RECHECK_CAL_BUSY", "CAL", 0, 0, extra="V2_TIMEOUT_CYCLES=8000000"))
    # 3 L-6 over the full RED / IR / CAL windows: STOP + START delay 0 (representative ticks; full scan in the formal grid)
    for t in (1, 44, 200, 300, 318):
        r.append(row(f"MC3_L6_RED_t{t}", "DUAL9", "START_DELAY", "ANY", 3, t, param=0))
    for t in (161, 204, 460, 477):
        r.append(row(f"MC3_L6_IR_t{t}", "DUAL9", "START_DELAY", "ANY", 3, t, param=0))
    for lt in (1, 10, 266, 283):
        r.append(row(f"MC3_L6_CAL_sf1_lt{lt}", "SEARCH", "START_DELAY", "ANY", 0, 625 + lt, sf=1, lt=lt, param=0))
    # 4 exception C: startup search with the calibration owner in flight at the calibration frame end
    #   the first calibration conversion of frame 0 completes late, at frame 1 tick 100, so the owner is in flight at the CAL frame end
    r.append(row("MC4_EXCC_SEARCH_LATE_CAL", "SEARCH", "LATE", "CAL", 0, 100))
    # 5 SID-05 deadline cross-frame retry: ADC busy across the local-248 calibration owner deadline
    #   the subframe-0 calibration conversion stays busy until subframe 1 local 300, so the subframe-1 owner misses local 248
    r.append(row("MC5_SID05_BUSY_ACROSS_248", "SEARCH", "BUSY", "CAL", 0, 625 + 300, sf=1, lt=300))
    # 6 late completion across a frame boundary (NORMAL RED, DONE in the next frame before T-lost)
    r.append(row("MC6_LATE_CROSS_FRAME", "DUAL9", "LATE", "RED", 3, 200))
    # 7 SAR15 void timing
    r.append(row("MC7_RED15_LOST", "RED15", "LOST", "RED", 3, 100))
    # 8 cause 07 at chip level -> control_top level with the C01 idle formula and held DONE (see report: chip-level item)
    r.append(row("MC8_CAUSE07_FOREVER", "DUAL9", "FOREVER", "RED", 3, 100, extra="V2_TIMEOUT_CYCLES=60000"))
    # 9 redundancy corrector: DONE entering the synchronizer 1~2 cycles before the void (late DONE at age 4498..4501)
    for t in (4499, 4500, 4501, 4502):
        r.append(row(f"MC9_LATE_AT_VOID_t{t}", "DUAL9", "LATE", "RED", 3, t, extra="V2_ADC_DONE_MODE=2"))
    return r


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    trial_ticks = sorted(set(KEY_TICKS))
    # trial (P0, current RTL): reduced grid of brief section 3.5
    rows = []
    rows += normal_rows("DUAL9", ["STOP", "ABORT", "LOST", "LATE"], trial_ticks)
    rows += normal_rows("RED15", ["STOP", "ABORT", "LOST", "LATE"], trial_ticks)
    (out / "trial_normal.tsv").write_text(HDR + "".join(rows), encoding="utf-8", newline="\n")
    rows = cal_rows(["STOP", "LOST"], KEY_LOCAL)
    (out / "trial_cal.tsv").write_text(HDR + "".join(rows), encoding="utf-8", newline="\n")
    (out / "trial_must_cover.tsv").write_text(HDR + "".join(must_cover()), encoding="utf-8", newline="\n")
    # formal (after RC1): full grid
    ft = frame_ticks()
    rows = []
    for mode in ("DUAL9", "RED15"):
        rows += normal_rows(mode, ["STOP", "ABORT", "LOST", "LATE", "BUSY", "DIAG_CLEAR", "COMMIT"], ft)
        for d in (0, 100, 200, 400):
            rows += normal_rows(mode, ["START_DELAY"], ft, tag=f"D{d}_", param=d)
    (out / "formal_normal.tsv").write_text(HDR + "".join(rows), encoding="utf-8", newline="\n")
    rows = cal_rows(["STOP", "ABORT", "LOST", "LATE", "BUSY"], local_ticks())
    for d in (0, 100, 200, 400):
        rows += cal_rows(["START_DELAY"], local_ticks(), tag=f"D{d}_", param=d)
    (out / "formal_cal.tsv").write_text(HDR + "".join(rows), encoding="utf-8", newline="\n")
    for f in sorted(out.glob("*.tsv")):
        n = sum(1 for _ in open(f, encoding="utf-8")) - 1
        print(f"{f.name}\t{n}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).resolve().parents[1] / "grids"))
