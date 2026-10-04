`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/08/06
// Design Name:     PPG System Configuration Manager Testbench
// Module Name:     tb_ppg_system_config_manager
// Description:     Self-checking lifecycle and configuration verification
// Simulations:     ppg_system_config_manager.v
//
// Referrences:     ppg_system_config_manager_semantic_contract.md
//
// Dependencies:    ppg_system_config_manager.v
//
// Version:         V4.9
// Revision Date:   2026/08/23
// History:
//     Time          Version     Revised by     Contents
// 2026/08/06        V1.0        Erie          Create file.
// 2026/08/06        V1.0        Erie          Extend the frozen V1 manager checks.
// 2026/08/07        V2.0        Erie          Verify the 640-bit ACTIVE V4 manager contract.
// 2026/08/13        V2.1        Erie          Verify the V4.1 profile and initial precision rule.
// 2026/08/23        V4.9        Erie          Widen every snapshot to the 1024-bit V4+V5 joint payload with a legal V5 default block on every full rebuild; add MGR-17 through MGR-24 covering the new STATIC_BIAS/EXTERNAL_TEST_CURRENT/reserved-IDAC combination checks, run_generation and stop_episode_active observation, and the system_fault_blocking START gate; retarget MGR-12's reserved-IDAC-encoding step from 0x05 to 0x15 per the current contract's ERROR_RESERVED_IDAC_MODE reclassification. MGR-21 is intentionally not implemented here per the contract's own note that it requires the joint Scheduler+SSW+AMI testbench, not this standalone one.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年08月06日
// 设计名称:        PPG系统配置管理器自检平台
// 模块名称:        tb_ppg_system_config_manager
// 模块说明:        验证原子配置、生命周期命令、错误状态和排空行为
// 仿真工程:        ppg_system_config_manager.v
//
// 参考资料:        ppg_system_config_manager_semantic_contract.md
//
// 依赖文件:        ppg_system_config_manager.v
//
// 当前版本:        V4.9
// 修订日期:        2026年08月23日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年08月06日   V1.0        Erie          创建文件
// 2026年08月06日   V1.0        Erie          扩展冻结版V1管理器检查
// 2026年08月07日   V2.0        Erie          验证640-bit ACTIVE V4管理合同
// 2026年08月13日   V2.1        Erie          验证运行类型与初始精度组合规则
// 2026年08月23日   V4.9        Erie          全部快照扩展为1024-bit V4+V5联合载荷，每次整体重建都补一份合法V5默认档案；新增MGR-17至MGR-24覆盖STATIC_BIAS/EXTERNAL_TEST_CURRENT/保留IDAC编码组合校验、run_generation与stop_episode_active观测、系统阻断START门；MGR-12保留IDAC枚举步骤按当前合同ERROR_RESERVED_IDAC_MODE重分类从0x05改为0x15。MGR-21按合同注记必须在Scheduler+SSW+AMI联合TB中验证，本TB故意不实现

// 对配置原子提交、生命周期命令、错误保持和STOPPING排空执行定向自检
module tb_ppg_system_config_manager();

	//-------------配置参数区域-------------//
	localparam integer CONFIG_WIDTH = 32'd1024; // 与V4+V5联合配置快照合同保持一致
	localparam integer EPOCH_WIDTH = 32'd8; // 检查8-bit模版本标签
	localparam integer RUN_GENERATION_WIDTH = 32'd8; // 检查8-bit代际标签
	localparam [1:0] ST_CONFIG = 2'b00;     // testbench期望的CONFIG编码
	localparam [1:0] ST_READY = 2'b01;      // testbench期望的READY编码
	localparam [1:0] ST_RUN = 2'b10;        // testbench期望的RUN编码
	localparam [1:0] ST_STOPPING = 2'b11;   // testbench期望的STOPPING编码

	//---------------时钟信号---------------//
	reg i_clk;                              // 2 MHz语义主时钟的缩短仿真替身

	//---------------复位信号---------------//
	reg i_rstn;                             // 驱动DUT低有效异步复位

	//--------------寄存器信号--------------//
	reg [CONFIG_WIDTH - 1:0]i_config_snapshot; // 逐字段构造待提交V4快照
	reg [CONFIG_WIDTH - 1:0]reg_mgr16_active_snapshot; // 保存MGR-16非法提交前的ACTIVE基线
	reg [EPOCH_WIDTH - 1:0]reg_mgr16_config_epoch; // 保存MGR-16非法提交前的配置版本
	reg [EPOCH_WIDTH - 1:0]reg_mgr16_coef_epoch; // 保存MGR-16非法提交前的Stage1版本
	reg [EPOCH_WIDTH - 1:0]reg_mgr16_stage2_epoch; // 保存MGR-16非法提交前的Stage2版本
	reg [EPOCH_WIDTH - 1:0]reg_mgr16_dc_epoch; // 保存MGR-16非法提交前的DC恢复版本
	reg [CONFIG_WIDTH - 1:0]reg_snapshot_before; // 保存MGR-19起各拒绝场景前的ACTIVE基线
	reg [EPOCH_WIDTH - 1:0]reg_epoch_before; // 保存MGR-19起各拒绝场景前的配置版本基线
	reg [RUN_GENERATION_WIDTH - 1:0]reg_generation_before; // 保存MGR-22/24各START拒绝场景前的代际基线
	integer cnt_error;                      // 累计所有自检比较失败数量

	//---------------标志信号---------------//
	reg i_config_update_event;              // 驱动完整配置到达事件
	reg i_start_event;                      // 驱动START命令事件
	reg i_stop_event;                       // 驱动STOP命令事件
	reg i_status_clear_event;               // 驱动sticky状态清除事件
	reg i_analog_ready;                     // 控制START模拟资格
	reg i_adc_idle;                         // 控制ADC空闲和STOPPING排空资格
	reg i_datapath_empty;                   // 控制ready/valid数据链排空资格
	reg i_idac_idle;                        // 控制IDAC内部流水排空资格
	reg i_analog_safe;                      // 控制模拟侧安全完成资格
	reg i_system_fault_blocking;            // 控制supervisor系统阻断START门
	reg i_static_characterization_enable;   // 控制STATIC_BIAS资格输入

	//---------------其他信号---------------//
	wire [CONFIG_WIDTH - 1:0]o_active_config; // 观察合法提交后的原子ACTIVE快照
	wire o_active_valid;                    // 观察本轮配置启动资格
	wire [EPOCH_WIDTH - 1:0]o_config_epoch; // 观察每次合法完整提交版本
	wire [EPOCH_WIDTH - 1:0]o_coef_epoch;   // 观察有效校准系数提交版本
	wire [EPOCH_WIDTH - 1:0]o_stage2_coef_epoch; // 观察正式Stage2系数提交版本
	wire [EPOCH_WIDTH - 1:0]o_dc_recovery_coef_epoch; // 观察DC恢复字段组提交版本
	wire [1:0]o_lifecycle_state;            // 观察四态生命周期编码
	wire o_start_ready;                     // 观察READY状态启动资格汇总
	wire o_run_enable;                      // 观察RUN状态功能链许可
	wire o_allow_new_transaction;           // 观察新ADC事务发起许可
	wire [RUN_GENERATION_WIDTH - 1:0]o_run_generation; // 观察唯一代际生产者
	wire o_stop_episode_active;             // 观察排空episode电平
	wire o_commit_ack_event;                // 观察最终ACTIVE提交应答事件
	wire o_start_ack_event;                 // 观察START接受事件
	wire o_stop_ack_event;                  // 观察STOP或幂等STOP应答事件
	wire o_error_event;                     // 观察拒绝事件脉冲
	wire o_commit_ack_sticky;               // 观察配置成功sticky状态
	wire o_error_sticky;                    // 观察错误sticky状态
	wire [7:0]o_last_error_code;            // 观察最近错误分类码

	//-------------仿真辅助任务-------------//
	// 把当前快照的V5[1023:640]整体重写为合同C04§5.2冻结的合法复位默认档案，供每次整体重建快照后调用
	task drive_default_v5;
		begin
			i_config_snapshot[640] = 1'b1;                // slope_mode=ADAPTIVE
			i_config_snapshot[672:641] = -32'sd65536;      // fixed_slope_q16
			i_config_snapshot[688:673] = 16'h199A;         // alpha_q15
			i_config_snapshot[704:689] = 16'h2000;         // beta_q15
			i_config_snapshot[720:705] = 16'h0800;         // timing_adjust_ratio_q15
			i_config_snapshot[752:721] = -32'sd262144;     // slope_min_q16
			i_config_snapshot[784:753] = -32'sd8192;       // slope_max_q16
			i_config_snapshot[816:785] = 32'sd0;           // baseline_delta_q16
			i_config_snapshot[848:817] = 32'd131072;       // cross_hysteresis_q16
			i_config_snapshot[864:849] = 16'd17;           // lead_min_frames
			i_config_snapshot[880:865] = 16'd19;           // lead_max_frames
			i_config_snapshot[884:881] = 4'd3;             // cross_confirm_count
			i_config_snapshot[888:885] = 4'd2;             // no_cross_limit
			i_config_snapshot[892:889] = 4'd3;             // peak_confirm_count
			i_config_snapshot[896:893] = 4'd3;             // valley_confirm_count
			i_config_snapshot[920:897] = 24'd2;            // direction_deadband
			i_config_snapshot[944:921] = 24'd20;           // min_peak_valley_amplitude
			i_config_snapshot[960:945] = 16'd20;           // min_peak_to_valley_frames
			i_config_snapshot[976:961] = 16'd100;          // min_peak_to_peak_frames
			i_config_snapshot[992:977] = 16'd600;          // max_fine_window_frames
			i_config_snapshot[1008:993] = 16'd1000;        // max_reacquire_frames
			i_config_snapshot[1009] = 1'b0;                // peak_valley_config_valid
			i_config_snapshot[1023:1010] = 14'd0;          // reserved_v5
		end
	endtask

	//-----------主要任务处理区域-----------//
	// 仿真使用10 ns周期，不改变DUT按时钟边沿工作的语义
	initial begin
		i_clk = 1'b0;                       // 时钟发生器从确定低电平起步
		forever #5 i_clk = ~i_clk;          // 每5 ns翻转一次形成10 ns仿真周期
	end

	//-------------测试激励区域-------------//
	initial begin
		i_rstn = 1'b0;                      // 初始保持异步复位有效
		i_config_snapshot = {CONFIG_WIDTH{1'b0}}; // 未构造前保持安全全零快照
		drive_default_v5;                   // 补齐合法V5默认档案，避免全零V5违反跨字段范围校验
		i_config_update_event = 1'b0;       // 初始不发送配置事件
		i_start_event = 1'b0;               // 初始不发送START
		i_stop_event = 1'b0;                // 初始不发送STOP
		i_status_clear_event = 1'b0;        // 初始不清除状态
		i_analog_ready = 1'b1;              // 默认模拟启动资格满足
		i_adc_idle = 1'b1;                  // 默认ADC没有活动事务
		i_datapath_empty = 1'b1;            // 默认数字事务流水为空
		i_idac_idle = 1'b1;                 // 默认IDAC控制流水为空
		i_analog_safe = 1'b1;               // 默认模拟控制位于安全状态
		i_system_fault_blocking = 1'b0;     // 默认系统未阻断
		i_static_characterization_enable = 1'b0; // 默认非STATIC_BIAS资格
		reg_mgr16_active_snapshot = {CONFIG_WIDTH{1'b0}}; // 初始化MGR-16 ACTIVE比较基线
		reg_mgr16_config_epoch = {EPOCH_WIDTH{1'b0}}; // 初始化MGR-16配置版本基线
		reg_mgr16_coef_epoch = {EPOCH_WIDTH{1'b0}}; // 初始化MGR-16 Stage1版本基线
		reg_mgr16_stage2_epoch = {EPOCH_WIDTH{1'b0}}; // 初始化MGR-16 Stage2版本基线
		reg_mgr16_dc_epoch = {EPOCH_WIDTH{1'b0}}; // 初始化MGR-16 DC恢复版本基线
		cnt_error = 0;                      // 清零失败计数器

		// MGR-01：复位只允许进入CONFIG且所有资格和epoch为零
		repeat(3) @(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_CONFIG) || o_active_valid || (o_config_epoch != 8'd0) || (o_coef_epoch != 8'd0) || (o_stage2_coef_epoch != 8'd0) || (o_dc_recovery_coef_epoch != 8'd0))begin
			$display("FAIL MGR-01 reset state"); // 报告复位状态或epoch不符合合同
			cnt_error = cnt_error + 1;      // 累计MGR-01复位检查失败
		end
		i_rstn = 1'b1;                      // 在非活动边沿附近释放复位
		repeat(2) @(posedge i_clk);

		// 构造满足V4 NORMAL_PPG资格的完整快照
		i_config_snapshot = {CONFIG_WIDTH{1'b0}}; // 清空快照后逐字段构造NORMAL配置
		drive_default_v5;                   // 补齐合法V5默认档案，避免全零V5违反跨字段范围校验
		i_config_snapshot[7:0] = 8'h04;     // 选择冻结的V4 schema
		i_config_snapshot[8] = 1'b0;        // 选择NORMAL_PPG运行资格
		i_config_snapshot[11:10] = 2'b00;   // 选择MANUAL IDAC模式
		i_config_snapshot[13:12] = 2'b00;   // 选择红光和红外双光模式
		i_config_snapshot[19] = 1'b1;       // 声明Stage1校准系数已经完整拟合
		i_config_snapshot[20] = 1'b1;       // 声明Stage2校准系数已经完整拟合
		i_config_snapshot[21] = 1'b1;       // 声明SAR9 DC恢复系数已经完成表征
		i_config_snapshot[22] = 1'b1;       // 声明SAR15 DC恢复系数已经完成表征
		i_config_snapshot[39:32] = 8'd64;   // AMB手动码位于0至255范围内
		i_config_snapshot[47:40] = 8'd0;    // AMB码下限采用零码
		i_config_snapshot[55:48] = 8'd255;  // AMB码上限采用满码
		i_config_snapshot[63:56] = 8'd80;   // 红光DCS手动码位于合法范围
		i_config_snapshot[71:64] = 8'd0;    // 红光DCS码下限采用零码
		i_config_snapshot[79:72] = 8'd255;  // 红光DCS码上限采用满码
		i_config_snapshot[87:80] = 8'd96;   // 红外DCS手动码位于合法范围
		i_config_snapshot[95:88] = 8'd0;    // 红外DCS码下限采用零码
		i_config_snapshot[103:96] = 8'd255; // 红外DCS码上限采用满码
		i_config_snapshot[115:104] = -12'sd64; // AMB窗口低阈值采用负残差
		i_config_snapshot[127:116] = 12'sd64; // AMB窗口高阈值采用正残差
		i_config_snapshot[139:128] = -12'sd48; // DCS窗口低阈值采用负残差
		i_config_snapshot[151:140] = 12'sd48; // DCS窗口高阈值采用正残差
		i_config_snapshot[159:152] = 8'd8;  // AMB连续八个越界样本才请求调码
		i_config_snapshot[167:160] = 8'd8;  // DCS连续八个越界样本才请求调码
		i_config_snapshot[479:460] = 20'sd54143; // 写入正极性的Stage2标称Q16增益
		i_config_snapshot[511:480] = 32'sd0; // 写入Stage2标称零值加性截距
		i_config_snapshot[543:512] = 32'sd65536; // 写入SAR9每码1.0统一PPG码的测试系数
		i_config_snapshot[575:544] = 32'sd32768; // 写入SAR15每码0.5统一PPG码的测试系数
		i_config_snapshot[591:576] = 16'd4096; // 配置约10.24秒的默认AMB周期重检间隔

		// MGR-02：反转AMB窗口关系必须拒绝且ACTIVE和epoch不变
		i_config_snapshot[115:104] = 12'sd80; // 把AMB低阈值抬高到窗口上方
		i_config_snapshot[127:116] = 12'sd40; // 把AMB高阈值压低形成反向窗口
		i_config_update_event = 1'b1;       // 提交反向AMB阈值快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束非法阈值提交事件
		if(!o_error_event || (o_last_error_code != 8'h07) || (o_lifecycle_state != ST_CONFIG) || o_active_valid || (o_config_epoch != 8'd0))begin
			$display("FAIL MGR-02 invalid threshold commit"); // 报告阈值错误拒绝行为异常
			cnt_error = cnt_error + 1;      // 累计MGR-02非法阈值检查失败
		end

		// 清除错误后恢复合法窗口，避免sticky错误阻止后续START
		i_status_clear_event = 1'b1;        // 请求清除MGR-02产生的错误状态
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束MGR-02状态清除事件
		i_config_snapshot[115:104] = -12'sd64; // 恢复AMB负侧合法低阈值
		i_config_snapshot[127:116] = 12'sd64; // 恢复AMB正侧合法高阈值
		@(posedge i_clk);
		#1;
		if(o_error_sticky || (o_last_error_code != 8'h00))begin
			$display("FAIL MGR-02 status clear"); // 报告sticky状态或错误码未被清除
			cnt_error = cnt_error + 1;      // 累计MGR-02清除检查失败
		end

		// MGR-03：合法NORMAL提交原子进入READY并同时更新两个epoch
		i_config_update_event = 1'b1;       // 提交首个合法NORMAL配置
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束合法NORMAL提交事件
		if(!o_commit_ack_event || !o_commit_ack_sticky || !o_active_valid || (o_lifecycle_state != ST_READY) || (o_active_config != i_config_snapshot) || (o_config_epoch != 8'd1) || (o_coef_epoch != 8'd1) || (o_stage2_coef_epoch != 8'd1) || (o_dc_recovery_coef_epoch != 8'd1))begin
			$display("FAIL MGR-03 valid normal commit"); // 报告原子提交或双epoch更新异常
			cnt_error = cnt_error + 1;      // 累计MGR-03合法提交检查失败
		end

		// MGR-04：全部资格满足时START一次性进入RUN
		i_start_event = 1'b1;               // 在READY且资格完整时请求START
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束合法START事件
		if(!o_start_ack_event || (o_lifecycle_state != ST_RUN) || !o_run_enable || !o_allow_new_transaction)begin
			$display("FAIL MGR-04 start run"); // 报告RUN进入或运行许可异常
			cnt_error = cnt_error + 1;      // 累计MGR-04启动检查失败
		end
        if(cnt_error != 0) $fatal(1, "D_SETUP_FAIL errors=%0d", cnt_error);
        @(negedge i_clk);
        i_analog_safe=0; i_adc_idle=0; i_datapath_empty=0; i_idac_idle=0;
        i_stop_event=1;
        if($test$plusargs("START_COLLISION")) i_start_event=1;
        if($test$plusargs("COMMIT_COLLISION")) i_config_update_event=1;
        if($test$plusargs("CLEAR_COLLISION")) i_status_clear_event=1;
        @(posedge i_clk); #1;
        $display("D_STOP_OBSERVE state=%b run=%b allow=%b ack=%b episode=%b error=%b code=%h",
            o_lifecycle_state,o_run_enable,o_allow_new_transaction,o_stop_ack_event,
            o_stop_episode_active,o_error_event,o_last_error_code);
        if(o_lifecycle_state !== ST_STOPPING || o_run_enable !== 0 ||
           o_allow_new_transaction !== 0 || o_stop_ack_event !== 1 ||
           o_stop_episode_active !== 1) $fatal(1, "D_STOP_FAIL: STOP did not win");
        $display("D_STOP_PASS"); $finish;
    end
	// 仿真超时保护，防止等待时钟或状态条件失效后无限运行
	initial begin
		#20000;
		$display("FAIL: ppg_system_config_manager testbench timeout"); // 报告主测试流程未在预算时间内结束
		$finish;                            // 超时后强制终止仿真避免挂起
	end

	//-------------模块例化区域-------------//
	ppg_system_config_manager inst_ppg_system_config_manager(
		.i_clk(i_clk),                      // 连接2 MHz语义仿真时钟
		.i_rstn(i_rstn),                    // 连接低有效异步复位
		.i_config_snapshot(i_config_snapshot), // 送入当前构造的完整配置快照
		.i_config_update_event(i_config_update_event), // 送入目标域配置到达事件
		.i_start_event(i_start_event),      // 送入START目标域事件
		.i_stop_event(i_stop_event),        // 送入STOP目标域事件
		.i_status_clear_event(i_status_clear_event), // 送入sticky状态清除事件
		.i_analog_ready(i_analog_ready),    // 送入模拟启动资格
		.i_adc_idle(i_adc_idle),            // 送入ADC空闲和DONE回低证明
		.i_datapath_empty(i_datapath_empty), // 送入数字事务链排空证明
		.i_idac_idle(i_idac_idle),          // 送入IDAC控制流水空闲证明
		.i_analog_safe(i_analog_safe),      // 送入停止后模拟安全证明
		.i_system_fault_blocking(i_system_fault_blocking), // 送入supervisor系统阻断电平
		.i_static_characterization_enable(i_static_characterization_enable), // 送入STATIC_BIAS资格电平
		.o_active_config(o_active_config),  // 观察原子ACTIVE快照
		.o_active_valid(o_active_valid),    // 观察本轮配置资格
		.o_config_epoch(o_config_epoch),    // 观察静态配置版本
		.o_coef_epoch(o_coef_epoch),        // 观察Stage1系数版本
		.o_stage2_coef_epoch(o_stage2_coef_epoch), // 观察Stage2系数版本
		.o_dc_recovery_coef_epoch(o_dc_recovery_coef_epoch), // 观察DC恢复字段组版本
		.o_lifecycle_state(o_lifecycle_state), // 观察四态生命周期
		.o_start_ready(o_start_ready),      // 观察START汇总资格
		.o_run_enable(o_run_enable),        // 观察RUN功能许可
		.o_allow_new_transaction(o_allow_new_transaction), // 观察新ADC事务许可
		.o_run_generation(o_run_generation), // 观察唯一代际生产者
		.o_stop_episode_active(o_stop_episode_active), // 观察排空episode电平
		.o_commit_ack_event(o_commit_ack_event), // 观察最终COMMIT应答事件
		.o_start_ack_event(o_start_ack_event), // 观察START应答事件
		.o_stop_ack_event(o_stop_ack_event), // 观察STOP应答事件
		.o_error_event(o_error_event),      // 观察错误事件
		.o_commit_ack_sticky(o_commit_ack_sticky), // 观察提交成功sticky位
		.o_error_sticky(o_error_sticky),    // 观察错误sticky位
		.o_last_error_code(o_last_error_code) // 观察最近错误码
	);

endmodule