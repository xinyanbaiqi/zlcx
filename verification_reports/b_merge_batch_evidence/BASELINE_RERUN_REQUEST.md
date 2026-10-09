# 基线补跑请求：4份系统TB + 1份模块级TB（基线`7a8eabf`）

> 背景：本机（Vivado 2019.2）的基线回归中，4份系统TB因进程被结束而未跑完，1份模块级TB在2019.2下xelab确定性崩溃。详情见`baseline_7a8eabf_vivado2019.2_partial/README.md`。请在另一台机器上补跑以下TB。

## 1. 要跑的TB

- 系统TB（`rtl/ppg_control_top/run_xsim_regression.sh`）：
  - `tb_ppg_control_top_baseline_cross`
  - `tb_ppg_control_top_robustness_corner_waveforms`
  - `tb_ppg_control_top_startup_idac_calibration`
  - `tb_ppg_control_top_adc_anomaly`
- 模块级TB（`tools/run_unit_tb_regression.sh`）：`tb_ppg_coarse_detection_fir`。用Vivado 2019.2时它必定崩溃，可以跳过；用其它版本时请跑。

## 2. 步骤（Windows + Git Bash）

1. 拉取仓库，导出基线到**仓库外**的独立目录。不要在工作区直接跑：autocrlf会改写文件字节，`.sh`带CRLF在bash下会出错。
   ```bash
   git clone https://github.com/xinyanbaiqi/zlcx && cd zlcx
   mkdir -p ../rerun_7a8eabf && git -c core.autocrlf=false archive 7a8eabf | tar -x -C ../rerun_7a8eabf
   cd ../rerun_7a8eabf
   ```
2. 指定Vivado，并记下版本：
   ```bash
   export VIVADO_BIN=/c/Xilinx/Vivado/2022.2/bin   # 按实际安装路径改
   "$VIVADO_BIN/xelab.bat" -version | head -1
   ```
3. 系统TB：只改**导出副本**中`rtl/ppg_control_top/run_xsim_regression.sh`的`ORDER=( ... )`数组，改成上面4个TB名（每行一个），其余内容不动。然后运行：
   ```bash
   bash rtl/ppg_control_top/run_xsim_regression.sh > sys_rerun4.out 2>&1
   ```
   想要2路并行的话，导出两份目录，各放2个TB。
4. 模块级（版本不是2019.2时）：
   ```bash
   bash tools/run_unit_tb_regression.sh -o "$PWD/unit_fir" tb_ppg_coarse_detection_fir > unit_fir.out 2>&1
   ```
5. 运行期间不要关闭启动仿真的程序，也不要让电脑睡眠。

## 3. 回传（提交到`b-merge-batch`分支）

把原始结果放进`verification_reports/b_merge_batch_evidence/baseline_7a8eabf_rerun/`：
- `MACHINE.txt`：CPU、操作系统、Vivado版本号（第2步的输出）、开始和结束时间；
- 系统TB：`rtl/ppg_control_top/xsim_regression_20260906/summary.tsv`，以及每个TB目录下的`xsim.log`，按`<tb>/xsim.log`放；
- 模块级（如果跑了）：`unit_fir/unit_summary.tsv`与`unit_fir/tb_ppg_coarse_detection_fir/xsim.log`。

提交前先`git pull`，只`git add`上面这个目录。不要改动其它文件。

## 4. 对后续比对的约束（交接书§6.8）

- 交接书要求基线与终版回归在**同一台机器、同一Vivado版本**上跑。因此这5份TB的**终版回归也必须在这台机器、这个Vivado版本上跑**，比对才成立。
- 合格判据：每个TB的xvlog、xelab、xsim返回0，0 FAIL，`$finish`恰好1次。4份系统TB的PASS行合计应为1250 − 985 = 265行（参考值来自统筹机器，Vivado 2022.2）。
- 如果这台机器装的是Vivado 2022.2，可以考虑把整套基线和终版回归都改在这台机器上跑：版本与参考值一致，FIR的崩溃问题也不存在。这一点由用户与统筹决定。
