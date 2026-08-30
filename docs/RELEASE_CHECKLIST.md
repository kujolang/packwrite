# Official release checklist

Use this gate for every stable PackWrite GitHub release.

## Prepare

- Confirm the intended SemVer increment from the user-visible changes.
- Update the version in `src/command.kujo`, `kujo.toml`, `packwrite.spec.yml`, the
  README badge, CLI contract tests, security support table, and changelog.
- Move completed changelog entries from `Unreleased` under the dated release heading.
- Confirm `main` is clean, synchronized with `origin/main`, and has no unmerged remote
  branches or open pull requests.

## Verify

```bash
make check
make test
make smoke
make scripts
git diff --check
```

- Confirm `packwrite version` prints the intended version.
- Confirm the full suite remains offline and no live provider credentials are used.
- Push the release-preparation commit and require the hosted CI and artifact guard to
  pass on that exact commit.

## Publish

- Create an annotated `vX.Y.Z` tag at the verified `origin/main` commit.
- Push the tag.
- Publish a non-draft, non-prerelease GitHub Release with concise notes derived from
  `CHANGELOG.md`.
- Verify the release URL, tag target, source archives, and latest-release status.
- Confirm the working tree is still clean and `main` still matches `origin/main`.
