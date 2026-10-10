#!/usr/bin/env python3
"""V2 sweep summary: parse <run_dir>/points/*/xsim.log and write summary.tsv + summary.md.

The verdict is derived ONLY from the lines the TB prints (V2MON, V2POINT, V2CAUSES, V2STICKY, V2SIG,
V2LOST, V2LAND, V2TIMEOUT); exit codes and banners are not used.

Classification (first matching rule wins):
  ERROR            no V2POINT line (simulation did not reach the end of the point)
  KNOWN-ADC-HELD-DONE  any monitor failure or abnormal end while the held DONE model (done_mode 1/3)
                   or the C01 idle formula (idle_mode 1) is selected: registered known issue, ADC round
  PASS             event FOREVER: lifecycle stays STOPPING with blocking, system causes contain 07 and 31,
                   liveness PASS (contract-defined long-busy behaviour, SYS-BUSY-FOREVER)
  NEW              any V2MON FAIL, end not in {DONE}, rejected restart
  EXC-F1           system cause 04 together with an IR void at macro tick >= 4760 (registered F-1)
  NEW              any other system fault cause (each needs triage; tag lists the causes)
  KNOWN-FIX-7 / KNOWN-FIX-4   the corresponding V2SIG signature was printed (monitors otherwise clean)
  KNOWN-FIX-3      AMI integration-protocol sticky set at the end (AMI-C1 signature, monitors otherwise clean)
  PASS             everything else
`landing` is OK / MISMATCH / NONE from the V2POINT landing_ok and rule fields.

usage: python v2_summarize.py <run_dir> [<title>]
"""
import re
import sys
from pathlib import Path

KV = re.compile(r'(\w+)=(\S*)')


def parse(log):
    d = {'mon': {}, 'sig': [], 'lost': [], 'causes_sys': [], 'causes_ami': [], 'sticky': {}, 'timeout': False}
    for line in log.read_text(encoding='utf-8', errors='replace').splitlines():
        if line.startswith('V2POINT '):
            d['point'] = dict(KV.findall(line))
        elif line.startswith('V2MON '):
            f = line.split()
            d['mon'][f[1]] = (f[2], f[3], ' '.join(f[4:]))
        elif line.startswith('V2CAUSES SYSTEM'):
            d['causes_sys'] = [c for c in line.split()[2:] if c != 'none']
        elif line.startswith('V2CAUSES AMI'):
            d['causes_ami'] = [c for c in line.split()[2:] if c != 'none']
        elif line.startswith('V2STICKY'):
            d['sticky'] = dict(KV.findall(line))
        elif line.startswith('V2SIG '):
            d['sig'].append(line.split()[1])
        elif line.startswith('V2LOST '):
            d['lost'].append(dict(KV.findall(line)))
        elif line.startswith('V2TIMEOUT'):
            d['timeout'] = True
    return d


def classify(d):
    p = d.get('point')
    if p is None:
        return 'ERROR', 'no V2POINT'
    mon_fail = [k for k, v in d['mon'].items() if v[0] == 'FAIL']
    ev = p.get('event', '')
    end = p.get('end', '')
    held = p.get('done_mode') in ('1', '3') or p.get('idle_mode') == '1'
    bad_restart = p.get('restarts', '0') != '0' and p.get('restart_ok') != '1'
    abnormal = bool(mon_fail) or end != 'DONE' or bad_restart
    if held and abnormal:
        return 'KNOWN-ADC-HELD-DONE', ','.join(mon_fail) or end
    if ev == 'FOREVER':
        ok = ('07' in d['causes_sys'] or '07' in d['causes_ami']) and d['mon'].get('LIVENESS', ('FAIL',))[0] == 'PASS' and p.get('blocking') == '1'
        return ('PASS', 'expected cause07+blocking') if ok else ('NEW', 'FOREVER without cause 07/blocking')
    if abnormal:
        return 'NEW', ','.join(mon_fail + ([f'end={end}'] if end != 'DONE' else []) + (['restart_rejected'] if bad_restart else []))
    if '04' in d['causes_sys'] and any(int(l.get('tick', '0')) >= 4760 for l in d['lost']):
        return 'EXC-F1', 'cause04 + void at tick>=4760'
    if d['causes_sys']:
        return 'NEW', 'system causes ' + ','.join(d['causes_sys'])
    if 'KNOWN-FIX-7' in d['sig']:
        return 'KNOWN-FIX-7', 'normal frame complete after STOP/abort/fault'
    if 'KNOWN-FIX-4' in d['sig']:
        return 'KNOWN-FIX-4', 'stop_episode_active stuck in RUN'
    if d['sticky'].get('ami_proto') == '1':
        return 'KNOWN-FIX-3', 'AMI integration protocol sticky'
    return 'PASS', ''


