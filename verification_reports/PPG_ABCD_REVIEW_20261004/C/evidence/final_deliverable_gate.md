# Verilog deliverable gate

Root: `C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-b9b8-78f2-8e39-c02cd0049c19\ppg_review_C\evidence\rtl_inputs`
Delivery ready: `False`
Summary: **92 error(s)**, **0 strict warning(s)**

| Severity | Code | Path | Line | Message |
|---|---|---|---:|---|
| error | VG052 | `ppg_coarse_detection_fir.v` | 312 | Output bridge assign `o_test_calibration_loss_inject_ready` must be placed in 输出信号连线, not `其他信号连线`. |
| error | VG061 | `ppg_coarse_detection_fir.v` | 312 | Item `o_test_calibration_loss_inject_ready` must be placed in 输出信号连线, not `其他信号连线`. |
| error | VG061 | `ppg_coarse_detection_fir.v` | 465 | Item `always@(posedge i_clk or negedge i_rstn)` must be placed in 主要任务处理区域, not `输出信号处理区域`. |
| error | VG052 | `ppg_idac_code_controller.v` | 422 | Output bridge assign `o_test_saturation_inject_ready` must be placed in 输出信号连线, not `其他信号连线`. |
| error | VG061 | `ppg_idac_code_controller.v` | 422 | Item `o_test_saturation_inject_ready` must be placed in 输出信号连线, not `其他信号连线`. |
| error | VG066 | `ppg_idac_code_controller.v` | 423 | Comment for assign `flag_test_saturation_inject_fire` repeats or closely reuses comment from signal `flag_test_saturation_inject_fire`; write entity-specific RTL intent. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_pipeline_overlap_corrector.v:221` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_pipeline_overlap_corrector.v:223` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_pipeline_overlap_corrector.v:229` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_pipeline_overlap_corrector.v:239` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_pipeline_overlap_corrector.v:245` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_pipeline_overlap_corrector.v:249` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_pipeline_overlap_corrector.v:257` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_pipeline_overlap_corrector.v:261` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_pipeline_overlap_corrector.v:271` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_programmable_reconstructor.v:245` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_programmable_reconstructor.v:249` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_programmable_reconstructor.v:253` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_programmable_reconstructor.v:258` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_programmable_reconstructor.v:262` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_programmable_reconstructor.v:265` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_result_router.v:151` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:191` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:193` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:195` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:197` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:199` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:201` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:203` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:205` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:207` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:209` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:213` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:222` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:224` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:227` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:234` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_programmable_calibrator.v:238` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_redundancy_corrector.v:162` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_redundancy_corrector.v:164` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_adc_s1_redundancy_corrector.v:168` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_coarse_detection_fir.v:758` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_coarse_detection_fir.v:760` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:411` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:414` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:425` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:430` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:435` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:438` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:441` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:444` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:447` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:449` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:451` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:454` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:461` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:464` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:467` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:474` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:486` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:499` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:501` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:503` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:506` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:509` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:512` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:515` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:518` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:521` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:524` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:527` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:542` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:545` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:548` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:551` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:563` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:580` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:582` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:586` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:590` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:594` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:596` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:598` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:602` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:604` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:607` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:653` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:656` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:663` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_idac_code_controller.v:671` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_normal_transaction_fork.v:197` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
| error | COMMENT_COMMENT_PLACEMENT | `ppg_normal_transaction_fork.v:204` |  | Verilog code line must use a same-line or adjacent explanatory comment in the requested language. |
