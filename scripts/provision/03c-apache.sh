#!/usr/bin/env bash
# Turbo Benchmark — Arena B: Apache 2.4 (mpm_event) + PHP-FPM 8.2
# Coexists with nginx/OLS: only ONE web server runs at a time (arena-switch.sh).
set -euo pipefail
DOMAIN="${1:?usage: bash 03c-apache.sh <domain>}"

apt-get -y install apache2
systemctl stop apache2 || true
systemctl disable apache2 || true   # arena-switch controls who runs

a2dismod mpm_prefork php8.2 2>/dev/null || true
a2enmod mpm_event proxy_fcgi setenvif rewrite headers expires http2 ssl
a2enconf php8.2-fpm

cat >/etc/apache2/sites-available/bench.conf <<EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    Redirect permanent / https://${DOMAIN}/
</VirtualHost>
<VirtualHost *:443>
    ServerName ${DOMAIN}
    DocumentRoot /var/www/bench
    Protocols h2 http/1.1
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/${DOMAIN}/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN}/privkey.pem
    <Directory /var/www/bench>
        AllowOverride All
        Require all granted
    </Directory>
    <FilesMatch \.php\$>
        SetHandler "proxy:unix:/run/php/php8.2-fpm.sock|fcgi://localhost"
    </FilesMatch>
</VirtualHost>
EOF
a2dissite 000-default
a2ensite bench
apache2ctl configtest
echo "=== Apache arena installed (disabled). Switch with arena-switch.sh apache ==="
