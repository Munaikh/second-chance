import test from 'node:test';
import assert from 'node:assert/strict';

process.env.N8N_BASE_URL = 'http://127.0.0.1:9';
const { createServer } = await import('../api.mjs');
const request = {
  profile: { name: 'Maya', openingBalancePence: 42000, monthlyIncomePence: 175000, monthlyEssentialsPence: 148500, debtBalancePence: 65000 },
  forecast: { shortfallPence: 18000, shortfallDate: '2026-11-12' }, hardship: 'income_drop',
};

test('unavailable n8n returns a retryable error without a fabricated plan', async (t) => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const response = await fetch(`${base}/api/recovery`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(request) });
  const failure = await response.json();
  assert.equal(response.status, 503);
  assert.equal(failure.retryable, true);
  assert.equal(failure.draft, undefined);
  assert.match(failure.error, /try again/);
});

test('HTTP boundary rejects malformed JSON, money, content type and remote origins', async (t) => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/api/recovery`;
  assert.equal((await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{' })).status, 400);
  assert.equal((await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ...request, forecast: { shortfallPence: 1.1 } }) })).status, 400);
  assert.equal((await fetch(url, { method: 'POST', body: JSON.stringify(request) })).status, 415);
  assert.equal((await fetch(url, { method: 'POST', headers: { Origin: 'https://example.com', 'Content-Type': 'application/json' }, body: JSON.stringify(request) })).status, 403);
});
