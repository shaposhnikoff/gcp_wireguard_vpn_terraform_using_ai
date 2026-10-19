#!/usr/bin/env bash
#
# Optional security scanners. Each tool is skipped when not installed.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

status=0

if command -v checkov >/dev/null 2>&1; then
  echo "==> checkov"
  checkov -d . --framework terraform --compact || status=1
else
  echo "==> checkov not installed, skipped"
fi

if command -v trivy >/dev/null 2>&1; then
  echo "==> trivy config"
  trivy config --exit-code 1 --severity HIGH,CRITICAL . || status=1
else
  echo "==> trivy not installed, skipped"
fi

if command -v gitleaks >/dev/null 2>&1; then
  echo "==> gitleaks"
  gitleaks detect --no-banner --redact || status=1
else
  echo "==> gitleaks not installed, skipped"
fi

exit "${status}"
