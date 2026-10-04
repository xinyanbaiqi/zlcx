from sim import *
top='tb_ppg_adc_measurement_idac_integration'
tb=(SNAP/'rtl/ppg_adc_measurement_idac_integration'/f'{top}.v').read_text(encoding='utf-8')
prefix='\n'.join(tb.splitlines()[:1300])+'\n'
sources=[str(p.relative_to(SNAP)).replace('\\','/') for p in sorted(SNAP.glob('rtl/*/ppg_*.v'))]
for cancel in ['abort','stop']:
 event='i_control_abort_event' if cancel=='abort' else 'i_stop_ack_event'
 body=f'''
        cnt_watchdog=0;
        while(!o_calibration_sample_valid && cnt_watchdog<200)begin
            pulse_safe_boundary;@(negedge i_clk);cnt_watchdog=cnt_watchdog+1;
        end
        check_case("BSETUP",o_amb_recheck_busy && o_calibration_sample_valid && o_calibration_request_reason==2'b01);
        if(cnt_fail!=0)$fatal(1,"B_SETUP_FAILED");
        cnt_fire_before=cnt_fire;
        $display("B_PRE_CANCEL busy=%b req=%b pwiempty=%b adc=%b inner=%b",o_amb_recheck_busy,o_calibration_sample_valid,dut.flag_pwi_detection_datapath_empty,dut.flag_adc_transaction_inflight,dut.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_sample_inflight);
        @(negedge i_clk);i_allow_new_transaction=0;{event}=1;
        #1;$display("B_CANCEL_EVENT pwiempty=%b detectiondiscard=%b",dut.flag_pwi_detection_datapath_empty,o_detection_discard_event);
        @(negedge i_clk);{event}=0;
        repeat(50)@(negedge i_clk);
        $display("B_POST_CANCEL busy=%b inner=%b req=%b datapath_empty=%b adc=%b physidle=%b ownerdelta=%0d",o_amb_recheck_busy,dut.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_sample_inflight,o_calibration_sample_valid,o_datapath_empty,dut.flag_adc_transaction_inflight,i_adc_idle,cnt_fire-cnt_fire_before);
        check_case("BCLEAR",!o_amb_recheck_busy && !dut.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_sample_inflight && o_datapath_empty);
        @(negedge i_clk);i_run_enable=0;
        repeat(10)@(negedge i_clk);
        check_case("BDROPR",!o_amb_recheck_busy && !dut.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_sample_inflight);
        if(cnt_fail!=0)$fatal(1,"B_PERIODIC_CANCEL_FAIL");$finish;
    end
    initial begin #2000000;$fatal(1,"B_TIMEOUT");end
endmodule
'''
 sim('recheck_cancel_'+cancel,top,sources,prefix+body)
