// Turbo Benchmark — k6 load scenario
// Env: BASE_URL (required), VUS (default 50), DURATION (default 60s), LABEL (plugin name)
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE = __ENV.BASE_URL;
const LABEL = __ENV.LABEL || 'unlabeled';

// Real page mix: home, shop archive, 3 product pages, one static page.
// Update slugs after content generation (bench/urls.txt is the source of truth).
const PATHS = (__ENV.PATHS || '/,/shop/,/bench-home/').split(',');

export const options = {
  vus: Number(__ENV.VUS || 50),
  duration: __ENV.DURATION || '60s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const path = PATHS[Math.floor(Math.random() * PATHS.length)];
  const res = http.get(`${BASE}${path}`, {
    headers: { 'User-Agent': 'k6-turbo-bench/1.0' },
  });
  check(res, {
    'status 200': (r) => r.status === 200,
    'has html': (r) => String(r.body).includes('</html>'),
  });
  sleep(Math.random() * 0.5);
}

export function handleSummary(data) {
  const m = data.metrics;
  const out = {
    label: LABEL,
    vus: options.vus,
    duration: options.duration,
    rps: m.http_reqs.values.rate,
    ttfb_ms: {
      p50: m.http_req_waiting.values['p(50)'] ?? m.http_req_waiting.values.med,
      p95: m.http_req_waiting.values['p(95)'],
      avg: m.http_req_waiting.values.avg,
      max: m.http_req_waiting.values.max,
    },
    total_ms: {
      p50: m.http_req_duration.values.med,
      p95: m.http_req_duration.values['p(95)'],
    },
    error_rate: m.http_req_failed.values.rate,
    requests: m.http_reqs.values.count,
  };
  return {
    stdout: JSON.stringify(out, null, 2) + '\n',
    [`results/${LABEL}-vus${options.vus}-${Date.now()}.json`]: JSON.stringify(out, null, 2),
  };
}
