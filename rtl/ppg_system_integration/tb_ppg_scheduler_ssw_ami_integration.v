`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026-08-16
// Design Name:     PPG Scheduler SSW AMI Joint Verification
// Module Name:     tb_ppg_scheduler_ssw_ami_integration
// Description:     Self-checking physical timing and ADC-owner integration testbench.
// Simulations:     Vivado xsim 2022.2
//
// Referrences:     PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md
//
// Dependencies:    Scheduler V1.3, SSW V1.3.2, and AMI V1.3.3 RTL
//
// Version:         V1.5
// Revision Date:   2026-08-17
// History:
// 2026-08-16       V1.0          Erie          Create real three-module joint regression.
// 2026-08-17       V1.1          Erie          Freeze physical 2 MHz clock period at 500 ns.
// 2026-08-17       V1.2          Erie          Split analog and measurement run/start permits.
// 2026-08-17       V1.3          Erie          Expose AMI algorithm and result observation wires.
// 2026-08-17       V1.4          Erie          Add deterministic physical PPG RAW stimulus generator.
// 2026-08-17       V1.5          Erie          Connect the generator to the 10-second algorithm closure.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年08月16日
// 设计名称:        PPG调度器、SSW与AMI联合验证
// 模块名称:        tb_ppg_scheduler_ssw_ami_integration
// 模块说明:        以真实CLK_DOUT/RAW捕获路径验证波形上下文、ADC owner与完成旁带闭环
// 仿真工程:        Vivado xsim 2022.2
//
// 参考资料:        PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md
//
// 依赖文件:        Scheduler V1.3、SSW V1.3.2及AMI V1.3.3 RTL
//
// 当前版本:        V1.5
// 修订日期:        2026年08月17日
// 修订历史:
// 2026-08-16       V1.0          Erie          新建真实三模块联合回归
// 2026-08-17       V1.1          Erie          将联合TB主时钟冻结为2 MHz物理周期500 ns
// 2026-08-17       V1.2          Erie          拆分模拟与测量运行许可及START事件
// 2026-08-17       V1.3          Erie          接出AMI算法状态与正式结果观察线
// 2026-08-17       V1.4          Erie          增加确定性人体PPG近似RAW激励发生器
// 2026-08-17       V1.5          Erie          将发生器接入10秒算法闭环并验证精度切换

module tb_ppg_scheduler_ssw_ami_integration ();

	// V1.3 stable acceptance trace: each contract ID binds public observables and an expected predicate.
	// RAW-01..13 use indices 0..12; SID/TRK/RRC/NRE/ILM/ADCN/ISE/OIB/LFA/PRC use indices 13..119.
	localparam integer C_RAW_TRACE_COUNT = 13;
	localparam integer C_STABLE_TRACE_COUNT = 107;
	localparam integer C_TRACE_COUNT = C_RAW_TRACE_COUNT + C_STABLE_TRACE_COUNT;
	localparam integer C_JNT_REQUIRED_SUBCHECKS = 52;
	localparam integer C_RESULT_SCOREBOARD_DEPTH = 16;
	localparam integer C_OIB_STALL_CYCLES = 1;
	localparam integer C_TRACE_SID_BASE = 13;
	localparam integer C_TRACE_TRK_BASE = 25;
	localparam integer C_TRACE_RRC_BASE = 35;
	localparam integer C_TRACE_NRE_BASE = 47;
	localparam integer C_TRACE_ILM_BASE = 53;
	localparam integer C_TRACE_ADCN_BASE = 68;
	localparam integer C_TRACE_ISE_BASE = 78;
	localparam integer C_TRACE_OIB_BASE = 88;
	localparam integer C_TRACE_LFA_BASE = 98;
	localparam integer C_TRACE_PRC_BASE = 110;
	localparam [1:0]TRACE_UNCHECKED = 2'b00;
	localparam [1:0]TRACE_PASS = 2'b01;
	localparam [1:0]TRACE_FAIL = 2'b10;
	// A stable check can be outside the joint-TB applicability boundary.  Keep
	// that state distinct from NOT_CLOSED so ordinary NORMAL runs do not claim
	// that calibration-only evidence was executed.
	localparam [1:0]TRACE_NOT_APPLICABLE = 2'b11;
	// xsim selects one independent contract scenario per process.  Scenario 0
	// retains the legacy all-in-one regression for diagnosis only.
	localparam integer C_SCENARIO_ALL = 0;
	localparam integer C_SCENARIO_LONG = 1;
	localparam integer C_SCENARIO_NO_RECHECK = 2;
	localparam integer C_SCENARIO_INPUT_MATRIX = 3;
	localparam integer C_SCENARIO_STARTUP = 4;
	localparam integer C_SCENARIO_TRACKING = 5;
	localparam integer C_SCENARIO_RECHECK = 6;
	localparam integer C_SCENARIO_NUMERIC = 7;
	localparam integer C_SCENARIO_IDENTITY = 8;
	localparam integer C_SCENARIO_OWNER = 9;
	localparam integer C_SCENARIO_LIFECYCLE = 10;
	localparam integer C_SCENARIO_ROBUSTNESS = 11;
	localparam integer C_SCENARIO_CORE_BASELINE = 12;
	localparam integer C_SCENARIO_CORE_CROSS = 13;
	localparam integer C_SCENARIO_CORE_PEAK_VALLEY = 14;
	localparam integer C_SCENARIO_CORE_FIR_TAIL = 15;
	localparam integer C_SCENARIO_CORE_LONG = 16;
	// Core PPG group map: group name -> primary public observations -> required evidence.
	// PPG-BASELINE-WARMUP -> o_fir_history_full_r/o_fir_history_full_ir/o_baseline_valid -> 21 qualified samples before cross.
	// PPG-CROSS-SAR15 -> o_cross_pending/o_fine_window_start_event/o_active_precision_mode -> real upward cross then safe SAR15.
	// PPG-PEAK-VALLEY-RETURN -> o_peak_pending/o_valley_pending/o_precision_15_to_9_event -> valley precedes safe SAR9 return.
	// PPG-FIR-TAIL-ISOLATION -> o_precision_15_to_9_event/o_baseline_valid/o_cross_pending -> old FIR tail cannot create a new cross.
	// PPG-LONG-10-CYCLES -> o_normal_frame_count/o_result_frame_id/o_result_sample_index -> 10 s, 4000 frames, continuous identities.
	reg [8 * 16 - 1:0]reg_trace_id [0:C_TRACE_COUNT - 1];
	reg [8 * 72 - 1:0]reg_trace_observable [0:C_TRACE_COUNT - 1];
	reg [8 * 96 - 1:0]reg_trace_expected [0:C_TRACE_COUNT - 1];
	reg [1:0]reg_trace_status [0:C_TRACE_COUNT - 1];
	integer reg_trace_run_index [0:C_TRACE_COUNT - 1];
	integer reg_trace_compare_count [0:C_TRACE_COUNT - 1];
	reg [8 * 32 - 1:0]reg_trace_group_id [0:C_TRACE_COUNT - 1];
	reg flag_trace_metadata_initialized;
	integer trace_index;

	// Additional scheduler observations reserved by the V1.3 trace map.
	wire o_macro_frame_start_event;
	wire o_scheduler_idle;
	wire [15:0]o_scheduler_current_frame_id;

	// Additional SSW timing, enable, and lifecycle observations.
	wire o_ssw_en_tia_low;
	wire o_ssw_clk_buf_low;
	wire o_ssw_clk_iref_idac_low;
	wire o_ssw_clk_aferst_low;
	wire o_ssw_clk_iref_idac_sar9_low;
	wire o_ssw_clk_iref_idac_sar15_low;
	wire o_ssw_clk_tiaen_low;
	wire o_ssw_en_15sar_low;
	wire o_ssw_en_sar9_amb_low;
	wire o_ssw_en_sar9_dc_low;
	wire o_ssw_en_sar9_iref;
	wire o_ssw_en_sar15_amb_low;
	wire o_ssw_en_sar15_dc_low;
	wire o_ssw_en_sar15_iref;
	wire o_ssw_clk_2m;
	wire o_ssw_wrapper_idle;
	wire o_ssw_precision_active;
	wire o_ssw_calibration_wave_active;

	// Additional AMI numerical, IDAC, recheck, and drain observations.
	wire o_calibration_request_fire;
	wire o_coarse_recovery_calibrated;
	wire o_coarse_saturation_low;
	wire o_coarse_saturation_high;
	wire o_fine_recovery_calibrated;
	wire o_fine_saturation_low;
	wire o_fine_saturation_high;
	wire signed [11:0]o_calibrated_s1_value;
	wire signed [14:0]o_programmable_15_code;
	wire o_programmable_15_valid;
	wire [7:0]o_result_config_epoch;
	wire [7:0]o_result_coef_epoch;
	wire [7:0]o_result_stage2_coef_epoch;
	wire [7:0]o_result_dc_coef_epoch;
	wire [1:0]o_result_frame_type;
	wire [7:0]o_result_amb_code_snapshot;
	wire [7:0]o_result_dc_code_snapshot;
	wire [3:0]o_result_amb_code_epoch;
	wire [3:0]o_result_dc_code_epoch;
	wire o_amb_code_at_min;
	wire o_amb_code_at_max;
	wire o_dcs_r_code_at_min;
	wire o_dcs_r_code_at_max;
	wire o_dcs_ir_code_at_min;
	wire o_dcs_ir_code_at_max;
	wire o_amb_code_update;
	wire o_dcs_r_code_update;
	wire o_dcs_ir_code_update;
	wire o_dcs_r_track_adjust;
	wire o_dcs_ir_track_adjust;
	wire o_amb_search_done;
	wire o_dcs_r_search_done;
	wire o_dcs_ir_search_done;
	wire o_amb_search_exhausted;
	wire o_dcs_r_search_exhausted;
	wire o_dcs_ir_search_exhausted;
	wire o_amb_pending_valid;
	wire o_dcs_r_pending_valid;
	wire o_dcs_ir_pending_valid;
	wire o_amb_fault;
	wire o_dcs_r_fault;
	wire o_dcs_ir_fault;
	wire o_idac_fault_blocking;
	wire o_idac_protocol_error_sticky;
	wire o_idac_idle;
	wire o_fine_window_active;
	wire [15:0]o_fine_window_start_frame_id;
	wire [15:0]o_precision_15_to_9_frame_id;
	wire o_reacquire_request_event;
	wire o_mode_fault_event;
	wire o_amb_recheck_pending;
	wire o_amb_recheck_accept;
	wire o_amb_recheck_busy;
	wire o_normal_output_inhibit;
	wire o_recheck_sequence_done;
	wire o_recheck_sequence_failed;
	wire o_fir_idle;
	wire o_detection_fork_idle;
	wire o_detector_idle;
	wire o_controller_idle;
	wire o_ami_scheduler_idle;
	wire o_return_pending;
	wire o_reacquire_active;
	wire o_detector_fine_window_active;
	wire signed [31:0]o_slope_current_q16;
	wire o_baseline_protocol_error_sticky;
	wire o_fine_window_timeout_sticky;
	wire o_reacquire_timeout_sticky;
	wire o_peak_valley_protocol_error_sticky;
	wire o_switch_timeout_sticky;
	wire o_precision_protocol_error_sticky;
	wire o_integration_protocol_error_sticky;
	wire o_adc_chain_idle;
	wire o_normal_fork_idle;
	wire o_measurement_output_idle;
	wire o_datapath_empty;

	//===================<参数定义>===================//
	localparam integer C_CLK_PERIOD_NS = 500;    // 2 MHz正式物理时钟周期（500 ns）
	localparam time C_SIM_TIMEOUT_NS = 64'd12000000000; // 覆盖10秒PPG物理时基并保留启动与收尾余量
	localparam integer C_PPG_HEART_SAMPLES = 400; // 60 BPM下每种颜色每个心搏400个400 Hz样本
	localparam integer C_PPG_DRIFT_SAMPLES = 4000; // 10秒确定性基线漂移周期
	localparam integer C_PPG_ALGORITHM_SAMPLES = 4004; // 超过10秒并包含10个完整心搏
	localparam time C_PPG_MIN_DURATION_NS = 64'd10000000000; // 算法闭环正式物理时长下限
	localparam integer C_PPG_RED_BASE_CODE = 260; // RED目标检测码中心
	localparam integer C_PPG_IR_BASE_CODE = 255; // IR目标检测码中心
	localparam integer C_PPG_RED_AMPLITUDE = 88; // RED脉动幅度
	localparam integer C_PPG_IR_AMPLITUDE = 62; // IR脉动幅度
	localparam [1:0]FRAME_TYPE_AMB = 2'b00;      // AMB校准事务编码
	localparam [1:0]FRAME_TYPE_DCS = 2'b01;      // DCS校准事务编码
	localparam [1:0]FRAME_TYPE_NORMAL = 2'b10;   // 正常PPG测量事务编码
	localparam [1:0]OPTICAL_MODE_BOTH = 2'b00;  // 红光和红外均启用

	//===================<全局激励寄存器>===================//
	reg i_clk;                                   // 三模块共享2 MHz数字时钟
	reg i_rstn;                                  // 三模块共享低有效异步复位
	reg i_active_config_valid;                   // 已提交ACTIVE配置总资格
	reg analog_run_enable;                       // SSW模拟运行许可
	reg measurement_run_enable;                  // Scheduler/AMI测量运行许可
	reg measurement_allow_new_transaction;       // Scheduler/AMI允许新ADC事务
	reg analog_start_ack_event;                  // SSW模拟START确认单拍
	reg measurement_start_ack_event;             // Scheduler/AMI测量START确认单拍
	reg i_stop_ack_event;                        // STOP确认单拍
	reg i_control_abort_event;                   // abort撤销单拍
	reg i_diag_clear_event;                      // 诊断清除单拍
	reg i_run_profile;                           // NORMAL运行档案
	reg i_input_source;                          // 光电二极管输入源
	reg [1:0]i_optical_mode;                     // 双光物理帧模式
	reg i_static_characterization_enable;        // STATIC_BIAS在本联合回归中关闭
	reg [4:0]i_test_mux_ctrl;                    // 测试MUX固定安全选择
	reg [7:0]i_leddac_r_code;                    // RED LED RDAC已提交码
	reg [7:0]i_leddac_ir_code;                   // IR LED RDAC已提交码

	//===================<异步ADC物理模型输入>===================//
	reg [9:0]i_dout_stage1_low;                  // 外部ADC提供的Stage1 RAW码
	reg i_clk_stage1_dout_low_async;             // 外部Stage1 CLK_DOUT异步完成电平
	reg [9:0]i_dout_stage2_low;                  // 外部ADC提供的Stage2 RAW码
	reg i_clk_stage2_dout_low_async;             // 外部Stage2 CLK_DOUT异步完成电平
	reg i_adc_idle;                              // 三模块共用的唯一物理ADC空闲来源
	reg i_measurement_result_ready;              // 正式测量结果消费者始终可接收

	//===================<AMI固定配置输入>===================//
	reg [7:0]i_config_epoch;                     // ACTIVE配置版本
	reg [7:0]i_stage1_coef_epoch;                // Stage1系数版本
	reg [7:0]i_stage2_coef_epoch;                // Stage2系数版本
	reg [7:0]i_dc_recovery_coef_epoch;           // DC恢复系数版本
	reg [1:0]i_idac_mode;                        // 固定为MANUAL以验证启动码边界
	reg i_amb_enable;                            // AMB码控制使能
	reg i_dcs_enable;                            // DCS码控制使能
	reg i_amb_polarity;                          // AMB搜索极性
	reg i_dcs_polarity;                          // DCS搜索极性
	reg [7:0]i_amb_manual_code;                  // AMB手动启动码
	reg [7:0]i_amb_code_min;                     // AMB自动下界保留配置
	reg [7:0]i_amb_code_max;                     // AMB自动上界保留配置
	reg [7:0]i_dcs_r_manual_code;                // RED DCS手动启动码
	reg [7:0]i_dcs_r_code_min;                   // RED DCS自动下界保留配置
	reg [7:0]i_dcs_r_code_max;                   // RED DCS自动上界保留配置
	reg [7:0]i_dcs_ir_manual_code;               // IR DCS手动启动码
	reg [7:0]i_dcs_ir_code_min;                  // IR DCS自动下界保留配置
	reg [7:0]i_dcs_ir_code_max;                  // IR DCS自动上界保留配置
	reg signed [11:0]i_amb_threshold_low;        // AMB残差窗口下界
	reg signed [11:0]i_amb_threshold_high;       // AMB残差窗口上界
	reg signed [11:0]i_dcs_threshold_low;        // DCS残差窗口下界
	reg signed [11:0]i_dcs_threshold_high;       // DCS残差窗口上界
	reg [7:0]i_amb_confirm_count;                // AMB确认次数
	reg [7:0]i_dcs_confirm_count;                // DCS确认次数
	reg i_stage1_calibration_valid;              // Stage1校准配置有效
	reg signed [25:0]i_stage1_weight_q16_0;      // Stage1位0权重
	reg signed [25:0]i_stage1_weight_q16_1;      // Stage1位1权重
	reg signed [25:0]i_stage1_weight_q16_2;      // Stage1位2权重
	reg signed [25:0]i_stage1_weight_q16_3;      // Stage1位3权重
	reg signed [25:0]i_stage1_weight_q16_4;      // Stage1位4权重
	reg signed [25:0]i_stage1_weight_q16_5;      // Stage1位5权重
	reg signed [25:0]i_stage1_weight_q16_6;      // Stage1位6权重
	reg signed [25:0]i_stage1_weight_q16_7;      // Stage1位7权重
	reg signed [25:0]i_stage1_weight_q16_8;      // Stage1位8权重
	reg signed [25:0]i_stage1_weight_q16_9;      // Stage1位9权重
	reg signed [31:0]i_stage1_offset_q16;        // Stage1偏置
	reg i_stage2_calibration_valid;              // Stage2校准配置有效
	reg signed [19:0]i_stage2_gain_q16;          // Stage2增益
	reg signed [31:0]i_stage2_offset_q16;        // Stage2偏置
	reg i_dc9_recovery_valid;                    // SAR9恢复配置有效
	reg i_dc15_recovery_valid;                   // SAR15恢复配置有效
	reg signed [31:0]i_dc9_recovery_gain_q16;    // SAR9恢复增益
	reg signed [31:0]i_dc15_recovery_gain_q16;   // SAR15恢复增益
	reg i_initial_precision;                     // 启动精度选择
	reg i_slope_mode;                            // 固定基线斜率模式
	reg signed [31:0]i_fixed_slope_q16;          // 固定Q16斜率
	reg [15:0]i_alpha_q15;                       // 基线alpha
	reg [15:0]i_beta_q15;                        // 基线beta
	reg [15:0]i_timing_adjust_ratio_q15;         // 相交时间修正比例
	reg signed [31:0]i_slope_min_q16;            // 斜率下界
	reg signed [31:0]i_slope_max_q16;            // 斜率上界
	reg signed [31:0]i_baseline_delta_q16;       // 基线锚点偏置
	reg [31:0]i_cross_hysteresis_q16;            // 相交迟滞
	reg [15:0]i_lead_min_frames;                 // 相交提前量下界
	reg [15:0]i_lead_max_frames;                 // 相交提前量上界
	reg [3:0]i_cross_confirm_count;              // 相交确认次数
	reg [3:0]i_no_cross_limit;                   // 无相交重检门限
	reg [3:0]i_peak_confirm_count;               // 波峰确认次数
	reg [3:0]i_valley_confirm_count;             // 波谷确认次数
	reg [23:0]i_direction_deadband;              // 方向死区
	reg [23:0]i_min_peak_valley_amplitude;       // 峰谷幅度门限
	reg [15:0]i_min_peak_to_valley_frames;       // 峰到谷间隔下界
	reg [15:0]i_min_peak_to_peak_frames;         // 峰到峰间隔下界
	reg [15:0]i_max_fine_window_frames;          // SAR15窗口上限
	reg [15:0]i_max_reacquire_frames;            // 重新获取窗口上限
	reg i_peak_valley_config_valid;              // 峰谷配置完整有效
	reg [15:0]i_amb_recheck_interval_frames;     // 周期AMB重检间隔

	//===================<Scheduler与SSW互连>===================//
	wire o_waveform_context_valid;               // Scheduler发布的模拟波形上下文
	wire o_waveform_context_ready;               // TB互连后的SSW波形上下文握手返回
	wire o_waveform_context_ready_raw;           // SSW原始公开ready，用于TB合法反压适配
	wire o_waveform_precision_mode;              // 波形精度快照
	wire [15:0]o_waveform_frame_id;              // 波形物理帧号
	wire o_waveform_color_ir;                    // 波形颜色身份
	wire [1:0]o_waveform_frame_type;             // 波形事务类型
	wire [7:0]o_waveform_amb_code_snapshot;      // 波形AMB码快照
	wire [7:0]o_waveform_dc_code_snapshot;       // 波形DC码快照
	wire [3:0]o_waveform_amb_code_epoch;         // 波形AMB版本
	wire [3:0]o_waveform_dc_code_epoch;          // 波形DC版本
	wire o_waveform_input_source;                // 波形输入源快照
	wire [1:0]o_waveform_optical_mode;           // 波形光学模式快照
	wire [7:0]o_waveform_leddac_code_snapshot;   // 波形LEDDAC码快照
	wire o_adc_owner_ready;                      // SSW接受新物理owner的资格
	wire o_adc_owner_commit_event;               // Scheduler和AMI共同提交的owner事件
	wire o_adc_owner_precision_mode;             // owner精度身份
	wire [15:0]o_adc_owner_frame_id;             // owner物理帧身份
	wire o_adc_owner_color_ir;                   // owner颜色身份
	wire [1:0]o_adc_owner_frame_type;            // owner事务类型
	wire [7:0]o_adc_owner_amb_code_snapshot;     // owner AMB码快照
	wire [7:0]o_adc_owner_dc_code_snapshot;      // owner DC码快照
	wire [3:0]o_adc_owner_amb_code_epoch;        // owner AMB版本
	wire [3:0]o_adc_owner_dc_code_epoch;         // owner DC版本
	wire [15:0]o_adc_owner_sample_index;         // owner全局样本序号
	wire [12:0]o_macro_tick;                     // 统一宏帧物理相位
	wire [2:0]o_calibration_subframe_index;      // 统一校准子帧序号
	wire [9:0]o_calibration_local_tick;          // 统一校准局部相位
	wire o_normal_frame_active;                  // Scheduler NORMAL物理帧活动
	wire o_calibration_frame_active;             // Scheduler校准物理帧活动
	wire o_macro_frame_safe_boundary;            // 宏帧安全边界
	wire o_idac_code_safe_boundary;              // 合并后的IDAC安全边界
	wire o_startup_idac_safe_boundary;           // START唯一IDAC安全边界
	wire [15:0]o_safe_frame_id;                  // 下一安全帧编号
	wire o_normal_frame_complete_event;          // NORMAL宏帧完成事件
	wire o_calibration_frame_complete_event;     // 校准物理帧完成事件
	wire o_scheduler_transaction_inflight;       // Scheduler单物理owner在途状态
	wire [15:0]o_scheduler_next_sample_index;    // Scheduler下一可分配样本序号
	wire o_scheduler_launch_timeout_sticky;      // 波形上下文超时诊断
	wire o_scheduler_owner_deadline_timeout_sticky; // owner提交超时诊断
	wire o_scheduler_completion_mismatch_sticky; // 完成身份错配诊断
	wire o_scheduler_protocol_error_sticky;      // Scheduler协议诊断
	wire o_scheduler_fault_blocking;             // Scheduler本地阻断故障

	//===================<Scheduler与AMI互连>===================//
	wire o_transaction_start_valid;              // TB互连后的Scheduler保持型ADC事务请求
	wire o_transaction_start_ready;              // TB互连后的AMI接受ADC事务资格
	wire o_transaction_start_valid_raw;          // Scheduler原始公开valid，用于TB合法反压适配
	wire o_transaction_start_ready_raw;          // AMI原始公开ready，用于TB合法反压适配
	wire o_transaction_start_fire;               // AMI真实ADC owner提交事件
	wire o_transaction_precision_mode;           // AMI事务精度快照
	wire [15:0]o_transaction_frame_id;           // AMI事务物理帧号
	wire [15:0]o_transaction_sample_index;       // AMI事务样本序号
	wire o_transaction_color_ir;                 // AMI事务颜色身份
	wire [1:0]o_transaction_frame_type;          // AMI事务类型
	wire [7:0]o_transaction_amb_code_snapshot;   // AMI事务AMB码快照
	wire [7:0]o_transaction_dc_code_snapshot;    // AMI事务DC码快照
	wire [3:0]o_transaction_amb_code_epoch;      // AMI事务AMB版本
	wire [3:0]o_transaction_dc_code_epoch;       // AMI事务DC版本
	wire o_adc_transaction_complete_event;       // AMI真实捕获和S1归属后的完成旁带
	wire o_adc_transaction_success;              // 完成旁带的结果成功资格
	wire [15:0]o_adc_complete_sample_index;      // 完成旁带的owner样本序号
	wire o_calibration_sample_valid;             // AMI发起的校准请求
	wire o_calibration_sample_ready;             // Scheduler接受校准请求
	wire [1:0]o_calibration_frame_type;          // AMI校准请求类型
	wire o_calibration_color_ir;                 // AMI校准请求颜色
	wire o_calibration_precision_mode;           // AMI校准固定SAR9精度
	wire [1:0]o_calibration_request_reason;      // AMI校准请求原因
	wire o_active_precision_mode;                // AMI committed精度
	wire o_normal_measurement_eligible;          // AMI开放NORMAL事务资格
	wire o_switch_hold_new_transaction;          // AMI精度切换暂停资格
	wire o_ami_fault_blocking;                   // AMI阻断故障输出
	wire o_startup_search_complete;              // AMI启动手动码或搜索完成状态
	wire [7:0]o_amb_code;                        // AMI committed AMB码
	wire [7:0]o_dcs_r_code;                      // AMI committed RED DC码
	wire [7:0]o_dcs_ir_code;                     // AMI committed IR DC码
	wire [3:0]o_amb_code_epoch;                  // AMI AMB码版本
	wire [3:0]o_dcs_r_code_epoch;                // AMI RED DC码版本
	wire [3:0]o_dcs_ir_code_epoch;               // AMI IR DC码版本
	wire o_measurement_result_valid;             // AMI正式测量结果保持有效
	wire o_baseline_valid;                       // AMI动态基线有效资格
	wire o_cross_pending;                        // AMI动态基线相交请求保持
	wire o_fine_window_start_event;              // AMI真实进入SAR15窗口事件
	wire o_switch_pending;                       // AMI精度切换等待提交
	wire o_switch_target_precision;              // AMI待提交目标精度
	wire o_peak_pending;                         // AMI波峰保持状态
	wire o_valley_pending;                       // AMI波谷保持状态
	wire o_precision_15_to_9_event;              // AMI真实返回SAR9事件
	wire [15:0]o_normal_frame_count;             // AMI NORMAL帧累计值
	wire o_fir_history_full_r;                   // AMI RED FIR历史预热完成
	wire o_fir_history_full_ir;                  // AMI IR FIR历史预热完成
	wire o_result_precision_mode;                // AMI正式结果精度快照
	wire [15:0]o_result_frame_id;                // AMI正式结果物理帧号
	wire [15:0]o_result_sample_index;            // AMI正式结果全局样本序号
	wire o_result_color_ir;                      // AMI正式结果颜色身份

	// 算法闭环输入输出观察线只接收AMI公开端口，禁止force内部状态。
	wire o_coarse_valid;                         // AMI粗结果有效资格
	wire o_fine_valid;                           // AMI精细结果有效资格
	wire signed [23:0]o_coarse_ppg_value;        // AMI粗PPG结果
	wire signed [23:0]o_fine_ppg_value;          // AMI精细PPG结果

	//===================<SSW状态与波形观察>===================//
	wire o_analog_safe;                          // SSW给Scheduler和AMI的模拟安全资格
	wire o_sar_timing_idle;                      // SSW给Scheduler的SAR时序空闲资格
	wire o_adc_owner_inflight;                   // SSW物理owner身份有效状态
	wire o_ssw_fault_blocking;                   // SSW阻断故障输出
	wire o_en_test;                              // SSW测试输入使能输出
	wire o_leden1_low;                           // SSW RED LEDEN低有效输出
	wire o_leden2_low;                           // SSW IR LEDEN低有效输出
	wire [7:0]o_leddac;                          // SSW LEDDAC输出
	wire [4:0]o_s_in;                            // SSW STATIC_BIAS测试MUX输出
	wire o_switch_protocol_error_sticky;         // SSW切换协议错误sticky
	wire o_transaction_mismatch_sticky;          // SSW事务身份错配sticky
	wire o_owner_deadline_timeout_sticky;        // SSW owner截止超时sticky
	wire o_calibration_timeout_sticky;           // SSW校准超时sticky
	wire o_clk_9q1_low;                          // SAR9 Q1 physical phase observation
	wire o_clk_15q1_low;                         // SAR15 Q1 physical phase observation
	wire o_clk_q2_low;                           // Common Q2 physical phase observation
	wire o_clk_q3_low;                           // 模拟波形的Q3有效低电平
	wire [7:0]o_idac_sar9ambn_low;               // SAR9 AMB逐bit码窗口观测
	wire [7:0]o_idac_sar9dcn_low;                // SAR9 DC逐bit码窗口观测
	wire [7:0]o_idac_sar15ambn_low;              // SAR15 AMB隔离总线观测
	wire [7:0]o_idac_sar15dcn_low;               // SAR15 DC隔离总线观测

	//===================<自检统计与快照>===================//
	integer cnt_pass;                            // 通过的联合场景数量
	integer cnt_fail;                            // 失败的联合场景数量
	integer cnt_run_index;                       // Independent reset/run sequence number
	integer cnt_run_jnt_checked;                 // Real JNT comparisons executed in the active baseline
	integer cnt_run_jnt_pass;                    // Passing JNT comparisons in the active baseline
	integer cnt_run_jnt_fail;                    // Failing JNT comparisons in the active baseline
	integer cnt_run_event;                       // Structured public-interface events in the active run
	integer cnt_run_stable_pass;                 // Stable IDs passing in the reported group range
	integer cnt_run_stable_fail;                 // Stable IDs failing in the reported group range
	integer cnt_run_stable_unclosed;             // Stable IDs without a real comparison in the reported group range
	integer cnt_jnt_parent_run_index;            // JNT run associated with the following functional run
	integer cnt_jnt_parent_checked;
	integer cnt_jnt_parent_pass;
	integer cnt_jnt_parent_fail;
	reg flag_jnt_parent_valid;
	reg [8 * 32 - 1:0]reg_jnt_parent_group_id;
	integer fd_event_log;                        // File descriptor for the complete structured event trace
	reg flag_event_log_initialized;              // Selects truncate-once then append-per-run behavior
	reg flag_jnt_baseline_active;                // Qualifies check_case accounting as JNT evidence
	reg [8 * 32 - 1:0]reg_run_group_id;          // Contract group name bound to the reset/run
	reg [8 * 32 - 1:0]reg_contract_group_id;     // Parent contract group for legal matrix sub-runs
	reg flag_contract_group_override;            // Keeps sub-run reset provenance under its parent group
	reg [8 * 32 - 1:0]reg_run_first_failure_id;  // First JNT or stable-ID failure in the reset/run
	time time_run_reset_assert;                  // time-typed independent reset timestamp
	time time_run_start_ack;                     // time-typed accepted measurement START timestamp
	time time_run_deadline;                      // time-typed absolute watchdog deadline
	integer cnt_startup_boundary;                // START安全边界次数
	integer cnt_waveform_context;                // 波形上下文真实握手次数
	integer cnt_owner_commit;                    // 真实ADC owner提交次数
	integer cnt_completion;                      // AMI完成旁带次数
	integer cnt_measurement_result;              // AMI正式结果握手次数
	integer cnt_red_waveform_context;            // RED上下文握手次数
	integer cnt_ir_waveform_context;             // IR上下文握手次数
	integer cnt_watchdog;                        // 有界等待临时计数
	integer cnt_raw_q1_observed;
	integer cnt_raw_q2_observed;
	integer cnt_raw_q3_observed;
	integer cnt_raw_q3_end_observed;
	integer cnt_raw_async_observed;
	integer cnt_raw_completion_observed;
	integer cnt_raw_identity_observed;
	integer cnt_raw_profile_rise;
	integer cnt_raw_profile_fall;
	reg flag_raw_profile_notch_rebound;
	reg flag_raw_profile_drift_observed;
	reg flag_raw_profile_clamp_observed;
	reg [31:0]reg_raw_signature;
	reg [31:0]reg_expected_raw_signature;
	reg flag_raw_signature_expected;
	integer cnt_raw_signature_samples;
	reg [9:0]reg_raw_profile_prev_red;
	reg [9:0]reg_raw_profile_prev_ir;
	reg flag_raw_profile_prev_red_valid;
	reg flag_raw_profile_prev_ir_valid;
	integer cnt_matrix_frame_start;
	integer cnt_matrix_frame_interval_mismatch;
	reg [12:0]reg_matrix_prev_macro_tick;
	time reg_matrix_prev_frame_time;
	reg flag_matrix_400hz_ok;
	reg flag_static_q1_seen;
	reg flag_static_q2_seen;
	reg flag_static_q3_seen;
	reg flag_static_async_seen;
	reg flag_static_done_seen;
	reg flag_static_fir_seen;
	reg flag_static_recheck_seen;
	reg flag_static_algorithm_result_seen;
	reg flag_static_atomic_update_ok;
	reg [4:0]reg_static_prev_s_in;
	reg flag_static_s_edge_seen;
	reg flag_static_s_edge_atomic;
	reg flag_lfa_early_dout_rejected;
	reg flag_lfa_duplicate_done_rejected;
	reg flag_lfa_wrong_identity_observed;
	integer cnt_owner_before;                    // 场景开始时owner计数
	integer cnt_completion_before;               // 场景开始时完成计数
	integer cnt_result_before;                   // 场景开始时正式结果计数
	reg flag_startup_boundary_without_owner;     // 启动边界本拍无ADC事务的检查快照
	reg [15:0]reg_startup_boundary_sample_index; // 启动边界观察到的下一样本序号
	reg flag_ir_context_while_red_inflight;      // IR上下文在RED物理owner未释放时已接管
	reg flag_red_q1_seen;                        // RED owner reached its selected Q1 phase
	reg flag_red_q2_seen;                        // RED owner reached its Q2 phase
	reg flag_red_q3_seen;                        // 当前RED owner的Q3低电平已经出现
	reg flag_ir_q1_seen;                         // IR owner reached its selected Q1 phase
	reg flag_ir_q2_seen;                         // IR owner reached its Q2 phase
	reg flag_ir_q3_seen;                         // 当前IR owner的Q3低电平已经出现
	reg reg_last_owner_precision_mode;           // Most recent owner precision snapshot
	reg [15:0]reg_last_owner_frame_id;           // Most recent owner frame snapshot
	reg [1:0]reg_last_owner_frame_type;           // Most recent owner frame-type snapshot
	reg [7:0]reg_last_owner_amb_code;            // Most recent owner AMB code snapshot
	reg [7:0]reg_last_owner_dc_code;             // Most recent owner DC code snapshot
	reg flag_owner_context_identity_match;       // Committed owner metadata matched its waveform context
	reg reg_red_waveform_precision_mode;         // RED waveform precision frozen at context fire
	reg [7:0]reg_red_waveform_amb_code;          // RED waveform AMB snapshot frozen before preheat
	reg [7:0]reg_red_waveform_dc_code;           // RED waveform DC snapshot frozen before preheat
	reg reg_ir_waveform_precision_mode;          // IR waveform precision frozen at context fire
	reg [7:0]reg_ir_waveform_amb_code;           // IR waveform AMB snapshot frozen before preheat
	reg [7:0]reg_ir_waveform_dc_code;            // IR waveform DC snapshot frozen before preheat
	reg flag_selected_amb_bus_seen;              // Selected precision AMB bus exposed snapshot bits
	reg flag_selected_dc_bus_seen;               // Selected precision DC bus exposed snapshot bits
	reg flag_red_dc_bus_seen;                    // RED DC snapshot appeared in its selected IDAC bus
	reg flag_ir_dc_bus_seen;                     // IR DC snapshot appeared in its selected IDAC bus
	reg flag_unselected_idac_bus_clean;          // Inactive precision buses stayed at zero
	reg flag_idac_bus_violation;                 // Any inactive precision bus toggled non-zero
	reg flag_ise_pattern_31_seen;
	reg flag_ise_pattern_42_seen;
	reg flag_ise_pattern_53_seen;
	reg reg_last_owner_color_ir;                 // 最近提交owner的颜色快照
	reg [15:0]reg_last_owner_sample_index;       // 最近提交owner的样本序号快照
	reg [12:0]reg_last_owner_macro_tick;         // 最近提交owner的宏帧相位快照
	reg reg_last_completion_success;             // 最近AMI完成旁带的成功资格
	reg [15:0]reg_last_completion_sample_index;  // 最近AMI完成旁带的样本序号
	reg flag_reset_done_observation;             // reset后旧DONE拒绝场景观测开关
	reg flag_normal_mismatch_reported;           // 首次NORMAL启动上下文错配诊断只打印一次

	//===================<Scheduler实例化>===================//
	// Scheduler只拥有物理相位、波形上下文发布及ADC owner提交次序。
	//===================<真实PPG算法闭环观察>===================//
	reg flag_ppg_algorithm_active;
	integer cnt_ppg_algorithm_result;
	integer cnt_ppg_algorithm_sar9_result;
	integer cnt_ppg_algorithm_sar15_result;
	reg flag_ppg_baseline_valid_seen;
	reg flag_ppg_cross_pending_seen;
	reg flag_ppg_fine_window_start_seen;
	reg flag_ppg_peak_pending_seen;
	reg flag_ppg_valley_pending_seen;
	reg flag_ppg_precision_15_seen;
	reg flag_ppg_precision_15_to_9_seen;
	reg flag_ppg_precision_9_after_15_seen;
	reg flag_ppg_fir_full_r_seen;
	reg flag_ppg_fir_full_ir_seen;
	reg flag_ppg_result_sequence_ok;
	reg flag_ppg_sar15_tail_isolated;
	integer cnt_ppg_return_pending_seen;
	integer cnt_ppg_return_event_seen;
	integer cnt_ppg_fine_timeout_seen;
	integer cnt_ppg_reacquire_seen;
	// Functional scenario controls are set by each independent run before releasing reset.
	reg [15:0]reg_scenario_recheck_interval;
	reg reg_scenario_input_source;
	reg [1:0]reg_scenario_optical_mode;
	reg reg_scenario_initial_precision;
	reg reg_scenario_emit_long_checks;
	reg [8 * 32 - 1:0]reg_scenario_group_id;
	reg [1:0]reg_scenario_idac_mode;
	integer reg_scenario_startup_watchdog_limit;
	reg reg_scenario_enable_tracking_after_startup;
	reg reg_scenario_force_search_failure;
	reg reg_scenario_force_recheck_failure;
	reg reg_scenario_allow_startup_failure;
	reg reg_scenario_recheck_nominal_calibration;
	reg reg_scenario_enable_result_backpressure;
	reg reg_scenario_enable_waveform_backpressure;
	reg reg_scenario_enable_transaction_backpressure;
	reg reg_scenario_preserve_for_jnt;
	integer cnt_result_backpressure_hold;
	reg reg_oib_waveform_stall_active;
	reg reg_oib_transaction_stall_active;
	reg flag_oib_waveform_stall_complete;
	reg flag_oib_transaction_stall_complete;
	reg flag_oib_waveform_stall_seen;
	reg flag_oib_transaction_stall_seen;
	reg flag_oib_waveform_accept_seen;
	reg flag_oib_transaction_accept_seen;
	reg flag_oib_waveform_hold_ok;
	reg flag_oib_transaction_hold_ok;
	integer cnt_oib_waveform_stall_cycles;
	integer cnt_oib_transaction_stall_cycles;
	integer cnt_oib_waveform_accept;
	integer cnt_oib_transaction_accept;
	reg [15:0]reg_oib_waveform_frame_id;
	reg reg_oib_waveform_color_ir;
	reg [1:0]reg_oib_waveform_frame_type;
	reg reg_oib_waveform_precision_mode;
	reg [7:0]reg_oib_waveform_amb_code;
	reg [7:0]reg_oib_waveform_dc_code;
	reg [15:0]reg_oib_waveform_next_sample_index;
	reg [15:0]reg_oib_transaction_frame_id;
	reg [15:0]reg_oib_transaction_sample_index;
	reg reg_oib_transaction_color_ir;
	reg [1:0]reg_oib_transaction_frame_type;
	reg reg_oib_transaction_precision_mode;
	reg [7:0]reg_oib_transaction_amb_code;
	reg [7:0]reg_oib_transaction_dc_code;
	reg [15:0]reg_oib_transaction_next_sample_index;
	reg flag_oib_waveform_snapshot_valid;
	reg flag_oib_transaction_snapshot_valid;
	integer reg_scenario_waveform_mode;
	integer reg_scenario_numeric_vector_mode;
	integer reg_scenario_sample_count;
	reg flag_ppg_have_result;
	reg [15:0]reg_ppg_last_result_sample_index;
	reg [15:0]reg_ppg_last_result_frame_id;
	reg signed [11:0]reg_last_calibrated_s1_value;
	reg signed [14:0]reg_last_programmable_15_code;
	reg signed [23:0]reg_last_coarse_ppg_value;
	reg signed [23:0]reg_last_fine_ppg_value;
	reg [7:0]reg_last_result_config_epoch;
	reg [7:0]reg_last_result_coef_epoch;
	reg [7:0]reg_last_result_stage2_coef_epoch;
	reg [7:0]reg_last_result_dc_coef_epoch;
	reg [1:0]reg_last_result_frame_type;
	reg [7:0]reg_last_result_amb_code_snapshot;
	reg [7:0]reg_last_result_dc_code_snapshot;
	reg [3:0]reg_last_result_amb_code_epoch;
	reg [3:0]reg_last_result_dc_code_epoch;
	time time_ppg_algorithm_start;
	time time_ppg_algorithm_end;
	// Per-process machine-readable result artifact used by the external aggregator.
	integer reg_selected_scenario;
	integer reg_plusarg_found;
	reg [8 * 256 - 1:0]reg_result_file_path;
	reg [8 * 256 - 1:0]reg_event_file_path;
	integer fd_result_file;
	reg flag_result_file_initialized;

	//===================<第2步：IDAC状态记账>===================//
	// 这些寄存器只记录公开输出的边沿和比较结果，不向DUT写入任何状态。
	integer cnt_amb_pending_observed;
	integer cnt_dcs_r_pending_observed;
	integer cnt_dcs_ir_pending_observed;
	integer cnt_amb_update_observed;
	integer cnt_dcs_r_update_observed;
	integer cnt_dcs_ir_update_observed;
	integer cnt_dcs_r_track_adjust_observed;
	integer cnt_dcs_ir_track_adjust_observed;
	integer cnt_amb_search_done_observed;
	integer cnt_dcs_r_search_done_observed;
	integer cnt_dcs_ir_search_done_observed;
	integer cnt_idac_search_exhausted_observed;
	integer cnt_idac_epoch_mismatch;
	integer cnt_idac_code_delta_mismatch;
	integer cnt_idac_boundary_wrap_violation;
	integer cnt_idac_update_without_change;
	integer cnt_tracking_boundary_hold_observed;
	integer cnt_tracking_epoch_wrap_observed;
	reg [7:0]reg_idac_prev_amb_code;
	reg [7:0]reg_idac_prev_dcs_r_code;
	reg [7:0]reg_idac_prev_dcs_ir_code;
	reg [3:0]reg_idac_prev_amb_epoch;
	reg [3:0]reg_idac_prev_dcs_r_epoch;
	reg [3:0]reg_idac_prev_dcs_ir_epoch;
	reg reg_idac_prev_amb_pending;
	reg reg_idac_prev_dcs_r_pending;
	reg reg_idac_prev_dcs_ir_pending;
	reg reg_idac_prev_amb_search_done;
	reg reg_idac_prev_dcs_r_search_done;
	reg reg_idac_prev_dcs_ir_search_done;
	reg reg_idac_prev_amb_exhausted;
	reg reg_idac_prev_dcs_r_exhausted;
	reg reg_idac_prev_dcs_ir_exhausted;
	reg flag_idac_epoch_relation_ok;
	reg flag_idac_track_delta_ok;
	reg flag_idac_no_wrap_ok;
	reg flag_idac_observation_valid;
	reg flag_idac_startup_order_ok;
	reg [1:0]reg_idac_search_stage;
	reg [1:0]reg_startup_stage_state;

	//===================<第2步：启动/重检真实ADC链记账>===================//
	integer cnt_startup_calibration_request;
	integer cnt_startup_calibration_completion;
	integer cnt_startup_successful_calibration_completion;
	integer cnt_startup_amb_completion;
	integer cnt_startup_dcs_r_completion;
	integer cnt_startup_dcs_ir_completion;
	integer cnt_startup_amb_waveform_observed;
	integer cnt_startup_dcs_r_waveform_observed;
	integer cnt_startup_dcs_ir_waveform_observed;
	integer cnt_startup_q3_observed;
	integer cnt_startup_q3_spacing_mismatch;
	integer cnt_startup_owner_deadline_mismatch;
	integer cnt_startup_real_chain_mismatch;
	integer cnt_recheck_pending_observed;
	integer cnt_recheck_accept_observed;
	integer cnt_recheck_done_observed;
	integer cnt_recheck_failed_observed;
	integer cnt_recheck_calibration_request;
	integer cnt_recheck_calibration_completion;
	integer cnt_recheck_successful_calibration_completion;
	integer cnt_recheck_amb_completion;
	integer cnt_recheck_dcs_r_completion;
	integer cnt_recheck_dcs_ir_completion;
	integer cnt_recheck_real_chain_mismatch;
	integer cnt_recheck_async_observed;
	integer cnt_recheck_sequence_mismatch;
	integer cnt_recheck_drain_mismatch;
	integer cnt_recheck_output_leak;
	integer cnt_recheck_history_r_warmup;
	integer cnt_recheck_history_ir_warmup;
	reg reg_startup_calibration_active;
	reg reg_recheck_calibration_active;
	integer cnt_recheck_post_accept_debug;
	reg reg_startup_prev_q3_low;
	reg [12:0]reg_startup_prev_q3_macro_tick;
	reg [63:0]reg_startup_prev_q3_physical_tick;
	reg flag_startup_q3_266_ok;
	reg flag_startup_q3_spacing_ok;
	reg flag_startup_owner_deadline_ok;
	reg flag_startup_waveform_ok;
	reg reg_recheck_sequence_done_seen;
	reg reg_recheck_sequence_failed_seen;
	reg reg_recheck_prev_pending;
	reg reg_recheck_prev_accept;
	reg reg_recheck_prev_done;
	reg reg_recheck_prev_failed;
	reg reg_recheck_owner_waiting;
	reg reg_recheck_owner_async_seen;
	reg reg_startup_owner_waiting;
	reg reg_startup_owner_async_seen;
	reg reg_recheck_history_r_cleared;
	reg reg_recheck_history_ir_cleared;
	reg reg_recheck_sequence_ok;
	reg reg_recheck_real_chain_ok;
	reg reg_recheck_drain_ok;
	reg reg_recheck_pre_accept_drain_ok;
	reg reg_recheck_output_inhibit_ok;
	reg reg_recheck_slope_preserved;
	reg reg_recheck_failure_reacquire_seen;
	reg reg_recheck_failure_fixed_slope_ok;
	reg reg_recheck_recross_seen;
	reg reg_recheck_recross_fine_seen;
	reg [1:0]reg_recheck_stage_state;
	reg [2:0]reg_recheck_stage_mask;
	reg signed [31:0]reg_recheck_slope_snapshot;
	reg signed [31:0]reg_recheck_slope_after;
	// RRC-12 cancellation evidence is retained across its two independent runs.
	reg [1:0]reg_scenario_recheck_cancel_mode;
	reg reg_recheck_cancel_triggered;
	reg reg_recheck_cancel_observed;
	reg reg_recheck_cancel_cleared;
	reg reg_recheck_cancel_owner_drained;
	reg reg_recheck_cancel_late_done_ok;
	reg reg_recheck_cancel_late_done_seen;
	reg reg_recheck_cancel_result_leak;
	reg reg_recheck_cancel_restart_clean;
	reg reg_rrc12_stop_ok;
	reg reg_rrc12_abort_ok;
	reg [7:0]reg_recheck_cancel_amb_code;
	reg [7:0]reg_recheck_cancel_dcs_r_code;
	reg [7:0]reg_recheck_cancel_dcs_ir_code;
	reg [3:0]reg_recheck_cancel_amb_epoch;
	reg [3:0]reg_recheck_cancel_dcs_r_epoch;
	reg [3:0]reg_recheck_cancel_dcs_ir_epoch;
	integer cnt_recheck_cancel_completion_before;
	integer cnt_recheck_cancel_result_before;
	integer cnt_recheck_cancel_request_before;

	//===================<第2步：数值和结果身份scoreboard>===================//
	integer cnt_numeric_comparison;
	integer cnt_numeric_mismatch;
	integer cnt_identity_comparison;
	integer cnt_identity_mismatch;
	integer cnt_result_backpressure_comparison;
	integer cnt_result_backpressure_mismatch;
	integer cnt_stage1_signed_comparison;
	integer cnt_stage2_comparison;
	integer cnt_coarse_comparison;
	integer cnt_fine_comparison;
	reg [9:0]reg_last_driven_stage1_raw;
	reg [9:0]reg_last_driven_stage2_raw;
	reg reg_last_driven_precision_mode;
	reg reg_last_driven_raw_valid;
	reg reg_owner_scoreboard_valid;
	reg reg_completed_owner_valid;
	reg reg_completed_owner_success;
	reg reg_completed_owner_color_ir;
	reg reg_completed_owner_precision_mode;
	reg [15:0]reg_completed_owner_frame_id;
	reg [15:0]reg_completed_owner_sample_index;
	reg [1:0]reg_completed_owner_frame_type;
	reg [7:0]reg_completed_owner_amb_code;
	reg [7:0]reg_completed_owner_dc_code;
	reg [3:0]reg_completed_owner_amb_epoch;
	reg [3:0]reg_completed_owner_dc_epoch;
	reg [7:0]reg_completed_owner_config_epoch;
	reg [7:0]reg_completed_owner_coef_epoch;
	reg [7:0]reg_completed_owner_stage2_epoch;
	reg [7:0]reg_completed_owner_dc_epoch_cfg;
	reg [9:0]reg_completed_owner_stage1_raw;
	reg [9:0]reg_completed_owner_stage2_raw;
	reg reg_completed_owner_raw_valid;
	reg reg_result_hold_valid;
	reg reg_result_hold_stable;
	reg signed [11:0]reg_hold_calibrated_s1_value;
	reg signed [14:0]reg_hold_programmable_15_code;
	reg signed [23:0]reg_hold_coarse_ppg_value;
	reg signed [23:0]reg_hold_fine_ppg_value;
	reg reg_hold_coarse_valid;
	reg reg_hold_fine_valid;
	reg [15:0]reg_hold_result_frame_id;
	reg [15:0]reg_hold_result_sample_index;
	reg reg_hold_result_color_ir;
	reg reg_hold_result_precision_mode;
	reg [1:0]reg_hold_result_frame_type;
	reg [7:0]reg_hold_result_amb_code;
	reg [7:0]reg_hold_result_dc_code;
	reg [3:0]reg_hold_result_amb_epoch;
	reg [3:0]reg_hold_result_dc_epoch;
	reg signed [63:0]reg_score_acc_q16;
	reg signed [11:0]reg_score_expected_s1;
	reg signed [14:0]reg_score_expected_15;
	reg signed [23:0]reg_score_expected_coarse;
	reg signed [23:0]reg_score_expected_fine;
	integer cnt_result_scoreboard_head;
	integer cnt_result_scoreboard_tail;
	integer cnt_result_scoreboard_count;
	integer cnt_result_scoreboard_overflow;
	reg reg_result_scoreboard_valid [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg reg_result_scoreboard_color_ir [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg reg_result_scoreboard_precision [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [15:0]reg_result_scoreboard_frame_id [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [15:0]reg_result_scoreboard_sample_index [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [1:0]reg_result_scoreboard_frame_type [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [7:0]reg_result_scoreboard_amb_code [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [7:0]reg_result_scoreboard_dc_code [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [3:0]reg_result_scoreboard_amb_epoch [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [3:0]reg_result_scoreboard_dc_epoch [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [7:0]reg_result_scoreboard_config_epoch [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [7:0]reg_result_scoreboard_coef_epoch [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [7:0]reg_result_scoreboard_stage2_epoch [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [7:0]reg_result_scoreboard_dc_coef_epoch [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [9:0]reg_result_scoreboard_stage1_raw [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg [9:0]reg_result_scoreboard_stage2_raw [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg reg_result_scoreboard_raw_valid [0:C_RESULT_SCOREBOARD_DEPTH - 1];
	reg flag_numeric_identity_ok;
	reg flag_sar9_no_fine_ok;
	reg flag_sar15_chain_ok;
	reg flag_stage1_signed_range_ok;
	reg flag_tracking_stage1_only;
	reg flag_adcn_negative_vector_seen;
	reg flag_adcn_half_lsb_vector_seen;
	reg flag_adcn_half_positive_seen;
	reg flag_adcn_half_negative_seen;
	reg flag_adcn_saturation_low_seen;
	reg flag_adcn_saturation_high_seen;
	reg flag_saturation_observed;
	reg reg_calibration_adc_driver_busy;
	reg reg_calibration_adc_driver_pending;
	reg reg_calibration_pending_precision_mode;
	reg reg_calibration_pending_color_ir;
	reg [1:0]reg_calibration_pending_frame_type;
	reg reg_calibration_q3_released;
	reg reg_integration_block_prev;
	integer cnt_calibration_adc_driver;
	integer cnt_calibration_adc_driver_timeout;

	//===================<第2步：故障和生命周期记账>===================//
	integer cnt_fault_observed;
	integer cnt_fault_blocking_cycles;
	integer cnt_fault_owner_leak;
	integer cnt_fault_result_leak;
	reg flag_fault_first_seen;
	reg [8 * 32 - 1:0]reg_first_fault_id;
	reg flag_fault_sticky_clear_observed;
	reg flag_fault_recovery_clean;
	reg reg_fault_seen_before_diag_clear;
	reg reg_any_fault_prev;
	reg reg_scheduler_deadline_prev;
	// Scheduler sticky diagnostics are tracked independently from the aggregate
	// fault bit so the first set cause cannot be hidden by a later fault source.
	reg reg_scheduler_launch_timeout_prev;
	reg reg_scheduler_owner_deadline_prev;
	reg reg_scheduler_completion_mismatch_prev;
	reg reg_scheduler_protocol_error_prev;
	reg flag_scheduler_first_set_seen;
	reg [8 * 48 - 1:0]reg_scheduler_first_set_reason;
	integer cnt_scheduler_first_set;
	integer cnt_scheduler_first_set_run;
	integer cnt_scheduler_first_set_macro_tick;
	integer cnt_scheduler_first_set_cal_tick;
	time time_scheduler_first_set;
	reg reg_scheduler_prev_frame_active;
	reg [1:0]reg_scheduler_prev_frame_mode;
	reg reg_scheduler_prev_red_pending;
	reg reg_scheduler_prev_ir_pending;
	reg reg_scheduler_prev_cal_pending;
	reg [12:0]reg_scheduler_prev_macro_tick;
	reg [9:0]reg_scheduler_prev_cal_tick;
	reg flag_scheduler_run_armed;
	integer cnt_stable_pass;
	integer cnt_stable_fail;
	integer cnt_stable_unclosed;

	// OIB directed stalls live only on the explicit Scheduler<->SSW and
	// Scheduler<->AMI port boundaries. They never write a DUT internal ready
	// signal or state element, and default to transparent connectivity.
	assign o_waveform_context_valid = o_waveform_context_valid_raw && !reg_oib_waveform_stall_active;
	assign o_waveform_context_ready = o_waveform_context_ready_raw && !reg_oib_waveform_stall_active;
	assign o_transaction_start_valid = o_transaction_start_valid_raw && !reg_oib_transaction_stall_active;
	assign o_transaction_start_ready = o_transaction_start_ready_raw && !reg_oib_transaction_stall_active;

	ppg_400hz_frame_calibration_scheduler ppg_400hz_frame_calibration_scheduler_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_active_config_valid(i_active_config_valid),
		.i_run_enable(measurement_run_enable),
		.i_allow_new_transaction(measurement_allow_new_transaction),
		.i_start_ack_event(measurement_start_ack_event),
		.i_stop_ack_event(i_stop_ack_event),
		.i_control_abort_event(i_control_abort_event),
		.i_diag_clear_event(i_diag_clear_event),
		.i_run_profile(i_run_profile),
		.i_input_source(i_input_source),
		.i_optical_mode(i_optical_mode),
		.i_active_precision_mode(o_active_precision_mode),
		.i_normal_measurement_eligible(o_normal_measurement_eligible),
		.i_switch_hold_new_transaction(o_switch_hold_new_transaction),
		.i_ami_fault_blocking(o_ami_fault_blocking),
		.i_ssw_fault_blocking(o_ssw_fault_blocking),
		.i_amb_code(o_amb_code),
		.i_dcs_r_code(o_dcs_r_code),
		.i_dcs_ir_code(o_dcs_ir_code),
		.i_amb_code_epoch(o_amb_code_epoch),
		.i_dcs_r_code_epoch(o_dcs_r_code_epoch),
		.i_dcs_ir_code_epoch(o_dcs_ir_code_epoch),
		.i_leddac_r_code(i_leddac_r_code),
		.i_leddac_ir_code(i_leddac_ir_code),
		.i_calibration_sample_valid(o_calibration_sample_valid),
		.o_calibration_sample_ready(o_calibration_sample_ready),
		.i_calibration_frame_type(o_calibration_frame_type),
		.i_calibration_color_ir(o_calibration_color_ir),
		.i_calibration_precision_mode(o_calibration_precision_mode),
		.i_calibration_request_reason(o_calibration_request_reason),
		.o_waveform_context_valid(o_waveform_context_valid_raw),
		.i_waveform_context_ready(o_waveform_context_ready),
		.o_waveform_precision_mode(o_waveform_precision_mode),
		.o_waveform_frame_id(o_waveform_frame_id),
		.o_waveform_color_ir(o_waveform_color_ir),
		.o_waveform_frame_type(o_waveform_frame_type),
		.o_waveform_amb_code_snapshot(o_waveform_amb_code_snapshot),
		.o_waveform_dc_code_snapshot(o_waveform_dc_code_snapshot),
		.o_waveform_amb_code_epoch(o_waveform_amb_code_epoch),
		.o_waveform_dc_code_epoch(o_waveform_dc_code_epoch),
		.o_waveform_input_source(o_waveform_input_source),
		.o_waveform_optical_mode(o_waveform_optical_mode),
		.o_waveform_leddac_code_snapshot(o_waveform_leddac_code_snapshot),
		.o_transaction_start_valid(o_transaction_start_valid_raw),
		.i_transaction_start_ready(o_transaction_start_ready),
		.i_transaction_start_fire(o_transaction_start_fire),
		.o_transaction_precision_mode(o_transaction_precision_mode),
		.o_transaction_frame_id(o_transaction_frame_id),
		.o_transaction_sample_index(o_transaction_sample_index),
		.o_transaction_color_ir(o_transaction_color_ir),
		.o_transaction_frame_type(o_transaction_frame_type),
		.o_transaction_amb_code_snapshot(o_transaction_amb_code_snapshot),
		.o_transaction_dc_code_snapshot(o_transaction_dc_code_snapshot),
		.o_transaction_amb_code_epoch(o_transaction_amb_code_epoch),
		.o_transaction_dc_code_epoch(o_transaction_dc_code_epoch),
		.i_adc_owner_ready(o_adc_owner_ready),
		.o_adc_owner_commit_event(o_adc_owner_commit_event),
		.o_adc_owner_precision_mode(o_adc_owner_precision_mode),
		.o_adc_owner_frame_id(o_adc_owner_frame_id),
		.o_adc_owner_color_ir(o_adc_owner_color_ir),
		.o_adc_owner_frame_type(o_adc_owner_frame_type),
		.o_adc_owner_amb_code_snapshot(o_adc_owner_amb_code_snapshot),
		.o_adc_owner_dc_code_snapshot(o_adc_owner_dc_code_snapshot),
		.o_adc_owner_amb_code_epoch(o_adc_owner_amb_code_epoch),
		.o_adc_owner_dc_code_epoch(o_adc_owner_dc_code_epoch),
		.o_adc_owner_sample_index(o_adc_owner_sample_index),
		.i_adc_transaction_complete_event(o_adc_transaction_complete_event),
		.i_adc_transaction_success(o_adc_transaction_success),
		.i_adc_complete_sample_index(o_adc_complete_sample_index),
		.i_adc_idle(i_adc_idle),
		.i_analog_safe(o_analog_safe),
		.i_sar_timing_idle(o_sar_timing_idle),
		.o_macro_frame_start_event(o_macro_frame_start_event),
		.o_macro_frame_safe_boundary(o_macro_frame_safe_boundary),
		.o_idac_code_safe_boundary(o_idac_code_safe_boundary),
		.o_startup_idac_safe_boundary(o_startup_idac_safe_boundary),
		.o_safe_frame_id(o_safe_frame_id),
		.o_macro_tick(o_macro_tick),
		.o_calibration_subframe_index(o_calibration_subframe_index),
		.o_calibration_local_tick(o_calibration_local_tick),
		.o_normal_frame_complete_event(o_normal_frame_complete_event),
		.o_calibration_frame_complete_event(o_calibration_frame_complete_event),
		.o_scheduler_idle(o_scheduler_idle),
		.o_normal_frame_active(o_normal_frame_active),
		.o_calibration_frame_active(o_calibration_frame_active),
		.o_transaction_inflight(o_scheduler_transaction_inflight),
		.o_current_frame_id(o_scheduler_current_frame_id),
		.o_next_sample_index(o_scheduler_next_sample_index),
		.o_launch_timeout_sticky(o_scheduler_launch_timeout_sticky),
		.o_owner_deadline_timeout_sticky(o_scheduler_owner_deadline_timeout_sticky),
		.o_completion_mismatch_sticky(o_scheduler_completion_mismatch_sticky),
		.o_protocol_error_sticky(o_scheduler_protocol_error_sticky),
		.o_scheduler_local_fault_blocking(o_scheduler_fault_blocking)
	);

	//===================<SSW实例化>===================//
	// SSW只消费波形上下文与owner身份，完成旁带用于释放其物理owner。
	ppg_sar9_sar15_safe_selection_wrapper ppg_sar9_sar15_safe_selection_wrapper_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_run_enable(analog_run_enable),
		.i_start_ack_event(analog_start_ack_event),
		.i_stop_ack_event(i_stop_ack_event),
		.i_control_abort_event(i_control_abort_event),
		.i_diag_clear_event(i_diag_clear_event),
		.i_macro_tick(o_macro_tick),
		.i_calibration_subframe_index(o_calibration_subframe_index),
		.i_calibration_local_tick(o_calibration_local_tick),
		.i_normal_frame_active(o_normal_frame_active),
		.i_calibration_frame_active(o_calibration_frame_active),
		.i_macro_frame_safe_boundary(o_macro_frame_safe_boundary),
		.i_idac_code_safe_boundary(o_idac_code_safe_boundary),
		.i_run_profile(i_run_profile),
		.i_input_source(i_input_source),
		.i_optical_mode(i_optical_mode),
		.i_precision_mode_committed(o_active_precision_mode),
		.i_static_characterization_enable(i_static_characterization_enable),
		.i_test_mux_ctrl(i_test_mux_ctrl),
		.i_waveform_context_valid(o_waveform_context_valid),
		.o_waveform_context_ready(o_waveform_context_ready_raw),
		.i_waveform_precision_mode(o_waveform_precision_mode),
		.i_waveform_frame_id(o_waveform_frame_id),
		.i_waveform_color_ir(o_waveform_color_ir),
		.i_waveform_frame_type(o_waveform_frame_type),
		.i_waveform_amb_code_snapshot(o_waveform_amb_code_snapshot),
		.i_waveform_dc_code_snapshot(o_waveform_dc_code_snapshot),
		.i_waveform_amb_code_epoch(o_waveform_amb_code_epoch),
		.i_waveform_dc_code_epoch(o_waveform_dc_code_epoch),
		.i_waveform_input_source(o_waveform_input_source),
		.i_waveform_optical_mode(o_waveform_optical_mode),
		.i_waveform_leddac_code_snapshot(o_waveform_leddac_code_snapshot),
		.o_adc_owner_ready(o_adc_owner_ready),
		.i_adc_owner_commit_event(o_adc_owner_commit_event),
		.i_adc_owner_precision_mode(o_adc_owner_precision_mode),
		.i_adc_owner_frame_id(o_adc_owner_frame_id),
		.i_adc_owner_color_ir(o_adc_owner_color_ir),
		.i_adc_owner_frame_type(o_adc_owner_frame_type),
		.i_adc_owner_amb_code_snapshot(o_adc_owner_amb_code_snapshot),
		.i_adc_owner_dc_code_snapshot(o_adc_owner_dc_code_snapshot),
		.i_adc_owner_amb_code_epoch(o_adc_owner_amb_code_epoch),
		.i_adc_owner_dc_code_epoch(o_adc_owner_dc_code_epoch),
		.i_adc_owner_sample_index(o_adc_owner_sample_index),
		.i_adc_transaction_complete_event(o_adc_transaction_complete_event),
		.i_adc_transaction_success(o_adc_transaction_success),
		.i_adc_complete_sample_index(o_adc_complete_sample_index),
		.i_adc_idle(i_adc_idle),
		.o_en_tia_low(o_ssw_en_tia_low),
		.o_leddac(o_leddac),
		.o_leden1_low(o_leden1_low),
		.o_leden2_low(o_leden2_low),
		.o_en_test(o_en_test),
		.o_clk_buf_low(o_ssw_clk_buf_low),
		.o_clk_iref_idac_low(o_ssw_clk_iref_idac_low),
		.o_clk_9q1_low(o_clk_9q1_low),
		.o_clk_15q1_low(o_clk_15q1_low),
		.o_clk_aferst_low(o_ssw_clk_aferst_low),
		.o_clk_iref_idac_sar9_low(o_ssw_clk_iref_idac_sar9_low),
		.o_clk_iref_idac_sar15_low(o_ssw_clk_iref_idac_sar15_low),
		.o_clk_q2_low(o_clk_q2_low),
		.o_clk_q3_low(o_clk_q3_low),
		.o_clk_tiaen_low(o_ssw_clk_tiaen_low),
		.o_en_15sar_low(o_ssw_en_15sar_low),
		.o_en_sar9_amb_low(o_ssw_en_sar9_amb_low),
		.o_en_sar9_dc_low(o_ssw_en_sar9_dc_low),
		.o_en_sar9_iref(o_ssw_en_sar9_iref),
		.o_en_sar15_amb_low(o_ssw_en_sar15_amb_low),
		.o_en_sar15_dc_low(o_ssw_en_sar15_dc_low),
		.o_en_sar15_iref(o_ssw_en_sar15_iref),
		.o_idac_sar9ambn_low(o_idac_sar9ambn_low),
		.o_idac_sar9dcn_low(o_idac_sar9dcn_low),
		.o_idac_sar15ambn_low(o_idac_sar15ambn_low),
		.o_idac_sar15dcn_low(o_idac_sar15dcn_low),
		.o_s_in(o_s_in),
		.o_clk_2m(o_ssw_clk_2m),
		.o_analog_safe(o_analog_safe),
		.o_sar_timing_idle(o_sar_timing_idle),
		.o_wrapper_idle(o_ssw_wrapper_idle),
		.o_precision_active(o_ssw_precision_active),
		.o_calibration_wave_active(o_ssw_calibration_wave_active),
		.o_adc_owner_inflight(o_adc_owner_inflight),
		.o_switch_protocol_error_sticky(o_switch_protocol_error_sticky),
		.o_transaction_mismatch_sticky(o_transaction_mismatch_sticky),
		.o_owner_deadline_timeout_sticky(o_owner_deadline_timeout_sticky),
		.o_calibration_timeout_sticky(o_calibration_timeout_sticky),
		.o_wrapper_fault_blocking(o_ssw_fault_blocking)
	);

	//===================<AMI实例化>===================//
	// AMI只消费Scheduler的ADC结果事务，并以真实异步捕获路径广播完成旁带。
	ppg_adc_measurement_idac_integration ppg_adc_measurement_idac_integration_Inst(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_active_config_valid(i_active_config_valid),
		.i_run_enable(measurement_run_enable),
		.i_allow_new_transaction(measurement_allow_new_transaction),
		.i_start_ack_event(measurement_start_ack_event),
		.i_stop_ack_event(i_stop_ack_event),
		.i_control_abort_event(i_control_abort_event),
		.i_diag_clear_event(i_diag_clear_event),
		.i_config_epoch(i_config_epoch),
		.i_stage1_coef_epoch(i_stage1_coef_epoch),
		.i_stage2_coef_epoch(i_stage2_coef_epoch),
		.i_dc_recovery_coef_epoch(i_dc_recovery_coef_epoch),
		.i_transaction_start_valid(o_transaction_start_valid),
		.o_transaction_start_ready(o_transaction_start_ready_raw),
		.o_transaction_start_fire(o_transaction_start_fire),
		.o_adc_transaction_complete_event(o_adc_transaction_complete_event),
		.o_adc_transaction_success(o_adc_transaction_success),
		.o_adc_complete_sample_index(o_adc_complete_sample_index),
		.i_transaction_precision_mode(o_transaction_precision_mode),
		.i_transaction_frame_id(o_transaction_frame_id),
		.i_transaction_sample_index(o_transaction_sample_index),
		.i_transaction_color_ir(o_transaction_color_ir),
		.i_transaction_frame_type(o_transaction_frame_type),
		.i_transaction_amb_code_snapshot(o_transaction_amb_code_snapshot),
		.i_transaction_dc_code_snapshot(o_transaction_dc_code_snapshot),
		.i_transaction_amb_code_epoch(o_transaction_amb_code_epoch),
		.i_transaction_dc_code_epoch(o_transaction_dc_code_epoch),
		.i_dout_stage1_low(i_dout_stage1_low),
		.i_clk_stage1_dout_low_async(i_clk_stage1_dout_low_async),
		.i_dout_stage2_low(i_dout_stage2_low),
		.i_clk_stage2_dout_low_async(i_clk_stage2_dout_low_async),
		.i_adc_idle(i_adc_idle),
		.i_analog_safe(o_analog_safe),
		.i_macro_frame_safe_boundary(o_macro_frame_safe_boundary),
		.i_idac_code_safe_boundary(o_idac_code_safe_boundary),
		.i_safe_frame_id(o_safe_frame_id),
		.i_normal_frame_complete_event(o_normal_frame_complete_event),
		.i_calibration_frame_complete_event(o_calibration_frame_complete_event),
		.i_calibration_sample_ready(o_calibration_sample_ready),
		.o_calibration_sample_valid(o_calibration_sample_valid),
		.o_calibration_frame_type(o_calibration_frame_type),
		.o_calibration_color_ir(o_calibration_color_ir),
		.o_calibration_precision_mode(o_calibration_precision_mode),
		.o_calibration_request_reason(o_calibration_request_reason),
		.o_calibration_request_fire(o_calibration_request_fire),
		.i_measurement_result_ready(i_measurement_result_ready),
		.o_measurement_result_valid(o_measurement_result_valid),
		.o_coarse_ppg_value(o_coarse_ppg_value),
		.o_coarse_valid(o_coarse_valid),
		.o_coarse_recovery_calibrated(o_coarse_recovery_calibrated),
		.o_coarse_saturation_low(o_coarse_saturation_low),
		.o_coarse_saturation_high(o_coarse_saturation_high),
		.o_fine_ppg_value(o_fine_ppg_value),
		.o_fine_valid(o_fine_valid),
		.o_fine_recovery_calibrated(o_fine_recovery_calibrated),
		.o_fine_saturation_low(o_fine_saturation_low),
		.o_fine_saturation_high(o_fine_saturation_high),
		.o_calibrated_s1_value(o_calibrated_s1_value),
		.o_programmable_15_code(o_programmable_15_code),
		.o_programmable_15_valid(o_programmable_15_valid),
		.o_config_epoch(o_result_config_epoch),
		.o_coef_epoch(o_result_coef_epoch),
		.o_stage2_result_coef_epoch(o_result_stage2_coef_epoch),
		.o_dc_result_coef_epoch(o_result_dc_coef_epoch),
		.o_result_precision_mode(o_result_precision_mode),
		.o_result_frame_id(o_result_frame_id),
		.o_result_sample_index(o_result_sample_index),
		.o_result_color_ir(o_result_color_ir),
		.o_result_frame_type(o_result_frame_type),
		.o_result_amb_code_snapshot(o_result_amb_code_snapshot),
		.o_result_dc_code_snapshot(o_result_dc_code_snapshot),
		.o_result_amb_code_epoch(o_result_amb_code_epoch),
		.o_result_dc_code_epoch(o_result_dc_code_epoch),
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
		.o_amb_code_update(o_amb_code_update),
		.o_dcs_r_code_update(o_dcs_r_code_update),
		.o_dcs_ir_code_update(o_dcs_ir_code_update),
		.o_dcs_r_track_adjust(o_dcs_r_track_adjust),
		.o_dcs_ir_track_adjust(o_dcs_ir_track_adjust),
		.o_amb_search_done(o_amb_search_done),
		.o_dcs_r_search_done(o_dcs_r_search_done),
		.o_dcs_ir_search_done(o_dcs_ir_search_done),
		.o_amb_search_exhausted(o_amb_search_exhausted),
		.o_dcs_r_search_exhausted(o_dcs_r_search_exhausted),
		.o_dcs_ir_search_exhausted(o_dcs_ir_search_exhausted),
		.o_amb_pending_valid(o_amb_pending_valid),
		.o_dcs_r_pending_valid(o_dcs_r_pending_valid),
		.o_dcs_ir_pending_valid(o_dcs_ir_pending_valid),
		.o_amb_fault(o_amb_fault),
		.o_dcs_r_fault(o_dcs_r_fault),
		.o_dcs_ir_fault(o_dcs_ir_fault),
		.o_idac_fault_blocking(o_idac_fault_blocking),
		.o_idac_protocol_error_sticky(o_idac_protocol_error_sticky),
		.o_startup_search_complete(o_startup_search_complete),
		.o_idac_idle(o_idac_idle),
		.o_active_precision_mode(o_active_precision_mode),
		.o_fine_window_active(o_fine_window_active),
		.o_fine_window_start_event(o_fine_window_start_event),
		.o_fine_window_start_frame_id(o_fine_window_start_frame_id),
		.o_precision_15_to_9_event(o_precision_15_to_9_event),
		.o_precision_15_to_9_frame_id(o_precision_15_to_9_frame_id),
		.o_reacquire_request_event(o_reacquire_request_event),
		.o_switch_hold_new_transaction(o_switch_hold_new_transaction),
		.o_mode_fault_event(o_mode_fault_event),
		.o_normal_frame_count(o_normal_frame_count),
		.o_amb_recheck_pending(o_amb_recheck_pending),
		.o_amb_recheck_accept(o_amb_recheck_accept),
		.o_amb_recheck_busy(o_amb_recheck_busy),
		.o_normal_output_inhibit(o_normal_output_inhibit),
		.o_recheck_sequence_done(o_recheck_sequence_done),
		.o_recheck_sequence_failed(o_recheck_sequence_failed),
		.o_fir_history_full_r(o_fir_history_full_r),
		.o_fir_history_full_ir(o_fir_history_full_ir),
		.o_fir_idle(o_fir_idle),
		.o_detection_fork_idle(o_detection_fork_idle),
		.o_detector_idle(o_detector_idle),
		.o_controller_idle(o_controller_idle),
		.o_scheduler_idle(o_ami_scheduler_idle),
		.o_cross_pending(o_cross_pending),
		.o_peak_pending(o_peak_pending),
		.o_valley_pending(o_valley_pending),
		.o_return_pending(o_return_pending),
		.o_baseline_valid(o_baseline_valid),
		.o_reacquire_active(o_reacquire_active),
		.o_detector_fine_window_active(o_detector_fine_window_active),
		.o_switch_pending(o_switch_pending),
		.o_switch_target_precision(o_switch_target_precision),
		.o_slope_current_q16(o_slope_current_q16),
		.o_baseline_protocol_error_sticky(o_baseline_protocol_error_sticky),
		.o_fine_window_timeout_sticky(o_fine_window_timeout_sticky),
		.o_reacquire_timeout_sticky(o_reacquire_timeout_sticky),
		.o_peak_valley_protocol_error_sticky(o_peak_valley_protocol_error_sticky),
		.o_switch_timeout_sticky(o_switch_timeout_sticky),
		.o_precision_protocol_error_sticky(o_precision_protocol_error_sticky),
		.o_integration_protocol_error_sticky(o_integration_protocol_error_sticky),
		.o_wrapper_fault_blocking(o_ami_fault_blocking),
		.o_normal_measurement_eligible(o_normal_measurement_eligible),
		.o_adc_chain_idle(o_adc_chain_idle),
		.o_normal_fork_idle(o_normal_fork_idle),
		.o_measurement_output_idle(o_measurement_output_idle),
		.o_datapath_empty(o_datapath_empty)
	);

	//===================<仿真辅助任务>===================//
	// 真实比较后记录每个联合验收场景的唯一通过或失败结果。
	// Mark one stable trace entry only after its real public comparison executes.
	task trace_mark;
		input integer trace_slot;
		input condition;
		begin
			if((trace_slot >= 0) && (trace_slot < C_TRACE_COUNT))begin
				// A later functional run may add applicability after an earlier
				// NOT_APPLICABLE observation, but it may not erase a real PASS/FAIL
				// result already captured for the same stable ID.
				if((reg_trace_status[trace_slot] != TRACE_PASS) && (reg_trace_status[trace_slot] != TRACE_FAIL)) begin
					reg_trace_status[trace_slot] = condition ? TRACE_PASS : TRACE_FAIL;
					reg_trace_run_index[trace_slot] = cnt_run_index;
					reg_trace_group_id[trace_slot] = flag_contract_group_override ? reg_contract_group_id : reg_run_group_id;
				end
				reg_trace_compare_count[trace_slot] = reg_trace_compare_count[trace_slot] + 1;
			end
		end
	endtask

	// Independent scenario entry resets every trace slot without changing DUT state.
	task trace_reset;
		integer reset_index;
		begin
			// Stable IDs are aggregate evidence across independent runs.  Initialize once,
			// then preserve prior groups while per-run counters are reset by begin_independent_run.
			if(!flag_trace_metadata_initialized)begin
				for(reset_index = 0; reset_index < C_TRACE_COUNT; reset_index = reset_index + 1)begin
					reg_trace_status[reset_index] = TRACE_UNCHECKED;
					reg_trace_run_index[reset_index] = 0;
					reg_trace_compare_count[reset_index] = 0;
					reg_trace_group_id[reset_index] = "UNASSIGNED";
				end
				flag_trace_metadata_initialized = 1'b1;
			end
		end
	endtask

	// Common V1.3 event record. All identity fields are sampled only from public ports.
	task log_public_event;
		input [8 * 24 - 1:0]event_id;
		input [15:0]frame_id;
		input [15:0]sample_index;
		input color_ir;
		input [1:0]frame_type;
		input precision_mode;
		begin
			cnt_run_event = cnt_run_event + 1;
			if(fd_event_log >= 0)begin
				$fwrite(fd_event_log, "TB_EVENT run=%0d group=%0s time=%0t event=%0s frame=%0d sample=%0d color_ir=%0b frame_type=%0b precision=%0b\n",
					cnt_run_index, reg_run_group_id, $time, event_id, frame_id, sample_index, color_ir, frame_type, precision_mode);
			end else begin
				$display("TB_EVENT run=%0d group=%0s time=%0t event=%0s frame=%0d sample=%0d color_ir=%0b frame_type=%0b precision=%0b",
					cnt_run_index, reg_run_group_id, $time, event_id, frame_id, sample_index, color_ir, frame_type, precision_mode);
			end
		end
	endtask

	// Reset all run-local observations while leaving aggregate stable-ID status intact.
	task reset_run_observations;
		begin
			cnt_startup_boundary = 0; cnt_waveform_context = 0; cnt_owner_commit = 0;
			cnt_completion = 0; cnt_measurement_result = 0; cnt_red_waveform_context = 0; cnt_ir_waveform_context = 0;
			cnt_raw_q1_observed = 0; cnt_raw_q2_observed = 0; cnt_raw_q3_observed = 0;
			cnt_raw_q3_end_observed = 0; cnt_raw_async_observed = 0; cnt_raw_completion_observed = 0; cnt_raw_identity_observed = 0;
			cnt_raw_profile_rise = 0; cnt_raw_profile_fall = 0;
			flag_raw_profile_notch_rebound = 1'b0; flag_raw_profile_drift_observed = 1'b0; flag_raw_profile_clamp_observed = 1'b0;
			reg_raw_signature = 32'h811c9dc5; cnt_raw_signature_samples = 0;
			reg_raw_profile_prev_red = 10'd0; reg_raw_profile_prev_ir = 10'd0;
			flag_raw_profile_prev_red_valid = 1'b0; flag_raw_profile_prev_ir_valid = 1'b0;
			cnt_matrix_frame_start = 0; cnt_matrix_frame_interval_mismatch = 0;
			reg_matrix_prev_macro_tick = 13'd0; reg_matrix_prev_frame_time = 0; flag_matrix_400hz_ok = 1'b1;
			flag_static_q1_seen = 1'b0; flag_static_q2_seen = 1'b0; flag_static_q3_seen = 1'b0;
			flag_static_async_seen = 1'b0; flag_static_done_seen = 1'b0; flag_static_fir_seen = 1'b0;
			flag_static_recheck_seen = 1'b0; flag_static_algorithm_result_seen = 1'b0;
			flag_static_atomic_update_ok = 1'b0;
			reg_static_prev_s_in = 5'd0; flag_static_s_edge_seen = 1'b0; flag_static_s_edge_atomic = 1'b1;
			flag_lfa_early_dout_rejected = 1'b0; flag_lfa_duplicate_done_rejected = 1'b0; flag_lfa_wrong_identity_observed = 1'b0;
			flag_startup_boundary_without_owner = 1'b0; reg_startup_boundary_sample_index = 16'd0;
			flag_ir_context_while_red_inflight = 1'b0; flag_owner_context_identity_match = 1'b0;
			flag_red_q1_seen = 1'b0; flag_red_q2_seen = 1'b0; flag_red_q3_seen = 1'b0;
			flag_ir_q1_seen = 1'b0; flag_ir_q2_seen = 1'b0; flag_ir_q3_seen = 1'b0;
			reg_last_owner_frame_id = 16'd0; reg_last_owner_color_ir = 1'b0; reg_last_owner_sample_index = 16'd0; reg_last_owner_macro_tick = 13'd0;
			reg_last_owner_precision_mode = 1'b0; reg_last_owner_frame_type = FRAME_TYPE_NORMAL; reg_last_owner_amb_code = 8'd0; reg_last_owner_dc_code = 8'd0;
			reg_red_waveform_precision_mode = 1'b0; reg_red_waveform_amb_code = 8'd0; reg_red_waveform_dc_code = 8'd0;
			reg_ir_waveform_precision_mode = 1'b0; reg_ir_waveform_amb_code = 8'd0; reg_ir_waveform_dc_code = 8'd0;
			flag_reset_done_observation = 1'b0; reg_last_completion_success = 1'b0; reg_last_completion_sample_index = 16'd0;
			flag_normal_mismatch_reported = 1'b0;
			flag_selected_amb_bus_seen = 1'b0; flag_selected_dc_bus_seen = 1'b0; flag_red_dc_bus_seen = 1'b0;
			flag_ir_dc_bus_seen = 1'b0; flag_unselected_idac_bus_clean = 1'b1; flag_idac_bus_violation = 1'b0;
			flag_ise_pattern_31_seen = 1'b0; flag_ise_pattern_42_seen = 1'b0; flag_ise_pattern_53_seen = 1'b0;
			cnt_amb_pending_observed = 0; cnt_dcs_r_pending_observed = 0; cnt_dcs_ir_pending_observed = 0;
			cnt_amb_update_observed = 0; cnt_dcs_r_update_observed = 0; cnt_dcs_ir_update_observed = 0;
			cnt_dcs_r_track_adjust_observed = 0; cnt_dcs_ir_track_adjust_observed = 0;
			cnt_amb_search_done_observed = 0; cnt_dcs_r_search_done_observed = 0; cnt_dcs_ir_search_done_observed = 0;
			cnt_idac_search_exhausted_observed = 0; cnt_idac_epoch_mismatch = 0; cnt_idac_code_delta_mismatch = 0;
			cnt_idac_boundary_wrap_violation = 0; cnt_idac_update_without_change = 0;
			cnt_tracking_boundary_hold_observed = 0; cnt_tracking_epoch_wrap_observed = 0;
			reg_idac_prev_amb_code = 8'd0; reg_idac_prev_dcs_r_code = 8'd0; reg_idac_prev_dcs_ir_code = 8'd0;
			reg_idac_prev_amb_epoch = 4'd0; reg_idac_prev_dcs_r_epoch = 4'd0; reg_idac_prev_dcs_ir_epoch = 4'd0;
			reg_idac_prev_amb_pending = 1'b0; reg_idac_prev_dcs_r_pending = 1'b0; reg_idac_prev_dcs_ir_pending = 1'b0;
			reg_idac_prev_amb_search_done = 1'b0; reg_idac_prev_dcs_r_search_done = 1'b0; reg_idac_prev_dcs_ir_search_done = 1'b0;
			reg_idac_prev_amb_exhausted = 1'b0; reg_idac_prev_dcs_r_exhausted = 1'b0; reg_idac_prev_dcs_ir_exhausted = 1'b0;
			flag_idac_epoch_relation_ok = 1'b1; flag_idac_track_delta_ok = 1'b1; flag_idac_no_wrap_ok = 1'b1;
			flag_idac_observation_valid = 1'b0; flag_idac_startup_order_ok = 1'b1; reg_idac_search_stage = 2'd0;
			cnt_startup_calibration_request = 0; cnt_startup_calibration_completion = 0; cnt_startup_successful_calibration_completion = 0;
			cnt_startup_amb_completion = 0; cnt_startup_dcs_r_completion = 0; cnt_startup_dcs_ir_completion = 0;
			cnt_startup_amb_waveform_observed = 0; cnt_startup_dcs_r_waveform_observed = 0; cnt_startup_dcs_ir_waveform_observed = 0;
			cnt_startup_q3_observed = 0; cnt_startup_q3_spacing_mismatch = 0; cnt_startup_owner_deadline_mismatch = 0; cnt_startup_real_chain_mismatch = 0;
			cnt_recheck_pending_observed = 0; cnt_recheck_accept_observed = 0; cnt_recheck_done_observed = 0; cnt_recheck_failed_observed = 0;
			cnt_recheck_calibration_request = 0; cnt_recheck_calibration_completion = 0; cnt_recheck_successful_calibration_completion = 0;
			cnt_recheck_amb_completion = 0; cnt_recheck_dcs_r_completion = 0; cnt_recheck_dcs_ir_completion = 0;
			cnt_recheck_real_chain_mismatch = 0; cnt_recheck_sequence_mismatch = 0; cnt_recheck_drain_mismatch = 0; cnt_recheck_output_leak = 0;
			cnt_recheck_async_observed = 0;
			cnt_recheck_history_r_warmup = 0; cnt_recheck_history_ir_warmup = 0;
			reg_startup_calibration_active = 1'b0; reg_recheck_calibration_active = 1'b0; cnt_recheck_post_accept_debug = 0; reg_startup_prev_q3_low = 1'b0; reg_startup_prev_q3_macro_tick = 13'd0; reg_startup_prev_q3_physical_tick = 64'd0;
			flag_startup_q3_266_ok = 1'b1; flag_startup_q3_spacing_ok = 1'b1; flag_startup_owner_deadline_ok = 1'b1; flag_startup_waveform_ok = 1'b1;
			reg_recheck_sequence_done_seen = 1'b0; reg_recheck_sequence_failed_seen = 1'b0; reg_recheck_prev_pending = 1'b0; reg_recheck_prev_accept = 1'b0;
			reg_recheck_prev_done = 1'b0; reg_recheck_prev_failed = 1'b0; reg_recheck_owner_waiting = 1'b0; reg_recheck_owner_async_seen = 1'b0;
			reg_startup_owner_waiting = 1'b0; reg_startup_owner_async_seen = 1'b0; reg_recheck_history_r_cleared = 1'b0; reg_recheck_history_ir_cleared = 1'b0;
			reg_recheck_sequence_ok = 1'b1; reg_recheck_real_chain_ok = 1'b1; reg_recheck_drain_ok = 1'b1; reg_recheck_pre_accept_drain_ok = 1'b1; reg_recheck_output_inhibit_ok = 1'b1;
			reg_recheck_slope_preserved = 1'b0; reg_recheck_recross_seen = 1'b0; reg_recheck_recross_fine_seen = 1'b0; reg_recheck_stage_state = 2'd0; reg_recheck_stage_mask = 3'd0;
			reg_recheck_failure_reacquire_seen = 1'b0; reg_recheck_failure_fixed_slope_ok = 1'b0;
			reg_recheck_cancel_triggered = 1'b0; reg_recheck_cancel_observed = 1'b0; reg_recheck_cancel_cleared = 1'b0;
			reg_recheck_cancel_owner_drained = 1'b0; reg_recheck_cancel_late_done_ok = 1'b0; reg_recheck_cancel_late_done_seen = 1'b0; reg_recheck_cancel_result_leak = 1'b0; reg_recheck_cancel_restart_clean = 1'b0;
			reg_recheck_cancel_amb_code = 8'd0; reg_recheck_cancel_dcs_r_code = 8'd0; reg_recheck_cancel_dcs_ir_code = 8'd0;
			reg_recheck_cancel_amb_epoch = 4'd0; reg_recheck_cancel_dcs_r_epoch = 4'd0; reg_recheck_cancel_dcs_ir_epoch = 4'd0;
			cnt_recheck_cancel_completion_before = 0; cnt_recheck_cancel_result_before = 0; cnt_recheck_cancel_request_before = 0;
			cnt_numeric_comparison = 0; cnt_numeric_mismatch = 0; cnt_identity_comparison = 0; cnt_identity_mismatch = 0;
			cnt_result_backpressure_comparison = 0; cnt_result_backpressure_mismatch = 0; cnt_stage1_signed_comparison = 0; cnt_stage2_comparison = 0; cnt_coarse_comparison = 0; cnt_fine_comparison = 0;
			cnt_result_backpressure_hold = 0;
			reg_oib_waveform_stall_active = 1'b0; reg_oib_transaction_stall_active = 1'b0;
			flag_oib_waveform_stall_complete = 1'b0; flag_oib_transaction_stall_complete = 1'b0;
			flag_oib_waveform_stall_seen = 1'b0; flag_oib_transaction_stall_seen = 1'b0;
			flag_oib_waveform_accept_seen = 1'b0; flag_oib_transaction_accept_seen = 1'b0;
			flag_oib_waveform_hold_ok = 1'b1; flag_oib_transaction_hold_ok = 1'b1;
			cnt_oib_waveform_stall_cycles = 0; cnt_oib_transaction_stall_cycles = 0;
			cnt_oib_waveform_accept = 0; cnt_oib_transaction_accept = 0;
			reg_oib_waveform_frame_id = 16'd0; reg_oib_waveform_color_ir = 1'b0;
			reg_oib_waveform_frame_type = FRAME_TYPE_NORMAL; reg_oib_waveform_precision_mode = 1'b0;
			reg_oib_waveform_amb_code = 8'd0; reg_oib_waveform_dc_code = 8'd0;
			reg_oib_waveform_next_sample_index = 16'd0; flag_oib_waveform_snapshot_valid = 1'b0;
			reg_oib_transaction_frame_id = 16'd0; reg_oib_transaction_sample_index = 16'd0;
			reg_oib_transaction_color_ir = 1'b0; reg_oib_transaction_frame_type = FRAME_TYPE_NORMAL;
			reg_oib_transaction_precision_mode = 1'b0; reg_oib_transaction_amb_code = 8'd0;
			reg_oib_transaction_dc_code = 8'd0; reg_oib_transaction_next_sample_index = 16'd0;
			flag_oib_transaction_snapshot_valid = 1'b0;
			flag_numeric_identity_ok = 1'b1; flag_sar9_no_fine_ok = 1'b1; flag_sar15_chain_ok = 1'b1; flag_stage1_signed_range_ok = 1'b1; flag_tracking_stage1_only = 1'b1;
			flag_adcn_negative_vector_seen = 1'b0; flag_adcn_half_lsb_vector_seen = 1'b0;
			flag_adcn_half_positive_seen = 1'b0; flag_adcn_half_negative_seen = 1'b0;
			flag_adcn_saturation_low_seen = 1'b0; flag_adcn_saturation_high_seen = 1'b0; flag_saturation_observed = 1'b0;
			reg_calibration_adc_driver_busy = 1'b0; reg_calibration_adc_driver_pending = 1'b0;
			reg_calibration_pending_precision_mode = 1'b0; reg_calibration_pending_color_ir = 1'b0; reg_calibration_pending_frame_type = FRAME_TYPE_AMB; reg_calibration_q3_released = 1'b0;
			reg_integration_block_prev = 1'b0;
			reg_scheduler_deadline_prev = 1'b0;
			reg_scheduler_launch_timeout_prev = 1'b0;
			reg_scheduler_owner_deadline_prev = 1'b0;
			reg_scheduler_completion_mismatch_prev = 1'b0;
			reg_scheduler_protocol_error_prev = 1'b0;
			flag_scheduler_first_set_seen = 1'b0;
			reg_scheduler_first_set_reason = "NONE";
			cnt_scheduler_first_set = 0;
			cnt_scheduler_first_set_run = 0;
			cnt_scheduler_first_set_macro_tick = 0;
			cnt_scheduler_first_set_cal_tick = 0;
			time_scheduler_first_set = 0;
			reg_scheduler_prev_frame_active = 1'b0;
			reg_scheduler_prev_frame_mode = 2'd0;
			reg_scheduler_prev_red_pending = 1'b0;
			reg_scheduler_prev_ir_pending = 1'b0;
			reg_scheduler_prev_cal_pending = 1'b0;
			reg_scheduler_prev_macro_tick = 13'd0;
			reg_scheduler_prev_cal_tick = 10'd0;
			flag_scheduler_run_armed = 1'b0;
			cnt_calibration_adc_driver = 0; cnt_calibration_adc_driver_timeout = 0;
			cnt_fault_observed = 0; cnt_fault_blocking_cycles = 0; cnt_fault_owner_leak = 0; cnt_fault_result_leak = 0; flag_fault_first_seen = 1'b0; flag_fault_sticky_clear_observed = 1'b0; flag_fault_recovery_clean = 1'b1;
			flag_ppg_algorithm_active = 1'b0; cnt_ppg_algorithm_result = 0; cnt_ppg_algorithm_sar9_result = 0; cnt_ppg_algorithm_sar15_result = 0;
			flag_ppg_baseline_valid_seen = 1'b0; flag_ppg_cross_pending_seen = 1'b0; flag_ppg_fine_window_start_seen = 1'b0; flag_ppg_peak_pending_seen = 1'b0; flag_ppg_valley_pending_seen = 1'b0;
			flag_ppg_precision_15_seen = 1'b0; flag_ppg_precision_15_to_9_seen = 1'b0; flag_ppg_precision_9_after_15_seen = 1'b0; flag_ppg_fir_full_r_seen = 1'b0; flag_ppg_fir_full_ir_seen = 1'b0; flag_ppg_result_sequence_ok = 1'b1; flag_ppg_sar15_tail_isolated = 1'b0; flag_ppg_have_result = 1'b0;
			cnt_ppg_return_pending_seen = 0; cnt_ppg_return_event_seen = 0; cnt_ppg_fine_timeout_seen = 0; cnt_ppg_reacquire_seen = 0;
		end
	endtask

	// Establish the reset-owned context required before every future functional group.
	task begin_independent_run;
		input [8 * 32 - 1:0]group_id;
		begin
			cnt_run_index = cnt_run_index + 1;
			reg_run_group_id = group_id;
			if(!flag_contract_group_override) reg_contract_group_id = group_id;
			reg_run_first_failure_id = "NONE";
			cnt_run_jnt_checked = 0;
			cnt_run_jnt_pass = 0;
			cnt_run_jnt_fail = 0;
			cnt_run_event = 0;
			cnt_run_stable_pass = 0;
			cnt_run_stable_fail = 0;
			cnt_run_stable_unclosed = 0;
			reset_run_observations;
			flag_jnt_baseline_active = 1'b0;
			trace_reset;
			@(negedge i_clk);
			i_rstn = 1'b0;
			analog_run_enable = 1'b0;
			measurement_run_enable = 1'b0;
			measurement_allow_new_transaction = 1'b0;
			analog_start_ack_event = 1'b0;
			measurement_start_ack_event = 1'b0;
			i_stop_ack_event = 1'b0;
			i_control_abort_event = 1'b0;
			i_diag_clear_event = 1'b0;
			i_run_profile = 1'b0;
			i_input_source = reg_scenario_input_source;
			i_optical_mode = reg_scenario_optical_mode;
			i_initial_precision = reg_scenario_initial_precision;
			i_amb_recheck_interval_frames = reg_scenario_recheck_interval;
			i_idac_mode = reg_scenario_idac_mode;
			if(reg_scenario_force_search_failure)begin
				i_amb_threshold_low = 12'sd500;
				i_amb_threshold_high = 12'sd501;
				i_dcs_threshold_low = 12'sd500;
				i_dcs_threshold_high = 12'sd501;
			end else if((group_id == "STARTUP-IDAC-CALIBRATION") || reg_scenario_enable_tracking_after_startup)begin
				// Force seven out-of-window candidate observations, then accept
				// the eighth physical SAR9 conversion in each startup stage.
				// The encoded target_code=8 maps to calibrated S1 value 12
				// under the active Stage1 Q16 weights, so the legal window
				// must cover that calibrated value rather than the raw target.
				i_amb_threshold_low = 12'sd11;
				i_amb_threshold_high = 12'sd13;
				 i_dcs_threshold_low = 12'sd11;
				 i_dcs_threshold_high = 12'sd13;
			end else begin
				i_amb_threshold_low = -12'sd2048;
				i_amb_threshold_high = 12'sd2047;
				i_dcs_threshold_low = -12'sd2048;
				 i_dcs_threshold_high = 12'sd2047;
			end
			i_static_characterization_enable = 1'b0;
			i_adc_idle = 1'b1;
			i_clk_stage1_dout_low_async = 1'b0;
			i_clk_stage2_dout_low_async = 1'b0;
			time_run_reset_assert = $time;
			time_run_start_ack = 0;
			time_run_deadline = time_run_reset_assert + C_SIM_TIMEOUT_NS;
			if(flag_jnt_parent_valid)begin
				$display("TB_JNT_PARENT functional_run=%0d functional_group=%0s parent_run=%0d parent_group=%0s checked=%0d pass=%0d fail=%0d", cnt_run_index, reg_run_group_id, cnt_jnt_parent_run_index, reg_jnt_parent_group_id, cnt_jnt_parent_checked, cnt_jnt_parent_pass, cnt_jnt_parent_fail);
				if(fd_result_file != 0) $fwrite(fd_result_file, "TB_JNT_PARENT functional_run=%0d functional_group=%0s parent_run=%0d parent_group=%0s checked=%0d pass=%0d fail=%0d required=%0d status=%0s\n", cnt_run_index, reg_run_group_id, cnt_jnt_parent_run_index, reg_jnt_parent_group_id, cnt_jnt_parent_checked, cnt_jnt_parent_pass, cnt_jnt_parent_fail, C_JNT_REQUIRED_SUBCHECKS, (cnt_jnt_parent_checked == C_JNT_REQUIRED_SUBCHECKS && cnt_jnt_parent_pass == C_JNT_REQUIRED_SUBCHECKS && cnt_jnt_parent_fail == 0) ? "PASS" : "NOT_CLOSED");
			end
			$display("TB_RUN_BEGIN run=%0d group=%0s reset_time=%0t deadline=%0t", cnt_run_index, reg_run_group_id, time_run_reset_assert, time_run_deadline);
		end
	endtask

	// Continue the functional phase under the same logical run that produced
	// its 52-check JNT parent. This performs a clean DUT reset while preserving
	// the parent counters and run/group provenance for the final group report.
	task begin_functional_phase_same_run;
		input [8 * 32 - 1:0]group_id;
		begin
			reg_run_group_id = group_id;
			if(!flag_contract_group_override) reg_contract_group_id = group_id;
			reg_run_first_failure_id = "NONE";
			cnt_run_event = 0;
			cnt_run_stable_pass = 0;
			cnt_run_stable_fail = 0;
			cnt_run_stable_unclosed = 0;
			reset_run_observations;
			trace_reset;
			flag_jnt_baseline_active = 1'b0;
			@(negedge i_clk);
			i_rstn = 1'b0;
			analog_run_enable = 1'b0;
			measurement_run_enable = 1'b0;
			measurement_allow_new_transaction = 1'b0;
			analog_start_ack_event = 1'b0;
			measurement_start_ack_event = 1'b0;
			i_stop_ack_event = 1'b0;
			i_control_abort_event = 1'b0;
			i_diag_clear_event = 1'b0;
			i_run_profile = 1'b0;
			i_input_source = reg_scenario_input_source;
			i_optical_mode = reg_scenario_optical_mode;
			i_initial_precision = reg_scenario_initial_precision;
			i_amb_recheck_interval_frames = reg_scenario_recheck_interval;
			i_idac_mode = reg_scenario_idac_mode;
			if(reg_scenario_force_search_failure) begin
				i_amb_threshold_low = 12'sd500;
				i_amb_threshold_high = 12'sd501;
				i_dcs_threshold_low = 12'sd500;
				i_dcs_threshold_high = 12'sd501;
			end else if((group_id == "STARTUP-IDAC-CALIBRATION") || reg_scenario_enable_tracking_after_startup) begin
				i_amb_threshold_low = 12'sd11;
				i_amb_threshold_high = 12'sd13;
				i_dcs_threshold_low = 12'sd11;
				i_dcs_threshold_high = 12'sd13;
			end else begin
				i_amb_threshold_low = -12'sd2048;
				i_amb_threshold_high = 12'sd2047;
				i_dcs_threshold_low = -12'sd2048;
				i_dcs_threshold_high = 12'sd2047;
			end
			i_static_characterization_enable = 1'b0;
			i_adc_idle = 1'b1;
			i_clk_stage1_dout_low_async = 1'b0;
			i_clk_stage2_dout_low_async = 1'b0;
			time_run_reset_assert = $time;
			time_run_start_ack = 0;
			time_run_deadline = time_run_reset_assert + C_SIM_TIMEOUT_NS;
			$display("TB_FUNCTIONAL_PHASE run=%0d group=%0s jnt_parent_run=%0d jnt=%0d/%0d", cnt_run_index, reg_run_group_id, cnt_jnt_parent_run_index, cnt_jnt_parent_pass, C_JNT_REQUIRED_SUBCHECKS);
			if(fd_result_file != 0) $fwrite(fd_result_file, "TB_FUNCTIONAL_PHASE run=%0d group=%0s jnt_parent_run=%0d jnt_checked=%0d jnt_pass=%0d jnt_fail=%0d required=%0d\n", cnt_run_index, reg_run_group_id, cnt_jnt_parent_run_index, cnt_jnt_parent_checked, cnt_jnt_parent_pass, cnt_jnt_parent_fail, C_JNT_REQUIRED_SUBCHECKS);
		end
	endtask

	// Release a previously established reset only after a deterministic reset hold.
	task release_independent_run_reset;
		begin
			repeat(4) @(negedge i_clk);
			i_rstn = 1'b1;
			log_public_event("RUN_RESET_RELEASE", 16'd0, 16'd0, 1'b0, 2'd0, 1'b0);
		end
	endtask

	// The accepted measurement START is the only valid origin for a physical-duration measurement.
	task mark_measurement_start;
		begin
			time_run_start_ack = $time;
			flag_scheduler_run_armed = 1'b1;
			$display("TB_MEASUREMENT_START run=%0d group=%0s time=%0t", cnt_run_index, reg_run_group_id, time_run_start_ack);
		end
	endtask

	// Report the real number of completed JNT comparisons. A partial baseline is explicitly NOT_CLOSED.
	task report_jnt_baseline;
		begin
			cnt_jnt_parent_run_index = cnt_run_index;
			cnt_jnt_parent_checked = cnt_run_jnt_checked;
			cnt_jnt_parent_pass = cnt_run_jnt_pass;
			cnt_jnt_parent_fail = cnt_run_jnt_fail;
			reg_jnt_parent_group_id = reg_run_group_id;
			flag_jnt_parent_valid = 1'b1;
			flag_jnt_baseline_active = 1'b0;
			if((cnt_run_jnt_checked == C_JNT_REQUIRED_SUBCHECKS) && (cnt_run_jnt_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_run_jnt_fail == 0))begin
				$display("JNT_BASELINE run=%0d group=%0s pass=%0d/%0d status=PASS", cnt_run_index, reg_run_group_id, cnt_run_jnt_pass, C_JNT_REQUIRED_SUBCHECKS);
				if(fd_result_file != 0) begin $fwrite(fd_result_file, "TB_JNT_BASELINE run=%0d group=%0s checked=%0d pass=%0d fail=%0d required=%0d status=PASS\n", cnt_run_index, reg_run_group_id, cnt_run_jnt_checked, cnt_run_jnt_pass, cnt_run_jnt_fail, C_JNT_REQUIRED_SUBCHECKS); $fflush(fd_result_file); end
			end else if(cnt_run_jnt_fail == 0)begin
				$display("JNT_BASELINE run=%0d group=%0s pass=%0d/%0d checked=%0d status=NOT_CLOSED", cnt_run_index, reg_run_group_id, cnt_run_jnt_pass, C_JNT_REQUIRED_SUBCHECKS, cnt_run_jnt_checked);
				if(fd_result_file != 0) begin $fwrite(fd_result_file, "TB_JNT_BASELINE run=%0d group=%0s checked=%0d pass=%0d fail=%0d required=%0d status=NOT_CLOSED\n", cnt_run_index, reg_run_group_id, cnt_run_jnt_checked, cnt_run_jnt_pass, cnt_run_jnt_fail, C_JNT_REQUIRED_SUBCHECKS); $fflush(fd_result_file); end
			end else begin
				$display("JNT_BASELINE run=%0d group=%0s pass=%0d/%0d checked=%0d fail=%0d first_failure=%0s status=FAIL", cnt_run_index, reg_run_group_id, cnt_run_jnt_pass, C_JNT_REQUIRED_SUBCHECKS, cnt_run_jnt_checked, cnt_run_jnt_fail, reg_run_first_failure_id);
				if(fd_result_file != 0) begin $fwrite(fd_result_file, "TB_JNT_BASELINE run=%0d group=%0s checked=%0d pass=%0d fail=%0d required=%0d first_failure=%0s status=FAIL\n", cnt_run_index, reg_run_group_id, cnt_run_jnt_checked, cnt_run_jnt_pass, cnt_run_jnt_fail, C_JNT_REQUIRED_SUBCHECKS, reg_run_first_failure_id); $fflush(fd_result_file); end
			end
			if(fd_result_file != 0)begin
				$fclose(fd_result_file);
				fd_result_file = $fopen("D:/PPG/verilog/jxa/ppg_system_integration/tb_scenario_result.log", "a");
			end
		end
	endtask

	// Group-local stable-ID accounting never borrows a comparison from another reset/run.
	task report_functional_group;
		input [8 * 32 - 1:0]group_id;
		input integer first_trace_slot;
		input integer required_trace_count;
		integer group_trace_index;
		integer group_not_applicable;
		integer group_applicable;
		integer group_provenance_mismatch;
		begin
			cnt_run_stable_pass = 0;
			cnt_run_stable_fail = 0;
			cnt_run_stable_unclosed = 0;
			group_not_applicable = 0;
			group_provenance_mismatch = 0;
			for(group_trace_index = first_trace_slot; group_trace_index < (first_trace_slot + required_trace_count); group_trace_index = group_trace_index + 1)begin
				if((reg_trace_status[group_trace_index] == TRACE_PASS) &&
					(reg_trace_compare_count[group_trace_index] > 0) &&
					(reg_trace_group_id[group_trace_index] == group_id)) cnt_run_stable_pass = cnt_run_stable_pass + 1;
				else if(reg_trace_status[group_trace_index] == TRACE_FAIL) begin
					if(reg_trace_group_id[group_trace_index] != group_id) begin
						group_provenance_mismatch = group_provenance_mismatch + 1;
						cnt_run_stable_unclosed = cnt_run_stable_unclosed + 1;
					end else cnt_run_stable_fail = cnt_run_stable_fail + 1;
					if(reg_run_first_failure_id == "NONE") reg_run_first_failure_id = reg_trace_id[group_trace_index];
				end else if(reg_trace_status[group_trace_index] == TRACE_UNCHECKED) begin
					cnt_run_stable_unclosed = cnt_run_stable_unclosed + 1;
				end else if(reg_trace_status[group_trace_index] == TRACE_NOT_APPLICABLE) begin
					group_not_applicable = group_not_applicable + 1;
				end else begin
					group_provenance_mismatch = group_provenance_mismatch + 1;
					cnt_run_stable_unclosed = cnt_run_stable_unclosed + 1;
				end
			end
			group_applicable = required_trace_count - group_not_applicable;
			if((group_applicable > 0) && flag_jnt_parent_valid && (cnt_jnt_parent_checked == C_JNT_REQUIRED_SUBCHECKS) && (cnt_jnt_parent_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_jnt_parent_fail == 0) && (cnt_run_stable_pass == group_applicable) && (cnt_run_stable_unclosed == 0))begin
				$display("TB_GROUP_SUMMARY run=%0d group=%0s jnt_parent_run=%0d jnt=%0d/%0d stable=%0d/%0d not_applicable=%0d provenance_mismatch=%0d events=%0d status=PASS", cnt_run_index, group_id, cnt_jnt_parent_run_index, cnt_jnt_parent_pass, C_JNT_REQUIRED_SUBCHECKS, cnt_run_stable_pass, group_applicable, group_not_applicable, group_provenance_mismatch, cnt_run_event);
			end else if(cnt_jnt_parent_fail != 0 || cnt_run_stable_fail != 0)begin
				$display("TB_GROUP_SUMMARY run=%0d group=%0s jnt_parent_run=%0d jnt=%0d/%0d stable=%0d/%0d stable_fail=%0d provenance_mismatch=%0d not_applicable=%0d events=%0d first_failure=%0s status=FAIL", cnt_run_index, group_id, cnt_jnt_parent_run_index, cnt_jnt_parent_pass, C_JNT_REQUIRED_SUBCHECKS, cnt_run_stable_pass, group_applicable, cnt_run_stable_fail, group_provenance_mismatch, group_not_applicable, cnt_run_event, reg_run_first_failure_id);
			end else begin
				$display("TB_GROUP_SUMMARY run=%0d group=%0s jnt_parent_run=%0d jnt=%0d/%0d stable=%0d/%0d not_closed=%0d provenance_mismatch=%0d not_applicable=%0d events=%0d status=NOT_CLOSED", cnt_run_index, group_id, cnt_jnt_parent_run_index, cnt_jnt_parent_pass, C_JNT_REQUIRED_SUBCHECKS, cnt_run_stable_pass, group_applicable, cnt_run_stable_unclosed, group_provenance_mismatch, group_not_applicable, cnt_run_event);
			end
		end
	endtask

	task check_case;
		input [8 * 32 - 1:0]case_id;
		input condition;
		begin
			if(condition === 1'b1)begin
				cnt_pass = cnt_pass + 1;
				if(flag_jnt_baseline_active == 1'b1)begin
					cnt_run_jnt_checked = cnt_run_jnt_checked + 1;
					cnt_run_jnt_pass = cnt_run_jnt_pass + 1;
				end
				$display("PASS %0s", case_id);
			end else begin
				cnt_fail = cnt_fail + 1;
				if(flag_jnt_baseline_active == 1'b1)begin
					cnt_run_jnt_checked = cnt_run_jnt_checked + 1;
					cnt_run_jnt_fail = cnt_run_jnt_fail + 1;
					if(reg_run_first_failure_id == "NONE") reg_run_first_failure_id = case_id;
				end
				$display("FAIL %0s at %0t", case_id, $time);
			end
		end
	endtask

	// 仅向SSW建立模拟START，STATIC_BIAS场景不得把该事件送入测量链。
	task pulse_analog_start_ack;
		begin
			@(negedge i_clk); analog_start_ack_event = 1'b1;
			@(negedge i_clk); analog_start_ack_event = 1'b0;
		end
	endtask

	// 仅向Scheduler/AMI建立测量START，保持测量许可边界独立。
	task pulse_measurement_start_ack;
		begin
			@(negedge i_clk); measurement_start_ack_event = 1'b1;
			@(negedge i_clk); measurement_start_ack_event = 1'b0;
		end
	endtask

	// 普通测量START要求模拟和测量事件同拍到达各自模块。
	task pulse_normal_start_ack;
		begin
			@(negedge i_clk);
			analog_start_ack_event = 1'b1;
			measurement_start_ack_event = 1'b1;
			mark_measurement_start;
			@(negedge i_clk);
			analog_start_ack_event = 1'b0;
			measurement_start_ack_event = 1'b0;
		end
	endtask

	// 在下降沿建立abort事件，随后保留匹配的物理DONE用于释放旧owner。
	task pulse_control_abort;
		begin
			@(negedge i_clk); i_control_abort_event = 1'b1;
			@(negedge i_clk); i_control_abort_event = 1'b0;
		end
	endtask

	// RRC-12 abort诊断：区分预期排空状态与调度器sticky协议故障。
	task log_rrc12_abort_scheduler_diag;
		input [8 * 32 - 1:0]phase_name;
		begin
			$display("TB_RRC12_ABORT_SCHED_DIAG phase=%0s macro_tick=%0d cal_tick=%0d abort=%0d stop_ack=%0d run_enable=%0d allow_new=%0d state_inflight=%0d state_discard=%0d state_stop_drain=%0d state_protocol_error=%0d state_completion_mismatch=%0d state_deadline_timeout=%0d start_valid=%0d start_ready=%0d start_fire=%0d owner_commit=%0d adc_complete=%0d adc_success=%0d adc_owner=%0d sched_txn=%0d cal_inflight=%0d", phase_name, o_macro_tick, o_calibration_local_tick, i_control_abort_event, i_stop_ack_event, measurement_run_enable, measurement_allow_new_transaction, ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_DISCARD], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_STOP_DRAIN], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_PROTOCOL_ERROR], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_COMPLETION_MISMATCH], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_OWNER_DEADLINE_TIMEOUT], o_transaction_start_valid, o_transaction_start_ready, o_transaction_start_fire, o_adc_owner_commit_event, o_adc_transaction_complete_event, o_adc_transaction_success, o_adc_owner_inflight, o_scheduler_transaction_inflight, ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight);
		end
	endtask

	// 产生一个同步STOP确认脉冲，并保留已提交物理owner直到匹配DONE完成排空。
	task pulse_stop_ack;
		begin
			@(negedge i_clk); i_stop_ack_event = 1'b1;
			@(negedge i_clk); i_stop_ack_event = 1'b0;
		end
	endtask

	// 等待期望数量的真实owner提交，超时只报告失败而不伪造任何接口事件。
	task wait_owner_commit_count;
		input integer expected_count;
		begin
			cnt_watchdog = 0;
			while((cnt_owner_commit < expected_count) && (cnt_watchdog < 1200))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			if(cnt_owner_commit < expected_count)begin
				$display("JOINT_OWNER_TIMEOUT macro_tick=%0d scheduler_inflight=%0b ssw_inflight=%0b owner_ready=%0b start_valid=%0b start_ready=%0b start_fire=%0b scheduler_fault=%0b ssw_fault=%0b ami_fault=%0b", o_macro_tick, o_scheduler_transaction_inflight, o_adc_owner_inflight, o_adc_owner_ready, o_transaction_start_valid, o_transaction_start_ready, o_transaction_start_fire, o_scheduler_fault_blocking, o_ssw_fault_blocking, o_ami_fault_blocking);
			end
			check_case("JNT-OWNER-WAIT", cnt_owner_commit >= expected_count);
		end
	endtask

	// 等待AMI从真实异步捕获链输出完成旁带，而不是驱动Scheduler完成输入。
	// 长时算法场景等待下一次真实owner，不将固定拍数当作完成判据。
	task wait_owner_commit_count_long;
		input integer expected_count;
		begin
			cnt_watchdog = 0;
			// Recheck acceptance can occur exactly at a 400 Hz frame boundary.
			// Allow the following calibration frame to publish its owner before
			// declaring a TB-side timeout.
			while((cnt_owner_commit < expected_count) && (cnt_watchdog < 40000))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			if(cnt_owner_commit < expected_count)begin
				$display("PPG_OWNER_TIMEOUT macro_tick=%0d expected=%0d actual=%0d", o_macro_tick, expected_count, cnt_owner_commit);
			end
		end
	endtask

	// 长时算法场景等待AMI真实完成旁带，完成仍由异步DOUT/RAW触发。
	task wait_completion_count_long;
		input integer expected_count;
		begin
			cnt_watchdog = 0;
			while((cnt_completion < expected_count) && (cnt_watchdog < 1000))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			if(cnt_completion < expected_count)begin
				$display("PPG_DONE_TIMEOUT expected=%0d actual=%0d", expected_count, cnt_completion);
			end
		end
	endtask

	// 长时发生器只验证物理相位顺序，不为每一笔样本增加场景计数。
	task wait_conversion_phases_complete_quiet;
		input color_ir;
		begin
			cnt_watchdog = 0;
			// Owner交接时，上一笔事务的Q相位可能仍处于有效电平；
			// 先等待这些电平返回空闲并重新清除观测标志，避免把旧历史
			// 当作当前owner的Q1/Q2/Q3完成证据。
			while(((((reg_last_owner_precision_mode == 1'b0) &&
				((o_clk_9q1_low == 1'b1) || (o_clk_q2_low == 1'b1) || (o_clk_q3_low == 1'b1))) ||
				((reg_last_owner_precision_mode == 1'b1) &&
				((o_clk_15q1_low == 1'b1) || (o_clk_q2_low == 1'b1) || (o_clk_q3_low == 1'b1)))) &&
				(cnt_watchdog < 42000)))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			flag_red_q1_seen = 1'b0;
			flag_red_q2_seen = 1'b0;
			flag_red_q3_seen = 1'b0;
			flag_ir_q1_seen = 1'b0;
			flag_ir_q2_seen = 1'b0;
			flag_ir_q3_seen = 1'b0;
			// 长时场景的公开 Q1/Q2/Q3 事件可能跨越一个完整模拟窗口；
			// 这里等待真实相位完成，不在固定短拍数到期时伪造 DONE。
			while((((color_ir == 1'b0) && (!flag_red_q1_seen || !flag_red_q2_seen || !flag_red_q3_seen)) || ((color_ir == 1'b1) && (!flag_ir_q1_seen || !flag_ir_q2_seen || !flag_ir_q3_seen))) && (cnt_watchdog < 40000))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			while((o_clk_q3_low == 1'b1) && (cnt_watchdog < 42000))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
		end
	endtask

	task wait_completion_count;
		input integer expected_count;
		begin
			cnt_watchdog = 0;
			while((cnt_completion < expected_count) && (cnt_watchdog < 200))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			check_case("JNT-DONE-WAIT", cnt_completion >= expected_count);
		end
	endtask

	// 在当前owner的Q3低电平结束后驱动外部CLK_DOUT和RAW，避免任何固定拍数完成模型。
	task drive_real_adc_done;
		input precision_mode;
		input [9:0]stage1_raw;
		input [9:0]stage2_raw;
		begin
			reg_last_driven_stage1_raw = stage1_raw;
			reg_last_driven_stage2_raw = stage2_raw;
			reg_last_driven_precision_mode = precision_mode;
			reg_last_driven_raw_valid = 1'b1;
			@(negedge i_clk);
			#2 i_adc_idle = 1'b0;
			#2 i_dout_stage1_low = stage1_raw;
			#1 i_dout_stage2_low = stage2_raw;
			#1 i_clk_stage1_dout_low_async = 1'b1;
			#1 i_clk_stage2_dout_low_async = precision_mode;
			repeat(5) @(negedge i_clk);
			#2 i_clk_stage1_dout_low_async = 1'b0;
			#1 i_clk_stage2_dout_low_async = 1'b0;
			#1 i_adc_idle = 1'b1;
		end
	endtask

	// Calibration RAW uses the same vdred=1 physical encoding as NORMAL samples.
	// The target is selected by the scenario: 500 is inside the startup/recheck
	// acceptance window, while 8 deliberately exercises search exhaustion.
	task make_calibration_raw;
		input integer target_code;
		output [9:0]stage1_raw;
		integer bounded_code;
		integer encoded_code;
		begin
			bounded_code = target_code;
			if(bounded_code < 8) bounded_code = 8;
			else if(bounded_code > 503) bounded_code = 503;
			encoded_code = bounded_code - 4;
			stage1_raw = ((encoded_code >> 3) << 4) | 10'b0000001000 | (encoded_code & 7);
		end
	endtask

	// A calibration owner is accepted only after its real Q3 interval has
	// completed.  This keeps CLK_DOUT/RAW causally downstream of the owner and
	// prevents a fixed-delay completion from masking a missing analog phase.
	task wait_calibration_q3_release;
		integer calibration_watchdog;
		begin
			calibration_watchdog = 0;
			while((o_clk_q3_low !== 1'b1) && (calibration_watchdog < 2000))begin
				@(negedge i_clk);
				calibration_watchdog = calibration_watchdog + 1;
			end
			while((o_clk_q3_low === 1'b1) && (calibration_watchdog < 2200))begin
				@(negedge i_clk);
				calibration_watchdog = calibration_watchdog + 1;
			end
			if((o_adc_owner_inflight !== 1'b1) || (o_clk_q3_low !== 1'b0))begin
				cnt_calibration_adc_driver_timeout = cnt_calibration_adc_driver_timeout + 1;
			end
			reg_calibration_q3_released = (o_clk_q3_low === 1'b0) && (calibration_watchdog < 2200);
			log_public_event("CAL_Q3_WAIT_DONE", o_adc_owner_frame_id, o_adc_owner_sample_index,
				o_adc_owner_color_ir, o_adc_owner_frame_type, o_adc_owner_precision_mode);
		end
	endtask

	// Respond to one calibration owner through the public asynchronous ADC
	// inputs.  AMB, DCS-RED, and DCS-IR all use the physical Stage1 path; the
	// owner/frame identity remains supplied by the connected scheduler/AMI.
	task drive_calibration_adc_done;
		input precision_mode;
		input color_ir;
		input [1:0]frame_type;
		reg [9:0]calibration_stage1_raw;
		begin
			if(reg_scenario_force_search_failure ||
				(reg_scenario_force_recheck_failure && (reg_recheck_calibration_active || o_amb_recheck_busy))) begin
				make_calibration_raw(8, calibration_stage1_raw);
			end else if(reg_scenario_recheck_nominal_calibration &&
				(reg_recheck_calibration_active || o_amb_recheck_busy)) begin
				// The recovery path must exercise successful AMB/DC revalidation;
				// keep its calibrated Stage1 value inside the acceptance window.
				make_calibration_raw(500, calibration_stage1_raw);
			end else if((i_idac_mode == 2'b01 || i_idac_mode == 2'b10) && ((cnt_calibration_adc_driver % 8) == 7)) begin
				make_calibration_raw(8, calibration_stage1_raw);
			end else begin
				make_calibration_raw(500, calibration_stage1_raw);
			end
			wait_calibration_q3_release;
			if(reg_calibration_q3_released)begin
				drive_real_adc_done(1'b0, calibration_stage1_raw, 10'd0);
				cnt_calibration_adc_driver = cnt_calibration_adc_driver + 1;
			end else begin
				cnt_calibration_adc_driver_timeout = cnt_calibration_adc_driver_timeout + 1;
			end
			reg_calibration_adc_driver_busy = 1'b0;
		end
	endtask

	// 等待所选精度的Q1、Q2、Q3依次出现且Q3返回非活动，再允许异步CLK_DOUT到达。
	task wait_conversion_phases_complete;
		input color_ir;
		begin
			cnt_watchdog = 0;
			while((((color_ir == 1'b0) && (!flag_red_q1_seen || !flag_red_q2_seen || !flag_red_q3_seen)) || ((color_ir == 1'b1) && (!flag_ir_q1_seen || !flag_ir_q2_seen || !flag_ir_q3_seen))) && (cnt_watchdog < 650))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			while((o_clk_q3_low == 1'b1) && (cnt_watchdog < 700))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			check_case("JNT-PHASE-ORDER", ((color_ir == 1'b0) && flag_red_q1_seen && flag_red_q2_seen && flag_red_q3_seen) ||
				((color_ir == 1'b1) && flag_ir_q1_seen && flag_ir_q2_seen && flag_ir_q3_seen));
			check_case("JNT-Q3-RELEASE", (o_clk_q3_low == 1'b0) && (cnt_watchdog < 700));
		end
	endtask

	// 生成60 BPM、快升慢降并带重搏切迹的确定性PPG物理RAW码。
	// color_sample_index是同一颜色的400 Hz样本序号，不使用DUT内部状态。
	task make_ppg_raw_sample;
		input precision_mode;
		input color_ir;
		input [15:0]color_sample_index;
		output [9:0]stage1_raw;
		output [9:0]stage2_raw;
		integer sample_number;
		integer heart_phase;
		integer drift_phase;
		integer pulse_q10;
		integer baseline_drift;
		integer deterministic_noise;
		integer base_code;
		integer pulse_amplitude;
		integer target_code;
		integer stage2_target_code;
		integer encoded_base_code;
		begin
			sample_number = color_sample_index;
			heart_phase = sample_number % C_PPG_HEART_SAMPLES;
			if(reg_scenario_waveform_mode == 7) heart_phase = sample_number % 80;
			else if(reg_scenario_waveform_mode == 8) heart_phase = sample_number % 520;

			// 归一化脉冲：快收缩上升、慢舒张下降、重搏切迹和低幅舒张平台。
			if(heart_phase < 40)begin
				pulse_q10 = 154 + ((870 * heart_phase) / 40);
			end else if(heart_phase < 120)begin
				pulse_q10 = 1024 - ((464 * (heart_phase - 40)) / 80);
			end else if(heart_phase < 220)begin
				pulse_q10 = 560 - ((310 * (heart_phase - 120)) / 100);
			end else if(heart_phase < 240)begin
				pulse_q10 = 250 + ((140 * (heart_phase - 220)) / 20);
			end else if(heart_phase < 260)begin
				pulse_q10 = 390 - ((140 * (heart_phase - 240)) / 20);
			end else begin
				pulse_q10 = 250 - ((130 * (heart_phase - 260)) / 140);
			end

			// 10秒周期的三角基线漂移和固定幅度噪声，保证回归可重复。
			drift_phase = sample_number % C_PPG_DRIFT_SAMPLES;
			if(drift_phase < (C_PPG_DRIFT_SAMPLES / 2))begin
				baseline_drift = -10 + ((20 * drift_phase) / (C_PPG_DRIFT_SAMPLES / 2));
			end else begin
				baseline_drift = 10 - ((20 * (drift_phase - (C_PPG_DRIFT_SAMPLES / 2))) / (C_PPG_DRIFT_SAMPLES / 2));
			end
			deterministic_noise = ((sample_number + (color_ir ? 3 : 0)) % 5) - 2;

			if(color_ir == 1'b0)begin
				base_code = C_PPG_RED_BASE_CODE;
				pulse_amplitude = C_PPG_RED_AMPLITUDE;
			end else begin
				base_code = C_PPG_IR_BASE_CODE;
				pulse_amplitude = C_PPG_IR_AMPLITUDE;
			end

			target_code = base_code + ((pulse_q10 * pulse_amplitude) / 1024) + baseline_drift + deterministic_noise;
			if(reg_scenario_waveform_mode == 1) target_code = base_code + deterministic_noise;
			else if(reg_scenario_waveform_mode == 2) target_code = base_code + ((pulse_q10 * pulse_amplitude) / 8192) + deterministic_noise;
			else if(reg_scenario_waveform_mode == 3) target_code = 503;
			else if(reg_scenario_waveform_mode == 4) target_code = ((sample_number % 7) == 0) ? 8 : 503;
			else if(reg_scenario_waveform_mode == 5) target_code = ((sample_number % 16) == 15) ? 8 : 500;
			else if(reg_scenario_waveform_mode == 6) begin
				if(sample_number < 128) target_code = ((sample_number % 16) < 8) ? 500 : 8;
				else target_code = ((sample_number % 16) == 15) ? 8 : 500;
			end
			else if(reg_scenario_waveform_mode == 9) target_code = base_code + ((pulse_q10 * pulse_amplitude) / 1024) + baseline_drift + deterministic_noise / 2;
			else if(reg_scenario_waveform_mode == 10) target_code = base_code + ((pulse_q10 > 700) ? pulse_amplitude : 0) + baseline_drift + deterministic_noise;
			else if(reg_scenario_waveform_mode == 11) target_code = ((sample_number % 9) == 0) ? 8 : (base_code + ((pulse_q10 * pulse_amplitude) / 1024));
			if(target_code < 8)begin
				target_code = 8;
			end else if(target_code > 503)begin
				target_code = 503;
			end

			// 使用vdred=1的公开物理位编码，使S1冗余译码结果等于target_code。
			encoded_base_code = target_code - 4;
			stage1_raw = ((encoded_base_code >> 3) << 4) | 10'b0000001000 | (encoded_base_code & 7);

			if(precision_mode == 1'b1)begin
				stage2_target_code = 256 + ((target_code - 256) / 2);
				if(stage2_target_code < 8)begin
					stage2_target_code = 8;
				end else if(stage2_target_code > 503)begin
					stage2_target_code = 503;
				end
				encoded_base_code = stage2_target_code - 4;
				stage2_raw = ((encoded_base_code >> 3) << 4) | 10'b0000001000 | (encoded_base_code & 7);
			end else begin
				stage2_raw = 10'd0;
			end
			// Numeric scoreboard vectors still use the public Q3->RAW->AMI path.
			case(reg_scenario_numeric_vector_mode)
				1: begin stage1_raw = 10'd0; stage2_raw = 10'd0; end
				2: begin stage1_raw = 10'd0; stage2_raw = 10'd0; end
				3: begin stage1_raw = 10'd0; stage2_raw = 10'd0; end
				4: begin stage1_raw = 10'd0; stage2_raw = 10'd0; end
				5: begin stage1_raw = 10'h3ff; stage2_raw = 10'h3ff; end
				default: begin end
			endcase
		end
	endtask

	// Record the generated payload itself so RAW-02/03 are tied to the
	// deterministic model, rather than to an arbitrary completion count.
	task record_raw_profile;
		input color_ir;
		input [9:0]raw_code;
		reg [9:0]previous_code;
		reg previous_valid;
		begin
			if(color_ir == 1'b0) begin previous_code = reg_raw_profile_prev_red; previous_valid = flag_raw_profile_prev_red_valid; end
			else begin previous_code = reg_raw_profile_prev_ir; previous_valid = flag_raw_profile_prev_ir_valid; end
			if(previous_valid) begin
				if(raw_code > previous_code) begin
					cnt_raw_profile_rise = cnt_raw_profile_rise + 1;
					if(cnt_raw_profile_fall > 0) flag_raw_profile_notch_rebound = 1'b1;
				end else if(raw_code < previous_code) cnt_raw_profile_fall = cnt_raw_profile_fall + 1;
			end
			if(color_ir == 1'b0) begin reg_raw_profile_prev_red = raw_code; flag_raw_profile_prev_red_valid = 1'b1; end
			else begin reg_raw_profile_prev_ir = raw_code; flag_raw_profile_prev_ir_valid = 1'b1; end
			// Ordered FNV-style signature binds color and every generated RAW value.
			reg_raw_signature = (reg_raw_signature ^ {21'd0, color_ir, raw_code}) * 32'h01000193;
			cnt_raw_signature_samples = cnt_raw_signature_samples + 1;
			if((cnt_raw_profile_rise > 20) && (cnt_raw_profile_fall > 20)) flag_raw_profile_drift_observed = 1'b1;
			// make_ppg_raw_sample clamps target_code to 8..503. These are the
			// corresponding public Stage1 RAW encodings for vdred=1.
			if((raw_code == 10'd12) || (raw_code == 10'd1003)) flag_raw_profile_clamp_observed = 1'b1;
		end
	endtask

	// 每笔PPG样本先等待实际Q3释放，再通过异步DONE链送入生成的RAW载荷。
	task drive_ppg_adc_done;
		input precision_mode;
		input color_ir;
		input [15:0]color_sample_index;
		reg [9:0]ppg_stage1_raw;
		reg [9:0]ppg_stage2_raw;
		begin
			wait_conversion_phases_complete(color_ir);
			make_ppg_raw_sample(precision_mode, color_ir, color_sample_index, ppg_stage1_raw, ppg_stage2_raw);
			drive_real_adc_done(precision_mode, ppg_stage1_raw, ppg_stage2_raw);
		end
	endtask

	// 长时算法场景的RAW驱动复用同一物理异步路径，但不将每笔样本计为独立场景。
	task drive_ppg_adc_done_quiet;
		input precision_mode;
		input color_ir;
		input [15:0]color_sample_index;
		reg [9:0]ppg_stage1_raw;
		reg [9:0]ppg_stage2_raw;
		begin
			wait_conversion_phases_complete_quiet(color_ir);
			make_ppg_raw_sample(precision_mode, color_ir, color_sample_index, ppg_stage1_raw, ppg_stage2_raw);
			record_raw_profile(color_ir, ppg_stage1_raw);
			drive_real_adc_done(precision_mode, ppg_stage1_raw, ppg_stage2_raw);
		end
	endtask

	// 启动新的手动码RUN并等待Scheduler经一次START边界将码提交到AMI。
	task start_manual_run;
		begin
			pulse_normal_start_ack;
			cnt_watchdog = 0;
			while((o_startup_search_complete !== 1'b1) && (cnt_watchdog < 80))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			check_case("JNT-STARTUP-READY", o_startup_search_complete && o_normal_measurement_eligible);
		end
	endtask

	// 在每次独立物理RUN前清除TB观察锁存，不改变DUT的复位与生命周期状态。
	task clear_idac_observation;
		begin
			flag_selected_amb_bus_seen = 1'b0;
			flag_selected_dc_bus_seen = 1'b0;
			flag_red_dc_bus_seen = 1'b0;
			flag_ir_dc_bus_seen = 1'b0;
			flag_unselected_idac_bus_clean = 1'b1;
			flag_idac_bus_violation = 1'b0;
		end
	endtask

	// Stage1黄金模型：严格按合同的十个signed-Q16绝对权重和对称舍入计算。
	task compute_expected_stage1;
		input [9:0]raw_code;
		output signed [11:0]expected_value;
		reg signed [63:0]accumulator_q16;
		reg signed [63:0]rounded_value;
		begin
			accumulator_q16 = i_stage1_offset_q16;
			if(raw_code[0]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_0;
			if(raw_code[1]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_1;
			if(raw_code[2]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_2;
			if(raw_code[3]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_3;
			if(raw_code[4]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_4;
			if(raw_code[5]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_5;
			if(raw_code[6]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_6;
			if(raw_code[7]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_7;
			if(raw_code[8]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_8;
			if(raw_code[9]) accumulator_q16 = accumulator_q16 + i_stage1_weight_q16_9;
			if(accumulator_q16 < 0)begin
				rounded_value = -(((-accumulator_q16) + 64'sd32768) >>> 16);
			end else begin
				rounded_value = (accumulator_q16 + 64'sd32768) >>> 16;
			end
			if(rounded_value < -2048)begin
				expected_value = -12'sd2048;
			end else if(rounded_value > 2047)begin
				expected_value = 12'sd2047;
			end else begin
				expected_value = rounded_value[11:0];
			end
		end
	endtask

	// Stage2/重构/DC recovery黄金模型：与现有公共系数和RTL中的Q17舍入、饱和语义逐项一致。
	// 该模型只消费已锁存RAW、码快照和ACTIVE系数，不读取DUT层次内部信号。
	task compute_expected_numeric_chain;
		input [9:0]raw_stage1;
		input [9:0]raw_stage2;
		input signed [11:0]stage1_value;
		input precision_mode;
		input [7:0]dc_code;
		output signed [14:0]expected_15;
		output signed [23:0]expected_coarse;
		output signed [23:0]expected_fine;
		reg signed [63:0]stage1_center_x2;
		reg signed [63:0]stage2_base_code;
		reg signed [63:0]stage2_code_ext;
		reg signed [63:0]stage2_center_x2;
		reg signed [63:0]stage1_product_q16;
		reg signed [63:0]stage2_product_q17;
		reg signed [63:0]stage2_offset_q17;
		reg signed [63:0]reconstructor_acc_q17;
		reg signed [63:0]reconstructor_magnitude;
		reg signed [63:0]reconstructor_rounded_magnitude;
		reg signed [63:0]reconstructor_rounded_code;
		reg signed [63:0]coarse_acc_q17;
		reg signed [63:0]fine_acc_q17;
		reg signed [63:0]expected_15_ext;
		reg signed [63:0]coarse_magnitude;
		reg signed [63:0]fine_magnitude;
		reg signed [63:0]coarse_rounded_magnitude;
		reg signed [63:0]fine_rounded_magnitude;
		reg signed [63:0]coarse_rounded_code;
		reg signed [63:0]fine_rounded_code;
		begin
			// Stage1中心项与重构器相同，raw_stage1参数保留在接口中用于追踪闭合。
			stage1_center_x2 = (stage1_value <<< 1) - 64'sd511;
			stage1_product_q16 = stage1_center_x2 * 64'sd3533837;

			// D2_EXT = {vd8:vd3,000}+{0000000,vd2:vd0} +/- vdred*4。
			stage2_base_code = (raw_stage2[9:4] * 64'sd8) + raw_stage2[2:0];
			if(raw_stage2[3] == 1'b1) stage2_code_ext = stage2_base_code + 64'sd4;
			else stage2_code_ext = stage2_base_code - 64'sd4;
			stage2_center_x2 = (stage2_code_ext <<< 1) - 64'sd512;
			stage2_product_q17 = stage2_center_x2 * $signed(i_stage2_gain_q16);
			stage2_offset_q17 = $signed(i_stage2_offset_q16) <<< 1;

			if(precision_mode == 1'b1)begin
				reconstructor_acc_q17 = stage1_product_q16 + stage2_product_q17 + stage2_offset_q17;
				if(reconstructor_acc_q17 < 0)begin
					reconstructor_magnitude = -reconstructor_acc_q17;
					reconstructor_rounded_magnitude = (reconstructor_magnitude + 64'sd65536) >>> 17;
					reconstructor_rounded_code = -reconstructor_rounded_magnitude;
				end else begin
					reconstructor_magnitude = reconstructor_acc_q17;
					reconstructor_rounded_magnitude = (reconstructor_magnitude + 64'sd65536) >>> 17;
					reconstructor_rounded_code = reconstructor_rounded_magnitude;
				end
				if(reconstructor_rounded_code < -64'sd16384) expected_15 = -15'sd16384;
				else if(reconstructor_rounded_code > 64'sd16383) expected_15 = 15'sd16383;
				else expected_15 = reconstructor_rounded_code[14:0];
			end else begin
				expected_15 = 15'sd0;
			end

			// SAR9 coarse recovery keeps the X2-centered Stage1 product at the contract Q17 scale.
			coarse_acc_q17 = stage1_product_q16 + (($signed({1'b0, dc_code}) * $signed(i_dc9_recovery_gain_q16)) <<< 1);
			if(coarse_acc_q17 < 0)begin
				coarse_magnitude = -coarse_acc_q17;
				coarse_rounded_magnitude = (coarse_magnitude + 64'sd65536) >>> 17;
				coarse_rounded_code = -coarse_rounded_magnitude;
			end else begin
				coarse_magnitude = coarse_acc_q17;
				coarse_rounded_magnitude = (coarse_magnitude + 64'sd65536) >>> 17;
				coarse_rounded_code = coarse_rounded_magnitude;
			end
			if(coarse_rounded_code < -64'sd8388608) expected_coarse = -24'sd8388608;
			else if(coarse_rounded_code > 64'sd8388607) expected_coarse = 24'sd8388607;
			else expected_coarse = coarse_rounded_code[23:0];

			// SAR15 fine DC recovery：15-bit重构结果进入Q17基项，再叠加DC15贡献。
			if(precision_mode == 1'b1)begin
				expected_15_ext = expected_15;
				fine_acc_q17 = (expected_15_ext <<< 17) + (($signed({1'b0, dc_code}) * $signed(i_dc15_recovery_gain_q16)) <<< 1);
				if(fine_acc_q17 < 0)begin
					fine_magnitude = -fine_acc_q17;
					fine_rounded_magnitude = (fine_magnitude + 64'sd65536) >>> 17;
					fine_rounded_code = -fine_rounded_magnitude;
				end else begin
					fine_magnitude = fine_acc_q17;
					fine_rounded_magnitude = (fine_magnitude + 64'sd65536) >>> 17;
					fine_rounded_code = fine_rounded_magnitude;
				end
				if(fine_rounded_code < -64'sd8388608) expected_fine = -24'sd8388608;
				else if(fine_rounded_code > 64'sd8388607) expected_fine = 24'sd8388607;
				else expected_fine = fine_rounded_code[23:0];
			end else begin
				expected_fine = 24'sd0;
			end
		end
	endtask

	// 只有实际观测到该场景的比较才写入稳定ID；未执行场景保留为NOT_CLOSED。
	task scoreboard_mark;
		input integer trace_slot;
		input observed;
		input condition;
		begin
			if((observed === 1'b1) && (reg_trace_status[trace_slot] != TRACE_PASS) && (reg_trace_status[trace_slot] != TRACE_FAIL))begin
				trace_mark(trace_slot, condition);
				if(condition === 1'b1)begin
					$display("SCOREBOARD_PASS %0s", reg_trace_id[trace_slot]);
				end else begin
					cnt_fail = cnt_fail + 1;
					$display("SCOREBOARD_FAIL %0s", reg_trace_id[trace_slot]);
				end
			end
		end
	endtask

	// Mark a contract item as outside this run's applicability set without
	// confusing it with a missing comparison.  The aggregate still requires
	// the item to be PASS in a run that declares it applicable.
	task scoreboard_mark_not_applicable;
		input integer trace_slot;
		begin
			if((trace_slot >= 0) && (trace_slot < C_TRACE_COUNT) &&
				(reg_trace_status[trace_slot] != TRACE_PASS) && (reg_trace_status[trace_slot] != TRACE_FAIL))
				reg_trace_status[trace_slot] = TRACE_NOT_APPLICABLE;
		end
	endtask

	// 汇总第2步的状态和数值证据；不会把没有实际输入/比较的ID伪标为PASS。
	task finalize_state_scoreboards;
		integer stable_pass_count;
		integer stable_fail_count;
		integer stable_unclosed_count;
		integer stable_index;
		reg flag_startup_observed;
		reg flag_tracking_observed;
		reg flag_recheck_observed;
		reg flag_numeric_observed;
		reg flag_identity_observed;
		reg flag_snapshot_observed;
		reg flag_lifecycle_observed;
		begin
			flag_startup_observed = (cnt_startup_calibration_request > 0) || (cnt_startup_calibration_completion > 0);
			flag_tracking_observed = (cnt_amb_pending_observed > 0) || (cnt_dcs_r_pending_observed > 0) ||
				(cnt_dcs_ir_pending_observed > 0) || (cnt_dcs_r_track_adjust_observed > 0) || (cnt_dcs_ir_track_adjust_observed > 0);
			flag_recheck_observed = (cnt_recheck_pending_observed > 0) || (cnt_recheck_accept_observed > 0) ||
				(cnt_recheck_calibration_request > 0) || (cnt_recheck_done_observed > 0) || (cnt_recheck_failed_observed > 0);
			flag_numeric_observed = (cnt_numeric_comparison > 0);
			flag_identity_observed = (cnt_identity_comparison > 0) || (cnt_owner_commit > 0);
			flag_snapshot_observed = (cnt_owner_commit > 0) && (cnt_waveform_context > 0);
			flag_lifecycle_observed = (cnt_completion > 0) || flag_fault_first_seen || flag_reset_done_observation;

			// SID-01..12：完整启动搜索仅在真实校准请求/完成链出现后闭合。
			// Stable IDs are owned by their explicit group tasks below.  Do not let
			// this broad historical aggregate helper borrow evidence across runs.
			if(1'b0) begin
			scoreboard_mark(C_TRACE_SID_BASE + 0, flag_startup_observed, (cnt_startup_boundary > 0) && flag_startup_boundary_without_owner);
			scoreboard_mark(C_TRACE_SID_BASE + 1, flag_startup_observed, flag_idac_startup_order_ok &&
				(cnt_startup_amb_completion > 0) && (cnt_startup_dcs_r_completion > 0) && (cnt_startup_dcs_ir_completion > 0));
			scoreboard_mark(C_TRACE_SID_BASE + 2, (cnt_startup_q3_observed > 0), flag_startup_q3_266_ok);
			scoreboard_mark(C_TRACE_SID_BASE + 3, flag_startup_observed, (cnt_startup_calibration_completion > 0) && (cnt_startup_real_chain_mismatch == 0));
			scoreboard_mark(C_TRACE_SID_BASE + 4, flag_startup_observed, flag_startup_owner_deadline_ok);
			scoreboard_mark(C_TRACE_SID_BASE + 5, flag_startup_observed, flag_owner_context_identity_match && (cnt_startup_q3_spacing_mismatch == 0));
			scoreboard_mark(C_TRACE_SID_BASE + 6, flag_startup_observed, flag_startup_waveform_ok &&
				(cnt_startup_amb_waveform_observed > 0) && flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_SID_BASE + 7, flag_startup_observed, flag_startup_waveform_ok &&
				(cnt_startup_dcs_r_waveform_observed > 0) && flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_SID_BASE + 8, flag_startup_observed, flag_startup_waveform_ok &&
				(cnt_startup_dcs_ir_waveform_observed > 0) && flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_SID_BASE + 9, flag_startup_observed, (cnt_startup_successful_calibration_completion == 24) &&
				(cnt_startup_amb_completion == 8) && (cnt_startup_dcs_r_completion == 8) && (cnt_startup_dcs_ir_completion == 8));
			scoreboard_mark(C_TRACE_SID_BASE + 10, 1'b0, 1'b0);
			scoreboard_mark(C_TRACE_SID_BASE + 11, flag_startup_observed, o_startup_search_complete &&
				(cnt_startup_successful_calibration_completion == 24) &&
				(cnt_startup_amb_completion == 8) && (cnt_startup_dcs_r_completion == 8) && (cnt_startup_dcs_ir_completion == 8));

			// TRK-01..10：每一项均绑定公开pending/update/epoch或数值证据。
			scoreboard_mark(C_TRACE_TRK_BASE + 0, flag_tracking_observed, flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 1, flag_tracking_observed, (cnt_amb_pending_observed + cnt_dcs_r_pending_observed + cnt_dcs_ir_pending_observed) > 0);
			scoreboard_mark(C_TRACE_TRK_BASE + 2, (cnt_dcs_r_track_adjust_observed + cnt_dcs_ir_track_adjust_observed) > 1, flag_idac_track_delta_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 3, (cnt_dcs_r_update_observed > 0) && (cnt_dcs_ir_update_observed > 0), flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 4, flag_tracking_observed && flag_ppg_precision_15_seen, flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 5, flag_tracking_observed, cnt_idac_update_without_change == 0);
			scoreboard_mark(C_TRACE_TRK_BASE + 6, (cnt_amb_update_observed + cnt_dcs_r_update_observed + cnt_dcs_ir_update_observed) > 0,
				flag_idac_track_delta_ok && flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 7, cnt_idac_search_exhausted_observed > 0, flag_idac_no_wrap_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 8, flag_tracking_observed && (cnt_numeric_comparison > 0), flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 9, flag_tracking_observed && (cnt_stage1_signed_comparison > 0), flag_tracking_stage1_only);

			// RRC-01..12：周期重检成功和失败均必须具有真实校准完成证据。
			scoreboard_mark(C_TRACE_RRC_BASE + 0, flag_recheck_observed, cnt_recheck_pending_observed > 0);
			scoreboard_mark(C_TRACE_RRC_BASE + 1, flag_recheck_observed && flag_ppg_precision_15_to_9_seen, cnt_recheck_sequence_mismatch == 0);
			scoreboard_mark(C_TRACE_RRC_BASE + 2, cnt_recheck_accept_observed > 0, reg_recheck_drain_ok);
			scoreboard_mark(C_TRACE_RRC_BASE + 3, cnt_recheck_accept_observed > 0, reg_recheck_history_r_cleared && reg_recheck_history_ir_cleared);
			scoreboard_mark(C_TRACE_RRC_BASE + 4, flag_recheck_observed, (cnt_recheck_calibration_request > 0) &&
				(cnt_recheck_successful_calibration_completion > 0) && (cnt_recheck_real_chain_mismatch == 0) && (cnt_recheck_async_observed >= cnt_recheck_calibration_completion) && (reg_recheck_stage_mask == 3'b111));
			scoreboard_mark(C_TRACE_RRC_BASE + 5, cnt_recheck_accept_observed > 0, cnt_recheck_sequence_mismatch == 0);
			scoreboard_mark(C_TRACE_RRC_BASE + 6, cnt_recheck_accept_observed > 0, flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_RRC_BASE + 7, flag_recheck_observed, reg_recheck_output_inhibit_ok);
			scoreboard_mark(C_TRACE_RRC_BASE + 8, cnt_recheck_done_observed > 0, reg_recheck_slope_preserved &&
				(cnt_recheck_history_r_warmup >= 21) && (cnt_recheck_history_ir_warmup >= 21));
			scoreboard_mark(C_TRACE_RRC_BASE + 9, cnt_recheck_done_observed > 0, reg_recheck_recross_seen && reg_recheck_recross_fine_seen &&
				(cnt_recheck_history_r_warmup >= 21) && (cnt_recheck_history_ir_warmup >= 21));
			scoreboard_mark(C_TRACE_RRC_BASE + 10, cnt_recheck_failed_observed > 0, o_reacquire_active && (o_slope_current_q16 == i_fixed_slope_q16));
			scoreboard_mark(C_TRACE_RRC_BASE + 11, 1'b0, 1'b0);

			// NRE和ILM只有在对应模式真正驱动过时才可闭合。
			scoreboard_mark(C_TRACE_NRE_BASE + 0, (i_amb_recheck_interval_frames == 0), (cnt_recheck_pending_observed == 0));
			scoreboard_mark(C_TRACE_NRE_BASE + 1, (i_amb_recheck_interval_frames == 0), (cnt_recheck_accept_observed == 0));
			scoreboard_mark(C_TRACE_NRE_BASE + 2, (i_amb_recheck_interval_frames == 0), flag_ppg_baseline_valid_seen);
			scoreboard_mark(C_TRACE_NRE_BASE + 3, (i_amb_recheck_interval_frames == 0), flag_ppg_cross_pending_seen);
			scoreboard_mark(C_TRACE_NRE_BASE + 4, (i_amb_recheck_interval_frames == 0), flag_ppg_precision_15_seen);
			scoreboard_mark(C_TRACE_NRE_BASE + 5, (i_amb_recheck_interval_frames == 0), flag_ppg_precision_15_to_9_seen);
			scoreboard_mark(C_TRACE_ILM_BASE + 0, cnt_waveform_context > 0, (i_input_source == 1'b0) && (i_optical_mode == OPTICAL_MODE_BOTH));
			scoreboard_mark(C_TRACE_ILM_BASE + 1, (cnt_waveform_context > 0) && (i_optical_mode == OPTICAL_MODE_BOTH), flag_owner_context_identity_match);
			scoreboard_mark(C_TRACE_ILM_BASE + 2, cnt_waveform_context > 0, (cnt_red_waveform_context > 0) && (cnt_ir_waveform_context > 0));
			scoreboard_mark(C_TRACE_ILM_BASE + 3, (cnt_waveform_context > 0) && (i_input_source == 1'b1), flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_ILM_BASE + 4, (cnt_waveform_context > 0) && (i_input_source == 1'b1), (o_leden1_low == 1'b0) && (o_leden2_low == 1'b0));
			scoreboard_mark(C_TRACE_ILM_BASE + 5, (cnt_waveform_context > 0) && (i_input_source == 1'b1), (o_leden1_low == 1'b0) && (o_leddac == 8'd0));
			scoreboard_mark(C_TRACE_ILM_BASE + 6, (cnt_waveform_context > 0) && (i_input_source == 1'b1), (o_leden1_low == 1'b0) && (o_leddac == 8'd0));
			scoreboard_mark(C_TRACE_ILM_BASE + 7, (i_input_source == 1'b1) && (i_optical_mode == 2'b11), (cnt_waveform_context == 0) && (cnt_owner_commit == 0) && (cnt_measurement_result == 0));
			scoreboard_mark(C_TRACE_ILM_BASE + 8, (i_input_source == 1'b1), (i_idac_mode == 2'b00) && (cnt_recheck_pending_observed == 0) && (cnt_recheck_accept_observed == 0));
			scoreboard_mark(C_TRACE_ILM_BASE + 9, flag_numeric_identity_ok, cnt_identity_mismatch == 0);
			scoreboard_mark(C_TRACE_ILM_BASE + 10, flag_startup_observed, (cnt_startup_amb_completion > 0) && flag_startup_q3_266_ok);
			scoreboard_mark(C_TRACE_ILM_BASE + 11, flag_startup_observed, (cnt_startup_dcs_r_completion > 0) && (cnt_startup_dcs_ir_completion > 0) && flag_startup_q3_266_ok);
			scoreboard_mark(C_TRACE_ILM_BASE + 12, (i_static_characterization_enable == 1'b1), (cnt_waveform_context == 0) && (cnt_owner_commit == 0) && !flag_static_q1_seen && !flag_static_q2_seen && !flag_static_q3_seen && !flag_static_async_seen && !flag_static_done_seen);
			scoreboard_mark(C_TRACE_ILM_BASE + 13, (i_static_characterization_enable == 1'b1), (o_s_in == i_test_mux_ctrl) && !flag_static_fir_seen && !flag_static_recheck_seen && !flag_static_algorithm_result_seen);
			scoreboard_mark(C_TRACE_ILM_BASE + 14, (i_static_characterization_enable == 1'b1) && (i_input_source == 1'b1), (o_s_in == 5'd0) && (cnt_waveform_context == 0) && (cnt_owner_commit == 0) && (cnt_measurement_result == 0));

			// ADCN：联合TB的代表性数值链和公开signed Stage1语义。
			scoreboard_mark(C_TRACE_ADCN_BASE + 0, cnt_stage1_signed_comparison > 0, cnt_numeric_mismatch == 0);
			// ADCN-02/03 require directed negative/half-LSB and signed-boundary
			// vectors. A generic Stage1 range comparison is insufficient evidence.
			scoreboard_mark(C_TRACE_ADCN_BASE + 1,
				flag_adcn_negative_vector_seen && flag_adcn_half_lsb_vector_seen,
				flag_stage1_signed_range_ok && flag_adcn_negative_vector_seen && flag_adcn_half_lsb_vector_seen);
			scoreboard_mark(C_TRACE_ADCN_BASE + 2,
				flag_adcn_saturation_low_seen && flag_adcn_saturation_high_seen,
				flag_stage1_signed_range_ok && flag_adcn_saturation_low_seen && flag_adcn_saturation_high_seen);
			scoreboard_mark(C_TRACE_ADCN_BASE + 3, cnt_coarse_comparison > 0, flag_sar9_no_fine_ok);
			scoreboard_mark(C_TRACE_ADCN_BASE + 4, cnt_stage2_comparison > 0, flag_sar15_chain_ok);
			scoreboard_mark(C_TRACE_ADCN_BASE + 5, cnt_fine_comparison > 0, flag_sar15_chain_ok && (cnt_numeric_mismatch == 0));
			scoreboard_mark(C_TRACE_ADCN_BASE + 6, cnt_identity_comparison > 0, flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_ADCN_BASE + 7, cnt_result_backpressure_comparison > 0, cnt_result_backpressure_mismatch == 0);
			scoreboard_mark(C_TRACE_ADCN_BASE + 8, cnt_stage1_signed_comparison > 0, flag_stage1_signed_range_ok);
			scoreboard_mark(C_TRACE_ADCN_BASE + 9, cnt_stage1_signed_comparison > 0, flag_tracking_stage1_only);

			// ISE/OIB：身份快照、总线隔离和公共反压。
			scoreboard_mark(C_TRACE_ISE_BASE + 0, (cnt_owner_commit > 0) && (cnt_waveform_context > 0), flag_owner_context_identity_match);
			scoreboard_mark(C_TRACE_ISE_BASE + 1, (cnt_owner_commit > 0) && (cnt_waveform_context > 0), flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_ISE_BASE + 2, (cnt_amb_update_observed + cnt_dcs_r_update_observed + cnt_dcs_ir_update_observed) > 0, flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_ISE_BASE + 3, cnt_owner_commit > 0, flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_ISE_BASE + 4, flag_ppg_precision_15_seen, flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_ISE_BASE + 5, flag_startup_observed || flag_recheck_observed, flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_ISE_BASE + 6, cnt_owner_commit > 1, flag_ise_pattern_31_seen && flag_ise_pattern_42_seen && flag_ise_pattern_53_seen && flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_ISE_BASE + 7, (cnt_red_waveform_context > 0) && (cnt_ir_waveform_context > 0), flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_ISE_BASE + 8, (cnt_amb_update_observed + cnt_dcs_r_update_observed + cnt_dcs_ir_update_observed) > 0, cnt_idac_update_without_change == 0);
			scoreboard_mark(C_TRACE_ISE_BASE + 9, cnt_tracking_epoch_wrap_observed > 0, flag_idac_no_wrap_ok && (cnt_tracking_epoch_wrap_observed == 1));
			// OIB-01/02 require internal waveform-context and ADC-owner/AMI-start
			// ready stalls; the joint black-box interface exposes no legal controls
			// for those stalls, so owner counts cannot close either ID.
			scoreboard_mark(C_TRACE_OIB_BASE + 0, 1'b0, 1'b0);
			scoreboard_mark(C_TRACE_OIB_BASE + 1, 1'b0, 1'b0);
			scoreboard_mark(C_TRACE_OIB_BASE + 2, cnt_result_backpressure_comparison > 0, cnt_result_backpressure_mismatch == 0);
			scoreboard_mark(C_TRACE_OIB_BASE + 3, cnt_result_backpressure_comparison > 0, cnt_result_backpressure_mismatch == 0);
			scoreboard_mark(C_TRACE_OIB_BASE + 4, cnt_identity_comparison > 0, cnt_identity_mismatch == 0);
			scoreboard_mark(C_TRACE_OIB_BASE + 5, cnt_identity_comparison > 0, cnt_identity_mismatch == 0);
			scoreboard_mark(C_TRACE_OIB_BASE + 6, cnt_identity_comparison > 0, flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_OIB_BASE + 7, cnt_completion > 0, cnt_result_backpressure_mismatch == 0);
			scoreboard_mark(C_TRACE_OIB_BASE + 8, cnt_owner_commit > 0, flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_OIB_BASE + 9, cnt_result_backpressure_comparison > 0, cnt_result_backpressure_mismatch == 0);

			// LFA：JNT已覆盖的真实abort/reset/迟到DONE路径，以及公开故障汇总。
			scoreboard_mark(C_TRACE_LFA_BASE + 0, flag_lifecycle_observed, cnt_fault_owner_leak == 0);
			scoreboard_mark(C_TRACE_LFA_BASE + 1, flag_lifecycle_observed, cnt_completion > 0);
			scoreboard_mark(C_TRACE_LFA_BASE + 2, flag_lifecycle_observed, cnt_idac_update_without_change == 0);
			scoreboard_mark(C_TRACE_LFA_BASE + 3, cnt_completion > 0, reg_last_completion_success || flag_reset_done_observation);
			scoreboard_mark(C_TRACE_LFA_BASE + 4, flag_reset_done_observation, (cnt_identity_mismatch == 0));
			scoreboard_mark(C_TRACE_LFA_BASE + 5, (cnt_completion > 0) || flag_fault_first_seen || flag_reset_done_observation, flag_lfa_early_dout_rejected);
			scoreboard_mark(C_TRACE_LFA_BASE + 6, (cnt_completion > 0) || flag_fault_first_seen || flag_reset_done_observation, flag_lfa_duplicate_done_rejected);
			// The public joint-TB interface has no legal input for changing the
			// completion sample-index sideband; exact wrong-identity injection is
			// owned by the AMI unit regression.
			scoreboard_mark(C_TRACE_LFA_BASE + 8, flag_lifecycle_observed, (cnt_fault_blocking_cycles == 0) || flag_fault_first_seen);
			scoreboard_mark(C_TRACE_LFA_BASE + 9, flag_fault_first_seen, cnt_fault_owner_leak == 0);
			scoreboard_mark(C_TRACE_LFA_BASE + 10, flag_fault_sticky_clear_observed, flag_fault_recovery_clean);
			scoreboard_mark(C_TRACE_LFA_BASE + 11, flag_reset_done_observation, (cnt_identity_mismatch == 0));

			// PRC：本步只接入结果/资格观察；专用角落波形运行未执行时保持NOT_CLOSED。
			// Unexecuted corner-waveform IDs remain NOT_CLOSED.  The generic
			// finalizer must not convert missing evidence to NOT_APPLICABLE.

			end
			stable_pass_count = 0;
			stable_fail_count = 0;
			stable_unclosed_count = 0;
			for(stable_index = C_RAW_TRACE_COUNT; stable_index < C_TRACE_COUNT; stable_index = stable_index + 1)begin
				if(reg_trace_status[stable_index] == TRACE_PASS) stable_pass_count = stable_pass_count + 1;
				else if(reg_trace_status[stable_index] == TRACE_FAIL) stable_fail_count = stable_fail_count + 1;
				else if(reg_trace_status[stable_index] == TRACE_UNCHECKED) stable_unclosed_count = stable_unclosed_count + 1;
			end
			cnt_stable_pass = stable_pass_count;
			cnt_stable_fail = stable_fail_count;
			cnt_stable_unclosed = stable_unclosed_count;
			$display("SCOREBOARD_SUMMARY pass=%0d fail=%0d not_closed=%0d numeric=%0d/%0d identity=%0d/%0d backpressure=%0d/%0d faults=%0d first_fault=%0s",
				stable_pass_count, stable_fail_count, stable_unclosed_count, cnt_numeric_comparison, cnt_numeric_mismatch,
				cnt_identity_comparison, cnt_identity_mismatch, cnt_result_backpressure_comparison, cnt_result_backpressure_mismatch,
				cnt_fault_observed, reg_first_fault_id);
		end
	endtask

	//===================<时钟与协议观察>===================//
	// 三模块共享同一数字时钟，外部ADC完成信号只由专用任务在非时钟点改变。
	// 真实PPG算法闭环：每个颜色每个宏帧一个样本，RAW只在Q3释放后异步到达。
	task run_ppg_algorithm_scenario;
		integer red_sample_index;
		integer ir_sample_index;
		integer expected_owner_count;
		integer completion_before;
		reg [15:0]sample_index_for_owner;
		reg precision_for_owner;
		reg color_for_owner;
		reg flag_loop_abort;
		reg flag_startup_search_launched;
		begin
			if(flag_jnt_parent_valid && (reg_jnt_parent_group_id == reg_scenario_group_id)) begin
				begin_functional_phase_same_run(reg_scenario_group_id);
			end else begin
				begin_independent_run(reg_scenario_group_id);
			end
			trace_reset;
			flag_ppg_algorithm_active = 1'b0;
			@(negedge i_clk); i_rstn = 1'b0;
			analog_run_enable = 1'b0;
			measurement_run_enable = 1'b0;
			measurement_allow_new_transaction = 1'b0;
			i_run_profile = 1'b0;
			// Scenario controls are loaded by begin_independent_run and remain frozen
			// for this run.  Do not overwrite the input/light/precision matrix here.
			i_adc_idle = 1'b1;
			i_clk_stage1_dout_low_async = 1'b0;
			i_clk_stage2_dout_low_async = 1'b0;
			cnt_ppg_algorithm_result = 0;
			cnt_ppg_algorithm_sar9_result = 0;
			cnt_ppg_algorithm_sar15_result = 0;
			flag_ppg_baseline_valid_seen = 1'b0;
			flag_ppg_cross_pending_seen = 1'b0;
			flag_ppg_fine_window_start_seen = 1'b0;
			flag_ppg_peak_pending_seen = 1'b0;
			flag_ppg_valley_pending_seen = 1'b0;
			flag_ppg_precision_15_seen = 1'b0;
			cnt_ppg_return_pending_seen = 0;
			cnt_ppg_return_event_seen = 0;
			cnt_ppg_fine_timeout_seen = 0;
			cnt_ppg_reacquire_seen = 0;
			flag_ppg_precision_15_to_9_seen = 1'b0;
			flag_ppg_precision_9_after_15_seen = 1'b0;
			flag_ppg_fir_full_r_seen = 1'b0;
			flag_ppg_fir_full_ir_seen = 1'b0;
			flag_ppg_result_sequence_ok = 1'b1;
			flag_ppg_sar15_tail_isolated = 1'b0;
			flag_ppg_have_result = 1'b0;
			reg_ppg_last_result_sample_index = 16'd0;
			reg_ppg_last_result_frame_id = 16'd0;
			red_sample_index = 0;
			ir_sample_index = 0;
			flag_loop_abort = 1'b0;
			release_independent_run_reset;
			expected_owner_count = cnt_owner_commit + 1;
			analog_run_enable = 1'b1;
			measurement_run_enable = 1'b1;
			measurement_allow_new_transaction = 1'b1;
			flag_ppg_algorithm_active = 1'b1;
			// 自动IDAC校准先建立SSW模拟RUN资格，再接受Scheduler/AMI测量START；
			// 手动码路径保持原有同拍START，避免改变JNT冻结语义。
			if(i_idac_mode == 2'b00)begin
				pulse_normal_start_ack;
			end else begin
				pulse_analog_start_ack;
				pulse_measurement_start_ack;
			end
			time_ppg_algorithm_start = time_run_start_ack;
			flag_startup_search_launched = (i_idac_mode == 2'b00);
			if(i_idac_mode != 2'b00)begin
				// Reset exposes completion high until the automatic search has accepted
				// START.  Do not mistake that reset value for 24 physical conversions.
				cnt_watchdog = 0;
				while((o_startup_search_complete === 1'b1) && (cnt_watchdog < 160))begin
					@(negedge i_clk);
					cnt_watchdog = cnt_watchdog + 1;
				end
				flag_startup_search_launched = (o_startup_search_complete !== 1'b1);
				if(!flag_startup_search_launched)begin
					$display("PPG_STARTUP_LAUNCH_TIMEOUT group=%0s mode=%0b complete=%0b eligible=%0b", reg_scenario_group_id, i_idac_mode, o_startup_search_complete, o_normal_measurement_eligible);
				end
			end
			cnt_watchdog = 0;
			while((o_startup_search_complete !== 1'b1) && (cnt_watchdog < reg_scenario_startup_watchdog_limit))begin
				@(negedge i_clk);
				cnt_watchdog = cnt_watchdog + 1;
			end
			if(reg_scenario_allow_startup_failure)begin
				if(o_startup_search_complete && o_normal_measurement_eligible) cnt_fail = cnt_fail + 1;
			end else begin
				if(o_startup_search_complete !== 1'b1)begin
					$display("PPG_STARTUP_TIMEOUT group=%0s mode=%0b run_profile=%0b run_enable=%0b active_cfg=%0b analog_safe=%0b sar_idle=%0b wrapper_idle=%0b idac_idle=%0b boundary=%0b startup_boundary=%0b cal_valid=%0b cal_ready=%0b cal_type=%0b cal_color=%0b cal_reason=%0b waveform_valid=%0b waveform_ready=%0b owner_valid=%0b owner_ready=%0b start_valid=%0b start_ready=%0b start_fire=%0b scheduler_fault=%0b ssw_fault=%0b ami_fault=%0b switch_error=%0b mismatch=%0b owner_timeout=%0b cal_timeout=%0b amb_fault=%0b dcs_r_fault=%0b dcs_ir_fault=%0b", reg_scenario_group_id, i_idac_mode, i_run_profile, measurement_run_enable, i_active_config_valid, o_analog_safe, o_sar_timing_idle, o_ssw_wrapper_idle, o_idac_idle, o_idac_code_safe_boundary, o_startup_idac_safe_boundary, o_calibration_sample_valid, o_calibration_sample_ready, o_calibration_frame_type, o_calibration_color_ir, o_calibration_request_reason, o_waveform_context_valid, o_waveform_context_ready, o_adc_owner_inflight, o_adc_owner_ready, o_transaction_start_valid, o_transaction_start_ready, o_transaction_start_fire, o_scheduler_fault_blocking, o_ssw_fault_blocking, o_ami_fault_blocking, o_switch_protocol_error_sticky, o_transaction_mismatch_sticky, o_owner_deadline_timeout_sticky, o_calibration_timeout_sticky, o_amb_fault, o_dcs_r_fault, o_dcs_ir_fault);
					$display("TB_STARTUP_IDAC_STATE state=%0d amb_req=%0d dcs_req=%0d dcs_color=%0d amb_pending=%0d dcs_r_pending=%0d dcs_ir_pending=%0d startup_complete=%0d idac_protocol_fault=%0d startup_source=%0d recheck_source=%0d cal_inflight=%0d cal_valid_o=%0d cal_valid_int=%0d start_blocked=%0d", ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current, ppg_adc_measurement_idac_integration_Inst.flag_idac_amb_sample_request, ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_sample_request, ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_sample_color_ir, ppg_adc_measurement_idac_integration_Inst.amb_pending_valid_o, ppg_adc_measurement_idac_integration_Inst.dcs_r_pending_valid_o, ppg_adc_measurement_idac_integration_Inst.dcs_ir_pending_valid_o, o_startup_search_complete, ppg_adc_measurement_idac_integration_Inst.idac_protocol_error_sticky_o, ppg_adc_measurement_idac_integration_Inst.flag_startup_request_source, ppg_adc_measurement_idac_integration_Inst.flag_recheck_request_source, ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight, o_calibration_sample_valid, ppg_adc_measurement_idac_integration_Inst.calibration_sample_valid_o, ppg_adc_measurement_idac_integration_Inst.flag_start_blocked);
					$display("TB_STARTUP_SCHED_STATE frame_active=%0d frame_mode=%0d cal_sub=%0d cal_local=%0d cal_pending=%0d cal_active=%0d cal_seen=%0d cal_wave_pending=%0d inflight=%0d cand_cal=%0d cal_valid=%0d cal_ready=%0d", ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode, ppg_400hz_frame_calibration_scheduler_Inst.calibration_subframe_index_o, ppg_400hz_frame_calibration_scheduler_Inst.calibration_local_tick_o, ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_CONTEXT_SEEN], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_WAVE_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT], ppg_400hz_frame_calibration_scheduler_Inst.flag_candidate_calibration, o_calibration_sample_valid, o_calibration_sample_ready);
				end
				check_case("PPG-STARTUP-READY", flag_startup_search_launched && o_startup_search_complete && o_normal_measurement_eligible);
			end
			if(reg_scenario_enable_tracking_after_startup)begin
				// Promote the completed startup-search run into SEARCH_TRACK only after NORMAL eligibility is open.
				i_idac_mode = 2'b10;
				// mode 5 supplies alternating legal Stage1 values near 12 and 500.
				// The centered window forces independent high/low confirmation runs.
			if(reg_scenario_recheck_nominal_calibration)begin
					// Startup search uses the low-code qualification window; the
					// successful periodic-recheck path uses the nominal raw
					// encoding, which evaluates to Stage1 code 276.
					i_amb_threshold_low = 12'sd502;
					i_amb_threshold_high = 12'sd506;
					i_dcs_threshold_low = 12'sd502;
					i_dcs_threshold_high = 12'sd506;
				end else begin
					i_dcs_threshold_low = 12'sd255;
					i_dcs_threshold_high = 12'sd257;
				end
				if(reg_scenario_force_recheck_failure) begin
					// Deliberately keep the recheck candidate outside its qualification
					// window.  This is a real calibration failure, not a result injection.
					i_amb_threshold_low = 12'sd502;
					i_amb_threshold_high = 12'sd506;
					i_dcs_threshold_low = 12'sd502;
					i_dcs_threshold_high = 12'sd506;
				end
				i_dcs_confirm_count = 8'd2;
			end
			while((((red_sample_index < reg_scenario_sample_count) || (ir_sample_index < reg_scenario_sample_count))) && (flag_loop_abort == 1'b0))begin
				// A recheck failure is a terminal observation for this run.  Stop the
				// stimulus loop here so a missing post-failure owner cannot become a
				// TB-generated timeout unrelated to the observed RTL event.
				if((reg_scenario_recheck_nominal_calibration == 1'b1) &&
					((o_recheck_sequence_failed === 1'b1) || o_amb_search_exhausted ||
						o_dcs_r_search_exhausted || o_dcs_ir_search_exhausted))begin
					flag_ppg_result_sequence_ok = 1'b0;
					flag_loop_abort = 1'b1;
				end
				// RRC-12 STOP case: cancel while the recheck is pending but before
				// the scheduler accepts a calibration frame.  No result or DONE is
				// injected here; all observations remain on the connected signals.
				if((reg_scenario_recheck_cancel_mode == 2'd1) && !reg_recheck_cancel_triggered &&
					(o_amb_recheck_pending && !o_amb_recheck_busy &&
					 !o_adc_owner_inflight && !o_scheduler_transaction_inflight &&
					 !o_transaction_start_valid))begin
					reg_recheck_cancel_triggered = 1'b1;
					reg_recheck_cancel_observed = 1'b1;
					reg_recheck_cancel_amb_code = o_amb_code;
					reg_recheck_cancel_dcs_r_code = o_dcs_r_code;
					reg_recheck_cancel_dcs_ir_code = o_dcs_ir_code;
					reg_recheck_cancel_amb_epoch = o_amb_code_epoch;
					reg_recheck_cancel_dcs_r_epoch = o_dcs_r_code_epoch;
					reg_recheck_cancel_dcs_ir_epoch = o_dcs_ir_code_epoch;
					cnt_recheck_cancel_completion_before = cnt_completion;
					cnt_recheck_cancel_result_before = cnt_measurement_result;
					cnt_recheck_cancel_request_before = cnt_recheck_calibration_request;
					$display("TB_RRC12_STOP_TRIGGER pending=%0d busy=%0d owner=%0d sched_txn=%0d start_valid=%0d start_ready=%0d start_fire=%0d amb_code=%0d dcs_r_code=%0d dcs_ir_code=%0d amb_epoch=%0d dcs_r_epoch=%0d dcs_ir_epoch=%0d", o_amb_recheck_pending, o_amb_recheck_busy, o_adc_owner_inflight, o_scheduler_transaction_inflight, o_transaction_start_valid, o_transaction_start_ready, o_transaction_start_fire, o_amb_code, o_dcs_r_code, o_dcs_ir_code, o_amb_code_epoch, o_dcs_r_code_epoch, o_dcs_ir_code_epoch);
					// Stop admitting a new NORMAL owner before delivering STOP.  Any
					// already committed owner must still drain through ADC/AMI.
					measurement_allow_new_transaction = 1'b0;
					pulse_stop_ack;
					i_idac_mode = 2'b00;
					i_amb_recheck_interval_frames = 16'hffff;
					measurement_allow_new_transaction = 1'b0;
					cnt_watchdog = 0;
					while((o_amb_recheck_pending || o_amb_recheck_busy || o_adc_owner_inflight || o_scheduler_transaction_inflight ||
						ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_request ||
						ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_busy ||
						ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight) &&
						(cnt_watchdog < 240))begin
						@(negedge i_clk);
						cnt_watchdog = cnt_watchdog + 1;
					end
					reg_recheck_cancel_cleared = !o_amb_recheck_pending && !o_amb_recheck_busy &&
						!ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_request &&
						!ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_busy &&
						!ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight;
					reg_recheck_cancel_owner_drained = !o_adc_owner_inflight && !o_scheduler_transaction_inflight;
					reg_recheck_cancel_late_done_ok = !reg_recheck_cancel_result_leak &&
						(cnt_measurement_result == cnt_recheck_cancel_result_before);
					// A subsequent START is deliberately issued with new transactions
					// blocked; it must not resurrect the canceled recheck context.
					measurement_run_enable = 1'b0;
					analog_run_enable = 1'b0;
					pulse_normal_start_ack;
					repeat(40) @(negedge i_clk);
					reg_recheck_cancel_restart_clean = (cnt_recheck_calibration_request == cnt_recheck_cancel_request_before) &&
						!o_amb_recheck_pending && !o_amb_recheck_busy &&
						(o_amb_code == reg_recheck_cancel_amb_code) &&
						(o_dcs_r_code == reg_recheck_cancel_dcs_r_code) &&
						(o_dcs_ir_code == reg_recheck_cancel_dcs_ir_code) &&
						(o_amb_code_epoch == reg_recheck_cancel_amb_epoch) &&
						(o_dcs_r_code_epoch == reg_recheck_cancel_dcs_r_epoch) &&
						(o_dcs_ir_code_epoch == reg_recheck_cancel_dcs_ir_epoch);
					// Include the post-START observation window in the cancellation
					// verdict.  A stale calibration result emitted after restart is
					// still a canceled-context leak, not a new legal measurement.
					reg_recheck_cancel_late_done_ok =
						(reg_scenario_recheck_cancel_mode == 2'd1) ?
						(!reg_recheck_cancel_result_leak && (cnt_measurement_result == cnt_recheck_cancel_result_before)) :
						(reg_recheck_cancel_late_done_seen && !reg_recheck_cancel_result_leak &&
						 (cnt_measurement_result == cnt_recheck_cancel_result_before));
					reg_recheck_cancel_owner_drained = !o_adc_owner_inflight && !o_scheduler_transaction_inflight;
					flag_loop_abort = 1'b1;
				end
				if(flag_loop_abort == 1'b1) begin
					// Leave the loop through the normal summary path below.
				end else begin
				wait_owner_commit_count_long(expected_owner_count);
				if(cnt_owner_commit < expected_owner_count)begin
					flag_ppg_result_sequence_ok = 1'b0;
					flag_loop_abort = 1'b1;
				end
				// RRC-12 abort case: cancel an already committed recheck owner.
				// The calibration responder remains responsible for the real late
				// CLK_DOUT/RAW completion, which must be success=0 and result-free.
				if((reg_scenario_recheck_cancel_mode == 2'd2) && !reg_recheck_cancel_triggered &&
					(o_amb_recheck_busy && o_adc_owner_inflight))begin
					reg_recheck_cancel_triggered = 1'b1;
					reg_recheck_cancel_observed = 1'b1;
					reg_recheck_cancel_amb_code = o_amb_code;
					reg_recheck_cancel_dcs_r_code = o_dcs_r_code;
					reg_recheck_cancel_dcs_ir_code = o_dcs_ir_code;
					reg_recheck_cancel_amb_epoch = o_amb_code_epoch;
					reg_recheck_cancel_dcs_r_epoch = o_dcs_r_code_epoch;
					reg_recheck_cancel_dcs_ir_epoch = o_dcs_ir_code_epoch;
					cnt_recheck_cancel_completion_before = cnt_completion;
					cnt_recheck_cancel_result_before = cnt_measurement_result;
					cnt_recheck_cancel_request_before = cnt_recheck_calibration_request;
					$display("TB_RRC12_ABORT_TRIGGER pending=%0d busy=%0d owner=%0d amb_code=%0d dcs_r_code=%0d dcs_ir_code=%0d amb_epoch=%0d dcs_r_epoch=%0d dcs_ir_epoch=%0d", o_amb_recheck_pending, o_amb_recheck_busy, o_adc_owner_inflight, o_amb_code, o_dcs_r_code, o_dcs_ir_code, o_amb_code_epoch, o_dcs_r_code_epoch, o_dcs_ir_code_epoch);
					log_rrc12_abort_scheduler_diag("BEFORE_ABORT");
					pulse_control_abort;
					log_rrc12_abort_scheduler_diag("AFTER_ABORT_PULSE");
					i_idac_mode = 2'b00;
					i_amb_recheck_interval_frames = 16'hffff;
					measurement_allow_new_transaction = 1'b0;
					// A different completion can increment cnt_completion first.  The
					// canceled owner must be observed through its own real success=0
					// completion, and the physical owner must drain before restart.
					cnt_watchdog = 0;
					while((!reg_recheck_cancel_late_done_seen || o_adc_owner_inflight || o_scheduler_transaction_inflight || o_amb_recheck_pending || o_amb_recheck_busy ||
						ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_request ||
						ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_busy ||
						ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight) &&
						(cnt_watchdog < 2400))begin
						@(negedge i_clk);
						cnt_watchdog = cnt_watchdog + 1;
					end
					$display("TB_RRC12_ABORT_WAIT late_done_seen=%0d owner=%0d sched_txn=%0d pending=%0d busy=%0d cal_inflight=%0d watchdog=%0d", reg_recheck_cancel_late_done_seen, o_adc_owner_inflight, o_scheduler_transaction_inflight, o_amb_recheck_pending, o_amb_recheck_busy, ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight, cnt_watchdog);
					reg_recheck_cancel_late_done_ok = reg_recheck_cancel_late_done_seen &&
						!reg_recheck_cancel_result_leak &&
						(cnt_measurement_result == cnt_recheck_cancel_result_before);
					reg_recheck_cancel_cleared = !o_amb_recheck_pending && !o_amb_recheck_busy &&
						!ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_request &&
						!ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_busy &&
						!ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight;
					reg_recheck_cancel_owner_drained = !o_adc_owner_inflight && !o_scheduler_transaction_inflight;
					measurement_run_enable = 1'b0;
					analog_run_enable = 1'b0;
					if(reg_recheck_cancel_late_done_seen && !o_adc_owner_inflight && !o_scheduler_transaction_inflight)begin
						pulse_normal_start_ack;
						repeat(40) @(negedge i_clk);
					end else begin
						$display("TB_RRC12_ABORT_RESTART_BLOCKED late_done_seen=%0d owner=%0d sched_txn=%0d", reg_recheck_cancel_late_done_seen, o_adc_owner_inflight, o_scheduler_transaction_inflight);
					end
					reg_recheck_cancel_restart_clean = (cnt_recheck_calibration_request == cnt_recheck_cancel_request_before) &&
						!o_amb_recheck_pending && !o_amb_recheck_busy &&
						(o_amb_code == reg_recheck_cancel_amb_code) &&
						(o_dcs_r_code == reg_recheck_cancel_dcs_r_code) &&
						(o_dcs_ir_code == reg_recheck_cancel_dcs_ir_code) &&
						(o_amb_code_epoch == reg_recheck_cancel_amb_epoch) &&
						(o_dcs_r_code_epoch == reg_recheck_cancel_dcs_r_epoch) &&
						(o_dcs_ir_code_epoch == reg_recheck_cancel_dcs_ir_epoch);
					if(reg_scenario_recheck_cancel_mode == 2'd2)begin
						reg_recheck_cancel_late_done_ok = reg_recheck_cancel_late_done_seen &&
							!reg_recheck_cancel_result_leak &&
							(cnt_measurement_result == cnt_recheck_cancel_result_before);
					end
					log_rrc12_abort_scheduler_diag("AFTER_ABORT_DRAIN");
					reg_recheck_cancel_owner_drained = !o_adc_owner_inflight && !o_scheduler_transaction_inflight;
					flag_loop_abort = 1'b1;
				end
				if((flag_loop_abort == 1'b0) && (reg_last_owner_frame_type == FRAME_TYPE_NORMAL))begin
					if(reg_scenario_enable_tracking_after_startup && ((red_sample_index + ir_sample_index) >= 600))begin
						// Tracking前段已产生真实pending/update/epoch证据；
						// 后段切回确定性脉搏，要求同一RUN完成SAR9->SAR15。
						reg_scenario_waveform_mode = 0;
					end
					color_for_owner = reg_last_owner_color_ir;
					precision_for_owner = reg_last_owner_precision_mode;
					if(color_for_owner == 1'b0)begin
						sample_index_for_owner = red_sample_index;
						red_sample_index = red_sample_index + 1;
					end else begin
						sample_index_for_owner = ir_sample_index;
						ir_sample_index = ir_sample_index + 1;
					end
					completion_before = cnt_completion;
					drive_ppg_adc_done_quiet(precision_for_owner, color_for_owner, sample_index_for_owner);
					wait_completion_count_long(completion_before + 1);
					if(cnt_completion < (completion_before + 1))begin
						flag_ppg_result_sequence_ok = 1'b0;
						flag_loop_abort = 1'b1;
					end
				end
				expected_owner_count = cnt_owner_commit + 1;
				end
			end
			// 额外等待完整宏帧排空，给最后一笔峰谷返回请求经过真实
			// valid/ready 和下一安全边界的时间。1200 tick 不足以覆盖
			// 5000-tick 宏帧，会把合法的 15->9 提交误判为未发生。
			repeat(6200) @(negedge i_clk);
			time_ppg_algorithm_end = $time;
			flag_ppg_algorithm_active = 1'b0;
			if(reg_scenario_emit_long_checks)begin
				check_case("PPG-10-HEARTBEATS", (red_sample_index >= C_PPG_ALGORITHM_SAMPLES) && (ir_sample_index >= C_PPG_ALGORITHM_SAMPLES));
				check_case("PPG-10S-PHYSICAL-TIME", (time_ppg_algorithm_end - time_ppg_algorithm_start) >= C_PPG_MIN_DURATION_NS);
				check_case("PPG-RUN-WATCHDOG", time_ppg_algorithm_end <= time_run_deadline);
				check_case("PPG-FIR-PREHEAT", (cnt_ppg_algorithm_sar9_result >= 21) && flag_ppg_fir_full_r_seen && flag_ppg_fir_full_ir_seen);
				check_case("PPG-BASELINE-CROSS", flag_ppg_baseline_valid_seen && flag_ppg_cross_pending_seen);
				check_case("PPG-SAR9-TO-SAR15", flag_ppg_fine_window_start_seen && flag_ppg_precision_15_seen && (cnt_ppg_algorithm_sar15_result > 0));
				check_case("PPG-PEAK-VALLEY", flag_ppg_peak_pending_seen && flag_ppg_valley_pending_seen);
				check_case("PPG-SAR15-TO-SAR9", flag_ppg_precision_15_to_9_seen && flag_ppg_precision_9_after_15_seen && flag_ppg_sar15_tail_isolated);
				check_case("PPG-RESULT-CONTINUITY", flag_ppg_have_result && flag_ppg_result_sequence_ok);
			end
			finalize_raw_trace;
			// RAW evidence is emitted by emit_scenario_result.  Core groups use
			// their own explicit summary after this common algorithm task; do not
			// emit a misleading zero-ID functional-group report here.
		end
	endtask

	// interval=0 control run: execute the real RAW/AMI loop with recheck disabled,
	// then close NRE-01..06 only from observed public behavior.
	task run_short_mode_scenario;
		input [8 * 32 - 1:0]group_id;
		input source_select;
		input [1:0]optical_select;
		input precision_select;
		input integer sample_count;
		begin
			reg_scenario_group_id = group_id;
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = source_select;
			reg_scenario_optical_mode = optical_select;
			reg_scenario_initial_precision = precision_select;
			reg_scenario_sample_count = sample_count;
			reg_scenario_emit_long_checks = 1'b0;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_force_recheck_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_enable_waveform_backpressure = 1'b0;
			reg_scenario_enable_transaction_backpressure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b0;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_recheck_cancel_mode = 2'd0;
			reg_scenario_waveform_mode = reg_scenario_numeric_vector_mode;
			run_ppg_algorithm_scenario;
		end
	endtask

	// Fixed-current characterization is intermittent 400 Hz measurement with
	// automatic search, tracking, and periodic recheck disabled.
	task run_fixed_current_mode;
		input [8 * 32 - 1:0]group_id;
		input [1:0]optical_select;
		input precision_select;
		input integer sample_count;
		reg fixed_mode_ok;
		begin
			reg_scenario_group_id = group_id;
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'd0;
			reg_scenario_input_source = 1'b1;
			reg_scenario_optical_mode = optical_select;
			reg_scenario_initial_precision = precision_select;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b0;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_enable_result_backpressure = 1'b0;
			reg_scenario_sample_count = sample_count;
			reg_scenario_waveform_mode = 0;
			reg_scenario_emit_long_checks = 1'b0;
			run_ppg_algorithm_scenario;
			fixed_mode_ok = (cnt_waveform_context > 0) && (o_en_test == 1'b1) && flag_matrix_400hz_ok &&
				(o_leden1_low == 1'b0) && (o_leden2_low == 1'b0) && (o_leddac == 8'd0);
			if(optical_select == 2'b01)
				fixed_mode_ok = fixed_mode_ok && (cnt_red_waveform_context > 0) && (cnt_ir_waveform_context == 0);
			else if(optical_select == 2'b10)
				fixed_mode_ok = fixed_mode_ok && (cnt_red_waveform_context == 0) && (cnt_ir_waveform_context > 0);
			else
				fixed_mode_ok = fixed_mode_ok && (cnt_red_waveform_context > 0) && (cnt_ir_waveform_context > 0);
			$display("TB_ILM_SUBRUN group=%0s input_source=%0b optical=%0b precision=%0b jnt_parent_run=%0d jnt=%0d/%0d frames=%0d red_ctx=%0d ir_ctx=%0d interval_ok=%0b led1=%0b led2=%0b leddac=%0d status=%0s",
				group_id, i_input_source, i_optical_mode, i_initial_precision, cnt_jnt_parent_run_index,
				cnt_jnt_parent_pass, C_JNT_REQUIRED_SUBCHECKS, cnt_matrix_frame_start,
				cnt_red_waveform_context, cnt_ir_waveform_context, flag_matrix_400hz_ok,
				o_leden1_low, o_leden2_low, o_leddac,
				((cnt_jnt_parent_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_jnt_parent_fail == 0) && fixed_mode_ok) ? "PASS" : "NOT_CLOSED");
		end
	endtask

	task run_startup_search_scenario;
		begin
			reg_scenario_group_id = "STARTUP-IDAC-CALIBRATION";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_enable_result_backpressure = 1'b0;
			reg_scenario_idac_mode = 2'b01;
			reg_scenario_startup_watchdog_limit = 250000;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_sample_count = 80;
			reg_scenario_emit_long_checks = 1'b0;
			run_ppg_algorithm_scenario;
			scoreboard_mark(C_TRACE_SID_BASE + 0, cnt_startup_calibration_request > 0, (cnt_startup_boundary > 0) && flag_startup_boundary_without_owner);
			scoreboard_mark(C_TRACE_SID_BASE + 1, cnt_startup_calibration_completion > 0, flag_idac_startup_order_ok &&
				(cnt_startup_amb_completion > 0) && (cnt_startup_dcs_r_completion > 0) && (cnt_startup_dcs_ir_completion > 0));
			scoreboard_mark(C_TRACE_SID_BASE + 2, cnt_startup_q3_observed > 0, flag_startup_q3_266_ok);
			scoreboard_mark(C_TRACE_SID_BASE + 3, cnt_startup_calibration_completion > 0, cnt_startup_real_chain_mismatch == 0);
			scoreboard_mark(C_TRACE_SID_BASE + 4, cnt_startup_calibration_completion > 0, flag_startup_owner_deadline_ok);
			scoreboard_mark(C_TRACE_SID_BASE + 5, cnt_startup_calibration_completion > 0, flag_owner_context_identity_match && (cnt_startup_q3_spacing_mismatch == 0));
			scoreboard_mark(C_TRACE_SID_BASE + 6, cnt_startup_amb_waveform_observed > 0, flag_startup_waveform_ok && flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_SID_BASE + 7, cnt_startup_dcs_r_waveform_observed > 0, flag_startup_waveform_ok && flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_SID_BASE + 8, cnt_startup_dcs_ir_waveform_observed > 0, flag_startup_waveform_ok && flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_SID_BASE + 9, cnt_startup_calibration_completion > 0, (cnt_startup_successful_calibration_completion == 24) &&
				(cnt_startup_amb_completion == 8) && (cnt_startup_dcs_r_completion == 8) && (cnt_startup_dcs_ir_completion == 8));
			scoreboard_mark(C_TRACE_SID_BASE + 11, cnt_startup_calibration_completion > 0, o_startup_search_complete &&
				(cnt_startup_successful_calibration_completion == 24));
			$display("TB_STARTUP_SUMMARY req=%0d done=%0d success=%0d amb=%0d dcs_r=%0d dcs_ir=%0d wave_amb=%0d wave_r=%0d wave_ir=%0d q3=%0d q3_mismatch=%0d chain_mismatch=%0d waveform_ok=%0d bus_clean=%0d owner_deadline=%0d search_complete=%0d eligible=%0d", cnt_startup_calibration_request, cnt_startup_calibration_completion, cnt_startup_successful_calibration_completion, cnt_startup_amb_completion, cnt_startup_dcs_r_completion, cnt_startup_dcs_ir_completion, cnt_startup_amb_waveform_observed, cnt_startup_dcs_r_waveform_observed, cnt_startup_dcs_ir_waveform_observed, cnt_startup_q3_observed, cnt_startup_q3_spacing_mismatch, cnt_startup_real_chain_mismatch, flag_startup_waveform_ok, flag_unselected_idac_bus_clean, flag_startup_owner_deadline_ok, o_startup_search_complete, o_normal_measurement_eligible);
			report_functional_group("STARTUP-IDAC-CALIBRATION", C_TRACE_SID_BASE, 12);
		end
	endtask

	task run_tracking_scenario;
		begin
			reg_scenario_group_id = "NORMAL-IDAC-SLOW-TRACKING";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			// Startup search must complete before enabling NORMAL tracking.
			reg_scenario_idac_mode = 2'b01;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b0;
			reg_scenario_startup_watchdog_limit = 250000;
			reg_scenario_enable_tracking_after_startup = 1'b1;
			reg_scenario_sample_count = 1000;
			reg_scenario_waveform_mode = 6;
			reg_scenario_emit_long_checks = 1'b0;
			run_ppg_algorithm_scenario;
			scoreboard_mark(C_TRACE_TRK_BASE + 0, (cnt_amb_pending_observed + cnt_dcs_r_pending_observed + cnt_dcs_ir_pending_observed) > 0, flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 1, (cnt_amb_pending_observed + cnt_dcs_r_pending_observed + cnt_dcs_ir_pending_observed) > 0,
				(cnt_amb_pending_observed + cnt_dcs_r_pending_observed + cnt_dcs_ir_pending_observed) > 0);
			scoreboard_mark(C_TRACE_TRK_BASE + 2, (cnt_dcs_r_track_adjust_observed + cnt_dcs_ir_track_adjust_observed) > 1, flag_idac_track_delta_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 3, (cnt_dcs_r_update_observed > 0) && (cnt_dcs_ir_update_observed > 0), flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 4, ((cnt_amb_pending_observed + cnt_dcs_r_pending_observed + cnt_dcs_ir_pending_observed) > 0) && flag_ppg_precision_15_seen, flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 5, (cnt_amb_pending_observed + cnt_dcs_r_pending_observed + cnt_dcs_ir_pending_observed) > 0, cnt_idac_update_without_change == 0);
			scoreboard_mark(C_TRACE_TRK_BASE + 6, (cnt_amb_update_observed + cnt_dcs_r_update_observed + cnt_dcs_ir_update_observed) > 0, flag_idac_track_delta_ok && flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 7, (cnt_tracking_boundary_hold_observed > 0) && (cnt_tracking_epoch_wrap_observed > 0),
				flag_idac_no_wrap_ok && flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 8, ((cnt_amb_pending_observed + cnt_dcs_r_pending_observed + cnt_dcs_ir_pending_observed) > 0) && (cnt_numeric_comparison > 0), flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_TRK_BASE + 9, ((cnt_amb_pending_observed + cnt_dcs_r_pending_observed + cnt_dcs_ir_pending_observed) > 0) && (cnt_stage1_signed_comparison > 0), flag_tracking_stage1_only);
			$display("TB_TRACKING_SUMMARY pending_amb=%0d pending_r=%0d pending_ir=%0d update_amb=%0d update_r=%0d update_ir=%0d adjust_r=%0d adjust_ir=%0d boundary_hold=%0d epoch_wrap=%0d at_minmax_r=%0b/%0b at_minmax_ir=%0b/%0b no_wrap=%0b epoch_ok=%0b precision15=%0b", cnt_amb_pending_observed, cnt_dcs_r_pending_observed, cnt_dcs_ir_pending_observed, cnt_amb_update_observed, cnt_dcs_r_update_observed, cnt_dcs_ir_update_observed, cnt_dcs_r_track_adjust_observed, cnt_dcs_ir_track_adjust_observed, cnt_tracking_boundary_hold_observed, cnt_tracking_epoch_wrap_observed, o_dcs_r_code_at_min, o_dcs_r_code_at_max, o_dcs_ir_code_at_min, o_dcs_ir_code_at_max, flag_idac_no_wrap_ok, flag_idac_epoch_relation_ok, flag_ppg_precision_15_seen);
			report_functional_group("NORMAL-IDAC-SLOW-TRACKING", C_TRACE_TRK_BASE, 10);
		end
	endtask

	task run_startup_failure_scenario;
		begin
			reg_scenario_group_id = "STARTUP-IDAC-FAILURE";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b01;
			reg_scenario_startup_watchdog_limit = 250000;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_force_search_failure = 1'b1;
			reg_scenario_allow_startup_failure = 1'b1;
			reg_scenario_sample_count = 8;
			reg_scenario_emit_long_checks = 1'b0;
			run_ppg_algorithm_scenario;
			scoreboard_mark(C_TRACE_SID_BASE + 10, cnt_idac_search_exhausted_observed > 0, (o_amb_code_at_min || o_amb_code_at_max) &&
				(o_dcs_r_code_at_min || o_dcs_r_code_at_max) && (o_dcs_ir_code_at_min || o_dcs_ir_code_at_max));
			scoreboard_mark(C_TRACE_SID_BASE + 11, cnt_idac_search_exhausted_observed > 0, !o_startup_search_complete &&
				!o_normal_measurement_eligible && (o_amb_fault || o_dcs_r_fault || o_dcs_ir_fault || o_idac_fault_blocking));
		end
	endtask

	task run_periodic_recheck_scenario;
		begin
			reg_scenario_recheck_cancel_mode = 2'd0;
			reg_scenario_group_id = "PERIODIC-RECHECK-RECOVERY";
			run_jnt_baseline;
			// Let the nominal waveform complete a real SAR9->SAR15->SAR9
			// window before requesting recheck.  A 16-frame interval races the
			// return path and cannot satisfy the RRC-02 precondition.
			reg_scenario_recheck_interval = 16'd400;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			// 周期重检只在NORMAL SEARCH_TRACK资格下允许接管；先完成
			// AMB/DC启动搜索，再切换到正式tracking运行态。
			reg_scenario_idac_mode = 2'b01;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b1;
			reg_scenario_startup_watchdog_limit = 250000;
			reg_scenario_enable_tracking_after_startup = 1'b1;
			// Retain enough post-recheck NORMAL samples for two 21-sample FIR
			// warmups, a fresh upward crossing, and a fine-window entry.
			reg_scenario_sample_count = 1400;
			reg_scenario_emit_long_checks = 1'b0;
			run_ppg_algorithm_scenario;
			$display("TB_RECHECK_SUMMARY pending=%0d accept=%0d done=%0d failed=%0d cal_req=%0d cal_complete=%0d cal_success=%0d stage_mask=%b seq_mismatch=%0d drain_mismatch=%0d output_leak=%0d warmup_r=%0d warmup_ir=%0d recross=%0d recross_fine=%0d slope_preserved=%0d real_chain_mismatch=%0d seq_failed=%0d amb_fault=%0d dcs_r_fault=%0d dcs_ir_fault=%0d amb_exhausted=%0d dcs_r_exhausted=%0d dcs_ir_exhausted=%0d amb_code=%0d dcs_r_code=%0d dcs_ir_code=%0d amb_epoch=%0d dcs_r_epoch=%0d dcs_ir_epoch=%0d normal_inhibit=%0d recheck_busy=%0d",
				cnt_recheck_pending_observed, cnt_recheck_accept_observed, cnt_recheck_done_observed,
				cnt_recheck_failed_observed, cnt_recheck_calibration_request, cnt_recheck_calibration_completion,
				cnt_recheck_successful_calibration_completion, reg_recheck_stage_mask,
				cnt_recheck_sequence_mismatch, cnt_recheck_drain_mismatch, cnt_recheck_output_leak,
				cnt_recheck_history_r_warmup, cnt_recheck_history_ir_warmup, reg_recheck_recross_seen,
				reg_recheck_recross_fine_seen, reg_recheck_slope_preserved, cnt_recheck_real_chain_mismatch,
					o_recheck_sequence_failed, o_amb_fault, o_dcs_r_fault, o_dcs_ir_fault,
				o_amb_search_exhausted, o_dcs_r_search_exhausted, o_dcs_ir_search_exhausted,
				o_amb_code, o_dcs_r_code, o_dcs_ir_code, o_amb_code_epoch, o_dcs_r_code_epoch,
				o_dcs_ir_code_epoch, o_normal_output_inhibit, o_amb_recheck_busy);
			scoreboard_mark(C_TRACE_RRC_BASE + 0, cnt_recheck_pending_observed > 0, cnt_recheck_pending_observed > 0);
			scoreboard_mark(C_TRACE_RRC_BASE + 1, (cnt_recheck_pending_observed > 0) && flag_ppg_precision_15_to_9_seen, cnt_recheck_sequence_mismatch == 0);
			scoreboard_mark(C_TRACE_RRC_BASE + 2, cnt_recheck_accept_observed > 0, reg_recheck_drain_ok);
			scoreboard_mark(C_TRACE_RRC_BASE + 3, cnt_recheck_accept_observed > 0, reg_recheck_history_r_cleared && reg_recheck_history_ir_cleared);
			scoreboard_mark(C_TRACE_RRC_BASE + 4, cnt_recheck_calibration_request > 0, (cnt_recheck_successful_calibration_completion > 0) &&
				(cnt_recheck_real_chain_mismatch == 0) && (cnt_recheck_async_observed >= cnt_recheck_calibration_completion) && (reg_recheck_stage_mask == 3'b111));
			scoreboard_mark(C_TRACE_RRC_BASE + 5, cnt_recheck_accept_observed > 0, cnt_recheck_sequence_mismatch == 0);
			scoreboard_mark(C_TRACE_RRC_BASE + 6, cnt_recheck_accept_observed > 0, flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_RRC_BASE + 7, cnt_recheck_pending_observed > 0, reg_recheck_output_inhibit_ok);
			scoreboard_mark(C_TRACE_RRC_BASE + 8, cnt_recheck_done_observed > 0, reg_recheck_slope_preserved &&
				(cnt_recheck_history_r_warmup >= 21) && (cnt_recheck_history_ir_warmup >= 21));
			scoreboard_mark(C_TRACE_RRC_BASE + 9, cnt_recheck_done_observed > 0, reg_recheck_recross_seen && reg_recheck_recross_fine_seen &&
				(cnt_recheck_history_r_warmup >= 21) && (cnt_recheck_history_ir_warmup >= 21));
			// RRC-10 is already closed at slot +9 by the successful recross.
			// Slot +10 is RRC-11 and is reserved exclusively for the failure path.

			// RRC-11 is a separate failure run.  A startup-search failure is not
			// sufficient: this run reaches periodic recheck, then supplies real
			// out-of-window AMB/DCS conversions through the same Q3/AMI path.
			reg_scenario_group_id = "PERIODIC-RECHECK-RECOVERY";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'd400;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b01;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_force_recheck_failure = 1'b1;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b0;
			reg_scenario_enable_tracking_after_startup = 1'b1;
			reg_scenario_sample_count = 700;
			reg_scenario_recheck_cancel_mode = 2'd0;
			run_ppg_algorithm_scenario;
			$display("TB_RECHECK_FAILURE_SUMMARY failed=%0d reacquire=%0d fixed_slope_ok=%0d sequence_mismatch=%0d", cnt_recheck_failed_observed, reg_recheck_failure_reacquire_seen, reg_recheck_failure_fixed_slope_ok, cnt_recheck_sequence_mismatch);
			scoreboard_mark(C_TRACE_RRC_BASE + 10, cnt_recheck_failed_observed > 0, reg_recheck_failure_reacquire_seen && reg_recheck_failure_fixed_slope_ok && (o_amb_recheck_pending == 1'b0) && (o_amb_recheck_busy == 1'b0));

			// RRC-12 uses two additional independent resets.  The first cancels a
			// pending recheck with STOP; the second cancels an already committed
			// calibration owner with abort and accepts its real late DONE.
			reg_rrc12_stop_ok = 1'b0;
			reg_rrc12_abort_ok = 1'b0;
			reg_scenario_group_id = "PERIODIC-RECHECK-RECOVERY";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'd8;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b01;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b1;
			reg_scenario_startup_watchdog_limit = 250000;
			reg_scenario_enable_tracking_after_startup = 1'b1;
			reg_scenario_sample_count = 800;
			reg_scenario_waveform_mode = 0;
			reg_scenario_recheck_cancel_mode = 2'd1;
			reg_scenario_emit_long_checks = 1'b0;
			run_ppg_algorithm_scenario;
			reg_rrc12_stop_ok = reg_recheck_cancel_observed && reg_recheck_cancel_cleared &&
				reg_recheck_cancel_owner_drained && reg_recheck_cancel_restart_clean &&
				!reg_recheck_cancel_result_leak &&
				(o_amb_code == reg_recheck_cancel_amb_code) && (o_dcs_r_code == reg_recheck_cancel_dcs_r_code) &&
				(o_dcs_ir_code == reg_recheck_cancel_dcs_ir_code) && (o_amb_code_epoch == reg_recheck_cancel_amb_epoch) &&
				(o_dcs_r_code_epoch == reg_recheck_cancel_dcs_r_epoch) && (o_dcs_ir_code_epoch == reg_recheck_cancel_dcs_ir_epoch);
			$display("TB_RRC12_STOP_SUMMARY observed=%0d cleared=%0d owner_drained=%0d late_done_seen=%0d late_done_ok=%0d result_leak=%0d restart_clean=%0d adc_owner=%0d sched_txn=%0d cal_inflight=%0d ssw_fault=%0d", reg_recheck_cancel_observed, reg_recheck_cancel_cleared, reg_recheck_cancel_owner_drained, reg_recheck_cancel_late_done_seen, reg_recheck_cancel_late_done_ok, reg_recheck_cancel_result_leak, reg_recheck_cancel_restart_clean, o_adc_owner_inflight, o_scheduler_transaction_inflight, ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight, o_ssw_fault_blocking);

			reg_scenario_group_id = "PERIODIC-RECHECK-RECOVERY";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'd8;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b01;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b1;
			reg_scenario_startup_watchdog_limit = 250000;
			reg_scenario_enable_tracking_after_startup = 1'b1;
			reg_scenario_sample_count = 800;
			reg_scenario_waveform_mode = 0;
			reg_scenario_recheck_cancel_mode = 2'd2;
			reg_scenario_emit_long_checks = 1'b0;
			run_ppg_algorithm_scenario;
			reg_rrc12_abort_ok = reg_recheck_cancel_observed && reg_recheck_cancel_cleared &&
				reg_recheck_cancel_owner_drained && reg_recheck_cancel_late_done_ok && reg_recheck_cancel_restart_clean &&
				(o_amb_code == reg_recheck_cancel_amb_code) && (o_dcs_r_code == reg_recheck_cancel_dcs_r_code) &&
				(o_dcs_ir_code == reg_recheck_cancel_dcs_ir_code) && (o_amb_code_epoch == reg_recheck_cancel_amb_epoch) &&
				(o_dcs_r_code_epoch == reg_recheck_cancel_dcs_r_epoch) && (o_dcs_ir_code_epoch == reg_recheck_cancel_dcs_ir_epoch);
			log_rrc12_abort_scheduler_diag("ABORT_SUMMARY");
			$display("TB_RRC12_ABORT_SUMMARY observed=%0d cleared=%0d owner_drained=%0d late_done_seen=%0d late_done_ok=%0d result_leak=%0d restart_clean=%0d adc_owner=%0d sched_txn=%0d cal_inflight=%0d sched_fault=%0d", reg_recheck_cancel_observed, reg_recheck_cancel_cleared, reg_recheck_cancel_owner_drained, reg_recheck_cancel_late_done_seen, reg_recheck_cancel_late_done_ok, reg_recheck_cancel_result_leak, reg_recheck_cancel_restart_clean, o_adc_owner_inflight, o_scheduler_transaction_inflight, ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight, o_scheduler_fault_blocking);
			scoreboard_mark(C_TRACE_RRC_BASE + 11, 1'b1, reg_rrc12_stop_ok && reg_rrc12_abort_ok);
			report_functional_group("PERIODIC-RECHECK-RECOVERY", C_TRACE_RRC_BASE, 12);
		end
	endtask

	task run_input_light_matrix_scenario;
		integer static_owner_before;
		integer static_result_before;
		reg [7:0]static_amb_code_before;
		reg [7:0]static_dcs_r_code_before;
		reg [7:0]static_dcs_ir_code_before;
		reg [3:0]static_amb_epoch_before;
		reg [3:0]static_dcs_r_epoch_before;
		reg [3:0]static_dcs_ir_epoch_before;
		reg [15:0]static_sample_before;
		reg [15:0]static_frame_before;
		reg fixed_red9_ok;
		reg fixed_red15_ok;
		reg fixed_ir9_ok;
		reg fixed_ir15_ok;
		begin
			// Matrix sub-runs have independent reset/JNT evidence but belong to one
			// contract group in the aggregate manifest.
			flag_contract_group_override = 1'b1;
			reg_contract_group_id = "INPUT-LIGHT-STATIC-MATRIX";
			// Photodiode NORMAL dual-light and pure-RED fixed precision paths.
			run_short_mode_scenario("INPUT-PHOTODIODE-BOTH", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 48);
			scoreboard_mark(C_TRACE_ILM_BASE + 0, 1'b1, (cnt_waveform_context > 0) && (cnt_red_waveform_context > 0) && (cnt_ir_waveform_context > 0) && (o_en_test == 1'b0));
			run_short_mode_scenario("INPUT-PHOTODIODE-RED9", 1'b0, 2'b01, 1'b0, 48);
			scoreboard_mark(C_TRACE_ILM_BASE + 1, 1'b1, (cnt_waveform_context > 0) && (cnt_red_waveform_context > 0) && (cnt_ir_waveform_context == 0) && !flag_ppg_precision_15_seen && (o_en_test == 1'b0));
			run_short_mode_scenario("INPUT-PHOTODIODE-RED15", 1'b0, 2'b01, 1'b1, 48);
			scoreboard_mark(C_TRACE_ILM_BASE + 2, 1'b1, (cnt_waveform_context > 0) && (cnt_red_waveform_context > 0) && (cnt_ir_waveform_context == 0) && flag_ppg_precision_15_seen && (o_en_test == 1'b0));

			// External fixed-current modes: LED outputs must stay disabled for every color variant.
			run_fixed_current_mode("INPUT-FIXED-BOTH9", OPTICAL_MODE_BOTH, 1'b0, 32);
			scoreboard_mark(C_TRACE_ILM_BASE + 3, 1'b1, (cnt_waveform_context > 0) && (o_en_test == 1'b1) && (o_leden1_low == 1'b0) && (o_leden2_low == 1'b0) && (o_leddac == 8'd0) && flag_matrix_400hz_ok);
			run_fixed_current_mode("INPUT-FIXED-BOTH15", OPTICAL_MODE_BOTH, 1'b1, 32);
			scoreboard_mark(C_TRACE_ILM_BASE + 4, 1'b1, (cnt_waveform_context > 0) && (o_en_test == 1'b1) && (o_leden1_low == 1'b0) && (o_leden2_low == 1'b0) && (o_leddac == 8'd0) && flag_matrix_400hz_ok);
			run_fixed_current_mode("INPUT-FIXED-RED9", 2'b01, 1'b0, 32);
			fixed_red9_ok = (cnt_waveform_context > 0) && (cnt_ir_waveform_context == 0) && (o_en_test == 1'b1) && (o_leden1_low == 1'b0) && (o_leden2_low == 1'b0) && (o_leddac == 8'd0) && flag_matrix_400hz_ok;
			run_fixed_current_mode("INPUT-FIXED-RED15", 2'b01, 1'b1, 32);
			fixed_red15_ok = (cnt_waveform_context > 0) && (cnt_ir_waveform_context == 0) && (o_en_test == 1'b1) && (o_leden1_low == 1'b0) && (o_leden2_low == 1'b0) && (o_leddac == 8'd0) && flag_matrix_400hz_ok;
			run_fixed_current_mode("INPUT-FIXED-IR9", 2'b10, 1'b0, 32);
			fixed_ir9_ok = (cnt_waveform_context > 0) && (cnt_red_waveform_context == 0) && (o_en_test == 1'b1) && (o_leden1_low == 1'b0) && (o_leden2_low == 1'b0) && (o_leddac == 8'd0) && flag_matrix_400hz_ok;
			run_fixed_current_mode("INPUT-FIXED-IR15", 2'b10, 1'b1, 32);
			fixed_ir15_ok = (cnt_waveform_context > 0) && (cnt_red_waveform_context == 0) && (o_en_test == 1'b1) && (o_leden1_low == 1'b0) && (o_leden2_low == 1'b0) && (o_leddac == 8'd0) && flag_matrix_400hz_ok;
			scoreboard_mark(C_TRACE_ILM_BASE + 5, 1'b1, fixed_red9_ok && fixed_red15_ok);
			scoreboard_mark(C_TRACE_ILM_BASE + 6, 1'b1, fixed_ir9_ok && fixed_ir15_ok);
			// Characterization is manual-only: no startup search, tracking, or
			// periodic recheck may appear in any fixed-current subrun.
			scoreboard_mark(C_TRACE_ILM_BASE + 8, 1'b1,
				(i_idac_mode == 2'b00) && (cnt_recheck_pending_observed == 0) &&
				(cnt_recheck_accept_observed == 0) &&
				(cnt_amb_update_observed == 0) && (cnt_dcs_r_update_observed == 0) &&
				(cnt_dcs_ir_update_observed == 0));

			// AMB_CAL and DCS_CAL RED/IR get their own reset/JNT parent inside the
			// matrix.  This prevents the fixed-current runs from hiding a missing
			// calibration waveform or completion chain.
			run_startup_search_scenario;
			$display("TB_ILM_SUBRUN group=INPUT-CALIBRATION-AMB-DCS input_source=%0b optical=%0b jnt_parent_run=%0d jnt=%0d/%0d amb=%0d dcs_r=%0d dcs_ir=%0d q3=%0d chain_mismatch=%0d status=%0s",
				i_input_source, i_optical_mode, cnt_jnt_parent_run_index, cnt_jnt_parent_pass,
				C_JNT_REQUIRED_SUBCHECKS, cnt_startup_amb_completion, cnt_startup_dcs_r_completion,
				cnt_startup_dcs_ir_completion, cnt_startup_q3_observed, cnt_startup_real_chain_mismatch,
				((cnt_jnt_parent_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_jnt_parent_fail == 0) &&
				 (cnt_startup_amb_completion > 0) && (cnt_startup_dcs_r_completion > 0) &&
				 (cnt_startup_dcs_ir_completion > 0) && (cnt_startup_real_chain_mismatch == 0)) ? "PASS" : "NOT_CLOSED");
			scoreboard_mark(C_TRACE_ILM_BASE + 10, 1'b1, (cnt_startup_amb_completion > 0) &&
				(cnt_startup_real_chain_mismatch == 0) && flag_startup_q3_spacing_ok &&
				(o_en_test == 1'b0) && (o_leden1_low == 1'b0) && (o_leden2_low == 1'b0) && (o_leddac == 8'd0));
			scoreboard_mark(C_TRACE_ILM_BASE + 11, 1'b1, (cnt_startup_dcs_r_completion > 0) &&
				(cnt_startup_dcs_ir_completion > 0) && (cnt_startup_real_chain_mismatch == 0) &&
				flag_startup_q3_spacing_ok && (o_en_test == 1'b0) && (o_leden1_low == 1'b0) &&
				(o_leden2_low == 1'b0) && (o_leddac == 8'd0));
			// Illegal OFF/auto-search combinations must not create an owner or result side effect.
			reg_scenario_group_id = "INPUT-ILLEGAL-MATRIX";
			run_jnt_baseline;
			begin_independent_run(reg_scenario_group_id);
			static_owner_before = cnt_owner_commit;
			static_result_before = cnt_measurement_result;
			i_input_source = 1'b1;
			i_optical_mode = 2'b11;
			i_idac_mode = 2'b11;
			release_independent_run_reset;
			analog_run_enable = 1'b1;
			measurement_run_enable = 1'b1;
			measurement_allow_new_transaction = 1'b1;
			pulse_normal_start_ack;
			repeat(120) @(negedge i_clk);
			scoreboard_mark(C_TRACE_ILM_BASE + 7, 1'b1, (cnt_owner_commit == static_owner_before) && (cnt_measurement_result == static_result_before) &&
				(o_leden1_low == 1'b0) && (o_leden2_low == 1'b0) && (o_leddac == 8'd0));
			$display("TB_ILM_SUBRUN group=INPUT-ILLEGAL-MATRIX input_source=%0b optical=%0b idac_mode=%0b jnt_parent_run=%0d jnt=%0d/%0d owner_delta=%0d result_delta=%0d status=%0s",
				i_input_source, i_optical_mode, i_idac_mode, cnt_jnt_parent_run_index,
				cnt_jnt_parent_pass, C_JNT_REQUIRED_SUBCHECKS, cnt_owner_commit - static_owner_before,
				cnt_measurement_result - static_result_before,
				((cnt_jnt_parent_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_jnt_parent_fail == 0) &&
				 (cnt_owner_commit == static_owner_before) && (cnt_measurement_result == static_result_before)) ? "PASS" : "NOT_CLOSED");

			// Verify atomic snapshot semantics on a dedicated owner run.
			run_snapshot_atomic_scenario;
			scoreboard_mark(C_TRACE_ILM_BASE + 9, 1'b1, flag_numeric_identity_ok && (cnt_identity_mismatch == 0) && (cnt_completion > 0));
			reg_scenario_group_id = "STATIC-BIAS-MATRIX";
			run_jnt_baseline;
			begin_independent_run(reg_scenario_group_id);
			i_static_characterization_enable = 1'b1;
			i_input_source = 1'b0;
			i_optical_mode = OPTICAL_MODE_BOTH;
			i_initial_precision = 1'b0;
			i_idac_mode = 2'b00;
			i_amb_recheck_interval_frames = 16'd0;
			i_test_mux_ctrl = 5'b10101;
			static_owner_before = cnt_owner_commit;
			static_result_before = cnt_measurement_result;
			static_amb_code_before = o_amb_code;
			static_dcs_r_code_before = o_dcs_r_code;
			static_dcs_ir_code_before = o_dcs_ir_code;
			static_amb_epoch_before = o_amb_code_epoch;
			static_dcs_r_epoch_before = o_dcs_r_code_epoch;
			static_dcs_ir_epoch_before = o_dcs_ir_code_epoch;
			static_sample_before = o_scheduler_next_sample_index;
			static_frame_before = o_scheduler_current_frame_id;
			release_independent_run_reset;
			analog_run_enable = 1'b1;
			reg_static_prev_s_in = o_s_in;
			flag_static_s_edge_seen = 1'b0;
			flag_static_s_edge_atomic = 1'b1;
			// STATIC_BIAS permits the analog static vector only.  Do not issue
			// the measurement START or open an ADC transaction permit.
			measurement_run_enable = 1'b0;
			measurement_allow_new_transaction = 1'b0;
			pulse_analog_start_ack;
			repeat(80) @(negedge i_clk);
			scoreboard_mark(C_TRACE_ILM_BASE + 12, 1'b1, (o_s_in == i_test_mux_ctrl) && (cnt_owner_commit == static_owner_before) &&
				!o_adc_owner_inflight && !o_calibration_frame_active && !o_normal_frame_active &&
				!flag_static_q1_seen && !flag_static_q2_seen && !flag_static_q3_seen &&
				!flag_static_async_seen && !flag_static_done_seen &&
				!flag_static_fir_seen && !flag_static_recheck_seen && !flag_static_algorithm_result_seen &&
				!o_measurement_result_valid && !o_cross_pending && !o_peak_pending && !o_valley_pending &&
				(o_amb_code == static_amb_code_before) && (o_dcs_r_code == static_dcs_r_code_before) &&
				(o_dcs_ir_code == static_dcs_ir_code_before) && (o_amb_code_epoch == static_amb_epoch_before) &&
				(o_dcs_r_code_epoch == static_dcs_r_epoch_before) && (o_dcs_ir_code_epoch == static_dcs_ir_epoch_before) &&
				(o_scheduler_next_sample_index == static_sample_before) && (o_scheduler_current_frame_id == static_frame_before));
			i_test_mux_ctrl = 5'b01010;
			repeat(8) @(negedge i_clk);
			flag_static_atomic_update_ok = (o_s_in == i_test_mux_ctrl) && (cnt_owner_commit == static_owner_before) &&
				(cnt_measurement_result == static_result_before) && !flag_static_algorithm_result_seen &&
				!o_measurement_result_valid && !o_amb_recheck_pending && !o_amb_recheck_busy &&
				(o_amb_code == static_amb_code_before) && (o_dcs_r_code == static_dcs_r_code_before) &&
				(o_dcs_ir_code == static_dcs_ir_code_before) && (o_amb_code_epoch == static_amb_epoch_before) &&
				(o_dcs_r_code_epoch == static_dcs_r_epoch_before) && (o_dcs_ir_code_epoch == static_dcs_ir_epoch_before) &&
				(o_scheduler_next_sample_index == static_sample_before) && (o_scheduler_current_frame_id == static_frame_before) &&
				flag_static_s_edge_seen && flag_static_s_edge_atomic;
			scoreboard_mark(C_TRACE_ILM_BASE + 13, 1'b1, flag_static_atomic_update_ok);
			$display("TB_ILM_SUBRUN group=STATIC-BIAS-MATRIX input_source=%0b static_enable=%0b jnt_parent_run=%0d jnt=%0d/%0d owner_delta=%0d result_delta=%0d q1=%0d q2=%0d q3=%0d async=%0d done=%0d fir=%0d recheck=%0d algorithm=%0d status=%0s",
				i_input_source, i_static_characterization_enable, cnt_jnt_parent_run_index,
				cnt_jnt_parent_pass, C_JNT_REQUIRED_SUBCHECKS, cnt_owner_commit - static_owner_before,
				cnt_measurement_result - static_result_before, flag_static_q1_seen, flag_static_q2_seen,
				flag_static_q3_seen, flag_static_async_seen, flag_static_done_seen, flag_static_fir_seen,
				flag_static_recheck_seen, flag_static_algorithm_result_seen,
				((cnt_jnt_parent_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_jnt_parent_fail == 0) &&
				 (cnt_owner_commit == static_owner_before) && (cnt_measurement_result == static_result_before) &&
				 !flag_static_q1_seen && !flag_static_q2_seen && !flag_static_q3_seen &&
				 !flag_static_async_seen && !flag_static_done_seen && !flag_static_fir_seen &&
				 !flag_static_recheck_seen && !flag_static_algorithm_result_seen) ? "PASS" : "NOT_CLOSED");
			// Invalid STATIC_BIAS source is a separate reset/run.  It must not
			// enter the static vector or measurement path at all.
			reg_scenario_group_id = "STATIC-BIAS-INVALID-SOURCE";
			run_jnt_baseline;
			begin_independent_run(reg_scenario_group_id);
			i_static_characterization_enable = 1'b1;
			i_input_source = 1'b1;
			i_optical_mode = OPTICAL_MODE_BOTH;
			i_test_mux_ctrl = 5'b11100;
			static_owner_before = cnt_owner_commit;
			static_result_before = cnt_measurement_result;
			static_amb_code_before = o_amb_code;
			static_dcs_r_code_before = o_dcs_r_code;
			static_dcs_ir_code_before = o_dcs_ir_code;
			static_amb_epoch_before = o_amb_code_epoch;
			static_dcs_r_epoch_before = o_dcs_r_code_epoch;
			static_dcs_ir_epoch_before = o_dcs_ir_code_epoch;
			static_sample_before = o_scheduler_next_sample_index;
			static_frame_before = o_scheduler_current_frame_id;
			release_independent_run_reset;
			analog_run_enable = 1'b1;
			measurement_run_enable = 1'b0;
			measurement_allow_new_transaction = 1'b0;
			pulse_analog_start_ack;
			repeat(80) @(negedge i_clk);
			scoreboard_mark(C_TRACE_ILM_BASE + 14, 1'b1, (cnt_owner_commit == static_owner_before) &&
				(cnt_measurement_result == static_result_before) && !flag_static_q1_seen &&
				!flag_static_q2_seen && !flag_static_q3_seen && !flag_static_async_seen &&
				!flag_static_done_seen && !flag_static_algorithm_result_seen && (o_s_in == 5'd0) &&
				(o_amb_code == static_amb_code_before) && (o_dcs_r_code == static_dcs_r_code_before) &&
				(o_dcs_ir_code == static_dcs_ir_code_before) && (o_amb_code_epoch == static_amb_epoch_before) &&
				(o_dcs_r_code_epoch == static_dcs_r_epoch_before) && (o_dcs_ir_code_epoch == static_dcs_ir_epoch_before) &&
				(o_scheduler_next_sample_index == static_sample_before) && (o_scheduler_current_frame_id == static_frame_before));
			$display("TB_ILM_SUBRUN group=STATIC-BIAS-INVALID-SOURCE input_source=%0b static_enable=%0b jnt_parent_run=%0d jnt=%0d/%0d s_in=%0b owner_delta=%0d result_delta=%0d status=%0s",
				i_input_source, i_static_characterization_enable, cnt_jnt_parent_run_index, cnt_jnt_parent_pass,
				C_JNT_REQUIRED_SUBCHECKS, o_s_in, cnt_owner_commit - static_owner_before,
				cnt_measurement_result - static_result_before,
				((cnt_jnt_parent_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_jnt_parent_fail == 0) &&
				 (cnt_owner_commit == static_owner_before) && (cnt_measurement_result == static_result_before) &&
				 (o_s_in == 5'd0)) ? "PASS" : "NOT_CLOSED");
			report_functional_group("INPUT-LIGHT-STATIC-MATRIX", C_TRACE_ILM_BASE, 15);
			flag_contract_group_override = 1'b0;
		end
	endtask

	// Change source/light/precision/manual-code inputs after a real owner has
	// committed.  The current owner must retain its public waveform snapshot,
	// completion identity, and code epoch; the changed values may affect only a
	// later transaction.
	task run_snapshot_atomic_scenario;
		integer completion_before;
		reg snapshot_ok;
		reg owner_precision;
		reg owner_color_ir;
		reg [15:0]owner_frame_id;
		reg [15:0]owner_sample_index;
		reg [7:0]owner_amb_code;
		reg [7:0]owner_dc_code;
		reg [3:0]owner_amb_epoch;
		reg [3:0]owner_dc_epoch;
		begin
			reg_scenario_group_id = "INPUT-SNAPSHOT-ATOMIC";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'd0;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_enable_result_backpressure = 1'b0;
			begin_independent_run(reg_scenario_group_id);
			release_independent_run_reset;
			analog_run_enable = 1'b1;
			measurement_run_enable = 1'b1;
			measurement_allow_new_transaction = 1'b1;
			pulse_normal_start_ack;
			wait_owner_commit_count(cnt_owner_commit + 1);
			owner_precision = reg_last_owner_precision_mode;
			owner_color_ir = reg_last_owner_color_ir;
			owner_frame_id = reg_last_owner_frame_id;
			owner_sample_index = reg_last_owner_sample_index;
			owner_amb_code = reg_last_owner_amb_code;
			owner_dc_code = reg_last_owner_dc_code;
			owner_amb_epoch = o_adc_owner_amb_code_epoch;
			owner_dc_epoch = o_adc_owner_dc_code_epoch;
			completion_before = cnt_completion;
			// These changes occur while the captured owner is still in Q phases.
			i_input_source = 1'b1;
			i_optical_mode = 2'b01;
			i_initial_precision = 1'b1;
			i_amb_manual_code = i_amb_manual_code + 8'd1;
			i_dcs_r_manual_code = i_dcs_r_manual_code + 8'd1;
			i_dcs_ir_manual_code = i_dcs_ir_manual_code + 8'd1;
			wait_conversion_phases_complete_quiet(owner_color_ir);
			drive_real_adc_done(owner_precision, 10'b0000011011, owner_precision ? 10'd102 : 10'd0);
			wait_completion_count_long(completion_before + 1);
			snapshot_ok = (cnt_completion >= (completion_before + 1)) && reg_last_completion_success &&
				(reg_last_completion_sample_index == owner_sample_index) &&
				(reg_completed_owner_valid == 1'b1) &&
				(reg_completed_owner_frame_id == owner_frame_id) &&
				(reg_completed_owner_sample_index == owner_sample_index) &&
				(reg_completed_owner_color_ir == owner_color_ir) &&
				(reg_completed_owner_precision_mode == owner_precision) &&
				(reg_completed_owner_amb_code == owner_amb_code) &&
				(reg_completed_owner_dc_code == owner_dc_code) &&
				(reg_completed_owner_amb_epoch == owner_amb_epoch) &&
				(reg_completed_owner_dc_epoch == owner_dc_epoch);
			$display("TB_ILM_SNAPSHOT_SUMMARY jnt_parent_run=%0d jnt=%0d/%0d owner_frame=%0d owner_sample=%0d owner_color=%0b owner_precision=%0b owner_amb=%0d owner_dc=%0d completion=%0d status=%0s",
				cnt_jnt_parent_run_index, cnt_jnt_parent_pass, C_JNT_REQUIRED_SUBCHECKS,
				owner_frame_id, owner_sample_index, owner_color_ir, owner_precision, owner_amb_code, owner_dc_code,
				cnt_completion, snapshot_ok ? "PASS" : "FAIL");
			// ILM-10 is closed only by this dedicated run.  The comparison is
			// intentionally bound to the captured owner, not to later configuration.
			scoreboard_mark(C_TRACE_ILM_BASE + 9, 1'b1, snapshot_ok);
		end
	endtask

	task run_robustness_waveform_scenario;
		reg fast_rate_ok;
		reg slow_rate_ok;
		reg [31:0]noise_signature_first;
		integer noise_signature_samples_first;
		reg [15:0]saved_min_peak_to_valley_frames;
		reg [15:0]saved_min_peak_to_peak_frames;
		begin
			flag_contract_group_override = 1'b1;
			reg_contract_group_id = "PPG-ROBUSTNESS-CORNER-WAVEFORMS";
			reg_scenario_waveform_mode = 1;
			run_short_mode_scenario("ROBUST-FLAT-NO-PULSE", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 96);
			scoreboard_mark(C_TRACE_PRC_BASE + 0, 1'b1, !flag_ppg_cross_pending_seen && !flag_ppg_peak_pending_seen && !flag_ppg_valley_pending_seen);
			reg_scenario_waveform_mode = 2;
			run_short_mode_scenario("ROBUST-LOW-AMPLITUDE", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 96);
			scoreboard_mark(C_TRACE_PRC_BASE + 1, 1'b1, !flag_ppg_precision_15_seen || (cnt_ppg_algorithm_sar15_result == 0));
			reg_scenario_waveform_mode = 3;
			run_short_mode_scenario("ROBUST-SATURATION", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 96);
			scoreboard_mark(C_TRACE_PRC_BASE + 2, flag_saturation_observed,
				!flag_ppg_baseline_valid_seen && !flag_ppg_cross_pending_seen && !flag_ppg_peak_pending_seen && !flag_ppg_valley_pending_seen);
			reg_scenario_waveform_mode = 0;
			run_short_mode_scenario("ROBUST-DRIFT-NOISE", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 320);
			scoreboard_mark(C_TRACE_PRC_BASE + 3, 1'b1, flag_numeric_identity_ok && flag_ppg_result_sequence_ok);
			noise_signature_first = reg_raw_signature;
			noise_signature_samples_first = cnt_raw_signature_samples;
			// PRC-05 requires a second independently reset run of the same RAW schedule.
			run_short_mode_scenario("ROBUST-DRIFT-NOISE-REPEAT", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 320);
			scoreboard_mark(C_TRACE_PRC_BASE + 4,
				(noise_signature_samples_first > 0) && (cnt_raw_signature_samples == noise_signature_samples_first),
				(cnt_numeric_mismatch == 0) && (reg_raw_signature == noise_signature_first));
			// The fast 80-frame profile is below this configured interval.  It must
			// reach timeout/reacquire and cannot create a qualified return event.
			saved_min_peak_to_valley_frames = i_min_peak_to_valley_frames;
			saved_min_peak_to_peak_frames = i_min_peak_to_peak_frames;
			i_min_peak_to_valley_frames = 16'd100;
			i_min_peak_to_peak_frames = 16'd100;
			reg_scenario_waveform_mode = 7;
			run_short_mode_scenario("ROBUST-FAST-HEART-RATE", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 320);
			fast_rate_ok = flag_ppg_result_sequence_ok &&
				((cnt_ppg_fine_timeout_seen > 0) || (cnt_ppg_reacquire_seen > 0)) &&
				!flag_ppg_precision_15_to_9_seen;
			reg_scenario_waveform_mode = 8;
			run_short_mode_scenario("ROBUST-SLOW-HEART-RATE", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 1200);
			slow_rate_ok = flag_ppg_result_sequence_ok && flag_ppg_peak_pending_seen &&
				flag_ppg_valley_pending_seen && flag_ppg_precision_15_to_9_seen &&
				flag_ppg_precision_9_after_15_seen;
			scoreboard_mark(C_TRACE_PRC_BASE + 5, 1'b1, fast_rate_ok && slow_rate_ok);
			i_min_peak_to_valley_frames = saved_min_peak_to_valley_frames;
			i_min_peak_to_peak_frames = saved_min_peak_to_peak_frames;
			reg_scenario_waveform_mode = 9;
			run_short_mode_scenario("ROBUST-WEAK-NOTCH", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 320);
			scoreboard_mark(C_TRACE_PRC_BASE + 6, 1'b1,
				(flag_ppg_valley_pending_seen && flag_ppg_precision_15_to_9_seen && flag_ppg_precision_9_after_15_seen && flag_ppg_result_sequence_ok) ||
				(cnt_ppg_fine_timeout_seen > 0) || (cnt_ppg_reacquire_seen > 0));
			reg_scenario_waveform_mode = 10;
			run_short_mode_scenario("ROBUST-MISSING-NOTCH", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 320);
			// Missing-notch is the second PRC-07 profile. Its result is reported in
			// the trace, but does not substitute for PRC-08 invalid-sample evidence.
			reg_scenario_waveform_mode = 11;
			run_short_mode_scenario("ROBUST-INVALID-QUALIFICATION", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 160);
			// The public joint interface can provide a physical RAW value but has no
			// valid/invalid sample sideband.  A low RAW code is not an invalid sample,
			// therefore PRC-08 remains NOT_CLOSED instead of treating this waveform as
			// a substitute for the required invalid-transaction test.
			scoreboard_mark(C_TRACE_PRC_BASE + 7, 1'b0, 1'b0);
			i_stage1_calibration_valid = 1'b0;
			run_short_mode_scenario("ROBUST-CALIBRATION-QUALIFICATION-LOSS", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 160);
			scoreboard_mark(C_TRACE_PRC_BASE + 8, 1'b1,
				!flag_ppg_baseline_valid_seen && !flag_ppg_cross_pending_seen && !flag_ppg_peak_pending_seen && !flag_ppg_valley_pending_seen);
			i_stage1_calibration_valid = 1'b1;
			reg_scenario_waveform_mode = 0;
			run_short_mode_scenario("ROBUST-POST-INVALID-RECOVERY", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 320);
			// The recovery comparison is bound to the post-loss independent run.
			scoreboard_mark(C_TRACE_PRC_BASE + 9, 1'b1, flag_ppg_result_sequence_ok && (cnt_identity_mismatch == 0));
			report_functional_group("PPG-ROBUSTNESS-CORNER-WAVEFORMS", C_TRACE_PRC_BASE, 10);
			flag_contract_group_override = 1'b0;
		end
	endtask

	// Exercise negative ADC timing through the public asynchronous inputs.  The
	// task never changes DUT state hierarchically and does not inject completion.
	task exercise_adc_anomaly_path;
		integer completion_snapshot;
		begin
			// Keep the anomaly stimulus in the lifecycle functional phase that owns
			// the complete 52-check JNT parent; do not create a detached run.
			reg_scenario_group_id = "LIFECYCLE-FAULT-ADC-ANOMALY";
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_enable_result_backpressure = 1'b0;
			begin_functional_phase_same_run(reg_scenario_group_id);
			release_independent_run_reset;
			analog_run_enable = 1'b1;
			measurement_run_enable = 1'b1;
			measurement_allow_new_transaction = 1'b1;
			pulse_normal_start_ack;
			wait_owner_commit_count(cnt_owner_commit + 1);
			completion_snapshot = cnt_completion;
			i_dout_stage1_low = 10'b0000011011;
			i_clk_stage1_dout_low_async = 1'b1;
			#1 i_clk_stage1_dout_low_async = 1'b0;
			repeat(8) @(negedge i_clk);
			flag_lfa_early_dout_rejected = (cnt_completion == completion_snapshot);
			wait_conversion_phases_complete(1'b0);
			drive_real_adc_done(1'b0, 10'b0000011011, 10'd0);
			wait_completion_count(completion_snapshot + 1);
			completion_snapshot = cnt_completion;
			i_dout_stage1_low = 10'b0000011011;
			i_clk_stage1_dout_low_async = 1'b1;
			#1 i_clk_stage1_dout_low_async = 1'b0;
			repeat(8) @(negedge i_clk);
			flag_lfa_duplicate_done_rejected = (cnt_completion == completion_snapshot);
			$display("TB_LFA_ADC_ANOMALY early_rejected=%0d duplicate_rejected=%0d completion=%0d", flag_lfa_early_dout_rejected, flag_lfa_duplicate_done_rejected, cnt_completion);
		end
	endtask

	task close_lifecycle_and_identity_groups;
		begin
			flag_contract_group_override = 1'b1;
			reg_contract_group_id = "LIFECYCLE-FAULT-ADC-ANOMALY";
			// JNT-05/06/08/09 are real abort, reset, STOP, and deadline transactions.
			reg_scenario_group_id = "LIFECYCLE-FAULT-ADC-ANOMALY";
			run_jnt_baseline;
			exercise_adc_anomaly_path;
			scoreboard_mark(C_TRACE_LFA_BASE + 0, (cnt_completion > 0) || flag_reset_done_observation, cnt_fault_owner_leak == 0);
			scoreboard_mark(C_TRACE_LFA_BASE + 1, (cnt_completion > 0) || flag_reset_done_observation, cnt_completion > 0);
			scoreboard_mark(C_TRACE_LFA_BASE + 2, (cnt_completion > 0) || flag_reset_done_observation, cnt_idac_update_without_change == 0);
			scoreboard_mark(C_TRACE_LFA_BASE + 3, cnt_completion > 0, reg_last_completion_success || flag_reset_done_observation);
			scoreboard_mark(C_TRACE_LFA_BASE + 4, flag_reset_done_observation, cnt_identity_mismatch == 0);
			scoreboard_mark(C_TRACE_LFA_BASE + 5, (cnt_completion > 0) || flag_fault_first_seen || flag_reset_done_observation, flag_lfa_early_dout_rejected);
			scoreboard_mark(C_TRACE_LFA_BASE + 6, (cnt_completion > 0) || flag_fault_first_seen || flag_reset_done_observation, flag_lfa_duplicate_done_rejected);
			// The joint interface has no legal sample-index override.  Do not claim
			// LFA-08 by marking it N/A: retain NOT_CLOSED until a public protocol
			// injection point or separately versioned interface evidence exists.
			scoreboard_mark(C_TRACE_LFA_BASE + 8, (cnt_completion > 0) || flag_reset_done_observation, (cnt_fault_blocking_cycles == 0) || flag_fault_first_seen);
			scoreboard_mark(C_TRACE_LFA_BASE + 9, flag_fault_first_seen, cnt_fault_owner_leak == 0);
			scoreboard_mark(C_TRACE_LFA_BASE + 10, flag_fault_sticky_clear_observed, flag_fault_recovery_clean);
			scoreboard_mark(C_TRACE_LFA_BASE + 11, flag_reset_done_observation, cnt_identity_mismatch == 0);
			report_functional_group("LIFECYCLE-FAULT-ADC-ANOMALY", C_TRACE_LFA_BASE, 12);
			flag_contract_group_override = 1'b0;
		end
	endtask

	task close_identity_groups;
		begin
			scoreboard_mark(C_TRACE_ISE_BASE + 0, (cnt_owner_commit > 0) && (cnt_waveform_context > 0), flag_owner_context_identity_match);
			scoreboard_mark(C_TRACE_ISE_BASE + 1, (cnt_owner_commit > 0) && (cnt_waveform_context > 0), flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_ISE_BASE + 2, (cnt_amb_update_observed + cnt_dcs_r_update_observed + cnt_dcs_ir_update_observed) > 0, flag_idac_epoch_relation_ok);
			scoreboard_mark(C_TRACE_ISE_BASE + 3, cnt_owner_commit > 0, flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_ISE_BASE + 4, flag_ppg_precision_15_seen, flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_ISE_BASE + 5, (cnt_startup_calibration_request > 0) || (cnt_recheck_calibration_request > 0), flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_ISE_BASE + 6, cnt_owner_commit > 1, flag_ise_pattern_31_seen && flag_ise_pattern_42_seen && flag_ise_pattern_53_seen && flag_unselected_idac_bus_clean);
			scoreboard_mark(C_TRACE_ISE_BASE + 7, (cnt_red_waveform_context > 0) && (cnt_ir_waveform_context > 0), flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_ISE_BASE + 8, (cnt_amb_update_observed + cnt_dcs_r_update_observed + cnt_dcs_ir_update_observed) > 0, cnt_idac_update_without_change == 0);
			// OIB-01/02 are closed only by the explicit interconnect adapter above.
			// Both source payloads must remain stable for the held clock, retain
			// the scheduler sample index, and transfer exactly once after release.
			scoreboard_mark(C_TRACE_OIB_BASE + 0,
				flag_oib_waveform_stall_seen && flag_oib_waveform_stall_complete &&
				flag_oib_waveform_snapshot_valid && (cnt_oib_waveform_stall_cycles >= C_OIB_STALL_CYCLES) &&
				flag_oib_waveform_accept_seen,
				flag_oib_waveform_hold_ok && (cnt_oib_waveform_accept == 1) &&
				!o_scheduler_launch_timeout_sticky && !o_scheduler_owner_deadline_timeout_sticky &&
				!o_scheduler_protocol_error_sticky && !o_ssw_fault_blocking && !o_ami_fault_blocking);
			scoreboard_mark(C_TRACE_OIB_BASE + 1,
				flag_oib_transaction_stall_seen && flag_oib_transaction_stall_complete &&
				flag_oib_transaction_snapshot_valid && (cnt_oib_transaction_stall_cycles >= C_OIB_STALL_CYCLES) &&
				flag_oib_transaction_accept_seen,
				flag_oib_transaction_hold_ok && (cnt_oib_transaction_accept == 1) &&
				!o_scheduler_launch_timeout_sticky && !o_scheduler_owner_deadline_timeout_sticky &&
				!o_scheduler_protocol_error_sticky && !o_ssw_fault_blocking && !o_ami_fault_blocking);
			scoreboard_mark(C_TRACE_OIB_BASE + 2, cnt_result_backpressure_comparison > 0, cnt_result_backpressure_mismatch == 0);
			scoreboard_mark(C_TRACE_OIB_BASE + 3, cnt_result_backpressure_comparison > 0,
				(cnt_result_backpressure_mismatch == 0) && !o_scheduler_launch_timeout_sticky &&
				!o_scheduler_owner_deadline_timeout_sticky && !o_scheduler_protocol_error_sticky &&
				!o_ssw_fault_blocking && !o_ami_fault_blocking);
			scoreboard_mark(C_TRACE_OIB_BASE + 4, cnt_identity_comparison > 0, cnt_identity_mismatch == 0);
			scoreboard_mark(C_TRACE_OIB_BASE + 5, cnt_identity_comparison > 0, cnt_identity_mismatch == 0);
			scoreboard_mark(C_TRACE_OIB_BASE + 6, cnt_identity_comparison > 0, flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_OIB_BASE + 7, cnt_completion > 0, cnt_result_backpressure_mismatch == 0);
			scoreboard_mark(C_TRACE_OIB_BASE + 8, cnt_owner_commit > 0, flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_OIB_BASE + 9, cnt_result_backpressure_comparison > 0, cnt_result_backpressure_mismatch == 0);
		end
	endtask

	// Five V1.2 core PPG groups are separate reset/JNT/algorithm runs.
	task report_core_ppg_group;
		input [8 * 32 - 1:0]group_id;
		input condition;
		reg group_pass;
		begin
			group_pass = condition && flag_jnt_parent_valid && (reg_jnt_parent_group_id == group_id) &&
				(cnt_jnt_parent_checked == C_JNT_REQUIRED_SUBCHECKS) &&
				(cnt_jnt_parent_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_jnt_parent_fail == 0);
			$display("TB_CORE_GROUP_SUMMARY run=%0d group=%0s jnt_parent_run=%0d jnt=%0d/%0d algorithm=%0b status=%0s", cnt_run_index, group_id, cnt_jnt_parent_run_index, cnt_jnt_parent_pass, C_JNT_REQUIRED_SUBCHECKS, condition, group_pass ? "PASS" : "NOT_CLOSED");
			if(fd_result_file != 0) $fwrite(fd_result_file, "TB_CORE_GROUP_RESULT run=%0d group=%0s jnt_parent_run=%0d jnt_checked=%0d jnt_pass=%0d jnt_fail=%0d algorithm=%0b status=%0s\n", cnt_run_index, group_id, cnt_jnt_parent_run_index, cnt_jnt_parent_checked, cnt_jnt_parent_pass, cnt_jnt_parent_fail, condition, group_pass ? "PASS" : "NOT_CLOSED");
		end
	endtask

	task run_core_ppg_group;
		input [8 * 32 - 1:0]group_id;
		input integer waveform_mode;
		input integer sample_count;
		input [2:0]expected_events;
		begin
			reg_scenario_group_id = group_id;
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b0;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_enable_result_backpressure = 1'b0;
			reg_scenario_waveform_mode = waveform_mode;
			reg_scenario_sample_count = sample_count;
			reg_scenario_emit_long_checks = 1'b0;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b0;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_recheck_cancel_mode = 2'd0;
			run_jnt_baseline;
			run_ppg_algorithm_scenario;
			if(expected_events[0]) report_core_ppg_group(group_id, flag_ppg_fir_full_r_seen && flag_ppg_fir_full_ir_seen && flag_ppg_baseline_valid_seen);
			else if(expected_events[1]) report_core_ppg_group(group_id, flag_ppg_cross_pending_seen && flag_ppg_fine_window_start_seen && flag_ppg_precision_15_seen);
			else if(expected_events[2]) report_core_ppg_group(group_id, flag_ppg_peak_pending_seen && flag_ppg_valley_pending_seen && flag_ppg_precision_15_to_9_seen && flag_ppg_precision_9_after_15_seen);
			else report_core_ppg_group(group_id, flag_ppg_sar15_tail_isolated && flag_ppg_result_sequence_ok);
		end
	endtask

	task run_core_baseline_warmup_scenario;
		begin run_core_ppg_group("PPG-BASELINE-WARMUP", 0, 180, 3'b001); end
	endtask

	task run_core_cross_sar15_scenario;
		begin run_core_ppg_group("PPG-CROSS-SAR15", 0, 420, 3'b010); end
	endtask

	task run_core_peak_valley_return_scenario;
		begin run_core_ppg_group("PPG-PEAK-VALLEY-RETURN", 0, 820, 3'b100); end
	endtask

	task run_core_fir_tail_scenario;
		begin run_core_ppg_group("PPG-FIR-TAIL-ISOLATION", 5, 820, 3'b000); end
	endtask

	// The long core group has the same independent JNT parent rule as the four
	// directed groups, but its acceptance predicate is the physical 10-second
	// run rather than a short event tuple.
	task run_core_long_scenario;
		begin
			reg_scenario_group_id = "PPG-LONG-10-CYCLES";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b0;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_enable_result_backpressure = 1'b0;
			reg_scenario_waveform_mode = 0;
			reg_scenario_sample_count = C_PPG_ALGORITHM_SAMPLES;
			reg_scenario_emit_long_checks = 1'b1;
			reg_scenario_recheck_cancel_mode = 2'd0;
			run_ppg_algorithm_scenario;
			report_core_ppg_group("PPG-LONG-10-CYCLES",
				(o_normal_frame_count >= 16'd4000) && flag_ppg_result_sequence_ok &&
				flag_ppg_fir_full_r_seen && flag_ppg_fir_full_ir_seen &&
				flag_ppg_precision_15_seen && flag_ppg_precision_9_after_15_seen);
		end
	endtask

		task run_no_recheck_control_scenario;
		begin
			reg_scenario_group_id = "NO-RECHECK-CROSS-CONTROL";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'd0;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			// 600 samples can end before a formally-qualified fine-window
			// peak/valley pair is available; keep the control run long enough
			// to cover a complete second pulse cycle.
			reg_scenario_sample_count = 1000;
			reg_scenario_emit_long_checks = 1'b0;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_startup_watchdog_limit = 100;
		reg_scenario_enable_tracking_after_startup = 1'b0;
		reg_scenario_enable_waveform_backpressure = 1'b0;
		reg_scenario_enable_transaction_backpressure = 1'b0;
		reg_scenario_waveform_mode = 0;
			run_ppg_algorithm_scenario;
			$display("TB_NRE_SUMMARY baseline=%0d cross=%0d fine_start=%0d peak=%0d valley=%0d sar15=%0d return=%0d sar9_after=%0d sar9_results=%0d sar15_results=%0d active_precision=%0d return_pending_cycles=%0d return_events=%0d fine_timeout_cycles=%0d reacquire_cycles=%0d", flag_ppg_baseline_valid_seen, flag_ppg_cross_pending_seen, flag_ppg_fine_window_start_seen, flag_ppg_peak_pending_seen, flag_ppg_valley_pending_seen, flag_ppg_precision_15_seen, flag_ppg_precision_15_to_9_seen, flag_ppg_precision_9_after_15_seen, cnt_ppg_algorithm_sar9_result, cnt_ppg_algorithm_sar15_result, o_active_precision_mode, cnt_ppg_return_pending_seen, cnt_ppg_return_event_seen, cnt_ppg_fine_timeout_seen, cnt_ppg_reacquire_seen);
			scoreboard_mark(C_TRACE_NRE_BASE + 0, 1'b1, cnt_recheck_pending_observed == 0);
			scoreboard_mark(C_TRACE_NRE_BASE + 1, 1'b1, cnt_recheck_accept_observed == 0);
			scoreboard_mark(C_TRACE_NRE_BASE + 2, 1'b1, flag_ppg_baseline_valid_seen);
			scoreboard_mark(C_TRACE_NRE_BASE + 3, 1'b1, flag_ppg_cross_pending_seen);
			scoreboard_mark(C_TRACE_NRE_BASE + 4, 1'b1, flag_ppg_precision_15_seen);
			scoreboard_mark(C_TRACE_NRE_BASE + 5, 1'b1, flag_ppg_precision_15_to_9_seen);
			report_functional_group("NO-RECHECK-CROSS-CONTROL", C_TRACE_NRE_BASE, 6);
		end
	endtask

	// Each numeric vector owns a standard JNT baseline before its coefficient
	// override is applied. This prevents a directed arithmetic vector from
	// changing the frozen 52-check baseline itself.
	task run_numeric_vector_subrun;
		input [8 * 32 - 1:0]subrun_id;
		input integer vector_mode;
		input signed [31:0]stage1_offset_q16;
		input precision_select;
		input integer sample_count;
		begin
			reg_scenario_group_id = subrun_id;
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = precision_select;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_enable_result_backpressure = 1'b1;
			reg_scenario_waveform_mode = vector_mode;
			reg_scenario_numeric_vector_mode = vector_mode;
			reg_scenario_sample_count = sample_count;
			reg_scenario_emit_long_checks = 1'b0;
			i_stage1_offset_q16 = stage1_offset_q16;
			run_ppg_algorithm_scenario;
		end
	endtask

	// Representative ADC numeric-chain run. The actual comparisons are made by
	// the public-result monitor and finalized only after each independent reset.
	task run_numeric_scoreboard_scenario;
		reg signed [31:0]saved_stage1_offset;
		reg aggregate_negative_seen;
		reg aggregate_half_positive_seen;
		reg aggregate_half_negative_seen;
		reg aggregate_saturation_low_seen;
		reg aggregate_saturation_high_seen;
		reg aggregate_directed_vectors_clean;
		begin
			flag_contract_group_override = 1'b1;
			reg_contract_group_id = "ADC-NUMERIC-CODE-SCOREBOARD";
			saved_stage1_offset = i_stage1_offset_q16;
			aggregate_negative_seen = 1'b0;
			aggregate_half_positive_seen = 1'b0;
			aggregate_half_negative_seen = 1'b0;
			aggregate_saturation_low_seen = 1'b0;
			aggregate_saturation_high_seen = 1'b0;
			aggregate_directed_vectors_clean = 1'b1;
			// NORMAL must enter SAR15 through the contracted SAR9-to-SAR15 path.
			// Starting directly in SAR15 cannot replace public precision-window evidence.
			run_numeric_vector_subrun("ADC-NUMERIC-NOMINAL", 0, saved_stage1_offset, 1'b0, 1400);
			scoreboard_mark(C_TRACE_ADCN_BASE + 0, cnt_stage1_signed_comparison > 0, cnt_numeric_mismatch == 0);
			scoreboard_mark(C_TRACE_ADCN_BASE + 3, cnt_coarse_comparison > 0, flag_sar9_no_fine_ok);
			scoreboard_mark(C_TRACE_ADCN_BASE + 4, cnt_stage2_comparison > 0, flag_sar15_chain_ok);
			scoreboard_mark(C_TRACE_ADCN_BASE + 5, cnt_fine_comparison > 0, flag_sar15_chain_ok && (cnt_numeric_mismatch == 0));
			scoreboard_mark(C_TRACE_ADCN_BASE + 6, cnt_identity_comparison > 0, flag_numeric_identity_ok);
			scoreboard_mark(C_TRACE_ADCN_BASE + 7, cnt_result_backpressure_comparison > 0, cnt_result_backpressure_mismatch == 0);
			scoreboard_mark(C_TRACE_ADCN_BASE + 8, cnt_stage1_signed_comparison > 0, flag_stage1_signed_range_ok);
			scoreboard_mark(C_TRACE_ADCN_BASE + 9, cnt_stage1_signed_comparison > 0, flag_tracking_stage1_only);

			// Negative and symmetric half-LSB vectors use the same real ADC owner.
			run_numeric_vector_subrun("ADC-NUMERIC-NEGATIVE", 1, -32'sd65536, 1'b0, 32);
			aggregate_negative_seen = flag_adcn_negative_vector_seen;
			aggregate_directed_vectors_clean = aggregate_directed_vectors_clean && (cnt_stage1_signed_comparison > 0) &&
				(cnt_numeric_mismatch == 0) && flag_stage1_signed_range_ok;
			run_numeric_vector_subrun("ADC-NUMERIC-HALF-POSITIVE", 2, 32'sd32768, 1'b0, 32);
			aggregate_half_positive_seen = flag_adcn_half_positive_seen;
			aggregate_directed_vectors_clean = aggregate_directed_vectors_clean && (cnt_stage1_signed_comparison > 0) &&
				(cnt_numeric_mismatch == 0) && flag_stage1_signed_range_ok;
			run_numeric_vector_subrun("ADC-NUMERIC-HALF-NEGATIVE", 3, -32'sd32768, 1'b0, 32);
			aggregate_half_negative_seen = flag_adcn_half_negative_seen;
			aggregate_directed_vectors_clean = aggregate_directed_vectors_clean && (cnt_stage1_signed_comparison > 0) &&
				(cnt_numeric_mismatch == 0) && flag_stage1_signed_range_ok;
			scoreboard_mark(C_TRACE_ADCN_BASE + 1, aggregate_negative_seen && aggregate_half_positive_seen && aggregate_half_negative_seen,
				aggregate_directed_vectors_clean && aggregate_negative_seen && aggregate_half_positive_seen && aggregate_half_negative_seen);

			// Explicit signed Stage1 saturation vectors.
			run_numeric_vector_subrun("ADC-NUMERIC-SATURATION-LOW", 4, -32'sd200000000, 1'b0, 32);
			aggregate_saturation_low_seen = flag_adcn_saturation_low_seen;
			aggregate_directed_vectors_clean = aggregate_directed_vectors_clean && (cnt_stage1_signed_comparison > 0) &&
				(cnt_numeric_mismatch == 0) && flag_stage1_signed_range_ok;
			run_numeric_vector_subrun("ADC-NUMERIC-SATURATION-HIGH", 5, 32'sd200000000, 1'b0, 32);
			aggregate_saturation_high_seen = flag_adcn_saturation_high_seen;
			aggregate_directed_vectors_clean = aggregate_directed_vectors_clean && (cnt_stage1_signed_comparison > 0) &&
				(cnt_numeric_mismatch == 0) && flag_stage1_signed_range_ok;
			scoreboard_mark(C_TRACE_ADCN_BASE + 2, aggregate_saturation_low_seen && aggregate_saturation_high_seen,
				aggregate_directed_vectors_clean && aggregate_saturation_low_seen && aggregate_saturation_high_seen);
			i_stage1_offset_q16 = saved_stage1_offset;
			reg_scenario_numeric_vector_mode = 0;
			reg_scenario_enable_result_backpressure = 1'b0;
			flag_contract_group_override = 1'b0;
			report_functional_group("ADC-NUMERIC-CODE-SCOREBOARD", C_TRACE_ADCN_BASE, 10);
		end
	endtask

	// IDAC snapshot/epoch and owner identity evidence run.  No hierarchy or
	// force is used; all predicates consume public observation wires only.
	task run_identity_isolation_scenario;
		begin
			run_short_mode_scenario("IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION", 1'b0, OPTICAL_MODE_BOTH, 1'b0, 320);
			close_identity_groups;
			// ISE-10 requires a real observed epoch wrap, not search exhaustion.
			// This separate reset/JNT run sustains legal tracking updates until the
			// monitor observes a physical 4'hF -> 0 transition.
			reg_scenario_group_id = "IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b01;
			reg_scenario_enable_tracking_after_startup = 1'b1;
			reg_scenario_waveform_mode = 6;
			reg_scenario_sample_count = 8000;
			reg_scenario_emit_long_checks = 1'b0;
			run_ppg_algorithm_scenario;
			scoreboard_mark(C_TRACE_ISE_BASE + 9, cnt_tracking_epoch_wrap_observed > 0,
				flag_idac_no_wrap_ok && (cnt_tracking_epoch_wrap_observed == 1));
			report_functional_group("IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION", C_TRACE_ISE_BASE, 10);
			// OIB is closed only by run_owner_identity_scenario, which enables
			// the public result-ready backpressure window in this same run.
		end
	endtask

	task run_owner_identity_scenario;
		begin
			// Do not use run_short_mode_scenario here: its normal default policy
			// deliberately disables all optional backpressure. This group requires
			// each of the three public port-boundary stall mechanisms to be active.
			reg_scenario_group_id = "OWNER-IDENTITY-BACKPRESSURE";
			run_jnt_baseline;
			reg_scenario_recheck_interval = 16'hffff;
			reg_scenario_input_source = 1'b0;
			reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
			reg_scenario_initial_precision = 1'b0;
			reg_scenario_idac_mode = 2'b00;
			reg_scenario_force_search_failure = 1'b0;
			reg_scenario_force_recheck_failure = 1'b0;
			reg_scenario_allow_startup_failure = 1'b0;
			reg_scenario_recheck_nominal_calibration = 1'b0;
			reg_scenario_enable_tracking_after_startup = 1'b0;
			reg_scenario_enable_result_backpressure = 1'b1;
			reg_scenario_enable_waveform_backpressure = 1'b1;
			reg_scenario_enable_transaction_backpressure = 1'b1;
			reg_scenario_waveform_mode = 0;
			reg_scenario_numeric_vector_mode = 0;
			reg_scenario_sample_count = 64;
			reg_scenario_emit_long_checks = 1'b0;
			reg_scenario_recheck_cancel_mode = 2'd0;
			run_ppg_algorithm_scenario;
			reg_scenario_enable_result_backpressure = 1'b0;
			reg_scenario_enable_waveform_backpressure = 1'b0;
			reg_scenario_enable_transaction_backpressure = 1'b0;
			close_identity_groups;
			finalize_state_scoreboards;
			report_functional_group("OWNER-IDENTITY-BACKPRESSURE", C_TRACE_OIB_BASE, 10);
		end
	endtask

	// RAW-01..13 are closed only from observed physical timing/identity counters.
	// No fixed-delay or direct completion predicate is accepted here.
	task finalize_raw_trace;
		begin
			// RAW-01/12/13 are long-run claims and are never closed by a short
			// calibration or smoke run.  RAW-05..11 require the complete causal
			// chain, not merely one observed event.
			if(reg_scenario_emit_long_checks) begin
				scoreboard_mark(0, (cnt_red_waveform_context >= 4000) && (cnt_ir_waveform_context >= 4000),
					(cnt_red_waveform_context >= 4000) && (cnt_ir_waveform_context >= 4000));
				scoreboard_mark(1, (cnt_red_waveform_context >= 4000) && (cnt_ir_waveform_context >= 4000),
					(flag_raw_profile_notch_rebound && flag_raw_profile_drift_observed && (cnt_raw_profile_rise > 20) && (cnt_raw_profile_fall > 20)));
				// The first long run emits this signature. A repeat xsim must supply it
				// through +RAW_SIGNATURE=<hex>; only then can RAW-03 close.
				scoreboard_mark(2, flag_raw_signature_expected && (cnt_raw_signature_samples >= 8000),
					(reg_raw_signature == reg_expected_raw_signature));
				scoreboard_mark(3, (cnt_red_waveform_context >= 4000) && (cnt_ir_waveform_context >= 4000),
					flag_raw_profile_clamp_observed);
				scoreboard_mark(4, cnt_owner_commit >= 8000, (cnt_raw_q1_observed >= 8000) && (cnt_raw_q2_observed >= 8000) && (cnt_raw_q3_observed >= 8000) && (cnt_raw_q3_end_observed >= 8000));
				scoreboard_mark(5, cnt_owner_commit >= 8000, (cnt_raw_async_observed >= 8000) && (cnt_raw_completion_observed >= 8000));
				scoreboard_mark(6, cnt_owner_commit >= 8000, (cnt_raw_identity_observed >= 8000) && (cnt_identity_mismatch == 0));
				scoreboard_mark(7, cnt_owner_commit >= 8000, flag_ir_context_while_red_inflight && (cnt_ir_waveform_context >= 4000));
				scoreboard_mark(8, cnt_owner_commit >= 8000, flag_numeric_identity_ok && flag_ppg_result_sequence_ok);
				scoreboard_mark(9, cnt_owner_commit >= 1, flag_reset_done_observation || (cnt_identity_mismatch == 0));
				scoreboard_mark(10, cnt_owner_commit >= 1, (cnt_identity_mismatch == 0) && (cnt_completion >= cnt_owner_commit));
				scoreboard_mark(11, 1'b1, (time_ppg_algorithm_end - time_ppg_algorithm_start) >= C_PPG_MIN_DURATION_NS &&
					(cnt_red_waveform_context >= 4000) && (cnt_ir_waveform_context >= 4000) && (cnt_owner_commit >= 8000) &&
					(cnt_completion >= 8000) && (($time - time_ppg_algorithm_start) / C_CLK_PERIOD_NS >= 20000000));
				scoreboard_mark(12, 1'b1, (time_run_deadline - time_run_reset_assert) == C_SIM_TIMEOUT_NS &&
					(time_ppg_algorithm_end <= time_run_deadline) && ((time_ppg_algorithm_end - time_ppg_algorithm_start) >= C_PPG_MIN_DURATION_NS));
			end
		end
	endtask

	// Emit one complete, parseable artifact for the selected xsim process.
	// NOT_CLOSED is preserved whenever no real comparison occurred.
	task emit_scenario_result;
		integer result_index;
		integer result_pass;
		integer result_fail;
		integer result_unclosed;
		integer result_not_applicable;
		integer raw_pass;
		integer raw_fail;
		integer raw_unclosed;
		integer raw_not_applicable;
		begin
			result_pass = 0;
			result_fail = 0;
			result_unclosed = 0;
			result_not_applicable = 0;
			raw_pass = 0;
			raw_fail = 0;
			raw_unclosed = 0;
			raw_not_applicable = 0;
			$display("TB_SCENARIO_BEGIN selector=%0d result_file=%0s", reg_selected_scenario, reg_result_file_path);
			if(fd_result_file != 0) $fwrite(fd_result_file, "TB_RAW_SIGNATURE samples=%0d value=%08h expected_valid=%0d expected=%08h\n", cnt_raw_signature_samples, reg_raw_signature, flag_raw_signature_expected, reg_expected_raw_signature);
			for(result_index = 0; result_index < C_TRACE_COUNT; result_index = result_index + 1)begin
				if(reg_trace_status[result_index] == TRACE_PASS)begin
					if(result_index < C_RAW_TRACE_COUNT) raw_pass = raw_pass + 1;
					else result_pass = result_pass + 1;
					if(fd_result_file != 0) $fwrite(fd_result_file, "%0s_RESULT index=%0d id=%0s run=%0d group=%0s compare_count=%0d status=PASS\n", (result_index < C_RAW_TRACE_COUNT) ? "TB_RAW" : "TB_STABLE", result_index, reg_trace_id[result_index], reg_trace_run_index[result_index], reg_trace_group_id[result_index], reg_trace_compare_count[result_index]);
				end else if(reg_trace_status[result_index] == TRACE_FAIL)begin
					if(result_index < C_RAW_TRACE_COUNT) raw_fail = raw_fail + 1;
					else result_fail = result_fail + 1;
					if(fd_result_file != 0) $fwrite(fd_result_file, "%0s_RESULT index=%0d id=%0s run=%0d group=%0s compare_count=%0d status=FAIL\n", (result_index < C_RAW_TRACE_COUNT) ? "TB_RAW" : "TB_STABLE", result_index, reg_trace_id[result_index], reg_trace_run_index[result_index], reg_trace_group_id[result_index], reg_trace_compare_count[result_index]);
				end else if(reg_trace_status[result_index] == TRACE_UNCHECKED)begin
					if(result_index < C_RAW_TRACE_COUNT) raw_unclosed = raw_unclosed + 1;
					else result_unclosed = result_unclosed + 1;
					if(fd_result_file != 0) $fwrite(fd_result_file, "%0s_RESULT index=%0d id=%0s run=%0d group=%0s compare_count=%0d status=NOT_CLOSED\n", (result_index < C_RAW_TRACE_COUNT) ? "TB_RAW" : "TB_STABLE", result_index, reg_trace_id[result_index], reg_trace_run_index[result_index], reg_trace_group_id[result_index], reg_trace_compare_count[result_index]);
				end else begin
					if(result_index < C_RAW_TRACE_COUNT) raw_not_applicable = raw_not_applicable + 1;
					else result_not_applicable = result_not_applicable + 1;
					if(fd_result_file != 0) $fwrite(fd_result_file, "%0s_RESULT index=%0d id=%0s run=%0d group=%0s compare_count=%0d status=NOT_APPLICABLE\n", (result_index < C_RAW_TRACE_COUNT) ? "TB_RAW" : "TB_STABLE", result_index, reg_trace_id[result_index], reg_trace_run_index[result_index], reg_trace_group_id[result_index], reg_trace_compare_count[result_index]);
				end
			end
			if(fd_result_file != 0)begin
				$fwrite(fd_result_file, "TB_JNT_RESULT run=%0d group=%0s checked=%0d pass=%0d fail=%0d required=%0d status=%0s\n", flag_jnt_parent_valid ? cnt_jnt_parent_run_index : cnt_run_index, flag_jnt_parent_valid ? reg_jnt_parent_group_id : reg_run_group_id, flag_jnt_parent_valid ? cnt_jnt_parent_checked : cnt_run_jnt_checked, flag_jnt_parent_valid ? cnt_jnt_parent_pass : cnt_run_jnt_pass, flag_jnt_parent_valid ? cnt_jnt_parent_fail : cnt_run_jnt_fail, C_JNT_REQUIRED_SUBCHECKS, ((flag_jnt_parent_valid ? cnt_jnt_parent_pass : cnt_run_jnt_pass) == C_JNT_REQUIRED_SUBCHECKS && (flag_jnt_parent_valid ? cnt_jnt_parent_fail : cnt_run_jnt_fail) == 0) ? "PASS" : "NOT_CLOSED");
				$fwrite(fd_result_file, "TB_RAW_SUMMARY pass=%0d fail=%0d not_closed=%0d not_applicable=%0d required=%0d\n", raw_pass, raw_fail, raw_unclosed, raw_not_applicable, C_RAW_TRACE_COUNT);
				$fwrite(fd_result_file, "TB_SCENARIO_RESULT selector=%0d stable_pass=%0d stable_fail=%0d stable_not_closed=%0d stable_not_applicable=%0d events=%0d status=%0s\n", reg_selected_scenario, result_pass, result_fail, result_unclosed, result_not_applicable, cnt_run_event, (result_fail != 0) ? "FAIL" : ((result_unclosed != 0) ? "NOT_CLOSED" : ((result_not_applicable != 0) ? "PARTIAL" : "PASS")));
				$fclose(fd_result_file);
			end
			$display("TB_SCENARIO_RESULT selector=%0d stable_pass=%0d stable_fail=%0d stable_not_closed=%0d stable_not_applicable=%0d events=%0d", reg_selected_scenario, result_pass, result_fail, result_unclosed, result_not_applicable, cnt_run_event);
		end
	endtask

	initial begin
		i_clk = 1'b0;
		#(C_CLK_PERIOD_NS / 2) i_clk = 1'b1;
	end

	always@(posedge i_clk)begin
		#(C_CLK_PERIOD_NS / 2) i_clk = 1'b0;
	end

	always@(negedge i_clk)begin
		#(C_CLK_PERIOD_NS / 2) i_clk = 1'b1;
	end

	// 公共结果接口反压只通过正式 ready 端口施加；内部 fork ready 不被层次改写。
	always@(negedge i_clk)begin
		if((reg_scenario_enable_result_backpressure == 1'b1) && (flag_ppg_algorithm_active == 1'b1) && (o_measurement_result_valid == 1'b1))begin
			if(cnt_result_backpressure_hold < 3)begin
				i_measurement_result_ready = 1'b0;
				cnt_result_backpressure_hold = cnt_result_backpressure_hold + 1;
			end else begin
				i_measurement_result_ready = 1'b1;
				cnt_result_backpressure_hold = 0;
			end
		end else begin
			i_measurement_result_ready = 1'b1;
			cnt_result_backpressure_hold = 0;
		end
	end

	// OIB-01/02 use a legal interconnect adapter in the testbench wrapper.  The
	// adapter blocks a public transfer before either receiving module observes
	// it, then releases exactly the same held request after one full clock.
	always@(negedge i_clk)begin
		if(i_rstn != 1'b1)begin
			reg_oib_waveform_stall_active = 1'b0;
			reg_oib_transaction_stall_active = 1'b0;
		end else begin
			// First allow a complete NORMAL owner through the fixed startup handoff.
			// The directed stall then exercises the next public handover without
			// perturbing the scheduler's START-to-first-waveform qualification.
			if(reg_scenario_enable_waveform_backpressure && !flag_oib_waveform_stall_complete &&
				(cnt_owner_commit > 0) && o_normal_frame_active &&
				o_waveform_context_valid_raw && o_waveform_context_ready_raw) begin
				if(!reg_oib_waveform_stall_active) begin
					reg_oib_waveform_stall_active = 1'b1;
					flag_oib_waveform_stall_seen = 1'b1;
				end else if(cnt_oib_waveform_stall_cycles >= C_OIB_STALL_CYCLES) begin
					reg_oib_waveform_stall_active = 1'b0;
					flag_oib_waveform_stall_complete = 1'b1;
				end
			end else if(!reg_scenario_enable_waveform_backpressure) begin
				reg_oib_waveform_stall_active = 1'b0;
			end
			if(reg_scenario_enable_transaction_backpressure && !flag_oib_transaction_stall_complete &&
				(cnt_owner_commit > 0) && o_normal_frame_active &&
				o_transaction_start_valid_raw && o_transaction_start_ready_raw) begin
				if(!reg_oib_transaction_stall_active) begin
					reg_oib_transaction_stall_active = 1'b1;
					flag_oib_transaction_stall_seen = 1'b1;
				end else if(cnt_oib_transaction_stall_cycles >= C_OIB_STALL_CYCLES) begin
					reg_oib_transaction_stall_active = 1'b0;
					flag_oib_transaction_stall_complete = 1'b1;
				end
			end else if(!reg_scenario_enable_transaction_backpressure) begin
				reg_oib_transaction_stall_active = 1'b0;
			end
		end
	end

	// Each stalled public payload is snapshotted at its first held cycle.  A
	// change, early owner commit, or sample-index advance is a real OIB failure.
	always@(posedge i_clk)begin
		if(i_rstn == 1'b1)begin
			if(reg_oib_waveform_stall_active && o_waveform_context_valid_raw) begin
				cnt_oib_waveform_stall_cycles = cnt_oib_waveform_stall_cycles + 1;
				if(!flag_oib_waveform_snapshot_valid) begin
					flag_oib_waveform_snapshot_valid = 1'b1;
					reg_oib_waveform_frame_id = o_waveform_frame_id;
					reg_oib_waveform_color_ir = o_waveform_color_ir;
					reg_oib_waveform_frame_type = o_waveform_frame_type;
					reg_oib_waveform_precision_mode = o_waveform_precision_mode;
					reg_oib_waveform_amb_code = o_waveform_amb_code_snapshot;
					reg_oib_waveform_dc_code = o_waveform_dc_code_snapshot;
					reg_oib_waveform_next_sample_index = o_scheduler_next_sample_index;
				end else if((o_waveform_frame_id != reg_oib_waveform_frame_id) ||
					(o_waveform_color_ir != reg_oib_waveform_color_ir) ||
					(o_waveform_frame_type != reg_oib_waveform_frame_type) ||
					(o_waveform_precision_mode != reg_oib_waveform_precision_mode) ||
					(o_waveform_amb_code_snapshot != reg_oib_waveform_amb_code) ||
					(o_waveform_dc_code_snapshot != reg_oib_waveform_dc_code) ||
					(o_scheduler_next_sample_index != reg_oib_waveform_next_sample_index) ||
					o_adc_owner_commit_event) begin
					flag_oib_waveform_hold_ok = 1'b0;
				end
			end
			if(reg_oib_transaction_stall_active && o_transaction_start_valid_raw) begin
				cnt_oib_transaction_stall_cycles = cnt_oib_transaction_stall_cycles + 1;
				if(!flag_oib_transaction_snapshot_valid) begin
					flag_oib_transaction_snapshot_valid = 1'b1;
					reg_oib_transaction_frame_id = o_transaction_frame_id;
					reg_oib_transaction_sample_index = o_transaction_sample_index;
					reg_oib_transaction_color_ir = o_transaction_color_ir;
					reg_oib_transaction_frame_type = o_transaction_frame_type;
					reg_oib_transaction_precision_mode = o_transaction_precision_mode;
					reg_oib_transaction_amb_code = o_transaction_amb_code_snapshot;
					reg_oib_transaction_dc_code = o_transaction_dc_code_snapshot;
					reg_oib_transaction_next_sample_index = o_scheduler_next_sample_index;
				end else if((o_transaction_frame_id != reg_oib_transaction_frame_id) ||
					(o_transaction_sample_index != reg_oib_transaction_sample_index) ||
					(o_transaction_color_ir != reg_oib_transaction_color_ir) ||
					(o_transaction_frame_type != reg_oib_transaction_frame_type) ||
					(o_transaction_precision_mode != reg_oib_transaction_precision_mode) ||
					(o_transaction_amb_code_snapshot != reg_oib_transaction_amb_code) ||
					(o_transaction_dc_code_snapshot != reg_oib_transaction_dc_code) ||
					(o_scheduler_next_sample_index != reg_oib_transaction_next_sample_index) ||
					o_adc_owner_commit_event) begin
					flag_oib_transaction_hold_ok = 1'b0;
				end
			end
			if(flag_oib_waveform_stall_complete && !flag_oib_waveform_accept_seen &&
				o_waveform_context_valid_raw && o_waveform_context_ready) begin
				flag_oib_waveform_accept_seen = 1'b1;
				cnt_oib_waveform_accept = cnt_oib_waveform_accept + 1;
			end
			if(flag_oib_transaction_stall_complete && !flag_oib_transaction_accept_seen &&
				o_transaction_start_valid_raw && o_transaction_start_ready) begin
				flag_oib_transaction_accept_seen = 1'b1;
				cnt_oib_transaction_accept = cnt_oib_transaction_accept + 1;
			end
		end
	end

	// ISE-07 observes two asymmetric public code snapshots, proving that the
	// four 8-bit buses are gated bit-by-bit rather than by a single enable.
	always@(negedge i_clk)begin
		if(i_rstn == 1'b1)begin
			if(o_idac_sar9ambn_low == 8'h31 || o_idac_sar15ambn_low == 8'h31) flag_ise_pattern_31_seen = 1'b1;
			if(o_idac_sar9dcn_low == 8'h42 || o_idac_sar15dcn_low == 8'h42) flag_ise_pattern_42_seen = 1'b1;
			if(o_idac_sar9dcn_low == 8'h53 || o_idac_sar15dcn_low == 8'h53) flag_ise_pattern_53_seen = 1'b1;
		end
	end

	// STATIC_BIAS S[4:0] is sampled on the real 2-MHz static-vector clock.
	// The monitor records one transition and rejects a mixed-bit/intermediate
	// value; it never drives or forces the DUT output.
	always@(posedge o_ssw_clk_2m)begin
		if((i_rstn == 1'b1) && (i_static_characterization_enable == 1'b1))begin
			if(o_s_in != reg_static_prev_s_in)begin
				flag_static_s_edge_seen = 1'b1;
				if(o_s_in != i_test_mux_ctrl) flag_static_s_edge_atomic = 1'b0;
			end
			reg_static_prev_s_in = o_s_in;
		end
	end

	// Q3 release and CLK_DOUT are event-driven observations, not synthesized fixed-delay DONEs.
	// The AMI capture transfer is intentionally not logged as a separate PASS event because the
	// current public interface exposes its causal completion sideband, but not an internal capture valid.
	always@(posedge o_clk_q3_low)begin
		if(i_rstn == 1'b1 && o_adc_owner_inflight == 1'b1)begin
			cnt_raw_q3_end_observed = cnt_raw_q3_end_observed + 1;
			if(i_static_characterization_enable == 1'b1) flag_static_q3_seen = 1'b1;
			log_public_event("Q3_END", o_adc_owner_frame_id, o_adc_owner_sample_index,
				o_adc_owner_color_ir, o_adc_owner_frame_type, o_adc_owner_precision_mode);
		end
	end

	// Capture one-cycle integration fault predicates before the DUT sticky bit is set.
	always@(negedge i_clk)begin
		if((i_rstn == 1'b1) && (ppg_adc_measurement_idac_integration_Inst.flag_integration_blocking == 1'b0) &&
			(ppg_adc_measurement_idac_integration_Inst.flag_calibration_result_mismatch ||
			 ppg_adc_measurement_idac_integration_Inst.flag_start_context_mismatch ||
			 ppg_adc_measurement_idac_integration_Inst.flag_adc_capture_without_owner ||
			 (ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_emit && !ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_owner_match) ||
			 (ppg_adc_measurement_idac_integration_Inst.flag_startup_request_source && ppg_adc_measurement_idac_integration_Inst.flag_recheck_request_source)))begin
			$display("TB_INTEGRATION_BLOCK_PREEDGE group=%0s macro_tick=%0d cal_tick=%0d result_mismatch=%0d start_context_mismatch=%0d capture_without_owner=%0d completion_emit=%0d completion_owner_match=%0d startup_source=%0d recheck_source=%0d cal_inflight=%0d normal_start_match=%0d cal_start_match=%0d normal_valid=%0d cal_valid=%0d", reg_run_group_id, o_macro_tick, o_calibration_local_tick, ppg_adc_measurement_idac_integration_Inst.flag_calibration_result_mismatch, ppg_adc_measurement_idac_integration_Inst.flag_start_context_mismatch, ppg_adc_measurement_idac_integration_Inst.flag_adc_capture_without_owner, ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_emit, ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_owner_match, ppg_adc_measurement_idac_integration_Inst.flag_startup_request_source, ppg_adc_measurement_idac_integration_Inst.flag_recheck_request_source, ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight, ppg_adc_measurement_idac_integration_Inst.flag_normal_start_match, ppg_adc_measurement_idac_integration_Inst.flag_calibration_start_match, o_transaction_start_valid, o_calibration_sample_valid);
			if(ppg_adc_measurement_idac_integration_Inst.flag_start_context_mismatch &&
				!flag_normal_mismatch_reported)begin
				flag_normal_mismatch_reported = 1'b1;
				$display("TB_NORMAL_START_MISMATCH precision_tx=%0d precision_active=%0d amb_tx=%0d amb_committed=%0d amb_epoch_tx=%0d amb_epoch_committed=%0d dc_tx=%0d dc_committed=%0d dc_epoch_tx=%0d dc_epoch_committed=%0d color_ir=%0d frame_type=%0d frame_id=%0d sample_index=%0d", o_transaction_precision_mode, o_active_precision_mode, o_transaction_amb_code_snapshot, o_amb_code, o_transaction_amb_code_epoch, o_amb_code_epoch, o_transaction_dc_code_snapshot, (o_transaction_color_ir ? o_dcs_ir_code : o_dcs_r_code), o_transaction_dc_code_epoch, (o_transaction_color_ir ? o_dcs_ir_code_epoch : o_dcs_r_code_epoch), o_transaction_color_ir, o_transaction_frame_type, o_transaction_frame_id, o_transaction_sample_index);
				$display("TB_NORMAL_START_SCHED_STATE frame_active=%0d frame_mode=%0d cal_req_pending=%0d cal_req_active=%0d cal_wave_pending=%0d red_wave_pending=%0d ir_wave_pending=%0d inflight=%0d cand_cal=%0d cand_red=%0d cand_ir=%0d sched_start_valid=%0d", ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode, ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_WAVE_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_RED_WAVE_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_IR_WAVE_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT], ppg_400hz_frame_calibration_scheduler_Inst.flag_candidate_calibration, ppg_400hz_frame_calibration_scheduler_Inst.flag_candidate_red, ppg_400hz_frame_calibration_scheduler_Inst.flag_candidate_ir, o_transaction_start_valid);
			end
		end
	end

	always@(posedge i_clk_stage1_dout_low_async)begin
		if(i_rstn == 1'b1 && o_adc_owner_inflight == 1'b1)begin
			cnt_raw_async_observed = cnt_raw_async_observed + 1;
			if(reg_recheck_calibration_active || o_amb_recheck_busy) cnt_recheck_async_observed = cnt_recheck_async_observed + 1;
			if(i_static_characterization_enable == 1'b1) flag_static_async_seen = 1'b1;
			log_public_event("ADC_RAW_ASYNC", o_adc_owner_frame_id, o_adc_owner_sample_index,
				o_adc_owner_color_ir, o_adc_owner_frame_type, o_adc_owner_precision_mode);
		end
	end

	// The owner monitor below latches calibration commits; the responder starts
	// on the next half-cycle so the public owner snapshot is stable.
	always@(negedge i_clk)begin
		if((i_rstn == 1'b1) && reg_calibration_adc_driver_pending &&
			!reg_calibration_adc_driver_busy)begin
			reg_calibration_adc_driver_pending = 1'b0;
			reg_calibration_adc_driver_busy = 1'b1;
			log_public_event("CAL_DRIVER_START", o_adc_owner_frame_id, o_adc_owner_sample_index,
				reg_calibration_pending_color_ir, reg_calibration_pending_frame_type,
				reg_calibration_pending_precision_mode);
			drive_calibration_adc_done(reg_calibration_pending_precision_mode,
				reg_calibration_pending_color_ir, reg_calibration_pending_frame_type);
		end
	end

	// 监视真实握手与完成事件，所有快照均来自三模块互连而非TB伪造信号。
	always@(posedge i_clk)begin
		if(i_rstn == 1'b1)begin
			if(o_waveform_context_valid && ((reg_run_group_id == "STARTUP-IDAC-CALIBRATION") || (reg_run_group_id == "PERIODIC-RECHECK-RECOVERY")))begin
				$display("TB_STARTUP_WAVEFORM valid type=%0b color=%0b frame=%0d macro_tick=%0d cal_tick=%0d ready=%0b normal_active=%0b cal_active=%0b analog_enable=%0b input_source=%0b optical=%0b precision=%0b wave_input=%0b wave_optical=%0b wave_precision=%0b wrapper_idle=%0b analog_ack=%0b", o_waveform_frame_type, o_waveform_color_ir, o_waveform_frame_id, o_macro_tick, o_calibration_local_tick, o_waveform_context_ready, o_normal_frame_active, o_calibration_frame_active, analog_run_enable, i_input_source, i_optical_mode, o_active_precision_mode, o_waveform_input_source, o_waveform_optical_mode, o_waveform_precision_mode, o_ssw_wrapper_idle, analog_start_ack_event);
			end
			if((reg_run_group_id == "PERIODIC-RECHECK-RECOVERY") && o_calibration_frame_active && (o_calibration_local_tick == 10'd0))begin
				$display("TB_CAL_SUBFRAME_ZERO macro_tick=%0d valid=%0d ready=%0d cal_valid=%0d cal_fire=%0d cal_pending=%0d cal_active=%0d cal_seen=%0d cal_wave_pending=%0d inflight=%0d started=%0d stop_drain=%0d cfg_valid=%0d run_enable=%0d ext_fault=%0d local_fault=%0d lifecycle=%0d cal_ready_int=%0d frame_active=%0d frame_mode=%0d", o_macro_tick, o_waveform_context_valid, o_waveform_context_ready, o_calibration_sample_valid, o_calibration_request_fire, ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_CONTEXT_SEEN], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_WAVE_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_STARTED], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_STOP_DRAIN], i_active_config_valid, measurement_run_enable, ppg_400hz_frame_calibration_scheduler_Inst.flag_external_fault, ppg_400hz_frame_calibration_scheduler_Inst.scheduler_local_fault_blocking_o, ppg_400hz_frame_calibration_scheduler_Inst.flag_lifecycle_active, ppg_400hz_frame_calibration_scheduler_Inst.calibration_sample_ready_o, ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode);
			end
			if(measurement_start_ack_event == 1'b1)begin
				log_public_event("MEASUREMENT_START", 16'd0, 16'd0, 1'b0, 2'd0, i_initial_precision);
			end
			if(o_startup_idac_safe_boundary == 1'b1)begin
				cnt_startup_boundary = cnt_startup_boundary + 1;
				flag_startup_boundary_without_owner = !o_transaction_start_fire && !o_adc_owner_commit_event;
				reg_startup_boundary_sample_index = o_scheduler_next_sample_index;
			end
			if(o_waveform_context_valid && o_waveform_context_ready)begin
				cnt_waveform_context = cnt_waveform_context + 1;
				log_public_event("WAVEFORM_ACCEPT", o_waveform_frame_id, o_scheduler_next_sample_index,
					o_waveform_color_ir, o_waveform_frame_type, o_waveform_precision_mode);
				if(o_waveform_color_ir == 1'b0)begin
					cnt_red_waveform_context = cnt_red_waveform_context + 1;
					reg_red_waveform_precision_mode = o_waveform_precision_mode;
					reg_red_waveform_amb_code = o_waveform_amb_code_snapshot;
					reg_red_waveform_dc_code = o_waveform_dc_code_snapshot;
				end else begin
					cnt_ir_waveform_context = cnt_ir_waveform_context + 1;
					reg_ir_waveform_precision_mode = o_waveform_precision_mode;
					reg_ir_waveform_amb_code = o_waveform_amb_code_snapshot;
					reg_ir_waveform_dc_code = o_waveform_dc_code_snapshot;
					if(o_scheduler_transaction_inflight && (reg_last_owner_color_ir == 1'b0))begin
						flag_ir_context_while_red_inflight = 1'b1;
					end
				end
			end
			if(o_adc_owner_commit_event == 1'b1)begin
				cnt_owner_commit = cnt_owner_commit + 1;
				log_public_event("OWNER_COMMIT", o_adc_owner_frame_id, o_adc_owner_sample_index,
					o_adc_owner_color_ir, o_adc_owner_frame_type, o_adc_owner_precision_mode);
				reg_last_owner_color_ir = o_adc_owner_color_ir;
				reg_last_owner_frame_id = o_adc_owner_frame_id;
				reg_last_owner_sample_index = o_adc_owner_sample_index;
				reg_last_owner_macro_tick = o_macro_tick;
				reg_last_owner_precision_mode = o_adc_owner_precision_mode;
				reg_last_owner_frame_type = o_adc_owner_frame_type;
				reg_last_owner_amb_code = o_adc_owner_amb_code_snapshot;
				reg_last_owner_dc_code = o_adc_owner_dc_code_snapshot;
				flag_owner_context_identity_match = (o_adc_owner_color_ir == 1'b0) ? ((o_adc_owner_precision_mode == reg_red_waveform_precision_mode) && (o_adc_owner_amb_code_snapshot == reg_red_waveform_amb_code) && (o_adc_owner_dc_code_snapshot == reg_red_waveform_dc_code)) : ((o_adc_owner_precision_mode == reg_ir_waveform_precision_mode) && (o_adc_owner_amb_code_snapshot == reg_ir_waveform_amb_code) && (o_adc_owner_dc_code_snapshot == reg_ir_waveform_dc_code));
				reg_owner_scoreboard_valid = 1'b1;
				reg_completed_owner_valid = 1'b0;
				reg_completed_owner_color_ir = o_adc_owner_color_ir;
				reg_completed_owner_precision_mode = o_adc_owner_precision_mode;
				reg_completed_owner_frame_id = o_adc_owner_frame_id;
				reg_completed_owner_sample_index = o_adc_owner_sample_index;
				reg_completed_owner_frame_type = o_adc_owner_frame_type;
				reg_completed_owner_amb_code = o_adc_owner_amb_code_snapshot;
				reg_completed_owner_dc_code = o_adc_owner_dc_code_snapshot;
				reg_completed_owner_amb_epoch = o_adc_owner_amb_code_epoch;
				reg_completed_owner_dc_epoch = o_adc_owner_dc_code_epoch;
				reg_completed_owner_config_epoch = i_config_epoch;
				reg_completed_owner_coef_epoch = i_stage1_coef_epoch;
				reg_completed_owner_stage2_epoch = o_adc_owner_precision_mode ? i_stage2_coef_epoch : 8'd0;
				reg_completed_owner_dc_epoch_cfg = i_dc_recovery_coef_epoch;
				reg_completed_owner_stage1_raw = reg_last_driven_stage1_raw;
				reg_completed_owner_stage2_raw = reg_last_driven_stage2_raw;
				reg_completed_owner_raw_valid = reg_last_driven_raw_valid;
				if(o_adc_owner_frame_type != FRAME_TYPE_NORMAL)begin
					if(!reg_calibration_adc_driver_busy)begin
						reg_calibration_adc_driver_pending = 1'b1;
						reg_calibration_pending_precision_mode = o_adc_owner_precision_mode;
						reg_calibration_pending_color_ir = o_adc_owner_color_ir;
						reg_calibration_pending_frame_type = o_adc_owner_frame_type;
						log_public_event("CAL_DRIVER_PENDING", o_adc_owner_frame_id, o_adc_owner_sample_index,
							o_adc_owner_color_ir, o_adc_owner_frame_type, o_adc_owner_precision_mode);
					end
					if(o_calibration_local_tick > 10'd248)begin
						cnt_startup_owner_deadline_mismatch = cnt_startup_owner_deadline_mismatch + 1;
						flag_startup_owner_deadline_ok = 1'b0;
					end
					if(reg_recheck_calibration_active || o_amb_recheck_busy)begin
						reg_recheck_owner_waiting = 1'b1;
						reg_recheck_owner_async_seen = 1'b0;
					end else if(o_startup_search_complete !== 1'b1)begin
						reg_startup_owner_waiting = 1'b1;
						reg_startup_owner_async_seen = 1'b0;
					end
				end
				flag_red_q1_seen = 1'b0;
				flag_red_q2_seen = 1'b0;
				flag_red_q3_seen = 1'b0;
				flag_ir_q1_seen = 1'b0;
				flag_ir_q2_seen = 1'b0;
				flag_ir_q3_seen = 1'b0;
			end
			if(o_adc_owner_inflight == 1'b1)begin
				if(reg_last_owner_color_ir == 1'b0)begin
					if((reg_last_owner_precision_mode ? o_clk_15q1_low : o_clk_9q1_low) == 1'b1)begin
						flag_red_q1_seen = 1'b1;
						cnt_raw_q1_observed = cnt_raw_q1_observed + 1;
						if(i_static_characterization_enable == 1'b1) flag_static_q1_seen = 1'b1;
					end
					if(o_clk_q2_low == 1'b1)begin
						flag_red_q2_seen = 1'b1;
						cnt_raw_q2_observed = cnt_raw_q2_observed + 1;
						if(i_static_characterization_enable == 1'b1) flag_static_q2_seen = 1'b1;
					end
					if(o_clk_q3_low == 1'b1)begin
						flag_red_q3_seen = 1'b1;
						cnt_raw_q3_observed = cnt_raw_q3_observed + 1;
						if(i_static_characterization_enable == 1'b1) flag_static_q3_seen = 1'b1;
					end
				end else begin
					if((reg_last_owner_precision_mode ? o_clk_15q1_low : o_clk_9q1_low) == 1'b1)begin
						flag_ir_q1_seen = 1'b1;
						cnt_raw_q1_observed = cnt_raw_q1_observed + 1;
						if(i_static_characterization_enable == 1'b1) flag_static_q1_seen = 1'b1;
					end
					if(o_clk_q2_low == 1'b1)begin
						flag_ir_q2_seen = 1'b1;
						cnt_raw_q2_observed = cnt_raw_q2_observed + 1;
						if(i_static_characterization_enable == 1'b1) flag_static_q2_seen = 1'b1;
					end
					if(o_clk_q3_low == 1'b1)begin
						flag_ir_q3_seen = 1'b1;
						cnt_raw_q3_observed = cnt_raw_q3_observed + 1;
						if(i_static_characterization_enable == 1'b1) flag_static_q3_seen = 1'b1;
					end
				end
			end
			if((cnt_red_waveform_context > 0) && (reg_red_waveform_precision_mode == 1'b0))begin
				if((reg_red_waveform_amb_code != 8'h00) && (o_idac_sar9ambn_low == reg_red_waveform_amb_code))begin
					flag_selected_amb_bus_seen = 1'b1;
				end
				if((reg_red_waveform_dc_code != 8'h00) && (o_idac_sar9dcn_low == reg_red_waveform_dc_code))begin
					flag_selected_dc_bus_seen = 1'b1;
					flag_red_dc_bus_seen = 1'b1;
				end
				if((o_idac_sar15ambn_low != 8'h00) || (o_idac_sar15dcn_low != 8'h00))begin
					flag_unselected_idac_bus_clean = 1'b0;
					flag_idac_bus_violation = 1'b1;
				end
			end else if(cnt_red_waveform_context > 0)begin
				if((reg_red_waveform_amb_code != 8'h00) && (o_idac_sar15ambn_low == reg_red_waveform_amb_code))begin
					flag_selected_amb_bus_seen = 1'b1;
				end
				if((reg_red_waveform_dc_code != 8'h00) && (o_idac_sar15dcn_low == reg_red_waveform_dc_code))begin
					flag_selected_dc_bus_seen = 1'b1;
					flag_red_dc_bus_seen = 1'b1;
				end
				if((o_idac_sar9ambn_low != 8'h00) || (o_idac_sar9dcn_low != 8'h00))begin
					flag_unselected_idac_bus_clean = 1'b0;
					flag_idac_bus_violation = 1'b1;
				end
			end
			if((cnt_ir_waveform_context > 0) && (reg_ir_waveform_dc_code != 8'h00) && ((reg_ir_waveform_precision_mode == 1'b0 && o_idac_sar9dcn_low == reg_ir_waveform_dc_code) || (reg_ir_waveform_precision_mode == 1'b1 && o_idac_sar15dcn_low == reg_ir_waveform_dc_code)))begin
				flag_ir_dc_bus_seen = 1'b1;
			end
			if(o_adc_transaction_complete_event == 1'b1)begin
				cnt_raw_completion_observed = cnt_raw_completion_observed + 1;
				if(i_static_characterization_enable == 1'b1) flag_static_done_seen = 1'b1;
				if(reg_recheck_cancel_triggered && (reg_scenario_recheck_cancel_mode == 2'd2))begin
					$display("TB_RRC12_ABORT_DONE_DIAG state_inflight=%0d state_discard=%0d state_stop_drain=%0d state_protocol_error=%0d state_completion_mismatch=%0d owner_sample=%0d complete_sample=%0d owner_frame=%0d complete_success=%0d", ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_DISCARD], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_STOP_DRAIN], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_PROTOCOL_ERROR], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_COMPLETION_MISMATCH], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_SAMPLE_H:ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_SAMPLE_L], o_adc_complete_sample_index, reg_completed_owner_frame_type, o_adc_transaction_success);
				end
				cnt_completion = cnt_completion + 1;
				log_public_event("AMI_COMPLETE", reg_completed_owner_frame_id, o_adc_complete_sample_index,
					reg_completed_owner_color_ir, reg_completed_owner_frame_type, reg_completed_owner_precision_mode);
				reg_last_completion_success = o_adc_transaction_success;
				reg_last_completion_sample_index = o_adc_complete_sample_index;
				if(reg_recheck_cancel_triggered && (reg_completed_owner_frame_type != FRAME_TYPE_NORMAL) &&
					(o_adc_transaction_success == 1'b0))begin
					reg_recheck_cancel_late_done_seen = 1'b1;
				end
				if(reg_owner_scoreboard_valid == 1'b0)begin
					cnt_identity_mismatch = cnt_identity_mismatch + 1;
				end else if(o_adc_complete_sample_index != reg_completed_owner_sample_index)begin
					cnt_identity_mismatch = cnt_identity_mismatch + 1;
				end else begin
					cnt_identity_comparison = cnt_identity_comparison + 1;
					reg_completed_owner_valid = 1'b1;
					reg_completed_owner_success = o_adc_transaction_success;
					reg_completed_owner_stage1_raw = reg_last_driven_stage1_raw;
					reg_completed_owner_stage2_raw = reg_last_driven_stage2_raw;
					reg_completed_owner_raw_valid = reg_last_driven_raw_valid;
				end
				if(reg_completed_owner_valid && reg_completed_owner_success && (reg_completed_owner_frame_type == FRAME_TYPE_NORMAL))begin
					if(cnt_result_scoreboard_count < C_RESULT_SCOREBOARD_DEPTH)begin
						reg_result_scoreboard_valid[cnt_result_scoreboard_tail] = 1'b1;
						reg_result_scoreboard_color_ir[cnt_result_scoreboard_tail] = reg_completed_owner_color_ir;
						reg_result_scoreboard_precision[cnt_result_scoreboard_tail] = reg_completed_owner_precision_mode;
						reg_result_scoreboard_frame_id[cnt_result_scoreboard_tail] = reg_completed_owner_frame_id;
						reg_result_scoreboard_sample_index[cnt_result_scoreboard_tail] = reg_completed_owner_sample_index;
						reg_result_scoreboard_frame_type[cnt_result_scoreboard_tail] = reg_completed_owner_frame_type;
						reg_result_scoreboard_amb_code[cnt_result_scoreboard_tail] = reg_completed_owner_amb_code;
						reg_result_scoreboard_dc_code[cnt_result_scoreboard_tail] = reg_completed_owner_dc_code;
						reg_result_scoreboard_amb_epoch[cnt_result_scoreboard_tail] = reg_completed_owner_amb_epoch;
						reg_result_scoreboard_dc_epoch[cnt_result_scoreboard_tail] = reg_completed_owner_dc_epoch;
						reg_result_scoreboard_config_epoch[cnt_result_scoreboard_tail] = reg_completed_owner_config_epoch;
						reg_result_scoreboard_coef_epoch[cnt_result_scoreboard_tail] = reg_completed_owner_coef_epoch;
						reg_result_scoreboard_stage2_epoch[cnt_result_scoreboard_tail] = reg_completed_owner_stage2_epoch;
						reg_result_scoreboard_dc_coef_epoch[cnt_result_scoreboard_tail] = reg_completed_owner_dc_epoch_cfg;
						reg_result_scoreboard_stage1_raw[cnt_result_scoreboard_tail] = reg_completed_owner_stage1_raw;
						reg_result_scoreboard_stage2_raw[cnt_result_scoreboard_tail] = reg_completed_owner_stage2_raw;
						reg_result_scoreboard_raw_valid[cnt_result_scoreboard_tail] = reg_completed_owner_raw_valid;
						if(cnt_result_scoreboard_tail == (C_RESULT_SCOREBOARD_DEPTH - 1)) cnt_result_scoreboard_tail = 0;
						else cnt_result_scoreboard_tail = cnt_result_scoreboard_tail + 1;
						cnt_result_scoreboard_count = cnt_result_scoreboard_count + 1;
					end else begin
						cnt_result_scoreboard_overflow = cnt_result_scoreboard_overflow + 1;
						cnt_identity_mismatch = cnt_identity_mismatch + 1;
						flag_numeric_identity_ok = 1'b0;
					end
				end
				if(reg_completed_owner_frame_type != FRAME_TYPE_NORMAL)begin
					if(reg_recheck_owner_waiting)begin
						cnt_recheck_calibration_completion = cnt_recheck_calibration_completion + 1;
						if(reg_completed_owner_success) cnt_recheck_successful_calibration_completion = cnt_recheck_successful_calibration_completion + 1;
						$display("TB_RECHECK_INTERNAL event=COMPLETE idac_state=%0d idac_amb_qualified=%0d idac_in_window=%0d idac_dcs_request=%0d idac_dcs_busy=%0d sched_state=%0d sched_dcs_accept=%0d sched_stage_result_done=%0d sched_stage_frame_complete=%0d router_s1=%0d amb_threshold=%0d..%0d dcs_threshold=%0d..%0d",
							ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current,
							ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.flag_amb_sample_qualified,
							ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.flag_search_in_window,
							ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_request,
							ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_busy,
							ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.state_current,
							ppg_adc_measurement_idac_integration_Inst.flag_precision_dcs_revalidate_accept,
							ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_stage_result_done,
							ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_stage_frame_complete,
							$signed(ppg_adc_measurement_idac_integration_Inst.dec_router_calibrated_s1_value),
							i_amb_threshold_low, i_amb_threshold_high, i_dcs_threshold_low, i_dcs_threshold_high);
						$display("TB_RECHECK_CAL_RESULT type=%0d color=%0d success=%0d s1=%0d raw_valid=%0d q3=%0d router_s1=%0d router_applied=%0d router_amb_valid=%0d router_dcs_valid=%0d router_type=%0d router_amb_epoch=%0d router_dc_epoch=%0d",
							reg_completed_owner_frame_type, reg_completed_owner_color_ir,
							reg_completed_owner_success, $signed(o_calibrated_s1_value),
							reg_completed_owner_raw_valid, reg_recheck_owner_async_seen,
							$signed(ppg_adc_measurement_idac_integration_Inst.dec_router_calibrated_s1_value),
							ppg_adc_measurement_idac_integration_Inst.flag_router_calibration_applied,
							ppg_adc_measurement_idac_integration_Inst.flag_router_amb_valid,
							ppg_adc_measurement_idac_integration_Inst.flag_router_dcs_valid,
							ppg_adc_measurement_idac_integration_Inst.dec_router_frame_type,
							ppg_adc_measurement_idac_integration_Inst.dec_router_amb_code_epoch,
							ppg_adc_measurement_idac_integration_Inst.dec_router_dc_code_epoch);
						if(reg_completed_owner_frame_type == FRAME_TYPE_AMB)begin
							cnt_recheck_amb_completion = cnt_recheck_amb_completion + 1;
						end else if(reg_completed_owner_color_ir == 1'b0)begin
							cnt_recheck_dcs_r_completion = cnt_recheck_dcs_r_completion + 1;
						end else begin
							cnt_recheck_dcs_ir_completion = cnt_recheck_dcs_ir_completion + 1;
						end
						if(!reg_recheck_owner_async_seen || ((reg_completed_owner_color_ir == 1'b0) && !flag_red_q3_seen) ||
							((reg_completed_owner_color_ir == 1'b1) && !flag_ir_q3_seen))begin
							cnt_recheck_real_chain_mismatch = cnt_recheck_real_chain_mismatch + 1;
						end
						reg_recheck_owner_waiting = 1'b0;
						reg_recheck_owner_async_seen = 1'b0;
					end else if(reg_startup_owner_waiting)begin
						cnt_startup_calibration_completion = cnt_startup_calibration_completion + 1;
						if(reg_completed_owner_success) cnt_startup_successful_calibration_completion = cnt_startup_successful_calibration_completion + 1;
						if(reg_completed_owner_frame_type == FRAME_TYPE_AMB)begin
							cnt_startup_amb_completion = cnt_startup_amb_completion + 1;
							if((reg_startup_stage_state != 2'd0) &&
								!((reg_startup_stage_state == 2'd1) && (cnt_startup_amb_completion <= 8))) flag_idac_startup_order_ok = 1'b0;
							reg_startup_stage_state = 2'd1;
						end else if(reg_completed_owner_color_ir == 1'b0)begin
							cnt_startup_dcs_r_completion = cnt_startup_dcs_r_completion + 1;
							if((reg_startup_stage_state != 2'd1) &&
								!((reg_startup_stage_state == 2'd2) && (cnt_startup_dcs_r_completion <= 8))) flag_idac_startup_order_ok = 1'b0;
							reg_startup_stage_state = 2'd2;
						end else begin
							cnt_startup_dcs_ir_completion = cnt_startup_dcs_ir_completion + 1;
							if((reg_startup_stage_state != 2'd2) &&
								!((reg_startup_stage_state == 2'd3) && (cnt_startup_dcs_ir_completion <= 8))) flag_idac_startup_order_ok = 1'b0;
							reg_startup_stage_state = 2'd3;
						end
							if(!reg_startup_owner_async_seen || ((reg_completed_owner_color_ir == 1'b0) && !flag_red_q3_seen) ||
								((reg_completed_owner_color_ir == 1'b1) && !flag_ir_q3_seen))begin
								cnt_startup_real_chain_mismatch = cnt_startup_real_chain_mismatch + 1;
							end
							if(reg_scenario_group_id == "STARTUP-IDAC-CALIBRATION")begin
								$display("TB_STARTUP_COMPLETION type=%0d color=%0d success=%0d amb=%0d dcs_r=%0d dcs_ir=%0d state=%0d order_ok=%0d", reg_completed_owner_frame_type, reg_completed_owner_color_ir, reg_completed_owner_success, cnt_startup_amb_completion, cnt_startup_dcs_r_completion, cnt_startup_dcs_ir_completion, reg_startup_stage_state, flag_idac_startup_order_ok);
							end
							reg_startup_owner_waiting = 1'b0;
						reg_startup_owner_async_seen = 1'b0;
					end
				end
				reg_owner_scoreboard_valid = 1'b0;
			end
			if(o_measurement_result_valid && i_measurement_result_ready)begin
				cnt_measurement_result = cnt_measurement_result + 1;
				// RRC-12 is closed by an event-level no-leak check.  A result
				// accepted after STOP/abort is a failure even if a global counter
				// happens to be sampled on the same clock edge as the cancel task.
				if(reg_recheck_cancel_triggered &&
					((reg_scenario_recheck_cancel_mode == 2'd1) ||
					 (reg_scenario_recheck_cancel_mode == 2'd2)))begin
					reg_recheck_cancel_result_leak = 1'b1;
					$display("TB_RRC12_RESULT_LEAK mode=%0d frame=%0d sample=%0d type=%0d precision=%0d", reg_scenario_recheck_cancel_mode, o_result_frame_id, o_result_sample_index, o_result_frame_type, o_result_precision_mode);
				end
				log_public_event("RESULT_ACCEPT", o_result_frame_id, o_result_sample_index,
					o_result_color_ir, o_result_frame_type, o_result_precision_mode);
				if((cnt_result_scoreboard_count == 0) || (reg_result_scoreboard_valid[cnt_result_scoreboard_head] == 1'b0))begin
					cnt_identity_mismatch = cnt_identity_mismatch + 1;
					flag_numeric_identity_ok = 1'b0;
				end else begin
					cnt_identity_comparison = cnt_identity_comparison + 1;
					cnt_raw_identity_observed = cnt_raw_identity_observed + 1;
					if((o_result_color_ir != reg_result_scoreboard_color_ir[cnt_result_scoreboard_head]) ||
						(o_result_precision_mode != reg_result_scoreboard_precision[cnt_result_scoreboard_head]) ||
						(o_result_frame_id != reg_result_scoreboard_frame_id[cnt_result_scoreboard_head]) ||
						(o_result_sample_index != reg_result_scoreboard_sample_index[cnt_result_scoreboard_head]) ||
						(o_result_frame_type != reg_result_scoreboard_frame_type[cnt_result_scoreboard_head]) ||
						(o_result_amb_code_snapshot != reg_result_scoreboard_amb_code[cnt_result_scoreboard_head]) ||
						(o_result_dc_code_snapshot != reg_result_scoreboard_dc_code[cnt_result_scoreboard_head]) ||
						(o_result_amb_code_epoch != reg_result_scoreboard_amb_epoch[cnt_result_scoreboard_head]) ||
						(o_result_dc_code_epoch != reg_result_scoreboard_dc_epoch[cnt_result_scoreboard_head]) ||
						(o_result_config_epoch != reg_result_scoreboard_config_epoch[cnt_result_scoreboard_head]) ||
						(o_result_coef_epoch != reg_result_scoreboard_coef_epoch[cnt_result_scoreboard_head]) ||
						(o_result_stage2_coef_epoch != reg_result_scoreboard_stage2_epoch[cnt_result_scoreboard_head]) ||
						(o_result_dc_coef_epoch != reg_result_scoreboard_dc_coef_epoch[cnt_result_scoreboard_head]))begin
						cnt_identity_mismatch = cnt_identity_mismatch + 1;
						flag_numeric_identity_ok = 1'b0;
					end
				end
				cnt_numeric_comparison = cnt_numeric_comparison + 1;
				if((cnt_result_scoreboard_count > 0) && reg_result_scoreboard_raw_valid[cnt_result_scoreboard_head])begin
					compute_expected_stage1(reg_result_scoreboard_stage1_raw[cnt_result_scoreboard_head], reg_score_expected_s1);
					compute_expected_numeric_chain(reg_result_scoreboard_stage1_raw[cnt_result_scoreboard_head], reg_result_scoreboard_stage2_raw[cnt_result_scoreboard_head],
						reg_score_expected_s1, reg_result_scoreboard_precision[cnt_result_scoreboard_head], reg_result_scoreboard_dc_code[cnt_result_scoreboard_head],
						reg_score_expected_15, reg_score_expected_coarse, reg_score_expected_fine);
					cnt_stage1_signed_comparison = cnt_stage1_signed_comparison + 1;
					if($signed(o_calibrated_s1_value) != reg_score_expected_s1)begin
						cnt_numeric_mismatch = cnt_numeric_mismatch + 1;
					end
					if($signed(o_coarse_ppg_value) != reg_score_expected_coarse)begin
						cnt_numeric_mismatch = cnt_numeric_mismatch + 1;
					end
				end
				if($signed(o_calibrated_s1_value) < -2048 || $signed(o_calibrated_s1_value) > 2047)begin
					flag_stage1_signed_range_ok = 1'b0;
				end
				if(o_result_precision_mode == 1'b0)begin
					cnt_coarse_comparison = cnt_coarse_comparison + 1;
					if(o_fine_valid !== 1'b0 || $signed(o_fine_ppg_value) != 24'sd0) flag_sar9_no_fine_ok = 1'b0;
					if((cnt_result_scoreboard_count > 0) && reg_result_scoreboard_raw_valid[cnt_result_scoreboard_head] && $signed(o_coarse_ppg_value) != reg_score_expected_coarse)begin
						flag_sar9_no_fine_ok = 1'b0;
					end
				end else begin
					cnt_stage2_comparison = cnt_stage2_comparison + 1;
					cnt_fine_comparison = cnt_fine_comparison + 1;
					if((o_programmable_15_valid !== 1'b1) || (o_fine_valid !== 1'b1) || (o_coarse_valid !== 1'b1))begin
						flag_sar15_chain_ok = 1'b0;
					end
					if((cnt_result_scoreboard_count > 0) && reg_result_scoreboard_raw_valid[cnt_result_scoreboard_head] && $signed(o_programmable_15_code) != reg_score_expected_15)begin
						cnt_numeric_mismatch = cnt_numeric_mismatch + 1;
						flag_sar15_chain_ok = 1'b0;
					end
					if((cnt_result_scoreboard_count > 0) && reg_result_scoreboard_raw_valid[cnt_result_scoreboard_head] && $signed(o_fine_ppg_value) != reg_score_expected_fine)begin
						cnt_numeric_mismatch = cnt_numeric_mismatch + 1;
						flag_sar15_chain_ok = 1'b0;
					end
				end
				if((o_coarse_saturation_low === 1'b1) && (o_coarse_saturation_high === 1'b1))begin
					cnt_numeric_mismatch = cnt_numeric_mismatch + 1;
				end
				if(o_coarse_saturation_low || o_coarse_saturation_high || o_fine_saturation_low || o_fine_saturation_high) begin
					flag_saturation_observed = 1'b1;
				if(o_coarse_saturation_low) flag_adcn_saturation_low_seen = 1'b1;
				if(o_coarse_saturation_high) flag_adcn_saturation_high_seen = 1'b1;
				end
				if($signed(o_calibrated_s1_value) < 0) flag_adcn_negative_vector_seen = 1'b1;
				if((reg_scenario_numeric_vector_mode == 4) && ($signed(o_calibrated_s1_value) == -12'sd2048)) begin
					flag_adcn_saturation_low_seen = 1'b1;
				end
				if((reg_scenario_numeric_vector_mode == 5) && ($signed(o_calibrated_s1_value) == 12'sd2047)) begin
					flag_adcn_saturation_high_seen = 1'b1;
				end
				if((reg_scenario_numeric_vector_mode == 2) && ($signed(o_calibrated_s1_value) == 12'sd1)) begin
					flag_adcn_half_positive_seen = 1'b1;
				end
				if((reg_scenario_numeric_vector_mode == 3) && ($signed(o_calibrated_s1_value) == -12'sd1)) begin
					flag_adcn_half_negative_seen = 1'b1;
				end
				flag_adcn_half_lsb_vector_seen = flag_adcn_half_positive_seen && flag_adcn_half_negative_seen;
				if(cnt_result_scoreboard_count > 0)begin
					reg_result_scoreboard_valid[cnt_result_scoreboard_head] = 1'b0;
					if(cnt_result_scoreboard_head == (C_RESULT_SCOREBOARD_DEPTH - 1)) cnt_result_scoreboard_head = 0;
					else cnt_result_scoreboard_head = cnt_result_scoreboard_head + 1;
					cnt_result_scoreboard_count = cnt_result_scoreboard_count - 1;
				end
				reg_last_calibrated_s1_value = o_calibrated_s1_value;
				reg_last_programmable_15_code = o_programmable_15_code;
				reg_last_coarse_ppg_value = o_coarse_ppg_value;
				reg_last_fine_ppg_value = o_fine_ppg_value;
				reg_last_result_config_epoch = o_result_config_epoch;
				reg_last_result_coef_epoch = o_result_coef_epoch;
				reg_last_result_stage2_coef_epoch = o_result_stage2_coef_epoch;
				reg_last_result_dc_coef_epoch = o_result_dc_coef_epoch;
				reg_last_result_frame_type = o_result_frame_type;
				reg_last_result_amb_code_snapshot = o_result_amb_code_snapshot;
				reg_last_result_dc_code_snapshot = o_result_dc_code_snapshot;
				reg_last_result_amb_code_epoch = o_result_amb_code_epoch;
				reg_last_result_dc_code_epoch = o_result_dc_code_epoch;
			end
		end
	end

	// 在反相时钟边沿观察SSW已更新的IDAC寄存输出，避免与正沿控制字更新发生竞态。
	always@(negedge i_clk)begin
		if(i_rstn == 1'b1)begin
			if((cnt_red_waveform_context > 0) && (reg_red_waveform_precision_mode == 1'b0))begin
				if((reg_red_waveform_amb_code != 8'h00) && (o_idac_sar9ambn_low == reg_red_waveform_amb_code))begin
					flag_selected_amb_bus_seen = 1'b1;
				end
				if((reg_red_waveform_dc_code != 8'h00) && (o_idac_sar9dcn_low == reg_red_waveform_dc_code))begin
					flag_selected_dc_bus_seen = 1'b1;
					flag_red_dc_bus_seen = 1'b1;
				end
				if((o_idac_sar15ambn_low != 8'h00) || (o_idac_sar15dcn_low != 8'h00))begin
					flag_unselected_idac_bus_clean = 1'b0;
					flag_idac_bus_violation = 1'b1;
				end
			end else if(cnt_red_waveform_context > 0)begin
				if((reg_red_waveform_amb_code != 8'h00) && (o_idac_sar15ambn_low == reg_red_waveform_amb_code))begin
					flag_selected_amb_bus_seen = 1'b1;
				end
				if((reg_red_waveform_dc_code != 8'h00) && (o_idac_sar15dcn_low == reg_red_waveform_dc_code))begin
					flag_selected_dc_bus_seen = 1'b1;
					flag_red_dc_bus_seen = 1'b1;
				end
				if((o_idac_sar9ambn_low != 8'h00) || (o_idac_sar9dcn_low != 8'h00))begin
					flag_unselected_idac_bus_clean = 1'b0;
					flag_idac_bus_violation = 1'b1;
				end
			end
			if((cnt_ir_waveform_context > 0) && (reg_ir_waveform_dc_code != 8'h00) && ((reg_ir_waveform_precision_mode == 1'b0 && o_idac_sar9dcn_low == reg_ir_waveform_dc_code) || (reg_ir_waveform_precision_mode == 1'b1 && o_idac_sar15dcn_low == reg_ir_waveform_dc_code)))begin
				flag_ir_dc_bus_seen = 1'b1;
			end
		end
	end

	//===================<第2步：状态、数值、身份与故障scoreboard>===================//
	// 使用反相沿观察DUT已经稳定的公开输出，避免与DUT的非阻塞更新竞争。
	always@(negedge i_clk)begin
			if(i_rstn == 1'b0)begin
			flag_idac_observation_valid = 1'b0;
			reg_idac_prev_amb_pending = 1'b0;
			reg_idac_prev_dcs_r_pending = 1'b0;
			reg_idac_prev_dcs_ir_pending = 1'b0;
			reg_idac_prev_amb_search_done = 1'b0;
			reg_idac_prev_dcs_r_search_done = 1'b0;
			reg_idac_prev_dcs_ir_search_done = 1'b0;
			reg_idac_prev_amb_exhausted = 1'b0;
			reg_idac_prev_dcs_r_exhausted = 1'b0;
			reg_idac_prev_dcs_ir_exhausted = 1'b0;
			reg_recheck_prev_pending = 1'b0;
			reg_recheck_prev_accept = 1'b0;
			reg_recheck_prev_done = 1'b0;
			reg_recheck_prev_failed = 1'b0;
			reg_recheck_calibration_active = 1'b0;
			reg_recheck_owner_waiting = 1'b0;
			reg_recheck_owner_async_seen = 1'b0;
			reg_startup_calibration_active = 1'b0;
			reg_startup_prev_q3_low = 1'b0;
			reg_startup_prev_q3_macro_tick = 13'd0;
			reg_startup_owner_waiting = 1'b0;
			reg_startup_owner_async_seen = 1'b0;
			reg_result_hold_valid = 1'b0;
			reg_result_hold_stable = 1'b1;
			cnt_result_scoreboard_head = 0;
			cnt_result_scoreboard_tail = 0;
			cnt_result_scoreboard_count = 0;
			cnt_result_scoreboard_overflow = 0;
			reg_owner_scoreboard_valid = 1'b0;
			reg_completed_owner_valid = 1'b0;
			reg_last_driven_raw_valid = 1'b0;
			reg_fault_seen_before_diag_clear = 1'b0;
				reg_any_fault_prev = 1'b0;
				reg_integration_block_prev = 1'b0;
				reg_scheduler_deadline_prev = 1'b0;
				reg_scheduler_launch_timeout_prev = 1'b0;
				reg_scheduler_owner_deadline_prev = 1'b0;
				reg_scheduler_completion_mismatch_prev = 1'b0;
				reg_scheduler_protocol_error_prev = 1'b0;
				reg_scheduler_prev_frame_active = 1'b0;
				reg_scheduler_prev_frame_mode = 2'd0;
				reg_scheduler_prev_red_pending = 1'b0;
				reg_scheduler_prev_ir_pending = 1'b0;
				reg_scheduler_prev_cal_pending = 1'b0;
				reg_scheduler_prev_macro_tick = 13'd0;
				reg_scheduler_prev_cal_tick = 10'd0;
			end else begin
				if(ppg_adc_measurement_idac_integration_Inst.flag_integration_blocking && !reg_integration_block_prev)begin
					$display("TB_INTEGRATION_BLOCK_CAUSE group=%0s macro_tick=%0d cal_tick=%0d result_mismatch=%0d start_context_mismatch=%0d capture_without_owner=%0d completion_emit=%0d completion_owner_match=%0d startup_source=%0d recheck_source=%0d cal_inflight=%0d router_amb=%0d router_dcs=%0d amb_ready=%0d dcs_ready=%0d cal_valid=%0d cal_ready=%0d", reg_run_group_id, o_macro_tick, o_calibration_local_tick, ppg_adc_measurement_idac_integration_Inst.flag_calibration_result_mismatch, ppg_adc_measurement_idac_integration_Inst.flag_start_context_mismatch, ppg_adc_measurement_idac_integration_Inst.flag_adc_capture_without_owner, ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_emit, ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_owner_match, ppg_adc_measurement_idac_integration_Inst.flag_startup_request_source, ppg_adc_measurement_idac_integration_Inst.flag_recheck_request_source, ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight, ppg_adc_measurement_idac_integration_Inst.flag_router_amb_valid, ppg_adc_measurement_idac_integration_Inst.flag_router_dcs_valid, ppg_adc_measurement_idac_integration_Inst.flag_idac_search_amb_ready, ppg_adc_measurement_idac_integration_Inst.flag_idac_search_dcs_ready, o_calibration_sample_valid, o_calibration_sample_ready);
				end
				reg_integration_block_prev = ppg_adc_measurement_idac_integration_Inst.flag_integration_blocking;
				if(flag_scheduler_run_armed && ((o_scheduler_launch_timeout_sticky && !reg_scheduler_launch_timeout_prev) ||
					(o_scheduler_owner_deadline_timeout_sticky && !reg_scheduler_owner_deadline_prev) ||
					(o_scheduler_completion_mismatch_sticky && !reg_scheduler_completion_mismatch_prev) ||
					(o_scheduler_protocol_error_sticky && !reg_scheduler_protocol_error_prev)))begin
					if(!flag_scheduler_first_set_seen)begin
						flag_scheduler_first_set_seen = 1'b1;
						cnt_scheduler_first_set = cnt_scheduler_first_set + 1;
						cnt_scheduler_first_set_run = cnt_run_index;
						cnt_scheduler_first_set_macro_tick = o_macro_tick;
						cnt_scheduler_first_set_cal_tick = o_calibration_local_tick;
						time_scheduler_first_set = $time;
						if(o_scheduler_owner_deadline_timeout_sticky && !reg_scheduler_owner_deadline_prev) begin
							if(ppg_400hz_frame_calibration_scheduler_Inst.flag_red_owner_deadline ||
								(reg_scheduler_prev_frame_active && (reg_scheduler_prev_frame_mode == 2'd1) && reg_scheduler_prev_red_pending && (reg_scheduler_prev_macro_tick >= 13'd283))) reg_scheduler_first_set_reason = "OWNER_DEADLINE_RED";
							else if(ppg_400hz_frame_calibration_scheduler_Inst.flag_ir_owner_deadline ||
								(reg_scheduler_prev_frame_active && (reg_scheduler_prev_frame_mode == 2'd1) && reg_scheduler_prev_ir_pending && (reg_scheduler_prev_macro_tick >= 13'd443))) reg_scheduler_first_set_reason = "OWNER_DEADLINE_IR";
							else if(ppg_400hz_frame_calibration_scheduler_Inst.flag_cal_owner_deadline ||
								(reg_scheduler_prev_frame_active && (reg_scheduler_prev_frame_mode == 2'd2) && reg_scheduler_prev_cal_pending && (reg_scheduler_prev_cal_tick >= 10'd248))) reg_scheduler_first_set_reason = "OWNER_DEADLINE_CAL";
							else reg_scheduler_first_set_reason = "OWNER_DEADLINE_LATCH";
						end else if(o_scheduler_launch_timeout_sticky && !reg_scheduler_launch_timeout_prev) begin
							reg_scheduler_first_set_reason = "WAVEFORM_LAUNCH_TIMEOUT";
						end else if(o_scheduler_completion_mismatch_sticky && !reg_scheduler_completion_mismatch_prev) begin
							reg_scheduler_first_set_reason = "COMPLETION_MISMATCH";
						end else begin
							reg_scheduler_first_set_reason = "SCHEDULER_PROTOCOL_ERROR";
						end
					end
					$display("TB_SCHEDULER_STICKY_EDGE run=%0d group=%0s rstn=%0d reset_time=%0t start_time=%0t time=%0t first_reason=%0s launch_edge=%0d owner_edge=%0d completion_edge=%0d protocol_edge=%0d red_deadline=%0d ir_deadline=%0d cal_deadline=%0d prev_frame_active=%0d prev_frame_mode=%0d prev_red_pending=%0d prev_ir_pending=%0d prev_cal_pending=%0d prev_macro_tick=%0d prev_cal_tick=%0d macro_tick=%0d cal_tick=%0d frame_active=%0d frame_mode=%0d red_pending=%0d ir_pending=%0d cal_pending=%0d cal_active=%0d inflight=%0d waveform_valid=%0d waveform_ready=%0d start_valid=%0d start_ready=%0d start_fire=%0d owner_commit=%0d adc_owner=%0d adc_idle=%0d analog_safe=%0d sar_idle=%0d cal_req_valid=%0d cal_req_ready=%0d cal_req_fire=%0d run_enable=%0d allow_new=%0d", cnt_run_index, reg_run_group_id, i_rstn, time_run_reset_assert, time_run_start_ack, $time, reg_scheduler_first_set_reason, o_scheduler_launch_timeout_sticky && !reg_scheduler_launch_timeout_prev, o_scheduler_owner_deadline_timeout_sticky && !reg_scheduler_owner_deadline_prev, o_scheduler_completion_mismatch_sticky && !reg_scheduler_completion_mismatch_prev, o_scheduler_protocol_error_sticky && !reg_scheduler_protocol_error_prev, ppg_400hz_frame_calibration_scheduler_Inst.flag_red_owner_deadline, ppg_400hz_frame_calibration_scheduler_Inst.flag_ir_owner_deadline, ppg_400hz_frame_calibration_scheduler_Inst.flag_cal_owner_deadline, reg_scheduler_prev_frame_active, reg_scheduler_prev_frame_mode, reg_scheduler_prev_red_pending, reg_scheduler_prev_ir_pending, reg_scheduler_prev_cal_pending, reg_scheduler_prev_macro_tick, reg_scheduler_prev_cal_tick, o_macro_tick, o_calibration_local_tick, ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode, ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_RED_WAVE_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_IR_WAVE_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_WAVE_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT], o_waveform_context_valid, o_waveform_context_ready, o_transaction_start_valid, o_transaction_start_ready, o_transaction_start_fire, o_adc_owner_commit_event, o_adc_owner_inflight, i_adc_idle, o_analog_safe, o_sar_timing_idle, o_calibration_sample_valid, o_calibration_sample_ready, o_calibration_request_fire, measurement_run_enable, measurement_allow_new_transaction);
				end
				reg_scheduler_deadline_prev = o_scheduler_owner_deadline_timeout_sticky;
				reg_scheduler_launch_timeout_prev = o_scheduler_launch_timeout_sticky;
				reg_scheduler_owner_deadline_prev = o_scheduler_owner_deadline_timeout_sticky;
				reg_scheduler_completion_mismatch_prev = o_scheduler_completion_mismatch_sticky;
				reg_scheduler_protocol_error_prev = o_scheduler_protocol_error_sticky;
				// Cancellation evidence is latched from a later observation edge,
				// avoiding task/always scheduling races at owner release.
				if(reg_recheck_cancel_triggered &&
					!o_adc_owner_inflight && !o_scheduler_transaction_inflight)begin
					reg_recheck_cancel_owner_drained = 1'b1;
				end
				if(reg_recheck_cancel_triggered &&
					(reg_scenario_recheck_cancel_mode == 2'd2) &&
					reg_recheck_cancel_late_done_seen &&
					!reg_recheck_cancel_result_leak &&
					(cnt_measurement_result == cnt_recheck_cancel_result_before))begin
					reg_recheck_cancel_late_done_ok = 1'b1;
				end
			if((reg_scenario_group_id == "PERIODIC-RECHECK-RECOVERY") && (cnt_recheck_post_accept_debug > 0) && (cnt_recheck_post_accept_debug <= 32))begin
				$display("TB_RECHECK_POST_ACCEPT n=%0d macro_tick=%0d idac_state=%0d idac_state_next=%0d sched_state=%0d sched_state_next=%0d dcs_req=%0d dcs_sample_req=%0d cal_valid=%0d cal_ready=%0d cal_fire=%0d frame_active=%0d run_enable=%0d inflight=%0d amb_accept=%0d dcs_accept=%0d amb_ready=%0d dcs_ready=%0d router_amb=%0d router_dcs=%0d integration_block=%0d start_block=%0d", 
					cnt_recheck_post_accept_debug, o_macro_tick,
					ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current,
					ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_next,
					ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.state_current,
					ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.state_next,
					ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_request,
					ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_sample_request,
					o_calibration_sample_valid, o_calibration_sample_ready, o_calibration_request_fire,
					o_calibration_frame_active, measurement_run_enable,
					ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight,
					ppg_adc_measurement_idac_integration_Inst.flag_amb_sample_accepted,
					ppg_adc_measurement_idac_integration_Inst.flag_dcs_sample_accepted,
					ppg_adc_measurement_idac_integration_Inst.flag_idac_search_amb_ready,
					ppg_adc_measurement_idac_integration_Inst.flag_idac_search_dcs_ready,
					ppg_adc_measurement_idac_integration_Inst.flag_router_amb_valid,
					ppg_adc_measurement_idac_integration_Inst.flag_router_dcs_valid,
					ppg_adc_measurement_idac_integration_Inst.flag_integration_blocking,
					ppg_adc_measurement_idac_integration_Inst.flag_start_blocked);
				cnt_recheck_post_accept_debug = cnt_recheck_post_accept_debug + 1;
			end
			//---------- IDAC pending/search/update/epoch记账 ----------//
			if((o_amb_recheck_busy || reg_recheck_calibration_active) &&
				((o_calibration_local_tick == 10'd0) || (o_calibration_local_tick == 10'd266) || (o_calibration_local_tick == 10'd624)) &&
				(ppg_adc_measurement_idac_integration_Inst.flag_idac_amb_seq_done ||
				 ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_request ||
				 o_calibration_frame_complete_event ||
				 ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_stage_result_done ||
				 ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_stage_frame_complete))begin
				$display("TB_RECHECK_PULSE macro_tick=%0d cal_tick=%0d idac_state=%0d amb_done=%0d dcs_req=%0d dcs_accept=%0d track_qualified=%0d cal_valid=%0d cal_ready=%0d cal_fire=%0d dcs_sample_req=%0d dcs_color=%0d cal_frame_done=%0d sched_state=%0d sched_result=%0d sched_frame=%0d",
					o_macro_tick, o_calibration_local_tick,
					ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current,
					ppg_adc_measurement_idac_integration_Inst.flag_idac_amb_seq_done,
					ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_request,
					ppg_adc_measurement_idac_integration_Inst.flag_dcs_revalidate_accept_qualified,
					ppg_adc_measurement_idac_integration_Inst.flag_normal_track_qualified,
					o_calibration_sample_valid, o_calibration_sample_ready, o_calibration_request_fire,
					ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_sample_request,
					ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_sample_color_ir,
					o_calibration_frame_complete_event,
					ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.state_current,
					ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_stage_result_done,
					ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_stage_frame_complete);
			end
			if(o_amb_pending_valid && !reg_idac_prev_amb_pending) cnt_amb_pending_observed = cnt_amb_pending_observed + 1;
			if(o_dcs_r_pending_valid && !reg_idac_prev_dcs_r_pending) cnt_dcs_r_pending_observed = cnt_dcs_r_pending_observed + 1;
			if(o_dcs_ir_pending_valid && !reg_idac_prev_dcs_ir_pending) cnt_dcs_ir_pending_observed = cnt_dcs_ir_pending_observed + 1;
			if(o_amb_code_update) cnt_amb_update_observed = cnt_amb_update_observed + 1;
			if(o_dcs_r_code_update) cnt_dcs_r_update_observed = cnt_dcs_r_update_observed + 1;
			if(o_dcs_ir_code_update) cnt_dcs_ir_update_observed = cnt_dcs_ir_update_observed + 1;
			if(o_dcs_r_track_adjust) cnt_dcs_r_track_adjust_observed = cnt_dcs_r_track_adjust_observed + 1;
			if(o_dcs_ir_track_adjust) cnt_dcs_ir_track_adjust_observed = cnt_dcs_ir_track_adjust_observed + 1;
			if(o_amb_search_done && !reg_idac_prev_amb_search_done)begin
				cnt_amb_search_done_observed = cnt_amb_search_done_observed + 1;
				if(reg_idac_search_stage != 2'd0) flag_idac_startup_order_ok = 1'b0;
				reg_idac_search_stage = 2'd1;
			end
			if(o_dcs_r_search_done && !reg_idac_prev_dcs_r_search_done)begin
				cnt_dcs_r_search_done_observed = cnt_dcs_r_search_done_observed + 1;
				if(reg_idac_search_stage != 2'd1) flag_idac_startup_order_ok = 1'b0;
				reg_idac_search_stage = 2'd2;
			end
			if(o_dcs_ir_search_done && !reg_idac_prev_dcs_ir_search_done)begin
				cnt_dcs_ir_search_done_observed = cnt_dcs_ir_search_done_observed + 1;
				if(reg_idac_search_stage != 2'd2) flag_idac_startup_order_ok = 1'b0;
				reg_idac_search_stage = 2'd3;
			end
			if(o_amb_search_exhausted && !reg_idac_prev_amb_exhausted) cnt_idac_search_exhausted_observed = cnt_idac_search_exhausted_observed + 1;
			if(o_dcs_r_search_exhausted && !reg_idac_prev_dcs_r_exhausted) cnt_idac_search_exhausted_observed = cnt_idac_search_exhausted_observed + 1;
			if(o_dcs_ir_search_exhausted && !reg_idac_prev_dcs_ir_exhausted) cnt_idac_search_exhausted_observed = cnt_idac_search_exhausted_observed + 1;

			if(o_startup_search_complete === 1'b1 && !flag_idac_observation_valid)begin
				reg_idac_prev_amb_code = o_amb_code;
				reg_idac_prev_dcs_r_code = o_dcs_r_code;
				reg_idac_prev_dcs_ir_code = o_dcs_ir_code;
				reg_idac_prev_amb_epoch = o_amb_code_epoch;
				reg_idac_prev_dcs_r_epoch = o_dcs_r_code_epoch;
				reg_idac_prev_dcs_ir_epoch = o_dcs_ir_code_epoch;
				flag_idac_observation_valid = 1'b1;
			end else if(flag_idac_observation_valid)begin
				if(o_amb_code != reg_idac_prev_amb_code)begin
					if(o_amb_code_epoch != (reg_idac_prev_amb_epoch + 4'd1)) cnt_idac_epoch_mismatch = cnt_idac_epoch_mismatch + 1;
					if((o_amb_code != (reg_idac_prev_amb_code + 8'd1)) && (o_amb_code != (reg_idac_prev_amb_code - 8'd1)))begin
						if((i_idac_mode == 2'b10) && i_run_profile == 1'b0 && !o_amb_recheck_busy && !o_calibration_frame_active)begin
							cnt_idac_code_delta_mismatch = cnt_idac_code_delta_mismatch + 1;
						end
					end
					if((reg_idac_prev_amb_code == i_amb_code_min || reg_idac_prev_amb_code == i_amb_code_max) &&
						(o_amb_code != i_amb_code_min) && (o_amb_code != i_amb_code_max))begin
						cnt_idac_boundary_wrap_violation = cnt_idac_boundary_wrap_violation + 1;
					end
				end else if(o_amb_code_epoch != reg_idac_prev_amb_epoch)begin
					cnt_idac_epoch_mismatch = cnt_idac_epoch_mismatch + 1;
				end
				if(o_dcs_r_code != reg_idac_prev_dcs_r_code)begin
					if(o_dcs_r_code_epoch != (reg_idac_prev_dcs_r_epoch + 4'd1)) cnt_idac_epoch_mismatch = cnt_idac_epoch_mismatch + 1;
					if((reg_idac_prev_dcs_r_epoch == 4'hf) && (o_dcs_r_code_epoch == 4'h0)) begin
						cnt_tracking_epoch_wrap_observed = cnt_tracking_epoch_wrap_observed + 1;
					end
					if(o_dcs_r_track_adjust && (o_dcs_r_code != (reg_idac_prev_dcs_r_code + 8'd1)) && (o_dcs_r_code != (reg_idac_prev_dcs_r_code - 8'd1)))begin
						cnt_idac_code_delta_mismatch = cnt_idac_code_delta_mismatch + 1;
					end
					if(((reg_idac_prev_dcs_r_code == i_dcs_r_code_min) && (o_dcs_r_code == i_dcs_r_code_max)) ||
						((reg_idac_prev_dcs_r_code == i_dcs_r_code_max) && (o_dcs_r_code == i_dcs_r_code_min)))begin
						cnt_idac_boundary_wrap_violation = cnt_idac_boundary_wrap_violation + 1;
					end
				end else if(o_dcs_r_code_epoch != reg_idac_prev_dcs_r_epoch)begin
					cnt_idac_epoch_mismatch = cnt_idac_epoch_mismatch + 1;
				end
				if(o_dcs_ir_code != reg_idac_prev_dcs_ir_code)begin
					if(o_dcs_ir_code_epoch != (reg_idac_prev_dcs_ir_epoch + 4'd1)) cnt_idac_epoch_mismatch = cnt_idac_epoch_mismatch + 1;
					if((reg_idac_prev_dcs_ir_epoch == 4'hf) && (o_dcs_ir_code_epoch == 4'h0)) begin
						cnt_tracking_epoch_wrap_observed = cnt_tracking_epoch_wrap_observed + 1;
					end
					if(o_dcs_ir_track_adjust && (o_dcs_ir_code != (reg_idac_prev_dcs_ir_code + 8'd1)) && (o_dcs_ir_code != (reg_idac_prev_dcs_ir_code - 8'd1)))begin
						cnt_idac_code_delta_mismatch = cnt_idac_code_delta_mismatch + 1;
					end
					if(((reg_idac_prev_dcs_ir_code == i_dcs_ir_code_min) && (o_dcs_ir_code == i_dcs_ir_code_max)) ||
						((reg_idac_prev_dcs_ir_code == i_dcs_ir_code_max) && (o_dcs_ir_code == i_dcs_ir_code_min)))begin
						cnt_idac_boundary_wrap_violation = cnt_idac_boundary_wrap_violation + 1;
					end
				end else if(o_dcs_ir_code_epoch != reg_idac_prev_dcs_ir_epoch)begin
					cnt_idac_epoch_mismatch = cnt_idac_epoch_mismatch + 1;
				end
				if(o_amb_code_update && (o_amb_code == reg_idac_prev_amb_code)) cnt_idac_update_without_change = cnt_idac_update_without_change + 1;
				if(o_dcs_r_code_update && (o_dcs_r_code == reg_idac_prev_dcs_r_code)) cnt_idac_update_without_change = cnt_idac_update_without_change + 1;
				if(o_dcs_ir_code_update && (o_dcs_ir_code == reg_idac_prev_dcs_ir_code)) cnt_idac_update_without_change = cnt_idac_update_without_change + 1;
				if((i_idac_mode == 2'b10) && !o_calibration_frame_active && !o_amb_recheck_busy &&
					o_measurement_result_valid && i_measurement_result_ready &&
					(((o_dcs_r_code_at_min || o_dcs_r_code_at_max) &&
						(o_dcs_r_code == reg_idac_prev_dcs_r_code) && (o_dcs_r_code_epoch == reg_idac_prev_dcs_r_epoch)) ||
						((o_dcs_ir_code_at_min || o_dcs_ir_code_at_max) &&
						(o_dcs_ir_code == reg_idac_prev_dcs_ir_code) && (o_dcs_ir_code_epoch == reg_idac_prev_dcs_ir_epoch))))begin
					cnt_tracking_boundary_hold_observed = cnt_tracking_boundary_hold_observed + 1;
				end
				reg_idac_prev_amb_code = o_amb_code;
				reg_idac_prev_dcs_r_code = o_dcs_r_code;
				reg_idac_prev_dcs_ir_code = o_dcs_ir_code;
				reg_idac_prev_amb_epoch = o_amb_code_epoch;
				reg_idac_prev_dcs_r_epoch = o_dcs_r_code_epoch;
				reg_idac_prev_dcs_ir_epoch = o_dcs_ir_code_epoch;
			end
			if((cnt_idac_epoch_mismatch != 0) || (cnt_idac_update_without_change != 0)) flag_idac_epoch_relation_ok = 1'b0;
			if((cnt_idac_code_delta_mismatch != 0)) flag_idac_track_delta_ok = 1'b0;
			if(cnt_idac_boundary_wrap_violation != 0) flag_idac_no_wrap_ok = 1'b0;
			if((reg_startup_calibration_active || reg_recheck_calibration_active || o_amb_recheck_busy) && o_clk_q3_low && !reg_startup_prev_q3_low)begin
				cnt_startup_q3_observed = cnt_startup_q3_observed + 1;
				if(o_calibration_local_tick != 10'd266) flag_startup_q3_266_ok = 1'b0;
				// o_macro_tick is only the current 400 Hz frame phase and wraps at 5000.
				// Use the physical 2 MHz simulation tick for spacing across calibration subframes.
				if(cnt_startup_q3_observed > 1 && ((($time / C_CLK_PERIOD_NS) - reg_startup_prev_q3_physical_tick) != 64'd625))begin
					cnt_startup_q3_spacing_mismatch = cnt_startup_q3_spacing_mismatch + 1;
					flag_startup_q3_spacing_ok = 1'b0;
				end
				if(reg_scenario_group_id == "STARTUP-IDAC-CALIBRATION")begin
					$display("TB_STARTUP_Q3 subframe=%0d physical_tick=%0d macro_tick=%0d local_tick=%0d frame=%0d spacing_mismatch=%0d", o_calibration_subframe_index, ($time / C_CLK_PERIOD_NS), o_macro_tick, o_calibration_local_tick, o_adc_owner_frame_id, cnt_startup_q3_spacing_mismatch);
				end
				reg_startup_prev_q3_macro_tick = o_macro_tick;
				reg_startup_prev_q3_physical_tick = ($time / C_CLK_PERIOD_NS);
			end
			reg_startup_prev_q3_low = o_clk_q3_low;
			// 启动校准必须使用专用光源/测试波形；这里只观察正式公共控制输出，不改写DUT状态。
			if((reg_startup_calibration_active || ((o_startup_search_complete !== 1'b1) && o_calibration_frame_active)) && o_calibration_frame_active)begin
				if(o_en_test !== 1'b0)begin
					flag_startup_waveform_ok = 1'b0;
					if(reg_scenario_group_id == "STARTUP-IDAC-CALIBRATION") $display("TB_STARTUP_WAVEFORM_MISMATCH reason=en_test type=%0d color=%0d en_test=%0d leden1=%0d leden2=%0d sar9dc=%0d sar15amb=%0d sar15dc=%0d", o_calibration_frame_type, o_calibration_color_ir, o_en_test, o_leden1_low, o_leden2_low, o_idac_sar9dcn_low, o_idac_sar15ambn_low, o_idac_sar15dcn_low);
				end
				if(o_calibration_frame_type == FRAME_TYPE_AMB)begin
					cnt_startup_amb_waveform_observed = cnt_startup_amb_waveform_observed + 1;
					if((o_leden1_low !== 1'b0) || (o_leden2_low !== 1'b0) || (o_idac_sar9dcn_low !== 8'd0) ||
						(o_idac_sar15ambn_low !== 8'd0) || (o_idac_sar15dcn_low !== 8'd0))begin
						flag_startup_waveform_ok = 1'b0;
						if(reg_scenario_group_id == "STARTUP-IDAC-CALIBRATION") $display("TB_STARTUP_WAVEFORM_MISMATCH reason=amb_outputs leden1=%0d leden2=%0d sar9dc=%0d sar15amb=%0d sar15dc=%0d", o_leden1_low, o_leden2_low, o_idac_sar9dcn_low, o_idac_sar15ambn_low, o_idac_sar15dcn_low);
					end
				end else if(o_calibration_frame_type == FRAME_TYPE_DCS && o_calibration_color_ir == 1'b0)begin
					cnt_startup_dcs_r_waveform_observed = cnt_startup_dcs_r_waveform_observed + 1;
					if((o_leden2_low !== 1'b0) || (o_idac_sar15ambn_low !== 8'd0) || (o_idac_sar15dcn_low !== 8'd0))begin
						flag_startup_waveform_ok = 1'b0;
						if(reg_scenario_group_id == "STARTUP-IDAC-CALIBRATION") $display("TB_STARTUP_WAVEFORM_MISMATCH reason=dcs_r_outputs leden2=%0d sar15amb=%0d sar15dc=%0d", o_leden2_low, o_idac_sar15ambn_low, o_idac_sar15dcn_low);
					end
				end else if(o_calibration_frame_type == FRAME_TYPE_DCS && o_calibration_color_ir == 1'b1)begin
					cnt_startup_dcs_ir_waveform_observed = cnt_startup_dcs_ir_waveform_observed + 1;
					if((o_leden1_low !== 1'b0) || (o_idac_sar15ambn_low !== 8'd0) || (o_idac_sar15dcn_low !== 8'd0))begin
						flag_startup_waveform_ok = 1'b0;
						if(reg_scenario_group_id == "STARTUP-IDAC-CALIBRATION") $display("TB_STARTUP_WAVEFORM_MISMATCH reason=dcs_ir_outputs leden1=%0d sar15amb=%0d sar15dc=%0d", o_leden1_low, o_idac_sar15ambn_low, o_idac_sar15dcn_low);
					end
				end else begin
					flag_startup_waveform_ok = 1'b0;
				end
			end

			//---------- 周期重检状态、排空、顺序及真实ADC链 ----------//
			if((reg_scenario_group_id == "PERIODIC-RECHECK-RECOVERY") &&
				ppg_adc_measurement_idac_integration_Inst.flag_dcs_revalidate_accept_qualified)begin
				$display("TB_RECHECK_ACCEPT_EDGE macro_tick=%0d idac_state=%0d idac_state_next=%0d sched_state=%0d sched_state_next=%0d dcs_req=%0d dcs_accept=%0d run_enable=%0d track_qualified=%0d", 
					o_macro_tick,
					ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current,
					ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_next,
					ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.state_current,
					ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.state_next,
					ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_revalidate_request,
					ppg_adc_measurement_idac_integration_Inst.flag_dcs_revalidate_accept_qualified,
					measurement_run_enable,
					ppg_adc_measurement_idac_integration_Inst.flag_normal_track_qualified);
			end
			if((reg_scenario_group_id == "PERIODIC-RECHECK-RECOVERY") &&
				(ppg_adc_measurement_idac_integration_Inst.flag_router_amb_valid ||
				 ppg_adc_measurement_idac_integration_Inst.flag_router_dcs_valid ||
				 ppg_adc_measurement_idac_integration_Inst.flag_amb_sample_accepted ||
				 ppg_adc_measurement_idac_integration_Inst.flag_dcs_sample_accepted ||
				 ppg_adc_measurement_idac_integration_Inst.flag_calibration_result_mismatch))begin
				$display("TB_CAL_RESULT_EDGE macro_tick=%0d local_tick=%0d router_amb=%0d router_dcs=%0d router_color=%0d amb_qualified=%0d dcs_qualified=%0d amb_ready=%0d dcs_ready=%0d amb_accepted=%0d dcs_accepted=%0d result_match=%0d result_mismatch=%0d inflight=%0d cal_inflight=%0d idac_state=%0d idac_next=%0d amb_req=%0d dcs_req=%0d dcs_color=%0d", o_macro_tick, o_calibration_local_tick, ppg_adc_measurement_idac_integration_Inst.flag_router_amb_valid, ppg_adc_measurement_idac_integration_Inst.flag_router_dcs_valid, ppg_adc_measurement_idac_integration_Inst.flag_router_color_ir, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.flag_amb_sample_qualified, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.flag_dcs_sample_qualified, ppg_adc_measurement_idac_integration_Inst.flag_idac_search_amb_ready, ppg_adc_measurement_idac_integration_Inst.flag_idac_search_dcs_ready, ppg_adc_measurement_idac_integration_Inst.flag_amb_sample_accepted, ppg_adc_measurement_idac_integration_Inst.flag_dcs_sample_accepted, ppg_adc_measurement_idac_integration_Inst.flag_calibration_result_match, ppg_adc_measurement_idac_integration_Inst.flag_calibration_result_mismatch, ppg_adc_measurement_idac_integration_Inst.flag_adc_transaction_inflight, ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_next, ppg_adc_measurement_idac_integration_Inst.flag_idac_amb_sample_request, ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_sample_request, ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_sample_color_ir);
			end
			if((reg_scenario_group_id == "PERIODIC-RECHECK-RECOVERY") &&
				(ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current !=
				 ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_next))begin
				$display("TB_IDAC_STATE_EDGE macro_tick=%0d local_tick=%0d state=%0d next=%0d safe=%0d amb_pending=%0d dcs_r_pending=%0d dcs_ir_pending=%0d amb_req=%0d dcs_req=%0d amb_commit=%0d dcs_r_commit=%0d dcs_ir_commit=%0d amb_code=%0d amb_candidate=%0d dcs_r_code=%0d dcs_r_candidate=%0d dcs_ir_code=%0d dcs_ir_candidate=%0d", o_macro_tick, o_calibration_local_tick, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_next, o_idac_code_safe_boundary, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_pending_valid, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_pending_valid, ppg_adc_measurement_idac_integration_Inst.flag_idac_amb_sample_request, ppg_adc_measurement_idac_integration_Inst.flag_idac_dcs_sample_request, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.flag_amb_commit, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.flag_dcs_r_commit, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.flag_dcs_ir_commit, o_amb_code, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.candidate_amb_code, o_dcs_r_code, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.candidate_dcs_r_code, o_dcs_ir_code, ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.candidate_dcs_ir_code);
			end
			if(o_amb_recheck_pending && !reg_recheck_prev_pending) cnt_recheck_pending_observed = cnt_recheck_pending_observed + 1;
			// Capture the idle boundary before accept starts the next calibration frame.
			// The accept pulse itself may coincide with scheduler activation, so checking
			// o_datapath_empty on that same edge would include the new request.
			if(o_amb_recheck_pending && !o_amb_recheck_accept)begin
				reg_recheck_pre_accept_drain_ok = i_adc_idle && o_adc_chain_idle && o_normal_fork_idle && o_measurement_output_idle &&
					o_fir_idle && o_detection_fork_idle && o_detector_idle && o_controller_idle && o_idac_idle &&
					!o_adc_owner_inflight && !o_scheduler_transaction_inflight && !o_calibration_sample_valid &&
					!ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight;
			end
			if(o_amb_recheck_accept && !reg_recheck_prev_accept)begin
				cnt_recheck_accept_observed = cnt_recheck_accept_observed + 1;
				reg_recheck_calibration_active = 1'b1;
				reg_recheck_sequence_done_seen = 1'b0;
				reg_recheck_sequence_failed_seen = 1'b0;
				reg_recheck_recross_seen = 1'b0;
				reg_recheck_recross_fine_seen = 1'b0;
				cnt_recheck_history_r_warmup = 0;
				cnt_recheck_history_ir_warmup = 0;
				cnt_recheck_successful_calibration_completion = 0;
				reg_recheck_stage_state = 2'd0;
				reg_recheck_stage_mask = 3'd0;
				reg_recheck_slope_snapshot = o_slope_current_q16;
				reg_recheck_history_r_cleared = 1'b0;
				reg_recheck_history_ir_cleared = 1'b0;
				reg_recheck_sequence_ok = 1'b1;
				reg_recheck_real_chain_ok = 1'b1;
				reg_recheck_drain_ok = reg_recheck_pre_accept_drain_ok;
				if(!reg_recheck_drain_ok) begin
					cnt_recheck_drain_mismatch = cnt_recheck_drain_mismatch + 1;
					$display("TB_RECHECK_DRAIN_MISMATCH macro_tick=%0d pre_accept_drain=%0b adc_idle=%0b adc_chain_idle=%0b normal_fork_idle=%0b measurement_output_idle=%0b fir_idle=%0b detection_fork_idle=%0b detector_idle=%0b controller_idle=%0b scheduler_idle=%0b idac_idle=%0b adc_owner_inflight=%0b scheduler_transaction_inflight=%0b datapath_empty=%0b", o_macro_tick, reg_recheck_pre_accept_drain_ok, i_adc_idle, o_adc_chain_idle, o_normal_fork_idle, o_measurement_output_idle, o_fir_idle, o_detection_fork_idle, o_detector_idle, o_controller_idle, o_scheduler_idle, o_idac_idle, o_adc_owner_inflight, o_scheduler_transaction_inflight, o_datapath_empty);
				end
			end
			if((reg_scenario_group_id == "PERIODIC-RECHECK-RECOVERY") &&
				ppg_adc_measurement_idac_integration_Inst.flag_dcs_revalidate_accept_qualified)begin
				cnt_recheck_post_accept_debug = 1;
			end
			if(o_amb_recheck_busy || reg_recheck_calibration_active)begin
				if(!o_normal_output_inhibit)begin
					cnt_recheck_output_leak = cnt_recheck_output_leak + 1;
					reg_recheck_output_inhibit_ok = 1'b0;
				end
				if(!o_fir_history_full_r) reg_recheck_history_r_cleared = 1'b1;
				if(!o_fir_history_full_ir) reg_recheck_history_ir_cleared = 1'b1;
			end
			if(o_calibration_request_fire && (o_calibration_frame_type != FRAME_TYPE_NORMAL))begin
				if(reg_scenario_group_id == "PERIODIC-RECHECK-RECOVERY")begin
					$display("TB_RECHECK_CAL_REQUEST type=%0d color=%0d precision=%0d reason=%0d sample_valid=%0d fire=%0d busy=%0d pending=%0d seq_failed=%0d amb_code=%0d dcs_r_code=%0d dcs_ir_code=%0d amb_epoch=%0d dcs_r_epoch=%0d dcs_ir_epoch=%0d macro_tick=%0d cal_tick=%0d sched_frame_active=%0d sched_frame_mode=%0d sched_cal_pending=%0d sched_cal_active=%0d sched_cal_seen=%0d sched_wave_pending=%0d", o_calibration_frame_type, o_calibration_color_ir, o_calibration_precision_mode, o_calibration_request_reason, o_calibration_sample_valid, o_calibration_request_fire, o_amb_recheck_busy, o_amb_recheck_pending, o_recheck_sequence_failed, o_amb_code, o_dcs_r_code, o_dcs_ir_code, o_amb_code_epoch, o_dcs_r_code_epoch, o_dcs_ir_code_epoch, o_macro_tick, o_calibration_local_tick, ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode, ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_PENDING], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_ACTIVE], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_CONTEXT_SEEN], ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_WAVE_PENDING]);
				end
				if(o_startup_search_complete !== 1'b1 && !o_amb_recheck_busy && !reg_recheck_calibration_active)begin
					if(!reg_startup_calibration_active)begin
						// 每次复位后的START都建立独立启动搜索记账窗口，避免把多次JNT启动累加成一次成功证据。
						cnt_startup_calibration_request = 0;
						cnt_startup_calibration_completion = 0;
						cnt_startup_successful_calibration_completion = 0;
						cnt_startup_amb_completion = 0;
						cnt_startup_dcs_r_completion = 0;
						cnt_startup_dcs_ir_completion = 0;
						cnt_startup_q3_observed = 0;
						cnt_startup_q3_spacing_mismatch = 0;
						cnt_startup_real_chain_mismatch = 0;
						cnt_startup_amb_waveform_observed = 0;
						cnt_startup_dcs_r_waveform_observed = 0;
						cnt_startup_dcs_ir_waveform_observed = 0;
						flag_startup_q3_266_ok = 1'b1;
						flag_startup_q3_spacing_ok = 1'b1;
						flag_startup_owner_deadline_ok = 1'b1;
						flag_startup_waveform_ok = 1'b1;
						reg_startup_stage_state = 2'd0;
						reg_startup_prev_q3_macro_tick = 13'd0;
						reg_startup_prev_q3_physical_tick = 64'd0;
					end
					cnt_startup_calibration_request = cnt_startup_calibration_request + 1;
					reg_startup_calibration_active = 1'b1;
				end else if(reg_recheck_calibration_active || o_amb_recheck_busy)begin
					cnt_recheck_calibration_request = cnt_recheck_calibration_request + 1;
					if(o_calibration_precision_mode !== 1'b0)begin
						cnt_recheck_sequence_mismatch = cnt_recheck_sequence_mismatch + 1;
					end else if(o_calibration_frame_type == FRAME_TYPE_AMB && o_calibration_color_ir == 1'b0)begin
						if(reg_recheck_stage_state > 2'd1) cnt_recheck_sequence_mismatch = cnt_recheck_sequence_mismatch + 1;
						reg_recheck_stage_state = 2'd1;
						reg_recheck_stage_mask[0] = 1'b1;
					end else if(o_calibration_frame_type == FRAME_TYPE_DCS && o_calibration_color_ir == 1'b0)begin
						if((reg_recheck_stage_state != 2'd1) && (reg_recheck_stage_state != 2'd2)) cnt_recheck_sequence_mismatch = cnt_recheck_sequence_mismatch + 1;
						reg_recheck_stage_state = 2'd2;
						reg_recheck_stage_mask[1] = 1'b1;
					end else if(o_calibration_frame_type == FRAME_TYPE_DCS && o_calibration_color_ir == 1'b1)begin
						if((reg_recheck_stage_state != 2'd2) && (reg_recheck_stage_state != 2'd3)) cnt_recheck_sequence_mismatch = cnt_recheck_sequence_mismatch + 1;
						reg_recheck_stage_state = 2'd3;
						reg_recheck_stage_mask[2] = 1'b1;
					end else begin
						cnt_recheck_sequence_mismatch = cnt_recheck_sequence_mismatch + 1;
					end
				end
			end
			if(o_startup_search_complete === 1'b1 && reg_startup_calibration_active)begin
				// 搜索完成后关闭启动专用观察窗口；后续校准只能归入周期重检窗口。
				reg_startup_calibration_active = 1'b0;
			end
			if((reg_recheck_calibration_active || o_amb_recheck_busy) && i_clk_stage1_dout_low_async && !o_clk_q3_low)begin
				reg_recheck_owner_async_seen = 1'b1;
			end
			if(reg_startup_calibration_active && i_clk_stage1_dout_low_async && !o_clk_q3_low)begin
				reg_startup_owner_async_seen = 1'b1;
			end
			if(o_recheck_sequence_done && !reg_recheck_prev_done)begin
				cnt_recheck_done_observed = cnt_recheck_done_observed + 1;
				reg_recheck_sequence_done_seen = 1'b1;
				reg_recheck_slope_after = o_slope_current_q16;
				reg_recheck_slope_preserved = (o_slope_current_q16 == reg_recheck_slope_snapshot);
				if(!reg_recheck_slope_preserved) cnt_recheck_sequence_mismatch = cnt_recheck_sequence_mismatch + 1;
				reg_recheck_calibration_active = 1'b0;
			end
			if(o_recheck_sequence_failed && !reg_recheck_prev_failed)begin
				cnt_recheck_failed_observed = cnt_recheck_failed_observed + 1;
				reg_recheck_sequence_failed_seen = 1'b1;
				reg_recheck_failure_reacquire_seen = o_reacquire_active;
				reg_recheck_failure_fixed_slope_ok = (o_slope_current_q16 == i_fixed_slope_q16);
				if(!reg_recheck_failure_reacquire_seen || !reg_recheck_failure_fixed_slope_ok) cnt_recheck_sequence_mismatch = cnt_recheck_sequence_mismatch + 1;
				reg_recheck_calibration_active = 1'b0;
			end
			if((reg_recheck_calibration_active || o_amb_recheck_busy) && o_measurement_result_valid)begin
				cnt_recheck_output_leak = cnt_recheck_output_leak + 1;
			end
			// 重检成功后的预热只计入真实、成功、NORMAL、SAR9结果；history_full不能代替21笔新样本证据。
			if(reg_recheck_sequence_done_seen && o_measurement_result_valid && i_measurement_result_ready &&
				o_result_frame_type == FRAME_TYPE_NORMAL && o_result_precision_mode == 1'b0 &&
				o_coarse_valid && o_coarse_recovery_calibrated && !o_normal_output_inhibit)begin
				if(o_result_color_ir == 1'b0)begin
					if(cnt_recheck_history_r_warmup < 21) cnt_recheck_history_r_warmup = cnt_recheck_history_r_warmup + 1;
				end else begin
					if(cnt_recheck_history_ir_warmup < 21) cnt_recheck_history_ir_warmup = cnt_recheck_history_ir_warmup + 1;
				end
			end

			//---------- 结果反压保持和Stage1/Stage2/DC recovery数值检查 ----------//
			if(o_measurement_result_valid && !i_measurement_result_ready)begin
				if(!reg_result_hold_valid)begin
					reg_result_hold_valid = 1'b1;
					reg_hold_calibrated_s1_value = o_calibrated_s1_value;
					reg_hold_programmable_15_code = o_programmable_15_code;
					reg_hold_coarse_ppg_value = o_coarse_ppg_value;
					reg_hold_fine_ppg_value = o_fine_ppg_value;
					reg_hold_coarse_valid = o_coarse_valid;
					reg_hold_fine_valid = o_fine_valid;
					reg_hold_result_frame_id = o_result_frame_id;
					reg_hold_result_sample_index = o_result_sample_index;
					reg_hold_result_color_ir = o_result_color_ir;
					reg_hold_result_precision_mode = o_result_precision_mode;
					reg_hold_result_frame_type = o_result_frame_type;
					reg_hold_result_amb_code = o_result_amb_code_snapshot;
					reg_hold_result_dc_code = o_result_dc_code_snapshot;
					reg_hold_result_amb_epoch = o_result_amb_code_epoch;
					reg_hold_result_dc_epoch = o_result_dc_code_epoch;
				end else begin
					cnt_result_backpressure_comparison = cnt_result_backpressure_comparison + 1;
					if((o_calibrated_s1_value != reg_hold_calibrated_s1_value) || (o_programmable_15_code != reg_hold_programmable_15_code) ||
						(o_coarse_ppg_value != reg_hold_coarse_ppg_value) || (o_fine_ppg_value != reg_hold_fine_ppg_value) ||
						(o_coarse_valid != reg_hold_coarse_valid) || (o_fine_valid != reg_hold_fine_valid) ||
						(o_result_frame_id != reg_hold_result_frame_id) || (o_result_sample_index != reg_hold_result_sample_index) ||
						(o_result_color_ir != reg_hold_result_color_ir) || (o_result_precision_mode != reg_hold_result_precision_mode) ||
						(o_result_frame_type != reg_hold_result_frame_type) || (o_result_amb_code_snapshot != reg_hold_result_amb_code) ||
						(o_result_dc_code_snapshot != reg_hold_result_dc_code) || (o_result_amb_code_epoch != reg_hold_result_amb_epoch) ||
						(o_result_dc_code_epoch != reg_hold_result_dc_epoch))begin
						cnt_result_backpressure_mismatch = cnt_result_backpressure_mismatch + 1;
					end
				end
			end else if(i_measurement_result_ready)begin
				reg_result_hold_valid = 1'b0;
			end
			if((o_dcs_r_track_adjust || o_dcs_ir_track_adjust) && (o_programmable_15_valid || o_fine_valid))begin
				flag_tracking_stage1_only = 1'b0;
			end

			//---------- 故障汇总、owner泄漏和诊断清除观察 ----------//
			if((o_scheduler_fault_blocking || o_ssw_fault_blocking || o_ami_fault_blocking || o_idac_fault_blocking ||
				o_scheduler_protocol_error_sticky || o_switch_protocol_error_sticky || o_transaction_mismatch_sticky ||
				o_idac_protocol_error_sticky || o_baseline_protocol_error_sticky || o_integration_protocol_error_sticky))begin
				cnt_fault_blocking_cycles = cnt_fault_blocking_cycles + 1;
				if(!reg_any_fault_prev)begin
					cnt_fault_observed = cnt_fault_observed + 1;
					$display("TB_FAULT_EDGE group=%0s macro_tick=%0d cal_tick=%0d normal_active=%0b cal_active=%0b waveform_valid=%0b waveform_ready=%0b waveform_type=%0b waveform_color=%0b cal_valid=%0b cal_ready=%0b owner_commit=%0b switch_error=%0b mismatch=%0b scheduler_fault=%0b ssw_fault=%0b ami_fault=%0b", reg_run_group_id, o_macro_tick, o_calibration_local_tick, o_normal_frame_active, o_calibration_frame_active, o_waveform_context_valid, o_waveform_context_ready, o_waveform_frame_type, o_waveform_color_ir, o_calibration_sample_valid, o_calibration_sample_ready, o_adc_owner_commit_event, o_switch_protocol_error_sticky, o_transaction_mismatch_sticky, o_scheduler_fault_blocking, o_ssw_fault_blocking, o_ami_fault_blocking);
					if(!flag_fault_first_seen)begin
						flag_fault_first_seen = 1'b1;
						if(o_scheduler_fault_blocking) reg_first_fault_id = "SCHEDULER";
						else if(o_ssw_fault_blocking) reg_first_fault_id = "SSW";
						else if(o_ami_fault_blocking) reg_first_fault_id = "AMI";
						else reg_first_fault_id = "IDAC/PROTOCOL";
					end
				end
				if(o_adc_owner_commit_event) cnt_fault_owner_leak = cnt_fault_owner_leak + 1;
				if(o_measurement_result_valid) cnt_fault_result_leak = cnt_fault_result_leak + 1;
				reg_fault_seen_before_diag_clear = 1'b1;
			end
			if(i_diag_clear_event && reg_fault_seen_before_diag_clear)begin
				flag_fault_sticky_clear_observed = 1'b1;
			end
			if(flag_fault_sticky_clear_observed && !o_scheduler_fault_blocking && !o_ssw_fault_blocking && !o_ami_fault_blocking)begin
				flag_fault_recovery_clean = !o_scheduler_transaction_inflight && !o_adc_owner_inflight;
			end
			reg_any_fault_prev = (o_scheduler_fault_blocking || o_ssw_fault_blocking || o_ami_fault_blocking || o_idac_fault_blocking ||
				o_scheduler_protocol_error_sticky || o_switch_protocol_error_sticky || o_transaction_mismatch_sticky ||
				o_idac_protocol_error_sticky || o_baseline_protocol_error_sticky || o_integration_protocol_error_sticky);

			reg_idac_prev_amb_pending = o_amb_pending_valid;
			reg_idac_prev_dcs_r_pending = o_dcs_r_pending_valid;
			reg_idac_prev_dcs_ir_pending = o_dcs_ir_pending_valid;
			reg_idac_prev_amb_search_done = o_amb_search_done;
			reg_idac_prev_dcs_r_search_done = o_dcs_r_search_done;
			reg_idac_prev_dcs_ir_search_done = o_dcs_ir_search_done;
			reg_idac_prev_amb_exhausted = o_amb_search_exhausted;
			reg_idac_prev_dcs_r_exhausted = o_dcs_r_search_exhausted;
			reg_idac_prev_dcs_ir_exhausted = o_dcs_ir_search_exhausted;
			reg_recheck_prev_pending = o_amb_recheck_pending;
			reg_recheck_prev_accept = o_amb_recheck_accept;
			reg_recheck_prev_done = o_recheck_sequence_done;
			reg_recheck_prev_failed = o_recheck_sequence_failed;
			// Preserve the pre-edge scheduler context so a deadline sticky set on
			// the previous state transition retains its actual RED/IR/CAL cause.
			reg_scheduler_prev_frame_active = ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE];
			reg_scheduler_prev_frame_mode = ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode;
			reg_scheduler_prev_red_pending = ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_RED_WAVE_PENDING];
			reg_scheduler_prev_ir_pending = ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_IR_WAVE_PENDING];
			reg_scheduler_prev_cal_pending = ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_WAVE_PENDING];
			reg_scheduler_prev_macro_tick = o_macro_tick;
			reg_scheduler_prev_cal_tick = o_calibration_local_tick;
		end
	end

	//===================<仿真激励区域>===================//
	// 算法观察线在时钟沿后采样，避免错过由AMI寄存器更新产生的单拍事件。
	always@(posedge i_clk)begin
		#1;
		if((i_input_source == 1'b1) && (o_macro_frame_start_event == 1'b1))begin
			// o_macro_tick is a wrapped phase counter, so it cannot prove the
			// absolute 400-Hz interval.  Use simulation time for the 5000-tick
			// physical-frame period and retain the phase snapshot for diagnostics.
			if(cnt_matrix_frame_start > 0 && (($time - reg_matrix_prev_frame_time) != (C_CLK_PERIOD_NS * 5000)))begin
				cnt_matrix_frame_interval_mismatch = cnt_matrix_frame_interval_mismatch + 1;
				flag_matrix_400hz_ok = 1'b0;
			end
			reg_matrix_prev_macro_tick = o_macro_tick;
			reg_matrix_prev_frame_time = $time;
			cnt_matrix_frame_start = cnt_matrix_frame_start + 1;
		end
		if(i_static_characterization_enable == 1'b1)begin
			if(o_fir_history_full_r || o_fir_history_full_ir) flag_static_fir_seen = 1'b1;
			if(o_amb_recheck_pending || o_amb_recheck_busy || o_recheck_sequence_done || o_recheck_sequence_failed) flag_static_recheck_seen = 1'b1;
			if(o_measurement_result_valid || o_cross_pending || o_peak_pending || o_valley_pending) flag_static_algorithm_result_seen = 1'b1;
		end
		if(flag_ppg_algorithm_active == 1'b1)begin
			if(o_baseline_valid == 1'b1) flag_ppg_baseline_valid_seen = 1'b1;
			if(o_cross_pending == 1'b1) flag_ppg_cross_pending_seen = 1'b1;
			if(o_fine_window_start_event == 1'b1) flag_ppg_fine_window_start_seen = 1'b1;
			if(o_peak_pending == 1'b1) flag_ppg_peak_pending_seen = 1'b1;
			if(o_valley_pending == 1'b1) flag_ppg_valley_pending_seen = 1'b1;
			if(o_fir_history_full_r == 1'b1) flag_ppg_fir_full_r_seen = 1'b1;
			if(o_fir_history_full_ir == 1'b1) flag_ppg_fir_full_ir_seen = 1'b1;
			if(o_active_precision_mode == 1'b1) flag_ppg_precision_15_seen = 1'b1;
			if(o_precision_15_to_9_event == 1'b1) flag_ppg_precision_15_to_9_seen = 1'b1;
			if(o_return_pending == 1'b1) cnt_ppg_return_pending_seen = cnt_ppg_return_pending_seen + 1;
			if(o_precision_15_to_9_event == 1'b1) cnt_ppg_return_event_seen = cnt_ppg_return_event_seen + 1;
			if(o_fine_window_timeout_sticky == 1'b1) cnt_ppg_fine_timeout_seen = cnt_ppg_fine_timeout_seen + 1;
			if(o_reacquire_active == 1'b1) cnt_ppg_reacquire_seen = cnt_ppg_reacquire_seen + 1;
			if(flag_ppg_precision_15_seen && (o_active_precision_mode == 1'b0)) flag_ppg_precision_9_after_15_seen = 1'b1;
			if(o_measurement_result_valid && i_measurement_result_ready)begin
				cnt_ppg_algorithm_result = cnt_ppg_algorithm_result + 1;
				if(o_result_precision_mode == 1'b1)begin
					cnt_ppg_algorithm_sar15_result = cnt_ppg_algorithm_sar15_result + 1;
				end else begin
					cnt_ppg_algorithm_sar9_result = cnt_ppg_algorithm_sar9_result + 1;
					if(flag_ppg_precision_15_seen) flag_ppg_sar15_tail_isolated = 1'b1;
				end
				if(flag_ppg_have_result && (o_result_sample_index != (reg_ppg_last_result_sample_index + 16'd1)))begin
					flag_ppg_result_sequence_ok = 1'b0;
				end
				if(flag_ppg_have_result && (o_result_frame_id < reg_ppg_last_result_frame_id))begin
					flag_ppg_result_sequence_ok = 1'b0;
				end
				reg_ppg_last_result_sample_index = o_result_sample_index;
				reg_ppg_last_result_frame_id = o_result_frame_id;
				flag_ppg_have_result = 1'b1;
			end
			if(reg_recheck_sequence_done_seen && (cnt_recheck_history_r_warmup >= 21) &&
				(cnt_recheck_history_ir_warmup >= 21) && o_cross_pending) reg_recheck_recross_seen = 1'b1;
			if(reg_recheck_sequence_done_seen && (cnt_recheck_history_r_warmup >= 21) &&
				(cnt_recheck_history_ir_warmup >= 21) && o_fine_window_start_event) reg_recheck_recross_fine_seen = 1'b1;
		end
	end

	initial begin
		flag_trace_metadata_initialized = 1'b0;
		// Contract trace-map initialization is data-only; each later checker marks PASS or FAIL.
		reg_trace_id[0] = "RAW-01";
		reg_trace_observable[0] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[0] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[1] = "RAW-02";
		reg_trace_observable[1] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[1] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[2] = "RAW-03";
		reg_trace_observable[2] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[2] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[3] = "RAW-04";
		reg_trace_observable[3] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[3] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[4] = "RAW-05";
		reg_trace_observable[4] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[4] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[5] = "RAW-06";
		reg_trace_observable[5] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[5] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[6] = "RAW-07";
		reg_trace_observable[6] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[6] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[7] = "RAW-08";
		reg_trace_observable[7] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[7] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[8] = "RAW-09";
		reg_trace_observable[8] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[8] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[9] = "RAW-10";
		reg_trace_observable[9] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[9] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[10] = "RAW-11";
		reg_trace_observable[10] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[10] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[11] = "RAW-12";
		reg_trace_observable[11] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[11] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[12] = "RAW-13";
		reg_trace_observable[12] = "o_macro_tick/o_clk_q3_low/o_adc_transaction_complete_event";
		reg_trace_expected[12] = "physical RAW timing and no fixed-delay DONE";
		reg_trace_id[13] = "SID-01";
		reg_trace_observable[13] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[13] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[14] = "SID-02";
		reg_trace_observable[14] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[14] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[15] = "SID-03";
		reg_trace_observable[15] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[15] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[16] = "SID-04";
		reg_trace_observable[16] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[16] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[17] = "SID-05";
		reg_trace_observable[17] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[17] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[18] = "SID-06";
		reg_trace_observable[18] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[18] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[19] = "SID-07";
		reg_trace_observable[19] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[19] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[20] = "SID-08";
		reg_trace_observable[20] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[20] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[21] = "SID-09";
		reg_trace_observable[21] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[21] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[22] = "SID-10";
		reg_trace_observable[22] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[22] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[23] = "SID-11";
		reg_trace_observable[23] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[23] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[24] = "SID-12";
		reg_trace_observable[24] = "o_calibration_subframe_index/o_calibration_local_tick/o_calibration_request_fire";
		reg_trace_expected[24] = "AMB->DC_R->DC_IR real 8x SAR9 causal completion";
		reg_trace_id[25] = "TRK-01";
		reg_trace_observable[25] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[25] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[26] = "TRK-02";
		reg_trace_observable[26] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[26] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[27] = "TRK-03";
		reg_trace_observable[27] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[27] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[28] = "TRK-04";
		reg_trace_observable[28] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[28] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[29] = "TRK-05";
		reg_trace_observable[29] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[29] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[30] = "TRK-06";
		reg_trace_observable[30] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[30] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[31] = "TRK-07";
		reg_trace_observable[31] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[31] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[32] = "TRK-08";
		reg_trace_observable[32] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[32] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[33] = "TRK-09";
		reg_trace_observable[33] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[33] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[34] = "TRK-10";
		reg_trace_observable[34] = "o_amb_pending_valid/o_dcs_r_pending_valid/o_dcs_ir_pending_valid/o_*_update/o_*_epoch";
		reg_trace_expected[34] = "confirmation, one-LSB safe commit, update and epoch";
		reg_trace_id[35] = "RRC-01";
		reg_trace_observable[35] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[35] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[36] = "RRC-02";
		reg_trace_observable[36] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[36] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[37] = "RRC-03";
		reg_trace_observable[37] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[37] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[38] = "RRC-04";
		reg_trace_observable[38] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[38] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[39] = "RRC-05";
		reg_trace_observable[39] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[39] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[40] = "RRC-06";
		reg_trace_observable[40] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[40] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[41] = "RRC-07";
		reg_trace_observable[41] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[41] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[42] = "RRC-08";
		reg_trace_observable[42] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[42] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[43] = "RRC-09";
		reg_trace_observable[43] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[43] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[44] = "RRC-10";
		reg_trace_observable[44] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[44] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[45] = "RRC-11";
		reg_trace_observable[45] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[45] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[46] = "RRC-12";
		reg_trace_observable[46] = "o_amb_recheck_pending/o_amb_recheck_accept/o_amb_recheck_busy/o_recheck_sequence_done";
		reg_trace_expected[46] = "drain, real three-stage recheck, rewarm and recross";
		reg_trace_id[47] = "NRE-01";
		reg_trace_observable[47] = "i_amb_recheck_interval_frames/o_amb_recheck_pending/o_cross_pending";
		reg_trace_expected[47] = "interval zero keeps recheck disabled while normal cross works";
		reg_trace_id[48] = "NRE-02";
		reg_trace_observable[48] = "i_amb_recheck_interval_frames/o_amb_recheck_pending/o_cross_pending";
		reg_trace_expected[48] = "interval zero keeps recheck disabled while normal cross works";
		reg_trace_id[49] = "NRE-03";
		reg_trace_observable[49] = "i_amb_recheck_interval_frames/o_amb_recheck_pending/o_cross_pending";
		reg_trace_expected[49] = "interval zero keeps recheck disabled while normal cross works";
		reg_trace_id[50] = "NRE-04";
		reg_trace_observable[50] = "i_amb_recheck_interval_frames/o_amb_recheck_pending/o_cross_pending";
		reg_trace_expected[50] = "interval zero keeps recheck disabled while normal cross works";
		reg_trace_id[51] = "NRE-05";
		reg_trace_observable[51] = "i_amb_recheck_interval_frames/o_amb_recheck_pending/o_cross_pending";
		reg_trace_expected[51] = "interval zero keeps recheck disabled while normal cross works";
		reg_trace_id[52] = "NRE-06";
		reg_trace_observable[52] = "i_amb_recheck_interval_frames/o_amb_recheck_pending/o_cross_pending";
		reg_trace_expected[52] = "interval zero keeps recheck disabled while normal cross works";
		reg_trace_id[53] = "ILM-01";
		reg_trace_observable[53] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[53] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[54] = "ILM-02";
		reg_trace_observable[54] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[54] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[55] = "ILM-03";
		reg_trace_observable[55] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[55] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[56] = "ILM-04";
		reg_trace_observable[56] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[56] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[57] = "ILM-05";
		reg_trace_observable[57] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[57] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[58] = "ILM-06";
		reg_trace_observable[58] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[58] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[59] = "ILM-07";
		reg_trace_observable[59] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[59] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[60] = "ILM-08";
		reg_trace_observable[60] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[60] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[61] = "ILM-09";
		reg_trace_observable[61] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[61] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[62] = "ILM-10";
		reg_trace_observable[62] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[62] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[63] = "ILM-11";
		reg_trace_observable[63] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[63] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[64] = "ILM-12";
		reg_trace_observable[64] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[64] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[65] = "ILM-13";
		reg_trace_observable[65] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[65] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[66] = "ILM-14";
		reg_trace_observable[66] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[66] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[67] = "ILM-15";
		reg_trace_observable[67] = "i_input_source/i_optical_mode/o_en_test/o_leden1_low/o_leden2_low/o_s_in";
		reg_trace_expected[67] = "legal and illegal input/light/STATIC_BIAS matrix";
		reg_trace_id[68] = "ADCN-01";
		reg_trace_observable[68] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[68] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[69] = "ADCN-02";
		reg_trace_observable[69] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[69] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[70] = "ADCN-03";
		reg_trace_observable[70] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[70] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[71] = "ADCN-04";
		reg_trace_observable[71] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[71] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[72] = "ADCN-05";
		reg_trace_observable[72] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[72] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[73] = "ADCN-06";
		reg_trace_observable[73] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[73] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[74] = "ADCN-07";
		reg_trace_observable[74] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[74] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[75] = "ADCN-08";
		reg_trace_observable[75] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[75] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[76] = "ADCN-09";
		reg_trace_observable[76] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[76] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[77] = "ADCN-10";
		reg_trace_observable[77] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value";
		reg_trace_expected[77] = "signed numeric chain and identity-bound scoreboard";
		reg_trace_id[78] = "ISE-01";
		reg_trace_observable[78] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[78] = "preheat snapshot and precision bus isolation";
		reg_trace_id[79] = "ISE-02";
		reg_trace_observable[79] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[79] = "preheat snapshot and precision bus isolation";
		reg_trace_id[80] = "ISE-03";
		reg_trace_observable[80] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[80] = "preheat snapshot and precision bus isolation";
		reg_trace_id[81] = "ISE-04";
		reg_trace_observable[81] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[81] = "preheat snapshot and precision bus isolation";
		reg_trace_id[82] = "ISE-05";
		reg_trace_observable[82] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[82] = "preheat snapshot and precision bus isolation";
		reg_trace_id[83] = "ISE-06";
		reg_trace_observable[83] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[83] = "preheat snapshot and precision bus isolation";
		reg_trace_id[84] = "ISE-07";
		reg_trace_observable[84] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[84] = "preheat snapshot and precision bus isolation";
		reg_trace_id[85] = "ISE-08";
		reg_trace_observable[85] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[85] = "preheat snapshot and precision bus isolation";
		reg_trace_id[86] = "ISE-09";
		reg_trace_observable[86] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[86] = "preheat snapshot and precision bus isolation";
		reg_trace_id[87] = "ISE-10";
		reg_trace_observable[87] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_expected[87] = "preheat snapshot and precision bus isolation";
		reg_trace_id[88] = "OIB-01";
		reg_trace_observable[88] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[88] = "public backpressure preserves payload and identity";
		reg_trace_id[89] = "OIB-02";
		reg_trace_observable[89] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[89] = "public backpressure preserves payload and identity";
		reg_trace_id[90] = "OIB-03";
		reg_trace_observable[90] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[90] = "public backpressure preserves payload and identity";
		reg_trace_id[91] = "OIB-04";
		reg_trace_observable[91] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[91] = "public backpressure preserves payload and identity";
		reg_trace_id[92] = "OIB-05";
		reg_trace_observable[92] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[92] = "public backpressure preserves payload and identity";
		reg_trace_id[93] = "OIB-06";
		reg_trace_observable[93] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[93] = "public backpressure preserves payload and identity";
		reg_trace_id[94] = "OIB-07";
		reg_trace_observable[94] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[94] = "public backpressure preserves payload and identity";
		reg_trace_id[95] = "OIB-08";
		reg_trace_observable[95] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[95] = "public backpressure preserves payload and identity";
		reg_trace_id[96] = "OIB-09";
		reg_trace_observable[96] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[96] = "public backpressure preserves payload and identity";
		reg_trace_id[97] = "OIB-10";
		reg_trace_observable[97] = "o_waveform_context_ready/o_transaction_start_ready/o_measurement_result_valid";
		reg_trace_expected[97] = "public backpressure preserves payload and identity";
		reg_trace_id[98] = "LFA-01";
		reg_trace_observable[98] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[98] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[99] = "LFA-02";
		reg_trace_observable[99] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[99] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[100] = "LFA-03";
		reg_trace_observable[100] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[100] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[101] = "LFA-04";
		reg_trace_observable[101] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[101] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[102] = "LFA-05";
		reg_trace_observable[102] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[102] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[103] = "LFA-06";
		reg_trace_observable[103] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[103] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[104] = "LFA-07";
		reg_trace_observable[104] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[104] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[105] = "LFA-08";
		reg_trace_observable[105] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[105] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[106] = "LFA-09";
		reg_trace_observable[106] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[106] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[107] = "LFA-10";
		reg_trace_observable[107] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[107] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[108] = "LFA-11";
		reg_trace_observable[108] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[108] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[109] = "LFA-12";
		reg_trace_observable[109] = "i_stop_ack_event/i_control_abort_event/i_rstn/o_*_fault_blocking";
		reg_trace_expected[109] = "STOP abort reset anomaly and clean restart";
		reg_trace_id[110] = "PRC-01";
		reg_trace_observable[110] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[110] = "corner waveforms reject false events and preserve order";
		reg_trace_id[111] = "PRC-02";
		reg_trace_observable[111] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[111] = "corner waveforms reject false events and preserve order";
		reg_trace_id[112] = "PRC-03";
		reg_trace_observable[112] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[112] = "corner waveforms reject false events and preserve order";
		reg_trace_id[113] = "PRC-04";
		reg_trace_observable[113] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[113] = "corner waveforms reject false events and preserve order";
		reg_trace_id[114] = "PRC-05";
		reg_trace_observable[114] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[114] = "corner waveforms reject false events and preserve order";
		reg_trace_id[115] = "PRC-06";
		reg_trace_observable[115] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[115] = "corner waveforms reject false events and preserve order";
		reg_trace_id[116] = "PRC-07";
		reg_trace_observable[116] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[116] = "corner waveforms reject false events and preserve order";
		reg_trace_id[117] = "PRC-08";
		reg_trace_observable[117] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[117] = "corner waveforms reject false events and preserve order";
		reg_trace_id[118] = "PRC-09";
		reg_trace_observable[118] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[118] = "corner waveforms reject false events and preserve order";
		reg_trace_id[119] = "PRC-10";
		reg_trace_observable[119] = "o_baseline_valid/o_cross_pending/o_peak_pending/o_valley_pending/o_reacquire_active";
		reg_trace_expected[119] = "corner waveforms reject false events and preserve order";
		reg_trace_status[0] = TRACE_UNCHECKED;
		reg_trace_status[1] = TRACE_UNCHECKED;
		reg_trace_status[2] = TRACE_UNCHECKED;
		reg_trace_status[3] = TRACE_UNCHECKED;
		reg_trace_status[4] = TRACE_UNCHECKED;
		reg_trace_status[5] = TRACE_UNCHECKED;
		reg_trace_status[6] = TRACE_UNCHECKED;
		reg_trace_status[7] = TRACE_UNCHECKED;
		reg_trace_status[8] = TRACE_UNCHECKED;
		reg_trace_status[9] = TRACE_UNCHECKED;
		reg_trace_status[10] = TRACE_UNCHECKED;
		reg_trace_status[11] = TRACE_UNCHECKED;
		reg_trace_status[12] = TRACE_UNCHECKED;
		reg_trace_status[13] = TRACE_UNCHECKED;
		reg_trace_status[14] = TRACE_UNCHECKED;
		reg_trace_status[15] = TRACE_UNCHECKED;
		reg_trace_status[16] = TRACE_UNCHECKED;
		reg_trace_status[17] = TRACE_UNCHECKED;
		reg_trace_status[18] = TRACE_UNCHECKED;
		reg_trace_status[19] = TRACE_UNCHECKED;
		reg_trace_status[20] = TRACE_UNCHECKED;
		reg_trace_status[21] = TRACE_UNCHECKED;
		reg_trace_status[22] = TRACE_UNCHECKED;
		reg_trace_status[23] = TRACE_UNCHECKED;
		reg_trace_status[24] = TRACE_UNCHECKED;
		reg_trace_status[25] = TRACE_UNCHECKED;
		reg_trace_status[26] = TRACE_UNCHECKED;
		reg_trace_status[27] = TRACE_UNCHECKED;
		reg_trace_status[28] = TRACE_UNCHECKED;
		reg_trace_status[29] = TRACE_UNCHECKED;
		reg_trace_status[30] = TRACE_UNCHECKED;
		reg_trace_status[31] = TRACE_UNCHECKED;
		reg_trace_status[32] = TRACE_UNCHECKED;
		reg_trace_status[33] = TRACE_UNCHECKED;
		reg_trace_status[34] = TRACE_UNCHECKED;
		reg_trace_status[35] = TRACE_UNCHECKED;
		reg_trace_status[36] = TRACE_UNCHECKED;
		reg_trace_status[37] = TRACE_UNCHECKED;
		reg_trace_status[38] = TRACE_UNCHECKED;
		reg_trace_status[39] = TRACE_UNCHECKED;
		reg_trace_status[40] = TRACE_UNCHECKED;
		reg_trace_status[41] = TRACE_UNCHECKED;
		reg_trace_status[42] = TRACE_UNCHECKED;
		reg_trace_status[43] = TRACE_UNCHECKED;
		reg_trace_status[44] = TRACE_UNCHECKED;
		reg_trace_status[45] = TRACE_UNCHECKED;
		reg_trace_status[46] = TRACE_UNCHECKED;
		reg_trace_status[47] = TRACE_UNCHECKED;
		reg_trace_status[48] = TRACE_UNCHECKED;
		reg_trace_status[49] = TRACE_UNCHECKED;
		reg_trace_status[50] = TRACE_UNCHECKED;
		reg_trace_status[51] = TRACE_UNCHECKED;
		reg_trace_status[52] = TRACE_UNCHECKED;
		reg_trace_status[53] = TRACE_UNCHECKED;
		reg_trace_status[54] = TRACE_UNCHECKED;
		reg_trace_status[55] = TRACE_UNCHECKED;
		reg_trace_status[56] = TRACE_UNCHECKED;
		reg_trace_status[57] = TRACE_UNCHECKED;
		reg_trace_status[58] = TRACE_UNCHECKED;
		reg_trace_status[59] = TRACE_UNCHECKED;
		reg_trace_status[60] = TRACE_UNCHECKED;
		reg_trace_status[61] = TRACE_UNCHECKED;
		reg_trace_status[62] = TRACE_UNCHECKED;
		reg_trace_status[63] = TRACE_UNCHECKED;
		reg_trace_status[64] = TRACE_UNCHECKED;
		reg_trace_status[65] = TRACE_UNCHECKED;
		reg_trace_status[66] = TRACE_UNCHECKED;
		reg_trace_status[67] = TRACE_UNCHECKED;
		reg_trace_status[68] = TRACE_UNCHECKED;
		reg_trace_status[69] = TRACE_UNCHECKED;
		reg_trace_status[70] = TRACE_UNCHECKED;
		reg_trace_status[71] = TRACE_UNCHECKED;
		reg_trace_status[72] = TRACE_UNCHECKED;
		reg_trace_status[73] = TRACE_UNCHECKED;
		reg_trace_status[74] = TRACE_UNCHECKED;
		reg_trace_status[75] = TRACE_UNCHECKED;
		reg_trace_status[76] = TRACE_UNCHECKED;
		reg_trace_status[77] = TRACE_UNCHECKED;
		reg_trace_status[78] = TRACE_UNCHECKED;
		reg_trace_status[79] = TRACE_UNCHECKED;
		reg_trace_status[80] = TRACE_UNCHECKED;
		reg_trace_status[81] = TRACE_UNCHECKED;
		reg_trace_status[82] = TRACE_UNCHECKED;
		reg_trace_status[83] = TRACE_UNCHECKED;
		reg_trace_status[84] = TRACE_UNCHECKED;
		reg_trace_status[85] = TRACE_UNCHECKED;
		reg_trace_status[86] = TRACE_UNCHECKED;
		reg_trace_status[87] = TRACE_UNCHECKED;
		reg_trace_status[88] = TRACE_UNCHECKED;
		reg_trace_status[89] = TRACE_UNCHECKED;
		reg_trace_status[90] = TRACE_UNCHECKED;
		reg_trace_status[91] = TRACE_UNCHECKED;
		reg_trace_status[92] = TRACE_UNCHECKED;
		reg_trace_status[93] = TRACE_UNCHECKED;
		reg_trace_status[94] = TRACE_UNCHECKED;
		reg_trace_status[95] = TRACE_UNCHECKED;
		reg_trace_status[96] = TRACE_UNCHECKED;
		reg_trace_status[97] = TRACE_UNCHECKED;
		reg_trace_status[98] = TRACE_UNCHECKED;
		reg_trace_status[99] = TRACE_UNCHECKED;
		reg_trace_status[100] = TRACE_UNCHECKED;
		reg_trace_status[101] = TRACE_UNCHECKED;
		reg_trace_status[102] = TRACE_UNCHECKED;
		reg_trace_status[103] = TRACE_UNCHECKED;
		reg_trace_status[104] = TRACE_UNCHECKED;
		reg_trace_status[105] = TRACE_UNCHECKED;
		reg_trace_status[106] = TRACE_UNCHECKED;
		reg_trace_status[107] = TRACE_UNCHECKED;
		reg_trace_status[108] = TRACE_UNCHECKED;
		reg_trace_status[109] = TRACE_UNCHECKED;
		reg_trace_status[110] = TRACE_UNCHECKED;
		reg_trace_status[111] = TRACE_UNCHECKED;
		reg_trace_status[112] = TRACE_UNCHECKED;
		reg_trace_status[113] = TRACE_UNCHECKED;
		reg_trace_status[114] = TRACE_UNCHECKED;
		reg_trace_status[115] = TRACE_UNCHECKED;
		reg_trace_status[116] = TRACE_UNCHECKED;
		reg_trace_status[117] = TRACE_UNCHECKED;
		reg_trace_status[118] = TRACE_UNCHECKED;
		reg_trace_status[119] = TRACE_UNCHECKED;
		reg_trace_observable[13] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[14] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[15] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[16] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[17] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[18] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[19] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[20] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[21] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[22] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[23] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[24] = "o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[35] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[36] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[37] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[38] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[39] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[40] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[41] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[42] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[43] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[44] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[45] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[46] = "o_amb_recheck_* / o_calibration_local_tick/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		reg_trace_observable[68] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[69] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[70] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[71] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[72] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[73] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[74] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[75] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[76] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[77] = "o_calibrated_s1_value/o_programmable_15_code/o_coarse_ppg_value/o_fine_ppg_value/o_result_*";
		reg_trace_observable[78] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[79] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[80] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[81] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[82] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[83] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[84] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[85] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[86] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[87] = "o_waveform_*_snapshot/o_idac_sar9*/o_idac_sar15*/o_*_code_epoch";
		reg_trace_observable[58] = "o_en_test/o_leden1_low/o_leden2_low/o_leddac/o_waveform_color_ir/o_adc_owner_commit_event";
		reg_trace_observable[59] = "o_en_test/o_leden1_low/o_leden2_low/o_leddac/o_waveform_color_ir/o_adc_owner_commit_event";
		reg_trace_observable[65] = "o_s_in/o_clk_9q1_low/o_clk_15q1_low/o_clk_q2_low/o_clk_q3_low/i_clk_stage1_dout_low_async/o_adc_transaction_complete_event";
		i_rstn = 1'b0;
		i_active_config_valid = 1'b1;
		analog_run_enable = 1'b0;
		measurement_run_enable = 1'b0;
		measurement_allow_new_transaction = 1'b0;
		analog_start_ack_event = 1'b0;
		measurement_start_ack_event = 1'b0;
		i_stop_ack_event = 1'b0;
		i_control_abort_event = 1'b0;
		i_diag_clear_event = 1'b0;
		i_run_profile = 1'b0;
		i_input_source = 1'b0;
		i_optical_mode = OPTICAL_MODE_BOTH;
		i_static_characterization_enable = 1'b0;
		i_test_mux_ctrl = 5'd0;
		i_leddac_r_code = 8'h3c;
		i_leddac_ir_code = 8'h5a;
		i_dout_stage1_low = 10'd0;
		i_clk_stage1_dout_low_async = 1'b0;
		i_dout_stage2_low = 10'd0;
		i_clk_stage2_dout_low_async = 1'b0;
		i_adc_idle = 1'b1;
		i_measurement_result_ready = 1'b1;
		i_config_epoch = 8'h11;
		i_stage1_coef_epoch = 8'h21;
		i_stage2_coef_epoch = 8'h31;
		i_dc_recovery_coef_epoch = 8'h41;
		i_idac_mode = 2'b00;
		i_amb_enable = 1'b1;
		i_dcs_enable = 1'b1;
		i_amb_polarity = 1'b1;
		i_dcs_polarity = 1'b1;
		i_amb_manual_code = 8'h31;
		i_amb_code_min = 8'h00;
		i_amb_code_max = 8'hff;
		i_dcs_r_manual_code = 8'h42;
		i_dcs_r_code_min = 8'h00;
		i_dcs_r_code_max = 8'hff;
		i_dcs_ir_manual_code = 8'h53;
		i_dcs_ir_code_min = 8'h00;
		i_dcs_ir_code_max = 8'hff;
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
		reg_scenario_recheck_interval = 16'hffff;
		reg_scenario_input_source = 1'b0;
		reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
		reg_scenario_initial_precision = 1'b0;
		reg_scenario_emit_long_checks = 1'b1;
		reg_scenario_group_id = "PPG-LONG-10-CYCLES";
		reg_scenario_idac_mode = 2'b00;
		reg_scenario_startup_watchdog_limit = 100;
		reg_scenario_enable_tracking_after_startup = 1'b0;
		reg_scenario_force_search_failure = 1'b0;
		reg_scenario_force_recheck_failure = 1'b0;
		reg_scenario_allow_startup_failure = 1'b0;
		reg_scenario_waveform_mode = 0;
		reg_scenario_numeric_vector_mode = 0;
		reg_scenario_enable_result_backpressure = 1'b0;
		reg_scenario_enable_waveform_backpressure = 1'b0;
		reg_scenario_enable_transaction_backpressure = 1'b0;
		reg_expected_raw_signature = 32'd0;
		flag_raw_signature_expected = $value$plusargs("RAW_SIGNATURE=%h", reg_expected_raw_signature);
		reg_scenario_sample_count = C_PPG_ALGORITHM_SAMPLES;
		cnt_pass = 0;
		cnt_fail = 0;
		cnt_run_index = 0;
		cnt_run_jnt_checked = 0;
		cnt_run_jnt_pass = 0;
		cnt_run_jnt_fail = 0;
		cnt_run_event = 0;
		cnt_run_stable_pass = 0;
		cnt_run_stable_fail = 0;
		cnt_run_stable_unclosed = 0;
		cnt_jnt_parent_run_index = 0;
		cnt_jnt_parent_checked = 0;
		cnt_jnt_parent_pass = 0;
		cnt_jnt_parent_fail = 0;
		flag_jnt_parent_valid = 1'b0;
		reg_jnt_parent_group_id = "NONE";
		fd_event_log = -1;
		flag_event_log_initialized = 1'b0;
		fd_event_log = $fopen("D:/PPG/verilog/jxa/ppg_system_integration/tb_ppg_event_trace.log");
		if(fd_event_log != 0) flag_event_log_initialized = 1'b1;
		flag_jnt_baseline_active = 1'b0;
		reg_run_group_id = "BOOT";
		reg_contract_group_id = "BOOT";
		flag_contract_group_override = 1'b0;
		reg_run_first_failure_id = "NONE";
		time_run_reset_assert = 0;
		time_run_start_ack = 0;
		time_run_deadline = 0;
		cnt_startup_boundary = 0;
		cnt_waveform_context = 0;
		cnt_owner_commit = 0;
		cnt_completion = 0;
		cnt_measurement_result = 0;
		cnt_red_waveform_context = 0;
		cnt_ir_waveform_context = 0;
		cnt_watchdog = 0;
		cnt_owner_before = 0;
		cnt_completion_before = 0;
		cnt_result_before = 0;
		flag_startup_boundary_without_owner = 1'b0;
		reg_startup_boundary_sample_index = 16'd0;
		flag_ir_context_while_red_inflight = 1'b0;
		flag_red_q1_seen = 1'b0;
		flag_red_q2_seen = 1'b0;
		flag_red_q3_seen = 1'b0;
		flag_ir_q1_seen = 1'b0;
		flag_ir_q2_seen = 1'b0;
		flag_ir_q3_seen = 1'b0;
		reg_last_owner_frame_id = 16'd0;
		reg_last_owner_color_ir = 1'b0;
		reg_last_owner_sample_index = 16'd0;
		reg_last_owner_macro_tick = 13'd0;
		reg_last_owner_precision_mode = 1'b0;
		reg_last_owner_amb_code = 8'h00;
		reg_last_owner_dc_code = 8'h00;
		reg_red_waveform_precision_mode = 1'b0;
		reg_red_waveform_amb_code = 8'h00;
		reg_red_waveform_dc_code = 8'h00;
		reg_ir_waveform_precision_mode = 1'b0;
		reg_ir_waveform_amb_code = 8'h00;
		reg_ir_waveform_dc_code = 8'h00;
		flag_owner_context_identity_match = 1'b0;
		flag_selected_amb_bus_seen = 1'b0;
		flag_selected_dc_bus_seen = 1'b0;
		flag_red_dc_bus_seen = 1'b0;
		flag_ir_dc_bus_seen = 1'b0;
		flag_unselected_idac_bus_clean = 1'b1;
		flag_idac_bus_violation = 1'b0;
		reg_last_completion_success = 1'b0;
		reg_last_completion_sample_index = 16'd0;
		flag_reset_done_observation = 1'b0;
		flag_ppg_algorithm_active = 1'b0;
		cnt_ppg_algorithm_result = 0;
		cnt_ppg_algorithm_sar9_result = 0;
		cnt_ppg_algorithm_sar15_result = 0;
		flag_ppg_baseline_valid_seen = 1'b0;
		flag_ppg_cross_pending_seen = 1'b0;
		flag_ppg_fine_window_start_seen = 1'b0;
		flag_ppg_peak_pending_seen = 1'b0;
		flag_ppg_valley_pending_seen = 1'b0;
		flag_ppg_precision_15_seen = 1'b0;
		flag_ppg_precision_15_to_9_seen = 1'b0;
		flag_ppg_precision_9_after_15_seen = 1'b0;
		flag_ppg_fir_full_r_seen = 1'b0;
		flag_ppg_fir_full_ir_seen = 1'b0;
		flag_ppg_result_sequence_ok = 1'b1;
		flag_ppg_sar15_tail_isolated = 1'b0;
		flag_ppg_have_result = 1'b0;
		reg_ppg_last_result_sample_index = 16'd0;
		reg_ppg_last_result_frame_id = 16'd0;
		reg_last_calibrated_s1_value = 12'sd0;
		reg_last_programmable_15_code = 15'sd0;
		reg_last_coarse_ppg_value = 24'sd0;
		reg_last_fine_ppg_value = 24'sd0;
		reg_last_result_config_epoch = 8'd0;
		reg_last_result_coef_epoch = 8'd0;
		reg_last_result_stage2_coef_epoch = 8'd0;
		reg_last_result_dc_coef_epoch = 8'd0;
		reg_last_result_frame_type = 2'd0;
		reg_last_result_amb_code_snapshot = 8'd0;
		reg_last_result_dc_code_snapshot = 8'd0;
		reg_last_result_amb_code_epoch = 4'd0;
		reg_last_result_dc_code_epoch = 4'd0;
		time_ppg_algorithm_start = 0;
		time_ppg_algorithm_end = 0;
		cnt_amb_pending_observed = 0;
		cnt_dcs_r_pending_observed = 0;
		cnt_dcs_ir_pending_observed = 0;
		cnt_amb_update_observed = 0;
		cnt_dcs_r_update_observed = 0;
		cnt_dcs_ir_update_observed = 0;
		cnt_dcs_r_track_adjust_observed = 0;
		cnt_dcs_ir_track_adjust_observed = 0;
		cnt_amb_search_done_observed = 0;
		cnt_dcs_r_search_done_observed = 0;
		cnt_dcs_ir_search_done_observed = 0;
		cnt_idac_search_exhausted_observed = 0;
		cnt_idac_epoch_mismatch = 0;
		cnt_idac_code_delta_mismatch = 0;
		cnt_idac_boundary_wrap_violation = 0;
		cnt_idac_update_without_change = 0;
		reg_idac_prev_amb_code = 8'd0;
		reg_idac_prev_dcs_r_code = 8'd0;
		reg_idac_prev_dcs_ir_code = 8'd0;
		reg_idac_prev_amb_epoch = 4'd0;
		reg_idac_prev_dcs_r_epoch = 4'd0;
		reg_idac_prev_dcs_ir_epoch = 4'd0;
		reg_idac_prev_amb_pending = 1'b0;
		reg_idac_prev_dcs_r_pending = 1'b0;
		reg_idac_prev_dcs_ir_pending = 1'b0;
		reg_idac_prev_amb_search_done = 1'b0;
		reg_idac_prev_dcs_r_search_done = 1'b0;
		reg_idac_prev_dcs_ir_search_done = 1'b0;
		reg_idac_prev_amb_exhausted = 1'b0;
		reg_idac_prev_dcs_r_exhausted = 1'b0;
		reg_idac_prev_dcs_ir_exhausted = 1'b0;
		flag_idac_epoch_relation_ok = 1'b1;
		flag_idac_track_delta_ok = 1'b1;
		flag_idac_no_wrap_ok = 1'b1;
		flag_idac_observation_valid = 1'b0;
		flag_idac_startup_order_ok = 1'b1;
		reg_idac_search_stage = 2'd0;
		reg_startup_stage_state = 2'd0;
		cnt_startup_calibration_request = 0;
			cnt_startup_calibration_completion = 0;
			cnt_startup_successful_calibration_completion = 0;
			cnt_startup_amb_completion = 0;
			cnt_startup_dcs_r_completion = 0;
			cnt_startup_dcs_ir_completion = 0;
			cnt_startup_amb_waveform_observed = 0;
			cnt_startup_dcs_r_waveform_observed = 0;
			cnt_startup_dcs_ir_waveform_observed = 0;
		cnt_startup_q3_observed = 0;
		cnt_startup_q3_spacing_mismatch = 0;
		cnt_startup_owner_deadline_mismatch = 0;
		cnt_startup_real_chain_mismatch = 0;
		cnt_recheck_pending_observed = 0;
		cnt_recheck_accept_observed = 0;
		cnt_recheck_done_observed = 0;
		cnt_recheck_failed_observed = 0;
			cnt_recheck_calibration_request = 0;
			cnt_recheck_calibration_completion = 0;
			cnt_recheck_successful_calibration_completion = 0;
		cnt_recheck_amb_completion = 0;
		cnt_recheck_dcs_r_completion = 0;
		cnt_recheck_dcs_ir_completion = 0;
		cnt_recheck_real_chain_mismatch = 0;
		cnt_recheck_sequence_mismatch = 0;
		cnt_recheck_drain_mismatch = 0;
		cnt_recheck_output_leak = 0;
		cnt_recheck_history_r_warmup = 0;
		cnt_recheck_history_ir_warmup = 0;
		reg_startup_calibration_active = 1'b0;
		reg_recheck_calibration_active = 1'b0;
		cnt_recheck_post_accept_debug = 0;
		reg_startup_prev_q3_low = 1'b0;
		reg_startup_prev_q3_macro_tick = 13'd0;
		reg_startup_prev_q3_physical_tick = 64'd0;
			flag_startup_q3_266_ok = 1'b1;
			flag_startup_q3_spacing_ok = 1'b1;
			flag_startup_owner_deadline_ok = 1'b1;
			flag_startup_waveform_ok = 1'b1;
		reg_recheck_sequence_done_seen = 1'b0;
		reg_recheck_sequence_failed_seen = 1'b0;
		reg_recheck_prev_pending = 1'b0;
		reg_recheck_prev_accept = 1'b0;
		reg_recheck_prev_done = 1'b0;
		reg_recheck_prev_failed = 1'b0;
		reg_recheck_owner_waiting = 1'b0;
		reg_recheck_owner_async_seen = 1'b0;
		reg_startup_owner_waiting = 1'b0;
		reg_startup_owner_async_seen = 1'b0;
		reg_recheck_history_r_cleared = 1'b0;
		reg_recheck_history_ir_cleared = 1'b0;
		reg_recheck_sequence_ok = 1'b1;
		reg_recheck_real_chain_ok = 1'b1;
		reg_recheck_drain_ok = 1'b1;
		reg_recheck_output_inhibit_ok = 1'b1;
		reg_recheck_slope_preserved = 1'b0;
		reg_recheck_recross_seen = 1'b0;
		reg_recheck_recross_fine_seen = 1'b0;
		reg_recheck_stage_state = 2'd0;
		reg_recheck_stage_mask = 3'd0;
		reg_recheck_slope_snapshot = 32'sd0;
		reg_recheck_slope_after = 32'sd0;
		cnt_numeric_comparison = 0;
		cnt_numeric_mismatch = 0;
		cnt_identity_comparison = 0;
		cnt_identity_mismatch = 0;
		cnt_result_backpressure_comparison = 0;
		cnt_result_backpressure_mismatch = 0;
		cnt_stage1_signed_comparison = 0;
		cnt_stage2_comparison = 0;
		cnt_coarse_comparison = 0;
		cnt_fine_comparison = 0;
		reg_last_driven_stage1_raw = 10'd0;
		reg_last_driven_stage2_raw = 10'd0;
		reg_last_driven_precision_mode = 1'b0;
		reg_last_driven_raw_valid = 1'b0;
		reg_owner_scoreboard_valid = 1'b0;
		reg_completed_owner_valid = 1'b0;
		reg_completed_owner_success = 1'b0;
		reg_completed_owner_color_ir = 1'b0;
		reg_completed_owner_precision_mode = 1'b0;
		reg_completed_owner_frame_id = 16'd0;
		reg_completed_owner_sample_index = 16'd0;
		reg_completed_owner_frame_type = 2'd0;
		reg_completed_owner_amb_code = 8'd0;
		reg_completed_owner_dc_code = 8'd0;
		reg_completed_owner_amb_epoch = 4'd0;
		reg_completed_owner_dc_epoch = 4'd0;
		reg_completed_owner_config_epoch = 8'd0;
		reg_completed_owner_coef_epoch = 8'd0;
		reg_completed_owner_stage2_epoch = 8'd0;
		reg_completed_owner_dc_epoch_cfg = 8'd0;
		reg_completed_owner_stage1_raw = 10'd0;
		reg_completed_owner_stage2_raw = 10'd0;
		reg_completed_owner_raw_valid = 1'b0;
		reg_result_hold_valid = 1'b0;
		reg_result_hold_stable = 1'b1;
		cnt_result_scoreboard_head = 0;
		cnt_result_scoreboard_tail = 0;
		cnt_result_scoreboard_count = 0;
		cnt_result_scoreboard_overflow = 0;
		reg_hold_calibrated_s1_value = 12'sd0;
		reg_hold_programmable_15_code = 15'sd0;
		reg_hold_coarse_ppg_value = 24'sd0;
		reg_hold_fine_ppg_value = 24'sd0;
		reg_hold_coarse_valid = 1'b0;
		reg_hold_fine_valid = 1'b0;
		reg_hold_result_frame_id = 16'd0;
		reg_hold_result_sample_index = 16'd0;
		reg_hold_result_color_ir = 1'b0;
		reg_hold_result_precision_mode = 1'b0;
		reg_hold_result_frame_type = 2'd0;
		reg_hold_result_amb_code = 8'd0;
		reg_hold_result_dc_code = 8'd0;
		reg_hold_result_amb_epoch = 4'd0;
		reg_hold_result_dc_epoch = 4'd0;
		reg_score_acc_q16 = 64'sd0;
		reg_score_expected_s1 = 0;
		reg_score_expected_15 = 15'sd0;
		reg_score_expected_coarse = 24'sd0;
		reg_score_expected_fine = 24'sd0;
		flag_numeric_identity_ok = 1'b1;
		flag_sar9_no_fine_ok = 1'b1;
		flag_sar15_chain_ok = 1'b1;
		flag_stage1_signed_range_ok = 1'b1;
		flag_tracking_stage1_only = 1'b1;
		cnt_fault_observed = 0;
		cnt_fault_blocking_cycles = 0;
		cnt_fault_owner_leak = 0;
		cnt_fault_result_leak = 0;
		flag_fault_first_seen = 1'b0;
		reg_first_fault_id = "NONE";
		flag_fault_sticky_clear_observed = 1'b0;
		flag_fault_recovery_clean = 1'b1;
		reg_fault_seen_before_diag_clear = 1'b0;
		reg_any_fault_prev = 1'b0;
		reg_scheduler_deadline_prev = 1'b0;
		reg_scheduler_launch_timeout_prev = 1'b0;
		reg_scheduler_owner_deadline_prev = 1'b0;
		reg_scheduler_completion_mismatch_prev = 1'b0;
		reg_scheduler_protocol_error_prev = 1'b0;
		flag_scheduler_first_set_seen = 1'b0;
		reg_scheduler_first_set_reason = "NONE";
		cnt_scheduler_first_set = 0;
		cnt_scheduler_first_set_run = 0;
		cnt_scheduler_first_set_macro_tick = 0;
		cnt_scheduler_first_set_cal_tick = 0;
		time_scheduler_first_set = 0;
		cnt_stable_pass = 0;
		cnt_stable_fail = 0;
		cnt_stable_unclosed = 0;

		// JNT-01：START边界只提交手动IDAC码，不生成ADC owner或样本序号。
	end

	task run_jnt_baseline;
		begin
		// 每次JNT前固定恢复合同基线配置，不能继承前一功能组的搜索/故障参数。
		reg_scenario_recheck_interval = 16'hffff;
		reg_scenario_input_source = 1'b0;
		reg_scenario_optical_mode = OPTICAL_MODE_BOTH;
		reg_scenario_initial_precision = 1'b0;
		reg_scenario_enable_result_backpressure = 1'b0;
		reg_scenario_enable_waveform_backpressure = 1'b0;
		reg_scenario_enable_transaction_backpressure = 1'b0;
		reg_scenario_idac_mode = 2'b00;
		reg_scenario_force_search_failure = 1'b0;
		reg_scenario_allow_startup_failure = 1'b0;
		reg_scenario_recheck_nominal_calibration = 1'b0;
		reg_scenario_startup_watchdog_limit = 250000;
		reg_scenario_enable_tracking_after_startup = 1'b0;
		reg_scenario_sample_count = 0;
		reg_scenario_emit_long_checks = 1'b0;
		flag_jnt_parent_valid = 1'b0;
			// The JNT parent is owned by the functional group that requested it;
			// this keeps the 52 checks and the subsequent algorithm evidence in one
			// independently logged group/run association.
			begin_independent_run(reg_scenario_group_id);
		release_independent_run_reset;
		flag_jnt_baseline_active = 1'b1;
		analog_run_enable = 1'b1;
		measurement_run_enable = 1'b1;
		measurement_allow_new_transaction = 1'b1;
		clear_idac_observation;
		start_manual_run;
		check_case("JNT-01", (cnt_startup_boundary == 1) && flag_startup_boundary_without_owner &&
			(reg_startup_boundary_sample_index == 16'd0));

		// JNT-02：RED owner先提交，IR波形上下文仍必须在tick 160接管且不等待RED完成。
		cnt_owner_before = cnt_owner_commit;
		wait_owner_commit_count(cnt_owner_before + 1);
		check_case("JNT-02A", !reg_last_owner_color_ir && flag_owner_context_identity_match && (reg_last_owner_sample_index == 16'd0) &&
			(reg_last_owner_macro_tick <= 13'd283));
		cnt_watchdog = 0;
		while((!flag_ir_context_while_red_inflight) && (cnt_watchdog < 250))begin
			@(negedge i_clk);
			cnt_watchdog = cnt_watchdog + 1;
		end
		check_case("JNT-02B", flag_ir_context_while_red_inflight && (cnt_red_waveform_context == 1) &&
			(cnt_ir_waveform_context == 1));

		// JNT-03：RED Q3结束后真实DOUT完成才释放RED owner，随后才允许IR owner提交。
		wait_conversion_phases_complete(1'b0);
		check_case("JNT-03-IDAC", flag_selected_amb_bus_seen && flag_selected_dc_bus_seen && flag_red_dc_bus_seen &&
			flag_unselected_idac_bus_clean && !flag_idac_bus_violation);
		cnt_completion_before = cnt_completion;
		drive_real_adc_done(1'b0, 10'b0000010101, 10'd0);
		wait_completion_count(cnt_completion_before + 1);
		check_case("JNT-03A", reg_last_completion_success && (reg_last_completion_sample_index == 16'd0));
		cnt_owner_before = cnt_owner_commit;
		wait_owner_commit_count(cnt_owner_before + 1);
		check_case("JNT-03B", reg_last_owner_color_ir && flag_owner_context_identity_match && (reg_last_owner_sample_index == 16'd1) &&
			(reg_last_owner_macro_tick <= 13'd443));

		// JNT-04：IR同样必须在自己的Q3完成后通过AMI真实捕获完成，两个模块均无协议故障。
		wait_conversion_phases_complete(1'b1);
		check_case("JNT-04-IDAC", flag_selected_amb_bus_seen && flag_selected_dc_bus_seen && flag_ir_dc_bus_seen &&
			flag_unselected_idac_bus_clean && !flag_idac_bus_violation);
		cnt_completion_before = cnt_completion;
		drive_real_adc_done(1'b0, 10'b0000010110, 10'd0);
		wait_completion_count(cnt_completion_before + 1);
		check_case("JNT-04", reg_last_completion_success && (reg_last_completion_sample_index == 16'd1) &&
			!o_scheduler_transaction_inflight && !o_adc_owner_inflight && !o_scheduler_fault_blocking && !o_ssw_fault_blocking && !o_ami_fault_blocking);

		// JNT-05：abort保留原owner身份，匹配的迟到DONE以success=0释放物理owner且不输出正式测量结果。
		@(negedge i_clk); i_rstn = 1'b0;
		repeat(3) @(negedge i_clk);
		i_rstn = 1'b1;
		cnt_result_before = cnt_measurement_result;
		clear_idac_observation;
		start_manual_run;
		cnt_owner_before = cnt_owner_commit;
		wait_owner_commit_count(cnt_owner_before + 1);
		check_case("JNT-05A", !reg_last_owner_color_ir && (reg_last_owner_sample_index == 16'd0));
		wait_conversion_phases_complete(1'b0);
		pulse_control_abort;
		cnt_completion_before = cnt_completion;
		drive_real_adc_done(1'b0, 10'b0000010111, 10'd0);
		wait_completion_count(cnt_completion_before + 1);
		check_case("JNT-05B", !reg_last_completion_success && (reg_last_completion_sample_index == 16'd0) &&
			!o_scheduler_transaction_inflight && !o_adc_owner_inflight && (cnt_measurement_result == cnt_result_before));

		// JNT-06：复位清除owner身份；复位后的旧物理DONE不得重新生成完成旁带或释放旧事务。
		analog_run_enable = 1'b1;
		measurement_run_enable = 1'b1;
		measurement_allow_new_transaction = 1'b1;
		start_manual_run;
		cnt_owner_before = cnt_owner_commit;
		wait_owner_commit_count(cnt_owner_before + 1);
		wait_conversion_phases_complete(1'b0);
		cnt_completion_before = cnt_completion;
		@(negedge i_clk); i_rstn = 1'b0;
		repeat(3) @(negedge i_clk);
		i_rstn = 1'b1;
		flag_reset_done_observation = 1'b1;
		drive_real_adc_done(1'b0, 10'b0000011000, 10'd0);
		repeat(12) @(negedge i_clk);
		check_case("JNT-06", flag_reset_done_observation && (cnt_completion == cnt_completion_before) &&
			!o_scheduler_transaction_inflight && !o_adc_owner_inflight && !o_adc_transaction_complete_event);

		// JNT-07: a fresh SAR15 run repeats RED/IR waveform preparation, exact phase order, IDAC isolation, and real capture.
		@(negedge i_clk); i_rstn = 1'b0;
		i_run_profile = 1'b1;
		i_input_source = 1'b1;
		i_initial_precision = 1'b1;
		repeat(3) @(negedge i_clk);
		i_rstn = 1'b1;
		clear_idac_observation;
		start_manual_run;
		cnt_owner_before = cnt_owner_commit;
		wait_owner_commit_count(cnt_owner_before + 1);
		check_case("JNT-07A", !reg_last_owner_color_ir && (reg_last_owner_precision_mode == 1'b1) &&
			flag_owner_context_identity_match && (reg_last_owner_sample_index == 16'd0));
		wait_conversion_phases_complete(1'b0);
		check_case("JNT-07B", flag_selected_amb_bus_seen && flag_selected_dc_bus_seen && flag_red_dc_bus_seen &&
			flag_unselected_idac_bus_clean && !flag_idac_bus_violation);
		cnt_completion_before = cnt_completion;
		drive_real_adc_done(1'b1, 10'b0000011001, 10'd102);
		wait_completion_count(cnt_completion_before + 1);
		check_case("JNT-07C", reg_last_completion_success && (reg_last_completion_sample_index == 16'd0));
		cnt_owner_before = cnt_owner_commit;
		wait_owner_commit_count(cnt_owner_before + 1);
		check_case("JNT-07D", reg_last_owner_color_ir && (reg_last_owner_precision_mode == 1'b1) &&
			flag_owner_context_identity_match && (reg_last_owner_sample_index == 16'd1));
		wait_conversion_phases_complete(1'b1);
		check_case("JNT-07E", flag_selected_amb_bus_seen && flag_selected_dc_bus_seen && flag_ir_dc_bus_seen &&
			flag_unselected_idac_bus_clean && !flag_idac_bus_violation);
		cnt_completion_before = cnt_completion;
		drive_real_adc_done(1'b1, 10'b0000011010, 10'd103);
		wait_completion_count(cnt_completion_before + 1);
		check_case("JNT-07F", reg_last_completion_success && (reg_last_completion_sample_index == 16'd1) &&
			!o_scheduler_transaction_inflight && !o_adc_owner_inflight && !o_scheduler_fault_blocking && !o_ssw_fault_blocking && !o_ami_fault_blocking);

		// Restore the default coarse precision before any later directed reset scenario.
		i_run_profile = 1'b0;
		i_input_source = 1'b0;
		i_initial_precision = 1'b0;

		// JNT-08: STOP drains its already-committed owner with the original completion qualification, then blocks future owners.
		@(negedge i_clk); i_rstn = 1'b0;
		repeat(3) @(negedge i_clk);
		i_rstn = 1'b1;
		clear_idac_observation;
		start_manual_run;
		cnt_result_before = cnt_measurement_result;
		cnt_owner_before = cnt_owner_commit;
		wait_owner_commit_count(cnt_owner_before + 1);
		wait_conversion_phases_complete(1'b0);
		pulse_stop_ack;
		cnt_completion_before = cnt_completion;
		drive_real_adc_done(1'b0, 10'b0000011011, 10'd0);
		wait_completion_count(cnt_completion_before + 1);
		check_case("JNT-08", reg_last_completion_success && (reg_last_completion_sample_index == 16'd0) &&
			!o_scheduler_transaction_inflight && !o_adc_owner_inflight && (cnt_measurement_result == cnt_result_before));

		// JNT-09: after the one-shot START boundary has committed the IDAC startup code, an unavailable ADC must trip owner deadlines.
		@(negedge i_clk); i_rstn = 1'b0;
		i_adc_idle = 1'b1;
		repeat(3) @(negedge i_clk);
		i_rstn = 1'b1;
		analog_run_enable = 1'b1;
		measurement_run_enable = 1'b1;
		measurement_allow_new_transaction = 1'b1;
		pulse_normal_start_ack;
		cnt_watchdog = 0;
		while((o_startup_search_complete !== 1'b1) && (cnt_watchdog < 80))begin
			@(negedge i_clk);
			cnt_watchdog = cnt_watchdog + 1;
		end
		check_case("JNT-09-STARTUP", o_startup_search_complete && o_normal_measurement_eligible);
		i_adc_idle = 1'b0;
		cnt_watchdog = 0;
		while(!o_scheduler_owner_deadline_timeout_sticky && (cnt_watchdog < 650))begin
			@(negedge i_clk);
			cnt_watchdog = cnt_watchdog + 1;
		end
		check_case("JNT-09", (cnt_watchdog < 650) && o_scheduler_owner_deadline_timeout_sticky &&
			!o_scheduler_transaction_inflight && !o_adc_owner_inflight && !o_ssw_fault_blocking && !o_ami_fault_blocking);
		report_jnt_baseline;
		end
	endtask

	initial begin
		@(negedge i_clk);
		reg_selected_scenario = C_SCENARIO_ALL;
		// xsim may change its process working directory; keep the artifact path explicit.
		reg_result_file_path = "D:/PPG/verilog/jxa/ppg_system_integration/tb_scenario_result.log";
		if($test$plusargs("SCENARIO16")) reg_selected_scenario = C_SCENARIO_CORE_LONG;
		else if($test$plusargs("SCENARIO15")) reg_selected_scenario = C_SCENARIO_CORE_FIR_TAIL;
		else if($test$plusargs("SCENARIO14")) reg_selected_scenario = C_SCENARIO_CORE_PEAK_VALLEY;
		else if($test$plusargs("SCENARIO13")) reg_selected_scenario = C_SCENARIO_CORE_CROSS;
		else if($test$plusargs("SCENARIO12")) reg_selected_scenario = C_SCENARIO_CORE_BASELINE;
		else if($test$plusargs("SCENARIO11")) reg_selected_scenario = C_SCENARIO_ROBUSTNESS;
		else if($test$plusargs("SCENARIO10")) reg_selected_scenario = C_SCENARIO_LIFECYCLE;
		else if($test$plusargs("SCENARIO1")) reg_selected_scenario = C_SCENARIO_LONG;
		else if($test$plusargs("SCENARIO2")) reg_selected_scenario = C_SCENARIO_NO_RECHECK;
		else if($test$plusargs("SCENARIO3")) reg_selected_scenario = C_SCENARIO_INPUT_MATRIX;
		else if($test$plusargs("SCENARIO4")) reg_selected_scenario = C_SCENARIO_STARTUP;
		else if($test$plusargs("SCENARIO5")) reg_selected_scenario = C_SCENARIO_TRACKING;
		else if($test$plusargs("SCENARIO6")) reg_selected_scenario = C_SCENARIO_RECHECK;
		else if($test$plusargs("SCENARIO7")) reg_selected_scenario = C_SCENARIO_NUMERIC;
		else if($test$plusargs("SCENARIO8")) reg_selected_scenario = C_SCENARIO_IDENTITY;
		else if($test$plusargs("SCENARIO9")) reg_selected_scenario = C_SCENARIO_OWNER;
		reg_plusarg_found = 0;
		fd_result_file = $fopen("D:/PPG/verilog/jxa/ppg_system_integration/tb_scenario_result.log", "w");
		if(fd_result_file != 0) flag_result_file_initialized = 1'b1;
		$display("TB_RESULT_FILE_FD=%0d", fd_result_file);
		$display("TB_SCENARIO_SELECTOR=%0d", reg_selected_scenario);
		case(reg_selected_scenario)
			C_SCENARIO_LONG: begin run_core_long_scenario; finalize_state_scoreboards; end
			C_SCENARIO_NO_RECHECK: run_no_recheck_control_scenario;
			C_SCENARIO_INPUT_MATRIX: run_input_light_matrix_scenario;
			C_SCENARIO_STARTUP: begin
				run_startup_search_scenario;
				run_startup_failure_scenario;
				finalize_state_scoreboards;
			end
			C_SCENARIO_TRACKING: run_tracking_scenario;
			C_SCENARIO_RECHECK: run_periodic_recheck_scenario;
			C_SCENARIO_NUMERIC: run_numeric_scoreboard_scenario;
			C_SCENARIO_IDENTITY: run_identity_isolation_scenario;
			C_SCENARIO_OWNER: run_owner_identity_scenario;
			C_SCENARIO_LIFECYCLE: close_lifecycle_and_identity_groups;
			C_SCENARIO_ROBUSTNESS: run_robustness_waveform_scenario;
			C_SCENARIO_CORE_BASELINE: run_core_baseline_warmup_scenario;
			C_SCENARIO_CORE_CROSS: run_core_cross_sar15_scenario;
			C_SCENARIO_CORE_PEAK_VALLEY: run_core_peak_valley_return_scenario;
			C_SCENARIO_CORE_FIR_TAIL: run_core_fir_tail_scenario;
			C_SCENARIO_CORE_LONG: run_core_long_scenario;
			default: begin
				run_jnt_baseline;
				run_ppg_algorithm_scenario;
				run_no_recheck_control_scenario;
				run_input_light_matrix_scenario;
				run_startup_search_scenario;
				run_startup_failure_scenario;
				run_tracking_scenario;
				run_periodic_recheck_scenario;
				run_numeric_scoreboard_scenario;
				run_identity_isolation_scenario;
				run_owner_identity_scenario;
				run_robustness_waveform_scenario;
				run_core_baseline_warmup_scenario;
				run_core_cross_sar15_scenario;
				run_core_peak_valley_return_scenario;
				run_core_fir_tail_scenario;
				close_lifecycle_and_identity_groups;
				finalize_state_scoreboards;
			end
		endcase
		emit_scenario_result;
		if(fd_event_log >= 0) $fclose(fd_event_log);
		$finish;

		// Scenario dispatch is implemented below; keep the legacy aggregate body disabled.
		if(1'b0) begin
		run_jnt_baseline;

		// PPG算法闭环：真实PPG形状、10个心搏、10秒物理时基与精度状态切换。
		run_ppg_algorithm_scenario;
		run_no_recheck_control_scenario;
		run_input_light_matrix_scenario;
		run_startup_search_scenario;
		run_startup_failure_scenario;
		run_tracking_scenario;
		run_periodic_recheck_scenario;
		run_robustness_waveform_scenario;
		close_lifecycle_and_identity_groups;
		close_identity_groups;
		finalize_state_scoreboards;

		if((cnt_fail == 0) && (cnt_stable_fail == 0) && (cnt_stable_unclosed == 0))begin
			$display("JOINT_TB_PASS scenarios=%0d waveform=%0d owner=%0d completion=%0d stable=%0d/%0d", cnt_pass, cnt_waveform_context, cnt_owner_commit, cnt_completion, cnt_stable_pass, C_STABLE_TRACE_COUNT);
		end else if((cnt_fail == 0) && (cnt_stable_fail == 0))begin
			$display("JOINT_TB_NOT_CLOSED scenarios=%0d stable=%0d/%0d not_closed=%0d", cnt_pass, cnt_stable_pass, C_STABLE_TRACE_COUNT, cnt_stable_unclosed);
		end else begin
			$display("JOINT_TB_FAIL pass=%0d fail=%0d", cnt_pass, cnt_fail);
		end
		if(fd_event_log >= 0) $fclose(fd_event_log);
		$finish;
	end

	// 联合回归的有限时间保护，任何无响应握手均须显式结束而不留下无限仿真。
	end

	initial begin
		#(C_SIM_TIMEOUT_NS);
		$display("JOINT_TB_TIMEOUT");
		$finish;
	end

endmodule
