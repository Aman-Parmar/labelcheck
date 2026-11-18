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
- CI: Linux lint → macOS test + screenshots in parallel → archive (skipped until signing secrets exist); 9-shot screenshot lane with bundled sample data, deterministic and offline (08-alternatives added with LC-1, 09-search added with LC-3)

## Sprint 1 — 2026-11-18 to 2026-11-24 (in progress)

Sprint goal: close the gaps users complain about most in every competing scanner, starting with the one every winner ships.

- **LC-1 Healthier alternatives (same-category, better Nutri-Score)** — medium. Evidence: most-requested feature across winners; Yuka 5-star reviews praise swaps, its absence is a named complaint; Bobby, Trash Panda, Fig all ship it. Acceptance: on a D/E product card, 2-3 same-category products with a better Nutri-Score from OFF category search, one tap to view. Status 2026-11-18: BUILT (f81a4a0), QA PASSED 2026-11-18 (run 44382232471, all 4 jobs green, all 8 shots verified 1320x2868, section renders 3 rows C/D/D with chevrons, no verdict language). One minor docs defect filed below (QA-1): app-store-listing.md stale after LC-1. Notes: search endpoint is `cgi/search.pl` (OFF ignores a Nutri-Score filter there, so the grade cut is client-side); category candidates most-specific-first with a broad-category denylist, up to 3 searches; section hidden on fetch failure; privacy policy + Settings copy updated (category tag is now also sent); screenshot lane is 8 shots (08-alternatives added).
- **LC-2 Offline cache of scanned products** — small. Evidence: offline mode is a Yuka Premium selling point; store-signal timeouts freezing apps is a recurring 1-star theme. Acceptance: every scanned product's OFF payload cached in SwiftData at scan time; re-scans and history work with no signal. Status 2026-11-18: BUILT, CI GREEN on run 44390286674 (all 4 jobs: Lint 40s, Build/test 5m11s, Screenshots 12m54s, Archive 20s, exits cleanly without signing secrets as designed), QA PASSED 2026-11-18 (independent QA, run 44390286674, all 8 shots verified 1320x2868, no visual regression, fetch order / save-on-success / History fallback / cap-200 prune / sample-data precedence all verified in code, 7 tests verified to cover what they claim, launch checklist clean: prices $9.99/$19.99 match, no verdict language, no placeholder copy, em dashes comments-only, no secrets). No defects found. Raw OFF v3 response JSON stored verbatim in a new `CachedProduct` SwiftData model (barcode unique, payload, cachedAt), via a `ProductPayloadStore` actor that owns its own ModelContext from the app container; `OpenFoodFactsClient.fetchProduct` checks memory, then sample data (screenshot mode wins, lane stays deterministic), then the persistent cache, then the network, and saves the raw payload on every network success. History taps load the full cached card, falling back to the summary fields on the row when nothing is cached. Cap 200 entries, oldest pruned first. Privacy policy, README, and listing updated (on-device only, no new network call, no new data sent). 7 new unit tests in ProductCacheTests (round-trip, unknown/corrupt, overwrite, prune cap, client serves cached with dead network, client persists network response). First CI run 44388254858 FAILED on a compile error: `await` inside XCTUnwrap/XCTAssertNil autoclosures does not compile; fixed in 2d09662 by hoisting the await into a `let` first (lesson added to LESSONS.md).
- **LC-3 Search by product name (no barcode)** — small-medium, Pro-gated. Evidence: Yuka locks search behind Premium and users complain about exactly that ("can't search the brand, you have to be a member"); OFF API supports it natively. Acceptance: type-to-search by name/brand, Pro gate like Yuka's. Status 2026-11-18: BUILT, QA PASSED 2026-11-18 (independent QA, run 44395771905, all 4 jobs green: Lint 40s, Build/test 3m13s, Screenshots 13m20s, Archive 22s exits cleanly without signing as designed; all 9 shots verified 1320x2868 by eye, 09-search shows the "nutella" query and the Nutella/Ferrero E-badge result row, 01-scan shows the new section with nothing clipped or pushed behind the tab bar; gate `store.isPro || ScreenshotMode.isEnabled` verified in ScanView.swift:276 with test12 covering the non-Pro paywall path; tap flow fetchProduct + saveToHistory + selectedProduct verified; all 7 ProductSearchTests passed in CI with no skips; launch checklist clean: listing lists 9 shots with search in the Pro line, prices $9.99/$19.99 match, no verdict language, no placeholder copy, em dashes comments-only, no secrets). Two minor docs defects filed below (QA-2, QA-3). `OpenFoodFactsClient.searchByName` uses the same `cgi/search.pl` endpoint as LC-1 with `search_terms` (only the typed words are sent); a shared `search(queryItems:)` helper serves both paths. Scan tab gains a "Search by name" section; results show name, brand, Nutri-Score badge, and tap opens the full product card via a barcode lookup (which also saves the payload to the LC-2 offline cache) and saves to History. Free users tapping Search get the paywall (navigation push, not a second sheet: ScanView already carries the scanner sheet, and two sheets on one view is the pattern that failed for OCR). Paywall lists search as a Pro feature. Screenshot mode bypasses the gate so the lane can capture results offline (test11, 09-search); the gate itself is covered by test12, which relaunches without screenshot mode and expects the paywall. Privacy policy, listing, README, and subscription plan updated (search text is a third thing that leaves the phone). 7 new unit tests in ProductSearchTests (response decoding, search_terms request, empty query skips network, HTTP error, sample filter by name/brand).
- **QA-1 RESOLVED 2026-11-18 (docs only): app-store-listing.md stale after LC-1** — fixed in commit 78ca9c1, before this run: the listing description already discloses the category send and the Screenshots section already lists 8 shots including 08-alternatives. Verified by reading the listing in this run; removed from the Next backlog below.

## Next (prioritised backlog, evidence-scored)

- **QA-2 PASSED 2026-11-18 (docs): Settings privacy line stale after LC-3** — fixed in commit e9402dc, verified by independent QA on CI run 44400501775 (all 4 jobs green): 07-settings.png shows the new line "Only the scanned barcode, the product category, and (Pro) your search words leave this phone. History and profiles stay on this phone." fully visible, whole list fits at rest with nothing clipped behind the tab bar; matches privacy-policy.md.
- **QA-3 PASSED 2026-11-18 (docs): Pro feature lists omit search by name** — fixed in commit e9402dc, verified by independent QA on CI run 44400501775 (all 4 jobs green): both StoreKit descriptions in 06-paywall.png read "search by product name" with prices $9.99/$19.99, Settings Pro card in 07-settings.png reads "search by name", matching the paywall bullet and the listing/SUBSCRIPTION_PLAN/README/LESSONS lists. StoreManager.swift comment updated for consistency.
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
