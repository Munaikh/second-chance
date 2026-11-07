# Validation

Checks completed on 7 November 2026 using Flutter 3.47.9, Dart 3.13.7 and Xcode 27.2. Mobile runtime: iPhone 18 Pro Simulator, iOS 27.2.

## Mascot-first redesign

The original prototype was committed and pushed as `8f92fc0` before the redesign. The app is now Raise, with Cloudy, an original animated cloud, above a draggable financial sheet with a pinned expand/collapse control, a permanent voice/text composer and inline conversations. Forecast, recovery and progress screens remain reachable through the sheet and menu. Existing device progress is preserved; internal package and storage identifiers are retained.

The supplied assistant screenshots were the primary layout reference: spacious sky background, a character behind a light sheet, a dark input bar and a compact character header during conversation. Artwork and controls are original project assets; see [Cloudy animation provenance and controls](cloud-mascot.md). Lottie playback is controlled by conversation state and respects reduced motion.

Five additional home regressions cover initial mascot/composer access, sheet expansion and scrolling, calculated chat and returning to Home, keyboard/2× text layout, and profile isolation. Earlier forecast, goal, draft and persistence journeys were adapted to menu navigation. Live simulator checks verified sheet expansion, internal scrolling, collapse and a contextual ElevenLabs text reply.

The final Raise build has **42 passing Flutter tests**, including parsing the real Cloudy asset, switching all three playback ranges and freezing under reduced motion. Source analysis is clean. The final iOS Simulator build and launch succeeded, and the reference-matching cloud, glasses and face were visually inspected above the sheet.

Voice testing encountered a native iOS Simulator abort: Apple `AudioUnitInitialize` timed out while LiveKit/WebRTC initialized audio capture or playback. The same native boundary appears in crashes before the visual redesign. Live ElevenLabs text works, including the verified Cloudy/Raise identity. Current simulator audio stability is unresolved; no physical-device audio acceptance is claimed.

## Original prototype verification

These checks describe the baseline implementation and its original navigation. The later redesign uses a menu rather than tabs.

- `flutter analyze`: no issues. `flutter test`: **36 passing tests**. Backend: **6 passing Node tests**.
- Native iOS build and launch succeeded with Swift Package Manager.
- Noor’s forecast showed £180 short on 12 November. Changing flexible spending by £25 per week produced £155 on the same date; live Pip text explained both values and retained a follow-up.
- The mobile ElevenLabs voice session connected, displayed listening/speaking states, returned two contextual responses and supported microphone mute and stopping voice. Input for this mobile check was typed; the separate synthetic speech check verifies the spoken-input service path.
- The app itself executed n8n and displayed Noor’s personalised £180 recovery plan. The subject and body were edited, autosaved and copied; the simulator clipboard contained the edited text and original calculated gap. Primary guidance sources were visible in the plan.
- A £500 goal started with Noor’s existing £35, then recording £5 showed £40 and a three-action “Stronger foundations” achievement. Both remained after a full OS-level terminate and relaunch of the final rebuilt app. Alex’s separate profile displayed £1,850 and no forecast shortfall, with a £418 low on 21 November.
- Real native tab touches selected Prepare, Support and Grow, with matching Flutter content. See [native automation details](NATIVE_VALIDATION.md); a successful accessibility activation alone was insufficient evidence.
- The final app’s reset flow cleared saved goals, plans, edited drafts and positive actions and restored Noor’s baseline. The simulator was left on Prepare for a fresh demonstration; local recovery services remained healthy.
- Light and dark simulator compositions were inspected, including native chrome, the forecast, voice controls and draft editor. Widget tests cover Prepare, Forecast, Support, funded Grow and the long draft at 390px width and 2× text. The Copy action stays fixed and reachable while editing.
- Body, secondary text and primary-button palette pairs measured 5.73–15.89:1 in light mode and 8.63–14.57:1 in dark mode. These measurements cover those specific pairs, not every composited native material.

## Design basis

Appllama research inspected the complete Buddy Overview flow (`936422955`: `oth_0cq5e`, `oth_rb8tn`, `oth_kbpv2`, `oth_0a8iv`) and Fleur Home Dashboard flow (`1621020173`: `oth_38sll`, `oth_deeok`). Adopted the clear summary-to-detail hierarchy and dated money overview; adapted them into neutral surfaces, a single upcoming pressure and three customer-led destinations. The original Pip illustration, voice-state feedback and goal-progress motion are product-specific. Still-image research does not establish competitor motion behavior.

- Financial tests reconcile every daily closing balance and both eight-week histories, check scenario bounds, preserve benefits when changing earnings and cap spending reductions.
- Persistence tests cover fresh-state restoration, profile separation, edited drafts, reset, recovery retries and malformed stored data.
- Live ElevenLabs checks cover two text turns and two synthetic spoken turns through ASR → contextual reply → audio. Evidence: `integrations/elevenlabs/`.
- The actual local n8n webhook returned a personalised plan and sources. `integration-evidence.json` verifies transport and personalisation independently from the Dart fixtures.

These service checks do not establish physical-device microphone quality, audible playback routing, accessibility traversal or wellbeing outcomes. Customer data is synthetic; forecasts are calculated; guidance is curated. The app does not connect a bank, submit requests, grant support or move money.

Android and older iOS implementations are not physical-device acceptance evidence. Cloud hosting, production authentication and device acceptance remain follow-on work. Live service availability and quota can change after verification.
