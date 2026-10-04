from pathlib import Path
import csv,json,hashlib,subprocess,datetime
B=Path(__file__).resolve().parent; E=B/'evidence'; S=B/'snapshot'
ast=lambda n:json.loads((E/'gates'/(n+'.json')).read_text(encoding='utf-8'))['quality_gate']['ast_report']['files'][0]['modules'][0]
suffixes=['frame_id','sample_index','color_ir','frame_type','precision','config_epoch','coef_epoch','dc_recovery_epoch','amb_code_epoch','dc_code_epoch','run_generation']
expected={'o_measurement_result_discard_'+x for x in suffixes}
probe=lambda ports: sorted(expected-set(ports))
traps=['o_measurement_result_discard_'+x for x in ['frame_id','precision','config_epoch']]
assert probe(expected)==[] and probe(expected-set(traps))==sorted(traps)
proof={}
for n in ['ppg_control_top','ppg_adc_measurement_idac_integration']:
    ports={p['name'] for p in ast(n)['ports']}
    missing=probe(ports)
    assert missing==sorted('o_measurement_result_discard_'+x for x in suffixes[5:10]),missing
    proof[n]={'actual_discard_ports':sorted(p for p in ports if p.startswith('o_measurement_result_discard_')),'missing_epoch_ports':missing,'all_ports':sorted(ports)}
proof['negative_control']={'correct':[],'three_removed':probe(expected-set(traps))}
(E/'public_discard_port_evidence.json').write_text(json.dumps(proof,indent=2),encoding='utf-8')

tb_names={'tb_ppg_timing_sar9','tb_ppg_timing_sar15','tb_ppg_timing_3200hz','tb_ppg_dual_precision_top'}
orphans={'ppg_timing_sar9','ppg_timing_sar15','ppg_timing_sar9_3200hz','ppg_timing_sar15_3200hz','ppg_dual_precision_top','ppg_digital_shell','ppg_digital_esd_shell'}
cov=list(csv.DictReader((B/'coverage_A.csv').open(encoding='utf-8-sig')))
for row in cov:
    n=Path(row['path']).stem
    if n in tb_names:
        row.update(status='完成',file_status='完成',evidence=str(E/'compile'/n/'run.log')+';'+str(E/'mutation_results_A.json'),remaining='已全文核对比较、驱动、时序、watchdog、终判及单点变异；不等于穷尽所有变异')
    elif n in orphans:
        row.update(status='完成',file_status='完成',evidence=str(E/'skill_analysis_A.json')+';'+str(E/'mutation_results_A.json'),remaining='孤立参考模块内部审阅完成；C01 §8禁止纳入正式Top，处置未定属已知事项，未授予芯片集成资格')
    elif n=='ppg_control_top':
        row.update(status='部分' if row['check_item'] in ['端口与合同名称/方向/宽度/符号/语义','CDC条件与消费者','注释与代码一致'] else '完成',file_status='部分',evidence=str(E/'skill_analysis_A.json')+';'+str(E/'public_discard_port_evidence.json'),remaining='全部有效代码已读；默认6子模块连接、复位、事件merge/许可拆分/身份/输出直连已核对；继续非法参数与TOP验收语义/系统TB闭环')
    elif n=='PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT':
        row.update(status='部分',file_status='部分',evidence=str(E/'public_discard_port_evidence.json'),remaining='954行全文已读，6子模块默认连接已逐项核对，F-008 formal端口冲突；版本依赖、TOP01-24真实语义证据和继承行号继续')
with (B/'coverage_A.csv').open('w',encoding='utf-8-sig',newline='') as fp:
    w=csv.DictWriter(fp,fieldnames=cov[0]);w.writeheader();w.writerows(cov)
