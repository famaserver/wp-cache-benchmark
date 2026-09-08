# WP Rocket 3.18.3 (default settings) — self-test — Round 1 (2026-09)

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
