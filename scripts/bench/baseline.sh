#!/usr/bin/env bash
# Baseline بدون کش — هر سه زمین: nginx, apache, ols
# خروجی: /root/bench-scripts/results/
set -euo pipefail
cd /root/bench-scripts
mkdir -p results
BASE=https://bench.fama.co.ir
PATHS=$(paste -sd, urls.txt)

for arena in nginx apache ols; do
  echo "##### ARENA: $arena #####"
  bash arena-switch.sh "$arena"
  sleep 3

  # سه دور warm-up (فقط opcache و بافرهای DB گرم شود — کش صفحه‌ای وجود ندارد)
  for i in 1 2 3; do
    while read -r p; do curl -so /dev/null "$BASE$p"; done < urls.txt
  done

  # TTFB تک‌درخواست: خانه و فروشگاه، ۱۵ بار
  bash ttfb-probe.sh "$BASE/" 15 "${arena}-nocache-home"  > "results/${arena}-nocache-home-ttfb.log"
  bash ttfb-probe.sh "$BASE/shop/" 15 "${arena}-nocache-shop" > "results/${arena}-nocache-shop-ttfb.log"

  # بار ۵۰ کاربر همزمان × ۶۰ ثانیه × ۳ تکرار + ثبت CPU حین تست
  for r in 1 2 3; do
    mpstat 5 12 > "results/${arena}-nocache-vus50-r${r}-cpu.log" 2>&1 &
    MP=$!
    k6 run --quiet \
      -e BASE_URL="$BASE" -e VUS=50 -e DURATION=60s \
      -e LABEL="${arena}-nocache-r${r}" -e PATHS="$PATHS" \
      load-test.js > "results/${arena}-nocache-vus50-r${r}.json" 2>&1 || echo "k6 failed for $arena r$r"
    wait $MP 2>/dev/null || true
    sleep 5
  done
done

bash arena-switch.sh nginx >/dev/null
echo "BASELINE-DONE"
