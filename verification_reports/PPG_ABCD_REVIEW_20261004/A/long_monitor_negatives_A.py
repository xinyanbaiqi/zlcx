from pathlib import Path
import json,hashlib,re
from native_probe import run
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';out=[]
def save_run(name,p,decl,body,sequence,refs):
 d=E/name;d.mkdir(exist_ok=True);tb=d/'tb_A_monitor.v'
 source='`timescale 1ns/1ps\nmodule tb_A_monitor;\n'+decl+'\n'+body+'\ninitial begin\n'+sequence+'\n$display("A_MONITOR_NEGATIVES_CONFIRMED");$finish;end\nendmodule\n'
 tb.write_text(source,encoding='utf-8');r=run(name,[tb],'tb_A_monitor')
 assert (r['compile_rc'],r['run_rc'])==(0,0)
 out.append({'case':name,'source':str(p),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'copied_ranges':refs,'limitation':'Exact checker fragments only; synthetic observed counts; no full DUT runtime/mutation PASS claim','result':r})
for name in ['tb_diag_algo_probe','tb_ppg_control_top_longrun']:
 p=S/'rtl/ppg_control_top'/(name+'.v');text=p.read_text(encoding='utf-8-sig')
 start=text.index('\t\tif(flag_global_timeout) begin',text.index('// RAW-12：post-START'))
 end=text.index('// RAW-13：',start);snippet=text[start:end].rsplit('\n',1)[0]
 keys=['C_RAW12_TARGET_RED_SAMPLES','C_RAW12_TARGET_IR_SAMPLES','C_PPG_MIN_DURATION_NS'];decl=[]
 for key in keys:
  line=next(l for l in text.splitlines() if 'localparam' in l.split('//',1)[0] and key in l.split('//',1)[0]);decl.append(line.split('//',1)[0])
 decl='\n'.join(decl)+'\ninteger cnt_red_response,cnt_ir_response,cnt_error;time reg_measurement_elapsed_time;reg flag_global_timeout;'
 body='task check_original;begin\n'+snippet+'\nend endtask'
 seq='cnt_red_response=C_RAW12_TARGET_RED_SAMPLES;cnt_ir_response=C_RAW12_TARGET_IR_SAMPLES;reg_measurement_elapsed_time=C_PPG_MIN_DURATION_NS;flag_global_timeout=0;cnt_error=0;check_original;if(cnt_error!=0)$fatal(1,"positive rejected");\n'
 seq+='cnt_red_response=C_RAW12_TARGET_RED_SAMPLES-1;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"RED deficit escaped");cnt_red_response=C_RAW12_TARGET_RED_SAMPLES;\n'
 seq+='cnt_ir_response=C_RAW12_TARGET_IR_SAMPLES-1;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"IR deficit escaped");cnt_ir_response=C_RAW12_TARGET_IR_SAMPLES;\n'
 seq+='reg_measurement_elapsed_time=C_PPG_MIN_DURATION_NS-1;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"short time escaped");reg_measurement_elapsed_time=C_PPG_MIN_DURATION_NS;\n'
 seq+='flag_global_timeout=1;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"watchdog escaped");'
 lo=text[:start].count('\n')+1;hi=lo+snippet.count('\n');save_run('A_monitor_'+name,p,decl,body,seq,[[lo,hi]])
p=S/'rtl/ppg_control_top/tb_ppg_control_top_long_10_cycles.v';text=p.read_text(encoding='utf-8-sig')
start=text.index('\t\tif((cnt_red_response + cnt_ir_response - cnt_measurement_result_valid) > 1) begin');end=text.index('// 全程协议错误sticky核查',start);a=text[start:end].rsplit('\n',1)[0]
s=text.index('\t\tif(o_error_sticky) begin',end);z=text.index('// 非阻断历史诊断类sticky',s);b=text[s:z].rsplit('\n',1)[0]
ports=re.findall(r'(o_[A-Za-z0-9_]+)',b);ports=list(dict.fromkeys(ports))
decl='integer cnt_red_response,cnt_ir_response,cnt_measurement_result_valid,cnt_error;reg flag_raw_arith_unbounded;\nreg '+','.join(ports)+';'
body='task check_counts;begin\n'+a+'\nend endtask\ntask check_sticky;begin\n'+b+'\nend endtask'
seq='cnt_red_response=10;cnt_ir_response=10;cnt_measurement_result_valid=20;flag_raw_arith_unbounded=0;cnt_error=0;check_counts;if(cnt_error!=0)$fatal(1,"exact positive rejected");\n'
seq+='cnt_measurement_result_valid=19;cnt_error=0;check_counts;if(cnt_error!=0)$fatal(1,"permitted deficit1 rejected");\n'
for val,label in [(18,'loss2'),(21,'duplicate')]:seq+=f'cnt_measurement_result_valid={val};cnt_error=0;check_counts;if(cnt_error!=1)$fatal(1,"{label} escaped");\n'
seq+='cnt_measurement_result_valid=20;flag_raw_arith_unbounded=1;cnt_error=0;check_counts;if(cnt_error!=1)$fatal(1,"saturation escaped");\n'
seq+=''.join(v+'=0;' for v in ports)+'cnt_error=0;check_sticky;if(cnt_error!=0)$fatal(1,"sticky positive rejected");\n'
for v in ports:seq+=v+'=1;cnt_error=0;check_sticky;if(cnt_error!=1)$fatal(1,"sticky escaped: '+v+'");'+v+'=0;\n'
save_run('A_monitor_long10',p,decl,body,seq,[[text[:start].count('\n')+1,text[:end].count('\n')],[text[:s].count('\n')+1,text[:z].count('\n')]])
(E/'long_monitor_negatives_A.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8');print('ALL_THREE_MONITOR_NEGATIVES_COMPLETE',len(out))
