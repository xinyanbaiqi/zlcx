"""从已手工核对的 C09 字典生成被动采集 TB；不读取 SSW 来提取端口。"""

from __future__ import annotations

import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "golden"))
from model import INPUTS, OUTPUTS, STATUS

HEADER = """`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Codex
// Create Date:     2026/10/10
// Design Name:     tb_v18_ssw_golden
// Module Name:     tb_v18_ssw_golden
// Description:     Contract-only stimulus replay and complete analog pin capture
// Simulations:     Vivado xsim or iverilog
// Referrences:     C09 sections 7 and 8; independent V18 Python golden
// Dependencies:    ppg_sar9_sar15_safe_selection_wrapper (compile only)
// Version:         V1.0
// Revision Date:   2026/10/10
// History:         2026/10/10 V1.0 Codex Create independent pin capture bench.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Codex
// 创建日期:        2026年10月10日
// 设计名称:        tb_v18_ssw_golden
// 模块名称:        tb_v18_ssw_golden
// 模块说明:        合同端口驱动与全部模拟引脚逐拍采集，期望值由独立Python检查
// 仿真工程:        verification/v18_ssw_golden
// 参考资料:        C09接口合同以及获准时序模板
// 依赖文件:        SSW仅交给编译器，生成器不读取其内容
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:        2026年10月10日 V1.0 Codex 创建合同驱动采集台

// 逐拍重放相位和数字ADC行为链，检查时钟相位以及边沿间控制稳定性
module tb_v18_ssw_golden
();
"""


def annotated(code: str, comment: str) -> str:
    """按固定注释锚点对齐，同时保留Tab层级缩进。"""
    return code + " " * max(1, 44 - len(code.expandtabs(4))) + "// " + comment


