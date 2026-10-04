"""D组外部短对照；不解析Verilog，源文件仅按已实读唯一文本制作副本。"""
import csv
import json
import sys
from pathlib import Path
import review_driver as d

def simulate(label, name, tb, files):
    d.simulate(name, tb, files)
    folder = d.EVIDENCE / name
    for suffix in ('compile.log', 'run.log', 'result.json'):
        if (folder / suffix).exists():
            (folder / suffix).replace(folder / (label + '.' + suffix))

def stop_probe():
    relative = 'rtl/ppg_system_config_manager/tb_ppg_system_config_manager.v'
    lines = (d.SOURCE / relative).read_text(encoding='utf-8').splitlines()
    # 保留入库TB的复位/合法COMMIT/START前置比较；替换后续激励，不注入内部状态。
    prefix = '\n'.join(lines[:260])
    suffix = '\n'.join(lines[935:])
    stimulus = r'''
        if(cnt_error != 0) $fatal(1, "D_SETUP_FAIL errors=%0d", cnt_error);
        @(negedge i_clk);
        i_analog_safe=0; i_adc_idle=0; i_datapath_empty=0; i_idac_idle=0;
        i_stop_event=1;
        if($test$plusargs("START_COLLISION")) i_start_event=1;
        if($test$plusargs("COMMIT_COLLISION")) i_config_update_event=1;
        if($test$plusargs("CLEAR_COLLISION")) i_status_clear_event=1;
        @(posedge i_clk); #1;
        $display("D_STOP_OBSERVE state=%b run=%b allow=%b ack=%b episode=%b error=%b code=%h",
            o_lifecycle_state,o_run_enable,o_allow_new_transaction,o_stop_ack_event,
            o_stop_episode_active,o_error_event,o_last_error_code);
        if(o_lifecycle_state !== ST_STOPPING || o_run_enable !== 0 ||
           o_allow_new_transaction !== 0 || o_stop_ack_event !== 1 ||
           o_stop_episode_active !== 1) $fatal(1, "D_STOP_FAIL: STOP did not win");
        $display("D_STOP_PASS"); $finish;
    end
'''
    probe=d.EVIDENCE/'mgr_stop_probe.v'
    probe.write_text(prefix+stimulus+suffix,encoding='utf-8')
    files=['rtl/ppg_system_config_manager/ppg_system_config_manager.v']
    for label, extra in [('stop_only', []), ('stop_start', ['+START_COLLISION']), ('stop_commit', ['+COMMIT_COLLISION']), ('stop_clear', ['+CLEAR_COLLISION'])]:
        d.simulate('tb_ppg_system_config_manager', probe, files, extra)
        folder=d.EVIDENCE/'tb_ppg_system_config_manager'
        for suffix in ('compile.log','run.log','result.json'):
            if (folder/suffix).exists():
                (folder/suffix).replace(folder/(label+'.'+suffix))
    # 原TB负对照验证真实比较能FAIL；不拿横幅当完整ID覆盖。
    raw='\n'.join(lines)+'\n'
    needle='(o_active_config != i_config_snapshot)'
    assert raw.count(needle)==1
    negative=d.EVIDENCE/'mgr_negative.v'
    negative.write_text(raw.replace(needle,'(o_active_config == i_config_snapshot)'),encoding='utf-8')
    simulate('negative','tb_ppg_system_config_manager',negative,files)

