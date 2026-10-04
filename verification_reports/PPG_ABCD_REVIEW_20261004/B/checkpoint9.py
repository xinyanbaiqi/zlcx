from review import *
from collections import Counter

report=OUT/'PPG_REVIEW_B.md'
body=report.read_text(encoding='utf-8')
assert '### B-018' not in body, 'checkpoint9 already saved; do not append twice'
old='`| i_max_fine_window_frames, i_max_reacquire_frames | precision controller |`（原Markdown含代码反引号）'
new='`| `i_max_fine_window_frames`, `i_max_reacquire_frames` | precision controller | The limits are stable configuration values; the separate valid gate prohibits formal fine-window control and 9-to-15 requests when low. |`'
assert old in body
# Use a fenced original row, because nested backticks are not valid inline code.
body=body.replace('- 原文（1行）：'+old+'。', '- 原文（1行）：\n```text\n| `i_max_fine_window_frames`, `i_max_reacquire_frames` | precision controller | The limits are stable configuration values; the separate valid gate prohibits formal fine-window control and 9-to-15 requests when low. |\n```\n')
body+='''

## 批次9：全文注释、ID语义及依赖收尾

### B-018 — 相同验收编号在合同与TB中指向不同场景

- S3 / 合同与测试映射；静态确认。C08 `contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md:1135,1149,1166-1167` 对应 `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:564,592,708,724`；C24 `contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md:160-161` 对应 `rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v:470,480-488`。机械索引可找到同号TB调用，却不能据此判定需求闭合。
- 原文（3行）：
```text
| FSC-03 | 400 Hz周期 | 相邻宏帧起点严格相差5000个2 MHz周期 |
check_fsc(3, (cnt_frame_start == 0) && (o_next_sample_index == 0) && !o_transaction_inflight);
check_fsc(17, cnt_owner_commit == 1);
```
- FSC-03实际检查START后尚未出现宏帧/owner；周期比较在FSC-14（:581），而合同FSC-14是DCS_CAL RED。FSC-17合同要求校准资格与请求保持，TB却处于RED-only正常帧，只检查owner数为1。FSC-34合同是随机反压，TB检查一次失败完成后NORMAL完成数为0；FSC-35合同是长期400Hz无漂移，TB检查STOP后的释放。SUP-09合同是fault-discard/external-abort区分，TB检查watchdog在阈值前真实idle；SUP-10合同是AMI延迟fault reason保持，TB检查清历史后的第二次episode。不是同一场景的不同文字。
- 证据：全文原表/调用控制流，`evidence/id_four_link_audit.json` 的numeric dispatch和SUP子case索引；重新按实际行号读取，未运行新长仿真。反驳：scheduler :909/:927（FSC-58/59）确有非法run-profile/input-source的有效资格比较；SUP-06以及前面的fault-discard检查仍有独立价值。它们不能让原FSC-17或SUP-10同号证据变成合同所述场景；不声称这些需求在全项目完全未验证。
- 与B-004区分：B-004是周期允许值与Q3资格过弱；本条是验收编号语义错位。与F-003区分：这里的行号可找到实际有效调用，问题不是锚点漂移。建议按冻结需求重建编号映射，保留已有有效检查并显式关联替代场景。置信度：静态确认。

### B-019 — C09当前版本声明与三个规范依赖绑定不一致

- S3 / 合同与版本台账；静态确认。`contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md:3` 已是V1.10（AMB单相Q2修订），`:7`仍称sole current V1.9。C08依赖表`:59`、C10`:63`、C24`:17`及 `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:1206,1244` 仍绑定C09 V1.9，与约定按 `C09:3` 读取当前版本的台账不一致。
- 原文（2行）：
```text
> Normative status: V1.9 is the sole current SSW interface and lifecycle authority (V1.9 is additive over V1.8, see the 2026-08-30 change record above). Earlier V1.3.x-V1.7 status and historical regression wording cannot classify missing joint implementation evidence as a contract-interface defect.
| C09 | `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` | V1.9 | SSW registered fault-record source and stop-drain consumer. |
```
- `dependency_audit.py` / `evidence/dependency_bindings.json` 核对B七份规范合同的54条当前依赖，按当前matrix §12.4a canonical path解析，54条路径全匹配，只有上述3条版本与实际目标第3行不匹配。故意错版本、错路径两个负对照均拒绝。首版版本正则在中文紧跟数字时错误退回V1/V2，输出21条假差异；已撤销该结果，加入中文V1.10、英文逗号、英文句号三个解析fixture，修正后才采信3条差异。未修改共享合同。
- 反驳：V1.10是明确增量修订，V1.9仍含owner/Q3/注入等主要规范，不能把旧sole标签解释成禁止新增端口或推导所有功能错误。C08/C10/C18也各有新修订记录与旧current标签并置，记录为同类版本权威措辞待统一。此项只否定版本/依赖台账完全一致；不重复F-003行锚点问题，也不重报已知§13.1数量滞后。建议明确最新增量与基础规范的关系并同步三处依赖和当前台账；历史版本记录保留为历史。置信度：静态确认与机械负对照。

### 完整读取与抽查口径

7 RTL、13 TB和9份合同的全文（含文件头、中英文修订记录及有语义的内联注释）均已读取。相同系统公共任务使用逐行内容对照后复用阅读，所有差异和新增主序列独立读取。`evidence/comment_inventory.json` / `unique_comments.json`仅为定位/去重索引，不是Verilog语义解析器。语法依据技能formatter AST和真实Icarus编译；注释/PASS/历史回归声明不是规范或当前动态证据。

312个不同合同ID来自B合同明确定义表以及C25中属于B六系统TB的五组需求；14个family均作语义抽查。`evidence/id_four_link_audit.json`保留每个ID的四类原始来源；范围和子case归一化经过fixture，numeric FSC调用、移除TB联系与移除registry联系有负对照。索引里的“有TB代码提及”可能只是横幅或display，不等于真实比较；registry提及可能是历史行，不等于当前CLOSED。完整逐ID语义签核和全局锚点台账仍归A，B完成了本组机械核对及family抽查。

| family | 明确定义数 | 已抽查的实际证据与结果 |
|---|---:|---|
| AMI | 54 | AMI-47合同:1259，叶子TB:1579/1628，实际one-shot绑定/拒绝；INJ互斥处理窗口受B-013限制。AMI-48~53在本组单元TB没有同号case，不能按横幅补齐；对应系统身份/invalid/discard场景按实际条件审，AMI-54跨层门控由D01及静态连接承接，不宣称本组单元覆盖54项。 |
| AMR | 14 | AMR-05合同:655、TB:384-391，pending前/后与未启动可比较；码/epoch不由此调度叶子观测，系统RRC-02限制已记。AMR-08/09涉及IDAC重搜索，AMR-13涉及隔离数值链，叶子无同号case，不自动判为RTL缺失；B-007给真实跨模块反例。 |
| FFK | 9 | FFK-02合同:618，C主责TB:334-340实比两分支payload且初始ready均0；只复核共享合同所需场景，不代替C全文审阅。 |
| FSC | 57 | FSC-03/17/34/35检查调用确有，但语义错位B-018；另有58/59资格对照，不能混作57项需求均已闭合。 |
| IDT | 15 | IDT-03合同:633、C主责TB:588-592，N_CONFIRM=1第一笔有效越界建立pending；数值叶子全文由C负责。 |
| LFA | 12 | LFA-04合同C25:697、TB:1188-1232，先abort后迟到DONE具有真实在途身份并检查failure/no formal；同拍释放缺口另见B-012。LFA-10b SKIP保留，不能转PASS。 |
| NRE | 6 | NRE-01合同C25:618，TB连续RUN监视五个重检活动信号、:1048-1052比较计数；NRE-06只做frame非递减和capture>0，不能替代精确节拍/无丢失。 |
| OIB | 10 | OIB-06合同C25:684、TB:946-960/1868-1875，缺少守恒和元数据期望，B-015；OIB-04是构造方法约束，OIB-10明确静态ready分析/单位fork证据，不要求同名dynamic case。 |
| PWC | 41 | PWC-41合同:954、RTL:494/511、TB:746/758，有真实sticky非空前提和两个比较；已有修复有效。PWC同拍discard/commit仍有B-010。 |
| PWI | 8 | PWI-05合同:643、TB:830-837，在20/21笔边界验证重预热。06/07为invalid、08门控，原TB仅01~05，相关系统场景的范围按实际比较记录，不能宣称单元8项全覆盖。 |
| RRC | 12 | RRC-01合同C25:601、TB:1067-1072只有首次pending帧数打印，B-014。RRC-12有独立真实调码比较，不据前者否定所有调码覆盖。 |
| SID | 12 | SID-05合同C25:553、三阶段deadline抑制/恢复场景均有非空请求，:1117及后续阶段；已知248同拍commit项仍未覆盖，不另报。 |
| SSW | 52 | SSW-46合同:863、TB:986-994，非零SAR15事务逐tick检查SAR9两总线为0；本case只支持其明确比较的精度隔离部分，其他码窗由45/47/48交叉核验。同拍abort/completion另见B-012。 |
| SUP | 10 | SUP-06合同:157、TB:441/458及补充边界对照，真实idle优先、无伪完成成立；非法参数拒绝缺口B-001。09/10同号语义错位B-018，历史未clear rearm覆盖缺口B-002。 |

旧FSC/SSW/AMR/IDT等家族大量没有同名`@satisfies`或在matrix/alias逐项枚举，机械索引按实际缺失记录，不创造豁免、不把无标签等同无实现，也不补写虚构CLOSED。旧§13.1和G-FP独立复核范围不足属已知事项；A可从逐ID索引合并全局账。额外INJ/P/N/K标签在矩阵而非B合同定义表中，已按本组相关场景逐条读取，B-013/016等保存语义反证，不能混入312个定义数重复计数。

### 工具与尚不具备的签核证据

使用bundled Python、D:/Git/cmd/git.exe、现有WSL Debian中的Icarus11.0。7份RTL formatter AST结构成功，同版本deliverable gate/lint已按来源复核复用；AMI 2 error/1 warning、SSW 10 error、PWI 1 warning，其余4份零。错误规则是既有VG014/VG0611/VG0661/VG0603/VG0666积压，详各模块evidence/skill，不重复列为功能发现；门禁结构结果不等于协议正确。专项的compile.log/run.log/result.json保留真实编译、FAIL和退出码；带FAIL而rc=0的原TB依日志判失败，负对照预期FAIL不算原RTL回归失败。

全套原TB/长回归由A统一执行，本组只做必要短对照及同版本日志复核。三份外部3600秒截断仍是未完成，不能写PASS或内部死锁。未重新运行Vivado xsim、Verilator、FPGA/ASIC综合、STA或PVT；本组结果不构成芯片或工具签核。B-007完整Top拒绝-owner输入窗口的专项以及B-010完整Top同拍取消到达窗口尚没有新的动态证据，这些限制保留在各条结论，不扩大已验证范围。

截止本批，B-001~019共19项：8 S1 RTL、7 S2 TB、4 S3合同/一致性；无新增S4风格条目。发现保持未修复，本组共享源始终只读。正在做最终文件台账与基准字节复核。
'''
report.write_text(body,encoding='utf-8')
with (OUT/'handoff.md').open('a',encoding='utf-8') as fp:fp.write('\n批次9补记：全文注释及14 family抽查完成，312明确定义ID机械联系保存；B-018同号语义错位、B-019三处C09版本绑定。当前19项（8S1/7S2/4S3），最后核对报告/覆盖/固定提交。此前进行中状态为历史批次，最终交接待此复核后重写。\n')
print('Saved checkpoint9: B-018/019; reading and ID sample review complete; final verification pending')
