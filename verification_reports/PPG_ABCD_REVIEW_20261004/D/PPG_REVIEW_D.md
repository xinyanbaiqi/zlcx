基准提交：d18c6954621e53e5a6505dd3a6c688c266d23839

<!-- 本文件继续由D组维护；共享源码保持只读。 -->

# PPG 接口、配置与跨域审阅 D

审阅日期：2026-10-03 至 2026-10-04（Asia/Shanghai）。任务类型 analyze；实际工具执行另记 validate。conservative，只读共享资产，不应用修复。

## 状态

24 个主责文件（10 RTL、7 TB、7 合同）的全文语义、全部端口与必要短专项已审阅。台账65项：60完成、5部分；文件整体19完成、5部分。5份TB的技能formatter静态compile/AST未通过，具体诊断与真实Icarus证据分开保留；不能裁定全部门禁通过。已确认 D-001～D-008：S1=1、S2=4、S3=3，其中D-001已被A归入F-013。完整回归由 A 管理，本组仅做必要短专项。缺陷未修复、全局ID未裁定CLOSED，不能视为功能或ASIC物理签核。

## 输出

固定交接：handoff.md；逐项台账：coverage.csv；原始证据：evidence/。

## 基准与工具

固定克隆 HEAD 为本报告首行提交，git status 为空。24 主责文件逐字节等于 git show；SHA256 和行数见 evidence/baseline.json。Python 3.12.14、A 组独立 Icarus 11.0/WSL Debian；没有运行 xsim、Verilator 或 ASIC 签核工具。默认沙箱执行 helper_unknown_error，已按权限机制使用具体命令升级执行。

技能依赖预检缺 erie-remote-ssh 和推荐依赖，按共同约定只做既有本地工具审阅，不安装。已读取技能入口、dispatcher、lint/ASIC/注释/可读性规范，并复用同字节版本已有 strict 门禁。技能 analyze-existing 最初因工作区路径校验失败；在本组目录建立字节相同输入副本后成功，失败尝试不记通过。

## 已有发现复核

F-005/F-006 保留原编号。已实际读取 physical/legacy/hypothesis/hypothesis_negative 全部原探针日志及源码执行方式：真实 Mode0 首字节 0100 got=1c、expected=0e；legacy 与假设控制 38 诊断字节+128 影子字节通过；错误预期 0f 触发 FAIL。芯片物理采样副本出现 3 个真实比较 FAIL；不因退出码0视为通过。证据根为 C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/evidence/spi_map_probe 和 chip_spi_ab。

F-007 保留原编号：芯片合同两路 reset_sync 正文与 V1.11 勘误和实际单路架构冲突。已全文核对芯片顶层，单个reset_sync实例、source复位直接使用w_rstn，符合勘误；不重复生成新发现。

## D-001：CCC-22 没有比较诊断清除后的 sticky=0

- 严重度/层：S2 / TB；置信度：仿真确认。
- 位置：固定快照 rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v:431、:437、:442。关键原文（3行）：

```verilog
i_diag_clear_event = 1'b1;
launch_control_inflight(1'b0, 5'b11110);
check_case(8'd22, (flag_reject === 1'b1) && (o_protocol_error_sticky === 1'b1) &&
```

- 合同依据：PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md §12.2:315 和 CCC-22:359 要求软件清除与错误优先两个行为。TB 在已有 sticky=1 时执行清除，但未在 435/436 之间检查为0；随后立即构造新拒绝，仅检查最终为1。
- 最小变异：仅在本组 evidence/ccc_clear_mutant.v 把 RTL:188 的软件清零改为自保持，复位清零不变。实际编译0、运行0，原TB仍打印 ALL CCC-01 TO CCC-26 PASS (26 checks)。错误 CCC-04 期望值负对照编译0，日志报 FAIL CCC-4 和 CCC REGRESSION FAIL (1 failures, 25 passes)，证明比较机制可失败。
- 原始日志：evidence/tb_ppg_characterization_control_cdc/clear_mutant.run.log、negative.run.log；命令和返回码为对应 result.json，变异源码完整保存。运行退出0不能作为 PASS 判据。
- 反驳：RTL 实际具有软件清除分支，故本项不是生产 RTL 缺失；整个497行TB无另一项在诊断清除后比较 sticky=0，CCC-23是复位清零不能代替软件清除。原已知 N04 清除缺独立断言是其他模块事项，F-001/F-006并不覆盖此项。合同没有豁免该清除检查。
- 影响/建议：CCC-22 的“清除通过”证据不足；增加纯清除后的零值比较，并保留同拍错误优先比较。本轮不修改共享TB。

## 批次一代码实读记录

reset_sync 全文：两级异步断言/同步释放，寄存器声明初值不替代板级复位；pulse_cdc_sync 全文：无反馈toggle两级同步+历史差分，需事件间隔/共同复位前提；config_cdc_bridge 全文：源忙时不接受、稳定总线请求应答邮箱，目标更新与采样同沿、两边同步属性齐全；characterization CDC全文：6bit顺序、valid重新武装、RUN模式冻结/整笔拒绝、拒绝高于diag_clear、STOP/abort配置保持。以上尚待时钟比例/相位/复位专项验证和芯片实际连接闭环。

CDC TB全文497行已实读，26项有真实 check_case 比较和watchdog；CCC-17/20/21在叶子层只证明配置侧，不证明SSW或模拟动作，需关联系统TB证据；监视器以普通不等式比较变化，对有效输出的X不能声称全面覆盖。新发现 D-001 已确认，其余覆盖继续核验。

## D-003：STOP与其他命令同拍时被拒绝，RUN继续许可新事务

