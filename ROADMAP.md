# LabelCheck — Roadmap (agile, living)

Agile model since 2026-11-18 (Aman: adopt agile, not waterfall). One-week sprints, Monday planning, Friday review. This file is the single source of truth for what gets built: the Researcher scores backlog items by market evidence, the PM picks the Sprint Backlog, the Developer loop builds it in order, QA verifies each item independently. Nothing moves here without evidence — pre-launch the evidence is competitor reviews, pricing, and ASO; post-launch it is real downloads, conversion, retention, and App Store reviews.

A feature only moves from "not building" to the roadmap on a new decision with evidence from real users — never on speculation, and never by silently widening scope in a build-loop run.

## Shipped (v1, code-complete, not yet submitted)

- Scan tab: live barcode scanning (VisionKit DataScanner, EAN-13/UPC), manual barcode entry, lookup against Open Food Facts v3 with in-memory cache
- Product card: name, brand, Nutri-Score, NOVA, allergens, ingredients, nutriments per 100 g, "verify on the physical label" states, source attribution + disclaimer
- Allergen profiles: create profiles, on-device matching, match banner on the product card (first profile free, multiple profiles Pro)
- OCR fallback: photograph an ingredients panel, on-device Vision OCR + Natural Language allergen extraction, user confirms matches
- History: SwiftData on-device (free: most recent 10; Pro: unlimited), delete/clear, CSV export (Pro, via the system share sheet)
- Plain-English label explain: deterministic card from product data; Foundation Models (iOS 26+, gated) as an enhancement
- Paywall: StoreKit 2, $9.99/year + $19.99 lifetime, one Pro entitlement
- Settings: privacy, attribution, support/privacy links, restore purchases
- Real 1024x1024 app icon; labelcheck.singhsec.com support + privacy pages live
- CI: Linux lint → macOS test + screenshots in parallel → archive (skipped until signing secrets exist); 8-shot screenshot lane with bundled sample data, deterministic and offline (08-alternatives added with LC-1)

## Sprint 1 — 2026-11-18 to 2026-11-24 (in progress)

Sprint goal: close the gaps users complain about most in every competing scanner, starting with the one every winner ships.

- **LC-1 Healthier alternatives (same-category, better Nutri-Score)** — medium. Evidence: most-requested feature across winners; Yuka 5-star reviews praise swaps, its absence is a named complaint; Bobby, Trash Panda, Fig all ship it. Acceptance: on a D/E product card, 2-3 same-category products with a better Nutri-Score from OFF category search, one tap to view. Status 2026-11-18: BUILT (f81a4a0), QA PASSED 2026-11-18 (run 44382232471, all 4 jobs green, all 8 shots verified 1320x2868, section renders 3 rows C/D/D with chevrons, no verdict language). One minor docs defect filed below (QA-1): app-store-listing.md stale after LC-1. Notes: search endpoint is `cgi/search.pl` (OFF ignores a Nutri-Score filter there, so the grade cut is client-side); category candidates most-specific-first with a broad-category denylist, up to 3 searches; section hidden on fetch failure; privacy policy + Settings copy updated (category tag is now also sent); screenshot lane is 8 shots (08-alternatives added).
- **LC-2 Offline cache of scanned products** — small. Evidence: offline mode is a Yuka Premium selling point; store-signal timeouts freezing apps is a recurring 1-star theme. Acceptance: every scanned product's OFF payload cached in SwiftData at scan time; re-scans and history work with no signal. Status 2026-11-18: BUILT, CI GREEN on run 44390286674 (all 4 jobs: Lint 40s, Build/test 5m11s, Screenshots 12m54s, Archive 20s, exits cleanly without signing secrets as designed), awaiting independent QA. Raw OFF v3 response JSON stored verbatim in a new `CachedProduct` SwiftData model (barcode unique, payload, cachedAt), via a `ProductPayloadStore` actor that owns its own ModelContext from the app container; `OpenFoodFactsClient.fetchProduct` checks memory, then sample data (screenshot mode wins, lane stays deterministic), then the persistent cache, then the network, and saves the raw payload on every network success. History taps load the full cached card, falling back to the summary fields on the row when nothing is cached. Cap 200 entries, oldest pruned first. Privacy policy, README, and listing updated (on-device only, no new network call, no new data sent). 7 new unit tests in ProductCacheTests (round-trip, unknown/corrupt, overwrite, prune cap, client serves cached with dead network, client persists network response). First CI run 44388254858 FAILED on a compile error: `await` inside XCTUnwrap/XCTAssertNil autoclosures does not compile; fixed in 2d09662 by hoisting the await into a `let` first (lesson added to LESSONS.md).
- **LC-3 Search by product name (no barcode)** — small-medium, Pro-gated. Evidence: Yuka locks search behind Premium and users complain about exactly that ("can't search the brand, you have to be a member"); OFF API supports it natively. Acceptance: type-to-search by name/brand, Pro gate like Yuka's.

