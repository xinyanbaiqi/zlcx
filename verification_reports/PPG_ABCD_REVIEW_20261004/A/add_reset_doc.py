from pathlib import Path
import json
B=Path(__file__).resolve().parent
for name in ['PPG_FULL_REVIEW_20261002.md','PPG_FULL_REVIEW_20261003.md']:
    p=B/name;text=p.read_text(encoding='utf-8');assert '### F-007' not in text
    detail='''### F-007：芯片合同正文仍要求两路reset_sync，与自身V1.11勘误及RTL冲突

- **严重度/层**：S3 / 合同。
- **位置及原文（3行摘录）**：
  - `contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md:101`：``| ① 复位同步 ×2 | 有 | `RESET_N`分别经`CLK_2M_PAD`域和`SPI_SCLK`域各自的`ppg_reset_sync`实例，产出`i_rstn`和`i_source_rstn` |``
  - 同合同`:25`原文片段：`已改为源域复位直接借用已在`CLK_2M_PAD`域完成同步、早于任何真实SPI活动稳定下来的`i_rstn``（该行V1.11勘误明确记录删除SPI时钟同步器）。
  - `rtl/ppg_chip_digital_top/ppg_chip_digital_top.v:284`：`assign w_source_rstn = w_rstn;          // 源域复位借用已稳定的数字域释放结果`
- **描述/依据**：RTL只在:373实例化一次ppg_reset_sync（CLK_2M_PAD）；SPI域复位是w_rstn直通。合同:53/65/80/82/101却仍列两次实例和SPI_SCLK同步释放，与自身:25勘误及实际结构矛盾。
- **证据/反驳**：实际Top实例/赋值与SPI寄存器source reset连线已交叉核实；额外同步器不存在于别的SPI子模块。合同:25已经明文允许现有机制，因此本条只报告未同步的结构表/正文，不把“没有第二个同步器”认定为S1。source复位释放前SPI是否必须静止、独立reset安全等仍需按实际板级前提继续审查；历史勘误的“无亚稳态风险”措辞不是本轮签核证据。本条不是用户已知“CDC审计不属ASIC签核”的重复事项。
- **置信度**：静态确认（文档内部矛盾及实例数），无需功能仿真。
- **建议方向**：将第2/3/4/6节结构表与图同步到明确的V1.11复位政策，并明确其SPI首次时钟相对复位释放的前提。

'''
    pos=text.index('## 4. 已知事项状态核实');text=text[:pos]+detail+text[pos:]
    text=text.replace('已确认6条','已确认7条').replace('S3=3','S3=4').replace('合同=2、矩阵','合同=3、矩阵')
    text=text.replace('S1 1、S2 2、S3 3、S4 0。按主层：RTL 1、TB 2、合同 2','S1 1、S2 2、S3 4、S4 0。按主层：RTL 1、TB 2、合同 3')
    row='| F-004 | S3 | 合同 | C13给纯组合Router声明不存在的注册式local-empty |'
    assert row in text;text=text.replace(row,row+'\n| F-007 | S3 | 合同 | 芯片合同两路reset_sync正文与自身勘误/实际单路架构冲突 |')
    text+='\n检查点补记：F-007已经跨合同勘误与实际Top核实；确认数更新为7条（S1 1 / S2 2 / S3 4）。待续审候选还包括discard翻转位对两次轮询之间偶数个事件的可辨识性，尚缺真实系统事件/主机轮询前提的反驳验证，未计作已确认发现。\n'
    p.write_text(text,encoding='utf-8')
ledgerpath=B/'evidence/ledger.json';ledger=json.loads(ledgerpath.read_text(encoding='utf-8'))
for x in ledger:
    if x['file']=='contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md':x['checks'].append('复位结构表与本合同V1.11勘误/实际Top矛盾F-007；翻转位偶数事件能力待续核')
ledgerpath.write_text(json.dumps(ledger,ensure_ascii=False,indent=2),encoding='utf-8')
print('F007 RECORDED. Seven confirmed findings.')
