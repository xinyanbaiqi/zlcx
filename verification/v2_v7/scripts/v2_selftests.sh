#!/bin/bash
# V2/V7 framework: run the ADC-model and monitor self-check testbenches (and, if present, the V7 assertion self-check).
# usage: v2_selftests.sh <source_root> <out_dir>
# Prints one SELFTEST line per bench; exit status 0 only if every bench printed its *_PASS closing line.
set -u
SRC=$(cygpath -m "$(cd "$1" && pwd)")
OUT=$2
export PATH="${VIVADO_BIN:-/c/Xilinx/Vivado/2022.2/bin}:$PATH"
V=$SRC/verification/v2_v7
rc_all=0
run_bench() {   # name top pass_token sv(0/1) files...
  local name=$1 top=$2 tok=$3 sv=$4; shift 4
  local d=$OUT/$name; rm -rf "$d"; mkdir -p "$d"; cd "$d" || return 1
  if [ "$sv" = "1" ]; then xvlog.bat -sv "$@" > xvlog.log 2>&1; else xvlog.bat "$@" > xvlog.log 2>&1; fi
  local rv=$?
  xelab.bat "$top" -s snap_$name -timescale 1ns/1ps > xelab.log 2>&1; local re=$?
  xsim.bat snap_$name -runall -log xsim.log > /dev/null 2>&1
  local line; line=$(grep -m1 -E "${tok}_(PASS|FAIL)" xsim.log 2>/dev/null)
  echo "SELFTEST $name xvlog=$rv xelab=$re ${line:-NO_VERDICT}"
  case "$line" in *_PASS*) ;; *) rc_all=1;; esac
}
run_bench adc_model tb_v2_adc_behavior_model ADCM_SELFTEST 0 $V/adc_model/v2_adc_behavior_model.v $V/tb/tb_v2_adc_behavior_model.v
run_bench monitors tb_v2_monitor_selftest MONITOR_SELFTEST 0 $V/monitors/v2_mon_liveness.v $V/monitors/v2_mon_q3_bind.v $V/monitors/v2_mon_void_excl.v \
  $V/monitors/v2_mon_frame_interval.v $V/monitors/v2_mon_recovery.v $V/monitors/v2_mon_identity.v $V/tb/tb_v2_monitor_selftest.v
if [ -f "$V/tb/tb_v7_assertion_selftest.sv" ]; then
  run_bench assertions tb_v7_assertion_selftest V7_SELFTEST 1 $V/assertions/v7_checkers.sv $V/tb/tb_v7_assertion_selftest.sv
fi
exit $rc_all
