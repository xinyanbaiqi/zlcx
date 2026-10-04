# Design Explanation: ppg_timing_sar15

## Project Topology
- Selected top module: `ppg_timing_sar15`
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
- `input i_idac_sar15_amb_r_code` width=8 role=signal
- `input i_idac_sar15_amb_ir_code` width=8 role=signal
- `input i_idac_sar15_dc_r_code` width=8 role=signal
- `input i_idac_sar15_dc_ir_code` width=8 role=signal
- `output o_frame_start_400hz` width=1 role=signal
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
- `ppg_timing_sar15 reset behavior`: derived from ports, state, and always blocks.
- `logic partition block 1`: derived from ports, state, and always blocks.
- `logic partition block 2`: derived from ports, state, and always blocks.
- `logic partition block 3`: derived from ports, state, and always blocks.
- `logic partition block 4`: derived from ports, state, and always blocks.
- `logic partition block 5`: derived from ports, state, and always blocks.
- `counter update block 6`: derived from ports, state, and always blocks.
- `logic partition block 7`: derived from ports, state, and always blocks.
- `logic partition block 8`: derived from ports, state, and always blocks.
- `logic partition block 9`: derived from ports, state, and always blocks.
- `counter progression`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_timing_sar15` drives known output values after reset release.
- `counter_progression`: Verify timer/counter progression across phase transitions.
- `fc001`: ppg_timing_sar15 reset behavior
- `fc900`: counter progression

## Decomposition Candidates
- `u_block_1` lines 288-297: logic_partition
- `u_block_2` lines 297-306: logic_partition
- `u_block_3` lines 306-317: logic_partition
- `u_block_4` lines 317-329: logic_partition
- `u_block_5` lines 329-341: logic_partition
- `u_block_6` lines 341-352: counter_update
- `u_block_7` lines 352-376: logic_partition
- `u_block_8` lines 376-389: logic_partition
- `u_block_9` lines 389-465: logic_partition

