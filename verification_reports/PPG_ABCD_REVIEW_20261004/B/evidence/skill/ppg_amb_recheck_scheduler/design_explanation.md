# Design Explanation: ppg_amb_recheck_scheduler

## Project Topology
- Selected top module: `ppg_amb_recheck_scheduler`
- Module count: 1

## Interface Summary
- `input i_clk` width=1 role=clock
- `input i_rstn` width=1 role=reset
- `input i_run_enable` width=1 role=control
- `input i_start_ack_event` width=1 role=signal
- `input i_stop_ack_event` width=1 role=signal
- `input i_control_abort_event` width=1 role=signal
- `input i_idac_mode` width=2 role=control
- `input i_amb_enable` width=1 role=control
- `input i_dcs_enable` width=1 role=control
- `input i_amb_recheck_interval_frames` width=16 role=signal
- `input i_startup_search_complete` width=1 role=signal
- `input i_normal_measurement_active` width=1 role=signal
- `input i_normal_frame_complete_event` width=1 role=signal
- `input i_precision_15_to_9_event` width=1 role=signal
- `input i_precision_takeover_safe` width=1 role=signal
- `input i_normal_fork_idle` width=1 role=signal
- `input i_idac_idle` width=1 role=signal
- `input i_fir_idle` width=1 role=signal
- `input i_peak_valley_idle` width=1 role=signal
- `input i_frame_safe_boundary` width=1 role=signal
- `input i_calibration_frame_complete_event` width=1 role=signal
- `input i_amb_sample_request` width=1 role=control
- `input i_amb_sequence_done` width=1 role=status
- `input i_amb_sequence_failed` width=1 role=signal
- `input i_dcs_revalidate_request` width=1 role=status
- `input i_dcs_sample_request` width=1 role=control
- `input i_dcs_sample_color_ir` width=1 role=signal
- `input i_dcs_revalidate_done` width=1 role=status
- `input i_dcs_revalidate_failed` width=1 role=status
- `input i_amb_sample_accepted_event` width=1 role=signal
- `input i_dcs_sample_accepted_event` width=1 role=signal
- `output o_amb_sequence_start` width=1 role=signal
- `output o_dcs_revalidate_accept` width=1 role=status
- `input i_calibration_sample_ready` width=1 role=status
- `output o_calibration_sample_valid` width=1 role=status
- `output o_calibration_frame_type` width=2 role=signal
- `output o_calibration_color_ir` width=1 role=signal
- `output o_calibration_precision_mode` width=1 role=control
- `output o_calibration_frame_start` width=1 role=signal
- `output o_calibration_stage` width=2 role=signal
- `output o_normal_frame_count` width=16 role=signal
- `output o_amb_recheck_pending` width=1 role=signal
- `output o_amb_recheck_accept` width=1 role=signal
- `output o_amb_recheck_busy` width=1 role=signal
- `output o_normal_output_inhibit` width=1 role=signal
- `output o_sequence_done` width=1 role=status
- `output o_sequence_failed` width=1 role=signal
- `output o_scheduler_idle` width=1 role=signal

## Feature Mapping
- `ppg_amb_recheck_scheduler reset behavior`: derived from ports, state, and always blocks.
- `counter update block 1`: derived from ports, state, and always blocks.
- `logic partition block 2`: derived from ports, state, and always blocks.
- `state transition block 3`: derived from ports, state, and always blocks.
- `state transition block 4`: derived from ports, state, and always blocks.
- `logic partition block 5`: derived from ports, state, and always blocks.
- `logic partition block 6`: derived from ports, state, and always blocks.
- `logic partition block 7`: derived from ports, state, and always blocks.
- `counter progression`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_amb_recheck_scheduler` drives known output values after reset release.
- `counter_progression`: Verify timer/counter progression across phase transitions.
- `fc001`: ppg_amb_recheck_scheduler reset behavior
- `fc900`: counter progression

## Decomposition Candidates
- `u_block_1` lines 229-244: counter_update
- `u_block_2` lines 244-258: logic_partition
- `u_block_3` lines 258-267: state_transition
- `u_block_4` lines 267-329: state_transition
- `u_block_5` lines 329-346: logic_partition
- `u_block_6` lines 346-360: logic_partition
- `u_block_7` lines 360-374: logic_partition

