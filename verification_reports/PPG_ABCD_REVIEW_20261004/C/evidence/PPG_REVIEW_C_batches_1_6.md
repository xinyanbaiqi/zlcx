d18c6954621e53e5a6505dd3a6c688c266d23839

# PPG 数值链与算法专项 C

审阅进行中，未签核。

## 批次1：FIR

全文语义已读，具体见evidence/fir_review.md。独立合同向量和跨层generation尚在推进。复用A真实103 PASS日志并读比较与激励，变异负对照真实147错误。

### C-001 — FIR合同仍称sample-valid定向TB未实现

S3 / 合同，静态确认。位置 contracts/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md:686；原文摘录：`确认其中不含任何i_sample_valid引用，未见针对该端口的定向回归`。被审版本TB:1011设置资格0，:1017比较两次消费且历史/MAC/输出不推进；:1056、1084还有FIR-32/33，:1143实际接端口。原日志最后三项均真实PASS且总103。合同自身新增资格规范正确，但09-13说明已滞后于09-16/17 TB。反驳：查实际公开输入、断言条件及完整run.log；非已知N08观察项或F-001四份注入TB，style积压也不豁免合同错误。此条只说明证据状态文字错，不据此签核全部FIR。建议同步TB事实与验收状态。

## 批次2：基线与ADC前半链

已全文实读范围与逐项数值、握手、复位、TB比较核对保存在 [numeric_checkpoint_20261004.md](evidence/numeric_checkpoint_20261004.md)。目前共20份实读，仍保持部分状态；跨层资格、discard豁免前提和ID映射未闭环。

基线独立12组合同向量实际PASS，16384→16383舍入变异在新增半值case10被拒绝（退出1）。最初DrvFS I/O失败，后来复用A已恢复的Linux临时工具并通过tar标准输入传输自有副本；没有重启WSL或停止A进程。不能以65 PASS主TB或20005公式等价向量代替最终随机斜率/连续周期覆盖。

## 批次3：overlap、可编程重构与DC恢复

七份全文审阅及独立数学参考见evidence/adc_tail_review.md、evidence/adc_reference/。C11/C14/C15 discard条件豁免的当前START/empty链已静态重定位核实，未误报为缺RTL。后续已复用恢复的工具补跑重构独立4邻点及舍入负对照，见批次5补充日志；初始失败与后来实际运行记录均保留。

### C-002 — 四份ADC/fork TB漏接29个现有输入

