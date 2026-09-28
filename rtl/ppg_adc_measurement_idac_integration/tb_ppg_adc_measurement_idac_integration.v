`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026-08-12
// Design Name:     PPG ADC Measurement and IDAC Integration Verification
// Module Name:     tb_ppg_adc_measurement_idac_integration
// Description:     Self-checking AMI-01 through AMI-47 plus N08-01 integration regression.
// Simulations:     Vivado xsim 2022.2
//
// Referrences:     PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
// Dependencies:
//      DUT and all real integration submodules
//
// Version:         V1.8
// Revision Date:   2026-09-08
// History:
// 2026-08-12           V1.0       Erie        Create file.
// 2026-08-13           V1.1       Erie        Verify split safe-boundary routing.
// 2026-08-14           V1.2       Erie        Verify ADC completion sideband semantics.
// 2026-08-15           V1.3       Erie        Verify ADC result owner and lifecycle late-DONE rules.
// 2026-08-23           V1.4       Erie        Fix: this TB never connected/drove DUT i_run_generation (added in an earlier AMI revision), leaving it floating X; every generation-gated commit inside child modules (e.g. IDAC controller's AMB/DCS pending-to-committed transition, section 15.1's stale-generation rule) compared against X and never fired, hanging startup search forever from AMI-17 onward. Connect i_run_generation to a fixed-value reg and raise the global simulation watchdog from 200us to 2ms to match the now-real (previously silently-skipped) work. Fixed the hang; AMI-17/19/20/25/26/42 still failed for a second, separate reason.
// 2026-08-23           V1.5       Erie        Fix: this TB also never connected/drove DUT i_system_fault_discard_event, leaving it floating X; flag_ami_terminal_action's OR chain (i_stop_ack_event || i_control_abort_event || flag_system_fault_discard_pending || i_system_fault_discard_event) resolved to X whenever the other three terms were 0, poisoning AMI's private detection-discard broadcast into PWI, which poisoned the dynamic baseline cross detector's flag_control_clear/flag_arithmetic_cancel/o_result_ready and silently blocked the entire candidate-tracking pipeline feeding the 9-to-15-bit precision switch. Connect it to a fixed 0 reg. All 45 cases (AMI-01 through AMI-45) now pass with a clean $finish.
// 2026-08-23           V1.6       Erie        Add AMI-46/AMI-47: wire the section 6.10 public o_measurement_result_discard_*/o_detection_discard_* ports into the DUT instance (previously entirely omitted from the port map, hence unobservable). AMI-46 holds a formal result under i_measurement_result_ready backpressure and confirms abort emits exactly one public measurement-result discard with reason=ABORT and TXN_ID (frame_id/sample_index) bound to the held transaction. AMI-47 confirms at least one public detection-generation-flush broadcast occurs across the regression. All 47 cases now pass with a clean $finish.
// 2026-08-23           V1.7       Erie        Fix a stale AMI-40 assertion found while re-running this regression against the DUT's V1.11 fix (flag_stop_result_draining now also arms when STOP catches a real owner still in flight, per contract section 13's frozen late-DONE rule 1). AMI-40 previously asserted adc_complete_success_snapshot==1 for exactly this STOP-with-owner-inflight case; the contract requires success=0 (a single original-identity discard release that must never enter the formal result or detection chain), matching how AMI-22/32/39 already test the equivalent abort case. Corrected the assertion and strengthened it with !o_measurement_result_valid && o_measurement_output_idle. All 47 cases (AMI-01 through AMI-47) still pass with a clean $finish.
// 2026-09-08           V1.8       Erie        Add N08-01: wire the remaining section 6.10 o_detection_discard_identity_valid/frame_id/sample_index/color_ir ports into the DUT instance (previously entirely unconnected). N08-01 drives two back-to-back RED NORMAL transactions with the new send_normal_sample_tight task (same code-to-raw math as send_normal_sample minus the 20-cycle settle); the second transaction latches AMI's own flag_detection_pending while FIR is still mid-MAC on the first one's already-warm 21-tap window, then abort proves o_detection_discard_identity_valid/frame_id/sample_index/color_ir are bound to that still-resident second transaction's real identity before hand-off to PWI. This closes the pre-handoff half of N08 that a prior full-chip-level attempt (tb_ppg_control_top_baseline_cross.v) could not reach because its background stimulus generator's physical pacing was wider than the window; this module-level unit TB drives transactions directly and is not bound by that pacing floor. 48 cases (AMI-01 through AMI-47 plus N08-01) pass with a clean $finish.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年08月12日
// 设计名称:        PPG ADC测量与IDAC集成验证
// 模块名称:        tb_ppg_adc_measurement_idac_integration
// 模块说明:        使用真实子模块验证AMI-01至AMI-47及N08-01，不使用force或行为替身
// 仿真工程:        Vivado xsim 2022.2
//
// 参考资料:        PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
// 依赖文件:
//      DUT及全部真实集成子模块
//
// 当前版本:        V1.8
// 修订日期:        2026年09月08日
// 修订历史:
// 2026-08-12           V1.0       Erie        创建文件
// 2026-08-13           V1.1       Erie        验证两类安全边界独立路由
// 2026-08-14           V1.2       Erie        验证可靠ADC完成旁带
// 2026-08-15           V1.3       Erie        验证ADC结果owner与迟到DONE生命周期
// 2026-08-23           V1.4       Erie        修复：本TB从未连接/驱动过DUT的i_run_generation（更早一轮AMI改动新增的端口），导致悬空为X；子模块内所有按代际门控的pending转committed提交（例如IDAC控制器AMB/DCS候选提交、合同15.1节陈旧代际规则）比较结果恒为X，从未触发，导致启动搜索从AMI-17往后彻底卡死。补上固定值驱动，并把全局仿真watchdog从200us放宽到2ms以覆盖修复后真实变多的工作量。卡死修好了，但AMI-17/19/20/25/26/42仍然失败，是第二个独立原因
// 2026-08-23           V1.5       Erie        修复：本TB同样从未连接/驱动过DUT的i_system_fault_discard_event，悬空为X；flag_ami_terminal_action的或链（i_stop_ack_event || i_control_abort_event || flag_system_fault_discard_pending || i_system_fault_discard_event）在其余三项都是0时结果恒为X，把AMI私有检测代际清空广播喂进PWI后污染了动态基线相交检测器的flag_control_clear/flag_arithmetic_cancel/o_result_ready，悄悄堵死了驱动9到15-bit精度切换的整条候选跟踪流水线。补上固定0驱动即可。AMI-01至AMI-45全部45项现在都通过，仿真正常$finish
// 2026-08-23           V1.6       Erie        新增AMI-46/AMI-47：把合同6.10节公开的o_measurement_result_discard_*/o_detection_discard_*端口接入DUT例化（此前整组端口在例化里完全缺席，无法被观察）。AMI-46在i_measurement_result_ready反压保持正式结果在途期间触发abort，验证只产生一次公开正式结果丢弃、reason=ABORT且TXN_ID（frame_id/sample_index）绑定被丢弃事务。AMI-47验证全程至少产生一次公开检测代际清空广播。47项全部通过，仿真正常$finish
// 2026-08-23           V1.7       Erie        拿DUT V1.11修复（flag_stop_result_draining现在也在STOP恰好命中真实owner在途时置位，对应合同13节冻结的迟到DONE规则第1条）重跑这份回归时发现并修复AMI-40一条过时断言：原来对"STOP恰好命中owner在途"这个场景断言adc_complete_success_snapshot==1，但合同要求的是success=0（以原始身份释放一次discard，绝不进入正式结果或检测链），和AMI-22/32/39已经在测的abort等价场景应该一致。订正断言并加强为!o_measurement_result_valid && o_measurement_output_idle。AMI-01至AMI-47全部47项仍然通过，仿真正常$finish
// 2026-09-08           V1.8       Erie        新增N08-01：把6.10节剩余的o_detection_discard_identity_valid/frame_id/sample_index/color_ir端口接入DUT例化（此前完全未连接）。N08-01用新增的send_normal_sample_tight任务（与send_normal_sample共用码转换算法，只是不等20拍settle）背靠背驱动两笔RED NORMAL事务，第二笔完成让AMI自身flag_detection_pending武装到1时，FIR恰好还在处理第一笔样本已经预热到21点满窗后触发的MAC计算，借此天然卡住多拍窗口，随后abort验证o_detection_discard_identity_valid/frame_id/sample_index/color_ir真实绑定这笔仍在AMI侧、尚未交接给PWI的事务身份。此前在ppg_control_top整机级TB（tb_ppg_control_top_baseline_cross.v）尝试过这个场景但因bg_responder背景激励的真实物理节拍比这个窗口更宽而够不到；这份AMI自身module-level unit TB直接驱动事务，不受该节拍下限约束。48项（AMI-01至AMI-47加N08-01）全部通过，仿真正常$finish

module tb_ppg_adc_measurement_idac_integration ();

	//===================<参数定义>===================//
	localparam integer C_CLK_PERIOD = 10;       // 仿真时钟周期纳秒数
	localparam [1:0]FRAME_AMB = 2'b00;          // AMB_CAL事务编码
	localparam [1:0]FRAME_DCS = 2'b01;          // DCS_CAL事务编码
	localparam [1:0]FRAME_NORMAL = 2'b10;       // NORMAL事务编码

	//===================<寄存器信号>===================//
	reg i_clk;                                  // 仿真工作时钟
	reg i_rstn;                                 // DUT低有效异步复位
	reg i_active_config_valid;                  // ACTIVE整体合法资格
	reg [7:0]i_run_generation;                  // 当前RUN代际，全程保持固定值，供pending/committed码代际比对
	reg i_run_enable;                           // RUN生命周期电平
	reg i_allow_new_transaction;                // 新事务启动许可
	reg i_start_ack_event;                      // 新RUN开始单拍
	reg i_stop_ack_event;                       // STOP确认单拍
	reg i_control_abort_event;                  // abort撤销单拍
	reg i_diag_clear_event;                     // sticky清除单拍
	reg i_system_fault_discard_event;           // supervisor系统故障丢弃选择器，本TB无supervisor场景，恒为0
	reg [7:0]i_config_epoch;                    // 当前ACTIVE版本
	reg [7:0]i_stage1_coef_epoch;               // 当前Stage1版本
	reg [7:0]i_stage2_coef_epoch;               // 当前Stage2版本
	reg [7:0]i_dc_recovery_coef_epoch;          // 当前DC恢复版本
	reg i_transaction_start_valid;              // 待启动事务valid
	reg i_transaction_precision_mode;           // 待启动事务精度
	reg [15:0]i_transaction_frame_id;           // 待启动事务帧号
	reg [15:0]i_transaction_sample_index;       // 待启动事务序号
	reg i_transaction_color_ir;                 // 待启动事务颜色
	reg [1:0]i_transaction_frame_type;          // 待启动事务类型
	reg [7:0]i_transaction_amb_code_snapshot;   // 待启动AMB码快照
	reg [7:0]i_transaction_dc_code_snapshot;    // 待启动DC码快照
	reg [3:0]i_transaction_amb_code_epoch;      // 待启动AMB版本
	reg [3:0]i_transaction_dc_code_epoch;       // 待启动DC版本
	reg [9:0]i_dout_stage1_low;                 // Stage1物理码
	reg i_clk_stage1_dout_low_async;            // Stage1 DONE异步电平
	reg [9:0]i_dout_stage2_low;                 // Stage2物理码
	reg i_clk_stage2_dout_low_async;            // Stage2 DONE异步电平
	reg i_adc_idle;                             // 物理ADC空闲资格
	reg i_analog_safe;                          // 模拟安全资格
	reg i_macro_frame_safe_boundary;            // 精度切换与重检宏帧边界
	reg i_idac_code_safe_boundary;              // IDAC pending码提交边界
	reg [15:0]i_safe_frame_id;                  // 下一安全帧编号
	reg i_normal_frame_complete_event;          // NORMAL帧完成单拍
	reg i_calibration_frame_complete_event;     // 校准帧完成单拍
	reg i_calibration_sample_ready;             // 校准调度器ready
	reg i_measurement_result_ready;             // 正式结果消费者ready
	reg [1:0]i_idac_mode;                       // IDAC模式配置
	reg i_amb_enable;                           // AMB控制使能
	reg i_dcs_enable;                           // DCS控制使能
	reg i_amb_polarity;                         // AMB调码极性
	reg i_dcs_polarity;                         // DCS调码极性
	reg [7:0]i_amb_manual_code;                 // AMB手动码
	reg [7:0]i_amb_code_min;                    // AMB自动下界
	reg [7:0]i_amb_code_max;                    // AMB自动上界
	reg [7:0]i_dcs_r_manual_code;               // 红光DC手动码
	reg [7:0]i_dcs_r_code_min;                  // 红光DC下界
	reg [7:0]i_dcs_r_code_max;                  // 红光DC上界
	reg [7:0]i_dcs_ir_manual_code;              // 红外DC手动码
	reg [7:0]i_dcs_ir_code_min;                 // 红外DC下界
	reg [7:0]i_dcs_ir_code_max;                 // 红外DC上界
	reg signed [11:0]i_amb_threshold_low;       // AMB窗口下界
	reg signed [11:0]i_amb_threshold_high;      // AMB窗口上界
	reg signed [11:0]i_dcs_threshold_low;       // DCS窗口下界
	reg signed [11:0]i_dcs_threshold_high;      // DCS窗口上界
	reg [7:0]i_amb_confirm_count;               // AMB确认次数
	reg [7:0]i_dcs_confirm_count;               // DCS确认次数
	reg i_stage1_calibration_valid;             // Stage1正式校准资格
	reg signed [25:0]i_stage1_weight_q16_0;    // Stage1位0权重
	reg signed [25:0]i_stage1_weight_q16_1;    // Stage1位1权重
	reg signed [25:0]i_stage1_weight_q16_2;    // Stage1位2权重
	reg signed [25:0]i_stage1_weight_q16_3;    // Stage1位3权重
	reg signed [25:0]i_stage1_weight_q16_4;    // Stage1位4权重
	reg signed [25:0]i_stage1_weight_q16_5;    // Stage1位5权重
	reg signed [25:0]i_stage1_weight_q16_6;    // Stage1位6权重
	reg signed [25:0]i_stage1_weight_q16_7;    // Stage1位7权重
	reg signed [25:0]i_stage1_weight_q16_8;    // Stage1位8权重
	reg signed [25:0]i_stage1_weight_q16_9;    // Stage1位9权重
	reg signed [31:0]i_stage1_offset_q16;      // Stage1 Q16偏置
	reg i_stage2_calibration_valid;             // Stage2正式校准资格
	reg signed [19:0]i_stage2_gain_q16;        // Stage2 Q16增益
	reg signed [31:0]i_stage2_offset_q16;      // Stage2 Q16偏置
	reg i_dc9_recovery_valid;                   // SAR9恢复系数资格
	reg i_dc15_recovery_valid;                  // SAR15恢复系数资格
	reg signed [31:0]i_dc9_recovery_gain_q16;  // SAR9恢复Q16系数
	reg signed [31:0]i_dc15_recovery_gain_q16; // SAR15恢复Q16系数
	reg i_run_profile;                          // NORMAL或表征模式
	reg i_initial_precision;                    // 表征模式初始精度
	reg i_slope_mode;                           // 基线斜率模式
	reg signed [31:0]i_fixed_slope_q16;        // 固定Q16负斜率
	reg [15:0]i_alpha_q15;                      // 基础斜率比例
	reg [15:0]i_beta_q15;                       // 斜率平滑比例
	reg [15:0]i_timing_adjust_ratio_q15;        // 时间修正比例
	reg signed [31:0]i_slope_min_q16;          // 最负斜率边界
	reg signed [31:0]i_slope_max_q16;          // 近零斜率边界
	reg signed [31:0]i_baseline_delta_q16;     // 基线锚点偏置
	reg [31:0]i_cross_hysteresis_q16;           // 相交迟滞
	reg [15:0]i_lead_min_frames;                // 相交提前量下界
	reg [15:0]i_lead_max_frames;                // 相交提前量上界
	reg [3:0]i_cross_confirm_count;             // 相交确认次数
	reg [3:0]i_no_cross_limit;                  // 无相交周期阈值
	reg [3:0]i_peak_confirm_count;              // 波峰确认次数
	reg [3:0]i_valley_confirm_count;            // 波谷确认次数
	reg [23:0]i_direction_deadband;             // 方向判断死区
	reg [23:0]i_min_peak_valley_amplitude;      // 最小峰谷幅度
	reg [15:0]i_min_peak_to_valley_frames;      // 峰到谷最小帧差
	reg [15:0]i_min_peak_to_peak_frames;        // 峰到峰最小帧差
	reg [15:0]i_max_fine_window_frames;         // fine窗口最大帧数
	reg [15:0]i_max_reacquire_frames;           // 重新获取最大帧数
	reg i_peak_valley_config_valid;             // 峰谷配置资格
	reg [15:0]i_amb_recheck_interval_frames;    // AMB周期重检间隔

	//===================<线网信号>===================//
	wire o_transaction_start_ready;             // DUT事务启动ready
	wire o_transaction_start_fire;              // DUT唯一事务启动fire
	wire o_adc_transaction_complete_event;      // DUT经S1归属确认后的ADC完成脉冲
	wire o_adc_transaction_success;             // DUT完成脉冲绑定的成功资格
	wire [15:0]o_adc_complete_sample_index;     // DUT完成脉冲绑定的事务序号
	wire o_calibration_sample_valid;             // DUT校准请求valid
	wire [1:0]o_calibration_frame_type;          // DUT校准请求类型
	wire o_calibration_color_ir;                 // DUT校准请求颜色
	wire [1:0]o_calibration_request_reason;      // DUT校准请求来源
	wire o_calibration_request_fire;             // DUT校准请求握手
	wire o_measurement_result_valid;             // DUT正式结果valid
	wire o_measurement_result_discard_event;     // DUT正式结果生命周期丢弃单拍观测，合同6.10节公开端口
	wire [1:0]o_measurement_result_discard_reason; // DUT正式结果丢弃STOP、abort或系统故障三态归类
	wire o_measurement_result_discard_identity_valid; // DUT正式结果丢弃身份可信位，事件为高时恒为1
	wire [15:0]o_measurement_result_discard_frame_id; // DUT正式结果丢弃事务的真实物理帧号
	wire [15:0]o_measurement_result_discard_sample_index; // DUT正式结果丢弃事务的全局顺序编号
	wire signed [23:0]o_coarse_ppg_value;       // DUT粗PPG结果
	wire o_coarse_valid;                        // DUT粗结果资格
	wire signed [23:0]o_fine_ppg_value;         // DUT精细PPG结果
	wire o_fine_valid;                          // DUT精细结果资格
	wire signed [11:0]o_calibrated_s1_value;    // DUT正式Stage1残差
	wire signed [14:0]o_programmable_15_code;   // DUT正式15-bit残差
	wire o_programmable_15_valid;               // DUT正式15-bit资格
	wire [7:0]o_config_epoch;                   // DUT结果ACTIVE版本
	wire [7:0]o_coef_epoch;                     // DUT结果Stage1版本
	wire [7:0]o_stage2_result_coef_epoch;       // DUT结果Stage2版本
	wire [7:0]o_dc_result_coef_epoch;           // DUT结果DC恢复版本
	wire o_result_precision_mode;               // DUT结果精度
	wire [15:0]o_result_frame_id;               // DUT结果帧号
	wire [15:0]o_result_sample_index;           // DUT结果序号
	wire o_result_color_ir;                     // DUT结果颜色
	wire [1:0]o_result_frame_type;              // DUT结果类型
	wire [7:0]o_result_amb_code_snapshot;       // DUT结果AMB快照
	wire [7:0]o_result_dc_code_snapshot;        // DUT结果DC快照
	wire [3:0]o_result_amb_code_epoch;          // DUT结果AMB版本
	wire [3:0]o_result_dc_code_epoch;           // DUT结果DC版本
	wire [7:0]o_amb_code;                       // DUT AMB committed码
	wire [7:0]o_dcs_r_code;                     // DUT红光DC committed码
	wire [7:0]o_dcs_ir_code;                    // DUT红外DC committed码
	wire o_amb_code_at_min;                     // DUT AMB committed码位于配置下界
	wire o_amb_code_at_max;                     // DUT AMB committed码位于配置上界
	wire o_dcs_r_code_at_min;                   // DUT红光DC committed码位于配置下界
	wire o_dcs_r_code_at_max;                   // DUT红光DC committed码位于配置上界
	wire o_dcs_ir_code_at_min;                  // DUT红外DC committed码位于配置下界
	wire o_dcs_ir_code_at_max;                  // DUT红外DC committed码位于配置上界
	wire [3:0]o_amb_code_epoch;                 // DUT AMB版本
	wire [3:0]o_dcs_r_code_epoch;               // DUT红光DC版本
	wire [3:0]o_dcs_ir_code_epoch;              // DUT红外DC版本
	wire o_startup_search_complete;             // DUT启动搜索完成
	wire o_amb_code_update;                     // DUT环境光码提交事件
	wire o_dcs_r_code_update;                   // DUT红光DC码提交事件
	wire o_dcs_ir_code_update;                  // DUT红外DC码提交事件
	wire o_dcs_r_track_adjust;                  // DUT红光慢速跟踪调码事件
	wire o_dcs_ir_track_adjust;                 // DUT红外慢速跟踪调码事件
	wire o_amb_search_done;                     // DUT环境光启动搜索完成
	wire o_amb_search_exhausted;               // DUT环境光搜索耗尽诊断
	wire o_dcs_r_search_exhausted;             // DUT红光DC搜索耗尽诊断
	wire o_dcs_ir_search_exhausted;            // DUT红外DC搜索耗尽诊断
	wire o_dcs_r_search_done;                   // DUT红光DC启动搜索完成
	wire o_dcs_ir_search_done;                  // DUT红外DC启动搜索完成
	wire o_amb_pending_valid;                   // DUT AMB候选等待提交状态
	wire o_dcs_r_pending_valid;                 // DUT红光DC候选等待提交状态
	wire o_dcs_ir_pending_valid;                // DUT红外DC候选等待提交状态
	wire o_switch_hold_new_transaction;         // DUT精度提交阻止新事务
	wire o_idac_idle;                           // DUT IDAC空闲
	wire o_active_precision_mode;               // DUT committed精度
	wire o_fine_window_start_event;             // DUT真实进入15-bit事件
	wire [15:0]o_fine_window_start_frame_id;    // DUT首笔15-bit真实帧号
	wire o_precision_15_to_9_event;             // DUT真实返回9-bit事件
	wire [15:0]o_precision_15_to_9_frame_id;    // DUT首笔恢复9-bit真实帧号
	wire o_amb_recheck_accept;                  // DUT重检安全接管事件
	wire o_amb_recheck_busy;                    // DUT三阶段重检占用状态
	wire o_normal_output_inhibit;               // DUT重检输出禁止
	wire o_integration_protocol_error_sticky;   // DUT集成协议sticky
	wire o_wrapper_fault_blocking;              // DUT阻断故障
	wire o_normal_measurement_eligible;         // DUT NORMAL测量资格
	wire o_adc_chain_idle;                      // DUT ADC链空闲
	wire o_normal_fork_idle;                    // DUT NORMAL fork空闲
	wire o_measurement_output_idle;             // DUT测量输出链空闲
	wire o_datapath_empty;                      // DUT全部数据链排空
	wire o_detection_discard_event;             // DUT检测代际清空广播单拍观测，合同6.10节公开端口
	wire o_detection_discard_identity_valid;    // DUT检测代际清空是否命中AMI自身仍持有的真实身份，N08交接前半新增观测
	wire [15:0]o_detection_discard_frame_id;    // DUT检测代际清空绑定的真实物理帧号，N08交接前半新增观测
	wire [15:0]o_detection_discard_sample_index; // DUT检测代际清空绑定的真实全局序号，N08交接前半新增观测
	wire o_detection_discard_color_ir;          // DUT检测代际清空绑定的真实颜色身份，N08交接前半新增观测

	integer cnt_pass;                           // 真实通过项累计
	integer cnt_fail;                           // 真实失败项累计
	integer cnt_fire;                           // 唯一start fire计数
	integer cnt_adc_complete;                   // 已归属ADC完成旁带脉冲计数
	integer cnt_result;                         // 正式结果握手计数
	integer cnt_cal_request;                    // 校准请求握手计数
	integer cnt_watchdog;                       // 有界等待计数
	integer cnt_recheck_request;                // 周期重检请求握手计数
	integer cnt_recheck_accept;                 // 周期重检安全接管计数
	integer cnt_fine_start;                     // 真实进入15-bit事件计数
	integer cnt_return_9bit;                    // 真实返回9-bit事件计数
	integer cnt_macro_boundary_route;           // 宏帧边界到精度子系统计数
	integer cnt_idac_boundary_route;            // 码边界到IDAC子系统计数
	integer cnt_idac_code_update;               // 三路IDAC真实更新事件总数
	integer cnt_detection_discard_event;        // 检测代际清空公开广播累计次数
	reg flag_result_snapshot_valid;             // 最近一笔正式结果握手快照有效
	reg flag_result_snapshot_precision;         // 最近一笔结果的精度快照
	reg flag_result_snapshot_coarse_valid;      // 最近一笔结果的粗结果资格
	reg flag_result_snapshot_fine_valid;        // 最近一笔结果的精细结果资格
	reg flag_result_snapshot_programmable_valid; // 最近一笔15-bit可编程结果资格
	reg [1:0]result_snapshot_frame_type;        // 最近一笔结果的事务类型
	reg result_snapshot_color_ir;               // 最近一笔结果的颜色
	reg [7:0]result_snapshot_stage2_epoch;      // 最近一笔结果的Stage2版本
	reg [7:0]result_snapshot_config_epoch;      // 最近一笔结果的ACTIVE版本
	reg [7:0]result_snapshot_stage1_epoch;      // 最近一笔结果的Stage1版本
	reg [7:0]result_snapshot_dc_epoch;          // 最近一笔结果的DC恢复版本
	reg [15:0]result_snapshot_frame_id;         // 最近一笔结果的物理帧号
	reg [15:0]result_snapshot_sample_index;     // 最近一笔结果的样本序号
	reg [7:0]result_snapshot_amb_code;          // 最近一笔结果保留的AMB积分码
	reg [7:0]result_snapshot_dc_code;           // 最近一笔结果保留的颜色DC积分码
	reg [3:0]result_snapshot_amb_code_epoch;    // 最近一笔结果保留的AMB码版本
	reg [3:0]result_snapshot_dc_code_epoch;     // 最近一笔结果保留的颜色DC码版本
	reg flag_startup_incomplete_before_boundary; // 启动IDAC边界到达前的搜索未完成资格
	reg flag_stop_blocked_owner;                // STOP到达后当前owner禁止新事务的观察结果
	integer cnt_fire_before;                    // 单场景启动计数基准
	integer cnt_adc_complete_before;            // 单场景ADC完成脉冲计数基准
	integer cnt_normal_measurement_transfer;    // NORMAL测量分支真实消费次数
	integer cnt_normal_track_transfer;          // NORMAL跟踪分支真实消费次数
	integer cnt_detection_transfer;             // DC恢复检测分支真实消费次数
	integer cnt_measurement_transfer;           // DC恢复正式分支真实消费次数
	integer cnt_track_adjust;                   // NORMAL慢速跟踪实际调码次数
	integer next_frame_id;                      // 定向波形下一真实帧号
	integer next_sample_index;                  // 定向波形下一事务序号
	integer idx_sample;                         // 定向波形循环索引
	reg [3:0]amb_epoch_before_recheck;           // 周期重检前AMB版本
	reg [3:0]dcs_r_epoch_before_recheck;         // 周期重检前红光DC版本
	reg [3:0]dcs_ir_epoch_before_recheck;        // 周期重检前红外DC版本
	reg [15:0]last_macro_safe_frame_id;          // 最近宏帧边界采纳的safe frame ID
	integer cnt_macro_before_boundary;           // 单场景宏帧路由计数基准
	integer cnt_idac_before_boundary;            // 单场景IDAC路由计数基准
	integer cnt_idac_update_before_boundary;     // 单场景IDAC更新计数基准
	integer cnt_fine_before_boundary;            // 单场景进入15-bit计数基准
	integer cnt_return_before_boundary;          // 单场景返回9-bit计数基准
	integer cnt_recheck_before_boundary;         // 单场景重检接管计数基准
	integer cnt_characterization_track_before;   // 表征场景tracking消费计数基准
	integer cnt_characterization_adjust_before;  // 表征场景自动调码计数基准
	integer cnt_characterization_cal_before;     // 表征场景校准请求计数基准
	reg adc_complete_success_snapshot;          // 最近完成旁带绑定的成功资格
	reg [15:0]adc_complete_sample_index_snapshot; // 最近完成旁带绑定的事务序号
	reg flag_characterization_search_blocked;    // 表征自动搜索入口被AMI防御门控阻断
	integer cnt_detection_transfer_before_n08;  // N08场景第一笔背靠背样本前的检测分支消费计数基准
	reg flag_n08_window_hit;                    // N08场景第二笔样本确认武装到检测分支pending的观测结果
	reg flag_n08_fir_busy_observed;             // N08场景abort触发瞬间FIR确实仍处于忙碌状态的诊断观测
	reg [15:0]n08_expect_frame_id;              // N08场景真实驱动的第二笔样本物理帧号，仅取自TB自身激励
	reg [15:0]n08_expect_sample_index;          // N08场景真实驱动的第二笔样本全局序号，仅取自TB自身激励

	//===================<DUT实例化>===================//
	// 全部配置和事务输入均由本TB真实驱动，未观察诊断输出允许保持开放。
	ppg_adc_measurement_idac_integration dut(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_active_config_valid(i_active_config_valid),
		.i_run_generation(i_run_generation),
		.i_run_enable(i_run_enable),
		.i_allow_new_transaction(i_allow_new_transaction),
		.i_start_ack_event(i_start_ack_event),
		.i_stop_ack_event(i_stop_ack_event),
		.i_control_abort_event(i_control_abort_event),
		.i_diag_clear_event(i_diag_clear_event),
		.i_system_fault_discard_event(i_system_fault_discard_event),
		.i_config_epoch(i_config_epoch),
		.i_stage1_coef_epoch(i_stage1_coef_epoch),
		.i_stage2_coef_epoch(i_stage2_coef_epoch),
		.i_dc_recovery_coef_epoch(i_dc_recovery_coef_epoch),
		.i_transaction_start_valid(i_transaction_start_valid),
		.o_transaction_start_ready(o_transaction_start_ready),
		.o_transaction_start_fire(o_transaction_start_fire),
		.o_adc_transaction_complete_event(o_adc_transaction_complete_event),
		.o_adc_transaction_success(o_adc_transaction_success),
		.o_adc_complete_sample_index(o_adc_complete_sample_index),
		.i_transaction_precision_mode(i_transaction_precision_mode),
		.i_transaction_frame_id(i_transaction_frame_id),
		.i_transaction_sample_index(i_transaction_sample_index),
		.i_transaction_color_ir(i_transaction_color_ir),
		.i_transaction_frame_type(i_transaction_frame_type),
		.i_transaction_amb_code_snapshot(i_transaction_amb_code_snapshot),
		.i_transaction_dc_code_snapshot(i_transaction_dc_code_snapshot),
		.i_transaction_amb_code_epoch(i_transaction_amb_code_epoch),
		.i_transaction_dc_code_epoch(i_transaction_dc_code_epoch),
		.i_dout_stage1_low(i_dout_stage1_low),
		.i_clk_stage1_dout_low_async(i_clk_stage1_dout_low_async),
		.i_dout_stage2_low(i_dout_stage2_low),
		.i_clk_stage2_dout_low_async(i_clk_stage2_dout_low_async),
		.i_adc_idle(i_adc_idle),
		.i_analog_safe(i_analog_safe),
		.i_macro_frame_safe_boundary(i_macro_frame_safe_boundary),
		.i_idac_code_safe_boundary(i_idac_code_safe_boundary),
		.i_safe_frame_id(i_safe_frame_id),
		.i_normal_frame_complete_event(i_normal_frame_complete_event),
		.i_calibration_frame_complete_event(i_calibration_frame_complete_event),
		.i_calibration_sample_ready(i_calibration_sample_ready),
		.o_calibration_sample_valid(o_calibration_sample_valid),
		.o_calibration_frame_type(o_calibration_frame_type),
		.o_calibration_color_ir(o_calibration_color_ir),
		.o_calibration_precision_mode(),
		.o_calibration_request_reason(o_calibration_request_reason),
		.o_calibration_request_fire(o_calibration_request_fire),
		.i_measurement_result_ready(i_measurement_result_ready),
		.o_measurement_result_valid(o_measurement_result_valid),
		.o_coarse_ppg_value(o_coarse_ppg_value),
		.o_coarse_valid(o_coarse_valid),
		.o_coarse_recovery_calibrated(),
		.o_coarse_saturation_low(),
		.o_coarse_saturation_high(),
		.o_fine_ppg_value(o_fine_ppg_value),
		.o_fine_valid(o_fine_valid),
		.o_fine_recovery_calibrated(),
		.o_fine_saturation_low(),
		.o_fine_saturation_high(),
		.o_calibrated_s1_value(o_calibrated_s1_value),
		.o_programmable_15_code(o_programmable_15_code),
		.o_programmable_15_valid(o_programmable_15_valid),
		.o_config_epoch(o_config_epoch),
		.o_coef_epoch(o_coef_epoch),
		.o_stage2_result_coef_epoch(o_stage2_result_coef_epoch),
		.o_dc_result_coef_epoch(o_dc_result_coef_epoch),
		.o_result_precision_mode(o_result_precision_mode),
		.o_result_frame_id(o_result_frame_id),
		.o_result_sample_index(o_result_sample_index),
		.o_result_color_ir(o_result_color_ir),
		.o_result_frame_type(o_result_frame_type),
		.o_result_amb_code_snapshot(o_result_amb_code_snapshot),
		.o_result_dc_code_snapshot(o_result_dc_code_snapshot),
		.o_result_amb_code_epoch(o_result_amb_code_epoch),
		.o_result_dc_code_epoch(o_result_dc_code_epoch),
		.o_measurement_result_discard_event(o_measurement_result_discard_event),
		.o_measurement_result_discard_reason(o_measurement_result_discard_reason),
		.o_measurement_result_discard_identity_valid(o_measurement_result_discard_identity_valid),
		.o_measurement_result_discard_sample_valid(),
		.o_measurement_result_discard_frame_id(o_measurement_result_discard_frame_id),
		.o_measurement_result_discard_sample_index(o_measurement_result_discard_sample_index),
		.o_measurement_result_discard_color_ir(),
		.o_measurement_result_discard_frame_type(),
		.o_measurement_result_discard_precision(),
		.o_measurement_result_discard_run_generation(),
		.i_idac_mode(i_idac_mode),
		.i_amb_enable(i_amb_enable),
		.i_dcs_enable(i_dcs_enable),
		.i_amb_polarity(i_amb_polarity),
		.i_dcs_polarity(i_dcs_polarity),
		.i_amb_manual_code(i_amb_manual_code),
		.i_amb_code_min(i_amb_code_min),
		.i_amb_code_max(i_amb_code_max),
		.i_dcs_r_manual_code(i_dcs_r_manual_code),
		.i_dcs_r_code_min(i_dcs_r_code_min),
		.i_dcs_r_code_max(i_dcs_r_code_max),
		.i_dcs_ir_manual_code(i_dcs_ir_manual_code),
		.i_dcs_ir_code_min(i_dcs_ir_code_min),
		.i_dcs_ir_code_max(i_dcs_ir_code_max),
		.i_amb_threshold_low(i_amb_threshold_low),
		.i_amb_threshold_high(i_amb_threshold_high),
		.i_dcs_threshold_low(i_dcs_threshold_low),
		.i_dcs_threshold_high(i_dcs_threshold_high),
		.i_amb_confirm_count(i_amb_confirm_count),
		.i_dcs_confirm_count(i_dcs_confirm_count),
		.i_stage1_calibration_valid(i_stage1_calibration_valid),
		.i_stage1_weight_q16_0(i_stage1_weight_q16_0),
		.i_stage1_weight_q16_1(i_stage1_weight_q16_1),
		.i_stage1_weight_q16_2(i_stage1_weight_q16_2),
		.i_stage1_weight_q16_3(i_stage1_weight_q16_3),
		.i_stage1_weight_q16_4(i_stage1_weight_q16_4),
		.i_stage1_weight_q16_5(i_stage1_weight_q16_5),
		.i_stage1_weight_q16_6(i_stage1_weight_q16_6),
		.i_stage1_weight_q16_7(i_stage1_weight_q16_7),
		.i_stage1_weight_q16_8(i_stage1_weight_q16_8),
		.i_stage1_weight_q16_9(i_stage1_weight_q16_9),
		.i_stage1_offset_q16(i_stage1_offset_q16),
		.i_stage2_calibration_valid(i_stage2_calibration_valid),
		.i_stage2_gain_q16(i_stage2_gain_q16),
		.i_stage2_offset_q16(i_stage2_offset_q16),
		.i_dc9_recovery_valid(i_dc9_recovery_valid),
		.i_dc15_recovery_valid(i_dc15_recovery_valid),
		.i_dc9_recovery_gain_q16(i_dc9_recovery_gain_q16),
		.i_dc15_recovery_gain_q16(i_dc15_recovery_gain_q16),
		.i_run_profile(i_run_profile),
		.i_initial_precision(i_initial_precision),
		.i_slope_mode(i_slope_mode),
		.i_fixed_slope_q16(i_fixed_slope_q16),
		.i_alpha_q15(i_alpha_q15),
		.i_beta_q15(i_beta_q15),
		.i_timing_adjust_ratio_q15(i_timing_adjust_ratio_q15),
		.i_slope_min_q16(i_slope_min_q16),
		.i_slope_max_q16(i_slope_max_q16),
		.i_baseline_delta_q16(i_baseline_delta_q16),
		.i_cross_hysteresis_q16(i_cross_hysteresis_q16),
		.i_lead_min_frames(i_lead_min_frames),
		.i_lead_max_frames(i_lead_max_frames),
		.i_cross_confirm_count(i_cross_confirm_count),
		.i_no_cross_limit(i_no_cross_limit),
		.i_peak_confirm_count(i_peak_confirm_count),
		.i_valley_confirm_count(i_valley_confirm_count),
		.i_direction_deadband(i_direction_deadband),
		.i_min_peak_valley_amplitude(i_min_peak_valley_amplitude),
		.i_min_peak_to_valley_frames(i_min_peak_to_valley_frames),
		.i_min_peak_to_peak_frames(i_min_peak_to_peak_frames),
		.i_max_fine_window_frames(i_max_fine_window_frames),
		.i_max_reacquire_frames(i_max_reacquire_frames),
		.i_peak_valley_config_valid(i_peak_valley_config_valid),
		.i_amb_recheck_interval_frames(i_amb_recheck_interval_frames),
		.o_amb_code(o_amb_code),
		.o_dcs_r_code(o_dcs_r_code),
		.o_dcs_ir_code(o_dcs_ir_code),
		.o_amb_code_at_min(o_amb_code_at_min),
		.o_amb_code_at_max(o_amb_code_at_max),
		.o_dcs_r_code_at_min(o_dcs_r_code_at_min),
		.o_dcs_r_code_at_max(o_dcs_r_code_at_max),
		.o_dcs_ir_code_at_min(o_dcs_ir_code_at_min),
		.o_dcs_ir_code_at_max(o_dcs_ir_code_at_max),
		.o_amb_code_epoch(o_amb_code_epoch),
		.o_dcs_r_code_epoch(o_dcs_r_code_epoch),
		.o_dcs_ir_code_epoch(o_dcs_ir_code_epoch),
		.o_startup_search_complete(o_startup_search_complete),
		.o_amb_code_update(o_amb_code_update),
		.o_dcs_r_code_update(o_dcs_r_code_update),
		.o_dcs_ir_code_update(o_dcs_ir_code_update),
		.o_dcs_r_track_adjust(o_dcs_r_track_adjust),
		.o_dcs_ir_track_adjust(o_dcs_ir_track_adjust),
		.o_amb_search_done(o_amb_search_done),
		.o_amb_search_exhausted(o_amb_search_exhausted),
		.o_dcs_r_search_exhausted(o_dcs_r_search_exhausted),
		.o_dcs_ir_search_exhausted(o_dcs_ir_search_exhausted),
		.o_dcs_r_search_done(o_dcs_r_search_done),
		.o_dcs_ir_search_done(o_dcs_ir_search_done),
		.o_amb_pending_valid(o_amb_pending_valid),
		.o_dcs_r_pending_valid(o_dcs_r_pending_valid),
		.o_dcs_ir_pending_valid(o_dcs_ir_pending_valid),
		.o_amb_fault(),
		.o_dcs_r_fault(),
		.o_dcs_ir_fault(),
		.o_idac_fault_blocking(),
		.o_idac_protocol_error_sticky(),
		.o_idac_idle(o_idac_idle),
		.o_active_precision_mode(o_active_precision_mode),
		.o_fine_window_active(),
		.o_fine_window_start_event(o_fine_window_start_event),
		.o_fine_window_start_frame_id(o_fine_window_start_frame_id),
		.o_precision_15_to_9_event(o_precision_15_to_9_event),
		.o_precision_15_to_9_frame_id(o_precision_15_to_9_frame_id),
		.o_reacquire_request_event(),
		.o_mode_fault_event(),
		.o_normal_frame_count(),
		.o_amb_recheck_pending(),
		.o_amb_recheck_accept(o_amb_recheck_accept),
		.o_amb_recheck_busy(o_amb_recheck_busy),
		.o_normal_output_inhibit(o_normal_output_inhibit),
		.o_recheck_sequence_done(),
		.o_recheck_sequence_failed(),
		.o_fir_history_full_r(),
		.o_fir_history_full_ir(),
		.o_fir_idle(),
		.o_detection_fork_idle(),
		.o_detector_idle(),
		.o_controller_idle(),
		.o_scheduler_idle(),
		.o_cross_pending(),
		.o_peak_pending(),
		.o_valley_pending(),
		.o_return_pending(),
		.o_baseline_valid(),
		.o_reacquire_active(),
		.o_detector_fine_window_active(),
		.o_switch_pending(),
		.o_switch_target_precision(),
		.o_slope_current_q16(),
		.o_baseline_protocol_error_sticky(),
		.o_fine_window_timeout_sticky(),
		.o_reacquire_timeout_sticky(),
		.o_peak_valley_protocol_error_sticky(),
		.o_switch_timeout_sticky(),
		.o_precision_protocol_error_sticky(),
		.o_switch_hold_new_transaction(o_switch_hold_new_transaction),
		.o_integration_protocol_error_sticky(o_integration_protocol_error_sticky),
		.o_wrapper_fault_blocking(o_wrapper_fault_blocking),
		.o_normal_measurement_eligible(o_normal_measurement_eligible),
		.o_adc_chain_idle(o_adc_chain_idle),
		.o_normal_fork_idle(o_normal_fork_idle),
		.o_measurement_output_idle(o_measurement_output_idle),
		.o_datapath_empty(o_datapath_empty),
		.o_ami_fault_valid(),
		.o_ami_fault_active(),
		.o_ami_fault_cause(),
		.o_ami_fault_identity_valid(),
		.o_ami_fault_frame_id(),
		.o_ami_fault_sample_index(),
		.o_ami_fault_color_ir(),
		.o_ami_fault_frame_type(),
		.o_ami_fault_precision(),
		.o_ami_fault_run_generation(),
		.o_detection_discard_event(o_detection_discard_event),
		.o_detection_discard_reason(),
		.o_detection_discard_identity_valid(o_detection_discard_identity_valid),
		.o_detection_discard_sample_valid(),
		.o_detection_discard_frame_id(o_detection_discard_frame_id),
		.o_detection_discard_sample_index(o_detection_discard_sample_index),
		.o_detection_discard_color_ir(o_detection_discard_color_ir),
		.o_detection_discard_frame_type(),
		.o_detection_discard_precision(),
		.o_detection_discard_config_epoch(),
		.o_detection_discard_coef_epoch(),
		.o_detection_discard_dc_recovery_epoch(),
		.o_detection_discard_amb_code_epoch(),
		.o_detection_discard_dc_code_epoch(),
		.o_detection_discard_run_generation()
	);

	//===================<仿真辅助任务>===================//
	// 真实条件比较后才允许打印对应AMI通过信息。
	task check_case;
		input [8 * 6 - 1:0]case_id;
		input condition;
		begin
			if(condition === 1'b1)begin
				cnt_pass = cnt_pass + 1;
				$display("PASS %s", case_id);
			end else begin
				cnt_fail = cnt_fail + 1;
				$display("FAIL %s at %0t", case_id, $time);
			end
		end
	endtask

	// 单周期脉冲在下降沿建立，保证下一个上升沿被DUT唯一采样。
	task pulse_start_ack;
		begin
			@(negedge i_clk); i_start_ack_event = 1'b1;
			@(negedge i_clk); i_start_ack_event = 1'b0;
		end
	endtask

	// STOP边界清除上一RUN的IDAC、精度和结果在途状态。
	task pulse_stop_ack;
		begin
			@(negedge i_clk); i_stop_ack_event = 1'b1;
			@(negedge i_clk); i_stop_ack_event = 1'b0;
		end
	endtask

	// 兼容既有场景：NORMAL宏帧边界同时允许精度和IDAC各消费一次。
	task pulse_safe_boundary;
		begin
			@(negedge i_clk);
			i_macro_frame_safe_boundary = 1'b1;
			i_idac_code_safe_boundary = 1'b1;
			@(negedge i_clk);
			i_macro_frame_safe_boundary = 1'b0;
			i_idac_code_safe_boundary = 1'b0;
			i_safe_frame_id = i_safe_frame_id + 1'b1;
		end
	endtask

	// 宏帧边界只驱动精度提交、重检接管和对应safe frame ID。
	task pulse_macro_frame_safe_boundary;
		begin
			@(negedge i_clk); i_macro_frame_safe_boundary = 1'b1;
			@(negedge i_clk);
			i_macro_frame_safe_boundary = 1'b0;
			i_safe_frame_id = i_safe_frame_id + 1'b1;
		end
	endtask

	// 快速SAR9校准微时隙只允许IDAC pending码提交，不推进宏帧上下文。
	task pulse_idac_code_safe_boundary;
		begin
			@(negedge i_clk); i_idac_code_safe_boundary = 1'b1;
			@(negedge i_clk); i_idac_code_safe_boundary = 1'b0;
		end
	endtask

	// 向调度器提交一笔保持型事务并等待唯一start fire。
	task start_transaction;
		input [1:0]frame_type;
		input precision_mode;
		input color_ir;
		input [15:0]frame_id;
		input [15:0]sample_index;
		begin
			@(negedge i_clk);
			i_transaction_frame_type = frame_type;
			i_transaction_precision_mode = precision_mode;
			i_transaction_color_ir = color_ir;
			i_transaction_frame_id = frame_id;
			i_transaction_sample_index = sample_index;
			i_transaction_amb_code_snapshot = o_amb_code;
			i_transaction_amb_code_epoch = o_amb_code_epoch;
			i_transaction_dc_code_snapshot = color_ir ? o_dcs_ir_code : o_dcs_r_code;
			i_transaction_dc_code_epoch = color_ir ? o_dcs_ir_code_epoch : o_dcs_r_code_epoch;
			i_transaction_start_valid = 1'b1;
			#1;
			cnt_watchdog = 0;
			while((o_transaction_start_ready !== 1'b1) && (cnt_watchdog < 200))begin
				@(negedge i_clk);
				#1;
				cnt_watchdog = cnt_watchdog + 1;
			end
			if(o_transaction_start_ready === 1'b1)begin
				@(posedge i_clk);
				#1;
			end
			@(negedge i_clk); i_transaction_start_valid = 1'b0;
		end
	endtask

	// 物理DONE保持若干数字周期，使双触发同步和稳定总线采样均满足合同。
	task drive_adc_done;
		input precision_mode;
		input [9:0]s1_raw;
		input [9:0]s2_raw;
		begin
			@(negedge i_clk);
			i_adc_idle = 1'b0;
			i_dout_stage1_low = s1_raw;
			i_dout_stage2_low = s2_raw;
			i_clk_stage1_dout_low_async = 1'b1;
			i_clk_stage2_dout_low_async = precision_mode;
			repeat(5) @(negedge i_clk);
			i_clk_stage1_dout_low_async = 1'b0;
			i_clk_stage2_dout_low_async = 1'b0;
			i_adc_idle = 1'b1;
		end
	endtask

	// 将0至511范围的Stage1校准目标映射为真实10-bit物理RAW并完成一笔NORMAL事务。
	task send_normal_sample;
		input integer calibrated_code;
		input precision_mode;
		input color_ir;
		integer bounded_code;
		integer coarse_code;
		integer low_code;
		reg [9:0]stage1_raw;
		begin
			bounded_code = calibrated_code;
			if(bounded_code < 4)begin
				bounded_code = 4;
			end else if(bounded_code > 511)begin
				bounded_code = 511;
			end
			coarse_code = (bounded_code - 4) / 8;
			low_code = (bounded_code - 4) % 8;
			stage1_raw = {coarse_code[5:0], 1'b1, low_code[2:0]};
			start_transaction(FRAME_NORMAL, precision_mode, color_ir,
				next_frame_id[15:0], next_sample_index[15:0]);
			drive_adc_done(precision_mode, stage1_raw, 10'b0000001010);
			next_frame_id = next_frame_id + 1;
			next_sample_index = next_sample_index + 1;
			repeat(20) @(negedge i_clk);
		end
	endtask

	// 与send_normal_sample共用码转换算法，但不等待20拍完全settle，供背靠背构造卡住FIR单槽缓存窗口。
	task send_normal_sample_tight;
		input integer calibrated_code;
		input precision_mode;
		input color_ir;
		integer bounded_code;
		integer coarse_code;
		integer low_code;
		reg [9:0]stage1_raw;
		begin
			bounded_code = calibrated_code;
			if(bounded_code < 4)begin
				bounded_code = 4;
			end else if(bounded_code > 511)begin
				bounded_code = 511;
			end
			coarse_code = (bounded_code - 4) / 8;
			low_code = (bounded_code - 4) % 8;
			stage1_raw = {coarse_code[5:0], 1'b1, low_code[2:0]};
			start_transaction(FRAME_NORMAL, precision_mode, color_ir,
				next_frame_id[15:0], next_sample_index[15:0]);
			drive_adc_done(precision_mode, stage1_raw, 10'b0000001010);
			next_frame_id = next_frame_id + 1;
			next_sample_index = next_sample_index + 1;
		end
	endtask

	// 通过真实ADC事务预热FIR并形成9-bit动态基线向上相交请求。
	task build_9bit_cross_request;
		begin
			for(idx_sample = 0; (idx_sample < 24) && (dut.o_switch_pending !== 1'b1); idx_sample = idx_sample + 1)begin
				send_normal_sample(20, 1'b0, 1'b0);
			end
			for(idx_sample = 0; (idx_sample < 24) && (dut.o_switch_pending !== 1'b1); idx_sample = idx_sample + 1)begin
				send_normal_sample(20 + idx_sample * 20, 1'b0, 1'b0);
			end
			for(idx_sample = 0; (idx_sample < 30) && (dut.o_switch_pending !== 1'b1); idx_sample = idx_sample + 1)begin
				send_normal_sample(500 - idx_sample * 16, 1'b0, 1'b0);
			end
			for(idx_sample = 0; (idx_sample < 40) && (dut.o_switch_pending !== 1'b1); idx_sample = idx_sample + 1)begin
				send_normal_sample(20 + idx_sample * 12, 1'b0, 1'b0);
			end
		end
	endtask

	// 在15-bit窗口内用Stage1粗链形成波峰、下降段、波谷和返回9-bit请求。
	task build_fine_peak_valley_return;
		begin
			for(idx_sample = 0; idx_sample < 12; idx_sample = idx_sample + 1)begin
				send_normal_sample(60 + idx_sample * 32, 1'b1, 1'b0);
			end
			for(idx_sample = 0; idx_sample < 24; idx_sample = idx_sample + 1)begin
				send_normal_sample(440 - idx_sample * 16, 1'b1, 1'b0);
			end
			for(idx_sample = 0; (idx_sample < 24) && (dut.o_switch_pending !== 1'b1); idx_sample = idx_sample + 1)begin
				send_normal_sample(72 + idx_sample * 16, 1'b1, 1'b0);
			end
		end
	endtask

	// 推进一帧NORMAL完成事件以驱动周期重检间隔计数。
	task pulse_normal_frame_complete;
		begin
			@(negedge i_clk); i_normal_frame_complete_event = 1'b1;
			@(negedge i_clk); i_normal_frame_complete_event = 1'b0;
		end
	endtask

	// 声明当前AMB或DCS校准物理帧结束，使三阶段调度器前进。
	task pulse_calibration_frame_complete;
		begin
			@(negedge i_clk); i_calibration_frame_complete_event = 1'b1;
			@(negedge i_clk); i_calibration_frame_complete_event = 1'b0;
		end
	endtask

	// 服务周期重检产生的AMB、DC_R和DC_IR三笔真实SAR9校准事务。
	task complete_wrapper_recheck;
		integer recheck_guard;
		begin
			recheck_guard = 0;
			while((o_amb_recheck_busy === 1'b1) && (recheck_guard < 500))begin
				pulse_safe_boundary;
				if(o_calibration_sample_valid === 1'b1)begin
					service_calibration_request;
					pulse_calibration_frame_complete;
				end else begin
					repeat(2) @(negedge i_clk);
				end
				recheck_guard = recheck_guard + 1;
			end
		end
	endtask

	// 等待正式结果事务出现并在ready保持期间完成一次真实握手。
	task wait_measurement_result;
		begin
			cnt_watchdog = 0;
			while((o_measurement_result_valid !== 1'b1) && (cnt_watchdog < 500))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			@(negedge i_clk);
		end
	endtask

	// 服务wrapper发出的单笔AMB/DCS校准请求，数据仍通过真实ADC捕获和S1校准链返回。
	task service_calibration_request;
		integer calibration_guard;
		reg [1:0]request_frame_type;
		reg request_color_ir;
		begin
			calibration_guard = 0;
			while((o_calibration_sample_valid !== 1'b1) && (calibration_guard < 200))begin
				@(negedge i_clk);
				calibration_guard = calibration_guard + 1;
			end
			if(o_calibration_sample_valid === 1'b1)begin
				request_frame_type = o_calibration_frame_type;
				request_color_ir = o_calibration_color_ir;
				i_calibration_sample_ready = 1'b1;
				@(negedge i_clk);
				start_transaction(request_frame_type, 1'b0, request_color_ir,
					16'd200 + cnt_cal_request[15:0], 16'd300 + cnt_cal_request[15:0]);
				i_calibration_sample_ready = 1'b0;
				drive_adc_done(1'b0, 10'b0000010101, 10'd0);
				repeat(3) @(negedge i_clk);
			end
		end
	endtask

	// 自动模式启动搜索需要三笔真实校准事务；每个候选码仍必须经过安全边界。
	task complete_wrapper_startup;
		integer startup_guard;
		begin
			startup_guard = 0;
			while((o_startup_search_complete !== 1'b1) && (o_wrapper_fault_blocking !== 1'b1) && (startup_guard < 300))begin
				startup_guard = startup_guard + 1;
				pulse_safe_boundary;
				if(o_calibration_sample_valid === 1'b1)begin
					service_calibration_request;
				end else begin
					repeat(2) @(negedge i_clk);
				end
			end
		end
	endtask

	//===================<仿真激励区域>===================//
	// 固定半周期自由运行时钟，持续提供激励和观察所需边沿。
	always@(i_clk)begin
		i_clk <= #5 ~i_clk;
	end

	// 统计真实握手次数以验证唯一消费和无重复传输。
	always@(posedge i_clk)begin
		if(o_transaction_start_fire)begin
			cnt_fire = cnt_fire + 1;
		end
		if(o_adc_transaction_complete_event)begin
			cnt_adc_complete = cnt_adc_complete + 1;
			adc_complete_success_snapshot = o_adc_transaction_success;
			adc_complete_sample_index_snapshot = o_adc_complete_sample_index;
		end
		if(dut.flag_measurement_transfer)begin
			cnt_measurement_transfer = cnt_measurement_transfer + 1;
		end
		if(dut.flag_detection_transfer)begin
			cnt_detection_transfer = cnt_detection_transfer + 1;
		end
		if(dut.flag_normal_ppg_profile && dut.flag_measurement_branch_valid && dut.flag_measurement_branch_ready)begin
			cnt_normal_measurement_transfer = cnt_normal_measurement_transfer + 1;
		end
		if(dut.flag_normal_ppg_profile && dut.flag_track_branch_valid && dut.flag_track_branch_ready)begin
			cnt_normal_track_transfer = cnt_normal_track_transfer + 1;
		end
		if(o_dcs_r_track_adjust || o_dcs_ir_track_adjust)begin
			cnt_track_adjust = cnt_track_adjust + 1;
		end
		if(o_amb_code_update || o_dcs_r_code_update || o_dcs_ir_code_update)begin
			cnt_idac_code_update = cnt_idac_code_update + 1;
		end
		if(o_measurement_result_valid && i_measurement_result_ready)begin
			cnt_result = cnt_result + 1;
			flag_result_snapshot_valid = 1'b1;
			flag_result_snapshot_precision = o_result_precision_mode;
			flag_result_snapshot_coarse_valid = o_coarse_valid;
			flag_result_snapshot_fine_valid = o_fine_valid;
			flag_result_snapshot_programmable_valid = o_programmable_15_valid;
			result_snapshot_frame_type = o_result_frame_type;
			result_snapshot_color_ir = o_result_color_ir;
			result_snapshot_stage2_epoch = o_stage2_result_coef_epoch;
			result_snapshot_config_epoch = o_config_epoch;
			result_snapshot_stage1_epoch = o_coef_epoch;
			result_snapshot_dc_epoch = o_dc_result_coef_epoch;
			result_snapshot_frame_id = o_result_frame_id;
			result_snapshot_sample_index = o_result_sample_index;
			result_snapshot_amb_code = o_result_amb_code_snapshot;
			result_snapshot_dc_code = o_result_dc_code_snapshot;
			result_snapshot_amb_code_epoch = o_result_amb_code_epoch;
			result_snapshot_dc_code_epoch = o_result_dc_code_epoch;
		end
		if(o_calibration_request_fire)begin
			cnt_cal_request = cnt_cal_request + 1;
			if(o_calibration_request_reason == 2'b01)begin
				cnt_recheck_request = cnt_recheck_request + 1;
			end
		end
		if(o_amb_recheck_accept)begin
			cnt_recheck_accept = cnt_recheck_accept + 1;
		end
		if(o_fine_window_start_event)begin
			cnt_fine_start = cnt_fine_start + 1;
		end
		if(o_precision_15_to_9_event)begin
			cnt_return_9bit = cnt_return_9bit + 1;
		end
		if(dut.ppg_precision_window_integration_Inst.i_frame_safe_boundary)begin
			cnt_macro_boundary_route = cnt_macro_boundary_route + 1;
			last_macro_safe_frame_id = dut.ppg_precision_window_integration_Inst.i_safe_frame_id;
		end
		if(dut.ppg_idac_code_controller_Inst.i_frame_safe_boundary)begin
			cnt_idac_boundary_route = cnt_idac_boundary_route + 1;
		end
		if(o_detection_discard_event)begin
			cnt_detection_discard_event = cnt_detection_discard_event + 1;
		end
	end

	// 主回归依次驱动 AMI-01 至 AMI-32，并只依据真实 DUT 输出完成逐项比较。
	initial begin
		i_clk = 1'b0;
		i_rstn = 1'b0;
		i_active_config_valid = 1'b1;
		i_run_generation = 8'h01;
		i_system_fault_discard_event = 1'b0;
		i_run_enable = 1'b0;
		i_allow_new_transaction = 1'b1;
		i_start_ack_event = 1'b0;
		i_stop_ack_event = 1'b0;
		i_control_abort_event = 1'b0;
		i_diag_clear_event = 1'b0;
		i_config_epoch = 8'h11;
		i_stage1_coef_epoch = 8'h21;
		i_stage2_coef_epoch = 8'h31;
		i_dc_recovery_coef_epoch = 8'h41;
		i_transaction_start_valid = 1'b0;
		i_transaction_precision_mode = 1'b0;
		i_transaction_frame_id = 16'd0;
		i_transaction_sample_index = 16'd0;
		i_transaction_color_ir = 1'b0;
		i_transaction_frame_type = FRAME_NORMAL;
		i_transaction_amb_code_snapshot = 8'd0;
		i_transaction_dc_code_snapshot = 8'd0;
		i_transaction_amb_code_epoch = 4'd0;
		i_transaction_dc_code_epoch = 4'd0;
		i_dout_stage1_low = 10'd0;
		i_clk_stage1_dout_low_async = 1'b0;
		i_dout_stage2_low = 10'd0;
		i_clk_stage2_dout_low_async = 1'b0;
		i_adc_idle = 1'b1;
		i_analog_safe = 1'b1;
		i_macro_frame_safe_boundary = 1'b0;
		i_idac_code_safe_boundary = 1'b0;
		i_safe_frame_id = 16'd1;
		i_normal_frame_complete_event = 1'b0;
		i_calibration_frame_complete_event = 1'b0;
		i_calibration_sample_ready = 1'b0;
		i_measurement_result_ready = 1'b1;
		i_idac_mode = 2'b10;
		i_amb_enable = 1'b1;
		i_dcs_enable = 1'b1;
		i_amb_polarity = 1'b1;
		i_dcs_polarity = 1'b1;
		i_amb_manual_code = 8'd64;
		i_amb_code_min = 8'd0;
		i_amb_code_max = 8'd255;
		i_dcs_r_manual_code = 8'd80;
		i_dcs_r_code_min = 8'd0;
		i_dcs_r_code_max = 8'd255;
		i_dcs_ir_manual_code = 8'd96;
		i_dcs_ir_code_min = 8'd0;
		i_dcs_ir_code_max = 8'd255;
		i_amb_threshold_low = -12'sd2048;
		i_amb_threshold_high = 12'sd2047;
		i_dcs_threshold_low = -12'sd2048;
		i_dcs_threshold_high = 12'sd2047;
		i_amb_confirm_count = 8'd1;
		i_dcs_confirm_count = 8'd1;
		i_stage1_calibration_valid = 1'b1;
		i_stage1_weight_q16_0 = 26'sd65536;
		i_stage1_weight_q16_1 = 26'sd131072;
		i_stage1_weight_q16_2 = 26'sd262144;
		i_stage1_weight_q16_3 = 26'sd524288;
		i_stage1_weight_q16_4 = 26'sd524288;
		i_stage1_weight_q16_5 = 26'sd1048576;
		i_stage1_weight_q16_6 = 26'sd2097152;
		i_stage1_weight_q16_7 = 26'sd4194304;
		i_stage1_weight_q16_8 = 26'sd8388608;
		i_stage1_weight_q16_9 = 26'sd16777216;
		i_stage1_offset_q16 = 32'sd0;
		i_stage2_calibration_valid = 1'b1;
		i_stage2_gain_q16 = 20'sd65536;
		i_stage2_offset_q16 = 32'sd0;
		i_dc9_recovery_valid = 1'b1;
		i_dc15_recovery_valid = 1'b1;
		i_dc9_recovery_gain_q16 = 32'sd0;
		i_dc15_recovery_gain_q16 = 32'sd0;
		i_run_profile = 1'b0;
		i_initial_precision = 1'b0;
		i_slope_mode = 1'b0;
		i_fixed_slope_q16 = -32'sd65536;
		i_alpha_q15 = 16'd6554;
		i_beta_q15 = 16'd8192;
		i_timing_adjust_ratio_q15 = 16'd1024;
		i_slope_min_q16 = -32'sd16777216;
		i_slope_max_q16 = -32'sd1;
		i_baseline_delta_q16 = 32'sd0;
		i_cross_hysteresis_q16 = 32'd0;
		i_lead_min_frames = 16'd17;
		i_lead_max_frames = 16'd19;
		i_cross_confirm_count = 4'd3;
		i_no_cross_limit = 4'd4;
		i_peak_confirm_count = 4'd3;
		i_valley_confirm_count = 4'd3;
		i_direction_deadband = 24'd0;
		i_min_peak_valley_amplitude = 24'd1;
		i_min_peak_to_valley_frames = 16'd1;
		i_min_peak_to_peak_frames = 16'd1;
		i_max_fine_window_frames = 16'd800;
		i_max_reacquire_frames = 16'd800;
		i_peak_valley_config_valid = 1'b1;
		i_amb_recheck_interval_frames = 16'hffff;
		cnt_pass = 0;
		cnt_fail = 0;
		cnt_fire = 0;
		cnt_adc_complete = 0;
		cnt_result = 0;
		cnt_cal_request = 0;
		cnt_watchdog = 0;
		cnt_recheck_request = 0;
		cnt_recheck_accept = 0;
		cnt_fine_start = 0;
		cnt_return_9bit = 0;
		cnt_macro_boundary_route = 0;
		cnt_idac_boundary_route = 0;
		cnt_idac_code_update = 0;
		cnt_detection_discard_event = 0;
		cnt_adc_complete_before = 0;
		adc_complete_success_snapshot = 1'b0;
		adc_complete_sample_index_snapshot = 16'd0;
		flag_result_snapshot_valid = 1'b0;
		flag_result_snapshot_precision = 1'b0;
		flag_result_snapshot_coarse_valid = 1'b0;
		flag_result_snapshot_fine_valid = 1'b0;
		flag_result_snapshot_programmable_valid = 1'b0;
		result_snapshot_frame_type = 2'b00;
		result_snapshot_color_ir = 1'b0;
		result_snapshot_stage2_epoch = 8'd0;
		result_snapshot_config_epoch = 8'd0;
		result_snapshot_stage1_epoch = 8'd0;
		result_snapshot_dc_epoch = 8'd0;
		result_snapshot_frame_id = 16'd0;
		result_snapshot_sample_index = 16'd0;
		result_snapshot_amb_code = 8'd0;
		result_snapshot_dc_code = 8'd0;
		result_snapshot_amb_code_epoch = 4'd0;
		result_snapshot_dc_code_epoch = 4'd0;
		flag_startup_incomplete_before_boundary = 1'b0;
		flag_stop_blocked_owner = 1'b0;
		cnt_fire_before = 0;
		cnt_normal_measurement_transfer = 0;
		cnt_normal_track_transfer = 0;
		cnt_detection_transfer = 0;
		cnt_measurement_transfer = 0;
		cnt_track_adjust = 0;
		last_macro_safe_frame_id = 16'd0;
		cnt_macro_before_boundary = 0;
		cnt_idac_before_boundary = 0;
		cnt_idac_update_before_boundary = 0;
		cnt_fine_before_boundary = 0;
		cnt_return_before_boundary = 0;
		cnt_recheck_before_boundary = 0;
		cnt_characterization_track_before = 0;
		cnt_characterization_adjust_before = 0;
		cnt_characterization_cal_before = 0;
		next_frame_id = 16'd1000;
		next_sample_index = 16'd1000;
		flag_characterization_search_blocked = 1'b0;

		repeat(4) @(negedge i_clk);
		check_case("AMI-01", !o_measurement_result_valid && !o_calibration_sample_valid && !o_transaction_start_fire);
		i_rstn = 1'b1;
		i_run_enable = 1'b1;
		i_idac_mode = 2'b00;
		pulse_start_ack();
		cnt_fire_before = cnt_fire;
		cnt_macro_before_boundary = cnt_macro_boundary_route;
		cnt_idac_before_boundary = cnt_idac_boundary_route;
		flag_startup_incomplete_before_boundary = !o_startup_search_complete && !o_normal_measurement_eligible;
		pulse_idac_code_safe_boundary;
		repeat(2) @(negedge i_clk);
		check_case("AMI-35", flag_startup_incomplete_before_boundary && o_startup_search_complete &&
			(cnt_idac_boundary_route == (cnt_idac_before_boundary + 1)));
		check_case("AMI-36", (cnt_fire == cnt_fire_before) && (cnt_macro_boundary_route == cnt_macro_before_boundary) &&
			!o_adc_transaction_complete_event);
		i_idac_mode = 2'b10;
		pulse_start_ack();
		complete_wrapper_startup;
		check_case("AMI-14", o_startup_search_complete && (o_amb_code >= i_amb_code_min) && (o_amb_code <= i_amb_code_max));
		check_case("AMI-15", (o_dcs_r_code >= i_dcs_r_code_min) && (o_dcs_r_code <= i_dcs_r_code_max) &&
			(o_dcs_ir_code >= i_dcs_ir_code_min) && (o_dcs_ir_code <= i_dcs_ir_code_max));
		@(negedge i_clk);

		// AMI-02至AMI-06、AMI-09至AMI-11和AMI-23通过同一真实9-bit事务核对。
		cnt_fire_before = cnt_fire;
		cnt_adc_complete_before = cnt_adc_complete;
		start_transaction(FRAME_NORMAL, 1'b0, 1'b0, 16'd10, 16'd100);
		check_case("AMI-02", cnt_fire == (cnt_fire_before + 1));
		repeat(8) @(negedge i_clk);
		check_case("AMI-37", (cnt_adc_complete == cnt_adc_complete_before) && !o_transaction_start_ready &&
			!o_adc_transaction_complete_event && i_adc_idle);
		drive_adc_done(1'b0, 10'b0000010101, 10'd0);
		wait_measurement_result();
		check_case("AMI-30", (cnt_adc_complete == (cnt_adc_complete_before + 1)) &&
			adc_complete_success_snapshot && (adc_complete_sample_index_snapshot == 16'd100));
		check_case("AMI-04", flag_result_snapshot_valid && flag_result_snapshot_coarse_valid && !flag_result_snapshot_fine_valid);
		check_case("AMI-06", flag_result_snapshot_valid && (result_snapshot_frame_type == FRAME_NORMAL));
		check_case("AMI-09", flag_result_snapshot_valid && !flag_result_snapshot_programmable_valid);
		check_case("AMI-10", flag_result_snapshot_valid && (flag_result_snapshot_precision == 1'b0));
		check_case("AMI-23", flag_result_snapshot_valid && (result_snapshot_config_epoch == 8'h11) &&
			(result_snapshot_stage1_epoch == 8'h21) && (result_snapshot_dc_epoch == 8'h41) &&
			(result_snapshot_sample_index == 16'd100));
		repeat(3) @(negedge i_clk);
		check_case("AMI-31", (cnt_adc_complete == (cnt_adc_complete_before + 1)) &&
			(o_adc_transaction_complete_event == 1'b0));

		// AMI-03验证资格缺失时ready为低，恢复后只产生一个fire。
		i_allow_new_transaction = 1'b0;
		@(negedge i_clk); i_transaction_start_valid = 1'b1;
		check_case("AMI-03", !o_transaction_start_ready && !o_transaction_start_fire);
		@(negedge i_clk); i_transaction_start_valid = 1'b0;
		i_allow_new_transaction = 1'b1;

		// 波形侧宏帧边界不会占用AMI结果owner，也不会自行产生ADC结果事务。
		cnt_fire_before = cnt_fire;
		cnt_adc_complete_before = cnt_adc_complete;
		pulse_macro_frame_safe_boundary;
		check_case("AMI-33", (cnt_fire == cnt_fire_before) && (cnt_adc_complete == cnt_adc_complete_before) &&
			!o_adc_transaction_complete_event);

		// start fire后故意改写未握手输入，真实DONE必须仍返回owner快照而非实时总线。
		cnt_adc_complete_before = cnt_adc_complete;
		start_transaction(FRAME_NORMAL, 1'b0, 1'b0, 16'd30, 16'd300);
		@(negedge i_clk);
		i_transaction_precision_mode = 1'b1;
		i_transaction_frame_id = 16'hbeef;
		i_transaction_sample_index = 16'hdead;
		i_transaction_color_ir = 1'b1;
		i_transaction_frame_type = FRAME_DCS;
		i_transaction_amb_code_snapshot = 8'ha3;
		i_transaction_dc_code_snapshot = 8'hc7;
		i_transaction_amb_code_epoch = 4'he;
		i_transaction_dc_code_epoch = 4'hd;
		drive_adc_done(1'b0, 10'b0000010110, 10'd0);
		wait_measurement_result();
		check_case("AMI-34", (cnt_adc_complete == (cnt_adc_complete_before + 1)) &&
			adc_complete_success_snapshot && (adc_complete_sample_index_snapshot == 16'd300));
		check_case("AMI-38", flag_result_snapshot_valid && !flag_result_snapshot_precision &&
			(result_snapshot_frame_id == 16'd30) && (result_snapshot_sample_index == 16'd300) &&
			(result_snapshot_frame_type == FRAME_NORMAL) && !result_snapshot_color_ir &&
			(result_snapshot_amb_code == o_amb_code) && (result_snapshot_dc_code == o_dcs_r_code) &&
			(result_snapshot_amb_code_epoch == o_amb_code_epoch) && (result_snapshot_dc_code_epoch == o_dcs_r_code_epoch));

		// 15-bit事务等待第二级DONE并输出同一原子粗精细载荷。
		i_run_profile = 1'b1;
		i_initial_precision = 1'b1;
		pulse_start_ack();
		complete_wrapper_startup;
		pulse_safe_boundary();
		repeat(3) @(negedge i_clk);
		start_transaction(FRAME_NORMAL, 1'b1, 1'b1, 16'd11, 16'd101);
		drive_adc_done(1'b1, 10'b0000011111, 10'b0000001010);
		wait_measurement_result();
		check_case("AMI-05", flag_result_snapshot_valid && flag_result_snapshot_precision && (result_snapshot_color_ir == 1'b1));
		check_case("AMI-11", flag_result_snapshot_valid && flag_result_snapshot_coarse_valid && flag_result_snapshot_fine_valid &&
			flag_result_snapshot_programmable_valid && (result_snapshot_stage2_epoch == 8'h31));
		i_run_profile = 1'b0;
		i_initial_precision = 1'b0;
		pulse_start_ack();
		complete_wrapper_startup;
		pulse_safe_boundary();
		repeat(3) @(negedge i_clk);

		// 正式消费者反压期间载荷必须逐位保持，释放后只能消费一次。
		i_measurement_result_ready = 1'b0;
		start_transaction(FRAME_NORMAL, 1'b0, 1'b0, 16'd12, 16'd102);
		drive_adc_done(1'b0, 10'b0000100001, 10'd0);
		wait_measurement_result();
		check_case("AMI-12", o_measurement_result_valid && (o_result_sample_index == 16'd102));
		repeat(5) @(negedge i_clk);
		check_case("AMI-13", o_measurement_result_valid && (o_result_sample_index == 16'd102));
		i_measurement_result_ready = 1'b1;
		repeat(3) @(negedge i_clk);

		// 非法frame_type绝不产生正式结果并锁存集成协议诊断。
		@(negedge i_clk);
		i_transaction_frame_type = 2'b11;
		i_transaction_start_valid = 1'b1;
		repeat(2) @(negedge i_clk);
		i_transaction_start_valid = 1'b0;
		check_case("AMI-07", o_integration_protocol_error_sticky && !o_transaction_start_fire);
		i_diag_clear_event = 1'b1;
		@(negedge i_clk); i_diag_clear_event = 1'b0;

		// NORMAL fork的两个真实消费者对已完成事务必须各消费且仅消费一次。
		check_case("AMI-08", (cnt_normal_measurement_transfer == cnt_normal_track_transfer) &&
			(cnt_normal_measurement_transfer > 0));

		// 收紧DCS窗口后送入真实未恢复Stage1残差，观察慢速跟踪调码且正式结果仍可交付。
		i_dcs_threshold_low = 12'sd100;
		i_dcs_threshold_high = 12'sd200;
		i_dcs_confirm_count = 8'd1;
		cnt_fire_before = cnt_result;
		send_normal_sample(300, 1'b0, 1'b0);
		pulse_safe_boundary;
		repeat(5) @(negedge i_clk);
		check_case("AMI-16", (cnt_track_adjust > 0) && (cnt_result > cnt_fire_before));
		i_dcs_threshold_low = -12'sd2048;
		i_dcs_threshold_high = 12'sd2047;

		// 通过真实ADC、FIR、动态基线和峰谷链完成普通9到15再到9切换。
		i_cross_confirm_count = 4'd2;
		i_peak_confirm_count = 4'd1;
		i_valley_confirm_count = 4'd1;
		i_amb_recheck_interval_frames = 16'd1;
		i_dcs_threshold_low = 12'sd100;
		i_dcs_threshold_high = 12'sd200;
		send_normal_sample(300, 1'b0, 1'b0);
		cnt_watchdog = 0;
		while((o_dcs_r_pending_valid !== 1'b1) && (cnt_watchdog < 100))begin
			@(negedge i_clk);
			cnt_watchdog = cnt_watchdog + 1;
		end
		dcs_r_epoch_before_recheck = o_dcs_r_code_epoch;
		build_9bit_cross_request;
		pulse_macro_frame_safe_boundary;
		repeat(3) @(negedge i_clk);
		check_case("AMI-42", o_active_precision_mode && o_dcs_r_pending_valid &&
			(o_dcs_r_code_epoch == dcs_r_epoch_before_recheck));
		pulse_idac_code_safe_boundary;
		i_dcs_threshold_low = -12'sd2048;
		i_dcs_threshold_high = 12'sd2047;
		cnt_fire_before = cnt_fine_start;
		pulse_normal_frame_complete;
		build_fine_peak_valley_return;
		check_case("AMI-19", o_active_precision_mode && (cnt_fine_start > 0) &&
			(dut.o_fir_history_full_r === 1'b1));

		// 返回9-bit提交后先不给安全边界，周期重检不得提前接管。
		repeat(3) @(negedge i_clk);
		check_case("AMI-20", (o_amb_recheck_accept == 1'b0) &&
			((dut.o_switch_pending == 1'b1) || (o_active_precision_mode == 1'b1)));
		pulse_safe_boundary;
		repeat(5) @(negedge i_clk);
		cnt_watchdog = 0;
		while((o_amb_recheck_busy !== 1'b1) && (cnt_watchdog < 200))begin
			pulse_safe_boundary;
			cnt_watchdog = cnt_watchdog + 1;
		end
		amb_epoch_before_recheck = o_amb_code_epoch;
		dcs_r_epoch_before_recheck = o_dcs_r_code_epoch;
		dcs_ir_epoch_before_recheck = o_dcs_ir_code_epoch;
		cnt_fire_before = cnt_recheck_request;
		complete_wrapper_recheck;
		check_case("AMI-17", (cnt_recheck_request == (cnt_fire_before + 3)) &&
			(cnt_recheck_accept > 0) && (o_amb_recheck_busy == 1'b0));
		check_case("AMI-18", (o_amb_code_epoch == amb_epoch_before_recheck) &&
			(o_dcs_r_code_epoch == dcs_r_epoch_before_recheck) &&
			(o_dcs_ir_code_epoch == dcs_ir_epoch_before_recheck));

		// 构造一笔红光DC tracking pending，用独立边界验证宏帧不会误提交IDAC码。
		i_dcs_threshold_low = 12'sd100;
		i_dcs_threshold_high = 12'sd200;
		send_normal_sample(300, 1'b0, 1'b0);
		cnt_watchdog = 0;
		while((o_dcs_r_pending_valid !== 1'b1) && (cnt_watchdog < 100))begin
			@(negedge i_clk);
			cnt_watchdog = cnt_watchdog + 1;
		end
		cnt_macro_before_boundary = cnt_macro_boundary_route;
		cnt_idac_before_boundary = cnt_idac_boundary_route;
		cnt_idac_update_before_boundary = cnt_idac_code_update;
		dcs_r_epoch_before_recheck = o_dcs_r_code_epoch;
		i_safe_frame_id = 16'ha501;
		pulse_macro_frame_safe_boundary;
		repeat(2) @(negedge i_clk);
		check_case("AMI-27", (cnt_macro_boundary_route == (cnt_macro_before_boundary + 1)) &&
			(cnt_idac_boundary_route == cnt_idac_before_boundary) &&
			(cnt_idac_code_update == cnt_idac_update_before_boundary) &&
			(o_dcs_r_code_epoch == dcs_r_epoch_before_recheck) &&
			(last_macro_safe_frame_id == 16'ha501));

		// 快速校准IDAC边界提交pending，但不得进入precision、recheck或safe-frame上下文。
		cnt_macro_before_boundary = cnt_macro_boundary_route;
		cnt_idac_before_boundary = cnt_idac_boundary_route;
		cnt_idac_update_before_boundary = cnt_idac_code_update;
		cnt_fine_before_boundary = cnt_fine_start;
		cnt_return_before_boundary = cnt_return_9bit;
		cnt_recheck_before_boundary = cnt_recheck_accept;
		i_safe_frame_id = 16'ha5f0;
		pulse_idac_code_safe_boundary;
		repeat(2) @(negedge i_clk);
		check_case("AMI-26", (cnt_idac_boundary_route == (cnt_idac_before_boundary + 1)) &&
			(cnt_macro_boundary_route == cnt_macro_before_boundary) &&
			(cnt_idac_code_update == (cnt_idac_update_before_boundary + 1)) &&
			(cnt_fine_start == cnt_fine_before_boundary) &&
			(cnt_return_9bit == cnt_return_before_boundary) &&
			(cnt_recheck_accept == cnt_recheck_before_boundary));
		check_case("AMI-28", (last_macro_safe_frame_id == 16'ha501) &&
			(o_fine_window_start_frame_id != 16'ha5f0) &&
			(o_precision_15_to_9_frame_id != 16'ha5f0));

		// NORMAL同拍边界必须分别到达两个消费者，且一笔pending最多产生一次真实更新。
		send_normal_sample(300, 1'b0, 1'b0);
		cnt_watchdog = 0;
		while((o_dcs_r_pending_valid !== 1'b1) && (cnt_watchdog < 100))begin
			@(negedge i_clk);
			cnt_watchdog = cnt_watchdog + 1;
		end
		cnt_macro_before_boundary = cnt_macro_boundary_route;
		cnt_idac_before_boundary = cnt_idac_boundary_route;
		cnt_idac_update_before_boundary = cnt_idac_code_update;
		i_safe_frame_id = 16'ha502;
		pulse_safe_boundary;
		repeat(2) @(negedge i_clk);
		check_case("AMI-25", (cnt_macro_boundary_route == (cnt_macro_before_boundary + 1)) &&
			(cnt_idac_boundary_route == (cnt_idac_before_boundary + 1)) &&
			(cnt_idac_code_update == (cnt_idac_update_before_boundary + 1)) &&
			(last_macro_safe_frame_id == 16'ha502));
		i_dcs_threshold_low = -12'sd2048;
		i_dcs_threshold_high = 12'sd2047;

		// STOP禁止新事务但保持既有结果真实排空。
		@(negedge i_clk); i_stop_ack_event = 1'b1;
		@(negedge i_clk); i_stop_ack_event = 1'b0;
		check_case("AMI-21", !o_transaction_start_ready);

		// STOP期间两路外部脉冲仍保持独立直连，但不得形成任何控制提交或补偿事件。
		cnt_macro_before_boundary = cnt_macro_boundary_route;
		cnt_idac_before_boundary = cnt_idac_boundary_route;
		cnt_idac_update_before_boundary = cnt_idac_code_update;
		cnt_fine_before_boundary = cnt_fine_start;
		cnt_return_before_boundary = cnt_return_9bit;
		cnt_recheck_before_boundary = cnt_recheck_accept;
		pulse_idac_code_safe_boundary;
		pulse_macro_frame_safe_boundary;
		repeat(2) @(negedge i_clk);
		check_case("AMI-29", (cnt_macro_boundary_route == (cnt_macro_before_boundary + 1)) &&
			(cnt_idac_boundary_route == (cnt_idac_before_boundary + 1)) &&
			(cnt_idac_code_update == cnt_idac_update_before_boundary) &&
			(cnt_fine_start == cnt_fine_before_boundary) &&
			(cnt_return_9bit == cnt_return_before_boundary) &&
			(cnt_recheck_accept == cnt_recheck_before_boundary) && !o_transaction_start_ready);

		// 新RUN后启动事务并在结果在途时abort，禁止迟到正式valid且最终回到empty。
		i_run_enable = 1'b1;
		pulse_start_ack();
		complete_wrapper_startup;
		pulse_safe_boundary();
		cnt_fire_before = cnt_fire;
		cnt_adc_complete_before = cnt_adc_complete;
		start_transaction(FRAME_NORMAL, 1'b0, 1'b0, 16'd20, 16'd200);
		@(negedge i_clk); i_control_abort_event = 1'b1;
		@(negedge i_clk); i_control_abort_event = 1'b0;
		drive_adc_done(1'b0, 10'b0000010001, 10'd0);
		repeat(30) @(negedge i_clk);
		check_case("AMI-22", !o_measurement_result_valid && o_measurement_output_idle);
		check_case("AMI-32", (cnt_fire == (cnt_fire_before + 1)) && (cnt_adc_complete == (cnt_adc_complete_before + 1)) &&
			!adc_complete_success_snapshot && (adc_complete_sample_index_snapshot == 16'd200) &&
			(o_measurement_result_valid == 1'b0));
		check_case("AMI-39", !adc_complete_success_snapshot && (adc_complete_sample_index_snapshot == 16'd200) &&
			!o_measurement_result_valid && o_adc_chain_idle);

		// STOP在物理DONE前发生时禁止新owner，但当前owner仍必须等真实DONE后受控排空；
		// 按合同13节冻结的迟到DONE规则第1条，STOP接受时所有尚未完成owner立即标记为
		// 丢弃，真实DONE只能产生一次原身份success=0释放，绝不进入正式结果或检测链——
		// 本用例此前误期望success=1，是ppg_control_top整机定向仿真发现STOP-owner-
		// inflight死锁后，V1.11修复flag_stop_result_draining的同时一并订正的过时断言
		i_allow_new_transaction = 1'b1;
		pulse_start_ack();
		complete_wrapper_startup;
		pulse_safe_boundary();
		cnt_fire_before = cnt_fire;
		cnt_adc_complete_before = cnt_adc_complete;
		start_transaction(FRAME_NORMAL, 1'b0, 1'b0, 16'd40, 16'd400);
		i_allow_new_transaction = 1'b0;
		@(negedge i_clk); i_stop_ack_event = 1'b1;
		@(negedge i_clk); i_stop_ack_event = 1'b0;
		flag_stop_blocked_owner = !o_transaction_start_ready && (cnt_fire == (cnt_fire_before + 1));
		drive_adc_done(1'b0, 10'b0000010010, 10'd0);
		repeat(30) @(negedge i_clk);
		check_case("AMI-40", flag_stop_blocked_owner && (cnt_adc_complete == (cnt_adc_complete_before + 1)) &&
			!adc_complete_success_snapshot && (adc_complete_sample_index_snapshot == 16'd400) &&
			!o_measurement_result_valid && o_measurement_output_idle);

		// 复位期间保持旧DONE电平，释放复位后该旧DONE不得绑定或释放新事务。
		cnt_fire_before = cnt_fire;
		cnt_adc_complete_before = cnt_adc_complete;
		@(negedge i_clk);
		i_rstn = 1'b0;
		i_adc_idle = 1'b0;
		i_dout_stage1_low = 10'b1111111111;
		i_clk_stage1_dout_low_async = 1'b1;
		repeat(5) @(negedge i_clk);
		i_rstn = 1'b1;
		repeat(5) @(negedge i_clk);
		i_clk_stage1_dout_low_async = 1'b0;
		i_adc_idle = 1'b1;
		repeat(5) @(negedge i_clk);
		check_case("AMI-41", (cnt_fire == cnt_fire_before) && (cnt_adc_complete == cnt_adc_complete_before) &&
			!o_adc_transaction_complete_event && o_adc_chain_idle);

		// CHARACTERIZATION自动模式即使意外到达AMI，也不得建立启动搜索、tracking或校准请求。
		i_run_enable = 1'b0;
		pulse_stop_ack;
		repeat(3) @(negedge i_clk);
		i_run_profile = 1'b1;
		i_initial_precision = 1'b1;
		i_idac_mode = 2'b10;
		i_run_enable = 1'b1;
		i_allow_new_transaction = 1'b1;
		cnt_characterization_cal_before = cnt_cal_request;
		cnt_characterization_adjust_before = cnt_track_adjust;
		cnt_idac_before_boundary = cnt_idac_code_update;
		pulse_start_ack;
		repeat(3) @(negedge i_clk);
		pulse_idac_code_safe_boundary;
		repeat(3) @(negedge i_clk);
		flag_characterization_search_blocked =
			!o_calibration_sample_valid && !o_startup_search_complete &&
			!o_amb_pending_valid && !o_dcs_r_pending_valid && !o_dcs_ir_pending_valid &&
			(dut.flag_track_branch_valid === 1'b0) &&
			(cnt_cal_request == cnt_characterization_cal_before) &&
			(cnt_track_adjust == cnt_characterization_adjust_before) &&
			(cnt_idac_code_update == cnt_idac_before_boundary);

		// 合法CHARACTERIZATION MANUAL启动只沿IDAC安全边界提交一次三路码。
		i_run_enable = 1'b0;
		pulse_stop_ack;
		repeat(3) @(negedge i_clk);
		i_amb_manual_code = o_amb_code ^ 8'hff;
		i_dcs_r_manual_code = o_dcs_r_code ^ 8'hff;
		i_dcs_ir_manual_code = o_dcs_ir_code ^ 8'hff;
		amb_epoch_before_recheck = o_amb_code_epoch;
		dcs_r_epoch_before_recheck = o_dcs_r_code_epoch;
		dcs_ir_epoch_before_recheck = o_dcs_ir_code_epoch;
		cnt_idac_before_boundary = cnt_idac_code_update;
		i_idac_mode = 2'b00;
		i_run_enable = 1'b1;
		pulse_start_ack;
		pulse_idac_code_safe_boundary;
		repeat(3) @(negedge i_clk);
		check_case("AMI-44", o_startup_search_complete &&
			(o_amb_code == i_amb_manual_code) && (o_dcs_r_code == i_dcs_r_manual_code) &&
			(o_dcs_ir_code == i_dcs_ir_manual_code) &&
			(o_amb_code_epoch == (amb_epoch_before_recheck + 1'b1)) &&
			(o_dcs_r_code_epoch == (dcs_r_epoch_before_recheck + 1'b1)) &&
			(o_dcs_ir_code_epoch == (dcs_ir_epoch_before_recheck + 1'b1)) &&
			(cnt_idac_code_update == (cnt_idac_before_boundary + 1)) &&
			!o_calibration_sample_valid && !o_amb_pending_valid &&
			!o_dcs_r_pending_valid && !o_dcs_ir_pending_valid);

		// 固定SAR15表征结果仍经过测量数据链，但不得反向开启自动控制分支。
		cnt_characterization_track_before = cnt_normal_track_transfer;
		cnt_characterization_adjust_before = cnt_track_adjust;
		cnt_characterization_cal_before = cnt_cal_request;
		cnt_idac_before_boundary = cnt_idac_code_update;
		cnt_fine_before_boundary = cnt_fine_start;
		cnt_return_before_boundary = cnt_return_9bit;
		cnt_fire_before = cnt_fire;
		flag_result_snapshot_valid = 1'b0;
		send_normal_sample(180, 1'b1, 1'b0);
		wait_measurement_result;
		repeat(3) @(negedge i_clk);
		check_case("AMI-43", flag_characterization_search_blocked &&
			(cnt_normal_track_transfer == cnt_characterization_track_before) &&
			(cnt_track_adjust == cnt_characterization_adjust_before) &&
			(cnt_cal_request == cnt_characterization_cal_before) &&
			!o_calibration_sample_valid && !o_amb_pending_valid &&
			!o_dcs_r_pending_valid && !o_dcs_ir_pending_valid &&
			(dut.flag_track_branch_valid === 1'b0));
		check_case("AMI-45", flag_result_snapshot_valid &&
			flag_result_snapshot_coarse_valid && flag_result_snapshot_fine_valid &&
			flag_result_snapshot_programmable_valid &&
			(flag_result_snapshot_precision == 1'b1) &&
			(o_active_precision_mode == 1'b1) &&
			(cnt_fine_start == cnt_fine_before_boundary) &&
			(cnt_return_9bit == cnt_return_before_boundary) &&
			(cnt_idac_code_update == cnt_idac_before_boundary) &&
			(o_amb_code == i_amb_manual_code) && (o_dcs_r_code == i_dcs_r_manual_code) &&
			(o_dcs_ir_code == i_dcs_ir_manual_code));

		check_case("AMI-24", !o_wrapper_fault_blocking || !o_transaction_start_ready);

		// 合同6.10节公开discard端口：新RUN内建立一笔正式结果并保持反压，随后abort必须产生一次公开正式结果丢弃且绑定原TXN_ID。
		i_run_enable = 1'b0;
		pulse_stop_ack;
		repeat(3) @(negedge i_clk);
		i_run_profile = 1'b0;
		i_initial_precision = 1'b0;
		i_idac_mode = 2'b10;
		i_allow_new_transaction = 1'b1;
		i_run_enable = 1'b1;
		pulse_start_ack();
		complete_wrapper_startup;
		pulse_safe_boundary();
		repeat(3) @(negedge i_clk);
		i_measurement_result_ready = 1'b0;
		start_transaction(FRAME_NORMAL, 1'b0, 1'b0, 16'd90, 16'd900);
		drive_adc_done(1'b0, 10'b0000100101, 10'd0);
		wait_measurement_result();
		@(negedge i_clk); i_control_abort_event = 1'b1;
		@(negedge i_clk); i_control_abort_event = 1'b0;
		check_case("AMI-46", o_measurement_result_discard_event &&
			(o_measurement_result_discard_reason == 2'b01) &&
			o_measurement_result_discard_identity_valid &&
			(o_measurement_result_discard_frame_id == 16'd90) &&
			(o_measurement_result_discard_sample_index == 16'd900) &&
			!o_measurement_result_valid);
		i_measurement_result_ready = 1'b1;
		repeat(3) @(negedge i_clk);

		// 合同6.10节公开discard端口：构造真实待提交的精度切换候选使PWI检测代际非空，随后abort必须广播公开检测代际清空。
		i_run_enable = 1'b0;
		pulse_stop_ack;
		repeat(3) @(negedge i_clk);
		i_run_enable = 1'b1;
		pulse_start_ack();
		complete_wrapper_startup;
		pulse_safe_boundary();
		repeat(3) @(negedge i_clk);
		i_dcs_threshold_low = 12'sd100;
		i_dcs_threshold_high = 12'sd200;
		send_normal_sample(300, 1'b0, 1'b0);
		build_9bit_cross_request;
		@(negedge i_clk); i_control_abort_event = 1'b1;
		@(negedge i_clk); i_control_abort_event = 1'b0;
		check_case("AMI-47", cnt_detection_discard_event > 0);
		i_dcs_threshold_low = -12'sd2048;
		i_dcs_threshold_high = 12'sd2047;

		// N08交接前半：背靠背两笔RED NORMAL事务，第二笔完成进入检测分支pending时FIR仍在处理第一笔的21点MAC窗口，
		// 借此天然卡住flag_precision_normal_result_ready=0的多拍窗口，随后abort验证AMI自身仍持有身份时discard正确置1。
		i_run_enable = 1'b0;
		pulse_stop_ack;
		repeat(3) @(negedge i_clk);
		i_allow_new_transaction = 1'b1;
		i_run_enable = 1'b1;
		pulse_start_ack();
		complete_wrapper_startup;
		pulse_safe_boundary();
		repeat(3) @(negedge i_clk);
		i_measurement_result_ready = 1'b1;
		// AMI-47自身收尾abort已经广播过一次检测代际清空，FIR私有历史窗口(cnt_red_sample)已被flag_history_clear清零；
		// 必须先用真实RED SAR9 NORMAL事务重新预热满21点窗口，否则第二笔样本到达时FIR仍处于冷态ST_IDLE，不会进入MAC忙碌态。
		for(idx_sample = 0; idx_sample < 24; idx_sample = idx_sample + 1)begin
			send_normal_sample(150 + idx_sample * 4, 1'b0, 1'b0);
		end
		cnt_detection_transfer_before_n08 = cnt_detection_transfer;
		send_normal_sample_tight(150, 1'b0, 1'b0);
		n08_expect_frame_id = next_frame_id[15:0];
		n08_expect_sample_index = next_sample_index[15:0];
		send_normal_sample_tight(170, 1'b0, 1'b0);
		cnt_watchdog = 0;
		while(!((cnt_detection_transfer == (cnt_detection_transfer_before_n08 + 1)) && dut.flag_detection_pending) && (cnt_watchdog < 400))begin
			@(negedge i_clk);
			cnt_watchdog = cnt_watchdog + 1;
		end
		flag_n08_window_hit = (cnt_detection_transfer == (cnt_detection_transfer_before_n08 + 1)) && dut.flag_detection_pending;
		flag_n08_fir_busy_observed = !dut.flag_precision_normal_result_ready;
		// o_detection_discard_event/identity_valid/frame_id/sample_index/color_ir均为纯组合输出，与i_control_abort_event同拍；
		// 必须在abort仍保持1'b1的这半个周期内取样，abort落回0后flag_detection_pending已经被同一次discard清空，事后取样只会读到已清零的值。
		@(negedge i_clk); i_control_abort_event = 1'b1;
		#1;
		check_case("N08-01", flag_n08_window_hit &&
			o_detection_discard_event &&
			o_detection_discard_identity_valid &&
			(o_detection_discard_frame_id == n08_expect_frame_id) &&
			(o_detection_discard_sample_index == n08_expect_sample_index) &&
			(o_detection_discard_color_ir == 1'b0));
		if(!flag_n08_fir_busy_observed)begin
			$display("N08 DIAG: FIR reported ready again before the abort landed; the busy window was narrower than expected at %0t", $time);
		end
		@(negedge i_clk); i_control_abort_event = 1'b0;

		if(cnt_fail == 0 && cnt_pass == 48)begin
			$display("AMI-01 through AMI-47 plus N08-01 PASS: %0d real comparisons", cnt_pass);
		end else begin
			$display("AMI REGRESSION FAIL: pass=%0d fail=%0d", cnt_pass, cnt_fail);
		end
		$finish;
	end

	// 仿真watchdog确保任何握手死锁都以明确失败结束。
	initial begin
		#2000000;
		$display("FAIL AMI-WATCHDOG");
		$finish;
	end

endmodule
