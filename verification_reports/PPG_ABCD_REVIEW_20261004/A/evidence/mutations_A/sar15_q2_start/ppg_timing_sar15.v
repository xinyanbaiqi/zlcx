`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/07/16
// Design Name:     PPG SAR15 Timing Controller
// Module Name:     ppg_timing_sar15
// Description:     Synthesizable 15-bit R/IR sampling timing controller
// Simulations:     tb_ppg_timing_sar15.v
//
// Referrences:     ../ppg_system_integration/PPG_NEW_CHAT_CONTEXT.md
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/07/18
// History:
//     Time          Version     Revised by     Contents
// 2026/07/16        V1.0        Erie          Create file.
// 2026/07/18        V1.0        Erie          Add static characterization and test-MUX control.
//////////////////////////////////English/////////////////////////////////////////
// Ownership:        Erie
// Developer:        Erie
//
// Creation Date:    2026/07/16
// Design Name:      PPG SAR15 Timing Controller
// Module Name:      ppg_timing_sar15
// Description:      Generates synthesizable control timing for 15-bit R/IR sampling
// Simulation:       tb_ppg_timing_sar15.v
//
// Reference:        ../ppg_system_integration/PPG_NEW_CHAT_CONTEXT.md
//
// Dependencies:     None
//
// Current Version:  V1.0
// Revision Date:    2026/07/18
// Revision History:
//     Date          Version     Author         Description
// 2026/07/16        V1.0        Erie           Initial creation
// 2026/07/18        V1.0        Erie           Add frame-safe static characterization control

// Core timing controller for dual-phase 15-bit R/IR sampling
module ppg_timing_sar15
#(
	parameter C_FRAME_TICKS = 13'd5000             // Frame length in 2 MHz clock cycles; 5000 selects the production 400 Hz rate
)
(
	//-------------Global Signals-------------//
	input i_clk,                                      // 2 MHz digital master clock after the input-pad HtoL path
	input i_rstn,                                     // Active-low asynchronous assertion reset with constrained release

	//--------------Mode Control--------------//
	input i_enable,                                   // Enables 15-bit timing and must settle before the precharge window
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

	//----------SAR15 IDAC Configuration------//
	input [7:0]i_idac_sar15_amb_r_code,               // Red-channel ambient-cancellation code
	input [7:0]i_idac_sar15_amb_ir_code,              // Infrared-channel ambient-cancellation code
	input [7:0]i_idac_sar15_dc_r_code,                // Red-channel DC-cancellation code
	input [7:0]i_idac_sar15_dc_ir_code,               // Infrared-channel DC-cancellation code

	//----------Frame Synchronization Output--//
	output o_frame_start_400hz,                       // One-cycle 400 Hz frame-start pulse every 5000 clocks

	//-----------Common Analog Controls-------//
	output o_en_tia_low,                              // Controls the TIA operating window
	output [7:0]o_leddac,                             // LED drive code selected for the active R/IR phase
	output o_leden1_low,                              // Red-channel LED1 operating window
	output o_leden2_low,                              // Infrared-channel LED2 operating window
	output o_en_test,                                 // Registered analog test-mode control
	output o_clk_buf_low,                             // Clock-buffer control enabled only during static characterization
	output o_clk_2m,                                  // Source-aligned 2 MHz clock forwarded to the analog domain
	output o_clk_iref_idac_low,                       // Per-phase R/IR local IDAC-reference timing
	output o_clk_9q1_low,                             // Fixed-off 9-bit Q1 timing in 15-bit mode
	output o_clk_15q1_low,                            // Main Q1 sampling phase for the 15-bit path
	output o_clk_aferst_low,                          // Analog-front-end reset-release window
	output o_clk_iref_idac_sar9_low,                  // SAR9 reference held active only during static characterization
	output o_clk_iref_idac_sar15_low,                 // SAR15 reference timing held across R/IR phases
	output o_clk_q2_low,                              // Q2 control phase for 15-bit sampling
	output o_clk_q3_low,                              // Q3 control phase for 15-bit sampling
	output o_clk_tiaen_low,                           // Local TIA-enable timing

	//---------Precision and IDAC Enables-----//
	output o_en_15sar_low,                            // High level selects the complete 15-bit timing system
	output o_en_sar9_amb_low,                         // SAR9 AMB enable active only during static characterization
	output o_en_sar9_dc_low,                          // SAR9 DC enable active only during static characterization
	output o_en_sar9_iref,                            // Fixed-off SAR9 reference enable in 15-bit mode
	output o_en_sar15_amb_low,                        // SAR15 AMB enable held across R/IR phases
	output o_en_sar15_dc_low,                         // SAR15 DC enable held across R/IR phases
	output o_en_sar15_iref,                           // SAR15 reference enable held across R/IR phases

	//-------------IDAC Code Outputs----------//
	output [7:0]o_idac_sar9ambn_low,                  // SAR9 AMB code used only during static characterization
	output [7:0]o_idac_sar9dcn_low,                   // SAR9 DC code used only during static characterization
	output [7:0]o_idac_sar15ambn_low,                 // SAR15 AMB code for the active optical phase
	output [7:0]o_idac_sar15dcn_low,                  // SAR15 DC code for the active optical phase

	//-------------Test Switch Outputs--------//
	output [4:0]o_s_in                                // Frame-latched SPI controls for test switches S0 through S4
);

	//-----------Configuration Parameters----//
	// Frame count and R/IR phase references
	localparam [12:0] FRAME_LAST_TICK = C_FRAME_TICKS - 13'd1;       // Last 2 MHz count value in the configured frame
	localparam [12:0] PRESTART_TICK = C_FRAME_TICKS - 13'd239;       // SAR15 shared-reference start 119.5 us before the frame
	localparam [12:0] IR_OFFSET_TICK = 13'd160;       // Infrared phase trails the red phase by 80 us
	localparam [12:0] OPTICAL_MODE_LATCH_TICK = C_FRAME_TICKS - 13'd240; // Captures the optical selection one cycle before the earliest SAR15 window
	localparam [1:0] OPTICAL_MODE_BOTH = 2'b00;       // Enables red and infrared optical phases
	localparam [1:0] OPTICAL_MODE_RED_ONLY = 2'b01;   // Enables only the red optical phase
	localparam [1:0] OPTICAL_MODE_IR_ONLY = 2'b10;    // Enables only the infrared optical phase
	localparam [1:0] OPTICAL_MODE_RESERVED = 2'b11;   // Reserved code disables both optical phases safely

	// Red-phase windows use right-open end points
	localparam [12:0] R_EN_TIA_END = 13'd39;          // Red TIA window ends at 19.5 us
	localparam [12:0] R_AFERST_END = 13'd20;          // Red analog-front-end reset window ends at 10 us
	localparam [12:0] R_Q1_START = 13'd18;            // Red 15Q1 window starts at 9 us
	localparam [12:0] R_Q1_END = 13'd39;              // Red 15Q1 window ends at 19.5 us
	localparam [12:0] R_Q2_START = 13'd22;            // Red Q2 window starts at 10.5 us
	localparam [12:0] R_Q2_END = 13'd29;              // Red Q2 window ends at 14.5 us
	localparam [12:0] R_LED_CODE_START = 13'd29;      // Red LEDDAC window starts at 14.5 us
	localparam [12:0] R_LED_CODE_END = 13'd38;        // Red LEDDAC window ends at 19 us
	localparam [12:0] R_LED_START = 13'd30;           // Red LED1 window starts at 15 us
	localparam [12:0] R_LED_END = 13'd38;             // Red LED1 window ends at 19 us
	localparam [12:0] R_IDAC_CLOCK_START = C_FRAME_TICKS - 13'd20;   // Red IDAC reference starts 10 us before the frame
	localparam [12:0] R_IDAC_CLOCK_END = 13'd40;      // Red IDAC reference ends at 20 us
	localparam [12:0] R_IDAC_DC_START = C_FRAME_TICKS - 13'd115;     // Red DC code settles from 57.5 us before the frame
	localparam [12:0] R_IDAC_AMB_START = C_FRAME_TICKS - 13'd63;     // Red AMB code settles from 31.5 us before the frame
	localparam [12:0] R_IDAC_CODE_END = 13'd42;       // Red cancellation codes end at 21 us

	// Infrared phase reuses each window width with a 160-cycle shift
	localparam [12:0] IR_EN_TIA_START = IR_OFFSET_TICK;                  // Infrared TIA window starts at 80 us
	localparam [12:0] IR_EN_TIA_END = IR_OFFSET_TICK + 13'd39;          // Infrared TIA window ends at 99.5 us
	localparam [12:0] IR_AFERST_START = IR_OFFSET_TICK;                  // Infrared analog-front-end reset starts at 80 us
	localparam [12:0] IR_AFERST_END = IR_OFFSET_TICK + 13'd20;          // Infrared analog-front-end reset ends at 90 us
	localparam [12:0] IR_Q1_START = IR_OFFSET_TICK + 13'd18;            // Infrared 15Q1 window starts at 89 us
	localparam [12:0] IR_Q1_END = IR_OFFSET_TICK + 13'd39;              // Infrared 15Q1 window ends at 99.5 us
	localparam [12:0] IR_Q2_START = IR_OFFSET_TICK + 13'd21;            // Infrared Q2 window starts at 90.5 us
	localparam [12:0] IR_Q2_END = IR_OFFSET_TICK + 13'd29;              // Infrared Q2 window ends at 94.5 us
	localparam [12:0] IR_LED_CODE_START = IR_OFFSET_TICK + 13'd29;      // Infrared LEDDAC window starts at 94.5 us
	localparam [12:0] IR_LED_CODE_END = IR_OFFSET_TICK + 13'd38;        // Infrared LEDDAC window ends at 99 us
	localparam [12:0] IR_LED_START = IR_OFFSET_TICK + 13'd30;           // Infrared LED2 window starts at 95 us
	localparam [12:0] IR_LED_END = IR_OFFSET_TICK + 13'd38;             // Infrared LED2 window ends at 99 us
	localparam [12:0] IR_IDAC_CLOCK_START = IR_OFFSET_TICK - 13'd20;    // Infrared IDAC reference restarts at 70 us
	localparam [12:0] IR_IDAC_CLOCK_END = IR_OFFSET_TICK + 13'd40;      // Infrared IDAC reference ends at 100 us
	localparam [12:0] IR_IDAC_DC_START = IR_OFFSET_TICK - 13'd115;      // Infrared DC code starts settling at 22.5 us
	localparam [12:0] IR_IDAC_AMB_START = IR_OFFSET_TICK - 13'd63;      // Infrared AMB code starts settling at 48.5 us
	localparam [12:0] IR_IDAC_CODE_END = IR_OFFSET_TICK + 13'd42;       // Infrared cancellation codes end at 101 us

	// SAR15 shared controls are expressed as per-phase windows so each optical mode remains selectable
	localparam [12:0] R_SHARED_IREF_START = C_FRAME_TICKS - 13'd239;    // Red shared IREF controls start 119.5 us before the frame
	localparam [12:0] R_SHARED_ENABLE_START = C_FRAME_TICKS - 13'd219;  // Red AMB/DC enables start 109.5 us before the frame
	localparam [12:0] R_SHARED_IREF_END = 13'd40;                       // Red SAR15 IREF enable ends at 20 us
	localparam [12:0] R_SHARED_CONTROL_END = 13'd42;                    // Red shared clock and cancellation enables end at 21 us
	localparam [12:0] IR_SHARED_IREF_START = C_FRAME_TICKS - 13'd79;    // Infrared shared IREF controls start 39.5 us before the frame
	localparam [12:0] IR_SHARED_ENABLE_START = C_FRAME_TICKS - 13'd59;  // Infrared AMB/DC enables start 29.5 us before the frame
	localparam [12:0] IR_SHARED_IREF_END = IR_OFFSET_TICK + 13'd40;     // Infrared SAR15 IREF enable ends at 100 us
	localparam [12:0] IR_SHARED_CONTROL_END = IR_OFFSET_TICK + 13'd42;  // Infrared shared controls end at 101 us

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
	localparam integer CONTROL_WIDTH = 32'd41;                          // Registered width of all dynamic analog-control outputs
	localparam integer CTRL_FRAME_START = 32'd0;                        // Position of the 400 Hz frame-start flag
	localparam integer CTRL_EN_TIA = 32'd1;                             // Position of the TIA operating control
	localparam integer CTRL_LEDDAC_LSB = 32'd2;                         // Least-significant bit of the LEDDAC output field
	localparam integer CTRL_LEDDAC_MSB = 32'd9;                         // Most-significant bit of the LEDDAC output field
	localparam integer CTRL_LEDEN1 = 32'd10;                            // Position of the red LED1 enable
	localparam integer CTRL_LEDEN2 = 32'd11;                            // Position of the infrared LED2 enable
	localparam integer CTRL_CLK_IREF_IDAC = 32'd12;                     // Position of the local IDAC-reference timing
	localparam integer CTRL_CLK_IREF_LED = 32'd13;                      // Position of the LED-reference timing
	localparam integer CTRL_CLK_15Q1 = 32'd14;                          // Position of the 15-bit Q1 phase
	localparam integer CTRL_CLK_AFERST = 32'd15;                        // Position of the analog-front-end reset phase
	localparam integer CTRL_CLK_IREF_SAR15 = 32'd16;                    // Position of the shared SAR15-reference timing
	localparam integer CTRL_CLK_Q2 = 32'd17;                            // Position of the Q2 phase
	localparam integer CTRL_CLK_Q3 = 32'd18;                            // Position of the Q3 phase
	localparam integer CTRL_CLK_TIAEN = 32'd19;                         // Position of the local TIA enable
	localparam integer CTRL_EN_SAR15_AMB = 32'd20;                      // Position of the SAR15 AMB enable
	localparam integer CTRL_EN_SAR15_DC = 32'd21;                       // Position of the SAR15 DC enable
	localparam integer CTRL_EN_SAR15_IREF = 32'd22;                     // Position of the SAR15 IREF enable
	localparam integer CTRL_IDAC_AMB_LSB = 32'd23;                      // Least-significant bit of the SAR15 AMB-code output field
	localparam integer CTRL_IDAC_AMB_MSB = 32'd30;                      // Most-significant bit of the SAR15 AMB-code output field
	localparam integer CTRL_IDAC_DC_LSB = 32'd31;                       // Least-significant bit of the SAR15 DC-code output field
	localparam integer CTRL_IDAC_DC_MSB = 32'd38;                       // Most-significant bit of the SAR15 DC-code output field
	localparam integer CTRL_EN_15SAR = 32'd39;                          // Position of the 15-bit mode-select output
	localparam integer CTRL_EN_TEST = 32'd40;                           // Position of the analog test-mode output

	//---------------Counter Signals---------//
	// Reset starts from the settling window so the first red sample receives full setup time
	reg [12:0]cnt_frame;                                                // Modulo-5000 frame counter in the 2 MHz domain

	//--------------Register Signals---------//
	// Six codes are latched at each frame setup point to isolate the frame from configuration updates
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
	// Dynamic controls are registered before the analog boundary to suppress binary-counter decode glitches
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
	assign o_clk_2m = i_clk;                                           // Logically forwards 2 MHz in phase; implementation uses a clock buffer and level shifter
	assign o_clk_iref_idac_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_IREF_IDAC]; // Resets the local phase IDAC clock during static characterization
	assign o_clk_9q1_low = 1'b0;                                       // Prevents 9-bit Q1 activity in 15-bit mode
	assign o_clk_15q1_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_15Q1]; // Resets SAR15 Q1 during static characterization
	assign o_clk_aferst_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_AFERST]; // Resets the analog-front-end reset clock during static characterization
	assign o_clk_iref_idac_sar9_low = reg_static_characterization_enable ? 1'b1 : 1'b0; // Holds the SAR9 IREF clock active for static characterization
	assign o_clk_iref_idac_sar15_low = reg_static_characterization_enable ? 1'b1 : control_o[CTRL_CLK_IREF_SAR15]; // Holds the SAR15 IREF clock active for static characterization
	assign o_clk_q2_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_Q2]; // Resets Q2 during static characterization
	assign o_clk_q3_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_CLK_Q3]; // Resets Q3 during static characterization
	assign o_clk_tiaen_low = reg_static_characterization_enable ? 1'b1 : control_o[CTRL_CLK_TIAEN]; // Holds the TIA-enable timing path active for static characterization

	// Precision-mode and IDAC-control bridges
	assign o_en_15sar_low = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_EN_15SAR]; // Resets the precision selector during static characterization
	assign o_en_sar9_amb_low = reg_static_characterization_enable ? 1'b1 : 1'b0; // Holds SAR9 AMB active for static characterization
	assign o_en_sar9_dc_low = reg_static_characterization_enable ? 1'b1 : 1'b0; // Holds SAR9 DC active for static characterization
	assign o_en_sar9_iref = 1'b0;                                      // Disables the SAR9 reference branch in 15-bit mode
	assign o_en_sar15_amb_low = reg_static_characterization_enable ? 1'b1 : control_o[CTRL_EN_SAR15_AMB]; // Holds SAR15 AMB active for static characterization
	assign o_en_sar15_dc_low = reg_static_characterization_enable ? 1'b1 : control_o[CTRL_EN_SAR15_DC]; // Holds SAR15 DC active for static characterization
	assign o_en_sar15_iref = reg_static_characterization_enable ? 1'b0 : control_o[CTRL_EN_SAR15_IREF]; // Resets the SAR15 IREF enable during static characterization
	assign o_idac_sar9ambn_low = reg_static_characterization_enable ? reg_static_code_snapshot[STATIC_SAR9_AMB_MSB:STATIC_SAR9_AMB_LSB] : 8'h00; // Applies the SAR9 AMB code only during static characterization
	assign o_idac_sar9dcn_low = reg_static_characterization_enable ? reg_static_code_snapshot[STATIC_SAR9_DC_MSB:STATIC_SAR9_DC_LSB] : 8'h00; // Applies the SAR9 DC code only during static characterization
	assign o_idac_sar15ambn_low = reg_static_characterization_enable ? reg_static_code_snapshot[STATIC_SAR15_AMB_MSB:STATIC_SAR15_AMB_LSB] : control_o[CTRL_IDAC_AMB_MSB:CTRL_IDAC_AMB_LSB]; // Selects the static or timed SAR15 AMB code
	assign o_idac_sar15dcn_low = reg_static_characterization_enable ? reg_static_code_snapshot[STATIC_SAR15_DC_MSB:STATIC_SAR15_DC_LSB] : control_o[CTRL_IDAC_DC_MSB:CTRL_IDAC_DC_LSB]; // Selects the static or timed SAR15 DC code
	assign o_s_in = reg_test_mux_ctrl;                                  // Exposes the frame-latched SPI test-MUX control in every operating mode
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
	// The configured frame counter runs continuously to keep 9-bit and 15-bit cores phase aligned
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_frame <= OPTICAL_MODE_LATCH_TICK;                            // Starts one cycle before the first mode latch and SAR15 setup window
		end else if(cnt_frame == FRAME_LAST_TICK)begin
			cnt_frame <= 13'd0;                                            // Returns to the red-frame origin after C_FRAME_TICKS cycles
		end else begin
			cnt_frame <= cnt_frame + 13'd1;                                // Advances one 0.5 us slot on each 2 MHz master-clock edge
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

	// Atomically latches this frame's R/IR LED and cancellation codes at the shared-reference start
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_code_snapshot <= {CODE_SNAPSHOT_WIDTH{1'b0}};              // Clears every programmable current code during reset
		end else if(cnt_frame == PRESTART_TICK)begin
			reg_code_snapshot <= {i_idac_sar15_dc_ir_code, i_idac_sar15_dc_r_code,
				i_idac_sar15_amb_ir_code, i_idac_sar15_amb_r_code,
				i_leddac_ir_code, i_leddac_r_code};                           // Latches all six configuration codes before analog settling
		end else begin
			reg_code_snapshot <= reg_code_snapshot;                        // Holds the codes for a full frame despite configuration updates
		end
	end

	// Decodes the frame counter into right-open windows that drive only the downstream control register
	always@(*)begin
		reg_control_next = {CONTROL_WIDTH{1'b0}};                         // Defaults all controls off while disabled or outside active windows
		if(i_enable == 1'b1)begin
			reg_control_next[CTRL_FRAME_START] = (cnt_frame == 13'd0);      // Generates one frame pulse at the red-phase origin
			reg_control_next[CTRL_EN_15SAR] = 1'b1;                         // Selects the complete 15-bit sampling system
			reg_control_next[CTRL_EN_TEST] = i_test_mode;                   // Passes the current test mode synchronously

			reg_control_next[CTRL_EN_TIA] =
				(flag_red_phase_enabled && (cnt_frame < R_EN_TIA_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_EN_TIA_START) && (cnt_frame < IR_EN_TIA_END)); // Selects only the configured TIA operating windows
			reg_control_next[CTRL_CLK_TIAEN] =
				(flag_red_phase_enabled && (cnt_frame < R_EN_TIA_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_EN_TIA_START) && (cnt_frame < IR_EN_TIA_END)); // Selects only the configured local TIA-enable windows
			reg_control_next[CTRL_CLK_AFERST] =
				(flag_red_phase_enabled && (cnt_frame < R_AFERST_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_AFERST_START) && (cnt_frame < IR_AFERST_END)); // Selects only the configured analog-front-end reset windows
			reg_control_next[CTRL_CLK_15Q1] =
				(flag_red_phase_enabled && (cnt_frame >= R_Q1_START) && (cnt_frame < R_Q1_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_Q1_START) && (cnt_frame < IR_Q1_END)); // Selects only the configured 15-bit Q1 sampling windows
			reg_control_next[CTRL_CLK_Q2] =
				(flag_red_phase_enabled && (cnt_frame >= R_Q2_START) && (cnt_frame < R_Q2_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_Q2_START) && (cnt_frame < IR_Q2_END)); // Selects only the configured nonoverlapping Q2 windows
			reg_control_next[CTRL_CLK_Q3] =
				(flag_red_phase_enabled && (cnt_frame >= R_LED_START) && (cnt_frame < R_LED_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_LED_START) && (cnt_frame < IR_LED_END)); // Selects Q3 while preserving both optical sample centers
			reg_control_next[CTRL_CLK_IREF_LED] =
				(flag_red_phase_enabled && (cnt_frame >= R_LED_CODE_START) && (cnt_frame < R_LED_CODE_END)) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_LED_CODE_START) && (cnt_frame < IR_LED_CODE_END)); // Selects only the configured LED-reference setup windows
			reg_control_next[CTRL_CLK_IREF_IDAC] =
				(flag_red_phase_enabled && ((cnt_frame >= R_IDAC_CLOCK_START) || (cnt_frame < R_IDAC_CLOCK_END))) ||
				(flag_ir_phase_enabled && (cnt_frame >= IR_IDAC_CLOCK_START) && (cnt_frame < IR_IDAC_CLOCK_END)); // Selects the cross-frame red or in-frame infrared IDAC-reference window

			reg_control_next[CTRL_CLK_IREF_SAR15] =
				(flag_red_phase_enabled && ((cnt_frame >= R_SHARED_IREF_START) || (cnt_frame < R_SHARED_CONTROL_END))) ||
				(flag_ir_phase_enabled && ((cnt_frame >= IR_SHARED_IREF_START) || (cnt_frame < IR_SHARED_CONTROL_END))); // Merges only the enabled SAR15-reference clock intervals
			reg_control_next[CTRL_EN_SAR15_IREF] =
				(flag_red_phase_enabled && ((cnt_frame >= R_SHARED_IREF_START) || (cnt_frame < R_SHARED_IREF_END))) ||
				(flag_ir_phase_enabled && ((cnt_frame >= IR_SHARED_IREF_START) || (cnt_frame < IR_SHARED_IREF_END))); // Merges only the enabled SAR15-reference enable intervals
			reg_control_next[CTRL_EN_SAR15_AMB] =
				(flag_red_phase_enabled && ((cnt_frame >= R_SHARED_ENABLE_START) || (cnt_frame < R_SHARED_CONTROL_END))) ||
				(flag_ir_phase_enabled && ((cnt_frame >= IR_SHARED_ENABLE_START) || (cnt_frame < IR_SHARED_CONTROL_END))); // Merges only the enabled SAR15 AMB intervals
			reg_control_next[CTRL_EN_SAR15_DC] =
				(flag_red_phase_enabled && ((cnt_frame >= R_SHARED_ENABLE_START) || (cnt_frame < R_SHARED_CONTROL_END))) ||
				(flag_ir_phase_enabled && ((cnt_frame >= IR_SHARED_ENABLE_START) || (cnt_frame < IR_SHARED_CONTROL_END))); // Merges only the enabled SAR15 DC intervals

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

			if(flag_red_phase_enabled && ((cnt_frame >= R_IDAC_AMB_START) || (cnt_frame < R_IDAC_CODE_END)))begin
				reg_control_next[CTRL_IDAC_AMB_MSB:CTRL_IDAC_AMB_LSB] =
					reg_code_snapshot[CODE_AMB_R_MSB:CODE_AMB_R_LSB];             // Holds the AMB cancellation code during red settling and operation
			end else if(flag_ir_phase_enabled && (cnt_frame >= IR_IDAC_AMB_START) && (cnt_frame < IR_IDAC_CODE_END))begin
				reg_control_next[CTRL_IDAC_AMB_MSB:CTRL_IDAC_AMB_LSB] =
					reg_code_snapshot[CODE_AMB_IR_MSB:CODE_AMB_IR_LSB];           // Holds the AMB cancellation code during infrared settling and operation
			end

			if(flag_red_phase_enabled && ((cnt_frame >= R_IDAC_DC_START) || (cnt_frame < R_IDAC_CODE_END)))begin
				reg_control_next[CTRL_IDAC_DC_MSB:CTRL_IDAC_DC_LSB] =
					reg_code_snapshot[CODE_DC_R_MSB:CODE_DC_R_LSB];               // Holds the DC cancellation code during red settling and operation
			end else if(flag_ir_phase_enabled && (cnt_frame >= IR_IDAC_DC_START) && (cnt_frame < IR_IDAC_CODE_END))begin
				reg_control_next[CTRL_IDAC_DC_MSB:CTRL_IDAC_DC_LSB] =
					reg_code_snapshot[CODE_DC_IR_MSB:CODE_DC_IR_LSB];             // Holds the DC cancellation code during infrared settling and operation
			end
		end
	end

endmodule
