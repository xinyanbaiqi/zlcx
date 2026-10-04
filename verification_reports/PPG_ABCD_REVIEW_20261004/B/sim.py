from review import *
import io, tarfile
TC=AUDIT/'toolchain/icarus11'
def linux(p):return '/mnt/'+p.drive[0].lower()+p.as_posix()[2:]
def sim(name,top,sources,tb,mutated=None):
 d=OUT/'evidence'/name;d.mkdir(parents=True,exist_ok=True)
 t=d/(top+'.v');t.write_text(tb,encoding='utf-8');src=[]
 for p in sources:
  p=SNAP/p
  if mutated and p.name in mutated:
   q=d/p.name;q.write_text(mutated[p.name],encoding='utf-8');p=q
  src.append(p)
 map_path=linux
 if os.environ.get('PPG_B_STAGE_IN_TMP')=='1':
  assert name.replace('_','').isalnum()
  stage='/tmp/codex-ppg-review-B-d18c6954/'+name
  buf=io.BytesIO()
  with tarfile.open(fileobj=buf,mode='w:gz') as arc:
   def tool_mode(info):
    if info.isfile() or info.isdir():info.mode=0o755
    return info
   arc.add(TC,arcname='tc',filter=tool_mode)
   for p in src+[t]:
    arc.add(p,arcname='inputs/'+p.name)
   for p in (SNAP/'rtl/ppg_control_top').glob('*.vh'):
    arc.add(p,arcname='inputs/'+p.name)
  upload=subprocess.run(['wsl.exe','-d','Debian','--cd','/','--','sh','-c',f'umask 077; mkdir -p {stage}; tar -xz -C {stage}'],input=buf.getvalue(),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
  (d/'staging.log').write_bytes(upload.stdout)
  if upload.returncode!=0:
   print(name,'STAGING_FAIL',upload.stdout.decode(errors='replace')[-1000:]);return
  def map_path(p):
   if p==TC or TC in p.parents:return stage+'/tc/'+str(p.relative_to(TC)).replace('\\','/')
   if p.name=='sim.vvp':return stage+'/sim.vvp'
   if p.is_dir():return stage+'/inputs'
   return stage+'/inputs/'+p.name
 cmd=['wsl.exe','-d','Debian','--cd','/','--',map_path(TC/'usr/bin/iverilog'),'-B',map_path(TC/'usr/lib/x86_64-linux-gnu/ivl'),'-g2012','-Wall','-s',top,'-o',map_path(d/'sim.vvp'),'-I',map_path(SNAP/'rtl/ppg_control_top')]+[map_path(p) for p in src]+[map_path(t)]
 c=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60);(d/'compile.log').write_bytes(c.stdout)
 res=dict(compile_command=cmd,compile_rc=c.returncode)
 if c.returncode==0:
  v=subprocess.run(['wsl.exe','-d','Debian','--cd','/','--',map_path(TC/'usr/bin/vvp'),'-M',map_path(TC/'usr/lib/x86_64-linux-gnu/ivl'),map_path(d/'sim.vvp')],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=45)
  (d/'run.log').write_bytes(v.stdout);s=v.stdout.decode(errors='replace')
  res.update(run_rc=v.returncode,fail_mentions=s.count('FAIL'),pass_mentions=s.count('PASS'))
  print(name,{k:v for k,v in res.items() if k!='compile_command'},'tail',s.splitlines()[-8:],flush=True)
 else:print(name,'COMPILE_FAIL',c.stdout.decode(errors='replace')[-1500:],flush=True)
 (d/'result.json').write_text(json.dumps(res,indent=2),encoding='utf-8')
