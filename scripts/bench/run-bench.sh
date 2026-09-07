#!/usr/bin/env bash
# Turbo Benchmark — orchestrator. Runs the full matrix for ONE arena.
# Run from the LOAD GENERATOR box for k6/probe parts, or on the server with
# BASE_URL=http://127.0.0.1 for a first smoke test.
#
# Usage: BASE_URL=http://<ip> ARENA=nginx bash run-bench.sh
# Requires: k6, curl, jq on this box; SSH root access to the server (SERVER=<ip>).
set -euo pipefail

BASE_URL="${BASE_URL:?set BASE_URL=http://<ip>}"
ARENA="${ARENA:?set ARENA=nginx|ols}"
SERVER="${SERVER:-}"            # SSH host for remote purge/restart; empty = local
REPEATS="${REPEATS:-5}"         # repetitions per (plugin, vus) cell
VUS_LIST="${VUS_LIST:-50 200}"  # add 500 for the stress pass
PLUGINS="${PLUGINS:-none turbo litespeed-cache wp-rocket w3-total-cache wp-super-cache wp-fastest-cache}"
OUT="results/${ARENA}-$(date +%Y%m%d-%H%M)"
mkdir -p "$OUT"

remote() {  # run a command on the WP server
  if [ -n "$SERVER" ]; then ssh "root@${SERVER}" "$@"; else bash -c "$*"; fi
}

wp_r() { remote "wp --allow-root --path=/var/www/bench $*"; }

reset_state() {  # clean slate between plugins
  local plugin="$1"
  for p in turbo litespeed-cache wp-rocket w3-total-cache wp-super-cache wp-fastest-cache; do
    wp_r "plugin deactivate $p" 2>/dev/null || true
  done
  [ "$plugin" != "none" ] && wp_r "plugin activate $plugin"
  wp_r "cache flush" || true
  remote "systemctl restart php8.3-fpm 2>/dev/null || systemctl restart lsws"
  sleep 3
}

warmup() {  # prime the cache before warm-cache measurements
  for i in 1 2 3; do
    while read -r p; do curl -so /dev/null "${BASE_URL}${p}"; done < urls.txt
  done
  sleep 2
}

echo "=== Arena: $ARENA | plugins: $PLUGINS | repeats: $REPEATS ==="
[ -f urls.txt ] || { echo "MISSING urls.txt (one path per line, e.g. /shop/)"; exit 1; }
PATHS=$(paste -sd, urls.txt)

for plugin in $PLUGINS; do
  echo "--- $plugin ---"
  reset_state "$plugin"

  # 1) COLD: purge, then first-hit TTFB (repeat cycle REPEATS times)
  for r in $(seq 1 "$REPEATS"); do
    wp_r "cache flush" || true
    sleep 1
    bash ttfb-probe.sh "${BASE_URL}/" 1 "${plugin}-cold-r${r}" | tee -a "$OUT/${plugin}-cold.log"
  done

  # 2) WARM single-request TTFB
  warmup
  bash ttfb-probe.sh "${BASE_URL}/" 15 "${plugin}-warm" | tee "$OUT/${plugin}-warm.log"

  # 3) LOAD at each VU level
  for vus in $VUS_LIST; do
    for r in $(seq 1 "$REPEATS"); do
      warmup
      k6 run --quiet \
        -e BASE_URL="$BASE_URL" -e VUS="$vus" -e DURATION=60s \
        -e LABEL="${ARENA}-${plugin}-r${r}" -e PATHS="$PATHS" \
        ../k6/load-test.js | tee "$OUT/${plugin}-vus${vus}-r${r}.json"
    done
  done
done

echo "=== DONE. Raw results in $OUT — aggregate with summarize.py ==="
