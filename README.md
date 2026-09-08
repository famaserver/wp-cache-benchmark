# WordPress Cache Plugin Benchmark

**🇬🇧 English** · [🇮🇷 فارسی](README.fa.md) · [🇸🇦 العربية](README.ar.md)

An open, reproducible benchmark of WordPress cache plugins — **Turbo, LiteSpeed Cache, WP Rocket, W3 Total Cache, WP Super Cache, WP Fastest Cache** — across **three web servers**: Nginx, Apache, and OpenLiteSpeed.

Every script, every configuration, and every raw result file lives in this repository. If you doubt a number, re-run it.

![Warm-cache throughput, 50 concurrent users](charts/rps-warm-50vu.svg)

**Status: 🚧 Round 1 in progress** — baseline ✅ · LiteSpeed Cache ✅ · WP Rocket ✅ · Turbo, W3TC, WP Super Cache, WP Fastest Cache: queued.

## Benchmark versioning

Plugins update, servers update — a benchmark is a snapshot, not an eternal truth. So results are versioned as **rounds**:

- **Round 1 — `2026-09`** (current): component versions pinned in the table below; every results directory and chart is stamped with the round id; the finished round gets git tag `round-1`.
- Future rounds re-run the same scenarios with updated components and their own pinned-version table, so improvements (or regressions) in any plugin update are visible over time.

## Test environment (measured, not claimed)

