#!/usr/bin/env bash
# Turbo Benchmark — theme + candidate plugins (installed but NOT active)
# Expects premium zips in /root/zips/: woodmart.zip, turbo.zip, (optional) wp-rocket.zip
set -euo pipefail

WP="wp --allow-root --path=/var/www/bench"
Z=/root/zips

# --- Woodmart (purchased) ---
[ -f $Z/woodmart.zip ] || { echo "MISSING: $Z/woodmart.zip"; exit 1; }
$WP theme install $Z/woodmart.zip --activate

# --- cache plugins under test: install, keep ALL inactive ---
[ -f $Z/turbo.zip ] && $WP plugin install $Z/turbo.zip || echo "NOTE: turbo.zip not found yet"
[ -f $Z/wp-rocket.zip ] && $WP plugin install $Z/wp-rocket.zip || echo "NOTE: wp-rocket.zip not found (premium)"
$WP plugin install litespeed-cache
$WP plugin install w3-total-cache
$WP plugin install wp-super-cache
$WP plugin install wp-fastest-cache

# make sure none of them start active
for p in litespeed-cache w3-total-cache wp-super-cache wp-fastest-cache wp-rocket turbo; do
  $WP plugin deactivate "$p" 2>/dev/null || true
done

# --- demo pages that will be benchmarked ---
$WP post create --post_type=page --post_status=publish --post_title='Bench Home' --allow-root >/dev/null || true

# record exact versions for the report
$WP core version > /root/versions.txt
php -v | head -1 >> /root/versions.txt
mysql --version >> /root/versions.txt
$WP theme list --format=csv >> /root/versions.txt
$WP plugin list --format=csv >> /root/versions.txt
echo "=== versions recorded in /root/versions.txt ==="
