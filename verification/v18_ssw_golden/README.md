# V18 independent SSW golden trial

所有模拟引脚来自 C09 §7.7。黄金发生器只读取获准的 SAR9/SAR15 相对窗口模板，SSW 路径只传给编译器，禁止从它提取端口或窗口。规则待确认时 `expected.csv` 保留空值，结果为 `PARTIAL_UNCERTAIN`，不会当作通过。

Python 3.10+，无第三方 Python 依赖。Vivado xsim 或 Icarus Verilog 为可参数化后端。

```powershell
python -B verification/v18_ssw_golden/scripts/run.py --repo . --simulator xsim --simulator-bin D:/vivado/2019.2/bin --select normal_both_sar9_a5 --out verification/v18_ssw_golden/_runs/one
python -B verification/v18_ssw_golden/scripts/run.py --repo . --simulator xsim --simulator-bin D:/Xilinx/Vivado/2022.2/bin --jobs 4 --out verification/v18_ssw_golden/_runs/full
python -B verification/v18_ssw_golden/scripts/run.py --repo . --simulator iverilog --simulator-bin C:/iverilog/bin --out verification/v18_ssw_golden/_runs/icarus
```

Linux 同一 Python 入口，`--simulator-bin /tools/Xilinx/Vivado/2022.2/bin`；PATH 已就绪时省略该参数。时序模板移入 legacy 后，用 `--sar9-template <路径>` 和 `--sar15-template <路径>` 指定。SSW移位时用 `--ssw-rtl <路径>`，不读取其内容。

- `--scenarios`：替换场景JSON；`--select`：名称子串过滤。
- `--generate-only`：只冻结期望与驱动，不调用仿真器。
- `--jobs`：多个独立仿真进程，每个有自己的编译快照、日志和波形数据库。
- 退出码0只表示全部已选择场景全量确定且符合黄金；不符、待确认规则或握手数量异常均非0。
- 输出包含全部引脚的 `expected.csv`/`actual.csv`、场景元数据、逐信号首差异/差异拍数/位差异数量、工具版本、窗口来源和SHA256。
- 硬复位拍也比较，正式帧前4拍配置预备期不对未定义的配置接管延迟作断言；时钟与边沿间稳定性仍全程检查。
- 行号对应一个输入提交沿；`tick`为正式帧相位，负数为复位/启动预备期。输出在上升沿后1ns采样，因此黄金不补偿或拟合DUT延迟。
- 行为ADC完成链为外部预定数字旁带日程；不使用DUT的Q3/包络末沿/idle自动生成DONE。不是AMS、SPICE或联合ADC数值验证。

`scripts/build_tb.py` 是合同字典到新TB的可复现生成器，不调用从RTL提取端口的工具。重新生成后必须运行技能门禁：

```powershell
python -B verification/v18_ssw_golden/scripts/build_tb.py
python -B .claude/skills/erie-verilog-generator/scripts/python/validation/verilog_generated_deliverable_gate.py verification/v18_ssw_golden/tb/tb_v18_ssw_golden.v --include-testbench --json verification/v18_ssw_golden/_runs/deliverable_gate.json --markdown verification/v18_ssw_golden/_runs/deliverable_gate.md
```

大体积逐拍文件、工具快照和运行日志留在忽略目录`_runs/`；提交包含小型机器可读结果、来源与迹线哈希，能够用相同脚本复现。独立性记录和未确认问题以`verification_reports/V18_SSW_EXPECTED_RULES.md`为准。
