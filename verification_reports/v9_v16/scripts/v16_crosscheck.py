"""导出指定Git基线，按现有回归表生成/运行Icarus交叉检查。

默认只生成计划；--execute才运行。所有新文件限于任务报告目录。
不改导出的RTL/TB；结束时间用可选只读VPI观察器获取，缺失则不宣称一致。
需要Python 3.12或更新（tar安全提取），Icarus 11+及vvp；VPI需要iverilog-vpi。
"""

from __future__ import annotations

import argparse
import csv
from decimal import Decimal
import difflib
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
REPORT = ROOT / "verification_reports/v9_v16"
EVIDENCE = Path("verification_reports/b_merge_batch_evidence/final_5d8ceba")
LONG = {"tb_ppg_control_top_longrun", "tb_ppg_control_top_long_10_cycles"}
FAIL = re.compile(r"^FAIL|^\[FAIL\]|^\[[0-9]+\] [A-Z0-9-]+ FAIL|_TB_FAIL|REGRESSION FAIL|ERROR:|FATAL:|status=FAIL", re.M)
UNIT_FS = {"fs": 1, "ps": 1000, "ns": 10**6, "us": 10**9, "ms": 10**12, "s": 10**15}


def archive_command(commit: str) -> list[str]:
    """仅导出源码及比较证据，排除无关原始日志副本。"""
    paths = ["rtl", "tools"] + [(EVIDENCE / item).as_posix() for item in ["index.tsv", "system", "chip", "unit"]]
    return ["git", "archive", commit, *paths]


def physical_time(text: str) -> str | None:
    """将显式带单位的结束时间转为精确fs，不猜测裸整数的单位。"""
    match = re.search(r"([0-9]+(?:\.[0-9]+)?)\s*(fs|ps|ns|us|ms|s)\b", text)
    return str(Decimal(match[1]) * UNIT_FS[match[2]]) if match else None


def run_command(command: list[str], cwd: Path, log: Path, timeout: int) -> int | str:
    """保留完整工具日志；超时返回独立状态，不当作正常finish。"""
    with log.open("w", encoding="utf-8") as stream:
        try:
            return subprocess.run(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                                  timeout=timeout, check=False).returncode
        except subprocess.TimeoutExpired:
            stream.write("\nV16_HOST_TIMEOUT\n")
            return "HOST_TIMEOUT"
        except OSError as error:
            stream.write(f"\nV16_ENV_ERROR: {error}\n")
            return "ENV_ERROR"


def export_source(revision: str, run_root: Path) -> tuple[Path, str]:
    """以git archive导出不可覆盖的新源码目录，防止混用其他提交。"""
    commit = subprocess.check_output(["git", "rev-parse", revision + "^{commit}"], cwd=ROOT, text=True).strip()
    source = run_root / ("src_" + commit[:12])
    marker = run_root / ("src_" + commit[:12] + ".revision.txt")
    if source.exists():
        if not marker.exists() or marker.read_text().strip() != commit:
            raise ValueError("已有导出缺少完整提交标记，请使用新的--run-name，不覆盖源码")
        return source, commit
    archive = subprocess.check_output(archive_command(commit), cwd=ROOT)
    source.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive)) as stream:
        # Windows沙箱中tarfile严格realpath可能拒绝打开目录句柄；显式校验后只写普通文件。
        # 不接受链接/设备/绝对路径/..，并在写入前验证最终路径仍在新导出目录。
        for member in stream:
            relative = Path(member.name)
            if relative.is_absolute() or ".." in relative.parts or not (member.isdir() or member.isfile()):
                raise ValueError(f"拒绝不安全归档条目：{member.name}")
            target = (source / relative).resolve()
            if not target.is_relative_to(source.resolve()):
                raise ValueError(f"归档路径逃逸：{member.name}")
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with stream.extractfile(member) as incoming, target.open("xb") as output:
                    shutil.copyfileobj(incoming, output)
    marker.write_text(commit + "\n", encoding="utf-8")
    return source, commit


