# بیس‌لاین بدون کش — ۱۶ شهریور ۱۴۰۵ (2026-09-07)

## Environment and prerequisites — full specification

Everything below was identical for every plugin measured in this report. Where a value changed between test rounds it is stated explicitly.

**Test server** (dedicated VPS provided by FamaServer, VMware virtualization, no control panel, no other workloads):

| Component | Exact value |
|---|---|
| CPU | Intel(R) Xeon(R) Gold 6138 @ 2.00GHz — 4 vCPU |
| RAM | 8 GB |
| Disk | 40 GB NVMe-backed — measured with fio: 87,900 IOPS 4k random read; 64,400 IOPS 4k random write; 1.47 GB/s sequential read |
| Network | ~130/160 Mbit/s international (load generator runs locally — see the self-test limitation) |
| OS | Ubuntu 24.04.4 LTS |
| PHP | 8.2.33 — FPM static pool, exactly 12 workers; OPcache 256 MB; memory_limit 256M; identical limits on the lsphp 8.2 stack used by OpenLiteSpeed |
| Database | MariaDB 10.11.14 — innodb_buffer_pool_size 2G, max_connections 300 (fixed for all runs) |
| Web servers | Nginx 1.24.0 · Apache 2.4.58 (mpm_event) · OpenLiteSpeed 1.9.2 — one active at a time via arena-switch.sh; site files, database and PHP untouched between switches |
| TLS | Let's Encrypt certificate, HTTPS enforced, HTTP/2 |
| Loaders | SourceGuardian 15.x (ionCube 15.5.0 was added 2026-09-09, for later rounds) |
| Object cache | none — Redis was not installed at the time of this round |
| Apache tuning | distribution defaults (mpm_event MaxRequestWorkers 150) |

**Test site** — https://bench.fama.co.ir (live):

| Component | Exact value |
|---|---|
| WordPress | 7.1 |
| WooCommerce | 9.9.5 |
| Theme | Woodmart 8.2.6 (full demo import) |
| Page builder | Elementor 3.30.2 |
| Content | 830 published products, 109 posts, 234 orders, 15+ pages |
| Permalinks | /%postname%/ |
| URL mix per iteration | home, /shop/, 3 product pages, 2 posts (bench/urls.txt) |

**Plugin versions measured in this report:** none — this is the no-plugin baseline. Cache plugins present but deactivated: LiteSpeed Cache 7.9.1, W3 Total Cache 2.10.6, WP Super Cache 3.1.3, WP Fastest Cache 1.5.1.

**Load tool:** k6 v2.2.0, executed on the test server itself (self-test). Scenario: scripts/k6/load-test.js (Test 1/2 protocol — includes a 0–0.5 s per-iteration sleep, which caps 50 VUs at ≈198 RPS; superseded in Test 3).


روش: k6 روی خود سرور (برچسب: **تست داخلی/self-test** — با رسیدن load generator تکرار می‌شود).
هر عدد بار: median از ۳ تکرار × ۶۰ ثانیه × ۵۰ کاربر همزمان، میکس ۷ صفحه (`bench/urls.txt`).
پروب TTFB: ۱۵ درخواست ترتیبی. محیط: طبق BENCHMARK-PLAN.md (PHP 8.2، ۱۲ ورکر، opcache ثابت).

## تست بار — ۵۰ کاربر همزمان

| وب‌سرور | RPS | TTFB p50 | TTFB p95 | خطا | CPU حین تست |
|---|---|---|---|---|---|
| Nginx 1.24 | 7.4 | 6420 ms | 7019 ms | 0% | ~99% |
| OpenLiteSpeed 1.9.2 | 7.3 | 6445 ms | 7049 ms | 0% | ~99% |
| Apache 2.4 (event) | 7.3 | 6497 ms | 7130 ms | 0% | ~99% |

## TTFB تک‌درخواست (median از ۱۵)

| وب‌سرور | خانه | فروشگاه |
|---|---|---|
| OpenLiteSpeed | 842.5 ms | 719.0 ms |
| Apache | 859.9 ms | 707.4 ms |
| Nginx | 862.4 ms | 708.6 ms |

## نتیجه‌گیری

1. بدون کش، **گلوگاه CPU/PHP است نه وب‌سرور** — اختلاف سه وب‌سرور <1.5٪ (در حد نویز).
   این دقیقاً چیزی است که «اثر پلاگین کش» را قابل اندازه‌گیری می‌کند: هر بهبودی از اینجا به بعد، کار کش است.
2. ظرفیت اشباع سرور بدون کش: **~7.3 صفحه در ثانیه** با صف انتظار ~6.5 ثانیه در ۵۰ کاربر.
3. یافته فنی: OLS با چند httpd worker دچار starvation صف LSAPI می‌شود
   (خطای "possible dead lock"، ~7٪ تایم‌اوت). با `httpdWorkers 1` رفع شد — در گزارش نهایی مستند می‌شود.

داده خام: `bench/results-baseline-selftest/` (JSONهای k6 + لاگ CPU mpstat + لاگ پروب‌ها)
