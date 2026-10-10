`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Codex
// Create Date:     2026/10/10
// Design Name:     tb_v18_ssw_golden
// Module Name:     tb_v18_ssw_golden
// Description:     Contract-only stimulus replay and complete analog pin capture
// Simulations:     Vivado xsim or iverilog
// Referrences:     C09 sections 7 and 8; independent V18 Python golden
// Dependencies:    ppg_sar9_sar15_safe_selection_wrapper (compile only)
// Version:         V1.0
// Revision Date:   2026/10/10
// History:         2026/10/10 V1.0 Codex Create independent pin capture bench.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Codex
// 创建日期:        2026年10月10日
// 设计名称:        tb_v18_ssw_golden
// 模块名称:        tb_v18_ssw_golden
// 模块说明:        合同端口驱动与全部模拟引脚逐拍采集，期望值由独立Python检查
// 仿真工程:        verification/v18_ssw_golden
// 参考资料:        C09接口合同以及获准时序模板
// 依赖文件:        SSW仅交给编译器，生成器不读取其内容
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:        2026年10月10日 V1.0 Codex 创建合同驱动采集台

// 逐拍重放相位和数字ADC行为链，检查时钟相位以及边沿间控制稳定性
module tb_v18_ssw_golden
();

	//---------------计数信号---------------//
	// 文件重放按有限行数推进，不由DUT输出决定物理相位
	integer cnt_clock_edge;                 // 有界主时钟发生循环的半周期计数
	integer cnt_row;                        // 采集记录唯一递增行号
	integer cnt_read;                       // 输入扫描返回的有效字段数量
	integer cnt_stimulus_file;              // 保存输入数据文件句柄
	integer cnt_output_file;                // 保存逐拍结果文件句柄
	integer cnt_errors;                     // 时钟相位或控制毛刺检查失败总数

	//--------------寄存器信号--------------//
	// 驱动字包括复位、相位、配置与两个独立身份通道
	reg reg_clk;                            // 仿真主时钟保持五百纳秒周期
	reg [193:0]reg_drive;                   // 单拍合同输入字在下降沿之后更换
	reg [8191:0]reg_stimulus_path;          // 运行参数指定完整刺激文件路径
	reg [8191:0]reg_output_path;            // 当前场景的模拟引脚采集目标路径
	reg [66:0]reg_high_sample;              // 上升沿稳定后冻结全部六十七个模拟位

	//---------------标志信号---------------//
	// 接管事实在沿前固定，避免沿后ready回落影响审计
	reg flag_wave_fire;                     // 记录提交沿之前真实波形握手条件
	reg flag_owner_fire;                    // 记录同拍结果所有权是否真正接纳

	//---------------输出信号---------------//
	// 每组模拟引脚保留合同宽度；状态只用于协议审计
	wire en_tia_low_o;                      // 采集TIA原始逻辑控制
	wire [7:0]leddac_o;                     // 采集LED电流数值总线
	wire leden1_low_o;                      // 采集红光发射采样窗口
	wire leden2_low_o;                      // 采集红外发射采样窗口
	wire en_test_o;                         // 采集外部测试电流源资格
	wire clk_buf_low_o;                     // 采集静态偏置缓冲控制
	wire clk_2m_o;                          // 采集原始主时钟同相转发
	wire clk_iref_idac_low_o;               // 采集局部参考电流预建立
	wire clk_9q1_low_o;                     // 采集九位路径第一采样相
	wire clk_15q1_low_o;                    // 采集十五位路径第一采样相
	wire clk_aferst_low_o;                  // 采集模拟前端复位时序
	wire clk_iref_idac_sar9_low_o;          // 采集九位参考长包络时钟
	wire clk_iref_idac_sar15_low_o;         // 采集十五位参考长包络时钟
	wire clk_q2_low_o;                      // 采集环境光扣除第二积分相
	wire clk_q3_low_o;                      // 采集颜色采样固定中心相位
	wire clk_tiaen_low_o;                   // 采集局部跨阻放大器门控
	wire en_15sar_low_o;                    // 采集转换器十五位选择电平
	wire en_sar9_amb_low_o;                 // 采集九位环境光抵消支路开通
	wire en_sar9_dc_low_o;                  // 采集九位直流抵消支路开通
	wire en_sar9_iref_o;                    // 采集九位参考源独立使能
	wire en_sar15_amb_low_o;                // 采集十五位环境光抵消资格
	wire en_sar15_dc_low_o;                 // 采集十五位直流抵消资格
	wire en_sar15_iref_o;                   // 采集十五位参考源保持许可
	wire [7:0]idac_sar9ambn_low_o;          // 采集九位环境光逐位快照码
	wire [7:0]idac_sar9dcn_low_o;           // 采集九位颜色逐位直流码
	wire [7:0]idac_sar15ambn_low_o;         // 采集十五位环境光数值载荷
	wire [7:0]idac_sar15dcn_low_o;          // 采集十五位颜色直流数值载荷
	wire [4:0]s_in_o;                       // 采集静态测试开关原子向量
	wire waveform_context_ready_o;          // 采集固定点模拟通道接管资格
	wire adc_owner_ready_o;                 // 采集最早待提交结果预约资格
	wire adc_owner_inflight_o;              // 采集等待真实完成的所有者存在
	wire owner_deadline_timeout_sticky_o;   // 采集截止抑制历史诊断
	wire switch_protocol_error_sticky_o;    // 采集阻断协议错误历史记录
	wire transaction_mismatch_sticky_o;     // 采集完成身份无法归属记录
	wire calibration_timeout_sticky_o;      // 采集校准读出迟到非阻断记录
	wire wrapper_fault_blocking_o;          // 采集当前阻断根因汇总
	wire analog_safe_o;                     // 采集模拟时序向量可停止事实
	wire sar_timing_idle_o;                 // 采集波形及切换已经结束
	wire wrapper_idle_o;                    // 采集时序数字身份物理链均空闲
	wire precision_active_o;                // 采集实际驱动的转换精度状态
	wire owner_q3_window_closed_o;          // 采集本所有者的采样窗口已关闭

	//-------------初始化区域-------------//
	// 自由运行时钟与输入文件解耦，避免把相位通道变成门控时钟
	initial begin $display("V18 clock: 2 MHz contract replay begins"); // 声明本次仿真唯一物理时基
		reg_clk = 1'b0;                   // 从低电平起步建立主时钟相位
		for(cnt_clock_edge = 0; cnt_clock_edge < 80000; cnt_clock_edge = cnt_clock_edge + 1)begin // 有界半周期序列覆盖全部场景时长
			#250 reg_clk = ~reg_clk;      // 每半周期翻转一次唯一仿真时基
		end
	end

	// 输入在低相稳定、提交前采样ready、NBA之后记录模拟边界
	initial begin $display("V18 driver: frozen contract stimuli are loaded"); // 刺激载荷已经由独立黄金模型冻结
		reg_drive = 194'd0;               // 初始合同字全零保证低有效复位已断言
		cnt_row = 0;                      // 第一行从复位序列零号开始
		cnt_errors = 0;                   // 本次采集清空被动断言失败计数
		if(!$value$plusargs("STIM=%s", reg_stimulus_path))begin
			$display("FAIL missing STIM"); // 缺少驱动文件则不能宣称仿真有效
			$finish;                      // 无刺激立即终止错误运行
		end
		if(!$value$plusargs("OUT=%s", reg_output_path))begin
			$display("FAIL missing OUT"); // 没有输出路径无法生成可审核证据
			$finish;                      // 无采集目标结束本次重放
		end
		cnt_stimulus_file = $fopen(reg_stimulus_path, "r"); // 只读打开预先生成的独立刺激
		cnt_output_file = $fopen(reg_output_path, "w"); // 创建新的逐行模拟输出采集文件
		if(cnt_stimulus_file == 0 || cnt_output_file == 0)begin
			$display("FAIL file open");   // 任何句柄无效都使采集证据失败
			$finish;                      // 文件访问失败时停止驱动
		end
		$fwrite(cnt_output_file, "row,o_en_tia_low,o_leddac,o_leden1_low,o_leden2_low,o_en_test,o_clk_buf_low,o_clk_2m,o_clk_iref_idac_low,o_clk_9q1_low,o_clk_15q1_low,o_clk_aferst_low,o_clk_iref_idac_sar9_low,o_clk_iref_idac_sar15_low,o_clk_q2_low,o_clk_q3_low,o_clk_tiaen_low,o_en_15sar_low,o_en_sar9_amb_low,o_en_sar9_dc_low,o_en_sar9_iref,o_en_sar15_amb_low,o_en_sar15_dc_low,o_en_sar15_iref,o_idac_sar9ambn_low,o_idac_sar9dcn_low,o_idac_sar15ambn_low,o_idac_sar15dcn_low,o_s_in,o_waveform_context_ready,o_adc_owner_ready,o_adc_owner_inflight,o_owner_deadline_timeout_sticky,o_switch_protocol_error_sticky,o_transaction_mismatch_sticky,o_calibration_timeout_sticky,o_wrapper_fault_blocking,o_analog_safe,o_sar_timing_idle,o_wrapper_idle,o_precision_active,o_owner_q3_window_closed,wave_fire,owner_fire,clock_low,stable_between_edges\n"); // 列名覆盖合同全部模拟输出与审计状态
		#2;                               // 留出复位组合传播时间再载入第一拍
		while(!$feof(cnt_stimulus_file))begin
			cnt_read = $fscanf(cnt_stimulus_file, "%h\n", reg_drive); // 低相载入固定宽度完整输入字
			if(cnt_read != 1)begin
				$display("FAIL malformed stimulus"); // 畸形行拒绝推进采集序号
				$finish;                  // 格式错误阻止不确定输入进入DUT
			end
			#247;                         // 提交沿前一纳秒确认握手资格
			flag_wave_fire = waveform_context_ready_o && reg_drive[138:138]; // 模拟预约只认沿前ready与valid同时成立
			flag_owner_fire = adc_owner_ready_o && reg_drive[82:82]; // 结果接纳只认独立owner通道合法提交
			@(posedge reg_clk);           // 物理更新点来自唯一二兆赫时钟
			#1;                           // 等待非阻塞赋值完成后观察上升沿输出
			reg_high_sample = {en_tia_low_o, leddac_o, leden1_low_o, leden2_low_o, en_test_o, clk_buf_low_o, clk_2m_o, clk_iref_idac_low_o, clk_9q1_low_o, clk_15q1_low_o, clk_aferst_low_o, clk_iref_idac_sar9_low_o, clk_iref_idac_sar15_low_o, clk_q2_low_o, clk_q3_low_o, clk_tiaen_low_o, en_15sar_low_o, en_sar9_amb_low_o, en_sar9_dc_low_o, en_sar9_iref_o, en_sar15_amb_low_o, en_sar15_dc_low_o, en_sar15_iref_o, idac_sar9ambn_low_o, idac_sar9dcn_low_o, idac_sar15ambn_low_o, idac_sar15dcn_low_o, s_in_o}; // 冻结完整模拟向量用于边沿间稳定性核查
			if(clk_2m_o !== 1'b1)begin
				cnt_errors = cnt_errors + 1; // 上升沿时钟转发错误纳入真实失败计数
			end
			@(negedge reg_clk);           // 下降沿再次核对时钟转发与模拟向量
			#1;                           // 允许源时钟下降传播到模拟端口
			if(clk_2m_o !== 1'b0 || ((reg_high_sample ^ {en_tia_low_o, leddac_o, leden1_low_o, leden2_low_o, en_test_o, clk_buf_low_o, clk_2m_o, clk_iref_idac_low_o, clk_9q1_low_o, clk_15q1_low_o, clk_aferst_low_o, clk_iref_idac_sar9_low_o, clk_iref_idac_sar15_low_o, clk_q2_low_o, clk_q3_low_o, clk_tiaen_low_o, en_15sar_low_o, en_sar9_amb_low_o, en_sar9_dc_low_o, en_sar9_iref_o, en_sar15_amb_low_o, en_sar15_dc_low_o, en_sar15_iref_o, idac_sar9ambn_low_o, idac_sar9dcn_low_o, idac_sar15ambn_low_o, idac_sar15dcn_low_o, s_in_o}) & 67'h7ffdfffffffffffff) !== 67'd0)begin
				cnt_errors = cnt_errors + 1; // 低相时钟错误或控制边沿间变化计为失败
			end
			$fwrite(cnt_output_file, "%d,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h\n", cnt_row, reg_high_sample[66:66], reg_high_sample[65:58], reg_high_sample[57:57], reg_high_sample[56:56], reg_high_sample[55:55], reg_high_sample[54:54], reg_high_sample[53:53], reg_high_sample[52:52], reg_high_sample[51:51], reg_high_sample[50:50], reg_high_sample[49:49], reg_high_sample[48:48], reg_high_sample[47:47], reg_high_sample[46:46], reg_high_sample[45:45], reg_high_sample[44:44], reg_high_sample[43:43], reg_high_sample[42:42], reg_high_sample[41:41], reg_high_sample[40:40], reg_high_sample[39:39], reg_high_sample[38:38], reg_high_sample[37:37], reg_high_sample[36:29], reg_high_sample[28:21], reg_high_sample[20:13], reg_high_sample[12:5], reg_high_sample[4:0], waveform_context_ready_o, adc_owner_ready_o, adc_owner_inflight_o, owner_deadline_timeout_sticky_o, switch_protocol_error_sticky_o, transaction_mismatch_sticky_o, calibration_timeout_sticky_o, wrapper_fault_blocking_o, analog_safe_o, sar_timing_idle_o, wrapper_idle_o, precision_active_o, owner_q3_window_closed_o, flag_wave_fire, flag_owner_fire, clk_2m_o, (((reg_high_sample ^ {en_tia_low_o, leddac_o, leden1_low_o, leden2_low_o, en_test_o, clk_buf_low_o, clk_2m_o, clk_iref_idac_low_o, clk_9q1_low_o, clk_15q1_low_o, clk_aferst_low_o, clk_iref_idac_sar9_low_o, clk_iref_idac_sar15_low_o, clk_q2_low_o, clk_q3_low_o, clk_tiaen_low_o, en_15sar_low_o, en_sar9_amb_low_o, en_sar9_dc_low_o, en_sar9_iref_o, en_sar15_amb_low_o, en_sar15_dc_low_o, en_sar15_iref_o, idac_sar9ambn_low_o, idac_sar9dcn_low_o, idac_sar15ambn_low_o, idac_sar15dcn_low_o, s_in_o}) & 67'h7ffdfffffffffffff) === 67'd0)); // 输出上升沿引脚值及本拍低相审计事实
			cnt_row = cnt_row + 1;        // 每条有效输入恰好对应一条采集记录
		end
		$fclose(cnt_stimulus_file);       // 全部刺激重放完成关闭输入句柄
		$fclose(cnt_output_file);         // 落盘采集证据后释放输出句柄
		if(cnt_errors == 0)begin
			$display("PASS pin capture clock and stability rows=%0d", cnt_row); // 只有真实时钟与稳定断言全通过才打印采集PASS
		end else begin
			$display("FAIL clock or stability errors=%0d", cnt_errors); // 被动断言错误明确标为采集失败
		end
		$finish;                          // 黄金符合性由独立Python比较器另行判定
	end

	// 有界看门狗使缺失时钟或阻塞文件不会成为无限仿真
	initial begin $display("V18 watchdog: bounded simulation guard armed"); // 启用超时保护防止无界工具占用
		#20000000;                        // 四十千拍上限覆盖双宏帧场景并留下余量
		$display("FAIL watchdog timeout"); // 超过允许模拟时间报告超时失败
		$finish;                          // 终止异常挂起并交还工具控制权
	end

	//------------模块实例化区域------------//
	// 仅按C09显式接口例化；不从RTL提取定义或绑定层级内部对象
	ppg_sar9_sar15_safe_selection_wrapper ppg_sar9_sar15_safe_selection_wrapper_Inst_contract( // 合同驱动的唯一被测模拟控制源
		.i_clk(reg_clk),                    // 供给无门控二兆赫物理主时钟
		.i_rstn(reg_drive[193:193]),        // 重放场景条件：低有效复位使所有数字预约失效
		.i_run_enable(reg_drive[192:192]),  // 重放场景条件：运行期间允许受控事务
		.i_start_ack_event(reg_drive[191:191]), // 重放场景条件：新运行确认清除历史残留
		.i_stop_ack_event(reg_drive[190:190]), // 重放场景条件：停止确认阻止后续接管
		.i_control_abort_event(reg_drive[189:189]), // 重放场景条件：立即撤销尚未完成的波形
		.i_diag_clear_event(reg_drive[188:188]), // 重放场景条件：安全空闲时请求清历史诊断
		.i_run_generation(reg_drive[187:180]), // 重放场景条件：唯一运行代际绑定释放身份
		.i_macro_tick(reg_drive[179:167]),  // 重放场景条件：外部宏帧物理相位从零到四千九百九十九
		.i_calibration_subframe_index(reg_drive[166:164]), // 重放场景条件：快速校准当前子帧编号
		.i_calibration_local_tick(reg_drive[163:154]), // 重放场景条件：子帧局部相位从零到六百二十四
		.i_normal_frame_active(reg_drive[153:153]), // 重放场景条件：声明本宏帧属于正常测量
		.i_calibration_frame_active(reg_drive[152:152]), // 重放场景条件：声明当前快速校准宏帧
		.i_macro_frame_safe_boundary(reg_drive[151:151]), // 重放场景条件：宏帧末尾安全点接管精度
		.i_idac_code_safe_boundary(reg_drive[150:150]), // 重放场景条件：候选码仅在规定边界提交
		.i_run_profile(reg_drive[149:149]), // 重放场景条件：选择普通运行或表征运行资格
		.i_input_source(reg_drive[148:148]), // 重放场景条件：光电二极管与固定电流的源选择
		.i_optical_mode(reg_drive[147:146]), // 重放场景条件：配置红光红外或双光测量数量
		.i_precision_mode_committed(reg_drive[145:145]), // 重放场景条件：安全边界已提交的转换精度
		.i_static_characterization_enable(reg_drive[144:144]), // 重放场景条件：独立静态偏置覆盖使能
		.i_test_mux_ctrl(reg_drive[143:139]), // 重放场景条件：经CDC原子提交的五位测试选择
		.i_waveform_context_valid(reg_drive[138:138]), // 重放场景条件：完整模拟上下文载荷有效
		.i_waveform_precision_mode(reg_drive[137:137]), // 重放场景条件：接管波形的精度快照
		.i_waveform_frame_id(reg_drive[136:121]), // 重放场景条件：波形槽归属的物理帧身份
		.i_waveform_color_ir(reg_drive[120:120]), // 重放场景条件：模拟槽使用的颜色身份
		.i_waveform_frame_type(reg_drive[119:118]), // 重放场景条件：模拟预约的正常或校准类型
		.i_waveform_amb_code_snapshot(reg_drive[117:110]), // 重放场景条件：预热前锁存环境光抵消码
		.i_waveform_dc_code_snapshot(reg_drive[109:102]), // 重放场景条件：预热前冻结当前色直流码
		.i_waveform_amb_code_epoch(reg_drive[101:98]), // 重放场景条件：环境光快照的码版本
		.i_waveform_dc_code_epoch(reg_drive[97:94]), // 重放场景条件：当前颜色直流快照版本
		.i_waveform_input_source(reg_drive[93:93]), // 重放场景条件：本次模拟解释的输入源快照
		.i_waveform_optical_mode(reg_drive[92:91]), // 重放场景条件：本帧颜色组合的冻结解释
		.i_waveform_leddac_code_snapshot(reg_drive[90:83]), // 重放场景条件：本次光路已提交电流码
		.i_adc_owner_commit_event(reg_drive[82:82]), // 重放场景条件：与模拟ADC接纳同拍提交结果身份
		.i_adc_owner_precision_mode(reg_drive[81:81]), // 重放场景条件：结果事务精度须匹配波形预约
		.i_adc_owner_frame_id(reg_drive[80:65]), // 重放场景条件：提交结果所有者的帧号
		.i_adc_owner_color_ir(reg_drive[64:64]), // 重放场景条件：结果所有权绑定红或红外
		.i_adc_owner_frame_type(reg_drive[63:62]), // 重放场景条件：结果接纳对应的校准类别
		.i_adc_owner_amb_code_snapshot(reg_drive[61:54]), // 重放场景条件：所有者携带环境光码副本
		.i_adc_owner_dc_code_snapshot(reg_drive[53:46]), // 重放场景条件：结果身份附带直流码副本
		.i_adc_owner_amb_code_epoch(reg_drive[45:42]), // 重放场景条件：结果侧环境光码版本核对
		.i_adc_owner_dc_code_epoch(reg_drive[41:38]), // 重放场景条件：结果侧颜色码版本核对
		.i_adc_owner_sample_index(reg_drive[37:22]), // 重放场景条件：仅真实提交时分配采样序号
		.i_adc_transaction_complete_event(reg_drive[21:21]), // 重放场景条件：行为ADC数字链给出完成旁带
		.i_adc_transaction_success(reg_drive[20:20]), // 重放场景条件：完成资格为零仍允许释放
		.i_adc_complete_sample_index(reg_drive[19:4]), // 重放场景条件：完成链返回原始事务序号
		.i_adc_transaction_lost_event(reg_drive[3:3]), // 重放场景条件：超时作废与正常完成互斥
		.i_adc_idle(reg_drive[2:2]),        // 重放场景条件：物理转换及返回链均已空闲
		.i_test_inject_enable(reg_drive[1:1]), // 重放场景条件：生产默认关闭的验证注入开关
		.i_context_handover_stall_request(reg_drive[0:0]), // 重放场景条件：不使用上下文反压注入
		.o_en_tia_low(en_tia_low_o),        // 观测DUT返回：TIA原始逻辑控制
		.o_leddac(leddac_o),                // 观测DUT返回：LED电流数值总线
		.o_leden1_low(leden1_low_o),        // 观测DUT返回：红光发射采样窗口
		.o_leden2_low(leden2_low_o),        // 观测DUT返回：红外发射采样窗口
		.o_en_test(en_test_o),              // 观测DUT返回：外部测试电流源资格
		.o_clk_buf_low(clk_buf_low_o),      // 观测DUT返回：静态偏置缓冲控制
		.o_clk_2m(clk_2m_o),                // 观测DUT返回：原始主时钟同相转发
		.o_clk_iref_idac_low(clk_iref_idac_low_o), // 观测DUT返回：局部参考电流预建立
		.o_clk_9q1_low(clk_9q1_low_o),      // 观测DUT返回：九位路径第一采样相
		.o_clk_15q1_low(clk_15q1_low_o),    // 观测DUT返回：十五位路径第一采样相
		.o_clk_aferst_low(clk_aferst_low_o), // 观测DUT返回：模拟前端复位时序
		.o_clk_iref_idac_sar9_low(clk_iref_idac_sar9_low_o), // 观测DUT返回：九位参考长包络时钟
		.o_clk_iref_idac_sar15_low(clk_iref_idac_sar15_low_o), // 观测DUT返回：十五位参考长包络时钟
		.o_clk_q2_low(clk_q2_low_o),        // 观测DUT返回：环境光扣除第二积分相
		.o_clk_q3_low(clk_q3_low_o),        // 观测DUT返回：颜色采样固定中心相位
		.o_clk_tiaen_low(clk_tiaen_low_o),  // 观测DUT返回：局部跨阻放大器门控
		.o_en_15sar_low(en_15sar_low_o),    // 观测DUT返回：转换器十五位选择电平
		.o_en_sar9_amb_low(en_sar9_amb_low_o), // 观测DUT返回：九位环境光抵消支路开通
		.o_en_sar9_dc_low(en_sar9_dc_low_o), // 观测DUT返回：九位直流抵消支路开通
		.o_en_sar9_iref(en_sar9_iref_o),    // 观测DUT返回：九位参考源独立使能
		.o_en_sar15_amb_low(en_sar15_amb_low_o), // 观测DUT返回：十五位环境光抵消资格
		.o_en_sar15_dc_low(en_sar15_dc_low_o), // 观测DUT返回：十五位直流抵消资格
		.o_en_sar15_iref(en_sar15_iref_o),  // 观测DUT返回：十五位参考源保持许可
		.o_idac_sar9ambn_low(idac_sar9ambn_low_o), // 观测DUT返回：九位环境光逐位快照码
		.o_idac_sar9dcn_low(idac_sar9dcn_low_o), // 观测DUT返回：九位颜色逐位直流码
		.o_idac_sar15ambn_low(idac_sar15ambn_low_o), // 观测DUT返回：十五位环境光数值载荷
		.o_idac_sar15dcn_low(idac_sar15dcn_low_o), // 观测DUT返回：十五位颜色直流数值载荷
		.o_s_in(s_in_o),                    // 观测DUT返回：静态测试开关原子向量
		.o_waveform_context_ready(waveform_context_ready_o), // 观测DUT返回：固定点模拟通道接管资格
		.o_adc_owner_ready(adc_owner_ready_o), // 观测DUT返回：最早待提交结果预约资格
		.o_adc_owner_inflight(adc_owner_inflight_o), // 观测DUT返回：等待真实完成的所有者存在
		.o_owner_deadline_timeout_sticky(owner_deadline_timeout_sticky_o), // 观测DUT返回：截止抑制历史诊断
		.o_switch_protocol_error_sticky(switch_protocol_error_sticky_o), // 观测DUT返回：阻断协议错误历史记录
		.o_transaction_mismatch_sticky(transaction_mismatch_sticky_o), // 观测DUT返回：完成身份无法归属记录
		.o_calibration_timeout_sticky(calibration_timeout_sticky_o), // 观测DUT返回：校准读出迟到非阻断记录
		.o_wrapper_fault_blocking(wrapper_fault_blocking_o), // 观测DUT返回：当前阻断根因汇总
		.o_analog_safe(analog_safe_o),      // 观测DUT返回：模拟时序向量可停止事实
		.o_sar_timing_idle(sar_timing_idle_o), // 观测DUT返回：波形及切换已经结束
		.o_wrapper_idle(wrapper_idle_o),    // 观测DUT返回：时序数字身份物理链均空闲
		.o_precision_active(precision_active_o), // 观测DUT返回：实际驱动的转换精度状态
		.o_owner_q3_window_closed(owner_q3_window_closed_o) // 观测DUT返回：本所有者的采样窗口已关闭
	);

endmodule
