#!/bin/bash
# run_ctrl_tb.sh <tag> <tb_short> [mut_file rel-to-rtl] [old] [new]
# copies the repo working-tree rtl/ into phase2/runs/<tag>/rtl (optionally applying one textual mutation), runs one 19-TB in xsim
set -u
TAG=$1; SH=$2
P=/d/PPG/verilog/ppg_regression_runs/abcd_20261004/phase2
W=$P/runs/$TAG; rm -rf $W; mkdir -p $W
cp -r ${SRC:-/d/PPG/verilog/ppg_github_release/rtl} $W/rtl
find $W/rtl -name 'xsim.dir' -prune -exec rm -rf {} + 2>/dev/null
if [ $# -ge 5 ]; then
  python - "$W/rtl/$3" "$4" "$5" <<'PY'
import sys
p,o,n=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(o)==1, ('anchor',s.count(o))
open(p,'w',encoding='utf-8',newline='\n').write(s.replace(o,n))
PY
fi
export PATH="/c/Xilinx/Vivado/2022.2/bin:$PATH"
cd $W/rtl/ppg_chip_digital_top
TB=$(grep -o '^module [a-z_0-9]*' $(sed -n '$p' xsim_chip_digital_top_filelist.f) | head -1 | awk '{print $2}')
xvlog.bat -f xsim_chip_digital_top_filelist.f -i . > $W/xvlog.log 2>&1 || { echo "$TAG XVLOG_FAIL"; exit 1; }
xelab.bat $TB -s snap -timescale 1ns/1ps > $W/xelab.log 2>&1 || { echo "$TAG XELAB_FAIL"; exit 1; }
xsim.bat snap -R > $W/xsim.log 2>&1
echo "$TAG rc=$? PASS=$(grep -c -E '^(PASS|[PASS]|.*PASS)' $W/xsim.log) FAILLINES=$(grep -c -E '^FAIL |ERROR:|FATAL|status=FAIL' $W/xsim.log) finish=$(grep -c 'finish called' $W/xsim.log)"