def build(destination: Path) -> None:
    """采集表的列来自合同输出字典；所有输入都显式驱动。"""
    total = sum(width for _, width, _ in INPUTS)
    pins = OUTPUTS + STATUS
    lines = [HEADER.rstrip()]
    declarations = [
        ("reg reg_clk;", "仿真主时钟保持五百纳秒周期"),
        (f"reg [{total - 1}:0]reg_drive;", "单拍合同输入字在下降沿之后更换"),
        ("reg [8191:0]reg_stimulus_path;", "运行参数指定完整刺激文件路径"),
        ("reg [8191:0]reg_output_path;", "当前场景的模拟引脚采集目标路径"),
        ("reg [66:0]reg_high_sample;", "上升沿稳定后冻结全部六十七个模拟位"),
        ("reg flag_wave_fire;", "记录提交沿之前真实波形握手条件"),
        ("reg flag_owner_fire;", "记录同拍结果所有权是否真正接纳"),
    ]
    lines += ["", "\t//---------------计数信号---------------//", "\t// 文件重放按有限行数推进，不由DUT输出决定物理相位"]
    integers = [
        ("cnt_clock_edge", "有界主时钟发生循环的半周期计数"),
        ("cnt_row", "采集记录唯一递增行号"), ("cnt_read", "输入扫描返回的有效字段数量"),
        ("cnt_stimulus_file", "保存输入数据文件句柄"), ("cnt_output_file", "保存逐拍结果文件句柄"),
        ("cnt_errors", "时钟相位或控制毛刺检查失败总数"),
    ]
    lines.extend(annotated(f"\tinteger {name};", comment) for name, comment in integers)
    lines += ["", "\t//--------------寄存器信号--------------//", "\t// 驱动字包括复位、相位、配置与两个独立身份通道"]
    lines.extend(annotated("\t" + code, comment) for code, comment in declarations if "flag_" not in code)
    lines += ["", "\t//---------------标志信号---------------//", "\t// 接管事实在沿前固定，避免沿后ready回落影响审计"]
    lines.extend(annotated("\t" + code, comment) for code, comment in declarations if "flag_" in code)
    lines += ["", "\t//---------------输出信号---------------//", "\t// 每组模拟引脚保留合同宽度；状态只用于协议审计"]
    for name, width, comment in pins:
        dimension = f"[{width - 1}:0]" if width > 1 else ""
        lines.append(annotated(f"\twire {dimension}{name[2:]}_o;", "采集" + comment))
    signals = ", ".join(name[2:] + "_o" for name, _, _ in OUTPUTS)
    clock_index = sum(width for _, width, _ in OUTPUTS[7:])
    mask = ((1 << 67) - 1) ^ (1 << clock_index)
    lines += ["", "\t//-------------初始化区域-------------//", "\t// 自由运行时钟与输入文件解耦，避免把相位通道变成门控时钟", "\tinitial begin",
              annotated('\t\t$display("V18 clock: 2 MHz contract replay begins");', "声明本次仿真唯一物理时基"),
              annotated("\t\treg_clk = 1'b0;", "从低电平起步建立主时钟相位"),
              annotated("\t\tfor(cnt_clock_edge = 0; cnt_clock_edge < 80000; cnt_clock_edge = cnt_clock_edge + 1)begin", "有界半周期序列覆盖全部场景时长"),
              annotated("\t\t\t#250 reg_clk = ~reg_clk;", "每半周期翻转一次唯一仿真时基"), "\t\tend", "\tend",
              "", "\t// 输入在低相稳定、提交前采样ready、NBA之后记录模拟边界", "\tinitial begin",
              annotated('\t\t$display("V18 driver: frozen contract stimuli are loaded");', "刺激载荷已经由独立黄金模型冻结"),
              annotated(f"\t\treg_drive = {total}'d0;", "初始合同字全零保证低有效复位已断言"),
              annotated("\t\tcnt_row = 0;", "第一行从复位序列零号开始"),
              annotated("\t\tcnt_errors = 0;", "本次采集清空被动断言失败计数"),
              "\t\tif(!$value$plusargs(\"STIM=%s\", reg_stimulus_path))begin",
              annotated('\t\t\t$display("FAIL missing STIM");', "缺少驱动文件则不能宣称仿真有效"),
              annotated("\t\t\t$finish;", "无刺激立即终止错误运行"), "\t\tend",
              "\t\tif(!$value$plusargs(\"OUT=%s\", reg_output_path))begin",
              annotated('\t\t\t$display("FAIL missing OUT");', "没有输出路径无法生成可审核证据"),
              annotated("\t\t\t$finish;", "无采集目标结束本次重放"), "\t\tend",
              annotated('\t\tcnt_stimulus_file = $fopen(reg_stimulus_path, "r");', "只读打开预先生成的独立刺激"),
              annotated('\t\tcnt_output_file = $fopen(reg_output_path, "w");', "创建新的逐行模拟输出采集文件"),
              "\t\tif(cnt_stimulus_file == 0 || cnt_output_file == 0)begin",
              annotated('\t\t\t$display("FAIL file open");', "任何句柄无效都使采集证据失败"),
              annotated("\t\t\t$finish;", "文件访问失败时停止驱动"), "\t\tend"]
    header = ["row"] + [name for name, _, _ in pins] + ["wave_fire", "owner_fire", "clock_low", "stable_between_edges"]
    lines += [annotated(f'\t\t$fwrite(cnt_output_file, "{",".join(header)}\\n");', "列名覆盖合同全部模拟输出与审计状态"),
              annotated("\t\t#2;", "留出复位组合传播时间再载入第一拍"),
              "\t\twhile(!$feof(cnt_stimulus_file))begin",
              annotated('\t\t\tcnt_read = $fscanf(cnt_stimulus_file, "%h\\n", reg_drive);', "低相载入固定宽度完整输入字"),
              "\t\t\tif(cnt_read != 1)begin",
              annotated('\t\t\t\t$display("FAIL malformed stimulus");', "畸形行拒绝推进采集序号"),
              annotated("\t\t\t\t$finish;", "格式错误阻止不确定输入进入DUT"), "\t\t\tend",
              annotated("\t\t\t#247;", "提交沿前一纳秒确认握手资格"),
              annotated("\t\t\tflag_wave_fire = waveform_context_ready_o && " + bit_for("i_waveform_context_valid") + ";", "模拟预约只认沿前ready与valid同时成立"),
              annotated("\t\t\tflag_owner_fire = adc_owner_ready_o && " + bit_for("i_adc_owner_commit_event") + ";", "结果接纳只认独立owner通道合法提交"),
              annotated("\t\t\t@(posedge reg_clk);", "物理更新点来自唯一二兆赫时钟"),
              annotated("\t\t\t#1;", "等待非阻塞赋值完成后观察上升沿输出"),
              annotated(f"\t\t\treg_high_sample = {{{signals}}};", "冻结完整模拟向量用于边沿间稳定性核查"),
              "\t\t\tif(clk_2m_o !== 1'b1)begin",
              annotated("\t\t\t\tcnt_errors = cnt_errors + 1;", "上升沿时钟转发错误纳入真实失败计数"), "\t\t\tend",
              annotated("\t\t\t@(negedge reg_clk);", "下降沿再次核对时钟转发与模拟向量"),
              annotated("\t\t\t#1;", "允许源时钟下降传播到模拟端口"),
              f"\t\t\tif(clk_2m_o !== 1'b0 || ((reg_high_sample ^ {{{signals}}}) & 67'h{mask:x}) !== 67'd0)begin",
              annotated("\t\t\t\tcnt_errors = cnt_errors + 1;", "低相时钟错误或控制边沿间变化计为失败"), "\t\t\tend"]
    # 主输出记录上升沿快照，状态在下降沿稳定后记录；状态非黄金窗口来源。
    offset = 67
    observed = []
    for _, width, _ in OUTPUTS:
        offset -= width
        observed.append(f"reg_high_sample[{offset + width - 1}:{offset}]")
    observed += [name[2:] + "_o" for name, _, _ in STATUS]
    arguments = ["cnt_row"] + observed + ["flag_wave_fire", "flag_owner_fire", "clk_2m_o",
                 f"(((reg_high_sample ^ {{{signals}}}) & 67'h{mask:x}) === 67'd0)"]
    fmt = "%d," + ",".join(["%h"] * (len(arguments) - 1)) + "\\n"
    lines += [annotated(f'\t\t\t$fwrite(cnt_output_file, "{fmt}", {", ".join(arguments)});', "输出上升沿引脚值及本拍低相审计事实"),
              annotated("\t\t\tcnt_row = cnt_row + 1;", "每条有效输入恰好对应一条采集记录"),
              "\t\tend", annotated("\t\t$fclose(cnt_stimulus_file);", "全部刺激重放完成关闭输入句柄"),
              annotated("\t\t$fclose(cnt_output_file);", "落盘采集证据后释放输出句柄"),
              "\t\tif(cnt_errors == 0)begin",
              annotated('\t\t\t$display("PASS pin capture clock and stability rows=%0d", cnt_row);', "只有真实时钟与稳定断言全通过才打印采集PASS"),
              "\t\tend else begin",
              annotated('\t\t\t$display("FAIL clock or stability errors=%0d", cnt_errors);', "被动断言错误明确标为采集失败"),
              "\t\tend", annotated("\t\t$finish;", "黄金符合性由独立Python比较器另行判定"), "\tend",
              "", "\t// 有界看门狗使缺失时钟或阻塞文件不会成为无限仿真", "\tinitial begin",
              annotated('\t\t$display("V18 watchdog: bounded simulation guard armed");', "启用超时保护防止无界工具占用"),
              annotated("\t\t#20000000;", "四十千拍上限覆盖双宏帧场景并留下余量"),
              annotated('\t\t$display("FAIL watchdog timeout");', "超过允许模拟时间报告超时失败"),
              annotated("\t\t$finish;", "终止异常挂起并交还工具控制权"), "\tend",
              "", "\t//------------模块实例化区域------------//", "\t// 仅按C09显式接口例化；不从RTL提取定义或绑定层级内部对象",
              annotated("\tppg_sar9_sar15_safe_selection_wrapper ppg_sar9_sar15_safe_selection_wrapper_Inst_contract(", "合同驱动的唯一被测模拟控制源"),
              annotated("\t\t.i_clk(reg_clk),", "供给无门控二兆赫物理主时钟")]
    for name, _, comment in INPUTS:
        lines.append(annotated(f"\t\t.{name}({bit_for(name)}),", "重放场景条件：" + comment))
    for index, (name, _, comment) in enumerate(pins):
        comma = "," if index + 1 < len(pins) else ""
        lines.append(annotated(f"\t\t.{name}({name[2:]}_o){comma}", "观测DUT返回：" + comment))
    lines += ["\t);", "", "endmodule", ""]
    destination.parent.mkdir(parents=True, exist_ok=True)
    # 初始状态说明与initial入口同一源码行，使技能AST保留可信首行定位。
    expanded = "\n".join(lines).splitlines()
    joined = []
    index = 0
    while index < len(expanded):
        if expanded[index].strip() == "initial begin" and expanded[index + 1].lstrip().startswith("$display"):
            joined.append(expanded[index] + " " + expanded[index + 1].lstrip())
            index += 2
        else:
            joined.append(expanded[index])
            index += 1
    aligned = []
    anchor = 44
    for line in joined:
        if line.lstrip().startswith("//-") and line.endswith("//"):
            anchor = display_width(line[:line.rfind("//")])
        if "//" in line and not line.lstrip().startswith("//") and line.startswith("\t"):
            code, comment = line.split("//", 1)
            code = code.rstrip()
            line = code + " " * max(1, anchor - display_width(code)) + "//" + comment
        aligned.append(line)
    destination.write_text("\n".join(aligned) + "\n", encoding="utf-8")


def display_width(text: str) -> int:
    """注释对齐使用汉字双列和四列Tab，与Erie区域横幅一致。"""
    column = 0
    for char in text:
        if char == "\t":
            column += 4 - column % 4
        else:
            column += 2 if unicodedata.east_asian_width(char) in {"W", "F"} else 1
    return column


def bit_for(name: str) -> str:
    """命名端口在驱动字中的位置由唯一合同字典计算。"""
    offset = sum(width for _, width, _ in INPUTS)
    for port, width, _ in INPUTS:
        offset -= width
        if port == name:
            return f"reg_drive[{offset + width - 1}:{offset}]"
    raise KeyError(name)


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1] / "tb" / "tb_v18_ssw_golden.v")
