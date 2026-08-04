# Luma

Free, open-source cycle health app for iOS — inspired by Flo’s product surface, not affiliated with Flo Health.

**Status:** Phase 0 + Phase 1 MVP scaffold. Open [`ios/Luma/Luma.xcodeproj`](ios/Luma/Luma.xcodeproj) in Xcode to run on a simulator or device.

## What’s in this repo

| Path | Purpose |
|---|---|
| [`docs/PRD.md`](docs/PRD.md) | Product requirements |
| [`ios/Luma`](ios/Luma) | SwiftUI iOS app (Today, Calendar, Day Log, Insights, AI Assistant, Settings) |
| [`Sources/LumaCore`](Sources/LumaCore) | Shared prediction / catalog / safety logic (SPM) |
| [`supabase`](supabase) | Postgres schema + AI gateway Edge Function |
| [`scripts`](scripts) | Xcode project generator, AI eval harness |

## Features (v0.1)

- Onboarding (goal, last period, cycle/period length, disclaimer, teen mode)
- Today home with cycle ring, phase, predictions, daily insight
- Calendar with period / fertile / ovulation markers
- Day log with **70+** symptoms & moods
- Model-agnostic Health Assistant (offline mock by default; gateway / OpenAI-compatible / Anthropic / on-device stubs)
- Local persistence + sync outbox (Supabase-ready)
- JSON export and delete-all
- GPL-3.0 client / AGPL-3.0 server licenses

## Quick start (iOS)

```bash
# Regenerate the Xcode project if sources changed
python3 scripts/generate_xcodeproj.py

# Open in Xcode
open ios/Luma/Luma.xcodeproj
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
2. Apply [`supabase/migrations/20260804120000_luma_init.sql`](supabase/migrations/20260804120000_luma_init.sql).
3. Deploy [`supabase/functions/ai-gateway`](supabase/functions/ai-gateway) with `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` secrets.
4. In the app Settings, set Supabase URL and enable cloud sync; set `LUMA_AI_GATEWAY_URL` for the gateway provider.

## Trademark notice

Not affiliated with Flo Health UK Limited. Do not ship Flo brand assets or trademarks. Working name: **Luma**.

## License

- App & core: [GPL-3.0](LICENSE)
- Server / Edge Functions: [AGPL-3.0](server/LICENSE)
