#!/bin/bash
set -u
cd /mnt/c/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/evidence/compile/tb_ppg_control_top_lifecycle_fault_adc_anomaly
if [ -f run.rc ]; then exit 0; fi
date -u +%Y-%m-%dT%H:%M:%SZ > run.start
timeout 3600 /mnt/c/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/toolchain/icarus11/usr/bin/vvp -M /mnt/c/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl sim.vvp > run.log 2>&1
echo "$?" > run.rc
date -u +%Y-%m-%dT%H:%M:%SZ > run.end
echo tb_ppg_control_top_lifecycle_fault_adc_anomaly run=$(cat run.rc)
