from pathlib import Path
import json,subprocess,shlex
B=Path(__file__).resolve().parent; S=B/'snapshot'; E=B/'evidence'
L='/mnt/c'+B.as_posix()[2:]; T=L+'/toolchain/icarus11/usr'; LIB=T+'/lib/x86_64-linux-gnu/ivl'
manifest={r['name']:r for r in json.loads((E/'compile_manifest.json').read_text(encoding='utf-8'))}
cases=[('sar9_q3_width','tb_ppg_timing_sar9','ppg_timing_sar9',"R_LED_END = R_Q3_CENTER_TICK + 13'd1;", "R_LED_END = R_Q3_CENTER_TICK + 13'd2;"),
       ('sar15_q2_start','tb_ppg_timing_sar15','ppg_timing_sar15',"R_Q2_START = 13'd21", "R_Q2_START = 13'd22"),
       ('dual_static_pack','tb_ppg_dual_precision_top','ppg_dual_precision_top','assign o_s_in = active_test_mux_ctrl;', "assign o_s_in = active_test_mux_ctrl ^ 5'b00001;"),
       ('3200_frame','tb_ppg_timing_3200hz','ppg_timing_sar9_3200hz',".C_FRAME_TICKS(13'd625)", ".C_FRAME_TICKS(13'd626)")]
rows=[]
for name,tb,mod,old,new in cases:
    d=E/'mutations_A'/name; d.mkdir(parents=True,exist_ok=True)
    p=S/'rtl'/('ppg_timing_sar9' if mod=='ppg_timing_sar9_3200hz' else mod)/(mod+'.v')
    src=p.read_text(encoding='utf-8'); assert src.count(old)==1,(name,src.count(old))
    (d/p.name).write_bytes(src.replace(old,new).encode('utf-8'))
    ent=manifest[tb]; dl=L+'/evidence/mutations_A/'+name
    paths=[dl+'/'+p.name if x==p.relative_to(S).as_posix() else L+'/snapshot/'+x for x in ent['files']]
    cmd=shlex.join([T+'/bin/iverilog','-B',LIB,'-g2012','-Wall','-s',tb,'-I',L+'/snapshot/'+Path(ent['tb']).parent.as_posix(),'-o',dl+'/sim.vvp']+paths)
    shell=cmd+' > '+shlex.quote(dl+'/compile.log')+' 2>&1\necho $? > '+shlex.quote(dl+'/compile.rc')+'\n'
    shell+=shlex.join(['timeout','120',T+'/bin/vvp','-M',LIB,dl+'/sim.vvp'])+' > '+shlex.quote(dl+'/run.log')+' 2>&1\necho $? > '+shlex.quote(dl+'/run.rc')+'\n'
    (d/'run.sh').write_bytes(shell.encode('utf-8'))
    subprocess.run(['wsl.exe','-d','Debian','--','bash',dl+'/run.sh'],capture_output=True)
    log=(d/'run.log').read_text(encoding='utf-8',errors='replace')
    errs=[x for x in log.splitlines() if 'ERROR' in x or 'FAIL' in x or 'FATAL' in x]
    row=dict(name=name,tb=tb,mutation_file=p.relative_to(S).as_posix(),old=old,new=new,compile_rc=int((d/'compile.rc').read_text()),run_rc=int((d/'run.rc').read_text()),error_lines=len(errs),examples=errs[:5],passed_banner='PASS:' in log)
    assert row['compile_rc']==0 and errs and not row['passed_banner'],row
    rows.append(row); print(json.dumps(row,ensure_ascii=False),flush=True)
    (E/'mutation_results_A.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