- 严重度/层：S1 / RTL；置信度：仿真确认。编号按审阅候选顺序保留。
- 位置：rtl/ppg_system_config_manager/ppg_system_config_manager.v:313、:461、:462，关键原文（3行）：

```verilog
(i_stop_event && i_status_clear_event); // 任意两个事件同时出现都拒绝全部动作
i_stop_event && (flag_command_conflict == 1'b0) &&
((state_current == ST_RUN) || (state_current == ST_STOPPING));
```

- 依据：当前规范 C02 V4.9 §2:65、§3.1:228-236、MGR-11:348明确 STOP 抢占 START/COMMIT/status-clear，并保留冲突诊断。C03 V1.6页眉:3重复 Top-merged STOP 的规范性。与旧“全部命令互斥”规则不同。
- 证据：evidence/mgr_stop_probe.v保留入库TB前260行的复位、非法提交、清错、合法COMMIT和START真实比较，不注入DUT内部状态；进入RUN后在negedge准备命令、posedge后1ns比较。独立 STOP：state=11 run=0 allow=0 ack=1 episode=1，PASS；分别与START、COMMIT、status-clear并发：state=10 run=1 allow=1 ack=0 episode=0 error=1 code=01，三次均D_STOP_FAIL，编译0/运行1。日志和实际命令位于 evidence/tb_ppg_system_config_manager/stop_only.*、stop_start.*、stop_commit.*、stop_clear.*。
- 芯片层复现：evidence/chip_stop_probe.v只经真实SPI pad写完整合法配置、COMMIT、START及命令字，不注入内部状态、不依赖F-006的错误SDO采样。0x0090=0x02对照state=00 stop_hits=1 collisions=0 code=00，PASS；同一位置写0x06（STOP+COMMIT）观察到真实目标域两请求碰撞，state=10 stop_hits=0 collisions=1 code=01，D_CHIP_STOP_FAIL，编译0运行1。真实33文件依赖清单与命令见 evidence/tb_ppg_chip_digital_top/chip_stop_only.*、chip_stop_commit.*。探针额外no-op SPI事务只提供邮箱/脉冲捕获所需后续source时钟，两个对照完全相同。
- 反驳：wrapper:397-399逐位直连三个命令；Top:375仅注册合并STOP，:737-739原样送START/STOP/status-clear，未将竞争命令屏蔽。SPI:23/44允许同一命令字置多个bit。未见其他模块重新向manager补发丢失的STOP；系统fault blocking只门控START，不强迫manager退出RUN。不是已知tick-248、P2S或冻结D03事项；合同不允许此拒绝。
- 影响：安全终止请求可被竞争命令吞掉，manager不创建排空episode并继续授权新事务。建议保留冲突诊断同时落实STOP优先，补RUN/STOPPING同拍矩阵。本轮不修RTL。
- TB关联：MGR TB:378-387检查的是READY中的旧全拒绝规则，无法反驳RUN的丢STOP。错误MGR-03预期负对照产生真实FAIL（negative.run.log），并非无条件PASS。

## D-002：当前正式参数合同未落实到manager/wrapper/unpack接口

- 严重度/层：S3 / 跨层合同；置信度：静态确认。
- 位置：contracts/ppg_system_config_manager_semantic_contract.md:37、contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:63、contracts/ppg_system_active_config_unpack_semantic_contract.md:26。关键原文（3行）：

```text
The manager module shall declare and expose the following parameters.
| `C_CONFIG_WIDTH` | 1024 | exactly 1024 | Passed unchanged to `ppg_config_cdc_bridge`, manager and unpacker; any mismatch is an elaboration error. |
| `C_CONFIG_WIDTH` | 1024 | exactly 1024 | Must equal Top, ACTIVE wrapper, manager and configuration-CDC width; no implicit pack, truncate or extension is permitted. |
```

- 事实/依据：C02 §1.1:43-50要求8个公开参数，实际manager:54-58仅C_CONFIG_WIDTH和C_RUN_GENERATION_WIDTH；其余6项不存在且epoch端口/寄存器固定8bit。C03 §2.1:63-65要求3参数，wrapper:49-50无参数表且:90、:207固定8bit generation，:379仅bridge显式常数1024，:392/429调用manager/unpack不传参数。C05 §1.1:26要求C_CONFIG_WIDTH，unpack:47-50却无参数表、输入固定1024bit。C02:52-55所述Top透传每个参数路径因此不存在。
- 证据：上述完整源文件及本组技能canonical AST，evidence/skill_analysis/；注意技能analysis的parameter_count可能包含localparam，不能替代模块正式参数声明。
- 反驳：默认产品1024/8bit连接实际一致，本项不声称默认值截断；旧历史声明不能覆盖页眉唯一规范V4.9/V1.6。本合同没豁免缺参数；不是已接受style积压或chip层不纳入G-FP-01的问题。
- 影响/建议：合同允许的非默认identity/epoch/generation宽度及elaboration检查不能按所述使用；统一正式参数范围、透传与检查，或明确冻结固定值。本轮不改合同/RTL。

## D-004：wrapper TB没有比较V5具名字段的透传，错误alpha输出仍22项PASS

- 严重度/层：S2 / TB；置信度：仿真确认。
- 位置：rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v:193、:675、:874。关键原文（3行）：