def ledger():
    path=d.ROOT/'coverage.csv'
    with path.open(encoding='utf-8-sig',newline='') as f:
        rows=list(csv.DictReader(f))
    full={'ppg_reset_sync.v':'chip §3 / F-007', 'ppg_pulse_cdc_sync.v':'chip §7 / 事件间隔前提',
          'ppg_config_cdc_bridge.v':'C03 §3/4', 'ppg_characterization_control_cdc.v':'C07 §3-12 / CCC-01..26',
          'tb_ppg_characterization_control_cdc.v':'CCC-01..26 / D-001',
          'ppg_system_active_config_unpack.v':'C05 §3-6 / UNPACK-01..05',
          'tb_ppg_system_active_config_unpack.v':'UNPACK-01..05',
          'ppg_system_config_manager.v':'C02 §1-9 / MGR-01..24',
          'tb_ppg_system_config_manager.v':'MGR-01..24 (21须联合层)',
          'ppg_active_v4_control_plane_integration.v':'C03 §1-14 / AV4C-01..22',
          'ppg_spi_register_file.v':'chip §4-7 / F-005', 'ppg_chip_digital_top.v':'chip §1-9 / F-007',
          'ppg_p2s_packer.v':'chip §5',
          'PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md':'C07 §1-12 / CCC-01..26',
          'ppg_system_active_config_unpack_semantic_contract.md':'C05 §1-6 / UNPACK-01..05',
          'ppg_system_config_manager_semantic_contract.md':'C02 §1-9 / MGR-01..24',
          'PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md':'C03 §1-14 / AV4C-01..22',
          'PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md':'chip §1-9 / F-005..07'}
    for row in rows:
        name=Path(row['path']).name
        if row['check_item']=='门禁/编译与证据':
            row.update(status='完成',evidence='evidence/gate_reuse.json; 同版本A evidence/gates + lint/compile',remaining='仅已列本地工具；未运行xsim/Verilator/综合/物理签核不记通过')
        elif name in full:
            row.update(status='部分',contract_or_id=full[name],evidence='PPG_REVIEW_D.md; evidence/baseline.json; evidence/skill_analysis',remaining='全文已实读；跨层ID与所需专项对照闭环待完成（详见报告）')
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)

def controls():
    name='tb_ppg_active_v4_control_plane_integration'
    wrapper='rtl/ppg_active_v4_control_plane_integration/ppg_active_v4_control_plane_integration.v'
    raw=(d.SOURCE/wrapper).read_text(encoding='utf-8')
    needle='assign o_alpha_q15 = alpha_q15_o;'
    assert raw.count(needle)==1
    mutant=d.EVIDENCE/'wrapper_alpha_mutant.v'
    mutant.write_text(raw.replace(needle,"assign o_alpha_q15 = 16'h0000;"),encoding='utf-8')
    tb=d.SOURCE/f'rtl/ppg_active_v4_control_plane_integration/{name}.v'
    deps=['rtl/ppg_config_cdc_bridge/ppg_config_cdc_bridge.v','rtl/ppg_system_config_manager/ppg_system_config_manager.v','rtl/ppg_system_active_config_unpack/ppg_system_active_config_unpack.v']
    simulate('alpha_mutant',name,tb,deps+[str(mutant)])
    original=tb.read_text(encoding='utf-8')
    needle='(o_active_config != reg_snapshot_normal)'
    assert original.count(needle)==3
    negative=d.EVIDENCE/'wrapper_negative.v'
    negative.write_text(original.replace(needle,'(o_active_config == reg_snapshot_normal)',1),encoding='utf-8')
    simulate('negative',name,negative,deps+[wrapper])
    name='tb_ppg_system_active_config_unpack'
    unpack='rtl/ppg_system_active_config_unpack/ppg_system_active_config_unpack.v'
    raw=(d.SOURCE/unpack).read_text(encoding='utf-8')
    needle='i_active_config[688:673]'
    assert raw.count(needle)==1
    mutant=d.EVIDENCE/'unpack_map_mutant.v'
    mutant.write_text(raw.replace(needle,'i_active_config[689:674]'),encoding='utf-8')
    simulate('mapping_mutant',name,d.SOURCE/f'rtl/ppg_system_active_config_unpack/{name}.v',[str(mutant)])
    raw=(d.EVIDENCE/'d_cdc_probe.v').read_text(encoding='utf-8')
    needle='check({enable,mux}===value);'
    assert raw.count(needle)==1
    negative=d.EVIDENCE/'d_cdc_negative.v'
    negative.write_text(raw.replace(needle,"check({enable,mux}===(value ^ 6'b000001));"),encoding='utf-8')
    simulate('negative','d_cdc_probe',negative,['rtl/ppg_config_cdc_bridge/ppg_config_cdc_bridge.v','rtl/ppg_characterization_control_cdc/ppg_characterization_control_cdc.v','rtl/ppg_pulse_cdc_sync/ppg_pulse_cdc_sync.v','rtl/ppg_reset_sync/ppg_reset_sync.v'])

