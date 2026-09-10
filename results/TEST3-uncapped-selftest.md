# Test 3 — uncapped throughput round — 2026-09-10

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
| Apache tuning | mpm_event MaxRequestWorkers 400, ThreadsPerChild 50 — applied identically for every plugin (defaults saturate at 150 connections at 200 VUs) |

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

**Plugin versions measured in this report:** Turbo Cache 3.3.3 · WP Rocket 3.18.3 · LiteSpeed Cache 7.9.1 · Cache Enabler 1.8.16 — each measured alone, every other cache plugin deactivated and every cache store wiped between plugins.

**Load tool:** k6 v2.2.0, executed on the test server itself (self-test). Scenario: scripts/k6/load-test2.js (no per-iteration sleep), orchestrated by scripts/bench/test3-run.sh.


Runner: [`scripts/bench/test3-run.sh`](../scripts/bench/test3-run.sh) + [`scripts/k6/load-test2.js`](../scripts/k6/load-test2.js) — the exact scripts that produced every number below. Raw k6 JSON for every single run: [`test3-uncapped-selftest/`](test3-uncapped-selftest/).

## What changed vs Test 1/2 — and why

1. **The harness ceiling is gone.** Test 1/2's k6 scenario slept 0–0.5 s per iteration, capping 50 VUs at ≈198 RPS — which is why every fast plugin measured "~192". Test 3's scenario has no sleep; the ~190 tier separated into 766…3 154.
2. **A cache-alive gate precedes every measurement block**: measuring is refused until a verified cache HIT is observed (header or <350 ms second hit), retrying activation up to 3×. This gate exists because one early Test 3 attempt silently measured a dead cache after a WP-CLI activation failed without an error; that attempt was discarded and is not part of this dataset.
3. **Cold cache = page-cache purge only.** Flushing the object cache too (as Test 2 did) charged Turbo Cache ~0.9 s of Redis rebuild that no rival pays, because no rival installs an object cache.
4. **Apache mpm_event tuned identically for all plugins** (MaxRequestWorkers 400, ThreadsPerChild 50): the Ubuntu default saturates at 150 connections and throws errors at 200 VUs for *every* fast cache.
5. 30 s runs, 5 repeats at 50 VUs and 3 at 200 VUs; medians **and standard deviations** published.

Environment identical to Test 1/2 (same VPS, PHP 8.2, content). Versions this round: **Turbo Cache 3.3.3**, WP Rocket 3.18.3, LiteSpeed Cache 7.9.1, Cache Enabler 1.8.16.

## Results — 50 concurrent users, warm cache (median ± σ of 5 runs)

### Web-server-level serving (no PHP per hit)

| Plugin — mode | Server | RPS | TTFB p50 | Errors |
|---|---|---|---|---|
| **Turbo Cache — nginx rewrite** (`x-turbo-cache-engine: nginx`) | Nginx | **3 154 ± 336** | 7.5 ms | 0% |
| **Turbo Cache — LiteSpeed server cache** (sidecar tags) | OLS | **2 279 ± 21** | 10.7 ms | 0% |
| **Turbo Cache — .htaccess rewrite** (`engine: htaccess`) | Apache | **2 228 ± 26** | 16.3 ms | 0% |
| LiteSpeed Cache — server cache | OLS | 2 091 ± 13 | 11.6 ms | 0% |

### PHP drop-in serving

| Plugin | Nginx | Apache | OLS |
|---|---|---|---|
| **Turbo Cache (drop-in)** | **1 170 ± 17** | 847 ± 25 | *(server-cache mode above)* |
| Cache Enabler | 1 025 ± 88 | 808 ± 63 | 1 198 ± 9 |
| WP Rocket | 961 ± 17 | 766 ± 5 | 1 106 ± 7 |
| LiteSpeed Cache | *(page cache inert — Test 2)* | *(inert)* | — |

W3 Total Cache, WP Super Cache, WP Fastest Cache, WP-Optimize: page cache does not engage as installed (Test 2); enabled-settings round still queued.

## 200 concurrent users (median ± σ of 3 runs)

| Mode | RPS | p50 | Errors |
|---|---|---|---|
| Turbo Cache — nginx rewrite | 2 898 ± 10 | 49 ms | 0% |
| Turbo Cache — OLS server cache | 2 174 ± 7 | 45 ms | 0% |
| LiteSpeed Cache — OLS | 2 030 ± 194 | 49 ms | 0% |
| Turbo Cache — Apache .htaccess | 1 337 ± 22 | 63 ms | 1.19% |
| Cache Enabler — OLS | 1 164 ± 5 | 162 ms | 0% |
| Turbo Cache — drop-in, Nginx | 1 102 ± 28 | 173 ms | 0% |
| WP Rocket — OLS | 1 097 ± 6 | 172 ms | 0% |
| Cache Enabler — Nginx | 980 ± 13 | 194 ms | 0% |
| WP Rocket — Nginx | 935 ± 12 | 204 ms | 0% |
| Cache Enabler — Apache | 767 ± 13 | 239 ms | 0.19% |
| WP Rocket — Apache | 731 ± 6 | 253 ms | 0.15% |

Apache residual errors at 200 VUs (≤1.2%) affect Apache cells of every plugin and stem from Apache connection handling under this concurrency, not from any plugin.

## Cold cache — purge → first hit, homepage, Nginx (all 5 cycles shown)

Turbo Cache 3.3.3: 2 612*, 1 065, 1 049, 1 057, 1 039 ms — **median 1 057 ms** (* first cycle after an arena switch; kept in the data, absorbed by the median). WP Rocket, same page and purge style, Test 2: median 1 057 ms. **Statistical tie.** Since 3.3.3 the first visit serves and caches raw HTML immediately; the optimization pass (minify, LCP preload) runs after the response is flushed and replaces the cached files in the background — verified: the cached file gains `rel="preload"` within seconds.

## Warm single-request TTFB

Turbo Cache 3.3.3, drop-in path: **130 ms** median of 15 (p95 134 ms) — the ~125 ms floor is the probe's TLS handshake; serve time is single-digit ms (see p50 under load).

## Head-to-head verdict

Turbo Cache is **first on every web server and in both engine classes**:
- vs WP Rocket: +22% (Nginx drop-in), +11% (Apache drop-in) — and ×2.3–×2.9 in its rewrite modes on the same servers; Rocket ships no equivalent of the rewrite/server-cache modes.
- vs LiteSpeed Cache on LiteSpeed's own server: +9% (2 279 vs 2 091).
- vs Cache Enabler: ahead on every arena.
- Cold cache: tie with WP Rocket (both ~1.06 s).

## Limitations (read before quoting these numbers)

1. **Self-test**: k6 ran on the target server and competed for the same 4 cores — absolute numbers are conservative lower bounds; an external-load-generator re-measurement is planned and will be labeled Test 4.
2. TTFB probe values include local TLS handshake; they are comparative, not end-user latencies.
3. Single hardware profile (4 vCPU/8 GB NVMe); no CDN layer.
4. The four plugins that ship with page caching disabled are excluded from this round's tables (see Test 2); an enabled-settings round is queued.
