`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/07/23
// Design Name:     PPG Dual Precision Timing Top
// Module Name:     ppg_dual_precision_top
// Description:     Description/ppg_dual_precision_top_Design.pdf
// Simulations:     tb_ppg_dual_precision_top.v
//
// Referrences:     ../ppg_system_integration/PPG_NEW_CHAT_CONTEXT.md
//
// Dependencies:    ppg_reset_sync.v, ppg_config_cdc_bridge.v,
//                  ppg_timing_sar9.v, ppg_timing_sar15.v
//
// Version:         V1.0
// Revision Date:   2026/07/23
// History:
//     Time          Version     Revised by     Contents
// 2026/07/23        V1.0        Erie          Create file.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年07月23日
// 设计名称:        PPG 双精度时序顶层
// 模块名称:        ppg_dual_precision_top
// 模块说明:        Description/ppg_dual_precision_top_Design.pdf
// 仿真工程:        tb_ppg_dual_precision_top.v
//
// 参考资料:        ../ppg_system_integration/PPG_NEW_CHAT_CONTEXT.md
//
// 依赖文件:        ppg_reset_sync.v、ppg_config_cdc_bridge.v、ppg_timing_sar9.v、ppg_timing_sar15.v
//
// 当前版本:        V1.0
// 修订日期:        2026年07月23日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年07月23日   V1.0        Erie          创建文件

// 在独立 5000 拍 SAR9/SAR15 时序核之上实现原子配置和帧安全精度切换
module ppg_dual_precision_top
(
	//---------------全局信号---------------//
	input i_clk,                                      // 外部输入经 HtoL 后的 2 MHz 数字主时钟
	input i_rstn,                                     // 同时异步置低两个时钟域的全局复位

	//---------------SPI 接口---------------//
	input i_spi_sclk,                                 // 与 2 MHz 主时钟无固定相位关系的 SPI 时钟
	input i_spi_config_commit,                        // 由 SPI 寄存器组产生的原子配置提交脉冲
	input i_spi_timing_enable,                        // 请求开启选中精度的间歇采样时序
	input i_spi_precision_mode,                       // 手动精度请求，低电平为 SAR9，高电平为 SAR15
	input i_spi_test_mode,                            // 独立选择光电前端或实验室测试电流路径
	input [1:0]i_spi_optical_mode,                    // 选择双光、红光、红外或保留关断组合
	input i_spi_static_characterization_enable,       // 独立启用静态 IDAC 表征输出覆盖
	input [4:0]i_spi_test_mux_ctrl,                   // 配置 S0_IN 至 S4_IN 模拟测试开关
	input [7:0]i_spi_static_sar9_amb_code,            // 静态表征使用的 SAR9 环境光抵消码
	input [7:0]i_spi_static_sar9_dc_code,             // 静态表征使用的 SAR9 直流抵消码
	input [7:0]i_spi_static_sar15_amb_code,           // 静态表征使用的 SAR15 环境光抵消码
	input [7:0]i_spi_static_sar15_dc_code,            // 静态表征使用的 SAR15 直流抵消码
	input [7:0]i_spi_leddac_r_code,                   // 红光阶段的 LED 驱动电流设定码
	input [7:0]i_spi_leddac_ir_code,                  // 红外阶段的 LED 驱动电流设定码
	input [7:0]i_spi_idac_sar9_amb_r_code,            // SAR9 红光环境光抵消时序码
	input [7:0]i_spi_idac_sar9_amb_ir_code,           // SAR9 红外环境光抵消时序码
	input [7:0]i_spi_idac_sar9_dc_r_code,             // SAR9 红光直流分量抵消时序码
	input [7:0]i_spi_idac_sar9_dc_ir_code,            // SAR9 红外直流分量抵消时序码
	input [7:0]i_spi_idac_sar15_amb_r_code,           // SAR15 红光环境光抵消时序码
	input [7:0]i_spi_idac_sar15_amb_ir_code,          // SAR15 红外环境光抵消时序码
	input [7:0]i_spi_idac_sar15_dc_r_code,            // SAR15 红光直流分量抵消时序码
	input [7:0]i_spi_idac_sar15_dc_ir_code,           // SAR15 红外直流分量抵消时序码
	output o_spi_config_busy,                         // 要求 SPI 寄存器组在忙期间不再发起提交

	//----------帧同步与模式状态输出-------//
	output o_frame_start_400hz,                       // 选中时序核每 5000 拍产生的单周期帧脉冲
	output o_active_precision_mode,                   // 当前帧实际采用的低 SAR9 高 SAR15 精度状态
	output o_config_applied,                          // 新配置在预建立窗口前安全生效的单周期指示

	//-----------公共模拟控制输出--------//
	output o_en_tia_low,                              // 选中精度核生成的 TIA 工作窗口
	output [7:0]o_leddac,                             // 与当前红光或红外时隙对应的 LED 码
	output o_leden1_low,                              // 红光 LED1 的帧内驱动窗口
	output o_leden2_low,                              // 红外 LED2 的帧内驱动窗口
	output o_en_test,                                 // 不受静态表征或精度选择影响的前端测试选择
	output o_clk_buf_low,                             // 静态表征期间的模拟时钟缓冲控制
	output o_clk_2m,                                  // 同相送往模拟边界的 2 MHz 时钟逻辑端
	output o_clk_iref_idac_low,                       // 分光学阶段的本地 IDAC 参考时序
	output o_clk_9q1_low,                             // 仅 SAR9 模式活动的第一阶段采样相位
	output o_clk_15q1_low,                            // 仅 SAR15 模式活动的精细路径 Q1 相位
	output o_clk_aferst_low,                          // 模拟前端复位与释放时间窗口
	output o_clk_iref_idac_sar9_low,                  // SAR9 IDAC 参考分支的帧内时序
	output o_clk_iref_idac_sar15_low,                 // SAR15 IDAC 参考分支的跨 R/IR 连续时序
	output o_clk_q2_low,                              // 保持 R/IR 对应边沿相差 160 拍的 Q2 相位
	output o_clk_q3_low,                              // SAR9 和 SAR15 共用红光 17 us、红外 97 us 中心
	output o_clk_tiaen_low,                           // 模拟前端本地 TIA 使能时序

	//---------精度与 IDAC 使能输出-------//
	output o_en_15sar_low,                            // 帧安全精度选择，低选 SAR9，高选 SAR15
	output o_en_sar9_amb_low,                         // SAR9 环境光抵消分支的活动窗口
	output o_en_sar9_dc_low,                          // SAR9 直流抵消分支的保持窗口
	output o_en_sar9_iref,                            // SAR9 局部参考电流分支使能
	output o_en_sar15_amb_low,                        // SAR15 环境光抵消分支跨光学相位使能
	output o_en_sar15_dc_low,                         // SAR15 直流抵消分支连续保持使能
	output o_en_sar15_iref,                           // SAR15 共享参考电流支路的建立使能

	//-------------IDAC 码值输出------------//
	output [7:0]o_idac_sar9ambn_low,                  // SAR9 环境光抵消输出码
	output [7:0]o_idac_sar9dcn_low,                   // SAR9 直流分量抵消输出码
	output [7:0]o_idac_sar15ambn_low,                 // SAR15 环境光抵消输出码
	output [7:0]o_idac_sar15dcn_low,                  // SAR15 直流分量抵消输出码

	//-------------测试开关输出------------//
	output [4:0]o_s_in                                // 帧安全保持的 S0_IN 至 S4_IN 控制向量
);

	//-------------配置参数区域-------------//
	// 原子配置总线和安全切换时刻
	localparam integer CONFIG_WIDTH = 32'd123;        // 包含模式、测试开关与十四组八位码的总位宽
	localparam [12:0] FRAME_LAST_TICK = 13'd4999;     // 每个 400 Hz 帧的最后一个 2 MHz 计数值
	localparam [12:0] CONFIG_APPLY_TICK = 13'd4759;  // 早于时序核 4760 锁存点的原子生效时刻
	localparam [12:0] RESET_FRAME_TICK = 13'd4760;   // 与 SAR9/SAR15 内部计数器对齐的复位相位

	//---------------计数信号---------------//
	// 顶层安全更新计数器与两个时序核同相连续运行
	reg [12:0]cnt_frame = RESET_FRAME_TICK;          // 只用于判断配置生效点的模 5000 计数器

	//--------------寄存器信号--------------//
	// 生效配置在完整帧期间保持不变
	reg [CONFIG_WIDTH - 1:0]reg_active_config = {CONFIG_WIDTH{1'b0}}; // 在预建立窗口前锁存的当前数字控制快照

	//---------------标志信号---------------//
	// CDC 到达事件会保留到下一个安全帧切换点
	reg flag_config_pending = 1'b0;                 // 表示尚有一笔已接收但未生效的配置
	wire flag_spi_config_busy;                      // SPI 域握手事务未收到目标应答的状态
	wire flag_destination_update;                   // 完整配置已到达 2 MHz 域的一拍通知
	wire flag_active_precision_mode;                // 低选 SAR9、高选 SAR15 的帧锁存精度位
	wire flag_active_timing_enable;                 // 允许选中时序核输出动态采样波形的使能
	wire flag_active_test_mode;                     // 在两种精度之间保持同一语义的前端测试选择
	wire flag_active_static_characterization;       // 与 EN_TEST 完全分离的静态 IDAC 表征使能
	wire flag_enable_sar9;                          // 仅在帧锁存精度为低时启动 SAR9 动态解码
	wire flag_enable_sar15;                         // 仅在帧锁存精度为高时启动 SAR15 动态解码
	wire rstn_system;                               // 经 2 MHz 时钟域同步释放的低有效复位
	wire rstn_spi;                                  // 经 SPI_SCLK 时钟域同步释放的低有效复位

	//---------------编码信号---------------//
	// 光学模式编码在顶层生效后再由两个时序核进行边界锁存
	wire [1:0]enc_active_optical_mode;               // 00 双光、01 红光、10 红外、11 安全关断

	//---------------其他信号---------------//
	// CDC 总线与帧锁存字段
	wire [CONFIG_WIDTH - 1:0]source_config;          // 由 SPI 域输入组合成的原子配置源向量
	wire [CONFIG_WIDTH - 1:0]destination_config;     // 经完整握手传入 2 MHz 域的稳定配置
	wire [4:0]active_test_mux_ctrl;                  // 作用于模拟测试开关的帧锁存选择值
	wire [7:0]active_leddac_r_code;                  // 供红光 LED 窗口使用的生效码值
	wire [7:0]active_leddac_ir_code;                 // 供红外 LED 窗口使用的生效码值
	wire [7:0]active_sar9_amb_r_code;                // SAR9 红光 AMB 窗口的帧锁存码
	wire [7:0]active_sar9_amb_ir_code;               // SAR9 红外 AMB 窗口的帧锁存码
	wire [7:0]active_sar9_dc_r_code;                 // SAR9 红光 DC 窗口的帧锁存码
	wire [7:0]active_sar9_dc_ir_code;                // SAR9 红外 DC 窗口的帧锁存码
	wire [7:0]active_sar15_amb_r_code;               // SAR15 红光 AMB 建立区间的生效码
	wire [7:0]active_sar15_amb_ir_code;              // SAR15 红外 AMB 建立区间的生效码
	wire [7:0]active_sar15_dc_r_code;                // SAR15 红光 DC 建立区间的生效码
	wire [7:0]active_sar15_dc_ir_code;               // SAR15 红外 DC 建立区间的生效码
	wire [7:0]active_static_sar9_amb_code;           // 静态测量时直接送往 SAR9 AMB 支路的码
	wire [7:0]active_static_sar9_dc_code;            // 静态测量时直接送往 SAR9 DC 支路的码
	wire [7:0]active_static_sar15_amb_code;          // 静态测量时直接送往 SAR15 AMB 支路的码
	wire [7:0]active_static_sar15_dc_code;           // 静态测量时直接送往 SAR15 DC 支路的码

	// SAR9 和 SAR15 时序核的独立波形节点
	wire sar9_frame_start;                           // SAR9 计数器每 5000 拍的本地帧起始脉冲
	wire sar15_frame_start;                          // SAR15 计数器每 5000 拍的本地帧起始脉冲
	wire sar9_en_tia;                                // SAR9 完整系统的 TIA 时序结果
	wire sar15_en_tia;                               // SAR15 完整系统的 TIA 时序结果
	wire [7:0]sar9_leddac;                           // SAR9 时序核选择后的 LED 码总线
	wire [7:0]sar15_leddac;                          // SAR15 时序核选择后的 LED 码总线
	wire sar9_leden1;                                // SAR9 红光 LED1 窗口结果
	wire sar15_leden1;                               // SAR15 红光 LED1 窗口结果
	wire sar9_leden2;                                // SAR9 红外 LED2 窗口结果
	wire sar15_leden2;                               // SAR15 红外 LED2 窗口结果
	wire sar9_clk_buf;                               // SAR9 静态表征时钟缓冲控制
	wire sar15_clk_buf;                              // SAR15 静态表征时钟缓冲控制
	wire sar9_clk_iref_idac;                         // SAR9 本地 IDAC 参考相位
	wire sar15_clk_iref_idac;                        // SAR15 本地 IDAC 参考相位
	wire sar9_clk_q1;                                // SAR9 路径的有效 Q1 相位
	wire sar15_clk_q1;                               // SAR15 路径的有效 Q1 相位
	wire sar9_clk_aferst;                            // SAR9 前端复位相位
	wire sar15_clk_aferst;                           // SAR15 前端复位相位
	wire sar9_clk_iref_sar9;                         // SAR9 参考支路的完整时序
	wire sar15_clk_iref_sar9;                        // SAR15 核静态时对 SAR9 支路的控制
	wire sar9_clk_iref_sar15;                        // SAR9 核静态时对 SAR15 支路的控制
	wire sar15_clk_iref_sar15;                       // SAR15 共享参考支路的连续时序
	wire sar9_clk_q2;                                // SAR9 保持 160 拍光学偏移的 Q2 波形
	wire sar15_clk_q2;                               // SAR15 保持 160 拍光学偏移的 Q2 波形
	wire sar9_clk_q3;                                // SAR9 以 17 us 和 97 us 为中心的 Q3 波形
	wire sar15_clk_q3;                               // SAR15 以 17 us 和 97 us 为中心的 Q3 波形
	wire sar9_clk_tiaen;                             // SAR9 前端本地使能时序
	wire sar15_clk_tiaen;                            // SAR15 前端本地使能时序
	wire sar9_en_amb;                                // SAR9 AMB 分支的动态或静态使能
	wire sar15_en_amb;                               // SAR15 AMB 分支的动态或静态使能
	wire sar9_en_dc;                                 // SAR9 DC 分支的动态或静态使能
	wire sar15_en_dc;                                // SAR15 DC 分支的动态或静态使能
	wire sar9_en_iref;                               // SAR9 参考电流支路使能
	wire sar15_en_iref;                              // SAR15 参考电流支路使能
	wire sar9_en_sar15_amb;                          // SAR9 核静态表征时的 SAR15 AMB 分支使能
	wire sar9_en_sar15_dc;                           // SAR9 核静态表征时的 SAR15 DC 分支使能
	wire sar9_en_sar15_iref;                         // SAR9 核为 SAR15 参考分支提供的静态控制
	wire sar15_en_sar9_amb;                          // SAR15 核静态表征时的 SAR9 AMB 分支使能
	wire sar15_en_sar9_dc;                           // SAR15 核静态表征时的 SAR9 DC 分支使能
	wire sar15_en_sar9_iref;                         // SAR15 核为 SAR9 参考分支提供的静态控制
	wire [7:0]sar9_idac_amb_code;                    // SAR9 核输出的 AMB 抵消码
	wire [7:0]sar15_idac_amb_code;                   // SAR15 核输出的 AMB 抵消码
	wire [7:0]sar9_idac_dc_code;                     // SAR9 核输出的 DC 抵消码
	wire [7:0]sar15_idac_dc_code;                    // SAR15 核输出的 DC 抵消码
	wire [7:0]sar9_static_sar15_amb_code;            // SAR9 核静态表征时的 SAR15 AMB 码
	wire [7:0]sar15_static_sar9_amb_code;            // SAR15 核静态表征时的 SAR9 AMB 码
	wire [7:0]sar9_static_sar15_dc_code;             // SAR9 核静态表征时的 SAR15 DC 码
	wire [7:0]sar15_static_sar9_dc_code;             // SAR15 核静态表征时的 SAR9 DC 码

	//---------------输出信号---------------//
	// 配置生效指示仅在安全切换点保持一拍
	reg config_applied_o = 1'b0;                    // 上层调试逻辑用于确认原子生效的事件输出

	//-------------其他信号连线-------------//
	// SPI 配置按固定字段顺序组成单一握手载荷
	assign source_config = {i_spi_static_sar15_dc_code, i_spi_static_sar15_amb_code, i_spi_static_sar9_dc_code, i_spi_static_sar9_amb_code, i_spi_idac_sar15_dc_ir_code, i_spi_idac_sar15_dc_r_code, i_spi_idac_sar15_amb_ir_code, i_spi_idac_sar15_amb_r_code, i_spi_idac_sar9_dc_ir_code, i_spi_idac_sar9_dc_r_code, i_spi_idac_sar9_amb_ir_code, i_spi_idac_sar9_amb_r_code, i_spi_leddac_ir_code, i_spi_leddac_r_code, i_spi_test_mux_ctrl, i_spi_static_characterization_enable, i_spi_optical_mode, i_spi_test_mode, i_spi_timing_enable, i_spi_precision_mode}; // 原子捕获所有会影响模拟控制的寄存器字段

	// 从帧锁存快照还原双精度时序核需要的独立配置字段
	assign {active_static_sar15_dc_code, active_static_sar15_amb_code, active_static_sar9_dc_code, active_static_sar9_amb_code, active_sar15_dc_ir_code, active_sar15_dc_r_code, active_sar15_amb_ir_code, active_sar15_amb_r_code, active_sar9_dc_ir_code, active_sar9_dc_r_code, active_sar9_amb_ir_code, active_sar9_amb_r_code, active_leddac_ir_code, active_leddac_r_code, active_test_mux_ctrl, flag_active_static_characterization, enc_active_optical_mode, flag_active_test_mode, flag_active_timing_enable, flag_active_precision_mode} = reg_active_config; // 保证精度、光学模式、码值和测试选择在同一帧生效
	assign flag_enable_sar9 = flag_active_timing_enable && (flag_active_precision_mode == 1'b0); // 低精度帧仅允许 SAR9 核输出动态波形
	assign flag_enable_sar15 = flag_active_timing_enable && (flag_active_precision_mode == 1'b1); // 高精度帧仅允许 SAR15 核输出动态波形

	//-------------输出信号连线-------------//
	// 配置与帧模式状态输出
	assign o_spi_config_busy = flag_spi_config_busy; // 将 CDC 源域占用状态返回 SPI 寄存器组
	assign o_active_precision_mode = flag_active_precision_mode; // 输出已在安全点锁存而非实时 SPI 请求的精度
	assign o_config_applied = config_applied_o;       // 输出新快照刚刚替换帧配置的指示脉冲

	// 选中核的波形仅在帧前安全精度位上发生切换
	assign o_frame_start_400hz = flag_active_precision_mode ? sar15_frame_start : sar9_frame_start; // 从当前完整 5000 拍时序系统输出帧边界
	assign o_en_tia_low = flag_active_precision_mode ? sar15_en_tia : sar9_en_tia; // 保持 TIA 控制与当前精度时序表一致
	assign o_leddac = flag_active_precision_mode ? sar15_leddac : sar9_leddac; // 选择对应精度核已锁存的光源驱动码
	assign o_leden1_low = flag_active_precision_mode ? sar15_leden1 : sar9_leden1; // 输出红光 LED1 在选中时序中的活动窗口
	assign o_leden2_low = flag_active_precision_mode ? sar15_leden2 : sar9_leden2; // 输出红外 LED2 的 160 拍后移活动窗口
	assign o_en_test = flag_active_test_mode;         // 前端测试路径不与静态表征或精度位相与
	assign o_clk_buf_low = flag_active_precision_mode ? sar15_clk_buf : sar9_clk_buf; // 使用选中表征模式的时钟缓冲控制
	assign o_clk_2m = i_clk;                         // 仅做同相逻辑连接，物理实现由时钟缓冲和电平转换单元承担
	assign o_clk_iref_idac_low = flag_active_precision_mode ? sar15_clk_iref_idac : sar9_clk_iref_idac; // 选择对应精度时序表的本地 IDAC 参考脉冲
	assign o_clk_9q1_low = flag_active_precision_mode ? 1'b0 : sar9_clk_q1; // 在 SAR15 帧强制关闭粗精度 Q1 分支
	assign o_clk_15q1_low = flag_active_precision_mode ? sar15_clk_q1 : 1'b0; // 在 SAR9 帧禁止精细路径 Q1 切换
	assign o_clk_aferst_low = flag_active_precision_mode ? sar15_clk_aferst : sar9_clk_aferst; // 输出当前完整时序系统的前端复位相位
	assign o_clk_iref_idac_sar9_low = flag_active_precision_mode ? sar15_clk_iref_sar9 : sar9_clk_iref_sar9; // 选择动态 SAR9 或静态表征时的参考控制
	assign o_clk_iref_idac_sar15_low = flag_active_precision_mode ? sar15_clk_iref_sar15 : sar9_clk_iref_sar15; // 选择动态 SAR15 或静态表征时的参考控制
	assign o_clk_q2_low = flag_active_precision_mode ? sar15_clk_q2 : sar9_clk_q2; // 切换精度时仍保留各核内部 80 us R/IR 合同
	assign o_clk_q3_low = flag_active_precision_mode ? sar15_clk_q3 : sar9_clk_q3; // 两个核的红光与红外 Q3 中心保持公共时刻
	assign o_clk_tiaen_low = flag_active_precision_mode ? sar15_clk_tiaen : sar9_clk_tiaen; // 输出选中精度的局部 TIA 使能节拍

	// 精度选择由帧锁存位直接驱动，不允许静态表征改写其语义
	assign o_en_15sar_low = flag_active_precision_mode; // 低电平硬选 SAR9，高电平硬选 SAR15
	assign o_en_sar9_amb_low = flag_active_precision_mode ? sar15_en_sar9_amb : sar9_en_amb; // 输出 SAR9 AMB 分支的动态或静态使能
	assign o_en_sar9_dc_low = flag_active_precision_mode ? sar15_en_sar9_dc : sar9_en_dc; // 输出 SAR9 DC 分支在当前完整时序系统中的状态
	assign o_en_sar9_iref = flag_active_precision_mode ? sar15_en_sar9_iref : sar9_en_iref; // 保留静态表征与动态 SAR9 参考使能的独立语义
	assign o_en_sar15_amb_low = flag_active_precision_mode ? sar15_en_amb : sar9_en_sar15_amb; // 输出 SAR15 AMB 动态分支或静态表征路径
	assign o_en_sar15_dc_low = flag_active_precision_mode ? sar15_en_dc : sar9_en_sar15_dc; // 输出 SAR15 DC 在选中精度下的保持使能
	assign o_en_sar15_iref = flag_active_precision_mode ? sar15_en_iref : sar9_en_sar15_iref; // 传递选中时序核对 SAR15 共享参考分支的控制
	assign o_idac_sar9ambn_low = flag_active_precision_mode ? sar15_static_sar9_amb_code : sar9_idac_amb_code; // 精度切换后保留 SAR9 动态或表征 AMB 码语义
	assign o_idac_sar9dcn_low = flag_active_precision_mode ? sar15_static_sar9_dc_code : sar9_idac_dc_code; // 将 SAR9 DC 码从当前完整时序系统送往模拟边界
	assign o_idac_sar15ambn_low = flag_active_precision_mode ? sar15_idac_amb_code : sar9_static_sar15_amb_code; // 将 SAR15 AMB 动态码或静态表征码输出
	assign o_idac_sar15dcn_low = flag_active_precision_mode ? sar15_idac_dc_code : sar9_static_sar15_dc_code; // 输出 SAR15 DC 分支的帧保持数字码
	assign o_s_in = active_test_mux_ctrl ^ 5'b00001;             // 测试开关只由原子帧配置控制而不依赖精度核输出

	//-----------输出信号处理区域-----------//
	// 新配置实际替换帧快照时产生单拍确认
	always@(posedge i_clk or negedge rstn_system)begin
		if(rstn_system == 1'b0)begin
			config_applied_o <= 1'b0;                 // 系统域复位期间禁止报告配置生效
		end else if((cnt_frame == CONFIG_APPLY_TICK) && (flag_config_pending == 1'b1))begin
			config_applied_o <= 1'b1;                 // 在 4760 内核锁存点前一拍标记原子更新
		end else begin
			config_applied_o <= 1'b0;                 // 非生效时刻始终保持事件输出为低
		end
	end

	//-----------主要任务处理区域-----------//
	// 独立计数器不受精度、表征或测试模式改变
	always@(posedge i_clk or negedge rstn_system)begin
		if(rstn_system == 1'b0)begin
			cnt_frame <= RESET_FRAME_TICK;            // 将顶层生效相位与两个时序核同步对齐
		end else if(cnt_frame == FRAME_LAST_TICK)begin
			cnt_frame <= 13'd0;                       // 精确完成 5000 个 2 MHz 周期后回到帧原点
		end else begin
			cnt_frame <= cnt_frame + 13'd1;           // 每个外部主时钟边沿推进一个帧时隙
		end
	end

	// 目标域配置到达后保留待处理状态，同拍新事务优先于旧事务清除
	always@(posedge i_clk or negedge rstn_system)begin
		if(rstn_system == 1'b0)begin
			flag_config_pending <= 1'b0;              // 复位后不将全零 CDC 初值视为待生效事务
		end else if(flag_destination_update == 1'b1)begin
			flag_config_pending <= 1'b1;              // 记录最近一笔已握手完成的 SPI 配置
		end else if((cnt_frame == CONFIG_APPLY_TICK) && (flag_config_pending == 1'b1))begin
			flag_config_pending <= 1'b0;              // 快照在安全点被采用后清除待处理标志
		end else begin
			flag_config_pending <= flag_config_pending; // 在跨帧等待期间不丢失已接收配置
		end
	end

	// 整条配置总线只在早于所有内核建立动作的固定时刻替换
	always@(posedge i_clk or negedge rstn_system)begin
		if(rstn_system == 1'b0)begin
			reg_active_config <= {CONFIG_WIDTH{1'b0}}; // 将复位安全态设为禁用时序、SAR9 选择和测试关闭
		end else if((cnt_frame == CONFIG_APPLY_TICK) && (flag_config_pending == 1'b1))begin
			reg_active_config <= destination_config;  // 以一次非阻塞赋值原子更新全部模拟控制字段
		end else begin
			reg_active_config <= reg_active_config;    // 从预建立开始直到下一帧更新之前保持配置稳定
		end
	end

	//------------模块实例化区域------------//
	// 为 2 MHz 数字主域产生异步置低、同步释放复位
	ppg_reset_sync ppg_reset_sync_Inst_system(
		.i_clk(i_clk),                                // 使用外部 2 MHz 时钟作为系统域释放基准
		.i_async_rstn(i_rstn),                       // 接收全局低有效异步复位输入
		.o_rstn(rstn_system)                         // 向帧计数和两个时序核提供同步释放复位
	);

	// 为 SPI_SCLK 配置源域独立生成同步释放复位
	ppg_reset_sync ppg_reset_sync_Inst_spi(
		.i_clk(i_spi_sclk),                           // 使用 SPI 串行时钟推进源域复位链
		.i_async_rstn(i_rstn),                       // 复用全局异步拉低复位源
		.o_rstn(rstn_spi)                            // 向配置快照和请求逻辑提供源域复位
	);

	// 用稳定数据和翻转握手跨域传送完整配置
	ppg_config_cdc_bridge
	#(
		.C_CONFIG_WIDTH(CONFIG_WIDTH)                // 将 123 位 PPG 配置视为不可分割的事务载荷
	)ppg_config_cdc_bridge_Inst_control(
		.i_source_clk(i_spi_sclk),                   // 在外部 SPI_SCLK 边沿锁存寄存器快照
		.i_source_rstn(rstn_spi),                    // 使用 SPI 域同步释放复位保护源端逻辑
		.i_source_config(source_config),             // 传入按固定顺序打包的模式与码值总线
		.i_source_update(i_spi_config_commit),       // 仅在 SPI 寄存器组完成写事务后发起提交
		.o_source_busy(flag_spi_config_busy),        // 将快照占用状态返回串行接口控制逻辑
		.i_destination_clk(i_clk),                   // 使用 2 MHz 主时钟捕获已稳定配置总线
		.i_destination_rstn(rstn_system),            // 使用系统域同步释放复位清除目标逻辑
		.o_destination_config(destination_config),   // 向帧安全更新逻辑提供原子跨域快照
		.o_destination_update(flag_destination_update) // 通知顶层已有新配置等待安全生效
	);

	// SAR9 核持续运行自身的 5000 拍计数器，仅动态解码受帧精度使能控制
	ppg_timing_sar9 ppg_timing_sar9_Inst_complete(
		.i_clk(i_clk),                               // 与 SAR15 共用外部 2 MHz 时钟边沿
		.i_rstn(rstn_system),                        // 与顶层计数器同步释放以保持相位一致
		.i_enable(flag_enable_sar9),                 // 仅低精度帧开放 SAR9 动态输出
		.i_test_mode(flag_active_test_mode),         // 传入与静态表征独立的前端测试选择
		.i_optical_mode(enc_active_optical_mode),    // 将帧锁存的红光、红外或双光模式传给 SAR9
		.i_static_characterization_enable(flag_active_static_characterization), // 独立请求 SAR9 核输出静态表征组合
		.i_test_mux_ctrl(active_test_mux_ctrl),      // 传递五位模拟测试开关快照
		.i_static_sar9_amb_code(active_static_sar9_amb_code), // 设置 SAR9 AMB 静态表征电流码
		.i_static_sar9_dc_code(active_static_sar9_dc_code), // 设置 SAR9 DC 静态表征电流码
		.i_static_sar15_amb_code(active_static_sar15_amb_code), // 为低精度表征组合提供 SAR15 AMB 码
		.i_static_sar15_dc_code(active_static_sar15_dc_code), // 为低精度表征组合提供 SAR15 DC 码
		.i_leddac_r_code(active_leddac_r_code),      // 向 SAR9 红光窗口提供已生效 LED 码
		.i_leddac_ir_code(active_leddac_ir_code),    // 向 SAR9 红外窗口提供已生效 LED 码
		.i_idac_sar9_amb_r_code(active_sar9_amb_r_code), // 连接 SAR9 红光 AMB 帧保持字段
		.i_idac_sar9_amb_ir_code(active_sar9_amb_ir_code), // 连接 SAR9 红外 AMB 帧保持字段
		.i_idac_sar9_dc_r_code(active_sar9_dc_r_code), // 连接 SAR9 红光 DC 时序码字段
		.i_idac_sar9_dc_ir_code(active_sar9_dc_ir_code), // 连接 SAR9 红外 DC 时序码字段
		.o_frame_start_400hz(sar9_frame_start),      // 捕获 SAR9 自有计数器的 400 Hz 帧脉冲
		.o_en_tia_low(sar9_en_tia),                 // 接收 SAR9 对齐后的 TIA 使能窗口
		.o_leddac(sar9_leddac),                     // 接收 SAR9 核选择的当前光源电流码
		.o_leden1_low(sar9_leden1),                 // 接收 SAR9 红光 LED1 时间窗口
		.o_leden2_low(sar9_leden2),                 // 接收 SAR9 红外 LED2 延迟时间窗口
		.o_en_test(),                               // 顶层使用帧配置直接生成独立 EN_TEST
		.o_clk_buf_low(sar9_clk_buf),               // 捕获 SAR9 静态表征的时钟缓冲状态
		.o_clk_2m(),                                 // 顶层直接输出公共 2 MHz 时钟逻辑端
		.o_clk_iref_idac_low(sar9_clk_iref_idac),   // 捕获 SAR9 本地 IDAC 参考时序
		.o_clk_9q1_low(sar9_clk_q1),                // 连接 SAR9 实际活动的 Q1 相位
		.o_clk_15q1_low(),                           // 未选用 SAR9 核内部固定关闭的 15Q1 端
		.o_clk_aferst_low(sar9_clk_aferst),         // 接收 SAR9 前端复位释放波形
		.o_clk_iref_idac_sar9_low(sar9_clk_iref_sar9), // 接收 SAR9 参考支路的跨帧时序
		.o_clk_iref_idac_sar15_low(sar9_clk_iref_sar15), // 接收低精度静态组合中的 SAR15 参考控制
		.o_clk_q2_low(sar9_clk_q2),                 // 连接 SAR9 红光与红外相差 80 us 的 Q2
		.o_clk_q3_low(sar9_clk_q3),                 // 连接与 SAR15 共享采样中心的 SAR9 Q3
		.o_clk_tiaen_low(sar9_clk_tiaen),           // 捕获 SAR9 前端本地使能时序
		.o_en_15sar_low(),                           // 顶层使用帧锁存精度位统一驱动选择信号
		.o_en_sar9_amb_low(sar9_en_amb),            // 连接 SAR9 AMB 动态使能或表征状态
		.o_en_sar9_dc_low(sar9_en_dc),              // 连接 SAR9 DC 抵消支路使能
		.o_en_sar9_iref(sar9_en_iref),              // 连接 SAR9 参考电流分支使能
		.o_en_sar15_amb_low(sar9_en_sar15_amb),     // 保留 SAR9 核静态表征的 SAR15 AMB 使能输出
		.o_en_sar15_dc_low(sar9_en_sar15_dc),       // 保留 SAR9 核静态表征的 SAR15 DC 使能输出
		.o_en_sar15_iref(sar9_en_sar15_iref),       // 捕获 SAR9 核对 SAR15 IREF 分支的明确关断状态
		.o_idac_sar9ambn_low(sar9_idac_amb_code),   // 接收 SAR9 当前光学阶段的 AMB 码
		.o_idac_sar9dcn_low(sar9_idac_dc_code),     // 接收 SAR9 当前光学阶段的 DC 码
		.o_idac_sar15ambn_low(sar9_static_sar15_amb_code), // 保留 SAR9 静态表征中的 SAR15 AMB 码通路
		.o_idac_sar15dcn_low(sar9_static_sar15_dc_code), // 保留 SAR9 静态表征中的 SAR15 DC 码通路
		.o_s_in()                                    // 测试开关由顶层生效快照直接输出
	);

	// SAR15 核与 SAR9 核并行运行自身的 5000 拍计数器并保持公共 Q3 中心
	ppg_timing_sar15 ppg_timing_sar15_Inst_complete(
		.i_clk(i_clk),                               // 与 SAR9 共用同一外部 2 MHz 主时钟
		.i_rstn(rstn_system),                        // 使用系统域同步释放复位保持计数对齐
		.i_enable(flag_enable_sar15),                // 仅高精度帧开放 SAR15 动态输出
		.i_test_mode(flag_active_test_mode),         // 传入不受精度选择影响的前端测试模式
		.i_optical_mode(enc_active_optical_mode),    // 将同一帧锁存光学模式传给 SAR15 时序表
		.i_static_characterization_enable(flag_active_static_characterization), // 独立启用 SAR15 核的静态 IDAC 表征输出
		.i_test_mux_ctrl(active_test_mux_ctrl),      // 传递与低精度核相同的模拟测试开关快照
		.i_static_sar9_amb_code(active_static_sar9_amb_code), // 为高精度表征组合提供 SAR9 AMB 码
		.i_static_sar9_dc_code(active_static_sar9_dc_code), // 为高精度表征组合提供 SAR9 DC 码
		.i_static_sar15_amb_code(active_static_sar15_amb_code), // 设置 SAR15 AMB 静态表征电流码
		.i_static_sar15_dc_code(active_static_sar15_dc_code), // 设置 SAR15 DC 静态表征电流码
		.i_leddac_r_code(active_leddac_r_code),      // 向 SAR15 红光阶段提供原子生效 LED 码
		.i_leddac_ir_code(active_leddac_ir_code),    // 向 SAR15 红外阶段提供原子生效 LED 码
		.i_idac_sar15_amb_r_code(active_sar15_amb_r_code), // 连接 SAR15 红光 AMB 长建立窗口码
		.i_idac_sar15_amb_ir_code(active_sar15_amb_ir_code), // 连接 SAR15 红外 AMB 延迟窗口码
		.i_idac_sar15_dc_r_code(active_sar15_dc_r_code), // 连接 SAR15 红光 DC 跨帧建立码
		.i_idac_sar15_dc_ir_code(active_sar15_dc_ir_code), // 连接 SAR15 红外 DC 帧内保持码
		.o_frame_start_400hz(sar15_frame_start),     // 捕获 SAR15 自有计数器的 400 Hz 帧脉冲
		.o_en_tia_low(sar15_en_tia),                // 接收 SAR15 两个光学阶段的 TIA 使能窗口
		.o_leddac(sar15_leddac),                    // 接收 SAR15 核当前选中的 LED 驱动码
		.o_leden1_low(sar15_leden1),                // 接收 SAR15 红光 LED1 完整激活窗口
		.o_leden2_low(sar15_leden2),                // 接收 SAR15 红外 LED2 后移激活窗口
		.o_en_test(),                               // 顶层独立输出帧锁存 EN_TEST 而不选择核内副本
		.o_clk_buf_low(sar15_clk_buf),              // 捕获 SAR15 静态表征的时钟缓冲状态
		.o_clk_2m(),                                 // 公共模拟 2 MHz 端由顶层不经多路选择输出
		.o_clk_iref_idac_low(sar15_clk_iref_idac),  // 捕获 SAR15 本地 IDAC 参考时序结果
		.o_clk_9q1_low(),                            // 未选用 SAR15 核内部固定关闭的 9Q1 端
		.o_clk_15q1_low(sar15_clk_q1),              // 连接 SAR15 精细路径实际 Q1 波形
		.o_clk_aferst_low(sar15_clk_aferst),        // 接收 SAR15 前端复位释放时间窗口
		.o_clk_iref_idac_sar9_low(sar15_clk_iref_sar9), // 接收高精度静态组合中的 SAR9 参考控制
		.o_clk_iref_idac_sar15_low(sar15_clk_iref_sar15), // 接收 SAR15 跨 R/IR 连续并集参考时序
		.o_clk_q2_low(sar15_clk_q2),                // 连接两段对应边沿严格相差 160 拍的 Q2
		.o_clk_q3_low(sar15_clk_q3),                // 连接与 SAR9 采样中心一致的 SAR15 Q3
		.o_clk_tiaen_low(sar15_clk_tiaen),          // 捕获 SAR15 前端本地 TIA 使能节拍
		.o_en_15sar_low(),                           // 内核选择副本不跨越顶层帧安全选择边界
		.o_en_sar9_amb_low(sar15_en_sar9_amb),      // 保留 SAR15 核静态表征的 SAR9 AMB 使能输出
		.o_en_sar9_dc_low(sar15_en_sar9_dc),        // 保留 SAR15 核静态表征的 SAR9 DC 使能输出
		.o_en_sar9_iref(sar15_en_sar9_iref),        // 捕获 SAR15 核对 SAR9 IREF 分支的确定关断状态
		.o_en_sar15_amb_low(sar15_en_amb),          // 连接 SAR15 AMB 跨光学阶段保持使能
		.o_en_sar15_dc_low(sar15_en_dc),            // 连接 SAR15 DC 跨红光与红外连续使能
		.o_en_sar15_iref(sar15_en_iref),            // 连接 SAR15 共享参考电流建立使能
		.o_idac_sar9ambn_low(sar15_static_sar9_amb_code), // 保留 SAR15 静态表征中的 SAR9 AMB 码通路
		.o_idac_sar9dcn_low(sar15_static_sar9_dc_code), // 保留 SAR15 静态表征中的 SAR9 DC 码通路
		.o_idac_sar15ambn_low(sar15_idac_amb_code), // 接收 SAR15 当前光学阶段的 AMB 码
		.o_idac_sar15dcn_low(sar15_idac_dc_code),   // 接收 SAR15 当前光学阶段的 DC 码
		.o_s_in()                                    // 测试开关使用顶层帧快照直接驱动
	);

endmodule
