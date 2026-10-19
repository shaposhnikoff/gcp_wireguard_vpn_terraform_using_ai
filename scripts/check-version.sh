#!/usr/bin/env bash
#
# Validate VERSION and its CHANGELOG entry. With --against-base, also require
# the version to be exactly one patch above origin/main.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -f VERSION ]] || fail "VERSION file is missing"
[[ -f CHANGELOG.md ]] || fail "CHANGELOG.md is missing"

CURRENT="$(tr -d '[:space:]' < VERSION)"
[[ "${CURRENT}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION must be semver, got '${CURRENT}'"

grep -q "^## \[${CURRENT}\]" CHANGELOG.md \
  || fail "CHANGELOG.md has no '## [${CURRENT}]' section"

if [[ "${1:-}" == "--against-base" ]]; then
  BASE="$(git show origin/main:VERSION 2>/dev/null || true)"
  if [[ -z "${BASE}" ]]; then
    [[ "${CURRENT}" == "0.0.1" ]] \
      || fail "the first versioned change must be 0.0.1, got ${CURRENT}"
  else
    IFS=. read -r base_major base_minor base_patch <<< "${BASE}"
    expected="${base_major}.${base_minor}.$((base_patch + 1))"
    [[ "${CURRENT}" == "${expected}" ]] \
      || fail "expected ${expected} (one patch above main), got ${CURRENT}"
  fi
fi

echo "Version ${CURRENT} is consistent with CHANGELOG.md"
