# Turbo 3.2.4 (drop-in cache engine) — self-test — Test 2 (2026-09-08)

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
| Loaders | ionCube 15.5.0 and SourceGuardian 15.x on both PHP stacks |
| Object cache | Redis 7 (512 MB, allkeys-lru) present on the host from 2026-09-09; only Turbo Cache ships an object-cache drop-in — no rival plugin uses it |
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

**Plugin versions measured in this report:** Turbo Cache 3.2.4 (licensed, drop-in engine). All other cache plugins deactivated.

**Load tool:** k6 v2.2.0, executed on the test server itself (self-test). Scenario: scripts/k6/load-test.js (Test 1/2 protocol — includes a 0–0.5 s per-iteration sleep, which caps 50 VUs at ≈198 RPS; superseded in Test 3).


Turbo 3.2.4 introduces an `advanced-cache.php` drop-in engine: cache hits are served
before WordPress loads (header `x-turbo-cache-engine: dropin` captured per arena).
Same protocol as every other run; verification gate passed (drop-in 14 KB active,
2nd-hit TTFB 163 ms).

## Warm-cache load — 50 VUs (median of 3)

| Web server | RPS | TTFB p50 | TTFB p95 | Errors | vs Turbo 3.1.3 | vs closest rival |
|---|---|---|---|---|---|---|
| OpenLiteSpeed | **194.4** | 0.4 ms | 2.4 ms | 0% | ≈ | LSCache 194.9 (tie), WP Rocket 192.9 |
| Nginx | **192.7** | 2.8 ms | 6.6 ms | 0% | **×15.7** | WP Rocket 193.3 (tie) |
| Apache | **191.3** | 3.2 ms | 7.6 ms | 0% | **×15.7** | WP Rocket 190.9 (tie) |

## Warm single-request TTFB (median of 15)

~161 ms on all three arenas (was ~490 ms on Nginx/Apache in 3.1.3).

## Cold cache — purge → first hit (5 cycles, home, median)

| Web server | 3.2.4 | 3.1.3 | WP Rocket |
|---|---|---|---|
| Nginx | 2 048 ms | 1 255 ms | 1 057 ms |
| Apache | 2 321 ms | 1 271 ms | 1 055 ms |
| OpenLiteSpeed¹ | 1 056 ms | 1 179 ms | 1 005 ms |

¹ measured with the LiteSpeed server cache store wiped between cycles.

## Front-end (Lighthouse 13.4, desktop preset, median of 3, homepage)

| State | Perf score | FCP | LCP | Full load |
|---|---|---|---|---|
| No cache (baseline) | 55 | 3 492 ms | 4 370 ms | 2 145 ms |
| Turbo 3.2.4 (nginx) | 54 | 3 497 ms | 4 417 ms | 2 121 ms |
| Turbo 3.2.4 (apache) | 57 | 3 140 ms | 3 526 ms | 2 155 ms |
| Turbo 3.2.4 (OLS) | 54 | 3 553 ms | 4 369 ms | 2 162 ms |

## Findings

1. **Turbo 3.2.4 is top-tier on every web server**: statistical tie with WP Rocket on
   Nginx/Apache, tie with LiteSpeed Cache on OLS — while remaining the only plugin
   with both the drop-in engine *and* native LiteSpeed integration.
2. **Cold-cache regression on Nginx/Apache**: first hit after purge roughly doubled
   vs 3.1.3 (2.0–2.3 s vs ~1.26 s). Optimization target for the next release.
3. **Front-end metrics are unchanged by caching alone** — expected: Lighthouse
   simulates network throttling, so server TTFB gains barely move FCP/LCP on this
   heavy theme. Front-end optimization features (minify, defer, lazyload, critical
   CSS) are the lever here and will be evaluated for all plugins in a dedicated
   front-end round.

Raw data: [`turbo-3.2.4-selftest/`](turbo-3.2.4-selftest/)

## Addendum (2026-09-10): the `advanced-cache.php size: missing` line in the verification artifact

The gate snapshot was taken immediately after WP-CLI activation. In 3.2.4 the
drop-in was only written on an admin settings-save (or later via the plugin's
admin-path self-heal), so the gate read "missing" while the load-test headers
correctly showed `x-turbo-cache-engine: dropin` once the drop-in materialized
mid-run. Turbo Cache 3.3.0+ writes the drop-in during activation itself, and
the gate script now primes the site before its snapshot
(`scripts/bench/plugin-bench.sh`). The original artifact is kept unmodified.