ledger=json.loads((E/'ledger.json').read_text(encoding='utf-8'))
for x in ledger:
    n=Path(x['file']).stem
    if n in orphans or n in tb_names:
        x.update(status='完成',remaining='孤立模块处置为已知未决；只读内部语义/全代码/端口/编译/门禁/4 TB变异完成，不授予正式芯片集成资格')
        note='A 2026-10-04：全部有效代码全文审阅；复位、无FSM/非法光学安全编码、默认组合赋值、13-bit 5000/625边界、预建立锁存、R/IR窗口、48/32/123-bit拼接和输出选择核对；实际 AST analyze 与原门禁复用；4 TB真实FAIL变异均触发'
        if note not in x['checks']:x['checks'].append(note)
    elif n in ['ppg_control_top','PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT']:
        x.update(status='部分',remaining='全部Top有效代码/C01 954行全文已读，继续参数拒绝、版本依赖、全量TOP场景与端口/锚点闭环')
        note='A 2026-10-04：6直接子模块、注册STOP/abort/clear、STATIC许可拆分、物理idle同源、owner/deadline/complete扇出、全部结果/模拟输出、注入/遥测边界实读核对；formal measurement discard五epoch缺口F-008'
        if note not in x['checks']:x['checks'].append(note)
for x in ledger: assert hashlib.sha256((S/x['file']).read_bytes()).hexdigest()==x['sha256'],x['file']
(E/'ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2),encoding='utf-8')

r=B/'PPG_FULL_REVIEW_20261002.md'; txt=r.read_text(encoding='utf-8')
txt=txt.replace('2026-10-02至2026-10-03','2026-10-02至2026-10-04')
txt=txt.replace('已确认7条：**S1=1、S2=2、S3=4、S4=0**；按主层：RTL=1、TB=2、合同=3、矩阵·台账=1','已确认8条：**S1=1、S2=2、S3=5、S4=0**；按主层：RTL=1、TB=2、合同=4、矩阵·台账=1')
txt=txt.replace('按严重度：S1 1、S2 2、S3 4、S4 0。按主层：RTL 1、TB 2、合同 3、矩阵·台账 1。','按严重度：S1 1、S2 2、S3 5、S4 0。按主层：RTL 1、TB 2、合同 4、矩阵·台账 1。')
txt=txt.replace('| F-007 | S3 | 合同 | 芯片合同两路reset_sync正文与自身勘误/实际单路架构冲突 |','| F-007 | S3 | 合同 | 芯片合同两路reset_sync正文与自身勘误/实际单路架构冲突 |\n| F-008 | S3 | 合同 | C01/C10正式measurement discard完整TXN_ID声明比AMI/Top实际端口多五epoch |') if '### F-008' not in txt else txt
if '### F-008' not in txt:
    detail='''
### F-008：正式 measurement-discard 身份在 C01/C10 要求完整 TXN_ID，实际 AMI/Top 缺五个 epoch 端口

- **严重度/层**：S3 / 合同·跨层；与F-002是不同边界，F-002针对C13 overlap私有discard，本条针对AMI与Top公开正式结果discard。
- **位置及原文（3行）**：
  - `contracts/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:620`、`contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md:290`、`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:199`，依次原文：
```text
| `o_measurement_result_discard_<TXN_ID>` | each transaction field width | Complete retained transaction identity; the exact field expansion is defined in the closure matrix and stable with the event. |
| output | `o_measurement_result_discard_event` / `reason` / `identity_valid` / `sample_valid` / `<TXN_ID>` | `1/2/1/1/each field` | AMI正式结果discard公开观测；identity-valid必须为1，完整字段在事件采样沿稳定，且不产生成功transfer |
\toutput [C_RUN_GENERATION_WIDTH - 1:0]o_measurement_result_discard_run_generation, // 被丢弃事务所属的RUN代际
```
- **描述/依据**：矩阵§1.1的82-92行明确定义11个独立端口，118-119行明确这是正式端口名宏。AMI公开组190-199与Top公开组263-272仅有6个身份分量，缺`config_epoch/coef_epoch/dc_recovery_epoch/amb_code_epoch/dc_code_epoch`五个measurement-discard端口。Top实例1186-1195、边界1572-1581也只传实际小组；detection-discard则有完整epoch组，不能替代另一个branch。
- **证据/反驳**：复用仓库skill真实formatter AST逐端口表，保存`evidence/public_discard_port_evidence.json`；检查器先以正确11字段和人为移除三字段集合做负对照，准确返回三处缺失。完整AMI/Top声明、实例与赋值核对一致。正常measurement结果自身的epoch输出虽然存在，但正式宏要求指定discard前缀的独立端口，不能当作已存在的指定端口；本条没有把诊断字段缺失升级为功能丢弃错误。用户已知C11/C14/C15 run-generation广播豁免不涵盖C01/C10公开结果组。C01全文、C10§6.10及矩阵身份定义未找到小组替代许可。跨组C10全文后如发现显式更高优先级例外，再据原文重新裁定。
- **置信度**：静态确认（形式端口与规范扩展不一致，无需行为仿真）；没有证明默认芯片的discard执行错误。
- **建议方向**：接口owner裁定公开discard要完整诊断身份还是现有紧凑身份，同步正式端口合同与矩阵；本轮不实现。
'''
    marker='## 4. 已知事项'
    pos=txt.find(marker)
    txt=txt[:pos]+detail+'\n'+txt[pos:] if pos>=0 else txt+'\n'+detail
if '## A检查点：2026-10-04 孤立模块与Top全文' not in txt:
    txt+='''
## A检查点：2026-10-04 孤立模块与Top全文

本批未修改共享源码。七个孤立RTL与四份对应TB的内部审阅已完成；它们处置未定及不属于芯片层级是已知事实，完成审阅不赋予正式集成资格。4 TB完整驱动/真实比较/watchdog/终判已查，单点变异都报错且无PASS终判：SAR9 Q3宽度12错误行、SAR15 Q2起点6、双精度MUX字段2、3200Hz帧长3；原4 TB均正常PASS。证据`evidence/mutation_results_A.json`及`evidence/mutations_A/`。

8个A主责RTL实际调用skill analyze-existing/formatter AST，退出码全部0，产物仅在本组字节相同副本目录；复用先前strict门禁规则计数，不重新列风格积压。证据`evidence/skill_analysis_A.json`。Top全部有效代码已读，C01合同954行全文已读；默认6子模块边界、注册事件合并、STATIC隔离、idle真源、owner/deadline/complete及全部输出逐项核对。Top与C01仍部分，非法参数拒绝、TOP01-24语义闭环/版本依赖/所有锚点继续。逐项最新状态以`coverage_A.csv`和`evidence/ledger.json`为准；前面历史覆盖表为旧检查点。

恢复时确认WSL无旧vvp进程，统一/额外exec session均不存在。七份无rc旧“运行中”记录实际中断，未当作通过。保留全部旧attempt日志至`evidence/resume_attempts/<tb>/before_20261004/`，仅续跑12份未完成/外部截断用例，36份已正常结束的不重复跑。每份外部时限21600秒、最多4并行，stdout实时刷新；时限与进程中断均不是DUT PASS。状态索引`evidence/regression_resume_attempts.json`，新exec session79583，最终仍读逐TB原始run.log。此前5/10秒进度探针显示仿真时间持续推进，但不能排除更晚停滞，也不能据此宣布长场景完成。

B/C/D部分交接已读取，专项发现尚待A查实际源码、合同与原始仿真再合并，不能把其他组摘要直接计入总数。
'''
r.write_bytes(txt.replace('\r\n','\n').replace('\n','\r\n').encode('utf-8'))
h=B/'handoff_A.md'; ht=h.read_text(encoding='utf-8')
ht+='\n## 2026-10-04更新\n\n总报告实际8条，新增F-008公开measurement-discard宏缺五epoch。七孤立RTL+四TB完成内部审阅，4定向变异触发真实错误；8 RTL skill analyze成功。Top全部有效代码/C01全文实读，但语义闭环、参数拒绝、全局追溯未完。原后台已随环境中断，旧日志已保留；12未完成用例续跑session79583。请以coverage_A.csv/ledger.json及新attempt日志为准，不据旧状态称仍在运行。B/C/D目录已定位，正在独立复核其专项证据。\n'
h.write_text(ht,encoding='utf-8')
print('CHECKPOINT_SAVED','8 findings','11 isolated files completed','shared source hash unchanged')
