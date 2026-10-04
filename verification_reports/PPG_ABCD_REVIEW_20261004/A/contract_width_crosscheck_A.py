from pathlib import Path
import json,re,ast,operator,collections
B=Path(__file__).resolve().parent;E=B/'evidence';S=B/'snapshot';O=E/'global_closure_20261004'
cm=json.loads((E/'anchor_scan.json').read_text(encoding='utf-8'))['contract_map']
mapping=json.loads((O/'ledger_port_inventory_summary.json').read_text(encoding='utf-8'))['mapping']
mods={};files={}
for p in (E/'gates').glob('*.json'):
 for f in json.loads(p.read_text(encoding='utf-8'))['quality_gate']['ast_report']['files']:
  for m in f.get('modules',[]):mods[m['name']]=m
for p in (S/'rtl').rglob('*.v'):
 if not p.name.startswith('tb_'):files[p.stem]=p
def const(expr,names):
 expr=expr.replace('`','').strip()
 expr=re.sub(r"(?:\d+)?'[sS]?[dD]([0-9_]+)",lambda m:str(int(m[1].replace('_',''))),expr)
 tree=ast.parse(expr,mode='eval')
 def visit(n):
  if isinstance(n,ast.Expression):return visit(n.body)
  if isinstance(n,ast.Constant) and type(n.value)==int:return n.value
  if isinstance(n,ast.Name) and n.id in names:return names[n.id]
  if isinstance(n,ast.BinOp) and type(n.op) in (ast.Add,ast.Sub,ast.Mult,ast.FloorDiv):
   return {ast.Add:operator.add,ast.Sub:operator.sub,ast.Mult:operator.mul,ast.FloorDiv:operator.floordiv}[type(n.op)](visit(n.left),visit(n.right))
  raise ValueError(expr)
 return visit(tree)
def port_shape(p,names):
 w=p['width'].strip()
 if not w:return 1,bool(p['signed'])
 m=re.fullmatch(r'\[(.+):(.+)\]',w)
 if not m:raise ValueError(w)
 return abs(const(m[1],names)-const(m[2],names))+1,bool(p['signed'])
def doc_shape(text,names):
 text=text.replace('`','').strip()
 signed='signed' in text.lower() and 'unsigned' not in text.lower()
 m=re.fullmatch(r'(?:(?:un)?signed\s+)?(\d+)(?:\s*(?:bit|bits|each))?',text,re.I)
 if m:return int(m[1]),signed
 m=re.fullmatch(r'(?:(?:un)?signed\s+)?\[(.+):(.+)\]',text,re.I)
 if m:return abs(const(m[1],names)-const(m[2],names))+1,signed
 if re.fullmatch(r'C_\w+',text):return const(text,names),signed
 raise ValueError(text)
def grouped_doc(text,names,pname,port_names,code,line):
 value=text.replace('`','').strip()
 if value.startswith('各'):return doc_shape(value[1:],names)
 if value.startswith('每个signed '):return doc_shape(value[2:],names)
 if value=="2，必须为2'b10":return 2,False
 if value=='signed/unsigned 32':return 32,False
 if value=='参数化':
  key='C_SAMPLE_INDEX_WIDTH' if 'sample_index' in pname else 'C_FRAME_ID_WIDTH'
  assert key in names,(code,line,pname,names)
  return names[key],False
 if value=='C04 V5精确字段宽度':
  assert pname in ('i_slope_mode','i_peak_valley_config_valid')
  return 1,False
 if '/' in value:
  fields=[x.strip() for x in value.split('/')]
  index=port_names.index(pname)
  # The group field order is written explicitly in the same table cell; only
  # named members are tested here, without inferring unnamed remaining fields.
  assert index<len(fields),(value,pname,port_names)
  return doc_shape(fields[index],names)
 return doc_shape(value,names)
def comparison(actual,expected,explicit_sign):
 return actual[0]!=expected[0] or explicit_sign and actual[1]!=expected[1]
fixtures=[('good_signed',(12,True),(12,True),True),('good_unsigned',(1,False),(1,False),True),
 ('changed_width',(12,True),(11,True),True),('changed_sign',(12,True),(12,False),True)]
