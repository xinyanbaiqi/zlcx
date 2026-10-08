`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026/08/14 00:00:00
// Design Name: 	PPG SAR9/SAR15 Safe Selection Wrapper
// Module Name: 	ppg_sar9_sar15_safe_selection_wrapper
// Description: 	V1.3 split waveform-context and ADC-owner timing selector.
// Dependencies:
// Scheduler V1.3 and AMI V1.3 completion sideband.
// 调度器V1.3及AMI V1.3完成旁带
// Simulations:		tb_ppg_sar9_sar15_safe_selection_wrapper.v
//
// Referrences:		PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//
//
// Version:			V1.8
// Revision Date:	2026/10/08 00:00:00
// History:
//    Time			   Version	   Revised by			Contents
// 2026/08/14          V1.2          Codex       Single-fire timing selector.
// 2026/08/15          V1.3        Codex       Split contexts, owner, and IDAC precision isolation.
// 2026/08/22          V1.4        Erie        Add i_run_generation with atomic waveform/owner-context tagging and stale-generation match/release rejection, and add the registered o_ssw_fault_* record group (cause 8'h21 only, mapped from the existing switch-protocol/transaction-mismatch stickies) for the system fault/abort supervisor, per PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md section 7.9. Cause 8'h22 (independent analog-safe convergence detector) is intentionally not implemented; the contract gives no concrete trigger condition and one was not designed in this pass.
// 2026/09/10          V1.5        Erie        AMB_CAL local tick [262,264) CTRL_Q2 gated to only pulse when reg_cal_frame_type==FRAME_TYPE_DCS; AMB_CAL no longer drives Q2 at all, per PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md section 6.4. Root cause: AMB code-value calibration judges candidates on the Q2/Q3 chopping-cancelled net value, but that cancellation is structurally insensitive to symmetric ambient residual present in both phases, so it never surfaces how much integrator headroom the candidate actually consumed short of hard saturation. DCS_CAL is unaffected because its LED is Q3-only, so Q2/Q3 are asymmetric there and chopping subtraction fully preserves the LED residual instead of masking it. CTRL_Q3 and all AMB_CAL AFERST/TIAEN/Q1_9 timing windows are unchanged.
// 2026/10/06          V1.6        Erie        ABCD review F-035: in adc_owner_inflight_o and reg_owner_abort_seen the matching-completion release now has priority over the abort hold. Previously an abort and a matching DONE in the same cycle kept the owner in flight forever (no later DONE can arrive, and a new owner needs !inflight), so measurement stopped until reset. Abort still cancels the waveform context and commit is still blocked during abort; owner identity registers hold in both branches as before.
// 2026/10/07          V1.7        Erie        Owner-lifecycle round. New input i_adc_transaction_lost_event releases the owner by the same index/generation match as a completion (unmatched void counts as transaction mismatch). Owner binding (S1/L-1): flag_red/ir/cal_has_owner now also require the owner to belong to the current context (frame id; for CAL also the new reg_owner_cal_subframe), so a stale owner neither drives the next context's Q3 nor masks its deadline. S1: calibration_timeout_sticky now sets when the owner bound to this subframe is still in flight at local tick 385 (late-read diagnostic, non-blocking).
// 2026/10/08          V1.8        Erie        ABCD N-2 (no contract ID; found by the F-009 round regression, pre-existing): if STOP is acknowledged after a RED/IR/CAL waveform context is taken over but before its owner is committed, STOPPING completes immediately (ADC idle, datapath empty), and a START that follows before the waveform's last tick previously left the uncommitted context valid forever (it is released only at wave last or on abort, and the scheduler freezes the tick at 0 in STARTUP_PENDING), so o_sar_timing_idle stayed 0 and the new RUN stalled silently. New wire flag_start_restore = i_start_ack_event && !adc_owner_inflight_o && i_adc_idle replaces the old START-restore condition (start ack && o_wrapper_idle) at all six sites (reg_run_active, the four protocol stickies, flag_ssw_fault_identity_valid); on it flag_red/ir/cal_context_valid and flag_stop_pending are cleared like abort. Premise: STOPPING completion already requires ADC idle and an empty datapath, so no committed owner can be in flight at START. Waveform snapshot registers are only consumed while their context is valid, so they need no clearing.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026年08月14日
// 设计名称: 		PPG SAR9/SAR15 Safe Selection Wrapper
// 模块名称: 		ppg_sar9_sar15_safe_selection_wrapper
// 模块说明:		V1.3 split waveform-context and ADC-owner timing selector.
// 依赖文件:
// Scheduler V1.3 and AMI V1.3 completion sideband.
// 调度器V1.3及AMI V1.3完成旁带
// 仿真工程: 		tb_ppg_sar9_sar15_safe_selection_wrapper.v
//
// 参考资料:		PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//
//
// 当前版本:		V1.8
// 修订日期:		2026年10月08日
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026年08月14日     V1.2          Codex       单fire时序选择实现。
// 2026年08月15日     V1.3        Codex       上下文、owner及IDAC精度隔离重构。
// 2026年08月22日     V1.4        Erie          按合同7.9节新增i_run_generation，对波形上下文和物理owner原子锁存并在匹配/释放时校验代际；新增注册式o_ssw_fault_*故障记录组（仅实现cause 8'h21，映射自已有的switch_protocol_error/transaction_mismatch两个sticky）。cause 8'h22（独立模拟安全收敛检测器）本次未实现：合同未给出具体触发条件，本次也未设计新的检测逻辑。
// 2026年09月10日     V1.5        Erie          按合同6.4节：AMB_CAL local tick[262,264)的CTRL_Q2改为仅reg_cal_frame_type==FRAME_TYPE_DCS时才产生脉冲，AMB_CAL全程不再驱动Q2。根因：AMB码值校准依赖Q2/Q3两相chopping抵消后的净值判据，但该抵消机制对两相都存在的对称环境光残余结构性不敏感，只有真正物理clip到轨才能被抓到；DCS_CAL不受影响，因其LED仅Q3导通、Q2/Q3本就不对称，chopping相减恰好完整保留LED残余。CTRL_Q3及AMB_CAL全部AFERST/TIAEN/Q1_9时序窗口不变。
// 2026年10月06日     V1.6        Erie          ABCD复核F-035：adc_owner_inflight_o与reg_owner_abort_seen中匹配完成的释放改为优先于abort保持。此前abort与匹配DONE同拍时owner永久在途（之后不会再有DONE，新owner又要求!inflight），测量停到复位。abort仍撤销波形上下文、abort期间仍禁止提交；owner身份寄存器在两个分支都保持，与原来一致
// 2026年10月07日     V1.7        Erie          owner生命周期轮。新增输入i_adc_transaction_lost_event，按与完成相同的序号/代际匹配释放owner（不匹配的作废记事务错配）。owner绑定（S1/L-1）：flag_red/ir/cal_has_owner增加'owner属于当前上下文'条件（帧号，校准另加新寄存器reg_owner_cal_subframe），跨上下文残留的旧owner既不驱动新上下文Q3，也不掩盖其截止。S1：calibration_timeout_sticky改为'绑定本子帧的校准owner在local tick 385仍在途'时置位（读出迟到诊断，非阻断）。
// 2026年10月08日     V1.8        Erie          ABCD N-2（无合同编号，F-009轮回归发现，既有缺陷）：STOP确认落在RED/IR/CAL波形上下文已接管、owner尚未提交之间时，STOPPING立即完成（ADC空闲、数据链排空），若在波形末拍前再次START，未提交上下文原先只在波形末拍或abort时释放，而调度器STARTUP_PENDING冻结tick 0，上下文永不释放，o_sar_timing_idle恒0，新RUN静默卡死。新增连线flag_start_restore=i_start_ack_event&&!adc_owner_inflight_o&&i_adc_idle，替换六处原START恢复条件（启动确认&&o_wrapper_idle：reg_run_active、四个协议sticky、flag_ssw_fault_identity_valid）；该条件成立时与abort一样清除flag_red/ir/cal_context_valid与flag_stop_pending。前提：STOPPING完成已要求ADC空闲且数据链排空，START时不可能有已提交owner在途。波形快照寄存器只在对应上下文有效时被读取，无需清除。
module ppg_sar9_sar15_safe_selection_wrapper
#(
	parameter C_FRAME_ID_WIDTH = 16, // 模块参数专用字段帧标识位宽高位编码端
	parameter C_SAMPLE_INDEX_WIDTH = 16, // 模块参数专用字段采样序号位宽高位编码端低位编码端
	parameter C_IDAC_CODE_WIDTH = 8, // 模块参数专用字段电流数模数字码位宽高位编码端
	parameter C_CODE_EPOCH_WIDTH = 4, // 模块参数专用字段数字码版本位宽高位编码端
	parameter C_RUN_GENERATION_WIDTH = 8, // 模块参数专用字段manager唯一生产、经ACTIVE wrapper与Top透明扇出的RUN代际位宽
	parameter C_MACRO_TICK_WIDTH = 13, // 模块参数专用字段宏帧节拍位宽高位编码端
	parameter C_CAL_TICK_WIDTH = 10, // 模块参数专用字段校准节拍位宽高位编码端低位编码端
	parameter C_NORMAL_RED_OWNER_DEADLINE = 283, // 模块参数专用字段正常红光结果所有权截止红光专属可见光路低位编码端
	parameter C_NORMAL_IR_OWNER_DEADLINE = 443, // 模块参数专用字段正常红外结果所有权截止红外专属红外光路低位编码端红外帧所有权截止
	parameter C_CAL_OWNER_DEADLINE = 248, // 模块参数专用字段校准结果所有权截止低位编码端
	parameter integer C_ENABLE_TEST_INJECTION = 32'd0 // 默认关闭的验证专用接管反压注入结构生成使能，生产网表必须为0
)
(
	//-----------------全局信号-----------------//
	input i_clk,                                // 输入端输入时钟低位编码端
	input i_rstn,                               // 输入端输入低有效复位
	input i_run_enable,                         // 输入端输入运行使能低位编码端
	input i_start_ack_event,                    // 输入端输入启动确认事件
	input i_stop_ack_event,                     // 输入端输入停止确认事件
	input i_control_abort_event,                // 输入端输入控制字撤销事件低位编码端
	input i_diag_clear_event,                   // 输入端输入诊断清除事件低位编码端
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // 输入端输入manager经ACTIVE wrapper与Top扇出的当前RUN代际，陈旧代际不得释放owner或复活波形

	//-------------统一物理相位输入-------------//
	input [C_MACRO_TICK_WIDTH - 1:0]i_macro_tick, // 输入端输入宏帧节拍
	input [2:0]i_calibration_subframe_index,    // 输入端输入校准专用字段序号低位编码端
	input [C_CAL_TICK_WIDTH - 1:0]i_calibration_local_tick, // 输入端输入校准专用字段节拍低位编码端
	input i_normal_frame_active,                // 输入端输入正常帧活动低位编码端
	input i_calibration_frame_active,           // 输入端输入校准帧活动低位编码端
	input i_macro_frame_safe_boundary,          // 输入端输入宏帧帧安全专用字段
	input i_idac_code_safe_boundary,            // 输入端输入电流数模数字码安全专用字段

	//---------------运行配置输入---------------//
	input i_run_profile,                        // 输入端输入运行配置档案低位编码端
	input i_input_source,                       // 输入端输入输入来源
	input [1:0]i_optical_mode,                  // 输入端输入光学模式低位编码端
	input i_precision_mode_committed,           // 输入端输入精度模式已提交
	input i_static_characterization_enable,     // 输入端输入静态偏置表征使能高位编码端低位编码端
	input [4:0]i_test_mux_ctrl,                 // 输入端输入测试多路选择专用字段低位编码端

	//-------验证专用接管反压注入接口-------//
	input i_test_inject_enable,                 // 输入端验证构建请求注入模式，与C_ENABLE_TEST_INJECTION共同限定
	input i_context_handover_stall_request,     // 输入端请求在接管tick合法压低context ready，不构成协议违规

	//-----------调度器波形上下文通道-----------//
	input i_waveform_context_valid,             // 输入端输入波形上下文有效低位编码端
	output o_waveform_context_ready,            // 输出端输出波形上下文就绪
	input i_waveform_precision_mode,            // 输入端输入波形精度模式
	input [C_FRAME_ID_WIDTH - 1:0]i_waveform_frame_id, // 输入端输入波形帧标识
	input i_waveform_color_ir,                  // 输入端输入波形颜色红外红外专属红外光路低位编码端
	input [1:0]i_waveform_frame_type,           // 输入端输入波形帧类型
	input [C_IDAC_CODE_WIDTH - 1:0]i_waveform_amb_code_snapshot, // 输入端输入波形环境数字码专用字段环境码通路高位编码端
	input [C_IDAC_CODE_WIDTH - 1:0]i_waveform_dc_code_snapshot, // 输入端输入波形直流数字码专用字段直流码通路高位编码端
	input [C_CODE_EPOCH_WIDTH - 1:0]i_waveform_amb_code_epoch, // 输入端输入波形环境数字码版本环境码通路高位编码端
	input [C_CODE_EPOCH_WIDTH - 1:0]i_waveform_dc_code_epoch, // 输入端输入波形直流数字码版本直流码通路高位编码端
	input i_waveform_input_source,              // 输入端输入波形输入来源
	input [1:0]i_waveform_optical_mode,         // 输入端输入波形光学模式低位编码端
	input [7:0]i_waveform_leddac_code_snapshot, // 输入端输入波形发光数模数字码专用字段高位编码端低位编码端

	//----------调度器ADC结果owner通道----------//
	output o_adc_owner_ready,                   // 输出端输出模数转换结果所有权就绪直流码通路
	input i_adc_owner_commit_event,             // 输入端输入模数转换结果所有权专用字段事件直流码通路
	input i_adc_owner_precision_mode,           // 输入端输入模数转换结果所有权精度模式直流码通路
	input [C_FRAME_ID_WIDTH - 1:0]i_adc_owner_frame_id, // 输入端输入模数转换结果所有权帧标识直流码通路
	input i_adc_owner_color_ir,                 // 输入端输入模数转换结果所有权颜色红外红外专属红外光路直流码通路低位编码端
	input [1:0]i_adc_owner_frame_type,          // 输入端输入模数转换结果所有权帧类型直流码通路
	input [C_IDAC_CODE_WIDTH - 1:0]i_adc_owner_amb_code_snapshot, // 输入端输入模数转换结果所有权环境数字码专用字段环境码通路直流码通路高位编码端
	input [C_IDAC_CODE_WIDTH - 1:0]i_adc_owner_dc_code_snapshot, // 输入端输入模数转换结果所有权直流数字码专用字段直流码通路高位编码端
	input [C_CODE_EPOCH_WIDTH - 1:0]i_adc_owner_amb_code_epoch, // 输入端输入模数转换结果所有权环境数字码版本环境码通路直流码通路高位编码端
	input [C_CODE_EPOCH_WIDTH - 1:0]i_adc_owner_dc_code_epoch, // 输入端输入模数转换结果所有权直流数字码版本直流码通路高位编码端
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_adc_owner_sample_index, // 输入端输入模数转换结果所有权采样序号直流码通路低位编码端

	//------------AMI完成与空闲旁带-------------//
	input i_adc_transaction_complete_event,     // 输入端输入模数转换事务完成事件直流码通路低位编码端
	input i_adc_transaction_success,            // 输入端输入模数转换事务成功直流码通路
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_adc_complete_sample_index, // 输入端输入模数转换完成采样序号直流码通路低位编码端
	input i_adc_transaction_lost_event,         // 输入端AMI在途owner完成丢失超时作废单拍，按序号与代际匹配释放owner
	input i_adc_idle,                           // 输入端输入模数转换空闲直流码通路低位编码端

	//---------------模拟控制输出---------------//
	output o_en_tia_low,                        // 输出端输出使能跨阻放大低有效低位编码端
	output [7:0]o_leddac,                       // 输出端输出发光数模低位编码端
	output o_leden1_low,                        // 输出端输出红光选择低有效低位编码端
	output o_leden2_low,                        // 输出端输出红外选择低有效低位编码端红外灯选通道
	output o_en_test,                           // 输出端输出使能测试
	output o_clk_buf_low,                       // 输出端输出时钟缓冲低有效低位编码端
	output o_clk_iref_idac_low,                 // 输出端输出时钟参考电流电流数模低有效低位编码端
	output o_clk_9q1_low,                       // 输出端输出时钟九位第一相位低有效低位编码端
	output o_clk_15q1_low,                      // 输出端输出时钟十五位第一相位低有效低位编码端
	output o_clk_aferst_low,                    // 输出端输出时钟前端复位低有效低位编码端
	output o_clk_iref_idac_sar9_low,            // 输出端输出时钟参考电流电流数模九位转换低有效九位转换专用低位编码端
	output o_clk_iref_idac_sar15_low,           // 输出端输出时钟参考电流电流数模十五位转换低有效十五位转换专用低位编码端
	output o_clk_q2_low,                        // 输出端输出时钟第二相位低有效低位编码端
	output o_clk_q3_low,                        // 输出端输出时钟第三相位低有效低位编码端第三相位采样中心
	output o_clk_tiaen_low,                     // 输出端输出时钟专用字段低有效低位编码端
	output o_en_15sar_low,                      // 输出端输出使能专用字段低有效低位编码端
	output o_en_sar9_amb_low,                   // 输出端输出使能九位转换环境低有效九位转换专用环境码通路低位编码端
	output o_en_sar9_dc_low,                    // 输出端输出使能九位转换直流低有效九位转换专用直流码通路低位编码端
	output o_en_sar9_iref,                      // 输出端输出使能九位转换参考电流九位转换专用
	output o_en_sar15_amb_low,                  // 输出端输出使能十五位转换环境低有效十五位转换专用环境码通路低位编码端
	output o_en_sar15_dc_low,                   // 输出端输出使能十五位转换直流低有效十五位转换专用直流码通路低位编码端
	output o_en_sar15_iref,                     // 输出端输出使能十五位转换参考电流十五位转换专用
	output [7:0]o_idac_sar9ambn_low,            // 输出端输出电流数模九位环境总线低有效九位转换专用环境码通路低位编码端
	output [7:0]o_idac_sar9dcn_low,             // 输出端输出电流数模九位直流总线低有效九位转换专用直流码通路低位编码端
	output [7:0]o_idac_sar15ambn_low,           // 输出端输出电流数模十五位环境总线低有效红外专属红外光路十五位转换专用环境码通路低位编码端
	output [7:0]o_idac_sar15dcn_low,            // 输出端输出电流数模十五位直流总线低有效红外专属红外光路十五位转换专用直流码通路低位编码端
	output [4:0]o_s_in,                         // 输出端输出观测选择专用字段
	output o_clk_2m,                            // 输出端输出时钟二兆赫兹低位编码端

	//--------------状态与诊断输出--------------//
	output o_analog_safe,                       // 输出端输出模拟安全低位编码端
	output o_sar_timing_idle,                   // 输出端输出专用字段时序空闲低位编码端
	output o_wrapper_idle,                      // 输出端输出封装空闲低位编码端
	output o_precision_active,                  // 输出端输出精度活动
	output o_calibration_wave_active,           // 输出端输出校准专用字段活动低位编码端
	output o_adc_owner_inflight,                // 输出端输出模数转换结果所有权在途直流码通路高位编码端低位编码端
	output o_owner_q3_window_closed,            // 输出端在途owner自身选定Q3窗口已关闭，供Scheduler门控completion身份匹配
	output o_switch_protocol_error_sticky,      // 输出端输出切换协议错误保持高位编码端低位编码端
	output o_transaction_mismatch_sticky,       // 输出端输出事务失配保持高位编码端
	output o_owner_deadline_timeout_sticky,     // 输出端输出结果所有权截止超时保持低位编码端
	output o_calibration_timeout_sticky,        // 输出端输出校准超时保持低位编码端
	output o_wrapper_fault_blocking,            // 输出端输出封装专用字段阻断低位编码端

	//---------------故障记录接口---------------//
	output o_ssw_fault_valid,                   // 输出端输出新故障episode单周期脉冲，供system fault/abort supervisor观测
	output o_ssw_fault_active,                  // 输出端输出注册式阻断持续状态，即wrapper_fault_blocking的本地根因部分
	output [7:0]o_ssw_fault_cause,              // 输出端输出固定8'h21，SSW身份/所有权协议错误原因码
	output o_ssw_fault_identity_valid,          // 输出端输出本次故障是否绑定了真实事务身份
	output [C_FRAME_ID_WIDTH - 1:0]o_ssw_fault_frame_id, // 输出端输出故障事务所属帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_ssw_fault_sample_index, // 输出端输出故障事务全局序号
	output o_ssw_fault_color_ir,                // 输出端输出故障事务颜色
	output [1:0]o_ssw_fault_frame_type,         // 输出端输出故障事务类型
	output o_ssw_fault_precision_mode,          // 输出端输出故障事务精度
	output [C_RUN_GENERATION_WIDTH - 1:0]o_ssw_fault_run_generation // 输出端输出故障事务所属RUN代际
);

	//---------------配置参数区域---------------//
	//frame_type参数
	localparam [1:0]FRAME_TYPE_AMB = 2'b00;     // 局部常量帧类型环境环境码通路
	localparam [1:0]FRAME_TYPE_DCS = 2'b01;     // 局部常量帧类型专用字段直流码通路
	localparam [1:0]FRAME_TYPE_NORMAL = 2'b10;  // 局部常量帧类型正常低位编码端

	//optical_mode参数
	localparam [1:0]OPTICAL_MODE_BOTH = 2'b00;  // 局部常量光学模式双光高位编码端低位编码端
	localparam [1:0]OPTICAL_MODE_RED_ONLY = 2'b01; // 局部常量光学模式红光单色红光专属可见光路低位编码端
	localparam [1:0]OPTICAL_MODE_IR_ONLY = 2'b10; // 局部常量光学模式红外单色红外专属红外光路低位编码端

	localparam RUN_PROFILE_NORMAL = 1'b0;       // 局部常量运行配置档案正常低位编码端
	localparam RUN_PROFILE_CHARACTERIZATION = 1'b1; // 局部常量运行配置档案表征高位编码端低位编码端

	//slot参数
	localparam [1:0]SLOT_RED = 2'd0;            // 局部常量槽位红光红光专属可见光路低位编码端
	localparam [1:0]SLOT_IR = 2'd1;             // 局部常量槽位红外红外专属红外光路低位编码端
	localparam [1:0]SLOT_CAL = 2'd2;            // 局部常量槽位校准低位编码端

	localparam [C_MACRO_TICK_WIDTH - 1:0]RED_Q3_TICK = 13'd300; // 局部常量红光第三相位节拍红光专属可见光路
	localparam [C_MACRO_TICK_WIDTH - 1:0]IR_Q3_TICK = 13'd460; // 局部常量红外第三相位节拍红外专属红外光路
	localparam [C_CAL_TICK_WIDTH - 1:0]CAL_Q3_TICK = 10'd266; // 局部常量校准第三相位节拍低位编码端；固定接管点，与local tick 0快照配合确认AMB/DCS正确性 @satisfies: TOP-04
	localparam [C_CAL_TICK_WIDTH - 1:0]CAL_COMMIT_TICK = 10'd385; // 局部常量校准专用字段节拍低位编码端
	localparam [31:0]CONTROL_WIDTH = 32'd72;    // 局部常量控制字位宽高位编码端低位编码端

	//ctrl参数
	localparam [31:0]CTRL_EN_TIA = 32'd0;       // 局部常量专用字段使能跨阻放大低位编码端
	localparam [31:0]CTRL_LED_R = 32'd1;        // 局部常量专用字段专用字段专用字段低位编码端
	localparam [31:0]CTRL_LED_IR = 32'd2;       // 局部常量专用字段专用字段红外红外专属红外光路低位编码端
	localparam [31:0]CTRL_CLK_BUF = 32'd4;      // 局部常量专用字段时钟缓冲低位编码端
	localparam [31:0]CTRL_IREF_IDAC = 32'd5;    // 局部常量专用字段参考电流电流数模低位编码端
	localparam [31:0]CTRL_Q1_9 = 32'd6;         // 局部常量专用字段第一相位九位九位转换专用低位编码端
	localparam [31:0]CTRL_Q1_15 = 32'd7;        // 局部常量专用字段第一相位十五十五位转换专用低位编码端
	localparam [31:0]CTRL_AFERST = 32'd8;       // 局部常量专用字段前端复位低位编码端
	localparam [31:0]CTRL_IREF_9 = 32'd9;       // 局部常量专用字段参考电流九位九位转换专用低位编码端
	localparam [31:0]CTRL_IREF_15 = 32'd10;     // 局部常量专用字段参考电流十五十五位转换专用低位编码端
	localparam [31:0]CTRL_Q2 = 32'd11;          // 局部常量专用字段第二相位低位编码端
	localparam [31:0]CTRL_Q3 = 32'd12;          // 局部常量专用字段第三相位低位编码端第三相位控制位
	localparam [31:0]CTRL_TIAEN = 32'd13;       // 局部常量专用字段专用字段低位编码端
	localparam [31:0]CTRL_EN_15 = 32'd14;       // 局部常量专用字段使能十五十五位转换专用低位编码端
	localparam [31:0]CTRL_EN_9_AMB = 32'd15;    // 局部常量专用字段使能九位环境九位转换专用环境码通路低位编码端
	localparam [31:0]CTRL_EN_9_DC = 32'd16;     // 局部常量专用字段使能九位直流九位转换专用直流码通路低位编码端
	localparam [31:0]CTRL_EN_9_IREF = 32'd17;   // 局部常量专用字段使能九位参考电流九位转换专用低位编码端
	localparam [31:0]CTRL_EN_15_AMB = 32'd18;   // 局部常量专用字段使能十五环境十五位转换专用环境码通路低位编码端
	localparam [31:0]CTRL_EN_15_DC = 32'd19;    // 局部常量专用字段使能十五直流十五位转换专用直流码通路低位编码端
	localparam [31:0]CTRL_EN_15_IREF = 32'd20;  // 局部常量专用字段使能十五参考电流十五位转换专用低位编码端
	localparam [31:0]CTRL_AMB9_L = 32'd21;      // 局部常量专用字段九位环境低端九位转换专用环境码通路低位编码端
	localparam [31:0]CTRL_AMB9_H = 32'd28;      // 局部常量专用字段九位环境高端九位转换专用环境码通路高位编码端低位编码端
	localparam [31:0]CTRL_DC9_L = 32'd29;       // 局部常量专用字段九位直流低端九位转换专用直流码通路低位编码端
	localparam [31:0]CTRL_DC9_H = 32'd36;       // 局部常量专用字段九位直流高端九位转换专用直流码通路高位编码端低位编码端
	localparam [31:0]CTRL_AMB15_L = 32'd37;     // 局部常量专用字段十五位环境低端十五位转换专用环境码通路低位编码端
	localparam [31:0]CTRL_AMB15_H = 32'd44;     // 局部常量专用字段十五位环境高端十五位转换专用环境码通路高位编码端低位编码端
	localparam [31:0]CTRL_DC15_L = 32'd45;      // 局部常量专用字段十五位直流低端十五位转换专用直流码通路低位编码端
	localparam [31:0]CTRL_DC15_H = 32'd52;      // 局部常量专用字段十五位直流高端十五位转换专用直流码通路高位编码端低位编码端
	localparam [31:0]CTRL_LED_CODE = 32'd53;    // 局部常量专用字段专用字段数字码低位编码端
	localparam [31:0]CTRL_LED_DATA_L = 32'd56;  // 局部常量专用字段专用字段数据低端低位编码端
	localparam [31:0]CTRL_LED_DATA_H = 32'd63;  // 局部常量专用字段专用字段数据高端高位编码端低位编码端
	localparam [31:0]CTRL_S_IN_L = 32'd64;      // 局部常量专用字段观测选择专用字段低端低位编码端
	localparam [31:0]CTRL_S_IN_H = 32'd68;      // 局部常量专用字段观测选择专用字段高端高位编码端低位编码端观测选择高端编码
	localparam [31:0]CTRL_EN_TEST = 32'd69;     // 局部常量专用字段使能测试低位编码端

	//----------------寄存器信号----------------//
	reg reg_run_active = 1'b0;                  // 时序寄存寄存运行活动
	reg reg_red_precision = 1'b0;               // 时序寄存寄存红光精度红光专属可见光路
	reg reg_ir_precision = 1'b0;                // 时序寄存寄存红外精度红外专属红外光路
	reg reg_cal_precision = 1'b0;               // 时序寄存寄存校准精度低位编码端
	reg [C_FRAME_ID_WIDTH - 1:0]reg_red_frame_id = {C_FRAME_ID_WIDTH{1'b0}}; // 时序寄存寄存红光帧标识红光专属可见光路
	reg [C_FRAME_ID_WIDTH - 1:0]reg_ir_frame_id = {C_FRAME_ID_WIDTH{1'b0}}; // 时序寄存寄存红外帧标识红外专属红外光路
	reg [C_FRAME_ID_WIDTH - 1:0]reg_cal_frame_id = {C_FRAME_ID_WIDTH{1'b0}}; // 时序寄存寄存校准帧标识低位编码端
	reg reg_cal_color_ir = 1'b0;                // 时序寄存寄存校准颜色红外红外专属红外光路低位编码端
	reg [1:0]reg_red_frame_type = 2'b00;        // 时序寄存寄存红光帧类型红光专属可见光路
	reg [1:0]reg_ir_frame_type = 2'b00;         // 时序寄存寄存红外帧类型红外专属红外光路
	reg [1:0]reg_cal_frame_type = 2'b00;        // 时序寄存寄存校准帧类型低位编码端
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_red_amb_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 时序寄存寄存红光环境数字码红光专属可见光路环境码通路
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_ir_amb_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 时序寄存寄存红外环境数字码红外专属红外光路环境码通路
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_cal_amb_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 时序寄存寄存校准环境数字码环境码通路低位编码端
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_red_dc_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 时序寄存寄存红光直流数字码红光专属可见光路直流码通路
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_ir_dc_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 时序寄存寄存红外直流数字码红外专属红外光路直流码通路
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_cal_dc_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 时序寄存寄存校准直流数字码直流码通路低位编码端
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_red_amb_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序寄存寄存红光环境版本红光专属可见光路环境码通路高位编码端
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_ir_amb_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序寄存寄存红外环境版本红外专属红外光路环境码通路高位编码端
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_cal_amb_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序寄存寄存校准环境版本环境码通路高位编码端低位编码端
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_red_dc_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序寄存寄存红光直流版本红光专属可见光路直流码通路高位编码端
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_ir_dc_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序寄存寄存红外直流版本红外专属红外光路直流码通路高位编码端
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_cal_dc_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序寄存寄存校准直流版本直流码通路高位编码端低位编码端
	reg reg_red_input_source = 1'b0;            // 时序寄存寄存红光输入来源红光专属可见光路
	reg reg_ir_input_source = 1'b0;             // 时序寄存寄存红外输入来源红外专属红外光路
	reg reg_cal_input_source = 1'b0;            // 时序寄存寄存校准输入来源低位编码端
	reg [1:0]reg_red_optical_mode = 2'b00;      // 时序寄存寄存红光光学模式红光专属可见光路低位编码端
	reg [1:0]reg_ir_optical_mode = 2'b00;       // 时序寄存寄存红外光学模式红外专属红外光路低位编码端
	reg [1:0]reg_cal_optical_mode = 2'b00;      // 时序寄存寄存校准光学模式低位编码端
	reg [7:0]reg_red_leddac_code = 8'h00;       // 时序寄存寄存红光发光数模数字码红光专属可见光路低位编码端
	reg [7:0]reg_ir_leddac_code = 8'h00;        // 时序寄存寄存红外发光数模数字码红外专属红外光路低位编码端
	reg [7:0]reg_cal_leddac_code = 8'h00;       // 时序寄存寄存校准发光数模数字码低位编码端
	reg [C_RUN_GENERATION_WIDTH - 1:0]reg_red_generation = {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序寄存红光独立时序核接管瞬间登记的RUN代际快照
	reg [C_RUN_GENERATION_WIDTH - 1:0]reg_ir_generation = {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序寄存红外时序模板接管瞬间同步记录的RUN代际
	reg [C_RUN_GENERATION_WIDTH - 1:0]reg_cal_generation = {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序寄存校准子帧首次接管时锁定的RUN代际编号
	reg reg_owner_abort_seen = 1'b0;            // 时序寄存寄存结果所有权撤销专用字段
	reg [1:0]reg_owner_slot = 2'b00;            // 时序寄存寄存结果所有权槽位低位编码端
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_owner_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 时序寄存寄存结果所有权采样序号低位编码端
	reg [C_RUN_GENERATION_WIDTH - 1:0]reg_owner_generation = {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序寄存寄存结果所有权提交时刻锁存的RUN代际，供DONE释放前校验
	reg [C_FRAME_ID_WIDTH - 1:0]reg_owner_frame_id = {C_FRAME_ID_WIDTH{1'b0}}; // 时序寄存寄存结果所有权提交时刻锁存的帧号身份
	reg reg_owner_color_ir = 1'b0;              // 时序寄存寄存结果所有权提交时刻锁存的颜色身份
	reg [1:0]reg_owner_frame_type = 2'b00;      // 时序寄存寄存结果所有权提交时刻锁存的类型身份
	reg reg_owner_precision_mode = 1'b0;        // 时序寄存寄存结果所有权提交时刻锁存的精度身份
	reg [2:0]reg_owner_cal_subframe = 3'd0;     // 校准owner提交时所在的3200 Hz子帧序号，与帧号一起把owner绑定到本子帧上下文
	reg [CONTROL_WIDTH - 1:0]reg_control_next = {CONTROL_WIDTH{1'b0}}; // 时序寄存寄存控制字下一拍低位编码端
	reg [CONTROL_WIDTH - 1:0]reg_control_vector = {CONTROL_WIDTH{1'b0}}; // 时序寄存寄存控制字向量低位编码端

	//----------------故障记录寄存----------------//
	reg [C_FRAME_ID_WIDTH - 1:0]reg_ssw_fault_frame_id = {C_FRAME_ID_WIDTH{1'b0}}; // 时序寄存故障事务帧号快照
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_ssw_fault_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 时序寄存故障事务序号快照
	reg reg_ssw_fault_color_ir = 1'b0;            // 时序寄存故障事务颜色快照
	reg [1:0]reg_ssw_fault_frame_type = 2'b00;    // 时序寄存故障事务类型快照
	reg reg_ssw_fault_precision_mode = 1'b0;      // 时序寄存故障事务精度快照
	reg [C_RUN_GENERATION_WIDTH - 1:0]reg_ssw_fault_generation = {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序寄存故障事务所属RUN代际快照

	//-----------------标志信号-----------------//
	reg flag_stop_pending = 1'b0;               // 时序寄存条件停止专用字段低位编码端
	reg flag_red_context_valid = 1'b0;          // 时序寄存条件红光上下文有效红光专属可见光路低位编码端；G-FP-02波形上下文owner，握手establish/自然末拍或abort release @satisfies: G-FP-02
	reg flag_ir_context_valid = 1'b0;           // 时序寄存条件红外上下文有效红外专属红外光路低位编码端；G-FP-02波形上下文owner，握手establish/自然末拍或abort release @satisfies: G-FP-02
	reg flag_cal_context_valid = 1'b0;          // 时序寄存条件校准上下文有效低位编码端
	reg flag_ssw_fault_valid = 1'b0;            // 时序寄存条件新故障episode单周期脉冲
	reg flag_ssw_fault_identity_valid = 1'b0;   // 时序寄存条件本次故障是否绑定了真实事务身份
	wire flag_static_active;                    // 组合条件条件静态偏置活动低位编码端
	wire flag_fixed_current_active;             // 组合条件条件固定电流活动低位编码端
	wire flag_characterization_pd_red_active;   // 组合条件表征光电二极管纯红光固定精度活动
	wire flag_static_bias_input_source_invalid; // 组合条件静态偏置输入源资格非法
	wire flag_normal_mode_legal;                // 组合条件条件正常模式专用字段低位编码端
	wire flag_calibration_mode_legal;           // 组合条件条件校准模式专用字段低位编码端
	wire flag_red_context_point;                // 组合条件条件红光上下文接管点红光专属可见光路低位编码端
	wire flag_ir_context_point;                 // 组合条件条件红外上下文接管点红外专属红外光路低位编码端
	wire flag_cal_context_point;                // 组合条件条件校准上下文接管点低位编码端
	wire flag_red_wave_active;                  // 组合条件条件红光专用字段活动红光专属可见光路低位编码端
	wire flag_ir_wave_active;                   // 组合条件条件红外专用字段活动红外专属红外光路低位编码端
	wire flag_red_wave_last;                    // 组合条件条件红光专用字段末拍红光专属可见光路低位编码端
	wire flag_ir_wave_last;                     // 组合条件条件红外专用字段末拍红外专属红外光路低位编码端
	wire flag_cal_wave_last;                    // 组合条件条件校准专用字段末拍低位编码端
	wire flag_red_owner_window;                 // 组合条件条件红光结果所有权专用字段红光专属可见光路低位编码端
	wire flag_ir_owner_window;                  // 组合条件条件红外结果所有权专用字段红外专属红外光路低位编码端
	wire flag_cal_owner_window;                 // 组合条件条件校准结果所有权专用字段低位编码端
	wire flag_red_owner_candidate;              // 组合条件条件红光结果所有权候选红光专属可见光路低位编码端
	wire flag_ir_owner_candidate;               // 组合条件条件红外结果所有权候选红外专属红外光路低位编码端
	wire flag_cal_owner_candidate;              // 组合条件条件校准结果所有权候选低位编码端
	wire flag_owner_identity_match_red;         // 组合条件条件结果所有权身份匹配红光红光专属可见光路高位编码端低位编码端
	wire flag_owner_identity_match_ir;          // 组合条件条件结果所有权身份匹配红外红外专属红外光路高位编码端低位编码端
	wire flag_owner_identity_match_cal;         // 组合条件条件结果所有权身份匹配校准高位编码端低位编码端
	wire flag_owner_identity_match;             // 组合条件条件结果所有权身份匹配高位编码端低位编码端三类候选并行归并
	wire flag_owner_commit_fire;                // 组合条件条件结果所有权专用字段提交低位编码端
	wire flag_owner_commit_error;               // 组合条件条件结果所有权专用字段错误低位编码端
	wire flag_owner_release;                    // 组合条件条件结果所有权释放低位编码端
	wire flag_done_mismatch;                    // 组合条件条件完成失配高位编码端低位编码端
	wire flag_red_has_owner;                    // 组合条件条件红光存在结果所有权红光专属可见光路高位编码端低位编码端
	wire flag_ir_has_owner;                     // 组合条件条件红外存在结果所有权红外专属红外光路高位编码端低位编码端
	wire flag_cal_has_owner;                    // 组合条件条件校准存在结果所有权高位编码端低位编码端
	wire flag_red_timeout;                      // 组合条件条件红光超时红光专属可见光路低位编码端
	wire flag_ir_timeout;                       // 组合条件条件红外超时红外专属红外光路低位编码端
	wire flag_cal_timeout;                      // 组合条件条件校准超时低位编码端
	wire flag_context_fire;                     // 组合条件条件上下文提交低位编码端
	wire flag_context_is_red;                   // 组合条件条件上下文判定红光红光专属可见光路低位编码端
	wire flag_context_is_ir;                    // 组合条件条件上下文判定红外红外专属红外光路低位编码端
	wire flag_context_is_cal;                   // 组合条件条件上下文判定校准低位编码端
	wire flag_context_is_red_raw;               // 组合条件不含接管反压注入的红光上下文判定，用于甄别真实协议违规
	wire flag_context_is_ir_raw;                // 组合条件不含接管反压注入的红外上下文判定，用于甄别真实协议违规
	wire flag_context_is_cal_raw;                // 组合条件不含接管反压注入的校准上下文判定，用于甄别真实协议违规
	wire flag_waveform_context_ready_raw;       // 组合条件不含接管反压注入时本应给出的context ready
	wire flag_test_inject_effective;            // 组合条件生产网表固定旁路验证接管反压注入请求
	wire flag_context_handover_stall;           // 组合条件本拍合法压低context ready，不构成协议违规
	wire flag_red_q3_end_passed;                // 组合条件RED owner自身选定Q3窗口已经关闭
	wire flag_ir_q3_end_passed;                 // 组合条件IR owner自身选定Q3窗口已经关闭
	wire flag_cal_q3_end_passed;                // 组合条件CAL owner自身选定Q3窗口已经关闭
	wire flag_owner_q3_closed_combo;            // 组合条件在途owner本拍即时Q3已关闭，不跨拍保持
	wire flag_blocking_fault;                   // 组合条件条件阻断专用字段低位编码端
	wire flag_start_restore;                    // 新RUN启动确认且无在途结果所有权、物理ADC空闲，丢弃未提交波形上下文并恢复运行资格
	wire flag_switch_protocol_error_condition;  // 组合条件非法接管点、双模式同时活动或事务载荷非法的原始判定
	wire flag_ssw_fault_rising;                 // 组合条件本地阻断故障从0跳变为1的首次时刻

	//-----------------其他信号-----------------//
	//-----------------输出信号-----------------//
	//模拟控制输出

	//状态与诊断输出
	wire calibration_wave_active_o;             // 组合条件校准专用字段活动输出低位编码端
	reg adc_owner_inflight_o = 1'b0;            // 时序寄存模数转换结果所有权在途输出直流码通路高位编码端低位编码端
	reg reg_owner_q3_closed_o = 1'b0;           // 时序寄存在途owner自身Q3已关闭的sticky，防止宏帧节拍环绕后误判未关闭
	reg switch_protocol_error_sticky_o = 1'b0;  // 时序寄存切换协议错误保持输出高位编码端低位编码端
	reg transaction_mismatch_sticky_o = 1'b0;   // 时序寄存事务失配保持输出高位编码端
	reg owner_deadline_timeout_sticky_o = 1'b0; // 时序寄存结果所有权截止超时保持输出低位编码端
	reg calibration_timeout_sticky_o = 1'b0;    // 时序寄存校准超时保持输出低位编码端

	//故障记录接口
	wire [7:0]ssw_fault_cause_o;                // 组合条件固定原因码桥，非活动时清零

	//---------------其他信号连线---------------//
	assign flag_static_active = reg_run_active && (i_run_profile == RUN_PROFILE_CHARACTERIZATION) && i_static_characterization_enable && (i_input_source == 1'b1); // 组合连线条件静态偏置活动低位编码端；ILM-13该条件为真时616-628行是reg_control_next唯一活动分支，纯组合逻辑不含macro_tick/宏帧/样本计数任何递增，分支内从不触碰CTRL_Q1/Q2/Q3/LED任一比特（615行统一清零默认保持0），结构性不产生Q1/Q2/Q3窗口、LED波形或ADC转换窗 @satisfies: ILM-13
	assign flag_fixed_current_active = reg_run_active && (i_run_profile == RUN_PROFILE_CHARACTERIZATION) && !i_static_characterization_enable && (i_input_source == 1'b1); // 组合连线条件固定电流活动低位编码端；EN_TEST=1场景下LEDEN保持默认0，SAR仍按400Hz间歇工作；ILM-01 PHOTODIODE下i_input_source=0，本条件恒为0，630行o_en_test随之保持低电平；ILM-04~07该条件与i_optical_mode无关，BOTH/RED_ONLY/IR_ONLY全部EXTERNAL_TEST_CURRENT变体EN_TEST=1一律成立；ILM-11 AMB_CAL/DCS_CAL期间i_run_profile恒为RUN_PROFILE_NORMAL非CHARACTERIZATION，本条件结构性恒为0，o_en_test同样保持低电平 @satisfies: TOP-07, ILM-01, ILM-04, ILM-05, ILM-06, ILM-07, ILM-11
	assign flag_characterization_pd_red_active = reg_run_active && (i_run_profile == RUN_PROFILE_CHARACTERIZATION) && !i_static_characterization_enable && (i_input_source == 1'b0) && (i_optical_mode == OPTICAL_MODE_RED_ONLY); // 组合连线表征光电二极管纯红光固定精度活动
	assign flag_static_bias_input_source_invalid = reg_run_active && (i_run_profile == RUN_PROFILE_CHARACTERIZATION) && i_static_characterization_enable && (i_input_source == 1'b0); // 组合连线静态偏置输入源资格非法

	//其他信号连线
	assign flag_normal_mode_legal = reg_run_active && !flag_static_active && !flag_stop_pending && !flag_blocking_fault && i_normal_frame_active && !i_calibration_frame_active && (((i_run_profile == RUN_PROFILE_NORMAL) && (i_input_source == 1'b0)) || flag_fixed_current_active || flag_characterization_pd_red_active); // 组合连线条件正常模式专用字段低位编码端
	assign flag_calibration_mode_legal = reg_run_active && !flag_static_active && !flag_stop_pending && !flag_blocking_fault && i_calibration_frame_active && !i_normal_frame_active && (i_run_profile == RUN_PROFILE_NORMAL) && (i_input_source == 1'b0); // 组合连线条件校准模式专用字段低位编码端；ILM-11/12该条件结构性要求i_input_source==1'b0(PHOTODIODE)，AMB_CAL/DCS_CAL只能在PHOTODIODE输入语义下合法建立校准上下文，非本条件独立观察结果 @satisfies: ILM-11, ILM-12
	assign flag_red_context_point = flag_normal_mode_legal && (i_macro_tick == 13'd0) && (i_waveform_frame_type == FRAME_TYPE_NORMAL) && !i_waveform_color_ir && ((i_waveform_optical_mode == OPTICAL_MODE_BOTH) || (i_waveform_optical_mode == OPTICAL_MODE_RED_ONLY)); // 组合连线条件红光上下文接管点红光专属可见光路低位编码端；ILM-07 IR_ONLY下本条件的optical_mode检查恒为假，RED上下文永不建立 @satisfies: ILM-07
	assign flag_ir_context_point = flag_normal_mode_legal && (i_macro_tick == 13'd160) && (i_waveform_frame_type == FRAME_TYPE_NORMAL) && i_waveform_color_ir && ((i_waveform_optical_mode == OPTICAL_MODE_BOTH) || (i_waveform_optical_mode == OPTICAL_MODE_IR_ONLY)); // 组合连线条件红外上下文接管点红外专属红外光路低位编码端；ILM-06 RED_ONLY下本条件的optical_mode检查恒为假，IR上下文永不建立 @satisfies: ILM-06
	assign flag_cal_context_point = flag_calibration_mode_legal && (i_calibration_local_tick == 10'd0) && ((i_waveform_frame_type == FRAME_TYPE_AMB && !i_waveform_color_ir) || (i_waveform_frame_type == FRAME_TYPE_DCS)) && !i_waveform_precision_mode; // 组合连线条件校准上下文接管点低位编码端
	assign flag_test_inject_effective = (C_ENABLE_TEST_INJECTION != 32'd0) && i_test_inject_enable; // 组合连线生产网表固定旁路验证接管反压注入请求
	assign flag_context_handover_stall = flag_test_inject_effective && i_context_handover_stall_request; // 组合连线本拍合法压低context ready，不构成协议违规
	assign flag_context_is_red_raw = flag_red_context_point && !flag_red_context_valid && (i_waveform_input_source == i_input_source) && (i_waveform_optical_mode == i_optical_mode) && (i_waveform_precision_mode == i_precision_mode_committed); // 组合连线不含接管反压注入的红光上下文判定
	assign flag_context_is_ir_raw = flag_ir_context_point && !flag_ir_context_valid && (i_waveform_input_source == i_input_source) && (i_waveform_optical_mode == i_optical_mode) && (i_waveform_precision_mode == i_precision_mode_committed); // 组合连线不含接管反压注入的红外上下文判定
	// 校准事务使用 AMB_CAL/DCS_CAL 自身冻结的专用光学模式；它不应被 NORMAL ACTIVE 光学模式拒绝。
	assign flag_context_is_cal_raw = flag_cal_context_point && !flag_cal_context_valid && (i_waveform_input_source == i_input_source); // 组合连线不含接管反压注入的校准上下文判定
	assign flag_context_is_red = flag_context_is_red_raw && !flag_context_handover_stall; // 组合连线条件上下文判定红光红光专属可见光路低位编码端，注入生效时合法压低
	assign flag_context_is_ir = flag_context_is_ir_raw && !flag_context_handover_stall; // 组合连线条件上下文判定红外红外专属红外光路低位编码端，注入生效时合法压低
	assign flag_context_is_cal = flag_context_is_cal_raw && !flag_context_handover_stall; // 组合连线条件上下文判定校准低位编码端，注入生效时合法压低
	assign flag_waveform_context_ready_raw = flag_context_is_red_raw || flag_context_is_ir_raw || flag_context_is_cal_raw; // 组合连线不含接管反压注入时本应给出的context ready，用于甄别真实协议违规
	assign flag_context_fire = i_waveform_context_valid && o_waveform_context_ready && !i_control_abort_event; // 组合连线条件上下文提交低位编码端
	assign flag_red_wave_active = flag_red_context_valid && (reg_red_precision ? ((i_macro_tick >= 13'd27) && (i_macro_tick < 13'd308)) : ((i_macro_tick >= 13'd44) && (i_macro_tick < 13'd318))); // 组合连线条件红光专用字段活动红光专属可见光路低位编码端
	assign flag_ir_wave_active = flag_ir_context_valid && (reg_ir_precision ? ((i_macro_tick >= 13'd187) && (i_macro_tick < 13'd468)) : ((i_macro_tick >= 13'd204) && (i_macro_tick < 13'd478))); // 组合连线条件红外专用字段活动红外专属红外光路低位编码端
	assign calibration_wave_active_o = flag_cal_context_valid && (i_calibration_local_tick >= 10'd10) && (i_calibration_local_tick < 10'd284); // 组合连线校准专用字段活动输出低位编码端
	assign flag_red_wave_last = reg_red_precision ? (i_macro_tick == 13'd307) : (i_macro_tick == 13'd317); // 组合连线条件红光专用字段末拍红光专属可见光路低位编码端
	assign flag_ir_wave_last = reg_ir_precision ? (i_macro_tick == 13'd467) : (i_macro_tick == 13'd477); // 组合连线条件红外专用字段末拍红外专属红外光路低位编码端
	assign flag_cal_wave_last = i_calibration_local_tick == 10'd283; // 组合连线条件校准专用字段末拍低位编码端
	assign flag_red_q3_end_passed = reg_red_precision ? (i_macro_tick >= 13'd304) : (i_macro_tick >= 13'd301); // 组合连线RED owner自身选定Q3窗口关闭时刻，与reg_control_next[CTRL_Q3]同一时序表逐字段对应
	assign flag_ir_q3_end_passed = reg_ir_precision ? (i_macro_tick >= 13'd464) : (i_macro_tick >= 13'd461); // 组合连线IR owner自身选定Q3窗口关闭时刻，与reg_control_next[CTRL_Q3]同一时序表逐字段对应
	assign flag_cal_q3_end_passed = i_calibration_local_tick >= 10'd267; // 组合连线CAL owner自身选定Q3窗口关闭时刻，与reg_control_next[CTRL_Q3]同一时序表逐字段对应
	assign flag_red_owner_window = flag_red_context_valid && (i_macro_tick <= C_NORMAL_RED_OWNER_DEADLINE); // 组合连线条件红光结果所有权专用字段红光专属可见光路低位编码端
	assign flag_ir_owner_window = flag_ir_context_valid && (i_macro_tick <= C_NORMAL_IR_OWNER_DEADLINE); // 组合连线条件红外结果所有权专用字段红外专属红外光路低位编码端
	assign flag_cal_owner_window = flag_cal_context_valid && (i_calibration_local_tick <= C_CAL_OWNER_DEADLINE); // 组合连线条件校准结果所有权专用字段低位编码端

	//其他信号连线
	assign flag_red_owner_candidate = flag_red_owner_window && !adc_owner_inflight_o && !flag_stop_pending && !flag_static_active; // 组合连线条件红光结果所有权候选红光专属可见光路低位编码端
	assign flag_ir_owner_candidate = !flag_red_owner_window && flag_ir_owner_window && !adc_owner_inflight_o && !flag_stop_pending && !flag_static_active; // 组合连线条件红外结果所有权候选红外专属红外光路低位编码端
	assign flag_cal_owner_candidate = flag_cal_owner_window && !adc_owner_inflight_o && !flag_stop_pending && !flag_static_active && !flag_red_context_valid && !flag_ir_context_valid; // 组合连线条件校准结果所有权候选低位编码端
	assign flag_owner_identity_match_red = (i_adc_owner_precision_mode == reg_red_precision) && (i_adc_owner_frame_id == reg_red_frame_id) && !i_adc_owner_color_ir && (i_adc_owner_frame_type == reg_red_frame_type) && (i_adc_owner_amb_code_snapshot == reg_red_amb_code) && (i_adc_owner_dc_code_snapshot == reg_red_dc_code) && (i_adc_owner_amb_code_epoch == reg_red_amb_epoch) && (i_adc_owner_dc_code_epoch == reg_red_dc_epoch) && (i_run_generation == reg_red_generation); // 组合连线条件结果所有权身份匹配红光红光专属可见光路高位编码端低位编码端红光事务身份比对，含代际校验防止陈旧代际复活波形
	assign flag_owner_identity_match_ir = (i_adc_owner_precision_mode == reg_ir_precision) && (i_adc_owner_frame_id == reg_ir_frame_id) && i_adc_owner_color_ir && (i_adc_owner_frame_type == reg_ir_frame_type) && (i_adc_owner_amb_code_snapshot == reg_ir_amb_code) && (i_adc_owner_dc_code_snapshot == reg_ir_dc_code) && (i_adc_owner_amb_code_epoch == reg_ir_amb_epoch) && (i_adc_owner_dc_code_epoch == reg_ir_dc_epoch) && (i_run_generation == reg_ir_generation); // 组合连线条件结果所有权身份匹配红外红外专属红外光路高位编码端低位编码端红外事务身份比对，含代际校验防止陈旧代际复活波形
	assign flag_owner_identity_match_cal = (i_adc_owner_precision_mode == 1'b0) && (i_adc_owner_frame_id == reg_cal_frame_id) && (i_adc_owner_color_ir == (reg_cal_frame_type == FRAME_TYPE_DCS ? reg_cal_color_ir : 1'b0)) && (i_adc_owner_frame_type == reg_cal_frame_type) && (i_adc_owner_amb_code_snapshot == reg_cal_amb_code) && (i_adc_owner_dc_code_snapshot == reg_cal_dc_code) && (i_adc_owner_amb_code_epoch == reg_cal_amb_epoch) && (i_adc_owner_dc_code_epoch == reg_cal_dc_epoch) && (i_run_generation == reg_cal_generation); // 组合连线条件结果所有权身份匹配校准高位编码端低位编码端，含代际校验防止陈旧代际复活波形
	assign flag_owner_identity_match = (flag_red_owner_candidate && flag_owner_identity_match_red) || (flag_ir_owner_candidate && flag_owner_identity_match_ir) || (flag_cal_owner_candidate && flag_owner_identity_match_cal); // 组合连线条件结果所有权身份匹配高位编码端低位编码端多路候选身份综合

	//其他信号连线
	assign flag_owner_commit_fire = i_adc_owner_commit_event && o_adc_owner_ready && flag_owner_identity_match && !i_control_abort_event; // 组合连线条件结果所有权专用字段提交低位编码端
	assign flag_owner_commit_error = i_adc_owner_commit_event && !flag_owner_commit_fire; // 组合连线条件结果所有权专用字段错误低位编码端
	assign flag_owner_release = (i_adc_transaction_complete_event || i_adc_transaction_lost_event) && adc_owner_inflight_o && (i_adc_complete_sample_index == reg_owner_sample_index) && (i_run_generation == reg_owner_generation); // 组合连线条件结果所有权释放低位编码端，含代际校验防止陈旧代际释放owner；释放本身不额外要求Q3已关闭——早于Q3的DONE仍然合法释放槽位（物理上确有一次匹配身份的完成信号到达），只是不构成正式成功，Q3门控只作用于Scheduler侧的flag_completion_success，避免"Q3若因异常提前完成后不再出现"导致owner永久卡在in-flight、连带o_wrapper_idle永远不能为真、transaction_mismatch_sticky_o永远清不掉的死锁
	assign flag_done_mismatch = (i_adc_transaction_complete_event || i_adc_transaction_lost_event) && !flag_owner_release; // 组合连线条件完成失配高位编码端低位编码端，与owner_release互补，代际或序号任一不符均视为失配；作废事件与完成事件同样以事件限定序号并按同一规则核对

	//其他信号连线
	assign flag_red_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_RED) && (reg_owner_frame_id == reg_red_frame_id); // 组合连线条件红光存在结果所有权：只认绑定到当前RED上下文帧号的owner，跨帧残留旧owner不驱动新帧Q3也不掩盖截止；L-1 @satisfies: SSW-38, SSW-34
	assign flag_ir_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_IR) && (reg_owner_frame_id == reg_ir_frame_id); // 组合连线条件红外存在结果所有权：IR owner须属于当前IR上下文所在帧，下一帧IR接管后旧owner失效；L-1
	assign flag_cal_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_CAL) && (reg_owner_frame_id == reg_cal_frame_id) && (reg_owner_cal_subframe == i_calibration_subframe_index); // 组合连线条件校准存在结果所有权：帧号与子帧序号同时一致才算本子帧owner，S1与L-1共用此绑定
	assign flag_red_timeout = flag_red_context_valid && (i_macro_tick == C_NORMAL_RED_OWNER_DEADLINE + 1) && !flag_red_has_owner; // 组合连线条件红光超时红光专属可见光路低位编码端
	assign flag_ir_timeout = flag_ir_context_valid && (i_macro_tick == C_NORMAL_IR_OWNER_DEADLINE + 1) && !flag_ir_has_owner; // 组合连线条件红外超时红外专属红外光路低位编码端
	assign flag_cal_timeout = flag_cal_context_valid && (i_calibration_local_tick == C_CAL_OWNER_DEADLINE + 1) && !flag_cal_has_owner; // 组合连线条件校准超时低位编码端

	//其他信号连线
	assign flag_blocking_fault = switch_protocol_error_sticky_o || transaction_mismatch_sticky_o; // 组合连线条件阻断专用字段低位编码端
	assign flag_start_restore = i_start_ack_event && !adc_owner_inflight_o && i_adc_idle; // 新RUN启动时上一RUN残留的未提交波形上下文一律作废（与abort一致），因此启动恢复不再以上下文空闲为前提；STOPPING完成已要求ADC空闲且数据链排空，START时不可能有已提交owner在途；服务ABCD N-2（STOP落在波形接管与owner提交之间后立即START的死锁）
	assign flag_switch_protocol_error_condition = flag_static_bias_input_source_invalid || flag_owner_commit_error || (i_normal_frame_active && i_calibration_frame_active) || (i_waveform_context_valid && !o_waveform_context_ready && !flag_waveform_context_ready_raw && ((i_macro_tick == 13'd0) || (i_macro_tick == 13'd160) || (i_calibration_local_tick == 10'd0))); // 组合连线切换协议错误的原始判定，供sticky和故障记录共用避免重复表达式；接管反压注入合法压低ready时(flag_waveform_context_ready_raw为真)不构成协议违规，交由Scheduler自身的非阻断launch-timeout诊断独立表态；本表达式是LFA-10(b)与OIB-01共同调查的唯一锚点,第4个OR项经`i_context_handover_stall_request`收窄后关闭OIB-01,LFA-10(b)证明四项皆结构性不可达而延期 @satisfies: LFA-10, OIB-01
	assign flag_ssw_fault_rising = !flag_blocking_fault && (flag_switch_protocol_error_condition || flag_done_mismatch); // 组合连线本地阻断故障首次跳变时刻，用于拉出故障记录valid脉冲
	assign ssw_fault_cause_o = flag_blocking_fault ? 8'h21 : 8'h00; // 组合连线仅SSW身份/所有权协议错误的固定原因码

	//---------------输出信号连线---------------//
	//调度器波形上下文通道
	assign o_waveform_context_ready = flag_context_is_red || flag_context_is_ir || flag_context_is_cal; // 组合连线输出波形上下文就绪；OIB-10要求的静态ready/valid环路分析：本表达式不组合依赖i_waveform_context_valid或任何下游valid，不构成组合ready环路 @satisfies: OIB-10

	//调度器ADC结果owner通道
	assign o_adc_owner_ready = flag_red_owner_candidate || flag_ir_owner_candidate || flag_cal_owner_candidate; // 组合连线输出模数转换结果所有权就绪直流码通路；OIB-10要求的静态ready/valid环路分析：本表达式同样不组合依赖i_adc_owner_commit_event或任何下游valid，不构成组合ready环路，独立fork分支stall沿用既有FFK/AMI unit级证据 @satisfies: OIB-10

	//模拟控制输出
	assign o_en_tia_low = reg_control_vector[CTRL_EN_TIA]; // 组合连线输出使能跨阻放大低有效低位编码端
	assign o_leddac = reg_control_vector[CTRL_LED_CODE] ? reg_control_vector[CTRL_LED_DATA_H:CTRL_LED_DATA_L] : 8'h00; // 组合连线输出发光数模低位编码端
	assign o_leden1_low = reg_control_vector[CTRL_LED_R]; // 组合连线输出红光选择低有效低位编码端
	assign o_leden2_low = reg_control_vector[CTRL_LED_IR]; // 组合连线输出红外选择低有效低位编码端红外灯选通道连线
	assign o_en_test = reg_control_vector[CTRL_EN_TEST]; // 组合连线输出使能测试
	assign o_clk_buf_low = reg_control_vector[CTRL_CLK_BUF]; // 组合连线输出时钟缓冲低有效低位编码端
	assign o_clk_iref_idac_low = reg_control_vector[CTRL_IREF_IDAC]; // 组合连线输出时钟参考电流电流数模低有效低位编码端
	assign o_clk_9q1_low = reg_control_vector[CTRL_Q1_9]; // 组合连线输出时钟九位第一相位低有效低位编码端
	assign o_clk_15q1_low = reg_control_vector[CTRL_Q1_15]; // 组合连线输出时钟十五位第一相位低有效低位编码端
	assign o_clk_aferst_low = reg_control_vector[CTRL_AFERST]; // 组合连线输出时钟前端复位低有效低位编码端
	assign o_clk_iref_idac_sar9_low = reg_control_vector[CTRL_IREF_9]; // 组合连线输出时钟参考电流电流数模九位转换低有效九位转换专用低位编码端
	assign o_clk_iref_idac_sar15_low = reg_control_vector[CTRL_IREF_15]; // 组合连线输出时钟参考电流电流数模十五位转换低有效十五位转换专用低位编码端
	assign o_clk_q2_low = reg_control_vector[CTRL_Q2]; // 组合连线输出时钟第二相位低有效低位编码端
	assign o_clk_q3_low = reg_control_vector[CTRL_Q3]; // 组合连线输出时钟第三相位低有效低位编码端第三相位中心时序
	assign o_clk_tiaen_low = reg_control_vector[CTRL_TIAEN]; // 组合连线输出时钟专用字段低有效低位编码端
	assign o_en_15sar_low = reg_control_vector[CTRL_EN_15]; // 组合连线输出使能专用字段低有效低位编码端
	assign o_en_sar9_amb_low = reg_control_vector[CTRL_EN_9_AMB]; // 组合连线输出使能九位转换环境低有效九位转换专用环境码通路低位编码端
	assign o_en_sar9_dc_low = reg_control_vector[CTRL_EN_9_DC]; // 组合连线输出使能九位转换直流低有效九位转换专用直流码通路低位编码端
	assign o_en_sar9_iref = reg_control_vector[CTRL_EN_9_IREF]; // 组合连线输出使能九位转换参考电流九位转换专用
	assign o_en_sar15_amb_low = reg_control_vector[CTRL_EN_15_AMB]; // 组合连线输出使能十五位转换环境低有效十五位转换专用环境码通路低位编码端
	assign o_en_sar15_dc_low = reg_control_vector[CTRL_EN_15_DC]; // 组合连线输出使能十五位转换直流低有效十五位转换专用直流码通路低位编码端
	assign o_en_sar15_iref = reg_control_vector[CTRL_EN_15_IREF]; // 组合连线输出使能十五位转换参考电流十五位转换专用
	assign o_idac_sar9ambn_low = reg_control_vector[CTRL_AMB9_H:CTRL_AMB9_L]; // 组合连线输出电流数模九位环境总线低有效九位转换专用环境码通路低位编码端
	assign o_idac_sar9dcn_low = reg_control_vector[CTRL_DC9_H:CTRL_DC9_L]; // 组合连线输出电流数模九位直流总线低有效九位转换专用直流码通路低位编码端
	assign o_idac_sar15ambn_low = reg_control_vector[CTRL_AMB15_H:CTRL_AMB15_L]; // 组合连线输出电流数模十五位环境总线低有效红外专属红外光路十五位转换专用环境码通路低位编码端
	assign o_idac_sar15dcn_low = reg_control_vector[CTRL_DC15_H:CTRL_DC15_L]; // 组合连线输出电流数模十五位直流总线低有效红外专属红外光路十五位转换专用直流码通路低位编码端
	assign o_s_in = reg_control_vector[CTRL_S_IN_H:CTRL_S_IN_L]; // 组合连线输出观测选择专用字段
	assign o_clk_2m = i_clk;                    // 组合连线输出时钟二兆赫兹低位编码端

	//状态与诊断输出
	assign o_analog_safe = !(flag_red_wave_active || flag_ir_wave_active || calibration_wave_active_o); // 组合连线输出模拟安全低位编码端
	assign o_sar_timing_idle = !flag_red_context_valid && !flag_ir_context_valid && !flag_cal_context_valid; // 组合连线输出专用字段时序空闲低位编码端
	assign o_wrapper_idle = o_sar_timing_idle && !adc_owner_inflight_o && i_adc_idle; // 组合连线输出封装空闲低位编码端
	assign o_precision_active = flag_static_active ? 1'b0 : (flag_red_wave_active ? reg_red_precision : (flag_ir_wave_active ? reg_ir_precision : (calibration_wave_active_o ? 1'b0 : 1'b0))); // 组合连线输出精度活动
	assign o_calibration_wave_active = calibration_wave_active_o; // 组合连线输出校准专用字段活动低位编码端
	assign o_adc_owner_inflight = adc_owner_inflight_o; // 组合连线输出模数转换结果所有权在途直流码通路高位编码端低位编码端
	assign flag_owner_q3_closed_combo = (flag_red_has_owner && flag_red_q3_end_passed) || (flag_ir_has_owner && flag_ir_q3_end_passed) || (flag_cal_has_owner && flag_cal_q3_end_passed); // 组合连线在途owner本拍即时Q3已关闭，不跨拍保持
	assign o_owner_q3_window_closed = reg_owner_q3_closed_o || flag_owner_q3_closed_combo; // 组合连线在途owner自身选定Q3窗口已关闭，供Scheduler门控completion身份匹配；跨宏帧节拍环绕后仍必须保持，故与sticky寄存做OR
	assign o_switch_protocol_error_sticky = switch_protocol_error_sticky_o; // 组合连线输出切换协议错误保持高位编码端低位编码端
	assign o_transaction_mismatch_sticky = transaction_mismatch_sticky_o; // 组合连线输出事务失配保持高位编码端
	assign o_owner_deadline_timeout_sticky = owner_deadline_timeout_sticky_o; // 组合连线输出结果所有权截止超时保持低位编码端
	assign o_calibration_timeout_sticky = calibration_timeout_sticky_o; // 组合连线输出校准超时保持低位编码端
	assign o_wrapper_fault_blocking = flag_blocking_fault || ((flag_red_wave_active || flag_ir_wave_active || calibration_wave_active_o) && flag_stop_pending); // 组合连线输出封装专用字段阻断低位编码端

	//故障记录接口
	assign o_ssw_fault_valid = flag_ssw_fault_valid; // 组合连线输出新故障episode单周期脉冲
	assign o_ssw_fault_active = flag_blocking_fault; // 组合连线输出注册式阻断持续状态
	assign o_ssw_fault_cause = ssw_fault_cause_o; // 组合连线输出固定原因码
	assign o_ssw_fault_identity_valid = flag_ssw_fault_identity_valid; // 组合连线输出身份是否可信
	assign o_ssw_fault_frame_id = flag_ssw_fault_identity_valid ? reg_ssw_fault_frame_id : {C_FRAME_ID_WIDTH{1'b0}}; // 组合连线身份无效时强制归零
	assign o_ssw_fault_sample_index = flag_ssw_fault_identity_valid ? reg_ssw_fault_sample_index : {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 组合连线输出故障事务序号，供supervisor与其它两路来源交叉核对
	assign o_ssw_fault_color_ir = flag_ssw_fault_identity_valid && reg_ssw_fault_color_ir; // 组合连线输出故障事务颜色，与AND门共享同一身份有效位
	assign o_ssw_fault_frame_type = flag_ssw_fault_identity_valid ? reg_ssw_fault_frame_type : 2'b00; // 组合连线输出故障事务类型，区分NORMAL与校准来源
	assign o_ssw_fault_precision_mode = flag_ssw_fault_identity_valid && reg_ssw_fault_precision_mode; // 组合连线输出故障事务精度
	assign o_ssw_fault_run_generation = flag_ssw_fault_identity_valid ? reg_ssw_fault_generation : {C_RUN_GENERATION_WIDTH{1'b0}}; // 组合连线输出故障事务所属RUN代际，供supervisor判断是否跨代际

	//-------------输出信号处理区域-------------//
	//模拟控制输出
	// 时序维护模数转换结果所有权在途输出直流码通路高位编码端低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			adc_owner_inflight_o <= 1'b0;       // 时序写入模数转换结果所有权在途输出直流码通路高位编码端低位编码端异步复位清零
		end else if(flag_owner_release == 1'b1)begin
			adc_owner_inflight_o <= 1'b0;       // 时序写入模数转换结果所有权在途输出直流码通路高位编码端低位编码端结果完成释放；与abort同拍的匹配完成同样释放，否则owner残留到复位 @satisfies: SSW-22
		end else if(i_control_abort_event == 1'b1)begin
			adc_owner_inflight_o <= adc_owner_inflight_o; // 时序写入模数转换结果所有权在途输出直流码通路高位编码端低位编码端撤销期间保持
		end else if(flag_owner_commit_fire == 1'b1)begin
			adc_owner_inflight_o <= 1'b1;       // 时序写入模数转换结果所有权在途输出直流码通路高位编码端低位编码端所有权提交锁存
		end
	end

	// 时序维护在途owner自身Q3已关闭的sticky，与adc_owner_inflight_o共享同一生命周期，跨宏帧节拍环绕后仍不丢失
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_owner_q3_closed_o <= 1'b0;      // 时序写入Q3关闭sticky异步复位清零
		end else if(flag_owner_release == 1'b1)begin
			reg_owner_q3_closed_o <= 1'b0;      // 时序写入结果完成释放后为下一个owner重置
		end else if(flag_owner_commit_fire == 1'b1)begin
			reg_owner_q3_closed_o <= 1'b0;      // 时序写入新owner建立，重新计时
		end else begin
			reg_owner_q3_closed_o <= reg_owner_q3_closed_o || flag_owner_q3_closed_combo; // 时序写入一旦本拍Q3关闭即锁存，撤销期间同样继续锁存
		end
	end

	// 时序维护校准超时保持输出低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			calibration_timeout_sticky_o <= 1'b0; // 时序写入校准超时保持输出低位编码端异步复位清零
		end else if(flag_start_restore == 1'b1)begin
			calibration_timeout_sticky_o <= 1'b0; // 时序写入校准超时保持输出低位编码端启动确认复原
		end else begin
			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
				calibration_timeout_sticky_o <= 1'b0; // 时序写入校准超时保持输出低位编码端诊断确认清除
			end
			if(i_calibration_frame_active == 1'b1 && (i_calibration_local_tick == CAL_COMMIT_TICK) && flag_cal_has_owner == 1'b1)begin
				calibration_timeout_sticky_o <= 1'b1; // 本子帧校准owner到local tick 385仍未完成即记迟到诊断（ADC已在tick 266采样、迟到的只是读出），非阻断；丢失由AMI超时作废另报；S1
			end
		end
	end

	// 时序维护结果所有权截止超时保持输出低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			owner_deadline_timeout_sticky_o <= 1'b0; // 时序写入结果所有权截止超时保持输出低位编码端异步复位清零
		end else if(flag_start_restore == 1'b1)begin
			owner_deadline_timeout_sticky_o <= 1'b0; // 时序写入结果所有权截止超时保持输出低位编码端启动确认复原
		end else begin
			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
				owner_deadline_timeout_sticky_o <= 1'b0; // 时序写入结果所有权截止超时保持输出低位编码端诊断确认清除
			end
			if(flag_red_timeout == 1'b1 || flag_ir_timeout == 1'b1 || flag_cal_timeout == 1'b1)begin
				owner_deadline_timeout_sticky_o <= 1'b1; // 时序写入结果所有权截止超时保持输出低位编码端红光波形控制更新
			end
		end
	end

	// 时序维护切换协议错误保持输出高位编码端低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			switch_protocol_error_sticky_o <= 1'b0; // 时序写入切换协议错误保持输出高位编码端低位编码端异步复位清零
		end else if(flag_start_restore == 1'b1)begin
			switch_protocol_error_sticky_o <= 1'b0; // 时序写入切换协议错误保持输出高位编码端低位编码端启动确认复原
		end else begin
			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
				switch_protocol_error_sticky_o <= 1'b0; // 时序写入切换协议错误保持输出高位编码端低位编码端诊断确认清除
			end
			if(flag_switch_protocol_error_condition == 1'b1)begin
				switch_protocol_error_sticky_o <= 1'b1; // 时序写入切换协议错误保持输出高位编码端低位编码端红光波形控制更新
			end
		end
	end

	// 时序维护事务失配保持输出高位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			transaction_mismatch_sticky_o <= 1'b0; // 时序写入事务失配保持输出高位编码端异步复位清零
		end else if(flag_start_restore == 1'b1)begin
			transaction_mismatch_sticky_o <= 1'b0; // 时序写入事务失配保持输出高位编码端启动确认复原
		end else begin
			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
				transaction_mismatch_sticky_o <= 1'b0; // 时序写入事务失配保持输出高位编码端诊断确认清除
			end
			if(flag_done_mismatch == 1'b1)begin
				transaction_mismatch_sticky_o <= 1'b1; // 时序写入事务失配保持输出高位编码端红光波形控制更新
			end
		end
	end

	//-------------主要任务处理区域-------------//
	// 时序维护寄存控制字向量低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_control_vector <= {CONTROL_WIDTH{1'b0}}; // 时序写入寄存控制字向量低位编码端异步复位清零；复位后SSW为安全向量，无旧事务恢复 @satisfies: TOP-01
		end else if(i_control_abort_event == 1'b1)begin
			reg_control_vector <= {CONTROL_WIDTH{1'b0}}; // 时序写入寄存控制字向量低位编码端撤销期间保持
		end else begin
			reg_control_vector <= reg_control_next; // 时序写入寄存控制字向量低位编码端正常时钟更新
		end
	end

	//状态与诊断输出
	// 组合生成寄存控制字下一拍低位编码端
	always@(*)begin
		reg_control_next = {CONTROL_WIDTH{1'b0}}; // 时序写入寄存控制字下一拍低位编码端正常时钟更新；ISE-06 STATIC_BIAS分支(616-628行)只置位EN_9_AMB/EN_9_DC/EN_15_AMB/EN_15_DC等通道使能位与测试多路选择总线，从不写CTRL_AMB9/DC9/AMB15/DC15任何一条码总线，四条总线在STATIC_BIAS期间全程保持本行的无条件清零值 @satisfies: ISE-06
		if(flag_static_active == 1'b1)begin
			reg_control_next[CTRL_EN_TEST] = 1'b1; // 时序写入寄存控制字下一拍低位编码端测试输入使能静态偏置控制更新
			reg_control_next[CTRL_CLK_BUF] = 1'b1; // 时序写入寄存控制字下一拍低位编码端时钟缓冲选择位静态偏置控制更新
			reg_control_next[CTRL_IREF_IDAC] = 1'b1; // 时序写入寄存控制字下一拍低位编码端共享参考电流位静态偏置控制更新
			reg_control_next[CTRL_AFERST] = 1'b1; // 时序写入寄存控制字下一拍低位编码端前端复位选择位静态偏置控制更新
			reg_control_next[CTRL_IREF_9] = 1'b1; // 时序写入寄存控制字下一拍低位编码端九位参考选择位九位转换专属静态偏置控制更新
			reg_control_next[CTRL_IREF_15] = 1'b1; // 时序写入寄存控制字下一拍低位编码端十五位参考选择位十五位转换专属静态偏置控制更新十五位参考电流保持
			reg_control_next[CTRL_TIAEN] = 1'b1; // 时序写入寄存控制字下一拍低位编码端跨阻时钟选择位静态偏置控制更新
			reg_control_next[CTRL_EN_9_AMB] = 1'b1; // 时序写入寄存控制字下一拍低位编码端九位环境通道使能九位转换专属静态偏置控制更新
			reg_control_next[CTRL_EN_9_DC] = 1'b1; // 时序写入寄存控制字下一拍低位编码端九位直流通道使能九位转换专属静态偏置控制更新九位直流通道开启
			reg_control_next[CTRL_EN_15_AMB] = 1'b1; // 时序写入寄存控制字下一拍低位编码端十五位环境通道使能十五位转换专属静态偏置控制更新
			reg_control_next[CTRL_EN_15_DC] = 1'b1; // 时序写入寄存控制字下一拍低位编码端十五位直流通道使能十五位转换专属静态偏置控制更新十五位直流通道开启
			reg_control_next[CTRL_S_IN_H:CTRL_S_IN_L] = i_test_mux_ctrl; // 时序写入寄存控制字下一拍低位编码端测试多路选择总线静态偏置控制更新
		end else if(reg_run_active == 1'b1 && i_control_abort_event == 1'b0)begin
			reg_control_next[CTRL_EN_TEST] = flag_fixed_current_active; // 时序写入寄存控制字下一拍低位编码端测试输入使能撤销期间保持
			if(flag_red_wave_active == 1'b1)begin
				reg_control_next[CTRL_IREF_IDAC] = reg_control_next[CTRL_IREF_IDAC] ||
				(reg_red_precision ? ((i_macro_tick >= 13'd246) && (i_macro_tick < 13'd306)):
				((i_macro_tick >= 13'd263) && (i_macro_tick < 13'd303))); // RED独立IDAC预热窗
				if(reg_red_precision == 1'b1)begin
					reg_control_next[CTRL_IREF_15] = 1'b1; // 时序写入寄存控制字下一拍低位编码端十五位参考选择位十五位转换专属红光波形控制更新
					reg_control_next[CTRL_EN_15_IREF] = (i_macro_tick >= 13'd27) && (i_macro_tick < 13'd306); // 时序写入寄存控制字下一拍低位编码端十五位参考通道使能十五位转换专属红光波形控制更新
					reg_control_next[CTRL_EN_15_AMB] = (i_macro_tick >= 13'd47) && (i_macro_tick < 13'd308); // 时序写入寄存控制字下一拍低位编码端十五位环境通道使能十五位转换专属红光波形控制更新十五位环境建立窗
					reg_control_next[CTRL_EN_15_DC] = (i_macro_tick >= 13'd47) && (i_macro_tick < 13'd308) &&
					(reg_red_frame_type != FRAME_TYPE_AMB); // AMB_CAL禁止DC通路
					reg_control_next[CTRL_AMB15_H:CTRL_AMB15_L] = reg_control_next[CTRL_AMB15_H:CTRL_AMB15_L] | (((i_macro_tick >= 13'd203) && (i_macro_tick < 13'd308) &&
					(reg_red_frame_type == FRAME_TYPE_NORMAL)) ? reg_red_amb_code : 8'h00); // SAR15 RED AMB窗口与后续IR窗口按位合并；ISE-05 本行仅在636行reg_red_precision==1'b1分支内执行，与645-655行SAR9分支互斥，该tick内SAR9 AMB/DC总线不会被RED写入，逐位透传reg_red_amb_code而非整线使能;ISE-07 Phase B驱动的8'h5A非对称模式(与C3组合)是与Phase A不同的第二组非对称码值，直接证明按位门控而非窗口/总线级使能捷径 @satisfies: ISE-05, ISE-07
					reg_control_next[CTRL_DC15_H:CTRL_DC15_L] = reg_control_next[CTRL_DC15_H:CTRL_DC15_L] | (((i_macro_tick >= 13'd151) && (i_macro_tick < 13'd308) &&
					(reg_red_frame_type == FRAME_TYPE_NORMAL)) ? reg_red_dc_code : 8'h00); // SAR15 RED DC窗口不会被未到达的IR上下文清零；ISE-05 本行同属636行SAR15专属分支，与SAR9 DC总线(653行)结构互斥，逐位透传reg_red_dc_code @satisfies: ISE-05
				end else begin
					reg_control_next[CTRL_IREF_9] = 1'b1; // 时序写入寄存控制字下一拍低位编码端九位参考选择位九位转换专属正常时钟更新
					reg_control_next[CTRL_EN_9_IREF] = (i_macro_tick >= 13'd236) && (i_macro_tick < 13'd308); // 时序写入寄存控制字下一拍低位编码端九位参考通道使能九位转换专属正常时钟更新
					reg_control_next[CTRL_EN_9_AMB] = (i_macro_tick >= 13'd256) && (i_macro_tick < 13'd310); // 时序写入寄存控制字下一拍低位编码端九位环境通道使能九位转换专属正常时钟更新九位环境建立窗
					reg_control_next[CTRL_EN_9_DC] = (i_macro_tick >= 13'd256) && (i_macro_tick < 13'd310) &&
					(reg_red_frame_type != FRAME_TYPE_AMB); // SAR9 RED DCS/NORMAL才允许DC
					reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] = reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] | (((i_macro_tick >= 13'd258) && (i_macro_tick < 13'd310)) ?
					reg_red_amb_code : 8'h00);  // SAR9 RED AMB窗口与IR路径的未激活零值隔离；ISE-04 本行仅在645行reg_red_precision==1'b0分支内执行，与636-644行SAR15分支互斥，该tick内SAR15 AMB/DC总线不会被RED写入，逐位透传reg_red_amb_code而非整线使能;ISE-07 本行逐位透传8位码值，Phase A驱动的8'hA5非对称模式(与3C组合)直接证明按位门控而非窗口/总线级使能捷径 @satisfies: ISE-04, ISE-07
					reg_control_next[CTRL_DC9_H:CTRL_DC9_L] = reg_control_next[CTRL_DC9_H:CTRL_DC9_L] | (((i_macro_tick >= 13'd266) && (i_macro_tick < 13'd310) &&
					(reg_red_frame_type != FRAME_TYPE_AMB)) ? reg_red_dc_code : 8'h00); // SAR9 RED DC窗口保持到其独立截止点；ISE-04 本行同属645行SAR9专属分支，与SAR15 DC总线(643行)结构互斥，逐位透传reg_red_dc_code @satisfies: ISE-04
				end
				if(flag_red_has_owner == 1'b1)begin
					reg_control_next[CTRL_EN_TIA] = (i_macro_tick >= (reg_red_precision ? 13'd266 : 13'd283)) &&
					(i_macro_tick < (reg_red_precision ? 13'd305 : 13'd303)); // RED TIA采样窗口
					reg_control_next[CTRL_AFERST] = (i_macro_tick >= (reg_red_precision ? 13'd266 : 13'd283)) &&
					(i_macro_tick < (reg_red_precision ? 13'd286 : 13'd295)); // RED前端复位窗口
					reg_control_next[CTRL_TIAEN] = reg_control_next[CTRL_EN_TIA]; // 时序写入寄存控制字下一拍低位编码端跨阻时钟选择位红光波形控制更新
					reg_control_next[CTRL_Q2] = (i_macro_tick >= (reg_red_precision ? 13'd287 : 13'd296)) &&
					(i_macro_tick < (reg_red_precision ? 13'd295 : 13'd298)); // RED Q2窗口
					reg_control_next[CTRL_Q3] = (i_macro_tick >= (reg_red_precision ? 13'd296 : 13'd299)) &&
					(i_macro_tick < (reg_red_precision ? 13'd304 : 13'd301)); // RED固定Q3窗口
					if(reg_red_precision == 1'b1)begin
						reg_control_next[CTRL_Q1_15] = (i_macro_tick >= 13'd284) && (i_macro_tick < 13'd305); // 时序写入寄存控制字下一拍低位编码端十五位第一相位十五位转换专属红光波形控制更新
						reg_control_next[CTRL_EN_15] = reg_control_next[CTRL_Q1_15]; // 时序写入寄存控制字下一拍低位编码端十五位阵列使能十五位转换专属红光波形控制更新
					end else begin
						reg_control_next[CTRL_Q1_9] = (i_macro_tick >= 13'd293) && (i_macro_tick < 13'd302); // 时序写入寄存控制字下一拍低位编码端九位第一相位九位转换专属正常时钟更新
					end
					if((reg_red_frame_type != FRAME_TYPE_AMB) && (i_macro_tick >= (reg_red_precision ? 13'd295 : 13'd298)) && (i_macro_tick < (reg_red_precision ? 13'd304 : 13'd301)))begin
						reg_control_next[CTRL_LED_R] = !reg_red_input_source; // 时序写入寄存控制字下一拍低位编码端红光灯选择位红光灯通路红光波形控制更新；ILM-04/05/06 reg_red_input_source在EXTERNAL_TEST_CURRENT下快照为1，本行连同674行LED_CODE一并恒为0，RED波形窗口内LED与LEDDAC保持关闭，与BOTH/SAR9/SAR15/RED_ONLY变体无关 @satisfies: ILM-04, ILM-05, ILM-06
						reg_control_next[CTRL_LED_CODE] = !reg_red_input_source; // 时序写入寄存控制字下一拍低位编码端灯码选择位红光波形控制更新
						reg_control_next[CTRL_LED_DATA_H:CTRL_LED_DATA_L] = reg_red_leddac_code; // 时序写入寄存控制字下一拍低位编码端灯数据总线红光波形控制更新
					end
				end
			end
			if(flag_ir_wave_active == 1'b1)begin
				reg_control_next[CTRL_IREF_IDAC] = reg_control_next[CTRL_IREF_IDAC] ||
				(reg_ir_precision ? ((i_macro_tick >= 13'd406) && (i_macro_tick < 13'd466)):
				((i_macro_tick >= 13'd423) && (i_macro_tick < 13'd463))); // IR独立IDAC预热窗
				if(reg_ir_precision == 1'b1)begin
					reg_control_next[CTRL_IREF_15] = 1'b1; // 时序写入寄存控制字下一拍低位编码端十五位参考选择位十五位转换专属红外波形控制更新红外十五位参考窗
					reg_control_next[CTRL_EN_15_IREF] = reg_control_next[CTRL_EN_15_IREF] ||
					((i_macro_tick >= 13'd187) && (i_macro_tick < 13'd466)); // SAR15 IR白名单IREF窗
					reg_control_next[CTRL_EN_15_AMB] = reg_control_next[CTRL_EN_15_AMB] ||
					((i_macro_tick >= 13'd207) && (i_macro_tick < 13'd468)); // SAR15 IR白名单AMB窗
					reg_control_next[CTRL_EN_15_DC] = reg_control_next[CTRL_EN_15_DC] ||
					(((i_macro_tick >= 13'd207) && (i_macro_tick < 13'd468)) && (reg_ir_frame_type == FRAME_TYPE_NORMAL)); // SAR15 IR白名单DC窗
					reg_control_next[CTRL_AMB15_H:CTRL_AMB15_L] = reg_control_next[CTRL_AMB15_H:CTRL_AMB15_L] | (((i_macro_tick >= 13'd363) && (i_macro_tick < 13'd468) &&
					(reg_ir_frame_type == FRAME_TYPE_NORMAL)) ? reg_ir_amb_code : 8'h00); // SAR15 IR AMB窗口保留可能仍活动的已确认RED窗口；ISE-05 本行仅在683行reg_ir_precision==1'b1分支内执行，与695-705行SAR9分支互斥，逐位透传reg_ir_amb_code，是RED侧641行的独立红外镜像 @satisfies: ISE-05
					reg_control_next[CTRL_DC15_H:CTRL_DC15_L] = reg_control_next[CTRL_DC15_H:CTRL_DC15_L] | (((i_macro_tick >= 13'd311) && (i_macro_tick < 13'd468) &&
					(reg_ir_frame_type == FRAME_TYPE_NORMAL)) ? reg_ir_dc_code : 8'h00); // SAR15 IR DC窗口与RED上下文的逻辑合并；ISE-05 本行同属683行SAR15专属分支，与SAR9 IR DC总线(703行)结构互斥，逐位透传reg_ir_dc_code @satisfies: ISE-05
				end else begin
					reg_control_next[CTRL_IREF_9] = 1'b1; // 时序写入寄存控制字下一拍低位编码端九位参考选择位九位转换专属正常时钟更新红外九位参考窗
					reg_control_next[CTRL_EN_9_IREF] = (i_macro_tick >= 13'd396) && (i_macro_tick < 13'd468); // 时序写入寄存控制字下一拍低位编码端九位参考通道使能九位转换专属正常时钟更新红外九位参考使能窗
					reg_control_next[CTRL_EN_9_AMB] = (i_macro_tick >= 13'd416) && (i_macro_tick < 13'd470); // 红外时隙九位环境通路窗口开启
					reg_control_next[CTRL_EN_9_DC] = (i_macro_tick >= 13'd416) && (i_macro_tick < 13'd470) &&
					(reg_ir_frame_type == FRAME_TYPE_NORMAL); // SAR9 IR仅NORMAL允许DC
					reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] = reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] | (((i_macro_tick >= 13'd418) && (i_macro_tick < 13'd470)) ?
					reg_ir_amb_code : 8'h00);   // SAR9 IR AMB窗口不破坏先前RED窗口的有效码位；ISE-04 本行仅在695行reg_ir_precision==1'b0分支内执行，与684-694行SAR15分支互斥，逐位透传reg_ir_amb_code，是RED侧651行的独立红外镜像 @satisfies: ISE-04
					reg_control_next[CTRL_DC9_H:CTRL_DC9_L] = reg_control_next[CTRL_DC9_H:CTRL_DC9_L] | (((i_macro_tick >= 13'd426) && (i_macro_tick < 13'd470) &&
					(reg_ir_frame_type == FRAME_TYPE_NORMAL)) ? reg_ir_dc_code : 8'h00); // SAR9 IR DC窗口仅在自身有效时增加码位；ISE-04 本行同属695行SAR9专属分支，与SAR15 IR DC总线(693行)结构互斥，逐位透传reg_ir_dc_code @satisfies: ISE-04
				end
				if(flag_ir_has_owner == 1'b1)begin
					reg_control_next[CTRL_EN_TIA] = reg_control_next[CTRL_EN_TIA] ||
					((i_macro_tick >= (reg_ir_precision ? 13'd426 : 13'd443)) &&
					(i_macro_tick < (reg_ir_precision ? 13'd465 : 13'd463))); // IR TIA采样窗口
					reg_control_next[CTRL_AFERST] = reg_control_next[CTRL_AFERST] ||
					((i_macro_tick >= (reg_ir_precision ? 13'd426 : 13'd443)) &&
					(i_macro_tick < (reg_ir_precision ? 13'd446 : 13'd455))); // IR前端复位窗口
					reg_control_next[CTRL_TIAEN] = reg_control_next[CTRL_EN_TIA]; // 时序写入寄存控制字下一拍低位编码端跨阻时钟选择位红外波形控制更新红外跨阻时钟跟随
					reg_control_next[CTRL_Q2] = reg_control_next[CTRL_Q2] ||
					((i_macro_tick >= (reg_ir_precision ? 13'd447 : 13'd456)) &&
					(i_macro_tick < (reg_ir_precision ? 13'd455 : 13'd458))); // IR Q2窗口
					reg_control_next[CTRL_Q3] = reg_control_next[CTRL_Q3] ||
					((i_macro_tick >= (reg_ir_precision ? 13'd456 : 13'd459)) &&
					(i_macro_tick < (reg_ir_precision ? 13'd464 : 13'd461))); // IR固定Q3窗口
					if(reg_ir_precision == 1'b1)begin
						reg_control_next[CTRL_Q1_15] = (i_macro_tick >= 13'd444) && (i_macro_tick < 13'd465); // 时序写入寄存控制字下一拍低位编码端十五位第一相位十五位转换专属红外波形控制更新红外十五位第一相位
						reg_control_next[CTRL_EN_15] = reg_control_next[CTRL_Q1_15]; // 时序写入寄存控制字下一拍低位编码端十五位阵列使能十五位转换专属红外波形控制更新红外十五位阵列使能
					end else begin
						reg_control_next[CTRL_Q1_9] = (i_macro_tick >= 13'd453) && (i_macro_tick < 13'd462); // 时序写入寄存控制字下一拍低位编码端九位第一相位九位转换专属正常时钟更新红外九位第一相位
					end
					if((reg_ir_frame_type != FRAME_TYPE_AMB) && (i_macro_tick >= (reg_ir_precision ? 13'd455 : 13'd458)) && (i_macro_tick < (reg_ir_precision ? 13'd464 : 13'd461)))begin
						reg_control_next[CTRL_LED_IR] = !reg_ir_input_source; // 时序写入寄存控制字下一拍低位编码端红外灯选择位红外灯通路红外波形控制更新；ILM-07 IR_ONLY固定电流下本行是唯一活动色通道LED门控，独立复现673行RED半句的同款EXTERNAL_TEST_CURRENT封锁逻辑，两个色通道各自拥有互不依赖的输入源快照 @satisfies: ILM-04, ILM-05, ILM-07
						reg_control_next[CTRL_LED_CODE] = !reg_ir_input_source; // 时序写入寄存控制字下一拍低位编码端灯码选择位红外波形控制更新红外灯码选择
						reg_control_next[CTRL_LED_DATA_H:CTRL_LED_DATA_L] = reg_ir_leddac_code; // 时序写入寄存控制字下一拍低位编码端灯数据总线红外波形控制更新红外灯数据窗
					end
				end
			end
			if(calibration_wave_active_o == 1'b1)begin // ILM-11/12该分支全程只使用CTRL_*_9系列寄存器，无reg_cal_precision分支切换到15位，是与631/679行RED/IR运行波形块并列但结构独立的专属SAR9校准波形，AMB_CAL/DCS_CAL统一走此代码路径 @satisfies: ILM-11, ILM-12
				reg_control_next[CTRL_IREF_9] = 1'b1; // 时序写入寄存控制字下一拍低位编码端九位参考选择位九位转换专属校准波形控制更新
				reg_control_next[CTRL_IREF_IDAC] = (i_calibration_local_tick >= 10'd229) &&
				(i_calibration_local_tick < 10'd269); // CAL共享IDAC时钟严格来自netlist
				reg_control_next[CTRL_EN_9_IREF] = (i_calibration_local_tick >= 10'd202) &&
				(i_calibration_local_tick < 10'd274); // CAL SAR9 IREF使能严格来自netlist
				reg_control_next[CTRL_EN_9_AMB] = (i_calibration_local_tick >= 10'd222) &&
				(i_calibration_local_tick < 10'd276); // CAL AMB通路窗口严格来自netlist
				reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] = ((i_calibration_local_tick >= 10'd224) &&
				(i_calibration_local_tick < 10'd276)) ? reg_cal_amb_code : 8'h00; // CAL AMB逐bit码窗严格为[224,276)；SID-08 该窗口与frame_type/颜色无关，DCS_CAL RED阶段AMB总线持续保持已确认AMB码；ILM-12该窗口AMB_CAL/DCS_CAL统一生效，DCS_CAL RED/IR阶段AMB总线均持有已确认AMB码，与选定颜色DC候选窗口(746行)并存；ISE-06 本行是AMB_CAL/DCS_CAL共同唯一驱动SAR9 AMB候选总线的位置，逐bit透传reg_cal_amb_code，AMB_CAL下DC总线由744/746行结构性保持零，两种校准帧类型对AMB总线的驱动完全相同 @satisfies: SID-08, ILM-12, ISE-06
				if(reg_cal_frame_type == FRAME_TYPE_DCS)begin
					reg_control_next[CTRL_EN_9_DC] = (i_calibration_local_tick >= 10'd222) &&
					(i_calibration_local_tick < 10'd276); // DCS_CAL才允许SAR9 DC通路；SID-07 AMB_CAL时frame_type非DCS，本if不执行，DC通路保持复位默认0；ILM-11 AMB_CAL下同一原因DC通路(本行及746行DC码窗)结构性保持复位默认0，无DC码窗口；ISE-06 本if正是AMB_CAL(DC总线归零)与DCS_CAL(允许DC通路)两种帧类型对DC使能位唯一的行为分岔点 @satisfies: SID-07, ILM-11, ISE-06
					reg_control_next[CTRL_DC9_H:CTRL_DC9_L] = ((i_calibration_local_tick >= 10'd232) &&
					(i_calibration_local_tick < 10'd276)) ? reg_cal_dc_code : 8'h00; // DCS_CAL使用独立DC码窗；ISE-06 本行仅在744行DCS_CAL条件成立时执行，逐bit透传reg_cal_dc_code(该寄存器已按选中颜色锁存红光/红外候选)，是DCS_CAL"驱动已确认AMB与选中颜色DC总线"要求的DC总线一半 @satisfies: ISE-06
				end
				if(flag_cal_has_owner == 1'b1)begin
					reg_control_next[CTRL_AFERST] = (i_calibration_local_tick >= 10'd249) &&
					(i_calibration_local_tick < 10'd261); // CAL AFE复位严格为[249,261)
					reg_control_next[CTRL_TIAEN] = (i_calibration_local_tick >= 10'd249) &&
					(i_calibration_local_tick < 10'd269); // CAL TIA时钟严格为[249,269)
					reg_control_next[CTRL_Q1_9] = (i_calibration_local_tick >= 10'd259) &&
					(i_calibration_local_tick < 10'd268); // CAL SAR9 Q1严格为[259,268)
					reg_control_next[CTRL_Q2] = (reg_cal_frame_type == FRAME_TYPE_DCS) &&
					(i_calibration_local_tick >= 10'd262) &&
					(i_calibration_local_tick < 10'd264); // CAL Q2严格为[262,264)，仅DCS_CAL产生：DCS的LED仅Q3导通、Q2/Q3本就不对称，chopping相减完整保留LED残余；AMB_CAL的Q2/Q3两相对称抵消对环境光残余结构性不敏感，抑制后阈值判据改为直接读Q3单相原始摆幅
					reg_control_next[CTRL_Q3] = (i_calibration_local_tick >= 10'd265) &&
					(i_calibration_local_tick < 10'd267); // CAL Q3严格围绕中心266；SID-03 该窗口在整个校准波形块内对AMB_CAL/DCS_CAL RED/DCS_CAL IR三种帧类型统一生效，与NORMAL运行波形块(287-306一带)完全独立的代码路径，不做任何NORMAL-Q3替换 @satisfies: SID-03
					if(reg_cal_frame_type == FRAME_TYPE_DCS && reg_cal_input_source == 1'b0 && (i_calibration_local_tick >= 10'd265) && (i_calibration_local_tick < 10'd267))begin
						reg_control_next[CTRL_LED_R] = !reg_cal_color_ir; // 时序写入寄存控制字下一拍低位编码端红光灯选择位红光灯通路校准波形控制更新校准红光灯选；SID-07 AMB_CAL时整个if因frame_type非DCS不执行，两路LED保持复位默认0；SID-08 DCS_CAL RED阶段color_ir=0，仅本行置位，红光LED窗口唯一生效；ILM-11 AMB_CAL下两路LED同样保持复位默认0；ILM-12 DCS_CAL RED阶段仅本行置位，与IR相对色窗口(下一行)互斥不并存 @satisfies: SID-07, SID-08, ILM-11, ILM-12
						reg_control_next[CTRL_LED_IR] = reg_cal_color_ir; // 时序写入寄存控制字下一拍低位编码端红外灯选择位红外灯通路校准波形控制更新校准红外灯选；SID-09 DCS_CAL IR阶段color_ir=1，仅本行置位，红外LED窗口唯一生效，与上一行红光位互斥；ILM-12 DCS_CAL IR阶段仅本行置位，与RED相对色窗口(上一行)互斥不并存 @satisfies: SID-09, ILM-12
						reg_control_next[CTRL_LED_CODE] = 1'b1; // 时序写入寄存控制字下一拍低位编码端灯码选择位校准波形控制更新
						reg_control_next[CTRL_LED_DATA_H:CTRL_LED_DATA_L] = reg_cal_leddac_code; // 时序写入寄存控制字下一拍低位编码端灯数据总线校准波形控制更新
					end
				end
			end
		end
	end

	// 时序维护寄存运行活动
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_run_active <= 1'b0;             // 时序写入寄存运行活动异步复位清零
		end else begin
			if(flag_start_restore == 1'b1)begin
				reg_run_active <= 1'b1;         // 时序写入寄存运行活动启动确认复原
			end else if((i_run_enable == 1'b0 || flag_stop_pending == 1'b1) && o_wrapper_idle == 1'b1)begin
				reg_run_active <= 1'b0;         // 时序写入寄存运行活动校准波形控制更新
			end
		end
	end

	// 时序维护条件停止专用字段低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stop_pending <= 1'b0;          // 时序写入条件停止专用字段低位编码端异步复位清零
		end else begin
			if(i_control_abort_event == 1'b1)begin
				flag_stop_pending <= 1'b1;      // 时序写入条件停止专用字段低位编码端撤销期间保持
			end else if(i_stop_ack_event == 1'b1)begin
				flag_stop_pending <= 1'b1;      // 时序写入条件停止专用字段低位编码端停止确认挂起
			end else if(reg_run_active == 1'b0 && o_wrapper_idle == 1'b1)begin
				flag_stop_pending <= 1'b0;      // 时序写入条件停止专用字段低位编码端校准波形控制更新
			end else if(flag_start_restore == 1'b1)begin
				flag_stop_pending <= 1'b0;      // 新RUN启动恢复时撤销上一RUN残留的停止挂起
			end
		end
	end

	// 时序维护寄存校准环境数字码环境码通路低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_cal_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 时序写入寄存校准环境数字码环境码通路低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_amb_code <= reg_cal_amb_code; // 时序写入寄存校准环境数字码环境码通路低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_amb_code <= i_waveform_amb_code_snapshot; // 时序写入寄存校准环境数字码环境码通路低位编码端波形上下文锁存；ISE-01/02/03 本行仅在flag_context_fire && flag_context_is_cal的一拍锁存新候选码，两次真实fire之间(含i_control_abort_event期间的804-805行保持)总线值恒定，实时改变i_waveform_amb_code_snapshot不会影响当前已在途波形的741行AMB总线，下一波形只在自身flag_context_fire再次为真时才采用新码 @satisfies: ISE-01, ISE-02, ISE-03
			end
		end
	end

	// 时序维护寄存校准环境版本环境码通路高位编码端低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_cal_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序写入寄存校准环境版本环境码通路高位编码端低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_amb_epoch <= reg_cal_amb_epoch; // 时序写入寄存校准环境版本环境码通路高位编码端低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_amb_epoch <= i_waveform_amb_code_epoch; // 时序写入寄存校准环境版本环境码通路高位编码端低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存校准颜色红外红外专属红外光路低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cal_color_ir <= 1'b0;           // 时序写入寄存校准颜色红外红外专属红外光路低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_color_ir <= reg_cal_color_ir; // 时序写入寄存校准颜色红外红外专属红外光路低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_color_ir <= i_waveform_color_ir; // 时序写入寄存校准颜色红外红外专属红外光路低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存校准直流数字码直流码通路低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_cal_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 时序写入寄存校准直流数字码直流码通路低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_dc_code <= reg_cal_dc_code; // 时序写入寄存校准直流数字码直流码通路低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_dc_code <= i_waveform_dc_code_snapshot; // 时序写入寄存校准直流数字码直流码通路低位编码端波形上下文锁存；ISE-01/02/03 与808行同一flag_context_fire && flag_context_is_cal门控原子生效，DC总线(746行)的捕获/隔离/安全边界更新规律与AMB总线完全一致，色彩/帧类型/精度快照(829-837行reg_cal_color_ir等)也在同一拍原子更新 @satisfies: ISE-01, ISE-02, ISE-03
			end
		end
	end

	// 时序维护寄存校准直流版本直流码通路高位编码端低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_cal_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序写入寄存校准直流版本直流码通路高位编码端低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_dc_epoch <= reg_cal_dc_epoch; // 时序写入寄存校准直流版本直流码通路高位编码端低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_dc_epoch <= i_waveform_dc_code_epoch; // 时序写入寄存校准直流版本直流码通路高位编码端低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存校准帧标识低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_cal_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 时序写入寄存校准帧标识低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_frame_id <= reg_cal_frame_id; // 时序写入寄存校准帧标识低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_frame_id <= i_waveform_frame_id; // 时序写入寄存校准帧标识低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存校准帧类型低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cal_frame_type <= FRAME_TYPE_AMB; // 时序写入寄存校准帧类型低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_frame_type <= reg_cal_frame_type; // 时序写入寄存校准帧类型低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_frame_type <= i_waveform_frame_type; // 时序写入寄存校准帧类型低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存校准输入来源低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cal_input_source <= 1'b0;       // 时序写入寄存校准输入来源低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_input_source <= reg_cal_input_source; // 时序写入寄存校准输入来源低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_input_source <= i_waveform_input_source; // 时序写入寄存校准输入来源低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存校准发光数模数字码低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_cal_leddac_code <= 8'h00;               // 时序写入寄存校准发光数模数字码低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_leddac_code <= reg_cal_leddac_code; // 时序写入寄存校准发光数模数字码低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_leddac_code <= i_waveform_leddac_code_snapshot; // 时序写入寄存校准发光数模数字码低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存校准光学模式低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cal_optical_mode <= OPTICAL_MODE_BOTH; // 时序写入寄存校准光学模式低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_optical_mode <= reg_cal_optical_mode; // 时序写入寄存校准光学模式低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_optical_mode <= i_waveform_optical_mode; // 时序写入寄存校准光学模式低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存校准精度低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cal_precision <= 1'b0;          // 时序写入寄存校准精度低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_precision <= reg_cal_precision; // 时序写入寄存校准精度低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_precision <= 1'b0;      // 时序写入寄存校准精度低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护条件校准上下文有效低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_cal_context_valid <= 1'b0;     // 时序写入条件校准上下文有效低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			flag_cal_context_valid <= 1'b0;     // 时序写入条件校准上下文有效低位编码端撤销期间保持
		end else if(flag_start_restore == 1'b1)begin
			flag_cal_context_valid <= 1'b0;     // 新一轮启动清空滞留的校准接管资格
		end else begin
			if(flag_cal_wave_last == 1'b1)begin
				flag_cal_context_valid <= 1'b0; // 时序写入条件校准上下文有效低位编码端波形末拍释放
			end
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				flag_cal_context_valid <= 1'b1; // 时序写入条件校准上下文有效低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外环境数字码红外专属红外光路环境码通路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_ir_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 时序写入寄存红外环境数字码红外专属红外光路环境码通路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_amb_code <= reg_ir_amb_code; // 时序写入寄存红外环境数字码红外专属红外光路环境码通路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_amb_code <= i_waveform_amb_code_snapshot; // 时序写入寄存红外环境数字码红外专属红外光路环境码通路波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外环境版本红外专属红外光路环境码通路高位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_ir_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序写入寄存红外环境版本红外专属红外光路环境码通路高位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_amb_epoch <= reg_ir_amb_epoch; // 时序写入寄存红外环境版本红外专属红外光路环境码通路高位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_amb_epoch <= i_waveform_amb_code_epoch; // 时序写入寄存红外环境版本红外专属红外光路环境码通路高位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外直流数字码红外专属红外光路直流码通路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_ir_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 时序写入寄存红外直流数字码红外专属红外光路直流码通路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_dc_code <= reg_ir_dc_code;   // 时序写入寄存红外直流数字码红外专属红外光路直流码通路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_dc_code <= i_waveform_dc_code_snapshot; // 时序写入寄存红外直流数字码红外专属红外光路直流码通路波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外直流版本红外专属红外光路直流码通路高位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_ir_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序写入寄存红外直流版本红外专属红外光路直流码通路高位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_dc_epoch <= reg_ir_dc_epoch; // 时序写入寄存红外直流版本红外专属红外光路直流码通路高位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_dc_epoch <= i_waveform_dc_code_epoch; // 时序写入寄存红外直流版本红外专属红外光路直流码通路高位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外帧标识红外专属红外光路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_ir_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 时序写入寄存红外帧标识红外专属红外光路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_frame_id <= reg_ir_frame_id; // 时序写入寄存红外帧标识红外专属红外光路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_frame_id <= i_waveform_frame_id; // 时序写入寄存红外帧标识红外专属红外光路波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外帧类型红外专属红外光路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ir_frame_type <= FRAME_TYPE_NORMAL; // 时序写入寄存红外帧类型红外专属红外光路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_frame_type <= reg_ir_frame_type; // 时序写入寄存红外帧类型红外专属红外光路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_frame_type <= i_waveform_frame_type; // 时序写入寄存红外帧类型红外专属红外光路波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外输入来源红外专属红外光路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ir_input_source <= 1'b0;        // 时序写入寄存红外输入来源红外专属红外光路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_input_source <= reg_ir_input_source; // 时序写入寄存红外输入来源红外专属红外光路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_input_source <= i_waveform_input_source; // 时序写入寄存红外输入来源红外专属红外光路波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外发光数模数字码红外专属红外光路低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_ir_leddac_code <= 8'h00;                // 时序写入寄存红外发光数模数字码红外专属红外光路低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_leddac_code <= reg_ir_leddac_code; // 时序写入寄存红外发光数模数字码红外专属红外光路低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_leddac_code <= i_waveform_leddac_code_snapshot; // 时序写入寄存红外发光数模数字码红外专属红外光路低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外光学模式红外专属红外光路低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ir_optical_mode <= OPTICAL_MODE_BOTH; // 时序写入寄存红外光学模式红外专属红外光路低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_optical_mode <= reg_ir_optical_mode; // 时序写入寄存红外光学模式红外专属红外光路低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_optical_mode <= i_waveform_optical_mode; // 时序写入寄存红外光学模式红外专属红外光路低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红外精度红外专属红外光路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ir_precision <= 1'b0;           // 时序写入寄存红外精度红外专属红外光路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_precision <= reg_ir_precision; // 时序写入寄存红外精度红外专属红外光路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_precision <= i_waveform_precision_mode; // 时序写入寄存红外精度红外专属红外光路波形上下文锁存
			end
		end
	end

	// 时序维护条件红外上下文有效红外专属红外光路低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_ir_context_valid <= 1'b0;      // 时序写入条件红外上下文有效红外专属红外光路低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			flag_ir_context_valid <= 1'b0;      // 时序写入条件红外上下文有效红外专属红外光路低位编码端撤销期间保持
		end else if(flag_start_restore == 1'b1)begin
			flag_ir_context_valid <= 1'b0;      // 重新开始运行前撤销残留红外接管登记
		end else begin
			if(flag_ir_wave_last == 1'b1)begin
				flag_ir_context_valid <= 1'b0;  // 时序写入条件红外上下文有效红外专属红外光路低位编码端波形末拍释放
			end
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				flag_ir_context_valid <= 1'b1;  // 时序写入条件红外上下文有效红外专属红外光路低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红光环境数字码红光专属可见光路环境码通路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_red_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 时序写入寄存红光环境数字码红光专属可见光路环境码通路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_amb_code <= reg_red_amb_code; // 时序写入寄存红光环境数字码红光专属可见光路环境码通路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_amb_code <= i_waveform_amb_code_snapshot; // 时序写入寄存红光环境数字码红光专属可见光路环境码通路波形上下文锁存
			end
		end
	end

	// 时序维护寄存红光环境版本红光专属可见光路环境码通路高位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_red_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序写入寄存红光环境版本红光专属可见光路环境码通路高位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_amb_epoch <= reg_red_amb_epoch; // 时序写入寄存红光环境版本红光专属可见光路环境码通路高位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_amb_epoch <= i_waveform_amb_code_epoch; // 时序写入寄存红光环境版本红光专属可见光路环境码通路高位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红光直流数字码红光专属可见光路直流码通路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_red_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 时序写入寄存红光直流数字码红光专属可见光路直流码通路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_dc_code <= reg_red_dc_code; // 时序写入寄存红光直流数字码红光专属可见光路直流码通路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_dc_code <= i_waveform_dc_code_snapshot; // 时序写入寄存红光直流数字码红光专属可见光路直流码通路波形上下文锁存
			end
		end
	end

	// 时序维护寄存红光直流版本红光专属可见光路直流码通路高位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_red_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 时序写入寄存红光直流版本红光专属可见光路直流码通路高位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_dc_epoch <= reg_red_dc_epoch; // 时序写入寄存红光直流版本红光专属可见光路直流码通路高位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_dc_epoch <= i_waveform_dc_code_epoch; // 时序写入寄存红光直流版本红光专属可见光路直流码通路高位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红光帧标识红光专属可见光路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_red_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 时序写入寄存红光帧标识红光专属可见光路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_frame_id <= reg_red_frame_id; // 时序写入寄存红光帧标识红光专属可见光路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_frame_id <= i_waveform_frame_id; // 时序写入寄存红光帧标识红光专属可见光路波形上下文锁存
			end
		end
	end

	// 时序维护红光独立时序核接管瞬间登记的RUN代际快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_red_generation <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序写入红光RUN代际快照异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_generation <= reg_red_generation; // 时序写入红光RUN代际快照撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_generation <= i_run_generation; // 红光固定接管点fire时原子登记当前RUN代际
			end
		end
	end

	// 时序维护红外时序模板接管瞬间同步记录的RUN代际
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ir_generation <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序写入红外RUN代际记录异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_ir_generation <= reg_ir_generation; // 时序写入红外RUN代际记录撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
				reg_ir_generation <= i_run_generation; // 红外固定接管点fire时同步写入当前RUN代际
			end
		end
	end

	// 时序维护校准子帧首次接管时锁定的RUN代际编号
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cal_generation <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序写入校准RUN代际编号异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_cal_generation <= reg_cal_generation; // 时序写入校准RUN代际编号撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
				reg_cal_generation <= i_run_generation; // 校准接管点fire时锁定本次子帧对应的RUN代际
			end
		end
	end

	// 时序维护寄存红光帧类型红光专属可见光路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_red_frame_type <= FRAME_TYPE_NORMAL; // 时序写入寄存红光帧类型红光专属可见光路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_frame_type <= reg_red_frame_type; // 时序写入寄存红光帧类型红光专属可见光路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_frame_type <= i_waveform_frame_type; // 时序写入寄存红光帧类型红光专属可见光路波形上下文锁存
			end
		end
	end

	// 时序维护寄存红光输入来源红光专属可见光路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_red_input_source <= 1'b0;       // 时序写入寄存红光输入来源红光专属可见光路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_input_source <= reg_red_input_source; // 时序写入寄存红光输入来源红光专属可见光路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_input_source <= i_waveform_input_source; // 时序写入寄存红光输入来源红光专属可见光路波形上下文锁存
			end
		end
	end

	// 时序维护寄存红光发光数模数字码红光专属可见光路低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_red_leddac_code <= 8'h00;               // 时序写入寄存红光发光数模数字码红光专属可见光路低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_leddac_code <= reg_red_leddac_code; // 时序写入寄存红光发光数模数字码红光专属可见光路低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_leddac_code <= i_waveform_leddac_code_snapshot; // 时序写入寄存红光发光数模数字码红光专属可见光路低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红光光学模式红光专属可见光路低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_red_optical_mode <= OPTICAL_MODE_BOTH; // 时序写入寄存红光光学模式红光专属可见光路低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_optical_mode <= reg_red_optical_mode; // 时序写入寄存红光光学模式红光专属可见光路低位编码端撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_optical_mode <= i_waveform_optical_mode; // 时序写入寄存红光光学模式红光专属可见光路低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存红光精度红光专属可见光路
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_red_precision <= 1'b0;          // 时序写入寄存红光精度红光专属可见光路异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_red_precision <= reg_red_precision; // 时序写入寄存红光精度红光专属可见光路撤销期间保持
		end else begin
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				reg_red_precision <= i_waveform_precision_mode; // 时序写入寄存红光精度红光专属可见光路波形上下文锁存
			end
		end
	end

	// 时序维护条件红光上下文有效红光专属可见光路低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_red_context_valid <= 1'b0;     // 时序写入条件红光上下文有效红光专属可见光路低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			flag_red_context_valid <= 1'b0;     // 时序写入条件红光上下文有效红光专属可见光路低位编码端撤销期间保持
		end else if(flag_start_restore == 1'b1)begin
			flag_red_context_valid <= 1'b0;     // 开机重启时丢弃旧运行遗留的可见光接管
		end else begin
			if(flag_red_wave_last == 1'b1)begin
				flag_red_context_valid <= 1'b0; // 时序写入条件红光上下文有效红光专属可见光路低位编码端波形末拍释放
			end
			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
				flag_red_context_valid <= 1'b1; // 时序写入条件红光上下文有效红光专属可见光路低位编码端波形上下文锁存
			end
		end
	end

	// 时序维护寄存结果所有权撤销专用字段
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_owner_abort_seen <= 1'b0;       // 时序写入寄存结果所有权撤销专用字段异步复位清零
		end else if(flag_owner_release == 1'b1)begin
			reg_owner_abort_seen <= 1'b0;       // 时序写入寄存结果所有权撤销专用字段结果完成释放；与abort同拍时owner已释放，不再保留撤销标记
		end else if(i_control_abort_event == 1'b1)begin
			if(adc_owner_inflight_o == 1'b1)begin
				reg_owner_abort_seen <= 1'b1;   // 时序写入寄存结果所有权撤销专用字段校准波形控制更新
			end
		end else if(flag_owner_commit_fire == 1'b1)begin
			reg_owner_abort_seen <= 1'b0;       // 时序写入寄存结果所有权撤销专用字段所有权提交锁存
		end
	end

	// 时序维护寄存结果所有权采样序号低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
	reg_owner_sample_index <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 时序写入寄存结果所有权采样序号低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_owner_sample_index <= reg_owner_sample_index; // 时序写入寄存结果所有权采样序号低位编码端撤销期间保持
		end else if(flag_owner_release == 1'b1)begin
			reg_owner_sample_index <= reg_owner_sample_index; // 时序写入寄存结果所有权采样序号低位编码端结果完成释放
		end else if(flag_owner_commit_fire == 1'b1)begin
			reg_owner_sample_index <= i_adc_owner_sample_index; // 时序写入寄存结果所有权采样序号低位编码端所有权提交锁存
		end
	end

	// 时序维护寄存结果所有权提交时刻锁存的RUN代际
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_owner_generation <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序写入寄存owner RUN代际异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_owner_generation <= reg_owner_generation; // 时序写入寄存owner RUN代际撤销期间保持
		end else if(flag_owner_release == 1'b1)begin
			reg_owner_generation <= reg_owner_generation; // 时序写入寄存owner RUN代际结果完成释放
		end else if(flag_owner_commit_fire == 1'b1)begin
			reg_owner_generation <= i_run_generation; // 时序写入寄存owner RUN代际所有权提交锁存
		end
	end

	// 时序维护寄存结果所有权提交时刻锁存的帧号身份
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_owner_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 时序写入寄存owner帧号身份异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_owner_frame_id <= reg_owner_frame_id; // 时序写入寄存owner帧号身份撤销期间保持
		end else if(flag_owner_release == 1'b1)begin
			reg_owner_frame_id <= reg_owner_frame_id; // 时序写入寄存owner帧号身份结果完成释放
		end else if(flag_owner_commit_fire == 1'b1)begin
			reg_owner_frame_id <= i_adc_owner_frame_id; // 时序写入寄存owner帧号身份所有权提交锁存
		end
	end

	// 校准owner提交沿锁存所在子帧序号，供S1迟到诊断与Q3绑定判定，释放与abort期间保持
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_owner_cal_subframe <= 3'd0;     // 复位清除owner子帧绑定
		end else if(flag_owner_commit_fire == 1'b1)begin
			reg_owner_cal_subframe <= i_calibration_subframe_index; // 提交沿记录调度器当前子帧，RED/IR owner同样记录但只在校准槽位使用
		end
	end

	// 时序维护寄存结果所有权提交时刻锁存的颜色身份
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_owner_color_ir <= 1'b0;         // 时序写入寄存owner颜色身份异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_owner_color_ir <= reg_owner_color_ir; // 时序写入寄存owner颜色身份撤销期间保持
		end else if(flag_owner_release == 1'b1)begin
			reg_owner_color_ir <= reg_owner_color_ir; // 时序写入寄存owner颜色身份结果完成释放
		end else if(flag_owner_commit_fire == 1'b1)begin
			reg_owner_color_ir <= i_adc_owner_color_ir; // 时序写入寄存owner颜色身份所有权提交锁存
		end
	end

	// 时序维护寄存结果所有权提交时刻锁存的类型身份
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_owner_frame_type <= 2'b00;      // 时序写入寄存owner类型身份异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_owner_frame_type <= reg_owner_frame_type; // 时序写入寄存owner类型身份撤销期间保持
		end else if(flag_owner_release == 1'b1)begin
			reg_owner_frame_type <= reg_owner_frame_type; // 时序写入寄存owner类型身份结果完成释放
		end else if(flag_owner_commit_fire == 1'b1)begin
			reg_owner_frame_type <= i_adc_owner_frame_type; // 时序写入寄存owner类型身份所有权提交锁存
		end
	end

	// 时序维护寄存结果所有权提交时刻锁存的精度身份
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_owner_precision_mode <= 1'b0;   // 时序写入寄存owner精度身份异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_owner_precision_mode <= reg_owner_precision_mode; // 时序写入寄存owner精度身份撤销期间保持
		end else if(flag_owner_release == 1'b1)begin
			reg_owner_precision_mode <= reg_owner_precision_mode; // 时序写入寄存owner精度身份结果完成释放
		end else if(flag_owner_commit_fire == 1'b1)begin
			reg_owner_precision_mode <= i_adc_owner_precision_mode; // 时序写入寄存owner精度身份所有权提交锁存
		end
	end

	// 时序维护寄存结果所有权槽位低位编码端
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_owner_slot <= SLOT_RED;         // 时序写入寄存结果所有权槽位低位编码端异步复位清零
		end else if(i_control_abort_event == 1'b1)begin
			reg_owner_slot <= reg_owner_slot;   // 时序写入寄存结果所有权槽位低位编码端撤销期间保持
		end else if(flag_owner_release == 1'b1)begin
			reg_owner_slot <= reg_owner_slot;   // 时序写入寄存结果所有权槽位低位编码端结果完成释放
		end else if(flag_owner_commit_fire == 1'b1)begin
			if(flag_red_owner_candidate == 1'b1)begin
				reg_owner_slot <= SLOT_RED;     // 时序写入寄存结果所有权槽位低位编码端红光所有权候选
			end else if(flag_ir_owner_candidate == 1'b1)begin
				reg_owner_slot <= SLOT_IR;      // 时序写入寄存结果所有权槽位低位编码端红外所有权候选红外所有权提交选择
			end else begin
				reg_owner_slot <= SLOT_CAL;     // 时序写入寄存结果所有权槽位低位编码端正常时钟更新
			end
		end
	end

	//----------------故障记录处理区域----------------//
	// 时序维护新故障episode单周期脉冲
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_ssw_fault_valid <= 1'b0;             // 时序写入故障valid脉冲异步复位清零
		end else if(flag_ssw_fault_rising == 1'b1)begin
			flag_ssw_fault_valid <= 1'b1;             // 时序写入本地阻断故障首次跳变时刻拉出一拍valid
		end else begin
			flag_ssw_fault_valid <= 1'b0;             // 时序写入非跳变时刻始终保持valid为低
		end
	end

	// 时序维护本次故障是否绑定了真实事务身份
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_ssw_fault_identity_valid <= 1'b0;    // 时序写入身份有效位异步复位清零
		end else if(flag_start_restore == 1'b1)begin
			flag_ssw_fault_identity_valid <= 1'b0;    // 时序写入身份有效位启动确认复原
		end else begin
			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
				flag_ssw_fault_identity_valid <= 1'b0; // 时序写入身份有效位诊断确认清除
			end
			if(flag_ssw_fault_rising == 1'b1)begin
				if(flag_owner_commit_error == 1'b1)begin
					flag_ssw_fault_identity_valid <= 1'b1; // 非法owner提交候选具备可报告身份
				end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
					flag_ssw_fault_identity_valid <= 1'b1; // 在途owner遭遇DONE错配时报告其身份
				end else begin
					flag_ssw_fault_identity_valid <= 1'b0; // 静态偏置、双模式或接管点违规无可报告的单一事务身份
				end
			end
		end
	end

	// 时序维护故障事务帧号快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ssw_fault_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 时序写入故障帧号快照异步复位清零
		end else if(flag_ssw_fault_rising == 1'b1)begin
			if(flag_owner_commit_error == 1'b1)begin
				reg_ssw_fault_frame_id <= i_adc_owner_frame_id; // 快照被拒绝owner候选的帧号
			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
				reg_ssw_fault_frame_id <= reg_owner_frame_id; // 快照在途owner自身锁存的帧号
			end
		end
	end

	// 时序维护故障事务序号快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ssw_fault_sample_index <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 时序写入故障序号快照异步复位清零
		end else if(flag_ssw_fault_rising == 1'b1)begin
			if(flag_owner_commit_error == 1'b1)begin
				reg_ssw_fault_sample_index <= i_adc_owner_sample_index; // 快照被拒绝owner候选的序号
			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
				reg_ssw_fault_sample_index <= reg_owner_sample_index; // 快照在途owner自身锁存的序号
			end
		end
	end

	// 时序维护故障事务颜色快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ssw_fault_color_ir <= 1'b0;           // 时序写入故障颜色快照异步复位清零
		end else if(flag_ssw_fault_rising == 1'b1)begin
			if(flag_owner_commit_error == 1'b1)begin
				reg_ssw_fault_color_ir <= i_adc_owner_color_ir; // 快照被拒绝owner候选的颜色
			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
				reg_ssw_fault_color_ir <= reg_owner_color_ir; // 快照在途owner自身锁存的颜色
			end
		end
	end

	// 时序维护故障事务类型快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ssw_fault_frame_type <= 2'b00;        // 时序写入故障类型快照异步复位清零
		end else if(flag_ssw_fault_rising == 1'b1)begin
			if(flag_owner_commit_error == 1'b1)begin
				reg_ssw_fault_frame_type <= i_adc_owner_frame_type; // 快照被拒绝owner候选的类型
			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
				reg_ssw_fault_frame_type <= reg_owner_frame_type; // 快照在途owner自身锁存的类型
			end
		end
	end

	// 时序维护故障事务精度快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ssw_fault_precision_mode <= 1'b0;     // 时序写入故障精度快照异步复位清零
		end else if(flag_ssw_fault_rising == 1'b1)begin
			if(flag_owner_commit_error == 1'b1)begin
				reg_ssw_fault_precision_mode <= i_adc_owner_precision_mode; // 快照被拒绝owner候选的精度
			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
				reg_ssw_fault_precision_mode <= reg_owner_precision_mode; // 快照在途owner自身锁存的精度
			end
		end
	end

	// 时序维护故障事务所属RUN代际快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ssw_fault_generation <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 时序写入故障RUN代际快照异步复位清零
		end else if(flag_ssw_fault_rising == 1'b1)begin
			if(flag_owner_commit_error == 1'b1)begin
				reg_ssw_fault_generation <= i_run_generation; // 快照被拒绝owner候选到达时的实时RUN代际
			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
				reg_ssw_fault_generation <= reg_owner_generation; // 快照在途owner自身锁存的RUN代际
			end
		end
	end

endmodule





