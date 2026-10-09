# 锚点第二轮：重新分类计数与抽样（统筹2026-10-09裁定）

规则见`tools/b_merge_tools/anchor_history_rules.py`（自测与负对照：`history_rules_selftest.txt`、`history_rules_negctl.txt`）。下表只列第二轮有变化的锚点：第一轮的“带日期叙述”1473个按新规则重新分类，另有第一轮已转换的锚点被回退或改写。

## 计数

| 第一轮 → 第二轮 | 数量 |
|---|---:|
| dated→convert | 1333 |
| dated→convert (uncertain) | 48 |
| dated→convert (uncertain) [manual] | 1 |
| dated→convert [manual] | 73 |
| dated→history-block | 17 |
| dated→not-anchor | 1 |
| 第一轮已转换→history-block（恢复原文） | 12 |
| 第一轮转换改写 | 4 |

第二轮之后全部9702个锚点：convert 9254、external 3、history 1、history-block 30、history-strike 410、not-anchor 4。修订记录节（history-revision）与被明示取代的旧条目（history-superseded）在两份文件中均为0个。

## 抽样（每类若干条：原文上下文中【】为旧锚点，后为新文本）

### dated→convert（1333条，列出6条）

| 文件:基线行 | 原文 | 新文本 | 理由 |
|---|---|---|---|
| 矩阵:1340 | tion_wrapper.v:77`） ← 网`sched_macro_tick_o` ← Scheduler.o_macro_tick（` **[ppg_control_top.v:947]** `；声明`ppg_400hz_frame_cali | `ppg_control_top.v` `o_macro_tick` |  |
| 矩阵:1356 | 独立复核批次1收尾）**：**C01合同规定的子模块连接，不是Top自身端口**。表征CDC.i_source_update_valid（` **[ppg_control_top.v:842]** `；声明`ppg_characterization | `ppg_control_top.v` `i_source_update_valid` |  |
| 矩阵:1377 | 核批次1收尾）**：**C01合同规定的子模块连接，不是Top自身端口**。AMI.i_transaction_sample_index（` **[ppg_control_top.v:1128]** `；声明`ppg_adc_measurement_ | `ppg_control_top.v` `i_transaction_sample_index` |  |
| 矩阵:1380 | valid_o` → Scheduler.i_active_config_valid（`ppg_control_top.v:869`；声明` **[ppg_400hz_frame_calibration_scheduler.v:82]** `）、AMI.i_active_config_va | `ppg_400hz_frame_calibration_scheduler.v` `i_active_config_valid` |  |
| 矩阵:1440 | ansaction_amb_code_snapshot_o` → AMI.i_transaction_amb_code_snapshot（` **[ppg_control_top.v:1131]** `；声明`ppg_adc_measurement_ | `ppg_control_top.v` `i_transaction_amb_code_snapshot` |  |
| 矩阵:1508 | -16新增行（批次1查出的65个从未入账的真实Top端口之一；组行覆盖；C01合同字面命中0次）**：Top自身边界端口。Top边界输入（` **[ppg_control_top.v:118]** `，1）→ AMI.i_clk_stage1_do | `ppg_control_top.v` `i_clk_stage1_dout_low_async` |  |

### dated→convert (uncertain)（48条，列出48条）

| 文件:基线行 | 原文 | 新文本 | 理由 |
|---|---|---|---|
| 矩阵:1571 | ；C01合同字面命中0次）**：Top自身边界端口。Top边界输出（`ppg_control_top.v:292`，[9:0]）← Top  **[`:1598`]**  `o_s2_raw = ami_s2_raw_o | `ppg_control_top.v` `o_s2_raw`、`sched_cal_owner_deadline_event_o` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:1571 | op.v:292`，[9:0]）← Top `:1598` `o_s2_raw = ami_s2_raw_o`←AMI.o_s2_raw（` **[ppg_control_top.v:1372]** `；声明`ppg_adc_measurement_ | `ppg_control_top.v` `o_s2_raw` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:1571 | 8` `o_s2_raw = ami_s2_raw_o`←AMI.o_s2_raw（`ppg_control_top.v:1372`；声明` **[ppg_adc_measurement_idac_integration.v:402]** `）。位宽10-bit，与子模块声明数值一致 ** | `ppg_adc_measurement_idac_integration.v` `o_s2_raw` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:1571 | 块末尾说明）**：SID-05没有新增Top端口，只新增Top内部网`sched_cal_owner_deadline_event_o`（` **[ppg_control_top.v:553]** `，调度器侧连接`:963`、AMI侧连接`:11 | `ppg_control_top.v` `sched_cal_owner_deadline_event_o` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:1571 | op内部网`sched_cal_owner_deadline_event_o`（`ppg_control_top.v:553`，调度器侧连接 **[`:963`]** 、AMI侧连接`:1151`；C01 V1.15勘 | `ppg_control_top.v` `sched_cal_owner_deadline_event_o` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:1571 | al_owner_deadline_event_o`（`ppg_control_top.v:553`，调度器侧连接`:963`、AMI侧连接 **[`:1151`]** ；C01 V1.15勘误已在第6.3节记录）。本台 | `ppg_control_top.v` `sched_cal_owner_deadline_event_o` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2147 |  `o_idac_idle` port, C10 row below.~~ **2026-09-28独立审计(批次3)勘误**：正确连接行为 **[`:2442`]** （见下方整体说明）。C17 now 122/122 | `ppg_adc_measurement_idac_integration.v` `idac_idle_o` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2147 | ract. **2026-09-28独立审计（批次3，G-FP-01批次2-9独立复核）结论**：独立重建C17全部122个端口的事实库（` **[ppg_idac_code_controller.v:67-207]** `声明区+`ppg_adc_measurement | `ppg_idac_code_controller.v` `o_idac_idle` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2147 | 例化连接区），与矩阵本行以上全部122行逐行核对，方向列(input/output)、端口名对应关系、模块自身文件内引用（声明行+实现行，如 **[`:602-682`]** ）、signed/位宽（`i_amb_thresh | `ppg_idac_code_controller.v` `o_idac_idle` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2147 | **：本行以上C17全部122行中，凡指向`ppg_adc_measurement_idac_integration.v`的行号引用（形如" **[`:2306`]** "至"`:2427`"）统一比实际行号少15——即 | `ppg_idac_code_controller.v` `o_idac_idle` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2147 | 全部122行中，凡指向`ppg_adc_measurement_idac_integration.v`的行号引用（形如"`:2306`"至" **[`:2427`]** "）统一比实际行号少15——即矩阵标注的行号N，实 | `ppg_idac_code_controller.v` `o_idac_idle` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2147 | 行号引用（形如"`:2306`"至"`:2427`"）统一比实际行号少15——即矩阵标注的行号N，实际应为N+15（例：`i_clk`矩阵标 **[`:2306`]** ，实际`:2321`；本行`o_idac_idle | `ppg_idac_code_controller.v` `o_idac_idle` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2147 | 2306`"至"`:2427`"）统一比实际行号少15——即矩阵标注的行号N，实际应为N+15（例：`i_clk`矩阵标`:2306`，实际 **[`:2321`]** ；本行`o_idac_idle`矩阵标`:2427 | `ppg_idac_code_controller.v` `o_idac_idle` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2147 | 5——即矩阵标注的行号N，实际应为N+15（例：`i_clk`矩阵标`:2306`，实际`:2321`；本行`o_idac_idle`矩阵标 **[`:2427`]** ，实际`:2442`）。已在40+个样本点用端口名 | `ppg_idac_code_controller.v` `o_idac_idle` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2147 | 号N，实际应为N+15（例：`i_clk`矩阵标`:2306`，实际`:2321`；本行`o_idac_idle`矩阵标`:2427`，实际 **[`:2442`]** ）。已在40+个样本点用端口名逐一核对（非仅算术） | `ppg_idac_code_controller.v` `o_idac_idle` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 计(批次3)勘误**：拆分数算错，按本表上方2787-2860行逐行Direction列实际统计为**34 in + 40 out**（与` **[ppg_normal_transaction_fork.v:61-146]** `独立核对的端口声明完全一致），并非37+37；" | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | t); cluster ⑥ complete for this contract share。**审计补充**：本子模块自身文件声明行引用（ **[`:61-146`]** ）全部核实准确；但本表2787-2860行中凡指向 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 表2787-2860行中凡指向`ppg_adc_measurement_idac_integration.v`的行号引用（如`i_clk`标 **[`:1972`]** 、`i_measurement_ready`所引的 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | ent_idac_integration.v`的行号引用（如`i_clk`标`:1972`、`i_measurement_ready`所引的 **[`:2005`]** 等）与C17同一系统性问题——统一比实际行号少15 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 、`i_measurement_ready`所引的`:2005`等）与C17同一系统性问题——统一比实际行号少15（例：`i_clk`矩阵标 **[`:1972`]** ,实际`:1987`；`i_datapath_di | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | ement_ready`所引的`:2005`等）与C17同一系统性问题——统一比实际行号少15（例：`i_clk`矩阵标`:1972`,实际 **[`:1987`]** ；`i_datapath_discard_run_ | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 5（例：`i_clk`矩阵标`:1972`,实际`:1987`；`i_datapath_discard_run_generation`矩阵标 **[`:1983`]** ,实际`:1998`）。已用40+样本点端口名核对 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | `矩阵标`:1972`,实际`:1987`；`i_datapath_discard_run_generation`矩阵标`:1983`,实际 **[`:1998`]** ）。已用40+样本点端口名核对验证零例外，根因同上 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 0个数字，已逐个按端口名/信号名对照RTL独立核实，并在各行原地订正（删除线保留旧数字，加粗为核实后的真实行号）：fork自身连接点21个（ **[`:2005`]** -`:2025`→`:2020`-`:2040`） | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 按端口名/信号名对照RTL独立核实，并在各行原地订正（删除线保留旧数字，加粗为核实后的真实行号）：fork自身连接点21个（`:2005`- **[`:2025`]** →`:2020`-`:2040`）；`ppg_ad | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 对照RTL独立核实，并在各行原地订正（删除线保留旧数字，加粗为核实后的真实行号）：fork自身连接点21个（`:2005`-`:2025`→ **[`:2020`]** -`:2040`）；`ppg_adc_pipeli | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 实，并在各行原地订正（删除线保留旧数字，加粗为核实后的真实行号）：fork自身连接点21个（`:2005`-`:2025`→`:2020`- **[`:2040`]** ）；`ppg_adc_pipeline_overl | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | `:2025`→`:2020`-`:2040`）；`ppg_adc_pipeline_overlap_corrector`例化连接点21个（ **[`:2071`]** -`:2090`及`:2092`→`:2086`- | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | `:2020`-`:2040`）；`ppg_adc_pipeline_overlap_corrector`例化连接点21个（`:2071`- **[`:2090`]** 及`:2092`→`:2086`-`:2105`及 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | `:2040`）；`ppg_adc_pipeline_overlap_corrector`例化连接点21个（`:2071`-`:2090`及 **[`:2092`]** →`:2086`-`:2105`及`:2107`， | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | ；`ppg_adc_pipeline_overlap_corrector`例化连接点21个（`:2071`-`:2090`及`:2092`→ **[`:2086`]** -`:2105`及`:2107`，逐端口名对照AM | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | c_pipeline_overlap_corrector`例化连接点21个（`:2071`-`:2090`及`:2092`→`:2086`- **[`:2105`]** 及`:2107`，逐端口名对照AMI内该例化`:2 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | ne_overlap_corrector`例化连接点21个（`:2071`-`:2090`及`:2092`→`:2086`-`:2105`及 **[`:2107`]** ，逐端口名对照AMI内该例化`:2074`-`:2 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 例化连接点21个（`:2071`-`:2090`及`:2092`→`:2086`-`:2105`及`:2107`，逐端口名对照AMI内该例化 **[`:2074`]** -`:2135`得出，非套用公式；仅限本区间引用的 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | （`:2071`-`:2090`及`:2092`→`:2086`-`:2105`及`:2107`，逐端口名对照AMI内该例化`:2074`- **[`:2135`]** 得出，非套用公式；仅限本区间引用的这21个连接点， | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 4`-`:2135`得出，非套用公式；仅限本区间引用的这21个连接点，C13台账2861起未审计、未改动）；IDAC控制器例化连接点16个（ **[`:2359`]** -`:2374`→`:2374`-`:2389`， | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 5`得出，非套用公式；仅限本区间引用的这21个连接点，C13台账2861起未审计、未改动）；IDAC控制器例化连接点16个（`:2359`- **[`:2374`]** →`:2374`-`:2389`，与C17台账20 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 公式；仅限本区间引用的这21个连接点，C13台账2861起未审计、未改动）；IDAC控制器例化连接点16个（`:2359`-`:2374`→ **[`:2374`]** -`:2389`，与C17台账2079-2094行 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 引用的这21个连接点，C13台账2861起未审计、未改动）；IDAC控制器例化连接点16个（`:2359`-`:2374`→`:2374`- **[`:2389`]** ，与C17台账2079-2094行已订正锚点逐一互 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | （`:2359`-`:2374`→`:2374`-`:2389`，与C17台账2079-2094行已订正锚点逐一互证）；AMI内部信号2个（ **[`:1336`]** →`:1351`，`:912`→`:919`）。* | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | -`:2374`→`:2374`-`:2389`，与C17台账2079-2094行已订正锚点逐一互证）；AMI内部信号2个（`:1336`→ **[`:1351`]** ，`:912`→`:919`）。**60个数字全部 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | →`:2374`-`:2389`，与C17台账2079-2094行已订正锚点逐一互证）；AMI内部信号2个（`:1336`→`:1351`， **[`:912`]** →`:919`）。**60个数字全部可独立核实并订 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | `-`:2389`，与C17台账2079-2094行已订正锚点逐一互证）；AMI内部信号2个（`:1336`→`:1351`，`:912`→ **[`:919`]** ）。**60个数字全部可独立核实并订正，没有需要留 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | `:1351`，`:912`→`:919`）。**60个数字全部可独立核实并订正，没有需要留白标注的项。** **偏移并非处处为+15**： **[`:912`]** 实际只差+7，因此本行上文"统一比实际行号少15/ | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 本行上文"统一比实际行号少15/AMI文件同一处15行插入所致"的推断只适用于fork/corrector/IDAC三个例化块内的连接锚点及 **[`:1336`]** 处，AMI靠前部分的内部信号引用须逐个按信号名核对 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | ctor/IDAC三个例化块内的连接锚点及`:1336`处，AMI靠前部分的内部信号引用须逐个按信号名核对（证据见附录三）。另：上文引用的" **[`:2005,2092`]** "顺序有误，2820行原格实为"`:2092,20 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:2860 | 处，AMI靠前部分的内部信号引用须逐个按信号名核对（证据见附录三）。另：上文引用的"`:2005,2092`"顺序有误，2820行原格实为" **[`:2092,2005`]** "（先corrector输出连接点，后fork输入 | `ppg_normal_transaction_fork.v` `o_local_empty` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |
| 矩阵:3189 | 10台账末尾汇总说明）**：SID-05新增端口`i_cal_owner_deadline_event`（AMI RTL V1.15，声明` **[ppg_adc_measurement_idac_integration.v:153]** `；C10 V2.2已在第6.6节端口表补入）尚未 | `ppg_adc_measurement_idac_integration.v` `i_cal_owner_deadline_event` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理 |

