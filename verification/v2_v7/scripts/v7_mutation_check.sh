#!/bin/bash
# V7 negative control on real RTL: build mutated RTL copies OUTSIDE the repository and show that the
# targeted assertion fires on the mutant and not on the unmodified design (same sweep point).
#
# usage: v7_mutation_check.sh <repo_root> <work_dir> [jobs]
# Each mutation is ONE sed edit on one RTL line of a `git archive` export; the diff of every mutant is
# written to <work_dir>/<name>/mutation.diff (copied into the report; mutants are never committed).
set -u
REPO=$(cd "$1" && pwd); W=$2; JOBS=${3:-6}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$W"
rm -rf "$W/base"; mkdir -p "$W/base"
git -C "$REPO" -c core.autocrlf=false archive HEAD | tar -x -C "$W/base"

SSW=rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v
RC=rtl/ppg_adc_s1_redundancy_corrector/ppg_adc_s1_redundancy_corrector.v
AMI=rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v

# name # file # sed expression # target property # sweep-point plusargs   ('#'-separated: the sed expressions contain '|')
MUTS=(
"MUT_P1_SSW_IGNORES_VOID#$SSW#s/assign flag_owner_release = (i_adc_transaction_complete_event || i_adc_transaction_lost_event) \&\&/assign flag_owner_release = (i_adc_transaction_complete_event) \&\&/#P1b_INFLIGHT_THREE_WAY#V2_MODE=DUAL9 V2_EVENT=LOST V2_TICK=100"
"MUT_P3_RC_NO_DROP_ARM#$RC#/end else if(i_transaction_abandon == 1'b1)begin/{n;s/flag_capture_drop_armed <= 1'b1;/flag_capture_drop_armed <= 1'b0;/}#P3_RC_CAPTURE_HAS_CONTEXT#V2_MODE=DUAL9 V2_EVENT=LOST V2_TICK=100"
"MUT_P4_SSW_START_KEEPS_RED_CTX#$SSW#s/flag_red_context_valid <= 1'b0;\(\s*\)\/\/ 开机重启时丢弃旧运行遗留的可见光接管/flag_red_context_valid <= flag_red_context_valid;\1\/\/ MUTANT/#P4_START_NO_RESIDUAL_CONTEXT#V2_MODE=DUAL9 V2_EVENT=START_DELAY V2_TICK=1 V2_PARAM=0"
"MUT_P5_LANE06_IGNORES_ABORT#$AMI#/flag_owner_lost_fault_hold <= 1'b0; \/\/ 复位解除连续丢失阻断/{n;s/i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1/i_start_ack_event == 1'b1/}#P5_L5_CLEAR_NEVER_EFFECTIVE#V2_MODE=DUAL9 V2_EVENT=LOST V2_SLOT=RED V2_TICK=100 V2_PARAM=255"
)
echo "MUTATION_START $(date '+%F %T')" > "$W/mutation.log"
for m in "${MUTS[@]}"; do
  IFS='#' read -r name file expr prop args <<< "$m"
  d=$W/$name; rm -rf "$d"; mkdir -p "$d"; cp -r "$W/base" "$d/src"
  sed -i "$expr" "$d/src/$file"
  (cd "$d" && diff -u "../base/$file" "src/$file" > mutation.diff)
  nlines=$(grep -c '^[-+][^-+]' "$d/mutation.diff")
  echo "MUTANT $name file=$file changed_lines=$nlines property=$prop" | tee -a "$W/mutation.log"
  [ "$nlines" -eq 2 ] || { echo "MUTANT $name sed did not change exactly one line" | tee -a "$W/mutation.log"; continue; }
  bash "$HERE/v2_compile.sh" "$d/src" "$d/build" > "$d/compile.log" 2>&1 || { echo "MUTANT $name compile failed" | tee -a "$W/mutation.log"; continue; }
done
# the unmodified design, same points
bash "$HERE/v2_compile.sh" "$W/base" "$W/base_build" > "$W/base_compile.log" 2>&1
for m in "${MUTS[@]}"; do
  IFS='#' read -r name file expr prop args <<< "$m"
  read -r -a a <<< "$args"
  ( bash "$HERE/v2_run_point.sh" "$W/$name/build" "$W/$name/run" V2_POINT=$name "${a[@]}" > /dev/null 2>&1
    bash "$HERE/v2_run_point.sh" "$W/base_build" "$W/$name/run_base" V2_POINT=${name}_BASE "${a[@]}" > /dev/null 2>&1 ) &
  while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
done
wait
for m in "${MUTS[@]}"; do
  IFS='#' read -r name file expr prop args <<< "$m"
  mut=$(grep -m1 "^V7SUM $prop " "$W/$name/run/xsim.log" 2>/dev/null)
  base=$(grep -m1 "^V7SUM $prop " "$W/$name/run_base/xsim.log" 2>/dev/null)
  verdict=KILLED
  case "$mut" in *" FAIL "*) ;; *) verdict=SURVIVED;; esac
  case "$base" in *" PASS "*) ;; *) verdict="$verdict(BASE_NOT_PASS)";; esac
  echo "MUTRESULT $name $verdict | mutant: ${mut:-none} | base: ${base:-none}" | tee -a "$W/mutation.log"
  grep "^V7SUM" "$W/$name/run/xsim.log" | grep " FAIL " | sed "s/^/  also_failing_on_mutant: /" | tee -a "$W/mutation.log"
done
echo "MUTATION_END $(date '+%F %T')" >> "$W/mutation.log"
