from pathlib import Path
from collections import Counter
import json,re
BASE=Path(__file__).resolve().parent
E=BASE/'evidence'
ledger=json.loads((E/'ledger.json').read_text(encoding='utf-8'))
allcounts=Counter()
chipcounts=Counter()
orphans={'ppg_dual_precision_top','ppg_digital_shell','ppg_digital_esd_shell','ppg_timing_sar9','ppg_timing_sar9_3200hz','ppg_timing_sar15','ppg_timing_sar15_3200hz'}
warnings=[]
for x in ledger:
    if x['layer'] not in ('RTL','TB'): continue
    p=Path(x['file'])
    d=E/'compile'/p.stem
    assert (d/'compile.rc').read_text().strip()=='0',x['file']
    x['status']='部分'
    x['checks']=['Icarus11 -Wall 编译/elaborate通过（RTL为-g2005；TB为-g2012）']
    x['remaining']='语义逐项、合同比对、变异抽查、回归完成判据尚未完成'
    log=(d/'compile.log').read_text(encoding='utf-8',errors='replace')
    warn=[l for l in log.splitlines() if 'warning:' in l.lower()]
    warnings+= [{'file':x['file'],'warning':l} for l in warn]
    if x['layer']=='RTL':
        j=json.loads((E/'gates'/(p.stem+'.json')).read_text(encoding='utf-8'))
        counts=j['delivery_issues_by_rule']
        allcounts.update(counts)
        if p.stem not in orphans: chipcounts.update(counts)
        x['checks']+=['仓库strict deliverable gate已运行，规则计数已记录','仓库verilog_lint external=none返回0']
    else: x['checks']+=['include与精确依赖可解析（来自入库filelist/TB_TABLE）']
(E/'ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2),encoding='utf-8')
(E/'compile_warnings.json').write_text(json.dumps(warnings,ensure_ascii=False,indent=2),encoding='utf-8')
(E/'gate_counts.json').write_text(json.dumps({'all37':dict(allcounts),'chip30':dict(chipcounts)},ensure_ascii=False,indent=2),encoding='utf-8')
r=BASE/'PPG_FULL_REVIEW_20261002.md'
text=r.read_text(encoding='utf-8')
start=text.index('| 文件 | 层 | 行数 | 状态 | 已做检查 |')
end=text.index('## 6. 回归对比',start)
tab=['| 文件 | 层 | 行数 | 状态 | 已做检查 / 剩余 |','|---|---|---:|---|---|']
for x in ledger:
    tab.append(f"| {x['file']} | {x['layer']} | {x['lines']} | {x['status']} | {'；'.join(x['checks']) or '仅登记'}；{x.get('remaining','全文语义审阅未完成')} |")
text=text[:start]+'\n'.join(tab)+'\n\n'+text[end:]
text+='''
### 检查点①：环境与自包含编译（已完成）

- 固定提交与仓库外导出完成；37 RTL / 48 活动TB / 32合同。两份legacy TB明确排除，另有2份`.vh`支持文件将在TB批次登记。
- Windows Git 2.54.0.windows.1；bundled Python 3.12.14；系统Python 3.8.5；Git Bash 5.3.9；WSL Debian 11.6。
- Vivado/xsim、Verilator未找到。独立Icarus 11.0（stable）从Debian官方源获取，仅解包到toolchain/，版本全文与下载SHA256保存于 evidence/toolchain*。未修改系统安装与全局PATH。
- 48/48活动TB逐份编译/elaborate返回0；19系统filelist、1芯片filelist、28模块TB_TABLE依赖全部使用。37/37 RTL按Verilog2005逐顶层编译返回0。
- 负对照：good编译0、运行0并打印REAL_COMPARISON_PASS；syntax_bad=2、missing include=1、nonexistent port=1。故意错误恰好三份编译失败。
- 编译没有FAIL发现；悬空输入及其他警告尚需按实际消费链和合同逐项裁定，不把warning直接认定为错误。
- 全37份运行仓库strict deliverable gate与verilog_lint；后者全部返回0。strict gate的既有风格积压仅汇总，不能据此认定RTL功能已通过。
- 本次没有使用remote/Vivado路径。skill预检缺erie-remote-ssh；用户明确指定本地工具并允许记录缺失，故仅执行本地只读审阅，未安装skill依赖。
- 自写驱动首次因Windows文本写入CRLF失败，已用显式字节LF更正，重新编译成功；首次驱动失败不属于仓库错误。
- 48份Icarus回归已启动，尚未完成。对比将直接读取每份run.log；无xsim.log意味着无法声称xsim复现。

| 规则 | 芯片层级30份RTL | 全部37份RTL |
|---|---:|---:|
'''
for code in sorted(allcounts): text+=f'| {code} | {chipcounts[code]} | {allcounts[code]} |\n'
text+='\n下一批：RTL叶子模块逐项语义审阅。后续待做：集成层/顶层、TB逐项、合同逐份、跨层锚点/ID、回归结果裁定、孤立模块、最终汇总。\n'
r.write_text(text,encoding='utf-8')
print('GATE chip30',dict(chipcounts),'all37',dict(allcounts))
print('WARNINGS',len(warnings))
for x in warnings:
    if 'dangling input' in x['warning'].lower(): print(x['file'],x['warning'].split(': warning:')[-1])
