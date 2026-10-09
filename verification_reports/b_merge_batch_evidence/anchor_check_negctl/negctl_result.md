# anchor_check.py negative control (2026-10-09)

Worktree of branch commit `f8986b3` (contracts as after stage 2). `anchor_check.py` run before and after five injected faults that keep every line count unchanged. Errors are compared as (file, line, kind, text).

- before: 6911 errors (stats {"symbol_anchors": 39, "satisfies_anchors": 0, "section_refs": 78, "old_anchor_history": 56})
- after:  6916 errors (stats {"symbol_anchors": 38, "satisfies_anchors": 0, "section_refs": 78, "old_anchor_history": 56})
- new errors: 5, disappeared errors: 0

| Injected fault | Reported as |
| --- | --- |
| PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md line 148 | `name-missing` ppg_400hz_frame_calibration_scheduler.v flag_calibration_rollovrX |
| PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md line 805 | `section-missing` C08 §10.9 |
| PPG_ALIAS_MAPPING_TABLE.md line 22 | `line-anchor` ppg_control_top.v:12 |
| PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md line 355 | `file-missing` ppg_sar9_sar15_safe_selection_wrappr.v |
| PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md line 83 | `section-ambiguous` C01 §4.1 needs a heading title (输入 / V1.10 final system boundary and one-to-one connection requirements) |

Injections: C08 `flag_calibration_rollover` -> `flag_calibration_rollovrX` (in a real `file` `name` anchor); C09 file token `ppg_sar9_sar15_safe_selection_wrapper.v` -> `...wrappr.v`; C10 `C08 §10.4` -> `C08 §10.9`; C24 `C10 §7.1a` -> `C01 §4.1` (number duplicated in C01, no title); alias-table line 22 gains `ppg_control_top.v:12`.

A first attempt changed a mention of `flag_frame_restart` inside a change-record sentence that has no file token before it; the checker correctly did not treat it as an anchor (symbols are only checked when they follow a backticked `.v`/`.vh` file name). That injection was replaced by the one in the table.

`@satisfies` anchors: none exist yet in the new format, so that path is negative-controlled again after the stage-4 conversion.
The ~7,400 pre-existing errors are the old line anchors of the matrix and alias table that stage 4 converts.

## Addendum: TB label tokens (2026-10-09)

`anchor_check.py` now also checks backticked `"text"` tokens after a TB file name (verbatim
substring of the TB source). Negative control on a scratch copy of the alias table: changing
"consumed" to "eaten" in the SID-11 PASS text gave exactly one new error
(`label-missing tb_ppg_control_top_startup_idac_calibration.v "PASS SID-11 double-saturated sample eaten by its own qualified-gate reject path"`).