## Next (prioritised backlog, evidence-scored)

- **QA-1 (2026-11-18, minor, docs only): app-store-listing.md stale after LC-1** — (a) Description still says "The only thing that leaves the phone is the barcode itself", but LC-1 also sends the product category to Open Food Facts on D/E cards (privacy-policy.md:9,14 and Settings already updated; listing not). (b) Screenshots section still says "7" and omits 08-alternatives, though the lane is now 8 shots. Evidence: QA on run 44382232471, 08-alternatives.png shows the section live; listing lines verified by grep. Fix: update both lines in app-store-listing.md. Found by independent QA; app itself passes, listing is the only mismatch.
- **Favorites + shopping lists** — medium. Evidence: the only honest retention mechanic in this category (the weekly-shop loop); Yuka favorites + history, Trash Panda curated lists, Fig lists. Local only, no account.
- **Additive explainer (plain-language, sourced)** — small-medium. Evidence: Trash Panda's pitch is flags linked to studies; Yuka is criticised for flagging without explaining. No invented risk claims, no verdict.
- **Add a missing product / report wrong data** — medium. Evidence: missing/stale US products are the #1 complaint class across every scanner (6-9 of 25 products missed in hands-on tests). Needs a check of OFF's anonymous contribution API rules before building; fallback is a deep link to OFF's contribution page.
- **Diet filters beyond allergens (vegan, gluten-free, seed-oil avoid)** — medium. Evidence: Fig's entire moat (2,800+ options); Yuka Premium dietary preferences. Extends the existing profile system.
- **History search** — small. Evidence: Yuka's unlimited history is a Premium selling point; LabelCheck Pro has unlimited history but no search.
- **Shareable product card (image export)** — small. Was v1.1; keep in Next, build only if users ask.

## Later / unsequenced

- Localised allergen names for the most common non-English label languages, if users ask.
- "Top products" discovery by category (a reason to open the app outside a shop).

## Explicitly not building

- A LabelCheck health score / verdict ("good" vs "bad" food). Yuka's 0-100 score is its most criticised feature; also the Guideline 1.4.1 risk this app is designed around. Nutri-Score and NOVA are published third-party data — present them, never invent a verdict on top.
- AI coach, diet plans, calorie/macro tracking. Crowded, medical-adjacent, on the no-go list.
- Social / user reviews / community. Moderation and spam risk for a solo dev with no backend.
- Cosmetics scanning. Doubles the database and scoring surface for no incremental advantage.
- Price comparison. No reliable free price API; prices go stale and create the same staleness complaints that sink scanners.
- Streaks. No scanner uses them; they would punish people for not shopping.
- Apple Watch, widgets, Siri. Meal planning, health coaching. Ads, analytics, crash reporting, accounts, backend. Any feature that needs a secret, a key, or a server.

## Kill gate

90 days after launch: if weekly active scanners are near zero and Pro conversion is zero, stop. Do not add features to save it. See `GO_TO_MARKET.md`.
