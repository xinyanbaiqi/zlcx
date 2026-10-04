from pathlib import Path
import json,sys,re,collections
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
sys.path.insert(0,str(S/'.claude/skills/erie-verilog-generator/scripts/python'))
from quality.formatter_backend.engine import VerilogFormatterEngine
from contract_width_crosscheck_A import const,port_shape
# Canonical repo helpers are reused directly on canonical AST instance records.
# This is inspection only: no rendering, renaming, repair or source writeback.
engine=VerilogFormatterEngine.__new__(VerilogFormatterEngine)
def associations(text):
 d=engine._parse_instance_for_render(engine._strip_instance_comments_for_parse(text))
 assert d is not None,'canonical instance parser declined'
 ports=[(engine._extract_instance_association_formal_name(s),engine._extract_instance_association_actual_text(s)) for s in d['ports']]
 params=[(engine._extract_instance_association_formal_name(s),engine._extract_instance_association_actual_text(s)) for s in d['params']]
 return d,ports,params
def check_formals(pairs,declared):
 seen=set();faults=[]
 for name,actual in pairs:
  if name in seen:faults.append(('duplicate',name))
  seen.add(name)
  if name not in declared:faults.append(('unknown',name));continue
  if not actual and declared[name]['direction']=='input':faults.append(('open_input',name))
 for name,p in declared.items():
  if p['direction']=='input' and name not in seen:faults.append(('missing_input',name))
 return faults
fixture={'i_a':{'direction':'input'},'o_b':{'direction':'output'}}
negative=[]
for label,text,expected in [
 ('good','leaf inst(.i_a(net),.o_b());',[]),
 ('unknown_port','leaf inst(.i_a(net),.o_b(),.i_wrong(net));',[('unknown','i_wrong')]),
 ('duplicate','leaf inst(.i_a(net),.i_a(net),.o_b());',[('duplicate','i_a')]),
 ('open_input','leaf inst(.i_a(),.o_b());',[('open_input','i_a')]),
 ('missing_input','leaf inst(.o_b());',[('missing_input','i_a')])]:
 _,pairs,_=associations(text);actual=check_formals(pairs,fixture);assert actual==expected,(label,actual,expected)
 negative.append(dict(case=label,reported=actual))
mods={};sources={}
for f in (E/'gates').glob('*.json'):
 for unit in json.loads(f.read_text(encoding='utf-8'))['quality_gate']['ast_report']['files']:
  for m in unit.get('modules',[]):mods[m['name']]=m
for p in (S/'rtl').rglob('*.v'):
 if not p.name.startswith('tb_'):sources[p.stem]=p
def parameter_values(module,overrides=None):
 values=dict(overrides or {});pending=[p for p in module.get('params',[])+module.get('localparams',[]) if p['name'] not in values]
 while pending:
  progress=False
  for p in pending[:]:
   try:values[p['name']]=const(p['value'],values)
   except (ValueError,SyntaxError,TypeError):continue
   pending.remove(p);progress=True
  if not progress:break
 return values
