# -*- coding: utf-8 -*-
"""The symbol a cell writes next to an anchor (brief section 3.13 Q1: the written
symbol governs over the line number).

Used twice:
  * anchor_manual_seed.py -- when converting an old line-number anchor, a symbol that the
    cell writes next to it overrides whatever the referenced line held (round 3);
  * anchor_check.py --semantic (default in the gate) -- in the converted documents, a
    symbol anchor `` `file.v` `S` `` must name the symbol the cell writes next to it.

`written_name(line, s, e, port=None)` looks at the text around the anchor span line[s:e]
and returns the written name, or None when the cell writes nothing there:

  W1  a backticked declaration right after the anchor:
      `` ... `output [7:0] o_system_fault_cause` `` -> o_system_fault_cause
  W2  "Mod.port（" right before the anchor            -> port
  W3  "Mod.port（... 声明" right before the anchor     -> port   (the declaration anchor)
  W4  "Top内部网`net`（" right before the anchor        -> net
  W5  "Top边界输入/输出（" right before the anchor, with the row's port column -> port
  W6  a backticked identifier right before "(" / "（" that opens the anchor's parenthesis
      -> that identifier
  W7  "(`name`," right before the anchor (same parenthesis) -> name
  W10 an instance port connection right after the anchor, optionally after "is":
      `` `ppg_control_top.v:932` is `.o_macro_frame_start_event()` `` -> o_macro_frame_start_event

`related(sym, port)` -- a symbol relates to the row's port when the i_/o_-stripped stems
are equal or one contains the other (a module port named differently from the Top port,
e.g. o_sequence_failed for o_recheck_sequence_failed).

Run directly for the self-test (constructed samples per rule plus negative cases).
"""
import re
import sys

ID = r'[A-Za-z_][A-Za-z0-9_]*'
DECL_AFTER = re.compile(r'^`?\s*`((?:input|output|inout|wire|reg|parameter|localparam|integer)\b[^`]*)`')
MOD_PORT = re.compile(r'(?:^|[^A-Za-z0-9_.`])(' + ID + r')\.(' + ID + r')（`?$')
MOD_PORT_DECL = re.compile(r'(?:^|[^A-Za-z0-9_.`])(' + ID + r')\.(' + ID + r')（[^（）|]{0,160}?声明`?$')
TOP_NET = re.compile(r'Top内部网`(' + ID + r')`（`?$')
TOP_EDGE = re.compile(r'Top边界(?:输入|输出)（`?$')
TICK_BEFORE_PAREN = re.compile(r'`(' + ID + r')`\s*[（(]`?$')
CONN_AFTER = re.compile(r'^`?\s*(?:is\s+)?`\.(' + ID + r')\s*\(')
SAME_PAREN = re.compile(r'[（(]`(' + ID + r')`\s*[,，、]\s*`?$')
KEYWORDS = {'input', 'output', 'inout', 'wire', 'reg', 'signed', 'parameter', 'localparam', 'integer'}


def decl_name(decl):
    """Name declared by a declaration text such as 'output [7:0] o_x' or 'parameter integer C_X = 5'."""
    d = re.sub(r'\[[^\]]*\]', ' ', decl)
    d = d.split('=')[0].split('//')[0]
    toks = [t for t in re.findall(ID, d) if t not in KEYWORDS]
    return toks[-1] if toks else None


def written_name(line, s, e, port=None):
    """(name, rule) written next to line[s:e], or (None, None)."""
    m = DECL_AFTER.match(line[e:])
    if m:
        n = decl_name(m.group(1))
        if n:
            return n, 'W1'
    m = CONN_AFTER.match(line[e:])
    if m:
        return m.group(1), 'W10'
    pre = line[max(0, s - 200):s]
    m = MOD_PORT.search(pre)
    if m:
        return m.group(2), 'W2'
    m = MOD_PORT_DECL.search(pre)
    if m:
        return m.group(2), 'W3'
    m = TOP_NET.search(pre)
    if m:
        return m.group(1), 'W4'
    if port and TOP_EDGE.search(pre):
        return port, 'W5'
    m = TICK_BEFORE_PAREN.search(pre)
    if m:
        return m.group(1), 'W6'
    m = SAME_PAREN.search(pre)
    if m:
        return m.group(1), 'W7'
    return None, None


