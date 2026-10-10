# 锚点第五轮：被明示取代的旧锚点（统筹2026-10-10对`67707b3`的核对意见第二部分）

依据：`verification_reports/coord_review_20261010/B_MERGE_BATCH_REVIEW_ROUND4_20261010.md`（main `3867083`，未合入本分支）。快照`c6ce496`；写入、复核、对照见本目录。

## 一、统筹点名的两行

| 基线行 | 原文 | 第四轮（67707b3） | 现文 |
|---:|---|---|---|
| 1577 | `Anchor corrected from stale `:234` (unrelated …)` | `ppg_system_config_manager.v` `flag_stop_accept` | 恢复原文，history-superseded |
| 1585 | `Anchor corrected from stale `:245` (unrelated …)` | `ppg_system_config_manager.v` `i_static_characterization_enable` | 恢复原文，history-superseded |

两行与基线1596行`:247`、别名表192行（“**不是**`…:285`”）、2182行`:1359-1377`（被否定的换算范围）同属“被明示取代的旧条目”，现统一归入history-superseded（2026-10-09裁定③，无删除线一类），由同一条规则识别；后三处原为第四轮的人工history，本轮改归同一类，文本不变。

## 二、扫描规则与结果

扫描对象：基线`7a8eabf`矩阵与别名表中的全部9702个锚点（对照表每一行，不论现分类），看锚点前后的基线原文。

**规则A（判定规则，`anchor_history_rules.superseded_wording`，自测27例）**：锚点本身被格内措辞指为旧的/作废的/错误的引用——
- 紧挨在前：`stale`、`corrected from`、`旧锚点`、`旧引用`、`旧文字把…`、`旧范围…得`、`原写`、`原先`、`曾指`、`原引用`、`矩阵标`、`**不是**`、`原格实为`（大小写不敏感）；
- 紧跟在后：`(unrelated …`、`,实际\`:N\``（矩阵标N、实际M）、`顺序有误`；
- 旧→新行号对的旧侧：`` `:A`-`:B`→`:C`-`:D` ``（`→`两侧均为裸行号；“`a.v:N` → `b.v:M`”这类信号链不算）。

命中21处，全部判定属本类：

