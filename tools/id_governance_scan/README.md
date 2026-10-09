# ID governance scanner (extracted)

These scripts are extracted verbatim (by ````python` fence) from appendix A of
`verification_reports/ID_GOVERNANCE_AUDIT_20261005.md` for the B merge batch
(`verification_reports/B_MERGE_BATCH_ITEMS.md` BMI-147). No logic was changed.
`decisions.py` is the audit's manual verdict data, not an automatic derivation.

Typical re-scan gate (all outputs outside the repository):

```bash
git -c core.autocrlf=false archive 2a90a69 | tar -x -C <dir>/src_2a90a69
git -c core.autocrlf=false archive <HEAD>  | tar -x -C <dir>/src_head
python -I scan_contract_ids.py <dir>/src_head contract_ids.json
python -I scan_tb_labels.py    <dir>/src_2a90a69 tb_sites_base.json
python -I scan_tb_labels.py    <dir>/src_head    tb_sites_head.json
python -I rescan_diff.py tb_sites_base.json tb_sites_head.json contract_ids.json
```

Every `B?`/`D` line must be re-read by hand against the contract row of the same
number. Results of the 2026-10-09 run on `7a8eabf` (37 reports) and its negative
control (2 injected changes -> exactly 2 extra reports) are kept in
`verification_reports/b_merge_batch_evidence/id_rescan/`.
