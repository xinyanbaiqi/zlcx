"""Symbol-anchor checker for the closure matrix, the alias table and the contracts.

Usage:
    python anchor_check.py [--repo DIR] [--json OUT.json] [--no-ast] [FILE.md ...]

Default inputs: contracts/PPG_CONTRACT_CLOSURE_MATRIX.md,
contracts/PPG_ALIAS_MAPPING_TABLE.md and every other contracts/*.md.

What is checked (B merge batch brief, section 3.2):
  1. Symbol anchors  `<file>.v` `<name>`  (also .vh): the file exists in the
     repository and every following backticked name exists in that file at a
     word boundary; a backticked `"text"` token (TB check label or PASS text) must
     occur verbatim in that file. Port, parameter, localparam, declaration and instance names
     are taken from the erie-verilog-generator formatter AST when it parses the
     file; otherwise (or for other identifiers) a comment-aware word-boundary
     search of the source is used. `@satisfies: ID` anchors require the tag to
     be present in a `//` comment of that file.
  2. Contract section references  `Cxx §x.y`  and  `<CONTRACT>.md` §x.y : the
     contract exists and has a heading with that number. When the number is
     duplicated in that contract, the reference must also carry the heading
     title (the text after the number) so that it is unique.
  3. Line-number anchors (old format, `file.v:N`, `file.md:N`, `Cxx:N`,
     `MATRIX:N`, `alias:N`) are errors in the matrix and the alias table unless
     the line is history: inside ~~strikethrough~~, or listed (by SHA-1 of the
     stripped line) in anchor_history_allowlist.json. In contracts they are
     reported as information only (contract change records are history).
  4. Memory references ([[...]] and memory `....md`) are repository-external;
     they are listed and never counted as errors.

Exit status: 0 when no error is found, 1 otherwise.
"""
import argparse
import glob
import hashlib
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from anchor_semantics import written_name, row_port  # noqa: E402
RENAMED = {'i_status_clear_event': 'i_diag_clear_event'}  # F-032 port rename after the anchor was written
WALK_SKIP_DIRS = {'.git', '__pycache__', '.claude'}  # directory-walk index: no git metadata, bytecode or skill tree
C_MAP_SECTION = '## 2. Active Contract Sources and Source Classification'

FILE_TOKEN = re.compile(r'`([A-Za-z0-9_./-]+\.(?:v|vh))`')
NAME_TOKEN = re.compile(r'\s*(?:[、,，/+]|and|和|及)?\s*`([^`]+)`')
IDENT = re.compile(r'^[A-Za-z_][A-Za-z0-9_$]*(?:\[[^\]]*\])?$')
SAT_TAG = re.compile(r'^@satisfies:\s*([A-Za-z0-9_-]+(?:\s*,\s*[A-Za-z0-9_-]+)*)$')
LABEL = re.compile(r'^"([^"`]{3,})"$')  # TB check label / PASS text, matched verbatim in the source
CSEC = re.compile(r'(?<![A-Za-z0-9])(C\d\d)\s*§\s*(\d+(?:\.\d+)*[a-z]?)((?:\s+[^\s，。；;,|）)]+)?)')
MDSEC = re.compile(r'`?((?:[A-Za-z0-9_/]+/)?[A-Za-z0-9_]+\.md)`?\s*§\s*(\d+(?:\.\d+)*[a-z]?)')
OLD_ANCHOR = re.compile(
    r'(?:[A-Za-z0-9_]+\.(?:v|vh|md|sh|py)`?\s*:\s*\d+'
    r'|(?<![A-Za-z0-9])C\d\d\s*:\s*\d+'
    r'|(?<![A-Za-z0-9])(?:MATRIX|matrix|alias|ALIAS)(?:\.md)?\s*:\s*\d+)')
MEMORY = re.compile(r'\[\[[^\]]+\]\]|memory\s*`[^`]+\.md`')
HEADING = re.compile(r'^(#{1,6})\s+(?:§\s*)?(\d+(?:\.\d+)*[a-z]?)[.\s]\s*(.*)$')


