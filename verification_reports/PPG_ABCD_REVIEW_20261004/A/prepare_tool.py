from pathlib import Path
import urllib.request, hashlib, json, subprocess
BASE = Path(__file__).resolve().parent
DEST = BASE / 'toolchain'
DEST.mkdir(exist_ok=True)
URL = 'https://deb.debian.org/debian/pool/main/i/iverilog/iverilog_11.0-1_amd64.deb'
data = urllib.request.urlopen(URL, timeout=30).read()
pkg = DEST / URL.rsplit('/',1)[1]
pkg.write_bytes(data)
def linux(p):
    return '/mnt/c/' + p.as_posix()[3:]
subprocess.run(['wsl.exe','-d','Debian','--','dpkg-deb','-x',linux(pkg),linux(DEST/'icarus11')], check=True)
tool = DEST/'icarus11/usr/bin/iverilog'
lib = DEST/'icarus11/usr/lib/x86_64-linux-gnu/ivl'
r = subprocess.run(['wsl.exe','-d','Debian','--',linux(tool),'-B',linux(lib),'-V'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
(BASE/'evidence/toolchain.log').write_bytes(r.stdout)
(BASE/'evidence/toolchain_source.json').write_text(json.dumps({'url':URL,'sha256':hashlib.sha256(data).hexdigest(),'rc':r.returncode},indent=2),encoding='utf-8')
print(r.stdout.decode('utf-8',errors='replace'))
print('rc',r.returncode)