```verilog
wire [15:0]o_alpha_q15; //观察基础斜率幅度比例
if((o_schema_version != 8'h04) || o_run_profile || o_input_source || (o_idac_mode != 2'b10) || (o_optical_mode != 2'b10) || o_initial_precision || !o_amb_enable || !o_dcs_enable || !o_amb_polarity || o_dcs_polarity || !o_stage1_calibration_valid || !o_stage2_calibration_valid || !o_dc9_recovery_valid || !o_dc15_recovery_valid || (o_amb_manual_code != 8'd64) || (o_dcs_r_manual_code != 8'd80) || (o_dcs_ir_manual_code != 8'd96) || (o_amb_threshold_low != -12'sd64) || (o_dcs_threshold_low != -12'sd48) || (o_stage1_weight_q16_0 != -26'sd17) || (o_stage1_weight_q16_9 != 26'sd26) || (o_stage1_offset_q16 != -32'sd99) || (o_stage2_gain_q16 != 20'sd54143) || (o_stage2_offset_q16 != -32'sd37) || (o_dc9_recovery_gain_q16 != 32'sd65536) || (o_dc15_recovery_gain_q16 != 32'sd32768) || (o_amb_recheck_interval_frames != 16'd4096))begin
$display("ALL AV4C-01 THROUGH AV4C-22 PASSED");
```

- 依据：C03 §8:246-251要求V5具名字段逐项原样导出，AV4C-02:296要求具名字段正确，AV4C-15:309要求符号保持。TB虽声明/接线V5字段，仅真实比较peak_valley_config_valid，未比较alpha等19字段；V4中间8个weight、部分range/high threshold也未在:675检查。
- 最小变异：仅把wrapper:356的o_alpha_q15输出改为16'h0000，manager/unpack/ACTIVE保持原样，非零合法默认alpha仍为16'h199a。入库原TB编译0运行0，22个PASS及完整横幅不变。原TB AV4C-01期望反转负对照则FAIL、errors=1。证据 evidence/wrapper_alpha_mutant.v、wrapper_negative.v 及 evidence/tb_ppg_active_v4_control_plane_integration/alpha_mutant.*、negative.*。
- 反驳：独立unpack TB的1024位one-hot确实能发现叶子切片错误，本组仅错位alpha切片就产生18个真实FAIL（evidence/tb_ppg_system_active_config_unpack/mapping_mutant.*）；该叶子TB没有经过wrapper输出桥，不能覆盖本次第二跳错误。本组两系统TB已全文核对，其场景检查不能替代全部具名接口输出逐项比较；未把本项扩大成全系统没有任何检查。实际wrapper透传正确，本项是入库wrapper验收证据不足，不是RTL输出错误。
- 建议：对全部具名输出与合同独立期望逐项比较，并采用区别于默认值的完整合法V5配置。本轮不改TB。

## 2026-10-04 批次二检查点

manager733行、wrapper500行、unpack211行及其980/889/340行TB已全文实读。核对V4/V5位表、signed字段、默认profile、原子提交、错误优先级、generation/episode、排空与非法编码恢复。manager MGR-21由合同要求联合层验证，不能因横幅MGR-01..24宣称本TB执行了21。

SPI681行、chip667行、P2S218行已全文实读；38诊断字节与128影子字节地址/位段、读副作用、DBG采样和chip实际模拟控制连线已核对。继续检查P2S有效串行窗口、队列反压、chip TB与跨层验收。P2S遥测错拍与no-backpressure更新仍按已知待落实事项，不新编号。

本组CDC五组比例/相位/释放偏斜各590个实际比较通过，文件evidence/d_cdc_probe/case0..4.*；错误有效payload预期负对照在check10报CDC_CHECK_FAIL、运行1。监视器在有效目标窗口检查X、事件次数/互斥/单拍和原子变化。此前两次测试台复位设置无效的失败日志保留为setup_invalid和monitor_setup_invalid，不计RTL失败。共同断言复位后的迟到请求检查已做；部分快目标配置在复位前可能已完成，不能称五组都覆盖了严格提交前取消。数字仿真不证明亚稳态、MTBF或布线时序。

本轮WSL的C盘drvfs出现Input/output error；首次probe编译126不算RTL失败或通过。恢复方式是在进程独立/tmp/ppg_review_D_01a0fd78_<pid>目录用二进制tar stdin传输已有Icarus和源文件副本，再将日志/vvp传回本组证据目录；未安装依赖、未重启WSL/停止A进程。

## D-005：ILM-04/05 的 LED 禁止驱动检查遗漏真实转换窗口

- 严重度/层：S2 / TB；置信度：仿真确认（原 ILM-04 场景的短片段，未重跑完整长回归）。
- 位置：rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v:1677、:1680、:1721；关键原文（3行）：

```verilog
if((!o_en_test) || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
wait_q3_release(real_release);
$display("PASS ILM-04 EXTERNAL_TEST_CURRENT BOTH SAR9: EN_TEST=1, LEDEN1/2=0, LEDDAC=0 held, RED=%0d IR=%0d",
```

- 依据：C25（PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md）§9.4.5:632/633，ILM-04/05 要求转换中无 LEDDAC 驱动窗口；C06:176 同样要求固定电流输入关闭LED驱动。原循环只在 wait_q3_release 前读一次，等待整个窗口时不检查，ILM-05 相同结构。
- 证据：batch3.py 从固定版本按真实行号复制 tasks/monitors/初始化与 ILM-04:1658-1699，跳过其他场景及JNT前缀调用；真实 Top 层级、源域 COMMIT、START、6次RED/IR真实owner、物理DONE和STOP/排空均保留。外部Top副本仅把:1449的输出映射改为 EXTERNAL_TEST_CURRENT 的Q3期间 LEDDAC=01。独立negedge观察器发现12个非法驱动周期，原比较却仍 errors=0、RED=3/IR=3、PASS ILM-04。未变异对照违规0；原期望00反转为01时 errors=1、FAIL ILM-04。三次编译0/运行0，判据来自真实比较日志。
- 证据文件：evidence/ilm04_fragment.v、ilm_led_q3_mutant.v、ilm04_wrong_expected.v；evidence/tb_ppg_control_top_input_light_static_matrix/fragment_positive.*、fragment_q3_mutant.*、fragment_negative.*，生成方式batch3.py。
- 反驳：2216行原TB及共享JNT前缀没有另一个固定电流RUN逐拍LEDDAC监视器；ILM-10有独立40拍监视，但属于另一场景，不能覆盖本循环后续窗口。叶子SSW验证不能发现Top输出映射这次外部变异。初版曾按用户限制延后ILM-11/12，后已回补，此项是已声称覆盖的ILM-04，与延后条款、D03、P2S已知事项无关。未把变异行为归因于生产RTL。
- 建议：在已接受固定电流RUN的全部有效窗口持续检查EN_TEST、LEDEN和LEDDAC，并累计有效周期；本轮不修改共享TB。

