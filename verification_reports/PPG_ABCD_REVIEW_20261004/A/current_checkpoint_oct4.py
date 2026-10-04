from pathlib import Path
import json,collections,datetime,re,hashlib,subprocess,csv
B=Path(__file__).resolve().parent;E=B/'evidence';S=B/'snapshot';p=B/'PPG_FULL_REVIEW_20261002.md';t=p.read_text(encoding='utf-8')
now=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(timespec='seconds')
rows=json.loads((E/'regression_results.json').read_text(encoding='utf-8'));states=collections.Counter(r['state'] for r in rows)
start=t.index('## 6. 回归对比');end=t.index('## 7.',start)
new='## 6. 回归对比（当前检查点 '+now+'）\n\n'
new+=f"48份活动TB均实际编译/elaborate返回0；当前实际设计仿真结束{states['finished']}份、运行{states['running']}份、排队{states['pending']}份、因环境失败而尚未执行{states['environment_failed']}份、外部墙钟截断待完整重跑{states['external_interrupted']}份。使用Icarus11，未获得xsim；19系统/芯片依原脚本^PASS空格口径、模块按实际PASS样式，对比每份原始run.log及最新入库基线/横幅，不使用summary.tsv。运行0/横幅一致不证明覆盖充分；发现表已记录逃过原TB的实际错误。\n\n"
new+='| TB | 当前状态 | rc | PASS行 | 系统基线PASS | FAIL标记 | 日志结论 |\n|---|---|---:|---:|---:|---:|---|\n'
for r in rows:
 state=r['state'];finished=state=='finished';rc=str(r.get('rc','—'));passes=str(r.get('pass_lines','—'));baseline=str(r.get('baseline') or '未给逐行数');fails=str(len(r['fail_lines'])) if finished else '—'
 if finished:
  verdict='FAIL/运行未正常结束' if r['rc']!=0 or r['fail_lines'] else '原TB横幅已核对；语义限度见发现表'
  if r['baseline'] is not None and r['pass_lines']!=r['baseline']:verdict+='；PASS数量变化需裁定'
  if r['tb']=='tb_ppg_chip_digital_top':verdict+='；真实Mode0采样对照FAIL，F-005/006'
 else:verdict='固定版本继续运行，未作通过结论' if state=='running' else r.get('reason','等待运行；旧中断日志不作本次结果')
 new+=f"| {r['tb']} | {'完成运行' if finished else '运行中' if state=='running' else '环境未执行' if state=='environment_failed' else '外部截断/待重跑' if state=='external_interrupted' else '排队'} | {rc} | {passes} | {baseline} | {fails} | {verdict} |\n"
