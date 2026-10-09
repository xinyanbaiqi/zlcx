# PPG精度窗口检测链集成Wrapper接口与握手合同

> V2.2修订日期：2026-10-09。B合同合并批次（`verification_reports/B_MERGE_BATCH_ITEMS.md` BMI-071~074，按基线`7a8eabf` PWI RTL V1.5改写，符号锚点格式为“文件 + 符号（§节）”）：① §5.5端口表新增`i_calibration_request_withdraw_event`（F-020，原样转给重检调度器）；② §5子模块消费表订正`i_max_fine_window_frames`、`i_max_reacquire_frames`的直接消费者为峰谷检测器（F-043）；③ §14门禁范围订正为实际验收表PWI-01至PWI-08（S4）。文件头V1.3历史状态行与§15历史记录中的“PWI-06至PWI-10”属带日期的历史叙述，保持原样；表格实际上限为PWI-08。
> V2.1修订日期：2026-10-01。合同补记批次3：补入PWI RTL V1.4（2026-08-31，Stage5 Group15 PRC-09/10）新增、但本合同一直缺失的内容：参数`C_ENABLE_TEST_INJECTION`（`ppg_precision_window_integration.v:72`，默认0），以及3个纯透传端口`i_test_inject_enable`、`i_test_calibration_loss_inject_valid`、`o_test_calibration_loss_inject_ready`（`:249-251`）。第4节参数表新增一行，并新增第5.12节。口径与C10 V2.3第6.5b节（AMI侧）一致：PWI既不解释也不门控，只把参数和三个端口原样接到粗检测FIR例化（`:600`、`:650-652`），请求的接受和作用都在FIR内。不改变PWI-01至PWI-10的任何条款。合同同步记录见`verification_reports/CONTRACT_SYNC_BATCH3_20261001.md`。
> Current normative version: V2.0, 2026-08-20. Status: `ACTIVE_NORMATIVE`; this module consumes only the AMI-forwarded V5 named detection fields, `peak_valley_config_valid` safety gate and config_epoch. System closure is `NOT_CLOSED` until the matrix reverse-port audit records zero defects; RTL/TB evidence remains `EVIDENCE_PENDING`.
> Historical V1.9 change record (non-normative): it replaced stale dependencies and implementation-result assertions with the then-current parent/child contract set. Current V2.0 rules above are authoritative.

> Historical V1.2 interface record (non-normative): the independent sample-valid behavior has authority only as incorporated by V2.0; it is not a separate current contract version and its RTL/TB evidence is `EVIDENCE_PENDING`.
> Historical V1.2 freeze date: 2026-08-12; historical V1.2 revision date: 2026-08-20.
> Historical V1.2 revision: the `i_sample_valid` rule is incorporated by V2.0; invalid transactions consume only the upstream handshake and do not enter FIR, the detection fork, baseline, peak/valley or precision control. This record cannot create a separate V1.2 authority.
> V1.3 historical status note: PWI-01至PWI-05 are V1.1 history. The current PWI-06至PWI-10 interface is normative, but its system closure verdict is owned only by the current fail-closed matrix audit. RTL/TB evidence remains `EVIDENCE_PENDING`.  
> 目标RTL：`ppg_precision_window_integration.v`  
> 目标TB：`tb_ppg_precision_window_integration.v`  
> 时钟域：2 MHz数字处理域  
> 有效检测样本率：每个颜色400 Hz  
> FIR基线：20阶、21抽头、群延时10个同色有效样本  
> 验收范围：PWI-01至PWI-08

## 1. 合同目的

本文冻结精度窗口检测子系统的可综合集成边界、外部端口、内部模块连接、粗FIR双消费者事务分发、
9-bit/15-bit请求与真实提交事件、AMB周期重检安全接管以及PWI-01至PWI-05的跨模块验收行为。

本wrapper不是完整PPG数字顶层，也不拥有ADC转换、IDAC码搜索算法、DC恢复数学或片外数据输出。
它只集成以下五个具有独立活动合同的模块，并增加一个可综合的双输出保持型检测fork：

1. `ppg_coarse_detection_fir`；
2. `ppg_dynamic_baseline_cross_detector`；
3. `ppg_peak_valley_window_detector`；
4. `ppg_precision_window_controller`；
5. `ppg_amb_recheck_scheduler`；
6. wrapper内部`FIR detection fork`。

后续集成RTL、PWI自检TB和更上层数字顶层必须以本文为该子系统连接真源。不得在TB中使用常量占位、
强制内部寄存器或复制行为模型代替上述真实模块。

## 2. 规范来源与冲突优先级

本文基于以下当前活动合同：

1. C10 — `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.5；
2. C19 — `ppg_system_integration/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md` V2.6；
3. C20 — `ppg_system_integration/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md` V2.6；
4. C21 — `ppg_system_integration/PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md` V1.3；
5. C22 — `ppg_system_integration/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md` V2.6；
6. C23 — `ppg_system_integration/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md` V2.7；
7. C16 — `ppg_system_integration/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md` V2.2。

若旧集成草案、旧handoff或单模块合同中的集成文字与本文冲突，连接关系和跨模块握手以本文为准；
各模块内部数学仍以其最新独立合同为准。

### 2.1 PWI-05精确解释

旧精度控制合同中“旧动态基线状态全部废止”不得解释为成功重检时无条件清除可靠波峰锚点和活动斜率。
按照当前动态基线V2.5合同，实际重检接管必须清除：

- 在途相交候选、连续确认计数和相邻样本关系；
- 当前周期的精确相交资格、峰谷组合资格和自适应更新资格；
- 旧波谷证据和恢复临时状态；
- 可能跨越重检边界的未完成算术事务。

成功重检允许保留最近可靠波峰锚点与`o_slope_current_q16`，并按持续递增的真实`frame_id`计算恢复基线；
重检失败、异常返回重新获取或协议故障才使旧锚点失效并回到固定斜率重新获取。

### 2.2 已满足的实现前置接口

精度控制器已经提供：

```verilog
o_reacquire_request_event
```

wrapper固定连接到动态基线模块的：

```verilog
i_reacquire_request_event
```

动态基线的现行合同声明该输入；相关RTL/TB记录只能作为
`EVIDENCE_PENDING`，不能作为接口闭合或实现前置结论。集成时仍不得把
该事件接成常量，也不得使用START、STOP、abort或重检事件替代。

## 3. 集成结构

```text
DC恢复后的NORMAL粗结果
        |
        v
