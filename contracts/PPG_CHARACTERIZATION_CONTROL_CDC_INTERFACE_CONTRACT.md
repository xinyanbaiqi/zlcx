# PPG表征控制CDC接口合同

> Current normative version: V1.1. Substantive interface-freeze date: 2026-08-14; metadata baseline date: 2026-08-20. Status: `ACTIVE_NORMATIVE`; system closure is `NOT_CLOSED` until the current matrix audit records zero defects. RTL/TB evidence is `EVIDENCE_PENDING`.
> V1.2修订日期：2026-10-09。B合同合并批次（`verification_reports/B_MERGE_BATCH_ITEMS.md` BMI-182，F-039，按基线`7a8eabf` `ppg_control_top.v`核对）：第11节“复位后必须重新完成至少一笔合法6-bit提交，才能允许新的START”与第10.1节“NORMAL和外部固定电流START不以`o_control_valid`为硬门槛”矛盾。RTL中`o_control_valid`（Top `ccc_control_valid_o`）只导出观测，不门控任何START；复位后`o_static_characterization_enable=0`，所以只有STATIC_BIAS START在事实上需要先完成一笔合法提交。第11节该句按此订正（原文保留于删除线中）。
> V1.1 change record: replaces a non-normative bridge RTL dependency and stale downstream versions with active-contract authority. CDC protocol and payload behavior do not change.  
> Historical display of the substantive interface-freeze date: 2026-08-14.
> 目标RTL：`ppg_characterization_control_cdc.v`  
> 目标TB：`tb_ppg_characterization_control_cdc.v`  
> 源时钟域：SPI配置源域  
> 目标时钟域：2 MHz数字系统域  
> 原子载荷宽度：6 bit  
> RTL语言：可综合Verilog-2001
> Historical evidence (non-normative): the V1.0 CDC RTL/TB and `xsim_ccc.log`
> once reported CCC-01 through CCC-26 as passing. This neither closes the current
> CDC contract nor proves input-source qualification, STATIC_BIAS permission or
> downstream Scheduler/AMI/SSW behavior; current implementation evidence is
> `EVIDENCE_PENDING`.

## 1. 合同目的

本文冻结独立表征控制从SPI配置源域到2 MHz数字系统域的跨时钟传输、原子提交、运行期更新和异常边界。

该CDC只传输以下两项控制：

```text
static_characterization_enable
test_mux_ctrl[4:0]
```

两项控制不属于640-bit ACTIVE V4，不得占用V4保留位，也不得由SPI shadow直接驱动SAR安全选择wrapper或模拟测试MUX。

本文不定义SPI地址、SPI物理协议、STATIC_BIAS模拟静态向量或SAR波形。其职责只是把完整的6-bit source快照可靠地转换为2 MHz域的已提交控制状态。

## 2. 依赖追踪与冲突优先级

**当前规范依赖（可决定CDC语义）**

1. C06 — `ppg_system_integration/PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md` V1.3；
2. C03 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V1.7；
3. C01 — `ppg_system_integration/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` V1.10；
4. C09 — `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` V1.11；
5. C02 — `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` V4.10。

The request/acknowledge toggle protocol is defined by this contract's Sections
3-7 and the C03 CDC boundary. `ppg_config_cdc_bridge.v`, RTL/TB and historical
logs are non-normative evidence or conflict-discovery material; they cannot
define a CDC endpoint, reset policy or payload ordering.

发生冲突时采用：

```text
用户最新明确确认
    > 本合同的表征控制CDC端口和传输语义
    > 当前规范依赖中的输入源、CDC、SAR和数字顶层连接合同
    > 历史RTL、旧顶层和旧注释
```

`PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md` 中“STOP或abort清除测试上下文”指撤销当前RUN和模拟输出上下文，不要求擦除已经提交的CDC配置寄存器，也不允许用STOP或abort异步复位CDC握手相位；它不清除AMI/PWI检测pending，检测链仍只能由AMI generation-scoped detection-discard释放。

## 3. 模块职责与禁止行为

`ppg_characterization_control_cdc`必须：

1. 在source域保持一笔完整6-bit快照直到目标域应答返回；
2. 使用单一请求/应答事务原子传输六个bit；
3. 在2 MHz域同一时钟沿提交两个控制字段；
4. 在RUN期间阻止`static_characterization_enable`改变；
5. 允许STATIC_BIAS运行期间原子更新`test_mux_ctrl[4:0]`；
6. 保持已提交控制，直到下一笔合法提交或复位；
7. 区分source传输握手、目标域提交事件和目标域拒绝事件。

