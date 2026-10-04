from sim import *
top='tb_ppg_adc_measurement_idac_integration'
tb=(SNAP/'rtl/ppg_adc_measurement_idac_integration'/f'{top}.v').read_text(encoding='utf-8')
prefix='\n'.join(tb.splitlines()[:1300])+'\n'
sources=[str(p.relative_to(SNAP)).replace('\\','/') for p in sorted(SNAP.glob('rtl/*/ppg_*.v'))]
body='''
        cnt_watchdog=0;
        while(!o_calibration_sample_valid && cnt_watchdog<200)begin
            pulse_safe_boundary;@(negedge i_clk);cnt_watchdog=cnt_watchdog+1;
        end
        $display("B_SETUP_DIAG startup=%b busy=%b req=%b reason=%b inner=%b outer=%b fault=%b",o_startup_search_complete,o_amb_recheck_busy,o_calibration_sample_valid,o_calibration_request_reason,dut.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_sample_inflight,dut.flag_calibration_request_inflight,o_wrapper_fault_blocking);
        check_case("BSETUP",o_amb_recheck_busy && o_calibration_sample_valid && o_calibration_request_reason==2'b01);
        if(cnt_fail!=0)$fatal(1,"B_SETUP_FAILED");
        cnt_fire_before=cnt_fire;
        @(negedge i_clk);i_calibration_sample_ready=1;
        @(negedge i_clk);i_calibration_sample_ready=0;
        repeat(2)@(negedge i_clk);
        $display("B_PRE_DEADLINE outer=%b inner=%b adc=%b req=%b",dut.flag_calibration_request_inflight,dut.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_sample_inflight,dut.flag_adc_transaction_inflight,o_calibration_sample_valid);
        @(negedge i_clk);i_cal_owner_deadline_event=1;
        @(negedge i_clk);i_cal_owner_deadline_event=0;
        pulse_calibration_frame_complete;
        for(idx_sample=0;idx_sample<100;idx_sample=idx_sample+1)begin
            pulse_safe_boundary;
        end
        $display("B_POST_DEADLINE outer=%b inner=%b adc=%b req=%b busy=%b physidle=%b chainidle=%b fault=%b ownerdelta=%0d",dut.flag_calibration_request_inflight,dut.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_sample_inflight,dut.flag_adc_transaction_inflight,o_calibration_sample_valid,o_amb_recheck_busy,i_adc_idle,o_adc_chain_idle,o_wrapper_fault_blocking,cnt_fire-cnt_fire_before);
        check_case("BRETRY",o_calibration_sample_valid && o_amb_recheck_busy && cnt_fire==cnt_fire_before);
        @(negedge i_clk);i_run_enable=0;
        repeat(10)@(negedge i_clk);
        check_case("BCLEAR",!o_amb_recheck_busy && !dut.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_sample_inflight);
        if(cnt_fail!=0)$fatal(1,"B_PERIODIC_DEADLINE_RETRY_FAIL");
        $finish;
    end
    initial begin #2000000;$fatal(1,"B_TIMEOUT");end
endmodule
'''
if not (OUT/'evidence/recheck_deadline_v4/result.json').exists():
 sim('recheck_deadline_v4','tb_ppg_adc_measurement_idac_integration',sources,prefix+body)
rp=SNAP/'rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v'
rtl=rp.read_text(encoding='utf-8')
lines=rtl.splitlines(keepends=True)
assert 'assign o_calibration_sample_valid' in lines[207]
assert lines[207].count(" && (flag_sample_inflight == 1'b0)")==3
lines[207]=lines[207].replace(" && (flag_sample_inflight == 1'b0)",'')
mut=''.join(lines)
sim('recheck_deadline_gate_counterfactual',top,sources,prefix+body,{rp.name:mut})
control='''
        check_case("BSETUP",o_startup_search_complete && o_amb_recheck_busy);
        complete_wrapper_recheck;
        check_case("BCHAIN",!o_amb_recheck_busy && !o_wrapper_fault_blocking);
        if(cnt_fail!=0)$fatal(1,"B_CHAIN_CONTROL_FAIL");$finish;
    end
    initial begin #2000000;$fatal(1,"B_TIMEOUT");end
endmodule
'''
# The unchanged real-result control already passed; do not repeat it here.
