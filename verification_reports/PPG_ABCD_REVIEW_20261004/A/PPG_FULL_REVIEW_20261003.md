被审 origin/main HEAD：`d18c6954621e53e5a6505dd3a6c688c266d23839`

# PPG 数字部分全量审阅阶段报告（未完成）

审阅日期：2026-10-02至2026-10-03（Asia/Shanghai）。独立只读审阅；原克隆未改动。

## 1. 基本信息

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

仓库erie-verilog-generator按SKILL.md手动执行；本轮运行strict deliverable gate和verilog_lint external=none，没有verify/repair、源代码生成、formatter或自动修复。静态门禁和Icarus编译不等同实际综合；没有执行独立ASIC时序/CDC签核或全周期X审计。脚本自身的负对照不构成芯片功能正确性的证明。

## 2. 结论摘要

尚未完成全量语义审阅。已确认7条：**S1=1、S2=2、S3=4、S4=0**；按主层：RTL=1、TB=2、合同=3、矩阵·台账=1。最重要为F-005（真实Mode 0 SPI读流提前一bit）及F-006（原芯片TB采样竞争掩盖错误）；F-001为4份注入TB的正式FIR资格X。未审、未完成工具检查和仅编译通过不能理解为功能通过。


| 编号 | 严重度 | 主层 | 结论 |
|---|---|---|---|
| F-005 | S1 | RTL | 真实Mode0 SPI读流提前一bit，leaf与chip均复现 |
| F-001 | S2 | TB | 4份注入构建缺calibration-loss valid驱动，正式FIR资格X |
| F-006 | S2 | TB | 芯片TB的SDO采样发生在negedge NBA更新前，掩盖F-005 |
| F-002 | S3 | 合同 | C13完整discard身份组多声明五个epoch端口 |
| F-003 | S3 | 矩阵·台账 | 177个明确文字不匹配引用及14个越界引用，按出现位置统计 |
| F-004 | S3 | 合同 | C13给纯组合Router声明不存在的注册式local-empty |
| F-007 | S3 | 合同 | 芯片合同两路reset_sync正文与自身勘误/实际单路架构冲突 |

按严重度：S1 1、S2 2、S3 4、S4 0。按主层：RTL 1、TB 2、合同 3、矩阵·台账 1。跨层证据见各条，不重复计数。

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
- **描述/依据**：别名:58-69的K01～K05出处仍为矩阵:872-876，实际指向CDC章节/空行；真实K行是:991-995。矩阵:1324的Verbatim declaration anchor明确写Top:121为i_adc_physical_idle，实际为i_dout_stage2_low。除这两组，脚本按明确“file:line + 逐字端口声明”的语法得到165个声明文字不匹配引用；另有14个明确文件行号超出文件总行数。12个K出处与上述165个声明引用合计177个文字不匹配记录。逐记录源行、引用、目标原文见`evidence/anchor_failures.csv`；重复引用按出现位置保留，不能当成177个独立功能错误。
- **证据/反驳**：扫描已先以正确锚点和三处已知错误作负对照，恰好报出错误文字/不存在文件/越界三类。忽略删除线中的旧引用，Cxx:3按版本行，带小数及低整数歧义按节号保留，不报为失效。C01“当前合同行号”的补记修正了合同侧Source列，未修正这些RTL声明列；:1324重建说明仍重复Top:121，没有给出实际端口行号。K机制已在真实RTL及矩阵新位置存在，故本条不是K闭环缺失。用户已知§13.1快照滞后、未独立复核台账、style backlog及旧外部文件不是本条所报告的错误。外部memory/缩写文件缺失6条单列为待裁定，未算入本发现。
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

## 4. 已知事项状态核实

待分批填入。

## 5. 覆盖台账

