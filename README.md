# Second Chance

A kinder path through financial setbacks. A Flutter prototype for the NatWest hackathon: **Prepare → Support → Grow**.

Explore a dated cash-flow risk, talk with Pip, compare a scenario, create a support plan and build an emergency buffer. All customer records are synthetic; all amounts are GBP.

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

The first build fetches Swift packages for voice. The project uses Swift Package Manager. The starter’s iOS 15 target is retained; iOS 26+ uses a native system tab bar, with product-styled navigation on other platforms. The primary demo target is iPhone 18 Pro Simulator, iOS 27.2.

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
Flutter: Prepare / Support / Grow + Pip
  ├─ integer-pence forecasts + two reproducible UK profiles
  ├─ on-device goals, actions and editable drafts
  ├─ ElevenLabs: contextual text WebSocket / voice WebRTC
  └─ local HTTP bridge :8787 → n8n :5678
       └─ validate → personalise plan and draft → return sources
```

`lib/core` owns calculations, integration clients and state. `lib/ui` owns theme tokens and task screens. No database or Supabase instance is needed for this local journey. A hosted service with authentication and optional Supabase persistence is future work.

## Live, calculated and simulated

| Capability | Implementation |
| --- | --- |
| Accounts, history and household circumstances | Synthetic fixtures; no Open Banking connection |
| Forecasts and comparisons | Deterministic daily closing balances, integer pence |
| Pip text and voice | Live ElevenLabs using calculated context |
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
