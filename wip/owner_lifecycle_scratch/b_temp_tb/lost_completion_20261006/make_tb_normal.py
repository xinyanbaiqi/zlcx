"""Build the out-of-repo NORMAL-measurement lost-completion experiment TB (L-1/L-2 in NORMAL).
Base: tb_ppg_control_top.v at 517ab78. The background ADC responder gets three experiment flags:
  flag_exp_drop_red / flag_exp_drop_ir : skip exactly one NORMAL RED / IR completion, then respond normally;
  flag_exp_dead                        : from that moment on never respond again (ADC dead).
The experiment runs right after reset (before the original SMOKE sequence) and ends with $finish.
Plusargs: DROPRED / DROPIR / DEAD ; none = control (every completion delivered)."""
import os
D = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(D, 'snap', 'rtl', 'ppg_control_top', 'tb_ppg_control_top.v')
dst = os.path.join(D, 'snap', 'rtl', 'ppg_control_top', 'tb_lost_done_normal.v')
t = open(src, encoding='utf-8').read()
t = t.replace('module tb_ppg_control_top', 'module tb_lost_done_normal', 1)
SCH = 'ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst'
AMI = 'ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst'
SSW = 'ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst'

# 1) responder: skip hook (wraps the original hold/drive section in an else branch)
a1 = "\t\t\t\tif(flag_hold_next_adc_response == 1'b1) begin"
a2 = "\t\t\t\tcnt_adc_response = cnt_adc_response + 1;"
assert t.count(a1) == 1 and t.count(a2) == 1
skip = f'''				if(flag_exp_dead || (!flag_response_is_calibration && ((flag_exp_drop_red && !reg_response_color_ir) || (flag_exp_drop_ir && reg_response_color_ir)))) begin
					$display("EXP responder SKIPS this completion t=%0t color_ir=%b cal=%b inflight_idx=%0d macro_tick=%0d", $time, reg_response_color_ir,
						flag_response_is_calibration, {SCH}.o_adc_owner_sample_index, {SCH}.macro_tick_o);
					flag_exp_drop_red = 1'b0;
					flag_exp_drop_ir = 1'b0;
				end else begin
'''
t = t.replace(a1, skip + a1, 1)
t = t.replace(a2, a2 + '\n\t\t\t\tend', 1)

