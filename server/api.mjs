import http from 'node:http';

const n8nBase = process.env.N8N_BASE_URL || 'http://127.0.0.1:5678';
const port = Number(process.env.API_PORT || 8787);
const allowedOrigin = (origin) => !origin || /^http:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$/.test(origin);

export function validateRecoveryRequest(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'Send a JSON request object.';
  if (!['income_drop', 'unexpected_bill', 'complaint'].includes(body.hardship)) return 'Choose a recognised hardship scenario.';
  const { profile, forecast } = body;
  if (!profile || !forecast) return 'A profile and forecast are required.';
  if (typeof profile.name !== 'string' || !profile.name.trim() || profile.name.length > 100) return 'A customer name of up to 100 characters is required.';
  for (const key of ['openingBalancePence', 'monthlyIncomePence', 'monthlyEssentialsPence', 'debtBalancePence']) {
    if (!Number.isSafeInteger(profile[key]) || Math.abs(profile[key]) > 100000000 || (key !== 'openingBalancePence' && profile[key] < 0)) return `profile.${key} must be integer pence within the demo range.`;
  }
  if (!Number.isSafeInteger(forecast.shortfallPence) || forecast.shortfallPence < 0 || forecast.shortfallPence > 100000000) return 'forecast.shortfallPence must be non-negative integer pence.';
  if (forecast.shortfallPence > 0) {
    const date = forecast.shortfallDate;
    if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}(T.*)?$/.test(date) || Number.isNaN(Date.parse(date)) || new Date(date).toISOString().slice(0, 10) !== date.slice(0, 10)) return 'A valid forecast.shortfallDate is required for a shortfall.';
  }
  if (body.note !== undefined && (typeof body.note !== 'string' || body.note.length > 1000)) return 'Keep the extra note within 1,000 characters.';
  return null;
}

export function createServer() {
  return http.createServer(async (req, res) => {
    const headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      Vary: 'Origin',
    };
    const send = (status, value) => {
      if (!res.writableEnded) res.writeHead(status, headers).end(JSON.stringify(value));
    };
    if (!allowedOrigin(req.headers.origin)) return send(403, { error: 'This local demo only accepts local development origins.' });
    if (req.headers.origin) headers['Access-Control-Allow-Origin'] = req.headers.origin;
    if (req.method === 'OPTIONS') return send(200, {});
    if (req.method === 'GET' && req.url === '/health') {
      try {
        const upstream = await fetch(`${n8nBase}/healthz`, { signal: AbortSignal.timeout(3000) });
        return send(upstream.ok ? 200 : 503, { service: 'second-chance-api', n8n: upstream.ok ? 'reachable' : 'unavailable', recoveryMode: 'live_n8n' });
      } catch {
        return send(503, { service: 'second-chance-api', n8n: 'unavailable', error: 'Start the local n8n workflow, then try again.' });
      }
    }
    if (req.method !== 'POST' || req.url !== '/api/recovery') return send(404, { error: 'This route was not found.' });
    if (!(req.headers['content-type'] || '').startsWith('application/json')) return send(415, { error: 'Use Content-Type: application/json.' });
    let body;
    try {
      const chunks = [];
      let bytes = 0;
      for await (const chunk of req) {
        bytes += chunk.length;
        if (bytes > 65536) return send(413, { error: 'The request is too large. Send only the selected demo profile and forecast.' });
        chunks.push(chunk);
      }
      body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    } catch {
      return send(400, { error: 'The request could not be read. Please try again.' });
    }
    const validation = validateRecoveryRequest(body);
    if (validation) return send(400, { error: validation });
    try {
      const upstream = await fetch(`${n8nBase}/webhook/second-chance-recovery`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body), signal: AbortSignal.timeout(25000),
      });
      if (!upstream.ok) return send(503, { error: 'The recovery workflow is unavailable. Your information is preserved; try again once n8n is running.', retryable: true });
      const result = await upstream.json();
      if (result.mode !== 'live_n8n' || result.workflow?.engine !== 'n8n' || !result.workflow?.executionId || !result.draft?.body || !Array.isArray(result.steps)) {
        return send(502, { error: 'The workflow returned an incomplete plan. Please try again.', retryable: true });
      }
      return send(200, result);
    } catch {
      return send(503, { error: 'We could not reach the recovery workflow. Check the local services and try again.', retryable: true });
    }
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const server = createServer();
  server.listen(port, '127.0.0.1', () => console.log(`Second Chance API ready at http://127.0.0.1:${port}`));
  process.on('SIGTERM', () => server.close());
  process.on('SIGINT', () => server.close());
}