new+='\n原始日志位于evidence/compile/<TB>/run.log，run.rc/start/end保留实际状态。此前3600秒外部wall-clock截断只表示未完成，不是TB内部watchdog或RTL死锁；旧记录保留evidence/resume_attempts/。2026-10-04补跑每份上限21600秒并最多4份长场景同时运行，未缩短时钟/样本/参数。WSL /mnt/c 新读取曾失败；错误日志完整保留。转移原sim.vvp后，其六条vpi_module绝对路径仍指向不可读取的目录，导致八份用例尚未执行设计便退出；不能据非零rc将它们算作已完成设计仿真。现仅在仓库外副本重定位这六条仿真器库路径，逆变换与原镜像字节完全相同，原RTL/TB及其余仿真指令不变；原工具包与native七个VPI二进制SHA256逐个相同。真实ADC捕获原TB恢复PASS、删除system库负对照失败，证据evidence/vpi_relocation_controls/。恢复脚本resume_vpi_paths.py保留失败日志并按四并发继续，不重启WSL或中断现有作业。短对照与原回归日志分目录，不混合统计。\n\n'
new+='2026-10-04本批另启动外部上限保护watch_external_caps_A.py：只在实际run.rc=124且原进程已写run.end后保留完整旧日志，等待现有队列及四并发容量后从头执行原TB，外部限额扩大到86400秒。它不终止现有仿真、不改TB内部watchdog、不改变DUT/激励；五个状态判别负对照已通过。rc124单列external_interrupted，未计入完成/通过。当前状态见evidence/external_cap_retry_state.json；该运行器只恢复仿真，不自动完成尚未审定的语义报告。\n\n'
t=t[:start]+new+t[end:]
start=t.index('## 4. 已知事项');end=t.index('## 5.',start)
known='''## 4. 已知事项状态核实

当前未确认需要另编号的“已知事项状态有误”。下列已核实内容按用户已知事项排除；其余风险保留于逐文件台账，未自动转为新发现。

| 已知事项 | 固定版本所见 / 本轮处理 |
|---|---|
| tick-248 / scheduler V1.9 | 基准为V1.8，未包含V1.9修复；边界问题仍按用户已知项，不重复编号 |
| P2S三遥测反压错拍及前提订正 | 本基准未包含所述后续合同/断言订正，按进行中事项；packer局部正确不抵消AMI错拍，不新增原问题 |
| RTL风格门禁、pad例外 | 芯片30 RTL本次strict计数77，其中VG010=46/VG031=1；规则版本/口径与约222不同不构成状态错误。全部37规则计数见§7，不逐条列风格 |
| PRC-04 / TRK-01 / N08 / N04 / P10 | 按接受策略、结构或观察项处理；新F-016/017是其他PRC监视器问题，F-013为独立CCC-22，不重报原接受项 |
| C11/C14/C15 generation discard豁免 | START需empty及叶子valid父链已交叉核对，保留有条件豁免；F-002/004/008为不同接口/文档事实 |
| SSW cause22 D03、五组悬空输出 | 按模拟前提冻结及glue-top设计处理；新F-035是匹配完成被吞，cause21为实际恢复结果，不使用D03情景 |
| SPI38字节原TB只回读3字节 | 不重复报覆盖数量；本轮逐项静态核对38读字节/全部shadow及写副作用，独立物理读探针确认F-005 |
| 芯片层无验收ID/G-FP台账、七孤立模块 | 保持既有架构范围与处置未定；七孤立RTL及四对应TB已审内部行为，不赋予正式集成资格 |
| §13.1旧快照、G-FP其余批次未独立复核、旧CDC/锁存/X审计 | 不作为现行完整签核；本轮机械候选与逐文件语义限度单列，未把旧快照数量变化重复编号 |
| Top q3修订记录 / _tmp_v13_filelist.f /旧本机路径指南 | 保留用户已知注释/遗留文件状态，不新增风格发现；legacy明确退役两TB排除 |

'''
t=t[:start]+known+t[end:]
start=t.index('## 7. 方法与检查点');body=t.index('### 检查点①',start)
method='''## 7. 方法与检查点

当前采用固定Git导出、真实Icarus逐TB编译/运行、仓库skill严格门禁与独立lint、逐模块/合同/TB语义审阅以及公开端口反例/变异。没有应用修复、生成RTL、提交或推送。所有脚本、编译物及最小TB均在仓库外，关键探针源代码与实际命令保存在evidence对应目录，可复现；详见各条证据索引。

机械脚本先做已知错误负对照：真实编译器的语法/缺include/不存在端口三负例；锚点的错文字、缺文件、越界、旧引用被当前引用覆盖和中途子文件歧义；ID缺定义/RTL标签/TB文本/索引四缺边与完整、紧邻中文、展开范围；日志判据的普通FAIL、JNT status=FAIL、最终TB_FAIL、带时戳FAIL及FATAL。机械通过只证明所实现的识别项，不证明语义正确。

全矩阵/别名9247个引用出现位置（含范围/重复）已机械扫描：5144仅文件/边界、525预期字面匹配、184历史Source已由当前覆盖、22节号/歧义、1656缺省文件名语境歧义、1696字面不符候选、14越界、6缺文件候选。大量合同Source引用本来就是组标题/位段表，不要求端口字面出现，因此1696不能直接当缺陷数；F-003只保留已逐项确认的251文字失配（原177、C09六条依赖引用、AMI三处标签漂移、64处子模块声明和C02一处公式Source）及14越界汇总。复用Erie AST的516条单端口声明核对含287字面匹配、229失配，含同名注释伪匹配的五种负对照已通过；C02全部33 Source行另逐行裁定为32字面匹配/1公式引用失效。它们不替代无明确端口名的组引用语义签核。bounds-only和缺省语境尚待完整人工解释。详情anchor_scan_v2.json、anchor_failures_v2.csv及global_closure_20261004/port_declaration_anchors.csv/C02_source_rows_33.json，已知失效锚点anchor_failures.csv。

版本与完整性新增全量检查：141条当前依赖源声明、26份manifest摘要均按真实文件/行/字节核对，中文及句尾版本解析正例、错误版本/路径负例先通过；M01只替换自身digest字段。26份固定Git原始blob与导出字节完全一致，排除CRLF归一化伪差异。确认23摘要不符（F-045）、同号需求映射错位（F-046）及SSW增量/基础规范标签未明示关系（F-047）；不因目标header V1.10便自动认定其sole-current V1.9基础绑定非法。

验收ID机械表id_presence_v2.json/csv覆盖全部合同表列/RTL标签/TB文本/矩阵别名表列，838个含模块、系统、历史和台账子项的候选不等于约319系统ID；缺边只是候选，不能据文本缺少标签判缺功能。C组355合同表列ID、B组312定义及19家族抽查、D组本地主责ID/端口/版本已逐项保存。B/C/D本轮均已交稿；A负责跨组裁定、Top与全矩阵和长回归终态。真实检查与无需RTL锚点理由必须语义对照，全文阅读不等于所有动态验收完成。

A五份系统TB关键抽查：smoke完整原TB错误TOP-18期望触发SMOKE_TB_FAIL errors1；diag/longrun原RAW12片段分别拒绝RED/IR不足、时长不足和watchdog，long10原计数/sticky片段拒绝丢失2、重复、饱和及8类sticky；robust两个原监视器最小A/B揭示F-016/017。后三份与robust为原比较片段，未声称完整DUT变异回归通过。SSW/PWC功能反例A独立重跑，全部结果按真实比较和日志裁定，不能用rc0代替TB通过。

以下为逐批历史记录，保留过程与当时限度；最新状态以§2、§5、§6及本节前述为准，早期“下一批/未审/待做”不作为当前状态。

'''
anchor_counts=collections.Counter(r['status'] for r in csv.DictReader((E/'anchor_failures.csv').read_text(encoding='utf-8-sig').splitlines()))
method=method.replace('251文字失配（原177、C09六条依赖引用、AMI三处标签漂移、64处子模块声明和C02一处公式Source）',str(anchor_counts['text_mismatch'])+'文字失配（分项按当前anchor_failures.csv及各批Source裁定表）')
source_summary_path=E/'global_closure_20261004/source_adjudication_summary_A.json'
if source_summary_path.exists():
    source_summary=json.loads(source_summary_path.read_text(encoding='utf-8'))
    method=method.replace('它们不替代无明确端口名的组引用语义签核。',f"累计另有{source_summary['reviewed_rows']}条Source已逐项人工裁定，Source待办0、两处C03歧义已裁定，详细分类与各批证据见global_closure_20261004/source_adjudication_summary_A.json。另对799处显式默认位宽及41处明示符号属性核对一致，4处参数名绑定缺失并入F024；6个缺文件候选均已裁定（3处缩写/跨行文字指向真实文件但索引失效并入F003，3处外部历史handoff确未入库）。证据分别为contract_width_crosscheck_A.json、grouped_width_manual_rulings_A.json、missing_file_candidate_adjudication_A.json。它们不替代非Source缺省引用的全部逐字核实或G-FP时序/CDC项目签核。")
