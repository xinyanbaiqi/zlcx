"""Owner-lifecycle round: AMI patch (R3 timeout void, per-slot k, lanes 06/07, discard 2'b11,
merged calibration-request withdraw for SID-05/F-020, L-5 lane clear at drained STOP-end, lost sticky).
Usage: python patch_ami.py <ami.v>   (applied in place, every anchor must be unique)."""
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()


def rep(old, new, cnt=1):
    global t
    n = t.count(old)
    assert n == cnt, (n, old[:120])
    t = t.replace(old, new)


# ---------------- parameters ----------------
rep("\tparameter integer C_ENABLE_TEST_INJECTION = 32'd0 // 默认关闭的验证专用异常注入结构生成使能\n",
    "\tparameter integer C_ADC_COMPLETION_LOST_CYCLES = 32'd4500, // T-lost：在途owner自start fire起满该拍数、物理ADC空闲且捕获链无完成时作废，须大于实测最晚合法迟到4355拍并小于下一帧同色接管4717拍\n"
    "\tparameter integer C_ADC_COMPLETION_LOST_LIMIT = 32'd2, // k：同一槽位连续作废达到该次数即经cause 8'h06升级为系统故障\n"
    "\tparameter integer C_ENABLE_TEST_INJECTION = 32'd0 // 默认关闭的验证专用异常注入结构生成使能\n")

# ---------------- ports ----------------
rep("\toutput [C_SAMPLE_INDEX_WIDTH - 1:0]o_adc_complete_sample_index, // 与完成脉冲绑定的启动事务序号\n",
    "\toutput [C_SAMPLE_INDEX_WIDTH - 1:0]o_adc_complete_sample_index, // 与完成脉冲或作废脉冲绑定的启动事务序号\n"
    "\toutput o_adc_transaction_lost_event,        // 在途owner完成丢失超时作废单拍，与完成脉冲永不同拍，不携带success\n")
rep("\toutput o_integration_protocol_error_sticky, // 集成协议异常历史诊断\n",
    "\toutput o_integration_protocol_error_sticky, // 集成协议异常历史诊断\n"
    "\toutput o_owner_lost_sticky,                 // ADC完成丢失超时作废历史诊断，新START不清\n")

# ---------------- localparams ----------------
rep("\tlocalparam [1:0]DISCARD_REASON_SYSTEM_FAULT = 2'b10; // 私有discard组系统故障原因编码\n",
    "\tlocalparam [1:0]DISCARD_REASON_SYSTEM_FAULT = 2'b10; // 私有discard组系统故障原因编码\n"
    "\tlocalparam [1:0]DISCARD_REASON_COMPLETION_LOST = 2'b11; // 正式结果discard专用：在途owner完成丢失被超时作废，占用2位字段最后一个空位\n"
    "\tlocalparam integer ADC_BUSY_FAULT_CYCLES = 2 * C_ADC_COMPLETION_LOST_CYCLES; // owner年龄到达该值时物理ADC仍非空闲即报cause 8'h07，计数器在此饱和\n")

# ---------------- counters (new region before 寄存器信号) ----------------
rep("\t//----------------寄存器信号----------------//\n\treg [1:0]reg_inflight_frame_type = 2'b00;   // 在途校准结果期望类型\n",
    "\t//----------------计数信号----------------//\n"
    "\treg [15:0]cnt_owner_age = 16'd0;            // 唯一ADC owner自start fire起的在途拍数，饱和于ADC_BUSY_FAULT_CYCLES\n"
    "\treg [3:0]cnt_lost_red = 4'd0;               // RED槽位连续超时作废次数，RED真实完成或START清零\n"
    "\treg [3:0]cnt_lost_ir = 4'd0;                // IR槽位连续超时作废次数，只被IR自身真实完成清零\n"
    "\treg [3:0]cnt_lost_cal = 4'd0;               // 校准槽位连续超时作废次数，截止撤销不计入\n"
    "\n"
    "\t//----------------寄存器信号----------------//\n\treg [1:0]reg_inflight_frame_type = 2'b00;   // 在途校准结果期望类型\n")

# ---------------- flag regs ----------------
rep("\treg flag_ami_fault_pending_05 = 1'b0;       // cause 8'h05待分发标记，IDAC控制器新episode到达时置位\n",
    "\treg flag_ami_fault_pending_05 = 1'b0;       // cause 8'h05待分发标记，IDAC控制器新episode到达时置位\n"
    "\treg flag_ami_fault_pending_06 = 1'b0;       // cause 8'h06待分发标记，某槽位连续作废达到k次时置位\n"
    "\treg flag_ami_fault_pending_07 = 1'b0;       // cause 8'h07待分发标记，owner年龄到9000拍物理ADC仍忙时置位\n")
