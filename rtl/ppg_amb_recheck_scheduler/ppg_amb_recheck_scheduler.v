`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/08
// Design Name:        PPG AMB Recheck Scheduler
// Module Name:        ppg_amb_recheck_scheduler
// Description:        Description/ppg_amb_recheck_scheduler_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_amb_recheck_scheduler
//
// Referrences:        PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md,
//                     PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_system_active_config_unpack.v,
//                     ppg_idac_code_controller.v,
//                     ppg_peak_valley_window_detector.v
//
// Version:            V1.1
// Revision Date:      2026/08/23
// History:
//    Time               Version       Revised by            Contents
// 2026/08/08            V1.0          Erie                  Create file.
// 2026/08/11            V1.0          Erie                  Add peak-valley idle takeover gate.
// 2026/08/23            V1.1          Erie                  Rename i_adc_idle to i_precision_takeover_safe (pure port rename, no logic change) to match the AMI/PWI composite switch-safety predicate naming used by PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md and PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md; the connected value was already PWI's forwarded AMI composite, never physical ADC idle.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月08日
// 设计名称:           PPG环境光周期重检调度器
// 模块名称:           ppg_amb_recheck_scheduler
// 模块说明:           Description/ppg_amb_recheck_scheduler_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_amb_recheck_scheduler
//
// 参考资料:           PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md、
//                     PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_system_active_config_unpack.v、
//                     ppg_idac_code_controller.v、
//                     ppg_peak_valley_window_detector.v
//
// 当前版本:           V1.1
// 修订日期:           2026年08月23日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月08日        V1.0          Erie                  创建文件。
// 2026年08月11日        V1.0          Erie                  增加峰谷检测器空闲接管门禁。
// 2026年08月23日        V1.1          Erie                  把i_adc_idle改名为i_precision_takeover_safe（纯端口改名，不改逻辑），和PWI/精度控制器合同里的复合切换安全资格命名保持一致——该端口连接的值本来就是PWI转发的AMI复合资格，从未是物理ADC空闲
// 在完整NORMAL帧间隔到期后等待15-bit到9-bit切换，并调度AMB、DC_R和DC_IR三个校准帧
module ppg_amb_recheck_scheduler
(
	//-----------------全局信号-----------------//
	input i_clk,                                // 2 MHz系统控制时钟
	input i_rstn,                               // 低有效异步复位输入

	//---------------生命周期接口---------------//
	input i_run_enable,                         // 配置管理器确认当前处于RUN
	input i_start_ack_event,                    // 合法START接受后的单周期初始化事件
	input i_stop_ack_event,                     // STOP进入排空流程的单周期取消事件
	input i_control_abort_event,                // 系统故障要求终止临时调度动作

	//--------------ACTIVE配置接口--------------//
	input [1:0]i_idac_mode,                     // 仅AUTO_SEARCH_TRACK编码10允许周期重检
	input i_amb_enable,                         // 允许环境光码参与当前RUN
	input i_dcs_enable,                         // 允许红光和红外DC固定重新确认
	input [15:0]i_amb_recheck_interval_frames,  // ACTIVE V4给出的完整NORMAL帧间隔

	//---------------帧与排空接口---------------//
	input i_startup_search_complete,            // IDAC启动三路搜索已经建立正式资格
	input i_normal_measurement_active,          // 当前允许统计完整NORMAL测量帧
	input i_normal_frame_complete_event,        // 每完成一帧400 Hz NORMAL测量产生单拍
	input i_precision_15_to_9_event,            // 下一次15-bit到9-bit安全切换事件
	input i_precision_takeover_safe,            // PWI原样转发AMI复合资格：ADC事务与内部流水已经排空；不是物理idle事实
	input i_normal_fork_idle,                   // NORMAL双消费者fork当前无占用
	input i_idac_idle,                          // IDAC无pending、请求或提交动作
	input i_fir_idle,                           // FIR无待消费输出且当前不接收输入
	input i_peak_valley_idle,                   // 峰谷检测器无待提交事件且允许重检接管
	input i_frame_safe_boundary,                // 当前沿允许接管校准序列
	input i_calibration_frame_complete_event,   // 当前AMB或DC校准帧已经完整结束

	//---------------IDAC序列接口---------------//
	input i_amb_sample_request,                 // IDAC保持请求下一笔AMB_CAL样本
	input i_amb_sequence_done,                  // AMB检查或重搜索成功单拍
	input i_amb_sequence_failed,                // AMB搜索耗尽失败单拍
	input i_dcs_revalidate_request,             // IDAC保持请求进入固定两色重验证
	input i_dcs_sample_request,                 // IDAC保持请求当前颜色DCS_CAL样本
	input i_dcs_sample_color_ir,                // 低为DC_R请求且高为DC_IR请求
	input i_dcs_revalidate_done,                // DC_R和DC_IR均完成的成功单拍
	input i_dcs_revalidate_failed,              // 任一DC搜索耗尽的失败单拍
	input i_amb_sample_accepted_event,          // 匹配AMB_CAL结果完成控制器消费
	input i_dcs_sample_accepted_event,          // 当前颜色DCS_CAL结果完成控制器消费
	output o_amb_sequence_start,                // 安全接管后启动AMB周期检查的单拍
	output o_dcs_revalidate_accept,             // 第一帧完成后接受两色DC重验证的单拍

	//-------------校准样本调度接口-------------//
	input i_calibration_sample_ready,           // 模拟时序调度器可接受一笔SAR9校准请求
	output o_calibration_sample_valid,          // 保持一笔AMB_CAL或DCS_CAL采样请求
	output [1:0]o_calibration_frame_type,       // 00为AMB_CAL且01为DCS_CAL
	output o_calibration_color_ir,              // DCS_CAL低为红光且高为红外
	output o_calibration_precision_mode,        // 周期重检固定输出低电平选择SAR9
	output o_calibration_frame_start,           // AMB、DC_R或DC_IR校准帧开始单拍
	output [1:0]o_calibration_stage,            // 00空闲、01 AMB、10 DC_R、11 DC_IR

	//---------------状态输出接口---------------//
	output [15:0]o_normal_frame_count,          // 当前周期已经累计的完整NORMAL帧数

	//AMB_RECHECK接口
	output o_amb_recheck_pending,               // 间隔到期后保持至成功、失败或取消
	output o_amb_recheck_accept,                // 15到9切换后安全接管成功单拍
	output o_amb_recheck_busy,                  // 从停止新NORMAL到最终帧结束保持有效
	output o_normal_output_inhibit,             // 三个校准帧期间禁止输出正式PPG事务
	output o_sequence_done,                     // 固定重检序列成功完成单拍
	output o_sequence_failed,                   // 任一搜索耗尽导致的失败单拍
	output o_scheduler_idle                     // 无pending、序列或在途样本时为高
);

	//---------------配置参数区域---------------//
	// ACTIVE编码和事务类别在系统合同中固定
	localparam [1:0]IDAC_MODE_TRACK = 2'b10;    // AUTO_SEARCH_TRACK模式编码
	localparam [1:0]FRAME_TYPE_AMB = 2'b00;     // LED关闭环境光校准类别编码
	localparam [1:0]FRAME_TYPE_DCS = 2'b01;     // 红光或红外直流校准类别编码
	localparam [1:0]CAL_STAGE_IDLE = 2'b00;     // 正常测量或等待切换阶段
	localparam [1:0]CAL_STAGE_AMB = 2'b01;      // 第一个校准帧处理环境光
	localparam [1:0]CAL_STAGE_DCS_R = 2'b10;    // 第二个校准帧处理红光DC
	localparam [1:0]CAL_STAGE_DCS_IR = 2'b11;   // 第三个校准帧处理红外DC

	//---------------状态参数区域---------------//
	// 七个状态分离计数、切换等待、排空和三个物理校准阶段
	localparam [2:0]ST_MONITOR = 3'd0;          // 统计正式NORMAL帧并等待间隔到期
	localparam [2:0]ST_WAIT_SWITCH = 3'd1;      // pending保持并等待下一次15到9切换
	localparam [2:0]ST_WAIT_DRAIN = 3'd2;       // 已锁存切换且禁止新NORMAL进入
	localparam [2:0]ST_AMB = 3'd3;              // 第一帧服务AMB检查或受限搜索
	localparam [2:0]ST_WAIT_DCS_ACCEPT = 3'd4;  // 第一帧结束后等待IDAC重验证请求
	localparam [2:0]ST_DCS_R = 3'd5;            // 第二帧只服务红光DCS样本
	localparam [2:0]ST_DCS_IR = 3'd6;           // 第三帧只服务红外DCS样本

	//----------------状态机信号----------------//
	reg [2:0]state_current;                     // 当前周期重检调度阶段
	reg [2:0]state_next;                        // 下一拍调度阶段选择

	//-----------------标志信号-----------------//
	reg flag_stage_result_done;                 // 当前校准阶段的数字判断已经完成
	reg flag_stage_frame_complete;              // 当前校准阶段对应物理帧已经结束
	reg flag_sample_inflight;                   // 已发出请求且等待匹配结果事务返回
	wire flag_control_cancel;                   // STOP、abort或离开RUN统一取消序列
	wire flag_period_enabled;                   // 当前ACTIVE和生命周期允许帧计数
	wire flag_interval_hit;                     // 本笔NORMAL完成事件达到配置间隔
	wire flag_takeover_safe;                    // ADC、fork、IDAC、FIR、峰谷检测器和帧边界同时空闲
	wire flag_stage_result_available;           // 当前拍或历史已经得到阶段完成结果
	wire flag_stage_frame_available;            // 当前拍或历史已经观察物理帧完成
	wire flag_switch_takeover;                  // pending与精度下降同拍锁存NORMAL接管
	wire flag_enter_ir;                         // 红光帧完成后进入红外帧的事件
	wire flag_calibration_transfer;             // 校准样本请求被模拟调度器接受
	wire flag_matching_sample_accepted;         // 在途样本已经由IDAC入口实际消费
	wire flag_enter_amb;                        // 从排空等待进入AMB第一帧的事件

	//-----------------其他信号-----------------//

	//-----------------输出信号-----------------//
	//IDAC序列接口
	wire dcs_revalidate_accept_o;               // 接受IDAC固定两色重验证的事件

	//状态输出接口
	reg [15:0]cnt_normal_frame_o;               // 从最近一次启动或重检完成开始累计
	reg amb_recheck_pending_o;                  // 周期间隔已经到达且尚未闭合
	wire amb_recheck_busy_o;                    // 已接管NORMAL且三帧尚未全部结束
	wire enc_sequence_done_o;                   // 最后一个启用阶段与物理帧均已完成
	wire enc_sequence_failed_o;                 // AMB或DCS控制器报告搜索耗尽

	//---------------其他信号连线---------------//
	// 生命周期和模式资格只影响新计数，不扰动等待切换前的既有pending
	assign flag_control_cancel = i_stop_ack_event || i_control_abort_event || (i_run_enable == 1'b0); // 汇总必须立即清理调度上下文的条件

	//其他信号连线
	assign flag_period_enabled = i_run_enable && (i_idac_mode == IDAC_MODE_TRACK) && i_amb_enable && (i_amb_recheck_interval_frames != 16'd0) && i_startup_search_complete && i_normal_measurement_active; // 限定正式TRACK帧才能累计；NRE-01 interval=0时本条件结构性恒为0，下游pending/accept/busy/done/failed全部保持复位值 @satisfies: NRE-01
	assign flag_interval_hit = (state_current == ST_MONITOR) && (amb_recheck_pending_o == 1'b0) && flag_period_enabled && i_normal_frame_complete_event && (cnt_normal_frame_o >= (i_amb_recheck_interval_frames - 16'd1)); // 当前完整帧达到ACTIVE周期
	assign flag_takeover_safe = i_precision_takeover_safe && i_normal_fork_idle && i_idac_idle && i_fir_idle && i_peak_valley_idle && i_frame_safe_boundary; // 六项同时成立才允许启动校准；RRC-03 accept在ADC/NORMAL fork/IDAC/FIR/峰谷检测器/帧边界全部排空前保持低电平的真实门禁 @satisfies: RRC-03

	//其他信号连线
	assign flag_stage_result_available = flag_stage_result_done || ((state_current == ST_AMB) && i_amb_sequence_done) || ((state_current == ST_DCS_R) && i_dcs_sample_request && i_dcs_sample_color_ir) || ((state_current == ST_DCS_IR) && i_dcs_revalidate_done); // 汇合三个阶段各自的完成判据
	assign flag_stage_frame_available = flag_stage_frame_complete || i_calibration_frame_complete_event; // 允许结果与帧完成任意先后到达

	//其他信号连线
	assign flag_enter_amb = (state_current == ST_WAIT_DRAIN) && flag_takeover_safe && (flag_control_cancel == 1'b0); // 仅安全边界产生一次AMB启动
	assign flag_switch_takeover = ((state_current == ST_MONITOR) && (amb_recheck_pending_o || flag_interval_hit) && i_precision_15_to_9_event) || ((state_current == ST_WAIT_SWITCH) && i_precision_15_to_9_event); // 精度下降沿立即阻止新NORMAL进入；NRE-04 pending/interval_hit结构性恒为0时本条件唯一入口被封死，SAR15->9真实回落事件不受周期重检接管干扰 @satisfies: NRE-04
	assign dcs_revalidate_accept_o = (state_current == ST_WAIT_DCS_ACCEPT) && i_dcs_enable && i_dcs_revalidate_request; // 第一帧闭合后接受DC_R阶段
	assign flag_enter_ir = (state_current == ST_DCS_R) && flag_stage_result_available && flag_stage_frame_available; // 红光结果和帧均结束后切到红外
	assign amb_recheck_busy_o = (state_current == ST_WAIT_DRAIN) || (state_current == ST_AMB) || (state_current == ST_WAIT_DCS_ACCEPT) || (state_current == ST_DCS_R) || (state_current == ST_DCS_IR); // 切换后至最终帧结束均抑制NORMAL

	//其他信号连线
	assign enc_sequence_done_o = ((state_current == ST_AMB) && (i_dcs_enable == 1'b0) && flag_stage_result_available && flag_stage_frame_available) || ((state_current == ST_WAIT_DCS_ACCEPT) && (i_dcs_enable == 1'b0)) || ((state_current == ST_DCS_IR) && flag_stage_result_available && flag_stage_frame_available); // 最后启用阶段完成才报告整体成功
	assign enc_sequence_failed_o = ((state_current == ST_AMB) && i_amb_sequence_failed) || (((state_current == ST_WAIT_DCS_ACCEPT) || (state_current == ST_DCS_R) || (state_current == ST_DCS_IR)) && i_dcs_revalidate_failed); // 搜索耗尽立即终止三帧上下文
	assign flag_calibration_transfer = o_calibration_sample_valid && i_calibration_sample_ready; // ready和valid同拍完成一次调度请求

	//其他信号连线
	assign flag_matching_sample_accepted = ((state_current == ST_AMB) && i_amb_sample_accepted_event) || (((state_current == ST_DCS_R) || (state_current == ST_DCS_IR)) && i_dcs_sample_accepted_event); // 仅当前阶段的返回事务解除在途锁

	//---------------输出信号连线---------------//
	//IDAC序列接口
	// IDAC序列握手事件与安全接管状态直接对应
	assign o_amb_sequence_start = flag_enter_amb; // 向IDAC启动一次周期AMB上下文
	assign o_dcs_revalidate_accept = dcs_revalidate_accept_o; // 向IDAC确认进入固定两色重验证

	//校准样本调度接口
	// 校准样本valid在下游反压和转换返回期间保持单笔所有权
	assign o_calibration_sample_valid = ((state_current == ST_AMB) && i_amb_sample_request && (flag_sample_inflight == 1'b0) && (flag_stage_result_available == 1'b0)) || ((state_current == ST_DCS_R) && i_dcs_sample_request && (i_dcs_sample_color_ir == 1'b0) && (flag_sample_inflight == 1'b0) && (flag_stage_result_available == 1'b0)) || ((state_current == ST_DCS_IR) && i_dcs_sample_request && i_dcs_sample_color_ir && (flag_sample_inflight == 1'b0) && (flag_stage_result_available == 1'b0)); // 每个保持请求只允许一笔样本在途
	assign o_calibration_frame_type = ((state_current == ST_WAIT_DRAIN) || (state_current == ST_AMB)) ? FRAME_TYPE_AMB : FRAME_TYPE_DCS; // AMB阶段与两色DCS阶段使用既有类别编码
	assign o_calibration_color_ir = flag_enter_ir || (state_current == ST_DCS_IR); // 第三帧启动拍和活动期均选择红外颜色
	assign o_calibration_precision_mode = 1'b0; // 所有周期重检事务强制采用SAR9
	assign o_calibration_frame_start = flag_enter_amb || dcs_revalidate_accept_o || flag_enter_ir; // 三个物理校准帧分别产生一次开始事件
	assign o_calibration_stage = flag_enter_ir ? CAL_STAGE_DCS_IR : (((state_current == ST_WAIT_DRAIN) || (state_current == ST_AMB)) ? CAL_STAGE_AMB : (((state_current == ST_WAIT_DCS_ACCEPT) || (state_current == ST_DCS_R)) ? CAL_STAGE_DCS_R : ((state_current == ST_DCS_IR) ? CAL_STAGE_DCS_IR : CAL_STAGE_IDLE))); // 输出当前或正进入的校准阶段

	//状态输出接口
	// 状态和诊断输出不拥有任何模拟码值
	assign o_normal_frame_count = cnt_normal_frame_o; // 导出已完成NORMAL帧累计值
	assign o_amb_recheck_pending = amb_recheck_pending_o; // 导出到期保持请求
	assign o_amb_recheck_accept = flag_enter_amb; // 向系统报告pending已被安全接管
	assign o_amb_recheck_busy = amb_recheck_busy_o; // 导出已接管的三帧活动状态
	assign o_normal_output_inhibit = amb_recheck_busy_o || flag_switch_takeover; // 精度下降接管当拍起屏蔽正式PPG输出资格；RRC-08 accept至序列终止全程禁止任何正式NORMAL输出 @satisfies: RRC-08
	assign o_sequence_done = enc_sequence_done_o; // 输出三阶段闭合成功单拍
	assign o_sequence_failed = enc_sequence_failed_o; // 输出任一路搜索耗尽单拍
	assign o_scheduler_idle = (state_current == ST_MONITOR) && (amb_recheck_pending_o == 1'b0) && (flag_sample_inflight == 1'b0); // 仅完全无事务时允许上层排空

	//-------------输出信号处理区域-------------//
	//状态输出接口
	// 完整NORMAL帧计数只在监测状态和正式资格下递增
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_normal_frame_o <= 16'd0;        // 复位清除周期累计
		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1)begin
			cnt_normal_frame_o <= 16'd0;        // 新RUN、取消或序列结束重新计时
		end else if(flag_interval_hit == 1'b1)begin
			cnt_normal_frame_o <= i_amb_recheck_interval_frames; // 到期帧计入累计值并冻结等待序列
		end else if((state_current == ST_MONITOR) && (amb_recheck_pending_o == 1'b0) && flag_period_enabled == 1'b1 && i_normal_frame_complete_event == 1'b1)begin
			cnt_normal_frame_o <= cnt_normal_frame_o + 16'd1; // 每笔完整NORMAL帧累计一次
		end else begin
			cnt_normal_frame_o <= cnt_normal_frame_o; // 非计数条件保持历史值
		end
	end

	// 周期pending跨越精度等待和三个校准阶段保持
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			amb_recheck_pending_o <= 1'b0;      // 复位时没有待处理周期请求
		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1)begin
			amb_recheck_pending_o <= 1'b0;      // 本轮结束或取消后释放保持请求；LFA-03/RRC-12 STOP/abort在周期重检pending期间取消未提交请求，不改变已提交码/epoch，已排空的在途owner遵循正常受控释放规则 @satisfies: LFA-03, RRC-12
		end else if(flag_interval_hit == 1'b1)begin
			amb_recheck_pending_o <= 1'b1;      // 达到配置帧数后锁存到期事实
		end else begin
			amb_recheck_pending_o <= amb_recheck_pending_o; // 等待切换和三帧期间保持
		end
	end

	//----------------状态机区域----------------//
	// 状态寄存器在复位和控制取消时回到NORMAL监测阶段
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_MONITOR;        // 复位后等待正式RUN帧
		end else begin
			state_current <= state_next;        // 每拍提交组合状态选择
		end
	end

	// 下一状态逻辑强制三个校准阶段由各自物理帧边界隔开
	always@(*)begin
		state_next = state_current;             // 默认保持当前调度阶段
		if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1)begin
			state_next = ST_MONITOR;            // 新RUN或取消事件清除旧序列
		end else if(enc_sequence_failed_o == 1'b1 || enc_sequence_done_o == 1'b1)begin
			state_next = ST_MONITOR;            // 成功或失败均结束本轮调度占用
		end else begin
			case(state_current)
				ST_MONITOR:begin
					if(amb_recheck_pending_o == 1'b1 || flag_interval_hit == 1'b1)begin
						if(i_precision_15_to_9_event == 1'b1)begin
							state_next = ST_WAIT_DRAIN; // 同拍切换事件直接锁存接管资格
						end else begin
							state_next = ST_WAIT_SWITCH; // 到期后保持等待下一次精度下降
						end
					end
				end
				ST_WAIT_SWITCH:begin
					if(i_precision_15_to_9_event == 1'b1)begin
						state_next = ST_WAIT_DRAIN; // 切到9-bit后停止接收新NORMAL事务；RRC-02 pending悬挂期间码/epoch/busy均不变，只在真实SAR15->9回落事件后才离开本状态 @satisfies: RRC-02
					end
				end
				ST_WAIT_DRAIN:begin
					if(flag_takeover_safe == 1'b1)begin
						state_next = ST_AMB;    // 六个安全条件满足后开始第一帧
					end
				end
				ST_AMB:begin
					if(flag_stage_result_available == 1'b1 && flag_stage_frame_available == 1'b1)begin
						if(i_dcs_enable == 1'b1)begin
							state_next = ST_WAIT_DCS_ACCEPT; // AMB帧结束后等待固定DC重验
						end else begin
							state_next = ST_MONITOR; // DCS禁用时第一帧即为最后阶段
						end
					end
				end
				ST_WAIT_DCS_ACCEPT:begin
					if(i_dcs_enable == 1'b0)begin
						state_next = ST_MONITOR; // 防御配置异常变化导致状态停滞
					end else if(i_dcs_revalidate_request == 1'b1)begin
						state_next = ST_DCS_R;  // 固定第二帧从红光DC开始
					end
				end
				ST_DCS_R:begin
					if(flag_stage_result_available == 1'b1 && flag_stage_frame_available == 1'b1)begin
						state_next = ST_DCS_IR; // 红光结果和帧均闭合后开始第三帧
					end
				end
				ST_DCS_IR:begin
					if(flag_stage_result_available == 1'b1 && flag_stage_frame_available == 1'b1)begin
						state_next = ST_MONITOR; // 红外结果和帧闭合后恢复正式NORMAL
					end
				end
				default:begin
					state_next = ST_MONITOR;    // 非法状态安全恢复且不发起校准
				end
			endcase
		end
	end

	//-------------状态任务处理区域-------------//
	// 阶段结果标志允许数字搜索完成早于物理帧结束
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stage_result_done <= 1'b0;     // 复位时没有阶段结果
		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1 || flag_enter_amb == 1'b1 || dcs_revalidate_accept_o == 1'b1 || flag_enter_ir == 1'b1)begin
			flag_stage_result_done <= 1'b0;     // 每个新阶段从未完成状态开始
		end else if((state_current == ST_AMB) && i_amb_sequence_done == 1'b1)begin
			flag_stage_result_done <= 1'b1;     // 保存AMB检查或重搜索成功
		end else if((state_current == ST_DCS_R) && i_dcs_sample_request == 1'b1 && i_dcs_sample_color_ir == 1'b1)begin
			flag_stage_result_done <= 1'b1;     // 红外请求出现证明红光阶段已结束
		end else if((state_current == ST_DCS_IR) && i_dcs_revalidate_done == 1'b1)begin
			flag_stage_result_done <= 1'b1;     // 保存两色重验证最终成功
		end else begin
			flag_stage_result_done <= flag_stage_result_done; // 等待对应帧边界时保持结果
		end
	end

	// 物理帧结束标志允许帧边界早于控制器完成事件
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stage_frame_complete <= 1'b0;  // 复位时没有校准帧完成
		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1 || flag_enter_amb == 1'b1 || dcs_revalidate_accept_o == 1'b1 || flag_enter_ir == 1'b1)begin
			flag_stage_frame_complete <= 1'b0;  // 进入下一阶段时清除上一帧历史
		end else if(((state_current == ST_AMB) || (state_current == ST_DCS_R) || (state_current == ST_DCS_IR)) && i_calibration_frame_complete_event == 1'b1)begin
			flag_stage_frame_complete <= 1'b1;  // 保存当前物理校准帧结束事实
		end else begin
			flag_stage_frame_complete <= flag_stage_frame_complete; // 等待数字判断完成时保持
		end
	end

	//-------------主要任务处理区域-------------//
	// 样本在途标志阻止保持型IDAC请求重复启动模拟转换
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_sample_inflight <= 1'b0;       // 复位时没有校准样本在途
		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1 || flag_enter_amb == 1'b1 || dcs_revalidate_accept_o == 1'b1 || flag_enter_ir == 1'b1)begin
			flag_sample_inflight <= 1'b0;       // 阶段边界和取消事件丢弃临时所有权
		end else if(flag_matching_sample_accepted == 1'b1)begin
			flag_sample_inflight <= 1'b0;       // IDAC实际消费结果后允许下一笔请求
		end else if(flag_calibration_transfer == 1'b1)begin
			flag_sample_inflight <= 1'b1;       // 模拟调度接受后等待匹配结果返回
		end else begin
			flag_sample_inflight <= flag_sample_inflight; // 反压或转换期间保持占用
		end
	end

endmodule
