`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/26
// Design Name:        PPG ADC Numeric Code Scoreboard Testbench
// Module Name:        tb_ppg_control_top_adc_numeric_scoreboard
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md
//                      PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md
//                      PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.1
// Revision Date:      2026/09/28
// History:
//    Time               Version       Revised by            Contents
// 2026/09/28            V1.1          Erie                  Workline-D independent recheck (NRE+ADCN batch) found this file's own identity-binding check only verified 5 of the contract's 10 named ADCN-07 fields (precision/config_epoch/coef_epoch/stage2_coef_epoch/dc_coef_epoch) -- frame_id/sample_index were captured into reg_cap_* but never compared against anything (dead reads), color_ir/frame_type were declared as ports but never read at all, and amb/dc code epochs were entirely absent; the AMB/DC code snapshot values themselves were only fed into the downstream golden model as a given input (self-consistency), never independently checked against what the transaction's owner actually committed. Also found ADCN-03's "matching exclusive saturation diagnostic" clause was only inferred indirectly (checking that the clamped value hit -2048/+2047), never checking the real o_saturation_low/o_saturation_high ports on ppg_adc_s1_programmable_calibrator.v itself (which exist, are correctly implemented, and are already tagged @satisfies: ADCN-03, just not routed to ppg_control_top's own top-level ports). Before fixing, cross-checked PPG_ALIAS_MAPPING_TABLE.md's existing entries for both IDs and found they already cited cross-file evidence (tb_ppg_adc_s1_programmable_calibrator.v's CAL-06/CAL-07 for ADCN-03; tb_ppg_control_top_owner_identity_backpressure.v's OIB-07 for ADCN-07) -- independently verifying both citations found the CAL-06/CAL-07 citation genuinely accurate (real, direct o_saturation_low/high checks, both legal-endpoint and saturating cases, mutual exclusivity), but the OIB-07 citation overstated its own coverage: OIB-07's own comment and FAIL message text confirm it checks only frame/sample/color/precision, never frame_type or either code snapshot/epoch, contradicting the alias table's claim of full frame/sample/color/frame_type/AMB-DC-snapshot/AMB-DC-epoch coverage. Net effect: ADCN-03 was already fully covered (this recheck's own initial "gap" conclusion was incomplete, from skipping the cross-file check this project's own methodology requires); ADCN-07's frame_id/sample_index/color_ir were already covered by OIB-07 in a different scenario, but frame_type and both AMB/DC code epochs were genuinely never verified anywhere. Fixed by adding a direct hierarchical read of o_saturation_low/o_saturation_high (captured in the same always block and same clock edge as the existing reg_cap_s1_value, into new reg_cap_s1_saturation_low/high) for ADCN-03, and by extending the existing owner-commit snapshot process (reg_owner_snapshot_*) to also capture color_ir/frame_type/sample_index/amb_code_snapshot/dc_code_snapshot/amb_code_epoch/dc_code_epoch from ppg_control_top.v's already-forwarded internal wires (sched_adc_owner_color_ir_o etc., same declaration site as the already-used precision_mode_o/frame_id_o) for ADCN-07, then adding a real 8-field identity-binding comparison against the matching o_result_* captures -- this makes the scoreboard file fully self-contained for both clauses rather than depending on cross-file arguments, in addition to (not replacing) the pre-existing evidence. Real dual-tool confirmation: iverilog and Vivado 2022.2 xsim both produced ADC_NUMERIC_SCOREBOARD_TB_PASS result_captures=16 track_branch_fires=16, 0 FAIL, bit-for-bit identical between tools, including both real saturating transactions (Phase C1/C2) correctly asserting exactly one of the two new diagnostic checks. Change confined entirely to this file; no RTL and no shared TB file touched, so the official 19-TB suite was not rerun (zero blast radius, consistent with this project's established practice for single-file TB-only fixes). See NRE_ADCN_WORKLINE_D_INDEPENDENT_RECHECK_20260928.md for the complete investigation including the self-correction on the initial recheck's methodology gap.
// 2026年09月28日        V1.1          Erie                  工作线D独立复核(NRE+ADCN批次)发现本文件自己的身份绑定检查只真实核对了合同10个具名ADCN-07字段里的5个(precision/config_epoch/coef_epoch/stage2_coef_epoch/dc_coef_epoch)——frame_id/sample_index被读进reg_cap_*却从未跟任何期望值比较过(死读)，color_ir/frame_type端口声明了却从未被读取，AMB/DC code的epoch完全没涉及；AMB/DC code快照值本身也只是原样喂给下游黄金模型当输入(自洽性检查)，从未独立核对"这个值是不是这笔事务owner真正commit的那个值"。同时发现ADCN-03"配套互斥饱和诊断"这半句此前只是间接推断(核对钳位值是否命中-2048/+2047)，从未检查`ppg_adc_s1_programmable_calibrator.v`自己真实存在、已带`@satisfies: ADCN-03`标签的`o_saturation_low/high`端口(只是没连到`ppg_control_top`顶层)。动手修复前先核对`PPG_ALIAS_MAPPING_TABLE.md`既有台账，发现这两条ID台账里早有跨文件引用(`tb_ppg_adc_s1_programmable_calibrator.v`的CAL-06/CAL-07给ADCN-03；`tb_ppg_control_top_owner_identity_backpressure.v`的OIB-07给ADCN-07)——独立核实两条引用后确认CAL-06/CAL-07真实准确(真的直接检查`o_saturation_low/high`，合法端点和越界端点都对、互斥性也对)，但OIB-07这条引用本身夸大了覆盖范围：OIB-07自己的注释和FAIL消息原文只检查frame/sample/color/precision，从未检查frame_type或任何一个code快照/epoch，与台账声称的"frame/sample/color/frame_type/AMB-DC快照/AMB-DC epoch全覆盖"不符。净结果：ADCN-03其实早已被完整覆盖(本次复核最初的"缺口"判断本身不完整，是漏做了这个项目一贯要求的跨文件核实这一步)；ADCN-07的frame_id/sample_index/color_ir确实已经被OIB-07在另一个场景下覆盖过，但frame_type和两个AMB/DC code epoch是真实、从未被任何地方验证过的缺口。修复方式：ADCN-03新增对`o_saturation_low/o_saturation_high`的直接层次引用读取(与既有`reg_cap_s1_value`同一个always块、同一拍捕获，存入新增的`reg_cap_s1_saturation_low/high`)；ADCN-07扩展既有的owner提交快照进程(`reg_owner_snapshot_*`)，从`ppg_control_top.v`已经转发好的内部wire(`sched_adc_owner_color_ir_o`等，与已经在用的`precision_mode_o`/`frame_id_o`同一处声明)补齐`color_ir`/`frame_type`/`sample_index`/`amb_code_snapshot`/`dc_code_snapshot`/`amb_code_epoch`/`dc_code_epoch`七个字段的快照，新增一条真实的8字段身份绑定核对，与对应的`o_result_*`结果字段比较——让这份scoreboard文件自己对这两条ID都能独立自证，不再依赖跨文件论证，是既有证据之外的补强，不是替代。真实双工具确认：iverilog和Vivado 2022.2 xsim均产出`ADC_NUMERIC_SCOREBOARD_TB_PASS result_captures=16 track_branch_fires=16`，0 FAIL，两工具逐位一致，含两笔真实饱和事务(阶段C1/C2)各自只命中新增两个诊断检查里的一个。改动完全局限在本文件内，未碰RTL、未碰共享TB文件，未重跑全套19-TB(blast radius为零，符合本项目对单文件TB修复的既有惯例)。完整调查过程(含本次复核方法论本身缺口的自我订正)见`NRE_ADCN_WORKLINE_D_INDEPENDENT_RECHECK_20260928.md`。
// 2026/08/26            V1.0          Erie                  Create file. Stage 5 Group 11 (ADC-NUMERIC-CODE-SCOREBOARD, ADCN-01 through ADCN-10, C25 contract section 9.4.6). Unlike Group1-5, this group does not want the physiological RAW generator's continuous waveform -- it wants deterministic, individually chosen RAW codes so every acceptance ID can be pinned to a specific, independently recomputed golden-model value, so `tb_ppg_real_raw_generator.vh` is not included here; each transaction is driven explicitly by this file's own sequential driver rather than a background bg_responder loop. Reuses the proven real-2MHz-clock/JNT-01~09-prefix/wait_q3_release/drive_real_adc_done/make_fixed_raw infrastructure verbatim from tb_ppg_control_top_baseline_cross.v. Four independently-committed calibration configs exercise four scenario phases in one JNT-prefixed run (no result or state carried between phases; each phase is a fresh legal COMMIT+START+STOP+drain cycle per section 9.1's own group-entry rule, after the single shared JNT-01~09 baseline that opens the file): Phase A (SAR9, C11's real nominal Stage1 weights, same coefficients Group1-5 use) drives five representative RAW codes across the reachable [8,503] window for ADCN-01/04/07/09/08/09; Phase B (SAR9, a small custom config: stage1_weight_q16_4=+32768/stage1_weight_q16_5=-32768, every other weight and the offset zeroed) drives codes 8/16/24 producing 0/+1/-1, an exact Q16 half-LSB tie in both directions for ADCN-02 -- C11's real nominal weights are all exact multiples of 65536 so no code can ever produce a real rounding remainder under them, making a dedicated non-nominal config the only way to actually exercise the tie-breaking arithmetic; Phase C is two independently committed configs (all ten weights zeroed, only stage1_offset_q16 set to +196608000/-196608000 respectively) each driving one code to force the signed-12-bit accumulator to saturate high/low for ADCN-03; Phase D commits run_profile=CHARACTERIZATION with optical_mode=RED and initial_precision=SAR15 (C11's nominal Stage1 weights plus this project's already-used representative stage2_gain_q16/stage2_offset_q16) and drives three representative codes for ADCN-05/06. ADCN-08 (public-result backpressure) is proven inside Phase A by holding i_measurement_result_ready low across one transaction, mirroring tb_ppg_control_top.v's SMOKE-17/OIB-03-adjacent pattern. ADCN-10 (only Stage1 evidence may reach the IDAC tracking comparator) is proven structurally (the fork in `ppg_adc_measurement_idac_integration.v` splits the single shared Stage1 net into its measurement and track branches strictly upstream of DC-recovery/reconstruction) and reinforced by a per-cycle runtime monitor comparing the two branches' held values.
//                                                             Five real, non-obvious bugs were found and fixed getting the first real iverilog run to pass, none of them RTL defects -- all in this file's own first-draft design: (1) the JNT-01~09 prefix internally calls fixed task names `task_build_normal_manual_config`/`_dual_config` to build its own legal setup, and this file had pointed both at its own single-RED-only Phase-A config; JNT-03A specifically requires a real IR-colored owner at sample_index 1, which a RED-only config can never produce, so 2/53 JNT checks failed until these two names were given their own proper IR/dual-optical config copied from tb_ppg_control_top_baseline_cross.v, reserved solely for the JNT prefix's internal use. (2) The original Stage1 golden-model call fed `target_code` (the semantic RAW value make_fixed_raw is asked to encode) directly into the per-bit weighted-sum model; tracing `ppg_adc_s1_redundancy_corrector.v` (`stage1_raw_o <= i_capture_stage1_raw`, an unmodified register passthrough with no decode at all) proved the calibrator actually receives make_fixed_raw's *encoded physical bus value* verbatim -- target_code only reappears as the calibrated output because make_fixed_raw's redundant encoding is specifically the inverse of C11's nominal per-bit weighting, a coincidence that only holds under nominal weights. Every Phase A/B/C mismatch (calibrated output silently identical to target_code, never touching the committed weights at all) traced to this one wrong input; fixed by passing the actual encoded `raw_code` local instead. (3) `stage1_weight_q16_k` fields are only 26-bit signed (~±512.0 real range) -- nowhere near enough for a single weighted bit to force a >2047 accumulator by itself, so the first saturation design (isolated huge per-bit weights) was arithmetically impossible under the real field width; switched Phase C to using the 32-bit `stage1_offset_q16` field alone (all weights zero), which has ample range and saturates unconditionally regardless of which RAW bits are set. (4) The first Phase D design tried to commit `run_profile=NORMAL_PPG` with `initial_precision=SAR15` directly, not remembering that this exact combination is MGR-16/18's own statically-illegal pair (independently confirmed by tb_ppg_control_top.v's SMOKE-22) -- the commit was rejected and the phase never started; fixed by using the already-established legal path to a real fixed SAR15 transaction, `run_profile=CHARACTERIZATION`+`optical_mode=RED`, matching tb_ppg_control_top.v's task_build_char_photodiode_red_sar15_config. This also meant `o_result_stage2_coef_epoch` legitimately reads back as 0 for every SAR9 transaction (Stage2 is never invoked, so the result interface does not bind an epoch to it) rather than tracking every COMMIT like the other three epoch fields -- the identity/epoch check was narrowed to only require stage2-epoch agreement when precision_mode=SAR15. (5) The ADCN-10 per-transaction monitor originally compared the track branch's live value against the top-level `o_calibrated_s1_value` at the moment the track branch fired, and failed on the very first real transaction -- `o_calibrated_s1_value` is a held RESULT signal that only updates once the measurement branch's own, independently-paced consumption completes several cycles later (possibly still showing an older, unconsumed transaction), not synchronized with the track branch's own handshake at all; switched the comparison to the fork's own sibling output (`dec_measurement_s1_value`), which per section 9.5.1's own "each branch holds its own snapshot, loaded together at fork entry" requirement is synchronized with the track branch by construction. After all five fixes: real iverilog run, JNT_BASELINE 53/53 PASS, all sixteen driven transactions produce non-trivial computed values that independently match this file's recomputed golden model bit-for-bit (including real saturation to exactly +2047/-2048 and real ties resolving to exactly 0/+1/-1), zero mismatches: `ADC_NUMERIC_SCOREBOARD_TB_PASS result_captures=16 track_branch_fires=16`.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月26日
// 设计名称:           PPG ADC数值码值记分板测试平台
// 模块名称:           tb_ppg_control_top_adc_numeric_scoreboard
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md
//                      PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md
//                      PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.0
// 修订日期:           2026年08月26日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月26日        V1.0          Erie                  创建文件。Stage 5第11组（ADC-NUMERIC-CODE-SCOREBOARD，ADCN-01~10，C25合同9.4.6节）。和Group1~5不同，本组不需要生理RAW生成器的连续波形，需要的是可以逐笔精确指定的RAW码，让每条验收ID都能绑定一个独立重算的黄金模型值，所以本文件不`include tb_ppg_real_raw_generator.vh`，每笔事务由本文件自己的顺序驱动逻辑显式发起，不是后台bg_responder循环。原样复用`tb_ppg_control_top_baseline_cross.v`已验证过的真实2MHz时钟/JNT-01~09前缀/`wait_q3_release`/`drive_real_adc_done`/`make_fixed_raw`基础设施。在同一次JNT前缀运行里（文件开头共用一次JNT-01~09基线之后），四个独立提交的校准配置驱动四个场景阶段（阶段之间不带任何结果或状态，每个阶段都是9.1节自己规定的"全新合法COMMIT+START+STOP+排空"周期）：阶段A（SAR9，C11合同自己的标称Stage1权重，和Group1~5用的系数完全一致）在可达的[8,503]窗口内驱动五个代表性RAW码，覆盖ADCN-01/04/07/08/09；阶段B（SAR9，一份专门构造的配置：只有stage1_weight_q16_4=+32768、stage1_weight_q16_5=-32768非零，其余权重和offset全部清零）驱动码值8/16/24，分别产生0/+1/-1，正负两个方向各一次精确的Q16半LSB舍入临界，覆盖ADCN-02——C11真实标称权重全部是65536的整数倍，任何码值在这组权重下都不可能产生真正的舍入余数，专门构造一份非标称配置是唯一能真正触碰到舍入判定逻辑的办法；阶段C是两次独立提交的配置（十个权重全部清零，只有stage1_offset_q16分别设成+196608000/-196608000），各驱动一笔事务让有符号12-bit累加器正向/负向饱和，覆盖ADCN-03；阶段D提交run_profile=CHARACTERIZATION+optical_mode=RED+initial_precision=SAR15（C11标称Stage1权重加上本项目其它地方已经在用的代表性stage2_gain_q16/stage2_offset_q16），驱动三个代表性码，覆盖ADCN-05/06。ADCN-08（正式结果公开背压）在阶段A内部完成，和`tb_ppg_control_top.v`已经证实过的SMOKE-17/OIB-03同类模式一致。ADCN-10（只有Stage1证据能到达IDAC跟踪比较器）用结构性论证（`ppg_adc_measurement_idac_integration.v`的fork在DC恢复/重建之前就把共享的Stage1值分叉给测量分支和跟踪分支）加一个逐拍运行时监视进程共同证明。
//                                                             为了拿到第一次真实iverilog跑通的证据，本轮排查并修复了五个真实问题，全部是本文件自己第一版设计的问题，不是RTL缺陷：（1）JNT-01~09前缀内部固定调用`task_build_normal_manual_config`/`_dual_config`两个task名构造它自己的合法配置，本文件最初把这两个名字都指向了阶段A的单RED配置——JNT-03A明确要求真的出现过一笔sample_index=1的IR身份owner，单RED配置永远产不出这个，导致JNT53项检查里有2项FAIL，修复方式是给这两个标准task名单独提供一份照抄`tb_ppg_control_top_baseline_cross.v`的IR/双光配置，专供JNT前缀内部自用，不影响本文件后面四个阶段各自的独立提交。（2）Stage1黄金模型最初直接拿`target_code`（要求`make_fixed_raw`编码的语义RAW值）喂给逐位加权求和公式；追查`ppg_adc_s1_redundancy_corrector.v`发现`stage1_raw_o<=i_capture_stage1_raw`是原样寄存器转发、完全没有解码——calibrator真正收到的是`make_fixed_raw`编码后的物理总线值本身，target_code只是在C11标称权重下才会被重新拼回来（因为`make_fixed_raw`的冗余编码本来就是C11标称逐位权重的逆运算，这个巧合只在标称权重下成立）。阶段A/B/C最初全部"校准输出原样等于target_code、完全没碰过提交的权重"的失败现象都来自这一处输入错误，改成喂真实编码后的`raw_code`局部变量后解决。（3）`stage1_weight_q16_k`字段只有26-bit（真实取值范围约±512.0），单个权重位单独作用永远不足以把累加器推过±2047——第一版"孤立巨大单位权重"的饱和设计在这个字段位宽下根本不可能实现；改用32-bit的`stage1_offset_q16`字段单独承担饱和测试（全部权重清零），取值空间大得多，且与raw_code具体是什么完全无关，必定饱和。（4）阶段D最初直接尝试提交run_profile=NORMAL_PPG+initial_precision=SAR15，忘了这正是MGR-16/18自己的静态非法组合表（`tb_ppg_control_top.v`的SMOKE-22已经confirmed过）——COMMIT被拒绝，阶段D根本没能启动；修复为改用已经确立的合法固定SAR15路径：run_profile=CHARACTERIZATION+optical_mode=RED，与`tb_ppg_control_top.v`的`task_build_char_photodiode_red_sar15_config`同源。这也意味着`o_result_stage2_coef_epoch`在SAR9事务下按设计恒为0（Stage2从未真正参与运算，结果接口不会为它绑定任何版本），不像另外三个epoch字段那样随每次COMMIT自增——身份/epoch核对相应改为只在precision_mode=SAR15时才要求stage2 epoch一致。（5）ADCN-10逐笔监视进程最初在跟踪分支握手那一拍去比较顶层`o_calibrated_s1_value`，第一笔真实事务就报FAIL——`o_calibrated_s1_value`是要等measurement分支自己独立消费节奏走完整条流水线之后才更新的保持型结果（可能还压着上一笔尚未消费的旧值），和跟踪分支自己的握手时刻完全不对齐；改为比较fork自己的兄弟分支输出`dec_measurement_s1_value`，按合同9.5.1节"各分支独立持有资格快照、fork接纳新事务时一起装载"的要求，这两路输出理应天然同步。五处修复完成后：真实iverilog跑通，`JNT_BASELINE 53/53 PASS`，驱动的全部十六笔事务算出的数值都是非平凡真实值，逐位匹配本文件独立重算的黄金模型（包含真实饱和到恰好+2047/-2048、真实舍入临界恰好落到0/+1/-1），零失配：`ADC_NUMERIC_SCOREBOARD_TB_PASS result_captures=16 track_branch_fires=16`。
//
// 复位后跑通JNT-01~09基线，随后依次提交四份独立校准配置（SAR9标称权重、SAR9
// 舍入临界权重、SAR9饱和权重、SAR15标称权重），每份配置下逐笔驱动预先选定的RAW
// 码并独立重算Stage1/DC恢复/Stage2重建三段黄金模型，核对ADCN-01~10全部十条
// 验收ID
module tb_ppg_control_top_adc_numeric_scoreboard();

	//---------------配置参数区域---------------//
	localparam integer C_FRAME_ID_WIDTH = 16; // 与DUT默认参数一致
	localparam integer C_SAMPLE_INDEX_WIDTH = 16; // 与DUT默认参数一致
	localparam integer C_CONFIG_WIDTH = 1024; // 与DUT默认参数一致
	localparam integer C_CODE_EPOCH_WIDTH = 4; // 与DUT默认参数一致
	localparam integer C_RUN_GENERATION_WIDTH = 8; // 与DUT默认参数一致
	localparam [1:0] ST_CONFIG = 2'b00; // manager CONFIG生命周期编码
	localparam [1:0] ST_READY = 2'b01; // manager READY生命周期编码
	localparam [1:0] ST_RUN = 2'b10; // manager RUN生命周期编码
	localparam [1:0] ST_STOPPING = 2'b11; // manager STOPPING生命周期编码

	//---------------场景控制参数---------------//
	localparam time C_SIM_TIMEOUT_NS = 64'd2000000000; // 2秒安全看门狗上限，本组事务数很少，远用不到这么长
	localparam integer C_RESULT_WAIT_TIMEOUT_CYCLES = 20000; // 单笔事务等待正式结果的安全上限

	// 以下V5默认字段值与ppg_system_config_manager.v的V5_RESET_PROFILE逐项一致，
	// 只用于凑出一份合法1024-bit联合快照；本组不exercising峰谷/基线算法，
	// peak_valley_config_valid保持复位默认0即可（探测器合法拒绝发布事件，不影响
	// 本组只关心的Stage1/DC恢复/重建数值链路）
	localparam [383:0] V5_RESET_PROFILE_REF = {
		14'd0,                                  // reserved_v5复位归零
		1'b0,                                   // peak_valley_config_valid复位不可用
		16'd1000,                               // max_reacquire_frames
		16'd600,                                // max_fine_window_frames
		16'd100,                                // min_peak_to_peak_frames
		16'd20,                                 // min_peak_to_valley_frames
		24'd20,                                 // min_peak_valley_amplitude
		24'd2,                                  // direction_deadband
		4'd3,                                   // valley_confirm_count
		4'd3,                                   // peak_confirm_count
		4'd2,                                   // no_cross_limit
		4'd3,                                   // cross_confirm_count
		16'd19,                                 // lead_max_frames
		16'd17,                                 // lead_min_frames
		32'd131072,                             // cross_hysteresis_q16
		32'sd0,                                 // baseline_delta_q16
		-32'sd8192,                             // slope_max_q16
		-32'sd262144,                           // slope_min_q16
		16'h0800,                               // timing_adjust_ratio_q15
		16'h2000,                               // beta_q15
		16'h199A,                               // alpha_q15
		-32'sd65536,                            // fixed_slope_q16
		1'b1                                    // slope_mode=ADAPTIVE
	};

	//---------------全局时钟与复位信号---------------//
	reg i_clk; // 真实2 MHz系统时钟
	reg i_rstn; // 系统域低有效复位
	reg i_source_clk; // SPI配置源域仿真时钟
	reg i_source_rstn; // 源域低有效复位

	//---------------V4+V5源域配置信号---------------//
	reg [C_CONFIG_WIDTH - 1:0] i_source_config_snapshot; // 待提交的1024-bit联合快照
	reg i_source_config_update_event; // 快照传输请求单拍

	//---------------表征source信号---------------//
	reg i_source_characterization_update_valid; // 本轮不驱动表征更新，恒0
	reg i_source_static_characterization_enable; // 本轮不使用STATIC_BIAS，恒0
	reg [4:0] i_source_test_mux_ctrl; // 本轮不使用测试MUX，恒0

	//---------------已同步生命周期与诊断信号---------------//
	reg i_start_event; // START单拍
	reg i_stop_event; // STOP单拍
	reg i_diag_clear_event; // 本轮不触发诊断清除，恒0
	reg i_control_abort_event; // 本轮不触发abort，恒0

	//---------------物理ADC与模拟边界信号---------------//
	reg [9:0] i_dout_stage1_low; // Stage1物理判决码激励
	reg i_clk_stage1_dout_low_async; // Stage1异步完成脉冲激励
	reg [9:0] i_dout_stage2_low; // Stage2物理判决码激励
	reg i_clk_stage2_dout_low_async; // Stage2异步完成脉冲激励，同时携带精度位
	reg i_adc_physical_idle; // 物理ADC空闲电平，仅在响应窗口内短暂拉低
	reg i_analog_ready; // 模拟就绪聚合结果，本轮恒1

	//---------------正式结果消费者信号---------------//
	reg i_measurement_result_ready; // ADCN-08背压场景之外恒接受

	//---------------验证专用异常注入信号---------------//
	reg i_test_inject_enable; // 本组不使用验证注入，恒0
	reg i_test_identity_inject_valid; // 恒0
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] i_test_identity_inject_sample_index; // 恒0
	reg i_test_invalid_sample_valid; // 恒0

	//---------------SSW模拟控制原样输出---------------//
	wire o_en_tia_low, o_leden1_low, o_leden2_low, o_en_test;
	wire [7:0] o_leddac;
	wire o_clk_buf_low, o_clk_iref_idac_low, o_clk_9q1_low, o_clk_15q1_low, o_clk_aferst_low;
	wire o_clk_iref_idac_sar9_low, o_clk_iref_idac_sar15_low, o_clk_q2_low, o_clk_q3_low, o_clk_tiaen_low;
	wire o_en_15sar_low, o_en_sar9_amb_low, o_en_sar9_dc_low, o_en_sar9_iref;
	wire o_en_sar15_amb_low, o_en_sar15_dc_low, o_en_sar15_iref;
	wire [7:0] o_idac_sar9ambn_low, o_idac_sar9dcn_low, o_idac_sar15ambn_low, o_idac_sar15dcn_low;
	wire [4:0] o_s_in;
	wire o_clk_2m;

	//---------------AMI正式测量结果输出---------------//
	wire o_measurement_result_valid;
	wire signed [23:0] o_coarse_ppg_value, o_fine_ppg_value;
	wire o_coarse_valid, o_coarse_recovery_calibrated, o_coarse_saturation_low, o_coarse_saturation_high;
	wire o_fine_valid, o_fine_recovery_calibrated, o_fine_saturation_low, o_fine_saturation_high;
	wire signed [11:0] o_calibrated_s1_value;
	wire signed [14:0] o_programmable_15_code;
	wire o_programmable_15_valid;
	wire [7:0] o_result_config_epoch, o_result_coef_epoch, o_result_stage2_coef_epoch, o_result_dc_coef_epoch;
	wire o_result_precision_mode;
	wire [C_FRAME_ID_WIDTH - 1:0] o_result_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_result_sample_index;
	wire o_result_color_ir;
	wire [1:0] o_result_frame_type;
	wire [7:0] o_result_amb_code_snapshot, o_result_dc_code_snapshot;
	wire [C_CODE_EPOCH_WIDTH - 1:0] o_result_amb_code_epoch, o_result_dc_code_epoch;
	wire o_result_sample_valid;

	//---------------V4/V5生命周期ACK与错误输出---------------//
	wire [1:0] o_lifecycle_state;
	wire o_start_ready, o_commit_ack_event, o_start_ack_event, o_stop_ack_event, o_error_event;
	wire o_commit_ack_sticky, o_error_sticky;
	wire [7:0] o_last_error_code, o_schema_version, o_config_epoch, o_coef_epoch, o_stage2_coef_epoch, o_dc_recovery_coef_epoch;

	//---------------调度器/AMI/SSW只读诊断输出---------------//
	wire o_scheduler_idle, o_scheduler_launch_timeout_sticky, o_scheduler_owner_deadline_timeout_sticky;
	wire o_scheduler_completion_mismatch_sticky, o_scheduler_protocol_error_sticky;
	wire o_ami_datapath_empty, o_ami_idac_idle, o_ami_integration_protocol_error_sticky;
	wire o_ssw_wrapper_idle, o_ssw_switch_protocol_error_sticky, o_ssw_transaction_mismatch_sticky;
	wire o_ssw_owner_deadline_timeout_sticky, o_ssw_calibration_timeout_sticky;

	//---------------表征控制source握手与诊断输出---------------//
	wire o_source_characterization_update_ready, o_characterization_control_valid;
	wire o_characterization_control_update_event, o_characterization_control_reject_event;
	wire o_characterization_protocol_error_sticky;

	//---------------验证专用异常注入应答输出---------------//
	wire o_test_identity_inject_ready, o_test_invalid_sample_ready;

	//---------------注册式系统故障/abort监督输出---------------//
	wire o_system_fault_blocking, o_system_abort_event, o_system_stop_request_event, o_system_fault_discard_event;
	wire o_system_fault_cause_valid;
	wire [7:0] o_system_fault_cause;
	wire [3:0] o_system_fault_source;
	wire o_system_fault_identity_valid;
	wire [C_FRAME_ID_WIDTH - 1:0] o_system_fault_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_system_fault_sample_index;
	wire o_system_fault_color_ir;
	wire [1:0] o_system_fault_frame_type;
	wire o_system_fault_precision;
	wire [C_RUN_GENERATION_WIDTH - 1:0] o_system_fault_run_generation;
	wire [15:0] o_system_fault_summary;
	wire o_result_discard_summary_sticky;

	//---------------AMI discard公开观测输出---------------//
	wire o_measurement_result_discard_event;
	wire [1:0] o_measurement_result_discard_reason;
	wire o_measurement_result_discard_identity_valid, o_measurement_result_discard_sample_valid;
	wire [C_FRAME_ID_WIDTH - 1:0] o_measurement_result_discard_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_measurement_result_discard_sample_index;
	wire o_measurement_result_discard_color_ir;
	wire [1:0] o_measurement_result_discard_frame_type;
	wire o_measurement_result_discard_precision;
	wire [C_RUN_GENERATION_WIDTH - 1:0] o_measurement_result_discard_run_generation;

	wire o_detection_discard_event;
	wire [1:0] o_detection_discard_reason;
	wire o_detection_discard_identity_valid, o_detection_discard_sample_valid;
	wire [C_FRAME_ID_WIDTH - 1:0] o_detection_discard_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_detection_discard_sample_index;
	wire o_detection_discard_color_ir;
	wire [1:0] o_detection_discard_frame_type;
	wire o_detection_discard_precision;
	wire [7:0] o_detection_discard_config_epoch, o_detection_discard_coef_epoch, o_detection_discard_dc_recovery_epoch;
	wire [C_CODE_EPOCH_WIDTH - 1:0] o_detection_discard_amb_code_epoch, o_detection_discard_dc_code_epoch;
	wire [C_RUN_GENERATION_WIDTH - 1:0] o_detection_discard_run_generation;

	//---------------自检计数与状态信号---------------//
	integer cnt_error; // 累计FAIL数
	integer cnt_measurement_result_valid; // 观测到的正式结果次数
	reg flag_global_timeout; // 全局看门狗超时标记

	//---------------DUT实例化---------------//
	// C01顶层：聚合全部6个直接子模块的唯一数字功能顶层
	ppg_control_top
		#(
			.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),
			.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH),
			.C_CONFIG_WIDTH(C_CONFIG_WIDTH),
			.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH),
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH)
		)
		ppg_control_top_Inst(
			.i_clk(i_clk),
			.i_rstn(i_rstn),
			.i_source_clk(i_source_clk),
			.i_source_rstn(i_source_rstn),
			.i_source_config_snapshot(i_source_config_snapshot),
			.i_source_config_update_event(i_source_config_update_event),
			.i_source_characterization_update_valid(i_source_characterization_update_valid),
			.i_source_static_characterization_enable(i_source_static_characterization_enable),
			.i_source_test_mux_ctrl(i_source_test_mux_ctrl),
			.i_start_event(i_start_event),
			.i_stop_event(i_stop_event),
			.i_diag_clear_event(i_diag_clear_event),
			.i_control_abort_event(i_control_abort_event),
			.i_dout_stage1_low(i_dout_stage1_low),
			.i_clk_stage1_dout_low_async(i_clk_stage1_dout_low_async),
			.i_dout_stage2_low(i_dout_stage2_low),
			.i_clk_stage2_dout_low_async(i_clk_stage2_dout_low_async),
			.i_adc_physical_idle(i_adc_physical_idle),
			.i_analog_ready(i_analog_ready),
			.i_measurement_result_ready(i_measurement_result_ready),
			.i_test_inject_enable(i_test_inject_enable),
			.i_test_identity_inject_valid(i_test_identity_inject_valid),
			.i_test_identity_inject_sample_index(i_test_identity_inject_sample_index),
			.i_test_invalid_sample_valid(i_test_invalid_sample_valid),
			.o_en_tia_low(o_en_tia_low),
			.o_leddac(o_leddac),
			.o_leden1_low(o_leden1_low),
			.o_leden2_low(o_leden2_low),
			.o_en_test(o_en_test),
			.o_clk_buf_low(o_clk_buf_low),
			.o_clk_iref_idac_low(o_clk_iref_idac_low),
			.o_clk_9q1_low(o_clk_9q1_low),
			.o_clk_15q1_low(o_clk_15q1_low),
			.o_clk_aferst_low(o_clk_aferst_low),
			.o_clk_iref_idac_sar9_low(o_clk_iref_idac_sar9_low),
			.o_clk_iref_idac_sar15_low(o_clk_iref_idac_sar15_low),
			.o_clk_q2_low(o_clk_q2_low),
			.o_clk_q3_low(o_clk_q3_low),
			.o_clk_tiaen_low(o_clk_tiaen_low),
			.o_en_15sar_low(o_en_15sar_low),
			.o_en_sar9_amb_low(o_en_sar9_amb_low),
			.o_en_sar9_dc_low(o_en_sar9_dc_low),
			.o_en_sar9_iref(o_en_sar9_iref),
			.o_en_sar15_amb_low(o_en_sar15_amb_low),
			.o_en_sar15_dc_low(o_en_sar15_dc_low),
			.o_en_sar15_iref(o_en_sar15_iref),
			.o_idac_sar9ambn_low(o_idac_sar9ambn_low),
			.o_idac_sar9dcn_low(o_idac_sar9dcn_low),
			.o_idac_sar15ambn_low(o_idac_sar15ambn_low),
			.o_idac_sar15dcn_low(o_idac_sar15dcn_low),
			.o_s_in(o_s_in),
			.o_clk_2m(o_clk_2m),
			.o_measurement_result_valid(o_measurement_result_valid),
			.o_coarse_ppg_value(o_coarse_ppg_value),
			.o_coarse_valid(o_coarse_valid),
			.o_coarse_recovery_calibrated(o_coarse_recovery_calibrated),
			.o_coarse_saturation_low(o_coarse_saturation_low),
			.o_coarse_saturation_high(o_coarse_saturation_high),
			.o_fine_ppg_value(o_fine_ppg_value),
			.o_fine_valid(o_fine_valid),
			.o_fine_recovery_calibrated(o_fine_recovery_calibrated),
			.o_fine_saturation_low(o_fine_saturation_low),
			.o_fine_saturation_high(o_fine_saturation_high),
			.o_calibrated_s1_value(o_calibrated_s1_value),
			.o_programmable_15_code(o_programmable_15_code),
			.o_programmable_15_valid(o_programmable_15_valid),
			.o_result_config_epoch(o_result_config_epoch),
			.o_result_coef_epoch(o_result_coef_epoch),
			.o_result_stage2_coef_epoch(o_result_stage2_coef_epoch),
			.o_result_dc_coef_epoch(o_result_dc_coef_epoch),
			.o_result_precision_mode(o_result_precision_mode),
			.o_result_frame_id(o_result_frame_id),
			.o_result_sample_index(o_result_sample_index),
			.o_result_color_ir(o_result_color_ir),
			.o_result_frame_type(o_result_frame_type),
			.o_result_amb_code_snapshot(o_result_amb_code_snapshot),
			.o_result_dc_code_snapshot(o_result_dc_code_snapshot),
			.o_result_amb_code_epoch(o_result_amb_code_epoch),
			.o_result_dc_code_epoch(o_result_dc_code_epoch),
			.o_result_sample_valid(o_result_sample_valid),
			.o_lifecycle_state(o_lifecycle_state),
			.o_start_ready(o_start_ready),
			.o_commit_ack_event(o_commit_ack_event),
			.o_start_ack_event(o_start_ack_event),
			.o_stop_ack_event(o_stop_ack_event),
			.o_error_event(o_error_event),
			.o_commit_ack_sticky(o_commit_ack_sticky),
			.o_error_sticky(o_error_sticky),
			.o_last_error_code(o_last_error_code),
			.o_schema_version(o_schema_version),
			.o_config_epoch(o_config_epoch),
			.o_coef_epoch(o_coef_epoch),
			.o_stage2_coef_epoch(o_stage2_coef_epoch),
			.o_dc_recovery_coef_epoch(o_dc_recovery_coef_epoch),
			.o_scheduler_idle(o_scheduler_idle),
			.o_scheduler_launch_timeout_sticky(o_scheduler_launch_timeout_sticky),
			.o_scheduler_owner_deadline_timeout_sticky(o_scheduler_owner_deadline_timeout_sticky),
			.o_scheduler_completion_mismatch_sticky(o_scheduler_completion_mismatch_sticky),
			.o_scheduler_protocol_error_sticky(o_scheduler_protocol_error_sticky),
			.o_ami_datapath_empty(o_ami_datapath_empty),
			.o_ami_idac_idle(o_ami_idac_idle),
			.o_ami_integration_protocol_error_sticky(o_ami_integration_protocol_error_sticky),
			.o_ssw_wrapper_idle(o_ssw_wrapper_idle),
			.o_ssw_switch_protocol_error_sticky(o_ssw_switch_protocol_error_sticky),
			.o_ssw_transaction_mismatch_sticky(o_ssw_transaction_mismatch_sticky),
			.o_ssw_owner_deadline_timeout_sticky(o_ssw_owner_deadline_timeout_sticky),
			.o_ssw_calibration_timeout_sticky(o_ssw_calibration_timeout_sticky),
			.o_source_characterization_update_ready(o_source_characterization_update_ready),
			.o_characterization_control_valid(o_characterization_control_valid),
			.o_characterization_control_update_event(o_characterization_control_update_event),
			.o_characterization_control_reject_event(o_characterization_control_reject_event),
			.o_characterization_protocol_error_sticky(o_characterization_protocol_error_sticky),
			.o_test_identity_inject_ready(o_test_identity_inject_ready),
			.o_test_invalid_sample_ready(o_test_invalid_sample_ready),
			.o_system_fault_blocking(o_system_fault_blocking),
			.o_system_abort_event(o_system_abort_event),
			.o_system_stop_request_event(o_system_stop_request_event),
			.o_system_fault_discard_event(o_system_fault_discard_event),
			.o_system_fault_cause_valid(o_system_fault_cause_valid),
			.o_system_fault_cause(o_system_fault_cause),
			.o_system_fault_source(o_system_fault_source),
			.o_system_fault_identity_valid(o_system_fault_identity_valid),
			.o_system_fault_frame_id(o_system_fault_frame_id),
			.o_system_fault_sample_index(o_system_fault_sample_index),
			.o_system_fault_color_ir(o_system_fault_color_ir),
			.o_system_fault_frame_type(o_system_fault_frame_type),
			.o_system_fault_precision(o_system_fault_precision),
			.o_system_fault_run_generation(o_system_fault_run_generation),
			.o_system_fault_summary(o_system_fault_summary),
			.o_result_discard_summary_sticky(o_result_discard_summary_sticky),
			.o_measurement_result_discard_event(o_measurement_result_discard_event),
			.o_measurement_result_discard_reason(o_measurement_result_discard_reason),
			.o_measurement_result_discard_identity_valid(o_measurement_result_discard_identity_valid),
			.o_measurement_result_discard_sample_valid(o_measurement_result_discard_sample_valid),
			.o_measurement_result_discard_frame_id(o_measurement_result_discard_frame_id),
			.o_measurement_result_discard_sample_index(o_measurement_result_discard_sample_index),
			.o_measurement_result_discard_color_ir(o_measurement_result_discard_color_ir),
			.o_measurement_result_discard_frame_type(o_measurement_result_discard_frame_type),
			.o_measurement_result_discard_precision(o_measurement_result_discard_precision),
			.o_measurement_result_discard_run_generation(o_measurement_result_discard_run_generation),
			.o_detection_discard_event(o_detection_discard_event),
			.o_detection_discard_reason(o_detection_discard_reason),
			.o_detection_discard_identity_valid(o_detection_discard_identity_valid),
			.o_detection_discard_sample_valid(o_detection_discard_sample_valid),
			.o_detection_discard_frame_id(o_detection_discard_frame_id),
			.o_detection_discard_sample_index(o_detection_discard_sample_index),
			.o_detection_discard_color_ir(o_detection_discard_color_ir),
			.o_detection_discard_frame_type(o_detection_discard_frame_type),
			.o_detection_discard_precision(o_detection_discard_precision),
			.o_detection_discard_config_epoch(o_detection_discard_config_epoch),
			.o_detection_discard_coef_epoch(o_detection_discard_coef_epoch),
			.o_detection_discard_dc_recovery_epoch(o_detection_discard_dc_recovery_epoch),
			.o_detection_discard_amb_code_epoch(o_detection_discard_amb_code_epoch),
			.o_detection_discard_dc_code_epoch(o_detection_discard_dc_code_epoch),
			.o_detection_discard_run_generation(o_detection_discard_run_generation)
		);

	//---------------source时钟发生器---------------//
	initial begin
		i_source_clk = 1'b0;
		forever #5.5 i_source_clk = ~i_source_clk;
	end

	//---------------系统时钟发生器---------------//
	// 真实2MHz语义：500ns整周期
	initial begin
		i_clk = 1'b0;
		forever #250 i_clk = ~i_clk;
	end

	//---------------阶段A：SAR9+C11标称Stage1权重配置构造任务---------------//
	// 权重/offset与Group1~5共用的C11合同标称值逐位一致，代表真实部署系数；
	// optical_mode用单RED（2'b01）而不是双光，避免本组只关心数值链路的场景还要
	// 分别追踪RED/IR两套颜色相关快照
	task task_build_adcn_sar9_nominal_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			i_source_config_snapshot[1023:640] = V5_RESET_PROFILE_REF;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b0; // run_profile=NORMAL_PPG
			i_source_config_snapshot[9] = 1'b0; // input_source=PHOTODIODE
			i_source_config_snapshot[11:10] = 2'b00; // idac_mode=MANUAL
			i_source_config_snapshot[13:12] = 2'b01; // optical_mode=OPTICAL_RED单光，只关心一条颜色的数值链路
			i_source_config_snapshot[14] = 1'b0; // initial_precision=SAR9
			i_source_config_snapshot[15] = 1'b1; // amb_enable
			i_source_config_snapshot[16] = 1'b1; // dcs_enable
			i_source_config_snapshot[17] = 1'b1; // amb_polarity
			i_source_config_snapshot[18] = 1'b0; // dcs_polarity
			i_source_config_snapshot[19] = 1'b1; // stage1_calibration_valid
			i_source_config_snapshot[20] = 1'b1; // stage2_calibration_valid
			i_source_config_snapshot[21] = 1'b1; // dc9_recovery_valid
			i_source_config_snapshot[22] = 1'b1; // dc15_recovery_valid
			i_source_config_snapshot[39:32] = 8'd64; // amb_manual_code
			i_source_config_snapshot[47:40] = 8'd8; // amb_code_min
			i_source_config_snapshot[55:48] = 8'd240; // amb_code_max
			i_source_config_snapshot[63:56] = 8'd80; // dcs_r_manual_code：本组DC恢复模型的dc_code直接读RTL上报的o_result_dc_code_snapshot，这里的具体数值只要求合法
			i_source_config_snapshot[71:64] = 8'd12; // dcs_r_code_min
			i_source_config_snapshot[79:72] = 8'd230; // dcs_r_code_max
			i_source_config_snapshot[87:80] = 8'd96; // dcs_ir_manual_code
			i_source_config_snapshot[95:88] = 8'd16; // dcs_ir_code_min
			i_source_config_snapshot[103:96] = 8'd220; // dcs_ir_code_max
			i_source_config_snapshot[115:104] = -12'sd64; // amb_threshold_low
			i_source_config_snapshot[127:116] = 12'sd72; // amb_threshold_high
			i_source_config_snapshot[139:128] = -12'sd48; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd56; // dcs_threshold_high
			i_source_config_snapshot[159:152] = 8'd8; // amb_confirm_count
			i_source_config_snapshot[167:160] = 8'd9; // dcs_confirm_count
			i_source_config_snapshot[193:168] = 26'sd65536; // stage1_weight_q16_0，C11标称1.0
			i_source_config_snapshot[219:194] = 26'sd131072; // stage1_weight_q16_1，C11标称2.0
			i_source_config_snapshot[245:220] = 26'sd262144; // stage1_weight_q16_2，C11标称4.0
			i_source_config_snapshot[271:246] = 26'sd524288; // stage1_weight_q16_3，C11标称8.0
			i_source_config_snapshot[297:272] = 26'sd524288; // stage1_weight_q16_4，C11标称8.0
			i_source_config_snapshot[323:298] = 26'sd1048576; // stage1_weight_q16_5，C11标称16.0
			i_source_config_snapshot[349:324] = 26'sd2097152; // stage1_weight_q16_6，C11标称32.0
			i_source_config_snapshot[375:350] = 26'sd4194304; // stage1_weight_q16_7，C11标称64.0
			i_source_config_snapshot[401:376] = 26'sd8388608; // stage1_weight_q16_8，C11标称128.0
			i_source_config_snapshot[427:402] = 26'sd16777216; // stage1_weight_q16_9，C11标称256.0
			i_source_config_snapshot[459:428] = -32'sd262144; // stage1_offset_q16，C11标称-4.0
			i_source_config_snapshot[479:460] = 20'sd54143; // stage2_gain_q16，本项目其它场景已在用的代表性取值
			i_source_config_snapshot[511:480] = -32'sd37; // stage2_offset_q16
			i_source_config_snapshot[543:512] = 32'sd65536; // dc9_recovery_gain_q16
			i_source_config_snapshot[575:544] = 32'sd32768; // dc15_recovery_gain_q16
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames，本组不exercising周期复检，取足够大的值避免误触发
		end
	endtask

	//---------------JNT-01~09基线前缀内部要求的标准配置task名---------------//
	// tb_ppg_jnt_baseline_prefix.vh的run_jnt_baseline_01_09内部固定调用这两个
	// 标准task名构造自己的合法NORMAL MANUAL配置，且内部部分子检查（如JNT-03A）
	// 要求真的出现过一笔IR事务——本文件自己的阶段A~D用单RED（OPTICAL_RED）简化
	// 数值链路追踪，但JNT基线自己的52个子检查不能沿用这份单色配置，必须原样
	// 提供Group1~5一直在用的双光MANUAL配置（本组唯一一处非本组自己发明的
	// 字段来源：直接照抄tb_ppg_control_top_baseline_cross.v的task_build_
	// normal_manual_config/_dual_config，逐字段一致，仅供JNT基线内部自用，
	// JNT跑完会做一次干净复位交还，不影响本文件随后自己四个阶段各自的独立COMMIT）
	task task_build_normal_manual_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			i_source_config_snapshot[1023:640] = V5_RESET_PROFILE_REF;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b0; // run_profile=NORMAL_PPG
			i_source_config_snapshot[9] = 1'b0; // input_source=PHOTODIODE
			i_source_config_snapshot[11:10] = 2'b00; // idac_mode=MANUAL
			i_source_config_snapshot[13:12] = 2'b10; // optical_mode=OPTICAL_IR，JNT-03A等子检查需要真实IR事务
			i_source_config_snapshot[14] = 1'b0; // initial_precision=SAR9
			i_source_config_snapshot[15] = 1'b1; // amb_enable
			i_source_config_snapshot[16] = 1'b1; // dcs_enable
			i_source_config_snapshot[17] = 1'b1; // amb_polarity
			i_source_config_snapshot[18] = 1'b0; // dcs_polarity
			i_source_config_snapshot[19] = 1'b1; // stage1_calibration_valid
			i_source_config_snapshot[20] = 1'b1; // stage2_calibration_valid
			i_source_config_snapshot[21] = 1'b1; // dc9_recovery_valid
			i_source_config_snapshot[22] = 1'b1; // dc15_recovery_valid
			i_source_config_snapshot[39:32] = 8'd64; // amb_manual_code
			i_source_config_snapshot[47:40] = 8'd8; // amb_code_min
			i_source_config_snapshot[55:48] = 8'd240; // amb_code_max
			i_source_config_snapshot[63:56] = 8'd80; // dcs_r_manual_code
			i_source_config_snapshot[71:64] = 8'd12; // dcs_r_code_min
			i_source_config_snapshot[79:72] = 8'd230; // dcs_r_code_max
			i_source_config_snapshot[87:80] = 8'd96; // dcs_ir_manual_code
			i_source_config_snapshot[95:88] = 8'd16; // dcs_ir_code_min
			i_source_config_snapshot[103:96] = 8'd220; // dcs_ir_code_max
			i_source_config_snapshot[115:104] = -12'sd64; // amb_threshold_low
			i_source_config_snapshot[127:116] = 12'sd72; // amb_threshold_high
			i_source_config_snapshot[139:128] = -12'sd48; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd56; // dcs_threshold_high
			i_source_config_snapshot[159:152] = 8'd8; // amb_confirm_count
			i_source_config_snapshot[167:160] = 8'd9; // dcs_confirm_count
			i_source_config_snapshot[193:168] = 26'sd65536; // stage1_weight_q16_0
			i_source_config_snapshot[219:194] = 26'sd131072; // stage1_weight_q16_1
			i_source_config_snapshot[245:220] = 26'sd262144; // stage1_weight_q16_2
			i_source_config_snapshot[271:246] = 26'sd524288; // stage1_weight_q16_3
			i_source_config_snapshot[297:272] = 26'sd524288; // stage1_weight_q16_4
			i_source_config_snapshot[323:298] = 26'sd1048576; // stage1_weight_q16_5
			i_source_config_snapshot[349:324] = 26'sd2097152; // stage1_weight_q16_6
			i_source_config_snapshot[375:350] = 26'sd4194304; // stage1_weight_q16_7
			i_source_config_snapshot[401:376] = 26'sd8388608; // stage1_weight_q16_8
			i_source_config_snapshot[427:402] = 26'sd16777216; // stage1_weight_q16_9
			i_source_config_snapshot[459:428] = -32'sd262144; // stage1_offset_q16
			i_source_config_snapshot[479:460] = 20'sd54143; // stage2_gain_q16
			i_source_config_snapshot[511:480] = -32'sd37; // stage2_offset_q16
			i_source_config_snapshot[543:512] = 32'sd65536; // dc9_recovery_gain_q16
			i_source_config_snapshot[575:544] = 32'sd32768; // dc15_recovery_gain_q16
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames
			i_source_config_snapshot[1009] = 1'b1; // peak_valley_config_valid
		end
	endtask

	task task_build_normal_manual_dual_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，真双光
		end
	endtask

	//---------------阶段B：SAR9+舍入临界权重配置构造任务---------------//
	// make_fixed_raw的vdred编码格式固定把物理位3钳位为1（"|10'b0000001000"项），
	// 物理位2/3组合是任何合法[8,503]码值都摆脱不掉的公共项，所以vd2/vd3权重清零、
	// 只在vd4（对应target_code=16会额外置位的物理位）给+0.5、vd5（对应
	// target_code=24会额外置位的物理位）给-0.5，才能干净构造出两个方向各一次
	// 真正落在Q16半LSB边界上的累加值——C11标称权重全部是65536整数倍，永远碰不到
	// 这个边界
	task task_build_adcn_sar9_roundtie_config;
		begin
			task_build_adcn_sar9_nominal_config;
			i_source_config_snapshot[193:168] = 26'sd0; // stage1_weight_q16_0清零
			i_source_config_snapshot[219:194] = 26'sd0; // stage1_weight_q16_1清零
			i_source_config_snapshot[245:220] = 26'sd0; // stage1_weight_q16_2清零，抵消[8,503]任意码值都会置位的公共物理位
			i_source_config_snapshot[271:246] = 26'sd0; // stage1_weight_q16_3清零，抵消make_fixed_raw强制置位的公共物理位
			i_source_config_snapshot[297:272] = 26'sd32768; // stage1_weight_q16_4=+0.5，target_code=16时单独置位产生+32768累加值
			i_source_config_snapshot[323:298] = -26'sd32768; // stage1_weight_q16_5=-0.5，target_code=24时单独置位产生-32768累加值
			i_source_config_snapshot[349:324] = 26'sd0; // stage1_weight_q16_6清零
			i_source_config_snapshot[375:350] = 26'sd0; // stage1_weight_q16_7清零
			i_source_config_snapshot[401:376] = 26'sd0; // stage1_weight_q16_8清零
			i_source_config_snapshot[427:402] = 26'sd0; // stage1_weight_q16_9清零
			i_source_config_snapshot[459:428] = 32'sd0; // stage1_offset_q16清零，纯粹只看两个权重位的贡献
		end
	endtask

	//---------------阶段C：SAR9+饱和offset配置构造任务（正向/负向各一份）---------------//
	// stage1_weight_q16_k字段只有26-bit（真实取值上限约±512.0），单个权重位不足以
	// 单独把累加值推过±2047/±2048饱和门槛；stage1_offset_q16是32-bit字段，取值
	// 空间大得多，全部权重清零、只用offset本身就能确定性触发饱和，且与raw_code
	// 具体是什么完全无关（不需要再逐位挑码值），代码更直接、意图更清楚
	task task_build_adcn_sar9_saturation_high_config;
		begin
			task_build_adcn_sar9_nominal_config;
			i_source_config_snapshot[193:168] = 26'sd0; // stage1_weight_q16_0清零
			i_source_config_snapshot[219:194] = 26'sd0; // stage1_weight_q16_1清零
			i_source_config_snapshot[245:220] = 26'sd0; // stage1_weight_q16_2清零
			i_source_config_snapshot[271:246] = 26'sd0; // stage1_weight_q16_3清零
			i_source_config_snapshot[297:272] = 26'sd0; // stage1_weight_q16_4清零
			i_source_config_snapshot[323:298] = 26'sd0; // stage1_weight_q16_5清零
			i_source_config_snapshot[349:324] = 26'sd0; // stage1_weight_q16_6清零
			i_source_config_snapshot[375:350] = 26'sd0; // stage1_weight_q16_7清零
			i_source_config_snapshot[401:376] = 26'sd0; // stage1_weight_q16_8清零
			i_source_config_snapshot[427:402] = 26'sd0; // stage1_weight_q16_9清零
			i_source_config_snapshot[459:428] = 32'sd196608000; // stage1_offset_q16=+3000.0，全部权重为零时任何raw_code都会正向饱和
		end
	endtask

	task task_build_adcn_sar9_saturation_low_config;
		begin
			task_build_adcn_sar9_nominal_config;
			i_source_config_snapshot[193:168] = 26'sd0; // stage1_weight_q16_0清零
			i_source_config_snapshot[219:194] = 26'sd0; // stage1_weight_q16_1清零
			i_source_config_snapshot[245:220] = 26'sd0; // stage1_weight_q16_2清零
			i_source_config_snapshot[271:246] = 26'sd0; // stage1_weight_q16_3清零
			i_source_config_snapshot[297:272] = 26'sd0; // stage1_weight_q16_4清零
			i_source_config_snapshot[323:298] = 26'sd0; // stage1_weight_q16_5清零
			i_source_config_snapshot[349:324] = 26'sd0; // stage1_weight_q16_6清零
			i_source_config_snapshot[375:350] = 26'sd0; // stage1_weight_q16_7清零
			i_source_config_snapshot[401:376] = 26'sd0; // stage1_weight_q16_8清零
			i_source_config_snapshot[427:402] = 26'sd0; // stage1_weight_q16_9清零
			i_source_config_snapshot[459:428] = -32'sd196608000; // stage1_offset_q16=-3000.0，全部权重为零时任何raw_code都会负向饱和
		end
	endtask

	//---------------阶段D：CHARACTERIZATION固定SAR15+C11标称权重配置构造任务---------------//
	// 按MGR-16/18静态非法组合表（SMOKE-22已confirmed），run_profile=NORMAL_PPG时
	// initial_precision必须是SAR9，NORMAL+SAR15是COMMIT前就会被manager拒绝的
	// 静态非法组合——真实SAR15事务只能通过CHARACTERIZATION固定精度（本任务）或
	// 让动态基线穿越算法自己触发切换（Group2/3的范围）两条路径获得，本组选前者，
	// 与tb_ppg_control_top.v的task_build_char_photodiode_red_sar15_config同源
	task task_build_adcn_sar15_config;
		begin
			task_build_adcn_sar9_nominal_config;
			i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION，唯一允许固定SAR15的run_profile
			i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15，exercising重建+DC恢复精细通路
		end
	endtask

	//---------------source事件任务---------------//
	task task_pulse_source_update;
		begin
			@(negedge i_source_clk);
			i_source_config_update_event = 1'b1;
			@(posedge i_source_clk);
			#1 i_source_config_update_event = 1'b0;
		end
	endtask

	//---------------START事件任务---------------//
	task task_pulse_start;
		begin
			@(negedge i_clk);
			i_start_event = 1'b1;
			@(posedge i_clk);
			#1 i_start_event = 1'b0;
		end
	endtask

	//---------------STOP事件任务---------------//
	task task_pulse_stop;
		begin
			@(negedge i_clk);
			i_stop_event = 1'b1;
			@(posedge i_clk);
			#1 i_stop_event = 1'b0;
		end
	endtask

	//---------------配置结果等待任务---------------//
	task task_wait_config_result;
		integer cnt_wait;
		begin
			cnt_wait = 0;
			while((o_commit_ack_event == 1'b0) && (o_error_event == 1'b0) && (cnt_wait < 64)) begin
				@(posedge i_clk);
				#1;
				cnt_wait = cnt_wait + 1;
			end
			if((o_commit_ack_event == 1'b0) && (o_error_event == 1'b0)) begin
				$display("FAIL ADCN config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------真实ADC完成响应任务---------------//
	task drive_real_adc_done;
		input precision_mode;
		input [9:0] stage1_raw;
		input [9:0] stage2_raw;
		begin
			@(negedge i_clk);
			#2 i_adc_physical_idle = 1'b0;
			#2 i_dout_stage1_low = stage1_raw;
			#1 i_dout_stage2_low = stage2_raw;
			#1 i_clk_stage1_dout_low_async = 1'b1;
			#1 i_clk_stage2_dout_low_async = precision_mode;
			repeat(5) @(negedge i_clk);
			#2 i_clk_stage1_dout_low_async = 1'b0;
			#1 i_clk_stage2_dout_low_async = 1'b0;
			#1 i_adc_physical_idle = 1'b1;
		end
	endtask

	//---------------Q3窗口等待任务---------------//
	task wait_q3_release;
		output o_real_release;
		integer cnt_wd;
		begin
			cnt_wd = 0;
			while((o_clk_q3_low !== 1'b1) && (cnt_wd < 5600)) begin
				@(negedge i_clk);
				cnt_wd = cnt_wd + 1;
			end
			if(o_clk_q3_low !== 1'b1) begin
				o_real_release = 1'b0;
			end else begin
				o_real_release = 1'b1;
				while((o_clk_q3_low === 1'b1) && (cnt_wd < 6600)) begin
					@(negedge i_clk);
					cnt_wd = cnt_wd + 1;
				end
				if(cnt_wd >= 6600) begin
					$display("FAIL ADCN Q3 wait timeout");
					cnt_error = cnt_error + 1;
				end
			end
		end
	endtask

	//---------------vdred编码RAW构造任务---------------//
	// 与tb_ppg_control_top_baseline_cross.v等既有Phase 3文件逐字节一致，[8,503]钳位
	// 范围即本组的可达码值窗口
	task make_fixed_raw;
		input integer target_code;
		output [9:0] raw_code;
		integer bounded_code;
		integer encoded_code;
		begin
			bounded_code = target_code;
			if(bounded_code < 8) bounded_code = 8;
			else if(bounded_code > 503) bounded_code = 503;
			encoded_code = bounded_code - 4;
			raw_code = ((encoded_code >> 3) << 4) | 10'b0000001000 | (encoded_code & 7);
		end
	endtask

	// xvlog要求声明先于使用，本include必须放在DUT例化、全部wire声明和
	// task_build_adcn_sar9_nominal_config等共享task定义之后
	`include "tb_ppg_jnt_baseline_prefix.vh"

	//---------------真实owner身份快照进程（供事务驱动读取实际committed精度）---------------//
	// 2026-09-28工作线D独立复核修复ADCN-07：原来只快照precision/frame_id两个字段，
	// 合同§9.4.6逐字枚举的frame/sample/color/type/AMB-DC code/code epochs共8个
	// 身份字段里有6个从未在owner提交时真实快照过，导致正式结果到达时无法核对
	// "这次报告的身份是不是这笔事务本该有的身份"——只能验证下游数值链路内部自洽，
	// 不是真正的身份绑定验证。ppg_control_top.v已经把这些字段全部转发到内部wire
	// （sched_adc_owner_color_ir_o/frame_type_o/sample_index_o/amb_code_snapshot_o/
	// dc_code_snapshot_o/amb_code_epoch_o/dc_code_epoch_o，与已经在用的
	// sched_adc_owner_precision_mode_o/frame_id_o同一处声明、同一拍有效），补齐
	// 全部快照
	reg reg_owner_snapshot_precision;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_owner_snapshot_frame_id;
	reg reg_owner_snapshot_color_ir;
	reg [1:0] reg_owner_snapshot_frame_type;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_owner_snapshot_sample_index;
	reg [7:0] reg_owner_snapshot_amb_code_snapshot, reg_owner_snapshot_dc_code_snapshot;
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_owner_snapshot_amb_code_epoch, reg_owner_snapshot_dc_code_epoch;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			reg_owner_snapshot_precision <= ppg_control_top_Inst.sched_adc_owner_precision_mode_o;
			reg_owner_snapshot_frame_id <= ppg_control_top_Inst.sched_adc_owner_frame_id_o;
			reg_owner_snapshot_color_ir <= ppg_control_top_Inst.sched_adc_owner_color_ir_o;
			reg_owner_snapshot_frame_type <= ppg_control_top_Inst.sched_adc_owner_frame_type_o;
			reg_owner_snapshot_sample_index <= ppg_control_top_Inst.sched_adc_owner_sample_index_o;
			reg_owner_snapshot_amb_code_snapshot <= ppg_control_top_Inst.sched_adc_owner_amb_code_snapshot_o;
			reg_owner_snapshot_dc_code_snapshot <= ppg_control_top_Inst.sched_adc_owner_dc_code_snapshot_o;
			reg_owner_snapshot_amb_code_epoch <= ppg_control_top_Inst.sched_adc_owner_amb_code_epoch_o;
			reg_owner_snapshot_dc_code_epoch <= ppg_control_top_Inst.sched_adc_owner_dc_code_epoch_o;
		end
	end

	//---------------正式结果边沿捕获进程---------------//
	// 逐笔驱动的顺序场景不需要后台bg_responder，但仍然需要在真实valid&&ready握手
	// 的那一拍原子捕获完整payload，不能等下一拍再读（ready已经恒为1时，consumer
	// 端一拍就会让valid回落）
	integer cnt_result_capture;
	reg signed [23:0] reg_cap_coarse_value;
	reg reg_cap_coarse_valid, reg_cap_coarse_recovery_calibrated, reg_cap_coarse_saturation_low, reg_cap_coarse_saturation_high;
	reg signed [23:0] reg_cap_fine_value;
	reg reg_cap_fine_valid, reg_cap_fine_recovery_calibrated, reg_cap_fine_saturation_low, reg_cap_fine_saturation_high;
	reg signed [11:0] reg_cap_s1_value;
	reg signed [14:0] reg_cap_programmable_15_code;
	reg reg_cap_programmable_15_valid;
	reg [7:0] reg_cap_config_epoch, reg_cap_coef_epoch, reg_cap_stage2_coef_epoch, reg_cap_dc_coef_epoch;
	reg reg_cap_precision_mode;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_cap_frame_id;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_cap_sample_index;
	reg [7:0] reg_cap_amb_code_snapshot, reg_cap_dc_code_snapshot;
	// 2026-09-28工作线D独立复核修复ADCN-07：color_ir/frame_type/两个code epoch
	// 原来只声明了顶层端口，从未被读入任何capture寄存器；ADCN-03：Stage1自己的
	// 饱和诊断标志o_saturation_low/high未在ppg_control_top顶层单独引出，但真实
	// 存在于ppg_adc_s1_programmable_calibrator.v（已带@satisfies: ADCN-03标签），
	// 用层次引用在同一拍捕获，与reg_cap_s1_value同一次握手对齐
	reg reg_cap_color_ir;
	reg [1:0] reg_cap_frame_type;
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_cap_amb_code_epoch, reg_cap_dc_code_epoch;
	reg reg_cap_s1_saturation_low, reg_cap_s1_saturation_high;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			reg_cap_coarse_value <= o_coarse_ppg_value;
			reg_cap_coarse_valid <= o_coarse_valid;
			reg_cap_coarse_recovery_calibrated <= o_coarse_recovery_calibrated;
			reg_cap_coarse_saturation_low <= o_coarse_saturation_low;
			reg_cap_coarse_saturation_high <= o_coarse_saturation_high;
			reg_cap_fine_value <= o_fine_ppg_value;
			reg_cap_fine_valid <= o_fine_valid;
			reg_cap_fine_recovery_calibrated <= o_fine_recovery_calibrated;
			reg_cap_fine_saturation_low <= o_fine_saturation_low;
			reg_cap_fine_saturation_high <= o_fine_saturation_high;
			reg_cap_s1_value <= o_calibrated_s1_value;
			reg_cap_programmable_15_code <= o_programmable_15_code;
			reg_cap_programmable_15_valid <= o_programmable_15_valid;
			reg_cap_config_epoch <= o_result_config_epoch;
			reg_cap_coef_epoch <= o_result_coef_epoch;
			reg_cap_stage2_coef_epoch <= o_result_stage2_coef_epoch;
			reg_cap_dc_coef_epoch <= o_result_dc_coef_epoch;
			reg_cap_precision_mode <= o_result_precision_mode;
			reg_cap_frame_id <= o_result_frame_id;
			reg_cap_sample_index <= o_result_sample_index;
			reg_cap_amb_code_snapshot <= o_result_amb_code_snapshot;
			reg_cap_dc_code_snapshot <= o_result_dc_code_snapshot;
			reg_cap_color_ir <= o_result_color_ir;
			reg_cap_frame_type <= o_result_frame_type;
			reg_cap_amb_code_epoch <= o_result_amb_code_epoch;
			reg_cap_dc_code_epoch <= o_result_dc_code_epoch;
			reg_cap_s1_saturation_low <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_adc_s1_programmable_calibrator_Inst.o_saturation_low;
			reg_cap_s1_saturation_high <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_adc_s1_programmable_calibrator_Inst.o_saturation_high;
			cnt_result_capture <= cnt_result_capture + 1;
		end
	end

	//---------------ADCN-10：IDAC跟踪分支Stage1证据隔离监视进程---------------//
	// 结构性论证（见本文件header）之外的运行时核实。第一版实现曾经对着顶层
	// o_calibrated_s1_value比较，在真实仿真里立刻假性FAIL——排查后发现
	// o_calibrated_s1_value是measurement分支再走完整条DC恢复流水线、且被独立
	// 消费节奏排空之后才更新的保持型结果，和track分支自己的握手时刻完全不对齐
	// （测量分支可能还压着上一笔尚未消费的旧结果，track分支这一拍已经拿到新值），
	// 不是同一时间基准，比出来的"不相等"是TB自己的比较时机错了，不是DUT问题。
	// 改为对着fork内部的兄弟分支输出dec_measurement_s1_value连续比较——两个分支
	// 由同一次fork接纳新事务时一起装载、各自独立持有直到被消费（合同9.5.1第10点
	// 要求的"各分支独立持有资格快照"），装载时刻严格同步，因此在任意时刻都应该
	// 逐位相等，不需要对齐任何一方的消费节奏
	integer cnt_track_branch_fire;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_track_branch_valid_raw &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_track_branch_ready) begin
			cnt_track_branch_fire <= cnt_track_branch_fire + 1;
		end
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_track_s1_value !==
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.dec_measurement_s1_value) begin
			$display("FAIL ADCN10_TRACK_ISOLATION track branch s1 value %0d != fork sibling measurement branch s1 value %0d at t=%0t",
				$signed(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_track_s1_value),
				$signed(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.dec_measurement_s1_value), $time);
			cnt_error = cnt_error + 1;
		end
	end

	//---------------Stage1黄金模型任务---------------//
	// 逐位Q16加权求和+offset，幅值偏置对称舍入，显式饱和到有符号12-bit范围，
	// 与ppg_adc_s1_programmable_calibrator.v的真实RTL结构逐步对应
	reg signed [32:0] model_s1_accumulator;
	reg signed [33:0] model_s1_accumulator_ext;
	reg [33:0] model_s1_magnitude;
	reg [34:0] model_s1_magnitude_biased;
	reg [18:0] model_s1_rounded_magnitude;
	reg signed [19:0] model_s1_rounded_value;
	reg signed [11:0] expected_s1_value;
	reg expected_s1_saturation_low, expected_s1_saturation_high;
	task calculate_stage1_model;
		input [9:0] raw_code;
		input signed [25:0] weight0, weight1, weight2, weight3, weight4;
		input signed [25:0] weight5, weight6, weight7, weight8, weight9;
		input signed [31:0] offset_q16;
		begin
			model_s1_accumulator = {{7{offset_q16[31]}}, offset_q16} +
				(raw_code[0] ? {{7{weight0[25]}}, weight0} : 33'sd0) +
				(raw_code[1] ? {{7{weight1[25]}}, weight1} : 33'sd0) +
				(raw_code[2] ? {{7{weight2[25]}}, weight2} : 33'sd0) +
				(raw_code[3] ? {{7{weight3[25]}}, weight3} : 33'sd0) +
				(raw_code[4] ? {{7{weight4[25]}}, weight4} : 33'sd0) +
				(raw_code[5] ? {{7{weight5[25]}}, weight5} : 33'sd0) +
				(raw_code[6] ? {{7{weight6[25]}}, weight6} : 33'sd0) +
				(raw_code[7] ? {{7{weight7[25]}}, weight7} : 33'sd0) +
				(raw_code[8] ? {{7{weight8[25]}}, weight8} : 33'sd0) +
				(raw_code[9] ? {{7{weight9[25]}}, weight9} : 33'sd0);
			model_s1_accumulator_ext = {model_s1_accumulator[32], model_s1_accumulator};
			model_s1_magnitude = model_s1_accumulator_ext[33] ? ((~model_s1_accumulator_ext) + 34'd1) : model_s1_accumulator_ext;
			model_s1_magnitude_biased = {1'b0, model_s1_magnitude} + 35'd32768;
			model_s1_rounded_magnitude = model_s1_magnitude_biased[34:16];
			model_s1_rounded_value = model_s1_accumulator_ext[33] ?
				-$signed({1'b0, model_s1_rounded_magnitude}) : $signed({1'b0, model_s1_rounded_magnitude});
			expected_s1_saturation_low = (model_s1_rounded_value < -20'sd2048);
			expected_s1_saturation_high = (model_s1_rounded_value > 20'sd2047);
			if(expected_s1_saturation_high) expected_s1_value = 12'sd2047;
			else if(expected_s1_saturation_low) expected_s1_value = -12'sd2048;
			else expected_s1_value = model_s1_rounded_value[11:0];
		end
	endtask

	//---------------DC恢复黄金模型任务---------------//
	// 与tb_ppg_adc_dc_recovery.v的calculate_model逐式一致
	reg signed [63:0] model_dc_code;
	reg signed [63:0] model_coarse_acc, model_fine_acc;
	reg signed [63:0] model_coarse_rounded, model_fine_rounded;
	reg signed [23:0] expected_coarse, expected_fine;
	reg expected_coarse_low, expected_coarse_high, expected_fine_low, expected_fine_high;
	task calculate_dc_recovery_model;
		input precision;
		input signed [11:0] s1_value;
		input signed [14:0] fine_value;
		input [7:0] dc_code;
		input signed [31:0] gain9;
		input signed [31:0] gain15;
		begin
			model_dc_code = {56'd0, dc_code};
			model_coarse_acc = (($signed(s1_value) * 64'sd2) - 64'sd511) *
				64'sd3533837 + model_dc_code * $signed(gain9) * 64'sd2;
			model_fine_acc = $signed(fine_value) * 64'sd131072 +
				model_dc_code * $signed(gain15) * 64'sd2;
			if(model_coarse_acc < 0) model_coarse_rounded = -(((-model_coarse_acc) + 64'sd65536) >>> 17);
			else model_coarse_rounded = (model_coarse_acc + 64'sd65536) >>> 17;
			if(model_fine_acc < 0) model_fine_rounded = -(((-model_fine_acc) + 64'sd65536) >>> 17);
			else model_fine_rounded = (model_fine_acc + 64'sd65536) >>> 17;
			expected_coarse_low = (model_coarse_rounded < -64'sd8388608);
			expected_coarse_high = (model_coarse_rounded > 64'sd8388607);
			expected_fine_low = precision && (model_fine_rounded < -64'sd8388608);
			expected_fine_high = precision && (model_fine_rounded > 64'sd8388607);
			if(expected_coarse_low) expected_coarse = -24'sd8388608;
			else if(expected_coarse_high) expected_coarse = 24'sd8388607;
			else expected_coarse = model_coarse_rounded[23:0];
			if(precision == 1'b0) expected_fine = 24'sd0;
			else if(expected_fine_low) expected_fine = -24'sd8388608;
			else if(expected_fine_high) expected_fine = 24'sd8388607;
			else expected_fine = model_fine_rounded[23:0];
		end
	endtask

	//---------------Stage2重建黄金模型任务---------------//
	// 与tb_ppg_adc_programmable_reconstructor.v的model_result逐式一致
	reg signed [63:0] model_recon_accumulator;
	reg signed [63:0] model_recon_rounded;
	reg signed [14:0] expected_recon_code;
	reg expected_recon_low, expected_recon_high;
	task calculate_reconstruction_model;
		input signed [11:0] model_s1;
		input signed [10:0] model_d2;
		input signed [19:0] model_gain;
		input signed [31:0] model_offset;
		begin
			model_recon_accumulator = ((model_s1 * 64'sd2 - 64'sd511) * 64'sd3533837) +
				((model_d2 * 64'sd2 - 64'sd512) * model_gain) +
				(model_offset * 64'sd2);
			if(model_recon_accumulator < 0) model_recon_rounded = -(((-model_recon_accumulator) + 64'sd65536) >>> 17);
			else model_recon_rounded = (model_recon_accumulator + 64'sd65536) >>> 17;
			if(model_recon_rounded < -64'sd16384) begin
				expected_recon_code = -15'sd16384;
				expected_recon_low = 1'b1;
				expected_recon_high = 1'b0;
			end else if(model_recon_rounded > 64'sd16383) begin
				expected_recon_code = 15'sd16383;
				expected_recon_low = 1'b0;
				expected_recon_high = 1'b1;
			end else begin
				expected_recon_code = model_recon_rounded[14:0];
				expected_recon_low = 1'b0;
				expected_recon_high = 1'b0;
			end
		end
	endtask

	//---------------单笔事务驱动+核对任务---------------//
	// 每笔：等真实Q3释放->驱动选定的target_code->等结果捕获计数增加->独立重算
	// Stage1(+SAR15时重建+DC恢复精细)黄金模型->逐项核对
	task drive_and_check_transaction;
		input integer test_id; // 用于日志标识的ADCN子ID标签（数值，配合字符串在调用点打印）
		input integer target_code; // 本笔选定的解码后RAW码，[8,503]范围内保证不被make_fixed_raw钳位改写
		input signed [25:0] w0, w1, w2, w3, w4, w5, w6, w7, w8, w9;
		input signed [31:0] offset_q16;
		input signed [19:0] stage2_gain;
		input signed [31:0] stage2_offset;
		input signed [31:0] dc9_gain;
		input signed [31:0] dc15_gain;
		reg real_release;
		reg [9:0] raw_code;
		integer cnt_pre_capture;
		integer cnt_wait_result;
		reg fail_this_transaction;
		begin
			fail_this_transaction = 1'b0;
			cnt_pre_capture = cnt_result_capture;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL ADCN-%0d no real Q3 release observed", test_id);
				cnt_error = cnt_error + 1;
				disable drive_and_check_transaction;
			end
			make_fixed_raw(target_code, raw_code);
			drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			cnt_wait_result = 0;
			while((cnt_result_capture == cnt_pre_capture) && (cnt_wait_result < C_RESULT_WAIT_TIMEOUT_CYCLES) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_result = cnt_wait_result + 1;
			end
			if(cnt_result_capture == cnt_pre_capture) begin
				$display("FAIL ADCN-%0d formal result timeout, target_code=%0d", test_id, target_code);
				cnt_error = cnt_error + 1;
				disable drive_and_check_transaction;
			end
			// calibrator实际接收的是make_fixed_raw编码后的物理RAW码（raw_code，经
			// ppg_adc_s1_redundancy_corrector.v原样寄存器转发，未做任何解码变换），
			// 不是target_code本身——target_code只在C11标称权重下才会被重新拼回来，
			// 阶段B/C的自定义权重必须对着真实raw_code算，见本task调用点的说明
			calculate_stage1_model(raw_code, w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, offset_q16);
			if(reg_cap_s1_value !== expected_s1_value) begin
				$display("FAIL ADCN-%0d Stage1 mismatch target_code=%0d expected=%0d actual=%0d",
					test_id, target_code, expected_s1_value, reg_cap_s1_value);
				cnt_error = cnt_error + 1;
				fail_this_transaction = 1'b1;
			end
			// ADCN-03："matching exclusive saturation diagnostic"半句：2026-09-28工作线D
			// 独立复核发现此前只核对了expected_s1_value数值本身是否命中钳位边界，从未
			// 独立核对诊断标志本身——反查ppg_adc_s1_programmable_calibrator.v确认
			// o_saturation_low/high是该模块真实存在的输出端口（已带@satisfies: ADCN-03），
			// 只是未连到ppg_control_top顶层PORT列表，改用层次引用直接读取修复，不再
			// 依赖DC恢复coarse通路的间接代理
			if(reg_cap_s1_saturation_low !== expected_s1_saturation_low) begin
				$display("FAIL ADCN-%0d Stage1 saturation-low diagnostic mismatch target_code=%0d expected=%b actual=%b",
					test_id, target_code, expected_s1_saturation_low, reg_cap_s1_saturation_low);
				cnt_error = cnt_error + 1;
				fail_this_transaction = 1'b1;
			end
			if(reg_cap_s1_saturation_high !== expected_s1_saturation_high) begin
				$display("FAIL ADCN-%0d Stage1 saturation-high diagnostic mismatch target_code=%0d expected=%b actual=%b",
					test_id, target_code, expected_s1_saturation_high, reg_cap_s1_saturation_high);
				cnt_error = cnt_error + 1;
				fail_this_transaction = 1'b1;
			end
			if(reg_cap_s1_saturation_low && reg_cap_s1_saturation_high) begin
				$display("FAIL ADCN-%0d Stage1 saturation-low and saturation-high both asserted simultaneously (not exclusive) target_code=%0d",
					test_id, target_code);
				cnt_error = cnt_error + 1;
				fail_this_transaction = 1'b1;
			end
			calculate_dc_recovery_model(reg_cap_precision_mode, expected_s1_value,
				reg_cap_precision_mode ? expected_recon_code : 15'sd0,
				reg_cap_dc_code_snapshot, dc9_gain, dc15_gain);
			if(reg_cap_precision_mode) begin
				calculate_reconstruction_model(expected_s1_value, target_code[10:0], stage2_gain, stage2_offset);
				calculate_dc_recovery_model(1'b1, expected_s1_value, expected_recon_code, reg_cap_dc_code_snapshot, dc9_gain, dc15_gain);
				if(reg_cap_programmable_15_code !== expected_recon_code) begin
					$display("FAIL ADCN-%0d reconstruction mismatch target_code=%0d expected=%0d actual=%0d",
						test_id, target_code, expected_recon_code, reg_cap_programmable_15_code);
					cnt_error = cnt_error + 1;
					fail_this_transaction = 1'b1;
				end
				if(reg_cap_fine_value !== expected_fine) begin
					$display("FAIL ADCN-%0d DC-recovery fine mismatch target_code=%0d expected=%0d actual=%0d",
						test_id, target_code, expected_fine, reg_cap_fine_value);
					cnt_error = cnt_error + 1;
					fail_this_transaction = 1'b1;
				end
				if(reg_cap_fine_valid !== 1'b1) begin
					$display("FAIL ADCN-%0d SAR15 fine_valid not asserted target_code=%0d", test_id, target_code);
					cnt_error = cnt_error + 1;
					fail_this_transaction = 1'b1;
				end
			end else begin
				calculate_dc_recovery_model(1'b0, expected_s1_value, 15'sd0, reg_cap_dc_code_snapshot, dc9_gain, dc15_gain);
				if(reg_cap_fine_valid !== 1'b0) begin
					$display("FAIL ADCN-%0d SAR9 fine_valid unexpectedly asserted target_code=%0d", test_id, target_code);
					cnt_error = cnt_error + 1;
					fail_this_transaction = 1'b1;
				end
			end
			if(reg_cap_coarse_value !== expected_coarse) begin
				$display("FAIL ADCN-%0d DC-recovery coarse mismatch target_code=%0d expected=%0d actual=%0d",
					test_id, target_code, expected_coarse, reg_cap_coarse_value);
				cnt_error = cnt_error + 1;
				fail_this_transaction = 1'b1;
			end
			if(reg_cap_coarse_valid !== 1'b1) begin
				$display("FAIL ADCN-%0d coarse_valid not asserted target_code=%0d", test_id, target_code);
				cnt_error = cnt_error + 1;
				fail_this_transaction = 1'b1;
			end
			// ADCN-07：结果绑定的身份/epoch字段必须都是当前提交事务的真实值，不是残留。
			// stage2_coef_epoch只在precision=SAR15、Stage2真正参与运算时才有意义
			// 绑定——SAR9事务的o_result_stage2_coef_epoch按设计不追踪这个字段（首次
			// 真实跑通时发现SAR9下这里恒为0，不随每次COMMIT自增，而o_stage2_coef_epoch
			// 是不区分precision的顶层配置版本计数器，两者只在SAR15分支下才需要对齐）
			if((reg_cap_precision_mode !== reg_owner_snapshot_precision) ||
				(reg_cap_config_epoch !== o_config_epoch) || (reg_cap_coef_epoch !== o_coef_epoch) ||
				(reg_cap_precision_mode && (reg_cap_stage2_coef_epoch !== o_stage2_coef_epoch)) ||
				(reg_cap_dc_coef_epoch !== o_dc_recovery_coef_epoch)) begin
				$display("FAIL ADCN-%0d identity/epoch binding mismatch target_code=%0d precision=%b/%b config_epoch=%0d/%0d coef_epoch=%0d/%0d stage2_epoch=%0d/%0d dc_epoch=%0d/%0d",
					test_id, target_code, reg_cap_precision_mode, reg_owner_snapshot_precision,
					reg_cap_config_epoch, o_config_epoch, reg_cap_coef_epoch, o_coef_epoch,
					reg_cap_stage2_coef_epoch, o_stage2_coef_epoch, reg_cap_dc_coef_epoch, o_dc_recovery_coef_epoch);
				cnt_error = cnt_error + 1;
				fail_this_transaction = 1'b1;
			end
			// 2026-09-28工作线D独立复核修复：合同§9.4.6逐字枚举的frame/sample/color/type/
			// AMB-DC code/code epochs此前完全没有对着owner真实提交时的身份做绑定核对——
			// frame_id/sample_index/amb_dc_code_snapshot此前只被读进capture寄存器当成
			// 黄金模型的输入（自洽性检查，不是身份验证）；color_ir/frame_type/两个code
			// epoch则连读都没读过。改为对着owner提交那一拍的真实快照（reg_owner_
			// snapshot_*，与既有precision/frame_id快照同一处、同一拍）逐项核对，是否
			// 与正式结果到达时报告的身份完全一致
			if((reg_cap_frame_id !== reg_owner_snapshot_frame_id) ||
				(reg_cap_sample_index !== reg_owner_snapshot_sample_index) ||
				(reg_cap_color_ir !== reg_owner_snapshot_color_ir) ||
				(reg_cap_frame_type !== reg_owner_snapshot_frame_type) ||
				(reg_cap_amb_code_snapshot !== reg_owner_snapshot_amb_code_snapshot) ||
				(reg_cap_dc_code_snapshot !== reg_owner_snapshot_dc_code_snapshot) ||
				(reg_cap_amb_code_epoch !== reg_owner_snapshot_amb_code_epoch) ||
				(reg_cap_dc_code_epoch !== reg_owner_snapshot_dc_code_epoch)) begin
				$display("FAIL ADCN-%0d identity binding mismatch (result vs real owner-commit snapshot) target_code=%0d frame_id=%0d/%0d sample_index=%0d/%0d color_ir=%b/%b frame_type=%0d/%0d amb_code=%0d/%0d dc_code=%0d/%0d amb_epoch=%0d/%0d dc_epoch=%0d/%0d",
					test_id, target_code, reg_cap_frame_id, reg_owner_snapshot_frame_id,
					reg_cap_sample_index, reg_owner_snapshot_sample_index,
					reg_cap_color_ir, reg_owner_snapshot_color_ir,
					reg_cap_frame_type, reg_owner_snapshot_frame_type,
					reg_cap_amb_code_snapshot, reg_owner_snapshot_amb_code_snapshot,
					reg_cap_dc_code_snapshot, reg_owner_snapshot_dc_code_snapshot,
					reg_cap_amb_code_epoch, reg_owner_snapshot_amb_code_epoch,
					reg_cap_dc_code_epoch, reg_owner_snapshot_dc_code_epoch);
				cnt_error = cnt_error + 1;
				fail_this_transaction = 1'b1;
			end
			if(!fail_this_transaction) begin
				$display("PASS ADCN-%0d target_code=%0d s1=%0d coarse=%0d fine=%0d recon=%0d precision=%b config_epoch=%0d coef_epoch=%0d",
					test_id, target_code, expected_s1_value, reg_cap_coarse_value, reg_cap_fine_value, reg_cap_programmable_15_code,
					reg_cap_precision_mode, reg_cap_config_epoch, reg_cap_coef_epoch);
			end
		end
	endtask

	//---------------全局看门狗---------------//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL ADC_NUMERIC_SCOREBOARD global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//
	initial begin : main_sequence
		integer cnt_stop_wait;
		integer cnt_drain_wait;
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		cnt_result_capture = 0;
		cnt_track_branch_fire = 0;
		i_rstn = 1'b0;
		i_source_rstn = 1'b0;
		i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
		i_source_config_update_event = 1'b0;
		i_source_characterization_update_valid = 1'b0;
		i_source_static_characterization_enable = 1'b0;
		i_source_test_mux_ctrl = 5'b00000;
		i_start_event = 1'b0;
		i_stop_event = 1'b0;
		i_diag_clear_event = 1'b0;
		i_control_abort_event = 1'b0;
		i_dout_stage1_low = 10'd0;
		i_clk_stage1_dout_low_async = 1'b0;
		i_dout_stage2_low = 10'd0;
		i_clk_stage2_dout_low_async = 1'b0;
		i_adc_physical_idle = 1'b1;
		i_analog_ready = 1'b1;
		i_measurement_result_ready = 1'b1;
		i_test_inject_enable = 1'b0;
		i_test_identity_inject_valid = 1'b0;
		i_test_identity_inject_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}};
		i_test_invalid_sample_valid = 1'b0;

		// 复位释放
		repeat(3) @(posedge i_clk);
		#1;
		@(negedge i_source_clk);
		i_source_rstn = 1'b1;
		@(negedge i_clk);
		i_rstn = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;

		// C25合同9.1节：独立复位后必须先完整跑通JNT-01~09才能启动本组场景
		run_jnt_baseline_01_09;

		//=========== 阶段A：SAR9标称权重，ADCN-01/04/07/09 ===========//
		task_build_adcn_sar9_nominal_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ADCN phase A commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		drive_and_check_transaction(1, 8,
			26'sd65536, 26'sd131072, 26'sd262144, 26'sd524288, 26'sd524288,
			26'sd1048576, 26'sd2097152, 26'sd4194304, 26'sd8388608, 26'sd16777216,
			-32'sd262144, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);
		drive_and_check_transaction(1, 128,
			26'sd65536, 26'sd131072, 26'sd262144, 26'sd524288, 26'sd524288,
			26'sd1048576, 26'sd2097152, 26'sd4194304, 26'sd8388608, 26'sd16777216,
			-32'sd262144, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);

		// ADCN-08：正式结果公开背压——压住ready一笔事务，确认ADC owner活动仍照常
		// 完成、被压住的payload在释放前不变，释放后立即被消费
		i_measurement_result_ready = 1'b0;
		begin : adcn08_backpressure
			reg real_release;
			reg [9:0] raw_code;
			integer cnt_pre_owner_commit;
			integer cnt_wait_valid;
			reg signed [11:0] held_s1_value;
			reg signed [23:0] held_coarse_value;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL ADCN-08 no real Q3 release observed under backpressure");
				cnt_error = cnt_error + 1;
			end
			make_fixed_raw(256, raw_code);
			drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			cnt_wait_valid = 0;
			while(!o_measurement_result_valid && (cnt_wait_valid < C_RESULT_WAIT_TIMEOUT_CYCLES) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_valid = cnt_wait_valid + 1;
			end
			if(!o_measurement_result_valid) begin
				$display("FAIL ADCN-08 result never asserted under backpressure");
				cnt_error = cnt_error + 1;
			end else begin
				held_s1_value = o_calibrated_s1_value;
				held_coarse_value = o_coarse_ppg_value;
				repeat(200) begin
					@(posedge i_clk);
					if((o_calibrated_s1_value !== held_s1_value) || (o_coarse_ppg_value !== held_coarse_value)) begin
						$display("FAIL ADCN-08 held payload changed before release s1=%0d/%0d coarse=%0d/%0d",
							o_calibrated_s1_value, held_s1_value, o_coarse_ppg_value, held_coarse_value);
						cnt_error = cnt_error + 1;
					end
					if(!o_measurement_result_valid) begin
						$display("FAIL ADCN-08 held result silently dropped before release");
						cnt_error = cnt_error + 1;
					end
				end
				i_measurement_result_ready = 1'b1;
				@(posedge i_clk);
				#1;
				if(o_measurement_result_valid) begin
					$display("FAIL ADCN-08 held result not consumed promptly after release");
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS ADCN-08 held numeric payload (s1=%0d coarse=%0d) stayed stable under backpressure and consumed promptly on release",
						held_s1_value, held_coarse_value);
				end
			end
		end

		drive_and_check_transaction(1, 256,
			26'sd65536, 26'sd131072, 26'sd262144, 26'sd524288, 26'sd524288,
			26'sd1048576, 26'sd2097152, 26'sd4194304, 26'sd8388608, 26'sd16777216,
			-32'sd262144, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);
		drive_and_check_transaction(1, 384,
			26'sd65536, 26'sd131072, 26'sd262144, 26'sd524288, 26'sd524288,
			26'sd1048576, 26'sd2097152, 26'sd4194304, 26'sd8388608, 26'sd16777216,
			-32'sd262144, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);
		drive_and_check_transaction(1, 503,
			26'sd65536, 26'sd131072, 26'sd262144, 26'sd524288, 26'sd524288,
			26'sd1048576, 26'sd2097152, 26'sd4194304, 26'sd8388608, 26'sd16777216,
			-32'sd262144, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);

		task_pulse_stop;
		cnt_stop_wait = 0;
		while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
			@(posedge i_clk);
			#1;
			cnt_stop_wait = cnt_stop_wait + 1;
		end
		cnt_drain_wait = 0;
		while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
			@(posedge i_clk);
			#1;
			cnt_drain_wait = cnt_drain_wait + 1;
		end
		if(o_lifecycle_state != ST_CONFIG) begin
			$display("FAIL ADCN phase A drain timeout");
			cnt_error = cnt_error + 1;
		end

		//=========== 阶段B：SAR9舍入临界权重，ADCN-02 ===========//
		task_build_adcn_sar9_roundtie_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ADCN phase B commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		drive_and_check_transaction(2, 8,
			26'sd0, 26'sd0, 26'sd0, 26'sd0, 26'sd32768,
			-26'sd32768, 26'sd0, 26'sd0, 26'sd0, 26'sd0,
			32'sd0, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);
		drive_and_check_transaction(2, 16,
			26'sd0, 26'sd0, 26'sd0, 26'sd0, 26'sd32768,
			-26'sd32768, 26'sd0, 26'sd0, 26'sd0, 26'sd0,
			32'sd0, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);
		drive_and_check_transaction(2, 24,
			26'sd0, 26'sd0, 26'sd0, 26'sd0, 26'sd32768,
			-26'sd32768, 26'sd0, 26'sd0, 26'sd0, 26'sd0,
			32'sd0, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);

		task_pulse_stop;
		cnt_stop_wait = 0;
		while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
			@(posedge i_clk);
			#1;
			cnt_stop_wait = cnt_stop_wait + 1;
		end
		cnt_drain_wait = 0;
		while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
			@(posedge i_clk);
			#1;
			cnt_drain_wait = cnt_drain_wait + 1;
		end
		if(o_lifecycle_state != ST_CONFIG) begin
			$display("FAIL ADCN phase B drain timeout");
			cnt_error = cnt_error + 1;
		end

		//=========== 阶段C1：SAR9正向饱和offset，ADCN-03（正向）===========//
		task_build_adcn_sar9_saturation_high_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ADCN phase C1 commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		drive_and_check_transaction(3, 256,
			26'sd0, 26'sd0, 26'sd0, 26'sd0, 26'sd0,
			26'sd0, 26'sd0, 26'sd0, 26'sd0, 26'sd0,
			32'sd196608000, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);

		task_pulse_stop;
		cnt_stop_wait = 0;
		while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
			@(posedge i_clk);
			#1;
			cnt_stop_wait = cnt_stop_wait + 1;
		end
		cnt_drain_wait = 0;
		while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
			@(posedge i_clk);
			#1;
			cnt_drain_wait = cnt_drain_wait + 1;
		end
		if(o_lifecycle_state != ST_CONFIG) begin
			$display("FAIL ADCN phase C1 drain timeout");
			cnt_error = cnt_error + 1;
		end

		//=========== 阶段C2：SAR9负向饱和offset，ADCN-03（负向）===========//
		task_build_adcn_sar9_saturation_low_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ADCN phase C2 commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		drive_and_check_transaction(3, 256,
			26'sd0, 26'sd0, 26'sd0, 26'sd0, 26'sd0,
			26'sd0, 26'sd0, 26'sd0, 26'sd0, 26'sd0,
			-32'sd196608000, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);

		task_pulse_stop;
		cnt_stop_wait = 0;
		while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
			@(posedge i_clk);
			#1;
			cnt_stop_wait = cnt_stop_wait + 1;
		end
		cnt_drain_wait = 0;
		while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
			@(posedge i_clk);
			#1;
			cnt_drain_wait = cnt_drain_wait + 1;
		end
		if(o_lifecycle_state != ST_CONFIG) begin
			$display("FAIL ADCN phase C2 drain timeout");
			cnt_error = cnt_error + 1;
		end

		//=========== 阶段D：SAR15标称权重，ADCN-05/06 ===========//
		task_build_adcn_sar15_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ADCN phase D commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		drive_and_check_transaction(5, 8,
			26'sd65536, 26'sd131072, 26'sd262144, 26'sd524288, 26'sd524288,
			26'sd1048576, 26'sd2097152, 26'sd4194304, 26'sd8388608, 26'sd16777216,
			-32'sd262144, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);
		drive_and_check_transaction(5, 256,
			26'sd65536, 26'sd131072, 26'sd262144, 26'sd524288, 26'sd524288,
			26'sd1048576, 26'sd2097152, 26'sd4194304, 26'sd8388608, 26'sd16777216,
			-32'sd262144, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);
		drive_and_check_transaction(6, 503,
			26'sd65536, 26'sd131072, 26'sd262144, 26'sd524288, 26'sd524288,
			26'sd1048576, 26'sd2097152, 26'sd4194304, 26'sd8388608, 26'sd16777216,
			-32'sd262144, 20'sd54143, -32'sd37, 32'sd65536, 32'sd32768);

		task_pulse_stop;
		cnt_stop_wait = 0;
		while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
			@(posedge i_clk);
			#1;
			cnt_stop_wait = cnt_stop_wait + 1;
		end
		cnt_drain_wait = 0;
		while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
			@(posedge i_clk);
			#1;
			cnt_drain_wait = cnt_drain_wait + 1;
		end
		if(o_lifecycle_state != ST_CONFIG) begin
			$display("FAIL ADCN phase D drain timeout");
			cnt_error = cnt_error + 1;
		end
		if(o_system_fault_blocking) begin
			$display("FAIL ADC_NUMERIC_SCOREBOARD unexpected system fault blocking after all phases");
			cnt_error = cnt_error + 1;
		end

		// ADCN-10汇总：至少观察到若干次真实跟踪分支握手，且监视进程全程没有报FAIL
		if(cnt_track_branch_fire < 1) begin
			$display("FAIL ADCN-10 no real track-branch fire observed to prove Stage1-only isolation");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ADCN-10 track branch fired %0d times, s1 value matched top-level calibrated value every time (structural fork isolation independently confirmed at runtime)",
				cnt_track_branch_fire);
		end

		if(cnt_error == 0) begin
			$display("ADC_NUMERIC_SCOREBOARD_TB_PASS result_captures=%0d track_branch_fires=%0d", cnt_result_capture, cnt_track_branch_fire);
		end else begin
			$display("ADC_NUMERIC_SCOREBOARD_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
