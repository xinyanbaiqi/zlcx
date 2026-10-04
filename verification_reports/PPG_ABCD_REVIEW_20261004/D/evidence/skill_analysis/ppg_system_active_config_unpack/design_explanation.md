# Design Explanation: ppg_system_active_config_unpack

## Project Topology
- Selected top module: `ppg_system_active_config_unpack`
- Module count: 1

## Interface Summary
- `input i_active_config` width=1024 role=signal
- `output o_schema_version` width=8 role=signal
- `output o_run_profile` width=1 role=signal
- `output o_input_source` width=1 role=signal
- `output o_idac_mode` width=2 role=control
- `output o_optical_mode` width=2 role=control
- `output o_initial_precision` width=1 role=signal
- `output o_amb_enable` width=1 role=control
- `output o_dcs_enable` width=1 role=control
- `output o_amb_polarity` width=1 role=signal
- `output o_dcs_polarity` width=1 role=signal
- `output o_stage1_calibration_valid` width=1 role=status
- `output o_stage2_calibration_valid` width=1 role=status
- `output o_dc9_recovery_valid` width=1 role=status
- `output o_dc15_recovery_valid` width=1 role=status
- `output o_amb_manual_code` width=8 role=signal
- `output o_amb_code_min` width=8 role=signal
- `output o_amb_code_max` width=8 role=signal
- `output o_dcs_r_manual_code` width=8 role=signal
- `output o_dcs_r_code_min` width=8 role=signal
- `output o_dcs_r_code_max` width=8 role=signal
- `output o_dcs_ir_manual_code` width=8 role=signal
- `output o_dcs_ir_code_min` width=8 role=signal
- `output o_dcs_ir_code_max` width=8 role=signal
- `output o_amb_threshold_low` width=1 role=signal
- `output o_amb_threshold_high` width=1 role=signal
- `output o_dcs_threshold_low` width=1 role=signal
- `output o_dcs_threshold_high` width=1 role=signal
- `output o_amb_confirm_count` width=8 role=signal
- `output o_dcs_confirm_count` width=8 role=signal
- `output o_stage1_weight_q16_0` width=1 role=signal
- `output o_stage1_weight_q16_1` width=1 role=signal
- `output o_stage1_weight_q16_2` width=1 role=signal
- `output o_stage1_weight_q16_3` width=1 role=signal
- `output o_stage1_weight_q16_4` width=1 role=signal
- `output o_stage1_weight_q16_5` width=1 role=signal
- `output o_stage1_weight_q16_6` width=1 role=signal
- `output o_stage1_weight_q16_7` width=1 role=signal
- `output o_stage1_weight_q16_8` width=1 role=signal
- `output o_stage1_weight_q16_9` width=1 role=signal
- `output o_stage1_offset_q16` width=1 role=signal
- `output o_stage2_gain_q16` width=1 role=signal
- `output o_stage2_offset_q16` width=1 role=signal
- `output o_dc9_recovery_gain_q16` width=1 role=signal
- `output o_dc15_recovery_gain_q16` width=1 role=signal
- `output o_amb_recheck_interval_frames` width=16 role=signal
- `output o_slope_mode` width=1 role=control
- `output o_fixed_slope_q16` width=1 role=signal
- `output o_alpha_q15` width=16 role=signal
- `output o_beta_q15` width=16 role=signal
- `output o_timing_adjust_ratio_q15` width=16 role=signal
- `output o_slope_min_q16` width=1 role=signal
- `output o_slope_max_q16` width=1 role=signal
- `output o_baseline_delta_q16` width=1 role=control
- `output o_cross_hysteresis_q16` width=32 role=signal
- `output o_lead_min_frames` width=16 role=signal
- `output o_lead_max_frames` width=16 role=signal
- `output o_cross_confirm_count` width=4 role=signal
- `output o_no_cross_limit` width=4 role=signal
- `output o_peak_confirm_count` width=4 role=signal
- `output o_valley_confirm_count` width=4 role=signal
- `output o_direction_deadband` width=24 role=signal
- `output o_min_peak_valley_amplitude` width=24 role=signal
- `output o_min_peak_to_valley_frames` width=16 role=signal
- `output o_min_peak_to_peak_frames` width=16 role=signal
- `output o_max_fine_window_frames` width=16 role=signal
- `output o_max_reacquire_frames` width=16 role=signal
- `output o_peak_valley_config_valid` width=1 role=status

## Feature Mapping
- `ppg_system_active_config_unpack reset behavior`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_system_active_config_unpack` drives known output values after reset release.
- `fc001`: ppg_system_active_config_unpack reset behavior

## Decomposition Candidates
- No decomposition candidates were inferred.

