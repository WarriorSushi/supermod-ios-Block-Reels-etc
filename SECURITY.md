# Security policy

## Report privately

Use [GitHub private vulnerability reporting](https://github.com/WarriorSushi/supermod-ios-Block-Reels-etc/security/advisories/new). Do not put credentials, account data, exploit details or signed-in screenshots in public issues or pull requests.

Include the affected commit, a concise impact description and minimal reproduction steps using synthetic data. Do not test against other people's accounts or data. This project does not offer a bug bounty or guaranteed response time.

## Supported scope

Only the current development branch receives fixes. There is no stable release series or security-support commitment yet. This policy covers Supermod's code, not the security of the external social services.

## If you expose a credential

Revoke or rotate it at its provider first. Removing a file, rewriting Git history or making a repository private does not invalidate the credential or erase copies. Check provider access logs and update affected deployments. Coordinate any history rewrite with collaborators.

The archive intentionally excludes signing material, private API keys, social sessions, raw QA logs and account records. The optional RevenueCat public SDK key is blank by default. GitHub scanning and CI are additional checks, not a guarantee of absence.
