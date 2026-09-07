#!/usr/bin/env bash
# Single-URL TTFB probe: N sequential requests, prints each + median/p95.
# Usage: bash ttfb-probe.sh <url> [runs=15] [label]
set -euo pipefail
URL="${1:?usage: ttfb-probe.sh <url> [runs] [label]}"
RUNS="${2:-15}"
LABEL="${3:-probe}"

vals=()
for i in $(seq 1 "$RUNS"); do
  t=$(curl -o /dev/null -sS -w '%{time_starttransfer}' "$URL")
  ms=$(awk -v t="$t" 'BEGIN{printf "%.1f", t*1000}')
  vals+=("$ms")
  echo "[$LABEL] run $i: ${ms} ms"
done

printf '%s\n' "${vals[@]}" | sort -n | awk -v label="$LABEL" '
  { a[NR]=$1 }
  END {
    med = (NR%2) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2
    p95i = int(NR*0.95); if (p95i<1) p95i=1
    printf "[%s] median=%.1f ms  p95=%.1f ms  min=%.1f  max=%.1f  (n=%d)\n",
      label, med, a[p95i], a[1], a[NR], NR
  }'