rep("\treg flag_recovery_context_fault_hold = 1'b0; // cause 8'h03无法证明可用原owner恢复，保持到本RUN结束\n",
    "\treg flag_recovery_context_fault_hold = 1'b0; // cause 8'h03无法证明可用原owner恢复，保持到本RUN结束\n"
    "\treg flag_owner_lost_fault_hold = 1'b0;      // cause 8'h06同槽位连续完成丢失，保持到abort、START或本RUN结束排空\n"
    "\treg flag_adc_busy_fault_hold = 1'b0;        // cause 8'h07物理ADC长期不回空闲，保持到abort、START或本RUN结束排空\n")

# ---------------- flag wires ----------------
rep("\twire flag_adc_completion_success;           // 非abort且元数据一致的可继续处理资格\n",
    "\twire flag_adc_completion_success;           // 非abort且元数据一致的可继续处理资格\n"
    "\twire flag_owner_lost_fire;                  // 本拍作废在途owner：年龄满T-lost、物理空闲、捕获与待发布完成均空、无同拍正式discard\n"
    "\twire flag_adc_busy_fault_fire;              // owner年龄恰到9000拍且物理ADC仍非空闲、无法作废的单拍\n"
    "\twire flag_owner_slot_red;                   // 在途owner属于RED采样槽位\n"
    "\twire flag_owner_slot_ir;                    // 在途owner属于IR采样槽位\n"
    "\twire flag_owner_slot_cal;                   // 在途owner属于AMB或DCS校准槽位\n"
    "\twire flag_owner_alive_completion;           // 与owner逐位匹配的真实完成发布，证明该槽位ADC仍在应答\n"
    "\twire flag_owner_lost_limit_reached;         // 本次作废使该槽位连续作废次数达到k\n"
    "\twire flag_calibration_request_withdraw;     // 在途校准请求撤销：SID-05截止或校准owner超时作废，二者合并\n"
    "\twire flag_recheck_request_withdraw;         // 撤销命中的在途请求来自周期重检时转送PWI释放内层在途\n"
    "\twire flag_run_context_drained;              // 当前RUN已由STOP结束且AMI全链排空，故障lane按本RUN结束落下\n")
rep("\twire flag_ami_fault_dispatch_05;            // IDAC阻断故障占用分发槽位的判定，让位给01/02/03/04\n",
    "\twire flag_ami_fault_dispatch_05;            // IDAC阻断故障占用分发槽位的判定，让位给01/02/03/04\n"
    "\twire flag_ami_fault_dispatch_06;            // 连续完成丢失故障占用分发槽位的判定，让位给01至05\n"
    "\twire flag_ami_fault_dispatch_07;            // ADC长期忙故障占用分发槽位的判定，七路中优先级最低\n")

# ---------------- output regs ----------------
rep("\treg [C_SAMPLE_INDEX_WIDTH - 1:0]adc_complete_sample_index_o = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 完成通知绑定的稳定事务序号\n",
    "\treg [C_SAMPLE_INDEX_WIDTH - 1:0]adc_complete_sample_index_o = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 完成通知绑定的稳定事务序号\n"
    "\treg adc_transaction_lost_event_o = 1'b0;    // 超时作废通知寄存，与完成通知分属两条独立事件线\n"
    "\treg owner_lost_sticky_o = 1'b0;             // 完成丢失作废历史位寄存，按N-1清除规则保持\n")

