p = 'rtl2/rtl/ppg_control_top/ppg_control_top.v'
t = open(p, encoding='utf-8').read()
def rep(o, n):
    global t
    assert t.count(o) == 1, o[:100]; t = t.replace(o, n)
rep("\t\toutput o_ami_integration_protocol_error_sticky,           // AMI集成协议异常历史诊断\n",
    "\t\toutput o_ami_integration_protocol_error_sticky,           // AMI集成协议异常历史诊断\n"
    "\t\toutput o_ami_owner_lost_sticky,                          // AMI完成丢失超时作废历史诊断，新START不清\n")
rep("\twire [C_SAMPLE_INDEX_WIDTH - 1:0] ami_adc_complete_sample_index_o; // 内部转发：完成身份序号\n",
    "\twire [C_SAMPLE_INDEX_WIDTH - 1:0] ami_adc_complete_sample_index_o; // 内部转发：完成或作废身份序号，只在两种事件拍有效\n"
    "\twire ami_adc_transaction_lost_event_o;                     // 内部转发：AMI在途owner完成丢失超时作废单拍\n"
    "\twire ami_amb_pending_valid_o;                              // 内部转发：AMI内IDAC的AMB候选等待安全边界\n"
    "\twire ami_dcs_r_pending_valid_o;                            // 内部转发：AMI内IDAC的红光DC候选等待安全边界\n"
    "\twire ami_dcs_ir_pending_valid_o;                           // 内部转发：AMI内IDAC的红外DC候选等待安全边界\n"
    "\twire flag_idac_boundary_request;                          // 内部转发：IDAC三路任一候选待提交，供调度器启动搜索空闲期补发边界\n")
rep("\twire ami_integration_protocol_error_sticky_o;                 // 内部转发：集成协议异常历史诊断\n",
    "\twire ami_integration_protocol_error_sticky_o;                 // 内部转发：集成协议异常历史诊断\n"
    "\twire ami_owner_lost_sticky_o;                              // 内部转发：完成丢失超时作废历史诊断\n")
rep("\tassign flag_adc_physical_idle = i_adc_physical_idle;",
    "\tassign flag_idac_boundary_request = ami_amb_pending_valid_o || ami_dcs_r_pending_valid_o || ami_dcs_ir_pending_valid_o; // 三路IDAC候选待提交合并为调度器边界请求；L-3启动搜索空闲期边界来源\n"
    "\tassign flag_adc_physical_idle = i_adc_physical_idle;")
rep("\t\t\t.i_ssw_fault_blocking(ssw_wrapper_fault_blocking_o),  // 接帧调度器.i_ssw_fault_blocking：SSW波形保持或模拟时序路径报告的阻断故障\n",
    "\t\t\t.i_ssw_fault_blocking(ssw_wrapper_fault_blocking_o),  // 接帧调度器.i_ssw_fault_blocking：SSW波形保持或模拟时序路径报告的阻断故障\n"
    "\t\t\t.i_idac_boundary_request(flag_idac_boundary_request), // 接帧调度器.i_idac_boundary_request：IDAC候选待提交请求，仅启动搜索空闲期补发边界\n")
rep("\t\t\t.i_adc_complete_sample_index(ami_adc_complete_sample_index_o), // 接帧调度器.i_adc_complete_sample_index：完成身份序号\n",
    "\t\t\t.i_adc_complete_sample_index(ami_adc_complete_sample_index_o), // 接帧调度器.i_adc_complete_sample_index：完成身份序号\n"
    "\t\t\t.i_adc_transaction_lost_event(ami_adc_transaction_lost_event_o), // 接帧调度器.i_adc_transaction_lost_event：AMI超时作废单拍，按序号与代际释放owner\n")
o = "\t\t\t.i_adc_complete_sample_index(ami_adc_complete_sample_index_o), // 接SSW.i_adc_complete_sample_index："
i = t.index(o); assert t.count(o) == 1; j = t.index('\n', i)
t = t[:j+1] + "\t\t\t.i_adc_transaction_lost_event(ami_adc_transaction_lost_event_o), // 接SSW.i_adc_transaction_lost_event：AMI超时作废单拍，SSW同步释放owner\n" + t[j+1:]
o = "\t\t\t.o_adc_complete_sample_index(ami_adc_complete_sample_index_o), // 接AMI.o_adc_complete_sample_index："
i = t.index(o); assert t.count(o) == 1; j = t.index('\n', i)
t = t[:j+1] + "\t\t\t.o_adc_transaction_lost_event(ami_adc_transaction_lost_event_o), // 接AMI.o_adc_transaction_lost_event：在途owner完成丢失超时作废单拍，广播给调度器与SSW\n" + t[j+1:]
rep("\t\t\t.o_amb_pending_valid(),                               // 接AMI.o_amb_pending_valid：AMB候选等待提交状态\n",
    "\t\t\t.o_amb_pending_valid(ami_amb_pending_valid_o),        // 接AMI.o_amb_pending_valid：AMB候选等待提交状态，并入调度器边界请求\n")
rep("\t\t\t.o_dcs_r_pending_valid(),                             // 接AMI.o_dcs_r_pending_valid：红光DC候选等待提交状态\n",
    "\t\t\t.o_dcs_r_pending_valid(ami_dcs_r_pending_valid_o),    // 接AMI.o_dcs_r_pending_valid：红光DC候选等待提交状态，并入调度器边界请求\n")
rep("\t\t\t.o_dcs_ir_pending_valid(),                            // 接AMI.o_dcs_ir_pending_valid：红外DC候选等待提交状态\n",
    "\t\t\t.o_dcs_ir_pending_valid(ami_dcs_ir_pending_valid_o),  // 接AMI.o_dcs_ir_pending_valid：红外DC候选等待提交状态，并入调度器边界请求\n")
o = "\t\t\t.o_integration_protocol_error_sticky(ami_integration_protocol_error_sticky_o),"
i = t.index(o); assert t.count(o) == 1; j = t.index('\n', i)
t = t[:j+1] + "\t\t\t.o_owner_lost_sticky(ami_owner_lost_sticky_o),        // 接AMI.o_owner_lost_sticky：完成丢失超时作废历史诊断\n" + t[j+1:]
rep("\tassign o_ami_integration_protocol_error_sticky = ami_integration_protocol_error_sticky_o; // 对外输出：内部转发：集成协议异常历史诊断\n",
    "\tassign o_ami_integration_protocol_error_sticky = ami_integration_protocol_error_sticky_o; // 对外输出：内部转发：集成协议异常历史诊断\n"
    "\tassign o_ami_owner_lost_sticky = ami_owner_lost_sticky_o;     // 对外输出：AMI完成丢失超时作废历史，芯片顶层送SPI 0x0108 bit6\n")
open(p, 'w', encoding='utf-8', newline='\n').write(t); print('top patched')
