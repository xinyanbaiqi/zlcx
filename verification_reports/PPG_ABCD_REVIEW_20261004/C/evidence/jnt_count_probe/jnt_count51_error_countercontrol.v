`timescale 1ns/1ps
module tb_C_jnt_count;
localparam integer C_JNT_REQUIRED_SUBCHECKS=54;
integer cnt_run_jnt_checked,cnt_run_jnt_pass,cnt_run_jnt_fail,cnt_error;
reg flag_jnt_baseline_pass,flag_jnt_manual_adc_hold;
reg [8*32-1:0] reg_jnt_first_failure_id;
task jnt_reset_release; begin end endtask
initial begin
cnt_run_jnt_checked=51; cnt_run_jnt_pass=51; cnt_run_jnt_fail=0; cnt_error=0; reg_jnt_first_failure_id="NONE";
		flag_jnt_baseline_pass = (cnt_run_jnt_checked == C_JNT_REQUIRED_SUBCHECKS) && (cnt_run_jnt_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_run_jnt_fail == 0);
		if(flag_jnt_baseline_pass) begin
			$display("JNT_BASELINE checked=%0d pass=%0d required=%0d status=PASS", cnt_run_jnt_checked, cnt_run_jnt_pass, C_JNT_REQUIRED_SUBCHECKS);
		end else begin
			$display("JNT_BASELINE checked=%0d pass=%0d fail=%0d required=%0d first_failure=%0s status=FAIL", cnt_run_jnt_checked, cnt_run_jnt_pass, cnt_run_jnt_fail, C_JNT_REQUIRED_SUBCHECKS, reg_jnt_first_failure_id);
			cnt_error = cnt_error + ((cnt_run_jnt_fail > 0) ? cnt_run_jnt_fail : 1);
		end
		flag_jnt_manual_adc_hold = 1'b0;
		jnt_reset_release;
if(cnt_error==0) $display("GROUP_WOULD_PASS error_count=0");
if(51<54 && cnt_error==0) $fatal(1,"C_JNT_COUNT_GUARD_FAIL checked=%0d pass=%0d flag=%b errors=%0d",cnt_run_jnt_checked,cnt_run_jnt_pass,flag_jnt_baseline_pass,cnt_error);
if(51==54 && !flag_jnt_baseline_pass) $fatal(1,"C_JNT_CONTROL_FAIL");
$display("C_JNT_GUARD_CONTROL_PASS count=%0d errors=%0d",cnt_run_jnt_checked,cnt_error); $finish;
end
endmodule
