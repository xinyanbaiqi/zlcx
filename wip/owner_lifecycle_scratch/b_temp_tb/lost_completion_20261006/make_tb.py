"""Build the out-of-repo experiment TB for the SSW-18 / tick-385 investigation.
Copies tb_ppg_control_top_startup_idac_calibration.v (snapshot 517ab78), inserts an experiment right before
run_jnt_baseline_01_09 (ending in $finish, so the original phases never run), and adds passive monitors.
Plusargs (no '=' allowed under xsim on Windows): LATE385 / LATENEXT / LATE2SF select the delayed-completion
variant for AMB candidate #2; no plusarg = control group (every completion right after Q3 release)."""
import os
D = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(D, 'snap', 'rtl', 'ppg_control_top', 'tb_ppg_control_top_startup_idac_calibration.v')
dst = os.path.join(D, 'snap', 'rtl', 'ppg_control_top', 'tb_ssw18_late_completion.v')
t = open(src, encoding='utf-8').read()
t = t.replace('module tb_ppg_control_top_startup_idac_calibration', 'module tb_ssw18_late_completion', 1)

SCH = 'ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst'
AMI = 'ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst'
IDC = AMI + '.ppg_idac_code_controller_Inst'
SSW = 'ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst'

exp = f'''
		//===================<SSW-18 experiment (out-of-repo)>===================//
		begin : ssw18_experiment
			integer k;
			integer mode;
			reg [2:0] sf0;
			integer n_sf_change;
			reg [2:0] sf_prev;
			reg rr;
			mode = 0;
			if($test$plusargs("LATE385")) mode = 1;
			if($test$plusargs("LATENEXT")) mode = 2;
			if($test$plusargs("LATE2SF")) mode = 3;
			if($test$plusargs("NODONE")) mode = 4;
			if($test$plusargs("DEADADC")) mode = 5;
			if($test$plusargs("LATE6SF")) mode = 7;
			$display("EXP mode=%0d (0=on-time control,1=done after local tick 400,2=next subframe tick 100,3=two subframes later)", mode);
			task_build_search_track_config;
			task_pulse_source_update;
			task_wait_config_result;
			if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
				$display("EXP FAIL commit");
				$finish;
			end
			task_pulse_start;
			for(k = 1; k <= 6; k = k + 1) begin
				wait_q3_release(rr);
				if(!rr) begin
					$display("EXP candidate %0d: no Q3 within watchdog (t=%0t)", k, $time);
				end else begin
					if((k >= 2) && (mode == 5)) begin
						$display("EXP candidate %0d: ADC dead, no DONE (t=%0t sf=%0d lt=%0d)", k, $time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick);
					end else if((k == 2) && (mode == 4)) begin
						$display("EXP candidate %0d: DONE deliberately never driven (owner committed in sf=%0d)", k, {SCH}.o_calibration_subframe_index);
					end else if((k == 2) && (mode != 0)) begin
						sf0 = {SCH}.o_calibration_subframe_index;
						if(mode == 1) begin
							while({SCH}.o_calibration_local_tick < 10'd400) @(negedge i_clk);
						end else begin
							n_sf_change = 0;
							sf_prev = sf0;
							while(n_sf_change < ((mode == 7) ? 6 : (mode - 1))) begin
								@(negedge i_clk);
								if({SCH}.o_calibration_subframe_index != sf_prev) begin
									n_sf_change = n_sf_change + 1;
									sf_prev = {SCH}.o_calibration_subframe_index;
								end
							end
							while({SCH}.o_calibration_local_tick < ((mode == 7) ? 10'd600 : 10'd100)) @(negedge i_clk);
						end
						$display("EXP candidate %0d: delayed DONE driven at sf=%0d lt=%0d (owner was committed in sf=%0d)", k,
							{SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick, sf0);
					end
					if(!((k == 2) && (mode == 4)) && !((k >= 2) && (mode == 5))) task_drive_amb_toward_target(reg_exp_last_owner_amb, 64);
				end
			end
			repeat(3000) @(posedge i_clk);
			$display("EXP END amb_code=%0d epoch=%0d search_done=%b exhausted=%b amb_fault=%b ctrl_fault=%b idac_proto=%b ami_proto=%b sch_owner_dl=%b sch_mismatch=%b sch_proto=%b sch_launch=%b ssw_cal_timeout=%b ssw_owner_dl=%b sys_fault=%b",
				{IDC}.o_amb_code, {IDC}.o_amb_code_epoch, {IDC}.o_amb_search_done, {IDC}.o_amb_search_exhausted, {IDC}.o_amb_fault,
				{IDC}.o_controller_fault_blocking, {IDC}.o_protocol_error_sticky, {AMI}.o_integration_protocol_error_sticky,
				{SCH}.o_owner_deadline_timeout_sticky, {SCH}.o_completion_mismatch_sticky, {SCH}.o_protocol_error_sticky, {SCH}.o_launch_timeout_sticky,
				{SSW}.o_calibration_timeout_sticky, {SSW}.o_owner_deadline_timeout_sticky, o_system_fault_blocking);
			$display("EXP STATE idac_state=%0d amb_pending=%b amb_request=%b ami_cal_valid=%b sch_frame_active=%b cal_frame_active=%b cal_req_pending=%b sch_idle=%b",
				{IDC}.state_current, {IDC}.o_amb_pending_valid, {IDC}.o_amb_sample_request, {AMI}.o_calibration_sample_valid,
				{SCH}.state_current[{SCH}.B_FRAME_ACTIVE], {SCH}.o_calibration_frame_active, {SCH}.state_current[{SCH}.B_CAL_REQ_PENDING], {SCH}.o_scheduler_idle);
			$finish;
		end
'''
anchor = '\t\trun_jnt_baseline_01_09;'
assert t.count(anchor) == 1
t = t.replace(anchor, exp + anchor, 1)

