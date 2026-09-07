#!/usr/bin/env bash
# Turbo Benchmark — Arena A: Nginx + PHP-FPM
# (restore the clean snapshot first if OLS was installed before)
set -euo pipefail
DOMAIN="${1:?usage: bash 03a-nginx.sh <domain-or-ip>}"

apt-get -y install nginx
systemctl stop apache2 2>/dev/null || true

cat >/etc/nginx/sites-available/bench <<EOF
server {
    listen 80 default_server;
    server_name ${DOMAIN};
    root /var/www/bench;
    index index.php;

    # generic advanced-cache support (WP Rocket / W3TC / Super Cache write
    # their own rules; we keep vanilla PHP handoff so every plugin competes
    # on equal footing unless its docs require rewrite rules — documented per run)
    location / { try_files \$uri \$uri/ /index.php?\$args; }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
    location ~* \.(css|js|png|jpe?g|gif|webp|svg|woff2?)\$ {
        expires 30d; access_log off;
    }
}
EOF
ln -sf /etc/nginx/sites-available/bench /etc/nginx/sites-enabled/bench
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
echo "=== Nginx arena ready: http://${DOMAIN} ==="
