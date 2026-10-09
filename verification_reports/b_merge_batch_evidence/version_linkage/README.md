# Version linkage evidence (B merge batch, commit 8b2b259)

- Script that made the edit: `tools/b_merge_tools/verlink.py` (strict rule: the
  replaced token must be the first version token after its own contract file name;
  dated narrative lines 956, 1912, 2151-2153 of the pre-linkage matrix were excluded).
- Independent check: `tools/b_merge_tools/verlink_check.py`. Reproduce with
  `python tools/b_merge_tools/verlink_check.py . 8b2b259~1 8b2b259 contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:4`
  -> `good 207 bad 0` (`verlink_check_8b2b259.txt`). Matrix line 4 is the change-record
  line written in the same commit and is listed as ALLOWED.
- Negative control (2026-10-09, working tree): after manually changing the C10
  citation in C08 line 62 from V2.5 to V2.7, the check reported exactly that line
  (`BAD ... 62 V2.4 -> V2.7`, `good 206 bad 1`); restoring the file gave `good 207 bad 0`.
- `verlink_dryrun_strict_before_apply.txt`: the 197-candidate dry run with the strict
  rule (before the C19 old-version fix; final applied count 207 after correcting C19's
  cited version from V2.4 to V2.5 and re-running until stable).
- `verlink_dryrun_loose_rejected.txt`: the first, loose dry run (208 candidates). Its
  six extra hits were wrong (a later binding's version token after the first file name);
  that attempt was reverted with `git checkout -- contracts` before any commit.
