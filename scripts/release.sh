#!/usr/bin/env bash
#
# Create an annotated tag and, optionally, a GitHub release for VERSION.
#
# Usage:
#   ./scripts/release.sh tag      # tag only
#   ./scripts/release.sh release  # tag plus GitHub release from CHANGELOG.md
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

MODE="${1:-release}"
case "${MODE}" in
  tag|release) ;;
  *) echo "Usage: $0 [tag|release]" >&2; exit 2 ;;
esac

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -z "$(git status --porcelain)" ]] || fail "working tree is not clean"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "releases are created from main"

./scripts/check-version.sh
VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v${VERSION}"

git fetch --tags origin
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] \
  || fail "main is not up to date with origin/main"

NOTES_FILE="$(mktemp)"
trap 'rm -f "${NOTES_FILE}"' EXIT

awk -v version="${VERSION}" '
  $0 ~ "^## \\[" version "\\]" { capture = 1; next }
  capture && /^## \[/ { exit }
  capture { print }
' CHANGELOG.md > "${NOTES_FILE}"

[[ -s "${NOTES_FILE}" ]] || fail "CHANGELOG.md has no content for ${VERSION}"

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  [[ "${MODE}" == "release" ]] || fail "tag ${TAG} already exists"
  gh release view "${TAG}" >/dev/null 2>&1 && fail "release ${TAG} already exists"
  echo "Tag ${TAG} already exists, creating the GitHub release only."
else
  git tag -a "${TAG}" -m "Release ${TAG}"
  git push origin "${TAG}"
  echo "Pushed annotated tag ${TAG}."
fi

if [[ "${MODE}" == "release" ]]; then
  gh release create "${TAG}" \
    --verify-tag \
    --title "${TAG}" \
    --notes-file "${NOTES_FILE}"
fi
