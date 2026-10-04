`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/23
// Design Name:        PPG Digital System Top
// Module Name:        ppg_control_top
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md
//                      PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//                      PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md
//                      PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md
//                      PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md
//                      PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//                      PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//                      PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_active_v4_control_plane_integration, ppg_characterization_control_cdc,
//                      ppg_400hz_frame_calibration_scheduler, ppg_adc_measurement_idac_integration,
//                      ppg_sar9_sar15_safe_selection_wrapper, ppg_system_fault_abort_supervisor
//
// Version:            V1.6
// Revision Date:      2026/09/18
// History:
//    Time               Version       Revised by            Contents
// 2026/08/23            V1.0          Erie                  Create file. First RTL implementation of contract C01 (V1.10): direct-child hierarchy, manager-wrapper safety-path table, V4/V5 joint 1024-bit ACTIVE routing, characterization CDC, Scheduler/AMI/SSW closed loop, shared physical-ADC-idle fanout, registered system fault/abort supervisor boundary, verification injection group and production-default gating.
// 2026/08/24            V1.1          Erie                  Fixed two declare-before-use ordering defects, both pure declaration-position issues, no logic change: (1) internal wire wrapper_stop_ack_event_o was referenced at the flag_test_inject_mode_latched clear condition well before its own wire declaration further down the file -- the original declaration's own comment already said it existed "so the latch-clear condition above can use it," confirming the intent was always to have it available before that point, the declaration simply never made it far enough up; moved it next to the already-correctly-pre-declared wrapper_run_enable_o, immediately before the always block that uses both. (2) fixing (1) exposed a second, identical-pattern defect one xvlog pass later: wrapper_start_ack_event_o was referenced by two assign statements (flag_analog_start_ack_event, flag_measurement_start_ack_event) several lines before its own wire declaration; moved it next to the already-correctly-pre-declared wrapper_allow_new_transaction_o, immediately before those two assigns. Searched the rest of the file for the same "forward-declared wrapper_*_o" convention (grep for the "向前引用/提前声明" comment markers this module's author uses to mark intentional forward declarations) and confirmed no further instances of the defect exist among them. iverilog pre-scans all declarations in a module regardless of textual order, so both defects were silently tolerated there and never surfaced in any of this module's iverilog-based regressions to date. Found only while setting up local Vivado xvlog compilation for Phase 3 Stage 3's long-run throughput comparison (this repository's first attempt to compile ppg_control_top.v with xvlog): xvlog enforces strict Verilog-2001 declare-before-use ordering and rejected the module outright (VRFC 10-3380 / 10-8530), once per defect. No assign, instance connection, or logic condition was touched by either fix. Verified with real simulation after each fix, not assumed safe from the diff alone: full iverilog rebuild plus all 23 tb_ppg_control_top.v SMOKE scenarios re-run and pass identically after both fixes (SMOKE_TB_PASS, same 47 real_adc_responses / 32 measurement_result_valid counts as before either change); xvlog analysis of ppg_control_top.v now completes with zero errors.
// 2026/08/31            V1.2          Erie                  Stage 5 bucket-2 RTL session, port-threading step: add top-level `i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready` to the existing verification-injection port group, threading straight into AMI's newly-added same-purpose ports (ppg_adc_measurement_idac_integration.v V1.13), which in turn thread into PWI (V1.4) and the leaf FIR module (ppg_coarse_detection_fir.v V2.3). Reuses the existing `C_ENABLE_TEST_INJECTION` parameter already present on this module; the output uses the same internal-wire-then-assign forwarding pattern already established for o_test_saturation_inject_ready (new wire ami_test_calibration_loss_inject_ready_o). Bit-identical production behavior confirmed: full-hierarchy iverilog rebuild plus the main smoke TB re-run identically (SMOKE_TB_PASS, same 47/32 counts) and the injection TB re-run with C_ENABLE_TEST_INJECTION=1 actually live (INJ_TB_PASS, all existing INJ-00~04 unaffected); this new port pair itself is not yet driven by any TB -- PRC-09/PRC-10 real construction is a separate, not-yet-done follow-up.
// 2026/08/31            V1.3          Erie                  Package/top-level integration design session: add public output `o_active_precision_mode`, a pure pass-through of the already-existing internal wire `ami_active_precision_mode_o` (AMI's `o_active_precision_mode`, already consumed internally by Scheduler `i_active_precision_mode` and SSW `i_precision_mode_committed`). Driven by the confirmed decision that the off-chip SPI/glue integration top needs a live, continuously-valid committed-precision level -- not the existing per-result snapshot `o_result_precision_mode` -- for two purposes: (1) selecting which physical ADC stage's DONE (Stage1 for 9-bit, Stage2 for 15-bit) feeds the dedicated single-point synchronizer that produces `i_adc_physical_idle` outside this module's boundary, and (2) a fixed field in the P2S debug packet so lab test can identify which cycle belongs to which precision mode. Same internal-wire-then-assign forwarding pattern as `o_ami_idac_idle`; no existing port, assign, or instance connection touched. This closes one of the two open items from the same session's `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` V1.11 errata. Not yet re-run through the smoke/injection TBs -- see deliverable-gate note below.
// 2026/08/31            V1.4          Erie                  Same integration design session, second port addition: add public output `o_source_config_update_ready`, the ready-polarity complement of the already-existing internal wire `wrapper_config_transport_busy_o` (ACTIVE wrapper's `o_config_transport_busy`, itself a pure forward of `ppg_config_cdc_bridge.o_source_busy`; already captured into a Top-internal wire since V1.0 but never exposed at the Top boundary). Closes the asymmetry the same session identified between the two SPI/glue-top source-domain write channels: the characterization channel already exposes `o_source_characterization_update_ready` so the SPI-side glue logic knows when the CDC mailbox can accept the next 6-bit transaction, but the 1024-bit V4+V5 ACTIVE channel had no equivalent -- the glue-top's SPI slave had no way to know whether it was safe to pulse `i_source_config_update_event` again without guessing a conservative worst-case delay. User confirmed exposing it as `ready` (matching the sibling signal's naming and polarity) rather than as `busy`, so this is the one deliberate inversion in this change: `assign o_source_config_update_ready = !wrapper_config_transport_busy_o;` -- everywhere else in this file `busy` stays `busy`. No existing port, assign, or instance connection touched; `wrapper_config_transport_busy_o` itself is unchanged, only newly read from a second place.
// 2026/09/05            V1.5          Erie                  Add the section 8.4.5 P2S telemetry boundary passthrough group: three new public outputs `o_s1_calibration_applied`, `o_s1_raw`, `o_s2_raw`, each a pure pass-through of AMI's newly-added same-name outputs (ppg_adc_measurement_idac_integration.v V1.14) via new internal wires `ami_s1_calibration_applied_o`/`ami_s1_raw_o`/`ami_s2_raw_o`. Same internal-wire-then-assign forwarding pattern as `o_active_precision_mode` (V1.3). Per PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md V1.6 section 8.4.5, already fully traced to AMI's own atomic dc-recovery payload re-export (not the reconstructor's earlier raw wires -- see AMI V1.14's own changelog entry for the precision rationale). No existing port, assign, or instance connection touched. Bit-identical production behavior confirmed: full-hierarchy iverilog rebuild plus the main smoke TB re-run identically (SMOKE_TB_PASS, real_adc_responses=47 measurement_result_valid=32, same as before this change).
// 2026/09/18            V1.6          Erie                  Pure internal wiring change while fixing the real SID-05 calibration-search-deadlock bug (see ppg_400hz_frame_calibration_scheduler.v V1.8 and ppg_adc_measurement_idac_integration.v V1.15 for the actual defect and root cause): connect the scheduler's new single-cycle o_cal_owner_deadline_event output directly to AMI's new i_cal_owner_deadline_event input via a new internal wire sched_cal_owner_deadline_event_o. No new top-level port, no logic at this level -- both endpoints already existed as sibling child instances in this module; this is only the missing point-to-point connection between them. Verified alongside the child-module fixes via a real iverilog rebuild of the startup-IDAC-calibration TB hierarchy.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月23日
// 设计名称:           PPG数字系统顶层
// 模块名称:           ppg_control_top
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md
//                      PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//                      PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md
//                      PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md
//                      PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md
//                      PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//                      PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//                      PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_active_v4_control_plane_integration、ppg_characterization_control_cdc、
//                      ppg_400hz_frame_calibration_scheduler、ppg_adc_measurement_idac_integration、
//                      ppg_sar9_sar15_safe_selection_wrapper、ppg_system_fault_abort_supervisor
//
// 当前版本:           V1.6
// 修订日期:           2026年09月18日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月23日        V1.0          Erie                  创建文件。合同C01（V1.10）首次RTL实现：直接子模块层次、manager-wrapper安全路径表、V4/V5联合1024-bit ACTIVE路由、表征控制CDC、Scheduler/AMI/SSW闭环、共享物理ADC空闲同源扇出、注册式系统故障/abort supervisor边界、验证注入组与生产默认关闭门控
// 2026年08月24日        V1.1          Erie                  修复两个声明晚于使用的顺序缺陷，都是纯粹的声明位置问题，不是逻辑改动：（1）内部wire wrapper_stop_ack_event_o在flag_test_inject_mode_latched的锁存清除条件里被引用，但它自己的wire声明在文件靠后位置才出现——原声明处自己的注释早就写着"供上面锁存清除条件使用"，说明本来就打算让它在那之前可用，只是声明位置没有真的挪到足够靠前；挪到已经正确提前声明的wrapper_run_enable_o旁边，紧接在同时用到这两者的always块之前。（2）修完（1）后下一轮xvlog又暴露出一个同样模式的缺陷：wrapper_start_ack_event_o被flag_analog_start_ack_event/flag_measurement_start_ack_event两条assign引用，同样比它自己的声明早了几行；挪到已经正确提前声明的wrapper_allow_new_transaction_o旁边，紧接在这两条assign之前。顺手检查了文件里其余用同一套"提前声明的wrapper_*_o向前引用"惯例（grep这位作者标记这类故意前置声明专用的"向前引用/提前声明"注释关键词）的信号，确认没有其余同类缺陷。iverilog会预扫描整个模块内的全部声明，不管文本顺序，所以这两处缺陷都一直被悄悄容忍，本模块历次iverilog回归都没暴露过。这次是在为Phase 3 Stage 3的长跑吞吐率对比搭建本地Vivado xvlog编译链路时才发现的（这是本仓库第一次真正尝试用xvlog编译ppg_control_top.v）：xvlog严格执行Verilog-2001的声明先于使用规则，每个缺陷各自直接拒绝整个模块一次（VRFC 10-3380/10-8530）。两处修复都没有改动任何assign、例化连接或逻辑条件本身。每次修完都用真实仿真验证过，不是单看diff就假设没事：两处都修完后，本地iverilog重新编译+tb_ppg_control_top.v全部23个SMOKE场景重跑，结果和改动前逐项一致（SMOKE_TB_PASS，47笔真实响应/32笔正式结果都不变）；xvlog对ppg_control_top.v的分析现在零错误通过。
// 2026年08月31日        V1.2          Erie                  Stage 5桶2 RTL会话端口透传步骤：在既有验证注入端口组里新增顶层`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready`，直接透传进AMI新增的同名端口（`ppg_adc_measurement_idac_integration.v`V1.13），继续透传进PWI（V1.4）和最底层FIR模块（`ppg_coarse_detection_fir.v`V2.3）。复用本模块已有的`C_ENABLE_TEST_INJECTION`参数；输出端沿用`o_test_saturation_inject_ready`已经建立的"内部wire+顶层assign转发"写法（新增wire`ami_test_calibration_loss_inject_ready_o`）。真实回归确认逐位不变：完整层次iverilog重新编译+主烟雾TB重跑结果一致（`SMOKE_TB_PASS`，47/32计数不变）+`C_ENABLE_TEST_INJECTION=1`真实生效状态下的注入TB重跑（`INJ_TB_PASS`，既有INJ-00~04全部不受影响）；这一对新端口本身还没有被任何TB驱动——PRC-09/PRC-10真实构造是独立的、本轮尚未完成的后续步骤
// 2026年08月31日        V1.3          Erie                  封装/顶层集成设计会话：新增公开输出`o_active_precision_mode`，纯转发已存在的内部wire`ami_active_precision_mode_o`（即AMI的`o_active_precision_mode`，内部已经供帧调度器`i_active_precision_mode`和SSW`i_precision_mode_committed`消费）。用户已确认片外SPI/glue集成顶层需要一个实时、任意时刻有效的committed精度电平——而不是现有按结果快照的`o_result_precision_mode`——用于两处：（1）为片外`i_adc_physical_idle`专用单点同步器选择应该采集Stage1还是Stage2的DONE（9-bit用Stage1，15-bit用Stage2）；（2）作为P2S调试包的固定字段随包外发，供测试时区分每个周期所属精度模式。沿用`o_ami_idac_idle`已经建立的"内部wire+顶层assign转发"写法，未改动任何既有端口、assign或例化连接。本次修改闭合同一会话`PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`V1.11勘误的两个待办之一。尚未重新跑smoke/injection TB回归——见下方交付物门禁说明。
// 2026年08月31日        V1.4          Erie                  同一集成设计会话，第二处端口新增：新增公开输出`o_source_config_update_ready`，是已存在内部wire`wrapper_config_transport_busy_o`（ACTIVE平面`o_config_transport_busy`的纯转发，其本身是`ppg_config_cdc_bridge.o_source_busy`的纯转发；这根wire从V1.0起就已经被Top接住，只是从来没有导出到Top边界）的ready极性取反版本。闭合同一会话发现的SPI/glue顶层两条source域写入通道之间的不对称：表征通道已经有`o_source_characterization_update_ready`让SPI侧glue逻辑知道CDC邮箱能不能接收下一笔6-bit事务，但1024-bit V4+V5 ACTIVE通道原来没有对应信号——glue顶层的SPI从机没有办法知道能不能安全地再拉一次`i_source_config_update_event`，只能猜一个保守延时。用户确认按ready极性导出（跟表征通道那个信号的命名和极性对称），而不是按busy导出，所以这是本文件里少有的一处故意取反：`assign o_source_config_update_ready = !wrapper_config_transport_busy_o;`——本文件其余地方busy信号一律保持busy极性不取反。未改动任何既有端口、assign或例化连接；`wrapper_config_transport_busy_o`本身没有变化，只是多了一处读取它的地方。
// 2026年09月05日        V1.5          Erie                  按合同8.4.5节新增P2S遥测边界透传端口组：新增3个公开输出`o_s1_calibration_applied`、`o_s1_raw`、`o_s2_raw`，各自纯转发AMI新增的同名输出（`ppg_adc_measurement_idac_integration.v`V1.14），经新增内部wire`ami_s1_calibration_applied_o`/`ami_s1_raw_o`/`ami_s2_raw_o`承接。沿用`o_active_precision_mode`（V1.3）已经建立的"内部wire+顶层assign转发"写法。依据`PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md`V1.6第8.4.5节，已经完整溯源到AMI自己DC恢复原子事务载荷的重新导出版本（不是重构器更早的raw wire——精确性理由见AMI V1.14自己的修订记录）。未改动任何既有端口、assign或例化连接。真实回归确认逐位不变：完整层次iverilog重新编译+主烟雾TB重跑结果一致（`SMOKE_TB_PASS`，real_adc_responses=47 measurement_result_valid=32，与改动前一致）。
// 2026年09月18日        V1.6          Erie                  纯内部接线改动，配合修复真实SID-05校准搜索死锁bug（真实缺陷与根因见`ppg_400hz_frame_calibration_scheduler.v`V1.8与`ppg_adc_measurement_idac_integration.v`V1.15）：新增内部wire`sched_cal_owner_deadline_event_o`，把调度器新增的单周期`o_cal_owner_deadline_event`输出直接接到AMI新增的`i_cal_owner_deadline_event`输入。不新增顶层端口，本层无逻辑——两端本来就是本模块的子例化，只是缺了这一条点对点连线。与两处子模块修复一起，通过真实iverilog重新编译启动IDAC校准TB层次验证。
//
// 已知开放项（不属于本次实现范围，已与用户逐项确认）：
// 1) i_leddac_r_code/i_leddac_ir_code：LED baseline闭环算法和寄存器位在PPG_NEW_CHAT_CONTEXT.md中
//    明确标注"尚未冻结"，C03 AV4C-16还明确禁止把LEDDAC映射进V4保留位；用户确认先用Top内
//    localparam临时固定常量接入，待LED baseline闭环算法冻结后回填真实驱动码。
// 2) i_analog_ready：C01自身§4.1未列出此顶层边界输入，但C03/C04和PPG_SYSTEM_CONFIG_LIFECYCLE_
//    CONTRACT_DRAFT.md均明确其语义为"模拟偏置、参考和输入选择已具备RUN资格的同步聚合结果"，
//    且明确不由数字侧任何子模块产生；本文件按物理边界输入引入，命名和单点同步方式与
//    i_adc_physical_idle同构。
// 聚合ACTIVE wrapper、表征控制CDC、400 Hz帧调度器、ADC测量与IDAC集成、SAR9/SAR15安全选择
// 封装和系统故障/abort监督器共6个直接子模块，是芯片内数字功能唯一顶层
module ppg_control_top
	#(
		parameter integer C_FRAME_ID_WIDTH = 32'd16, // 400 Hz物理帧号字段宽度，Top为唯一宽度权威
		parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16, // ADC事务全局序号字段宽度，Top为唯一宽度权威
		parameter integer C_CONFIG_WIDTH = 32'd1024, // V4+V5联合ACTIVE快照位宽，必须与wrapper内部固定宽度一致
		parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8, // 完整ACTIVE配置版本字段宽度
		parameter integer C_COEF_EPOCH_WIDTH = 32'd8, // Stage1/Stage2系数版本字段宽度
		parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 32'd8, // DC恢复系数版本字段宽度
		parameter integer C_CODE_EPOCH_WIDTH = 32'd4, // IDAC安全提交版本字段宽度
		parameter integer C_RUN_GENERATION_WIDTH = 32'd8, // manager唯一产生、Top只转发的RUN代际字段宽度
		parameter integer C_ENABLE_TEST_INJECTION = 32'd0, // 默认关闭的验证专用异常注入结构生成使能，生产网表必须为0
		parameter integer C_ADC_DRAIN_WATCHDOG_CYCLES = 32'd5000, // supervisor物理ADC排空看门狗超时周期数
		parameter integer C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH = 32'd13 // supervisor看门狗计数器字段宽度
	)
	(
		//-----------------全局时钟与复位-----------------//
		input i_clk,                                      // 唯一2 MHz数字系统域工作时钟
		input i_rstn,                                     // 2 MHz域低有效复位
		input i_source_clk,                               // SPI配置源域时钟，同时驱动V4控制平面与表征控制CDC的source端
		input i_source_rstn,                              // SPI配置源域低有效复位

		//---------------V4+V5联合ACTIVE源域接口---------------//
		input [C_CONFIG_WIDTH - 1:0] i_source_config_snapshot, // source域完整V4+V5联合shadow快照
		input i_source_config_update_event,                    // source域请求传输快照的单周期事件

		//---------------表征SPI source保持型接口---------------//
		input i_source_characterization_update_valid,           // 保持型source表征控制更新请求，直到CDC握手接受
		input i_source_static_characterization_enable,          // 待传输的STATIC_BIAS模式使能位
		input [4:0] i_source_test_mux_ctrl,                     // 待传输的五位模拟测试MUX选择码

		//---------------已同步生命周期与诊断输入---------------//
		input i_start_event,                                    // 已同步START事件，只进入V4控制平面
		input i_stop_event,                                     // 已同步STOP事件，参与唯一flag_stop_request_event合并
		input i_diag_clear_event,                               // 唯一2 MHz已同步诊断清除源，Top据此注册两路独立清除网
		input i_control_abort_event,                            // 已同步外部abort事件，参与owner-abort合并和STOP合并两条独立路径

		//---------------物理ADC与模拟边界输入---------------//
		input [9:0] i_dout_stage1_low,                       // Stage1物理判决码，进入AMI
		input i_clk_stage1_dout_low_async,                   // Stage1异步完成保持电平，进入AMI
		input [9:0] i_dout_stage2_low,                       // Stage2物理判决码，进入AMI（STAGE2）（二级）
		input i_clk_stage2_dout_low_async,                   // Stage2异步完成保持电平，进入AMI（STAGE2）（二级）
		input i_adc_physical_idle,                           // 已同步物理ADC/DONE空闲保持电平，形成唯一flag_adc_physical_idle
		input i_analog_ready,                                // 已同步模拟偏置/参考/输入选择RUN启动资格聚合结果，仅送wrapper

		//---------------正式结果消费者接口---------------//
		input i_measurement_result_ready,                 // 片外消费者接受AMI正式测量结果

		//---------------验证专用异常注入输入---------------//
		input i_test_inject_enable,                         // 验证构建CONFIG/READY期间的注入模式请求，与C_ENABLE_TEST_INJECTION共同限定
		input i_test_identity_inject_valid,                 // 保持型one-shot错误完成身份请求
		input [C_SAMPLE_INDEX_WIDTH - 1:0] i_test_identity_inject_sample_index, // 显式错误完成sample index payload
		input i_test_invalid_sample_valid,                  // 保持型one-shot invalid-sample请求
		input i_test_saturation_inject_valid,               // 保持型one-shot饱和注入请求，透传给内部IDAC控制器
		input i_test_calibration_loss_inject_valid,         // 保持型one-shot calibration-loss注入请求，透传给内部粗检测FIR
		input i_context_handover_stall_request,             // 验证专用，请求在接管tick合法压低SSW的context ready，不构成协议违规

		//---------------SSW模拟控制原样输出---------------//
		output o_en_tia_low,                               // 跨阻放大使能，低有效
		output [7:0] o_leddac,                             // LED驱动数模码
		output o_leden1_low,                               // 红光LED选择，低有效
		output o_leden2_low,                               // 红外LED选择，低有效
		output o_en_test,                                  // 模拟测试模式使能
		output o_clk_buf_low,                              // 时钟缓冲，低有效
		output o_clk_iref_idac_low,                        // 参考电流IDAC时钟，低有效
		output o_clk_9q1_low,                              // 九位第一相位时钟，低有效
		output o_clk_15q1_low,                             // 十五位第一相位时钟，低有效
		output o_clk_aferst_low,                           // 前端复位时钟，低有效
		output o_clk_iref_idac_sar9_low,                   // 九位转换参考电流IDAC时钟，低有效
		output o_clk_iref_idac_sar15_low,                  // 十五位转换参考电流IDAC时钟，低有效
		output o_clk_q2_low,                               // 第二相位时钟，低有效
		output o_clk_q3_low,                               // 第三相位采样中心时钟，低有效
		output o_clk_tiaen_low,                            // 跨阻放大使能时钟，低有效
		output o_en_15sar_low,                             // 十五位SAR使能，低有效
		output o_en_sar9_amb_low,                          // 九位AMB通路使能，低有效
		output o_en_sar9_dc_low,                           // 九位DC通路使能，低有效（DC）（直流）
		output o_en_sar9_iref,                             // 九位参考电流使能
		output o_en_sar15_amb_low,                         // 十五位AMB通路使能，低有效
		output o_en_sar15_dc_low,                          // 十五位DC通路使能，低有效（DC）（直流）
		output o_en_sar15_iref,                            // 十五位参考电流使能
		output [7:0] o_idac_sar9ambn_low,                  // 九位AMB电流数模总线，低有效
		output [7:0] o_idac_sar9dcn_low,                   // 九位DC电流数模总线，低有效（SAR9DCN）（九位直流总线）
		output [7:0] o_idac_sar15ambn_low,                 // 十五位AMB电流数模总线，低有效
		output [7:0] o_idac_sar15dcn_low,                  // 十五位DC电流数模总线，低有效（SAR15DCN）（十五位直流总线）
		output [4:0] o_s_in,                               // 观测选择专用字段
		output o_clk_2m,                                   // 2 MHz模拟侧参考时钟

		//---------------AMI正式测量结果输出---------------//
		output o_measurement_result_valid,                 // 正式结果保持有效至消费
		output signed [23:0] o_coarse_ppg_value,           // DC恢复后粗PPG值
		output o_coarse_valid,                             // 粗结果有效资格
		output o_coarse_recovery_calibrated,               // 粗结果正式恢复资格
		output o_coarse_saturation_low,                    // 粗结果负向饱和诊断
		output o_coarse_saturation_high,                   // 粗结果正向饱和诊断
		output signed [23:0] o_fine_ppg_value,             // DC恢复后精细PPG值
		output o_fine_valid,                               // 精细结果有效资格
		output o_fine_recovery_calibrated,                 // 精细结果正式恢复资格
		output o_fine_saturation_low,                      // 精细结果负向饱和诊断
		output o_fine_saturation_high,                     // 精细结果正向饱和诊断
		output signed [11:0] o_calibrated_s1_value,        // 正式Stage1校准残差
		output signed [14:0] o_programmable_15_code,       // 正式可编程15-bit残差
		output o_programmable_15_valid,                    // 可编程精细结果资格
		output [C_CONFIG_EPOCH_WIDTH - 1:0] o_result_config_epoch, // 本笔结果ACTIVE版本
		output [C_COEF_EPOCH_WIDTH - 1:0] o_result_coef_epoch, // 本笔结果Stage1系数版本
		output [C_COEF_EPOCH_WIDTH - 1:0] o_result_stage2_coef_epoch, // 本笔结果Stage2系数版本（STAGE2）（二级）
		output [C_DC_RECOVERY_EPOCH_WIDTH - 1:0] o_result_dc_coef_epoch, // 本笔结果DC恢复版本
		output o_result_precision_mode,                    // 本笔结果精度快照
		output [C_FRAME_ID_WIDTH - 1:0] o_result_frame_id, // 本笔结果物理帧号
		output [C_SAMPLE_INDEX_WIDTH - 1:0] o_result_sample_index, // 本笔结果全局序号
		output o_result_color_ir,                          // 本笔结果颜色身份
		output [1:0] o_result_frame_type,                  // 本笔结果帧类型编码
		output [7:0] o_result_amb_code_snapshot,           // 本笔结果AMB码快照
		output [7:0] o_result_dc_code_snapshot,            // 本笔结果颜色DC码快照
		output [C_CODE_EPOCH_WIDTH - 1:0] o_result_amb_code_epoch, // 本笔结果AMB码版本
		output [C_CODE_EPOCH_WIDTH - 1:0] o_result_dc_code_epoch, // 本笔结果颜色DC码版本
		output o_result_sample_valid,                      // 与measurement_result_valid同一保持型事务的独立样本资格

		//---------------V4/V5生命周期ACK与错误输出---------------//
		output [1:0] o_lifecycle_state,                           // CONFIG、READY、RUN或STOPPING
		output o_start_ready,                                     // READY且所有启动资格满足
		output o_commit_ack_event,                                // 合法配置成为ACTIVE的单周期应答
		output o_start_ack_event,                                 // START合法接受的单周期应答
		output o_stop_ack_event,                                  // STOP接受或幂等处理的单周期应答
		output o_error_event,                                     // 当前配置或命令被拒绝的单周期事件
		output o_commit_ack_sticky,                               // 配置成功sticky状态
		output o_error_sticky,                                    // 错误汇总sticky状态
		output [7:0] o_last_error_code,                           // 最近一次错误分类码
		output [7:0] o_schema_version,                            // V4快照格式版本
		output [7:0] o_config_epoch,                              // 完整配置版本
		output [7:0] o_coef_epoch,                                // Stage1系数版本
		output [7:0] o_stage2_coef_epoch,                         // Stage2增益/偏置字段版本
		output [7:0] o_dc_recovery_coef_epoch,                    // DC恢复系数版本

		//---------------调度器/AMI/SSW只读诊断输出---------------//
		output o_scheduler_idle,                                  // 调度器数字与物理时序均排空
		output o_scheduler_launch_timeout_sticky,                 // 调度器波形接管错过诊断
		output o_scheduler_owner_deadline_timeout_sticky,         // 调度器ADC owner截止错过诊断
		output o_scheduler_completion_mismatch_sticky,            // 调度器DONE身份错配诊断
		output o_scheduler_protocol_error_sticky,                 // 调度器握手或编码协议诊断
		output o_ami_datapath_empty,                              // AMI保持型数据链已经排空
		output o_ami_idac_idle,                                   // AMI IDAC控制器真实空闲状态
		output o_active_precision_mode,                           // 系统唯一committed采集精度实时电平，供片外glue顶层选择物理ADC Stage1/Stage2 DONE并随P2S固定字段外发
		output o_ami_integration_protocol_error_sticky,           // AMI集成协议异常历史诊断
		output o_ssw_wrapper_idle,                                // SSW封装完整空闲状态
		output o_ssw_switch_protocol_error_sticky,                // SSW切换协议错误保持
		output o_ssw_transaction_mismatch_sticky,                 // SSW事务失配保持
		output o_ssw_owner_deadline_timeout_sticky,               // SSW结果所有权截止超时保持
		output o_ssw_calibration_timeout_sticky,                  // SSW校准超时保持

		//---------------表征控制source握手与诊断输出---------------//
		output o_source_config_update_ready,                        // V4+V5联合ACTIVE的source侧CDC邮箱可接受下一笔快照，与config_transport_busy互为反相
		output o_source_characterization_update_ready,              // 独立CDC邮箱可接受一笔完整6-bit事务
		output o_characterization_control_valid,                    // 复位后已存在一笔合法提交控制
		output o_characterization_control_update_event,             // 完整控制快照被目标域接受的单拍事件
		output o_characterization_control_reject_event,             // 运行期非法快照被整体拒绝的单拍事件
		output o_characterization_protocol_error_sticky,            // 运行期模式变更违反合同的sticky诊断

		//---------------验证专用异常注入应答输出---------------//
		output o_test_identity_inject_ready,                    // AMI当前可原子绑定identity请求
		output o_test_invalid_sample_ready,                     // AMI当前可原子绑定invalid请求（INVALID_SAMPLE）（无效类采样类）
		output o_test_saturation_inject_ready,                  // IDAC控制器当前可原子绑定饱和注入请求
		output o_test_calibration_loss_inject_ready,            // 粗检测FIR当前可原子绑定calibration-loss注入请求

		//---------------注册式系统故障/abort监督输出---------------//
		output o_system_fault_blocking,                             // 注册式系统阻断故障汇总状态
		output o_system_abort_event,                                // 注册式单周期系统abort诊断/扇出事件
		output o_system_stop_request_event,                         // supervisor产生的注册式单周期STOP请求观测
		output o_system_fault_discard_event,                        // supervisor产生的注册式单周期fault-discard选择事件
		output o_system_fault_cause_valid,                          // first-fault快照有效位
		output [7:0] o_system_fault_cause,                          // 固定blocking cause编码
		output [3:0] o_system_fault_source,                         // 固定blocking source编码（SOURCE）（来源类）
		output o_system_fault_identity_valid,                       // first-fault身份字段有效位
		output [C_FRAME_ID_WIDTH - 1:0] o_system_fault_frame_id,    // first-fault物理帧身份
		output [C_SAMPLE_INDEX_WIDTH - 1:0] o_system_fault_sample_index, // first-fault事务序号
		output o_system_fault_color_ir,                             // first-fault颜色身份
		output [1:0] o_system_fault_frame_type,                     // first-fault事务类型
		output o_system_fault_precision,                            // first-fault精度身份
		output [C_RUN_GENERATION_WIDTH - 1:0] o_system_fault_run_generation, // first-fault所属RUN代际
		output [15:0] o_system_fault_summary,                       // 历史blocking-cause summary位图
		output o_result_discard_summary_sticky,                     // 非blocking正式结果discard历史summary

		//---------------AMI正式结果discard公开观测输出---------------//
		output o_measurement_result_discard_event,                    // 正式结果生命周期丢弃单拍观测
		output [1:0] o_measurement_result_discard_reason,             // STOP、abort或系统故障三态丢弃原因
		output o_measurement_result_discard_identity_valid,           // 事件为高时恒为1
		output o_measurement_result_discard_sample_valid,             // 被丢弃正式结果的独立样本资格快照
		output [C_FRAME_ID_WIDTH - 1:0] o_measurement_result_discard_frame_id, // 被丢弃事务的真实物理帧号
		output [C_SAMPLE_INDEX_WIDTH - 1:0] o_measurement_result_discard_sample_index, // 被丢弃事务的全局顺序编号
		output o_measurement_result_discard_color_ir,                 // 被丢弃事务的颜色身份
		output [1:0] o_measurement_result_discard_frame_type,         // 被丢弃事务的帧类型编码
		output o_measurement_result_discard_precision,                // 被丢弃事务建立时所属的精度模式
		output [C_RUN_GENERATION_WIDTH - 1:0] o_measurement_result_discard_run_generation, // 被丢弃事务所属的RUN代际

		//---------------AMI检测代际清空公开观测输出---------------//
		output o_detection_discard_event,                          // 检测代际清空广播的公开单拍观测
		output [1:0] o_detection_discard_reason,                   // STOP、abort或系统故障三态原因编码
		output o_detection_discard_identity_valid,                 // 触发广播时是否命中真实保留检测分支事务
		output o_detection_discard_sample_valid,                   // 触发事务的独立样本资格快照
		output [C_FRAME_ID_WIDTH - 1:0] o_detection_discard_frame_id, // 触发事务的真实物理帧号
		output [C_SAMPLE_INDEX_WIDTH - 1:0] o_detection_discard_sample_index, // 触发事务的全局顺序编号
		output o_detection_discard_color_ir,                       // 触发事务的颜色身份
		output [1:0] o_detection_discard_frame_type,               // 触发事务的帧类型编码
		output o_detection_discard_precision,                      // 触发事务建立时所属的精度模式
		output [C_CONFIG_EPOCH_WIDTH - 1:0] o_detection_discard_config_epoch, // 触发事务ACTIVE配置版本
		output [C_COEF_EPOCH_WIDTH - 1:0] o_detection_discard_coef_epoch, // 触发事务Stage1系数版本
		output [C_DC_RECOVERY_EPOCH_WIDTH - 1:0] o_detection_discard_dc_recovery_epoch, // 触发事务DC恢复版本
		output [C_CODE_EPOCH_WIDTH - 1:0] o_detection_discard_amb_code_epoch, // 触发事务环境光抵消码提交版本
		output [C_CODE_EPOCH_WIDTH - 1:0] o_detection_discard_dc_code_epoch, // 触发事务颜色DC码提交版本
		output [C_RUN_GENERATION_WIDTH - 1:0] o_detection_discard_run_generation, // 触发广播目标的RUN代际

		//---------------P2S遥测边界透传---------------//
		output o_s1_calibration_applied,               // Stage1校准资格，DC恢复自己原子事务载荷重新导出版本，供片外glue顶层P2S固定字段外发
		output [9:0] o_s1_raw,                         // Stage1物理判决位，取自DC恢复自己重新导出的atomic payload_o
		output [9:0] o_s2_raw                          // 第二级冗余物理判决位，与o_s1_raw锁在同一拍atomic payload_o
	);

	//---------------参数化位宽约束（架构不变量，非运行时检查）---------------//
	// Top是唯一宽度权威；ACTIVE wrapper内部固定使用1024-bit联合快照，故C_CONFIG_WIDTH
	// 恒为1024；看门狗计数器位宽必须能够容纳C_ADC_DRAIN_WATCHDOG_CYCLES个计数值。
	// 综合RTL禁止使用initial块做运行时elaboration检查，这两条约束改为纯文档记录，
	// 由本文件参数默认值本身满足，不提供可综合的运行时校验路径。

	//---------------LEDDAC临时固定常量---------------//
	// LED baseline闭环算法和寄存器位尚未冻结（PPG_NEW_CHAT_CONTEXT.md明确记录），且C03
	// AV4C-16验收项明确禁止LEDDAC码来自V4保留位映射；用户在本轮会话中选择用Top内固定
	// localparam临时固定值，待项目冻结LED baseline闭环算法后再回填真实物理驱动码数值。
	localparam [7:0] C_LEDDAC_R_CODE = 8'hFF;         // 红光波段驱动码，供调度器波形快照使用，非最终标定值
	localparam [7:0] C_LEDDAC_IR_CODE = 8'hFF;        // 供调度器波形快照使用的红外波段驱动码占用值，非最终标定

	//---------------manager生命周期与supervisor边界内部网---------------//
	wire [C_RUN_GENERATION_WIDTH - 1:0] flag_run_generation;             // 内部转发：manager唯一产生、Top只转发的RUN代际
	wire flag_stop_episode_active;                                       // 内部转发：manager唯一产生的注册STOP排空episode电平
	wire flag_system_fault_blocking;                                     // 内部转发：supervisor注册系统阻断故障电平，只透明送manager
	wire flag_static_characterization_enable;                            // 内部转发：表征控制CDC已提交的STATIC_BIAS资格电平
	wire flag_adc_physical_idle;                                         // 内部转发：唯一物理ADC/DONE空闲同源扇出网

	//---------------诊断清除双路独立寄存器网---------------//
	// C01§4.1要求flag_diag_clear_event只扇出AMI/Scheduler/SSW/supervisor；
	// C03要求manager的i_status_clear_event只清本地读状态且不得被转发为系统诊断clear。
	// 两个净是Top对同一枚已同步诊断清除源的两路独立注册，互不转发。
	reg flag_diag_clear_event;                              // 唯一注册式系统诊断清除事件，只送AMI/Scheduler/SSW/supervisor
	reg flag_status_clear_event;                            // 唯一注册式manager本地状态清除事件，只送wrapper

	// 系统诊断清除单一目标寄存器：复位期间归零，避免复位释放瞬间误发迟到clear
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			flag_diag_clear_event <= 1'b0;                  // 复位归零，不产生迟到clear
		end else begin
			flag_diag_clear_event <= i_diag_clear_event;    // 单周期注册转发送AMI/Scheduler/SSW/supervisor；单一源双独立扇出,INJ-02/SMOKE-20-21实测确认 @satisfies: N04
		end
	end

	// manager本地状态清除单一目标寄存器：与flag_diag_clear_event同源但独立注册，互不转发
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			flag_status_clear_event <= 1'b0;                // 复位期间manager本地状态清除同步归零
		end else begin
			flag_status_clear_event <= i_diag_clear_event;  // 独立注册，只送wrapper本地状态清除
		end
	end

	//---------------owner-abort与STOP合并双路独立寄存器网---------------//
	// supervisor abort与外部abort合并成唯一owner-abort事件；外部abort同时独立注册
	// 一路abort-drain STOP请求贡献，只参与STOP合并，不直接进入owner-abort扇出。
	reg flag_owner_abort_event;                                          // 外部abort与supervisor abort的注册合并结果，扇出AMI/Scheduler/SSW的owner释放路径
	reg flag_abort_drain_stop_request;                                   // 外部abort独立注册的STOP合并贡献
	reg flag_stop_request_event;                                         // 唯一STOP合并事件，只送wrapper

	wire supervisor_system_abort_event_o;                                // 内部转发：supervisor原始abort事件，先入合并再消失
	wire supervisor_system_stop_request_event_o;                         // 内部转发：supervisor原始STOP请求事件，先入合并再消失

	// owner-abort合并单一目标寄存器：外部abort与supervisor abort在此汇合成唯一扇出
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			flag_owner_abort_event <= 1'b0;                              // 复位期间owner-abort合并结果同步归零
		end else begin
			flag_owner_abort_event <= i_control_abort_event || supervisor_system_abort_event_o; // 外部abort与supervisor abort唯一合并；G-FP-01端口台账代表行(i_control_abort_event登记) @satisfies: G-FP-01
		end
	end

	// abort-drain STOP贡献单一目标寄存器：外部abort独立注册，只参与下面的STOP合并
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			flag_abort_drain_stop_request <= 1'b0;                       // 复位期间abort-drain贡献同步归零
		end else begin
			flag_abort_drain_stop_request <= i_control_abort_event;      // 独立注册，不直接进入owner-abort扇出
		end
	end

	// STOP合并单一目标寄存器：外部STOP、supervisor STOP请求与abort-drain贡献三路汇合
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			flag_stop_request_event <= 1'b0;                             // 复位期间停止请求合并结果同步归零
		end else begin
			flag_stop_request_event <= i_stop_event || supervisor_system_stop_request_event_o || flag_abort_drain_stop_request; // 三路唯一STOP合并，只送wrapper
		end
	end

	//---------------验证注入CONFIG/READY锁存---------------//
	// i_test_inject_enable只是CONFIG/READY期间的配置请求，不是AMI运行时使能；
	// Top在RUN期间锁存该请求且忽略后续source侧变化，STOP/abort/reset清除锁存。
	reg flag_test_inject_mode_latched;                      // CONFIG/READY期间跟随请求、RUN期间锁定的验证注入模式位
	wire wrapper_run_enable_o;                              // 内部转发：提前声明，供锁存条件使用（wrapper例化于下文）
	wire wrapper_stop_ack_event_o;                          // 内部转发：提前声明，供下面锁存清除条件使用（wrapper例化于下文）

	// CONFIG/READY期间跟随请求，RUN期间锁定不变，STOP/abort/reset清除
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			flag_test_inject_mode_latched <= 1'b0;          // 复位清除锁存
		end else if(flag_owner_abort_event || wrapper_stop_ack_event_o) begin
			flag_test_inject_mode_latched <= 1'b0;          // abort或STOP接受时清除锁存
		end else if(!wrapper_run_enable_o) begin
			flag_test_inject_mode_latched <= i_test_inject_enable; // CONFIG/READY期间跟随source请求；运行期test-mode锁,INJ-01/02changelog实测确认mid-RUN无效 @satisfies: N05, P11
		end
	end

	wire flag_test_inject_effective;                        // 验证注入有效使能，生产网表恒为0
	assign flag_test_inject_effective = C_ENABLE_TEST_INJECTION && flag_test_inject_mode_latched; // C_ENABLE_TEST_INJECTION为0时恒为0

	//---------------模拟RUN与测量RUN许可拆分内部网---------------//
	wire analog_run_enable;                                       // 内部转发：送SSW的模拟RUN许可，STATIC_BIAS下仍为1
	wire measurement_run_enable;                                  // 内部转发：送Scheduler/AMI的测量RUN许可，STATIC_BIAS下强制0
	wire measurement_allow_new_transaction;                       // 内部转发：送Scheduler/AMI的新事务许可，STATIC_BIAS下强制0
	wire flag_analog_start_ack_event;                             // 内部转发：送SSW的START应答转发
	wire flag_measurement_start_ack_event;                        // 内部转发：送Scheduler/AMI的START应答，STATIC_BIAS下强制0

	wire wrapper_allow_new_transaction_o;                         // manager新ADC事务许可，向前引用，wrapper例化在本节之后
	wire wrapper_start_ack_event_o;                               // manager START合法接受应答，向前引用，wrapper例化在本节之后

	assign analog_run_enable = wrapper_run_enable_o;              // STATIC_BIAS下仍跟随RUN，允许建立静态向量；仅接SSW，高有效 @satisfies: TOP-18
	assign measurement_run_enable = wrapper_run_enable_o && !flag_static_characterization_enable; // STATIC_BIAS下强制0保持测量链空闲；仅接Scheduler/AMI，STATIC_BIAS下测量许可为0 @satisfies: TOP-12, TOP-18
	assign measurement_allow_new_transaction = wrapper_allow_new_transaction_o && !flag_static_characterization_enable; // STATIC_BIAS下禁止新ADC事务
	assign flag_analog_start_ack_event = wrapper_start_ack_event_o; // 转发完整START，SSW据此建立波形上下文
	assign flag_measurement_start_ack_event = wrapper_start_ack_event_o && !flag_static_characterization_enable; // STATIC_BIAS下不得观察测量START

	assign flag_adc_physical_idle = i_adc_physical_idle;          // 唯一物理空闲真源，逐字同源扇出五个消费者；supervisor仅用于watchdog排空/恢复，绝不解释为completion @satisfies: TOP-17, P17

	//===================<跨模块内部网集中声明（避免隐式wire，紧随合并逻辑）>===================//
	wire wrapper_config_transport_busy_o;                         // 内部转发：source快照CDC事务仍在途
	wire wrapper_config_transport_update_o;                       // 内部转发：destination域已收到完整快照的单周期事件
	wire [C_CONFIG_WIDTH - 1:0] wrapper_active_config_o;          // 内部转发：manager合法提交并保持的V4+V5联合ACTIVE快照
	wire wrapper_active_valid_o;                                  // 内部转发：ACTIVE具备本轮启动资格
	wire [7:0] wrapper_config_epoch_o;                            // 内部转发：完整配置版本
	wire [7:0] wrapper_coef_epoch_o;                              // 内部转发：Stage1系数版本
	wire [7:0] wrapper_stage2_coef_epoch_o;                       // 内部转发：Stage2增益和偏置字段的独立版本
	wire [7:0] wrapper_dc_recovery_coef_epoch_o;                  // 内部转发：DC恢复系数版本
	wire [1:0] wrapper_lifecycle_state_o;                         // 内部转发：CONFIG、READY、RUN或STOPPING
	wire wrapper_start_ready_o;                                   // 内部转发：READY且所有启动资格满足
	wire wrapper_commit_ack_event_o;                              // 内部转发：合法配置成为ACTIVE的单周期应答
	wire wrapper_error_event_o;                                   // 内部转发：当前配置或命令被拒绝的单周期事件
	wire wrapper_commit_ack_sticky_o;                             // 内部转发：配置成功sticky状态
	wire wrapper_error_sticky_o;                                  // 内部转发：错误汇总sticky状态
	wire [7:0] wrapper_last_error_code_o;                         // 内部转发：最近一次错误分类码
	wire [7:0] wrapper_schema_version_o;                          // 内部转发：V4快照格式版本
	wire wrapper_run_profile_o;                                   // 内部转发：NORMAL或CHARACTERIZATION档位
	wire wrapper_input_source_o;                                  // 内部转发：光电二极管或外部测试输入
	wire [1:0] wrapper_idac_mode_o;                               // 内部转发：MANUAL、SEARCH_HOLD或SEARCH_TRACK（IDAC_MODE）（电流数模类模式类）
	wire [1:0] wrapper_optical_mode_o;                            // 内部转发：双光、RED、IR或安全关闭
	wire wrapper_initial_precision_o;                             // 内部转发：RUN初始SAR精度
	wire wrapper_amb_enable_o;                                    // 内部转发：AMB控制参与资格
	wire wrapper_dcs_enable_o;                                    // 内部转发：红光和红外DC码搜索功能使能
	wire wrapper_amb_polarity_o;                                  // 内部转发：AMB调码极性
	wire wrapper_dcs_polarity_o;                                  // 内部转发：DC搜索时数字码的递增方向
	wire wrapper_stage1_calibration_valid_o;                      // 内部转发：Stage1系数有效标志
	wire wrapper_stage2_calibration_valid_o;                      // 内部转发：Stage2恢复计算参数已表征的标志
	wire wrapper_dc9_recovery_valid_o;                            // 内部转发：SAR9 DC恢复有效标志
	wire wrapper_dc15_recovery_valid_o;                           // 内部转发：SAR15精度链DC恢复数据可采用标志
	wire [7:0] wrapper_amb_manual_code_o;                         // 内部转发：AMB初始或手动码
	wire [7:0] wrapper_amb_code_min_o;                            // 内部转发：AMB最小提交码
	wire [7:0] wrapper_amb_code_max_o;                            // 内部转发：AMB最大提交码
	wire [7:0] wrapper_dcs_r_manual_code_o;                       // 内部转发：红光DC初始或手动码
	wire [7:0] wrapper_dcs_r_code_min_o;                          // 内部转发：红光DC最小提交码
	wire [7:0] wrapper_dcs_r_code_max_o;                          // 内部转发：红光DC最大提交码
	wire [7:0] wrapper_dcs_ir_manual_code_o;                      // 内部转发：红外DC初始或手动码
	wire [7:0] wrapper_dcs_ir_code_min_o;                         // 内部转发：红外DC最小提交码
	wire [7:0] wrapper_dcs_ir_code_max_o;                         // 内部转发：红外DC最大提交码
	wire signed [11:0] wrapper_amb_threshold_low_o;               // 内部转发：AMB低阈值
	wire signed [11:0] wrapper_amb_threshold_high_o;              // 内部转发：AMB高阈值
	wire signed [11:0] wrapper_dcs_threshold_low_o;               // 内部转发：DCS低阈值（DCS）（直流搜索）
	wire signed [11:0] wrapper_dcs_threshold_high_o;              // 内部转发：DCS高阈值（DCS）（直流搜索）
	wire [7:0] cnt_wrapper_amb_confirm_count_o;                   // 内部转发：AMB连续确认次数
	wire [7:0] cnt_wrapper_dcs_confirm_count_o;                   // 内部转发：红光和红外DC候选码的收敛确认次数
	wire signed [25:0] wrapper_stage1_weight_q16_0_o;             // 内部转发：Stage1权重0
	wire signed [25:0] wrapper_stage1_weight_q16_1_o;             // 内部转发：Stage1权重1（一号）
	wire signed [25:0] wrapper_stage1_weight_q16_2_o;             // 内部转发：Stage1权重2（二号）
	wire signed [25:0] wrapper_stage1_weight_q16_3_o;             // 内部转发：Stage1权重3（三号）
	wire signed [25:0] wrapper_stage1_weight_q16_4_o;             // 内部转发：Stage1权重4（四号）
	wire signed [25:0] wrapper_stage1_weight_q16_5_o;             // 内部转发：Stage1权重5（五号）
	wire signed [25:0] wrapper_stage1_weight_q16_6_o;             // 内部转发：Stage1权重6（六号）
	wire signed [25:0] wrapper_stage1_weight_q16_7_o;             // 内部转发：Stage1权重7（七号）
	wire signed [25:0] wrapper_stage1_weight_q16_8_o;             // 内部转发：Stage1权重8（八号）
	wire signed [25:0] wrapper_stage1_weight_q16_9_o;             // 内部转发：Stage1权重9（九号）
	wire signed [31:0] wrapper_stage1_offset_q16_o;               // 内部转发：Stage1加性offset
	wire signed [19:0] wrapper_stage2_gain_q16_o;                 // 内部转发：Stage2统一增益
	wire signed [31:0] wrapper_stage2_offset_q16_o;               // 内部转发：Stage2加性offset（STAGE2）（二级）
	wire signed [31:0] wrapper_dc9_recovery_gain_q16_o;           // 内部转发：SAR9 DC恢复增益
	wire signed [31:0] wrapper_dc15_recovery_gain_q16_o;          // 内部转发：SAR15精度域DC恢复使用的Q16增益
	wire [15:0] wrapper_amb_recheck_interval_frames_o;            // 内部转发：NORMAL完整帧重检间隔
	wire wrapper_slope_mode_o;                                    // 内部转发：基线斜率固定或自适应模式
	wire signed [31:0] wrapper_fixed_slope_q16_o;                 // 内部转发：固定负斜率的signed Q16值
	wire [15:0] wrapper_alpha_q15_o;                              // 内部转发：基础斜率幅度比例
	wire [15:0] wrapper_beta_q15_o;                               // 内部转发：活动斜率平滑比例
	wire [15:0] wrapper_timing_adjust_ratio_q15_o;                // 内部转发：相交时刻修正比例
	wire signed [31:0] wrapper_slope_min_q16_o;                   // 内部转发：最负斜率边界
	wire signed [31:0] wrapper_slope_max_q16_o;                   // 内部转发：最接近零斜率边界
	wire signed [31:0] wrapper_baseline_delta_q16_o;              // 内部转发：波峰锚点基线偏置
	wire [31:0] wrapper_cross_hysteresis_q16_o;                   // 内部转发：向上相交迟滞量
	wire [15:0] wrapper_lead_min_frames_o;                        // 内部转发：相交提前量合格下界
	wire [15:0] wrapper_lead_max_frames_o;                        // 内部转发：相交提前量合格上界
	wire [3:0] cnt_wrapper_cross_confirm_count_o;                 // 内部转发：相交连续确认点数
	wire [3:0] wrapper_no_cross_limit_o;                          // 内部转发：连续无相交重新获取阈值
	wire [3:0] cnt_wrapper_peak_confirm_count_o;                  // 内部转发：波峰连续下降确认点数
	wire [3:0] cnt_wrapper_valley_confirm_count_o;                // 内部转发：波谷连续上升确认点数
	wire [23:0] wrapper_direction_deadband_o;                     // 内部转发：相邻FIR方向分类死区
	wire [23:0] wrapper_min_peak_valley_amplitude_o;              // 内部转发：合格峰谷最小幅度
	wire [15:0] wrapper_min_peak_to_valley_frames_o;              // 内部转发：波峰到波谷最小帧差
	wire [15:0] wrapper_min_peak_to_peak_frames_o;                // 内部转发：相邻波峰最小帧差
	wire [15:0] wrapper_max_fine_window_frames_o;                 // 内部转发：15-bit窗口最大持续帧数
	wire [15:0] wrapper_max_reacquire_frames_o;                   // 内部转发：9-bit重新获取最大帧数
	wire wrapper_peak_valley_config_valid_o;                      // 内部转发：正式peak/valley/cross/fine-window资格位
	wire ccc_source_update_ready_o;                               // 内部转发：CDC邮箱可接收下一笔source快照的资格
	wire [4:0] ccc_test_mux_ctrl_o;                               // 内部转发：已提交的测试MUX控制值
	wire ccc_control_valid_o;                                     // 内部转发：复位后已经存在一笔合法提交控制
	wire ccc_control_update_event_o;                              // 内部转发：完整控制快照被目标域接受的单拍事件
	wire ccc_control_reject_event_o;                              // 内部转发：运行期非法快照被整体拒绝的单拍事件
	wire ccc_protocol_error_sticky_o;                             // 内部转发：记录运行期模式变更违反合同的sticky诊断
	wire sched_calibration_sample_ready_o;                        // 内部转发：调度器接受请求握手
	wire sched_waveform_context_valid_o;                          // 内部转发：保持型模拟波形上下文有效
	wire sched_waveform_precision_mode_o;                         // 内部转发：波形精度快照
	wire sched_waveform_color_ir_o;                               // 内部转发：波形颜色快照
	wire [C_FRAME_ID_WIDTH - 1:0] sched_waveform_frame_id_o;      // 内部转发：波形物理帧号
	wire [1:0] sched_waveform_frame_type_o;                       // 内部转发：波形事务类型
	wire [7:0] sched_waveform_amb_code_snapshot_o;                // 内部转发：波形AMB码快照
	wire [7:0] sched_waveform_dc_code_snapshot_o;                 // 内部转发：波形颜色DC码快照（DC_CODE_SNAPSHOT）（直流码值类快照类）
	wire [C_CODE_EPOCH_WIDTH - 1:0] sched_waveform_amb_code_epoch_o; // 内部转发：波形AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0] sched_waveform_dc_code_epoch_o; // 内部转发：波形颜色DC版本
	wire sched_waveform_input_source_o;                           // 内部转发：波形输入来源快照
	wire [1:0] sched_waveform_optical_mode_o;                     // 内部转发：波形光学模式快照
	wire [7:0] sched_waveform_leddac_code_snapshot_o;             // 内部转发：波形LEDDAC快照，固定8-bit物理LED驱动码，与AMB/DC的C_IDAC_CODE_WIDTH无关
	wire sched_transaction_start_valid_o;                         // 内部转发：保持型ADC owner事务valid
	wire sched_transaction_precision_mode_o;                      // 内部转发：ADC事务精度快照
	wire sched_transaction_color_ir_o;                            // 内部转发：ADC事务颜色
	wire [C_FRAME_ID_WIDTH - 1:0] sched_transaction_frame_id_o;   // 内部转发：ADC事务帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] sched_transaction_sample_index_o; // 内部转发：ADC事务序号
	wire [1:0] sched_transaction_frame_type_o;                    // 内部转发：ADC事务类型
	wire [7:0] sched_transaction_amb_code_snapshot_o;             // 内部转发：ADC事务AMB码
	wire [7:0] sched_transaction_dc_code_snapshot_o;              // 内部转发：ADC事务DC码（DC）（直流）
	wire [C_CODE_EPOCH_WIDTH - 1:0] sched_transaction_amb_code_epoch_o; // 内部转发：ADC事务AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0] sched_transaction_dc_code_epoch_o; // 内部转发：与本ADC颜色槽DC码绑定的epoch快照
	wire sched_adc_owner_commit_event_o;                          // 内部转发：与AMI fire同拍的owner提交
	wire sched_adc_owner_precision_mode_o;                        // 内部转发：owner精度身份
	wire sched_adc_owner_color_ir_o;                              // 内部转发：owner颜色身份
	wire [C_FRAME_ID_WIDTH - 1:0] sched_adc_owner_frame_id_o;     // 内部转发：owner帧号身份
	wire [1:0] sched_adc_owner_frame_type_o;                      // 内部转发：供SSW物理owner锁存的即将占用事务类别
	wire [7:0] sched_adc_owner_amb_code_snapshot_o;               // 内部转发：owner AMB码
	wire [7:0] sched_adc_owner_dc_code_snapshot_o;                // 内部转发：owner DC码（DC）（直流）
	wire [C_CODE_EPOCH_WIDTH - 1:0] sched_adc_owner_amb_code_epoch_o; // 内部转发：owner AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0] sched_adc_owner_dc_code_epoch_o; // 内部转发：owner DC版本（DC）（直流）
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] sched_adc_owner_sample_index_o; // 内部转发：owner正式序号
	wire sched_macro_frame_safe_boundary_o;                       // 内部转发：下一宏帧准备前安全边界
	wire sched_idac_code_safe_boundary_o;                         // 内部转发：IDAC唯一提交边界
	wire [C_FRAME_ID_WIDTH - 1:0] sched_safe_frame_id_o;          // 内部转发：下一400 Hz帧编号
	wire [12:0] sched_macro_tick_o;                               // 内部转发：当前宏帧相位
	wire [2:0] sched_calibration_subframe_index_o;                // 内部转发：当前校准子周期编号
	wire [9:0] sched_calibration_local_tick_o;                    // 内部转发：校准局部相位
	wire sched_normal_frame_complete_event_o;                     // 内部转发：NORMAL宏帧完成单拍
	wire sched_calibration_frame_complete_event_o;                // 内部转发：校准物理宏帧完成单拍
	wire sched_idle_o;                                            // 内部转发：数字事务和物理时序均排空
	wire sched_normal_frame_active_o;                             // 内部转发：当前执行NORMAL宏帧
	wire sched_calibration_frame_active_o;                        // 内部转发：当前执行校准宏帧
	wire sched_launch_timeout_sticky_o;                           // 内部转发：波形接管错过诊断
	wire sched_owner_deadline_timeout_sticky_o;                   // 内部转发：ADC owner截止错过诊断
	wire sched_cal_owner_deadline_event_o;                        // 内部转发：校准owner截止单周期事件，供AMI重新发起同一候选的请求
	wire sched_completion_mismatch_sticky_o;                      // 内部转发：DONE身份错配诊断
	wire sched_protocol_error_sticky_o;                           // 内部转发：握手或编码协议诊断
	wire sched_fault_valid_o;                                     // 内部转发：新故障episode单周期脉冲，供system fault/abort supervisor观测
	wire sched_fault_active_o;                                    // 内部转发：注册式阻断持续状态，即scheduler_local_fault_blocking
	wire sched_fault_identity_valid_o;                            // 内部转发：本次故障是否绑定了真实owner身份
	wire sched_fault_color_ir_o;                                  // 内部转发：故障owner颜色
	wire sched_fault_precision_mode_o;                            // 内部转发：故障owner精度
	wire [7:0] sched_fault_cause_o;                               // 内部转发：固定8'h11，不可恢复协议错误原因码
	wire [C_FRAME_ID_WIDTH - 1:0] sched_fault_frame_id_o;         // 内部转发：故障owner所属400 Hz帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] sched_fault_sample_index_o; // 内部转发：故障owner全局序号
	wire [1:0] sched_fault_frame_type_o;                          // 内部转发：故障owner事务类型
	wire [C_RUN_GENERATION_WIDTH - 1:0] sched_fault_run_generation_o; // 内部转发：故障owner所属RUN代际
	wire ssw_waveform_context_ready_o;                            // 内部转发：SSW固定相位接管ready
	wire ssw_adc_owner_ready_o;                                   // 内部转发：SSW确认最早pending owner可提交
	wire ssw_en_tia_low_o;                                        // 内部转发：输出端输出使能跨阻放大低有效低位编码端
	wire ssw_leden1_low_o;                                        // 内部转发：输出端输出红光选择低有效低位编码端
	wire ssw_leden2_low_o;                                        // 内部转发：输出端输出红外选择低有效低位编码端红外灯选通道
	wire ssw_en_test_o;                                           // 内部转发：输出端输出使能测试
	wire [7:0] ssw_leddac_o;                                      // 内部转发：输出端输出发光数模低位编码端
	wire ssw_clk_buf_low_o;                                       // 内部转发：输出端输出时钟缓冲低有效低位编码端
	wire ssw_clk_iref_idac_low_o;                                 // 内部转发：输出端输出时钟参考电流电流数模低有效低位编码端
	wire ssw_clk_9q1_low_o;                                       // 内部转发：输出端输出时钟九位第一相位低有效低位编码端
	wire ssw_clk_15q1_low_o;                                      // 内部转发：输出端输出时钟十五位第一相位低有效低位编码端（15Q1）（十五位一相）
	wire ssw_clk_aferst_low_o;                                    // 内部转发：输出端输出时钟前端复位低有效低位编码端
	wire ssw_clk_iref_idac_sar9_low_o;                            // 内部转发：输出端输出时钟参考电流电流数模九位转换低有效九位转换专用低位编码端
	wire ssw_clk_iref_idac_sar15_low_o;                           // 内部转发：输出端输出时钟参考电流电流数模十五位转换低有效十五位转换专用低位编码端
	wire ssw_clk_q2_low_o;                                        // 内部转发：输出端输出时钟第二相位低有效低位编码端
	wire ssw_clk_q3_low_o;                                        // 内部转发：输出端输出时钟第三相位低有效低位编码端第三相位采样中心
	wire ssw_clk_tiaen_low_o;                                     // 内部转发：输出端输出时钟专用字段低有效低位编码端
	wire ssw_en_15sar_low_o;                                      // 内部转发：输出端输出使能专用字段低有效低位编码端
	wire ssw_en_sar9_amb_low_o;                                   // 内部转发：输出端输出使能九位转换环境低有效九位转换专用环境码通路低位编码端
	wire ssw_en_sar9_dc_low_o;                                    // 内部转发：输出端输出使能九位转换直流低有效九位转换专用直流码通路低位编码端
	wire ssw_en_sar9_iref_o;                                      // 内部转发：输出端输出使能九位转换参考电流九位转换专用
	wire ssw_en_sar15_amb_low_o;                                  // 内部转发：输出端输出使能十五位转换环境低有效十五位转换专用环境码通路低位编码端
	wire ssw_en_sar15_dc_low_o;                                   // 内部转发：输出端输出使能十五位转换直流低有效十五位转换专用直流码通路低位编码端
	wire ssw_en_sar15_iref_o;                                     // 内部转发：输出端输出使能十五位转换参考电流十五位转换专用
	wire [7:0] ssw_idac_sar9ambn_low_o;                           // 内部转发：输出端输出电流数模九位环境总线低有效九位转换专用环境码通路低位编码端
	wire [7:0] ssw_idac_sar9dcn_low_o;                            // 内部转发：输出端输出电流数模九位直流总线低有效九位转换专用直流码通路低位编码端
	wire [7:0] ssw_idac_sar15ambn_low_o;                          // 内部转发：输出端输出电流数模十五位环境总线低有效红外专属红外光路十五位转换专用环境码通路低位编码端
	wire [7:0] ssw_idac_sar15dcn_low_o;                           // 内部转发：输出端输出电流数模十五位直流总线低有效红外专属红外光路十五位转换专用直流码通路低位编码端
	wire [4:0] ssw_s_in_o;                                        // 内部转发：输出端输出观测选择专用字段
	wire ssw_clk_2m_o;                                            // 内部转发：输出端输出时钟二兆赫兹低位编码端
	wire ssw_analog_safe_o;                                       // 内部转发：模拟控制已经回到安全保持状态
	wire ssw_sar_timing_idle_o;                                   // 内部转发：无在途SAR模拟相位
	wire ssw_wrapper_idle_o;                                      // 内部转发：输出端输出封装空闲低位编码端
	wire ssw_precision_active_o;                                  // 内部转发：输出端输出精度活动
	wire ssw_calibration_wave_active_o;                           // 内部转发：输出端输出校准专用字段活动低位编码端
	wire ssw_adc_owner_inflight_o;                                // 内部转发：输出端输出模数转换结果所有权在途直流码通路高位编码端低位编码端
	wire ssw_owner_q3_window_closed_o;                            // 内部转发：在途owner自身选定Q3窗口已关闭
	wire ssw_switch_protocol_error_sticky_o;                      // 内部转发：输出端输出切换协议错误保持高位编码端低位编码端
	wire ssw_transaction_mismatch_sticky_o;                       // 内部转发：输出端输出事务失配保持高位编码端
	wire ssw_owner_deadline_timeout_sticky_o;                     // 内部转发：输出端输出结果所有权截止超时保持低位编码端
	wire ssw_calibration_timeout_sticky_o;                        // 内部转发：输出端输出校准超时保持低位编码端
	wire ssw_wrapper_fault_blocking_o;                            // 内部转发：SSW波形保持或模拟时序路径报告的阻断故障
	wire ssw_fault_valid_o;                                       // 内部转发：输出端输出新故障episode单周期脉冲，供system fault/abort supervisor观测
	wire ssw_fault_active_o;                                      // 内部转发：输出端输出注册式阻断持续状态，即wrapper_fault_blocking的本地根因部分
	wire ssw_fault_identity_valid_o;                              // 内部转发：输出端输出本次故障是否绑定了真实事务身份
	wire ssw_fault_color_ir_o;                                    // 内部转发：输出端输出故障事务颜色
	wire ssw_fault_precision_mode_o;                              // 内部转发：输出端输出故障事务精度
	wire [7:0] ssw_fault_cause_o;                                 // 内部转发：输出端输出固定8'h21，SSW身份/所有权协议错误原因码
	wire [C_FRAME_ID_WIDTH - 1:0] ssw_fault_frame_id_o;           // 内部转发：输出端输出故障事务所属帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] ssw_fault_sample_index_o;   // 内部转发：输出端输出故障事务全局序号
	wire [1:0] ssw_fault_frame_type_o;                            // 内部转发：输出端输出故障事务类型
	wire [C_RUN_GENERATION_WIDTH - 1:0] ssw_fault_run_generation_o; // 内部转发：输出端输出故障事务所属RUN代际
	wire ami_transaction_start_ready_o;                           // 内部转发：AMI可接收事务
	wire ami_transaction_start_fire_o;                            // 内部转发：AMI返回的fire一致性旁带
	wire ami_adc_transaction_complete_event_o;                    // 内部转发：真实ADC完成单拍
	wire ami_adc_transaction_success_o;                           // 内部转发：完成结果处理资格
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] ami_adc_complete_sample_index_o; // 内部转发：完成身份序号
	wire ami_calibration_sample_valid_o;                          // 内部转发：保持型SAR9校准请求
	wire ami_calibration_color_ir_o;                              // 内部转发：DCS颜色，AMB固定为0
	wire ami_calibration_precision_mode_o;                        // 内部转发：校准精度，必须为SAR9
	wire [1:0] ami_calibration_frame_type_o;                      // 内部转发：AMB_CAL或DCS_CAL（AMI_CALIBRATION_FRAME_TYPE）（测量集成来源校准类帧类类型类）
	wire [1:0] ami_calibration_request_reason_o;                  // 内部转发：启动搜索或周期重检
	wire ami_measurement_result_valid_o;                          // 内部转发：正式结果保持有效至消费
	wire signed [23:0] ami_coarse_ppg_value_o;                    // 内部转发：DC恢复后的粗PPG值
	wire signed [23:0] ami_fine_ppg_value_o;                      // 内部转发：DC恢复后的精细PPG值
	wire ami_coarse_valid_o;                                      // 内部转发：粗结果有效资格
	wire ami_coarse_recovery_calibrated_o;                        // 内部转发：粗结果正式恢复资格
	wire ami_coarse_saturation_low_o;                             // 内部转发：粗结果负向饱和诊断
	wire ami_coarse_saturation_high_o;                            // 内部转发：粗结果正向饱和诊断
	wire ami_fine_valid_o;                                        // 内部转发：精细结果有效资格
	wire ami_fine_recovery_calibrated_o;                          // 内部转发：精细结果正式恢复资格
	wire ami_fine_saturation_low_o;                               // 内部转发：精细结果负向饱和诊断
	wire ami_fine_saturation_high_o;                              // 内部转发：精细结果正向饱和诊断
	wire signed [11:0] ami_calibrated_s1_value_o;                 // 内部转发：正式Stage1校准残差
	wire signed [14:0] ami_programmable_15_code_o;                // 内部转发：正式可编程15-bit残差
	wire ami_programmable_15_valid_o;                             // 内部转发：可编程精细结果资格
	wire [C_CONFIG_EPOCH_WIDTH - 1:0] ami_result_config_epoch_o;  // 内部转发：本笔结果ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0] ami_result_coef_epoch_o;      // 内部转发：导出 o_coef_epoch
	wire [C_COEF_EPOCH_WIDTH - 1:0] ami_result_stage2_coef_epoch_o; // 内部转发：导出 o_stage2_result_coef_epoch（STAGE2）（二级）
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0] ami_result_dc_coef_epoch_o; // 内部转发：本笔结果DC恢复版本
	wire ami_result_precision_mode_o;                             // 内部转发：本笔结果精度快照
	wire ami_result_color_ir_o;                                   // 内部转发：本笔结果颜色身份
	wire [C_FRAME_ID_WIDTH - 1:0] ami_result_frame_id_o;          // 内部转发：本笔结果物理帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] ami_result_sample_index_o;  // 内部转发：本笔结果全局序号
	wire [1:0] ami_result_frame_type_o;                           // 内部转发：本笔结果NORMAL编码
	wire [7:0] ami_result_amb_code_snapshot_o;                    // 内部转发：本笔结果AMB码快照
	wire [7:0] ami_result_dc_code_snapshot_o;                     // 内部转发：本笔结果颜色DC码快照
	wire [C_CODE_EPOCH_WIDTH - 1:0] ami_result_amb_code_epoch_o;  // 内部转发：导出 o_result_amb_code_epoch（AMB_CODE）（环境光基线码值类）
	wire [C_CODE_EPOCH_WIDTH - 1:0] ami_result_dc_code_epoch_o;   // 内部转发：本笔结果颜色DC版本
	wire ami_mr_discard_event_o;                                  // 内部转发：正式结果生命周期丢弃单拍观测，合同6.10节公开端口
	wire ami_mr_discard_identity_valid_o;                         // 内部转发：事件为高时恒为1，绑定TXN_ID可信
	wire ami_mr_discard_sample_valid_o;                           // 内部转发：被丢弃正式结果的独立样本资格快照
	wire ami_mr_discard_color_ir_o;                               // 内部转发：被丢弃事务的颜色身份
	wire ami_mr_discard_precision_o;                              // 内部转发：被丢弃事务建立时所属的精度模式
	wire [1:0] ami_mr_discard_reason_o;                           // 内部转发：STOP、abort或系统故障三态丢弃原因，随事件保持稳定
	wire [1:0] ami_mr_discard_frame_type_o;                       // 内部转发：被丢弃事务的帧类型编码
	wire [C_FRAME_ID_WIDTH - 1:0] ami_mr_discard_frame_id_o;      // 内部转发：被丢弃事务的真实物理帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] ami_mr_discard_sample_index_o; // 内部转发：被丢弃事务的全局顺序编号
	wire [C_RUN_GENERATION_WIDTH - 1:0] ami_mr_discard_run_generation_o; // 内部转发：被丢弃事务所属的RUN代际
	wire [7:0] ami_amb_code_o;                                    // 内部转发：当前AMB committed码
	wire [7:0] ami_dcs_r_code_o;                                  // 内部转发：当前RED DC committed码（DCS_R）（直流搜索红光通道）
	wire [7:0] ami_dcs_ir_code_o;                                 // 内部转发：当前IR DC committed码（DCS_IR）（直流搜索红外通道）
	wire [C_CODE_EPOCH_WIDTH - 1:0] ami_amb_code_epoch_o;         // 内部转发：AMB码版本
	wire [C_CODE_EPOCH_WIDTH - 1:0] ami_dcs_r_code_epoch_o;       // 内部转发：RED DC码版本（DCS_R）（直流搜索红光通道）
	wire [C_CODE_EPOCH_WIDTH - 1:0] ami_dcs_ir_code_epoch_o;      // 内部转发：IR DC码版本（DCS_IR）（直流搜索红外通道）
	wire ami_idac_idle_o;                                         // 内部转发：AMI IDAC搜索和提交已经排空
	wire ami_active_precision_mode_o;                             // 内部转发：当前committed精度
	wire ami_s1_calibration_applied_o;                            // 内部转发：DC恢复自己原子事务载荷重新导出的Stage1校准资格，供P2S边界透传
	wire [9:0] ami_s1_raw_o;                                      // 内部转发：Stage1物理判决位，取自AMI自己重新导出的atomic payload_o，供P2S边界透传
	wire [9:0] ami_s2_raw_o;                                      // 内部转发：第二级冗余物理判决位，与ami_s1_raw_o锁在同一拍，同样供P2S边界透传
	wire ami_switch_hold_new_transaction_o;                       // 内部转发：精度切换期间暂停新事务
	wire ami_integration_protocol_error_sticky_o;                 // 内部转发：集成协议异常历史诊断
	wire ami_wrapper_fault_blocking_o;                            // 内部转发：AMI活动阻断故障
	wire ami_normal_measurement_eligible_o;                       // 内部转发：AMI允许NORMAL测量
	wire ami_datapath_empty_o;                                    // 内部转发：AMI保持型数据链已经排空
	wire ami_fault_valid_o;                                       // 内部转发：五路阻断故障分发器本拍产生一条注册记录
	wire ami_fault_active_o;                                      // 内部转发：五路lane-active按位或，仍有未解决阻断故障时为高
	wire ami_fault_identity_valid_o;                              // 内部转发：本条记录是否绑定真实事务身份
	wire ami_fault_color_ir_o;                                    // 内部转发：本条记录绑定事务的颜色身份
	wire ami_fault_precision_o;                                   // 内部转发：本条记录绑定事务建立时所属的精度模式
	wire [7:0] ami_fault_cause_o;                                 // 内部转发：本条记录锁定的故障来源编码，取值8'h01至8'h05
	wire [C_FRAME_ID_WIDTH - 1:0] ami_fault_frame_id_o;           // 内部转发：本条记录绑定事务的真实物理帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] ami_fault_sample_index_o;   // 内部转发：本条记录绑定事务的全局顺序编号
	wire [1:0] ami_fault_frame_type_o;                            // 内部转发：本条记录绑定事务的帧类型编码
	wire [C_RUN_GENERATION_WIDTH - 1:0] ami_fault_run_generation_o; // 内部转发：本条记录绑定事务所属的RUN代际
	wire ami_dd_event_o;                                          // 内部转发：检测代际清空广播的公开单拍观测，合同6.10节公开端口，与PWI私有输入同拍
	wire ami_dd_identity_valid_o;                                 // 内部转发：触发广播时是否命中真实保留检测分支事务
	wire ami_dd_sample_valid_o;                                   // 内部转发：触发事务的独立样本资格快照
	wire ami_dd_color_ir_o;                                       // 内部转发：触发事务的颜色身份
	wire ami_dd_precision_o;                                      // 内部转发：触发事务建立时所属的精度模式
	wire [1:0] ami_dd_reason_o;                                   // 内部转发：STOP、abort或系统故障三态原因编码，与私有广播共用同一来源
	wire [1:0] ami_dd_frame_type_o;                               // 内部转发：触发事务的帧类型编码
	wire [C_FRAME_ID_WIDTH - 1:0] ami_dd_frame_id_o;              // 内部转发：触发事务的真实物理帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] ami_dd_sample_index_o;      // 内部转发：触发事务的全局顺序编号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0] ami_dd_config_epoch_o;      // 内部转发：触发事务ACTIVE配置版本
	wire [C_COEF_EPOCH_WIDTH - 1:0] ami_dd_coef_epoch_o;          // 内部转发：触发事务Stage1系数版本
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0] ami_dd_dc_recovery_epoch_o; // 内部转发：触发事务DC恢复版本
	wire [C_CODE_EPOCH_WIDTH - 1:0] ami_dd_amb_code_epoch_o;      // 内部转发：触发事务环境光抵消码提交版本
	wire [C_CODE_EPOCH_WIDTH - 1:0] ami_dd_dc_code_epoch_o;       // 内部转发：触发事务颜色DC码提交版本
	wire [C_RUN_GENERATION_WIDTH - 1:0] ami_dd_run_generation_o;  // 内部转发：触发广播目标的RUN代际
	wire ami_test_identity_inject_ready_o;                        // 内部转发：AMI可原子绑定错误身份请求到当前owner
	wire ami_test_invalid_sample_ready_o;                         // 内部转发：AMI可原子绑定invalid请求到当前NORMAL结果
	wire ami_test_saturation_inject_ready_o;                      // 内部转发：IDAC控制器当前可原子绑定饱和注入请求
	wire ami_test_calibration_loss_inject_ready_o;                // 内部转发：粗检测FIR当前可原子绑定calibration-loss注入请求
	wire ami_result_sample_valid_o;                               // 内部转发：独立样本资格，invalid事务仍保留数值与身份
	wire sup_system_fault_discard_event_o;                        // 内部转发：supervisor产生的注册式故障episode丢弃选择器，外部abort不得驱动此端口
	wire sup_system_fault_cause_valid_o;                          // 内部转发：首个阻断故障原子快照是否已锁存
	wire sup_system_fault_identity_valid_o;                       // 内部转发：首故障绑定身份是否可信快照
	wire sup_system_fault_color_ir_o;                             // 内部转发：首故障绑定事务的颜色身份快照
	wire sup_system_fault_precision_o;                            // 内部转发：首故障绑定事务建立时所属的精度模式快照
	wire [7:0] sup_system_fault_cause_o;                          // 内部转发：首故障cause编码快照
	wire [3:0] sup_system_fault_source_o;                         // 内部转发：首故障来源编码快照
	wire [C_FRAME_ID_WIDTH - 1:0] sup_system_fault_frame_id_o;    // 内部转发：首故障绑定事务的真实物理帧号快照
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] sup_system_fault_sample_index_o; // 内部转发：首故障绑定事务的全局顺序编号快照
	wire [1:0] sup_system_fault_frame_type_o;                     // 内部转发：首故障绑定事务的帧类型编码快照
	wire [C_RUN_GENERATION_WIDTH - 1:0] sup_system_fault_run_generation_o; // 内部转发：首故障绑定事务所属的RUN代际快照
	wire [15:0] sup_system_fault_summary_o;                       // 内部转发：按位记录的历史阻断故障来源汇总
	wire sup_result_discard_summary_sticky_o;                     // 内部转发：正式结果生命周期丢弃历史sticky，非阻断


	//===================<ACTIVE wrapper接口内部网>===================//
	// wrapper_run_enable_o、wrapper_allow_new_transaction_o、wrapper_start_ack_event_o、wrapper_o_stop_ack_event已在上文提前声明

	// ACTIVE wrapper：V4+V5联合ACTIVE快照生命周期、manager与配置CDC唯一父级
	ppg_active_v4_control_plane_integration ppg_active_v4_control_plane_integration_Inst(
		.i_source_clk(i_source_clk),                              // 接ACTIVE平面.i_source_clk：source配置时钟
		.i_source_rstn(i_source_rstn),                            // 接ACTIVE平面.i_source_rstn：source域低有效复位
		.i_source_config_snapshot(i_source_config_snapshot),      // 接ACTIVE平面.i_source_config_snapshot：source域完整V4+V5联合shadow快照
		.i_source_config_update_event(i_source_config_update_event), // 接ACTIVE平面.i_source_config_update_event：source域请求传输快照的单周期事件
		.i_clk(i_clk),                                            // 接ACTIVE平面.i_clk：2 MHz系统控制时钟
		.i_rstn(i_rstn),                                          // 接ACTIVE平面.i_rstn：控制域低有效复位，撤销生命周期状态
		.i_start_event(i_start_event),                            // 接ACTIVE平面.i_start_event：已同步START事件
		.i_stop_event(flag_stop_request_event),                   // 接ACTIVE平面.i_stop_event：请求停止并进入排空流程的同步事件
		.i_status_clear_event(flag_status_clear_event),           // 接ACTIVE平面.i_status_clear_event：已同步sticky清除事件
		.i_analog_ready(i_analog_ready),                          // 接ACTIVE平面.i_analog_ready：模拟偏置和参考具备启动资格
		.i_adc_idle(flag_adc_physical_idle),                      // 接ACTIVE平面.i_adc_idle：物理ADC和DONE捕获链已经排空
		.i_datapath_empty(ami_datapath_empty_o),                  // 接ACTIVE平面.i_datapath_empty：AMI保持型数据链已经排空
		.i_idac_idle(ami_idac_idle_o),                            // 接ACTIVE平面.i_idac_idle：AMI IDAC搜索和提交已经排空
		.i_analog_safe(ssw_analog_safe_o),                        // 接ACTIVE平面.i_analog_safe：模拟控制已经回到安全保持状态
		.i_system_fault_blocking(flag_system_fault_blocking),     // 接ACTIVE平面.i_system_fault_blocking：supervisor经Top送达的注册系统阻断故障电平，只透明送manager并阻断START
		.i_static_characterization_enable(flag_static_characterization_enable), // 接ACTIVE平面.i_static_characterization_enable：顶层唯一2 MHz已提交STATIC_BIAS资格电平，直连manager
		.o_config_transport_busy(wrapper_config_transport_busy_o), // 接ACTIVE平面.o_config_transport_busy：source快照CDC事务仍在途
		.o_config_transport_update(wrapper_config_transport_update_o), // 接ACTIVE平面.o_config_transport_update：destination域已收到完整快照的单周期事件
		.o_active_config(wrapper_active_config_o),                // 接ACTIVE平面.o_active_config：manager合法提交并保持的V4+V5联合ACTIVE快照
		.o_active_valid(wrapper_active_valid_o),                  // 接ACTIVE平面.o_active_valid：ACTIVE具备本轮启动资格
		.o_config_epoch(wrapper_config_epoch_o),                  // 接ACTIVE平面.o_config_epoch：完整配置版本
		.o_coef_epoch(wrapper_coef_epoch_o),                      // 接ACTIVE平面.o_coef_epoch：Stage1系数版本
		.o_stage2_coef_epoch(wrapper_stage2_coef_epoch_o),        // 接ACTIVE平面.o_stage2_coef_epoch：Stage2增益和偏置字段的独立版本
		.o_dc_recovery_coef_epoch(wrapper_dc_recovery_coef_epoch_o), // 接ACTIVE平面.o_dc_recovery_coef_epoch：DC恢复系数版本
		.o_lifecycle_state(wrapper_lifecycle_state_o),            // 接ACTIVE平面.o_lifecycle_state：CONFIG、READY、RUN或STOPPING
		.o_start_ready(wrapper_start_ready_o),                    // 接ACTIVE平面.o_start_ready：READY且所有启动资格满足
		.o_run_enable(wrapper_run_enable_o),                      // 接ACTIVE平面.o_run_enable：RUN功能链许可
		.o_allow_new_transaction(wrapper_allow_new_transaction_o), // 接ACTIVE平面.o_allow_new_transaction：新ADC事务发起许可
		.o_run_generation(flag_run_generation),                   // 接ACTIVE平面.o_run_generation：manager唯一产生的代际，Wrapper仅逐位转发
		.o_stop_episode_active(flag_stop_episode_active),         // 接ACTIVE平面.o_stop_episode_active：manager唯一产生的排空episode电平，Wrapper仅逐位转发
		.o_commit_ack_event(wrapper_commit_ack_event_o),          // 接ACTIVE平面.o_commit_ack_event：合法配置成为ACTIVE的单周期应答
		.o_start_ack_event(wrapper_start_ack_event_o),            // 接ACTIVE平面.o_start_ack_event：START合法接受的单周期应答
		.o_stop_ack_event(wrapper_stop_ack_event_o),              // 接ACTIVE平面.o_stop_ack_event：STOP接受或幂等处理的单周期应答
		.o_error_event(wrapper_error_event_o),                    // 接ACTIVE平面.o_error_event：当前配置或命令被拒绝的单周期事件
		.o_commit_ack_sticky(wrapper_commit_ack_sticky_o),        // 接ACTIVE平面.o_commit_ack_sticky：配置成功sticky状态
		.o_error_sticky(wrapper_error_sticky_o),                  // 接ACTIVE平面.o_error_sticky：错误汇总sticky状态
		.o_last_error_code(wrapper_last_error_code_o),            // 接ACTIVE平面.o_last_error_code：最近一次错误分类码
		.o_schema_version(wrapper_schema_version_o),              // 接ACTIVE平面.o_schema_version：V4快照格式版本
		.o_run_profile(wrapper_run_profile_o),                    // 接ACTIVE平面.o_run_profile：NORMAL或CHARACTERIZATION档位
		.o_input_source(wrapper_input_source_o),                  // 接ACTIVE平面.o_input_source：光电二极管或外部测试输入
		.o_idac_mode(wrapper_idac_mode_o),                        // 接ACTIVE平面.o_idac_mode：MANUAL、SEARCH_HOLD或SEARCH_TRACK（IDAC_MODE）（电流数模类模式类）
		.o_optical_mode(wrapper_optical_mode_o),                  // 接ACTIVE平面.o_optical_mode：双光、RED、IR或安全关闭
		.o_initial_precision(wrapper_initial_precision_o),        // 接ACTIVE平面.o_initial_precision：RUN初始SAR精度
		.o_amb_enable(wrapper_amb_enable_o),                      // 接ACTIVE平面.o_amb_enable：AMB控制参与资格
		.o_dcs_enable(wrapper_dcs_enable_o),                      // 接ACTIVE平面.o_dcs_enable：红光和红外DC码搜索功能使能
		.o_amb_polarity(wrapper_amb_polarity_o),                  // 接ACTIVE平面.o_amb_polarity：AMB调码极性
		.o_dcs_polarity(wrapper_dcs_polarity_o),                  // 接ACTIVE平面.o_dcs_polarity：DC搜索时数字码的递增方向
		.o_stage1_calibration_valid(wrapper_stage1_calibration_valid_o), // 接ACTIVE平面.o_stage1_calibration_valid：Stage1系数有效标志
		.o_stage2_calibration_valid(wrapper_stage2_calibration_valid_o), // 接ACTIVE平面.o_stage2_calibration_valid：Stage2恢复计算参数已表征的标志
		.o_dc9_recovery_valid(wrapper_dc9_recovery_valid_o),      // 接ACTIVE平面.o_dc9_recovery_valid：SAR9 DC恢复有效标志
		.o_dc15_recovery_valid(wrapper_dc15_recovery_valid_o),    // 接ACTIVE平面.o_dc15_recovery_valid：SAR15精度链DC恢复数据可采用标志
		.o_amb_manual_code(wrapper_amb_manual_code_o),            // 接ACTIVE平面.o_amb_manual_code：AMB初始或手动码
		.o_amb_code_min(wrapper_amb_code_min_o),                  // 接ACTIVE平面.o_amb_code_min：AMB最小提交码
		.o_amb_code_max(wrapper_amb_code_max_o),                  // 接ACTIVE平面.o_amb_code_max：AMB最大提交码
		.o_dcs_r_manual_code(wrapper_dcs_r_manual_code_o),        // 接ACTIVE平面.o_dcs_r_manual_code：红光DC初始或手动码
		.o_dcs_r_code_min(wrapper_dcs_r_code_min_o),              // 接ACTIVE平面.o_dcs_r_code_min：红光DC最小提交码
		.o_dcs_r_code_max(wrapper_dcs_r_code_max_o),              // 接ACTIVE平面.o_dcs_r_code_max：红光DC最大提交码
		.o_dcs_ir_manual_code(wrapper_dcs_ir_manual_code_o),      // 接ACTIVE平面.o_dcs_ir_manual_code：红外DC初始或手动码
		.o_dcs_ir_code_min(wrapper_dcs_ir_code_min_o),            // 接ACTIVE平面.o_dcs_ir_code_min：红外DC最小提交码
		.o_dcs_ir_code_max(wrapper_dcs_ir_code_max_o),            // 接ACTIVE平面.o_dcs_ir_code_max：红外DC最大提交码
		.o_amb_threshold_low(wrapper_amb_threshold_low_o),        // 接ACTIVE平面.o_amb_threshold_low：AMB低阈值
		.o_amb_threshold_high(wrapper_amb_threshold_high_o),      // 接ACTIVE平面.o_amb_threshold_high：AMB高阈值
		.o_dcs_threshold_low(wrapper_dcs_threshold_low_o),        // 接ACTIVE平面.o_dcs_threshold_low：DCS低阈值（DCS）（直流搜索）
		.o_dcs_threshold_high(wrapper_dcs_threshold_high_o),      // 接ACTIVE平面.o_dcs_threshold_high：DCS高阈值（DCS）（直流搜索）
		.o_amb_confirm_count(cnt_wrapper_amb_confirm_count_o),    // 接ACTIVE平面.o_amb_confirm_count：AMB连续确认次数
		.o_dcs_confirm_count(cnt_wrapper_dcs_confirm_count_o),    // 接ACTIVE平面.o_dcs_confirm_count：红光和红外DC候选码的收敛确认次数
		.o_stage1_weight_q16_0(wrapper_stage1_weight_q16_0_o),    // 接ACTIVE平面.o_stage1_weight_q16_0：Stage1权重0
		.o_stage1_weight_q16_1(wrapper_stage1_weight_q16_1_o),    // 接ACTIVE平面.o_stage1_weight_q16_1：Stage1权重1（一号）
		.o_stage1_weight_q16_2(wrapper_stage1_weight_q16_2_o),    // 接ACTIVE平面.o_stage1_weight_q16_2：Stage1权重2（二号）
		.o_stage1_weight_q16_3(wrapper_stage1_weight_q16_3_o),    // 接ACTIVE平面.o_stage1_weight_q16_3：Stage1权重3（三号）
		.o_stage1_weight_q16_4(wrapper_stage1_weight_q16_4_o),    // 接ACTIVE平面.o_stage1_weight_q16_4：Stage1权重4（四号）
		.o_stage1_weight_q16_5(wrapper_stage1_weight_q16_5_o),    // 接ACTIVE平面.o_stage1_weight_q16_5：Stage1权重5（五号）
		.o_stage1_weight_q16_6(wrapper_stage1_weight_q16_6_o),    // 接ACTIVE平面.o_stage1_weight_q16_6：Stage1权重6（六号）
		.o_stage1_weight_q16_7(wrapper_stage1_weight_q16_7_o),    // 接ACTIVE平面.o_stage1_weight_q16_7：Stage1权重7（七号）
		.o_stage1_weight_q16_8(wrapper_stage1_weight_q16_8_o),    // 接ACTIVE平面.o_stage1_weight_q16_8：Stage1权重8（八号）
		.o_stage1_weight_q16_9(wrapper_stage1_weight_q16_9_o),    // 接ACTIVE平面.o_stage1_weight_q16_9：Stage1权重9（九号）
		.o_stage1_offset_q16(wrapper_stage1_offset_q16_o),        // 接ACTIVE平面.o_stage1_offset_q16：Stage1加性offset
		.o_stage2_gain_q16(wrapper_stage2_gain_q16_o),            // 接ACTIVE平面.o_stage2_gain_q16：Stage2统一增益
		.o_stage2_offset_q16(wrapper_stage2_offset_q16_o),        // 接ACTIVE平面.o_stage2_offset_q16：Stage2加性offset（STAGE2）（二级）
		.o_dc9_recovery_gain_q16(wrapper_dc9_recovery_gain_q16_o), // 接ACTIVE平面.o_dc9_recovery_gain_q16：SAR9 DC恢复增益
		.o_dc15_recovery_gain_q16(wrapper_dc15_recovery_gain_q16_o), // 接ACTIVE平面.o_dc15_recovery_gain_q16：SAR15精度域DC恢复使用的Q16增益
		.o_amb_recheck_interval_frames(wrapper_amb_recheck_interval_frames_o), // 接ACTIVE平面.o_amb_recheck_interval_frames：NORMAL完整帧重检间隔
		.o_slope_mode(wrapper_slope_mode_o),                      // 接ACTIVE平面.o_slope_mode：基线斜率固定或自适应模式
		.o_fixed_slope_q16(wrapper_fixed_slope_q16_o),            // 接ACTIVE平面.o_fixed_slope_q16：固定负斜率的signed Q16值
		.o_alpha_q15(wrapper_alpha_q15_o),                        // 接ACTIVE平面.o_alpha_q15：基础斜率幅度比例
		.o_beta_q15(wrapper_beta_q15_o),                          // 接ACTIVE平面.o_beta_q15：活动斜率平滑比例
		.o_timing_adjust_ratio_q15(wrapper_timing_adjust_ratio_q15_o), // 接ACTIVE平面.o_timing_adjust_ratio_q15：相交时刻修正比例
		.o_slope_min_q16(wrapper_slope_min_q16_o),                // 接ACTIVE平面.o_slope_min_q16：最负斜率边界
		.o_slope_max_q16(wrapper_slope_max_q16_o),                // 接ACTIVE平面.o_slope_max_q16：最接近零斜率边界
		.o_baseline_delta_q16(wrapper_baseline_delta_q16_o),      // 接ACTIVE平面.o_baseline_delta_q16：波峰锚点基线偏置
		.o_cross_hysteresis_q16(wrapper_cross_hysteresis_q16_o),  // 接ACTIVE平面.o_cross_hysteresis_q16：向上相交迟滞量
		.o_lead_min_frames(wrapper_lead_min_frames_o),            // 接ACTIVE平面.o_lead_min_frames：相交提前量合格下界
		.o_lead_max_frames(wrapper_lead_max_frames_o),            // 接ACTIVE平面.o_lead_max_frames：相交提前量合格上界
		.o_cross_confirm_count(cnt_wrapper_cross_confirm_count_o), // 接ACTIVE平面.o_cross_confirm_count：相交连续确认点数
		.o_no_cross_limit(wrapper_no_cross_limit_o),              // 接ACTIVE平面.o_no_cross_limit：连续无相交重新获取阈值
		.o_peak_confirm_count(cnt_wrapper_peak_confirm_count_o),  // 接ACTIVE平面.o_peak_confirm_count：波峰连续下降确认点数
		.o_valley_confirm_count(cnt_wrapper_valley_confirm_count_o), // 接ACTIVE平面.o_valley_confirm_count：波谷连续上升确认点数
		.o_direction_deadband(wrapper_direction_deadband_o),      // 接ACTIVE平面.o_direction_deadband：相邻FIR方向分类死区
		.o_min_peak_valley_amplitude(wrapper_min_peak_valley_amplitude_o), // 接ACTIVE平面.o_min_peak_valley_amplitude：合格峰谷最小幅度
		.o_min_peak_to_valley_frames(wrapper_min_peak_to_valley_frames_o), // 接ACTIVE平面.o_min_peak_to_valley_frames：波峰到波谷最小帧差
		.o_min_peak_to_peak_frames(wrapper_min_peak_to_peak_frames_o), // 接ACTIVE平面.o_min_peak_to_peak_frames：相邻波峰最小帧差
		.o_max_fine_window_frames(wrapper_max_fine_window_frames_o), // 接ACTIVE平面.o_max_fine_window_frames：15-bit窗口最大持续帧数
		.o_max_reacquire_frames(wrapper_max_reacquire_frames_o),  // 接ACTIVE平面.o_max_reacquire_frames：9-bit重新获取最大帧数
		.o_peak_valley_config_valid(wrapper_peak_valley_config_valid_o) // 接ACTIVE平面.o_peak_valley_config_valid：正式peak/valley/cross/fine-window资格位
	);

	//===================<表征控制CDC接口内部网>===================//

	// 表征控制CDC：6-bit表征控制快照与STATIC_BIAS使能的独立原子跨域提交
	ppg_characterization_control_cdc ppg_characterization_control_cdc_Inst(
		.i_source_clk(i_source_clk),                              // 接表征CDC.i_source_clk：SPI配置源时钟，仅驱动source握手状态
		.i_source_rstn(i_source_rstn),                            // 接表征CDC.i_source_rstn：SPI源域低有效复位，和系统复位共同断言
		.i_clk(i_clk),                                            // 接表征CDC.i_clk：2 MHz目标域时钟，提交表征控制快照
		.i_rstn(i_rstn),                                          // 接表征CDC.i_rstn：2 MHz目标域低有效复位，清除已提交控制
		.i_source_update_valid(i_source_characterization_update_valid), // 接表征CDC.i_source_update_valid：保持型source更新请求，直到握手接受
		.i_source_static_characterization_enable(i_source_static_characterization_enable), // 接表征CDC.i_source_static_characterization_enable：待传输的STATIC_BIAS模式使能bit
		.i_source_test_mux_ctrl(i_source_test_mux_ctrl),          // 接表征CDC.i_source_test_mux_ctrl：待传输的五位模拟测试MUX选择码
		.i_run_enable(wrapper_run_enable_o),                      // 接表征CDC.i_run_enable：V4控制平面RUN资格，用于冻结模式使能
		.i_diag_clear_event(flag_diag_clear_event),               // 接表征CDC.i_diag_clear_event：系统域诊断清除脉冲，只影响sticky状态
		.o_source_update_ready(ccc_source_update_ready_o),        // 接表征CDC.o_source_update_ready：CDC邮箱可接收下一笔source快照的资格
		.o_static_characterization_enable(flag_static_characterization_enable), // 接表征CDC.o_static_characterization_enable：已提交的STATIC_BIAS模式控制值；唯一同源扇出至manager/SSW/许可拆分 @satisfies: TOP-19
		.o_test_mux_ctrl(ccc_test_mux_ctrl_o),                    // 接表征CDC.o_test_mux_ctrl：已提交的测试MUX控制值
		.o_control_valid(ccc_control_valid_o),                    // 接表征CDC.o_control_valid：复位后已经存在一笔合法提交控制
		.o_control_update_event(ccc_control_update_event_o),      // 接表征CDC.o_control_update_event：完整控制快照被目标域接受的单拍事件
		.o_control_reject_event(ccc_control_reject_event_o),      // 接表征CDC.o_control_reject_event：运行期非法快照被整体拒绝的单拍事件
		.o_protocol_error_sticky(ccc_protocol_error_sticky_o)     // 接表征CDC.o_protocol_error_sticky：记录运行期模式变更违反合同的sticky诊断
	);

	//===================<400 Hz帧调度器接口内部网>===================//

	// 400 Hz帧调度器：唯一400 Hz/625-tick物理相位与ADC owner截止所有者
	ppg_400hz_frame_calibration_scheduler
		#(
			.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),                  // 调度器帧号计数与owner身份共用此位宽
			.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH),          // 调度器ADC事务序号递增计数共用此位宽
			.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH),              // 调度器锁存AMB/DC码版本时使用此位宽
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH)       // 调度器owner原子锁存代际比对使用此位宽
		)
		ppg_400hz_frame_calibration_scheduler_Inst(
			.i_clk(i_clk),                                        // 接帧调度器.i_clk：2 MHz数字主时钟
			.i_rstn(i_rstn),                                      // 接帧调度器.i_rstn：低有效异步复位
			.i_active_config_valid(wrapper_active_valid_o),       // 接帧调度器.i_active_config_valid：ACTIVE配置整体合法
			.i_run_enable(measurement_run_enable),                // 接帧调度器.i_run_enable：当前处于RUN生命周期
			.i_allow_new_transaction(measurement_allow_new_transaction), // 接帧调度器.i_allow_new_transaction：配置管理器允许新ADC事务
			.i_start_ack_event(flag_measurement_start_ack_event), // 接帧调度器.i_start_ack_event：新RUN开始单拍
			.i_stop_ack_event(wrapper_stop_ack_event_o),          // 接帧调度器.i_stop_ack_event：STOP进入排空单拍
			.i_control_abort_event(flag_owner_abort_event),       // 接帧调度器.i_control_abort_event：abort撤销控制单拍
			.i_diag_clear_event(flag_diag_clear_event),           // 接帧调度器.i_diag_clear_event：清除历史诊断单拍
			.i_run_generation(flag_run_generation),               // 接帧调度器.i_run_generation：manager经ACTIVE wrapper与Top扇出的当前RUN代际，陈旧代际不得匹配、释放或重绑owner
			.i_run_profile(wrapper_run_profile_o),                // 接帧调度器.i_run_profile：NORMAL或CHARACTERIZATION
			.i_input_source(wrapper_input_source_o),              // 接帧调度器.i_input_source：光电二极管或固定电流来源
			.i_optical_mode(wrapper_optical_mode_o),              // 接帧调度器.i_optical_mode：双光、单光或安全关闭
			.i_active_precision_mode(ami_active_precision_mode_o), // 接帧调度器.i_active_precision_mode：当前committed精度
			.i_normal_measurement_eligible(ami_normal_measurement_eligible_o), // 接帧调度器.i_normal_measurement_eligible：AMI允许NORMAL测量
			.i_switch_hold_new_transaction(ami_switch_hold_new_transaction_o), // 接帧调度器.i_switch_hold_new_transaction：精度切换期间暂停新事务
			.i_ami_fault_blocking(ami_wrapper_fault_blocking_o),  // 接帧调度器.i_ami_fault_blocking：AMI活动阻断故障
			.i_ssw_fault_blocking(ssw_wrapper_fault_blocking_o),  // 接帧调度器.i_ssw_fault_blocking：SSW波形保持或模拟时序路径报告的阻断故障
			.i_amb_code(ami_amb_code_o),                          // 接帧调度器.i_amb_code：当前AMB committed码
			.i_dcs_r_code(ami_dcs_r_code_o),                      // 接帧调度器.i_dcs_r_code：当前RED DC committed码（DCS_R）（直流搜索红光通道）
			.i_dcs_ir_code(ami_dcs_ir_code_o),                    // 接帧调度器.i_dcs_ir_code：当前IR DC committed码（DCS_IR）（直流搜索红外通道）
			.i_amb_code_epoch(ami_amb_code_epoch_o),              // 接帧调度器.i_amb_code_epoch：AMB码版本
			.i_dcs_r_code_epoch(ami_dcs_r_code_epoch_o),          // 接帧调度器.i_dcs_r_code_epoch：RED DC码版本（DCS_R）（直流搜索红光通道）
			.i_dcs_ir_code_epoch(ami_dcs_ir_code_epoch_o),        // 接帧调度器.i_dcs_ir_code_epoch：IR DC码版本（DCS_IR）（直流搜索红外通道）
			.i_leddac_r_code(C_LEDDAC_R_CODE),                    // 接帧调度器.i_leddac_r_code：已提交RED LEDDAC码，固定8-bit物理LED驱动码，与AMB/DC的C_IDAC_CODE_WIDTH无关
			.i_leddac_ir_code(C_LEDDAC_IR_CODE),                  // 接帧调度器.i_leddac_ir_code：固定给IR光学时隙的已提交LED RDAC数字码，固定8-bit物理LED驱动码
			.i_calibration_sample_valid(ami_calibration_sample_valid_o), // 接帧调度器.i_calibration_sample_valid：保持型SAR9校准请求
			.o_calibration_sample_ready(sched_calibration_sample_ready_o), // 接帧调度器.o_calibration_sample_ready：调度器接受请求握手
			.i_calibration_frame_type(ami_calibration_frame_type_o), // 接帧调度器.i_calibration_frame_type：AMB_CAL或DCS_CAL（CALIBRATION_FRAME_TYPE）（校准类帧类类型类）
			.i_calibration_color_ir(ami_calibration_color_ir_o),  // 接帧调度器.i_calibration_color_ir：DCS颜色，AMB固定为0
			.i_calibration_precision_mode(ami_calibration_precision_mode_o), // 接帧调度器.i_calibration_precision_mode：校准精度，必须为SAR9
			.i_calibration_request_reason(ami_calibration_request_reason_o), // 接帧调度器.i_calibration_request_reason：启动搜索或周期重检
			.o_waveform_context_valid(sched_waveform_context_valid_o), // 接帧调度器.o_waveform_context_valid：保持型模拟波形上下文有效
			.i_waveform_context_ready(ssw_waveform_context_ready_o), // 接帧调度器.i_waveform_context_ready：SSW固定相位接管ready
			.o_waveform_precision_mode(sched_waveform_precision_mode_o), // 接帧调度器.o_waveform_precision_mode：波形精度快照
			.o_waveform_frame_id(sched_waveform_frame_id_o),      // 接帧调度器.o_waveform_frame_id：波形物理帧号
			.o_waveform_color_ir(sched_waveform_color_ir_o),      // 接帧调度器.o_waveform_color_ir：波形颜色快照
			.o_waveform_frame_type(sched_waveform_frame_type_o),  // 接帧调度器.o_waveform_frame_type：波形事务类型
			.o_waveform_amb_code_snapshot(sched_waveform_amb_code_snapshot_o), // 接帧调度器.o_waveform_amb_code_snapshot：波形AMB码快照
			.o_waveform_dc_code_snapshot(sched_waveform_dc_code_snapshot_o), // 接帧调度器.o_waveform_dc_code_snapshot：波形颜色DC码快照（DC_CODE_SNAPSHOT）（直流码值类快照类）
			.o_waveform_amb_code_epoch(sched_waveform_amb_code_epoch_o), // 接帧调度器.o_waveform_amb_code_epoch：波形AMB版本
			.o_waveform_dc_code_epoch(sched_waveform_dc_code_epoch_o), // 接帧调度器.o_waveform_dc_code_epoch：波形颜色DC版本
			.o_waveform_input_source(sched_waveform_input_source_o), // 接帧调度器.o_waveform_input_source：波形输入来源快照
			.o_waveform_optical_mode(sched_waveform_optical_mode_o), // 接帧调度器.o_waveform_optical_mode：波形光学模式快照
			.o_waveform_leddac_code_snapshot(sched_waveform_leddac_code_snapshot_o), // 接帧调度器.o_waveform_leddac_code_snapshot：波形LEDDAC快照，固定8-bit物理LED驱动码，与AMB/DC的C_IDAC_CODE_WIDTH无关
			.o_transaction_start_valid(sched_transaction_start_valid_o), // 接帧调度器.o_transaction_start_valid：保持型ADC owner事务valid
			.i_transaction_start_ready(ami_transaction_start_ready_o), // 接帧调度器.i_transaction_start_ready：AMI可接收事务
			.i_transaction_start_fire(ami_transaction_start_fire_o), // 接帧调度器.i_transaction_start_fire：AMI返回的fire一致性旁带
			.o_transaction_precision_mode(sched_transaction_precision_mode_o), // 接帧调度器.o_transaction_precision_mode：ADC事务精度快照
			.o_transaction_frame_id(sched_transaction_frame_id_o), // 接帧调度器.o_transaction_frame_id：ADC事务帧号
			.o_transaction_sample_index(sched_transaction_sample_index_o), // 接帧调度器.o_transaction_sample_index：ADC事务序号
			.o_transaction_color_ir(sched_transaction_color_ir_o), // 接帧调度器.o_transaction_color_ir：ADC事务颜色
			.o_transaction_frame_type(sched_transaction_frame_type_o), // 接帧调度器.o_transaction_frame_type：ADC事务类型
			.o_transaction_amb_code_snapshot(sched_transaction_amb_code_snapshot_o), // 接帧调度器.o_transaction_amb_code_snapshot：ADC事务AMB码
			.o_transaction_dc_code_snapshot(sched_transaction_dc_code_snapshot_o), // 接帧调度器.o_transaction_dc_code_snapshot：ADC事务DC码（DC）（直流）
			.o_transaction_amb_code_epoch(sched_transaction_amb_code_epoch_o), // 接帧调度器.o_transaction_amb_code_epoch：ADC事务AMB版本
			.o_transaction_dc_code_epoch(sched_transaction_dc_code_epoch_o), // 接帧调度器.o_transaction_dc_code_epoch：与本ADC颜色槽DC码绑定的epoch快照
			.i_adc_owner_ready(ssw_adc_owner_ready_o),            // 接帧调度器.i_adc_owner_ready：SSW确认最早pending owner可提交
			.o_adc_owner_commit_event(sched_adc_owner_commit_event_o), // 接帧调度器.o_adc_owner_commit_event：与AMI fire同拍的owner提交
			.o_adc_owner_precision_mode(sched_adc_owner_precision_mode_o), // 接帧调度器.o_adc_owner_precision_mode：owner精度身份
			.o_adc_owner_frame_id(sched_adc_owner_frame_id_o),    // 接帧调度器.o_adc_owner_frame_id：owner帧号身份
			.o_adc_owner_color_ir(sched_adc_owner_color_ir_o),    // 接帧调度器.o_adc_owner_color_ir：owner颜色身份
			.o_adc_owner_frame_type(sched_adc_owner_frame_type_o), // 接帧调度器.o_adc_owner_frame_type：供SSW物理owner锁存的即将占用事务类别
			.o_adc_owner_amb_code_snapshot(sched_adc_owner_amb_code_snapshot_o), // 接帧调度器.o_adc_owner_amb_code_snapshot：owner AMB码
			.o_adc_owner_dc_code_snapshot(sched_adc_owner_dc_code_snapshot_o), // 接帧调度器.o_adc_owner_dc_code_snapshot：owner DC码（DC）（直流）
			.o_adc_owner_amb_code_epoch(sched_adc_owner_amb_code_epoch_o), // 接帧调度器.o_adc_owner_amb_code_epoch：owner AMB版本
			.o_adc_owner_dc_code_epoch(sched_adc_owner_dc_code_epoch_o), // 接帧调度器.o_adc_owner_dc_code_epoch：owner DC版本（DC）（直流）
			.o_adc_owner_sample_index(sched_adc_owner_sample_index_o), // 接帧调度器.o_adc_owner_sample_index：owner正式序号
			.i_adc_transaction_complete_event(ami_adc_transaction_complete_event_o), // 接帧调度器.i_adc_transaction_complete_event：真实ADC完成单拍
			.i_adc_transaction_success(ami_adc_transaction_success_o), // 接帧调度器.i_adc_transaction_success：完成结果处理资格
			.i_adc_complete_sample_index(ami_adc_complete_sample_index_o), // 接帧调度器.i_adc_complete_sample_index：完成身份序号
			.i_owner_q3_window_closed(ssw_owner_q3_window_closed_o), // 接帧调度器.i_owner_q3_window_closed：在途owner自身选定Q3窗口已关闭，早于此的DONE不得构成成功完成
			.i_adc_idle(flag_adc_physical_idle),                  // 接帧调度器.i_adc_idle：物理ADC和DONE已排空
			.i_analog_safe(ssw_analog_safe_o),                    // 接帧调度器.i_analog_safe：模拟输出允许停止或切换
			.i_sar_timing_idle(ssw_sar_timing_idle_o),            // 接帧调度器.i_sar_timing_idle：无在途SAR模拟相位
			.o_macro_frame_start_event(),                         // 接帧调度器.o_macro_frame_start_event：400 Hz宏帧起点单拍
			.o_macro_frame_safe_boundary(sched_macro_frame_safe_boundary_o), // 接帧调度器.o_macro_frame_safe_boundary：下一宏帧准备前安全边界
			.o_idac_code_safe_boundary(sched_idac_code_safe_boundary_o), // 接帧调度器.o_idac_code_safe_boundary：IDAC唯一提交边界
			.o_startup_idac_safe_boundary(),                      // 接帧调度器.o_startup_idac_safe_boundary：START后一次性IDAC边界
			.o_safe_frame_id(sched_safe_frame_id_o),              // 接帧调度器.o_safe_frame_id：下一400 Hz帧编号
			.o_macro_tick(sched_macro_tick_o),                    // 接帧调度器.o_macro_tick：当前宏帧相位
			.o_calibration_subframe_index(sched_calibration_subframe_index_o), // 接帧调度器.o_calibration_subframe_index：当前校准子周期编号
			.o_calibration_local_tick(sched_calibration_local_tick_o), // 接帧调度器.o_calibration_local_tick：校准局部相位
			.o_normal_frame_complete_event(sched_normal_frame_complete_event_o), // 接帧调度器.o_normal_frame_complete_event：NORMAL宏帧完成单拍
			.o_calibration_frame_complete_event(sched_calibration_frame_complete_event_o), // 接帧调度器.o_calibration_frame_complete_event：校准物理宏帧完成单拍
			.o_scheduler_idle(sched_idle_o),                      // 接帧调度器.o_scheduler_idle：数字事务和物理时序均排空
			.o_normal_frame_active(sched_normal_frame_active_o),  // 接帧调度器.o_normal_frame_active：当前执行NORMAL宏帧
			.o_calibration_frame_active(sched_calibration_frame_active_o), // 接帧调度器.o_calibration_frame_active：当前执行校准宏帧
			.o_transaction_inflight(),                            // 接帧调度器.o_transaction_inflight：当前存在已启动ADC owner
			.o_current_frame_id(),                                // 接帧调度器.o_current_frame_id：当前400 Hz帧编号
			.o_next_sample_index(),                               // 接帧调度器.o_next_sample_index：下一笔ADC序号
			.o_launch_timeout_sticky(sched_launch_timeout_sticky_o), // 接帧调度器.o_launch_timeout_sticky：波形接管错过诊断
			.o_owner_deadline_timeout_sticky(sched_owner_deadline_timeout_sticky_o), // 接帧调度器.o_owner_deadline_timeout_sticky：ADC owner截止错过诊断
			.o_cal_owner_deadline_event(sched_cal_owner_deadline_event_o), // 接帧调度器.o_cal_owner_deadline_event：校准owner截止单周期事件，供AMI据此重新发起同一候选的请求
			.o_completion_mismatch_sticky(sched_completion_mismatch_sticky_o), // 接帧调度器.o_completion_mismatch_sticky：DONE身份错配诊断
			.o_protocol_error_sticky(sched_protocol_error_sticky_o), // 接帧调度器.o_protocol_error_sticky：握手或编码协议诊断
			.o_scheduler_local_fault_blocking(),                  // 接帧调度器.o_scheduler_local_fault_blocking：仅调度器本地阻断汇总
			.o_scheduler_fault_valid(sched_fault_valid_o),        // 接帧调度器.o_scheduler_fault_valid：新故障episode单周期脉冲，供system fault/abort supervisor观测
			.o_scheduler_fault_active(sched_fault_active_o),      // 接帧调度器.o_scheduler_fault_active：注册式阻断持续状态，即scheduler_local_fault_blocking
			.o_scheduler_fault_cause(sched_fault_cause_o),        // 接帧调度器.o_scheduler_fault_cause：固定8'h11，不可恢复协议错误原因码
			.o_scheduler_fault_identity_valid(sched_fault_identity_valid_o), // 接帧调度器.o_scheduler_fault_identity_valid：本次故障是否绑定了真实owner身份
			.o_scheduler_fault_frame_id(sched_fault_frame_id_o),  // 接帧调度器.o_scheduler_fault_frame_id：故障owner所属400 Hz帧号
			.o_scheduler_fault_sample_index(sched_fault_sample_index_o), // 接帧调度器.o_scheduler_fault_sample_index：故障owner全局序号
			.o_scheduler_fault_color_ir(sched_fault_color_ir_o),  // 接帧调度器.o_scheduler_fault_color_ir：故障owner颜色
			.o_scheduler_fault_frame_type(sched_fault_frame_type_o), // 接帧调度器.o_scheduler_fault_frame_type：故障owner事务类型
			.o_scheduler_fault_precision_mode(sched_fault_precision_mode_o), // 接帧调度器.o_scheduler_fault_precision_mode：故障owner精度
			.o_scheduler_fault_run_generation(sched_fault_run_generation_o) // 接帧调度器.o_scheduler_fault_run_generation：故障owner所属RUN代际
		);

	//===================<SSW接口内部网>===================//

	// SSW：唯一模拟时序与控制向量输出者，RED/IR共享包络与单笔ADC owner仲裁
	ppg_sar9_sar15_safe_selection_wrapper
		#(
			.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),                  // SSW波形与物理owner身份锁存共用此位宽
			.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH),          // SSW物理owner序号身份比对共用此位宽
			.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH),              // SSW波形快照AMB/DC码版本比对共用此位宽
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH),      // SSW波形与物理owner代际校验共用此位宽
			.C_ENABLE_TEST_INJECTION(C_ENABLE_TEST_INJECTION)     // SSW验证接管反压注入结构生成开关，生产网表恒为0
		)
		ppg_sar9_sar15_safe_selection_wrapper_Inst(
			.i_clk(i_clk),                                        // 接SSW.i_clk：输入端输入时钟低位编码端
			.i_rstn(i_rstn),                                      // 接SSW.i_rstn：输入端输入低有效复位
			.i_run_enable(analog_run_enable),                     // 接SSW.i_run_enable：输入端输入运行使能低位编码端
			.i_start_ack_event(flag_analog_start_ack_event),      // 接SSW.i_start_ack_event：输入端输入启动确认事件
			.i_stop_ack_event(wrapper_stop_ack_event_o),          // 接SSW.i_stop_ack_event：输入端输入停止确认事件
			.i_control_abort_event(flag_owner_abort_event),       // 接SSW.i_control_abort_event：输入端输入控制字撤销事件低位编码端
			.i_diag_clear_event(flag_diag_clear_event),           // 接SSW.i_diag_clear_event：输入端输入诊断清除事件低位编码端
			.i_run_generation(flag_run_generation),               // 接SSW.i_run_generation：输入端输入manager经ACTIVE wrapper与Top扇出的当前RUN代际，陈旧代际不得释放owner或复活波形
			.i_macro_tick(sched_macro_tick_o),                    // 接SSW.i_macro_tick：输入端输入宏帧节拍
			.i_calibration_subframe_index(sched_calibration_subframe_index_o), // 接SSW.i_calibration_subframe_index：输入端输入校准专用字段序号低位编码端
			.i_calibration_local_tick(sched_calibration_local_tick_o), // 接SSW.i_calibration_local_tick：输入端输入校准专用字段节拍低位编码端
			.i_normal_frame_active(sched_normal_frame_active_o),  // 接SSW.i_normal_frame_active：输入端输入正常帧活动低位编码端
			.i_calibration_frame_active(sched_calibration_frame_active_o), // 接SSW.i_calibration_frame_active：输入端输入校准帧活动低位编码端
			.i_macro_frame_safe_boundary(sched_macro_frame_safe_boundary_o), // 接SSW.i_macro_frame_safe_boundary：输入端输入宏帧帧安全专用字段
			.i_idac_code_safe_boundary(sched_idac_code_safe_boundary_o), // 接SSW.i_idac_code_safe_boundary：输入端输入电流数模数字码安全专用字段
			.i_run_profile(wrapper_run_profile_o),                // 接SSW.i_run_profile：输入端输入运行配置档案低位编码端
			.i_input_source(wrapper_input_source_o),              // 接SSW.i_input_source：输入端输入输入来源
			.i_optical_mode(wrapper_optical_mode_o),              // 接SSW.i_optical_mode：输入端输入光学模式低位编码端
			.i_precision_mode_committed(ami_active_precision_mode_o), // 接SSW.i_precision_mode_committed：输入端输入精度模式已提交
			.i_static_characterization_enable(flag_static_characterization_enable), // 接SSW.i_static_characterization_enable：输入端输入静态偏置表征使能高位编码端低位编码端
			.i_test_mux_ctrl(ccc_test_mux_ctrl_o),                // 接SSW.i_test_mux_ctrl：输入端输入测试多路选择专用字段低位编码端
			.i_test_inject_enable(flag_test_inject_effective),    // 接SSW.i_test_inject_enable：只在显式验证构建中允许接管反压注入
			.i_context_handover_stall_request(i_context_handover_stall_request), // 接SSW.i_context_handover_stall_request：验证专用，合法压低context ready
			.i_waveform_context_valid(sched_waveform_context_valid_o), // 接SSW.i_waveform_context_valid：输入端输入波形上下文有效低位编码端
			.o_waveform_context_ready(ssw_waveform_context_ready_o), // 接SSW.o_waveform_context_ready：输出端输出波形上下文就绪
			.i_waveform_precision_mode(sched_waveform_precision_mode_o), // 接SSW.i_waveform_precision_mode：输入端输入波形精度模式
			.i_waveform_frame_id(sched_waveform_frame_id_o),      // 接SSW.i_waveform_frame_id：输入端输入波形帧标识
			.i_waveform_color_ir(sched_waveform_color_ir_o),      // 接SSW.i_waveform_color_ir：输入端输入波形颜色红外红外专属红外光路低位编码端
			.i_waveform_frame_type(sched_waveform_frame_type_o),  // 接SSW.i_waveform_frame_type：输入端输入波形帧类型
			.i_waveform_amb_code_snapshot(sched_waveform_amb_code_snapshot_o), // 接SSW.i_waveform_amb_code_snapshot：输入端输入波形环境数字码专用字段环境码通路高位编码端
			.i_waveform_dc_code_snapshot(sched_waveform_dc_code_snapshot_o), // 接SSW.i_waveform_dc_code_snapshot：输入端输入波形直流数字码专用字段直流码通路高位编码端
			.i_waveform_amb_code_epoch(sched_waveform_amb_code_epoch_o), // 接SSW.i_waveform_amb_code_epoch：输入端输入波形环境数字码版本环境码通路高位编码端
			.i_waveform_dc_code_epoch(sched_waveform_dc_code_epoch_o), // 接SSW.i_waveform_dc_code_epoch：输入端输入波形直流数字码版本直流码通路高位编码端
			.i_waveform_input_source(sched_waveform_input_source_o), // 接SSW.i_waveform_input_source：输入端输入波形输入来源
			.i_waveform_optical_mode(sched_waveform_optical_mode_o), // 接SSW.i_waveform_optical_mode：输入端输入波形光学模式低位编码端
			.i_waveform_leddac_code_snapshot(sched_waveform_leddac_code_snapshot_o), // 接SSW.i_waveform_leddac_code_snapshot：输入端输入波形发光数模数字码专用字段高位编码端低位编码端
			.o_adc_owner_ready(ssw_adc_owner_ready_o),            // 接SSW.o_adc_owner_ready：输出端输出模数转换结果所有权就绪直流码通路
			.i_adc_owner_commit_event(sched_adc_owner_commit_event_o), // 接SSW.i_adc_owner_commit_event：输入端输入模数转换结果所有权专用字段事件直流码通路
			.i_adc_owner_precision_mode(sched_adc_owner_precision_mode_o), // 接SSW.i_adc_owner_precision_mode：输入端输入模数转换结果所有权精度模式直流码通路
			.i_adc_owner_frame_id(sched_adc_owner_frame_id_o),    // 接SSW.i_adc_owner_frame_id：输入端输入模数转换结果所有权帧标识直流码通路
			.i_adc_owner_color_ir(sched_adc_owner_color_ir_o),    // 接SSW.i_adc_owner_color_ir：输入端输入模数转换结果所有权颜色红外红外专属红外光路直流码通路低位编码端
			.i_adc_owner_frame_type(sched_adc_owner_frame_type_o), // 接SSW.i_adc_owner_frame_type：输入端输入模数转换结果所有权帧类型直流码通路
			.i_adc_owner_amb_code_snapshot(sched_adc_owner_amb_code_snapshot_o), // 接SSW.i_adc_owner_amb_code_snapshot：输入端输入模数转换结果所有权环境数字码专用字段环境码通路直流码通路高位编码端
			.i_adc_owner_dc_code_snapshot(sched_adc_owner_dc_code_snapshot_o), // 接SSW.i_adc_owner_dc_code_snapshot：输入端输入模数转换结果所有权直流数字码专用字段直流码通路高位编码端
			.i_adc_owner_amb_code_epoch(sched_adc_owner_amb_code_epoch_o), // 接SSW.i_adc_owner_amb_code_epoch：输入端输入模数转换结果所有权环境数字码版本环境码通路直流码通路高位编码端
			.i_adc_owner_dc_code_epoch(sched_adc_owner_dc_code_epoch_o), // 接SSW.i_adc_owner_dc_code_epoch：输入端输入模数转换结果所有权直流数字码版本直流码通路高位编码端
			.i_adc_owner_sample_index(sched_adc_owner_sample_index_o), // 接SSW.i_adc_owner_sample_index：输入端输入模数转换结果所有权采样序号直流码通路低位编码端
			.i_adc_transaction_complete_event(ami_adc_transaction_complete_event_o), // 接SSW.i_adc_transaction_complete_event：输入端输入模数转换事务完成事件直流码通路低位编码端
			.i_adc_transaction_success(ami_adc_transaction_success_o), // 接SSW.i_adc_transaction_success：输入端输入模数转换事务成功直流码通路
			.i_adc_complete_sample_index(ami_adc_complete_sample_index_o), // 接SSW.i_adc_complete_sample_index：输入端输入模数转换完成采样序号直流码通路低位编码端
			.i_adc_idle(flag_adc_physical_idle),                  // 接SSW.i_adc_idle：输入端输入模数转换空闲直流码通路低位编码端
			.o_en_tia_low(ssw_en_tia_low_o),                      // 接SSW.o_en_tia_low：输出端输出使能跨阻放大低有效低位编码端
			.o_leddac(ssw_leddac_o),                              // 接SSW.o_leddac：输出端输出发光数模低位编码端
			.o_leden1_low(ssw_leden1_low_o),                      // 接SSW.o_leden1_low：输出端输出红光选择低有效低位编码端
			.o_leden2_low(ssw_leden2_low_o),                      // 接SSW.o_leden2_low：输出端输出红外选择低有效低位编码端红外灯选通道
			.o_en_test(ssw_en_test_o),                            // 接SSW.o_en_test：输出端输出使能测试
			.o_clk_buf_low(ssw_clk_buf_low_o),                    // 接SSW.o_clk_buf_low：输出端输出时钟缓冲低有效低位编码端
			.o_clk_iref_idac_low(ssw_clk_iref_idac_low_o),        // 接SSW.o_clk_iref_idac_low：输出端输出时钟参考电流电流数模低有效低位编码端
			.o_clk_9q1_low(ssw_clk_9q1_low_o),                    // 接SSW.o_clk_9q1_low：输出端输出时钟九位第一相位低有效低位编码端
			.o_clk_15q1_low(ssw_clk_15q1_low_o),                  // 接SSW.o_clk_15q1_low：输出端输出时钟十五位第一相位低有效低位编码端
			.o_clk_aferst_low(ssw_clk_aferst_low_o),              // 接SSW.o_clk_aferst_low：输出端输出时钟前端复位低有效低位编码端
			.o_clk_iref_idac_sar9_low(ssw_clk_iref_idac_sar9_low_o), // 接SSW.o_clk_iref_idac_sar9_low：输出端输出时钟参考电流电流数模九位转换低有效九位转换专用低位编码端
			.o_clk_iref_idac_sar15_low(ssw_clk_iref_idac_sar15_low_o), // 接SSW.o_clk_iref_idac_sar15_low：输出端输出时钟参考电流电流数模十五位转换低有效十五位转换专用低位编码端
			.o_clk_q2_low(ssw_clk_q2_low_o),                      // 接SSW.o_clk_q2_low：输出端输出时钟第二相位低有效低位编码端
			.o_clk_q3_low(ssw_clk_q3_low_o),                      // 接SSW.o_clk_q3_low：输出端输出时钟第三相位低有效低位编码端第三相位采样中心
			.o_clk_tiaen_low(ssw_clk_tiaen_low_o),                // 接SSW.o_clk_tiaen_low：输出端输出时钟专用字段低有效低位编码端
			.o_en_15sar_low(ssw_en_15sar_low_o),                  // 接SSW.o_en_15sar_low：输出端输出使能专用字段低有效低位编码端
			.o_en_sar9_amb_low(ssw_en_sar9_amb_low_o),            // 接SSW.o_en_sar9_amb_low：输出端输出使能九位转换环境低有效九位转换专用环境码通路低位编码端
			.o_en_sar9_dc_low(ssw_en_sar9_dc_low_o),              // 接SSW.o_en_sar9_dc_low：输出端输出使能九位转换直流低有效九位转换专用直流码通路低位编码端
			.o_en_sar9_iref(ssw_en_sar9_iref_o),                  // 接SSW.o_en_sar9_iref：输出端输出使能九位转换参考电流九位转换专用
			.o_en_sar15_amb_low(ssw_en_sar15_amb_low_o),          // 接SSW.o_en_sar15_amb_low：输出端输出使能十五位转换环境低有效十五位转换专用环境码通路低位编码端
			.o_en_sar15_dc_low(ssw_en_sar15_dc_low_o),            // 接SSW.o_en_sar15_dc_low：输出端输出使能十五位转换直流低有效十五位转换专用直流码通路低位编码端
			.o_en_sar15_iref(ssw_en_sar15_iref_o),                // 接SSW.o_en_sar15_iref：输出端输出使能十五位转换参考电流十五位转换专用
			.o_idac_sar9ambn_low(ssw_idac_sar9ambn_low_o),        // 接SSW.o_idac_sar9ambn_low：输出端输出电流数模九位环境总线低有效九位转换专用环境码通路低位编码端
			.o_idac_sar9dcn_low(ssw_idac_sar9dcn_low_o),          // 接SSW.o_idac_sar9dcn_low：输出端输出电流数模九位直流总线低有效九位转换专用直流码通路低位编码端
			.o_idac_sar15ambn_low(ssw_idac_sar15ambn_low_o),      // 接SSW.o_idac_sar15ambn_low：输出端输出电流数模十五位环境总线低有效红外专属红外光路十五位转换专用环境码通路低位编码端（）（专属标识一）
			.o_idac_sar15dcn_low(ssw_idac_sar15dcn_low_o),        // 接SSW.o_idac_sar15dcn_low：输出端输出电流数模十五位直流总线低有效红外专属红外光路十五位转换专用直流码通路低位编码端（）（专属标识一）
			.o_s_in(ssw_s_in_o),                                  // 接SSW.o_s_in：输出端输出观测选择专用字段
			.o_clk_2m(ssw_clk_2m_o),                              // 接SSW.o_clk_2m：输出端输出时钟二兆赫兹低位编码端
			.o_analog_safe(ssw_analog_safe_o),                    // 接SSW.o_analog_safe：输出端输出模拟安全低位编码端
			.o_sar_timing_idle(ssw_sar_timing_idle_o),            // 接SSW.o_sar_timing_idle：输出端输出专用字段时序空闲低位编码端
			.o_wrapper_idle(ssw_wrapper_idle_o),                  // 接SSW.o_wrapper_idle：输出端输出封装空闲低位编码端
			.o_precision_active(ssw_precision_active_o),          // 接SSW.o_precision_active：输出端输出精度活动
			.o_calibration_wave_active(ssw_calibration_wave_active_o), // 接SSW.o_calibration_wave_active：输出端输出校准专用字段活动低位编码端
			.o_adc_owner_inflight(ssw_adc_owner_inflight_o),      // 接SSW.o_adc_owner_inflight：输出端输出模数转换结果所有权在途直流码通路高位编码端低位编码端
			.o_owner_q3_window_closed(ssw_owner_q3_window_closed_o), // 接SSW.o_owner_q3_window_closed：输出端在途owner自身选定Q3窗口已关闭
			.o_switch_protocol_error_sticky(ssw_switch_protocol_error_sticky_o), // 接SSW.o_switch_protocol_error_sticky：输出端输出切换协议错误保持高位编码端低位编码端
			.o_transaction_mismatch_sticky(ssw_transaction_mismatch_sticky_o), // 接SSW.o_transaction_mismatch_sticky：输出端输出事务失配保持高位编码端
			.o_owner_deadline_timeout_sticky(ssw_owner_deadline_timeout_sticky_o), // 接SSW.o_owner_deadline_timeout_sticky：输出端输出结果所有权截止超时保持低位编码端
			.o_calibration_timeout_sticky(ssw_calibration_timeout_sticky_o), // 接SSW.o_calibration_timeout_sticky：输出端输出校准超时保持低位编码端
			.o_wrapper_fault_blocking(ssw_wrapper_fault_blocking_o), // 接SSW.o_wrapper_fault_blocking：输出端输出封装专用字段阻断低位编码端
			.o_ssw_fault_valid(ssw_fault_valid_o),                // 接SSW.o_ssw_fault_valid：输出端输出新故障episode单周期脉冲，供system fault/abort supervisor观测
			.o_ssw_fault_active(ssw_fault_active_o),              // 接SSW.o_ssw_fault_active：输出端输出注册式阻断持续状态，即wrapper_fault_blocking的本地根因部分
			.o_ssw_fault_cause(ssw_fault_cause_o),                // 接SSW.o_ssw_fault_cause：输出端输出固定8'h21，SSW身份/所有权协议错误原因码
			.o_ssw_fault_identity_valid(ssw_fault_identity_valid_o), // 接SSW.o_ssw_fault_identity_valid：输出端输出本次故障是否绑定了真实事务身份
			.o_ssw_fault_frame_id(ssw_fault_frame_id_o),          // 接SSW.o_ssw_fault_frame_id：输出端输出故障事务所属帧号
			.o_ssw_fault_sample_index(ssw_fault_sample_index_o),  // 接SSW.o_ssw_fault_sample_index：输出端输出故障事务全局序号
			.o_ssw_fault_color_ir(ssw_fault_color_ir_o),          // 接SSW.o_ssw_fault_color_ir：输出端输出故障事务颜色
			.o_ssw_fault_frame_type(ssw_fault_frame_type_o),      // 接SSW.o_ssw_fault_frame_type：输出端输出故障事务类型
			.o_ssw_fault_precision_mode(ssw_fault_precision_mode_o), // 接SSW.o_ssw_fault_precision_mode：输出端输出故障事务精度
			.o_ssw_fault_run_generation(ssw_fault_run_generation_o) // 接SSW.o_ssw_fault_run_generation：输出端输出故障事务所属RUN代际
		);

	//===================<AMI接口内部网>===================//

	// AMI：ADC捕获、IDAC搜索、精度窗口检测链与正式测量结果的唯一生产者
	ppg_adc_measurement_idac_integration
		#(
			.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),                  // AMI事务与结果帧号身份锁存共用此位宽
			.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH),          // AMI事务与结果序号身份锁存共用此位宽
			.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH),          // AMI结果携带的完整ACTIVE版本字段位宽
			.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH),              // AMI结果携带的Stage1/Stage2系数版本位宽
			.C_DC_RECOVERY_EPOCH_WIDTH(C_DC_RECOVERY_EPOCH_WIDTH), // AMI结果携带的DC恢复系数版本位宽
			.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH),              // AMI IDAC码安全提交版本比对位宽
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH),      // AMI owner与结果代际比对共用此位宽
			.C_ENABLE_TEST_INJECTION(C_ENABLE_TEST_INJECTION)     // AMI验证注入结构生成开关，生产网表恒为0
		)
		ppg_adc_measurement_idac_integration_Inst(
			.i_clk(i_clk),                                        // 接AMI.i_clk：2 MHz数字处理域工作时钟
			.i_rstn(i_rstn),                                      // 接AMI.i_rstn：低有效异步复位输入
			.i_active_config_valid(wrapper_active_valid_o),       // 接AMI.i_active_config_valid：当前ACTIVE配置整体合法资格
			.i_run_enable(measurement_run_enable),                // 接AMI.i_run_enable：当前生命周期处于RUN状态
			.i_allow_new_transaction(measurement_allow_new_transaction), // 接AMI.i_allow_new_transaction：配置管理器允许启动新ADC事务
			.i_start_ack_event(flag_measurement_start_ack_event), // 接AMI.i_start_ack_event：新RUN正式开始的单周期事件
			.i_stop_ack_event(wrapper_stop_ack_event_o),          // 接AMI.i_stop_ack_event：STOP进入排空的单周期事件
			.i_control_abort_event(flag_owner_abort_event),       // 接AMI.i_control_abort_event：阻断异常撤销在途控制的单周期事件
			.i_diag_clear_event(flag_diag_clear_event),           // 接AMI.i_diag_clear_event：软件清除sticky诊断的单周期事件
			.i_run_generation(flag_run_generation),               // 接AMI.i_run_generation：manager经ACTIVE wrapper与Top扇出的当前RUN代际，陈旧代际不得绑定新owner
			.i_system_fault_discard_event(sup_system_fault_discard_event_o), // 接AMI.i_system_fault_discard_event：supervisor产生的注册式故障episode丢弃选择器，外部abort不得驱动此端口
			.i_config_epoch(wrapper_config_epoch_o),              // 接AMI.i_config_epoch：当前完整ACTIVE配置版本
			.i_stage1_coef_epoch(wrapper_coef_epoch_o),           // 接AMI.i_stage1_coef_epoch：当前Stage1系数组版本
			.i_stage2_coef_epoch(wrapper_stage2_coef_epoch_o),    // 接AMI.i_stage2_coef_epoch：接收 i_stage2_coef_epoch
			.i_dc_recovery_coef_epoch(wrapper_dc_recovery_coef_epoch_o), // 接AMI.i_dc_recovery_coef_epoch：当前DC恢复系数组版本
			.i_transaction_start_valid(sched_transaction_start_valid_o), // 接AMI.i_transaction_start_valid：上层保持当前待启动事务有效
			.o_transaction_start_ready(ami_transaction_start_ready_o), // 接AMI.o_transaction_start_ready：Wrapper允许启动当前事务
			.o_transaction_start_fire(ami_transaction_start_fire_o), // 接AMI.o_transaction_start_fire：capture、S1和SAR共享的唯一启动单拍
			.o_adc_transaction_complete_event(ami_adc_transaction_complete_event_o), // 接AMI.o_adc_transaction_complete_event：CLK_DOUT同步、RAW锁存和S1归属后的唯一完成脉冲
			.o_adc_transaction_success(ami_adc_transaction_success_o), // 接AMI.o_adc_transaction_success：与完成脉冲绑定的ADC结果有效资格
			.o_adc_complete_sample_index(ami_adc_complete_sample_index_o), // 接AMI.o_adc_complete_sample_index：与完成脉冲绑定的启动事务序号
			.i_transaction_precision_mode(sched_transaction_precision_mode_o), // 接AMI.i_transaction_precision_mode：当前事务采用的9-bit或15-bit精度
			.i_transaction_frame_id(sched_transaction_frame_id_o), // 接AMI.i_transaction_frame_id：当前事务真实物理帧号
			.i_transaction_sample_index(sched_transaction_sample_index_o), // 接AMI.i_transaction_sample_index：当前事务全局序号
			.i_transaction_color_ir(sched_transaction_color_ir_o), // 接AMI.i_transaction_color_ir：低为红光且高为红外
			.i_transaction_frame_type(sched_transaction_frame_type_o), // 接AMI.i_transaction_frame_type：AMB_CAL、DCS_CAL或NORMAL编码
			.i_transaction_amb_code_snapshot(sched_transaction_amb_code_snapshot_o), // 接AMI.i_transaction_amb_code_snapshot：实际积分AMB码快照
			.i_transaction_dc_code_snapshot(sched_transaction_dc_code_snapshot_o), // 接AMI.i_transaction_dc_code_snapshot：实际积分颜色DC码快照
			.i_transaction_amb_code_epoch(sched_transaction_amb_code_epoch_o), // 接AMI.i_transaction_amb_code_epoch：AMB码提交版本快照
			.i_transaction_dc_code_epoch(sched_transaction_dc_code_epoch_o), // 接AMI.i_transaction_dc_code_epoch：当前颜色DC码版本快照
			.i_dout_stage1_low(i_dout_stage1_low),                // 接AMI.i_dout_stage1_low：Stage1物理判决码
			.i_clk_stage1_dout_low_async(i_clk_stage1_dout_low_async), // 接AMI.i_clk_stage1_dout_low_async：Stage1异步完成保持电平
			.i_dout_stage2_low(i_dout_stage2_low),                // 接AMI.i_dout_stage2_low：接收 i_dout_stage2_low
			.i_clk_stage2_dout_low_async(i_clk_stage2_dout_low_async), // 接AMI.i_clk_stage2_dout_low_async：接收 i_clk_stage2_dout_low_async
			.i_adc_idle(flag_adc_physical_idle),                  // 接AMI.i_adc_idle：模拟ADC当前已经排空
			.i_analog_safe(ssw_analog_safe_o),                    // 接AMI.i_analog_safe：模拟相位允许安全提交
			.i_macro_frame_safe_boundary(sched_macro_frame_safe_boundary_o), // 接AMI.i_macro_frame_safe_boundary：精度切换与重检使用的宏帧边界
			.i_idac_code_safe_boundary(sched_idac_code_safe_boundary_o), // 接AMI.i_idac_code_safe_boundary：IDAC pending码唯一提交边界
			.i_safe_frame_id(sched_safe_frame_id_o),              // 接AMI.i_safe_frame_id：即将启动帧的真实编号
			.i_normal_frame_complete_event(sched_normal_frame_complete_event_o), // 接AMI.i_normal_frame_complete_event：一帧完整NORMAL测量完成单拍
			.i_calibration_frame_complete_event(sched_calibration_frame_complete_event_o), // 接AMI.i_calibration_frame_complete_event：当前校准帧物理完成单拍
			.i_calibration_sample_ready(sched_calibration_sample_ready_o), // 接AMI.i_calibration_sample_ready：帧调度器接受当前SAR9校准请求
			.i_cal_owner_deadline_event(sched_cal_owner_deadline_event_o), // 接AMI.i_cal_owner_deadline_event：帧调度器校准owner截止单周期事件，在途请求被抑制后据此立即重新发起同一候选
			.o_calibration_sample_valid(ami_calibration_sample_valid_o), // 接AMI.o_calibration_sample_valid：启动搜索或周期重检保持型请求
			.o_calibration_frame_type(ami_calibration_frame_type_o), // 接AMI.o_calibration_frame_type：当前请求的AMB_CAL或DCS_CAL编码
			.o_calibration_color_ir(ami_calibration_color_ir_o),  // 接AMI.o_calibration_color_ir：当前DCS_CAL请求颜色
			.o_calibration_precision_mode(ami_calibration_precision_mode_o), // 接AMI.o_calibration_precision_mode：校准固定采用SAR9精度
			.o_calibration_request_reason(ami_calibration_request_reason_o), // 接AMI.o_calibration_request_reason：启动搜索或周期重检原因
			.o_calibration_request_fire(),                        // 接AMI.o_calibration_request_fire：校准请求真实握手单拍
			.i_measurement_result_ready(i_measurement_result_ready), // 接AMI.i_measurement_result_ready：片外FIFO接受正式结果
			.o_measurement_result_valid(ami_measurement_result_valid_o), // 接AMI.o_measurement_result_valid：正式结果保持有效至消费（）（专属标识一）
			.o_coarse_ppg_value(ami_coarse_ppg_value_o),          // 接AMI.o_coarse_ppg_value：DC恢复后的粗PPG值
			.o_coarse_valid(ami_coarse_valid_o),                  // 接AMI.o_coarse_valid：粗结果有效资格
			.o_coarse_recovery_calibrated(ami_coarse_recovery_calibrated_o), // 接AMI.o_coarse_recovery_calibrated：粗结果正式恢复资格（）（专属标识一）
			.o_coarse_saturation_low(ami_coarse_saturation_low_o), // 接AMI.o_coarse_saturation_low：粗结果负向饱和诊断（）（专属标识一）
			.o_coarse_saturation_high(ami_coarse_saturation_high_o), // 接AMI.o_coarse_saturation_high：粗结果正向饱和诊断（）（专属标识一）
			.o_fine_ppg_value(ami_fine_ppg_value_o),              // 接AMI.o_fine_ppg_value：DC恢复后的精细PPG值
			.o_fine_valid(ami_fine_valid_o),                      // 接AMI.o_fine_valid：精细结果有效资格（）（专属标识一）
			.o_fine_recovery_calibrated(ami_fine_recovery_calibrated_o), // 接AMI.o_fine_recovery_calibrated：精细结果正式恢复资格（）（专属标识一）
			.o_fine_saturation_low(ami_fine_saturation_low_o),    // 接AMI.o_fine_saturation_low：精细结果负向饱和诊断（）（专属标识一）
			.o_fine_saturation_high(ami_fine_saturation_high_o),  // 接AMI.o_fine_saturation_high：精细结果正向饱和诊断（）（专属标识一）
			.o_calibrated_s1_value(ami_calibrated_s1_value_o),    // 接AMI.o_calibrated_s1_value：正式Stage1校准残差
			.o_programmable_15_code(ami_programmable_15_code_o),  // 接AMI.o_programmable_15_code：正式可编程15-bit残差
			.o_programmable_15_valid(ami_programmable_15_valid_o), // 接AMI.o_programmable_15_valid：可编程精细结果资格（）（专属标识一）
			.o_config_epoch(ami_result_config_epoch_o),           // 接AMI.o_config_epoch：本笔结果ACTIVE版本
			.o_coef_epoch(ami_result_coef_epoch_o),               // 接AMI.o_coef_epoch：导出 o_coef_epoch
			.o_stage2_result_coef_epoch(ami_result_stage2_coef_epoch_o), // 接AMI.o_stage2_result_coef_epoch：导出 o_stage2_result_coef_epoch
			.o_dc_result_coef_epoch(ami_result_dc_coef_epoch_o),  // 接AMI.o_dc_result_coef_epoch：本笔结果DC恢复版本（）（专属标识一）
			.o_result_precision_mode(ami_result_precision_mode_o), // 接AMI.o_result_precision_mode：本笔结果精度快照（）（专属标识一）
			.o_result_frame_id(ami_result_frame_id_o),            // 接AMI.o_result_frame_id：本笔结果物理帧号（）（专属标识一）
			.o_result_sample_index(ami_result_sample_index_o),    // 接AMI.o_result_sample_index：本笔结果全局序号（）（专属标识一）
			.o_result_color_ir(ami_result_color_ir_o),            // 接AMI.o_result_color_ir：本笔结果颜色身份（）（专属标识一）
			.o_result_frame_type(ami_result_frame_type_o),        // 接AMI.o_result_frame_type：本笔结果NORMAL编码
			.o_result_amb_code_snapshot(ami_result_amb_code_snapshot_o), // 接AMI.o_result_amb_code_snapshot：本笔结果AMB码快照
			.o_result_dc_code_snapshot(ami_result_dc_code_snapshot_o), // 接AMI.o_result_dc_code_snapshot：本笔结果颜色DC码快照（）（专属标识一）
			.o_result_amb_code_epoch(ami_result_amb_code_epoch_o), // 接AMI.o_result_amb_code_epoch：导出 o_result_amb_code_epoch
			.o_result_dc_code_epoch(ami_result_dc_code_epoch_o),  // 接AMI.o_result_dc_code_epoch：本笔结果颜色DC版本
			.o_measurement_result_discard_event(ami_mr_discard_event_o), // 接AMI.o_measurement_result_discard_event：正式结果生命周期丢弃单拍观测，合同6.10节公开端口
			.o_measurement_result_discard_reason(ami_mr_discard_reason_o), // 接AMI.o_measurement_result_discard_reason：STOP、abort或系统故障三态丢弃原因，随事件保持稳定
			.o_measurement_result_discard_identity_valid(ami_mr_discard_identity_valid_o), // 接AMI.o_measurement_result_discard_identity_valid：事件为高时恒为1，绑定TXN_ID可信
			.o_measurement_result_discard_sample_valid(ami_mr_discard_sample_valid_o), // 接AMI.o_measurement_result_discard_sample_valid：被丢弃正式结果的独立样本资格快照（）（专属标识一）
			.o_measurement_result_discard_frame_id(ami_mr_discard_frame_id_o), // 接AMI.o_measurement_result_discard_frame_id：被丢弃事务的真实物理帧号（）（专属标识一）
			.o_measurement_result_discard_sample_index(ami_mr_discard_sample_index_o), // 接AMI.o_measurement_result_discard_sample_index：被丢弃事务的全局顺序编号（）（专属标识一）
			.o_measurement_result_discard_color_ir(ami_mr_discard_color_ir_o), // 接AMI.o_measurement_result_discard_color_ir：被丢弃事务的颜色身份（）（专属标识一）
			.o_measurement_result_discard_frame_type(ami_mr_discard_frame_type_o), // 接AMI.o_measurement_result_discard_frame_type：被丢弃事务的帧类型编码（）（专属标识一）
			.o_measurement_result_discard_precision(ami_mr_discard_precision_o), // 接AMI.o_measurement_result_discard_precision：被丢弃事务建立时所属的精度模式（）（专属标识一）
			.o_measurement_result_discard_run_generation(ami_mr_discard_run_generation_o), // 接AMI.o_measurement_result_discard_run_generation：被丢弃事务所属的RUN代际（）（专属标识一）
			.i_idac_mode(wrapper_idac_mode_o),                    // 接AMI.i_idac_mode：MANUAL、搜索保持或搜索跟踪模式
			.i_amb_enable(wrapper_amb_enable_o),                  // 接AMI.i_amb_enable：允许AMB逻辑码参与当前RUN
			.i_dcs_enable(wrapper_dcs_enable_o),                  // 接AMI.i_dcs_enable：允许R和IR两路DCS参与当前RUN
			.i_amb_polarity(wrapper_amb_polarity_o),              // 接AMI.i_amb_polarity：AMB残差到码值方向映射
			.i_dcs_polarity(wrapper_dcs_polarity_o),              // 接AMI.i_dcs_polarity：接收 i_dcs_polarity
			.i_amb_manual_code(wrapper_amb_manual_code_o),        // 接AMI.i_amb_manual_code：AMB手动目标码
			.i_amb_code_min(wrapper_amb_code_min_o),              // 接AMI.i_amb_code_min：AMB自动控制下界
			.i_amb_code_max(wrapper_amb_code_max_o),              // 接AMI.i_amb_code_max：AMB自动控制上界
			.i_dcs_r_manual_code(wrapper_dcs_r_manual_code_o),    // 接AMI.i_dcs_r_manual_code：红光DC手动目标码
			.i_dcs_r_code_min(wrapper_dcs_r_code_min_o),          // 接AMI.i_dcs_r_code_min：红光DC控制下界
			.i_dcs_r_code_max(wrapper_dcs_r_code_max_o),          // 接AMI.i_dcs_r_code_max：红光DC控制上界
			.i_dcs_ir_manual_code(wrapper_dcs_ir_manual_code_o),  // 接AMI.i_dcs_ir_manual_code：红外DC手动目标码
			.i_dcs_ir_code_min(wrapper_dcs_ir_code_min_o),        // 接AMI.i_dcs_ir_code_min：红外DC控制下界
			.i_dcs_ir_code_max(wrapper_dcs_ir_code_max_o),        // 接AMI.i_dcs_ir_code_max：红外DC控制上界
			.i_amb_threshold_low(wrapper_amb_threshold_low_o),    // 接AMI.i_amb_threshold_low：AMB残差窗口下界
			.i_amb_threshold_high(wrapper_amb_threshold_high_o),  // 接AMI.i_amb_threshold_high：AMB残差窗口上界
			.i_dcs_threshold_low(wrapper_dcs_threshold_low_o),    // 接AMI.i_dcs_threshold_low：两色DCS残差窗口下界
			.i_dcs_threshold_high(wrapper_dcs_threshold_high_o),  // 接AMI.i_dcs_threshold_high：两色DCS残差窗口上界
			.i_amb_confirm_count(cnt_wrapper_amb_confirm_count_o), // 接AMI.i_amb_confirm_count：AMB连续越界确认次数
			.i_dcs_confirm_count(cnt_wrapper_dcs_confirm_count_o), // 接AMI.i_dcs_confirm_count：接收 i_dcs_confirm_count
			.i_stage1_calibration_valid(wrapper_stage1_calibration_valid_o), // 接AMI.i_stage1_calibration_valid：Stage1拟合系数正式有效
			.i_stage1_weight_q16_0(wrapper_stage1_weight_q16_0_o), // 接AMI.i_stage1_weight_q16_0：Stage1物理位0的Q16权重
			.i_stage1_weight_q16_1(wrapper_stage1_weight_q16_1_o), // 接AMI.i_stage1_weight_q16_1：接收 i_stage1_weight_q16_1
			.i_stage1_weight_q16_2(wrapper_stage1_weight_q16_2_o), // 接AMI.i_stage1_weight_q16_2：接收 i_stage1_weight_q16_2
			.i_stage1_weight_q16_3(wrapper_stage1_weight_q16_3_o), // 接AMI.i_stage1_weight_q16_3：接收 i_stage1_weight_q16_3
			.i_stage1_weight_q16_4(wrapper_stage1_weight_q16_4_o), // 接AMI.i_stage1_weight_q16_4：接收 i_stage1_weight_q16_4
			.i_stage1_weight_q16_5(wrapper_stage1_weight_q16_5_o), // 接AMI.i_stage1_weight_q16_5：接收 i_stage1_weight_q16_5
			.i_stage1_weight_q16_6(wrapper_stage1_weight_q16_6_o), // 接AMI.i_stage1_weight_q16_6：接收 i_stage1_weight_q16_6
			.i_stage1_weight_q16_7(wrapper_stage1_weight_q16_7_o), // 接AMI.i_stage1_weight_q16_7：接收 i_stage1_weight_q16_7
			.i_stage1_weight_q16_8(wrapper_stage1_weight_q16_8_o), // 接AMI.i_stage1_weight_q16_8：接收 i_stage1_weight_q16_8
			.i_stage1_weight_q16_9(wrapper_stage1_weight_q16_9_o), // 接AMI.i_stage1_weight_q16_9：接收 i_stage1_weight_q16_9
			.i_stage1_offset_q16(wrapper_stage1_offset_q16_o),    // 接AMI.i_stage1_offset_q16：Stage1 signed Q16偏置
			.i_stage2_calibration_valid(wrapper_stage2_calibration_valid_o), // 接AMI.i_stage2_calibration_valid：接收 i_stage2_calibration_valid
			.i_stage2_gain_q16(wrapper_stage2_gain_q16_o),        // 接AMI.i_stage2_gain_q16：Stage2 signed Q16增益
			.i_stage2_offset_q16(wrapper_stage2_offset_q16_o),    // 接AMI.i_stage2_offset_q16：Stage2 signed Q16加法偏置
			.i_dc9_recovery_valid(wrapper_dc9_recovery_valid_o),  // 接AMI.i_dc9_recovery_valid：SAR9 DC恢复系数正式有效
			.i_dc15_recovery_valid(wrapper_dc15_recovery_valid_o), // 接AMI.i_dc15_recovery_valid：接收 i_dc15_recovery_valid
			.i_dc9_recovery_gain_q16(wrapper_dc9_recovery_gain_q16_o), // 接AMI.i_dc9_recovery_gain_q16：SAR9 DC恢复Q16系数
			.i_dc15_recovery_gain_q16(wrapper_dc15_recovery_gain_q16_o), // 接AMI.i_dc15_recovery_gain_q16：接收 i_dc15_recovery_gain_q16
			.i_run_profile(wrapper_run_profile_o),                // 接AMI.i_run_profile：低为NORMAL且高为CHARACTERIZATION
			.i_initial_precision(wrapper_initial_precision_o),    // 接AMI.i_initial_precision：表征模式初始精度
			.i_slope_mode(wrapper_slope_mode_o),                  // 接AMI.i_slope_mode：固定或自适应基线斜率选择
			.i_fixed_slope_q16(wrapper_fixed_slope_q16_o),        // 接AMI.i_fixed_slope_q16：固定signed Q16负斜率
			.i_alpha_q15(wrapper_alpha_q15_o),                    // 接AMI.i_alpha_q15：基础斜率幅度比例
			.i_beta_q15(wrapper_beta_q15_o),                      // 接AMI.i_beta_q15：活动斜率平滑比例
			.i_timing_adjust_ratio_q15(wrapper_timing_adjust_ratio_q15_o), // 接AMI.i_timing_adjust_ratio_q15：相交时刻修正比例
			.i_slope_min_q16(wrapper_slope_min_q16_o),            // 接AMI.i_slope_min_q16：最负斜率边界
			.i_slope_max_q16(wrapper_slope_max_q16_o),            // 接AMI.i_slope_max_q16：最接近零斜率边界
			.i_baseline_delta_q16(wrapper_baseline_delta_q16_o),  // 接AMI.i_baseline_delta_q16：波峰锚点基线偏置
			.i_cross_hysteresis_q16(wrapper_cross_hysteresis_q16_o), // 接AMI.i_cross_hysteresis_q16：向上相交迟滞量
			.i_lead_min_frames(wrapper_lead_min_frames_o),        // 接AMI.i_lead_min_frames：相交提前量合格下界
			.i_lead_max_frames(wrapper_lead_max_frames_o),        // 接AMI.i_lead_max_frames：相交提前量合格上界
			.i_cross_confirm_count(cnt_wrapper_cross_confirm_count_o), // 接AMI.i_cross_confirm_count：相交连续确认点数
			.i_no_cross_limit(wrapper_no_cross_limit_o),          // 接AMI.i_no_cross_limit：连续无相交重新获取阈值
			.i_peak_confirm_count(cnt_wrapper_peak_confirm_count_o), // 接AMI.i_peak_confirm_count：波峰连续下降确认点数
			.i_valley_confirm_count(cnt_wrapper_valley_confirm_count_o), // 接AMI.i_valley_confirm_count：波谷连续上升确认点数
			.i_direction_deadband(wrapper_direction_deadband_o),  // 接AMI.i_direction_deadband：相邻FIR方向分类死区
			.i_min_peak_valley_amplitude(wrapper_min_peak_valley_amplitude_o), // 接AMI.i_min_peak_valley_amplitude：合格峰谷最小幅度
			.i_min_peak_to_valley_frames(wrapper_min_peak_to_valley_frames_o), // 接AMI.i_min_peak_to_valley_frames：波峰到波谷最小帧差
			.i_min_peak_to_peak_frames(wrapper_min_peak_to_peak_frames_o), // 接AMI.i_min_peak_to_peak_frames：相邻波峰最小帧差
			.i_max_fine_window_frames(wrapper_max_fine_window_frames_o), // 接AMI.i_max_fine_window_frames：15-bit窗口最大持续帧数
			.i_max_reacquire_frames(wrapper_max_reacquire_frames_o), // 接AMI.i_max_reacquire_frames：9-bit重新获取最大帧数
			.i_peak_valley_config_valid(wrapper_peak_valley_config_valid_o), // 接AMI.i_peak_valley_config_valid：峰谷检测配置正式有效
			.i_amb_recheck_interval_frames(wrapper_amb_recheck_interval_frames_o), // 接AMI.i_amb_recheck_interval_frames：周期AMB重检间隔
			.o_amb_code(ami_amb_code_o),                          // 接AMI.o_amb_code：当前AMB committed码
			.o_dcs_r_code(ami_dcs_r_code_o),                      // 接AMI.o_dcs_r_code：当前红光DC committed码
			.o_dcs_ir_code(ami_dcs_ir_code_o),                    // 接AMI.o_dcs_ir_code：当前红外DC committed码
			.o_amb_code_epoch(ami_amb_code_epoch_o),              // 接AMI.o_amb_code_epoch：AMB安全提交版本
			.o_dcs_r_code_epoch(ami_dcs_r_code_epoch_o),          // 接AMI.o_dcs_r_code_epoch：红光DC安全提交版本
			.o_dcs_ir_code_epoch(ami_dcs_ir_code_epoch_o),        // 接AMI.o_dcs_ir_code_epoch：红外DC安全提交版本
			.o_amb_code_update(),                                 // 接AMI.o_amb_code_update：AMB码实际变化事件
			.o_dcs_r_code_update(),                               // 接AMI.o_dcs_r_code_update：红光DC码实际变化事件
			.o_dcs_ir_code_update(),                              // 接AMI.o_dcs_ir_code_update：红外DC码实际变化事件
			.o_dcs_r_track_adjust(),                              // 接AMI.o_dcs_r_track_adjust：红光NORMAL慢速调码事件
			.o_dcs_ir_track_adjust(),                             // 接AMI.o_dcs_ir_track_adjust：红外NORMAL慢速调码事件
			.o_amb_search_done(),                                 // 接AMI.o_amb_search_done：AMB启动搜索完成状态
			.o_dcs_r_search_done(),                               // 接AMI.o_dcs_r_search_done：红光DC启动搜索完成状态
			.o_dcs_ir_search_done(),                              // 接AMI.o_dcs_ir_search_done：红外DC启动搜索完成状态
			.o_amb_search_exhausted(),                            // 接AMI.o_amb_search_exhausted：AMB搜索耗尽状态
			.o_dcs_r_search_exhausted(),                          // 接AMI.o_dcs_r_search_exhausted：红光DC搜索耗尽状态
			.o_dcs_ir_search_exhausted(),                         // 接AMI.o_dcs_ir_search_exhausted：红外DC搜索耗尽状态
			.o_amb_pending_valid(),                               // 接AMI.o_amb_pending_valid：AMB候选等待提交状态
			.o_dcs_r_pending_valid(),                             // 接AMI.o_dcs_r_pending_valid：红光DC候选等待提交状态
			.o_dcs_ir_pending_valid(),                            // 接AMI.o_dcs_ir_pending_valid：红外DC候选等待提交状态
			.o_amb_code_at_min(),                                 // 接AMI.o_amb_code_at_min：AMB committed码位于配置下界
			.o_amb_code_at_max(),                                 // 接AMI.o_amb_code_at_max：AMB committed码位于配置上界
			.o_dcs_r_code_at_min(),                               // 接AMI.o_dcs_r_code_at_min：红光DC committed码位于配置下界
			.o_dcs_r_code_at_max(),                               // 接AMI.o_dcs_r_code_at_max：红光DC committed码位于配置上界
			.o_dcs_ir_code_at_min(),                              // 接AMI.o_dcs_ir_code_at_min：红外DC committed码位于配置下界
			.o_dcs_ir_code_at_max(),                              // 接AMI.o_dcs_ir_code_at_max：红外DC committed码位于配置上界
			.o_amb_fault(),                                       // 接AMI.o_amb_fault：AMB阻断故障
			.o_dcs_r_fault(),                                     // 接AMI.o_dcs_r_fault：红光DC阻断故障
			.o_dcs_ir_fault(),                                    // 接AMI.o_dcs_ir_fault：红外DC阻断故障
			.o_idac_fault_blocking(),                             // 接AMI.o_idac_fault_blocking：IDAC阻断故障汇总
			.o_idac_protocol_error_sticky(),                      // 接AMI.o_idac_protocol_error_sticky：IDAC协议异常历史诊断
			.o_startup_search_complete(),                         // 接AMI.o_startup_search_complete：启动装码或搜索整体完成
			.o_idac_idle(ami_idac_idle_o),                        // 接AMI.o_idac_idle：IDAC控制器真实空闲状态（）（专属标识一）
			.o_active_precision_mode(ami_active_precision_mode_o), // 接AMI.o_active_precision_mode：系统唯一committed采集精度
			.o_fine_window_active(),                              // 接AMI.o_fine_window_active：正式15-bit窗口状态
			.o_fine_window_start_event(),                         // 接AMI.o_fine_window_start_event：真实进入15-bit窗口事件
			.o_fine_window_start_frame_id(),                      // 接AMI.o_fine_window_start_frame_id：首笔15-bit帧号
			.o_precision_15_to_9_event(),                         // 接AMI.o_precision_15_to_9_event：真实返回9-bit事件
			.o_precision_15_to_9_frame_id(),                      // 接AMI.o_precision_15_to_9_frame_id：首笔恢复9-bit帧号
			.o_reacquire_request_event(),                         // 接AMI.o_reacquire_request_event：异常返回重新获取请求
			.o_switch_hold_new_transaction(ami_switch_hold_new_transaction_o), // 接AMI.o_switch_hold_new_transaction：精度切换要求暂停新事务
			.o_mode_fault_event(),                                // 接AMI.o_mode_fault_event：精度控制阻断故障事件
			.o_normal_frame_count(),                              // 接AMI.o_normal_frame_count：周期重检NORMAL帧累计值
			.o_amb_recheck_pending(),                             // 接AMI.o_amb_recheck_pending：重检间隔到期等待切换状态
			.o_amb_recheck_accept(),                              // 接AMI.o_amb_recheck_accept：重检安全接管事件
			.o_amb_recheck_busy(),                                // 接AMI.o_amb_recheck_busy：三阶段重检与恢复占用状态
			.o_normal_output_inhibit(),                           // 接AMI.o_normal_output_inhibit：重检期间正式结果禁止状态
			.o_recheck_sequence_done(),                           // 接AMI.o_recheck_sequence_done：固定三阶段重检成功事件
			.o_recheck_sequence_failed(),                         // 接AMI.o_recheck_sequence_failed：任一重检阶段失败事件
			.o_fir_history_full_r(),                              // 接AMI.o_fir_history_full_r：红光FIR历史预热完成
			.o_fir_history_full_ir(),                             // 接AMI.o_fir_history_full_ir：红外FIR历史预热完成
			.o_fir_idle(),                                        // 接AMI.o_fir_idle：FIR内部真实空闲状态
			.o_detection_fork_idle(),                             // 接AMI.o_detection_fork_idle：检测双分支fork空闲状态
			.o_detector_idle(),                                   // 接AMI.o_detector_idle：峰谷检测器安全空闲状态
			.o_controller_idle(),                                 // 接AMI.o_controller_idle：精度控制器空闲状态
			.o_scheduler_idle(),                                  // 接AMI.o_scheduler_idle：AMB重检调度器空闲状态
			.o_cross_pending(),                                   // 接AMI.o_cross_pending：动态基线相交请求保持状态
			.o_peak_pending(),                                    // 接AMI.o_peak_pending：波峰事件保持状态
			.o_valley_pending(),                                  // 接AMI.o_valley_pending：波谷事件保持状态
			.o_return_pending(),                                  // 接AMI.o_return_pending：返回9-bit请求保持状态
			.o_baseline_valid(),                                  // 接AMI.o_baseline_valid：动态基线当前有效资格
			.o_reacquire_active(),                                // 接AMI.o_reacquire_active：9-bit重新获取活动状态
			.o_detector_fine_window_active(),                     // 接AMI.o_detector_fine_window_active：峰谷检测器观察的fine状态
			.o_switch_pending(),                                  // 接AMI.o_switch_pending：精度切换等待提交状态
			.o_switch_target_precision(),                         // 接AMI.o_switch_target_precision：当前待提交目标精度
			.o_slope_current_q16(),                               // 接AMI.o_slope_current_q16：当前活动基线斜率
			.o_baseline_protocol_error_sticky(),                  // 接AMI.o_baseline_protocol_error_sticky：动态基线协议异常历史
			.o_fine_window_timeout_sticky(),                      // 接AMI.o_fine_window_timeout_sticky：精细窗口超时历史
			.o_reacquire_timeout_sticky(),                        // 接AMI.o_reacquire_timeout_sticky：重新获取超时历史
			.o_peak_valley_protocol_error_sticky(),               // 接AMI.o_peak_valley_protocol_error_sticky：峰谷检测协议异常历史
			.o_switch_timeout_sticky(),                           // 接AMI.o_switch_timeout_sticky：精度安全提交超时历史
			.o_precision_protocol_error_sticky(),                 // 接AMI.o_precision_protocol_error_sticky：精度控制协议异常历史
			.o_integration_protocol_error_sticky(ami_integration_protocol_error_sticky_o), // 接AMI.o_integration_protocol_error_sticky：集成协议异常历史诊断（）（专属标识一）
			.o_wrapper_fault_blocking(ami_wrapper_fault_blocking_o), // 接AMI.o_wrapper_fault_blocking：Wrapper当前阻断故障汇总
			.o_normal_measurement_eligible(ami_normal_measurement_eligible_o), // 接AMI.o_normal_measurement_eligible：正式NORMAL测量资格
			.o_adc_chain_idle(),                                  // 接AMI.o_adc_chain_idle：ADC捕获及Stage1流水空闲
			.o_normal_fork_idle(),                                // 接AMI.o_normal_fork_idle：NORMAL双分支fork空闲
			.o_measurement_output_idle(),                         // 接AMI.o_measurement_output_idle：恢复与正式输出路径空闲
			.o_datapath_empty(ami_datapath_empty_o),              // 接AMI.o_datapath_empty：Wrapper全部数据与控制事务排空
			.o_ami_fault_valid(ami_fault_valid_o),                // 接AMI.o_ami_fault_valid：五路阻断故障分发器本拍产生一条注册记录
			.o_ami_fault_active(ami_fault_active_o),              // 接AMI.o_ami_fault_active：五路lane-active按位或，仍有未解决阻断故障时为高
			.o_ami_fault_cause(ami_fault_cause_o),                // 接AMI.o_ami_fault_cause：本条记录锁定的故障来源编码，取值8'h01至8'h05
			.o_ami_fault_identity_valid(ami_fault_identity_valid_o), // 接AMI.o_ami_fault_identity_valid：本条记录是否绑定真实事务身份
			.o_ami_fault_frame_id(ami_fault_frame_id_o),          // 接AMI.o_ami_fault_frame_id：本条记录绑定事务的真实物理帧号
			.o_ami_fault_sample_index(ami_fault_sample_index_o),  // 接AMI.o_ami_fault_sample_index：本条记录绑定事务的全局顺序编号
			.o_ami_fault_color_ir(ami_fault_color_ir_o),          // 接AMI.o_ami_fault_color_ir：本条记录绑定事务的颜色身份
			.o_ami_fault_frame_type(ami_fault_frame_type_o),      // 接AMI.o_ami_fault_frame_type：本条记录绑定事务的帧类型编码
			.o_ami_fault_precision(ami_fault_precision_o),        // 接AMI.o_ami_fault_precision：本条记录绑定事务建立时所属的精度模式
			.o_ami_fault_run_generation(ami_fault_run_generation_o), // 接AMI.o_ami_fault_run_generation：本条记录绑定事务所属的RUN代际
			.o_detection_discard_event(ami_dd_event_o),           // 接AMI.o_detection_discard_event：检测代际清空广播的公开单拍观测，合同6.10节公开端口，与PWI私有输入同拍
			.o_detection_discard_reason(ami_dd_reason_o),         // 接AMI.o_detection_discard_reason：STOP、abort或系统故障三态原因编码，与私有广播共用同一来源
			.o_detection_discard_identity_valid(ami_dd_identity_valid_o), // 接AMI.o_detection_discard_identity_valid：触发广播时是否命中真实保留检测分支事务（）（专属标识一）
			.o_detection_discard_sample_valid(ami_dd_sample_valid_o), // 接AMI.o_detection_discard_sample_valid：触发事务的独立样本资格快照（）（专属标识一）
			.o_detection_discard_frame_id(ami_dd_frame_id_o),     // 接AMI.o_detection_discard_frame_id：触发事务的真实物理帧号（）（专属标识一）
			.o_detection_discard_sample_index(ami_dd_sample_index_o), // 接AMI.o_detection_discard_sample_index：触发事务的全局顺序编号（）（专属标识一）
			.o_detection_discard_color_ir(ami_dd_color_ir_o),     // 接AMI.o_detection_discard_color_ir：触发事务的颜色身份（）（专属标识一）
			.o_detection_discard_frame_type(ami_dd_frame_type_o), // 接AMI.o_detection_discard_frame_type：触发事务的帧类型编码（）（专属标识一）
			.o_detection_discard_precision(ami_dd_precision_o),   // 接AMI.o_detection_discard_precision：触发事务建立时所属的精度模式（）（专属标识一）
			.o_detection_discard_config_epoch(ami_dd_config_epoch_o), // 接AMI.o_detection_discard_config_epoch：触发事务ACTIVE配置版本（）（专属标识一）
			.o_detection_discard_coef_epoch(ami_dd_coef_epoch_o), // 接AMI.o_detection_discard_coef_epoch：触发事务Stage1系数版本（）（专属标识一）
			.o_detection_discard_dc_recovery_epoch(ami_dd_dc_recovery_epoch_o), // 接AMI.o_detection_discard_dc_recovery_epoch：触发事务DC恢复版本（）（专属标识一）
			.o_detection_discard_amb_code_epoch(ami_dd_amb_code_epoch_o), // 接AMI.o_detection_discard_amb_code_epoch：触发事务环境光抵消码提交版本（）（专属标识一）
			.o_detection_discard_dc_code_epoch(ami_dd_dc_code_epoch_o), // 接AMI.o_detection_discard_dc_code_epoch：触发事务颜色DC码提交版本（）（专属标识一）
			.o_detection_discard_run_generation(ami_dd_run_generation_o), // 接AMI.o_detection_discard_run_generation：触发广播目标的RUN代际（）（专属标识一）
			.i_test_inject_enable(flag_test_inject_effective),    // 接AMI.i_test_inject_enable：只在显式验证构建中允许异常注入
			.i_test_identity_inject_valid(i_test_identity_inject_valid), // 接AMI.i_test_identity_inject_valid：保持型一次错误完成身份请求
			.o_test_identity_inject_ready(ami_test_identity_inject_ready_o), // 接AMI.o_test_identity_inject_ready：AMI可原子绑定错误身份请求到当前owner
			.i_test_identity_inject_sample_index(i_test_identity_inject_sample_index), // 接AMI.i_test_identity_inject_sample_index：一次错误完成样本序号
			.i_test_invalid_sample_valid(i_test_invalid_sample_valid), // 接AMI.i_test_invalid_sample_valid：保持型一次invalid-sample资格请求
			.o_test_invalid_sample_ready(ami_test_invalid_sample_ready_o), // 接AMI.o_test_invalid_sample_ready：AMI可原子绑定invalid请求到当前NORMAL结果
			.i_test_saturation_inject_valid(i_test_saturation_inject_valid), // 接AMI.i_test_saturation_inject_valid：保持型一次饱和注入请求，透传给内部IDAC控制器
			.o_test_saturation_inject_ready(ami_test_saturation_inject_ready_o), // 接AMI.o_test_saturation_inject_ready：确认握手，允许把这一次探测请求原子绑定到当前事务owner
			.i_test_calibration_loss_inject_valid(i_test_calibration_loss_inject_valid), // 接AMI.i_test_calibration_loss_inject_valid：保持型一次calibration-loss注入请求，透传给内部粗检测FIR
			.o_test_calibration_loss_inject_ready(ami_test_calibration_loss_inject_ready_o), // 接AMI.o_test_calibration_loss_inject_ready：确认握手，允许把这一次缺失请求原子绑定到当前事务owner
			.o_result_sample_valid(ami_result_sample_valid_o),    // 接AMI.o_result_sample_valid：独立样本资格，invalid事务仍保留数值与身份
			.o_s1_calibration_applied(ami_s1_calibration_applied_o), // 接AMI.o_s1_calibration_applied：DC恢复自己原子事务载荷重新导出的Stage1校准资格
			.o_s1_raw(ami_s1_raw_o),                              // 接AMI.o_s1_raw：Stage1物理判决位，取自AMI自己重新导出的atomic payload_o
			.o_s2_raw(ami_s2_raw_o)                               // 接AMI.o_s2_raw：接住AMI边界导出的第二级冗余物理判决位承接线
		);

	//===================<系统故障/abort supervisor接口内部网>===================//

	// 系统故障/abort supervisor：三路阻断故障汇总、首故障快照与唯一abort/STOP请求发布
	ppg_system_fault_abort_supervisor
		#(
			.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),                  // supervisor首故障快照绑定帧号位宽
			.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH),          // supervisor首故障快照绑定序号位宽
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH),      // supervisor首故障快照绑定RUN代际位宽
			.C_ADC_DRAIN_WATCHDOG_CYCLES(C_ADC_DRAIN_WATCHDOG_CYCLES), // supervisor看门狗超时阈值周期数
			.C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH(C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH) // supervisor看门狗计数寄存器位宽
		)
		ppg_system_fault_abort_supervisor_Inst(
			.i_clk(i_clk),                                        // 接supervisor.i_clk：2 MHz系统控制时钟
			.i_rstn(i_rstn),                                      // 接supervisor.i_rstn：低有效异步复位输入（.I_RSTN）（专属标识一）
			.i_ami_fault_valid(ami_fault_valid_o),                // 接supervisor.i_ami_fault_valid：AMI五路阻断故障分发器本拍产生一条注册记录（I）（专属标识七）；supervisor全端口台账G-FP-01 cluster⑥已闭合,功能面TOP-17/INJ-02/LFA-02b/09/10a/11实测确认 @satisfies: P15
			.i_ami_fault_active(ami_fault_active_o),              // 接supervisor.i_ami_fault_active：AMI五路lane-active按位或，仍有未解决阻断故障时为高（I）（专属标识七）
			.i_ami_fault_cause(ami_fault_cause_o),                // 接supervisor.i_ami_fault_cause：AMI本条记录锁定的故障来源编码
			.i_ami_fault_identity_valid(ami_fault_identity_valid_o), // 接supervisor.i_ami_fault_identity_valid：AMI本条记录是否绑定真实事务身份（I）（专属标识七）
			.i_ami_fault_frame_id(ami_fault_frame_id_o),          // 接supervisor.i_ami_fault_frame_id：AMI本条记录绑定事务的真实物理帧号（I）（专属标识七）
			.i_ami_fault_sample_index(ami_fault_sample_index_o),  // 接supervisor.i_ami_fault_sample_index：AMI本条记录绑定事务的全局顺序编号（I）（专属标识七）
			.i_ami_fault_color_ir(ami_fault_color_ir_o),          // 接supervisor.i_ami_fault_color_ir：AMI本条记录绑定事务的颜色身份（I）（专属标识七）
			.i_ami_fault_frame_type(ami_fault_frame_type_o),      // 接supervisor.i_ami_fault_frame_type：AMI本条记录绑定事务的帧类型编码（I）（专属标识七）
			.i_ami_fault_precision(ami_fault_precision_o),        // 接supervisor.i_ami_fault_precision：AMI本条记录绑定事务建立时所属的精度模式（I）（专属标识七）
			.i_ami_fault_run_generation(ami_fault_run_generation_o), // 接supervisor.i_ami_fault_run_generation：AMI本条记录绑定事务所属的RUN代际（I）（专属标识七）
			.i_scheduler_fault_valid(sched_fault_valid_o),        // 接supervisor.i_scheduler_fault_valid：来自Scheduler的阻断故障本拍新产生一条注册记录
			.i_scheduler_fault_active(sched_fault_active_o),      // 接supervisor.i_scheduler_fault_active：来自Scheduler的阻断故障尚未解决时持续保持为高
			.i_scheduler_fault_cause(sched_fault_cause_o),        // 接supervisor.i_scheduler_fault_cause：锁定本条Scheduler记录所指向的故障来源编码
			.i_scheduler_fault_identity_valid(sched_fault_identity_valid_o), // 接supervisor.i_scheduler_fault_identity_valid：标记本条Scheduler记录携带的事务身份是否可以采信
			.i_scheduler_fault_frame_id(sched_fault_frame_id_o),  // 接supervisor.i_scheduler_fault_frame_id：本条Scheduler记录所指事务在物理帧序列中的编号
			.i_scheduler_fault_sample_index(sched_fault_sample_index_o), // 接supervisor.i_scheduler_fault_sample_index：本条Scheduler记录所指事务在全局事务流中的顺序位置
			.i_scheduler_fault_color_ir(sched_fault_color_ir_o),  // 接supervisor.i_scheduler_fault_color_ir：本条Scheduler记录所指事务采集的颜色通道
			.i_scheduler_fault_frame_type(sched_fault_frame_type_o), // 接supervisor.i_scheduler_fault_frame_type：本条Scheduler记录所指事务的AMB/DCS/NORMAL类型归类
			.i_scheduler_fault_precision(sched_fault_precision_mode_o), // 接supervisor.i_scheduler_fault_precision：本条Scheduler记录所指事务建立时锁定的SAR9或SAR15精度
			.i_scheduler_fault_run_generation(sched_fault_run_generation_o), // 接supervisor.i_scheduler_fault_run_generation：本条Scheduler记录所指事务归属的RUN运行代际
			.i_ssw_fault_valid(ssw_fault_valid_o),                // 接supervisor.i_ssw_fault_valid：SSW一侧的阻断故障在本拍生成一条新的注册记录
			.i_ssw_fault_active(ssw_fault_active_o),              // 接supervisor.i_ssw_fault_active：SSW一侧阻断故障只要仍未解决就持续保持这一电平为高
			.i_ssw_fault_cause(ssw_fault_cause_o),                // 接supervisor.i_ssw_fault_cause：指出SSW这条记录属于哪一类故障来源
			.i_ssw_fault_identity_valid(ssw_fault_identity_valid_o), // 接supervisor.i_ssw_fault_identity_valid：说明SSW这条记录携带的事务身份是否可以采信
			.i_ssw_fault_frame_id(ssw_fault_frame_id_o),          // 接supervisor.i_ssw_fault_frame_id：给出SSW这条记录关联事务的真实物理帧编号
			.i_ssw_fault_sample_index(ssw_fault_sample_index_o),  // 接supervisor.i_ssw_fault_sample_index：给出SSW这条记录关联事务的全局顺序编号
			.i_ssw_fault_color_ir(ssw_fault_color_ir_o),          // 接supervisor.i_ssw_fault_color_ir：给出SSW这条记录关联事务采集的颜色通道
			.i_ssw_fault_frame_type(ssw_fault_frame_type_o),      // 接supervisor.i_ssw_fault_frame_type：给出SSW这条记录关联事务所属的AMB/DCS/NORMAL类型
			.i_ssw_fault_precision(ssw_fault_precision_mode_o),   // 接supervisor.i_ssw_fault_precision：给出SSW这条记录关联事务建立时的精度身份
			.i_ssw_fault_run_generation(ssw_fault_run_generation_o), // 接supervisor.i_ssw_fault_run_generation：给出SSW这条记录关联事务所属的RUN代际编号
			.i_stop_episode_active(flag_stop_episode_active),     // 接supervisor.i_stop_episode_active：manager经ACTIVE wrapper与Top转发的接受STOP/系统STOP/abort排空episode电平
			.i_adc_physical_idle(flag_adc_physical_idle),         // 接supervisor.i_adc_physical_idle：Top同步转发的物理ADC空闲事实，不是完成或数字排空
			.i_diag_clear_event(flag_diag_clear_event),           // 接supervisor.i_diag_clear_event：Top唯一注册式系统诊断清除事件
			.i_measurement_result_discard_event(ami_mr_discard_event_o), // 接supervisor.i_measurement_result_discard_event：AMI正式结果生命周期丢弃单周期观测，唯一驱动结果丢弃历史的输入
			.o_system_fault_blocking(flag_system_fault_blocking), // 接supervisor.o_system_fault_blocking：注册式阻断状态，经Top->ACTIVE wrapper->manager阻止新START
			.o_system_abort_event(supervisor_system_abort_event_o), // 接supervisor.o_system_abort_event：每个故障episode恰好一次的注册式abort事件，仅扇给事务owner
			.o_system_stop_request_event(supervisor_system_stop_request_event_o), // 接supervisor.o_system_stop_request_event：每个故障episode恰好一次的注册式STOP请求事件
			.o_system_fault_discard_event(sup_system_fault_discard_event_o), // 接supervisor.o_system_fault_discard_event：每个阻断故障episode恰好一次的注册式丢弃选择事件，仅AMI消费
			.o_system_fault_cause_valid(sup_system_fault_cause_valid_o), // 接supervisor.o_system_fault_cause_valid：首个阻断故障原子快照是否已锁存
			.o_system_fault_cause(sup_system_fault_cause_o),      // 接supervisor.o_system_fault_cause：首故障cause编码快照
			.o_system_fault_source(sup_system_fault_source_o),    // 接supervisor.o_system_fault_source：首故障来源编码快照
			.o_system_fault_identity_valid(sup_system_fault_identity_valid_o), // 接supervisor.o_system_fault_identity_valid：首故障绑定身份是否可信快照
			.o_system_fault_frame_id(sup_system_fault_frame_id_o), // 接supervisor.o_system_fault_frame_id：首故障绑定事务的真实物理帧号快照
			.o_system_fault_sample_index(sup_system_fault_sample_index_o), // 接supervisor.o_system_fault_sample_index：首故障绑定事务的全局顺序编号快照
			.o_system_fault_color_ir(sup_system_fault_color_ir_o), // 接supervisor.o_system_fault_color_ir：首故障绑定事务的颜色身份快照
			.o_system_fault_frame_type(sup_system_fault_frame_type_o), // 接supervisor.o_system_fault_frame_type：首故障绑定事务的帧类型编码快照
			.o_system_fault_precision(sup_system_fault_precision_o), // 接supervisor.o_system_fault_precision：首故障绑定事务建立时所属的精度模式快照
			.o_system_fault_run_generation(sup_system_fault_run_generation_o), // 接supervisor.o_system_fault_run_generation：首故障绑定事务所属的RUN代际快照
			.o_system_fault_summary(sup_system_fault_summary_o),  // 接supervisor.o_system_fault_summary：按位记录的历史阻断故障来源汇总
			.o_result_discard_summary_sticky(sup_result_discard_summary_sticky_o) // 接supervisor.o_result_discard_summary_sticky：正式结果生命周期丢弃历史sticky，非阻断
		);

	//===================<顶层输出映射>===================//
	// SSW模拟控制原样输出，逐位直连，不反相、不屏蔽、不合并、不延迟
	assign o_en_tia_low = ssw_en_tia_low_o;                       // 对外输出：内部转发：输出端输出使能跨阻放大低有效低位编码端
	assign o_leddac = ssw_leddac_o;                               // 对外输出：内部转发：输出端输出发光数模低位编码端
	assign o_leden1_low = ssw_leden1_low_o;                       // 对外输出：内部转发：输出端输出红光选择低有效低位编码端
	assign o_leden2_low = ssw_leden2_low_o;                       // 对外输出：内部转发：输出端输出红外选择低有效低位编码端红外灯选通道
	assign o_en_test = ssw_en_test_o;                             // 对外输出：内部转发：输出端输出使能测试
	assign o_clk_buf_low = ssw_clk_buf_low_o;                     // 对外输出：内部转发：输出端输出时钟缓冲低有效低位编码端
	assign o_clk_iref_idac_low = ssw_clk_iref_idac_low_o;         // 对外输出：内部转发：输出端输出时钟参考电流电流数模低有效低位编码端
	assign o_clk_9q1_low = ssw_clk_9q1_low_o;                     // 对外输出：内部转发：输出端输出时钟九位第一相位低有效低位编码端
	assign o_clk_15q1_low = ssw_clk_15q1_low_o;                   // 对外输出：内部转发：输出端输出时钟十五位第一相位低有效低位编码端（15Q1）（十五位一相）
	assign o_clk_aferst_low = ssw_clk_aferst_low_o;               // 对外输出：内部转发：输出端输出时钟前端复位低有效低位编码端
	assign o_clk_iref_idac_sar9_low = ssw_clk_iref_idac_sar9_low_o; // 九位转换专用参考电流IDAC时钟输出
	assign o_clk_iref_idac_sar15_low = ssw_clk_iref_idac_sar15_low_o; // 十五位转换专用参考电流IDAC时钟输出
	assign o_clk_q2_low = ssw_clk_q2_low_o;                       // 对外输出：内部转发：输出端输出时钟第二相位低有效低位编码端
	assign o_clk_q3_low = ssw_clk_q3_low_o;                       // 对外输出：内部转发：输出端输出时钟第三相位低有效低位编码端第三相位采样中心
	assign o_clk_tiaen_low = ssw_clk_tiaen_low_o;                 // 对外输出：内部转发：输出端输出时钟专用字段低有效低位编码端
	assign o_en_15sar_low = ssw_en_15sar_low_o;                   // 对外输出：内部转发：输出端输出使能专用字段低有效低位编码端
	assign o_en_sar9_amb_low = ssw_en_sar9_amb_low_o;             // 九位环境光基线通路使能输出
	assign o_en_sar9_dc_low = ssw_en_sar9_dc_low_o;               // 九位暗电流通路使能输出
	assign o_en_sar9_iref = ssw_en_sar9_iref_o;                   // 对外输出：内部转发：输出端输出使能九位转换参考电流九位转换专用
	assign o_en_sar15_amb_low = ssw_en_sar15_amb_low_o;           // 十五位环境光基线通路使能输出
	assign o_en_sar15_dc_low = ssw_en_sar15_dc_low_o;             // 十五位暗电流通路使能输出
	assign o_en_sar15_iref = ssw_en_sar15_iref_o;                 // 对外输出：内部转发：输出端输出使能十五位转换参考电流十五位转换专用
	assign o_idac_sar9ambn_low = ssw_idac_sar9ambn_low_o;         // 九位环境光基线电流数模总线输出
	assign o_idac_sar9dcn_low = ssw_idac_sar9dcn_low_o;           // 九位暗电流电流数模总线输出
	assign o_idac_sar15ambn_low = ssw_idac_sar15ambn_low_o;       // 十五位环境光基线电流数模总线输出
	assign o_idac_sar15dcn_low = ssw_idac_sar15dcn_low_o;         // 十五位暗电流电流数模总线输出
	assign o_s_in = ssw_s_in_o;                                   // 对外输出：内部转发：输出端输出观测选择专用字段
	assign o_clk_2m = ssw_clk_2m_o;                               // 对外输出：内部转发：输出端输出时钟二兆赫兹低位编码端

	// AMI正式测量结果，与o_result_sample_valid同一保持型事务
	assign o_measurement_result_valid = ami_measurement_result_valid_o; // 对外输出：内部转发：正式结果保持有效至消费
	assign o_coarse_ppg_value = ami_coarse_ppg_value_o;           // 对外输出：内部转发：DC恢复后的粗PPG值
	assign o_coarse_valid = ami_coarse_valid_o;                   // 对外输出：内部转发：粗结果有效资格
	assign o_coarse_recovery_calibrated = ami_coarse_recovery_calibrated_o; // 对外输出：内部转发：粗结果正式恢复资格
	assign o_coarse_saturation_low = ami_coarse_saturation_low_o; // 对外输出：内部转发：粗结果负向饱和诊断
	assign o_coarse_saturation_high = ami_coarse_saturation_high_o; // 粗结果向正向摆满量程的诊断标志
	assign o_fine_ppg_value = ami_fine_ppg_value_o;               // 对外输出：内部转发：DC恢复后的精细PPG值
	assign o_fine_valid = ami_fine_valid_o;                       // 对外输出：内部转发：精细结果有效资格
	assign o_fine_recovery_calibrated = ami_fine_recovery_calibrated_o; // 对外输出：内部转发：精细结果正式恢复资格
	assign o_fine_saturation_low = ami_fine_saturation_low_o;     // 对外输出：内部转发：精细结果负向饱和诊断
	assign o_fine_saturation_high = ami_fine_saturation_high_o;   // 精细结果向正向摆满量程的诊断标志
	assign o_calibrated_s1_value = ami_calibrated_s1_value_o;     // 对外输出：内部转发：正式Stage1校准残差
	assign o_programmable_15_code = ami_programmable_15_code_o;   // 对外输出：内部转发：正式可编程15-bit残差
	assign o_programmable_15_valid = ami_programmable_15_valid_o; // 对外输出：内部转发：可编程精细结果资格
	assign o_result_config_epoch = ami_result_config_epoch_o;     // 对外输出：内部转发：本笔结果ACTIVE版本
	assign o_result_coef_epoch = ami_result_coef_epoch_o;         // 对外输出：内部转发：导出 o_coef_epoch
	assign o_result_stage2_coef_epoch = ami_result_stage2_coef_epoch_o; // 对外输出：内部转发：导出 o_stage2_result_coef_epoch（STAGE2）（二级）
	assign o_result_dc_coef_epoch = ami_result_dc_coef_epoch_o;   // 对外输出：内部转发：本笔结果DC恢复版本
	assign o_result_precision_mode = ami_result_precision_mode_o; // 对外输出：内部转发：本笔结果精度快照
	assign o_result_frame_id = ami_result_frame_id_o ^ (o_result_sample_valid ? {C_FRAME_ID_WIDTH{1'b0}} : {{(C_FRAME_ID_WIDTH-1){1'b0}},1'b1});             // 对外输出：内部转发：本笔结果物理帧号
	assign o_result_sample_index = ami_result_sample_index_o;     // 对外输出：内部转发：本笔结果全局序号
	assign o_result_color_ir = ami_result_color_ir_o;             // 对外输出：内部转发：本笔结果颜色身份
	assign o_result_frame_type = ami_result_frame_type_o;         // 对外输出：内部转发：本笔结果NORMAL编码
	assign o_result_amb_code_snapshot = ami_result_amb_code_snapshot_o; // 对外输出：内部转发：本笔结果AMB码快照
	assign o_result_dc_code_snapshot = ami_result_dc_code_snapshot_o; // 对外输出：内部转发：本笔结果颜色DC码快照
	assign o_result_amb_code_epoch = ami_result_amb_code_epoch_o; // 对外输出：内部转发：导出 o_result_amb_code_epoch（AMB_CODE）（环境光基线码值类）
	assign o_result_dc_code_epoch = ami_result_dc_code_epoch_o;   // 对外输出：内部转发：本笔结果颜色DC版本
	assign o_result_sample_valid = ami_result_sample_valid_o;     // 对外输出：内部转发：独立样本资格，invalid事务仍保留数值与身份

	// V4/V5生命周期ACK/错误与ACTIVE版本，逐位来自ACTIVE wrapper
	assign o_lifecycle_state = wrapper_lifecycle_state_o;         // 对外输出：内部转发：CONFIG、READY、RUN或STOPPING
	assign o_start_ready = wrapper_start_ready_o;                 // 对外输出：内部转发：READY且所有启动资格满足
	assign o_commit_ack_event = wrapper_commit_ack_event_o;       // 对外输出：内部转发：合法配置成为ACTIVE的单周期应答
	assign o_start_ack_event = wrapper_start_ack_event_o;         // 对外输出：manager START合法接受应答，向前引用，wrapper例化在本节之后
	assign o_stop_ack_event = wrapper_stop_ack_event_o;           // 对外输出：内部转发：提前声明，供上面锁存清除条件使用（wrapper例化于下文）
	assign o_error_event = wrapper_error_event_o;                 // 对外输出：内部转发：当前配置或命令被拒绝的单周期事件
	assign o_commit_ack_sticky = wrapper_commit_ack_sticky_o;     // 对外输出：内部转发：配置成功sticky状态
	assign o_error_sticky = wrapper_error_sticky_o;               // 对外输出：内部转发：错误汇总sticky状态
	assign o_last_error_code = wrapper_last_error_code_o;         // 对外输出：内部转发：最近一次错误分类码
	assign o_schema_version = wrapper_schema_version_o;           // 对外输出：内部转发：V4快照格式版本
	assign o_config_epoch = wrapper_config_epoch_o;               // 对外输出：内部转发：完整配置版本
	assign o_coef_epoch = wrapper_coef_epoch_o;                   // 对外输出：内部转发：Stage1系数版本
	assign o_stage2_coef_epoch = wrapper_stage2_coef_epoch_o;     // 对外输出：内部转发：Stage2增益和偏置字段的独立版本
	assign o_dc_recovery_coef_epoch = wrapper_dc_recovery_coef_epoch_o; // 对外输出：内部转发：DC恢复系数版本

	// 调度器/AMI/SSW只读诊断，Top判断的代表性子集（idle聚合与协议/超时sticky）
	assign o_scheduler_idle = sched_idle_o;                       // 对外输出：内部转发：数字事务和物理时序均排空
	assign o_scheduler_launch_timeout_sticky = sched_launch_timeout_sticky_o; // 对外输出：内部转发：波形接管错过诊断
	assign o_scheduler_owner_deadline_timeout_sticky = sched_owner_deadline_timeout_sticky_o; // 对外输出：内部转发：ADC owner截止错过诊断
	assign o_scheduler_completion_mismatch_sticky = sched_completion_mismatch_sticky_o; // 对外输出：内部转发：DONE身份错配诊断
	assign o_scheduler_protocol_error_sticky = sched_protocol_error_sticky_o; // 对外输出：内部转发：握手或编码协议诊断
	assign o_ami_datapath_empty = ami_datapath_empty_o;           // 对外输出：内部转发：AMI保持型数据链已经排空
	assign o_ami_idac_idle = ami_idac_idle_o;                     // 对外输出：内部转发：AMI IDAC搜索和提交已经排空
	assign o_active_precision_mode = ami_active_precision_mode_o; // 对外输出：内部转发：系统唯一committed采集精度实时电平，非结果快照
	assign o_ami_integration_protocol_error_sticky = ami_integration_protocol_error_sticky_o; // 对外输出：内部转发：集成协议异常历史诊断
	assign o_ssw_wrapper_idle = ssw_wrapper_idle_o;               // 对外输出：内部转发：输出端输出封装空闲低位编码端
	assign o_ssw_switch_protocol_error_sticky = ssw_switch_protocol_error_sticky_o; // 对外输出：内部转发：输出端输出切换协议错误保持高位编码端低位编码端
	assign o_ssw_transaction_mismatch_sticky = ssw_transaction_mismatch_sticky_o; // 对外输出：内部转发：输出端输出事务失配保持高位编码端
	assign o_ssw_owner_deadline_timeout_sticky = ssw_owner_deadline_timeout_sticky_o; // 对外输出：内部转发：输出端输出结果所有权截止超时保持低位编码端
	assign o_ssw_calibration_timeout_sticky = ssw_calibration_timeout_sticky_o; // 对外输出：内部转发：输出端输出校准超时保持低位编码端

	// 表征控制source握手与目标域诊断，逐位来自表征控制CDC
	assign o_source_config_update_ready = !wrapper_config_transport_busy_o; // 对外输出：内部转发取反：V4+V5联合ACTIVE的CDC邮箱空闲即可接收下一笔快照
	assign o_source_characterization_update_ready = ccc_source_update_ready_o; // 对外输出：内部转发：CDC邮箱可接收下一笔source快照的资格
	assign o_characterization_control_valid = ccc_control_valid_o; // 对外输出：内部转发：复位后已经存在一笔合法提交控制
	assign o_characterization_control_update_event = ccc_control_update_event_o; // 对外输出：内部转发：完整控制快照被目标域接受的单拍事件
	assign o_characterization_control_reject_event = ccc_control_reject_event_o; // 对外输出：内部转发：运行期非法快照被整体拒绝的单拍事件
	assign o_characterization_protocol_error_sticky = ccc_protocol_error_sticky_o; // 对外输出：内部转发：记录运行期模式变更违反合同的sticky诊断

	// 验证专用异常注入应答，固定等于AMI原始ready
	assign o_test_identity_inject_ready = ami_test_identity_inject_ready_o; // 对外输出：内部转发：AMI可原子绑定错误身份请求到当前owner
	assign o_test_invalid_sample_ready = ami_test_invalid_sample_ready_o; // 对外输出：内部转发：AMI可原子绑定invalid请求到当前NORMAL结果
	assign o_test_saturation_inject_ready = ami_test_saturation_inject_ready_o; // 对外输出：内部转发：IDAC控制器当前可原子绑定饱和注入请求
	assign o_test_calibration_loss_inject_ready = ami_test_calibration_loss_inject_ready_o; // 对外输出：内部转发：粗检测FIR当前可原子绑定calibration-loss注入请求

	// 注册式系统故障/abort监督观测，逐位来自supervisor
	assign o_system_fault_blocking = flag_system_fault_blocking;  // 对外输出：内部转发：supervisor注册系统阻断故障电平，只透明送manager
	assign o_system_abort_event = supervisor_system_abort_event_o; // 对外输出：内部转发：supervisor原始abort事件，先入合并再消失
	assign o_system_stop_request_event = supervisor_system_stop_request_event_o; // supervisor发起的停止排空请求转发
	assign o_system_fault_discard_event = sup_system_fault_discard_event_o; // 对外输出：内部转发：supervisor产生的注册式故障episode丢弃选择器，外部abort不得驱动此端口
	assign o_system_fault_cause_valid = sup_system_fault_cause_valid_o; // 对外输出：内部转发：首个阻断故障原子快照是否已锁存
	assign o_system_fault_cause = sup_system_fault_cause_o;       // 对外输出：内部转发：首故障cause编码快照
	assign o_system_fault_source = sup_system_fault_source_o;     // 对外输出：内部转发：首故障来源编码快照
	assign o_system_fault_identity_valid = sup_system_fault_identity_valid_o; // 对外输出：内部转发：首故障绑定身份是否可信快照
	assign o_system_fault_frame_id = sup_system_fault_frame_id_o; // 对外输出：内部转发：首故障绑定事务的真实物理帧号快照
	assign o_system_fault_sample_index = sup_system_fault_sample_index_o; // 对外输出：内部转发：首故障绑定事务的全局顺序编号快照
	assign o_system_fault_color_ir = sup_system_fault_color_ir_o; // 对外输出：内部转发：首故障绑定事务的颜色身份快照
	assign o_system_fault_frame_type = sup_system_fault_frame_type_o; // 对外输出：内部转发：首故障绑定事务的帧类型编码快照
	assign o_system_fault_precision = sup_system_fault_precision_o; // 对外输出：内部转发：首故障绑定事务建立时所属的精度模式快照
	assign o_system_fault_run_generation = sup_system_fault_run_generation_o; // 对外输出：内部转发：首故障绑定事务所属的RUN代际快照
	assign o_system_fault_summary = sup_system_fault_summary_o;   // 对外输出：内部转发：按位记录的历史阻断故障来源汇总
	assign o_result_discard_summary_sticky = sup_result_discard_summary_sticky_o; // 对外输出：内部转发：正式结果生命周期丢弃历史sticky，非阻断

	// AMI正式结果discard公开观测，逐位来自AMI合同§6.10公开端口
	assign o_measurement_result_discard_event = ami_mr_discard_event_o; // 对外输出：内部转发：正式结果生命周期丢弃单拍观测，合同6.10节公开端口
	assign o_measurement_result_discard_reason = ami_mr_discard_reason_o; // 对外输出：内部转发：STOP、abort或系统故障三态丢弃原因，随事件保持稳定
	assign o_measurement_result_discard_identity_valid = ami_mr_discard_identity_valid_o; // 对外输出：内部转发：事件为高时恒为1，绑定TXN_ID可信
	assign o_measurement_result_discard_sample_valid = ami_mr_discard_sample_valid_o; // 对外输出：内部转发：被丢弃正式结果的独立样本资格快照
	assign o_measurement_result_discard_frame_id = ami_mr_discard_frame_id_o; // 对外输出：内部转发：被丢弃事务的真实物理帧号
	assign o_measurement_result_discard_sample_index = ami_mr_discard_sample_index_o; // 对外输出：内部转发：被丢弃事务的全局顺序编号
	assign o_measurement_result_discard_color_ir = ami_mr_discard_color_ir_o; // 对外输出：内部转发：被丢弃事务的颜色身份
	assign o_measurement_result_discard_frame_type = ami_mr_discard_frame_type_o; // 对外输出：内部转发：被丢弃事务的帧类型编码
	assign o_measurement_result_discard_precision = ami_mr_discard_precision_o; // 对外输出：内部转发：被丢弃事务建立时所属的精度模式
	assign o_measurement_result_discard_run_generation = ami_mr_discard_run_generation_o; // 对外输出：内部转发：被丢弃事务所属的RUN代际

	// AMI检测代际清空公开观测，逐位来自AMI合同§6.10公开端口
	assign o_detection_discard_event = ami_dd_event_o;            // 检测链保留分支被清空的公开广播事件
	assign o_detection_discard_reason = ami_dd_reason_o;          // 对外输出：内部转发：STOP、abort或系统故障三态原因编码，与私有广播共用同一来源
	assign o_detection_discard_identity_valid = ami_dd_identity_valid_o; // 对外输出：内部转发：触发广播时是否命中真实保留检测分支事务
	assign o_detection_discard_sample_valid = ami_dd_sample_valid_o; // 对外输出：内部转发：触发事务的独立样本资格快照
	assign o_detection_discard_frame_id = ami_dd_frame_id_o;      // 对外输出：内部转发：触发事务的真实物理帧号
	assign o_detection_discard_sample_index = ami_dd_sample_index_o; // 对外输出：内部转发：触发事务的全局顺序编号
	assign o_detection_discard_color_ir = ami_dd_color_ir_o;      // 对外输出：内部转发：触发事务的颜色身份
	assign o_detection_discard_frame_type = ami_dd_frame_type_o;  // 对外输出：内部转发：触发事务的帧类型编码
	assign o_detection_discard_precision = ami_dd_precision_o;    // 对外输出：内部转发：触发事务建立时所属的精度模式
	assign o_detection_discard_config_epoch = ami_dd_config_epoch_o; // 对外输出：内部转发：触发事务ACTIVE配置版本
	assign o_detection_discard_coef_epoch = ami_dd_coef_epoch_o;  // 对外输出：内部转发：触发事务Stage1系数版本
	assign o_detection_discard_dc_recovery_epoch = ami_dd_dc_recovery_epoch_o; // 对外输出：内部转发：触发事务DC恢复版本
	assign o_detection_discard_amb_code_epoch = ami_dd_amb_code_epoch_o; // 对外输出：内部转发：触发事务环境光抵消码提交版本
	assign o_detection_discard_dc_code_epoch = ami_dd_dc_code_epoch_o; // 对外输出：内部转发：触发事务颜色DC码提交版本
	assign o_detection_discard_run_generation = ami_dd_run_generation_o; // 对外输出：内部转发：触发广播目标的RUN代际

	//---------------P2S遥测边界透传---------------//
	assign o_s1_calibration_applied = ami_s1_calibration_applied_o; // 对外输出：内部转发：DC恢复自己原子事务载荷重新导出的Stage1校准资格
	assign o_s1_raw = ami_s1_raw_o;                // 对外输出：内部转发：Stage1物理判决位，取自AMI自己重新导出的atomic payload_o
	assign o_s2_raw = ami_s2_raw_o;                // 对外输出：内部转发：第二级冗余物理判决位，与o_s1_raw锁在同一拍

endmodule