def get_cases(source: Path, archive_files: dict[str, bytes] | None = None) -> list[dict]:
    """只解析shell回归表及filelist路径，不解析Verilog源码。"""
    def read(path: Path) -> str:
        if archive_files is not None:
            return archive_files[path.relative_to(source).as_posix()].decode("utf-8-sig")
        return path.read_text(encoding="utf-8-sig")

    refs = list(csv.DictReader(io.StringIO(read(source / EVIDENCE / "index.tsv")), delimiter="\t"))
    system = read(source / "rtl/ppg_control_top/run_xsim_regression.sh")
    mapping = dict(re.findall(r"^\s*\[(tb_\w+)\]=(xsim_\w+\.f)\s*$", system, re.M))
    unit = {}
    table = read(source / "tools/run_unit_tb_regression.sh")
    for line in table.splitlines():
        match = re.match(r'^\s*"(tb_[^"]+)"\s*$', line)
        if match:
            name, group, tb_path, banner, deps = match[1].split("|", 4)
            unit[name] = [source / "rtl" / item for item in deps.split() + [tb_path]]
    cases = []
    for ref in refs:
        kind, name = ref["kind"], ref["tb"]
        if kind == "unit":
            paths = unit[name]
            entry = "tools/run_unit_tb_regression.sh TB_TABLE"
        else:
            folder = "ppg_control_top" if kind == "system" else "ppg_chip_digital_top"
            filelist = mapping[name] if kind == "system" else "xsim_chip_digital_top_filelist.f"
            base = source / "rtl" / folder
            paths = []
            for line in read(base / filelist).splitlines():
                item = line.strip()
                if item and not item.startswith(("#", "//")):
                    if item.startswith(("-", "+")):
                        raise ValueError(f"filelist选项需人工处理：{filelist}: {item}")
                    paths.append((base / item).resolve())
            entry = f"rtl/{folder}/{filelist}"
        paths = [path.resolve() for path in paths]
        for path in paths:
            exists = path.relative_to(source).as_posix() in archive_files if archive_files is not None else path.is_file()
            if not path.is_relative_to(source.resolve()) or not exists:
                raise ValueError(f"依赖不存在或逃逸导出目录：{path}")
        reference = source / EVIDENCE / kind / (name + ".pass_sorted.txt")
        pass_lines = read(reference).splitlines()
        if len(pass_lines) != int(ref["pass_lines"]):
            raise ValueError(f"参考PASS清单与index不一致：{name}")
        cases.append({"kind": kind, "tb": name, "entry": entry,
                      "source_files": [path.relative_to(source).as_posix() for path in paths],
                      "reference_pass_count": len(pass_lines), "reference_finish": ref["finish_time"],
                      "reference_finish_fs": physical_time(ref["finish_time"])})
    if len(cases) != 49 or len({case["tb"] for case in cases}) != 49:
        raise ValueError("本试跑应有49个唯一TB；RC1数量改变须显式更新参考及此预期")
    return cases


def execute_case(case: dict, source: Path, work: Path, timeout: int, vpi_module: Path | None) -> None:
    """从最低语言标准尝试编译，并保留排序PASS差异及精确结束时间。"""
    work.mkdir(parents=True, exist_ok=True)
    paths = [(source / item).resolve() for item in case["source_files"]]
    includes = sorted({str(path.parent) for path in paths})
    rc = None
    for standard in ["2001", "2005", "2005-sv", "2012"]:
        command = [shutil.which("iverilog"), "-o", str(work / "sim.vvp"), "-g" + standard, "-s", case["tb"]]
        for folder in includes:
            command.extend(["-I", folder])
        command.extend(map(str, paths))
        case.setdefault("compile_commands", []).append(command)
        rc = run_command(command, work, work / ("compile_" + standard + ".txt"), timeout)
        if rc == 0:
            case["language_standard"] = standard
            break
        if rc == "HOST_TIMEOUT":
            break
    case["compile"] = rc
    if rc != 0:
        case["classification"] = "编译不兼容或工具失败；须人工核对日志"
        return
    command = [shutil.which("vvp")]
    if vpi_module:
        command.extend(["-M", str(vpi_module.parent), "-m", vpi_module.stem])
    command.append(str(work / "sim.vvp"))
    case["run_command"] = command
    case["run"] = run_command(command, work, work / "run.txt", timeout)
    log = (work / "run.txt").read_text(encoding="utf-8", errors="replace")
    # 已核对49份参考均使用独立PASS单词口径；PASS:/[PASS]保留，_TB_PASS/PASSED不混入。
    actual = sorted(line.rstrip("\r") for line in log.splitlines() if re.search(r"\bPASS\b", line))
    expected = sorted((source / EVIDENCE / case["kind"] / (case["tb"] + ".pass_sorted.txt")).read_text(encoding="utf-8-sig").splitlines())
    (work / "actual.pass_sorted.txt").write_text("\n".join(actual) + ("\n" if actual else ""), encoding="utf-8")
    (work / "pass.diff.txt").write_text("\n".join(difflib.unified_diff(expected, actual, fromfile="xsim", tofile="iverilog")) + "\n", encoding="utf-8")
    case["pass_comparison"] = "MATCH" if expected == actual else "DIFF"
    case["actual_pass_count"] = len(actual)
    probe = re.findall(r"V16_FINISH ticks=(\d+) precision_exp=(-?\d+)", log)
    if len(probe) == 1:
        ticks, exponent = probe[0]
        case["actual_finish_fs"] = str(Decimal(ticks) * (Decimal(10) ** (15 + int(exponent))))
        case["finish_comparison"] = "MATCH" if Decimal(case["actual_finish_fs"]) == Decimal(case["reference_finish_fs"]) else "DIFF"
    else:
        case["finish_comparison"] = "UNAVAILABLE：无唯一VPI结束时间"
    case["fail_lines"] = len(FAIL.findall(log))
    matched = (case["run"] == 0 and case["fail_lines"] == 0 and case["pass_comparison"] == "MATCH" and case["finish_comparison"] == "MATCH")
    case["classification"] = "观测一致（不等于无RTL竞争）" if matched else "差异待人工分类：TB竞争/RTL竞争/仿真器语义/工具"


