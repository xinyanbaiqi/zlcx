from pathlib import Path
import json,collections,csv,hashlib
B=Path(__file__).resolve().parent; E=B/'evidence'; S=B/'snapshot'
a=json.loads((E/'anchor_scan.json').read_text(encoding='utf-8'))
issues=[r for r in a['references'] if r['status'] in ('out_of_bounds','text_mismatch')]
with (E/'anchor_failures.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=['source','line','reference','kind','expected','status','target']); w.writeheader(); w.writerows(issues)
print('ISSUES',dict(collections.Counter(r['status'] for r in issues)))
print('DECL_GROUPS',dict(collections.Counter(r['reference'].split(':')[0] for r in issues if r['status']=='text_mismatch')))
ast=json.loads((E/'gates/ppg_adc_pipeline_overlap_corrector.json').read_text(encoding='utf-8'))['quality_gate']['ast_report']['files'][0]['modules'][0]
ports={p['name'] for p in ast['ports']}
missing=['i_datapath_discard_'+x for x in ['config_epoch','coef_epoch','dc_recovery_epoch','amb_code_epoch','dc_code_epoch']]
assert not set(missing)&ports
router=json.loads((E/'gates/ppg_adc_result_router.json').read_text(encoding='utf-8'))['quality_gate']['ast_report']['files'][0]['modules'][0]
assert 'o_local_empty' not in {p['name'] for p in router['ports']}
(E/'c13_port_evidence.json').write_text(json.dumps({'overlap_ports':sorted(ports),'missing_discard_epoch_ports':missing,'router_ports':router['ports'],'router_counts':router['counts']},ensure_ascii=False,indent=2),encoding='utf-8')
r=B/'PPG_FULL_REVIEW_20261002.md'; text=r.read_text(encoding='utf-8')
assert '### F-002' not in text
details='''
### F-002：C13完整discard身份端口声明比RTL多出五个epoch输入

- **严重度/层**：S3 / 合同·跨层。
- **位置及原文（3行）**：
  - `contracts/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md:89`：`i_datapath_discard_<TXN_ID>` group, `o_run_generation[C_RUN_GENERATION_WIDTH-1:0]`,
  - `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:118`：`is a formal port-name macro, not an implicit packed bus or a permission for`
  - `rtl/ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v:77`：`input [C_RUN_GENERATION_WIDTH - 1:0]i_datapath_discard_run_generation, // 本次清空目标RUN代际`
- **描述/依据**：C13:85-90明文要求complete TXN_ID组；矩阵:82-92展开TXN_ID含config/coef/dc_recovery/amb_code/dc_code五个epoch。但overlap输入组:69-77只有reason、identity-valid与六个FAULT_ID形状字段，没有这五个discard epoch端口。正常事务的epoch输入不能代替独立的discard身份输入。矩阵:2863-2871同样只列出实际小组，:2920却声称60/60与合同匹配。
- **证据/反驳**：仓库skill AST端口结果与实际声明逐项一致，保存于`evidence/c13_port_evidence.json`；AMI:2077-2085实例也只传小组，没有另一路完整身份补偿。当前清除条件overlap:217只比较generation，故没有证据表明缺失的诊断epoch会造成错误清除；本条仅裁定合同与实现不一致。用户已知C11/C14/C15条件豁免针对discard广播可达性，不是C13完整形式端口免除。已检查C10/C12/C13、矩阵identity宏及最近两批同步报告，未找到把C13 TXN_ID缩成FAULT_ID的明文许可。
- **置信度**：静态确认，端口存在性无需仿真；未据此认定S1功能错误。
- **建议方向**：由接口所有者裁定完整诊断身份是否必要，选择补齐端口或把C13及台账改成实际小组。

### F-003：矩阵/别名表存在可直接证实的失效行号锚点

- **严重度/层**：S3 / 矩阵·台账。
- **位置及原文（3行）**：
  - `contracts/PPG_ALIAS_MAPPING_TABLE.md:58`：`| K01 (precision→PWI私有flag) | 无独立TB场景(语义追溯,非单独仿真项) | ... | PPG_CONTRACT_CLOSURE_MATRIX.md:872 |`（仅省略中间RTL列，原完整行保存于源文件）。
  - `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:872`：`anything?**`
  - `rtl/ppg_control_top/ppg_control_top.v:121`：`input [9:0] i_dout_stage2_low,                       // Stage2物理判决码，进入AMI（STAGE2）（二级）`
- **描述/依据**：别名:58-69的K01～K05出处仍为矩阵:872-876，实际指向CDC章节/空行；真实K行是:991-995。矩阵:1324的Verbatim declaration anchor明确写Top:121为i_adc_physical_idle，实际为i_dout_stage2_low。除这两组，脚本按明确“file:line + 逐字端口声明”的语法得到165个声明文字不匹配引用；另有14个明确文件行号超出文件总行数。12个K出处与上述165个声明引用合计177个文字不匹配记录。逐记录源行、引用、目标原文见`evidence/anchor_failures.csv`；重复引用按出现位置保留，不能当成177个独立功能错误。
- **证据/反驳**：扫描已先以正确锚点和三处已知错误作负对照，恰好报出错误文字/不存在文件/越界三类。忽略删除线中的旧引用，Cxx:3按版本行，带小数及低整数歧义按节号保留，不报为失效。C01“当前合同行号”的补记修正了合同侧Source列，未修正这些RTL声明列；:1324重建说明仍重复Top:121，没有给出实际端口行号。K机制已在真实RTL及矩阵新位置存在，故本条不是K闭环缺失。用户已知§13.1快照滞后、未独立复核台账、style backlog及旧外部文件不是本条所报告的错误。外部memory/缩写文件缺失6条单列为待裁定，未算入本发现。
- **置信度**：静态确认（声明文字/边界与K出处）；其他未附明确预期文字的“in bounds”引用仍仅为候选，未宣称正确。
- **建议方向**：从固定提交逐行重新定位并重建锚点，保留历史引用时明确标记历史性；不要用全文件统一偏移。

### F-004：C13给纯组合Router声明了不存在的注册式local-empty

- **严重度/层**：S3 / 合同·跨层。
- **位置及原文（3行）**：
  - `contracts/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md:99`：`normal output. Router o_local_empty is a registered local fact consumed only`
  - `contracts/PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md:65`：`5. router没有独立empty寄存器，STOPPING排空由校准器valid和各分支消费者状态共同汇总。`
  - `rtl/ppg_adc_result_router/ppg_adc_result_router.v:160`：`assign o_normal_valid = i_rstn && i_result_valid && flag_frame_normal;`
- **描述/依据**：C13:99-100明写Router o_local_empty为注册本地事实并由AMI排空聚合消费；实际Router共187行，没有时钟、always、寄存器、o_local_empty及discard输入，只有组合路由和元数据镜像。这同时与C12:61/65的纯组合/无empty寄存器条款相矛盾。
- **证据/反驳**：全Router代码及skill AST结构清单、AMI:1912-1973的完整Router实例都无此端口；AMI排空聚合可通过校准器/分支状态覆盖Router路径，因此不能把文档错误升级为排空死锁。C12明文的替代机制覆盖了功能需求，却没有让C13不存在的端口声明成立。本条不重复已知C11/C14/C15广播豁免、五组悬空输出或孤立模块事项。
- **置信度**：静态确认（合同内部冲突及不存在端口），不声称已仿真证明系统错误。
- **建议方向**：把C13的Router段改为C12定义的组合边界，或正式版本化新增状态需求，由接口所有者裁定。

'''
mark='## 4. '
pos=text.index(mark); text=text[:pos]+details+text[pos:]
text+='''
### 检查点②-A：ADC数值叶子与跨合同核对（部分完成）

已实读ADC捕获、S1冗余校正、S1可编程校准、Router、overlap、可编程重构、DC恢复的主要代码，检查弹性缓存握手、复位分支、中心化公式、signed扩展、舍入和饱和。另实读config_cdc_bridge、pulse_cdc_sync、reset_sync及SPI全部代码。尚未完成这些模块全部端口逐项合同表、所有FSM死锁反驳和全部TB变异，因此全部保留“部分”。新增F-002/F-003/F-004已在本检查点落盘。

锚点机械扫描共7403个显式/合同缩写引用出现位置（含重复，和用户约2300个唯一锚点口径不同）；7011个仅通过文件/边界，167个版本行通过边界，28个节号或歧义不裁定，177个明确预期文字不匹配，14个越界，6个缺文件待裁定。未覆盖全部省略文件名的`:NNN`继承引用，也未对“in bounds”逐条证明语义。故此统计不是“剩余引用全部正确”的结论。

回归：28模块+芯片+RAW自检+ADCN共31份结束，未发现FAIL标记；另外3份系统TB运行中，其余14份待运行。仅进程退出0和横幅匹配，不等于TB完整覆盖或无X；逐份日志和PASS原脚本口径仍在整理。
'''
r.write_text(text,encoding='utf-8')
print('RECORDED F002 F003 F004')
