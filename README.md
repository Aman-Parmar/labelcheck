# LabelCheck — Scan any packaged food, know what's in it in 2 seconds, privately.

A native iOS food-label scanner. Scan a barcode, get the product card: name, brand, Nutri-Score, NOVA group, allergens, ingredients, and nutrition per 100 g — from Open Food Facts, on-device allergen matching, on-device OCR fallback. No account, no ads, no tracking, no backend.

- Platform: iOS 17 and later, iPhone
- Language and UI: Swift 5.9 (per `project.yml`), SwiftUI
- Data: Open Food Facts API v3 (no key), SwiftData on-device only
- Local ML: Vision barcode + OCR, Natural Language allergen extraction, Foundation Models (iOS 26+, gated, enhancement only)
- Payments: StoreKit 2, serverless (no backend, no receipt server)
- Project generation: XcodeGen (`project.yml` at the repo root)
- CI: GitHub Actions (`.github/workflows/ios.yml`)

## What it does

- Scan a barcode (camera) or type the digits under it — unlimited scans, free, forever
- Product card: name, brand, Nutri-Score A–E, NOVA group 1–4, listed allergens, ingredients, nutrition per 100 g
- Additive explainer: every E-number on the card explained in plain English (what it is, what it does), from the public E-number list; no verdict, free for everyone
- Allergen profiles: set the allergens you watch for; every product card flags matches on-device
- OCR fallback: photograph an ingredients panel when the barcode is not in the database; allergens are extracted on-device and you confirm them
- History: every scan saved on the phone (free shows the most recent 10, Pro unlimited)
- Favorites: tap the heart on any product card to save it for the weekly shop, on this phone only, free for everyone
- Shopping lists: group favorites into named lists for the weekly shop, check items off as you buy them, on this phone only, free for everyone
- Plain-English label explain: a deterministic card built from the product's own data; on iPhone 15 Pro+ with Apple Intelligence (iOS 26) an on-device model can also explain it
- Pro (paid): unlimited history, multiple allergen profiles, OCR label explain, search by product name, export

## What it deliberately does not do

See `LESSONS.md`. Short version: no health verdicts (never "healthy"/"unhealthy"), no allergy safety guarantee, no Watch, no widgets, no Siri, no community, no meal planning, no calorie tracking, no social, no AI coach, no ads, no tracking, no account, no backend. One job: scan → know what's in it → save if you want.

## StoreKit products

Configure these exact product IDs in App Store Connect under the LabelCheck app. Prices in USD.

| Product ID | Type | Price |
| --- | --- | --- |
| `labelcheck_pro_yearly` | Auto-renewable subscription, 1 year | $9.99 |
| `labelcheck_pro_lifetime` | Non-consumable, one-time purchase | $19.99 |

Notes on pricing (see `SUBSCRIPTION_PLAN.md` and `VALIDATION.md`):

