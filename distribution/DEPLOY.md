# Deployment setup

This document prepares publication for `Shadow Word: Death Execute`. It does
not authorize a tag, a GitHub Release, or an upload by itself.

## Marketplace configuration

Stable releases publish to CurseForge and Wago Addons. The configured repository
variables are:

| Repository variable | Value |
| --- | --- |
| `CF_PROJECT_ID` | `1635549` |
| `WAGO_PROJECT_ID` | `Q6aRxaKW` |

The corresponding GitHub Actions secrets must remain configured, but their
values must never be stored in this repository or printed by a workflow:

| Secret | Used for |
| --- | --- |
| `CF_API_TOKEN` | CurseForge upload API; mapped only to Packager's `CF_API_KEY` |
| `WAGO_API_TOKEN` | Wago Addons upload API |

The project license is **All Rights Reserved**. Do not mark the project as open
source or grant redistribution, forks, or modifications.

## Development flow

Pushes and pull requests to `main` run Development CI only. It checks Lua,
formatting, model/static/package invariants, and uploads an installable RC ZIP
artifact. It always uses BigWigs Packager dry-run mode, receives no marketplace
secrets, and never creates a tag, GitHub Release, CurseForge upload, or Wago
upload.

Once per day, the Interface updater checks the Retail and PTR values and, when
needed, opens `automation/interface-version` against `main`. Review the TOC
diff and PR CI; merge it normally. The temporary branch is deleted afterwards.

The current TOC contains comma-separated Retail and PTR values. Future values
are maintained by that PR workflow rather than guessed manually.

## Promote a tested stable version

The required sequence is:

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

After a green push CI and successful versioned simulation RC for the exact
commit, the owner must complete manual WoW testing and explicitly approve the
release with `RELEASE APPROVED`. Codex then manually dispatches **Promote tested
RC** with the SemVer version and full 40-character tested commit SHA.

Create the versioned simulation RC by manually dispatching **Development CI**
with its `simulate_version` input. That run is dry-run packaging only.

The promotion workflow refuses an invalid approval, version, SHA, non-current
`main` commit, missing/expired RC, checksum or package failure, existing tag,
or existing GitHub Release. It creates and pushes only a new annotated tag.
It does not receive marketplace secrets and cannot upload files. It then sends
an internal dispatch to the tag-based release workflow, which fetches and
validates that annotated tag before publication. This dispatch is necessary
because a tag pushed with GitHub Actions' `GITHUB_TOKEN` does not trigger a
second `push` workflow.

Only `vMAJOR.MINOR.PATCH` annotated tags from `main` are accepted. The separate
tag-based release job is the only workflow that receives marketplace secrets.
It:

1. verifies the tag format, `main` ancestry, both marketplace configurations,
   and the absence of an existing GitHub Release;
2. runs syntax, model, lint, formatting, and static release checks;
3. builds a dry-run ZIP with BigWigs Packager and validates it with
   `scripts/validate_addon.py`, including the exact version substituted from
   `@project-version@`;
4. calculates the ZIP SHA-256, reuses the validated Packager staging directory,
   uploads to CurseForge and Wago Addons, and verifies the ZIP again;
5. creates one immutable GitHub Release with the verified ZIP.

WowUp uses the GitHub Release ZIP. After the first stable GitHub Release, open
**Get Addons** in WowUp, choose **Install from URL**, and enter:

```text
https://github.com/znoynext/ShadowWordDeathExecute
```

If a required project ID or token is missing, the tag-based job stops before
packaging or publication with a clear configuration error. Do not add
placeholders to bypass the check.

## Compatibility scope

Retail and PTR compatibility metadata are updated automatically, but an
Interface number is not a gameplay compatibility guarantee. Review each updater
PR and run the normal live smoke test before a release when Blizzard changes
the client/API.

Classic clients are not supported by this addon today. They use different
runtime/API contracts, so a future Classic version requires a separate
compatibility review and live test before adding a Classic Interface value or
publishing it as compatible.
