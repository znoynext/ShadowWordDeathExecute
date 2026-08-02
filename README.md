# Shadow Word: Death Execute

[English](README.md) | [Русский](README.ru.md)

A lightweight World of Warcraft Retail addon for a Priest character that shows a Shadow Word: Death execute indicator when a hostile target is ready to finish.

## Features

- Shows Shadow Word: Death in execute range.
- Works only in combat and requires a hostile living target.
- Uses the 20% execute threshold.
- Respects Shadow Word: Death's own cooldown.
- Does not hide the indicator because of the global cooldown alone.
- Keeps the indicator available when one charge can still be used while another is recharging.
- Optional Blizzard glow and compact `/swd` settings.
- Manual Position X/Y fields and independent Size X/Y fields for square or rectangular icons.
- Existing single-size settings automatically migrate to equal width and height values.
- English and Russian localization.
- Event-driven, with no external runtime libraries.

## Installation

1. Download the release ZIP.
2. Extract the `ShadowWordDeathExecute` folder.
3. Place it in `World of Warcraft/_retail_/Interface/AddOns`.
4. Restart World of Warcraft or run `/reload`.

## Usage

Use `/swd` to open the compact settings window:

- **Lock** prevents moving the indicator.
- **Test** shows the icon for placement.
- **Position X/Y** set the indicator position manually.
- **Size X/Y** set the icon width and height manually. Square and rectangular sizes are supported.
- **Glow** enables the optional Blizzard glow.
- **Reset** restores the default position and size.

## Execute behavior

Above 20% health, the icon is visually hidden. At 20% health or lower, it is visible when Shadow Word: Death is available. The global cooldown alone does not hide it, but Shadow Word: Death's own cooldown does. A charge that remains available is still treated as usable while another charge recharges.

## Compatibility

Designed for World of Warcraft Retail and Priest characters using Shadow Word: Death. The supported Interface version is defined in the addon TOC (currently `120007`).

## Troubleshooting

- Confirm that the addon is enabled.
- Run `/reload`.
- Check that you have the current addon version.
- Enable Lua errors and include any stack trace in a report.
- Try again with other addons disabled.
- [Open a GitHub issue](https://github.com/znoynext/ShadowWordDeathExecute/issues) if the problem remains.

## License

**License:** All Rights Reserved. Copyright © 2026 znoynext. This project is proprietary;
copying, modifying, distributing, republishing, forking, or creating
derivative works requires prior written permission from znoynext.

## Development

`main` is the only permanent branch. GitHub Actions validates pushes and pull requests to `main`, builds a test ZIP, and opens a reviewable PR when the Retail/PTR Interface values change.