ppg_coarse_detection_fir
        |
        v
双输出保持型检测fork
        |------------------------------|
        v                              v
dynamic_baseline_cross_detector   peak_valley_window_detector
        | cross                      | peak / valley / return
        |                            |
        +---- precision controller <-+
                    |
                    +--> committed precision
                    +--> fine start / 15-to-9 / reacquire
                                      |
                                      v
                           amb_recheck_scheduler
                                      |
                          recheck accept / busy / done
                                      |
                  FIR、动态基线和峰谷检测器原子协同
```

红光拥有自动精度窗口控制权。红外FIR事务必须被两个检测分支正常消费，但不得建立cross、峰、谷或返回请求。

## 4. 参数合同

| 参数 | 默认值 | 语义 |
| --- | ---: | --- |
| `C_DATA_WIDTH` | 24 | signed统一粗PPG码位宽 |
| `C_FRAME_ID_WIDTH` | 16 | 400 Hz物理帧号位宽 |
| `C_SAMPLE_INDEX_WIDTH` | 16 | ADC事务全局序号位宽 |
| `C_IDAC_CODE_WIDTH` | 8 | AMB/DC码快照位宽 |
| `C_CODE_EPOCH_WIDTH` | 4 | IDAC码提交版本位宽 |
| `C_CONFIG_EPOCH_WIDTH` | 8 | V4/V5联合COMMIT版本，运行期稳定 |
| `C_COEF_EPOCH_WIDTH` | 8 | Stage1系数组版本位宽 |
| `C_DC_RECOVERY_EPOCH_WIDTH` | 8 | DC恢复系数版本位宽 |
| `C_RUN_GENERATION_WIDTH` | 8 | manager唯一生产、由AMI/PWI逐级透传的RUN代际位宽 |
| `C_SLOPE_WIDTH` | 32 | signed Q16基线斜率位宽 |
| `C_BASELINE_WIDTH` | 48 | signed Q16基线运算位宽 |
| `C_RATIO_WIDTH` | 16 | unsigned Q1.15比例位宽 |
| `C_CONFIRM_COUNT_WIDTH` | 4 | 峰谷与相交连续确认计数位宽 |
| `C_INTERVAL_WIDTH` | 16 | 峰谷帧间隔与超时位宽 |
| `C_FIR_GROUP_DELAY_SAMPLES` | 10 | 20阶FIR固定同色群延时 |
| `C_SWITCH_TIMEOUT_CYCLES` | 10000 | 2 MHz下精度安全提交最大等待周期 |
| `C_SWITCH_TIMEOUT_COUNTER_WIDTH` | 14 | 精度提交超时计数位宽 |
| `C_ENABLE_TEST_INJECTION` | 0 | 验证专用注入结构生成使能（V2.1补记）；由AMI逐层传入，PWI只原样传给粗检测FIR（`:600`），生产网表必须为0 |

所有子模块的同名参数必须由wrapper统一向下传递，不允许出现frame、epoch或群延时位宽不一致。

## 5. Wrapper外部端口合同

### 5.1 全局与生命周期

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_clk` | 1 | 2 MHz数字处理时钟 |
| input | `i_rstn` | 1 | 低有效异步复位，释放由上层同步 |
| input | `i_run_enable` | 1 | 当前生命周期处于RUN |
| input | `i_start_ack_event` | 1 | 新RUN正式开始单拍 |
| input | `i_diag_clear_event` | 1 | 软件清除sticky诊断单拍 |

这些输入并联到所有具有同名端口的子模块。STOP和abort不得直接清理任何检测子模块的运行态；
未消费检测状态只能由AMI产生的generation-scoped detection discard经PWI广播清理。普通精度
切换和仅有`recheck_pending`不得清理FIR历史或检测状态。

### 5.2 ACTIVE与运行配置

| 方向 | 端口 | 位宽/格式 | 使用者 |
| --- | --- | --- | --- |
| input | `i_active_config_valid` | 1 | 精度控制器 |
| input | `i_run_profile` | 1 | 精度控制器及峰谷检测器；0 NORMAL，1 CHARACTERIZATION |
| input | `i_initial_precision` | 1 | 精度控制器 |
| input | `i_normal_measurement_active` | 1 | 精度控制器及AMB调度器 |
| input | `i_slope_mode` | 1 | 动态基线；0固定，1自适应 |
| input | `i_fixed_slope_q16` | signed 32 | 动态基线固定负斜率 |
| input | `i_alpha_q15` | unsigned 16 | 动态基础斜率幅度比例 |
| input | `i_beta_q15` | unsigned 16 | 逐周期斜率平滑比例 |
| input | `i_timing_adjust_ratio_q15` | unsigned 16 | 相交时刻调整比例 |
| input | `i_slope_min_q16` | signed 32 | 最负斜率边界 |
| input | `i_slope_max_q16` | signed 32 | 最接近零斜率边界 |
| input | `i_baseline_delta_q16` | signed 32 | 波峰锚点处基线偏置 |
| input | `i_cross_hysteresis_q16` | unsigned 32 | 向上相交迟滞 |
| input | `i_lead_min_frames` | 16 | 相交提前量合格窗口下界 |
| input | `i_lead_max_frames` | 16 | 相交提前量合格窗口上界 |
| input | `i_cross_confirm_count` | 4 | 向上相交连续确认点数 |
| input | `i_no_cross_limit` | 4 | 连续无相交重新获取阈值 |
| input | `i_peak_confirm_count` | 4 | 波峰后连续下降确认数 |
| input | `i_valley_confirm_count` | 4 | 波谷后连续上升确认数 |
| input | `i_direction_deadband` | unsigned 24 | 相邻FIR方向死区 |
| input | `i_min_peak_valley_amplitude` | unsigned 24 | 合格峰谷最小幅度 |
| input | `i_min_peak_to_valley_frames` | 16 | 波峰到波谷最小帧差 |
| input | `i_min_peak_to_peak_frames` | 16 | 相邻波峰最小帧差 |
| input | `i_max_fine_window_frames` | 16 | 15-bit正式窗口最大持续帧数 |
| input | `i_max_reacquire_frames` | 16 | 9-bit单轮重新获取最大帧数 |
| input | `i_peak_valley_config_valid` | 1 | 峰谷配置正式有效资格 |
| input | `i_idac_mode` | 2 | AMB scheduler的IDAC工作模式 |
| input | `i_amb_enable` | 1 | 允许周期AMB检查 |
| input | `i_dcs_enable` | 1 | 允许固定DC_R/DC_IR重验证 |
| input | `i_amb_recheck_interval_frames` | 16 | 完整NORMAL帧重检间隔 |

