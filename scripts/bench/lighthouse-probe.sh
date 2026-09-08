#!/usr/bin/env bash
# Front-end probe: N lighthouse runs against the homepage in its CURRENT state.
# Usage: lighthouse-probe.sh <label> [runs=3]
set -euo pipefail
cd /root/bench-scripts
LABEL=${1:?label}; RUNS=${2:-3}
mkdir -p results
for r in $(seq 1 "$RUNS"); do
  CHROME_PATH=/usr/bin/chromium-browser lighthouse https://bench.fama.co.ir/ \
    --only-categories=performance --preset=desktop \
    --output=json --output-path=/tmp/lh.json \
    --chrome-flags="--headless --no-sandbox --disable-gpu" --quiet >/dev/null 2>&1 || { echo "lighthouse run $r failed for $LABEL"; continue; }
  python3 - "$LABEL" "$r" <<'EOF'
import json,sys
d=json.load(open('/tmp/lh.json'))
a=d['audits']
m=a['metrics']['details']['items'][0]
out={'label':sys.argv[1],'run':int(sys.argv[2]),
 'perf_score':round((d['categories']['performance']['score'] or 0)*100),
 'fcp_ms':round(a['first-contentful-paint']['numericValue']),
 'lcp_ms':round(a['largest-contentful-paint']['numericValue']),
 'tbt_ms':round(a['total-blocking-time']['numericValue']),
 'cls':round(a['cumulative-layout-shift']['numericValue'],3),
 'speed_index':round(a['speed-index']['numericValue']),
 'tti_ms':round(a['interactive']['numericValue']),
 'observed_load_ms':m.get('observedLoad'),
 'dcl_ms':m.get('observedDomContentLoaded')}
print(json.dumps(out))
open(f"results/lh-{sys.argv[1]}-r{sys.argv[2]}.json","w").write(json.dumps(out,indent=1))
EOF
done
