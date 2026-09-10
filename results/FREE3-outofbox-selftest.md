# W3 Total Cache 2.10.6 · WP Super Cache 3.1.3 · WP Fastest Cache 1.5.1

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

**Plugin versions measured in this report:** W3 Total Cache 2.10.6, WP Super Cache 3.1.3, WP Fastest Cache 1.5.1 — each activated with no configuration changes; all other cache plugins deactivated during each run.

**Load tool:** k6 v2.2.0, executed on the test server itself (self-test). Scenario: scripts/k6/load-test.js (Test 1/2 protocol — includes a 0–0.5 s per-iteration sleep, which caps 50 VUs at ≈198 RPS; superseded in Test 3).

## Out-of-the-box behavior (activate, change nothing) — self-test — Round 1 (2026-09)

Protocol identical to the other runs. The per-run **verification gate** is the story here:

| Plugin | advanced-cache.php | WP_CACHE | 2nd-hit TTFB | Verdict |
|---|---|---|---|---|
| W3 Total Cache | 0 bytes | true | 992 ms | **page cache NOT engaged** |
| WP Super Cache | 0 bytes | true | 931 ms | **page cache NOT engaged** |
| WP Fastest Cache | 0 bytes | true | 961 ms | **page cache NOT engaged** |

Load numbers confirm it — all three sit at baseline (~6.5 RPS, p50 ~7.3 s at 50 VUs,
full tables in the raw data). Compare WP Rocket (~192 RPS) and LiteSpeed-Cache-on-OLS
(~195 RPS) in the same protocol.

## The finding

**Activating these three plugins does nothing for page caching until you enable it
in their settings.** WP Rocket and LiteSpeed Cache cache by default on activation;
W3TC, WP Super Cache, and WP Fastest Cache ship with caching off. A site owner who
installs them and stops there gets zero benefit.

This is reported as a result, not a disqualification: an **"enabled settings" run**
for each of the three is queued in this round, and those numbers will be the ones
used in cross-plugin comparisons.

Raw data: [`free3-outofbox-selftest/`](free3-outofbox-selftest/)
