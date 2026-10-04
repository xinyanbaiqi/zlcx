from review import *
import time
TC=AUDIT/'toolchain/icarus11'
def linux(p):return '/mnt/'+p.drive[0].lower()+p.as_posix()[2:]
def run_case(name,tb_text,rtl_text=None):
 d=OUT/'evidence'/name;d.mkdir(parents=True,exist_ok=True)
 t=d/'tb_ppg_system_fault_abort_supervisor.v';t.write_text(tb_text,encoding='utf-8')
 r=SNAP/'rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v'
 if rtl_text is not None:
  r=d/r.name;r.write_text(rtl_text,encoding='utf-8')
 iv=['wsl.exe','-d','Debian','--',linux(TC/'usr/bin/iverilog'),'-B',linux(TC/'usr/lib/x86_64-linux-gnu/ivl'),'-g2012','-Wall','-s','tb_ppg_system_fault_abort_supervisor','-o',linux(d/'sim.vvp'),linux(r),linux(t)]
 c=subprocess.run(iv,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=45)
 (d/'compile.log').write_bytes(c.stdout)
 if c.returncode==0:
  v=subprocess.run(['wsl.exe','-d','Debian','--',linux(TC/'usr/bin/vvp'),'-M',linux(TC/'usr/lib/x86_64-linux-gnu/ivl'),linux(d/'sim.vvp')],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=10)
  (d/'run.log').write_bytes(v.stdout)
  s=v.stdout.decode(errors='replace');print(name,'compile_rc',c.returncode,'run_rc',v.returncode,'fail_count',s.count('FAIL'),'tail',s.splitlines()[-3:])
  (d/'result.json').write_text(json.dumps(dict(compile_command=iv,compile_rc=c.returncode,run_rc=v.returncode,fail_count=s.count('FAIL'))),encoding='utf-8')
 else:print(name,'compile_rc',c.returncode,c.stdout.decode(errors='replace')[-1000:])
tb=(SNAP/'rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v').read_text(encoding='utf-8')
rtl=(SNAP/'rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v').read_text(encoding='utf-8')
mut=rtl.replace('flag_new_any && !system_fault_blocking_o','flag_new_any && !system_fault_cause_valid_o')
assert mut!=rtl
run_case('supervisor_original',tb)
run_case('supervisor_original_rearm_mutant',tb,mut)
run_case('supervisor_wrong_expected_negative',tb.replace('(o_system_fault_cause === 8\'h01)', '(o_system_fault_cause === 8\'h7f)',1))
run_case('supervisor_invalid_width',tb.replace('C_WD_WIDTH = 4','C_WD_WIDTH = 1'))
body='''
 initial begin
  i_clk=0;i_rstn=0;cnt_pass=0;cnt_fail=0;drive_idle_inputs;
  repeat(3) @(negedge i_clk);i_rstn=1;@(negedge i_clk);
  pulse_ami_fault(8'h01,1'b1,16'h1234,16'h5678);
  check_case("BOPEN1", o_system_abort_event === 1'b1);
  @(negedge i_clk);
  check_case("BCLOSE",o_system_fault_blocking === 1'b0 && o_system_fault_cause_valid === 1'b1);
  pulse_ami_fault(8'h02,1'b1,16'h1111,16'h2222);
  check_case("BREARM",o_system_abort_event === 1'b1 && o_system_stop_request_event === 1'b1 && o_system_fault_discard_event === 1'b1 && o_system_fault_cause === 8'h01 && o_system_fault_frame_id === 16'h1234 && o_system_fault_summary === 16'h0003);
  @(negedge i_clk);i_diag_clear_event=1;
  @(negedge i_clk);i_diag_clear_event=0;
  @(negedge i_clk);
  i_ami_fault_valid=1;i_ami_fault_cause=8'h03;i_diag_clear_event=1;
  @(negedge i_clk);i_ami_fault_valid=0;i_diag_clear_event=0;
  check_case("BNEWCL",o_system_fault_cause_valid === 1'b1 && o_system_fault_cause === 8'h03 && o_system_abort_event === 1'b1 && o_system_fault_summary[2] === 1'b1);
  @(negedge i_clk);i_diag_clear_event=1;
  @(negedge i_clk);i_diag_clear_event=0;
  @(negedge i_clk);i_stop_episode_active=1;i_adc_physical_idle=0;
  repeat(C_WD_CYCLES-1) @(negedge i_clk);
  check_case("BWDN1",o_system_fault_cause_valid === 1'b0 && o_system_abort_event === 1'b0);
  i_adc_physical_idle=1;@(negedge i_clk);
  check_case("BWDIDL",o_system_fault_cause_valid === 1'b0 && o_system_abort_event === 1'b0);
  $display("B_SUPERVISOR comparisons=%0d failures=%0d",cnt_pass,cnt_fail);
  if(cnt_fail!=0)$fatal(1,"B_SUPERVISOR_FAIL");
  $finish;
 end
 initial begin #50000;$fatal(1,"B_SUPERVISOR_TIMEOUT");end
endmodule
'''
newtb=tb[:tb.index('\n\tinitial begin')]+body
run_case('supervisor_extended',newtb)
run_case('supervisor_extended_rearm_mutant',newtb,mut)
