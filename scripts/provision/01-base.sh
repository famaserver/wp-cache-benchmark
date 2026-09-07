#!/usr/bin/env bash
# Turbo Benchmark — base stack (Ubuntu 24.04 LTS)
# Run as root on a CLEAN server. Idempotent-ish; safe to re-run.
# Usage: bash 01-base.sh <domain-or-ip>
set -euo pipefail

DOMAIN="${1:?usage: bash 01-base.sh <domain-or-ip>}"
WP_PATH=/var/www/bench
DB_NAME=wp_bench
DB_USER=wp_bench
CREDS=/root/bench-credentials.txt

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get -y install software-properties-common curl unzip git jq
add-apt-repository -y ppa:ondrej/php
apt-get update
apt-get -y install mariadb-server \
  php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-intl php8.3-mbstring \
  php8.3-soap php8.3-xml php8.3-zip php8.3-imagick php8.3-bcmath

# --- fixed DB config: identical for every test run ---
cat >/etc/mysql/mariadb.conf.d/60-bench.cnf <<'EOF'
[mysqld]
innodb_buffer_pool_size = 2G
innodb_log_file_size    = 512M
max_connections         = 300
skip-name-resolve       = 1
EOF
systemctl restart mariadb

if [ -f "$CREDS" ]; then
  DB_PASS=$(grep '^DB_PASS=' "$CREDS" | cut -d= -f2)
else
  DB_PASS=$(openssl rand -hex 16)
  WP_PASS=$(openssl rand -hex 12)
  printf 'DB_PASS=%s\nWP_ADMIN=admin\nWP_PASS=%s\n' "$DB_PASS" "$WP_PASS" > "$CREDS"
  chmod 600 "$CREDS"
fi
WP_PASS=$(grep '^WP_PASS=' "$CREDS" | cut -d= -f2)

mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

# --- fixed PHP config: identical for every test run ---
for SAPI in fpm cli; do
cat >/etc/php/8.3/${SAPI}/conf.d/99-bench.ini <<'EOF'
memory_limit = 256M
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 256
opcache.max_accelerated_files = 20000
max_execution_time = 120
EOF
done

# static pool -> no autoscaling noise in results
sed -i \
  -e 's/^pm = .*/pm = static/' \
  -e 's/^pm.max_children = .*/pm.max_children = 12/' \
  /etc/php/8.3/fpm/pool.d/www.conf
systemctl restart php8.3-fpm

# --- WP-CLI ---
if ! command -v wp >/dev/null; then
  curl -sSLo /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /usr/local/bin/wp
fi

# --- WordPress ---
mkdir -p "$WP_PATH"
cd "$WP_PATH"
[ -f wp-load.php ] || sudo -u www-data -- wp core download 2>/dev/null || wp core download --allow-root
[ -f wp-config.php ] || wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass="$DB_PASS" --allow-root
wp core is-installed --allow-root || wp core install \
  --url="http://${DOMAIN}" --title="Turbo Bench" \
  --admin_user=admin --admin_password="$WP_PASS" \
  --admin_email=bench@example.com --skip-email --allow-root
wp option update permalink_structure '/%postname%/' --allow-root
chown -R www-data:www-data "$WP_PATH"

# --- WooCommerce + realistic content ---
wp plugin install woocommerce --activate --allow-root
wp plugin install https://github.com/woocommerce/wc-smooth-generator/releases/latest/download/wc-smooth-generator.zip --activate --allow-root
wp wc generate products 800 --allow-root
wp wc generate orders 200 --allow-root || true

echo
echo "=== BASE DONE — credentials in $CREDS ==="
echo "Next: upload woodmart.zip + plugin zips to /root/zips/ then run 02-content.sh"