## D-006：ISE 以最后非零值代替选中总线的全波形逐位保持检查

- 严重度/层：S2 / TB；置信度：仿真确认（原 ISE-04 短片段）；同类 ISE-01/02、05 为静态确认的相同监视结构。
- 位置：rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v:780、:812-816、:954；关键原文（3行）：

```verilog
if(o_idac_sar9ambn_low !== 8'h00) reg_seen_sar9_ambn <= o_idac_sar9ambn_low;
if(o_idac_sar9ambn_low !== 8'h00) reg_ise_seen_ambn <= o_idac_sar9ambn_low;
if((reg_seen_sar9_ambn !== 8'hA5) || (reg_seen_sar9_dcn !== 8'h3C)) begin
```

- 依据：C25 §9.4.7:665/667/668/670，ISE-02/04/05/07要求当前波形逐位门控及冻结；TB:958、1174声称整个波形逐位正确。监视器没有记录中间错误，后面正确非零值会覆盖之前错误；零值也被忽略。未选中精度总线的连续零值检查:776/785确实有效，不能扩大为四条总线都没检查。
- 证据：batch3.py保留原初始化与 ISE-04 Phase A 两笔真实SAR9事务、持续SAR15零值监视、物理DONE、STOP/排空，跳过其他场景和JNT调用。外部Top副本只在每次Q3首个周期把SAR9 AMB输出A5翻转为A4，下一周期恢复；独立negedge观察器发现2个错误周期，原比较仍2个PASS、errors=0、zero_checks=5305。未变异观察0；错误期望A4产生2个FAIL、errors=2。
- 证据文件：evidence/ise04_fragment.v、ise_active_onecycle_mutant.v、ise04_wrong_expected.v；evidence/tb_ppg_control_top_idac_bus_isolation/fragment_positive.*、fragment_onecycle_mutant.*、fragment_negative.*。首次条件cnt=4超出真实Q3窗口，观察数0，保留为nontrigger_setup.*，不作为成功变异证据。
- 反驳：1532行原TB中的selected-bus及calibration-snapshot监视器均采用“最后非零值”结构，未增加逐拍错误sticky；共享JNT前缀的IDAC检查属于其前置事务，不在Phase A两笔事务持续运行。A的完整日志70条PASS仍保留，本项解释其有效性边界；叶子正常结果或SSW局部验证不能覆盖Top输出映射变异。合同未允许中间位错误；不是P2S、D03或accepted narrow-window问题。当前生产映射正常，不作RTL缺陷结论。
- 建议：根据合同的具体AMB/DC有效窗口持续比较每一位并锁存首次错误，窗口外按合法idle值判断；不要将最后非零值当作全波形相等。

## D-007：SPI 片选两级同步要求与实际异步片选结构不一致

- 严重度/层：S3 / 合同·跨层；置信度：静态确认。仅确认规范/实现矛盾，不据此声称物理CDC故障。
- 位置：contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md:128；rtl/ppg_chip_digital_top/ppg_chip_digital_top.v:385；rtl/ppg_spi_register_file/ppg_spi_register_file.v:432。关键原文（3行，首行为合同原句片段）：

```text
`CS_N`仍需过标准两级同步器，但只用于门控/复位比特计数器，不用于推导任何离散事件的触发时刻
.i_spi_cs_n(SPI_CS_N),            // 封装片选
always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
```

- 事实：芯片667行与SPI681行全文没有CS_N同步链；pad逐位直连SPI，SPI状态/计数/地址以原始CS_N上升沿异步清零、原始电平门控，命令触发则由完整字节计数生成。
- 反驳：reset_sync处理RSTN，不处理片选；ADC idle两级链也不处理片选。V1.11勘误明确豁免SPI_SCLK独立复位同步，但没有修改片选要求，V1.15只改诊断快照门控。F-007已关联复位文档冲突，未包含本片选条款；SPI真实边沿F-005是另一功能错误。本项没有要求在间歇SCLK上机械添加两拍延迟；那可能改变帧协议，需设计裁定。
- 建议：明确CS_N作为协议异步复位/门控的实际约束或确定同步方案，并同步冻结合同；本轮不改实现。

## 2026-10-04 批次三检查点

两系统TB全部可执行语句已实读，ILM前言与ISE英文修订说明已核查；代码中的历史“延后”须结合后面的真实回补阶段，未误判为仍未实施。JNT前缀650-806已补读；当前实际required=54而非历史53。A同版本完整日志实际ILM有54 JNT+19场景PASS（73条以PASS开头的行）、owner69/static_checks3000；ISE有54 JNT+16场景PASS（70条以PASS开头的行），sar15_zero_checks5305/sar9_zero_checks5308/results155。JNT汇总和最终横幅不计入上述PASS行。这里只引用原日志，不把计数或横幅作为逐拍覆盖证明。

该批次当时剩余的跨层ID/版本、矩阵状态、完整场景注释、24文件台账及最终基准复查，已在最终记录中补齐。D-005/006均为必要短专项，不重复A完整回归；当前留项以本报告首部状态和最终记录为准。