def load_contract_ids(repo):
    """Map C01..C25 to contract file names using the matrix section-2 table."""
    path = os.path.join(repo, 'contracts', 'PPG_CONTRACT_CLOSURE_MATRIX.md')
    ids = {}
    for line in open(path, encoding='utf-8').read().split('\n'):
        m = re.match(r'^\| (C\d\d) \| `(?:[a-z_/]+/)?([A-Za-z0-9_]+\.md)`', line)
        if m and m.group(1) not in ids:
            ids[m.group(1)] = m.group(2)
    return ids


def load_headings(md_path):
    """Return {number: [title, ...]} for every numbered heading."""
    out = {}
    for line in open(md_path, encoding='utf-8').read().split('\n'):
        m = HEADING.match(line)
        if m:
            out.setdefault(m.group(2), []).append(m.group(3).strip())
    return out


class SourceIndex:
    """Name lookup for one Verilog file."""

    def __init__(self, path, use_ast):
        self.path = path
        text = open(path, encoding='utf-8', errors='replace').read()
        self.raw_text = text
        self.code = []
        self.comments = []
        for line in text.split('\n'):
            code, _, comment = self._split(line)
            self.code.append(code)
            self.comments.append(comment)
        self.code_text = '\n'.join(self.code)
        self.comment_text = '\n'.join(self.comments)
        self.ast_names = set()
        self.ast_ok = False
        if use_ast:
            self._load_ast()

    @staticmethod
    def _split(line):
        quoted = False
        for i, ch in enumerate(line):
            if ch == '"' and (i == 0 or line[i - 1] != '\\'):
                quoted = not quoted
            if not quoted and line.startswith('//', i):
                return line[:i], '//', line[i + 2:]
        return line, '', ''

    def _load_ast(self):
        skill = os.path.join(os.path.dirname(HERE), '..', '.claude', 'skills', 'erie-verilog-generator')
        skill = os.path.abspath(skill)
        if skill not in sys.path:
            sys.path.insert(0, skill)
        try:
            from pathlib import Path
            from scripts.python.quality.formatter_ast import build_ast_report_for_path
            report = build_ast_report_for_path(Path(self.path))
        except Exception:  # formatter limits on some legal TB forms are documented
            return
        for module in report.get('modules', []):
            for key in ('ports', 'params', 'localparams', 'decls', 'instances'):
                for item in module.get(key, []) or []:
                    for field in ('name', 'instance_name', 'names'):
                        value = item.get(field)
                        if isinstance(value, str) and value:
                            self.ast_names.add(value)
                        elif isinstance(value, list):
                            self.ast_names.update(v for v in value if isinstance(v, str))
        self.ast_ok = True

    def has_name(self, name):
        base = re.sub(r'\[.*\]$', '', name)
        if base in self.ast_names:
            return 'ast'
        if re.search(r'(?<![A-Za-z0-9_$])' + re.escape(base) + r'(?![A-Za-z0-9_$])', self.code_text):
            return 'text'
        return None

    def has_satisfies(self, ident):
        pat = r'@satisfies:[^\n]*?(?<![A-Za-z0-9_-])' + re.escape(ident) + r'(?![A-Za-z0-9_-])'
        return re.search(pat, self.comment_text) is not None


def strike_spans(line):
    spans = []
    pos = 0
    while True:
        a = line.find('~~', pos)
        if a < 0:
            break
        b = line.find('~~', a + 2)
        if b < 0:
            break
        spans.append((a, b + 2))
        pos = b + 2
    return spans


def in_spans(i, spans):
    return any(a <= i < b for a, b in spans)


