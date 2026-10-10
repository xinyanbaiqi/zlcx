# PPG芯片级数字顶层（SPI/P2S集成glue顶层）架构合同

> V1.0 架构冻结，2026-08-31：本合同冻结芯片级数字顶层（下称"glue顶层"，暂定模块名`ppg_digital_top`，最终命名待确认）的信号清单、内部功能块划分和CDC路径归属，作为其RTL实现的前置依据。本合同**不冻结**SPI协议参数、P2S包格式细节、读方向CDC具体实现和`DBG_OUT`候选枚举——这些是第8节列出的开放项，将逐项单独确认后再补充勘误，不在本次范围内一次性冻结。
>
> V1.1勘误，2026-08-31：确认SPI协议参数的5项（Mode 0、MSB-first、16-bit地址、8-bit数据+突发自增、帧结构含COMMIT定长例外），见第8.1节。第8.2节仅剩SPI_SCLK频率上限（依赖读方向CDC实现）、P2S剩余字段、读方向CDC具体实现、`DBG_OUT`候选枚举、glue顶层命名、黑盒壳层幽灵Pin问题共6项未定。本次勘误不涉及`ppg_control_top.v`或C01合同，纯属glue顶层自身协议细节冻结。
>
> V1.2勘误，2026-08-31：确认读方向CDC同步器完整机制（快照捕获范围/触发时机/冻结策略/跨域同步方式）、读命令哑字节数（2字节）和`SPI_SCLK`频率上限（4 MHz），全部并入第8.1节。第8.2节开放项从6项收缩到4项：P2S剩余字段、`DBG_OUT`候选枚举、glue顶层命名、黑盒壳层幽灵Pin问题。第3项开放项（读方向CDC实现）至此关闭。
>
> V1.3勘误，2026-08-31：确认glue顶层最终模块名为`ppg_chip_digital_top`（不再是暂定名`ppg_digital_top`），文件路径`ppg_chip_digital_top/ppg_chip_digital_top.v`，目标TB`ppg_chip_digital_top/tb_ppg_chip_digital_top.v`。选择理由：与`ppg_control_top`明确区分层级（"chip"标注这是直接对接封装引脚的芯片级顶层，`ppg_control_top`是它例化的下一级PPG算法顶层），与本合同文件名`PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md`直接对应，并与既有`ppg_digital_shell.v`/`ppg_digital_esd_shell.v`保持同一"ppg_digital_"命名家族。本次勘误不涉及`PPG_CONTRACT_CLOSURE_MATRIX.md`，该合同未曾引用过glue顶层，不受影响。第8.2节开放项从4项收缩到3项。
>
> V1.4勘误，2026-08-31：修复`ppg_digital_esd_shell.v`/`ppg_digital_shell.v`两个黑盒壳层的三处遗留问题（RTL已改，非本合同文本变更）：① 删除不属于确认过的48脚表的幽灵电源脚`DVDD12_AUX`/`DGND12_AUX`，`ppg_digital_esd_shell.v`的`DVDD12`/`DGND12`引脚号注释同时从错误的31/32改正为33/34；② 删除两个黑盒都声明过的`SPI_SDO_OE`（单从机、`SPI_SDO`始终驱动，不需要三态使能）；③ 删除全无模拟侧对应端口的`ADC_S1_DONE_ACK`/`ADC_S2_DONE_ACK`，并把ADC接口从占位名`ADC_S1/S2_RAW`/`ADC_S1/S2_DONE`改成与模拟侧原理图一致的真实网名`DOUT_STAGE1/2_LOW`/`CLK_STAGE1/2_DOUT_LOW`（用户确认模拟侧原理图实际网名）。本节第4/5节信号表已同步改名。第8.2节开放项从3项收缩到2项：P2S剩余字段、`DBG_OUT`候选枚举。
>
> V1.5勘误，2026-08-31：确认`DBG_OUT`候选枚举6项（`o_start_ack_event`、`o_stop_ack_event`、`o_commit_ack_event`、`o_system_abort_event`、`o_measurement_result_valid`、`o_active_precision_mode`），全部纯直连、不加边沿检测或其他中间逻辑，详见新增第8.3节（含类型标注、选择理由和mux切换瞬态毛刺的已知限制说明）。峰谷检测事件和严格400Hz帧同步脉冲经核实Top当前未暴露，不纳入本次候选表。第8.2节开放项从2项收缩到1项：仅剩P2S剩余字段。
>
> V1.6勘误，2026-08-31：确认P2S固定包格式完整设计（字段清单12项/161 bit、字段顺序、位序、`P2S_CLK`速率、背压机制、`P2S_FRAME`对齐），详见新增第8.4节。第8.2节最后一项开放项（P2S剩余字段）就此关闭——**第8节全部开放项已确认完毕**。同时确认两处需要新增的AMI/Top RTL端口（`stage1_raw`/`stage2_raw`原始码透传、`o_s1_calibration_applied`，均已溯源到AMI内部具体信号，见第8.4节），尚未编写。
>
> V1.7勘误，2026-09-05：第8.4.5节两步AMI/Top RTL已按已溯源方案实现，非本合同重新设计。AMI新增边界输出`o_s1_calibration_applied`（`flag_dc_s1_calibration_applied`纯转发）、`o_s1_raw`/`o_s2_raw`（`ppg_adc_dc_recovery_Inst`原来留空的`o_stage1_raw`/`o_stage2_raw`接入新增内部wire后转发），`ppg_adc_measurement_idac_integration.v`升至V1.14；Top新增同名3个边界输出，沿用`o_active_precision_mode`的内部wire+assign转发模式，`ppg_control_top.v`升至V1.5。两文件均通过`verilog_generated_deliverable_gate`（新增代码0 error/0 strict warning，文件级既有历史问题不在本次范围）；完整层次iverilog重新编译+`tb_ppg_control_top.v`主烟雾TB重跑，`SMOKE_TB_PASS real_adc_responses=47 measurement_result_valid=32`，与改动前逐位一致。第8.4.5节原列三步中的第①②步（AMI/Top端口）至此完成，第③步（glue顶层P2S打包器接入这三个端口）明确保留未做——`ppg_chip_digital_top.v`本身是另一项独立工作，按用户指示在另一会话进行，本次不顺带开工，避免两边同时改动冲突。
>
> V1.8勘误，2026-09-06：修复`ppg_digital_esd_shell.v`第2处幽灵端口——`CLK_IREF_LED_LOW`（LED基准电流时钟）曾被`ppg_chip_digital_top`实现会话（②）发现"`ppg_control_top`/SSW两层都查不到对应信号"，一度怀疑是SSW漏实现的真实功能缺口。用户澄清：该信号早已从真实设计中删除，属于黑盒文件残留、与V1.4勘误处理过的`DVDD12_AUX`/`DGND12_AUX`/`SPI_SDO_OE`/`ADC_S1_DONE_ACK`/`ADC_S2_DONE_ACK`同一类问题，非新发现的设计缺口。已从`ppg_digital_esd_shell.v`删除该端口声明，`ppg_digital_shell.v`本来就没有这个信号、无需改动。第5节SSW模拟控制输出从33个改正为32个，内对模拟信号总数从37个改正为36个。②会话可以直接忽略这个信号，不需要为它路由或tie任何值。
>
> V1.9勘误，2026-09-06：修复`ppg_digital_esd_shell.v`第3处命名不一致——`EN_SAR9_IREF_LOW`（带`_LOW`后缀）与`ppg_control_top.v`已冻结的`o_en_sar9_iref`（无`_LOW`）不一致，且与同组`EN_SAR15_IREF`/`o_en_sar15_iref`（两侧均无`_LOW`）的命名规律不对称，曾被`ppg_chip_digital_top`实现会话（②）发现并提出。经两份独立的Cadence Spectre模拟侧`clk_sim`原理图testfixture netlist（`ppg_top_lay_sim`库，两次不同仿真配置）交叉确认，模拟侧真实网络名为`EN_SAR9_IREF`，不带`_LOW`——`_LOW`是`ppg_digital_esd_shell.v`自身的命名笔误，不是模拟侧存在两种真实命名规则。已将`ppg_digital_esd_shell.v`的`EN_SAR9_IREF_LOW`改正为`EN_SAR9_IREF`；`ppg_control_top.v`的`o_en_sar9_iref`本来就是对的，未改动。改动时`ppg_digital_esd_shell`模块尚未被任何文件例化，零下游涟漪。②会话现在可将`o_en_sar9_iref`按与`o_en_sar15_iref`→`EN_SAR15_IREF`相同的纯改名直连模式接到`EN_SAR9_IREF`，不需要在glue顶层做任何极性处理，也不需要记录为cosmetic命名drift——不一致已在本层修正完毕。
>
> V1.10勘误，2026-09-06：`ppg_chip_digital_top`实现会话（②）提出`i_analog_ready`应如何在glue顶层取源，误以为它跟`i_adc_physical_idle`同构——需要一个真实物理原始信号加单点同步器。经核查，`i_analog_ready`与`i_adc_physical_idle`并不同构：`i_adc_physical_idle`背后有真实随时间变化的物理信号（ADC DONE脉冲）需要同步器；`i_analog_ready`背后没有对应的时变物理信号，且这个问题在2026-08-23/24三份会话交接文档（`PPG_SESSION_HANDOFF_20260823_4.md`第92-94行、`PPG_SESSION_HANDOFF_20260824.md`第159-161行、`PPG_SESSION_HANDOFF_20260824_2.md`第342-343行）里口径一致地记录为**已与用户确认过的老决定**：真实芯片集成层的板级上电时序是"模拟偏置先稳定，数字系统/FPGA才启动"，因此`i_analog_ready`在glue顶层可以直接接常数`1'b1`，`ppg_control_top.v`本身仍保留该端口作为真实边界输入不变。②会话不需要为此新增QFN引脚，也不需要寻找现有引脚复用，直接`assign i_analog_ready = 1'b1;`（或等效常量连接）即可，不属于本次glue顶层实现范围内的新发现缺口。
>
> V1.11勘误，2026-09-07：glue顶层RTL/TB首次实现完成（②会话）。新建`ppg_pulse_cdc_sync.v`（单脉冲toggle-CDC复用IP，例化5次）、`ppg_spi_register_file.v`（SPI Mode 0从机寄存器文件，V1.1修复一处真实的突发读重加载错位缺陷，见下）、`ppg_p2s_packer.v`（161-bit定长包+深度2缓冲）、`ppg_chip_digital_top.v`（glue顶层本体，V1.1修复一处真实的复位CDC竞争，见下），四文件均通过`verilog_generated_deliverable_gate`（`ppg_chip_digital_top.v`的46处发现全部是该文件自身文件头已文档化接受的VG010封装引脚命名例外——第4节要求的46个封装边界端口必须与`ppg_digital_esd_shell.v`物理引脚名逐字一致，不可加`i_`/`o_`前缀，无其余发现；其余三个新文件0 error/0 strict warning）。字节级寄存器地图（写方向`0x0000-0x0090`、读方向`0x0100-0x0125`）首次正式写入本合同文本，见新增第11节——此前第6节②只有功能块级描述，未落到字节。新建`tb_ppg_chip_digital_top.v`覆盖任务要求的六个验证方面，5/6真实通过：SPI基本读写+生命周期轮询、P2S定长包字段与字节位置、真实双光背靠背深度2缓冲不丢数据、`flag_adc_physical_idle`合成器精度二选一、`DBG_OUT`全部6个候选逐一触发核对；第6项（两组discard锁存翻转位）经四种独立构造方法（并发下发STOP+DONE、剥离残留状态重建干净现场、不补DONE只看stop_ack本身、STOP提前到Q3仍拉高时下发）均未能真实触发，已定位为一个真实的架构级窄窗口问题、非TB时序bug，详见第11.3节，留作独立开放项。全链路iverilog重新编译+`tb_ppg_control_top.v`自身主烟雾TB重跑，`SMOKE_TB_PASS real_adc_responses=47 measurement_result_valid=32`，与本次改动前逐位一致，确认`ppg_control_top.v`零回归。发现并修复的两处真实缺陷（均属②会话新建代码自身，不涉及`ppg_control_top.v`或更早既有RTL）：① `ppg_chip_digital_top.v`最初例化的源域复位同步器由`SPI_SCLK`自身驱动，而`SPI_SCLK`在主机发起第一笔真实事务前始终空闲拉低，导致该同步器永远等不到释放所需的时钟沿，上电后第一笔SPI事务的头1~2比特会被复位覆盖而错位——已改为源域复位直接借用已在`CLK_2M_PAD`域完成同步、早于任何真实SPI活动稳定下来的`i_rstn`，异步喂入不存在亚稳态风险，`ppg_chip_digital_top.v`升至V1.1；② `ppg_spi_register_file.v`最初的突发读重加载逻辑直接按`reg_byte_addr`译码，但每字节重加载比地址自身的自增提前一整拍触发，导致突发读中从第二字节起每个字节都错误移出上一字节的内容——已改为按提前补偿+1的有效地址译码，`ppg_spi_register_file.v`升至V1.1。
>
> V1.12勘误，2026-09-07：针对第11.3节TC6开放项（discard锁存翻转位真实触发的架构级窄窗口）"是否需要新增专用触发通道"这一问题给出分析结论：**不需要**。依据两条独立门控证据：① `flag_stopping_complete`（`ppg_system_config_manager.v:463-464`）是`i_adc_idle && i_datapath_empty && i_idac_idle && i_analog_safe`四路独立AND，TC6卡住的窄窗口只发生在`i_adc_idle`这一路（背后是DOUT选通脉冲的瞬时取反）；真正防止丢失流水线在途数据的是`i_datapath_empty`这一路，跟`i_adc_idle`不是同一道防线。② `i_datapath_empty`（`ppg_adc_measurement_idac_integration.v:1140`，`o_datapath_empty`）本身是ADC chain、fork分支、FIR、detection fork、detector、controller、scheduler、calibration等8路以上子模块idle标志的聚合，真实数据流经这些阶段需要数十到上百个`CLK_2M`周期，与SPI一次命令事务的传输延迟属同一数量级，SPI STOP完全够得着这一路；只有`i_adc_idle`背后的DOUT选通脉冲本身宽度远小于SPI最短事务时延，这是协议延迟与ADC脉冲宽度两个不同数量级物理量决定的结构性事实，不是可以通过调整RTL压缩的巧合窗口。此外，discard锁存翻转位机制本身已经用"无owner在途的spurious DONE脉冲经fault supervisor级联"这一更宽的真实触发通路正面验证工作正常（与P06发现的约2-3拍自动abort级联路径同源），TC6打不中的只是"主动STOP精确命中ADC选通脉冲"这一个特定子场景，而该子场景在真实操作中因同样的时序错配也几乎不会发生——不是防线出现遗漏，是防线本来就在`i_datapath_empty`这一路，`i_adc_idle`从未独自承担过防止数据丢失的职责。与P06（同项目内同类"结构性窄窗口、非bug"发现，已关闭且未加RTL）归为同一结案类别：不新增专用硬件触发通道，也不新增QFN引脚（48脚封装已多轮冻结，新增物理引脚的代价与本项开放项完全不成比例）。第11.3节正文追加一句面向主机固件作者的措辞澄清，见下。
>
> V1.13勘误，2026-09-07：修复第8.4.2节字段12和第8.4.5节的文档滞后——两处文字仍停留在V1.6/V1.7时代"glue顶层P2S打包器接入待做/未做"的措辞，但V1.11勘误的glue顶层实现早已完成这一步：`ppg_chip_digital_top.v:473-475`将`s1_calibration_applied`/`stage1_raw`/`stage2_raw`接入P2S打包器`i_s1_calibration_applied`/`i_stage1_raw`/`i_stage2_raw`，`:644-646`接`ppg_control_top`同名输出，字段12三步（AMI端口/Top端口/glue打包器接入）全部完成，非本次新增实现，纯文本纠正，不涉及RTL改动。此项在②回复"TC6已结案"之后由用户追问"②的工作是否完全结束"时核对合同与实际RTL一致性发现，与V1.8/V1.9同一类"合同文字滞后于已完成RTL"问题。
>
> 本合同不改变、不重新认证、不关闭`PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`（下称"C01"）的`NOT_CLOSED`门禁状态；glue顶层是C01目标RTL`ppg_control_top`之外新增的一层，例化关系是"glue顶层例化`ppg_control_top`"，不是反过来，也不修改`ppg_control_top.v`内部除C01 V1.11/V1.12勘误已冻结的`o_active_precision_mode`、`o_source_config_update_ready`之外的任何逻辑。
>
> V1.14勘误，2026-09-07：修复用户复核发现的一个真实CDC缺陷（补齐第8.3节第153行V1.5冻结要求，是补齐已冻结要求，不是新决策）：`o_dbg_out_select[2:0]`原先从`SPI_SCLK`域零同步级直接跨入`CLK_2M`域组合逻辑——`ppg_spi_register_file.v`里`reg_dbg_out_select`注册时钟是`i_source_clk`（即`SPI_SCLK`），`assign o_dbg_out_select = reg_dbg_out_select;`直接导出，而`ppg_chip_digital_top.v`的`dec_dbg_out_mux`（`CLK_2M`域组合逻辑）直接用这个信号选择，既不在既有5个`ppg_pulse_cdc_sync`实例覆盖范围内（那5个只覆盖START/STOP/DIAG_CLEAR/ABORT+读触发5个单周期脉冲），也没有走`i_source_test_mux_ctrl[4:0]`那种由`ppg_control_top`内部`ppg_characterization_control_cdc`处理的握手桥方式——正是第8.3节第153行"选择值……需经`SPI_SCLK`→`CLK_2M`域的小型CDC（与既有`i_source_test_mux_ctrl[4:0]`同类）才能驱动选择器"这一早于本次glue顶层实现工作、V1.5即已冻结的要求，也正是第9节第6条明文禁止的"直接组合逻辑或单级触发器'临时'跨域"三条路径之一；V1.5第8.3节末尾接受的"已知限制"只覆盖"值经过正确CDC之后、选择器切换瞬间的正常mux毛刺"，前提是CDC本身已经做了，不是在给"没做CDC"背书。`TC5`（`DBG_OUT`全部6个候选逐一触发核对）之所以此前未测出，是因为功能仿真是事件驱动的，标准写法（写寄存器→等足够多拍→查`DBG_OUT`电平）测不出位撕裂/亚稳态这类时序层面的物理现象，属于功能TB的固有盲区，不是`TC5`写得不够严格。修复方式：不对3-bit值本身做双触发器同步（多bit值双触发器打两拍仍有跨bit撕裂风险），改为新增一路翻转式事件跨域，复用`ppg_pulse_cdc_sync`基础设施——`ppg_spi_register_file.v`（V1.2）新增第六个`ppg_pulse_cdc_sync`实例，复用更新`reg_dbg_out_select`本身的同一个单周期写命中脉冲（命中`reg_byte_addr==129`）作为桥接触发源，产生新的单周期`CLK_2M`域事件`o_dbg_out_select_update_event`；`reg_dbg_out_select`/`o_dbg_out_select`本身保持不变（仍是`SPI_SCLK`域寄存器直接导出）。`ppg_chip_digital_top.v`（V1.2）新增`CLK_2M`域寄存器`reg_dbg_out_select_stable`，只在该更新事件到达时才采样`spi_dbg_out_select_o`（复位值`3'd0`），`dec_dbg_out_mux`改为按这个本地锁存值选择——事件抵达时源端寄存器早已稳定多拍，采样安全，与其余5路脉冲跨域同一道理。两个文件均重新跑过`verilog_generated_deliverable_gate`确认0新增发现（`ppg_spi_register_file.v`0 error/0 strict warning，`ppg_chip_digital_top.v`仍只有46处已文档化的VG010封装引脚命名例外）；`tb_ppg_chip_digital_top.v`全量重跑6/6真实PASS（`DBG_OUT`候选0/2/4/5均已在`TC1`/`TC2`/`TC4b`场景中经这条真正CDC路径验证）；`ppg_control_top.v`自身`SMOKE_TB_PASS real_adc_responses=47 measurement_result_valid=32`不变，零回归。端口列表变化：`ppg_spi_register_file.v`新增输出端口`o_dbg_out_select_update_event`；`ppg_chip_digital_top.v`自身端口列表不变。
>
> V1.15勘误，2026-09-14：修复Stage 3 Item 4a延伸审计（非本合同正式Stage步骤，是既有CDC三分类审计工作的范围延伸）发现、并经独立复核确认维持的一处真实结构性CDC缺陷：第8.1节"冻结快照进`SPI_SCLK`域方式"一行原表述（`ppg_spi_register_file.v`回读段`reg_diag_sync_meta`/`reg_diag_sync_stable`无条件、每个`i_source_clk`周期都直接对304-bit的`reg_diag_snapshot`总线打两级触发器，不带任何门控信号）经查实为本合同第9节CDC三分类里明文禁止的"对总线直接打两级触发器（撕裂风险）"模式，与写方向`ppg_config_cdc_bridge.v`真正的Class 3(a)门控捕获范式在结构上并不相同；V1.2勘误当时给出的"源端冻结+时序余量即可保证不存在数据撕裂"这一论证，把多bit总线的跨域采样原子性风险错误等同于单bit信号的亚稳态解析时间风险，是真实的推导缺口，不是文字滞后。独立复核同时确认：合同原有的3周期/1.5us前段延迟数字本身准确，但"2倍余量"结论遗漏了返程2拍，理论频率上限10.7MHz的推导也只计入了前段——这些数字缺口本身不是撕裂风险的来源（补算后余量仍为正），真正的问题在于采样机制缺少门控这一结构性事实，与时序余量数字无关。修复方式：`ppg_spi_register_file.v`新增第七个`ppg_pulse_cdc_sync`实例（`ppg_pulse_cdc_sync_diag_ready_Inst`），把`reg_diag_snapshot`真正完成更新的同一个`i_clk`域事件`w_capture_trigger`反向桥接进`i_source_clk`域，生成新的单周期门控脉冲`w_diag_snapshot_gate_event`；原`reg_diag_sync_meta`改名为`reg_diag_snapshot_gated`（并移除不再适用的`ASYNC_REG`属性），采样条件改为只在该脉冲为真时才整体捕获，与`ppg_config_cdc_bridge.v`的门控捕获结构完全对齐；`reg_diag_sync_stable`现为同域流水线寄存器，不再是跨域同步的一部分。第8.1节相关三行（读命令哑字节数、`SPI_SCLK`频率上限、冻结快照进`SPI_SCLK`域方式）已按修复后的真实往返延迟（前段1.5us+返程4个`SPI_SCLK`周期，4MHz下约1.0us，合计2.5us，2字节窗口余量约1.5us/1.6倍，理论频率上限重算为约6.4MHz）与真实机制同步更新，生产`SPI_SCLK`上限4MHz本身不受影响、仍有正裕量。端口列表无变化（新增wire纯内部）；`ppg_spi_register_file.v`升至V1.3。读方向快照捕获段（`flag_read_start`→`w_capture_trigger`→`reg_diag_snapshot`）、`DBG_OUT`选择值CDC（V1.14已修复部分）与ACTIVE影子区写方向均未受影响，同一次延伸审计已独立确认这三处安全。`ppg_chip_digital_top.v`自身未改动，仍为V1.2。`tb_ppg_chip_digital_top.v`全量重跑6/6真实PASS，与修复前逐行输出（含`帧号=0`等具体数值）完全一致，证明功能未回归；但门控捕获修复的是仿真无法暴露的撕裂风险本身，PASS只证明"没改坏正常功能"，不构成"撕裂风险已消除"的独立证据——后者由本次改动的结构性对齐（门控捕获，不再依赖时序余量兜底）保证。完整推导过程见memory `project-ppg-stage3-item4a-extension-spi-diag-tearing-confirmed-20260914`。
>
> V1.16勘误，2026-10-04：订正第8.4.5节`s1_calibration_applied`来源的不实描述，并写明P2S三个遥测字段与正式结果同属一笔的前提（用户裁定方案(c)：不改RTL逻辑，只写限制）。AMI V1.14实际导出的是结果fork之前DC恢复实例的`flag_dc_s1_calibration_applied`（`ppg_adc_measurement_idac_integration.v:1029`，来源`:2278`），而不是本节原文所写的fork解包字段`flag_unused_output_calibration`；`stage1_raw`/`stage2_raw`同样取自fork之前（`:1030-1031`）。AMI端口注释（`:403`）和assign注释（`:1029`）已由任务C原行改正；芯片顶层TB V1.2新增TC7永久断言守护该前提。证据：`verification_reports/TASKC_TICK248_P2S_20261001.md`第4节。同步记录：`verification_reports/CONTRACT_SYNC_BATCH3_PHASE2_20261004.md`。
>
> V1.17勘误，2026-10-09：B合同合并批次（`verification_reports/B_MERGE_BATCH_ITEMS.md` BMI-110~115，按基线`7a8eabf`芯片顶层RTL、`ppg_spi_register_file.v` V1.5改写，符号锚点格式为“文件 + 符号（§节）”）。① 新增§8.5：`SPI_CS_N`作为SPI协议状态的异步复位/门控，不加同步链，写入四点安全论证（F-030）；§7新增对应行。② 第2、3、4、6节订正复位同步器为一个实例，源域复位借用已同步的数字域复位（F-007，RTL自V1.1起如此）。③ §8.1新增“读数据移出相位”一行（F-005/F-006）。④ §11.2地图0x0108 bit6为AMI owner lost sticky，并新增§11.4逐位清除方式。⑤ 新增§8.6产品固定参数与检查所在TB（F-014/F-024）。不改变任何地址、位定义（0x0108 bit6除外，它原为保留位）或协议时序。
>
> 目标RTL：`ppg_chip_digital_top/ppg_chip_digital_top.v`（V1.3勘误确认路径，V1.11勘误首次实现，V1.14勘误修复DBG_OUT选择值CDC后现为V1.2）
> 目标TB：`ppg_chip_digital_top/tb_ppg_chip_digital_top.v`（V1.3勘误确认路径，V1.11勘误首次实现）
> 工作时钟：`CLK_2M`域（2 MHz数字系统域，与C01的`i_clk`同源）+ `SPI_SCLK`域（SPI配置源域，与C01的`i_source_clk`同源，非自由振荡）
> 适用范围：QFN48封装数字Pad Ring边界到`ppg_control_top`边界之间的全部协议转换、时钟域处理和纯连接

