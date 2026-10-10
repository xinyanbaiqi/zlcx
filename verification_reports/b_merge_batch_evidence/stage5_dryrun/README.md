# Stage-5 tool dry runs (development only; nothing written into the matrix)

- `tools/b_merge_tools/manifest_digest.py` (F-045, §12.4a digests):
  - `manifest_digest_check_7a8eabf.txt`: baseline -> 26 rows, 3 match (C04, C05, C21), 23 mismatch; this reproduces the F-045 finding.
  - `manifest_digest_check_3f4673d.txt`: the snapshot named in the ABCD report -> also 3 match / 23 mismatch.
  - `manifest_digest_check_HEAD.txt`: branch at development time -> 0 match (expected; the batch changed contracts and matrix; formal regeneration is the last step of stage 5).
  - Negative control on a `7a8eabf` export: one byte changed in C04 -> exactly one new mismatch (C04), 2 match / 24 mismatch (`manifest_digest_negctl_*`).
  - `--write` round trip on the same export: afterwards 26/26 match (self-normalized M01).
- `tools/cross_reference_tools/reconcile_acceptance_ids.py` (path-fixed, logic unchanged):
  - dry run on HEAD and on a `7a8eabf` export: 341 IDs, identical counts
    {A 267, B 22, B2 35, D 1, E_STALE 16}.
  - `reconcile_dryrun_HEAD_b2_classification.md`: the 35 B2 split into 22 pseudo IDs from TB header revision notes
    (known false positives) and 13 real RTL tags without alias rows (to be added in stage 3).
  - The committed `reconciliation_report.*` files are not refreshed yet (§13 refresh is the last step of stage 5).
