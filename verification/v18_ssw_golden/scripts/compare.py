"""V18 逐拍比较器：缺行、重复行、X/Z和时钟错误均不能成为通过。"""

from __future__ import annotations

import csv
from pathlib import Path


def compare(expected_path: Path, actual_path: Path, signal_names: list[str]) -> dict:
    """按场景×信号给首处差异、拍数和位差异；空期望显式算待确认。"""
    with expected_path.open(encoding="utf-8", newline="") as stream:
        expected = list(csv.DictReader(stream))
    with actual_path.open(encoding="utf-8", newline="") as stream:
        actual = list(csv.DictReader(stream))
    structure = []
    if len(expected) != len(actual):
        structure.append(f"row count expected={len(expected)} actual={len(actual)}")
    results = {name: {"mismatch_ticks": 0, "compared_ticks": 0, "unknown_ticks": 0,
                      "mismatch_bits": 0, "first": None, "last_tick": None} for name in signal_names}
    handshake = {"wave_fire": 0, "owner_fire": 0, "clock_low_errors": 0, "stability_errors": 0}
    for index, (gold, observed) in enumerate(zip(expected, actual)):
        if int(gold["row"]) != index or int(observed["row"]) != index:
            structure.append(f"nonsequential/duplicate row at {index}")
        for key in ("wave_fire", "owner_fire"):
            handshake[key] += int(observed[key].strip(), 16)
        handshake["clock_low_errors"] += int(observed["clock_low"].strip() != "0")
        handshake["stability_errors"] += int(observed["stable_between_edges"].strip() != "1")
        # 配置启动预备阶段未规定固定延迟；只保留硬复位和正式帧比较。
        if -4 <= int(gold["tick"]) < 0:
            continue
        for name in signal_names:
            result = results[name]
            if gold[name] == "":
                result["unknown_ticks"] += 1
                continue
            result["compared_ticks"] += 1
            wanted = int(gold[name])
            rendered = observed[name].strip().lower()
            found = None if "x" in rendered or "z" in rendered else int(rendered, 16)
            if found == wanted:
                continue
            result["mismatch_ticks"] += 1
            result["mismatch_bits"] += (found ^ wanted).bit_count() if found is not None else 1
            result["last_tick"] = int(gold["tick"])
            if result["first"] is None:
                result["first"] = {"row": index, "tick": int(gold["tick"]),
                                   "macro_tick": int(gold["macro_tick"]), "local_tick": int(gold["local_tick"]),
                                   "expected": wanted, "actual": found if found is not None else rendered}
    failed = bool(structure or handshake["clock_low_errors"] or handshake["stability_errors"] or
                  any(item["mismatch_ticks"] for item in results.values()))
    unknown = any(item["unknown_ticks"] for item in results.values())
    return {"status": "MISMATCH" if failed else "PARTIAL_UNCERTAIN" if unknown else "PASS",
            "rows": len(actual), "structure_errors": structure, "audit": handshake, "signals": results}
