# PWC真实RTL缺陷修复报告——新START静默清掉两个历史sticky（2026-09-17）

> 执行依据：`TASKBRIEF_PWC_STICKY_CLEAR_RTL_FIX_20260917.md`。本报告只覆盖该brief范围内的
> 一个RTL缺陷修复，不涉及PWC-04/15/21/26/34/35那6个"缺测试证据"类缺口（在另一份
> `TASKBRIEF_TOP01_24_GAP_REMEDIATION_20260916.md`范围内，未在本次任务中处理）。

## 缺陷回顾

`ppg_precision_window_controller.v`的`switch_timeout_sticky_o`（原`:493-494`）和
`protocol_error_sticky_o`（原`:506-507`）两个历史sticky寄存器都把`i_start_ack_event`
（新合法START）当作清除条件，违反合同§6.2`:205`"新RUN不清除历史诊断"与§17.1`:731`
"新合法START和STOP本身不清sticky"。同项目`ppg_peak_valley_window_detector.v`V1.2
（2026-08-23）已经为同一条系统级要求修过RTL（对应PVW-37），PWC这边此前一直没跟进，
验收表40行里也从未有一行点名"START不清sticky"——PWC-33只覆盖了STOP那一半。

## RTL改动

文件：`ppg_precision_window_controller/ppg_precision_window_controller.v`

**改动1（原`:493-494`，现`:493-494`，行号未变因为是同行替换）**：

```diff
-		end else if(i_start_ack_event == 1'b1 || i_diag_clear_event == 1'b1)begin
-			switch_timeout_sticky_o <= 1'b0;    // 新RUN或软件明确清除历史
+		end else if(i_diag_clear_event == 1'b1)begin
+			switch_timeout_sticky_o <= 1'b0;    // 仅软件诊断清除可清历史，新START/STOP不清（合同:205/:731）; @satisfies: PWC-41
```

**改动2（原`:506-509`四行，现`:506-507`两行，删除了原来的`i_start_ack_event`独立分支）**：

```diff
-		end else if(i_start_ack_event == 1'b1)begin
-			protocol_error_sticky_o <= flag_protocol_error_event; // 新RUN先清旧历史再记录当前配置错误
-		end else if(i_diag_clear_event == 1'b1)begin
-			protocol_error_sticky_o <= 1'b0;    // 软件只清除历史标志
+		end else if(i_diag_clear_event == 1'b1)begin
+			protocol_error_sticky_o <= 1'b0;    // 软件只清除历史标志，新START/STOP不清（合同:205/:731）
 		end else if(flag_protocol_error_event == 1'b1)begin
-			protocol_error_sticky_o <= 1'b1;    // 任一协议异常锁存历史
+			protocol_error_sticky_o <= 1'b1;    // 任一协议异常锁存历史（含新START同拍触发的协议异常）
 		end else begin
-			protocol_error_sticky_o <= protocol_error_sticky_o; // 无新异常时保持; @satisfies: PWC-33
+			protocol_error_sticky_o <= protocol_error_sticky_o; // 无新异常时保持，新START本身不清; @satisfies: PWC-33, PWC-41
```

`protocol_error_sticky_o`删除专属分支后落到`flag_protocol_error_event==1'b1`这条已有分支：
`flag_protocol_error_event`（`:269`）本身是10个协议异常子条件的OR，是纯组合逻辑，不依赖
`i_start_ack_event`，所以"START同拍恰好发生协议异常"这个原有行为不受影响（原分支的
`<= flag_protocol_error_event`和现在落到的`<= 1'b1`分支效果一致，因为组合条件为真时两者
都置1）；唯一变化的是"START时无新异常、旧sticky仍为1"这种情况：原来会被强制清0，现在正确
落到`hold`分支保持1。

## TB改动（`tb_ppg_precision_window_controller.v`）

新增场景（`:713-734`，紧跟PWC-40之后、总判定门槛之前），两个独立子场景各自`reset_dut`起手：

1. **协议sticky**（`:714-722`）：`start_run`→用与PWC-33相同的手法（`i_return_9bit_valid`在
   无fine窗口时提交）真实触发`o_protocol_error_sticky=1`→**不经复位**、直接再调用一次
   `start_run`（第二次合法START）→断言sticky仍为1。
