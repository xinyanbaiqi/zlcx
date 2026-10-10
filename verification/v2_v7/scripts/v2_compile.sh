#!/bin/bash
# V2/V7 framework: compile the sweep snapshot once (xvlog + xelab), out of the repository.
#
# usage: v2_compile.sh <source_root> <build_dir> [--no-v7]
#   <source_root>  a tree laid out like the repository (normally a `git -c core.autocrlf=false archive` export)
#   <build_dir>    output directory (xsim.dir, logs, snapshot snap_v2_sweep)
#   --no-v7        do not compile/bind the V7 assertion package
#
# RTL list = rtl/ppg_control_top/xsim_adc_anomaly_filelist.f minus its own testbench line (the
# repository file is read, never modified). The V2 files are appended; the generator header
# tb_ppg_real_raw_generator.vh is found through -i rtl/ppg_control_top.
set -u
SRC=$(cygpath -m "$(cd "$1" && pwd)")
BUILD=$2
V7=1
[ "${3:-}" = "--no-v7" ] && V7=0
export PATH="${VIVADO_BIN:-/c/Xilinx/Vivado/2022.2/bin}:$PATH"
mkdir -p "$BUILD"
cd "$BUILD" || exit 2
FL=v2_filelist.f
: > $FL
while read -r line; do
  line=${line%$'\r'}
  [ -z "$line" ] && continue
  case "$line" in *tb_ppg_control_top_adc_anomaly.v) continue;; esac
  echo "$SRC/rtl/ppg_control_top/$line" >> $FL
done < "$SRC/rtl/ppg_control_top/xsim_adc_anomaly_filelist.f"
for f in adc_model/v2_adc_behavior_model.v monitors/v2_mon_liveness.v monitors/v2_mon_q3_bind.v monitors/v2_mon_void_excl.v \
         monitors/v2_mon_frame_interval.v monitors/v2_mon_recovery.v monitors/v2_mon_identity.v tb/tb_v2_sweep.v; do
  echo "$SRC/verification/v2_v7/$f" >> $FL
done
t0=$(date +%s)
xvlog.bat -f $FL -i "$SRC/rtl/ppg_control_top" > xvlog.log 2>&1; rc_v=$?
TOPS="tb_v2_sweep"
rc_sv=0
if [ $V7 -eq 1 ] && [ -f "$SRC/verification/v2_v7/assertions/v7_assertions.sv" ]; then
  xvlog.bat -sv "$SRC/verification/v2_v7/assertions/v7_assertions.sv" > xvlog_sv.log 2>&1; rc_sv=$?
fi
rc_e=1
if [ $rc_v -eq 0 ] && [ $rc_sv -eq 0 ]; then
  xelab.bat $TOPS -s snap_v2_sweep -timescale 1ns/1ps -debug off > xelab.log 2>&1; rc_e=$?
fi
t1=$(date +%s)
echo "V2COMPILE xvlog=$rc_v xvlog_sv=$rc_sv xelab=$rc_e seconds=$((t1-t0)) v7=$V7 build=$BUILD"
grep -E "^ERROR|^CRITICAL" xvlog.log xvlog_sv.log xelab.log 2>/dev/null | head -20
[ $rc_e -eq 0 ]
