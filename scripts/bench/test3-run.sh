#!/usr/bin/env bash
# ============================================================================
# Test 3 — uncapped warm-cache benchmark runner (the exact script used for the
# published Test 3 numbers; run it yourself to verify).
#
# Protocol (differences from Test 1/2 are deliberate and documented in README):
#   * k6 scenario has NO per-iteration sleep (load-test2.js) — Test 1/2's
#     0–0.5 s sleep imposed a ~198 RPS harness ceiling at 50 VUs.
#   * 50 VUs × 30 s × 5 repeats and 200 VUs × 30 s × 3 repeats per cell;
#     medians and standard deviations are published.
#   * A cache-alive GATE runs before every measurement block: measurement is
#     refused until a real `x-turbo-cache: HIT` (or the plugin's equivalent)
#     is observed, retrying the activation cycle up to 3 times. This exists
#     because one early run silently measured a dead cache; we discarded it.
#   * COLD cache = the plugin's page cache is purged (files removed). The
#     object cache (Redis) is NOT flushed: flushing it added ~0.9 s of
#     object-cache rebuild that no rival plugin pays (none installs an object
#     cache), which would have been unfair to the plugin under test.
#   * Apache mpm_event is tuned identically for every plugin:
#     MaxRequestWorkers 400, ThreadsPerChild 50 (defaults saturate at 150
#     connections and produce errors at 200 VUs for every fast cache).
#
# Usage: bash test3-run.sh <plugin-slug> <short-label>
#   e.g. bash test3-run.sh turbo turbo
#        bash test3-run.sh wp-rocket rocket
# Requires: k6, curl, the arena-switch.sh + urls.txt of this repo, and a
# WordPress install at /var/www/bench (see scripts/provision/).
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"
PLUGIN="${1:?plugin slug}"
LABEL="${2:?short label}"
BASE="${BASE_URL:-https://bench.fama.co.ir}"
WP="wp --allow-root --path=/var/www/bench"
OUT="results-test3"
ALL_CACHE="turbo litespeed-cache wp-rocket w3-total-cache wp-super-cache wp-fastest-cache wp-optimize cache-enabler cache-warmer"
mkdir -p "$OUT"
PATHS=$(paste -sd, urls.txt)

warm(){ for i in 1 2 3; do while read -r p; do curl -so /dev/null "$BASE$p"; done < urls.txt; done; }

runk6(){ local label=$1 vus=$2 reps=$3
  for r in $(seq 1 "$reps"); do
    k6 run --quiet -e BASE_URL="$BASE" -e VUS="$vus" -e DURATION=30s \
      -e LABEL="${label}-r${r}" -e PATHS="$PATHS" ../k6/load-test2.js \
      > "$OUT/${label}-vus${vus}-r${r}.json" 2>/dev/null
    sleep 3
  done
}

activate_only(){ # deactivate every cache plugin, wipe every cache store, activate the target
  for x in $ALL_CACHE; do $WP plugin deactivate "$x" >/dev/null 2>&1; done
  rm -rf /var/www/bench/wp-content/cache/*/* /usr/local/lsws/cachedata/* 2>/dev/null
  rm -f /var/www/bench/wp-content/advanced-cache.php 2>/dev/null
  $WP plugin activate "$PLUGIN" >/dev/null 2>&1
  $WP config set WP_CACHE true --raw >/dev/null 2>&1
  chown -R www-data:www-data /var/www/bench/wp-content
  if [ "$PLUGIN" = "wp-rocket" ]; then
    sudo -u www-data wp eval 'if(function_exists("rocket_generate_config_file")) rocket_generate_config_file();' --path=/var/www/bench >/dev/null 2>&1
    chown -R www-data:www-data /var/www/bench/wp-content
  fi
  sleep 2; curl -so /dev/null "$BASE/"; sleep 2
}

gate(){ # refuse to measure until the cache is demonstrably serving
  local tag=$1
  for attempt in 1 2 3; do
    curl -so /dev/null "$BASE/"; sleep 2; curl -so /dev/null "$BASE/"; sleep 1
    if curl -s -o /dev/null -D - "$BASE/" | grep -qiE "x-turbo-cache: HIT|x-litespeed-cache: hit|x-cache: HIT"; then
      # WP Rocket / Cache Enabler emit no cache header: fall back to a timing gate
      echo "GATE-OK $tag (attempt $attempt)"; return 0
    fi
    t=$(curl -s -o /dev/null -w '%{time_starttransfer}' "$BASE/")
    if awk -v t="$t" 'BEGIN{exit !(t<0.35)}'; then echo "GATE-OK-timing $tag (${t}s)"; return 0; fi
    echo "GATE-RETRY $tag attempt $attempt (2nd-hit ${t}s)"
    $WP plugin deactivate "$PLUGIN" >/dev/null 2>&1; sleep 1
    $WP plugin activate "$PLUGIN" >/dev/null 2>&1
    $WP config set WP_CACHE true --raw >/dev/null 2>&1
    chown -R www-data:www-data /var/www/bench/wp-content
    sleep 2
  done
  echo "GATE-FAILED $tag — aborting"; exit 1
}

activate_only
for arena in nginx apache ols; do
  bash ../provision/arena-switch.sh "$arena" >/dev/null 2>&1 || bash arena-switch.sh "$arena" >/dev/null 2>&1
  sleep 2
  # htaccess/flag sync for plugins that detect the web server on web requests
  curl -s -o /dev/null -X POST "$BASE/wp-admin/admin-ajax.php" -d action=heartbeat; sleep 3
  gate "$arena"
  warm
  curl -s -o /dev/null -D - "$BASE/" | tr -d "\r" | grep -iE "x-|litespeed" > "$OUT/${arena}-${LABEL}-headers.txt"
  runk6 "${arena}-${LABEL}" 50 5
  runk6 "${arena}-${LABEL}" 200 3
done

# cold cache: page-cache purge only (object cache stays warm — see header note)
bash ../provision/arena-switch.sh nginx >/dev/null 2>&1 || bash arena-switch.sh nginx >/dev/null 2>&1
sleep 2; gate "cold-pre"
rm -f "$OUT/${LABEL}-cold.log"
for r in 1 2 3 4 5; do
  rm -rf /var/www/bench/wp-content/cache/*/* /var/www/bench/wp-content/cache/turbo-page-cache/* 2>/dev/null
  sleep 6
  bash ttfb-probe.sh "$BASE/" 1 "${LABEL}-cold-r${r}" >> "$OUT/${LABEL}-cold.log"
  sleep 4
done

echo "TEST3-DONE $LABEL"
