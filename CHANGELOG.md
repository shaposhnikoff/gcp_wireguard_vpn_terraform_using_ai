# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The current version lives in `VERSION` and is bumped by one patch for every
merged pull request.

## [0.0.1] - 2026-10-19

### Added

- WireGuard VPN gateway on Google Cloud: dedicated VPC, static external IP,
  Shielded Debian VM, OS Login and SSH restricted to explicit CIDR ranges.
- First-boot bootstrap that generates WireGuard keys, configures NAT and stores
  client configurations in Secret Manager.
- Terraform tests with mocked providers, TFLint, Checkov and a verification
  report in every GitHub Actions run.
- Offline Terraform plan on pull requests with artifacts and a unified diff
  against the previous plan of the same pull request.
- Pull-request-only workflow for `main` with required status checks.
- Version and changelog enforcement in CI.