## 1. 合同目的与范围

`ppg_control_top`（C01目标RTL）的边界端口是协议无关的抽象接口（并行配置总线、单周期事件脉冲、已同步时钟复位），完全不感知SPI/P2S/`DBG_OUT`等物理引脚协议。glue顶层是这两者之间的适配层，只做协议转换、时钟域同步和纯信号改名/直连，不包含任何PPG测量、校准、检测算法逻辑——全部算法逻辑仍在`ppg_control_top`向下的六个直接子模块中。

本合同的信号清单和功能块划分来自与用户的逐信号讨论确认（2026-08-31会话），信号语义、方向、封装Pin号来自QFN48封装最后一次完整列出的引脚表（`PPG_NEW_CHAT_CONTEXT.md`第14-15节）及用户在本次会话中给出的更新表述，两者已核对一致。

## 2. 依赖追踪

| 依赖 | 版本 | 用途 |
| --- | --- | --- |
| `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`（C01） | V1.14 | `ppg_control_top`边界端口定义、`i_source_*`语义、`o_active_precision_mode`语义、`flag_adc_physical_idle`合成公式、`o_source_config_update_ready`语义；V1.13/V1.14为另一会话对TOP-01~24验收表的证据核对勘误（V1.14收尾TOP-06，24项全部CLOSED），与本合同信号/CDC内容无冲突 |
| `ppg_reset_sync/ppg_reset_sync.v` | V1.0 | 复位同步器标准IP，glue顶层例化~~两次~~一次（V1.17订正，F-007：`ppg_chip_digital_top.v` `ppg_reset_sync_clk2m_Inst`） |
| `ppg_config_cdc_bridge/ppg_config_cdc_bridge.v` | 现有 | 1024-bit ACTIVE配置的写方向CDC参考实现（该模块本身例化在`ppg_active_v4_control_plane_integration`内部，glue顶层只需按其`i_source_config`端口语义提供已经在`SPI_SCLK`域稳定的完整寄存器组，不重复实现CDC逻辑） |
| `ppg_characterization_control_cdc`合同 | V1.1 | 表征控制6-bit字段的CDC语义参考 |
| `ppg_digital_esd_shell/ppg_digital_esd_shell.v` | 现有（黑盒） | glue顶层对外边界端口名称必须与该黑盒一致（该文件的电源Pin号注释和幽灵AUX Pin问题已在封装复核中记录，不影响本合同的信号语义部分） |

