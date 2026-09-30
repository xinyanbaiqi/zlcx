#!/bin/bash
# Phase 6 regression driver: runs each of the 19 standalone ppg_control_top TB files
# through xvlog+xelab+xsim (Vivado 2022.2) individually and produces one summary.
set -u
export PATH="${VIVADO_BIN:-/c/Xilinx/Vivado/2022.2/bin}:$PATH"
cd "$(dirname "$0")"

OUTDIR="xsim_regression_20260906"
mkdir -p "$OUTDIR"
SUMMARY="$OUTDIR/summary.tsv"
echo -e "tb_name\tfilelist\tsnapshot\txvlog\txelab\txsim\tpass_count\tfail_count\tfinished\tduration_s\tlog_dir" > "$SUMMARY"

# tb_name : filelist
declare -A TB_FILELIST=(
  [tb_ppg_control_top]=xsim_main_filelist.f
  [tb_ppg_control_top_baseline_cross]=xsim_baseline_cross_filelist.f
  [tb_ppg_control_top_fir_tail_isolation]=xsim_fir_tail_isolation_filelist.f
  [tb_ppg_control_top_adc_numeric_scoreboard]=xsim_adc_numeric_scoreboard_filelist.f
  [tb_diag_algo_probe]=xsim_diag_filelist.f
  [tb_ppg_control_top_idac_bus_isolation]=xsim_idac_bus_isolation_filelist.f
  [tb_ppg_control_top_injection]=xsim_injection_filelist.f
  [tb_ppg_control_top_lifecycle_fault_adc_anomaly]=xsim_lifecycle_fault_adc_anomaly_filelist.f
  [tb_ppg_control_top_input_light_static_matrix]=xsim_input_light_static_matrix_filelist.f
  [tb_ppg_control_top_longrun]=xsim_longrun_filelist.f
  [tb_ppg_control_top_long_10_cycles]=xsim_long_10_cycles_filelist.f
  [tb_ppg_control_top_normal_slow_tracking]=xsim_normal_slow_tracking_filelist.f
  [tb_ppg_control_top_no_recheck_control]=xsim_no_recheck_control_filelist.f
  [tb_ppg_control_top_owner_identity_backpressure]=xsim_owner_identity_backpressure_filelist.f
  [tb_ppg_control_top_peak_valley_return]=xsim_peak_valley_return_filelist.f
  [tb_ppg_control_top_periodic_recheck_recovery]=xsim_periodic_recheck_recovery_filelist.f
  [tb_ppg_control_top_robustness_corner_waveforms]=xsim_robustness_corner_waveforms_filelist.f
  [tb_ppg_control_top_startup_idac_calibration]=xsim_startup_idac_calibration_filelist.f
  [tb_ppg_real_raw_generator_selfcheck]=xsim_raw_generator_selfcheck_filelist.f
)

ORDER=(
  tb_diag_algo_probe
  tb_ppg_real_raw_generator_selfcheck
  tb_ppg_control_top
  tb_ppg_control_top_baseline_cross
  tb_ppg_control_top_fir_tail_isolation
  tb_ppg_control_top_adc_numeric_scoreboard
  tb_ppg_control_top_idac_bus_isolation
  tb_ppg_control_top_injection
  tb_ppg_control_top_lifecycle_fault_adc_anomaly
  tb_ppg_control_top_input_light_static_matrix
  tb_ppg_control_top_normal_slow_tracking
  tb_ppg_control_top_no_recheck_control
  tb_ppg_control_top_owner_identity_backpressure
  tb_ppg_control_top_peak_valley_return
  tb_ppg_control_top_periodic_recheck_recovery
  tb_ppg_control_top_robustness_corner_waveforms
  tb_ppg_control_top_startup_idac_calibration
  tb_ppg_control_top_long_10_cycles
  tb_ppg_control_top_longrun
)

for tb in "${ORDER[@]}"; do
  fl="${TB_FILELIST[$tb]}"
  logdir="$OUTDIR/$tb"
  mkdir -p "$logdir"
  snap="snap_${tb}"
  echo "=== $tb (filelist=$fl) ==="
  t0=$(date +%s)

  xvlog.bat -f "$fl" -i . > "$logdir/xvlog.log" 2>&1
  xvlog_rc=$?

  xelab_rc=1
  xsim_rc=1
  if [ $xvlog_rc -eq 0 ]; then
    xelab.bat "$tb" -s "$snap" -timescale 1ns/1ps > "$logdir/xelab.log" 2>&1
    xelab_rc=$?
  else
    echo "SKIPPED (xvlog failed)" > "$logdir/xelab.log"
  fi

  if [ $xelab_rc -eq 0 ]; then
    xsim.bat "$snap" -runall -log "$logdir/xsim.log" > "$logdir/xsim_stdout.log" 2>&1
    xsim_rc=$?
  else
    echo "SKIPPED (xelab failed)" > "$logdir/xsim.log"
  fi

  t1=$(date +%s)
  dur=$((t1 - t0))

  if [ -f "$logdir/xsim.log" ]; then
    pass_count=$(grep -c -E "^PASS " "$logdir/xsim.log" 2>/dev/null); pass_count=${pass_count:-0}
    fail_count=$(grep -c -E "^FAIL |ERROR:|FATAL_ERROR|UVM_ERROR" "$logdir/xsim.log" 2>/dev/null); fail_count=${fail_count:-0}
    finished=$(grep -c 'finish called' "$logdir/xsim.log" 2>/dev/null); finished=${finished:-0}
  else
    pass_count=0
    fail_count=0
    finished=0
  fi

  echo -e "${tb}\t${fl}\t${snap}\t${xvlog_rc}\t${xelab_rc}\t${xsim_rc}\t${pass_count}\t${fail_count}\t${finished}\t${dur}\t${logdir}" >> "$SUMMARY"
  echo "  xvlog_rc=$xvlog_rc xelab_rc=$xelab_rc xsim_rc=$xsim_rc pass=$pass_count fail=$fail_count finished=$finished dur=${dur}s"
done

echo "=== DONE ==="
cat "$SUMMARY"
