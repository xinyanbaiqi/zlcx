# Stage 5 final: §13 refresh and §12.4a digests (2026-10-09)

- §13.1 refreshed from `tools/cross_reference_tools/reconcile_acceptance_ids.py` (commit `f5f6e3f`): 326 IDs, A 287, B 22,
  B2 0, C 0, D 1, D2 0, E 16. 22 non-ID texts after `@satisfies:` (TB revision-record prose) are excluded and listed
  at the end of `tools/cross_reference_tools/reconciliation_report.md`.
- §12.4a: `tools/b_merge_tools/manifest_digest.py --write` after every other contract, matrix and alias-table change
  of the batch (commit `5d294db`). `manifest_check_HEAD.txt`: `--rev HEAD`, 26/26 MATCH, exit 0. The script's negative
  control is in `../stage5_dryrun/`.
- `anchor_check_HEAD.txt`: anchor gate on the same HEAD, 0 errors.
