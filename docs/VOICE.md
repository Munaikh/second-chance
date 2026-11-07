# Cloudy: live ElevenLabs companion

The Flutter app connects to a dedicated public **synthetic-data demonstration** agent:

- Agent: `agent_8301m6v7kzdgfza9119295h54skt`
- Name: Cloudy
- Model: Gemini 2.5 Flash; voice: Charlotte (`XB0fDUnXU5powFXDhCwa`).
- Created for this prototype on 7 November 2026; maximum two concurrent calls and 100 sessions/day.
- Voice recording disabled, transcript/audio deletion enabled, retention set to one day. This is not certified zero-retention mode. Use synthetic data only.

No API key is bundled or required on the device. Override the public agent with `--dart-define=ELEVENLABS_AGENT_ID=your-public-agent-id`. For real customers, replace public access with authenticated server-issued conversation tokens and apply the required consent, retention and access controls.

`CompanionController` uses the official `elevenlabs_agents` Flutter SDK for WebRTC two-way voice, transcript events, speaking/listening state and microphone mute. Microphone permission is requested only when the user starts voice. On iOS, `NSMicrophoneUsageDescription` must be present; Android needs `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` and `INTERNET`. A physical microphone and reachable ElevenLabs/LiveKit services are needed. If permission is refused, the user can continue by text.

Text uses ElevenLabs' documented WebSocket protocol with a text-only session override. It never opens a microphone. This is deliberate: Flutter SDK 0.6.1 enables microphone capture even when its text-only conversation override is true. The dedicated agent allows only the text-only override, not client replacement of its system prompt.

The app sends the active profile, dated calculated forecast, scenario and goal as contextual updates. It converts every integer-pence field into an exact formatted GBP string before sending model context, so the language model does not perform currency-unit arithmetic. It supplies the last twelve visible live conversation messages when moving between text and voice sessions. Changing the selected demo profile ends the connection and clears the transcript. The agent cannot change finances or submit drafts; n8n recovery is a separate explicit app action.

“Stop voice playback” ends the voice session immediately, which stops microphone capture and output. The official SDK does not expose an independent output-pause API. Starting voice again retains the visible conversation through a contextual update. Mute controls input; it does not pause Cloudy's output.

When ElevenLabs is unreachable, a text reply can use deterministic guidance based on the supplied financial snapshot. These replies carry `isFallback: true` and the mode becomes **Calculated demo guidance**. A visible connection error explains how to reconnect. This mode is not live AI or ElevenLabs audio.

## Verification

The iPhone 18 Pro Simulator (iOS 27.2) also connected through the Flutter WebRTC client on 7 November 2026. Microphone permission, listening/speaking state, mute, two contextual replies and Stop voice were exercised. Questions were typed into the live voice session while the microphone was muted. Actual spoken input is covered separately by the synthetic ASR test below; physical microphone quality and audible hardware playback are untested. Permission is obtained before the connection timeout starts, and temporary permission prompts do not end the session.

The standalone service scripts use a deliberately small synthetic fixture, separate from the app’s two full financial histories. Their invoice on 16 November is not Noor’s app fixture, whose next delivery payment after the shortfall is 14 November. The simulator check used the app’s actual calculated snapshot and correctly explained the 14 November timing.

Run from the project directory with Node 22 or newer and internet access:

```sh
node integrations/elevenlabs/verify.mjs
node integrations/elevenlabs/verify.mjs --voice
flutter test test/companion_test.dart
```

The network checks send only a short synthetic profile. They assert that the first answer explains the £180 gap, a follow-up gives a relevant step, and voice mode receives non-empty ElevenLabs audio. Results are saved next to the script in `text-verification.json` and `voice-verification.json` with conversation IDs, timestamps and response text. They prove service response and speech generation, not microphone capture or audible device playback. Device acceptance must cover permission refusal, a spoken question and follow-up, mute, stop, an interrupted connection and persona switching.

References: [official Flutter SDK](https://github.com/elevenlabs/elevenlabs-flutter), [official WebSocket documentation](https://elevenlabs.io/docs/eleven-agents/libraries/web-sockets), [SDK package 0.6.1](https://pub.dev/packages/elevenlabs_agents/versions/0.6.1).

An additional speech-input check recognises two synthetic spoken questions and verifies contextual speech output. It does not access the user's microphone. For example, on macOS:

```sh
say -v Daniel -r 155 -o /tmp/sc-question.aiff 'Why will I be short on the twelfth of November?'
say -v Daniel -r 155 -o /tmp/sc-followup.aiff 'And what is one practical next step for that shortfall?'
afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/sc-question.aiff /tmp/sc-question.wav
afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/sc-followup.aiff /tmp/sc-followup.wav
python3 - <<'PY'
import wave
for name in ('question', 'followup'):
    with wave.open(f'/tmp/sc-{name}.wav', 'rb') as audio:
        with open(f'/tmp/sc-{name}.pcm', 'wb') as target:
            target.write(audio.readframes(audio.getnframes()))
PY
node integrations/elevenlabs/verify.mjs --speech-input /tmp/sc-question.pcm /tmp/sc-followup.pcm
```

The result is saved to `speech-verification.json`. On 7 November 2026, the service recognised both spoken questions, correctly explained the £180 gap on 12 November and returned a contextual recovery-plan follow-up with 967,680 bytes of generated audio (`conv_5701m6v830chfk1tptwtta19z273`). This verifies ASR → conversation → TTS at the service boundary. Mobile WebRTC microphone capture, speaker routing and audible playback remain separate device checks.

On 7 November 2026, the existing agent was renamed **Cloudy** for **Raise**. A read-back verified the new display name and prompt identity, with model, voice, financial instructions, privacy and call limits preserved. A live text-only turn confirmed “I'm Cloudy, and I'm part of Raise”; the result is recorded in `integrations/elevenlabs/identity-verification.json`. The first message remains empty so the app can provide financial context before the first reply. Existing text, voice and speech verification JSON files record earlier runs under the historical Pip name; they have been retained unchanged.