## D-008：C07 复位后 START 前置条件与自身模式例外互相矛盾

- 严重度/层：S3 / 合同；置信度：静态确认的内部矛盾。不是新RTL缺陷。
- 位置：contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md:210、:249、:295。关键原文（2行，:295首句省略）：

```text
NORMAL和外部固定电流START不以`o_control_valid`为硬门槛，但必须继续使用本合同规定的安全默认值或最近一笔合法提交值。
复位后必须重新完成至少一笔合法6-bit提交，才能允许新的START。
```

- 依据：同一V1.1正文§9/10明确允许NORMAL和固定电流使用复位默认控制启动，§11却不加模式限制地要求所有新的START先做6-bit提交；header:4明示CDC协议不变，没有后文覆盖前文的勘误。
- 实现/证据：manager的启动组合检查只消费已提交static-enable资格，不以ccc_control_valid为NORMAL/固定电流START门；Top:851/853区分已提交使能与valid，:746转发使能给manager。D-005的未变异短场景复位后从未触发表征6-bit提交，直接V4/V5 COMMIT+固定电流START，真实RED/IR各3笔事务通过，与§9/10例外一致。此项证据重点是合同原文，数字仿真仅展示实现选择。
- 反驳：STATIC_BIAS确实需先提交control-valid=1、enable=1，本项不否认该前置条件；若§11仅想描述STATIC_BIAS，必须明确限定。共同断言/错开释放限制:297不解决模式范围矛盾。已有F-007处理芯片复位架构，未处理此START条件；非N04/P2S/tick248已知事项。
- 建议：将§11的重新提交前置条件明确限定至STATIC_BIAS，或由设计方重新裁定NORMAL/固定电流启动要求；本轮不修改合同。

## 既有发现与追溯更新

最终复查时A总报告已扩展到F-030，本组按实际标题与关联重新核对：D-001=F-013、D-002=F-024、D-003=F-023、D-004=F-025、D-005=F-028、D-006=F-029、D-007=F-030；D-008尚待A复核/去重/统一编号。保留D编号供原始证据追溯，不将已合并的7项当作新的全局发现。D-003与F-009/010不同，前者是manager命令碰撞，后者是scheduler帧周期/末拍abort。F-008为AMI/Top正式discard缺五个epoch端口，关联跨层身份范围，不重复当D发现。

## 最终记录：范围、门禁与验证边界

本组24文件全部正文、可执行代码、场景/历史注释已实读；共享JNT前缀、Top实际生产者/消费者及有关跨组条款另行核对。10 RTL共396端口来自技能canonical AST，方向/宽度/signed、复位值、合法资格、握手及实际连线由源码与合同核对，详见evidence/port_inventory_D.json。正式参数以实际模块头声明为准，未用包含localparam的AST计数冒充公开参数。

65项台账中60项为审阅完成，5项为技能静态compile/AST留项。相应5份TB的全文语义审查已完成，文件整体保持部分。完成不表示缺陷已修复，也不表示全部验收ID已CLOSED。逐文件具体内容见本报告后附表、coverage.csv和evidence/review_ledger_D.json。

公共门禁严格结果原样保留在evidence/gate_reuse.json与evidence/tb_gate_review_D.json：

| 对象 | 静态compile/AST | 其余门禁/真实工具记录 | 裁定 |
| --- | --- | --- | --- |
| 10份RTL | 10/10 passed；本组analyze-existing均rc=0 | 8份readability/naming/profile正常；reset有VG060=10，chip有VG010=46；comment返回passed但scanned_files=0；testbench/toolchain未请求 | 静态门禁执行记录已核对；注释另由全文实读补足，不把零扫描数记全文检查 |
| wrapper TB、unpack TB | 2/2 passed | testbench_static_gate passed；strict整体仍delivery_ready=false（TB风格条款按用户原任务豁免） | 静态执行记录完成，不裁定所有strict条款通过 |
| CCC TB、chip TB | failed：only single module sources are currently supported | 实际均为单个无端口TB模块，采用合法module NAME;；formatter parse_mixin.py:187-205的头部模式要求括号；A真实Icarus编译/完整运行有记录 | formatter不支持该合法头部形式；保留compile/AST失败、文件部分 |
| manager TB、ISE TB | failed：control parser strict failure | 已保存formatter诊断；真实Icarus编译/完整运行有记录 | 未猜测具体控制流失败原因，不绕过静态门禁；文件部分 |
| ILM TB | failed：control parser strict failure及unclosed_block_comment | :2033的行注释含ST_AMB_*/ST_DCS_*；全文不存在块注释起始符；scoring.py:543直接对原文统计/*与*/次数，因行注释文字误报；另一个control-parser失败仍保留 | 注释误报原因已静态定位；整体AST并未因此修复或通过，文件部分 |
| 7份TB公共testbench检查 | 7/7 passed | comment均返回passed但扫描文件数0；toolchain均not_requested | 不代替人工语义/有效窗口/X检查，不等价实际回归通过 |

门禁中的compile是formatter AST+静态lint，真实Icarus compile/elaborate另存来源。未运行xsim、Verilator、综合工具；不把not_requested记passed，也不为补绿色结果改共享源码或安装工具。按本轮本地工具约定，这些缺项已明确列出，未伪造替代签核。

既有接受风格项按规则登记：本组reset_sync VG060=10为readability积压；chip VG010=46为封装pin命名例外，共56条既有接受项。本组没有把这些升级为功能S1，也没有把TB风格报错加入新的S4计数。全局其它风格积压由A按原规则汇总。

## 验收ID、版本与跨层策略

