#!/usr/bin/env bash
#
# Bump the patch version. A matching CHANGELOG entry must be added manually.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CURRENT="$(tr -d '[:space:]' < VERSION)"
IFS=. read -r major minor patch <<< "${CURRENT}"
NEXT="${major}.${minor}.$((patch + 1))"

printf '%s\n' "${NEXT}" > VERSION
echo "Bumped ${CURRENT} -> ${NEXT}"
echo "Add a '## [${NEXT}] - YYYY-MM-DD' section to CHANGELOG.md."
