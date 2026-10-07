import sys
p = 'rtl2/rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v'
t = open(p, encoding='utf-8').read()
def rep(o, n):
    global t
    assert t.count(o) == 1, o[:100]; t = t.replace(o, n)
rep("\tinput i_ssw_fault_blocking,                 // SSW波形保持或模拟时序路径报告的阻断故障\n",
    "\tinput i_ssw_fault_blocking,                 // SSW波形保持或模拟时序路径报告的阻断故障\n"
    "\tinput i_idac_boundary_request,              // AMI内IDAC任一路候选码等待安全边界提交，供启动搜索空闲期补发边界\n")
rep("\tinput [C_SAMPLE_INDEX_WIDTH - 1:0]i_adc_complete_sample_index, // 完成身份序号\n",
    "\tinput [C_SAMPLE_INDEX_WIDTH - 1:0]i_adc_complete_sample_index, // 完成或作废身份序号，只在两种事件拍有效\n"
    "\tinput i_adc_transaction_lost_event,         // AMI在途owner完成丢失超时作废单拍，与完成事件互斥\n")
rep("\twire flag_completion_success;               // 匹配且成功且非丢弃\n",
    "\twire flag_completion_success;               // 匹配且成功且非丢弃\n"
    "\twire flag_owner_lost_match;                 // AMI作废事件与在途owner序号及代际一致\n"
    "\twire flag_candidate_expired;                // 当前最早候选已越过本槽位owner截止相位，不得再提交\n"
    "\twire flag_idle_idac_safe_boundary;          // 启动搜索中调度器空闲且本拍不开帧时为IDAC待提交候选补发的单拍边界\n")
rep("\tassign transaction_start_valid_o = flag_transaction_candidate && i_adc_owner_ready && i_allow_new_transaction && flag_lifecycle_active; ",
    "\tassign flag_candidate_expired = (flag_candidate_red && (macro_tick_o > C_NORMAL_RED_OWNER_DEADLINE)) || (flag_candidate_ir && (macro_tick_o > C_NORMAL_IR_OWNER_DEADLINE)) || (flag_candidate_calibration && (calibration_local_tick_o > C_CAL_OWNER_DEADLINE)); "
    "// 截止相位当拍仍允许按时提交（与SSW窗口<=截止一致），越过截止的候选只走截止收尾，杜绝L-4的同拍截止与提交 @satisfies: LFA-09, OIB-02\n"
    "\tassign transaction_start_valid_o = flag_transaction_candidate && !flag_candidate_expired && i_adc_owner_ready && i_allow_new_transaction && flag_lifecycle_active; ")
rep("\tassign flag_completion_success = ",
    "\tassign flag_owner_lost_match = i_adc_transaction_lost_event && state_current[B_INFLIGHT] && (i_adc_complete_sample_index == state_current[B_INFLIGHT_SAMPLE_H:B_INFLIGHT_SAMPLE_L]) && (i_run_generation == state_current[B_INFLIGHT_GENERATION_H:B_INFLIGHT_GENERATION_L]); "
    "// 作废以事件限定序号总线，按与完成相同的序号和代际匹配，不置success也不置颜色完成位 @satisfies: TOP-03\n"
    "\tassign flag_completion_success = ")
rep("\tassign idac_code_safe_boundary_o = startup_idac_safe_boundary_o || macro_frame_safe_boundary_o || flag_calibration_boundary_o; ",
    "\tassign flag_idle_idac_safe_boundary = i_idac_boundary_request && flag_lifecycle_active && i_active_config_valid && !i_normal_measurement_eligible && !flag_frame_start_eligible && !state_current[B_STARTUP_PENDING] && !state_current[B_FRAME_ACTIVE] && !state_current[B_CAL_REQ_PENDING] && !state_current[B_RED_WAVE_PENDING] && !state_current[B_IR_WAVE_PENDING] && !state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT] && i_adc_idle && i_analog_safe && i_sar_timing_idle; "
    "// L-3：校准结果在末子帧tick 385后才被消费时IDAC候选无边界可等、调度器又无请求不开帧；仅启动搜索阶段、本拍不会开帧时补发，IDAC提交后请求即撤销，不影响NORMAL帧码提交时序 @satisfies: SID-06\n"
    "\tassign idac_code_safe_boundary_o = startup_idac_safe_boundary_o || macro_frame_safe_boundary_o || flag_calibration_boundary_o || flag_idle_idac_safe_boundary; ")
rep("\t\t\t\tend else if(i_adc_transaction_success == 1'b0 && !state_current[B_INFLIGHT_DISCARD])begin\n\t\t\t\t\tstate_next[B_FRAME_FAILED] = 1'b1; // success=0只做失败收尾\n\t\t\t\tend\n\t\t\tend else if(i_adc_transaction_complete_event == 1'b1)begin\n",
    "\t\t\t\tend else if(i_adc_transaction_success == 1'b0 && !state_current[B_INFLIGHT_DISCARD])begin\n\t\t\t\t\tstate_next[B_FRAME_FAILED] = 1'b1; // success=0只做失败收尾\n\t\t\t\tend\n"
    "\t\t\tend else if(flag_owner_lost_match == 1'b1)begin\n"
    "\t\t\t\tstate_next[B_INFLIGHT] = 1'b0;  // AMI超时作废释放唯一owner，下一拍起可按截止或新候选推进\n"
    "\t\t\t\tstate_next[B_INFLIGHT_DISCARD] = 1'b0; // 作废后不再保留最小身份，STOP或abort排空随之可结束\n"
    "\t\t\t\tif(!state_current[B_INFLIGHT_DISCARD])begin\n"
    "\t\t\t\t\tstate_next[B_FRAME_FAILED] = 1'b1; // 作废事务所在帧沿用失败收尾语义，不计NORMAL完成帧\n"
    "\t\t\t\tend\n"
    "\t\t\tend else if(i_adc_transaction_complete_event == 1'b1 || i_adc_transaction_lost_event == 1'b1)begin\n")
rep("\t\t\t\t\t\t\tif(state_current[B_CAL_REQ_PENDING] || state_current[B_CAL_WAVE_PENDING] || state_current[B_INFLIGHT])begin\n\t\t\t\t\t\t\t\tstate_next[B_CAL_REQ_PENDING] = 1'b1; // 未成功提交的请求跨宏帧保留\n",
    "\t\t\t\t\t\t\tif(state_current[B_CAL_REQ_PENDING] || state_current[B_CAL_WAVE_PENDING])begin\n\t\t\t\t\t\t\t\tstate_next[B_CAL_REQ_PENDING] = 1'b1; // 未成功提交的请求跨宏帧保留；已成为在途owner的请求不再重挂，由迟到完成或AMI超时作废后的重发推进，杜绝L-1错绑 @satisfies: FSC-31\n")
open(p, 'w', encoding='utf-8', newline='\n').write(t); print('sched patched')
