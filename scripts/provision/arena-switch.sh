#!/usr/bin/env bash
# Switch the active web server arena: nginx | apache | ols
# Same docroot, same DB, same PHP settings — only the web server changes.
# Ends with a health-check of every benchmark URL.
set -euo pipefail
ARENA="${1:?usage: arena-switch.sh nginx|apache|ols}"
DOMAIN=bench.fama.co.ir

systemctl stop nginx apache2 lshttpd 2>/dev/null || true
sleep 1

case "$ARENA" in
  nginx)  systemctl restart php8.2-fpm; systemctl start nginx ;;
  apache) systemctl restart php8.2-fpm; systemctl start apache2 ;;
  ols)    systemctl start lshttpd ;;
  *) echo "unknown arena: $ARENA"; exit 1 ;;
esac
sleep 2

echo "=== health check ($ARENA) ==="
fail=0
while read -r p; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "https://${DOMAIN}${p}")
  echo "  $code $p"
  [ "$code" = "200" ] || fail=1
done < /root/bench-scripts/urls.txt
[ $fail -eq 0 ] && echo "=== $ARENA arena LIVE ===" || { echo "!!! HEALTH CHECK FAILED"; exit 1; }
