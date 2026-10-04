# Design Explanation: ppg_reset_sync

## Project Topology
- Selected top module: `ppg_reset_sync`
- Module count: 1

## Interface Summary
- `input i_clk` width=1 role=clock
- `input i_async_rstn` width=1 role=reset
- `output o_rstn` width=1 role=reset

## Feature Mapping
- `ppg_reset_sync reset behavior`: derived from ports, state, and always blocks.
- `logic partition block 1`: derived from ports, state, and always blocks.
- `logic partition block 2`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_reset_sync` drives known output values after reset release.
- `fc001`: ppg_reset_sync reset behavior

## Decomposition Candidates
- `u_block_1` lines 67-77: logic_partition
- `u_block_2` lines 77-85: logic_partition

