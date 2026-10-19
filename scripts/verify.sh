#!/usr/bin/env bash
#
# Local verification gate for the WireGuard gateway module.
# Fails on formatting, schema, and test regressions. Optional scanners run
# when their binaries are present.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "==> terraform fmt"
terraform fmt -check -recursive

echo "==> terraform init (local backend)"
terraform init -backend=false -input=false

echo "==> terraform validate"
terraform validate

echo "==> terraform test"
terraform test

if command -v tflint >/dev/null 2>&1; then
  echo "==> tflint"
  tflint --init
  tflint --recursive
else
  echo "==> tflint not installed, skipped"
fi

if command -v checkov >/dev/null 2>&1; then
  echo "==> checkov"
  checkov -d . --framework terraform --compact --quiet
else
  echo "==> checkov not installed, skipped"
fi

echo "Verification gate passed."
