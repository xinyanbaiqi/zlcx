# V1 同拍冲突矩阵：SPI寄存器文件（`ppg_spi_register_file.v`，对照芯片顶层合同）

- 任务：P0-V1 续，模块10/12；基线main `a1ba482`；只读；纯静态（没有仿真器）
- 合同：`contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md`（下称CHIP），重点是第9节第11项和0x0090寄存器行（266行）

## 0. 结构与记号

18个always块：
- 16个时序块：SPI_SCLK（`i_source_clk`）域12个，其中协议引擎7个带`posedge i_spi_cs_n`异步复位、1个在下降沿；2 MHz（`i_clk`）域3个；
- 2个组合块：386 `state_next`，595 `dec_read_byte`。

`grep -c always`得19，多出的一个是第24行修订记录中的文字。

命令字节0x0090（291–299）：在DATA阶段的字节边界写入命中时，bit0=START、bit1=STOP、bit2=COMMIT、bit3=DIAG_CLEAR、bit4=ABORT、bit5=表征更新。各位互相独立地产生触发：
- START/STOP/DIAG_CLEAR/ABORT各经一个`ppg_pulse_cdc_sync`进入2 MHz域（612–650）；
- COMMIT留在source域（364），交给配置CDC桥；
- 表征更新经`flag_char_request_held`握手。

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| 0x0090命令位 | 291–299，各位独立相与 | 同一字节中多位同时为1 | (b)（本模块），系统级见引用 | CHIP第9节第11项与266行：“允许一次原子写入同时置位多个bit…SPI从机自身不得为此新增任何互斥/优先级限制逻辑，消歧完全依赖`ppg_control_top`”。本模块按合同实现。系统级消歧在control_top并不成立：0x11见V1-SCH-C3，0x03与0x09见V1-MGR-C2，0x0A见V1-MGR-C3。另外，四个CDC实例是独立的双触发器同步器，同一字节中两位到达2 MHz域可能相差±1拍（V1-MGR §0.1），所以系统级结果不确定 | 是：chip TB覆盖0x03/0x09/0x0A/0x11/0x12/0x18 |
| `reg_active_shadow`（495）× COMMIT | 影子写在0x0000–0x007F的字节边界；COMMIT在0x0090的字节边界 | 影子写 × COMMIT | (a) | 每个SCLK字节边界只写一个地址，影子与命令不可能同拍 | 否 |
| 〃 | — | COMMIT时配置CDC桥忙 | (b) | 桥在忙期间丢弃新请求，不合并（`ppg_config_cdc_bridge.v` 139–141），本模块注释“忙碌丢弃由既有CDC桥内部处理”（364）；主机可从0x0109 bit0（`i_source_config_update_ready`）判断 | 否 |
| `reg_characterization`（506）× 表征更新触发 | 前者写0x0080，后者是0x0090 bit5 | — | (a) | 地址不同，不同字节边界 | 否 |
| `flag_char_request_held`（528） | 新触发置1 > ready清0 | 新触发 × ready | (b) | 置位胜出，新请求继续等待一次握手，读取的是最新的`reg_characterization` | 否 |
| 协议引擎（377 state、418 `cnt_field_byte`、437 `reg_byte_addr`、452 `flag_cmd_is_read`、463 `reg_read_byte`、477 `cnt_bit_in_byte`、486 `reg_shift_in`） | `i_source_rstn`低或CS_N高时异步复位 > 各自的字节边界条件（按状态互斥） | CS_N释放 × 字节边界 | (b) | brief §3.4 F-030：CS_N作异步复位与门控，合同按四点安全论证写入（ABCD §12.5）。各寄存器的字节边界分支按`state_current`互斥 | 否 |
| `reg_read_byte`（463，下降沿） | 装载 > 移位 | — | (a) | 装载只在每字节第0位，移位在其余位 | 否 |
| `reg_dbg_out_select`（517） | 0x0081写入 | — | — | 单写者；CDC缺陷已在V1.14修复（CHIP 33行） | — |
| `reg_mr_latch`/`reg_dd_latch`（573/584，2 MHz） | discard事件时锁存身份并翻转bit0 | 事件 × 读快照捕获（`w_capture_trigger`）同拍 | (b) | 快照取的是锁存器当前值（事件前），新值出现在下一次读中；翻转位语义见CHIP 305行 | 否 |
| `reg_diag_snapshot`（541）→`reg_diag_snapshot_gated`（553）→`reg_diag_sync_stable`（564） | 2 MHz域捕获 → 门控事件回到source域采样 → 下一拍稳定 | — | (b) | V1.3/V1.15已修复的CDC结构，不是置位/清零冲突；本次不复核时序余量 | 否 |

## 2. 汇总与清单

- 本模块(c)：0项（按合同实现）；系统级同字节多命令问题记在V1-SCH-C3、V1-MGR-C2、V1-MGR-C3。
- 建议给B批次：CHIP第9节第11项写的“消歧完全依赖ppg_control_top已有的合并/优先级处理”与实际时序不符（START直连、STOP与诊断清除各寄存一拍、ABORT派生STOP寄存两拍，外加CDC偏斜±1拍），合同需要写明各组合的实际语义，或者规定为非法组合。
- always块（18个，全部覆盖）：377、386（组合）、418、437、452、463、477、486、495、506、517、528、541、553、564、573、584、595（组合）。
