# PitchLab App Store submission plan

- [ ] Add a manual macOS archive workflow. Select Xcode 26+, check the iPhone SDK and archive the Release scheme without signing for preflight. Keep the existing test IPA separate.
- [ ] Implement StoreKit 2 entitlement evaluation and verified transaction reconciliation. Test 168-hour boundary, purchase precedence, revocation and temporary offline state before wiring the paywall.
- [ ] Gate practice entry points without blocking score browsing or removing saved progress. Verify capture stops on expiry and add sandbox tests for restore and canceled transactions.
- [ ] Add English and Simplified Chinese resource tables, permission text, and settings with support email and privacy URL. Check both languages with simulator tests.
- [ ] Prepare icon, screenshots, support and privacy pages, reviewer sample, store listing and data disclosure. Confirm privacy declarations against the final binary and dependencies.
- [ ] In the account owner's team, register the bundle ID, create the app and both non-consumables, complete agreements, set localized pricing and territory availability, and sign the build for App Store distribution.
- [ ] Upload the signed build, verify it on TestFlight, then submit the exact tested build and both products for review.
