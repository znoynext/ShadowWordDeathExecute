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

FORBIDDEN_PACKAGE_PARTS = {
    ".git",
    ".github",
    ".agents",
    ".codex",
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
        files.append(line)

    if not files:
        fail(errors, "TOC does not list any addon files.")

    return files


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
    required_markers = {
        "slash command": 'SLASH_SHADOWWORDDEATHEXECUTE1 = "/swd"',
        "combat gate": 'UnitAffectingCombat("player")',
        "Secret-safe health curve": "C_CurveUtil.CreateColorCurve()",
        "Secret-safe target health": 'UnitHealthPercent("target", true, executeHealthCurve)',
        "execute threshold": "local EXECUTE_THRESHOLD = 0.20",
        "Blizzard glow template": '"ActionButtonSpellAlertTemplate"',
        "boolean glow setting": "database.glowEnabled",
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

    for obsolete_marker in ("GLOW_PULSE", "GLOW_STRONG", "CreatePulseAnimation", "UIDropDownMenu_"):
        if obsolete_marker in source:
            fail(errors, f"Obsolete glow architecture remains: {obsolete_marker}.")

    indicator_start = source.find('local indicator = CreateFrame("Frame", nil, UIParent)')
    early_hide = source.find("indicator:Hide()", indicator_start)
    glow_start = source.find("local glowContainer =", indicator_start)
    if indicator_start == -1 or early_hide == -1 or glow_start == -1 or not indicator_start < early_hide < glow_start:
        fail(errors, "indicator:Hide() must remain immediately in the early UI initialization path.")


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
    for required in (f"{ADDON_NAME}/{TOC_NAME}", f"{ADDON_NAME}/{LUA_NAME}"):
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
