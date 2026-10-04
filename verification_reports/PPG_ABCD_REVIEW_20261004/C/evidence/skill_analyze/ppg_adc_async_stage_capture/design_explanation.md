# Design Explanation: ppg_adc_async_stage_capture

## Project Topology
- Selected top module: `ppg_adc_async_stage_capture`
- Module count: 1

## Interface Summary
- `input i_clk` width=1 role=clock
- `input i_rstn` width=1 role=reset
- `input i_adc_transaction_start` width=1 role=signal
- `input i_precision_mode_committed` width=1 role=control
- `input i_dout_stage1_low` width=1 role=signal
- `input i_clk_stage1_dout_low_async` width=1 role=clock
- `input i_dout_stage2_low` width=1 role=signal
- `input i_clk_stage2_dout_low_async` width=1 role=clock
- `input i_capture_ready` width=1 role=status
- `output o_capture_stage1_raw` width=1 role=signal
- `output o_capture_stage2_raw` width=1 role=signal
- `output o_capture_precision_mode` width=1 role=control
- `output o_capture_valid` width=1 role=status

## Feature Mapping
- `ppg_adc_async_stage_capture reset behavior`: derived from ports, state, and always blocks.
- `logic partition block 1`: derived from ports, state, and always blocks.
- `logic partition block 2`: derived from ports, state, and always blocks.
- `logic partition block 3`: derived from ports, state, and always blocks.
- `output update block 4`: derived from ports, state, and always blocks.
- `logic partition block 5`: derived from ports, state, and always blocks.
- `logic partition block 6`: derived from ports, state, and always blocks.
- `logic partition block 7`: derived from ports, state, and always blocks.
- `logic partition block 8`: derived from ports, state, and always blocks.
- `logic partition block 9`: derived from ports, state, and always blocks.
- `logic partition block 10`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_adc_async_stage_capture` drives known output values after reset release.
- `fc001`: ppg_adc_async_stage_capture reset behavior

## Decomposition Candidates
- `u_block_1` lines 118-129: logic_partition
- `u_block_2` lines 129-144: logic_partition
- `u_block_3` lines 144-155: logic_partition
- `u_block_4` lines 155-169: output_update
- `u_block_5` lines 169-180: logic_partition
- `u_block_6` lines 180-191: logic_partition
- `u_block_7` lines 191-202: logic_partition
- `u_block_8` lines 202-213: logic_partition
- `u_block_9` lines 213-224: logic_partition
- `u_block_10` lines 224-236: logic_partition

