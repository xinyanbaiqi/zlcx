from pathlib import Path
import subprocess, tarfile, hashlib, json

BASE = Path(__file__).resolve().parent
REPO = BASE / 'zlcx'
EXPORT = BASE / 'snapshot'
GIT = r'D:\Git\cmd\git.exe'
HASH = 'd18c6954621e53e5a6505dd3a6c688c266d23839'
OUT = BASE / 'evidence'
OUT.mkdir(exist_ok=True)
EXPORT.mkdir(exist_ok=True)
assert subprocess.check_output([GIT, '-C', str(REPO), 'rev-parse', 'origin/main'], text=True).strip() == HASH
with (BASE / 'snapshot.tar').open('wb') as f:
    subprocess.run([GIT, '-C', str(REPO), '-c', 'core.autocrlf=false', 'archive', HASH], stdout=f, check=True)
with tarfile.open(BASE / 'snapshot.tar') as tf:
    tf.extractall(EXPORT, filter='data')
paths = sorted(list(EXPORT.glob('rtl/**/*.v')) + list(EXPORT.glob('contracts/*.md')))
ledger = []
for p in paths:
    rel = p.relative_to(EXPORT).as_posix()
    layer = '合同' if rel.startswith('contracts/') else ('TB' if p.name.startswith('tb_') else 'RTL')
    data = p.read_bytes()
    blob = subprocess.check_output([GIT, '-C', str(REPO), 'show', HASH + ':' + rel])
    assert blob == data, rel
    ledger.append(dict(file=rel, layer=layer, lines=len(data.decode('utf-8-sig').splitlines()), sha256=hashlib.sha256(data).hexdigest(), status='未审', checks=[]))
(OUT / 'ledger.json').write_text(json.dumps(ledger, ensure_ascii=False, indent=2), encoding='utf-8')
report = [f'被审 origin/main HEAD：`{HASH}`', '', '# PPG 数字部分全量审阅报告（进行中）', '', '审阅日期：2026-10-02（Asia/Shanghai）。独立只读审阅；原克隆未改动。', '', '## 1. 基本信息', '', f'- 固定克隆：`{REPO}`', f'- 字节一致导出副本：`{EXPORT}`', '- 导出使用 git -c core.autocrlf=false archive；范围内逐文件与 git show 比较相等。', '- 工具环境与检查日志保存在 evidence/；仿真结果尚未产生。', '', '## 2. 结论摘要', '', '尚未完成审阅；当前无可上报的已确认发现。不得将未审或工具未运行理解为通过。', '', '## 3. 新发现', '', '待分批填入。', '', '## 4. 已知事项状态核实', '', '待分批填入。', '', '## 5. 覆盖台账', '', '| 文件 | 层 | 行数 | 状态 | 已做检查 |', '|---|---|---:|---|---|']
for x in ledger:
    report.append(f"| {x['file']} | {x['layer']} | {x['lines']} | 未审 | 仅字节一致性与范围登记 |")
report += ['', '## 6. 回归对比', '', '未运行。', '', '## 7. 方法与检查点', '', '已完成固定提交与字节一致性导出，接下来读取背景、检查环境与所有TB自包含编译。']
(BASE / 'PPG_FULL_REVIEW_20261002.md').write_text('\n'.join(report)+'\n', encoding='utf-8')
print('HASH', HASH)
print('FILES', len(ledger))
for layer in ['RTL', 'TB', '合同']:
    subset = [x for x in ledger if x['layer']==layer]
    print(layer, len(subset), sum(x['lines'] for x in subset))
print('REPORT', BASE / 'PPG_FULL_REVIEW_20261002.md')
