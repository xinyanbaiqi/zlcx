# Design Explanation: ppg_adc_s1_programmable_calibrator

## Project Topology
- Selected top module: `ppg_adc_s1_programmable_calibrator`
- Module count: 1

## Interface Summary
- `input i_clk` width=1 role=clock
- `input i_rstn` width=1 role=reset
- `input i_active_valid` width=1 role=status
- `input i_stage1_calibration_valid` width=1 role=status
- `input i_config_epoch` width=1 role=signal
- `input i_coef_epoch` width=1 role=signal
- `input i_stage1_weight_q16_0` width=1 role=signal
- `input i_stage1_weight_q16_1` width=1 role=signal
- `input i_stage1_weight_q16_2` width=1 role=signal
- `input i_stage1_weight_q16_3` width=1 role=signal
- `input i_stage1_weight_q16_4` width=1 role=signal
- `input i_stage1_weight_q16_5` width=1 role=signal
- `input i_stage1_weight_q16_6` width=1 role=signal
- `input i_stage1_weight_q16_7` width=1 role=signal
- `input i_stage1_weight_q16_8` width=1 role=signal
- `input i_stage1_weight_q16_9` width=1 role=signal
- `input i_stage1_offset_q16` width=1 role=signal
- `input i_result_valid` width=1 role=status
- `input i_stage1_raw` width=10 role=signal
- `input i_detect_code` width=9 role=signal
- `input i_stage1_code_ext` width=1 role=signal
- `input i_stage2_raw` width=10 role=signal
- `input i_precision_mode` width=1 role=control
- `input i_frame_id` width=1 role=signal
- `input i_sample_index` width=1 role=signal
- `input i_color_ir` width=1 role=signal
- `input i_frame_type` width=2 role=signal
- `input i_amb_code_snapshot` width=1 role=signal
- `input i_dc_code_snapshot` width=1 role=signal
- `input i_amb_code_epoch` width=1 role=signal
- `input i_dc_code_epoch` width=1 role=signal
- `output o_result_ready` width=1 role=status
- `input i_calibrated_ready` width=1 role=status
- `output o_calibrated_valid` width=1 role=status
- `output o_calibrated_s1_value` width=1 role=signal
- `output o_calibration_applied` width=1 role=signal
- `output o_saturation_low` width=1 role=signal
- `output o_saturation_high` width=1 role=signal
- `output o_config_epoch` width=1 role=signal
- `output o_coef_epoch` width=1 role=signal
- `output o_stage1_raw` width=10 role=signal
- `output o_detect_code` width=9 role=signal
- `output o_stage1_code_ext` width=1 role=signal
- `output o_stage2_raw` width=10 role=signal
- `output o_precision_mode` width=1 role=control
- `output o_frame_id` width=1 role=signal
- `output o_sample_index` width=1 role=signal
- `output o_color_ir` width=1 role=signal
- `output o_frame_type` width=2 role=signal
- `output o_amb_code_snapshot` width=1 role=signal
- `output o_dc_code_snapshot` width=1 role=signal
- `output o_amb_code_epoch` width=1 role=signal
- `output o_dc_code_epoch` width=1 role=signal

## Feature Mapping
- `ppg_adc_s1_programmable_calibrator reset behavior`: derived from ports, state, and always blocks.
- `logic partition block 1`: derived from ports, state, and always blocks.
- `output update block 2`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_adc_s1_programmable_calibrator` drives known output values after reset release.
- `fc001`: ppg_adc_s1_programmable_calibrator reset behavior

## Decomposition Candidates
- `u_block_1` lines 287-298: logic_partition
- `u_block_2` lines 298-310: output_update