def main() -> int:
    """生成每TB计划；缺工具、未跑、比较缺失或未分类差异绝不算通过。"""
    global EVIDENCE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", default="66bebdf")
    parser.add_argument("--run-name", default="trial_66bebdf")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--include-long", action="store_true")
    parser.add_argument("--tb", action="append", help="可重复指定；其他TB仍明确列为未选")
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    parser.add_argument("--reference-dir", default=str(EVIDENCE), help="RC1需提供与源码完全对应的49-TB参考目录")
    args = parser.parse_args()
    # 参考路径必须为Git归档内的普通相对路径，禁止路径逃逸。
    EVIDENCE = Path(args.reference_dir)
    if EVIDENCE.is_absolute() or ".." in EVIDENCE.parts:
        parser.error("--reference-dir必须为仓库内相对目录")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.run_name) or args.timeout_seconds < 1:
        parser.error("run-name仅允许字母数字下划线横线，timeout必须为正数")
    run_root = REPORT / "runs" / args.run_name
    commit = subprocess.check_output(["git", "rev-parse", args.revision + "^{commit}"], cwd=ROOT, text=True).strip()
    archive = subprocess.check_output(archive_command(commit), cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(archive)) as stream:
        archive_files = {item.name: stream.extractfile(item).read() for item in stream if item.isfile()}
    # 缺工具时只在内存核对git archive，避免为了未跑任务落盘整套源码及长路径。
    run_root.mkdir(parents=True, exist_ok=True)
    source = (run_root / ("src_" + commit[:12])).resolve()
    cases = get_cases(source, archive_files)
    names = {case["tb"] for case in cases}
    if args.tb and not set(args.tb).issubset(names):
        parser.error("--tb包含未登记TB")
    tools = {name: shutil.which(name) for name in ["iverilog", "vvp", "iverilog-vpi"]}
    versions = {}
    usable = bool(tools["iverilog"] and tools["vvp"])
    if usable:
        version = subprocess.run([tools["iverilog"], "-V"], text=True, capture_output=True, check=False)
        versions["iverilog"] = version.stdout + version.stderr
        match = re.search(r"Icarus Verilog version\s+(\d+)", versions["iverilog"])
        usable = version.returncode == 0 and bool(match) and int(match[1]) >= 11
    if args.execute and usable:
        source, commit = export_source(args.revision, run_root)
        for name, data in archive_files.items():
            if hashlib.sha256((source / name).read_bytes()).digest() != hashlib.sha256(data).digest():
                raise ValueError(f"导出被改动或不完整，不允许混基线运行：{name}")
    vpi_module = None
    if args.execute and usable and tools["iverilog-vpi"]:
        vpi_dir = run_root / "vpi"
        vpi_dir.mkdir(parents=True, exist_ok=True)
        probe = Path(__file__).with_name("v16_finish_probe.c")
        rc = run_command([tools["iverilog-vpi"], str(probe)], vpi_dir, vpi_dir / "build.txt", 120)
        modules = list(vpi_dir.glob("v16_finish_probe.vpi"))
        if rc == 0 and len(modules) == 1:
            vpi_module = modules[0].resolve()
    for case in cases:
        case.update({"compile": "未跑", "run": "未跑", "pass_comparison": "未比较", "finish_comparison": "未比较", "classification": "未跑：计划模式"})
        if not usable:
            case["classification"] = "未跑：无可用Icarus 11+/vvp"
        elif args.tb and case["tb"] not in args.tb:
            case["classification"] = "未跑：未选"
        elif case["tb"] in LONG and not args.include_long:
            case["classification"] = "未跑：长跑默认跳过"
        elif args.execute:
            execute_case(case, source, run_root / case["tb"], args.timeout_seconds, vpi_module)
        print(case["tb"], case["classification"], flush=True)
    result = {"revision": commit, "reference_dir": EVIDENCE.as_posix(), "tools": tools, "versions": versions,
              "execute_requested": args.execute, "vpi_loaded": bool(vpi_module), "cases": cases}
    (run_root / "results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("results:", run_root / "results.json")
    return 0 if not args.execute else (0 if all(case["classification"].startswith("观测一致") for case in cases) else 1)


if __name__ == "__main__":
    raise SystemExit(main())
