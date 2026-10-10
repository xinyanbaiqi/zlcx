"""Prove that Verilog edits touch only comments (and, with --strings, string literals).

Usage:
    python strip_compare.py [--strings] <git-rev> <file> [<file> ...]

For every file, the version at <git-rev> and the working-tree version are both
reduced by removing `//` line comments and `/* */` block comments (and, with
--strings, replacing the content of every "..." string literal by an empty
string). Whitespace-only lines are dropped, so a whole-line comment that is added
or removed leaves no trace. The reduced texts must be byte-identical. Line endings are normalised
to LF before reduction so that CRLF checkouts compare equal.

Exit status: 0 when every file is identical after reduction, 1 otherwise.
Used by the B merge batch (B_MERGE_BATCH_BRIEF_20261009.md section 6.4 and 0.3):
TB label renames are checked with --strings, RTL comment edits without it.
"""
import subprocess
import sys


def reduce_text(text, drop_strings):
    """Remove comments (and optionally string contents) with a small lexer."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == '"':
            # string literal: copy delimiters, optionally drop the body
            j = i + 1
            while j < n and text[j] != '"' and text[j] != '\n':
                j += 2 if text[j] == '\\' else 1
            body = text[i + 1:j]
            out.append('""' if drop_strings else '"' + body + '"')
            i = j + 1
        elif text.startswith('//', i):
            j = text.find('\n', i)
            i = n if j < 0 else j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            i = n if j < 0 else j + 2
        else:
            out.append(ch)
            i += 1
    # trailing blanks left behind by removed comments are not significant, and neither
    # are the empty lines left by added or removed whole-line comments (for example a
    # new change-log entry in the file header)
    return '\n'.join(line.rstrip() for line in ''.join(out).split('\n') if line.strip())


def main():
    args = sys.argv[1:]
    drop_strings = False
    if args and args[0] == '--strings':
        drop_strings = True
        args = args[1:]
    if len(args) < 2:
        print(__doc__)
        return 2
    rev, files = args[0], args[1:]
    bad = 0
    for path in files:
        rel = path.replace('\\', '/')
        old = subprocess.run(['git', 'show', '%s:%s' % (rev, rel)], capture_output=True)
        if old.returncode != 0:
            print('MISSING-AT-REV %s' % rel)
            bad += 1
            continue
        old_txt = old.stdout.decode('utf-8').replace('\r\n', '\n')
        new_txt = open(path, encoding='utf-8').read().replace('\r\n', '\n')
        same = reduce_text(old_txt, drop_strings) == reduce_text(new_txt, drop_strings)
        changed = old_txt != new_txt
        print('%s %s (raw %s)' % ('IDENTICAL' if same else 'DIFFERENT', rel,
                                  'changed' if changed else 'unchanged'))
        bad += 0 if same else 1
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