# ---------------- combinational ----------------
rep("\tassign flag_adc_completion_success = ",
    "\tassign flag_owner_lost_fire = flag_adc_transaction_inflight && (cnt_owner_age >= C_ADC_COMPLETION_LOST_CYCLES) && i_adc_idle && !flag_capture_valid && !flag_adc_completion_pending && !flag_measurement_result_discard_fire && !i_start_ack_event; "
    "// AMI是作废与迟到完成的唯一裁决点：物理空闲、捕获缓存和待发布完成三项同拍原子判断，完成一旦进入捕获缓存即优先；同拍正式discard占用公开discard寄存时推迟一拍 @satisfies: AMI-39, LFA-04\n"
    "\tassign flag_adc_busy_fault_fire = flag_adc_transaction_inflight && (cnt_owner_age == (ADC_BUSY_FAULT_CYCLES - 1)) && !i_adc_idle; // 计数跨入饱和值的那一拍物理ADC仍忙才报一次，饱和后不再重复\n"
    "\tassign flag_owner_slot_red = (reg_adc_inflight_frame_type == FRAME_TYPE_NORMAL) && !reg_adc_inflight_color_ir; // 由owner启动沿锁存的类型与颜色译出RED槽位\n"
    "\tassign flag_owner_slot_ir = (reg_adc_inflight_frame_type == FRAME_TYPE_NORMAL) && reg_adc_inflight_color_ir; // 由owner启动沿锁存的类型与颜色译出IR槽位\n"
    "\tassign flag_owner_slot_cal = (reg_adc_inflight_frame_type != FRAME_TYPE_NORMAL); // AMB_CAL与DCS_CAL共用唯一校准槽位\n"
    "\tassign flag_owner_alive_completion = flag_adc_completion_normal_emit && flag_adc_completion_owner_match; // success=0的受控释放同样证明物理ADC应答，按槽位清零连续作废计数\n"
    "\tassign flag_owner_lost_limit_reached = flag_owner_lost_fire && ((flag_owner_slot_red && (cnt_lost_red >= (C_ADC_COMPLETION_LOST_LIMIT - 1))) || (flag_owner_slot_ir && (cnt_lost_ir >= (C_ADC_COMPLETION_LOST_LIMIT - 1))) || (flag_owner_slot_cal && (cnt_lost_cal >= (C_ADC_COMPLETION_LOST_LIMIT - 1)))); // 只看被作废owner自己槽位的计数\n"
    "\tassign flag_calibration_request_withdraw = i_cal_owner_deadline_event || (flag_owner_lost_fire && flag_owner_slot_cal); // SID-05截止撤销与校准owner超时作废合并为同一撤销事件，二者都意味着在途请求不会再有结果；F-020 @satisfies: SID-05\n"
    "\tassign flag_recheck_request_withdraw = flag_calibration_request_withdraw && flag_calibration_request_inflight && (reg_inflight_reason == REASON_RECHECK); // 只把命中周期重检在途请求的撤销转送PWI，避免误清重检调度器内层状态\n"
    "\tassign flag_run_context_drained = flag_run_context_ended && o_datapath_empty; // STOP确认结束本RUN且被作废事务已不计在途，全链排空后无残留阻断原因\n"
    "\tassign flag_adc_completion_success = ")

rep("\tassign flag_ami_fault_dispatch_05 = flag_ami_fault_pending_05 && !flag_ami_fault_pending_01 && !flag_ami_fault_pending_02 && !flag_ami_fault_pending_03 && !flag_ami_fault_pending_04; ",
    "\tassign flag_ami_fault_dispatch_06 = flag_ami_fault_pending_06 && !flag_ami_fault_pending_01 && !flag_ami_fault_pending_02 && !flag_ami_fault_pending_03 && !flag_ami_fault_pending_04 && !flag_ami_fault_pending_05; // 01至05都不占槽时连续丢失记录出槽\n"
    "\tassign flag_ami_fault_dispatch_07 = flag_ami_fault_pending_07 && !flag_ami_fault_pending_01 && !flag_ami_fault_pending_02 && !flag_ami_fault_pending_03 && !flag_ami_fault_pending_04 && !flag_ami_fault_pending_05 && !flag_ami_fault_pending_06; // 前六路都空闲时ADC长期忙记录才出槽\n"
    "\tassign flag_ami_fault_dispatch_05 = flag_ami_fault_pending_05 && !flag_ami_fault_pending_01 && !flag_ami_fault_pending_02 && !flag_ami_fault_pending_03 && !flag_ami_fault_pending_04; ")

# outputs
rep("\tassign o_adc_complete_sample_index = adc_complete_sample_index_o; // 完成脉冲有效时导出本笔启动事务的稳定索引\n",
    "\tassign o_adc_complete_sample_index = adc_complete_sample_index_o; // 完成或作废脉冲有效时导出本笔启动事务的稳定索引，接收方须以事件限定取值\n"
    "\tassign o_adc_transaction_lost_event = adc_transaction_lost_event_o; // 导出超时作废事件，调度器与SSW据此按序号与代际释放owner\n")
rep("\tassign o_integration_protocol_error_sticky = integration_protocol_error_sticky_o; // 导出wrapper协议异常历史\n",
    "\tassign o_integration_protocol_error_sticky = integration_protocol_error_sticky_o; // 导出wrapper协议异常历史\n"
    "\tassign o_owner_lost_sticky = owner_lost_sticky_o; // 导出完成丢失作废历史，经control_top送SPI 0x0108 bit6\n")
