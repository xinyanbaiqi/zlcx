"""Aggregate independent V1.3 TB result artifacts without manufacturing PASS."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


SCENARIOS = {
    1: "PPG-LONG-10-CYCLES",
    2: "NO-RECHECK-CROSS-CONTROL",
    3: "INPUT-LIGHT-STATIC-MATRIX",
    4: "STARTUP-IDAC-CALIBRATION",
    5: "NORMAL-IDAC-SLOW-TRACKING",
    6: "PERIODIC-RECHECK-RECOVERY",
    7: "ADC-NUMERIC-CODE-SCOREBOARD",
    8: "IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION",
    9: "OWNER-IDENTITY-BACKPRESSURE",
    10: "LIFECYCLE-FAULT-ADC-ANOMALY",
    11: "PPG-ROBUSTNESS-CORNER-WAVEFORMS",
}
OWNER_BY_PREFIX = {
    "SID": 4, "TRK": 5, "RRC": 6, "NRE": 2, "ILM": 3,
    "ADCN": 7, "ISE": 8, "OIB": 9, "LFA": 10, "PRC": 11,
}

STABLE_RE = re.compile(r"TB_STABLE_RESULT\s+index=(\d+)\s+id=(\S+)\s+status=(PASS|FAIL|NOT_CLOSED)")
JNT_RE = re.compile(
    r"TB_JNT_BASELINE\s+run=(\d+)\s+group=(\S+)\s+checked=(\d+)\s+pass=(\d+)\s+fail=(\d+)\s+required=(\d+).*?status=(PASS|FAIL|NOT_CLOSED)"
)


def parse_artifact(path: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    stable = {}
    for match in STABLE_RE.finditer(text):
        stable[match.group(2)] = {
            "index": int(match.group(1)),
            "status": match.group(3),
        }
    jnt = []
    for match in JNT_RE.finditer(text):
        jnt.append(
            {
                "run": int(match.group(1)),
                "group": match.group(2),
                "checked": int(match.group(3)),
                "pass": int(match.group(4)),
                "fail": int(match.group(5)),
                "required": int(match.group(6)),
                "status": match.group(7),
            }
        )
    return {"file": str(path), "stable": stable, "jnt": jnt}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("result_dir", type=Path)
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()

    artifacts = []
    for selector, name in SCENARIOS.items():
        path = args.result_dir / f"{name}.result.log"
        if path.exists():
            parsed = parse_artifact(path)
            parsed["selector"] = selector
            parsed["scenario"] = name
            artifacts.append(parsed)
        else:
            artifacts.append({"selector": selector, "scenario": name, "file": str(path), "stable": {}, "jnt": []})

    stable_union = {}
    for artifact in artifacts:
        for stable_id, entry in artifact["stable"].items():
            if OWNER_BY_PREFIX.get(stable_id.split("-", 1)[0]) == artifact["selector"]:
                stable_union[stable_id] = {**entry, "scenario": artifact["scenario"]}

    jnt_failures = []
    for artifact in artifacts:
        if not artifact["jnt"]:
            jnt_failures.append({"scenario": artifact["scenario"], "reason": "missing JNT records"})
            continue
        for record in artifact["jnt"]:
            if not (record["required"] == 52 and record["checked"] == 52 and record["pass"] == 52 and record["fail"] == 0 and record["status"] == "PASS"):
                jnt_failures.append({"scenario": artifact["scenario"], **record})

    stable_failures = sorted(
        [stable_id for stable_id, entry in stable_union.items() if entry["status"] != "PASS"]
    )
    stable_not_closed = sorted(
        [stable_id for stable_id, entry in stable_union.items() if entry["status"] == "NOT_CLOSED"]
    )
    summary = {
        "version": "V1.3",
        "scenario_count": len(artifacts),
        "scenarios_present": sum(bool(a["jnt"]) for a in artifacts),
        "stable_union_count": len(stable_union),
        "stable_pass_count": sum(entry["status"] == "PASS" for entry in stable_union.values()),
        "stable_failures": stable_failures,
        "stable_not_closed": stable_not_closed,
        "jnt_failures": jnt_failures,
        "missing_artifacts": [a["scenario"] for a in artifacts if not a["jnt"]],
        "status": "PASS" if len(stable_union) == 107 and not stable_failures and not jnt_failures else "NOT_CLOSED",
        "artifacts": artifacts,
    }
    payload = json.dumps(summary, indent=2, ensure_ascii=True)
    if args.out:
        args.out.write_text(payload + "\n", encoding="utf-8")
    print(payload)
    return 0 if summary["status"] == "PASS" else 2


if __name__ == "__main__":
    sys.exit(main())
