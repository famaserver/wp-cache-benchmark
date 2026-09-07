# WordPress Cache Plugin Benchmark

> 🇮🇷 [نسخه فارسی این سند](README.fa.md)

An open, reproducible benchmark of WordPress cache plugins — **Turbo, LiteSpeed Cache, WP Rocket, W3 Total Cache, WP Super Cache, WP Fastest Cache** — across **three web servers**: Nginx, Apache, and OpenLiteSpeed.

Every script, every configuration, and every raw result file lives in this repository. If you doubt a number, re-run it.

**Status: 🚧 work in progress** — baseline complete, plugin rounds underway.

## Why another benchmark?

Most cache plugin benchmarks are one-shot Lighthouse screenshots on a hello-world site. This one is different:

- **A real store**: Woodmart theme + Elementor + WooCommerce with **830 products, 109 posts, 234 orders**
- **Three web servers**, switched on the same machine with files, database, and PHP untouched — so a difference in numbers means the web server (or the plugin), nothing else
- **Median of ≥3–5 repeats**, always reported with p95 — never averages, never best-run
- **Raw data published** (k6 JSON, CPU logs, response headers proving cache hits)
- **Fairness rules** written down before the tests, not after

## Test environment (measured, not claimed)

| Component | Value |
|---|---|
| CPU | Intel Xeon Gold 6138 @ 2.00GHz — 4 vCPU (VMware) |
| RAM | 8 GB |
| Disk | 40 GB NVMe — **measured with fio**: 87.9k IOPS 4k rand-read, 64.4k IOPS 4k rand-write, 1.47 GB/s seq-read |
| Network | ~130/160 Mbit/s international (server in IR); load tests run locally / from a same-DC box |
| OS | Ubuntu 24.04.4 LTS |
| PHP | 8.2 (FPM static pool, 12 workers, OPcache 256 MB — identical limits on all stacks) |
| Database | MariaDB, 2G buffer pool — fixed config for every run |
| TLS | Let's Encrypt, HTTP/2 |

## Scenarios

| # | Scenario | Metric |
|---|---|---|
| S1 | Cold cache — first hit after purge ×5 cycles | TTFB |
| S2 | Warm cache — 15 sequential requests | TTFB median / p95 |
| S3–S5 | 50 / 200 / 500 concurrent users, 60 s × ≥3 repeats (k6) | RPS, TTFB p50/p95, error rate, CPU |
| S6 | Logged-in / full cart (cache bypass) | TTFB p50/p95 |
| S7 | Purge speed after updating one product | seconds, CPU |

URL mix per iteration: home, shop archive, 3 product pages, 2 blog posts.

## Results so far

### Baseline — no cache plugin (self-test¹, 50 VUs, 60 s × 3)

| Web server | RPS | TTFB p50 | TTFB p95 | Errors | CPU |
|---|---|---|---|---|---|
| Nginx 1.24 | 7.4 | 6 420 ms | 7 019 ms | 0% | ~99% |
| OpenLiteSpeed 1.9.2 | 7.3 | 6 445 ms | 7 049 ms | 0% | ~99% |
| Apache 2.4 (event) | 7.3 | 6 497 ms | 7 130 ms | 0% | ~99% |

Single-request TTFB (median of 15): home ≈ 850 ms, shop ≈ 710 ms on all three.

**Takeaways:** without a cache the bottleneck is PHP/CPU — the web server choice changes nothing (<1.5% spread). Capacity saturates at ~7 pages/s with a ~6.5 s queue at 50 concurrent users. Every improvement from here on is attributable to the cache layer.

> ¹ *self-test* = the load generator (k6) ran on the target server itself. All headline numbers will be re-measured from a separate same-datacenter box and labeled accordingly.

### Field note: OpenLiteSpeed LSAPI starvation

With OLS's default multiple worker processes, each worker opens its own connection pool to the single lsphp parent (12 children). Under saturation, requests pinned to a starved pool hang 30–60 s with `No request delivery notification has been received from LSAPI application, possible dead lock` (~7% timeouts at 50 VUs). Setting `httpdWorkers 1` fixed it completely: 0 errors, throughput on par with Nginx/Apache. See [`scripts/provision/ols/vhconf.conf`](scripts/provision/ols/vhconf.conf). Related: [openlitespeed#360](https://github.com/litespeedtech/openlitespeed/issues/360).

## Fairness rules

1. LiteSpeed Cache has server-level page caching **only** on LiteSpeed servers — its results on Nginx/Apache are reported separately with that context, never mixed into one table.
2. Every plugin is tested twice: **default settings** and **vendor-documented optimized settings**. The exact settings export of every run is published next to its results.
3. Turbo is tested under exactly the same two modes — no hidden tuning.
4. Between every change: full purge → PHP service restart → 3 warm-up passes.
5. Response headers are captured for every run as proof of cache hit/miss.

## Repository layout

```
scripts/provision/   server + arena setup (Nginx / Apache / OpenLiteSpeed)
scripts/bench/       orchestrators, TTFB probe, aggregator
scripts/k6/          k6 load scenario
methodology/         full methodology (EN / FA)
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
