`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026-08-15
// Design Name: 	PPG 400 Hz Frame Calibration Scheduler
// Module Name: 	ppg_400hz_frame_calibration_scheduler
// Description: 	V1.3 scheduler with independent waveform and ADC-owner contexts.
// Dependencies:
// AMI V1.3 and SSW V1.3.1 interface contracts.
// AMI V1.3、SSW V1.3.1接口合同
// Simulations:		ppg_400hz_frame_calibration_scheduler
//
// Referrences:		PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md
//
//
// Version:			V1.8
// Revision Date:	2026-09-18
// History:
//    Time			   Version	   Revised by			Contents
// 2026-08-13           V1.0       Erie        Create file.
// 2026-08-14           V1.2       Erie        Align context handoff and Q3 phases.
// 2026-08-15           V1.3       Erie        Split waveform and ADC-owner scheduling.
// 2026-08-22           V1.3.1     Erie        Fix i_leddac_r_code/i_leddac_ir_code/o_waveform_leddac_code_snapshot and the internal frame-state LEDDAC slots to a fixed 8-bit width per PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md; they were incorrectly tied to C_IDAC_CODE_WIDTH, which the SSW contract scopes to AMB/DC codes only.
// 2026-08-22           V1.4       Erie        Add i_run_generation with atomic ADC-owner tagging and stale-generation completion rejection, and add the registered o_scheduler_fault_* record group for the system fault/abort supervisor, per PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md section 15.1 and PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md.
// 2026-08-22           V1.5     Erie        Comment-and-structure cleanup only: removed a provably-dead if(1'b0) calibration-rollover branch superseded by the state_rollover_next overlay, relocated flag_calibration_rollover's assign and added a dedicated region banner for state_rollover_next to satisfy the strict deliverable gate's region-ownership rule, and added the missing same-line comments the gate flagged. No functional behavior changed; gate now reports 0 errors.
// 2026-08-23           V1.6     Erie        Fix a real STOP-drain deadlock found via ppg_control_top's first system-level smoke simulation: the combined STOP/abort/run_enable==0 branch forced B_FRAME_ACTIVE (and macro_tick advancement) to freeze on the very same cycle a plain STOP arrived, even while SSW already held an accepted-but-not-yet-committed RED/IR wave context. SSW's own flag_red_context_valid/flag_ir_context_valid only clear on i_control_abort_event or on the tick reaching the wave window's natural release point (PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md); they never watch stop_ack. With tick frozen mid-window, SSW's context could never release, o_analog_safe/o_sar_timing_idle never asserted, and o_scheduler_idle never reached 1, deadlocking STOPPING forever. Fix: only i_control_abort_event now forces B_FRAME_ACTIVE/B_FRAME_MODE to 0 immediately; a plain STOP (stop_ack or run_enable==0 without abort) leaves B_FRAME_ACTIVE untouched so the existing, already-correct natural tick-advance/MACRO_LAST_TICK end-of-frame path lets any already-open RED/IR/calibration window run out and release on its own, matching PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md section 16.3's "已接管但未提交owner的模拟预建立安全收尾" wording. CONTEXT_SEEN/WAVE_PENDING/CAL_REQ_ACTIVE are still cleared immediately in both cases, so no new context handoff, owner commit or IDAC boundary can occur during the extended drain; only the passive tick-driven release path is left open.
// 2026-08-24           V1.7     Erie        Implement the receiver-side calibration eligibility check that section 9.1 has always specified but that was never actually wired: i_run_profile was a declared-but-unreferenced dead input, and i_input_source was only latched into B_FRAME_INPUT_SOURCE for SSW waveform tagging -- neither ever gated calibration_sample_ready_o or flag_calibration_request_valid, so the only real defense against an illegal (CHARACTERIZATION, external-current, or otherwise non-NORMAL-PPG-PHOTODIODE) calibration request was AMI's own source-side gate, not the documented AMI+Scheduler two-sided check. Confirmed via tb_ppg_control_top.v's TOP-20 evidence (SMOKE-21/22) and re-verified directly against section 9.1's frozen calibration_request_qualified formula (a genuine MUST, not descriptive text) before touching this file, per PPG_CONTRACT_CLOSURE_MATRIX.md discipline. Also found while implementing: calibration_sample_ready_o previously never referenced flag_calibration_request_valid at all, meaning even the SAR9-precision half of the eligibility check that already existed only triggered a post-hoc B_PROTOCOL_ERROR flag (line ~621's i_calibration_sample_valid&&!flag_calibration_request_valid branch) without actually preventing calibration_sample_ready_o/flag_calibration_request_fire from firing and letting the illegal request establish a waveform context, ADC owner, or pending state -- contradicting section 9.1's "只有calibration_request_qualified=1...ready才允许为1" requirement. Fix: added localparams RUN_PROFILE_NORMAL/INPUT_SOURCE_PHOTODIODE, widened flag_calibration_request_valid to also require i_run_profile==RUN_PROFILE_NORMAL && i_input_source==INPUT_SOURCE_PHOTODIODE, and ANDed flag_calibration_request_valid directly into calibration_sample_ready_o so an illegal request is blocked at the ready signal itself (not just flagged afterward); the existing B_PROTOCOL_ERROR trigger at line ~621 already keyed off the same flag and needed no further change. This closes the implementation half of the closure matrix's P07-adjacent scheduler-side gap; tb_ppg_400hz_frame_calibration_scheduler.v FSC-58/59 (new) are the first real test coverage for this path -- the previously-documented "FSC-17" case referenced by the contract's own self-check table never actually existed in that TB (its real FSC-17 tests an unrelated RED-only owner-commit count), so this was untested as well as unimplemented before this fix.
// 2026-09-18           V1.8     Erie        Fix a real permanent deadlock discovered while investigating workline-D's SID-05 pending item (C25 contract section 9.4.1, "each calibration ADC owner commits no later than local tick 248"): flag_cal_owner_deadline already correctly suppressed the candidate window and set B_OWNER_DEADLINE_TIMEOUT when a calibration owner missed its tick-248 deadline (this half was already correct, confirmed by real xsim), but that suppression was never reported back to AMI as a distinguishable event. AMI's flag_calibration_request_inflight (ppg_adc_measurement_idac_integration.v) only ever clears on a genuine consumed search result (flag_amb_sample_accepted/flag_dcs_sample_accepted) or on STOP/abort -- a deadline-suppressed request produces neither, since by construction no ADC owner and no transaction ever existed for it. Confirmed via a real iverilog A/B trace (not just static reading, per this project's standing methodology): forcing i_adc_physical_idle=0 across a genuine mid-search DC_R candidate's tick-248 deadline correctly clears B_CAL_WAVE_PENDING at tick 248 (flag_cal_owner_deadline fires exactly once, as designed), but AMI's flag_calibration_request_inflight then stays 1 forever, so AMI never re-arms calibration_sample_valid_o, B_CAL_REQ_PENDING never becomes 1 again at any future tick-624 subframe boundary, and B_CAL_CONTEXT_SEEN permanently locks at 1 -- the whole calibration search (AMB or DCS_CAL, whichever was in progress) stalls forever and never recovers on its own, confirmed by a real trace showing 12/12 subsequent candidates all fail with "real Q3 window never opened". This is a genuine functional gap, not merely a missing test: any real hardware condition that legitimately delays the physical ADC past the 248-tick deadline (not just this synthetic test) would permanently strand the calibration search, since the contract's own graceful-degradation intent (soft, non-blocking B_OWNER_DEADLINE_TIMEOUT diagnostic, no fault escalation, per the existing LFA-09/OIB-02 precedent for the RED/IR owner-deadline siblings) is defeated by AMI silently never retrying. Fix: added a new single-cycle event output o_cal_owner_deadline_event, wired directly to the pre-existing, already self-clearing flag_cal_owner_deadline combinational pulse (confirmed self-clearing after exactly one cycle by the same trace, since B_CAL_WAVE_PENDING -- one of its own AND-terms -- clears on the same edge) -- no new state, no new timing path, purely an existing internal pulse exposed as a port so AMI can react to it. AMI V1.15 (see that file's own changelog) consumes this new event as an additional flag_calibration_request_inflight clear condition, letting it re-arm calibration_sample_valid_o for a fresh retry of the same still-wanted candidate on the very next opportunity. This fix only touches the calibration (AMB/DCS_CAL) owner-deadline path that AMI's calibration_sample_valid_o request/accept handshake depends on; the sibling RED/IR NORMAL-measurement owner-deadline timeouts (flag_red_owner_deadline/flag_ir_owner_deadline, LFA-09/OIB-02) use an entirely different request path (ppg_normal_transaction_fork.v, not AMI's calibration arbitration) and were not touched or re-investigated -- out of scope for this fix.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026-08-15
// 设计名称: 		PPG 400 Hz Frame Calibration Scheduler
// 模块名称: 		ppg_400hz_frame_calibration_scheduler
// 模块说明:		V1.3 scheduler with independent waveform and ADC-owner contexts.
// 依赖文件:
// AMI V1.3 and SSW V1.3.1 interface contracts.
// AMI V1.3、SSW V1.3.1接口合同
// 仿真工程: 		ppg_400hz_frame_calibration_scheduler
//
// 参考资料:		PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md
//
//
// 当前版本:		V1.7
// 修订日期:		2026-08-24
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026-09-18           V1.8     Erie        修复调查工作线D待查项SID-05（合同9.4.1节"每个校准ADC owner不得晚于本地tick 248提交"）时发现的一个真实永久死锁：flag_cal_owner_deadline在校准owner错过tick-248截止时本来就正确抑制候选窗口并置位B_OWNER_DEADLINE_TIMEOUT（这一半已确认正确，真实xsim验证过），但这次抑制从未以可区分的事件形式回报给AMI。AMI的flag_calibration_request_inflight（ppg_adc_measurement_idac_integration.v）只在真实消费到搜索结果（flag_amb_sample_accepted/flag_dcs_sample_accepted）或STOP/abort时才清零——被抑制的请求两者都不会产生，因为按设计它从未真正建立过ADC owner或事务。真实iverilog A/B追查确认（不是仅凭静态阅读，遵循本项目一贯方法论）：对一笔真实进行中的DC_R候选，在其tick-248截止跨越期间强制i_adc_physical_idle=0，能正确在tick 248让B_CAL_WAVE_PENDING清零（flag_cal_owner_deadline按设计只脉冲一拍），但AMI的flag_calibration_request_inflight之后永远保持1，导致AMI再也不会重新拉高calibration_sample_valid_o，B_CAL_REQ_PENDING在之后任何一次tick-624子帧边界都不会再变成1，B_CAL_CONTEXT_SEEN永久锁定在1——整个校准搜索（无论当时是AMB还是DCS_CAL）从此卡死不再自行恢复，真实trace显示后续12/12个候选全部"real Q3 window never opened"。这是真实功能性缺口，不只是缺测试：任何让物理ADC真实晚于248拍变idle的硬件场景（不只是这次的合成测试）都会永久搁浅校准搜索，因为合同本身"优雅降级"的设计意图（软性、非阻断的B_OWNER_DEADLINE_TIMEOUT诊断，不升级故障，与既有RED/IR owner-deadline姊妹机制LFA-09/OIB-02同一惯例）被AMI静默不重试这一点架空了。修复：新增一个单周期事件输出o_cal_owner_deadline_event，直接接到原本就存在、本来就自清零的flag_cal_owner_deadline组合脉冲上（同一份trace确认它恰好一拍后自动清零，因为B_CAL_WAVE_PENDING——它自己的与项之一——在同一拍跟着清零）——不新增状态，不新增时序路径，只是把一个已有的内部脉冲暴露成端口供AMI响应。AMI V1.15（见该文件自己的修订记录）把这个新事件接成flag_calibration_request_inflight的额外清零条件，让它能为同一个仍在等待的候选立即重新拉高calibration_sample_valid_o发起重试。本次修复只涉及AMI calibration_sample_valid_o请求/接受握手依赖的校准（AMB/DCS_CAL）owner截止通路；姊妹机制RED/IR NORMAL测量owner截止超时（flag_red_owner_deadline/flag_ir_owner_deadline，LFA-09/OIB-02）走的是完全不同的请求通路（ppg_normal_transaction_fork.v，非AMI的校准仲裁），本次未触碰也未重新调查——不在本次修复范围内。
// 2026-08-13           V1.0       Erie        创建文件
// 2026-08-14           V1.2       Erie        对齐上下文接管点和Q3相位
// 2026-08-15           V1.3       Erie        拆分波形上下文和ADC owner调度
// 2026-08-22           V1.3.1     Erie        按PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md修正i_leddac_r_code/i_leddac_ir_code/o_waveform_leddac_code_snapshot及内部帧状态LEDDAC槽位为固定8-bit；此前错误绑定C_IDAC_CODE_WIDTH，而该参数在SSW合同中明确限定只用于AMB/DC码。
// 2026-08-22           V1.4       Erie        按合同15.1节新增i_run_generation，对ADC owner创建原子锁存并在DONE匹配时校验代际；新增注册式o_scheduler_fault_*故障记录组供system fault/abort supervisor观测。
// 2026-08-22           V1.5     Erie        仅注释与结构整理：删除已被state_rollover_next覆盖逻辑取代的if(1'b0)校准滚动死分支，将flag_calibration_rollover的assign移入正确区域并为state_rollover_next补建专用区域banner以满足严格门禁的区域归属规则，并补齐门禁标记缺失的同行注释。不改变任何功能行为，门禁现已0错误。
// 2026-08-23           V1.6     Erie        修复ppg_control_top第一次整机烟雾仿真发现的真实STOP排空死锁：原来STOP/abort/run_enable==0合并成一个分支，纯STOP到达的同一拍就强制冻结B_FRAME_ACTIVE（连带冻结macro_tick推进），即使SSW当时已经接管了一个尚未提交owner的RED/IR波形上下文。SSW自己的flag_red_context_valid/flag_ir_context_valid（见PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md）只在i_control_abort_event或tick自然走到窗口末尾两条路径释放，从不监听stop_ack；tick一旦冻结在窗口中间，SSW上下文永远释放不了，o_analog_safe/o_sar_timing_idle永远拉不高，o_scheduler_idle永远是0，STOPPING生命周期死锁。修复：只有i_control_abort_event才立即强制B_FRAME_ACTIVE/B_FRAME_MODE归零；纯STOP（stop_ack或run_enable==0但没有abort）不再动B_FRAME_ACTIVE，让下方本来就正确的tick自然推进/MACRO_LAST_TICK宏帧末拍收尾路径把已经打开的RED/IR/校准窗口自然走完再释放，对应合同16.3节"已接管但未提交owner的模拟预建立安全收尾"原文。两种情况下CONTEXT_SEEN/WAVE_PENDING/CAL_REQ_ACTIVE仍然立即清除，排空延长期间不会有任何新波形接管、owner提交或IDAC边界，只留下这一条被动的tick驱动释放通路。
// 2026-08-24           V1.7     Erie        补上合同9.1节一直写着、但从未真正接过线的调度器接收端校准资格复核：i_run_profile此前是声明后从未被引用的死端口，i_input_source只被锁存进B_FRAME_INPUT_SOURCE转发给SSW波形槽做标记——两者都从未参与calibration_sample_ready_o或flag_calibration_request_valid的判断，导致对非法（CHARACTERIZATION、外部电流或其他非NORMAL_PPG+PHOTODIODE）校准请求的唯一真实防线是AMI单边的源端门控，不是合同描述的AMI+Scheduler双边检查。动手前先按PPG_CONTRACT_CLOSURE_MATRIX.md的规矩核对了tb_ppg_control_top.v TOP-20的证据（SMOKE-21/22）并重新对照合同9.1节冻结的calibration_request_qualified公式确认这条确实是MUST，不是描述性文字。修复过程中还发现：calibration_sample_ready_o原来根本没有引用过flag_calibration_request_valid，也就是说即使原来就存在的SAR9精度那一项检查，也只是在事后触发一次B_PROTOCOL_ERROR（约621行的i_calibration_sample_valid&&!flag_calibration_request_valid分支），并没有真正阻止calibration_sample_ready_o/flag_calibration_request_fire让非法请求建立波形上下文、ADC owner或pending状态——与合同9.1节"只有calibration_request_qualified=1...ready才允许为1"的要求矛盾。修复：新增RUN_PROFILE_NORMAL/INPUT_SOURCE_PHOTODIODE两个localparam，把flag_calibration_request_valid扩展成同时要求i_run_profile==RUN_PROFILE_NORMAL && i_input_source==INPUT_SOURCE_PHOTODIODE，并把flag_calibration_request_valid直接与到calibration_sample_ready_o里，让非法请求在ready这一层就被挡住，不是事后才标记；原有621行附近的B_PROTOCOL_ERROR触发本来就是靠同一个flag，不需要再改。这条关闭了closure matrix里P07相邻的scheduler端实现缺口；tb_ppg_400hz_frame_calibration_scheduler.v新增的FSC-58/59是这条路径第一份真实测试覆盖——合同自检表里此前写着的"FSC-17"其实从未在这份TB里真正存在过（真实的FSC-17测的是纯RED场景一个无关的owner commit计数），所以这条不仅没实现，之前也从未被测过。
module ppg_400hz_frame_calibration_scheduler
#(
	parameter C_FRAME_ID_WIDTH = 16,            // 400 Hz物理帧号宽度
	parameter C_SAMPLE_INDEX_WIDTH = 16,        // ADC事务全局序号宽度
	parameter C_IDAC_CODE_WIDTH = 8,            // committed IDAC码宽度
	parameter C_CODE_EPOCH_WIDTH = 4,           // IDAC码版本宽度
	parameter C_RUN_GENERATION_WIDTH = 8,       // manager唯一生产、经ACTIVE wrapper与Top透明扇出的RUN代际宽度
	parameter C_MACRO_TICK_WIDTH = 13,          // 400 Hz宏帧相位宽度
	parameter C_CAL_TICK_WIDTH = 10,            // 3200 Hz校准局部相位宽度
	parameter C_MACRO_FRAME_TICKS = 5000,       // 每个400 Hz宏帧的2 MHz周期数
	parameter C_CAL_SUBFRAME_TICKS = 625,       // 每个SAR9校准子周期的2 MHz周期数
	parameter C_NORMAL_RED_OWNER_DEADLINE = 283, // NORMAL RED owner截止相位
	parameter C_NORMAL_IR_OWNER_DEADLINE = 443, // 为IR预建立留出的ADC owner最晚提交相位
	parameter C_CAL_OWNER_DEADLINE = 248        // 校准owner截止相位
)
(
	//--------------全局时钟与复位--------------//
	input i_clk,                                // 2 MHz数字主时钟
	input i_rstn,                               // 低有效异步复位

	//---------------生命周期控制---------------//
	input i_active_config_valid,                // ACTIVE配置整体合法
	input i_run_enable,                         // 当前处于RUN生命周期
	input i_allow_new_transaction,              // 配置管理器允许新ADC事务
	input i_start_ack_event,                    // 新RUN开始单拍
	input i_stop_ack_event,                     // STOP进入排空单拍
	input i_control_abort_event,                // abort撤销控制单拍
	input i_diag_clear_event,                   // 清除历史诊断单拍
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // manager经ACTIVE wrapper与Top扇出的当前RUN代际，陈旧代际不得匹配、释放或重绑owner

	//--------------配置与AMI状态---------------//
	input i_run_profile,                        // NORMAL或CHARACTERIZATION
	input i_input_source,                       // 光电二极管或固定电流来源
	input [1:0]i_optical_mode,                  // 双光、单光或安全关闭
	input i_active_precision_mode,              // 当前committed精度
	input i_normal_measurement_eligible,        // AMI允许NORMAL测量
	input i_switch_hold_new_transaction,        // 精度切换期间暂停新事务
	input i_ami_fault_blocking,                 // AMI活动阻断故障
	input i_ssw_fault_blocking,                 // SSW波形保持或模拟时序路径报告的阻断故障
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code,  // 当前AMB committed码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code, // 当前RED DC committed码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code, // 当前IR DC committed码
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // AMB码版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dcs_r_code_epoch, // RED DC码版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dcs_ir_code_epoch, // IR DC码版本
	input [7:0]i_leddac_r_code,                 // 已提交RED LEDDAC码，固定8-bit物理LED驱动码，与AMB/DC的C_IDAC_CODE_WIDTH无关
	input [7:0]i_leddac_ir_code,                // 固定给IR光学时隙的已提交LED RDAC数字码，固定8-bit物理LED驱动码

	//---------------AMI校准请求----------------//
	input i_calibration_sample_valid,           // 保持型SAR9校准请求
	output o_calibration_sample_ready,          // 调度器接受请求握手
	input [1:0]i_calibration_frame_type,        // AMB_CAL或DCS_CAL
	input i_calibration_color_ir,               // DCS颜色，AMB固定为0
	input i_calibration_precision_mode,         // 校准精度，必须为SAR9
	input [1:0]i_calibration_request_reason,    // 启动搜索或周期重检

	//------------SSW模拟波形上下文-------------//
	output o_waveform_context_valid,            // 保持型模拟波形上下文有效
	input i_waveform_context_ready,             // SSW固定相位接管ready
	output o_waveform_precision_mode,           // 波形精度快照
	output [C_FRAME_ID_WIDTH - 1:0]o_waveform_frame_id, // 波形物理帧号
	output o_waveform_color_ir,                 // 波形颜色快照
	output [1:0]o_waveform_frame_type,          // 波形事务类型
	output [C_IDAC_CODE_WIDTH - 1:0]o_waveform_amb_code_snapshot, // 波形AMB码快照
	output [C_IDAC_CODE_WIDTH - 1:0]o_waveform_dc_code_snapshot, // 波形颜色DC码快照
	output [C_CODE_EPOCH_WIDTH - 1:0]o_waveform_amb_code_epoch, // 波形AMB版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_waveform_dc_code_epoch, // 波形颜色DC版本
	output o_waveform_input_source,             // 波形输入来源快照
	output [1:0]o_waveform_optical_mode,        // 波形光学模式快照
	output [7:0]o_waveform_leddac_code_snapshot, // 波形LEDDAC快照，固定8-bit物理LED驱动码，与AMB/DC的C_IDAC_CODE_WIDTH无关

	//-------------AMI ADC结果事务--------------//

	//TRANSACTION_START接口
	output o_transaction_start_valid,           // 保持型ADC owner事务valid
	input i_transaction_start_ready,            // AMI可接收事务
	input i_transaction_start_fire,             // AMI返回的fire一致性旁带
	output o_transaction_precision_mode,        // ADC事务精度快照
	output [C_FRAME_ID_WIDTH - 1:0]o_transaction_frame_id, // ADC事务帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_transaction_sample_index, // ADC事务序号
	output o_transaction_color_ir,              // ADC事务颜色
	output [1:0]o_transaction_frame_type,       // ADC事务类型
	output [C_IDAC_CODE_WIDTH - 1:0]o_transaction_amb_code_snapshot, // ADC事务AMB码
	output [C_IDAC_CODE_WIDTH - 1:0]o_transaction_dc_code_snapshot, // ADC事务DC码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_transaction_amb_code_epoch, // ADC事务AMB版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_transaction_dc_code_epoch, // 与本ADC颜色槽DC码绑定的epoch快照

	//-----------SSW owner与物理完成------------//
	input i_adc_owner_ready,                    // SSW确认最早pending owner可提交
	output o_adc_owner_commit_event,            // 与AMI fire同拍的owner提交
	output o_adc_owner_precision_mode,          // owner精度身份
	output [C_FRAME_ID_WIDTH - 1:0]o_adc_owner_frame_id, // owner帧号身份
	output o_adc_owner_color_ir,                // owner颜色身份
	output [1:0]o_adc_owner_frame_type,         // 供SSW物理owner锁存的即将占用事务类别
	output [C_IDAC_CODE_WIDTH - 1:0]o_adc_owner_amb_code_snapshot, // owner AMB码
	output [C_IDAC_CODE_WIDTH - 1:0]o_adc_owner_dc_code_snapshot, // owner DC码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_adc_owner_amb_code_epoch, // owner AMB版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_adc_owner_dc_code_epoch, // owner DC版本
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_adc_owner_sample_index, // owner正式序号
	input i_adc_transaction_complete_event,     // 真实ADC完成单拍
	input i_adc_transaction_success,            // 完成结果处理资格
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_adc_complete_sample_index, // 完成身份序号
	input i_owner_q3_window_closed,             // 在途owner自身选定Q3窗口已关闭，早于此的DONE不得构成成功完成
	input i_adc_idle,                           // 物理ADC和DONE已排空
	input i_analog_safe,                        // 模拟输出允许停止或切换
	input i_sar_timing_idle,                    // 无在途SAR模拟相位

	//--------------时间与完成事件--------------//
	output o_macro_frame_start_event,           // 400 Hz宏帧起点单拍
	output o_macro_frame_safe_boundary,         // 下一宏帧准备前安全边界
	output o_idac_code_safe_boundary,           // IDAC唯一提交边界
	output o_startup_idac_safe_boundary,        // START后一次性IDAC边界
	output [C_FRAME_ID_WIDTH - 1:0]o_safe_frame_id, // 下一400 Hz帧编号
	output [C_MACRO_TICK_WIDTH - 1:0]o_macro_tick, // 当前宏帧相位
	output [2:0]o_calibration_subframe_index,   // 当前校准子周期编号
	output [C_CAL_TICK_WIDTH - 1:0]o_calibration_local_tick, // 校准局部相位
	output o_normal_frame_complete_event,       // NORMAL宏帧完成单拍
	output o_calibration_frame_complete_event,  // 校准物理宏帧完成单拍

	//----------------状态与诊断----------------//
	output o_scheduler_idle,                    // 数字事务和物理时序均排空
	output o_normal_frame_active,               // 当前执行NORMAL宏帧
	output o_calibration_frame_active,          // 当前执行校准宏帧
	output o_transaction_inflight,              // 当前存在已启动ADC owner
	output [C_FRAME_ID_WIDTH - 1:0]o_current_frame_id, // 当前400 Hz帧编号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_next_sample_index, // 下一笔ADC序号
	output o_launch_timeout_sticky,             // 波形接管错过诊断
	output o_owner_deadline_timeout_sticky,     // ADC owner截止错过诊断
	output o_cal_owner_deadline_event,          // 校准owner截止单周期事件，供AMI据此重新发起同一候选的请求
	output o_completion_mismatch_sticky,        // DONE身份错配诊断
	output o_protocol_error_sticky,             // 握手或编码协议诊断
	output o_scheduler_local_fault_blocking,    // 仅调度器本地阻断汇总

	//---------------故障记录接口---------------//
	output o_scheduler_fault_valid,             // 新故障episode单周期脉冲，供system fault/abort supervisor观测
	output o_scheduler_fault_active,            // 注册式阻断持续状态，即scheduler_local_fault_blocking
	output [7:0]o_scheduler_fault_cause,        // 固定8'h11，不可恢复协议错误原因码
	output o_scheduler_fault_identity_valid,    // 本次故障是否绑定了真实owner身份
	output [C_FRAME_ID_WIDTH - 1:0]o_scheduler_fault_frame_id, // 故障owner所属400 Hz帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_scheduler_fault_sample_index, // 故障owner全局序号
	output o_scheduler_fault_color_ir,          // 故障owner颜色
	output [1:0]o_scheduler_fault_frame_type,   // 故障owner事务类型
	output o_scheduler_fault_precision_mode,    // 故障owner精度
	output [C_RUN_GENERATION_WIDTH - 1:0]o_scheduler_fault_run_generation // 故障owner所属RUN代际
);
	wire flag_calibration_rollover;             // 校准宏帧末拍存在下一笔请求时，标记直接滚入下一625-tick子帧而不产生边界空拍
	//---------------配置参数区域---------------//
	//===================<固定编码与相位>===================//
	localparam [1:0]FRAME_TYPE_AMB = 2'b00;     // AMB_CAL事务编码
	localparam [1:0]FRAME_TYPE_DCS = 2'b01;     // 颜色DC搜索或重检校准事务的专属编码
	localparam [1:0]FRAME_TYPE_NORMAL = 2'b10;  // 稳态PPG采样结果事务的常规编码
	localparam [1:0]OPTICAL_BOTH = 2'b00;       // RED后IR双光模式
	localparam [1:0]OPTICAL_RED = 2'b01;        // 纯RED模式
	localparam [1:0]OPTICAL_IR = 2'b10;         // 纯IR模式
	localparam [1:0]OPTICAL_OFF = 2'b11;        // 安全关闭模式
	localparam [1:0]FRAME_MODE_IDLE = 2'b00;    // 无宏帧活动
	localparam [1:0]FRAME_MODE_NORMAL = 2'b01;  // NORMAL宏帧活动
	localparam [1:0]FRAME_MODE_CAL = 2'b10;     // SAR9校准宏帧活动
	localparam RUN_PROFILE_NORMAL = 1'b0;       // i_run_profile低电平为NORMAL_PPG，与AMI合同6.6节编码一致
	localparam INPUT_SOURCE_PHOTODIODE = 1'b0;  // i_input_source低电平为光电二极管来源，与V4配置bit9编码一致
	localparam integer MACRO_LAST_TICK = C_MACRO_FRAME_TICKS - 1; // 400 Hz宏帧终止的最后一个2 MHz相位
	localparam integer MACRO_SAFE_TICK = C_MACRO_FRAME_TICKS - 240; // 留出240 tick的宏帧末尾IDAC安全提交区
	localparam integer NORMAL_RED_CONTEXT_TICK = 32'd0; // NORMAL RED波形上下文在宏帧起点接管；波形上下文只在两个固定接管点与SSW握手 @satisfies: TOP-05
	localparam integer NORMAL_IR_CONTEXT_TICK = 32'd160; // NORMAL IR波形上下文在RED后移160 tick接管
	localparam integer CAL_CONTEXT_TICK = 32'd0; // 每个校准子帧从局部起点发布专用波形；local tick 0快照点 @satisfies: TOP-04
	localparam integer CAL_LAST_LOCAL_TICK = C_CAL_SUBFRAME_TICKS - 1; // 校准局部相位回零前的末拍
	localparam integer CAL_IDAC_LOCAL_TICK = 32'd385; // 校准子帧内供IDAC更新使用的安全相位

	//===================<状态向量字段>===================//
	localparam integer B_STARTED = 32'd0;       // RUN生命周期的起始标志位
	localparam integer B_STARTUP_PENDING = B_STARTED + 1; // START边界待发
	localparam integer B_STOP_DRAIN = B_STARTUP_PENDING + 1; // STOP或abort排空
	localparam integer B_FRAME_ACTIVE = B_STOP_DRAIN + 1; // 标记状态向量中当前400 Hz帧仍处于存活期
	localparam integer B_FRAME_MODE_L = B_FRAME_ACTIVE + 1; // 宏帧模式低位
	localparam integer B_FRAME_MODE_H = B_FRAME_MODE_L + 1; // 宏帧模式高位
	localparam integer B_FRAME_OPTICAL_L = B_FRAME_MODE_H + 1; // 光学模式低位
	localparam integer B_FRAME_OPTICAL_H = B_FRAME_OPTICAL_L + 1; // 光学模式高位
	localparam integer B_FRAME_PRECISION = B_FRAME_OPTICAL_H + 1; // 宏帧精度快照
	localparam integer B_FRAME_INPUT_SOURCE = B_FRAME_PRECISION + 1; // 输入来源快照
	localparam integer B_FRAME_ID_L = B_FRAME_INPUT_SOURCE + 1; // 帧号低位
	localparam integer B_FRAME_ID_H = B_FRAME_ID_L + C_FRAME_ID_WIDTH - 1; // 帧号高位
	localparam integer B_MACRO_TICK_L = B_FRAME_ID_H + 1; // 宏帧相位低位
	localparam integer B_MACRO_TICK_H = B_MACRO_TICK_L + C_MACRO_TICK_WIDTH - 1; // 宏帧相位高位
	localparam integer B_CAL_SUB_L = B_MACRO_TICK_H + 1; // 校准子周期低位
	localparam integer B_CAL_SUB_H = B_CAL_SUB_L + 2; // 校准子周期高位
	localparam integer B_CAL_LOCAL_L = B_CAL_SUB_H + 1; // 校准局部相位低位
	localparam integer B_CAL_LOCAL_H = B_CAL_LOCAL_L + C_CAL_TICK_WIDTH - 1; // 校准局部相位高位
	localparam integer B_RED_REQUIRED = B_CAL_LOCAL_H + 1; // RED是否需要
	localparam integer B_IR_REQUIRED = B_RED_REQUIRED + 1; // 由光学模式快照决定IR颜色槽是否必须完成
	localparam integer B_RED_DONE = B_IR_REQUIRED + 1; // RED结果成功
	localparam integer B_IR_DONE = B_RED_DONE + 1; // 仅在IR owner返回成功DONE后记录颜色结果完成
	localparam integer B_FRAME_FAILED = B_IR_DONE + 1; // 当前宏帧失败
	localparam integer B_FRAME_AMB_L = B_FRAME_FAILED + 1; // 宏帧AMB码低位
	localparam integer B_FRAME_AMB_H = B_FRAME_AMB_L + C_IDAC_CODE_WIDTH - 1; // 宏帧AMB码高位
	localparam integer B_FRAME_DCR_L = B_FRAME_AMB_H + 1; // RED颜色槽DC快照在帧载荷中的起始位
	localparam integer B_FRAME_DCR_H = B_FRAME_DCR_L + C_IDAC_CODE_WIDTH - 1; // RED颜色槽DC快照的末位并限定取片宽度
	localparam integer B_FRAME_DCIR_L = B_FRAME_DCR_H + 1; // IR颜色槽DC码从状态向量该位开始保存
	localparam integer B_FRAME_DCIR_H = B_FRAME_DCIR_L + C_IDAC_CODE_WIDTH - 1; // IR颜色槽DC码在此闭合并供IR waveform使用
	localparam integer B_FRAME_AMB_EPOCH_L = B_FRAME_DCIR_H + 1; // 宏帧AMB版本低位
	localparam integer B_FRAME_AMB_EPOCH_H = B_FRAME_AMB_EPOCH_L + C_CODE_EPOCH_WIDTH - 1; // 宏帧AMB版本高位
	localparam integer B_FRAME_DCR_EPOCH_L = B_FRAME_AMB_EPOCH_H + 1; // RED DC提交版本的帧内存储起始位
	localparam integer B_FRAME_DCR_EPOCH_H = B_FRAME_DCR_EPOCH_L + C_CODE_EPOCH_WIDTH - 1; // RED DC epoch快照的最高保存位
	localparam integer B_FRAME_DCIR_EPOCH_L = B_FRAME_DCR_EPOCH_H + 1; // IR DC提交版本从该位置进入帧快照
	localparam integer B_FRAME_DCIR_EPOCH_H = B_FRAME_DCIR_EPOCH_L + C_CODE_EPOCH_WIDTH - 1; // IR DC epoch取片在该位置结束
	localparam integer B_FRAME_LEDDAC_R_L = B_FRAME_DCIR_EPOCH_H + 1; // 宏帧RED LEDDAC低位
	localparam integer B_FRAME_LEDDAC_R_H = B_FRAME_LEDDAC_R_L + 8 - 1; // 宏帧RED LEDDAC高位，固定8-bit物理LED驱动码宽度，与AMB/DC的C_IDAC_CODE_WIDTH解耦
	localparam integer B_FRAME_LEDDAC_IR_L = B_FRAME_LEDDAC_R_H + 1; // IR LED RDAC码在帧快照中独立存放的首位
	localparam integer B_FRAME_LEDDAC_IR_H = B_FRAME_LEDDAC_IR_L + 8 - 1; // IR LED RDAC码完整取片的终止位，固定8-bit物理LED驱动码宽度，与AMB/DC的C_IDAC_CODE_WIDTH解耦
	localparam integer B_CAL_REQ_PENDING = B_FRAME_LEDDAC_IR_H + 1; // 待接收校准请求
	localparam integer B_CAL_REQ_ACTIVE = B_CAL_REQ_PENDING + 1; // 当前校准请求仍需重试
	localparam integer B_CAL_REQ_TYPE_L = B_CAL_REQ_ACTIVE + 1; // 请求类型低位
	localparam integer B_CAL_REQ_TYPE_H = B_CAL_REQ_TYPE_L + 1; // 请求类型高位
	localparam integer B_CAL_REQ_COLOR = B_CAL_REQ_TYPE_H + 1; // 请求颜色
	localparam integer B_CAL_REQ_REASON_L = B_CAL_REQ_COLOR + 1; // 请求原因低位
	localparam integer B_CAL_REQ_REASON_H = B_CAL_REQ_REASON_L + 1; // 请求原因高位
	localparam integer B_CAL_FRAME_TYPE_L = B_CAL_REQ_REASON_H + 1; // 帧内校准类型低位
	localparam integer B_CAL_FRAME_TYPE_H = B_CAL_FRAME_TYPE_L + 1; // 帧内校准类型高位
	localparam integer B_CAL_FRAME_COLOR = B_CAL_FRAME_TYPE_H + 1; // 帧内校准颜色
	localparam integer B_CAL_FRAME_REASON_L = B_CAL_FRAME_COLOR + 1; // 帧内原因低位
	localparam integer B_CAL_FRAME_REASON_H = B_CAL_FRAME_REASON_L + 1; // 帧内原因高位
	localparam integer B_RED_CONTEXT_SEEN = B_CAL_FRAME_REASON_H + 1; // RED接管点已处理
	localparam integer B_IR_CONTEXT_SEEN = B_RED_CONTEXT_SEEN + 1; // 阻止同一宏帧内重复发布IR波形上下文
	localparam integer B_CAL_CONTEXT_SEEN = B_IR_CONTEXT_SEEN + 1; // 校准接管点已处理
	localparam integer B_RED_WAVE_PENDING = B_CAL_CONTEXT_SEEN + 1; // RED波形待建owner
	localparam integer B_IR_WAVE_PENDING = B_RED_WAVE_PENDING + 1; // IR波形已接管但尚未形成物理ADC owner
	localparam integer B_CAL_WAVE_PENDING = B_IR_WAVE_PENDING + 1; // 校准波形待建owner
	localparam integer B_CAL_WAVE_AMB_L = B_CAL_WAVE_PENDING + 1; // 校准AMB快照低位
	localparam integer B_CAL_WAVE_AMB_H = B_CAL_WAVE_AMB_L + C_IDAC_CODE_WIDTH - 1; // 校准AMB快照高位
	localparam integer B_CAL_WAVE_DC_L = B_CAL_WAVE_AMB_H + 1; // DCS校准颜色DC候选码在载荷内的首位
	localparam integer B_CAL_WAVE_DC_H = B_CAL_WAVE_DC_L + C_IDAC_CODE_WIDTH - 1; // DCS校准颜色DC候选码的取片上界
	localparam integer B_CAL_WAVE_AMB_EPOCH_L = B_CAL_WAVE_DC_H + 1; // 校准AMB版本低位
	localparam integer B_CAL_WAVE_AMB_EPOCH_H = B_CAL_WAVE_AMB_EPOCH_L + C_CODE_EPOCH_WIDTH - 1; // 校准AMB版本高位
	localparam integer B_CAL_WAVE_DC_EPOCH_L = B_CAL_WAVE_AMB_EPOCH_H + 1; // 校准DCS颜色DC版本从该位写入暂存载荷
	localparam integer B_CAL_WAVE_DC_EPOCH_H = B_CAL_WAVE_DC_EPOCH_L + C_CODE_EPOCH_WIDTH - 1; // 校准DCS颜色DC版本在此位闭合
	localparam integer B_INFLIGHT = B_CAL_WAVE_DC_EPOCH_H + 1; // ADC owner在途
	localparam integer B_INFLIGHT_DISCARD = B_INFLIGHT + 1; // 在途结果受控丢弃
	localparam integer B_INFLIGHT_SAMPLE_L = B_INFLIGHT_DISCARD + 1; // 在途序号低位
	localparam integer B_INFLIGHT_SAMPLE_H = B_INFLIGHT_SAMPLE_L + C_SAMPLE_INDEX_WIDTH - 1; // 在途序号高位
	localparam integer B_INFLIGHT_TYPE_L = B_INFLIGHT_SAMPLE_H + 1; // 在途类型低位
	localparam integer B_INFLIGHT_TYPE_H = B_INFLIGHT_TYPE_L + 1; // 在途类型高位
	localparam integer B_INFLIGHT_COLOR = B_INFLIGHT_TYPE_H + 1; // 在途颜色
	localparam integer B_INFLIGHT_GENERATION_L = B_INFLIGHT_COLOR + 1; // 在途owner创建时刻锁存的RUN代际低位
	localparam integer B_INFLIGHT_GENERATION_H = B_INFLIGHT_GENERATION_L + C_RUN_GENERATION_WIDTH - 1; // 在途owner创建时刻锁存的RUN代际高位，用于拒绝跨代际DONE匹配
	localparam integer B_NEXT_SAMPLE_L = B_INFLIGHT_GENERATION_H + 1; // 下一ADC序号低位
	localparam integer B_NEXT_SAMPLE_H = B_NEXT_SAMPLE_L + C_SAMPLE_INDEX_WIDTH - 1; // 下一ADC序号高位
	localparam integer B_MACRO_START = B_NEXT_SAMPLE_H + 1; // 宏帧起点脉冲
	localparam integer B_NORMAL_COMPLETE = B_MACRO_START + 1; // NORMAL完成脉冲
	localparam integer B_CAL_COMPLETE = B_NORMAL_COMPLETE + 1; // 校准物理完成脉冲
	localparam integer B_LAUNCH_TIMEOUT = B_CAL_COMPLETE + 1; // 波形接管超时sticky
	localparam integer B_OWNER_DEADLINE_TIMEOUT = B_LAUNCH_TIMEOUT + 1; // owner截止sticky
	localparam integer B_COMPLETION_MISMATCH = B_OWNER_DEADLINE_TIMEOUT + 1; // DONE错配sticky
	localparam integer B_PROTOCOL_ERROR = B_COMPLETION_MISMATCH + 1; // 协议错误sticky
	localparam integer B_SCHED_FAULT_VALID = B_PROTOCOL_ERROR + 1; // 新故障episode单周期脉冲
	localparam integer B_SCHED_FAULT_IDENTITY_VALID = B_SCHED_FAULT_VALID + 1; // 故障是否绑定了真实owner身份
	localparam integer B_SCHED_FAULT_FRAME_ID_L = B_SCHED_FAULT_IDENTITY_VALID + 1; // 故障owner帧号低位
	localparam integer B_SCHED_FAULT_FRAME_ID_H = B_SCHED_FAULT_FRAME_ID_L + C_FRAME_ID_WIDTH - 1; // 故障owner帧号高位
	localparam integer B_SCHED_FAULT_SAMPLE_INDEX_L = B_SCHED_FAULT_FRAME_ID_H + 1; // 故障owner序号低位
	localparam integer B_SCHED_FAULT_SAMPLE_INDEX_H = B_SCHED_FAULT_SAMPLE_INDEX_L + C_SAMPLE_INDEX_WIDTH - 1; // 故障owner序号高位
	localparam integer B_SCHED_FAULT_COLOR = B_SCHED_FAULT_SAMPLE_INDEX_H + 1; // 状态向量中锁存的故障快照红光红外选择位
	localparam integer B_SCHED_FAULT_FRAME_TYPE_L = B_SCHED_FAULT_COLOR + 1; // 故障owner类型低位
	localparam integer B_SCHED_FAULT_FRAME_TYPE_H = B_SCHED_FAULT_FRAME_TYPE_L + 1; // 故障owner类型高位
	localparam integer B_SCHED_FAULT_PRECISION = B_SCHED_FAULT_FRAME_TYPE_H + 1; // 状态向量中锁存的故障快照SAR9或SAR15选择位
	localparam integer B_SCHED_FAULT_GENERATION_L = B_SCHED_FAULT_PRECISION + 1; // 故障owner所属RUN代际低位
	localparam integer B_SCHED_FAULT_GENERATION_H = B_SCHED_FAULT_GENERATION_L + C_RUN_GENERATION_WIDTH - 1; // 故障owner所属RUN代际高位
	localparam integer STATE_WIDTH = B_SCHED_FAULT_GENERATION_H + 1; // 调度状态总宽度

	//----------------状态机信号----------------//
	reg [STATE_WIDTH - 1:0]state_current = {STATE_WIDTH{1'b0}}; // 当前完整调度状态的唯一寄存器
	reg [STATE_WIDTH - 1:0]state_next = {STATE_WIDTH{1'b0}}; // 组合计算得到的下一拍调度状态
	reg [STATE_WIDTH - 1:0]state_rollover_next = {STATE_WIDTH{1'b0}}; // 在state_next基础上叠加校准滚动覆盖的最终待寄存值

	//-----------------标志信号-----------------//
	wire flag_external_fault;                   // AMI或SSW输入故障
	wire flag_lifecycle_active;                 // 可发起新上下文
	wire flag_calibration_request_valid;        // 输入校准载荷合法
	wire flag_calibration_request_fire;         // 校准请求握手
	wire flag_frame_start_eligible;             // 首帧或下一帧启动资格
	wire flag_red_required;                     // 当前帧需要RED
	wire flag_ir_required;                      // 由帧内光学模式判定是否必须执行IR颜色槽
	wire flag_red_context_due;                  // RED固定接管相位
	wire flag_ir_context_due;                   // 宏帧160 tick到达且IR上下文尚未发布的唯一时刻
	wire flag_cal_context_due;                  // 校准固定接管相位
	wire flag_waveform_is_calibration;          // 当前波形槽属于校准
	wire flag_waveform_is_ir;                   // 当前波形槽属于IR
	wire flag_waveform_fire;                    // 波形上下文真实fire
	wire flag_cal_wave_dc_is_ir;                // 校准DC颜色选择
	wire flag_candidate_calibration;            // 校准owner候选
	wire flag_candidate_red;                    // RED owner候选
	wire flag_candidate_ir;                     // IR owner候选
	wire flag_transaction_candidate;            // 存在最早owner候选
	wire flag_completion_match;                 // DONE身份匹配
	wire flag_completion_success;               // 匹配且成功且非丢弃
	wire flag_red_owner_deadline;               // RED owner截止到达
	wire flag_ir_owner_deadline;                // IR波形未提交ADC owner时触发的443 tick超时条件
	wire flag_cal_owner_deadline;               // 校准owner截止到达

	//-----------------译码信号-----------------//
	wire [1:0]dec_frame_mode;                   // 当前宏帧模式
	wire [1:0]dec_frame_optical_mode;           // 当前宏帧光学模式

	//----------------其他信号----------------//
	//-----------------输出信号-----------------//
	//AMI校准请求
	wire calibration_sample_ready_o;            // 校准请求ready

	//SSW模拟波形上下文
	wire waveform_context_valid_o;              // 波形valid组合桥
	wire waveform_precision_mode_o;             // 波形精度桥
	wire [C_FRAME_ID_WIDTH - 1:0]waveform_frame_id_o; // 波形帧号桥
	wire waveform_color_ir_o;                   // 波形颜色桥
	wire [1:0]waveform_frame_type_o;            // 波形类型桥
	wire [C_IDAC_CODE_WIDTH - 1:0]waveform_amb_code_snapshot_o; // 波形AMB码桥
	wire [C_IDAC_CODE_WIDTH - 1:0]waveform_dc_code_snapshot_o; // 指向颜色相关DC快照的SSW内部输出桥
	wire [C_CODE_EPOCH_WIDTH - 1:0]waveform_amb_code_epoch_o; // 波形AMB版本桥
	wire [C_CODE_EPOCH_WIDTH - 1:0]waveform_dc_code_epoch_o; // 随颜色DC快照一起交付给SSW的内部epoch桥
	wire waveform_input_source_o;               // 波形输入来源桥
	wire [1:0]waveform_optical_mode_o;          // 波形光学模式桥
	wire [7:0]waveform_leddac_code_snapshot_o;  // 波形LEDDAC桥，固定8-bit物理LED驱动码宽度，与AMB/DC的C_IDAC_CODE_WIDTH解耦

	//AMI ADC结果事务
	wire transaction_start_valid_o;             // AMI事务valid组合桥
	wire transaction_precision_mode_o;          // 事务精度桥
	wire [C_FRAME_ID_WIDTH - 1:0]transaction_frame_id_o; // 事务帧号桥
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]transaction_sample_index_o; // 事务序号桥
	wire transaction_color_ir_o;                // 事务颜色桥
	wire [1:0]transaction_frame_type_o;         // 事务类型桥
	wire [C_IDAC_CODE_WIDTH - 1:0]transaction_amb_code_o; // 事务AMB码桥
	wire [C_IDAC_CODE_WIDTH - 1:0]transaction_dc_code_o; // AMI结果owner携带的本颜色DC码内部桥
	wire [C_CODE_EPOCH_WIDTH - 1:0]transaction_amb_epoch_o; // 事务AMB版本桥
	wire [C_CODE_EPOCH_WIDTH - 1:0]transaction_dc_epoch_o; // AMI结果owner携带的颜色DC版本内部桥

	//SSW owner与物理完成
	wire adc_owner_commit_event_o;              // scheduler本地真实fire
	wire flag_calibration_boundary_o;           // 校准IDAC边界组合脉冲

	//时间与完成事件
	wire macro_frame_safe_boundary_o;           // 宏帧安全边界组合脉冲
	wire idac_code_safe_boundary_o;             // IDAC边界合并脉冲
	wire startup_idac_safe_boundary_o;          // START边界组合脉冲
	wire [C_MACRO_TICK_WIDTH - 1:0]macro_tick_o; // 由状态向量选片形成的宏帧相位内部读出口
	wire [2:0]calibration_subframe_index_o;     // 当前校准子周期
	wire [C_CAL_TICK_WIDTH - 1:0]calibration_local_tick_o; // 当前校准局部相位

	//状态与诊断
	wire [C_FRAME_ID_WIDTH - 1:0]current_frame_id_o; // 当前物理帧号
	wire scheduler_local_fault_blocking_o;      // 本地活动阻断故障

	//故障记录接口
	wire [7:0]scheduler_fault_cause_o;          // 固定原因码桥，非活动时清零

	//---------------其他信号连线---------------//
	//===================<状态提取赋值>===================//
	assign dec_frame_mode = state_current[B_FRAME_MODE_H:B_FRAME_MODE_L]; // 提取宏帧模式
	assign dec_frame_optical_mode = state_current[B_FRAME_OPTICAL_H:B_FRAME_OPTICAL_L]; // 提取光学模式
	assign current_frame_id_o = state_current[B_FRAME_ID_H:B_FRAME_ID_L]; // 提取当前frame_id
	assign macro_tick_o = state_current[B_MACRO_TICK_H:B_MACRO_TICK_L]; // 提取宏帧tick
	assign calibration_subframe_index_o = state_current[B_CAL_SUB_H:B_CAL_SUB_L]; // 提取子帧序号
	assign calibration_local_tick_o = state_current[B_CAL_LOCAL_H:B_CAL_LOCAL_L]; // 提取校准局部tick
	//===================<组合资格赋值>===================//
	assign scheduler_local_fault_blocking_o = state_current[B_PROTOCOL_ERROR] || state_current[B_COMPLETION_MISMATCH]; // 仅本地协议和身份错配阻断
	assign flag_external_fault = i_ami_fault_blocking || i_ssw_fault_blocking; // 外部两路故障独立汇总使用
	assign scheduler_fault_cause_o = scheduler_local_fault_blocking_o ? 8'h11 : 8'h00; // 仅调度器不可恢复协议错误的固定原因码

	//其他信号连线
	assign flag_lifecycle_active = state_current[B_STARTED] && i_run_enable && !state_current[B_STOP_DRAIN] && !i_stop_ack_event && !i_control_abort_event && !scheduler_local_fault_blocking_o && !flag_external_fault; // 新事务生命周期资格
	assign flag_calibration_request_valid = (i_run_profile == RUN_PROFILE_NORMAL) && (i_input_source == INPUT_SOURCE_PHOTODIODE) && (((i_calibration_frame_type == FRAME_TYPE_AMB) && !i_calibration_color_ir && !i_calibration_precision_mode) || ((i_calibration_frame_type == FRAME_TYPE_DCS) && !i_calibration_precision_mode)); // 合同9.1节接收端资格：只允许NORMAL_PPG+PHOTODIODE下的SAR9 AMB或DCS请求，CHARACTERIZATION/外部电流/非法编码一律拒绝；Scheduler接收端资格检查(与manager静态检查分工) @satisfies: TOP-20

	//其他信号连线
	assign calibration_sample_ready_o = flag_calibration_request_valid && flag_lifecycle_active && i_active_config_valid && !state_current[B_CAL_REQ_PENDING] &&
		((!state_current[B_CAL_REQ_ACTIVE] && (!state_current[B_FRAME_ACTIVE] || (dec_frame_mode == FRAME_MODE_NORMAL))) ||
		 ((state_current[B_CAL_REQ_ACTIVE] == 1'b1) && (dec_frame_mode == FRAME_MODE_CAL) &&
		  !state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT])); // 校准序列在子帧间允许接收下一笔保持请求；合同9.1节要求ready本身就必须以接收端资格为前提，不能只在事后置协议错误——非法请求（CHARACTERIZATION/外部电流/非法编码/SAR15）必须在ready这一层就被挡住，不得建立波形上下文、owner或pending
	assign flag_calibration_request_fire = i_calibration_sample_valid && calibration_sample_ready_o; // 请求原子握手
	assign flag_frame_start_eligible = flag_lifecycle_active && !state_current[B_FRAME_ACTIVE] && !state_current[B_STARTUP_PENDING] && i_active_config_valid && (state_current[B_CAL_REQ_PENDING] || (i_allow_new_transaction && (i_optical_mode == OPTICAL_OFF || (i_normal_measurement_eligible && !i_switch_hold_new_transaction && (i_optical_mode != OPTICAL_OFF))))); // 宏帧启动资格
	assign flag_red_required = (dec_frame_optical_mode == OPTICAL_BOTH) || (dec_frame_optical_mode == OPTICAL_RED); // 当前宏帧是否需要RED
	assign flag_ir_required = (dec_frame_optical_mode == OPTICAL_BOTH) || (dec_frame_optical_mode == OPTICAL_IR); // 当前帧配置包含IR槽时返回事务必需资格；ILM-02/ILM-03 RED_ONLY下本条件恒为0，宏帧从不构造IR槽，全程不产生IR波形或owner @satisfies: ILM-02, ILM-03
	assign flag_red_context_due = state_current[B_FRAME_ACTIVE] && (dec_frame_mode == FRAME_MODE_NORMAL) && flag_red_required && !state_current[B_RED_CONTEXT_SEEN] && (macro_tick_o == NORMAL_RED_CONTEXT_TICK); // RED只允许tick 0
	assign flag_ir_context_due = state_current[B_FRAME_ACTIVE] && (dec_frame_mode == FRAME_MODE_NORMAL) && flag_ir_required && !state_current[B_IR_CONTEXT_SEEN] && (macro_tick_o == NORMAL_IR_CONTEXT_TICK); // IR只允许tick 160
	assign flag_cal_context_due = state_current[B_FRAME_ACTIVE] && (dec_frame_mode == FRAME_MODE_CAL) && state_current[B_CAL_REQ_ACTIVE] && !state_current[B_CAL_CONTEXT_SEEN] && (calibration_local_tick_o == CAL_CONTEXT_TICK) && ((calibration_subframe_index_o == 3'd0) || state_current[B_CAL_REQ_PENDING]); // 首个校准子帧消费已接受请求，后续子帧必须先有新的请求握手

	//其他信号连线
	assign flag_waveform_is_calibration = flag_cal_context_due; // 校准波形类型选择
	assign flag_waveform_is_ir = flag_ir_context_due; // IR波形类型选择
	assign waveform_context_valid_o = flag_lifecycle_active && (flag_red_context_due || flag_ir_context_due || flag_cal_context_due); // 固定接管点valid
	assign flag_waveform_fire = waveform_context_valid_o && i_waveform_context_ready; // 唯一波形上下文fire
	assign flag_cal_wave_dc_is_ir = state_current[B_CAL_FRAME_COLOR]; // DCS校准的颜色选择
	assign flag_candidate_calibration = state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT]; // 校准优先owner候选
	assign flag_candidate_red = !flag_candidate_calibration && state_current[B_RED_WAVE_PENDING] && !state_current[B_INFLIGHT]; // RED优先于IR
	assign flag_candidate_ir = !flag_candidate_calibration && !flag_candidate_red && state_current[B_IR_WAVE_PENDING] && !state_current[B_INFLIGHT]; // IR后置owner候选

	//其他信号连线
	assign flag_transaction_candidate = flag_candidate_calibration || flag_candidate_red || flag_candidate_ir; // 存在最早未提交owner
	assign transaction_start_valid_o = flag_transaction_candidate && i_adc_owner_ready && i_allow_new_transaction && flag_lifecycle_active; // SSW ready独立门控AMI valid；flag_lifecycle_active在STOP/abort/故障发生的同一拍归零，是LFA-01/LFA-02"STOP期间禁止新owner"要求的直接门控点 @satisfies: LFA-01, LFA-02

	//TRANSACTION_START接口
	assign adc_owner_commit_event_o = transaction_start_valid_o && i_transaction_start_ready; // AMI ready形成正式fire

	//其他信号连线
	assign flag_completion_match = i_adc_transaction_complete_event && state_current[B_INFLIGHT] && 1'b1 && (i_run_generation == state_current[B_INFLIGHT_GENERATION_H:B_INFLIGHT_GENERATION_L]); // DONE身份逐位匹配，含RUN代际校验防止跨代际误配；不额外要求Q3已关闭——身份匹配就应该合法释放owner槽位，否则一旦Q3因异常提前完成而不再出现，owner会永久卡在in-flight，见flag_completion_success自己的Q3门控注释；sample_index/generation身份匹配是NORMAL双光owner连续性的支撑机制之一(非唯一锚点,中等置信度) @satisfies: TOP-03
	assign flag_completion_success = flag_completion_match && i_adc_transaction_success && !state_current[B_INFLIGHT_DISCARD] && i_owner_q3_window_closed; // 正式成功结果资格，额外要求在途owner自身选定的Q3窗口已关闭，防止提前的CLK_DOUT冒充成功完成；门控放在success而不是match/release上，避免Q3若因异常提前完成而不再出现时owner永久卡在in-flight的死锁
	assign startup_idac_safe_boundary_o = state_current[B_STARTUP_PENDING] && flag_lifecycle_active && i_adc_idle && i_analog_safe && i_sar_timing_idle && !state_current[B_FRAME_ACTIVE] && !state_current[B_RED_WAVE_PENDING] && !state_current[B_IR_WAVE_PENDING] && !state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT]; // START一次性边界
	assign macro_frame_safe_boundary_o = state_current[B_FRAME_ACTIVE] && flag_lifecycle_active && (macro_tick_o == MACRO_SAFE_TICK); // 宏帧唯一边界
	assign flag_calibration_boundary_o = state_current[B_FRAME_ACTIVE] && (dec_frame_mode == FRAME_MODE_CAL) && flag_lifecycle_active && (calibration_local_tick_o == CAL_IDAC_LOCAL_TICK); // 每625 tick校准边界；SID-06 唯一的本地tick 385安全提交点，早于此点的候选/确认AMB码/颜色/版本更新只在此刻原子提交，之后的更新只影响下一子帧 @satisfies: SID-06
	assign idac_code_safe_boundary_o = startup_idac_safe_boundary_o || macro_frame_safe_boundary_o || flag_calibration_boundary_o; // 启动、宏帧和校准边界合并
	assign flag_red_owner_deadline = state_current[B_FRAME_ACTIVE] && (dec_frame_mode == FRAME_MODE_NORMAL) && state_current[B_RED_WAVE_PENDING] && !state_current[B_INFLIGHT] && (macro_tick_o >= C_NORMAL_RED_OWNER_DEADLINE); // RED owner截止
	assign flag_ir_owner_deadline = state_current[B_FRAME_ACTIVE] && (dec_frame_mode == FRAME_MODE_NORMAL) && state_current[B_IR_WAVE_PENDING] && !state_current[B_INFLIGHT] && (macro_tick_o >= C_NORMAL_IR_OWNER_DEADLINE); // IR owner截止
	assign flag_cal_owner_deadline = state_current[B_FRAME_ACTIVE] && (dec_frame_mode == FRAME_MODE_CAL) && state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT] && (calibration_local_tick_o >= C_CAL_OWNER_DEADLINE); // 校准owner截止；SID-05 本地tick 248截止相位，越过仍未提交owner即判定错过窗口 @satisfies: SID-05
	assign flag_calibration_rollover = (dec_frame_mode == FRAME_MODE_CAL) &&
		(macro_tick_o == MACRO_LAST_TICK) &&
		(state_current[B_CAL_REQ_ACTIVE] == 1'b1) &&
		(state_current[B_CAL_WAVE_PENDING] == 1'b0) &&
		(state_current[B_INFLIGHT] == 1'b0) &&
		((state_current[B_CAL_REQ_PENDING] == 1'b1) || (i_calibration_sample_valid == 1'b1)); // 校准宏帧末拍存在下一笔请求时直接滚入下一子帧的资格
	//===================<波形载荷赋值>===================//
	assign waveform_precision_mode_o = flag_waveform_is_calibration ? 1'b0 : state_current[B_FRAME_PRECISION]; // 校准强制SAR9

	//其他信号连线
	assign waveform_frame_id_o = current_frame_id_o; // 波形绑定当前宏帧
	assign waveform_color_ir_o = flag_waveform_is_calibration ? state_current[B_CAL_FRAME_COLOR] : (flag_waveform_is_ir ? 1'b1 : 1'b0); // AMB和RED固定颜色0
	assign waveform_frame_type_o = flag_waveform_is_calibration ? state_current[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] : FRAME_TYPE_NORMAL; // 校准波形从活动请求取类型，普通波形固定为NORMAL

	//其他信号连线
	assign waveform_amb_code_snapshot_o = flag_waveform_is_calibration ? i_amb_code : state_current[B_FRAME_AMB_H:B_FRAME_AMB_L]; // 校准波形从本次接管时的AMB提交码构成独立快照
	assign waveform_dc_code_snapshot_o = flag_waveform_is_calibration ? ((state_current[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] == FRAME_TYPE_AMB) ? {C_IDAC_CODE_WIDTH{1'b0}} : (state_current[B_CAL_FRAME_COLOR] ? i_dcs_ir_code : i_dcs_r_code)) : (flag_waveform_is_ir ? state_current[B_FRAME_DCIR_H:B_FRAME_DCIR_L] : state_current[B_FRAME_DCR_H:B_FRAME_DCR_L]); // DCS选色后读取同色DC码，AMB校准则强制归零
	assign waveform_amb_code_epoch_o = flag_waveform_is_calibration ? i_amb_code_epoch : state_current[B_FRAME_AMB_EPOCH_H:B_FRAME_AMB_EPOCH_L]; // 波形AMB版本快照
	assign waveform_dc_code_epoch_o = flag_waveform_is_calibration ? ((state_current[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] == FRAME_TYPE_AMB) ? {C_CODE_EPOCH_WIDTH{1'b0}} : (state_current[B_CAL_FRAME_COLOR] ? i_dcs_ir_code_epoch : i_dcs_r_code_epoch)) : (flag_waveform_is_ir ? state_current[B_FRAME_DCIR_EPOCH_H:B_FRAME_DCIR_EPOCH_L] : state_current[B_FRAME_DCR_EPOCH_H:B_FRAME_DCR_EPOCH_L]); // 校准DCS颜色码的epoch与NORMAL帧快照在此择一
	assign waveform_input_source_o = state_current[B_FRAME_INPUT_SOURCE]; // 宏帧建立时锁存的输入源字段直接送往SSW波形槽
	assign waveform_optical_mode_o = flag_waveform_is_calibration ? ((state_current[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] == FRAME_TYPE_AMB) ? OPTICAL_OFF : (state_current[B_CAL_FRAME_COLOR] ? OPTICAL_IR : OPTICAL_RED)) : dec_frame_optical_mode; // AMB关闭LED，DCS按颜色工作
	assign waveform_leddac_code_snapshot_o = flag_waveform_is_calibration ? 8'h00 : (flag_waveform_is_ir ? state_current[B_FRAME_LEDDAC_IR_H:B_FRAME_LEDDAC_IR_L] : state_current[B_FRAME_LEDDAC_R_H:B_FRAME_LEDDAC_R_L]); // 固定电流和校准不驱动LEDDAC
	//===================<事务载荷赋值>===================//
	assign transaction_precision_mode_o = flag_candidate_calibration ? 1'b0 : state_current[B_FRAME_PRECISION]; // owner事务精度

	//其他信号连线
	assign transaction_frame_id_o = current_frame_id_o; // owner事务物理帧号
	assign transaction_sample_index_o = state_current[B_NEXT_SAMPLE_H:B_NEXT_SAMPLE_L]; // 只在fire前保持next序号
	assign transaction_color_ir_o = flag_candidate_calibration ? state_current[B_CAL_FRAME_COLOR] : flag_candidate_ir; // owner颜色顺序
	assign transaction_frame_type_o = flag_candidate_calibration ? state_current[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] : FRAME_TYPE_NORMAL; // owner候选优先采用校准请求类别，普通候选固定NORMAL
	assign transaction_amb_code_o = flag_candidate_calibration ? state_current[B_CAL_WAVE_AMB_H:B_CAL_WAVE_AMB_L] : state_current[B_FRAME_AMB_H:B_FRAME_AMB_L]; // owner AMB快照
	assign transaction_dc_code_o = flag_candidate_calibration ? state_current[B_CAL_WAVE_DC_H:B_CAL_WAVE_DC_L] : (flag_candidate_ir ? state_current[B_FRAME_DCIR_H:B_FRAME_DCIR_L] : state_current[B_FRAME_DCR_H:B_FRAME_DCR_L]); // owner颜色DC快照
	assign transaction_amb_epoch_o = flag_candidate_calibration ? state_current[B_CAL_WAVE_AMB_EPOCH_H:B_CAL_WAVE_AMB_EPOCH_L] : state_current[B_FRAME_AMB_EPOCH_H:B_FRAME_AMB_EPOCH_L]; // owner AMB版本
	assign transaction_dc_epoch_o = flag_candidate_calibration ? state_current[B_CAL_WAVE_DC_EPOCH_H:B_CAL_WAVE_DC_EPOCH_L] : (flag_candidate_ir ? state_current[B_FRAME_DCIR_EPOCH_H:B_FRAME_DCIR_EPOCH_L] : state_current[B_FRAME_DCR_EPOCH_H:B_FRAME_DCR_EPOCH_L]); // owner DC版本

	//---------------输出信号连线---------------//
	//AMI校准请求
	//===================<输出桥接赋值>===================//
	assign o_calibration_sample_ready = calibration_sample_ready_o; // 输出校准请求ready

	//SSW模拟波形上下文
	assign o_waveform_context_valid = waveform_context_valid_o; // 输出波形valid
	assign o_waveform_precision_mode = waveform_precision_mode_o; // 输出波形精度
	assign o_waveform_frame_id = waveform_frame_id_o; // 输出波形帧号
	assign o_waveform_color_ir = waveform_color_ir_o; // 输出波形颜色
	assign o_waveform_frame_type = waveform_frame_type_o; // 输出波形类型
	assign o_waveform_amb_code_snapshot = waveform_amb_code_snapshot_o; // 输出波形AMB码
	assign o_waveform_dc_code_snapshot = waveform_dc_code_snapshot_o; // 将内部颜色DC快照桥接到SSW的显式输出端口
	assign o_waveform_amb_code_epoch = waveform_amb_code_epoch_o; // 输出波形AMB版本
	assign o_waveform_dc_code_epoch = waveform_dc_code_epoch_o; // 将内部颜色DC epoch桥接到SSW的显式输出端口
	assign o_waveform_input_source = waveform_input_source_o; // 输出波形输入来源
	assign o_waveform_optical_mode = waveform_optical_mode_o; // 输出波形光学模式
	assign o_waveform_leddac_code_snapshot = waveform_leddac_code_snapshot_o; // 把本帧锁存的LED RDAC码作为波形载荷对外提交

	//AMI ADC结果事务
	assign o_transaction_start_valid = transaction_start_valid_o; // 输出AMI事务valid
	assign o_transaction_precision_mode = transaction_precision_mode_o; // 输出事务精度
	assign o_transaction_frame_id = transaction_frame_id_o; // 输出事务帧号
	assign o_transaction_sample_index = transaction_sample_index_o; // 输出事务序号
	assign o_transaction_color_ir = transaction_color_ir_o; // 输出事务颜色
	assign o_transaction_frame_type = transaction_frame_type_o; // 输出事务类型
	assign o_transaction_amb_code_snapshot = transaction_amb_code_o; // 输出事务AMB码
	assign o_transaction_dc_code_snapshot = transaction_dc_code_o; // 将AMI owner内部颜色DC码桥接到结果事务端口
	assign o_transaction_amb_code_epoch = transaction_amb_epoch_o; // 输出事务AMB版本
	assign o_transaction_dc_code_epoch = transaction_dc_epoch_o; // 将AMI owner内部颜色DC版本桥接到结果事务端口

	//SSW owner与物理完成
	assign o_adc_owner_commit_event = adc_owner_commit_event_o; // 输出SSW owner原子提交
	assign o_adc_owner_precision_mode = transaction_precision_mode_o; // 输出owner精度
	assign o_adc_owner_frame_id = transaction_frame_id_o; // 输出owner帧号
	assign o_adc_owner_color_ir = transaction_color_ir_o; // 输出owner颜色
	assign o_adc_owner_frame_type = transaction_frame_type_o; // 输出owner类型
	assign o_adc_owner_amb_code_snapshot = transaction_amb_code_o; // 输出owner AMB码
	assign o_adc_owner_dc_code_snapshot = transaction_dc_code_o; // 输出owner DC码
	assign o_adc_owner_amb_code_epoch = transaction_amb_epoch_o; // 输出owner AMB版本
	assign o_adc_owner_dc_code_epoch = transaction_dc_epoch_o; // 向SSW发布与owner DC码同步的提交版本号
	assign o_adc_owner_sample_index = transaction_sample_index_o; // 输出owner正式序号

	//时间与完成事件
	assign o_macro_frame_start_event = state_current[B_MACRO_START]; // 输出宏帧起点单拍
	assign o_macro_frame_safe_boundary = macro_frame_safe_boundary_o; // 输出宏帧安全边界
	assign o_idac_code_safe_boundary = idac_code_safe_boundary_o; // 输出IDAC合并安全边界
	assign o_startup_idac_safe_boundary = startup_idac_safe_boundary_o; // 输出START专用边界；START后首帧前仅一次，无ADC/宏帧/索引消费 @satisfies: TOP-11
	assign o_safe_frame_id = current_frame_id_o + {{(C_FRAME_ID_WIDTH - 1){1'b0}}, 1'b1}; // 输出下一帧编号
	assign o_macro_tick = macro_tick_o;         // 输出宏帧相位
	assign o_calibration_subframe_index = calibration_subframe_index_o; // 输出校准子帧编号
	assign o_calibration_local_tick = calibration_local_tick_o; // 输出校准局部相位
	assign o_normal_frame_complete_event = state_current[B_NORMAL_COMPLETE]; // 输出NORMAL完成
	assign o_calibration_frame_complete_event = state_current[B_CAL_COMPLETE]; // 输出校准物理完成

	//状态与诊断
	assign o_scheduler_idle = !state_current[B_FRAME_ACTIVE] && !state_current[B_STARTUP_PENDING] && !state_current[B_CAL_REQ_ACTIVE] && !state_current[B_RED_WAVE_PENDING] && !state_current[B_IR_WAVE_PENDING] && !state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT] && i_adc_idle && i_analog_safe && i_sar_timing_idle; // 输出全链路idle
	assign o_normal_frame_active = state_current[B_FRAME_ACTIVE] && (dec_frame_mode == FRAME_MODE_NORMAL); // 输出NORMAL活动
	assign o_calibration_frame_active = state_current[B_FRAME_ACTIVE] && (dec_frame_mode == FRAME_MODE_CAL); // 输出校准活动
	assign o_transaction_inflight = state_current[B_INFLIGHT]; // 输出ADC owner在途
	assign o_current_frame_id = current_frame_id_o; // 输出当前frame_id
	assign o_next_sample_index = state_current[B_NEXT_SAMPLE_H:B_NEXT_SAMPLE_L]; // 输出下一sample index
	assign o_launch_timeout_sticky = state_current[B_LAUNCH_TIMEOUT]; // 输出波形超时sticky
	assign o_owner_deadline_timeout_sticky = state_current[B_OWNER_DEADLINE_TIMEOUT]; // 输出owner超时sticky
	assign o_cal_owner_deadline_event = flag_cal_owner_deadline; // 直接转发已有的单周期截止脉冲，自身在B_CAL_WAVE_PENDING清零的同一拍自动回落，无需额外锁存；SID-05 供AMI据此在deadline抑制后重新发起同一候选的请求，修复永久死锁 @satisfies: SID-05
	assign o_completion_mismatch_sticky = state_current[B_COMPLETION_MISMATCH]; // 输出DONE错配sticky
	assign o_protocol_error_sticky = state_current[B_PROTOCOL_ERROR]; // 输出协议sticky
	assign o_scheduler_local_fault_blocking = scheduler_local_fault_blocking_o; // 仅输出本地协议和身份阻断

	//故障记录接口
	assign o_scheduler_fault_valid = state_current[B_SCHED_FAULT_VALID]; // 输出新故障episode单周期脉冲
	assign o_scheduler_fault_active = scheduler_local_fault_blocking_o; // 输出注册式阻断持续状态
	assign o_scheduler_fault_cause = scheduler_fault_cause_o; // 输出固定原因码
	assign o_scheduler_fault_identity_valid = state_current[B_SCHED_FAULT_IDENTITY_VALID]; // 输出身份是否可信
	assign o_scheduler_fault_frame_id = state_current[B_SCHED_FAULT_IDENTITY_VALID] ? state_current[B_SCHED_FAULT_FRAME_ID_H:B_SCHED_FAULT_FRAME_ID_L] : {C_FRAME_ID_WIDTH{1'b0}}; // 输出故障owner帧号，非法请求场景下无身份可报告因而归零
	assign o_scheduler_fault_sample_index = state_current[B_SCHED_FAULT_IDENTITY_VALID] ? state_current[B_SCHED_FAULT_SAMPLE_INDEX_H:B_SCHED_FAULT_SAMPLE_INDEX_L] : {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 输出故障owner全局序号，供supervisor与其它两路来源交叉核对
	assign o_scheduler_fault_color_ir = state_current[B_SCHED_FAULT_IDENTITY_VALID] && state_current[B_SCHED_FAULT_COLOR]; // 输出故障owner颜色，与AND门共享同一身份有效位
	assign o_scheduler_fault_frame_type = state_current[B_SCHED_FAULT_IDENTITY_VALID] ? state_current[B_SCHED_FAULT_FRAME_TYPE_H:B_SCHED_FAULT_FRAME_TYPE_L] : 2'b00; // 输出故障owner事务类型，区分NORMAL与校准来源
	assign o_scheduler_fault_precision_mode = state_current[B_SCHED_FAULT_IDENTITY_VALID] && state_current[B_SCHED_FAULT_PRECISION]; // 输出故障owner精度，校准owner固定读回SAR9
	assign o_scheduler_fault_run_generation = state_current[B_SCHED_FAULT_IDENTITY_VALID] ? state_current[B_SCHED_FAULT_GENERATION_H:B_SCHED_FAULT_GENERATION_L] : {C_RUN_GENERATION_WIDTH{1'b0}}; // 输出故障owner所属RUN代际，供supervisor判断是否跨代际

	//----------------状态机区域----------------//
	//===================<组合状态机>===================//
	always@(*)begin
		state_next = state_current;             // 默认保持所有生命周期和快照
		state_next[B_MACRO_START] = 1'b0;       // 宏帧起点脉冲默认清零
		state_next[B_NORMAL_COMPLETE] = 1'b0;   // NORMAL完成脉冲默认清零
		state_next[B_CAL_COMPLETE] = 1'b0;      // 校准完成脉冲默认清零
		state_next[B_SCHED_FAULT_VALID] = 1'b0; // 故障episode单周期脉冲默认清零
		if(i_start_ack_event == 1'b1)begin
			state_next = {STATE_WIDTH{1'b0}};   // START原子清除上一RUN所有权
			state_next[B_STARTED] = 1'b1;       // 建立新RUN生命周期
			state_next[B_STARTUP_PENDING] = 1'b1; // 建立一次性IDAC启动边界
		end else begin
			if(i_stop_ack_event == 1'b1 || i_control_abort_event == 1'b1 || i_run_enable == 1'b0)begin
				state_next[B_STARTED] = 1'b0;   // STOP或abort禁止未来新启动
				state_next[B_STOP_DRAIN] = 1'b1; // 保留排空生命周期
				state_next[B_STARTUP_PENDING] = 1'b0; // 撤销尚未发布的启动边界
				if(i_control_abort_event == 1'b1)begin
					state_next[B_FRAME_ACTIVE] = 1'b0; // abort立即撤销未完成宏帧上下文，与SSW侧i_control_abort_event立即失效旧波形同拍
					state_next[B_FRAME_MODE_H:B_FRAME_MODE_L] = FRAME_MODE_IDLE; // abort立即清除宏帧模式
				end
				// 纯STOP（无abort）本拍不强制清FRAME_ACTIVE/FRAME_MODE：SSW的flag_red/ir_context_valid
				// 只在i_control_abort_event或tick自然走到窗口末尾两条路径释放，不监听stop_ack本身；
				// 下方既有tick自然推进/宏帧末拍收尾路径会在真实走到MACRO_LAST_TICK后正确清零两者，
				// 期间CONTEXT_SEEN/WAVE_PENDING已经挡住任何新的波形接管或owner提交
				state_next[B_RED_CONTEXT_SEEN] = 1'b1; // 禁止迟到RED波形fire
				state_next[B_IR_CONTEXT_SEEN] = 1'b1; // STOP或abort后封闭IR接管点，拒绝迟到IR波形fire
				state_next[B_CAL_CONTEXT_SEEN] = 1'b1; // 禁止迟到校准波形fire
				state_next[B_RED_WAVE_PENDING] = 1'b0; // 撤销RED owner-pending
				state_next[B_IR_WAVE_PENDING] = 1'b0; // 撤销IR owner-pending
				state_next[B_CAL_WAVE_PENDING] = 1'b0; // 撤销校准owner-pending
				state_next[B_CAL_REQ_PENDING] = 1'b0; // 撤销未接受校准请求
				state_next[B_CAL_REQ_ACTIVE] = 1'b0; // 撤销当前校准重试
				if(state_current[B_INFLIGHT])begin
					state_next[B_INFLIGHT_DISCARD] = 1'b1; // 已启动owner转为受控丢弃
				end
			end
			if(startup_idac_safe_boundary_o == 1'b1)begin
				state_next[B_STARTUP_PENDING] = 1'b0; // START边界发布后只消费一次待发标志
			end
			if(i_diag_clear_event == 1'b1 && !state_current[B_FRAME_ACTIVE] && !state_current[B_INFLIGHT] && !state_current[B_RED_WAVE_PENDING] && !state_current[B_IR_WAVE_PENDING] && !state_current[B_CAL_WAVE_PENDING] && flag_external_fault == 1'b0)begin
				state_next[B_LAUNCH_TIMEOUT] = 1'b0; // 只清除历史波形超时
				state_next[B_OWNER_DEADLINE_TIMEOUT] = 1'b0; // 只清除历史owner超时
				state_next[B_COMPLETION_MISMATCH] = 1'b0; // 只清除历史DONE错配
				state_next[B_PROTOCOL_ERROR] = 1'b0; // 只清除历史协议错误
			end
			if(i_calibration_sample_valid == 1'b1 && flag_calibration_request_valid == 1'b0)begin
				state_next[B_PROTOCOL_ERROR] = 1'b1; // 拒绝非法校准精度或颜色
				if(!scheduler_local_fault_blocking_o)begin
					state_next[B_SCHED_FAULT_VALID] = 1'b1; // 校准请求校验失败首次跳变，向supervisor拉出一拍valid
					state_next[B_SCHED_FAULT_IDENTITY_VALID] = 1'b0; // 非法请求没有已建立的owner身份可报告
				end
			end
			if(i_start_ack_event == 1'b0 && (i_transaction_start_fire != adc_owner_commit_event_o))begin
				state_next[B_PROTOCOL_ERROR] = 1'b1; // AMI返回fire必须逐拍一致
				if(!scheduler_local_fault_blocking_o)begin
					state_next[B_SCHED_FAULT_VALID] = 1'b1; // AMI fire一致性检查失败首次跳变，向supervisor拉出一拍valid
					state_next[B_SCHED_FAULT_IDENTITY_VALID] = 1'b1; // 报告本次候选事务身份
					state_next[B_SCHED_FAULT_FRAME_ID_H:B_SCHED_FAULT_FRAME_ID_L] = current_frame_id_o; // 快照候选事务帧号
					state_next[B_SCHED_FAULT_SAMPLE_INDEX_H:B_SCHED_FAULT_SAMPLE_INDEX_L] = transaction_sample_index_o; // 快照候选事务序号
					state_next[B_SCHED_FAULT_COLOR] = transaction_color_ir_o; // 快照候选事务颜色
					state_next[B_SCHED_FAULT_FRAME_TYPE_H:B_SCHED_FAULT_FRAME_TYPE_L] = transaction_frame_type_o; // 快照候选事务类型
					state_next[B_SCHED_FAULT_PRECISION] = transaction_precision_mode_o; // 快照候选事务精度
					state_next[B_SCHED_FAULT_GENERATION_H:B_SCHED_FAULT_GENERATION_L] = i_run_generation; // 快照当前RUN代际
				end
			end
			if(flag_calibration_request_fire == 1'b1)begin
				state_next[B_CAL_CONTEXT_SEEN] = 1'b0; // 新请求到达时重新开放校准接管点
				state_next[B_CAL_REQ_PENDING] = 1'b1; // 接收一笔保持型校准请求
				state_next[B_CAL_REQ_TYPE_H:B_CAL_REQ_TYPE_L] = i_calibration_frame_type; // 锁存请求类型
				state_next[B_CAL_REQ_COLOR] = i_calibration_color_ir; // 锁存请求颜色
				state_next[B_CAL_REQ_REASON_H:B_CAL_REQ_REASON_L] = i_calibration_request_reason; // 锁存请求原因
			end
			if(flag_waveform_fire == 1'b1)begin
				if(flag_waveform_is_calibration == 1'b1)begin
					// 请求已转化为真实校准 waveform，释放保持型 pending 以允许下一笔请求。
					state_next[B_CAL_REQ_PENDING] = 1'b0; // 本次波形已接管请求载荷，清除保持型pending
				end
				if(flag_waveform_is_calibration == 1'b1)begin
					state_next[B_CAL_CONTEXT_SEEN] = 1'b1; // 校准波形上下文已经接管
					state_next[B_CAL_WAVE_PENDING] = 1'b1; // 建立校准owner-pending
					state_next[B_CAL_WAVE_AMB_H:B_CAL_WAVE_AMB_L] = i_amb_code; // 锁存本次AMB committed码
					state_next[B_CAL_WAVE_DC_H:B_CAL_WAVE_DC_L] = (state_current[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] == FRAME_TYPE_AMB) ? {C_IDAC_CODE_WIDTH{1'b0}} : (state_current[B_CAL_FRAME_COLOR] ? i_dcs_ir_code : i_dcs_r_code); // 锁存本次颜色DC码
					state_next[B_CAL_WAVE_AMB_EPOCH_H:B_CAL_WAVE_AMB_EPOCH_L] = i_amb_code_epoch; // 锁存AMB版本
					state_next[B_CAL_WAVE_DC_EPOCH_H:B_CAL_WAVE_DC_EPOCH_L] = (state_current[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] == FRAME_TYPE_AMB) ? {C_CODE_EPOCH_WIDTH{1'b0}} : (state_current[B_CAL_FRAME_COLOR] ? i_dcs_ir_code_epoch : i_dcs_r_code_epoch); // 锁存颜色DC版本
				end else if(flag_waveform_is_ir == 1'b1)begin
					state_next[B_IR_CONTEXT_SEEN] = 1'b1; // IR波形上下文已经接管
					state_next[B_IR_WAVE_PENDING] = 1'b1; // 建立IR owner-pending
				end else begin
					state_next[B_RED_CONTEXT_SEEN] = 1'b1; // RED waveform握手成功后，登记该颜色槽已经消耗其接管点
					state_next[B_RED_WAVE_PENDING] = 1'b1; // 建立RED owner-pending
				end
			end else begin
				if(flag_red_context_due == 1'b1)begin
					state_next[B_RED_CONTEXT_SEEN] = 1'b1; // RED错过接管点后禁止迟到fire
					state_next[B_LAUNCH_TIMEOUT] = 1'b1; // 记录RED波形接管超时
					state_next[B_FRAME_FAILED] = 1'b1; // 当前宏帧不再声明完整成功
				end
				if(flag_ir_context_due == 1'b1)begin
					state_next[B_IR_CONTEXT_SEEN] = 1'b1; // IR固定接管点未握手时，永久封闭本帧该颜色的重试机会
					state_next[B_LAUNCH_TIMEOUT] = 1'b1; // IR接管失败使waveform-launch诊断置位，便于区分RED失败
					state_next[B_FRAME_FAILED] = 1'b1; // IR波形没有在规定相位被接收，取消本宏帧成功完成资格
				end
				if(flag_cal_context_due == 1'b1)begin
					state_next[B_CAL_CONTEXT_SEEN] = 1'b1; // 校准错过接管点后保留请求重试
					state_next[B_LAUNCH_TIMEOUT] = 1'b1; // 记录校准波形接管超时
				end
			end
			if(adc_owner_commit_event_o == 1'b1)begin
				state_next[B_INFLIGHT] = 1'b1;  // 正式建立唯一ADC owner
				state_next[B_INFLIGHT_DISCARD] = 1'b0; // 新owner默认可计入结果
				state_next[B_INFLIGHT_SAMPLE_H:B_INFLIGHT_SAMPLE_L] = transaction_sample_index_o; // 首次绑定sample index
				state_next[B_INFLIGHT_TYPE_H:B_INFLIGHT_TYPE_L] = transaction_frame_type_o; // 锁存owner事务类型
				state_next[B_INFLIGHT_COLOR] = transaction_color_ir_o; // 锁存owner颜色
				state_next[B_INFLIGHT_GENERATION_H:B_INFLIGHT_GENERATION_L] = i_run_generation; // 原子锁存本次owner创建时刻的RUN代际，供后续DONE匹配校验
				state_next[B_NEXT_SAMPLE_H:B_NEXT_SAMPLE_L] = state_current[B_NEXT_SAMPLE_H:B_NEXT_SAMPLE_L] + {{(C_SAMPLE_INDEX_WIDTH - 1){1'b0}}, 1'b1}; // 仅真实fire后递增序号
				if(flag_candidate_calibration == 1'b1)begin
					state_next[B_CAL_WAVE_PENDING] = 1'b0; // 消费校准owner-pending
					// 校准宏帧可承载连续八个625-tick子周期；owner提交只消费当前波形，
					// 请求阶段活动资格保持到宏帧结束或生命周期取消。
					state_next[B_CAL_REQ_ACTIVE] = state_current[B_CAL_REQ_ACTIVE]; // 显式保持活动身份，不随单次owner提交清除
				end else if(flag_candidate_red == 1'b1)begin
					state_next[B_RED_WAVE_PENDING] = 1'b0; // 消费RED owner-pending
				end else begin
					state_next[B_IR_WAVE_PENDING] = 1'b0; // 消费IR owner-pending
				end
			end
			if(flag_completion_match == 1'b1)begin
				state_next[B_INFLIGHT] = 1'b0;  // 匹配DONE释放物理owner
				state_next[B_INFLIGHT_DISCARD] = 1'b0; // 释放最小身份后清除丢弃标志
				if(flag_completion_success == 1'b1 && (state_current[B_INFLIGHT_TYPE_H:B_INFLIGHT_TYPE_L] == FRAME_TYPE_NORMAL))begin
					if(state_current[B_INFLIGHT_COLOR])begin
						state_next[B_IR_DONE] = 1'b1; // 成功结果标记IR完成
					end else begin
						state_next[B_RED_DONE] = 1'b1; // 只将RED成功DONE转换为RED颜色结果完成位
					end
				end else if(i_adc_transaction_success == 1'b0 && !state_current[B_INFLIGHT_DISCARD])begin
					state_next[B_FRAME_FAILED] = 1'b1; // success=0只做失败收尾
				end
			end else if(i_adc_transaction_complete_event == 1'b1)begin
				state_next[B_COMPLETION_MISMATCH] = 1'b1; // 错配或无owner DONE不得消费新事务
				if(!scheduler_local_fault_blocking_o)begin
					state_next[B_SCHED_FAULT_VALID] = 1'b1; // DONE身份或代际错配首次跳变，向supervisor拉出一拍valid
					state_next[B_SCHED_FAULT_IDENTITY_VALID] = state_current[B_INFLIGHT]; // 仅在存在真实owner时报告身份
					state_next[B_SCHED_FAULT_FRAME_ID_H:B_SCHED_FAULT_FRAME_ID_L] = current_frame_id_o; // 快照当前owner所属帧号
					state_next[B_SCHED_FAULT_SAMPLE_INDEX_H:B_SCHED_FAULT_SAMPLE_INDEX_L] = state_current[B_INFLIGHT_SAMPLE_H:B_INFLIGHT_SAMPLE_L]; // 快照在途owner序号
					state_next[B_SCHED_FAULT_COLOR] = state_current[B_INFLIGHT_COLOR]; // 快照在途owner颜色
					state_next[B_SCHED_FAULT_FRAME_TYPE_H:B_SCHED_FAULT_FRAME_TYPE_L] = state_current[B_INFLIGHT_TYPE_H:B_INFLIGHT_TYPE_L]; // 快照在途owner类型
					state_next[B_SCHED_FAULT_PRECISION] = (state_current[B_INFLIGHT_TYPE_H:B_INFLIGHT_TYPE_L] == FRAME_TYPE_NORMAL) ? state_current[B_FRAME_PRECISION] : 1'b0; // 校准owner固定SAR9精度
					state_next[B_SCHED_FAULT_GENERATION_H:B_SCHED_FAULT_GENERATION_L] = state_current[B_INFLIGHT_GENERATION_H:B_INFLIGHT_GENERATION_L]; // 使用owner自身创建时锁存的RUN代际
				end
			end
			if(adc_owner_commit_event_o == 1'b0)begin
				if(flag_red_owner_deadline == 1'b1)begin
					state_next[B_RED_WAVE_PENDING] = 1'b0; // RED owner截止后抑制采样
					state_next[B_OWNER_DEADLINE_TIMEOUT] = 1'b1; // 记录RED owner截止；LFA-09/OIB-02 owner-deadline超时只置这个非阻断历史诊断位(未汇入417行scheduler_local_fault_blocking_o)，不产生阻断/abort/STOP/半提交owner @satisfies: LFA-09, OIB-02
					state_next[B_FRAME_FAILED] = 1'b1; // 当前宏帧失败收尾
				end
				if(flag_ir_owner_deadline == 1'b1)begin
					state_next[B_IR_WAVE_PENDING] = 1'b0; // IR owner超过截止相位仍未提交时撤销其待提交上下文
					state_next[B_OWNER_DEADLINE_TIMEOUT] = 1'b1; // IR等待ADC owner超时后锁存owner-deadline诊断
					state_next[B_FRAME_FAILED] = 1'b1; // IR owner未在443 tick前建立，使本帧不再满足完整结果条件
				end
				if(flag_cal_owner_deadline == 1'b1)begin
					state_next[B_CAL_WAVE_PENDING] = 1'b0; // 校准owner截止后等待下一子帧；SID-05 错过截止的候选窗口被直接抑制，不产生owner提交，不消费样本序号 @satisfies: SID-05
					state_next[B_OWNER_DEADLINE_TIMEOUT] = 1'b1; // 记录校准owner截止
				end
			end
			if(flag_frame_start_eligible == 1'b1)begin
				state_next[B_FRAME_ACTIVE] = 1'b1; // 建立新的400 Hz物理宏帧
				state_next[B_FRAME_MODE_H:B_FRAME_MODE_L] = state_current[B_CAL_REQ_PENDING] ? FRAME_MODE_CAL : FRAME_MODE_NORMAL; // 校准优先于NORMAL
				state_next[B_FRAME_OPTICAL_H:B_FRAME_OPTICAL_L] = i_optical_mode; // 锁存光学模式
				state_next[B_FRAME_PRECISION] = state_current[B_CAL_REQ_PENDING] ? 1'b0 : i_active_precision_mode; // NORMAL新帧从active配置冻结精度，校准帧则强制写入SAR9；TOP-13/14/15三种场景共用同一精度冻结寄存器，本行是唯一锚点，三者未在RTL层面拆分为独立分支(见别名映射表说明)；ILM-03 MANUAL/CHARACTERIZATION下无自动搜索/重检触发精度切换，i_active_precision_mode保持SAR15，每帧原样重锁存，全程不发生精度窗口切换 @satisfies: TOP-13, TOP-14, TOP-15, ILM-03
				state_next[B_FRAME_INPUT_SOURCE] = i_input_source; // 锁存输入来源
				state_next[B_MACRO_TICK_H:B_MACRO_TICK_L] = {C_MACRO_TICK_WIDTH{1'b0}}; // 宏帧从tick 0开始
				state_next[B_CAL_SUB_H:B_CAL_SUB_L] = 3'd0; // 校准子周期从0开始
				state_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = {C_CAL_TICK_WIDTH{1'b0}}; // 校准局部相位从0开始
				state_next[B_RED_REQUIRED] = (i_optical_mode == OPTICAL_BOTH) || (i_optical_mode == OPTICAL_RED); // 锁存RED资格
				state_next[B_IR_REQUIRED] = (i_optical_mode == OPTICAL_BOTH) || (i_optical_mode == OPTICAL_IR); // 根据锁存光学模式单独写入IR颜色槽的存在资格
				state_next[B_RED_DONE] = 1'b0;  // 清除RED完成状态
				state_next[B_IR_DONE] = 1'b0;   // 新帧初始化时专门清除上一次IR结果完成标志
				state_next[B_FRAME_FAILED] = 1'b0; // 清除上一帧失败状态
				state_next[B_RED_CONTEXT_SEEN] = 1'b0; // 允许新的RED接管
				state_next[B_IR_CONTEXT_SEEN] = 1'b0; // 新帧开放IR固定接管点，允许随后一次合法波形发布
				state_next[B_CAL_CONTEXT_SEEN] = 1'b0; // 允许新的校准接管
				state_next[B_RED_WAVE_PENDING] = 1'b0; // 清除旧RED owner-pending
				state_next[B_IR_WAVE_PENDING] = 1'b0; // 清除旧IR owner-pending
				state_next[B_CAL_WAVE_PENDING] = 1'b0; // 清除旧校准owner-pending
				state_next[B_MACRO_START] = 1'b1; // 把宏帧起点脉冲写入状态向量供外部时基观察
				state_next[B_FRAME_AMB_H:B_FRAME_AMB_L] = i_amb_code; // 锁存AMB committed码
				state_next[B_FRAME_DCR_H:B_FRAME_DCR_L] = i_dcs_r_code; // 锁存RED DC committed码
				state_next[B_FRAME_DCIR_H:B_FRAME_DCIR_L] = i_dcs_ir_code; // 锁存IR DC committed码
				state_next[B_FRAME_AMB_EPOCH_H:B_FRAME_AMB_EPOCH_L] = i_amb_code_epoch; // 为即将开始的宏帧冻结公共AMB码对应的版本号
				state_next[B_FRAME_DCR_EPOCH_H:B_FRAME_DCR_EPOCH_L] = i_dcs_r_code_epoch; // 把RED DC提交epoch复制到该帧专用颜色快照；OIB-09要求的"新宏帧建立前已接受的事务保留旧快照，只有下一笔新接受事务才用新完整快照，不出现混合epoch"，正是靠这个每帧一次性锁存(而非持续跟踪IDAC控制器自己活的epoch寄存器)实现 @satisfies: OIB-09
				state_next[B_FRAME_DCIR_EPOCH_H:B_FRAME_DCIR_EPOCH_L] = i_dcs_ir_code_epoch; // 将IR DC提交epoch复制到该帧专用颜色快照，并与RED版本分离保存
				state_next[B_FRAME_LEDDAC_R_H:B_FRAME_LEDDAC_R_L] = i_leddac_r_code; // 锁存RED LEDDAC
				state_next[B_FRAME_LEDDAC_IR_H:B_FRAME_LEDDAC_IR_L] = i_leddac_ir_code; // 锁存IR LEDDAC
				state_next[B_CAL_CONTEXT_SEEN] = (state_current[B_CAL_REQ_PENDING] || flag_calibration_request_fire) ? 1'b0 : 1'b1; // 新帧有待处理校准请求时立即开放接管点，否则先行封闭
				if(state_current[B_CAL_REQ_PENDING])begin
					state_next[B_CAL_REQ_PENDING] = 1'b0; // 消费一笔校准请求载荷
					state_next[B_CAL_REQ_ACTIVE] = 1'b1; // 允许波形或owner失败后重试
					state_next[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] = state_current[B_CAL_REQ_TYPE_H:B_CAL_REQ_TYPE_L]; // 锁存校准类型
					state_next[B_CAL_FRAME_COLOR] = state_current[B_CAL_REQ_COLOR]; // 锁存校准颜色
					state_next[B_CAL_FRAME_REASON_H:B_CAL_FRAME_REASON_L] = state_current[B_CAL_REQ_REASON_H:B_CAL_REQ_REASON_L]; // 锁存校准原因
				end else begin
					state_next[B_CAL_REQ_ACTIVE] = 1'b0; // NORMAL帧无校准重试
				end
			end
			if(state_current[B_FRAME_ACTIVE])begin
				if(dec_frame_mode == FRAME_MODE_CAL && (calibration_local_tick_o == CAL_LAST_LOCAL_TICK) && state_current[B_CAL_REQ_ACTIVE] && !state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT])begin
					state_next[B_CAL_CONTEXT_SEEN] = (state_current[B_CAL_REQ_PENDING] || flag_calibration_request_fire) ? 1'b0 : 1'b1; // 历史遗留候选赋值，结果被下一行无条件覆盖，保留原位置避免改变代码结构
					state_next[B_CAL_CONTEXT_SEEN] = 1'b0; // 下一个625-tick校准子帧重新开放上下文
					if(!state_current[B_CAL_REQ_PENDING] && !flag_calibration_request_fire)begin
						// 没有新的保持型请求时锁住上下文，防止后续子帧重复发波形。
						state_next[B_CAL_CONTEXT_SEEN] = 1'b1; // 无新请求时收回刚开放的接管点
					end
					if(state_current[B_CAL_REQ_PENDING])begin
						// 同一物理校准宏帧内消费下一笔请求；宏帧结束才走跨帧保留路径。
						state_next[B_CAL_REQ_PENDING] = 1'b0; // 尝试消费本次保持型请求快照，是否真正消费由下方保留逻辑最终裁定
						state_next[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] = state_current[B_CAL_REQ_TYPE_H:B_CAL_REQ_TYPE_L]; // 锁存下一子帧校准类型
						state_next[B_CAL_FRAME_COLOR] = state_current[B_CAL_REQ_COLOR]; // 锁存下一子帧校准颜色
						state_next[B_CAL_FRAME_REASON_H:B_CAL_FRAME_REASON_L] = state_current[B_CAL_REQ_REASON_H:B_CAL_REQ_REASON_L]; // 锁存下一子帧校准原因
					end
					// 保持请求直到对应子帧真正产生 waveform；原始 pending 只在边界被消费会丢失后续上下文资格。
					if(state_current[B_CAL_REQ_PENDING])begin
						state_next[B_CAL_REQ_PENDING] = 1'b1; // 覆盖上方尝试性消费，确保pending跨子帧保留直到真正产生waveform
					end
				end
			if(macro_tick_o == MACRO_LAST_TICK)begin
					if((dec_frame_mode == FRAME_MODE_NORMAL) && (dec_frame_optical_mode != OPTICAL_OFF) && !state_current[B_FRAME_FAILED] && ((!state_current[B_RED_REQUIRED] || state_current[B_RED_DONE]) && (!state_current[B_IR_REQUIRED] || state_current[B_IR_DONE])))begin
						state_next[B_NORMAL_COMPLETE] = 1'b1; // 仅完整成功NORMAL帧输出一次
					end
					if(dec_frame_mode == FRAME_MODE_CAL)begin
						state_next[B_CAL_COMPLETE] = 1'b1; // 输出物理校准宏帧完成
						if(state_current[B_CAL_REQ_ACTIVE])begin
							if(state_current[B_CAL_REQ_PENDING] || state_current[B_CAL_WAVE_PENDING] || state_current[B_INFLIGHT])begin
								state_next[B_CAL_REQ_PENDING] = 1'b1; // 未成功提交的请求跨宏帧保留
							end
							state_next[B_CAL_REQ_ACTIVE] = 1'b0; // 重新进入请求等待
						end
					end
					state_next[B_FRAME_ACTIVE] = 1'b0; // 当前宏帧结束
					state_next[B_FRAME_MODE_H:B_FRAME_MODE_L] = FRAME_MODE_IDLE; // 释放宏帧模式
					state_next[B_FRAME_ID_H:B_FRAME_ID_L] = current_frame_id_o + {{(C_FRAME_ID_WIDTH - 1){1'b0}}, 1'b1}; // 真实宏帧边界递增frame_id
					state_next[B_MACRO_TICK_H:B_MACRO_TICK_L] = {C_MACRO_TICK_WIDTH{1'b0}}; // 下一帧重新从tick 0开始
					state_next[B_CAL_SUB_H:B_CAL_SUB_L] = 3'd0; // 清除校准子帧编号
					state_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = {C_CAL_TICK_WIDTH{1'b0}}; // 清除校准局部相位
					state_next[B_RED_CONTEXT_SEEN] = 1'b1; // 结束后禁止迟到RED上下文
					state_next[B_IR_CONTEXT_SEEN] = 1'b1; // 宏帧结束后封锁IR波形通道，避免下一帧前出现越界接管
					state_next[B_CAL_CONTEXT_SEEN] = 1'b1; // 结束后禁止迟到校准上下文
					state_next[B_RED_WAVE_PENDING] = 1'b0; // 结束后清除RED pending
					state_next[B_IR_WAVE_PENDING] = 1'b0; // 宏帧结束时清空未消费的IR波形候选，禁止跨帧owner提交
					state_next[B_CAL_WAVE_PENDING] = 1'b0; // 结束后清除校准 pending
				end else begin
					state_next[B_MACRO_TICK_H:B_MACRO_TICK_L] = macro_tick_o + {{(C_MACRO_TICK_WIDTH - 1){1'b0}}, 1'b1}; // 推进宏帧相位
					if(calibration_local_tick_o == CAL_LAST_LOCAL_TICK)begin
						state_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = {C_CAL_TICK_WIDTH{1'b0}}; // 校准局部相位自然回零；SID-04 每625 tick(C_CAL_SUBFRAME_TICKS)本地相位归零，与下面逐拍递增共同保证相邻物理子帧Q3中心严格625 tick等距 @satisfies: SID-04
						state_next[B_CAL_SUB_H:B_CAL_SUB_L] = calibration_subframe_index_o + 3'd1; // 校准子周期自然递增
					end else begin
						state_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = calibration_local_tick_o + {{(C_CAL_TICK_WIDTH - 1){1'b0}}, 1'b1}; // 推进校准局部相位
					end
				end
			end
		end
	end

	//----------------状态任务处理区域----------------//
	//===================<状态寄存器>===================//
	// 在主FSM计算的state_next之上叠加校准子帧滚动覆盖，避免宏帧末拍与下一子帧起点之间出现空拍
	always @* begin
		state_rollover_next = state_next;             // 默认沿用主FSM的下一拍状态
		if(flag_calibration_rollover)begin
			state_rollover_next[B_CAL_COMPLETE] = 1'b1; // 滚动路径同样上报物理宏帧完成
			state_rollover_next[B_FRAME_ACTIVE] = 1'b1; // 不经过IDLE直接进入下一校准子帧
			state_rollover_next[B_FRAME_MODE_H:B_FRAME_MODE_L] = FRAME_MODE_CAL; // 下一子帧固定仍为校准模式
			state_rollover_next[B_FRAME_ID_H:B_FRAME_ID_L] = current_frame_id_o + {{(C_FRAME_ID_WIDTH - 1){1'b0}}, 1'b1}; // 宏帧编号照常递增
			state_rollover_next[B_MACRO_TICK_H:B_MACRO_TICK_L] = {C_MACRO_TICK_WIDTH{1'b0}}; // 宏帧相位重新从tick 0开始
			state_rollover_next[B_CAL_SUB_H:B_CAL_SUB_L] = 3'd0; // 校准子周期编号回零
			state_rollover_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = {C_CAL_TICK_WIDTH{1'b0}}; // 校准局部相位回零
			state_rollover_next[B_CAL_CONTEXT_SEEN] = 1'b0; // 下一子帧重新开放波形接管点
			state_rollover_next[B_CAL_REQ_ACTIVE] = 1'b1; // 保持校准请求活动身份跨子帧连续
		if(state_current[B_CAL_REQ_PENDING] == 1'b1)begin
				state_rollover_next[B_CAL_REQ_PENDING] = 1'b0; // 消费已接受的保持型请求载荷
				state_rollover_next[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] = state_current[B_CAL_REQ_TYPE_H:B_CAL_REQ_TYPE_L]; // 滚动路径把请求快照类型转交给紧接着的下一子帧
				state_rollover_next[B_CAL_FRAME_COLOR] = state_current[B_CAL_REQ_COLOR]; // 滚动路径把请求快照颜色转交给紧接着的下一子帧
				state_rollover_next[B_CAL_FRAME_REASON_H:B_CAL_FRAME_REASON_L] = state_current[B_CAL_REQ_REASON_H:B_CAL_REQ_REASON_L]; // 滚动路径把请求快照原因转交给紧接着的下一子帧
		end
	end
	end

	//----------------状态机区域----------------//
	// 2 MHz主时钟异步置低、同步释放，原子提交叠加校准滚动覆盖后的最终下一拍状态
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= {STATE_WIDTH{1'b0}}; // 异步复位清除全部事务和诊断；LFA-05复位立即使B_INFLIGHT等owner身份字段全部归零 @satisfies: LFA-05
		end else begin
			state_current <= state_rollover_next; // 2 MHz时钟沿原子提交下一状态
		end
	end

endmodule
