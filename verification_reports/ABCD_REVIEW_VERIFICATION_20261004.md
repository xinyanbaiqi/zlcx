# 外部ABCD审阅报告逐条复核（第一阶段，2026-10-04至10-05）

## 0. 结论先行

- 四份报告共51个F编号，加A报告§4的K-001，合计52条，逐条复核：
  - **确认49条**：RTL功能11条、TB有效性19条、合同/矩阵/台账19条；
  - **已修复2条**：F-001（`edec143`）、K-001（`6c68094`，复核期间推送）；
  - **疑似1条**：F-044（验收证据范围待裁定）；
  - **误报0条**。
- 另有1条复核中新发现的观察：N-1（AMI诊断清除不检查活动blocking，见§5.12）。
- 11条RTL功能缺陷全部做了仿真确认：在仓库外写最小临时TB，xsim 2022.2确认，部分用iverilog交叉。按可达性分三档：
  - 芯片真实节拍可达：F-005、F-009、F-010、F-020、F-022、F-023、F-035；
  - 集成层（AMI/control_top）可达，芯片原生节拍不可达：F-019；AMI级可达，control_top原生节拍下1.08万次握手中未触发：F-021；
  - 只在叶子层可达，常规父链被屏蔽：F-018、F-034。
- 第一阶段没有改任何RTL、TB、合同、矩阵或别名表。修复方案见§10，等待用户选择。

## 1. 输入核对

