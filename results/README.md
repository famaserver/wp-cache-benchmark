# Tests archive — all rounds, all reports, all raw data

Every test round ever published in this benchmark remains permanently available here and via its git tag. Each report is self-contained: it opens with the **full environment specification** (server hardware with measured disk performance, OS, PHP/database/web-server versions and configuration, site content counts, exact plugin versions, load tool and scenario) valid for that round.

| Round | Date(s) | Git tag | Contents | Reports |
|---|---|---|---|---|
| **Test 1** | 2026-09-07 → 08 | `test-1` | Capped protocol (k6 with per-iteration sleep). No-cache baseline on 3 web servers; LiteSpeed Cache defaults; Turbo Cache 3.1.3 | [Baseline](BASELINE-nocache-selftest.md) · [LiteSpeed Cache](LSCACHE-default-selftest.md) · [Turbo Cache 3.1.3](TURBO-configured-selftest.md) |
| **Test 2** | 2026-09-08 → 09 | `test-2` | Same capped protocol. WP Rocket defaults; Turbo Cache 3.2.4 (drop-in engine); W3TC/WPSC/WFC out-of-box; Cache Enabler & WP-Optimize as installed | [WP Rocket](ROCKET-default-selftest.md) · [Turbo Cache 3.2.4](TURBO-3.2.4-selftest.md) · [Free trio out-of-box](FREE3-outofbox-selftest.md) · raw: [`wpo-cenabler-selftest/`](wpo-cenabler-selftest/) |
| **Test 3** | 2026-09-10 | `test-3` | **Uncapped protocol** (no k6 sleep, cache-alive gate, ±σ published). Turbo Cache 3.3.3 in all three engines; WP Rocket, Cache Enabler, LiteSpeed Cache on all applicable arenas; cold-cache cycles | [Full Test 3 report](TEST3-uncapped-selftest.md) |

## Raw data directories

Each directory contains the unmodified k6 JSON of every individual run, response-header captures, cold-cache probe logs, CPU logs (`mpstat`) where recorded, and plugin-state/verification artifacts:

- [`baseline-nocache-selftest/`](baseline-nocache-selftest/) · [`lscache-default-selftest/`](lscache-default-selftest/) · [`turbo-configured-selftest/`](turbo-configured-selftest/)
- [`rocket-default-selftest/`](rocket-default-selftest/) · [`turbo-3.2.4-selftest/`](turbo-3.2.4-selftest/) · [`free3-outofbox-selftest/`](free3-outofbox-selftest/) · [`wpo-cenabler-selftest/`](wpo-cenabler-selftest/)
- [`test3-uncapped-selftest/`](test3-uncapped-selftest/)

## Comparing across rounds

Test 1/2 throughput figures were taken under the capped scenario (a deliberate 0–0.5 s per-iteration sleep limited 50 VUs to ≈198 RPS) and are **not comparable** with Test 3's uncapped figures. Within a round, every plugin ran under the identical protocol; cross-round comparisons are valid only for the same protocol (e.g., Turbo 3.1.3 vs 3.2.4 under Test 1/2; engine modes under Test 3). Each report states its scenario file explicitly.

## Reproduce any round

```bash
bash ../scripts/provision/01-base.sh <your-domain>      # clean Ubuntu 24.04
bash ../scripts/bench/plugin-bench.sh <slug> <label>    # Test 1/2 protocol
bash ../scripts/bench/test3-run.sh <slug> <label>       # Test 3 protocol
```
