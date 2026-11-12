# Frequently asked questions

### Is this a replacement Instagram app?

It is a separate browser that opens supported social websites inside Supermod. It does not modify the official apps, your account or other browsers. Features depend on what each website exposes.

### Can I install it from the App Store or TestFlight?

Not currently. This repository provides source for developers and curious testers with a Mac and compatible Xcode. Follow [RESTORE.md](../RESTORE.md). There is no official downloadable IPA in this repository.

### Do I have to pay to try the code?

Debug builds include **Continue without paying** and local StoreKit testing. The source contains subscription/paywall code, but production billing is not ready. Do not make a real purchase to test it. The optional RevenueCat key is blank.

### What is the Scroll timer?

On Home, choose **Set scroll timer**, select the features you want temporarily available and choose 1–60 minutes. When time runs out, those features hide. The deadline continues while you leave the app. You can edit choices without restarting the clock. Ending early hides them immediately.

### What does Lock my filters do?

It prevents changes to Supermod's filter choices for the selected duration. Starting a lock ends a running Scroll timer. It does not lock the phone or prevent you from opening another app.

### Why offer Hide Home feed?

It is an optional way to browse profiles or messages without the Home post stream. Leave it off if you want normal feed browsing. It is separate from hiding suggestions and ads.

### Why do I sometimes see only a few posts?

A batch can contain mostly recommendations or ads. Filtering may leave fewer ordinary posts. Supermod attempts bounded pagination recovery and distinguishes loading, a stall and a confirmed end where the site's data supports it. Pull down at the top of Home to refresh. Network failures and website changes can still interrupt loading.

### Does it remove every ad or recommendation?

No. Recognition is best effort and depends on markup, accessibility labels and response shapes. Some detection assumes English labels. The feed adapter aims to preserve layout during filtering; unknown content may remain visible.

### Can it block the official apps, play background audio or sign into YouTube?

No system-wide app shield is implemented. Background audio is not guaranteed. YouTube support is for public browsing; in-app Google sign-in is not implemented.

### Is it legal or approved by the platforms?

This repository does not establish that. It is independent and experimental. Review service terms, media rights and distribution requirements before release. Apple specifically requires appropriate permission for use of third-party services under [guideline 5.2.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property). Obtain qualified advice for your intended distribution; GPL licensing is not platform approval.

### Where should I report a problem?

Use the [bug-report form](https://github.com/WarriorSushi/supermod-ios-Block-Reels-etc/issues/new?template=bug_report.yml). For credentials or vulnerabilities, follow [SECURITY.md](../SECURITY.md). Remove personal information from all public attachments.