rep("\tassign o_wrapper_fault_blocking = o_idac_fault_blocking || flag_precision_fault_blocking || flag_integration_blocking; // 汇总wrapper阻断资格\n",
    "\tassign o_wrapper_fault_blocking = o_idac_fault_blocking || flag_precision_fault_blocking || flag_integration_blocking || flag_owner_lost_fault_hold || flag_adc_busy_fault_hold; // 汇总wrapper阻断资格，lane 06/07保持期间同样禁止新事务\n")
rep("\tassign o_ami_fault_active = flag_test_identity_hold || flag_owner_protocol_fault_hold || flag_recovery_context_fault_hold || flag_precision_fault_active || flag_idac_fault_active; // 五路lane-active按位或，分别镜像各自保持电平\n",
    "\tassign o_ami_fault_active = flag_test_identity_hold || flag_owner_protocol_fault_hold || flag_recovery_context_fault_hold || flag_precision_fault_active || flag_idac_fault_active || flag_owner_lost_fault_hold || flag_adc_busy_fault_hold; // 七路lane-active按位或，分别镜像各自保持电平\n")
rep("\tassign o_ami_fault_valid = flag_ami_fault_dispatch_01 || flag_ami_fault_dispatch_02 || flag_ami_fault_dispatch_03 || flag_ami_fault_dispatch_04 || flag_ami_fault_dispatch_05; ",
    "\tassign o_ami_fault_valid = flag_ami_fault_dispatch_01 || flag_ami_fault_dispatch_02 || flag_ami_fault_dispatch_03 || flag_ami_fault_dispatch_04 || flag_ami_fault_dispatch_05 || flag_ami_fault_dispatch_06 || flag_ami_fault_dispatch_07; ")
rep("(flag_ami_fault_dispatch_05 ? 8'h05 : 8'h00)))); ",
    "(flag_ami_fault_dispatch_05 ? 8'h05 : (flag_ami_fault_dispatch_06 ? 8'h06 : (flag_ami_fault_dispatch_07 ? 8'h07 : 8'h00)))))); ")
rep("(flag_ami_fault_dispatch_05 ? flag_idac_fault_identity_valid : 1'b0)))); ",
    "(flag_ami_fault_dispatch_05 ? flag_idac_fault_identity_valid : (flag_ami_fault_dispatch_06 || flag_ami_fault_dispatch_07))))); ")
rep("(flag_ami_fault_dispatch_05 ? flag_idac_fault_frame_id : {C_FRAME_ID_WIDTH{1'b0}}))); ",
    "(flag_ami_fault_dispatch_05 ? flag_idac_fault_frame_id : ((flag_ami_fault_dispatch_06 || flag_ami_fault_dispatch_07) ? reg_adc_inflight_frame_id : {C_FRAME_ID_WIDTH{1'b0}})))); ")
rep("(flag_ami_fault_dispatch_05 ? flag_idac_fault_sample_index : {C_SAMPLE_INDEX_WIDTH{1'b0}}))); ",
    "(flag_ami_fault_dispatch_05 ? flag_idac_fault_sample_index : ((flag_ami_fault_dispatch_06 || flag_ami_fault_dispatch_07) ? reg_adc_inflight_sample_index : {C_SAMPLE_INDEX_WIDTH{1'b0}})))); ")
rep("(flag_ami_fault_dispatch_05 ? flag_idac_fault_color_ir : 1'b0))); ",
    "(flag_ami_fault_dispatch_05 ? flag_idac_fault_color_ir : ((flag_ami_fault_dispatch_06 || flag_ami_fault_dispatch_07) && reg_adc_inflight_color_ir)))); ")
rep("(flag_ami_fault_dispatch_05 ? flag_idac_fault_frame_type : 2'b00))); ",
    "(flag_ami_fault_dispatch_05 ? flag_idac_fault_frame_type : ((flag_ami_fault_dispatch_06 || flag_ami_fault_dispatch_07) ? reg_adc_inflight_frame_type : 2'b00)))); ")
rep("(flag_ami_fault_dispatch_05 ? flag_idac_fault_precision : 1'b0))); ",
    "(flag_ami_fault_dispatch_05 ? flag_idac_fault_precision : ((flag_ami_fault_dispatch_06 || flag_ami_fault_dispatch_07) && reg_adc_inflight_precision_mode)))); ")
