#!/bin/bash
# =============================================================================
# PPG module-level unit-TB regression driver (Vivado xvlog -> xelab -> xsim).
#
# Covers the 28 module-level self-checking testbenches under rtl/:
#   hier   : 24 TBs whose DUT sits inside the chip hierarchy
#   orphan :  4 TBs of modules that are not instantiated by the chip hierarchy
# The other two suites have their own drivers and are NOT run here:
#   rtl/ppg_control_top/run_xsim_regression.sh       (19-TB system suite)
#   rtl/ppg_chip_digital_top/run_xsim_regression.sh  (chip glue top)
#
# Usage:
#   tools/run_unit_tb_regression.sh [-o OUT_DIR] [-g hier|orphan|all] [TB_NAME ...]
#     -o OUT_DIR  where logs/xsim work dirs go. Default:
#                 <repo parent>/ppg_unit_tb_runs/<YYYYmmdd_HHMMSS>
#                 A directory inside the repository is refused, so a run can
#                 never leave xsim products in the working tree.
#     -g GROUP    run only one group (default: all)
#     TB_NAME     run only the named TBs (e.g. tb_ppg_idac_code_controller)
#   Environment:
#     VIVADO_BIN  directory holding xvlog/xelab/xsim
#                 (default /c/Xilinx/Vivado/2022.2/bin)
#
# Pass criteria per TB (same as REGRESSION_BASELINE_20260930.md):
#   xvlog, xelab and xsim all return 0; the xsim log contains "$finish called";
#   it contains no FAIL / ERROR: / FATAL line; and the TB's own final verdict
#   banner (listed per TB below) is present.
# Output: <OUT_DIR>/<tb>/{filelist.f,xvlog.log,xelab.log,xsim.log,...}
#         <OUT_DIR>/unit_summary.tsv (one line per TB)
# Exit status: 0 when every selected TB passes, 1 otherwise, 2 on usage error.
# =============================================================================
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
RTL="$REPO/rtl"
VIVADO_BIN="${VIVADO_BIN:-/c/Xilinx/Vivado/2022.2/bin}"
export PATH="$VIVADO_BIN:$PATH"

# Windows Vivado ships xvlog.bat etc.; Linux ships plain executables.
if command -v xvlog.bat >/dev/null 2>&1; then EXE=".bat"; else EXE=""; fi
if ! command -v "xvlog$EXE" >/dev/null 2>&1; then
  echo "ERROR: xvlog not found; set VIVADO_BIN (now: $VIVADO_BIN)" >&2
  exit 2
fi

# Vivado on Windows cannot open MSYS-style /d/... paths; hand it D:/... paths.
native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