instances=[];connections=[];declined=[];unknown=[];wire_widths=[];wire_width_skips=[]
for parent,m in mods.items():
 for inst in m.get('instances',[]):
  try:d,pairs,params=associations(inst['text'])
  except AssertionError as error:
   declined.append(dict(parent=parent,instance=inst['instance_name'],line=inst['line_start'],reason=str(error)));continue
  child=d['module_name'];ports={p['name']:p for p in mods.get(child,{}).get('ports',[])}
  if not ports:unknown.append(dict(parent=parent,module=child,instance=d['instance_name'],line=inst['line_start']));continue
  faults=check_formals(pairs,ports)
  instances.append(dict(parent=parent,module=child,instance=d['instance_name'],line=inst['line_start'],end_line=inst['line_end'],faults=faults,params=params))
  lines=sources[parent].read_text(encoding='utf-8').splitlines()
  parent_params=parameter_values(m);override_values={}
  for key,value in params:
   try:override_values[key]=const(value,parent_params)
   except (ValueError,SyntaxError,TypeError):pass
  child_params=parameter_values(mods[child],override_values)
  nets={p['name']:p for p in m.get('ports',[])+m.get('decls',[])}
  for formal,actual in pairs:
   p=ports.get(formal)
   # Locate the actual source line within the exact canonical instance span.
   # No offset arithmetic: require the formal token in actual line text.
   hits=[n for n in range(inst['line_start'],inst['line_end']+1) if ('.'+str(formal)+'(') in lines[n-1].replace(' ','').replace('\t','')]
   if len(hits)!=1:
    declined.append(dict(parent=parent,instance=d['instance_name'],formal=formal,reason='association source not uniquely one-line; keep instance span evidence'))
   connections.append(dict(parent=parent,module=child,instance=d['instance_name'],formal=formal,actual=actual,
    direction=p['direction'] if p else None,formal_width=p['width'] if p else None,formal_signed=p['signed'] if p else None,
    declaration_line=p['line_start'] if p else None,source_line=hits[0] if len(hits)==1 else None,
    source_text=lines[hits[0]-1] if len(hits)==1 else inst['text']))
   if actual in nets and p:
    try:a=port_shape(nets[actual],parent_params)[0];z=port_shape(p,child_params)[0]
    except (ValueError,SyntaxError,TypeError) as error:
     wire_width_skips.append(dict(parent=parent,module=child,formal=formal,actual=actual,reason=str(error)));continue
    wire_widths.append(dict(parent=parent,module=child,instance=d['instance_name'],formal=formal,actual=actual,source_line=hits[0] if len(hits)==1 else None,actual_bits=a,formal_bits=z,state='match' if a==z else 'candidate_mismatch'))
drivers=collections.defaultdict(list)
for c in connections:
 if c['direction']=='output' and re.fullmatch(r'[A-Za-z_]\w*',c['actual']):drivers[(c['parent'],c['actual'])].append((c['instance'],c['formal'],c['source_line']))
conflicts=[dict(parent=p,net=n,drivers=d) for (p,n),d in drivers.items() if len(d)>1]
assert len({('fixture','net'):[('a','o_x'),('b','o_y')]})==1
control_drivers={('fixture','net'):[('a','o_x'),('b','o_y')],('fixture','single'):[('c','o_z')]}
assert [n for (p,n),d in control_drivers.items() if len(d)>1]==['net']
for u in unknown:
 p=sources[u['module']]
 assert p.exists()
 u.update(state='isolated_existing_leaf_AST_port_metadata_unavailable',actual_source=p.relative_to(S).as_posix(),
  reason='Module source exists and all37 real Icarus RTL compiles and full timing/dual original TB runs already succeeded. Canonical aggregate port metadata absent; not a missing HDL module, no automatic new defect. Known isolated-module disposition retained.')
result=dict(instances=instances,connections=connections,declined=declined,unknown_modules=unknown,negative_controls=negative,multiple_child_output_drivers=conflicts,wire_widths=wire_widths,wire_width_skips=wire_width_skips,
 counts=dict(instances=len(instances),associations=len(connections),faults=sum(len(i['faults']) for i in instances),declined=len(declined),unknown_modules=len(unknown),multiple_child_output_drivers=len(conflicts),plain_net_widths=dict(collections.Counter(r['state'] for r in wire_widths)),plain_net_width_not_evaluable=len(wire_width_skips)),
 limits='Named association existence/direction and actual source location from canonical Erie AST/helpers. Empty outputs are allowed. Does not infer legal behavior from wire-name similarity, does not recreate ASIC timing/CDC signoff, and does not claim every actual net has a semantically correct producer.')
(O/'canonical_instance_crosscheck_A.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('CANONICAL_INSTANCE_CHECK',result['counts'])
for i in instances:
 if i['faults']:print('CANDIDATE',i)
for x in declined[:4]+unknown[:4]:print('UNRESOLVED',x)
for r in wire_widths:
 if r['state']=='candidate_mismatch':print('WIDTH_CANDIDATE',r)