rep("(flag_ami_fault_dispatch_05 ? flag_idac_fault_run_generation : {C_RUN_GENERATION_WIDTH{1'b0}}))); ",
    "(flag_ami_fault_dispatch_05 ? flag_idac_fault_run_generation : ((flag_ami_fault_dispatch_06 || flag_ami_fault_dispatch_07) ? i_run_generation : {C_RUN_GENERATION_WIDTH{1'b0}})))); ")

# ---------------- output processing: lost event, index, sticky, discard group ----------------
rep("\t\tend else if(flag_adc_completion_emit == 1'b1)begin\n\t\t\tadc_complete_sample_index_o <= reg_adc_inflight_sample_index; ",
    "\t\tend else if(flag_adc_completion_emit == 1'b1 || flag_owner_lost_fire == 1'b1)begin\n\t\t\tadc_complete_sample_index_o <= reg_adc_inflight_sample_index; ")
old_succ_hdr = "\t// 独立样本资格随结果fork原子锁存；invalid只禁止算法历史，不改写数值或身份。\n"
rep(old_succ_hdr,
    "\t// 超时作废通知只在作废判定拍置一拍，START拍不补发，绝不与完成通知同拍。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\tadc_transaction_lost_event_o <= 1'b0; // 复位不产生伪造作废通知\n"
    "\t\tend else if(i_start_ack_event == 1'b1)begin\n"
    "\t\t\tadc_transaction_lost_event_o <= 1'b0; // 新RUN边界不发布前一生命周期的作废\n"
    "\t\tend else begin\n"
    "\t\t\tadc_transaction_lost_event_o <= flag_owner_lost_fire; // 物理空闲且捕获链无完成时向调度器与SSW发布一次作废 @satisfies: AMI-39, LFA-04\n"
    "\t\tend\n"
    "\tend\n"
    "\n"
    "\t// 完成丢失历史位：新作废优先于同拍诊断清除；清除只在本地连续丢失阻断未保持或本RUN已由STOP结束且排空时生效，START不清。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\towner_lost_sticky_o <= 1'b0;   // 复位清除完成丢失历史\n"
    "\t\tend else if(flag_owner_lost_fire == 1'b1)begin\n"
    "\t\t\towner_lost_sticky_o <= 1'b1;   // 任一槽位超时作废都留下软件可读历史，同拍诊断清除不得吞掉 @satisfies: AMI-24\n"
    "\t\tend else if(i_diag_clear_event == 1'b1 && (flag_owner_lost_fault_hold == 1'b0 || flag_run_context_drained == 1'b1))begin\n"
    "\t\t\towner_lost_sticky_o <= 1'b0;   // 与集成sticky同一清除规则：无活跃连续丢失阻断或本RUN已结束排空时才允许撤销历史\n"
    "\t\tend\n"
    "\tend\n"
    "\n" + old_succ_hdr)

# discard group: event / reason / identity / sample_valid / frame / index / color / type / precision / generation
rep("\t\tend else if(flag_measurement_result_discard_fire == 1'b1)begin\n\t\t\tmeasurement_result_discard_event_o <= 1'b1; // 已同步在途正式结果与丢弃汇点确认本笔丢弃\n",
    "\t\tend else if(flag_measurement_result_discard_fire == 1'b1 || flag_owner_lost_fire == 1'b1)begin\n\t\t\tmeasurement_result_discard_event_o <= 1'b1; // 已同步在途正式结果与丢弃汇点确认本笔丢弃，或在途owner被超时作废\n")
