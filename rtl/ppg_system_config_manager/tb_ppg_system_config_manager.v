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
// Version:         V4.11
// Revision Date:   2026/10/09
// History:
//     Time          Version     Revised by     Contents
// 2026/08/06        V1.0        Erie          Create file.
// 2026/08/06        V1.0        Erie          Extend the frozen V1 manager checks.
// 2026/08/07        V2.0        Erie          Verify the 640-bit ACTIVE V4 manager contract.
// 2026/08/13        V2.1        Erie          Verify the V4.1 profile and initial precision rule.
// 2026/08/23        V4.9        Erie          Widen every snapshot to the 1024-bit V4+V5 joint payload with a legal V5 default block on every full rebuild; add MGR-17 through MGR-24 covering the new STATIC_BIAS/EXTERNAL_TEST_CURRENT/reserved-IDAC combination checks, run_generation and stop_episode_active observation, and the system_fault_blocking START gate; retarget MGR-12's reserved-IDAC-encoding step from 0x05 to 0x15 per the current contract's ERROR_RESERVED_IDAC_MODE reclassification. MGR-21 is intentionally not implemented here per the contract's own note that it requires the joint Scheduler+SSW+AMI testbench, not this standalone one.
// 2026/10/06        V4.10       Erie          ABCD review F-023: add the RUN/STOPPING half of MGR-11: for STOP+START, STOP+status-clear and STOP+COMMIT, each in its own RUN, the STOP must enter STOPPING (and the repeated conflicting STOP must stay idempotent), close run/new-transaction permission, raise stop_episode_active, report 0x01, and leave generation, ACTIVE and config_epoch unchanged; drain must return to CONFIG. Info line MGR11_STOP_PRIORITY.
// 2026/10/09        V4.11       Erie          B merge batch BMI-145 (ID governance): banner text only. The PASS banner no longer claims MGR-21, which this TB does not check (C02 requires the three-module joint TB); checks and counts unchanged.
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
// 当前版本:        V4.11
// 修订日期:        2026年10月09日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年08月06日   V1.0        Erie          创建文件
// 2026年08月06日   V1.0        Erie          扩展冻结版V1管理器检查
// 2026年08月07日   V2.0        Erie          验证640-bit ACTIVE V4管理合同
// 2026年08月13日   V2.1        Erie          验证运行类型与初始精度组合规则
// 2026年08月23日   V4.9        Erie          全部快照扩展为1024-bit V4+V5联合载荷，每次整体重建都补一份合法V5默认档案；新增MGR-17至MGR-24覆盖STATIC_BIAS/EXTERNAL_TEST_CURRENT/保留IDAC编码组合校验、run_generation与stop_episode_active观测、系统阻断START门；MGR-12保留IDAC枚举步骤按当前合同ERROR_RESERVED_IDAC_MODE重分类从0x05改为0x15。MGR-21按合同注记必须在Scheduler+SSW+AMI联合TB中验证，本TB故意不实现
// 2026年10月06日   V4.10       Erie          ABCD复核F-023：补MGR-11的RUN/STOPPING部分：STOP+START、STOP+status-clear、STOP+COMMIT各走一次独立RUN，STOP必须进入STOPPING（冲突的重复STOP保持幂等），关闭运行与新事务许可，置stop_episode_active，报0x01，代际、ACTIVE与config_epoch不变；排空后回CONFIG。信息行MGR11_STOP_PRIORITY
// 2026年10月09日   V4.11       Erie          B合并批次BMI-145（编号治理）：只改横幅文字。PASS横幅不再宣称覆盖MGR-21（本TB无此检查，C02要求三模块联合TB验证）；判定与计数不变。

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
	integer idx_mgr11_case;                // MGR-11 STOP优先：同拍冲突命令种类索引
	integer idx_mgr11_step;                // MGR-11 STOP优先：RUN与STOPPING两拍索引
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

		// MGR-05：RUN期间COMMIT必须拒绝且ACTIVE和epoch冻结
		i_config_snapshot[39:32] = 8'd65;   // 修改shadow AMB码验证RUN期冻结
		i_config_update_event = 1'b1;       // 在RUN状态发出非法COMMIT
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束RUN期非法COMMIT事件
		if(!o_error_event || (o_last_error_code != 8'h02) || (o_lifecycle_state != ST_RUN) || (o_config_epoch != 8'd1) || (o_active_config[39:32] != 8'd64))begin
			$display("FAIL MGR-05 run commit rejection"); // 报告RUN期配置冻结行为异常
			cnt_error = cnt_error + 1;      // 累计MGR-05运行期提交检查失败
		end

		// MGR-06：STOP立即关闭新事务，但未排空时保持STOPPING
		i_adc_idle = 1'b0;                  // 模拟仍有ADC事务在途
		i_datapath_empty = 1'b0;            // 模拟数字流水仍保存有效事务
		i_idac_idle = 1'b0;                 // 模拟IDAC仍有pending动作
		i_analog_safe = 1'b0;               // 模拟控制尚未回到安全状态
		i_stop_event = 1'b1;                // 请求进入STOPPING排空阶段
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;                // 结束首次STOP事件
		if(!o_stop_ack_event || (o_lifecycle_state != ST_STOPPING) || o_run_enable || o_allow_new_transaction)begin
			$display("FAIL MGR-06 stop entry"); // 报告STOPPING进入或事务门控异常
			cnt_error = cnt_error + 1;      // 累计MGR-06停止入口检查失败
		end

		// MGR-07：STOPPING重复STOP只返回幂等ACK且不置新错误
		i_stop_event = 1'b1;                // 在STOPPING中重复发送STOP
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;                // 结束幂等STOP事件
		if(!o_stop_ack_event || (o_lifecycle_state != ST_STOPPING) || o_error_event)begin
			$display("FAIL MGR-07 idempotent stop"); // 报告重复STOP应答或错误事件异常
			cnt_error = cnt_error + 1;      // 累计MGR-07幂等停止检查失败
		end

		// 全部排空和模拟安全后返回CONFIG并撤销active_valid
		i_adc_idle = 1'b1;                  // 声明ADC事务已经全部结束
		i_datapath_empty = 1'b1;            // 声明数字流水已经完全排空
		i_idac_idle = 1'b1;                 // 声明IDAC控制没有在途动作
		i_analog_safe = 1'b1;               // 声明模拟控制已经安全保持
		@(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_CONFIG) || o_active_valid)begin
			$display("FAIL MGR-06 stopping completion"); // 报告排空完成后的CONFIG返回异常
			cnt_error = cnt_error + 1;      // 累计MGR-06排空完成检查失败
		end

		// 清除RUN期拒绝错误后验证CONFIG中的START状态错误
		i_status_clear_event = 1'b1;        // 清除RUN期非法COMMIT错误
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束RUN期错误清除事件
		i_start_event = 1'b1;               // 在CONFIG状态发出非法START
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束CONFIG期非法START事件
		if(!o_error_event || (o_last_error_code != 8'h0a) || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL MGR-08 start in config"); // 报告CONFIG期START拒绝异常
			cnt_error = cnt_error + 1;      // 累计MGR-08非法启动检查失败
		end

		// MGR-09：标称CHARACTERIZATION允许资格位为0且不更新coef_epoch
		i_status_clear_event = 1'b1;        // 清除MGR-08遗留的CONFIG期START错误
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束MGR-09前置清除脉冲
		i_config_snapshot = {CONFIG_WIDTH{1'b0}}; // 先清空快照以暴露未声明字段
		drive_default_v5;                   // 补齐合法V5默认档案，避免全零V5违反跨字段范围校验
		i_config_snapshot[7:0] = 8'h04;     // 写入冻结V4 schema编号
		i_config_snapshot[8] = 1'b1;        // 明确选择实验室CHARACTERIZATION
		i_config_snapshot[11:10] = 2'b00;   // 选择允许的手动IDAC模式
		i_config_snapshot[13:12] = 2'b01;   // 光电二极管表征固定选择纯RED
		i_config_snapshot[19] = 1'b0;       // 标称权重不声明为流片校准结果
		i_config_snapshot[47:40] = 8'd0;    // 设定AMB手动码下限
		i_config_snapshot[55:48] = 8'd255;  // 设定AMB手动码上限
		i_config_snapshot[71:64] = 8'd0;    // 设定红光DCS码下限
		i_config_snapshot[79:72] = 8'd255;  // 设定红光DCS码上限
		i_config_snapshot[95:88] = 8'd0;    // 设定红外DCS码下限
		i_config_snapshot[103:96] = 8'd255; // 设定红外DCS码上限
		i_config_snapshot[115:104] = -12'sd64; // 写入AMB迟滞低阈值
		i_config_snapshot[127:116] = 12'sd64; // 写入AMB迟滞高阈值
		i_config_snapshot[139:128] = -12'sd48; // 写入DCS迟滞低阈值
		i_config_snapshot[151:140] = 12'sd48; // 写入DCS迟滞高阈值
		i_config_snapshot[159:152] = 8'd8;  // 设置AMB连续确认次数
		i_config_snapshot[167:160] = 8'd8;  // 设置DCS连续确认次数
		i_config_snapshot[193:168] = 26'sd65536; // 写入S1_RAW[0]标称Q16权重
		i_config_snapshot[219:194] = 26'sd131072; // 写入S1_RAW[1]标称Q16权重
		i_config_snapshot[245:220] = 26'sd262144; // 写入S1_RAW[2]标称Q16权重
		i_config_snapshot[271:246] = 26'sd524288; // 写入S1_RAW[3]冗余判决权重
		i_config_snapshot[297:272] = 26'sd524288; // 写入S1_RAW[4]标称Q16权重
		i_config_snapshot[323:298] = 26'sd1048576; // 写入S1_RAW[5]标称Q16权重
		i_config_snapshot[349:324] = 26'sd2097152; // 写入S1_RAW[6]标称Q16权重
		i_config_snapshot[375:350] = 26'sd4194304; // 写入S1_RAW[7]标称Q16权重
		i_config_snapshot[401:376] = 26'sd8388608; // 写入S1_RAW[8]标称Q16权重
		i_config_snapshot[427:402] = 26'sd16777216; // 写入S1_RAW[9]标称Q16权重
		i_config_snapshot[459:428] = -32'sd262144; // 写入固定公式的标称Q16 offset
		i_config_update_event = 1'b1;       // 请求CHARACTERIZATION快照原子提交
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束MGR-09配置提交事件
		if(!o_commit_ack_event || (o_lifecycle_state != ST_READY) || (o_config_epoch != 8'd2) || (o_coef_epoch != 8'd1) || (o_stage2_coef_epoch != 8'd1) || (o_dc_recovery_coef_epoch != 8'd2))begin
			$display("FAIL MGR-09 characterization commit"); // 报告CHARACTERIZATION提交结果不符
			cnt_error = cnt_error + 1;      // 累计MGR-09提交检查失败
		end

		// MGR-10：模拟未ready时START必须保持READY并返回资格错误
		i_analog_ready = 1'b0;              // 撤销模拟启动资格以构造拒绝条件
		i_start_event = 1'b1;               // 在资格不完整时发出START
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束MGR-10 START事件
		if(!o_error_event || (o_last_error_code != 8'h0b) || (o_lifecycle_state != ST_READY) || o_run_enable)begin
			$display("FAIL MGR-10 start qualification"); // 报告模拟资格拒绝结果不符
			cnt_error = cnt_error + 1;      // 累计MGR-10资格检查失败
		end

		// MGR-11：同拍START和STOP冲突，既不启动也不接受STOP
		i_start_event = 1'b1;               // 与STOP同时拉高以构造命令冲突
		i_stop_event = 1'b1;                // 与START同时拉高以构造命令冲突
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 撤销冲突中的START事件
		i_stop_event = 1'b0;                // 撤销冲突中的STOP事件
		if(!o_error_event || (o_last_error_code != 8'h01) || o_start_ack_event || o_stop_ack_event || (o_lifecycle_state != ST_READY))begin
			$display("FAIL MGR-11 command conflict"); // 报告互斥命令未被整体拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-11冲突检查失败
		end

		// 返回CONFIG以验证完整配置拒绝矩阵
		i_status_clear_event = 1'b1;        // 清除前序START资格和命令冲突错误
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束独立状态清除事件
		i_analog_ready = 1'b1;              // 恢复合法START所需的模拟资格
		i_start_event = 1'b1;               // 从READY进入RUN以便执行正常STOP
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // START事件只保持一个系统时钟周期
		i_stop_event = 1'b1;                // 在全部空闲条件满足时请求停止
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;                // STOP事件只保持一个系统时钟周期
		@(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_CONFIG) || o_active_valid)begin
			$display("FAIL MGR-12 return config before validation matrix"); // 报告拒绝矩阵前未回到安全CONFIG
			cnt_error = cnt_error + 1;      // 累计MGR-12前置状态检查失败
		end

		// MGR-12：逐类拒绝schema、保留位、枚举、码范围、确认次数和标称系数错误
		i_config_snapshot[7:0] = 8'h00;     // 构造错误schema版本
		i_config_update_event = 1'b1;       // 提交错误schema快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束错误schema提交事件
		if(!o_error_event || (o_last_error_code != 8'h03) || (o_config_epoch != 8'd2) || (o_coef_epoch != 8'd1))begin
			$display("FAIL MGR-12 schema validation"); // 报告schema拒绝码或epoch保持异常
			cnt_error = cnt_error + 1;      // 累计MGR-12 schema检查失败
		end
		i_config_snapshot[7:0] = 8'h04;     // 恢复冻结的V4 schema
		i_config_snapshot[23] = 1'b1;       // 构造头部保留位非零错误
		i_config_update_event = 1'b1;       // 提交保留位错误快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束保留位错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h04) || (o_config_epoch != 8'd2) || (o_coef_epoch != 8'd1))begin
			$display("FAIL MGR-12 reserved validation"); // 报告保留位拒绝行为异常
			cnt_error = cnt_error + 1;      // 累计MGR-12保留位检查失败
		end
		i_config_snapshot[23] = 1'b0;       // 恢复头部保留位全零合同
		i_config_snapshot[639] = 1'b1;      // 构造V4高位扩展保留区错误
		i_config_update_event = 1'b1;       // 提交高位保留区非零快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束高位保留区错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h04) || (o_config_epoch != 8'd2) || (o_dc_recovery_coef_epoch != 8'd2))begin
			$display("FAIL MGR-12 high reserved validation"); // 报告V4高位保留区未被拒绝
			cnt_error = cnt_error + 1;      // 累计高位保留区检查失败
		end
		i_config_snapshot[639] = 1'b0;      // 恢复V4扩展保留区全零合同
		i_config_snapshot[11:10] = 2'b11;   // 构造IDAC保留枚举编码
		i_config_update_event = 1'b1;       // 提交枚举错误快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束枚举错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h15) || (o_config_epoch != 8'd2) || (o_coef_epoch != 8'd1))begin
			$display("FAIL MGR-12 enum validation"); // 报告IDAC保留枚举未按V4.9的0x15重分类拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-12枚举检查失败
		end
		i_config_snapshot[11:10] = 2'b00;   // 恢复MANUAL IDAC模式
		i_config_snapshot[39:32] = 8'd255;  // 构造AMB手动码超过上限
		i_config_snapshot[55:48] = 8'd100;  // 收紧AMB允许上限形成范围错误
		i_config_update_event = 1'b1;       // 提交IDAC范围错误快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束IDAC范围错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h06) || (o_config_epoch != 8'd2) || (o_coef_epoch != 8'd1))begin
			$display("FAIL MGR-12 idac range validation"); // 报告手动码越界拒绝结果异常
			cnt_error = cnt_error + 1;      // 累计MGR-12码范围检查失败
		end
		i_config_snapshot[39:32] = 8'd0;    // 恢复合法AMB手动码
		i_config_snapshot[55:48] = 8'd255;  // 恢复合法AMB码上限
		i_config_snapshot[159:152] = 8'd0;  // 构造AMB确认次数为零
		i_config_update_event = 1'b1;       // 提交确认次数错误快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束确认次数错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h08) || (o_config_epoch != 8'd2) || (o_coef_epoch != 8'd1))begin
			$display("FAIL MGR-12 confirm count validation"); // 报告零确认次数拒绝结果异常
			cnt_error = cnt_error + 1;      // 累计MGR-12确认次数检查失败
		end
		i_config_snapshot[159:152] = 8'd8;  // 恢复合法AMB确认次数
		i_config_snapshot[193:168] = 26'sd0; // 破坏CHARACTERIZATION标称权重
		i_config_update_event = 1'b1;       // 提交标称系数错误快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束标称系数错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h09) || (o_config_epoch != 8'd2) || (o_coef_epoch != 8'd1))begin
			$display("FAIL MGR-12 coefficient validation"); // 报告标称Stage1系数拒绝结果异常
			cnt_error = cnt_error + 1;      // 累计MGR-12系数检查失败
		end
		i_config_snapshot[193:168] = 26'sd65536; // 恢复S1_RAW[0]标称1.0权重
		i_config_snapshot[20] = 1'b1;       // 声明Stage2系数有效以检查数值极性
		i_config_snapshot[479:460] = 20'sd0; // 构造零值Stage2增益错误
		i_config_update_event = 1'b1;       // 提交无正向Stage2增益的快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束Stage2系数错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h0e) || (o_config_epoch != 8'd2) || (o_stage2_coef_epoch != 8'd1))begin
			$display("FAIL MGR-12 stage2 coefficient validation"); // 报告Stage2资格或增益错误未被拒绝
			cnt_error = cnt_error + 1;      // 累计Stage2系数检查失败
		end
		i_config_snapshot[20] = 1'b0;       // 恢复CHARACTERIZATION临时Stage2参数语义
		i_config_snapshot[21] = 1'b1;       // 声明SAR9 DC恢复系数有效以检查极性
		i_config_snapshot[543:512] = -32'sd1; // 构造反向SAR9 DC恢复增益
		i_config_update_event = 1'b1;       // 提交DC恢复系统极性错误快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束DC恢复系数错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h0f) || (o_config_epoch != 8'd2) || (o_dc_recovery_coef_epoch != 8'd2))begin
			$display("FAIL MGR-12 dc recovery coefficient validation"); // 报告DC恢复极性错误未被拒绝
			cnt_error = cnt_error + 1;      // 累计DC恢复系数检查失败
		end
		i_config_snapshot[21] = 1'b0;       // 恢复CHARACTERIZATION未校准SAR9资格
		i_config_snapshot[543:512] = 32'sd0; // 恢复允许的临时零值恢复系数
		i_config_snapshot[8] = 1'b0;        // 切换到NORMAL以检查必需资格位
		i_config_snapshot[19] = 1'b1;       // 避免Stage1资格优先遮蔽Stage2错误
		i_config_update_event = 1'b1;       // 提交缺少Stage2资格的NORMAL快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束NORMAL Stage2资格错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h0e) || (o_config_epoch != 8'd2) || (o_stage2_coef_epoch != 8'd1))begin
			$display("FAIL MGR-12 normal stage2 qualification"); // 报告NORMAL缺少Stage2资格未被拒绝
			cnt_error = cnt_error + 1;      // 累计NORMAL Stage2资格检查失败
		end
		i_config_snapshot[20] = 1'b1;       // 补齐NORMAL Stage2正式校准资格
		i_config_snapshot[479:460] = 20'sd54143; // 写回正向Stage2标称Q16增益
		i_config_update_event = 1'b1;       // 提交缺少两组DC恢复资格的NORMAL快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束NORMAL DC恢复资格错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h0f) || (o_config_epoch != 8'd2) || (o_dc_recovery_coef_epoch != 8'd2))begin
			$display("FAIL MGR-12 normal dc qualification"); // 报告NORMAL缺少DC恢复资格未被拒绝
			cnt_error = cnt_error + 1;      // 累计NORMAL DC恢复资格检查失败
		end
		i_config_snapshot[8] = 1'b1;        // 恢复后续CHARACTERIZATION测试上下文
		i_config_snapshot[19] = 1'b0;       // 恢复标称Stage1参数资格声明
		i_config_snapshot[20] = 1'b0;       // 恢复临时Stage2参数资格声明

		// MGR-13：CONFIG状态STOP必须报告固定的非法状态错误
		i_stop_event = 1'b1;                // 在CONFIG状态发出非法STOP
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;                // 结束非法STOP事件
		if(!o_error_event || (o_last_error_code != 8'h0c) || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL MGR-13 stop in config"); // 报告CONFIG期STOP错误分类异常
			cnt_error = cnt_error + 1;      // 累计MGR-13非法停止检查失败
		end
		@(posedge i_clk);
		#1;
		if(o_error_event || o_commit_ack_event || o_start_ack_event || o_stop_ack_event)begin
			$display("FAIL MGR-13 event pulse width"); // 报告应答或错误事件超过单拍
			cnt_error = cnt_error + 1;      // 累计MGR-13脉宽检查失败
		end

		// MGR-14：8-bit配置和系数epoch必须按模256回绕
		i_status_clear_event = 1'b1;        // 清除验证矩阵产生的sticky错误
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束状态清除事件
		i_config_snapshot[8] = 1'b0;        // 切换为NORMAL_PPG配置
		i_config_snapshot[19] = 1'b1;       // 声明完整Stage1校准系数有效
		i_config_snapshot[20] = 1'b1;       // 声明完整Stage2校准系数有效
		i_config_snapshot[21] = 1'b1;       // 声明SAR9 DC恢复校准有效
		i_config_snapshot[22] = 1'b1;       // 声明SAR15 DC恢复校准有效
		i_config_snapshot[479:460] = 20'sd54143; // 恢复正极性的Stage2标称增益
		i_config_snapshot[543:512] = 32'sd65536; // 恢复正SAR9 DC输入等效系数
		i_config_snapshot[575:544] = 32'sd32768; // 恢复正SAR15 DC输入等效系数
		i_config_snapshot[591:576] = 16'hffff; // 验证最大16-bit AMB周期编码允许提交
		@(negedge i_clk);
		inst_ppg_system_config_manager.config_epoch_o = 8'hff; // 注入配置epoch最大值以验证回绕
		inst_ppg_system_config_manager.coef_epoch_o = 8'hff; // 注入系数epoch最大值以验证回绕
		inst_ppg_system_config_manager.stage2_coef_epoch_o = 8'hff; // 注入Stage2 epoch最大值以验证回绕
		inst_ppg_system_config_manager.dc_recovery_coef_epoch_o = 8'hff; // 注入DC恢复epoch最大值以验证回绕
		i_config_update_event = 1'b1;       // 提交合法NORMAL快照触发双epoch递增
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束合法回绕提交事件
		if(!o_commit_ack_event || (o_config_epoch != 8'h00) || (o_coef_epoch != 8'h00) || (o_stage2_coef_epoch != 8'h00) || (o_dc_recovery_coef_epoch != 8'h00) || (o_active_config[591:576] != 16'hffff) || (o_lifecycle_state != ST_READY))begin
			$display("FAIL MGR-14 epoch wrap"); // 报告双epoch模256回绕异常
			cnt_error = cnt_error + 1;      // 累计MGR-14回绕检查失败
		end
		@(posedge i_clk);
		#1;
		if(o_commit_ack_event)begin
			$display("FAIL MGR-14 commit ack pulse width"); // 报告COMMIT应答未在下一拍清零
			cnt_error = cnt_error + 1;      // 累计MGR-14应答脉宽检查失败
		end

		// MGR-15：非法内部状态必须上报0x0d、撤销资格并回到CONFIG
		@(negedge i_clk);
		inst_ppg_system_config_manager.state_current = 3'b100; // 注入首个保留FSM编码验证安全恢复
		@(posedge i_clk);
		#1;
		if(!o_error_event || !o_error_sticky || (o_last_error_code != 8'h0d) || (o_lifecycle_state != ST_CONFIG) || o_active_valid || o_run_enable || o_allow_new_transaction)begin
			$display("FAIL MGR-15 illegal state recovery"); // 报告非法FSM编码的安全恢复异常
			cnt_error = cnt_error + 1;      // 累计MGR-15恢复检查失败
		end
		@(posedge i_clk);
		#1;
		if(o_error_event)begin
			$display("FAIL MGR-15 illegal state event pulse width"); // 报告非法状态错误事件超过单拍
			cnt_error = cnt_error + 1;      // 累计MGR-15事件脉宽检查失败
		end

		// MGR-16：运行类型与初始精度组合必须在COMMIT阶段严格校验
		i_status_clear_event = 1'b1;        // 清除MGR-15非法状态诊断以恢复独立测试上下文
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束MGR-16前置状态清除事件
		i_config_snapshot[8] = 1'b0;        // 选择NORMAL_PPG运行类型
		i_config_snapshot[14] = 1'b1;       // 构造NORMAL非法SAR15初始精度
		i_config_snapshot[19] = 1'b1;       // 保持NORMAL Stage1正式校准资格完整
		i_config_snapshot[20] = 1'b1;       // 保持NORMAL Stage2正式校准资格完整
		i_config_snapshot[21] = 1'b1;       // 保持NORMAL SAR9 DC恢复资格完整
		i_config_snapshot[22] = 1'b1;       // 保持NORMAL SAR15 DC恢复资格完整
		i_config_snapshot[479:460] = 20'sd54143; // 保持Stage2正增益避免遮蔽组合错误
		i_config_snapshot[543:512] = 32'sd65536; // 保持SAR9恢复正增益避免其他拒绝
		i_config_snapshot[575:544] = 32'sd32768; // 保持SAR15恢复正增益避免其他拒绝
		reg_mgr16_active_snapshot = o_active_config; // 快照非法提交前的ACTIVE内容
		reg_mgr16_config_epoch = o_config_epoch; // 快照非法提交前的配置版本
		reg_mgr16_coef_epoch = o_coef_epoch; // 快照非法提交前的Stage1版本
		reg_mgr16_stage2_epoch = o_stage2_coef_epoch; // 快照非法提交前的Stage2版本
		reg_mgr16_dc_epoch = o_dc_recovery_coef_epoch; // 快照非法提交前的DC恢复版本
		i_config_update_event = 1'b1;       // 提交NORMAL加SAR15非法组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束非法运行类型组合提交
		if(!o_error_event || (o_last_error_code != 8'h10) || o_commit_ack_event || o_active_valid || (o_lifecycle_state != ST_CONFIG) || (o_active_config != reg_mgr16_active_snapshot) || (o_config_epoch != reg_mgr16_config_epoch) || (o_coef_epoch != reg_mgr16_coef_epoch) || (o_stage2_coef_epoch != reg_mgr16_stage2_epoch) || (o_dc_recovery_coef_epoch != reg_mgr16_dc_epoch))begin
			$display("FAIL MGR-16 normal SAR15 rejection"); // 报告非法NORMAL初始精度未被原子拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-16非法组合检查失败
		end
		i_status_clear_event = 1'b1;        // 清除非法组合产生的sticky错误
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束MGR-16错误清除事件
		i_config_snapshot[14] = 1'b0;       // 恢复NORMAL规范SAR9初始精度
		i_config_update_event = 1'b1;       // 提交合法NORMAL加SAR9组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束合法NORMAL组合提交
		if(!o_commit_ack_event || !o_active_valid || (o_lifecycle_state != ST_READY) || (o_active_config[8] != 1'b0) || (o_active_config[14] != 1'b0))begin
			$display("FAIL MGR-16 normal SAR9 acceptance"); // 报告规范NORMAL配置未进入READY
			cnt_error = cnt_error + 1;      // 累计MGR-16合法NORMAL检查失败
		end
		i_start_event = 1'b1;               // 进入RUN以便通过STOP返回CONFIG继续测试
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束MGR-16中间START事件
		i_stop_event = 1'b1;                // 请求合法NORMAL运行返回安全CONFIG
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;                // 结束MGR-16中间STOP事件
		@(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_CONFIG) || o_active_valid)begin
			$display("FAIL MGR-16 return config after normal"); // 报告四组合测试中间生命周期未排空
			cnt_error = cnt_error + 1;      // 累计MGR-16返回CONFIG检查失败
		end
		i_config_snapshot[8] = 1'b1;        // 切换到CHARACTERIZATION运行类型
		i_config_snapshot[9] = 1'b0;        // 选择光电二极管纯RED表征输入
		i_config_snapshot[11:10] = 2'b00;   // CHARACTERIZATION固定使用MANUAL IDAC
		i_config_snapshot[13:12] = 2'b01;   // 光电二极管表征只允许RED_ONLY
		i_config_snapshot[14] = 1'b0;       // 选择表征模式SAR9初始精度
		i_config_snapshot[19] = 1'b0;       // 表征使用完整标称Stage1权重
		i_config_snapshot[20] = 1'b0;       // 表征使用临时Stage2参数且不声明校准
		i_config_snapshot[21] = 1'b0;       // 表征不声明SAR9恢复正式校准
		i_config_snapshot[22] = 1'b0;       // 表征不声明SAR15恢复正式校准
		i_config_update_event = 1'b1;       // 提交CHARACTERIZATION加SAR9组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束表征SAR9组合提交
		if(!o_commit_ack_event || !o_active_valid || (o_lifecycle_state != ST_READY) || (o_active_config[8] != 1'b1) || (o_active_config[14] != 1'b0))begin
			$display("FAIL MGR-16 characterization SAR9 acceptance"); // 报告表征SAR9配置被错误拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-16表征SAR9检查失败
		end
		i_start_event = 1'b1;               // 启动表征SAR9以便合法STOP返回CONFIG
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束表征SAR9 START事件
		i_stop_event = 1'b1;                // 请求表征SAR9运行停止
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;                // 结束表征SAR9 STOP事件
		@(posedge i_clk);
		#1;
		i_config_snapshot[14] = 1'b1;       // 选择表征模式SAR15初始精度
		i_config_update_event = 1'b1;       // 提交CHARACTERIZATION加SAR15组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束表征SAR15组合提交
		if(!o_commit_ack_event || !o_active_valid || (o_lifecycle_state != ST_READY) || (o_active_config[8] != 1'b1) || (o_active_config[14] != 1'b1))begin
			$display("FAIL MGR-16 characterization SAR15 acceptance"); // 报告表征SAR15配置被错误拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-16表征SAR15检查失败
		end

		// 返回CONFIG以便执行MGR-17起新增的V4.9组合校验、STATIC_BIAS所有权与系统阻断门检查
		i_start_event = 1'b1;               // 从READY进入RUN以便通过STOP排空
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束中间START事件
		i_stop_event = 1'b1;                // 请求排空返回CONFIG
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;                // 结束中间STOP事件
		@(posedge i_clk);
		#1;

		// MGR-17：CHARACTERIZATION+EXTERNAL_TEST_CURRENT+BOTH+SAR9必须被接受
		i_config_snapshot[9] = 1'b1;        // 切换为外部固定电流输入源
		i_config_snapshot[13:12] = 2'b00;   // 选择双光BOTH光学模式
		i_config_snapshot[14] = 1'b0;       // 选择SAR9初始精度
		i_config_update_event = 1'b1;       // 提交固定电流双光SAR9组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束固定电流双光提交事件
		if(!o_commit_ack_event || !o_active_valid || (o_lifecycle_state != ST_READY) || (o_active_config[9] != 1'b1) || (o_active_config[13:12] != 2'b00))begin
			$display("FAIL MGR-17 characterization external current both"); // 报告固定电流双光合法组合被错误拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-17固定电流组合检查失败
		end
		i_start_event = 1'b1;               // 返回CONFIG准备下一组合
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;
		i_stop_event = 1'b1;
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;
		@(posedge i_clk);
		#1;

		// MGR-17续：已提交STATIC_BIAS资格时CHARACTERIZATION+外部固定电流必须被接受
		i_static_characterization_enable = 1'b1; // 提交STATIC_BIAS资格
		i_config_update_event = 1'b1;       // 快照仍为CHARACTERIZATION+外部固定电流+双光+SAR9
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束STATIC_BIAS组合提交事件
		if(!o_commit_ack_event || !o_active_valid || (o_lifecycle_state != ST_READY))begin
			$display("FAIL MGR-17 static bias acceptance"); // 报告STATIC_BIAS合法组合被错误拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-17 STATIC_BIAS检查失败
		end
		i_start_event = 1'b1;               // 返回CONFIG准备MGR-18非法组合矩阵
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;
		i_stop_event = 1'b1;
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;
		@(posedge i_clk);
		#1;
		i_static_characterization_enable = 1'b0; // 恢复非STATIC_BIAS默认资格

		// MGR-18：逐类拒绝V4.9新增的非法运行组合，均在CONFIG内连续提交无需往返状态
		i_config_snapshot[8] = 1'b0;        // 选择NORMAL_PPG
		i_config_snapshot[9] = 1'b1;        // 错误请求外部固定电流输入源
		i_config_snapshot[14] = 1'b0;       // 保持SAR9避免遮蔽本项错误
		i_config_snapshot[11:10] = 2'b00;   // 保持MANUAL IDAC避免遮蔽本项错误
		i_config_update_event = 1'b1;       // 提交NORMAL加外部固定电流非法组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束NORMAL固定电流错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h11) || o_active_valid || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL MGR-18 normal external current rejection"); // 报告NORMAL加外部固定电流未被拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-18 NORMAL固定电流检查失败
		end
		i_config_snapshot[8] = 1'b1;        // 切换为CHARACTERIZATION
		i_config_snapshot[9] = 1'b0;        // 选择光电二极管输入源
		i_config_snapshot[13:12] = 2'b01;   // 选择RED_ONLY避免遮蔽本项错误
		i_config_snapshot[11:10] = 2'b01;   // 构造自动SEARCH_HOLD IDAC非法组合
		i_config_update_event = 1'b1;       // 提交CHARACTERIZATION加自动IDAC非法组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束自动IDAC错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h12) || o_active_valid || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL MGR-18 characterization auto idac rejection"); // 报告CHARACTERIZATION自动IDAC未被拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-18自动IDAC检查失败
		end
		i_config_snapshot[11:10] = 2'b00;   // 恢复MANUAL IDAC模式
		i_config_snapshot[13:12] = 2'b00;   // 构造光电二极管非纯红光非法组合
		i_config_update_event = 1'b1;       // 提交光电二极管双光非法组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束光电二极管光学模式错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h13) || o_active_valid || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL MGR-18 characterization photodiode optical rejection"); // 报告光电二极管非纯红光未被拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-18光学模式检查失败
		end
		i_config_snapshot[9] = 1'b1;        // 切换为外部固定电流输入源
		i_config_snapshot[13:12] = 2'b11;   // 构造非STATIC_BIAS的安全关闭光学模式非法组合
		i_config_update_event = 1'b1;       // 提交固定电流安全关闭非法组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束固定电流安全关闭错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h16) || o_active_valid || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL MGR-18 fixed current optical off rejection"); // 报告非STATIC_BIAS固定电流安全关闭未被拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-18固定电流关闭检查失败
		end

		// MGR-19：已提交STATIC_BIAS资格但候选输入源仍为光电二极管必须拒绝
		i_config_snapshot[9] = 1'b0;        // 候选恢复光电二极管输入源
		i_config_snapshot[13:12] = 2'b01;   // 候选恢复RED_ONLY避免遮蔽本项错误
		i_static_characterization_enable = 1'b1; // 提交STATIC_BIAS资格但候选输入源不符
		i_config_update_event = 1'b1;       // 提交STATIC_BIAS加光电二极管非法组合
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束STATIC_BIAS输入源错误提交事件
		if(!o_error_event || (o_last_error_code != 8'h14) || o_active_valid || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL MGR-19 static bias input source rejection"); // 报告STATIC_BIAS光电二极管输入源未被拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-19 STATIC_BIAS输入源检查失败
		end
		i_static_characterization_enable = 1'b0; // 恢复非STATIC_BIAS默认资格

		// MGR-20：idac_mode保留编码2'b11必须原子拒绝并归类为0x15
		i_config_snapshot[11:10] = 2'b11;   // 构造保留IDAC编码
		i_config_update_event = 1'b1;       // 提交保留IDAC编码快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束保留IDAC编码提交事件
		if(!o_error_event || (o_last_error_code != 8'h15) || o_active_valid || (o_lifecycle_state != ST_CONFIG))begin
			$display("FAIL MGR-20 reserved idac mode rejection"); // 报告保留IDAC编码未按0x15拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-20保留编码检查失败
		end
		i_config_snapshot[11:10] = 2'b00;   // 恢复MANUAL IDAC模式

		// 提交一笔干净的NORMAL_PPG合法快照，为MGR-22/24的START拒绝场景建立READY基线
		i_status_clear_event = 1'b1;        // 清除MGR-18/19/20遗留的sticky错误
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束前置状态清除事件
		i_config_snapshot[8] = 1'b0;        // 选择NORMAL_PPG运行类型
		i_config_snapshot[9] = 1'b0;        // 选择光电二极管输入源
		i_config_snapshot[14] = 1'b0;       // 选择NORMAL规范SAR9初始精度
		i_config_snapshot[19] = 1'b1;       // NORMAL_PPG要求Stage1正式校准资格
		i_config_snapshot[20] = 1'b1;       // NORMAL_PPG要求Stage2正式校准资格
		i_config_snapshot[21] = 1'b1;       // NORMAL_PPG要求SAR9 DC恢复资格
		i_config_snapshot[22] = 1'b1;       // NORMAL_PPG要求SAR15 DC恢复资格
		i_config_snapshot[479:460] = 20'sd54143; // 恢复正极性Stage2标称Q16增益
		i_config_snapshot[543:512] = 32'sd65536; // 恢复正SAR9 DC输入等效Q16系数
		i_config_snapshot[575:544] = 32'sd32768; // 恢复正SAR15 DC输入等效Q16系数
		i_config_update_event = 1'b1;       // 提交干净NORMAL_PPG快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束干净NORMAL_PPG提交事件
		if(!o_commit_ack_event || !o_active_valid || (o_lifecycle_state != ST_READY))begin
			$display("FAIL MGR-22 normal baseline commit"); // 报告MGR-22前置NORMAL基线提交异常
			cnt_error = cnt_error + 1;      // 累计MGR-22前置基线检查失败
		end

		// MGR-22：COMMIT后、START前STATIC_BIAS资格由0变1时必须在START拍重新核对ACTIVE并拒绝
		reg_snapshot_before = o_active_config; // 记录START拒绝前的ACTIVE基线
		reg_epoch_before = o_config_epoch;  // 记录START拒绝前的配置版本基线
		reg_generation_before = o_run_generation; // 记录START拒绝前的代际基线
		i_static_characterization_enable = 1'b1; // START前把STATIC_BIAS资格从0改为1
		i_start_event = 1'b1;               // 在ACTIVE不满足STATIC_BIAS组合时请求START
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束MGR-22非法START事件
		if(!o_error_event || (o_last_error_code != 8'h14) || (o_lifecycle_state != ST_READY) || (o_active_config != reg_snapshot_before) || (o_config_epoch != reg_epoch_before) || (o_run_generation != reg_generation_before))begin
			$display("FAIL MGR-22 static bias ownership rejection"); // 报告START拍STATIC_BIAS资格复核未拒绝或产生副作用
			cnt_error = cnt_error + 1;      // 累计MGR-22所有权检查失败
		end
		i_static_characterization_enable = 1'b0; // 资格复原为0，ACTIVE本身满足非STATIC_BIAS的NORMAL_PPG
		i_status_clear_event = 1'b1;        // 清除被拒绝START留下的sticky错误，否则error_sticky会继续挡住合法START
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束MGR-22恢复前置清除事件
		i_start_event = 1'b1;               // 资格复原后合法START必须成功
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束MGR-22合法START事件
		if(!o_start_ack_event || (o_lifecycle_state != ST_RUN) || (o_run_generation != (reg_generation_before + 1'b1)))begin
			$display("FAIL MGR-22 recovery start"); // 报告资格复原后合法START或代际递增异常
			cnt_error = cnt_error + 1;      // 累计MGR-22恢复检查失败
		end

		// 排空返回CONFIG并重新提交NORMAL_PPG，为MGR-24系统阻断START门建立新的READY基线
		i_adc_idle = 1'b0;                  // 构造未排空的STOPPING中间态
		i_datapath_empty = 1'b0;
		i_idac_idle = 1'b0;
		i_analog_safe = 1'b0;
		i_stop_event = 1'b1;
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;
		i_adc_idle = 1'b1;                  // 声明数字与模拟链均已排空
		i_datapath_empty = 1'b1;
		i_idac_idle = 1'b1;
		i_analog_safe = 1'b1;
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b1;       // 重新提交同一份合法NORMAL_PPG快照
		@(posedge i_clk);
		#1;
		i_config_update_event = 1'b0;       // 结束MGR-24前置NORMAL提交事件
		if(!o_commit_ack_event || !o_active_valid || (o_lifecycle_state != ST_READY))begin
			$display("FAIL MGR-24 normal baseline commit"); // 报告MGR-24前置NORMAL基线提交异常
			cnt_error = cnt_error + 1;      // 累计MGR-24前置基线检查失败
		end

		// MGR-24：supervisor系统阻断电平为高时START必须拒绝且不进RUN、不递增代际
		reg_generation_before = o_run_generation; // 记录阻断期间的代际基线
		i_system_fault_blocking = 1'b1;     // 声明系统阻断故障仍未解除
		i_start_event = 1'b1;               // 在系统阻断期间请求START
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束MGR-24阻断期START事件
		if(!o_error_event || (o_lifecycle_state != ST_READY) || o_run_enable || (o_run_generation != reg_generation_before))begin
			$display("FAIL MGR-24 system fault blocking rejection"); // 报告系统阻断期间START未被正确拒绝
			cnt_error = cnt_error + 1;      // 累计MGR-24阻断检查失败
		end
		i_system_fault_blocking = 1'b0;     // 阻断解除
		i_status_clear_event = 1'b1;        // 清除被拒绝START留下的sticky错误，否则error_sticky会继续挡住合法START
		@(posedge i_clk);
		#1;
		i_status_clear_event = 1'b0;        // 结束MGR-24恢复前置清除事件
		i_start_event = 1'b1;               // 阻断解除且资格齐全后合法START必须成功并递增代际
		@(posedge i_clk);
		#1;
		i_start_event = 1'b0;               // 结束MGR-24恢复START事件
		if(!o_start_ack_event || (o_lifecycle_state != ST_RUN) || (o_run_generation != (reg_generation_before + 1'b1)))begin
			$display("FAIL MGR-24 recovery start generation"); // 报告阻断解除后合法START或代际递增异常
			cnt_error = cnt_error + 1;      // 累计MGR-24恢复检查失败
		end
		i_stop_event = 1'b1;                // 排空返回CONFIG，结束附加用例序列
		@(posedge i_clk);
		#1;
		i_stop_event = 1'b0;
		@(posedge i_clk);
		#1;

		// MGR-11（RUN/STOPPING部分）：Top合并STOP与START/status-clear/COMMIT同拍时STOP优先进入或保持STOPPING，
		// 同拍的另一命令被拒绝并记录0x01；三种组合各走一次独立RUN（k=0 START、k=1 status-clear、k=2 COMMIT）
		for(idx_mgr11_case = 0; idx_mgr11_case < 3; idx_mgr11_case = idx_mgr11_case + 1)begin
			i_config_update_event = 1'b1;   // CONFIG中重新提交同一份合法NORMAL_PPG快照建立READY
			@(posedge i_clk);
			#1;
			i_config_update_event = 1'b0;
			i_status_clear_event = 1'b1;    // 清除前序sticky错误，否则error_sticky会挡住合法START
			@(posedge i_clk);
			#1;
			i_status_clear_event = 1'b0;
			i_start_event = 1'b1;           // 合法START进入RUN
			@(posedge i_clk);
			#1;
			i_start_event = 1'b0;
			if(o_lifecycle_state != ST_RUN)begin
				$display("FAIL MGR-11 stop priority case %0d did not reach RUN", idx_mgr11_case); // 前置RUN建立异常
				cnt_error = cnt_error + 1;
			end
			reg_generation_before = o_run_generation; // 记录RUN代际，冲突STOP不得改变
			reg_snapshot_before = o_active_config;    // 记录ACTIVE，冲突COMMIT不得替换
			reg_epoch_before = o_config_epoch;        // 记录配置版本，冲突COMMIT不得递增
			i_adc_idle = 1'b0;              // 保持未排空，使STOPPING可在第二拍继续观察
			i_datapath_empty = 1'b0;
			i_idac_idle = 1'b0;
			i_analog_safe = 1'b0;
			for(idx_mgr11_step = 0; idx_mgr11_step < 2; idx_mgr11_step = idx_mgr11_step + 1)begin
				i_stop_event = 1'b1;        // step0：RUN中冲突STOP；step1：STOPPING中冲突的重复STOP
				i_start_event = (idx_mgr11_case == 0);
				i_status_clear_event = (idx_mgr11_case == 1);
				i_config_update_event = (idx_mgr11_case == 2);
				@(posedge i_clk);
				#1;
				i_stop_event = 1'b0;
				i_start_event = 1'b0;
				i_status_clear_event = 1'b0;
				i_config_update_event = 1'b0;
				if(!o_stop_ack_event || (o_lifecycle_state != ST_STOPPING) || o_run_enable || o_allow_new_transaction || !o_stop_episode_active ||
					!o_error_event || (o_last_error_code != 8'h01) || !o_error_sticky || o_start_ack_event || o_commit_ack_event ||
					(o_run_generation != reg_generation_before) || (o_active_config != reg_snapshot_before) || (o_config_epoch != reg_epoch_before))begin
					$display("FAIL MGR-11 stop priority case %0d step %0d ack=%b state=%0d run=%b allow=%b episode=%b err=%b code=%h", idx_mgr11_case, idx_mgr11_step,
						o_stop_ack_event, o_lifecycle_state, o_run_enable, o_allow_new_transaction, o_stop_episode_active, o_error_event, o_last_error_code); // STOP被同拍命令吞掉或冲突诊断缺失
					cnt_error = cnt_error + 1;
				end
			end
			i_adc_idle = 1'b1;              // 排空完成后返回CONFIG
			i_datapath_empty = 1'b1;
			i_idac_idle = 1'b1;
			i_analog_safe = 1'b1;
			@(posedge i_clk);
			#1;
			if((o_lifecycle_state != ST_CONFIG) || o_active_valid || o_stop_episode_active)begin
				$display("FAIL MGR-11 stop priority case %0d drain did not return CONFIG", idx_mgr11_case); // 冲突STOP后排空未正常完成
				cnt_error = cnt_error + 1;
			end
		end
		$display("MGR11_STOP_PRIORITY cases=3 steps_per_case=2"); // 信息行：RUN与STOPPING冲突STOP组合已执行

		reg_mgr16_active_snapshot = o_active_config;
		reg_mgr16_config_epoch = o_config_epoch;
		reg_mgr16_coef_epoch = o_coef_epoch;
		reg_mgr16_stage2_epoch = o_stage2_coef_epoch;
		reg_mgr16_dc_epoch = o_dc_recovery_coef_epoch;
		if(cnt_error == 0)begin
			$display("PASS: ppg_system_config_manager MGR-01 through MGR-24 except MGR-21 (joint-TB item) all directed checks passed"); // 仅在全部MGR检查无误时报告通过
		end else begin
			$display("FAIL: ppg_system_config_manager detected %0d errors", cnt_error); // 汇总所有定向检查失败数量
		end
		$finish;                            // 完成全部定向用例后结束仿真
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
