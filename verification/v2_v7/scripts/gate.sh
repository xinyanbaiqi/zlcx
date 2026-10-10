#!/bin/bash
# V2/V7 helper: align inline comments, then run the erie-verilog-generator deliverable gate on one file.
# usage: gate.sh <file> [--include-testbench]   ; writes <outdir>/<stem>.gate.{json,md}, prints summary
set -u
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
F=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=${GATE_OUT:-$REPO/verification/v2_v7/gate_results}
mkdir -p "$OUT"
STEM=$(basename "$1"); STEM=${STEM%.*}
python "$REPO/verification/v2_v7/scripts/align_inline_comments.py" "$F" > /dev/null
cd "$REPO/.claude/skills/erie-verilog-generator"
python -m scripts.python.validation.verilog_generated_deliverable_gate "$(cygpath -w "$F")" ${2:-} --json "$(cygpath -w "$OUT/$STEM.gate.json")" --markdown "$(cygpath -w "$OUT/$STEM.gate.md")" > /dev/null 2>&1
rc=$?
echo "GATE $STEM rc=$rc $(grep -m1 '^Summary' "$OUT/$STEM.gate.md")"
grep '^| \(error\|warning\)' "$OUT/$STEM.gate.md" | head -${GATE_SHOW:-30}
exit $rc
