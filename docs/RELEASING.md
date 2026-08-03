# Releasing

`main` is the only permanent branch. Every push to it runs Development CI and
creates an RC ZIP artifact only; it never creates a tag, GitHub Release, or
marketplace upload.

## Tested RC promotion flow

```text
push main
→ Development CI
→ versioned simulation RC
→ manual WoW test
→ RELEASE APPROVED
→ Promote tested RC
→ annotated tag
→ GitHub Release + CurseForge + Wago
→ WowUp through the GitHub Release
```

Manual WoW testing is mandatory. Only after the owner has explicitly supplied
`RELEASE APPROVED` may Codex manually dispatch **Promote tested RC** with the
SemVer version and full SHA of the tested RC. That workflow requires a green
push CI, a successful non-expired versioned simulation artifact, a valid RC ZIP
and checksum, and that `origin/main` still points to that exact commit.

The versioned simulation is a manual **Development CI** dispatch with its
`simulate_version` input. It is still dry-run packaging and never publishes.

The promotion workflow creates one annotated tag and pushes only that new tag.
It cannot create commits, change `main`, replace a tag, create a GitHub Release,
or upload to marketplaces. The separate tag-based release workflow handles
publication after the tag exists. Because a tag pushed with GitHub Actions'
`GITHUB_TOKEN` does not itself trigger another `push` workflow, promotion sends
one internal `promote-tested-rc` dispatch after the successful tag push. The
release workflow still fetches and validates the immutable annotated tag before
it can use marketplace secrets.

CurseForge and Wago Addons are the required marketplace destinations. Their
repository variables and API-token secrets are described in
[`distribution/DEPLOY.md`](../distribution/DEPLOY.md). Never place project IDs
or API tokens in the TOC or source files.

The workflow runs syntax, model, lint, formatting, and static release checks.
It then performs a BigWigs Packager dry-run and validates the installable ZIP,
including that `@project-version@` became the exact tag. The upload pass reuses
that validated staging directory, uploads the ZIP to CurseForge and Wago
Addons, and verifies its SHA-256 again. It then creates one GitHub Release
without replacing releases or assets. The GitHub Release ZIP is the WowUp source.

The scheduled Interface updater opens a reviewable PR against `main`; it does
not change compatibility metadata directly on the default branch or create a
public release. Review its diff, Development CI, versioned RC, and manual WoW
test before a separate approved promotion.
