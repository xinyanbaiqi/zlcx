from pathlib import Path
import subprocess,io,tarfile,uuid,json,hashlib
BASE=Path(__file__).resolve().parent
TOOL='/tmp/ppg_audit_iverilog_20261004'
PREFIX=['wsl.exe','-d','Debian','--cd','/tmp','--exec']
def run(name,sources,top,timeout=60):
 d=BASE/'evidence'/name;d.mkdir(parents=True,exist_ok=True)
 root='/tmp/ppg_audit_probes/'+name.replace('/','_')+'_'+uuid.uuid4().hex[:8]
 stream=io.BytesIO();names=[];sha=[];includes=[]
 with tarfile.open(fileobj=stream,mode='w') as arc:
  for idx,p in enumerate(map(Path,sources)):
   rel=f'files/{idx}/{p.name}';data=p.read_bytes();i=tarfile.TarInfo(rel);i.size=len(data);i.mode=0o644;arc.addfile(i,io.BytesIO(data));sha.append({'file':str(p),'sha256':hashlib.sha256(data).hexdigest()})
   if p.suffix=='.vh':includes+=['-I',root+f'/files/{idx}']
   else:names.append(root+'/'+rel)
 subprocess.run(PREFIX+['mkdir','-p',root],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True)
 subprocess.run(PREFIX+['tar','-xf','-','-C',root],input=stream.getvalue(),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True)
 cmd=PREFIX+[TOOL+'/bin/iverilog','-B',TOOL+'/lib/x86_64-linux-gnu/ivl','-g2012','-Wall','-s',top,'-o',root+'/sim.vvp']+includes+names
 c=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(d/'native.compile.log').write_bytes(c.stdout)
 r=subprocess.run(PREFIX+['timeout',str(timeout),TOOL+'/bin/vvp','-M',TOOL+'/lib/x86_64-linux-gnu/ivl','-i',root+'/sim.vvp'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT) if c.returncode==0 else None
 result={'command':cmd,'linux_root':root,'compile_rc':c.returncode,'run_rc':r.returncode if r else None,'inputs':sha}
 if (d/'native.result.json').exists():(d/('native.previous_'+uuid.uuid4().hex[:8]+'.json')).write_bytes((d/'native.result.json').read_bytes())
 (d/'native.result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
 if r:
  if (d/'native.run.log').exists():(d/('native.previous_'+uuid.uuid4().hex[:8]+'.log')).write_bytes((d/'native.run.log').read_bytes())
  (d/'native.run.log').write_bytes(r.stdout)
 print(name,'compile',c.returncode,'run',r.returncode if r else None);print((r.stdout if r else c.stdout).decode('utf-8',errors='replace').replace('\x00','').splitlines()[-12:]);return result
