#!/bin/bash
# V2/V7 framework: resumable parallel batch over one or more grid TSV files.
#
# usage: v2_batch.sh <build_dir> <run_dir> <jobs> <grid.tsv> [<grid.tsv> ...]
#   <build_dir>  snapshot built by v2_compile.sh
#   <run_dir>    results: <run_dir>/points/<point_id>/xsim.log (+args.txt, start.txt, end.txt), <run_dir>/batch.log
#   <jobs>       parallel xsim processes (default plan: 10 of the 12 cores)
# Resumable: a point whose xsim.log already holds its V2POINT line is skipped, so the batch can be
# restarted after the launching process was killed (background simulations die with their parent).
# Columns: point_id mode event slot frame tick sf lt param extra   (extra = ';'-separated plusargs)
set -u
B=$1; RUN=$2; JOBS=${3:-10}; shift 3
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$RUN/points"
LOG=$RUN/batch.log
echo "BATCH_START $(date '+%F %T') epoch=$(date +%s) jobs=$JOBS grids=$*" >> "$LOG"
n_run=0; n_skip=0
run_one() {   # point_id then plusargs
  local id=$1; shift
  bash "$HERE/v2_run_point.sh" "$B" "$RUN/points/$id" "V2_POINT=$id" "$@" > /dev/null 2>&1
  local line; line=$(grep -m1 "^V2POINT" "$RUN/points/$id/xsim.log" 2>/dev/null)
  echo "POINT_DONE $(date '+%T') $id ${line:+ok}${line:-NO_V2POINT}" >> "$LOG"
}
for g in "$@"; do
  while IFS=$'\t' read -r id mode ev slot frame tick sf lt param extra; do
    [ "$id" = "point_id" ] && continue
    [ -z "$id" ] && continue
    extra=${extra%$'\r'}
    if grep -q "^V2POINT" "$RUN/points/$id/xsim.log" 2>/dev/null; then n_skip=$((n_skip+1)); continue; fi
    args=(V2_MODE=$mode V2_EVENT=$ev V2_SLOT=$slot V2_FRAME=$frame V2_TICK=$tick V2_PARAM=$param)
    [ "$sf" != "-1" ] && args+=(V2_SF=$sf V2_LT=$lt)
    if [ -n "$extra" ]; then IFS=';' read -r -a ex <<< "$extra"; args+=("${ex[@]}"); fi
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
    run_one "$id" "${args[@]}" &
    n_run=$((n_run+1))
  done < "$g"
done
wait
echo "BATCH_END $(date '+%F %T') epoch=$(date +%s) launched=$n_run skipped=$n_skip" >> "$LOG"
echo "launched=$n_run skipped=$n_skip"