wrapper必须把`i_run_profile`直接连接峰谷检测器的`i_characterization_mode`，不得引入第二个可不一致的
CHARACTERIZATION控制位。

V5字段的唯一producer为ACTIVE unpacker经AMI转发的注册/稳定2 MHz输出；PWI不读取
联合原始ACTIVE，也不产生默认配置。`i_config_epoch[C_CONFIG_EPOCH_WIDTH-1:0]`
与全部V5输入在同一合法联合COMMIT边界绑定，进入READY/RUN后稳定，且每笔检测事务
携带该epoch。PWI逐端连接如下：

| AMI/PWI输入 | 直接子模块消费者 | 资格/生命周期 |
| --- | --- | --- |
| `i_slope_mode`, `i_fixed_slope_q16`, `i_alpha_q15`, `i_beta_q15`, `i_timing_adjust_ratio_q15`, `i_slope_min_q16`, `i_slope_max_q16`, `i_baseline_delta_q16`, `i_cross_hysteresis_q16`, `i_lead_min_frames`, `i_lead_max_frames`, `i_cross_confirm_count`, `i_no_cross_limit` | FIR后动态baseline/cross | 逐位稳定；任何V5非法值不得到达此端口 |
| `i_peak_confirm_count`, `i_valley_confirm_count`, `i_direction_deadband`, `i_min_peak_valley_amplitude`, `i_min_peak_to_valley_frames`, `i_min_peak_to_peak_frames` | peak/valley detector | `peak_valley_config_valid=0`时只允许安全消费，不得发布正式事件 |
| `i_peak_valley_config_valid` | dynamic baseline/cross, peak/valley detector, precision controller | Single AMI-forwarded registered gate fanout. `0` prohibits formal cross, peak, valley, 9-to-15 request and fine-window control; detector children still consume/drain held transactions and do not publish those formal events or controls. |
| `i_max_fine_window_frames`, `i_max_reacquire_frames` | ~~precision controller~~ V2.2 (F-043, RTL): peak/valley detector (`ppg_precision_window_integration.v` instance `ppg_peak_valley_window_detector_Inst`); the precision controller has no such ports | The limits are stable configuration values; the separate valid gate prohibits formal fine-window control and 9-to-15 requests when low. |
| `i_config_epoch` | FIR、baseline/cross、peak/valley、precision controller | 与检测事务/`run_generation`绑定，禁止跨epoch混用 |

PWI内部仍只有AMI generation-scoped detection discard清理运行态；STOP、abort、fault
不得直连清除上述配置或检测pending。reset清状态但不产生discard event。

### 5.3 FIR上游NORMAL粗结果

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_normal_result_valid` | 1 | 上游保持型NORMAL粗结果valid |
| output | `o_normal_result_ready` | 1 | FIR允许唯一消费当前事务 |
| input | `i_coarse_ppg_value` | signed 24 | DC恢复后的统一粗PPG值 |
| input | `i_coarse_valid` | 1 | 当前事务具有粗结果 |
| input | `i_sample_valid` | 1 | 上游独立sample qualification；0事务可握手但不得进入FIR或后续算法 |
| input | `i_coarse_recovery_calibrated` | 1 | Stage1和DC9恢复均正式有效 |
| input | `i_stage1_saturation_low` | 1 | Stage1负向饱和诊断 |
| input | `i_stage1_saturation_high` | 1 | Stage1正向饱和诊断 |
| input | `i_coarse_saturation_low` | 1 | 粗恢复负向饱和诊断 |
| input | `i_coarse_saturation_high` | 1 | 粗恢复正向饱和诊断 |
| input | `i_config_epoch` | 8 | 当前事务ACTIVE版本 |
| input | `i_coef_epoch` | 8 | 当前事务Stage1系数版本 |
| input | `i_dc_recovery_coef_epoch` | 8 | 当前事务DC恢复版本 |
| input | `i_precision_mode` | 1 | 事务开始时快照的committed精度 |
| input | `i_frame_id` | 16 | 当前物理400 Hz帧号 |
| input | `i_sample_index` | 16 | 当前ADC事务全局序号 |
| input | `i_color_ir` | 1 | 0红光，1红外 |
| input | `i_frame_type` | 2 | 正式NORMAL固定为`2'b10` |
| input | `i_amb_code_snapshot` | 8 | 当前事务AMB committed码 |
| input | `i_dc_code_snapshot` | 8 | 当前颜色DC committed码 |
| input | `i_amb_code_epoch` | 4 | AMB码版本 |
| input | `i_dc_code_epoch` | 4 | 当前颜色DC码版本 |

`o_normal_result_ready`只由真实FIR输入ready返回。精度切换pending应阻止新的ADC事务启动，但不得组合撤销
已经产生并等待FIR接收的旧事务。

`i_sample_valid`必须逐位连接`ppg_coarse_detection_fir.i_sample_valid`，不得连接或改写内部检测fork ready。`i_normal_result_valid=1 && o_normal_result_ready=1 && i_sample_valid=0`仍是一次真实上游事务消费，但FIR按V2.1不产生输出，因此该事务不会建立fork pending，也不会到达动态基线、峰谷或精度控制器。wrapper不得把RAW数值、`i_coarse_valid`、`i_coarse_recovery_calibrated`或饱和诊断重新编码成该资格。

