import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';
import { validateRecoveryRequest } from '../api.mjs';

const code = await readFile(new URL('../../workflows/recovery-code.js', import.meta.url), 'utf8');
const request = {
  profile: { id: 'maya', name: 'Maya Patel', openingBalancePence: 42000, monthlyIncomePence: 175000, monthlyEssentialsPence: 148500, debtBalancePence: 65000 },
  forecast: { shortfallPence: 18000, shortfallDate: '2026-11-12', lowestBalancePence: -18000, causes: ['Rent arrives before the next income payment'] },
  hardship: 'income_drop',
};
const run = (input) => vm.runInNewContext(`(function() { ${code} })()`, { $input: { first: () => ({ json: { body: input } }) }, $execution: { id: 'test-execution-42' } })[0].json;

test('n8n draft uses the selected customer, GBP figures, pressure date and sources', () => {
  const result = run(request);
  assert.equal(result.mode, 'live_n8n');
  assert.equal(result.workflow.executionId, 'test-execution-42');
  assert.equal(result.workflow.engine, 'n8n');
  assert.match(result.draft.body, /Maya Patel/);
  assert.match(result.draft.body, /£180\.00/);
  assert.match(result.draft.body, /12 November 2026/);
  assert.match(result.draft.body, /£1,750\.00/);
  assert.match(result.draft.body, /expected income over the next 30 days/);
  assert.match(result.steps[0].detail, /essential costs over the next 30 days/);
  assert.match(result.knownFacts.join(' '), /Expected income over the next 30 days/);
  assert.doesNotMatch(JSON.stringify(result), /monthly/i);
  assert.equal(result.steps.length, 4);
  assert.equal(result.sources.length, 3);
  assert.ok(result.sources.every((source) => source.url.startsWith('https://')));
  assert.ok(result.assumptions.some((item) => item.includes('not agreed')));
});

test('a different profile and complaint produce a distinct draft without inventing a shortfall', () => {
  const result = run({ ...request, profile: { ...request.profile, name: 'James Morgan', monthlyIncomePence: 280000 }, forecast: { shortfallPence: 0 }, hardship: 'complaint', note: 'A duplicate charge needs investigating.' });
  assert.match(result.draft.subject, /Complaint/);
  assert.match(result.draft.body, /James Morgan/);
  assert.match(result.draft.body, /£2,800\.00/);
  assert.match(result.draft.body, /A duplicate charge/);
  assert.match(result.draft.body, /expected income over the next 30 days/);
  assert.doesNotMatch(JSON.stringify(result), /monthly/i);
  assert.doesNotMatch(result.draft.body, /£180\.00/);
  assert.match(result.summary, /above zero/);
});

test('boundary validation rejects missing, fractional and invalid money and dates', () => {
  assert.equal(validateRecoveryRequest(request), null);
  assert.match(validateRecoveryRequest({ ...request, profile: { ...request.profile, openingBalancePence: 1.5 } }), /integer pence/);
  assert.match(validateRecoveryRequest({ ...request, forecast: { ...request.forecast, shortfallDate: 'tomorrow' } }), /valid/);
  assert.match(validateRecoveryRequest({ ...request, forecast: { ...request.forecast, shortfallDate: '2026-11-31' } }), /valid/);
  assert.match(validateRecoveryRequest({ ...request, profile: { ...request.profile, monthlyIncomePence: -1 } }), /integer pence/);
  assert.match(validateRecoveryRequest({ ...request, note: 'x'.repeat(1001) }), /1,000/);
  assert.throws(() => run({ ...request, forecast: { shortfallPence: -1 } }), /non-negative/);
});

test('exported workflow contains this exact source and a real webhook-to-response path', async () => {
  const workflow = JSON.parse(await readFile(new URL('../../workflows/second-chance-recovery.json', import.meta.url), 'utf8'));
  assert.equal(workflow.nodes.find((node) => node.type === 'n8n-nodes-base.code').parameters.jsCode, code);
  assert.equal(workflow.nodes[0].parameters.path, 'second-chance-recovery');
  assert.equal(workflow.nodes.at(-1).type, 'n8n-nodes-base.respondToWebhook');
});
