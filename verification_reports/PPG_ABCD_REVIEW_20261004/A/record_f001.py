from pathlib import Path
BASE=Path(__file__).resolve().parent
p=BASE/'PPG_FULL_REVIEW_20261002.md'
s=p.read_text(encoding='utf-8')
finding='''
### F-001 — 启用注入的4份系统TB使calibration-loss valid悬空，污染正式FIR资格

| 字段 | 内容 |
|---|---|
| 严重度 / 层 | **S2 / TB（跨层消费链已核实）** |
| 位置 | `rtl/ppg_control_top/tb_ppg_control_top_injection.v:234`；`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v:264`；`tb_ppg_control_top_owner_identity_backpressure.v:262`；`tb_ppg_control_top_startup_idac_calibration.v:253`（后3份同目录）；DUT消费：`rtl/ppg_coarse_detection_fir/ppg_coarse_detection_fir.v:313-315` |
| 描述 | 四份TB显式覆盖C_ENABLE_TEST_INJECTION=1，却未连接i_test_calibration_loss_inject_valid。Icarus逐份报告dangling input port 26。运行时enable被实际置1后，Z沿Top→AMI→PWI直通到FIR，并使正常合格样本的flag_sample_qualified为X。21个合格NORMAL点可以仍得到result_valid=1，但o_detection_qualified=X。这削弱这些验证构建中的正式检测资格证据；不能由既有PASS横幅证明其无影响。本项不声称生产RTL有此错误，生产默认0的负分支已独立证明屏蔽Z。 |
| 合同依据 | C01 `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md:271`定义该保持型请求；`:293-301`定义编译期/运行时门控与非活动约束；FIR注入接口和C19正式资格规则。不存在把未驱动Z当作合法请求0的条款。 |
| 证据 | `evidence/compile/<四份TB>/compile.log`的真实悬空端口警告；`evidence/fir_floating_ab/audit_fir_ab.run.log`三路同激励；Top透传`:1372`、AMI`:2615`、PWI`:651`。|
| 置信度 | **仿真确认**：已确认叶子资格X与编译期关闭屏蔽；四份完整系统TB受影响的场景范围仍待监测，不把叶子A/B扩大为四份全部验收失效。 |
| 建议方向 | 把未使用的calibration-loss valid显式接0，重跑四份TB并增加正式资格无X检查；仅建议，不实施。 |

原文（合计3行，直接按固定提交重新读取）：

```verilog
.C_ENABLE_TEST_INJECTION(1) // 本文件的核心覆盖：打开验证专用异常注入结构生成
assign flag_test_calibration_loss_inject_fire = (C_ENABLE_TEST_INJECTION != 32'd0) && i_test_inject_enable && i_test_calibration_loss_inject_valid && o_test_calibration_loss_inject_ready;
assign flag_sample_qualified = i_sample_valid && (i_coarse_recovery_calibrated && !flag_test_calibration_loss_active) && (i_stage1_saturation_low == 1'b0) && (i_stage1_saturation_high == 1'b0) && (i_coarse_saturation_low == 1'b0) && (i_coarse_saturation_high == 1'b0);
```

后两行省略尾随中文注释，代码正文与RTL:313、315逐字相同。

最小TB实际输出（不从历史报告抄录）：

```text
audit_fir_ab compile 0 run 0
INPUT qualified A(open,enabled)=x B(tie0,enabled)=1 C(open,disabled)=1
OUTPUT valid A=1 B=1 C=1 qualified A=x B=1 C=1 guard=33
AUDIT_AB_CONFIRMED
audit_fir_ab_negative compile 0 run 1
FATAL: audit_fir_ab_negative.v:160: AUDIT_AB_FAIL
Time: 356000 Scope: audit_fir_ab
```

上报前反驳：

- (a) 核实三层透传后，保护只在编译期参数0或运行时enable0时生效；FIR接口无Z→0净化。运行时enable置1位置分别为injection:732、lifecycle:1067、owner_identity:1715、startup:932/1006。独立C路参数0且悬空确实输出资格1。
- (b) 该悬空在基线§6.6和TB维护§7中已被记录；**不属于用户第4节免报条目**。本轮补充的是正式资格X的直接A/B证据，保留历史来源，避免把它说成首次发现。
- (c) C01/C19没有允许未驱动的有效请求；普通生产构建保持0的豁免不适用于这四份参数1的TB。

变异负对照仅把B路期望资格1改成0，编译仍0而运行返回1并触发AUDIT_AB_FAIL，证明比较能失败。
'''
assert '### F-001' not in s
s=s.replace('待分批填入。',finding,1)
s=s.replace('尚未完成审阅；当前无可上报的已确认发现。不得将未审或工具未运行理解为通过。','尚未完成全量审阅。当前已确认：S1=0、S2=1、S3=0、S4=0；按层：TB=1。最重要条目为F-001（4份启用注入的TB输入悬空导致正式FIR资格X）。这不代表其余范围无错误，不得将未审或工具未运行理解为通过。')
s+='\n### 增量检查点：F-001已保存\n\n最小三路A/B和错误期望值负对照均已完成；原克隆没有写入。叶子RTL完整审阅批次尚未结束，回归仍在运行。\n'
p.write_text(s,encoding='utf-8')
print('F-001 saved')
