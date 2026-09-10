# WP Rocket 3.18.3 (default settings) — self-test — Round 1 (2026-09)

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

**Plugin versions measured in this report:** WP Rocket 3.18.3 (default settings, licensed). All other cache plugins deactivated.

**Load tool:** k6 v2.2.0, executed on the test server itself (self-test). Scenario: scripts/k6/load-test.js (Test 1/2 protocol — includes a 0–0.5 s per-iteration sleep, which caps 50 VUs at ≈198 RPS; superseded in Test 3).


Same protocol as baseline/LSCache: 50 VUs × 60 s × 3 repeats per arena, 15-probe warm TTFB,
5 purge→first-hit cold cycles. Verification gate passed before measurement:
`WP_CACHE=true`, advanced-cache.php drop-in active (3 402 B), 2nd-hit TTFB 156 ms
([`rocket-verification.txt`](rocket-default-selftest/rocket-verification.txt)).

**Transparency note:** the first Rocket run was discarded — our checks caught stale
LiteSpeed Cache entries being served on OLS and Rocket's page cache silently off
(root-owned cache dirs, `WP_CACHE=false` after CLI activation). The protocol now wipes
all cache stores between plugins and verifies the cache mechanism before measuring.
Cold-cache runs were additionally re-measured after fixing the purge routine
(`rocket_clean_domain()` + physical cache file removal) — the original purge only
flushed the object cache, leaving page cache files intact.

## Warm-cache load — 50 VUs (median of 3)

| Web server | RPS | TTFB p50 | TTFB p95 | Errors | vs baseline RPS |
|---|---|---|---|---|---|
| Nginx | **193.3** | 1.8 ms | 4.5 ms | 0% | **×26.1** |
| OpenLiteSpeed | **192.9** | 2.1 ms | 4.8 ms | 0% | **×26.4** |
| Apache | **190.9** | 2.3 ms | 5.2 ms | 0% | **×26.2** |

## Warm single-request TTFB (median of 15)

| Web server | Home | Shop |
|---|---|---|
| Nginx | 154.7 ms | 155.0 ms |
| OpenLiteSpeed | 155.6 ms | 153.5 ms |
| Apache | 157.8 ms | 155.3 ms |

## Cold cache — purge → first hit (5 cycles, home)

| Web server | Runs (ms) | Median |
|---|---|---|
| Nginx | 2598*, 1057, 1064, 1062, 1045 | 1 057 |
| Apache | 1055, 1069, 1062, 989, 1042 | 1 055 |
| OpenLiteSpeed | 1005, 1004, 1015, 1032, 988 | 1 005 |

\* first cycle after plugin activation (config warm-up); raw logs published.

## Findings

1. **WP Rocket is web-server-independent**: ~192 RPS and ~2 ms p50 on all three
   arenas — statistically identical. Its PHP-level `advanced-cache.php` drop-in
   makes the web server irrelevant for cache hits.
2. Warm single-request TTFB (~155 ms) matches LSCache-on-OLS (~153 ms): once a page
   is cached, both serve it at effectively the same speed (the residual ~150 ms in
   probes is TLS handshake overhead of the probe itself).
3. Cold first-hit (~1.0–1.1 s) ≈ uncached render + cache write. Compare LSCache's
   full-purge rebuild on OLS (~2.3 s).
4. Throughput (~192 RPS) is **capped by the self-test setup** — k6 competes for the
   same 4 cores. External load-generator re-measurement pending.

Raw data: [`rocket-default-selftest/`](rocket-default-selftest/)
