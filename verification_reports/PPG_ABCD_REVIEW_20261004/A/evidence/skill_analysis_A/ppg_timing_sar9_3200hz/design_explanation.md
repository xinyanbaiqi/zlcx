# Design Explanation: ppg_timing_sar9_3200hz

## Project Topology
- Selected top module: `ppg_timing_sar9_3200hz`
- Module count: 1

## Interface Summary
- `input i_clk` width=1 role=clock
- `input i_rstn` width=1 role=reset
- `input i_enable` width=1 role=control
- `input i_test_mode` width=1 role=control
- `input i_optical_mode` width=2 role=control
- `input i_static_characterization_enable` width=1 role=control
- `input i_test_mux_ctrl` width=5 role=signal
- `input i_static_sar9_amb_code` width=8 role=signal
- `input i_static_sar9_dc_code` width=8 role=signal
- `input i_static_sar15_amb_code` width=8 role=signal
- `input i_static_sar15_dc_code` width=8 role=signal
- `input i_leddac_r_code` width=8 role=signal
- `input i_leddac_ir_code` width=8 role=signal
- `input i_idac_sar9_amb_r_code` width=8 role=signal
- `input i_idac_sar9_amb_ir_code` width=8 role=signal
- `input i_idac_sar9_dc_r_code` width=8 role=signal
- `input i_idac_sar9_dc_ir_code` width=8 role=signal
- `output o_frame_start_3200hz` width=1 role=signal
- `output o_en_tia_low` width=1 role=signal
- `output o_leddac` width=8 role=signal
- `output o_leden1_low` width=1 role=signal
- `output o_leden2_low` width=1 role=signal
- `output o_en_test` width=1 role=signal
- `output o_clk_buf_low` width=1 role=clock
- `output o_clk_2m` width=1 role=clock
- `output o_clk_iref_idac_low` width=1 role=clock
- `output o_clk_9q1_low` width=1 role=clock
- `output o_clk_15q1_low` width=1 role=clock
- `output o_clk_aferst_low` width=1 role=clock
- `output o_clk_iref_idac_sar9_low` width=1 role=clock
- `output o_clk_iref_idac_sar15_low` width=1 role=clock
- `output o_clk_q2_low` width=1 role=clock
- `output o_clk_q3_low` width=1 role=clock
- `output o_clk_tiaen_low` width=1 role=clock
- `output o_en_15sar_low` width=1 role=signal
- `output o_en_sar9_amb_low` width=1 role=signal
- `output o_en_sar9_dc_low` width=1 role=signal
- `output o_en_sar9_iref` width=1 role=signal
- `output o_en_sar15_amb_low` width=1 role=signal
- `output o_en_sar15_dc_low` width=1 role=signal
- `output o_en_sar15_iref` width=1 role=signal
- `output o_idac_sar9ambn_low` width=8 role=signal
- `output o_idac_sar9dcn_low` width=8 role=signal
- `output o_idac_sar15ambn_low` width=8 role=signal
- `output o_idac_sar15dcn_low` width=8 role=signal
- `output o_s_in` width=5 role=signal

## Feature Mapping
- `ppg_timing_sar9_3200hz reset behavior`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_timing_sar9_3200hz` drives known output values after reset release.
- `fc001`: ppg_timing_sar9_3200hz reset behavior

## Decomposition Candidates
- No decomposition candidates were inferred.

