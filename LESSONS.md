# LabelCheck — Lessons from Clear Days

These rules are carried over from the Clear Days build, verbatim in spirit. They are enforced by the build loop, not just written down: a change that breaks one of these gets cut before it ships, the same way the Apple Watch was cut from Clear Days when it could not work.

## 1. Optimised CI

- Linux job first (cheap lint + Foundation-only logic tests), then the macOS test lane and the macOS screenshots lane **in parallel**, both gated on Linux. Archive job after both, only if signing secrets exist, otherwise it exits cleanly — a missing secret is never a red build.
- Docs-only pushes skip CI (`paths-ignore: **.md, docs/**`).
- `concurrency: cancel-in-progress: true` on the ref, so a batch of pushes costs one run, not one run per push.
- Cache Homebrew installs + SPM/DerivedData. The repo is public (flipped back from private by Aman 2026-11-17 ~23:21 ET): public repos get free unlimited Actions minutes, including macOS. Optimise for wall-clock, but keep the lanes lean anyway.
- Batch independent low-risk changes into **one commit / one CI cycle**. Do not push tiny commits that each trigger a full run.
- Wait for CI in the same run where possible — do not leave verification to the next run. Slow poll only: one `gh run view` per check, sleep at least 180 seconds between checks, at most ~8 checks. NEVER use `gh run watch` — it polls every 3 seconds and exhausts the GitHub API rate limit (403), blocking ALL gh calls for about an hour (hit 2026-11-18). If any gh call returns a 403 rate limit, STOP all gh calls immediately and wait for the window to reset; do not retry in a loop.
- GitHub actions pinned to v6 (2026-11-19): checkout/cache/upload-artifact v6 is the Node 24 generation; v5 drew a Node 20 deprecation annotation on every run. v6 release notes verified: runtime bump only, no input changes for this workflow, GitHub-hosted runners satisfy the minimum runner version. v7 exists (upload-artifact 7.0.2, checkout 7.0.1, cache 6.1.0) but was not adopted — its changes were not reviewed; bump one major at a time and read the release notes first.

## 2. Screenshots — real, never mockups

- 9-shot lane on the iPhone 17 Pro Max simulator: 01-scan, 02-product card, 03-allergens, 04-history, 05-OCR fallback, 06-paywall, 07-settings, 08-alternatives, 09-search (`UITests/ScreenshotTests.swift`). 08 added 2026-11-18 with LC-1 (alternatives section sits below the fold on the card, so it gets its own shot); 09 added 2026-11-18 with LC-3 (search-by-name results).
- Screenshot-mode sample data only: a fixed set of 3 known Open Food Facts barcodes/products with bundled sample JSON (`LabelCheck/SampleData/SampleProducts.json`), so screenshots are deterministic and offline. Never mockups, never Figma.
- Every future update comes with real simulator screenshots from CI.
- Verify framing after every run: scan button, Nutri-Score badge, and allergen banner fully visible in each shot, no clipping.

## 3. Simplicity wins — core-features discipline

- Free core always works forever: **unlimited barcode scans + product card**. Pro is depth only: unlimited history, multiple allergen profiles, OCR label explain, search by product name, export.
- No social, no AI coach, no ads, no tracking, no account, no backend.
- Remove nonsense features before they get built. Explicitly **not** building in v1, and not to be added without a new decision: Apple Watch, widgets, Siri, community, meal planning, calorie tracking.
- One job: scan → know what's in it → save if you want.
- Keep Logic separate from Views (`LabelCheck/Logic` vs `LabelCheck/Views`) so the core stays reusable.
- No dead code, no unused assets, no duplicate logic, no unnecessary dependencies. Run a bloat check before pushing: every file in the repo must be referenced by `project.yml`, a test, CI, or a doc — or it gets deleted.
- StoreKit 2 only. No RevenueCat.

## 4. XcodeGen owns the Info.plist

- Never add a key only to a checked-in `Info.plist`. XcodeGen rewrites every target Info.plist from `project.yml` and drops it. Every Info.plist key (camera usage description, display name, etc.) must be in `project.yml` under the target's `info.properties`.
- Never commit a `.xcodeproj`. Regenerate with `xcodegen generate`.
- Drift found 2026-11-18 (hygiene audit): the checked-in plist carried `LSRequiresIPhoneOS` and `UIApplicationSceneManifest`, neither in `project.yml` — XcodeGen's auto-generated list covers the eight `CFBundle*` keys but not these two, so every CI generate silently dropped them. Fix: `LSRequiresIPhoneOS: true` moved into `project.yml` (Xcode template default for iOS apps); `UIApplicationSceneManifest` deleted from the checked-in plist (inert under the SwiftUI App lifecycle, single scene is the default). Audit the plist against `project.yml` + XcodeGen's auto-generated list whenever either file changes.

## 5. Security — standing rule

- No secrets anywhere. No API keys (none needed — Open Food Facts v3 needs no key). No signing secrets in the repo. CI archive exits cleanly without secrets.
- No network calls beyond the Open Food Facts lookup for a scanned barcode. No new dependencies without a real need — hand-roll on existing Apple frameworks.
- Before every push, run the secret scan: `grep -r` for `p8`, `pem`, `API_KEY`, `password`, `token` across staged files, and confirm `.gitignore` covers `*.p8`, `*.pem`, `.env`, `*.p12`, `*.mobileprovision`, `*.xcodeproj/`.
- The public-repo secret audit rule from Clear Days applies here too: all signing values live only in GitHub repo settings as Actions secrets, referenced via `secrets.*` in the workflow.

