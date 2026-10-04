from pathlib import Path
import csv, json, subprocess, sys, os, hashlib
OUT=Path(__file__).resolve().parent
AUDIT=Path(r'C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit')
SNAP=AUDIT/'snapshot'
COMMON=Path(r'C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd39-7e50-7671-8810-299165a4df40')
COMMIT='d18c6954621e53e5a6505dd3a6c688c266d23839'
FILES=[r for r in csv.DictReader((COMMON/'OWNERSHIP_4CHAT.csv').open(encoding='utf-8-sig')) if r['owner']=='B']
if __name__=='__main__':
 if sys.argv[1]=='read':
  p=SNAP/sys.argv[2] if not Path(sys.argv[2]).is_absolute() else Path(sys.argv[2])
  lines=p.read_text(encoding='utf-8-sig').splitlines()
  start=int(sys.argv[3]) if len(sys.argv)>3 else 1
  end=int(sys.argv[4]) if len(sys.argv)>4 else len(lines)
  print(str(p))
  for i in range(start-1,min(end,len(lines))):print(f'{i+1:5}: {lines[i]}')
 if sys.argv[1]=='init':
  results=[]
  for f in FILES:
   p=SNAP/f['path']
   blob=subprocess.check_output([r'D:\Git\cmd\git.exe','-C',str(AUDIT/'zlcx'),'show',COMMIT+':'+f['path']])
   results.append(dict(path=f['path'],lines=len(p.read_bytes().splitlines()),same=p.read_bytes()==blob,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
  (OUT/'evidence'/'baseline.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
  with (OUT/'coverage.csv').open('w',encoding='utf-8-sig',newline='') as fp:
   w=csv.DictWriter(fp,fieldnames=['owner','path','check_item','contract_or_id','status','evidence','remaining']);w.writeheader()
   for f in FILES:
    for item in (['全文内部一致性','端口/RTL/时序','版本依赖/ID/锚点'] if f['layer']=='合同' else ['端口/合同','reset/状态/异常','握手/优先级/身份/计数/位宽','注释/可综合性/门禁'] if f['layer']=='RTL' else ['全文驱动/比较/覆盖','有效窗口/X/超时/结束','负对照/运行证据']):
     w.writerow(dict(owner='B',path=f['path'],check_item=item,contract_or_id='',status='未审',evidence='',remaining='逐项审阅'))
  (OUT/'PPG_REVIEW_B.md').write_text(f'被审提交：`{COMMIT}`\n\n# PPG 控制协议与生命周期专项 B\n\n状态：进行中。只读、conservative。初始主责文件字节核对见 evidence/baseline.json。\n',encoding='utf-8')
  (OUT/'handoff.md').write_text(f'# B 交接\n\n固定提交：{COMMIT}\n\n输出目录：{OUT}\n报告：{OUT / "PPG_REVIEW_B.md"}\n覆盖台账：{OUT / "coverage.csv"}\n证据目录：{OUT / "evidence"}\n\n状态：已读四份共同文件及技能；Git HEAD一致、工作树干净，正在核实旧发现与工具证据并逐拍建立协议表。尚无新结论。全部主责语义未审完。\n',encoding='utf-8')
  print(json.dumps(results,indent=2))
