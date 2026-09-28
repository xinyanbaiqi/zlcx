# NRE-01~06 + ADCN-01~10 工作线D独立复核（2026-09-28）

> 方法声明：不信任`tb_ppg_control_top_no_recheck_control.v`/`tb_ppg_control_top_adc_
> numeric_scoreboard.v`自己的changelog或`PPG_ALIAS_MAPPING_TABLE.md`既有映射，全部
> 当作"待验证的声称"。复核方法：(1)从`PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`
> §9.4.4/§9.4.6取verbatim英文acceptance requirement原文，(2)完整读真实断言代码块本身
> （不只看`$display`标签和changelog自述），(3)特别核对合同原文里逐项列举的多个子字段
> /子条件（如"binds frame, sample, color, type..."这类枚举式要求）是否每一项都有对应
> 的真实检查，而不是部分覆盖就算数。

延续`HANDOFF_20260917_2.md`交接以来的工作线D方法论，这是继JNT/ILM/SID/TRK/ISE/OIB/
LFA/PRC/RRC九个家族之后，首次覆盖NRE和ADCN——这两个家族此前只有2026-08-30 Stage5的
"iverilog+xsim双工具全量confirmed"记录，从未被工作线D这套断言级独立复核方法论真正
碰过。

## 结论摘要

| 家族 | ID数 | 真实缺口 | CONFIRMED |
| --- | --- | --- | --- |
| NRE | 6 | **0** | 6 |
| ADCN | 10 | **2**（ADCN-03部分/ADCN-07大部分） | 8（含ADCN-03/07的已confirmed部分） |

**本轮RTL零改动，未做任何修复**——按二级委派规则，独立复核（只读审计）阶段不需要
额外授权即可直接做，但发现缺口后"要不要补断言"是需要用户决定的下一步，本报告只
如实报告发现，不擅自动手。

---

## NRE-01~06：6项全部CONFIRMED，无真实缺口

