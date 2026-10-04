from pathlib import Path
from native_probe import run
import json,hashlib
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';e=[]
p=S/'rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v';ls=p.read_text(encoding='utf-8-sig').splitlines();monitor='\n'.join(ls[941:967]);gate='\n'.join(ls[1867:1876])
assert 'always @(posedge i_clk)' in monitor and 'cnt_duplicate_or_relabel_violation' in monitor and 'PASS OIB-06' in gate
decl='''reg i_clk,flag_oib_order_monitor_active,o_measurement_result_valid,i_measurement_result_ready,flag_order_first_seen;
reg [15:0]o_result_frame_id,o_result_sample_index,reg_last_result_frame_id,reg_last_result_sample_index;
reg o_result_color_ir,o_result_precision_mode,reg_last_result_color_ir,reg_last_result_precision_mode;
reg [1:0]o_result_frame_type,reg_last_result_frame_type;
integer cnt_order_violation,cnt_duplicate_or_relabel_violation,cnt_error,cnt_result_capture,k,c,id;
always #5 i_clk=~i_clk;
'''
body=monitor+'\ntask check_original;begin\n'+gate+'\nend endtask\n'
seq='''i_clk=0;flag_oib_order_monitor_active=0;o_measurement_result_valid=0;i_measurement_result_ready=1;
for(c=0;c<7;c=c+1)begin
 @(negedge i_clk);flag_order_first_seen=0;cnt_order_violation=0;cnt_duplicate_or_relabel_violation=0;cnt_error=0;cnt_result_capture=0;flag_oib_order_monitor_active=1;
 for(k=1;k<=4;k=k+1)begin
  if(!(c==1 && k==2))begin
   @(negedge i_clk);id=k;
   if(c==5 && k==2)id=1;
   if(c==6 && k==2)id=3;
   if(c==6 && k==3)id=2;
   o_result_frame_id=id;o_result_sample_index=id;o_result_color_ir=(k%2);o_result_frame_type=0;o_result_precision_mode=0;
   if(c==2 && k==2)o_result_color_ir=~o_result_color_ir;
   if(c==3 && k==2)o_result_frame_type=1;
   if(c==4 && k==2)o_result_precision_mode=1;
   o_measurement_result_valid=1;@(posedge i_clk);#1;cnt_result_capture=cnt_result_capture+1;
   @(negedge i_clk);o_measurement_result_valid=0;
  end
 end
 check_original;$display("A_OIB_CHECKER case=%0d errors=%0d transfers=%0d",c,cnt_error,cnt_result_capture);
 if(c<5 && cnt_error!=0)$fatal(1,"unexpected counterexample rejection");
 if(c>=5 && cnt_error!=1)$fatal(1,"known duplicate/order negative did not fire");
end
'''
d=E/'A_oib06_checker';d.mkdir(exist_ok=True);tb=d/'tb_A_checker.v';tb.write_text('`timescale 1ns/1ps\nmodule tb_A_checker;\n'+decl+body+'initial begin\n'+seq+'$display("A_OIB_CHECKER_CONFIRMED");$finish;end\nendmodule\n',encoding='utf-8');r=run('A_oib06_checker',[tb],'tb_A_checker');assert (r['compile_rc'],r['run_rc'])==(0,0)
e.append({'case':'OIB06','source':str(p),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'ranges':[[942,967],[1868,1876]],'limitation':'Exact monitor/gate fragments; synthetic public result stream, not full DUT mutant','result':r})
p=S/'rtl/ppg_control_top/tb_ppg_control_top_periodic_recheck_recovery.v';ls=p.read_text(encoding='utf-8-sig').splitlines();gate='\n'.join(ls[1066:1072]);assert 'PASS RRC-01' in gate
d=E/'A_rrc01_checker';d.mkdir(exist_ok=True);tb=d/'tb_A_checker.v'
tb.write_text('''module tb_A_checker;
reg flag_pending_before_fine_window;integer cnt_frame_drive,cnt_frame_before_pending,cnt_error;
task check_original;begin
'''+gate+'''
end endtask
initial begin
cnt_frame_drive=80;flag_pending_before_fine_window=1;cnt_error=0;cnt_frame_before_pending=30;check_original;if(cnt_error!=0)$fatal(1,"nominal rejected");
cnt_frame_before_pending=1;cnt_error=0;check_original;if(cnt_error!=0)$fatal(1,"bad interval unexpectedly rejected");
flag_pending_before_fine_window=0;cnt_error=0;check_original;if(cnt_error!=1)$fatal(1,"absence negative did not fire");
$display("A_RRC01_CHECKER_CONFIRMED nominal30_pass bad1_pass absence_fail");$finish;
end endmodule
''',encoding='utf-8');r=run('A_rrc01_checker',[tb],'tb_A_checker');assert (r['compile_rc'],r['run_rc'])==(0,0)
e.append({'case':'RRC01','source':str(p),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'ranges':[[1067,1072]],'limitation':'Exact final checker only; no claim altered interval RTL passes full RRC','result':r})
(E/'stream_interval_checker_evidence_A.json').write_text(json.dumps(e,ensure_ascii=False,indent=2),encoding='utf-8')
