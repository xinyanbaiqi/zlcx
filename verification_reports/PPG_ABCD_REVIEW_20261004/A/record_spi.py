from pathlib import Path
B=Path(__file__).resolve().parent; p=B/'PPG_FULL_REVIEW_20261002.md';text=p.read_text(encoding='utf-8')
assert '### F-005' not in text
s1='''### F-005：SPI读回在真实Mode 0上升沿已提前移位，读字节错一bit

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

'''
s2='''### F-006：芯片TB在下降沿更新前采样SDO，掩盖F-005

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

'''
pos=text.index('### F-001');text=text[:pos]+s1+text[pos:]
pos=text.index('### F-002');text=text[:pos]+s2+text[pos:]
old='尚未完成全量审阅。当前已确认：S1=0、S2=1、S3=0、S4=0；按层：TB=1。最重要条目为F-001（4份启用注入的TB输入悬空导致正式FIR资格X）。这不代表其余范围无错误，不得将未审或工具未运行理解为通过。'
new='尚未完成全量语义审阅。已确认6条：**S1=1、S2=2、S3=3、S4=0**；按主层：RTL=1、TB=2、合同=2、矩阵·台账=1。最重要为F-005（真实Mode 0 SPI读流提前一bit）及F-006（原芯片TB采样竞争掩盖错误）；F-001为4份注入TB的正式FIR资格X。未审、未完成工具检查和仅编译通过不能理解为功能通过。'
assert old in text;text=text.replace(old,new).replace('审阅日期：2026-10-02（Asia/Shanghai）。','审阅日期：2026-10-02至2026-10-03（Asia/Shanghai）。').replace('- 工具环境与检查日志保存在 evidence/；仿真结果尚未产生。','- 工具环境与实际编译/仿真/变异日志保存在 evidence/；已产生结果按每份run.log记录。')
text+='''
### 检查点②-B：SPI真实边沿与TB变异（已完成本子批）

F-005/F-006是新确认的S1/S2；没有修复源仓库。SPI地图38字节及全部写寄存器已作静态核对；独立physical探针暴露串行相位错误，legacy与仓库外假设控制通过全部38+128字节。上述通过只代表对照条件，不能当作入库RTL按真实Mode 0通过。

六项模块TB变异均编译成功并触发FAIL：S1冗余符号1031条、S1移除偏置1036条、重构中心1042条、PWC START清sticky 4条、Router删除复位门控2条、scheduler移除sample-index匹配1条；全部变异仅在evidence/mutations/。原TB判据检查FAIL文本，变异进程退出0本身不算PASS。

系统长仿真五秒诊断副本已推进至1768101500 ps（1.768ms）并完成JNT前缀54比较；因此不是时间0无穷delta循环，但Icarus速度不等同历史xsim。现有每份3600秒外部wall-clock上限可能截断大规模仿真；这样的外部截断须记为回归未完成，不能冒充TB自身超时或RTL死锁。日志evidence/compile/tb_ppg_control_top_baseline_cross/progress_probe.log。
'''
p.write_text(text,encoding='utf-8');print('RECORDED F005 S1 F006 S2')