# 2) experiment flags + monitors, placed before the responder declarations
a3 = '\t//---------------后台ADC响应暂停控制信号---------------//'
assert t.count(a3) == 1
mon = f'''	//===================<lost-completion experiment flags and monitors (out-of-repo)>===================//
	reg flag_exp_drop_red = 1'b0;
	reg flag_exp_drop_ir = 1'b0;
	reg flag_exp_dead = 1'b0;
	reg reg_exp_q3_prev = 1'b0;
	reg [1:0] reg_exp_life_prev = 2'b00;
	reg [15:0] reg_exp_sticky_prev = 16'd0;
	wire [15:0] w_exp_sticky = {{{SCH}.o_owner_deadline_timeout_sticky, {SCH}.o_completion_mismatch_sticky, {SCH}.o_protocol_error_sticky,
		{SCH}.o_launch_timeout_sticky, {SSW}.o_owner_deadline_timeout_sticky, {SSW}.o_calibration_timeout_sticky, {SSW}.o_transaction_mismatch_sticky,
		{AMI}.o_integration_protocol_error_sticky, {AMI}.o_wrapper_fault_blocking, o_system_fault_blocking, {SCH}.o_scheduler_local_fault_blocking,
		{SSW}.o_wrapper_fault_blocking, 4'b0000}};
	always @(posedge i_clk) begin
		if({SCH}.adc_owner_commit_event_o)
			$display("MON OWNER  t=%0t frame=%0d mt=%0d color_ir=%b cal=%b idx=%0d", $time, {SCH}.o_current_frame_id, {SCH}.macro_tick_o,
				{SCH}.o_adc_owner_color_ir, !{SCH}.o_adc_owner_frame_type[1], {SCH}.o_adc_owner_sample_index);
		if({AMI}.o_adc_transaction_complete_event)
			$display("MON DONE   t=%0t frame=%0d mt=%0d success=%b idx=%0d", $time, {SCH}.o_current_frame_id, {SCH}.macro_tick_o,
				{AMI}.o_adc_transaction_success, {AMI}.o_adc_complete_sample_index);
		if(o_measurement_result_valid && i_measurement_result_ready)
			$display("MON RESULT t=%0t frame=%0d mt=%0d result_frame=%0d result_idx=%0d color_ir=%b sample_valid=%b", $time, {SCH}.o_current_frame_id,
				{SCH}.macro_tick_o, o_result_frame_id, o_result_sample_index, o_result_color_ir, o_result_sample_valid);
		if(o_clk_q3_low && !reg_exp_q3_prev)
			$display("MON Q3RISE t=%0t frame=%0d mt=%0d inflight=%b inflight_idx=%0d ssw_red_owner=%b ssw_ir_owner=%b", $time, {SCH}.o_current_frame_id,
				{SCH}.macro_tick_o, {SCH}.o_transaction_inflight, {SCH}.o_adc_owner_sample_index, {SSW}.flag_red_has_owner, {SSW}.flag_ir_has_owner);
		reg_exp_q3_prev <= o_clk_q3_low;
		if({SCH}.o_normal_frame_complete_event)
			$display("MON NFRAME_COMPLETE t=%0t frame=%0d", $time, {SCH}.o_current_frame_id);
		if(w_exp_sticky != reg_exp_sticky_prev)
			$display("MON STICKY t=%0t frame=%0d mt=%0d vec=%b (sch_own_dl,sch_mism,sch_proto,sch_launch,ssw_own_dl,ssw_cal_to,ssw_mism,ami_proto,ami_wrap_fault,sys_fault,sch_local_fault,ssw_wrap_fault)",
				$time, {SCH}.o_current_frame_id, {SCH}.macro_tick_o, w_exp_sticky[15:4]);
		reg_exp_sticky_prev <= w_exp_sticky;
		if(o_lifecycle_state != reg_exp_life_prev)
			$display("MON LIFE   t=%0t lifecycle=%b", $time, o_lifecycle_state);
		reg_exp_life_prev <= o_lifecycle_state;
	end
	// supervisor / drain visibility
	integer cnt_exp_status = 0;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_fault_valid_o) $display("MON SUPIN  t=%0t scheduler fault record cause=%h", $time, ppg_control_top_Inst.sched_fault_cause_o);
		if(ppg_control_top_Inst.ssw_fault_valid_o) $display("MON SUPIN  t=%0t ssw fault record cause=%h", $time, ppg_control_top_Inst.ssw_fault_cause_o);
		if(ppg_control_top_Inst.ami_fault_valid_o) $display("MON SUPIN  t=%0t ami fault record cause=%h", $time, ppg_control_top_Inst.ami_fault_cause_o);
		if(ppg_control_top_Inst.supervisor_system_abort_event_o) $display("MON SUPOUT t=%0t system abort event", $time);
		if(ppg_control_top_Inst.supervisor_system_stop_request_event_o) $display("MON SUPOUT t=%0t system STOP request", $time);
		if(ppg_control_top_Inst.flag_stop_request_event) $display("MON STOPREQ t=%0t merged STOP request to manager", $time);
		cnt_exp_status = cnt_exp_status + 1;
		if((o_lifecycle_state == 2'b11) && (cnt_exp_status % 20000 == 0))
			$display("MON DRAIN  t=%0t episode=%b adc_phys_idle=%b datapath_empty=%b idac_idle=%b analog_safe=%b sched_idle=%b inflight=%b sys_blocking=%b",
				$time, ppg_control_top_Inst.flag_stop_episode_active, ppg_control_top_Inst.flag_adc_physical_idle, ppg_control_top_Inst.ami_datapath_empty_o,
				ppg_control_top_Inst.ami_idac_idle_o, ppg_control_top_Inst.ssw_analog_safe_o, o_scheduler_idle,
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_transaction_inflight, o_system_fault_blocking);
	end

'''
t = t.replace(a3, mon + a3, 1)

# 3) experiment body before the original first commit
a4 = '\t\ttask_build_normal_manual_config; // 构造第一笔'
assert t.count(a4) == 1
exp = f'''		begin : lost_done_experiment
			integer mode;
			integer cnt_wait;
			mode = 0;
			if($test$plusargs("DROPRED")) mode = 1;
			if($test$plusargs("DROPIR")) mode = 2;
			if($test$plusargs("DEAD")) mode = 3;
			$display("EXP mode=%0d (0=control,1=drop one RED completion,2=drop one IR completion,3=ADC dead)", mode);
			task_build_normal_manual_dual_config;
			task_pulse_source_update;
			task_wait_config_result;
			if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
				$display("EXP FAIL commit");
				$finish;
			end
			task_pulse_start;
			// let 3 NORMAL macro frames run with every completion delivered
			cnt_wait = 0;
			while(({SCH}.o_current_frame_id < 3) && (cnt_wait < 40000)) begin
				@(posedge i_clk);
				cnt_wait = cnt_wait + 1;
			end
			$display("EXP fault injection point t=%0t frame=%0d mt=%0d", $time, {SCH}.o_current_frame_id, {SCH}.macro_tick_o);
			if(mode == 1) flag_exp_drop_red = 1'b1;
			if(mode == 2) flag_exp_drop_ir = 1'b1;
			if(mode == 3) flag_exp_dead = 1'b1;
			repeat(40000) @(posedge i_clk); // 8 more macro frames
			$display("EXP END t=%0t frame=%0d lifecycle=%b eligible=%b inflight=%b inflight_idx=%0d sticky_vec=%b results_total=%0d",
				$time, {SCH}.o_current_frame_id, o_lifecycle_state, {AMI}.o_normal_measurement_eligible, {SCH}.o_transaction_inflight,
				{SCH}.o_adc_owner_sample_index, w_exp_sticky[15:4], cnt_measurement_result_valid);
			$finish;
		end
'''
t = t.replace(a4, exp + a4, 1)
open(dst, 'w', encoding='utf-8', newline='\n').write(t)
print('written', dst)