def row_port(line):
    """Port / signal column (4th cell) of a ledger row such as | C01 | src | output | `o_x` | ..."""
    cols = line.split('|')
    if len(cols) > 5 and cols[3].strip() in ('input', 'output', 'inout'):
        m = re.match(r'`?(' + ID + r')', cols[4].strip())
        return m.group(1) if m else None
    return None


def carries(text, name):
    """True when Verilog source text declares `name` (input/output/inout/wire/reg) or
    connects it as an instance port `.name(` -- a file 'has' the row's port (W9/W9b)."""
    w = r'(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])' % re.escape(name)
    return (re.search(r'^\s*(?:input|output|inout|wire|reg)\b[^;/\n]*?' + w, text, re.M) is not None
            or re.search(r'\.\s*%s\s*\(' % re.escape(name), text) is not None)


def stem(name):
    return re.sub(r'^(?:i|o|io)_', '', name)


def related(sym, port):
    """True when sym and the row port share a stem (equal, or one contains the other)."""
    a, b = stem(sym), stem(port)
    return a == b or (len(b) >= 6 and b in sym) or (len(a) >= 8 and a in b)


# --------------------------------------------------------------------------- self-test
SAMPLES = [
    ('| C01 | src | output | `o_system_fault_cause` | `ppg_control_top.v:248` `output [7:0] o_system_fault_cause` | x |',
     'ppg_control_top.v:248', 'o_system_fault_cause', 'W1'),
    ('x `ppg_a.v:12` `parameter integer C_W = 5` y', 'ppg_a.v:12', 'C_W', 'W1'),
    ('AMI.i_transaction_sample_index（`ppg_control_top.v:1128`；声明`ppg_adc.v:128`）', 'ppg_control_top.v:1128', 'i_transaction_sample_index', 'W2'),
    ('AMI.i_transaction_sample_index（`ppg_control_top.v:1128`；声明`ppg_adc.v:128`）', 'ppg_adc.v:128', 'i_transaction_sample_index', 'W3'),
    ('Top内部网`analog_run_enable`（`:408`）→SSW', '`:408`', 'analog_run_enable', 'W4'),
    ('| C01 | src | input | `i_source_rstn` | Top边界输入（`ppg_control_top.v:99`，1） |', 'ppg_control_top.v:99', 'i_source_rstn', 'W5'),
    ('consumed by `flag_interval_hit` (`:178,249-250`) here', '`:178,249-250`', 'flag_interval_hit', 'W6'),
    ('same packed payload unpack (`coarse_valid_o`, `:949,2506`).', '`:949,2506`', 'coarse_valid_o', 'W7'),
    # negative: nothing written next to the anchor
    ('see `ppg_x.v:12` for details', 'ppg_x.v:12', None, None),
    ('Consumer: `assign o_x = y;` (`:1006`) -> AMI', '`:1006`', None, None),
    ('| C01 | src | input | `i_x` | wrapper.i_y（`ppg_top.v:5` `wire z` | x |', 'ppg_top.v:5', 'z', 'W1'),
    ('Consumer: **none** -- `ppg_control_top.v:932` is `.o_macro_frame_start_event()`, an open port', 'ppg_control_top.v:932',
     'o_macro_frame_start_event', 'W10'),
    ('Consumer: `ppg_control_top.v:1298` `.o_detector_idle()`, empty per contract', 'ppg_control_top.v:1298', 'o_detector_idle', 'W10'),
]
RELATED = [('o_sequence_failed', 'o_recheck_sequence_failed', True), ('i_cross_valid', 'o_cross_valid', True),
           ('o_protocol_error_sticky', 'o_baseline_protocol_error_sticky', True), ('o_waveform_frame_id', 'o_transaction_precision_mode', False),
           ('o_peak_valid', 'o_peak_pending', False), ('o_valid', 'o_cross_valid', False)]


def self_test():
    bad = 0
    for line, text, want, rule in SAMPLES:
        s = line.index(text)
        got = written_name(line, s, s + len(text), row_port(line))
        ok = got == (want, rule)
        bad += not ok
        print('%s %-28s %-4s -> %s' % ('OK  ' if ok else 'FAIL', want, rule, got))
    for a, b, want in RELATED:
        ok = related(a, b) == want
        bad += not ok
        print('%s related(%s, %s) = %s' % ('OK  ' if ok else 'FAIL', a, b, related(a, b)))
    print('samples %d, failures %d' % (len(SAMPLES) + len(RELATED), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(self_test())