Test server provided by **[FamaServer](https://famaserver.com)** — an isolated VPS dedicated to this benchmark, no control panel, no other workloads.

| Component | Value |
|---|---|
| Provider | FamaServer — dedicated benchmark VPS |
| CPU | Intel Xeon Gold 6138 @ 2.00GHz — 4 vCPU (VMware) |
| RAM | 8 GB |
| Disk | 40 GB NVMe — **measured with fio**: 87.9k IOPS 4k rand-read, 64.4k IOPS 4k rand-write, 1.47 GB/s seq-read |
| Network | ~130/160 Mbit/s international; load tests run locally / from a same-DC box |
| OS | Ubuntu 24.04.4 LTS |
| PHP | 8.2 (FPM static pool, 12 workers, OPcache 256 MB — identical limits on all stacks) |
| Database | MariaDB 10.11.14, 2G buffer pool — fixed config for every run |
| TLS | Let's Encrypt, HTTP/2 |

### Versions under test — Round 1 (2026-09)

| Component | Version | | Component | Version |
|---|---|---|---|---|
| WordPress | 7.1 | | LiteSpeed Cache | 7.9.1 |
| WooCommerce | 9.9.5 | | WP Rocket | 3.18.3 |
| Woodmart theme | 8.2.6 | | **Turbo** | **3.1.3** |
| Elementor | 3.30.2 | | W3 Total Cache | 2.10.6 |
| Nginx | 1.24.0 | | WP Super Cache | 3.1.3 |
| Apache | 2.4.58 (mpm_event) | | WP Fastest Cache | 1.5.1 |
| OpenLiteSpeed | 1.9.2 | | k6 (load tool) | 2.2.0 |

Site content: **830 products, 109 posts, 234 orders** (Woodmart demo + WC Smooth Generator).

## Why another benchmark?

Most cache plugin benchmarks are one-shot Lighthouse screenshots on a hello-world site. This one is different:

- **A real store**: Woodmart + Elementor + WooCommerce at realistic scale
- **Three web servers**, switched on the same machine with files, database, and PHP untouched — a difference in numbers means the web server (or the plugin), nothing else
- **Median of ≥3–5 repeats**, always reported with p95 — never averages, never best-run
- **Raw data published** (k6 JSON, CPU logs, response headers proving cache hits)
- **Versioned rounds** — re-run after major plugin updates
- **Fairness rules** written down before the tests, not after

## Scenarios

| # | Scenario | Metric |
|---|---|---|
| S1 | Cold cache — first hit after purge ×5 cycles | TTFB |
| S2 | Warm cache — 15 sequential requests | TTFB median / p95 |
| S3–S5 | 50 / 200 / 500 concurrent users, 60 s × ≥3 repeats (k6) | RPS, TTFB p50/p95, error rate, CPU |
| S6 | Logged-in / full cart (cache bypass) | TTFB p50/p95 |
| S7 | Purge speed after updating one product | seconds, CPU |

URL mix per iteration: home, shop archive, 3 product pages, 2 blog posts.

## Results — Round 1 (so far)

### Baseline — no cache plugin (self-test¹, 50 VUs)

| Web server | RPS | TTFB p50 | TTFB p95 | Errors | CPU |
|---|---|---|---|---|---|
| Nginx | 7.4 | 6 420 ms | 7 019 ms | 0% | ~99% |
| OpenLiteSpeed | 7.3 | 6 445 ms | 7 049 ms | 0% | ~99% |
| Apache | 7.3 | 6 497 ms | 7 130 ms | 0% | ~99% |

Without a cache the bottleneck is PHP/CPU — the web server choice changes nothing (<1.5% spread). Details: [`results/BASELINE-nocache-selftest.md`](results/BASELINE-nocache-selftest.md)

### LiteSpeed Cache 7.9.1 — default settings (self-test¹, 50 VUs, warm)

| Web server | RPS | TTFB p50 | vs baseline |
|---|---|---|---|
| **OpenLiteSpeed** | **194.9** | **0.4 ms** | **×26.7** |
| Nginx | 6.4 | 7 383 ms | ×0.87 — *slower than no plugin* |
| Apache | 6.4 | 7 359 ms | ×0.87 — *slower than no plugin* |

On its own server LSCache is transformative; on Nginx/Apache its page cache is inert and the plugin becomes pure overhead. Details: [`results/LSCACHE-default-selftest.md`](results/LSCACHE-default-selftest.md)

### WP Rocket 3.18.3 — default settings (self-test¹, 50 VUs, warm)

| Web server | RPS | TTFB p50 | vs baseline |
|---|---|---|---|
| Nginx | **193.3** | 1.8 ms | ×26.1 |
| OpenLiteSpeed | **192.9** | 2.1 ms | ×26.4 |
| Apache | **190.9** | 2.3 ms | ×26.2 |

Web-server-independent: statistically identical on all three arenas. Its first run was discarded by our own verification gate (stale-cache contamination + cache silently off) — full story in [`results/ROCKET-default-selftest.md`](results/ROCKET-default-selftest.md).

> ¹ *self-test* = the load generator (k6) ran on the target server itself. All headline numbers will be re-measured from a separate same-datacenter box and labeled accordingly.

### Field note: OpenLiteSpeed LSAPI starvation

With OLS's default multiple worker processes, requests pinned to a starved LSAPI connection pool hang 30–60 s (`possible dead lock`, ~7% timeouts at 50 VUs). `httpdWorkers 1` fixed it completely. See [`scripts/provision/ols/vhconf.conf`](scripts/provision/ols/vhconf.conf) and [openlitespeed#360](https://github.com/litespeedtech/openlitespeed/issues/360).

## Fairness rules

1. LiteSpeed Cache has server-level page caching **only** on LiteSpeed servers — its results on Nginx/Apache are reported separately with that context, never mixed into one table.
2. Every plugin is tested twice: **default settings** and **vendor-documented optimized settings** (preload enabled where the vendor recommends it). The exact settings export of every run is published next to its results.
3. Turbo is tested under exactly the same two modes — no hidden tuning.
4. Between every change: full purge → PHP service restart → 3 warm-up passes.
5. Response headers are captured for every run as proof of cache hit/miss.
6. Component versions are pinned and published per round.

## Repository layout

```
scripts/provision/   server + arena setup (Nginx / Apache / OpenLiteSpeed)
scripts/bench/       orchestrators, TTFB probe, aggregator
scripts/k6/          k6 load scenario
methodology/         full methodology (EN / FA / AR)
results/             raw k6 JSON, CPU logs, probe logs, per-run summaries
charts/              charts & infographics generated from results
```

## Reproduce it

```bash
# on a clean Ubuntu 24.04 box
bash scripts/provision/01-base.sh <your-domain>
bash scripts/provision/03a-nginx.sh <your-domain>   # arena A
bash scripts/provision/03c-apache.sh <your-domain>  # arena B
bash scripts/provision/03b-openlitespeed.sh <your-domain>  # arena C
# then, per plugin:
bash scripts/bench/plugin-bench.sh <plugin-slug> <label>
python3 scripts/bench/summarize.py results/<run-dir>/
```

## License

Scripts and documentation: MIT. Raw result data: CC BY 4.0 — cite this repository.