# -----------------------------------------------------------------------------
# TB table: name | group | TB file | final-banner ERE | RTL deps
# Paths are relative to rtl/. Dependency lists are the exact compile closure,
# derived with `iverilog -y <each rtl dir> -M` (tb_..._phase_a_... is
# self-contained and needs no RTL).
# -----------------------------------------------------------------------------
TB_TABLE=(
  # ---------------- hier: DUT inside the chip hierarchy (24) ----------------
  "tb_ppg_400hz_frame_calibration_scheduler|hier|ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v|^ALL FSC-01 THROUGH FSC-62 PASSED$|ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v"
  "tb_ppg_active_v4_control_plane_integration|hier|ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v|^ALL AV4C-01 THROUGH AV4C-22 PASSED$|ppg_active_v4_control_plane_integration/ppg_active_v4_control_plane_integration.v ppg_config_cdc_bridge/ppg_config_cdc_bridge.v ppg_system_active_config_unpack/ppg_system_active_config_unpack.v ppg_system_config_manager/ppg_system_config_manager.v"
  "tb_ppg_adc_async_stage_capture|hier|ppg_adc_async_stage_capture/tb_ppg_adc_async_stage_capture.v|^PASS ppg_adc_async_stage_capture explicit-frame checks$|ppg_adc_async_stage_capture/ppg_adc_async_stage_capture.v"
  "tb_ppg_adc_dc_recovery|hier|ppg_adc_dc_recovery/tb_ppg_adc_dc_recovery.v|^PASS ppg_adc_dc_recovery DCR-01\.\.DCR-22$|ppg_adc_dc_recovery/ppg_adc_dc_recovery.v"
  "tb_ppg_adc_measurement_idac_integration|hier|ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v|^AMI-01 through AMI-45, AMI-DISC-1/2, AMI-SID05-1/2 plus N08-01 PASS: [0-9]+ real comparisons$|ppg_adc_async_stage_capture/ppg_adc_async_stage_capture.v ppg_adc_dc_recovery/ppg_adc_dc_recovery.v ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v ppg_adc_programmable_reconstructor/ppg_adc_programmable_reconstructor.v ppg_adc_result_router/ppg_adc_result_router.v ppg_adc_s1_programmable_calibrator/ppg_adc_s1_programmable_calibrator.v ppg_adc_s1_redundancy_corrector/ppg_adc_s1_redundancy_corrector.v ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v ppg_coarse_detection_fir/ppg_coarse_detection_fir.v ppg_dynamic_baseline_cross_detector/ppg_dynamic_baseline_cross_detector.v ppg_idac_code_controller/ppg_idac_code_controller.v ppg_normal_transaction_fork/ppg_normal_transaction_fork.v ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v ppg_precision_window_controller/ppg_precision_window_controller.v ppg_precision_window_integration/ppg_precision_window_integration.v"
  "tb_ppg_adc_pipeline_overlap_corrector|hier|ppg_adc_pipeline_overlap_corrector/tb_ppg_adc_pipeline_overlap_corrector.v|^PASS ppg_adc_pipeline_overlap_corrector OVL-01\.\.OVL-17 and 1024-code sweep$|ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v"
  "tb_ppg_adc_programmable_reconstructor|hier|ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v|^PASS ppg_adc_programmable_reconstructor PR-01\.\.PR-14 and 1024-code sweep$|ppg_adc_programmable_reconstructor/ppg_adc_programmable_reconstructor.v"
  "tb_ppg_adc_result_router|hier|ppg_adc_result_router/tb_ppg_adc_result_router.v|^PASS ppg_adc_result_router RTR-01\.\.RTR-13$|ppg_adc_result_router/ppg_adc_result_router.v"
  "tb_ppg_adc_s1_programmable_calibrator|hier|ppg_adc_s1_programmable_calibrator/tb_ppg_adc_s1_programmable_calibrator.v|^PASS ppg_adc_s1_programmable_calibrator CAL-01\.\.CAL-17$|ppg_adc_s1_programmable_calibrator/ppg_adc_s1_programmable_calibrator.v"
  "tb_ppg_adc_s1_redundancy_corrector|hier|ppg_adc_s1_redundancy_corrector/tb_ppg_adc_s1_redundancy_corrector.v|^PASS ppg_adc_s1_redundancy_corrector integrated exhaustive checks$|ppg_adc_async_stage_capture/ppg_adc_async_stage_capture.v ppg_adc_s1_redundancy_corrector/ppg_adc_s1_redundancy_corrector.v"
  "tb_ppg_amb_recheck_scheduler|hier|ppg_amb_recheck_scheduler/tb_ppg_amb_recheck_scheduler.v|^PASS: ppg_amb_recheck_scheduler completed scheduler regression$|ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v"
  "tb_ppg_characterization_control_cdc|hier|ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v|^ALL CCC-01 TO CCC-26 PASS \([0-9]+ checks\)$|ppg_characterization_control_cdc/ppg_characterization_control_cdc.v ppg_config_cdc_bridge/ppg_config_cdc_bridge.v"
  "tb_ppg_coarse_detection_fir|hier|ppg_coarse_detection_fir/tb_ppg_coarse_detection_fir.v|^PPG_COARSE_DETECTION_FIR_V2_TB_PASS pass=[0-9]+$|ppg_coarse_detection_fir/ppg_coarse_detection_fir.v"
  "tb_ppg_dynamic_baseline_cross_detector|hier|ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v|^ALL BSL-01 THROUGH BSL-39, OPT-01 THROUGH OPT-24 AND OPTC-01 THROUGH OPTC-02 PASS count=[0-9]+$|ppg_dynamic_baseline_cross_detector/ppg_dynamic_baseline_cross_detector.v"
  "tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence|hier|ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence.v|^PHASE_A_ARITH_EQV PASS vectors=[0-9]+$|"
  "tb_ppg_idac_code_controller|hier|ppg_idac_code_controller/tb_ppg_idac_code_controller.v|^PASS: ppg_idac_code_controller V2\.1 periodic sequence and IDT regression completed$|ppg_idac_code_controller/ppg_idac_code_controller.v"
  "tb_ppg_normal_transaction_fork|hier|ppg_normal_transaction_fork/tb_ppg_normal_transaction_fork.v|^PASS: ppg_normal_transaction_fork completed FFK-01 through FFK-09$|ppg_normal_transaction_fork/ppg_normal_transaction_fork.v"
  "tb_ppg_peak_valley_window_detector|hier|ppg_peak_valley_window_detector/tb_ppg_peak_valley_window_detector.v|^PVW-01 through PVW-48 ALL PASS: [0-9]+ checks$|ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v"
  "tb_ppg_precision_window_controller|hier|ppg_precision_window_controller/tb_ppg_precision_window_controller.v|^PWC-01 through PWC-41 ALL PASS pass=[0-9]+ fail=0$|ppg_precision_window_controller/ppg_precision_window_controller.v"
  "tb_ppg_precision_window_integration|hier|ppg_precision_window_integration/tb_ppg_precision_window_integration.v|^ALL PWI-01 THROUGH PWI-05 PASS count=[0-9]+$|ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v ppg_coarse_detection_fir/ppg_coarse_detection_fir.v ppg_dynamic_baseline_cross_detector/ppg_dynamic_baseline_cross_detector.v ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v ppg_precision_window_controller/ppg_precision_window_controller.v ppg_precision_window_integration/ppg_precision_window_integration.v"
  "tb_ppg_sar9_sar15_safe_selection_wrapper|hier|ppg_sar9_sar15_safe_selection_wrapper/tb_ppg_sar9_sar15_safe_selection_wrapper.v|^ALL SSW-01 THROUGH SSW-52 PASS$|ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v"
  "tb_ppg_system_active_config_unpack|hier|ppg_system_active_config_unpack/tb_ppg_system_active_config_unpack.v|^PASS: ppg_system_active_config_unpack all checks passed$|ppg_system_active_config_unpack/ppg_system_active_config_unpack.v"
  "tb_ppg_system_config_manager|hier|ppg_system_config_manager/tb_ppg_system_config_manager.v|^PASS: ppg_system_config_manager MGR-01 through MGR-24 all directed checks passed$|ppg_system_config_manager/ppg_system_config_manager.v"
  "tb_ppg_system_fault_abort_supervisor|hier|ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v|^SUP-01 through SUP-10 PASS: [0-9]+ real comparisons$|ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v"
  # ---------------- orphan: modules outside the chip hierarchy (4) ----------------
  "tb_ppg_dual_precision_top|orphan|ppg_dual_precision_top/tb_ppg_dual_precision_top.v|^PASS: ppg_dual_precision_top CDC and frame-safe timing contract verified$|ppg_config_cdc_bridge/ppg_config_cdc_bridge.v ppg_dual_precision_top/ppg_dual_precision_top.v ppg_reset_sync/ppg_reset_sync.v ppg_timing_sar15/ppg_timing_sar15.v ppg_timing_sar9/ppg_timing_sar9.v"
  "tb_ppg_timing_sar9|orphan|ppg_timing_sar9/tb_ppg_timing_sar9.v|^PASS: ppg_timing_sar9 optical, test-MUX, and static characterization modes matched\.$|ppg_timing_sar9/ppg_timing_sar9.v"
  "tb_ppg_timing_sar15|orphan|ppg_timing_sar15/tb_ppg_timing_sar15.v|^PASS: ppg_timing_sar15 optical, test-MUX, and static characterization modes matched\.$|ppg_timing_sar15/ppg_timing_sar15.v"
  "tb_ppg_timing_3200hz|orphan|ppg_timing_3200hz_validation/tb_ppg_timing_3200hz.v|^PASS: 3200 Hz frame, 80 us R/IR offsets, and Q3-center alignment verified\.$|ppg_timing_sar15/ppg_timing_sar15.v ppg_timing_sar15/ppg_timing_sar15_3200hz.v ppg_timing_sar9/ppg_timing_sar9.v ppg_timing_sar9/ppg_timing_sar9_3200hz.v"
)

