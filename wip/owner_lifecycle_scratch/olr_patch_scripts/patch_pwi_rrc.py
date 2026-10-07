import sys
def patch(p, pairs):
    t = open(p, encoding='utf-8').read()
    for o, n in pairs:
        assert t.count(o) == 1, (p, o[:80]); t = t.replace(o, n)
    open(p, 'w', encoding='utf-8', newline='\n').write(t); print('patched', p)
R = 'rtl2/rtl/'
patch(R + 'ppg_precision_window_integration/ppg_precision_window_integration.v', [
 ("\tinput i_dcs_sample_accepted_event,          // 确认当前颜色直流校准结果完成消费\n",
  "\tinput i_dcs_sample_accepted_event,          // 确认当前颜色直流校准结果完成消费\n"
  "\tinput i_calibration_request_withdraw_event, // AMI转送的周期重检在途请求撤销单拍，来源为SID-05截止或校准owner超时作废\n"),
 ("\t\t.i_dcs_sample_accepted_event(i_dcs_sample_accepted_event), // 确认颜色直流校准样本已消费\n",
  "\t\t.i_dcs_sample_accepted_event(i_dcs_sample_accepted_event), // 确认颜色直流校准样本已消费\n"
  "\t\t.i_calibration_request_withdraw_event(i_calibration_request_withdraw_event), // 原样转送重检在途请求撤销，供重检调度器释放内层在途；F-020\n"),
])
patch(R + 'ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v', [
 ("\tinput i_dcs_sample_accepted_event,          // 当前颜色DCS_CAL结果完成控制器消费\n",
  "\tinput i_dcs_sample_accepted_event,          // 当前颜色DCS_CAL结果完成控制器消费\n"
  "\tinput i_calibration_request_withdraw_event, // 外层在途请求被截止撤销或owner超时作废的单拍，不会再有对应结果返回\n"),
 ("\t\tend else if(flag_matching_sample_accepted == 1'b1)begin\n\t\t\tflag_sample_inflight <= 1'b0;       // IDAC实际消费结果后允许下一笔请求\n",
  "\t\tend else if(flag_matching_sample_accepted == 1'b1)begin\n\t\t\tflag_sample_inflight <= 1'b0;       // IDAC实际消费结果后允许下一笔请求\n"
  "\t\tend else if(i_calibration_request_withdraw_event == 1'b1)begin\n\t\t\tflag_sample_inflight <= 1'b0;       // 外层请求被撤销后同步释放内层在途，保持型IDAC请求随即重发同一候选；F-020 @satisfies: SID-05\n"),
])
