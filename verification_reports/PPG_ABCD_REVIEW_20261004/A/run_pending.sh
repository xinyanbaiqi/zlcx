#!/bin/bash
set -u
bash /mnt/c/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/evidence/compile/tb_ppg_control_top_normal_slow_tracking/run.sh &
bash /mnt/c/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/evidence/compile/tb_ppg_control_top_owner_identity_backpressure/run.sh &
bash /mnt/c/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/evidence/compile/tb_ppg_control_top_peak_valley_return/run.sh &
bash /mnt/c/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/evidence/compile/tb_ppg_control_top_periodic_recheck_recovery/run.sh &
wait
bash /mnt/c/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/evidence/compile/tb_ppg_control_top_robustness_corner_waveforms/run.sh &
bash /mnt/c/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/evidence/compile/tb_ppg_control_top_startup_idac_calibration/run.sh &
wait
