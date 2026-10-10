"""构造任务书要求的场景数据；不读取RTL或先前测试报告。"""

import json
from pathlib import Path


def matrix() -> list[dict]:
    """覆盖颜色、精度、码图样、校准、owner与生命周期关键边沿。"""
    cases = []
    for precision in (0, 1):
        for mode, label in ((0, "both"), (1, "red"), (2, "ir")):
            for pattern in (165, 90, 0, 255):
                cases.append(dict(name=f"normal_{label}_sar{9 if not precision else 15}_{pattern:02x}",
                                  precision=precision, optical_mode=mode, patterns=[pattern] * 4))
    for kind, color, label in ((0, 0, "amb"), (1, 0, "dcs_red"), (1, 1, "dcs_ir")):
        for pattern in (165, 90, 0, 255):
            cases.append(dict(name=f"cal_{label}_{pattern:02x}", frame_type=kind, color=color,
                              precision=0, patterns=[pattern] * 4))
    for order in ([0, 1], [1, 0]):
        cases.append(dict(name="precision_switch_" + "_".join(map(str, order)), precisions=order))
    cases += [dict(name="owner_miss_red", miss_owner="red"),
              dict(name="owner_miss_ir", miss_owner="ir"),
              dict(name="owner_miss_cal", miss_owner="cal", frame_type=0)]
    cases += [dict(name="owner_at_deadline_normal9", owner_tick=283, ir_owner_tick=443),
              dict(name="owner_at_deadline_normal15", precision=1, owner_tick=283, ir_owner_tick=443),
              dict(name="owner_at_deadline_cal", frame_type=0, owner_tick=248)]
    for precision in (0, 1):
        cases.append(dict(name=f"char_photodiode_red_sar{9 if not precision else 15}",
                          characterization=True, precision=precision, optical_mode=1))
        for mode, label in ((0, "both"), (1, "red"), (2, "ir")):
            cases.append(dict(name=f"char_current_{label}_sar{9 if not precision else 15}",
                              characterization=True, input_source=1, optical_mode=mode, precision=precision))
    cases.append(dict(name="static_bias", static=True, characterization=True, input_source=1))
    for precision in (0, 1):
        for mode, color, center in ((1, "red", 300), (2, "ir", 460)):
            first = center - (256 if not precision else 273)
            q1 = center - (7 if not precision else 16)
            last = center + (18 if not precision else 8)
            stages = [("before_preheat", first - 1), ("after_preheat", first + 1),
                      ("before_q1", q1 - 1), ("in_q3", center),
                      ("after_q3", center + (2 if not precision else 5)), ("before_end", last - 1)]
            for action in ("stop", "abort"):
                for label, tick in stages:
                    cases.append(dict(name=f"{action}_{color}_sar{9 if not precision else 15}_{label}",
                                      precision=precision, optical_mode=mode, **{action + "_tick": tick}))
    for precision in (0, 1):
        cases.append(dict(name=f"snapshot_payload_changes_sar{9 if not precision else 15}",
                          precision=precision, perturb_payload=True))
    return cases


if __name__ == "__main__":
    path = Path(__file__).resolve().parents[1] / "scenarios" / "matrix.json"
    path.write_text(json.dumps(matrix(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(matrix())} scenarios")