目录`D:\PPG_ABCD_REPORTS_20261004\PPG_ABCD_REPORTS_20261004\`，四份报告的字节数和SHA256均与`REPORT_SHA256.json`一致：

| 报告 | 字节 | SHA256 | 一致 |
|---|---:|---|---|
| PPG_REVIEW_A_CURRENT.md | 235532 | 9e427f6015a5fb9b89a7628911f3ab3ab80c5a58debd2e631926483f3941d95d | 是 |
| PPG_REVIEW_B.md | 54405 | 843b1b8d01be2588eff0262237575eb5305698c01e33b0649ca0c2efd5968c98 | 是 |
| PPG_REVIEW_C.md | 24080 | 973cc09a75805b26178d035c7fc67912896baba9a3c15d985bbf45e6d73282b6 | 是 |
| PPG_REVIEW_D.md | 42337 | 69988b784a15fa3a26a293fae8ae1379a8e0362a146167f27903a4d50ed8b4bf | 是 |

各组编号与F号的对应关系：
- B-001→F-014、B-002→F-012、B-003→F-009、B-004→F-011、B-005→F-010、B-006→F-019、B-007→F-020、B-008→F-021、B-009→F-022、B-010→F-034、B-011→F-036、B-012→F-035、B-013→F-040、B-014→F-041、B-015→F-042、B-016→F-044、B-017→F-043、B-018→F-046、B-019→F-047；
- C-001→F-015、C-002→F-026、C-003→F-027、C-004→F-018、C-005→F-031、C-006→F-032、C-007→F-033、C-008→F-037、C-009→F-038；
- D-001→F-013、D-002→F-024、D-003→F-023、D-004→F-025、D-005→F-028、D-006→F-029、D-007→F-030、D-008→F-039。

按约定，同一F号只计一次，不把各组问题数相加。

## 2. 被审基准与当前HEAD

- 报告的审阅基准：`d18c695`。
- 本次开工时的origin/main：`668a5ea`（任务C推送）。
- 写本报告时的origin/main：`6c68094`。两者之间的提交：

| 提交 | 内容 | 对复核结论的影响 |
|---|---|---|
| `bb39a0f` | B会话合同批次3第二阶段：C08 V1.12/C10 V2.4、芯片顶层合同V1.16勘误、矩阵/别名表的RTL/TB行号重映射 | 只改contracts/与报告。合同类条目改以本版重查，见§7 |
| `5bb9d06` | 任务C报告附录A勘误 | 无 |
| `3f4673d` | AMI单元TB V1.11：AMI-46/47→AMI-DISC-1/2，AMI-48/49→AMI-SID05-1/2，只改标签 | F-019/F-020/F-021/F-022的探针基于668a5ea版AMI TB，检查逻辑相同，结论不变。下文"AMI-46"即现在的AMI-DISC-1 |
| `2bb6b17` | AMI单元TB V1.12：标签打印方式调整 | 同上 |
| `6c68094` | B会话：矩阵§12.10第3408行原行订正（C23协议sticky按PWC V1.4改写） | K-001已修复，见§7 |

- `d18c695`→`6c68094`之间改动的RTL只有三处：scheduler V1.9（头部+2行，原`:567`一行逻辑）、AMI两行注释、PWC文件头。其余RTL逐字未变。所有RTL复核以668a5ea版RTL为准，它与6c68094逐字相同。

## 3. 方法

- 只读复核。仿真全部在仓库外的`D:\PPG\verilog\ppg_regression_runs\abcd_20261004\`进行：
  - `src_668a5ea`、`src_d18c695`、`src_3f4673d`都用`git -c core.autocrlf=false archive`导出；
  - `probes/`下按F号分目录，存放临时TB、monitor、变异副本和日志。
- 仿真器：
  - Vivado 2022.2 xsim（确认用）；
  - Icarus Verilog 12（探索与交叉用，`-o`放在最前）。
- 构造临时TB的手法：
  - 叶子RTL复用该模块单元TB已有的task，在原序列中插入或替换场景（`probes/mk_insert.py`、`mk_probe.py`），其余部分不动；
  - 系统级只加被动monitor（作为第二个top），不改TB，不force任何net。
- TB有效性类：
  - 用`probes/mut/mutrun.py`对RTL做单处变异，用原单元TB原样回归，看是否仍PASS；
  - 不能廉价变异的，读TB判据原文做静态确认。
- 合同类：在`src_3f4673d`（contracts/与6c68094相比仅差矩阵第3408行一行）上逐条重读合同原文与RTL。
- 每条RTL缺陷都做了反驳尝试：是否有其他机制覆盖、合同是否允许、真实系统里能否到达。结论写在各条的"可达性"里。
- 限制：
  - 没有ABCD组的原始日志或探针，凡采信的结论都由本次重新构造证明；
  - F-019、F-020、F-034、F-035的芯片/Top级端到端构造没有全部重跑，只给出静态可达性判断，下文逐条注明。

## 4. 总表

判定说明：
- "确认-仿真"表示本次亲自跑仿真复现；
- "确认-静态"表示代码或合同原文事实明确，不需要仿真；
- 严重度：S1=RTL功能缺陷，S2=验证缺口，S3=合同/台账与RTL不一致，S4=注释/风格。

| F | 出处 | 层 | 一句话 | 判定 | 严重度 | 可达性/证据摘要 |
|---|---|---|---|---|---|---|
| F-005 | A§3, D | RTL | SPI读回在Mode 0下提前一位移出 | 确认-仿真 | S1 | 芯片可达。f005：真上升沿采样读回`4a/78/1f/02`，应为`a5/3c/0f/81` |
| F-009 | A, B-003 | RTL | 连续NORMAL宏帧5001拍 | 确认-仿真 | S1 | 芯片可达。f009：周期5001，空拍时eligible=1 |
| F-010 | A, B-005 | RTL | CAL末拍rollover覆盖同拍abort/STOP | 确认-仿真 | S1 | 芯片可达，影响有界。f010：多出5000拍CAL帧，frame_id跳号 |
| F-018 | A, C-004 | RTL | PVW返回请求反压期间frame被第二个谷覆盖 | 确认-仿真 | S1 | 叶子可达；常规父链PWC立即ready，只有PWC fault_hold时可达 |
| F-019 | A, B-006 | RTL | 正式结果discard身份取自已推进的上游 | 确认-仿真 | S1 | AMI/control_top可达，芯片原生节拍不可达。f019：报91/901/IR，实为90/900/RED |
| F-020 | A, B-007 | RTL | 周期AMB截止后内层inflight不释放，重检永不重试 | 确认-仿真 | S1 | AMI级仿真；芯片在owner错过tick 248时可达（与SID-05同前提）。f020 |
| F-021 | A, B-008 | RTL | measurement先消费会清掉detection待用的sample_valid | 确认-仿真 | S1 | AMI级仿真；两份control_top长TB共10823次握手未触发 |
| F-022 | A, B-009 | RTL | AMI新START清除历史protocol sticky | 确认-仿真 | S1 | 芯片可达。f022 |
| F-023 | A, D-003 | RTL | STOP与START/COMMIT/clear同拍时被吞 | 确认-仿真 | S1 | 芯片可达：SPI一次写0x03或0x0A。f023 |
| F-034 | A, B-010 | RTL | PWC discard与安全提交同拍仍提交精度并发事件 | 确认-仿真 | S1 | 叶子可达；Top常规父链被scheduler门控屏蔽（初判） |
| F-035 | A, B-012 | RTL | SSW abort同拍吞掉匹配完成，owner永久残留 | 确认-仿真 | S1 | 静态判断芯片可达，后果直到复位才解除。f035 |
| F-001 | A, B, C, D | TB | 4份19-TB注入valid悬空 | 已修复（edec143） | S2 | f001：修前FIR输入资格X（3/5、8/10），输出X=0，无检查读取它 |
| F-006 | A, D | TB | 芯片TB在NBA前采样SDO，掩盖F-005 | 确认-仿真 | S2 | f005 legacy模式即原TB的采样方式 |
| F-011 | A, B-004 | TB | FSC-14允许5001 | 确认-仿真 | S2 | f009同一次运行FSC-14 PASS |
| F-012 | A, B-002 | TB | SUP10A不能证明历史未清时重开episode | 确认-仿真 | S2 | 变异后仍14 PASS |
| F-013 | A, D-001 | TB | CCC-22不比较清除后sticky=0 | 确认-仿真 | S2 | 变异后仍26 PASS |
| F-016 | A | TB | PRC-09把FIR空拍算作不合格窗口 | 确认-静态 | S2 | TB:1046-1053、FIR:442 |
| F-017 | A | TB | PRC-10只检测相邻重复 | 确认-静态 | S2 | TB:902 |
| F-025 | A, D-004 | TB | AV4C漏比较alpha | 确认-仿真 | S2 | alpha恒0变异后仍22 PASS |
| F-026 | A, C-002 | TB | 4份ADC/fork TB漏接29个输入 | 确认-静态（编译诊断） | S2 | iverilog -Wall报1+10+8+10 |
| F-027 | A, C-003 | TB | PR-06未构造门限邻点 | 确认-仿真 | S2 | ROUND_HALF 65534变异后仍PASS |
| F-028 | A, D-005 | TB | ILM-04/05 LED检查跳过Q3窗口 | 确认-静态 | S2 | TB:1676-1679 |
| F-029 | A, D-006 | TB | ISE只比较最后一个非零值 | 确认-静态 | S2 | TB:780-787/954 |
| F-031 | A, C-005 | TB | IDAC单元TB未覆盖9位和 | 确认-仿真 | S2 | 截位变异后仍148 PASS |
| F-036 | A, B-011 | TB | PWI-01终判丢弃累计前提 | 确认-仿真 | S2 | GROUP_DELAY=0变异后仍5 PASS |
| F-037 | A, C-008 | TB | JNT数量不足不计入错误 | 确认-静态 | S2 | prefix:796-801；脚本:90 |
| F-038 | A, C-009 | TB | OPT-23/24未做连续周期和最终结果差分 | 确认-静态 | S2 | TB:410、1281-1303 |
| F-040 | A, B-013 | TB | INJ-04在两路ready必然为0的窗口里检查互斥 | 确认-静态 | S2 | TB:999-1003、AMI:1012-1013 |
| F-041 | A, B-014 | TB | RRC-01不比较间隔 | 确认-静态 | S2 | TB:1067-1071 |
| F-042 | A, B-015 | TB | OIB-06不检丢失和元数据错标 | 确认-静态 | S2 | TB:948-960 |
| F-049 | A | TB | INJ-03只排除全X | 确认-静态 | S2 | TB:961 |
| F-044 | A, B-016 | TB/跨层 | P06叶子去使能没有被动态覆盖 | 疑似 | S2? | Top RUN锁存使其在合法RUN中不可达，需裁定证据范围 |
| F-002 | A | 合同 | C13要求完整TXN_ID，overlap缺5个epoch | 确认-静态 | S3 | overlap:69-77 |
| F-003 | A | 矩阵/别名表 | 失效锚点 | 确认-静态（抽样） | S3 | bb39a0f已修正一部分，如alias:58的RTL锚点；alias:58出处`MATRIX:872`仍失效 |
| F-004 | A | 合同 | C13写Router有注册式local_empty | 确认-静态 | S3 | Router无always、无该端口；与C12:65矛盾 |
| F-007 | A, D | 合同 | 芯片合同正文仍写两路reset_sync | 确认-静态 | S3 | 合同:55/66-67/82/84/103（V1.16）；RTL只有一个实例 |
| F-008 | A | 合同 | C01/C10公开measurement-discard缺5个epoch | 确认-静态 | S3 | AMI/Top无对应端口 |
| F-014 | A, B-001 | 合同/RTL | Supervisor缺elaboration参数拒绝 | 确认-静态 | S3 | 默认5000/13合法 |
| F-015 | A, C-001 | 合同 | FIR合同称sample_valid无定向TB | 确认-静态 | S3 | FIR-31/32/33已PASS（f485cbc基线） |
| F-024 | A, D-002 | 合同 | manager/wrapper/unpack缺正式参数 | 确认-静态 | S3 | manager只有2个参数 |
| F-030 | A, D-007 | 合同 | CS_N两级同步条款与原始CS异步清零不符 | 确认-静态 | S3 | SPI中7处`posedge i_spi_cs_n` |
| F-032 | A, C-006 | 合同 | IDAC清除端口名不一致 | 确认-静态 | S3 | 合同`i_diag_clear_event`，RTL为`i_status_clear_event` |
| F-033 | A, C-007 | 合同 | C17禁止不改码时重验，与C16、RTL相反 | 确认-静态 | S3 | C17:503，C16:487 |
| F-039 | A, D-008 | 合同 | C07的START前提与模式例外矛盾 | 确认-静态 | S3 | C07:249与:295 |
| F-043 | A, B-017 | 合同 | C18窗口长度的直接消费者写成PWC | 确认-静态 | S3 | PWC无这两个端口 |
| F-045 | A | 矩阵 | §12.4a的26个摘要中23个不符 | 确认-静态 | S3 | 在3f4673d上重算：3个匹配，23个不符 |
| F-046 | A, B-018 | 跨层 | FSC/SUP同号不同义 | 确认-静态 | S3 | C08:1136/1147/1150/1167/1168 对 TB:601/618/629/745/761 |
| F-047 | A, B-019 | 合同 | C09第3行V1.10与第7行sole V1.9并存 | 确认-静态 | S3 | 依赖表仍绑定V1.9 |
| F-048 | A | 合同 | C01 §4.1"only四路"与第五路CCC冲突 | 确认-静态 | S3 | Top有5路`.i_diag_clear_event(flag_diag_clear_event)` |
| F-050 | A | 别名表 | SID-11仍标SKIP、结构不可达 | 确认-静态 | S3 | alias:148；基线日志有`PASS SID-11` |
| F-051 | A | 合同 | C24复位端口名`i_rstn_2m` | 确认-静态 | S3 | RTL只有`i_rstn` |
| K-001 | A§4 | 矩阵 | 第3408行仍写PWC START先清sticky | 已修复（6c68094） | S3 | 2bb6b17及之前成立；6c68094原行订正为diag-clear-only，与PWC:508-513一致 |

## 5. RTL功能缺陷详细证据

探针目录统一为`D:\PPG\verilog\ppg_regression_runs\abcd_20261004\probes\<f号>\`。下文行号指668a5ea版RTL，与6c68094相同。

### 5.1 F-005 SPI读回错一位（S1，芯片可达）
- 机理：
  - `cnt_bit_in_byte`在posedge更新（`ppg_spi_register_file.v:472-476`）；
  - `flag_byte_boundary = (cnt==7)`（`:280`）；
  - 读移位寄存器在negedge装载/左移（`:458-466`），`SDO = reg_read_byte[7]`（`:356`）。
  - 结果是装载发生在本字节第7个上升沿之后的下降沿：主机第8个上升沿采到的是下一字节的bit7，下一字节第1个上升沿前已经左移一次。真实Mode 0主机读到的是`{b6..b0, next_b7}`。
- 仿真（`f005/tb_f005.v`，叶子SPI加pulse_cdc_sync，2 MHz/4 MHz）：
  - 写`A5 3C 0F 81`后突发读；
  - LEGACY（下降沿同时间槽采样，即芯片TB的方式）：`a5 3c 0f 81`，PASS；
  - PHYS（上升沿前1 ns采样）：`4a 78 1f 02`，FAIL，与机理推算逐字节一致；
  - xsim与iverilog结果相同。
- 可达性：芯片`SPI_SCLK→i_source_clk`（chip:383）、`SPI_SDO`直连pad（chip:337），没有补偿；合同§8.1冻结Mode 0上升沿采样。
- 反驳：两个哑字节只解决CDC延迟，不能修正字节内相位；合同没有允许主机在下降沿前采样。

### 5.2 F-009 NORMAL宏帧5001拍（S1，芯片可达）
- 机理：
  - 末拍`MACRO_LAST_TICK`清`FRAME_ACTIVE`（scheduler:827）；
  - 启动资格要求`!FRAME_ACTIVE`（:436），因此下一帧最早在下一拍才能启动。
  - CAL路径有rollover叠加来"避免空拍"（:854注释），NORMAL没有对应路径。
- 仿真（`f009`，原单元TB加被动monitor）：`frame_start cycle=5006 period=5001`；cycle 5005时`frame_active=0`且`eligible=1`，说明这一拍不是在等外部条件，是结构性空拍。
- 可达性：全层级没有`C_MACRO_FRAME_TICKS`覆盖。连续采样频率约399.92 Hz，每帧相位累积1拍；C08 §4.2和FSC-03要求严格5000拍。
- 同一次运行FSC-14 PASS，即F-011。

### 5.3 F-010 CAL末拍rollover覆盖abort/STOP（S1，芯片可达，影响有界）
- 机理：`flag_calibration_rollover`（:468-473）不含生命周期取消项；后置叠加（:854-873）在主FSM已清`FRAME_ACTIVE`/`CAL_REQ_ACTIVE`之后又把它们置回1。
- 仿真（`f010`，xsim）：
  - 第二个CAL帧tick 4999同拍abort：沿后`frame=2 tick=0 calactive=1 idle=0`，5000拍后才idle，frame_id从1跳到3，无新owner、无新waveform；
  - tick 4998同拍abort的对照：1拍后idle，frame不变；
  - STOP@4999同样多出5000拍（iverilog）。
- 影响：撤销后多保留一个完整CAL帧上下文，排空延迟约2.5 ms，frame_id跳号，多发一次`o_calibration_frame_complete_event`。因为`run_enable=0`会清`CAL_REQ_ACTIVE`，不会出现第二次rollover，所以不构成死锁。
- 可达性：周期重检或启动搜索期间，AMI以电平保持校准请求；主机STOP/abort落在CAL帧第4999拍即可触发，概率约1/5000，但合法可达。

### 5.4 F-018 PVW返回载荷被覆盖（S1，叶子可达）
- 机理：valley accept那一支更新`return_payload_o`（PVW:555-556）时不检查`return_9bit_valid_o`；而timeout/protocol_fallback两支（:420/:423）都有`return_9bit_valid_o==0`门控，三支不对称。
- 仿真（`f018`，复用PVW单元TB的task，xsim）：
  - PVW-30序列后消费valley，return保持ready=0，再送第二组合法峰谷：return frame从10变成21，HOLD_FAIL；
  - 先消费return的对照：新return=21，CTRL_PASS。
- 可达性：PWI中return_ready来自PWC:282（run_enable&&!fault_hold&&ST_FINE&&15BIT&&fine_active），常规fine窗口内立即ready，只有PWC fault_hold时会为0。芯片常规路径不可达，但违反C22 §11.4叶子合同。

### 5.5 F-019 正式结果discard报错身份（S1，control_top可达）
- 机理：
  - discard身份字段取`dec_measurement_*`等NORMAL fork测量分支的输出（AMI:1296/1307/1318/1329/1340/1351）；
  - 正式结果取`reg_result_fork_payload`（:961）；
  - 检测discard（:982）取`result_frame_id_o`，两者不对称。
- 仿真（`f019`，原AMI TB的AMI-46即AMI-DISC-1序列，xsim）：
  - 90/900 RED被反压持住后再送91/901 IR，然后abort：discard报`91/901/IR`，原AMI-46判据FAIL（pass 49/fail 1）；
  - 不加第二笔的对照：AMI-46 PASS（50）。
- 可达性：
  - control_top在OIB合法反压下可达；
  - 芯片原生节拍下P2S不反压（TC7守护），正式结果只pending 1拍，下一笔约80 µs后才到，不可达。与P2S遥测错拍是同一类可达性结论。

### 5.6 F-020 周期重检截止后永不重试（S1，芯片在ADC异常下可达）
- 机理：
  - AMB recheck的`flag_sample_inflight`（amb_recheck:360-372）只在accepted、阶段结束或取消时清除，没有deadline输入；
  - AMI外层inflight在deadline时清除（AMI:1797），但`o_calibration_sample_valid`要求内层inflight==0，所以请求不会重发。
- 仿真（`f020`，原AMI TB在第一次周期AMB请求处插入，xsim）：
  - 握手后inner=1/outer=1；合法deadline事件后outer=0、inner=1；
  - 之后100个安全边界加10个校准帧完成，请求从未重发，busy恒为1，chainidle=physidle=1，fault=0；
  - 再送6笔NORMAL：正式和检测传输均为0（没有细分是入口拒绝还是链路阻塞）。
- 可达性：周期重检CAL帧的owner在tick 248前未提交（ADC idle迟到或SSW不ready）。这与SID-05是同一前提，项目当时已按真实缺陷处理。后果是本RUN内重检永不完成、测量停止，只有STOP或撤RUN能恢复。
- 限制：Top级"SSW拒绝owner"的端到端构造没有重跑。

### 5.7 F-021 共享sample_valid被measurement消费清掉（S1，AMI级）
- 机理：`result_sample_valid_o`只有一个寄存器（AMI:1231-1240），measurement transfer时清零；它同时驱动PWI detection的`i_sample_valid`（:2518）。
- 仿真（`f021`，xsim）：
  - 原AMI TB全程加被动monitor：109次检测握手，"measurement先消费"0次，错配0次，说明原TB从未进入这个窗口；
  - N08背靠背窗口去掉abort：frame 1131装入时资格为1，检测握手时呈现为0。
  - 系统级monitor：periodic_recheck_recovery 2821次握手、long_10_cycles 8002次握手，measurement先消费均为0次，错配均为0。
- 可达性：需要FIR忙时有新事务背靠背到达，control_top原生节拍下未出现。芯片级没有证明可达，但违反C10 §8"分支独立资格"。

### 5.8 F-022 AMI START清除历史sticky（S1，芯片可达）
- AMI:1186把`i_start_ack_event || i_diag_clear_event`并列为清零条件；C10:1153明文"新合法START和STOP本身不得清除该历史诊断"。
- 仿真（`f022`）：AMI-07非法类型使sticky=1、blocking=0；STOP后仍为1；新START后变0，HISTORY_CLEARED_BY_START。

### 5.9 F-023 STOP被同拍命令吞掉（S1，芯片可达）
- manager:313把任意两命令同拍判为冲突，`flag_stop_accept`要求`!conflict`（:461-462）；C02 §3.1和MGR-11要求STOP优先。
- 仿真（`f023`，原manager TB在MGR-04进入RUN后插入，xsim）：
  - 单独STOP：进入STOPPING，ack=1；
  - STOP与COMMIT、START或status-clear同拍：`state=RUN run=1 allow=1 ack=0 error=01`，5拍后仍为RUN。
- 可达性：
  - SPI 0x0090的START(bit0)、STOP(bit1)、diag_clear(bit3)各走一个同构`ppg_pulse_cdc_sync`，Top各打一拍（Top:329/337/375），一次写0x03或0x0A就同拍到达manager；
  - Top的STOP合并还包含supervisor系统STOP请求（:375），与主机命令同拍时同样会被吞。

### 5.10 F-034 PWC discard与提交同拍（S1，叶子可达）
- PWC:264-265的commit条件不含取消；精度寄存器（:318-335）与事件寄存器没有取消优先级。C23:700-710冻结"当前generation的detection discard > 安全提交"，:779-784规定"不得产生精度切换"。
- 仿真（`f034`）：
  - enter_commit与当前代际discard同拍：`mode=1 window=0 start_event=1`，精度、窗口、FSM三者不一致；
  - 对照：`mode=1 window=1`。
- 可达性（静态初判）：
  - PWI的`i_frame_safe_boundary`来自scheduler的组合输出（sched:464），受`flag_lifecycle_active`门控，该门控包含!stop_ack、!abort、!外部故障、!run_enable、!STOP_DRAIN；
  - 因此STOP、abort、离开RUN三种取消源在同拍已被屏蔽；
  - supervisor系统故障discard的时序没有构造，不能断言绝对不可达。

### 5.11 F-035 SSW abort吞掉匹配完成（S1，静态判断芯片可达）
- SSW:514-517中abort保持分支优先于release；owner寄存器只有reset、release、commit三条路径（:511-520），release要求generation匹配（:427），新owner候选要求`!inflight`（:416-418）。
- 仿真（`f035`，原SSW TB task，xsim）：
  - abort与匹配DONE同拍：inflight=1；20拍后、STOP+diag_clear+generation 2新START后仍为1，OWNER_STUCK；
  - DONE早一拍的对照：释放。
- 可达性：Top注册的abort（Top:357）与AMI注册的完成脉冲来源独立，没有互斥机制。后果是复位前无法再建立新owner，测量永久停止。Top级端到端复现没有独立重跑。

### 5.12 新观察 N-1（不在ABCD报告中）
- AMI:1186的`i_diag_clear_event`清sticky时不检查本地活动blocking（`flag_integration_blocking`）。C10:1153要求"在本地无活动blocking cause后"才可清。
- 判定：确认-静态，S3（RTL与合同不一致），没有仿真。建议与F-022一起处理：改RTL加门控，或改合同。

## 6. TB有效性类证据

- F-001（已修复`edec143`）：
  - `f001`在4份TB上加FIR被动monitor，对比d18c695与668a5ea；
  - 修复前：injection有3/5笔、lifecycle有8/10笔FIR输入资格为X（`xfire_cycles=en_cycles`）；owner 0/37；startup未打开注入使能，0/2；
  - 任何FIR输出的`o_detection_qualified`都没有X（这些TB在注入使能期间FIR未积满21点窗口）；
  - 修复后全部为0；PASS 15/80/68/83前后相同。
  - 结论：ABCD说的"污染FIR资格"在FIR输入层成立，但X没有传到输出，也没有任何检查读取它，所以任务C观察到PASS行不变。两份报告的说法并不矛盾。
- 变异确认（`probes/mut/mutrun.py`，xsim，原单元TB原样回归）：

| F | 变异 | 原TB结果 |
|---|---|---|
| F-012 | supervisor:198 `!system_fault_blocking_o`→`!system_fault_cause_valid_o` | 14 PASS，横幅不变 |
| F-013 | CCC软件清零改为自保持 | 26 PASS |
| F-025 | wrapper `o_alpha_q15`恒为0 | 22 PASS |
| F-027 | `ROUND_HALF_Q17` 65536→65534 | PASS，横幅不变 |
| F-031 | `amb_initial_midpoint`截成8位和 | 148 PASS |
| F-036 | PVW `FIR_GROUP_DELAY_LIMIT`→0 | PWI 5 PASS |

- 静态确认（HEAD TB原文）：
  - F-016：PRC-09按周期计"不合格"，没有用FIR valid门控；FIR payload消费后清零（FIR:442），空闲拍天然计入；
  - F-017：只比较差值==0；
  - F-028：每笔只在`wait_q3_release`前采样一次；
  - F-029：只锁存最后一个非零值；
  - F-037：数量不足只加`cnt_run_jnt_fail`，`flag_jnt_baseline_pass`没有外部引用，脚本:90的grep不匹配`JNT_BASELINE ... status=FAIL`；
  - F-038：每次除法向量都reset+START，OPT-24只比较商和周期数；
  - F-040：重叠4拍发生在DONE之前，此时identity_ready需要的`completion_pending`和invalid_ready需要的`dc_result_valid`都必然为0，互斥项根本没有被检验；
  - F-041：只要求pending出现过；
  - F-042：只检查递减和完全重复；
  - F-049：只排除全X。
- F-026：iverilog -Wall报告的悬空输入为router 1、overlap 10、dc_recovery 8、fork 10，名单与C组报告一致。
- F-044（疑似）：Top在RUN中锁存注入使能（Top:393），叶子级去使能在合法RUN里不可达；是否需要叶子级动态证据，属于验收范围的裁定。

## 7. 合同/矩阵/台账类（按origin/main复核）

19条F号在origin/main上逐条重读，问题全部仍然存在（原文行号见§4总表）；K-001已在复核期间修复。
- bb39a0f的行号重映射修正了一部分F-003锚点：alias:58的RTL锚点已从`:292`改为`:294`，内容正确；但同一行的出处`MATRIX.md:872`仍指向无关文字。A报告的643条计数本次没有逐条重做，只抽样确认。
- K-001：到2bb6b17为止，第3408行仍写"`i_start_ack_event` first-priority"，与PWC:508-513（START不清sticky，09-17修复）不符；`6c68094`已原行订正为diag-clear-only（保留删除线旧文），核对后与RTL一致，判已修复。
- F-045：在3f4673d上重算§12.4a的26个摘要，3个匹配、23个不符，与A报告一致。

## 8. 误报清单

无。另有两点说明：
- F-001、K-001已修复，F-044保持疑似，均不算误报；
- 有几条报告自己给的严重度对芯片级影响偏高，已在可达性里限定：F-018、F-034为叶子级；F-019为集成层；F-021为AMI级，系统原生节拍下未触发。

## 9. 报告自列留项的处置建议

| 留项 | 来源 | 建议 |
|---|---|---|
| 4份长系统TB（long_10_cycles、longrun、robustness、baseline_cross等）在Icarus上未跑完 | A§6、C | 不需要补。f485cbc基线已在xsim上跑完全部19份（1208/0）。本次又用HEAD源码在xsim跑了periodic与long_10_cycles（70、129 PASS） |
| 无xsim、无Verilator | A | xsim已由本项目基线覆盖；Verilator lint可另立任务 |
| 5份TB的formatter AST解析失败（CCC、chip、manager、ILM、ISE） | D§最终留项 | 属skill formatter对合法写法（无端口模块头、控制流）的支持局限，不是设计问题。建议另开skill维护任务，不阻塞本项目 |
| F-020 Top级"SSW拒绝owner"端到端构造 | A、B | 第二阶段若修F-020，用control_top级A/B TB补上 |
| F-034 Top级同拍构造 | A、B | 修叶子后加单元断言；Top级可达性按§5.10记录 |
| F-010纯STOP影响量化 | A、B | 已量化：同样多5000拍 |
| 非Source省略文件名引用、bounds-only引用的逐条语义 | A§7 | 并入锚点重建（§10 b类），不单列 |
| G-FP其余cluster的语义签核、CDC/锁存/X态审计重跑 | A、已知 | 维持已知缺口，不在本任务范围 |
| discard翻转位的偶数事件可辨识性 | A检查点补记 | 未确认，保留为候选，本次不展开 |

## 10. 修复方案分组（供用户选择，第二阶段只做批准的项）

**(c) 改RTL（每条都已有A/B证据，合同要求明确）**

| 组 | 条目 | 改法要点 | 影响面 |
|---|---|---|---|
| c1 | F-005（连带F-006） | SPI读移位改为：在每字节第8个上升沿后的下降沿装载，其余下降沿移位；去掉V1.1的+1地址补偿；芯片TB改为真实上升沿采样，并扩展到38字节全读 | 只改SPI文件和芯片TB；芯片回归 |
| c2 | F-009（连带F-011） | 末拍满足条件时直接开始下一NORMAL帧，不经过空拍；FSC-14收紧为5000 | scheduler是系统时基，19-TB的时刻会整体漂移，需要全套回归并逐条解释PASS行或时刻变化；行号重映射 |
| c3 | F-010 | `flag_calibration_rollover`加生命周期取消门控（stop/abort/!run_enable/!STARTED） | scheduler一处；加FSC相邻拍abort断言 |
| c4 | F-020 | AMB recheck的inflight在未建立owner的deadline时释放，需要把deadline从AMI接入PWI/recheck | 跨AMI/PWI/recheck三个文件，端口有增加，需同步合同 |
| c5 | F-022 | AMI sticky清除去掉START项（可连同N-1加blocking门控） | AMI一行；需检查是否有TB依赖START清除 |
| c6 | F-023 | manager:STOP在RUN/STOPPING中优先，同时保留冲突诊断 | manager一处；MGR新断言；芯片0x03/0x0A断言 |
| c7 | F-035 | SSW：匹配完成优先释放owner，abort仍取消波形和结果资格 | SSW一处；SSW断言加Top恢复场景 |

**(d) 需要设计裁定：改RTL，还是像P2S的方案(c)那样写入合同限制**

| 条目 | 选项 |
|---|---|
| F-019 | ①discard身份改取`reg_result_fork_payload`（与检测discard对称，改动小）；②合同写明只在芯片原生节拍下成立 |
| F-021 | ①两个分支各自保存资格位；②合同写明限制 |
| F-018 | ①valley分支加return-pending门控；②合同注明只在fault_hold时可达 |
| F-034 | ①commit加`!flag_lifecycle_cancel`；②合同注明Top父链已屏蔽 |
| F-002/F-008 | 补5个epoch端口，还是把C13/C01/C10/矩阵收窄为实际小组 |
| F-024 | 补正式参数与透传检查，还是合同冻结为产品固定值 |
| F-014 | Supervisor加elaboration参数门禁（Verilog-2001需用generate技巧），还是删去合同该条款 |
| F-030 | CS_N加同步链（会改变协议时序），还是合同改写为异步复位/门控约束 |
| F-032 | RTL改端口名，还是合同改名 |
| N-1 | AMI诊断清除是否加blocking门控 |
| F-044 | P06是否需要叶子级动态证据 |

**(a) 只改TB（不改RTL；每处修复都要做负对照）**
- F-012、F-013、F-016、F-017、F-025、F-026、F-027、F-028、F-029、F-031、F-036、F-037（含run_xsim_regression.sh判据）、F-038、F-040、F-041、F-042、F-049。
- 注意F-006、F-011依赖c1、c2：RTL不修就先改TB，TB会直接FAIL，所以要与RTL同批。

**(b) 只改合同/矩阵/台账文字（B会话已推送，可以开工）**
- F-003（锚点重建，至少按出处列逐条重定位）、F-004、F-007、F-015、F-033、F-039、F-043、F-045（重新生成摘要）、F-046（同号重映射）、F-047、F-048、F-050、F-051；
- 以及(d)中选择"改合同"的项。

## 附录 探针索引

| 目录 | 内容 |
|---|---|
| probes/f005 | `tb_f005.v`（SPI叶子，+PHYS为真实采样），xs_LEGACY/xs_PHYS |
| probes/f009 | `mon_f009.v`（scheduler单元TB被动monitor） |
| probes/f010 | `scen.v`/`tb_f010.v`（+T4998对照，+STOP，+DROP） |
| probes/f018 | `tb_f018.v`（+CTRL为先消费return的对照） |
| probes/f019 | `mk.py`/`tb_f019.v`（+TWO为第二笔事务） |
| probes/f020 | `mk.py`/`tb_f020.v`（+DEADLINE） |
| probes/f021 | `mon_f021.v`、`tb_f021.v`（+NOABORT）、`run_sys.sh`（系统级monitor） |
| probes/f022 | `tb_f022.v` |
| probes/f023 | `tb_f023.v`（+WITH_COMMIT/START/CLEAR） |
| probes/f034 | `tb_f034.v`（+CTRL） |
| probes/f035 | `tb_f035.v`（+CTRL） |
| probes/f001 | `mon_f001.v`、`run4.sh`，base_*/head_* |
| probes/f026 | iverilog -Wall悬空输入统计 |
| probes/mut | `mutrun.py`与6个变异运行目录 |
