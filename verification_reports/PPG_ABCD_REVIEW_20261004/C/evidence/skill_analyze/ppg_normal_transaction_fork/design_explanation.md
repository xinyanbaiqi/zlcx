# Design Explanation: ppg_normal_transaction_fork

## Project Topology
- Selected top module: `ppg_normal_transaction_fork`
- Module count: 1

## Interface Summary
- `input i_clk` width=1 role=clock
- `input i_rstn` width=1 role=reset
- `input i_run_generation` width=1 role=signal
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
- `output o_normal_ready` width=1 role=status
- `input i_measurement_ready` width=1 role=status
- `output o_measurement_valid` width=1 role=status
- `output o_measurement_calibrated_s1_value` width=1 role=signal
- `output o_measurement_calibration_applied` width=1 role=signal
- `output o_measurement_saturation_low` width=1 role=signal
- `output o_measurement_saturation_high` width=1 role=signal
- `output o_measurement_config_epoch` width=1 role=signal
- `output o_measurement_coef_epoch` width=1 role=signal
- `output o_measurement_detect_code` width=9 role=signal
- `output o_measurement_stage1_raw` width=10 role=signal
- `output o_measurement_stage1_code_ext` width=1 role=signal
- `output o_measurement_stage2_raw` width=10 role=signal
- `output o_measurement_precision_mode` width=1 role=control
- `output o_measurement_frame_id` width=1 role=signal
- `output o_measurement_sample_index` width=1 role=signal
- `output o_measurement_color_ir` width=1 role=signal
- `output o_measurement_frame_type` width=2 role=signal
- `output o_measurement_amb_code_snapshot` width=1 role=signal
- `output o_measurement_dc_code_snapshot` width=1 role=signal
- `output o_measurement_amb_code_epoch` width=1 role=signal
- `output o_measurement_dc_code_epoch` width=1 role=signal
- `output o_measurement_run_generation` width=1 role=signal
- `input i_track_ready` width=1 role=status
- `output o_track_valid` width=1 role=status
- `output o_track_calibrated_s1_value` width=1 role=signal
- `output o_track_calibration_applied` width=1 role=signal
- `output o_track_saturation_low` width=1 role=signal
- `output o_track_saturation_high` width=1 role=signal
- `output o_track_config_epoch` width=1 role=signal
- `output o_track_coef_epoch` width=1 role=signal
- `output o_track_precision_mode` width=1 role=control
- `output o_track_frame_id` width=1 role=signal
- `output o_track_sample_index` width=1 role=signal
- `output o_track_color_ir` width=1 role=signal
- `output o_track_frame_type` width=2 role=signal
- `output o_track_amb_code_snapshot` width=1 role=signal
- `output o_track_dc_code_snapshot` width=1 role=signal
- `output o_track_amb_code_epoch` width=1 role=signal
- `output o_track_dc_code_epoch` width=1 role=signal
- `output o_tracking_run_generation` width=1 role=signal
- `output o_local_empty` width=1 role=signal

## Feature Mapping
- `ppg_normal_transaction_fork reset behavior`: derived from ports, state, and always blocks.
- `logic partition block 1`: derived from ports, state, and always blocks.
- `output update block 2`: derived from ports, state, and always blocks.
- `output update block 3`: derived from ports, state, and always blocks.
- `logic partition block 4`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_normal_transaction_fork` drives known output values after reset release.
- `fc001`: ppg_normal_transaction_fork reset behavior

## Decomposition Candidates
- `u_block_1` lines 275-286: logic_partition
- `u_block_2` lines 286-299: output_update
- `u_block_3` lines 299-312: output_update
- `u_block_4` lines 312-322: logic_partition