mon = f'''
	//===================<SSW-18 experiment monitors (passive)>===================//
	reg [7:0] reg_exp_last_owner_amb = 8'd0;
	reg [15:0] reg_exp_sticky_prev = 16'd0;
	wire [15:0] w_exp_sticky = {{{SSW}.o_calibration_timeout_sticky, {SSW}.o_owner_deadline_timeout_sticky,
		{SCH}.o_owner_deadline_timeout_sticky, {SCH}.o_completion_mismatch_sticky, {SCH}.o_protocol_error_sticky, {SCH}.o_launch_timeout_sticky,
		{IDC}.o_protocol_error_sticky, {IDC}.o_amb_fault, {IDC}.o_amb_search_exhausted, {IDC}.o_controller_fault_blocking,
		{AMI}.o_integration_protocol_error_sticky, o_system_fault_blocking, {IDC}.o_amb_search_done, 3'b000}};
	always @(posedge i_clk) begin
		if({SCH}.adc_owner_commit_event_o) begin
			reg_exp_last_owner_amb <= {SCH}.o_adc_owner_amb_code_snapshot;
			$display("MON OWNER   t=%0t sf=%0d lt=%0d idx=%0d amb_snapshot=%0d", $time, {SCH}.o_calibration_subframe_index,
				{SCH}.o_calibration_local_tick, {SCH}.o_adc_owner_sample_index, {SCH}.o_adc_owner_amb_code_snapshot);
		end
		if({AMI}.o_calibration_sample_valid && {AMI}.i_calibration_sample_ready)
			$display("MON CALREQ  t=%0t sf=%0d lt=%0d", $time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick);
		if({AMI}.o_adc_transaction_complete_event)
			$display("MON DONE    t=%0t sf=%0d lt=%0d", $time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick);
		if({IDC}.i_search_amb_valid && {IDC}.o_search_amb_ready)
			$display("MON AMBSMP  t=%0t sf=%0d lt=%0d sample_snapshot=%0d current=%0d qualified=%b", $time, {SCH}.o_calibration_subframe_index,
				{SCH}.o_calibration_local_tick, {IDC}.i_search_amb_code_snapshot, {IDC}.o_amb_code, {IDC}.flag_amb_sample_qualified);
		if({IDC}.o_amb_code_update)
			$display("MON AMBCOMMIT t=%0t sf=%0d lt=%0d new_code=%0d", $time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick, {IDC}.o_amb_code);
		if({SCH}.o_calibration_frame_complete_event)
			$display("MON CALFRAME_COMPLETE t=%0t", $time);
		if({SCH}.o_calibration_frame_active && ({SCH}.o_calibration_local_tick == 10'd385))
			$display("MON T385    t=%0t sf=%0d ssw_cal_ctx_valid=%b ssw_cal_has_owner=%b", $time, {SCH}.o_calibration_subframe_index,
				{SSW}.flag_cal_context_valid, {SSW}.flag_cal_has_owner);
		if(w_exp_sticky != reg_exp_sticky_prev)
			$display("MON STICKY  t=%0t sf=%0d lt=%0d vec=%b (ssw_cal_to,ssw_own_dl,sch_own_dl,sch_mism,sch_proto,sch_launch,idc_proto,amb_fault,amb_exh,ctrl_fault,ami_proto,sys_fault,amb_done)",
				$time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick, w_exp_sticky[15:3]);
		reg_exp_sticky_prev <= w_exp_sticky;
	end
'''
anchor2 = '\t//---------------真实ADC完成响应任务---------------//'
assert t.count(anchor2) == 1
t = t.replace(anchor2, mon + '\n' + anchor2, 1)
open(dst, 'w', encoding='utf-8', newline='\n').write(t)
print('written', dst)
