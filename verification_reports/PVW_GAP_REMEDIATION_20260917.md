# PVW-09/32/33/39四个真实缺口+PVW-47/48两个新ID报告（2026-09-17）

> 执行依据：`TASKBRIEF_TOP01_24_GAP_REMEDIATION_20260916.md`"PVW模块4个缺口"+
> "PVW模块另需新建2个验收ID"两节。

## 总体结论

4条缺口+2个新ID全部真实补上信号级断言证据，**RTL全程未改动**。官方xsim回归
（`module_tb_regression/`）：**54/54 PASS**（46条原有+本批6条新增=54）。4条缺口全部
做了真实RTL变异测试确认判别力；2个新ID也各自做了变异测试。

## PVW-09 + PVW-39——16-bit帧号自然回绕全项目零激励（同根因）

原断言用小十进制帧号，全TB没有任何一笔样本让frame_id真正跨过0xFFFF→0x0000；PVW-39
实际触发的是RTL`:427`第1项（帧不连续，跟PVW-20同一条判据），跟"模回绕"无关。

**新增PVW-09-WRAP**：上一正式峰锚定在帧0xFFF1（65521），真实连续帧号跨越
0xFFFF→0x0000，运行最大值落在帧0x0005，帧差=(0x0005-0xFFF1) mod 2^16=20恰好合法，
断言被正确接受。

**新增PVW-39-WRAP**：全程保持帧号严格连续（避免与第1项混淆），用32768拍平坦值走够
半回绕距离（帧差MSB=1），断言经RTL`:427`第2项（峰峰半回绕）被正确拒绝并置协议诊断。

变异：移除RTL`:427`第2项，PVW-39-WRAP真实FAIL、PVW-09-WRAP不受影响（交叉确认两者
独立针对不同机制）。

## PVW-32——"recheck pending"零重检激励

原场景全程`i_recheck_busy=0`，对该信号零判别力。**新增PVW-32-BUSY**：真实驱动
`i_recheck_busy=1`（运行最大值已建立之后），层次化核对`dec_running_value`/
`dec_running_frame_id`/`o_fine_window_active`原样不变。变异：给`flag_runtime_clear`
加`i_recheck_busy`，真实FAIL（PVW-32原断言也级联FAIL，交叉确认）。

## PVW-33——"仅idle时允许accept"排除半句零覆盖

原场景两次accept脉冲全在完全idle状态触发。**新增PVW-33-BUSY**：真实建立未消费峰值
使`o_detector_idle=0`后打accept脉冲。**重要澄清**：最初假设"非idle时accept应被完全
阻止、峰谷状态不受影响"，真实回归FAIL——独立核实RTL`:346`（`flag_runtime_clear`早已
无条件包含`i_recheck_accept_event`，带`@satisfies: PVW-32,35,36`既有标签）确认真实
设计是"诊断标记+仍执行清除"，不是"阻止清除"；断言据此改为核对sticky置位+状态清零+
重回idle，这是追根因后的真实结论，不是弱化断言迁就结果。变异：移除非idle-accept
诊断项，真实FAIL。

## PVW-47（新ID）——§10.5精度提前下降条款

RTL已实现（`flag_precision_drop_event`），46条原有用例里拉低`i_active_precision_mode`
的三处都在完成返回握手之后，从未触发这条异常分支。**新增场景**：真实建立fine窗口后，
在未完成返回握手时拉低`i_active_precision_mode`，断言窗口撤销+协议诊断置位+进入
重新获取。变异：移除`flag_precision_drop_event`对`fine_window_active_o`的清除项，
真实FAIL。

## PVW-48（新ID）——§11.4 RETURN_REASON_PROTOCOL回退

RTL已实现（`flag_fine_protocol_fallback_event`），46条原有用例里拉低
`i_peak_valley_config_valid`的三处都没有活跃fine窗口，这个返回原因码从未产生。
**新增场景**：真实建立fine窗口后拉低`i_peak_valley_config_valid`，断言产生
`RETURN_REASON_PROTOCOL`(2'b10)返回请求。**范围说明**：断言收窄为核心claim本身
（返回请求+原因码），不含`flag_fine_exit_complete`额外要求的`i_active_precision_mode`
下游动作（那是另一个独立机制，真实系统里由PWC控制器响应此返回请求后触发，不属于
"PROTOCOL回退请求本身是否产生"这条claim范围）。第一版断言过宽、真实回归FAIL后按此
收窄，非事后弱化。变异：移除PROTOCOL回退分支，真实FAIL。

## 合同/别名表改动

- `ppg_system_integration/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md`§16
  新增PVW-47、PVW-48两行，§16尾注"PVW-01至PVW-46"改为"PVW-01至PVW-48"。
- `PPG_ALIAS_MAPPING_TABLE.md`：PVW-09/32/33/39四行追加说明，PVW-47/48两行新增，
  section标题"PVW-01~46"改为"PVW-01~48"。

## 回归证据

`ppg_system_integration/module_tb_regression/xsim_module_regression/tb_ppg_peak_valley_window_detector/xsim.log`：
54/54 PASS，0 FAIL。
