from sim import *
p='rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v'
tb=(SNAP/'rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v').read_text(encoding='utf-8')
rtl=(SNAP/p).read_text(encoding='utf-8')
prefix=tb[:tb.index('\n\tinitial begin')]
for at in [4998,4999]:
 body=f'''
 initial begin
 i_clk=0;i_rstn=0;cnt_pass=0;cnt_fail=0;drive_defaults;
 i_normal_measurement_eligible=0;i_calibration_sample_valid=1;
 reset_dut;pulse_start;
 wait(o_macro_tick==13'd{at});@(negedge i_clk);
 $display("B_ABORT_BEFORE tick=%0d active=%b inflight=%b pending=%b rollover=%b",o_macro_tick,o_calibration_frame_active,o_transaction_inflight,inst_ppg_400hz_frame_calibration_scheduler.state_current[inst_ppg_400hz_frame_calibration_scheduler.B_CAL_REQ_PENDING],inst_ppg_400hz_frame_calibration_scheduler.flag_calibration_rollover);
 i_control_abort_event=1;
 @(posedge i_clk);#1;
 $display("B_ABORT_AFTER tick=%0d active=%b inflight=%b ownercommit=%b idle=%b",o_macro_tick,o_calibration_frame_active,o_transaction_inflight,o_adc_owner_commit_event,o_scheduler_idle);
 check_fsc(101,!o_calibration_frame_active && !o_adc_owner_commit_event);
 if(cnt_fail!=0)$fatal(1,"B_ROLLOVER_ABORT_FAIL");$finish;
 end
 initial begin #5000000;$fatal(1,"B_TIMEOUT");end
endmodule
'''
 sim('scheduler_abort_tick'+str(at),'tb_ppg_400hz_frame_calibration_scheduler',[p],prefix+body)
# Q3早DONE门控：保留真实释放身份，原实现释放但不置NORMAL完成；去掉门控的负对照应失败。
body='''
 initial begin
 i_clk=0;i_rstn=0;cnt_pass=0;cnt_fail=0;drive_defaults;reset_dut;pulse_start;
 wait_frame_start(20);wait_macro_tick(13'd4999,5100);repeat(3)@(negedge i_clk);
 check_fsc(102,cnt_owner_commit>=2 && cnt_done>=2 && cnt_normal_complete==0);
 $display("B_EARLY_Q3 owner=%0d done=%0d normalcomplete=%0d",cnt_owner_commit,cnt_done,cnt_normal_complete);
 if(cnt_fail!=0)$fatal(1,"B_EARLY_Q3_FAIL");$finish;
 end
 initial begin #5000000;$fatal(1,"B_TIMEOUT");end
endmodule
'''
qtb=(prefix+body).replace('.i_owner_q3_window_closed(1\'b1)', '.i_owner_q3_window_closed(1\'b0)')
sim('scheduler_early_q3','tb_ppg_400hz_frame_calibration_scheduler',[p],qtb)
mutq=rtl.replace(' && i_owner_q3_window_closed;',';')
sim('scheduler_early_q3_mutant','tb_ppg_400hz_frame_calibration_scheduler',[p],qtb,{Path(p).name:mutq})
