p = 'rtl2/rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v'
t = open(p, encoding='utf-8').read()
def rep(o, n):
    global t
    assert t.count(o) == 1, o[:100]; t = t.replace(o, n)
rep("\tinput [C_SAMPLE_INDEX_WIDTH - 1:0]i_adc_complete_sample_index, // 输入端输入模数转换完成采样序号直流码通路低位编码端\n",
    "\tinput [C_SAMPLE_INDEX_WIDTH - 1:0]i_adc_complete_sample_index, // 输入端输入模数转换完成采样序号直流码通路低位编码端\n"
    "\tinput i_adc_transaction_lost_event,         // 输入端AMI在途owner完成丢失超时作废单拍，按序号与代际匹配释放owner\n")
rep("\treg reg_owner_precision_mode = 1'b0;        // 时序寄存寄存结果所有权提交时刻锁存的精度身份\n",
    "\treg reg_owner_precision_mode = 1'b0;        // 时序寄存寄存结果所有权提交时刻锁存的精度身份\n"
    "\treg [2:0]reg_owner_cal_subframe = 3'd0;     // 校准owner提交时所在的3200 Hz子帧序号，与帧号一起把owner绑定到本子帧上下文\n")
rep("\tassign flag_owner_release = i_adc_transaction_complete_event && adc_owner_inflight_o && ",
    "\tassign flag_owner_release = (i_adc_transaction_complete_event || i_adc_transaction_lost_event) && adc_owner_inflight_o && ")
rep("\tassign flag_done_mismatch = i_adc_transaction_complete_event && !flag_owner_release; // 组合连线条件完成失配高位编码端低位编码端，与owner_release互补，代际或序号任一不符均视为失配\n",
    "\tassign flag_done_mismatch = (i_adc_transaction_complete_event || i_adc_transaction_lost_event) && !flag_owner_release; // 组合连线条件完成失配高位编码端低位编码端，与owner_release互补，代际或序号任一不符均视为失配；作废事件与完成事件同样以事件限定序号并按同一规则核对 @satisfies: SSW-22\n")
rep("\tassign flag_red_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_RED); // 组合连线条件红光存在结果所有权红光专属可见光路高位编码端低位编码端\n",
    "\tassign flag_red_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_RED) && (reg_owner_frame_id == reg_red_frame_id); // 组合连线条件红光存在结果所有权：只认绑定到当前RED上下文帧号的owner，跨帧残留旧owner不驱动新帧Q3也不掩盖截止；L-1 @satisfies: SID-06\n")
rep("\tassign flag_ir_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_IR); // 组合连线条件红外存在结果所有权红外专属红外光路高位编码端低位编码端\n",
    "\tassign flag_ir_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_IR) && (reg_owner_frame_id == reg_ir_frame_id); // 组合连线条件红外存在结果所有权：IR owner须属于当前IR上下文所在帧，下一帧IR接管后旧owner失效；L-1\n")
rep("\tassign flag_cal_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_CAL); // 组合连线条件校准存在结果所有权高位编码端低位编码端\n",
    "\tassign flag_cal_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_CAL) && (reg_owner_frame_id == reg_cal_frame_id) && (reg_owner_cal_subframe == i_calibration_subframe_index); // 组合连线条件校准存在结果所有权：帧号与子帧序号同时一致才算本子帧owner，S1与L-1共用此绑定\n")
rep("\t\t\tif(flag_cal_context_valid == 1'b1 && (i_calibration_local_tick == CAL_COMMIT_TICK) && flag_cal_has_owner == 1'b0)begin\n",
    "\t\t\tif(i_calibration_frame_active == 1'b1 && (i_calibration_local_tick == CAL_COMMIT_TICK) && flag_cal_has_owner == 1'b1)begin\n")
rep("\t\t\t\tcalibration_timeout_sticky_o <= 1'b1; // 时序写入校准超时保持输出低位编码端红光波形控制更新\n",
    "\t\t\t\tcalibration_timeout_sticky_o <= 1'b1; // 本子帧校准owner到local tick 385仍未完成即记迟到诊断（ADC已在tick 266采样、迟到的只是读出），非阻断；丢失由AMI超时作废另报；S1 @satisfies: SSW-18\n")
anchor = "\t// 时序维护寄存结果所有权提交时刻锁存的颜色身份\n"
rep(anchor,
    "\t// 校准owner提交沿锁存所在子帧序号，供S1迟到诊断与Q3绑定判定，释放与abort期间保持\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\treg_owner_cal_subframe <= 3'd0; // 复位清除owner子帧绑定\n"
    "\t\tend else if(flag_owner_commit_fire == 1'b1 && i_control_abort_event == 1'b0)begin\n"
    "\t\t\treg_owner_cal_subframe <= i_calibration_subframe_index; // 提交沿记录调度器当前子帧，RED/IR owner同样记录但只在校准槽位使用\n"
    "\t\tend\n"
    "\tend\n\n" + anchor)
open(p, 'w', encoding='utf-8', newline='\n').write(t); print('ssw patched')