## 6. Honesty rules (content + data)

- Never say "healthy" or "unhealthy". Nutri-Score and NOVA are general information from Open Food Facts, not health verdicts. Enforced by `Tests/NutriScoreTests.swift`.
- Never present an allergen match as a safety guarantee. Every product card and every OCR result says to check the physical label.
- Open Food Facts is crowdsourced: show "not found / verify" states, never auto-trust.
- Sample data is labelled as sample data, in the file and in this document. Screenshot values are a snapshot, not live data.
- Foundation Models is a gated iOS 26+ enhancement, never the core value prop. iOS 26 context is 4096 tokens, not 8192 — keep prompts short.

## 7. SwiftUI presentation traps (found the hard way)

- Never put two `.sheet` modifiers on the same view: only one reliably presents, and the other can silently fail to appear with no error. ScanView's OCR sheet never presented in CI (runs 44238639541, 44240348390) until it became a navigation push; AllergenProfilesView had the identical latent bug (add + paywall sheets) and was fixed the same way (2026-11-18). One sheet per view at most; anything else is a navigation push, and a UI test must cover the push.
- Screenshot timing: `waitForExistence` returns as soon as the element exists, which can be mid-push-transition. Add a 1s settle delay before capturing a screenshot of a pushed view (05-OCR was captured mid-transition: top half black, tab bar overlapping text).
- No em dashes in user-facing copy, ever. Use a colon or a full stop instead. Swept 2026-11-18 (20 strings across NutriScore, LabelExplainer, Paywall, Scan, Product, OCR result, Settings, Allergen profiles).
- iOS 26 floating tab bar overlays scroll content: the pill floats over the bottom of every tab screen, so content that reaches the screen bottom sits half-hidden behind it (01 scan button, 02 Nutri-Score, 05 OCR text, 07 privacy text all caught in the 2026-11-18 listing shots). Fix in two parts: (1) pushed detail screens (product card, OCR result, add profile) hide the bar with `.toolbar(.hidden, for: .tabBar)`; (2) every tab ScrollView/List carries `.contentMargins(.bottom, 110, for: .scrollContent)` so the last content scrolls fully above the pill. Screenshot tests nudge the content up ~140pt before capturing 01/04/07.
- Screenshot scroll timing (2026-11-18, runs 44250358989–44254094663): a 0.5s settle after a drag caught the scroll mid-deceleration and the collapsing large title ghosted over the card in 01; 1.5s did not help — the ghosting is the static resting state of a scrolled Scan screen (card title under the nav bar blur), not a timing issue. A coordinate press-drag does NOT scroll a List whose rows are Buttons (the row captures the touch): 04/07 came back byte-identical. `app.swipeUp()` was a no-op on these Lists too (07 byte-identical again), and `tables.firstMatch` matches nothing for a SwiftUI List (test04/test07 failed with "No matches found" in run 44252395003). Do not fight List framing with test gestures: fix the layout instead, and accept a partly visible last row as normal list behaviour.
- Scan CTA half-hidden at rest (2026-11-18, runs 44247113507–44254094663): the "Scan with camera" button sat half-hidden behind the iOS 26 floating tab bar when the Scan tab opened — a real defect, not just a screenshot problem. Fixed by making ScanView use an inline title (the large title pushed the card down) and tightening the camera card (icon 56→48, spacing 20→16 / 12→10). The card's own "Scan any packaged food" heading carries the screen's identity.
- Accessibility identifiers on plain containers do not surface in XCUI (2026-11-18, run 44379182540): test02/test10 waited 10 s for `otherElements["alternatives-section"]` on a VStack and never found it, though the section rendered. A VStack is not an accessibility element. Fix: `.accessibilityElement(children: .contain)` on the container so the identifier surfaces, and in tests prefer waiting on a child StaticText (the section heading) over a container identifier.
- `await` inside an assertion autoclosure does not compile (2026-11-18, run 44388254858): `XCTUnwrap(await store.load(...))` and `XCTAssertNil(await store.load(...))` both fail with "call to actor-isolated instance method in a synchronous nonisolated context" / "'await' in an autoclosure that does not support concurrency". Hoist the await into a `let` first, then assert on the value. Applies to every XCTAssert/XCTUnwrap call that takes an autoclosure.
- A helper in a `private extension` is file-scoped (2026-11-19, run 44467292287): reusing `nilIfEmpty` from `Product.swift` in `ScannedProduct.swift` failed the macOS build with "'nilIfEmpty' is inaccessible due to 'fileprivate' protection level" — the Linux lint job does not compile Swift, so it passed and hid the break. Check the access level before reusing any helper across files; only the macOS build catches it.
- `split(separator:)` returns `[Substring]`, not `[String]` (2026-11-19, run 44505063722): `commaSeparatedList` calling `.trimmed` (a `String` helper) on `$0` failed the macOS build with "reference to member 'trimmed' cannot be resolved without a contextual type" — the Linux lint job does not compile Swift, so it passed and hid the break. Fix: `String($0).trimmed`. Same lesson as the private-extension one above: only the macOS build catches type errors in shared helpers, so a hygiene refactor that touches a helper must wait for the macOS job, not just the Linux lint.
