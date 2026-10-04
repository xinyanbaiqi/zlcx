# Design Explanation: ppg_config_cdc_bridge

## Project Topology
- Selected top module: `ppg_config_cdc_bridge`
- Module count: 1

## Interface Summary
- `input i_source_clk` width=1 role=clock
- `input i_source_rstn` width=1 role=reset
- `input i_source_config` width=1 role=signal
- `input i_source_update` width=1 role=signal
- `output o_source_busy` width=1 role=signal
- `input i_destination_clk` width=1 role=clock
- `input i_destination_rstn` width=1 role=reset
- `output o_destination_config` width=1 role=signal
- `output o_destination_update` width=1 role=signal

## Feature Mapping
- `ppg_config_cdc_bridge reset behavior`: derived from ports, state, and always blocks.
- `logic partition block 1`: derived from ports, state, and always blocks.
- `logic partition block 2`: derived from ports, state, and always blocks.
- `logic partition block 3`: derived from ports, state, and always blocks.
- `logic partition block 4`: derived from ports, state, and always blocks.
- `logic partition block 5`: derived from ports, state, and always blocks.
- `logic partition block 6`: derived from ports, state, and always blocks.
- `logic partition block 7`: derived from ports, state, and always blocks.
- `logic partition block 8`: derived from ports, state, and always blocks.
- `logic partition block 9`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_config_cdc_bridge` drives known output values after reset release.
- `fc001`: ppg_config_cdc_bridge reset behavior

## Decomposition Candidates
- `u_block_1` lines 101-112: logic_partition
- `u_block_2` lines 112-124: logic_partition
- `u_block_3` lines 124-135: logic_partition
- `u_block_4` lines 135-146: logic_partition
- `u_block_5` lines 146-155: logic_partition
- `u_block_6` lines 155-164: logic_partition
- `u_block_7` lines 164-173: logic_partition
- `u_block_8` lines 173-182: logic_partition
- `u_block_9` lines 182-192: logic_partition

