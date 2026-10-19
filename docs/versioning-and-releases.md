# Versioning and releases

The project uses semantic versioning with an explicit version file and an
English changelog.

## Files

| File | Purpose |
|---|---|
| `VERSION` | Current version, for example `0.0.6` |
| `CHANGELOG.md` | Keep a Changelog format, English entries |
| `Makefile` | Version, tag and release commands |

## One patch per pull request

`main` uses squash merges, so one merged pull request equals one commit. The CI
job `Version and changelog` enforces:

- `VERSION` must be exactly one patch above `origin/main`;
- `CHANGELOG.md` must contain a `## [x.y.z]` section for that version.

Example: `main` is at `0.0.6`, so the next pull request must ship `0.0.7` and a
`## [0.0.7]` section. The first versioned change is `0.0.1`.

Bump the version with:

```bash
make version-bump
```

Then add an English entry to `CHANGELOG.md` and run `make verify`.

## Inspecting versions

```bash
make version
```

Shows the latest Git tag (through `git describe --tags --abbrev=0`) and the
value from `VERSION`. They normally match after a release.

## Tags

```bash
make tag
```

Creates an annotated `v$(VERSION)` tag and pushes it. The script refuses to run
when the working tree is dirty, the branch is not `main`, `main` is behind
`origin/main`, the changelog section is missing, or the tag already exists.

## Releases

```bash
make release
```

Does everything `make tag` does and then publishes a GitHub Release with notes
extracted from the matching `CHANGELOG.md` section:

```text
https://github.com/shaposhnikoff/gcp_wireguard_vpn_terraform_using_ai/releases/tag/v0.0.6
```

If the tag exists but the release does not, `make release` creates only the
release. If both exist, it fails. Release notes are generated from the
changelog, not from commit messages.

## Recommended flow

1. Open a pull request that bumps `VERSION` and updates `CHANGELOG.md`.
2. Wait for all required checks and review the plan diff.
3. Squash merge.
4. Check out `main`, pull, and run `make release`.
5. Verify the release page and the badge on the README.
