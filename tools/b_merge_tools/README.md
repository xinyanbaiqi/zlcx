# B merge batch tools

Scripts written for `verification_reports/B_MERGE_BATCH_BRIEF_20261009.md`.

| Script | Purpose |
| --- | --- |
| `verlink.py` | Dependency-version linkage across contracts and matrix §12.4/12.4a/12.4b (dry run without `--apply`). |
| `verlink_check.py` | Independent pairing check of a linkage edit (`<repo> OLD NEW [ALLOW_FILE:LINE...]`). Evidence: `verification_reports/b_merge_batch_evidence/version_linkage/`. |
| `strip_compare.py` | Proves Verilog edits are comment-only (RTL) or comment-and-string-only (`--strings`, TB label renames) against a git revision. |
| `anchor_check.py` | Symbol-anchor checker (file exists, name / `@satisfies` present, contract section exists and is unique; old line anchors are errors in matrix/alias unless history). Runs with Python >= 3.9 (formatter AST from the erie-verilog-generator skill); `--no-ast` falls back to text search. Under development in stage 4. |
