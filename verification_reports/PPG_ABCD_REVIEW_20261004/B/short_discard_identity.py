from sim import *
top='tb_ppg_adc_measurement_idac_integration'
tb=(SNAP/'rtl/ppg_adc_measurement_idac_integration'/f'{top}.v').read_text(encoding='utf-8')
prefix='\n'.join(tb.splitlines()[:1120])+'\n'
sources=[str(p.relative_to(SNAP)).replace('\\','/') for p in sorted(SNAP.glob('rtl/*/ppg_*.v'))]
for second in [False,True]:
 body='''
        repeat(4)@(negedge i_clk);i_rstn=1;i_run_enable=1;
        pulse_start_ack;complete_wrapper_startup;pulse_safe_boundary;
        check_case("BSETUP",o_startup_search_complete && !o_wrapper_fault_blocking);
        i_measurement_result_ready=0;
        start_transaction(FRAME_NORMAL,0,0,16'd90,16'd900);
        drive_adc_done(0,10'b0000100101,0);
        wait_measurement_result;
        check_case("BAHELD",o_measurement_result_valid && o_result_frame_id==90 && o_result_sample_index==900);
'''
 if second:
  body+='''
        start_transaction(FRAME_NORMAL,0,1,16'd91,16'd901);
        drive_adc_done(0,10'b0000100101,0);
        repeat(30)@(negedge i_clk);
'''
 body+='''
        $display("B_PRE_DISCARD resultframe=%0d resultsample=%0d upstreamframe=%0d upstreamsample=%0d",o_result_frame_id,o_result_sample_index,dut.dec_measurement_frame_id,dut.dec_measurement_sample_index);
        @(negedge i_clk);i_control_abort_event=1;
        @(negedge i_clk);i_control_abort_event=0;
        $display("B_POST_DISCARD event=%b frame=%0d sample=%0d color=%b",o_measurement_result_discard_event,o_measurement_result_discard_frame_id,o_measurement_result_discard_sample_index,dut.o_measurement_result_discard_color_ir);
        check_case("BIDISC",o_measurement_result_discard_event && o_measurement_result_discard_frame_id==90 && o_measurement_result_discard_sample_index==900 && !dut.o_measurement_result_discard_color_ir);
        if(cnt_fail!=0)$fatal(1,"B_DISCARD_IDENTITY_FAIL");$finish;
    end
    initial begin #2000000;$fatal(1,"B_TIMEOUT");end
endmodule
'''
 sim('discard_identity_'+('two' if second else 'one'),top,sources,prefix+body)
