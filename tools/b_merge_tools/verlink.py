# -*- coding: utf-8 -*-
"""Inventory / apply dependency-version linkage for contracts bumped in the B merge batch.
usage: verlink.py <contracts_dir> [--apply]
Only lines that are dependency-table rows are touched:
  * markdown table rows ("| ...") or numbered list rows ("N. Cxx — ...")
  * containing the target file name AND the old version as a separate token
  * not inside strikethrough and not a change-record ("> ") line.
Every candidate line is printed; with --apply the replacement is written.
"""
import re, sys, os, glob

BUMPS = {
    'ppg_system_config_manager_semantic_contract.md': ('V4.9', 'V4.10'),
    'PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md': ('V1.6', 'V1.7'),
    'PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md': ('V1.1', 'V1.2'),
    'PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md': ('V1.12', 'V1.13'),
    'PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md': ('V1.9', 'V1.11'),
    'PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md': ('V2.4', 'V2.5'),
    'PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md': ('V1.2', 'V1.3'),
    'PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md': ('V2.1', 'V2.2'),
    'PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md': ('V2.3', 'V2.4'),
    'PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md': ('V2.1', 'V2.2'),
    'PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md': ('V2.5', 'V2.6'),
    'PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md': ('V1.2', 'V1.3'),
    'PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md': ('V2.6', 'V2.7'),
    'PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md': ('V1.5', 'V1.6'),
    'PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md': ('V1.7', 'V1.8'),
}

def main():
    root = sys.argv[1]
    apply = '--apply' in sys.argv
    total = 0
    for path in sorted(glob.glob(os.path.join(root, '*.md'))):
        fname = os.path.basename(path)
        lines = open(path, encoding='utf-8').read().split('\n')
        changed = False
        for n, line in enumerate(lines):
            if fname == 'PPG_CONTRACT_CLOSURE_MATRIX.md' and (n + 1) in (956, 1912, 2151, 2152, 2153):
                continue
            st = line.lstrip()
            if st.startswith('>'):
                continue
            is_row = st.startswith('|') or re.match(r'^\d+\.\s+C\d\d\s', st)
            if not is_row:
                continue
            for target, (old, new) in BUMPS.items():
                if target == fname:
                    continue
                # left boundary on file name to avoid tb_/prefix confusion
                for m in re.finditer(r'(?<![A-Za-z0-9_])' + re.escape(target), line):
                    # the first version token after this file-name occurrence must be the old version
                    h = re.compile(r'(?<![A-Za-z0-9.])V\d+(?:\.\d+)*(?![0-9.])').search(line, m.end())
                    if h and h.group(0) == old:
                        break
                else:
                    continue
                # skip if inside strikethrough
                pre = line[:h.start()]
                if pre.count('~~') % 2 == 1:
                    continue
                total += 1
                print('%s:%d  %s %s->%s  | %s' % (fname, n + 1, target[:40], old, new, line.strip()[:150]))
                line = line[:h.start()] + new + line[h.end():]
                lines[n] = line
                changed = True
        if apply and changed:
            open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
    print('total', total)

main()
