#!/bin/bash
# =============================================================================
# Symbol-anchor gate (B merge batch brief section 3.2, BMI-153).
#
# Runs tools/b_merge_tools/anchor_check.py over the closure matrix, the alias table
# and every contract of the repository that holds this script.  It is called at the
# start of tools/run_unit_tb_regression.sh, so a broken anchor fails the whole
# regression round before any simulation starts; it can also be run on its own.
#
# Usage:   tools/b_merge_tools/run_anchor_gate.sh [anchor_check.py arguments ...]
# Env:     PYTHON  interpreter to use (default: python3, then python). Python >= 3.9
#                  reads port/signal names through the erie-verilog-generator formatter
#                  AST; an older interpreter falls back to the text search built into
#                  anchor_check.py (same pass/fail rules).
# Exit:    0 when anchor_check.py reports no error, 1 otherwise, 2 when no Python.
# =============================================================================
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PY="${PYTHON:-}"
if [ -z "$PY" ]; then
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then PY=python3
  elif command -v python >/dev/null 2>&1; then PY=python
  else echo "ANCHOR GATE ERROR: no python interpreter found (set PYTHON)" >&2; exit 2; fi
fi

echo "ANCHOR GATE: $("$PY" --version 2>&1) $HERE/anchor_check.py $*"
PYTHONDONTWRITEBYTECODE=1 PYTHONIOENCODING=utf-8 "$PY" -I "$HERE/anchor_check.py" "$@"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "ANCHOR GATE FAILED (anchor_check.py exit $rc)"
  exit 1
fi
echo "ANCHOR GATE PASSED"
exit 0
