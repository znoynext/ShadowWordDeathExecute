# Releasing

## Planned target

The next planned version is `v1.3.0`. This document does not authorize creating
the tag or publishing a release.

`main` is the only permanent branch. A release begins only when an annotated
SemVer tag (`vMAJOR.MINOR.PATCH`) is pushed for a commit already in `main`.
The release workflow rejects non-SemVer tags, tags outside `main` history, and
an existing GitHub Release for the same tag.

CurseForge and Wago Addons are the required marketplace destinations. Their
repository variables and API-token secrets are described in
[`distribution/DEPLOY.md`](../distribution/DEPLOY.md). Never place project IDs
or API tokens in the TOC or source files.

After the release commit has passed normal CI and the owner explicitly approves
publication, create the tag from the checked-out `main` commit:

```text
git checkout main
git pull --ff-only origin main
git tag -a v1.3.0 -m "v1.3.0"
git push origin v1.3.0
```

The workflow runs syntax, model, lint, formatting, and static release checks.
It then performs a BigWigs Packager dry-run and validates the installable ZIP,
including that `@project-version@` became the exact tag. The upload pass reuses
that validated staging directory, uploads the ZIP to CurseForge and Wago
Addons, and verifies its SHA-256 again. It then creates one GitHub Release
without replacing releases or assets. The GitHub Release ZIP is the WowUp source.

The scheduled Interface updater opens a reviewable PR against `main`; it does
not change compatibility metadata directly on the default branch. Review its
diff and normal PR CI before merging.
