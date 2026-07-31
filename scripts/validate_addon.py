#!/usr/bin/env python3
"""Small static guardrail for ShadowWordDeathExecute's release-critical invariants."""

from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[1]
ADDON_NAME = "ShadowWordDeathExecute"
ADDON_DIR = ROOT / ADDON_NAME
TOC_NAME = f"{ADDON_NAME}.toc"
LUA_NAME = f"{ADDON_NAME}.lua"
MODEL_CHECKS = ROOT / "scripts" / "model_checks.lua"
LOCALE_FILES = {
    "enUS": "Locales/enUS.lua",
    "ruRU": "Locales/ruRU.lua",
}
REQUIRED_LOCALE_KEYS = {"TITLE", "LOCK", "TEST", "SIZE", "GLOW", "RESET"}
EXPECTED_LOCALES = {
    "enUS": {
        "TITLE": "Shadow Word: Death Execute",
        "LOCK": "Lock",
        "TEST": "Test",
        "SIZE": "Size: %d",
        "GLOW": "Glow",
        "RESET": "Reset",
    },
    "ruRU": {
        "TITLE": "Shadow Word: Death Execute",
        "LOCK": "Закрепить",
        "TEST": "Тест",
        "SIZE": "Размер: %d",
        "GLOW": "Свечение",
        "RESET": "Сбросить",
    },
}

FORBIDDEN_PACKAGE_PARTS = {
    ".git",
    ".github",
    ".agents",
    ".codex",
    "distribution",
    "docs",
    "scripts",
    "tests",
}
FORBIDDEN_PACKAGE_FILES = {
    ".gitignore",
    ".gitattributes",
    ".luacheckrc",
    ".pkgmeta",
    "README.md",
    "README.ru.md",
    "stylua.toml",
}


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def toc_files(toc: Path, errors: list[str]) -> list[str]:
    files: list[str] = []

    for raw_line in toc.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        path = Path(line.replace("\\", "/"))
        if path.is_absolute() or ".." in path.parts:
            fail(errors, f"TOC contains an unsafe relative path: {line}")
            continue
        files.append(path.as_posix())

    if not files:
        fail(errors, "TOC does not list any addon files.")

    return files


def parse_locale(locale: str, errors: list[str]) -> dict[str, str]:
    path = ADDON_DIR / LOCALE_FILES[locale]
    if not path.is_file():
        fail(errors, f"Missing {locale} locale file: {path.relative_to(ROOT)}")
        return {}

    source = path.read_text(encoding="utf-8-sig")
    table_match = re.search(
        rf"addon\.Locales\.{locale}\s*=\s*\{{(?P<body>.*?)^\}}",
        source,
        re.DOTALL | re.MULTILINE,
    )
    if not table_match:
        fail(errors, f"{locale} locale must define addon.Locales.{locale}.")
        return {}

    entries: dict[str, str] = {}
    for entry in re.finditer(
        r'^\s*(?P<key>[A-Z_]+)\s*=\s*"(?P<value>(?:[^"\\]|\\.)*)",?\s*$',
        table_match.group("body"),
        re.MULTILINE,
    ):
        key = entry.group("key")
        if key in entries:
            fail(errors, f"{locale} locale contains duplicate key: {key}")
        entries[key] = entry.group("value")

    return entries


