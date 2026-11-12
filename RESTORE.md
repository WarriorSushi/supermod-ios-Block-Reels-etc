# Restore this development snapshot

This archive preserves the current app source, bundled media/artwork, Xcode project and shared schemes, pinned Swift package resolution, XcodeGen specification, local StoreKit configuration, unit/WebKit/UI tests, design sources and sanitized development notes. No external reference recording or raw QA evidence is needed to build it. The sanitized archive passed a fresh Debug simulator build with code signing disabled and a Gitleaks credential scan before upload.

## Build

Validated toolchain at archival: Xcode 27.2 (27B52), Swift 5 language mode, iOS deployment target 17.0. Use a compatible current Xcode supporting the bundled Icon Composer assets. Internet access is needed to restore RevenueCat 5.102.3 via Swift Package Manager.

```sh
git clone https://github.com/WarriorSushi/supermod-ios-Block-Reels-etc.git
cd supermod-ios-Block-Reels-etc
shasum -a 256 -c ARCHIVE-SHA256SUMS.txt
open Supermod.xcodeproj
```

Select the **Supermod** scheme and an installed iPhone simulator. Run from Xcode. This Debug scheme enables local StoreKit; use test purchases or **Continue without paying**. A fresh clone has no social logins, usage history or saved preferences.

Command-line simulator build:

```sh
xcodebuild -project Supermod.xcodeproj -scheme Supermod \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/restore CODE_SIGNING_ALLOWED=NO build
```

For tests, replace the destination with an installed simulator ID shown by `xcrun simctl list devices available`, then use `test` instead of `build`. The test suite uses local StoreKit and web fixtures; UI reset flags should only be used on a disposable simulator, never a phone whose app data should be preserved.

`project.yml` allows regeneration with XcodeGen (`xcodegen generate`); XcodeGen is unnecessary for the checked-in project.

## Device signing and optional subscriptions

Choose your Apple development team in Xcode and enable automatic signing. Use a bundle identifier your account controls if needed. Signing certificates and private keys must come from your own secure account storage; they cannot be restored from this public repository.

The `REVENUECAT_PUBLIC_API_KEY` default is deliberately blank in both project.yml and the Xcode project. Local StoreKit/testing access works without it. To reconnect analytics, supply your own public iOS SDK key as a local build setting. Private Apple/IAP keys belong in the provider dashboard, never in the app or Git. See [subscription setup](docs/subscriptions-setup-2026-11-11.md) for product and entitlement mappings. Live Apple sandbox billing was not fully validated before archival.

## Deliberate exclusions

- Build products, package caches, DerivedData, test result bundles and Xcode per-user state: regenerable.
- The entire raw `Evidence/` tree: contains signed-in social screenshots, videos, HTML/debug captures, device logs and old snapshots. Sanitized findings and current tests are retained instead.
- Third-party reference screenshots and the large SocialLite reference recording: research material, not build inputs; omitted from public redistribution.
- Account-specific setup records, device identifiers, local user paths and the public RevenueCat app key: removed or replaced with setup instructions.
- Credentials, tokens, certificates, provisioning profiles, private keys, cookies and app/session data: not included.

The app's bundled artwork, demonstration media and their available provenance notes are retained. The existing repository LICENSE is preserved; third-party assets and SDKs may have separate rights or licenses. This archive does not establish legal clearance for distributing the app or its bundled media. Review service permissions and asset rights before launch.

The archive is sufficient to rebuild the development app, not to recreate private accounts, certificates or signed-in sessions. Historical Evidence links intentionally do not resolve in this public copy. `ARCHIVE-SHA256SUMS.txt` covers the tracked public package except itself. It is refreshed when the source or documentation changes. Contributors can validate it with `python3 scripts/repository_check.py`; see [CONTRIBUTING.md](CONTRIBUTING.md).