### dated→convert (uncertain) [manual]（1条，列出1条）

| 文件:基线行 | 原文 | 新文本 | 理由 |
|---|---|---|---|
| 矩阵:1571 | 账的真实Top端口之一；C01缺口：V1.5新增端口，C01至今未收录；C01合同字面命中0次）**：Top自身边界端口。Top边界输出（` **[ppg_control_top.v:292]** `，[9:0]）← Top `:1598` `o_ | `ppg_control_top.v` `o_s2_raw` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |

### dated→convert [manual]（73条，列出6条）

| 文件:基线行 | 原文 | 新文本 | 理由 |
|---|---|---|---|
| 别名表:260 | .4.8"OWNER-IDENTITY-BACKPRESSURE"家族)的验收文字近乎逐字重复，两者共享同一原子payload寄存器机制(` **[ppg_adc_measurement_idac_integration.v:1745]** `的`reg_result_fork_payloa | `ppg_adc_measurement_idac_integration.v` `reg_result_fork_payload` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：右侧引文reg_result_fork_payload<=enc_dc_result_payload |
| 别名表:277 | B候选总线)与DCS_CAL(驱动已确认AMB+选定颜色DC总线)共享`:742`(AMB总线，两种校准帧类型行为相同)，DC总线的分岔点在 **[`:745`]** (EN_9_DC使能门控)与`:747`(DC9码 | `ppg_sar9_sar15_safe_selection_wrapper.v` `CTRL_EN_9_DC` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：ISE-06“EN_9_DC使能门控”；写入时SSW:745为CTRL_EN_9_DC赋值 |
| 别名表:340 | **2026-09-17工作线D复核确认原场景全程`i_recheck_busy=0`，对该信号零判别力。已补`PVW-32-BUSY`（` **[tb_ppg_peak_valley_window_detector.v:875]** `）：真实驱动`i_recheck_busy=1` | `tb_ppg_peak_valley_window_detector.v` `"PVW-32-BUSY"` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“已补PVW-32-BUSY(…)” |
| 矩阵:1390 | wns this row.~~ **2026-09-16重建（G-FP-01独立复核批次1收尾）**：Top自身边界端口。Top边界输出（` **[ppg_control_top.v:231]** `，1）← Top `:1537` `o_char | `ppg_control_top.v` `o_characterization_control_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵:1410 | r9_sar15_safe_selection_wrapper.v:69`）、Top内部网`measurement_run_enable`（ **[`:409`]** ）→Scheduler.i_run_enable（ | `ppg_control_top.v` `measurement_run_enable` | 第二轮：“Top内部网`measurement_run_enable`（:N）”，按格内网名 |
| 矩阵:1418 | r9_sar15_safe_selection_wrapper.v:90`）、Top内部网`measurement_run_enable`（ **[`:409`]** ）→Scheduler.i_run_enable（ | `ppg_control_top.v` `measurement_run_enable` | 第二轮：“Top内部网`measurement_run_enable`（:N）”，按格内网名 |

### dated→history-block（17条，列出6条）

| 文件:基线行 | 原文 | 新文本 | 理由 |
|---|---|---|---|
| 别名表:485 | > **本次(2026-09-06)25项P/N穷尽核对小结** **[:19]** 项`CLOSED`(P02,P03,P04,P05 | （保留原文） |  |
| 矩阵:1314 | 46`; `o_stop_ack_event` omits Scheduler/SSW/AMI `i_stop_ack_event` at  **[`:873]** /:991/:1111`). (4) 0 of 1 | （保留原文） |  |
| 矩阵:1314 | p_ack_event` omits Scheduler/SSW/AMI `i_stop_ack_event` at `:873/:991/ **[:1111`]** ). (4) 0 of 185 contract  | （保留原文） |  |
| 矩阵:1314 | not Scheduler/SSW/AMI; `o_scheduler_idle`/`o_ssw_wrapper_idle` -- C01  **[`:632`]**  is the prohibited-`i_adc | （保留原文） |  |
| 矩阵:1314 | er_idle` -- C01 `:632` is the prohibited-`i_adc_idle` list, now `:634/ **[:635`]** , not an idle-source mapp | （保留原文） |  |
| 矩阵:1316 | er_active_config_o` at `:746`, `wrapper_config_transport_update_o` at  **[`:745`]** ) alongside the three SSW | （保留原文） |  |

### dated→not-anchor（1条，列出1条）

| 文件:基线行 | 原文 | 新文本 | 理由 |
|---|---|---|---|
| 矩阵:3832 | 次N08自己的矩阵行文字已同步更新为CLOSED,不再落入本类。**Stage 2批次1(2026-09-10)逐项核对了原15项里的前8项 **[:2]** 项(`G-FP-02`/`G-FP-06`)是真实 | （保留原文） | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“前8项:2项(G-FP-02/G-FP-06)”计数，不是行号 |

### 第一轮已转换→history-block（恢复原文）（12条，列出6条）

| 文件:基线行 | 原文 | 新文本 | 理由 |
|---|---|---|---|
| 别名表:523 | > 顶层端口,而是` **[ppg_system_config_manager.v:457]** `门控的ACTIVE V5寄存器位,COMMIT只 | （保留原文） |  |
| 矩阵:965 | >   half): re-verified directly against ` **[ppg_system_config_manager.v:528-538]** ` | （保留原文） |  |
| 矩阵:3623 | > rows in Section 12.5 (e.g. C03:249, C05:94,  **[C10:257]** , C20:781, C22:679, | （保留原文） |  |
| 矩阵:3657 | >    but reading ` **[ppg_peak_valley_window_detector.v:111,351,354,465]** ` directly | （保留原文） |  |
| 矩阵:3668 | >    ` **[ppg_system_config_manager.v:457]** `'s | （保留原文） |  |
| 矩阵:3891 | > 可达"(` **[ppg_adc_s1_programmable_calibrator.v:232-233]** `的`flag_saturation_low`/ | （保留原文） |  |

### 第一轮转换改写（4条，列出4条）

| 文件:基线行 | 原文 | 新文本 | 理由 |
|---|---|---|---|
| 矩阵:1365 | 54`~~ **当前`:267`** / input / `i_test_identity_inject_sample_index` / ` **[ppg_control_top.v:130]** ` `input [C_SAMPLE_INDEX_ | `ppg_control_top.v` `i_test_identity_inject_sample_index` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵:1467 | 207`<br>~~`:207`~~ **当前`:209`** / input / `i_source_test_mux_ctrl` / ` **[ppg_control_top.v:108]** ` `input [4:0] i_source_t | `ppg_control_top.v` `i_source_test_mux_ctrl` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵:1509 | ON_CONTRACT.md:211`（§4.1“ADC物理接口”组行） / input / `i_dout_stage2_low` / ` **[ppg_control_top.v:119]** ` `input [9:0] i_dout_sta | `ppg_control_top.v` `i_dout_stage2_low` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵:1571 | rol_top.v:68`（V1.5，2026-09-05）与P2S集成合同§8.4.5 / output / `o_s2_raw` / ` **[ppg_control_top.v:292]** ` `output [9:0] o_s2_raw` | `ppg_control_top.v` `o_s2_raw` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
