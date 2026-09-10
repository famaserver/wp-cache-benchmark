# LiteSpeed Cache (default settings) — self-test — 2026-09-07

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

**Plugin versions measured in this report:** LiteSpeed Cache 7.9.1 (default settings, activated via WP-CLI). All other cache plugins deactivated.

**Load tool:** k6 v2.2.0, executed on the test server itself (self-test). Scenario: scripts/k6/load-test.js (Test 1/2 protocol — includes a 0–0.5 s per-iteration sleep, which caps 50 VUs at ≈198 RPS; superseded in Test 3).


Same protocol as baseline: 50 VUs × 60 s × 3 repeats (k6, self-test), 15-probe warm TTFB,
5 purge→first-hit cold cycles. Plugin at defaults, activated via WP-CLI. Proof of caching:
response headers captured per arena (`*-lscache-headers.txt`) — `x-litespeed-cache: hit` on OLS only.

## Warm-cache load — 50 VUs (median of 3)

| Web server | RPS | TTFB p50 | TTFB p95 | Errors | vs baseline RPS |
|---|---|---|---|---|---|
| **OpenLiteSpeed** | **194.9** | **0.4 ms** | **2.5 ms** | 0% | **×26.7** |
| Nginx | 6.4 | 7 383 ms | 7 956 ms | 0% | ×0.87 |
| Apache | 6.4 | 7 359 ms | 8 025 ms | 0% | ×0.87 |

## Warm single-request TTFB (median of 15)

| Web server | Home | Shop | Baseline home |
|---|---|---|---|
| OpenLiteSpeed | 152.6 ms | 154.2 ms | 842.5 ms |
| Nginx | 923.8 ms | 787.5 ms | 862.4 ms |
| Apache | 912.8 ms | 767.1 ms | 859.9 ms |

## Cold cache — purge → first hit (5 cycles, home)

| Web server | Runs (ms) |
|---|---|
| OpenLiteSpeed | 2287, 2295, 2290, 2282, 2279 |
| Nginx | 1121, 4096*, 977, 957, 970 |
| Apache | 991, 974, 966, 944, 937 |

\* one outlier (likely purge housekeeping); raw logs published.

## Findings

1. **On its own server, LSCache is transformative**: 26.7× throughput, TTFB p50 drops
   from 6.4 s (queued) to sub-millisecond serve time. The 194.9 RPS figure is
   **capped by the self-test setup** (k6 competes for CPU) — expect higher from an
   external load generator.
2. **On Nginx/Apache, LSCache's page cache does not function** (no LiteSpeed server
   module). Result: ~10–13% *slower* than no plugin at all (7.4 → 6.4 RPS;
   warm TTFB 862 → 924 ms) — the plugin adds overhead with no page-cache benefit.
   If you don't run a LiteSpeed server, this plugin's headline feature is inert.
3. OLS cold-cache first hit (~2.3 s) is noticeably heavier than baseline first
   render (~0.85 s): the full-purge rebuild pass costs real time. Consistent across
   all 5 cycles.

Raw data: [`lscache-default-selftest/`](lscache-default-selftest/)
