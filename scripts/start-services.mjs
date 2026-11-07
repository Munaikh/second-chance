import { mkdir } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const cli = `${root}server/node_modules/n8n/bin/n8n`;
const runtime = `${root}.runtime/n8n`;
await mkdir(runtime, { recursive: true });
const env = {
  ...process.env,
  N8N_USER_FOLDER: runtime,
  N8N_HOST: '127.0.0.1', N8N_LISTEN_ADDRESS: '127.0.0.1', N8N_PORT: '5678',
  N8N_PROTOCOL: 'http', N8N_SECURE_COOKIE: 'false',
  N8N_DIAGNOSTICS_ENABLED: 'false', N8N_VERSION_NOTIFICATIONS_ENABLED: 'false',
  N8N_TEMPLATES_ENABLED: 'false', N8N_PERSONALIZATION_ENABLED: 'false',
  N8N_PYTHON_ENABLED: 'false',
  N8N_RUNNERS_BROKER_PORT: '5680', GENERIC_TIMEZONE: 'Europe/London',
};
function command(args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, args, { cwd: root, env, stdio: 'inherit', ...options });
    child.on('error', reject);
    child.on('exit', (code) => code === 0 ? resolve() : reject(new Error(`Command failed (${code}): ${args.join(' ')}`)));
  });
}
await command([`${root}scripts/build-workflow.mjs`]);
await command([cli, 'import:workflow', `--input=${root}workflows/second-chance-recovery.json`]);
await command([cli, 'publish:workflow', '--id=secondChanceRecovery']);
const n8n = spawn(process.execPath, [cli, 'start'], { cwd: root, env, stdio: 'inherit' });
const api = spawn(process.execPath, [`${root}server/api.mjs`], { cwd: root, env, stdio: 'inherit' });
const shutdown = () => { n8n.kill('SIGTERM'); api.kill('SIGTERM'); };
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
n8n.on('exit', (code) => { api.kill('SIGTERM'); process.exitCode = code || 0; });
api.on('exit', (code) => { n8n.kill('SIGTERM'); process.exitCode = code || 0; });