- No monthly tier: the market anchor is $10–20/year (Yuka's core is free, Pro is ~$10/year). A $4.99/month price was validated as wrong for this market and is not used.
- Yearly at $9.99 and lifetime at $19.99 (about two years of yearly). One Pro entitlement, not two feature sets.
- Test in Xcode with the StoreKit Configuration file `Resources/LabelCheck.storekit` (already wired into the Run scheme in `project.yml`). Test with the sandbox, never with a real Apple ID in a debug build.

## Data source and honesty

- Product data comes from Open Food Facts (world.openfoodfacts.org), API v3, no key, ODbL licensed. Only the scanned barcode is sent, to fetch that product. On a D/E product card the app also sends that product's category to fetch same-category products with a higher Nutri-Score. With Pro, the words typed in a name search are also sent, to find matching products.
- Open Food Facts is crowdsourced. It can be incomplete or out of date. The app shows a "verify on the physical label" state on every product card and never auto-trusts the data.
- Nutri-Score and NOVA are shown as general information from Open Food Facts, with the disclaimer: general information only, not medical or dietary advice, not an allergy safety guarantee. Always check the physical label and check with a doctor about dietary questions. This is the Guideline 1.4.1 risk mitigation (see `VALIDATION.md`).

## Prerequisites

You need a Mac to build for iOS. There is no supported way to build an iOS app on Linux or Windows alone. Linux is used here only for cheap lint in CI.

- macOS 26 (Tahoe) or later
- Xcode 26 with the iOS 26 SDK
- Command Line Tools: `xcode-select --install`
- Homebrew: https://brew.sh
- XcodeGen: `brew install xcodegen`
- A GitHub account, for the repo and CI
- An Apple Developer Program membership, for device testing and TestFlight (see "What needs Aman" below). Simulator testing works without it.

## Build from scratch

### 1. Clone the repo

```bash
git clone https://github.com/Aman-Parmar/labelcheck.git
cd labelcheck
```

### 2. Generate the Xcode project

The repo does not commit the `.xcodeproj` file. It is generated from `project.yml` with XcodeGen.

```bash
brew install xcodegen
xcodegen generate
```

This creates `LabelCheck.xcodeproj`. If you add a new Swift file under `LabelCheck/`, `Tests/`, or `UITests/`, re-run `xcodegen generate`. You do not need to drag files into Xcode by hand.

### 3. Open in Xcode

```bash
open LabelCheck.xcodeproj
```

In Xcode, check three things before your first run:

- The scheme at the top is `LabelCheck`.
- The deployment target is iOS 17.0.
- The bundle identifier is `com.singhsec.labelcheck` (see "Signing" below if this needs to change to match Aman's team).

### 4. Run on the simulator

1. Pick a simulator in the run destination menu, for example iPhone 17 running iOS 26.
2. Press Cmd-R, or Product, Run.
3. The app launches empty. Type a barcode (for example `3017620422003` for Nutella) in the manual entry field — the simulator has no real camera barcode to scan, but the lookup, product card, history, and paywall all work. Sample data for screenshots lives in `LabelCheck/SampleData/` and is used only in screenshot mode.

Simulator testing covers the lookup, product card, allergen matching, history, and paywall UI. It does not cover the live camera scanner or real purchases. For purchases, use the StoreKit Configuration file `Resources/LabelCheck.storekit`.

### 5. Run on a real device

1. Connect an iPhone by cable or over Wi-Fi.
2. In Xcode, select the phone as the run destination.
3. The first time, Xcode asks for a development team. Pick Aman's team (see "Signing").
4. Press Cmd-R. If iOS shows an "Untrusted Developer" message on the phone, go to Settings, General, VPN and Device Management, trust the developer certificate, then launch again.

A free Apple ID can run the app on a device for development, but only a paid Developer Program membership enables TestFlight, App Store submission, and StoreKit testing outside the sandbox.

### 6. Run the tests

```bash
xcodebuild test \
  -scheme LabelCheck \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:LabelCheckTests
```

Or press Cmd-U in Xcode. Unit tests live in `Tests/` and cover Open Food Facts parsing, allergen matching, and the Nutri-Score display mapping — the parts that must never be wrong, because a wrong allergen match is the one bug a user will notice on day one.

### 7. Screenshots

The screenshot lane is a UI test target (`UITests/ScreenshotTests.swift`). It launches the app in `--screenshot-mode` (bundled sample data, no network) and captures twelve shots on the iPhone 17 Pro Max simulator. In CI it runs in parallel with the unit tests; locally:

```bash
xcodebuild test \
  -scheme LabelCheck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
  -only-testing:LabelCheckUITests/ScreenshotTests
ls /tmp/labelcheck-screenshots
```

Every update ships with fresh screenshots from CI. Never mockups, never Figma. After a run, check framing: scan button, Nutri-Score badge, and allergen banner fully visible in each shot, no clipping.

## TestFlight via CI

CI does not upload to TestFlight yet in v1 — the archive job exits cleanly until the signing secrets exist and a Match setup is wired (see `GO_TO_MARKET.md`). The test and screenshots lanes are the gate. When the archive step lands, the flow is the Clear Days one: push to `main`, CI tests + screenshots, then archive and upload; the build appears in App Store Connect under TestFlight.

## Signing overview

Same shape as Clear Days, when the time comes: Fastlane Match stores certificates and provisioning profiles in a private git repo, encrypted. CI runs Match in readonly mode and never creates or rotates certificates. The `.p8` App Store Connect API key is download-once; its base64 form goes into the `APP_STORE_CONNECT_API_KEY_KEY` GitHub secret. None of these values ever go in the repo — see `LESSONS.md` and the secret scan in the repo history.

## Project layout

```
labelcheck/
  project.yml                  # XcodeGen spec. Source of truth for targets.
  LabelCheck/
    App/                       # App entry point, tab navigation
    Models/                    # FoodProduct (Open Food Facts v3), SwiftData history + profiles
    Logic/                     # Pure logic: API client, Nutri-Score, allergen matcher,
                               #   OCR, barcode scanner, StoreKit, label explainer, screenshot mode
    SampleData/                # Bundled sample products + OCR text, screenshot mode ONLY
    Views/                     # SwiftUI screens: scan, product card, history, allergens,
                               #   OCR result, settings, paywall
  Resources/
    Assets.xcassets/           # App icon (real 1024 master + all sizes, white barcode
                               #   + checkmark on leaf-green accent), accent color
    LabelCheck.storekit        # StoreKit Configuration for sandbox purchase testing
    PrivacyInfo.xcprivacy      # Privacy manifest: no tracking, no collected data
  Tests/                       # Unit tests (LabelCheckTests target)
  UITests/                     # Screenshot tests (LabelCheckUITests target)
  .github/workflows/ios.yml    # CI: Linux lint, then macOS test + screenshots in parallel,
                               #   then archive (skipped until signing secrets exist)
```

## What needs Aman

These are the steps only Aman can do, because they need his Apple ID, his payment, or his phone. Nothing here is delegated to an agent.

1. Apple Developer Program, $99 per year, enroll as an Individual. Takes 1 to 2 days. Enroll at developer.apple.com with his Apple ID.
2. Paid Apps Agreement in App Store Connect. Without it, no paid app and no subscriptions can be sold. Go to App Store Connect, Agreements, Tax, and Banking, and accept the Paid Apps Agreement, then add tax and banking details.
3. Small Business Program, 15 percent commission instead of 30 percent. Apply in App Store Connect after the Paid Apps Agreement is in place.
4. App Store Connect API key. In App Store Connect, Users and Access, Integrations, create a key with the App Manager role, download the `.p8` file once, and keep it safe. Apple shows it once and never again. If it is lost, revoke it and create a new one. The base64 form of that file goes into the `APP_STORE_CONNECT_API_KEY_KEY` GitHub secret.
5. TestFlight on his iPhone. Install the TestFlight app from the App Store, accept the internal tester invite for LabelCheck, and install the build.
6. App Store listing decisions. App name, subtitle, description, keywords, screenshots, and the privacy policy URL (see `app-store-listing.md`).
7. Publish the singhsec.com pages. Done 2026-11-18: support page live at https://labelcheck.singhsec.com/labelcheck-support and privacy policy live at https://labelcheck.singhsec.com/labelcheck-privacy, both fetched and verified.
8. Real app icon. Done 2026-11-18: real 1024×1024 icon in `Assets.xcassets/AppIcon.appiconset` (white barcode + checkmark on leaf-green accent, all sizes).

## Costs, Year 1

| Item | Cost |
| --- | --- |
| Apple Developer Program, Individual | $99 per year |
| GitHub Actions, private repo (2,000 free min/mo; macOS bills 10x) | $0 if usage stays inside the free tier |
| Open Food Facts API v3 | $0 (no key, rate limits per IP) |
| Fastlane, XcodeGen | $0, open source |
| **Total, Year 1** | **About $99** |

Apple's commission is separate and comes out of sales, not out of pocket: 15 percent under the Small Business Program, 30 percent without it. On a $9.99 year, that is $1.50 or $3.00 to Apple.

## Privacy

- No account, no analytics SDK, no ads, no server. Scan history and allergen profiles stay on the device in SwiftData.
- The only network calls are to Open Food Facts: the scanned barcode to fetch that product's data, and, on a D/E product card, the product's category to fetch same-category products with a higher Nutri-Score. Barcode lookups are cached in memory, and each scanned product's full details are cached on the device in SwiftData, so re-scans and History work with no signal.
- Camera images and label photos are processed on-device (Vision, Natural Language, Foundation Models) and never leave the phone.
- StoreKit transactions are handled by Apple. The app never sees a card number.
- Do not add analytics, crash reporting, or ads in v1. Each one is a privacy disclosure and a review risk, and none of them is needed to learn whether the scanner works.

## Honest expectations

Most indie apps earn very little, and food scanning is a saturated market with a strong free incumbent (see `VALIDATION.md`). LabelCheck was picked because it is the only concept that satisfies both halves of the brief — a verified commercial-safe no-key public API plus real on-device ML — and because it is the simplest build, not because success is likely. Build it well, ship it, learn from real users, and let the numbers decide whether app 3 is worth the time.
