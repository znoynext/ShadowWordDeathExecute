# Changelog

## Unreleased

- Shows the indicator only when the Shadow Word: Death talent is selected and the spell is usable.

## 1.3.0

- Added manual Position X/Y controls in the `/swd` settings.
- Replaced the size slider with separate manual Size X/Y controls for square or rectangular icons.
- Migrates the former single saved size to equal width and height values.
- Replaced the former glow mode setting with a single Blizzard glow checkbox.
- Migrates existing glow settings to the boolean checkbox setting.
- Hardened runtime handling so unexpected errors fail closed and reach WoW's standard Lua error handler.
- Added English and Russian localization.
- Added CI, model, static, and package validation improvements.
- Added automated Retail/PTR Interface update PRs and immutable tag-based release publishing.
