from pathlib import Path
import json,collections,hashlib,subprocess,re,datetime
B=Path(__file__).resolve().parent; S=B/'snapshot';E=B/'evidence';r=B/'PPG_FULL_REVIEW_20261002.md';text=r.read_text(encoding='utf-8')
ledger=json.loads((E/'ledger.json').read_text(encoding='utf-8'))
results=json.loads((E/'regression_results.json').read_text(encoding='utf-8')); runs={x['tb']:x for x in results}
read_modules={
'ppg_adc_async_stage_capture':'代码实读：DONE两级同步/模式冻结/单笔pending/缓存反压/复位；合同全部端口与异常重叠仍待核对',
'ppg_adc_s1_redundancy_corrector':'代码实读：-4..515 signed11/钳位/上下文握手/保持/复位；符号反转变异触发1031条FAIL',
'ppg_adc_s1_programmable_calibrator':'代码实读：33bit最坏累加范围/Q16对称舍入/12bit饱和/载荷保持/复位；移除offset变异触发1036条FAIL',
'ppg_adc_result_router':'全文代码+C12全文/C13主要边界核对：纯组合、one-hot类别、非法类别消费、复位门控；复位变异触发FAIL；F-004',
'ppg_adc_pipeline_overlap_corrector':'主要代码实读：S2冗余/固定Q16/饱和/缓存/复位/generation discard；C13完整身份差异F-002',
'ppg_adc_programmable_reconstructor':'主要代码实读：signed中心化/增益乘法宽度/Q17对称舍入/15bit饱和/精度资格/缓存复位；中心值变异触发1042条FAIL',
'ppg_adc_dc_recovery':'主要代码实读：DC unsigned8与signed增益乘法宽度/Q17/24bit饱和/资格/缓存复位；少量payload段与全部合同比对未完成',
'ppg_config_cdc_bridge':'全文代码实读：req/ack toggle、稳定总线邮箱、busy拒绝、两域同步链与复位；ASIC约束/独立复位未签核',
'ppg_pulse_cdc_sync':'全文代码实读：toggle/两级目标同步/差分脉冲；SPI4MHz下命令间隔反驳常规丢脉冲候选；任意使用条件未全量证明',
'ppg_reset_sync':'全文代码实读：异步assert/两级同步释放；跨域系统复位政策未全部核对',
'ppg_spi_register_file':'全文代码+SPI地址/位段/写属性/复位实读；38诊断及128影子字节独立对照；真实Mode0错位F-005',
'ppg_400hz_frame_calibration_scheduler':'重点读V1.8 deadline/owner/DONE身份比较；sample-index比较变异触发FSC-32 FAIL；全部FSM仍待审',
'ppg_precision_window_controller':'重点读09-17两类sticky保持、START/diag-clear；START清sticky变异触发PWC-41 FAIL；全模块仍待审',
'ppg_adc_measurement_idac_integration':'抽读注入透传、Router/overlap实例、private discard、输出资格消费链；owner/截止/完成释放全协议仍待审',
'ppg_precision_window_integration':'抽读注入直通FIR链；全部PWI协议和算法连接仍待审',
'ppg_control_top':'抽读注入参数/端口/AMI连线、SPI telemetry、ADC idle链；全端口/复位/owner协议仍待审',
'ppg_chip_digital_top':'抽读SPI pad直连/源域复位/实际层次；芯片原TB与采样时刻变异A/B；全部顶层端口仍待审'}
for x in ledger:
    p=Path(x['file']); stem=p.stem
    if x['layer']=='RTL' and stem in read_modules:x['checks'].append(read_modules[stem])
    if x['layer']=='TB':
        rr=runs.get(stem)
        if rr:
            if rr['state']=='finished':
                if rr['rc']==0:x['checks'].append('Icarus入库TB运行结束；日志FAIL=0；横幅已核对；不等于覆盖充分或全周期无X')
                else:x['checks'].append(f"外部wall-clock上限截断，rc={rr['rc']}，回归未完成，不能裁定RTL/TB自身超时")
            else:x['checks'].append('Icarus回归'+('后台运行中' if rr['state']=='running' else '排队未运行'))
        if stem=='tb_ppg_chip_digital_top':x['checks'].append('SPI采样任务实读，真实边沿副本3个FAIL，F-006；P2S和其他任务未全文审')
        if stem in ['tb_ppg_'+m for m in ['adc_s1_redundancy_corrector','adc_s1_programmable_calibrator','adc_programmable_reconstructor','precision_window_controller','adc_result_router','400hz_frame_calibration_scheduler']]:x['checks'].append('关键RTL变异负向抽查触发FAIL；并非全部断言逐项审阅')
    if x['layer']=='合同':
        x['checks'].append('机械扫描验收ID表列及25份Cxx版本/依赖文本；不以出现性证明闭环')
        if p.name=='PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md':x['status']='部分';x['checks'].append('全文实读并对Router及AMI连接；其余upstream完整身份条款仍待核')
        elif p.name=='PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md':x['status']='部分';x['checks'].append('全文实读；overlap/Router正式端口矛盾F-002/F-004；生命周期全行为未仿真')
        elif p.name=='PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md':x['status']='部分';x['checks'].append('SPI协议/38读字节+写方向地图逐项静态核对；关键CDC/P2S段实读；历史长段/全合同未审')
        elif p.name in ('PPG_CONTRACT_CLOSURE_MATRIX.md','PPG_ALIAS_MAPPING_TABLE.md'):
            x['status']='部分';x['checks'].append('关键章节/identity定义/K条目/C01/C13台账抽读；全引用出现性+边界扫描，F-003；未全量语义核实')
        elif p.name=='TAPEOUT_FINAL_REVIEW_GUIDE.md':x['status']='部分';x['checks'].append('全文实读；外部路径/过时数字按用户已知背景登记，不当权威')
        elif p.name in ('PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md','PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md'):
            x['status']='部分';x['checks'].append('注入/检测资格相关条款实读，F-001；其余全文未审')
        x['remaining']='未列为实读的条款均未语义审阅；端口全量比对、版本依赖裁定、各ID真实检查和家族抽查未完成'