def validate_locales(entries: list[str], runtime: str, errors: list[str]) -> None:
    for locale, filename in LOCALE_FILES.items():
        if filename not in entries:
            fail(errors, f"TOC is missing {locale} locale file: {filename}")

    runtime_index = entries.index(LUA_NAME) if LUA_NAME in entries else -1
    for locale, filename in LOCALE_FILES.items():
        if filename in entries and (runtime_index == -1 or entries.index(filename) > runtime_index):
            fail(errors, f"{locale} locale must load before {LUA_NAME} in the TOC.")

    parsed_locales = {locale: parse_locale(locale, errors) for locale in LOCALE_FILES}
    en_keys = set(parsed_locales["enUS"])
    ru_keys = set(parsed_locales["ruRU"])
    if en_keys != ru_keys:
        fail(errors, "enUS and ruRU locales must use the same key set.")
    for locale, values in parsed_locales.items():
        missing = REQUIRED_LOCALE_KEYS - set(values)
        if missing:
            fail(errors, f"{locale} locale is missing required keys: {', '.join(sorted(missing))}")
        for key, expected in EXPECTED_LOCALES[locale].items():
            if values.get(key) != expected:
                fail(errors, f"{locale} locale has an unexpected value for {key}.")

    if "local _, addon = ..." not in runtime or "local L = addon.Locales[GetLocale()] or addon.Locales.enUS" not in runtime:
        fail(errors, "Runtime Lua must use the private namespace with an enUS locale fallback.")
    if re.search(r"[\u0400-\u04FF]", runtime):
        fail(errors, "Runtime Lua must not contain hardcoded Russian UI labels.")

    localized_markers = {
        "title": "title:SetText(L.TITLE)",
        "lock": "CreateCheckbox(settings, L.LOCK",
        "test": "CreateCheckbox(settings, L.TEST",
        "size": "sizeText:SetText(L.SIZE:format(size))",
        "glow": "CreateCheckbox(settings, L.GLOW",
        "reset": "resetButton:SetText(L.RESET)",
    }
    for description, marker in localized_markers.items():
        if marker not in runtime:
            fail(errors, f"Runtime Lua does not use the locale for the {description} label.")


