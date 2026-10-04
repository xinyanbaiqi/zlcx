"""D组只读取证驱动：固定版本核验、行号读取和外部最小验证；不解析Verilog。"""
from pathlib import Path
import csv
import hashlib
import json
import io
import os
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parent
AUDIT = Path('C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit')
SOURCE = AUDIT / 'snapshot'
SKILL = SOURCE / '.claude/skills/erie-verilog-generator'
COMMON = Path('C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd39-7e50-7671-8810-299165a4df40')
COMMIT = 'd18c6954621e53e5a6505dd3a6c688c266d23839'
GIT = 'D:/Git/cmd/git.exe'
PYTHON = sys.executable
EVIDENCE = ROOT / 'evidence'

def owned():
    with (COMMON / 'OWNERSHIP_4CHAT.csv').open(encoding='utf-8-sig', newline='') as handle:
        return [row for row in csv.DictReader(handle) if row['owner'] == 'D']

def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')

def initialize():
    records = []
    for row in owned():
        raw = (SOURCE / row['path']).read_bytes()
        blob = subprocess.run([GIT, '-C', str(AUDIT / 'zlcx'), 'show', COMMIT + ':' + row['path']], capture_output=True, check=True).stdout
        records.append(dict(row, sha256=hashlib.sha256(raw).hexdigest(), git_blob_equal=raw == blob, lines=len(raw.decode('utf-8-sig').splitlines())))
    save_json(EVIDENCE / 'baseline.json', records)
    if not (ROOT / 'coverage.csv').exists():
        with (ROOT / 'coverage.csv').open('w', encoding='utf-8-sig', newline='') as handle:
            writer = csv.DictWriter(handle, fieldnames=['owner', 'path', 'check_item', 'contract_or_id', 'status', 'evidence', 'remaining'])
            writer.writeheader()
            for record in records:
                categories = ['全文语义与端口合同', '复位/状态/异常/握手/位宽/注释', '门禁/编译与证据'] if record['layer'] == 'RTL' else (['全文语义比较与输入资格', '有效覆盖/负对照/结束条件'] if record['layer'] == 'TB' else ['全文内部一致性与RTL映射', '版本/ID/矩阵闭环'])
                for item in categories:
                    writer.writerow(dict(owner='D', path=record['path'], check_item=item, contract_or_id='', status='未审', evidence='evidence/baseline.json', remaining='待逐批实际核验'))
    print(json.dumps(records, ensure_ascii=False, indent=2))

def read_lines(arguments):
    for argument in arguments:
        relative, separator, bounds = argument.partition('@')
        path = Path(relative) if Path(relative).is_absolute() else SOURCE / relative
        lines = path.read_text(encoding='utf-8-sig').splitlines()
        start, end = map(int, bounds.split('-')) if separator else (1, len(lines))
        print('\nFILE', relative, 'TOTAL', len(lines))
        for number in range(start, min(end, len(lines)) + 1):
            print(str(number) + ': ' + lines[number - 1])

def read_code(arguments):
    """仅省略空行和独立//注释；不是Verilog解析或检查器。场景注释另行实读。"""
    for argument in arguments:
        relative,separator,bounds=argument.partition('@')
        lines=(SOURCE/relative).read_text(encoding='utf-8-sig').splitlines()
        start,end=map(int,bounds.split('-')) if separator else (1,len(lines))
        print('FILE',relative,'TOTAL',len(lines),'COMMENT-ONLY LINES OMITTED')
        for number in range(start,min(end,len(lines))+1):
            line=lines[number-1]
            if line.strip() and not line.lstrip().startswith('//'):
                print(str(number)+': '+line)

def read_comments(arguments):
    """显示独立行注释以补齐场景说明；只是文字读取。"""
    for argument in arguments:
        relative,separator,bounds=argument.partition('@')
        lines=(SOURCE/relative).read_text(encoding='utf-8-sig').splitlines()
        start,end=map(int,bounds.split('-')) if separator else (1,len(lines))
        print('COMMENTS',relative,start,end)
        for number in range(start,min(end,len(lines))+1):
            if lines[number-1].lstrip().startswith('//'):
                print(str(number)+': '+lines[number-1])