## 3. 冻结层次

glue顶层的直接子模块（新建）加一个既有模块例化：

```text
ppg_chip_digital_top
├── ppg_reset_sync（例化1，i_clk=CLK_2M_PAD，产i_rstn）
├── ~~ppg_reset_sync（例化2，i_clk=SPI_SCLK，产i_source_rstn）~~ V1.17订正（F-007）：无例化2；i_source_rstn = i_rstn（`w_source_rstn = w_rstn`）
├── SPI从机（新建，移位引擎+寄存器文件，写方向+读方向）
├── flag_adc_physical_idle合成器（新建，精度模式选择+单点同步）
├── P2S打包器（新建，含深度2内部缓冲，字段清单见第8.4节）
├── DBG_OUT候选选择器（新建，候选枚举见第8.3节）
└── ppg_control_top（既有，C01目标RTL，不得修改除C01 V1.11/V1.12已冻结范围外的内部逻辑）
```

glue顶层不得直接例化`ppg_control_top`内部的任何子模块（ACTIVE控制平面、表征CDC、调度器、AMI、SSW、supervisor），这点与C01第3.1节"Top不得重复例化AMI内部子模块"的精神一致，延伸适用于glue顶层。

## 4. 封装级数字信号清单（10个）

| # | 信号 | 方向 | glue顶层内接收/驱动方 |
| --- | --- | --- | --- |
| 1 | `CLK_2M_PAD` | 输入 | `ppg_reset_sync`例化1的`i_clk`；`ppg_control_top.i_clk`；P2S打包器`P2S_CLK`派生源 |
| 2 | `RESET_N` | 输入 | `ppg_reset_sync`例化1~~、例化2~~的`i_async_rstn`（V1.17订正，F-007：只有一个实例；源域复位借用其同步结果） |
| 3 | `SPI_CS_N` | 输入 | SPI从机移位引擎 |
| 4 | `SPI_SCLK` | 输入 | SPI从机移位引擎；~~`ppg_reset_sync`例化2的`i_clk`；~~等效于C01的`i_source_clk`（V1.17订正，F-007：不再驱动任何复位同步器） |
| 5 | `SPI_SDI` | 输入 | SPI从机移位引擎（写方向） |
| 6 | `SPI_SDO` | 输出 | SPI从机寄存器文件读方向逻辑驱动 |
| 7 | `P2S_CLK` | 输出 | P2S打包器驱动，`CLK_2M_PAD`派生 |
| 8 | `P2S_DATA` | 输出 | P2S打包器驱动 |
| 9 | `P2S_FRAME` | 输出 | P2S打包器驱动 |
| 10 | `DBG_OUT` | 输出 | DBG_OUT候选选择器驱动 |

