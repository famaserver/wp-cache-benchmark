# Turbo 3.2.4 (drop-in cache engine) — self-test — Test 2 (2026-09-08)

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
