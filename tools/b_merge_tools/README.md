# B merge batch tools

Scripts written for `verification_reports/B_MERGE_BATCH_BRIEF_20261009.md`.

| Script | Purpose |
| --- | --- |
| `verlink.py` | Dependency-version linkage across contracts and matrix §12.4/12.4a/12.4b (dry run without `--apply`). |
| `verlink_check.py` | Independent pairing check of a linkage edit (`<repo> OLD NEW [ALLOW_FILE:LINE...]`). Evidence: `verification_reports/b_merge_batch_evidence/version_linkage/`. |
| `strip_compare.py` | Proves Verilog edits are comment-only (RTL) or comment-and-string-only (`--strings`, TB label renames) against a git revision. |
| `anchor_check.py` | Symbol-anchor checker (file exists, name / `@satisfies` present, contract section exists and is unique; old line anchors are errors in matrix/alias unless history). Runs with Python >= 3.9 (formatter AST from the erie-verilog-generator skill); `--no-ast` falls back to text search. Under development in stage 4. |
| `regression_evidence.py` | `export <run_root> <out_dir>`: per-TB sorted PASS lines (brief §6.8 rule) and `$finish` lines (paths reduced to basenames) plus `index.tsv`; `compare <baseline_dir> <final_dir>`: lists every differing PASS line, exits 1 when a TB is missing or a `$finish` line differs. Run layout: `verification_reports/b_merge_batch_evidence/REGRESSION_RUN_REQUEST.md`. |
| `manifest_digest.py` | Check (`--rev REV` or working tree) or regenerate (`--write`) the matrix §12.4a SHA-256 manifest; M01 is self-normalized. Evidence: `verification_reports/b_merge_batch_evidence/stage5_dryrun/`. |
