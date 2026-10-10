# D04 / D06 定因报告（仓库外实验）

两项跨仿真器差异均已证实由 TB 同沿计数更新/读取竞争导致。错开临时TB相关统计/读取及输入驱动时刻、不改RTL后，扩展实验得到一致的PASS、$finish、事务输出/丢弃序列和精确拍号；最小读取补丁足以消除本次结果计数或finish差异。D06 根因位于 SMOKE-23；SMOKE-17 ready 同沿驱动是另一个候选，单独修改未消除 D06。

源码：`66bebdfabe9e1cb173c34a0ce44e48ba4230398d`。实验平台：WSL Debian 的 Icarus Verilog 11.0 stable，本机 Vivado/XSIM 2019.2。此前对照日志为 XSIM 2022.2；本次没有运行 2022.2 或 Icarus 12。本机2019.2原始运行复现了已报告的两个差异，因此本次定因有实测支持；RC1 时仍应以统筹的2022.2/12环境复核正式补丁。

## 对照结果

下列每次均编译成功、正常 $finish、0 FAIL；PASS逐行精确比较，不放宽容差。`RUN_RESULTS.json` 保存各次精简结果及 PASS 文本。

| TB / 临时版本 | Icarus 11 | XSIM 2019.2 | 结论 |
| --- | --- | --- | --- |
| D06 原始 | 73 PASS；49 ADC/34 results；1655648.5 ns | 73 PASS；49 ADC/33 results；1655648.5 ns | 复现原差异 |
| D06 候选：SMOKE-17 ready下降沿 + 结果计数#1更新 | 34 results | 33 results | 未消除差异，不能据此归因SMOKE-17 |
| D06 扩展错开时序：上述候选 + owner计数/身份#1更新，SMOKE-23下降沿读取 | 73 PASS；49 ADC/34 results；1655648.5 ns | 完全相同 | 确認TB竞争；STOP时刻选择改变输出笔数 |
| D06 最小：仅SMOKE-23两个读取点加#1 | 73 PASS；49 ADC/33 results；1655648.5 ns | 完全相同 | 两行修改足以消除差异，并保留原XSIM结果计数 |
| D04 原始 | 20 PASS；11361750 ns | 20 PASS；11362750 ns | 复现1000 ns（两拍）差异 |
| D04 错开时序：reset释放#1、lost计数#1更新、相关等待下降沿读取 | 20 PASS；11361750 ns | 完全相同 | 差异消失 |
| D04 最小：仅wait_chip_lost读取点加#1 | 20 PASS；11361750 ns | 完全相同 | 一处修改足以消除差异，无需改变复位或RTL |

扩展D06得到34、最小D06得到33并不矛盾：两个实验选择了不同的 STOP 排期。消竞争后每个实验在两边一致，不把某个总数当成对所有刺激都恒定的黄金值。

## D06 原始 TXN 的去向

差异唯一涉及复位命名空间0、RUN15的 RED NORMAL SAR9事务：frame_id=1、sample_index=2、color_ir=0、frame_type=2、precision=0。这不是重复计数；缓冲槽状态和载荷替换核对显示，该笔在两边的真实去向不同。

全局cycle从第一次posedge记1，D06 TB实际周期13 ns。

| 原写法事件 | Icarus：cycle / ns | XSIM：cycle / ns |
| --- | --- | --- |
| 该owner成功完成 | 126033 / 1638422.5 | 126033 / 1638422.5 |
| 同帧IR sample=3 owner建立 | 126035 / 1638448.5 | 126035 / 1638448.5 |
| STOP_ACK出现 | 126038 / 1638487.5 | 126037 / 1638474.5 |
| RED sample=2装入正式结果槽 | 126038 / 1638487.5 | 126038 / 1638487.5 |
| RED sample=2终结 | 126039 / 1638500.5：valid&&ready输出，计数32→33 | 126039 / 1638500.5：STOP丢弃，discard_event=1/reason=0，计数保持32 |
| 后续真正复位 | 126375后 / 1642875 | 同时刻 |

因此差异笔不是被后续复位清掉。XSIM早一拍STOP，使正式结果被STOP遮蔽并丢弃；Icarus晚一拍STOP，先允许该笔真实输出。原始两边总输出集合只差这一个TXN；其余输出身份一致。

最小补丁后，两边STOP_ACK都在126037拍，正式结果在126038拍装入，126039拍STOP丢弃；总结果33，两边完整输出/正式丢弃身份序列一致，SMOKE-23差异笔的时间和拍号一致。最小补丁未处理SMOKE-17等其他等待点，其RUN11前两笔输出仍相差13 ns，另有四个STOP_ACK相差13或26 ns；它们不再导致本次D06总数差异，不能称最小补丁消除了全套时序竞争。扩展补丁后，STOP_ACK都在126038拍，该笔在126039拍输出；总结果34，两边完整输出/正式丢弃事件及START/STOP/复位和$finish之前的READY观测，身份、时间和拍号全部一致。

TXN证据保留了观测限制：结果槽未直接导出独立RUN代际，因此表中RUN15通过当前RUN和已接受owner身份关联，并用复位epoch避免身份复用。原始公开discard_generation在该事件实测为0，`TXN_EVIDENCE.tsv`保留原始字段值，空字段以 `-` 表示，未将其伪装为15，也未把代际字段本身判为本次跨仿真器差异原因。这个字段的独立合同一致性不在本轮结论中。

