被审 origin/main HEAD：`d18c6954621e53e5a6505dd3a6c688c266d23839`

# PPG 数字部分全量审阅报告（进行中）

审阅日期：2026-10-02至2026-10-04（Asia/Shanghai）。独立只读审阅；原克隆未改动。

## 1. 基本信息

本轮分工状态：B、C、D已完成各自主责分组并交稿；A负责独立反驳复核、全局追溯、合并覆盖台账和最终原始日志核对。分组交稿不等于整体报告完成。本轮A续做已实际完成四链机械核对、46家族语义抽查、Top165边界端口/TOP01-24及1860台账端口名称方向检查；人工语义限度和未终结长回归见§5、§6。

- 固定克隆：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\zlcx`
- 字节一致导出副本：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\snapshot`
- 导出使用 git -c core.autocrlf=false archive；范围内逐文件与 git show 比较相等。
- 工具环境与实际编译/仿真/变异日志保存在 evidence/；已产生结果按每份run.log记录。


| 实际工具 | 版本/状态 | 实际用途与限制 |
|---|---|---|
| Git | 2.54.0.windows.1 | clone/固定origin/main/core.autocrlf=false archive/只读状态检查 |
| bundled Python | 3.12.14 | 仓库skill门禁/lint、检查脚本、证据与台账；实际使用版本 |
| 系统Python | 3.8.5 | 仅环境检测，未用作主验证运行时 |
| Icarus / vvp | 11.0 stable，Debian官方包独立解包 | 48 TB -g2012 -Wall编译、37 RTL -g2005 -Wall编译、实际vvp/A-B/变异；未获得建议12版 |
| Git Bash | 5.3.9 | 入库shell入口与依赖静态核对 |
| WSL Debian | 11.6 x86_64 | 独立Icarus运行环境；不安装系统包 |
| Vivado 2022.2 xsim | 未找到 | 未运行三个原生xsim入口，不能声称复现xsim.log或综合/ASIC CDC签核 |
| Verilator | 未找到 | 未做verilator --lint-only |

仓库erie-verilog-generator按SKILL.md手动执行；本轮运行strict deliverable gate和verilog_lint external=none，另已实际运行analyze-existing --no-state并核对Top八门禁输出；没有verify/repair、源代码生成、写回格式化修改或自动修复。静态门禁和Icarus编译不等同实际综合；没有执行独立ASIC时序/CDC签核或全周期X审计。脚本自身的负对照不构成芯片功能正确性的证明。

## 2. 结论摘要

所列人工审阅与交叉核对已补充完成，完整原回归终态尚未齐；未能独立验证的范围明确列于§5/§7。已确认50条：**S1=11、S2=20、S3=19、S4=0**；按主层：RTL=11、TB=20、合同=15、矩阵·台账=3、跨层=1；另有1条疑似，不计确认数。优先关注F-035完成/abort同拍导致重新START受阻、F-023真实SPI STOP被吞、F-005真实Mode0读流错位、F-020周期重检重试锁住及F-019错误discard身份。S2中F-006/F-011掩盖已有真实S1，其他变异逃逸范围见各条；叶子反压/同拍组合与完整芯片触发严格区分。未审、工具未完成和仅编译通过均不能理解为功能通过。

| 编号 | 严重度 | 主层 | 结论 |
|---|---|---|---|
| F-005 | S1 | RTL | SPI读回在真实Mode 0上升沿已提前移位，读字节错一bit |
| F-009 | S1 | RTL | 连续 NORMAL 宏帧多一个边界空拍，默认周期为 5001 拍 |
| F-010 | S1 | RTL | CAL 末拍 rollover 覆盖同拍 abort，重新建立已撤销的逻辑帧 |
| F-018 | S1 | RTL | PVW 返回请求反压期间被第二次合法谷值覆盖 frame_id |
| F-019 | S1 | RTL | AMI 正式结果 discard 报告了已推进上游的另一笔身份 |
| F-020 | S1 | RTL | 周期 AMB 截止只清 AMI 外层 inflight，内层锁住后续 RUN 重试 |
| F-021 | S1 | RTL | measurement 先消费清共享 sample-valid，仍 pending 的 detection 资格变零 |
| F-022 | S1 | RTL | AMI 新合法 START 清除了软件尚未清除的历史 protocol sticky |
| F-023 | S1 | RTL | STOP 与竞争命令同拍被 manager 吞掉，真实 SPI 仍保持 RUN |
| F-034 | S1 | RTL | PWC 当前代际 discard 与安全提交同拍仍改变精度并发事件 |
| F-035 | S1 | RTL | SSW abort 同拍吞掉匹配完成，残留 owner 阻断重新 START |
| F-001 | S2 | TB | 启用注入的4份系统TB使calibration-loss valid悬空，污染正式FIR资格 |
| F-006 | S2 | TB | 芯片TB在下降沿更新前采样SDO，掩盖F-005 |
| F-011 | S2 | TB | FSC 周期检查允许 5001 拍，漏过 F-009 |
| F-012 | S2 | TB | SUP10A 清空历史后才重开 episode，不能证明未清快照时重新触发 trio |
| F-013 | S2 | TB | CCC-22 未比较软件清除后 sticky=0，删除清除逻辑仍可通过 |
| F-016 | S2 | TB | PRC-09 把 FIR 空闲周期当作未合格窗口，未发生资格丢失也能满足恢复判据 |
| F-017 | S2 | TB | PRC-10 所称顺序比较只检测相邻重复，倒序或跳号不能触发 |
| F-025 | S2 | TB | ACTIVE wrapper 的字段透传检查漏 alpha，固定错误输出仍 22 PASS |
| F-026 | S2 | TB | 四份 ADC/fork 模块 TB 漏接 29 个现有输入 |
| F-027 | S2 | TB | PR-06 正负半值标签未构造门限，舍入门限变异逃过完整原 TB |
| F-028 | S2 | TB | ILM-04/05 LED 禁止驱动检查跳过真实转换窗口 |
| F-029 | S2 | TB | ISE 选中总线的最后非零值比较漏掉中间一拍错误 |
| F-031 | S2 | TB | IDAC 单元 TB 的低码搜索未检出九位求和截断 |
| F-036 | S2 | TB | PWI 尾部测试丢弃累计前置判据，第一笔提前报错仍 PASS |
| F-037 | S2 | TB | JNT 数量不足不增加统一错误数，官方统计也漏 status=FAIL |
| F-038 | S2 | TB | OPT-23/24 没有构造连续周期和随机正式最终结果差分 |
| F-040 | S2 | TB | INJ-04 在两类注入均未就绪的窗口检查互斥，删门控仍 PASS |
| F-041 | S2 | TB | RRC-01 只打印首次 pending 帧数，没有比较配置间隔 |
| F-042 | S2 | TB | OIB-06 的排序和重复判据不能证明无丢失及三类元数据错标 |
| F-049 | S2 | TB | INJ-03 把“不是全 X”当成无效样本身份保持正确 |
| F-002 | S3 | 合同 | C13完整discard身份端口声明比RTL多出五个epoch输入 |
| F-003 | S3 | 矩阵·台账 | 矩阵/别名表存在可直接证实的失效行号锚点 |
| F-004 | S3 | 合同 | C13给纯组合Router声明了不存在的注册式local-empty |
| F-007 | S3 | 合同 | 芯片合同正文仍要求两路reset_sync，与自身V1.11勘误及RTL冲突 |
| F-008 | S3 | 合同 | 正式 measurement-discard 身份在 C01/C10 要求完整 TXN_ID，实际 AMI/Top 缺五个 epoch 端口 |
| F-014 | S3 | 合同 | Supervisor 接受合同明令 elaboration 拒绝的过窄 watchdog 计数器 |
| F-015 | S3 | 合同 | FIR 合同仍称 sample-valid 定向 TB 不存在 |
| F-024 | S3 | 合同 | manager、ACTIVE wrapper、unpack 缺当前合同要求的正式参数及透传 |
| F-030 | S3 | 合同 | SPI CS_N 两级同步规范与实际原始片选异步复位不一致 |
| F-032 | S3 | 合同 | IDAC 冻结诊断清除端口名与实际叶子接口不一致 |
| F-033 | S3 | 合同 | IDAC 合同禁止不改 AMB 码时重验，与冻结依赖及实际三阶段相反 |
| F-039 | S3 | 合同 | 表征控制合同复位后的 START 前提与自身模式例外矛盾 |
| F-043 | S3 | 合同 | C18 窗口长度配置的直接消费者写成了 PWC |
| F-045 | S3 | 矩阵·台账 | 矩阵现行26文件完整性摘要有23项与固定版本字节不符 |
| F-046 | S3 | 跨层 | 合同与TB的同号验收场景存在语义错位 |
| F-047 | S3 | 合同 | SSW最新修订与唯一规范版本声明的承接关系不明确 |
| F-048 | S3 | 合同 | Top 诊断清除的排他消费者名单漏掉表征 CDC |
| F-050 | S3 | 矩阵·台账 | 别名表仍把现有 SID-11 注入场景列为结构不可达的 SKIP |
| F-051 | S3 | 合同 | Supervisor规范复位端口名与真实模块接口不一致 |
| F-044 | S2（疑似） | TB | 疑似——P06 动态闭合是否需要叶子去使能，范围尚待裁定 |

统计每条发现一次；跨层证据不重复计数。其他组新候选在A独立复核前不计入。

## 3. 新发现


### F-005：SPI读回在真实Mode 0上升沿已提前移位，读字节错一bit

- **严重度/层**：**S1 / RTL**（芯片配置回读及诊断输出错误）。
- **位置及原文（3行，尾随说明省略）**：
  - `rtl/ppg_spi_register_file/ppg_spi_register_file.v:301`：`assign flag_load_read_byte = (flag_byte_boundary && (state_current == ST_DUMMY) && (cnt_field_byte == 1'b1)) || (flag_byte_boundary && (state_current == ST_DATA) && flag_cmd_is_read);`
  - 同文件`:476`：`cnt_bit_in_byte <= cnt_bit_in_byte + 3'd1;`
  - 同文件`:464`：`reg_read_byte <= {reg_read_byte[6:0], 1'b0};`
- **描述/依据**：芯片合同`PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md:124-125`冻结Mode 0、上升沿采样、MSB-first。计数器在posedge更新，negedge的load/shift却直接消费更新后的计数和状态。哑字节倒数第二个posedge后计数变7，紧接negedge已装入首个数据；哑字节最后posedge后计数归0且状态进入DATA，紧接negedge先把首个数据左移。真实第一个数据posedge采到的是bit6，bit7已经丢失；后续字节边界同样提前装入下一字节，形成整条读流的一bit错位。
- **仿真证据**（Icarus11，clk=2MHz，SPI约3.984MHz、2哑字节；所有输入明确驱动）：

```text
physical compile 0 run 1
SPI_MAP_FAIL addr=00000100 got=1c expected=0e
legacy compile 0 run 0
SPI_MAP_PROBE_PASS diagnostic_bytes=38 shadow_bytes=128 atomic_freeze=1 refresh=1 reserved=1 multi_command=1
hypothesis compile 0 run 0
SPI_MAP_PROBE_PASS diagnostic_bytes=38 shadow_bytes=128 atomic_freeze=1 refresh=1 reserved=1 multi_command=1
hypothesis_negative compile 0 run 1
SPI_MAP_FAIL addr=00000100 got=0e expected=0f
```

  Physical在真正posedge后1ns采样，negedge后留1ns完成更新；legacy采用原TB的同时间槽采样。hypothesis仅在仓库外leaf副本调整字节边界相位，恢复真实posedge采样；它是反驳用的假设对照，**不是交付修复，也未改入库RTL**。negative把正确预期0e改成0f后确实FAIL。代码与日志：`evidence/spi_map_probe/`。
  芯片级进一步只改仓库外TB的SDO采样时刻、保持入库RTL与SPI半周期125ns不变，复现：

```text
CHIP_PHYSICAL compile 0 run 0
FAIL TC1 ACTIVE shadow echo mismatch
FAIL TC1 COMMIT后生命周期非READY：got=10
FAIL TC1 START后生命周期非RUN：got=00
TB_CHIP_DIGITAL_TOP_FAIL cnt_error=3
```

  `evidence/chip_spi_ab/run.log`；这不是修改期望值导致的失败，修改仅为把采样移到真实上升沿后1ns。
- **上报前反驳**：芯片Top:383把SPI_SCLK直接送i_source_clk，:387把SDO直接接pad网，没有相位反转或下一层重定时补偿；额外哑字节不能修正每个字节内部的提前移位。38地址静态位段与合同对得上，只是串行时序错；不是已知“只查3个读字节”的覆盖数量问题、09-14快照撕裂问题、P2S反压问题或style积压。合同不允许主机在negedge前一个delta时间采样代替Mode 0上升沿。原TB PASS之所以不能反驳见F-006。
- **置信度**：**仿真确认**（leaf A/B与真实芯片层均复现）；未使用Vivado确认跨仿真器调度差异，真实硬件Mode 0采样结论由稳定边沿与代码相位共同支撑。
- **建议方向**：重新对齐posedge字节计数与negedge装载/移位条件，先用无竞争上升沿主机核对首字节及全部突发字节；具体修改由设计者裁定。

### F-009：连续 NORMAL 宏帧多一个边界空拍，默认周期为 5001 拍

- 严重度/层：S1 / RTL。置信度：仿真确认（叶子默认行为）；Top直连静态确认。
- 位置：`contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md:142`；`rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:825`.

```text
宏帧计数范围为`0..4999`，在`4999 -> 0`时进入下一宏帧。
state_next[B_FRAME_ACTIVE] = 1'b0; // 当前宏帧结束
```

- 描述与依据：C08 §4.2:137-142要求5000拍/400 Hz。RTL:752-790只能在沿前 FRAME_ACTIVE=0 时启动，而:812-838在末拍先清 FRAME_ACTIVE，产生额外启动拍。连续 eligible、各 ready/idle 为真时仍然有误差；Top:862-868没有覆盖默认计数长度或周期补偿。
- 证据：

```text
B_NORMAL_PERIOD cycle=5007 period=5001 frame=1
B_NORMAL_PERIOD cycle=10008 period=5001 frame=2
B_NORMAL_PERIOD cycle=15009 period=5001 frame=3
```

- 反驳与范围：原RTL严格5000比较3次FAIL，运行退出1；仓库外仅把长度参数改4999的定位对照为5000/5000/5000，3次PASS、退出0。这不是建议的有效修复。排除了消费者等待；CAL旁路仅适用于校准，不能补偿NORMAL；非已知tick-248问题。默认理想连续采样约399.920016 Hz。
- 原始证据：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\scheduler_cadence`；`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\scheduler_cadence_counterfactual`。
- 建议方向：裁定连续NORMAL帧的边界进入方式，并补严格5000拍比较。

### F-010：CAL 末拍 rollover 覆盖同拍 abort，重新建立已撤销的逻辑帧

- 严重度/层：S1 / RTL。置信度：仿真确认（叶子取消边界）；系统影响范围仍有限。
- 位置：`rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:602`；`rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:855`；`rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:857`.

```text
state_next[B_FRAME_ACTIVE] = 1'b0; // abort立即撤销未完成宏帧上下文，与SSW侧i_control_abort_event立即失效旧波形同拍
if(flag_calibration_rollover)begin
state_rollover_next[B_FRAME_ACTIVE] = 1'b1; // 不经过IDLE直接进入下一校准子帧
```

- 描述与依据：主FSM:597-619撤销abort上下文；但:468-473仅看旧CAL状态/末拍/pending，不排除abort。后置组合overlay:853-872把FRAME_ACTIVE、CAL模式及请求身份重新置位，最终:880采纳overlay。C08 §16.4:1090要求撤销未握手上下文并禁止未来启动；Top:877实际接owner-abort。
- 证据：

```text
B_ABORT_BEFORE tick=4999 active=1 inflight=0 pending=1 rollover=1
B_ABORT_AFTER tick=0 active=1 inflight=0 ownercommit=0 idle=0
FAIL FSC-101 cycle=5005 tick=0
```

- 反驳与范围：同一刺激提前一拍时active=0、idle=1且PASS；末拍FAIL、退出1。请求来自正常valid输入，不使用force，abort在negedge驱动、下一posedge+1观察。其它STARTED/生命周期门控仍阻止新owner，未观察到重新提交ADC owner，因此不宣称永久死锁；本项指逻辑CAL上下文复活与idle推迟。纯STOP的影响仍待量化。非已知SID-05 deadline问题。
- 原始证据：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\scheduler_abort_tick4998`；`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\scheduler_abort_tick4999`。
- 建议方向：让rollover服从取消优先级，补相邻拍abort对照。

### F-018：PVW 返回请求反压期间被第二次合法谷值覆盖 frame_id

- 严重度/层：S1 / RTL。置信度：仿真确认叶子接口错误；未声称常规Top路径必现。关联C-004；原专项把RTL握手错误归S2，按本任务S1定义统一。
- 位置：`rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v:438,555,556`，原文3行：
```text
assign o_result_ready = i_rstn && i_run_enable && (i_recheck_busy == 1'b0) && (peak_valid_o == 1'b0) && (valley_valid_o == 1'b0);
end else if(flag_valley_accept_event == 1'b1 && fine_window_active_o == 1'b1)begin
return_payload_o <= {RETURN_REASON_VALLEY, i_frame_id};
```
- 描述/依据：C22合同§11.3:520-521允许valley与return独立握手，§11.4:538要求return原因/frame在反压期间保持。消费valley但保持return ready=0后，输入ready重新开放；同epoch、连续合法15-bit峰谷可再次确认，555-556无pending保护，覆盖仍valid的旧返回frame。
- A/B证据：A独立执行C组公开输入准备件并核对所有激励、精度/epoch、真实握手及无协议故障前提。`evidence/peak_hold_actual/native.run.log`：`held return changed: expected frame=10 actual=21`，编译0运行1；先真实消费旧return再送相同第二峰谷的`peak_hold_consumed_control`打印`C_RETURN_HOLD_PASS`，编译0运行0；错误初始期望11的负对照在第一请求建立时fatal，运行1。全部依赖只有实际PVW和仓库外TB，输入hash/命令保存在对应native.result.json。
- 反驳：PWI实际绑定PWC的ready（PWC:280在正常ST_FINE立即为1）限制常规系统触发，不能解除叶子合同的独立反压义务。原PVW-30:851-859未消费valley、未继续送输入，不能推翻反例。非TRK-01原子不可测试、discard豁免、已知PWC修复或PRC-04。
- 建议方向：在旧返回请求消费前保护其载荷/所有权，并加入valley先消费、return反压的公开输入对照。

### F-019：AMI 正式结果 discard 报告了已推进上游的另一笔身份

- 严重度/层：S1 / RTL。置信度：真实链仿真确认；关联B-006。
- 位置：`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1296,1307,1318`，原文3行：
```text
measurement_result_discard_frame_id_o <= dec_measurement_frame_id;
measurement_result_discard_sample_index_o <= dec_measurement_sample_index;
measurement_result_discard_color_ir_o <= flag_measurement_color_ir;
```
- 描述/依据：C10:616-620、661-673要求measurement discard携带该分支保留事务。正式待消费输出来自1742-1749的`reg_result_fork_payload`，但discard六字段取自NORMAL fork的上游`dec_measurement_*`（2022-2041），该上游可先到下一笔。
- 证据：B组仓库外`discard_identity_one`单笔真实ADC/S1/DC链3 PASS；相同启动与链路的`discard_identity_two`保持正式RED 90/900，再接收IR 91/901。原始日志：`B_PRE_DISCARD resultframe=90 resultsample=900 upstreamframe=91 upstreamsample=901`；abort后`B_POST_DISCARD event=1 frame=91 sample=901 color=1`，`FAIL BIDISC`，编译0运行1。A已读实际公开刺激、完整身份来源和原始日志/命令。Top:1190-1192/1576-1578直通错误身份。
- 反驳：没有force，注入参数默认关闭；正常正式结果仍90/900，排除只是期望把trigger当保留事务的误解。合同明确每分支身份，不允许任意上游trigger。本条为真实可见错身份，区别F-002/F-008五epoch文档缺口；C11/C14/C15条件豁免不能覆盖公开measurement-discard。没有据此声称永久排空失败。
- 建议方向：discard取当前正式measurement保留载荷的身份，增加两笔背压后取消的比较。

### F-020：周期 AMB 截止只清 AMI 外层 inflight，内层锁住后续 RUN 重试

- 严重度/层：S1 / RTL·跨层。置信度：AMI及全部实际子模块仿真确认；全Top拒绝owner的专项尚待补。关联B-007。
- 位置：AMI `rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1798` 与 `rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v:368`，原文2行：
```text
flag_calibration_request_inflight <= 1'b0;
flag_sample_inflight <= 1'b1;
```
- 描述/依据：C10:486/996规定未取得owner的截止不会有结果返回，应重新发同一候选。AMI:929把中间缓存ready经PWI:1015送给AMB；AMB:195/360-369在缓存握手时先置本地inflight，208据此禁止valid。截止1797-1798仅清外层；没有deadline送到AMB，内层只在实际结果accepted、阶段结束或生命周期取消时清，未建立owner则没有结果可解锁。
- 证据：B `recheck_deadline_v4`经真实启动、FIR/cross/精度返回到periodic reason01，公开请求握手后outer=1/inner=1/adc=0；合法deadline及100次安全边界后，`B_POST_DEADLINE outer=0 inner=1 adc=0 req=0 busy=1 physidle=1 chainidle=1 fault=0 ownerdelta=0`，`FAIL BRETRY`、`PASS BCLEAR`，编译0运行1。正常真实三阶段结果链`recheck_control`30 PASS；只删除内层valid的inflight门控之仓库外因果对照31 PASS，req恢复；不是候选修复。A已核对实际代码、公开刺激、两层握手、原始日志和命令。
- 反驳：RUN撤销后确实恢复，故不称复位后永久死锁；物理/数据链idle且ownerdelta=0排除等待合法ADC返回。Top把Scheduler deadline直送AMI，没有内层补偿；外层SID-05修复只能帮助startup单层源，不能替periodic内层清理。与已知tick248同拍commit不同，此复现完全无owner commit。全Top在SSW拒绝或候选来晚时的实际截止触发仍待补，不能称已端到端复现。
- 建议方向：未建立owner的截止释放要贯穿周期重检所有权，并保留重复请求保护。

### F-021：measurement 先消费清共享 sample-valid，仍 pending 的 detection 资格变零

- 严重度/层：S1 / RTL。置信度：真实链仿真及因果对照确认；关联B-008。
- 位置：`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1238,1239,2518`，原文3行：
```text
end else if(flag_measurement_transfer == 1'b1)begin
result_sample_valid_o <= 1'b0;
.i_sample_valid(result_sample_valid_o),
```
- 描述/依据：C10:691-694、941-946明确两分支分别保存资格，任一消费不能修改另一pending分支。现有唯一资格寄存器同时驱动measurement:1028与PWI detection:2518；measurement完成时清零，detection仍pending也看见0，稍后会作为invalid样本被消耗。
- 证据：B `branch_qualification_v2`保留原AMI TB至N08的真实链及FIR忙窗口，原47比较通过后：`B_BRANCH_DIAG window=1 firbusy=1 detpending=1 measpending=0 samplequal=0 frame=1131 expected=1131`；`PASS BWINDO`、`FAIL BQUALI`，编译0运行1。同激励仅在仓库外让measurement清零还要求detection不pending，samplequal=1且49比较/0失败。A读实际变异单行、公开激励、原日志及代码来源；第一版观察早一拍的失败属于setup，未采用。
- 反驳：没有force、注入关闭、payload仍保持，排除F-001悬空注入及P2S三个遥测错拍已知项。消费measurement期间detection ready低为原N08已有合法背压；不能用一条branch的原子数值载荷代替另一条独立资格。常规400 Hz每帧是否一定命中该窗口未证明，不扩大为所有默认帧丢失。
- 建议方向：分支独立保存资格，并比较measurement先消费及detection先消费两种次序。