### 5.4 帧、模拟安全与排空输入

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_frame_safe_boundary` | 1 | 下一物理帧开始前安全边界单拍 |
| input | `i_safe_frame_id` | 16 | 即将启动帧的真实frame_id |
| input | `i_precision_takeover_safe` | 1 | AMI导出的复合精度切换资格：物理ADC/DONE已空闲，且ADC、capture和结果流水已排空；它不是物理idle事实。 |
| input | `i_analog_safe` | 1 | 模拟相位允许提交新精度 |
| input | `i_normal_fork_idle` | 1 | 上游NORMAL测量/跟踪fork排空 |
| input | `i_idac_idle` | 1 | IDAC控制器无pending或在途提交 |
| input | `i_startup_search_complete` | 1 | 启动AMB/DC搜索已经完成 |
| input | `i_normal_frame_complete_event` | 1 | 一帧完整NORMAL测量结束单拍 |
| input | `i_calibration_frame_complete_event` | 1 | 当前AMB或DCS校准帧结束单拍 |

同一个`i_frame_safe_boundary`同时送精度控制器和AMB scheduler；普通精度切换不等待FIR或检测器idle，
AMB重检接管则必须等待第9节冻结的完整安全条件。

### 5.5 IDAC序列协作端口

下列端口直接透传AMB scheduler与现有IDAC控制器之间的合同：

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_amb_sample_request` | 1 | IDAC请求下一笔AMB_CAL样本 |
| input | `i_amb_sequence_done` | 1 | AMB检查或搜索成功单拍 |
| input | `i_amb_sequence_failed` | 1 | AMB搜索失败单拍 |
| input | `i_dcs_revalidate_request` | 1 | IDAC请求固定DC_R/DC_IR重验证 |
| input | `i_dcs_sample_request` | 1 | IDAC请求当前DCS_CAL样本 |
| input | `i_dcs_sample_color_ir` | 1 | 0 DC_R，1 DC_IR |
| input | `i_dcs_revalidate_done` | 1 | 两色DC重验证成功单拍 |
| input | `i_dcs_revalidate_failed` | 1 | 任一路DC失败单拍 |
| input | `i_amb_sample_accepted_event` | 1 | 匹配AMB_CAL结果已消费 |
| input | `i_dcs_sample_accepted_event` | 1 | 匹配DCS_CAL结果已消费 |
| input | `i_calibration_request_withdraw_event` | 1 | V2.2补记（F-020）。AMI转送的周期重检外层在途校准请求撤销单拍（来源为调度器校准owner截止或校准owner完成丢失超时作废）；PWI原样转给重检调度器，由其释放内层在途状态（C16 §9.3、§9.4） |
| output | `o_amb_sequence_start` | 1 | 安全接管后启动AMB检查单拍 |
| output | `o_dcs_revalidate_accept` | 1 | AMB帧后接受DC_R/DC_IR重验证单拍 |

