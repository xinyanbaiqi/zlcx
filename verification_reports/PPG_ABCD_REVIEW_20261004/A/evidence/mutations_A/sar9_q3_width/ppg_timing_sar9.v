`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/07/16
// Design Name:     PPG SAR9 Timing Controller
// Module Name:     ppg_timing_sar9
// Description:     Synthesizable 9-bit timing aligned to the SAR15 Q3 centers
// Simulations:     tb_ppg_timing_sar9.v
//
// Referrences:     SAR9 Virtuoso clk_sim netlist and PPG timing contract
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/07/18
// History:
//     Time          Version     Revised by     Contents
// 2026/07/16        V1.0        Erie          Create file.
// 2026/07/17        V1.0        Erie          Align R/IR Q3 centers with SAR15.
// 2026/07/18        V1.0        Erie          Add static characterization and test-MUX control.
////////////////////////////////////English///////////////////////////////////////
// Ownership:        Erie
// Developer:        Erie
//
// Creation Date:    2026/07/16
// Design Name:      PPG SAR9 Timing Controller
// Module Name:      ppg_timing_sar9
// Description:      Generates shifted 9-bit timing with common R/IR Q3 centers
// Simulation:       tb_ppg_timing_sar9.v
//
// Reference:        SAR9 Virtuoso clk_sim netlist and PPG timing contract
//
// Dependencies:     None
//
// Current Version:  V1.0
// Revision Date:    2026/07/18
// Revision History:
//     Date          Version     Author         Description
// 2026/07/16        V1.0        Erie           Initial creation
// 2026/07/17        V1.0        Erie           Align Q3 centers to SAR15
// 2026/07/18        V1.0        Erie           Add frame-safe static characterization control

// Complete timing controller for dual-phase 9-bit R/IR sampling
module ppg_timing_sar9
#(
	parameter C_FRAME_TICKS = 13'd5000             // Frame length in 2 MHz clock cycles; 5000 selects the production 400 Hz rate
)
(
	//-------------Global Signals-------------//
	input i_clk,                                      // 2 MHz digital master clock after the input-pad HtoL path
	input i_rstn,                                     // Active-low asynchronous assertion reset with constrained release

	//--------------Mode Control--------------//
	input i_enable,                                   // Enables 9-bit timing and must settle before the earliest setup window
	input i_test_mode,                                // Selects the analog test path and remains stable within a frame
	input [1:0]i_optical_mode,                        // System-clock-domain R/IR selection supplied by the SPI register bridge
	input i_static_characterization_enable,           // Enables the selected static characterization output override
	input [4:0]i_test_mux_ctrl,                       // System-clock-domain S0_IN through S4_IN test-MUX control

	//--------Static IDAC Code Configuration--//
	input [7:0]i_static_sar9_amb_code,                 // Static-characterization SAR9 ambient-cancellation code
	input [7:0]i_static_sar9_dc_code,                  // Static-characterization SAR9 DC-cancellation code
	input [7:0]i_static_sar15_amb_code,                // Static-characterization SAR15 ambient-cancellation code
	input [7:0]i_static_sar15_dc_code,                 // Static-characterization SAR15 DC-cancellation code

	//-----------LED Code Configuration-------//
	input [7:0]i_leddac_r_code,                       // Red-channel LED drive-current code
	input [7:0]i_leddac_ir_code,                      // Infrared-channel LED drive-current code

	//-----------SAR9 IDAC Configuration------//
	input [7:0]i_idac_sar9_amb_r_code,                // Red-channel ambient-cancellation code
	input [7:0]i_idac_sar9_amb_ir_code,               // Infrared-channel ambient-cancellation code
	input [7:0]i_idac_sar9_dc_r_code,                 // Red-channel DC-cancellation code
	input [7:0]i_idac_sar9_dc_ir_code,                // Infrared-channel DC-cancellation code

	//----------Frame Synchronization Output--//
	output o_frame_start_400hz,                       // One-cycle 400 Hz frame-start pulse every 5000 clocks

	//-----------Common Analog Controls-------//
	output o_en_tia_low,                              // Controls the TIA operating window for each optical phase
	output [7:0]o_leddac,                             // LED drive code selected for the active R/IR phase
	output o_leden1_low,                              // Red-channel LED1 operating window
	output o_leden2_low,                              // Infrared-channel LED2 operating window
	output o_en_test,                                 // Registered analog test-mode control
	output o_clk_buf_low,                             // Clock-buffer control enabled only during static characterization
	output o_clk_2m,                                  // Source-aligned 2 MHz clock forwarded to the analog domain
	output o_clk_iref_idac_low,                       // Per-phase R/IR local IDAC-reference timing
	output o_clk_9q1_low,                             // Main Q1 sampling phase for the 9-bit path
	output o_clk_15q1_low,                            // Fixed-off 15-bit Q1 timing in 9-bit mode
	output o_clk_aferst_low,                          // Analog-front-end reset-release window
	output o_clk_iref_idac_sar9_low,                  // SAR9 reference timing spanning overlapping R/IR setup windows
	output o_clk_iref_idac_sar15_low,                 // SAR15 reference held active only during static characterization
	output o_clk_q2_low,                              // One-microsecond ambient-current sampling phase
	output o_clk_q3_low,                              // Dynamic-current sampling phase centered on the SAR15 Q3 time
	output o_clk_tiaen_low,                           // Local TIA-enable timing

	//---------Precision and IDAC Enables-----//
	output o_en_15sar_low,                            // Fixed low to select the complete 9-bit timing system
	output o_en_sar9_amb_low,                         // SAR9 AMB enable asserted separately for each R/IR phase
	output o_en_sar9_dc_low,                          // SAR9 DC enable asserted separately for each R/IR phase
	output o_en_sar9_iref,                            // SAR9 reference enable asserted separately for each R/IR phase
	output o_en_sar15_amb_low,                        // SAR15 AMB enable active only during static characterization
	output o_en_sar15_dc_low,                         // SAR15 DC enable active only during static characterization
	output o_en_sar15_iref,                           // Fixed-off SAR15 reference enable in 9-bit mode

	//-------------IDAC Code Outputs----------//
	output [7:0]o_idac_sar9ambn_low,                  // SAR9 AMB code for the active optical phase
	output [7:0]o_idac_sar9dcn_low,                   // SAR9 DC code for the active optical phase
	output [7:0]o_idac_sar15ambn_low,                 // SAR15 AMB code used only during static characterization
	output [7:0]o_idac_sar15dcn_low,                  // SAR15 DC code used only during static characterization

	//-------------Test Switch Outputs--------//
	output [4:0]o_s_in                                // Frame-latched SPI controls for test switches S0 through S4
);

	//-----------Configuration Parameters----//
	// Common frame and phase references shared with the 15-bit timing system
	localparam [12:0] FRAME_LAST_TICK = C_FRAME_TICKS - 13'd1;        // Last 2 MHz count value in the configured frame
	localparam [12:0] FRAME_PRESTART_TICK = C_FRAME_TICKS - 13'd239;  // Common reset phase 119.5 us before the frame origin
	localparam [12:0] SAR9_PRESTART_TICK = C_FRAME_TICKS - 13'd222;   // Shifted SAR9 reference starts 111 us before the frame
	localparam [12:0] IR_OFFSET_TICK = 13'd160;                       // Infrared phase trails the red phase by 80 us
	localparam [12:0] OPTICAL_MODE_LATCH_TICK = C_FRAME_TICKS - 13'd240; // Captures the optical selection one cycle before the earliest SAR window
	localparam [1:0] OPTICAL_MODE_BOTH = 2'b00;                       // Enables red and infrared optical phases
	localparam [1:0] OPTICAL_MODE_RED_ONLY = 2'b01;                   // Enables only the red optical phase
	localparam [1:0] OPTICAL_MODE_IR_ONLY = 2'b10;                    // Enables only the infrared optical phase
	localparam [1:0] OPTICAL_MODE_RESERVED = 2'b11;                   // Reserved code disables both optical phases safely
	localparam [12:0] R_Q3_CENTER_TICK = 13'd34;                      // Common red Q3 center at 17 us
	localparam [12:0] IR_Q3_CENTER_TICK = R_Q3_CENTER_TICK + IR_OFFSET_TICK; // Common infrared Q3 center at 97 us

	// Red-phase windows preserve the netlist relationships after a seventeen-cycle shift
	localparam [12:0] R_EN_TIA_START = 13'd17;                        // Red TIA window starts at 8.5 us
	localparam [12:0] R_EN_TIA_END = 13'd37;                          // Red TIA window ends at 18.5 us
	localparam [12:0] R_AFERST_START = 13'd17;                        // Red analog-front-end reset starts at 8.5 us
	localparam [12:0] R_AFERST_END = 13'd29;                          // Red analog-front-end reset ends at 14.5 us
	localparam [12:0] R_Q1_START = 13'd27;                            // Red 9Q1 window starts at 13.5 us
	localparam [12:0] R_Q1_END = 13'd36;                              // Red 9Q1 window ends at 18 us
	localparam [12:0] R_Q2_START = 13'd30;                            // Red Q2 window starts at 15 us
	localparam [12:0] R_Q2_END = 13'd32;                              // Red Q2 window ends at 16 us
	localparam [12:0] R_LED_CODE_START = 13'd32;                      // Red LEDDAC window starts at 16 us
	localparam [12:0] R_LED_CODE_END = 13'd35;                        // Red LEDDAC window ends at 17.5 us
	localparam [12:0] R_LED_START = R_Q3_CENTER_TICK - 13'd1;         // Red LED1 and Q3 window starts at 16.5 us
	localparam [12:0] R_LED_END = R_Q3_CENTER_TICK + 13'd2;           // Red LED1 and Q3 window ends at 17.5 us
	localparam [12:0] R_IDAC_CLOCK_START = C_FRAME_TICKS - 13'd3;     // Red local IDAC reference starts 1.5 us before the frame
	localparam [12:0] R_IDAC_CLOCK_END = 13'd37;                      // Red local IDAC reference ends at 18.5 us
	localparam [12:0] R_SAR9_IREF_START = SAR9_PRESTART_TICK;         // Red SAR9 reference clock starts 111 us before the frame
	localparam [12:0] R_SAR9_IREF_END = 13'd52;                       // Red SAR9 reference clock ends at 26 us
	localparam [12:0] R_ENABLE_IREF_START = C_FRAME_TICKS - 13'd30;   // Red SAR9 reference enable starts 15 us before the frame
	localparam [12:0] R_ENABLE_IREF_END = 13'd42;                     // Red SAR9 reference enable ends at 21 us
	localparam [12:0] R_ENABLE_CODE_START = C_FRAME_TICKS - 13'd10;   // Red SAR9 AMB/DC enables start 5 us before the frame
	localparam [12:0] R_ENABLE_CODE_END = 13'd44;                     // Red SAR9 AMB/DC enables end at 22 us
	localparam [12:0] R_IDAC_AMB_START = C_FRAME_TICKS - 13'd8;       // Red AMB code starts settling 4 us before the frame
	localparam [12:0] R_IDAC_AMB_END = 13'd44;                        // Red AMB code ends at 22 us
	localparam [12:0] R_IDAC_DC_START = 13'd0;                        // Red DC code starts at the frame origin after Q3 alignment
	localparam [12:0] R_IDAC_DC_END = 13'd44;                         // Red DC code ends at 22 us

	// Infrared windows reuse every red width with an exact 160-cycle phase shift
	localparam [12:0] IR_EN_TIA_START = R_EN_TIA_START + IR_OFFSET_TICK;           // Infrared TIA window starts at 88.5 us
	localparam [12:0] IR_EN_TIA_END = R_EN_TIA_END + IR_OFFSET_TICK;               // Infrared TIA window ends at 98.5 us
	localparam [12:0] IR_AFERST_START = R_AFERST_START + IR_OFFSET_TICK;           // Infrared analog-front-end reset starts at 88.5 us
	localparam [12:0] IR_AFERST_END = R_AFERST_END + IR_OFFSET_TICK;               // Infrared analog-front-end reset ends at 94.5 us
	localparam [12:0] IR_Q1_START = R_Q1_START + IR_OFFSET_TICK;                   // Infrared 9Q1 window starts at 93.5 us
	localparam [12:0] IR_Q1_END = R_Q1_END + IR_OFFSET_TICK;                       // Infrared 9Q1 window ends at 98 us
	localparam [12:0] IR_Q2_START = R_Q2_START + IR_OFFSET_TICK;                   // Infrared Q2 window starts at 95 us
	localparam [12:0] IR_Q2_END = R_Q2_END + IR_OFFSET_TICK;                       // Infrared Q2 window ends at 96 us
	localparam [12:0] IR_LED_CODE_START = R_LED_CODE_START + IR_OFFSET_TICK;       // Infrared LEDDAC window starts at 96 us
	localparam [12:0] IR_LED_CODE_END = R_LED_CODE_END + IR_OFFSET_TICK;           // Infrared LEDDAC window ends at 97.5 us
	localparam [12:0] IR_LED_START = IR_Q3_CENTER_TICK - 13'd1;                    // Infrared LED2 and Q3 window starts at 96.5 us
	localparam [12:0] IR_LED_END = IR_Q3_CENTER_TICK + 13'd1;                      // Infrared LED2 and Q3 window ends at 97.5 us
	localparam [12:0] IR_IDAC_CLOCK_START = 13'd157;                               // Infrared local IDAC reference starts at 78.5 us
	localparam [12:0] IR_IDAC_CLOCK_END = 13'd197;                                 // Infrared local IDAC reference ends at 98.5 us
	localparam [12:0] IR_SAR9_IREF_START = C_FRAME_TICKS - 13'd62;                  // Infrared SAR9 reference begins 31 us before the frame
	localparam [12:0] IR_SAR9_IREF_END = 13'd212;                                  // Infrared SAR9 reference ends at 106 us
	localparam [12:0] IR_ENABLE_IREF_START = 13'd130;                               // Infrared SAR9 reference enable starts at 65 us
	localparam [12:0] IR_ENABLE_IREF_END = 13'd202;                                 // Infrared SAR9 reference enable ends at 101 us
	localparam [12:0] IR_ENABLE_CODE_START = 13'd150;                               // Infrared SAR9 AMB/DC enables start at 75 us
	localparam [12:0] IR_ENABLE_CODE_END = 13'd204;                                 // Infrared SAR9 AMB/DC enables end at 102 us
	localparam [12:0] IR_IDAC_AMB_START = 13'd152;                                  // Infrared AMB code starts settling at 76 us
	localparam [12:0] IR_IDAC_AMB_END = 13'd204;                                    // Infrared AMB code ends at 102 us
	localparam [12:0] IR_IDAC_DC_START = 13'd160;                                   // Infrared DC code starts settling at 80 us
	localparam [12:0] IR_IDAC_DC_END = 13'd204;                                     // Infrared DC code ends at 102 us

	// Frame-latched data-bus layout
	localparam integer CODE_SNAPSHOT_WIDTH = 32'd48;                    // Total width of six latched 8-bit R/IR configuration codes
	localparam integer CODE_LED_R_LSB = 32'd0;                          // Least-significant bit of the red LEDDAC snapshot field
	localparam integer CODE_LED_R_MSB = 32'd7;                          // Most-significant bit of the red LEDDAC snapshot field
	localparam integer CODE_LED_IR_LSB = 32'd8;                         // Least-significant bit of the infrared LEDDAC snapshot field
	localparam integer CODE_LED_IR_MSB = 32'd15;                        // Most-significant bit of the infrared LEDDAC snapshot field
	localparam integer CODE_AMB_R_LSB = 32'd16;                         // Least-significant bit of the red AMB snapshot field
	localparam integer CODE_AMB_R_MSB = 32'd23;                         // Most-significant bit of the red AMB snapshot field
	localparam integer CODE_AMB_IR_LSB = 32'd24;                        // Least-significant bit of the infrared AMB snapshot field
	localparam integer CODE_AMB_IR_MSB = 32'd31;                        // Most-significant bit of the infrared AMB snapshot field
	localparam integer CODE_DC_R_LSB = 32'd32;                          // Least-significant bit of the red DC snapshot field
	localparam integer CODE_DC_R_MSB = 32'd39;                          // Most-significant bit of the red DC snapshot field
	localparam integer CODE_DC_IR_LSB = 32'd40;                         // Least-significant bit of the infrared DC snapshot field
	localparam integer CODE_DC_IR_MSB = 32'd47;                         // Most-significant bit of the infrared DC snapshot field

	// Static-characterization IDAC-code snapshot layout
	localparam integer STATIC_CODE_SNAPSHOT_WIDTH = 32'd32;             // Total width of all four static IDAC configuration codes
	localparam integer STATIC_SAR9_AMB_LSB = 32'd0;                     // Least-significant bit of the static SAR9 AMB field
	localparam integer STATIC_SAR9_AMB_MSB = 32'd7;                     // Most-significant bit of the static SAR9 AMB field
	localparam integer STATIC_SAR9_DC_LSB = 32'd8;                      // Least-significant bit of the static SAR9 DC field
	localparam integer STATIC_SAR9_DC_MSB = 32'd15;                     // Most-significant bit of the static SAR9 DC field
	localparam integer STATIC_SAR15_AMB_LSB = 32'd16;                   // Least-significant bit of the static SAR15 AMB field
	localparam integer STATIC_SAR15_AMB_MSB = 32'd23;                   // Most-significant bit of the static SAR15 AMB field
	localparam integer STATIC_SAR15_DC_LSB = 32'd24;                    // Least-significant bit of the static SAR15 DC field
	localparam integer STATIC_SAR15_DC_MSB = 32'd31;                    // Most-significant bit of the static SAR15 DC field

	// Registered analog-control vector layout
	localparam integer CONTROL_WIDTH = 32'd40;                          // Registered width of all dynamic analog-control outputs
	localparam integer CTRL_FRAME_START = 32'd0;                        // Position of the 400 Hz frame-start flag
	localparam integer CTRL_EN_TIA = 32'd1;                             // Position of the TIA operating control
	localparam integer CTRL_LEDDAC_LSB = 32'd2;                         // Least-significant bit of the LEDDAC output field
	localparam integer CTRL_LEDDAC_MSB = 32'd9;                         // Most-significant bit of the LEDDAC output field
	localparam integer CTRL_LEDEN1 = 32'd10;                            // Position of the red LED1 enable
	localparam integer CTRL_LEDEN2 = 32'd11;                            // Position of the infrared LED2 enable
	localparam integer CTRL_CLK_IREF_IDAC = 32'd12;                     // Position of the local IDAC-reference timing
	localparam integer CTRL_CLK_IREF_LED = 32'd13;                      // Position of the LED-reference timing
	localparam integer CTRL_CLK_9Q1 = 32'd14;                           // Position of the 9-bit Q1 phase
	localparam integer CTRL_CLK_AFERST = 32'd15;                        // Position of the analog-front-end reset phase
	localparam integer CTRL_CLK_IREF_SAR9 = 32'd16;                     // Position of the SAR9-reference timing
	localparam integer CTRL_CLK_Q2 = 32'd17;                            // Position of the Q2 phase
	localparam integer CTRL_CLK_Q3 = 32'd18;                            // Position of the Q3 phase
	localparam integer CTRL_CLK_TIAEN = 32'd19;                         // Position of the local TIA enable
	localparam integer CTRL_EN_SAR9_AMB = 32'd20;                       // Position of the SAR9 AMB enable
	localparam integer CTRL_EN_SAR9_DC = 32'd21;                        // Position of the SAR9 DC enable
	localparam integer CTRL_EN_SAR9_IREF = 32'd22;                      // Position of the SAR9 IREF enable
	localparam integer CTRL_IDAC_AMB_LSB = 32'd23;                      // Least-significant bit of the SAR9 AMB-code output field
	localparam integer CTRL_IDAC_AMB_MSB = 32'd30;                      // Most-significant bit of the SAR9 AMB-code output field
	localparam integer CTRL_IDAC_DC_LSB = 32'd31;                       // Least-significant bit of the SAR9 DC-code output field
	localparam integer CTRL_IDAC_DC_MSB = 32'd38;                       // Most-significant bit of the SAR9 DC-code output field
	localparam integer CTRL_EN_TEST = 32'd39;                           // Position of the analog test-mode output

	//---------------Counter Signals---------//
	// Reset uses the common frame phase so SAR9 and SAR15 counters remain interchangeable
	reg [12:0]cnt_frame;                                                // Modulo-5000 frame counter in the 2 MHz domain

	//--------------Register Signals---------//
	// Six codes are latched before the earliest active SAR9 settling window
	reg [CODE_SNAPSHOT_WIDTH - 1:0]reg_code_snapshot;                   // LEDDAC and IDAC code snapshot used by the current R/IR frame
	reg [1:0]reg_optical_mode;                                           // Frame-safe optical phase selection used by all timing decodes
	reg reg_static_characterization_enable;                              // Frame-safe static characterization override enable
	reg [STATIC_CODE_SNAPSHOT_WIDTH - 1:0]reg_static_code_snapshot;       // Frame-safe static IDAC codes with a zero reset value
	reg [4:0]reg_test_mux_ctrl;                                          // Frame-safe test-MUX control vector
	reg reg_frontend_test_select;                                        // Synchronous photodiode or ideal-current-source selection
	reg [CONTROL_WIDTH - 1:0]reg_control_next;                          // Next analog-control vector decoded from the frame counter

	// Optical phase enables are decoded only from the frame-latched mode register
	wire flag_red_phase_enabled;                                         // High when the current frame includes the red phase
	wire flag_ir_phase_enabled;                                          // High when the current frame includes the infrared phase

	//---------------Output Signals----------//
	// Dynamic controls are registered before the analog boundary to suppress decode glitches
	reg [CONTROL_WIDTH - 1:0]control_o;                                 // Registered analog-control output bus

	//-------------Output Signal Wiring------//
	// Frame and common analog-control bridges
	assign o_frame_start_400hz = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_FRAME_START]; // Suppresses frame pulses during static characterization
	assign o_en_tia_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_EN_TIA]; // Keeps the TIA off during static characterization
	assign o_leddac = reg_static_characterization_enable ? 8'h00 : control_o[CTRL_LEDDAC_MSB:CTRL_LEDDAC_LSB]; // Forces LEDDAC to zero during static characterization
	assign o_leden1_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_LEDEN1]; // Keeps LED1 off during static characterization
	assign o_leden2_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_LEDEN2]; // Keeps LED2 off during static characterization
	assign o_en_test = reg_frontend_test_select;                         // Preserves the independent registered frontend-source selection
	assign o_clk_buf_low = reg_static_characterization_enable ? 1'b1 : 1'b0; // Enables the buffer during static characterization
	assign o_clk_2m = i_clk;                                           // Logically forwards 2 MHz in phase to the analog domain
	assign o_clk_iref_idac_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_IREF_IDAC]; // Resets the local phase IDAC clock during static characterization
	assign o_clk_9q1_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_9Q1]; // Resets SAR9 Q1 during static characterization
	assign o_clk_15q1_low = 1'b0;                                      // Prevents 15-bit Q1 activity in 9-bit mode
	assign o_clk_aferst_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_AFERST]; // Resets the analog-front-end reset clock during static characterization
	assign o_clk_iref_idac_sar9_low = reg_static_characterization_enable ? 1'b1 : control_o[CTRL_CLK_IREF_SAR9]; // Holds the SAR9 IREF clock active for static characterization
	assign o_clk_iref_idac_sar15_low = reg_static_characterization_enable ? 1'b1 : 1'b0; // Holds the SAR15 IREF clock active for static characterization
	assign o_clk_q2_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_Q2]; // Resets Q2 during static characterization
	assign o_clk_q3_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_Q3]; // Resets Q3 during static characterization
	assign o_clk_tiaen_low = reg_static_characterization_enable ? 1'b1 : control_o[CTRL_CLK_TIAEN]; // Holds the TIA-enable timing path active for static characterization

	// Precision-mode and IDAC-control bridges
	assign o_en_15sar_low = 1'b0;                                      // Keeps the precision selector low during both normal 9-bit and static characterization operation
	assign o_en_sar9_amb_low = reg_static_characterization_enable ? 1'b1 : control_o[CTRL_EN_SAR9_AMB]; // Holds SAR9 AMB active for static characterization
	assign o_en_sar9_dc_low = reg_static_characterization_enable ? 1'b1 : control_o[CTRL_EN_SAR9_DC]; // Holds SAR9 DC active for static characterization
	assign o_en_sar9_iref = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_EN_SAR9_IREF]; // Resets the SAR9 IREF enable only during static characterization
	assign o_en_sar15_amb_low = reg_static_characterization_enable ? 1'b1 : 1'b0; // Holds SAR15 AMB active for static characterization
	assign o_en_sar15_dc_low = reg_static_characterization_enable ? 1'b1 : 1'b0; // Holds SAR15 DC active for static characterization
	assign o_en_sar15_iref = 1'b0;                                     // Disables the SAR15 reference branch in 9-bit mode
	assign o_idac_sar9ambn_low = reg_static_characterization_enable ? reg_static_code_snapshot[STATIC_SAR9_AMB_MSB:STATIC_SAR9_AMB_LSB] : control_o[CTRL_IDAC_AMB_MSB:CTRL_IDAC_AMB_LSB]; // Selects the static or timed SAR9 AMB code
	assign o_idac_sar9dcn_low = reg_static_characterization_enable ? reg_static_code_snapshot[STATIC_SAR9_DC_MSB:STATIC_SAR9_DC_LSB] : control_o[CTRL_IDAC_DC_MSB:CTRL_IDAC_DC_LSB]; // Selects the static or timed SAR9 DC code
	assign o_idac_sar15ambn_low = reg_static_characterization_enable ? reg_static_code_snapshot[STATIC_SAR15_AMB_MSB:STATIC_SAR15_AMB_LSB] : 8'h00; // Applies the SAR15 AMB code only during static characterization
	assign o_idac_sar15dcn_low = reg_static_characterization_enable ? reg_static_code_snapshot[STATIC_SAR15_DC_MSB:STATIC_SAR15_DC_LSB] : 8'h00; // Applies the SAR15 DC code only during static characterization
	assign o_s_in = reg_test_mux_ctrl;                                 // Exposes the frame-latched SPI test-MUX control in every operating mode
	assign flag_red_phase_enabled = (reg_optical_mode == OPTICAL_MODE_BOTH) ||
		(reg_optical_mode == OPTICAL_MODE_RED_ONLY);                     // Decodes red-phase permission without using asynchronous SPI data
	assign flag_ir_phase_enabled = (reg_optical_mode == OPTICAL_MODE_BOTH) ||
		(reg_optical_mode == OPTICAL_MODE_IR_ONLY);                      // Decodes infrared-phase permission without using asynchronous SPI data

	//-----------Output Signal Processing----//
	// Registers every dynamic analog control so it changes only on active 2 MHz edges
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			control_o <= {CONTROL_WIDTH{1'b0}};                             // Disables all dynamic analog controls during reset
		end else begin
			control_o <= reg_control_next;                                 // Commits the complete glitch-free control vector each cycle
		end
	end

	// Registers the frontend source selection independently from timing and characterization modes
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_frontend_test_select <= 1'b0;                              // Selects the photodiode frontend after reset
		end else begin
			reg_frontend_test_select <= i_test_mode;                       // Selects the SPI-configured frontend source on a 2 MHz edge
		end
	end

	// Latches the static characterization request at the same frame-safe boundary as optical mode
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_static_characterization_enable <= 1'b0;                       // Returns to normal intermittent timing after reset
		end else if(cnt_frame == OPTICAL_MODE_LATCH_TICK)begin
			reg_static_characterization_enable <= i_static_characterization_enable; // Applies the SPI request only at a frame boundary
		end else begin
			reg_static_characterization_enable <= reg_static_characterization_enable; // Holds characterization state for the complete frame
		end
	end

	// Latches all static IDAC codes at the characterization-mode boundary
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_static_code_snapshot <= {STATIC_CODE_SNAPSHOT_WIDTH{1'b0}}; // Resets all four static IDAC codes to zero
		end else if(cnt_frame == OPTICAL_MODE_LATCH_TICK)begin
			reg_static_code_snapshot <= {i_static_sar15_dc_code, i_static_sar15_amb_code,
				i_static_sar9_dc_code, i_static_sar9_amb_code};                 // Captures an atomic SPI-programmed static-code vector
		end else begin
			reg_static_code_snapshot <= reg_static_code_snapshot;             // Holds the static codes until the next safe boundary
		end
	end

	// Latches the test-MUX vector so SPI updates cannot switch analog nodes mid-frame
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_test_mux_ctrl <= 5'b00000;                                  // Resets every test-MUX switch to its safe state
		end else if(cnt_frame == OPTICAL_MODE_LATCH_TICK)begin
			reg_test_mux_ctrl <= i_test_mux_ctrl;                            // Applies the SPI test-MUX request at a frame boundary
		end else begin
			reg_test_mux_ctrl <= reg_test_mux_ctrl;                          // Holds the selected test path for the complete frame
		end
	end

	//-----------Main Processing-------------//
	// The configured frame counter runs continuously regardless of the active precision mode
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_frame <= OPTICAL_MODE_LATCH_TICK;                            // Starts one cycle before the first mode latch and SAR setup window
		end else if(cnt_frame == FRAME_LAST_TICK)begin
			cnt_frame <= 13'd0;                                            // Returns to the red-frame origin after C_FRAME_TICKS cycles
		end else begin
			cnt_frame <= cnt_frame + 13'd1;                                // Advances one 0.5 us slot on each master-clock edge
		end
	end

	// Latches a validated optical mode before any red or infrared setup window begins
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_optical_mode <= OPTICAL_MODE_BOTH;                          // Preserves the historical red-plus-infrared default after reset
		end else if(cnt_frame == OPTICAL_MODE_LATCH_TICK)begin
			case(i_optical_mode)
				OPTICAL_MODE_BOTH:begin
					reg_optical_mode <= OPTICAL_MODE_BOTH;                      // Accepts the combined optical mode
				end
				OPTICAL_MODE_RED_ONLY:begin
					reg_optical_mode <= OPTICAL_MODE_RED_ONLY;                  // Accepts the red-only optical mode
				end
				OPTICAL_MODE_IR_ONLY:begin
					reg_optical_mode <= OPTICAL_MODE_IR_ONLY;                   // Accepts the infrared-only optical mode
				end
				default:begin
					reg_optical_mode <= OPTICAL_MODE_RESERVED;                  // Forces an unassigned code to the safe optical-off mode
				end
			endcase
		end else begin
			reg_optical_mode <= reg_optical_mode;                            // Holds the selected mode for the complete 400 Hz frame
		end
	end

	// Atomically latches this frame's R/IR codes before the shifted SAR9 reference starts
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_code_snapshot <= {CODE_SNAPSHOT_WIDTH{1'b0}};              // Clears every programmable current code during reset
		end else if(cnt_frame == FRAME_PRESTART_TICK)begin
			reg_code_snapshot <= {i_idac_sar9_dc_ir_code, i_idac_sar9_dc_r_code,
				i_idac_sar9_amb_ir_code, i_idac_sar9_amb_r_code,
				i_leddac_ir_code, i_leddac_r_code};                           // Latches all six codes before the earliest setup edge
		end else begin
			reg_code_snapshot <= reg_code_snapshot;                        // Holds the codes for a full frame despite configuration updates
		end
	end

	// Decodes the frame counter into right-open windows that drive only the output register
	always@(*)begin
		reg_control_next = {CONTROL_WIDTH{1'b0}};                         // Defaults all controls off while disabled or outside active windows
		if(i_enable == 1'b1)begin
			reg_control_next[CTRL_FRAME_START] = (cnt_frame == 13'd0);      // Generates one frame pulse at the red-phase origin
			reg_control_next[CTRL_EN_TEST] = i_test_mode;                   // Passes the current test mode synchronously

			reg_control_next[CTRL_EN_TIA] =
				(flag_red_phase_enabled && (cnt_frame >= R_EN_TIA_START) && (cnt_frame < R_EN_TIA_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_EN_TIA_START) && (cnt_frame < IR_EN_TIA_END)); // Selects only the configured TIA operating windows
			reg_control_next[CTRL_CLK_TIAEN] =
				(flag_red_phase_enabled && (cnt_frame >= R_EN_TIA_START) && (cnt_frame < R_EN_TIA_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_EN_TIA_START) && (cnt_frame < IR_EN_TIA_END)); // Selects only the configured local TIA-enable windows
			reg_control_next[CTRL_CLK_AFERST] =
				(flag_red_phase_enabled && (cnt_frame >= R_AFERST_START) && (cnt_frame < R_AFERST_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_AFERST_START) && (cnt_frame < IR_AFERST_END)); // Selects only the configured analog-front-end reset windows
			reg_control_next[CTRL_CLK_9Q1] =
				(flag_red_phase_enabled && (cnt_frame >= R_Q1_START) && (cnt_frame < R_Q1_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_Q1_START) && (cnt_frame < IR_Q1_END)); // Selects only the configured shifted 9-bit Q1 windows
			reg_control_next[CTRL_CLK_Q2] =
				(flag_red_phase_enabled && (cnt_frame >= R_Q2_START) && (cnt_frame < R_Q2_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_Q2_START) && (cnt_frame < IR_Q2_END)); // Selects only the configured ambient-current Q2 windows
			reg_control_next[CTRL_CLK_Q3] =
				(flag_red_phase_enabled && (cnt_frame >= R_LED_START) && (cnt_frame < R_LED_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_LED_START) && (cnt_frame < IR_LED_END)); // Selects Q3 while preserving both cross-precision sample centers
			reg_control_next[CTRL_CLK_IREF_LED] =
				(flag_red_phase_enabled && (cnt_frame >= R_LED_CODE_START) && (cnt_frame < R_LED_CODE_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_LED_CODE_START) && (cnt_frame < IR_LED_CODE_END)); // Selects only the configured LED-reference setup windows
			reg_control_next[CTRL_CLK_IREF_IDAC] =
				(flag_red_phase_enabled && ((cnt_frame >= R_IDAC_CLOCK_START) || (cnt_frame < R_IDAC_CLOCK_END))) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_IDAC_CLOCK_START) && (cnt_frame < IR_IDAC_CLOCK_END)); // Selects only the configured local IDAC-reference windows

			reg_control_next[CTRL_CLK_IREF_SAR9] =
				(flag_red_phase_enabled && ((cnt_frame >= R_SAR9_IREF_START) || (cnt_frame < R_SAR9_IREF_END))) ||
				(flag_ir_phase_enabled && ((cnt_frame >= IR_SAR9_IREF_START) || (cnt_frame < IR_SAR9_IREF_END))); // Merges only the enabled SAR9-reference intervals
			reg_control_next[CTRL_EN_SAR9_IREF] =
				(flag_red_phase_enabled && ((cnt_frame >= R_ENABLE_IREF_START) || (cnt_frame < R_ENABLE_IREF_END))) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_ENABLE_IREF_START) && (cnt_frame < IR_ENABLE_IREF_END)); // Selects the independent SAR9-reference enable windows
			reg_control_next[CTRL_EN_SAR9_AMB] =
				(flag_red_phase_enabled && ((cnt_frame >= R_ENABLE_CODE_START) || (cnt_frame < R_ENABLE_CODE_END))) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_ENABLE_CODE_START) && (cnt_frame < IR_ENABLE_CODE_END)); // Selects the independent AMB-enable windows
			reg_control_next[CTRL_EN_SAR9_DC] =
				(flag_red_phase_enabled && ((cnt_frame >= R_ENABLE_CODE_START) || (cnt_frame < R_ENABLE_CODE_END))) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_ENABLE_CODE_START) && (cnt_frame < IR_ENABLE_CODE_END)); // Selects the independent DC-enable windows

			if(flag_red_phase_enabled && (cnt_frame >= R_LED_CODE_START) && (cnt_frame < R_LED_CODE_END))begin
				reg_control_next[CTRL_LEDDAC_MSB:CTRL_LEDDAC_LSB] =
					reg_code_snapshot[CODE_LED_R_MSB:CODE_LED_R_LSB];             // Drives the latched LED1 current code during the red window
			end else if(flag_ir_phase_enabled && (cnt_frame >= IR_LED_CODE_START) && (cnt_frame < IR_LED_CODE_END))begin
				reg_control_next[CTRL_LEDDAC_MSB:CTRL_LEDDAC_LSB] =
					reg_code_snapshot[CODE_LED_IR_MSB:CODE_LED_IR_LSB];           // Drives the latched LED2 current code during the infrared window
			end

			reg_control_next[CTRL_LEDEN1] =
				flag_red_phase_enabled && (cnt_frame >= R_LED_START) && (cnt_frame < R_LED_END); // Enables LED1 only when the selected mode includes red
			reg_control_next[CTRL_LEDEN2] =
				flag_ir_phase_enabled && (cnt_frame >= IR_LED_START) && (cnt_frame < IR_LED_END); // Enables LED2 only when the selected mode includes infrared

			if(flag_red_phase_enabled && ((cnt_frame >= R_IDAC_AMB_START) || (cnt_frame < R_IDAC_AMB_END)))begin
				reg_control_next[CTRL_IDAC_AMB_MSB:CTRL_IDAC_AMB_LSB] =
					reg_code_snapshot[CODE_AMB_R_MSB:CODE_AMB_R_LSB];             // Holds the AMB code during red settling and conversion
			end else if(flag_ir_phase_enabled && (cnt_frame >= IR_IDAC_AMB_START) && (cnt_frame < IR_IDAC_AMB_END))begin
				reg_control_next[CTRL_IDAC_AMB_MSB:CTRL_IDAC_AMB_LSB] =
					reg_code_snapshot[CODE_AMB_IR_MSB:CODE_AMB_IR_LSB];           // Holds the AMB code during infrared settling and conversion
			end

			if(flag_red_phase_enabled && (cnt_frame >= R_IDAC_DC_START) && (cnt_frame < R_IDAC_DC_END))begin
				reg_control_next[CTRL_IDAC_DC_MSB:CTRL_IDAC_DC_LSB] =
					reg_code_snapshot[CODE_DC_R_MSB:CODE_DC_R_LSB];               // Holds the DC code during red settling and conversion
			end else if(flag_ir_phase_enabled && (cnt_frame >= IR_IDAC_DC_START) && (cnt_frame < IR_IDAC_DC_END))begin
				reg_control_next[CTRL_IDAC_DC_MSB:CTRL_IDAC_DC_LSB] =
					reg_code_snapshot[CODE_DC_IR_MSB:CODE_DC_IR_LSB];             // Holds the DC code during infrared settling and conversion
			end
		end
	end

endmodule