# Any of these in xsim.log fails the TB (plain, bracketed and SSW "[t] ID FAIL" styles).
FAIL_ERE='^FAIL|^\[FAIL\]|^\[[0-9]+\] [A-Z0-9-]+ FAIL|ERROR:|FATAL'

# ------------------------------- arguments -----------------------------------
OUT=""
GROUP="all"
SELECT=()
while [ $# -gt 0 ]; do
  case "$1" in
    -o) [ $# -ge 2 ] || { echo "ERROR: -o needs a directory" >&2; exit 2; }; OUT="$2"; shift 2 ;;
    -g) [ $# -ge 2 ] || { echo "ERROR: -g needs hier|orphan|all" >&2; exit 2; }; GROUP="$2"; shift 2 ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    -*) echo "ERROR: unknown option $1" >&2; exit 2 ;;
    *) SELECT+=("$1"); shift ;;
  esac
done
case "$GROUP" in hier|orphan|all) ;; *) echo "ERROR: -g must be hier, orphan or all" >&2; exit 2 ;; esac

for want in "${SELECT[@]+"${SELECT[@]}"}"; do
  found=0
  for row in "${TB_TABLE[@]}"; do [ "${row%%|*}" = "$want" ] && found=1; done
  [ $found -eq 1 ] || { echo "ERROR: unknown TB $want" >&2; exit 2; }
done