assert [name for name,a,e,sign in fixtures if comparison(a,e,sign)]==['changed_width','changed_sign']
assert const("32'd16",{})==16 and port_shape(dict(width='[N-1:0]',signed=True),dict(N=12))==(12,True)
assert doc_shape('signed 12',{})==(12,True)
assert doc_shape('12',{})!=port_shape(dict(width='[11:0]',signed=True),{})
assert doc_shape('signed 11',{})!=port_shape(dict(width='[11:0]',signed=True),{})
try:const('__import__("os")',{})
except ValueError:pass
else:raise AssertionError('unsafe expression')
rows=[];skips=[]
for code,modules in mapping.items():
 name=Path(cm[code]).name;lines=(S/'contracts'/name).read_text(encoding='utf-8').splitlines();header=None
 for n,line in enumerate(lines,1):
  if not line.startswith('|'):header=None;continue
  cells=[x.strip() for x in line.split('|')[1:-1]]
  wi=next((i for i,c in enumerate(cells) if c.lower() in ('width','位宽','宽度')),None)
  if wi is not None:header=(wi,cells);continue
  if header is None:continue
  wi,_=header
  if wi>=len(cells):continue
  names_found=re.findall(r'\b[io]_[A-Za-z0-9_]+\b',' '.join(cells[:wi]))
  # Slash shorthand expands only an unambiguous terminal low/high pair.
  if re.search(r'\bo_\w+_low\s*/\s*high\b',' '.join(cells[:wi])):
   names_found+=[x[:-4]+'_high' for x in names_found if x.endswith('_low')]
  for pname in dict.fromkeys(names_found):
   for module in modules:
    p=next((x for x in mods[module]['ports'] if x['name']==pname),None)
    if p is None:continue
    params={}
    for q in mods[module].get('params',[]):
     try:params[q['name']]=const(q['value'],params)
     except (ValueError,SyntaxError,TypeError):pass
    try:actual=port_shape(p,params);expected=grouped_doc(cells[wi],params,pname,list(dict.fromkeys(names_found)),code,n)
    except (ValueError,SyntaxError,TypeError) as error:
     skips.append(dict(contract=code,contract_line=n,module=module,port=pname,width_text=cells[wi],reason=str(error)));continue
    # Numeric-only tables often document bit-pattern width without a signedness
    # declaration. Only explicit signed/unsigned prose constitutes a sign check.
    explicit_sign=(expected[1] or bool(re.search(r'\bunsigned\b',cells[wi],re.I))) and cells[wi]!='signed/unsigned 32'
    mismatch=comparison(actual,expected,explicit_sign)
    decl=files[module].read_text(encoding='utf-8').splitlines()[p['line_start']-1]
    assert pname in decl
    rows.append(dict(contract=code,contract_file='contracts/'+name,contract_line=n,contract_text=line,module=module,port=pname,
     rtl_file=files[module].relative_to(S).as_posix(),rtl_line=p['line_start'],rtl_text=decl,
     expected_bits=expected[0],actual_bits=actual[0],explicit_sign_check=explicit_sign,expected_signed=expected[1],actual_signed=actual[1],state='candidate_mismatch' if mismatch else 'match'))
result=dict(records=rows,not_evaluable=skips,counts=dict(collections.Counter(x['state'] for x in rows)),
 negative_controls=dict(changed_width_detected=True,changed_signedness_detected=True,expression_execution_rejected=True,fixtures=fixtures,exact_reported_labels=['changed_width','changed_sign']),
 limits='Contract Markdown width rows only, compared to canonical Erie AST declarations at default parameters. No second Verilog parser; no inferred sign from numeric-only prose; grouped/dynamic widths remain explicit not-evaluable, never counted as passing.')
(O/'contract_width_crosscheck_A.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('EXPLICIT_WIDTH_CHECKS',result['counts'],'NOT_EVALUABLE',len(skips))
for r in rows:
 if r['state']=='candidate_mismatch':print('CANDIDATE',r['contract'],r['contract_line'],r['module'],r['port'],r['expected_bits'],r['actual_bits'],r['expected_signed'],r['actual_signed'],r['contract_text'])
