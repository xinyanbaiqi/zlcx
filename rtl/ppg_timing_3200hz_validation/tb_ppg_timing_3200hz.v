`timescale 1ns / 1ps

// Self-checking simulation for the 3200 Hz SAR9 and SAR15 timing wrappers.
module tb_ppg_timing_3200hz;

	reg i_clk;
	reg i_rstn;
	reg i_enable;
	reg i_test_mode;
	reg [1:0]i_optical_mode;
	reg i_static_characterization_enable;
	reg [4:0]i_test_mux_ctrl;
	reg [7:0]i_static_sar9_amb_code;
	reg [7:0]i_static_sar9_dc_code;
	reg [7:0]i_static_sar15_amb_code;
	reg [7:0]i_static_sar15_dc_code;
	reg [7:0]i_leddac_r_code;
	reg [7:0]i_leddac_ir_code;
	reg [7:0]i_idac_sar9_amb_r_code;
	reg [7:0]i_idac_sar9_amb_ir_code;
	reg [7:0]i_idac_sar9_dc_r_code;
	reg [7:0]i_idac_sar9_dc_ir_code;
	reg [7:0]i_idac_sar15_amb_r_code;
	reg [7:0]i_idac_sar15_amb_ir_code;
	reg [7:0]i_idac_sar15_dc_r_code;
	reg [7:0]i_idac_sar15_dc_ir_code;
	wire frame_start_sar9;
	wire frame_start_sar15;
	wire clk_2m_sar9;
	wire clk_2m_sar15;
	wire clk_q2_sar9;
	wire clk_q2_sar15;
	wire clk_q3_sar9;
	wire clk_q3_sar15;
	integer error_count;
	time frame_sar9_first;
	time frame_sar9_second;
	time frame_sar15_first;
	time frame_sar15_second;
	time q2_sar9_red_rise;
	time q2_sar9_ir_rise;
	time q2_sar15_red_rise;
	time q2_sar15_ir_rise;
	time q3_sar9_red_rise;
	time q3_sar9_red_fall;
	time q3_sar9_ir_rise;
	time q3_sar9_ir_fall;
	time q3_sar15_red_rise;
	time q3_sar15_red_fall;
	time q3_sar15_ir_rise;
	time q3_sar15_ir_fall;

	// Generate the unchanged 2 MHz digital master clock.
	always begin
		#250 i_clk = ~i_clk;
	end

	// Exercise both optical phases and verify the accelerated frame contract.
	initial begin
		i_clk = 1'b0;
		i_rstn = 1'b0;
		i_enable = 1'b1;
		i_test_mode = 1'b0;
		i_optical_mode = 2'b00;
		i_static_characterization_enable = 1'b0;
		i_test_mux_ctrl = 5'b00000;
		i_static_sar9_amb_code = 8'h00;
		i_static_sar9_dc_code = 8'h00;
		i_static_sar15_amb_code = 8'h00;
		i_static_sar15_dc_code = 8'h00;
		i_leddac_r_code = 8'h35;
		i_leddac_ir_code = 8'hCA;
		i_idac_sar9_amb_r_code = 8'h12;
		i_idac_sar9_amb_ir_code = 8'h34;
		i_idac_sar9_dc_r_code = 8'h56;
		i_idac_sar9_dc_ir_code = 8'h78;
		i_idac_sar15_amb_r_code = 8'h21;
		i_idac_sar15_amb_ir_code = 8'h43;
		i_idac_sar15_dc_r_code = 8'h65;
		i_idac_sar15_dc_ir_code = 8'h87;
		error_count = 0;

		#1375 i_rstn = 1'b1;

		// Confirm both wrappers forward the original 2 MHz waveform unchanged.
		repeat(8)begin
			@(posedge i_clk);
			#1;
			if((clk_2m_sar9 !== 1'b1) || (clk_2m_sar15 !== 1'b1))begin
				error_count = error_count + 1;
				$display("ERROR: forwarded 2 MHz clock was not high at %0t ns", $time);
			end
			@(negedge i_clk);
			#1;
			if((clk_2m_sar9 !== 1'b0) || (clk_2m_sar15 !== 1'b0))begin
				error_count = error_count + 1;
				$display("ERROR: forwarded 2 MHz clock was not low at %0t ns", $time);
			end
		end

		fork
			begin
				@(posedge frame_start_sar9);
				frame_sar9_first = $time;
			end
			begin
				@(posedge frame_start_sar15);
				frame_sar15_first = $time;
			end
		join

		if(frame_sar9_first != frame_sar15_first)begin
			error_count = error_count + 1;
			$display("ERROR: SAR9 and SAR15 first frame boundaries differ");
		end

		fork
			begin
				@(posedge clk_q2_sar9);
				q2_sar9_red_rise = $time;
				@(posedge clk_q2_sar9);
				q2_sar9_ir_rise = $time;
			end
			begin
				@(posedge clk_q2_sar15);
				q2_sar15_red_rise = $time;
				@(posedge clk_q2_sar15);
				q2_sar15_ir_rise = $time;
			end
			begin
				@(posedge clk_q3_sar9);
				q3_sar9_red_rise = $time;
				@(negedge clk_q3_sar9);
				q3_sar9_red_fall = $time;
				@(posedge clk_q3_sar9);
				q3_sar9_ir_rise = $time;
				@(negedge clk_q3_sar9);
				q3_sar9_ir_fall = $time;
			end
			begin
				@(posedge clk_q3_sar15);
				q3_sar15_red_rise = $time;
				@(negedge clk_q3_sar15);
				q3_sar15_red_fall = $time;
				@(posedge clk_q3_sar15);
				q3_sar15_ir_rise = $time;
				@(negedge clk_q3_sar15);
				q3_sar15_ir_fall = $time;
			end
		join

		if((q2_sar9_ir_rise - q2_sar9_red_rise) != 80000)begin
			error_count = error_count + 1;
			$display("ERROR: SAR9 Q2 R/IR offset is not 80 us");
		end
		if((q2_sar15_ir_rise - q2_sar15_red_rise) != 80000)begin
			error_count = error_count + 1;
			$display("ERROR: SAR15 Q2 R/IR offset is not 80 us");
		end
		if((q3_sar9_ir_rise - q3_sar9_red_rise) != 80000)begin
			error_count = error_count + 1;
			$display("ERROR: SAR9 Q3 R/IR offset is not 80 us");
		end
		if((q3_sar15_ir_rise - q3_sar15_red_rise) != 80000)begin
			error_count = error_count + 1;
			$display("ERROR: SAR15 Q3 R/IR offset is not 80 us");
		end

		if((q3_sar9_red_rise + q3_sar9_red_fall) !=
			(q3_sar15_red_rise + q3_sar15_red_fall))begin
			error_count = error_count + 1;
			$display("ERROR: SAR9 and SAR15 red Q3 centers are not aligned");
		end
		if((q3_sar9_ir_rise + q3_sar9_ir_fall) !=
			(q3_sar15_ir_rise + q3_sar15_ir_fall))begin
			error_count = error_count + 1;
			$display("ERROR: SAR9 and SAR15 infrared Q3 centers are not aligned");
		end

		fork
			begin
				@(posedge frame_start_sar9);
				frame_sar9_second = $time;
			end
			begin
				@(posedge frame_start_sar15);
				frame_sar15_second = $time;
			end
		join

		if((frame_sar9_second - frame_sar9_first) != 312500)begin
			error_count = error_count + 1;
			$display("ERROR: SAR9 frame period is not 312.5 us");
		end
		if((frame_sar15_second - frame_sar15_first) != 312500)begin
			error_count = error_count + 1;
			$display("ERROR: SAR15 frame period is not 312.5 us");
		end
		if(frame_sar9_second != frame_sar15_second)begin
			error_count = error_count + 1;
			$display("ERROR: SAR9 and SAR15 second frame boundaries differ");
		end

		if(error_count == 0)begin
			$display("PASS: 3200 Hz frame, 80 us R/IR offsets, and Q3-center alignment verified.");
		end else begin
			$display("FAIL: 3200 Hz timing regression detected %0d errors.", error_count);
		end
		#1000 $finish;
	end

	initial begin
		#2000000;
		$display("FAIL: 3200 Hz timing regression timeout.");
		$finish;
	end

	ppg_timing_sar9_3200hz ppg_timing_sar9_Inst_dut(
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
		.o_frame_start_3200hz(frame_start_sar9),
		.o_clk_2m(clk_2m_sar9),
		.o_clk_q2_low(clk_q2_sar9),
		.o_clk_q3_low(clk_q3_sar9)
	);

	ppg_timing_sar15_3200hz ppg_timing_sar15_Inst_dut(
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
		.i_idac_sar15_amb_r_code(i_idac_sar15_amb_r_code),
		.i_idac_sar15_amb_ir_code(i_idac_sar15_amb_ir_code),
		.i_idac_sar15_dc_r_code(i_idac_sar15_dc_r_code),
		.i_idac_sar15_dc_ir_code(i_idac_sar15_dc_ir_code),
		.o_frame_start_3200hz(frame_start_sar15),
		.o_clk_2m(clk_2m_sar15),
		.o_clk_q2_low(clk_q2_sar15),
		.o_clk_q3_low(clk_q3_sar15)
	);

endmodule
