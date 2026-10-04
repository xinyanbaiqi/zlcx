`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/14
// Design Name:        PPG ACTIVE V4 Control Plane Integration Testbench
// Module Name:        tb_ppg_active_v4_control_plane_integration
// Description:       Self-checking 640-bit CDC, lifecycle and unique unpack verification
// Simulations:        ppg_active_v4_control_plane_integration.v
//
// Referrences:        PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_config_cdc_bridge.v,
//                     ppg_system_config_manager.v,
//                     ppg_system_active_config_unpack.v,
//                     ppg_active_v4_control_plane_integration.v
//
// Version:            V1.6
// Revision Date:      2026/08/23
// History:
// 2026/08/14          V1.0        Erie          Create AV4C-01 through AV4C-18 self-check.
// 2026/08/23          V1.6        Erie          Widen every snapshot to the 1024-bit V4+V5 joint payload with a legal V5 default block on every rebuild; add AV4C-19 through AV4C-22 covering STATIC_BIAS ownership, system_fault_blocking/run_generation/stop_episode_active transparent forwarding, joint COMMIT rejection and V5 qualification gating.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月14日
// 设计名称:           PPG ACTIVE V4控制平面集成自检平台
// 模块名称:           tb_ppg_active_v4_control_plane_integration
// 模块说明:           验证1024-bit V4+V5联合配置CDC、生命周期管理和唯一字段解包
// 仿真工程:           ppg_active_v4_control_plane_integration.v
//
// 参考资料:           PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_config_cdc_bridge.v、
//                     ppg_system_config_manager.v、
//                     ppg_system_active_config_unpack.v、
//                     ppg_active_v4_control_plane_integration.v
//
// 当前版本:           V1.6
// 修订日期:           2026年08月23日
// 修订历史:
// 2026年08月14日       V1.0        Erie          创建AV4C-01至AV4C-18自检。
// 2026年08月23日       V1.6        Erie          全部快照扩展为1024-bit V4+V5联合载荷，每次整体重建都补一份合法V5默认档案；新增AV4C-19至AV4C-22覆盖STATIC_BIAS所有权、system_fault_blocking/run_generation/stop_episode_active透明转发、联合COMMIT拒绝和V5资格门控

// 本平台在独立source与2 MHz时钟域下，对控制平面进行保持型CDC和逐位字段比较。
module tb_ppg_active_v4_control_plane_integration();

	//---------------配置参数区域---------------//
	localparam integer C_CONFIG_WIDTH = 1024;   //冻结的V4+V5联合ACTIVE快照宽度
	localparam [1:0] ST_CONFIG = 2'b00;         //manager CONFIG生命周期编码
	localparam [1:0] ST_READY = 2'b01;          //manager READY生命周期编码
	localparam [1:0] ST_RUN = 2'b10;            //manager RUN生命周期编码
	localparam [1:0] ST_STOPPING = 2'b11;       //manager STOPPING生命周期编码
	//以下V5默认字段值与ppg_system_config_manager.v的V5_RESET_PROFILE逐项一致，用于构造合法快照和复位比较基线
	localparam [383:0] V5_RESET_PROFILE_REF = {
		14'd0,                                  //reserved_v5复位归零
		1'b0,                                   //peak_valley_config_valid复位不可用
		16'd1000,                               //max_reacquire_frames
		16'd600,                                //max_fine_window_frames
		16'd100,                                //min_peak_to_peak_frames
		16'd20,                                 //min_peak_to_valley_frames
		24'd20,                                 //min_peak_valley_amplitude
		24'd2,                                  //direction_deadband
		4'd3,                                   //valley_confirm_count
		4'd3,                                   //peak_confirm_count
		4'd2,                                   //no_cross_limit
		4'd3,                                   //cross_confirm_count
		16'd19,                                 //lead_max_frames
		16'd17,                                 //lead_min_frames
		32'd131072,                             //cross_hysteresis_q16
		32'sd0,                                 //baseline_delta_q16
		-32'sd8192,                             //slope_max_q16
		-32'sd262144,                           //slope_min_q16
		16'h0800,                               //timing_adjust_ratio_q15
		16'h2000,                               //beta_q15
		16'h199A,                               //alpha_q15
		-32'sd65536,                            //fixed_slope_q16
		1'b1                                    //slope_mode=ADAPTIVE
	};
	localparam [C_CONFIG_WIDTH - 1:0] RESET_ACTIVE_CONFIG = {V5_RESET_PROFILE_REF, 640'd0}; //manager复位后的唯一合法ACTIVE比较基线

	//---------------时钟与复位信号---------------//
	reg i_source_clk;                             //source配置域异步时钟
	reg i_source_rstn;                            //source域低有效复位
	reg i_clk;                                    //2 MHz语义系统时钟的仿真替身
	reg i_rstn;                                   //系统域低有效复位

	//---------------source配置驱动---------------//
	reg [C_CONFIG_WIDTH - 1:0]i_source_config_snapshot; //待跨域传输的完整V4快照
	reg i_source_config_update_event;             //source域配置更新单拍

	//---------------生命周期驱动-------------------//
	reg i_start_event;                              //系统域START单拍
	reg i_stop_event;                               //系统域STOP单拍
	reg i_status_clear_event;                       //系统域sticky清除单拍
	reg i_analog_ready;                             //模拟启动资格驱动
	reg i_adc_idle;                                 //物理ADC空闲资格驱动
	reg i_datapath_empty;                           //AMI数据链排空资格驱动
	reg i_idac_idle;                                //AMI IDAC排空资格驱动
	reg i_analog_safe;                              //模拟安全保持资格驱动
	reg i_system_fault_blocking;                    //supervisor系统阻断电平驱动
	reg i_static_characterization_enable;           //STATIC_BIAS资格电平驱动

	//---------------配置传输状态观察---------------//
	wire o_config_transport_busy;                   //观察CDC源域占用状态
	wire o_config_transport_update;                 //观察目标域完整快照到达事件

	//---------------ACTIVE与生命周期观察-------------//
	wire [C_CONFIG_WIDTH - 1:0]o_active_config;       //观察合法ACTIVE快照
	wire o_active_valid;                              //观察ACTIVE启动资格
	wire [7:0]o_config_epoch;                         //观察完整配置版本
	wire [7:0]o_coef_epoch;                           //观察Stage1版本
	wire [7:0]o_stage2_coef_epoch;                    //观察Stage2版本
	wire [7:0]o_dc_recovery_coef_epoch;               //观察DC恢复版本
	wire [1:0]o_lifecycle_state;                      //观察当前生命周期状态
	wire o_start_ready;                               //观察READY启动资格汇总
	wire o_run_enable;                                //观察RUN功能许可
	wire o_allow_new_transaction;                     //观察新事务许可
	wire [7:0]o_run_generation;                       //观察manager唯一产生的代际
	wire o_stop_episode_active;                       //观察排空episode电平

	//---------------响应与错误观察-------------------//
	wire o_commit_ack_event;                          //观察合法COMMIT应答
	wire o_start_ack_event;                           //观察合法START应答
	wire o_stop_ack_event;                            //观察合法STOP应答
	wire o_error_event;                               //观察拒绝事件
	wire o_commit_ack_sticky;                         //观察COMMIT历史sticky
	wire o_error_sticky;                              //观察错误历史sticky
	wire [7:0]o_last_error_code;                      //观察最近错误码

	//---------------系统模式字段观察---------------//
	wire [7:0]o_schema_version;                     //观察解包schema字段
	wire o_run_profile;                             //观察解包运行档位
	wire o_input_source;                            //观察解包输入来源
	wire [1:0]o_idac_mode;                          //观察解包IDAC模式
	wire [1:0]o_optical_mode;                       //观察解包光学模式
	wire o_initial_precision;                       //观察解包初始精度
	wire o_amb_enable;                              //观察AMB使能字段
	wire o_dcs_enable;                              //观察DCS使能字段
	wire o_amb_polarity;                            //观察AMB极性字段
	wire o_dcs_polarity;                            //观察DCS极性字段
	wire o_stage1_calibration_valid;                //观察Stage1有效字段
	wire o_stage2_calibration_valid;                //观察Stage2有效字段
	wire o_dc9_recovery_valid;                      //观察SAR9恢复有效字段
	wire o_dc15_recovery_valid;                     //观察SAR15恢复有效字段

	//---------------IDAC字段观察---------------------//
	wire [7:0]o_amb_manual_code;                      //观察AMB手动码字段
	wire [7:0]o_amb_code_min;                         //观察AMB码下限字段
	wire [7:0]o_amb_code_max;                         //观察AMB码上限字段
	wire [7:0]o_dcs_r_manual_code;                    //观察红光DC手动码字段
	wire [7:0]o_dcs_r_code_min;                       //观察红光DC码下限字段
	wire [7:0]o_dcs_r_code_max;                       //观察红光DC码上限字段
	wire [7:0]o_dcs_ir_manual_code;                   //观察红外DC手动码字段
	wire [7:0]o_dcs_ir_code_min;                      //观察红外DC码下限字段
	wire [7:0]o_dcs_ir_code_max;                      //观察红外DC码上限字段

	//---------------阈值与确认字段观察---------------//
	wire signed [11:0]o_amb_threshold_low;            //观察AMB负阈值的signed解释
	wire signed [11:0]o_amb_threshold_high;           //观察AMB正阈值的signed解释
	wire signed [11:0]o_dcs_threshold_low;            //观察DCS负阈值的signed解释
	wire signed [11:0]o_dcs_threshold_high;           //观察DCS正阈值的signed解释
	wire [7:0]o_amb_confirm_count;                    //观察AMB确认次数
	wire [7:0]o_dcs_confirm_count;                    //观察DCS确认次数

	//---------------Stage1字段观察-------------------//
	wire signed [25:0]o_stage1_weight_q16_0;          //观察Stage1权重0
	wire signed [25:0]o_stage1_weight_q16_1;          //观察Stage1权重1
	wire signed [25:0]o_stage1_weight_q16_2;          //观察Stage1权重2
	wire signed [25:0]o_stage1_weight_q16_3;          //观察Stage1权重3
	wire signed [25:0]o_stage1_weight_q16_4;          //观察Stage1权重4
	wire signed [25:0]o_stage1_weight_q16_5;          //观察Stage1权重5
	wire signed [25:0]o_stage1_weight_q16_6;          //观察Stage1权重6
	wire signed [25:0]o_stage1_weight_q16_7;          //观察Stage1权重7
	wire signed [25:0]o_stage1_weight_q16_8;          //观察Stage1权重8
	wire signed [25:0]o_stage1_weight_q16_9;          //观察Stage1权重9
	wire signed [31:0]o_stage1_offset_q16;            //观察Stage1 offset

	//---------------Stage2、DC恢复与调度字段观察-----//
	wire signed [19:0]o_stage2_gain_q16;              //观察Stage2 gain
	wire signed [31:0]o_stage2_offset_q16;            //观察Stage2 offset
	wire signed [31:0]o_dc9_recovery_gain_q16;        //观察SAR9 DC恢复gain
	wire signed [31:0]o_dc15_recovery_gain_q16;       //观察SAR15 DC恢复gain
	wire [15:0]o_amb_recheck_interval_frames;         //观察AMB重检间隔

	//---------------V5检测字段观察---------------------//
	wire o_slope_mode;                                //观察基线斜率固定或自适应模式
	wire signed [31:0]o_fixed_slope_q16;              //观察固定负斜率
	wire [15:0]o_alpha_q15;                           //观察基础斜率幅度比例
	wire [15:0]o_beta_q15;                            //观察活动斜率平滑比例
	wire [15:0]o_timing_adjust_ratio_q15;             //观察相交时刻修正比例
	wire signed [31:0]o_slope_min_q16;                //观察最负斜率边界
	wire signed [31:0]o_slope_max_q16;                //观察最接近零斜率边界
	wire signed [31:0]o_baseline_delta_q16;           //观察波峰锚点基线偏置
	wire [31:0]o_cross_hysteresis_q16;                //观察向上相交迟滞量
	wire [15:0]o_lead_min_frames;                     //观察相交提前量合格下界
	wire [15:0]o_lead_max_frames;                     //观察相交提前量合格上界
	wire [3:0]o_cross_confirm_count;                  //观察相交连续确认点数
	wire [3:0]o_no_cross_limit;                       //观察连续无相交重新获取阈值
	wire [3:0]o_peak_confirm_count;                   //观察波峰连续下降确认点数
	wire [3:0]o_valley_confirm_count;                 //观察波谷连续上升确认点数
	wire [23:0]o_direction_deadband;                  //观察相邻FIR方向分类死区
	wire [23:0]o_min_peak_valley_amplitude;           //观察合格峰谷最小幅度
	wire [15:0]o_min_peak_to_valley_frames;           //观察波峰到波谷最小帧差
	wire [15:0]o_min_peak_to_peak_frames;             //观察相邻波峰最小帧差
	wire [15:0]o_max_fine_window_frames;              //观察15-bit窗口最大持续帧数
	wire [15:0]o_max_reacquire_frames;                //观察9-bit重新获取最大帧数
	wire o_peak_valley_config_valid;                  //观察正式peak/valley/cross/fine-window资格位

	//---------------自检工作寄存器-------------------//
	reg [C_CONFIG_WIDTH - 1:0]reg_snapshot_normal;    //保存合法NORMAL快照基线
	reg [C_CONFIG_WIDTH - 1:0]reg_snapshot_busy;      //保存忙期间故意改写的shadow快照
	reg [C_CONFIG_WIDTH - 1:0]reg_snapshot_before_reject; //保存非法提交前ACTIVE基线
	reg [7:0]reg_config_epoch_before_reject;          //保存非法提交前配置epoch
	reg [7:0]reg_coef_epoch_before_reject;            //保存非法提交前Stage1 epoch
	reg [7:0]reg_stage2_epoch_before_reject;          //保存非法提交前Stage2 epoch
	reg [7:0]reg_dc_epoch_before_reject;              //保存非法提交前DC恢复epoch
	reg [7:0]reg_generation_before;                   //保存AV4C-20 START拒绝场景前的代际基线
	integer cnt_error;                                //累计真实比较失败数
	integer cnt_timeout;                              //受界等待循环计数器
	integer cnt_source_clock;                         //source时钟有限仿真循环计数
	integer cnt_system_clock;                         //系统时钟有限仿真循环计数

	//---------------source时钟发生器-----------------//
	//使用11 ns周期与系统13 ns周期形成独立CDC相位关系。
	initial begin
		i_source_clk = 1'b0;
		for(cnt_source_clock = 0; cnt_source_clock < 1000000; cnt_source_clock = cnt_source_clock + 1)begin
			#5.5 i_source_clk = ~i_source_clk;
		end
	end

	//---------------系统时钟发生器-------------------//
	//系统时钟只承担边沿语义，绝对仿真时间不改变2 MHz功能合同。
	initial begin
		i_clk = 1'b0;
		for(cnt_system_clock = 0; cnt_system_clock < 1000000; cnt_system_clock = cnt_system_clock + 1)begin
			#6.5 i_clk = ~i_clk;
		end
	end

	//---------------V5默认档案构造任务---------------//
	//把当前快照的V5[1023:640]整体重写为与manager V5_RESET_PROFILE一致的合法默认值
	task task_drive_default_v5;
		begin
			i_source_config_snapshot[1023:640] = V5_RESET_PROFILE_REF;
		end
	endtask

	//---------------合法NORMAL快照构造任务-----------//
	//构造一组带signed测试值的完整NORMAL V4配置，用于CDC与字段逐位比较。
	task task_build_normal_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			task_drive_default_v5;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b0;
			i_source_config_snapshot[9] = 1'b0; // NORMAL_PPG按V4.9合同必须为光电二极管输入源，否则触发新增0x11拒绝
			i_source_config_snapshot[11:10] = 2'b10;
			i_source_config_snapshot[13:12] = 2'b10;
			i_source_config_snapshot[14] = 1'b0;
			i_source_config_snapshot[15] = 1'b1;
			i_source_config_snapshot[16] = 1'b1;
			i_source_config_snapshot[17] = 1'b1;
			i_source_config_snapshot[18] = 1'b0;
			i_source_config_snapshot[19] = 1'b1;
			i_source_config_snapshot[20] = 1'b1;
			i_source_config_snapshot[21] = 1'b1;
			i_source_config_snapshot[22] = 1'b1;
			i_source_config_snapshot[39:32] = 8'd64;
			i_source_config_snapshot[47:40] = 8'd8;
			i_source_config_snapshot[55:48] = 8'd240;
			i_source_config_snapshot[63:56] = 8'd80;
			i_source_config_snapshot[71:64] = 8'd12;
			i_source_config_snapshot[79:72] = 8'd230;
			i_source_config_snapshot[87:80] = 8'd96;
			i_source_config_snapshot[95:88] = 8'd16;
			i_source_config_snapshot[103:96] = 8'd220;
			i_source_config_snapshot[115:104] = -12'sd64;
			i_source_config_snapshot[127:116] = 12'sd72;
			i_source_config_snapshot[139:128] = -12'sd48;
			i_source_config_snapshot[151:140] = 12'sd56;
			i_source_config_snapshot[159:152] = 8'd8;
			i_source_config_snapshot[167:160] = 8'd9;
			i_source_config_snapshot[193:168] = -26'sd17;
			i_source_config_snapshot[219:194] = 26'sd18;
			i_source_config_snapshot[245:220] = -26'sd19;
			i_source_config_snapshot[271:246] = 26'sd20;
			i_source_config_snapshot[297:272] = -26'sd21;
			i_source_config_snapshot[323:298] = 26'sd22;
			i_source_config_snapshot[349:324] = -26'sd23;
			i_source_config_snapshot[375:350] = 26'sd24;
			i_source_config_snapshot[401:376] = -26'sd25;
			i_source_config_snapshot[427:402] = 26'sd26;
			i_source_config_snapshot[459:428] = -32'sd99;
			i_source_config_snapshot[479:460] = 20'sd54143;
			i_source_config_snapshot[511:480] = -32'sd37;
			i_source_config_snapshot[543:512] = 32'sd65536;
			i_source_config_snapshot[575:544] = 32'sd32768;
			i_source_config_snapshot[591:576] = 16'd4096;
		end
	endtask

	//---------------合法CHARACTERIZATION快照任务-----//
	//构造未声明正式系数的标称表征快照，用于验证四类epoch的独立更新规则。
	task task_build_characterization_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			task_drive_default_v5;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b1;
			i_source_config_snapshot[11:10] = 2'b00;
			i_source_config_snapshot[13:12] = 2'b01; // 光电二极管CHARACTERIZATION按V4.9合同必须为RED_ONLY，否则触发新增0x13拒绝
			i_source_config_snapshot[14] = 1'b0;
			i_source_config_snapshot[39:32] = 8'd48;
			i_source_config_snapshot[47:40] = 8'd0;
			i_source_config_snapshot[55:48] = 8'd255;
			i_source_config_snapshot[63:56] = 8'd72;
			i_source_config_snapshot[71:64] = 8'd0;
			i_source_config_snapshot[79:72] = 8'd255;
			i_source_config_snapshot[87:80] = 8'd88;
			i_source_config_snapshot[95:88] = 8'd0;
			i_source_config_snapshot[103:96] = 8'd255;
			i_source_config_snapshot[115:104] = -12'sd32;
			i_source_config_snapshot[127:116] = 12'sd32;
			i_source_config_snapshot[139:128] = -12'sd24;
			i_source_config_snapshot[151:140] = 12'sd24;
			i_source_config_snapshot[159:152] = 8'd4;
			i_source_config_snapshot[167:160] = 8'd4;
			i_source_config_snapshot[193:168] = 26'sd65536;
			i_source_config_snapshot[219:194] = 26'sd131072;
			i_source_config_snapshot[245:220] = 26'sd262144;
			i_source_config_snapshot[271:246] = 26'sd524288;
			i_source_config_snapshot[297:272] = 26'sd524288;
			i_source_config_snapshot[323:298] = 26'sd1048576;
			i_source_config_snapshot[349:324] = 26'sd2097152;
			i_source_config_snapshot[375:350] = 26'sd4194304;
			i_source_config_snapshot[401:376] = 26'sd8388608;
			i_source_config_snapshot[427:402] = 26'sd16777216;
			i_source_config_snapshot[459:428] = -32'sd262144;
			i_source_config_snapshot[591:576] = 16'd1024;
		end
	endtask

	//---------------source配置事件任务---------------//
	//在source时钟边沿提交一次快照传输请求；忙期间请求按CDC合同被忽略。
	task task_pulse_source_update;
		begin
			@(negedge i_source_clk);
			i_source_config_update_event = 1'b1;
			@(posedge i_source_clk);
			#1 i_source_config_update_event = 1'b0;
		end
	endtask

	//---------------START事件任务--------------------//
	//在2 MHz域提供一个无并发配置命令的START单拍。
	task task_pulse_start;
		begin
			@(negedge i_clk);
			i_start_event = 1'b1;
			@(posedge i_clk);
			#1 i_start_event = 1'b0;
		end
	endtask

	//---------------STOP事件任务---------------------//
	//在2 MHz域提供一个无并发配置命令的STOP单拍。
	task task_pulse_stop;
		begin
			@(negedge i_clk);
			i_stop_event = 1'b1;
			@(posedge i_clk);
			#1 i_stop_event = 1'b0;
		end
	endtask

	//---------------状态清除事件任务-----------------//
	//仅清除manager sticky状态和错误码，不触发任何生命周期命令。
	task task_clear_status;
		begin
			@(negedge i_clk);
			i_status_clear_event = 1'b1;
			@(posedge i_clk);
			#1 i_status_clear_event = 1'b0;
			@(posedge i_clk);
			#1;
		end
	endtask

	//---------------目标域传输等待任务---------------//
	//等待CDC在2 MHz域给出完整快照到达脉冲，超时即记录自检失败。
	task task_wait_transport_update;
		begin
			cnt_timeout = 0;
			while((o_config_transport_update == 1'b0) && (cnt_timeout < 32))begin
				@(posedge i_clk);
				#1;
				cnt_timeout = cnt_timeout + 1;
			end
			if(o_config_transport_update != 1'b1)begin
				$display("FAIL transport update timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------配置结果等待任务-----------------//
	//等待manager对到达快照给出唯一COMMIT ACK或ERROR事件。
	task task_wait_config_result;
		begin
			cnt_timeout = 0;
			while((o_commit_ack_event == 1'b0) && (o_error_event == 1'b0) && (cnt_timeout < 32))begin
				@(posedge i_clk);
				#1;
				cnt_timeout = cnt_timeout + 1;
			end
			if((o_commit_ack_event == 1'b0) && (o_error_event == 1'b0))begin
				$display("FAIL manager config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//------------模块实例化区域------------//
	//通过真实三个子模块连接验证640-bitCDC、管理器和唯一unpack输出。
	ppg_active_v4_control_plane_integration dut_Inst(
		.i_source_clk(i_source_clk),
		.i_source_rstn(i_source_rstn),
		.i_source_config_snapshot(i_source_config_snapshot),
		.i_source_config_update_event(i_source_config_update_event),
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_start_event(i_start_event),
		.i_stop_event(i_stop_event),
		.i_status_clear_event(i_status_clear_event),
		.i_analog_ready(i_analog_ready),
		.i_adc_idle(i_adc_idle),
		.i_datapath_empty(i_datapath_empty),
		.i_idac_idle(i_idac_idle),
		.i_analog_safe(i_analog_safe),
		.i_system_fault_blocking(i_system_fault_blocking),
		.i_static_characterization_enable(i_static_characterization_enable),
		.o_config_transport_busy(o_config_transport_busy),
		.o_config_transport_update(o_config_transport_update),
		.o_active_config(o_active_config),
		.o_active_valid(o_active_valid),
		.o_config_epoch(o_config_epoch),
		.o_coef_epoch(o_coef_epoch),
		.o_stage2_coef_epoch(o_stage2_coef_epoch),
		.o_dc_recovery_coef_epoch(o_dc_recovery_coef_epoch),
		.o_lifecycle_state(o_lifecycle_state),
		.o_start_ready(o_start_ready),
		.o_run_enable(o_run_enable),
		.o_allow_new_transaction(o_allow_new_transaction),
		.o_run_generation(o_run_generation),
		.o_stop_episode_active(o_stop_episode_active),
		.o_commit_ack_event(o_commit_ack_event),
		.o_start_ack_event(o_start_ack_event),
		.o_stop_ack_event(o_stop_ack_event),
		.o_error_event(o_error_event),
		.o_commit_ack_sticky(o_commit_ack_sticky),
		.o_error_sticky(o_error_sticky),
		.o_last_error_code(o_last_error_code),
		.o_schema_version(o_schema_version),
		.o_run_profile(o_run_profile),
		.o_input_source(o_input_source),
		.o_idac_mode(o_idac_mode),
		.o_optical_mode(o_optical_mode),
		.o_initial_precision(o_initial_precision),
		.o_amb_enable(o_amb_enable),
		.o_dcs_enable(o_dcs_enable),
		.o_amb_polarity(o_amb_polarity),
		.o_dcs_polarity(o_dcs_polarity),
		.o_stage1_calibration_valid(o_stage1_calibration_valid),
		.o_stage2_calibration_valid(o_stage2_calibration_valid),
		.o_dc9_recovery_valid(o_dc9_recovery_valid),
		.o_dc15_recovery_valid(o_dc15_recovery_valid),
		.o_amb_manual_code(o_amb_manual_code),
		.o_amb_code_min(o_amb_code_min),
		.o_amb_code_max(o_amb_code_max),
		.o_dcs_r_manual_code(o_dcs_r_manual_code),
		.o_dcs_r_code_min(o_dcs_r_code_min),
		.o_dcs_r_code_max(o_dcs_r_code_max),
		.o_dcs_ir_manual_code(o_dcs_ir_manual_code),
		.o_dcs_ir_code_min(o_dcs_ir_code_min),
		.o_dcs_ir_code_max(o_dcs_ir_code_max),
		.o_amb_threshold_low(o_amb_threshold_low),
		.o_amb_threshold_high(o_amb_threshold_high),
		.o_dcs_threshold_low(o_dcs_threshold_low),
		.o_dcs_threshold_high(o_dcs_threshold_high),
		.o_amb_confirm_count(o_amb_confirm_count),
		.o_dcs_confirm_count(o_dcs_confirm_count),
		.o_stage1_weight_q16_0(o_stage1_weight_q16_0),
		.o_stage1_weight_q16_1(o_stage1_weight_q16_1),
		.o_stage1_weight_q16_2(o_stage1_weight_q16_2),
		.o_stage1_weight_q16_3(o_stage1_weight_q16_3),
		.o_stage1_weight_q16_4(o_stage1_weight_q16_4),
		.o_stage1_weight_q16_5(o_stage1_weight_q16_5),
		.o_stage1_weight_q16_6(o_stage1_weight_q16_6),
		.o_stage1_weight_q16_7(o_stage1_weight_q16_7),
		.o_stage1_weight_q16_8(o_stage1_weight_q16_8),
		.o_stage1_weight_q16_9(o_stage1_weight_q16_9),
		.o_stage1_offset_q16(o_stage1_offset_q16),
		.o_stage2_gain_q16(o_stage2_gain_q16),
		.o_stage2_offset_q16(o_stage2_offset_q16),
		.o_dc9_recovery_gain_q16(o_dc9_recovery_gain_q16),
		.o_dc15_recovery_gain_q16(o_dc15_recovery_gain_q16),
		.o_amb_recheck_interval_frames(o_amb_recheck_interval_frames),
		.o_slope_mode(o_slope_mode),
		.o_fixed_slope_q16(o_fixed_slope_q16),
		.o_alpha_q15(o_alpha_q15),
		.o_beta_q15(o_beta_q15),
		.o_timing_adjust_ratio_q15(o_timing_adjust_ratio_q15),
		.o_slope_min_q16(o_slope_min_q16),
		.o_slope_max_q16(o_slope_max_q16),
		.o_baseline_delta_q16(o_baseline_delta_q16),
		.o_cross_hysteresis_q16(o_cross_hysteresis_q16),
		.o_lead_min_frames(o_lead_min_frames),
		.o_lead_max_frames(o_lead_max_frames),
		.o_cross_confirm_count(o_cross_confirm_count),
		.o_no_cross_limit(o_no_cross_limit),
		.o_peak_confirm_count(o_peak_confirm_count),
		.o_valley_confirm_count(o_valley_confirm_count),
		.o_direction_deadband(o_direction_deadband),
		.o_min_peak_valley_amplitude(o_min_peak_valley_amplitude),
		.o_min_peak_to_valley_frames(o_min_peak_to_valley_frames),
		.o_min_peak_to_peak_frames(o_min_peak_to_peak_frames),
		.o_max_fine_window_frames(o_max_fine_window_frames),
		.o_max_reacquire_frames(o_max_reacquire_frames),
		.o_peak_valley_config_valid(o_peak_valley_config_valid)
	);

	//---------------主自检序列------------------------//
	//按合同顺序验证复位、拒绝、CDC、字段、生命周期、epoch和结构隔离规则。
	initial begin
		i_source_rstn = 1'b0;
		i_rstn = 1'b0;
		i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
		i_source_config_update_event = 1'b0;
		i_start_event = 1'b0;
		i_stop_event = 1'b0;
		i_status_clear_event = 1'b0;
		i_analog_ready = 1'b1;
		i_adc_idle = 1'b1;
		i_datapath_empty = 1'b1;
		i_idac_idle = 1'b1;
		i_analog_safe = 1'b1;
		i_system_fault_blocking = 1'b0;
		i_static_characterization_enable = 1'b0;
		reg_snapshot_normal = {C_CONFIG_WIDTH{1'b0}};
		reg_snapshot_busy = {C_CONFIG_WIDTH{1'b0}};
		reg_snapshot_before_reject = {C_CONFIG_WIDTH{1'b0}};
		reg_config_epoch_before_reject = 8'd0;
		reg_coef_epoch_before_reject = 8'd0;
		reg_stage2_epoch_before_reject = 8'd0;
		reg_dc_epoch_before_reject = 8'd0;
		cnt_error = 0;
		cnt_timeout = 0;

		//AV4C-13：两域复位不产生迟到CDC、COMMIT或生命周期事件。
		repeat(3) @(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_CONFIG) || o_active_valid || o_config_transport_busy || o_config_transport_update || o_commit_ack_event || o_start_ack_event || o_stop_ack_event || o_error_event || (o_config_epoch != 8'd0) || (o_coef_epoch != 8'd0) || (o_stage2_coef_epoch != 8'd0) || (o_dc_recovery_coef_epoch != 8'd0))begin
			$display("FAIL AV4C-13 reset isolation");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-13");
		end
		@(negedge i_source_clk);
		i_source_rstn = 1'b1;
		@(negedge i_clk);
		i_rstn = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;
		if(o_config_transport_update || o_commit_ack_event || o_error_event)begin
			$display("FAIL AV4C-13 release phantom event");
			cnt_error = cnt_error + 1;
		end

		//AV4C-04：反向阈值必须由manager拒绝，ACTIVE和epoch保持初值。
		task_build_normal_config;
		i_source_config_snapshot[115:104] = 12'sd80;
		i_source_config_snapshot[127:116] = 12'sd40;
		task_pulse_source_update;
		task_wait_transport_update;
		task_wait_config_result;
		if(!o_error_event || o_commit_ack_event || o_active_valid || (o_lifecycle_state != ST_CONFIG) || (o_config_epoch != 8'd0))begin
			$display("FAIL AV4C-04 invalid threshold reject");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-04");
		end

		//AV4C-08：状态清除只清除sticky和错误码，不改变生命周期。
		task_clear_status;
		if(o_error_sticky || (o_last_error_code != 8'h00) || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL AV4C-08 status clear");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-08");
		end

		//AV4C-10：V4头部保留位非零必须拒绝，不能影响未使用的功能输出。
		task_build_normal_config;
		i_source_config_snapshot[31:23] = 9'h001;
		task_pulse_source_update;
		task_wait_transport_update;
		task_wait_config_result;
		if(!o_error_event || o_active_valid || (o_active_config != RESET_ACTIVE_CONFIG) || (o_config_epoch != 8'd0))begin
			$display("FAIL AV4C-10 reserved field reject");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-10");
		end
		task_clear_status;

		//AV4C-11：NORMAL配置禁止以SAR15作为初始精度。
		task_build_normal_config;
		i_source_config_snapshot[14] = 1'b1;
		task_pulse_source_update;
		task_wait_transport_update;
		task_wait_config_result;
		if(!o_error_event || o_active_valid || (o_lifecycle_state != ST_CONFIG) || (o_config_epoch != 8'd0))begin
			$display("FAIL AV4C-11 normal initial precision reject");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-11");
		end
		task_clear_status;

		//AV4C-01、AV4C-05、AV4C-14：有效A快照跨域时，忙期间第二请求不得覆盖已锁存的A。
		task_build_normal_config;
		reg_snapshot_normal = i_source_config_snapshot;
		task_pulse_source_update;
		if(!o_config_transport_busy)begin
			$display("FAIL AV4C-14 source busy did not assert");
			cnt_error = cnt_error + 1;
		end
		task_wait_transport_update;
		reg_snapshot_busy = reg_snapshot_normal;
		reg_snapshot_busy[39:32] = 8'hA5;
		i_source_config_snapshot = reg_snapshot_busy;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_active_config == reg_snapshot_normal) || (o_config_epoch != 8'd1) || (o_lifecycle_state != ST_READY))begin
			$display("FAIL AV4C-01 640-bit atomic CDC");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-01");
		end
		if(o_config_transport_update || (o_active_config[39:32] != 8'd64))begin
			$display("FAIL AV4C-05 transport was confused with a second COMMIT");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-05");
		end
		cnt_timeout = 0;
		while(o_config_transport_busy && (cnt_timeout < 16))begin
			@(posedge i_source_clk);
			#1;
			cnt_timeout = cnt_timeout + 1;
		end
		if(o_config_transport_busy || (o_active_config != reg_snapshot_normal))begin
			$display("FAIL AV4C-14 source busy protection");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-14");
		end

		//AV4C-02、AV4C-03、AV4C-15、AV4C-17：检查唯一解包器对所有关键signed字段逐位透传。
		if((o_schema_version != 8'h04) || o_run_profile || o_input_source || (o_idac_mode != 2'b10) || (o_optical_mode != 2'b10) || o_initial_precision || !o_amb_enable || !o_dcs_enable || !o_amb_polarity || o_dcs_polarity || !o_stage1_calibration_valid || !o_stage2_calibration_valid || !o_dc9_recovery_valid || !o_dc15_recovery_valid || (o_amb_manual_code != 8'd64) || (o_dcs_r_manual_code != 8'd80) || (o_dcs_ir_manual_code != 8'd96) || (o_amb_threshold_low != -12'sd64) || (o_dcs_threshold_low != -12'sd48) || (o_stage1_weight_q16_0 != -26'sd17) || (o_stage1_weight_q16_9 != 26'sd26) || (o_stage1_offset_q16 != -32'sd99) || (o_stage2_gain_q16 != 20'sd54143) || (o_stage2_offset_q16 != -32'sd37) || (o_dc9_recovery_gain_q16 != 32'sd65536) || (o_dc15_recovery_gain_q16 != 32'sd32768) || (o_amb_recheck_interval_frames != 16'd4096))begin
			$display("FAIL AV4C-02 unique unpack or signed field mapping");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-02");
			$display("PASS AV4C-03");
			$display("PASS AV4C-15");
			$display("PASS AV4C-17");
		end

		//AV4C-09：首个NORMAL提交使四类版本独立建立为一。
		if((o_config_epoch != 8'd1) || (o_coef_epoch != 8'd1) || (o_stage2_coef_epoch != 8'd1) || (o_dc_recovery_coef_epoch != 8'd1) || !o_commit_ack_sticky || !o_active_valid)begin
			$display("FAIL AV4C-09 first epoch formation");
			cnt_error = cnt_error + 1;
		end

		//AV4C-06：缺少模拟资格的START必须拒绝，资格恢复且清错后才允许进入RUN。
		i_analog_ready = 1'b0;
		task_pulse_start;
		if(!o_error_event || o_start_ack_event || (o_lifecycle_state != ST_READY) || o_run_enable)begin
			$display("FAIL AV4C-06 start qualification rejection");
			cnt_error = cnt_error + 1;
		end
		task_clear_status;
		i_analog_ready = 1'b1;
		task_pulse_start;
		if(!o_start_ack_event || (o_lifecycle_state != ST_RUN) || !o_run_enable || !o_allow_new_transaction)begin
			$display("FAIL AV4C-06 qualified start");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-06");
		end

		//AV4C-12、AV4C-18：RUN静态输入期间ACTIVE和生命周期稳定，Wrapper不自行产生abort动作。
		repeat(4) @(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_RUN) || (o_active_config != reg_snapshot_normal) || (o_config_epoch != 8'd1) || !o_run_enable || !o_allow_new_transaction)begin
			$display("FAIL AV4C-12 RUN stability");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-12");
		end
		if(o_stop_ack_event || o_error_event || !o_active_valid)begin
			$display("FAIL AV4C-18 unexpected internal abort behavior");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-18");
		end

		//AV4C-07：STOP先关闭新事务，只有全部排空后才从STOPPING返回CONFIG。
		i_adc_idle = 1'b0;
		i_datapath_empty = 1'b0;
		i_idac_idle = 1'b0;
		i_analog_safe = 1'b0;
		task_pulse_stop;
		if(!o_stop_ack_event || (o_lifecycle_state != ST_STOPPING) || o_run_enable || o_allow_new_transaction || !o_active_valid)begin
			$display("FAIL AV4C-07 STOPPING entry");
			cnt_error = cnt_error + 1;
		end
		repeat(2) @(posedge i_clk);
		#1;
		if(o_lifecycle_state != ST_STOPPING)begin
			$display("FAIL AV4C-07 premature drain completion");
			cnt_error = cnt_error + 1;
		end
		i_adc_idle = 1'b1;
		i_datapath_empty = 1'b1;
		i_idac_idle = 1'b1;
		i_analog_safe = 1'b1;
		@(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_CONFIG) || o_active_valid || o_run_enable || o_allow_new_transaction)begin
			$display("FAIL AV4C-07 drain completion");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-07");
		end

		//AV4C-16：非零扩展保留位只会造成拒绝，不能成为LEDDAC、测试或检测字段来源。
		task_build_normal_config;
		i_source_config_snapshot[639:592] = 48'h0000_0000_0001;
		reg_snapshot_before_reject = o_active_config;
		reg_config_epoch_before_reject = o_config_epoch;
		reg_coef_epoch_before_reject = o_coef_epoch;
		reg_stage2_epoch_before_reject = o_stage2_coef_epoch;
		reg_dc_epoch_before_reject = o_dc_recovery_coef_epoch;
		task_pulse_source_update;
		task_wait_transport_update;
		task_wait_config_result;
		if(!o_error_event || (o_active_config != reg_snapshot_before_reject) || (o_config_epoch != reg_config_epoch_before_reject) || (o_coef_epoch != reg_coef_epoch_before_reject) || (o_stage2_coef_epoch != reg_stage2_epoch_before_reject) || (o_dc_recovery_coef_epoch != reg_dc_epoch_before_reject))begin
			$display("FAIL AV4C-16 reserved extension isolation");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-16");
		end
		task_clear_status;

		//AV4C-09：CHARACTERIZATION标称提交只递增config和DC恢复版本，保持Stage1/Stage2校准版本。
		task_build_characterization_config;
		task_pulse_source_update;
		task_wait_transport_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY) || (o_config_epoch != 8'd2) || (o_coef_epoch != 8'd1) || (o_stage2_coef_epoch != 8'd1) || (o_dc_recovery_coef_epoch != 8'd2) || o_stage1_calibration_valid || o_stage2_calibration_valid || o_dc9_recovery_valid || o_dc15_recovery_valid)begin
			$display("FAIL AV4C-09 independent epoch update");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-09");
		end

		//返回CONFIG准备AV4C-19起新增的1024-bit联合与supervisor透传验证
		task_pulse_start;
		task_pulse_stop;
		@(posedge i_clk);
		#1;

		//AV4C-19：已提交STATIC_BIAS资格但候选输入源仍为光电二极管必须在COMMIT拒绝且无ACTIVE/epoch副作用
		reg_snapshot_before_reject = o_active_config;
		reg_config_epoch_before_reject = o_config_epoch;
		task_build_characterization_config;
		i_static_characterization_enable = 1'b1;
		task_pulse_source_update;
		task_wait_transport_update;
		task_wait_config_result;
		if(!o_error_event || (o_last_error_code != 8'h14) || (o_active_config != reg_snapshot_before_reject) || (o_config_epoch != reg_config_epoch_before_reject) || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL AV4C-19 static bias input source rejection");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-19");
		end
		i_static_characterization_enable = 1'b0;
		task_clear_status;

		//AV4C-21：V5保留位非零必须拒绝联合COMMIT且旧V4/V5/config_epoch同时保持
		reg_snapshot_before_reject = o_active_config;
		reg_config_epoch_before_reject = o_config_epoch;
		task_build_normal_config;
		i_source_config_snapshot[1023:1010] = 14'h1;
		task_pulse_source_update;
		task_wait_transport_update;
		task_wait_config_result;
		if(!o_error_event || (o_last_error_code != 8'h17) || (o_active_config != reg_snapshot_before_reject) || (o_config_epoch != reg_config_epoch_before_reject) || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL AV4C-21 v5 reserved rejection");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-21");
		end
		task_clear_status;

		//AV4C-22：reset profile的peak_valley_config_valid=0禁止正式检测资格，只有合法联合COMMIT后的新值才能释放
		if(o_peak_valley_config_valid)begin
			$display("FAIL AV4C-22 default profile leaked formal detection qualification");
			cnt_error = cnt_error + 1;
		end
		task_build_normal_config;
		i_source_config_snapshot[1009] = 1'b1;
		task_pulse_source_update;
		task_wait_transport_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_peak_valley_config_valid)begin
			$display("FAIL AV4C-22 legal commit did not release detection qualification");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-22");
		end

		//AV4C-20：系统阻断电平拒绝START且不递增代际；解除并清错后合法START透传递增后的代际和排空episode
		reg_generation_before = o_run_generation;
		i_system_fault_blocking = 1'b1;
		task_pulse_start;
		if(!o_error_event || (o_lifecycle_state != ST_READY) || o_run_enable || (o_run_generation != reg_generation_before))begin
			$display("FAIL AV4C-20 system fault blocking rejection");
			cnt_error = cnt_error + 1;
		end
		i_system_fault_blocking = 1'b0;
		task_clear_status;
		task_pulse_start;
		if(!o_start_ack_event || (o_lifecycle_state != ST_RUN) || (o_run_generation != (reg_generation_before + 8'd1)))begin
			$display("FAIL AV4C-20 recovery start generation");
			cnt_error = cnt_error + 1;
		end
		if(o_stop_episode_active)begin
			$display("FAIL AV4C-20 stop episode asserted before any stop request");
			cnt_error = cnt_error + 1;
		end
		task_pulse_stop;
		if(!o_stop_episode_active)begin
			$display("FAIL AV4C-20 stop episode not asserted after accepted stop");
			cnt_error = cnt_error + 1;
		end
		@(posedge i_clk);
		#1;
		if(o_stop_episode_active || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL AV4C-20 stop episode did not clear after full drain");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS AV4C-20");
		end

		if(cnt_error == 0)begin
			$display("ALL AV4C-01 THROUGH AV4C-22 PASSED");
		end else begin
			$display("FAIL AV4 control plane self-check errors=%0d", cnt_error);
		end
		$finish;
	end

	//---------------仿真看门狗------------------------//
	//防止CDC握手或等待条件错误造成无界仿真挂起。
	initial begin
		#20000;
		$display("FAIL watchdog timeout");
		$finish;
	end

endmodule
