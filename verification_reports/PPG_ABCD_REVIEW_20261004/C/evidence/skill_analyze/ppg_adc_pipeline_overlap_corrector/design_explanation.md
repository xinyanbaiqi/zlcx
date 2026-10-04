# Design Explanation: ppg_adc_pipeline_overlap_corrector

## Project Topology
- Selected top module: `ppg_adc_pipeline_overlap_corrector`
- Module count: 1

## Interface Summary
- `input i_clk` width=1 role=clock
- `input i_rstn` width=1 role=reset
- `input i_datapath_discard_event` width=1 role=data
- `input i_datapath_discard_reason` width=2 role=data
- `input i_datapath_discard_identity_valid` width=1 role=status
- `input i_datapath_discard_frame_id` width=1 role=data
- `input i_datapath_discard_sample_index` width=1 role=data
- `input i_datapath_discard_color_ir` width=1 role=data
- `input i_datapath_discard_frame_type` width=2 role=data
- `input i_datapath_discard_precision` width=1 role=data
- `input i_datapath_discard_run_generation` width=1 role=data
- `input i_normal_valid` width=1 role=status
- `input i_calibrated_s1_value` width=1 role=signal
- `input i_calibration_applied` width=1 role=signal
- `input i_saturation_low` width=1 role=signal
- `input i_saturation_high` width=1 role=signal
- `input i_config_epoch` width=1 role=signal
- `input i_coef_epoch` width=1 role=signal
- `input i_detect_code` width=9 role=signal
- `input i_stage1_raw` width=10 role=signal
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
- `input i_run_generation` width=1 role=signal
- `output o_normal_ready` width=1 role=status
- `input i_result_ready` width=1 role=status
- `output o_result_valid` width=1 role=status
- `output o_calibrated_s1_value` width=1 role=signal
- `output o_calibration_applied` width=1 role=signal
- `output o_saturation_low` width=1 role=signal
- `output o_saturation_high` width=1 role=signal
- `output o_config_epoch` width=1 role=signal
- `output o_coef_epoch` width=1 role=signal
- `output o_detect_code` width=9 role=signal
- `output o_stage1_raw` width=10 role=signal
- `output o_stage1_code_ext` width=1 role=signal
- `output o_stage2_raw` width=10 role=signal
- `output o_stage2_code_ext` width=1 role=signal
- `output o_nominal_15_code` width=1 role=signal
- `output o_nominal_15_valid` width=1 role=status
- `output o_nominal_saturated` width=1 role=signal
- `output o_precision_mode` width=1 role=control
- `output o_frame_id` width=1 role=signal
- `output o_sample_index` width=1 role=signal
- `output o_color_ir` width=1 role=signal
- `output o_frame_type` width=2 role=signal
- `output o_amb_code_snapshot` width=1 role=signal
- `output o_dc_code_snapshot` width=1 role=signal
- `output o_amb_code_epoch` width=1 role=signal
- `output o_dc_code_epoch` width=1 role=signal
- `output o_run_generation` width=1 role=signal
- `output o_local_empty` width=1 role=signal

## Feature Mapping
- `ppg_adc_pipeline_overlap_corrector reset behavior`: derived from ports, state, and always blocks.
- `logic partition block 1`: derived from ports, state, and always blocks.
- `logic partition block 2`: derived from ports, state, and always blocks.
- `logic partition block 3`: derived from ports, state, and always blocks.
- `logic partition block 4`: derived from ports, state, and always blocks.
- `logic partition block 5`: derived from ports, state, and always blocks.
- `logic partition block 6`: derived from ports, state, and always blocks.
- `logic partition block 7`: derived from ports, state, and always blocks.
- `logic partition block 8`: derived from ports, state, and always blocks.
- `logic partition block 9`: derived from ports, state, and always blocks.
- `output update block 10`: derived from ports, state, and always blocks.
- `output update block 11`: derived from ports, state, and always blocks.
- `logic partition block 12`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_adc_pipeline_overlap_corrector` drives known output values after reset release.
- `fc001`: ppg_adc_pipeline_overlap_corrector reset behavior

## Decomposition Candidates
- `u_block_1` lines 312-323: logic_partition
- `u_block_2` lines 323-334: logic_partition
- `u_block_3` lines 334-345: logic_partition
- `u_block_4` lines 345-356: logic_partition
- `u_block_5` lines 356-371: logic_partition
- `u_block_6` lines 371-382: logic_partition
- `u_block_7` lines 382-393: logic_partition
- `u_block_8` lines 393-404: logic_partition
- `u_block_9` lines 404-415: logic_partition
- `u_block_10` lines 415-426: output_update
- `u_block_11` lines 426-439: output_update
- `u_block_12` lines 439-449: logic_partition

