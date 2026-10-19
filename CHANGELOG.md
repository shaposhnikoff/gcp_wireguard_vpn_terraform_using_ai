# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The current version lives in `VERSION` and is bumped by one patch for every
merged pull request.

## [0.0.8] - 2026-10-19

### Changed

- Add a direct link to the GitHub Pages documentation site at the top of the
  README.

## [0.0.7] - 2026-10-19

### Added

- GitHub Pages documentation site built with MkDocs Material and deployed by
  the `Documentation` workflow.

## [0.0.6] - 2026-10-19

### Added

- CI status, release and Terraform version badges on the README landing page.

## [0.0.5] - 2026-10-19

### Changed

- Show the plan diff in a collapsible block at the bottom of the verification
  report, after the gate table and before the commit metadata.

## [0.0.4] - 2026-10-19

### Fixed

- Compare plans against the previous successful run on `main` for post-merge
  runs, so the report shows a real diff instead of `no base plan`.
- Label the PR-only previous-push diff as `n/a on main` when running on `main`.

## [0.0.3] - 2026-10-19

### Added

- ICMP diagnostics ingress rule restricted to the same administrative CIDR
  ranges as SSH.

## [0.0.2] - 2026-10-19

### Changed

- Upgrade GitHub Actions to Node.js 24 runtimes: `actions/checkout@v7`,
  `hashicorp/setup-terraform@v4`, `actions/upload-artifact@v7`,
  `actions/download-artifact@v8`, `actions/github-script@v9` and
  `terraform-linters/setup-tflint@v6.3.2`.
- Pin workflows to the `ubuntu-24.04` runner image instead of the moving
  `ubuntu-latest` label.

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
- Makefile targets to inspect the latest tag, create annotated tags and publish
  GitHub releases with notes taken from this changelog.
