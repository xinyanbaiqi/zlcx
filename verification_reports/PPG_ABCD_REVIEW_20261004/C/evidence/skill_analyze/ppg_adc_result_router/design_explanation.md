# Design Explanation: ppg_adc_result_router

## Project Topology
- Selected top module: `ppg_adc_result_router`
- Module count: 1

## Interface Summary
- `input i_rstn` width=1 role=reset
- `input i_result_valid` width=1 role=status
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
- `input i_amb_cal_ready` width=1 role=status
- `input i_dc_cal_ready` width=1 role=status
- `input i_normal_ready` width=1 role=status
- `output o_result_ready` width=1 role=status
- `output o_amb_cal_valid` width=1 role=status
- `output o_dc_cal_valid` width=1 role=status
- `output o_normal_valid` width=1 role=status
- `output o_frame_type_error` width=1 role=signal
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

## Feature Mapping
- `ppg_adc_result_router reset behavior`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_adc_result_router` drives known output values after reset release.
- `fc001`: ppg_adc_result_router reset behavior

## Decomposition Candidates
- No decomposition candidates were inferred.

