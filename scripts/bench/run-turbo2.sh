#!/usr/bin/env bash
# Full Turbo 3.2.4 run: server bench on 3 arenas + lighthouse front-end phase
set -euo pipefail
cd /root/bench-scripts
WP="wp --allow-root --path=/var/www/bench"

bash plugin-bench.sh turbo turbo324

# --- front-end phase (turbo active, warm cache, per arena) ---
$WP plugin activate turbo >/dev/null 2>&1
chown -R www-data:www-data /var/www/bench/wp-content
for arena in nginx apache ols; do
  bash arena-switch.sh "$arena" >/dev/null 2>&1
  sleep 2
  for i in 1 2 3; do while read -r p; do curl -so /dev/null "https://bench.fama.co.ir$p"; done < urls.txt; done
  bash lighthouse-probe.sh "${arena}-turbo324" 3
done

# baseline front-end for comparison (no plugin, nginx)
$WP plugin deactivate turbo >/dev/null 2>&1
rm -f /var/www/bench/wp-content/advanced-cache.php
bash arena-switch.sh nginx >/dev/null 2>&1
sleep 2
curl -so /dev/null https://bench.fama.co.ir/
bash lighthouse-probe.sh "nginx-nocache" 3

echo "TURBO324-ALL-DONE"
