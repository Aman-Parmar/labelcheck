# LabelCheck — Validation

Recorded honestly, 2026-11-17. Three research agents looked at this concept from three angles and did not agree. This document keeps all three findings on the record, and says why the app was picked anyway.

## The three findings

### 1. API agent: Open Food Facts ranked #1

- Open Food Facts API v3 is the best public API for this brief: free, no key, no account, generous rate limits (15 product reads/min/IP, 10 searches/min/IP), ODbL licensed, and built for exactly this lookup — barcode in, product out, with Nutri-Score, NOVA, allergens, ingredients, and nutriments.
- v2 is deprecated. The app builds on v3: `GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json`, `User-Agent: LabelCheck/1.0 (support@singhsec.com)`.
- Verified in the wild: Nutella `3017620422003` (Nutri-Score E, NOVA 4, ~539 kcal/100 g, sugars ~56.3 g) and Coca-Cola `5449000000996` (Nutri-Score E, NOVA 4, 42 kcal/100 g, sugars 10.6 g) resolve as documented. Sample data in `LabelCheck/SampleData/` is a snapshot of these public entries.
- Commercial use is allowed under ODbL with attribution, which the app and README carry.

### 2. ML agent: food ranked best v1 for local ML

- Food scanning is the best first vehicle for the local-ML half of the brief: Vision barcode detection (EAN-13/UPC), Vision OCR (accurate) for the nutrition panel, and Natural Language tokenisation for allergen extraction are all mature, on-device, and need no server and no key.
- Foundation Models (iOS 26+, on-device, ~3B model, 4096-token context — not 8192) can explain a label in plain English, but only as a gated enhancement: it needs iPhone 15 Pro+ with Apple Intelligence, and the deterministic card built from the product's own data is the feature that works on every device.

### 3. Demand agent: food ranked #3 — saturated, with real risks

- Food scanning is a saturated market. Yuka is the incumbent: free core scanning with a ~$10/year Pro. That sets a hard price ceiling — a $4.99/month subscription was validated as wrong for this market and is not used (see `SUBSCRIPTION_PLAN.md`).
- Demand for "yet another scanner" is unproven. The app does not assume anyone will pay for it; the free core is the product, and Pro is depth for people who scan every week.
- Guideline 1.4.1 risk is real: an app that reads food labels sits next to health and dietary advice. Mitigations, built into v1 rather than promised later:
  - No health verdicts anywhere — never "healthy"/"unhealthy" (enforced by unit test).
  - Nutri-Score and NOVA shown as general information from Open Food Facts, with a disclaimer on every product card, in Settings, and in the listing.
  - No allergy safety guarantee — allergen matches are warnings to check the physical label.
  - "Not found / verify" states — Open Food Facts is crowdsourced and may be incomplete or out of date.

## Why pick it anyway

Only one concept satisfied **both** halves of the brief with verified parts:

1. A public API that is genuinely free, keyless, and commercial-safe (Open Food Facts v3). Every other candidate API in the research needed a key, a paid tier, or a usage agreement that would have put a secret or a bill in the loop.
2. Real on-device ML with no server and no key (Vision + Natural Language + gated Foundation Models).

It is also the simplest build in the portfolio: one screen that does one job (scan → know what's in it), no backend, no account, no social graph, no content pipeline. If the demand agent is right and nobody pays, the loss is one small, well-built app — and the free core still works for the people who do scan.

## What would change the decision

- If Open Food Facts v3 becomes keyed, rate-limited to unusable levels, or shuts down, the app has no data source and stops being viable. The client is isolated in `LabelCheck/Logic/OpenFoodFactsClient.swift` so a swap is one file, but there is no verified second source today.
- If App Store review rejects the concept under Guideline 1.4.1 despite the disclaimers, the mitigations in this document are the appeal evidence — and the fallback is to ship the scanner with no scores at all (barcode → ingredients + allergens only).
- If, 90 days after launch, weekly active scanners are near zero and Pro conversion is zero, stop: do not add features to save it. See `GO_TO_MARKET.md`.