## D04 原始 TXN / 排期证据

D04时钟周期500 ns。原始两边均真实输出相同五笔结果，输出的身份、时间和拍号全部一致，没有发现“一边输出、另一边STOP/复位丢弃”的结果差异。三笔completion-lost均是owner超时作废，没有正式结果输出；身份分别为 RUN7/frame0/sample0/IR、RUN7/frame1/sample1/IR、RUN8/frame0/sample0/IR，均为NORMAL SAR9、复位epoch0。两边身份相同，只有第三笔时刻随TB排期移动。

| 原始事件 | Icarus：cycle / ns | XSIM：cycle / ns |
| --- | --- | --- |
| RUN7首次lost | 12118 / 6058750 | 同左 |
| lost计数达到1 | 12119 / 6059250 | 同左 |
| RUN7第二次lost | 17118 / 8558750 | 同左 |
| lost计数达到2 | 17119 / 8559250 | 同左 |
| lost计数复归0的TB刺激时刻 | 17606后 / 8803125 | 17607后 / 8803625 |
| RUN8 START_ACK | 17609 / 8804250 | 17610 / 8804750 |
| RUN8 lost | 22275 / 11137250 | 22276 / 11137750 |
| RUN8 STOP_ACK | 22296 / 11147750 | 22298 / 11148750 |
| $finish | 22724 / 11361750 | 22726 / 11362750 |

计数信号本身在同一拍增加，等待进程能否在当拍看到新值取决于Active区顺序，继而移动后续SPI命令/STOP排期。最小补丁仅在wait_chip_lost的posedge后加#1，再执行原有cnt_wd增量及循环判定；原超时上限未变。两边lost、START/STOP与结果事件的序列及拍号全部一致，finish同为11361750 ns。故D04是TB排期竞争，不是观察到的RTL事务丢失。

## 实验改动与复现

最终因果隔离用 `tb_ppg_control_top.minimal.diff` 和 `tb_ppg_chip_digital_top.minimal.diff`；扩展错开输入/统计时序的对照用两个 `full_timing.diff`。全部diff仅作用于仓库外独立TB副本。没有强制RTL内部状态，没有改变PASS断言、结果接受范围或等待上限。

复现时导出该源码revision的rtl和相关include，按原 `xsim_main_filelist.f` / `xsim_chip_digital_top_filelist.f` 完整编译，仅将相应TB路径换成临时副本。Icarus参数为 `-g2001 -s <TB>`，XSIM使用 `xvlog` + `xelab -debug all -timescale 1ns/1ps` + `xsim run all`。先跑原始副本，再在各自新目录应用最小diff并重跑；不能把实验补丁应用回仓库。

四份原始无跟踪运行和四份原始VCD跟踪运行的PASS/$finish逐项相同，排除了本次只读观察改变原始差异的情况。Icarus VCD观察模块只有initial/$dumpvars，无always或输入赋值；XSIM由Tcl只读log_vcd同一组信号。XSIM最后一次VCD变化在$finish前1 ns，Icarus记录了$finish同一时间槽的ready恢复；该恢复后没有时钟采样，未将它当成运行期事务差异。$finish时间始终取实际finish日志/VPI，不能用最后VCD时间代替。波形按时间槽合并为结算状态，以正式缓冲pending/载荷替换及discard事件判断去向，避免在同沿新增TB计数器重复引入竞争。实验使用的仓库外 `parse_trace.py` 是VCD解析器，不是第二个Verilog解析器。

最长单次预算14400秒，全部自然结束，未缩短激励。XSIM最初一次Tcl路径转义失败返回0但没有$finish，已修正并重跑；编译/运行中修正过临时补丁生成错误及注释位置，仅以最终完整版本为证据，未将这些尝试计入有效通过。

## V9归档与本阶段收尾

统筹已认可D04、D06为TB同沿竞争，不是RTL竞争，并授权归档证据和更新结论。新增V9问题Q01/Q02已纳入 [V9清单](V9_TB_TOLERANCE_INVENTORY.md)，总数由32增至34。对应V16结论见 [试跑记录](V16_IVERILOG_CROSSCHECK_TRIAL.md)。13份系统级TB保留为compile-only，RC1后由统筹用Icarus12和既有脚本补跑正式V16。

实验完成时仓库工作区干净，HEAD为 `bd5cfe2cc59e54c1c4bacf02aca2337257b8eae8`，实验未产生提交或推送；`SOURCE_INTEGRITY.json`保留该时点自查快照。本次后续归档提交仅新增报告/证据，并按统筹明确授权更新V16报告与V9清单，不改TB、RTL、合同或仿真入口。导出的484个源文件哈希全部未改变；原始TB覆盖副本只作文本换行规范化，语句不变；实际RTL文件逐字节未改。`SOURCE_INTEGRITY.json`提供核对记录。所有大日志、VCD、仿真快照都只在仓库外临时目录，交付文件只包含必要diff、摘要及TXN摘录，没有本机账号/令牌/私有绝对路径。
