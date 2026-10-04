`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/10
// Design Name:        PPG Dynamic Baseline Cross Detector Testbench
// Module Name:        tb_ppg_dynamic_baseline_cross_detector
// Description:        Self-checking BSL-01 through BSL-39 verification
// Simulations:        TestBench/Vivado/2022.2/ppg_dynamic_baseline_cross_detector
//
// Referrences:        PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_dynamic_baseline_cross_detector.v
//
// Version:            V1.1
// Revision Date:      2026/08/27
// History:
//    Time               Version       Revised by            Contents
// 2026/08/10            V1.0          Erie                  Create file.
// 2026/08/27            V1.1          Erie                  Resync with DUT V1.1~V1.3: remove obsolete i_stop_ack_event/i_control_abort_event ports; wire the new PWI-broadcast i_detection_discard group, i_run_generation and o_local_empty per PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md section 14.1; wire i_peak_valley_config_valid (V5 gate, default driven high to preserve pre-existing BSL/OPT case behavior) per section 14.4. Replaced the two direct-clear event pulses with a shared pulse_detection_discard task carrying DISCARD_STOP/DISCARD_ABORT reason codes. No test case logic, expected value, or case count changed. Verified with real iverilog: compiles -Wall clean and vvp reproduces ALL BSL-01 THROUGH BSL-39, OPT-01 THROUGH OPT-24 AND OPTC-01 THROUGH OPTC-02 PASS count=65.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月10日
// 设计名称:           PPG动态基线相交检测器自检仿真
// 模块名称:           tb_ppg_dynamic_baseline_cross_detector
// 模块说明:           覆盖冻结合同BSL-01至BSL-39
// 仿真工程:           TestBench/Vivado/2022.2/ppg_dynamic_baseline_cross_detector
//
// 参考资料:           PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_dynamic_baseline_cross_detector.v
//
// 当前版本:           V1.1
// 修订日期:           2026年08月27日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月10日        V1.0          Erie                  创建文件
// 2026年08月27日        V1.1          Erie                  与DUT V1.1~V1.3重新同步：删除已废弃的i_stop_ack_event/i_control_abort_event端口；按合同14.1节接入新增的PWI广播i_detection_discard组、i_run_generation和o_local_empty；按合同14.4节接入i_peak_valley_config_valid（V5门控，默认拉高以保持既有BSL/OPT用例行为不变）。原来的两处直接清除事件脉冲统一改为携带DISCARD_STOP/DISCARD_ABORT原因码的pulse_detection_discard任务。未改动任何用例逻辑、预期值或用例总数。真实iverilog核实：-Wall编译干净，vvp仿真复现ALL BSL-01 THROUGH BSL-39, OPT-01 THROUGH OPT-24 AND OPTC-01 THROUGH OPTC-02 PASS count=65。

// 对动态基线数学、相交握手、自适应闭环和故障恢复执行28项定向自检
module tb_C_baseline;

	//-------------配置参数区域-------------//
	// 仿真时钟仅保持同步关系，功能判断不依赖实际2 MHz周期长度
	localparam integer C_CLK_PERIOD = 32'd10;                            // 主时钟完整周期为10 ns
	localparam signed [31:0]C_FIXED_SLOPE = -32'sd65536;                // 默认每400 Hz帧下降1个统一PPG码
	localparam signed [31:0]C_SLOPE_MIN = -32'sd262144;                 // 默认最负斜率为每帧下降4码
	localparam signed [31:0]C_SLOPE_MAX = -32'sd8192;                   // 默认近零边界为每帧下降0.125码
	localparam [15:0]C_ALPHA_Q15 = 16'h199a;                            // 默认alpha约为0.20
	localparam [15:0]C_BETA_Q15 = 16'h2000;                             // 默认beta严格等于0.25
	localparam [15:0]C_ADJUST_Q15 = 16'h0800;                           // 默认时刻调整比例严格等于1/16
	localparam [3:0]ST_IDLE = 4'd0;                                     // 阶段B空闲状态编码
	localparam [3:0]ST_CAPTURE = 4'd1;                                  // 阶段B波峰快照状态编码
	localparam [3:0]ST_MUL_ALPHA = 4'd2;                                // 阶段B alpha乘法状态编码
	localparam [3:0]ST_PREPARE_DIVIDE = 4'd3;                           // 阶段B除法准备状态编码
	localparam [3:0]ST_DIVIDE = 4'd4;                                   // 阶段B固定42周期除法状态编码
	localparam [3:0]ST_BUILD_SLOPE_BASE = 4'd5;                         // 阶段B基础斜率构建状态编码
	localparam [3:0]ST_MUL_BETA = 4'd6;                                 // 阶段B beta乘法状态编码
	localparam [3:0]ST_ROUND_BETA = 4'd7;                               // 阶段B beta舍入状态编码
	localparam [3:0]ST_MUL_ADJUST = 4'd8;                               // 阶段B调整乘法状态编码
	localparam [3:0]ST_ROUND_ADJUST = 4'd9;                             // 阶段B调整舍入状态编码
	localparam [3:0]ST_CLAMP = 4'd10;                                   // 阶段B斜率限幅状态编码
	localparam [3:0]ST_WAIT_PEAK_COMMIT = 4'd11;                        // 阶段B原子提交等待状态编码
	localparam [3:0]ST_TIMEOUT_FALLBACK = 4'd12;                        // 阶段B异常固定斜率回退状态编码
	localparam [1:0]DISCARD_REASON_STOP = 2'b00;                        // PWI广播discard的STOP排空原因码
	localparam [1:0]DISCARD_REASON_ABORT = 2'b01;                       // PWI广播discard的abort撤销原因码
	localparam [7:0]C_RUN_GENERATION_ACTIVE = 8'd1;                     // 全部用例固定使用的当前RUN代际

	//--------------寄存器信号--------------//
	// 全部DUT输入由测试任务在时钟下降沿设置并保持至握手
	reg i_clk;                                                          // 仿真主时钟
	reg i_rstn;                                                         // 低有效异步复位
	reg i_run_enable;                                                   // RUN检测使能
	reg i_start_ack_event;                                              // 新RUN接受事件
	reg i_detection_discard_event;                                      // PWI广播的AMI注册式代际清空事件
	reg [1:0]i_detection_discard_reason;                                // 清空原因分类：STOP排空/abort撤销/系统故障
	reg i_detection_discard_identity_valid;                             // 触发事务身份是否可信
	reg i_detection_discard_sample_valid;                               // 触发事务的独立样本资格快照
	reg [15:0]i_detection_discard_frame_id;                             // 触发事务帧号，仅诊断用途
	reg [15:0]i_detection_discard_sample_index;                         // 触发事务序号，仅诊断用途
	reg i_detection_discard_color_ir;                                   // 触发事务颜色，仅诊断用途
	reg [1:0]i_detection_discard_frame_type;                            // 触发事务类型，仅诊断用途
	reg i_detection_discard_precision;                                  // 触发事务精度，仅诊断用途
	reg [7:0]i_detection_discard_config_epoch;                          // 触发事务ACTIVE版本，仅诊断用途
	reg [7:0]i_detection_discard_coef_epoch;                            // 触发事务Stage1系数版本，仅诊断用途
	reg [7:0]i_detection_discard_dc_recovery_epoch;                     // 触发事务DC恢复版本，仅诊断用途
	reg [3:0]i_detection_discard_amb_code_epoch;                        // 触发事务环境光抵消码提交版本，仅诊断用途
	reg [3:0]i_detection_discard_dc_code_epoch;                         // 触发事务颜色DC码版本，仅诊断用途
	reg [7:0]i_detection_discard_run_generation;                        // 本次清空目标RUN代际
	reg [7:0]i_run_generation;                                          // PWI层级扇出的当前RUN代际实时快照
	reg i_peak_valley_config_valid;                                     // PWI经AMI注册转发的V5正式检测资格
	reg i_fine_window_active;                                           // 15-bit窗口活动标志
	reg i_reacquire_request_event;                                      // 异常返回后的重新获取事件
	reg i_recheck_accept_event;                                         // 重检安全接管事件
	reg i_recheck_busy;                                                 // 重检禁止窗口状态
	reg i_recheck_done_event;                                           // 重检结束事件
	reg i_recheck_success;                                              // 重检整体成功资格
	reg i_result_valid;                                                 // FIR事务valid
	reg signed [23:0]i_filtered_ppg_value;                              // 当前粗FIR统一PPG码
	reg i_detection_qualified;                                         // 当前FIR窗口正式资格
	reg i_window_saturation_low;                                        // 输入窗口负端饱和
	reg i_window_saturation_high;                                       // 输入窗口正端饱和
	reg i_fir_saturation_low;                                           // FIR结果负端饱和
	reg i_fir_saturation_high;                                          // FIR结果正端饱和
	reg [7:0]i_config_epoch;                                            // FIR中心ACTIVE版本
	reg [7:0]i_coef_epoch;                                              // FIR中心Stage1版本
	reg [7:0]i_dc_recovery_coef_epoch;                                  // FIR中心DC恢复版本
	reg i_precision_mode;                                               // FIR中心精度模式
	reg [15:0]i_frame_id;                                               // FIR中心400 Hz帧号
	reg [15:0]i_sample_index;                                           // FIR中心事务序号
	reg i_color_ir;                                                     // 当前FIR事务颜色
	reg [1:0]i_frame_type;                                              // 当前事务类别编码
	reg i_peak_valid;                                                   // 波峰事件valid
	reg signed [23:0]i_peak_value;                                      // 可靠码值波峰
	reg [15:0]i_peak_frame_id;                                          // 波峰实际中心帧号
	reg [15:0]i_peak_sample_index;                                      // 波峰中心事务号
	reg [7:0]i_peak_config_epoch;                                       // 波峰ACTIVE版本
	reg [7:0]i_peak_coef_epoch;                                         // 波峰Stage1版本
	reg [7:0]i_peak_dc_recovery_coef_epoch;                             // 波峰DC恢复版本
	reg i_valley_valid;                                                 // 波谷事件valid
	reg signed [23:0]i_valley_value;                                    // 可靠码值波谷
	reg [15:0]i_valley_frame_id;                                        // 波谷实际中心帧号
	reg [15:0]i_valley_sample_index;                                    // 波谷中心事务号
	reg [7:0]i_valley_config_epoch;                                     // 波谷ACTIVE版本
	reg [7:0]i_valley_coef_epoch;                                       // 波谷Stage1版本
	reg [7:0]i_valley_dc_recovery_coef_epoch;                           // 波谷DC恢复版本
	reg i_slope_mode;                                                   // 固定或自适应斜率选择
	reg signed [31:0]i_fixed_slope_q16;                                 // ACTIVE固定斜率
	reg [15:0]i_alpha_q15;                                              // ACTIVE幅度比例
	reg [15:0]i_beta_q15;                                               // ACTIVE平滑比例
	reg [15:0]i_timing_adjust_ratio_q15;                                // ACTIVE时刻修正比例
	reg signed [31:0]i_slope_min_q16;                                   // ACTIVE最负斜率边界
	reg signed [31:0]i_slope_max_q16;                                   // ACTIVE近零斜率边界
	reg signed [31:0]i_baseline_delta_q16;                              // ACTIVE基线起点偏置
	reg [31:0]i_cross_hysteresis_q16;                                   // ACTIVE对称迟滞
	reg [15:0]i_lead_min_frames;                                        // 提前量合格下界
	reg [15:0]i_lead_max_frames;                                        // 提前量合格上界
	reg [3:0]i_cross_confirm_count;                                     // 连续确认点数
	reg [3:0]i_no_cross_limit;                                          // 无相交重新获取限制
	reg i_cross_ready;                                                  // 下游相交事件ready

	// 仿真统计变量只用于生成明确PASS/FAIL结论
	integer cnt_pass;                                                    // 已通过BSL用例数量
	integer cnt_fail;                                                    // 已失败检查数量
	integer cnt_eqv_cycle;                                               // 阶段A逐位等价追踪周期序号
	integer reg_hold_frame;                                              // 反压保持帧号快照
	integer reg_hold_sample;                                             // 反压保持事务号快照
	integer cnt_divide_cycles;                                          // 阶段B实际DIVIDE状态周期计数
	integer cnt_wait_guard;                                             // 状态等待任务的有限循环保护
	integer cnt_state_target;                                           // STOP、abort和重检逐状态循环索引
	integer cnt_random_vector;                                          // 阶段B顺序商随机差分向量编号
	integer cnt_result_transfer_seen;                                   // 阶段B反压场景实际消费FIR事务次数
	integer cnt_valley_transfer_seen;                                   // 阶段B反压场景实际消费波谷事务次数
	integer cnt_result_transfer_before;                                 // busy保持测试开始前FIR握手计数快照
	integer cnt_valley_transfer_before;                                 // busy保持测试开始前波谷握手计数快照
	integer reg_random_seed;                                            // 确定性随机序列固定种子
	reg [31:0]reg_random_word;                                         // 随机幅度和周期字段原始字
	reg [63:0]reg_golden_numerator;                                    // 测试台组合黄金公式的完整正分子
	reg [63:0]reg_golden_quotient;                                     // 测试台允许使用除法得到的参考商
	reg [41:0]reg_first_quotient;                                      // 连续周期隔离检查保存的首个顺序商
	reg flag_stage_check_ok;                                           // 逐状态撤销循环的累计布尔结果
	reg signed [47:0]reg_hold_baseline;                                  // 反压保持基线快照
	reg signed [31:0]reg_slope_snapshot;                                // 普通模式切换前斜率快照
	reg reg_baseline_snapshot;                                          // 普通模式切换前基线资格
	reg flag_eqv_started;                                                // 首次完成复位后允许输出等价追踪
	reg flag_divide_seen;                                                // 即时路径检查是否错误进入顺序除法
	reg flag_random_divider_ok;                                         // 确定性随机顺序商差分累计结果
	reg flag_shared_multiplier_ok;                                      // 阶段C三种操作数和乘积路由累计正确性
	reg flag_shared_idle_zero_ok;                                       // 非乘法状态共享输入及结果保持零值
	reg flag_shared_alpha_seen;                                         // 仿真已经覆盖alpha共享乘法状态
	reg flag_shared_beta_seen;                                          // 仿真已经覆盖beta共享乘法状态
	reg flag_shared_adjust_seen;                                        // 仿真已经覆盖adjust共享乘法状态

	//---------------其他信号---------------//
	// DUT输出使用wire连接以便任务在任意仿真时刻检查
	wire o_local_empty;                                                  // 本模块无pending、无输出且无在途算术
	wire o_result_ready;                                                 // FIR分支ready
	wire o_peak_ready;                                                   // 波峰事件ready
	wire o_valley_ready;                                                 // 波谷事件ready
	wire o_cross_valid;                                                  // 相交事件valid
	wire [15:0]o_cross_frame_id;                                         // 相交首次越过帧号
	wire [15:0]o_cross_sample_index;                                     // 相交首次越过事务号
	wire o_cross_time_unknown;                                           // 相交精确时刻未知属性
	wire [7:0]o_cross_config_epoch;                                      // 相交ACTIVE版本
	wire [7:0]o_cross_coef_epoch;                                        // 相交Stage1版本
	wire [7:0]o_cross_dc_recovery_coef_epoch;                            // 相交DC恢复版本
	wire signed [31:0]o_cross_slope_q16;                                // 相交活动斜率
	wire signed [47:0]o_cross_baseline_q16;                              // 相交诊断基线
	wire o_baseline_valid;                                               // 当前动态基线资格
	wire o_adaptive_slope_valid;                                         // 自适应斜率资格
	wire signed [31:0]o_slope_current_q16;                              // 当前活动斜率
	wire signed [31:0]o_slope_base_q16;                                 // 最近基础斜率
	wire [15:0]o_last_lead_frames;                                       // 最近相交提前量
	wire [3:0]o_no_cross_count;                                          // 连续无相交周期计数
	wire o_reacquire_active;                                             // 锚点重新获取状态
	wire o_slope_saturation_min;                                         // 最负斜率限幅诊断
	wire o_slope_saturation_max;                                         // 近零斜率限幅诊断
	wire o_baseline_saturation_low;                                      // 基线低端饱和诊断
	wire o_baseline_saturation_high;                                     // 基线高端饱和诊断
	wire o_protocol_error_sticky;                                        // 运行协议错误累计标志

	//-----------主要任务处理区域-----------//
	// 主时钟持续翻转，所有激励在下降沿改变以避开采样竞争
	always #(C_CLK_PERIOD / 2) i_clk = ~i_clk;                           // 生成规则仿真时钟

	// 阶段A在安全下降沿记录全部外部可见状态，供优化前后逐行逐位比较
	always@(negedge i_clk)begin
		if(i_rstn == 1'b1 && flag_eqv_started == 1'b1)begin
			$display("EQV %0d %h", cnt_eqv_cycle, {o_result_ready, o_peak_ready, o_valley_ready, o_cross_valid, o_cross_frame_id, o_cross_sample_index, o_cross_time_unknown, o_cross_config_epoch, o_cross_coef_epoch, o_cross_dc_recovery_coef_epoch, o_cross_slope_q16, o_cross_baseline_q16, o_baseline_valid, o_adaptive_slope_valid, o_slope_current_q16, o_slope_base_q16, o_last_lead_frames, o_no_cross_count, o_reacquire_active, o_slope_saturation_min, o_slope_saturation_max, o_baseline_saturation_low, o_baseline_saturation_high, o_protocol_error_sticky, i_precision_mode}); // 固定字段顺序打包形成逐位黄金记录
			cnt_eqv_cycle = cnt_eqv_cycle + 1;                               // 每个非复位观察周期只生成一条记录
		end
	end

	// 阶段B反压测试分别统计FIR和波谷握手，确认保持事务只消费一次
	always@(posedge i_clk)begin
		if(i_rstn == 1'b0)begin
			cnt_result_transfer_seen <= 0;                                  // 异步复位场景后的统计从零开始
			cnt_valley_transfer_seen <= 0;                                  // 清除波谷实际消费次数
		end else begin
			if(i_result_valid && o_result_ready)begin
				cnt_result_transfer_seen <= cnt_result_transfer_seen + 1;       // 记录一笔真实FIR握手
			end
			if(i_valley_valid && o_valley_ready)begin
				cnt_valley_transfer_seen <= cnt_valley_transfer_seen + 1;       // 记录一笔真实波谷握手
			end
		end
	end

	// 阶段C监视器逐状态核对唯一33乘17乘法器的操作数选择和空闲静默
	always@(posedge i_clk)begin
		if(i_rstn == 1'b1 && flag_eqv_started == 1'b1)begin
			case(ppg_dynamic_baseline_cross_detector_Inst_dut.state_current)
				ST_MUL_ALPHA:begin
					flag_shared_alpha_seen = 1'b1; // 记录正幅度与alpha操作已经执行
					if((ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_operand_a !== $signed({8'd0, ppg_dynamic_baseline_cross_detector_Inst_dut.reg_arith_cycle_amplitude})) || (ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_operand_b !== $signed({1'b0, ppg_dynamic_baseline_cross_detector_Inst_dut.reg_arith_alpha_q15})) || (ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_product !== ($signed({8'd0, ppg_dynamic_baseline_cross_detector_Inst_dut.reg_arith_cycle_amplitude}) * $signed({1'b0, ppg_dynamic_baseline_cross_detector_Inst_dut.reg_arith_alpha_q15}))))begin
						flag_shared_multiplier_ok = 1'b0; // alpha路由或完整乘积任一位错误即保持失败
					end
				end
				ST_MUL_BETA:begin
					flag_shared_beta_seen = 1'b1; // 记录signed平滑差与beta操作已经执行
					if((ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_operand_a !== $signed(ppg_dynamic_baseline_cross_detector_Inst_dut.enc_arith_smooth_difference)) || (ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_operand_b !== $signed({1'b0, ppg_dynamic_baseline_cross_detector_Inst_dut.reg_arith_beta_q15})) || (ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_product !== ($signed(ppg_dynamic_baseline_cross_detector_Inst_dut.enc_arith_smooth_difference) * $signed({1'b0, ppg_dynamic_baseline_cross_detector_Inst_dut.reg_arith_beta_q15}))))begin
						flag_shared_multiplier_ok = 1'b0; // beta负数符号扩展或乘积不一致时锁存失败
					end
				end
				ST_MUL_ADJUST:begin
					flag_shared_adjust_seen = 1'b1; // 记录基础斜率幅值与调整比例操作已经执行
					if((ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_operand_a !== $signed({1'b0, ppg_dynamic_baseline_cross_detector_Inst_dut.dec_arith_base_abs})) || (ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_operand_b !== $signed({1'b0, ppg_dynamic_baseline_cross_detector_Inst_dut.reg_arith_adjust_ratio_q15})) || (ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_product !== ($signed({1'b0, ppg_dynamic_baseline_cross_detector_Inst_dut.dec_arith_base_abs}) * $signed({1'b0, ppg_dynamic_baseline_cross_detector_Inst_dut.reg_arith_adjust_ratio_q15}))))begin
						flag_shared_multiplier_ok = 1'b0; // adjust补零扩展或正乘积异常时保持失败
					end
				end
				default:begin
					if((ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_operand_a !== 33'sd0) || (ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_operand_b !== 17'sd0) || (ppg_dynamic_baseline_cross_detector_Inst_dut.dec_shared_product !== 50'sd0))begin
						flag_shared_idle_zero_ok = 1'b0; // 非三个乘法状态禁止共享算术组合节点无效翻转
					end
				end
			endcase
		end
	end

	// 统一初始化全部输入，防止未驱动X值掩盖真实失败
	task initialize_inputs;
	begin
		i_run_enable = 1'b0;                                               // 初始不处于RUN
		i_start_ack_event = 1'b0;                                          // 清除START事件
		i_detection_discard_event = 1'b0;                                  // 清除代际清空事件
		i_detection_discard_reason = DISCARD_REASON_STOP;                  // 默认原因码归入STOP排空
		i_detection_discard_identity_valid = 1'b1;                         // 默认触发身份可信
		i_detection_discard_sample_valid = 1'b0;                           // 默认独立样本资格无效
		i_detection_discard_frame_id = 16'd0;                              // 初始化诊断帧号
		i_detection_discard_sample_index = 16'd0;                          // 初始化诊断事务号
		i_detection_discard_color_ir = 1'b0;                               // 默认诊断颜色为RED
		i_detection_discard_frame_type = 2'b10;                            // 默认诊断类别使用NORMAL编码
		i_detection_discard_precision = 1'b0;                              // 默认诊断精度为9-bit
		i_detection_discard_config_epoch = 8'd1;                           // 默认诊断ACTIVE版本
		i_detection_discard_coef_epoch = 8'd2;                             // 默认诊断Stage1版本
		i_detection_discard_dc_recovery_epoch = 8'd3;                      // 默认诊断DC恢复版本
		i_detection_discard_amb_code_epoch = 4'd0;                         // 默认诊断AMB码版本
		i_detection_discard_dc_code_epoch = 4'd0;                          // 默认诊断DC码版本
		i_detection_discard_run_generation = C_RUN_GENERATION_ACTIVE;      // 默认清空目标对齐当前代际
		i_run_generation = C_RUN_GENERATION_ACTIVE;                        // 固定当前RUN代际快照
		i_peak_valley_config_valid = 1'b1;                                 // 默认开放V5正式检测资格以保留既有用例行为
		i_fine_window_active = 1'b0;                                       // 初始选择9-bit粗模式
		i_reacquire_request_event = 1'b0;                                  // 清除异常返回重获事件
		i_recheck_accept_event = 1'b0;                                     // 清除重检接管事件
		i_recheck_busy = 1'b0;                                             // 初始没有重检禁止窗口
		i_recheck_done_event = 1'b0;                                       // 清除重检结束事件
		i_recheck_success = 1'b0;                                          // 初始没有成功资格
		i_result_valid = 1'b0;                                             // FIR入口初始无事务
		i_filtered_ppg_value = 24'sd0;                                     // 初始化FIR码值
		i_detection_qualified = 1'b1;                                      // 默认事务具备正式资格
		i_window_saturation_low = 1'b0;                                    // 默认窗口无负端饱和
		i_window_saturation_high = 1'b0;                                   // 默认窗口无正端饱和
		i_fir_saturation_low = 1'b0;                                       // 默认FIR无负端饱和
		i_fir_saturation_high = 1'b0;                                      // 默认FIR无正端饱和
		i_config_epoch = 8'd1;                                             // 默认ACTIVE版本为1
		i_coef_epoch = 8'd2;                                               // 默认Stage1版本为2
		i_dc_recovery_coef_epoch = 8'd3;                                   // 默认DC恢复版本为3
		i_precision_mode = 1'b0;                                           // 默认样本采用9-bit模式
		i_frame_id = 16'd0;                                                // 初始化中心帧号
		i_sample_index = 16'd0;                                            // 初始化事务号
		i_color_ir = 1'b0;                                                 // 默认事务属于RED
		i_frame_type = 2'b10;                                              // 默认使用NORMAL类别
		i_peak_valid = 1'b0;                                               // 波峰入口初始空闲
		i_peak_value = 24'sd0;                                             // 初始化波峰码值
		i_peak_frame_id = 16'd0;                                           // 初始化波峰帧号
		i_peak_sample_index = 16'd0;                                       // 初始化波峰事务号
		i_peak_config_epoch = 8'd1;                                        // 默认波峰ACTIVE版本
		i_peak_coef_epoch = 8'd2;                                          // 默认波峰Stage1版本
		i_peak_dc_recovery_coef_epoch = 8'd3;                              // 默认波峰DC恢复版本
		i_valley_valid = 1'b0;                                             // 波谷入口初始空闲
		i_valley_value = 24'sd0;                                           // 初始化波谷码值
		i_valley_frame_id = 16'd0;                                         // 初始化波谷帧号
		i_valley_sample_index = 16'd0;                                     // 初始化波谷事务号
		i_valley_config_epoch = 8'd1;                                      // 默认波谷ACTIVE版本
		i_valley_coef_epoch = 8'd2;                                        // 默认波谷Stage1版本
		i_valley_dc_recovery_coef_epoch = 8'd3;                            // 默认波谷DC恢复版本
		i_slope_mode = 1'b1;                                               // 默认启用自适应斜率
		i_fixed_slope_q16 = C_FIXED_SLOPE;                                 // 装载每帧下降1码的种子
		i_alpha_q15 = C_ALPHA_Q15;                                         // 装载20%幅度比例
		i_beta_q15 = C_BETA_Q15;                                           // 装载25%平滑比例
		i_timing_adjust_ratio_q15 = C_ADJUST_Q15;                          // 装载1/16时刻修正比例
		i_slope_min_q16 = C_SLOPE_MIN;                                     // 装载默认最负边界
		i_slope_max_q16 = C_SLOPE_MAX;                                     // 装载默认近零边界
		i_baseline_delta_q16 = 32'sd0;                                     // 默认基线通过波峰锚点
		i_cross_hysteresis_q16 = 32'd0;                                    // 定向测试默认关闭迟滞幅值
		i_lead_min_frames = 16'd17;                                        // 默认合格提前量下界
		i_lead_max_frames = 16'd19;                                        // 默认合格提前量上界
		i_cross_confirm_count = 4'd3;                                      // 默认首次越过加两个确认点
		i_no_cross_limit = 4'd2;                                           // 默认两个无相交周期后重获
		i_cross_ready = 1'b1;                                              // 默认下游立即消费事件
	end
	endtask

	// 非阻塞波峰驱动用于观察阶段B内部状态和有界反压
	task begin_peak_hold;
		input signed [23:0]value;
		input [15:0]frame_id;
		input [7:0]epoch;
	begin
		@(negedge i_clk);                                                   // 在下降沿放置待捕获波峰
		i_peak_value = value;                                              // 驱动pending码值波峰
		i_peak_frame_id = frame_id;                                        // 驱动pending实际帧号
		i_peak_sample_index = frame_id + 16'd1000;                          // 生成阶段B可追踪事务号
		i_peak_config_epoch = epoch;                                       // 设置pending ACTIVE版本
		i_peak_coef_epoch = 8'd2;                                          // 使用统一Stage1版本
		i_peak_dc_recovery_coef_epoch = 8'd3;                              // 使用统一DC恢复版本
		i_peak_valid = 1'b1;                                               // 持续声明波峰直到正式ready
	end
	endtask

	// 等待原子提交状态并在握手后的下降沿撤销波峰valid
	task finish_peak_hold;
	begin
		cnt_wait_guard = 0;                                                // 初始化有界等待保护
		while(o_peak_ready !== 1'b1 && cnt_wait_guard < 200)begin
			@(negedge i_clk);                                                // 每个周期观察是否进入WAIT提交状态
			cnt_wait_guard = cnt_wait_guard + 1;                             // 防止RTL错误造成任务永久阻塞
		end
		if(o_peak_ready !== 1'b1)begin
			$display("FAIL PHASE_B peak ready timeout state=%0d", ppg_dynamic_baseline_cross_detector_Inst_dut.state_current); // 报告未解除反压的状态
			$fatal(1);                                                       // 有界反压超时属于阻断错误
		end
		@(negedge i_clk);                                                   // 中间上升沿提交pending波峰与算术结果
		i_peak_valid = 1'b0;                                               // 握手完成后撤销事件所有权
	end
	endtask

	// 等待指定阶段B状态并以200周期上限防止测试本身挂起
	task wait_arithmetic_state;
		input [3:0]target_state;
	begin
		cnt_wait_guard = 0;                                                // 从当前状态开始有界轮询
		while(ppg_dynamic_baseline_cross_detector_Inst_dut.state_current != target_state && cnt_wait_guard < 200)begin
			@(negedge i_clk);                                                // 在稳定半周期边界观察FSM状态
			cnt_wait_guard = cnt_wait_guard + 1;                             // 累计等待周期用于超时诊断
		end
		if(ppg_dynamic_baseline_cross_detector_Inst_dut.state_current != target_state)begin
			$display("FAIL PHASE_B state timeout target=%0d current=%0d", target_state, ppg_dynamic_baseline_cross_detector_Inst_dut.state_current); // 报告不可达状态
			$fatal(1);                                                       // 冻结状态不可达时立即阻断
		end
	end
	endtask

	// 建立一个无相交但尚未达到重获限制的完整自适应周期
	task prepare_adaptive_peak_hold;
		input signed [23:0]peak_value;
		input signed [23:0]valley_value;
		input [15:0]old_peak_frame;
		input [15:0]valley_frame;
		input [15:0]new_peak_frame;
	begin
		send_peak(peak_value, old_peak_frame, 8'd1);                        // 即时路径建立旧可靠锚点
		send_valley(valley_value, valley_frame, 8'd1);                     // 保存本周期正幅度证据
		begin_peak_hold(peak_value, new_peak_frame, 8'd1);                  // 保持新波峰启动阶段B算术
	end
	endtask

	// 通过正式峰谷事务启动顺序除法，并将42-bit商与测试台组合黄金结果逐位比较
	task check_sequential_divider;
		input signed [23:0]peak_value;
		input signed [23:0]valley_value;
		input [24:0]amplitude;
		input [15:0]period_frames;
		input [15:0]alpha_q15;
	begin
		reset_dut;                                                         // 每个除法向量使用独立运行上下文
		initialize_inputs;                                                 // 恢复合法ACTIVE和空入口
		i_alpha_q15 = alpha_q15;                                           // 设置本向量基础斜率比例
		start_run;                                                         // 装载固定斜率种子并进入RUN
		send_peak(peak_value, 16'd1, 8'd1);                                // 建立旧周期波峰锚点
		send_valley(valley_value, 16'd2, 8'd1);                            // 建立P减V幅度证据
		begin_peak_hold(peak_value, 16'd1 + period_frames, 8'd1);           // 保持新波峰并启动阶段B算术
		wait_arithmetic_state(ST_DIVIDE);                                  // 等待第一拍固定迭代状态
		cnt_divide_cycles = 0;                                             // 从第一拍DIVIDE开始精确计数
		while(ppg_dynamic_baseline_cross_detector_Inst_dut.state_current == ST_DIVIDE)begin
			cnt_divide_cycles = cnt_divide_cycles + 1;                       // 每个稳定DIVIDE状态代表处理一个商位
			@(negedge i_clk);                                                // 观察下一状态是否仍在迭代
		end
		reg_golden_numerator = $unsigned({39'd0, amplitude}) * $unsigned({48'd0, alpha_q15}) * 64'd2; // 形成冻结公式正分子
		reg_golden_numerator = reg_golden_numerator + ({48'd0, period_frames} >> 1); // 加入半分母实现最近舍入
		reg_golden_quotient = reg_golden_numerator / period_frames;         // 测试台使用组合除法生成黄金商
		if((cnt_divide_cycles != 42) || (ppg_dynamic_baseline_cross_detector_Inst_dut.reg_div_quotient !== reg_golden_quotient[41:0]))begin
			$display("FAIL PHASE_B_DIV A=%h T=%h alpha=%h cycles=%0d dut=%h ref=%h", amplitude, period_frames, alpha_q15, cnt_divide_cycles, ppg_dynamic_baseline_cross_detector_Inst_dut.reg_div_quotient, reg_golden_quotient[41:0]); // 报告首个顺序商差异
			$fatal(1);                                                       // 商或周期数不精确时立即阻断
		end
		finish_peak_hold;                                                  // 允许完整斜率与新锚点正式提交
	end
	endtask

	// 在目标FSM阶段脉冲STOP并核对算术与RUN状态均被清理
	task stop_at_state;
		input [3:0]target_state;
	begin
		reset_dut;                                                         // 每个目标状态使用独立RUN上下文
		initialize_inputs;                                                 // 恢复默认合法ACTIVE与空闲valid
		start_run;                                                         // 装载固定斜率并进入RUN
		prepare_adaptive_peak_hold(24'sd1000, 24'sd0, 16'd100, 16'd300, 16'd400); // 启动完整周期计算
		wait_arithmetic_state(target_state);                               // 等待指定阶段稳定出现
		pulse_detection_discard(DISCARD_REASON_STOP);                      // 在目标状态当前下降沿立即声明STOP排空
		i_peak_valid = 1'b0;                                               // 上游随RUN终止释放保持事件
		flag_stage_check_ok = flag_stage_check_ok && (ppg_dynamic_baseline_cross_detector_Inst_dut.state_current == 4'd0) && (ppg_dynamic_baseline_cross_detector_Inst_dut.flag_pending_valid == 1'b0) && (o_baseline_valid == 1'b0) && (o_slope_current_q16 == 0); // 累计无迟到提交结论
	end
	endtask

	// 在目标FSM阶段脉冲control abort并核对结果不可迟到写回
	task abort_at_state;
		input [3:0]target_state;
	begin
		reset_dut;                                                         // 为每个abort阶段清除历史
		initialize_inputs;                                                 // 恢复全部默认驱动
		start_run;                                                         // 开始独立RUN事务
		prepare_adaptive_peak_hold(24'sd1000, 24'sd0, 16'd100, 16'd300, 16'd400); // 进入顺序算术路径
		wait_arithmetic_state(target_state);                               // 定位待撤销的具体状态
		pulse_detection_discard(DISCARD_REASON_ABORT);                     // 在目标状态当前下降沿立即声明abort撤销
		i_peak_valid = 1'b0;                                               // 终止RUN后释放波峰valid
		flag_stage_check_ok = flag_stage_check_ok && (ppg_dynamic_baseline_cross_detector_Inst_dut.state_current == 4'd0) && (ppg_dynamic_baseline_cross_detector_Inst_dut.flag_pending_valid == 1'b0) && (o_adaptive_slope_valid == 1'b0) && (o_slope_current_q16 == 0); // 累计abort优先级检查
	end
	endtask

	// 在目标FSM阶段接受AMB重检并核对旧锚点和活动斜率得到保留
	task recheck_at_state;
		input [3:0]target_state;
	begin
		reset_dut;                                                         // 每个重检阶段使用独立状态
		initialize_inputs;                                                 // 清除上一循环控制信号
		start_run;                                                         // 建立正常RUN
		prepare_adaptive_peak_hold(24'sd1000, 24'sd0, 16'd100, 16'd300, 16'd400); // 启动待撤销自适应运算
		wait_arithmetic_state(target_state);                               // 等待重检插入状态
		reg_slope_snapshot = o_slope_current_q16;                          // 保存重检前旧活动斜率
		reg_hold_frame = ppg_dynamic_baseline_cross_detector_Inst_dut.dec_peak_frame_id; // 保存旧锚点帧号
		i_recheck_accept_event = 1'b1;                                     // 在目标状态当前下降沿立即声明重检接管
		i_recheck_busy = 1'b1;                                             // 同步进入重检禁止窗口
		@(negedge i_clk) i_recheck_accept_event = 1'b0;                   // 清除接管事件并维持busy
		i_peak_valid = 1'b0;                                               // 被取消的旧峰不再恢复
		flag_stage_check_ok = flag_stage_check_ok && (ppg_dynamic_baseline_cross_detector_Inst_dut.state_current == 4'd0) && (ppg_dynamic_baseline_cross_detector_Inst_dut.flag_pending_valid == 1'b0) && (o_slope_current_q16 == reg_slope_snapshot) && (ppg_dynamic_baseline_cross_detector_Inst_dut.dec_peak_frame_id == reg_hold_frame); // 核对旧锚点与斜率未被部分结果覆盖
		i_recheck_busy = 1'b0;                                             // 结束测试用重检禁止窗口
	end
	endtask

	// 在任一算术阶段注入异常返回重获并核对旧快照不可迟到提交
	task reacquire_at_state;
		input [3:0]target_state;
	begin
		reset_dut;                                                         // 每个重获阶段使用独立状态
		initialize_inputs;                                                // 恢复默认合法ACTIVE与空入口
		start_run;                                                        // 建立正常RUN上下文
		prepare_adaptive_peak_hold(24'sd1000, 24'sd0, 16'd100, 16'd300, 16'd400); // 启动待撤销自适应运算
		wait_arithmetic_state(target_state);                               // 等待异常返回插入目标阶段
		reg_slope_snapshot = o_slope_current_q16;                          // 保存事件前活动斜率数值
		i_reacquire_request_event = 1'b1;                                  // 声明真实返回9-bit后的重获单拍
		@(negedge i_clk) i_reacquire_request_event = 1'b0;                // 清除不可反压控制事件
		i_peak_valid = 1'b0;                                               // 被撤销的旧波峰不得再次提交
		flag_stage_check_ok = flag_stage_check_ok && (ppg_dynamic_baseline_cross_detector_Inst_dut.state_current == ST_IDLE) && (ppg_dynamic_baseline_cross_detector_Inst_dut.flag_pending_valid == 1'b0) && (o_baseline_valid == 1'b0) && (o_adaptive_slope_valid == 1'b0) && o_reacquire_active && (o_slope_current_q16 == reg_slope_snapshot); // 累计原子撤销与斜率保留结论
	end
	endtask

	// 每个独立场景通过异步复位清除DUT和测试输入历史
	task reset_dut;
	begin
		@(negedge i_clk);                                                   // 在安全下降沿开始复位
		i_rstn = 1'b0;                                                     // 拉低异步复位
		repeat(2) @(negedge i_clk);                                        // 保持两个完整时钟沿
		i_rstn = 1'b1;                                                     // 释放复位进入空闲态
		@(negedge i_clk);                                                   // 等待复位释放稳定
		flag_eqv_started = 1'b0;                                           // 首次复位后开始记录确定性状态
	end
	endtask

	// 合法START任务使配置在事件前已经稳定
	task start_run;
	begin
		@(negedge i_clk);                                                   // 在采样沿之前设置RUN状态
		i_run_enable = 1'b1;                                               // 允许检测接口开始握手
		i_start_ack_event = 1'b1;                                          // 发送单拍START接受事件
		@(negedge i_clk);                                                   // START已经被DUT采样
		i_start_ack_event = 1'b0;                                          // 清除单周期事件
	end
	endtask

	// 生命周期discard任务统一模拟PWI广播的STOP/abort代际清空单拍
	task pulse_detection_discard;
		input [1:0]reason;
	begin
		i_detection_discard_event = 1'b1;                                  // 在当前下降沿立即声明代际清空事件
		i_detection_discard_reason = reason;                               // 设置STOP排空或abort撤销分类
		i_detection_discard_identity_valid = 1'b1;                         // 使用可信触发身份
		i_detection_discard_run_generation = i_run_generation;             // 命中当前RUN代际以触发清理
		@(negedge i_clk) i_detection_discard_event = 1'b0;                // 清除单拍事件
	end
	endtask

	// 波峰任务在阶段B有界反压期间持续保持valid和全部载荷
	task send_peak;
		input signed [23:0]value;
		input [15:0]frame_id;
		input [7:0]epoch;
	begin
		@(negedge i_clk);                                                   // 在采样沿之前设置波峰载荷
		i_peak_value = value;                                              // 驱动可靠码值波峰
		i_peak_frame_id = frame_id;                                        // 驱动波峰实际中心帧
		i_peak_sample_index = frame_id + 16'd1000;                          // 生成可追踪事务号
		i_peak_config_epoch = epoch;                                       // 设置波峰ACTIVE版本
		i_peak_coef_epoch = 8'd2;                                          // 使用默认Stage1版本
		i_peak_dc_recovery_coef_epoch = 8'd3;                              // 使用默认DC恢复版本
		i_peak_valid = 1'b1;                                               // 声明完整波峰事件
		while(o_peak_ready !== 1'b1)begin
			@(negedge i_clk);                                                // 算术busy时保持波峰载荷等待WAIT状态
		end
		@(negedge i_clk);                                                   // ready为高后的中间上升沿完成正式提交
		i_peak_valid = 1'b0;                                               // 撤销valid避免重复消费
	end
	endtask

	// 波谷任务允许单独指定ACTIVE版本以测试epoch不一致
	task send_valley;
		input signed [23:0]value;
		input [15:0]frame_id;
		input [7:0]epoch;
	begin
		@(negedge i_clk);                                                   // 在采样沿之前设置波谷载荷
		i_valley_value = value;                                            // 驱动运行最小值
		i_valley_frame_id = frame_id;                                      // 驱动波谷实际中心帧
		i_valley_sample_index = frame_id + 16'd2000;                        // 生成独立波谷事务号
		i_valley_config_epoch = epoch;                                     // 设置波谷ACTIVE版本
		i_valley_coef_epoch = 8'd2;                                        // 使用默认Stage1版本
		i_valley_dc_recovery_coef_epoch = 8'd3;                            // 使用默认DC恢复版本
		i_valley_valid = 1'b1;                                             // 声明完整波谷事件
		while(o_valley_ready !== 1'b1)begin
			@(negedge i_clk);                                                // 波峰算术期间保持波谷事务等待接口恢复
		end
		@(negedge i_clk);                                                   // ready为高后的中间上升沿记录波谷
		i_valley_valid = 1'b0;                                             // 撤销valid避免重复记录
	end
	endtask

	// FIR任务可控制颜色、资格和饱和以覆盖正式证据边界
	task send_result;
		input signed [23:0]value;
		input [15:0]frame_id;
		input color_ir;
		input qualified;
		input saturation;
		input [7:0]epoch;
	begin
		@(negedge i_clk);                                                   // 在采样沿之前设置FIR事务
		i_filtered_ppg_value = value;                                      // 驱动当前粗滤波码值
		i_frame_id = frame_id;                                             // 驱动FIR中心帧号
		i_sample_index = frame_id + 16'd3000;                               // 生成可核对的中心事务号
		i_color_ir = color_ir;                                             // 选择RED或IR身份
		i_detection_qualified = qualified;                                 // 设置正式检测资格
		i_window_saturation_low = saturation;                              // 用负端标志代表任意输入饱和
		i_window_saturation_high = 1'b0;                                   // 保持另一端诊断无效
		i_fir_saturation_low = 1'b0;                                       // 默认FIR低端不饱和
		i_fir_saturation_high = 1'b0;                                      // 默认FIR高端不饱和
		i_config_epoch = epoch;                                            // 设置中心ACTIVE版本
		i_coef_epoch = 8'd2;                                               // 设置中心Stage1版本
		i_dc_recovery_coef_epoch = 8'd3;                                   // 设置中心DC恢复版本
		i_result_valid = 1'b1;                                             // 声明完整FIR事务
		while(o_result_ready !== 1'b1)begin
			@(negedge i_clk);                                                // 阶段B有界反压期间保持FIR事务完整
		end
		@(negedge i_clk);                                                   // ready为高后的中间上升沿完成消费
		i_result_valid = 1'b0;                                             // 撤销valid避免重复消费
		i_window_saturation_low = 1'b0;                                    // 恢复默认无饱和输入
		i_detection_qualified = 1'b1;                                      // 恢复默认正式资格
	end
	endtask

	// 精确相交序列先给出基线下样本，再给出三个连续上方样本
	task make_cross;
		input [15:0]cross_frame;
		input [7:0]epoch;
	begin
		send_result(-24'sd100000, cross_frame - 16'd1, 1'b0, 1'b1, 1'b0, epoch); // 观察负迟滞下方并建立相邻历史
		send_result(24'sd100000, cross_frame, 1'b0, 1'b1, 1'b0, epoch);     // 首次向上越过计为第一个点
		send_result(24'sd100001, cross_frame + 16'd1, 1'b0, 1'b1, 1'b0, epoch); // 第二个连续上方确认点
		send_result(24'sd100002, cross_frame + 16'd2, 1'b0, 1'b1, 1'b0, epoch); // 第三个确认点产生相交事件
	end
	endtask

	// 用例结论只有在真实布尔比较完成后才允许打印PASS
	task check_case;
		input [8*7 - 1:0]case_id;
		input condition;
	begin
		if(condition)begin
			cnt_pass = cnt_pass + 1;                                        // 累计通过的冻结用例
			$display("PASS %s", case_id);                                  // 输出可检索的成功标记
		end else begin
			cnt_fail = cnt_fail + 1;                                        // 累计失败检查供最终退出使用
			$display("FAIL %s time=%0t", case_id, $time);                   // 报告失败用例和仿真时刻
		end
	end
	endtask

	//-------------模块实例化区域-------------//
	// 被测模块连接全部冻结端口，避免接口字段在验证中被省略
	ppg_dynamic_baseline_cross_detector ppg_dynamic_baseline_cross_detector_Inst_dut(
		.i_clk(i_clk),                                                     // 连接仿真主时钟
		.i_rstn(i_rstn),                                                   // 连接低有效异步复位
		.i_run_enable(i_run_enable),                                       // 连接RUN检测使能
		.i_start_ack_event(i_start_ack_event),                             // 连接START接受事件
		.i_fine_window_active(i_fine_window_active),                       // 连接15-bit窗口状态
		.i_reacquire_request_event(i_reacquire_request_event),             // 连接异常返回重获事件
		.i_recheck_accept_event(i_recheck_accept_event),                   // 连接重检接管事件
		.i_recheck_busy(i_recheck_busy),                                   // 连接重检禁止窗口
		.i_recheck_done_event(i_recheck_done_event),                       // 连接重检结束事件
		.i_recheck_success(i_recheck_success),                             // 连接重检成功资格
		.i_detection_discard_event(i_detection_discard_event),             // 连接PWI广播代际清空事件
		.i_detection_discard_reason(i_detection_discard_reason),           // 连接清空原因分类
		.i_detection_discard_identity_valid(i_detection_discard_identity_valid), // 连接触发身份可信标志
		.i_detection_discard_sample_valid(i_detection_discard_sample_valid), // 连接触发独立样本资格
		.i_detection_discard_frame_id(i_detection_discard_frame_id),       // 连接触发诊断帧号
		.i_detection_discard_sample_index(i_detection_discard_sample_index), // 连接触发诊断事务号
		.i_detection_discard_color_ir(i_detection_discard_color_ir),       // 连接触发诊断颜色
		.i_detection_discard_frame_type(i_detection_discard_frame_type),   // 连接触发诊断类型
		.i_detection_discard_precision(i_detection_discard_precision),     // 连接触发诊断精度
		.i_detection_discard_config_epoch(i_detection_discard_config_epoch), // 连接触发诊断ACTIVE版本
		.i_detection_discard_coef_epoch(i_detection_discard_coef_epoch),   // 连接触发诊断Stage1版本
		.i_detection_discard_dc_recovery_epoch(i_detection_discard_dc_recovery_epoch), // 连接触发诊断DC恢复版本
		.i_detection_discard_amb_code_epoch(i_detection_discard_amb_code_epoch), // 连接触发诊断AMB码版本
		.i_detection_discard_dc_code_epoch(i_detection_discard_dc_code_epoch), // 连接触发诊断DC码版本
		.i_detection_discard_run_generation(i_detection_discard_run_generation), // 连接清空目标RUN代际
		.i_run_generation(i_run_generation),                               // 连接当前RUN代际快照
		.o_local_empty(o_local_empty),                                     // 观察本地排空状态
		.i_result_valid(i_result_valid),                                   // 连接粗FIR事务valid
		.o_result_ready(o_result_ready),                                   // 观察粗FIR事务ready
		.i_filtered_ppg_value(i_filtered_ppg_value),                       // 连接统一粗PPG码
		.i_detection_qualified(i_detection_qualified),                     // 连接FIR正式资格
		.i_window_saturation_low(i_window_saturation_low),                 // 连接窗口负端诊断
		.i_window_saturation_high(i_window_saturation_high),               // 连接窗口正端诊断
		.i_fir_saturation_low(i_fir_saturation_low),                       // 连接FIR负端诊断
		.i_fir_saturation_high(i_fir_saturation_high),                     // 连接FIR正端诊断
		.i_config_epoch(i_config_epoch),                                   // 连接中心ACTIVE版本
		.i_coef_epoch(i_coef_epoch),                                       // 连接中心Stage1版本
		.i_dc_recovery_coef_epoch(i_dc_recovery_coef_epoch),               // 连接中心DC恢复版本
		.i_precision_mode(i_precision_mode),                               // 连接中心精度身份
		.i_frame_id(i_frame_id),                                           // 连接FIR中心帧号
		.i_sample_index(i_sample_index),                                   // 连接FIR中心事务号
		.i_color_ir(i_color_ir),                                           // 连接FIR颜色身份
		.i_frame_type(i_frame_type),                                       // 连接NORMAL事务类别
		.i_peak_valid(i_peak_valid),                                       // 连接可靠波峰valid
		.o_peak_ready(o_peak_ready),                                       // 观察波峰事件ready
		.i_peak_value(i_peak_value),                                       // 连接码值波峰
		.i_peak_frame_id(i_peak_frame_id),                                 // 连接波峰中心帧号
		.i_peak_sample_index(i_peak_sample_index),                         // 连接波峰事务号
		.i_peak_config_epoch(i_peak_config_epoch),                         // 连接波峰ACTIVE版本
		.i_peak_coef_epoch(i_peak_coef_epoch),                             // 连接波峰Stage1版本
		.i_peak_dc_recovery_coef_epoch(i_peak_dc_recovery_coef_epoch),     // 连接波峰DC恢复版本
		.i_valley_valid(i_valley_valid),                                   // 连接可靠波谷valid
		.o_valley_ready(o_valley_ready),                                   // 观察波谷事件ready
		.i_valley_value(i_valley_value),                                   // 连接码值波谷
		.i_valley_frame_id(i_valley_frame_id),                             // 连接波谷中心帧号
		.i_valley_sample_index(i_valley_sample_index),                     // 连接波谷事务号
		.i_valley_config_epoch(i_valley_config_epoch),                     // 连接波谷ACTIVE版本
		.i_valley_coef_epoch(i_valley_coef_epoch),                         // 连接波谷Stage1版本
		.i_valley_dc_recovery_coef_epoch(i_valley_dc_recovery_coef_epoch), // 连接波谷DC恢复版本
		.i_slope_mode(i_slope_mode),                                       // 连接斜率模式配置
		.i_fixed_slope_q16(i_fixed_slope_q16),                             // 连接固定负斜率
		.i_alpha_q15(i_alpha_q15),                                         // 连接幅度比例配置
		.i_beta_q15(i_beta_q15),                                           // 连接平滑比例配置
		.i_timing_adjust_ratio_q15(i_timing_adjust_ratio_q15),             // 连接时刻修正比例
		.i_slope_min_q16(i_slope_min_q16),                                 // 连接最负斜率边界
		.i_slope_max_q16(i_slope_max_q16),                                 // 连接近零斜率边界
		.i_baseline_delta_q16(i_baseline_delta_q16),                       // 连接基线起点偏置
		.i_cross_hysteresis_q16(i_cross_hysteresis_q16),                   // 连接对称相交迟滞
		.i_lead_min_frames(i_lead_min_frames),                             // 连接提前量下界
		.i_lead_max_frames(i_lead_max_frames),                             // 连接提前量上界
		.i_cross_confirm_count(i_cross_confirm_count),                     // 连接连续确认点数
		.i_no_cross_limit(i_no_cross_limit),                               // 连接无相交周期限制
		.i_peak_valley_config_valid(i_peak_valley_config_valid),           // 连接V5正式检测资格门控
		.i_cross_ready(i_cross_ready),                                     // 连接相交下游ready
		.o_cross_valid(o_cross_valid),                                     // 观察相交事件valid
		.o_cross_frame_id(o_cross_frame_id),                               // 观察首次越过帧号
		.o_cross_sample_index(o_cross_sample_index),                       // 观察首次越过事务号
		.o_cross_time_unknown(o_cross_time_unknown),                       // 观察未知时刻属性
		.o_cross_config_epoch(o_cross_config_epoch),                       // 观察相交ACTIVE版本
		.o_cross_coef_epoch(o_cross_coef_epoch),                           // 观察相交Stage1版本
		.o_cross_dc_recovery_coef_epoch(o_cross_dc_recovery_coef_epoch),   // 观察相交DC恢复版本
		.o_cross_slope_q16(o_cross_slope_q16),                             // 观察相交活动斜率
		.o_cross_baseline_q16(o_cross_baseline_q16),                       // 观察相交诊断基线
		.o_baseline_valid(o_baseline_valid),                               // 观察当前基线资格
		.o_adaptive_slope_valid(o_adaptive_slope_valid),                   // 观察自适应资格
		.o_slope_current_q16(o_slope_current_q16),                         // 观察当前活动斜率
		.o_slope_base_q16(o_slope_base_q16),                               // 观察最近基础斜率
		.o_last_lead_frames(o_last_lead_frames),                           // 观察最近提前量
		.o_no_cross_count(o_no_cross_count),                               // 观察无相交周期数
		.o_reacquire_active(o_reacquire_active),                           // 观察重新获取状态
		.o_slope_saturation_min(o_slope_saturation_min),                   // 观察最负限幅诊断
		.o_slope_saturation_max(o_slope_saturation_max),                   // 观察近零限幅诊断
		.o_baseline_saturation_low(o_baseline_saturation_low),             // 观察基线负端诊断
		.o_baseline_saturation_high(o_baseline_saturation_high),           // 观察基线正端诊断
		.o_protocol_error_sticky(o_protocol_error_sticky)                  // 观察协议错误sticky
	);

	//---------------初始化区域---------------//
	// 主测试序列按合同编号独立复位并逐项比较预期结果
initial begin
i_clk=0;i_rstn=1;cnt_pass=0;cnt_fail=0;cnt_eqv_cycle=0;flag_eqv_started=0;flag_shared_multiplier_ok=1;flag_shared_idle_zero_ok=1;flag_shared_alpha_seen=0;flag_shared_beta_seen=0;flag_shared_adjust_seen=0;initialize_inputs;
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd65536;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd6554;i_beta_q15=16'd8192;i_timing_adjust_ratio_q15=16'd2048;i_no_cross_limit=4'd15;start_run;send_peak(24'sd1000,16'd100,8'd1);
make_cross(16'd384,8'd1);
send_valley(24'sd0,16'd101,8'd1);send_peak(24'sd1000,16'd400,8'd1);if(o_slope_base_q16 !== -32'sd43693 || o_slope_current_q16 !== -32'sd62806 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b0 || o_slope_saturation_max !== 1'b0)begin $display("C_BASELINE_VECTOR_FAIL case=0 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=0 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd65536;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd6554;i_beta_q15=16'd8192;i_timing_adjust_ratio_q15=16'd2048;i_no_cross_limit=4'd15;start_run;send_peak(24'sd1000,16'd100,8'd1);
make_cross(16'd383,8'd1);
send_valley(24'sd0,16'd101,8'd1);send_peak(24'sd1000,16'd400,8'd1);if(o_slope_base_q16 !== -32'sd43693 || o_slope_current_q16 !== -32'sd60075 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b0 || o_slope_saturation_max !== 1'b0)begin $display("C_BASELINE_VECTOR_FAIL case=1 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=1 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd65536;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd6554;i_beta_q15=16'd8192;i_timing_adjust_ratio_q15=16'd2048;i_no_cross_limit=4'd15;start_run;send_peak(24'sd1000,16'd100,8'd1);
make_cross(16'd381,8'd1);
send_valley(24'sd0,16'd101,8'd1);send_peak(24'sd1000,16'd400,8'd1);if(o_slope_base_q16 !== -32'sd43693 || o_slope_current_q16 !== -32'sd60075 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b0 || o_slope_saturation_max !== 1'b0)begin $display("C_BASELINE_VECTOR_FAIL case=2 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=2 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd65536;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd6554;i_beta_q15=16'd8192;i_timing_adjust_ratio_q15=16'd2048;i_no_cross_limit=4'd15;start_run;send_peak(24'sd1000,16'd100,8'd1);
make_cross(16'd380,8'd1);
send_valley(24'sd0,16'd101,8'd1);send_peak(24'sd1000,16'd400,8'd1);if(o_slope_base_q16 !== -32'sd43693 || o_slope_current_q16 !== -32'sd57344 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b0 || o_slope_saturation_max !== 1'b0)begin $display("C_BASELINE_VECTOR_FAIL case=3 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=3 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd65536;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd6554;i_beta_q15=16'd1;i_timing_adjust_ratio_q15=16'd2048;i_no_cross_limit=4'd15;start_run;send_peak(24'sd1000,16'd100,8'd1);
send_valley(24'sd0,16'd101,8'd1);send_peak(24'sd1000,16'd400,8'd1);if(o_slope_base_q16 !== -32'sd43693 || o_slope_current_q16 !== -32'sd68266 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b0 || o_slope_saturation_max !== 1'b0)begin $display("C_BASELINE_VECTOR_FAIL case=4 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=4 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd65536;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd1;i_beta_q15=16'd1;i_timing_adjust_ratio_q15=16'd1;i_no_cross_limit=4'd15;start_run;send_peak(24'sd1,16'd100,8'd1);
send_valley(24'sd0,16'd101,8'd1);send_peak(24'sd1,16'd104,8'd1);if(o_slope_base_q16 !== -32'sd1 || o_slope_current_q16 !== -32'sd65535 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b0 || o_slope_saturation_max !== 1'b0)begin $display("C_BASELINE_VECTOR_FAIL case=5 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=5 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd1;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd65535;i_beta_q15=16'd65535;i_timing_adjust_ratio_q15=16'd65535;i_no_cross_limit=4'd15;start_run;send_peak(24'sd8388607,16'd100,8'd1);
send_valley(-24'sd8388608,16'd101,8'd1);send_peak(24'sd8388607,16'd102,8'd1);if(o_slope_base_q16 !== -32'sd2147483647 || o_slope_current_q16 !== -32'sd2147483647 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b1 || o_slope_saturation_max !== 1'b0)begin $display("C_BASELINE_VECTOR_FAIL case=6 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=6 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd2147483647;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd65535;i_beta_q15=16'd65535;i_timing_adjust_ratio_q15=16'd1;i_no_cross_limit=4'd15;start_run;send_peak(24'sd8388607,16'd100,8'd1);
send_valley(-24'sd8388608,16'd101,8'd1);send_peak(24'sd8388607,16'd32867,8'd1);if(o_slope_base_q16 !== -32'sd67109884 || o_slope_current_q16 !== -32'sd1 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b0 || o_slope_saturation_max !== 1'b1)begin $display("C_BASELINE_VECTOR_FAIL case=7 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=7 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd2147483647;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd1;i_beta_q15=16'd65535;i_timing_adjust_ratio_q15=16'd65535;i_no_cross_limit=4'd15;start_run;send_peak(24'sd1,16'd100,8'd1);
send_valley(24'sd0,16'd101,8'd1);send_peak(24'sd1,16'd32867,8'd1);if(o_slope_base_q16 !== 32'sd0 || o_slope_current_q16 !== -32'sd1 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b0 || o_slope_saturation_max !== 1'b1)begin $display("C_BASELINE_VECTOR_FAIL case=8 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=8 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
reset_dut;initialize_inputs;i_fixed_slope_q16=-32'sd1234567;i_slope_min_q16=-32'sd2147483647;i_slope_max_q16=-32'sd1;i_alpha_q15=16'd32767;i_beta_q15=16'd16384;i_timing_adjust_ratio_q15=16'd32768;i_no_cross_limit=4'd15;start_run;send_peak(24'sd37,16'd100,8'd1);
send_valley(24'sd0,16'd101,8'd1);send_peak(24'sd37,16'd112,8'd1);if(o_slope_base_q16 !== -32'sd202063 || o_slope_current_q16 !== -32'sd920378 || o_adaptive_slope_valid !== 1'b1 || o_slope_saturation_min !== 1'b0 || o_slope_saturation_max !== 1'b0)begin $display("C_BASELINE_VECTOR_FAIL case=9 base=%0d slope=%0d adaptive=%b",o_slope_base_q16,o_slope_current_q16,o_adaptive_slope_valid);$fatal(1);end $display("C_BASELINE_VECTOR_PASS case=9 base=%0d slope=%0d",o_slope_base_q16,o_slope_current_q16);
$display("C_BASELINE_CONTRACT_VECTORS_PASS count=10");$finish;
end
	// 独立watchdog防止握手或时序错误导致仿真永久挂起
	initial begin
		#2000000;                                                         // 为BSL、逐状态撤销和随机42周期除法预留充足时间
		$display("FAIL WATCHDOG timeout at %0t", $time);                  // 输出超时诊断
		$fatal(1);                                                         // 超时属于阻断验证失败
	end

endmodule
