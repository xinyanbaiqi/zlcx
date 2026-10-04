`timescale 1ns/1ps
module tb_A_monitor;
	localparam integer C_RAW12_TARGET_RED_SAMPLES = 4000; 
	localparam integer C_RAW12_TARGET_IR_SAMPLES = 4000; 
	localparam time C_PPG_MIN_DURATION_NS = 64'd10000000000; 
integer cnt_red_response,cnt_ir_response,cnt_error;time reg_measurement_elapsed_time;reg flag_global_timeout;
task check_original;begin
		if(flag_global_timeout) begin
			$display("FAIL RAW-12 global watchdog fired before RED/IR both reached target red=%0d ir=%0d elapsed_ns=%0d",
				cnt_red_response, cnt_ir_response, reg_measurement_elapsed_time);
			cnt_error = cnt_error + 1;
		end else if(cnt_red_response < C_RAW12_TARGET_RED_SAMPLES) begin
			$display("FAIL RAW-12 RED sample count insufficient red=%0d target=%0d", cnt_red_response, C_RAW12_TARGET_RED_SAMPLES);
			cnt_error = cnt_error + 1;
		end else if(cnt_ir_response < C_RAW12_TARGET_IR_SAMPLES) begin
			$display("FAIL RAW-12 IR sample count insufficient ir=%0d target=%0d", cnt_ir_response, C_RAW12_TARGET_IR_SAMPLES);
			cnt_error = cnt_error + 1;
		end else if(reg_measurement_elapsed_time < C_PPG_MIN_DURATION_NS) begin
			$display("FAIL RAW-12 elapsed time insufficient elapsed_ns=%0d min_ns=%0d red=%0d ir=%0d",
				reg_measurement_elapsed_time, C_PPG_MIN_DURATION_NS, cnt_red_response, cnt_ir_response);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS RAW-12 post-START run covers real_red=%0d real_ir=%0d elapsed_ns=%0d (>=%0d) with no 32-bit overflow (time-typed)",
				cnt_red_response, cnt_ir_response, reg_measurement_elapsed_time, C_PPG_MIN_DURATION_NS);
		end

end endtask
initial begin
cnt_red_response=C_RAW12_TARGET_RED_SAMPLES;cnt_ir_response=C_RAW12_TARGET_IR_SAMPLES;reg_measurement_elapsed_time=C_PPG_MIN_DURATION_NS;flag_global_timeout=0;cnt_error=0;check_original;if(cnt_error!=0)$fatal(1,"positive rejected");
cnt_red_response=C_RAW12_TARGET_RED_SAMPLES-1;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"RED deficit escaped");cnt_red_response=C_RAW12_TARGET_RED_SAMPLES;
cnt_ir_response=C_RAW12_TARGET_IR_SAMPLES-1;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"IR deficit escaped");cnt_ir_response=C_RAW12_TARGET_IR_SAMPLES;
reg_measurement_elapsed_time=C_PPG_MIN_DURATION_NS-1;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"short time escaped");reg_measurement_elapsed_time=C_PPG_MIN_DURATION_NS;
flag_global_timeout=1;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"watchdog escaped");
$display("A_MONITOR_NEGATIVES_CONFIRMED");$finish;end
endmodule
