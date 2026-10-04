# Design Explanation: ppg_chip_digital_top

## Project Topology
- Selected top module: `ppg_chip_digital_top`
- Module count: 1

## Interface Summary
- `input CLK_2M_PAD` width=1 role=clock
- `input RESET_N` width=1 role=reset
- `input SPI_CS_N` width=1 role=signal
- `input SPI_SCLK` width=1 role=clock
- `input SPI_SDI` width=1 role=signal
- `output SPI_SDO` width=1 role=signal
- `output P2S_CLK` width=1 role=clock
- `output P2S_DATA` width=1 role=data
- `output P2S_FRAME` width=1 role=signal
- `output DBG_OUT` width=1 role=signal
- `input DOUT_STAGE1_LOW` width=10 role=signal
- `input CLK_STAGE1_DOUT_LOW` width=1 role=clock
- `input DOUT_STAGE2_LOW` width=10 role=signal
- `input CLK_STAGE2_DOUT_LOW` width=1 role=clock
- `output EN_TIA_LOW` width=1 role=signal
- `output LEDDAC` width=8 role=signal
- `output LEDEN1_LOW` width=1 role=signal
- `output LEDEN2_LOW` width=1 role=signal
- `output EN_TEST` width=1 role=signal
- `output CLK_BUF_LOW` width=1 role=clock
- `output CLK_2M` width=1 role=clock
- `output CLK_IREF_IDAC_LOW` width=1 role=clock
- `output CLK_9Q1_LOW` width=1 role=clock
- `output CLK_15Q1_LOW` width=1 role=clock
- `output CLK_AFERST_LOW` width=1 role=clock
- `output CLK_IREF_IDAC_SAR9_LOW` width=1 role=clock
- `output CLK_IREF_IDAC_SAR15_LOW` width=1 role=clock
- `output CLK_Q2_LOW` width=1 role=clock
- `output CLK_Q3_LOW` width=1 role=clock
- `output CLK_TIAEN_LOW` width=1 role=clock
- `output EN_15SAR_LOW` width=1 role=signal
- `output EN_SAR9_AMB_LOW` width=1 role=signal
- `output EN_SAR9_DC_LOW` width=1 role=signal
- `output EN_SAR9_IREF` width=1 role=signal
- `output EN_SAR15_AMB_LOW` width=1 role=signal
- `output EN_SAR15_DC_LOW` width=1 role=signal
- `output EN_SAR15_IREF` width=1 role=signal
- `output IDAC_SAR9AMBN_LOW` width=8 role=signal
- `output IDAC_SAR9DCN_LOW` width=8 role=signal
- `output IDAC_SAR15AMBN_LOW` width=8 role=signal
- `output IDAC_SAR15DCN_LOW` width=8 role=signal
- `output S0_IN` width=1 role=signal
- `output S1_IN` width=1 role=signal
- `output S2_IN` width=1 role=signal
- `output S3_IN` width=1 role=signal
- `output S4_IN` width=1 role=signal

## Feature Mapping
- `ppg_chip_digital_top reset behavior`: derived from ports, state, and always blocks.
- `logic partition block 1`: derived from ports, state, and always blocks.
- `logic partition block 2`: derived from ports, state, and always blocks.
- `logic partition block 3`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_chip_digital_top` drives known output values after reset release.
- `fc001`: ppg_chip_digital_top reset behavior

## Decomposition Candidates
- `u_block_1` lines 343-352: logic_partition
- `u_block_2` lines 352-361: logic_partition
- `u_block_3` lines 361-667: logic_partition

