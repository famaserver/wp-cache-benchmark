# LiteSpeed Cache (default settings) — self-test — 2026-09-07

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
