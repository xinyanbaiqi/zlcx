from pathlib import Path
import json,csv,collections,datetime,subprocess,hashlib,re
B=Path(__file__).resolve().parent;E=B/'evidence';S=B/'snapshot'
COORD=Path(r'C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd39-7e50-7671-8810-299165a4df40')
now=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(timespec='seconds')
git=r'D:\Git\cmd\git.exe'
head=subprocess.check_output([git,'-C',str(B/'zlcx'),'rev-parse','origin/main'],text=True).strip()
status=subprocess.check_output([git,'-C',str(B/'zlcx'),'status','--porcelain','--untracked-files=all'],text=True)
assert head=='d18c6954621e53e5a6505dd3a6c688c266d23839' and not status,(head,status)
ledger=json.loads((E/'ledger.json').read_text(encoding='utf-8'))
assert len(ledger)==119
for x in ledger:assert hashlib.sha256((S/x['file']).read_bytes()).hexdigest()==x['sha256'],x['file']
ownership=list(csv.DictReader((COORD/'OWNERSHIP_4CHAT.csv').open(encoding='utf-8-sig',newline='')))
assert len(ownership)==119 and len({x['path'] for x in ownership})==119
assert {x['path'] for x in ownership}=={x['file'] for x in ledger}
subprocess.run([r'C:\Users\DAWN\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',str(B/'regression_audit.py')],check=True,stdout=(E/'regression_resume_listing.log').open('w',encoding='utf-8'))
runs=json.loads((E/'regression_results.json').read_text(encoding='utf-8'))
rows=[]
index={x['file']:x for x in ledger}
items={
'RTL':['端口与合同名称/方向/宽度/符号/语义','寄存器复位与释放','FSM可达/非法恢复/锁存/死锁','握手稳定/优先级/在途释放','运算符号/位宽/舍入/饱和','计数器边界/回绕','CDC条件与消费者','可综合结构/组合环','注释与代码一致','工具compile/AST/lint/gate'],
'TB':['真实比较与FAIL判据','变异抽查','验收ID激励/执行计数/覆盖语义','输入驱动/注入参数','超时/结束/容差','路径/参数硬编码','运行日志/入口脚本判据'],
'合同':['内部端口/正文/验收/修订一致性','RTL逐条一致性','版本与依赖','验收ID闭环','节号/行号引用']}
for o in ownership:
    if o['owner']!='A':continue
    x=index[o['path']]
    for item in items[o['layer']]:
        st='未审';evidence='';remaining='需要本组逐项语义核对'
        if item=='工具compile/AST/lint/gate':st='完成';evidence=str(E/'compile'/Path(o['path']).stem/'compile.log')+';'+str(E/'gates'/(Path(o['path']).stem+'.json'));remaining='工具项完成不代表整份RTL完成'
        elif item=='运行日志/入口脚本判据':st='部分';evidence=str(E/'compile'/Path(o['path']).stem/'run.log');remaining='全局复核最终横幅/FAIL/X/结束及外部截断，继续必要补跑'
        elif o['path'].endswith('PPG_CONTRACT_CLOSURE_MATRIX.md') and item=='节号/行号引用':st='部分';evidence=str(E/'anchor_scan.json')+';'+str(E/'anchor_failures.csv');remaining='全量继承式:NNN及语义预期/历史订正尚未完成'
        elif o['path'].endswith('PPG_ALIAS_MAPPING_TABLE.md') and item=='节号/行号引用':st='部分';evidence=str(E/'anchor_failures.csv');remaining='完整标签一致性/场景真实检查仍未完成'
        elif o['path'].endswith('TAPEOUT_FINAL_REVIEW_GUIDE.md'):st='部分';evidence=str(B/'PPG_FULL_REVIEW_20261002.md');remaining='已全文读过，仍需系统化逐项归类过时说法与实际证据'
        elif o['path'].endswith('ppg_control_top.v') and o['layer']=='RTL':st='部分';evidence=str(B/'PPG_FULL_REVIEW_20261002.md');remaining='仅抽读注入/idle/telemetry连线，继续Top全文与全端口/优先级核对'
        rows.append(dict(owner='A',path=o['path'],check_item=item,contract_or_id='',status=st,evidence=evidence,remaining=remaining,file_status=x['status']))
