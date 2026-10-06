`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/07/23
// Design Name:        PPG IDAC Code Controller
// Module Name:        ppg_idac_code_controller
// Description:        Description/ppg_idac_code_controller_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_idac_code_controller
//
// Referrences:        PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md,
//                     PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// Dependencies:       None
//
// Version:            V2.4
// Revision Date:      2026/10/06
// History:
//    Time               Version       Revised by            Contents
// 2026/07/23            V1.0          Erie                  Create file.
// 2026/08/07            V2.0          Erie                  Rebuild three-code search and tracking controller.
// 2026/08/08            V2.1          Erie                  Fix periodic AMB-R-IR revalidation sequence.
// 2026/08/22            V2.2          Erie                  Add i_run_generation with atomic pending-candidate tagging and stale-generation commit rejection, and add the registered o_controller_fault_event/identity_valid/<FAULT_ID> group for the AMI fault dispatcher, per PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md V2.2.
// 2026/08/29            V2.3          Erie                  Fix a real cross-module deadlock discovered while building Stage 5 Group 8 (PERIODIC-RECHECK-RECOVERY, C25 contract section 9.4.3): CTX_AMB_FAULT_BIT/CTX_DCS_R_FAULT_BIT/CTX_DCS_IR_FAULT_BIT (o_amb_fault/o_dcs_r_fault/o_dcs_ir_fault, ORed into o_controller_fault_blocking) were previously cleared only inside the i_start_ack_event block -- but per PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md section 11.3 (line 546) they must instead be revoked once STOP/abort terminates the action and local o_idac_idle=1 with the active root cause gone (or by async reset), and section 11.3 (lines 296-297) / conformance ID IDC2-23 (line 662) explicitly state a fresh START must NOT clear active or historical blocking faults. The RTL had this backwards, which is a real, reproducible deadlock, not just a contract-wording nitpick: o_controller_fault_blocking feeds AMI's o_ami_fault_active (ppg_adc_measurement_idac_integration.v line 1127/2404), which feeds ppg_system_fault_abort_supervisor.v's flag_local_actives_low / flag_episode_close_condition (o_system_fault_blocking only clears once all three lane-actives are low), which feeds ppg_system_config_manager.v's flag_start_ready (i_system_fault_blocking must be 0 for START to be accepted, per that module's own line-77 port comment "拒绝START且不能被本地清除"). So once a real AMB/DC_R/DC_IR search exhaustion sets the fault bit, no fresh i_start_ack_event can ever be generated to clear it -- confirmed by a real xsim run (Group 8's tb_ppg_control_top_periodic_recheck_recovery.v forcing a genuine DC_R search exhaustion via a persistent one-directional excursion) that got stuck with o_start_ready=0/o_system_fault_blocking=1/o_controller_fault_blocking=1 indefinitely after a full STOP+drain+i_diag_clear_event sequence (i_diag_clear_event cannot help either: the supervisor's own flag_diag_clear_legal at line 200 explicitly requires !system_fault_blocking_o already, so it cannot force-close an open episode). Fixed by moving the three FAULT-bit clears from the i_start_ack_event block into the flag_control_cancel block (STOP/abort/leave-RUN, which already atomically clears the corresponding pending/origin context in the same cycle and forces state_next to ST_IDLE unconditionally, so o_idac_idle settles true immediately after -- satisfying the contract's "STOP/abort + idle + root cause gone" condition in one atomic step, consistent with how the sibling EXHAUSTED bits were already being cleared there) and removing the old clear from the START block entirely (leaving intact the separate, legitimate case where an illegal START -- disabled run_enable or invalid config -- newly SETS these bits itself; the contract forbids START from clearing a pre-existing fault, not from raising its own). Verified: (1) the fixed joint TB (tb_ppg_control_top_periodic_recheck_recovery.v) now runs a full RUN2 after the RRC-11 DC_R-exhaustion episode and gets a real, clean COMMIT/START, with all twelve RRC-01~12 IDs passing under real Vivado 2022.2 xsim; (2) a real A/B diff of ppg_idac_code_controller's own unit-level tb_ppg_idac_code_controller.v (iverilog) before and after this fix produced byte-for-byte identical output including its pre-existing 33 failures -- confirming those 33 failures are a pre-existing V2.1-vs-current-RTL staleness in that unit TB (it prints its own "V2.1 regression" label), completely unrelated to and unaffected by this fix, and that this fix introduces zero behavior change in every scenario that unit TB currently exercises; (3) tb_ppg_control_top_startup_idac_calibration.v and tb_ppg_control_top_normal_slow_tracking.v (Stage 5 Group 6/7, whose own already-passing runs never exercise a STOP/re-START after a real controller fault) still compile cleanly against the fixed RTL with zero structural changes.
// 2026/10/06            V2.4          Erie                  ABCD review F-032: rename input port i_status_clear_event to i_diag_clear_event, matching contract C17 and the actual source (AMI connects the Top registered diag_clear, not the manager-local status_clear, which is a different event). Edited in place on the declaration and the one use; behaviour unchanged.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年07月23日
// 设计名称:           PPG IDAC码值控制器
// 模块名称:           ppg_idac_code_controller
// 模块说明:           Description/ppg_idac_code_controller_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_idac_code_controller
//
// 参考资料:           PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md、
//                     PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// 依赖文件:           无
//
// 当前版本:           V2.4
// 修订日期:           2026年10月06日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年07月23日        V1.0          Erie                  创建文件。
// 2026年08月07日        V2.0          Erie                  重构三路码搜索、重检及慢速跟踪架构。
// 2026年08月08日        V2.1          Erie                  固定周期AMB、红光DC及红外DC重验证顺序。
// 2026年08月22日        V2.2          Erie                  按合同V2.2新增i_run_generation，对pending候选原子锁存并在提交时校验代际；新增注册式o_controller_fault_event/identity_valid/<FAULT_ID>组供AMI故障分发器观测。
// 2026年08月29日        V2.3          Erie                  修复Stage 5 Group 8（PERIODIC-RECHECK-RECOVERY，C25合同9.4.3节）开工时真实发现的一个跨模块死锁：CTX_AMB_FAULT_BIT/CTX_DCS_R_FAULT_BIT/CTX_DCS_IR_FAULT_BIT（o_amb_fault/o_dcs_r_fault/o_dcs_ir_fault，汇总成o_controller_fault_blocking）此前只在i_start_ack_event那一拍被清零——但PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md 11.3节（546行）明确规定它们只应在STOP/abort终止动作使本地o_idac_idle=1且活动根因消失后撤销（或由异步复位撤销），且11.3节（296-297行）/一致性条款IDC2-23（662行）明确规定新START不得清除活动或历史阻断故障。原实现正好做反了，这不是文字措辞问题，是一个真实、可复现的死锁：o_controller_fault_blocking接入AMI的o_ami_fault_active（ppg_adc_measurement_idac_integration.v 1127/2404行），再接入ppg_system_fault_abort_supervisor.v的flag_local_actives_low/flag_episode_close_condition（o_system_fault_blocking只在三路lane-active全部为低后才清零），再接入ppg_system_config_manager.v的flag_start_ready（该模块自己77行的端口注释就写着i_system_fault_blocking"拒绝START且不能被本地清除"）——一旦真实AMB/DC_R/DC_IR搜索耗尽置位故障，就再也生成不了新的i_start_ack_event去清除它。真实xsim confirmed（Group8的tb_ppg_control_top_periodic_recheck_recovery.v用持续单方向漂移真实逼出一次DC_R搜索耗尽）：完整STOP+drain+i_diag_clear_event之后，o_start_ready=0/o_system_fault_blocking=1/o_controller_fault_blocking=1永久卡住不变——i_diag_clear_event同样救不了，supervisor自己的flag_diag_clear_legal（200行）明确要求episode已经关闭（!system_fault_blocking_o）才算合法，不能强行关闭一个还开着的episode。修复为把三个FAULT位的清零从i_start_ack_event块搬到flag_control_cancel块（STOP/abort/离开RUN，本来就已经在同一拍原子撤销对应pending/origin上下文并无条件把state_next拉回ST_IDLE，下一拍o_idac_idle即可读到真——一步到位满足合同"STOP/abort+idle+根因消失"三个条件，和同一个块里本来就这样处理的EXHAUSTED伴随位手法一致），并把START块里旧的清零整段删除（非法START——run_enable禁用或配置非法——仍然保留原样置1这三个位的独立分支，合同禁止的是START清除既有故障，不是START自己新建故障）。已验证：（1）修复后的联合TB在RRC-11 DC_R耗尽episode之后真实跑通RUN2的COMMIT/START，Group8全部十二条RRC-01~12在真实Vivado 2022.2 xsim下PASS；（2）用iverilog对`tb_ppg_idac_code_controller.v`自己的单元级TB做了修复前后的真实A/B逐字节diff，输出完全一致（含它自己既有的33个失败，结尾自己也报"V2.1 regression"，确认这是该单元TB自身早就没跟V2.2同步的历史遗留问题，和本次修复无关，本次修复对它已覆盖的全部场景零行为变化）；（3）`tb_ppg_control_top_startup_idac_calibration.v`和`tb_ppg_control_top_normal_slow_tracking.v`（Stage5 Group6/7，两者自己已经通过的场景都从未在真实控制器故障后尝试STOP+重新START）对着修复后的RTL依然干净编译，零结构性改动。
// 2026年10月06日        V2.4          Erie                  ABCD复核F-032：输入端口i_status_clear_event改名为i_diag_clear_event，与合同C17及实际来源一致（AMI接的是Top注册式diag_clear，不是manager本地status_clear，二者是不同事件）。声明与唯一使用处原行修改，行为不变

// 统一管理AMB、红光DCS和红外DCS三组逻辑码，并在安全帧边界提交搜索或慢速跟踪候选
module ppg_idac_code_controller
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16, // R/IR共享采样帧编号字段宽度
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16, // 全局ADC事务顺序编号字段宽度
	parameter integer C_IDAC_CODE_WIDTH = 32'd8, // 三组逻辑IDAC码及快照字段宽度
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4, // 每路安全提交版本标签字段宽度
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8, // 完整ACTIVE配置版本标签字段宽度
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8, // Stage1系数组诊断版本字段宽度
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8, // manager唯一产生、AMI逐层传入的RUN代际字段宽度；本模块自身声明,与AMI父级等宽由构造保证 @satisfies: K03
	parameter [C_IDAC_CODE_WIDTH - 1:0]C_RESET_CODE = {C_IDAC_CODE_WIDTH{1'b0}}, // 复位和禁用路径使用的安全数字码
	parameter integer C_ENABLE_TEST_INJECTION = 32'd0 // 默认关闭的验证专用饱和注入结构生成使能，生产网表必须为0
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz数字控制与事务处理时钟
	input i_rstn,                           // 低有效异步复位且释放由系统上层同步
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // manager经AMI逐层传入的当前RUN代际，陈旧代际不得建立pending或改变committed码

	//-----------生命周期控制接口-----------//
	input i_run_enable,                     // 配置管理器仅在RUN状态给出的功能许可
	input i_start_ack_event,                // 合法START被接受后产生的单周期初始化事件
	input i_stop_ack_event,                 // STOP进入排空流程时产生的单周期取消事件
	input i_diag_clear_event,               // 清除非阻断协议诊断的独立状态命令
	input i_control_abort_event,            // 配置或调度阻断错误要求取消临时动作
	input i_frame_safe_boundary,            // 当前时钟沿允许提交一个或多个pending码
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_active_config_epoch, // 当前稳定ACTIVE V4快照版本

	//------------ACTIVE配置接口------------//
	input [1:0]i_idac_mode,                 // 选择MANUAL、搜索保持或搜索跟踪模式
	input i_amb_enable,                     // 授权AMB逻辑码参与当前运行上下文
	input i_dcs_enable,                     // 授权红光与红外DCS共同参与运行
	input i_amb_polarity,                   // 映射AMB残差方向到码值增减方向
	input i_dcs_polarity,                   // 映射颜色DC残差方向到1 LSB调码方向
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_manual_code, // MANUAL模式环境光抵消目标码
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_min, // AMB自动控制允许使用的闭区间下界
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_max, // AMB自动控制允许使用的闭区间上界
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_manual_code, // 红光DCS手动模式装载码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code_min, // 红光DCS搜索及跟踪最小码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code_max, // 红光DCS搜索及跟踪最大码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_manual_code, // 红外DCS手动模式装载码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code_min, // 红外DCS控制范围的低端点
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code_max, // 红外DCS控制范围的高端点
	input signed [11:0]i_amb_threshold_low, // AMB校准残差窗口的signed低边界
	input signed [11:0]i_amb_threshold_high, // AMB校准残差窗口的signed高边界
	input signed [11:0]i_dcs_threshold_low, // R/IR共用DCS残差窗口的signed下限
	input signed [11:0]i_dcs_threshold_high, // R/IR共用DCS残差窗口的signed上限
	input [7:0]i_amb_confirm_count,         // 周期AMB重检同向越界确认次数
	input [7:0]i_dcs_confirm_count,         // DCS重验证及NORMAL跟踪确认次数

	//----------搜索检查样本输入接口----------//
	input i_search_amb_valid,                 // router保持AMB_CAL事务直到控制器接纳
	output o_search_amb_ready,                // 当前拍允许消费一笔AMB_CAL事务
	input i_search_dcs_valid,                 // router保持颜色DCS_CAL事务直至控制器接纳
	output o_search_dcs_ready,                // 当前拍允许消费红光或红外DCS_CAL事务
	input signed [11:0]i_search_calibrated_s1_value, // 搜索与检查唯一使用的Stage1校准残差
	input i_search_calibration_applied,       // 当前搜索样本采用有效Stage1校准系数
	input i_search_saturation_low,            // 校准器给出的明确负向端点保护标志
	input i_search_saturation_high,           // 校准器给出的明确正向端点保护标志
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_search_config_epoch, // 搜索样本绑定的ACTIVE配置版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_search_coef_epoch, // 搜索样本携带的Stage1系数版本
	input i_search_precision_mode,            // 保留搜索样本的9-bit或15-bit身份
	input [C_FRAME_ID_WIDTH - 1:0]i_search_frame_id, // 搜索诊断使用的R/IR共享帧号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_search_sample_index, // 搜索事务的全局顺序编号
	input i_search_color_ir,                  // DCS_CAL低为红光且高为红外
	input [1:0]i_search_frame_type,           // 00为AMB_CAL且01为DCS_CAL
	input [C_IDAC_CODE_WIDTH - 1:0]i_search_amb_code_snapshot, // 当前积分实际使用的AMB码快照
	input [C_IDAC_CODE_WIDTH - 1:0]i_search_dc_code_snapshot, // 当前颜色积分使用的DC码快照
	input [C_CODE_EPOCH_WIDTH - 1:0]i_search_amb_code_epoch, // 搜索样本观察到的AMB提交版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_search_dc_code_epoch, // 搜索样本观察到的颜色DC版本

	//----------验证专用饱和注入接口----------//
	input i_test_inject_enable,               // 验证构建请求注入模式，与C_ENABLE_TEST_INJECTION共同限定
	input i_test_saturation_inject_valid,     // 请求把下一笔真实AMB/DCS搜索样本强制判定为双向饱和
	output o_test_saturation_inject_ready,    // 仅在真实AMB/DCS搜索样本本拍参与qualified判定时可以接纳

	//----------NORMAL跟踪输入接口----------//
	input i_track_valid,                    // NORMAL fork保持跟踪副本直到本模块消费
	output o_track_ready,                   // 有界接纳跟踪事务且不因pending长期反压
	input signed [11:0]i_track_calibrated_s1_value, // 慢速跟踪比较使用的Stage1校准残差
	input i_track_calibration_applied,      // 指示NORMAL残差具备正式校准资格
	input i_track_saturation_low,           // 为跟踪器提供确定的低侧越界证据
	input i_track_saturation_high,          // 为跟踪器提供确定的高侧越界证据
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_track_config_epoch, // NORMAL事务对应的ACTIVE版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_track_coef_epoch, // 跟踪样本采用的Stage1系数组版本
	input i_track_precision_mode,           // 透传精度身份但不分裂IDAC状态；TRK-05 本模块全程不消费该端口,SAR9/SAR15精度切换本身对跟踪evidence/pending/committed码/epoch零耦合 @satisfies: TRK-05
	input [C_FRAME_ID_WIDTH - 1:0]i_track_frame_id, // 跟踪诊断使用的共享采样帧号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_track_sample_index, // 验证单次消费顺序的事务编号
	input i_track_color_ir,                 // 低选择DC_R且高选择DC_IR状态库
	input [1:0]i_track_frame_type,          // 合格跟踪事务必须使用NORMAL编码10
	input [C_IDAC_CODE_WIDTH - 1:0]i_track_amb_code_snapshot, // NORMAL事务观察到的AMB committed码
	input [C_IDAC_CODE_WIDTH - 1:0]i_track_dc_code_snapshot, // NORMAL事务观察到的当前颜色DC码
	input [C_CODE_EPOCH_WIDTH - 1:0]i_track_amb_code_epoch, // 拒绝AMB调码前旧事务的版本标签
	input [C_CODE_EPOCH_WIDTH - 1:0]i_track_dc_code_epoch, // 拒绝颜色DC调码前旧证据的版本

	//-------------序列调度接口-------------//
	input i_amb_sequence_start,             // 调度器安全接管后启动周期AMB检查
	output o_amb_sample_request,            // 保持请求下一笔LED关闭AMB_CAL样本
	output o_amb_sequence_busy,             // 周期AMB检查或重搜索仍在执行
	output o_amb_sequence_done,             // 周期AMB检查成功结束的单周期事件
	output o_amb_sequence_failed,           // 周期AMB重搜索耗尽的单周期事件
	output o_dcs_sample_request,            // 保持请求当前颜色的DCS_CAL样本
	output o_dcs_sample_color_ir,           // 指示DCS请求属于红光或红外
	output o_dcs_revalidate_request,        // 周期AMB阶段完成后保持到调度器accept
	input i_dcs_revalidate_accept,          // 调度器已排空NORMAL并接管DCS重验证
	output o_dcs_revalidate_busy,           // DC_R/DC_IR重新检查仍未完成
	output o_dcs_revalidate_done,           // 两个颜色均恢复窗口的单周期事件
	output o_dcs_revalidate_failed,         // 任一颜色重搜索耗尽的单周期事件

	//-------------码值输出接口-------------//
	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code, // 当前唯一可用于模拟积分的AMB committed码
	output [C_IDAC_CODE_WIDTH - 1:0]o_dcs_r_code, // 当前红光DC抵消committed码
	output [C_IDAC_CODE_WIDTH - 1:0]o_dcs_ir_code, // 当前红外DC抵消committed码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch, // AMB实际改码次数的模16版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dcs_r_code_epoch, // 红光DC安全提交版本标签
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dcs_ir_code_epoch, // 红外DC安全提交版本标签
	output o_amb_code_update,               // AMB码在安全边界实际变化的单拍事件
	output o_dcs_r_code_update,             // 红光DC码实际提交新值的单拍事件
	output o_dcs_ir_code_update,            // 红外DC码实际提交新值的单拍事件
	output o_dcs_r_track_adjust,            // 红光NORMAL慢速跟踪移动1 LSB事件
	output o_dcs_ir_track_adjust,           // 红外NORMAL慢速跟踪移动1 LSB事件

	//-------------状态输出接口-------------//
	output o_amb_search_done,               // 当前RUN的AMB自动搜索已由窗口样本确认
	output o_dcs_r_search_done,             // 当前RUN的红光DCS搜索已完成
	output o_dcs_ir_search_done,            // 当前RUN的红外DCS搜索已完成
	output o_amb_search_exhausted,          // AMB允许码区间内未找到窗口码
	output o_dcs_r_search_exhausted,        // 红光DCS搜索区间已经耗尽
	output o_dcs_ir_search_exhausted,       // 红外DCS搜索无法恢复残差窗口
	output o_amb_pending_valid,             // AMB候选正在等待帧安全边界
	output o_dcs_r_pending_valid,           // 红光DC候选尚未成为committed码
	output o_dcs_ir_pending_valid,          // 红外DC候选等待安全提交
	output o_amb_code_at_min,               // AMB committed码等于ACTIVE下界
	output o_amb_code_at_max,               // AMB committed码等于ACTIVE上界
	output o_dcs_r_code_at_min,             // 红光DC码位于允许区间最低端
	output o_dcs_r_code_at_max,             // 红光DC码位于允许区间最高端
	output o_dcs_ir_code_at_min,            // 红外DC码已经达到配置下界
	output o_dcs_ir_code_at_max,            // 红外DC码已经达到配置上界
	output o_amb_fault,                     // AMB搜索耗尽或内部异常的阻断状态
	output o_dcs_r_fault,                   // 红光DC路径阻断级故障状态
	output o_dcs_ir_fault,                  // 红外DC路径阻断级故障状态
	output o_controller_fault_blocking,     // 汇总三路故障以撤销正式NORMAL资格

	//---------------故障记录接口---------------//
	output o_controller_fault_event,            // 三路故障任一从0到1的注册单周期事件
	output o_controller_fault_identity_valid,   // 本次故障是否绑定了真实搜索样本身份
	output [C_FRAME_ID_WIDTH - 1:0]o_controller_fault_frame_id, // 故障样本所属帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_controller_fault_sample_index, // 故障样本全局序号
	output o_controller_fault_color_ir,         // 故障样本颜色
	output [1:0]o_controller_fault_frame_type,  // 故障样本类型
	output o_controller_fault_precision,        // 故障样本精度
	output [C_RUN_GENERATION_WIDTH - 1:0]o_controller_fault_run_generation, // 故障样本所属RUN代际

	output o_protocol_error_sticky,             // 记录入口冲突和事务协议错误
	output o_startup_search_complete,           // 启动装码或自动搜索全部完成的保持电平
	output o_idac_idle                          // 无样本、序列、pending或提交动作时为高
);

	//-------------配置参数区域-------------//
	// packed上下文位段保证单一时序目标并保留三路独立硬件状态
	localparam integer CTX_AMB_CODE_LSB = 32'd0; // 环境光committed码位于上下文最低字节
	localparam integer CTX_DCS_R_CODE_LSB = 32'd8; // 红光DC committed码紧随AMB字段
	localparam integer CTX_DCS_IR_CODE_LSB = 32'd16; // 红外DC committed码占用第三个字节
	localparam integer CTX_AMB_EPOCH_LSB = 32'd24; // AMB安全提交版本占四位
	localparam integer CTX_DCS_R_EPOCH_LSB = 32'd28; // 红光DC版本保存于AMB版本之后
	localparam integer CTX_DCS_IR_EPOCH_LSB = 32'd32; // 红外DC版本完成三路epoch组
	localparam integer CTX_AMB_PENDING_CODE_LSB = 32'd36; // AMB待提交候选的低位位置
	localparam integer CTX_DCS_R_PENDING_CODE_LSB = 32'd44; // 红光DC候选值独立保存
	localparam integer CTX_DCS_IR_PENDING_CODE_LSB = 32'd52; // 红外DC候选值避免跨色覆盖
	localparam integer CTX_AMB_PENDING_VALID_BIT = 32'd60; // 标记AMB候选所有权尚未释放
	localparam integer CTX_DCS_R_PENDING_VALID_BIT = 32'd61; // 红光DC等待安全边界标志
	localparam integer CTX_DCS_IR_PENDING_VALID_BIT = 32'd62; // 红外DC等待安全边界标志
	localparam integer CTX_DCS_R_PENDING_TRACK_BIT = 32'd63; // 识别红光候选是否来自NORMAL跟踪
	localparam integer CTX_DCS_IR_PENDING_TRACK_BIT = 32'd64; // 识别红外候选的慢速跟踪来源
	localparam integer CTX_AMB_BOUND_LOW_LSB = 32'd65; // AMB二分搜索当前闭区间下界
	localparam integer CTX_AMB_BOUND_HIGH_LSB = 32'd73; // AMB二分搜索当前闭区间上界
	localparam integer CTX_DCS_R_BOUND_LOW_LSB = 32'd81; // 红光DCS搜索区间低端点
	localparam integer CTX_DCS_R_BOUND_HIGH_LSB = 32'd89; // 红光DCS搜索区间高端点
	localparam integer CTX_DCS_IR_BOUND_LOW_LSB = 32'd97; // 红外DCS搜索区间低端点
	localparam integer CTX_DCS_IR_BOUND_HIGH_LSB = 32'd105; // 红外DCS搜索区间高端点
	localparam integer CTX_DCS_R_HIGH_COUNT_LSB = 32'd113; // 红光高侧连续越界计数
	localparam integer CTX_DCS_R_LOW_COUNT_LSB = 32'd121; // 红光低侧连续越界计数
	localparam integer CTX_DCS_IR_HIGH_COUNT_LSB = 32'd129; // 红外高侧连续越界计数
	localparam integer CTX_DCS_IR_LOW_COUNT_LSB = 32'd137; // 红外低侧连续越界计数
	localparam integer CTX_AMB_HIGH_COUNT_LSB = 32'd145; // 周期AMB检查高侧确认计数
	localparam integer CTX_AMB_LOW_COUNT_LSB = 32'd153; // 周期AMB检查低侧确认计数
	localparam integer CTX_AMB_RECHECK_ORIGIN_BIT = 32'd161; // 标识AMB二分搜索来自周期重检
	localparam integer CTX_DCS_REVALIDATE_ORIGIN_BIT = 32'd162; // 标识DCS搜索来自周期固定重验
	localparam integer CTX_AMB_CHANGED_BIT = 32'd163; // 记录周期序列中AMB码至少变化一次
	localparam integer CTX_AMB_SEARCH_DONE_BIT = 32'd164; // AMB搜索成功保持状态
	localparam integer CTX_DCS_R_SEARCH_DONE_BIT = 32'd165; // 红光DCS搜索成功保持状态
	localparam integer CTX_DCS_IR_SEARCH_DONE_BIT = 32'd166; // 红外DCS搜索成功保持状态
	localparam integer CTX_AMB_EXHAUSTED_BIT = 32'd167; // AMB搜索耗尽sticky状态
	localparam integer CTX_DCS_R_EXHAUSTED_BIT = 32'd168; // 红光DCS搜索耗尽sticky状态
	localparam integer CTX_DCS_IR_EXHAUSTED_BIT = 32'd169; // 红外DCS搜索耗尽sticky状态
	localparam integer CTX_AMB_FAULT_BIT = 32'd170; // AMB路径阻断故障存储位
	localparam integer CTX_DCS_R_FAULT_BIT = 32'd171; // 红光DCS阻断故障存储位
	localparam integer CTX_DCS_IR_FAULT_BIT = 32'd172; // 红外DCS阻断故障存储位
	localparam integer CTX_PROTOCOL_ERROR_BIT = 32'd173; // 协议异常历史存储位
	localparam integer CTX_STARTUP_COMPLETE_BIT = 32'd174; // 启动搜索完成保持位
	localparam integer CTX_AMB_UPDATE_BIT = 32'd175; // AMB实际改码单周期事件位
	localparam integer CTX_DCS_R_UPDATE_BIT = 32'd176; // 红光DC实际改码单周期事件位
	localparam integer CTX_DCS_IR_UPDATE_BIT = 32'd177; // 红外DC实际改码单周期事件位
	localparam integer CTX_DCS_R_TRACK_ADJUST_BIT = 32'd178; // 红光1 LSB跟踪事件位
	localparam integer CTX_DCS_IR_TRACK_ADJUST_BIT = 32'd179; // 红外1 LSB跟踪事件位
	localparam integer CTX_AMB_SEQUENCE_DONE_BIT = 32'd180; // 周期AMB序列成功事件位
	localparam integer CTX_AMB_SEQUENCE_FAILED_BIT = 32'd181; // 周期AMB序列失败事件位
	localparam integer CTX_DCS_REVALIDATE_DONE_BIT = 32'd182; // DCS重验证完成事件位
	localparam integer CTX_DCS_REVALIDATE_FAILED_BIT = 32'd183; // DCS重验证失败事件位
	localparam integer CTX_AMB_PENDING_GENERATION_LSB = 32'd184; // AMB候选建立时刻锁存的RUN代际
	localparam integer CTX_DCS_R_PENDING_GENERATION_LSB = 32'd192; // 红光DC候选建立时刻锁存的RUN代际
	localparam integer CTX_DCS_IR_PENDING_GENERATION_LSB = 32'd200; // 红外DC候选建立时刻锁存的RUN代际
	localparam integer CTX_CTRL_FAULT_EVENT_BIT = 32'd208; // 三路故障新episode单周期脉冲存储位
	localparam integer CTX_CTRL_FAULT_IDENTITY_VALID_BIT = 32'd209; // 故障是否绑定真实搜索样本身份
	localparam integer CTX_CTRL_FAULT_FRAME_ID_LSB = 32'd210; // 故障样本帧号快照低位
	localparam integer CTX_CTRL_FAULT_SAMPLE_INDEX_LSB = 32'd226; // 故障样本序号快照低位
	localparam integer CTX_CTRL_FAULT_COLOR_BIT = 32'd242; // 故障样本颜色快照
	localparam integer CTX_CTRL_FAULT_FRAME_TYPE_LSB = 32'd243; // 故障样本类型快照低位
	localparam integer CTX_CTRL_FAULT_PRECISION_BIT = 32'd245; // 故障样本精度快照
	localparam integer CTX_CTRL_FAULT_GENERATION_LSB = 32'd246; // 故障样本所属RUN代际快照低位
	localparam integer CONTEXT_WIDTH = 32'd254; // packed控制上下文总位宽

	//-------------状态参数区域-------------//
	// 单一序列状态机覆盖启动搜索、周期AMB检查和DCS重验证
	localparam [4:0]ST_IDLE = 5'd0;         // 等待合法START或STOP后的空闲状态
	localparam [4:0]ST_MANUAL_APPLY = 5'd1; // 等待安全边界装入三路启动码
	localparam [4:0]ST_AMB_APPLY = 5'd2;    // 等待提交当前AMB二分候选
	localparam [4:0]ST_AMB_WAIT = 5'd3;     // 请求并评价当前AMB候选样本；SID系列启动搜索入口 @satisfies: SID-01
	localparam [4:0]ST_DCS_R_APPLY = 5'd4;  // 等待红光DCS候选安全生效
	localparam [4:0]ST_DCS_R_WAIT = 5'd5;   // 请求红光DCS_CAL评价当前候选
	localparam [4:0]ST_DCS_IR_APPLY = 5'd6; // 等待红外DCS候选安全生效
	localparam [4:0]ST_DCS_IR_WAIT = 5'd7;  // 请求红外DCS_CAL评价当前候选
	localparam [4:0]ST_NORMAL = 5'd8;       // 启动完成并允许NORMAL慢速跟踪
	localparam [4:0]ST_AMB_RECHECK = 5'd9;  // 周期检查当前AMB码并累计确认；RRC周期重检入口,与ST_AMB_WAIT共用同一AMB搜索逻辑 @satisfies: RRC-01
	localparam [4:0]ST_DCS_REVALIDATE_WAIT = 5'd10; // 保持DCS重验证请求直到accept
	localparam [4:0]ST_DCS_REVALIDATE_R = 5'd11; // 检查当前红光DC码是否仍在窗口
	localparam [4:0]ST_DCS_REVALIDATE_IR = 5'd12; // 检查当前红外DC码是否仍在窗口
	localparam [4:0]ST_FAULT = 5'd13;       // 阻断正式NORMAL并等待STOP或新START

	//---------------计数信号---------------//
	// 当前上下文切片只读别名用于确认次数判断
	wire [7:0]cnt_dcs_r_high;               // 红光高侧连续越界证据当前值
	wire [7:0]cnt_dcs_r_low;                // 红光低侧连续越界证据当前值
	wire [7:0]cnt_dcs_ir_high;              // 红外高侧连续越界证据当前值
	wire [7:0]cnt_dcs_ir_low;               // 红外低侧连续越界证据当前值
	wire [7:0]cnt_amb_high;                 // AMB周期检查高侧连续样本数
	wire [7:0]cnt_amb_low;                  // AMB周期检查低侧连续样本数

	//--------------状态机信号--------------//
	reg [4:0]state_current;                 // 当前启动、重检或故障阶段
	reg [4:0]state_next;                    // 组合计算的下一序列阶段

	//--------------寄存器信号--------------//
	// 所有非FSM持久状态统一打包为完整控制上下文
	reg [CONTEXT_WIDTH - 1:0]reg_context;   // 三路码、边界、计数和诊断的当前上下文
	reg [CONTEXT_WIDTH - 1:0]reg_context_next; // 当前事件作用后的完整下一上下文

	//---------------标志信号---------------//
	// 入口仲裁、资格判断、安全提交和搜索方向组合标志
	wire flag_expect_amb_sample;            // 当前状态需要AMB_CAL事务
	wire flag_expect_dcs_sample;            // 当前状态需要指定颜色的DCS_CAL事务
	wire flag_amb_transfer;                 // 当前拍唯一接纳一笔AMB分支事务
	wire flag_dcs_transfer;                 // 当前拍接纳一笔红光或红外DCS事务
	wire flag_test_inject_effective;        // 生产网表固定旁路验证饱和注入请求
	wire flag_test_saturation_inject_fire;  // ready/valid唯一接纳一次饱和注入
	wire flag_track_transfer;               // 当前拍消费NORMAL tracking副本
	wire flag_amb_sample_qualified;         // AMB事务版本、快照和类别全部匹配
	wire flag_dcs_sample_qualified;         // DCS事务颜色、版本和码快照全部匹配
	wire flag_track_sample_qualified;       // NORMAL事务具备慢速跟踪资格
	wire flag_search_above_high;            // 搜索残差明确位于所选窗口上侧
	wire flag_search_below_low;             // 搜索残差明确位于所选窗口下侧
	wire flag_search_in_window;             // 搜索残差位于包含端点的窗口内
	wire flag_track_above_high;             // NORMAL残差提供高侧越界证据
	wire flag_track_below_low;              // NORMAL残差提供低侧越界证据
	wire flag_track_in_window;              // NORMAL残差回到DCS允许窗口
	wire flag_amb_code_increase;            // 当前AMB偏差要求提高数字码
	wire flag_dcs_code_increase;            // 颜色DC残差方向要求提高抵消码
	wire flag_amb_search_has_next;          // AMB当前方向仍存在未评价候选
	wire flag_dcs_r_search_has_next;        // 红光DCS区间仍可继续缩小
	wire flag_dcs_ir_search_has_next;       // 红外DCS区间仍可继续缩小
	wire flag_amb_confirm_trigger;          // AMB越界证据达到配置确认数
	wire flag_dcs_r_confirm_trigger;        // 红光越界证据达到确认次数
	wire flag_dcs_ir_confirm_trigger;       // 红外越界证据达到确认次数
	wire flag_config_valid;                 // ACTIVE输入满足控制器运行安全关系
	wire flag_protocol_event;               // 当前拍发现入口或载荷协议错误
	wire flag_control_cancel;               // STOP、abort或离开RUN要求清理临时状态
	wire flag_amb_commit;                   // 当前安全边界提交AMB pending
	wire flag_dcs_r_commit;                 // 当前安全边界提交红光DC pending
	wire flag_dcs_ir_commit;                // 当前安全边界提交红外DC pending
	wire flag_amb_commit_changes_code;      // AMB pending与committed码不同
	wire flag_dcs_r_commit_changes_code;    // 红光DC pending会实际改变输出
	wire flag_dcs_ir_commit_changes_code;   // 红外DC pending会实际改变输出
	wire flag_track_selected_pending;       // 按颜色选择当前DC pending状态
	wire flag_amb_check_start_allowed;      // 周期AMB检查满足NORMAL接管条件
	wire flag_dcs_r_adjust_allowed;         // 红光跟踪方向未越过配置端点
	wire flag_dcs_ir_adjust_allowed;        // 红外跟踪方向未越过配置端点

	//---------------其他信号---------------//
	// 上下文字段别名与显式扩位的二分搜索运算
	wire [C_IDAC_CODE_WIDTH - 1:0]amb_code_current; // 当前AMB committed码内部别名
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_r_code_current; // 当前红光DC committed码内部别名
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_ir_code_current; // 当前红外DC committed码内部别名
	wire [C_CODE_EPOCH_WIDTH - 1:0]amb_epoch_current; // AMB当前提交版本内部别名
	wire [C_CODE_EPOCH_WIDTH - 1:0]dcs_r_epoch_current; // 红光DC当前版本内部别名
	wire [C_CODE_EPOCH_WIDTH - 1:0]dcs_ir_epoch_current; // 红外DC当前版本内部别名
	wire [C_IDAC_CODE_WIDTH - 1:0]candidate_amb_code; // AMB等待提交的候选值
	wire [C_IDAC_CODE_WIDTH - 1:0]candidate_dcs_r_code; // 红光DC等待提交的候选值
	wire [C_IDAC_CODE_WIDTH - 1:0]candidate_dcs_ir_code; // 红外DC等待提交的候选值
	wire [C_IDAC_CODE_WIDTH - 1:0]amb_bound_low; // AMB二分搜索当前下界
	wire [C_IDAC_CODE_WIDTH - 1:0]amb_bound_high; // AMB二分搜索当前上界
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_r_bound_low; // 红光DCS二分搜索下界
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_r_bound_high; // 红光DCS二分搜索上界
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_ir_bound_low; // 红外DCS二分搜索下界
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_ir_bound_high; // 红外DCS二分搜索上界
	wire [C_IDAC_CODE_WIDTH - 1:0]amb_next_low; // AMB样本评价后的候选区间下界
	wire [C_IDAC_CODE_WIDTH - 1:0]amb_next_high; // AMB样本评价后的候选区间上界
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_r_next_low; // 红光样本评价后的新区间下界
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_r_next_high; // 红光样本评价后的新区间上界
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_ir_next_low; // 红外样本评价后的新区间下界
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_ir_next_high; // 红外样本评价后的新区间上界
	wire [8:0]amb_initial_sum;              // AMB初始闭区间端点的9-bit和
	wire [8:0]dcs_r_initial_sum;            // 红光DCS初始区间端点扩位和
	wire [8:0]dcs_ir_initial_sum;           // 红外DCS初始区间端点扩位和
	wire [8:0]amb_next_sum;                 // AMB缩小区间端点的9-bit和
	wire [8:0]dcs_r_next_sum;               // 红光DCS缩小区间端点和
	wire [8:0]dcs_ir_next_sum;              // 红外DCS缩小区间端点和
	wire [C_IDAC_CODE_WIDTH - 1:0]amb_initial_midpoint; // AMB全范围向下取整中点
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_r_initial_midpoint; // 红光DCS全范围向下取整中点
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_ir_initial_midpoint; // 红外DCS全范围向下取整中点
	wire [C_IDAC_CODE_WIDTH - 1:0]amb_next_midpoint; // AMB下一闭区间向下取整中点
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_r_next_midpoint; // 红光DCS下一候选中点
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_ir_next_midpoint; // 红外DCS下一候选中点
	wire [C_IDAC_CODE_WIDTH - 1:0]selected_dc_code_value; // 按颜色选择NORMAL事务应观察的DC码
	wire [C_CODE_EPOCH_WIDTH - 1:0]selected_dc_epoch_value; // 按颜色选择当前DC版本

	//---------------输出信号---------------//

	//-------------其他信号连线-------------//
	assign amb_code_current = reg_context[CTX_AMB_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 提取AMB committed码
	assign dcs_r_code_current = reg_context[CTX_DCS_R_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 提取红光DC committed码
	assign dcs_ir_code_current = reg_context[CTX_DCS_IR_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 提取红外DC committed码
	assign amb_epoch_current = reg_context[CTX_AMB_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 提取AMB提交版本
	assign dcs_r_epoch_current = reg_context[CTX_DCS_R_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 提取红光DC版本
	assign dcs_ir_epoch_current = reg_context[CTX_DCS_IR_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 提取红外DC版本
	assign candidate_amb_code = reg_context[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 读取AMB pending候选
	assign candidate_dcs_r_code = reg_context[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 读取红光DC pending候选
	assign candidate_dcs_ir_code = reg_context[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 读取红外DC pending候选
	assign amb_bound_low = reg_context[CTX_AMB_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH]; // 读取AMB搜索下界
	assign amb_bound_high = reg_context[CTX_AMB_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH]; // 读取AMB搜索上界
	assign dcs_r_bound_low = reg_context[CTX_DCS_R_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH]; // 读取红光搜索下界
	assign dcs_r_bound_high = reg_context[CTX_DCS_R_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH]; // 读取红光搜索上界
	assign dcs_ir_bound_low = reg_context[CTX_DCS_IR_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH]; // 读取红外搜索下界
	assign dcs_ir_bound_high = reg_context[CTX_DCS_IR_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH]; // 读取红外搜索上界
	assign cnt_dcs_r_high = reg_context[CTX_DCS_R_HIGH_COUNT_LSB +: 8]; // 提取红光高侧证据计数
	assign cnt_dcs_r_low = reg_context[CTX_DCS_R_LOW_COUNT_LSB +: 8]; // 提取红光低侧证据计数
	assign cnt_dcs_ir_high = reg_context[CTX_DCS_IR_HIGH_COUNT_LSB +: 8]; // 提取红外高侧证据计数
	assign cnt_dcs_ir_low = reg_context[CTX_DCS_IR_LOW_COUNT_LSB +: 8]; // 提取红外低侧证据计数
	assign cnt_amb_high = reg_context[CTX_AMB_HIGH_COUNT_LSB +: 8]; // 提取AMB高侧确认计数
	assign cnt_amb_low = reg_context[CTX_AMB_LOW_COUNT_LSB +: 8]; // 提取AMB低侧确认计数
	assign flag_expect_amb_sample =
		(state_current == ST_AMB_WAIT) ||
		(state_current == ST_AMB_RECHECK);  // 启动搜索与周期检查共用AMB入口
	assign flag_expect_dcs_sample =
		(state_current == ST_DCS_R_WAIT) ||
		(state_current == ST_DCS_IR_WAIT) ||
		(state_current == ST_DCS_REVALIDATE_R) ||
		(state_current == ST_DCS_REVALIDATE_IR); // DCS搜索和重验证共用颜色入口
	assign flag_amb_transfer = i_search_amb_valid && o_search_amb_ready; // 定义AMB入口唯一握手沿
	assign flag_dcs_transfer = i_search_dcs_valid && o_search_dcs_ready; // 定义颜色DCS入口唯一握手沿
	assign flag_test_inject_effective = (C_ENABLE_TEST_INJECTION != 32'd0) && i_test_inject_enable; // 生产构建固定旁路验证饱和注入请求
	assign o_test_saturation_inject_ready = flag_test_inject_effective && ((flag_amb_transfer && flag_expect_amb_sample) || (flag_dcs_transfer && flag_expect_dcs_sample)); // 只在真实AMB/DCS样本本拍参与qualified判定时可以接纳，不touch共享的i_search_saturation_low/high输入线
	assign flag_test_saturation_inject_fire = i_test_saturation_inject_valid && o_test_saturation_inject_ready; // ready/valid唯一接纳一次饱和注入
	assign flag_track_transfer = i_track_valid && o_track_ready; // 定义NORMAL跟踪入口消费事件
	assign flag_search_above_high = i_search_saturation_high ||
		((i_search_saturation_low == 1'b0) &&
			($signed(i_search_calibrated_s1_value) >
				((flag_expect_amb_sample == 1'b1) ?
					i_amb_threshold_high : i_dcs_threshold_high))); // 饱和优先于signed窗口上侧比较
	assign flag_search_below_low = i_search_saturation_low ||
		((i_search_saturation_high == 1'b0) &&
			($signed(i_search_calibrated_s1_value) <
				((flag_expect_amb_sample == 1'b1) ?
					i_amb_threshold_low : i_dcs_threshold_low))); // 饱和优先于signed窗口下侧比较
	assign flag_search_in_window =
		(flag_search_above_high == 1'b0) &&
		(flag_search_below_low == 1'b0);    // 包含LOW和HIGH端点的搜索窗口判定
	assign flag_track_above_high = i_track_saturation_high ||
		((i_track_saturation_low == 1'b0) &&
			($signed(i_track_calibrated_s1_value) > i_dcs_threshold_high)); // NORMAL残差高于共用DCS上界；TRK-10 跟踪比较仅使用本signed 12-bit校准Stage1残差,不存在Stage2/15-bit重建/DC恢复/正式输出的替代通路 @satisfies: TRK-10
	assign flag_track_below_low = i_track_saturation_low ||
		((i_track_saturation_high == 1'b0) &&
			($signed(i_track_calibrated_s1_value) < i_dcs_threshold_low)); // NORMAL残差低于共用DCS下界；TRK-10 同一signed 12-bit残差驱动低侧比较,零替代通路 @satisfies: TRK-10
	assign flag_track_in_window =
		(flag_track_above_high == 1'b0) &&
		(flag_track_below_low == 1'b0);     // NORMAL残差处于允许闭区间
	assign selected_dc_code_value = i_track_color_ir ?
		dcs_ir_code_current : dcs_r_code_current; // 颜色身份选择应匹配的DC committed码
	assign selected_dc_epoch_value = i_track_color_ir ?
		dcs_ir_epoch_current : dcs_r_epoch_current; // 颜色身份选择对应4-bit版本
	assign flag_track_selected_pending = i_track_color_ir ?
		reg_context[CTX_DCS_IR_PENDING_VALID_BIT] :
		reg_context[CTX_DCS_R_PENDING_VALID_BIT]; // 阻止同一颜色pending期间重复累积；TRK-06 pending等待安全边界期间该色新证据被此条件挡在flag_track_sample_qualified外,payload不可被后续证据覆盖 @satisfies: TRK-06
	assign flag_amb_check_start_allowed =
		(state_current == ST_NORMAL) && (i_amb_sequence_start == 1'b1) &&
		(i_idac_mode == 2'b10) && (i_amb_enable == 1'b1) &&
		(o_controller_fault_blocking == 1'b0) &&
		(o_amb_pending_valid == 1'b0) &&
		(o_dcs_r_pending_valid == 1'b0) &&
		(o_dcs_ir_pending_valid == 1'b0);   // 仅空闲NORMAL允许调度器启动AMB检查；NRE-02 i_amb_sequence_start来自调度器o_amb_sequence_start，interval=0时结构性恒为0，本条件永不满足，控制器不产生重检驱动的校准请求 @satisfies: NRE-02
	assign flag_dcs_r_adjust_allowed =
		((flag_dcs_code_increase == 1'b1) && (dcs_r_code_current < i_dcs_r_code_max)) ||
		((flag_dcs_code_increase == 1'b0) && (dcs_r_code_current > i_dcs_r_code_min)); // 红光方向必须保留1 LSB调整空间；TRK-08 码已贴住min/max端点时该条件为0,1075行pending不形成,持续同向证据不产生假update也不递增epoch @satisfies: TRK-08
	assign flag_dcs_ir_adjust_allowed =
		((flag_dcs_code_increase == 1'b1) && (dcs_ir_code_current < i_dcs_ir_code_max)) ||
		((flag_dcs_code_increase == 1'b0) && (dcs_ir_code_current > i_dcs_ir_code_min)); // 红外方向必须保留1 LSB调整空间
	assign flag_amb_sample_qualified = flag_amb_transfer &&
		flag_expect_amb_sample && i_run_enable &&
		(i_search_frame_type == 2'b00) && i_search_calibration_applied &&
		(i_search_config_epoch == i_active_config_epoch) &&
		(i_search_amb_code_snapshot == amb_code_current) &&
		(i_search_amb_code_epoch == amb_epoch_current) &&
		(flag_test_saturation_inject_fire ? 1'b0 : ((i_search_saturation_low && i_search_saturation_high) == 1'b0)); // AMB样本必须观察当前码和版本，注入生效时旁路真实饱和线强制判定为双向饱和
	assign flag_dcs_sample_qualified = flag_dcs_transfer &&
		flag_expect_dcs_sample && i_run_enable &&
		(i_search_frame_type == 2'b01) && i_search_calibration_applied &&
		(i_search_color_ir == o_dcs_sample_color_ir) &&
		(i_search_config_epoch == i_active_config_epoch) &&
		(i_search_amb_code_snapshot == amb_code_current) &&
		(i_search_amb_code_epoch == amb_epoch_current) &&
		(i_search_dc_code_snapshot ==
			(i_search_color_ir ? dcs_ir_code_current : dcs_r_code_current)) &&
		(i_search_dc_code_epoch ==
			(i_search_color_ir ? dcs_ir_epoch_current : dcs_r_epoch_current)) &&
		(flag_test_saturation_inject_fire ? 1'b0 : ((i_search_saturation_low && i_search_saturation_high) == 1'b0)); // DCS样本同时绑定AMB和当前颜色DC状态，注入生效时旁路真实饱和线强制判定为双向饱和
	assign flag_track_sample_qualified = flag_track_transfer && i_run_enable &&
		(i_idac_mode == 2'b10) && i_dcs_enable &&
		reg_context[CTX_STARTUP_COMPLETE_BIT] &&
		(state_current == ST_NORMAL) &&
		(i_track_frame_type == 2'b10) && i_track_calibration_applied &&
		(i_track_config_epoch == i_active_config_epoch) &&
		(i_track_amb_code_snapshot == amb_code_current) &&
		(i_track_amb_code_epoch == amb_epoch_current) &&
		(i_track_dc_code_snapshot == selected_dc_code_value) &&
		(i_track_dc_code_epoch == selected_dc_epoch_value) &&
		(flag_track_selected_pending == 1'b0) &&
		(o_controller_fault_blocking == 1'b0) &&
		((i_track_saturation_low && i_track_saturation_high) == 1'b0); // 仅当前码快照的正式NORMAL事务参与跟踪；TRK-01 未真实transfer(flag_track_transfer=0,含i_track_valid=0)时整条assign为0,下方1067行判定块不执行,evidence/pending/committed码/epoch零变化;TRK-09 calibration_applied缺失或AMB/DC码快照及epoch任一不匹配同样使本条件为0,样本被真实消费(flag_track_transfer=1)但不改变跟踪状态 @satisfies: TRK-01, TRK-09
	assign flag_amb_code_increase = flag_search_above_high ?
		i_amb_polarity : (i_amb_polarity == 1'b0); // AMB极性决定上下侧残差的码方向
	assign flag_dcs_code_increase = (flag_expect_dcs_sample ? flag_search_above_high : flag_track_above_high) ?
		i_dcs_polarity : (i_dcs_polarity == 1'b0); // DCS极性统一控制搜索和1 LSB跟踪
	assign flag_amb_search_has_next = flag_amb_code_increase ?
		(amb_code_current < amb_bound_high) :
		(amb_code_current > amb_bound_low); // 当前候选未到目标方向边界时可继续搜索
	assign flag_dcs_r_search_has_next = flag_dcs_code_increase ?
		(dcs_r_code_current < dcs_r_bound_high) :
		(dcs_r_code_current > dcs_r_bound_low); // 红光DCS候选仍有未评价半区
	assign flag_dcs_ir_search_has_next = flag_dcs_code_increase ?
		(dcs_ir_code_current < dcs_ir_bound_high) :
		(dcs_ir_code_current > dcs_ir_bound_low); // 红外DCS候选仍可沿目标方向移动
	assign amb_next_low = flag_amb_code_increase ?
		(amb_code_current + {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}) :
		amb_bound_low;                      // 增码搜索排除已经评价的AMB候选
	assign amb_next_high = flag_amb_code_increase ?
		amb_bound_high :
		(amb_code_current - {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}); // 减码搜索排除当前AMB候选
	assign dcs_r_next_low = flag_dcs_code_increase ?
		(dcs_r_code_current + {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}) :
		dcs_r_bound_low;                    // 红光增码方向更新闭区间下界
	assign dcs_r_next_high = flag_dcs_code_increase ?
		dcs_r_bound_high :
		(dcs_r_code_current - {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}); // 红光减码方向更新闭区间上界
	assign dcs_ir_next_low = flag_dcs_code_increase ?
		(dcs_ir_code_current + {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}) :
		dcs_ir_bound_low;                   // 红外增码搜索形成新区间下界
	assign dcs_ir_next_high = flag_dcs_code_increase ?
		dcs_ir_bound_high :
		(dcs_ir_code_current - {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}); // 红外减码搜索形成新区间上界
	assign amb_initial_sum = {1'b0, i_amb_code_min} + {1'b0, i_amb_code_max}; // 扩位计算AMB初始中点避免8-bit溢出
	assign dcs_r_initial_sum = {1'b0, i_dcs_r_code_min} + {1'b0, i_dcs_r_code_max}; // 扩位计算红光DCS初始中点
	assign dcs_ir_initial_sum = {1'b0, i_dcs_ir_code_min} + {1'b0, i_dcs_ir_code_max}; // 扩位计算红外DCS初始中点
	assign amb_next_sum = {1'b0, amb_next_low} + {1'b0, amb_next_high}; // 计算AMB下一候选的闭区间端点和
	assign dcs_r_next_sum = {1'b0, dcs_r_next_low} + {1'b0, dcs_r_next_high}; // 计算红光DCS下一候选中点
	assign dcs_ir_next_sum = {1'b0, dcs_ir_next_low} + {1'b0, dcs_ir_next_high}; // 计算红外DCS下一候选中点
	assign amb_initial_midpoint = amb_initial_sum[8:1]; // 向下取整得到AMB首个二分候选
	assign dcs_r_initial_midpoint = dcs_r_initial_sum[8:1]; // 向下取整得到红光首个候选
	assign dcs_ir_initial_midpoint = dcs_ir_initial_sum[8:1]; // 向下取整得到红外首个候选
	assign amb_next_midpoint = amb_next_sum[8:1]; // 向下取整得到AMB下一候选
	assign dcs_r_next_midpoint = dcs_r_next_sum[8:1]; // 向下取整得到红光下一候选
	assign dcs_ir_next_midpoint = dcs_ir_next_sum[8:1]; // 向下取整得到红外下一候选
	assign flag_amb_confirm_trigger = flag_search_above_high ?
		(cnt_amb_high >= (i_amb_confirm_count - 8'd1)) :
		(cnt_amb_low >= (i_amb_confirm_count - 8'd1)); // 当前AMB样本是否补足同向确认次数
	assign flag_dcs_r_confirm_trigger = (flag_expect_dcs_sample ? flag_search_above_high : flag_track_above_high) ?
		(cnt_dcs_r_high >= (i_dcs_confirm_count - 8'd1)) :
		(cnt_dcs_r_low >= (i_dcs_confirm_count - 8'd1)); // 红光当前样本是否形成调码证据；TRK-02 同向计数未达i_dcs_confirm_count-1时该条件为0,样本只累计计数(1067行同向分支)不形成pending,达到阈值当拍才真正触发1072行清零+形成候选 @satisfies: TRK-02
	assign flag_dcs_ir_confirm_trigger = (flag_expect_dcs_sample ? flag_search_above_high : flag_track_above_high) ?
		(cnt_dcs_ir_high >= (i_dcs_confirm_count - 8'd1)) :
		(cnt_dcs_ir_low >= (i_dcs_confirm_count - 8'd1)); // 红外当前样本是否达到确认阈值
	assign flag_config_valid =
		(i_idac_mode != 2'b11) &&
		(i_amb_code_min <= i_amb_manual_code) &&
		(i_amb_manual_code <= i_amb_code_max) &&
		(i_dcs_r_code_min <= i_dcs_r_manual_code) &&
		(i_dcs_r_manual_code <= i_dcs_r_code_max) &&
		(i_dcs_ir_code_min <= i_dcs_ir_manual_code) &&
		(i_dcs_ir_manual_code <= i_dcs_ir_code_max) &&
		($signed(i_amb_threshold_low) < $signed(i_amb_threshold_high)) &&
		($signed(i_dcs_threshold_low) < $signed(i_dcs_threshold_high)) &&
		(i_amb_confirm_count != 8'd0) &&
		(i_dcs_confirm_count != 8'd0);      // 运行期再次保护ACTIVE字段关系
	assign flag_protocol_event =
		((i_search_amb_valid && i_search_dcs_valid) ||
			(i_search_amb_valid && i_track_valid) ||
			(i_search_dcs_valid && i_track_valid)) ||
		((flag_amb_transfer || flag_dcs_transfer) &&
			(i_search_saturation_low && i_search_saturation_high)) ||
		(flag_track_transfer && i_track_saturation_low && i_track_saturation_high) ||
		(flag_amb_transfer &&
			((flag_expect_amb_sample == 1'b0) || (i_search_frame_type != 2'b00))) ||
		(flag_dcs_transfer &&
			((flag_expect_dcs_sample == 1'b0) || (i_search_frame_type != 2'b01) ||
				(i_search_color_ir != o_dcs_sample_color_ir))) ||
		(flag_track_transfer && (i_track_frame_type != 2'b10)) ||
		(i_amb_sequence_start &&
			((state_current != ST_NORMAL) || (i_idac_mode != 2'b10) ||
				(i_amb_enable == 1'b0) || (o_controller_fault_blocking == 1'b1))) ||
		(i_dcs_revalidate_accept && (state_current != ST_DCS_REVALIDATE_WAIT)); // 汇总所有可确定的上层调度协议错误
	assign flag_control_cancel = i_stop_ack_event || i_control_abort_event ||
		(i_run_enable == 1'b0);             // 离开RUN后立即清理临时证据；fault-bit清除优先级,呼应V2.3 STOP/abort而非START清除的死锁修复 @satisfies: K01, G-FP-06
	assign flag_amb_commit = reg_context[CTX_AMB_PENDING_VALID_BIT] &&
		i_frame_safe_boundary && i_run_enable &&
		(i_stop_ack_event == 1'b0) && (i_control_abort_event == 1'b0) &&
		(reg_context[CTX_AMB_PENDING_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] == i_run_generation); // AMB pending只在安全边界且代际未过期时成为committed码
	assign flag_dcs_r_commit = reg_context[CTX_DCS_R_PENDING_VALID_BIT] &&
		i_frame_safe_boundary && i_run_enable &&
		(i_stop_ack_event == 1'b0) && (i_control_abort_event == 1'b0) &&
		(reg_context[CTX_DCS_R_PENDING_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] == i_run_generation); // 红光DC pending安全提交条件，含代际校验
	assign flag_dcs_ir_commit = reg_context[CTX_DCS_IR_PENDING_VALID_BIT] &&
		i_frame_safe_boundary && i_run_enable &&
		(i_stop_ack_event == 1'b0) && (i_control_abort_event == 1'b0) &&
		(reg_context[CTX_DCS_IR_PENDING_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] == i_run_generation); // 红外DC pending安全提交条件，含代际校验
	assign flag_amb_commit_changes_code = flag_amb_commit &&
		(candidate_amb_code != amb_code_current); // 仅实际改变AMB码时更新epoch
	assign flag_dcs_r_commit_changes_code = flag_dcs_r_commit &&
		(candidate_dcs_r_code != dcs_r_code_current); // 识别红光DC真实码值变化；ISE-09 该条件为0时877行整个if分支不执行，本次安全边界不产生update/track-adjust/epoch递增中的任何一项，仅数值真实变化才会门控877-883行 @satisfies: ISE-09
	assign flag_dcs_ir_commit_changes_code = flag_dcs_ir_commit &&
		(candidate_dcs_ir_code != dcs_ir_code_current); // 识别红外DC真实码值变化

	//-------------输出信号连线-------------//
	assign o_search_amb_ready = flag_expect_dcs_sample ?
		(i_search_dcs_valid == 1'b0) : 1'b1; // 当前期待DCS时优先保证DCS事务被消费
	assign o_search_dcs_ready = flag_expect_amb_sample ?
		(i_search_amb_valid == 1'b0) :
		(flag_expect_dcs_sample ? 1'b1 : (i_search_amb_valid == 1'b0)); // 非AMB优先拍允许消费DCS事务
	assign o_track_ready = (flag_amb_transfer == 1'b0) &&
		(flag_dcs_transfer == 1'b0);        // 搜索入口占用当前拍时暂缓tracking副本
	assign o_amb_code = amb_code_current;   // 输出唯一AMB committed码
	assign o_dcs_r_code = dcs_r_code_current; // 输出红光DC committed码
	assign o_dcs_ir_code = dcs_ir_code_current; // 输出红外DC committed码
	assign o_amb_code_epoch = amb_epoch_current; // 输出AMB安全提交版本
	assign o_dcs_r_code_epoch = dcs_r_epoch_current; // 输出红光DC提交版本
	assign o_dcs_ir_code_epoch = dcs_ir_epoch_current; // 输出红外DC提交版本
	assign o_amb_code_update = reg_context[CTX_AMB_UPDATE_BIT]; // 输出AMB实际改码单拍
	assign o_dcs_r_code_update = reg_context[CTX_DCS_R_UPDATE_BIT]; // 输出红光DC实际改码单拍
	assign o_dcs_ir_code_update = reg_context[CTX_DCS_IR_UPDATE_BIT]; // 输出红外DC实际改码单拍
	assign o_dcs_r_track_adjust = reg_context[CTX_DCS_R_TRACK_ADJUST_BIT]; // 标记红光NORMAL跟踪提交
	assign o_dcs_ir_track_adjust = reg_context[CTX_DCS_IR_TRACK_ADJUST_BIT]; // 标记红外NORMAL跟踪提交
	assign o_amb_search_done = reg_context[CTX_AMB_SEARCH_DONE_BIT]; // 输出AMB搜索成功保持状态
	assign o_dcs_r_search_done = reg_context[CTX_DCS_R_SEARCH_DONE_BIT]; // 输出红光DCS搜索成功状态
	assign o_dcs_ir_search_done = reg_context[CTX_DCS_IR_SEARCH_DONE_BIT]; // 输出红外DCS搜索成功状态
	assign o_amb_search_exhausted = reg_context[CTX_AMB_EXHAUSTED_BIT]; // 输出AMB搜索耗尽sticky
	assign o_dcs_r_search_exhausted = reg_context[CTX_DCS_R_EXHAUSTED_BIT]; // 输出红光搜索耗尽sticky
	assign o_dcs_ir_search_exhausted = reg_context[CTX_DCS_IR_EXHAUSTED_BIT]; // 输出红外搜索耗尽sticky
	assign o_amb_pending_valid = reg_context[CTX_AMB_PENDING_VALID_BIT]; // 暴露AMB候选等待状态
	assign o_dcs_r_pending_valid = reg_context[CTX_DCS_R_PENDING_VALID_BIT]; // 暴露红光DC pending状态
	assign o_dcs_ir_pending_valid = reg_context[CTX_DCS_IR_PENDING_VALID_BIT]; // 暴露红外DC pending状态
	assign o_amb_code_at_min = amb_code_current == i_amb_code_min; // 当前AMB码是否到达ACTIVE下界
	assign o_amb_code_at_max = amb_code_current == i_amb_code_max; // 当前AMB码是否到达ACTIVE上界
	assign o_dcs_r_code_at_min = dcs_r_code_current == i_dcs_r_code_min; // 红光DC码是否位于配置下界
	assign o_dcs_r_code_at_max = dcs_r_code_current == i_dcs_r_code_max; // 红光DC码是否位于配置上界
	assign o_dcs_ir_code_at_min = dcs_ir_code_current == i_dcs_ir_code_min; // 红外DC码是否位于配置下界
	assign o_dcs_ir_code_at_max = dcs_ir_code_current == i_dcs_ir_code_max; // 红外DC码是否位于配置上界
	assign o_amb_fault = reg_context[CTX_AMB_FAULT_BIT]; // 输出AMB路径阻断状态
	assign o_dcs_r_fault = reg_context[CTX_DCS_R_FAULT_BIT]; // 输出红光DCS路径阻断状态
	assign o_dcs_ir_fault = reg_context[CTX_DCS_IR_FAULT_BIT]; // 输出红外DCS路径阻断状态
	assign o_controller_fault_blocking = o_amb_fault || o_dcs_r_fault || o_dcs_ir_fault; // 汇总正式运行阻断条件；IDAC child自身私有汇总flag,唯一出口送AMI @satisfies: K01

	//故障记录接口
	assign o_controller_fault_event = reg_context[CTX_CTRL_FAULT_EVENT_BIT]; // 输出三路故障新episode单周期脉冲
	assign o_controller_fault_identity_valid = reg_context[CTX_CTRL_FAULT_IDENTITY_VALID_BIT]; // 输出身份是否可信
	assign o_controller_fault_frame_id = reg_context[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] ? reg_context[CTX_CTRL_FAULT_FRAME_ID_LSB +: C_FRAME_ID_WIDTH] : {C_FRAME_ID_WIDTH{1'b0}}; // 身份无效时强制归零
	assign o_controller_fault_sample_index = reg_context[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] ? reg_context[CTX_CTRL_FAULT_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH] : {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 供supervisor与其它两路来源交叉核对
	assign o_controller_fault_color_ir = reg_context[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] && reg_context[CTX_CTRL_FAULT_COLOR_BIT]; // 与AND门共享同一身份有效位
	assign o_controller_fault_frame_type = reg_context[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] ? reg_context[CTX_CTRL_FAULT_FRAME_TYPE_LSB +: 2] : 2'b00; // 区分AMB_CAL与DCS_CAL来源
	assign o_controller_fault_precision = reg_context[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] && reg_context[CTX_CTRL_FAULT_PRECISION_BIT]; // 输出耗尽样本精度
	assign o_controller_fault_run_generation = reg_context[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] ? reg_context[CTX_CTRL_FAULT_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] : {C_RUN_GENERATION_WIDTH{1'b0}}; // 供supervisor判断是否跨代际
	assign o_protocol_error_sticky = reg_context[CTX_PROTOCOL_ERROR_BIT]; // 输出未清除的协议错误历史
	assign o_startup_search_complete = reg_context[CTX_STARTUP_COMPLETE_BIT]; // 输出启动流程完成资格
	assign o_amb_sample_request = flag_expect_amb_sample; // 当前状态持续请求AMB_CAL事务
	assign o_dcs_sample_request = flag_expect_dcs_sample; // 当前状态持续请求指定颜色DCS_CAL事务
	assign o_dcs_sample_color_ir =
		(state_current == ST_DCS_IR_WAIT) ||
		(state_current == ST_DCS_REVALIDATE_IR); // 红外相关状态请求color_ir为1
	assign o_amb_sequence_busy =
		(state_current == ST_AMB_RECHECK) ||
		(reg_context[CTX_AMB_RECHECK_ORIGIN_BIT] &&
			((state_current == ST_AMB_APPLY) || (state_current == ST_AMB_WAIT))); // 周期检查及其二分重搜期间保持busy
	assign o_amb_sequence_done = reg_context[CTX_AMB_SEQUENCE_DONE_BIT]; // 输出周期AMB成功单拍
	assign o_amb_sequence_failed = reg_context[CTX_AMB_SEQUENCE_FAILED_BIT]; // 输出周期AMB失败单拍
	assign o_dcs_revalidate_request = state_current == ST_DCS_REVALIDATE_WAIT; // AMB阶段结束后保持固定重验证请求
	assign o_dcs_revalidate_busy =
		(state_current == ST_DCS_REVALIDATE_R) ||
		(state_current == ST_DCS_REVALIDATE_IR) ||
		(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] &&
			((state_current == ST_DCS_R_APPLY) || (state_current == ST_DCS_R_WAIT) ||
				(state_current == ST_DCS_IR_APPLY) || (state_current == ST_DCS_IR_WAIT))); // accept后至两色完成期间保持busy
	assign o_dcs_revalidate_done = reg_context[CTX_DCS_REVALIDATE_DONE_BIT]; // 输出DCS重验证完成事件
	assign o_dcs_revalidate_failed = reg_context[CTX_DCS_REVALIDATE_FAILED_BIT]; // 输出DCS重验证失败事件
	assign o_idac_idle =
		(o_amb_pending_valid == 1'b0) &&
		(o_dcs_r_pending_valid == 1'b0) &&
		(o_dcs_ir_pending_valid == 1'b0) &&
		(o_amb_sample_request == 1'b0) &&
		(o_dcs_sample_request == 1'b0) &&
		(o_dcs_revalidate_request == 1'b0) &&
		(o_amb_sequence_busy == 1'b0) &&
		(o_dcs_revalidate_busy == 1'b0) &&
		(flag_amb_transfer == 1'b0) &&
		(flag_dcs_transfer == 1'b0) &&
		(flag_track_transfer == 1'b0);      // STOPPING只等待真实在途控制动作排空

	//--------------状态机区域--------------//
	// 序列状态寄存器在复位、STOP和abort后回到空闲阶段
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_IDLE;       // 复位禁止任何自动采样请求
		end else begin
			state_current <= state_next;    // 每拍采纳合同限定的下一序列阶段
		end
	end

	// 下一状态只根据已接纳事件、搜索结果和安全提交边界改变
	always@(*)begin
		state_next = state_current;         // 默认保持以覆盖全部组合路径
		if((i_stop_ack_event == 1'b1) || (i_control_abort_event == 1'b1))begin
			state_next = ST_IDLE;           // 显式取消优先终止活动序列
		end else if(i_start_ack_event == 1'b1)begin
			if((i_run_enable == 1'b0) || (flag_config_valid == 1'b0))begin
				state_next = ST_FAULT;      // 不可能的非法START进入阻断状态
			end else if(i_idac_mode == 2'b00)begin
				state_next = ST_MANUAL_APPLY; // MANUAL等待首个安全边界装码；ILM-02/ILM-03 idac_mode=MANUAL时状态机只进本分支，ST_MANUAL_APPLY又只能转向ST_NORMAL(720行)，结构性永不进入AMB/DCS任一搜索态，SPI提交的AMB/DC_R码在整个RUN期间保持不变；ILM-09 同一结构性约束下state_current全程只落在ST_IDLE/ST_MANUAL_APPLY/ST_NORMAL这个MANUAL-only小集合，自动启动搜索/周期重检/自动精度切换全部结构性不可达 @satisfies: ILM-02, ILM-03, ILM-09
			end else if(i_amb_enable == 1'b1)begin
				state_next = ST_AMB_APPLY;  // 自动模式首先搜索AMB；SID-02 启动搜索严格先进AMB阶段，不允许跳过或从其它颜色阶段起步 @satisfies: SID-02
			end else if(i_dcs_enable == 1'b1)begin
				state_next = ST_DCS_R_APPLY; // AMB禁用时直接搜索红光DC
			end else begin
				state_next = ST_MANUAL_APPLY; // 全部禁用仍在边界装入安全码
			end
		end else if(i_run_enable == 1'b0)begin
			state_next = ST_IDLE;           // 非RUN状态不保留活动控制上下文
		end else begin
			case(state_current)
				ST_IDLE:begin
					state_next = ST_IDLE;   // 等待配置管理器给出下一次合法START
				end
				ST_MANUAL_APPLY:begin
					if(i_frame_safe_boundary == 1'b1)begin
						state_next = ST_NORMAL; // 三路启动pending在同一安全沿完成
					end
				end
				ST_AMB_APPLY:begin
					if(flag_amb_commit == 1'b1)begin
						state_next = ST_AMB_WAIT; // 候选生效后才允许请求AMB样本
					end
				end
				ST_AMB_WAIT:begin
					if(flag_amb_sample_qualified == 1'b1)begin
						if(flag_search_in_window == 1'b1)begin
							if(reg_context[CTX_AMB_RECHECK_ORIGIN_BIT] == 1'b1)begin
								if(i_dcs_enable)begin
									state_next = ST_DCS_REVALIDATE_WAIT; // 周期三帧序列无条件进入两色DC重新验证
								end else begin
									state_next = ST_NORMAL; // DCS禁用时周期AMB阶段完成并恢复NORMAL
								end
							end else if(i_dcs_enable == 1'b1)begin
								state_next = ST_DCS_R_APPLY; // 启动AMB成功后进入红光DCS搜索
							end else begin
								state_next = ST_NORMAL; // 仅AMB启用时启动流程完成
							end
						end else if(flag_amb_search_has_next == 1'b1)begin
							state_next = ST_AMB_APPLY; // 缩小区间后提交下一AMB候选
						end else begin
							state_next = ST_FAULT; // AMB区间耗尽阻断正式运行
						end
					end
				end
				ST_DCS_R_APPLY:begin
					if(flag_dcs_r_commit == 1'b1)begin
						state_next = ST_DCS_R_WAIT; // 红光候选提交后请求匹配DCS_CAL
					end
				end
				ST_DCS_R_WAIT:begin
					if(flag_dcs_sample_qualified == 1'b1)begin
						if(flag_search_in_window == 1'b1)begin
							if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b1)begin
								state_next = ST_DCS_REVALIDATE_IR; // 红光恢复后检查现有红外码
							end else begin
								state_next = ST_DCS_IR_APPLY; // 启动搜索继续红外DCS阶段
							end
						end else if(flag_dcs_r_search_has_next == 1'b1)begin
							state_next = ST_DCS_R_APPLY; // 红光区间仍有候选则继续二分
						end else begin
							state_next = ST_FAULT; // 红光DCS搜索耗尽进入故障
						end
					end
				end
				ST_DCS_IR_APPLY:begin
					if(flag_dcs_ir_commit == 1'b1)begin
						state_next = ST_DCS_IR_WAIT; // 红外候选生效后等待对应样本
					end
				end
				ST_DCS_IR_WAIT:begin
					if(flag_dcs_sample_qualified == 1'b1)begin
						if(flag_search_in_window == 1'b1)begin
							state_next = ST_NORMAL; // 红外搜索或重验证成功后恢复NORMAL
						end else if(flag_dcs_ir_search_has_next == 1'b1)begin
							state_next = ST_DCS_IR_APPLY; // 红外区间缩小后提交下一候选
						end else begin
							state_next = ST_FAULT; // 红外DCS搜索耗尽阻断运行
						end
					end
				end
				ST_NORMAL:begin
					if(flag_amb_check_start_allowed == 1'b1)begin
						state_next = ST_AMB_RECHECK; // 安全接管后检查当前AMB码
					end
				end
				ST_AMB_RECHECK:begin
					if(flag_amb_sample_qualified == 1'b1)begin
						if(flag_search_in_window == 1'b1)begin
							if(i_dcs_enable == 1'b1)begin
								state_next = ST_DCS_REVALIDATE_WAIT; // 当前AMB合格也必须继续三帧DC重新验证；RRC-05 强制序列严格AMB->DC_R->DC_IR，不允许跳过任一颜色阶段 @satisfies: RRC-05
							end else begin
								state_next = ST_NORMAL; // DCS禁用时周期AMB阶段单独完成
							end
						end else if(flag_amb_confirm_trigger == 1'b1)begin
							state_next = ST_AMB_APPLY; // 确认漂移后启动全范围二分重搜
						end
					end
				end
				ST_DCS_REVALIDATE_WAIT:begin
					if(i_dcs_revalidate_accept == 1'b1)begin
						state_next = ST_DCS_REVALIDATE_R; // 调度器接管后先检查红光DC
					end
				end
				ST_DCS_REVALIDATE_R:begin
					if(flag_dcs_sample_qualified == 1'b1)begin
						if(flag_search_in_window == 1'b1)begin
							state_next = ST_DCS_REVALIDATE_IR; // 当前红光码合格后检查红外
						end else if(flag_dcs_r_confirm_trigger == 1'b1)begin
							state_next = ST_DCS_R_APPLY; // 确认红光漂移后进行全范围搜索
						end
					end
				end
				ST_DCS_REVALIDATE_IR:begin
					if(flag_dcs_sample_qualified == 1'b1)begin
						if(flag_search_in_window == 1'b1)begin
							state_next = ST_NORMAL; // 两色均合格后恢复正式NORMAL
						end else if(flag_dcs_ir_confirm_trigger == 1'b1)begin
							state_next = ST_DCS_IR_APPLY; // 确认红外漂移后进入二分搜索
						end
					end
				end
				ST_FAULT:begin
					state_next = ST_FAULT;  // 阻断故障只能由STOP或新START解除
				end
				default:begin
					state_next = ST_FAULT;  // 非法状态编码进入安全阻断态
				end
			endcase
		end
	end

	//-----------状态任务处理区域-----------//
	// packed上下文组合更新按事件优先级处理提交、样本、取消和新START
	always@(*)begin
		reg_context_next = reg_context;     // 默认保持全部持久状态并避免锁存
		reg_context_next[CTX_AMB_UPDATE_BIT] = 1'b0; // 默认撤销上一拍AMB更新事件
		reg_context_next[CTX_DCS_R_UPDATE_BIT] = 1'b0; // 默认撤销上一拍红光更新事件
		reg_context_next[CTX_DCS_IR_UPDATE_BIT] = 1'b0; // 默认撤销上一拍红外更新事件
		reg_context_next[CTX_DCS_R_TRACK_ADJUST_BIT] = 1'b0; // 默认清除红光跟踪单拍
		reg_context_next[CTX_DCS_IR_TRACK_ADJUST_BIT] = 1'b0; // 默认清除红外跟踪单拍
		reg_context_next[CTX_AMB_SEQUENCE_DONE_BIT] = 1'b0; // 默认清除AMB序列完成事件
		reg_context_next[CTX_AMB_SEQUENCE_FAILED_BIT] = 1'b0; // 默认清除AMB序列失败事件
		reg_context_next[CTX_DCS_REVALIDATE_DONE_BIT] = 1'b0; // 默认清除DCS重验证完成事件
		reg_context_next[CTX_DCS_REVALIDATE_FAILED_BIT] = 1'b0; // 默认清除DCS重验证失败事件
		reg_context_next[CTX_CTRL_FAULT_EVENT_BIT] = 1'b0; // 默认清除故障episode单周期脉冲

		if(i_diag_clear_event == 1'b1)begin
			reg_context_next[CTX_PROTOCOL_ERROR_BIT] = 1'b0; // 状态清除不解除搜索耗尽阻断故障
		end

		if(flag_amb_commit == 1'b1)begin
			reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b0; // 安全沿释放AMB pending所有权
			if(flag_amb_commit_changes_code == 1'b1)begin
				reg_context_next[CTX_AMB_CODE_LSB +: C_IDAC_CODE_WIDTH] = candidate_amb_code; // 原子更新AMB committed码
				reg_context_next[CTX_AMB_EPOCH_LSB +: C_CODE_EPOCH_WIDTH] = amb_epoch_current + {{C_CODE_EPOCH_WIDTH - 1{1'b0}}, 1'b1}; // 实际改码递增AMB版本；RRC-07 确认漂移改码只在flag_amb_commit的安全边界这一拍发生，且只有真实改码才递增epoch；NRE-06 flag_amb_commit要求先进入AMB_RECHECK族状态，interval=0时结构性不可达，长跑期间AMB码与epoch原样保持 @satisfies: RRC-07, NRE-06
				reg_context_next[CTX_AMB_UPDATE_BIT] = 1'b1; // 报告AMB输出实际变化
				if(reg_context[CTX_AMB_RECHECK_ORIGIN_BIT] == 1'b1)begin
					reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b1; // 记录周期重搜曾改变AMB码
					reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b0; // AMB变化取消红光旧pending
					reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b0; // AMB变化取消红外旧pending
					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // AMB变化清除红光高侧证据
					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // AMB变化清除红光低侧证据
					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // AMB变化清除红外高侧证据
					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // AMB变化清除红外低侧证据
				end
			end
		end

		if(flag_dcs_r_commit == 1'b1)begin
			reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b0; // 安全沿释放红光DC pending
			reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 红光提交后清除高侧证据
			reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 红光提交后清除低侧证据
			if(flag_dcs_r_commit_changes_code == 1'b1)begin
				reg_context_next[CTX_DCS_R_CODE_LSB +: C_IDAC_CODE_WIDTH] = candidate_dcs_r_code; // 更新红光DC committed码；ISE-08 本if由flag_dcs_r_commit独立门控，与下方888行flag_dcs_ir_commit分属两套互不相关的pending/committed/epoch字段，交错事务下红光提交不触碰红外的任何寄存位 @satisfies: ISE-08
				reg_context_next[CTX_DCS_R_EPOCH_LSB +: C_CODE_EPOCH_WIDTH] = dcs_r_epoch_current + {{C_CODE_EPOCH_WIDTH - 1{1'b0}}, 1'b1}; // 红光实际改码递增版本；TRK-07 安全边界仅对真实改变的±1LSB候选原子提交并加一epoch;TRK-08 普通4-bit截断加法,4'hF->4'h0自动回绕,身份随reg_context整体原子更新;ISE-10 同一截断加法逻辑覆盖ISE-10要求的"从4'hF实际提交一次回绕到4'h0"场景,回绕后epoch与878行同一reg_context原子更新的committed码保持绑定,不会出现epoch与码分离 @satisfies: TRK-07, TRK-08, ISE-10
				reg_context_next[CTX_DCS_R_UPDATE_BIT] = 1'b1; // 产生红光DC码更新事件
				if(reg_context[CTX_DCS_R_PENDING_TRACK_BIT] == 1'b1)begin
					reg_context_next[CTX_DCS_R_TRACK_ADJUST_BIT] = 1'b1; // 仅NORMAL来源产生track adjust；TRK-07 pending-track标记确保该安全边界只为NORMAL跟踪来源脉冲一次track-adjust事件,搜索/重验证来源不触发 @satisfies: TRK-07
				end
			end
			reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0; // 提交后清除红光候选来源
		end

		if(flag_dcs_ir_commit == 1'b1)begin
			reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b0; // 安全沿释放红外DC pending
			reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 红外提交后清除高侧证据
			reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 红外提交后清除低侧证据
			if(flag_dcs_ir_commit_changes_code == 1'b1)begin
				reg_context_next[CTX_DCS_IR_CODE_LSB +: C_IDAC_CODE_WIDTH] = candidate_dcs_ir_code; // 更新红外DC committed码；ISE-08 本if由flag_dcs_ir_commit独立门控，与上方873行flag_dcs_r_commit分属两套互不相关的pending/committed/epoch字段，交错事务下红外提交不触碰红光的任何寄存位 @satisfies: ISE-08
				reg_context_next[CTX_DCS_IR_EPOCH_LSB +: C_CODE_EPOCH_WIDTH] = dcs_ir_epoch_current + {{C_CODE_EPOCH_WIDTH - 1{1'b0}}, 1'b1}; // 红外实际改码递增版本
				reg_context_next[CTX_DCS_IR_UPDATE_BIT] = 1'b1; // 产生红外DC码更新事件
				if(reg_context[CTX_DCS_IR_PENDING_TRACK_BIT] == 1'b1)begin
					reg_context_next[CTX_DCS_IR_TRACK_ADJUST_BIT] = 1'b1; // 标记红外慢速跟踪提交
				end
			end
			reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0; // 提交后清除红外候选来源
		end

		if((state_current == ST_MANUAL_APPLY) && (i_frame_safe_boundary == 1'b1))begin
			reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b1; // 三路启动码处理后建立运行资格
		end

		if((state_current == ST_AMB_WAIT) && (flag_amb_sample_qualified == 1'b1))begin
			if(flag_search_in_window == 1'b1)begin
				reg_context_next[CTX_AMB_SEARCH_DONE_BIT] = 1'b1; // 当前AMB候选由窗口样本确认
				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0; // 成功后清除AMB高侧确认计数
				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0; // 成功后清除AMB低侧确认计数
				if(reg_context[CTX_AMB_RECHECK_ORIGIN_BIT] == 1'b1)begin
					reg_context_next[CTX_AMB_SEQUENCE_DONE_BIT] = 1'b1; // 周期AMB重搜成功报告done
					reg_context_next[CTX_AMB_RECHECK_ORIGIN_BIT] = 1'b0; // 结束周期AMB搜索上下文
				end else if(i_dcs_enable == 1'b1)begin
					reg_context_next[CTX_DCS_R_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_min; // 初始化红光DCS搜索下界
					reg_context_next[CTX_DCS_R_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_max; // 初始化红光DCS搜索上界
					reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_initial_midpoint; // 形成红光首个二分候选
					reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1; // 红光候选等待安全边界
					reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0; // 启动搜索候选不属于慢速跟踪
				end else begin
					reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b1; // 无DCS路径时AMB成功即完成启动
				end
			end else if(flag_amb_search_has_next == 1'b1)begin
				reg_context_next[CTX_AMB_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = amb_next_low; // 保存缩小后的AMB下界
				reg_context_next[CTX_AMB_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = amb_next_high; // 保存缩小后的AMB上界
				reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = amb_next_midpoint; // 形成下一AMB候选
				reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1; // 下一AMB候选等待提交
			end else begin
				reg_context_next[CTX_AMB_SEARCH_DONE_BIT] = 1'b0; // 搜索耗尽撤销AMB成功状态
				reg_context_next[CTX_AMB_EXHAUSTED_BIT] = 1'b1; // 锁存AMB搜索耗尽状态；SID-12 反转阈值窗口逼出AMB区间耗尽时锁存该sticky @satisfies: SID-12
				reg_context_next[CTX_AMB_FAULT_BIT] = 1'b1; // AMB耗尽阻断正式NORMAL；SID-12 耗尽故障阻断startup_search_complete与后续NORMAL @satisfies: SID-12
				if(reg_context[CTX_AMB_RECHECK_ORIGIN_BIT] == 1'b1)begin
					reg_context_next[CTX_AMB_SEQUENCE_FAILED_BIT] = 1'b1; // 周期AMB重搜失败报告事件
				end
			end
		end

		if((state_current == ST_DCS_R_WAIT) && (flag_dcs_sample_qualified == 1'b1))begin
			if(flag_search_in_window == 1'b1)begin
				reg_context_next[CTX_DCS_R_SEARCH_DONE_BIT] = 1'b1; // 红光当前候选通过窗口确认
				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 清除红光搜索高侧证据
				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 清除红光搜索低侧证据
				if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b0)begin
					reg_context_next[CTX_DCS_IR_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_ir_code_min; // 初始化红外启动搜索下界
					reg_context_next[CTX_DCS_IR_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_ir_code_max; // 初始化红外启动搜索上界
					reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_initial_midpoint; // 形成红外首个候选
					reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1; // 红外启动候选等待提交
					reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0; // 红外搜索候选标记为非tracking
				end
			end else if(flag_dcs_r_search_has_next == 1'b1)begin
				reg_context_next[CTX_DCS_R_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_next_low; // 保存红光新区间下界
				reg_context_next[CTX_DCS_R_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_next_high; // 保存红光新区间上界
				reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_next_midpoint; // 形成红光下一候选
				reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1; // 红光下一候选等待安全沿
			end else begin
				reg_context_next[CTX_DCS_R_SEARCH_DONE_BIT] = 1'b0; // 红光搜索耗尽撤销done
				reg_context_next[CTX_DCS_R_EXHAUSTED_BIT] = 1'b1; // 锁存红光搜索耗尽
				reg_context_next[CTX_DCS_R_FAULT_BIT] = 1'b1; // 红光路径进入阻断故障
				if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b1)begin
					reg_context_next[CTX_DCS_REVALIDATE_FAILED_BIT] = 1'b1; // DCS重验证报告红光失败
				end
			end
		end

		if((state_current == ST_DCS_IR_WAIT) && (flag_dcs_sample_qualified == 1'b1))begin
			if(flag_search_in_window == 1'b1)begin
				reg_context_next[CTX_DCS_IR_SEARCH_DONE_BIT] = 1'b1; // 红外当前候选通过窗口确认
				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 清除红外搜索高侧证据
				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 清除红外搜索低侧证据
				if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b1)begin
					reg_context_next[CTX_DCS_REVALIDATE_DONE_BIT] = 1'b1; // 两色重验证成功报告done
					reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b0; // 结束DCS重验证搜索上下文
				end else begin
					reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b1; // 红外启动搜索成功完成全部初始化；SID-12 AMB/DC_R/DC_IR三阶段闭合后置位完成资格，先于任何NORMAL owner提交 @satisfies: SID-12
				end
			end else if(flag_dcs_ir_search_has_next == 1'b1)begin
				reg_context_next[CTX_DCS_IR_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_next_low; // 保存红外新区间下界
				reg_context_next[CTX_DCS_IR_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_next_high; // 保存红外新区间上界
				reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_next_midpoint; // 形成红外下一候选
				reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1; // 红外下一候选等待提交
			end else begin
				reg_context_next[CTX_DCS_IR_SEARCH_DONE_BIT] = 1'b0; // 红外搜索耗尽撤销done
				reg_context_next[CTX_DCS_IR_EXHAUSTED_BIT] = 1'b1; // 锁存红外搜索耗尽
				reg_context_next[CTX_DCS_IR_FAULT_BIT] = 1'b1; // 红外路径进入阻断故障
				if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b1)begin
					reg_context_next[CTX_DCS_REVALIDATE_FAILED_BIT] = 1'b1; // DCS重验证报告红外失败
				end
			end
		end

		if((state_current == ST_AMB_RECHECK) && (flag_amb_sample_qualified == 1'b1))begin
			if(flag_search_in_window == 1'b1)begin
				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0; // 当前AMB码合格时清除高侧证据
				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0; // 当前AMB码合格时清除低侧证据
				reg_context_next[CTX_AMB_SEQUENCE_DONE_BIT] = 1'b1; // 无需调码直接完成周期检查；RRC-06 窗口内不变AMB样本保持已提交码/epoch，不触发flag_amb_commit @satisfies: RRC-06
			end else if(flag_amb_confirm_trigger == 1'b1)begin
				reg_context_next[CTX_AMB_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_amb_code_min; // 重搜恢复完整AMB下界
				reg_context_next[CTX_AMB_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_amb_code_max; // 重搜恢复完整AMB上界
				reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = amb_initial_midpoint; // 形成周期重搜首个候选
				reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1; // 周期重搜候选等待安全提交
				reg_context_next[CTX_AMB_RECHECK_ORIGIN_BIT] = 1'b1; // 标记后续AMB搜索属于周期序列
				reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b0; // 新重搜尚未实际改变AMB码
				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0; // 进入二分前清除高侧确认数
				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0; // 进入二分前清除低侧确认数
			end else if(flag_search_above_high == 1'b1)begin
				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = cnt_amb_high + 8'd1; // 同向高侧样本继续累计
				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0; // 高侧证据清除旧低侧序列
			end else begin
				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = cnt_amb_low + 8'd1; // 同向低侧样本继续累计
				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0; // 低侧证据清除旧高侧序列
			end
		end

		if((state_current == ST_DCS_REVALIDATE_WAIT) && (i_dcs_revalidate_accept == 1'b1))begin
			reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 重验证开始前清除红光高侧旧证据
			reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 重验证开始前清除红光低侧旧证据
			reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 重验证开始前清除红外高侧旧证据
			reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 重验证开始前清除红外低侧旧证据
			reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b1; // 标记后续DCS搜索属于重验证流程
		end

		if((state_current == ST_DCS_REVALIDATE_R) && (flag_dcs_sample_qualified == 1'b1))begin
			if(flag_search_in_window == 1'b1)begin
				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 当前红光码合格后清除高侧证据
				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 当前红光码合格后清除低侧证据
			end else if(flag_dcs_r_confirm_trigger == 1'b1)begin
				reg_context_next[CTX_DCS_R_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_min; // 重搜恢复红光完整下界
				reg_context_next[CTX_DCS_R_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_max; // 重搜恢复红光完整上界
				reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_initial_midpoint; // 形成红光重搜首个候选
				reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1; // 红光重搜候选等待安全沿
				reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0; // 重验证搜索不产生track adjust
				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 进入搜索前清除红光高侧计数
				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 进入搜索前清除红光低侧计数
			end else if(flag_search_above_high == 1'b1)begin
				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = cnt_dcs_r_high + 8'd1; // 红光重验证高侧证据加一
				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 高侧证据切断红光低侧序列
			end else begin
				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = cnt_dcs_r_low + 8'd1; // 红光重验证低侧证据加一
				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 低侧证据切断红光高侧序列
			end
		end

		if((state_current == ST_DCS_REVALIDATE_IR) && (flag_dcs_sample_qualified == 1'b1))begin
			if(flag_search_in_window == 1'b1)begin
				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 当前红外码合格后清除高侧证据
				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 当前红外码合格后清除低侧证据
				reg_context_next[CTX_DCS_REVALIDATE_DONE_BIT] = 1'b1; // 当前码无需重搜即可完成两色验证
				reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b0; // 结束DCS重验证上下文
			end else if(flag_dcs_ir_confirm_trigger == 1'b1)begin
				reg_context_next[CTX_DCS_IR_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_ir_code_min; // 重搜恢复红外完整下界
				reg_context_next[CTX_DCS_IR_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_ir_code_max; // 重搜恢复红外完整上界
				reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_initial_midpoint; // 形成红外重搜首个候选
				reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1; // 红外重搜候选等待安全沿
				reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0; // 重验证搜索不属于NORMAL跟踪
				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 进入搜索前清除红外高侧计数
				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 进入搜索前清除红外低侧计数
			end else if(flag_search_above_high == 1'b1)begin
				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = cnt_dcs_ir_high + 8'd1; // 红外重验证高侧证据加一
				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 高侧证据切断红外低侧序列
			end else begin
				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = cnt_dcs_ir_low + 8'd1; // 红外重验证低侧证据加一
				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 低侧证据切断红外高侧序列
			end
		end

		if(flag_track_sample_qualified == 1'b1)begin
			if(i_track_color_ir == 1'b0)begin
				if(flag_track_in_window == 1'b1)begin
					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 红光窗口内样本清除高侧证据；TRK-02 窗口内证据清零本方向计数;TRK-04 分支仅触碰CTX_DCS_R_*位,与红外分支结构隔离 @satisfies: TRK-02, TRK-04
					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 红光窗口内样本清除低侧证据
				end else if(flag_dcs_r_confirm_trigger == 1'b1)begin
					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 达到确认数后清除红光高侧计数
					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 达到确认数后清除红光低侧计数
					if(flag_dcs_r_adjust_allowed == 1'b1)begin
						reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = flag_dcs_code_increase ?
							(dcs_r_code_current + {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}) :
							(dcs_r_code_current - {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}); // 形成相邻1 LSB红光候选
						reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1; // 红光跟踪候选等待安全提交
						reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b1; // 标记红光候选来自NORMAL跟踪
					end
				end else if(flag_track_above_high == 1'b1)begin
					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = cnt_dcs_r_high + 8'd1; // 红光同向高侧证据加一
					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 高侧样本清除红光低侧序列；TRK-03 方向反转即时清空另一侧计数,新方向从零起步 @satisfies: TRK-03
				end else begin
					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = cnt_dcs_r_low + 8'd1; // 红光同向低侧证据加一
					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 低侧样本清除红光高侧序列；TRK-03 同上,低转高清空高侧历史后该样本自身当拍计入新方向为1,不产生两次pending @satisfies: TRK-03
				end
			end else begin
				if(flag_track_in_window == 1'b1)begin
					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 红外窗口内样本清除高侧证据；TRK-04 红外分支独立只触碰CTX_DCS_IR_*位,与红光互不干扰(对称验证) @satisfies: TRK-04
					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 红外窗口内样本清除低侧证据
				end else if(flag_dcs_ir_confirm_trigger == 1'b1)begin
					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 达到确认数后清除红外高侧计数
					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 达到确认数后清除红外低侧计数
					if(flag_dcs_ir_adjust_allowed == 1'b1)begin
						reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = flag_dcs_code_increase ?
							(dcs_ir_code_current + {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}) :
							(dcs_ir_code_current - {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}); // 形成相邻1 LSB红外候选
						reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1; // 红外跟踪候选等待安全提交
						reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b1; // 标记红外候选来自NORMAL跟踪
					end
				end else if(flag_track_above_high == 1'b1)begin
					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = cnt_dcs_ir_high + 8'd1; // 红外同向高侧证据加一
					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 高侧样本清除红外低侧序列
				end else begin
					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = cnt_dcs_ir_low + 8'd1; // 红外同向低侧证据加一
					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 低侧样本清除红外高侧序列
				end
			end
		end

		if(flag_amb_check_start_allowed == 1'b1)begin
			reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0; // 新周期检查清除AMB高侧历史
			reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0; // 新周期检查清除AMB低侧历史
			reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b0; // 周期开始时尚未改动AMB码
		end

		if(flag_protocol_event == 1'b1)begin
			reg_context_next[CTX_PROTOCOL_ERROR_BIT] = 1'b1; // 新协议错误优先于同拍状态清除
		end

		if(flag_control_cancel == 1'b1)begin
			reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b0; // STOP或abort取消AMB pending；LFA-01"STOP取消未提交候选、已提交码不变"的真实清除点 @satisfies: LFA-01
			reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b0; // STOP或abort取消红光pending
			reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b0; // STOP或abort取消红外pending
			reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0; // 清除红光候选来源标记
			reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0; // 清除红外候选来源标记
			reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 取消时清除红光高侧证据
			reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 取消时清除红光低侧证据
			reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 取消时清除红外高侧证据
			reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 取消时清除红外低侧证据
			reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0; // 取消时清除AMB高侧确认
			reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0; // 取消时清除AMB低侧确认
			reg_context_next[CTX_AMB_RECHECK_ORIGIN_BIT] = 1'b0; // 终止周期AMB搜索上下文
			reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b0; // 终止DCS重验证上下文
			reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b0; // 取消后丢弃未完成的AMB变化记录
			reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b0; // 离开RUN撤销启动完成资格；LFA-12下一次合法START必须从这个清零状态真实重新搜索、不带陈旧完成标记 @satisfies: LFA-12
			// 合同PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md 11.3节明确规定：
			// o_amb_fault/o_dcs_r_fault/o_dcs_ir_fault只在STOP/abort终止动作使本地
			// o_idac_idle=1且相应活动根因不再存在后撤销，或由异步复位撤销；296-297行
			// 进一步明确"新START不得清除活动或历史阻断故障"。上面flag_control_cancel
			// 分支本身就已经原子撤销了对应的pending/origin上下文（活动根因随之消失），
			// state_next也在同一拍无条件回到ST_IDLE（见下方状态机块），o_idac_idle在
			// 下一拍即可读到真——在这里清除三个FAULT位完全符合"STOP/abort+idle+根因
			// 已消失"这三个条件。这是Stage 5 Group 8（RRC-11失败恢复路径）真实confirmed
			// 出的一个功能性死锁修复：修复前FAULT位只在i_start_ack_event那一拍清零
			// （合同明确禁止的路径），但i_start_ack_event本身又被这三个位经AMI汇总到
			// o_system_fault_blocking后反过来阻断——STOP/abort/COMMIT/START/diag_clear
			// 组成的任何软件序列都无法解除，真实xsim confirmed跑到o_start_ready永久为0。
			reg_context_next[CTX_AMB_FAULT_BIT] = 1'b0; // STOP/abort终止动作后撤销AMB路径阻断故障
			reg_context_next[CTX_DCS_R_FAULT_BIT] = 1'b0; // 同上，红光DCS路径
			reg_context_next[CTX_DCS_IR_FAULT_BIT] = 1'b0; // 同上，红外DCS路径
			if(i_stop_ack_event || (i_run_enable == 1'b0))begin
				reg_context_next[CTX_AMB_SEARCH_DONE_BIT] = 1'b0; // STOP清除本RUN的AMB成功状态
				reg_context_next[CTX_DCS_R_SEARCH_DONE_BIT] = 1'b0; // STOP清除本RUN红光成功状态
				reg_context_next[CTX_DCS_IR_SEARCH_DONE_BIT] = 1'b0; // STOP清除本RUN红外成功状态
				reg_context_next[CTX_AMB_EXHAUSTED_BIT] = 1'b0; // STOP结束AMB耗尽run-scoped状态
				reg_context_next[CTX_DCS_R_EXHAUSTED_BIT] = 1'b0; // STOP结束红光耗尽run-scoped状态
				reg_context_next[CTX_DCS_IR_EXHAUSTED_BIT] = 1'b0; // STOP结束红外耗尽run-scoped状态
			end
		end

		if(i_start_ack_event == 1'b1)begin
			reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b0; // 新RUN先清除上一轮AMB pending
			reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b0; // 新RUN先清除上一轮红光pending
			reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b0; // 新RUN先清除上一轮红外pending
			reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0; // 新RUN清除红光候选来源
			reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0; // 新RUN清除红外候选来源
			reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0; // 启动前清除红光高侧证据
			reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0; // 启动前清除红光低侧证据
			reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0; // 启动前清除红外高侧证据
			reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0; // 启动前清除红外低侧证据
			reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0; // 启动前清除AMB高侧证据
			reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0; // 启动前清除AMB低侧证据
			reg_context_next[CTX_AMB_RECHECK_ORIGIN_BIT] = 1'b0; // 新RUN不是周期AMB上下文
			reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b0; // 新RUN不是DCS重验证上下文
			reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b0; // 启动时清除AMB变化历史
			reg_context_next[CTX_AMB_SEARCH_DONE_BIT] = 1'b0; // 新RUN重新建立AMB搜索资格
			reg_context_next[CTX_DCS_R_SEARCH_DONE_BIT] = 1'b0; // 新RUN重新建立红光搜索资格
			reg_context_next[CTX_DCS_IR_SEARCH_DONE_BIT] = 1'b0; // 新RUN重新建立红外搜索资格
			reg_context_next[CTX_AMB_EXHAUSTED_BIT] = 1'b0; // 新RUN清除旧AMB耗尽状态
			reg_context_next[CTX_DCS_R_EXHAUSTED_BIT] = 1'b0; // 新RUN清除旧红光耗尽状态
			reg_context_next[CTX_DCS_IR_EXHAUSTED_BIT] = 1'b0; // 新RUN清除旧红外耗尽状态
			// 合同11.3/296-297行明确禁止新START清除活动或历史阻断故障——三个FAULT位
			// 已经改为在上面flag_control_cancel块（STOP/abort终止动作）里撤销，这里
			// 不再重复清零，避免START本身成为清除路径（原V2.2版本在这里清零，是
			// Stage 5 Group 8真实confirmed出的死锁根因之一：见上方flag_control_cancel
			// 块的详细changelog说明）。下面非法START仍可以原子把它们重新置1，这是
			// START自己新建故障，不是清除故障，合同没有禁止
			reg_context_next[CTX_PROTOCOL_ERROR_BIT] = 1'b0; // 新RUN清除旧协议诊断历史
			reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b0; // 初始化结束前禁止正式NORMAL
			if((i_run_enable == 1'b0) || (flag_config_valid == 1'b0))begin
				reg_context_next[CTX_AMB_FAULT_BIT] = 1'b1; // 非法START置AMB阻断故障
				reg_context_next[CTX_DCS_R_FAULT_BIT] = i_dcs_enable; // 启用红光路径时同步阻断
				reg_context_next[CTX_DCS_IR_FAULT_BIT] = i_dcs_enable; // 启用红外路径时同步阻断
			end else if(i_idac_mode == 2'b00)begin
				reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = i_amb_enable ? i_amb_manual_code : C_RESET_CODE; // 形成AMB手动或禁用安全码
				reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_enable ? i_dcs_r_manual_code : C_RESET_CODE; // 形成红光手动或安全码
				reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_enable ? i_dcs_ir_manual_code : C_RESET_CODE; // 形成红外手动或安全码
				reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1; // AMB启动码等待首个安全沿
				reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1; // 红光启动码等待首个安全沿
				reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1; // 红外启动码等待首个安全沿
			end else begin
				if(i_amb_enable == 1'b1)begin
					reg_context_next[CTX_AMB_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_amb_code_min; // 初始化AMB启动搜索下界
					reg_context_next[CTX_AMB_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_amb_code_max; // 初始化AMB启动搜索上界
					reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = amb_initial_midpoint; // 形成AMB启动首个候选
					reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1; // AMB首个候选等待安全边界
				end else begin
					reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = C_RESET_CODE; // 禁用AMB路径装入安全码
					reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1; // 禁用AMB安全码仍经边界提交
				end
				if(i_dcs_enable == 1'b0)begin
					reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = C_RESET_CODE; // 禁用DCS时红光码回安全值
					reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = C_RESET_CODE; // 禁用DCS时红外码回安全值
					reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1; // 红光禁用安全码等待边界
					reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1; // 红外禁用安全码等待边界
				end else if(i_amb_enable == 1'b0)begin
					reg_context_next[CTX_DCS_R_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_min; // AMB禁用时初始化红光下界
					reg_context_next[CTX_DCS_R_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_max; // AMB禁用时初始化红光上界
					reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_initial_midpoint; // 形成红光启动首个候选
					reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1; // 红光首个候选等待安全边界
				end
			end
		end

		//===================<代际锁存>===================//
		if(reg_context_next[CTX_AMB_PENDING_VALID_BIT] == 1'b1 && reg_context[CTX_AMB_PENDING_VALID_BIT] == 1'b0)begin
			reg_context_next[CTX_AMB_PENDING_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] = i_run_generation; // 新建AMB候选时原子锁存当前RUN代际
		end
		if(reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] == 1'b1 && reg_context[CTX_DCS_R_PENDING_VALID_BIT] == 1'b0)begin
			reg_context_next[CTX_DCS_R_PENDING_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] = i_run_generation; // 新建红光DC候选时原子锁存当前RUN代际
		end
		if(reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] == 1'b1 && reg_context[CTX_DCS_IR_PENDING_VALID_BIT] == 1'b0)begin
			reg_context_next[CTX_DCS_IR_PENDING_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] = i_run_generation; // 新建红外DC候选时原子锁存当前RUN代际
		end

		//===================<故障记录捕获>===================//
		if((reg_context_next[CTX_AMB_FAULT_BIT] || reg_context_next[CTX_DCS_R_FAULT_BIT] || reg_context_next[CTX_DCS_IR_FAULT_BIT]) && !(reg_context[CTX_AMB_FAULT_BIT] || reg_context[CTX_DCS_R_FAULT_BIT] || reg_context[CTX_DCS_IR_FAULT_BIT]))begin
			reg_context_next[CTX_CTRL_FAULT_EVENT_BIT] = 1'b1; // 三路故障首次跳变，向supervisor拉出一拍valid
			if(i_start_ack_event == 1'b1)begin
				reg_context_next[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] = 1'b0; // 非法START无具体搜索样本身份可报告
			end else begin
				reg_context_next[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] = 1'b1; // 搜索耗尽时绑定当前搜索样本身份
				reg_context_next[CTX_CTRL_FAULT_FRAME_ID_LSB +: C_FRAME_ID_WIDTH] = i_search_frame_id; // 快照耗尽时刻的搜索样本帧号
				reg_context_next[CTX_CTRL_FAULT_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH] = i_search_sample_index; // 快照耗尽时刻的搜索样本序号
				reg_context_next[CTX_CTRL_FAULT_COLOR_BIT] = i_search_color_ir; // 快照耗尽时刻的搜索样本颜色
				reg_context_next[CTX_CTRL_FAULT_FRAME_TYPE_LSB +: 2] = i_search_frame_type; // 快照耗尽时刻的搜索样本类型
				reg_context_next[CTX_CTRL_FAULT_PRECISION_BIT] = i_search_precision_mode; // 快照耗尽时刻的搜索样本精度
				reg_context_next[CTX_CTRL_FAULT_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] = i_run_generation; // 快照耗尽时刻的实时RUN代际
			end
		end
	end

	//-----------主要任务处理区域-----------//
	// packed上下文在单一时序目标中原子保存所有码、计数和状态事件
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_context <= {CONTEXT_WIDTH{1'b0}}; // 复位三码、epoch、pending及故障全部清零
		end else begin
			reg_context <= reg_context_next; // 当前拍所有合法事件原子形成下一上下文
		end
	end

endmodule