discard_fields = [
    ("measurement_result_discard_reason_o <= flag_measurement_result_discard_reason; ",
     "measurement_result_discard_reason_o <= DISCARD_REASON_COMPLETION_LOST; // 作废专用原因码，与STOP/abort/系统故障三类区分"),
    ("measurement_result_discard_identity_valid_o <= 1'b1; ",
     "measurement_result_discard_identity_valid_o <= 1'b1; // 被作废owner的启动身份完整可信"),
    ("measurement_result_discard_sample_valid_o <= result_sample_valid_o; ",
     "measurement_result_discard_sample_valid_o <= 1'b0; // 作废事务从未产生样本，资格恒为0"),
    ("measurement_result_discard_frame_id_o <= result_frame_id_o; ",
     "measurement_result_discard_frame_id_o <= reg_adc_inflight_frame_id; // 取owner启动沿锁存的真实帧号"),
    ("measurement_result_discard_sample_index_o <= result_sample_index_o; ",
     "measurement_result_discard_sample_index_o <= reg_adc_inflight_sample_index; // 取owner启动沿锁存的全局序号"),
    ("measurement_result_discard_color_ir_o <= result_color_ir_o; ",
     "measurement_result_discard_color_ir_o <= reg_adc_inflight_color_ir; // 取owner启动沿锁存的颜色"),
    ("measurement_result_discard_frame_type_o <= result_frame_type_o; ",
     "measurement_result_discard_frame_type_o <= reg_adc_inflight_frame_type; // 作废类型可为NORMAL或校准，由该字段区分"),
    ("measurement_result_discard_precision_o <= result_precision_mode_o; ",
     "measurement_result_discard_precision_o <= reg_adc_inflight_precision_mode; // 取owner启动沿锁存的精度"),
    ("measurement_result_discard_run_generation_o <= dec_fork_measurement_run_generation; ",
     "measurement_result_discard_run_generation_o <= i_run_generation; // 作废只在本RUN内发生，代际取实时值"),
]
for anchor, lostline in discard_fields:
    i = t.index(anchor)
    assert t.count(anchor) == 1, anchor
    j = t.index('\n', i)
    var = anchor.split(' <=')[0]
    t = t[:j + 1] + "\t\tend else if(flag_owner_lost_fire == 1'b1)begin\n\t\t\t" + lostline + "\n" + t[j + 1:]

# ---------------- main processing ----------------
# AMI in-flight owner release by void
rep("\t\tend else if(flag_adc_completion_emit == 1'b1)begin\n\t\t\tflag_adc_transaction_inflight <= 1'b0; // 成功或失败完成旁带发布后才释放物理ADC owner\n",
    "\t\tend else if(flag_adc_completion_emit == 1'b1)begin\n\t\t\tflag_adc_transaction_inflight <= 1'b0; // 成功或失败完成旁带发布后才释放物理ADC owner\n"
    "\t\tend else if(flag_owner_lost_fire == 1'b1)begin\n\t\t\tflag_adc_transaction_inflight <= 1'b0; // 超时作废释放owner，不产生RAW、结果或success；作废不清捕获模块等待权，旧DONE随后按无owner捕获拒绝 @satisfies: AMI-40\n")
rep("\t\tend else if(o_transaction_start_fire == 1'b1 || flag_adc_completion_emit == 1'b1)begin\n\t\t\tflag_adc_transaction_abort <= 1'b0; ",
    "\t\tend else if(o_transaction_start_fire == 1'b1 || flag_adc_completion_emit == 1'b1 || flag_owner_lost_fire == 1'b1)begin\n\t\t\tflag_adc_transaction_abort <= 1'b0; ")

# lanes 01/02/03: L-5 drained clear after set branch
rep("\t\t\tflag_test_identity_hold <= 1'b1;    // 错配进入原matcher后保留真实完成等待恢复\n\t\tend\n",
    "\t\t\tflag_test_identity_hold <= 1'b1;    // 错配进入原matcher后保留真实完成等待恢复\n"
    "\t\tend else if(flag_run_context_drained == 1'b1)begin\n"
    "\t\t\tflag_test_identity_hold <= 1'b0;    // STOP结束本RUN且全链排空后测试身份不再有可恢复的owner，lane 01随RUN结束落下；L-5 @satisfies: AMI-24\n"
    "\t\tend\n")
rep("\t\t\tflag_owner_protocol_fault_hold <= 1'b1; // 四类协议错误任一到达即置位并保持\n\t\tend\n",
    "\t\t\tflag_owner_protocol_fault_hold <= 1'b1; // 四类协议错误任一到达即置位并保持\n"
    "\t\tend else if(flag_run_context_drained == 1'b1)begin\n"
    "\t\t\tflag_owner_protocol_fault_hold <= 1'b0; // 保持到本RUN结束：STOP确认且AMI全链排空即无残留阻断原因，lane 02落下使episode可关闭；置位优先于本清零；L-5 @satisfies: AMI-24\n"
    "\t\tend\n")
rep("\t\t\tflag_recovery_context_fault_hold <= 1'b1; // 无法证明可用原owner执行失败释放\n\t\tend\n",
    "\t\t\tflag_recovery_context_fault_hold <= 1'b1; // 无法证明可用原owner执行失败释放\n"
    "\t\tend else if(flag_run_context_drained == 1'b1)begin\n"
    "\t\t\tflag_recovery_context_fault_hold <= 1'b0; // STOP结束本RUN且排空后无可恢复的原owner，lane 03随之落下；L-5 @satisfies: AMI-24\n"
    "\t\tend\n")

