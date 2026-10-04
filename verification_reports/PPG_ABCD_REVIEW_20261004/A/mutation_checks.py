from pathlib import Path
import json,subprocess,shlex
B=Path(__file__).resolve().parent; S=B/'snapshot'; E=B/'evidence'
L='/mnt/c'+B.as_posix()[2:]; LIB=L+'/toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl'; IV=L+'/toolchain/icarus11/usr/bin/iverilog'; VVP=L+'/toolchain/icarus11/usr/bin/vvp'
manifest={r['name']:r for r in json.loads((E/'compile_manifest.json').read_text(encoding='utf-8'))}
cases=[
 ('s1_redundancy_sign','ppg_adc_s1_redundancy_corrector',"(i_capture_stage1_raw[3] ? 11'sd4 : -11'sd4)","(i_capture_stage1_raw[3] ? -11'sd4 : 11'sd4)"),
 ('s1_offset_removed','ppg_adc_s1_programmable_calibrator','assign dec_accumulator_q16 = dec_offset_q16_ext +',"assign dec_accumulator_q16 = 33'sd0 +"),
 ('reconstructor_center','ppg_adc_programmable_reconstructor',"- 14'sd511;","- 14'sd510;"),
 ('pwc_start_clears_sticky','ppg_precision_window_controller',"end else if(i_diag_clear_event == 1'b1)begin","end else if(i_diag_clear_event == 1'b1 || i_start_ack_event == 1'b1)begin"),
 ('router_reset_valid','ppg_adc_result_router','assign o_normal_valid = i_rstn && i_result_valid && flag_frame_normal;','assign o_normal_valid = i_result_valid && flag_frame_normal;'),
 ('fsc_identity_match','ppg_400hz_frame_calibration_scheduler','(i_adc_complete_sample_index == state_current[B_INFLIGHT_SAMPLE_H:B_INFLIGHT_SAMPLE_L])',"1'b1")]
results=[]
for name,mod,old,new in cases:
    d=E/'mutations'/name; d.mkdir(parents=True,exist_ok=True)
    rtl=S/'rtl'/mod/(mod+'.v'); source=rtl.read_text(encoding='utf-8'); count=source.count(old)
    assert count>=1,(name,count)
    mutant=d/(mod+'.v'); mutant.write_bytes(source.replace(old,new).encode('utf-8'))
    entry=manifest['tb_'+mod]; sourcepaths=[L+'/snapshot/'+p for p in entry['files']]
    rel=rtl.relative_to(S).as_posix(); sourcepaths=[L+'/evidence/mutations/'+name+'/'+mod+'.v' if p==L+'/snapshot/'+rel else p for p in sourcepaths]
    dl=L+'/evidence/mutations/'+name
    command=shlex.join([IV,'-B',LIB,'-g2012','-Wall','-s','tb_'+mod,'-I',L+'/snapshot/'+str(Path(entry['tb']).parent).replace('\\','/'),'-o',dl+'/sim.vvp']+sourcepaths)+' > '+shlex.quote(dl+'/compile.log')+' 2>&1\n'
    command+='rc=$?\necho "$rc" > '+shlex.quote(dl+'/compile.rc')+'\nif [ "$rc" -eq 0 ]; then\n'
    command+=shlex.join(['timeout','120',VVP,'-M',LIB,dl+'/sim.vvp'])+' > '+shlex.quote(dl+'/run.log')+' 2>&1\necho "$?" > '+shlex.quote(dl+'/run.rc')+'\nfi\n'
    script=d/'run.sh'; script.write_bytes(command.encode('utf-8'))
    rr=subprocess.run(['wsl.exe','-d','Debian','--','bash',dl+'/run.sh'],capture_output=True)
    comp=int((d/'compile.rc').read_text().strip()); log=(d/'run.log').read_text(encoding='utf-8',errors='replace') if (d/'run.log').exists() else ''
    bad=[l for l in log.splitlines() if 'FAIL' in l or 'FATAL' in l]
    result=dict(name=name,replacement_count=count,compile_rc=comp,run_rc=int((d/'run.rc').read_text().strip()) if (d/'run.rc').exists() else None,fail_lines=bad)
    results.append(result); print(name,'compile',comp,'run',result['run_rc'],'FAIL_LINES',len(bad),bad[:3],flush=True)
(E/'mutation_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
