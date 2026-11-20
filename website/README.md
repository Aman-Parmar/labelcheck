# LabelCheck website pages

Static HTML only, no server code, no tracking, no external dependencies.

## Files

- `labelcheck-support.html` - upload to labelcheck.singhsec.com as `/labelcheck-support`
- `labelcheck-privacy.html` - upload to labelcheck.singhsec.com as `/labelcheck-privacy`

These are the exact URLs in App Store Connect (see `app-store-listing.md`):
- Support: https://labelcheck.singhsec.com/labelcheck-support
- Privacy: https://labelcheck.singhsec.com/labelcheck-privacy

The privacy page text matches `privacy-policy.md` in the repo root. The support
page contact is support@singhsec.com, the same address the privacy policy
publishes. That address must exist as a Hostinger email forwarder to Aman's
Gmail before submission, or support mail to it will bounce.

Rule (Aman, 2026-11-09): each app gets its own subdomain on singhsec.com.
LabelCheck is labelcheck.singhsec.com. Never touch blogs.singhsec.com.

## Deploy on Hostinger hPanel

Same pattern as Clear Days (`~/workspace/ios-apps/clear-days/website/README.md`).

1. In Hostinger hPanel, create subdomain labelcheck.singhsec.com on the same hosting plan as blogs.singhsec.com, with SSL on. Do not change blogs.singhsec.com in any way.
2. Use File Manager, go to the document root for labelcheck.singhsec.com (not public_html for the apex, not the blogs subdomain folder).
3. Upload both HTML files there, with these exact filenames. If Hostinger serves `.html` files directly, you may need a redirect or rename to `labelcheck-support/index.html` and `labelcheck-privacy/index.html` instead, so the clean URLs open:
   - `labelcheck-support.html` must open at https://labelcheck.singhsec.com/labelcheck-support
   - `labelcheck-privacy.html` must open at https://labelcheck.singhsec.com/labelcheck-privacy
   Test both URLs in a browser before submitting to Apple.
4. Before launch, confirm the support email on the support page is the one Aman wants live; if the dedicated alias exists by then, swap it in and re-upload.

## Do not submit until

- Both URLs open in a browser, with the correct content, no error page.