with (B/'coverage_A.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
todos=[
('X-001','B/C/A','F-001','4份启用注入TB实际场景资格X','已有leaf A/B确认；B检查4系统TB相关断言/场景，C核对FIR资格链，A管理必要集成探针','待专项复核'),
('X-002','D/A','F-005/F-006','SPI真实Mode0读位错位与TB NBA旧值采样','D独立核对原代码/四组SPI leaf对照/芯片采样变异日志；A保留原始证据并裁定去重','待D复核'),
('X-003','C/B/A','F-002/F-004','C13完整discard组与组合Router的合同矛盾','C主责C12/C13全文与叶子，B核对AMI实际discard/排空，A核验双方原文证据','待跨组复核'),
('X-004','A/B/C/D','F-003','177文字不匹配/14越界引用及剩余继承锚点','A全面机械+语义；其余组复核自身实际信号/标签，不按偏移修正','进行中'),
('X-005','D/A','F-007','芯片正文两路复位与V1.11实际单路冲突','D读合同全文核实同合同勘误许可；A保持S3不升级为未验证CDC S1','待D复核'),
('X-006','A','全局回归','既有后台48TB回归和3份外部3600秒截断','保留已有进程；重新核对run.rc/完整FAIL模式/X窗口/结束；不能当RTL死锁','进行中'),
('X-007','A/B/C/D','119覆盖','唯一主责与逐检查项合并','只读取得各组handoff/coverage/原始日志，缺证据或未完成项不得升级完成','进行中'),
('X-008','A/B/D','TOP/owner','Top/AMI/scheduler/SSW/chip跨组连线','A从实际Top端口/参数连线核查，B控制协议，D芯片约束；分别核对自己的生产者/消费者','待核查'),
('X-009','A/C/D','候选','discard翻转位对偶数事件可辨识性','尚缺真实系统事件与host轮询前提；读取合同并反驳，不计已确认新发现','未裁定'),
('X-010','A','孤立RTL','七个孤立模块完整语义/参数/复位及TB','已有编译和4TB完整运行；源码/TB全文语义未完成，未遗漏','待本组审阅')]
with (B/'cross_group_todo.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.writer(f);w.writerow(['id','owners','related','question','required_evidence','status']);w.writerows(todos)
h=[f'被审提交：`{head}`',f'# A组交接（{now}）','',
'四组共同约定/主责清单已读，原始任务已知事项沿用。A唯一总报告为本目录PPG_FULL_REVIEW_20261002.md；PPG_FULL_REVIEW_20261003.md是上轮同内容阶段副本，不作为新四组汇总的第二作者。共享snapshot/zlcx只读，其他组不得修改原报告/证据。',
f'输出根：`{B}`',f'handoff固定路径：`{B / "handoff_A.md"}`',f'逐检查项覆盖：`{B / "coverage_A.csv"}`',f'跨组待办：`{B / "cross_group_todo.csv"}`','',
'## 固定资源与工具','',f'快照：`{S}`；克隆：`{B / "zlcx"}`；origin/main仍固定、工作树为空、119范围文件SHA256与初始台账一致。没有fetch/pull/切分支/提交/推送。',
'Git D:/Git/cmd/git.exe 2.54.0.windows.1；bundled Python C:/Users/DAWN/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe 3.12.14；系统Python 3.8.5。WSL Debian 11.6。',
f'Icarus11.0 stable只读工具包：`{B / "toolchain/icarus11/usr/bin/iverilog"}`、`{B / "toolchain/icarus11/usr/bin/vvp"}`；lib：`{B / "toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl"}`。Windows不能直接执行Linux ELF，使用wsl.exe -d Debian -- <Linux绝对路径>；Linux路径为/mnt/c/Users/DAWN/...。iverilog必须-B上述lib；vvp用-M上述lib。',
'Vivado/xsim和Verilator未找到；已运行本仓库erie-verilog-generator analyze/validate的formatter-AST、strict gate、verilog_lint external=none；无verify/repair或formatter写源码。Python使用-B/PYTHONDONTWRITEBYTECODE=1和UTF-8。旧restricted shell曾setup refresh失败；PowerShell只读命令需现有工具的require_escalated auto-review，不能改写其他组目录。','',
'## 检查点与尚未完成','',
'37 RTL按-g2005 -Wall逐模块编译，48活动TB按-g2012 -Wall及精确依赖全部编译；19系统filelist+1芯片filelist+28单位TB_TABLE覆盖全部活动TB，2份legacy排除。37 gate/lint已有同提交证据，勿重复风格门禁。负对照编译3种错误均被检出。',
'上轮②-B完成：ADC数值叶子主要代码/部分CDC/SPI全文及少量合同，6项模块RTL变异均触发真实FAIL；并未把整份文件语义标完成。阶段报告与evidence/ledger.json有每文件实际范围；交给B/C/D不等于该文件完成。',
'锚点7403出现位置含重复；177明确文本不匹配（165Top声明+12K出处），14越界，6缺文件待裁定。忽略删除线旧引、区分Cxx:3/小数节号；尚未覆盖全部省略文件名:NNN与所有in-bounds语义。ID表828是候选（含模块/历史/范围），不得当真实系统ID计数或直接缺闭环报告。',
'A现接管22个唯一主责文件+全局119汇总/ID/端口/锚点/契约冲突。七孤立RTL全部归A，保留原任务。B/C/D的专项证据需要A读取源码、合同、原始日志后复核去重。','',
'## 既有发现：实际为七条','',
'共同约定/协调消息写F-001～F-006比最新报告早；F-007已在协调消息前核实并写入两份阶段报告，必须保留。此处是索引，详细原文/行号/反驳在总报告；各组应读原始证据再作独立裁定。','',
'| 编号 | 严重度 | 主责复核 | 内容与原始证据 |','|---|---|---|---|',
'| F-001 | S2 TB | B/C | 4注入TBcal-loss valid悬空，21合格点leaf正式资格X；evidence/fir_floating_ab/；disabled/tie0对照资格1，负期望fatal |',
'| F-002 | S3 合同 | C/B | C13 complete TXN_ID discard比overlap实际小组多5epoch；evidence/c13_port_evidence.json；清除只看generation，未升级S1 |',
'| F-003 | S3 台账 | A/各组 | 165Top声明引用错误+12K出处指向CDC+14越界；evidence/anchor_failures.csv与带负对照anchor_scan.json |',
'| F-004 | S3 合同 | C/B | C13 Router registered local-empty不存在且与C12纯组合条款冲突；全Router/AMI实例/AST已查 |',
'| F-005 | S1 RTL | D/A | SPI真实Mode0读流提前1bit；evidence/spi_map_probe/ physical FAIL0x0100 got1c expected0e；legacy/hypothesis通过38+128字节；仅外部假设副本，无修复入库 |',
'| F-006 | S2 TB | D/A | 原chip TB在negedge NBA前采旧SDO掩盖F005；evidence/chip_spi_ab/run.log仅采样移到posedge+1ns出现3FAIL，原TB6PASS |',
'| F-007 | S3 合同 | D/A | 芯片正文53/65/80/82/101仍两路reset_sync，与本合同25勘误及Top284/373单路实际架构冲突；本合同明文许可现有机制，未报S1 |','',
'六项变异：evidence/mutations/及mutation_results.json，S1冗余符号1031FAIL/校准offset1036/重构中心1042/PWC START清sticky4/Router复位2/FSC身份1；进程rc0仍有FAIL，必须看文本判据。SPI假设/采样变异副本只作A/B反驳；绝不把它们的通过当成入库RTL通过。','',
'## 原有全局回归（保留，不重启）','',
'统一exec session=22875；run_all.sh分4并行批次，额外fast session=96661已结束。每TB目录evidence/compile/<name>包含compile.log/compile.rc/sim.vvp/run.sh/run.log/run.rc/run.start/run.end。只有run.rc存在才结束；日志可能C stdio缓冲，不能据空文件判断time0死锁。原脚本每份外部wall-clock timeout3600；rc124必须归外部截断。','',
'上轮baseline_cross 5秒诊断副本推进到1768101500ps并通过JNT54，因此不是time0 delta循环；这尚不能排除之后的delta停滞，继续诊断时不得停止原进程。保存于evidence/compile/tb_ppg_control_top_baseline_cross/progress_probe.log。','',
'| TB | 状态 | rc | PASS行（按实际样式） | 日志 |','|---|---|---:|---:|---|']
for rr in runs:
    state=rr['state']
    if state=='finished' and rr['rc']==124:state='外部3600秒截断，未完成'
    elif state=='finished':state='原TB结束；不推定语义覆盖完成'
    h.append(f"| {rr['tb']} | {state} | {rr.get('rc','—')} | {rr.get('pass_lines','—')} | {E/'compile'/rr['tb']/'run.log'} |")
h+=['','## 已知事项与后续入口','',
'scheduler V1.8/AMI V1.15，不包含任务C V1.9；tick248已知，不重复新报。P2S反压前提文档/TB改动不在基准，按进行中，不写已落实。PRC04、N08/N04/P10、TRK01、C11/C14/C15条件豁免、D03冻结、5悬空输出、GFP未复核、旧CDC/锁存/X态审计、SPI仅3诊断读字节、芯片层无ID、7孤立、遗留_tmp filelist按原任务处理，须核实前提。',
'新范围为RTL功能签核准备；PVT、综合网表、电气延迟、Virtuoso后续，不以它们缺失暂停可做只读功能审阅。没有主责文件全文完成之前不能宣布全量功能正确。',
'本次先继续现有回归最终判据/工具差异诊断，再审A七孤立RTL+对应TB、Top全端口/参数/逻辑、5全局TB真实覆盖及5合同全文，完成全锚点/ID/台账语义。优先消化B/C/D每批已完成原始证据，避免等全部结束才汇总。',
'其他组不发消息；通过registry真实ID读取进度。A不能修改协调登记表。主责输出与handoff路径发布后读取并在cross_group_todo.csv登记，不要求用户传文件。','']
(B/'handoff_A.md').write_text('\n'.join(h),encoding='utf-8')
(E/'handoff_readonly_check.json').write_text(json.dumps({'time':now,'head':head,'status':status,'scope_file_count':119,'hash_differences':[]},ensure_ascii=False,indent=2),encoding='utf-8')
print('HANDOFF',B/'handoff_A.md','A_FILES',sum(o['owner']=='A' for o in ownership),'CHECK_ROWS',len(rows),'RUN_STATES',dict(collections.Counter(x['state'] for x in runs)))
