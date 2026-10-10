# Round-2 negative control (2026-10-09)

Copies of the round-2 result with 4 injected faults:

| # | Line | Fault | anchor_verify --previous | anchor_check |
|---|---|---|---|---|
| 1 | matrix 1372 | a round-2 forward conversion put back to its old line anchor (`ppg_control_top.v:99`) | reported | reported (line-anchor) |
| 2 | matrix 3641 | a reverted "> " block anchor left converted (`C03 §8` instead of `C03:249`) | reported | reported indirectly: the edited line no longer matches its allowlist SHA-1, so the other old anchors on it (C05:94, C10:257, C20:781, C22:679) are reported |
| 3 | matrix 1471 (line edited after round 1) | rewrite left with the round-1 wrong symbol | reported (by undoing the delta) | not reported: the wrong symbol exists in the file |
| 4 | alias 279 | non-anchor text changed on a round-2 line | reported | not in scope |

anchor_verify:
```
MISMATCH PPG_CONTRACT_CLOSURE_MATRIX.md:1372
MISMATCH PPG_CONTRACT_CLOSURE_MATRIX.md:1471 (edited after round 1; undoing the delta does not give the --before text)
MISMATCH PPG_CONTRACT_CLOSURE_MATRIX.md:3641
MISMATCH PPG_ALIAS_MAPPING_TABLE.md:279
delta pairs 1471, changed lines 338, lines edited after round 1 (checked by undoing the delta) 6, mismatches 4
```

anchor_check:
```
ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:1372 line-anchor ppg_control_top.v:99
ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:3641 line-anchor C05:94
ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:3641 line-anchor C10:257
ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:3641 line-anchor C20:781
ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:3641 line-anchor C22:679
stats {"symbol_anchors": 6797, "satisfies_anchors": 111, "label_anchors": 176, "section_refs": 2768, "old_anchor_history": 12}; external refs 27; errors 5; file index git (1019 files)
```

First version of the verifier only listed lines edited after round 1 for review, so fault 3 was missed; the edited-line path now undoes the delta and compares with the snapshot text, and the run above is with that version.
