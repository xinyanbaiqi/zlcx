from pathlib import Path
import re, json, csv, collections
B = Path(__file__).resolve().parent
S = B / 'snapshot'
E = B / 'evidence'
O = E / 'global_closure_20261004'
O.mkdir(exist_ok=True)

# Reuse the skill's canonical AST. This script parses only Markdown references.
paths = collections.defaultdict(list)
for p in S.rglob('*.v'):
    paths[p.name].append(p)
modules = {}
for p in (E / 'gates').glob('*.json'):
    data = json.loads(p.read_text(encoding='utf-8'))
    for entry in data['quality_gate']['ast_report']['files']:
        for m in entry.get('modules', []):
            key = m['name'] if 'name' in m else m['module_name']
            modules[key + '.v'] = m

def check(lines, ports, name, direction, start, end):
    if name not in ports:
        return 'unresolved_port_mapping'
    if ports[name]['direction'] != direction:
        return 'direction_candidate'
    if start < 1 or end > len(lines) or end < start:
        return 'out_of_bounds'
    if not any(re.search(r'\b' + re.escape(name) + r'\b', l) for l in lines[start-1:end]):
        return 'confirmed_literal_mismatch'
    if 'line_start' in ports[name] and not start <= ports[name]['line_start'] <= end:
        return 'contains_name_outside_declaration_candidate'
    return 'literal_match'

# Four deliberately distinct mistakes; check that only these are reported.
fixture = ['input i_alpha;', 'output o_beta;', 'wire helper;']
fp = {'i_alpha': {'direction': 'input','line_start':1}, 'o_beta': {'direction': 'output','line_start':2}}
controls = [
    ('good', check(fixture, fp, 'i_alpha', 'input', 1, 1), 'literal_match'),
    ('wrong_line', check(fixture, fp, 'i_alpha', 'input', 2, 2), 'confirmed_literal_mismatch'),
    ('wrong_direction', check(fixture, fp, 'i_alpha', 'output', 1, 1), 'direction_candidate'),
    ('missing_port', check(fixture, fp, 'i_missing', 'input', 1, 1), 'unresolved_port_mapping'),
    ('out_of_bounds', check(fixture, fp, 'o_beta', 'output', 4, 4), 'out_of_bounds'),
    ('comment_only', check(fixture+['// i_alpha belongs elsewhere'],fp,'i_alpha','input',4,4),'contains_name_outside_declaration_candidate'),
]
assert all(actual == expected for _, actual, expected in controls), controls
reference_pattern = re.compile(r'([A-Za-z0-9_]+\.v):(\d+)(?:-(\d+))?')
negative_markdown = '| C02 | ref | input | `i_alpha` | `fixture.v:2` (declaration) | text |'
cc = [x.strip() for x in negative_markdown.split('|')]
assert re.fullmatch(r'`([A-Za-z0-9_]+)`', cc[4])[1] == 'i_alpha'
assert reference_pattern.search(cc[5]).groups() == ('fixture.v', '2', None)
(O / 'port_anchor_negative_controls.json').write_text(json.dumps(controls, ensure_ascii=False, indent=2), encoding='utf-8')

matrix = S / 'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md'
records = []
skipped = collections.Counter()
for number, line in enumerate(matrix.read_text(encoding='utf-8').splitlines(), 1):
    c = [x.strip() for x in line.split('|')]
    if len(c) < 7 or not re.fullmatch(r'C\d{2}', c[1]) or c[3] not in ('input', 'output', 'inout'):
        continue
    name_match = re.fullmatch(r'`([A-Za-z0-9_]+)`', c[4])
    if not name_match:
        skipped['grouped_or_nonliteral_port'] += 1
        continue
    if not ('声明' in c[5] or re.search(r'\b(?:input|output|inout)\b', c[5])):
        skipped['no_explicit_declaration_anchor'] += 1
        continue
    references = list(reference_pattern.finditer(c[5]))
    if not references:
        skipped['no_literal_rtl_reference'] += 1
        continue
    for ref in references:
        file, first, last = ref.groups()
        if file not in modules or len(paths[file]) != 1:
            skipped['missing_or_ambiguous_ast'] += 1
            continue
        target = paths[file][0]
        lines = target.read_text(encoding='utf-8').splitlines()
        ports = {p['name']: p for p in modules[file]['ports']}
        # Confirm every reused AST span against frozen source, never infer offsets.
        for p in ports.values():
            assert re.search(r'\b' + re.escape(p['name']) + r'\b', lines[p['line_start']-1]), (target, p)
        name = name_match[1]
        state = check(lines, ports, name, c[3], int(first), int(last or first))
        records.append(dict(source='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md', line=number,
            contract=c[1], direction=c[3], expected=name, reference=ref[0],
            state=state, current_declaration=ports.get(name, {}).get('line_start'),
            actual='\n'.join(lines[int(first)-1:int(last or first)]),
            target=target.relative_to(S).as_posix(), original_cell=c[5]))
assert records, 'No declaration rows extracted'
with (O / 'port_declaration_anchors.csv').open('w', encoding='utf-8-sig', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=list(records[0]))
    writer.writeheader(); writer.writerows(records)
summary = dict(canonical_ast_modules=len(modules), checked=len(records),
    counts=dict(collections.Counter(r['state'] for r in records)),
    skipped=dict(skipped), by_contract=dict(collections.Counter(r['contract'] for r in records)),
    limits='Only explicit declaration anchors with one literal port name; grouped, inherited or absent references require independent semantic review. Wrong direction/mapping are candidates, not confirmed functional findings.')
(O / 'port_declaration_summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(summary, ensure_ascii=False))
prior = list(csv.DictReader((E / 'anchor_failures.csv').read_text(encoding='utf-8-sig').splitlines()))
keys = {(r['source'], str(r['line']), r['reference'], r['expected']) for r in prior}
new = [r for r in records if r['state'] == 'confirmed_literal_mismatch'
       and (r['source'], str(r['line']), r['reference'], r['expected']) not in keys]
(O / 'new_port_anchor_mismatches.json').write_text(json.dumps(new, ensure_ascii=False, indent=2), encoding='utf-8')
print('NEW_COUNT', len(new))
print('NEW_SAMPLE', [(r['line'], r['expected'], r['reference'], r['current_declaration'], r['actual'][:100]) for r in new[:15]])
