"""冻结最终规则并汇总已采集迹线；先证明刺激完全相同，再重新比较更新后的黄金。"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
import sys
from collections import Counter
from pathlib import Path

TASK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TASK / "golden"))
from model import OUTPUTS, contexts_for, generate, load_windows
from compare import compare

FRONTEND = {"o_en_tia_low", "o_clk_aferst_low", "o_clk_tiaen_low"}


def digest(path: Path) -> str:
    """仅计算本任务产生的输入、期望或采集文件，不对SSW实现求哈希。"""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def classification(case: dict, signal: str) -> str:
    """SAR15前端迟到owner窗口按统筹指定的已知问题单独登记。"""
    if signal in FRONTEND and any(context["precision"] == 1 and context["owner"] is not None and
                                  context["center"] - 34 <= context["owner"] <= context["center"] - 17
                                  for context in contexts_for(case)):
        return "KNOWN-SAR15-DEADLINE"
    if "stop_tick" in case and "before_preheat" in case["name"] and signal != "o_en_15sar_low":
        return "V18-F06"
    if signal in {"o_en_sar9_amb_low", "o_en_sar9_dc_low", "o_en_sar9_iref"}:
        return "V18-F01"
    if signal in {"o_leden1_low", "o_leden2_low"}:
        return "V18-F02"
    if signal == "o_en_15sar_low":
        return "V18-F03"
    if case.get("frame_type") == 1 and signal == "o_en_tia_low":
        return "V18-F04"
    if case.get("frame_type") == 1 and signal == "o_leddac":
        return "V18-F05"
    if signal in FRONTEND and case["name"] == "owner_at_deadline_normal9":
        return "V18-F07"
    return "UNCLASSIFIED"


def ranges(rows: list[dict], signal: str, start: int, end: int, hexadecimal: bool) -> list[list[int]]:
    """把指定观察区间内的真实高电平记录展开成左闭右开连续区间。"""
    segments, current = [], None
    for tick in range(start, end):
        row = rows[tick + 8]
        value = int(row[signal].strip(), 16 if hexadecimal else 10)
        if value and current is None:
            current = tick
        if not value and current is not None:
            segments.append([current, tick])
            current = None
    if current is not None:
        segments.append([current, end])
    return segments


def main() -> None:
    """后一个运行目录优先；任何刺激哈希不一致都拒绝沿用旧采集。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=Path, nargs="+", required=True)
    parser.add_argument("--out", type=Path, default=TASK / "_runs/final")
    parser.add_argument("--evidence", type=Path, default=TASK / "scenarios/evidence")
    parser.add_argument("--repo", type=Path, default=TASK.parents[1])
    parser.add_argument("--sar9-template", type=Path)
    parser.add_argument("--sar15-template", type=Path)
    args = parser.parse_args()
    repo = args.repo
    profiles, provenance = load_windows(args.sar9_template or repo / "rtl/ppg_timing_sar9/ppg_timing_sar9.v",
                                        args.sar15_template or repo / "rtl/ppg_timing_sar15/ppg_timing_sar15.v")
    cases = json.loads((TASK / "scenarios/matrix.json").read_text(encoding="utf-8"))
    args.out.mkdir(parents=True, exist_ok=True)
    args.evidence.mkdir(parents=True, exist_ok=True)
    results, signal_table, known_ranges = {}, [], {}
    sources = Counter()
    for case in cases:
        name = case["name"]
        folder = args.out / name
        metadata = generate(case, profiles, folder)
        candidates = [run / name for run in args.runs if (run / name / "actual.csv").exists()]
        if not candidates:
            raise RuntimeError(f"没有场景真实采集: {name}")
        captured = candidates[-1]
        if digest(captured / "stimulus.hex") != digest(folder / "stimulus.hex"):
            raise RuntimeError(f"刺激已变化，须重跑仿真，不能沿用旧迹线: {name}")
        log = (captured / "simulation.log").read_text(encoding="utf-8")
        if "FAIL" in log or "PASS pin capture" not in log:
            raise RuntimeError(f"采集断言未真实通过: {name}")
        shutil.copy2(captured / "actual.csv", folder / "actual.csv")
        comparison = compare(folder / "expected.csv", folder / "actual.csv", [name for name, _, _ in OUTPUTS])
        contexts = metadata["contexts"]
        expected_waves = sum(all(case.get(action) is None or context["fire"] < case[action]
                                 for action in ("stop_tick", "abort_tick")) for context in contexts)
        expected_owners = sum(context["sample"] != 0 for context in contexts)
        comparison["planned_fires"] = {"wave_fire": expected_waves, "owner_fire": expected_owners}
        comparison["handshake_matches_plan"] = all(comparison["audit"][key] == expected_count
                                                     for key, expected_count in comparison["planned_fires"].items())
        if not comparison["handshake_matches_plan"] or comparison["structure_errors"]:
            raise RuntimeError(f"协议驱动或迹线完整性不成立: {name}")
        comparison["scenario"] = case
        comparison["capture_source"] = captured.parent.name
        comparison["stimulus_unchanged_proven"] = True
        comparison["trace_sha256"] = {file.name: digest(file) for file in
                                      (folder / "stimulus.hex", folder / "expected.csv", folder / "actual.csv")}
        with (folder / "actual.csv").open(encoding="utf-8", newline="") as stream:
            actual_rows = list(csv.DictReader(stream))
        comparison["protocol_sticky_rows"] = {signal: sum(int(row[signal].strip(), 16) != 0 for row in actual_rows)
                                                for signal in ("o_switch_protocol_error_sticky", "o_transaction_mismatch_sticky",
                                                               "o_wrapper_fault_blocking")}
        if any(comparison["protocol_sticky_rows"][signal] for signal in
               ("o_switch_protocol_error_sticky", "o_transaction_mismatch_sticky")):
            raise RuntimeError(f"合法场景出现阻断诊断，需单独核查: {name}")
        for signal, info in comparison["signals"].items():
            info["classification"] = classification(case, signal) if info["mismatch_ticks"] else "MATCH"
            first = info["first"] or {}
            signal_table.append(dict(scenario=name, signal=signal, classification=info["classification"],
                                     compared_ticks=info["compared_ticks"], unknown_ticks=info["unknown_ticks"],
                                     mismatch_ticks=info["mismatch_ticks"], mismatch_bits=info["mismatch_bits"],
                                     first_tick=first.get("tick", ""), first_macro_tick=first.get("macro_tick", ""),
                                     first_local_tick=first.get("local_tick", ""), expected=first.get("expected", ""),
                                     actual=first.get("actual", ""), last_tick=info["last_tick"] if info["last_tick"] is not None else ""))
        if name.startswith("known_sar15_deadline") or name.startswith("owner_at_deadline_normal"):
            with (folder / "expected.csv").open(encoding="utf-8", newline="") as stream:
                expected_rows = list(csv.DictReader(stream))
            for context in contexts:
                center = context["center"]
                for signal in sorted(FRONTEND):
                    key = f"{name}/{context['color']}/{signal}"
                    known_ranges[key] = dict(owner_tick=context["owner"],
                                             expected=ranges(expected_rows, signal, center - 40, center + 10, False),
                                             actual=ranges(actual_rows, signal, center - 40, center + 10, True))
        results[name] = comparison
        sources[comparison["capture_source"]] += 1
        (folder / "comparison.json").write_text(json.dumps(comparison, ensure_ascii=False, indent=2), encoding="utf-8")
    classes = Counter(info["classification"] for result in results.values() for info in result["signals"].values()
                      if info["mismatch_ticks"])
    summary = dict(scenarios=len(results), rows=sum(result["rows"] for result in results.values()),
                   status_counts=dict(Counter(result["status"] for result in results.values())),
                   compared_group_ticks=sum(info["compared_ticks"] for result in results.values() for info in result["signals"].values()),
                   unknown_group_ticks=sum(info["unknown_ticks"] for result in results.values() for info in result["signals"].values()),
                   mismatch_group_ticks=sum(info["mismatch_ticks"] for result in results.values() for info in result["signals"].values()),
                   classification_signal_pairs=dict(classes), capture_sources=dict(sources),
                   all_handshakes_match=True, unexpected_protocol_sticky_rows=0,
                   lifecycle_blocking_state_rows=sum(result["protocol_sticky_rows"]["o_wrapper_fault_blocking"] for result in results.values()),
                   clock_low_errors=sum(result["audit"]["clock_low_errors"] for result in results.values()),
                   stability_errors=sum(result["audit"]["stability_errors"] for result in results.values()))
    package = {"summary": summary, "results": results}
    (args.evidence / "trial_results.json").write_text(json.dumps(package, ensure_ascii=False, indent=2), encoding="utf-8")
    (args.evidence / "window_provenance.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2), encoding="utf-8")
    (args.evidence / "owner_window_ranges.json").write_text(json.dumps(known_ranges, ensure_ascii=False, indent=2), encoding="utf-8")
    with (args.evidence / "signal_comparison.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(signal_table[0]))
        writer.writeheader()
        writer.writerows(signal_table)
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if "UNCLASSIFIED" in classes:
        raise RuntimeError("仍有未分类差异，不能完成报告")


if __name__ == "__main__":
    main()
