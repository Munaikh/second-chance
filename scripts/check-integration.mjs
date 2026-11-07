import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

const body = {
  profile: { id: 'maya', name: 'Maya Patel', household: 'Single parent, one child', openingBalancePence: 42000, monthlyIncomePence: 175000, monthlyEssentialsPence: 148500, debtBalancePence: 65000 },
  forecast: { shortfallPence: 18000, shortfallDate: '2026-11-12', lowestBalancePence: -18000, causes: ['Rent before the next income payment'] },
  hardship: 'income_drop',
};
const response = await fetch('http://127.0.0.1:8787/api/recovery', {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: AbortSignal.timeout(30000),
});
const plan = await response.json();
assert.equal(response.status, 200, JSON.stringify(plan));
assert.equal(plan.mode, 'live_n8n');
assert.equal(plan.workflow.engine, 'n8n');
assert.ok(plan.workflow.executionId);
assert.match(plan.draft.body, /Maya Patel/);
assert.match(plan.draft.body, /£180\.00/);
assert.match(plan.draft.body, /expected income over the next 30 days/);
assert.match(plan.draft.body, /planned essential costs over the next 30 days/);
assert.doesNotMatch(JSON.stringify(plan), /monthly/i);
const evidence = {
  verifiedAt: new Date().toISOString(), method: 'POST /api/recovery -> n8n webhook -> Code -> Respond to Webhook',
  workflow: plan.workflow, personalisedName: 'Maya Patel', forecastGapPence: 18000,
  sourceCount: plan.sources.length, draftCharacters: plan.draft.body.length,
};
await writeFile(new URL('../docs/integration-evidence.json', import.meta.url), `${JSON.stringify(evidence, null, 2)}\n`);
console.log(JSON.stringify(evidence, null, 2));
