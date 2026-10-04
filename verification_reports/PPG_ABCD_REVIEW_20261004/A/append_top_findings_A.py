from pathlib import Path
import json
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence'
report=B/'PPG_FULL_REVIEW_20261002.md';text=report.read_text(encoding='utf-8')
def quote(file,line,token):
    value=(S/file).read_text(encoding='utf-8').splitlines()[line-1]
    assert token in value,(file,line,token,value)
    return f'`{file}:{line}`\n> {value.strip()}\n'
if '### F-048' not in text:
    section='''### F-048：Top 诊断清除的排他消费者名单漏掉表征 CDC

- 严重度：S3；层：合同；置信度：静态确认。
- 位置与原文：
'''+quote('contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md',365,'only')+quote('contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md',366,'AMI, Scheduler, SSW and supervisor')+quote('rtl/ppg_control_top/ppg_control_top.v',849,'i_diag_clear_event(flag_diag_clear_event)')+'''
- 描述：C01 §4.1 明确写 only 并列四个直接消费者，但其 §5.2 的端口连接表（526）要求表征 CDC 也接顶层诊断清除，当前 RTL 正是同一注册事件的第五路扇出。两个规范条款不能同时按字面满足。
- 证据与反驳：(a) C07:113、315 明确规定该输入和 sticky 清除，CCC RTL:184-190 实现了新错优先及清除；因此第五路不是多余功能或真实 RTL 错误。(b) 此问题不在用户第4节的已知事项；矩阵:1334 已明确记载“only”名单与 §5.2/RTL 不一致，独立核实确认该注记尚未落实到被审 C01，不把它说成此前从未有人记录。(c) 同份 C01:526 明文要求第五路，排除将其视为合同允许的四路排他名单。Top:321 注释也仍只列四路。无需仿真来确认文档自身矛盾，未把清除功能判为失败。
- 建议方向：统一 C01 §4.1、§5.2 与 Top 清除消费者注释，保留或调整第五路由合同所有者裁定。

'''
    text=text.replace('## 4. 已知事项',section+'## 4. 已知事项',1)
if '### F-049' not in text:
    results=json.loads((E/'inj_identity_A/comparison.json').read_text(encoding='utf-8'))
    assert len(results)==3 and all(r['compile_rc']==0 and r['run_rc']==0 for r in results)
    assert 'INJ_TB_PASS' in results[0]['key_lines'] and 'INJ_TB_PASS' in results[1]['key_lines']
    assert any('INJ_TB_FAIL error_count=1' in x for x in results[2]['key_lines'])
    section='''### F-049：INJ-03 把“不是全 X”当成无效样本身份保持正确

- 严重度：S2；层：TB；置信度：仿真确认。
- 位置与原文：
'''+quote('rtl/ppg_control_top/tb_ppg_control_top_injection.v',957,'reg_captured_frame_id ===')+quote('rtl/ppg_control_top/tb_ppg_control_top_injection.v',961,'identity/value fields intact')+quote('contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md',935,'保留identity')+'''
- 描述：INJ-03 只排除整个 coarse 值/整个 frame_id 全 X，未把正式结果身份与该笔真实 owner 的身份比较。有限数值但错误的 frame_id 仍会打印身份完整且整个注入 TB PASS；C01 TOP-23 要求保留真实身份，C25:718 的 PRC-08 同样绑定真实身份匹配事务。
- 仿真：在仓库外只将 Top:1497 的正式 frame_id 透传改成“sample_valid=0 时最低位翻转”；不改变 AMI 内部、owner、RAW、资格及其他结果字段。完整原 INJ 场景及原比较分支保留，仅加不影响计数的独立观察。正常对照：
```text
AUDIT_IDENTITY expected_frame=1 observed_frame=1 sample_valid=0
INJ_TB_PASS
```
身份变异：
```text
AUDIT_IDENTITY expected_frame=1 observed_frame=0 sample_valid=0
AUDIT_IDENTITY_FAIL invalid result frame differs from the real accepted owner
PASS INJ-03 invalid-sample-injected transaction reached the formal boundary with sample_valid=0 and identity/value fields intact
INJ_TB_PASS
```
负对照仅把同一真实预期比较纳入 cnt_error，完整 TB 最终为 `INJ_TB_FAIL error_count=1`。三组真实 iverilog -Wall 编译成功，vvp 均执行至最终横幅；rc=0 不能替代横幅判据。原始日志、两个仓库外变异及观察代码在 `evidence/inj_identity_A/`，命令与 SHA 在各 native.result.json。
- 反驳：(a) robust:1712-1716 对 PRC-08 直接引用并打印 INJ-03，未再构造或比较该无效事务身份；INJ-03 的后续合法样本检查仅检查 valid/sample_valid，不能查出前一笔有限错误 frame_id。其他单位/数值场景可以检验合法载荷，但本次完整注入 TB 在该真实无效事务错位时确实逃逸，不声称全部系统 TB 都漏掉所有身份错误。(b) 与已知 P2S 三路遥测错拍不同，本变异针对正式事务身份；与 F-001 悬空校准注入输入及 F-042 OIB 队列检查也是不同判据。(c) C01:935 不允许无效资格事务改绑身份，sample-valid=0 不免除载荷身份保持。
- 建议方向：在注入握手前缓存真实 owner 的完整身份，并在对应正式无效结果出现时逐字段比较。

'''
    text=text.replace('## 4. 已知事项',section+'## 4. 已知事项',1)
report.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
print('APPENDED F048 F049; source quote text and three real simulation final banners verified')
