# LabelCheck — Subscription Plan

## Decision

- **No monthly tier.** The market anchor is $10–20/year (Yuka's core is free, Pro ~$10/year). A $4.99/month price was validated as wrong for this market and is not used anywhere in the app, the storekit file, or the listing.
- **Two products, one Pro entitlement:**
  - `labelcheck_pro_yearly` — auto-renewable subscription, $9.99/year.
  - `labelcheck_pro_lifetime` — non-consumable, $19.99 once (~2 years of yearly).
- **No free trial at launch.** A trial is a lever to test later if yearly conversion is weak; it is not a launch assumption.

## Free vs Pro

| Feature | Free | Pro |
| --- | --- | --- |
| Barcode scans | Unlimited, forever | Unlimited |
| Product card (Nutri-Score, NOVA, allergens, ingredients, nutriments) | Yes | Yes |
| Plain-English label explain (deterministic card) | Yes | Yes |
| On-device AI explain (iOS 26+, iPhone 15 Pro+) | Yes, when available | Yes, when available |
| Scan history | Most recent 10 | Unlimited |
| Allergen profiles | 1 profile | Multiple profiles |
| OCR label explain | No | Yes |
| History export | No | Yes (v1.1) |

The free core always works forever. Pro is depth only — it never gates the scan itself.

## StoreKit

- StoreKit 2 only, serverless. No RevenueCat, no receipt server, no backend.
- Products live in `Resources/LabelCheck.storekit` (sandbox testing, wired into the Run scheme in `project.yml`) and must be created with the exact same IDs in App Store Connect.
- Subscription group: `labelcheck_pro`. Both products unlock the same entitlement; `StoreManager` checks current entitlements for either product ID.
- Test purchases with the sandbox, never with a real Apple ID in a debug build.

## Money

- Apple commission: 15% under the Small Business Program, 30% without it. On $9.99/year that is $1.50 or $3.00 to Apple.
- Paid Apps Agreement + Small Business Program application are on the launch checklist (`GO_TO_MARKET.md`) — only Aman can do them.