## 5. 内对模拟信号清单（36个，纯直连/改名，不在glue顶层产生任何新逻辑状态；V1.8勘误从37个改正为36个）

| 分组 | 数量 | 处理方式 |
| --- | --- | --- |
| ADC数字接口（`DOUT_STAGE1/2_LOW`、`CLK_STAGE1/2_DOUT_LOW`，V1.4勘误按模拟侧真实网名改名，原`ADC_S1/S2_RAW`/`ADC_S1/S2_DONE`占位名已废弃） | 4，全输入 | 逐位直连`ppg_control_top`的`i_dout_stage1_low`/`i_clk_stage1_dout_low_async`/`i_dout_stage2_low`/`i_clk_stage2_dout_low_async`，零逻辑；同时`!CLK_STAGE1_DOUT_LOW`/`!CLK_STAGE2_DOUT_LOW`参与`flag_adc_physical_idle`合成器的输入 |
| SSW模拟控制输出 | 32，全输出（V1.8勘误：原33个之一`CLK_IREF_LED_LOW`是`ppg_digital_esd_shell.v`残留的已废弃端口，用户确认早已从真实设计中删除，非SSW漏做，已从黑盒文件删除） | `ppg_control_top`对应`o_*`输出纯改名直连到`ppg_digital_esd_shell`同名端口，不得反相、屏蔽、合并或延迟，与C01第4.2节要求一致 |

## 6. 内部功能块划分（5+1块）

| 块 | 有无逻辑 | 职责 |
| --- | --- | --- |
| ① 复位同步 ~~×2~~ ×1 | 有 | ~~`RESET_N`分别经`CLK_2M_PAD`域和`SPI_SCLK`域各自的`ppg_reset_sync`实例，产出`i_rstn`和`i_source_rstn`~~ V1.17订正（F-007）：`RESET_N`只经`CLK_2M_PAD`域的一个`ppg_reset_sync`实例产出`i_rstn`；`i_source_rstn`直接借用该同步结果（`w_source_rstn = w_rstn`）。原因：`SPI_SCLK`在主机第一次真实传输前保持低电平静止，由它驱动的复位同步器会用第一次传输自己的时钟沿释放复位，破坏首次传输的前1~2位（芯片顶层RTL V1.1修复，TB TC1发现） |
| ② SPI从机 | 有 | 移位引擎+寄存器文件；写方向把SPI串行写入解码为`i_source_config_snapshot[1023:0]`、`i_source_config_update_event`、`i_source_characterization_update_valid`等C01已冻结的`i_source_*`端口，以及一次性命令脉冲（映射到C01的`i_start_event`/`i_stop_event`/`i_diag_clear_event`/`i_control_abort_event`）；读方向把`ppg_control_top`输出的快照通过`SPI_SDO`移出 |
| ③ `flag_adc_physical_idle`合成 | 有 | 按C01 V1.11冻结公式，用`ppg_control_top.o_active_precision_mode`在`!CLK_STAGE1_DOUT_LOW`和`!CLK_STAGE2_DOUT_LOW`之间二选一，经单点同步器产出`ppg_control_top.i_adc_physical_idle` |
| ④ P2S打包器 | 有 | 12字段固定包（161 bit），事件触发（`o_measurement_result_valid`）、深度2内部缓冲承接背压，字段清单见第8.4节 |
| ⑤ `DBG_OUT`候选选择器 | 有 | 6选1纯直连多路选择器（候选枚举见第8.3节），选择值来自SPI寄存器（需跨`SPI_SCLK`→`CLK_2M`域，见第7节） |
| ⑥ 纯改名/直连 | 无 | 第5节36个内对模拟信号 |

## 7. CDC路径总表

| 路径 | 方向 | 机制 | 状态 |
| --- | --- | --- | --- |
| SPI写入 → `i_source_config_snapshot`等`i_source_*` | `SPI_SCLK`域 → `CLK_2M`域 | 复用C01既有的`ppg_config_cdc_bridge`（1024-bit ACTIVE）与`ppg_characterization_control_cdc`（6-bit表征字段）语义；glue顶层SPI寄存器文件按其`i_source_config`端口要求提供稳定并行总线；写入节流由C01 V1.12新增的`o_source_config_update_ready`回报（`=1`才可再拉`i_source_config_update_event`），不再需要保守限速猜测 | 已有CDC基础设施，`o_source_config_update_ready`已在C01落地，glue顶层只需正确驱动 |
| `ppg_control_top`输出 → `SPI_SDO`读回 | `CLK_2M`域 → `SPI_SCLK`域 | 每次新读事务在`CLK_2M`域整体捕获`0x0100+`只读诊断区快照并冻结至事务结束，快照完成更新的同一事件再桥接一次跨入`SPI_SCLK`域生成门控脉冲，`SPI_SCLK`域寄存器只在该脉冲为真时才整体捕获总线（非对总线的无门控直接双触发器），读命令地址后插入2个哑字节覆盖往返延迟；机制细节见第8.1节 | 已确认（V1.2勘误确认哑字节数与频率上限；V1.15勘误修复回读段门控缺陷、更新本行机制描述与第8.1节时序数字），RTL见`ppg_spi_register_file.v` V1.3 |
| `SPI_CS_N` → SPI协议状态 | 异步 → `SPI_SCLK`域 | V1.17补记（F-030）：作为7个SPI协议状态寄存器的异步复位/门控，不加同步链；安全论证与接口时序要求见§8.5 | 已冻结 |
| ADC DONE → `flag_adc_physical_idle` | 异步 → `CLK_2M`域 | 精度模式选择后单点两级同步器，选择信号`o_active_precision_mode`本身已是`CLK_2M`域同步电平 | 已确定机制，待写RTL |
| SPI寄存器（选择值）→ `DBG_OUT`候选选择器 | `SPI_SCLK`域 → `CLK_2M`域 | 与既有`i_source_test_mux_ctrl[4:0]`同类的小型CDC，具体走既有握手结构还是独立小型同步器待定 | 开放项，见第8节 |
| ~~SPI寄存器 → P2S打包器~~ | 不适用 | V1.6勘误：P2S字段清单最终确认为全部固定、不受SPI配置影响（无模式播报、无可配置字段选择），P2S打包器全程只消费`ppg_control_top`的`CLK_2M`域输出，不存在SPI→P2S的CDC路径 | 已确认为不适用，非遗漏 |

## 8. SPI协议参数

### 8.1 已确认（V1.1勘误新增前6条，V1.2勘误新增后6条，均2026-08-31）

