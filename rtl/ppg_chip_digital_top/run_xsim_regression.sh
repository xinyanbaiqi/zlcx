#!/bin/bash
# Tape-out-readiness Stage 1: runs tb_ppg_chip_digital_top.v through xvlog+xelab+xsim
# (Vivado 2022.2), mirroring the exact tool-invocation pattern already established by
# ppg_control_top/run_xsim_regression.sh (Phase 6 regression driver). This is the first
# trusted-tool (xsim) confirmation for ppg_chip_digital_top -- it has so far only ever
# been run through iverilog.
set -u
export PATH="${VIVADO_BIN:-/c/Xilinx/Vivado/2022.2/bin}:$PATH"
cd "$(dirname "$0")"

OUTDIR="xsim_regression_$(date +%Y%m%d)"
mkdir -p "$OUTDIR"
SUMMARY="$OUTDIR/summary.tsv"
echo -e "tb_name\tfilelist\tsnapshot\txvlog\txelab\txsim\tpass_count\tfail_count\tfinished\tduration_s\tlog_dir" > "$SUMMARY"

tb="tb_ppg_chip_digital_top"
fl="xsim_chip_digital_top_filelist.f"
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

echo "=== DONE ==="
cat "$SUMMARY"