合同文本ID定位器先做正/负夹具：MGR-01中文后缀和CCC-04能识别，CCC-XX与WRONG-01不能识别。它只定位合同文字，不解析Verilog、不推导动态通过；CCC数字check_case与MGR-23在786行的实际OFF比较已人工对照。evidence/id_local_D.json含131项逐条实际位置、原要求与语义边界：MGR 24、AV4C 22、UNPACK 4、CCC 26、CIS 30、ILM 15、ISE 10。更正旧台账误写的UNPACK-05；固定合同只定义01..04。

MGR-21的联合校准请求阻断不在manager单模块TB内执行。实际Top/AMI/Scheduler请求资格是NORMAL、PD输入和SAR9等合法条件的交集；manager没有calibration_plan符合责任边界。动态联合验收须联系A/B证据，不能因MGR-01..24横幅推定21已测。AV4C-22导出资格位不证明下游算法端到端验收；CCC控制层通过不替代模拟波形检查。ILM与ISE的全部ID已按真实代码核对，D-005/006及ISE08/09/10的观察边界逐条列在ID证据中。

| C06跨层ID | 实际承接边界 | 本组核对与限制 |
| --- | --- | --- |
| CIS-01..07 | C02输入源/固定精度合法性；Top锁存与EN_TEST；C08/C09时序；AMI请求资格；ILM-01..07/15 | EN_TEST、owner、颜色、精度有真实检查；固定电流LED整段覆盖受D-005限制；不借CDC叶子26PASS裁定系统波形 |
| CIS-08..13 | C07控制提交→Top测量/模拟许可分离→C09静态向量；ILM-11..14 | STATIC_BIAS不产生owner/ADC、idle持续3000拍；完整向量只比一次、MUX只比更新前后，不能扩大为五bit所有转变沿的动态证明 |
| CIS-14..18 | C02 START原子快照/STOP/abort；C07 mailbox与复位；真实Top源域连接与JNT | D-003证实STOP竞争丢失；D-008记录复位START条件矛盾；时钟相位/比例/释放偏斜数字专项不代表物理CDC |
| CIS-19..20 | C09 AMB专用波形；C02 MANUAL/光学/精度合法性；AMI/Scheduler双端拒绝 | 独立校准窗口按当前C09 authority，不能用STATIC_BIAS覆盖；非法启动无ACK/owner等比较有实际代码，未将跨层global tag缺失等同没有行为检查 |
| CIS-21..26 | C02表征与STATIC_BIAS资格；C07 committed使能；ILM-01..03/08..12与MGR非法配置比较 | 纯RED PD两精度、非MANUAL拒绝与STATIC_BIAS input_source资格核对；C07 START前置条件冲突见D-008 |
| CIS-27..28 | Top测量run/allow与analog_run独立连线；AMI/Scheduler/SSW消费者 | 已核对实际连线及静态场景owner/idle比较；不能将analog_run和measurement_run合并为同一许可 |
| CIS-29..30 | MGR合法光学组合/OFF拒绝；ILM-04..07实际RED/IR事务 | BOTH/RED_ONLY/IR_ONLY事务计数及OFF拒绝有真实检查；两路LED全RUN要求的覆盖边界见D-005 |

C02 V4.9、C03 V1.6、C04 V1.7、C05 V5、C06 V1.3、C07 V1.1的规范页眉及声明依赖已逐一核对；矩阵§12.4对应4+7+2+2+7+5=27条声明绑定匹配。chip架构合同按V1.0正文及V1.1..V1.15各项勘误读取。C09当前规范V1.9与后续局部波形勘误分开；C06:398仍使用“当前V1.8”旧措辞，已记录为文字追溯边界，其§2:37明确V1.9优先，未据旧措辞推翻当前波形要求或新增功能缺陷。

已复用并核对A的ID/锚点扫描及负对照；evidence/anchor_reuse_D.json的本组相关条目为in_bounds 913、current_version_in_bounds 42、out_of_bounds 1、section_or_ambiguous 1。矩阵:1725引用wrapper:784而文件仅500行，关联既有F-003，不重复编号。in_bounds和alias/tag出现都不证明语义正确；全局矩阵保留NOT_CLOSED。

## 真实回归来源及短专项结论

7份完整入库回归由A管理，本组已读原run.log、run.rc和run.end，并核对TB真实比较，来源索引与SHA256见evidence/regression_reuse_D.json。所有运行有最终结束记录/rc0；以下计数只描述日志内容，不作为覆盖闭合依据：

| TB | 原日志内容 | 本组有效性结论 |
| --- | --- | --- |
| wrapper | 22条PASS，0 FAIL | D-004的错误alpha输出仍保持这些PASS |
| CCC | 26条PASS，0 FAIL | D-001/F-013纯clear漏比较 |
| manager | 1条汇总PASS，0 FAIL | 不能当成24个实际独立执行计数；MGR-21不在本TB，D-003未被原冲突场景捕获 |
| unpack | 1条汇总PASS，0 FAIL | 已读完整one-hot真实比较；错位alpha切片产生18个FAIL |
| chip | 6场景PASS，0 FAIL | F-006采样掩盖F-005；TC6窄窗口按原已接受事项保留 |
| ILM | 73条PASS=54 JNT+19场景；owner69/static_checks3000 | 中间LED变异12周期仍原场景PASS，不能以完整回归横幅反驳D-005 |
| ISE | 70条PASS=54 JNT+16场景；SAR15零检查5305/SAR9零检查5308/results155 | 中间选中bus变异2周期仍原场景PASS；持续未选中bus零检查仍有实际价值 |

