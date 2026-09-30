////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/24
// Design Name:        Deterministic Physiological PPG RAW Generator Model
// Module Name:        tb_ppg_real_raw_generator (Verilog include fragment)
// Description:        Phase 3 Stage 1 -- simulation-only deterministic RAW
//                      source model. Not synthesizable, not a chip RTL block.
//                      Included into a testbench module to provide
//                      task_generate_raw_target_code, which returns one
//                      physiological target_code per (color, physical-frame)
//                      combining fast systolic rise, slow diastolic decay,
//                      a dicrotic notch/rebound, low-rate baseline drift and
//                      bounded deterministic noise, explicitly clamped to the
//                      same [8,503] physical target_code window already used
//                      by tb_ppg_control_top.v's make_fixed_raw.
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      section 3 (Required RAW Waveform Content) and
//                      section 4 (Parameterization and Reproducibility).
//
// Dependencies:       None (pure task/parameter fragment; caller module must
//                      `include this file and declare no conflicting names).
//
// Version:            V1.2
// Revision Date:      2026/08/24
// History:
//    Time               Version       Revised by            Contents
// 2026/08/24            V1.0          Erie                  Create file. Phase 3 Stage 1: deterministic RAW generator model only (contract section 3/4), not yet wired into tb_ppg_control_top.v's bg_responder (that is Stage 2). Produces one coarse/Stage1 physiological target_code per (color, frame); SAR15 fine/Stage2 code derivation is intentionally deferred to Stage 2, where it must be reconciled against the real AMI coarse/fine reconstruction chain (C14) instead of being guessed here. Piecewise-linear pulse shape chosen over a smoother spline so every segment boundary is independently reviewable and debuggable from its frozen frame offsets. Noise is a pure function of (color, frame) -- not a stateful advancing generator -- specifically so a skipped or retried frame under backpressure can never desynchronize the sequence from what a later rerun would produce for that same frame.
// 2026/08/24            V1.1          Erie                  User review of V1.0's default parameters requested two changes, both addressed here without altering any task/algorithm structure. (1) Heart rate: C_RAW_PULSE_PERIOD_FRAMES changed from 200 frames (0.5 s/beat, 120 bpm) to 400 frames (1.0 s/beat, 60 bpm, the textbook resting rate) per explicit user direction. This makes the mandatory 10-second/4000-frame long-run window contain exactly floor(4000/400)=10 complete pulse periods -- the contract's "at least ten complete configured pulse periods" is satisfied exactly, not violated, but Stage 4 (PPG-LONG-10-CYCLES, not yet built) must log this as an exact-boundary case rather than assuming extra margin. (2) DC offset and pulse amplitude: user judged V1.0's values (RED 200/140, IR 260/170; amplitude ~65-70% of DC offset) neither centered in the [8,503] legal window nor "reasonable". Re-derived with two constraints in tension: real optical PPG's AC/IR-DC ratio (~1-2%) is far too small to survive quantization/noise in this ~500-code test domain and would make Stage 4/5's baseline-crossing and peak/valley algorithms untestable, while V1.0's ~70% ratio was arbitrarily large with no physiological grounding. Settled on amplitude ~= 33-37% of DC offset (RED 240/80, IR 270/100) as the balance point: visually and proportionally still reads as a PPG pulse riding on a much larger DC baseline (unlike real optics, but this is a digital algorithm-verification domain, not an optical replica), while remaining several times larger than the noise floor so downstream detectors have real signal to lock onto. Both DC offsets now sit closer to the [8,503] window's midpoint (255) with comfortable dual-sided headroom (worst case RED/IR sum of DC+amplitude+drift+noise stays under 390, clamp never triggers in normal operation, consistent with V1.0's original intent that clamp is exercised only by Stage 4/5's deliberate corner-case parameters, not by the default profile). Drift and noise amplitudes rescaled proportionally to preserve the same relative signal/drift/noise structure as V1.0 (drift ~12-13% of amplitude, noise ~3.5-4% of amplitude). Notch position/depth/rebound percentages (already aligned with commonly cited PPG morphology: systolic rise ~15% of cycle, dicrotic notch in the cycle's mid-40s-to-mid-50s percent range) are unchanged. RGC-01~08 self-check rerun and still all pass -- the shape relationships that matter (rise-then-decay ordering, notch as a bounded-rebound local minimum, return near trough, drift trend, noise bound/determinism, clamp behavior, full-pipeline in-window reproducibility) are magnitude-independent by construction.
// 2026/08/24            V1.2          Erie                  User asked, before Stage 2 wiring, whether the single V1.1 default waveform actually covers the full contract section 9 functional matrix (baseline crossing, no-cross, peak/valley detection, peak/valley anomalies, AMB/DC startup calibration, periodic AMB recheck, threshold-driven slow DC tracking, plus whatever else was missed). Answer: no, not by itself, and this revision is the architectural fix, not just new default numbers. Refactored task_generate_pulse_shape and task_generate_baseline_drift to take their governing quantities (amplitude, notch percentages, period, drift amplitude) as explicit inputs instead of resolving them internally from color_ir; added task_select_raw_profile_params(profile_id, color_ir) as the single place that maps a named profile plus color to a concrete parameter set, defaulting every dimension to the V1.1 NORMAL values and overriding only the one dimension each profile exists to isolate. Added seven corner profiles required by contract section 9.4.10's PPG-ROBUSTNESS-CORNER-WAVEFORMS group (PRC-01/02/03/04/06/07): C_RAW_PROFILE_FLAT (amplitude=0, tests no false cross from drift/noise alone), C_RAW_PROFILE_LOW_AMPLITUDE (amplitude far below NORMAL, PRC-02's "stays in SAR9" case), C_RAW_PROFILE_HIGH_AMPLITUDE_SATURATED (amplitude large enough that DC+amplitude alone exceeds 503 during ordinary cyclic operation, not just a synthetic extreme call, PRC-03), C_RAW_PROFILE_STRONG_DRIFT (drift amplitude several times NORMAL while staying within the legal window, PRC-04), C_RAW_PROFILE_FAST_PERIOD and C_RAW_PROFILE_SLOW_PERIOD (150 and 700 frames against NORMAL's 400, PRC-06's fast/slow legal-edge cases), C_RAW_PROFILE_WEAK_NOTCH (notch depth reduced to near zero, PRC-07). Each profile changes exactly one governing quantity relative to NORMAL so a PRC scenario can isolate one independent variable at a time. task_generate_raw_target_code now takes profile_id as its first input; existing callers must pass C_RAW_PROFILE_NORMAL to reproduce V1.1 behavior exactly (verified bit-identical by RGC-08). Explicitly out of this generator's scope, confirmed by rereading contract section 1 and the section 9.3 group definitions rather than assumed: AMB_CAL/DCS_CAL startup search and periodic-recheck conversions (groups 6 STARTUP-IDAC-CALIBRATION and 8 PERIODIC-RECHECK-RECOVERY) stay on "the existing calibration testbench model" per section 1, not this physiological generator; EXTERNAL_TEST_CURRENT characterization stays on its own independently configured fixed-current stimulus per section 1 and must not be silently replaced by this model; ADC-NUMERIC-CODE-SCOREBOARD (group 11) needs direct representative/endpoint/saturation/rounding code injection at exact values, which is structurally different from a physiological shape and stays out of this file; PRC-08's invalid-sample and PRC-09's calibration-qualification-loss cases are injected through the protected verification boundary or existing calibration-valid controls per section 9.5.1, not through a RAW-value profile. Grounded the NORMAL profile's ability to actually produce a real qualified upward crossing by reading the dynamic-baseline contract's frozen formula B=P+DELTA+S*frame_delta (S<0, declining post-peak threshold) plus the V5_RESET_PROFILE_REF constant already present in tb_ppg_control_top.v (min_peak_valley_amplitude=20, cross_hysteresis_q16=2.0, min_peak_to_peak_frames=100, min_peak_to_valley_frames=20, cross_confirm_count=3): NORMAL's amplitude (80/100) and fast-rise slope comfortably clear both the hysteresis and the declining-baseline dynamics, giving confidence the default profile produces real, not incidental, crossings -- but the exact numeric margins for LOW_AMPLITUDE/FAST_PERIOD/SLOW_PERIOD/WEAK_NOTCH are first-pass placeholders, not yet confirmed against C20/C22's complete qualification math, and must be revisited when Stage 5 implements the PRC group itself with real downstream algorithm evidence. RGC-01~08 rerun with explicit C_RAW_PROFILE_NORMAL and still all pass; added RGC-09~15 covering each new profile's isolated variable (flat has zero pulse contribution, low/high amplitude bracket NORMAL on the correct side, saturated profile actually reaches the clamp boundary during a normal frame sweep rather than only via the synthetic extreme call, strong drift stays bounded and still trends, fast/slow periods produce the expected cycle count over a fixed frame span, weak notch's dip is small relative to NORMAL's).
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月24日
// 设计名称:           确定性生理PPG RAW波形生成器模型
// 模块名称:           tb_ppg_real_raw_generator（Verilog include片段）
// 模块说明:           Phase 3 Stage 1——仅供仿真使用的确定性RAW源模型，不可综合，
//                      不是芯片RTL模块。被某个testbench模块`include后提供
//                      task_generate_raw_target_code任务，为每个(颜色,物理帧)
//                      组合产出一个融合了收缩快升、舒张慢降、重搏切迹+回弹、
//                      低频基线漂移、有界确定性噪声的生理target_code，显式clamp
//                      到tb_ppg_control_top.v的make_fixed_raw已经在用的同一个
//                      [8,503]物理target_code合法窗口。
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      第3节（Required RAW Waveform Content）与
//                      第4节（Parameterization and Reproducibility）。
//
// 依赖文件:           无（纯task/parameter片段；调用方模块需自行`include本文件，
//                      且不得声明冲突的同名标识符）。
//
// 当前版本:           V1.2
// 修订日期:           2026年08月24日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月24日        V1.0          Erie                  创建文件。Phase 3 Stage 1：只做合同第3/4节定义的确定性RAW生成器模型本体，尚未接入tb_ppg_control_top.v的bg_responder（那是Stage 2）。当前只产出每个(颜色,帧)组合的一个粗量化/Stage1生理target_code；SAR15细量化/Stage2码的推导本轮故意延后到Stage 2再做——那时必须对照AMI真实的粗/细重建链路（C14）来确定，而不是在这里凭空猜一个映射公式。脉搏形状选用分段线性而不是更平滑的样条，是为了让每一段边界都能独立对照其冻结的帧偏移量复核和调试。噪声是(颜色,帧)的纯函数，不是一个持续推进状态的生成器——这样即使某一帧在背压下被跳过或重试，也不会让噪声序列和之后重跑同一帧时算出来的值出现不一致（去同步）。
// 2026年08月24日        V1.1          Erie                  用户复核V1.0默认参数后提出两点意见，本次全部只改参数数值，不改任何task/算法结构。（1）心率：C_RAW_PULSE_PERIOD_FRAMES从200帧（0.5秒/拍，120bpm）按用户明确要求改为400帧（1.0秒/拍，60bpm，教科书式静息心率）。这会让强制10秒/4000帧长跑窗口内恰好含floor(4000/400)=10个完整脉搏周期——合同"at least ten complete configured pulse periods"用的是"at least"，10是精确满足、不是违反，但Stage 4（PPG-LONG-10-CYCLES，尚未开工）落地时必须把这记成一个刚好卡线的边界情形，不能想当然认为还有富余。（2）直流基线偏置与脉搏幅度：用户认为V1.0的数值（RED 200/140、IR 260/170，幅度占DC偏置约65~70%）既没有居中在[8,503]合法窗口，也不"合理"。重新推导时要在两个互相牵制的约束间取平衡：真实光学PPG的AC/DC比例（约1~2%）在这个约500码的数字测试域里会被量化和噪声完全淹没，让Stage 4/5的基线穿越、峰谷检测算法根本无法可靠触发，而V1.0约70%的比例又完全没有生理依据、纯属拍脑袋。最终定在幅度≈DC偏置的33~37%（RED 240/80、IR 270/100）作为平衡点：视觉和比例上依然读得出"一个骑在更大直流基线上的PPG脉搏"（不是真实光学比例的复刻，因为这是数字算法验证域，不是光学复现），同时幅度依然是噪声本底的数倍，下游检测器有真实信号可锁定。两个通道的DC偏置现在都更靠近[8,503]窗口中点（255）且留有双向裕量（最坏情况RED/IR的DC+幅度+漂移+噪声总和都不到390，正常运行下clamp不会触发，延续V1.0"clamp只应由Stage 4/5刻意构造的极端参数触发，不应由默认档位触发"的原意）。漂移幅度与噪声幅度按新幅度等比例缩放，保持和V1.0相近的信噪比结构（漂移约为幅度的12~13%，噪声约为幅度的3.5~4%）。切迹位置/深度/回弹百分比（已经和文献里常见的PPG形态吻合：收缩快升占周期约15%，重搏切迹落在周期中段45%~55%附近）未改动。RGC-01~08自检重跑后依然全部真实通过——真正要紧的形状关系（快升后紧接慢降、切迹是有界回弹的局部最小值、周期末尾回到谷值附近、漂移有趋势、噪声有界且可复现、clamp行为正确、整条流水线窗口内且可复现）按设计都与具体数值大小无关。
// 2026年08月24日        V1.2          Erie                  用户在Stage 2接线前提出一个关键问题：V1.1那个单一默认波形，能不能覆盖合同第9节完整功能矩阵（基线相交、基线未相交、波峰波谷检测、波峰波谷检测异常、AMB码上电、DC码上电、周期性重检AMB、PPG码值大于/小于阈值进行DC码慢速波动，以及可能遗漏的其他功能）。答案是：不能，仅凭V1.1本身不够，本次是架构层面的修正，不只是换一版默认数值。把task_generate_pulse_shape和task_generate_baseline_drift重构成接收显式输入（幅度、切迹百分比、周期、漂移幅度），不再在内部按color_ir自行决定；新增task_select_raw_profile_params(profile_id, color_ir)作为唯一把"档位名+颜色"映射到具体参数集的地方，默认每个维度都取V1.1的NORMAL数值，每个档位只覆盖它真正要单独验证的那一个维度。按合同第9.4.10节PPG-ROBUSTNESS-CORNER-WAVEFORMS组（PRC-01/02/03/04/06/07）的要求新增七个角落档位：C_RAW_PROFILE_FLAT（幅度=0，验证纯漂移/噪声不会产生假相交）、C_RAW_PROFILE_LOW_AMPLITUDE（幅度远小于NORMAL，对应PRC-02"应停留在SAR9"场景）、C_RAW_PROFILE_HIGH_AMPLITUDE_SATURATED（幅度大到DC+幅度本身在正常周期性运行下就会超出503，不是只在自检里用极端值单独调用clamp，对应PRC-03）、C_RAW_PROFILE_STRONG_DRIFT（漂移幅度是NORMAL的数倍但仍在合法窗口内，对应PRC-04）、C_RAW_PROFILE_FAST_PERIOD与C_RAW_PROFILE_SLOW_PERIOD（150帧和700帧对比NORMAL的400帧，对应PRC-06快/慢合法边界情形）、C_RAW_PROFILE_WEAK_NOTCH（切迹深度降到接近0，对应PRC-07）。每个档位相对NORMAL只改动一个自变量，方便PRC场景做单变量对照。task_generate_raw_target_code现在第一个输入是profile_id；已有调用方必须显式传C_RAW_PROFILE_NORMAL才能复现V1.1的行为——RGC-08已验证这样做逐位相同。同时重新核对合同第1节和第9.3节各组定义，明确写清楚哪些功能不属于本生成器管辖范围（不是想当然假设的）：AMB_CAL/DCS_CAL启动搜索和周期性重检的转换（第6组STARTUP-IDAC-CALIBRATION、第8组PERIODIC-RECHECK-RECOVERY）按合同第1节继续走"既有校准testbench模型"，不归本生理生成器管；EXTERNAL_TEST_CURRENT特征化按合同第1节继续走自己独立配置的固定电流激励，不得被本模型静默替换；ADC-NUMERIC-CODE-SCOREBOARD（第11组）需要直接注入代表性/端点/饱和/舍入的精确码值，这在结构上和生理波形完全不同，不属于本文件范围；PRC-08的invalid-sample和PRC-09的calibration-qualification-loss按合同第9.5.1节走受保护验证边界注入或既有校准valid控制，不是靠RAW波形档位实现。为了确认NORMAL档位真的能产生真实的合格上穿而不是侥幸，去读了动态基线合同冻结的B=P+DELTA+S*frame_delta公式（S<0，峰值后阈值持续下降）以及tb_ppg_control_top.v里已经存在的V5_RESET_PROFILE_REF常量（min_peak_valley_amplitude=20、cross_hysteresis_q16=2.0、min_peak_to_peak_frames=100、min_peak_to_valley_frames=20、cross_confirm_count=3）：NORMAL的幅度（80/100）和快升斜率相对这些阈值和下降基线动态都有充分裕量，有理由相信默认档位产生的是真实穿越而不是巧合——但LOW_AMPLITUDE/FAST_PERIOD/SLOW_PERIOD/WEAK_NOTCH几个新档位的具体数值边界目前是第一版占位，还没有对照C20/C22完整的合格判定数学核实过，Stage 5真正落地PRC组、拿到下游算法真实证据时必须重新核对。RGC-01~08改用显式C_RAW_PROFILE_NORMAL重跑依然全部通过；新增RGC-09~15分别核对每个新档位各自要隔离的那个变量（flat脉搏贡献恒为0、低/高幅度分别落在NORMAL两侧、饱和档位在正常周期扫描里真的触达clamp边界而不只是自检极端值单独调用、强漂移保持有界但仍有趋势、快/慢周期在固定帧跨度内产生符合预期的周期数、弱切迹的下探幅度相对NORMAL明显偏小）。
//
// 确定性生理PPG RAW波形生成器：clamp前算术为
//   raw_unclamped(color,frame) = dc_offset(color) + pulse_shape(color,frame mod period)
//                                + baseline_drift(color,frame) + deterministic_noise(color,frame)
//   raw(color,frame) = clamp(raw_unclamped, C_RAW_TARGET_CODE_MIN, C_RAW_TARGET_CODE_MAX)
// 与C25合同第3节冻结的算术形式逐项对应。

	//---------------RAW目标码合法窗口参数---------------//
	// 复用tb_ppg_control_top.v既有make_fixed_raw任务已经在用的同一个物理target_code
	// 合法窗口，Stage 2接线时可以直接把本文件产出的target_code原样喂给
	// make_fixed_raw做vdred物理位编码，不需要另建一套编码规则
	localparam integer C_RAW_TARGET_CODE_MIN = 8;   // target_code合法窗口下界
	localparam integer C_RAW_TARGET_CODE_MAX = 503; // target_code合法窗口上界

	//---------------颜色身份编码---------------//
	// 与调度器state_current[B_INFLIGHT_COLOR]编码一致：0=RED，1=IR
	localparam C_RAW_COLOR_RED = 1'b0; // RED颜色身份编码
	localparam C_RAW_COLOR_IR  = 1'b1; // IR颜色身份编码

	//---------------波形档位身份编码（V1.2新增）---------------//
	// 每个档位相对NORMAL只覆盖一个自变量，供不同验证组按需选用；task_select_
	// raw_profile_params是唯一把档位+颜色映射成具体参数集的地方
	localparam [2:0] C_RAW_PROFILE_NORMAL                   = 3'd0; // 默认生理波形（Stage 1~4主力档位）
	localparam [2:0] C_RAW_PROFILE_FLAT                     = 3'd1; // 平坦/无脉搏，只剩漂移+噪声，对应PRC-01
	localparam [2:0] C_RAW_PROFILE_LOW_AMPLITUDE             = 3'd2; // 幅度远低于NORMAL，对应PRC-02
	localparam [2:0] C_RAW_PROFILE_HIGH_AMPLITUDE_SATURATED = 3'd3; // 幅度大到正常扫描就会触达clamp，对应PRC-03
	localparam [2:0] C_RAW_PROFILE_STRONG_DRIFT             = 3'd4; // 漂移幅度远大于NORMAL但仍在窗口内，对应PRC-04
	localparam [2:0] C_RAW_PROFILE_FAST_PERIOD              = 3'd5; // 心动周期明显快于NORMAL，对应PRC-06快边界
	localparam [2:0] C_RAW_PROFILE_SLOW_PERIOD              = 3'd6; // 心动周期明显慢于NORMAL，对应PRC-06慢边界
	localparam [2:0] C_RAW_PROFILE_WEAK_NOTCH               = 3'd7; // 重搏切迹深度接近0，对应PRC-07

	//---------------脉搏相位分段百分比（所有档位共用，只随各自的周期缩放）---------------//
	localparam integer C_RAW_RISE_PCT        = 15; // 收缩快升区占周期百分比
	localparam integer C_RAW_NOTCH_START_PCT = 45; // 重搏切迹起点占周期百分比
	localparam integer C_RAW_NOTCH_END_PCT   = 55; // 重搏切迹终点占周期百分比

	//---------------NORMAL档位心动周期（RED/IR共用同一心动周期）---------------//
	// 400Hz物理帧率下，周期400帧=1.0秒/拍，60bpm（标准静息心率，V1.1按用户明确
	// 要求从200帧/120bpm改来）；10秒强制回归窗口内恰好含floor(4000/400)=10个
	// 完整周期——合同"at least ten complete configured pulse periods"精确满足，
	// 不是违反，但这是刚好卡线、没有富余的边界情形，Stage 4（PPG-LONG-10-CYCLES）
	// 落地时必须把这一点如实记录，不能假设还有额外周期余量
	localparam integer C_RAW_PULSE_PERIOD_FRAMES = 400; // NORMAL心动周期长度（物理帧数）

	//---------------基线漂移周期参数（跨物理帧，远慢于单次脉搏，所有档位共用）---------------//
	// 漂移周期取满整个10秒强制回归窗口的物理帧数，保证长跑期间只观察到一个完整
	// 的三角波漂移趋势，而不是叠加出人为的高频抖动；STRONG_DRIFT只改漂移幅度，
	// 不改漂移周期
	localparam integer C_RAW_DRIFT_PERIOD_FRAMES = 4000; // 基线漂移三角波周期（物理帧数）

	//---------------RED通道NORMAL档位参数---------------//
	// V1.1按用户要求重新校准DC偏置与脉搏幅度：真实光学PPG的AC/DC比例（约1~2%）
	// 在这个约500码的数字测试域里会被量化和噪声完全淹没，无法可靠触发Stage 4/5
	// 的基线穿越/峰谷检测算法；幅度取DC偏置的33%（240的80）作为平衡点——比例上
	// 依然读得出"骑在更大直流基线上的脉搏"，同时是噪声本底的数倍，下游检测器有
	// 真实信号可锁定。DC偏置240更靠近[8,503]窗口中点255，双向留有裕量
	localparam integer C_RAW_DC_OFFSET_RED         = 240; // RED直流基线中心（target_code域）
	localparam integer C_RAW_PULSE_AMPLITUDE_RED   = 80;  // RED脉搏峰谷幅度
	localparam integer C_RAW_NOTCH_TOP_PCT_RED     = 40;  // RED切迹起点电平占峰值百分比
	localparam integer C_RAW_NOTCH_DEPTH_PCT_RED   = 25;  // RED切迹下探深度占峰值百分比
	localparam integer C_RAW_NOTCH_REBOUND_PCT_RED = 55;  // RED切迹回弹占下探深度百分比
	localparam integer C_RAW_DRIFT_AMPLITUDE_RED   = 10;  // RED基线漂移三角波幅度（约为幅度13%）
	localparam integer C_RAW_NOISE_AMPLITUDE_RED   = 3;   // RED确定性噪声有界幅度（约为幅度4%）
	localparam integer C_RAW_NOISE_MULT_RED        = 32'd1000003; // RED噪声哈希乘数
	localparam integer C_RAW_NOISE_ADD_RED         = 32'd7919;    // RED噪声哈希加数

	//---------------IR通道NORMAL档位参数---------------//
	// 同RED通道的V1.1校准思路：幅度取DC偏置的约37%（270的100），DC偏置270同样
	// 更靠近[8,503]窗口中点255，与RED独立取值以保留跨颜色的可区分性
	localparam integer C_RAW_DC_OFFSET_IR         = 270; // IR直流基线中心（target_code域）
	localparam integer C_RAW_PULSE_AMPLITUDE_IR   = 100; // IR脉搏峰谷幅度
	localparam integer C_RAW_NOTCH_TOP_PCT_IR     = 40;  // IR切迹起点电平占峰值百分比
	localparam integer C_RAW_NOTCH_DEPTH_PCT_IR   = 22;  // IR切迹下探深度占峰值百分比
	localparam integer C_RAW_NOTCH_REBOUND_PCT_IR = 50;  // IR切迹回弹占下探深度百分比
	localparam integer C_RAW_DRIFT_AMPLITUDE_IR   = 12;  // IR基线漂移三角波幅度（约为幅度12%）
	localparam integer C_RAW_NOISE_AMPLITUDE_IR   = 4;   // IR确定性噪声有界幅度（约为幅度4%）
	localparam integer C_RAW_NOISE_MULT_IR        = 32'd2000003; // IR噪声哈希乘数
	localparam integer C_RAW_NOISE_ADD_IR         = 32'd104729;  // IR噪声哈希加数

	//---------------角落档位覆盖参数（V1.2新增，PRC-01~07）---------------//
	// 每个档位相对NORMAL只覆盖下面列出的这一项，其余维度沿用NORMAL同颜色的值；
	// 具体数值是第一版占位，Stage 5落地PRC组时须对照C20/C22完整合格判定公式复核
	localparam integer C_RAW_PULSE_AMPLITUDE_LOW_AMPLITUDE_RED = 15;  // LOW_AMPLITUDE档位RED幅度（PRC-02）
	localparam integer C_RAW_PULSE_AMPLITUDE_LOW_AMPLITUDE_IR  = 18;  // LOW_AMPLITUDE档位IR幅度（PRC-02）
	localparam integer C_RAW_PULSE_AMPLITUDE_HIGH_SAT_RED       = 300; // HIGH_AMPLITUDE_SATURATED档位RED幅度：240+300=540>503，正常扫描即触达clamp（PRC-03）
	localparam integer C_RAW_PULSE_AMPLITUDE_HIGH_SAT_IR         = 280; // HIGH_AMPLITUDE_SATURATED档位IR幅度：270+280=550>503（PRC-03）
	localparam integer C_RAW_DRIFT_AMPLITUDE_STRONG_RED         = 60;  // STRONG_DRIFT档位RED漂移幅度：仍在窗口内不会常态clamp（PRC-04）
	localparam integer C_RAW_DRIFT_AMPLITUDE_STRONG_IR           = 70;  // STRONG_DRIFT档位IR漂移幅度（PRC-04）
	localparam integer C_RAW_PULSE_PERIOD_FAST_FRAMES = 150; // FAST_PERIOD档位周期：明显快于NORMAL的400帧（PRC-06快边界）
	localparam integer C_RAW_PULSE_PERIOD_SLOW_FRAMES = 700; // SLOW_PERIOD档位周期：明显慢于NORMAL的400帧（PRC-06慢边界）
	localparam integer C_RAW_NOTCH_DEPTH_PCT_WEAK_RED = 3; // WEAK_NOTCH档位RED切迹深度：接近0（PRC-07）
	localparam integer C_RAW_NOTCH_DEPTH_PCT_WEAK_IR  = 3; // WEAK_NOTCH档位IR切迹深度：接近0（PRC-07）

	//---------------target_code窗口clamp任务---------------//
	// 独立拆出clamp原语，供生成任务内部调用，也供自检直接用极端值单独验证
	// clamp机制本身，不依赖溢出/回绕/隐式有符号转换决定最终码值
	task task_clamp_to_target_code_window;
		input integer value_i; // clamp前的候选值，允许超出[MIN,MAX]甚至为负
		output [9:0] clamped_o; // clamp后的target_code，恒落在[C_RAW_TARGET_CODE_MIN,C_RAW_TARGET_CODE_MAX]
		integer bounded_value;
		begin
			bounded_value = value_i;
			if(bounded_value < C_RAW_TARGET_CODE_MIN) bounded_value = C_RAW_TARGET_CODE_MIN;
			else if(bounded_value > C_RAW_TARGET_CODE_MAX) bounded_value = C_RAW_TARGET_CODE_MAX;
			clamped_o = bounded_value[9:0];
		end
	endtask

	//---------------确定性噪声任务---------------//
	// 纯(color,frame)函数，不维护任何跨调用的状态寄存器：同一帧无论被求值多少次、
	// 无论求值顺序如何，结果必须逐位相同，避免背压重试场景下的噪声序列去同步
	task task_generate_deterministic_noise;
		input color_ir; // 0=RED，1=IR
		input [31:0] frame_index; // 物理宏帧序号
		output integer noise_o; // 有界确定性噪声值，范围[-amplitude,+amplitude]
		integer noise_amplitude;
		integer noise_mult;
		integer noise_add;
		reg [31:0] noise_hash;
		begin
			if(color_ir == C_RAW_COLOR_IR) begin
				noise_amplitude = C_RAW_NOISE_AMPLITUDE_IR;
				noise_mult = C_RAW_NOISE_MULT_IR;
				noise_add = C_RAW_NOISE_ADD_IR;
			end else begin
				noise_amplitude = C_RAW_NOISE_AMPLITUDE_RED;
				noise_mult = C_RAW_NOISE_MULT_RED;
				noise_add = C_RAW_NOISE_ADD_RED;
			end
			// 32位无符号乘加故意允许截断回绕——这是哈希函数设计的一部分，不是
			// 意外的隐式转换：结果始终是frame_index的确定性纯函数
			noise_hash = (frame_index * noise_mult) + noise_add;
			noise_o = (noise_hash % ((2 * noise_amplitude) + 1)) - noise_amplitude;
		end
	endtask

	//---------------波形档位参数选择任务（V1.2新增）---------------//
	// 唯一把"档位+颜色"解析成具体参数集的地方：先取该颜色的NORMAL缺省值，
	// 再按profile_id只覆盖该档位真正要隔离验证的那一个维度，其余维度保持和
	// NORMAL完全一致，方便PRC等场景一次只改一个自变量做对照
	task task_select_raw_profile_params;
		input [2:0] profile_id; // C_RAW_PROFILE_*
		input color_ir; // 0=RED，1=IR
		output integer dc_offset_o; // 直流基线中心（target_code域）
		output integer pulse_amplitude_o; // 脉搏峰谷幅度
		output integer notch_top_pct_o; // 切迹起点电平占峰值百分比
		output integer notch_depth_pct_o; // 切迹下探深度占峰值百分比
		output integer notch_rebound_pct_o; // 切迹回弹占下探深度百分比
		output integer drift_amplitude_o; // 基线漂移三角波幅度
		output integer pulse_period_frames_o; // 心动周期长度（物理帧数）
		begin
			if(color_ir == C_RAW_COLOR_IR) begin
				dc_offset_o = C_RAW_DC_OFFSET_IR;
				pulse_amplitude_o = C_RAW_PULSE_AMPLITUDE_IR;
				notch_top_pct_o = C_RAW_NOTCH_TOP_PCT_IR;
				notch_depth_pct_o = C_RAW_NOTCH_DEPTH_PCT_IR;
				notch_rebound_pct_o = C_RAW_NOTCH_REBOUND_PCT_IR;
				drift_amplitude_o = C_RAW_DRIFT_AMPLITUDE_IR;
			end else begin
				dc_offset_o = C_RAW_DC_OFFSET_RED;
				pulse_amplitude_o = C_RAW_PULSE_AMPLITUDE_RED;
				notch_top_pct_o = C_RAW_NOTCH_TOP_PCT_RED;
				notch_depth_pct_o = C_RAW_NOTCH_DEPTH_PCT_RED;
				notch_rebound_pct_o = C_RAW_NOTCH_REBOUND_PCT_RED;
				drift_amplitude_o = C_RAW_DRIFT_AMPLITUDE_RED;
			end
			pulse_period_frames_o = C_RAW_PULSE_PERIOD_FRAMES;
			case(profile_id)
				C_RAW_PROFILE_FLAT: begin
					pulse_amplitude_o = 0; // 纯漂移+噪声，无脉搏贡献
				end
				C_RAW_PROFILE_LOW_AMPLITUDE: begin
					pulse_amplitude_o = (color_ir == C_RAW_COLOR_IR) ? C_RAW_PULSE_AMPLITUDE_LOW_AMPLITUDE_IR : C_RAW_PULSE_AMPLITUDE_LOW_AMPLITUDE_RED;
				end
				C_RAW_PROFILE_HIGH_AMPLITUDE_SATURATED: begin
					pulse_amplitude_o = (color_ir == C_RAW_COLOR_IR) ? C_RAW_PULSE_AMPLITUDE_HIGH_SAT_IR : C_RAW_PULSE_AMPLITUDE_HIGH_SAT_RED;
				end
				C_RAW_PROFILE_STRONG_DRIFT: begin
					drift_amplitude_o = (color_ir == C_RAW_COLOR_IR) ? C_RAW_DRIFT_AMPLITUDE_STRONG_IR : C_RAW_DRIFT_AMPLITUDE_STRONG_RED;
				end
				C_RAW_PROFILE_FAST_PERIOD: begin
					pulse_period_frames_o = C_RAW_PULSE_PERIOD_FAST_FRAMES;
				end
				C_RAW_PROFILE_SLOW_PERIOD: begin
					pulse_period_frames_o = C_RAW_PULSE_PERIOD_SLOW_FRAMES;
				end
				C_RAW_PROFILE_WEAK_NOTCH: begin
					notch_depth_pct_o = (color_ir == C_RAW_COLOR_IR) ? C_RAW_NOTCH_DEPTH_PCT_WEAK_IR : C_RAW_NOTCH_DEPTH_PCT_WEAK_RED;
				end
				default: begin
					// C_RAW_PROFILE_NORMAL：不覆盖任何维度，沿用上面取到的该颜色NORMAL缺省值
				end
			endcase
		end
	endtask

	//---------------基线漂移任务---------------//
	// 跨物理帧的低频三角波，周期远大于单次脉搏周期，代表DC基线的缓慢变化趋势；
	// V1.2起改为接收已解析的漂移幅度，不再自行按颜色查表，纯数学计算与档位/
	// 颜色身份解耦
	task task_generate_baseline_drift;
		input integer drift_amplitude; // 已解析的基线漂移三角波幅度
		input [31:0] frame_index; // 物理宏帧序号
		output integer drift_o; // 基线漂移值，范围[-amplitude,+amplitude]
		integer drift_phase;
		integer drift_half;
		integer drift_distance;
		begin
			drift_phase = frame_index % C_RAW_DRIFT_PERIOD_FRAMES;
			drift_half = C_RAW_DRIFT_PERIOD_FRAMES / 2;
			// 三角波：相位在漂移半周期处取峰值+amplitude，在两端取谷值-amplitude
			if(drift_phase > drift_half) drift_distance = drift_phase - drift_half;
			else drift_distance = drift_half - drift_phase;
			drift_o = drift_amplitude - ((2 * drift_amplitude * drift_distance) / drift_half);
		end
	endtask

	//---------------脉搏形状任务---------------//
	// 分段线性合成收缩快升->舒张早期慢降->重搏切迹下探->切迹回弹->舒张晚期慢降，
	// 五段共同覆盖一个完整心动周期，谷值统一取0，供上层叠加到直流基线上；V1.2起
	// 改为接收已解析的幅度/切迹百分比/周期，段边界帧号按传入周期现算，不再依赖
	// 编译期固定的NORMAL周期边界，FAST_PERIOD/SLOW_PERIOD档位才能正确缩放
	task task_generate_pulse_shape;
		input integer pulse_amplitude; // 已解析的脉搏峰谷幅度
		input integer notch_top_pct; // 已解析的切迹起点电平占峰值百分比
		input integer notch_depth_pct; // 已解析的切迹下探深度占峰值百分比
		input integer notch_rebound_pct; // 已解析的切迹回弹占下探深度百分比
		input integer pulse_period_frames; // 已解析的心动周期长度（物理帧数）
		input [31:0] frame_index; // 物理宏帧序号
		output integer pulse_o; // 相对谷值0的脉搏瞬时贡献量
		integer notch_top_level;
		integer notch_bottom_level;
		integer notch_end_level;
		integer phase_in_period;
		integer rise_end_frame;
		integer notch_start_frame;
		integer notch_end_frame;
		integer notch_mid_frame;
		begin
			rise_end_frame = (pulse_period_frames * C_RAW_RISE_PCT) / 100;
			notch_start_frame = (pulse_period_frames * C_RAW_NOTCH_START_PCT) / 100;
			notch_end_frame = (pulse_period_frames * C_RAW_NOTCH_END_PCT) / 100;
			notch_mid_frame = (notch_start_frame + notch_end_frame) / 2;
			notch_top_level = (pulse_amplitude * notch_top_pct) / 100;
			notch_bottom_level = notch_top_level - ((pulse_amplitude * notch_depth_pct) / 100);
			notch_end_level = notch_bottom_level + (((notch_top_level - notch_bottom_level) * notch_rebound_pct) / 100);
			phase_in_period = frame_index % pulse_period_frames;
			if(phase_in_period < rise_end_frame) begin
				// 收缩快升：谷值0线性上升到主峰pulse_amplitude
				pulse_o = (pulse_amplitude * phase_in_period) / rise_end_frame;
			end else if(phase_in_period < notch_start_frame) begin
				// 舒张早期慢降：主峰线性下降到重搏切迹起点电平
				pulse_o = pulse_amplitude - (((pulse_amplitude - notch_top_level) *
					(phase_in_period - rise_end_frame)) / (notch_start_frame - rise_end_frame));
			end else if(phase_in_period < notch_mid_frame) begin
				// 重搏切迹下探段：切迹起点电平线性下探到切迹谷底
				pulse_o = notch_top_level - (((notch_top_level - notch_bottom_level) *
					(phase_in_period - notch_start_frame)) / (notch_mid_frame - notch_start_frame));
			end else if(phase_in_period < notch_end_frame) begin
				// 重搏切迹回弹段：切迹谷底线性回弹到切迹终点电平（有界回弹，不回到主峰）
				pulse_o = notch_bottom_level + (((notch_end_level - notch_bottom_level) *
					(phase_in_period - notch_mid_frame)) / (notch_end_frame - notch_mid_frame));
			end else begin
				// 舒张晚期慢降：切迹终点电平线性回落到本周期谷值0，衔接下一周期快升起点
				pulse_o = notch_end_level - ((notch_end_level *
					(phase_in_period - notch_end_frame)) / (pulse_period_frames - notch_end_frame));
			end
		end
	endtask

	//---------------RAW目标码顶层生成任务---------------//
	// 合成直流基线+脉搏形状+基线漂移+确定性噪声，显式clamp到合法target_code窗口，
	// 是Stage 2接线时唯一需要调用的入口任务；raw_unclamped_o只用于自检验证clamp
	// 确实在生效，不作为对外接口的一部分。V1.2起第一个输入是profile_id，已有
	// 调用方须显式传C_RAW_PROFILE_NORMAL才能复现V1.1行为
	task task_generate_raw_target_code;
		input [2:0] profile_id; // C_RAW_PROFILE_*
		input color_ir; // 0=RED，1=IR
		input [31:0] frame_index; // 物理宏帧序号（Stage2接线时取自真实owner身份frame_id）
		output [9:0] target_code_o; // clamp后的target_code，可直接喂给make_fixed_raw同款vdred编码
		output integer raw_unclamped_o; // clamp前的原始合成值，供自检核对clamp分支
		integer dc_offset;
		integer pulse_amplitude;
		integer notch_top_pct;
		integer notch_depth_pct;
		integer notch_rebound_pct;
		integer drift_amplitude;
		integer pulse_period_frames;
		integer pulse_value;
		integer drift_value;
		integer noise_value;
		begin
			task_select_raw_profile_params(profile_id, color_ir, dc_offset, pulse_amplitude,
				notch_top_pct, notch_depth_pct, notch_rebound_pct, drift_amplitude, pulse_period_frames);
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct,
				pulse_period_frames, frame_index, pulse_value);
			task_generate_baseline_drift(drift_amplitude, frame_index, drift_value);
			task_generate_deterministic_noise(color_ir, frame_index, noise_value);
			raw_unclamped_o = dc_offset + pulse_value + drift_value + noise_value;
			task_clamp_to_target_code_window(raw_unclamped_o, target_code_o);
		end
	endtask
