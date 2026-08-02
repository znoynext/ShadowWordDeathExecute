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
RELEASE_WORKFLOW = ROOT / ".github" / "workflows" / "update-release.yml"
CI_WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"
INTERFACE_WORKFLOW = ROOT / ".github" / "workflows" / "update-interface.yml"
LOCALE_FILES = {
    "enUS": "Locales/enUS.lua",
    "ruRU": "Locales/ruRU.lua",
}
REQUIRED_LOCALE_KEYS = {"TITLE", "LOCK", "TEST", "POSITION", "X", "Y", "SIZE", "GLOW", "RESET"}
EXPECTED_LOCALES = {
    "enUS": {
        "TITLE": "Shadow Word: Death Execute",
        "LOCK": "Lock",
        "TEST": "Test",
        "POSITION": "Position",
        "X": "X:",
        "Y": "Y:",
        "SIZE": "Size",
        "GLOW": "Glow",
        "RESET": "Reset",
    },
    "ruRU": {
        "TITLE": "Shadow Word: Death Execute",
        "LOCK": "Закрепить",
        "TEST": "Тест",
        "POSITION": "Позиция",
        "X": "X:",
        "Y": "Y:",
        "SIZE": "Размер",
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


def validate_interface_versions(toc_text: str, errors: list[str], context: str) -> None:
    matches = re.findall(r"^## Interface:\s*(.+?)\s*$", toc_text, re.MULTILINE)
    if len(matches) != 1:
        fail(errors, f"{context} must contain exactly one Interface field.")
        return

    versions = [version.strip() for version in matches[0].split(",")]
    if not versions or not all(re.fullmatch(r"\d{6}", version) for version in versions):
        fail(errors, f"{context} has an invalid comma-separated Interface value.")
    if len(set(versions)) != len(versions):
        fail(errors, f"{context} must not repeat an Interface version.")


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
        "position": "CreateLabel(settings, L.POSITION",
        "X coordinate": "CreateLabel(settings, L.X",
        "Y coordinate": "CreateLabel(settings, L.Y",
        "size": "CreateLabel(settings, L.SIZE",
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
    toc_source = toc.read_text(encoding="utf-8-sig")
    if "## Version: @project-version@" not in toc_source:
        fail(errors, "TOC must use BigWigs Packager's @project-version@ substitution.")
    validate_interface_versions(toc_source, errors, "Source TOC")
    validate_locales(entries, source, errors)
    required_markers = {
        "slash command": 'SLASH_SHADOWWORDDEATHEXECUTE1 = "/swd"',
        "combat gate": "UnitAffectingCombat(PLAYER_UNIT)",
        "Secret-safe health curve": "C_CurveUtil.CreateColorCurve()",
        "Secret-safe target health": "UnitHealthPercent(TARGET_UNIT, true, executeHealthCurve)",
        "execute threshold": "local EXECUTE_THRESHOLD = 0.20",
        "Blizzard glow template": '"ActionButtonSpellAlertTemplate"',
        "boolean glow setting": "database.glowEnabled",
        "manual size inputs": "SetIconSize(sizeXInput:GetText(), sizeYInput:GetText())",
        "manual coordinate inputs": 'CreateFrame("EditBox", nil, parent, "InputBoxTemplate")',
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
    if 'CreateFrame("Slider"' in source:
        fail(errors, "Settings must not reintroduce a size slider.")

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


def validate_package(archive: Path, expected_version: str | None, errors: list[str]) -> None:
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
    nested_addon_directory = f"{ADDON_NAME}/{ADDON_NAME}/"
    if any(name.startswith(nested_addon_directory) for name in package_names):
        fail(errors, "Package contains an extra nested addon directory.")

    required_files = [TOC_NAME, "CHANGELOG.md", *toc_files(ADDON_DIR / TOC_NAME, errors)]
    for required_file in required_files:
        required = f"{ADDON_NAME}/{required_file}"
        if required not in package_names:
            fail(errors, f"Package is missing required runtime file: {required}")

    packaged_toc = f"{ADDON_NAME}/{TOC_NAME}"
    if packaged_toc in package_names:
        with zipfile.ZipFile(archive) as package:
            toc_text = package.read(packaged_toc).decode("utf-8-sig")
        validate_interface_versions(toc_text, errors, "Packaged TOC")
        version_match = re.search(r"^## Version:\s*(.+)$", toc_text, re.MULTILINE)
        if not version_match:
            fail(errors, "Packaged TOC is missing a Version field.")
        else:
            version = version_match.group(1).strip()
            if version == "@project-version@":
                fail(errors, "Packaged TOC still contains an unresolved @project-version@ substitution.")
            if expected_version and version != expected_version:
                fail(
                    errors,
                    f"Packaged TOC version {version!r} does not match expected tag {expected_version!r}.",
                )


def validate_release_workflow(errors: list[str]) -> None:
    if not RELEASE_WORKFLOW.is_file():
        fail(errors, "Missing release workflow: .github/workflows/update-release.yml")
        return

    workflow = RELEASE_WORKFLOW.read_text(encoding="utf-8")
    required_markers = {
        "SemVer tag guard": '[[ ! "$TAG" =~ ^v[0-9]+\\.[0-9]+\\.[0-9]+$ ]]',
        "main-history guard": 'git merge-base --is-ancestor "$TAG_COMMIT" "origin/main"',
        "immutable release preflight": 'gh release view "$TAG" --json id',
        "BigWigs Packager build": "uses: BigWigsMods/packager@",
        "dry-run Packager mode": "args: -d",
        "packaged version validation": '--expected-version "$TAG"',
        "marketplace project IDs": "-p ${{ vars.CF_PROJECT_ID }}",
        "Wago project ID": "-a ${{ vars.WAGO_PROJECT_ID }}",
        "WoWInterface addon ID": "-w ${{ vars.WOWI_PROJECT_ID }}",
        "CurseForge secret mapping": "CF_API_KEY: ${{ secrets.CF_API_TOKEN }}",
        "Wago secret": "WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}",
        "WoWInterface secret": "WOWI_API_TOKEN: ${{ secrets.WOWI_API_TOKEN }}",
        "missing deployment configuration guard": "configure the required GitHub Actions variables/secrets",
        "immutable release creation": 'gh release create "$TAG" "$ARCHIVE" --verify-tag',
    }
    for description, marker in required_markers.items():
        if marker not in workflow:
            fail(errors, f"Release workflow is missing {description}.")

    for forbidden_marker in ("--clobber", "gh release upload", "zip -r"):
        if forbidden_marker in workflow:
            fail(errors, f"Release workflow contains forbidden mutable/manual packaging: {forbidden_marker}.")


def validate_ci_workflow(errors: list[str]) -> None:
    if not CI_WORKFLOW.is_file():
        fail(errors, "Missing development CI workflow: .github/workflows/ci.yml")
        return

    workflow = CI_WORKFLOW.read_text(encoding="utf-8")
    required_markers = {
        "main push trigger": "  push:\n    branches:\n      - main",
        "main PR trigger": "  pull_request:\n    branches:\n      - main",
        "manual package simulation": "simulate_version:",
        "SemVer simulation guard": '[[ ! "$SIMULATE_VERSION" =~ ^v[0-9]+\\.[0-9]+\\.[0-9]+$ ]]',
        "ephemeral simulation tag": 'git -c user.name="CI package simulation" -c user.email="ci@users.noreply.github.com" tag -a "$SIMULATE_VERSION"',
        "simulated package version validation": '--expected-version "$EXPECTED_VERSION"',
        "manual-dispatch whitespace fallback": '[[ "${{ github.event_name }}" == "push" && "${{ github.event.before }}" != "0000000000000000000000000000000000000000" ]]',
    }
    for description, marker in required_markers.items():
        if marker not in workflow:
            fail(errors, f"Development CI is missing {description}.")
    if "develop/v2" in workflow:
        fail(errors, "Development CI must not retain develop/v2 as an active branch.")


def validate_interface_workflow(errors: list[str]) -> None:
    if not INTERFACE_WORKFLOW.is_file():
        fail(errors, "Missing Interface updater workflow: .github/workflows/update-interface.yml")
        return

    workflow = INTERFACE_WORKFLOW.read_text(encoding="utf-8")
    required_markers = {
        "scheduled trigger": "  schedule:",
        "manual trigger": "  workflow_dispatch:",
        "main PR base": "base: main",
        "Retail flavor": "flavor: retail",
        "PTR support": "ptr: true",
        "pinned Interface updater": "p3lim/toc-interface-updater@118fd5125c8604306fc8652bfcb5dd80e8899f63",
        "pinned PR action": "peter-evans/create-pull-request@22a9089034f40e5a961c8808d113e2c98fb63676",
        "temporary automation branch": "branch: automation/interface-version",
        "temporary branch cleanup": "delete-branch: true",
        "TOC-only scope": "add-paths: ShadowWordDeathExecute/ShadowWordDeathExecute.toc",
    }
    for description, marker in required_markers.items():
        if marker not in workflow:
            fail(errors, f"Interface updater workflow is missing {description}.")
    if "develop/v2" in workflow:
        fail(errors, "Interface updater must target main, not develop/v2.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, help="Validate a BigWigs Packager ZIP after source checks.")
    parser.add_argument(
        "--expected-version",
        help="Require the packaged TOC version to match this release tag.",
    )
    parser.add_argument(
        "--release-workflow",
        action="store_true",
        help="Validate release-automation guardrails.",
    )
    args = parser.parse_args()

    errors: list[str] = []
    validate_source(errors)
    if args.package:
        validate_package(args.package, args.expected_version, errors)
    elif args.expected_version:
        fail(errors, "--expected-version requires --package.")
    if args.release_workflow:
        validate_release_workflow(errors)
        validate_ci_workflow(errors)
        validate_interface_workflow(errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("ShadowWordDeathExecute validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
