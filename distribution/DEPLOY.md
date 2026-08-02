# Deployment setup

This document prepares publication for `Shadow Word: Death Execute`. It does
not authorize a tag, a GitHub Release, or an upload by itself.

## 1. Create the project pages

CurseForge is required for a production release. Create its project owned by
`znoynext`, using the ready listing text in
[marketplace-submission.md](marketplace-submission.md):

1. CurseForge — copy its numeric project ID from the project page.
2. Optionally, create Wago Addons and copy its project ID from the developer
   dashboard.
3. Optionally, create WoWInterface and copy the numeric addon ID from its URL
   (`info<ID>-...`).

Keep the IDs out of the TOC and source code. They are repository configuration,
not addon metadata. The project license is **All Rights Reserved**; do not mark
the project as open source or grant redistribution, forks, or modifications.

## 2. Configure GitHub Actions

In **Settings → Secrets and variables → Actions → Variables**, add the real
values below:

| Repository variable | Value |
| --- | --- |
| `CF_PROJECT_ID` | CurseForge project ID |
| `WAGO_PROJECT_ID` | Wago Addons project ID (optional) |
| `WOWI_PROJECT_ID` | WoWInterface addon ID (optional) |

In **Settings → Secrets and variables → Actions → Secrets**, add the API tokens:

| Secret | Used for |
| --- | --- |
| `CF_API_TOKEN` | CurseForge upload API |
| `WAGO_API_TOKEN` | Wago Addons upload API (optional) |
| `WOWI_API_TOKEN` | WoWInterface upload API (optional) |

The CurseForge secret is deliberately mapped to BigWigs Packager's internal
`CF_API_KEY` environment variable only inside the release job. Tokens are never
stored in this repository or printed by the workflow.

For the scheduled Interface updater, in **Settings → Actions → General** set
workflow permissions to **Read and write permissions** and enable **Allow
GitHub Actions to create and approve pull requests**. The workflow uses those
permissions solely to open a temporary PR with the TOC change; it never merges
the PR itself.

## 3. Normal development flow

Pushes and pull requests to `main` run Development CI only. It checks Lua,
formatting, model/static/package invariants, and uploads an installable RC ZIP
artifact. It does not upload to any marketplace.

Once per day, the Interface updater checks the Retail and PTR values and, when
needed, opens `automation/interface-version` against `main`. Review the TOC
diff and PR CI; merge it normally. The temporary branch is deleted afterwards.

The current TOC contains comma-separated Retail and PTR values. Future values
are maintained by that PR workflow rather than guessed manually.

## 4. Publish a stable version

After the release commit is on a green `main` and the owner approves it:

```text
git checkout main
git pull --ff-only origin main
git tag -a v1.3.0 -m "v1.3.0"
git push origin v1.3.0
```

Only `vMAJOR.MINOR.PATCH` tags from `main` are accepted. The release job:

1. verifies the tag format, `main` ancestry, CurseForge configuration, and the
   absence of an existing GitHub Release;
2. builds a dry-run ZIP with BigWigs Packager and validates it with
   `scripts/validate_addon.py`, including the exact version substituted from
   `@project-version@`;
3. uses the same validated Packager staging directory to upload to CurseForge;
   Wago Addons and WoWInterface are uploaded only when each has both its ID and
   API token configured;
4. confirms the final ZIP still has the validated SHA-256, then creates the
   GitHub Release without replacing any existing release or asset.

WowUp consumes the GitHub Release ZIP. Existing WoWInterface downloads are
archived rather than overwritten (`wowi-archive-previous: yes`).

If the CurseForge ID or token is missing, the job stops before packaging or
publication with `CurseForge: required configuration missing`. If either
optional service is incomplete, its upload is skipped and does not block the
CurseForge or GitHub release. Do not add placeholders to bypass the check.

## Compatibility scope

Retail and PTR compatibility metadata are updated automatically, but an
Interface number is not a gameplay compatibility guarantee. Review each updater
PR and run the normal live smoke test before a release when Blizzard changes
the client/API.

Classic clients are not supported by this addon today. They use different
runtime/API contracts, so a future Classic version requires a separate
compatibility review and live test before adding a Classic Interface value or
publishing it as compatible.