### F-022：AMI 新合法 START 清除了软件尚未清除的历史 protocol sticky

- 严重度/层：S1 / RTL。置信度：仿真确认；关联B-009。
- 位置：`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1186-1187`，原文2行：
```text
end else if(i_start_ack_event == 1'b1 || i_diag_clear_event == 1'b1)begin
integration_protocol_error_sticky_o <= 1'b0;
```
- 描述/依据：C10 §15.1:1153只允许reset，或本地无活动blocking cause时的diag_clear清历史；START/STOP明确不得清。实际把START与diag_clear并列清零。
- 证据：B `ami_sticky_start`通过MANUAL真实启动建立上下文，非法保留frame11置sticky；`PASS BSTICK`证明sticky=1、blocking=0、无ADC inflight，STOP/撤RUN/drain后`PASS BDRAIN`证明empty及历史仍1。新generation2合法START后`B_STICKY_AFTER_START sticky=0 blocking=0 inflight=0`，`FAIL BKEEPH`；显式diag_clear的`PASS BDIAGC`对照通过。编译0运行1，3 PASS/1 FAIL。A核对实际刺激、合同、清零代码和原始日志。
- 反驳：新START前已排空，没有保留旧owner或故障blocking阻止START；Top允许从正常排空后的新RUN清上下文，未自动发diag_clear。用户已知09-17 PWC保留sticky修复是另一个模块，不能豁免AMI同名历史状态。
- 建议方向：START仅重建RUN上下文，历史sticky保留至其明文清除条件；加跨RUN比较。

### F-023：STOP 与竞争命令同拍被 manager 吞掉，真实 SPI 仍保持 RUN

- 严重度/层：S1 / RTL。置信度：叶子及真实SPI pad仿真确认；关联D-003。
- 位置：`rtl/ppg_system_config_manager/ppg_system_config_manager.v:313,461,462`，原文3行：
```text
(i_stop_event && i_status_clear_event);
i_stop_event && (flag_command_conflict == 1'b0) &&
((state_current == ST_RUN) || (state_current == ST_STOPPING));
```
- 描述/依据：C02当前V4.9:65、228-236及MGR-11要求Top-merged STOP抢占START/COMMIT/status-clear，保留冲突诊断。实际任意冲突把stop_accept也清零，RUN许可继续为1，没有排空episode。
- 证据：D仓库外manager真实COMMIT/START进入RUN。单STOP日志`state=11 run=0 allow=0 ack=1 episode=1`、PASS；分别同START/COMMIT/clear则`state=10 run=1 allow=1 ack=0 episode=0 error=1 code=01`，各fatal、编译0运行1。真实chip SPI写0x0090命令：0x02对照`state=00 stop_hits=1 collisions=0 code=00` PASS；0x06(STOP+COMMIT)出现`D_CHIP_STOP_COMMIT_COLLISION`后`state=10 stop_hits=0 collisions=1 code=01`、`D_CHIP_STOP_FAIL`，编译0运行1。A已读公开pad刺激、actual commands/日志、RTL优先条件。
- 反驳：wrapper:397-399直通，Top:375/737-739只注册合并STOP、不屏蔽竞争命令；SPI命令位允许同时设置，真实pad对照消除了仅叶子非可达假设。没有其他机制补发丢STOP；fault blocking只拒START不自动退出RUN。原MGR TB在READY测试旧全拒绝不能反驳RUN丢终止请求。无已知事项豁免，当前规范明确STOP优先；不采用旧互斥说明盖过当前规范。
- 建议方向：保持冲突诊断同时落实STOP优先，补RUN/STOPPING的同拍命令矩阵。

### F-034：PWC 当前代际 discard 与安全提交同拍仍改变精度并发事件

- 严重度/层：S1 / RTL；置信度：A独立最小仿真及限定反驳对照确认。关联B-010。
- 位置：`rtl/ppg_precision_window_controller/ppg_precision_window_controller.v:264,265`及C23:705，原文3行：
```text
assign flag_enter_commit = (state_current == ST_WAIT_ENTER) && i_frame_safe_boundary && i_precision_takeover_safe && i_analog_safe && (i_recheck_busy == 1'b0);
assign flag_return_commit = (state_current == ST_WAIT_RETURN) && i_frame_safe_boundary && i_precision_takeover_safe && i_analog_safe;
> 当前generation的detection discard
```
- 描述/依据：两个commit条件未排除flag_lifecycle_cancel；FSM:602优先回IDLE、窗口:340优先清0，但精度:327-330及事件:355-397仍提交，违反C23:703-710 discard高于提交和:779-784的禁止事件规则。
- 证据：A复用已核实公开cross/return激励重跑：STOP/abort/fault三种当前generation discard分别与合法安全边界同拍，enter均`mode=1 window=0 start=1 state=0`，return均`mode=0 window=0 return=1 state=0`；6功能比较FAIL、8setup/旧generation/正常返回PASS，运行1。外部只在两个commit条件加!flag_lifecycle_cancel，同一14比较PASS、运行0，记录evidence/A_pwc_cancel_commit*。
- 反驳：取消FSM不抑制不同always中的commit事件；AMI:962复合safe/970检测discard与:2539/2541传入PWI并未定义二者互斥。真实父链同步同拍仍待完整Top构造，故不称必然新ADC启动或永久死锁。叶子合同明文允许并冻结同拍优先级；已知09-17 PWC修复是START历史sticky，不豁免此项。
- 建议方向：精度、事件和FSM使用一致的取消优先级，并补双向同拍公开输入检查。

### F-035：SSW abort 同拍吞掉匹配完成，残留 owner 阻断重新 START

- 严重度/层：S1 / RTL；置信度：A独立叶子仿真、已核实真实Top ADC路径及限定对照确认。关联B-012。
- 位置：`rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v:514-516`，原文3行：
```text
end else if(i_control_abort_event == 1'b1)begin
adc_owner_inflight_o <= adc_owner_inflight_o;
end else if(flag_owner_release == 1'b1)begin
```
- 描述/依据：427的flag_owner_release已识别正确sample_index/generation，无ready完成只有一拍，abort保持优先于释放。C09:346-354、678-689冻结匹配完成success0/1都释放owner，取消阻止新模拟/结果处理却不允许丢失释放事实。
- 证据：A叶子独立运行SAR9/SAR15×success0/1，完成前release=1，沿后`recognized=1 inflight=1 idle=0 waveidle=1 physicalidle=1`，20拍后仍占用，8比较FAIL。迟一拍匹配完成、错ID后正确完成两对照PASS；只删除外部副本abort保持两行，同6case全PASS。
- 顶层证据：B top_abort_done_v3使用真实合法MANUAL双光、Q3、CLK_DOUT/RAW，注入参数0、无force。Top:353-357注册abort与AMI:1199-1202注册完成实见同拍`abort=1 completion=1 release=1`。后`SSWowner=1 schedulerowner=0 AMIowner=0`；3拍回CONFIG，physicalidle1/AMIempty1，但SSWidle0；100拍、diag-clear、合法重新COMMIT/START均不清。新RUN7000拍`newowners=0 blocking=1 cause=21`。仅上述两行外部对照，新RUN5拍`newowners=1 lifecycle=2 blocking=0 cause=00`并PASS。A已读公开激励/寄存器实际路径、全部命令与原始日志，索引evidence/merged_findings_oct4e_refs.json。
- 反驳：首次生命周期能够回CONFIG，不误报STOPPING死锁；Top:741-744排空资格确实不含完整SSW idle。owner寄存器仅reset/release/commit改变，START、diag-clear、physicalidle均无清除，generation改变也不能补释放旧owner；正常接口没有补发已消费DONE机制。LFA-04先abort后DONE及旧SSW迟到测试不覆盖同拍。不是冻结D03 cause22或tick-248。
- 建议方向：匹配完成优先释放真实owner，同时取消继续清模拟/结果资格；补完成/abort同拍及跨START恢复检查。

### F-001 — 启用注入的4份系统TB使calibration-loss valid悬空，污染正式FIR资格

| 字段 | 内容 |
|---|---|
| 严重度 / 层 | **S2 / TB（跨层消费链已核实）** |
| 位置 | `rtl/ppg_control_top/tb_ppg_control_top_injection.v:234`；`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v:264`；`tb_ppg_control_top_owner_identity_backpressure.v:262`；`tb_ppg_control_top_startup_idac_calibration.v:253`（后3份同目录）；DUT消费：`rtl/ppg_coarse_detection_fir/ppg_coarse_detection_fir.v:313-315` |
| 描述 | 四份TB显式覆盖C_ENABLE_TEST_INJECTION=1，却未连接i_test_calibration_loss_inject_valid。Icarus逐份报告dangling input port 26。运行时enable被实际置1后，Z沿Top→AMI→PWI直通到FIR，并使正常合格样本的flag_sample_qualified为X。21个合格NORMAL点可以仍得到result_valid=1，但o_detection_qualified=X。这削弱这些验证构建中的正式检测资格证据；不能由既有PASS横幅证明其无影响。本项不声称生产RTL有此错误，生产默认0的负分支已独立证明屏蔽Z。 |
| 合同依据 | C01 `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md:271`定义该保持型请求；`:293-301`定义编译期/运行时门控与非活动约束；FIR注入接口和C19正式资格规则。不存在把未驱动Z当作合法请求0的条款。 |
| 证据 | `evidence/compile/<四份TB>/compile.log`的真实悬空端口警告；`evidence/fir_floating_ab/audit_fir_ab.run.log`三路同激励；Top透传`:1372`、AMI`:2615`、PWI`:651`。|
| 置信度 | **仿真确认**：已确认叶子资格X与编译期关闭屏蔽；四份完整系统TB受影响的场景范围仍待监测，不把叶子A/B扩大为四份全部验收失效。 |
| 建议方向 | 把未使用的calibration-loss valid显式接0，重跑四份TB并增加正式资格无X检查；仅建议，不实施。 |

原文（合计3行，直接按固定提交重新读取）：

```verilog
.C_ENABLE_TEST_INJECTION(1) // 本文件的核心覆盖：打开验证专用异常注入结构生成
assign flag_test_calibration_loss_inject_fire = (C_ENABLE_TEST_INJECTION != 32'd0) && i_test_inject_enable && i_test_calibration_loss_inject_valid && o_test_calibration_loss_inject_ready;
assign flag_sample_qualified = i_sample_valid && (i_coarse_recovery_calibrated && !flag_test_calibration_loss_active) && (i_stage1_saturation_low == 1'b0) && (i_stage1_saturation_high == 1'b0) && (i_coarse_saturation_low == 1'b0) && (i_coarse_saturation_high == 1'b0);
```

后两行省略尾随中文注释，代码正文与RTL:313、315逐字相同。

最小TB实际输出（不从历史报告抄录）：

```text
audit_fir_ab compile 0 run 0
INPUT qualified A(open,enabled)=x B(tie0,enabled)=1 C(open,disabled)=1
OUTPUT valid A=1 B=1 C=1 qualified A=x B=1 C=1 guard=33
AUDIT_AB_CONFIRMED
audit_fir_ab_negative compile 0 run 1
FATAL: audit_fir_ab_negative.v:160: AUDIT_AB_FAIL
Time: 356000 Scope: audit_fir_ab
```

上报前反驳：

- (a) 核实三层透传后，保护只在编译期参数0或运行时enable0时生效；FIR接口无Z→0净化。运行时enable置1位置分别为injection:732、lifecycle:1067、owner_identity:1715、startup:932/1006。独立C路参数0且悬空确实输出资格1。
- (b) 该悬空在基线§6.6和TB维护§7中已被记录；**不属于用户第4节免报条目**。本轮补充的是正式资格X的直接A/B证据，保留历史来源，避免把它说成首次发现。
- (c) C01/C19没有允许未驱动的有效请求；普通生产构建保持0的豁免不适用于这四份参数1的TB。

变异负对照仅把B路期望资格1改成0，编译仍0而运行返回1并触发AUDIT_AB_FAIL，证明比较能失败。



### F-006：芯片TB在下降沿更新前采样SDO，掩盖F-005

- **严重度/层**：**S2 / TB**。
- **位置及原文（3行）**：`rtl/ppg_chip_digital_top/tb_ppg_chip_digital_top.v:212-214`：

```verilog
rx_byte[i] = SPI_SDO;
#(SPI_HALF_PERIOD) SPI_SCLK = 1'b1;
#(SPI_HALF_PERIOD) SPI_SCLK = 1'b0;
```

- **描述/依据**：任务末尾下降沿阻塞赋值SCLK后，不等待DUT的NBA更新就进入下一bit/下一byte，立刻读取旧SDO。该值在随后的真实上升沿前已改变，因而不代表合同Mode 0主机采样的比特。其检查有真实比较，但其时间参照点使错误读流被判为正确。
- **证据**：原芯片TB直接run.log有6条PASS、正确横幅；仅把读动作放到真实posedge后1ns（半周期仍125ns）就得到F-005列出的3个FAIL及`TB_CHIP_DIGITAL_TOP_FAIL cnt_error=3`。独立38字节leaf probe的legacy采样通过、physical采样失败，仓库外边界变异控制通过，改错预期的负对照失败。原TB并不是无条件打印PASS。
- **上报前反驳**：SPI收发任务被全部`spi_txn`读路径复用，没有另一组在真实posedge采样的回读比较；P2S字段/内部生命周期监视不会替代pad上的SPI数据比较。生产接口合同:124明文上升沿采样，未允许这种NBA旧值观测。这与已知只回读3个诊断字节不同：即使扩到38个，沿用相同时序仍会漏掉此错误（独立legacy探针已证明）。
- **置信度**：**仿真确认**。
- **建议方向**：让SPI主机按真实采样沿观察已稳定SDO并避免同时间槽竞争，再核对原有TC及全地址读回。

### F-011：FSC 周期检查允许 5001 拍，漏过 F-009

- 严重度/层：S2 / TB。置信度：静态确认并有严格比较仿真对照。
- 位置：`rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:581`.

```text
check_fsc(14, flag_wait_ok && ((reg_frame_period == 5000) || (reg_frame_period == 5001)));
```

- 描述与依据：FSC-14的真实比较允许5000或5001，但C08:137-142只冻结5000，FSC-35:1167还要求无漂移；因此原59项PASS不能证明精确400 Hz。
- 证据：

```text
ALL FSC-01 THROUGH FSC-59 PASSED
B_NORMAL_PERIOD cycle=5007 period=5001 frame=1
FAIL FSC-100 cycle=5007 tick=1
```

