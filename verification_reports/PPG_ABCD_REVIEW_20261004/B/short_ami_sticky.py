from sim import *
top='tb_ppg_adc_measurement_idac_integration'
tb=(SNAP/'rtl/ppg_adc_measurement_idac_integration'/f'{top}.v').read_text(encoding='utf-8')
prefix='\n'.join(tb.splitlines()[:1120])+'\n'
sources=[str(p.relative_to(SNAP)).replace('\\','/') for p in sorted(SNAP.glob('rtl/*/ppg_*.v'))]
body='''
        repeat(4)@(negedge i_clk);i_rstn=1;i_run_enable=1;i_idac_mode=0;
        pulse_start_ack;pulse_safe_boundary;repeat(5)@(negedge i_clk);
        @(negedge i_clk);i_transaction_frame_type=2'b11;i_transaction_start_valid=1;
        repeat(2)@(negedge i_clk);i_transaction_start_valid=0;
        check_case("BSTICK",o_integration_protocol_error_sticky && !o_wrapper_fault_blocking && !dut.flag_adc_transaction_inflight);
        pulse_stop_ack;@(negedge i_clk);i_run_enable=0;
        repeat(20)@(negedge i_clk);
        check_case("BDRAIN",o_datapath_empty && o_integration_protocol_error_sticky);
        @(negedge i_clk);i_transaction_frame_type=FRAME_NORMAL;i_run_generation=2;i_run_enable=1;
        pulse_start_ack;repeat(3)@(negedge i_clk);
        $display("B_STICKY_AFTER_START sticky=%b blocking=%b inflight=%b",o_integration_protocol_error_sticky,o_wrapper_fault_blocking,dut.flag_adc_transaction_inflight);
        check_case("BKEEPH",o_integration_protocol_error_sticky);
        @(negedge i_clk);i_diag_clear_event=1;
        @(negedge i_clk);i_diag_clear_event=0;
        check_case("BDIAGC",!o_integration_protocol_error_sticky);
        if(cnt_fail!=0)$fatal(1,"B_AMI_STICKY_START_FAIL");$finish;
    end
    initial begin #2000000;$fatal(1,"B_TIMEOUT");end
endmodule
'''
sim('ami_sticky_start',top,sources,prefix+body)