| 决策点 | 冻结值 | 备注 |
| --- | --- | --- |
| SPI模式 | Mode 0（CPOL=0, CPHA=0） | 空闲低、上升沿采样，与绝大多数SPI外设默认一致 |
| 位序 | MSB-first | 行业事实标准 |
| 地址位宽 | 16-bit | 实测当前写方向（ACTIVE影子128B+表征1B+命令1B≈130B）与读方向（结果快照+生命周期+诊断+故障+discard事件≈100B）合计约230~250字节，已逼近8-bit地址256字节上限、无余量；地址译码逻辑只覆盖实际定义字段，16-bit地址不额外增加寄存器堆物理规模，仅每帧多1字节头部开销 |
| 数据位宽 | 8-bit（字节），突发内地址自增 | 标准SPI寄存器访问粒度；非字节对齐字段（如6-bit表征字段、2-bit`frame_type`、15-bit`o_programmable_15_code`）需在后续寄存器地图里显式定义其在某字节内的位位置，8-bit粒度本身不受影响 |
| 帧结构 | 寄存器读写：1字节命令(R/W+保留位)+2字节地址+N字节变长突发；COMMIT等一次性触发命令：固定32-bit（1+2+1字节） | 变长突发之所以安全，是因为每个字节写入影子寄存器都是自包含的、不依赖"突发何时结束"；只有需要产生离散触发事件的命令（COMMIT等）才要求固定长度，使其"事务完成"可以纯粹由SPI_SCLK域的比特计数器判断，不依赖`CS_N`上升沿。`CS_N`仍需过标准两级同步器，但只用于门控/复位比特计数器，不用于推导任何离散事件的触发时刻 |
| ACTIVE写入生效时机 | 突发写只更新`0x0000-0x007F`影子区，不自动生效；必须由`0x0090`命令寄存器单独一次COMMIT写入才原子提交给Top | 与C01/C02既有的"CONFIG影子→显式COMMIT→ACTIVE"模型一致，突发写允许只更新部分字段后再统一提交 |
| 读命令哑字节数 | 2个字节（16拍），仅读命令的地址与首个真实数据字节之间插入，写命令不需要 | 覆盖读方向CDC往返总延迟：前段（`flag_read_start`→`reg_diag_snapshot`完成更新）3个`CLK_2M`周期=1.5us（2级同步器2拍+捕获寄存器1拍），返程（`reg_diag_snapshot`→`SPI_SCLK`域可安全读取，V1.15勘误改为门控捕获后）4个`SPI_SCLK`周期（2级同步器2拍+门控捕获寄存器1拍+同域流水线1拍）；4MHz上限下返程=1.0us，往返合计2.5us，2字节(4us)窗口余量约1.5us（约1.6倍），代价是每次读事务多2字节协议开销，可忽略。V1.15勘误前的旧实现返程是无门控连续双触发器，本行返程数字与"2倍余量"表述当时未把返程计入总账，且旧机制本身存在撕裂风险，详见memory `project-ppg-stage3-item4a-extension-spi-diag-tearing-confirmed-20260914`与`ppg_spi_register_file.v` V1.3改动记录 |
| `SPI_SCLK`频率上限 | 4 MHz | 2个哑字节（16拍）需覆盖2.5us往返总延迟，理论可支持到约6.4MHz（16拍/2.5us，V1.15勘误据修复后真实往返延迟重新核算；V1.2勘误原10.7MHz数值只计入了前段1.5us、遗漏了返程，是本次连带修正的合同文字滞后，不影响4MHz生产上限本身的正确性），但SPI只承担低频配置/轮询（高带宽遥测由P2S承担），刻意选保守的低几MHz值而非逼近理论上限：一是留足PVT和后续实现细节（如同步链多一级）的余量，二是较低的`SPI_SCLK`翻转速率对旁边的精密PPG模拟输入前端（`VIN/VIP`等，已在封装复核中标记`CLK_2M`邻近噪声耦合风险）更友好 |
| 读方向CDC快照捕获范围 | `0x0100+`整个只读诊断区一次性整体捕获，不做逐字段独立刷新 | 保证一次多字节读回内所有字节属于同一时刻，不会前后字节撕裂 |
| 读数据移出相位（V1.17补记，F-005/F-006） | Mode 0读：每字节第8个`SPI_SCLK`上升沿之后的下降沿装载下一字节（`ST_DATA`且`cnt_bit_in_byte==0`时的下降沿，含哑字节结束后的首个数据字节），其余下降沿移位；不做地址+1补偿 | `ppg_spi_register_file.v` `flag_load_read_byte`。主机在上升沿采样SDO，从机在下降沿更新；芯片TB在SCLK上升沿采样SDO并做38字节全读（DIAG-MAP38） |
| 读方向CDC捕获触发时机 | 每次新读事务（`CS_N`拉低+识别为读命令）触发一次新捕获，不支持host手动刷新命令 | 保证每次读到的是"当下最新"快照，逻辑最简单，不需要额外命令 |
| 读方向CDC冻结策略 | 捕获完成后，快照在整个读事务期间（到`CS_N`拉高为止）保持冻结，不被`CLK_2M`域实时更新覆盖 | 避免读到一半Top侧数据更新导致同一次读回前后字节不一致；冻结期间的"滞后"仅持续一次读事务的耗时（微秒级），远小于PPG 400Hz采样周期（2.5ms），不影响正确性 |
| 冻结快照进`SPI_SCLK`域方式 | 门控捕获：专用同步事件+目标域寄存器只在该事件为真时才整体采样（V1.15勘误改正，与写方向`ppg_config_cdc_bridge.v`的Class 3(a)范式结构对齐） | V1.2勘误原表述是"逐bit标准两级同步器，不使用握手协议"，理由是"源端在整个读期间不再变化，只需处理捕获那一瞬间的亚稳态风险，不存在数据撕裂问题"——这个理由把多bit总线的跨域采样风险等同于单bit信号的亚稳态解析时间风险，二者不是同一类风险：304个bit被无门控双触发器各自独立采样时，如果源端跳变沿恰好落在某次`SPI_SCLK`采样沿的建立/保持窗口内，这304个触发器会各自独立发生亚稳态解析，可能撕裂出一个源端从未真实存在过的拼凑值，而"源端此后不再变化"只保证这个已撕裂的值不会被自我纠正，并不能防止它在采样瞬间产生；时序余量（哑字节窗口）解决的是"值多久能传到位"，解决不了"采样那一拍本身是不是原子的"，二者是不同维度的问题。该表述已被判定为真实的结构性CDC缺陷（非文字滞后），经Stage 3 Item 4a延伸审计发现、独立复核（含本节时序数字的重新推导）后确认成立，`ppg_spi_register_file.v`已升级至V1.3改为门控捕获修复，本处合同文字同步为V1.15勘误，完整推导见memory `project-ppg-stage3-item4a-extension-spi-diag-tearing-confirmed-20260914` |

### 8.2 仍开放（V1.6勘误：本节已清空，第8节全部开放项确认完毕）

无。

### 8.3 DBG_OUT候选枚举（已确认，V1.5勘误2026-08-31）

| 选择值 | 信号 | 类型 | 说明 |
| --- | --- | --- | --- |
| 0 | `o_start_ack_event` | 单周期脉冲 | 验证START命令经SPI→CDC→合法性检查后真正生效的时刻 |
| 1 | `o_stop_ack_event` | 单周期脉冲 | 验证STOP命令真正生效的时刻；注意STOP有三路来源合并（外部命令/supervisor自动止损/abort排空），本信号不区分具体来源 |
| 2 | `o_commit_ack_event` | 单周期脉冲 | 验证ACTIVE配置写入+COMMIT后真正生效的时刻，可配合`o_source_config_update_ready`实测CDC延迟 |
| 3 | `o_system_abort_event` | 单周期脉冲 | 系统级abort真实发生的时刻；supervisor对同一未解决故障cause只在首次锁存时发一拍，不重复 |
| 4 | `o_measurement_result_valid` | 握手电平（保持有效至消费，非脉冲），原样直连不做边沿检测 | 上升沿即为结果就绪时刻，保持时长额外反映消费者反压时长；不做边沿加工的理由见下 |
| 5 | `o_active_precision_mode` | 电平（SAR9/SAR15状态位） | 精度切换瞬间即为电平跳变沿 |

全部6个候选均为**纯直连、不加任何中间逻辑**（包括`o_measurement_result_valid`，确认不加边沿检测）。选择依据：

1. 最小化不必要逻辑——不为凑候选表"看起来统一"而引入没有需求驱动的额外状态；
2. 调试观测端口应保持透明——`DBG_OUT`的作用是如实展示内部信号真实状态，不应重新加工被观测信号，否则示波器上看到的不再是"真相"；
3. `o_measurement_result_valid`的握手电平是ready/valid标准语义（与本项目其余ready/valid信号对一致），是设计正确的表达，不是需要"修正"的缺陷；
4. 保留原始电平能额外看到反压时长这一诊断信息，边沿检测会丢弃这个信息。

选择值本身存于glue顶层SPI寄存器文件，由SPI写入配置，需经`SPI_SCLK`→`CLK_2M`域的小型CDC（与既有`i_source_test_mux_ctrl[4:0]`同类）才能驱动选择器；重新配置选择值期间，`DBG_OUT`可能出现与真实事件无关的短暂瞬态跳变（多路选择器切换的常见现象），这是可接受的已知限制，不代表任何真实事件，也不影响任何功能时序路径（`DBG_OUT`不参与功能时序）。**V1.14勘误：本要求已实现**——`ppg_spi_register_file.v`（V1.2）新增第六个`ppg_pulse_cdc_sync`实例桥接选择值更新事件，`ppg_chip_digital_top.v`（V1.2）新增`CLK_2M`域本地锁存寄存器，`dec_dbg_out_mux`改为按该锁存值选择，详见版本历史V1.14条目。

峰谷检测事件和严格意义的400Hz帧同步脉冲，经核实Top当前均未暴露（前者埋在`ppg_peak_valley_window_detector`、后者止步于Scheduler内部），需要新增/穿透多级子模块才能实现，本次不纳入候选表；如后续确有需要，作为独立开放项另行评估。

### 8.4 P2S固定包格式（已确认，V1.6勘误2026-08-31）

#### 8.4.1 触发与包结构

| 决策点 | 冻结值 | 依据 |
| --- | --- | --- |
| 包长度 | 定长包，161 bit | `P2S_FRAME`按文档原意"覆盖整个固定数据包"，不是变长 |
| 触发方式 | 事件触发：每笔正式测量结果（`o_measurement_result_valid`）发一次包，不是400Hz周期性广播 | 文档原意"P2S包应在ADC转换完成后…发送"；双光模式下一个宏帧内RED/IR各触发一次，不是1:1对应400Hz |
| 位序 | MSB-first | 与SPI一致，降低FPGA两套协议分别实现的复杂度 |
| `P2S_CLK`速率 | 直接用`CLK_2M`（2MHz，不分频），不新增PLL/分频器 | 已是不加复杂度前提下能达到的最快选项，由8.4.3节的时序分析驱动 |
| `P2S_FRAME`对齐 | 与第一个数据位同一`P2S_CLK`边沿拉高，覆盖全部161拍数据，最后一位被采样后的下一拍拉低；**背靠背两个包之间`P2S_FRAME`必须至少落低1拍**，不得让两个包的高电平连成一片 | 简化FPGA解析（下降沿即为一个包结束，无需二次判断），并消除深度2缓冲下背靠背发包时的包边界歧义 |

#### 8.4.2 字段清单（12项，共161 bit）

