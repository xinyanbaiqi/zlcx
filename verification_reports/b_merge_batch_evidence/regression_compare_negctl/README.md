# `regression_evidence.py compare`: $finish compared by time and file (2026-10-09)

The stage-3 label renames (`68edf17`) added a 2-line change-log entry to the headers of 6 TBs, and BMI-145
(`c15e648`) did the same to `tb_ppg_system_config_manager.v`. Every source line after the header, the `$finish`
statement included, moved down by 2. `export` keeps the whole `$finish called at time : T : File "x.v" Line N`
line, and `compare` used to compare it whole, so the final regression would have reported these 7 TBs as
FINISH_DIFF (exit 1) although the `$finish` time is unchanged. The brief (§6.8) requires the `$finish` time to be equal.

Change: `compare` now compares ($finish time, file name). If only `Line` differs, the TB is marked
`FINISH_LINE_SHIFT` with the old and new line numbers; this is not counted as a problem and does not change
the exit status. A different time or file is still `FINISH_DIFF`, exit 1. `export` is unchanged (finish.txt
keeps the line number for the explanation).

| File | Run | Result |
|---|---|---|
| `self_compare.txt` | `baseline_7a8eabf` vs itself | 49 SAME, exit 0 |
| `negctl_A_line_shift.txt` | copy with only the `Line` of `system/tb_ppg_control_top_lifecycle_fault_adc_anomaly.finish.txt` changed (2173 -> 753) | that TB `FINISH_LINE_SHIFT`, problems 0, exit 0 |
| `negctl_B_time_diff.txt` | copy with the time of `unit/tb_ppg_adc_dc_recovery.finish.txt` changed (571 ns -> 1571 ns) | that TB `FINISH_DIFF`, problems 1, exit 1 |

The copies were made in a scratch directory outside the repository; only the outputs are kept here.
