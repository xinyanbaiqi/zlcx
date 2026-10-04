from pathlib import Path
import json,subprocess,shlex
B=Path(__file__).resolve().parent; S=B/'snapshot'; D=B/'evidence/chip_spi_ab'; D.mkdir(exist_ok=True)
j=next(x for x in json.loads((B/'evidence/compile_manifest.json').read_text(encoding='utf-8')) if x['name']=='tb_ppg_chip_digital_top')
src=(S/j['tb']).read_text(encoding='utf-8')
old='''\t\t\t\tSPI_SDI = tx_byte[i];
\t\t\t\trx_byte[i] = SPI_SDO;
\t\t\t\t#(SPI_HALF_PERIOD) SPI_SCLK = 1'b1;
\t\t\t\t#(SPI_HALF_PERIOD) SPI_SCLK = 1'b0;'''
new='''\t\t\t\tSPI_SDI = tx_byte[i];
\t\t\t\t#(SPI_HALF_PERIOD) SPI_SCLK = 1'b1;
\t\t\t\t#1 rx_byte[i] = SPI_SDO;
\t\t\t\t#(SPI_HALF_PERIOD-1) SPI_SCLK = 1'b0;'''
assert src.count(old)==1
tb=D/'tb_ppg_chip_digital_top_physical_spi.v';tb.write_bytes(src.replace(old,new).encode())
def lin(p):return '/mnt/c/'+p.resolve().as_posix()[3:]
lib=B/'toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl'; iv=B/'toolchain/icarus11/usr/bin/iverilog'; vvp=B/'toolchain/icarus11/usr/bin/vvp'
paths=[tb if p==j['tb'] else S/p for p in j['files']]
args=[lin(iv),'-B',lin(lib),'-g2012','-Wall','-s',j['name'],'-o',lin(D/'sim.vvp')]+[lin(p) for p in paths]
c=subprocess.run(['wsl.exe','-d','Debian','--']+args,capture_output=True);(D/'compile.log').write_bytes(c.stdout+c.stderr)
r=subprocess.run(['wsl.exe','-d','Debian','--','timeout','120',lin(vvp),'-M',lin(lib),lin(D/'sim.vvp')],capture_output=True);(D/'run.log').write_bytes(r.stdout+r.stderr)
print('CHIP_PHYSICAL compile',c.returncode,'run',r.returncode)
print(r.stdout.decode('utf-8',errors='replace'))
