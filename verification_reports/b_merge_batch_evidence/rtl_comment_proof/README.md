# RTL comment-change proofs (B merge batch, brief §0.3)

Each RTL file changed by this batch gets: deliverable gate on the baseline (`7a8eabf`) and on
the branch (no new findings allowed), the skill's comment-only verifier
(`verify_verilog_comment_only.py baseline branch --require-comment-delta`), and
`tools/b_merge_tools/strip_compare.py 7a8eabf <file>` (comments removed -> byte-identical).

| File | Change | Gate baseline -> branch | Comment-only | strip_compare |
| --- | --- | --- | --- | --- |
| `rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v` | §3.9 (F-9): the three named comments (`flag_stage_frame_complete` declaration, `o_calibration_frame_start` assign, next-state `always` banner) rewritten to the F-9 semantics; nothing else | 0/0 -> 0/0 | successful | IDENTICAL |
| `rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v` | BMI-160 `@satisfies` appended to 8 existing comments: AMI-39/LFA-04 (`adc_transaction_lost_event_o` publish), AMI-24 (`owner_lost_sticky_o` clear; lane 06 `flag_owner_lost_fault_hold` two clears; lanes 01/02/03 L-5 clears), AMI-40 (`flag_adc_transaction_inflight` void release) | 11/1 -> 11/1, no new finding | successful | IDENTICAL |
| `rtl/ppg_adc_s1_redundancy_corrector/ppg_adc_s1_redundancy_corrector.v` | BMI-160: AMI-40 on `flag_capture_drop` (C10 §7.1a notifies the S1 corrector) | 3/0 -> 3/0, no new finding | successful | IDENTICAL |
| `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v` | BMI-160: FSC-19 on `flag_idle_idac_safe_boundary`; FSC-54 on the `flag_owner_lost_match` branch (owner release, current frame failed) | 4/0 -> 4/0, no new finding | successful | IDENTICAL |
| `rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v` | BMI-160: SSW-42 on `flag_owner_release`; SSW-18 on the `calibration_timeout_sticky_o` set; SSW-53 (L-6, C09 V1.11 new row) on `flag_start_restore` | 10/0 -> 10/0, no new finding | successful | IDENTICAL |
| `rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v` | BMI-160: P09 on the cause-to-summary-bit mapping (C24 V1.6 §3 table) | 1/0 -> 1/0, no new finding | successful | IDENTICAL |

Negative control for `strip_compare.py` (2026-10-09): flipping `1'b1` to `1'b0` in the
`flag_stage_frame_complete` set branch was reported DIFFERENT; restoring gave IDENTICAL.

## BMI-160 `@satisfies` tags (stage 4)

The five files above are not strict deliverables at the baseline either: the gate reports 29 errors and 1 strict warning
on the `7a8eabf` copies (VG014/VG060/VG061/VG066 and comment placement). The requirement is therefore "no new finding". The branch copies give
the same 29/1, identical per file, per rule and per message with line numbers removed (`satisfies_gate_compare.txt`,
`tools/b_merge_tools/gate_compare.py`). Every tag was appended to an existing substantive Chinese comment after
checking the post-stage-2 contract row against the code it sits on. Other files: `satisfies_strip_compare.txt`, `satisfies_comment_only.txt`
(including a negative control: one code token changed in the corrector, which the verifier reports), `satisfies_gate_*`, `satisfies_diff.txt`.

Not tagged, on purpose:
- SUP-08: the C24 row still reads "Final Top proves mismatch to STOPPING and legal restart" (not rewritten in stage 2). That does not describe
  `flag_owner_lost_fault_hold`, so no tag (the meaning does not match).
- SID-05: the C25 row is the calibration-owner deadline. The owner-lost tests (WDRAW-LOST, SYS-CAL-*) check voiding, not the deadline,
  so the meaning differs (OLR §8.3); the existing deadline tags in the scheduler stay as they are.
