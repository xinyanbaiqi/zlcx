"""Regression evidence for the B merge batch (brief section 6.8).

export  <run_root> <out_dir>
    <run_root> holds an exported tree per run group, laid out as in
    verification_reports/b_merge_batch_evidence/REGRESSION_RUN_REQUEST.md:
      sys_g1..sys_gN/rtl/ppg_control_top/xsim_regression_20260906/summary.tsv
      chip/rtl/ppg_chip_digital_top/xsim_regression_*/summary.tsv
      unit_runs/unit_summary.tsv
    Writes, per TB, <kind>/<tb>.pass_sorted.txt (lines matching \\bPASS\\b that
    do not contain "pass=", sorted) and <kind>/<tb>.finish.txt ($finish lines
    with absolute paths reduced to the file basename), plus index.tsv with the
    tool return codes and the pass/finish counts.

compare <baseline_evidence_dir> <final_evidence_dir>
    Per TB: compares the sorted PASS lines and the $finish lines. Prints every
    differing PASS line so label-only renames can be listed one by one. $finish
    lines are compared as ($finish time, file name): a difference there is
    FINISH_DIFF. When only the source line number differs (a change-log entry
    added to the TB header moves the $finish statement), the TB is marked
    FINISH_LINE_SHIFT with the old and new line numbers; that is not a problem.
    Exit 1 when a TB is missing on one side or a FINISH_DIFF is found.
"""
import csv
import difflib
import glob
import os
import re
import sys

PASS_RE = re.compile(r"\bPASS\b")
FIN_RE = re.compile(r'\$finish called at time\s*:\s*(.*?)\s*:\s*File "([^"]*)"\s*Line\s*(\d+)')
INDEX_HEAD = ["kind", "tb", "xvlog", "xelab", "xsim", "verdict", "pass_lines", "finish_lines", "finish_time"]


def read_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8", errors="replace") as fh:
        return [ln.rstrip("\r\n") for ln in fh]