for p in sorted((S/'rtl/ppg_control_top').glob('*.vh')):
    ledger.append(dict(file=p.relative_to(S).as_posix(),layer='TB支持',lines=len(p.read_text(encoding='utf-8-sig').splitlines()),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),status='部分',checks=['include自包含编译可解析','ID出现性机械扫描','实际回归使用；未全文语义审阅'],remaining='全部函数/task数值与波形语义、FAIL变异及时间边界仍待审'))
(E/'ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2),encoding='utf-8')
start=text.index('| 文件 | 层 | 行数 | 状态 | 已做检查');end=text.index('## 6. 回归对比',start)
table=['| 文件 | 层 | 行数 | 状态 | 已做检查 / 剩余 |','|---|---|---:|---|---|']
for x in ledger:table.append(f"| {x['file']} | {x['layer']} | {x['lines']} | {x['status']} | {'；'.join(x['checks'])}；{x.get('remaining','全部语义及跨层合同核对尚未完成')} |")
text=text[:start]+'\n'.join(table)+'\n\n'+text[end:]
# Regression table reads ONLY actual logs via regression_results, never summary.tsv.
start=text.index('## 6. 回归对比');end=text.index('## 7.',start)
reg='''## 6. 回归对比（截至本检查点）

工具为Icarus11，不是Vivado xsim；系统/芯片按原脚本`^PASS `计数，单位TB按其实际PASS样式计数，PASS:格式包括最终汇总。基线优先最新TB_MAINTENANCE_20260930的横幅；该表未给每份逐行PASS数量时不臆造。系统数字取REGRESSION_BASELINE_20260930逐TB表。每份日志路径为`evidence/compile/<TB>/run.log`；未读取summary.tsv作结论。表中“横幅一致”仅指可比文字/数字，不证明断言语义充分或全周期无X。

| TB | 本次rc | PASS行 | 最新系统基线PASS | FAIL行 | 横幅/结论 |
|---|---:|---:|---:|---:|---|
'''
for rr in results:
    if rr['state']!='finished':reg+=f"| {rr['tb']} | — | — | — | — | {'后台运行中' if rr['state']=='running' else '排队未运行'} |\n";continue
    verdict='外部3600秒wall-clock截断，未完成' if rr['rc']!=0 else '入库原TB横幅一致' if rr['banner'] else '无预期最终横幅，须核查'
    if rr['baseline'] is not None and rr['rc']==0 and rr['pass_lines']!=rr['baseline']:verdict='PASS数量差异，须核查'
    if rr['tb']=='tb_ppg_chip_digital_top':verdict+='；真实采样副本FAIL，见F-005/F-006'
    reg+=f"| {rr['tb']} | {rr['rc']} | {rr['pass_lines']} | {rr['baseline'] if rr['baseline'] is not None else '未给/横幅对照'} | {len(rr['fail_lines'])} | {verdict} |\n"
reg+='\n三份长TB被审阅驱动的外部上限截断（rc124），不是TB watchdog的证据。五秒诊断副本已真实推进仿真时间，排除了time0 delta循环。它们没有完成最终PASS数量对比，不能写成“回归全部通过”。剩余后台作业仍写各自run.log/run.rc，本报告为检查点静态快照。\n\n'
text=text[:start]+reg+text[end:]
# Correct the primary quote to the exact whole source line.
old='`| K01 (precision→PWI私有flag) | 无独立TB场景(语义追溯,非单独仿真项) | ... | PPG_CONTRACT_CLOSURE_MATRIX.md:872 |`（仅省略中间RTL列，原完整行保存于源文件）。'
actual=(S/'contracts/PPG_ALIAS_MAPPING_TABLE.md').read_text(encoding='utf-8').splitlines()[57]
text=text.replace(old,'``'+actual+'``。')
text=text.replace('`normal output. Router o_local_empty is a registered local fact consumed only`','``normal output. Router `o_local_empty` is a registered local fact consumed only``')
now=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(timespec='seconds')
text+='''
### 本轮检查点与续审入口

本文件是**阶段报告，不是全量审阅完成或流片签核报告**。由于全量RTL/TB/合同语义审阅尚需继续，且缺少xsim使大规模系统回归在本轮外部时间上限内未完成，按用户§7停在②-B子批边界。119行覆盖台账包括37 RTL、48活动TB、32合同、2支持头文件；“部分”不能当作无问题，“未审”文件只做了机械登记。

下一批从**FIR全文→动态基线→峰谷→IDAC/AMB叶子**继续；随后完成AMI/scheduler/SSW owner/在途/截止/释放协议、控制层与顶层全端口核对、48TB逐项+变异、32合同逐份、每ID家族语义、七孤立模块。跨层锚点脚本未覆盖省略文件名的`:NNN`继承引用；机械ID候选表包含历史/模块级ID，不得把828候选数当成319系统ID变化或551个缺RTL标签错误。25份合同版本依赖只提取登记，尚未完成逐依赖裁定。

资料：evidence/ledger.json、anchor_scan.json、anchor_failures.csv、id_presence.json/csv、contract_version_inventory.json、regression_results.json、mutation_results.json、gates/、compile/、fir_floating_ab/、spi_map_probe/、chip_spi_ab/。最小TB源码完整保留在各探针目录。原仓库和导出源文件不得修复；继续必须沿用固定hash及本轮输出目录。无需重新clone、切换版本或重做已完成检查。

已知事项状态：本基准是scheduler V1.8、AMI V1.15，没有任务C V1.9；tick248仍按用户已知未修复状态登记，不重复报新发现。P2S反压限制的文档/TB前提更新不在此基准，按用户说明属于进行中；未把它计入新发现。strict gate口径给出芯片30文件77条/全37文件计数，未把与“约222条”不同直接判为状态错误。三项旧CDC/锁存/X态审计不是本轮签核证据。

本轮没有给任一整份RTL或TB标“完成”：代码实读和变异范围已逐行标明，仍缺的合同比对/全异常路径必须继续。完整审阅仍需完成余下语义与回归裁定；若补齐xsim，可按原脚本进一步复核跨工具结果。
'''
text+='\n检查点时间：'+now+'。\n'
git=r'D:\Git\cmd\git.exe';clone=B/'zlcx'
head=subprocess.run([git,'-C',str(clone),'rev-parse','origin/main'],capture_output=True,text=True).stdout.strip()
status=subprocess.run([git,'-C',str(clone),'status','--porcelain','--untracked-files=all'],capture_output=True,text=True)
assert head=='d18c6954621e53e5a6505dd3a6c688c266d23839',head
assert status.returncode==0 and not status.stdout,status.stdout
changed=[]
for x in ledger:
    digest=hashlib.sha256((S/x['file']).read_bytes()).hexdigest()
    if x.get('sha256') and digest!=x['sha256']:changed.append(x['file'])
assert not changed,changed
(E/'final_readonly_check.json').write_text(json.dumps({'origin_main':head,'clone_porcelain':status.stdout,'source_scope_hash_differences':changed,'checkpoint':now},ensure_ascii=False,indent=2),encoding='utf-8')
text+='\n只读终检：origin/main仍为首行hash；原克隆git status为空；范围内源文件SHA256与初始台账无差异。\n'
toolinfo='''
| 实际工具 | 版本/状态 | 实际用途与限制 |
|---|---|---|
| Git | 2.54.0.windows.1 | clone/固定origin/main/core.autocrlf=false archive/只读状态检查 |
| bundled Python | 3.12.14 | 仓库skill门禁/lint、检查脚本、证据与台账；实际使用版本 |
| 系统Python | 3.8.5 | 仅环境检测，未用作主验证运行时 |
| Icarus / vvp | 11.0 stable，Debian官方包独立解包 | 48 TB -g2012 -Wall编译、37 RTL -g2005 -Wall编译、实际vvp/A-B/变异；未获得建议12版 |
| Git Bash | 5.3.9 | 入库shell入口与依赖静态核对 |
| WSL Debian | 11.6 x86_64 | 独立Icarus运行环境；不安装系统包 |
| Vivado 2022.2 xsim | 未找到 | 未运行三个原生xsim入口，不能声称复现xsim.log或综合/ASIC CDC签核 |
| Verilator | 未找到 | 未做verilator --lint-only |

仓库erie-verilog-generator按SKILL.md手动执行；本轮运行strict deliverable gate和verilog_lint external=none，没有verify/repair、源代码生成、formatter或自动修复。静态门禁和Icarus编译不等同实际综合；没有执行独立ASIC时序/CDC签核或全周期X审计。脚本自身的负对照不构成芯片功能正确性的证明。

'''
pos=text.index('## 2. 结论摘要');text=text[:pos]+toolinfo+text[pos:]
idx='''
| 编号 | 严重度 | 主层 | 结论 |
|---|---|---|---|
| F-005 | S1 | RTL | 真实Mode0 SPI读流提前一bit，leaf与chip均复现 |
| F-001 | S2 | TB | 4份注入构建缺calibration-loss valid驱动，正式FIR资格X |
| F-006 | S2 | TB | 芯片TB的SDO采样发生在negedge NBA更新前，掩盖F-005 |
| F-002 | S3 | 合同 | C13完整discard身份组多声明五个epoch端口 |
| F-003 | S3 | 矩阵·台账 | 177个明确文字不匹配引用及14个越界引用，按出现位置统计 |
| F-004 | S3 | 合同 | C13给纯组合Router声明不存在的注册式local-empty |

按严重度：S1 1、S2 2、S3 3、S4 0。按主层：RTL 1、TB 2、合同 2、矩阵·台账 1。跨层证据见各条，不重复计数。

'''
pos=text.index('## 3. 新发现');text=text[:pos]+idx+text[pos:]
r.write_text(text,encoding='utf-8')
out=B/'PPG_FULL_REVIEW_20261003.md';out.write_text(text.replace('# PPG 数字部分全量审阅报告（进行中）','# PPG 数字部分全量审阅阶段报告（未完成）'),encoding='utf-8')
print('REPORT',out,'LEDGER',len(ledger),'RUN_STATES',dict(collections.Counter(x['state'] for x in results)))
