# Raise

A kinder path through financial setbacks. A voice and chat first Flutter companion for the NatWest hackathon: **Prepare → Support → Grow**.

Cloudy, an animated cloud, lives on Home and peeks over a draggable financial sheet. Controlled Lottie segments give Cloudy a gentle idle blink, attentive listening and expressive speaking; reduced motion freezes the character. Talk by tapping Cloudy or the microphone, or type into the persistent composer. Drag the sheet up to explore your forecast, support plan and savings; use the menu for direct navigation. All customer records are synthetic; all amounts are GBP.

## Run

Checked toolchain: Flutter 3.47.9 / Dart 3.13.7, Node 26, Xcode 27.2. Use Node 24+ and a booted iOS Simulator.

```sh
flutter pub get
sh scripts/setup-services.sh
node scripts/start-services.mjs
```

Keep services running. In a second terminal:

```sh
flutter run -d <your-ios-simulator-id>
```

The first build fetches Swift packages for voice. The project uses Swift Package Manager and retains the starter’s iOS 15 target. The primary demo target is iPhone 18 Pro Simulator, iOS 27.2. The main navigation is a mascot-centred Home with an expandable sheet and menu.

The dedicated public ElevenLabs demo agent works by default. No API key is bundled. It accepts fictional demo context only. To override it:

```sh
flutter run --dart-define=ELEVENLABS_AGENT_ID=your_public_demo_agent_id
```

iOS Simulator uses `http://127.0.0.1:8787`; Android Emulator uses `http://10.0.2.2:8787` in debug. A physical phone needs a separately configured reachable backend. `--dart-define=API_BASE_URL=https://your-host` overrides the endpoint. Cloud deployment is a follow-on milestone.

## Demonstrate

Follow [the three-minute journey and pitch](docs/DEMO.md). The avatar opens profile switching and **Reset all demo progress**.

- **Noor:** irregular earnings and household commitments; £180 short on 12 November, before the next earnings on 14 November.
- **Alex:** steady earnings and a positive forecast; guidance shifts towards building a stronger buffer and understanding credit.

Forecasts use a fixed **7 November 2026** clock. Savings records use the date recorded. Goals, positive actions, plans and edited drafts survive restarting, separately for each profile. Exploratory scenarios reset on profile change or restart.

## Architecture

```text
Flutter: Cloudy Home + financial sheet + inline conversation
  ├─ integer-pence forecasts + two reproducible UK profiles
  ├─ on-device goals, actions and editable drafts
  ├─ ElevenLabs: contextual text WebSocket / voice WebRTC
  └─ local HTTP bridge :8787 → n8n :5678
       └─ validate → personalise plan and draft → return sources
```

`lib/core` owns calculations, integration clients and state. `lib/ui/home.dart` coordinates the sheet and conversation; `assistant_widgets.dart` owns the mascot, composer and message styling. Other task screens share the theme. No database or Supabase instance is needed for this local journey. A hosted service with authentication and optional Supabase persistence is future work.

## Live, calculated and simulated

| Capability | Implementation |
| --- | --- |
| Accounts, history and household circumstances | Synthetic fixtures; no Open Banking connection |
| Forecasts and comparisons | Deterministic daily closing balances, integer pence |
| Cloudy text and voice | Live ElevenLabs using calculated context |
| Connection failure guidance | Explicitly labelled calculated demo guidance |
| Plan and editable request | Genuine local n8n execution; deterministic personalisation |
| Guidance | Curated primary-source summaries and visible links; no vector RAG claim |
| Savings and achievements | Persistent personal records; no transfer or spending reward |
| Support request submission | User reviews and copies; nothing is sent |

Forecasts assume the listed dates and amounts. They do not model intraday payment order, overdrafts or interest. First-negative and lowest balances are shown separately. General guidance does not decide eligibility or credit outcomes.

## Verify

```sh
flutter analyze
flutter test
node --test server/test/*.test.mjs
node scripts/check-integration.mjs
node integrations/elevenlabs/verify.mjs
```

See [voice setup](docs/VOICE.md), [n8n setup](docs/INTEGRATIONS.md) and [validation limits](docs/VALIDATION.md). Text chat needs no microphone permission. Production authentication, cloud hosting and physical-device acceptance remain follow-on work.
