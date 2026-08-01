# Releasing

GitHub Releases are created only when a new SemVer tag such as `v1.2.3` is
pushed. The tagged commit must already be reachable from `main`; tags on
`develop/v2` or another branch are rejected.

After the release candidate has passed its live WoW smoke-test, merge the
approved commit into `main`, push `main`, then create and push an annotated
tag on that commit:

```text
git tag -a v1.2.3 -m "v1.2.3"
git push origin v1.2.3
```

The release workflow validates the tag format, confirms the tag commit is in
`origin/main`, refuses an existing GitHub Release, builds with BigWigs
Packager, validates the resulting ZIP, and creates one immutable GitHub
Release. The Packager replaces `@project-version@` in the packaged TOC with
the exact tag value, so the release ZIP contains `## Version: v1.2.3`.

The uploaded ZIP is the WowUp source. Its only files are the installable
`ShadowWordDeathExecute/` addon directory, TOC, runtime Lua, and locale Lua
files; development files are excluded by `.pkgmeta`.

CurseForge and Wago are intentionally not enabled yet. To enable them later,
add the real project IDs and the GitHub Actions secrets `CF_API_TOKEN` and
`WAGO_API_TOKEN`, then explicitly add the corresponding Packager upload
arguments. Do not add placeholder IDs or secrets.
