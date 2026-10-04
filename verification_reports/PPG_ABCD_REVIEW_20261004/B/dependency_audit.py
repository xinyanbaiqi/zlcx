from review import *
import re
from collections import Counter

OWN={
'C08':'PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md',
'C09':'PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md',
'C10':'PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md',
'C16':'PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md',
'C18':'PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md',
'C23':'PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md',
'C24':'PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md'}
matrix=(SNAP/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8-sig').splitlines()
targets={}
for n,line in enumerate(matrix,1):
 if 1230<n<1270:
  m=re.match(r'\| (C\d\d) \| `([^`]+)`',line)
  if m:targets[m[1]]={'canonical':m[2],'file':SNAP/'contracts'/Path(m[2]).name,'matrix_line':n}
assert len(targets)==25,len(targets)
def header_version(line):
 # Chinese revision prose directly follows the numeric version; a Unicode
 # word-boundary after the last digit would incorrectly retreat to V1/V2.
 m=re.search(r'\b(V\d+(?:\.\d+)*)(?!\d|\.\d)',line)
 assert m,line
 return m[1]
assert header_version('> V1.10修订日期：2026-09-10。')=='V1.10'
assert header_version('> Current normative version: V2.6, 2026-08-20.')=='V2.6'
assert header_version('> Current normative version: V1.3. Substantive freeze date: 2026.')=='V1.3'
for c,t in targets.items():
 lines=t['file'].read_text(encoding='utf-8-sig').splitlines()
 t['header_version']=header_version(lines[2]);t['header_line3']=lines[2]

def declared_refs(source):
 refs=[]
 lines=(SNAP/'contracts'/OWN[source]).read_text(encoding='utf-8-sig').splitlines()
 for n,line in enumerate(lines[:90],1):
  m=re.match(r'\| (C\d\d) \| `([^`]+)` \| (V\d+(?:\.\d+)*) \|',line)
  if not m:m=re.match(r'\d+\. (C\d\d) — `([^`]+)` (V\d+(?:\.\d+)*)',line)
  if m:refs.append({'source':source,'line':n,'target':m[1],'canonical':m[2],'declared_version':m[3]})
 return refs

if __name__=='__main__':
 refs=[r for c in OWN for r in declared_refs(c)]
 assert len(refs)==54,len(refs)
 for r in refs:
  target=targets[r['target']]
  r.update(header_version=target['header_version'],header_line=3,path_matches=r['canonical']==target['canonical'],version_matches=r['declared_version']==target['header_version'])
 # Negative controls: reject a deliberately wrong version and wrong path.
 def valid(r):return r['canonical']==targets[r['target']]['canonical'] and r['declared_version']==targets[r['target']]['header_version']
 good=next(r for r in refs if r['version_matches'] and r['path_matches'])
 bad_version=dict(good,declared_version='V999.0');bad_path=dict(good,canonical='wrong/path.md')
 assert valid(good) and not valid(bad_version) and not valid(bad_path)
 result={'commit':COMMIT,'method':'54 current dependency rows of seven B-owned normative contracts, resolved through current matrix 12.4a canonical paths into flat snapshot; compare to actual target header line 3 by the ledger convention. Not a normative-meaning/signoff checker.','negative_controls':{'wrong_version_detected':True,'wrong_path_detected':True},'bindings':refs}
 (OUT/'evidence'/'dependency_bindings.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
 print('54 bindings; path mismatch',sum(not r['path_matches'] for r in refs),'version mismatch',sum(not r['version_matches'] for r in refs))
 for r in refs:
  if not r['version_matches'] or not r['path_matches']:print(r['source']+':'+str(r['line']),r['target'],r['declared_version'],'actual line 3',r['header_version'])
 print('negative controls: 2/2')