| 序号 | 字段 | 位宽 | 来源状态 |
| --- | --- | --- | --- |
| 1 | `frame_id` | 16 | 现成（`ppg_control_top.o_result_frame_id`） |
| 2 | `sample_index` | 16 | 现成（`o_result_sample_index`） |
| 3 | `color_ir` | 1 | 现成（`o_result_color_ir`） |
| 4 | `frame_type` | 2 | 现成（`o_result_frame_type`） |
| 5 | `o_result_precision_mode` | 1 | 现成 |
| 6 | `coarse_ppg_value`+`coarse_valid`+`coarse_recovery_calibrated` | 24+1+1=26 | 现成 |
| 7 | `fine_ppg_value`+`fine_valid`+`fine_recovery_calibrated` | 24+1+1=26 | 现成；`precision_mode`=0时数值和`valid`均被RTL强制清零，FPGA必须先判`precision_mode`再决定是否使用本组字段 |
| 8 | `amb_code_snapshot`+`dc_code_snapshot` | 8+8=16 | 现成（`o_result_amb_code_snapshot`/`o_result_dc_code_snapshot`） |
| 9 | `amb_code_epoch`+`dc_code_epoch` | 4+4=8 | 现成（`o_result_amb_code_epoch`/`o_result_dc_code_epoch`），随IDAC搜索/跟踪持续更新，不是session级静态量 |
| 10 | `calibrated_s1_value` | 12 | 现成（`o_calibrated_s1_value`），裸值，无配套标志位 |
| 11 | `programmable_15_code`+`programmable_15_valid` | 15+1=16 | 现成（`o_programmable_15_code`/`o_programmable_15_valid`） |
| 12 | `s1_calibration_applied`+`stage1_raw`+`stage2_raw` | 1+10+10=21 | AMI/Top边界端口+glue顶层P2S打包器接入**均已实现**（V1.11勘误，`ppg_chip_digital_top.v:473-475,644-646`），见8.4.5节 |

字段顺序即上表序号顺序：身份/上下文（1-5）→最终结果（6-7）→校准码（8-9）→中间管线诊断（10-11）→原始码+其配套标志（12）。

#### 8.4.3 时序分析（`P2S_CLK`=`CLK_2M`下）

- 单包耗时：161 bit × 500ns = 80.5us；
- RED/IR两次结果间隔：约160个`CLK_2M`周期=80us（`C_MACRO_FRAME_TICKS=5000`宏帧内，RED Q3中心macro_tick=300，IR Q3中心macro_tick=460）；
- **80.5us已贴近甚至略超80us窗口，双光模式下每一帧都会触碰该边界，不是罕见极端情况**；
- IR完成到下一帧RED开始之前有约4840拍（2.42ms）的长空闲窗，单/双包在此窗口内发送裕量充足，不构成风险点。

#### 8.4.4 背压机制

复用既有`i_measurement_result_ready`/`o_measurement_result_valid`握手（不新增协议），并在P2S打包器内部增加**深度2缓冲**（161-bit宽×2，约322个触发器）：

- 打包器在结果一出现的1~2拍内即可接住（`i_measurement_result_ready`几乎瞬时拉高），不需要等前一包发送完；
- AMI的正式结果fork保持寄存器因此不会被P2S发送速度拖慢，`Scheduler`/`SSW`的时序完全不受P2S发送节奏影响；
- 深度2对应"一个宏帧最多RED+IR两笔结果"的真实业务节奏；
- **验证要求（非可选）**：RTL落地后，须用现有dual-tool仿真基础设施专门验证持续双光模式下深度2缓冲不会溢出（即不会出现同一宏帧内挤进第三笔待发送结果的场景）；若发现真实场景下确有三笔及以上结果需要排队，须在仿真中明确暴露而非静默丢弃，再决定是否扩深度。

#### 8.4.5 新增RTL（AMI+Top+glue顶层P2S打包器接入均已实现，V1.11勘误）

| 新增信号 | 来源（已溯源） | 说明 |
| --- | --- | --- |
| `stage1_raw`[9:0]、`stage2_raw`[9:0] | AMI内部`ppg_adc_dc_recovery`原子载荷`dec_payload_input`已打包`i_stage1_raw`/`i_stage2_raw`，AMI自身V1.8版本changelog明确记录"重构器诊断透传输出…暂时留空，等以后有真实消费方再接"——本次P2S设计即为该消费方 | 禁止改用pad级`DOUT_STAGE1/2_LOW`直连glue模块（同一物理线被RED/IR事务反复复用，读取时机稍晚即读到下一笔事务的值，导致数据与`frame_id`/`sample_index`错位），必须从AMI原子载荷取值 |
| `s1_calibration_applied` | ~~AMI内部"result fork payload"第949行解包出的`flag_unused_output_calibration`（变量名自证"未使用输出"），溯源至`ppg_adc_dc_recovery.v`第938行`enc_dc_result_payload`打包的`flag_dc_s1_calibration_applied`，与`dec_dc_s1_value`（即`o_calibrated_s1_value`）同一原子载荷、同拍锁存~~ **V1.16勘误：RTL实际导出的是结果fork之前DC恢复实例的`o_calibration_applied`（AMI内部线`flag_dc_s1_calibration_applied`，`ppg_adc_measurement_idac_integration.v:1029`，来源`:2278`），与`stage1_raw`/`stage2_raw`同取自DC恢复`payload_o`，不是fork解包字段** | ~~同源同拍，不存在错位风险；~~ **只有在下述“同笔前提”成立时才与正式结果同属一笔（V1.16勘误）；**Stage1自身的`flag_unused_output_s1_sat_low`/`flag_unused_output_s1_sat_high`（饱和标志）经8.4.6节讨论确认不需要导出 |

两处新增共需三步：① AMI新增对应输出端口（从内部wire转发到边界）——**已实现**，`ppg_adc_measurement_idac_integration.v`V1.14，端口名`o_s1_calibration_applied`/`o_s1_raw`/`o_s2_raw`；② Top新增对应输出端口（内部wire+assign转发，同`o_active_precision_mode`模式）——**已实现**，`ppg_control_top.v`V1.5，同名3个边界输出；③ glue顶层P2S打包器接入——**已实现**（V1.11勘误，`ppg_chip_digital_top.v`），实例化连线见`:473-475`（接入P2S打包器`i_s1_calibration_applied`/`i_stage1_raw`/`i_stage2_raw`）与`:644-646`（接`ppg_control_top`同名输出），三步至此全部完成。

**V1.16勘误：P2S遥测字段的同笔前提。** 三个遥测字段（`s1_calibration_applied`、`stage1_raw`、`stage2_raw`）取自AMI结果fork之前的DC恢复`payload_o`，而字段1-11取自结果fork寄存器（`ppg_adc_measurement_idac_integration.v:961`）。(a) 两者属于同一笔事务，**当且仅当**正式结果被持住期间没有下一笔事务进入DC恢复；否则遥测字段已是下一笔。(b) 在本glue顶层中，这一前提由三条结构条件保证：P2S打包器没有外部反压（只有`o_p2s_data`/`o_p2s_frame`两个对外输出，`ppg_p2s_packer.v:77-78`）；其`o_result_ready`就是深度2队列未满（`:129`、`:144`），每包在第161拍出队（`:125`）；每个5000拍宏帧最多2笔NORMAL正式结果、相隔160拍。P2S的ready直接接到`ppg_control_top`的`i_measurement_result_ready`（`ppg_chip_digital_top.v:519`），AMI正式结果因此从不被持住。(c) 该前提由`tb_ppg_chip_digital_top.v`的TC7永久断言守护（`:631-649`逐拍检查P2S `i_result_valid`为1时`o_result_ready`必须为1，`:907-911`给出最终判定）；第8.4.4节的深度、背压或包长若有改动，必须保证TC7仍然成立。这是对第8.4.5节原“同源同拍，不存在错位风险”结论的订正；RTL逻辑不变。

#### 8.4.6 明确排除、不放进P2S包的内容及理由

| 排除内容 | 理由 |
| --- | --- |
| 黄金参考值（`detect_code`、`nominal_15_code`+`valid`+`saturated`、`stage1_code_ext`、`stage2_code_ext`） | 均为固定公式从`stage1_raw`/`stage2_raw`可精确复现的结果，外部按已知公式自行计算即可，芯片重复传输是无信息增量的冗余 |
| session级模式标志（双光/单光、固定9/固定15、TEST、`run_profile`、`optical_mode`、`input_source`） | 用户确认实验室测试不会中途切换模式，session内静态，SPI配置阶段已知，无需每包重复 |
| `config_epoch`/`coef_epoch`/`stage2_coef_epoch`/`dc_recovery_coef_epoch`四个配置/系数版本号 | 与session级模式标志同一类静态信息（只在COMMIT新配置时变化，而session内不会重新COMMIT），验证"配置没有意外变化"用SPI测试前后各读一次即可，不需要每包携带 |
| 状态/故障事件快照（`o_system_fault_blocking`等） | 保持"P2S管数值、SPI管状态"分工；且能收到P2S包本身已隐含"这笔结果未被判定丢弃"（按C01 TOP-09，STOP/abort期间在途结果走显式discard，不以`valid`身份交付） |
| `coarse`/`fine`/`stage1`各自的饱和标志位（`saturation_low`/`saturation_high`） | RTL对饱和值做的是钳位到固定边界常数（如24-bit`-8388608`/`8388607`），"数值==边界常数"与"标志位=1"完全等价，外部检查数值本身即可判断，无需单独占位传输；`valid`/`recovery_calibrated`/`calibration_applied`类标志不受此逻辑影响，因为它们无法从数值反推，予以保留 |

### 8.5 `SPI_CS_N`作为协议异步复位/门控（V1.17新增，F-030）

`SPI_CS_N`不经同步链，直接作为SPI协议状态的异步复位/门控（`ppg_spi_register_file.v`中7个`always`块的敏感表含`posedge i_spi_cs_n`）。这是冻结设计，安全依据如下四点：

1. **被`SPI_CS_N`异步清零的只有7个协议状态寄存器**：`state_current`、`cnt_field_byte`、`reg_byte_addr`、`flag_cmd_is_read`、`reg_read_byte`、`cnt_bit_in_byte`、`reg_shift_in`。以下寄存器只受源域或系统复位，不受`SPI_CS_N`影响：`reg_active_shadow`、`reg_characterization`、`reg_dbg_out_select`、`flag_char_request_held`；`CLK_2M`域的`reg_diag_snapshot`、`reg_diag_snapshot_gated`、`reg_diag_sync_stable`、`reg_mr_latch`、`reg_dd_latch`；以及各`ppg_pulse_cdc_sync`的源域翻转寄存器。
2. **接口时序要求**（Mode 0下`SPI_CS_N`翻转时`SPI_SCLK`为低且静止）：
   - `SPI_CS_N`下降沿到第一个`SPI_SCLK`上升沿 ≥ t_su(CS)，且满足异步清零释放的recovery时间；
   - 最后一个`SPI_SCLK`上升沿到`SPI_CS_N`上升沿 ≥ t_h(CS)；
   - `SPI_CS_N`高电平宽度 ≥ t_cs_high。