禁止：

- 对六个bit分别实例化单bit同步器；
- 组合跨接source shadow到目标输出；
- 用固定延时假定SPI域与2 MHz域相位关系；
- 在CDC内部生成START、STOP、abort或模拟安全向量；
- 将CDC提交事件解释为STATIC_BIAS已经进入或START已经接受；
- 在RUN期间部分接受非法快照中的MUX字段。

## 4. 固定原子载荷

source域和目标域的打包顺序固定为：

```text
control_snapshot[5]   = static_characterization_enable
control_snapshot[4:0] = test_mux_ctrl[4:0]
```

不得交换bit顺序、补符号位、拆成两笔CDC事务或在目标域重新编码。

目标域每次只能接受或拒绝完整6-bit快照。若一笔更新不合法，六个已提交bit必须全部保持原值。

## 5. 冻结端口

### 5.1 SPI配置源域

| 端口 | 宽度 | 方向 | 语义 |
| --- | ---: | --- | --- |
| `i_source_clk` | 1 | 输入 | SPI配置源域时钟 |
| `i_source_rstn` | 1 | 输入 | source域低有效复位 |
| `i_source_update_valid` | 1 | 输入 | 保持型更新请求valid |
| `o_source_update_ready` | 1 | 输出 | 当前可以在source时钟沿接受完整快照 |
| `i_source_static_characterization_enable` | 1 | 输入 | source域待提交STATIC_BIAS使能 |
| `i_source_test_mux_ctrl[4:0]` | 5 | 输入 | source域待提交测试MUX码 |

### 5.2 2 MHz目标域

| 端口 | 宽度 | 方向 | 语义 |
| --- | ---: | --- | --- |
| `i_clk` | 1 | 输入 | 2 MHz数字系统时钟 |
| `i_rstn` | 1 | 输入 | 2 MHz域低有效复位 |
| `i_run_enable` | 1 | 输入 | V4控制平面已经进入RUN的电平资格 |
| `i_diag_clear_event` | 1 | 输入 | 2 MHz域诊断清除单拍 |
| `o_static_characterization_enable` | 1 | 输出 | 2 MHz域已提交STATIC_BIAS使能 |
| `o_test_mux_ctrl[4:0]` | 5 | 输出 | 2 MHz域已提交测试MUX码 |
| `o_control_valid` | 1 | 输出 | 复位后至少一笔合法控制已经提交 |
| `o_control_update_event` | 1 | 输出 | 一笔合法6-bit快照提交成功的单拍 |
| `o_control_reject_event` | 1 | 输出 | 一笔传输到达但因RUN规则被整笔拒绝的单拍 |
| `o_protocol_error_sticky` | 1 | 输出 | 记录运行期间非法改变模式或无初始提交启动的诊断 |

`i_run_enable`只用于目标域提交资格检查，不得由CDC改写或延迟。START、STOP和`control_abort_event`不作为本模块端口，具体边界见第10节。

## 6. Source域保持型握手

source事务接受条件固定为：

```text
source_fire = i_source_update_valid && o_source_update_ready
```

规则如下：

1. source端必须从`i_source_update_valid=1`开始保持valid和两项载荷不变，直到`source_fire`发生；
2. `source_fire`所在时钟沿锁存完整6-bit快照并发起一次请求翻转；
3. 请求在途期间`o_source_update_ready=0`，锁存快照不得被后续shadow写入覆盖；
4. 目标域应答经两级同步返回后，`o_source_update_ready`重新为1；
5. busy期间出现的新shadow写入可由SPI寄存器层保存，但不得覆盖本模块正在传输的快照；
6. 本模块不设置第二笔队列，不合并多次请求，也不重复消费持续为高的valid；
7. 上一笔握手完成且valid先撤销后，才允许把下一笔更新解释为新事务。

`o_source_update_ready`表示CDC邮箱可以接受一笔传输，不表示目标域已经通过RUN合法性检查。最终结果必须由`o_control_update_event`或`o_control_reject_event`区分。

## 7. CDC实现与原子性

RTL必须复用或严格等价实现已验证的请求/应答翻转邮箱：

```text
source valid/ready fire
    -> source锁存6-bit稳定快照
    -> request toggle跨入2 MHz域，两级同步
    -> 目标域读取已经保持至少同步延迟的多bit快照
    -> 目标域合法性判断并原子提交或整笔拒绝
    -> acknowledge toggle返回source域，两级同步
    -> source ready恢复
```

