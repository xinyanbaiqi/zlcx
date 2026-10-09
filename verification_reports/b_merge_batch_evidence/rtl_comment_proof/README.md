# RTL comment-change proofs (B merge batch, brief §0.3)

Each RTL file changed by this batch gets: deliverable gate on the baseline (`7a8eabf`) and on
the branch (no new findings allowed), the skill's comment-only verifier
(`verify_verilog_comment_only.py baseline branch --require-comment-delta`), and
`tools/b_merge_tools/strip_compare.py 7a8eabf <file>` (comments removed -> byte-identical).

| File | Change | Gate baseline -> branch | Comment-only | strip_compare |
| --- | --- | --- | --- | --- |
| `rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v` | §3.9 (F-9): the three named comments (`flag_stage_frame_complete` declaration, `o_calibration_frame_start` assign, next-state `always` banner) rewritten to the F-9 semantics; nothing else | 0/0 -> 0/0 | successful | IDENTICAL |

Negative control for `strip_compare.py` (2026-10-09): flipping `1'b1` to `1'b0` in the
`flag_stage_frame_complete` set branch was reported DIFFERENT; restoring gave IDENTICAL.