3. **剩余风险**：传输中途`SPI_CS_N`出现毛刺，会让协议状态回到IDLE，后续比特被当作新命令字节解析，可能误写影子区或0x0090命令寄存器。这作为板级信号完整性要求；主机侧可配合写后读回校验。
4. **命令与写入不会被`SPI_CS_N`截断**：写入影子区、0x0080、0x0081，以及0x0090的命令触发（START/STOP/COMMIT/DIAG_CLEAR/ABORT/表征），都在该字节第8个`SPI_SCLK`上升沿由`flag_write_commit`成立时产生，并由源域时钟沿采样进脉冲CDC的源域翻转寄存器（只受源域复位）。读方向快照触发`flag_read_start`也在上升沿产生。这些都不依赖`SPI_CS_N`上升沿，此后`SPI_CS_N`的异步清零也不会截断已经产生的事件。字节不完整（第8个上升沿之前`SPI_CS_N`就升高）时不提交，这是正确行为。

### 8.6 产品固定参数（V1.17新增，F-014/F-024）

glue顶层例化的`ppg_control_top`参数为产品固定值，不得覆盖：`C_CONFIG_WIDTH=1024`；config/coef/DC-recovery epoch宽度8；code epoch宽度4；generation宽度8；frame/sample宽度16/16；supervisor看门狗5000/13（C01 §4.1 V1.10 final system boundary（V1.18）、C24 §1）。RTL不做elaboration期拒绝；仿真开始时按层次读取实际例化值核对，检查所在TB：`tb_ppg_chip_digital_top.v`（TB本地检查`PARAM-FIXED`、`PARAM-WDOG`）、`tb_ppg_control_top.v`（同名检查）、supervisor单元TB（`WDPARM`）。

## 9. 严格禁止

1. glue顶层不得在`ppg_control_top`之外重新实现或复制任何PPG测量、校准、检测算法逻辑；
2. glue顶层不得绕过C01已冻结的`i_source_*`握手直接把SPI寄存器接到`ppg_control_top`内部信号（对应C01"禁止SPI shadow直连功能模块"的精神）；
3. 第5节33路SSW模拟输出的改名直连不得插入反相、屏蔽、合并、延迟或任何时序元件；
4. `flag_adc_physical_idle`合成器不得用AND/OR等固定组合替代精度模式选择公式，也不得脱离C01 V1.11冻结的选择依据自建判据；
5. 除C01 V1.11已冻结的`o_active_precision_mode`、V1.12已冻结的`o_source_config_update_ready`，以及第8.4.5节`stage1_raw`/`stage2_raw`/`s1_calibration_applied`三个转发端口（V1.7勘误已在`ppg_control_top.v`V1.5实现）外，glue顶层不得要求对`ppg_control_top.v`做任何其他端口或逻辑修改；
6. 读方向、`DBG_OUT`选择值、P2S字段这三条待定CDC路径在细节确认前，不得用直接组合逻辑或单级触发器"临时"跨域，必须等第8节对应开放项确认后再实现；
7. P2S打包器的`stage1_raw`/`stage2_raw`/`s1_calibration_applied`不得直接连线pad级`DOUT_STAGE1/2_LOW`，必须来自AMI内部`ppg_adc_dc_recovery`原子载荷转发出的对应端口，理由见第8.4.5节；
8. P2S打包器内部深度2缓冲发生溢出（同一宏帧内出现第三笔待发送正式结果）时，不得静默丢弃任何一笔结果，必须在仿真/实现中显式暴露该场景；
9. P2S打包器背靠背发送两个包时，`P2S_FRAME`不得连续保持高电平覆盖两个包，每个包之间必须有至少1拍的低电平间隙；
10. `0x0114`/`0x011B`两组discard锁存必须使用翻转位（每次真实事件到来时连同身份字段一起翻转bit0），不得用普通粘滞位（只置位不翻转）实现，理由是主机需要能区分"两次轮询之间是否发生过新事件"，普通粘滞位一旦置位就无法区分；
11. `0x0090`共享命令字节允许一次原子写入同时置位多个bit（如STOP+ABORT同拍），SPI从机自身不得为此新增任何互斥/优先级限制逻辑，消歧完全依赖`ppg_control_top`已有的合并/优先级处理；
12. 7个验证注入端口（`i_test_inject_enable`、`i_test_identity_inject_valid`、`i_test_identity_inject_sample_index`、`i_test_invalid_sample_valid`、`i_test_saturation_inject_valid`、`i_test_calibration_loss_inject_valid`、`i_context_handover_stall_request`）不得出现在第11节字节级寄存器地图的任何地址上，生产环境的SPI接口不暴露验证注入能力。

## 10. 验收与状态边界

V1.11勘误前，本合同是**架构级冻结**，不是实现完成声明；glue顶层当时没有任何RTL/TB代码。**第8节全部开放项已于V1.6勘误确认完毕**（SPI协议参数、读方向CDC、`DBG_OUT`候选枚举、P2S固定包格式），架构级设计到此完整，可以进入RTL编写阶段。

**V1.11勘误起，glue顶层RTL/TB已首次实现**：`ppg_chip_digital_top.v`（V1.2）+`ppg_spi_register_file.v`（V1.2）+`ppg_p2s_packer.v`（V1.0）+`ppg_pulse_cdc_sync.v`（V1.0），四文件均通过`verilog_generated_deliverable_gate`（`ppg_chip_digital_top.v`仅剩已文档化接受的VG010封装引脚命名例外）；`tb_ppg_chip_digital_top.v`覆盖任务要求的六个验证方面全部有真实结论：前5项均真实触发通过，第6项（discard锁存翻转位）经V1.12勘误分析确认为架构级窄窗口、非bug、机制本身已通过替代真实触发路径独立验证，结案不新增RTL（见第11.3节）——**六个方面验证完整**。第8.4.4节标注的"非可选"仿真验证项（深度2缓冲不溢出）已在TC3场景中真实验证通过。V1.14勘误修复了`DBG_OUT`选择值一处真实CDC缺口（补齐第8.3节V1.5即已冻结的要求，非新决策），详见该条勘误。全链路回归确认`ppg_control_top.v`零回归（`SMOKE_TB_PASS real_adc_responses=47 measurement_result_valid=32`，与改动前逐位一致）。本合同的确认不改变、不解除C01（`PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`）的`NOT_CLOSED`门禁状态，也不构成`ppg_control_top`的TOP-01~24验收证据。

## 11. 字节级SPI寄存器地图（V1.11勘误首次写入，实现与用户三轮核对确认）

本节是第6节②"SPI从机"功能块描述的字节级落地，`ppg_spi_register_file.v`按本表实现。地址为16-bit，字节寻址，突发访问内地址自增（见第8.1节）。

### 11.1 写方向（`0x0000-0x00FF`）

| 地址范围 | 内容 | 说明 |
| --- | --- | --- |
| `0x0000-0x007F`（128字节） | 1024-bit V4+V5联合ACTIVE影子区 | 按字节寻址、字节内低位在前（`reg_active_shadow[{addr[6:0],3'b000}] +: 8`）；写入只更新影子区，COMMIT前可原样读回；不自动生效 |
| `0x0080` | 表征/STATIC_BIAS控制字节 | bit0=`i_source_static_characterization_enable`，bits[5:1]=`i_source_test_mux_ctrl[4:0]`，bits[7:6]保留 |
| `0x0081` | `DBG_OUT`选择字节 | bits[2:0]=候选值0~5（见第8.3节），bits[7:3]保留 |
| `0x0082-0x008F` | 保留 | 未定义，回读固定0 |
| `0x0090` | 共享命令字节，固定32-bit帧（1+2+1字节，见第8.1节） | bit0=START，bit1=STOP，bit2=COMMIT，bit3=DIAG_CLEAR，bit4=ABORT，bit5=表征更新触发；bits[7:6]保留；**允许一次写入同时置位多个bit，由`ppg_control_top`自己既有的合并/优先级逻辑消歧，SPI从机自身不做任何互斥限制**（第9节第11项要求）；一次性写入无持久内容，回读固定0 |
| `0x0091-0x00FF` | 保留 | 未定义，回读固定0 |

### 11.2 读方向（`0x0100-0x0125`，共38字节=304 bit，整体原子快照冻结，见第8.1节）