TB文件：`ppg_control_top/tb_ppg_control_top_no_recheck_control.v`（1111行，完整读完）。
合同来源：`PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.4。

单一连续RUN（`amb_recheck_interval_frames=0`+SEARCH_TRACK+双光真实生成器）覆盖全部
六条ID，用连续后台监视进程+sticky捕获，不是事后推断：

| ID | 合同原文核心 | 真实检查机制 | 复核结论 |
| --- | --- | --- | --- |
| NRE-01 | pending/accept/busy/done/failed全程不激活 | 直接监视`ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending/accept/busy/o_sequence_done/o_sequence_failed`五个信号，sticky锁存，全程要求恒0 | CONFIRMED |
| NRE-02 | 无重检驱动的FIR历史清除/检测器清除/输出抑制/校准请求 | 直接在FIR和穿越检测器**自己的输入引脚**监视`i_recheck_accept_event`/`i_recheck_busy`（不是从调度器输出侧间接推断），另监视IDAC控制器的4个重检族状态。**"输出抑制"这一子句独立反查RTL确认**：`ppg_coarse_detection_fir.v:406`的`o_result_ready`公式包含`(i_recheck_busy==1'b0)`这一项，与"FIR历史清除"共用同一个`i_recheck_busy`监视点，两者是同一个信号的两个后果，已经被同一条检查覆盖，不是遗漏 | CONFIRMED（含独立验证过的"输出抑制"子句） |
| NRE-03 | 两色完成正常FIR预热且历史不被中断 | `cnt_red_sample`/`cnt_ir_sample`高水位监视，满窗前任何真实下降立即判违规 | CONFIRMED |
| NRE-04 | 真实穿越进SAR15+合格峰谷序列回落SAR9，中间零重检事件 | `o_fine_window_start_event`+`o_return_9bit_valid`&`i_return_9bit_ready`sticky捕获，vacuous时真实报FAIL（非静默通过） | CONFIRMED |
| NRE-05 | 穿越身份绑定真实FIR/基线证据，不能归因于START/复位/隐藏重检清除 | 穿越形成时刻核对两色FIR历史是否**已经**真实锁满（`flag_nre05_fir_full_before_cross`），证明穿越建立在真实累积历史上；"隐藏重检清除"这个反面可能性已被NRE-01/02同一次RUN证明重检从未激活而结构性排除 | CONFIRMED |
| NRE-06 | 长时间运行保持owner/结果顺序、码epoch、结果连续性，重检计数器/事件全程禁用 | `o_result_frame_id`全程非递减+AMB码/epoch从启动搜索完成后逐字节不变；"owner顺序"未见独立于"结果顺序"的专属检查，但该结论建立在本项目已独立confirmed的"单笔严格在途"架构不变量之上（同一时刻只有一个owner在途，grant顺序与completion顺序机械等价），不是新的推论 | CONFIRMED（"owner顺序"部分依赖已有架构不变量，非独立动态证据，如实记录） |

**结论**：NRE家族是继它自己2026-08-29创建时"第一次真实跑就干净PASS、零bug"的
既有记录之后，第二次（这次是独立复核）得出同样的"零真实缺口"结论——这次复核没有
只是重复相信原有声称，是逐条真实核对断言代码+反查RTL机制后独立得出的一致结果。

---

## ADCN-01~10：2处真实缺口（ADCN-03部分、ADCN-07大部分）

TB文件：`ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v`（1381行，完整
读完）。合同来源：`PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.6。这是
Stage5批次规划里"结构最复杂"的家族之一（`project-ppg-stage2-d2nostatus-batch5-adcn-family-20260913.md`
是指D2_NO_STATUS_FOUND批次，性质不同，本次是工作线D断言级复核，独立结论）。

### 整体架构（真实核实，非转述）

不用生理RAW生成器的连续波形，改为四个独立提交的校准配置（阶段A标称权重、阶段B
舍入临界权重、阶段C1/C2饱和offset、阶段D SAR15标称权重）逐笔驱动精确指定的RAW码，
每笔独立重算Stage1/DC恢复/Stage2重建三段**真正独立**的黄金模型（不是RTL代码的
verbatim复制——比如Stage1黄金模型用显式的"取符号取幅值→加偏置→右移→按位饱和"
计算风格，与真实RTL内部实现路径不同，逐位比对结果而非逐行对照代码，是真正意义
上的独立reimplementation）。

### CONFIRMED的8项

| ID | 合同原文核心 | 真实检查 |
| --- | --- | --- |
| ADCN-01 | Stage1 RAW编码匹配黄金模型+公开12-bit输出 | 独立黄金模型`calculate_stage1_model`逐位比对`reg_cap_s1_value` |
| ADCN-02 | 正/负/半LSB舍入用对称规则，不提前转无符号 | 阶段B专门构造非标称权重（标称权重全是65536整数倍，任何码值都不会产生真实舍入余数，必须用自定义权重才能真正触碰舍入判定），码值8/16/24产生0/+1/-1两个方向各一次真实半LSB临界 |
| ADCN-04 | 合格SAR9事务产生冻结coarse DC恢复值+无合格fine结果 | `expected_coarse`匹配+`reg_cap_fine_valid!==1'b0`（SAR9下要求fine_valid恒为0） |
| ADCN-05 | 合格SAR15事务用绑定的Stage1+Stage2值 | 阶段D独立黄金模型`calculate_reconstruction_model`逐位比对`reg_cap_programmable_15_code` |
| ADCN-06 | SAR15粗/精DC恢复匹配黄金模型 | `calculate_dc_recovery_model`同时算coarse/fine两路，逐位比对 |
| ADCN-08 | 背压期间数值/资格/诊断/身份全部保持直到公开传输 | 压住`i_measurement_result_ready`200拍，逐拍核对`o_calibrated_s1_value`/`o_coarse_ppg_value`不变+`o_measurement_result_valid`不掉线，释放后立即消费 |
| ADCN-09 | 12-bit Stage1值不被截断到9-bit，9-bit角色结果在公开coarse接口核对 | `o_calibrated_s1_value`端口本身声明为`signed[11:0]`（12-bit），黄金模型比对的是完整12-bit值，SAR9下的"9-bit角色"结果专门在`o_coarse_ppg_value`（公开coarse DC恢复接口）核对，符合合同"at the public coarse DC-recovered interface"的措辞 |
| ADCN-10 | Stage2/重建/粗精恢复/正式输出值不能进入IDAC跟踪比较器，只有同笔Stage1证据可以 | 结构性论证（fork在DC恢复/重建之前分叉）+运行时逐拍监视`flag_track_s1_value`对比fork兄弟分支`dec_measurement_s1_value`，`cnt_track_branch_fire`确认非vacuous（真实触发过） |

### 真实缺口1：ADCN-03——"matching exclusive saturation diagnostic"半句未被独立核实

**合同原文**：`Stage1 arithmetic outside the signed 12-bit range saturates to -2048 or
+2047 **with the matching exclusive saturation diagnostic**.`——两个分句：数值本身
正确饱和（已confirmed），且有对应的、互斥的饱和诊断标志一起产生。

**TB现状**：阶段C1/C2构造offset饱和场景，只核对`expected_s1_value`命中`-2048`/
`+2047`钳位边界（`reg_cap_s1_value!==expected_s1_value`），**没有检查诊断标志本身**。
文件自己1122-978行附近有一条真实注释解释原因："Stage1自身的o_saturation_low/high
未在ppg_control_top顶层单独引出"，所以只能用数值本身命中钳位边界作为间接证据，
不重复判定诊断标志。

**独立反查RTL**：`ppg_adc_s1_programmable_calibrator.v`确认`o_saturation_low`
（100行）/`o_saturation_high`（101行）**是该模块真实存在的输出端口**，底层
`flag_saturation_low`/`flag_saturation_high`（232-233行）已经带`@satisfies: ADCN-03`
标签。TB的说法"未在顶层单独引出"只是说没有连到`ppg_control_top`自己的PORT列表，
不代表**层次引用不可达**——这个项目里大量TB（本次NRE/ADCN本身，以及此前PRC-04/
ISE-01等）都是靠`ppg_control_top_Inst.xxx_Inst.yyy_Inst.signal`这种深层次引用直接
读取非顶层端口信号，ADCN-03完全可以用同样手法直接读到这两个诊断位，本次TB没有
尝试。

**结论**：数值本身饱和正确（已confirmed），但"诊断标志同步产生"这个独立命名的
子句目前只是间接推断，不是直接验证。真实、具体、可继续（不是"结构性不可测"）的
缺口。

### 真实缺口2：ADCN-07——10个具名绑定字段里只有5个被真实检查

**合同原文**：`Every numerical comparison binds frame, sample, color, type,
precision, AMB/DC code, code epochs, config epoch, Stage1/Stage2 coefficient
epochs, and DC-recovery epoch.`——逐字枚举了10类身份/版本字段，要求每一次数值比较
都绑定验证。

**逐项核实TB真实实现**（`drive_and_check_transaction`任务1021-1036行的身份/epoch
核对块，是全文件唯一一处identity binding检查）：

| 合同字段 | TB真实状态 |
| --- | --- |
| frame（frame_id） | `reg_cap_frame_id`（752行）**已捕获但全文件从未与任何期望值比较**——纯死读 |
| sample（sample_index） | `reg_cap_sample_index`（753行）**同样已捕获但从未比较**——纯死读 |
| color（color_ir） | **全文件未捕获**：`o_result_color_ir`端口已声明并连线（162/316行），但从未被读取/赋值给任何capture寄存器 |
| type（frame_type） | **全文件未捕获**：`o_result_frame_type`同样已连线但从未被使用 |
| precision | `reg_cap_precision_mode`对比`reg_owner_snapshot_precision`——**真实检查** |
| AMB/DC code | `reg_cap_amb_code_snapshot`/`reg_cap_dc_code_snapshot`已捕获，但只是**原样喂给DC恢复黄金模型当输入**（438行注释明确写"这里的具体数值只要求合法"），不是独立核对"这笔事务报告的码值是不是它本该有的那个码值"——是自洽性检查，不是身份绑定检查 |
| code epochs（amb/dc_code_epoch） | **全文件未捕获**：`o_result_amb_code_epoch`/`o_result_dc_code_epoch`已连线但从未读取 |
| config epoch | `reg_cap_config_epoch`对比`o_config_epoch`——**真实检查** |
| Stage1/Stage2系数epoch | `reg_cap_coef_epoch`对比`o_coef_epoch`（真实检查）；`reg_cap_stage2_coef_epoch`对比`o_stage2_coef_epoch`（仅SAR15下要求，真实检查，且已如实说明SAR9下stage2 epoch不追踪的设计原因） |
| DC-recovery epoch | `reg_cap_dc_coef_epoch`对比`o_dc_recovery_coef_epoch`——**真实检查** |

**结论**：10个具名字段里，**precision/config_epoch/Stage1系数epoch/Stage2系数epoch
（仅SAR15）/DC恢复epoch共5个是真实、独立验证的；frame_id和sample_index被捕获但
从未比较（死代码）；color_ir和frame_type连捕获都没有；AMB/DC code的epoch版本
（区别于码值本身）完全未涉及；AMB/DC code值本身只做自洽性检查，不是独立身份
验证**。这是本次NRE+ADCN复核里最实质的一处缺口——不是"部分覆盖"，是合同枚举的
一半以上具名子字段在这条唯一的身份绑定检查里根本不存在。

**为何这是真实缺口而非可以接受的简化**：这个测试文件的核心设计目的就是"逐笔
精确指定RAW码+独立重算黄金模型"，每个阶段每笔事务的frame_id/sample_index/color_ir/
frame_type在真实运行时都是完全可预测、可以被owner快照机制（`reg_owner_snapshot_*`，
本文件已有这个模式，用于precision）独立捕获并比对的——不存在"这个字段真的没办法
在这个场景下验证"这类结构性理由，只是TB自己没有把已经声明的端口接进比较逻辑。

---

## 与已有台账的关系

NRE/ADCN此前的证据状态（`PPG_ALIAS_MAPPING_TABLE.md`）此前均来自2026-08-30 Stage5
批次的"iverilog+xsim双工具全量confirmed"记录，本次工作线D复核**不推翻**这个记录本身
（双工具确认这两份TB文件真实能跑通、产生真实PASS，这个事实没有变），本次揭示的是
"PASS"这个结论背后，ADCN-03/07两条具体子句的检查深度不够，是对既有记录的**补充**而
非推翻，与本项目一贯"CONFIRMED"和"检查够不够深"是两个独立维度的既有原则一致。

台账本次**未改动**——按项目惯例，独立复核阶段只报告发现，是否需要新建/修改
`PPG_ALIAS_MAPPING_TABLE.md`里的具体行留给"是否要修复"这个后续决定之后再做。

## 2026-09-28修复完成，过程中发现自己复核方法有遗漏

用户授权"直接把这2处修上"后动手修复，**动手前按流程去核对`PPG_ALIAS_MAPPING_TABLE.md`
既有台账时，发现一个重要情况：本报告正文"发现真实缺口"这个判断本身有遗漏**——本次
独立复核只读了`tb_ppg_control_top_adc_numeric_scoreboard.v`一份文件，没有按这个项目
反复验证过的方法论去检查"其它文件是否已经有隐藏证据"（TOP-11/SID-01、P13/FFK等先例
确立的规矩），而台账里ADCN-03/07这两行**确实早就有跨文件交叉引用的既有论证**。真实
核对结果分两种情况：

- **ADCN-03的诊断位半句：既有论证真实、准确，本次复核判断有遗漏**。台账引用
  `tb_ppg_adc_s1_programmable_calibrator.v`的CAL-06/CAL-07，独立打开该文件核实
  （357-389行）：确认真的直接检查`o_saturation_low`/`o_saturation_high`，合法端点
  两者皆0、越界端点恰好单独置1，是真实、准确、完整的证据——这个半句在ADCN scoreboard
  自己的文件里没查到，不代表这个半句从未被验证过，是本次复核没有跨文件核实导致的
  误判。
- **ADCN-07的身份绑定半句：既有论证本身被发现有夸大**。台账引用`tb_ppg_control_top_
  owner_identity_backpressure.v`的OIB-07声称覆盖"frame/sample/color/frame_type/
  AMB-DC快照/AMB-DC epoch"六个字段，独立打开该文件核实（1638-1677行）：OIB-07自己的
  注释和真实断言代码**只检查frame/sample/color/precision四个字段**，`frame_type`/
  两个code快照/两个code epoch **完全没有出现在OIB-07的检查里**——台账这条引用本身
  夸大了覆盖范围。这意味着即使算上这条（部分不准确的）既有证据，`frame_type`/AMB-DC
  快照/AMB-DC epoch这5个字段本次复核判断"真实缺口"依然成立，只有frame_id/sample_
  index/color_ir三项因为OIB-07确实覆盖、被本次复核误判为缺口。

**结论**：ADCN-03不是新缺口，是复核方法本身漏做跨文件核实；ADCN-07里frame_id/
sample_index/color_ir三项同样如此，但frame_type/AMB-DC快照/AMB-DC epoch五项是
真实缺口，独立于台账既有引用都成立——且台账引用OIB-07时对覆盖范围的描述本身不准确，
这是本次顺带发现的一个新的、真实的台账文字问题。

**修复已完成，不因为上述发现而撤回**——即使ADCN-03和ADCN-07的frame/sample/color
三项本可以只做"更正台账文字说明证据在别处"就收尾，直接在ADCN scoreboard自己的文件里
用真实层次引用+owner快照模式补上直接检查，让这份文件对全部8个字段自己独立成立、
不再依赖跨文件论证，是更强的证据，不是浪费。具体修复：

- **ADCN-03**：新增`reg_cap_s1_saturation_low/high`，用层次引用直接读取
  `ppg_adc_s1_programmable_calibrator_Inst.o_saturation_low/high`（与`reg_cap_
  s1_value`同一拍捕获），替换原来"不重复判定"的占位注释，新增3条真实检查（低饱和
  匹配、高饱和匹配、两者互斥不可同时为1）。
- **ADCN-07**：扩展`reg_owner_snapshot_*`快照进程，新增`color_ir`/`frame_type`/
  `sample_index`/`amb_code_snapshot`/`dc_code_snapshot`/`amb_code_epoch`/
  `dc_code_epoch`共7个字段的commit时刻快照（复用`ppg_control_top.v`已经转发好的
  内部wire，与已有的precision/frame_id快照同一处声明、同一拍有效）；扩展结果捕获
  进程新增`color_ir`/`frame_type`/两个code epoch的capture；新增一条完整的8字段
  身份绑定检查（frame_id/sample_index/color_ir/frame_type/amb_code/dc_code/
  amb_code_epoch/dc_code_epoch，全部对着owner真实commit时的快照比对，不是自洽性
  检查）。

**回归证据**：iverilog真实跑通（`ADC_NUMERIC_SCOREBOARD_TB_PASS result_captures=16
track_branch_fires=16`，含2笔真实饱和事务）；真实Vivado 2022.2 xsim独立confirm
逐位一致（`JNT_BASELINE checked=54 pass=54`+同样的`result_captures=16
track_branch_fires=16`，0 FAIL）。改动完全局限在`tb_ppg_control_top_adc_numeric_
scoreboard.v`一份文件内，未触碰RTL、未触碰共享TB文件，未跑全套19-TB（blast radius
为0，比照本项目对单文件TB修复的既有惯例）。

## 建议的下一步

1. **NRE**：无需任何后续动作，6项独立复核后确认无缺口。
2. **ADCN-03**：补一处诊断标志的真实层次引用检查（`ppg_adc_s1_programmable_
   calibrator.v`的`o_saturation_low/high`，需要先找到从`ppg_control_top_Inst`
   到该实例的完整层次路径），预计是小改动。
3. **ADCN-07**：需要新增frame_id/sample_index/color_ir/frame_type/amb_code_epoch/
   dc_code_epoch共6个字段的真实身份绑定检查，思路是复用本文件已有的`reg_owner_
   snapshot_*`快照模式（在owner真正commit那一拍锁存期望值，正式结果到达时与
   `o_result_*`对应字段比较）——这是本轮工作线D新发现里工作量最大的一项，但方法
   论上并不困难，本文件已经有现成的、可以直接复用的快照对比范式。
