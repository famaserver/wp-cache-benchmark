#!/usr/bin/env python3
"""Aggregate run-bench.sh output: per (plugin, vus) -> median across repeats.

Usage: python3 summarize.py results/nginx-YYYYMMDD-HHMM/
Prints a markdown table ready for the report.
"""
import json, re, sys, statistics as st
from pathlib import Path
from collections import defaultdict

d = Path(sys.argv[1])
cells = defaultdict(list)  # (plugin, vus) -> [run dicts]

for f in sorted(d.glob('*-vus*-r*.json')):
    m = re.match(r'(.+)-vus(\d+)-r\d+\.json', f.name)
    if not m:
        continue
    try:
        run = json.loads(f.read_text())
    except json.JSONDecodeError:
        continue
    cells[(m.group(1), int(m.group(2)))].append(run)

print('| plugin | VUs | RPS (med) | TTFB p50 ms | TTFB p95 ms | err % | runs |')
print('|---|---|---|---|---|---|---|')
for (plugin, vus), runs in sorted(cells.items(), key=lambda kv: (kv[0][1], -st.median(r['rps'] for r in kv[1]))):
    med = lambda key: st.median(key(r) for r in runs)
    print(f"| {plugin} | {vus} "
          f"| {med(lambda r: r['rps']):.1f} "
          f"| {med(lambda r: r['ttfb_ms']['p50']):.1f} "
          f"| {med(lambda r: r['ttfb_ms']['p95']):.1f} "
          f"| {med(lambda r: r['error_rate'])*100:.2f} "
          f"| {len(runs)} |")

# single-request probe logs
print('\n### TTFB probes (median of medians)')
for log in sorted(d.glob('*-ttfb.log')) + sorted(d.glob('*-warm.log')) + sorted(d.glob('*-cold.log')):
    meds = re.findall(r'median=([\d.]+)', log.read_text())
    if meds:
        vals = [float(x) for x in meds]
        print(f"- {log.stem}: {st.median(vals):.1f} ms (n={len(vals)})")
