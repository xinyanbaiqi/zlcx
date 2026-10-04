from pathlib import Path
import json,datetime,collections,re
B=Path(__file__).resolve().parent;E=B/'evidence';p=B/'handoff_A.md'
if not (E/'handoff_A_before_20261004h.md').exists():(E/'handoff_A_before_20261004h.md').write_bytes(p.read_bytes())
ledger=json.loads((E/'ledger.json').read_text(encoding='utf-8'));runs=json.loads((E/'regression_results.json').read_text(encoding='utf-8'))
now=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(timespec='seconds')
report=(B/'PPG_FULL_REVIEW_20261002.md').read_text(encoding='utf-8');confirmed=[];suspected=[]
for m in re.finditer(r'^### (F-\d+)(?:：| — )[^\n]+\n(.*?)(?=^### F-|^## 4\.)',report,flags=re.M|re.S):
    sev=re.search(r'S[1-4]',m[2])
    if sev:(suspected if '置信度：疑似' in m[2] else confirmed).append(sev[0])
counts=collections.Counter(confirmed)
unfinished=sum(r['state']!='finished' for r in runs)
recovery=json.loads((E/'vpi_recovery_state.json').read_text(encoding='utf-8'))
anchor_counts=collections.Counter(r['status'] for r in __import__('csv').DictReader((E/'anchor_failures.csv').read_text(encoding='utf-8-sig').splitlines()))
source_summary=json.loads((E/'global_closure_20261004/source_adjudication_summary_A.json').read_text(encoding='utf-8')) if (E/'global_closure_20261004/source_adjudication_summary_A.json').exists() else {'reviewed_rows':628,'states':{}}
text=f'''被审提交：`d18c6954621e53e5a6505dd3a6c688c266d23839`
# A 当前交接（{now}）

总报告：{B/'PPG_FULL_REVIEW_20261004.md'}。A唯一维护源报告：{B/'PPG_FULL_REVIEW_20261002.md'}；Oct4版本是最新阶段副本。Oct3版本及原交接为历史，勿用其计数/进度。
快照snapshot与克隆zlcx只读；119范围文件SHA256和固定origin/main保持不变，无源码修复、提交、推送。

已独立核实合并{len(confirmed)}项确认发现（{dict(counts)}）及{len(suspected)}项疑似F-044，不把疑似计入确认。F-035真实Top的完成/abort碰撞阻碍重启、F-023实际SPI STOP碰撞、F-005 Mode0读错位、F-020周期重试与F-019 discard身份是优先项。每条真实源码行、反驳和原始日志见总报告。新增F-045确认26文件完整性摘要23项不符；F-046同号ID语义错位；F-047SSW增量与基础标签关系未明示。141绑定及26原始Git blob已核对。
F-044（B-016）需要格外保守：C10:712-714明文限制控制来自Top且RUN期间锁存；叶子去使能在合法Top运行中不可达。A未确认B声称的叶子验证缺口。F-011仅接受B-004中的5001拍容差问题；Q3完成另由系统链测试覆盖，未计全局缺口。

覆盖状态：{dict(collections.Counter(r['status'] for r in ledger))}，范围119文件全部进入审阅但不能称全部检查完成。A逐项表coverage_A.csv（22主责文件），跨组总表evidence/ledger.json；完整逐文件状态和缺项在报告§5。B/C/D本轮均已交稿：B final状态2026-10-04已实际查询为idle/completed，19候选均由A核对并按疑似/缩窄范围处理；C/D语义审阅已交付，动态闭环及工具限制仍保留。不得用“已读全文”推导ASIC签核或全部动态验收。

回归当前状态：{dict(collections.Counter(r['state'] for r in runs))}，全部48原TB编译成功；19系统、1芯片、28模块，2个legacy已退役不纳入。只按每份原始run.log/最终横幅裁定，不按summary.tsv。diag已5 PASS、baseline-cross已75 PASS、FIR-tail已80 PASS，均与基线PASS计数一致，无FAIL。
旧回归续跑session79583的实际活跃进程数为{recovery['old_active']}，勿停止仍在执行的进程。native恢复watcher session57044只处理旧DrvFS错误；八个用例之前因镜像内VPI绝对库路径不可读而未执行，错误已完整保存。新恢复session28324/resume_vpi_paths.py仅重定位六条库路径，已证明逆变换原镜像完全相同、七个VPI工具库hash相同、真实原ADC TB正对照PASS及缺库负对照失败；当前native运行{recovery['running_native']}，排队{recovery['queued']}。evidence/vpi_recovery_state.json记录真实队列，evidence/resume_attempts保留所有错误尝试。不重启原在跑进程，不将环境失败当设计FAIL或完成。

工具Icarus11.0、Git2.54、Python3.12.14、WSL Debian11.6；无Vivado/xsim或Verilator。native_probe.py通过Windows读取source并stdin tar到Linux /tmp，支持.vh；短TB/变异在仓库外。WSL/mnt/c新读取不可靠，勿直接从那里发起新仿真。
37 RTL真实编译及strict gate已跑，style与用户已知例外只计数。芯片30 strict77，其中VG01046/VG0311，完整37规则计数在报告§7。repo erie-verilog-generator手动analyze/validate，未调用verify/repair。

机械锚点v2扫描9247处：1696字面不符只是候选（大量合法组表头），F-003保留251已确认失配及14越界（原177加C09六条依赖、AMI三处标签漂移、64处子模块声明、C02一处公式Source）；候选不得自动提升。复用Erie AST核对516个明确单端口声明锚点，287字面匹配、229失配；含同名注释伪匹配的五类负对照通过。C02的33个Source已人工逐行裁定：32含同名端口、1引用297空行（公式真实311），只补充F003，不重报1593已明示的I/O表登记缺口。ID v2含838历史/模块/系统/子ID候选不是约319系统验收总数；全量四链表已合并745个逐ID语义记录，剩余93候选按11家族裁定，全部46家族有语义样本。Top165端口及TOP01-24语义核对、17个不同标签候选逐项裁定、141版本绑定/26摘要已完成。F048合同only四个诊断消费者冲突、F049完整INJ有限错误身份逃逸变异、F050 SID11旧不可达别名，证据已写总报告。

后续：等待{unfinished}份剩余原回归终态并更新§6；9247锚点的分组/缺省引用仍未逐条语义签核，其余G-FP cluster独立逐字段核对仍受已知事项限制。旧long10的21600秒外部墙钟上限可能先于TB固有10秒仿真结束；外部上限保护watch_external_caps_A.py实际session11312已运行，只在真实rc124且旧进程结束后保留日志，待容量允许时从头native完整重跑（86400秒外部限额），不能把外部截断当RTL死锁或通过。原回归session79583、native回归28324不要停止。另有watch_report_results_A.py持续检测真实终态变化，调用已做负对照的原始日志核对/报告刷新，记录report_watch_state/events；它不替代未完成的人工语义裁定。更新报告和handoff时用当前脚本，不运行早期checkpoint恢复旧状态。当前总报告仍“进行中”。
'''
text=text.replace('251已确认失配及14越界（原177加C09六条依赖、AMI三处标签漂移、64处子模块声明、C02一处公式Source）',f"{anchor_counts['text_mismatch']}已确认失配及{anchor_counts['out_of_bounds']}越界（各批逐项原文与Source裁定见anchor_failures.csv及global_closure_20261004）")
text=text.replace('C02的33个Source已人工逐行裁定：32含同名端口、1引用297空行（公式真实311），只补充F003，不重报1593已明示的I/O表登记缺口。',f"{source_summary['reviewed_rows']}个Source已人工逐项裁定，状态{source_summary['states']}；当前各批证据见source_adjudication_summary_A.json。C05全部67输出切片与规范Erie AST一致；C24复位名不一致F051静态确认，不据此声称硬件复位缺陷。")
text+='\nOct4晚间实际补完：剩余864 Source、C03两处歧义已裁定，当前1860/1860 Source工作项有证据，0待办；799处规范默认位宽/41明示符号属性一致，4个公开epoch参数缺失并入既有F024；6个缺文件候选逐项裁定，3个实际是缩写/换行的真实文件但索引失效，3个外部历史handoff无法读取。Erie canonical实例helper实际核对39实例/2168命名关联，0输入漏接/开路/未知或重复formal，2024根plain net默认位宽一致，106 clock/reset关联原行有表。另4个孤立timing实例缺少可用AST叶子端口元数据，真实源码/编译/原TB存在，保留工具限度。证据global_closure_20261004/static_residual_disposition_A.json及canonical_instance_crosscheck_A.json。\n'
cap=json.loads((E/'external_cap_retry_state.json').read_text(encoding='utf-8'))
text+='\n外部上限实际状态：'+str(cap)+'\n'
text+='\n最终报告实际终态门禁final_report_if_ready_A.py已接入报告刷新：仅48完整原TB正常结束、横幅齐、无FAIL且有基线的PASS数一致才结束交付；7个错误终态负对照通过。Source待办已清零，非Source逐字语义/G-FP项目逐字段/ASIC工具限度及F044保留，不假称全签核。任何新异常终态需人工裁定，自动刷新不得升级为已确认功能错误。\n'
p.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
print('HANDOFF_UPDATED',str(p),now)
