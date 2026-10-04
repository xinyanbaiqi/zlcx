from pathlib import Path
import json,re,runpy,datetime
B=Path(__file__).resolve().parent;E=B/'evidence';p=B/'PPG_FULL_REVIEW_20261002.md'
t=p.read_text(encoding='utf-8')
if '本轮分工状态：B、C、D' not in t:
 t=t.replace('## 1. 基本信息\n\n','## 1. 基本信息\n\n本轮分工状态：B、C、D已完成各自主责分组并交稿；A负责独立反驳复核、全局追溯、合并覆盖台账和最终原始日志核对。分组交稿不等于整体报告完成。本轮A续做已实际完成四链机械核对、46家族语义抽查、Top165边界端口/TOP01-24及1860台账端口名称方向检查；人工语义限度和未终结长回归见§5、§6。\n\n',1)
 t=t.replace('没有verify/repair、源代码生成、formatter或自动修复。','另已实际运行analyze-existing --no-state并核对Top八门禁输出；没有verify/repair、源代码生成、写回格式化修改或自动修复。')
 t=t.replace('先通过错误行号、错误方向、缺端口及越界四个负对照；','先通过错误行号、错误方向、缺端口及越界四个负对照；随后补充同名注释伪匹配负对照，并用实际AST声明跨度排除假匹配；')
 heading='## A 本批交付与后台任务：2026-10-04'
 if heading not in t:
  t+='\n'+heading+'\n\n本批新确认F048—F050及F003的64条子模块锚点补充已写入主表，S1/S2置前；119个固定范围文件hash复核通过，Git状态空，origin/main锁定hash未变化。当前阶段副本为PPG_FULL_REVIEW_20261004.md，源报告PPG_FULL_REVIEW_20261002.md由A唯一维护，早期日期副本及历史检查点不得作为最新进度。\n\n'
  t+='原回归与native恢复进程继续执行；watch_external_caps_A.py仅恢复真实墙钟截断；watch_report_results_A.py仅在真实终态变化后重读每份原始run.log、核对基线及横幅并刷新§5/§6/交接，不根据旧summary.tsv或TB自身的PASS宣称语义正确。实际活动状态和刷新事件分别保存在evidence/vpi_recovery_state.json、external_cap_retry_state.json、report_watch_state.json及report_watch_events.json；运行器的状态/FAIL/截断/缺组成员负对照已保存。新的FAIL、PASS数量变化或空最终横幅将列为待人工裁定异常，未自动编造新发现或宣布全量完成。\n'
 p.write_bytes(t.replace('\n','\r\n').encode('utf-8'))
runpy.run_path(str(B/'finish_closure_checkpoint_A.py'))
text=p.read_text(encoding='utf-8')
assert text.splitlines()[0]=='被审 origin/main HEAD：`d18c6954621e53e5a6505dd3a6c688c266d23839`'
assert (B/'PPG_FULL_REVIEW_20261004.md').read_bytes()==p.read_bytes()
print('CURRENT_STAGE_DELIVERABLE',B/'PPG_FULL_REVIEW_20261004.md')
