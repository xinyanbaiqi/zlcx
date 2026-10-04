# Design Explanation: ppg_digital_shell

## Project Topology
- Selected top module: `ppg_digital_shell`
- Module count: 1

## Interface Summary
- `inout DVDD12` width=1 role=signal
- `inout DGND12` width=1 role=signal
- `inout DVDD33` width=1 role=signal
- `inout DGND33` width=1 role=signal
- `inout DVDD33_AUX` width=1 role=signal
- `inout DGND33_AUX` width=1 role=signal
- `input CLK_2M` width=1 role=clock
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
- `output ANA_CLK_2M` width=1 role=clock
- `output ANA_RST_N` width=1 role=reset
- `output ADC_RST_N` width=1 role=reset
- `output FRAME_START_400HZ` width=1 role=signal
- `output ANA_BIAS_EN` width=1 role=signal
- `output ADC_REF_EN` width=1 role=signal
- `output ADC_S1_EN` width=1 role=signal
- `output ADC_S2_EN` width=1 role=signal
- `output ADC_FINE_MODE` width=1 role=control
- `output ADC_START` width=1 role=signal
- `output LED_DRV_EN` width=1 role=signal
- `output LED1_EN` width=1 role=signal
- `output LED2_EN` width=1 role=signal
- `output AMB_IDAC_CODE` width=1 role=signal
- `output AMB_IDAC_EN` width=1 role=signal
- `output DCS_IDAC_CODE` width=1 role=signal
- `output DCS_IDAC_EN` width=1 role=signal
- `output IDAC_UPDATE` width=1 role=signal
- `output TEST_MODE` width=1 role=control
- `output VOUT_TEST_EN` width=1 role=signal

## Feature Mapping
- `ppg_digital_shell reset behavior`: derived from ports, state, and always blocks.

## Verification Targets
- `reset_outputs_known`: Verify `ppg_digital_shell` drives known output values after reset release.
- `fc001`: ppg_digital_shell reset behavior

## Decomposition Candidates
- No decomposition candidates were inferred.

