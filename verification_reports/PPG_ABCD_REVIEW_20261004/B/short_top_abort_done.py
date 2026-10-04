from sim import *
path='rtl/ppg_control_top/tb_ppg_control_top_lifecycle_fault_adc_anomaly.v'
tb=(SNAP/path).read_text(encoding='utf-8')
lines=tb.splitlines(True)
prefix=''.join(lines[:916]).replace('.C_ENABLE_TEST_INJECTION(1)', '.C_ENABLE_TEST_INJECTION(0)').replace('.C_ENABLE_TEST_INJECTION(32\'d1)', '.C_ENABLE_TEST_INJECTION(32\'d0)')
init=''.join(lines[933:973])
body=r'''
 `define B_TOP ppg_control_top_Inst
 `define B_AMI ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst
 `define B_SSW ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst
 `define B_SCH ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst
 initial begin : b_main
  reg real_release;
  integer b_guard;
  reg [9:0] raw_code_tmp;
  reg b_pair_seen;
  reg b_lost_owner;
  integer b_before_restart;
 INIT_HERE
  flag_global_timeout=0;
  task_build_normal_manual_dual_config;task_pulse_source_update;task_wait_config_result;
  if(cnt_error!=0 || !o_start_ready || o_lifecycle_state!=ST_READY)$fatal(1,"B_TOP_SETUP_CONFIG_FAIL");
  task_pulse_start;wait_q3_release(real_release);
  if(!real_release || !`B_SSW.o_adc_owner_inflight)$fatal(1,"B_TOP_SETUP_OWNER_FAIL");
  $display("B_TOP_SETUP precision=%b sample=%0d owner=%b",reg_owner_snapshot_precision,reg_owner_snapshot_sample_index,`B_SSW.o_adc_owner_inflight);
  make_fixed_raw(150,raw_code_tmp);b_pair_seen=0;
  fork
   drive_real_adc_done(reg_owner_snapshot_precision,raw_code_tmp,raw_code_tmp);
   begin
    b_guard=0;
    @(negedge i_clk);
    while(`B_AMI.flag_adc_completion_normal_emit!==1'b1 && b_guard<100)begin @(negedge i_clk);b_guard=b_guard+1;end
    if(b_guard>=100)$fatal(1,"B_TOP_SETUP_EMIT_TIMEOUT");
    i_control_abort_event=1;
    @(posedge i_clk);#1;
    b_pair_seen=(`B_TOP.flag_owner_abort_event===1'b1 && `B_TOP.ami_adc_transaction_complete_event_o===1'b1 && `B_SSW.flag_owner_release===1'b1);
    $display("B_TOP_PAIR abort=%b completion=%b release=%b amiowner=%b sswowner=%b",`B_TOP.flag_owner_abort_event,`B_TOP.ami_adc_transaction_complete_event_o,`B_SSW.flag_owner_release,`B_AMI.flag_adc_transaction_inflight,`B_SSW.o_adc_owner_inflight);
    @(negedge i_clk);i_control_abort_event=0;
    @(posedge i_clk);#1;
    $display("B_TOP_AFTER sswowner=%b schedulerowner=%b amiowner=%b",`B_SSW.o_adc_owner_inflight,`B_SCH.o_transaction_inflight,`B_AMI.flag_adc_transaction_inflight);
   end
  join
  if(!b_pair_seen)$fatal(1,"B_TOP_SETUP_PAIR_FAIL");
  b_guard=0;
  while(o_lifecycle_state!=ST_CONFIG && b_guard<10000)begin @(negedge i_clk);b_guard=b_guard+1;end
  $display("B_TOP_DRAIN cycles=%0d lifecycle=%0d physicalidle=%b waveidle=%b amiempty=%b amiowner=%b schedulerowner=%b sswowner=%b sswide=%b blocking=%b cause=%h",b_guard,o_lifecycle_state,i_adc_physical_idle,`B_SSW.o_sar_timing_idle,o_ami_datapath_empty,`B_AMI.flag_adc_transaction_inflight,`B_SCH.o_transaction_inflight,`B_SSW.o_adc_owner_inflight,o_ssw_wrapper_idle,o_system_fault_blocking,o_system_fault_cause);
  repeat(100)@(negedge i_clk);
  b_lost_owner=(`B_SSW.o_adc_owner_inflight!==1'b0 || o_ssw_wrapper_idle!==1'b1);
  $display("B_TOP_PERSIST lifecycle=%0d physicalidle=%b amiempty=%b sswowner=%b sswide=%b",o_lifecycle_state,i_adc_physical_idle,o_ami_datapath_empty,`B_SSW.o_adc_owner_inflight,o_ssw_wrapper_idle);
  @(negedge i_clk);i_diag_clear_event=1;
  @(negedge i_clk);i_diag_clear_event=0;
  repeat(4)@(negedge i_clk);
  $display("B_TOP_DIAG_CLEAR sswowner=%b sswide=%b",`B_SSW.o_adc_owner_inflight,o_ssw_wrapper_idle);
  task_build_normal_manual_dual_config;task_pulse_source_update;task_wait_config_result;
  if(!o_start_ready || o_lifecycle_state!=ST_READY)$fatal(1,"B_TOP_RECOMMIT_FAIL");
  b_before_restart=cnt_owner_commit_total_lfa;
  @(negedge i_clk);i_start_event=1;
  @(negedge i_clk);i_start_event=0;
  b_guard=0;
  while(`B_TOP.wrapper_start_ack_event_o!==1'b1 && b_guard<64)begin @(negedge i_clk);b_guard=b_guard+1;end
  if(b_guard>=64)$fatal(1,"B_TOP_RESTART_ACK_TIMEOUT");
  @(posedge i_clk);#1;
  $display("B_TOP_RESTART_CLEAR sswowner=%b sswide=%b",`B_SSW.o_adc_owner_inflight,o_ssw_wrapper_idle);
  b_guard=0;
  while(cnt_owner_commit_total_lfa==b_before_restart && b_guard<7000)begin @(negedge i_clk);b_guard=b_guard+1;end
  $display("B_TOP_RESTART_PROGRESS cycles=%0d newowners=%0d lifecycle=%0d physicalidle=%b sswowner=%b blocking=%b cause=%h",b_guard,cnt_owner_commit_total_lfa-b_before_restart,o_lifecycle_state,i_adc_physical_idle,`B_SSW.o_adc_owner_inflight,o_system_fault_blocking,o_system_fault_cause);
  if(b_lost_owner)$fatal(1,"B_TOP_ABORT_DONE_INTERNAL_DRAIN_FAIL");
  if(cnt_owner_commit_total_lfa==b_before_restart)$fatal(1,"B_TOP_RESTART_NO_NEW_OWNER");
  $display("B_TOP_ABORT_DONE_PASS");$finish;
 end
 initial begin #100000000;$fatal(1,"B_TOP_ABORT_DONE_TIMEOUT");end
endmodule
'''.replace('INIT_HERE',init)
newtb=prefix+body
src=[str(p.relative_to(SNAP)).replace('\\','/') for p in (SNAP/'rtl').glob('*/*.v') if p.name.startswith('ppg_')]
name='top_abort_done_v3'
if not (OUT/'evidence'/name/'result.json').exists() or json.loads((OUT/'evidence'/name/'result.json').read_text())['compile_rc']!=0:sim(name,'tb_ppg_control_top_lifecycle_fault_adc_anomaly',src,newtb)
p='rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v'
rtl=(SNAP/p).read_text(encoding='utf-8').splitlines(True)
assert 'i_control_abort_event' in rtl[513] and 'adc_owner_inflight_o <= adc_owner_inflight_o' in rtl[514]
sim(name+'_counterfactual','tb_ppg_control_top_lifecycle_fault_adc_anomaly',src,newtb,{Path(p).name:''.join(rtl[:513]+rtl[515:])})
