# -*- coding: utf-8 -*-
"""Which old line-number anchors are history (kept verbatim) and which are converted.

Rule set of the coordinator's ruling of 2026-10-09 on report section 9-1 (it replaces
the earlier "a date earlier in the same cell makes it history" rule, which came from an
ambiguous wording in the brief):

  history-strike      class 1: inside ~~strikethrough~~ with nothing after it in the cell
  history-superseded-struck
                      class 3 (and 1): a struck old entry followed, in the same cell, by the
                      later entry that replaces it ("~~old~~ **new**"); counted as class 3
  history-block       the line is a "> " block (errata / explanation block)
  history-revision    the line lies in a revision-record section (heading names a
                      revision / change record / history)
  history-superseded  the anchor is in an older entry of the same cell that a later
                      entry of that cell explicitly declares superseded / void
  (None)              everything else is converted -- dated current conclusions
                      ("CLOSED 2026-09-07 ...", "2026-09-16重建 ...", "2026-09-16新增行 ...",
                      evidence chains after "... 复核确认 ...") included

When in doubt the anchor is converted ("resolving at the written-at version loses no
information; keeping the old line number is what does harm"). Doubtful cases -- a later
dated correction/addendum in the same cell that does not explicitly void the earlier
entry -- are converted and flagged `uncertain` so they can be counted and listed.

Run this file directly for the self-test (constructed samples for every class,
including the negative cases); exit status 0 only when every sample is classified as
expected.
"""
import re
import sys

DATE = re.compile(r'20\d\d-\d\d-\d\d|20\d\d年\d+月\d+日|20\d\d/\d\d/\d\d')
REVISION_HEADING = re.compile(r'修订记录|变更记录|修订历史|版本记录|[Cc]hange [Rr]ecord|[Cc]hange [Ll]og|'
                              r'[Rr]evision [Hh]istory|^#+\s*History\b')
# an explicit statement, later in the same cell, that the earlier entry no longer holds
SUPERSEDED = re.compile(r'(以上|上述|前述|此前|前一条|该条|本条)[^|。]{0,24}?(作废|不成立|已被[^|。]{0,24}?取代|已撤回|已废止)'
                        r'|[Ss]uperseded\b|no longer (?:valid|holds|applies)')
CORRECTION = re.compile(r'勘误|订正|更正|纠正|补记|补充|取代|改判|corrected|errat')


def heading_of(lines, n):
    """Nearest markdown heading at or above line n (1-based)."""
    for i in range(min(n, len(lines)) - 1, -1, -1):
        if lines[i].startswith('#'):
            return lines[i]
    return ''


def cell_bounds(line, pos):
    if not line.lstrip().startswith('|'):
        return 0, len(line)
    a = line.rfind('|', 0, pos) + 1
    b = line.find('|', pos)
    return a, (len(line) if b < 0 else b)


def classify_struck(line, pos):
    """For an anchor inside ~~strikethrough~~ (class 1 or class 3 of the ruling):
    'history-superseded-struck' when the struck old entry is followed, in the same cell,
    by a later entry that replaces it (text after the closing ~~); 'history-strike'
    when nothing follows it in the cell."""
    a, b = cell_bounds(line, pos)
    close = line.find('~~', pos)
    after = line[close + 2:b] if 0 <= close < b else ''
    if re.search(r'[A-Za-z0-9一-鿿]', after):
        return 'history-superseded-struck'
    return 'history-strike'


def classify(lines, n, pos, end):
    """(status or None, uncertain) for the anchor at lines[n-1][pos:end]."""
    line = lines[n - 1]
    if line.lstrip().startswith('>'):
        return 'history-block', False
    if REVISION_HEADING.search(heading_of(lines, n)):
        return 'history-revision', False
    a, b = cell_bounds(line, pos)
    after = line[end:b]
    if SUPERSEDED.search(after):
        return 'history-superseded', False
    uncertain = any(CORRECTION.search(after[m.start():m.start() + 120]) for m in DATE.finditer(after))
    return None, uncertain