CDC五组时钟比/相位/释放偏斜各590比较、合计2950；错误有效payload预期负对照真实FAIL。P2S短专项逐bit比较7完整161bit包，并观察639个反压周期；639是反压周期数，不是比较数。首包bit160错误期望立即P2S_BIT_FAIL，见evidence/d_p2s_probe/positive.*和negative.*。输入采用完整原子packet，只证明packer串行字段/队列行为；已知AMI三路遥测在反压下错拍仍按原事项保留。

全部关键新功能/覆盖结论的真实刺激、变异副本、原始日志、命令和返回码在各专项目录保存；setup_invalid、monitor_setup_invalid、nontrigger_setup与首次drvfs编译126均不作为RTL失败或成功证据。没有重复全套长回归，没有停止A后台任务。

## 最终留项与交付

1. 5份TB的formatter compile/AST仍failed：CCC、chip、manager、ILM、ISE。当前只读范围内保留原诊断/源码，未把合法Icarus编译当作formatter通过。需要技能维护方处理合法模块头、控制流解析及注释计数边界后再执行原字节门禁；不要求本轮擅改设计源码。
2. D-008待A复核/去重；其余7项已对应统一F编号。D-003等真实RTL缺陷及D-001/004/005/006覆盖缺陷未修；按conservative授权只报告。
3. 全局CIS/MGR联合层动态ID、矩阵CLOSED裁定和其它完整/长回归属于A/B/C汇总，不以本组全文实读或转交视为通过。xsim/Verilator/综合未运行；PVT、电气/布局、Virtuoso、MTBF与ASIC复位/CDC签核按约定属于后续。

最终基准复查evidence/final_baseline_D.json：HEAD仍为d18c6954621e53e5a6505dd3a6c688c266d23839，工作树为空；24主责文件+4依赖均等于固定git blob，主责SHA256与最初记录一致，所有未变异门禁输入副本逐字节一致。共享RTL、TB、合同与A报告没有写入。

输出根为C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D；正式输出PPG_REVIEW_D.md、coverage.csv、handoff.md及evidence/。文件级详表保存在evidence/file_review_table_D.md；其状态与65项CSV、review_ledger_D.json一致。

## 逐文件实际审阅表（最终台账）