def write_lines(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("".join(ln + "\n" for ln in lines))


def read_tsv(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def export_one(out_dir, kind, tb, log_path, rcs, verdict, index):
    lines = read_lines(log_path)
    passes = sorted(ln for ln in lines if PASS_RE.search(ln) and "pass=" not in ln)
    finishes = []
    for ln in lines:
        m = FIN_RE.search(ln)
        if m:
            finishes.append('$finish called at time : %s : File "%s" Line %s'
                            % (m.group(1), os.path.basename(m.group(2)), m.group(3)))
    kind_dir = os.path.join(out_dir, kind)
    os.makedirs(kind_dir, exist_ok=True)
    write_lines(os.path.join(kind_dir, tb + ".pass_sorted.txt"), passes)
    write_lines(os.path.join(kind_dir, tb + ".finish.txt"), finishes)
    finish_time = finishes[0].split(" : ")[1] if finishes else "-"
    index.append([kind, tb] + list(rcs) + [verdict, str(len(passes)), str(len(finishes)), finish_time])


def export(run_root, out_dir):
    index = []
    sys_summaries = sorted(glob.glob(os.path.join(
        run_root, "sys_g*", "rtl", "ppg_control_top", "xsim_regression_20260906", "summary.tsv")))
    chip_summaries = sorted(glob.glob(os.path.join(
        run_root, "chip", "rtl", "ppg_chip_digital_top", "xsim_regression_*", "summary.tsv")))
    for kind, summaries in (("system", sys_summaries), ("chip", chip_summaries)):
        for summary in summaries:
            base = os.path.dirname(os.path.dirname(summary))
            for row in read_tsv(summary):
                ok = (row["xvlog"], row["xelab"], row["xsim"]) == ("0", "0", "0") \
                    and row["fail_count"] == "0" and row["finished"] == "1"
                export_one(out_dir, kind, row["tb_name"], os.path.join(base, row["log_dir"], "xsim.log"),
                           (row["xvlog"], row["xelab"], row["xsim"]), "PASS" if ok else "FAIL", index)
    unit_summary = os.path.join(run_root, "unit_runs", "unit_summary.tsv")
    if os.path.exists(unit_summary):
        for row in read_tsv(unit_summary):
            export_one(out_dir, "unit", row["tb"], os.path.join(run_root, "unit_runs", row["tb"], "xsim.log"),
                       (row["xvlog"], row["xelab"], row["xsim"]), row["verdict"], index)
    write_lines(os.path.join(out_dir, "index.tsv"), ["\t".join(INDEX_HEAD)] + ["\t".join(r) for r in index])
    for kind in ("system", "chip", "unit"):
        rows = [r for r in index if r[0] == kind]
        n_pass = sum(1 for r in rows if r[5] == "PASS")
        print("%-6s TBs=%d PASS=%d FAIL=%d pass_lines=%d"
              % (kind, len(rows), n_pass, len(rows) - n_pass, sum(int(r[6]) for r in rows)))
    return 0


def tb_files(evidence_dir):
    found = {}
    for path in glob.glob(os.path.join(evidence_dir, "*", "*.pass_sorted.txt")):
        kind = os.path.basename(os.path.dirname(path))
        found[(kind, os.path.basename(path)[:-len(".pass_sorted.txt")])] = path
    return found


def finish_keys(lines):
    """($finish time, file) per line; a line that does not parse is kept whole."""
    keys = []
    for ln in lines:
        m = FIN_RE.search(ln)
        keys.append((m.group(1), m.group(2)) if m else (ln, None))
    return keys


def finish_line_numbers(lines):
    return [m.group(3) for m in (FIN_RE.search(ln) for ln in lines) if m]


def compare(base_dir, final_dir):
    base, final = tb_files(base_dir), tb_files(final_dir)
    bad = 0
    for key in sorted(set(base) | set(final)):
        name = "%s/%s" % key
        if key not in base or key not in final:
            print("MISSING  %s (baseline=%s final=%s)" % (name, key in base, key in final))
            bad += 1
            continue
        b_fin = read_lines(base[key].replace(".pass_sorted.txt", ".finish.txt"))
        f_fin = read_lines(final[key].replace(".pass_sorted.txt", ".finish.txt"))
        b_pass, f_pass = read_lines(base[key]), read_lines(final[key])
        diff = [d for d in difflib.unified_diff(b_pass, f_pass, lineterm="", n=0)
                if d[:1] in "+-" and not d.startswith(("+++", "---"))]
        status = "SAME" if not diff else "PASSDIFF(%d/%d lines)" % (len(b_pass), len(f_pass))
        b_key, f_key = finish_keys(b_fin), finish_keys(f_fin)
        fin_note = None
        if b_key != f_key:
            fin_note = "FINISH_DIFF"
            bad += 1
        elif b_fin != f_fin:
            # same $finish time and file, only the source line moved (e.g. a change-log
            # entry added to the TB header): reported, not a problem
            fin_note = "FINISH_LINE_SHIFT"
        if fin_note:
            status = fin_note if not diff else status + " " + fin_note
        print("%-28s %s" % (status, name))
        for d in diff:
            print("    " + d)
        if fin_note == "FINISH_DIFF":
            print("    baseline finish: %s" % b_fin)
            print("    final    finish: %s" % f_fin)
        elif fin_note == "FINISH_LINE_SHIFT":
            print("    $finish line: baseline %s -> final %s (time and file equal)"
                  % (",".join(finish_line_numbers(b_fin)), ",".join(finish_line_numbers(f_fin))))
    print("TBs=%d problems(missing, or $finish time/file differs)=%d" % (len(set(base) | set(final)), bad))
    return 1 if bad else 0


def main(argv):
    if len(argv) == 4 and argv[1] == "export":
        return export(argv[2], argv[3])
    if len(argv) == 4 and argv[1] == "compare":
        return compare(argv[2], argv[3])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
