# Marketplace submission: Shadow Word: Death Execute

This file prepares the v1.3.0 listing text only. It does not authorize a tag,
a GitHub Release, an upload, or marketplace publication.

## Publication configuration

| Value | Configured value |
| --- | --- |
| CurseForge project ID | `1635549` |
| Wago Addons project ID | `Q6aRxaKW` |
| License | All Rights Reserved |

CurseForge and Wago Addons automated uploads require their configured GitHub
Actions variables and secrets. A new SemVer tag from `main` publishes to both
services and creates the GitHub Release used by WowUp. See
`distribution/DEPLOY.md` for the exact setup and release sequence.

## Shared listing text

### Name

Shadow Word: Death Execute

### Summary

A lightweight Shadow Word: Death execute indicator for World of Warcraft Retail Priests.

### Full description

Shadow Word: Death Execute is a focused World of Warcraft Retail addon for
Priests. It displays Shadow Word: Death only when you are in combat, your
current target is hostile and alive, the target is at 20% health or lower, and
the spell is available.

The indicator ignores the global cooldown by itself, but hides during Shadow
Word: Death's own cooldown. It remains available when one charge can still be
used while another charge recharges. Compact slash-command settings include
manual Position X/Y fields, independent Size X/Y fields for square or
rectangular icons, Lock, Test, optional Blizzard glow, and Reset. Existing
single-size settings automatically migrate to equal width and height values.

The addon is event-driven, includes enUS and ruRU localization, and has no
external runtime libraries.

### Features

- Combat-only Shadow Word: Death execute indicator.
- Hostile living target and 20% execute threshold checks.
- Own cooldown and charge-aware spell availability.
- Global cooldown alone does not hide a ready indicator.
- Manual Position X/Y controls.
- Independent Size X/Y controls for square or rectangular icons.
- Automatic migration from the former single saved size.
- Optional built-in Blizzard glow.
- enUS and ruRU localization.
- Event-driven operation with no external runtime libraries.

### Installation

1. Download the release ZIP for v1.3.0.
2. Extract the ShadowWordDeathExecute folder.
3. Place it in World of Warcraft/_retail_/Interface/AddOns.
4. Restart World of Warcraft or run /reload.
5. Use /swd to open the settings.

### Changelog: v1.3.0

- Added manual Position X/Y controls.
- Replaced the size slider with separate Size X/Y controls.
- Added migration from the former single saved size to equal width and height.
- Simplified glow to one optional Blizzard glow checkbox.
- Added enUS and ruRU localization.
- Improved CI, package validation, and fail-closed runtime error reporting.

### Repository and support

- Repository: https://github.com/znoynext/ShadowWordDeathExecute
- Issue tracker: https://github.com/znoynext/ShadowWordDeathExecute/issues

## Per-marketplace fields

### CurseForge

| Field | Value |
| --- | --- |
| Project name | Shadow Word: Death Execute |
| Summary | A lightweight Shadow Word: Death execute indicator for World of Warcraft Retail Priests. |
| Description | Use Full description above. |
| Features | Use Features above. |
| Installation | Use Installation above. |
| Changelog | Use Changelog: v1.3.0 above. |
| Suggested categories | Combat; Class & Role Specific -> Priest |
| Suggested tags | WoW Retail, Priest, Shadow Word: Death, Execute, Combat |
| Source repository | https://github.com/znoynext/ShadowWordDeathExecute |
| Issue tracker | https://github.com/znoynext/ShadowWordDeathExecute/issues |
| License | All Rights Reserved |

### Wago Addons

| Field | Value |
| --- | --- |
| Project name | Shadow Word: Death Execute |
| Summary | A lightweight Shadow Word: Death execute indicator for World of Warcraft Retail Priests. |
| Description | Use Full description above. |
| Features | Use Features above. |
| Installation | Use Installation above. |
| Changelog | Use Changelog: v1.3.0 above. |
| Suggested categories | Combat; Priest/Class-specific, if the form offers it |
| Suggested tags | Retail, Priest, Shadow Word: Death, Execute, Combat |
| Source repository | https://github.com/znoynext/ShadowWordDeathExecute |
| Issue tracker | https://github.com/znoynext/ShadowWordDeathExecute/issues |
| License | All Rights Reserved |

## Screenshots the owner should capture

Capture current WoW Retail screenshots without unrelated UI clutter or personal
chat or character information:

1. Execute-ready icon in combat against a hostile target at 20% health or lower.
2. Slash-command settings with Test enabled, showing manual Position X/Y and Size X/Y fields.
3. A rectangular icon with Blizzard glow enabled, showing that both settings coexist.
4. The ruRU settings window, if practical, to demonstrate localization and label layout.

Use the first two as the minimum listing screenshots. The glow and ruRU
screenshots are recommended supporting images.
