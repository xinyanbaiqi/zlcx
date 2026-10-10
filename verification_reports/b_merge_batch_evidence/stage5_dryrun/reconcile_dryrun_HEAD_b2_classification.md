# reconcile_acceptance_ids.py dry run (path-fixed), B2_ALIAS_ROW_MISSING classification

Run on the working tree at the stage-5 development point (contracts after stage 2). Counts: {"B2_ALIAS_ROW_MISSING": 35, "A_CONSISTENT": 267, "B_TAG_MISSING": 22, "D_PENDING_KNOWN": 1, "E_STALE_MATRIX_TEXT": 16}

## Known false positives: pseudo IDs cut from `@satisfies:` text inside TB file-header revision notes (22)

| Pseudo ID (as parsed) | Source |
| --- | --- |
| 33 measurement results). | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| ADCN-03`标签的`o_saturation_low | `rtl/ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v:25` |
| ADCN-03标签）， | `rtl/ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v:781` |
| ADCN-03）， | `rtl/ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v:1012` |
| PRC-04) plus the module's own o_baseline_saturation_high | `rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:32` |
| PRC-04`标签），加上该模块自己导出的`o_baseline_saturation_high | `rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:63` |
| PRC-06标签） | `rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:1041` |
| PRC-06）和 | `rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:323` |
| SMOKE_TB_PASS (49 real ADC responses | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| TOP-01 tag); a new standalone scenario at file end drives a real in-flight owner then resets mid-transaction | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| TOP-01`标签）；文件末尾新增独立场景，真实建立在途事务后触发复位，确认状态完全清零、结果计数不因旧事务静默递增，再确认重新COMMIT+START真的能产生全新结果。TOP-02：SMOKE-05与SMOKE-06之间新增负向场景，只 | `rtl/ppg_control_top/tb_ppg_control_top.v:56` |
| TOP-01标签）， | `rtl/ppg_control_top/tb_ppg_control_top.v:1176` |
| confirming state fully clears and the result counter does not silently advance | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| cross-checked PPG_ALIAS_MAPPING_TABLE.md's existing entries for both IDs and found they already cited cross-file evidenc | `rtl/ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v:24` |
| for the first real assertion on o_measurement_result_discard_event (previously only a $display). TOP-15: a permanent bac | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| just not routed to ppg_control_top's own top-level ports). Before fixing | `rtl/ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v:24` |
| matching the RTL's own documented intent rather than the literal but incorrect first reading of the contract prose. All  | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| not assumed). TOP-18: SMOKE-19's existing 4000-cycle STATIC_BIAS steady-state loop gains two per-cycle checks; the first | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| so both reflect pre-this-edge settled values on a common time basis); an earlier version that added an extra one-cycle d | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| so the assertion was corrected to measurement_run_enable==0 and analog_run_enable==1 | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| then confirms a fresh commit+start genuinely produces a new result. TOP-02: a new negative scenario between SMOKE-05 and | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |
| which real simulation proved has zero pending measurement result to discard by construction) builds a genuinely held res | `rtl/ppg_control_top/tb_ppg_control_top.v:29` |

## Real `@satisfies` tags with no alias-table row (13) — to be added in stage 3

| ID | Tag locations |
| --- | --- |
| AMI-24 | `rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1239` |
| FSC-03 | `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:494` |
| FSC-17 | `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:847`; `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:1176`; `rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v:1719` |
| FSC-31 | `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:492` |
| FSC-32 | `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:492` |
| FSC-38 | `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:1253` |
| FSC-46 | `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:469`; `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:1202`; `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:1217` |
| FSC-49 | `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:469`; `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:1202` |
| FSC-50 | `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:469` |
| MGR-11 | `rtl/ppg_system_config_manager/ppg_system_config_manager.v:464` |
| SSW-22 | `rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v:525` |
| SSW-34 | `rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v:440` |
| SSW-38 | `rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v:1522`; `rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v:1671`; `rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v:440` |

## Pseudo location inside a real ID

`ADCN-03` is A_CONSISTENT through its real RTL tags (`ppg_adc_s1_programmable_calibrator.v`), but the scan also
records `rtl/ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v:24`, which is the header revision-note
text "ADCN-03, just not routed ..." (as noted in ID_GOVERNANCE_AUDIT_20261005.md section 9). It does not change
the class; it is listed with the known false positives.