# --------------------------------------------------------------------------- self-test
SAMPLES = [
    # (lines, line number, anchor text, expected status, expected uncertain)
    (['## 12.5 ledger', '| C01 | ~~old~~ **2026-09-16重建**：Top端口（`ppg_control_top.v:244`） |'],
     2, 'ppg_control_top.v:244', None, False),
    (['## 11', '| P05 | **CLOSED 2026-09-07**：证据`ppg_x.v:12` |'], 2, 'ppg_x.v:12', None, False),
    (['## 11', '| N06 | 2026-09-28复核确认：`ppg_x.v:30`、`:31` |'], 2, 'ppg_x.v:30', None, False),
    (['## 12.5', '> **2026-09-16 recheck -- errata.** see `ppg_control_top.v:12`'], 2, 'ppg_control_top.v:12', 'history-block', False),
    (['## 12.5', '>   half): re-verified against `ppg_m.v:528-538`'], 2, 'ppg_m.v:528-538', 'history-block', False),
    (['### 修订记录', '| V1.2 | 2026-09-01 | 改`C10:44` |'], 2, 'C10:44', 'history-revision', False),
    (['## Change record', '- 2026-09-01: moved `ppg_x.v:9`'], 2, 'ppg_x.v:9', 'history-revision', False),
    (['## 12.5', '| X | 2026-09-10：`ppg_x.v:5`；2026-09-16 上述结论不成立，见新行 |'], 2, 'ppg_x.v:5', 'history-superseded', False),
    (['## 12.5', '| X | 2026-09-10: `ppg_x.v:5` (superseded by row Y) |'], 2, 'ppg_x.v:5', 'history-superseded', False),
    (['## 12.5', '| X | `ppg_x.v:5`；**2026-09-30补记**：另见C01 V1.16勘误 |'], 2, 'ppg_x.v:5', None, True),
    (['## 12.5', '| X | `ppg_x.v:5` | 2026-09-30勘误：另一格 |'], 2, 'ppg_x.v:5', None, False),
    (['## 12.5', '| X | 上述作废的说明在另一格 | `ppg_x.v:5` |'], 2, 'ppg_x.v:5', None, False),
    (['## 历史', '| X | 2026-09-10 `ppg_x.v:5` |'], 2, 'ppg_x.v:5', None, False),
]


STRUCK_SAMPLES = [
    # (line, anchor text, expected)
    ('| C01 | ~~old `ppg_x.v:9` ledger~~ **2026-09-16重建**：Top端口 |', 'ppg_x.v:9', 'history-superseded-struck'),
    ('| P05 | ~~SUP06A `ppg_x.v:9`~~ SUP06B/C |', 'ppg_x.v:9', 'history-superseded-struck'),
    ('| X | ~~`ppg_x.v:9` removed~~ |', 'ppg_x.v:9', 'history-strike'),
    ('| X | ~~`ppg_x.v:9`~~ | next cell text |', 'ppg_x.v:9', 'history-strike'),
]


def self_test():
    bad = 0
    for line, text, want in STRUCK_SAMPLES:
        got = classify_struck(line, line.index(text))
        ok = got == want
        bad += not ok
        print('%s %-26s -> %s' % ('OK  ' if ok else 'FAIL', want, got))
    for lines, n, text, want, want_u in SAMPLES:
        pos = lines[n - 1].index(text)
        got, unc = classify(lines, n, pos, pos + len(text))
        ok = (got == want and unc == want_u)
        bad += not ok
        print('%s %-20s %-6s -> %s%s' % ('OK  ' if ok else 'FAIL', want or 'convert', 'unc' if want_u else '',
                                        got or 'convert', ' (uncertain)' if unc else ''))
    print('samples %d, failures %d' % (len(SAMPLES) + len(STRUCK_SAMPLES), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(self_test())
