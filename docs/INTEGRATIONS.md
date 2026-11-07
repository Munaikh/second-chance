# Local recovery workflow

The recovery screen calls a real n8n workflow. A local Node API validates the selected synthetic profile and forecast, forwards them to an n8n webhook, and returns the personalised plan, editable draft and sources. The draft is never sent to a bank or provider.

```text
Flutter recovery screen
  POST http://127.0.0.1:8787/api/recovery
    → n8n POST /webhook/second-chance-recovery :5678
      → validate and personalise plan (Code node)
      → return JSON (Respond to Webhook node)
```

The workflow is deterministic personalisation with curated guidance; it does not claim LLM generation, vector retrieval or a live eligibility assessment. Its response contains the actual n8n execution ID and timestamp. Each request executes n8n. If n8n is unavailable, the app receives a retryable error rather than a fabricated plan.

## Run

Use Node 24 or later. The checked runtime is pinned to n8n `2.46.6` in `server/package-lock.json`; this npm package declares Node `>=24`.

From the repository root:

```sh
sh scripts/setup-services.sh
node scripts/start-services.mjs
```

The setup script installs the locked packages without unrelated connector install hooks, then builds the SQLite and isolated JavaScript bindings used by this demo. Other native n8n connectors, including Kafka, are outside this prototype and must be built before adding them. No cloud account or API key is required for recovery drafting.

The launcher regenerates the workflow from its source, imports and publishes it, then starts n8n and the API. Keep this process running during the demo. Press Ctrl-C to stop both services. Ports 5678, 5680 and 8787 must be available. Both HTTP services bind to `127.0.0.1`.

n8n can log a missing optional Python runner in this npm setup. This workflow uses the registered JavaScript runner; it does not need Python.

```sh
curl http://127.0.0.1:8787/health
node --test server/test/*.test.mjs
node scripts/check-integration.mjs
```

The integration check makes a genuine webhook request and writes a compact result to `docs/integration-evidence.json`. Its example request is synthetic and independent of the app’s seed profiles; the `£180` gap checks personalisation and transport rather than revalidating the Dart forecast.

On iOS Simulator and macOS, the app can reach the host at `127.0.0.1:8787`. Android Emulator uses `10.0.2.2:8787`. A physical phone requires an explicitly configured development connection to the host; this loopback-only setup does not expose a service to the LAN. Cloud deployment and production authentication are follow-on work.

n8n’s built-in SQLite data and generated local configuration live under `.runtime/n8n/`. They are development runtime files and must stay ignored. No Supabase account or app database is needed for this workflow. The Flutter app owns its local demo profile, draft and savings persistence. Restarting the launcher reloads the checked-in workflow; the app’s reset-demo action resets the customer journey. No external financial actions occur.

## Request and response

`POST /api/recovery` requires JSON:

```json
{
  "profile": {
    "id": "example",
    "name": "Maya Patel",
    "household": "Single parent, one child",
    "openingBalancePence": 42000,
    "monthlyIncomePence": 175000,
    "monthlyEssentialsPence": 148500,
    "debtBalancePence": 65000
  },
  "forecast": {
    "shortfallPence": 18000,
    "shortfallDate": "2026-11-12",
    "lowestBalancePence": -18000,
    "causes": ["Rent before the next income payment"]
  },
  "hardship": "income_drop",
  "note": "Optional customer context, at most 1,000 characters"
}
```

The selected hardship is `income_drop`, `unexpected_bill` or `complaint`. Monetary values use integer pence; the gap must be non-negative. A dated shortfall is required only when a gap exists. The API rejects malformed input, oversized requests and non-local browser origins. The workflow validates its input again because its webhook is a separate boundary.

The compatibility keys `monthlyIncomePence` and `monthlyEssentialsPence` carry expected income and planned essential costs over the next 30 days, not a calendar-month total. For the fixed demo, that horizon is 7 November–6 December 2026. The returned plan, facts and draft use the next-30-days wording.

The successful response contains:

```text
mode: live_n8n
workflow: { name, executionId, executedAt, engine: n8n }
title, summary
steps: [{ id, title, detail }]
draft: { subject, recipient, body }
evidence: [string]
knownFacts: [string]
assumptions: [string]
sources: [{ title, url, excerpt, reviewedAt }]
```

The draft leaves account details, preferred contact method and unresolved complaint facts as placeholders. It asks the provider to explain any credit-file, charge or future-payment consequences. It does not assume support, waive a payment, promise eligibility or present the request as submitted.

## Guidance sources

The workflow paraphrases these public primary sources, reviewed on 7 November 2026. Their titles, links and brief summaries are returned with each plan and shown in the app. Review the sources again before using this outside a demonstration.

- [MoneyHelper: help if you’re struggling to pay your bills](https://www.moneyhelper.org.uk/en/everyday-money/credit/struggling-to-pay-your-gas-or-electricity-bill) supports contacting providers early, checking essential costs and finding free debt advice.
- [FCA: dealing with financial pressure](https://www.fca.org.uk/consumers/financial-impact-rising-costs-living) describes early contact, circumstances-based support, priority bills and the distinction between talking to a lender and entering an arrangement.
- [NatWest: support with bills](https://www.natwest.com/support-centre/payments/general/im-struggling-with-my-bills-how-can-you-help.html) provides the bank’s official money-worries support route.

## What is live, calculated or simulated

| Part | Status |
| --- | --- |
| API validation, n8n webhook execution and returned plan | Live locally |
| Plan and draft personalisation | Rules calculated from submitted profile/forecast |
| Guidance snippets | Curated paraphrases with visible source links |
| Profile balances, household details and payment history | Synthetic |
| Future income, spending and shortfall | Scenario estimates calculated by Flutter |
| Sending a support request, changing payments or obtaining provider agreement | Not performed |

Skipped cloud hosting and automated letter submission. This local prototype is general financial guidance, not a regulated debt-advice or banking service.