### 5.6 校准采样调度端口

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_calibration_sample_ready` | 1 | 模拟调度器可接受SAR9校准请求 |
| output | `o_calibration_sample_valid` | 1 | 保持型AMB_CAL或DCS_CAL请求 |
| output | `o_calibration_frame_type` | 2 | `00` AMB_CAL，`01` DCS_CAL |
| output | `o_calibration_color_ir` | 1 | DCS_CAL颜色选择 |
| output | `o_calibration_precision_mode` | 1 | 固定为0，周期重检只使用SAR9 |
| output | `o_calibration_frame_start` | 1 | 三个校准帧各自开始单拍 |
| output | `o_calibration_stage` | 2 | 00 idle，01 AMB，10 DC_R，11 DC_IR |

### 5.7 精度控制输出

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| output | `o_active_precision_mode` | 1 | 唯一committed采集精度 |
| output | `o_fine_window_active` | 1 | 正式PPG 15-bit窗口状态 |
| output | `o_fine_window_start_event` | 1 | 真实进入15-bit的提交单拍 |
| output | `o_fine_window_start_frame_id` | 16 | 第一笔真实15-bit帧号 |
| output | `o_precision_15_to_9_event` | 1 | 真实返回9-bit提交单拍 |
| output | `o_precision_15_to_9_frame_id` | 16 | 第一笔恢复9-bit帧号 |
| output | `o_reacquire_request_event` | 1 | 异常返回后废止旧锚点并重新获取单拍 |
| output | `o_switch_hold_new_transaction` | 1 | 2 MHz注册安全门控；唯一消费者为AMI内部事务启动资格，AMI可将同一注册值输出给Scheduler观察，不得由Top重建。 |
| output | `o_mode_fault_event` | 1 | 精度控制阻断故障的注册单拍；唯一消费者为AMI内部precision fault record形成器。 |
| output | `o_mode_fault_active` | 1 | 精度控制当前代际阻断故障注册保持电平；唯一消费者为AMI内部启动门控和fault-active保持。 |
| output | `o_mode_fault_identity_valid/<FAULT_ID>` | 1/各字段宽度 | 与`o_mode_fault_event`原子稳定的故障身份；无效时所有身份字段为0；唯一消费者为AMI内部fault record形成器。 |

`o_active_precision_mode`的唯一层次路径是
`precision controller -> PWI -> AMI -> Top -> Scheduler/SSW`：AMI把同一
已提交值作为下一ADC事务的`i_precision_mode`快照来源，Top再将AMI输出
连接至Scheduler `i_active_precision_mode`及SSW `i_precision_mode_committed`。
PWI不得直接驱动Scheduler、SSW、capture、S1或Top，且不得生成第二套活动
精度寄存器。

### 5.8 AMB重检输出

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| output | `o_normal_frame_count` | 16 | 当前周期累计的完整NORMAL帧数 |
| output | `o_amb_recheck_pending` | 1 | 间隔到期并等待下一次15-to-9事件 |
| output | `o_amb_recheck_accept` | 1 | 安全接管实际发生单拍 |
| output | `o_amb_recheck_busy` | 1 | 三帧校准序列占用状态 |
| output | `o_normal_output_inhibit` | 1 | 重检接管后禁止新的NORMAL正式结果资格；2 MHz注册，复位为0，唯一消费者AMI内部正式结果资格，不释放既有owner或fork。 |
| output | `o_recheck_sequence_done` | 1 | 三阶段整体成功单拍 |
| output | `o_recheck_sequence_failed` | 1 | 任一阶段失败单拍 |

### 5.9 状态、可观测性与诊断输出

为保证PWI测试来自真实比较，wrapper冻结以下可综合只读输出：

| 输出 | 位宽 | 语义 |
| --- | ---: | --- |
| `o_fir_history_full_r` | 1 | 红光21点历史已满 |
| `o_fir_history_full_ir` | 1 | 红外21点历史已满 |
| `o_fir_idle` | 1 | FIR MAC和其输出缓冲排空，不包含wrapper fork |
| `o_detection_fork_idle` | 1 | 两个检测分支均无事务所有权 |
| `o_detector_idle` | 1 | 峰谷真实事务及入口尾部排空 |
| `o_controller_idle` | 1 | 精度控制事务排空 |
| `o_scheduler_idle` | 1 | AMB scheduler无pending或在途样本 |
| `o_cross_pending` | 1 | 动态基线存在未消费cross请求 |
| `o_peak_pending` | 1 | 峰谷检测器存在未消费peak事件 |
| `o_valley_pending` | 1 | 峰谷检测器存在未消费valley事件 |
| `o_return_pending` | 1 | 峰谷检测器存在未消费返回请求 |
| `o_baseline_valid` | 1 | 当前动态基线锚点有效 |
| `o_reacquire_active` | 1 | 动态基线要求9-bit重新获取 |
| `o_detector_fine_window_active` | 1 | 峰谷检测器观察到的正式fine状态 |
| `o_switch_pending` | 1 | 精度请求等待安全提交 |
| `o_switch_target_precision` | 1 | pending目标精度 |
| `o_slope_current_q16` | signed 32 | 当前周期活动斜率 |
| `o_baseline_protocol_error_sticky` | 1 | 动态基线协议诊断 |
| `o_fine_window_timeout_sticky` | 1 | 峰谷fine窗口超时历史 |
| `o_reacquire_timeout_sticky` | 1 | 峰谷重新获取超时历史 |
| `o_peak_valley_protocol_error_sticky` | 1 | 峰谷协议诊断 |
| `o_switch_timeout_sticky` | 1 | 精度提交超时历史 |
| `o_precision_protocol_error_sticky` | 1 | 精度控制协议诊断 |

这些端口只用于系统状态寄存器、集成验证和诊断，不得反向驱动检测决策。

### 5.10 Detection-discard, generation and empty ports

PWI receives the registered 2 MHz AMI group
`i_detection_discard_event`, `i_detection_discard_reason[1:0]`,
`i_detection_discard_identity_valid`, the full trigger `TXN_ID` and
`i_run_generation[C_RUN_GENERATION_WIDTH-1:0]`. There is no
`discard_ready` or acknowledgement. When the event is sampled, PWI
unconditionally broadcasts the same registered event, reason, identity-valid and complete trigger ID
to FIR, baseline/cross, peak/valley and precision-window controller. Every
downstream port is named `i_detection_discard_event`,
`i_detection_discard_reason[1:0]`, individual ID fields and
`i_run_generation`; every downstream empty return is named `o_local_empty`.
There is no direct STOP/abort destructive-clear path to these children. This
event is a `run_generation`-scoped flush: each owner clears every pending and
run-scoped algorithm state that belongs to the event generation at that edge,
then may report local empty no earlier than the next cycle. `identity_valid=0`
is a legal scope-only flush and requires every trigger field except target
`run_generation`, plus sample-valid, to be zero. No cross, peak, valley, precision transition or algorithm result
may be emitted for the discarded generation.

`i_precision_takeover_safe` is a registered AMI-to-PWI level and is forwarded
unchanged only to the precision-window controller's same-named input. It is
the composite precision-switch safety predicate, not a second physical-idle
source; PWI neither synchronizes nor recomputes it.

`o_detection_datapath_empty` is registered high only after PWI's fork, FIR,
baseline/cross, peak/valley, precision controller and discard-broadcast state
are empty. PWI samples each `o_local_empty` on the next 2 MHz edge after the
broadcast; it cannot report empty in the discard edge. AMI is its sole consumer
for full `o_datapath_empty` aggregation. PWI does not use or recreate physical
ADC idle. Any retained transaction carries the complete ID including run
generation; a stale generation is discarded without an output or algorithmic
state transition.

`i_sample_valid=0` remains an accepted, identity-observable NORMAL transaction
but does not advance FIR history/count/full/MAC, baseline evidence, cross,
peak/valley or precision control. It is independent of RAW, saturation,
calibration qualification and result-valid.

### 5.11 Fault promotion and safety-gate ownership

PWI's precision-controller child and AMI's separate IDAC-controller child do
not bypass AMI or the system supervisor. The exact registered paths are:

```text
ppg_precision_window_controller.o_mode_fault_event/active/identity_valid/<FAULT_ID>
    -> PWI private flag_precision_controller_fault_*
    -> PWI.o_mode_fault_event/active/identity_valid/<FAULT_ID>
    -> AMI private flag_precision_fault_*
    -> AMI.o_ami_fault_valid/active/cause/identity_valid/<FAULT_ID>, cause=8'h04

ppg_idac_code_controller.o_controller_fault_event/blocking/identity_valid/<FAULT_ID>
    -> AMI private flag_idac_fault_*
    -> AMI.o_ami_fault_valid/active/cause/identity_valid/<FAULT_ID>, cause=8'h05
