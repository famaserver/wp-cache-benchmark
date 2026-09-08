# W3 Total Cache 2.10.6 · WP Super Cache 3.1.3 · WP Fastest Cache 1.5.1
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
