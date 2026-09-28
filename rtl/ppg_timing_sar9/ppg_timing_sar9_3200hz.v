`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/07/23
// Design Name:     PPG SAR9 Fast Simulation Timing Wrapper
// Module Name:     ppg_timing_sar9_3200hz
// Description:     Synthesizable SAR9 wrapper using a 625-cycle, 3200 Hz frame
// Simulations:     Fast simulation testbench or Virtuoso AMS configuration
//
// Referrences:     ppg_timing_sar9.v and PPG timing contract
//
// Dependencies:    ppg_timing_sar9.v
//
// Version:         V1.0
// Revision Date:   2026/07/23
// History:
//     Time          Version     Revised by     Contents
// 2026/07/23        V1.0        Erie          Create 3200 Hz simulation wrapper.
////////////////////////////////////English///////////////////////////////////////
// Ownership:        Erie
// Developer:        Erie
//
// Creation Date:    2026/07/23
// Design Name:      PPG SAR9 Fast Simulation Timing Wrapper
// Module Name:      ppg_timing_sar9_3200hz
// Description:      Exposes the SAR9 controller with a 3200 Hz frame output.
// Simulation:       Fast simulation testbench or Virtuoso AMS configuration
//
// Reference:        ppg_timing_sar9.v and PPG timing contract
//
// Dependencies:     ppg_timing_sar9.v
//
// Current Version:  V1.0
// Revision Date:    2026/07/23
// Revision History:
//     Date          Version     Author         Description
// 2026/07/23        V1.0        Erie           Initial 3200 Hz wrapper

// SAR9 fast simulation wrapper with all analog-control ports preserved.
module ppg_timing_sar9_3200hz
(
	//-------------Global Signals-------------//
	input i_clk,                                      // 2 MHz digital master clock
	input i_rstn,                                     // Active-low asynchronous reset

	//--------------Mode Control--------------//
	input i_enable,                                   // Enables SAR9 timing
	input i_test_mode,                                // Selects the analog test source
	input [1:0]i_optical_mode,                        // Selects red, infrared, or both phases
	input i_static_characterization_enable,           // Enables static characterization
	input [4:0]i_test_mux_ctrl,                       // Selects S0_IN through S4_IN

	//--------Static IDAC Code Configuration--//
	input [7:0]i_static_sar9_amb_code,                 // Static SAR9 AMB code
	input [7:0]i_static_sar9_dc_code,                  // Static SAR9 DC code
	input [7:0]i_static_sar15_amb_code,                // Static SAR15 AMB code
	input [7:0]i_static_sar15_dc_code,                 // Static SAR15 DC code

	//-----------LED Code Configuration-------//
	input [7:0]i_leddac_r_code,                       // Red LED drive code
	input [7:0]i_leddac_ir_code,                      // Infrared LED drive code

	//-----------SAR9 IDAC Configuration------//
	input [7:0]i_idac_sar9_amb_r_code,                // Red SAR9 AMB code
	input [7:0]i_idac_sar9_amb_ir_code,               // Infrared SAR9 AMB code
	input [7:0]i_idac_sar9_dc_r_code,                 // Red SAR9 DC code
	input [7:0]i_idac_sar9_dc_ir_code,                // Infrared SAR9 DC code

	//----------Frame Synchronization Output--//
	output o_frame_start_3200hz,                       // One-cycle 3200 Hz frame-start pulse

	//-----------Common Analog Controls-------//
	output o_en_tia_low,                              // TIA operating window
	output [7:0]o_leddac,                             // Active red or infrared LED code
	output o_leden1_low,                              // Red LED1 operating window
	output o_leden2_low,                              // Infrared LED2 operating window
	output o_en_test,                                 // Registered analog test control
	output o_clk_buf_low,                             // Static-characterization buffer control
	output o_clk_2m,                                  // Forwarded 2 MHz clock
	output o_clk_iref_idac_low,                       // Local IDAC reference timing
	output o_clk_9q1_low,                             // SAR9 Q1 sampling phase
	output o_clk_15q1_low,                            // Fixed-off SAR15 Q1 phase
	output o_clk_aferst_low,                          // Analog-front-end reset window
	output o_clk_iref_idac_sar9_low,                  // SAR9 reference timing
	output o_clk_iref_idac_sar15_low,                 // Static SAR15 reference timing
	output o_clk_q2_low,                              // Ambient-current sampling phase
	output o_clk_q3_low,                              // Dynamic-current sampling phase
	output o_clk_tiaen_low,                           // Local TIA-enable timing

	//---------Precision and IDAC Enables-----//
	output o_en_15sar_low,                            // Fixed-low 15-bit selector
	output o_en_sar9_amb_low,                         // SAR9 AMB enable
	output o_en_sar9_dc_low,                          // SAR9 DC enable
	output o_en_sar9_iref,                            // SAR9 reference enable
	output o_en_sar15_amb_low,                        // Static SAR15 AMB enable
	output o_en_sar15_dc_low,                         // Static SAR15 DC enable
	output o_en_sar15_iref,                           // Fixed-low SAR15 reference enable

	//-------------IDAC Code Outputs----------//
	output [7:0]o_idac_sar9ambn_low,                  // Active SAR9 AMB code
	output [7:0]o_idac_sar9dcn_low,                   // Active SAR9 DC code
	output [7:0]o_idac_sar15ambn_low,                 // Static SAR15 AMB code
	output [7:0]o_idac_sar15dcn_low,                 // Static SAR15 DC code

	//-------------Test Switch Outputs--------//
	output [4:0]o_s_in                                // Frame-latched test-MUX controls
);

	// The core keeps all production timing windows and changes only the frame modulus.
	ppg_timing_sar9
	#(
		.C_FRAME_TICKS(13'd625)
	)ppg_timing_sar9_Inst_3200hz(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_enable(i_enable),
		.i_test_mode(i_test_mode),
		.i_optical_mode(i_optical_mode),
		.i_static_characterization_enable(i_static_characterization_enable),
		.i_test_mux_ctrl(i_test_mux_ctrl),
		.i_static_sar9_amb_code(i_static_sar9_amb_code),
		.i_static_sar9_dc_code(i_static_sar9_dc_code),
		.i_static_sar15_amb_code(i_static_sar15_amb_code),
		.i_static_sar15_dc_code(i_static_sar15_dc_code),
		.i_leddac_r_code(i_leddac_r_code),
		.i_leddac_ir_code(i_leddac_ir_code),
		.i_idac_sar9_amb_r_code(i_idac_sar9_amb_r_code),
		.i_idac_sar9_amb_ir_code(i_idac_sar9_amb_ir_code),
		.i_idac_sar9_dc_r_code(i_idac_sar9_dc_r_code),
		.i_idac_sar9_dc_ir_code(i_idac_sar9_dc_ir_code),
		.o_frame_start_400hz(o_frame_start_3200hz),
		.o_en_tia_low(o_en_tia_low),
		.o_leddac(o_leddac),
		.o_leden1_low(o_leden1_low),
		.o_leden2_low(o_leden2_low),
		.o_en_test(o_en_test),
		.o_clk_buf_low(o_clk_buf_low),
		.o_clk_2m(o_clk_2m),
		.o_clk_iref_idac_low(o_clk_iref_idac_low),
		.o_clk_9q1_low(o_clk_9q1_low),
		.o_clk_15q1_low(o_clk_15q1_low),
		.o_clk_aferst_low(o_clk_aferst_low),
		.o_clk_iref_idac_sar9_low(o_clk_iref_idac_sar9_low),
		.o_clk_iref_idac_sar15_low(o_clk_iref_idac_sar15_low),
		.o_clk_q2_low(o_clk_q2_low),
		.o_clk_q3_low(o_clk_q3_low),
		.o_clk_tiaen_low(o_clk_tiaen_low),
		.o_en_15sar_low(o_en_15sar_low),
		.o_en_sar9_amb_low(o_en_sar9_amb_low),
		.o_en_sar9_dc_low(o_en_sar9_dc_low),
		.o_en_sar9_iref(o_en_sar9_iref),
		.o_en_sar15_amb_low(o_en_sar15_amb_low),
		.o_en_sar15_dc_low(o_en_sar15_dc_low),
		.o_en_sar15_iref(o_en_sar15_iref),
		.o_idac_sar9ambn_low(o_idac_sar9ambn_low),
		.o_idac_sar9dcn_low(o_idac_sar9dcn_low),
		.o_idac_sar15ambn_low(o_idac_sar15ambn_low),
		.o_idac_sar15dcn_low(o_idac_sar15dcn_low),
		.o_s_in(o_s_in)
	);

endmodule
