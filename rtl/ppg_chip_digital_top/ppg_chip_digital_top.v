`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/09/06
// Design Name:     PPG Chip Digital Top (SPI/P2S Glue Top)
// Module Name:     ppg_chip_digital_top
// Description:     Description/ppg_chip_digital_top_Design.pdf
// Simulations:     tb_ppg_chip_digital_top
//
// Referrences:     PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md
//
// Dependencies:    ppg_reset_sync, ppg_spi_register_file, ppg_p2s_packer, ppg_control_top
//
// Version:         V1.2
// Revision Date:   2026/09/07
// History:
//     Time          Version     Revised by     Contents
// 2026/09/07        V1.2        Erie          Fix a real CDC gap flagged by the user against contract section 8.3 (line 153, frozen at V1.5) and section 9 rule 6 (line 230): dec_dbg_out_mux's selection used spi_dbg_out_select_o directly -- a SPI_SCLK-domain register (ppg_spi_register_file's reg_dbg_out_select) sampled with zero synchronizer stages by this file's CLK_2M-domain combinational mux, exactly the "temporary direct combinational or single-flop crossing" the contract forbids for this signal. Companion fix in ppg_spi_register_file.v V1.2 adds a sixth ppg_pulse_cdc_sync instance producing a new single-cycle CLK_2M-domain event (o_dbg_out_select_update_event) each time 0x0081 is genuinely written. This file adds a new CLK_2M-domain register, reg_dbg_out_select_stable, that only samples spi_dbg_out_select_o when that event pulses (reset to 3'd0, matching the SPI regfile's own reset value); dec_dbg_out_mux now selects off reg_dbg_out_select_stable instead of the raw SPI-domain wire. No metastability risk on the sampled value: by construction it has already been stable in the source domain for several source-domain cycles by the time the crossing event arrives, same reasoning already used for the other 5 pulse crossings. New wire spi_dbg_out_select_update_event_o added; no port list change on this module itself (ppg_spi_register_file's port list gained the one new output, wired here). Gate-clean, still only the 46 documented VG010 pad-naming exceptions. Full-hierarchy regression: tb_ppg_chip_digital_top.v 6/6 PASS, ppg_control_top.v's own SMOKE_TB_PASS unchanged (real_adc_responses=47 measurement_result_valid=32).
// 2026/09/07        V1.1        Erie          Fix a real reset-CDC race found by tb_ppg_chip_digital_top.v's TC1: the SPI-domain reset synchronizer was clocked by SPI_SCLK itself, which stays idle-low until the host's very first real SPI transaction, so that transaction's own opening clock edges were simultaneously the ones needed to release the synchronizer -- corrupting the first 1-2 bits of the first-ever transaction after power-up (a genuine silicon-level bug, not a testbench artifact). Fixed by dropping the SPI_SCLK-clocked ppg_reset_sync instance and driving w_source_rstn directly from w_rstn (already synchronized in the always-running CLK_2M_PAD domain and long-settled before any real SPI activity begins, so feeding it in asynchronously carries no metastability risk). No port list change.
// 2026/09/06        V1.0        Erie          Create file. First RTL implementation of PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md (V1.10): the QFN48 package-facing glue layer between the pad ring and ppg_control_top, per contract section 3's frozen hierarchy. Instantiates two ppg_reset_sync (CLK_2M_PAD domain and SPI_SCLK domain), one ppg_spi_register_file (Mode 0 SPI slave register file, byte-level map confirmed with the user across three rounds: write 0x0000-0x007F ACTIVE shadow / 0x0080 characterization / 0x0081 DBG_OUT select / 0x0090 shared command byte, read 0x0100-0x0125 captured diagnostic snapshot plus two independent discard-event latches), one ppg_p2s_packer (161-bit fixed telemetry packet), and one ppg_control_top (C01 target RTL, unmodified except the already-frozen o_active_precision_mode/o_source_config_update_ready/o_s1_calibration_applied/o_s1_raw/o_s2_raw ports). Inline logic covers: the flag_adc_physical_idle synthesizer (mux Stage1/Stage2 DONE by o_active_precision_mode, single 2-stage synchronizer, per C01 V1.11's frozen formula), the 6-candidate DBG_OUT mux (section 8.3), i_analog_ready tied to a fixed 1'b1 per the V1.10 errata (board power-up sequencing guarantees analog is stable before the digital domain starts -- not structurally analogous to i_adc_physical_idle, no synchronizer needed), the 7 verification-injection inputs tied to their production-safe defaults (C_ENABLE_TEST_INJECTION=0, matching the confirmed decision to exclude injection from the SPI map entirely), and the 32-signal SSW plus 4-signal ADC-interface pure rename passthrough (section 5, 36 signals total per the V1.8 errata correction). P2S_CLK is a pure CLK_2M_PAD passthrough per section 8.4.1, not generated inside ppg_p2s_packer. Known, deliberate gate exception: the 46 package/analog-facing ports (all `input`/`output` declarations above, none of the internal signals) do not carry `i_`/`o_` prefixes and so trip the erie_strict VG010 check on every one of them -- this is required, not an oversight: the contract mandates these boundary names match `ppg_digital_esd_shell.v`'s physical pin names exactly (QFN48 pad names cannot carry an internal-signal-style prefix). No other finding remains in this file; VG010 is the only category left unresolved, and resolving it by renaming would violate the contract.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年09月06日
// 设计名称:        PPG芯片级数字顶层（SPI/P2S glue顶层）
// 模块名称:        ppg_chip_digital_top
// 模块说明:        Description/ppg_chip_digital_top_Design.pdf
// 仿真工程:        tb_ppg_chip_digital_top
//
// 参考资料:        PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md
//
// 依赖文件:        ppg_reset_sync、ppg_spi_register_file、ppg_p2s_packer、ppg_control_top
//
// 当前版本:        V1.2
// 修订日期:        2026年09月07日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年09月07日   V1.2        Erie          修复用户对照合同第8.3节（第153行，V1.5冻结）与第9节第6条（第230行）指出的一个真实CDC缺口：dec_dbg_out_mux的选择依据原先直接用spi_dbg_out_select_o——SPI_SCLK域寄存器（ppg_spi_register_file的reg_dbg_out_select）被本文件CLK_2M域组合mux零同步级直接采样，正是合同禁止的"临时直接组合逻辑或单级触发器跨域"。配套修复ppg_spi_register_file.v V1.2新增第六个ppg_pulse_cdc_sync实例，每次真实写入0x0081时产生一个新的单周期CLK_2M域事件（o_dbg_out_select_update_event）。本文件新增CLK_2M域寄存器reg_dbg_out_select_stable，只在该事件到达时才采样spi_dbg_out_select_o（复位值3'd0，与SPI寄存器文件自身复位值一致）；dec_dbg_out_mux改为按reg_dbg_out_select_stable选择，不再用原始SPI域wire。采样值不存在亚稳态风险：按构造，跨域事件抵达时该值在源域早已稳定多个源域时钟周期，与其余5路脉冲跨域同一道理。新增wire spi_dbg_out_select_update_event_o；本模块自身端口列表无变化（ppg_spi_register_file新增的1个输出端口在此接线）。gate仍只有46个已文档化的VG010封装引脚命名例外，无新发现。全链路回归：tb_ppg_chip_digital_top.v 6/6 PASS，ppg_control_top.v自身SMOKE_TB_PASS不变（real_adc_responses=47 measurement_result_valid=32）。
// 2026年09月07日   V1.1        Erie          修复tb_ppg_chip_digital_top.v TC1发现的一个真实复位CDC竞争：源域复位同步器原先由SPI_SCLK自身驱动，而SPI_SCLK在主机发起第一笔真实SPI事务前始终空闲拉低，导致该事务自己最开头的时钟沿同时被用来推动同步链释放，使上电后第一笔事务的头1~2个比特被错误复位覆盖（这是真实芯片级缺陷，不是仅存在于测试平台的假象）。修复方式：去掉由SPI_SCLK驱动的ppg_reset_sync实例，改为w_source_rstn直接借用w_rstn（已在始终运行的CLK_2M_PAD域完成同步，且在任何真实SPI活动开始前早已稳定，异步喂入不存在亚稳态风险）。端口列表无变化。
// 2026年09月06日   V1.0        Erie          创建文件。PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md（V1.10）首次RTL实现：QFN48封装Pad Ring与ppg_control_top之间的glue层，按合同第3节冻结的例化层次搭建。例化两个ppg_reset_sync（CLK_2M_PAD域与SPI_SCLK域各一）、一个ppg_spi_register_file（Mode 0 SPI从机寄存器文件，字节级地图与用户三轮核对确认：写方向0x0000-0x007F ACTIVE影子区/0x0080表征控制/0x0081 DBG_OUT选择/0x0090共享命令字节，读方向0x0100-0x0125整体捕获快照加两组独立discard事件锁存）、一个ppg_p2s_packer（161-bit固定遥测包）、一个ppg_control_top（C01目标RTL，除已冻结的o_active_precision_mode/o_source_config_update_ready/o_s1_calibration_applied/o_s1_raw/o_s2_raw外未做任何改动）。内联逻辑覆盖：flag_adc_physical_idle合成器（按o_active_precision_mode在Stage1/Stage2 DONE间二选一，单个两级同步器，遵循C01 V1.11冻结公式）、DBG_OUT六选一多路选择器（合同第8.3节）、i_analog_ready按V1.10勘误固定接1'b1（板级上电时序保证数字域启动时模拟侧已经稳定，与i_adc_physical_idle结构上并不同构，不需要同步器）、7个验证注入输入接生产安全默认值（C_ENABLE_TEST_INJECTION=0，与验证注入整体排除出SPI地图的已确认决定一致）、32路SSW加4路ADC接口的纯改名直连（第5节，V1.8勘误修正后共36个信号）。P2S_CLK按第8.4.1节直接用CLK_2M_PAD纯直连，不在ppg_p2s_packer内部产生。已知且刻意保留的gate例外：46个封装/模拟侧边界端口（仅module端口声明本身，不含任何内部信号）都不带i_/o_前缀，因而每一个都会命中erie_strict的VG010检查——这是合同硬性要求，不是遗漏：这些边界名称必须与ppg_digital_esd_shell.v的物理引脚名逐字一致（QFN48引脚名本身不可能带内部信号风格前缀）。本文件除VG010外无其余任何发现；如果为了消掉VG010而改名，反而会违反合同。

// glue顶层：SPI寄存器文件、P2S打包器与ppg_control_top的封装级集成
module ppg_chip_digital_top
(
	//---------------封装级数字信号---------------//
	input CLK_2M_PAD,                             // QFN pin 47，2 MHz数字系统域源时钟
	input RESET_N,                                // QFN pin 38，全局异步低有效复位
	input SPI_CS_N,                               // QFN pin 39，SPI片选，低有效
	input SPI_SCLK,                               // QFN pin 40，SPI配置源时钟
	input SPI_SDI,                                // QFN pin 41，SPI主到从串行数据
	output SPI_SDO,                               // QFN pin 42，SPI从到主串行数据
	output P2S_CLK,                               // QFN pin 43，P2S移位时钟，CLK_2M_PAD纯直连
	output P2S_DATA,                              // QFN pin 44，P2S串行遥测数据
	output P2S_FRAME,                             // QFN pin 45，P2S包边界指示
	output DBG_OUT,                               // QFN pin 46，六选一调试观测输出

	//---------------两级异步ADC物理接口---------------//
	input [9:0] DOUT_STAGE1_LOW,                       // Stage1判决码
	input CLK_STAGE1_DOUT_LOW,                         // Stage1完成位
	input [9:0] DOUT_STAGE2_LOW,                       // Stage2判决码
	input CLK_STAGE2_DOUT_LOW,                         // Stage2完成位

	//---------------SSW模拟控制原样直连输出---------------//
	output EN_TIA_LOW,                                     // 跨阻放大使能，低有效
	output [7:0] LEDDAC,                                   // LED驱动数模码
	output LEDEN1_LOW,                                     // 红光LED选择，低有效
	output LEDEN2_LOW,                                     // 红外LED选择，低有效
	output EN_TEST,                                        // 模拟测试模式使能
	output CLK_BUF_LOW,                                    // 时钟缓冲，低有效
	output CLK_2M,                                         // 2 MHz模拟侧参考时钟
	output CLK_IREF_IDAC_LOW,                              // 参考电流IDAC时钟，低有效
	output CLK_9Q1_LOW,                                    // 九位第一相位时钟，低有效
	output CLK_15Q1_LOW,                                   // 十五位第一相位时钟，低有效
	output CLK_AFERST_LOW,                                 // 前端复位时钟，低有效
	output CLK_IREF_IDAC_SAR9_LOW,                         // 九位转换参考电流IDAC时钟，低有效
	output CLK_IREF_IDAC_SAR15_LOW,                        // 十五位转换参考电流IDAC时钟，低有效
	output CLK_Q2_LOW,                                     // 第二相位时钟，低有效
	output CLK_Q3_LOW,                                     // 第三相位采样中心时钟，低有效
	output CLK_TIAEN_LOW,                                  // 跨阻放大使能时钟，低有效
	output EN_15SAR_LOW,                                   // 十五位SAR使能，低有效
	output EN_SAR9_AMB_LOW,                                // 环境光
	output EN_SAR9_DC_LOW,                                 // 直流
	output EN_SAR9_IREF,                                   // 九位参考电流使能
	output EN_SAR15_AMB_LOW,                               // 环境光
	output EN_SAR15_DC_LOW,                                // 直流
	output EN_SAR15_IREF,                                  // 十五位参考电流使能
	output [7:0] IDAC_SAR9AMBN_LOW,                        // 光流
	output [7:0] IDAC_SAR9DCN_LOW,                         // 直流流
	output [7:0] IDAC_SAR15AMBN_LOW,                       // 光流
	output [7:0] IDAC_SAR15DCN_LOW,                        // 直流流
	output S0_IN,                                          // 选择位0
	output S1_IN,                                          // 选择位1
	output S2_IN,                                          // 选择位2
	output S3_IN,                                          // 选择位3
	output S4_IN                                           // 选择位4
);

	//-------------模块实例化信号-------------//
	// 复位同步器在CLK_2M域内产生的域复位输出
	wire w_rstn;                              // 域复位
	// 源域复位直接借用已稳定的w_rstn，见下方assign处的race条件说明
	wire w_source_rstn;                       // 源复位

	//--------------寄存器信号--------------//
	// flag_adc_physical_idle合成器的两级同步链
	reg reg_idle_sync_meta;                 // 第一级同步，隔离跨域亚稳态
	reg reg_idle_sync_stable;               // 第二级同步，供Top.i_adc_physical_idle使用
	// DBG_OUT选择值在CLK_2M域的安全锁存副本，只在更新事件到达时才采样spi_dbg_out_select_o
	reg [2:0] reg_dbg_out_select_stable;    // 供dec_dbg_out_mux消费，避免多bit值零同步级跨域撕裂

	//---------------译码信号---------------//
	// DBG_OUT候选选择的组合译码结果
	wire dec_dbg_out_mux;                   // 按spi_dbg_out_select_o从6个候选中选出的电平

	//---------------其他信号---------------//
	// 精度模式选择Stage1/Stage2 DONE的异步组合结果，尚未同步
	wire w_idle_mux_async;                  // (!CLK_STAGE1_DOUT_LOW)/(!CLK_STAGE2_DOUT_LOW)按精度二选一

	// SSW与P2S/SPI物理引脚各自的输出桥接线，转发前不做任何处理，命名已自解释具体去向
	wire w_pad_en_tia_low;                  // 桥接线
	wire [7:0] w_pad_leddac;                // 桥接线
	wire w_pad_leden1_low;                  // 桥接线
	wire w_pad_leden2_low;                  // 桥接线
	wire w_pad_en_test;                     // 桥接线
	wire w_pad_clk_buf_low;                 // 桥接线
	wire w_pad_clk_iref_idac_low;           // 桥接线
	wire w_pad_clk_9q1_low;                 // 桥接线
	wire w_pad_clk_15q1_low;                // 桥接线
	wire w_pad_clk_aferst_low;              // 桥接线
	wire w_pad_clk_iref_idac_sar9_low;      // 桥接线
	wire w_pad_clk_iref_idac_sar15_low;     // 桥接线
	wire w_pad_clk_q2_low;                  // 桥接线
	wire w_pad_clk_q3_low;                  // 桥接线
	wire w_pad_clk_tiaen_low;               // 桥接线
	wire w_pad_en_15sar_low;                // 桥接线
	wire w_pad_en_sar9_amb_low;             // 桥接线
	wire w_pad_en_sar9_dc_low;              // 桥接线
	wire w_pad_en_sar9_iref;                // 桥接线
	wire w_pad_en_sar15_amb_low;            // 桥接线
	wire w_pad_en_sar15_dc_low;             // 桥接线
	wire w_pad_en_sar15_iref;               // 桥接线
	wire [7:0] w_pad_idac_sar9ambn_low;     // 桥接线
	wire [7:0] w_pad_idac_sar9dcn_low;      // 桥接线
	wire [7:0] w_pad_idac_sar15ambn_low;    // 桥接线
	wire [7:0] w_pad_idac_sar15dcn_low;     // 桥接线
	wire [4:0] w_pad_s_in;                  // 桥接线
	wire w_pad_clk_2m;                      // 桥接线
	wire w_pad_spi_sdo;                     // 桥接线
	wire w_pad_p2s_data;                    // 桥接线
	wire w_pad_p2s_frame;                   // 桥接线

	//---------------输出信号---------------//
	// SPI寄存器文件写方向与命令输出
	wire [1023:0] spi_source_config_snapshot_o; // ACTIVE快照
	wire spi_source_config_update_event_o;  // COMMIT脉冲
	wire spi_source_characterization_update_valid_o; // 表征请求
	wire spi_source_static_characterization_enable_o; // BIAS位
	wire [4:0] spi_source_test_mux_ctrl_o;  // MUX码
	wire spi_start_event_o;                 // 启动脉冲
	wire spi_stop_event_o;                  // 停止脉冲
	wire spi_diag_clear_event_o;            // 清除脉冲
	wire spi_control_abort_event_o;         // 终止脉冲
	wire [2:0] spi_dbg_out_select_o;        // 选择值，仍是SPI_SCLK域寄存器，须配合下方更新事件锁存后才可用于CLK_2M域组合逻辑
	wire spi_dbg_out_select_update_event_o; // 选择值真实更新的单周期CLK_2M域桥接事件

	// P2S打包器对上游AMI结果fork的ready回报
	wire p2s_result_ready_o;                // 接P2S打包器.o_result_ready

	// ppg_control_top正式结果与生命周期输出
	wire top_measurement_result_valid_o;    // 接Top.o_measurement_result_valid
	wire signed [23:0] top_coarse_ppg_value_o; // 接Top.o_coarse_ppg_value
	wire top_coarse_valid_o;                // 接Top.o_coarse_valid
	wire top_coarse_recovery_calibrated_o;  // 接Top.o_coarse_recovery_calibrated
	wire signed [23:0] top_fine_ppg_value_o; // 接Top.o_fine_ppg_value
	wire top_fine_valid_o;                  // 接Top.o_fine_valid
	wire top_fine_recovery_calibrated_o;    // 接Top.o_fine_recovery_calibrated
	wire signed [11:0] top_calibrated_s1_value_o; // 接Top.o_calibrated_s1_value
	wire signed [14:0] top_programmable_15_code_o; // 接Top.o_programmable_15_code
	wire top_programmable_15_valid_o;       // 接Top.o_programmable_15_valid
	wire top_result_precision_mode_o;       // 接Top.o_result_precision_mode
	wire [15:0] top_result_frame_id_o;      // 接Top.o_result_frame_id
	wire [15:0] top_result_sample_index_o;  // 接Top.o_result_sample_index
	wire top_result_color_ir_o;             // 接Top.o_result_color_ir
	wire [1:0] top_result_frame_type_o;     // 接Top.o_result_frame_type
	wire [7:0] top_result_amb_code_snapshot_o; // 接Top.o_result_amb_code_snapshot
	wire [7:0] top_result_dc_code_snapshot_o; // 接Top.o_result_dc_code_snapshot
	wire [3:0] top_result_amb_code_epoch_o; // 接Top.o_result_amb_code_epoch
	wire [3:0] top_result_dc_code_epoch_o;  // 接Top.o_result_dc_code_epoch
	wire top_s1_calibration_applied_o;      // 接Top.o_s1_calibration_applied
	wire [9:0] top_s1_raw_o;                // 接Top.o_s1_raw
	wire [9:0] top_s2_raw_o;                // 接Top.o_s2_raw

	// ppg_control_top生命周期/ACK/错误输出
	wire [1:0] top_lifecycle_state_o;       // 接Top.o_lifecycle_state
	wire top_start_ready_o;                 // 接Top.o_start_ready
	wire top_commit_ack_event_o;            // 接Top.o_commit_ack_event
	wire top_start_ack_event_o;             // 接Top.o_start_ack_event
	wire top_stop_ack_event_o;              // 接Top.o_stop_ack_event
	wire top_commit_ack_sticky_o;           // 接Top.o_commit_ack_sticky
	wire top_error_sticky_o;                // 接Top.o_error_sticky
	wire [7:0] top_last_error_code_o;       // 接Top.o_last_error_code
	wire [7:0] top_schema_version_o;        // 接Top.o_schema_version
	wire [7:0] top_config_epoch_o;          // 接Top.o_config_epoch
	wire [7:0] top_coef_epoch_o;            // 接Top.o_coef_epoch
	wire [7:0] top_stage2_coef_epoch_o;     // 接Top.o_stage2_coef_epoch
	wire [7:0] top_dc_recovery_coef_epoch_o; // 接Top.o_dc_recovery_coef_epoch

	// ppg_control_top调度器/AMI/SSW诊断输出
	wire top_scheduler_idle_o;              // 接Top.o_scheduler_idle
	wire top_scheduler_launch_timeout_sticky_o; // 接Top.o_scheduler_launch_timeout_sticky
	wire top_scheduler_owner_deadline_timeout_sticky_o; // 接Top.o_scheduler_owner_deadline_timeout_sticky
	wire top_scheduler_completion_mismatch_sticky_o; // 接Top.o_scheduler_completion_mismatch_sticky
	wire top_scheduler_protocol_error_sticky_o; // 接Top.o_scheduler_protocol_error_sticky
	wire top_ami_datapath_empty_o;          // 接Top.o_ami_datapath_empty
	wire top_ami_idac_idle_o;               // 接Top.o_ami_idac_idle
	wire top_active_precision_mode_o;       // 接Top.o_active_precision_mode，供空闲合成器/DBG_OUT/诊断快照三方复用
	wire top_ami_integration_protocol_error_sticky_o; // 接Top.o_ami_integration_protocol_error_sticky
	wire top_ssw_wrapper_idle_o;            // 接Top.o_ssw_wrapper_idle
	wire top_ssw_switch_protocol_error_sticky_o; // 接Top.o_ssw_switch_protocol_error_sticky
	wire top_ssw_transaction_mismatch_sticky_o; // 接Top.o_ssw_transaction_mismatch_sticky
	wire top_ssw_owner_deadline_timeout_sticky_o; // 接Top.o_ssw_owner_deadline_timeout_sticky
	wire top_ssw_calibration_timeout_sticky_o; // 接Top.o_ssw_calibration_timeout_sticky

	// ppg_control_top表征控制握手与诊断输出
	wire top_source_config_update_ready_o;  // 接Top.o_source_config_update_ready
	wire top_source_characterization_update_ready_o; // 接Top.o_source_characterization_update_ready
	wire top_characterization_control_valid_o; // 接Top.o_characterization_control_valid
	wire top_characterization_protocol_error_sticky_o; // 接Top.o_characterization_protocol_error_sticky

	// ppg_control_top系统故障/abort监督输出
	wire top_system_fault_blocking_o;       // 接Top.o_system_fault_blocking
	wire top_system_abort_event_o;          // 接Top.o_system_abort_event
	wire top_system_fault_cause_valid_o;    // 接Top.o_system_fault_cause_valid
	wire [7:0] top_system_fault_cause_o;    // 接Top.o_system_fault_cause
	wire [3:0] top_system_fault_source_o;   // 接Top.o_system_fault_source
	wire top_system_fault_identity_valid_o; // 接Top.o_system_fault_identity_valid
	wire [15:0] top_system_fault_frame_id_o; // 接Top.o_system_fault_frame_id
	wire [15:0] top_system_fault_sample_index_o; // 接Top.o_system_fault_sample_index
	wire top_system_fault_color_ir_o;       // 接Top.o_system_fault_color_ir
	wire [1:0] top_system_fault_frame_type_o; // 接Top.o_system_fault_frame_type
	wire top_system_fault_precision_o;      // 接Top.o_system_fault_precision
	wire [7:0] top_system_fault_run_generation_o; // 接Top.o_system_fault_run_generation
	wire [15:0] top_system_fault_summary_o; // 接Top.o_system_fault_summary
	wire top_result_discard_summary_sticky_o; // 接Top.o_result_discard_summary_sticky

	// ppg_control_top正式结果discard公开观测输出
	wire top_measurement_result_discard_event_o; // 接Top.o_measurement_result_discard_event
	wire [1:0] top_measurement_result_discard_reason_o; // 接Top.o_measurement_result_discard_reason
	wire top_measurement_result_discard_identity_valid_o; // 接Top.o_measurement_result_discard_identity_valid
	wire top_measurement_result_discard_sample_valid_o; // 接Top.o_measurement_result_discard_sample_valid
	wire [15:0] top_measurement_result_discard_frame_id_o; // 接Top.o_measurement_result_discard_frame_id
	wire [15:0] top_measurement_result_discard_sample_index_o; // 接Top.o_measurement_result_discard_sample_index
	wire top_measurement_result_discard_color_ir_o; // 接Top.o_measurement_result_discard_color_ir
	wire [1:0] top_measurement_result_discard_frame_type_o; // 接Top.o_measurement_result_discard_frame_type
	wire top_measurement_result_discard_precision_o; // 接Top.o_measurement_result_discard_precision
	wire [7:0] top_measurement_result_discard_run_generation_o; // 接Top.o_measurement_result_discard_run_generation

	// ppg_control_top检测代际清空公开观测输出
	wire top_detection_discard_event_o;     // 接Top.o_detection_discard_event
	wire [1:0] top_detection_discard_reason_o; // 接Top.o_detection_discard_reason
	wire top_detection_discard_identity_valid_o; // 接Top.o_detection_discard_identity_valid
	wire top_detection_discard_sample_valid_o; // 接Top.o_detection_discard_sample_valid
	wire [15:0] top_detection_discard_frame_id_o; // 接Top.o_detection_discard_frame_id
	wire [15:0] top_detection_discard_sample_index_o; // 接Top.o_detection_discard_sample_index
	wire top_detection_discard_color_ir_o;  // 接Top.o_detection_discard_color_ir
	wire [1:0] top_detection_discard_frame_type_o; // 接Top.o_detection_discard_frame_type
	wire top_detection_discard_precision_o; // 接Top.o_detection_discard_precision
	wire [7:0] top_detection_discard_config_epoch_o; // 接Top.o_detection_discard_config_epoch
	wire [7:0] top_detection_discard_coef_epoch_o; // 接Top.o_detection_discard_coef_epoch
	wire [7:0] top_detection_discard_dc_recovery_epoch_o; // 接Top.o_detection_discard_dc_recovery_epoch
	wire [3:0] top_detection_discard_amb_code_epoch_o; // 接Top.o_detection_discard_amb_code_epoch
	wire [3:0] top_detection_discard_dc_code_epoch_o; // 接Top.o_detection_discard_dc_code_epoch
	wire [7:0] top_detection_discard_run_generation_o; // 接Top.o_detection_discard_run_generation

	//-------------其他信号连线-------------//
	// 源域复位直接沿用w_rstn，不用SPI_SCLK驱动的独立两级同步器：SPI_SCLK由主机间歇性提供，
	// 上电后第一笔真实SPI事务自身的头两个时钟沿如果同时被借用来推动同步链释放，会导致该事务
	// 起始若干比特被复位强制清零而错位；w_rstn已在始终运行的CLK_2M_PAD域完成同步且在任何真实
	// SPI活动开始前早已稳定，异步喂给源域是安全的，不存在亚稳态风险
	assign w_source_rstn = w_rstn;          // 源域复位借用已稳定的数字域释放结果

	// PRECISION_9BIT=1'b0选Stage1，PRECISION_15BIT=1'b1选Stage2，按C01 V1.11冻结公式
	assign w_idle_mux_async = top_active_precision_mode_o ? (!CLK_STAGE2_DOUT_LOW) : (!CLK_STAGE1_DOUT_LOW); // 选择依据是Top自己已同步实时输出，不是本模块另建判据

	// DBG_OUT六个候选按合同8.3节固定选择值排列，全部纯直连不加边沿检测；选择依据用CLK_2M域已安全锁存的
	// reg_dbg_out_select_stable，不直接用SPI_SCLK域的spi_dbg_out_select_o（多bit值零同步级跨域会撕裂）
	assign dec_dbg_out_mux = (reg_dbg_out_select_stable == 3'd0) ? top_start_ack_event_o :
	                          (reg_dbg_out_select_stable == 3'd1) ? top_stop_ack_event_o :
	                          (reg_dbg_out_select_stable == 3'd2) ? top_commit_ack_event_o :
	                          (reg_dbg_out_select_stable == 3'd3) ? top_system_abort_event_o :
	                          (reg_dbg_out_select_stable == 3'd4) ? top_measurement_result_valid_o :
	                          (reg_dbg_out_select_stable == 3'd5) ? top_active_precision_mode_o :
	                          1'b0;         // 选择值6/7保留，固定输出低电平

	//-------------输出信号连线-------------//
	// P2S_CLK直接用CLK_2M不分频，按合同8.4.1节
	assign P2S_CLK = CLK_2M_PAD;            // P2S移位时钟与数字系统域同源
	assign DBG_OUT = dec_dbg_out_mux;       // 六选一候选电平直接驱动物理引脚

	// SSW与P2S/SPI物理引脚各自的转发，全部纯改名直连，不插入任何时序或组合元件
	assign EN_TIA_LOW = w_pad_en_tia_low;   // 跨阻放大使能透传
	assign LEDDAC = w_pad_leddac;           // LED驱动数模码透传
	assign LEDEN1_LOW = w_pad_leden1_low;   // 红光LED选择透传
	assign LEDEN2_LOW = w_pad_leden2_low;   // 红外LED选择透传
	assign EN_TEST = w_pad_en_test;         // 模拟测试模式使能透传
	assign CLK_BUF_LOW = w_pad_clk_buf_low; // 时钟缓冲透传
	assign CLK_IREF_IDAC_LOW = w_pad_clk_iref_idac_low; // 参考电流IDAC时钟透传
	assign CLK_9Q1_LOW = w_pad_clk_9q1_low; // 九位第一相位时钟透传
	assign CLK_15Q1_LOW = w_pad_clk_15q1_low; // 十五位第一相位时钟透传
	assign CLK_AFERST_LOW = w_pad_clk_aferst_low; // 前端复位时钟透传
	assign CLK_IREF_IDAC_SAR9_LOW = w_pad_clk_iref_idac_sar9_low; // 九位转换参考电流IDAC时钟透传
	assign CLK_IREF_IDAC_SAR15_LOW = w_pad_clk_iref_idac_sar15_low; // 十五位转换参考电流IDAC时钟透传
	assign CLK_Q2_LOW = w_pad_clk_q2_low;   // 第二相位时钟透传
	assign CLK_Q3_LOW = w_pad_clk_q3_low;   // 第三相位采样中心时钟透传
	assign CLK_TIAEN_LOW = w_pad_clk_tiaen_low; // 跨阻放大使能时钟透传
	assign EN_15SAR_LOW = w_pad_en_15sar_low; // 十五位SAR使能透传
	assign EN_SAR9_AMB_LOW = w_pad_en_sar9_amb_low; // 光通路
	assign EN_SAR9_DC_LOW = w_pad_en_sar9_dc_low; // 流通路
	assign EN_SAR9_IREF = w_pad_en_sar9_iref; // 九位参考电流使能透传
	assign EN_SAR15_AMB_LOW = w_pad_en_sar15_amb_low; // 光通路
	assign EN_SAR15_DC_LOW = w_pad_en_sar15_dc_low; // 流通路
	assign EN_SAR15_IREF = w_pad_en_sar15_iref; // 十五位参考电流使能透传
	assign IDAC_SAR9AMBN_LOW = w_pad_idac_sar9ambn_low; // 光流线
	assign IDAC_SAR9DCN_LOW = w_pad_idac_sar9dcn_low; // 直流线
	assign IDAC_SAR15AMBN_LOW = w_pad_idac_sar15ambn_low; // 光流线
	assign IDAC_SAR15DCN_LOW = w_pad_idac_sar15dcn_low; // 直流线
	assign S0_IN = w_pad_s_in[0];           // 透传位0
	assign S1_IN = w_pad_s_in[1];           // 透传位1
	assign S2_IN = w_pad_s_in[2];           // 透传位2
	assign S3_IN = w_pad_s_in[3];           // 透传位3
	assign S4_IN = w_pad_s_in[4];           // 透传位4
	assign CLK_2M = w_pad_clk_2m;           // 2 MHz模拟侧参考时钟透传
	assign SPI_SDO = w_pad_spi_sdo;         // SPI从到主串行数据透传
	assign P2S_DATA = w_pad_p2s_data;       // P2S串行遥测数据透传
	assign P2S_FRAME = w_pad_p2s_frame;     // P2S包边界指示透传

	//-----------主要任务处理区域-----------//
	// 空闲合成器第一级同步，隔离跨域亚稳态
	always@(posedge CLK_2M_PAD or negedge w_rstn)begin
		if(w_rstn == 1'b0)begin
			reg_idle_sync_meta <= 1'b0;     // 复位期间保持非空闲，避免误报物理ADC已排空
		end else begin
			reg_idle_sync_meta <= w_idle_mux_async; // 首级触发器只采样异步电平
		end
	end

	// 空闲合成器第二级同步，供Top.i_adc_physical_idle直接使用
	always@(posedge CLK_2M_PAD or negedge w_rstn)begin
		if(w_rstn == 1'b0)begin
			reg_idle_sync_stable <= 1'b0;   // 复位期间保持非空闲
		end else begin
			reg_idle_sync_stable <= reg_idle_sync_meta; // 两级同步后交给Top消费
		end
	end

	// DBG_OUT选择值CLK_2M域安全锁存：更新事件到达时spi_dbg_out_select_o在源域早已稳定多拍，此刻采样安全
	always@(posedge CLK_2M_PAD or negedge w_rstn)begin
		if(w_rstn == 1'b0)begin
			reg_dbg_out_select_stable <= 3'd0; // 复位期间默认选择候选0，与SPI寄存器文件自身复位值一致
		end else if(spi_dbg_out_select_update_event_o == 1'b1)begin
			reg_dbg_out_select_stable <= spi_dbg_out_select_o; // 只在真实更新事件到达时才重新采样
		end else begin
			reg_dbg_out_select_stable <= reg_dbg_out_select_stable; // 其余拍原样保持，不跟随源域寄存器漂移
		end
	end

	//-----------模块实例化区域-----------//
	// 数字系统域复位释放，供SPI寄存器文件/P2S打包器/Top公用
	ppg_reset_sync ppg_reset_sync_clk2m_Inst(
		.i_clk(CLK_2M_PAD),               // 数字域时钟
		.i_async_rstn(RESET_N),           // 全局复位
		.o_rstn(w_rstn)                   // 数字域释放
	);

	// SPI从机寄存器文件：写方向直连Top配置总线，读方向汇聚Top全部只读诊断
	ppg_spi_register_file ppg_spi_register_file_Inst(
		.i_clk(CLK_2M_PAD),               // 快照捕获时钟
		.i_rstn(w_rstn),                  // 数字域复位
		.i_source_clk(SPI_SCLK),          // 源域时钟输入
		.i_source_rstn(w_source_rstn),    // 源域复位输入
		.i_spi_cs_n(SPI_CS_N),            // 封装片选
		.i_spi_sdi(SPI_SDI),              // 封装主从数据
		.o_spi_sdo(w_pad_spi_sdo),        // 封装从主数据
		.o_source_config_snapshot(spi_source_config_snapshot_o), // ACTIVE影子快照
		.o_source_config_update_event(spi_source_config_update_event_o), // COMMIT单周期事件
		.o_source_characterization_update_valid(spi_source_characterization_update_valid_o), // 表征保持型请求
		.o_source_static_characterization_enable(spi_source_static_characterization_enable_o), // STATIC_BIAS使能位
		.o_source_test_mux_ctrl(spi_source_test_mux_ctrl_o), // 测试MUX选择码
		.i_source_config_update_ready(top_source_config_update_ready_o), // ACTIVE邮箱资格回报
		.i_source_characterization_update_ready(top_source_characterization_update_ready_o), // 表征邮箱资格回报
		.o_start_event(spi_start_event_o), // 启动脉冲输出
		.o_stop_event(spi_stop_event_o),  // 停止脉冲输出
		.o_diag_clear_event(spi_diag_clear_event_o), // 清除脉冲输出
		.o_control_abort_event(spi_control_abort_event_o), // 终止脉冲输出
		.o_dbg_out_select(spi_dbg_out_select_o), // DBG_OUT选择值
		.o_dbg_out_select_update_event(spi_dbg_out_select_update_event_o), // 选择值更新桥接事件
		.i_lifecycle_state(top_lifecycle_state_o), // 接SPI寄存器文件.i_lifecycle_state：生命周期编码
		.i_start_ready(top_start_ready_o), // 接SPI寄存器文件.i_start_ready：启动资格
		.i_commit_ack_sticky(top_commit_ack_sticky_o), // 接SPI寄存器文件.i_commit_ack_sticky：配置成功sticky
		.i_error_sticky(top_error_sticky_o), // 接SPI寄存器文件.i_error_sticky：错误汇总sticky
		.i_last_error_code(top_last_error_code_o), // 接SPI寄存器文件.i_last_error_code：最近错误分类码
		.i_schema_version(top_schema_version_o), // 接SPI寄存器文件.i_schema_version：V4快照格式版本
		.i_config_epoch(top_config_epoch_o), // 接SPI寄存器文件.i_config_epoch：完整配置版本
		.i_coef_epoch(top_coef_epoch_o),  // 一级系数版本
		.i_stage2_coef_epoch(top_stage2_coef_epoch_o), // 二级系数版本
		.i_dc_recovery_coef_epoch(top_dc_recovery_coef_epoch_o), // 接SPI寄存器文件.i_dc_recovery_coef_epoch：DC恢复版本
		.i_scheduler_idle(top_scheduler_idle_o), // 接SPI寄存器文件.i_scheduler_idle：调度器空闲
		.i_scheduler_launch_timeout_sticky(top_scheduler_launch_timeout_sticky_o), // 接SPI寄存器文件.i_scheduler_launch_timeout_sticky：接管错过诊断
		.i_scheduler_owner_deadline_timeout_sticky(top_scheduler_owner_deadline_timeout_sticky_o), // 调度器截止诊断
		.i_scheduler_completion_mismatch_sticky(top_scheduler_completion_mismatch_sticky_o), // 接SPI寄存器文件.i_scheduler_completion_mismatch_sticky：DONE身份错配诊断
		.i_scheduler_protocol_error_sticky(top_scheduler_protocol_error_sticky_o), // 接SPI寄存器文件.i_scheduler_protocol_error_sticky：握手协议诊断
		.i_ami_datapath_empty(top_ami_datapath_empty_o), // 接SPI寄存器文件.i_ami_datapath_empty：AMI数据链排空
		.i_ami_idac_idle(top_ami_idac_idle_o), // 接SPI寄存器文件.i_ami_idac_idle：IDAC空闲
		.i_active_precision_mode(top_active_precision_mode_o), // 接SPI寄存器文件.i_active_precision_mode：实时committed精度
		.i_ami_integration_protocol_error_sticky(top_ami_integration_protocol_error_sticky_o), // 接SPI寄存器文件.i_ami_integration_protocol_error_sticky：AMI集成协议诊断
		.i_ssw_wrapper_idle(top_ssw_wrapper_idle_o), // 接SPI寄存器文件.i_ssw_wrapper_idle：SSW封装空闲
		.i_ssw_switch_protocol_error_sticky(top_ssw_switch_protocol_error_sticky_o), // 接SPI寄存器文件.i_ssw_switch_protocol_error_sticky：SSW切换协议诊断
		.i_ssw_transaction_mismatch_sticky(top_ssw_transaction_mismatch_sticky_o), // 接SPI寄存器文件.i_ssw_transaction_mismatch_sticky：SSW事务失配诊断
		.i_ssw_owner_deadline_timeout_sticky(top_ssw_owner_deadline_timeout_sticky_o), // 封装截止诊断
		.i_ssw_calibration_timeout_sticky(top_ssw_calibration_timeout_sticky_o), // 接SPI寄存器文件.i_ssw_calibration_timeout_sticky：SSW校准超时诊断
		.i_characterization_control_valid(top_characterization_control_valid_o), // 接SPI寄存器文件.i_characterization_control_valid：表征控制合法性
		.i_characterization_protocol_error_sticky(top_characterization_protocol_error_sticky_o), // 接SPI寄存器文件.i_characterization_protocol_error_sticky：表征协议诊断
		.i_system_fault_blocking(top_system_fault_blocking_o), // 接SPI寄存器文件.i_system_fault_blocking：系统阻断故障汇总
		.i_system_fault_cause_valid(top_system_fault_cause_valid_o), // 接SPI寄存器文件.i_system_fault_cause_valid：first-fault有效位
		.i_system_fault_identity_valid(top_system_fault_identity_valid_o), // 接SPI寄存器文件.i_system_fault_identity_valid：first-fault身份有效位
		.i_system_fault_color_ir(top_system_fault_color_ir_o), // 接SPI寄存器文件.i_system_fault_color_ir：first-fault颜色身份
		.i_system_fault_frame_type(top_system_fault_frame_type_o), // 接SPI寄存器文件.i_system_fault_frame_type：first-fault事务类型
		.i_system_fault_precision(top_system_fault_precision_o), // 接SPI寄存器文件.i_system_fault_precision：first-fault精度身份
		.i_result_discard_summary_sticky(top_result_discard_summary_sticky_o), // 接SPI寄存器文件.i_result_discard_summary_sticky：非blocking discard历史
		.i_system_fault_cause(top_system_fault_cause_o), // 接SPI寄存器文件.i_system_fault_cause：blocking cause编码
		.i_system_fault_source(top_system_fault_source_o), // 接SPI寄存器文件.i_system_fault_source：blocking来源编码
		.i_system_fault_frame_id(top_system_fault_frame_id_o), // 接SPI寄存器文件.i_system_fault_frame_id：first-fault帧号
		.i_system_fault_sample_index(top_system_fault_sample_index_o), // 接SPI寄存器文件.i_system_fault_sample_index：first-fault序号
		.i_system_fault_run_generation(top_system_fault_run_generation_o), // 接SPI寄存器文件.i_system_fault_run_generation：first-fault RUN代际
		.i_system_fault_summary(top_system_fault_summary_o), // 接SPI寄存器文件.i_system_fault_summary：blocking-cause summary位图
		.i_measurement_result_discard_event(top_measurement_result_discard_event_o), // 接SPI寄存器文件.i_measurement_result_discard_event：正式结果discard触发
		.i_measurement_result_discard_reason(top_measurement_result_discard_reason_o), // 接SPI寄存器文件.i_measurement_result_discard_reason：正式结果discard原因
		.i_measurement_result_discard_identity_valid(top_measurement_result_discard_identity_valid_o), // 接SPI寄存器文件.i_measurement_result_discard_identity_valid：正式结果discard身份有效位
		.i_measurement_result_discard_sample_valid(top_measurement_result_discard_sample_valid_o), // 接SPI寄存器文件.i_measurement_result_discard_sample_valid：正式结果discard样本资格
		.i_measurement_result_discard_frame_id(top_measurement_result_discard_frame_id_o), // 接SPI寄存器文件.i_measurement_result_discard_frame_id：正式结果discard帧号
		.i_measurement_result_discard_sample_index(top_measurement_result_discard_sample_index_o), // 接SPI寄存器文件.i_measurement_result_discard_sample_index：正式结果discard序号
		.i_measurement_result_discard_color_ir(top_measurement_result_discard_color_ir_o), // 接SPI寄存器文件.i_measurement_result_discard_color_ir：正式结果discard颜色身份
		.i_measurement_result_discard_frame_type(top_measurement_result_discard_frame_type_o), // 接SPI寄存器文件.i_measurement_result_discard_frame_type：正式结果discard帧类型
		.i_measurement_result_discard_precision(top_measurement_result_discard_precision_o), // 接SPI寄存器文件.i_measurement_result_discard_precision：正式结果discard精度
		.i_measurement_result_discard_run_generation(top_measurement_result_discard_run_generation_o), // 接SPI寄存器文件.i_measurement_result_discard_run_generation：正式结果discard RUN代际
		.i_detection_discard_event(top_detection_discard_event_o), // 接SPI寄存器文件.i_detection_discard_event：检测代际清空触发
		.i_detection_discard_reason(top_detection_discard_reason_o), // 接SPI寄存器文件.i_detection_discard_reason：检测discard原因
		.i_detection_discard_identity_valid(top_detection_discard_identity_valid_o), // 接SPI寄存器文件.i_detection_discard_identity_valid：检测discard身份有效位
		.i_detection_discard_sample_valid(top_detection_discard_sample_valid_o), // 接SPI寄存器文件.i_detection_discard_sample_valid：检测discard样本资格
		.i_detection_discard_frame_id(top_detection_discard_frame_id_o), // 接SPI寄存器文件.i_detection_discard_frame_id：检测discard帧号
		.i_detection_discard_sample_index(top_detection_discard_sample_index_o), // 接SPI寄存器文件.i_detection_discard_sample_index：检测discard序号
		.i_detection_discard_color_ir(top_detection_discard_color_ir_o), // 接SPI寄存器文件.i_detection_discard_color_ir：检测discard颜色身份
		.i_detection_discard_frame_type(top_detection_discard_frame_type_o), // 接SPI寄存器文件.i_detection_discard_frame_type：检测discard帧类型
		.i_detection_discard_precision(top_detection_discard_precision_o), // 接SPI寄存器文件.i_detection_discard_precision：检测discard精度
		.i_detection_discard_config_epoch(top_detection_discard_config_epoch_o), // 接SPI寄存器文件.i_detection_discard_config_epoch：检测discard配置版本
		.i_detection_discard_coef_epoch(top_detection_discard_coef_epoch_o), // 接SPI寄存器文件.i_detection_discard_coef_epoch：检测discard系数版本
		.i_detection_discard_dc_recovery_epoch(top_detection_discard_dc_recovery_epoch_o), // 接SPI寄存器文件.i_detection_discard_dc_recovery_epoch：检测discard DC恢复版本
		.i_detection_discard_amb_code_epoch(top_detection_discard_amb_code_epoch_o), // 环境光码版本
		.i_detection_discard_dc_code_epoch(top_detection_discard_dc_code_epoch_o), // 颜色码版本
		.i_detection_discard_run_generation(top_detection_discard_run_generation_o) // 接SPI寄存器文件.i_detection_discard_run_generation：检测discard RUN代际
	);

	// P2S打包器：12字段161-bit固定包，深度2队列承接背压
	ppg_p2s_packer ppg_p2s_packer_Inst(
		.i_clk(CLK_2M_PAD),               // 接P2S打包器.i_clk：CLK_2M域时钟
		.i_rstn(w_rstn),                  // 接P2S打包器.i_rstn：CLK_2M域复位
		.i_result_valid(top_measurement_result_valid_o), // 接P2S打包器.i_result_valid：正式结果保持有效
		.o_result_ready(p2s_result_ready_o), // 接P2S打包器.o_result_ready：队列未满时接受新结果
		.i_frame_id(top_result_frame_id_o), // 接P2S打包器.i_frame_id：字段1物理帧号
		.i_sample_index(top_result_sample_index_o), // 接P2S打包器.i_sample_index：字段2全局序号
		.i_color_ir(top_result_color_ir_o), // 接P2S打包器.i_color_ir：字段3颜色身份
		.i_frame_type(top_result_frame_type_o), // 接P2S打包器.i_frame_type：字段4帧类型编码
		.i_result_precision_mode(top_result_precision_mode_o), // 接P2S打包器.i_result_precision_mode：字段5结果精度快照
		.i_coarse_ppg_value(top_coarse_ppg_value_o), // 接P2S打包器.i_coarse_ppg_value：字段6粗PPG值
		.i_coarse_valid(top_coarse_valid_o), // 接P2S打包器.i_coarse_valid：字段6粗结果有效资格
		.i_coarse_recovery_calibrated(top_coarse_recovery_calibrated_o), // 接P2S打包器.i_coarse_recovery_calibrated：字段6粗结果恢复资格
		.i_fine_ppg_value(top_fine_ppg_value_o), // 接P2S打包器.i_fine_ppg_value：字段7精细PPG值
		.i_fine_valid(top_fine_valid_o),  // 接P2S打包器.i_fine_valid：字段7精细结果有效资格
		.i_fine_recovery_calibrated(top_fine_recovery_calibrated_o), // 接P2S打包器.i_fine_recovery_calibrated：字段7精细结果恢复资格
		.i_amb_code_snapshot(top_result_amb_code_snapshot_o), // 接P2S打包器.i_amb_code_snapshot：字段8 AMB码快照
		.i_dc_code_snapshot(top_result_dc_code_snapshot_o), // 接P2S打包器.i_dc_code_snapshot：字段8颜色DC码快照
		.i_amb_code_epoch(top_result_amb_code_epoch_o), // 接P2S打包器.i_amb_code_epoch：字段9 AMB码版本
		.i_dc_code_epoch(top_result_dc_code_epoch_o), // 接P2S打包器.i_dc_code_epoch：字段9颜色DC码版本
		.i_calibrated_s1_value(top_calibrated_s1_value_o), // 接P2S打包器.i_calibrated_s1_value：字段10 Stage1校准残差
		.i_programmable_15_code(top_programmable_15_code_o), // 接P2S打包器.i_programmable_15_code：字段11可编程15-bit残差
		.i_programmable_15_valid(top_programmable_15_valid_o), // 接P2S打包器.i_programmable_15_valid：字段11可编程精细结果资格
		.i_s1_calibration_applied(top_s1_calibration_applied_o), // 接P2S打包器.i_s1_calibration_applied：字段12 Stage1校准资格
		.i_stage1_raw(top_s1_raw_o),      // 接P2S打包器.i_stage1_raw：字段12 Stage1物理判决位
		.i_stage2_raw(top_s2_raw_o),      // 接P2S打包器.i_stage2_raw：字段12第二级冗余物理判决位
		.o_p2s_data(w_pad_p2s_data),      // 接P2S打包器.o_p2s_data：串行遥测数据直连物理引脚
		.o_p2s_frame(w_pad_p2s_frame)     // 接P2S打包器.o_p2s_frame：包边界指示直连物理引脚
	);

	// C01目标RTL：PPG算法唯一顶层，除已冻结的5个新增端口外未做任何改动
	ppg_control_top ppg_control_top_Inst(
		.i_clk(CLK_2M_PAD),               // 接Top.i_clk：CLK_2M域时钟
		.i_rstn(w_rstn),                  // 接Top.i_rstn：CLK_2M域复位
		.i_source_clk(SPI_SCLK),          // 接Top.i_source_clk：SPI源域时钟
		.i_source_rstn(w_source_rstn),    // 接Top.i_source_rstn：SPI源域复位
		.i_source_config_snapshot(spi_source_config_snapshot_o), // 接Top.i_source_config_snapshot：ACTIVE影子快照
		.i_source_config_update_event(spi_source_config_update_event_o), // 接Top.i_source_config_update_event：COMMIT单周期事件
		.i_source_characterization_update_valid(spi_source_characterization_update_valid_o), // 接Top.i_source_characterization_update_valid：表征保持型请求
		.i_source_static_characterization_enable(spi_source_static_characterization_enable_o), // 接Top.i_source_static_characterization_enable：STATIC_BIAS使能位
		.i_source_test_mux_ctrl(spi_source_test_mux_ctrl_o), // 接Top.i_source_test_mux_ctrl：测试MUX选择码
		.i_start_event(spi_start_event_o), // 启动脉冲输入
		.i_stop_event(spi_stop_event_o),  // 停止脉冲输入
		.i_diag_clear_event(spi_diag_clear_event_o), // 清除脉冲输入
		.i_control_abort_event(spi_control_abort_event_o), // 终止脉冲输入
		.i_dout_stage1_low(DOUT_STAGE1_LOW), // 一级判决直连
		.i_clk_stage1_dout_low_async(CLK_STAGE1_DOUT_LOW), // 一级完成直连
		.i_dout_stage2_low(DOUT_STAGE2_LOW), // 二级判决直连
		.i_clk_stage2_dout_low_async(CLK_STAGE2_DOUT_LOW), // 二级完成直连
		.i_adc_physical_idle(reg_idle_sync_stable), // 接Top.i_adc_physical_idle：本模块空闲合成器两级同步后的输出
		.i_analog_ready(1'b1),            // 接Top.i_analog_ready：按V1.10勘误固定常量，板级时序保证模拟侧先于数字侧稳定
		.i_measurement_result_ready(p2s_result_ready_o), // 接Top.i_measurement_result_ready：P2S打包器队列未满即可接受
		.i_test_inject_enable(1'b0),      // 验证注入整体排除出glue顶层，本组7个输入统一固定生产默认值
		.i_test_identity_inject_valid(1'b0), // 恒0
		.i_test_identity_inject_sample_index(16'd0), // 恒0
		.i_test_invalid_sample_valid(1'b0), // 恒0
		.i_test_saturation_inject_valid(1'b0), // 恒0
		.i_test_calibration_loss_inject_valid(1'b0), // 恒0
		.i_context_handover_stall_request(1'b0), // 恒0
		.o_en_tia_low(w_pad_en_tia_low),  // 直连
		.o_leddac(w_pad_leddac),          // 直连
		.o_leden1_low(w_pad_leden1_low),  // 直连
		.o_leden2_low(w_pad_leden2_low),  // 直连
		.o_en_test(w_pad_en_test),        // 直连
		.o_clk_buf_low(w_pad_clk_buf_low), // 直连
		.o_clk_iref_idac_low(w_pad_clk_iref_idac_low), // 直连
		.o_clk_9q1_low(w_pad_clk_9q1_low), // 直连
		.o_clk_15q1_low(w_pad_clk_15q1_low), // 直连
		.o_clk_aferst_low(w_pad_clk_aferst_low), // 直连
		.o_clk_iref_idac_sar9_low(w_pad_clk_iref_idac_sar9_low), // 直连
		.o_clk_iref_idac_sar15_low(w_pad_clk_iref_idac_sar15_low), // 直连
		.o_clk_q2_low(w_pad_clk_q2_low),  // 直连
		.o_clk_q3_low(w_pad_clk_q3_low),  // 直连
		.o_clk_tiaen_low(w_pad_clk_tiaen_low), // 直连
		.o_en_15sar_low(w_pad_en_15sar_low), // 直连
		.o_en_sar9_amb_low(w_pad_en_sar9_amb_low), // 直连
		.o_en_sar9_dc_low(w_pad_en_sar9_dc_low), // 直连
		.o_en_sar9_iref(w_pad_en_sar9_iref), // 网名不带_LOW，V1.9勘误已核实
		.o_en_sar15_amb_low(w_pad_en_sar15_amb_low), // 直连
		.o_en_sar15_dc_low(w_pad_en_sar15_dc_low), // 直连
		.o_en_sar15_iref(w_pad_en_sar15_iref), // 直连
		.o_idac_sar9ambn_low(w_pad_idac_sar9ambn_low), // 直连
		.o_idac_sar9dcn_low(w_pad_idac_sar9dcn_low), // 直连
		.o_idac_sar15ambn_low(w_pad_idac_sar15ambn_low), // 直连
		.o_idac_sar15dcn_low(w_pad_idac_sar15dcn_low), // 直连
		.o_s_in(w_pad_s_in),              // 位下标对应拆分转发
		.o_clk_2m(w_pad_clk_2m),          // 直连
		.o_measurement_result_valid(top_measurement_result_valid_o), // 接Top.o_measurement_result_valid：正式结果保持有效
		.o_coarse_ppg_value(top_coarse_ppg_value_o), // 接Top.o_coarse_ppg_value：粗PPG值
		.o_coarse_valid(top_coarse_valid_o), // 接Top.o_coarse_valid：粗结果有效资格
		.o_coarse_recovery_calibrated(top_coarse_recovery_calibrated_o), // 接Top.o_coarse_recovery_calibrated：粗结果恢复资格
		.o_coarse_saturation_low(),       // 8.4.6节排除的饱和标志之一，本组4个信号统一不接入P2S/SPI
		.o_coarse_saturation_high(),      // 同上
		.o_fine_ppg_value(top_fine_ppg_value_o), // 接Top.o_fine_ppg_value：精细PPG值
		.o_fine_valid(top_fine_valid_o),  // 接Top.o_fine_valid：精细结果有效资格
		.o_fine_recovery_calibrated(top_fine_recovery_calibrated_o), // 接Top.o_fine_recovery_calibrated：精细结果恢复资格
		.o_fine_saturation_low(),         // 同上
		.o_fine_saturation_high(),        // 同上
		.o_calibrated_s1_value(top_calibrated_s1_value_o), // 接Top.o_calibrated_s1_value：Stage1校准残差
		.o_programmable_15_code(top_programmable_15_code_o), // 接Top.o_programmable_15_code：可编程15-bit残差
		.o_programmable_15_valid(top_programmable_15_valid_o), // 接Top.o_programmable_15_valid：可编程精细结果资格
		.o_result_config_epoch(),         // 8.4.6节排除的session级静态量之一，本组4个信号统一不接入
		.o_result_coef_epoch(),           // 同上
		.o_result_stage2_coef_epoch(),    // 同上
		.o_result_dc_coef_epoch(),        // 同上
		.o_result_precision_mode(top_result_precision_mode_o), // 接Top.o_result_precision_mode：本笔结果精度快照
		.o_result_frame_id(top_result_frame_id_o), // 接Top.o_result_frame_id：本笔结果物理帧号
		.o_result_sample_index(top_result_sample_index_o), // 接Top.o_result_sample_index：本笔结果全局序号
		.o_result_color_ir(top_result_color_ir_o), // 接Top.o_result_color_ir：本笔结果颜色身份
		.o_result_frame_type(top_result_frame_type_o), // 接Top.o_result_frame_type：本笔结果帧类型编码
		.o_result_amb_code_snapshot(top_result_amb_code_snapshot_o), // 接Top.o_result_amb_code_snapshot：本笔结果AMB码快照
		.o_result_dc_code_snapshot(top_result_dc_code_snapshot_o), // 接Top.o_result_dc_code_snapshot：本笔结果颜色DC码快照
		.o_result_amb_code_epoch(top_result_amb_code_epoch_o), // 接Top.o_result_amb_code_epoch：本笔结果AMB码版本
		.o_result_dc_code_epoch(top_result_dc_code_epoch_o), // 接Top.o_result_dc_code_epoch：本笔结果颜色DC码版本
		.o_result_sample_valid(),         // 接Top.o_result_sample_valid：不在P2S 12字段清单内，生产下与measurement_result_valid恒同，暂不接入
		.o_lifecycle_state(top_lifecycle_state_o), // 接Top.o_lifecycle_state：CONFIG/READY/RUN/STOPPING
		.o_start_ready(top_start_ready_o), // 接Top.o_start_ready：READY且启动资格满足
		.o_commit_ack_event(top_commit_ack_event_o), // 供DBG_OUT候选2
		.o_start_ack_event(top_start_ack_event_o), // 供DBG_OUT候选0
		.o_stop_ack_event(top_stop_ack_event_o), // 供DBG_OUT候选1
		.o_error_event(),                 // 接Top.o_error_event：裸单周期脉冲，已有o_error_sticky覆盖同等信息，不接入
		.o_commit_ack_sticky(top_commit_ack_sticky_o), // 接Top.o_commit_ack_sticky：配置成功sticky
		.o_error_sticky(top_error_sticky_o), // 接Top.o_error_sticky：错误汇总sticky
		.o_last_error_code(top_last_error_code_o), // 接Top.o_last_error_code：最近错误分类码
		.o_schema_version(top_schema_version_o), // 接Top.o_schema_version：V4快照格式版本
		.o_config_epoch(top_config_epoch_o), // 接Top.o_config_epoch：完整配置版本
		.o_coef_epoch(top_coef_epoch_o),  // 接Top.o_coef_epoch：Stage1系数版本
		.o_stage2_coef_epoch(top_stage2_coef_epoch_o), // 接Top.o_stage2_coef_epoch：Stage2增益偏置字段版本
		.o_dc_recovery_coef_epoch(top_dc_recovery_coef_epoch_o), // 接Top.o_dc_recovery_coef_epoch：DC恢复系数版本
		.o_scheduler_idle(top_scheduler_idle_o), // 接Top.o_scheduler_idle：调度器数字与物理时序均排空
		.o_scheduler_launch_timeout_sticky(top_scheduler_launch_timeout_sticky_o), // 接Top.o_scheduler_launch_timeout_sticky：波形接管错过诊断
		.o_scheduler_owner_deadline_timeout_sticky(top_scheduler_owner_deadline_timeout_sticky_o), // 接Top.o_scheduler_owner_deadline_timeout_sticky：ADC owner截止错过诊断
		.o_scheduler_completion_mismatch_sticky(top_scheduler_completion_mismatch_sticky_o), // 接Top.o_scheduler_completion_mismatch_sticky：DONE身份错配诊断
		.o_scheduler_protocol_error_sticky(top_scheduler_protocol_error_sticky_o), // 接Top.o_scheduler_protocol_error_sticky：握手或编码协议诊断
		.o_ami_datapath_empty(top_ami_datapath_empty_o), // 接Top.o_ami_datapath_empty：AMI保持型数据链已排空
		.o_ami_idac_idle(top_ami_idac_idle_o), // 接Top.o_ami_idac_idle：AMI IDAC控制器真实空闲状态
		.o_active_precision_mode(top_active_precision_mode_o), // 接Top.o_active_precision_mode：系统唯一committed采集精度实时电平
		.o_ami_integration_protocol_error_sticky(top_ami_integration_protocol_error_sticky_o), // 接Top.o_ami_integration_protocol_error_sticky：AMI集成协议异常历史诊断
		.o_ssw_wrapper_idle(top_ssw_wrapper_idle_o), // 接Top.o_ssw_wrapper_idle：SSW封装完整空闲状态
		.o_ssw_switch_protocol_error_sticky(top_ssw_switch_protocol_error_sticky_o), // 接Top.o_ssw_switch_protocol_error_sticky：SSW切换协议错误保持
		.o_ssw_transaction_mismatch_sticky(top_ssw_transaction_mismatch_sticky_o), // 接Top.o_ssw_transaction_mismatch_sticky：SSW事务失配保持
		.o_ssw_owner_deadline_timeout_sticky(top_ssw_owner_deadline_timeout_sticky_o), // 接Top.o_ssw_owner_deadline_timeout_sticky：SSW结果所有权截止超时保持
		.o_ssw_calibration_timeout_sticky(top_ssw_calibration_timeout_sticky_o), // 接Top.o_ssw_calibration_timeout_sticky：SSW校准超时保持
		.o_source_config_update_ready(top_source_config_update_ready_o), // 接Top.o_source_config_update_ready：ACTIVE邮箱可接受下一笔快照资格
		.o_source_characterization_update_ready(top_source_characterization_update_ready_o), // 接Top.o_source_characterization_update_ready：表征邮箱可接受一笔事务资格
		.o_characterization_control_valid(top_characterization_control_valid_o), // 接Top.o_characterization_control_valid：复位后已存在合法提交控制
		.o_characterization_control_update_event(), // 裸脉冲未纳入只读区，本组连同下方system_stop_request共3个不接入
		.o_characterization_control_reject_event(), // 同上
		.o_characterization_protocol_error_sticky(top_characterization_protocol_error_sticky_o), // 接Top.o_characterization_protocol_error_sticky：运行期模式变更违反合同的sticky诊断
		.o_test_identity_inject_ready(),  // 验证注入排除，对应输入已恒0，本组4个信号统一不接入
		.o_test_invalid_sample_ready(),   // 同上
		.o_test_saturation_inject_ready(), // 同上
		.o_test_calibration_loss_inject_ready(), // 同上
		.o_system_fault_blocking(top_system_fault_blocking_o), // 接Top.o_system_fault_blocking：注册式系统阻断故障汇总状态
		.o_system_abort_event(top_system_abort_event_o), // 接Top.o_system_abort_event：注册式单周期系统abort事件，仅供DBG_OUT候选3
		.o_system_stop_request_event(),   // 同上
		.o_system_fault_discard_event(),  // 接Top.o_system_fault_discard_event：与两组discard锁存reason字段及故障汇总双重冗余，确认不接入
		.o_system_fault_cause_valid(top_system_fault_cause_valid_o), // 接Top.o_system_fault_cause_valid：first-fault快照有效位
		.o_system_fault_cause(top_system_fault_cause_o), // 故障原因编码
		.o_system_fault_source(top_system_fault_source_o), // 故障来源编码
		.o_system_fault_identity_valid(top_system_fault_identity_valid_o), // 接Top.o_system_fault_identity_valid：first-fault身份字段有效位
		.o_system_fault_frame_id(top_system_fault_frame_id_o), // 接Top.o_system_fault_frame_id：first-fault物理帧身份
		.o_system_fault_sample_index(top_system_fault_sample_index_o), // 接Top.o_system_fault_sample_index：first-fault事务序号
		.o_system_fault_color_ir(top_system_fault_color_ir_o), // 接Top.o_system_fault_color_ir：first-fault颜色身份
		.o_system_fault_frame_type(top_system_fault_frame_type_o), // 接Top.o_system_fault_frame_type：first-fault事务类型
		.o_system_fault_precision(top_system_fault_precision_o), // 接Top.o_system_fault_precision：first-fault精度身份
		.o_system_fault_run_generation(top_system_fault_run_generation_o), // 接Top.o_system_fault_run_generation：first-fault所属RUN代际
		.o_system_fault_summary(top_system_fault_summary_o), // 接Top.o_system_fault_summary：历史blocking-cause summary位图
		.o_result_discard_summary_sticky(top_result_discard_summary_sticky_o), // 接Top.o_result_discard_summary_sticky：非blocking正式结果discard历史summary
		.o_measurement_result_discard_event(top_measurement_result_discard_event_o), // 接Top.o_measurement_result_discard_event：正式结果生命周期丢弃单拍观测
		.o_measurement_result_discard_reason(top_measurement_result_discard_reason_o), // 接Top.o_measurement_result_discard_reason：STOP/abort/系统故障三态丢弃原因
		.o_measurement_result_discard_identity_valid(top_measurement_result_discard_identity_valid_o), // 接Top.o_measurement_result_discard_identity_valid：事件为高时恒为1
		.o_measurement_result_discard_sample_valid(top_measurement_result_discard_sample_valid_o), // 接Top.o_measurement_result_discard_sample_valid：被丢弃正式结果的独立样本资格快照
		.o_measurement_result_discard_frame_id(top_measurement_result_discard_frame_id_o), // 接Top.o_measurement_result_discard_frame_id：被丢弃事务的真实物理帧号
		.o_measurement_result_discard_sample_index(top_measurement_result_discard_sample_index_o), // 接Top.o_measurement_result_discard_sample_index：被丢弃事务的全局顺序编号
		.o_measurement_result_discard_color_ir(top_measurement_result_discard_color_ir_o), // 接Top.o_measurement_result_discard_color_ir：被丢弃事务的颜色身份
		.o_measurement_result_discard_frame_type(top_measurement_result_discard_frame_type_o), // 接Top.o_measurement_result_discard_frame_type：被丢弃事务的帧类型编码
		.o_measurement_result_discard_precision(top_measurement_result_discard_precision_o), // 接Top.o_measurement_result_discard_precision：被丢弃事务建立时所属的精度模式
		.o_measurement_result_discard_run_generation(top_measurement_result_discard_run_generation_o), // 接Top.o_measurement_result_discard_run_generation：被丢弃事务所属的RUN代际
		.o_detection_discard_event(top_detection_discard_event_o), // 接Top.o_detection_discard_event：检测代际清空广播的公开单拍观测
		.o_detection_discard_reason(top_detection_discard_reason_o), // 接Top.o_detection_discard_reason：STOP/abort/系统故障三态原因编码
		.o_detection_discard_identity_valid(top_detection_discard_identity_valid_o), // 接Top.o_detection_discard_identity_valid：触发广播时是否命中真实保留检测分支事务
		.o_detection_discard_sample_valid(top_detection_discard_sample_valid_o), // 接Top.o_detection_discard_sample_valid：触发事务的独立样本资格快照
		.o_detection_discard_frame_id(top_detection_discard_frame_id_o), // 接Top.o_detection_discard_frame_id：触发事务的真实物理帧号
		.o_detection_discard_sample_index(top_detection_discard_sample_index_o), // 接Top.o_detection_discard_sample_index：触发事务的全局顺序编号
		.o_detection_discard_color_ir(top_detection_discard_color_ir_o), // 接Top.o_detection_discard_color_ir：触发事务的颜色身份
		.o_detection_discard_frame_type(top_detection_discard_frame_type_o), // 接Top.o_detection_discard_frame_type：触发事务的帧类型编码
		.o_detection_discard_precision(top_detection_discard_precision_o), // 接Top.o_detection_discard_precision：触发事务建立时所属的精度模式
		.o_detection_discard_config_epoch(top_detection_discard_config_epoch_o), // 接Top.o_detection_discard_config_epoch：触发事务ACTIVE配置版本
		.o_detection_discard_coef_epoch(top_detection_discard_coef_epoch_o), // 接Top.o_detection_discard_coef_epoch：触发事务Stage1系数版本
		.o_detection_discard_dc_recovery_epoch(top_detection_discard_dc_recovery_epoch_o), // 接Top.o_detection_discard_dc_recovery_epoch：触发事务DC恢复版本
		.o_detection_discard_amb_code_epoch(top_detection_discard_amb_code_epoch_o), // 接Top.o_detection_discard_amb_code_epoch：触发事务环境光抵消码提交版本
		.o_detection_discard_dc_code_epoch(top_detection_discard_dc_code_epoch_o), // 接Top.o_detection_discard_dc_code_epoch：触发事务颜色DC码提交版本
		.o_detection_discard_run_generation(top_detection_discard_run_generation_o), // 接Top.o_detection_discard_run_generation：触发广播目标的RUN代际
		.o_s1_calibration_applied(top_s1_calibration_applied_o), // 接Top.o_s1_calibration_applied：字段12 Stage1校准资格
		.o_s1_raw(top_s1_raw_o),          // 接Top.o_s1_raw：字段12 Stage1物理判决位
		.o_s2_raw(top_s2_raw_o)           // 接Top.o_s2_raw：字段12第二级冗余物理判决位
	);

endmodule
