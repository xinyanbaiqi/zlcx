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
    cases.append(dict(name="cal_amb_candidate_sequence", frame_type=0))
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
    for kind, color, family in ((0, 0, "amb"), (1, 0, "dcs_red"), (1, 1, "dcs_ir")):
        for action in ("stop", "abort"):
            for label, tick in (("before_preheat", 9), ("after_preheat", 11),
                                ("before_q1", 258), ("in_q3", 266),
                                ("after_q3", 268), ("before_end", 283)):
                cases.append(dict(name=f"cal_lifecycle_{action}_{family}_{label}", frame_type=kind,
                                  color=color, **{action + "_tick": tick}))
    for precision in (0, 1):
        cases.append(dict(name=f"normal_led_patterns_sar{9 if not precision else 15}",
                          precisions=[precision] * 4, led_patterns=[0, 255, 165, 90],
                          ir_led_patterns=[255, 0, 90, 165]))
        cases.append(dict(name=f"normal_color_codes_sar{9 if not precision else 15}", precision=precision,
                          dc_patterns=[60] * 4, ir_dc_patterns=[195] * 4))
    cases.extend([dict(name="owner_miss_red_sar15", miss_owner="red", precision=1),
                  dict(name="owner_miss_ir_sar15", miss_owner="ir", precision=1)])
    cases.extend([dict(name="known_sar15_deadline_red_275", precision=1, optical_mode=1, owner_tick=275),
                  dict(name="known_sar15_deadline_ir_435", precision=1, optical_mode=2, ir_owner_tick=435)])
    return cases


if __name__ == "__main__":
    path = Path(__file__).resolve().parents[1] / "scenarios" / "matrix.json"
    path.write_text(json.dumps(matrix(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lifecycle = [case for case in matrix() if "stop_tick" in case or "abort_tick" in case]
    path.with_name("lifecycle_matrix.json").write_text(json.dumps(lifecycle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    extras = [case for case in matrix() if "miss_owner" in case or "led_patterns" in case or "dc_patterns" in case]
    path.with_name("extra_matrix.json").write_text(json.dumps(extras, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    known = [case for case in matrix() if case["name"].startswith("known_sar15_deadline")]
    path.with_name("known_deadline_matrix.json").write_text(json.dumps(known, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(matrix())} scenarios")