- 严重度/层：S2 / TB；静态与既有真实编译确认，高置信度。
- 位置/关键原文（共3行）：router TB:465 `)u_ppg_adc_result_router(`；overlap TB:753 `)ppg_adc_pipeline_overlap_corrector_Inst_dut(`；DC TB:444 `ppg_adc_dc_recovery dut(`。各完整绑定表分别465..514、753..802、444..474，均已全文读取。真实路径在evidence/adc_reference/omitted_inputs.json列出。
- 依据：router的i_run_generation；overlap的i_run_generation和9项discard输入；DC的detect_code、stage1_raw/code_ext、stage2_raw/code_ext、nominal_15_code/valid/saturated，加NORMAL fork的i_run_generation及9项discard输入，共29项实际RTL输入没有TB绑定。固定版本Icarus -Wall逐项报告dangling input，skill AST确认端口存在。C12代际透传、C13 discard规范、C15§11.3八组诊断透传均要求真实接口行为。
- 影响：这些TB的正常数值PASS不能证明generation保持/匹配discard或新增诊断payload透传；有效窗口中的对应输入为Z且无相关比较。此条不声称数值算法故障或正式资格被这些字段污染。
- 证据：adc_reference/*_compile.log与*_run.log；人工完整激励/断言核对及omitted_inputs.json含skill AST端口行号。新变异因WSL故障未执行，未宣称负对照完成。
- 反驳：AMI实际实例连接上述生产接口；系统TB可能覆盖其中行为，仍需逐项核验。跨层连接不使这四个模块TB的缺失激励成立。F-001是另四份注入TB的cal-loss valid悬空，与本条不同；C11/C14/C15条件豁免针对discard/local_empty，不豁免DC已有8个诊断输入；5组已接受悬空输出也不是这些TB输入。
- 建议：补齐TB公开输入驱动、有效窗口断言和discard定向场景；先用错误generation/诊断透传变异确认判据，再更新覆盖记录。仅报告，不应用修复。

### C-003 — PR-06标签所述正负半值边界没有被两组激励构造

- 严重度/层：S2 / TB验证缺口；独立合同数学及变异仿真确认，高置信度。
- 位置：rtl/ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v:338..340；关键原文1行：`// PR-06：正负半LSB边界由黄金模型逐笔比较`。
- 依据/影响：C14§3和PR-06要求正负对称门限行为；本例S1=256,D2=256,gain=0,offset=±32768仍包含Stage1+0.5贡献，ACC_Q17=3599373/3468301，两者均正，舍入27/26。改变offset半值不等于总累加值到达半值门限。不得据该标签将定向正负边界写成已覆盖。
- 证据：独立BigInt contract_reference.mjs、boundary_derivation.json、rounding_coverage.json；参考自校验故意错误期望能拒绝。新增公开端口±65535/±65537邻点TB真实4 PASS；65536→65534变异在+65537点被拒绝（退出1），同一变异通过原PR-01..14+1024码sweep（退出0）。这确认原TB的门限覆盖缺口，暂无原RTL数值错误结论。
- 反驳：完整1024码sweep确有正负数，最近距半值门限25 Q17单位，故不称全TB完全漏负舍入；overlap OVL-09另有正负邻点1/3单位，但不是本DUT。合法ACC恒奇数，精确半值不可达，应测可达门限邻点，不能为了满足字面tie强行改变DUT中间量。该事项不是已知PRC-04 baseline构造策略或风格积压。
- 建议：改为能使总ACC处于正负门限两侧的公开输入向量，并使PR-06标签、真实比较及合同覆盖一致。

## 批次4：峰谷检测

三份全文语义及跨层sample-valid资格追踪见evidence/peak_review.md。累计30/44。原54项PASS只能支持实际比较范围，未将单调随机步长当作完整软件状态机golden。

### C-004 — 返回请求阻塞期间可被第二次谷值确认覆盖帧号

- 严重度/层：S1 / 叶子RTL返回载荷错误；公开端口仿真确认，高置信度。系统触发范围受PWC立即ready约束。
- 真实路径：[ppg_peak_valley_window_detector.v](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v:555)，相关438、404、533；合同[§11.4](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md:538)，TB[PVW-30](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_peak_valley_window_detector/tb_ppg_peak_valley_window_detector.v:851)。关键原文2行：

`assign o_result_ready = i_rstn && i_run_enable && (i_recheck_busy == 1'b0) && (peak_valid_o == 1'b0) && (valley_valid_o == 1'b0);`

`return_payload_o <= {RETURN_REASON_VALLEY, i_frame_id};`

- 依据/影响：C22§11.3两分支各自握手，§11.4返回原因/frame在反压期间保持。持有return ready0但消费valley后输入重新开放，同epoch第二个合法fine峰谷仍可确认，555不检查return pending，将未消费frame10改为21。冻结载荷义务违反，不据此宣称Top正常流程必现。
- 证据：evidence/peak_review.md逐项独立公开序列与门限推导；peak_public_vectors/tb_C_peak_return_hold.v固定期望frame10，真实原RTL失败：expected=10 actual=21，退出1；增加protocol_error_sticky必须为0的断言后仍在同一载荷比较失败。仓库外仅增加payload pending保持门控的反驳对照真实PASS，退出0。日志targeted_runtime_20261004/peak_return_hold_with_protocol_check与peak_return_guard_countercontrol；对照不应用为生产修复。
- 反驳：PWI绑定至PWC280正常ST_FINE立即ready，常规生产窗口通常一沿消费，限制了系统触发条件；叶子接口合同仍允许独立反压，没有该阻塞长度限制。原PVW-30没有消费valley或继续送样本，o_result_ready始终0，因此该用例PASS不能推翻反例。不是已知discard豁免、风格积压或F系列重复项。
- 建议：保持旧返回载荷，并约束新结论的建立/所有权；增加消费valley但阻塞return且继续输入的公开端口用例。仅报告，不修RTL。

## 批次5：IDAC与短测试补充

全文实读累计33/44。IDAC数值/状态/实际TB范围见evidence/idac_reference/review.md；实际短测试及负对照见evidence/targeted_runtime_20261004/README.md与results*.json。C-003升级为S2验证缺口、C-004按任务严重度定义升级为S1真实叶子载荷错误，均已有实际仿真证据。

### C-005 — IDAC单元搜索只用低码范围，未检出九位和截断

- 严重度/层：S2 / TB验证缺口；变异仿真确认，高置信度。
- 真实位置：[IDAC TB](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v:499)，范围499..506及restart配置464..472；关键原文1行：`i_dcs_ir_code_max = 8'd27;`。C17 [搜索算法](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:509)要求端点和至少9位；8位码域可产生sum510。
- 依据/影响：原TB所有真实搜索范围max<=30、sum<=60，闭环最终目标正确不能证明高码的中点求和。仓库外仅将AMB初始/后继9位和掩为低8位，原TB仍148 PASS退出0；独立0..255/目标200固定8候选序列原RTL通过，同变异第二候选63!=191退出1。
- 证据：targeted_runtime_20261004/results_idac.json及三个run.log；idac_reference/tb_C_idac_midpoints.v的期望均固定字面量，未从DUT中间量生成。
- 反驳：这是测试宽位边界覆盖缺口，不是原RTL溢出；原RTL530..541真实9位和正确。系统SID等是否补足仍需后续全文核验，不把当前148 PASS归因为旧generation悬空（09-30已真实修复）。无模拟传递函数证明。
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

## 批次6：NORMAL fork

全文实读累计35/44；细节见evidence/fork_review.md。C-002扩展至4份TB、29个真实悬空输入，同一发现不重复编号。新增真实位置：[fork TB完整绑定](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_normal_transaction_fork/tb_ppg_normal_transaction_fork.v:525)，真实A编译10个dangling警告保存在adc_reference/ppg_normal_transaction_fork_compile.log；50 PASS只覆盖实际FFK比较，不证明新增代际和cancel行为。