| 文件 | 层 | 行数 | 状态 | 已做检查 / 剩余 |
|---|---|---:|---|---|
| contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md | 合同 | 1252 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md | 合同 | 644 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md | 合同 | 343 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md | 合同 | 623 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ADC_IDAC_INTEGRATION_SPEC.md | 合同 | 494 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md | 合同 | 1337 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md | 合同 | 346 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md | 合同 | 157 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；全文实读；overlap/Router正式端口矛盾F-002/F-004；生命周期全行为未仿真；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md | 合同 | 205 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；全文实读并对Router及AMI连接；其余upstream完整身份条款仍待核；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md | 合同 | 405 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_ALIAS_MAPPING_TABLE.md | 合同 | 570 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；关键章节/identity定义/K条目/C01/C13台账抽读；全引用出现性+边界扫描，F-003；未全量语义核实；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md | 合同 | 408 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md | 合同 | 466 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md | 合同 | 309 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；SPI协议/38读字节+写方向地图逐项静态核对；关键CDC/P2S段实读；历史长段/全合同未审；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md | 合同 | 686 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；注入/检测资格相关条款实读，F-001；其余全文未审；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_CONTRACT_CLOSURE_MATRIX.md | 合同 | 3920 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；关键章节/identity定义/K条目/C01/C13台账抽读；全引用出现性+边界扫描，F-003；未全量语义核实；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md | 合同 | 954 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；注入/检测资格相关条款实读，F-001；其余全文未审；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md | 合同 | 666 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md | 合同 | 966 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md | 合同 | 717 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md | 合同 | 382 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md | 合同 | 716 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md | 合同 | 900 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md | 合同 | 1029 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md | 合同 | 690 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md | 合同 | 975 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md | 合同 | 918 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md | 合同 | 430 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/ppg_system_active_config_unpack_semantic_contract.md | 合同 | 117 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/ppg_system_config_manager_semantic_contract.md | 合同 | 395 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md | 合同 | 161 | 未审 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| contracts/TAPEOUT_FINAL_REVIEW_GUIDE.md | 合同 | 71 | 部分 | 机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环；全文实读；外部路径/过时数字按用户已知背景登记，不当权威；未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成 |
| rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v | RTL | 884 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；重点读V1.8 deadline/owner/DONE身份比较；sample-index比较变异触发FSC-32 FAIL；全部FSM仍待审；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v | TB | 936 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_active_v4_control_plane_integration/ppg_active_v4_control_plane_integration.v | RTL | 500 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v | TB | 889 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_async_stage_capture/ppg_adc_async_stage_capture.v | RTL | 236 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；代码实读：DONE两级同步/模式冻结/单笔pending/缓存反压/复位；合同全部端口与异常重叠仍待核对；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_async_stage_capture/tb_ppg_adc_async_stage_capture.v | TB | 363 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_dc_recovery/ppg_adc_dc_recovery.v | RTL | 371 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；主要代码实读：DC unsigned8与signed增益乘法宽度/Q17/24bit饱和/资格/缓存复位；少量payload段与全部合同比对未完成；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_dc_recovery/tb_ppg_adc_dc_recovery.v | TB | 475 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v | RTL | 2681 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；抽读注入透传、Router/overlap实例、private discard、输出资格消费链；owner/截止/完成释放全协议仍待审；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v | TB | 1642 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v | RTL | 449 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；主要代码实读：S2冗余/固定Q16/饱和/缓存/复位/generation discard；C13完整身份差异F-002；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_pipeline_overlap_corrector/tb_ppg_adc_pipeline_overlap_corrector.v | TB | 804 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_programmable_reconstructor/ppg_adc_programmable_reconstructor.v | RTL | 352 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；主要代码实读：signed中心化/增益乘法宽度/Q17对称舍入/15bit饱和/精度资格/缓存复位；中心值变异触发1042条FAIL；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v | TB | 415 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_result_router/ppg_adc_result_router.v | RTL | 187 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码+C12全文/C13主要边界核对：纯组合、one-hot类别、非法类别消费、复位门控；复位变异触发FAIL；F-004；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_result_router/tb_ppg_adc_result_router.v | TB | 516 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_s1_programmable_calibrator/ppg_adc_s1_programmable_calibrator.v | RTL | 310 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；代码实读：33bit最坏累加范围/Q16对称舍入/12bit饱和/载荷保持/复位；移除offset变异触发1036条FAIL；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_s1_programmable_calibrator/tb_ppg_adc_s1_programmable_calibrator.v | TB | 681 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_s1_redundancy_corrector/ppg_adc_s1_redundancy_corrector.v | RTL | 314 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；代码实读：-4..515 signed11/钳位/上下文握手/保持/复位；符号反转变异触发1031条FAIL；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_adc_s1_redundancy_corrector/tb_ppg_adc_s1_redundancy_corrector.v | TB | 577 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v | RTL | 374 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_amb_recheck_scheduler/tb_ppg_amb_recheck_scheduler.v | TB | 655 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_characterization_control_cdc/ppg_characterization_control_cdc.v | RTL | 222 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v | TB | 497 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_chip_digital_top/ppg_chip_digital_top.v | RTL | 667 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；抽读SPI pad直连/源域复位/实际层次；芯片原TB与采样时刻变异A/B；全部顶层端口仍待审；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_chip_digital_top/tb_ppg_chip_digital_top.v | TB | 893 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；SPI采样任务实读，真实边沿副本3个FAIL，F-006；P2S和其他任务未全文审；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_coarse_detection_fir/ppg_coarse_detection_fir.v | RTL | 768 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_coarse_detection_fir/tb_ppg_coarse_detection_fir.v | TB | 1191 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_config_cdc_bridge/ppg_config_cdc_bridge.v | RTL | 192 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码实读：req/ack toggle、稳定总线邮箱、busy拒绝、两域同步链与复位；ASIC约束/独立复位未签核；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/ppg_control_top.v | RTL | 1606 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；抽读注入参数/端口/AMI连线、SPI telemetry、ADC idle链；全端口/复位/owner协议仍待审；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_diag_algo_probe.v | TB | 934 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；外部wall-clock上限截断，rc=124，回归未完成，不能裁定RTL/TB自身超时；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top.v | TB | 3194 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归后台运行中；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v | TB | 1462 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_baseline_cross.v | TB | 1907 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；外部wall-clock上限截断，rc=124，回归未完成，不能裁定RTL/TB自身超时；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_fir_tail_isolation.v | TB | 1712 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；外部wall-clock上限截断，rc=124，回归未完成，不能裁定RTL/TB自身超时；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v | TB | 1532 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_injection.v | TB | 1045 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v | TB | 2216 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_lifecycle_fault_adc_anomaly.v | TB | 2172 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_long_10_cycles.v | TB | 1987 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归后台运行中；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_longrun.v | TB | 862 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归后台运行中；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_no_recheck_control.v | TB | 1111 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归后台运行中；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_normal_slow_tracking.v | TB | 1558 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归排队未运行；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v | TB | 1887 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归排队未运行；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_peak_valley_return.v | TB | 1581 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归排队未运行；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_periodic_recheck_recovery.v | TB | 1513 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归排队未运行；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v | TB | 1770 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归排队未运行；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v | TB | 1503 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus回归排队未运行；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_real_raw_generator_selfcheck.v | TB | 531 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_digital_esd_shell/ppg_digital_esd_shell.v | RTL | 97 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_digital_shell/ppg_digital_shell.v | RTL | 107 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_dual_precision_top/ppg_dual_precision_top.v | RTL | 451 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_dual_precision_top/tb_ppg_dual_precision_top.v | TB | 384 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_dynamic_baseline_cross_detector/ppg_dynamic_baseline_cross_detector.v | RTL | 1697 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v | TB | 1323 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence.v | TB | 220 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_idac_code_controller/ppg_idac_code_controller.v | RTL | 1266 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v | TB | 893 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_normal_transaction_fork/ppg_normal_transaction_fork.v | RTL | 322 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_normal_transaction_fork/tb_ppg_normal_transaction_fork.v | TB | 589 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_p2s_packer/ppg_p2s_packer.v | RTL | 218 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v | RTL | 1003 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_peak_valley_window_detector/tb_ppg_peak_valley_window_detector.v | TB | 1204 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_precision_window_controller/ppg_precision_window_controller.v | RTL | 889 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；重点读09-17两类sticky保持、START/diag-clear；START清sticky变异触发PWC-41 FAIL；全模块仍待审；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_precision_window_controller/tb_ppg_precision_window_controller.v | TB | 776 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_precision_window_integration/ppg_precision_window_integration.v | RTL | 1032 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；抽读注入直通FIR链；全部PWI协议和算法连接仍待审；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v | TB | 854 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_pulse_cdc_sync/ppg_pulse_cdc_sync.v | RTL | 110 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码实读：toggle/两级目标同步/差分脉冲；SPI4MHz下命令间隔反驳常规丢脉冲候选；任意使用条件未全量证明；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_reset_sync/ppg_reset_sync.v | RTL | 85 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码实读：异步assert/两级同步释放；跨域系统复位政策未全部核对；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v | RTL | 1519 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_sar9_sar15_safe_selection_wrapper/tb_ppg_sar9_sar15_safe_selection_wrapper.v | TB | 1116 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_spi_register_file/ppg_spi_register_file.v | RTL | 681 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；全文代码+SPI地址/位段/写属性/复位实读；38诊断及128影子字节独立对照；真实Mode0错位F-005；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_system_active_config_unpack/ppg_system_active_config_unpack.v | RTL | 211 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_system_active_config_unpack/tb_ppg_system_active_config_unpack.v | TB | 340 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_system_config_manager/ppg_system_config_manager.v | RTL | 733 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_system_config_manager/tb_ppg_system_config_manager.v | TB | 980 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v | RTL | 465 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v | TB | 511 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_timing_3200hz_validation/tb_ppg_timing_3200hz.v | TB | 266 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_timing_sar15/ppg_timing_sar15.v | RTL | 465 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_timing_sar15/ppg_timing_sar15_3200hz.v | RTL | 165 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_timing_sar15/tb_ppg_timing_sar15.v | TB | 456 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_timing_sar9/ppg_timing_sar9.v | RTL | 474 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_timing_sar9/ppg_timing_sar9_3200hz.v | RTL | 165 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；仓库strict deliverable gate已运行，规则计数已记录；仓库verilog_lint external=none返回0；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_timing_sar9/tb_ppg_timing_sar9.v | TB | 548 | 部分 | Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）；include与精确依赖可解析（来自入库filelist/TB_TABLE）；Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X；语义逐项、合同比对、变异抽查、回归完成判据尚未完成 |
| rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh | TB支持 | 806 | 部分 | include自包含编译可解析；ID出现性机械扫描；实际回归使用；未全文语义审阅；全部函数/task数值与波形语义、FAIL变异及时间边界仍待审 |
| rtl/ppg_control_top/tb_ppg_real_raw_generator.vh | TB支持 | 363 | 部分 | include自包含编译可解析；ID出现性机械扫描；实际回归使用；未全文语义审阅；全部函数/task数值与波形语义、FAIL变异及时间边界仍待审 |

