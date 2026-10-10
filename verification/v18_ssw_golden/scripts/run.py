"""V18 可复用仿真入口：黄金先冻结，SSW仅作为编译器参数，不扫描其目录。"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

TASK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TASK / "golden"))
from model import OUTPUTS, generate, load_windows
from compare import compare


def execute(command: list[str], cwd: Path, log: Path, timeout: int = 120) -> str:
    """工具日志落盘；异常只报告位置，不回显可能含RTL源码的诊断上下文。"""
    process = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             encoding="utf-8", errors="replace", timeout=timeout)
    log.write_text(process.stdout, encoding="utf-8")
    version_only = command[-1] in {"--version", "-V"} and "Vivado Simulator" in process.stdout
    if process.returncode and not version_only:
        raise RuntimeError(f"tool failed ({process.returncode}), inspect allowed diagnostics: {log}")
    return process.stdout


def executable(binary: Path | None, name: str) -> str:
    """同一入口支持Windows批处理和Linux可执行文件。"""
    if binary is None:
        return name
    path = binary / (name + ".bat" if os.name == "nt" else name)
    if not path.exists():
        path = binary / name
    return str(path)


def main() -> int:
    """生成所有独立场景，再编译一次，每个场景单独重置和采集。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=TASK.parents[1])
    parser.add_argument("--simulator", choices=("xsim", "iverilog"), default="xsim")
    parser.add_argument("--simulator-bin", type=Path)
    parser.add_argument("--ssw-rtl", type=Path)
    parser.add_argument("--sar9-template", type=Path)
    parser.add_argument("--sar15-template", type=Path)
    parser.add_argument("--scenarios", type=Path, default=TASK / "scenarios" / "matrix.json")
    parser.add_argument("--select", help="场景名子串过滤")
    parser.add_argument("--out", type=Path, default=TASK / "_runs" / "trial")
    parser.add_argument("--generate-only", action="store_true")
    parser.add_argument("--jobs", type=int, default=1, help="独立快照并行仿真数，默认串行")
    args = parser.parse_args()
    repo, out = args.repo.resolve(), args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sar9 = args.sar9_template or repo / "rtl/ppg_timing_sar9/ppg_timing_sar9.v"
    sar15 = args.sar15_template or repo / "rtl/ppg_timing_sar15/ppg_timing_sar15.v"
    profiles, provenance = load_windows(sar9, sar15)
    (out / "window_provenance.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2), encoding="utf-8")
    scenarios = json.loads(args.scenarios.read_text(encoding="utf-8"))
    selected = [case for case in scenarios if not args.select or args.select in case["name"]]
    if not selected:
        raise ValueError("选择器没有命中场景")
    metadata = {case["name"]: generate(case, profiles, out / case["name"]) for case in selected}
    if args.generate_only:
        print(f"Generated {len(selected)} independent scenarios")
        return 0
    sswr = args.ssw_rtl or repo / "rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v"
    # 严格独立性：这里不open/read/hash/parse被测SSW路径，只传给仿真编译进程。
    tb = TASK / "tb/tb_v18_ssw_golden.v"
    build = out / "build"
    build.mkdir(exist_ok=True)
    binary = args.simulator_bin
    if args.simulator == "xsim":
        version = execute([executable(binary, "xsim"), "--version"], build, out / "simulator_version.log")
        execute([executable(binary, "xvlog"), str(sswr), str(tb)], build, build / "compile.log")
        execute([executable(binary, "xelab"), "tb_v18_ssw_golden", "-s", "v18_pins"], build, build / "elaborate.log")
    else:
        version = execute([executable(binary, "iverilog"), "-V"], build, out / "simulator_version.log")
        execute([executable(binary, "iverilog"), "-g2005", "-s", "tb_v18_ssw_golden", "-o", "v18.vvp", str(sswr), str(tb)], build, build / "compile.log")
    def run_case(case: dict) -> tuple[str, dict]:
        """每个进程使用自己的工具目录，不共享仿真日志或WDB。"""
        name = case["name"]
        folder = out / name
        # Vivado 2019.2不支持过长Windows路径；快照使用独立短编号目录。
        case_build = out / "sims" / f"s{selected.index(case):03d}"
        shutil.copytree(build, case_build, dirs_exist_ok=True)
        stim, actual = folder / "stimulus.hex", folder / "actual.csv"
        if args.simulator == "xsim":
            # Windows批处理会拆分未引号保护的等号；响应文件保留完整plusarg。
            options = case_build / "scenario.opts"
            options.write_text('--runall\n--testplusarg "STIM=' + stim.as_posix() +
                               '"\n--testplusarg "OUT=' + actual.as_posix() + '"\n', encoding="utf-8")
            command = [executable(binary, "xsim"), "v18_pins", "--file", str(options)]
        else:
            command = [executable(binary, "vvp"), str(build / "v18.vvp"), "+STIM=" + stim.as_posix(), "+OUT=" + actual.as_posix()]
        log = execute(command, case_build, folder / "simulation.log")
        if "FAIL" in log or "PASS pin capture" not in log:
            raise RuntimeError(f"capture failed: {name}; log {folder / 'simulation.log'}")
        comparison = compare(folder / "expected.csv", actual, [signal for signal, _, _ in OUTPUTS])
        expected_waves = len([context for context in metadata[name]["contexts"] if all(
            case.get(key) is None or context["fire"] < case[key] for key in ("stop_tick", "abort_tick"))])
        expected_owners = len([context for context in metadata[name]["contexts"] if context["owner"] is not None and all(
            case.get(key) is None or context["owner"] < case[key] for key in ("stop_tick", "abort_tick"))])
        comparison["planned_fires"] = {"wave_fire": expected_waves, "owner_fire": expected_owners}
        comparison["handshake_matches_plan"] = (comparison["audit"]["wave_fire"] == expected_waves and
                                                 comparison["audit"]["owner_fire"] == expected_owners)
        comparison["scenario"] = case
        comparison["trace_sha256"] = {file.name: hashlib.sha256(file.read_bytes()).hexdigest()
                                      for file in (folder / "expected.csv", actual, stim)}
        (folder / "comparison.json").write_text(json.dumps(comparison, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"{name}: {comparison['status']} handshakes={comparison['handshake_matches_plan']}", flush=True)
        return name, comparison
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        for name, comparison in pool.map(run_case, selected):
            results[name] = comparison
    (out / "results.json").write_text(json.dumps({"simulator": version.strip(), "results": results}, ensure_ascii=False, indent=2), encoding="utf-8")
    return int(any(value["status"] != "PASS" or not value["handshake_matches_plan"] for value in results.values()))


if __name__ == "__main__":
    raise SystemExit(main())
