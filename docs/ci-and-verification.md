# CI and verification

The workflow lives in `.github/workflows/terraform.yml` and runs on every pull
request, on pushes to `main`, and on manual dispatch. No Google Cloud
credentials are needed: tests use mocked providers and the plan is offline.

## Jobs

| Job | What it does |
|---|---|
| `Format` | `terraform fmt -check -recursive -diff` |
| `Version and changelog` | Requires exactly one patch above `main` and a matching changelog section |
| `Terraform plan` | Runs an offline plan and publishes the plan and diffs |
| `Validate and test` | `init -backend=false`, `validate`, `terraform test` on Terraform 1.9.8 and 1.15.6 |
| `TFLint` | Google ruleset, recursive scan |
| `Security scan (Checkov)` | Blocking scan with documented exceptions |
| `Verification report` | Aggregates everything into the run summary |

There is no `apply` in CI. Production changes are applied manually from a
reviewed plan.

## Offline plan

The plan job runs with:

```text
terraform init -backend=false
terraform plan -refresh=false -lock=false \
  -var-file=envs/ci/terraform.tfvars.json
```

`envs/ci/terraform.tfvars.json` contains fixed fake values. A dummy
`GOOGLE_OAUTH_ACCESS_TOKEN` lets the provider configure without real
credentials; no API calls are expected because refresh is disabled and the
state is empty.

The result validates the resource graph and shows the diff against empty
state. It does not detect drift, API permissions or quotas.

## Plan diffs

Two comparisons are produced:

- **Changes since main** on pull requests: downloads the latest successful
  `terraform-plan` artifact from the base branch.
- **Changes since previous run** on `main`: compares with the previous
  successful run on `main`.
- **Changes since previous PR push**: extracts the previous plan from the bot
  comment on the same pull request.

Artifacts include `plan.txt`, `plan.log`, `tfplan`, `plan.diff`,
`plan-diff-stat.txt`, `plan-base.diff` and `plan-base-diff-stat.txt`. They are
kept for five days.

Values that are unknown until apply, such as the startup script containing the
not-yet-created static IP, do not appear in diffs.

## Verification report

The `Verification report` job runs with `if: always()` and writes to the run
summary:

- a gate table with statuses and short statistics;
- the plan result and diff counters;
- the test results parsed from uploaded logs;
- a collapsible full diff below the table, before the commit metadata.

The report itself does not block merges; the individual jobs do.

## Required checks

`main` is protected. A pull request can merge only after:

- `Format`
- `Version and changelog`
- `Terraform plan`
- `Validate and test (Terraform 1.9.8)`
- `Validate and test (Terraform 1.15.6)`
- `TFLint`
- `Security scan (Checkov)`

Branch protection also requires linear history and forbids force pushes and
deletions. The configuration is reproduced by
`scripts/setup-branch-protection.sh`.

## Running checks locally

```bash
make verify
```

This runs formatting, the version check, `init -backend=false`, `validate`,
`terraform test`, and optional `tflint` and `checkov` when installed.

```bash
make security
```

Runs `checkov`, `trivy config` and `gitleaks` when available.
