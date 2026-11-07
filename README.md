# Raise

A kinder path through financial setbacks. A voice and chat first Flutter companion for the NatWest hackathon: **Prepare → Support → Grow**.

Cloudy, an animated cloud, lives on Home and peeks over a draggable financial sheet. Controlled Lottie segments give Cloudy a gentle idle blink, attentive listening and expressive speaking; reduced motion freezes the character. Talk by tapping Cloudy or the microphone, or type into the persistent composer. A Motor spring moves the sheet away and carries Cloudy into the conversation header. Drag the sheet up for forecast, support and savings; every destination is available there. All customer records are synthetic; all amounts are GBP.

Voice mode gives Cloudy the upper two-thirds of the screen, with Mute, End, Chat and a scrolling transcript below. Chat switches presentation while preserving the session and draft. The financial sheet puts four labelled tasks first: Forecast, Expected vs actual, Get support and Savings goal; large text uses a single column.

Cloudy can carry out requests through four client tools: model a what-if, prepare a real n8n support plan and editable draft, create a savings goal, and compare historical balances. Results appear inside the conversation. Existing goals and drafts require confirmation before replacement; recorded savings are preserved. These actions do not transfer money or send requests externally.

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

The first build fetches Swift packages for voice. The project uses Swift Package Manager and retains the starter’s iOS 15 target. The primary demo target is iPhone 18 Pro Simulator, iOS 27.2. The main navigation is a mascot-centred Home with an expandable sheet.

The dedicated public ElevenLabs demo agent works by default. No API key is bundled. It accepts fictional demo context only. To override it:

```sh
flutter run --dart-define=ELEVENLABS_AGENT_ID=your_public_demo_agent_id
```

iOS Simulator uses `http://127.0.0.1:8787`; Android Emulator uses `http://10.0.2.2:8787` in debug. A physical phone needs a separately configured reachable backend. `--dart-define=API_BASE_URL=https://your-host` overrides the endpoint. Cloud deployment is a follow-on milestone.

For a phone connected through Tailscale, start local services and run `tailscale serve --bg http://127.0.0.1:8787` on the Mac. Follow its activation link if Serve is disabled. Build the app with `flutter run -d <phone-id> --dart-define=API_BASE_URL=https://<your-mac>.<your-tailnet>.ts.net`, using the HTTPS URL printed by Serve. Check that URL with `/health` in phone Safari first. Keep the Mac awake and the services running. Changing this build setting requires a full relaunch. Cloudy connects directly to ElevenLabs over the phone's internet connection.

## Demonstrate

Follow [the three-minute journey and pitch](docs/DEMO.md). The avatar opens profile switching and **Reset all demo progress**.

- **Noor:** irregular earnings and household commitments; £180 short on 12 November, before the next earnings on 14 November.
- **Alex:** steady earnings and a positive forecast; guidance shifts towards building a stronger buffer and understanding credit.

Forecasts use a fixed **7 November 2026** clock. Savings records use the date recorded. Goals, positive actions, plans and edited drafts survive restarting, separately for each profile. Exploratory scenarios reset on profile change or restart.

Time travel includes **Look ahead** and **Expected vs actual**. The historical comparison reconstructs a simple estimate for 10 October–6 November from the preceding four demo weeks, then compares it with synthetic recorded balances. It is not an archived forecast or evidence of prediction accuracy. Curves join daily closing values without overshooting; date selection shows both exact balances and their difference.

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
flutter test test/live/companion_actions_live_test.dart --dart-define=RUN_LIVE_AGENT_TESTS=true --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

See [voice setup](docs/VOICE.md), [n8n setup](docs/INTEGRATIONS.md) and [validation limits](docs/VALIDATION.md). Text chat needs no microphone permission. Phone voice and forecast/recovery actions are user-confirmed on mobile data with Tailscale. Production authentication, cloud hosting and broader device acceptance remain follow-on work.