| 地址 | 内容 |
| --- | --- |
| `0x0100` | bits[1:0]=`o_lifecycle_state`，bit2=`o_start_ready`，bit3=`o_commit_ack_sticky`，bit4=`o_error_sticky`，bits[7:5]保留 |
| `0x0101` | `o_last_error_code` |
| `0x0102` | `o_schema_version` |
| `0x0103` | `o_config_epoch` |
| `0x0104` | `o_coef_epoch` |
| `0x0105` | `o_stage2_coef_epoch` |
| `0x0106` | `o_dc_recovery_coef_epoch` |
| `0x0107` | bit0=scheduler_idle，bit1=launch_timeout_sticky，bit2=owner_deadline_timeout_sticky，bit3=completion_mismatch_sticky，bit4=protocol_error_sticky，bit5=ami_datapath_empty，bit6=ami_idac_idle，bit7=`o_active_precision_mode` |
| `0x0108` | bit0=ami_integration_protocol_error_sticky，bit1=ssw_wrapper_idle，bit2=ssw_switch_protocol_error_sticky，bit3=ssw_transaction_mismatch_sticky，bit4=ssw_owner_deadline_timeout_sticky，bit5=ssw_calibration_timeout_sticky，~~bits[7:6]保留~~ bit6=ami_owner_lost_sticky（V1.17补记，owner生命周期轮，`ppg_spi_register_file.v` `i_ami_owner_lost_sticky`），bit7保留 |
| `0x0109` | bit0=source_config_update_ready，bit1=source_characterization_update_ready，bit2=characterization_control_valid，bit3=characterization_protocol_error_sticky，bits[7:4]保留 |
| `0x010A` | bit0=system_fault_blocking，bit1=fault_cause_valid，bit2=fault_identity_valid，bit3=fault_color_ir，bits[5:4]=fault_frame_type，bit6=fault_precision，bit7=result_discard_summary_sticky |
| `0x010B` | `o_system_fault_cause[7:0]` |
| `0x010C` | bits[3:0]=`o_system_fault_source[3:0]`，bits[7:4]保留 |
| `0x010D-0x010E` | `o_system_fault_frame_id[15:0]`（低字节先） |
| `0x010F-0x0110` | `o_system_fault_sample_index[15:0]`（低字节先） |
| `0x0111` | `o_system_fault_run_generation[7:0]` |
| `0x0112-0x0113` | `o_system_fault_summary[15:0]`（低字节先） |
| `0x0114` | 正式结果discard控制字节：bit0=翻转位，bits[2:1]=reason，bit3=identity_valid，bit4=sample_valid，bit5=color_ir，bits[7:6]=frame_type |
| `0x0115-0x0116` | 正式结果discard latched frame_id（低字节先） |
| `0x0117-0x0118` | 正式结果discard latched sample_index（低字节先） |
| `0x0119` | 正式结果discard latched run_generation |
| `0x011A` | bit0=正式结果discard latched precision（`o_measurement_result_discard_precision`），bits[7:1]保留 |
| `0x011B` | 检测discard控制字节：同`0x0114`布局 |
| `0x011C-0x011D` | 检测discard latched frame_id（低字节先） |
| `0x011E-0x011F` | 检测discard latched sample_index（低字节先） |
| `0x0120` | 检测discard latched config_epoch |
| `0x0121` | 检测discard latched coef_epoch |
| `0x0122` | 检测discard latched dc_recovery_epoch |
| `0x0123` | bits[3:0]=检测discard latched amb_code_epoch，bits[7:4]=检测discard latched dc_code_epoch |
| `0x0124` | 检测discard latched run_generation |
| `0x0125` | bit0=检测discard latched precision（`o_detection_discard_precision`），bits[7:1]保留 |

`0x0114`/`0x011B`两组discard锁存均使用**翻转位**而非普通粘滞位（第9节第10项要求）：真实discard事件发生时锁存整套身份字段并同时翻转bit0，主机两次轮询间比较bit0即可判断"是不是同一次事件"，不需要额外的清零命令。

**明确排除、不进入本地图的内容**（与第8.4.6节P2S排除清单是两条独立但呼应的列表）：12项P2S逐结果数值字段（P2S是它们的唯一通道）；7个验证注入端口`i_test_inject_enable`/`i_test_identity_inject_valid`/`i_test_identity_inject_sample_index`/`i_test_invalid_sample_valid`/`i_test_saturation_inject_valid`/`i_test_calibration_loss_inject_valid`/`i_context_handover_stall_request`（第9节第12项要求，生产环境不通过SPI暴露）；全部无持久/锁存伴生的裸单周期事件脉冲（`o_start_ack_event`/`o_stop_ack_event`/`o_error_event`/`o_system_abort_event`/`o_system_stop_request_event`/`o_characterization_control_update_event`/`o_characterization_control_reject_event`，这类事件只经`DBG_OUT`候选表对外可见）；`o_system_fault_discard_event`（追溯确认双重冗余：只喂给AMI自身`i_system_fault_discard_event`、并入`0x0114`/`0x011B`两组discard锁存已有的`reason=system-fault`路径，其裸事件本身已被`0x010A`的`fault_cause_valid`/`o_system_fault_summary`覆盖）。

### 11.3 discard锁存翻转位真实触发的架构级窄窗口（V1.12勘误：已结案，非bug，不新增专用通道）

`tb_ppg_chip_digital_top.v`验证第6项（两组discard锁存翻转位）时，尝试用"STOP命中一个真实在途owner"的场景（同`tb_ppg_control_top.v`已验证的SMOKE-06时序窗口）复现，经四种独立构造方法（STOP与真实DONE并发下发、剥离残留状态后重建干净现场再试、完全不补DONE只看STOP自身能否触发、把STOP提前到Q3仍拉高的采样窗口内下发）均未能真实触发任一discard锁存翻转，现象一致不变。定位的直接原因：STOPPING收尾条件`flag_stopping_complete`（`ppg_system_config_manager.v:463-464`）要求`i_adc_idle`为真，而glue顶层`flag_adc_physical_idle`合成器按C01 V1.11冻结公式即`!CLK_STAGE1/2_DOUT_LOW`——DOUT选通脉冲的取反，只要没有正在选通就恒为1；这与调度器自己"在途owner等待稍后到达的真实DONE"（`B_INFLIGHT`）语义天然脱节，STOPPING一旦被接受、`i_adc_idle`这一路几乎立即满足。真实存在的"主动STOP精确命中ADC选通脉冲那一瞬间"窗口理论上只有DOUT选通脉冲本身那几拍宽，而SPI一次命令事务（32-bit定长帧）本身就需要约16个`CLK_2M`周期，两者是不同数量级的物理量，不是可以靠调整RTL压缩的巧合窗口。

**V1.12勘误分析结论（已结案）**：`flag_stopping_complete`并非只由`i_adc_idle`单独把关，而是`i_adc_idle && i_datapath_empty && i_idac_idle && i_analog_safe`四路独立AND；真正防止"流水线在途数据被STOPPING收尾提前吞掉"的是`i_datapath_empty`（`ppg_adc_measurement_idac_integration.v:1140`的`o_datapath_empty`，聚合ADC chain、fork分支、FIR、detection fork、detector、controller、scheduler、calibration等8路以上子模块idle标志），真实数据流经这些阶段需要数十到上百个`CLK_2M`周期，与SPI命令事务传输延迟同一数量级，SPI STOP完全够得着这一路——`i_adc_idle`从未独自承担过防止数据丢失的职责，TC6打不中的窄窗口只发生在`i_adc_idle`这一路本身，不代表整条防线有缺口。discard锁存翻转位机制本身也已经用"无owner在途的spurious DONE脉冲经fault supervisor级联"这条更宽的真实触发通路正面验证工作正常（与P06发现的~2-3拍自动abort级联路径同源）。综合两点：**不新增专用硬件触发通道，也不新增QFN引脚**（48脚封装已多轮冻结，新增物理引脚的代价与本项开放项完全不成比例），维持现状。此项从未影响本节字节级地图的正确性，discard锁存的写入/翻转/清零路径本身按第9节第10项要求实现且已独立验证；面向主机固件作者的措辞澄清：**主机不需要、也不应该设计成依赖"STOP精确命中ADC选通脉冲瞬间"这一子场景来触发discard**——真实防止数据丢失的是`i_datapath_empty`这一路，任何在数据仍处于流水线中途时发出的STOP都会被正确挡在`i_datapath_empty`收尾之前，该机制已通过独立触发路径验证工作正常（触发通路为`i_control_abort_event`，与P06发现的约2-3拍自动abort级联同源）。

### 11.4 诊断地图逐位清除方式（V1.17新增）

读方向地图只反映`ppg_control_top`输出的当前值，SPI从机本身不清除任何诊断位。各位的清除方式由其源模块决定，下表按源分组写明。“诊断清除”指0x0090 bit3（DIAG_CLEAR）经Top注册式`flag_diag_clear_event`送达各源；manager状态清除经Top的`flag_status_clear_event`。

| 地址/位 | 源 | 置位 | 清除方式 | START是否清 |
| --- | --- | --- | --- | --- |
| 0x0100 bit3 commit_ack_sticky、bit4 error_sticky；0x0101 last_error_code | manager | 见C02 | 复位；manager状态清除（条件见C02） | 否 |
| 0x0107 bit1~bit4（调度器launch/owner-deadline/completion-mismatch/protocol sticky） | 调度器 | 见C08 | 复位；**新START清零**；诊断清除只在无活动宏帧、无在途owner、无owner-pending且无外部阻断时生效，所以RUN中实际清不掉（C08 §16.2、§16.5） | 是 |
| 0x0108 bit0 ami_integration_protocol_error_sticky | AMI | 见C10 §15.1 | 复位；诊断清除在“无活跃集成阻断，或RUN已由STOP结束且AMI排空”时生效（C10 §15.1） | 否 |
| 0x0108 bit6 ami_owner_lost_sticky | AMI | 任一槽位ADC完成丢失超时作废（C10 §7.1a） | 复位；诊断清除在“lane 06未保持，或RUN已由STOP结束且排空”时生效；同拍新作废优先（C10 §15.1） | 否 |
| 0x0108 bit2~bit5（SSW switch-protocol/transaction-mismatch/owner-deadline/calibration-timeout sticky） | SSW | 见C09 | 复位；START恢复（C09 §8.3a）；诊断清除在SSW `o_wrapper_idle`时生效 | 是（START恢复成立时） |
| 0x0109 bit3 characterization_protocol_error_sticky | 表征CDC | 见C07 | 复位；诊断清除 | 否 |
| 0x010A bit1~bit6、0x010B~0x0113（supervisor首故障快照与summary） | supervisor | 首个阻断故障记录捕获快照；之后的故障只置summary位 | 复位；合法诊断清除（全部本地故障已恢复后，C24 §5）。首故障快照只在首次捕获时写入，episode关闭后若尚未清除，新episode不覆盖它；清除后的下一个阻断故障重新捕获快照 | 否 |
| 0x010A bit7 result_discard_summary_sticky | supervisor | AMI正式结果discard事件（含COMPLETION_LOST） | 复位；合法诊断清除 | 否 |
| 0x0114~0x0125 discard锁存 | SPI寄存器文件`CLK_2M`域锁存 | 每次discard事件整体锁存并翻转bit0 | 不清除，下次事件覆盖（翻转位语义，§11.2） | 否 |