推荐实现为实例化：

```verilog
ppg_config_cdc_bridge #(
    .C_CONFIG_WIDTH(6)
)
```

语义wrapper必须把保持型source valid/ready转换成通用bridge的一次`i_source_update`接受事件，并在目标域对bridge输出增加本合同第8节的运行期合法性检查。

请求和应答同步链必须使用两级触发器，并对同步寄存器标注适用的`ASYNC_REG`综合属性。多bit数据总线依靠source快照在完整请求/应答期间保持稳定，不得对每个数据bit独立同步。

两个时钟域之间不得存在组合反馈路径。CDC延迟由两域相位和频率决定，合同不冻结固定周期数，但保证每笔被接受事务最终只产生一次目标域提交或拒绝。

## 8. 目标域提交规则

bridge传输到达后，目标域按以下优先级处理：

```text
i_rstn == 0
    -> 清零已提交控制、valid和事件

新传输到达 && i_run_enable == 0
    -> 接受完整6-bit快照

新传输到达 && i_run_enable == 1
                 && o_control_valid == 1
                 && incoming_static_enable == committed_static_enable
    -> 接受完整6-bit快照

其他新传输到达
    -> 整笔拒绝，保持六个已提交bit
```

合法接受时：

- `o_static_characterization_enable`和`o_test_mux_ctrl`在同一`i_clk`上升沿更新；
- `o_control_valid`置1并保持；
- `o_control_update_event`只拉高一个2 MHz周期；
- `o_control_reject_event`保持0。

非法拒绝时：

- 两个已提交字段均保持原值；
- `o_control_valid`保持原值；
- `o_control_update_event`保持0；
- `o_control_reject_event`只拉高一个2 MHz周期；
- `o_protocol_error_sticky`置1。

重复提交与当前值完全相同的合法快照仍是一笔真实提交，必须产生一次`o_control_update_event`。

## 9. STATIC_BIAS运行时更新

进入STATIC_BIAS RUN之前，`o_control_valid`必须已经为1、已提交使能位必须为1，且source侧必须等到对应传输应答返回后才允许发起START。NORMAL和外部固定电流RUN可以使用复位后的安全默认值`static_characterization_enable=0`、`test_mux_ctrl=5'b0`，不要求预先提交测试控制。

### 9.1 STATIC_BIAS运行期间

```text
i_run_enable = 1
o_static_characterization_enable = 1
```

允许提交新的`test_mux_ctrl[4:0]`，但source快照中的`static_characterization_enable`必须继续为1。合法提交后五位MUX码在同一2 MHz时钟沿改变，不允许出现逐bit过渡。

SSW可直接使用`o_test_mux_ctrl`驱动STATIC_BIAS的`S[4:0]`。模拟稳定时间和测试仪器采样等待时间由片外流程负责，不由CDC产生延时。

### 9.2 NORMAL或固定电流RUN期间

RUN期间`static_characterization_enable`同样不得改变。`test_mux_ctrl`可以预装为新的已提交值，但SSW必须继续依据自身合同在非STATIC_BIAS状态输出`S[4:0]=5'b0`，因此该更新不得改变任何模拟工作路径。

### 9.3 非法运行期模式切换

以下操作必须整笔拒绝：

```text
RUN中 0 -> 1：禁止从NORMAL/固定电流直接进入STATIC_BIAS
RUN中 1 -> 0：禁止从STATIC_BIAS直接退出到动态SAR工作
```

模式切换必须先完成STOP和系统排空，使`i_run_enable=0`，再提交新的6-bit快照，确认`o_control_update_event`后重新START。

## 10. START、STOP与abort边界

### 10.1 START

本模块不接收START事件。上层在请求STATIC_BIAS START时必须同时满足以下条件：

1. `o_control_valid=1`；
2. 对应source更新已经完成请求/应答闭环；
3. `o_protocol_error_sticky`没有被系统策略判定为阻断故障；
4. V4配置及其他模拟安全资格已经满足。

NORMAL和外部固定电流START不以`o_control_valid`为硬门槛，但必须继续使用本合同规定的安全默认值或最近一笔合法提交值。

START之后，`static_characterization_enable`冻结到STOP；只有MUX码允许按第9节规则更新。

### 10.2 STOP

