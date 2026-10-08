`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/08
// Design Name:        PPG AMB Recheck Scheduler Self-Checking Testbench
// Module Name:        tb_ppg_amb_recheck_scheduler
// Description:        Description/tb_ppg_amb_recheck_scheduler_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_amb_recheck_scheduler
//
// Referrences:        PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md,
//                     PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_amb_recheck_scheduler.v
//
// Version:            V1.2
// Revision Date:      2026/10/08
// History:
//    Time               Version       Revised by            Contents
// 2026/08/08            V1.0          Erie                  Create file.
// 2026/08/11            V1.0          Erie                  Verify peak-valley idle takeover gate.
// 2026/09/30            V1.1          Erie                  TB maintenance (no RTL change): RTL V1.1 (2026/08/23) renamed the input i_adc_idle to i_precision_takeover_safe as a pure port rename with no logic change, so this TB stopped elaborating (xelab "cannot find port 'i_adc_idle'", REGRESSION_BASELINE_20260930.md section 6.3). Renamed the one named-port connection; the TB-side stimulus reg keeps its old name. Result: 35 PASS lines (34 checks + final summary), 0 FAIL (xsim and iverilog).
// 2026/10/08            V1.2          Erie                  Owner-lifecycle round step 3 (F-020): input i_calibration_request_withdraw_event is now a TB reg; new TB-local check F020-WDRAW (two PASS lines): a withdraw of the in-flight outer request releases the inner in-flight state, the held AMB request re-raises valid and is accepted exactly once more.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月08日
// 设计名称:           PPG环境光周期重检调度器自检平台
// 模块名称:           tb_ppg_amb_recheck_scheduler
// 模块说明:           Description/tb_ppg_amb_recheck_scheduler_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_amb_recheck_scheduler
//
// 参考资料:           PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md、
//                     PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_amb_recheck_scheduler.v
//
// 当前版本:           V1.2
// 修订日期:           2026年10月08日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月08日        V1.0          Erie                  创建文件。
// 2026年08月11日        V1.0          Erie                  验证峰谷检测器空闲接管门禁。
// 2026年09月30日        V1.1          Erie                  TB维护（不改RTL）：RTL V1.1（2026/08/23）把输入i_adc_idle纯改名为i_precision_takeover_safe，逻辑不变，本TB因此无法elaborate（xelab报"cannot find port 'i_adc_idle'"，见REGRESSION_BASELINE_20260930.md第6.3节）。只改这一处具名端口连接，TB侧激励reg保持原名。结果：35条PASS（34条检查+1条最终汇总），0 FAIL（xsim与iverilog一致）。
// 2026年10月08日        V1.2          Erie                  owner生命周期轮第三步（F-020）：输入i_calibration_request_withdraw_event改为TB寄存器驱动；新增TB本地检查F020-WDRAW（两条PASS）：外层在途请求被撤销后内层在途释放，仍保持的AMB请求重新拉高valid并恰好再被接收一次。

// 覆盖周期计数、精度切换等待、固定三帧顺序、反压保持、异常终止和生命周期清理
module tb_ppg_amb_recheck_scheduler
(
);

	//-------------配置参数区域-------------//
	// 仿真使用100 MHz时钟缩短65535帧边界回归时间
	localparam integer C_CLK_PERIOD = 10;   // 主时钟周期为10 ns
	localparam [1:0]IDAC_MODE_MANUAL = 2'b00; // 手动模式必须忽略周期字段
	localparam [1:0]IDAC_MODE_HOLD = 2'b01; // 自动搜索保持模式不执行重检
	localparam [1:0]IDAC_MODE_TRACK = 2'b10; // 自动搜索跟踪模式允许重检
	localparam [1:0]FRAME_TYPE_AMB = 2'b00; // 环境光校准事务类别
	localparam [1:0]FRAME_TYPE_DCS = 2'b01; // 颜色DC校准事务类别
	localparam [1:0]CAL_STAGE_AMB = 2'b01; // 第一物理校准帧身份
	localparam [1:0]CAL_STAGE_DCS_R = 2'b10; // 第二物理校准帧身份
	localparam [1:0]CAL_STAGE_DCS_IR = 2'b11; // 第三物理校准帧身份

	//--------------寄存器信号--------------//
	// 全局、生命周期和ACTIVE输入由测试主过程驱动
	reg i_clk;                              // DUT仿真时钟
	reg i_rstn;                             // DUT低有效异步复位
	reg i_run_enable;                       // 当前测试RUN资格
	reg i_start_ack_event;                  // 新RUN初始化事件
	reg i_stop_ack_event;                   // STOP取消事件
	reg i_control_abort_event;              // 故障取消事件
	reg [1:0]i_idac_mode;                   // 当前IDAC工作模式
	reg i_amb_enable;                       // AMB路径使能
	reg i_dcs_enable;                       // 两色DCS路径使能
	reg [15:0]i_amb_recheck_interval_frames; // 周期完整NORMAL帧数

	// 完整帧、精度下降和安全接管条件由测试过程独立组合
	reg i_startup_search_complete;          // 启动搜索完成资格
	reg i_normal_measurement_active;        // 正式NORMAL测量活动资格
	reg i_normal_frame_complete_event;      // 完整400 Hz帧完成事件
	reg i_precision_15_to_9_event;          // 15-bit到9-bit切换事件
	reg i_adc_idle;                         // ADC流水空闲条件
	reg i_normal_fork_idle;                 // NORMAL fork排空条件
	reg i_idac_idle;                        // IDAC控制器空闲条件
	reg i_fir_idle;                         // FIR无保持输出且当前无输入握手
	reg i_peak_valley_idle;                 // 峰谷检测器没有待提交事件
	reg i_frame_safe_boundary;              // 帧级安全接管边界
	reg i_calibration_frame_complete_event; // 当前校准物理帧完成事件

	// IDAC序列状态和样本消费事件模拟真实控制器响应
	reg i_amb_sample_request;               // AMB样本保持请求
	reg i_amb_sequence_done;                // AMB阶段成功事件
	reg i_amb_sequence_failed;              // AMB阶段搜索耗尽事件
	reg i_dcs_revalidate_request;           // 两色DC重验证保持请求
	reg i_dcs_sample_request;               // 当前颜色DCS样本保持请求
	reg i_dcs_sample_color_ir;              // DCS请求颜色身份
	reg i_dcs_revalidate_done;              // 两色DC阶段整体成功事件
	reg i_dcs_revalidate_failed;            // 任一DC搜索耗尽事件
	reg i_amb_sample_accepted_event;        // AMB结果被IDAC入口接受事件
	reg i_dcs_sample_accepted_event;        // DCS结果被IDAC入口接受事件
	reg i_calibration_sample_ready;         // 模拟采样调度器ready
	reg i_calibration_request_withdraw_event; // owner生命周期轮F-020：外层请求被截止撤销或作废

	// 自检状态仅在测试平台内部记录观察结果
	integer cnt_error;                      // 全部断言失败累计数
	integer cnt_normal_event_loop;          // 65535帧边界循环索引
	integer cnt_frame_start;                // 真实校准帧启动次数
	integer cnt_sample_transfer;            // 校准样本valid/ready握手次数
	integer cnt_amb_start;                  // AMB序列启动事件次数
	integer cnt_dcs_accept;                 // DCS重验证accept次数
	integer cnt_sequence_done;              // 完整序列成功事件次数
	integer cnt_sequence_failed;            // 完整序列失败事件次数
	reg [5:0]enc_frame_order;               // 三次frame_start对应的阶段顺序
	reg flag_bad_frame_metadata;            // 任一启动拍类型或颜色不匹配

	//---------------其他信号---------------//
	// DUT全部输出均接出以检查合同可见行为
	wire o_amb_sequence_start;              // 观察AMB序列启动单拍
	wire o_dcs_revalidate_accept;           // 观察DCS重验证接纳单拍
	wire o_calibration_sample_valid;        // 观察保持型校准样本请求
	wire [1:0]o_calibration_frame_type;     // 观察AMB或DCS类别
	wire o_calibration_color_ir;            // 观察DCS颜色选择
	wire o_calibration_precision_mode;      // 观察强制SAR9精度
	wire o_calibration_frame_start;         // 观察物理校准帧启动事件
	wire [1:0]o_calibration_stage;          // 观察当前三帧阶段
	wire [15:0]o_normal_frame_count;        // 观察完整NORMAL帧累计值
	wire o_amb_recheck_pending;             // 观察到期保持请求
	wire o_amb_recheck_accept;              // 观察安全接管事件
	wire o_amb_recheck_busy;                // 观察活动序列占用
	wire o_normal_output_inhibit;           // 观察NORMAL输出抑制
	wire o_sequence_done;                   // 观察整体成功单拍
	wire o_sequence_failed;                 // 观察整体失败单拍
	wire o_scheduler_idle;                  // 观察调度器完全空闲状态

	//------------主要任务处理区域-----------//
	// 生成连续100 MHz方波供所有同步事件使用
	always begin
		#(C_CLK_PERIOD / 2) i_clk = ~i_clk; // 每5 ns翻转一次时钟
	end

	// 统计真实校准帧启动次数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_frame_start <= 0;              // 每次复位清除帧启动历史
		end else if(o_calibration_frame_start)begin
			cnt_frame_start <= cnt_frame_start + 1; // 仅启动事件累计一次
		end else begin
			cnt_frame_start <= cnt_frame_start; // 空闲拍保持累计值
		end
	end

	// 顺序编码逐次拼入AMB、DC_R和DC_IR阶段号
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			enc_frame_order <= 6'd0;           // 复位清除阶段顺序记录
		end else if(o_calibration_frame_start)begin
			enc_frame_order <= {enc_frame_order[3:0], o_calibration_stage}; // 保存最近三次阶段身份
		end else begin
			enc_frame_order <= enc_frame_order; // 非启动拍保持顺序记录
		end
	end

	// 任一frame_start拍的类型、颜色或精度不匹配即锁存错误
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_bad_frame_metadata <= 1'b0;   // 复位清除元数据错误
		end else if(o_calibration_frame_start &&
			!(((o_calibration_stage == CAL_STAGE_AMB) &&
				(o_calibration_frame_type == FRAME_TYPE_AMB) &&
				(o_calibration_color_ir == 1'b0)) ||
			((o_calibration_stage == CAL_STAGE_DCS_R) &&
				(o_calibration_frame_type == FRAME_TYPE_DCS) &&
				(o_calibration_color_ir == 1'b0)) ||
			((o_calibration_stage == CAL_STAGE_DCS_IR) &&
				(o_calibration_frame_type == FRAME_TYPE_DCS) &&
				o_calibration_color_ir)) || o_calibration_precision_mode)begin
			flag_bad_frame_metadata <= 1'b1;   // 锁存任何启动拍协议错误
		end else begin
			flag_bad_frame_metadata <= flag_bad_frame_metadata; // 合格拍不覆盖旧错误
		end
	end

	// 样本计数只接受valid和ready同拍的真实传输
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_sample_transfer <= 0;          // 复位清除采样传输历史
		end else if(o_calibration_sample_valid && i_calibration_sample_ready)begin
			cnt_sample_transfer <= cnt_sample_transfer + 1; // 记录一次模拟采样启动
		end else begin
			cnt_sample_transfer <= cnt_sample_transfer; // 反压和在途期间禁止重复计数
		end
	end

	// AMB启动、DCS接纳和整体结果分别计数以检查单拍属性
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_amb_start <= 0;                // 复位清除AMB启动次数
		end else if(o_amb_sequence_start)begin
			cnt_amb_start <= cnt_amb_start + 1; // 安全接管只应启动一次
		end else begin
			cnt_amb_start <= cnt_amb_start;    // 无启动事件时保持
		end
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_dcs_accept <= 0;               // 复位清除DCS接纳次数
		end else if(o_dcs_revalidate_accept)begin
			cnt_dcs_accept <= cnt_dcs_accept + 1; // 每轮只接受一次保持请求
		end else begin
			cnt_dcs_accept <= cnt_dcs_accept;  // 非接纳拍保持
		end
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_sequence_done <= 0;            // 复位清除成功事件次数
		end else if(o_sequence_done)begin
			cnt_sequence_done <= cnt_sequence_done + 1; // 三阶段闭合才累计成功
		end else begin
			cnt_sequence_done <= cnt_sequence_done; // 活动阶段保持
		end
	end

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_sequence_failed <= 0;          // 复位清除失败事件次数
		end else if(o_sequence_failed)begin
			cnt_sequence_failed <= cnt_sequence_failed + 1; // 搜索耗尽只累计一次
		end else begin
			cnt_sequence_failed <= cnt_sequence_failed; // 无故障拍保持
		end
	end

	// 对单个布尔条件执行可检索的自检报告
	task check_condition;
		input condition_value;               // 调用者提供的比较结果
		input [8 * 96 - 1:0]case_message;     // 输出对应合同场景名称
		begin
			if(condition_value === 1'b1)begin
				$display("PASS: %0s", case_message); // 合格检查立即报告
			end else begin
				cnt_error = cnt_error + 1;       // 失败检查累计到最终状态
				$display("FAIL: %0s", case_message); // 输出失败语义便于定位
			end
		end
	endtask

	// 复位跨越两个有效时钟沿并在释放后等待状态稳定
	task apply_reset;
		begin
			@(negedge i_clk);
			i_rstn = 1'b0;                    // 异步拉低复位
			repeat(2)@(negedge i_clk);
			i_rstn = 1'b1;                    // 在下降沿释放避免竞争
			@(negedge i_clk);
		end
	endtask

	// 产生一拍START确认并维持RUN资格
	task start_run;
		begin
			i_run_enable = 1'b1;              // 建立RUN电平资格
			@(negedge i_clk);
			i_start_ack_event = 1'b1;         // 发出新RUN初始化事件
			@(negedge i_clk);
			i_start_ack_event = 1'b0;         // 单拍结束后继续正式测量
		end
	endtask

	// 产生一个完整NORMAL帧完成事件
	task pulse_normal_frame;
		begin
			@(negedge i_clk);
			i_normal_frame_complete_event = 1'b1; // 跨越一个上升沿计入一帧
			@(negedge i_clk);
			i_normal_frame_complete_event = 1'b0; // 恢复空闲电平
		end
	endtask

	// 产生一拍15-bit到9-bit精度下降事件
	task pulse_precision_switch;
		begin
			@(negedge i_clk);
			i_precision_15_to_9_event = 1'b1; // 通知pending可以接管
			@(negedge i_clk);
			i_precision_15_to_9_event = 1'b0; // 切换事件不保持
		end
	endtask

	// 产生当前校准物理帧完成事件
	task pulse_calibration_frame_complete;
		begin
			@(negedge i_clk);
			i_calibration_frame_complete_event = 1'b1; // 保存当前阶段帧完成事实
			@(negedge i_clk);
			i_calibration_frame_complete_event = 1'b0; // 事件结束
		end
	endtask

	// 主测试依次执行禁用、边界、正常三帧、失败和STOP场景
	initial begin
		i_clk = 1'b0;                        // 初始化时钟低电平
		i_rstn = 1'b0;                       // 上电保持复位
		i_run_enable = 1'b0;                 // 上电不具备RUN资格
		i_start_ack_event = 1'b0;            // 清除START事件
		i_stop_ack_event = 1'b0;             // 清除STOP事件
		i_control_abort_event = 1'b0;        // 清除故障取消事件
		i_idac_mode = IDAC_MODE_TRACK;       // 默认选择周期跟踪模式
		i_amb_enable = 1'b1;                 // 默认启用AMB
		i_dcs_enable = 1'b1;                 // 默认启用两色DCS
		i_amb_recheck_interval_frames = 16'd0; // 默认关闭周期检查
		i_startup_search_complete = 1'b1;    // 默认认为启动搜索已完成
		i_normal_measurement_active = 1'b1;  // 默认允许正式NORMAL计数
		i_normal_frame_complete_event = 1'b0; // 清除完整帧事件
		i_precision_15_to_9_event = 1'b0;    // 清除精度切换事件
		i_adc_idle = 1'b1;                   // 默认ADC空闲
		i_normal_fork_idle = 1'b1;           // 默认fork已经排空
		i_idac_idle = 1'b1;                  // 默认IDAC无活动动作
		i_fir_idle = 1'b1;                   // 默认FIR没有待消费输出
		i_peak_valley_idle = 1'b1;           // 默认峰谷检测器允许重检接管
		i_frame_safe_boundary = 1'b1;        // 默认处于安全帧边界
		i_calibration_frame_complete_event = 1'b0; // 清除校准帧完成事件
		i_amb_sample_request = 1'b0;         // 清除AMB请求
		i_amb_sequence_done = 1'b0;          // 清除AMB成功事件
		i_amb_sequence_failed = 1'b0;        // 清除AMB失败事件
		i_dcs_revalidate_request = 1'b0;     // 清除DCS重验证请求
		i_dcs_sample_request = 1'b0;         // 清除DCS样本请求
		i_dcs_sample_color_ir = 1'b0;        // 默认选择红光
		i_dcs_revalidate_done = 1'b0;        // 清除DCS成功事件
		i_dcs_revalidate_failed = 1'b0;      // 清除DCS失败事件
		i_amb_sample_accepted_event = 1'b0;  // 清除AMB消费事件
		i_dcs_sample_accepted_event = 1'b0;  // 清除DCS消费事件
		i_calibration_sample_ready = 1'b0;   // 默认对样本施加反压
		i_calibration_request_withdraw_event = 1'b0; // 默认无外层撤销
		cnt_error = 0;                       // 初始化全局错误累计

		apply_reset;
		check_condition(o_scheduler_idle && !o_amb_recheck_pending &&
			!o_amb_recheck_busy && !o_normal_output_inhibit,
			"AMR reset clears pending, busy and inhibit");

		// interval为0时TRACK模式也不得累计或发起请求
		start_run;
		repeat(4)pulse_normal_frame;
		check_condition(!o_amb_recheck_pending && (o_normal_frame_count == 16'd0),
			"AMR-01 interval zero disables periodic counting");

		// MANUAL和HOLD模式均忽略非零周期字段
		apply_reset;
		i_amb_recheck_interval_frames = 16'd2;
		i_idac_mode = IDAC_MODE_MANUAL;
		start_run;
		repeat(3)pulse_normal_frame;
		check_condition(!o_amb_recheck_pending && (o_normal_frame_count == 16'd0),
			"AMR-02 MANUAL ignores interval field");
		apply_reset;
		i_idac_mode = IDAC_MODE_HOLD;
		start_run;
		repeat(3)pulse_normal_frame;
		check_condition(!o_amb_recheck_pending && (o_normal_frame_count == 16'd0),
			"AMR-02 HOLD ignores interval field");

		// 最大合法间隔在第65535个完整帧才锁存pending
		apply_reset;
		i_idac_mode = IDAC_MODE_TRACK;
		i_amb_recheck_interval_frames = 16'hffff;
		start_run;
		for(cnt_normal_event_loop = 0; cnt_normal_event_loop < 65534;
			cnt_normal_event_loop = cnt_normal_event_loop + 1)begin
			pulse_normal_frame;
		end
		check_condition(!o_amb_recheck_pending && (o_normal_frame_count == 16'hfffe),
			"interval 65535 remains inactive through frame 65534");
		pulse_normal_frame;
		check_condition(o_amb_recheck_pending && (o_normal_frame_count == 16'hffff),
			"interval 65535 includes terminal frame before pending");

		// 标准三帧流程先证明N-1不请求且第N帧保持pending
		apply_reset;
		i_amb_recheck_interval_frames = 16'd3;
		start_run;
		repeat(2)pulse_normal_frame;
		check_condition(!o_amb_recheck_pending && (o_normal_frame_count == 16'd2),
			"AMR-03 N minus one frames do not request recheck");
		pulse_normal_frame;
		check_condition(o_amb_recheck_pending && (o_normal_frame_count == 16'd3),
			"AMR-04 Nth frame latches persistent pending");
		pulse_normal_frame;
		check_condition(o_amb_recheck_pending && !o_amb_recheck_busy &&
			!o_normal_output_inhibit && (o_normal_frame_count == 16'd3),
			"AMR-05 pending waits switch without blocking NORMAL output");

		// 精度下降当拍立即抑制新NORMAL，但排空未完成时不得启动AMB
		i_adc_idle = 1'b0;
		@(negedge i_clk);
		i_precision_15_to_9_event = 1'b1;
		#1;
		check_condition(o_normal_output_inhibit,
			"precision switch cycle immediately inhibits new NORMAL launch");
		@(negedge i_clk);
		i_precision_15_to_9_event = 1'b0;
		check_condition(o_amb_recheck_busy && (cnt_amb_start == 0),
			"AMR-06 switch waits until ADC and fork are drained");
		i_adc_idle = 1'b1;
		i_fir_idle = 1'b0;
		i_frame_safe_boundary = 1'b0;
		repeat(2)@(negedge i_clk);
		check_condition(cnt_amb_start == 0,
			"takeover waits while FIR output is held");
		i_frame_safe_boundary = 1'b1;
		repeat(2)@(negedge i_clk);
		check_condition(cnt_amb_start == 0 && !o_amb_recheck_accept,
			"FIR-held recheck remains pending after frame boundary is safe");
		i_fir_idle = 1'b1;
		i_peak_valley_idle = 1'b0;
		repeat(2)@(negedge i_clk);
		check_condition(cnt_amb_start == 0 && !o_amb_recheck_accept,
			"peak-valley held event blocks recheck after FIR drains");
		i_peak_valley_idle = 1'b1;
		#1;
		check_condition(o_amb_sequence_start && o_amb_recheck_accept,
			"FIR and peak-valley idle permit AMB takeover");

		// 安全接管启动第一帧并检查AMB valid在反压期间保持
		check_condition(o_amb_sequence_start && o_amb_recheck_accept &&
			o_calibration_frame_start &&
			(o_calibration_frame_type == FRAME_TYPE_AMB),
			"safe takeover starts AMB frame with AMB metadata");
		@(negedge i_clk);
		i_amb_sample_request = 1'b1;
		i_calibration_sample_ready = 1'b0;
		repeat(3)@(posedge i_clk);
		#1;
		check_condition(o_calibration_sample_valid &&
			(cnt_sample_transfer == 0) && !o_calibration_precision_mode,
			"AMB sample valid holds through downstream backpressure");
		@(negedge i_clk);
		i_calibration_sample_ready = 1'b1;
		@(negedge i_clk);
		i_calibration_sample_ready = 1'b0;
		check_condition((cnt_sample_transfer == 1) && !o_calibration_sample_valid,
			"one accepted AMB request creates one inflight sample");
		repeat(2)@(negedge i_clk);
		check_condition((cnt_sample_transfer == 1) && !o_calibration_sample_valid,
			"held IDAC request cannot duplicate an inflight conversion");
		// F020-WDRAW（owner生命周期轮F-020，TB本地名）：在途样本的外层请求被SID-05截止撤销或owner超时作废时，内层在途必须释放，
		// 仍保持的IDAC请求随即重新拉高valid；再握手一次后在途恢复，后续匹配结果照常释放
		@(negedge i_clk);
		i_calibration_request_withdraw_event = 1'b1;
		@(negedge i_clk);
		i_calibration_request_withdraw_event = 1'b0;
		check_condition(o_calibration_sample_valid && (cnt_sample_transfer == 1),
			"F020-WDRAW withdrawn inflight request re-raises the held AMB sample request");
		i_calibration_sample_ready = 1'b1;
		@(negedge i_clk);
		i_calibration_sample_ready = 1'b0;
		check_condition((cnt_sample_transfer == 2) && !o_calibration_sample_valid,
			"F020-WDRAW re-issued request is accepted once and holds inflight again");
		i_amb_sample_accepted_event = 1'b1;
		@(negedge i_clk);
		i_amb_sample_accepted_event = 1'b0;
		check_condition(o_calibration_sample_valid,
			"matching AMB result releases inflight ownership for next evidence");
		i_amb_sample_request = 1'b0;

		// 帧完成先于数字结果时必须保存事实，并在AMB成功后固定进入DC_R
		pulse_calibration_frame_complete;
		check_condition(o_amb_recheck_busy && (cnt_dcs_accept == 0),
			"AMB frame completion waits for digital sequence result");
		@(negedge i_clk);
		i_amb_sequence_done = 1'b1;
		@(negedge i_clk);
		i_amb_sequence_done = 1'b0;
		i_dcs_revalidate_request = 1'b1;
		#1;
		check_condition(o_dcs_revalidate_accept && o_calibration_frame_start &&
			(o_calibration_stage == CAL_STAGE_DCS_R) &&
			(o_calibration_frame_type == FRAME_TYPE_DCS) &&
			!o_calibration_color_ir,
			"AMR-07 and AMR-10 always continue with DC_R frame");
		@(negedge i_clk);
		i_dcs_revalidate_request = 1'b0;

		// 红光结果先切换为IR请求，物理红光帧结束后才允许启动第三帧
		i_dcs_sample_request = 1'b1;
		i_dcs_sample_color_ir = 1'b0;
		i_calibration_sample_ready = 1'b1;
		@(negedge i_clk);
		i_calibration_sample_ready = 1'b0;
		i_dcs_sample_accepted_event = 1'b1;
		@(negedge i_clk);
		i_dcs_sample_accepted_event = 1'b0;
		i_dcs_sample_color_ir = 1'b1;
		repeat(2)@(negedge i_clk);
		check_condition((cnt_frame_start == 2) && !o_calibration_sample_valid,
			"DC_R digital completion cannot start IR before frame boundary");
		@(negedge i_clk);
		i_calibration_frame_complete_event = 1'b1;
		#1;
		check_condition(o_calibration_frame_start &&
			(o_calibration_stage == CAL_STAGE_DCS_IR) &&
			o_calibration_color_ir,
			"DC_IR frame start carries IR color on the transition cycle");
		@(negedge i_clk);
		i_calibration_frame_complete_event = 1'b0;
		check_condition(o_calibration_sample_valid && o_calibration_color_ir,
			"third frame serves pending IR calibration request");

		// 最后一帧允许数字结果先到，物理帧闭合后产生单拍成功
		i_calibration_sample_ready = 1'b1;
		@(negedge i_clk);
		i_calibration_sample_ready = 1'b0;
		i_dcs_sample_accepted_event = 1'b1;
		@(negedge i_clk);
		i_dcs_sample_accepted_event = 1'b0;
		i_dcs_sample_request = 1'b0;
		i_dcs_revalidate_done = 1'b1;
		@(negedge i_clk);
		i_dcs_revalidate_done = 1'b0;
		check_condition((cnt_sequence_done == 0) && o_amb_recheck_busy,
			"DC result completion waits for final physical frame boundary");
		pulse_calibration_frame_complete;
		check_condition((cnt_sequence_done == 1) && (cnt_frame_start == 3) &&
			(enc_frame_order == 6'b011011) && !flag_bad_frame_metadata,
			"AMR-11 fixed AMB DC_R DC_IR frame order and metadata");
		check_condition(!o_amb_recheck_pending && !o_amb_recheck_busy &&
			!o_normal_output_inhibit && o_scheduler_idle &&
			(o_normal_frame_count == 16'd0),
			"successful sequence clears pending and restarts interval count");

		// interval=1与切换同拍时不得丢失精度下降事件
		apply_reset;
		i_amb_recheck_interval_frames = 16'd1;
		start_run;
		i_adc_idle = 1'b0;
		@(negedge i_clk);
		i_normal_frame_complete_event = 1'b1;
		i_precision_15_to_9_event = 1'b1;
		#1;
		check_condition(o_normal_output_inhibit,
			"same-cycle interval hit and switch asserts takeover inhibit");
		@(negedge i_clk);
		i_normal_frame_complete_event = 1'b0;
		i_precision_15_to_9_event = 1'b0;
		check_condition(o_amb_recheck_pending && o_amb_recheck_busy,
			"same-cycle interval hit and switch enters drain wait");

		// AMB搜索耗尽立即终止活动序列并清除周期pending
		i_adc_idle = 1'b1;
		i_frame_safe_boundary = 1'b1;
		@(negedge i_clk);
		@(negedge i_clk);
		i_amb_sequence_failed = 1'b1;
		@(negedge i_clk);
		i_amb_sequence_failed = 1'b0;
		check_condition((cnt_sequence_failed == 1) &&
			!o_amb_recheck_pending && o_scheduler_idle,
			"AMR-12 search exhausted terminates and releases scheduler");

		// DCS禁用时只执行AMB帧并在结果和帧均完成后成功
		apply_reset;
		i_dcs_enable = 1'b0;
		i_amb_recheck_interval_frames = 16'd1;
		start_run;
		pulse_normal_frame;
		pulse_precision_switch;
		@(negedge i_clk);
		i_amb_sequence_done = 1'b1;
		i_calibration_frame_complete_event = 1'b1;
		@(negedge i_clk);
		i_amb_sequence_done = 1'b0;
		i_calibration_frame_complete_event = 1'b0;
		check_condition((cnt_frame_start == 1) && (cnt_sequence_done == 1) &&
			!o_amb_recheck_pending,
			"DCS disabled closes periodic sequence after AMB stage");

		// STOP既能清除等待切换的pending，也能取消已经接管的活动序列
		apply_reset;
		i_dcs_enable = 1'b1;
		i_amb_recheck_interval_frames = 16'd1;
		start_run;
		pulse_normal_frame;
		@(negedge i_clk);
		i_stop_ack_event = 1'b1;
		@(negedge i_clk);
		i_stop_ack_event = 1'b0;
		check_condition(!o_amb_recheck_pending && o_scheduler_idle,
			"AMR-14 STOP clears pending while waiting for switch");
		start_run;
		pulse_normal_frame;
		pulse_precision_switch;
		@(negedge i_clk);
		i_stop_ack_event = 1'b1;
		@(negedge i_clk);
		i_stop_ack_event = 1'b0;
		check_condition(!o_amb_recheck_pending && !o_amb_recheck_busy &&
			!o_normal_output_inhibit && o_scheduler_idle,
			"STOP clears active takeover without false completion");

		if(cnt_error == 0)begin
			$display("PASS: ppg_amb_recheck_scheduler completed scheduler regression"); // 仅所有比较通过时报告总成功
		end else begin
			$display("FAIL: ppg_amb_recheck_scheduler found %0d errors", cnt_error); // 汇总失败数量
		end
		$finish;                             // 正常结束自检仿真
	end

	// 独立看门狗防止握手或循环异常导致仿真悬挂
	initial begin
		#5000000;                            // 覆盖最大间隔回归并保留充足余量
		$display("FAIL: ppg_amb_recheck_scheduler simulation timeout"); // 超时视为测试失败
		$finish;                             // 强制终止未收敛仿真
	end

	//------------模块实例化区域-------------//
	// 实例化周期重检调度器并逐端口连接冻结接口
	ppg_amb_recheck_scheduler ppg_amb_recheck_scheduler_Inst_dut(
		.i_clk(i_clk),                                           // 连接测试主时钟
		.i_rstn(i_rstn),                                         // 连接低有效异步复位
		.i_run_enable(i_run_enable),                             // 连接RUN资格
		.i_start_ack_event(i_start_ack_event),                   // 连接START初始化事件
		.i_stop_ack_event(i_stop_ack_event),                     // 连接STOP取消事件
		.i_control_abort_event(i_control_abort_event),           // 连接故障取消事件
		.i_idac_mode(i_idac_mode),                               // 连接IDAC模式
		.i_amb_enable(i_amb_enable),                             // 连接AMB使能
		.i_dcs_enable(i_dcs_enable),                             // 连接DCS使能
		.i_amb_recheck_interval_frames(i_amb_recheck_interval_frames), // 连接周期帧数
		.i_startup_search_complete(i_startup_search_complete),   // 连接启动资格
		.i_normal_measurement_active(i_normal_measurement_active), // 连接NORMAL活动资格
		.i_normal_frame_complete_event(i_normal_frame_complete_event), // 连接完整帧事件
		.i_precision_15_to_9_event(i_precision_15_to_9_event),   // 连接精度下降事件
		.i_precision_takeover_safe(i_adc_idle),                  // V1.1:RTL V1.1已把i_adc_idle纯改名为i_precision_takeover_safe，TB侧激励变量名保持不变
		.i_normal_fork_idle(i_normal_fork_idle),                 // 连接fork排空条件
		.i_idac_idle(i_idac_idle),                               // 连接IDAC空闲条件
		.i_fir_idle(i_fir_idle),                                 // 连接FIR安全接管空闲条件
		.i_peak_valley_idle(i_peak_valley_idle),                 // 连接峰谷检测器安全空闲条件
		.i_frame_safe_boundary(i_frame_safe_boundary),           // 连接安全帧边界
		.i_calibration_frame_complete_event(i_calibration_frame_complete_event), // 连接校准帧完成
		.i_amb_sample_request(i_amb_sample_request),             // 连接AMB样本请求
		.i_amb_sequence_done(i_amb_sequence_done),               // 连接AMB成功事件
		.i_amb_sequence_failed(i_amb_sequence_failed),           // 连接AMB失败事件
		.i_dcs_revalidate_request(i_dcs_revalidate_request),     // 连接DCS重验证请求
		.i_dcs_sample_request(i_dcs_sample_request),             // 连接DCS样本请求
		.i_dcs_sample_color_ir(i_dcs_sample_color_ir),           // 连接DCS颜色身份
		.i_dcs_revalidate_done(i_dcs_revalidate_done),           // 连接DCS成功事件
		.i_dcs_revalidate_failed(i_dcs_revalidate_failed),       // 连接DCS失败事件
		.i_amb_sample_accepted_event(i_amb_sample_accepted_event), // 连接AMB消费事件
		.i_dcs_sample_accepted_event(i_dcs_sample_accepted_event), // 连接DCS消费事件
		.i_calibration_request_withdraw_event(i_calibration_request_withdraw_event), // owner生命周期轮F-020撤销输入，仅F020-WDRAW段驱动
		.o_amb_sequence_start(o_amb_sequence_start),             // 观察AMB启动单拍
		.o_dcs_revalidate_accept(o_dcs_revalidate_accept),       // 观察DCS接纳单拍
		.i_calibration_sample_ready(i_calibration_sample_ready), // 驱动下游ready
		.o_calibration_sample_valid(o_calibration_sample_valid), // 观察保持型valid
		.o_calibration_frame_type(o_calibration_frame_type),     // 观察校准类别
		.o_calibration_color_ir(o_calibration_color_ir),         // 观察颜色身份
		.o_calibration_precision_mode(o_calibration_precision_mode), // 观察固定SAR9选择
		.o_calibration_frame_start(o_calibration_frame_start),   // 观察物理帧启动
		.o_calibration_stage(o_calibration_stage),               // 观察三阶段身份
		.o_normal_frame_count(o_normal_frame_count),             // 观察帧计数值
		.o_amb_recheck_pending(o_amb_recheck_pending),           // 观察pending保持
		.o_amb_recheck_accept(o_amb_recheck_accept),             // 观察安全接管事件
		.o_amb_recheck_busy(o_amb_recheck_busy),                 // 观察活动占用
		.o_normal_output_inhibit(o_normal_output_inhibit),       // 观察NORMAL抑制
		.o_sequence_done(o_sequence_done),                       // 观察整体成功
		.o_sequence_failed(o_sequence_failed),                   // 观察整体失败
		.o_scheduler_idle(o_scheduler_idle)                      // 观察完全空闲
	);

endmodule