```

`flag_precision_controller_fault_*`, `flag_precision_fault_*` and
`flag_idac_fault_*` are named 2 MHz registered internal nets, not implied
signals or Top ports. The precision-controller child is the sole producer of
the first group, PWI is the sole producer of the second group, and the IDAC
child is the sole producer of the third group. PWI and AMI are respectively
their sole consumers. Every group resets low; an invalid identity drives every
identity field to zero. No PWI signal is a consumer or producer of an IDAC
fault record.

AMI is the sole exporter of both records as
`o_ami_fault_valid/active/cause/identity_valid/<FAULT_ID>`. Cause `8'h04` is the
precision switch timeout and cause `8'h05` is the IDAC blocking fault; both use
source `4'h1` and retain the current transaction identity when valid, otherwise
all identity fields are zero. The record then follows the only system path:

```text
AMI fault record -> registered supervisor
 -> o_system_abort_event/o_system_stop_request_event/o_system_fault_discard_event
 -> Top -> ACTIVE wrapper -> manager STOPPING
```

`o_switch_hold_new_transaction` and `o_normal_output_inhibit` are separately
declared 1-bit PWI outputs and connect only to AMI's registered private
`flag_precision_switch_hold` and `flag_normal_output_inhibit` inputs. Both
reset low, block only new work, and cannot release an accepted owner, fork,
pending request or fault hold. AMI alone may re-export
`o_switch_hold_new_transaction` to the Scheduler through Top. AMI does not
export `o_normal_output_inhibit`: it remains the private formal-result gate.
Top may not directly connect a PWI child output, recreate either safety gate,
or consume a precision-controller output.

### 5.12 验证专用calibration-loss注入透传端口（V2.1补记）

| 端口 | 位宽 | 方向 | 语义 |
| --- | ---: | --- | --- |
| `i_test_inject_enable` | 1 | input | AMI逐层传入的验证注入使能（AMI侧为`(C_ENABLE_TEST_INJECTION != 0) && i_test_inject_enable`，见C10第6.5b节）；PWI原样接到FIR（`:650`），自身不使用 |
| `i_test_calibration_loss_inject_valid` | 1 | input | 保持型一次性calibration-loss注入请求valid，原样接到FIR（`:651`） |
| `o_test_calibration_loss_inject_ready` | 1 | output | 原样取自FIR的同名ready（`:652`） |

PWI对这组端口只做透传：全文件grep只有声明（`:249-251`）和FIR例化连接（`:650-652`）两处，wrapper内没有其它使用，不参与第6节FIR双消费者fork、第9节AMB安全接管或任何本地状态。请求的接受、作用和撤销全部在粗检测FIR内实现（`ppg_coarse_detection_fir.v:312-315`、`:465-477`），以FIR合同C19和C10第6.5b节为准：ready为`(C_ENABLE_TEST_INJECTION != 0) && i_test_inject_enable && i_rstn && !flag_test_calibration_loss_armed`；握手后绑定到下一笔被FIR接纳的样本，并把该样本的粗路径校准资格强制视为0。`C_ENABLE_TEST_INJECTION=0`时ready恒为0，valid被忽略。

## 6. FIR双消费者保持型Fork

### 6.1 必要性

FIR只有一个保持型输出事务，而动态基线与峰谷检测器必须各消费一次同一笔完整中心样本。不得使用：

```text
fir_ready = baseline_ready && peak_valley_ready
```

并把同一个`valid`直接并联给两个模块。该接法会在一个分支先ready时造成重复消费或分支丢失。

### 6.2 所有权模型

wrapper内部保存：

```text
fork_payload
baseline_pending
peak_valley_pending
```

`fork_payload`至少原子保存两个下游共同使用的全部字段：

```text
filtered_ppg_value
detection_qualified
window_saturation_low/high
fir_saturation_low/high
config_epoch
coef_epoch
dc_recovery_coef_epoch
precision_mode
frame_id
sample_index
color_ir
frame_type
```

### 6.3 握手规则

```text
baseline_transfer    = baseline_pending    && baseline_result_ready
peak_valley_transfer = peak_valley_pending && peak_valley_result_ready

all_current_released = (!baseline_pending    || baseline_result_ready)
                    && (!peak_valley_pending || peak_valley_result_ready)

fork_input_ready = fork_empty || all_current_released
fir_output_transfer = fir_result_valid && fork_input_ready
```

每次`fir_output_transfer`必须原子锁存载荷，并把两个pending同时置1。每个分支的pending只在本分支完成唯一
握手后清零。允许旧事务两个分支在同一沿释放并在该沿锁存下一笔事务，实现单元素零气泡替换。

当任一分支反压时，另一分支即使已经消费也不得导致FIR载荷被第二次送给它。payload必须保持到两个pending
均释放。

### 6.4 Fork idle

```text
fork_idle = !baseline_pending && !peak_valley_pending
```

AMB scheduler看到的FIR安全排空条件必须是：

```text
fir_idle_to_scheduler = fir_o_fir_idle && fork_idle
```

不得只连接FIR自身`o_fir_idle`，否则FIR输出已经被fork接收但尚未被两个检测器完全消费时可能错误接管重检。

## 7. 精度窗口闭环连接表

| 源 | 目的 | 固定连接 |
| --- | --- | --- |
| AMI `precision_takeover_safe` | PWI `i_precision_takeover_safe` | AMI注册复合精度切换资格逐位连接；它不是物理idle，PWI不得重算或重同步 |
| PWI `i_precision_takeover_safe` | 精度控制器同名输入 | 层级原样转发；控制器只把它作为精度切换的安全资格 |
| 动态基线cross接口 | 精度控制器cross接口 | valid、ready及完整cross元数据逐位连接 |
| 精度控制器`o_fine_window_active` | 动态基线`i_fine_window_active` | 禁止15-bit真实窗口内建立新cross |
| 精度控制器fine start | 峰谷检测器fine start | event与第一笔15-bit frame_id原子连接 |
| 精度控制器`o_active_precision_mode` | 峰谷检测器`i_active_precision_mode` | 当前真实committed精度 |
| 峰谷检测器return接口 | 精度控制器return接口 | valid、ready、reason及frame_id连接 |
| 峰谷检测器peak接口 | 动态基线peak接口 | 保持型事件和全部epoch连接 |
| 峰谷检测器valley接口 | 动态基线valley接口 | 保持型事件和全部epoch连接 |
| 动态基线`o_reacquire_active` | 峰谷检测器`i_reacquire_active` | 9-bit重新获取状态 |
| 精度控制器`o_reacquire_request_event` | 动态基线新增输入 | 异常返回后废止旧锚点 |
| 精度控制器15-to-9事件 | AMB scheduler | 只有真实NORMAL返回事件可触发pending接管 |

