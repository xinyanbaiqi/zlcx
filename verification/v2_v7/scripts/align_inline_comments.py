#!/usr/bin/env python3
"""V2/V7 framework helper: align same-line // comments to the erie_strict region anchor (VG060).

Uses the column helpers of the bundled erie-verilog-generator quality gate so that the
alignment rule is exactly the one the gate checks: inside a region banner, a same-line
comment starts at the banner's right-hand // display column, or one column after the
code when the code is already wider than the anchor.

Only whitespace between the code and the // marker is changed; code tokens are untouched.

Usage: python align_inline_comments.py <file.v|file.sv> [...]
"""
import sys
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parents[3] / ".claude" / "skills" / "erie-verilog-generator"
sys.path.insert(0, str(SKILL_ROOT))

from scripts.python.quality import quality_gate as qg  # noqa: E402


def align_text(text: str) -> str:
    lines = text.split("\n")
    anchor = None
    out = []
    for line in lines:
        banner = qg._region_banner_anchor_column(line)
        if banner is not None:
            anchor = banner
            out.append(line)
            continue
        if anchor is None or not qg._is_code_line(line):
            out.append(line)
            continue
        idx = qg._line_comment_start(line)
        if idx < 0:
            out.append(line)
            continue
        code = line[:idx].rstrip()
        comment = line[idx:]
        width = qg._display_width_with_tabs(code)
        target = anchor if width < anchor else width + 1
        pad = target - width
        out.append(code + " " * pad + comment)
    return "\n".join(out)


def main(argv):
    for name in argv[1:]:
        path = Path(name)
        src = path.read_text(encoding="utf-8")
        dst = align_text(src)
        if dst != src:
            path.write_text(dst, encoding="utf-8", newline="\n")
            print(f"aligned {path}")
        else:
            print(f"unchanged {path}")


if __name__ == "__main__":
    main(sys.argv)
