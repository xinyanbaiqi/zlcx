module tb_A_checker;
reg flag_pending_before_fine_window;integer cnt_frame_drive,cnt_frame_before_pending,cnt_error;
task check_original;begin
			if(!flag_pending_before_fine_window) begin
				$display("FAIL RRC-01 recheck pending never asserted within %0d driven frames -- interval/frame-count check is vacuous", cnt_frame_drive);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-01 recheck pending asserted after %0d completed real NORMAL macro frames (configured interval=30, counted by real sched_normal_frame_complete_event_o pulses, not by ADC/owner-commit events)", cnt_frame_before_pending);
			end
end endtask
initial begin
cnt_frame_drive=80;flag_pending_before_fine_window=1;cnt_error=0;cnt_frame_before_pending=30;check_original;if(cnt_error!=0)$fatal(1,"nominal rejected");
cnt_frame_before_pending=1;cnt_error=0;check_original;if(cnt_error!=0)$fatal(1,"bad interval unexpectedly rejected");
flag_pending_before_fine_window=0;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"absence negative did not fire");
$display("A_RRC01_CHECKER_CONFIRMED nominal30_pass bad1_pass absence_fail");$finish;
end endmodule
