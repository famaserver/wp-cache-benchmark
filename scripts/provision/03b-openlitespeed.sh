#!/usr/bin/env bash
# Turbo Benchmark — Arena B: OpenLiteSpeed + lsphp83
# (restore the clean snapshot first — never install on top of Nginx arena)
set -euo pipefail
DOMAIN="${1:?usage: bash 03b-openlitespeed.sh <domain-or-ip>}"

wget -qO - https://repo.litespeed.sh | bash
apt-get -y install openlitespeed lsphp83 lsphp83-common lsphp83-mysql \
  lsphp83-curl lsphp83-intl lsphp83-opcache lsphp83-imagick

# same PHP limits as the FPM arena
cat >/usr/local/lsws/lsphp83/etc/php/8.3/mods-available/99-bench.ini <<'EOF'
memory_limit = 256M
opcache.enable = 1
opcache.memory_consumption = 256
opcache.max_accelerated_files = 20000
EOF

# vhost: docroot -> /var/www/bench, listener on :80
# (configure via WebAdmin once, or drop a prepared vhconf — see README)
systemctl stop nginx 2>/dev/null || true
systemctl enable --now lsws

echo "=== OLS installed. Set vhost docroot to /var/www/bench via WebAdmin (:7080)"
echo "    admin pass: /usr/local/lsws/admin/misc/admpass.sh ==="