def validate_source(errors: list[str]) -> None:
    toc = ADDON_DIR / TOC_NAME
    lua = ADDON_DIR / LUA_NAME

    if not toc.is_file():
        fail(errors, f"Missing TOC: {toc.relative_to(ROOT)}")
        return
    if not lua.is_file():
        fail(errors, f"Missing runtime Lua: {lua.relative_to(ROOT)}")
        return

    entries = toc_files(toc, errors)
    for entry in entries:
        if not (ADDON_DIR / entry).is_file():
            fail(errors, f"TOC entry does not exist: {ADDON_NAME}/{entry}")

    source = lua.read_text(encoding="utf-8-sig")
    validate_locales(entries, source, errors)
    required_markers = {
        "slash command": 'SLASH_SHADOWWORDDEATHEXECUTE1 = "/swd"',
        "combat gate": "UnitAffectingCombat(PLAYER_UNIT)",
        "Secret-safe health curve": "C_CurveUtil.CreateColorCurve()",
        "Secret-safe target health": "UnitHealthPercent(TARGET_UNIT, true, executeHealthCurve)",
        "execute threshold": "local EXECUTE_THRESHOLD = 0.20",
        "Blizzard glow template": '"ActionButtonSpellAlertTemplate"',
        "boolean glow setting": "database.glowEnabled",
        "fail-closed initialization guard": "if not addonInitialized then",
        "own cooldown excludes GCD": "cooldownInfo and cooldownInfo.isActive and not spellOnGCD",
        "charge-safe readiness": "return not ownSpellCooldownActive",
        "core callback wrapper": "local function RunCoreCallback(callback, ...)",
        "pre-unwind error reporting": "return xpcall(invoke, ReportCoreError)",
        "Retail stack-aware reporting": "pcall(CallErrorHandler, message)",
        "standard error handler": "pcall(geterrorhandler)",
        "fail-closed error cleanup": "pcall(HideIndicator)",
    }
    for description, marker in required_markers.items():
        if marker not in source:
            fail(errors, f"Missing critical source marker: {description}.")

    if re.search(r"\bSetScript\s*\(\s*['\"]OnUpdate['\"]", source):
        fail(errors, "Runtime Lua must not install a permanent OnUpdate handler.")
    if re.search(r"\bUnitHealth\s*\(", source):
        fail(errors, "Direct UnitHealth use would reintroduce unsafe execute HP arithmetic.")
    if re.search(r"\bUnitHealthMax\s*\([^)]*\)\s*[/\*]", source):
        fail(errors, "UnitHealthMax must not be used for execute HP arithmetic.")
    if re.search(r"return\s+not\s+C_Spell\.GetSpell(?:Cooldown|Charge)Duration", source):
        fail(errors, "DurationObjects must not be treated as readiness booleans.")

    for silent_pattern in (
        "pcall(UpdateIndicator)",
        "pcall(HandleEvent, event, unit)",
        "pcall(ToggleSettings)",
    ):
        if silent_pattern in source:
            fail(errors, f"Core callback errors must reach WoW's handler, not use silent {silent_pattern}.")

    for obsolete_marker in ("GLOW_PULSE", "GLOW_STRONG", "CreatePulseAnimation", "UIDropDownMenu_"):
        if obsolete_marker in source:
            fail(errors, f"Obsolete glow architecture remains: {obsolete_marker}.")

    indicator_start = source.find('local indicator = CreateFrame("Frame", nil, UIParent)')
    early_hide = source.find("indicator:Hide()", indicator_start)
    glow_start = source.find("local glowContainer =", indicator_start)
    if indicator_start == -1 or early_hide == -1 or glow_start == -1 or not indicator_start < early_hide < glow_start:
        fail(errors, "indicator:Hide() must remain immediately in the early UI initialization path.")

    test_mode = source.find("if testMode then")
    combat_gate = source.find("UnitAffectingCombat(PLAYER_UNIT)")
    if test_mode == -1 or combat_gate == -1 or test_mode > combat_gate:
        fail(errors, "Test mode must bypass the combat and target gates.")

    own_cooldown = source.find("if not IsSpellReadyNow() then")
    own_cooldown_hide = source.find("HideIndicator()", own_cooldown)
    if own_cooldown == -1 or own_cooldown_hide == -1:
        fail(errors, "Own Shadow Word: Death cooldown must hide the indicator.")

    cooldown_done = source.find('cooldownWatcher:SetScript("OnCooldownDone"')
    cooldown_update = source.find("RequestIndicatorUpdate()", cooldown_done)
    if cooldown_done == -1 or cooldown_update == -1:
        fail(errors, "Cooldown completion must request an indicator refresh.")

    for callback in (
        "RunCoreCallback(UpdateIndicator)",
        "RunCoreCallback(ToggleSettings)",
        "RunCoreCallback(HandleEvent, event, unit)",
    ):
        if callback not in source:
            fail(errors, f"Core callback must use fail-closed error reporting: {callback}.")

    if not MODEL_CHECKS.is_file():
        fail(errors, "Missing execute-indicator model regression checks.")


def validate_package(archive: Path, errors: list[str]) -> None:
    if not archive.is_file():
        fail(errors, f"Package archive does not exist: {archive}")
        return

    with zipfile.ZipFile(archive) as package:
        entries = [PurePosixPath(name) for name in package.namelist() if not name.endswith("/")]

    if not entries:
        fail(errors, "Package archive is empty.")
        return

    for entry in entries:
        if not entry.parts or entry.parts[0] != ADDON_NAME:
            fail(errors, f"Package has content outside {ADDON_NAME}/: {entry}")
        if any(part in FORBIDDEN_PACKAGE_PARTS for part in entry.parts):
            fail(errors, f"Package contains a development path: {entry}")
        if entry.name in FORBIDDEN_PACKAGE_FILES:
            fail(errors, f"Package contains a development file: {entry}")

    package_names = {entry.as_posix() for entry in entries}
    required_files = [TOC_NAME, *toc_files(ADDON_DIR / TOC_NAME, errors)]
    for required_file in required_files:
        required = f"{ADDON_NAME}/{required_file}"
        if required not in package_names:
            fail(errors, f"Package is missing required runtime file: {required}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, help="Validate a BigWigs Packager ZIP after source checks.")
    args = parser.parse_args()

    errors: list[str] = []
    validate_source(errors)
    if args.package:
        validate_package(args.package, errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("ShadowWordDeathExecute validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