2. **切换超时sticky**（`:724-734`）：`start_run`→用与PWC-34相同的手法（`request_cross`+
   阻断`i_precision_takeover_safe`+空转`C_TEST_TIMEOUT_CYCLES+1`拍）真实触发
   `o_switch_timeout_sticky=1`→**不经复位**、直接再调用一次`start_run`→断言sticky仍为1。

总PASS门槛从40提高到42（`:737`及附近的`if(cnt_error==0 && cnt_pass==42)`）。版本号提升到
V1.2，changelog按项目惯例追加新行，不改写旧行。

## 合同/别名表改动

- `ppg_system_integration/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md`§21验收
  矩阵新增一行`PWC-41 | START不清sticky（2026-09-17新增） | ...`（原`:952`后追加，现表格
  到`:953`）。§6.2`:205`/§17.1`:731`两处规范正文本来就写对了，未改动。
- `ppg_system_integration/PPG_ALIAS_MAPPING_TABLE.md`：PWC小节标题从"PWC-01~40"改为
  "PWC-01~41"（`:347`），新增PWC-41映射行（原PWC-40行之后）。
- `ppg_system_integration/module_tb_regression/run_module_tb_regression.sh`：
  `TB_EXPECTED_PASS[tb_ppg_precision_window_controller]`从40改成42，否则回归驱动脚本自己
  的门槛判定会跟TB内部新门槛不一致而误报FAIL。

## 回归结果（真实双向验证）

**1. 新断言判别力验证**（scratchpad内重建修复前RTL，真实项目文件全程未动）：把两处清除条件
还原成修复前的样子（用Python精确定位并替换，`diff`确认逐字符还原），编译新TB（新TB本身
未改，改的是旧RTL副本）后用`vvp`运行：

```
PASS PWC-01 ~ PWC-40（40项全过，证明新场景没有破坏任何既有用例）
FAIL PWC-41 new legal START preserves protocol sticky time=2286000
FAIL PWC-41 new legal START preserves switch-timeout sticky time=2446000
PWC REGRESSION FAIL pass=40 fail=2
```

两条新断言在旧RTL上**确实FAIL**，证明它们有真实判别力，不是又一条恒真式。

**2. 官方xsim回归**（`ppg_system_integration/module_tb_regression/run_module_tb_regression.sh`，
真实项目文件，Vivado 2022.2 xvlog+xelab+xsim全流程，2026-09-17）：

```
tb_ppg_peak_valley_window_detector       pass=46/46  fail=0  verdict=PASS  (未受影响，交叉验证)
tb_ppg_precision_window_controller       pass=42/42  fail=0  verdict=PASS
tb_ppg_coarse_detection_fir              pass=98/98  fail=0  verdict=PASS  (未受影响，交叉验证)
```

日志：`ppg_system_integration/module_tb_regression/xsim_module_regression/tb_ppg_precision_window_controller/xsim.log`
（PWC-41两条断言在第57、58行，均为PASS）。PVW/FIR两个模块本次未改动任何文件，同批跑出的
46/46与98/98可以确认本次改动没有波及其他模块（三者共用同一个回归驱动脚本和xvlog工作区）。

## 未处理的关联项（如实记录，不在本次范围）

- `PPG_ALIAS_MAPPING_TABLE.md`第89行`Acceptance-D01-01`那条提到的PWC/C23门控关系背景
  文字未动（本次改动不影响那条的结论）。
  `PWC_01_40_WORKLINE_D_INDEPENDENT_RECHECK_20260916.md`里另外6条"缺测试证据"类缺口
  （PWC-04/15/21/26/34/35）本次未处理，留给`TASKBRIEF_TOP01_24_GAP_REMEDIATION_20260916.md`
  范围内的后续工作。

## 结论

RTL缺陷已修复、已通过双向验证（旧RTL上新断言FAIL，新RTL上全部PASS），验收表/别名表已同步
补齐PWC-41，官方xsim回归42/42全过，PVW/FIR交叉确认未受影响。这条缺陷从"发现"到"修复+验证
+登记"已经完整闭环，不留模糊地带。
