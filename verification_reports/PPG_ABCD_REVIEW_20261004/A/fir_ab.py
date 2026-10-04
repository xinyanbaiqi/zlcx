from pathlib import Path
import json,subprocess,shlex
BASE=Path(__file__).resolve().parent
S=BASE/'snapshot'
D=BASE/'evidence/fir_floating_ab'
D.mkdir(exist_ok=True)
j=json.loads((BASE/'evidence/gates/ppg_coarse_detection_fir.json').read_text(encoding='utf-8'))
ports=j['quality_gate']['ast_report']['files'][0]['modules'][0]['ports']
signals={'i_clk':'clk','i_rstn':'rstn','i_run_enable':"1'b1",'i_result_valid':'valid','i_sample_valid':"1'b1",'i_coarse_valid':"1'b1",'i_coarse_recovery_calibrated':"1'b1",'i_frame_type':"2'b10",'i_result_ready':"1'b1",'i_test_inject_enable':"1'b1"}
body='''`timescale 1ns/1ps
module audit_fir_ab;
reg clk=0;
reg rstn=1;
reg valid=0;
always #5 clk=~clk;
'''
for name,enable in [('a',1),('b',1),('c',0)]:
    connections=[]
    for p in ports:
        if p['direction']!='input': continue
        signal=signals.get(p['name'],"'0")
        if p['name']=='i_test_calibration_loss_inject_valid':
            if name in ('a','c'): continue
            signal="1'b0"
        connections.append('.'+p['name']+'('+signal+')')
    body+='ppg_coarse_detection_fir #(.C_ENABLE_TEST_INJECTION('+str(enable)+')) '+name+' (\n'+',\n'.join(connections)+'\n);\n'
body+='''
integer guard;
initial begin
  #1 rstn=0;
  #20 rstn=1;
  @(negedge clk); valid=1;
  #1;
  $display("INPUT qualified A(open,enabled)=%b B(tie0,enabled)=%b C(open,disabled)=%b",a.flag_sample_qualified,b.flag_sample_qualified,c.flag_sample_qualified);
  guard=0;
  while (b.o_result_valid !== 1'b1 && guard<200) begin @(posedge clk); #1; guard=guard+1; end
  $display("OUTPUT valid A=%b B=%b C=%b qualified A=%b B=%b C=%b guard=%0d",a.o_result_valid,b.o_result_valid,c.o_result_valid,a.o_detection_qualified,b.o_detection_qualified,c.o_detection_qualified,guard);
  if (guard>=200 || a.o_detection_qualified !== 1'bx || b.o_detection_qualified !== 1'b1 || c.o_detection_qualified !== 1'b1) $fatal(1,"AUDIT_AB_FAIL");
  $display("AUDIT_AB_CONFIRMED");
  $finish;
end
endmodule
'''
(D/'audit_fir_ab.v').write_bytes(body.encode())
(D/'audit_fir_ab_negative.v').write_bytes(body.replace("b.o_detection_qualified !== 1'b1","b.o_detection_qualified !== 1'b0").encode())
def linux(p):return '/mnt/c/'+p.resolve().as_posix()[3:]
def q(p):return shlex.quote(linux(p))
iv=BASE/'toolchain/icarus11/usr/bin/iverilog'
lib=BASE/'toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl'
vp=BASE/'toolchain/icarus11/usr/bin/vvp'
script=['#!/bin/bash','set -u','cd '+q(D)]
for tag in ['audit_fir_ab','audit_fir_ab_negative']:
    cmd=q(iv)+' -B '+q(lib)+' -g2012 -Wall -s audit_fir_ab -o '+q(D/(tag+'.vvp'))+' '+q(S/'rtl/ppg_coarse_detection_fir/ppg_coarse_detection_fir.v')+' '+q(D/(tag+'.v'))
    script += [cmd+' > '+q(D/(tag+'.compile.log'))+' 2>&1','echo "$?" > '+q(D/(tag+'.compile.rc')),q(vp)+' -M '+q(lib)+' '+q(D/(tag+'.vvp'))+' > '+q(D/(tag+'.run.log'))+' 2>&1','echo "$?" > '+q(D/(tag+'.run.rc'))]
(D/'run_ab.sh').write_bytes(('\n'.join(script)+'\n').encode())
r=subprocess.run(['wsl.exe','-d','Debian','--','bash',linux(D/'run_ab.sh')],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(D/'driver.log').write_bytes(r.stdout)
for tag in ['audit_fir_ab','audit_fir_ab_negative']:
    print(tag,'compile', (D/(tag+'.compile.rc')).read_text().strip(),'run',(D/(tag+'.run.rc')).read_text().strip())
    print((D/(tag+'.run.log')).read_text(encoding='utf-8'))
