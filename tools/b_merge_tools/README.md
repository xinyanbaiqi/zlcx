# B merge batch tools

Scripts written for `verification_reports/B_MERGE_BATCH_BRIEF_20261009.md`.

| Script | Purpose |
| --- | --- |
| `verlink.py` | Dependency-version linkage across contracts and matrix §12.4/12.4a/12.4b (dry run without `--apply`). |
| `verlink_check.py` | Independent pairing check of a linkage edit (`<repo> OLD NEW [ALLOW_FILE:LINE...]`). Evidence: `verification_reports/b_merge_batch_evidence/version_linkage/`. |
| `strip_compare.py` | Proves Verilog edits are comment-only (RTL) or comment-and-string-only (`--strings`, TB label renames) against a git revision; whitespace-only lines are ignored. |
| `gate_compare.py` | Compares two deliverable-gate JSON reports (baseline vs branch) per file/rule and per message with line numbers removed, for files that are not strict deliverables at the baseline (no new finding allowed). Evidence: `verification_reports/b_merge_batch_evidence/tb_rename_proof/`. |
| `anchor_check.py` | Symbol-anchor checker (file exists, name / `@satisfies` present, contract section exists and is unique; old line anchors are errors in matrix/alias unless history). Runs with Python >= 3.9 (formatter AST from the erie-verilog-generator skill); `--no-ast` falls back to text search. Lines kept on purpose are listed in `anchor_history_allowlist.json`. Gate: `run_anchor_gate.sh`. |
| `anchor_inventory.py` | Lists every old line-number anchor in the matrix and the alias table, with its git-blame written-at commit, kind, cell symbols and position. |
| `anchor_resolve.py` | Resolves each inventoried anchor by reading the referenced file at the written-at commit: symbol / `@satisfies` / TB label / contract section; strikethrough and dated narrative are classified as history. |
| `anchor_manual_seed.py` | Writes `anchor_manual_decisions.tsv`, the reviewed hand decisions (with reasons) for anchors the resolver cannot settle. |
| `anchor_mapping.py` | Merges resolver output and the manual decisions into the complete old -> new table (`verification_reports/b_merge_batch_evidence/anchor_conversion/`). Writes nothing into the matrix or the alias table. |
| `anchor_apply.py` | Writes the old -> new table into the matrix and the alias table (base text aligned to the working tree, old anchor found by occurrence index, surrounding backticks absorbed) and regenerates `anchor_history_allowlist.json`. |
| `anchor_verify.py` | Independent re-check of a conversion against the pre-conversion snapshot commit with a different placement rule (left-to-right scan); every old/new pair and the text between pairs must match. `--after-dir` for negative controls. |
| `run_anchor_gate.sh` | Symbol-anchor gate wrapper (picks python3/python); called first by `tools/run_unit_tb_regression.sh`, exit 1 stops the round. Evidence: `verification_reports/b_merge_batch_evidence/anchor_gate_demo/`. |
| `regression_evidence.py` | `export <run_root> <out_dir>`: per-TB sorted PASS lines (brief §6.8 rule) and `$finish` lines (paths reduced to basenames) plus `index.tsv`; `compare <baseline_dir> <final_dir>`: lists every differing PASS line, exits 1 when a TB is missing or a `$finish` line differs. Run layout: `verification_reports/b_merge_batch_evidence/REGRESSION_RUN_REQUEST.md`. |
| `manifest_digest.py` | Check (`--rev REV` or working tree) or regenerate (`--write`) the matrix §12.4a SHA-256 manifest; M01 is self-normalized. Evidence: `verification_reports/b_merge_batch_evidence/stage5_dryrun/`. |