| 位置（基线行） | 旧锚点 | 措辞 | 原分类/原转换 | 现分类 |
|---|---|---|---|---|
| 矩阵:1497 | `:632` | 旧文字把C01 | §6.2.1 | history-superseded |
| 矩阵:1577 | `:234` | stale | `ppg_system_config_manager.v` `flag_stop_accept` | history-superseded |
| 矩阵:1585 | `:245` | stale | `ppg_system_config_manager.v` `i_static_characterization_enable` | history-superseded |
| 矩阵:1596 | `:247` | stale | history | history-superseded |
| 矩阵:2147 | `:2306` | 矩阵标 | `ppg_idac_code_controller.v` `o_idac_idle` | history-superseded |
| 矩阵:2147 | `:2427` | 矩阵标 | `ppg_idac_code_controller.v` `o_idac_idle` | history-superseded |
| 矩阵:2182 | `:1359-1377` | 旧范围若按+15换算得 | history | history-superseded |
| 矩阵:2860 | `:1972` | 矩阵标 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:1983` | 矩阵标 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:2005` | -`:2025`→`:2 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:2025` | →`:2 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:2071` | -`:2090`及`:2092`→`:2 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:2090` | 及`:2092`→`:2 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:2092` | →`:2 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:2359` | -`:2374`→`:2 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:2374` | →`:2 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:1336` | →`:1 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:912` | →`:9 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:2005,2092` | "顺序有误 | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 矩阵:2860 | `:2092,2005` | 原格实为" | `ppg_normal_transaction_fork.v` `o_local_empty` | history-superseded |
| 别名表:192 | ppg_idac_code_controller.v:285 | **不是**` | history | history-superseded |

另有6处同类但措辞不规则、规则未覆盖，人工归入（均在2147、2860两行的行号审计注记中）：

- 矩阵:2147 ``:2306``：被明示取代的旧锚点）：“行号引用（形如"`:2306`"至"`:2427`"）统一比实际行号少15”：旧行号示例，本格明示错误
- 矩阵:2147 ``:2427``：被明示取代的旧锚点）：同上，旧行号示例`:2427`
- 矩阵:2860 ``:1972``：被明示取代的旧锚点）：“如`i_clk`标`:1972`”：矩阵原标的旧行号（统一少15），本格明示错误
- 矩阵:2860 ``:2005``：被明示取代的旧锚点）：“`i_measurement_ready`所引的`:2005`等…统一比实际行号少15”：旧行号，本格明示错误
- 矩阵:2860 ``:912``：被明示取代的旧锚点）：“`:912`实际只差+7”：指旧行号`:912`本身（实为`:919`），明示取代
- 矩阵:2860 ``:1336``：被明示取代的旧锚点）：“…连接锚点及`:1336`处”：指旧行号`:1336`（实为`:1351`），明示取代

**规则B（宽扫描，用于查漏）**：锚点前40字内（取最近一处、距锚点≤25字）出现`stale`、`corrected from`、`previously`、`formerly`、`replaced`、`superseded`、`obsolete`、`wrong`、`old anchor/line`、`instead of`、`旧锚点/旧引用/旧文字/旧范围/旧行号`、`作废`、`原写/原先/原为/原指/原引用/曾指`、`已漂移`、`不是/并非`、`原假设`、`误引/误指`等，或锚点后紧跟`(unrelated`/`(无关`/`(stale`。命中19处，逐条判定：

| 位置（基线行） | 旧锚点 | 命中词 | 判定 |
|---|---|---|---|
| 矩阵:1497 | `:632` | 旧文字 | 属本类，已归history-superseded |
| 矩阵:1577 | `:234` | stale | 属本类，已归history-superseded |
| 矩阵:1585 | `:245` | stale | 属本类，已归history-superseded |
| 矩阵:1596 | `:247` | stale | 属本类，已归history-superseded |
| 矩阵:2182 | `:1359-1377` | 旧范围 | 属本类，已归history-superseded |
| 矩阵:2843 | `:919` | 不是 | 不属本类：“偏移为+7（不是+15），现为`:919`”：“不是”修饰偏移量，`:919`是核实后的现行行号，不属本类 |
| 矩阵:2860 | `:912` | 并非 | 属本类，已归history-superseded |
| 矩阵:3265 | C01:6 | wrong | 不属本类：“wrong-hierarchy port path”是本行描述的缺陷类别，其后的合同节号是现行引用 |
| 矩阵:3268 | C10:2 | stale | 不属本类：“stale dependency”是本行描述的缺陷类别，其后的合同节号是现行引用 |
| 矩阵:3268 | C18:2-2 | stale | 不属本类：同上 |
| 别名表:33 | PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md:943 | 原假设 | 不属本类：“原假设已被…纠正”说的是前一格的fir文件，本锚点在另一格（合同列），是现行引用 |
| 别名表:38 | ppg_control_top.v:945 | 原假设 | 不属本类：“原假设已被纠正”说的是idac_code_controller，本锚点是纠正后的现行证据（第四轮已改为o_startup_idac_safe_boundary） |
| 别名表:116 | ppg_dual_precision_top.v:338 | 不是 | 不属本类：“不是数据总线”与本锚点无关（描述同步链）；且为dual_precision锚点，本批不改 |
| 别名表:173 | PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:662,664 | 不是 | 不属本类：已在删除线内，原即历史（history-strike） |
| 别名表:176 | PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:664 | 不是 | 不属本类：“不是单一RTL机制的直接结果”与本锚点（另一格的合同引用）无关 |
| 别名表:192 | ppg_idac_code_controller.v:285 | 不是 | 属本类，已归history-superseded |
| 别名表:201 | `:696` | 旧锚点 | 不属本类：“作废旧锚点”描述的是RTL行为（重检失败置0作废旧基线锚点），不是文档锚点 |
| 别名表:212 | ppg_idac_code_controller.v:498 | 不是 | 不属本类：“不是合同要求的主动故障注入场景”与本锚点（另一格）无关 |
| 别名表:303 | `:10` | 不是 | 不属本类：“不是矩阵文字真的过期”与本锚点无关 |

## 三、同行顺带改正：2147、2860两行审计注记中已核实的行号

这两行（C17、C16端口台账末行）是2026-09-28/30对AMI行号的审计注记。注记里的旧行号已按上面归为历史；注记里写明“实际”“→”右侧的核实行号此前被解析器误归本行第一个文件（IDAC控制器/fork），又按名字取了本行端口（`o_idac_idle`/`o_local_empty`），与所指内容无关。已按写入时版本（`b1de2e0`、`d18c695`）的AMI逐个核对后改正：

| 位置（基线行） | 旧锚点 | 第四轮 | 现文 | 依据 |
|---|---|---|---|---|
| 矩阵:2147 | ppg_idac_code_controller.v:67-207 | `ppg_idac_code_controller.v` `o_idac_idle` | `ppg_idac_code_controller.v` `ppg_idac_code_controller` | “`ppg_idac_code_controller.v:67-207`声明区”：所指为模块端口声明区，取模块名（原解析取本行端口o_idac_idle） |
| 矩阵:2147 | `:602-682` | `ppg_idac_code_controller.v` `o_idac_idle` | `ppg_idac_code_controller.v` `"输出信号连线"` | “模块自身文件内引用（声明行+实现行，如`:602-682`）”：b1de2e0版602-682行为“输出信号连线”段，改为该段标题注释原文锚点（原解析取本行端口o_idac_idle） |
| 矩阵:2147 | `:2321` | `ppg_idac_code_controller.v` `o_idac_idle` | `ppg_adc_measurement_idac_integration.v` `ppg_idac_code_controller_Inst`、`i_clk` | “`i_clk`矩阵标`:2306`，实际`:2321`”：b1de2e0版AMI为IDAC控制器例化的`.i_clk(i_clk)` |
| 矩阵:2147 | `:2442` | `ppg_idac_code_controller.v` `o_idac_idle` | `ppg_adc_measurement_idac_integration.v` `ppg_idac_code_controller_Inst`、`o_idac_idle` | “本行`o_idac_idle`…实际`:2442`”：AMI中IDAC控制器例化的`.o_idac_idle(`连接 |
| 矩阵:2860 | ppg_normal_transaction_fork.v:61-146 | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_normal_transaction_fork.v` `ppg_normal_transaction_fork` | “与`ppg_normal_transaction_fork.v:61-146`独立核对的端口声明”：所指为模块端口声明区，取模块名（原解析取本行端口o_local_empty） |
| 矩阵:2860 | `:61-146` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_normal_transaction_fork.v` `ppg_normal_transaction_fork` | “本子模块自身文件声明行引用（`:61-146`）”：同上 |
| 矩阵:2860 | `:1987` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_normal_transaction_fork_Inst`、`i_clk` | “`i_clk`…实际`:1987`”：d18c695版AMI 1987行为fork例化的`.i_clk(i_clk)` |
| 矩阵:2860 | `:1998` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_normal_transaction_fork_Inst`、`i_datapath_discard_run_generation` | “`i_datapath_discard_run_generation`…实际`:1998`”：d18c695版AMI 1998行为fork例化的该端口连接 |
| 矩阵:2860 | `:2020` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_normal_transaction_fork_Inst` | “fork自身连接点21个（…→`:2020`-`:2040`）”：d18c695版AMI 2020~2040行为fork例化的端口连接 |
| 矩阵:2860 | `:2040` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_normal_transaction_fork_Inst` | 同上（区间终点`:2040`） |
| 矩阵:2860 | `:2086` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_pipeline_overlap_corrector_Inst` | “overlap_corrector例化连接点21个（…→`:2086`-`:2105`及`:2107`）”：d18c695版AMI为该例化的端口连接 |
| 矩阵:2860 | `:2105` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_pipeline_overlap_corrector_Inst` | 同上（`:2105`） |
| 矩阵:2860 | `:2107` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_pipeline_overlap_corrector_Inst` | 同上（`:2107`） |
| 矩阵:2860 | `:2074` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_pipeline_overlap_corrector_Inst` | “逐端口名对照AMI内该例化`:2074`-`:2135`”：d18c695版AMI 2074行为`)ppg_adc_pipeline_overlap_corrector_Inst(` |
| 矩阵:2860 | `:2135` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_pipeline_overlap_corrector_Inst` | 同上（例化块终点`:2135`） |
| 矩阵:2860 | `:2374` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_idac_code_controller_Inst` | “IDAC控制器例化连接点16个（…→`:2374`-`:2389`）”：d18c695版AMI为该例化的端口连接 |
| 矩阵:2860 | `:2389` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `ppg_idac_code_controller_Inst` | 同上（`:2389`） |
| 矩阵:2860 | `:1351` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `measurement_result_discard_run_generation_o` | “AMI内部信号（`:1336`→`:1351`）”：d18c695版AMI 1351行为measurement_result_discard_run_generation_o寄存器赋值 |
| 矩阵:2860 | `:919` | `ppg_normal_transaction_fork.v` `o_local_empty` | `ppg_adc_measurement_idac_integration.v` `flag_normal_track_qualified` | “`:912`→`:919`”：d18c695版AMI 919行为`assign flag_normal_track_qualified`（同2843行所述） |

## 四、新发现，待统筹决定：按名解析（resolved-by-name）的锚点有一批落错文件

核对2860行时发现：解析器对一部分锚点（状态`resolved-by-name`，共1072个）不是按所引行的内容取符号，而是在本行写明的名字里找一个“在所指文件中存在”的名字。裸`:N`的文件又可能误归本行第一个文件，于是得到一个名字在本行出现、文件里也存在、但与所引行无关的符号；第三轮相关性检查、规则1d都拦不住（名字确实在本行出现）。
按写入时版本检查“所引行号是否落在该符号出现处附近”：剔除后续各轮已改写的，剩余未改写的857个按名解析锚点中，118个所引行号超出所指文件末行（文件必然错），144个距该符号最近出现处超过15行；合计262个，分布在210行。抽查（2139 `:2434`、2784 `:1955`、2778 `:1949`、1880、2463、别名表116）均确为错误（例：`:1955`是AMI行号，被归到188行的`ppg_adc_result_router.v`；2463的`:894`应是PWC例化，被取成了PVW例化名）。
本轮未改这一类（超出第二部分范围），全部清单见`resolved_by_name_audit.json`（每条含文件、基线行、旧锚点、现解析、写入时版本、所指文件行数、距离）。建议合并前再做一轮：按行内上下文重新确定文件（多为AMI），在写入时版本按行内容取符号，取不到的用钉住版本写法；并把“所引行号须在该符号附近”加进门禁。请统筹决定是否在合并前处理。