[ -n "$OUT" ] || OUT="$(dirname "$REPO")/ppg_unit_tb_runs/$(date +%Y%m%d_%H%M%S)"
# Resolve to an absolute path *before* creating anything, so a refused
# in-repo directory is never even created.
case "$OUT" in /*|?:/*|?:\\*) ;; *) OUT="$PWD/$OUT" ;; esac
command -v cygpath >/dev/null 2>&1 && OUT="$(cygpath -u "$OUT")"
OUT="$(realpath -m "$OUT")"
case "$OUT/" in
  "$REPO/"*) echo "ERROR: output dir $OUT is inside the repository; choose a directory outside $REPO" >&2; exit 2 ;;
esac
mkdir -p "$OUT" || exit 2

SUMMARY="$OUT/unit_summary.tsv"
printf 'group\ttb\txvlog\txelab\txsim\tfinish\tfail_lines\tbanner\tverdict\tdur_s\tbanner_line\n' > "$SUMMARY"
echo "repo=$REPO"
echo "out=$OUT"
echo "vivado_bin=$VIVADO_BIN"

n_run=0; n_pass=0; n_fail=0
for row in "${TB_TABLE[@]}"; do
  IFS='|' read -r tb grp tbfile banner deps <<< "$row"
  [ "$GROUP" = "all" ] || [ "$GROUP" = "$grp" ] || continue
  if [ ${#SELECT[@]} -gt 0 ]; then
    hit=0; for want in "${SELECT[@]}"; do [ "$want" = "$tb" ] && hit=1; done
    [ $hit -eq 1 ] || continue
  fi
  n_run=$((n_run + 1))
  wd="$OUT/$tb"
  rm -rf "$wd"; mkdir -p "$wd"
  : > "$wd/filelist.f"
  for d in $deps; do native "$RTL/$d" >> "$wd/filelist.f"; done
  native "$RTL/$tbfile" >> "$wd/filelist.f"
  echo "=== [$grp] $tb ==="
  t0=$(date +%s)
  (
    cd "$wd" || exit 9
    "xvlog$EXE" -f filelist.f -i "$(native "$(dirname "$RTL/$tbfile")")" > xvlog.log 2>&1; echo $? > rc_xvlog
    if [ "$(cat rc_xvlog)" = "0" ]; then
      "xelab$EXE" "$tb" -s "snap_$tb" -timescale 1ns/1ps > xelab.log 2>&1; echo $? > rc_xelab
    fi
    if [ -f rc_xelab ] && [ "$(cat rc_xelab)" = "0" ]; then
      "xsim$EXE" "snap_$tb" -runall -log xsim.log > xsim_stdout.log 2>&1; echo $? > rc_xsim
    fi
  )
  dur=$(( $(date +%s) - t0 ))
  rc_xvlog=$(cat "$wd/rc_xvlog" 2>/dev/null); rc_xvlog=${rc_xvlog:-NA}
  rc_xelab=$(cat "$wd/rc_xelab" 2>/dev/null); rc_xelab=${rc_xelab:-NA}
  rc_xsim=$(cat "$wd/rc_xsim" 2>/dev/null); rc_xsim=${rc_xsim:-NA}
  fin=0; fails=0; have_banner=N; banner_line="-"
  if [ -f "$wd/xsim.log" ]; then
    fin=$(grep -c 'finish called' "$wd/xsim.log" 2>/dev/null); fin=${fin:-0}
    fails=$(grep -cE "$FAIL_ERE" "$wd/xsim.log" 2>/dev/null); fails=${fails:-0}
    banner_line=$(grep -E "$banner" "$wd/xsim.log" 2>/dev/null | tail -n 1)
    [ -n "$banner_line" ] && have_banner=Y || banner_line="-"
  fi
  if [ "$rc_xvlog" = "0" ] && [ "$rc_xelab" = "0" ] && [ "$rc_xsim" = "0" ] \
     && [ "$fin" -ge 1 ] && [ "$fails" -eq 0 ] && [ "$have_banner" = "Y" ]; then
    verdict=PASS; n_pass=$((n_pass + 1))
  else
    verdict=FAIL; n_fail=$((n_fail + 1))
  fi
  banner_line=$(printf '%s' "$banner_line" | tr '\t\r\n' '   ')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$grp" "$tb" "$rc_xvlog" "$rc_xelab" "$rc_xsim" \
    "$fin" "$fails" "$have_banner" "$verdict" "$dur" "$banner_line" >> "$SUMMARY"
  echo "  $verdict xvlog=$rc_xvlog xelab=$rc_xelab xsim=$rc_xsim finish=$fin fail_lines=$fails banner=$have_banner dur=${dur}s"
done

echo "=== DONE: run=$n_run pass=$n_pass fail=$n_fail ==="
echo "summary: $SUMMARY"
[ $n_run -gt 0 ] && [ $n_fail -eq 0 ]
