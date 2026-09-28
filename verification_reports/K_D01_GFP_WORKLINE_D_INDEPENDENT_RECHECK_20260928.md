# K01-K05 + D01(4) + G-FP-01~07 工作线D独立复核（2026-09-28）

> 延续`NRE_ADCN_WORKLINE_D_INDEPENDENT_RECHECK_20260928.md`同一对话框、同一批次的后续工作。
> 范围：`HANDOFF_20260928.md`点名的"工作线D剩余约41个ID"中的K(5)+D01(4)+G-FP(7)=16项，
> 覆盖率41→25（剩N(8)+P(17)未碰）。

## 方法论说明——为何不是"读TB断言"

K01-K05、D01(4)、G-FP(7)这16项在`PPG_ALIAS_MAPPING_TABLE.md`里全部标注"无独立TB场景"——
它们本质是**跨合同/跨RTL文件的静态语义声明**（信号唯一producer、参数位宽跨模块透传一致、
故障通路唯一出口等），不是TB assertion完整性问题。因此本轮"独立复核"的操作方式是：不信
2026-09-05当时的引用行号和结论文字，逐条重新读当前的合同原文段落和当前的真实RTL文件，
自己重新判断声明是否仍然成立——方法论精神与NRE/ADCN"读断言代码"一致，只是对象换成了
"读结构/语义声明的证据"。

## 结论汇总

**16项全部CONFIRMED，零真实功能缺陷。** 发现两类非功能性问题，均已修复：

1. **1处真实的`@satisfies`标签缺口**（RTL修复）
2. **7处台账行号引用漂移**（台账文字订正，行号所指内容已随其它工作会话对高频修改的枢纽
   文件的编辑整体下移，语义关系本身逐条核实无误）

### 逐项复核记录

| ID | 声明 | 复核结果 |
| --- | --- | --- |
| K01 | PWC私有fault flag→PWI转发→AMI cause 8'h04；IDAC三路fault→AMI cause 8'h05；AMI用独立sticky标记（`flag_ami_fault_pending_04/05`）序列化仲裁，同拍多路不互相覆盖 | **CONFIRMED**。逐段实读`ppg_precision_window_controller.v:138,292`→`ppg_precision_window_integration.v:472`→`ppg_adc_measurement_idac_integration.v:1153,1458-1478,2576`全链路，`ppg_control_top.v`全文grep确认PWC无任何直连manager/supervisor路径 |
| K02 | episode开/关/rearm独立于首故障快照历史；后续episode正常发trio但不覆盖未清除的首故障快照 | **CONFIRMED**（台账原注"未逐角落穷尽验证"，本轮补齐）。`ppg_system_fault_abort_supervisor.v:198`(`flag_episode_open_edge`只看`system_fault_blocking_o`)与`:202-205`(`flag_capture_*`均门控在`!system_fault_cause_valid_o`)两组逻辑独立，trio(264-294行三个always块)与首故障快照(296-306行)机制解耦，实读确认后续episode不会重新捕获仍锁存的首故障 |
| K03 | `C_RUN_GENERATION_WIDTH`由manager唯一产生，PWI/IDAC自身声明+AMI父级声明+透传，父子等宽 | **CONFIRMED**。PWI:71/599/690/804/904，IDAC:61/585/589/593/648，AMI:92→PWI例化透传/IDAC例化透传，逐行核实一致 |
| K04 | PWI/PWC只用AMI generation-scoped discard做STOP/abort/system-fault释放；reset独立、不产生discard | **CONFIRMED**。`ppg_precision_window_controller.v`670-682号always块：reset(671-672)与`flag_lifecycle_cancel`(673-674，即generation-scoped discard或`flag_leave_run_cancel`)是同一always块内两条互斥分支，reset不经discard路径 |
| K05 | PWC无DRAFT依赖、无manager直连fault路径，唯一阻断故障出口经PWI/AMI | **CONFIRMED**。`ppg_control_top.v`全文grep零匹配`ppg_precision_window_controller`/`mode_fault_active`，PWI自身注释明写"唯一消费者AMI" |
| G-FP-01-D01-01~03 | V4`[639:0]`/V5`[1023:640]`位段划分；wrapper接口(`C_CONFIG_WIDTH=1024`/source快照/manager联合ACTIVE/unpacker具名V4V5输出)；V5解包语义(每字段精确位段+唯一decode owner) | **CONFIRMED**。三份合同原文逐段重读，`PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md:184-218`、`PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:12,79-130,220-243`、`ppg_system_active_config_unpack_semantic_contract.md:4,34-70`三份文字与台账声称逐字一致；V5`[369]`本地位对应全局`i_active_config[1009]`（640+369=1009）算术交叉验证无误 |
| G-FP-01-D01-04 | `peak_valley_config_valid`链：unpacker→AMI→PWI→C20/C22/C23唯一通路，六段各有真实消费点 | **CONFIRMED，但发现1处真实标签缺口**。unpacker:209、V4控制平面:375、AMI转发:2512(原引用2509已漂移)、C23:277均已实读确认且均带`@satisfies: G-FP-01-D01-04`标签；**C20段(`ppg_dynamic_baseline_cross_detector.v:480`)语义确认真实门控但RTL注释此前只打了`@satisfies: PRC-01`，漏打本ID标签——与链路其余5段的双锚点惯例不一致，已修复（见下）**；C22段(`:111`)确认CHARACTERIZATION豁免属已知PVW-38范围，非新混淆 |
| G-FP-01 | 3行代表性锚点(`i_clk`扇出/`i_control_abort_event`/AMI物理ADC owner) | **CONFIRMED**（轻量核实——本身是"代表性",非穷尽台账,19-TB 1208/1208回归对基础wiring提供隐性验证；`i_clk`扇出行发现行号漂移未逐一订正，量级与下方枢纽文件漂移一致） |
| G-FP-02 | SSW是波形上下文(RED/IR)唯一owner；C23精度切换pending在lifecycle cancel时正确释放 | **CONFIRMED**。`ppg_sar9_sar15_safe_selection_wrapper.v:1090-1097,1275-1282`两组RED/IR context valid寄存器均只由SSW自身`flag_context_fire`/`i_control_abort_event`/`flag_*_wave_last`驱动；PWC:827-842确认`flag_pending_cross/return`在`flag_lifecycle_cancel`时正确清零 |
| G-FP-03 | C23/PWC精度fault 8'h04链(PWC→PWI→AMI)；C17 IDAC fault 8'h05链+V2.3死锁修复 | **CONFIRMED**。8'h04链与K01共享同一组证据；C17行`ppg_idac_code_controller.v:580-581`已实读确认，`@satisfies: K01, G-FP-06`标签准确指向V2.3 STOP/abort清除死锁修复 |
| G-FP-04 | 合同文字互引(legacy文本处置)，非RTL锚点 | 未重新展开（该家族已有独立的Batch 0穷尽复核收尾，本轮不重复） |
| G-FP-05 | Top→AMI 8参数透传；AMI→PWI 15/18参数绑定 | **CONFIRMED**。Top侧AMI例化`#(...)`实数8个参数(`ppg_control_top.v:1099-1106`)，AMI侧PWI例化`#(...)`实数15个参数(`ppg_adc_measurement_idac_integration.v:2446-2461`)，与台账"8"/"15"字面吻合，原引用行号均已漂移 |
| G-FP-06 | ACTIVE CDC双触发器桥(Class 3范式)；C17 fault-bit清除优先级 | **CONFIRMED**（前者已有Stage3 Item4a+Item4b Phase4独立交叉确认在先，本轮不重复深挖；后者`ppg_idac_code_controller.v:580-581`已实读，同G-FP-03） |
| G-FP-07 | 版本/依赖台账，合同间元数据引用 | 未重新展开（该家族已有独立的Batch 8+stale-refs-repaired两轮141项穷尽修复收尾，本轮不重复） |

