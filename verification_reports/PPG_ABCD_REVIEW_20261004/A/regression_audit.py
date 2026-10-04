from pathlib import Path
import json,re,collections,datetime
B=Path(__file__).resolve().parent; S=B/'snapshot'; E=B/'evidence'
manifest=json.loads((E/'compile_manifest.json').read_text(encoding='utf-8'))
print('MANIFEST TYPE',type(manifest).__name__)
table={}
for line in (S/'tools/run_unit_tb_regression.sh').read_text(encoding='utf-8').splitlines():
    if line.strip().startswith('"tb_'):
        parts=line.strip().strip('"').split('|'); table[parts[0]]=parts[3]
baseline={}
for line in (S/'verification_reports/REGRESSION_BASELINE_20260930.md').read_text(encoding='utf-8').splitlines():
    cells=[c.strip().strip('`') for c in line.split('|')]
    if len(cells)>4 and cells[1].startswith('tb_'):
        if re.match(r'\d+\s*/\s*\d+$',cells[3]): baseline[cells[1]]=int(cells[3].split('/')[0])
        elif cells[1]=='tb_ppg_chip_digital_top': baseline[cells[1]]=6
rows=[]
def failures(log):
    return [l for l in log.splitlines() if re.search(r'^FAIL|^\[FAIL\]|^\[\d+\] (?:[A-Z0-9-]+ )?FAIL|ERROR:|FATAL|\bstatus=FAIL\b|\b[A-Z0-9_]*_TB_FAIL\b',l)]
controls=[failures(t) for t in ['PASS TEST\nJNT_BASELINE status=PASS','FAIL test','JNT_BASELINE checked=51 status=FAIL','LONGRUN_TB_FAIL error_count=1','[12] TEST FAIL','FATAL: known error']]
assert [len(x) for x in controls]==[0,1,1,1,1,1],controls
(E/'regression_log_negative_controls.json').write_text(json.dumps(controls,ensure_ascii=False,indent=2),encoding='utf-8')
resume={x['tb']:x['restart_utc'] for x in json.loads((E/'regression_resume_attempts.json').read_text(encoding='utf-8'))} if (E/'regression_resume_attempts.json').exists() else {}
iso=lambda x:datetime.datetime.fromisoformat(x.strip().replace('Z','+00:00'))
for d in sorted((E/'compile').iterdir()):
    if not d.name.startswith('tb_'): continue
    rcfile=d/'run.rc'; logfile=d/'run.log'
    if not rcfile.exists() or not re.fullmatch(r'-?\d+',rcfile.read_text().strip()):
        active=rcfile.exists() and rcfile.read_text().strip() in ('RUNNING_RESUMED','RUNNING_NATIVE_RECOVERY','RUNNING_NATIVE_CAP_RETRY')
        pending_vpi=rcfile.exists() and rcfile.read_text().strip()=='PENDING_VPI_RECOVERY'
        if not active and not pending_vpi and (d/'run.start').exists():active=d.name not in resume or iso((d/'run.start').read_text())>=iso(resume[d.name])
        rows.append(dict(tb=d.name,state='running' if active else 'pending',baseline=baseline.get(d.name),raw_log=str(logfile))); continue
    log=logfile.read_text(encoding='utf-8',errors='replace').replace('\x00','')
    if int(rcfile.read_text().strip())==124:
        rows.append(dict(tb=d.name,state='external_interrupted',rc=124,baseline=baseline.get(d.name),raw_log=str(logfile),reason='GNU timeout external wall-clock cap; original TB did not reach its final result. Preserved log; complete native retry queued if capacity permits.'))
        print(d.name,'EXTERNAL_WALL_CLOCK_INTERRUPTED');continue
    if 'Unable to find module file' in log and 'Program not runnable' in log:
        rows.append(dict(tb=d.name,state='environment_failed',rc=int(rcfile.read_text().strip()),baseline=baseline.get(d.name),raw_log=str(logfile),reason='Icarus VPI library absolute paths unavailable; design simulation did not execute'))
        print(d.name,'ENVIRONMENT_FAILED',rcfile.read_text().strip());continue
    fail=failures(log)
    isunit=d.name in table
    passrx=r'^PASS[: ]|^\[PASS\]|^\[\d+\] [A-Z0-9-]+ PASS|^PHASE_A_ARITH_EQV PASS' if isunit else r'^PASS '
    passes=[l for l in log.splitlines() if re.match(passrx,l)]
    pattern=table.get(d.name)
    banners=[l for l in log.splitlines() if pattern and re.search(pattern,l)]
    finals=[l for l in log.splitlines() if '_TB_PASS' in l or 'SELFCHECK_PASS' in l or 'TB_CHIP_DIGITAL_TOP_PASS' in l]
    row=dict(tb=d.name,state='finished',rc=int(rcfile.read_text().strip()),pass_lines=len(passes),baseline=baseline.get(d.name),fail_lines=fail,banner=banners[-1:] if pattern else finals[-1:])
    rows.append(row)
    print(d.name,'rc',row['rc'],'PASS',len(passes),'FAIL',len(fail),'BANNER',row['banner'])
    if fail: print('FAIL_DETAIL',fail[:10])
(E/'regression_results.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
print('STATES',dict(collections.Counter(r['state'] for r in rows)))
