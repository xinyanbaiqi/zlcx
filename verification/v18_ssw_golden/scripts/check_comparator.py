"""比较器负对照：检验单拍边沿、单bit码值、X、缺行和重复行都能被发现。"""

from __future__ import annotations

import argparse
import copy
import csv
import json
import sys
from pathlib import Path

from compare import compare

TASK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TASK / "golden"))
from model import OUTPUTS


def main() -> None:
    """以冻结的SAR9期望表构造正确采集，再主动注入互相独立的错误。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=TASK / "_runs/comparator_checks")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    signals = [name for name, _, _ in OUTPUTS]
    with args.expected.open(encoding="utf-8", newline="") as stream:
        expected = list(csv.DictReader(stream))
    nominal = [dict(row=row["row"], **{name: format(int(row[name]), "x") for name in signals},
                    wave_fire="0", owner_fire="0", clock_low="0", stable_between_edges="1")
               for row in expected]
    results = {}

    def check(label: str, rows: list[dict]) -> dict:
        path = args.out / (label + ".csv")
        with path.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(nominal[0]))
            writer.writeheader()
            writer.writerows(rows)
        result = compare(args.expected, path, signals)
        results[label] = result
        return result

    assert check("positive_control", nominal)["status"] == "PASS"
    code_row = next(index for index, row in enumerate(expected) if int(row["o_idac_sar9ambn_low"]) != 0)
    changed = copy.deepcopy(nominal)
    changed[code_row]["o_idac_sar9ambn_low"] = format(int(changed[code_row]["o_idac_sar9ambn_low"], 16) ^ 64, "x")
    bit_result = check("single_idac_bit", changed)["signals"]["o_idac_sar9ambn_low"]
    assert bit_result["mismatch_ticks"] == 1 and bit_result["mismatch_bits"] == 1
    assert bit_result["first"]["row"] == code_row
    edge_row = next(index for index, row in enumerate(expected) if int(row["tick"]) == 298)
    changed = copy.deepcopy(nominal)
    changed[edge_row]["o_leden1_low"] = "1"
    assert check("early_led_edge", changed)["signals"]["o_leden1_low"]["first"]["tick"] == 298
    changed = copy.deepcopy(nominal)
    changed[code_row]["o_idac_sar9ambn_low"] = "xx"
    assert check("unknown_logic", changed)["status"] == "MISMATCH"
    assert check("missing_row", nominal[:-1])["structure_errors"]
    changed = copy.deepcopy(nominal)
    changed[-1] = copy.deepcopy(changed[-2])
    assert check("duplicate_row", changed)["structure_errors"]
    changed = copy.deepcopy(nominal)
    changed[8]["clock_low"] = "1"
    assert check("wrong_clock_low", changed)["audit"]["clock_low_errors"] == 1
    changed = copy.deepcopy(nominal)
    changed[8]["stable_between_edges"] = "0"
    assert check("control_changes_between_edges", changed)["audit"]["stability_errors"] == 1
    summary = {name: {"status": result["status"], "structure_errors": result["structure_errors"],
                      "audit": result["audit"], "mismatch_signals": {
                          signal: info for signal, info in result["signals"].items() if info["mismatch_ticks"]}}
               for name, result in results.items()}
    (args.out / "checks.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Comparator integrity: {len(results)} controls passed")


if __name__ == "__main__":
    main()
