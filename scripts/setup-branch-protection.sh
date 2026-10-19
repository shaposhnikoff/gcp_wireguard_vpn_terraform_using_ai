#!/usr/bin/env bash
#
# Enable PR-only flow on main and require the Terraform check suite.
# Requires admin rights on the repository.
#
set -euo pipefail

REPO="${1:-}"

if [[ -z "${REPO}" ]]; then
  REMOTE="$(git remote get-url origin)"
  REPO="$(sed -E 's#^git@github.com:##; s#^https://github.com/##; s#\.git$##' <<< "${REMOTE}")"
fi

echo "Configuring branch protection for ${REPO} (main)"

gh api -X PUT "repos/${REPO}/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Format",
      "Terraform plan",
      "Validate and test (Terraform 1.9.8)",
      "Validate and test (Terraform 1.15.6)",
      "TFLint",
      "Security scan (Checkov)"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true
}
JSON

echo "Branch protection applied."
