# Anchor gate in the regression entry (BMI-153, 2026-10-09)

`tools/b_merge_tools/run_anchor_gate.sh` runs `anchor_check.py` over the closure matrix, the alias table
and every contract. `tools/run_unit_tb_regression.sh` calls it first, so a broken anchor stops the whole
regression round with exit 1 before any simulation starts. The gate script can also be run on its own.
With Python >= 3.9 names are resolved through the erie-verilog-generator formatter AST. An older
interpreter uses the text search built into `anchor_check.py`, with the same pass/fail rules.
Both were tried here: Python 3.8.5 gives 0 errors in about 5 s; Python 3.12 with the AST also gives 0 errors.

Local demonstration (this laptop, Vivado 2019.2, reference only; the formal demonstration is part of
the final regression on the regression machine, `../REGRESSION_RUN_REQUEST.md` §2):

| File | Run | Result |
|---|---|---|
| `regression_gate_pass.txt` | `run_unit_tb_regression.sh` on two renamed TBs (`tb_ppg_adc_dc_recovery`, `tb_ppg_system_fault_abort_supervisor`) | gate PASSED, then 2/2 TB PASS with the new banners matched; exit 0 |
| `regression_gate_negctl.txt` | same command after injecting one bad anchor into the matrix (`ppg_amb_recheck_scheduler.v` `i_amb_enable` -> `i_amb_enablX`) | gate reports `name-missing` and FAILED; round stopped before simulation (no output directory created); exit 1. Matrix restored afterwards, SHA-1 identical |
| `renamed_unit_tbs_local_2019.2.txt` | the other three renamed unit TBs (scheduler, AMI, SSW) | gate PASSED; 3/3 PASS with the new banner regexes |

The renamed system TB (`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v`) is run by
`rtl/ppg_control_top/run_xsim_regression.sh`, which has no banner regex for it. Its PASS lines are compared in the final regression.