# calibration request inflight: merged withdraw
rep("\t\tend else if(flag_amb_sample_accepted == 1'b1 || flag_dcs_sample_accepted == 1'b1 || i_cal_owner_deadline_event == 1'b1)begin\n",
    "\t\tend else if(flag_amb_sample_accepted == 1'b1 || flag_dcs_sample_accepted == 1'b1 || flag_calibration_request_withdraw == 1'b1)begin\n")

# new main-area always blocks, inserted before the pending_01 block
anchor = "\t// cause 8'h01待分发标记，受保护测试身份注入被唯一owner接纳时置位，本拍出槽后清除。\n"
new_main = (
    "\t// owner年龄从start fire起计数，饱和于ADC_BUSY_FAULT_CYCLES；完成或作废后保持到下一笔start，不参与其它判定。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\tcnt_owner_age <= 16'd0;         // 复位时不存在在途owner年龄\n"
    "\t\tend else if(o_transaction_start_fire == 1'b1)begin\n"
    "\t\t\tcnt_owner_age <= 16'd0;         // 新owner启动沿重新计龄\n"
    "\t\tend else if(flag_adc_transaction_inflight == 1'b1 && cnt_owner_age < ADC_BUSY_FAULT_CYCLES)begin\n"
    "\t\t\tcnt_owner_age <= cnt_owner_age + 16'd1; // 在途期间逐拍累加，STOP、abort与帧停止都不暂停计时\n"
    "\t\tend\n"
    "\tend\n"
    "\n"
    "\t// RED槽位连续作废计数：只有RED owner自身的真实完成或START清零，达到k后饱和。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\tcnt_lost_red <= 4'd0;           // 复位无RED作废历史\n"
    "\t\tend else if(i_start_ack_event == 1'b1)begin\n"
    "\t\t\tcnt_lost_red <= 4'd0;           // 新RUN不继承RED连续作废\n"
    "\t\tend else if(flag_owner_alive_completion == 1'b1 && flag_owner_slot_red == 1'b1)begin\n"
    "\t\t\tcnt_lost_red <= 4'd0;           // RED真实完成证明该槽位仍有应答\n"
    "\t\tend else if(flag_owner_lost_fire == 1'b1 && flag_owner_slot_red == 1'b1 && cnt_lost_red < C_ADC_COMPLETION_LOST_LIMIT)begin\n"
    "\t\t\tcnt_lost_red <= cnt_lost_red + 4'd1; // RED owner被作废一次\n"
    "\t\tend\n"
    "\tend\n"
    "\n"
    "\t// IR槽位连续作废计数：与RED独立，只被IR真实完成或START清零。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\tcnt_lost_ir <= 4'd0;            // 复位无IR作废历史\n"
    "\t\tend else if(i_start_ack_event == 1'b1)begin\n"
    "\t\t\tcnt_lost_ir <= 4'd0;            // 新RUN不继承IR连续作废\n"
    "\t\tend else if(flag_owner_alive_completion == 1'b1 && flag_owner_slot_ir == 1'b1)begin\n"
    "\t\t\tcnt_lost_ir <= 4'd0;            // IR真实完成清零其连续作废\n"
    "\t\tend else if(flag_owner_lost_fire == 1'b1 && flag_owner_slot_ir == 1'b1 && cnt_lost_ir < C_ADC_COMPLETION_LOST_LIMIT)begin\n"
    "\t\t\tcnt_lost_ir <= cnt_lost_ir + 4'd1; // IR owner被作废一次\n"
    "\t\tend\n"
    "\tend\n"
    "\n"
    "\t// 校准槽位连续作废计数：SID-05截止撤销不经过owner，不计入；只统计真正的超时作废。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\tcnt_lost_cal <= 4'd0;           // 复位无校准作废历史\n"
    "\t\tend else if(i_start_ack_event == 1'b1)begin\n"
    "\t\t\tcnt_lost_cal <= 4'd0;           // 新RUN不继承校准连续作废\n"
    "\t\tend else if(flag_owner_alive_completion == 1'b1 && flag_owner_slot_cal == 1'b1)begin\n"
    "\t\t\tcnt_lost_cal <= 4'd0;           // 校准真实完成清零其连续作废\n"
    "\t\tend else if(flag_owner_lost_fire == 1'b1 && flag_owner_slot_cal == 1'b1 && cnt_lost_cal < C_ADC_COMPLETION_LOST_LIMIT)begin\n"
    "\t\t\tcnt_lost_cal <= cnt_lost_cal + 4'd1; // 校准owner被作废一次\n"
    "\t\tend\n"
    "\tend\n"
    "\n"
    "\t// cause 8'h06保持电平：某槽位连续作废达到k即置位；abort、START清零，或本RUN已由STOP结束且排空时落下；置位优先于后者。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\tflag_owner_lost_fault_hold <= 1'b0; // 复位解除连续丢失阻断\n"
    "\t\tend else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin\n"
    "\t\t\tflag_owner_lost_fault_hold <= 1'b0; // 新RUN或supervisor abort结束本episode的连续丢失阻断\n"
    "\t\tend else if(flag_owner_lost_limit_reached == 1'b1)begin\n"
    "\t\t\tflag_owner_lost_fault_hold <= 1'b1; // T-dead：同槽位连续k次作废，经supervisor升级为系统故障并STOP @satisfies: SUP-08\n"
    "\t\tend else if(flag_run_context_drained == 1'b1)begin\n"
    "\t\t\tflag_owner_lost_fault_hold <= 1'b0; // 本RUN已结束且排空，连续丢失不再有在途事务\n"
    "\t\tend\n"
    "\tend\n"
    "\n"
    "\t// cause 8'h07保持电平：owner年龄到9000拍物理ADC仍忙即置位，不释放owner；清零规则与lane 06相同。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\tflag_adc_busy_fault_hold <= 1'b0; // 复位解除ADC长期忙阻断\n"
    "\t\tend else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin\n"
    "\t\t\tflag_adc_busy_fault_hold <= 1'b0; // 新RUN或abort后改由看门狗监视排空中的ADC忙\n"
    "\t\tend else if(flag_adc_busy_fault_fire == 1'b1)begin\n"
    "\t\t\tflag_adc_busy_fault_hold <= 1'b1; // RUN中ADC一直不回空闲时不再静默停滞，报故障并STOP\n"
    "\t\tend else if(flag_run_context_drained == 1'b1)begin\n"
    "\t\t\tflag_adc_busy_fault_hold <= 1'b0; // 本RUN结束且排空即无残留ADC忙原因\n"
    "\t\tend\n"
    "\tend\n"
    "\n"
    "\t// cause 8'h06待分发标记，连续丢失达到k的作废拍置位，出槽后清除。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\tflag_ami_fault_pending_06 <= 1'b0; // 复位撤销连续丢失待分发记录\n"
    "\t\tend else if(flag_owner_lost_limit_reached == 1'b1)begin\n"
    "\t\t\tflag_ami_fault_pending_06 <= 1'b1; // 达到k的作废拍排队一条连续丢失故障记录\n"
    "\t\tend else if(flag_ami_fault_dispatch_06 == 1'b1)begin\n"
    "\t\t\tflag_ami_fault_pending_06 <= 1'b0; // 连续丢失记录已出槽\n"
    "\t\tend\n"
    "\tend\n"
    "\n"
    "\t// cause 8'h07待分发标记，ADC长期忙判定拍置位，出槽后清除。\n"
    "\talways@(posedge i_clk or negedge i_rstn)begin\n"
    "\t\tif(i_rstn == 1'b0)begin\n"
    "\t\t\tflag_ami_fault_pending_07 <= 1'b0; // 复位撤销ADC长期忙待分发记录\n"
    "\t\tend else if(flag_adc_busy_fault_fire == 1'b1)begin\n"
    "\t\t\tflag_ami_fault_pending_07 <= 1'b1; // 每个owner只在年龄跨入饱和值时排队一次\n"
    "\t\tend else if(flag_ami_fault_dispatch_07 == 1'b1)begin\n"
    "\t\t\tflag_ami_fault_pending_07 <= 1'b0; // ADC长期忙记录已出槽\n"
    "\t\tend\n"
    "\tend\n"
    "\n")
rep(anchor, new_main + anchor)

# ---------------- PWI instance: withdraw passthrough ----------------
rep("\t\t.i_dcs_sample_accepted_event(flag_dcs_sample_accepted), // 输入 i_dcs_sample_accepted_event 用 flag_dcs_sample_accepted\n",
    "\t\t.i_dcs_sample_accepted_event(flag_dcs_sample_accepted), // 输入 i_dcs_sample_accepted_event 用 flag_dcs_sample_accepted\n"
    "\t\t.i_calibration_request_withdraw_event(flag_recheck_request_withdraw), // 周期重检在途请求被截止撤销或校准作废时释放重检调度器内层在途；F-020\n")

open(p, 'w', encoding='utf-8', newline='\n').write(t)
print('AMI patched')
