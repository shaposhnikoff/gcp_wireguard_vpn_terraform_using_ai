## What changed

<!-- Describe the change in one or two sentences. -->

## Why

<!-- Link the ticket or explain the problem. -->

## Verification

- [ ] `make verify` passes locally
- [ ] `VERSION` bumped and `CHANGELOG.md` has an English entry
- [ ] Offline plan and plan diff in the PR comment reviewed
- [ ] `terraform plan` reviewed against the real project, no unexpected destroy or replace
- [ ] New Checkov exceptions are documented in `.checkov.yaml` and below
- [ ] No secrets, credentials, or private keys in the diff

## Risk and rollback

<!-- What can break, and how do we revert it? -->
