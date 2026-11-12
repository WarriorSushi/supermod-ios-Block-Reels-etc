# Subscription setup for restoration

Account-specific configuration was removed for this public archive.

- Bundle ID: `app.supermod.ios`.
- StoreKit products: `app.supermod.ios.monthly` and `app.supermod.ios.annual`.
- RevenueCat SDK: 5.102.3; entitlement: `supermod_pro`; offering: `default`; packages: `$rc_monthly` and `$rc_annual`.
- `Supermod` scheme uses local Xcode StoreKit and `SUPERMOD_LOCAL_STOREKIT=1`. Local testing does not require RevenueCat credentials.
- `Supermod Sandbox` scheme omits local StoreKit overrides. Apple sandbox purchase/restore and production billing were not fully validated.
- To reconnect a RevenueCat project, supply its public iOS SDK key through `REVENUECAT_PUBLIC_API_KEY`. The archived default is empty. Never put secret keys in source control or the app bundle.
- Select your own Apple development team for physical-device signing. Keep certificates, provisioning profiles, Apple private keys and account records outside this repository.
- Reconfigure App Store Connect products, availability, agreements and RevenueCat store mappings in the relevant dashboards before release. Private account state is not part of this backup.

StoreKit remains the authority for access. RevenueCat integration records subscription analytics when configured. Debug testing access does not create a paid entitlement.