请求握手与真实提交必须严格区分：cross/return握手只建立pending；只有后续安全边界提交才改变
`o_active_precision_mode`并产生fine start或15-to-9事件。

## 8. 重检事件连接

```text
recheck_accept_event = scheduler.o_amb_recheck_accept
recheck_busy         = scheduler.o_amb_recheck_busy
recheck_done_event   = scheduler.o_sequence_done
                     || scheduler.o_sequence_failed
recheck_success      = scheduler.o_sequence_done
```

上述四个信号并联到FIR、动态基线和峰谷检测器的对应端口；FIR只使用accept和busy。

`recheck_pending`不得连接任何模块的accept或clear端口。只有真实
`recheck_accept_event`允许清除对应代际的运行态或临时状态；历史sticky只能由
全局`i_diag_clear_event`或复位清除。

## 9. AMB安全接管条件

wrapper送入scheduler的安全条件冻结为：

```text
i_precision_takeover_safe
&& i_normal_fork_idle
&& i_idac_idle
&& (fir_o_fir_idle && fork_idle)
&& peak_valley_o_detector_idle
&& i_frame_safe_boundary
```

被动15-bit退出尾部不单独拉低`peak_valley_o_detector_idle`；入口尾部、未消费peak、valley、return、
恢复返回状态及生命周期清理仍必须拉低该idle。

按正常闭环，scheduler只在真实15-to-9事件后等待接管。此前cross已经由控制器消费；动态基线在fine窗口及
旧15-bit退出尾部均不能产生新cross；动态斜率算术期间peak事件仍由峰谷检测器保持。因此上述冻结条件能够
覆盖动态基线真实事务所有权。PWI TB还必须断言`recheck_accept_event`发生时`o_cross_pending==0`。

## 10. 精度与FIR历史尾部责任

### 10.1 进入15-bit

真实进入15-bit提交沿：

- 控制器立即置活动精度和fine窗口状态；
- 峰谷检测器接收唯一fine start事件和第一笔真实15-bit frame_id；
- FIR不清历史，随后最多输出10笔中心精度仍为9-bit的同色旧样本；
- 旧9-bit中心样本可维护粗趋势，但不得组成正式15-bit峰谷对；
- 第11笔仍为旧9-bit中心样本属于峰谷协议错误。

控制器不得统计或等待这10笔尾部。

### 10.2 返回9-bit

真实返回9-bit提交沿：

- 控制器立即清除正式fine窗口并输出15-to-9事件；
- FIR不清历史，随后最多输出10笔中心精度仍为15-bit的同色旧样本；
- 峰谷检测器管理被动退出尾部；
- 动态基线可以消费这些样本维持时间前进，但必须切断相交候选、相邻样本证据和连续确认；
- 第一笔恢复9-bit中心样本只重新建立9-bit相邻上下文，不能与旧15-bit样本拼接产生cross。

## 11. 生命周期与清理

| 事件 | FIR | Fork | 动态基线 | 峰谷检测器 | 精度控制器 | Scheduler |
| --- | --- | --- | --- | --- | --- | --- |
| `i_rstn=0` | 清历史/MAC/输出 | 清pending/payload | 清全部状态 | 清全部状态 | 安全初值 | 清pending/序列 |
| START | 清历史并预热 | 清事务 | 装固定斜率并重新获取 | 进入9-bit重新获取 | NORMAL装9-bit | 清周期计数 |
| STOP | 仅在接收AMI `DISCARD_STOP` 后清当前generation运行态；历史sticky保持 | 仅由同一discard释放 | 仅由同一discard清运行态 | 仅由同一discard清运行态 | 仅由同一discard撤销pending | 按自身STOP协议终止序列，不向检测子模块直连清理 |
| abort / system fault | 仅在接收AMI `DISCARD_ABORT` / `DISCARD_SYSTEM_FAULT` 后清当前generation运行态；历史sticky保持 | 仅由同一discard释放 | 仅由同一discard清运行态 | 仅由同一discard清运行态 | 仅由同一discard撤销pending并保持故障状态 | 按自身abort协议终止序列，不向检测子模块直连清理 |
| 普通9/15切换 | 不清 | 不清 | 保持锚点/斜率 | 管理历史尾部 | 原子提交精度 | 仅观察15-to-9 |
| recheck pending | 不清 | 不清 | 不清 | 不清 | 不抢占fine | 等待15-to-9 |
| recheck accept | 清两色历史 | 必须已idle并清空 | 清临时候选/周期资格 | 清尾部/极值/事件状态 | 保持9-bit | 进入三帧序列 |

## 12. 禁止事项

以下实现违反本合同：

1. 在TB中直接例化五个模块并使用不可综合逻辑代替wrapper连接；
2. 把FIR valid直接并联给两个消费者而不记录各分支消费状态；
3. 只使用FIR自身`o_fir_idle`判断重检排空而忽略检测fork；
4. 普通精度切换清空FIR或fork；
5. 使用当前活动精度电平改写FIR中心样本携带的历史`precision_mode`；
6. 把cross或return握手帧当作真实精度提交帧；
7. 使用重检pending清除检测状态；
8. 在被动退出尾部存在时永久拉低`o_detector_idle`形成循环等待；
9. 在未消费peak、valley、return或fork事务存在时强制重检accept；
10. 将`o_reacquire_request_event`悬空、接常量或用START/abort冒充；
11. 成功重检无条件清除活动斜率，或失败重检继续宣称旧锚点有效；
12. 使用15-bit可编程重构输出替代Stage1粗FIR检测数据；
13. 把`i_sample_valid`连接到fork ready、检测器ready、生命周期或重检控制；
14. 用`i_coarse_valid`、calibration-valid、饱和或特殊数值代替独立`i_sample_valid`；
15. 让invalid事务建立FIR输出或任一检测fork pending。