STOP由V4控制平面、调度器和SSW处理，不作为CDC复位。STOP期间：

- CDC不得产生模拟控制或自行撤销SSW波形；
- 已提交6-bit控制和`o_control_valid`保持；
- 已被source握手接受的CDC事务允许完成；
- SSW必须依据STOP和`i_run_enable`撤销STATIC_BIAS或动态SAR输出；
- `i_run_enable=0`后可以提交下一次RUN使用的新模式和MUX码。

因此STOP后的安全向量来自SSW，不来自清零CDC配置。

### 10.3 `control_abort_event`

abort由系统故障路径直接送SSW、AMI和调度器，不作为CDC端口或握手复位。abort期间：

- SSW立即撤销模拟控制和当前RUN上下文；
- CDC已提交配置保持，不重新产生提交事件；
- 已经在途的CDC传输可以完成，但只能更新配置状态，不能恢复被abort撤销的模拟动作；
- 重新START前仍必须重新满足第10.1节资格；
- abort不能与source或目标域复位混用来强制重置请求/应答toggle。

“abort后不得恢复旧测试上下文”指不得恢复旧RUN、旧事务或旧模拟波形，不表示必须擦除软件已经提交的静态配置值。

## 11. 复位规则

`i_source_rstn`和`i_rstn`均为所属时钟域的低有效复位。系统必须由同一芯片级复位源同时断言两个域的复位，允许在各自时钟域独立同步释放。

复位时：

```text
source锁存快照              = 6'b000000
request/acknowledge toggle  = 初始一致相位
o_source_update_ready       = 复位释放并恢复一致相位后为1
o_static_characterization_enable = 0
o_test_mux_ctrl             = 5'b00000
o_control_valid             = 0
o_control_update_event      = 0
o_control_reject_event      = 0
o_protocol_error_sticky     = 0
```

复位断言必须取消所有在途CDC事务，复位释放不得产生伪提交或伪拒绝事件。~~复位后必须重新完成至少一笔合法6-bit提交，才能允许新的START。~~ V1.2订正（F-039）：复位后必须重新完成至少一笔合法6-bit提交，才能允许新的STATIC_BIAS START（第10.1节）；NORMAL和外部固定电流START不以此为门槛，继续使用复位安全默认值。

只复位单一时钟域而保持另一域继续运行不属于合法系统操作，因为会破坏toggle事务代际。TB必须覆盖共同断言、不同步释放，但不得把单域独立复位定义为正常运行功能。

## 12. 稳定性与诊断

### 12.1 输出稳定性

除合法`o_control_update_event`对应的目标时钟沿外，两个已提交输出必须保持不变。拒绝、诊断清除、STOP、abort和source shadow写入均不得改变已提交控制。

`o_control_update_event`与`o_control_reject_event`互斥，且每笔bridge传输最多产生其中一个事件。

### 12.2 Sticky诊断

`o_protocol_error_sticky`在以下任一场景置1：

1. `i_run_enable=1`且尚无首笔合法提交时收到更新；
2. RUN期间新快照试图改变`static_characterization_enable`；
3. 实现检测到同一传输同时产生提交和拒绝事件。

sticky只在`i_rstn=0`或`i_diag_clear_event=1`时清除。若清除与新错误同拍发生，新错误置位优先。读取状态不得自动清除。

## 13. 顶层连接要求

最终数字顶层必须：

1. 实例化且只实例化一个`ppg_characterization_control_cdc`；
2. 将SPI表征shadow和保持型更新请求连接source端口；
3. 将V4控制平面`o_run_enable`连接`i_run_enable`；
4. 将已提交两个输出逐位连接SSW的`i_static_characterization_enable`和`i_test_mux_ctrl`；
5. 仅在CHARACTERIZATION/STATIC_BIAS START前将`o_control_valid`和已提交使能位纳入模拟/控制资格；
6. 导出或汇总reject事件和sticky诊断；
7. 禁止SPI shadow、source快照或bridge内部总线旁路到SSW；
8. 不得把`o_control_update_event`接成START、STOP或SAR事务fire。

`PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`后续小版本修订必须补充本节的直接实例层次和连接，不改变已冻结的四个功能wrapper内部算法。

## 14. 自检验收矩阵

自检TB必须使用异步、非整数相位关系的source时钟和2 MHz目标时钟，至少覆盖：

