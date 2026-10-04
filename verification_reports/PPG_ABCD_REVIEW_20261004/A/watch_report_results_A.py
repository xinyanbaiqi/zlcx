from pathlib import Path
import json,datetime,time,runpy,contextlib,io,hashlib,collections
B=Path(__file__).resolve().parent;E=B/'evidence'
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def fingerprint(items):return hashlib.sha256(json.dumps(items,sort_keys=True).encode()).hexdigest()
def changed(before,after):return fingerprint(before)!=fingerprint(after)
fixture=[{'tb':'fixture','rc':'RUNNING','end':''}]
assert not changed(fixture,[dict(fixture[0])])
assert changed(fixture,[{'tb':'fixture','rc':'0','end':'actual_end'}])
assert changed(fixture,[{'tb':'fixture','rc':'124','end':'actual_end'}])
(E/'report_watch_negative_controls.json').write_text(json.dumps({'unchanged_no_refresh':True,'real_completion_refresh':True,'external_cap_refresh':True},indent=2),encoding='utf-8')
def sample():
 rows=[]
 for d in sorted((E/'compile').iterdir()):
  if not d.name.startswith('tb_'):continue
  rows.append({'tb':d.name,'rc':(d/'run.rc').read_text().strip() if (d/'run.rc').exists() else '',
   'end':(d/'run.end').read_text().strip() if (d/'run.end').exists() else ''})
 assert len(rows)==48,len(rows)
 return rows
if __name__=='__main__':
 last=sample();deadline=time.monotonic()+48*3600;events=[]
 print('REPORT_LOG_WATCH_START 48; refresh on actual terminal-state changes only',flush=True)
 while time.monotonic()<deadline:
  current=sample()
  if changed(last,current):
   output=io.StringIO()
   try:
    with contextlib.redirect_stdout(output):runpy.run_path(str(B/'finish_closure_checkpoint_A.py'))
   except Exception as exc:
    (E/'report_watch_state.json').write_text(json.dumps({'updated_utc':now(),'state':'needs_manual_attention','error':str(exc),'stdout':output.getvalue()},ensure_ascii=False,indent=2),encoding='utf-8')
    raise
   results=json.loads((E/'regression_results.json').read_text(encoding='utf-8'))
   anomalies=[r for r in results if r['state'] in ('environment_failed','external_interrupted') or
    (r['state']=='finished' and (r['rc']!=0 or r['fail_lines'] or not r['banner'] or (r['baseline'] is not None and r['pass_lines']!=r['baseline'])))]
   event={'utc':now(),'states':dict(collections.Counter(r['state'] for r in results)),
    'changed_tbs':[a['tb'] for a,b in zip(current,last) if a!=b],'anomalies':anomalies}
   events.append(event);last=current
   (E/'report_watch_events.json').write_text(json.dumps(events,ensure_ascii=False,indent=2),encoding='utf-8')
   print('REPORT_LOG_REFRESH',event['states'],'anomalies',len(anomalies),flush=True)
   if all(r['state']=='finished' for r in results):
    print('ALL_48_RAW_LOGS_FINALIZED; semantic limits and findings remain in report',flush=True)
    break
  (E/'report_watch_state.json').write_text(json.dumps({'updated_utc':now(),'state':'watching_actual_logs',
   'completed_refreshes':len(events),'last_fingerprint':fingerprint(last),
   'limits':'Refreshes factual logs, baseline comparisons, coverage runtime state and repository hash check. Does not claim full semantic or ASIC signoff, repair findings, or adjudicate new anomalies.'},ensure_ascii=False,indent=2),encoding='utf-8')
  time.sleep(20)
 (E/'report_watch_state.json').write_text(json.dumps({'updated_utc':now(),'state':'ended',
  'completed_refreshes':len(events),'events':events[-1:]},ensure_ascii=False,indent=2),encoding='utf-8')
