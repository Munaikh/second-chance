import { readFile, writeFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const code = await readFile(new URL('workflows/recovery-code.js', root), 'utf8');
const workflow = {
  id: 'secondChanceRecovery',
  name: 'Second Chance · Personal recovery plan',
  active: false,
  nodes: [
    {
      id: 'recovery-webhook', name: 'Recovery request', type: 'n8n-nodes-base.webhook', typeVersion: 2,
      position: [240, 300], webhookId: 'second-chance-recovery',
      parameters: { httpMethod: 'POST', path: 'second-chance-recovery', responseMode: 'responseNode', options: {} },
    },
    {
      id: 'personalise-plan', name: 'Personalise sourced recovery plan', type: 'n8n-nodes-base.code', typeVersion: 2,
      position: [520, 300], parameters: { mode: 'runOnceForAllItems', jsCode: code },
    },
    {
      id: 'return-plan', name: 'Return plan and editable draft', type: 'n8n-nodes-base.respondToWebhook', typeVersion: 1.4,
      position: [800, 300], parameters: { respondWith: 'json', responseBody: '={{ $json }}', options: { responseCode: 200 } },
    },
  ],
  connections: {
    'Recovery request': { main: [[{ node: 'Personalise sourced recovery plan', type: 'main', index: 0 }]] },
    'Personalise sourced recovery plan': { main: [[{ node: 'Return plan and editable draft', type: 'main', index: 0 }]] },
  },
  settings: { executionOrder: 'v1', saveDataSuccessExecution: 'all', saveDataErrorExecution: 'all' },
};
await writeFile(new URL('workflows/second-chance-recovery.json', root), `${JSON.stringify(workflow, null, 2)}\n`);
console.log('Built workflows/second-chance-recovery.json');
