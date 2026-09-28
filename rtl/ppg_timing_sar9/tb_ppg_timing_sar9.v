`timescale 1ns / 1ps
`default_nettype none

// This file is for simulation verification only and is not synthesizable RTL
module tb_ppg_timing_sar9;

	//-------------Optical Mode Values-------//
	localparam [1:0] OPTICAL_MODE_BOTH = 2'b00;        // Requests red and infrared operation
	localparam [1:0] OPTICAL_MODE_RED_ONLY = 2'b01;    // Requests red-only operation
	localparam [1:0] OPTICAL_MODE_IR_ONLY = 2'b10;     // Requests infrared-only operation
	localparam [1:0] OPTICAL_MODE_RESERVED = 2'b11;    // Exercises the safe optical-off fallback

	//-------------Test Stimulus Signals-----//
	reg i_clk;                                         // 2 MHz test master clock
	reg i_rstn;                                        // Active-low test reset
	reg i_enable;                                      // 9-bit timing test enable
	reg i_test_mode;                                   // Analog test-path selection
	reg [1:0]i_optical_mode;                           // SPI-register-equivalent optical mode request
	reg i_static_characterization_enable;              // Static characterization request
	reg [4:0]i_test_mux_ctrl;                          // SPI-register-equivalent test-MUX control
	reg [7:0]i_static_sar9_amb_code;                   // Static SAR9 AMB characterization code
	reg [7:0]i_static_sar9_dc_code;                    // Static SAR9 DC characterization code
	reg [7:0]i_static_sar15_amb_code;                  // Static SAR15 AMB characterization code
	reg [7:0]i_static_sar15_dc_code;                   // Static SAR15 DC characterization code
	reg [7:0]i_leddac_r_code;                          // Red LED test code
	reg [7:0]i_leddac_ir_code;                         // Infrared LED test code
	reg [7:0]i_idac_sar9_amb_r_code;                   // Red AMB test code
	reg [7:0]i_idac_sar9_amb_ir_code;                  // Infrared AMB test code
	reg [7:0]i_idac_sar9_dc_r_code;                    // Red DC test code
	reg [7:0]i_idac_sar9_dc_ir_code;                   // Infrared DC test code

	//-------------DUT Output Signals--------//
	wire o_frame_start_400hz;                          // 400 Hz frame-start pulse
	wire o_en_tia_low;                                 // TIA operating window
	wire [7:0]o_leddac;                                // Current LED drive code
	wire o_leden1_low;                                 // Red LED1 window
	wire o_leden2_low;                                 // Infrared LED2 window
	wire o_en_test;                                    // Test-mode output
	wire o_clk_buf_low;                                // Static-characterization buffer control
	wire o_clk_2m;                                     // Source-aligned 2 MHz analog-domain clock
	wire o_clk_iref_idac_low;                          // Local IDAC-reference timing
	wire o_clk_9q1_low;                                // 9-bit Q1 timing
	wire o_clk_15q1_low;                               // Fixed-off 15-bit Q1 timing
	wire o_clk_aferst_low;                             // Analog-front-end reset timing
	wire o_clk_iref_idac_sar9_low;                     // SAR9-reference timing
	wire o_clk_iref_idac_sar15_low;                    // Static-characterization SAR15-reference timing
	wire o_clk_q2_low;                                 // Centered Q2 timing
	wire o_clk_q3_low;                                 // Q3 timing
	wire o_clk_tiaen_low;                              // Local TIA-enable timing
	wire o_en_15sar_low;                               // 15-bit mode selection
	wire o_en_sar9_amb_low;                            // SAR9 AMB enable
	wire o_en_sar9_dc_low;                             // SAR9 DC enable
	wire o_en_sar9_iref;                               // SAR9-reference enable
	wire o_en_sar15_amb_low;                           // Static-characterization SAR15 AMB enable
	wire o_en_sar15_dc_low;                            // Static-characterization SAR15 DC enable
	wire o_en_sar15_iref;                              // Fixed-off SAR15-reference enable
	wire [7:0]o_idac_sar9ambn_low;                     // Current SAR9 AMB code
	wire [7:0]o_idac_sar9dcn_low;                      // Current SAR9 DC code
	wire [7:0]o_idac_sar15ambn_low;                    // Fixed-zero SAR15 AMB code
	wire [7:0]o_idac_sar15dcn_low;                     // Fixed-zero SAR15 DC code
	wire [4:0]o_s_in;                                  // Frame-latched SPI test-MUX controls

	//---------------Check State-------------//
	integer tick_expected;                             // Frame count associated with the current check
	integer tick_index;                                // Cycle-by-cycle loop index for one frame
	integer error_count;                               // Accumulated mismatch count
	reg expected_red_active;                           // Expected red-phase permission for the checked frame
	reg expected_ir_active;                            // Expected infrared-phase permission for the checked frame
	reg capture_q_edges;                               // Enables Q2/Q3 edge capture only for the dual-phase reference frame
	integer q2_rise_red_tick;                          // Observed red Q2 rising-edge count
	integer q2_fall_red_tick;                          // Observed red Q2 falling-edge count
	integer q2_rise_ir_tick;                           // Observed infrared Q2 rising-edge count
	integer q2_fall_ir_tick;                           // Observed infrared Q2 falling-edge count
	reg q2_previous;                                   // Previous Q2 value for edge detection
	integer q3_rise_red_tick;                          // Observed red Q3 rising-edge count
	integer q3_fall_red_tick;                          // Observed red Q3 falling-edge count
	integer q3_rise_ir_tick;                           // Observed infrared Q3 rising-edge count
	integer q3_fall_ir_tick;                           // Observed infrared Q3 falling-edge count
	reg q3_previous;                                   // Previous Q3 value for edge detection
	reg expected_scalar;                               // Expected single-bit value cache
	reg [7:0]expected_bus;                             // Expected 8-bit bus value cache

	// 2 MHz clock source with a 250 ns half period
	always #250 i_clk = ~i_clk;

	// Checks whether the analog clock output is logically in phase with the digital master clock
	always@(i_clk)begin
		#1;
		if(o_clk_2m !== i_clk)begin
			error_count = error_count + 1;                  // Records an analog 2 MHz forwarding mismatch
			$display("ERROR: o_clk_2m mismatch at %0t", $time);
		end
	end

	// Compares one single-bit timing output
	task check_scalar;
		input actual_value;                              // Actual single-bit DUT output
		input expected_value;                            // Expected single-bit value for the current cycle
		input [8*48-1:0]signal_name;                     // Signal name printed in the simulation log
		begin
			if(actual_value !== expected_value)begin
				error_count = error_count + 1;              // Accumulates the current single-bit comparison error
				$display("ERROR tick=%0d %0s actual=%b expected=%b",
					tick_expected, signal_name, actual_value, expected_value);
			end
		end
	endtask

	// Compares one 8-bit analog-control code output
	task check_bus;
		input [7:0]actual_value;                          // Actual 8-bit DUT control code
		input [7:0]expected_value;                        // Expected control code for the current window
		input [8*48-1:0]signal_name;                     // Bus name printed in the simulation log
		begin
			if(actual_value !== expected_value)begin
				error_count = error_count + 1;              // Accumulates the current bus comparison error
				$display("ERROR tick=%0d %0s actual=%h expected=%h",
					tick_expected, signal_name, actual_value, expected_value);
			end
		end
	endtask

	// Recomputes every key output window from the current common frame count
	task check_tick;
		begin
			check_scalar(o_frame_start_400hz, tick_expected == 0,
				"o_frame_start_400hz");
			check_scalar(o_en_tia_low,
				(expected_red_active && (tick_expected >= 17) && (tick_expected < 37)) ||
				(expected_ir_active && (tick_expected >= 177) && (tick_expected < 197)),
				"o_en_tia_low");
			check_scalar(o_clk_tiaen_low,
				(expected_red_active && (tick_expected >= 17) && (tick_expected < 37)) ||
				(expected_ir_active && (tick_expected >= 177) && (tick_expected < 197)),
				"o_clk_tiaen_low");
			check_scalar(o_clk_aferst_low,
				(expected_red_active && (tick_expected >= 17) && (tick_expected < 29)) ||
				(expected_ir_active && (tick_expected >= 177) && (tick_expected < 189)),
				"o_clk_aferst_low");
			check_scalar(o_clk_9q1_low,
				(expected_red_active && (tick_expected >= 27) && (tick_expected < 36)) ||
				(expected_ir_active && (tick_expected >= 187) && (tick_expected < 196)),
				"o_clk_9q1_low");
			check_scalar(o_clk_q2_low,
				(expected_red_active && (tick_expected >= 30) && (tick_expected < 32)) ||
				(expected_ir_active && (tick_expected >= 190) && (tick_expected < 192)),
				"o_clk_q2_low");
			check_scalar(o_clk_q3_low,
				(expected_red_active && (tick_expected >= 33) && (tick_expected < 35)) ||
				(expected_ir_active && (tick_expected >= 193) && (tick_expected < 195)),
				"o_clk_q3_low");
			check_scalar(o_clk_iref_idac_low,
				(expected_red_active && ((tick_expected >= 4997) || (tick_expected < 37))) ||
				(expected_ir_active && (tick_expected >= 157) && (tick_expected < 197)),
				"o_clk_iref_idac_low");
			check_scalar(o_clk_iref_idac_sar9_low,
				(expected_red_active && ((tick_expected >= 4778) || (tick_expected < 52))) ||
				(expected_ir_active && ((tick_expected >= 4938) || (tick_expected < 212))),
				"o_clk_iref_idac_sar9_low");
			check_scalar(o_en_sar9_iref,
				(expected_red_active && ((tick_expected >= 4970) || (tick_expected < 42))) ||
				(expected_ir_active && (tick_expected >= 130) && (tick_expected < 202)),
				"o_en_sar9_iref");
			check_scalar(o_en_sar9_amb_low,
				(expected_red_active && ((tick_expected >= 4990) || (tick_expected < 44))) ||
				(expected_ir_active && (tick_expected >= 150) && (tick_expected < 204)),
				"o_en_sar9_amb_low");
			check_scalar(o_en_sar9_dc_low,
				(expected_red_active && ((tick_expected >= 4990) || (tick_expected < 44))) ||
				(expected_ir_active && (tick_expected >= 150) && (tick_expected < 204)),
				"o_en_sar9_dc_low");
			check_scalar(o_leden1_low,
				expected_red_active && (tick_expected >= 33) && (tick_expected < 35),
				"o_leden1_low");
			check_scalar(o_leden2_low,
				expected_ir_active && (tick_expected >= 193) && (tick_expected < 195),
				"o_leden2_low");

			expected_bus = 8'h00;                         // Keeps the LEDDAC output off by default
			if(expected_red_active && (tick_expected >= 32) && (tick_expected < 35))begin
				expected_bus = i_leddac_r_code;             // Checks the LED1 code during the red window
			end else if(expected_ir_active && (tick_expected >= 192) && (tick_expected < 195))begin
				expected_bus = i_leddac_ir_code;            // Checks the LED2 code during the infrared window
			end
			check_bus(o_leddac, expected_bus, "o_leddac");

			expected_bus = 8'h00;                         // Keeps the SAR9 AMB code off by default
			if(expected_red_active && ((tick_expected >= 4992) || (tick_expected < 44)))begin
				expected_bus = i_idac_sar9_amb_r_code;      // Checks the red AMB setup and operating window
			end else if(expected_ir_active && (tick_expected >= 152) && (tick_expected < 204))begin
				expected_bus = i_idac_sar9_amb_ir_code;     // Checks the infrared AMB setup and operating window
			end
			check_bus(o_idac_sar9ambn_low, expected_bus,
				"o_idac_sar9ambn_low");

			expected_bus = 8'h00;                         // Keeps the SAR9 DC code off by default
			if(expected_red_active && (tick_expected < 44))begin
				expected_bus = i_idac_sar9_dc_r_code;       // Checks the red DC setup and operating window
			end else if(expected_ir_active && (tick_expected >= 160) && (tick_expected < 204))begin
				expected_bus = i_idac_sar9_dc_ir_code;      // Checks the infrared DC setup and operating window
			end
			check_bus(o_idac_sar9dcn_low, expected_bus,
				"o_idac_sar9dcn_low");

			check_scalar(o_en_15sar_low, 1'b0, "o_en_15sar_low");
			check_scalar(o_en_test, 1'b1, "o_en_test");
			check_scalar(o_clk_buf_low, 1'b0, "o_clk_buf_low");
			check_scalar(o_clk_15q1_low, 1'b0, "o_clk_15q1_low");
			check_scalar(o_clk_iref_idac_sar15_low, 1'b0,
				"o_clk_iref_idac_sar15_low");
			check_scalar(o_en_sar15_amb_low, 1'b0, "o_en_sar15_amb_low");
			check_scalar(o_en_sar15_dc_low, 1'b0, "o_en_sar15_dc_low");
			check_scalar(o_en_sar15_iref, 1'b0, "o_en_sar15_iref");
			check_bus(o_idac_sar15ambn_low, 8'h00, "o_idac_sar15ambn_low");
			check_bus(o_idac_sar15dcn_low, 8'h00, "o_idac_sar15dcn_low");
			if(o_s_in !== i_test_mux_ctrl)begin
				error_count = error_count + 1;              // Records a normal-mode test-MUX control mismatch
				$display("ERROR tick=%0d o_s_in=%b expected=%b",
					tick_expected, o_s_in, i_test_mux_ctrl);
			end

			if(capture_q_edges == 1'b1)begin
				if((q2_previous == 1'b0) && (o_clk_q2_low == 1'b1))begin
					if(tick_expected < 160)begin
						q2_rise_red_tick = tick_expected;         // Captures the red Q2 rising edge
					end else begin
						q2_rise_ir_tick = tick_expected;          // Captures the infrared Q2 rising edge
					end
				end
				if((q2_previous == 1'b1) && (o_clk_q2_low == 1'b0))begin
					if(tick_expected < 160)begin
						q2_fall_red_tick = tick_expected;         // Captures the red Q2 falling edge
					end else begin
						q2_fall_ir_tick = tick_expected;          // Captures the infrared Q2 falling edge
					end
				end
				q2_previous = o_clk_q2_low;                  // Advances the Q2 edge detector during the reference frame

				if((q3_previous == 1'b0) && (o_clk_q3_low == 1'b1))begin
					if(tick_expected < 160)begin
						q3_rise_red_tick = tick_expected;         // Captures the red Q3 rising edge
					end else begin
						q3_rise_ir_tick = tick_expected;          // Captures the infrared Q3 rising edge
					end
				end
				if((q3_previous == 1'b1) && (o_clk_q3_low == 1'b0))begin
					if(tick_expected < 160)begin
						q3_fall_red_tick = tick_expected;         // Captures the red Q3 falling edge
					end else begin
						q3_fall_ir_tick = tick_expected;          // Captures the infrared Q3 falling edge
					end
				end
				q3_previous = o_clk_q3_low;                  // Advances the Q3 edge detector during the reference frame
			end
		end
	endtask

	// Checks the complete static characterization output override
	task check_static_tick;
		begin
			check_scalar(o_frame_start_400hz, 1'b0, "static o_frame_start_400hz");
			check_scalar(o_en_tia_low, 1'b0, "static o_en_tia_low");
			check_bus(o_leddac, 8'h00, "static o_leddac");
			check_scalar(o_leden1_low, 1'b0, "static o_leden1_low");
			check_scalar(o_leden2_low, 1'b0, "static o_leden2_low");
			check_scalar(o_en_test, i_test_mode, "static o_en_test");
			check_scalar(o_clk_buf_low, 1'b1, "static o_clk_buf_low");
			check_scalar(o_clk_iref_idac_low, 1'b0, "static o_clk_iref_idac_low");
			check_scalar(o_clk_9q1_low, 1'b0, "static o_clk_9q1_low");
			check_scalar(o_clk_15q1_low, 1'b0, "static o_clk_15q1_low");
			check_scalar(o_clk_aferst_low, 1'b0, "static o_clk_aferst_low");
			check_scalar(o_clk_iref_idac_sar9_low, 1'b1,
				"static o_clk_iref_idac_sar9_low");
			check_scalar(o_clk_iref_idac_sar15_low, 1'b1,
				"static o_clk_iref_idac_sar15_low");
			check_scalar(o_clk_q2_low, 1'b0, "static o_clk_q2_low");
			check_scalar(o_clk_q3_low, 1'b0, "static o_clk_q3_low");
			check_scalar(o_clk_tiaen_low, 1'b1, "static o_clk_tiaen_low");
			check_scalar(o_en_15sar_low, 1'b0, "static o_en_15sar_low");
			check_scalar(o_en_sar9_amb_low, 1'b1, "static o_en_sar9_amb_low");
			check_scalar(o_en_sar9_dc_low, 1'b1, "static o_en_sar9_dc_low");
			check_scalar(o_en_sar9_iref, 1'b0, "static o_en_sar9_iref");
			check_scalar(o_en_sar15_amb_low, 1'b1, "static o_en_sar15_amb_low");
			check_scalar(o_en_sar15_dc_low, 1'b1, "static o_en_sar15_dc_low");
			check_scalar(o_en_sar15_iref, 1'b0, "static o_en_sar15_iref");
			check_bus(o_idac_sar9ambn_low, i_static_sar9_amb_code, "static o_idac_sar9ambn_low");
			check_bus(o_idac_sar9dcn_low, i_static_sar9_dc_code, "static o_idac_sar9dcn_low");
			check_bus(o_idac_sar15ambn_low, i_static_sar15_amb_code, "static o_idac_sar15ambn_low");
			check_bus(o_idac_sar15dcn_low, i_static_sar15_dc_code, "static o_idac_sar15dcn_low");
			if(o_s_in !== i_test_mux_ctrl)begin
				error_count = error_count + 1;              // Records a static test-MUX mismatch
				$display("ERROR static tick=%0d o_s_in=%b expected=%b",
					tick_expected, o_s_in, i_test_mux_ctrl);
			end
		end
	endtask

	// Checks one complete frame using the optical mode captured at tick 4760
	task run_mode_frame;
		input [1:0]requested_mode;                       // Mode value presented by the simulated SPI register bridge
		input red_phase_expected;                       // Expected red-phase activity throughout this frame
		input ir_phase_expected;                        // Expected infrared-phase activity throughout this frame
		begin
			i_optical_mode = requested_mode;                // Presents the next mode before the frame-safe latch edge
			expected_red_active = red_phase_expected;       // Selects red expectations for every checked output
			expected_ir_active = ir_phase_expected;         // Selects infrared expectations for every checked output
			for(tick_index = 0; tick_index < 5000; tick_index = tick_index + 1)begin
				@(posedge i_clk);
				#1;
				check_tick;                                    // Checks all dynamic and fixed outputs for this frame tick
				if(tick_expected == 4999)begin
					tick_expected = 0;                          // Wraps to the red-frame origin at the frame end
				end else begin
					tick_expected = tick_expected + 1;          // Advances the expected count to the next 0.5 us slot
				end
			end
		end
	endtask

	// Checks one complete frame of the static characterization override
	task run_static_frame;
		begin
			i_static_characterization_enable = 1'b1;        // Requests the static override before the safe latch edge
			i_test_mode = 1'b0;                             // Proves EN_TEST remains an independent frontend selector
			i_test_mux_ctrl = 5'b01010;                     // Selects a nonzero static test-MUX path
			i_static_sar9_amb_code = 8'h11;                 // Selects a distinct static SAR9 AMB code
			i_static_sar9_dc_code = 8'h22;                  // Selects a distinct static SAR9 DC code
			i_static_sar15_amb_code = 8'h44;                // Selects a distinct static SAR15 AMB code
			i_static_sar15_dc_code = 8'h88;                 // Selects a distinct static SAR15 DC code
			for(tick_index = 0; tick_index < 5000; tick_index = tick_index + 1)begin
				@(posedge i_clk);
				#1;
				check_static_tick;                              // Checks every static output for the complete frame
				if(tick_expected == 4999)begin
					tick_expected = 0;                          // Wraps the expected frame counter
				end else begin
					tick_expected = tick_expected + 1;          // Advances to the next static frame slot
				end
			end
		end
	endtask

	// Changes the requested mode after the latch and proves the current frame remains atomic
	task run_frame_with_mid_update;
		input [1:0]frame_mode;                           // Mode captured for the frame under test
		input [1:0]next_mode;                            // New request written after the current frame latch
		input red_phase_expected;                       // Expected red activity from the captured frame mode
		input ir_phase_expected;                        // Expected infrared activity from the captured frame mode
		begin
			i_optical_mode = frame_mode;                    // Presents the mode before the safe latch edge
			expected_red_active = red_phase_expected;       // Holds current-frame red expectations after the later write
			expected_ir_active = ir_phase_expected;         // Holds current-frame infrared expectations after the later write
			for(tick_index = 0; tick_index < 5000; tick_index = tick_index + 1)begin
				@(posedge i_clk);
				#1;
				check_tick;                                    // Confirms every window still follows the captured mode
				if(tick_expected == 13'd100)begin
					i_optical_mode = next_mode;                 // Models an SPI update after red sampling but before infrared sampling
				end
				if(tick_expected == 4999)begin
					tick_expected = 0;                          // Wraps the expected frame counter
				end else begin
					tick_expected = tick_expected + 1;          // Advances to the next frame slot
				end
			end
		end
	endtask

	//-----------Test Stimulus Execution-----//
	initial begin
		i_clk = 1'b0;                                    // Initializes the 2 MHz clock low
		i_rstn = 1'b0;                                   // Keeps reset asserted during initialization
		i_enable = 1'b1;                                 // Enables SAR9 before the earliest setup window
		i_test_mode = 1'b1;                              // Reproduces the current Spectre test mode
		i_optical_mode = OPTICAL_MODE_BOTH;              // Preserves dual-phase behavior for the reset frame
		i_static_characterization_enable = 1'b0;         // Starts in normal intermittent operation
		i_test_mux_ctrl = 5'b10101;                      // Exercises normal-mode SPI test-MUX observation
		i_static_sar9_amb_code = 8'h00;                  // Resets the static SAR9 AMB code
		i_static_sar9_dc_code = 8'h00;                   // Resets the static SAR9 DC code
		i_static_sar15_amb_code = 8'h00;                 // Resets the static SAR15 AMB code
		i_static_sar15_dc_code = 8'h00;                  // Resets the static SAR15 DC code
		i_leddac_r_code = 8'hA5;                         // Uses an asymmetric red code to check bit ordering
		i_leddac_ir_code = 8'h5A;                        // Uses a complementary infrared code to check phase switching
		i_idac_sar9_amb_r_code = 8'h12;                  // Sets the red AMB identification code
		i_idac_sar9_amb_ir_code = 8'h34;                 // Sets the infrared AMB identification code
		i_idac_sar9_dc_r_code = 8'h56;                   // Sets the red DC identification code
		i_idac_sar9_dc_ir_code = 8'h78;                  // Sets the infrared DC identification code
		tick_expected = 4760;                            // Aligns with the mode-latch count after reset
		tick_index = 0;                                  // Clears the single-frame loop index
		error_count = 0;                                 // Clears the accumulated error count
		expected_red_active = 1'b1;                      // Expects the reset-default red phase
		expected_ir_active = 1'b1;                       // Expects the reset-default infrared phase
		capture_q_edges = 1'b1;                          // Captures Q2/Q3 edges only in the first dual-phase frame
		q2_rise_red_tick = -1;                           // Marks the red Q2 rising edge as unseen
		q2_fall_red_tick = -1;                           // Marks the red Q2 falling edge as unseen
		q2_rise_ir_tick = -1;                            // Marks the infrared Q2 rising edge as unseen
		q2_fall_ir_tick = -1;                            // Marks the infrared Q2 falling edge as unseen
		q2_previous = 1'b0;                              // Initializes Q2 edge detection low
		q3_rise_red_tick = -1;                           // Marks the red Q3 rising edge as unseen
		q3_fall_red_tick = -1;                           // Marks the red Q3 falling edge as unseen
		q3_rise_ir_tick = -1;                            // Marks the infrared Q3 rising edge as unseen
		q3_fall_ir_tick = -1;                            // Marks the infrared Q3 falling edge as unseen
		q3_previous = 1'b0;                              // Initializes Q3 edge detection low
		expected_scalar = 1'b0;                          // Initializes the expected single-bit cache
		expected_bus = 8'h00;                            // Initializes the expected bus cache

		repeat(3)begin
			@(posedge i_clk);                              // Holds reset for three master-clock cycles
		end
		@(negedge i_clk);
		i_rstn = 1'b1;                                   // Releases reset on a falling edge to avoid testbench races

		run_mode_frame(OPTICAL_MODE_BOTH, 1'b1, 1'b1);   // Checks the historical red-plus-infrared waveform set

		if((q2_rise_ir_tick - q2_rise_red_tick) != 160)begin
			error_count = error_count + 1;                  // Rejects a Q2 rising-edge offset other than 80 us
			$display("ERROR: Q2 rising-edge offset is %0d cycles", q2_rise_ir_tick - q2_rise_red_tick);
		end
		if((q2_fall_ir_tick - q2_fall_red_tick) != 160)begin
			error_count = error_count + 1;                  // Rejects a Q2 falling-edge offset other than 80 us
			$display("ERROR: Q2 falling-edge offset is %0d cycles", q2_fall_ir_tick - q2_fall_red_tick);
		end
		if(((q2_rise_red_tick + q2_fall_red_tick) / 2) != 31)begin
			error_count = error_count + 1;                  // Rejects a red Q2 center other than 15.5 us
			$display("ERROR: red Q2 center is not tick 31");
		end
		if(((q2_rise_ir_tick + q2_fall_ir_tick) / 2) != 191)begin
			error_count = error_count + 1;                  // Rejects an infrared Q2 center other than 95.5 us
			$display("ERROR: infrared Q2 center is not tick 191");
		end
		if((q3_rise_ir_tick - q3_rise_red_tick) != 160)begin
			error_count = error_count + 1;                  // Rejects a Q3 rising-edge offset other than 80 us
			$display("ERROR: Q3 rising-edge offset is %0d cycles", q3_rise_ir_tick - q3_rise_red_tick);
		end
		if((q3_fall_ir_tick - q3_fall_red_tick) != 160)begin
			error_count = error_count + 1;                  // Rejects a Q3 falling-edge offset other than 80 us
			$display("ERROR: Q3 falling-edge offset is %0d cycles", q3_fall_ir_tick - q3_fall_red_tick);
		end
		if(((q3_rise_red_tick + q3_fall_red_tick) / 2) != 34)begin
			error_count = error_count + 1;                  // Rejects a red Q3 center different from the SAR15 center
			$display("ERROR: red Q3 center is not tick 34");
		end
		if(((q3_rise_ir_tick + q3_fall_ir_tick) / 2) != 194)begin
			error_count = error_count + 1;                  // Rejects an infrared Q3 center different from the SAR15 center
			$display("ERROR: infrared Q3 center is not tick 194");
		end
		capture_q_edges = 1'b0;                          // Prevents single-phase frames from overwriting the reference edges

		@(negedge i_clk);
		run_mode_frame(OPTICAL_MODE_RED_ONLY, 1'b1, 1'b0); // Checks that every infrared-specific control remains off
		@(negedge i_clk);
		run_mode_frame(OPTICAL_MODE_IR_ONLY, 1'b0, 1'b1); // Checks that every red-specific control remains off
		@(negedge i_clk);
		run_frame_with_mid_update(OPTICAL_MODE_BOTH, OPTICAL_MODE_RED_ONLY,
			1'b1, 1'b1);                                  // Checks that a mid-frame SPI write cannot suppress the current infrared phase
		@(negedge i_clk);
		run_mode_frame(OPTICAL_MODE_RED_ONLY, 1'b1, 1'b0); // Checks that the deferred SPI request applies on the next frame
		@(negedge i_clk);
		run_mode_frame(OPTICAL_MODE_RESERVED, 1'b0, 1'b0); // Checks the safe optical-off response to the reserved code
		@(negedge i_clk);
		run_static_frame;                                // Checks the frame-latched static characterization vector
		@(negedge i_clk);
		i_static_characterization_enable = 1'b0;         // Requests a return to normal timing at the next latch edge
		i_test_mode = 1'b1;                              // Restores the ideal-source frontend selection
		i_test_mux_ctrl = 5'b00111;                      // Selects a new normal-mode observation path
		run_mode_frame(OPTICAL_MODE_BOTH, 1'b1, 1'b1);   // Checks normal timing recovery after static characterization

		@(negedge i_clk);
		i_enable = 1'b0;                                 // Disables the 9-bit timing core on a safe edge
		@(posedge i_clk);
		#1;
		check_scalar(o_en_tia_low, 1'b0, "disabled o_en_tia_low");
		check_scalar(o_en_test, 1'b1, "disabled independent o_en_test");
		check_scalar(o_clk_iref_idac_sar9_low, 1'b0,
			"disabled o_clk_iref_idac_sar9_low");
		check_bus(o_idac_sar9ambn_low, 8'h00,
			"disabled o_idac_sar9ambn_low");
		check_bus(o_idac_sar9dcn_low, 8'h00,
			"disabled o_idac_sar9dcn_low");

		if(error_count == 0)begin
			$display("PASS: ppg_timing_sar9 optical, test-MUX, and static characterization modes matched.");
		end else begin
			$display("FAIL: ppg_timing_sar9 optical-mode test detected %0d mismatches.", error_count);
		end
		$finish;
	end

	// Watchdog terminates a stalled test before it can hang a batch run
	initial begin
		#30000000;
		$display("FAIL: ppg_timing_sar9 optical-mode simulation timeout.");
		$finish;
	end

	// 9-bit timing-controller DUT instance
	ppg_timing_sar9 ppg_timing_sar9_Inst_dut(
		.i_clk(i_clk),                                           // Connects the 2 MHz test master clock
		.i_rstn(i_rstn),                                         // Connects the active-low test reset
		.i_enable(i_enable),                                     // Connects the 9-bit timing enable
		.i_test_mode(i_test_mode),                               // Connects the analog test mode
		.i_optical_mode(i_optical_mode),                         // Connects the SPI-register-equivalent optical selection
		.i_static_characterization_enable(i_static_characterization_enable), // Connects the static characterization request
		.i_test_mux_ctrl(i_test_mux_ctrl),                       // Connects the SPI-register-equivalent test-MUX control
		.i_static_sar9_amb_code(i_static_sar9_amb_code),         // Connects the static SAR9 AMB code
		.i_static_sar9_dc_code(i_static_sar9_dc_code),           // Connects the static SAR9 DC code
		.i_static_sar15_amb_code(i_static_sar15_amb_code),       // Connects the static SAR15 AMB code
		.i_static_sar15_dc_code(i_static_sar15_dc_code),         // Connects the static SAR15 DC code
		.i_leddac_r_code(i_leddac_r_code),                       // Connects the red LED test code
		.i_leddac_ir_code(i_leddac_ir_code),                     // Connects the infrared LED test code
		.i_idac_sar9_amb_r_code(i_idac_sar9_amb_r_code),         // Connects the red AMB test code
		.i_idac_sar9_amb_ir_code(i_idac_sar9_amb_ir_code),       // Connects the infrared AMB test code
		.i_idac_sar9_dc_r_code(i_idac_sar9_dc_r_code),           // Connects the red DC test code
		.i_idac_sar9_dc_ir_code(i_idac_sar9_dc_ir_code),         // Connects the infrared DC test code
		.o_frame_start_400hz(o_frame_start_400hz),                // Observes the 400 Hz frame-start pulse
		.o_en_tia_low(o_en_tia_low),                             // Observes the TIA operating window
		.o_leddac(o_leddac),                                     // Observes the current LED drive code
		.o_leden1_low(o_leden1_low),                             // Observes the red LED1 window
		.o_leden2_low(o_leden2_low),                             // Observes the infrared LED2 window
		.o_en_test(o_en_test),                                   // Observes the test-mode output
		.o_clk_buf_low(o_clk_buf_low),                           // Observes the fixed buffer control
		.o_clk_2m(o_clk_2m),                                     // Observes the 2 MHz analog-domain forwarding
		.o_clk_iref_idac_low(o_clk_iref_idac_low),               // Observes the local IDAC-reference timing
		.o_clk_9q1_low(o_clk_9q1_low),                           // Observes the shifted 9-bit Q1 timing
		.o_clk_15q1_low(o_clk_15q1_low),                         // Observes the fixed-off 15-bit Q1 timing
		.o_clk_aferst_low(o_clk_aferst_low),                     // Observes the analog-front-end reset timing
		.o_clk_iref_idac_sar9_low(o_clk_iref_idac_sar9_low),     // Observes the SAR9-reference timing
		.o_clk_iref_idac_sar15_low(o_clk_iref_idac_sar15_low),   // Observes the fixed-off SAR15-reference timing
		.o_clk_q2_low(o_clk_q2_low),                             // Observes the centered Q2 timing
		.o_clk_q3_low(o_clk_q3_low),                             // Observes Q3 timing
		.o_clk_tiaen_low(o_clk_tiaen_low),                       // Observes the local TIA-enable timing
		.o_en_15sar_low(o_en_15sar_low),                         // Observes 15-bit mode selection
		.o_en_sar9_amb_low(o_en_sar9_amb_low),                   // Observes the SAR9 AMB enable
		.o_en_sar9_dc_low(o_en_sar9_dc_low),                     // Observes the SAR9 DC enable
		.o_en_sar9_iref(o_en_sar9_iref),                         // Observes the SAR9-reference enable
		.o_en_sar15_amb_low(o_en_sar15_amb_low),                 // Observes the fixed-off SAR15 AMB enable
		.o_en_sar15_dc_low(o_en_sar15_dc_low),                   // Observes the fixed-off SAR15 DC enable
		.o_en_sar15_iref(o_en_sar15_iref),                       // Observes the fixed-off SAR15-reference enable
		.o_idac_sar9ambn_low(o_idac_sar9ambn_low),               // Observes the AMB code for the current optical phase
		.o_idac_sar9dcn_low(o_idac_sar9dcn_low),                 // Observes the DC code for the current optical phase
		.o_idac_sar15ambn_low(o_idac_sar15ambn_low),             // Observes the fixed-zero SAR15 AMB code
		.o_idac_sar15dcn_low(o_idac_sar15dcn_low),               // Observes the fixed-zero SAR15 DC code
		.o_s_in(o_s_in)                                          // Observes the fixed-off test switches
	);

endmodule

`default_nettype wire
