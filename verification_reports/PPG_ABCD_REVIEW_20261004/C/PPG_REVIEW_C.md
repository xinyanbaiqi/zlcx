d18c6954621e53e5a6505dd3a6c688c266d23839

# PPG 数值链与算法专项 C

C主责44/44文件完成全文语义审阅；这不是功能签核。固定只读快照，未应用源码修复。范围为12 RTL、13模块/辅助TB、6数值系统/RAW TB、11合同和2支持头。重复系统文件以标准diff逐段核实已审共同原文，并读取全部新原文；证据给出逐段映射和哈希，不声称重复展示了全部相同代码。

9项C发现：S1 1项、S2 5项、S3 3项。C001→A F015、C002→F026、C003→F027、C004→F018已经合并；其余待A最终复核/去重。C004公开端口实际复现未消费返回frame10被第二个合法谷覆盖为21，限定叶子反压；不扩大为Top常规必现。

状态口径：完成表示所列审阅工作已做，发现错误也可审阅完成；真实验证未完成项独立保持部分。C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/id_review_matrix.csv含355个实际合同表列ID，255项审阅裁定完成、100项动态/跨组闭环仍部分；其中非C主责家族只核对相关依赖，不代其它组签核。合同C13无编号ID表，其握手、字段、generation/discard及§7五项验收随模块审阅笔记记录。

## 数值和证据范围

ADC冗余全1024 RAW映射、Stage1有符号权重/offset/33bit累加/12bit舍入饱和、overlap/可编程Q17中心公式和15bit饱和、DC恢复unsigned8bit码×signed32bit系数、21tap Q15 FIR及中心身份、基线顺序除法/共享乘法/平滑/限幅、峰谷模帧差和确认计数、IDAC9bit端点和/1LSB跟踪、NORMAL fork原子二分支均已逐支核对。独立参考从合同输入产生，不取DUT中间量；系统局部同源诊断/结构检查另标明。

实际短证据：FIR8公开合同向量；基线12向量及舍入变异拒绝；重构4个可达正负门限邻点及变异拒绝（同变异原1024 sweep仍PASS）；IDAC8个字面中点及sum8变异拒绝（原单元148 PASS）；DC公开正负粗饱和2向量与错误期望拒绝。峰谷载荷反例/协议0/对照和JNT数量门禁探针见原始日志。C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/targeted_runtime_20261004/results*.json记录16次恢复后短运行，预期失败不计成RTL通过；其它早期FIR日志和失败启动记录保留。

RAW八档整数模型、噪声32bit回绕、分段/漂移/clamp和JNT54真实条件已读。RAW只代表声明的数字输入环境；RGC13/14是参数周期/切迹比检查，不代精细峰谷全波形证明。

## 八门禁

| 门禁 | 实际证据和结论 |
| --- | --- |
| compile | 12 RTL静态AST+lint通过；A相同快照实际Icarus编译/运行证据另列。四TB29个dangling输入是C002，不把编译退出0当接口覆盖通过。 |
| ast | C实际analyze_existing 12份；最终目录门禁12文件/12模块/0 parse_error；796端口矩阵来自该AST，未自造解析器。 |
| readability | 原始strict失败：VG052=2、VG061=3；按已排期风格项汇总。 |
| comment | 本次真正扫描12文件、5652代码行，COMMENT_COMMENT_PLACEMENT=86；此前scanned_files=0的PASS废弃为无有效扫描。实体注释语义另由全文人工核对。 |
| naming | strict失败：VG066=1；与readability汇总有重叠，不重复计总数。 |
| profile | 当前skill规则簿/profile一致性通过；不代表数值或系统行为已签核。 |
| testbench | 全部对应激励/判据/异常路径已审；C16份短运行含正/负对照已保存，另有FIR独立8向量及系数变异。A的15份已完成C归属TB日志无FAIL；4份长系统TB未完成。C002/003/005/008/009等覆盖/判据缺口仍阻止完整验收。 |
| toolchain | 实际工具Icarus11、Windows bundled Python3.12；复用A恢复工具，未安装/重启。Vivado xsim/综合、Verilator和ASIC时序/CDC实测未运行，保持部分。 |