## 13. PWI集成验收矩阵

| 编号 | 场景 | 真实比较要求 |
| --- | --- | --- |
| PWI-01 | 进入尾部责任分离 | cross握手后在下一安全帧真实进入15-bit；控制器立即提交且不统计尾部；峰谷检测器允许最多10笔旧9-bit RED中心样本，第11笔才报协议错误；旧样本不形成正式fine峰谷对 |
| PWI-02 | 退出尾部禁止新cross | 正常返回9-bit后送入旧15-bit中心样本；动态基线不得置`o_cross_pending`；第一笔9-bit恢复样本不得与旧15-bit样本拼接，重新建立完整9-bit证据后才允许cross |
| PWI-03 | AMB接管被动尾部 | 重检间隔pending已锁存，真实15-to-9发生且只剩被动退出尾部；FIR、fork及真实峰谷事务排空后`o_detector_idle=1`，下一安全边界允许`o_amb_recheck_accept` |
| PWI-04 | AMB接管真实事务 | 分别制造fork未释放、peak pending、valley pending或return pending；每种情况下accept必须保持0；真实事务释放后才允许接管，且不得丢失或重复消费原事务 |
| PWI-05 | 重检原子清理 | accept同拍FIR两色history_full清零、fork为空、峰谷被动尾部和旧极值/方向状态废止、动态基线临时候选和周期资格清理；三帧结束后每色重新收集21笔真实NORMAL样本才恢复FIR输出资格；成功保留可靠锚点/斜率，失败进入重新获取 |
| PWI-06 | invalid检测隔离 | 合法NORMAL事务以`i_sample_valid=0`握手后，FIR历史/count/full、检测fork、动态基线周期证据、cross、峰谷pending和精度状态全部不推进 |
| PWI-07 | invalid后合法恢复 | invalid不插0、不占用历史位置；后续合法样本保持原frame/sample/color顺序，并仅在重新具备合同要求的合法历史和检测证据后产生事件 |
| PWI-08 | V5有效资格扇出 | `i_peak_valley_config_valid=0`时PWI向baseline/cross、peak/valley和precision controller逐位送0；三者继续安全消费/排空而不发布正式cross/peak/valley、9-to-15或fine-window控制，且不得产生本地第二producer。 |

所有PASS必须来自端口、握手计数、元数据和状态输出的真实比较。不得只打印PASS文本，不得通过层次化force
制造内部状态，不得跳过21点真实预热。

## 14. 实现与验证门禁

wrapper和集成TB完成后必须执行：

- 可综合Verilog-2001检查；
- formatter-AST：0 error / 0 strict warning；
- 独立RTL lint：0 error / 0 warning；
- Vivado `xvlog`与`xelab`通过；
- xsim中~~PWI-01至PWI-07~~ PWI-01至PWI-08（V2.2：范围按第13节表格订正）全部真实比较PASS；这是要求，不是当前状态：当前单元TB只有PWI-01~PWI-05，PWI-06~PWI-08的证据状态见别名表与矩阵§13（ID=PWI-01～PWI-08）；
- wrapper Vivado OOC综合：0 error / 0 critical warning；
- Latch = 0；
- Blackbox = 0；
- 2 MHz时序满足；
- 记录LUT、FF、DSP、WNS/TNS和非阻断警告。

综合必须以wrapper为顶层并包含五个真实子模块。单独综合空壳或只综合fork不能作为集成综合证据。

## 15. Historical V1.2 Freeze Record (Non-Normative)

The V1.2 record below is retained for traceability only. The current V1.8
port, hierarchy, discard, fault and evidence rules are defined by the active
sections above and the current dependency table. No statement below asserts
implementation readiness, a current PASS result or a system closure verdict.

1. wrapper模块名冻结为`ppg_precision_window_integration`；
2. FIR输出通过单元素双输出保持型fork分别送动态基线和峰谷检测器；
3. 两个检测分支对每笔FIR事务各消费且只消费一次；
4. 普通精度切换不清FIR、fork或检测历史；
5. 控制器拥有唯一committed精度，FIR中心元数据保留真实历史精度；
6. scheduler使用`FIR idle && fork idle`及峰谷真实idle执行安全接管；
7. 被动退出尾部允许重检废止，真实未消费事务禁止强制接管；
8. recheck accept、busy、done和success按第8节统一广播；
9. PWI-05按动态基线V2.2解释：成功保留可靠锚点/活动斜率，清除临时相交与周期资格；
10. 动态基线V2.2已经补齐`i_reacquire_request_event`并完成回归，wrapper实现前置条件已经满足。
11. 独立`i_sample_valid`只连接FIR sample qualification；invalid事务不建立FIR输出或检测fork所有权；
12. 正常sample-valid、FIR数学、精度提交、尾部责任和重检安全条件保持V1.1语义不变。

任何改变sample-valid、fork所有权、精度提交事件、尾部责任、重检安全条件或PWI验收语义的实现，必须先修订本文版本。

当前RTL/TB仅具备PWI-01至PWI-05历史证据。~~第5.1节定义的`i_sample_valid`、discard、generation和PWI-06至PWI-10尚未实现或运行~~ **2026-09-13勘误（Stage 3 Item 3 合同文字滞后扫描发现）：`i_sample_valid`（V1.0起）与`i_run_generation`/`i_detection_discard_*`组（V1.1，2026-08-22）在`ppg_precision_window_integration.v`里均早已实现并逐位转发给五个子模块，并非"尚未实现或运行"；真正仍然缺失的是PWI-06至PWI-10专属验收TB证据——直接检查`tb_ppg_precision_window_integration.v`确认其中不含任何`i_sample_valid`引用，未见针对该端口的定向回归**，因此其证据状态为`EVIDENCE_PENDING`。
