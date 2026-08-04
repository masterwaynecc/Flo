# dawt

Free, open-source cycle health app for iOS — inspired by Flo’s product surface, not affiliated with Flo Health.

**Status:** Phase 0 + Phase 1 MVP scaffold. Open [`ios/Dawt/Dawt.xcodeproj`](ios/Dawt/Dawt.xcodeproj) in Xcode to run on a simulator or device.

## What’s in this repo

| Path | Purpose |
|---|---|
| [`ios/Dawt`](ios/Dawt) | SwiftUI iOS app (Today, Calendar, Day Log, Insights, AI Assistant, Settings) |
| [`Sources/DawtCore`](Sources/DawtCore) | Shared prediction / catalog / safety logic (SPM) |
| [`supabase`](supabase) | Postgres schema + AI gateway Edge Function |
| [`scripts`](scripts) | Xcode project generator, AI eval harness |

## Features (v0.1)

- Onboarding (goal, last period, cycle/period length, disclaimer, teen mode)
- Today home with cycle ring, phase, predictions, daily insight
- Calendar with period / fertile / ovulation markers
- Day log with **70+** symptoms & moods
- Model-agnostic Health Assistant using **open-weight models only** (offline mock by default; Ollama / self-hosted / gateway / on-device stubs — no OpenAI/Anthropic)
- Local persistence + sync outbox (Supabase-ready)
- JSON export and delete-all
- GPL-3.0 client / AGPL-3.0 server licenses

## Quick start (iOS)

```bash
# Regenerate the Xcode project if sources changed
python3 scripts/generate_xcodeproj.py

# Open in Xcode
open ios/Dawt/Dawt.xcodeproj
```

Select an iPhone simulator or your device, then Run.

If Xcode reports the iOS platform is missing:

```bash
xcodebuild -downloadPlatform iOS
```

## Core tests (no simulator required)

```bash
swift test
python3 scripts/ai_eval.py
```

## Supabase (optional cloud sync + AI gateway)

1. Create a Supabase project.
2. Apply [`supabase/migrations/20260804120000_dawt_init.sql`](supabase/migrations/20260804120000_dawt_init.sql).
3. Run an open-weight server locally, e.g. `ollama pull llama3.2 && ollama serve`.
4. Deploy [`supabase/functions/ai-gateway`](supabase/functions/ai-gateway) with `DAWT_OSS_BASE_URL` (e.g. your Ollama/vLLM OpenAI-compatible URL) and `DAWT_OSS_MODEL` (default `llama3.2`).
5. In the app Settings, pick **Ollama**, **Self-hosted open-weight**, or **dawt gateway**; set `DAWT_AI_GATEWAY_URL` when using the gateway.

Closed-source hosted model APIs are intentionally unsupported.

## Trademark notice

Not affiliated with Flo Health UK Limited. Do not ship Flo brand assets or trademarks. Product name: **dawt**.

## License

- App & core: [GPL-3.0](LICENSE)
- Server / Edge Functions: [AGPL-3.0](server/LICENSE)
