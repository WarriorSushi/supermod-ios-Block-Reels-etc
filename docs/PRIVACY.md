# Privacy overview for this development snapshot

This describes the checked-in design, not a finished legal privacy policy for an App Store release.

- Preferences, onboarding answers, timer deadlines and aggregate usage are stored locally by the app. A fresh checkout does not contain anyone's settings or usage history.
- Each social service uses a separate persistent WebKit website-data store. The service handles sign-in and receives traffic from the pages you browse. Its cookies/session data can persist on your device.
- The app does not include a custom social-password database or an account backend. That is not a claim that embedded services cannot collect browsing information under their own policies.
- Filter scripts inspect supported page structure and selected response data locally. Current pagination metadata tracks counts and end/loading state rather than storing post content. Website integration still needs continuing review.
- StoreKit handles subscription transactions. Optional RevenueCat integration can transmit pseudonymous subscription/customer information when configured. Its public app key is blank in this repository, and local test launches skip that integration.
- Settings includes controls to clear website data and local usage. Deleting local data does not delete your account or data held by a social service or payment provider.
- Debug logs, device identifiers, raw web dumps and signed-in screenshots are not appropriate public bug-report attachments. Use synthetic fixtures and redact captures.

The bundled privacy manifest is a development artifact. It must be reviewed against the final binary, enabled SDK behavior and actual distribution before release. No “zero tracking” or anonymous-browsing guarantee is made.
