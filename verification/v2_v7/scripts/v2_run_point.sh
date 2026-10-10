#!/bin/bash
# V2/V7 framework: run ONE sweep point on an already elaborated snapshot.
#
# usage: v2_run_point.sh <build_dir> <point_dir> <plusarg> [<plusarg> ...]
#   <build_dir>  directory produced by v2_compile.sh (contains xsim.dir/snap_v2_sweep)
#   <point_dir>  private run directory; the snapshot is copied in so that points can run in parallel
#   <plusarg>    e.g. V2_MODE=DUAL9 V2_EVENT=STOP V2_TICK=283
# Plusargs are passed through an xsim -f options file because xsim.bat splits "A=B" on '='.
# Writes <point_dir>/xsim.log, args.txt, start.txt, end.txt and prints the V2POINT line.
set -u
B=$1; D=$2; shift 2
export PATH="${VIVADO_BIN:-/c/Xilinx/Vivado/2022.2/bin}:$PATH"
rm -rf "$D"; mkdir -p "$D/xsim.dir"
cp -r "$B/xsim.dir/snap_v2_sweep" "$D/xsim.dir/"
: > "$D/args.txt"
for a in "$@"; do echo "-testplusarg $a" >> "$D/args.txt"; done
date +%s > "$D/start.txt"
cd "$D" || exit 2
xsim.bat snap_v2_sweep -runall -log xsim.log -f args.txt > stdout.log 2>&1
rc=$?
date +%s > "$D/end.txt"
rm -rf "$D/xsim.dir"
grep -m1 "^V2POINT" xsim.log || echo "V2POINT missing rc=$rc dir=$D"
exit $rc
