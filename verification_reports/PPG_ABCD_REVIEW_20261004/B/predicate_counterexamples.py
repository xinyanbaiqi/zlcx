from review import *
p=SNAP/'rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v'
ls=p.read_text(encoding='utf-8-sig').splitlines()
assert 'o_result_frame_id < reg_last_result_frame_id' in ls[945]
assert 'o_result_sample_index < reg_last_result_sample_index' in ls[946]
assert 'o_result_frame_id == reg_last_result_frame_id' in ls[950] and 'o_result_sample_index == reg_last_result_sample_index' in ls[950]
def verdict(trace):
 decreasing=duplicates=0
 for a,b in zip(trace,trace[1:]):
  if b['frame']<a['frame'] or b['frame']==a['frame'] and b['sample']<a['sample']:decreasing+=1
  elif b['frame']==a['frame'] and b['sample']==a['sample']:duplicates+=1
 return {'order_violations':decreasing,'duplicate_or_relabel_violations':duplicates,'OIB06_gate_pass':decreasing==duplicates==0}
good=[dict(frame=7,sample=i,color=i%2,type=0,precision=0) for i in range(10,14)]
cases={'good':good,'loss':good[:1]+good[2:],'recolor':[{**v,'color':1-v['color']} for v in good],'retype':[{**v,'type':2} for v in good],'precision_relabel':[{**v,'precision':1} for v in good],'duplicate_control':good[:2]+[good[1]]+good[2:],'decreasing_control':good[:2]+[good[0]]+good[2:]}
results={k:{'trace':v,'verdict':verdict(v)} for k,v in cases.items()}
assert all(results[k]['verdict']['OIB06_gate_pass'] for k in ['good','loss','recolor','retype','precision_relabel'])
assert not any(results[k]['verdict']['OIB06_gate_pass'] for k in ['duplicate_control','decreasing_control'])
(OUT/'evidence'/'oib06_predicate_counterexamples.json').write_text(json.dumps({'method':'binary-value replay of the exact static OIB06 predicates, not a RTL/system simulation','source':str(p),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'lines':[946,947,951,1868,1871],'results':results},indent=2),encoding='utf-8')
print(json.dumps({k:v['verdict'] for k,v in results.items()},indent=2))