| 文件（均为固定快照相对路径） | 层/行数 | 本组实际检查与语义边界 | 状态 |
| --- | --- | --- | --- |
| contracts/ppg_system_config_manager_semantic_contract.md | 合同/395 | C02 V4.9 / MGR-01..24；正式参数、合法配置、命令优先、generation/episode、排空与异常恢复；D-002/003；MGR-21动态联合层边界已记；D-002/003待设计方修正；MGR-21联合层验收由A/B核实，不宣称本TB已测 | 完成 |
| contracts/ppg_system_active_config_unpack_semantic_contract.md | 合同/117 | C05 V5 / UNPACK-01..04；1024bit联合位表、signed与零周期映射、保留位；仅4个本地ID，旧台账05已更正；D-002；D-002正式宽度参数合同未落实，待设计方处理 | 完成 |
| contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md | 合同/309 | chip V1.15 / F-005..07 / D-007；SPI物理采样、38诊断/128shadow、命令/DBG快照、P2S反压前提、复位/CS_N及模拟pad映射；F-005/006/007、D-007及已知P2S前提尚未修复；无物理签核 | 完成 |
| contracts/PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md | 合同/466 | C06 V1.3 / CIS-01..30；输入源、EN_TEST/LED、STATIC_BIAS完整向量、MANUAL资格、测量/模拟分离、STOP/abort/reset、跨层CIS映射；CIS-03/29动态覆盖受D-005限制；CIS-11仅前后值检查不等价五bit转变沿均验收；全局CLOSED由A决定 | 完成 |
| contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md | 合同/408 | C07 V1.1 / CCC-01..26；6bit合法序列、valid重武装、稳定载荷、RUN冻结、拒绝优先、clear/STOP/reset及START模式例外；D-001/008；D-001/F-013和D-008待修正；数字CDC验证不代表物理签核 | 完成 |
| contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md | 合同/343 | C03 V1.6 / AV4C-01..22；104端口、source邮箱到manager/unpack、具名V4/V5透传、START与ACTIVE绑定、Top实际第二跳及资格fanout；D-002/004；D-002/004待处理；AV4C-22仅资格导出不证明下游算法端到端验收 | 完成 |
| contracts/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md | 合同/644 | C04 V1.7 / V4[639:0]+V5[1023:640]；全部字段生产/消费连线、signed 12/20/26/32bit、10权重与V5 fanout；当前依赖2项逐一核对；全局矩阵仍NOT_CLOSED；仅tag/alias存在不记ID验收通过 | 完成 |
| rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v | TB/889 | AV4C-01..22 / D-004；全文889行；输入资格、CDC握手、真实ACTIVE/epoch/generation比较、watchdog/结束；alpha变异22PASS与错误期望FAIL对照；D-004未覆盖全部具名字段；完整22PASS不等价V5第二跳已验收 | 完成 |
| rtl/ppg_active_v4_control_plane_integration/ppg_active_v4_control_plane_integration.v | RTL/500 | C03/C04/C02/C05 / AV4C-01..22；全文500行/104端口；1024bit CDC、ACTIVE、manager命令、全部unpack输出第二跳和实际Top消费者；默认连接一致；D-002正式参数缺失、D-003命令优先缺陷属于相关路径，未应用修复 | 完成 |
| rtl/ppg_spi_register_file/ppg_spi_register_file.v | RTL/681 | chip §4-7 / F-005 / D-007；全文681行/84端口；38字节读map、128shadow逐位写、reserved/invalid、副作用、4命令、DBG快照、首末bit与CS_N；F-005真实Mode0首字节错误仍在；D-007片选文档矛盾；不得用legacy采样证明物理接口正确 | 完成 |
| rtl/ppg_config_cdc_bridge/ppg_config_cdc_bridge.v | RTL/192 | C03 §3/4 / mailbox；全文192行/9端口；忙拒收、稳定总线、toggle请求/ack、同步标记、目标原子更新、复位清除和时钟间隔；快目标部分case复位前已完成，不能称全5case均覆盖严格提交前取消；无MTBF/布局签核 | 完成 |
| rtl/ppg_p2s_packer/ppg_p2s_packer.v | RTL/218 | chip §5 / 161bit packet；全文218行/27端口；字段顺序、MSB首末bit、valid/ready、串行有效窗口、FIFO满空/队列与复位；7完整包、639反压周期验证packer，未证明AMI遥测在反压下原子对齐；已知3路遥测缺陷按原事项保留 | 完成 |
| rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v | TB/497 | CCC-01..26 / D-001=F-013；全文497行；26真实check_case、busy/拒绝/模式冻结与复位、watchdog；clear变异26PASS、错误期望FAIL对照；D-001纯软件clear漏比较；叶子26check不扩大为SSW/模拟全系统覆盖 | 部分 |
| rtl/ppg_characterization_control_cdc/ppg_characterization_control_cdc.v | RTL/222 | C07 / CCC-01..26；全文222行/16端口；6bit打包、valid重武装、busy冻结/拒绝、enable/MUX输出、sticky清除优先与复位；叶子控制行为正常；软件clear的TB覆盖缺D-001/F-013；无物理CDC签核 | 完成 |
| rtl/ppg_reset_sync/ppg_reset_sync.v | RTL/85 | chip §3 / V1.11 erratum / F-007；全文85行/3端口；异步断言、两拍同步释放、初值与复位区分、同步属性、chip仅目标域一实例；VG060=10已接受可读性积压；F-007复位正文未统一；真实ASIC释放/复位树未签核 | 完成 |
| rtl/ppg_pulse_cdc_sync/ppg_pulse_cdc_sync.v | RTL/110 | chip §7 / 4 SPI command events；全文110行/6端口；源toggle、目标两级同步/历史差分、单拍脉冲、复位、无反馈事件间隔前提；数字时钟比/相位检查完成；固定SPI事务间隔前提外的任意高速事件流未声称支持 | 完成 |
| rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v | TB/2216 | ILM-01..15 / CIS-01..30 / JNT-54 / D-005；全文2216行含中英文场景历史/实际回补；真实COMMIT/START、owner/颜色/精度、DONE、STOP、static 3000拍、资格窗口/X与watchdog；ILM04三对照；D-005 LED中间窗口漏查；ILM13/14静态向量仅一次完整比较、MUX前后比较；默认production注入0不等于F-001的注入1环境 | 部分 |
| rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v | TB/1532 | ISE-01..10 / JNT-54 / D-006；全文1532行含中英文历史；真实SAR9/15物理事务、未选中总线持续零检查、选中最后非零、搜索/冻结、145笔wrap、watchdog/结束；ISE04三对照；D-006选中bus中间错误可被覆盖；ISE08/09未逐拍比pending/update，ISE10不证明全部后续结果身份，边界已记 | 部分 |
| rtl/ppg_system_config_manager/ppg_system_config_manager.v | RTL/733 | C02 / MGR-01..24；全文733行/33端口；全部状态/合法编码、V4/V5资格、COMMIT/START/STOP/CLEAR、错误及非法状态恢复、epoch/generation/episode；D-003 STOP碰撞实缺陷、D-002参数合同矛盾仍在；联合calibration_plan门控按跨层边界 | 完成 |
| rtl/ppg_system_config_manager/tb_ppg_system_config_manager.v | TB/980 | MGR-01..24 / D-003；全文980行；全部输入驱动和真实比较/错误计数/结束；MGR23通过786行OFF比较，MGR21不在本TB；STOP单独与3冲突专项/错误预期；原MGR11只测READY非STOP冲突；MGR21动态联合层需A/B，不能以横幅推定执行 | 部分 |
| rtl/ppg_chip_digital_top/tb_ppg_chip_digital_top.v | TB/893 | chip TC1..6 / F-006 / D-003；全文893行；真实SPI帧与边沿、3诊断读值、模拟pad结构、reset、serial窗口/结束；单STOP/冲突完整pad短专项；F-006 pre-NBA SDO采样掩盖F-005；原TC5未动态选dbg3，TC6窄窗口分支按已接受事项不新编号 | 部分 |
| rtl/ppg_chip_digital_top/ppg_chip_digital_top.v | RTL/667 | chip §1-9 / F-005..07 / D-003/007；全文667行/46端口；pad方向/宽度、SPI38诊断与shadow、命令CDC、Top全部模拟控制、P2S数据/valid/backpressure、复位；VG010=46为accepted pad例外；S1 D-003已走真实SPI复现；P2S已知错拍与F-005保留 | 完成 |
| rtl/ppg_system_active_config_unpack/tb_ppg_system_active_config_unpack.v | TB/340 | UNPACK-01..04；全文340行；1024位one-hot独立期望、signed位宽/10权重/保留区、default映射/结束；alpha切片错位18FAIL负对照；纯叶子切片不证明manager的资格或wrapper第二跳；本地仅4ID，无UNPACK-05 | 完成 |
| rtl/ppg_system_active_config_unpack/ppg_system_active_config_unpack.v | RTL/211 | C05/C04 / UNPACK-01..04；全文211行/68端口；1024bit全部具名切片、10权重、符号、reserved、组合零延迟，无时序状态；叶子alpha切片变异可FAIL，不能覆盖wrapper第二跳D-004；D-002正式宽度参数未落实 | 完成 |
