"""交付一致性检查：核对全部迹线哈希、矩阵、文档统计和Python语法。"""

import ast
import csv
import hashlib
import json
from pathlib import Path

TASK = Path(__file__).resolve().parents[1]


def main() -> None:
    """只读取本任务新建文件，核验报告引用的结果确有对应真实迹线。"""
    evidence = TASK / "scenarios/evidence"
    data = json.loads((evidence / "trial_results.json").read_text(encoding="utf-8"))
    cases = json.loads((TASK / "scenarios/matrix.json").read_text(encoding="utf-8"))
    assert len(cases) == 148 and len({case["name"] for case in cases}) == 148
    assert set(data["results"]) == {case["name"] for case in cases}
    assert data["summary"]["unknown_group_ticks"] == 0
    for name, result in data["results"].items():
        assert result["handshake_matches_plan"] and result["stimulus_unchanged_proven"]
        assert not result["structure_errors"]
        assert result["audit"]["clock_low_errors"] == result["audit"]["stability_errors"] == 0
        for filename, expected_digest in result["trace_sha256"].items():
            path = TASK / "_runs/final" / name / filename
            assert hashlib.sha256(path.read_bytes()).hexdigest() == expected_digest, (name, filename)
    assert sum(result["rows"] for result in data["results"].values()) == 781184
    with (evidence / "signal_comparison.csv").open(encoding="utf-8", newline="") as stream:
        comparisons = list(csv.DictReader(stream))
    assert len(comparisons) == 148 * 28
    assert sum(int(row["mismatch_ticks"]) for row in comparisons) == data["summary"]["mismatch_group_ticks"]
    gate = json.loads((evidence / "deliverable_gate.json").read_text(encoding="utf-8"))
    assert gate["delivery_ready"] and gate["errors"] == gate["strict_warnings"] == 0
    checks = json.loads((evidence / "comparator_checks.json").read_text(encoding="utf-8"))
    assert len(checks) == 8 and checks["positive_control"]["status"] == "PASS"
    assert all(check["status"] == "MISMATCH" for label, check in checks.items() if label != "positive_control")
    with (TASK / "_runs/final/normal_both_sar15_a5/actual.csv").open(encoding="utf-8", newline="") as stream:
        selected = [row for row in csv.DictReader(stream) if int(row["row"]) >= 8]
    assert all(row["o_en_15sar_low"] == row["o_clk_15q1_low"] for row in selected)
    assert sum(int(row["o_en_15sar_low"], 16) for row in selected) == 42
    # 仅语法解析本任务Python文件，不生成缓存、不扫描RTL或其他目录。
    python_files = sorted((TASK / "scripts").glob("*.py")) + sorted((TASK / "golden").glob("*.py"))
    for path in python_files:
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    report = TASK.parents[1] / "verification_reports/V18_SSW_GOLDEN_TRIAL_20261010.md"
    text = report.read_text(encoding="utf-8")
    assert sum(line.startswith("| " + name + " |") for name in data["results"] for line in text.splitlines()) == 148
    summary = dict(status="PASS", scenarios=148, checked_trace_hashes=148 * 3,
                   scenario_signal_rows=148 * 28, python_files=len(python_files),
                   sar15_select_observed_equal_q1=True, report_scenario_rows=148)
    (evidence / "delivery_checks.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
