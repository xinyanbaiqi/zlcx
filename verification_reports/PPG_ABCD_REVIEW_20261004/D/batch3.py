"""复用原系统TB的短场景；外部变异副本只验证覆盖，不修改基准RTL/TB。"""
import sys
import review_driver as d

def lines(path,a,b):
    return '\n'.join((d.SOURCE/path).read_text(encoding='utf-8-sig').splitlines()[a-1:b])+'\n'

def files(top_mutant=None):
    folder=d.SOURCE/'rtl/ppg_chip_digital_top'
    result=[]
    for entry in (folder/'xsim_chip_digital_top_filelist.f').read_text(encoding='utf-8').splitlines():
        if entry and not entry.startswith('tb_') and not entry.startswith('ppg_chip_digital_top'):
            path=(folder/entry).resolve()
            result.append(str(top_mutant) if top_mutant and path.name=='ppg_control_top.v' else str(path))
    return result

def run(name,tb,rtl,label):
    d.simulate(name,tb,rtl)
    output=d.EVIDENCE/name
    for suffix in ('compile.log','run.log','result.json'):
        if (output/suffix).exists(): (output/suffix).replace(output/(label+'.'+suffix))

def ilm():
    path='rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v'
    monitor='''
    integer d_observed_led_violation=0;
    always @(negedge i_clk) begin
        if(i_rstn && (o_lifecycle_state==ST_RUN) && o_clk_q3_low && o_en_test && (o_leddac !== 8'h00))
            d_observed_led_violation=d_observed_led_violation+1;
    end
'''
    tb=lines(path,1,1306)+monitor+lines(path,1308,1355)+lines(path,1658,1699)+'''
        $display("D_ILM_FRAGMENT errors=%0d observed_led_violation=%0d",cnt_error,d_observed_led_violation);
        if(cnt_error==0) $display("D_ILM_ORIGINAL_CHECKS_PASS");
        else $display("D_ILM_ORIGINAL_CHECKS_FAIL");
        $finish;
    end
endmodule
'''
    own=d.EVIDENCE/'ilm04_fragment.v'; own.write_text(tb,encoding='utf-8')
    original=(d.SOURCE/'rtl/ppg_control_top/ppg_control_top.v').read_text(encoding='utf-8-sig')
    needle='assign o_leddac = ssw_leddac_o;'
    assert original.count(needle)==1
    mutant=d.EVIDENCE/'ilm_led_q3_mutant.v'
    mutant.write_text(original.replace(needle,"assign o_leddac = (wrapper_input_source_o && ssw_clk_q3_low_o) ? 8'h01 : ssw_leddac_o;"),encoding='utf-8')
    negative=d.EVIDENCE/'ilm04_wrong_expected.v'
    needle="(o_leddac != 8'h00)"
    assert tb.count(needle)>=1
    negative.write_text(tb.replace(needle,"(o_leddac != 8'h01)"),encoding='utf-8')
    run('tb_ppg_control_top_input_light_static_matrix',own,files(),'fragment_positive')
    run('tb_ppg_control_top_input_light_static_matrix',own,files(mutant),'fragment_q3_mutant')
    run('tb_ppg_control_top_input_light_static_matrix',negative,files(),'fragment_negative')

def ise(mutant_only=False):
    path='rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v'
    monitor='''
    integer d_observed_active_bus_violation=0;
    always @(negedge i_clk) begin
        if(flag_check_sar9_phase && o_clk_q3_low && (o_idac_sar9ambn_low !== 8'hA5))
            d_observed_active_bus_violation=d_observed_active_bus_violation+1;
    end
'''
    tb=lines(path,1,878)+monitor+lines(path,879,922)+lines(path,926,981)+'''
        $display("D_ISE_FRAGMENT errors=%0d observed_active_bus_violation=%0d zero_checks=%0d",cnt_error,d_observed_active_bus_violation,cnt_sar15_zero_checks);
        if(cnt_error==0) $display("D_ISE_ORIGINAL_CHECKS_PASS");
        else $display("D_ISE_ORIGINAL_CHECKS_FAIL");
        $finish;
    end
endmodule
'''
    own=d.EVIDENCE/'ise04_fragment.v'; own.write_text(tb,encoding='utf-8')
    original=(d.SOURCE/'rtl/ppg_control_top/ppg_control_top.v').read_text(encoding='utf-8-sig')
    needle='assign o_idac_sar9ambn_low = ssw_idac_sar9ambn_low_o;'
    assert original.count(needle)==1
    replacement='''reg [3:0] d_q3_count;
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) d_q3_count <= 0;
        else if(!ssw_clk_q3_low_o) d_q3_count <= 0;
        else if(d_q3_count!=4'hF) d_q3_count <= d_q3_count+1'b1;
    end
    assign o_idac_sar9ambn_low = (ssw_clk_q3_low_o && d_q3_count==4'd0) ? (ssw_idac_sar9ambn_low_o ^ 8'h01) : ssw_idac_sar9ambn_low_o;'''
    mutant=d.EVIDENCE/'ise_active_onecycle_mutant.v';mutant.write_text(original.replace(needle,replacement),encoding='utf-8')
    needle="(reg_seen_sar9_ambn !== 8'hA5)"
    assert tb.count(needle)==1
    negative=d.EVIDENCE/'ise04_wrong_expected.v';negative.write_text(tb.replace(needle,"(reg_seen_sar9_ambn !== 8'hA4)"),encoding='utf-8')
    if mutant_only:
        output=d.EVIDENCE/'tb_ppg_control_top_idac_bus_isolation'
        for suffix in ('compile.log','run.log','result.json'):
            old=output/('fragment_onecycle_mutant.'+suffix)
            if old.exists(): old.replace(output/('nontrigger_setup.'+suffix))
        run('tb_ppg_control_top_idac_bus_isolation',own,files(mutant),'fragment_onecycle_mutant')
        return
    run('tb_ppg_control_top_idac_bus_isolation',own,files(),'fragment_positive')
    run('tb_ppg_control_top_idac_bus_isolation',own,files(mutant),'fragment_onecycle_mutant')
    run('tb_ppg_control_top_idac_bus_isolation',negative,files(),'fragment_negative')

if __name__=='__main__':
    if sys.argv[1]=='ilm': ilm()
    elif sys.argv[1]=='ise': ise()
    elif sys.argv[1]=='ise_mutant': ise(True)
