# LabelCheck — Roadmap

## v1 (this scaffold — shipped to `main`)

- Scan tab: live barcode scanning (VisionKit DataScanner, EAN-13/UPC), manual barcode entry, lookup against Open Food Facts v3 with in-memory cache
- Product card: name, brand, Nutri-Score, NOVA, allergens, ingredients, nutriments per 100 g, "verify on the physical label" states, source attribution + disclaimer
- Allergen profiles: create profiles, on-device matching, match banner on the product card (first profile free, multiple profiles Pro)
- OCR fallback: photograph an ingredients panel, on-device Vision OCR + Natural Language allergen extraction, user confirms matches
- History: SwiftData on-device (free: most recent 10; Pro: unlimited), delete/clear
- Plain-English label explain: deterministic card from product data; Foundation Models (iOS 26+, gated) as an enhancement
- Paywall: StoreKit 2, $9.99/year + $19.99 lifetime, one Pro entitlement
- Settings: privacy, attribution, support/privacy links, restore purchases
- CI: Linux lint → macOS test + screenshots in parallel → archive (skipped until signing secrets exist)
- 7-shot screenshot lane with bundled sample data, deterministic and offline

## v1.1 (after TestFlight feedback — only what real users ask for)

- Real app icon (placeholder in v1 — required before submission)
- Shareable product card (image export of a scanned product, no account, no feed)
- History export (CSV) — a Pro feature, already promised by the paywall copy
- Barcode scan history search
- Localised allergen names for the most common non-English label languages, if users ask

## Explicitly not building (see `LESSONS.md`)

- Apple Watch, widgets, Siri
- Community, social, sharing feeds, following
- Meal planning, calorie tracking, diet plans, health coaching
- AI coach, chat, any server-side AI
- Ads, analytics, crash reporting, accounts, backend
- Any feature that needs a secret, a key, or a server

A feature only moves from this list to the roadmap on a new decision with evidence from real users — never on speculation, and never by silently widening scope in a build-loop run.