def gates():
    result = []
    for row in owned():
        if row['layer'] != 'RTL':
            continue
        name = Path(row['path']).stem
        output = EVIDENCE / 'skill_analysis' / name
        input_copy = EVIDENCE / 'skill_inputs' / row['path']
        input_copy.parent.mkdir(parents=True, exist_ok=True)
        input_copy.write_bytes((SOURCE / row['path']).read_bytes())
        args = [PYTHON, '-B', '-m', 'scripts.python.workflow.cli', 'analyze-existing', '--source', str(input_copy), '--out-dir', str(output), '--no-state']
        run = subprocess.run(args, cwd=ROOT, capture_output=True, env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1', PYTHONPATH=str(SKILL), PYTHONUTF8='1'))
        output.mkdir(parents=True, exist_ok=True)
        (output / 'cli.log').write_bytes(run.stdout + run.stderr)
        prior = json.loads((AUDIT / 'evidence/gates' / (name + '.json')).read_text(encoding='utf-8'))
        result.append(dict(path=row['path'], analysis_rc=run.returncode, analysis_log=str(output / 'cli.log'), prior_gate=str(AUDIT / 'evidence/gates' / (name + '.json')), prior_checks=prior.get('checks'), prior_rules=prior.get('delivery_issues_by_rule')))
        print(name, 'analysis_rc', run.returncode, 'prior_rules', prior.get('delivery_issues_by_rule'), flush=True)
    save_json(EVIDENCE / 'gate_reuse.json', result)

def linux(path):
    return '/mnt/c/' + Path(path).resolve().as_posix()[3:]

def simulate(name, tb, files, extra=()):
    directory = EVIDENCE / name
    directory.mkdir(parents=True, exist_ok=True)
    library = AUDIT / 'toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl'
    compiler = AUDIT / 'toolchain/icarus11/usr/bin/iverilog'
    runner = AUDIT / 'toolchain/icarus11/usr/bin/vvp'
    native = os.environ.get('PPG_D_NATIVE_TMP')
    if native:
        # 仅为C盘drvfs发生I/O错误时的传输适配，不安装工具或修改共享目录。
        staging=f'/tmp/ppg_review_D_01a0fd78_{os.getpid()}'
        stream=io.BytesIO()
        with tarfile.open(fileobj=stream,mode='w:gz') as archive:
            for executable in (compiler,runner):
                archive.add(executable,arcname='toolchain/usr/bin/'+executable.name)
            archive.add(library,arcname='toolchain/usr/lib/ivl')
            archive.add(tb,arcname='inputs/testbench.v')
            # 系统TB实际使用的固定版本公共前缀；仅复制输入，不生成/解析Verilog。
            archive.add(SOURCE/'rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh',arcname='inputs/tb_ppg_jnt_baseline_prefix.vh')
            for index,file in enumerate(files):
                archive.add(SOURCE/file,arcname=f'inputs/rtl{index}.v')
        mkdir=subprocess.run(['wsl.exe','-d','Debian','--cd','/tmp','--','/bin/mkdir','-p',staging],capture_output=True)
        transfer=subprocess.run(['wsl.exe','-d','Debian','--cd','/tmp','--','/bin/tar','-xzf','-','-C',staging],input=stream.getvalue(),capture_output=True)
        (directory/'transfer.log').write_bytes(mkdir.stdout+mkdir.stderr+transfer.stdout+transfer.stderr)
        assert mkdir.returncode==0 and transfer.returncode==0
        subprocess.run(['wsl.exe','-d','Debian','--cd','/tmp','--','/bin/chmod','-R','u+rx',staging+'/toolchain'],capture_output=True,check=True)
        library_path=staging+'/toolchain/usr/lib/ivl'
        compiler_path=staging+'/toolchain/usr/bin/iverilog'
        runner_path=staging+'/toolchain/usr/bin/vvp'
        args=['wsl.exe','-d','Debian','--cd','/tmp','--',compiler_path,'-B',library_path,'-I',staging+'/inputs','-g2012','-Wall','-s',name,'-o',staging+'/sim.vvp',staging+'/inputs/testbench.v']+[staging+f'/inputs/rtl{index}.v' for index in range(len(files))]
    else:
        args = ['wsl.exe', '-d', 'Debian', '--', linux(compiler), '-B', linux(library), '-g2012', '-Wall', '-s', name, '-o', linux(directory / 'sim.vvp'), linux(tb)] + [linux(SOURCE / file) for file in files]
    compile_run = subprocess.run(args, capture_output=True)
    (directory / 'compile.log').write_bytes(compile_run.stdout + compile_run.stderr)
    result = dict(compile_rc=compile_run.returncode, command=args)
    if compile_run.returncode == 0:
        command=['wsl.exe','-d','Debian','--cd','/tmp','--',runner_path,'-M',library_path,staging+'/sim.vvp'] if native else ['wsl.exe', '-d', 'Debian', '--', linux(runner), '-M', linux(library), linux(directory / 'sim.vvp')]
        run = subprocess.run(command + list(extra), capture_output=True, timeout=55)
        (directory / 'run.log').write_bytes(run.stdout + run.stderr)
        result['run_rc'] = run.returncode
        result['run_command'] = command + list(extra)
        if native:
            binary=subprocess.run(['wsl.exe','-d','Debian','--cd','/tmp','--','/bin/cat',staging+'/sim.vvp'],capture_output=True,check=True)
            (directory/'sim.vvp').write_bytes(binary.stdout)
        print(run.stdout.decode('utf-8', errors='replace'))
    save_json(directory / 'result.json', result)
    print(name, result.get('compile_rc'), result.get('run_rc'))

def cdc_sweep():
    files = ['rtl/ppg_config_cdc_bridge/ppg_config_cdc_bridge.v', 'rtl/ppg_characterization_control_cdc/ppg_characterization_control_cdc.v', 'rtl/ppg_pulse_cdc_sync/ppg_pulse_cdc_sync.v', 'rtl/ppg_reset_sync/ppg_reset_sync.v']
    directory = EVIDENCE / 'd_cdc_probe'
    for file in directory.glob('case*'):
        if not (directory / ('setup_invalid.' + file.name)).exists():
            (directory / ('setup_invalid.' + file.name)).write_bytes(file.read_bytes())
        elif not (directory / ('monitor_setup_invalid.' + file.name)).exists():
            (directory / ('monitor_setup_invalid.' + file.name)).write_bytes(file.read_bytes())
    for index, (source_half, dest_half, phase, skew) in enumerate([(7,5,1,9),(3,17,2,11),(17,3,4,7),(125,250,113,777),(250,125,71,511)]):
        simulate('d_cdc_probe', EVIDENCE / 'd_cdc_probe.v', files, [f'+SOURCE_HALF={source_half}', f'+DEST_HALF={dest_half}', f'+PHASE={phase}', f'+SKEW={skew}'])
        directory = EVIDENCE / 'd_cdc_probe'
        for file in directory.iterdir():
            if file.name in ['compile.log', 'run.log', 'result.json']:
                file.replace(file.with_name(f'case{index}.' + file.name))

def ccc_mutations():
    tb_relative = 'rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v'
    rtl_relative = 'rtl/ppg_characterization_control_cdc/ppg_characterization_control_cdc.v'
    bridge = 'rtl/ppg_config_cdc_bridge/ppg_config_cdc_bridge.v'
    rtl = (SOURCE / rtl_relative).read_text(encoding='utf-8')
    needle = "end else if(i_diag_clear_event == 1'b1)begin\n\t\t\tprotocol_error_sticky_o <= 1'b0;"
    assert rtl.count(needle) == 1
    mutant = EVIDENCE / 'ccc_clear_mutant.v'
    mutant.write_bytes(rtl.replace(needle, "end else if(i_diag_clear_event == 1'b1)begin\n\t\t\tprotocol_error_sticky_o <= protocol_error_sticky_o;").encode('utf-8'))
    tb = (SOURCE / tb_relative).read_text(encoding='utf-8')
    positive = EVIDENCE / 'ccc_original.v'
    positive.write_bytes(tb.encode('utf-8'))
    negative = EVIDENCE / 'ccc_negative.v'
    assert tb.count("check_case(8'd4, (o_static_characterization_enable === 1'b1)") == 1
    negative.write_bytes(tb.replace("check_case(8'd4, (o_static_characterization_enable === 1'b1)", "check_case(8'd4, (o_static_characterization_enable === 1'b0)").encode('utf-8'))
    simulate('tb_ppg_characterization_control_cdc', positive, [bridge, str(mutant)])
    directory = EVIDENCE / 'tb_ppg_characterization_control_cdc'
    for file in directory.iterdir():
        if file.suffix in ['.log', '.json']:
            file.rename(file.with_name('clear_mutant.' + file.name))
    simulate('tb_ppg_characterization_control_cdc', negative, [bridge, rtl_relative])
    for file in directory.iterdir():
        if file.name in ['compile.log', 'run.log', 'result.json']:
            file.rename(file.with_name('negative.' + file.name))

if __name__ == '__main__':
    mode, *args = sys.argv[1:]
    if mode == 'init':
        initialize()
    elif mode == 'read':
        read_lines(args)
    elif mode == 'code':
        read_code(args)
    elif mode == 'comments':
        read_comments(args)
    elif mode == 'gates':
        gates()
    elif mode == 'sim':
        simulate(args[0], ROOT / args[1], args[2:])
    elif mode == 'ccc_mutations':
        ccc_mutations()
    elif mode == 'cdc_sweep':
        cdc_sweep()
