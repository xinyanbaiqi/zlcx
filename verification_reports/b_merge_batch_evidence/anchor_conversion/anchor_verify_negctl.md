# Negative controls for the stage-4 conversion checks (2026-10-09)

Copies of the converted matrix and alias table (HEAD after anchor_apply.py) with 4 injected faults:

| # | Line | Fault | anchor_verify.py | anchor_check.py |
|---|---|---|---|---|
| 1 | matrix 1732 | symbol renamed inside a converted anchor (`ppg_amb_recheck_scheduler.v` `i_amb_enable` -> `i_amb_enablX`) | reported | reported (name-missing) |
| 2 | matrix 1708 | non-anchor word on a converted line (Consumer -> Consumr) | reported | not in scope |
| 3 | matrix 8 | unconverted heading line changed (appended ' x') | reported | not in scope |
| 4 | alias 311 | converted anchor reverted to the old line anchor `tb_ppg_peak_valley_window_detector.v:534` | reported | reported (line-anchor) |

anchor_verify.py --before 3b6df78 --after-dir <copies>:
```
MISMATCH PPG_CONTRACT_CLOSURE_MATRIX.md:8 (0 pairs)
MISMATCH PPG_CONTRACT_CLOSURE_MATRIX.md:1708 (4 pairs)
MISMATCH PPG_CONTRACT_CLOSURE_MATRIX.md:1732 (6 pairs)
MISMATCH PPG_ALIAS_MAPPING_TABLE.md:311 (3 pairs)
pairs checked 7811, changed lines 2386, mismatches 4
```

anchor_check.py <copies>:
```
ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:1732 name-missing ppg_amb_recheck_scheduler.v i_amb_enablX
ERROR PPG_ALIAS_MAPPING_TABLE.md:311 line-anchor tb_ppg_peak_valley_window_detector.v:534
stats {"symbol_anchors": 5313, "satisfies_anchors": 87, "label_anchors": 144, "section_refs": 2760, "old_anchor_history": 1113}; external refs 27; errors 2
```

Both tools report every injected fault in their scope and nothing else. On the real files: anchor_verify 0 mismatches (`anchor_verify.txt`), anchor_check 0 errors (`anchor_check_head.txt`).

First attempt note: the first injection for #1 replaced the first `i_amb_enable` on the line, which was the plain port-name column, not the anchor; anchor_check correctly did not report it (anchor_verify did). The injection was moved inside the anchor and both runs repeated.
