// Test-3 k6 scenario — UNCAPPED: no per-iteration sleep (fixes the ~198 RPS harness ceiling)
import http from 'k6/http';
import { check } from 'k6';

const BASE = __ENV.BASE_URL;
const LABEL = __ENV.LABEL || 'unlabeled';
const PATHS = (__ENV.PATHS || '/').split(',');

export const options = {
  vus: Number(__ENV.VUS || 50),
  duration: __ENV.DURATION || '30s',
  discardResponseBodies: true,
};

export default function () {
  const path = PATHS[Math.floor(Math.random() * PATHS.length)];
  const res = http.get(`${BASE}${path}`, { headers: { 'User-Agent': 'k6-turbo-bench/2.0' } });
  check(res, { 'status 200': (r) => r.status === 200 });
}

export function handleSummary(data) {
  const m = data.metrics;
  const out = {
    label: LABEL,
    vus: options.vus,
    duration: options.duration,
    rps: m.http_reqs.values.rate,
    ttfb_ms: {
      p50: m.http_req_waiting.values.med,
      p95: m.http_req_waiting.values['p(95)'],
      avg: m.http_req_waiting.values.avg,
      max: m.http_req_waiting.values.max,
    },
    error_rate: m.http_req_failed.values.rate,
    requests: m.http_reqs.values.count,
  };
  return { stdout: JSON.stringify(out) + '\n' };
}