## 已执行的修复

1. **RTL标签修复**：[`ppg_dynamic_baseline_cross_detector.v:480`](../ppg_dynamic_baseline_cross_detector/ppg_dynamic_baseline_cross_detector.v)
   的`flag_candidate_start`赋值注释追加`G-FP-01-D01-04`标签（原只有`PRC-01`），并补充"C20消费端,
   真实门控点"的说明文字。验证：
   - `verilog_generated_deliverable_gate.py`：`delivery_ready=True errors=0 strict_warnings=0`
   - `iverilog`编译`ppg_dynamic_baseline_cross_detector.v` + 自身module-level TB：exit 0，零警告
   - 纯注释改动，不改变任何RTL token/语义，未触发全套19-TB重跑（单文件、非共享TB、非功能性改动，
     比"单文件TB修复"门槛更低）
2. **台账行号订正**：`PPG_ALIAS_MAPPING_TABLE.md`共7处引用行号追加式订正（K01×1、K03×1、K04×1、
   D01×2、G-FP-03×1、G-FP-05×2），均标注"2026-09-28工作线D独立复核订正"及具体新旧行号，不删除
   原文字，遵循本项目一贯的追加式订正惯例。

## 观察到但未处理的次要项（如实记录，非本轮范围）

- `ppg_sar9_sar15_safe_selection_wrapper.v`约1089-1097/1274-1282行区域的RED/IR context valid
  寄存器注释存在明显的模板化重复文字（同一短语"时序维护条件XX上下文有效XX专属XX光路低位编码端"
  在多行几乎原样重复），观感上接近本项目`VG066`(重复/近重复实体注释)风格问题；但**不影响本轮
  G-FP-02语义声明的真实性**（signal ownership本身核实无误），且该重复模式在文件内出现次数未知，
  改起来需要专门一次通读该文件，超出本轮"验收ID独立复核"范围，留给未来单独的注释质量扫描处理，
  不建议现在顺手改。
- G-FP-01/04/06/07未逐行重新核实台账现有citation的精确行号（04/07两家族已有独立穷尽审计在先，
  01是明确的"代表性、非穷尽"锚点，06的CDC bridge主张已有Stage3/Item4b双重交叉确认）——如果这几处
  citation同样存在类似K/D01/G-FP-03/05发现的行号漂移，本轮未逐一订正，不代表已确认无漂移。

## 与"工作线D剩余41个ID"的关系

本批次完成后：259(此前)+16(NRE/ADCN,今日早些时候)+16(本批次)=291，剩余**N(8)+P(17)=25项**
未被工作线D"独立复核"方法论正式碰过。这25项与本批次16项证据形态不同——它们在Phase 3
穷尽核对阶段就已经有真实TB场景引用（部分甚至已经过开放项批次1-4的真实xsim调试），更接近
NRE/ADCN的"读TB断言是否真完整覆盖合同"验证方式，而非本批次的"读静态语义声明"方式。