- 反驳与范围：原单元TB真实59 PASS，而同原RTL严格周期探针3次FAIL。反驳：不存在合同±1拍允许条款。Q3恒1在TB:276明确将门控覆盖交给系统LFA-06；C08:4/6明确该系统证据，故不把这一分工追加为无覆盖结论。固定DONE桩与C08:1205的要求另列后续裁定，不扩大本条。
- 原始证据：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\scheduler_cadence`。
- 建议方向：将连续全就绪条件下的周期判据收紧到合同值。

### F-012：SUP10A 清空历史后才重开 episode，不能证明未清快照时重新触发 trio

- 严重度/层：S2 / TB。置信度：仿真确认（变异逃逸与补充对照）。
- 位置：`rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v:459`；`rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v:475`；`rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v:480`.

```text
i_diag_clear_event = 1'b1;
// SUP-10：验证第二个独立episode（此前episode均已完整关闭+诊断清除，非同一episode延续）依然
check_case("SUP10A", (o_system_fault_blocking === 1'b1) &&
```

- 描述与依据：C24 §4:110-118要求保留首故障快照的后续episode仍发新abort/stop/discard三联事件。原TB:365-368/414-416/459-461先清历史，:479-488期望全新cause03。故:475-478声称补齐“独立于首故障历史”过强；alias:482也采纳此说明。
- 证据：

```text
SUP-01 through SUP-10 PASS: 14 real comparisons
PASS BREARM
FAIL BREARM at 90000
```

- 反驳与范围：仅将RTL:198 episode-open从!blocking改成!cause_valid，原TB仍14 PASS；独立扩展保留cause01历史再发cause02，原RTL6比较通过，同变异BREARM FAIL、退出1。错误期望负对照SUP01A也真实FAIL。原RTL实现正确。matrix:992与alias:63只声明结构证明/非穷尽；本项不推断全系统毫无覆盖。非第4节已知事项。
- 原始证据：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\supervisor_original_rearm_mutant`；`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\supervisor_extended`；`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\supervisor_extended_rearm_mutant`；`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\supervisor_wrong_expected_negative`。
- 建议方向：补保留历史的rearm用例，同时检查新trio与旧snapshot。

### F-013：CCC-22 未比较软件清除后 sticky=0，删除清除逻辑仍可通过

- 严重度/层：S2 / TB。置信度：仿真确认（变异逃逸）。
- 位置：`rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v:431`；`rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v:437`；`rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v:442`.

```text
i_diag_clear_event = 1'b1;
launch_control_inflight(1'b0, 5'b11110);
check_case(8'd22, (flag_reject === 1'b1) && (o_protocol_error_sticky === 1'b1) &&
```

- 描述与依据：C06 §12.2:315和CCC-22:359要求软件清除及同拍错误优先。TB清除已有sticky后没有在:435-436比较0，立即发新拒绝，仅检查最终1与配置保持。
- 证据：

```text
ALL CCC-01 TO CCC-26 PASS (26 checks)
FAIL CCC-4 at 146000
CCC REGRESSION FAIL (1 failures, 25 passes)
```

- 反驳与范围：仓库外仅将RTL:188软件清零改成自保持，复位清零保留，原26项全部PASS；错误CCC-04期望负对照确实报FAIL。读取过完整原日志、result.json及变异源码；各次编译0、运行0，所以不能按退出码判PASS。CCC-23仅是共同复位，不覆盖软件清除；原RTL:185-188实际正确。N04是其它模块清除事项，不豁免CCC-22。
- 原始证据：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-edf3-7221-9fc4-3dd2391369a9\ppg_review_D\evidence\tb_ppg_characterization_control_cdc`；`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-edf3-7221-9fc4-3dd2391369a9\ppg_review_D\evidence\ccc_clear_mutant.v`。
- 建议方向：增加纯软件清除后的零值比较，保留错误优先比较。

### F-016：PRC-09 把 FIR 空闲周期当作未合格窗口，未发生资格丢失也能满足恢复判据

- 严重度/层：S2 / TB。置信度：仿真确认监视器行为，静态确认判据不足。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:1048`；`rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:1049`；`rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:1690`.

```verilog
if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.flag_fir_detection_qualified) begin
reg_unqualified_after_injection_count = reg_unqualified_after_injection_count + 1;
end else if(reg_unqualified_after_injection_count == 0) begin
```

- 描述与依据：FIR:409输出qualification来自payload，:441-442消费后payload归零，故valid=0时qualification=0是正常空值。TB:1046-1053没有按FIR valid/ready门控，:1679恢复等待和:1690-1694仅要求观察过若干低周期、随后看到1，不能证明C25:719要求的每个覆盖注入样本的有效窗口都不合格。
- 证据：

```text
A actual-loss checker_pass=1 unqualified_cycles=475 actual_unqualified_valid=21
B ignored-loss checker_pass=1 unqualified_cycles=13 actual_unqualified_valid=0
AUDIT_PRC09_AB_CONFIRMED
```

- 反驳与范围：真实原FIR与仓库外仅移除flag_sample_qualified中的!flag_test_calibration_loss_active项的变异FIR，21样本warmup后用同一注入/22个后续真实输入；监视器均判通过，变异的实际未合格valid握手数为0。错误oracle期望负对照退出1并报AUDIT_PRC09_AB_FAIL。探针提取本监视器判据，未声称整个1770行TB变异后仍67 PASS。叶子FIR-17/31等独立验证不能修正本系统PRC-09归因错误；原RTL注入逻辑正确。本项非已知PRC-04。
- 原始证据：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\prc09_monitor_ab`，包括临时TB、变异副本、输入hash、真实命令及日志；仅在仓库外执行。
- 建议方向：按真实FIR结果握手统计覆盖窗口，绑定注入样本身份和失效/恢复先后关系。

### F-017：PRC-10 所称顺序比较只检测相邻重复，倒序或跳号不能触发

- 严重度/层：S2 / TB。置信度：仿真确认监视器行为，静态确认判据不足。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:902`；`rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:1696`；`rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v:1700`.

```verilog
if((o_result_sample_index - reg_last_result_sample_index_prc) == {C_SAMPLE_INDEX_WIDTH{1'b0}}) begin
if(reg_order_violation_count != 0) begin
$display("PASS PRC-10 sample_index/identity order preserved across the injected sample and its recovery, order_violation_count stayed 0");
```

- 描述与依据：TB:902只比较差值是否为0，最终:1696-1700把零重复计数写成sample_index/identity顺序保持；没有在该监视器比较frame/color或模序号连续性。C25:720要求后续合法结果保持frame/sample/color order。
- 证据：

```text
A ordered 0,1,2: original_order_check_violations=0
B reordered 1,0,2: original_order_check_violations=0
C duplicate 1,1,2: original_order_check_violations=1
```

- 反驳与范围：最小Verilog保留原16-bit减法比较和NBA记录时序，倒序反例漏报、重复负对照恰好报1次；编译0、运行0。这仅验证检查器盲点，不证明生产数据实际倒序；共享JNT/AMI其它身份检查有独立范围，也不等于本PRC-10注入恢复监视器检查了顺序。TRK-01原子载荷豁免是其它结构问题，不能证明流顺序。
- 原始证据：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\prc10_order_probe`，包括临时TB、变异副本、输入hash、真实命令及日志；仅在仓库外执行。
- 建议方向：明确允许的丢弃/回绕规则，再比较相邻身份的顺序及颜色、frame归属。

### F-025：ACTIVE wrapper 的字段透传检查漏 alpha，固定错误输出仍 22 PASS

- 严重度/层：S2 / TB；置信度：仿真确认。关联D-004。
- 位置：`rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v:192,674,679`，原文3行（注释行保留）：
```text
wire [15:0]o_alpha_q15;
//AV4C-02、AV4C-03、AV4C-15、AV4C-17：检查唯一解包器对所有关键signed字段逐位透传。
$display("PASS AV4C-02");
```
- 描述/依据：C03:246-251要求V5具名字段原样输出，AV4C-02:296要求具名字段正确。TB声明/连接alpha，但675的长比较没有它；全文件搜索alpha只有声明/连接与配置字段，没有输出比较。默认合法值TB:79为199A，错误全零应被识别。
- 证据：D外部wrapper副本只将356的alpha输出置0000，完整原TB仍22个PASS及`ALL AV4C-01 THROUGH AV4C-22 PASSED`，编译0运行0。错误AV4C-01期望负对照报`FAIL AV4 control plane self-check errors=1`；A已核对实际单行变异、完整原日志/命令及合同。其他未逐一变异字段不按本项宣称全量证明。
- 反驳：unpack叶子1024-bit one-hot比较确实有效，切片变异有18个FAIL，但没有经过wrapper第二跳，不能覆盖本次输出变异；本条不推断系统层完全没覆盖。实际生产alpha透传正确，无RTL错误指控，无已知事项豁免。
- 建议方向：对wrapper具名输出用完整合法非对称配置逐项独立比较。

### F-026：四份 ADC/fork 模块 TB 漏接 29 个现有输入

- 严重度/层：S2 / TB；置信度：静态确认及真实编译诊断。关联C-002，统一四文件一条，未证明生产数值算法故障。
- 位置：三个代表性实际端口分别为 `rtl/ppg_adc_result_router/ppg_adc_result_router.v:88`、`rtl/ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v:69`、`rtl/ppg_adc_dc_recovery/ppg_adc_dc_recovery.v:93`，原文3行：
```text
input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation,
input i_datapath_discard_event,
input [8:0]i_detect_code,
```
- 描述/依据：Router TB:465-514缺run_generation；overlap TB:753-802缺run_generation及9个discard输入；DC TB:444-474缺detect_code、两级raw/code_ext及nominal15三诊断输入；NORMAL fork TB:525以后完整绑定缺10个generation/discard输入。合计1+10+8+10=29。实际Icarus -Wall分别精确报1/10/8/10个dangling input，名称清单在evidence/merged_findings_oct4c_refs.json；C组skill AST及完整绑定人工核对一致。
- 证据：原始编译例 `warning: Instantiating module ppg_adc_result_router with dangling input port 22 (i_run_generation) floating.`；这些未绑定输入为Z，TB没有对应有效窗口比较。四份原正常数值/FFK PASS仅支持已有真实比较，不能证明新代际、cancel及DC诊断payload接口；无新增全字段变异完成声明。
- 反驳：AMI实际生产实例有连接，不使这四份模块TB缺失激励变成存在；系统覆盖仍须逐项追溯，不声称全系统都漏。C11/C14/C15条件豁免是不同模块/不可达discard前提，不豁免这些已有接口的输入驱动及DC诊断透传。与F-001四份注入系统TB、五组悬空输出及TRK-01原子耦合不可测试不同。
- 建议方向：补齐公开输入驱动，并以错generation/诊断透传等变异核实实际比较。

### F-027：PR-06 正负半值标签未构造门限，舍入门限变异逃过完整原 TB

- 严重度/层：S2 / TB；置信度：静态公式、短Verilog及真实变异确认。关联C-003，按本任务验证缺口统一为S2。
- 位置：`rtl/ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v:338-340`，原文3行：
```text
// PR-06：正负半LSB边界由黄金模型逐笔比较
send_transaction(6, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, 32'sd32768, 1'b1, 1'b1, 8'h16, 8'h38, 8'h5b, 8);
send_transaction(6, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, -32'sd32768, 1'b1, 1'b1, 8'h16, 8'h38, 8'h5b, 9);
```
- 描述/依据：C14:141-143/162-165及PR-06:334要求正负对称门限。S1=256给S1_CENTER_X2=1，Stage1贡献3533837；D2=256/gain0，offset±32768只增加±65536，实际总ACC为3599373/3468301，均正，输出27/26。offset是半值不等于总累加值在门限。
- 证据：A `pr06_formula_actual`六个独立整数期望的短Verilog编译0运行0，输出`PR06_POS_OFFSET acc=3599373 rounded=27`、`PR06_NEG_OFFSET acc=3468301 rounded=26`；错27→28的负对照fatal。C已完成真实DUT公开邻点四向量输出0/1/0/-1；仅将ROUND_HALF_Q17从65536变65534的外部RTL，完整原TB仍`PASS ... PR-01..PR-14 and 1024-code sweep`，新增邻点第二比较却fatal `case 1 got=0`。原始日志在C evidence/targeted_runtime_20261004/reconstructor_{original,round_mutant,legacy_mutant}，A读实际TB/变异及日志。
- 反驳：1024码sweep包含正负，最近距门限25 Q17单位，故不称整个TB没有负舍入覆盖。合法总ACC恒奇数、精确半值不可达，应测门限两侧可达邻点；不能通过强制中间量造非法tie。overlap另有有效邻点不是本DUT，PRC-04已知项也不相关。原RTL舍入正确，仅验证证据不足。
- 建议方向：用公开输入构造正负门限两侧可达邻点，并同步PR-06覆盖文字。

### F-028：ILM-04/05 LED 禁止驱动检查跳过真实转换窗口

- 严重度/层：S2 / TB；置信度：ILM-04原场景短片段变异确认，ILM-05同结构静态确认。关联D-005。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v:1677,1680,1694`，原文3行：
```text
if((!o_en_test) || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
wait_q3_release(real_release);
$display("PASS ILM-04 EXTERNAL_TEST_CURRENT BOTH SAR9: EN_TEST=1, LEDEN1/2=0, LEDDAC=0 held, RED=%0d IR=%0d",
```
- 描述/依据：C25:632-633要求固定电流转换EN_TEST高、LEDEN低且无LEDDAC窗口。原循环每笔在wait_q3_release前只采一次，整个等待Q3窗口没有继续检查。
- 证据：D按固定原文件行复制初始化/task/monitor与ILM-04六笔真实RED/IR、实际Top链，外部Top仅在EXTERNAL_TEST_CURRENT且Q3时映射LEDDAC=01；独立negedge监视实见12个非法周期，原比较却`PASS ILM-04 ... RED=3 IR=3`、`D_ILM_FRAGMENT errors=0 observed_led_violation=12`。未变异违规0；错期望00→01负对照errors1且FAIL。三次编译0运行0，判据从实际错误计数/日志取，不使用rc0判通过。A已读复制脚本、变异、合同及原始日志/命令。
- 反驳：完整TB/共享前缀无在该六笔事务持续运行的固定电流逐拍监视；ILM-10另一个40拍场景不能覆盖本窗口。SSW叶子检查不经过Top映射，未替代覆盖。与后续回补ILM-11/12、冻结D03或P2S不同；不是生产RTL错误。未重跑完整长回归的变异，不称全73 PASS逃逸。
- 建议方向：对合法固定电流RUN的有效窗口持续检查三个输出并计数。

### F-029：ISE 选中总线的最后非零值比较漏掉中间一拍错误

- 严重度/层：S2 / TB；置信度：原ISE-04短片段变异确认，其他同构selected监视为静态确认。关联D-006。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v:780,815,954`，原文3行：
```text
if(o_idac_sar9ambn_low !== 8'h00) reg_seen_sar9_ambn <= o_idac_sar9ambn_low;
if(o_idac_sar9ambn_low !== 8'h00) reg_ise_seen_ambn <= o_idac_sar9ambn_low;
if((reg_seen_sar9_ambn !== 8'hA5) || (reg_seen_sar9_dcn !== 8'h3C)) begin
```
- 描述/依据：C25:665/667-670要求当前波形逐位冻结/门控。监视器只记最后非零值，不积累中途不匹配；下一正确值能覆盖此前错误，零值也被忽略，不能证明958所称整个Q3 bit-for-bit保持。
- 证据：D复制ISE-04 Phase A两笔真实SAR9事务及完整Top，外部Top仅每次Q3首周期将A5翻为A4、下一周期恢复。独立negedge检查2个错误周期，原两比较仍PASS，`D_ISE_FRAGMENT errors=0 observed_active_bus_violation=2 zero_checks=5305`；原对照违规0，错误期望A4产生2 FAIL/errors2。编译均0运行均0，使用真实FAIL/计数。A核对实际脉冲条件确实命中、原始日志和命令，初次条件不命中的nontrigger_setup未采用。
- 反驳：未选中精度总线持续零比较776/785是真实有效的5305/5308计数，不扩大为四总线全未查。JNT前置事务不持续覆盖这两笔，叶子SSW局部正确不检查Top映射。实际生产映射正常，不报RTL错；无已知事项豁免。未声称完整长TB变异仍70 PASS。
- 建议方向：按具体AMB/DC有效窗口逐拍比较并锁存错误，窗口外核对合法idle值。

### F-031：IDAC 单元 TB 的低码搜索未检出九位求和截断

- 严重度/层：S2 / TB；置信度：仿真确认。关联C-005。
- 位置：`rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v:503,506`及`contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:509`，原文3行：
```text
i_dcs_r_code_max = 8'd17;
i_dcs_ir_code_max = 8'd27;
1. 初始候选为`floor((low_bound + high_bound) / 2)`；中间求和至少9 bit；
```
- 描述/依据：首轮范围AMB0..7/R10..17/IR20..27；restart:464-471及其调用只用max<=30，端点和<=60。规范的8位码域最高和510，当前真实搜索不经过第9位。
- 证据：A已读C公开端口TB固定8候选字面量127/191/223/207/199/203/201/200，范围0..255、目标200，原RTL编译0运行0，`C_IDAC_MIDPOINT_PASS count=8 target=200`。仓库外仅将RTL:530的AMB初始和及:533后继和掩为低8位；公开TB运行1，`C_IDAC midpoint[1] expected=191 got=63`。同一变异运行完整原TB仍148条PASS、最终regression completed，退出0。原始命令、哈希及日志已复核并索引evidence/merged_findings_oct4d_refs.json。
- 反驳：原RTL确实扩成9位，本条不报生产溢出；完整TB每次最终码的比较是真实有效，只无法识别此宽位缺陷。系统SID/ISE等可能覆盖部分高码，不能代替该单元TB已有搜索算法验收，未据此宣称全系统无高码覆盖。generation悬空旧问题已修复，与本条不同；无已知事项豁免。
- 建议方向：加入高码、第9位和0/255端点的公开搜索向量及独立逐候选比较。

### F-036：PWI 尾部测试丢弃累计前置判据，第一笔提前报错仍 PASS

- 严重度/层：S2 / TB；置信度：真实PWI链原场景短片段变异确认。关联B-011。
- 位置：`rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v:738,743,746`，原文3行：
```text
flag_case_ok = flag_case_ok && o_active_precision_mode && o_fine_window_active && (cnt_fine_start_event == 1);
flag_case_ok = flag_case_ok && (o_peak_valley_protocol_error_sticky == 1'b0);
check_case("PWI-01", o_peak_valley_protocol_error_sticky && (cnt_fine_start_event == 1) && o_active_precision_mode && o_fine_window_active);
```
- 描述/依据：前10笔合法、真实fine事件/进入状态累计到flag_case_ok，最终check_case却不使用它，只要求第11笔后已有sticky。PWI-02:758-766的累计变量也未进入769比较。C18:639要求最多10笔合法、第11笔才错误。
- 证据：原PWI-01片段及仅将外部PVW的FIR_GROUP_DELAY_LIMIT从10改0的变异，均1 PASS/0 FAIL，`saved_preconditions=0`，运行0。直接加flag_case_ok连原RTL也FAIL，因为738读取事件计数尚未经过下一计数沿。补一个negedge观察并使用累计值：原链`count=1 B_TAIL10 sticky=0 saved=1`最终PASS，提前报错变异`sticky=1`最终FAIL、运行1。A已核对单行变异、公开激励、原始日志及采样原因。
- 反驳：PVW其他独立尾部测试有效，不能使此PWI集成项真实检验进入期间前10笔行为；不据变异称原RTL尾部错误。已知C18:690说明PWI06..10缺独立TB，不在本项重复上报。没有运行完整5项变异，仅报告原PWI-01片段和PWI-02静态同构遗漏。
- 建议方向：修正观察时点并将累计判据纳入终判，保留提前报错负对照。

### F-037：JNT 数量不足不增加统一错误数，官方统计也漏 status=FAIL

- 严重度/层：S2 / TB·运行判据；置信度：检查器原分支短仿真、调用方及脚本静态确认。关联C-008。
- 位置：`rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh:796,801`及`rtl/ppg_control_top/run_xsim_regression.sh:90`，原文3行：
```text
flag_jnt_baseline_pass = (cnt_run_jnt_checked == C_JNT_REQUIRED_SUBCHECKS) && (cnt_run_jnt_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_run_jnt_fail == 0);
cnt_error = cnt_error + cnt_run_jnt_fail;
fail_count=$(grep -c -E "^FAIL |ERROR:|FATAL_ERROR|UVM_ERROR" "$logdir/xsim.log" 2>/dev/null); fail_count=${fail_count:-0}
```
- 描述/依据：检查数量/通过数不足时flag为0且打印JNT status=FAIL，却只加单项失败数；已执行子检查全成功时错误数仍0。所有flag使用只在该头自身306/796/797，ADCN:1178等调用方不验证flag，继续组场景并最终按cnt_error判定。C25:442-443要求JNT不足时整个组失败，当前头要求54项。
- 证据：C真实原分支提取短仿真54/54正常PASS；51/51单项fail0打印`status=FAIL`又`GROUP_WOULD_PASS error_count=0`，独立断言fatal运行1；外部数量不足至少加1的限定对照errors1运行0。A读取三份短TB、原始日志和实际源分支。官方脚本仅统计`^FAIL |ERROR:|FATAL_ERROR|UVM_ERROR`，此JNT行不匹配；它只输出统计表，并没有独立JNT前提检查。
- 反驳：正常真实54项运行有效，不称当前未改系统TB只执行51项；每项真实比较也没有因此失效。数量缺失场景仅短检查器，不是完整系统变异。日志本身已有FAIL可供外层更严格审计拒绝，本报告审计器补入status=FAIL判据；不能据error_count0或官方fail_count0判通过。旧52/53注释、TRK01等接受项不覆盖统一失败计数。
- 建议方向：数量不足进入统一错误计数，调用方和运行判据明确核验JNT前提。

### F-038：OPT-23/24 没有构造连续周期和随机正式最终结果差分

- 严重度/层：S2 / TB；置信度：静态确认覆盖义务与实际激励/比较不符；未运行本项新的全TB变异。关联C-009。
- 位置：`rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v:410,1281,1303`，原文3行：
```text
reset_dut;
check_sequential_divider(24'sd2000, 24'sd0, 25'd2000, 16'd257, C_ALPHA_Q15);
check_case("OPT-24", flag_random_divider_ok && (cnt_divide_cycles == 42));
```
- 描述/依据：OPT23的两次check_sequential_divider都reset+START，不能证明无复位的两个完整周期不复用旧pending；OPT24随机32次同样每次reset，独立比较是内部42轮商及周期数426，不比较随机事务的最终平滑/提交结果。C21:589-592要求连续完整周期及所有合法随机正式结果逐位一致，覆盖正负平滑、无相交、lead三区间、短回绕和饱和。
- 反驳/证据：原商golden、42轮计数、其他固定场景及共享乘法局部监视均有效，原65 PASS不否定这些真实检查。phase_a_equivalence的20005向量无DUT，只证明窄宽公式等价；公开独立算术边界向量每组独立运行，也不验证连续pending。系统连续波形B[f]比较使用DUT报告斜率，不能替代最终斜率独立随机参考。只报这两项覆盖声明不足，不宣称原数值RTL错误。
- 建议方向：增加不复位双周期和从合同/公开输入独立计算的最终参考，并做旧pending/最终提交变异抽查。

### F-040：INJ-04 在两类注入均未就绪的窗口检查互斥，删门控仍 PASS

- 严重度/层：S2 / TB；置信度：真实Top原场景短片段变异确认。关联B-013。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_injection.v:1006-1008`，原文3行：
```text
i_test_identity_inject_valid = 1'b0;
i_test_invalid_sample_valid = 1'b0;
drive_real_adc_done(1'b0, reg_fixed_stage1_raw, reg_fixed_stage2_raw);
```
- 描述/依据：995-1004只在DONE到达前重叠请求4拍，再撤销valid才投递DONE。AMI:1012 identity-ready需completion_pending/S1valid；:1013 invalid-ready需真实NORMAL DC transfer，重叠窗口两者都未出现。C01 TOP-24:936及:946把该项作为双请求互斥闭合，不能以未就绪时ready0证明处理窗口互斥。
- 证据：B复用真实合法COMMIT/START/Q3和原INJ04，双方将F-001相关cal-loss valid绑0隔离已知X；原RTL与仅删1012/1013两互斥项的外部变异，均4条PASS、运行0，`window_cycles=4 eligible_cycles=0 ready_cycles=0`。保持双请求穿过真实DONE的补充窗口，原`eligible2 ready0`、变异`eligible4 ready1`且独立ready错误检查fatal运行1。A已读刺激、差异和原始日志；v2补充后续还重复驱动一次DONE，不据该补充序列宣称全协议无错误，其首次真实eligible/ready旁证足以分辨门控。
- 反驳：INJ02/03分别验证单请求，不能覆盖双valid同拍门控；原互斥RTL正确，本项是TB窗口错误。Top锁存enable不是两个请求资格，不能补这一交叠。非F-001悬空输入原因，变异对照已一致隔离；未声称完整15 PASS变异逃逸。
- 建议方向：在真实两类处理资格窗口持续检查ready/fire、副作用及owner身份，使用单笔合法DONE。

### F-041：RRC-01 只打印首次 pending 帧数，没有比较配置间隔

- 严重度/层：S2 / TB；置信度：静态确认及原终判短Verilog确认。关联B-014。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_periodic_recheck_recovery.v:1056,1067,1071`，原文3行：
```text
cnt_frame_before_pending = cnt_real_macro_frame_complete;
if(!flag_pending_before_fine_window) begin
$display("PASS RRC-01 recheck pending asserted after %0d completed real NORMAL macro frames (configured interval=30, counted by real sched_normal_frame_complete_event_o pulses, not by ADC/owner-commit events)", cnt_frame_before_pending);
```
- 描述/依据：497-498设间隔30、865-869数真实宏帧，1056保存首次pending计数；终判只要求pending曾出现，未比较应于30帧到期，也未比较双光owner和整帧比率。C16:415-420规定单位为完整NORMAL帧而非单个颜色事务。
- 证据：A提取1067-1072原分支实际编译0运行0，计数30和错误计数1均打印PASS，分别`after 30 ... configured interval=30`、`after 1 ... configured interval=30`；pending从未出现负对照真实FAIL。日志evidence/A_rrc01_checker。不使用该短检查器宣称改RTL间隔后完整RRC会通过。
- 反驳：AMR单位TB有正确周期证据，不能让这份集成检查验证传入的真实事件来源/间隔；后续RRC12有部分码保持比较，也无该到期等式。只报此系统验收声明，未声称周期计数RTL错误或全项目无覆盖；不重复F-009物理宏帧多拍。
- 建议方向：在完整宏帧完成沿逐次核验pending到期边界，并核对同窗双色owner增量。

### F-042：OIB-06 的排序和重复判据不能证明无丢失及三类元数据错标

- 严重度/层：S2 / TB；置信度：原监视器/终判短Verilog及跨场景静态确认。关联B-015。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v:951,956,1875`，原文3行：
```text
end else if((o_result_frame_id == reg_last_result_frame_id) && (o_result_sample_index == reg_last_result_sample_index)) begin
cnt_duplicate_or_relabel_violation <= cnt_duplicate_or_relabel_violation + 1;
$display("PASS OIB-06 result stream preserved order with no loss/duplication/recoloring/retyping/precision-relabeling across %0d real transfers", cnt_result_capture);
```
- 描述/依据：946-960只检测(frame,sample)递减或相等；颜色/type/precision仅锁存/打印，未与每笔owner期望队列比较，也无数量守恒。C25:684规定无loss/duplication/recoloring/retyping/precision relabeling；别名174/176声称全部已覆盖。
- 证据：A直接复制942-967监视器与1868-1876终判，输入合法16位二值结果流。基准四笔及分别漏第2笔、翻color、改type、改precision四反例均`errors=0`并原OIB06 PASS；重复/倒序两个已知错误负对照各`errors=1`且FAIL，编译0运行0。evidence/A_oib06_checker及stream_interval_checker_evidence_A.json。只证明原判据盲点，不冒称完整1887行TB的RTL变异通过。
- 反驳：OIB07:1670-1671确有一笔frame/sample/color/precision比较，OIB09:1567/1621有两笔前后epoch核对；不能将这些有限真检查扩大为全stream、type及丢失检测。与F-017不同TB/验收义务，与F-003旧行号不同；原元数据RTL未证明错误，已知事项不豁免此项。
- 建议方向：从真实owner与合法discard维护期望队列，逐transfer比较身份/元数据并核对守恒。

### F-044：疑似——P06 动态闭合是否需要叶子去使能，范围尚待裁定

- 严重度/层：S2 / TB·跨层（疑似）；置信度：疑似，刺激到达事实已仿真确认，但合同允许的覆盖范围尚不能判为新错误。关联B-016，**不计已确认发现**。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_injection.v:783`、Top RTL:392、C10:714，原文3行：
```text
i_test_inject_enable = 1'b0;
end else if(!wrapper_run_enable_o) begin
in CONFIG/READY, is locked on accepted START and ignores source changes in RUN.
```
- 描述：TB拉低Top源enable后仍见AMI hold1；Top RUN锁存使叶子enable实际仍1。若P06闭合要求AMI端实际去使能，该动态证据未构造它；若接受合法系统源去使能加Top锁存结构证明，则该场景确实证明了系统性质，不能报成验证错误。
- 证据：原场景短链与在外部AMI副本加!enable清hold的错误分支，均3 PASS、运行0，`outer_enable=0 leaf_enable=1 hold=1 abort=0`及`leaf_disable_cycles=0`。双方隔离F-001。A已核对原实际接口、公开激励、变异及日志，evidence/merged_findings_oct4g_refs.json。
- 反驳：C10:712-714明文控制只能由Top注册源进入、START后锁定并忽略RUN源改变；这使所提叶子去使能在合法RUN结构上不可达。C10:715及矩阵P06:928的AMI request-slot保持义务仍可由当前寄存器静态规则支持。不能仅凭不触发的叶子变异将已被另一机制覆盖的性质判失效。TRK01的既有结构豁免针对其他ID，是否采用类似静态闭合需接口owner明确。
- 缺失证据/建议方向：明确P06要求的入口层与可接受静态闭合证据；若要独立叶子动态证明，再用合法叶子场景实降输入。这里不请求修改RTL，也不升级为芯片功能错。

### F-049：INJ-03 把“不是全 X”当成无效样本身份保持正确

- 严重度：S2；层：TB；置信度：仿真确认。
- 位置与原文：
`rtl/ppg_control_top/tb_ppg_control_top_injection.v:957`
> end else if((reg_captured_coarse_value === 24'sbx) || (reg_captured_frame_id === {C_FRAME_ID_WIDTH{1'bx}})) begin
`rtl/ppg_control_top/tb_ppg_control_top_injection.v:961`
> $display("PASS INJ-03 invalid-sample-injected transaction reached the formal boundary with sample_valid=0 and identity/value fields intact");
`contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md:935`
> | TOP-23 | PRC-08顶层资格 | invalid请求绑定一笔真实身份匹配NORMAL事务；正式输出保留identity且sample-valid为0，FIR/基线/峰谷/精度不推进，后续合法样本按合同恢复 |

- 描述：INJ-03 只排除整个 coarse 值/整个 frame_id 全 X，未把正式结果身份与该笔真实 owner 的身份比较。有限数值但错误的 frame_id 仍会打印身份完整且整个注入 TB PASS；C01 TOP-23 要求保留真实身份，C25:718 的 PRC-08 同样绑定真实身份匹配事务。
- 仿真：在仓库外只将 Top:1497 的正式 frame_id 透传改成“sample_valid=0 时最低位翻转”；不改变 AMI 内部、owner、RAW、资格及其他结果字段。完整原 INJ 场景及原比较分支保留，仅加不影响计数的独立观察。正常对照：
```text
AUDIT_IDENTITY expected_frame=1 observed_frame=1 sample_valid=0
INJ_TB_PASS
```
身份变异：
```text
AUDIT_IDENTITY expected_frame=1 observed_frame=0 sample_valid=0
AUDIT_IDENTITY_FAIL invalid result frame differs from the real accepted owner
PASS INJ-03 invalid-sample-injected transaction reached the formal boundary with sample_valid=0 and identity/value fields intact
INJ_TB_PASS
```
负对照仅把同一真实预期比较纳入 cnt_error，完整 TB 最终为 `INJ_TB_FAIL error_count=1`。三组真实 iverilog -Wall 编译成功，vvp 均执行至最终横幅；rc=0 不能替代横幅判据。原始日志、两个仓库外变异及观察代码在 `evidence/inj_identity_A/`，命令与 SHA 在各 native.result.json。
- 反驳：(a) robust:1712-1716 对 PRC-08 直接引用并打印 INJ-03，未再构造或比较该无效事务身份；INJ-03 的后续合法样本检查仅检查 valid/sample_valid，不能查出前一笔有限错误 frame_id。其他单位/数值场景可以检验合法载荷，但本次完整注入 TB 在该真实无效事务错位时确实逃逸，不声称全部系统 TB 都漏掉所有身份错误。(b) 与已知 P2S 三路遥测错拍不同，本变异针对正式事务身份；与 F-001 悬空校准注入输入及 F-042 OIB 队列检查也是不同判据。(c) C01:935 不允许无效资格事务改绑身份，sample-valid=0 不免除载荷身份保持。
- 建议方向：在注入握手前缓存真实 owner 的完整身份，并在对应正式无效结果出现时逐字段比较。

### F-002：C13完整discard身份端口声明比RTL多出五个epoch输入

- **严重度/层**：S3 / 合同·跨层。
- **位置及原文（3行）**：
  - `contracts/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md:89`：`i_datapath_discard_<TXN_ID>` group, `o_run_generation[C_RUN_GENERATION_WIDTH-1:0]`,
  - `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:118`：`is a formal port-name macro, not an implicit packed bus or a permission for`
  - `rtl/ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v:77`：`input [C_RUN_GENERATION_WIDTH - 1:0]i_datapath_discard_run_generation, // 本次清空目标RUN代际`
- **描述/依据**：C13:85-90明文要求complete TXN_ID组；矩阵:82-92展开TXN_ID含config/coef/dc_recovery/amb_code/dc_code五个epoch。但overlap输入组:69-77只有reason、identity-valid与六个FAULT_ID形状字段，没有这五个discard epoch端口。正常事务的epoch输入不能代替独立的discard身份输入。矩阵:2863-2871同样只列出实际小组，:2920却声称60/60与合同匹配。
- **证据/反驳**：仓库skill AST端口结果与实际声明逐项一致，保存于`evidence/c13_port_evidence.json`；AMI:2077-2085实例也只传小组，没有另一路完整身份补偿。当前清除条件overlap:217只比较generation，故没有证据表明缺失的诊断epoch会造成错误清除；本条仅裁定合同与实现不一致。用户已知C11/C14/C15条件豁免针对discard广播可达性，不是C13完整形式端口免除。已检查C10/C12/C13、矩阵identity宏及最近两批同步报告，未找到把C13 TXN_ID缩成FAULT_ID的明文许可。
- **置信度**：静态确认，端口存在性无需仿真；未据此认定S1功能错误。
- **建议方向**：由接口所有者裁定完整诊断身份是否必要，选择补齐端口或把C13及台账改成实际小组。

### F-003：矩阵/别名表存在可直接证实的失效行号锚点

- **严重度/层**：S3 / 矩阵·台账。
- **位置及原文（3行）**：
  - `contracts/PPG_ALIAS_MAPPING_TABLE.md:58`：``| K01 (precision→PWI私有flag) | 无独立TB场景(语义追溯,非单独仿真项) | `ppg_precision_window_controller.v:292` (`o_mode_fault_active`) | `PPG_CONTRACT_CLOSURE_MATRIX.md:872` |``。
  - `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:872`：`anything?**`
  - `rtl/ppg_control_top/ppg_control_top.v:121`：`input [9:0] i_dout_stage2_low,                       // Stage2物理判决码，进入AMI（STAGE2）（二级）`
- **描述/依据**：当前累计确认643处文字/当前章节不符、14处越界，按引用出现位置而非独立缺陷计数。包括165个Top声明、64个Scheduler/AMI子模块声明、12个K出处、6个C09依赖、3个AMI标签、以及390个合同Source索引和3个说明列缩写/跨行文件名索引。最后一批864条Source逐项裁定新增84处：空行、围栏、ASCII图、错误输入/输出握手边界及把正式测量/检测discard指向物理ADC owner或成功completion章节；另把C03的生命周期/START-ready两处歧义裁定为章节索引错位。所有真实端口与正确现行定义已另核实，不把失效引用推导成硬件未实现。全1860条Source现均有独立记录，合法分组/完整身份展开/当前覆盖及矩阵自述缺口保留，不凑成失配。逐项原Source、目标文字、正确当前定义和实际Erie端口声明见`anchor_failures.csv`及各`*_source_rows_*.json`；不能当成643个独立功能错误。
- **证据/反驳**：扫描已先以正确锚点和三处已知错误作负对照，恰好报出错误文字/不存在文件/越界三类。忽略删除线中的旧引用，Cxx:3按版本行，带小数及低整数歧义按节号保留，不报为失效。C01“当前合同行号”的补记修正了合同侧Source列，未修正这些RTL声明列；:1324重建说明仍重复Top:121，没有给出实际端口行号。新增64处逐项确认所列端口在目标模块的正式AST端口集合中存在、方向正确、引用行却不含该端口；单端口声明列未设历史删除线，说明列没有替代当前声明行；实际正确端口位置来自AST并逐行核对，未按偏移计算。C16/C17的244条声明锚点字面均匹配，此结论不替代其生命周期签核。K机制已在真实RTL及矩阵新位置存在，故本条不是K闭环缺失。用户已知§13.1快照滞后、未独立复核台账、style backlog及旧外部文件不是本条所报告的错误。外部memory/缩写文件缺失6条单列为待裁定，未算入本发现。
- **置信度**：静态确认（声明文字/边界与K出处）；其他未附明确预期文字的“in bounds”引用仍仅为候选，未宣称正确。
- **建议方向**：从固定提交逐行重新定位并重建锚点，保留历史引用时明确标记历史性；不要用全文件统一偏移。


### F-004：C13给纯组合Router声明了不存在的注册式local-empty

- **严重度/层**：S3 / 合同·跨层。
- **位置及原文（3行）**：
  - `contracts/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md:99`：``normal output. Router `o_local_empty` is a registered local fact consumed only``
  - `contracts/PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md:65`：`5. router没有独立empty寄存器，STOPPING排空由校准器valid和各分支消费者状态共同汇总。`
  - `rtl/ppg_adc_result_router/ppg_adc_result_router.v:160`：`assign o_normal_valid = i_rstn && i_result_valid && flag_frame_normal;`
- **描述/依据**：C13:99-100明写Router o_local_empty为注册本地事实并由AMI排空聚合消费；实际Router共187行，没有时钟、always、寄存器、o_local_empty及discard输入，只有组合路由和元数据镜像。这同时与C12:61/65的纯组合/无empty寄存器条款相矛盾。
- **证据/反驳**：全Router代码及skill AST结构清单、AMI:1912-1973的完整Router实例都无此端口；AMI排空聚合可通过校准器/分支状态覆盖Router路径，因此不能把文档错误升级为排空死锁。C12明文的替代机制覆盖了功能需求，却没有让C13不存在的端口声明成立。本条不重复已知C11/C14/C15广播豁免、五组悬空输出或孤立模块事项。
- **置信度**：静态确认（合同内部冲突及不存在端口），不声称已仿真证明系统错误。
- **建议方向**：把C13的Router段改为C12定义的组合边界，或正式版本化新增状态需求，由接口所有者裁定。

### F-007：芯片合同正文仍要求两路reset_sync，与自身V1.11勘误及RTL冲突

- **严重度/层**：S3 / 合同。
- **位置及原文（3行摘录）**：
  - `contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md:101`：``| ① 复位同步 ×2 | 有 | `RESET_N`分别经`CLK_2M_PAD`域和`SPI_SCLK`域各自的`ppg_reset_sync`实例，产出`i_rstn`和`i_source_rstn` |``
  - 同合同`:25`原文片段（V1.11勘误）：

```text
已改为源域复位直接借用已在`CLK_2M_PAD`域完成同步、早于任何真实SPI活动稳定下来的`i_rstn`
```

  - `rtl/ppg_chip_digital_top/ppg_chip_digital_top.v:284`：`assign w_source_rstn = w_rstn;          // 源域复位借用已稳定的数字域释放结果`
- **描述/依据**：RTL只在:373实例化一次ppg_reset_sync（CLK_2M_PAD）；SPI域复位是w_rstn直通。合同:53/65/80/82/101却仍列两次实例和SPI_SCLK同步释放，与自身:25勘误及实际结构矛盾。
- **证据/反驳**：实际Top实例/赋值与SPI寄存器source reset连线已交叉核实；额外同步器不存在于别的SPI子模块。合同:25已经明文允许现有机制，因此本条只报告未同步的结构表/正文，不把“没有第二个同步器”认定为S1。source复位释放前SPI是否必须静止、独立reset安全等仍需按实际板级前提继续审查；历史勘误的“无亚稳态风险”措辞不是本轮签核证据。本条不是用户已知“CDC审计不属ASIC签核”的重复事项。
- **置信度**：静态确认（文档内部矛盾及实例数），无需功能仿真。
- **建议方向**：将第2/3/4/6节结构表与图同步到明确的V1.11复位政策，并明确其SPI首次时钟相对复位释放的前提。


### F-008：正式 measurement-discard 身份在 C01/C10 要求完整 TXN_ID，实际 AMI/Top 缺五个 epoch 端口

- **严重度/层**：S3 / 合同·跨层；与F-002是不同边界，F-002针对C13 overlap私有discard，本条针对AMI与Top公开正式结果discard。
- **位置及原文（3行）**：
  - `contracts/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:620`、`contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md:290`、`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:199`，依次原文：
```text
| `o_measurement_result_discard_<TXN_ID>` | each transaction field width | Complete retained transaction identity; the exact field expansion is defined in the closure matrix and stable with the event. |
| output | `o_measurement_result_discard_event` / `reason` / `identity_valid` / `sample_valid` / `<TXN_ID>` | `1/2/1/1/each field` | AMI正式结果discard公开观测；identity-valid必须为1，完整字段在事件采样沿稳定，且不产生成功transfer |
	output [C_RUN_GENERATION_WIDTH - 1:0]o_measurement_result_discard_run_generation, // 被丢弃事务所属的RUN代际
```
- **描述/依据**：矩阵§1.1的82-92行明确定义11个独立端口，118-119行明确这是正式端口名宏。AMI公开组190-199与Top公开组263-272仅有6个身份分量，缺`config_epoch/coef_epoch/dc_recovery_epoch/amb_code_epoch/dc_code_epoch`五个measurement-discard端口。Top实例1186-1195、边界1572-1581也只传实际小组；detection-discard则有完整epoch组，不能替代另一个branch。
- **证据/反驳**：复用仓库skill真实formatter AST逐端口表，保存`evidence/public_discard_port_evidence.json`；检查器先以正确11字段和人为移除三字段集合做负对照，准确返回三处缺失。完整AMI/Top声明、实例与赋值核对一致。正常measurement结果自身的epoch输出虽然存在，但正式宏要求指定discard前缀的独立端口，不能当作已存在的指定端口；本条没有把诊断字段缺失升级为功能丢弃错误。用户已知C11/C14/C15 run-generation广播豁免不涵盖C01/C10公开结果组。C01全文、C10§6.10及矩阵身份定义未找到小组替代许可。跨组C10全文后如发现显式更高优先级例外，再据原文重新裁定。
- **置信度**：静态确认（形式端口与规范扩展不一致，无需行为仿真）；没有证明默认芯片的discard执行错误。
- **建议方向**：接口owner裁定公开discard要完整诊断身份还是现有紧凑身份，同步正式端口合同与矩阵；本轮不实现。

### F-014：Supervisor 接受合同明令 elaboration 拒绝的过窄 watchdog 计数器

- 严重度/层：S3 / 合同。置信度：仿真确认非法参数被接受；静态确认缺guard。
- 位置：`contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md:41`；`rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v:192`.

```text
Elaboration shall reject `C_ADC_DRAIN_WATCHDOG_CYCLES < 1` or `C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH < $clog2(C_ADC_DRAIN_WATCHDOG_CYCLES + 1)`. `5000` cycles is a provisional one-400-Hz-frame system policy (`2.5 ms` at 2 MHz), not ADC/analog macro timing signoff.
assign flag_watchdog_timeout_fire = flag_watchdog_window_active && (cnt_adc_drain_watchdog == (C_ADC_DRAIN_WATCHDOG_CYCLES - 1));
```

- 描述与依据：C24:41要求COUNTER_WIDTH≥clog2(CYCLES+1)。实际参数及计数逻辑无guard，8拍/1bit非法配置编译被接受，计数0/1不能达到超时比较7。
- 证据：

```text
FAIL SUP06B at 350000
SUPERVISOR REGRESSION FAIL: pass=13 fail=1
```

- 反驳与范围：Icarus -g2012 -Wall编译0、运行0但实际FAIL。检查其它共享模块没有补偿合法性拒绝；Top默认5000/13合法且未给运行时CSR修改途径，不扩大为默认芯片S1。原组报告引用的合同43行已独立纠正为实际41行。非已知风格积压。
- 原始证据：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd78-55cb-7173-9e41-1e0b27c41d49\ppg_review_B\evidence\supervisor_invalid_width`。
- 建议方向：由owner裁定补elaboration参数门禁或修改参数前提。

### F-015：FIR 合同仍称 sample-valid 定向 TB 不存在

- 严重度/层：S3 / 合同。置信度：静态确认；原TB仿真支持。
- 位置：`contracts/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md:686`.

```text
确认其中不含任何`i_sample_valid`引用，未见针对该端口的定向回归
```

- 描述与依据：当前末行仍声称缺FIR-31..36专属证据、TB无i_sample_valid引用；实际TB:1011设置invalid，:1017真比较两次消费且不推进history/MAC/output，:1056/1084还有FIR-32/33，:1143接公开端口。这里只确认31..33已有实现证据，未据此宣称34..36通过。
- 证据：

```text
[PASS] FIR-31 invalid transaction consumed once without history MAC or output
[PASS] FIR-32 qualification orthogonal to sample_valid
[PASS] FIR-33 invalid gap keeps legal history continuity
```

- 反驳与范围：原48套回归中的FIR完整run.log为103 PASS、无FAIL，且已读实际激励和比较；合同末行是现时状态措辞，并非仅引用旧报告。非已知N08观察项或四份系统注入输入悬空。
- 原始证据：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_coarse_detection_fir\run.log`。
- 建议方向：更新证据状态文字，区分已实现31..33与其它待验证项。

### F-024：manager、ACTIVE wrapper、unpack 缺当前合同要求的正式参数及透传

- 严重度/层：S3 / 合同·跨层。置信度：静态确认；关联D-002，不指控默认产品宽度错误。
- 位置：`contracts/ppg_system_config_manager_semantic_contract.md:37`、`contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:63`、`contracts/ppg_system_active_config_unpack_semantic_contract.md:26`，原文3行：
```text
The manager module shall declare and expose the following parameters. Every
| `C_CONFIG_WIDTH` | 1024 | exactly 1024 | Passed unchanged to `ppg_config_cdc_bridge`, manager and unpacker; any mismatch is an elaboration error. |
| `C_CONFIG_WIDTH` | 1024 | exactly 1024 | Must equal Top, ACTIVE wrapper, manager and configuration-CDC width; no implicit pack, truncate or extension is permitted. |
```
- 描述/依据：C02:43-50要求8正式参数，实际manager:54-58只有CONFIG_WIDTH与RUN_GENERATION_WIDTH，余6项不声明、epoch端口固定8bit；C03:63-65要求3参数，wrapper:49-50无参数表，generation固定8bit，379只显式传常数1024给bridge，392/429调用manager/unpack无参数传递；C05:26要求CONFIG_WIDTH，unpack:47-50无参数表、输入固定1024bit。C02:52-55所述Top一路透传每个参数及拒绝不匹配路径不存在。
- 证据/反驳：完整实际模块参数声明与实例、仓库skill canonical AST均核对；AST的parameter_count可包含localparam，未把计数当正式接口。默认1024/8产品连接一致，未把非法/非默认宽度问题升级为默认功能S1；当前V4.9/V1.6正式页眉没有缺参数豁免，旧历史冻结不能替代。不是已接受VG风格问题或chip层没有验收ID的问题。无需行为仿真，事实是正式接口缺失。
- 建议方向：设计owner统一实际允许的参数、透传及拒绝检查，或明确冻结产品固定值。

### F-030：SPI CS_N 两级同步规范与实际原始片选异步复位不一致

- 严重度/层：S3 / 合同·跨层；置信度：静态确认规范/实现矛盾，不据此声称物理CDC故障。关联D-007。
- 位置：`contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md:128`（句片段）、chip RTL:385与SPI RTL:432，原文3行：
```text
`CS_N`仍需过标准两级同步器，但只用于门控/复位比特计数器，不用于推导任何离散事件的触发时刻
.i_spi_cs_n(SPI_CS_N),
always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
```
- 描述/依据：chip直接连接pad；SPI全部CS_N使用在372/413/432/447/458/472/481等异步清零及电平门控，没有标准两级CS_N同步链。事件仍由完整字节生成，不能使同步要求成立。
- 反驳/证据：已读chip/SPI全文件、全部CS_N使用和合同勘误。reset_sync处理RSTN、ADC idle同步处理ADC idle，均不处理CS。V1.11仅豁免SPI独立复位同步，V1.15只改诊断快照，未修订CS条款；F-007为RSTN文档冲突，F-005为读位功能，不重复。不是user接受的ASIC CDC签核限制。本项无需仿真来证明没有声明/连线，不要求机械添加两拍改变SPI协议。
- 建议方向：由接口owner明确CS_N异步协议约束或同步方案，同步冻结合同。

### F-032：IDAC 冻结诊断清除端口名与实际叶子接口不一致

- 严重度/层：S3 / 合同；置信度：静态确认。关联C-006。
- 位置：`contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:159`、IDAC RTL:75、AMI RTL:2327，原文3行：
```text
input i_diag_clear_event,
input i_status_clear_event,
.i_status_clear_event(i_diag_clear_event),
```
- 描述/依据：C17:137明确名称、方向、位宽必须与原型一致，原型写diag_clear，实际叶子用status_clear；TB:786和生产AMI均绑定实际旧名。按冻结原型具名实例化将无法elaborate。
- 反驳/证据：全局单一diag事件在AMI映射给叶子的status端口，清除路径存在且原TB有真实比较，故不报清除功能失效；来源映射不能使同一合同原型名与叶子声明一致。已核对合同现行版本行3及诊断正文、RTL声明/使用和生产连线；不属于注释style积压，也不同于F-024参数原型与其他discard合同事项。
- 建议方向：由接口owner统一冻结原型名称和AMI来源映射说明。

### F-033：IDAC 合同禁止不改 AMB 码时重验，与冻结依赖及实际三阶段相反

- 严重度/层：S3 / 合同；置信度：静态确认，原始148 PASS日志及真实比较支持实际行为。关联C-007。
- 位置：`contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:503`、`contracts/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md:487`、IDAC RTL:794，原文3行：
```text
AMB码未实际改变时不得产生`o_dcs_revalidate_request`。该request为电平握手，不得实现为可能丢失的单拍。
周期AMB阶段成功后，只要DCS使能，无论AMB committed码是否实际改变，都必须执行：
state_next = ST_DCS_REVALIDATE_WAIT;
```
- 描述/依据：C17当前规范行3为V2.3，其依赖表:18明确依赖C16 V2.1；C17§8.3/8.4及IDC2-17:670仍要求AMB不改码不请求DCS，C16§9.6却要求DCS启用时无论AMB是否改码均执行固定AMB/R/IR三阶段，两条规范不可同时满足。
- 反驳/证据：实际IDAC在ST_AMB_RECHECK合格且DCS启用时直接转重验等待；TB:371送不改码的合格样本，:377真实比较unchanged AMB仍产生请求，:568执行固定周期场景。C16现行修订及RRC-05三阶段义务已交叉核对；故将C17滞后文字报S3，不把实际无条件重验当RTL错误。不是旧33失败、generation悬空或已知tick-248事项。
- 建议方向：同步C17正文与IDC2-17，使依赖、验收表和固定三阶段义务一致。

### F-039：表征控制合同复位后的 START 前提与自身模式例外矛盾

- 严重度/层：S3 / 合同；置信度：静态确认。关联D-008。
- 位置：`contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md:210,249,295`，原文3行：
```text
进入STATIC_BIAS RUN之前，`o_control_valid`必须已经为1、已提交使能位必须为1，且source侧必须等到对应传输应答返回后才允许发起START。NORMAL和外部固定电流RUN可以使用复位后的安全默认值`static_characterization_enable=0`、`test_mux_ctrl=5'b0`，不要求预先提交测试控制。
NORMAL和外部固定电流START不以`o_control_valid`为硬门槛，但必须继续使用本合同规定的安全默认值或最近一笔合法提交值。
复位断言必须取消所有在途CDC事务，复位释放不得产生伪提交或伪拒绝事件。复位后必须重新完成至少一笔合法6-bit提交，才能允许新的START。
```
- 描述/依据：同一现行正文§9/10允许NORMAL和外部固定电流以复位安全默认控制启动，§11不限定模式又要求所有新START先做6-bit提交；版本勘误没有覆盖该冲突。
- 反驳/证据：STATIC_BIAS确有valid1/enable1前提，本项不否认；Top:851/853区分已提交enable/valid，:746给manager的资格不将ccc_valid作为NORMAL/固定电流硬门控。D固定电流未变异短场景无6-bit提交、直接V4/V5 COMMIT/START后真实RED/IR各3笔支持实现选择。共同复位:297解决toggle代际不解决模式矛盾。F-007复位架构及已知N04/P2S事项不同。
- 建议方向：明确§11前提的模式范围；若要求所有模式重提，应由设计方裁定并统一其他条款。

### F-043：C18 窗口长度配置的直接消费者写成了 PWC

- 严重度/层：S3 / 合同；置信度：静态确认。关联B-017。
- 位置：`contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:201`、PWI RTL:842/843，原文3行：
```text
| `i_max_fine_window_frames`, `i_max_reacquire_frames` | precision controller | The limits are stable configuration values; the separate valid gate prohibits formal fine-window control and 9-to-15 requests when low. |
.i_max_fine_window_frames(i_max_fine_window_frames),
.i_max_reacquire_frames(i_max_reacquire_frames),
```
- 描述/依据：表196明文为直接子模块消费者；实际两输入只送803开始的PVW实例，PWC声明60-156没有这两端口。窗口计数/超时由PVW拥有，PWC依据返回请求做安全精度提交。
- 反驳/证据：全PWI例化和PWC/PVW公开端口已查；配置未丢失，不报RTL功能错误。“间接影响精度”不能使直接消费者表成立。C23未要求PWC另收两字段，C18其他职责段落也指PVW。非F-003引用偏移，行201本身语义错。
- 建议方向：统一直接消费者与真实窗口/返回/精度提交所有权。

### F-045：矩阵现行26文件完整性摘要有23项与固定版本字节不符

- 严重度/层：S3 / 矩阵·台账。
- 位置：`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:1226-1232`定义当前完整文件摘要及失效规则；`:1236-1261`现行清单。原文（3行，分别为:1226、:1231、:1232）：
```text
The 25 contract digests are full-file SHA-256 digests of their active paths.
not closure evidence; any later change to an active file invalidates this
baseline until the manifest is regenerated.
```
- 描述/依据：25合同中仅C04、C05、C21的full-file SHA256匹配；其余22份及按本节规定将自身摘要字段替换为`<SELF_SHA256>`后的M01均不符，共23项。清单明确是active paths现行完整性基线，不能用这些摘要鉴别本次实际文件。
- 证据：`evidence/manifest_audit_A.json`逐项保留登记摘要、实际摘要和源行。C01(:1236)登记`620b671493546aa45b86354d09703f4141c325940b5e7a2cf84b3c832e14f395`，实际`39c747617ff7da2997c1bfc1e14aaf5c41d38056fba2eb662d4ef13d2ddd299e`；C09(:1244)登记`425b896e22b87f84f748829b5d4ac483a50b755668958e12f13610a1c0e973ee`，实际`658fc3c56721a27db369a93057317fd44ebbd4b6bcef6da807dade6a9451451d`。PowerShell Get-FileHash独立核对上述两项相同。26份文件逐个经git cat-file的固定提交原始blob核对，均与导出字节完全一致，排除autocrlf/编码转换。M01登记和实际值见同表。
- 反驳：矩阵:1191-1194明确排除historical lists/baseline copies；:1231-1232明文后续改动使该baseline失效。M01已按其自归一化算法核对，没有拿未经归一化的自摘要制造差异。用户已知§13.1旧ID数量与G-FP独立复核范围没有说明§12.4a现行摘要已接受失效；也非F-003行号引用问题。没有据此认定RTL被篡改或功能错误。
- 置信度：静态确认。脚本先验证正常项、字节改动、错误摘要、缺文件恰好输出三项已知错误；另验证自摘要字段变化被忽略而其他文字变化被检出，详manifest_negative_controls.json。
- 建议方向：重新生成当前完整性清单并独立比对原始Git字节，同时保留旧摘要为历史。

### F-046：合同与TB的同号验收场景存在语义错位

- 严重度/层：S3 / 跨层。
- 位置：C08 `contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md:1135,1146,1149,1166-1167`；scheduler TB `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:564,581,592,708,724`。C24 `contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md:160-161`与supervisor TB `rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v:464-488`。原文（3行，分别为C08:1135、scheduler TB:564、C24:161）：
```text
| FSC-03 | 400 Hz周期 | 相邻宏帧起点严格相差5000个2 MHz周期 |
		check_fsc(3, (cnt_frame_start == 0) && (o_next_sample_index == 0) && !o_transaction_inflight);
| SUP-10 | A single fault-discard event is retained as an AMI-local current-generation reason until terminal digital drain, so delayed discardable work remains `DISCARD_SYSTEM_FAULT` without a repeated supervisor pulse. | `EVIDENCE_PENDING` |
```
- 描述：合同FSC-03是严格5000拍周期，TB同号却比较启动前frame/owner/索引为空；周期检查实际在FSC-14，而合同FSC-14是DCS_CAL RED。FSC-17要求校准资格/请求保持，TB同号比较RED-only owner数；FSC-34/35合同分别随机反压/长期无漂移，TB同号分别失败完成不计正常结果/STOP释放。SUP-09合同区分fault-discard与外部abort，TB同号是阈值前真实idle；SUP-10合同是AMI延迟discard reason保持，TB同号是清历史后第二episode。仅找到相同ID字符串不能证明该冻结需求被验证。
- 证据/反驳：A重新核对原定义、check_fsc数值派发及前后激励，来源B-018，逐ID索引在B evidence/id_four_link_audit.json。FSC-58/59确有真实资格检查，SUP其他case也确有fault-discard比较；不声称这些行为在项目中完全未测。F-011已单列周期容差过弱，F-012已单列历史未清rearm缺口，本条只汇总同号语义错位，不重复算缺失功能，也不是F-003失效行号。未见合同允许重用同一编号表达另一验收义务。
- 置信度：静态确认；本条为编号映射事实，无需新增行为仿真。
- 建议方向：将现有有效检查按冻结需求重新映射，并明列其他case/文件提供的替代证据。

### F-047：SSW最新修订与唯一规范版本声明的承接关系不明确

- 严重度/层：S3 / 合同。
- 位置：`contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md:3,7,403,430-438`；矩阵`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:1206,1244,1267-1280`及八份现行C09依赖表。原文（2行，C09:3、:7）：
```text
> V1.10修订日期：2026-09-10。AMB_CAL单相积分改造：`ppg_sar9_sar15_safe_selection_wrapper.v`V1.5起，AMB_CAL（`reg_cal_frame_type==FRAME_TYPE_AMB`）期间`CTRL_Q2`（`o_clk_q2_low`）不再产生`[262,264)`脉冲，全程保持`0`；`CTRL_Q3`（`o_clk_q3_low`）在`[265,267)`的既有窗口完全不变，DCS_CAL的Q2/Q3行为也完全不变。详见第6.4节。第6.1节数字控制窗口表和第5.5节暗态采样描述已同步更新为该真实行为；不改变本合同SSW-01至SSW-52任何既有编号条款的行为定义本身，只改变AMB_CAL一种帧类型下CTRL_Q2这一项输出的实际取值。真实依据、根因和影响范围见第6.4节。
> Normative status: V1.9 is the sole current SSW interface and lifecycle authority (V1.9 is additive over V1.8, see the 2026-08-30 change record above). Earlier V1.3.x-V1.7 status and historical regression wording cannot classify missing joint implementation evidence as a contract-interface defect.
```
- 描述：文件以V1.10记录真实AMB单相Q2取值修订，正文:403/434也采用该行为，但:7仍称V1.9为唯一现行接口/生命周期权威。矩阵版本列仍V1.9，却按C09:3取目标header并称141/141当前header版本匹配。A核对141绑定，八处C09登记V1.9与第3行V1.10不同（C01:101、C03:28、C06:37、C07:40、C08:59、C10:63、C24:17、C25:127）。当前基础标签与增量修订的关系没有像C01:20那样明文澄清。
- 证据：dependency_audit_A.json全141项源声明/目标header，真实差异恰好上述八条，其余133条header比对一致。中文紧邻版本、句尾标点正例与错版本/缺路径负例均通过后才采信结果；各源声明的实际文字逐条读取。C09六条依赖声明行引用文字漂移另并入F-003，不重复编号。
- 反驳：C09:7本身明文允许把V1.9视为基础规范，所以本条没有认定八处V1.9绑定非法，也不把SSW AMB改造作为新的功能错误。C01的V1.11~17已被明确解释为保留V1.10标签的errata，不能泛化为所有文件自动具备相同解释。用户已知SSW V1.5单相改造不等于接受此版本元数据矛盾。此条缩窄B-019“只有三处依赖错误”的表达，按全量八处差异记录文档承接问题。
- 置信度：静态确认（元数据和文字事实）；V1.10是否应升级规范标签由合同维护者裁定。
- 建议方向：明确保留V1.9基础标签并声明V1.10为勘误，或将唯一规范升级V1.10后同步八处依赖及矩阵。

### F-048：Top 诊断清除的排他消费者名单漏掉表征 CDC

- 严重度：S3；层：合同；置信度：静态确认。
- 位置与原文：
`contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md:365`
> diagnostic-clear source and fans it unchanged only to the direct diagnostic
`contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md:366`
> consumers AMI, Scheduler, SSW and supervisor. AMI/PWI forward that same event
`rtl/ppg_control_top/ppg_control_top.v:849`
> .i_diag_clear_event(flag_diag_clear_event),               // 接表征CDC.i_diag_clear_event：系统域诊断清除脉冲，只影响sticky状态

- 描述：C01 §4.1 明确写 only 并列四个直接消费者，但其 §5.2 的端口连接表（526）要求表征 CDC 也接顶层诊断清除，当前 RTL 正是同一注册事件的第五路扇出。两个规范条款不能同时按字面满足。
- 证据与反驳：(a) C07:113、315 明确规定该输入和 sticky 清除，CCC RTL:184-190 实现了新错优先及清除；因此第五路不是多余功能或真实 RTL 错误。(b) 此问题不在用户第4节的已知事项；矩阵:1334 已明确记载“only”名单与 §5.2/RTL 不一致，独立核实确认该注记尚未落实到被审 C01，不把它说成此前从未有人记录。(c) 同份 C01:526 明文要求第五路，排除将其视为合同允许的四路排他名单。Top:321 注释也仍只列四路。无需仿真来确认文档自身矛盾，未把清除功能判为失败。
- 建议方向：统一 C01 §4.1、§5.2 与 Top 清除消费者注释，保留或调整第五路由合同所有者裁定。

### F-050：别名表仍把现有 SID-11 注入场景列为结构不可达的 SKIP

- 严重度：S3；层：矩阵·台账；置信度：静态确认（文档及代码存在事实）。
- 位置与原文：
`contracts/PPG_ALIAS_MAPPING_TABLE.md:148`
> | SID-11 (延期,结构性不可达) | `tb_ppg_control_top_startup_idac_calibration.v` (标记SKIP非PASS) | `ppg_adc_s1_programmable_calibrator.v:232-233` (`flag_saturation_low`/`flag_saturation_high`互斥,双饱和数学不可达) | [[project-ppg-stage5-batching-plan]] |
`contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:559`
> | SID-11 | A double-saturated or otherwise ineligible sample cannot advance search evidence and must produce the specified protocol diagnostic; no replacement result may be fabricated. |
`rtl/ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v:1033`
> i_test_saturation_inject_valid = 1'b1;

- 描述：当前别名行将SID-11写成“SKIP非PASS”，引用数值校准器两方向饱和互斥作为永远无法构造的理由；当前TB阶段B2却已在一笔真实Q3/RAW事务上通过公开专用饱和注入口构造双饱和，1044-1055真正检查fire出现、AMB码不推进和无硬故障，再条件打印PASS SID-11。该行没有标历史或删除线，当前表内状态及锚点都未跟随新的测试边界。
- 反驳：(a) 数值校准器本身确实互斥，但AMI的专用注入口在身份匹配后的搜索评价支路注入，并不要求数值校准器天然同时产生两位；Top TB覆盖参数打开并驱动公开输入，不使用Verilog force。(b) 用户第4节未将SID-11旧延期登记列为已知项，和已知SID-05/tick248截止错误不同。(c) C10/C01/C25允许专用受保护注入；C25仍定义SID-11义务，别名:481也引用SID-10/SID-11作为N05证据，与:148长期SKIP自身矛盾。已检查本表全570行，没有后文把:148标成历史或明确改为现行公开注入场景。
- 证据限度：本条只确认“被审版本已有实际激励和真实比較分支，旧结构不可达理由失效”；当前完整SID原回归尚在队列/执行中，未据TB自己的PASS文本、changelog或旧报告声称本次已通过。动态终态将归入§6。
- 建议方向：将SID-11别名改为当前公开注入场景及对应AMI入口，明确其本次回归实际结果。

### F-051：Supervisor规范复位端口名与真实模块接口不一致

- 严重度/层：S3 / 合同；置信度：静态确认。
- 位置：`contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md:56`、`rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v:60`、`rtl/ppg_control_top/ppg_control_top.v:1393`；引用原文3行：
```text
| `i_rstn_2m` | 1 | Top reset boundary | Active-low system reset. |
input i_rstn,                               // 低有效异步复位输入
.i_rstn(i_rstn),                                      // 接supervisor.i_rstn：低有效异步复位输入（.I_RSTN）（专属标识一）
```
- 描述/依据：当前规范C24§2名为Complete Supervisor Port Contract，将复位输入列作`i_rstn_2m`；实际叶子只声明`i_rstn`，Top也按该真实端口连线。此处是冻结接口名不一致，不能由表中名称直接生成正确实例。
- 证据与反驳：当前C24全文仅第56行出现该复位名，没有声明它是允许的叶子端口别名；C01 Top实际端口为`i_rstn`（Top RTL:99），芯片层实际连Top为`.i_rstn(w_rstn)`（chip RTL:501）。矩阵:3068一边登记真实`i_rstn`，一边转述合同的`i_rstn_2m`，不能消解此矛盾。规范Erie AST独立确认52个实际端口中存在`i_rstn`且没有`i_rstn_2m`；这不是五组悬空输出、CDC审计等级或既有F032的IDAC清除端口问题，不属第4节接受事项。代码事实明确，无需功能仿真；不据此声称存在硬件复位缺陷。
- 建议方向：统一C24冻结端口名与真实接口，或由设计者明确写出且限定逻辑别名映射。

## 4. 已知事项状态核实

已确认1条“已知事项状态有误”（K-001，S3），单独列于本节，不计入50条确认新发现。下列其余已核实内容按用户已知事项排除；其余风险保留于逐文件台账，未自动转为新发现。

| 已知事项 | 固定版本所见 / 本轮处理 |
|---|---|
| tick-248 / scheduler V1.9 | 基准为V1.8，未包含V1.9修复；边界问题仍按用户已知项，不重复编号 |
| P2S三遥测反压错拍及前提订正 | 本基准未包含所述后续合同/断言订正，按进行中事项；packer局部正确不抵消AMI错拍，不新增原问题 |
| RTL风格门禁、pad例外 | 芯片30 RTL本次strict计数77，其中VG010=46/VG031=1；规则版本/口径与约222不同不构成状态错误。全部37规则计数见§7，不逐条列风格 |
| PRC-04 / TRK-01 / N08 / N04 / P10 | 按接受策略、结构或观察项处理；新F-016/017是其他PRC监视器问题，F-013为独立CCC-22，不重报原接受项 |
| C11/C14/C15 generation discard豁免 | START需empty及叶子valid父链已交叉核对，保留有条件豁免；F-002/004/008为不同接口/文档事实 |
| SSW cause22 D03、五组悬空输出 | 按模拟前提冻结及glue-top设计处理；新F-035是匹配完成被吞，cause21为实际恢复结果，不使用D03情景 |
| SPI38字节原TB只回读3字节 | 不重复报覆盖数量；本轮逐项静态核对38读字节/全部shadow及写副作用，独立物理读探针确认F-005 |
| 芯片层无验收ID/G-FP台账、七孤立模块 | 保持既有架构范围与处置未定；七孤立RTL及四对应TB已审内部行为，不赋予正式集成资格 |
| §13.1旧快照、G-FP其余批次未独立复核、旧CDC/锁存/X审计 | 不作为现行完整签核；本轮机械候选与逐文件语义限度单列，未把旧快照数量变化重复编号 |
| Top q3修订记录 / _tmp_v13_filelist.f /旧本机路径指南 | 保留用户已知注释/遗留文件状态，不新增风格发现；legacy明确退役两TB排除 |

### K-001：PWC START不清sticky的已知修复未同步G-FP优先级台账

- 严重度／层／置信度：S3／矩阵·台账／静态确认，已执行原模块级仿真旁证。
- 位置及原文：`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:3408`：“`i_start_ack_event` -> `protocol_error_sticky_o <= flag_protocol_error_event`”；同一行仍称START是“first-priority”重评触发。
- 当前事实：`rtl/ppg_precision_window_controller/ppg_precision_window_controller.v:506`为`end else if(i_diag_clear_event == 1'b1)begin`，507行为`protocol_error_sticky_o <= 1'b0;`；511行为`protocol_error_sticky_o <= protocol_error_sticky_o;`。实际sticky过程没有START清除分支。`contracts/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md:954`／PWC-41明确“新合法START本身不清…只有`i_diag_clear_event`或复位可以清”。
- 反驳：RTL675-676的`flag_fault_hold`确实在START重评，但它是另一寄存器，不能为sticky台账文字辩护；别名表406已记录当前PWC-41规则，因此不是修复缺失。本条只报用户已知09-17修复对应的台账状态错误，不重复上报RTL缺陷。
- 实际原TB关键输出（`evidence/compile/tb_ppg_precision_window_controller/run.log`）：`PASS PWC-41 new legal START preserves protocol sticky`；`PASS PWC-41 new legal START preserves switch-timeout sticky`；`PWC-01 through PWC-41 ALL PASS pass=48 fail=0`。
- 建议方向：同步G-FP-03的sticky清除/优先级文字，并继续区分fault_hold与历史sticky；未实施修复。完整原行、日志SHA及跨文件反驳见`global_closure_20261004/known_status_error_K001_A.json`。

## 5. 覆盖台账

| 文件 | 层 | 行数 | 状态 | 已做检查 / 剩余 |
|---|---|---:|---|---|
| contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md | 合同 | 1252 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；B组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md | 合同 | 644 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；D组逐项台账（2026-10-04b读取）：完成2项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md | 合同 | 343 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；D组逐项台账（2026-10-04b读取）：完成2项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md | 合同 | 623 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ADC_IDAC_INTEGRATION_SPEC.md | 合同 | 494 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；B组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md | 合同 | 1337 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；B组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md | 合同 | 346 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md | 合同 | 157 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；全文实读；overlap/Router正式端口矛盾F-002/F-004；生命周期全行为未仿真；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md | 合同 | 205 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；全文实读并对Router及AMI连接；其余upstream完整身份条款仍待核；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md | 合同 | 405 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_ALIAS_MAPPING_TABLE.md | 合同 | 570 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；关键章节/identity定义/K条目/C01/C13台账抽读；全引用出现性+边界扫描，F-003；未全量语义核实；A组逐项台账（2026-10-04b读取）：完成2项，部分3项；剩余：RTL逐条一致性：838候选四链、46家族语义抽查、1860端口行名称方向（含十权重展开）、516声明锚点、1860个单独Source、141版本绑定/26摘要及367标签关联已核对；Source待办0、C03两处歧义已裁定。799显式默认位宽/41明示符号属性及4个参数组人工核对、6个缺文件候选已裁定。范围限度：非Source缺省文件名/bounds-only引用未全部逐字语义核实，未重建G-FP全部cluster逐字段项目签核或ASIC CDC；这些不能记通过。F044入口范围为疑似，4份原长回归终态未齐。F003/F024/F045/F046/F048/F050/F051保留。；验收ID闭环：838候选四链、46家族语义抽查、1860端口行名称方向（含十权重展开）、516声明锚点、1860个单独Source、141版本绑定/26摘要及367标签关联已核对；Source待办0、C03两处歧义已裁定。799显式默认位宽/41明示符号属性及4个参数组人工核对、6个缺文件候选已裁定。范围限度：非Source缺省文件名/bounds-only引用未全部逐字语义核实，未重建G-FP全部cluster逐字段项目签核或ASIC CDC；这些不能记通过。F044入口范围为疑似，4份原长回归终态未齐。F003/F024/F045/F046/F048/F050/F051保留。；节号/行号引用：838候选四链、46家族语义抽查、1860端口行名称方向（含十权重展开）、516声明锚点、1860个单独Source、141版本绑定/26摘要及367标签关联已核对；Source待办0、C03两处歧义已裁定。799显式默认位宽/41明示符号属性及4个参数组人工核对、6个缺文件候选已裁定。范围限度：非Source缺省文件名/bounds-only引用未全部逐字语义核实，未重建G-FP全部cluster逐字段项目签核或ASIC CDC；这些不能记通过。F044入口范围为疑似，4份原长回归终态未齐。F003/F024/F045/F046/F048/F050/F051保留。 |
| contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md | 合同 | 408 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；D组逐项台账（2026-10-04b读取）：完成2项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md | 合同 | 466 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；D组逐项台账（2026-10-04b读取）：完成2项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md | 合同 | 309 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；SPI协议/38读字节+写方向地图逐项静态核对；关键CDC/P2S段实读；历史长段/全合同未审；复位结构表与本合同V1.11勘误/实际Top矛盾F-007；翻转位偶数事件能力待续核；D组逐项台账（2026-10-04b读取）：完成2项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md | 合同 | 686 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；注入/检测资格相关条款实读，F-001；其余全文未审；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_CONTRACT_CLOSURE_MATRIX.md | 合同 | 3920 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；关键章节/identity定义/K条目/C01/C13台账抽读；全引用出现性+边界扫描，F-003；未全量语义核实；A组逐项台账（2026-10-04b读取）：完成2项，部分3项；剩余：RTL逐条一致性：838候选四链、46家族语义抽查、1860端口行名称方向（含十权重展开）、516声明锚点、1860个单独Source、141版本绑定/26摘要及367标签关联已核对；Source待办0、C03两处歧义已裁定。799显式默认位宽/41明示符号属性及4个参数组人工核对、6个缺文件候选已裁定。范围限度：非Source缺省文件名/bounds-only引用未全部逐字语义核实，未重建G-FP全部cluster逐字段项目签核或ASIC CDC；这些不能记通过。F044入口范围为疑似，4份原长回归终态未齐。F003/F024/F045/F046/F048/F050/F051保留。；验收ID闭环：838候选四链、46家族语义抽查、1860端口行名称方向（含十权重展开）、516声明锚点、1860个单独Source、141版本绑定/26摘要及367标签关联已核对；Source待办0、C03两处歧义已裁定。799显式默认位宽/41明示符号属性及4个参数组人工核对、6个缺文件候选已裁定。范围限度：非Source缺省文件名/bounds-only引用未全部逐字语义核实，未重建G-FP全部cluster逐字段项目签核或ASIC CDC；这些不能记通过。F044入口范围为疑似，4份原长回归终态未齐。F003/F024/F045/F046/F048/F050/F051保留。；节号/行号引用：838候选四链、46家族语义抽查、1860端口行名称方向（含十权重展开）、516声明锚点、1860个单独Source、141版本绑定/26摘要及367标签关联已核对；Source待办0、C03两处歧义已裁定。799显式默认位宽/41明示符号属性及4个参数组人工核对、6个缺文件候选已裁定。范围限度：非Source缺省文件名/bounds-only引用未全部逐字语义核实，未重建G-FP全部cluster逐字段项目签核或ASIC CDC；这些不能记通过。F044入口范围为疑似，4份原长回归终态未齐。F003/F024/F045/F046/F048/F050/F051保留。 |
| contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md | 合同 | 954 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；注入/检测资格相关条款实读，F-001；其余全文未审；A 2026-10-04：6直接子模块、注册STOP/abort/clear、STATIC许可拆分、物理idle同源、owner/deadline/complete扇出、全部结果/模拟输出、注入/遥测边界实读核对；formal measurement discard五epoch缺口F-008；A组逐项台账（2026-10-04b读取）：完成5项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md | 合同 | 666 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md | 合同 | 966 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；C组逐项台账（2026-10-04b读取）：完成1项，部分1项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：合同版本/依赖/逐条验收ID裁定：正文与C相关源码已审；同版本完整系统或其它主责家族动态闭环未完成，逐ID保留部分 |
| contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md | 合同 | 717 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md | 合同 | 382 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；A组逐项台账（2026-10-04b读取）：完成5项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md | 合同 | 716 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；B组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md | 合同 | 900 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md | 合同 | 1029 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；B组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md | 合同 | 690 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；B组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md | 合同 | 975 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；C组逐项台账（2026-10-04b读取）：完成1项，部分1项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：合同版本/依赖/逐条验收ID裁定：正文与C相关源码已审；同版本完整系统或其它主责家族动态闭环未完成，逐ID保留部分 |
| contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md | 合同 | 918 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；B组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md | 合同 | 430 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；B组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/ppg_system_active_config_unpack_semantic_contract.md | 合同 | 117 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；D组逐项台账（2026-10-04b读取）：完成2项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/ppg_system_config_manager_semantic_contract.md | 合同 | 395 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；D组逐项台账（2026-10-04b读取）：完成2项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md | 合同 | 161 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；B组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| contracts/TAPEOUT_FINAL_REVIEW_GUIDE.md | 合同 | 71 | 完成 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；全文实读；外部路径/过时数字按用户已知背景登记，不当权威；A组逐项台账（2026-10-04b读取）：完成5项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v | RTL | 884 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；重点读V1.8 deadline/owner/DONE身份比较；sample-index比较变异触发FSC-32 FAIL；全部FSM仍待审；B组逐项台账（2026-10-04b读取）：完成4项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v | TB | 936 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=ALL FSC-01 THROUGH FSC-59 PASSED；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_active_v4_control_plane_integration/ppg_active_v4_control_plane_integration.v | RTL | 500 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v | TB | 889 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；D组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=ALL AV4C-01 THROUGH AV4C-22 PASSED；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_adc_async_stage_capture/ppg_adc_async_stage_capture.v | RTL | 236 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_adc_async_stage_capture/tb_ppg_adc_async_stage_capture.v | TB | 363 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS ppg_adc_async_stage_capture explicit-frame checks；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_adc_dc_recovery/ppg_adc_dc_recovery.v | RTL | 371 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_adc_dc_recovery/tb_ppg_adc_dc_recovery.v | TB | 475 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS ppg_adc_dc_recovery DCR-01..DCR-22；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v | RTL | 2681 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；抽读注入透传、Router/overlap实例、private discard、输出资格消费链；owner/截止/完成释放全协议仍待审；B组逐项台账（2026-10-04b读取）：完成4项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v | TB | 1642 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=AMI-01 through AMI-47 plus N08-01 PASS: 48 real comparisons；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v | RTL | 449 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；主要代码实读：S2冗余/固定Q16/饱和/缓存/复位/generation discard；C13完整身份差异F-002；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_adc_pipeline_overlap_corrector/tb_ppg_adc_pipeline_overlap_corrector.v | TB | 804 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS ppg_adc_pipeline_overlap_corrector OVL-01..OVL-17 and 1024-code sweep；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_adc_programmable_reconstructor/ppg_adc_programmable_reconstructor.v | RTL | 352 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；主要代码实读：signed中心化/增益乘法宽度/Q17对称舍入/15bit饱和/精度资格/缓存复位；中心值变异触发1042条FAIL；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v | TB | 415 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS ppg_adc_programmable_reconstructor PR-01..PR-14 and 1024-code sweep；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_adc_result_router/ppg_adc_result_router.v | RTL | 187 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码+C12全文/C13主要边界核对：纯组合、one-hot类别、非法类别消费、复位门控；复位变异触发FAIL；F-004；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_adc_result_router/tb_ppg_adc_result_router.v | TB | 516 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS ppg_adc_result_router RTR-01..RTR-13；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_adc_s1_programmable_calibrator/ppg_adc_s1_programmable_calibrator.v | RTL | 310 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；代码实读：33bit最坏累加范围/Q16对称舍入/12bit饱和/载荷保持/复位；移除offset变异触发1036条FAIL；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_adc_s1_programmable_calibrator/tb_ppg_adc_s1_programmable_calibrator.v | TB | 681 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS ppg_adc_s1_programmable_calibrator CAL-01..CAL-17；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_adc_s1_redundancy_corrector/ppg_adc_s1_redundancy_corrector.v | RTL | 314 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；代码实读：-4..515 signed11/钳位/上下文握手/保持/复位；符号反转变异触发1031条FAIL；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_adc_s1_redundancy_corrector/tb_ppg_adc_s1_redundancy_corrector.v | TB | 577 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS ppg_adc_s1_redundancy_corrector integrated exhaustive checks；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v | RTL | 374 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；B组逐项台账（2026-10-04b读取）：完成4项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_amb_recheck_scheduler/tb_ppg_amb_recheck_scheduler.v | TB | 655 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS: ppg_amb_recheck_scheduler completed scheduler regression；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_characterization_control_cdc/ppg_characterization_control_cdc.v | RTL | 222 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v | TB | 497 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；D组逐项台账（2026-10-04b读取）：完成2项，部分1项；Icarus原TB当前状态：finished; rc=0；最终横幅=ALL CCC-01 TO CCC-26 PASS (26 checks)；剩余：技能静态门禁/真实编译：真实Icarus编译/运行见A固定版原始证据；TB风格豁免，不计新S4；toolchain未请求；comment scanned_files=0不作全文扫描通过证据；formatter静态compile/AST失败，未绕过或记通过：['> ERR: [Python] only single module sources are currently supported.'] |
| rtl/ppg_chip_digital_top/ppg_chip_digital_top.v | RTL | 667 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；抽读SPI pad直连/源域复位/实际层次；芯片原TB与采样时刻变异A/B；全部顶层端口仍待审；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_chip_digital_top/tb_ppg_chip_digital_top.v | TB | 893 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；SPI采样任务实读，真实边沿副本3个FAIL，F-006；P2S和其他任务未全文审；D组逐项台账（2026-10-04b读取）：完成2项，部分1项；Icarus原TB当前状态：finished; rc=0；最终横幅=TB_CHIP_DIGITAL_TOP_PASS all scenarios passed；剩余：技能静态门禁/真实编译：真实Icarus编译/运行见A固定版原始证据；TB风格豁免，不计新S4；toolchain未请求；comment scanned_files=0不作全文扫描通过证据；formatter静态compile/AST失败，未绕过或记通过：['> ERR: [Python] only single module sources are currently supported.'] |
| rtl/ppg_coarse_detection_fir/ppg_coarse_detection_fir.v | RTL | 768 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_coarse_detection_fir/tb_ppg_coarse_detection_fir.v | TB | 1191 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PPG_COARSE_DETECTION_FIR_V2_TB_PASS pass=103；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_config_cdc_bridge/ppg_config_cdc_bridge.v | RTL | 192 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码实读：req/ack toggle、稳定总线邮箱、busy拒绝、两域同步链与复位；ASIC约束/独立复位未签核；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/ppg_control_top.v | RTL | 1606 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；抽读注入参数/端口/AMI连线、SPI telemetry、ADC idle链；全端口/复位/owner协议仍待审；A 2026-10-04：6直接子模块、注册STOP/abort/clear、STATIC许可拆分、物理idle同源、owner/deadline/complete扇出、全部结果/模拟输出、注入/遥测边界实读核对；formal measurement discard五epoch缺口F-008；A组逐项台账（2026-10-04b读取）：完成10项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_diag_algo_probe.v | TB | 934 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；外部wall-clock上限截断，rc=124，回归未完成，不能裁定RTL/TB自身超时；A：全部有效代码实读，真实比较/输入驱动/注入参数/watchdog/结束/容差/硬编码核对；robust监视器最小A/B揭示F-016/017；smoke原71 PASS。其他长TB仍等待完整回归。；A组逐项台账（2026-10-04b读取）：完成7项；Icarus原TB当前状态：finished; rc=0；最终横幅=LONGRUN_TB_PASS real_red=1200 real_ir=1200 real_cal=0 elapsed_ns=2998332499 measurement_result_valid=2399；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top.v | TB | 3194 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；A：全部有效代码实读，真实比较/输入驱动/注入参数/watchdog/结束/容差/硬编码核对；robust监视器最小A/B揭示F-016/017；smoke原71 PASS。其他长TB仍等待完整回归。；A组逐项台账（2026-10-04b读取）：完成7项；Icarus原TB当前状态：finished; rc=0；最终横幅=SMOKE_TB_PASS real_adc_responses=49 measurement_result_valid=33；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v | TB | 1462 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=ADC_NUMERIC_SCOREBOARD_TB_PASS result_captures=16 track_branch_fires=16；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_baseline_cross.v | TB | 1907 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；外部wall-clock上限截断，rc=124，回归未完成，不能裁定RTL/TB自身超时；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=BASELINE_CROSS_TB_PASS real_red=1106 real_ir=1104 real_cal=0 measurement_result_valid=2207 peak_count=6 valley_count=3 cross_count=1 return_count=1；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_fir_tail_isolation.v | TB | 1712 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；外部wall-clock上限截断，rc=124，回归未完成，不能裁定RTL/TB自身超时；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=FIR_TAIL_ISOLATION_TB_PASS real_red=900 real_ir=898 real_cal=0 measurement_result_valid=1798 peak_count=5 valley_count=4 cross_count=2 return_count=1 first_sar15_peak_frame=464 first_sar15_valley_frame=601；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v | TB | 1532 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；D组逐项台账（2026-10-04b读取）：完成2项，部分1项；Icarus原TB当前状态：finished; rc=0；最终横幅=IDAC_BUS_ISOLATION_TB_PASS sar15_zero_checks=5305 sar9_zero_checks=5308 result_captures=155；剩余：技能静态门禁/真实编译：真实Icarus编译/运行见A固定版原始证据；TB风格豁免，不计新S4；toolchain未请求；comment scanned_files=0不作全文扫描通过证据；formatter静态compile/AST失败，未绕过或记通过：['> ERR: [Python] control parser strict failure.'] |
| rtl/ppg_control_top/tb_ppg_control_top_injection.v | TB | 1045 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=INJ_TB_PASS；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v | TB | 2216 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；D组逐项台账（2026-10-04b读取）：完成2项，部分1项；Icarus原TB当前状态：finished; rc=0；最终横幅=INPUT_LIGHT_STATIC_MATRIX_TB_PASS owner_commit_total=69 static_vector_checks=3000；剩余：技能静态门禁/真实编译：真实Icarus编译/运行见A固定版原始证据；TB风格豁免，不计新S4；toolchain未请求；comment scanned_files=0不作全文扫描通过证据；formatter静态compile/AST失败，未绕过或记通过：['> ERR: [Python] control parser strict failure.', 'unclosed_block_comment'] |
| rtl/ppg_control_top/tb_ppg_control_top_lifecycle_fault_adc_anomaly.v | TB | 2172 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=LIFECYCLE_FAULT_ADC_ANOMALY_TB_PASS result_captures=8 owner_commit_total=244 measurement_discard_events=3 detection_discard_events=0；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_long_10_cycles.v | TB | 1987 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；A：全部有效代码实读，真实比较/输入驱动/注入参数/watchdog/结束/容差/硬编码核对；robust监视器最小A/B揭示F-016/017；smoke原71 PASS。其他长TB仍等待完整回归。；A组逐项台账（2026-10-04b读取）：完成6项，部分1项；Icarus原TB当前状态：running；未作通过结论；剩余：运行日志/入口脚本判据：所列静态比较/驱动/时限/终判/路径及各ID语义已审；原最小监视器A/B不冒充完整DUT变异。完整原长回归仍运行或排队，终态未核对。 |
| rtl/ppg_control_top/tb_ppg_control_top_longrun.v | TB | 862 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；A：全部有效代码实读，真实比较/输入驱动/注入参数/watchdog/结束/容差/硬编码核对；robust监视器最小A/B揭示F-016/017；smoke原71 PASS。其他长TB仍等待完整回归。；A组逐项台账（2026-10-04b读取）：完成6项，部分1项；Icarus原TB当前状态：running；未作通过结论；剩余：运行日志/入口脚本判据：所列静态比较/驱动/时限/终判/路径及各ID语义已审；原最小监视器A/B不冒充完整DUT变异。完整原长回归仍运行或排队，终态未核对。 |
| rtl/ppg_control_top/tb_ppg_control_top_no_recheck_control.v | TB | 1111 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=NO_RECHECK_CONTROL_TB_PASS result_captures=1627 owner_commit_total=1655；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_normal_slow_tracking.v | TB | 1558 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=NORMAL_SLOW_TRACKING_TB_PASS result_captures=1406 owner_commit_total=1477；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v | TB | 1887 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=OWNER_IDENTITY_BACKPRESSURE_TB_PASS result_captures=35 owner_commit_total=224 measurement_discard_events=1 detection_discard_events=0 order_violation_count=0；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_peak_valley_return.v | TB | 1581 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PEAK_VALLEY_RETURN_TB_PASS real_red=700 real_ir=698 real_cal=0 measurement_result_valid=1398 peak_count=4 valley_count=3 cross_count=1 return_count=1 first_sar15_peak_frame=464 first_sar15_valley_frame=601；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_periodic_recheck_recovery.v | TB | 1513 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=PERIODIC_RECHECK_RECOVERY_TB_PASS result_captures=2821 owner_commit_total=2906；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v | TB | 1770 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；A：全部有效代码实读，真实比较/输入驱动/注入参数/watchdog/结束/容差/硬编码核对；robust监视器最小A/B揭示F-016/017；smoke原71 PASS。其他长TB仍等待完整回归。；A组逐项台账（2026-10-04b读取）：完成6项，部分1项；Icarus原TB当前状态：running；未作通过结论；剩余：运行日志/入口脚本判据：所列静态比较/驱动/时限/终判/路径及各ID语义已审；原最小监视器A/B不冒充完整DUT变异。完整原长回归仍运行或排队，终态未核对。 |
| rtl/ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v | TB | 1503 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_real_raw_generator_selfcheck.v | TB | 531 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=RAWGEN_SELFCHECK_PASS；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_digital_esd_shell/ppg_digital_esd_shell.v | RTL | 97 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成10项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_digital_shell/ppg_digital_shell.v | RTL | 107 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成10项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_dual_precision_top/ppg_dual_precision_top.v | RTL | 451 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成10项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_dual_precision_top/tb_ppg_dual_precision_top.v | TB | 384 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成7项；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS: ppg_dual_precision_top CDC and frame-safe timing contract verified；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_dynamic_baseline_cross_detector/ppg_dynamic_baseline_cross_detector.v | RTL | 1697 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v | TB | 1323 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=ALL BSL-01 THROUGH BSL-39, OPT-01 THROUGH OPT-24 AND OPTC-01 THROUGH OPTC-02 PASS count=65；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence.v | TB | 220 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PHASE_A_ARITH_EQV PASS vectors=20005；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_idac_code_controller/ppg_idac_code_controller.v | RTL | 1266 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v | TB | 893 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS: ppg_idac_code_controller V2.1 periodic sequence and IDT regression completed；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_normal_transaction_fork/ppg_normal_transaction_fork.v | RTL | 322 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_normal_transaction_fork/tb_ppg_normal_transaction_fork.v | TB | 589 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS: ppg_normal_transaction_fork completed FFK-01 through FFK-09；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_p2s_packer/ppg_p2s_packer.v | RTL | 218 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v | RTL | 1003 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；C组逐项台账（2026-10-04b读取）：完成7项，部分2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：八门禁:testbench：目录门禁原始not_requested；完整运行及覆盖义务按TB/ID独立台账，既有缺口未修复；八门禁:toolchain：目录门禁原始not_requested；Icarus实际证据已有；Vivado xsim/综合、ASIC时序/CDC未验证 |
| rtl/ppg_peak_valley_window_detector/tb_ppg_peak_valley_window_detector.v | TB | 1204 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；C组逐项台账（2026-10-04b读取）：完成2项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；Icarus原TB当前状态：finished; rc=0；最终横幅=PVW-01 through PVW-48 ALL PASS: 54 checks；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_precision_window_controller/ppg_precision_window_controller.v | RTL | 889 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；重点读09-17两类sticky保持、START/diag-clear；START清sticky变异触发PWC-41 FAIL；全模块仍待审；B组逐项台账（2026-10-04b读取）：完成4项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_precision_window_controller/tb_ppg_precision_window_controller.v | TB | 776 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=PWC-01 through PWC-41 ALL PASS pass=48 fail=0；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_precision_window_integration/ppg_precision_window_integration.v | RTL | 1032 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；抽读注入直通FIR链；全部PWI协议和算法连接仍待审；B组逐项台账（2026-10-04b读取）：完成4项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v | TB | 854 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=ALL PWI-01 THROUGH PWI-05 PASS count=5；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_pulse_cdc_sync/ppg_pulse_cdc_sync.v | RTL | 110 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码实读：toggle/两级目标同步/差分脉冲；SPI4MHz下命令间隔反驳常规丢脉冲候选；任意使用条件未全量证明；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_reset_sync/ppg_reset_sync.v | RTL | 85 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码实读：异步assert/两级同步释放；跨域系统复位政策未全部核对；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v | RTL | 1519 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；B组逐项台账（2026-10-04b读取）：完成4项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_sar9_sar15_safe_selection_wrapper/tb_ppg_sar9_sar15_safe_selection_wrapper.v | TB | 1116 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=ALL SSW-01 THROUGH SSW-52 PASS；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_spi_register_file/ppg_spi_register_file.v | RTL | 681 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码+SPI地址/位段/写属性/复位实读；38诊断及128影子字节独立对照；真实Mode0错位F-005；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_system_active_config_unpack/ppg_system_active_config_unpack.v | RTL | 211 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_system_active_config_unpack/tb_ppg_system_active_config_unpack.v | TB | 340 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；D组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS: ppg_system_active_config_unpack all checks passed；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_system_config_manager/ppg_system_config_manager.v | RTL | 733 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；D组逐项台账（2026-10-04b读取）：完成3项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_system_config_manager/tb_ppg_system_config_manager.v | TB | 980 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；D组逐项台账（2026-10-04b读取）：完成2项，部分1项；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS: ppg_system_config_manager MGR-01 through MGR-24 all directed checks passed；剩余：技能静态门禁/真实编译：真实Icarus编译/运行见A固定版原始证据；TB风格豁免，不计新S4；toolchain未请求；comment scanned_files=0不作全文扫描通过证据；formatter静态compile/AST失败，未绕过或记通过：['> ERR: [Python] control parser strict failure.'] |
| rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v | RTL | 465 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；B组逐项台账（2026-10-04b读取）：完成4项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v | TB | 511 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；B组逐项台账（2026-10-04b读取）：完成3项；Icarus原TB当前状态：finished; rc=0；最终横幅=SUP-01 through SUP-10 PASS: 14 real comparisons；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_timing_3200hz_validation/tb_ppg_timing_3200hz.v | TB | 266 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成7项；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS: 3200 Hz frame, 80 us R/IR offsets, and Q3-center alignment verified.；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_timing_sar15/ppg_timing_sar15.v | RTL | 465 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成10项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_timing_sar15/ppg_timing_sar15_3200hz.v | RTL | 165 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成10项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_timing_sar15/tb_ppg_timing_sar15.v | TB | 456 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成7项；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS: ppg_timing_sar15 optical, test-MUX, and static characterization modes matched.；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_timing_sar9/ppg_timing_sar9.v | RTL | 474 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成10项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_timing_sar9/ppg_timing_sar9_3200hz.v | RTL | 165 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成10项；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_timing_sar9/tb_ppg_timing_sar9.v | TB | 548 | 完成 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发；A组逐项台账（2026-10-04b读取）：完成7项；Icarus原TB当前状态：finished; rc=0；最终横幅=PASS: ppg_timing_sar9 optical, test-MUX, and static characterization modes matched.；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh | TB支持 | 806 | 完成 | include自包含编译可解析；ID出现性机械扫描；实际回归使用；未全文语义审阅；C组逐项台账（2026-10-04b读取）：完成1项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |
| rtl/ppg_control_top/tb_ppg_real_raw_generator.vh | TB支持 | 363 | 完成 | include自包含编译可解析；ID出现性机械扫描；实际回归使用；未全文语义审阅；C组逐项台账（2026-10-04b读取）：完成1项；当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账；剩余：所列要求已审；不等于穷尽输入状态空间或ASIC签核 |

完整逐项证据及未完成项分别在各组coverage.csv，总表不将“已读全文”升级为所有检查完成。

## 6. 回归对比（当前检查点 2026-10-04T20:18:12+08:00）

48份活动TB均实际编译/elaborate返回0；当前实际设计仿真结束45份、运行3份、排队0份、因环境失败而尚未执行0份、外部墙钟截断待完整重跑0份。使用Icarus11，未获得xsim；19系统/芯片依原脚本^PASS空格口径、模块按实际PASS样式，对比每份原始run.log及最新入库基线/横幅，不使用summary.tsv。运行0/横幅一致不证明覆盖充分；发现表已记录逃过原TB的实际错误。

| TB | 当前状态 | rc | PASS行 | 系统基线PASS | FAIL标记 | 日志结论 |
|---|---|---:|---:|---:|---:|---|
| tb_diag_algo_probe | 完成运行 | 0 | 5 | 5 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_400hz_frame_calibration_scheduler | 完成运行 | 0 | 59 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_active_v4_control_plane_integration | 完成运行 | 0 | 22 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_adc_async_stage_capture | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_adc_dc_recovery | 完成运行 | 0 | 2 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_adc_measurement_idac_integration | 完成运行 | 0 | 48 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_adc_pipeline_overlap_corrector | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_adc_programmable_reconstructor | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_adc_result_router | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_adc_s1_programmable_calibrator | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_adc_s1_redundancy_corrector | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_amb_recheck_scheduler | 完成运行 | 0 | 35 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_characterization_control_cdc | 完成运行 | 0 | 26 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_chip_digital_top | 完成运行 | 0 | 6 | 6 | 0 | 原TB横幅已核对；语义限度见发现表；真实Mode0采样对照FAIL，F-005/006 |
| tb_ppg_coarse_detection_fir | 完成运行 | 0 | 103 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top | 完成运行 | 0 | 71 | 71 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_adc_numeric_scoreboard | 完成运行 | 0 | 69 | 69 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_baseline_cross | 完成运行 | 0 | 75 | 75 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_fir_tail_isolation | 完成运行 | 0 | 80 | 80 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_idac_bus_isolation | 完成运行 | 0 | 70 | 70 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_injection | 完成运行 | 0 | 15 | 15 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_input_light_static_matrix | 完成运行 | 0 | 73 | 73 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_lifecycle_fault_adc_anomaly | 完成运行 | 0 | 80 | 80 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_long_10_cycles | 运行中 | — | — | 129 | — | 固定版本继续运行，未作通过结论 |
| tb_ppg_control_top_longrun | 运行中 | — | — | 5 | — | 固定版本继续运行，未作通过结论 |
| tb_ppg_control_top_no_recheck_control | 完成运行 | 0 | 61 | 61 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_normal_slow_tracking | 完成运行 | 0 | 72 | 72 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_owner_identity_backpressure | 完成运行 | 0 | 68 | 68 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_peak_valley_return | 完成运行 | 0 | 75 | 75 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_periodic_recheck_recovery | 完成运行 | 0 | 70 | 70 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_control_top_robustness_corner_waveforms | 运行中 | — | — | 67 | — | 固定版本继续运行，未作通过结论 |
| tb_ppg_control_top_startup_idac_calibration | 完成运行 | 0 | 83 | 83 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_dual_precision_top | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_dynamic_baseline_cross_detector | 完成运行 | 0 | 65 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_idac_code_controller | 完成运行 | 0 | 148 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_normal_transaction_fork | 完成运行 | 0 | 50 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_peak_valley_window_detector | 完成运行 | 0 | 54 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_precision_window_controller | 完成运行 | 0 | 48 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_precision_window_integration | 完成运行 | 0 | 5 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_real_raw_generator_selfcheck | 完成运行 | 0 | 40 | 40 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_sar9_sar15_safe_selection_wrapper | 完成运行 | 0 | 52 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_system_active_config_unpack | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_system_config_manager | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_system_fault_abort_supervisor | 完成运行 | 0 | 14 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_timing_3200hz | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_timing_sar15 | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |
| tb_ppg_timing_sar9 | 完成运行 | 0 | 1 | 未给逐行数 | 0 | 原TB横幅已核对；语义限度见发现表 |

原始日志位于evidence/compile/<TB>/run.log，run.rc/start/end保留实际状态。此前3600秒外部wall-clock截断只表示未完成，不是TB内部watchdog或RTL死锁；旧记录保留evidence/resume_attempts/。2026-10-04补跑每份上限21600秒并最多4份长场景同时运行，未缩短时钟/样本/参数。WSL /mnt/c 新读取曾失败；错误日志完整保留。转移原sim.vvp后，其六条vpi_module绝对路径仍指向不可读取的目录，导致八份用例尚未执行设计便退出；不能据非零rc将它们算作已完成设计仿真。现仅在仓库外副本重定位这六条仿真器库路径，逆变换与原镜像字节完全相同，原RTL/TB及其余仿真指令不变；原工具包与native七个VPI二进制SHA256逐个相同。真实ADC捕获原TB恢复PASS、删除system库负对照失败，证据evidence/vpi_relocation_controls/。恢复脚本resume_vpi_paths.py保留失败日志并按四并发继续，不重启WSL或中断现有作业。短对照与原回归日志分目录，不混合统计。

2026-10-04本批另启动外部上限保护watch_external_caps_A.py：只在实际run.rc=124且原进程已写run.end后保留完整旧日志，等待现有队列及四并发容量后从头执行原TB，外部限额扩大到86400秒。它不终止现有仿真、不改TB内部watchdog、不改变DUT/激励；五个状态判别负对照已通过。rc124单列external_interrupted，未计入完成/通过。当前状态见evidence/external_cap_retry_state.json；该运行器只恢复仿真，不自动完成尚未审定的语义报告。

## 7. 方法与检查点

当前采用固定Git导出、真实Icarus逐TB编译/运行、仓库skill严格门禁与独立lint、逐模块/合同/TB语义审阅以及公开端口反例/变异。没有应用修复、生成RTL、提交或推送。所有脚本、编译物及最小TB均在仓库外，关键探针源代码与实际命令保存在evidence对应目录，可复现；详见各条证据索引。

机械脚本先做已知错误负对照：真实编译器的语法/缺include/不存在端口三负例；锚点的错文字、缺文件、越界、旧引用被当前引用覆盖和中途子文件歧义；ID缺定义/RTL标签/TB文本/索引四缺边与完整、紧邻中文、展开范围；日志判据的普通FAIL、JNT status=FAIL、最终TB_FAIL、带时戳FAIL及FATAL。机械通过只证明所实现的识别项，不证明语义正确。

全矩阵/别名9247个引用出现位置（含范围/重复）已机械扫描：5144仅文件/边界、525预期字面匹配、184历史Source已由当前覆盖、22节号/歧义、1656缺省文件名语境歧义、1696字面不符候选、14越界、6缺文件候选。大量合同Source引用本来就是组标题/位段表，不要求端口字面出现，因此1696不能直接当缺陷数；F-003只保留已逐项确认的643文字失配（分项按当前anchor_failures.csv及各批Source裁定表）及14越界汇总。复用Erie AST的516条单端口声明核对含287字面匹配、229失配，含同名注释伪匹配的五种负对照已通过；C02全部33 Source行另逐行裁定为32字面匹配/1公式引用失效。累计另有1860条Source已逐项人工裁定，Source待办0、两处C03歧义已裁定，详细分类与各批证据见global_closure_20261004/source_adjudication_summary_A.json。另对799处显式默认位宽及41处明示符号属性核对一致，4处参数名绑定缺失并入F024；6个缺文件候选均已裁定（3处缩写/跨行文字指向真实文件但索引失效并入F003，3处外部历史handoff确未入库）。证据分别为contract_width_crosscheck_A.json、grouped_width_manual_rulings_A.json、missing_file_candidate_adjudication_A.json。它们不替代非Source缺省引用的全部逐字核实或G-FP时序/CDC项目签核。bounds-only和缺省语境尚待完整人工解释。详情anchor_scan_v2.json、anchor_failures_v2.csv及global_closure_20261004/port_declaration_anchors.csv/C02_source_rows_33.json，已知失效锚点anchor_failures.csv。

版本与完整性新增全量检查：141条当前依赖源声明、26份manifest摘要均按真实文件/行/字节核对，中文及句尾版本解析正例、错误版本/路径负例先通过；M01只替换自身digest字段。26份固定Git原始blob与导出字节完全一致，排除CRLF归一化伪差异。确认23摘要不符（F-045）、同号需求映射错位（F-046）及SSW增量/基础规范标签未明示关系（F-047）；不因目标header V1.10便自动认定其sole-current V1.9基础绑定非法。

验收ID机械表id_presence_v2.json/csv覆盖全部合同表列/RTL标签/TB文本/矩阵别名表列，838个含模块、系统、历史和台账子项的候选不等于约319系统ID；缺边只是候选，不能据文本缺少标签判缺功能。C组355合同表列ID、B组312定义及19家族抽查、D组本地主责ID/端口/版本已逐项保存。B/C/D本轮均已交稿；A负责跨组裁定、Top与全矩阵和长回归终态。真实检查与无需RTL锚点理由必须语义对照，全文阅读不等于所有动态验收完成。

A五份系统TB关键抽查：smoke完整原TB错误TOP-18期望触发SMOKE_TB_FAIL errors1；diag/longrun原RAW12片段分别拒绝RED/IR不足、时长不足和watchdog，long10原计数/sticky片段拒绝丢失2、重复、饱和及8类sticky；robust两个原监视器最小A/B揭示F-016/017。后三份与robust为原比较片段，未声称完整DUT变异回归通过。SSW/PWC功能反例A独立重跑，全部结果按真实比较和日志裁定，不能用rc0代替TB通过。

以下为逐批历史记录，保留过程与当时限度；最新状态以§2、§5、§6及本节前述为准，早期“下一批/未审/待做”不作为当前状态。

### 检查点①：环境与自包含编译（已完成）

- 固定提交与仓库外导出完成；37 RTL / 48 活动TB / 32合同。两份legacy TB明确排除，另有2份`.vh`支持文件将在TB批次登记。
- Windows Git 2.54.0.windows.1；bundled Python 3.12.14；系统Python 3.8.5；Git Bash 5.3.9；WSL Debian 11.6。
- Vivado/xsim、Verilator未找到。独立Icarus 11.0（stable）从Debian官方源获取，仅解包到toolchain/，版本全文与下载SHA256保存于 evidence/toolchain*。未修改系统安装与全局PATH。
- 48/48活动TB逐份编译/elaborate返回0；19系统filelist、1芯片filelist、28模块TB_TABLE依赖全部使用。37/37 RTL按Verilog2005逐顶层编译返回0。
- 负对照：good编译0、运行0并打印REAL_COMPARISON_PASS；syntax_bad=2、missing include=1、nonexistent port=1。故意错误恰好三份编译失败。
- 编译没有FAIL发现；悬空输入及其他警告尚需按实际消费链和合同逐项裁定，不把warning直接认定为错误。
- 全37份运行仓库strict deliverable gate与verilog_lint；后者全部返回0。strict gate的既有风格积压仅汇总，不能据此认定RTL功能已通过。
- 本次没有使用remote/Vivado路径。skill预检缺erie-remote-ssh；用户明确指定本地工具并允许记录缺失，故仅执行本地只读审阅，未安装skill依赖。
- 自写驱动首次因Windows文本写入CRLF失败，已用显式字节LF更正，重新编译成功；首次驱动失败不属于仓库错误。
- 48份Icarus回归已启动，尚未完成。对比将直接读取每份run.log；无xsim.log意味着无法声称xsim复现。

| 规则 | 芯片层级30份RTL | 全部37份RTL |
|---|---:|---:|
| VG000 | 0 | 2 |
| VG001 | 0 | 2 |
| VG004 | 0 | 94 |
| VG007 | 0 | 16 |
| VG009 | 0 | 4 |
| VG010 | 46 | 138 |
| VG011 | 0 | 92 |
| VG012 | 0 | 2 |
| VG014 | 2 | 122 |
| VG021 | 0 | 4 |
| VG031 | 1 | 1 |
| VG040 | 0 | 8 |
| VG041 | 0 | 185 |
| VG042 | 0 | 1 |
| VG052 | 2 | 2 |
| VG060 | 13 | 726 |
| VG061 | 5 | 7 |
| VG064 | 0 | 94 |
| VG066 | 8 | 69 |

下一批：RTL叶子模块逐项语义审阅。后续待做：集成层/顶层、TB逐项、合同逐份、跨层锚点/ID、回归结果裁定、孤立模块、最终汇总。

### 增量检查点：F-001已保存

最小三路A/B和错误期望值负对照均已完成；原克隆没有写入。叶子RTL完整审阅批次尚未结束，回归仍在运行。

### 检查点②-A：ADC数值叶子与跨合同核对（部分完成）

已实读ADC捕获、S1冗余校正、S1可编程校准、Router、overlap、可编程重构、DC恢复的主要代码，检查弹性缓存握手、复位分支、中心化公式、signed扩展、舍入和饱和。另实读config_cdc_bridge、pulse_cdc_sync、reset_sync及SPI全部代码。尚未完成这些模块全部端口逐项合同表、所有FSM死锁反驳和全部TB变异，因此全部保留“部分”。新增F-002/F-003/F-004已在本检查点落盘。

锚点机械扫描共7403个显式/合同缩写引用出现位置（含重复，和用户约2300个唯一锚点口径不同）；7011个仅通过文件/边界，167个版本行通过边界，28个节号或歧义不裁定，177个明确预期文字不匹配，14个越界，6个缺文件待裁定。未覆盖全部省略文件名的`:NNN`继承引用，也未对“in bounds”逐条证明语义。故此统计不是“剩余引用全部正确”的结论。

回归：28模块+芯片+RAW自检+ADCN共31份结束，未发现FAIL标记；另外3份系统TB运行中，其余14份待运行。仅进程退出0和横幅匹配，不等于TB完整覆盖或无X；逐份日志和PASS原脚本口径仍在整理。

### 检查点②-B：SPI真实边沿与TB变异（已完成本子批）

F-005/F-006是新确认的S1/S2；没有修复源仓库。SPI地图38字节及全部写寄存器已作静态核对；独立physical探针暴露串行相位错误，legacy与仓库外假设控制通过全部38+128字节。上述通过只代表对照条件，不能当作入库RTL按真实Mode 0通过。

六项模块TB变异均编译成功并触发FAIL：S1冗余符号1031条、S1移除偏置1036条、重构中心1042条、PWC START清sticky 4条、Router删除复位门控2条、scheduler移除sample-index匹配1条；全部变异仅在evidence/mutations/。原TB判据检查FAIL文本，变异进程退出0本身不算PASS。

系统长仿真五秒诊断副本已推进至1768101500 ps（1.768ms）并完成JNT前缀54比较；因此不是时间0无穷delta循环，但Icarus速度不等同历史xsim。现有每份3600秒外部wall-clock上限可能截断大规模仿真；这样的外部截断须记为回归未完成，不能冒充TB自身超时或RTL死锁。日志evidence/compile/tb_ppg_control_top_baseline_cross/progress_probe.log。

### 本轮检查点与续审入口

本文件是**阶段报告，不是全量审阅完成或流片签核报告**。由于全量RTL/TB/合同语义审阅尚需继续，且缺少xsim使大规模系统回归在本轮外部时间上限内未完成，按用户§7停在②-B子批边界。119行覆盖台账包括37 RTL、48活动TB、32合同、2支持头文件；“部分”不能当作无问题，“未审”文件只做了机械登记。

下一批从**FIR全文→动态基线→峰谷→IDAC/AMB叶子**继续；随后完成AMI/scheduler/SSW owner/在途/截止/释放协议、控制层与顶层全端口核对、48TB逐项+变异、32合同逐份、每ID家族语义、七孤立模块。跨层锚点脚本未覆盖省略文件名的`:NNN`继承引用；机械ID候选表包含历史/模块级ID，不得把828候选数当成319系统ID变化或551个缺RTL标签错误。25份合同版本依赖只提取登记，尚未完成逐依赖裁定。

资料：evidence/ledger.json、anchor_scan.json、anchor_failures.csv、id_presence.json/csv、contract_version_inventory.json、regression_results.json、mutation_results.json、gates/、compile/、fir_floating_ab/、spi_map_probe/、chip_spi_ab/。最小TB源码完整保留在各探针目录。原仓库和导出源文件不得修复；继续必须沿用固定hash及本轮输出目录。无需重新clone、切换版本或重做已完成检查。

已知事项状态：本基准是scheduler V1.8、AMI V1.15，没有任务C V1.9；tick248仍按用户已知未修复状态登记，不重复报新发现。P2S反压限制的文档/TB前提更新不在此基准，按用户说明属于进行中；未把它计入新发现。strict gate口径给出芯片30文件77条/全37文件计数，未把与“约222条”不同直接判为状态错误。三项旧CDC/锁存/X态审计不是本轮签核证据。

本轮没有给任一整份RTL或TB标“完成”：代码实读和变异范围已逐行标明，仍缺的合同比对/全异常路径必须继续。完整审阅仍需完成余下语义与回归裁定；若补齐xsim，可按原脚本进一步复核跨工具结果。

检查点时间：2026-10-03T00:23:18+08:00。

只读终检：origin/main仍为首行hash；原克隆git status为空；范围内源文件SHA256与初始台账无差异。

检查点补记：F-007已经跨合同勘误与实际Top核实；确认数更新为7条（S1 1 / S2 2 / S3 4）。待续审候选还包括discard翻转位对两次轮询之间偶数个事件的可辨识性，尚缺真实系统事件/主机轮询前提的反驳验证，未计作已确认发现。

## A检查点：2026-10-04 孤立模块与Top全文

本批未修改共享源码。七个孤立RTL与四份对应TB的内部审阅已完成；它们处置未定及不属于芯片层级是已知事实，完成审阅不赋予正式集成资格。4 TB完整驱动/真实比较/watchdog/终判已查，单点变异都报错且无PASS终判：SAR9 Q3宽度12错误行、SAR15 Q2起点6、双精度MUX字段2、3200Hz帧长3；原4 TB均正常PASS。证据`evidence/mutation_results_A.json`及`evidence/mutations_A/`。

8个A主责RTL实际调用skill analyze-existing/formatter AST，退出码全部0，产物仅在本组字节相同副本目录；复用先前strict门禁规则计数，不重新列风格积压。证据`evidence/skill_analysis_A.json`。Top全部有效代码已读，C01合同954行全文已读；默认6子模块边界、注册事件合并、STATIC隔离、idle真源、owner/deadline/complete及全部输出逐项核对。Top与C01仍部分，非法参数拒绝、TOP01-24语义闭环/版本依赖/所有锚点继续。逐项最新状态以`coverage_A.csv`和`evidence/ledger.json`为准；前面历史覆盖表为旧检查点。

恢复时确认WSL无旧vvp进程，统一/额外exec session均不存在。七份无rc旧“运行中”记录实际中断，未当作通过。保留全部旧attempt日志至`evidence/resume_attempts/<tb>/before_20261004/`，仅续跑12份未完成/外部截断用例，36份已正常结束的不重复跑。每份外部时限21600秒、最多4并行，stdout实时刷新；时限与进程中断均不是DUT PASS。状态索引`evidence/regression_resume_attempts.json`，新exec session79583，最终仍读逐TB原始run.log。此前5/10秒进度探针显示仿真时间持续推进，但不能排除更晚停滞，也不能据此宣布长场景完成。

B/C/D部分交接已读取，专项发现尚待A查实际源码、合同与原始仿真再合并，不能把其他组摘要直接计入总数。

## A检查点：2026-10-04 新发现独立复核

新增F-009至F-015已逐条读取固定快照实际行、合同、原探针激励和日志。没有按组报告行号直接套用；C24拒绝参数条款实际为41行。scheduler Q3恒1有明确系统LFA-06分工，不据此报全局覆盖缺口。诊断probe全934行有效代码已读，其短运行门槛不作RAW-12十秒验收依据；矩阵和alias不登记该probe为RAW-12权威闭合证据。其它未完成内容仍见逐项台账。

## A检查点：系统长TB语义与PRC监视器

longrun有效代码由已实读diag版本加完整差异核对完成；long_10_cycles全1987行有效代码、robustness全1770行有效代码均已读。共享JNT前缀由C组负责，本组另核对计数隔离和owner快照接线；引用式PRC-05/08 PASS明确是其它TB证据，不计作本TB新执行的动态比较。F-016/F-017已做仓库外短探针；完整长回归与关键监视器全TB变异仍在推进。WSL新访问DrvFS出现EIO，保留已加载的四个长回归；相同工具字节转至/tmp/ppg_audit_iverilog_20261004，Icarus11版本及新探针成功。失败启动尝试保留，不计仿真验证。

## 覆盖检查点：2026-10-04b

A五份系统TB有效代码全文已读，比较、输入驱动、时限、终判、路径静态核对已保存。除smoke原71 PASS外，四份长场景尚未完成实际回归；只对robust PRC09/10完成最小判据变异，未声称完整robust变异仍通过。119文件覆盖表刷新为本次逐项台账：A组自审，B/C/D组状态按其台账保守汇总；跨组新发现仍需独立核实。其余所列未审保持未审。三组台账读取快照保存evidence/coverage_snapshot_20261004b。

## 功能专项检查点：2026-10-04b

新增F-018～024均已由A重新定位实际源行并跨文件反驳。F-018补跑公开端口A/B及错误期望；B/D六项复用其真实短仿真，A读取公开刺激、实际RTL/合同/生产者消费者与原始日志，不凭专项摘要计数。证据索引evidence/merged_findings_oct4b_refs.json。相关完整系统场景、default频率触发和全Top截止仍按各条限定，不把叶子反例自动升级为所有芯片运行必现。共24条待刷新总表；所有源文件仍只读。

## 验证覆盖检查点：2026-10-04c

F-025～030已核对实际合同、代码、变异/公开刺激和原始日志。F-026四模块共29输入悬空，由真实Icarus+skill AST确认；F-027补A短Verilog语义对照，并读取C新增真实DUT门限变异。F-028/029为原场景短片段，明确不宣称完整系统TB变异PASS计数。共30条，等待刷新汇总表。证据索引evidence/merged_findings_oct4c_refs.json。

## IDAC检查点：2026-10-04d

F-031～033已核对9处固定原文、三次公开端口/完整原TB实际日志与变异差异；新增S2一条、S3两条。831等ID扫描数字只是候选文本计数，不能直接作为真实缺口数量。

## 取消与验证检查点：2026-10-04e

F-034～039核实18处精确原文、A独立PWC/SSW四次运行、PWI四对照、真实Top恢复两对照及JNT三对照。共39条；完整smoke错误期望变异真实SMOKE_TB_FAIL error_count=1，确认TOP-18判据能生效。其余未完成检查不升级。

## 当前日期检查点：2026-10-04f

五份A系统TB关键变异已完成并限定抽查范围；当前119文件全部已进入语义审阅，仍有部分要求/跨组动态验收未闭环。最新覆盖状态及36/4/8运行状态见§5/§6。C、D已交付本轮分组审阅，B尚在收尾；总报告仍为进行中，不能宣布全量完成。

## 系统覆盖检查点：2026-10-04g

F-040～043四项已独立复核确认；F-044保留疑似范围裁定，不直接采信B-016的S2确认，因为Top锁存为合同明文的合法系统机制。新增A原OIB/RRC检查器短Verilog及正负对照，复核B真实INJ/P06六运行原始证据。共43已确认、1疑似，等待刷新总表。

## A 全局追溯检查点：2026-10-04 Top / 参考说明

使用仓库 erie-verilog-generator 的 analyze-existing 与八门 deliverable gate 只读入口。新的Top AST/分析与JSON均在 evidence/closure_skill_20261004；真实工具链编译/仿真独立记录，不将门禁的 compile 静态解析或 toolchain=not_requested 说成 xsim/ASIC验证。Top 165个端口名称、方向、默认位宽与C01边界台账165行一致（4个signed输出逐声明核对，矩阵未独立声明signed）；先做错误方向/宽度、缺行和重复行负对照。AST六个直接实例与合同一致；旧行号问题仍为F-003，参数化缺陷F-014/F-024和formal discard缺五epochs F-008不被此结论覆盖。门禁只有已接受VG031=1。

TOP01-24逐条源代码语义复核完成；“已审”表示审阅完成而非验收CLOSED。有限切片、真实反例及未结束的SID/OIB长回归如下，各引用文字已逐行校验。完整证据在top_24_semantic.csv/json。

| ID | 当前C01行 | 真正比较/结构证据 | 审阅结论和限制 |
|---|---:|---|---|
| TOP-01 | 913 | tb_ppg_control_top.v:1143; tb_ppg_control_top.v:1153; tb_ppg_control_top.v:3018; tb_ppg_control_top.v:3034 | 复位初值、安全S、真实在途复位及重新产生新结果；71 PASS smoke 已完成 |
| TOP-02 | 914 | tb_ppg_control_top.v:1189; tb_ppg_control_top.v:1308 | 联合合法提交及破坏V5保留位负向拒绝；下游ACK连接逐跳审过；F-023 STOP同拍优先级另列 |
| TOP-03 | 915 | tb_ppg_control_top.v:2921; tb_ppg_control_top.v:2924; tb_ppg_control_top.v:2942 | 两真实双光宏帧的帧号、连续序号、精度及固定Q3相位比较；F-009 宏帧5001拍另列 |
| TOP-04 | 916 | tb_ppg_control_top.v:2132; tb_ppg_control_top.v:2135 | CAL响应tick允许捕获延迟，不能把260..272响应范围当Q3本身偏移；SSW/Scheduler单位tick0/266比较补证 |
| TOP-05 | 917 | tb_ppg_control_top.v:2281; tb_ppg_control_top.v:2312; tb_ppg_control_top.v:2316 | 输出反压期间owner继续、held valid不撤销；独立波形/事务握手另在OIB与Scheduler单位场景。OIB顺序判据缺陷F-042保留；原OIB完整运行待终态 |
| TOP-06 | 918 | tb_ppg_control_top.v:2219 | 同笔三模块精度对比；FIR-tail GROUP4 真实旧尾部candidate禁止及重新CROSS，原80 PASS已完成 |
| TOP-07 | 919 | tb_ppg_control_top.v:2405; tb_ppg_control_top.v:2422; tb_ppg_control_top.v:2429 | 固定电流边界逐拍监视并要求真实RED/IR继续响应，不只有静态输出 |
| TOP-08 | 920 | tb_ppg_control_top.v:2521; tb_ppg_control_top.v:2531; tb_ppg_control_top.v:2601 | 静态向量逐位比较、CDC提交后S更新、真实owner计数不变；CCC原单位26 PASS补跨域提交原子性 |
| TOP-09 | 921 | tb_ppg_control_top.v:1285; tb_ppg_control_top.v:3133; tb_ppg_control_top.v:3160 | STOP/abort/drain及held正式结果显式discard均有真实比较；F-019身份/F-021资格/F-035完成abort碰撞反例不得被这些PASS掩盖 |
| TOP-10 | 922 | ppg_control_top.v:730 | Erie AST六个直接子模块及全层次iverilog elaborate；旧双精度/旧SAR timing无可达实例。静态验收无需TB标签；无ASIC综合工具 |
| TOP-11 | 923 | tb_ppg_control_top_startup_idac_calibration.v:889; tb_ppg_control_top_startup_idac_calibration.v:892 | SID01真实计一次边界及首AMB请求前owner/macro/result不推进；原完整SID回归排队，不能写成已重跑PASS |
| TOP-12 | 924 | ppg_control_top.v:411; tb_ppg_control_top.v:2556; tb_ppg_control_top.v:2566 | 许可门控、全4000拍idle及owner不变。宏帧/索引无推进由Scheduler static支路和单位场景另核对 |
| TOP-13 | 925 | tb_ppg_control_top.v:1840; tb_ppg_control_top.v:1843; tb_ppg_control_top.v:1847 | 纯RED SAR9按宏帧计一笔、无IR、固定IDAC快照；逐笔owner精度由后台捕获并按配置路径冻结 |
| TOP-14 | 926 | tb_ppg_control_top.v:1933; tb_ppg_control_top.v:1945; tb_ppg_control_top.v:1948 | 纯RED SAR15全RUN精度及每帧一笔比较；精度事件直接由fixed模式PWC屏蔽分支补静态证据 |
| TOP-15 | 927 | tb_ppg_control_top.v:1031; tb_ppg_control_top.v:1033; tb_ppg_control_top.v:3175 | 同拍owner不重入且终判要求监视非空；四SAR15控制共享包络在SSW逐拍及smoke后台监视补证 |
| TOP-16 | 928 | tb_ppg_control_top.v:1656; tb_ppg_control_top.v:1675 | 真实Q3后悬置DONE3000拍，owner不释放；释放真实CLK_DOUT后必须完成。错误identity在INJ02/AMI单位真实拒绝 |
| TOP-17 | 929 | ppg_control_top.v:416; tb_ppg_control_top.v:1720; tb_ppg_control_top.v:1723 | 单一网五路同源；扰动物理idle不造completion。芯片只同步一次，CDC signoff不属于现有工具能力 |
| TOP-18 | 930 | ppg_control_top.v:410; ppg_control_top.v:411; tb_ppg_control_top.v:2559; tb_ppg_control_top.v:2562 | 高有效许可分开扇出；STATIC测量0模拟1；真实错误期望变异触发smoke FAIL |
| TOP-19 | 931 | ppg_control_top.v:851; tb_ppg_control_top.v:2656 | CDC已提交单一源到manager/SSW/许可；非法PHOTODIODE组合提交真实拒绝 |
| TOP-20 | 932 | tb_ppg_control_top.v:2757; tb_ppg_control_top.v:2761; tb_ppg_control_top.v:2764; tb_ppg_control_top.v:2825 | 真实固定电流RUN要求有两色事务且源/接收校准门持续禁用；NORMAL SAR15配置先拒绝，不制造不可达非法RUN；F-046 FSC标签语义错位保留 |
| TOP-21 | 933 | tb_ppg_control_top_injection.v:687; tb_ppg_control_top_injection.v:699; ppg_control_top.v:393 | 参数默认0 smoke与编译使能1运行enable0 INJ双切片；未持有历史V1.3.4全波形逐位比较源，不能以一个sample_valid替代逐位等价签核 |
| TOP-22 | 934 | tb_ppg_control_top_injection.v:797; tb_ppg_control_top_injection.v:811; tb_ppg_control_top_injection.v:835; tb_ppg_control_top_injection.v:900 | 真实错identity保持owner、supervisor阻断、STOP清理和下一合法样本恢复；INJ02“恰好一次/原identity”横幅没有独立完整completion计数，AMI单位cache/单脉冲结构补有限证据，非所有collision覆盖 |
| TOP-23 | 935 | tb_ppg_control_top_injection.v:954; tb_ppg_control_top_injection.v:957; tb_ppg_control_top_injection.v:978 | invalid握手、正式sample_valid0和后续1真实比较；全X判断不能证明身份正确，完整frame变异逃逸F-049；robust直接引用不能补此比较 |
| TOP-24 | 936 | tb_ppg_control_top_injection.v:997; tb_ppg_control_top_injection.v:1000 | 双请求ready0场景没有命中实际采样eligible窗口，变异已证实F-040；其他安全负向由模块/结构补有限切片，F-044叶子去使能Top RUN不可达仍疑似 |

非规范参考裁定：TAPEOUT_FINAL_REVIEW_GUIDE.md全部71行已核对。其本机路径不存在、SMOKE56与现71、CDC/锁存审计日期早于修复，属于用户明确已知；不新增发现、不采用“唯一开放线索/功能正确”作为当前结论。没有Cxx当前版本声明或独立验收定义，版本绑定/验收闭环项属于不适用；矩阵§2:167-171规定其非规范地位，真实流片/STA/AMS限制仍明确保留。

候选联合TB说明全部382行已核对：§2只连接Scheduler/SSW/AMI，明确排除manager/SPI/fault supervisor，不能拿其scope否定Top路径；STATIC许可与当前Top拆分一致，10秒/≥4000帧/每色≥4000真实结果按现行C25和原long_10_cycles判据核对。§11的历史52子检查先于当前C25及JNT54，按候选状态与矩阵§2非规范分类处理，当前回归不用52作门槛；真实门槛失效F-037独立保留。PRC-04零脉搏冲突是已接受事项，候选闭环次序不覆盖C20/C23现行规范。不存在独立Cxx版本绑定，未因非规范候选中尚未实现的场景自动报RTL错误。原10秒回归仍未结束，不宣布候选算法长运行PASS。

## A 全局四链及标签检查点：2026-10-04

全量机械四链表all_id_four_links.csv包含838个候选，涵盖当前模块/系统验收、历史引用和G-FP子项；不把它当约319个系统ID的总数。已合并745个候选的A/B/C/D逐ID语义记录，其余93个按下表裁定。46个家族均有实际源码/条款代表样本审阅；各组部分或待动态项保持原限制，不把合并操作算成A逐ID重新仿真。四类缺边负对照分别报出唯一删除的边。

| 剩余家族 | 源码/当前条款样本 | 范围裁定 |
|---|---|---|
| AV4 | PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md:606; tb_ppg_active_v4_control_plane_integration.v:649; PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md:621; tb_ppg_active_v4_control_plane_integration.v:815 | 19个C04连接验收条款不是AV4C编号的逐号别名；1024-bit COMMIT直连唯一unpack、具名V5到AMI/PWI、码快照与epoch静态逐跳和AV4C01/21、TOP02、MGR/UNPACK分担验证。F-025的alpha缺比较保留，不能据AV4C22 PASS宣称全部V5字段动态已验证。 |
| CF4 | PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md:670; PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md:674; ppg_system_config_manager.v:314; ppg_system_config_manager.v:317 | schema4和保留位由唯一manager资格门检查，MGR12真实非法schema/bit639比较及MGR03合法提交补样本；16bit interval不存在额外数值拒绝比较，0/1/4096/65535静态均可表示；RUN只允许CONFIG COMMIT，当前规范字段仍保持。五个CF4未形成独立命名TB，不制造全量动态四端点已PASS结论。 |
| D | PPG_CONTRACT_CLOSURE_MATRIX.md:3536; PPG_CONTRACT_CLOSURE_MATRIX.md:3585; ppg_control_top.v:123 | D01/D02/D03是产品接口决策及关联门禁；D02端口已存在，D03模拟收敛不适用已冻结为用户已知，不要求虚造独立TB/RTL标签。 |
| D01 | PPG_CONTRACT_CLOSURE_MATRIX.md:3599; tb_ppg_active_v4_control_plane_integration.v:824 | V5 safety-valid同一unpack->AMI->PWI->三leaf链及reset valid0/合法commit释放真实比较；F-034同拍discard/safe提交优先级反例仍适用。 |
| G-FP | PPG_CONTRACT_CLOSURE_MATRIX.md:3599; PPG_CONTRACT_CLOSURE_MATRIX.md:3602; ppg_control_top.v:104 | G-FP01..07及D01子项是端口、状态、故障、参数、CDC、产品台账门禁，机械ID不等于一个RTL状态机。C01 165边界端口完成独立名称/方向/默认宽度核对；其他cluster按B/C/D端口表实读，用户已知的独立签核不足仍明确保留；参数F014/F024、manifest F045、失效锚点F003不能被旧CLOSED文字覆盖。 |
| JNT | tb_ppg_jnt_baseline_prefix.vh:638; tb_ppg_jnt_baseline_prefix.vh:796; tb_ppg_jnt_baseline_prefix.vh:800 | 9稳定ID由共享prefix54子比较实现，全部14真实include已自包含编译；跨整个Top的验收无需单模块tag（别名表明示N/A）。原19系统已完成者逐log确认JNT54；数量不足终判传递错误F037必须保留；剩余长回归不填PASS。 |
| K | ppg_system_fault_abort_supervisor.v:198; tb_ppg_system_fault_abort_supervisor.v:480 | K01五路根故障->AMI->supervisor，K02episode与首故障分离，K03generation参数，K04代际discard，K05层级排他逐跳核对。SUP10A缺保留旧首故障刺激F012；PWC sticky START历史F022、clear归因F046、SSW碰撞F035均可反驳局部CLOSED。 |
| L | PPG_CONTRACT_CLOSURE_MATRIX.md:996; PPG_CONTRACT_CLOSURE_MATRIX.md:167 | L01是版本/规范优先级清理项，别名表明确N/A；全部141依赖及26原Git blob核对，不要求独立硬件tag。F047基础标签与增量版本关系未明示仍保留。 |
| N | tb_ppg_adc_measurement_idac_integration.v:1616; tb_ppg_adc_measurement_idac_integration.v:1619; ppg_system_config_manager.v:533; ppg_control_top.v:329 | N08真实pre-handoff判据及系统scope-only flush互补，N01四consumer empty真实比较；N02generation唯一producer静态，N03SUP同拍仲裁，N04两腿未单独隔离为用户已知且F048名单冲突，N05Top锁模式，N06SUPwatchdog/episode但旧first-fault保留验证不足F012，N07是TB方法规范无需RTL锚点。 |
| P | tb_ppg_control_top_lifecycle_fault_adc_anomaly.v:1622; tb_ppg_control_top_lifecycle_fault_adc_anomaly.v:1639; tb_ppg_control_top_lifecycle_fault_adc_anomaly.v:1644 | P01真实ready/abort同拍优先与完整identity逐场景核对，P02/N01同源discard，P03注册merge，P04/09/10由SUP模块补证，P05watchdog，P06合法Top RUN去使能不可达而叶子问题F044仅疑似，P07/08/11/14引用INJ/LFA/OIB且有限比较F049保留，P12/15/16/17是静态参数/连线或方法义务，P13 fork原50比较；P10逐hex未测为用户已知。 |
| R | PPG_CONTRACT_CLOSURE_MATRIX.md:997; PPG_CONTRACT_CLOSURE_MATRIX.md:1005 | R01..09是历史冲突修复追溯，不是9个新增运行场景。当前端口/层级与141依赖源已实读；C01 discard/诊断清除文字和C09版本关系仍有F008/F048/F047，未因历史Replaced自动判当前一致。 |

已确认的矩阵/别名语义错误为F003、F045、F046及相关合同F047/F048；用户明确已知的§13.1快照滞后、G-FP独立复核不足及工具签核局限不重复编号。缺字面tag/索引只是四链候选，模块级共享比较、静态义务和N/A理由列明；未称所有838候选已达到四边逐ID规范签核。

## A 标签核对及本批边界：2026-10-04

全570行别名表的标签/字面RTL锚点机械核对：{'symbol_anchor_without_tag': 103, 'same_id_tag': 223, 'explicit_NA': 14, 'different_id_tag_candidate': 17, 'no_literal_source_anchor': 10}。同时检验错ID、删标签及明确“不是旧锚点”的负对照，RRC02行中的否定旧idac引用已剔除，避免脚本反向误判。17个不同标签候选全部人工逐条裁定：三处真实AMI行号漂移并入F003、SID11旧不可达状态并入F050，13处为共享实现或静态台账代表锚点。逐条原文和裁定见alias_tag_consistency.csv与different_tag_adjudication.json。不存在把所有“不同tag/无tag”升级成新功能缺陷的做法。

本批A已完成Top165端口、TOP24语义、838候选四链全量机械检查、46家族语义抽查、141版本绑定/26摘要和两份非规范参考裁定。仍未逐项独立签核G-FP其余全部cluster，也未对9247机械锚点的每个合法组表头/继承引用候选逐条完成语义裁定；这些限度在§5矩阵/别名行保留，用户已知事项不重复编号。最终原长回归日志尚未全部到齐，因此报告仍为阶段报告，不能称ABCD整体审阅交付已全部结束。

## A 声明锚点补充复核：2026-10-04

复用37份既有skill gate的canonical formatter AST（35个不同模块名）进行Markdown单端口声明锚点核对，先通过错误行号、错误方向、缺端口及越界四个负对照；随后补充同名注释伪匹配负对照，并用实际AST声明跨度排除假匹配；正确对照不误报。实际516处声明引用中287处字面匹配、229处失配，后者含已计入F003的165处Top引用与新增64处Scheduler/AMI引用。去重后F003为250处文字失配和14处越界，详表anchor_failures.csv；原始目标行和当前逐行验证的声明行见port_declaration_anchors.csv。未带明确声明的1365行及1个分组行保留语义边界，没有伪造它们的“通过”。C16/C17共244处声明字面匹配，名称/方向正确不等于已完成所有跨域、优先级及在途语义签核。

## A 全台账端口存在性核对：2026-10-04

实际提取§12.5全部1860个Direction为input/output/inout的端口行，复用Erie AST逐合同对照名称与方向：1858个单端口匹配，1个Stage1权重组展开0..9十端口全部匹配，1个C03的o_system_fault_blocking不在wrapper中，但该行:1633已经明确标注“defect finding / phantom/mis-filed”，且实际Top有同名输出，故记作已明示的待协调台账条目，没有新报缺RTL功能。初次只按合同对应外层模块匹配时的其余候选，经当前C04映射正文和C10捕获/冗余/Router子模块表逐项反驳，全部找到了真实边界；这体现为什么不能凭机械名字搜索直接报错。名称、方向及少一个分组成员三种负对照先通过。详见ledger_port_inventory.csv/summary/controls。

边界：多模块合同使用明示模块集合并保留命中的实际声明行，名称/方向存在性不证明producer/consumer连线、位宽、复位、CDC或等待释放规则已逐字段签核；这些仍与分组语义审阅及G-FP已知未复核范围分开记录。别名明确否定旧锚点的语法已排除；838候选四链、46家族抽查、516条明确声明锚点、141版本绑定和26字节摘要本批均已实际完成。长回归仍执行，最终汇总未称全部完成。

## A 本批交付与后台任务：2026-10-04

本批新确认F048—F050及F003的64条子模块锚点补充已写入主表，S1/S2置前；119个固定范围文件hash复核通过，Git状态空，origin/main锁定hash未变化。当前阶段副本为PPG_FULL_REVIEW_20261004.md，源报告PPG_FULL_REVIEW_20261002.md由A唯一维护，早期日期副本及历史检查点不得作为最新进度。

原回归与native恢复进程继续执行；watch_external_caps_A.py仅恢复真实墙钟截断；watch_report_results_A.py仅在真实终态变化后重读每份原始run.log、核对基线及横幅并刷新§5/§6/交接，不根据旧summary.tsv或TB自身的PASS宣称语义正确。实际活动状态和刷新事件分别保存在evidence/vpi_recovery_state.json、external_cap_retry_state.json、report_watch_state.json及report_watch_events.json；运行器的状态/FAIL/截断/缺组成员负对照已保存。新的FAIL、PASS数量变化或空最终横幅将列为待人工裁定异常，未自动编造新发现或宣布全量完成。

## A C02 Source交叉引用裁定：2026-10-04

§12.5的33个C02 Source锚点已逐行对当前UTF-8合同核实，32个含明确的同名端口；仅:1593引用C02:297时目标为空行。C02:311存在完整start_ready公式，manager实际:90有o_start_ready、:503直接赋值，故不存在该输出的RTL缺实现。:1593本身已明示完整I/O表漏登记的文档缺口，此轮不把其已自述的缺口另编号；只把公式/Source行号失效作为F003新增记录。现F003汇总251处文字失配及14处越界，C02 Source逐行证据见global_closure_20261004/C02_source_rows_33.json。

## A C03/C04 Source语义裁定：2026-10-04

不等待长回归，实际对C03/C04全部129个Source引用逐条核对：29个C03旧Source确认失效并入F003；70个C03当前分组引用、1个生命周期节标题、25个C04完整字面映射、1个十权重组引用接受，共97个合法引用；1个C03 phantom原表已经明示，未新报缺RTL；2个C03输出的Source只指ACTIVE/epoch标题，但C02已有状态透传来源，保留范围歧义不计缺陷。这些不是机械103个“没有完整端口名”候选都报错：C03§8明确保持unpack当前端口名/宽度/signed，C03§11允许manager状态组透传；当前组标题本身有效。F003现280处文字失配+14越界。Source原行、逐项反驳、真实AST端口声明行及现行明确定义行见global_closure_20261004/C03_C04_source_rows_129.json/csv，所有行号取当前文件真实文字，未按偏移推算。

## A C05/C07/C08/C09 Source语义裁定：2026-10-04

本批291条Source不依赖长回归，已逐条交叉核对当前合同、矩阵和规范Erie AST：C05 68条、C07 16条、C08 106条均接受当前字面/字段组/章节组/完整身份来源；C09 101条Source确认指向其他参数、端口、错误接口章节或无关sticky，并入F003失效引用汇总。C09身份各字段由§7.8完整fault identity和§7.9约束覆盖，不误报缺RTL；测试注入及Q3新增输出有当前第4行明确定义，不根据日期或固定偏移推算行号。C05 67个输出切片逐项复用Erie AST静态核对一致；未将此扩张为全部G-FP复位/CDC/时序签核。累计已单独裁定C02至C09相关453条Source，保留C03两处来源范围歧义。

## A C11/C17 Source语义裁定：2026-10-04

完整核对C11当前53条Source、C17当前122条Source；共173条引用指向空行、围栏、参数、错误方向端口、阈值说明或无关规则。C17 STOP/abort的两个当前同名取消条款合法。正确来源逐条按当前完整声明、规范端口表及允许的十权重/同名元数据组定位，没有套偏移。C11受条件保护的discard广播豁免保持原裁定，不因为错误来源推断缺RTL。证据和负对照均在global_closure_20261004。本轮Source人工裁定累计628条，F003累计554文字失配+14越界。

## A 检测链与Supervisor Source语义裁定：2026-10-04

完整核对C19/C20/C22/C23/C24的368条端口Source：真实章节/表格、完整TXN/FAULT身份组、显式low/high或min/max缩写、中心元数据o_前缀和谷epoch透传均有当前规范覆盖；旧生命周期表未逐个列新端口，但现行附加条款已明文定义，不误报缺RTL。C24两个module-level API索引保留复位名矛盾，另以F051静态确认合同端口名不一致；不是reset功能错误。逐条裁定及章节边界负对照在global_closure_20261004。累计单独裁定996条Source；F003计数不因合法分组增加。

## A 人工剩余项计数：2026-10-04

按实际逐项证据而非估计计数：G-FP的1860条端口台账Source工作项中，996条已有单独人工裁定记录，864条尚待单独裁定；另有已审的C03:矩阵1639/1640两处来源范围歧义（o_lifecycle_state/o_start_ready）。来源待办分布如下：

| 合同 | 待单独裁定Source条数 |
| --- | ---: |
| C01 | 250 |
| C10 | 288 |
| C13 | 60 |
| C14 | 63 |
| C15 | 81 |
| C16 | 122 |
| 合计 | 864 |

每条待办的当前矩阵行、端口、完整Source原单元格及真实模块/声明行已导出global_closure_20261004/source_manual_backlog_864.csv；计数负对照、两处歧义证据和范围见manual_remaining_summary_A.json。864是引用工作量，不是864个缺陷；此前全量名称/方向机械检查已完成，不能把此待办理解为864端口的代码从未审过。缺省/继承引用及端口生产者/消费者、复位、时序、CDC独立逐字段核对尚未形成统一穷尽待办清单，因此当前不能诚实给出全部人工工作的精确剩余总数或整体完成百分比。B/C/D的原分组审阅不因此重置为未完成。

## A Source人工裁定闭合：2026-10-04

此前996已审/864待审是历史检查点；本批已实际完成剩余864条逐项裁定，并解决C03两处范围歧义。当前1860/1860 Source工作项有单条记录，待审0、未裁定歧义0。最后一批341条当前字面/章节支持、435条明确分组及跨合同支持、84条失效Source、4条已有明确缺口/历史覆盖说明。两处C03新增索引失效并入F003；最后批次负对照曾真实捕获空行错误地继承后续表格的问题，检查器已在仓库外修正，再通过当前覆盖、跨章节、空行、反向握手四类负对照；没有以失败检查器的无报错结果作依据。

这只关闭Source索引与分组来源人工待办，不把结果扩展成ASIC CDC签核或未经执行的长期回归结论。关键证据：global_closure_20261004/C01_C10_C13_C14_C15_C16_source_rows_864.json和更新后的C03_C04_source_rows_129.json。

## A 剩余人工核对裁定及范围：2026-10-04

本批完成1860条Source、两处C03歧义、6个缺文件候选及显式默认位宽补充核对。799处位宽一致，其中41处明示signed/unsigned属性也一致；改变位宽/翻转符号负对照恰好报出两处故意错误，两个正确对照无误报。4处无法按合同参数名求值已实际人工核实：manager的四个epoch为固定8-bit，但仅声明CONFIG_WIDTH/RUN_GENERATION_WIDTH两个公开参数，归入原F024，不再留作未来待办。

缺文件候选中1处是换行拆开的真实SSW文件名，但引用:480为空，逐字找到实际o_analog_safe赋值:482；2处是C02缩写文件名与已报F003的旧start_ready公式在说明列再次出现；这3个引用出现位置并入F003，现643文字失配及14越界。3处外部历史handoff确实未入库，列为无法读取的证据限度，不编造其结论。非Source的bounds-only/省略文件名注释没有全量逐字语义签核，G-FP全部cluster逐字段项目签核与ASIC工具检查也未重建；这与已完成的模块端口语义审阅、1860 Source裁定和46家族抽查分开标明。F044仍是合同入口范围待owner裁定的疑似，不强行制造非法系统场景。详见static_residual_disposition_A.json。

当前可在回归终态前完成的人工项目已完成并记录；剩余正在执行的是四份完整原长回归及其最终日志/基线核对。任何新FAIL或异常终态仍需人工反驳复核，不能由后台程序直接判成已确认功能错误。

## A 实际实例连线补充核对：2026-10-04

复用仓库Erie canonical AST及其原有实例/关联提取helper，实际核对39个可用实例、2168个命名端口关联：没有未知formal、重复formal、缺接或显式留空的输入，也没有一个plain net被多个子模块输出共同驱动；2024处完整单根actual net的默认参数化位宽与child formal相同。未知端口、重复、开路输入、漏输入四个负对照分别精确报出故意错误，正确输入和留空输出不误报；位宽/符号比较沿用已通过的独立负对照。时钟/复位逐关联真实行导出canonical_clock_reset_bindings_A.csv；Top与chip reset/两source CDC路径按已有语义复核和F007边界解释。

另4个孤立timing实例在旧strict聚合AST中未得到可用leaf端口元数据；原源文件确实在库，真实Icarus37RTL编译及dual/timing完整原TB已通过，保留为本次额外AST连线扫描的限度，不谎称缺模块或新增RTL缺陷。对常数/拼接/留空输出未用单根net宽度比较来证明语义正确。全部实际关联与原行、参数覆盖和限制见global_closure_20261004/canonical_instance_crosscheck_A.json；不以此代替握手/CDC/优先级签核。

## A 人工收尾仍在进行：2026-10-04

Source工作项1860/1860及两处范围歧义已完成。仍需人工核实非Source的省略文件名引用、未逐条指定预期文字的bounds-only引用，以及G-FP各cluster生产者/消费者、复位、CDC、优先级的独立语义。机械扫描的1656处隐式上下文候选和5144处bounds-only存在与先前证据重叠，不能相加当作精确剩余总量，也不能直接当作缺陷数。已据实际PWC代码、合同和原模块TB确认K-001状态错误。人工闭环状态保存于manual_closure_completion_A.json；报告终态程序已增加该状态门槛，三份长回归通过不会自动把未完成人工核对变成完成。
