## What changed

<!-- Describe the change in one or two sentences. -->

## Why

<!-- Link the ticket or explain the problem. -->

## Verification

- [ ] `make verify` passes locally
- [ ] Offline plan in the PR comment reviewed
- [ ] `terraform plan` reviewed against the real project, no unexpected destroy or replace
- [ ] New Checkov exceptions are documented in `.checkov.yaml` and below
- [ ] No secrets, credentials, or private keys in the diff

## Risk and rollback

<!-- What can break, and how do we revert it? -->