def chip_stop():
    folder=d.SOURCE/'rtl/ppg_chip_digital_top'
    original=(folder/'tb_ppg_chip_digital_top.v').read_text(encoding='utf-8').splitlines()
    probe=d.EVIDENCE/'chip_stop_probe.v'
    stimulus=r'''
    integer stop_hits=0, collision_hits=0;
    always @(posedge CLK_2M_PAD) begin
        #1;
        if(dut.top_stop_ack_event_o === 1'b1) stop_hits=stop_hits+1;
        if(dut.ppg_control_top_Inst.flag_stop_request_event &&
           dut.ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.config_transport_update_o) begin
            collision_hits=collision_hits+1;
            $display("D_CHIP_STOP_COMMIT_COLLISION");
        end
    end
    initial begin
        wait(RESET_N === 1'b1); repeat(5) @(posedge CLK_2M_PAD);
        build_normal_manual_config; spi_write_config; spi_command(8'h04);
        spi_txn(1'b0,16'hffff,1); repeat(8) @(posedge CLK_2M_PAD); #1;
        if(dut.top_lifecycle_state_o !== 2'b01) $fatal(1,"D_CHIP_SETUP_READY_FAIL");
        spi_command(8'h01); spi_txn(1'b0,16'hffff,1);
        repeat(8) @(posedge CLK_2M_PAD); #1;
        if(dut.top_lifecycle_state_o !== 2'b10) $fatal(1,"D_CHIP_SETUP_RUN_FAIL");
        if($test$plusargs("COMMIT_COLLISION")) spi_command(8'h06);
        else spi_command(8'h02);
        spi_txn(1'b0,16'hffff,1); repeat(16) @(posedge CLK_2M_PAD); #1;
        $display("D_CHIP_STOP_OBSERVE state=%b stop_hits=%0d collisions=%0d code=%h",
            dut.top_lifecycle_state_o,stop_hits,collision_hits,dut.top_last_error_code_o);
        if(stop_hits!=1 || dut.top_lifecycle_state_o===2'b10) $fatal(1,"D_CHIP_STOP_FAIL");
        $display("D_CHIP_STOP_PASS"); $finish;
    end
    initial begin #3000000; $fatal(1,"D_CHIP_PROBE_TIMEOUT"); end
endmodule
'''
    # 真实实例名先由read/rg验证；不从RTL自行解析。
    probe.write_text('\n'.join(original[:635])+stimulus,encoding='utf-8')
    files=[]
    for entry in (folder/'xsim_chip_digital_top_filelist.f').read_text(encoding='utf-8').splitlines():
        if entry and not entry.startswith('tb_'):
            files.append(str((folder/entry).resolve()))
    for label,extra in [('chip_stop_only',[]),('chip_stop_commit',['+COMMIT_COLLISION'])]:
        d.simulate('tb_ppg_chip_digital_top',probe,files,extra)
        output=d.EVIDENCE/'tb_ppg_chip_digital_top'
        for suffix in ('compile.log','run.log','result.json'):
            if (output/suffix).exists(): (output/suffix).replace(output/(label+'.'+suffix))

def p2s():
    for label,extra in [('positive',[]),('negative',['+NEGATIVE'])]:
        d.simulate('d_p2s_probe',d.EVIDENCE/'d_p2s_probe.v',['rtl/ppg_p2s_packer/ppg_p2s_packer.v'],extra)
        output=d.EVIDENCE/'d_p2s_probe'
        for suffix in ('compile.log','run.log','result.json'):
            if (output/suffix).exists(): (output/suffix).replace(output/(label+'.'+suffix))

if __name__=='__main__':
    if sys.argv[1]=='stop': stop_probe()
    elif sys.argv[1]=='ledger': ledger()
    elif sys.argv[1]=='controls': controls()
    elif sys.argv[1]=='chip_stop': chip_stop()
    elif sys.argv[1]=='p2s': p2s()
