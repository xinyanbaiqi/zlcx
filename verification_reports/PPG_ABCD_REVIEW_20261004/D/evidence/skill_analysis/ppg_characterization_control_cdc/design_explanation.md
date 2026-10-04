# Design Explanation: ppg_characterization_control_cdc

## Project Topology
- Selected top module: `ppg_characterization_control_cdc`
- Module count: 1

## Interface Summary
- `input i_source_clk` width=1 role=clock
- `input i_source_rstn` width=1 role=reset
- `input i_clk` width=1 role=clock
- `input i_rstn` width=1 role=reset
- `input i_source_update_valid` width=1 role=status
- `input i_source_static_characterization_enable` width=1 role=control
- `input i_source_test_mux_ctrl` width=5 role=signal
- `input i_run_enable` width=1 role=control
- `input i_diag_clear_event` width=1 role=signal
- `output o_source_update_ready` width=1 role=status
- `output o_static_characterization_enable` width=1 role=control
- `output o_test_mux_ctrl` width=5 role=signal
- `output o_control_valid` width=1 role=status
- `output o_control_update_event` width=1 role=signal
- `output o_control_reject_event` width=1 role=signal
- `output o_protocol_error_sticky` width=1 role=signal

## Feature Mapping
- `ppg_characterization_control_cdc reset behavior`: derived from ports, state, and always blocks.
- `logic partition block 1`: derived from ports, state, and always blocks.
- `logic partition block 2`: derived from ports, state, and always blocks.
- `output update block 3`: derived from ports, state, and always blocks.
- `logic partition block 4`: derived from ports, state, and always blocks.
- `logic partition block 5`: derived from ports, state, and always blocks.
- `logic partition block 6`: derived from ports, state, and always blocks.
- `logic partition block 7`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_characterization_control_cdc` drives known output values after reset release.
- `fc001`: ppg_characterization_control_cdc reset behavior

## Decomposition Candidates
- `u_block_1` lines 127-138: logic_partition
- `u_block_2` lines 138-149: logic_partition
- `u_block_3` lines 149-160: output_update
- `u_block_4` lines 160-171: logic_partition
- `u_block_5` lines 171-182: logic_partition
- `u_block_6` lines 182-196: logic_partition
- `u_block_7` lines 196-222: logic_partition