## 6. 回归对比（截至本检查点）

工具为Icarus11，不是Vivado xsim；系统/芯片按原脚本`^PASS `计数，单位TB按其实际PASS样式计数，PASS:格式包括最终汇总。基线优先最新TB_MAINTENANCE_20260930的横幅；该表未给每份逐行PASS数量时不臆造。系统数字取REGRESSION_BASELINE_20260930逐TB表。每份日志路径为`evidence/compile/<TB>/run.log`；未读取summary.tsv作结论。表中“横幅一致”仅指可比文字/数字，不证明断言语义充分或全周期无X。

| TB | 本次rc | PASS行 | 最新系统基线PASS | FAIL行 | 横幅/结论 |
|---|---:|---:|---:|---:|---|
| tb_diag_algo_probe | 124 | 2 | 5 | 0 | 外部3600秒wall-clock截断，未完成 |
| tb_ppg_400hz_frame_calibration_scheduler | 0 | 59 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_active_v4_control_plane_integration | 0 | 22 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_adc_async_stage_capture | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_adc_dc_recovery | 0 | 2 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_adc_measurement_idac_integration | 0 | 48 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_adc_pipeline_overlap_corrector | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_adc_programmable_reconstructor | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_adc_result_router | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_adc_s1_programmable_calibrator | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_adc_s1_redundancy_corrector | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_amb_recheck_scheduler | 0 | 35 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_characterization_control_cdc | 0 | 26 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_chip_digital_top | 0 | 6 | 6 | 0 | 入库原TB横幅一致；真实采样副本FAIL，见F-005/F-006 |
| tb_ppg_coarse_detection_fir | 0 | 103 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_control_top | — | — | — | — | 后台运行中 |
| tb_ppg_control_top_adc_numeric_scoreboard | 0 | 69 | 69 | 0 | 入库原TB横幅一致 |
| tb_ppg_control_top_baseline_cross | 124 | 0 | 75 | 0 | 外部3600秒wall-clock截断，未完成 |
| tb_ppg_control_top_fir_tail_isolation | 124 | 0 | 80 | 0 | 外部3600秒wall-clock截断，未完成 |
| tb_ppg_control_top_idac_bus_isolation | 0 | 70 | 70 | 0 | 入库原TB横幅一致 |
| tb_ppg_control_top_injection | 0 | 15 | 15 | 0 | 入库原TB横幅一致 |
| tb_ppg_control_top_input_light_static_matrix | 0 | 73 | 73 | 0 | 入库原TB横幅一致 |
| tb_ppg_control_top_lifecycle_fault_adc_anomaly | 0 | 80 | 80 | 0 | 入库原TB横幅一致 |
| tb_ppg_control_top_long_10_cycles | — | — | — | — | 后台运行中 |
| tb_ppg_control_top_longrun | — | — | — | — | 后台运行中 |
| tb_ppg_control_top_no_recheck_control | — | — | — | — | 后台运行中 |
| tb_ppg_control_top_normal_slow_tracking | — | — | — | — | 排队未运行 |
| tb_ppg_control_top_owner_identity_backpressure | — | — | — | — | 排队未运行 |
| tb_ppg_control_top_peak_valley_return | — | — | — | — | 排队未运行 |
| tb_ppg_control_top_periodic_recheck_recovery | — | — | — | — | 排队未运行 |
| tb_ppg_control_top_robustness_corner_waveforms | — | — | — | — | 排队未运行 |
| tb_ppg_control_top_startup_idac_calibration | — | — | — | — | 排队未运行 |
| tb_ppg_dual_precision_top | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_dynamic_baseline_cross_detector | 0 | 65 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_idac_code_controller | 0 | 148 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_normal_transaction_fork | 0 | 50 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_peak_valley_window_detector | 0 | 54 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_precision_window_controller | 0 | 48 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_precision_window_integration | 0 | 5 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_real_raw_generator_selfcheck | 0 | 40 | 40 | 0 | 入库原TB横幅一致 |
| tb_ppg_sar9_sar15_safe_selection_wrapper | 0 | 52 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_system_active_config_unpack | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_system_config_manager | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_system_fault_abort_supervisor | 0 | 14 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_timing_3200hz | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_timing_sar15 | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |
| tb_ppg_timing_sar9 | 0 | 1 | 未给/横幅对照 | 0 | 入库原TB横幅一致 |

三份长TB被审阅驱动的外部上限截断（rc124），不是TB watchdog的证据。五秒诊断副本已真实推进仿真时间，排除了time0 delta循环。它们没有完成最终PASS数量对比，不能写成“回归全部通过”。剩余后台作业仍写各自run.log/run.rc，本报告为检查点静态快照。

## 7. 方法与检查点

已完成固定提交与字节一致性导出，接下来读取背景、检查环境与所有TB自包含编译。

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
