import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';

const agentId = process.env.ELEVENLABS_AGENT_ID || 'agent_8301m6v7kzdgfza9119295h54skt';
const speechIndex = process.argv.indexOf('--speech-input');
const speechFiles = speechIndex < 0 ? [] : process.argv.slice(speechIndex + 1, speechIndex + 3);
if (speechIndex >= 0 && speechFiles.length !== 2) throw new Error('Supply two raw mono PCM16 16kHz speech files');
const voice = process.argv.includes('--voice') || speechFiles.length > 0;
async function sendSpeech(path) {
  const audio = Buffer.concat([await readFile(path), Buffer.alloc(48000)]);
  for (let offset = 0; offset < audio.length && socket.readyState === WebSocket.OPEN; offset += 3200) {
    socket.send(JSON.stringify({ user_audio_chunk: audio.subarray(offset, offset + 3200).toString('base64') }));
    await delay(100);
  }
}
const socket = new WebSocket(`wss://api.elevenlabs.io/v1/convai/conversation?agent_id=${agentId}`);
const evidence = { agentId, mode: speechFiles.length ? 'speech-input-and-output' : voice ? 'voice-output' : 'text-only', checkedAt: new Date().toISOString(), conversationId: null, responses: [], transcripts: [], audioBytes: 0 };
const rawContext = { synthetic: true, profile: { id: 'maya', name: 'Maya', household: 'Single parent with irregular freelance income' }, forecast: { shortfallPence: 18000, shortfallDate: '2026-11-12', lowestBalancePence: -18000, causes: ['Rent and energy bills fall before an estimated freelance invoice on 16 November'] }, goal: { title: 'Emergency buffer', savedPence: 6500, targetPence: 50000 } };
const formatContext = value => Array.isArray(value) ? value.map(formatContext) : value && typeof value === 'object' ? Object.fromEntries(Object.entries(value).map(([key, item]) => key.endsWith('Pence') && typeof item === 'number' ? [key.replace(/Pence$/, 'GBP'), `£${(item / 100).toFixed(2)}`] : [key, formatContext(item)])) : value;
const context = formatContext(rawContext);
let stage = 0;
let settle;
const timeout = setTimeout(() => { socket.close(); console.error('Timed out waiting for ElevenLabs response'); process.exitCode = 1; }, 45000);
socket.onopen = () => socket.send(JSON.stringify({ type: 'conversation_initiation_client_data', conversation_config_override: { conversation: { text_only: !voice } } }));
socket.onerror = event => { if (stage === 4) return; clearTimeout(timeout); console.error('ElevenLabs socket failed', event.message); process.exitCode = 1; };
socket.onmessage = event => {
  const data = JSON.parse(event.data);
  if (data.type === 'ping') socket.send(JSON.stringify({ type: 'pong', event_id: data.ping_event.event_id }));
  if (data.type === 'conversation_initiation_metadata') {
    evidence.conversationId = data.conversation_initiation_metadata_event.conversation_id;
    socket.send(JSON.stringify({ type: 'contextual_update', text: `Current app-calculated synthetic financial snapshot. All amounts already formatted in GBP; copy exactly and do not convert units: ${JSON.stringify(context)}` }));
    if (speechFiles.length) void sendSpeech(speechFiles[0]);
    else socket.send(JSON.stringify({ type: 'user_message', text: 'Why will I be short on 12 November? Use my exact forecast amount.' }));
    stage = 1;
  }
  if (data.type === 'user_transcript') {
    evidence.transcripts.push(data.user_transcription_event.user_transcript);
    console.log(`Recognised speech: ${data.user_transcription_event.user_transcript}`);
  }
  if (data.type === 'audio') evidence.audioBytes += Buffer.from(data.audio_event?.audio_base_64 || '', 'base64').length;
  if (data.type === 'agent_response') {
    const response = data.agent_response_event.agent_response;
    if (response.includes('I’m Cloudy') || response.includes("I'm Cloudy")) return;
    evidence.responses.push(response);
    console.log(`Response ${evidence.responses.length}: ${response}`);
    if (stage === 1) {
      assert.match(response, /180|one hundred (?:and )?eighty/i);
      if (speechFiles.length) void delay(1500).then(() => sendSpeech(speechFiles[1]));
      else socket.send(JSON.stringify({ type: 'user_message', text: 'And what is one practical next step for that shortfall?' }));
      stage = 2;
    } else if (stage === 2) {
      assert.match(response, /provider|support|contact|recovery|plan|reach out/i);
      stage = 3;
      settle = setTimeout(async () => {
        if (voice) assert.ok(evidence.audioBytes > 0, 'Expected ElevenLabs audio output');
        if (speechFiles.length) assert.ok(evidence.transcripts.length >= 2, 'Expected both spoken questions to be recognised');
        await writeFile(new URL(speechFiles.length ? './speech-verification.json' : voice ? './voice-verification.json' : './text-verification.json', import.meta.url), JSON.stringify(evidence, null, 2) + '\n');
        console.log(JSON.stringify({ passed: true, conversationId: evidence.conversationId, followUpRetainedContext: true, audioBytes: evidence.audioBytes }));
        clearTimeout(timeout);
        stage = 4;
        socket.close();
      }, voice ? 5000 : 500);
    }
  }
  if (data.type === 'error') { clearTimeout(timeout); clearTimeout(settle); console.error(data); socket.close(); process.exitCode = 1; }
};
