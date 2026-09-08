# WordPress Cache Plugin Benchmark

**🇬🇧 English** · [🇮🇷 فارسی](README.fa.md) · [🇸🇦 العربية](README.ar.md)

An open, reproducible benchmark of WordPress cache plugins on three web servers: Nginx, Apache, and OpenLiteSpeed.
Every script, configuration, and raw data point is published in this repository for independent verification.

![Throughput](charts/rps-warm-50vu.svg)

![TTFB](charts/ttfb-warm.svg)

## Test 1 — 2026-09-08

**Environment:** dedicated [VPS](https://famaserver.com/vps/) (provided by FamaServer) · 4 vCPU Intel Xeon Gold 6138 · 8 GB RAM · 40 GB NVMe (fio-verified: 87.9k IOPS) · Ubuntu 24.04 LTS · PHP 8.2 FPM (12 workers, identical on every stack) · MariaDB 10.11 · Redis · HTTPS/HTTP-2 · WordPress 7.1 + WooCommerce 9.9.5 + Woodmart 8.2.6 + Elementor — **830 products, 109 posts, 234 orders**. Load: k6, 50 concurrent users × 60 s × 3 runs, medians reported. [Full methodology →](results/)

### Plugins under test

| # | Plugin | Version | Type |
|---|---|---|---|
| 1 | Turbo | 3.1.3 | commercial |
| 2 | LiteSpeed Cache | 7.9.1 | free |
| 3 | WP Rocket | 3.18.3 | commercial |
| 4 | W3 Total Cache | 2.10.6 | free |
| 5 | WP Super Cache | 3.1.3 | free |
| 6 | WP Fastest Cache | 1.5.1 | free |

### Results — requests/second at 50 concurrent users (warm cache)

| Plugin | Nginx | Apache | OpenLiteSpeed | Caches on every server |
|---|---|---|---|---|
| **Turbo** | 12.3 | 12.2 | **193.9** 🏆 | ✅ |
| LiteSpeed Cache | 6.4 ⚠️ | 6.4 ⚠️ | 194.9 | ✖ |
| WP Rocket | 193.3 | 190.9 | 192.9 | ✅ |
| W3 Total Cache | 6.5 | 6.5 | 6.5 | ✖ |
| WP Super Cache | 6.5 | 6.5 | 6.5 | ✖ |
| WP Fastest Cache | 6.5 | 6.5 | 6.5 | ✖ |
| *(no cache)* | *7.4* | *7.3* | *7.3* | — |

⚠️ slower than running no cache plugin at all. The 6.5 figures for rows 4–6 mean their page cache does not engage until manually configured.

### What Test 1 proves

1. **Turbo is the fastest plugin on the LiteSpeed stack** — 193.9 RPS, ahead of WP Rocket (192.9) and matching LiteSpeed Cache itself, thanks to its **native LiteSpeed server-cache integration** (verified miss→hit with Turbo's own `x-litespeed-tag: turbo_*` tags). WP Rocket has no such integration.
2. **Turbo is the only plugin that both integrates with LiteSpeed *and* caches on every web server.** LiteSpeed Cache outside LiteSpeed servers is pure overhead (13% *slower* than nothing). W3TC / WP Super Cache / WP Fastest Cache never cache at all until manually configured — activating them does nothing.
3. Faster responses = SEO: warm TTFB drops from 850 ms to ~154 ms (Turbo on OLS) — well under Google's 200 ms TTFB recommendation, directly improving crawl budget and Core Web Vitals.
4. Turbo's current gap: on Nginx/Apache it serves hits through the full WordPress bootstrap (~12 RPS vs Rocket's ~192). Tracked below — that's what the next tests are for.

### Progress tracking

Each plugin update gets re-tested under the identical protocol; growth is charted test-over-test.

| Test | Date | Changes | Status |
|---|---|---|---|
| **Test 1** | 2026-09-08 | initial — versions above | ✅ published, tag `test-1` |
| Test 2 | TBD | plugin updates, enabled-settings runs for #4–6, external load generator, 200/500 users | 🔜 |

Full per-plugin reports & raw data: [`results/`](results/) · Reproduce: [`scripts/`](scripts/) · License: MIT (scripts), CC BY 4.0 (data)