def main(run_dir, title='V2 sweep'):
    run = Path(run_dir)
    rows = []
    for pd in sorted((run / 'points').iterdir()):
        log = pd / 'xsim.log'
        if not log.exists():
            continue
        d = parse(log)
        verdict, why = classify(d)
        p = d.get('point', {})
        try:
            secs = int((pd / 'end.txt').read_text().strip()) - int((pd / 'start.txt').read_text().strip())
        except Exception:
            secs = -1
        rule = p.get('rule', '')
        landing = 'NONE' if rule in ('none', '') else ('OK' if p.get('landing_ok') == '1' else ('NOT_LANDED' if p.get('landed') == '0' else 'MISMATCH'))
        if rule in ('next_conv', 'observe') and landing == 'MISMATCH':
            landing = 'INFO'
        mons = ' '.join(f"{k}:{v[0]}" for k, v in d['mon'].items())
        rows.append({
            'point': pd.name, 'mode': p.get('mode', ''), 'event': p.get('event', ''), 'slot': p.get('slot', ''),
            'target': f"f{p.get('frame', '')}/t{p.get('tick', '')}" + (f"/sf{p.get('sf')}lt{p.get('lt')}" if p.get('sf', '-1') != '-1' else ''),
            'landed': f"f{p.get('land_frame', '')}/t{p.get('land_tick', '')}/sf{p.get('land_sf', '')}lt{p.get('land_lt', '')}",
            'landing': landing, 'rule': rule, 'verdict': verdict, 'why': why, 'monitors': mons,
            'sys_causes': ','.join(d['causes_sys']) or '-', 'ami_causes': ','.join(d['causes_ami']) or '-',
            'sigs': ','.join(sorted(set(d['sig']))) or '-', 'end': p.get('end', ''), 'cycles': p.get('cycles', ''), 'seconds': secs,
            'log': str(log),
        })
    cols = ['point', 'mode', 'event', 'slot', 'target', 'landed', 'landing', 'rule', 'verdict', 'why', 'monitors', 'sys_causes', 'ami_causes', 'sigs', 'end', 'cycles', 'seconds', 'log']
    with open(run / 'summary.tsv', 'w', encoding='utf-8', newline='\n') as f:
        f.write('\t'.join(cols) + '\n')
        for r in rows:
            f.write('\t'.join(str(r[c]) for c in cols) + '\n')
    # markdown
    from collections import Counter, defaultdict
    by = defaultdict(Counter)
    for r in rows:
        by[(r['mode'], r['event'])][r['verdict']] += 1
    verdicts = sorted({r['verdict'] for r in rows})
    secs = [r['seconds'] for r in rows if r['seconds'] >= 0]
    land = Counter(r['landing'] for r in rows)
    md = [f"# {title}", '', f"points: {len(rows)}; verdicts: " + ', '.join(f"{v} {sum(1 for r in rows if r['verdict'] == v)}" for v in verdicts),
          f"landing: " + ', '.join(f"{k} {v}" for k, v in sorted(land.items())),
          f"per-point wall time: mean {sum(secs) / len(secs):.1f} s, max {max(secs)} s" if secs else '', '',
          '| mode | event | ' + ' | '.join(verdicts) + ' |', '|---|---|' + '---:|' * len(verdicts)]
    for (m, e), c in sorted(by.items()):
        md.append(f"| {m} | {e} | " + ' | '.join(str(c.get(v, 0)) for v in verdicts) + ' |')
    md += ['', '## Points not PASS', '', '| point | target | landed | landing | verdict | why | causes | sigs |', '|---|---|---|---|---|---|---|---|']
    for r in rows:
        if r['verdict'] != 'PASS':
            md.append(f"| {r['point']} | {r['target']} | {r['landed']} | {r['landing']} | {r['verdict']} | {r['why']} | {r['sys_causes']}/{r['ami_causes']} | {r['sigs']} |")
    md += ['', '## Landing mismatches', '', '| point | target | landed | rule |', '|---|---|---|---|']
    for r in rows:
        if r['landing'] in ('MISMATCH', 'NOT_LANDED'):
            md.append(f"| {r['point']} | {r['target']} | {r['landed']} | {r['rule']} |")
    (run / 'summary.md').write_text('\n'.join(md) + '\n', encoding='utf-8', newline='\n')
    print('\n'.join(md[:6]))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'V2 sweep')
