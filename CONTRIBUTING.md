# Contributing to Supermod

Thanks for helping make social browsing more deliberate. This is an experimental project: clear bug reports, small fixes and honest device observations are especially useful.

## Before you start

Read the [README](README.md), [restore guide](RESTORE.md) and [roadmap](docs/ROADMAP.md). For a substantial feature or architecture change, open a proposal first so the approach can be discussed. For a small, reproducible bug, a focused pull request is welcome.

Use an iPhone simulator for development. Never run reset-oriented UI tests against a device containing sessions you want to keep. The local StoreKit configuration is for testing; do not make production purchases to validate a contribution.

## A useful bug report

Include the app commit, Xcode/iOS version, device or simulator, affected service, active filters, steps, expected result and observed result. Describe whether it happens after refresh or after scrolling. English accessibility labels are currently part of some filter detection, so include the site's language.

Use a synthetic page or the sample preview wherever possible. Remove usernames, faces, posts, messages, cookies, authorization headers, device identifiers and account details from attachments. Never upload a raw signed-in DOM dump or WebKit profile. Security reports belong in [private reporting](SECURITY.md).

## Make a change

1. Fork the repository and create a focused branch.
2. Build using [RESTORE.md](RESTORE.md). Keep account-specific keys and signing settings local.
3. Preserve route, login, dialog and draft safeguards. For feed filters, avoid changing the height of rendered posts or virtual-list spacers during scrolling.
4. Add a regression test for a behavioral fix when it can distinguish the failure from correct behavior. A documentation-only change does not need an iOS test run.
5. Run the relevant tests and record what you actually checked. Live-service verification and synthetic WebKit tests are different evidence; label them accurately.
6. Refresh and validate the file manifest:

   ```sh
   git add .
   python3 scripts/repository_check.py --update-manifest
   git add ARCHIVE-SHA256SUMS.txt
   python3 scripts/repository_check.py
   git diff --cached --check
   ```

7. Open a pull request explaining the problem, resulting behavior, checks and any remaining limitations.

Use a GitHub noreply email if you do not want a personal email in public commit metadata. Do not commit build products, local assistant settings, credentials, logs or raw test evidence.

## License and conduct

By submitting a contribution, you agree that your original contribution is provided under the project's GPLv3 license. Only submit work you have the right to share; identify third-party code or assets and their licenses. No contributor license agreement is required by this repository.

Be respectful, specific and patient. Critique code and ideas, not people. Harassment, personal data disclosure and misleading security claims do not belong here. Maintainers may close off-topic or abusive discussions. There is no guaranteed review timeline.
