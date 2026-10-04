from pathlib import Path
import difflib,hashlib,json
root=Path("C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot")
out=Path("C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C")
base=root/'rtl/ppg_control_top/tb_ppg_control_top_baseline_cross.v'
a=base.read_text(encoding='utf-8').splitlines(True)
report=[]
for name in ['peak_valley_return','fir_tail_isolation','normal_slow_tracking']:
 p=root/f'rtl/ppg_control_top/tb_ppg_control_top_{name}.v'
 b=p.read_text(encoding='utf-8').splitlines(True)
 matcher=difflib.SequenceMatcher(None,a,b,autojunk=False)
 chunks=[]
 for tag,i,j,k,l in matcher.get_opcodes():
  chunks.append({'kind':tag,'base_start':i+1,'base_end':j,'candidate_start':k+1,'candidate_end':l,'candidate_lines':b[k:l] if tag!='equal' else None})
 item={'base':str(base),'path':str(p),'base_sha256':hashlib.sha256(base.read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'opcodes':chunks,'equal_lines':sum(c['candidate_end']-c['candidate_start']+1 for c in chunks if c['kind']=='equal')}
 report.append(item)
 (out/'evidence'/f'system_compare_{name}.json').write_text(json.dumps(item,ensure_ascii=False,indent=2),encoding='utf-8')
 (out/'evidence'/f'system_diff_{name}.patch').write_text(''.join(difflib.unified_diff(a,b,fromfile=str(base),tofile=str(p))),encoding='utf-8')
 print(name,len(b),'identical_lines',item['equal_lines'],'unique_lines',len(b)-item['equal_lines'])
