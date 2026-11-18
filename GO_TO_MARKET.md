# LabelCheck — Go to Market

## Positioning

"Scan any packaged food, know what's in it in 2 seconds, privately."

One sentence, one job. The differentiator is not the scan — Yuka does that free — it is privacy: no account, no ads, no tracking, everything on the phone except the barcode lookup. Say that in every listing line. Do not claim to be better than Yuka at data coverage; Open Food Facts is the same open database anyone can use, and the listing must not pretend otherwise.

## Channels — ASO first

- App Store Optimisation first: name, subtitle, keywords, screenshots (see `app-store-listing.md`). The 7 CI screenshots are the listing screenshots.
- Product-as-marketing: shareable product cards (v1.1) — a scanned product shared by a user is the ad.
- Channels NOT used: LinkedIn cyber audience, Reddit promotion, Google Ads. Apple Search Ads only on Aman's call, and only after the listing converts from organic traffic.
- No spend authorised. No paid acquisition until the 90-day gate is passed (below).

## Launch checklist

1. Real app icon in `Assets.xcassets/AppIcon.appiconset` (placeholder in v1).
2. Support page live: https://labelcheck.singhsec.com/labelcheck-support
3. Privacy policy live: https://labelcheck.singhsec.com/labelcheck-privacy (text in `privacy-policy.md`)
4. Apple Developer enrolment ($99) + App Store Connect app created with bundle ID `com.singhsec.labelcheck` (only Aman).
5. Paid Apps Agreement accepted; Small Business Program applied for (15% commission).
6. StoreKit products created in App Store Connect: `labelcheck_pro_yearly` $9.99/year, `labelcheck_pro_lifetime` $19.99 (see `SUBSCRIPTION_PLAN.md`).
7. TestFlight internal build installed and used for a week of real scanning.
8. CI archive job wired (Fastlane Match) once signing secrets exist; until then the archive job exits cleanly by design.
9. Submit with the listing in `app-store-listing.md`. Do not submit with placeholder screenshots or placeholder URLs — Apple rejects those.

## The 90-day gate

90 days after launch, look at two numbers: weekly active scanners, and Pro conversions.

- If weekly active scanners are near zero and Pro conversion is zero, stop. Do not add features to save it, do not buy ads to save it. The free core stays live for existing users; no app follows from this one on the strength of hope.
- If scanning is real but conversion is zero, the price or the Pro split is wrong — re-validate pricing before adding features.
- Only if both numbers are real does the v1.1 list in `ROADMAP.md` get built.

## What needs Aman (again, in one place)

Apple Developer enrolment ($99, 1–2 days) is the critical path: without it there is no TestFlight and no submission, and nothing else on the checklist can be tested end to end. Start it first. The Hostinger subdomain pages (support + privacy) are second — they must be live before submission, and they need the mailbox/password work already tracked for Clear Days.