| 编号 | 场景 | 验收要求 |
| --- | --- | --- |
| CCC-01 | 共同复位 | 两域状态、输出、valid和事件清零 |
| CCC-02 | 复位释放偏斜 | 不产生伪提交、伪拒绝或sticky |
| CCC-03 | 首笔提交 | 6-bit快照逐位正确并置valid |
| CCC-04 | 固定打包 | bit5为使能，bit4:0为MUX，无重排 |
| CCC-05 | source保持型valid | ready为0时valid和载荷保持后最终只接受一次 |
| CCC-06 | source反压 | 在途期间ready保持0，不覆盖旧快照 |
| CCC-07 | 目标域原子更新 | 六个输出只在同一目标时钟沿改变 |
| CCC-08 | 单拍事件 | 每次合法提交只产生一个update脉冲 |
| CCC-09 | 输出保持 | 无新合法提交时控制长期稳定 |
| CCC-10 | 连续事务 | 前一应答返回后下一笔无丢失、无重复 |
| CCC-11 | 相同值重提交 | 输出值不变但产生一次真实update事件 |
| CCC-12 | 随机时钟相位 | 不同相位下逐位结果和事务数量一致 |
| CCC-13 | STATIC_BIAS更新MUX | RUN中保持使能1并原子更新五位MUX |
| CCC-14 | STATIC_BIAS禁止退出 | RUN中1到0整笔拒绝 |
| CCC-15 | 动态模式禁止进入 | RUN中0到1整笔拒绝 |
| CCC-16 | 拒绝无部分提交 | 非法快照的使能和MUX均不改变 |
| CCC-17 | NORMAL隔离 | RUN中MUX预装不要求SSW产生S输出变化 |
| CCC-18 | STOP保持配置 | STOP不清除已提交值或valid |
| CCC-19 | STOP后改模式 | run_enable为0后允许提交新模式 |
| CCC-20 | abort隔离 | abort撤销消费者上下文，不产生CDC伪事件 |
| CCC-21 | 在途传输后STOP/abort | 事务最多产生一次目标结果且不恢复模拟动作 |
| CCC-22 | sticky清除 | 诊断清除不改变配置，错误与清除同拍时错误优先 |
| CCC-23 | 复位取消在途 | 共同复位后旧请求不迟到提交 |
| CCC-24 | 无shadow旁路 | 未握手shadow变化不影响目标输出 |
| CCC-25 | 首笔前RUN违规 | 无valid时RUN内到达更新被拒绝并置sticky |
| CCC-26 | 事件互斥 | update与reject永不同拍为1 |

所有PASS必须来自真实端口、时钟边沿、握手次数、提交值和事件计数比较。禁止使用`force`、内部层次改值、行为替身或仅打印PASS。

## 15. 工具验证与交付要求

RTL与TB实现后必须完成：

1. formatter-AST严格门：RTL和TB均为0 error、0 strict warning；
2. 独立Verilog lint：0 error、0 warning；
3. Vivado `xvlog`、`xelab`和`xsim`；
4. CCC-01至CCC-26全部由真实比较通过；
5. Vivado OOC综合：0 error、0 critical warning；
6. Latch=0，Blackbox=0；
7. 2 MHz目标时钟时序满足；
8. 记录LUT、寄存器、DSP、WNS/TNS和非阻断警告。

CDC实现还必须检查：

- 请求和应答同步器存在且带`ASYNC_REG`属性；
- 多bit总线在请求/应答期间保持；
- 不存在组合跨域路径或组合环；
- 不把source和destination时钟当作数据或生成门控时钟；
- 复位释放不产生伪toggle检测。

## 16. 正式冻结结论

V1.0正式冻结：

```text
source 6-bit shadow
    -> 保持型valid/ready接受
    -> 单一请求/应答CDC邮箱
    -> 2 MHz域整笔合法性判断
    -> 原子提交或整笔拒绝
    -> stable committed controls
```

- `static_characterization_enable`和`test_mux_ctrl[4:0]`必须作为一个6-bit快照传输；
- RUN期间模式使能不可改变，STATIC_BIAS期间五位MUX允许原子更新；
- STOP和abort撤销消费者运行上下文，但不擦除已经提交的CDC配置；
- 只有共同复位清除CDC状态和valid；
- 顶层必须使用已提交输出和valid，禁止source shadow旁路；
- 后续RTL、TB和顶层连接必须逐项满足CCC-01至CCC-26。

任何端口、打包顺序、RUN更新资格、STOP/abort或复位语义修改，必须先版本化修订本合同。
