`timescale 1ns/1ps
module tb_A_monitor;
integer cnt_red_response,cnt_ir_response,cnt_measurement_result_valid,cnt_error;reg flag_raw_arith_unbounded;
reg o_error_sticky,o_scheduler_completion_mismatch_sticky,o_scheduler_protocol_error_sticky,o_ami_integration_protocol_error_sticky,o_ssw_switch_protocol_error_sticky,o_ssw_transaction_mismatch_sticky,o_characterization_protocol_error_sticky,o_result_discard_summary_sticky;
task check_counts;begin
		if((cnt_red_response + cnt_ir_response - cnt_measurement_result_valid) > 1) begin
			$display("FAIL GROUP5_NO_STALE_CONTEXT measurement_result_valid=%0d falls more than 1 short of real_red+real_ir=%0d, possible accumulated loss/owner leakage beyond the one legitimate STOP-boundary discard-pending transaction",
				cnt_measurement_result_valid, cnt_red_response + cnt_ir_response);
			cnt_error = cnt_error + 1;
		end else if(cnt_measurement_result_valid > (cnt_red_response + cnt_ir_response)) begin
			$display("FAIL GROUP5_NO_STALE_CONTEXT measurement_result_valid=%0d exceeds real_red+real_ir=%0d, possible duplicated result",
				cnt_measurement_result_valid, cnt_red_response + cnt_ir_response);
			cnt_error = cnt_error + 1;
		end else if(flag_raw_arith_unbounded) begin
			$display("FAIL GROUP5_NO_STALE_CONTEXT slope/baseline saturation was observed during the run, see the earlier GROUP5_BOUNDED_RAW_ARITHMETIC FAIL for detail");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP5_NO_STALE_CONTEXT measurement_result_valid=%0d within 1 of real_red+real_ir=%0d after STOP drain (deficit of 0 or 1 is the documented legitimate STOP-boundary discard-pending case), no RAW-arithmetic saturation observed",
				cnt_measurement_result_valid, cnt_red_response + cnt_ir_response);
		end

end endtask
task check_sticky;begin
		if(o_error_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_scheduler_completion_mismatch_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_scheduler_completion_mismatch_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_scheduler_protocol_error_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_scheduler_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_ami_integration_protocol_error_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_ami_integration_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_ssw_switch_protocol_error_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_ssw_switch_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_ssw_transaction_mismatch_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_ssw_transaction_mismatch_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_characterization_protocol_error_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_characterization_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_result_discard_summary_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_result_discard_summary_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP5_PROTOCOL_STICKY all blocking scheduler/AMI/SSW/characterization/discard protocol-error stickies stayed 0 across real_red=%0d real_ir=%0d transactions",
				cnt_red_response, cnt_ir_response);
		end
end endtask
initial begin
cnt_red_response=10;cnt_ir_response=10;cnt_measurement_result_valid=20;flag_raw_arith_unbounded=0;cnt_error=0;check_counts;if(cnt_error!=0)$fatal(1,"exact positive rejected");
cnt_measurement_result_valid=19;cnt_error=0;check_counts;if(cnt_error!=0)$fatal(1,"permitted deficit1 rejected");
cnt_measurement_result_valid=18;cnt_error=0;check_counts;if(cnt_error!=1)$fatal(1,"loss2 escaped");
cnt_measurement_result_valid=21;cnt_error=0;check_counts;if(cnt_error!=1)$fatal(1,"duplicate escaped");
cnt_measurement_result_valid=20;flag_raw_arith_unbounded=1;cnt_error=0;check_counts;if(cnt_error!=1)$fatal(1,"saturation escaped");
o_error_sticky=0;o_scheduler_completion_mismatch_sticky=0;o_scheduler_protocol_error_sticky=0;o_ami_integration_protocol_error_sticky=0;o_ssw_switch_protocol_error_sticky=0;o_ssw_transaction_mismatch_sticky=0;o_characterization_protocol_error_sticky=0;o_result_discard_summary_sticky=0;cnt_error=0;check_sticky;if(cnt_error!=0)$fatal(1,"sticky positive rejected");
o_error_sticky=1;cnt_error=0;check_sticky;if(cnt_error!=1)$fatal(1,"sticky escaped: o_error_sticky");o_error_sticky=0;
o_scheduler_completion_mismatch_sticky=1;cnt_error=0;check_sticky;if(cnt_error!=1)$fatal(1,"sticky escaped: o_scheduler_completion_mismatch_sticky");o_scheduler_completion_mismatch_sticky=0;
o_scheduler_protocol_error_sticky=1;cnt_error=0;check_sticky;if(cnt_error!=1)$fatal(1,"sticky escaped: o_scheduler_protocol_error_sticky");o_scheduler_protocol_error_sticky=0;
o_ami_integration_protocol_error_sticky=1;cnt_error=0;check_sticky;if(cnt_error!=1)$fatal(1,"sticky escaped: o_ami_integration_protocol_error_sticky");o_ami_integration_protocol_error_sticky=0;
o_ssw_switch_protocol_error_sticky=1;cnt_error=0;check_sticky;if(cnt_error!=1)$fatal(1,"sticky escaped: o_ssw_switch_protocol_error_sticky");o_ssw_switch_protocol_error_sticky=0;
o_ssw_transaction_mismatch_sticky=1;cnt_error=0;check_sticky;if(cnt_error!=1)$fatal(1,"sticky escaped: o_ssw_transaction_mismatch_sticky");o_ssw_transaction_mismatch_sticky=0;
o_characterization_protocol_error_sticky=1;cnt_error=0;check_sticky;if(cnt_error!=1)$fatal(1,"sticky escaped: o_characterization_protocol_error_sticky");o_characterization_protocol_error_sticky=0;
o_result_discard_summary_sticky=1;cnt_error=0;check_sticky;if(cnt_error!=1)$fatal(1,"sticky escaped: o_result_discard_summary_sticky");o_result_discard_summary_sticky=0;

$display("A_MONITOR_NEGATIVES_CONFIRMED");$finish;end
endmodule
