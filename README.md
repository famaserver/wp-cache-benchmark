# WordPress Cache Plugin Benchmark

**🇬🇧 English** · [🇮🇷 فارسی](README.fa.md) · [🇸🇦 العربية](README.ar.md)

An open, reproducible benchmark of WordPress cache plugins on three web servers: Nginx, Apache, and OpenLiteSpeed.
Every script, configuration, and raw data point is published in this repository for independent verification — and the exact runner script is included so you can reproduce any number yourself.

## 🏆 Overall ranking — Test 3 (2026-09-10)

Criterion: peak verified throughput, each plugin in the best mode it supports on any web server (full per-server tables below — Turbo Cache also leads on **each individual server**):

| Rank | Plugin | Peak RPS (50 users) | Mode |
|---|---|---|---|
| 🥇 | **[Turbo Cache](https://www.zhaket.com/web/turbo-plugin) 3.3.3** | **3 154** | Nginx rewrite — cache served with no PHP |
| 🥈 | LiteSpeed Cache 7.9.1 | 2 091 | LiteSpeed server cache (OLS only) |
| 🥉 | Cache Enabler 1.8.16 | 1 198 | PHP drop-in (OLS) |
| 4 | WP Rocket 3.18.3 | 1 106 | PHP drop-in (OLS) |

![Uncapped throughput](charts/rps-uncapped-50vu.svg)

![TTFB](charts/ttfb-warm.svg)

## Test 3 — what was measured

Same environment as before ([VPS](https://famaserver.com/vps/) by FamaServer · 4 vCPU Xeon Gold 6138 · 8 GB · NVMe · Ubuntu 24.04 · PHP 8.2, 12 workers on every stack · MariaDB · Redis · WordPress + WooCommerce + Woodmart, 830 products). Protocol upgrades over Test 1/2, each documented in the [full report](results/TEST3-uncapped-selftest.md):

- **k6 without per-iteration sleep** — Test 1/2's scenario capped every fast plugin at ≈198 RPS; uncapped, the "~192 tier" separated into 766…3 154.
- **Cache-alive gate** before every measurement (one early attempt that silently measured a dead cache was discarded — the gate exists so that can never recur).
- **Cold cache = page-cache purge only** (no object-cache flush — no rival installs an object cache, so flushing Redis taxed only Turbo Cache).
- Apache mpm_event tuned identically for all plugins; 5 × 30 s runs at 50 users, 3 × at 200; medians **± standard deviation** published.

### Plugins under test

| # | Plugin | Version | Type | # | Plugin | Version | Type |
|---|---|---|---|---|---|---|---|
| 1 | [Turbo Cache](https://www.zhaket.com/web/turbo-plugin) | 3.3.3 | commercial | 5 | W3 Total Cache | 2.10.6 | free |
| 2 | LiteSpeed Cache | 7.9.1 | free | 6 | WP Super Cache | 3.1.3 | free |
| 3 | WP Rocket | 3.18.3 | commercial | 7 | WP Fastest Cache | 1.5.1 | free |
| 4 | Cache Enabler | 1.8.16 | free | 8 | WP-Optimize | 4.6.1 | free |

Auxiliary (not a page cache): Cache Warmer 1.3.10.

### Results — 50 concurrent users, warm cache (median ± σ)

| Plugin | Nginx | Apache | OpenLiteSpeed |
|---|---|---|---|
| **Turbo Cache — best mode** | **3 154 ± 336** (rewrite) | **2 228 ± 26** (.htaccess) | **2 279 ± 21** (server cache) |
| Turbo Cache — PHP drop-in | 1 170 ± 17 | 847 ± 25 | — |
| LiteSpeed Cache | inert | inert | 2 091 ± 13 |
| Cache Enabler | 1 025 ± 88 | 808 ± 63 | 1 198 ± 9 |
| WP Rocket | 961 ± 17 | 766 ± 5 | 1 106 ± 7 |
| *(no cache)* | *7.4* | *7.3* | *7.3* |

W3 Total Cache, WP Super Cache, WP Fastest Cache and WP-Optimize ship with page caching disabled (Test 2) and are excluded from this round; an enabled-settings round is queued. 200-user tables, cold-cache cycles and headers evidence: [full report](results/TEST3-uncapped-selftest.md).

### What Test 3 proves

**1 — Turbo Cache is first on every web server**: +22% over WP Rocket in the drop-in class on Nginx (1 170 vs 961), +9% over LiteSpeed Cache on LiteSpeed's own server (2 279 vs 2 091), and ×2.3–×3.3 over every rival in its rewrite modes.

**2 — Turbo Cache is the only plugin with automated web-server-level serving on all three servers**: generated nginx rules, an automatic `.htaccess` block, and native LiteSpeed server-cache integration (tag sidecars, verified miss→hit). WP Rocket ships none of these; LiteSpeed Cache works on LiteSpeed only.

**3 — Cold cache is now a tie with WP Rocket** (~1.06 s first paint after purge, both): since 3.3.3 the first visitor gets raw HTML immediately and the optimization pass replaces the cached files in the background.

**4 — Every claim is header-verified**: `x-turbo-cache-engine: nginx | htaccess | dropin`, `x-litespeed-cache: miss→hit`, captured per arena and published with the raw data.

### Understanding the two TTFB figures

The **single-request probe** (~130 ms warm) includes the probe's own TLS handshake — it is comparative, not an end-user latency. The **load-test p50** (7–50 ms) is the server-side response time under concurrency. Both are published; they measure different things.

### Verify it yourself

```bash
# the exact scripts that produced these numbers:
bash scripts/provision/01-base.sh <your-domain>     # clean Ubuntu 24.04 box
bash scripts/bench/test3-run.sh turbo turbo         # or wp-rocket, cache-enabler, ...
python3 scripts/bench/summarize.py results-test3/
```

The test site is a real store; every raw k6 JSON, CPU log and header capture is in [`results/`](results/).

### Progress tracking

| Test | Date | Turbo Cache | Peak result | Status |
|---|---|---|---|---|
| Test 1 | 2026-09-08 | 3.1.3 | 12 RPS on Nginx (no drop-in engine) | ✅ `test-1` |
| Test 2 | 2026-09-08 | 3.2.4 | ~192 RPS (harness-capped tier) | ✅ `test-2` |
| **Test 3** | **2026-09-10** | **3.3.3** | **3 154 RPS uncapped — first on every server** | ✅ `test-3` |
| Test 4 | TBD | — | external load generator, 500 users, enabled-settings round, front-end round | 🔜 |

### Limitations

Self-test (the load generator shared the server's 4 cores — figures are conservative lower bounds); single hardware profile; no CDN; probe TTFB includes TLS. External-load-generator re-measurement is the headline of Test 4.

License: MIT (scripts) · CC BY 4.0 (data)
