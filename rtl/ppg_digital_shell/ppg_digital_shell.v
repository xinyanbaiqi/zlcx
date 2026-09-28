`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// PPG digital controller black-box shell
//
// This file intentionally contains no functional RTL.  It only defines the
// digital block boundary for mixed-signal top-level integration, pad/ESD
// schematic capture, and early floorplanning.
//
// ADC interface contract:
//   - Each pipeline-SAR stage supplies a 10-bit physical raw code (DOUT_STAGEx_LOW).
//   - CLK_STAGEx_DOUT_LOW marks the stage's final-bit decision complete and is
//     allowed to be asynchronous to CLK_2M.
//   - DOUT_STAGEx_LOW has an ample natural margin (~4800 CLK_2M cycles) before
//     the next conversion overwrites it; no ACK handshake exists or is needed.
//
// IDAC widths are placeholders until the analog IDAC resolutions are frozen.
// -----------------------------------------------------------------------------
(* black_box = "true" *)
module ppg_digital_shell #(
    parameter integer AMB_IDAC_WIDTH = 8,
    parameter integer DCS_IDAC_WIDTH = 8
) (
    // -------------------------------------------------------------------------
    // Digital power pins used by the pad/ESD-level schematic.
    // AUX pins are separate package pins connected to the same named domain.
    // -------------------------------------------------------------------------
    inout  wire                         DVDD12,
    inout  wire                         DGND12,
    inout  wire                         DVDD33,
    inout  wire                         DGND33,
    inout  wire                         DVDD33_AUX,
    inout  wire                         DGND33_AUX,

    // -------------------------------------------------------------------------
    // External digital pads (QFN-48 package-facing signals).
    // -------------------------------------------------------------------------
    input  wire                         CLK_2M,
    input  wire                         RESET_N,

    input  wire                         SPI_CS_N,
    input  wire                         SPI_SCLK,
    input  wire                         SPI_SDI,
    output wire                         SPI_SDO,

    output wire                         P2S_CLK,
    output wire                         P2S_DATA,
    output wire                         P2S_FRAME,
    output wire                         DBG_OUT,

    // -------------------------------------------------------------------------
    // Asynchronous two-stage pipeline-SAR ADC result interface.
    // Both physical stage buses are 10 bits, including redundancy.
    // -------------------------------------------------------------------------
    input  wire [9:0]                   DOUT_STAGE1_LOW,
    input  wire                         CLK_STAGE1_DOUT_LOW,

    input  wire [9:0]                   DOUT_STAGE2_LOW,
    input  wire                         CLK_STAGE2_DOUT_LOW,

    // -------------------------------------------------------------------------
    // Analog clock, reset, power-up, and conversion controls.
    // -------------------------------------------------------------------------
    output wire                         ANA_CLK_2M,
    output wire                         ANA_RST_N,
    output wire                         ADC_RST_N,
    output wire                         FRAME_START_400HZ,

    output wire                         ANA_BIAS_EN,
    output wire                         ADC_REF_EN,
    output wire                         ADC_S1_EN,
    output wire                         ADC_S2_EN,
    output wire                         ADC_FINE_MODE,
    output wire                         ADC_START,

    // -------------------------------------------------------------------------
    // LED driver controls.  ILED1/ILED2 are analog package outputs and are not
    // ports of this digital block; these signals drive their analog drivers.
    // -------------------------------------------------------------------------
    output wire                         LED_DRV_EN,
    output wire                         LED1_EN,
    output wire                         LED2_EN,

    // -------------------------------------------------------------------------
    // Ambient-light and DC-cancellation IDAC controls.
    // The digital block outputs the active code for the current LED phase.
    // -------------------------------------------------------------------------
    output wire [AMB_IDAC_WIDTH-1:0]    AMB_IDAC_CODE,
    output wire                         AMB_IDAC_EN,
    output wire [DCS_IDAC_WIDTH-1:0]    DCS_IDAC_CODE,
    output wire                         DCS_IDAC_EN,
    output wire                         IDAC_UPDATE,

    // -------------------------------------------------------------------------
    // Analog functional-test controls selected through SPI registers.
    // There are no dedicated package pins for normal/fine/test mode selection.
    // -------------------------------------------------------------------------
    output wire                         TEST_MODE,
    output wire                         VOUT_TEST_EN
);

    // Black-box shell: functional implementation will be added later.

endmodule

`default_nettype wire
