#!/usr/bin/env bash
# تست کامل یک پلاگین کش روی هر سه زمین (یا زمین‌های انتخابی)
# Usage: bash plugin-bench.sh <plugin-slug> <label> [arenas="nginx apache ols"]
set -euo pipefail
cd /root/bench-scripts
PLUGIN="${1:?plugin slug}"
LABEL="${2:?short label}"
ARENAS="${3:-nginx apache ols}"
BASE=https://bench.fama.co.ir
WP="wp --allow-root --path=/var/www/bench"
ALL_CACHE="turbo litespeed-cache wp-rocket w3-total-cache wp-super-cache wp-fastest-cache"
mkdir -p results

purge() {
  case "$PLUGIN" in
    litespeed-cache) $WP litespeed-purge all 2>/dev/null || $WP cache flush 2>/dev/null || true ;;
    wp-rocket)       $WP rocket clean --confirm 2>/dev/null || $WP cache flush 2>/dev/null || true ;;
    *)               $WP cache flush 2>/dev/null || true ;;
  esac
}

warmup() { for i in 1 2 3; do while read -r p; do curl -so /dev/null "$BASE$p"; done < urls.txt; done; }

# فقط پلاگین هدف فعال باشد
for p in $ALL_CACHE; do $WP plugin deactivate "$p" 2>/dev/null || true; done
$WP plugin activate "$PLUGIN"
$WP plugin list --format=csv --fields=name,status,version > "results/${LABEL}-plugins-state.csv"

PATHS=$(paste -sd, urls.txt)
for arena in $ARENAS; do
  echo "##### $LABEL @ $arena #####"
  bash arena-switch.sh "$arena"
  sleep 3

  # S1: cold — ۵ چرخه purge + اولین درخواست
  for r in 1 2 3 4 5; do
    purge; sleep 2
    bash ttfb-probe.sh "$BASE/" 1 "${arena}-${LABEL}-cold-r${r}" >> "results/${arena}-${LABEL}-cold.log"
  done

  # S2: warm — پر کردن کش، بعد ۱۵ پروب
  purge; sleep 2; warmup
  bash ttfb-probe.sh "$BASE/" 15 "${arena}-${LABEL}-home"  > "results/${arena}-${LABEL}-home-ttfb.log"
  bash ttfb-probe.sh "$BASE/shop/" 15 "${arena}-${LABEL}-shop" > "results/${arena}-${LABEL}-shop-ttfb.log"

  # S3: بار ۵۰ کاربر × ۳ تکرار (کش گرم)
  for r in 1 2 3; do
    warmup
    mpstat 5 12 > "results/${arena}-${LABEL}-vus50-r${r}-cpu.log" 2>&1 &
    MP=$!
    k6 run --quiet -e BASE_URL="$BASE" -e VUS=50 -e DURATION=60s \
      -e LABEL="${arena}-${LABEL}-r${r}" -e PATHS="$PATHS" \
      load-test.js > "results/${arena}-${LABEL}-vus50-r${r}.json" 2>/dev/null || echo "k6 nonzero: $arena r$r"
    wait $MP 2>/dev/null || true
    sleep 5
  done

  # هدرهای کش برای مستندسازی
  curl -sI "$BASE/" | grep -iE "x-cache|x-litespeed|x-rocket|cache-control|x-turbo" \
    > "results/${arena}-${LABEL}-headers.txt" || true
done

$WP plugin deactivate "$PLUGIN" 2>/dev/null || true
bash arena-switch.sh nginx >/dev/null
echo "PLUGIN-BENCH-DONE $LABEL"
