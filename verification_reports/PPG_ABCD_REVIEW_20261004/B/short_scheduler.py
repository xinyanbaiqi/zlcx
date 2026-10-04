from sim import *
p='rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v'
t='rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v'
tb=(SNAP/t).read_text(encoding='utf-8');rtl=(SNAP/p).read_text(encoding='utf-8')
body='''
 initial begin
  i_clk=0;i_rstn=0;cnt_pass=0;cnt_fail=0;
  drive_defaults;reset_dut;pulse_start;
  wait_frame_start(20);
  repeat(3)begin
   wait_frame_start(5020);
   @(negedge i_clk);
   $display("B_NORMAL_PERIOD cycle=%0d period=%0d frame=%0d",cnt_cycle,reg_frame_period,o_current_frame_id);
   check_fsc(100,flag_wait_ok && reg_frame_period==5000);
  end
  $display("B_SCHEDULER pass=%0d fail=%0d",cnt_pass,cnt_fail);
  if(cnt_fail!=0)$fatal(1,"B_NORMAL_PERIOD_FAIL");
  $finish;
 end
 initial begin #12000000;$fatal(1,"B_TIMEOUT");end
endmodule
'''
newtb=tb[:tb.index('\n\tinitial begin')]+body
sim('scheduler_cadence','tb_ppg_400hz_frame_calibration_scheduler',[p],newtb)
mut=rtl.replace('C_MACRO_FRAME_TICKS = 5000','C_MACRO_FRAME_TICKS = 4999')
assert rtl!=mut
sim('scheduler_cadence_counterfactual','tb_ppg_400hz_frame_calibration_scheduler',[p],newtb,{Path(p).name:mut})
# 原TB允许5001的证据为旧日志，追加Q3门控变异短跑以核实比较执行。
mutq=rtl.replace(' && i_owner_q3_window_closed;',';')
assert rtl!=mutq
sim('scheduler_original_q3_gate_mutant','tb_ppg_400hz_frame_calibration_scheduler',[p],tb,{Path(p).name:mutq})