def line_hash(line):
    return hashlib.sha1(line.strip().encode('utf-8')).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=os.path.abspath(os.path.join(HERE, '..', '..')))
    ap.add_argument('--json')
    ap.add_argument('--no-ast', action='store_true')
    ap.add_argument('--index', choices=('auto', 'git', 'walk'), default='auto',
                    help='file index: git ls-files, a directory walk, or auto (git, else walk when '
                         'the tree is not a git checkout, e.g. a `git archive` export)')
    ap.add_argument('--no-semantic', action='store_true',
                    help='skip the semantic mode (anchor symbol vs the symbol the cell writes next to it)')
    ap.add_argument('files', nargs='*')
    args = ap.parse_args()
    repo = args.repo
    contracts_dir = os.path.join(repo, 'contracts')
    gated = {'PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md'}
    files = args.files or sorted(glob.glob(os.path.join(contracts_dir, '*.md')))
    allow_path = os.path.join(HERE, 'anchor_history_allowlist.json')
    allow = set(json.load(open(allow_path, encoding='utf-8'))['line_sha1']) if os.path.exists(allow_path) else set()

    # repository file index by base name: `git ls-files` in a checkout; in a
    # `git archive` export (the regression machine runs there, brief section 6.8)
    # there is no git metadata, so walk the tree instead -- an export holds exactly
    # the tracked files.
    tracked, index_source = [], args.index
    if args.index in ('auto', 'git'):
        res = subprocess.run(['git', '-C', repo, 'ls-files'], capture_output=True)
        tracked = [t for t in res.stdout.decode('utf-8').split('\n') if t] if res.returncode == 0 else []
        index_source = 'git'
    if args.index == 'walk' or (args.index == 'auto' and not tracked):
        tracked, index_source = [], 'walk'
        for dirpath, dirnames, filenames in os.walk(repo):
            dirnames[:] = sorted(d for d in dirnames if d not in WALK_SKIP_DIRS)
            for fn in sorted(filenames):
                tracked.append(os.path.relpath(os.path.join(dirpath, fn), repo).replace(os.sep, '/'))
    by_base = {}
    for rel in tracked:
        if rel:
            by_base.setdefault(os.path.basename(rel), []).append(rel)
    cid = load_contract_ids(repo)
    heading_cache = {}
    src_cache = {}

    def headings(name):
        if name not in heading_cache:
            path = os.path.join(contracts_dir, name)
            heading_cache[name] = load_headings(path) if os.path.exists(path) else None
        return heading_cache[name]

    def source(rel):
        if rel not in src_cache:
            src_cache[rel] = SourceIndex(os.path.join(repo, rel), not args.no_ast)
        return src_cache[rel]

    errors, infos, external = [], [], []
    stats = {'symbol_anchors': 0, 'satisfies_anchors': 0, 'label_anchors': 0, 'section_refs': 0, 'old_anchor_history': 0,
             'semantic_checked': 0}
    sem_path = os.path.join(HERE, 'anchor_semantic_exceptions.json')
    sem_exceptions = set((x['line_sha1'], x['anchor']) for x in json.load(open(sem_path, encoding='utf-8'))['exceptions']) \
        if os.path.exists(sem_path) else set()

    def err(f, n, kind, text):
        errors.append({'file': os.path.basename(f), 'line': n, 'kind': kind, 'text': text})

    for f in files:
        base = os.path.basename(f)
        lines = open(f, encoding='utf-8').read().split('\n')
        for n, line in enumerate(lines, 1):
            spans = strike_spans(line)
            for m in MEMORY.finditer(line):
                external.append({'file': base, 'line': n, 'ref': m.group(0)})
            # 1. symbol anchors
            for fm in FILE_TOKEN.finditer(line):
                if in_spans(fm.start(), spans):
                    continue
                fname = os.path.basename(fm.group(1))
                pos = fm.end()
                names = []
                while True:
                    nm = NAME_TOKEN.match(line, pos)
                    if not nm:
                        break
                    tok = nm.group(1).strip()
                    if not (IDENT.match(tok) or SAT_TAG.match(tok) or LABEL.match(tok)):
                        break
                    names.append(tok)
                    pos = nm.end()
                if not names:
                    continue
                # 1b. semantic mode (coordinator review 2026-10-10): the anchor must name
                # the symbol the cell writes next to it (declaration text, "Mod.port（",
                # "Top内部网`x`（", Top boundary + row port, name opening its parenthesis)
                if base in gated and not args.no_semantic:
                    idents = [t for t in names if IDENT.match(t)]
                    wn, rule = written_name(line, fm.start(), pos, row_port(line))
                    if idents and wn and not wn.startswith('_'):
                        stats['semantic_checked'] += 1
                        clause = line[max(line.rfind('|', 0, fm.start()) + 1, fm.start() - 150):fm.start()]
                        ok = (wn in idents or RENAMED.get(wn) in idents
                              or (rule in ('W6', 'W7') and any(re.search(r'(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])' % re.escape(t), clause) for t in idents))
                              or (line_hash(line), line[fm.start():pos]) in sem_exceptions)
                        if not ok:
                            err(f, n, 'symbol-mismatch', '%s %s but the cell writes `%s` (%s)' % (fname, '/'.join(idents), wn, rule))
                cands = [r for r in by_base.get(fname, []) if not r.startswith('legacy/')]
                if len(cands) != 1:
                    err(f, n, 'file-missing' if not cands else 'file-ambiguous', fname)
                    continue
                src = source(cands[0])
                for tok in names:
                    sm = SAT_TAG.match(tok)
                    lm = LABEL.match(tok)
                    if lm:
                        stats['label_anchors'] += 1
                        if lm.group(1) not in src.raw_text:
                            err(f, n, 'label-missing', '%s "%s"' % (fname, lm.group(1)))
                    elif sm:
                        for ident in re.split(r'\s*,\s*', sm.group(1)):
                            stats['satisfies_anchors'] += 1
                            if not src.has_satisfies(ident):
                                err(f, n, 'satisfies-missing', '%s @satisfies %s' % (fname, ident))
                    else:
                        stats['symbol_anchors'] += 1
                        if not src.has_name(tok):
                            err(f, n, 'name-missing', '%s %s' % (fname, tok))
            # 2. contract section references
            for sm in CSEC.finditer(line):
                if in_spans(sm.start(), spans):
                    continue
                stats['section_refs'] += 1
                name = cid.get(sm.group(1))
                hd = headings(name) if name else None
                if hd is None:
                    err(f, n, 'contract-missing', sm.group(1))
                    continue
                num, title = sm.group(2), sm.group(3).strip()
                if num not in hd:
                    err(f, n, 'section-missing', '%s §%s' % (sm.group(1), num))
                elif len(hd[num]) > 1 and not any(title and t.startswith(title[:8]) for t in hd[num]):
                    err(f, n, 'section-ambiguous', '%s §%s needs a heading title (%s)' % (sm.group(1), num, ' / '.join(hd[num])))
            for mm in MDSEC.finditer(line):
                if in_spans(mm.start(), spans):
                    continue
                name = os.path.basename(mm.group(1))
                if not name.startswith(('PPG_', 'ppg_', 'TAPEOUT')):
                    continue
                stats['section_refs'] += 1
                hd = headings(name)
                if hd is None:
                    err(f, n, 'contract-missing', name)
                elif mm.group(2) not in hd:
                    err(f, n, 'section-missing', '%s §%s' % (name, mm.group(2)))
            # 3. old line anchors
            olds = [om for om in OLD_ANCHOR.finditer(line) if not in_spans(om.start(), spans)]
            if olds:
                if base in gated and line_hash(line) not in allow:
                    for om in olds:
                        err(f, n, 'line-anchor', om.group(0))
                else:
                    stats['old_anchor_history'] += len(olds)
                    if base not in gated:
                        infos.append({'file': base, 'line': n, 'kind': 'contract-line-anchor', 'count': len(olds)})

    result = {'errors': errors, 'external_refs': external, 'stats': stats,
              'files': [os.path.basename(f) for f in files], 'info_count': len(infos)}
    if args.json:
        json.dump(result, open(args.json, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    for e in errors:
        print('ERROR %(file)s:%(line)d %(kind)s %(text)s' % e)
    print('stats %s; external refs %d; errors %d; file index %s (%d files)'
          % (json.dumps(stats), len(external), len(errors), index_source, len(tracked)))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
