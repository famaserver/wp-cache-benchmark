# Turbo 3.1.3 (vendor-configured: license, preload cron, Redis available) — self-test — Round 1 (2026-09)

Same protocol as the other plugins. Proof of caching captured per arena:
`x-turbo-cache: HIT` + `x-cache-provider: turbo` on Nginx/Apache;
on OpenLiteSpeed Turbo emits `x-litespeed-cache-control` + its own
`x-litespeed-tag: turbo_*` tags — a **native LiteSpeed server-cache integration**,
verified with a clean miss→hit cycle after full server-cache purge
(miss on first GET, hit at 152 ms on the second).

OLS cold-cache cycles were re-measured with the server cache store wiped
(`/usr/local/lsws/cachedata`) — the first pass missed it and read ~154 ms "cold" hits.

## Warm-cache load — 50 VUs (median of 3)

| Web server | RPS | TTFB p50 | TTFB p95 | Errors | vs baseline |
|---|---|---|---|---|---|
| **OpenLiteSpeed** | **193.9** | **0.4 ms** | 2.4 ms | 0% | **×26.6** |
| Nginx | 12.3 | 3 750 ms | 4 018 ms | 0% | ×1.7 |
| Apache | 12.2 | 3 760 ms | 4 012 ms | 0% | ×1.7 |

## Warm single-request TTFB (median of 15)

| Web server | Home | Shop |
|---|---|---|
| OpenLiteSpeed | 154.3 ms | 154.8 ms |
| Nginx | 476.9 ms | 509.3 ms |
| Apache | 483.7 ms | 508.8 ms |

## Cold cache — purge → first hit (5 cycles, home)

| Web server | Runs (ms) | Median |
|---|---|---|
| OpenLiteSpeed | 1179, 1201, 1164, 1159, 1316 | 1 179 |
| Nginx | 1272, 1245, 1259, 1255, 1225 | 1 255 |
| Apache | 1447, 1246, 1286, 1264, 1271 | 1 271 |

## Findings

1. **On OpenLiteSpeed, Turbo matches LiteSpeed Cache** (193.9 vs 194.9 RPS,
   identical sub-ms p50): its LiteSpeed integration hands pages to the server
   cache module with its own tag set (`turbo_front`, …) — the same mechanism
   LSCache uses, working at full server speed.
2. **On Nginx/Apache, Turbo caches but serves hits through the full WordPress
   bootstrap**: no `advanced-cache.php` drop-in is installed, so every cache hit
   still loads WordPress (~480–510 ms/hit, CPU-bound), capping load throughput at
   ~12 RPS versus WP Rocket's ~192 RPS drop-in serving on the same arenas.
   Turbo does beat the no-cache baseline (×1.7), but the gap to drop-in-based
   serving on non-LiteSpeed servers is the clear optimization target.
3. Cold first-hit (~1.2 s) is in line with the other plugins (uncached render +
   cache write).

Raw data: [`turbo-configured-selftest/`](turbo-configured-selftest/)
