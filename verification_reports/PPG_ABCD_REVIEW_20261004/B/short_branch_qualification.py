from sim import *
top='tb_ppg_adc_measurement_idac_integration'
tb=(SNAP/'rtl/ppg_adc_measurement_idac_integration'/f'{top}.v').read_text(encoding='utf-8')
prefix='\n'.join(tb.splitlines()[:1613])+'\n'
sources=[str(p.relative_to(SNAP)).replace('\\','/') for p in sorted(SNAP.glob('rtl/*/ppg_*.v'))]
body='''
        @(negedge i_clk);
        $display("B_BRANCH_DIAG window=%b firbusy=%b detpending=%b measpending=%b samplequal=%b frame=%0d expected=%0d",flag_n08_window_hit,flag_n08_fir_busy_observed,dut.flag_detection_pending,dut.flag_measurement_pending,dut.result_sample_valid_o,o_result_frame_id,n08_expect_frame_id);
        check_case("BWINDO",flag_n08_window_hit && flag_n08_fir_busy_observed && dut.flag_detection_pending && !dut.flag_measurement_pending);
        check_case("BQUALI",dut.result_sample_valid_o===1'b1);
        if(cnt_fail!=0)$fatal(1,"B_BRANCH_QUALIFICATION_FAIL");$finish;
    end
    initial begin #2000000;$fatal(1,"B_TIMEOUT");end
endmodule
'''
sim('branch_qualification_v2',top,sources,prefix+body)
p=SNAP/'rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v'
rtl=p.read_text(encoding='utf-8');lines=rtl.splitlines(keepends=True)
assert "else if(flag_measurement_transfer == 1'b1)begin" in lines[1237]
lines[1237]=lines[1237].replace("flag_measurement_transfer == 1'b1","flag_measurement_transfer == 1'b1 && !flag_detection_pending")
sim('branch_qualification_counterfactual_v2',top,sources,prefix+body,{p.name:''.join(lines)})
