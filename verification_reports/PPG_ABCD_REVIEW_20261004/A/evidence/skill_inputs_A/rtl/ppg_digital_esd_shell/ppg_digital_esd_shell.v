`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// PPG mixed-signal ASIC digital black-box shell
//
// Purpose:
//   1. Generate a digital-block symbol for the top-level analog/ESD schematic.
//   2. Freeze digital I/O directions before the functional RTL is implemented.
//
// This module intentionally contains no functional logic.
// Signals ending in _LOW retain the analog schematic naming convention; the
// suffix does not by itself define active-low polarity.
// -----------------------------------------------------------------------------
(* black_box = "true" *)
module ppg_digital_esd_shell (
    // -------------------------------------------------------------------------
    // QFN-48 package-facing digital power and signal pins.
    // CLK_2M_PAD is the external pin; CLK_2M below is the internal analog clock.
    // -------------------------------------------------------------------------
    inout  wire         DVDD12,             // QFN pin 33
    inout  wire         DGND12,             // QFN pin 34
    inout  wire         DVDD33,             // QFN pin 35
    inout  wire         DGND33,             // QFN pin 36
    inout  wire         DVDD33_AUX,         // QFN pin 37
    input  wire         RESET_N,            // QFN pin 38
    input  wire         SPI_CS_N,           // QFN pin 39
    input  wire         SPI_SCLK,           // QFN pin 40
    input  wire         SPI_SDI,            // QFN pin 41
    output wire         SPI_SDO,            // QFN pin 42
    output wire         P2S_CLK,            // QFN pin 43
    output wire         P2S_DATA,           // QFN pin 44
    output wire         P2S_FRAME,          // QFN pin 45
    output wire         DBG_OUT,            // QFN pin 46
    input  wire         CLK_2M_PAD,         // QFN pin 47, package name CLK_2M
    inout  wire         DGND33_AUX,         // QFN pin 48

    // -------------------------------------------------------------------------
    // Two-stage asynchronous pipeline-SAR ADC data interface.
    // Each physical stage output contains 9 nominal bits plus 1 redundant bit.
    // CLK_STAGEx_DOUT_LOW marks the stage's final-bit decision complete; RAW
    // has an ample natural margin (~4800 CLK_2M cycles) before the next
    // conversion overwrites it, so no ACK handshake is required or provided.
    // -------------------------------------------------------------------------
    input  wire [9:0]   DOUT_STAGE1_LOW,
    input  wire         CLK_STAGE1_DOUT_LOW,

    input  wire [9:0]   DOUT_STAGE2_LOW,
    input  wire         CLK_STAGE2_DOUT_LOW,

    // -------------------------------------------------------------------------
    // Digital outputs to the internal analog circuits.
    // Bus notation <7:0> in the schematic is written as [7:0] in Verilog.
    // -------------------------------------------------------------------------
    output wire         EN_TIA_LOW,
    output wire [7:0]   LEDDAC,
    output wire         LEDEN1_LOW,
    output wire         LEDEN2_LOW,
    output wire         EN_TEST,

    output wire         CLK_BUF_LOW,
    output wire         CLK_2M,
    output wire         CLK_IREF_IDAC_LOW,
    output wire         CLK_9Q1_LOW,
    output wire         CLK_15Q1_LOW,
    output wire         CLK_AFERST_LOW,
    output wire         CLK_IREF_IDAC_SAR9_LOW,
    output wire         CLK_IREF_IDAC_SAR15_LOW,
    output wire         CLK_Q2_LOW,
    output wire         CLK_Q3_LOW,
    output wire         CLK_TIAEN_LOW,

    output wire         EN_15SAR_LOW,
    output wire         EN_SAR9_AMB_LOW,
    output wire         EN_SAR9_DC_LOW,
    output wire         EN_SAR9_IREF,
    output wire         EN_SAR15_AMB_LOW,
    output wire         EN_SAR15_DC_LOW,
    output wire         EN_SAR15_IREF,

    output wire [7:0]   IDAC_SAR9AMBN_LOW,
    output wire [7:0]   IDAC_SAR9DCN_LOW,
    output wire [7:0]   IDAC_SAR15AMBN_LOW,
    output wire [7:0]   IDAC_SAR15DCN_LOW,

    output wire         S0_IN,
    output wire         S1_IN,
    output wire         S2_IN,
    output wire         S3_IN,
    output wire         S4_IN
);

    // Black-box shell only.  Timing/control RTL will be implemented later.

endmodule

`default_nettype wire