最终strict原始结果errors=92、strict_warnings=0、delivery_ready=false（6 VG+86注释落点项），证据 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/final_deliverable_gate.json。46 VG010封装例外和1 VG031接受差距按共同原始任务，222风格清理积压只做规则计数，不逐条作为新发现，也不将风格豁免泛化为功能通过。

## 发现

### C-001 — FIR合同仍称sample-valid定向TB未实现

S3 / 合同，静态确认。位置 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md:686；原文摘录：`确认其中不含任何i_sample_valid引用，未见针对该端口的定向回归`。被审版本TB C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_coarse_detection_fir/tb_ppg_coarse_detection_fir.v:1011设置资格0，:1017比较两次消费且历史/MAC/输出不推进；:1056、1084还有FIR-32/33，:1143实际接端口。原日志最后三项均真实PASS且总103。合同自身新增资格规范正确，但09-13说明已滞后于09-16/17 TB。反驳：查实际公开输入、断言条件及完整run.log；非已知N08观察项或F-001四份注入TB，style积压也不豁免合同错误。此条只说明证据状态文字错，不据此签核全部FIR。建议同步TB事实与验收状态。

A关联：已合并为F-015。

### C-002 — 四份ADC/fork TB漏接29个现有输入

- 严重度/层：S2 / TB；静态与既有真实编译确认，高置信度。
- 位置/关键原文（共3行）：router TB:465 `)u_ppg_adc_result_router(`；overlap TB:753 `)ppg_adc_pipeline_overlap_corrector_Inst_dut(`；DC TB:444 `ppg_adc_dc_recovery dut(`。各完整绑定表分别465..514、753..802、444..474，均已全文读取。真实路径在evidence/adc_reference/omitted_inputs.json列出。
- 依据：router的i_run_generation；overlap的i_run_generation和9项discard输入；DC的detect_code、stage1_raw/code_ext、stage2_raw/code_ext、nominal_15_code/valid/saturated，加NORMAL fork的i_run_generation及9项discard输入，共29项实际RTL输入没有TB绑定。固定版本Icarus -Wall逐项报告dangling input，skill AST确认端口存在。C12代际透传、C13 discard规范、C15§11.3八组诊断透传均要求真实接口行为。
- 影响：这些TB的正常数值PASS不能证明generation保持/匹配discard或新增诊断payload透传；有效窗口中的对应输入为Z且无相关比较。此条不声称数值算法故障或正式资格被这些字段污染。
- 证据：adc_reference/*_compile.log与*_run.log；人工完整激励/断言核对及omitted_inputs.json含skill AST端口行号。未对29项逐一运行接口变异；本条据完整绑定、独立AST及真实编译悬空警告确认。
- 反驳：AMI实际实例连接上述生产接口；系统的fork消费及生命周期检查提供部分补证，不能补足四个模块TB缺失的输入驱动与比较。跨层连接不使这四个模块TB的缺失激励成立。F-001是另四份注入TB的cal-loss valid悬空，与本条不同；C11/C14/C15条件豁免针对discard/local_empty，不豁免DC已有8个诊断输入；5组已接受悬空输出也不是这些TB输入。
- 建议：补齐TB公开输入驱动、有效窗口断言和discard定向场景；先用错误generation/诊断透传变异确认判据，再更新覆盖记录。仅报告，不应用修复。

A关联：已合并为F-026；four TB路径及全部29项输入行号见绝对路径 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/adc_reference/omitted_inputs.json。

### C-003 — PR-06标签所述正负半值边界没有被两组激励构造

- 严重度/层：S2 / TB验证缺口；独立合同数学及变异仿真确认，高置信度。
- 位置：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v:338（相关339、340）；关键原文1行：`// PR-06：正负半LSB边界由黄金模型逐笔比较`。
- 依据/影响：C14§3和PR-06要求正负对称门限行为；本例S1=256,D2=256,gain=0,offset=±32768仍包含Stage1+0.5贡献，ACC_Q17=3599373/3468301，两者均正，舍入27/26。改变offset半值不等于总累加值到达半值门限。不得据该标签将定向正负边界写成已覆盖。
- 证据：独立BigInt contract_reference.mjs、boundary_derivation.json、rounding_coverage.json；参考自校验故意错误期望能拒绝。新增公开端口±65535/±65537邻点TB真实4 PASS；65536→65534变异在+65537点被拒绝（退出1），同一变异通过原PR-01..14+1024码sweep（退出0）。这确认原TB的门限覆盖缺口，暂无原RTL数值错误结论。
- 反驳：完整1024码sweep确有正负数，最近距半值门限25 Q17单位，故不称全TB完全漏负舍入；overlap OVL-09另有正负邻点1/3单位，但不是本DUT。合法ACC恒奇数，精确半值不可达，应测可达门限邻点，不能为了满足字面tie强行改变DUT中间量。该事项不是已知PRC-04 baseline构造策略或风格积压。
- 建议：改为能使总ACC处于正负门限两侧的公开输入向量，并使PR-06标签、真实比较及合同覆盖一致。

A关联：已合并为F-027。

### C-004 — 返回请求阻塞期间可被第二次谷值确认覆盖帧号

- 严重度/层：S1 / 叶子RTL返回载荷错误；公开端口仿真确认，高置信度。系统触发范围受PWC立即ready约束。
- 真实路径：[ppg_peak_valley_window_detector.v](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v:555)，相关438、404、533；合同[§11.4](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md:538)，TB[PVW-30](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_peak_valley_window_detector/tb_ppg_peak_valley_window_detector.v:851)。关键原文2行：

`assign o_result_ready = i_rstn && i_run_enable && (i_recheck_busy == 1'b0) && (peak_valid_o == 1'b0) && (valley_valid_o == 1'b0);`

`return_payload_o <= {RETURN_REASON_VALLEY, i_frame_id};`

- 依据/影响：C22§11.3两分支各自握手，§11.4返回原因/frame在反压期间保持。持有return ready0但消费valley后输入重新开放，同epoch第二个合法fine峰谷仍可确认，555不检查return pending，将未消费frame10改为21。冻结载荷义务违反，不据此宣称Top正常流程必现。
- 证据：evidence/peak_review.md逐项独立公开序列与门限推导；peak_public_vectors/tb_C_peak_return_hold.v固定期望frame10，真实原RTL失败：expected=10 actual=21，退出1；增加protocol_error_sticky必须为0的断言后仍在同一载荷比较失败。仓库外仅增加payload pending保持门控的反驳对照真实PASS，退出0。日志targeted_runtime_20261004/peak_return_hold_with_protocol_check与peak_return_guard_countercontrol；对照不应用为生产修复。
- 反驳：PWI绑定至PWC280正常ST_FINE立即ready，常规生产窗口通常一沿消费，限制了系统触发条件；叶子接口合同仍允许独立反压，没有该阻塞长度限制。原PVW-30没有消费valley或继续送样本，o_result_ready始终0，因此该用例PASS不能推翻反例。不是已知discard豁免、风格积压或F系列重复项。
- 建议：保持旧返回载荷，并约束新结论的建立/所有权；增加消费valley但阻塞return且继续输入的公开端口用例。仅报告，不修RTL。

A关联：已独立复核合并F-018；A采用原请求先真实消费后再发送第二序列的对照通过，故意错误期望负对照被拒，证据 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/evidence/peak_hold_A、peak_hold_consumed_control、peak_hold_wrong_expected_negative。

### C-005 — IDAC单元搜索只用低码范围，未检出九位和截断

- 严重度/层：S2 / TB验证缺口；变异仿真确认，高置信度。
- 真实位置：[IDAC TB](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v:499)，范围499..506及restart配置464..472；关键原文1行：`i_dcs_ir_code_max = 8'd27;`。C17 [搜索算法](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:509)要求端点和至少9位；8位码域可产生sum510。
- 依据/影响：原TB所有真实搜索范围max<=30、sum<=60，闭环最终目标正确不能证明高码的中点求和。仓库外仅将AMB初始/后继9位和掩为低8位，原TB仍148 PASS退出0；独立0..255/目标200固定8候选序列原RTL通过，同变异第二候选63!=191退出1。
- 证据：targeted_runtime_20261004/results_idac.json及三个run.log；idac_reference/tb_C_idac_midpoints.v的期望均固定字面量，未从DUT中间量生成。
- 反驳：这是测试宽位边界覆盖缺口，不是原RTL溢出；原RTL530..541真实9位和正确。SID配置8..240且SID12耗尽阶段实际驱动一路增码至上限，源码能补充系统高码行为；该系统完整运行当前由A继续，不把单元缺口扩大为全系统漏检。不把当前148 PASS归因为旧generation悬空（09-30已真实修复）。无模拟传递函数证明。
- 建议：公开端口覆盖高码/和第9位与0/255端点，检查每个合法floor候选或独立性质，保留变异负对照。

### C-006 — IDAC冻结诊断清除端口名与实际叶子接口不一致

- 严重度/层：S3 / 合同接口，高置信度静态确认。真实路径[合同](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:159)、[RTL](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_idac_code_controller/ppg_idac_code_controller.v:75)、[TB绑定](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v:786)。关键原文2行：`input i_diag_clear_event,`；`input i_status_clear_event,`。
- 依据/影响：C17第4节137要求名称与原型一致，5.1/5.2文字同样指diag-clear，实际生产AMI仍绑定status-clear叶子名。按照冻结原型直接实例化会报不存在端口；当前生产连接有效，不是清除功能失效。
- 反驳：全局唯一诊断事件可在AMI映射到旧叶子名，但该来源映射不使同一合同的逐端口原型与实际一致。style积压不豁免规范接口；F-002/004/008属于其他身份/local-empty组，与本条不同。
- 建议：同步合同原型和来源映射，保留单一诊断源；仅报告不改接口。

### C-007 — IDAC合同仍禁止AMB不改码时的固定DCS重验证

- 严重度/层：S3 / 合同内部及依赖冲突，高置信度静态确认。真实路径[合同§8.4](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:503)、[现行依赖C16](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md:487)、[RTL](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_idac_code_controller/ppg_idac_code_controller.v:794)，TB377/568真实测试不变AMB仍重验。关键原文2行：`AMB码未实际改变时不得产生o_dcs_revalidate_request`（正文反引号省略）；`无论AMB committed码是否实际改变，都必须执行`。
- 依据/影响：C17§8.3、§8.4、IDC2-17仍是不变AMB不请求DCS，依赖C16§9.5/9.6与其修订§18明确固定AMB/R/IR三阶段；RTL与TB遵循固定三帧。两条相反规范不能同时签核。
- 反驳：不将实际无条件重验报成RTL故障；读取现行C16修订及真实TB条件后，裁定为C17落后文字。不是旧33失败或风格积压。
- 建议：同步C17相关正文和IDC2-17，并订正precision选择计数器的矛盾注释，保留实际三帧义务。

### C-008 — JNT检查数量不足时不累计错误，调用方继续进入数值场景

- 严重度/层：S2 / TB检查器；原文分支的独立短仿真确认，高置信度。
- 位置：[JNT收尾](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh:796)，关键801；[ADCN调用方](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v:1178)。关键原文3行：

`cnt_error = cnt_error + cnt_run_jnt_fail;`
`run_jnt_baseline_01_09;`
`task_build_adcn_sar9_nominal_config;`

- 依据/影响：C25§9.1:442要求不足52项通过时本组失败；当前移植头要求54项。若检查数不足且执行的子检查全部通过，flag_jnt_baseline_pass为0并打印FAIL，但cnt_run_jnt_fail为0，累计错误仍0。调用方没有检查该flag，直接执行组场景；末尾只按cnt_error判定。检查数量保护没有进入统一失败计数。
- 证据：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/jnt_count_probe/source_slice.txt保留796..804原文；C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/targeted_runtime_20261004/results_jnt.json三次实际编译/运行：54/54原分支通过；51/51、单项失败0时原分支打印JNT FAIL而error_count=0，独立断言退出1；仅在C隔离件让数量不足至少增加1错误的反驳对照错误数1、退出0。未跑完整系统变异，该探针仅验证检查器收尾分支。
- 反驳与范围：原有真实54项正常运行有效；本条不声称当前未修改系统TB已经只执行51项，也不把JNT全部单项失败判据说成失效。A外层回归按日志FAIL拒绝该输出，可阻止其入总报告PASS；仍不能把TB自身error_count=0当有效数量门禁。JNT头旧52/53注释不是本条原因；已接受TRK01或discard豁免无关。
- 建议：数量/通过数不足也进入统一失败计数，并在调用方核验前置pass；保留不足数量、错误条件和正常数量三个负/正对照。仅报告，不改共享头或TB。

### C-009 — 基线OPT-23/24未检验连续周期和随机最终结果

- 严重度/层：S2 / TB覆盖声明；全文源码及合同静态确认，高置信度。
- 位置：[除法检查任务](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v:410)，相关426；[两项检查](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v:1279)，相关1281、1286..1303；[合同](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md:589)。关键原文3行：

`reset_dut;`
`check_sequential_divider(24'sd2000, 24'sd0, 25'd2000, 16'd257, C_ALPHA_Q15);`
`check_case("OPT-24", flag_random_divider_ok && (cnt_divide_cycles == 42));`

- 依据/影响：OPT23要求连续两个完整周期独立、不复用旧pending；OPT24要求随机合法事务的正式最终结果逐位一致，并覆盖正负平滑、无相交、lead三区间、短回绕与饱和。实际OPT23两次调用均reset+新START；OPT24随机32次复用同一任务，独立判据只比较42轮内部商，没有随机最终平滑斜率golden，也没有连续pending上下文。不能据其PASS标签记录这些完整验收义务已覆盖。
- 证据：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/baseline_coverage_limits.md；A真实主TB65 PASS。本条未运行新的全TB变异，只作静态覆盖结论。
- 反驳：原除法黄金公式、42轮计数和共享乘法局部路由检查是真实有效；phase_a_equivalence的20005向量无DUT，只证明窄宽公式等价。C12组公开合同算术向量及半值变异补数值边界，但每组独立运行；系统连续波形的B[f]比较使用RTL报告斜率，不提供随机最终斜率独立golden。故这些证据不能反驳本项，也不据此宣称原RTL数值错误。
- 建议：增加不复位双完整周期、由输入和合同产生的完整最终参考，以及错误最终提交/旧pending复用负对照。仅报告。

## 跨文件反驳与已知事项

C11/C14/C15 discard/local_empty有条件免除已重定位到当前START→datapath_empty→三leaf输出valid链；未因缺这些端口重复报RTL故障。overlap/fork事件target与live generation在AMI生产绑定相等，终止时NORMAL输入受mask；未根据任意独立leaf错target扩成Top故障。固定8bit IDAC/4bit epoch域与冻结参数核对，未声称任意宽参数通过。

ADCN07八owner字段及Stage1饱和历史修复当前真实存在；ADCN08正式measurement结果由原子载荷寄存器、代表性比较和OIB03支持。另一detection分支的共享sample-valid消失已由B/A实际报告为F021，不能据数值载荷原子保持抵消该错误；同样关联F020周期超时旧上下文，不重复C编号。

TRK01接受结构资格证明；TRK05 precision未参与计数/pending选择；TRK06 pending资格抑制后来的同色证据；TRK07 Unit IDT12真查更新、track_adjust和单拍撤销；TRK08 Unit IDT13双端加结构限幅、系统16更新回绕；TRK09全部快照/epoch在资格AND，但动态错误epoch未逐项隔离。系统的弱代表性比较保留范围限制，未据此追加重复发现。IDAC高码SID耗尽源码能补系统覆盖，C005只指模块TB。

峰谷Group3只比较中心范围和顺序，叶子PVW独立极值/平台/回绕检查补精确身份；不把范围检查写成精确系统golden。基线BSL40主TB未定向，系统D01合法配置valid0驱动及PWI/RTL门控提供补证，完整系统动态仍待A。阶段性笔记中的未运行/候选以本报告和最终闭环记录为准，保留历史文件不篡改。

## 未完成与交接

A固定快照回归记录中，C归属baseline_cross、peak_valley_return、fir_tail_isolation、normal_slow_tracking四份系统TB仍未完成；未重复长跑，未标PASS或死锁。原始状态抓取 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/A_regression_C_scope_snapshot.json。355 ID表中100项部分包括其动态验收及其它主责系统家族；A/B完成相应项后更新总矩阵。Vivado编译/运行/综合、ASIC时序/CDC未验证。9项发现未修复；只读审阅已完成，最终修复验收及全系统签核由A负责。

报告 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/PPG_REVIEW_C.md；台账 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/coverage.csv；交接 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/handoff.md；证据 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/。