t=t[:start]+method+t[body:]
if '## 当前日期检查点：2026-10-04f' not in t:t+='\n## 当前日期检查点：2026-10-04f\n\n五份A系统TB关键变异已完成并限定抽查范围；当前119文件全部已进入语义审阅，仍有部分要求/跨组动态验收未闭环。最新覆盖状态及36/4/8运行状态见§5/§6。C、D已交付本轮分组审阅，B尚在收尾；总报告仍为进行中，不能宣布全量完成。\n'
p.write_bytes(t.replace('\n','\r\n').encode('utf-8'))
git='D:/Git/cmd/git.exe';c=B/'zlcx';head=subprocess.run([git,'-C',str(c),'rev-parse','origin/main'],stdout=subprocess.PIPE,check=True).stdout.decode().strip();status=subprocess.run([git,'-C',str(c),'status','--porcelain'],stdout=subprocess.PIPE,check=True).stdout.decode();assert head=='d18c6954621e53e5a6505dd3a6c688c266d23839' and status=='',(head,status)
ledger=json.loads((E/'ledger.json').read_text(encoding='utf-8'));assert all(hashlib.sha256((S/r['file']).read_bytes()).hexdigest()==r['sha256'] for r in ledger)
(E/'readonly_checkpoint_20261004f.json').write_text(json.dumps({'time':now,'origin_main':head,'git_status':status,'scope_hashes_unchanged':len(ledger),'regression_states':dict(states),'coverage_states':dict(collections.Counter(r['status'] for r in ledger))},ensure_ascii=False,indent=2),encoding='utf-8')
latest=B/'PPG_FULL_REVIEW_20261004.md';latest.write_bytes(p.read_bytes())
print('CURRENT_REPORT',str(latest),'states',dict(states),'coverage',dict(collections.Counter(r['status'] for r in ledger)),'READONLY',head)
