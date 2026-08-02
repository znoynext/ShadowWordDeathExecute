# Retail API compatibility audit

## Audited target

| Item | Value |
| --- | --- |
| Historical source revision | `06f1cfd803bc5de73941d31cc3da7413edd0fdfe` |
| WoW product | World of Warcraft Retail (Mainline), Midnight |
| UI-source build | `12.0.7.68887` |
| TOC Interface | `120007` |
| Audit date | 2026-07-31 |

### Sources and evidence level

Blizzard does not publish a separate public, versioned API reference for every
Retail build. This audit therefore uses the closest primary artefact: the
generated API documentation and FrameXML extracted from the Retail client in
the `live` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source).
The repository identifies itself as a mirror of the WoW UI source, not as an
official Blizzard repository. All source findings below are pinned to
`[Gethe/wow-ui-source@4383ced](https://github.com/Gethe/wow-ui-source/commit/4383ced)`,
whose commit message and [`version.txt`](https://github.com/Gethe/wow-ui-source/blob/4383ced/version.txt)
identify build `12.0.7.68887`. Accessed 2026-07-31.

Primary/client-derived source paths used by this audit:

- [`Blizzard_APIDocumentationGenerated/SpellDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)
- [`Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua)
- [`Blizzard_APIDocumentationGenerated/UnitDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [`Blizzard_APIDocumentationGenerated/CurveUtilDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_APIDocumentationGenerated/CurveUtilDocumentation.lua)
- [`Blizzard_APIDocumentationGenerated/LuaColorCurveObjectAPIDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaColorCurveObjectAPIDocumentation.lua)
- [`Blizzard_APIDocumentationGenerated/LuaCurveObjectBaseAPIDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaCurveObjectBaseAPIDocumentation.lua)
- [`Blizzard_APIDocumentationGenerated/LuaCurveObjectConstantsDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaCurveObjectConstantsDocumentation.lua)
- [`Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua)
- [`Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua)
- [`Blizzard_ActionBar/Blizzard_ActionBar_Mainline.toc`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_ActionBar/Blizzard_ActionBar_Mainline.toc)
- [`Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.lua`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.lua)
- [`Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml`](https://github.com/Gethe/wow-ui-source/blob/4383ced/Interface/AddOns/Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml)
- [Lua 5.1 reference manual: `xpcall`](https://www.lua.org/manual/5.1/manual.html#pdf-xpcall)

`120007` is consistent with the audited live client version `12.0.7` and the
current TOC. The authoritative runtime value is the fourth result of
`GetBuildInfo()`; it cannot be executed in this source-only audit. A live
smoke test must record `select(4, GetBuildInfo())` before any future TOC bump.
There is no evidence that `120007` is stale for build `12.0.7.68887`, so this
is **not** a change request.

Status meanings:

- **VERIFIED** — present with the needed documented contract in the audited client source.
- **VERIFIED WITH CAVEAT** — source supports the implementation, but a client-state or load-order condition remains.
- **UNVERIFIED** — cannot be established from the allowed static sources; requires a live Retail observation.
- **CHANGE REQUIRED** — confirmed incompatibility. None were found.

## API audit

| Area | Current implementation | Verified semantics | Status | Risk | Required action |
| --- | --- | --- | --- | --- | --- |
| Color curve | `C_CurveUtil.CreateColorCurve()`, `curve:SetType(Enum.LuaCurveType.Step)`, `AddPoint` | `CreateColorCurve` returns a `LuaColorCurveObject`; its base supports `SetType`; `Step` is enum value 1 and performs exact steps rather than interpolation. | VERIFIED | Low | None. |
| Secret health | `UnitHealthPercent("target", true, executeHealthCurve)` | Signature is `(unit, usePredicted = true, curve = nil)`. With a curve it returns the curve evaluation, and the function is explicitly `SecretReturns`; it is secret when the curve is secret. | VERIFIED | Low | None. |
| Visual Secret sink | `color:GetRGBA()` → `icon:SetAlpha(alpha)` and `glowContainer:SetAlpha(alpha)` | UI-region `SetAlpha` accepts tainted Secret arguments and records the Alpha aspect; `GetAlpha` is secret-aspect returning. The addon never calls `GetAlpha`, never branches on alpha, and never converts target HP to a Lua boolean. | VERIFIED | Low | None. |
| Maximum-health guard | `UnitHealthMax("target")`; compare with zero only after `not issecretvalue` | `UnitHealthMax` may become secret under `UnitHealthMaxRestricted`. The guard avoids comparing a secret value; it is not used for execute arithmetic. | VERIFIED WITH CAVEAT | Low | Keep the guard exactly as written. A live restricted-context smoke test remains useful. |
| Texture | `C_Spell.GetSpellTexture(32379)` during frame construction | `(spellIdentifier)` returns `iconID, originalIconID`, and may return nothing when the spell is not found. | VERIFIED WITH CAVEAT | Low | P2: verify a fresh login/reload on a Priest. If Retail can return nil before spell data is ready, refresh the texture after data availability; do not add polling. |
| Cooldown state | `C_Spell.GetSpellCooldown(32379)` cache on `SPELL_UPDATE_COOLDOWN` | May return nil if the spell is not found and may be secret while cooldowns are restricted. `SpellCooldownInfo.isActive` and `.isOnGCD` are documented `NeverSecret`. `isOnGCD` is explicitly trustworthy **only while responding to `SPELL_UPDATE_COOLDOWN`**. | VERIFIED | Low | None; the cache is correctly populated only in that event. |
| Own cooldown vs. GCD | `isActive and not spellOnGCD` | `isActive` means an active cooldown; `.isOnGCD` identifies GCD-only state in the trusted event context. This is the documented separation required by the implementation. | VERIFIED | Low | None. |
| Cooldown watcher | `C_Spell.GetSpellCooldownDuration(32379, true)` → `Cooldown:SetCooldownFromDurationObject` | `(spellIdentifier, ignoreGCD = false)` returns a `LuaDurationObject` for an active cooldown. `ignoreGCD = true` is a real optional argument. `SetCooldownFromDurationObject(duration, clearIfZero = true)` accepts that object. | VERIFIED | Low | None. |
| Charge watcher | fallback `C_Spell.GetSpellChargeDuration(32379)` | Returns a `LuaDurationObject` for an active recharge. Its presence means recharge exists, not that all charges are unavailable. | VERIFIED | Low | None. |
| Charge readiness | `return not ownSpellCooldownActive`; no `DurationObject` truthiness test | `GetSpellCharges` reports `currentCharges`; a recharge has an independent `SpellChargeInfo.isActive`. The current architecture deliberately does not use a recharge object's truthiness as readiness. | VERIFIED | Low | None. |
| Spell usability | `C_Spell.IsSpellUsable(32379)` | `(spellIdentifier)` returns `(isUsable, insufficientPower)`, where `insufficientPower` specifically identifies a resource failure. | VERIFIED | Low | None. |
| Error containment | `xpcall` around core callback, handler hides first then calls `CallErrorHandler` or `geterrorhandler()` | Lua 5.1 `xpcall(f, err)` invokes `err` before unwinding. Capturing arguments in a closure is required on Lua 5.1. The current code protects cleanup and handler dispatch to prevent a secondary handler failure from looping. | VERIFIED WITH CAVEAT | Low | None. Verify live error capture in Blizzard error UI and BugSack/BugGrabber before release candidate. |
| `CallErrorHandler` / `geterrorhandler` | runtime feature detection, standard-handler fallback | The generated API snapshot does not document their exact signatures. The code is fail-closed if either is absent or fails, but only a live client can prove the receiving handler/stack presentation. | VERIFIED WITH CAVEAT | Low | No code change; perform the live error-report smoke test. |
| Blizzard glow | Optional `ActionButtonSpellAlertTemplate`, guarded `pcall(CreateFrame, ...)` | `Blizzard_ActionBar` loads `Shared/ActionButtonSpellAlerts.lua` and `.xml`; that source creates the same template and defines `ActionButtonSpellAlertMixin`. Its mainline TOC declares `DefaultState: enabled` and `AllowLoad: Game`. | VERIFIED WITH CAVEAT | Low | Keep the optional fallback. `OptionalDeps` gives load order, but the template must still be treated as optional if Blizzard UI is unavailable or changes. |

### Secret-safe health-path conclusion

The exact path is valid for the audited client:

```text
C_CurveUtil.CreateColorCurve
  → UnitHealthPercent("target", true, curve)
  → ColorMixin:GetRGBA()
  → Texture/Frame:SetAlpha()
```

The `Step` curve maps `<= 0.20` to alpha 1 and values above `0.2001` to alpha
0. This is a visual Secret-value propagation path, not protected-health
arithmetic. `UnitHealth("target") / UnitHealthMax("target")` is absent, and
the code does not read a visual alpha back into Lua control flow. **NO CHANGE.**

## Spell audit: Shadow Word: Death

| Property | Current assumption | Verified value | Status | Source |
| --- | --- | --- | --- | --- |
| Spell identity | `SPELL_ID = 32379` | `C_Spell` supports numeric `SpellIdentifier`; the audited static UI source does not ship current spell records or a tooltip for this ID. | UNVERIFIED | `SpellDocumentation.lua`; live spell data required. |
| Display texture | `C_Spell.GetSpellTexture(32379)` | API signature and `fileID` result are verified. The spell-to-ID result needs live confirmation. | VERIFIED WITH CAVEAT | `SpellDocumentation.lua`; live spell data required. |
| Priest availability | addon gates only `PRIEST`, not a spec | Not represented in the audited API/FrameXML sources. | UNVERIFIED | Live spellbook/API observation required for every Priest spec intended to be supported. |
| Base cooldown / charges | handled through current `C_Spell` APIs | API contracts are verified; the current spell's actual cooldown/charge layout is game data. | UNVERIFIED | Live spell API observation required. |
| Execute threshold | `0.20` | Static UI sources do not expose the live SW:D tooltip/effect or talent modifiers. | UNVERIFIED | Live tooltip and combat smoke test required. |
| Overrides/replacements | fixed ID intentionally remains the only supported spell | `C_Spell.GetBaseSpell`/`GetOverrideSpell` exist, but no primary current data proves an SW:D override relevant to this addon. | UNVERIFIED | Query live `GetBaseSpell`/`GetOverrideSpell` before considering any change. |
| Adaptive threshold talent | no adaptive threshold implementation | No primary static evidence found for a current Retail talent that changes the relevant threshold. | UNVERIFIED | Check the live Priest talent/spell data; do not add adaptive logic without evidence. |

The production baseline confirms the core behavior was player-tested at
`v1.2.2`, but that is not a substitute for current game-data evidence across
specs and talent configurations. This is an evidence gap, not proof that
`32379` or `20%` is wrong.

## Event audit

The addon registers no `OnUpdate` handler. Its cooldown watcher is event-driven
and uses `OnCooldownDone`, so no frame polling is needed.

| Event | Current filter / purpose | Source finding | Status |
| --- | --- | --- | --- |
| `PLAYER_LOGIN` | initialize database/settings | Standard lifecycle event; initialization is additionally fail-closed until complete. | VERIFIED WITH CAVEAT |
| `PLAYER_ENTERING_WORLD` | refresh after world entry/reload | Current Blizzard ActionBar registers it. | VERIFIED |
| `PLAYER_TARGET_CHANGED` | target acquisition/loss | Standard target lifecycle event; no unit argument is used. | VERIFIED WITH CAVEAT |
| `PLAYER_REGEN_DISABLED` | enter combat | Standard combat lifecycle event. | VERIFIED WITH CAVEAT |
| `PLAYER_REGEN_ENABLED` | leave combat and hide | Standard combat lifecycle event. | VERIFIED WITH CAVEAT |
| `UNIT_HEALTH` | `target`; evaluate visual Secret-safe threshold | Generated Unit docs list a synchronous unit-token payload. | VERIFIED |
| `UNIT_MAXHEALTH` | `target`; zero-max guard | Generated Unit docs list a synchronous unit-token payload. | VERIFIED |
| `UNIT_FLAGS` | `target`; dead/flag state | Generated Unit docs list a synchronous unit-token payload. | VERIFIED |
| `UNIT_FACTION` | `target`; hostility relation | Generated Unit docs list a synchronous unit-token payload. | VERIFIED |
| `UNIT_POWER_UPDATE` | `player`; refresh resource usability | Unit-token filter is correct. Current API docs do not enumerate the legacy/global event's payload in this snapshot. | VERIFIED WITH CAVEAT |
| `UNIT_SPELLCAST_SUCCEEDED` | `player`; immediate post-cast refresh | Current Blizzard ActionBar registers this exact player unit event. | VERIFIED |
| `SPELL_UPDATE_COOLDOWN` | update trusted `isOnGCD` cache and refresh | Required by the documented trust restriction on `SpellCooldownInfo.isOnGCD`. | VERIFIED |
| `SPELL_UPDATE_USABLE` | refresh `IsSpellUsable` result | Not contradicted by source, but current ActionBar uses an action-slot watcher (`ACTION_USABLE_CHANGED`) rather than this spell-level registration. | VERIFIED WITH CAVEAT |
| `SPELL_UPDATE_CHARGES` | refresh charge/recharge state | Current Blizzard ActionBar registers it. | VERIFIED |
| `SPELLS_CHANGED` | refresh after spellbook changes | Standard spellbook lifecycle event; source-only audit cannot prove dispatch timing for this addon. | VERIFIED WITH CAVEAT |

No registered event is identified as removed or deprecated by the audited
client-derived sources. Unit filters match their use: `target` for target state
and `player` for cast/resource events. The existing combination covers target
changes, target health/faction/flags, combat gates, spell usability/cooldown/
charge changes, and cooldown completion without polling.

## Findings

### P0 — blocks publication

None found.

### P1 — resolve before a release candidate

1. **Current SW:D game-data evidence is missing.** On live Retail, record
   `C_Spell.GetSpellInfo(32379)`, `C_Spell.GetBaseSpell(32379)`,
   `C_Spell.GetOverrideSpell(32379)`, `C_Spell.GetSpellCharges(32379)`, the
   spellbook/tooltip, and a `20%` boundary test for each supported Priest spec.
   Verify whether any selected talent changes the execute threshold. This is an
   evidence task; it does not authorize a runtime change by itself.
2. **Live event/error smoke evidence is required.** Verify `SPELL_UPDATE_USABLE`
   dispatch in the actual client, `select(4, GetBuildInfo()) == 120007`, and an
   intentionally injected temporary error in a local test copy. The error must
   reach the standard Lua error UI and any enabled BugSack/BugGrabber exactly
   once while the indicator and glow hide.

### P2 — useful future hardening

1. At a fresh `/reload` on a Priest, confirm the top-level
   `C_Spell.GetSpellTexture(32379)` is non-nil. If it is ever nil before spell
   data becomes available, add one event-driven texture refresh after spell-data
   availability. Do not add a timer or `OnUpdate`.
2. Re-run this audit against each new Retail build and keep the source revision
   and `GetBuildInfo()` evidence alongside the release candidate.

### NO CHANGE — confirmed current areas

- `C_CurveUtil` + `UnitHealthPercent` + alpha rendering is the documented
  Secret-safe display path.
- The zero-max-health guard is secret-aware and is not execute arithmetic.
- The cooldown logic correctly honours the documented event-only validity of
  `isOnGCD`.
- `ignoreGCD = true` is a documented parameter, and a `LuaDurationObject` is
  correctly used only to watch cooldown/recharge completion.
- The readiness model does not mistake a recharging charge for an unavailable
  spell.
- `C_Spell.IsSpellUsable` has the expected two-return-value contract.
- The Blizzard glow template/mixin remains optional and cannot break the icon.
- The `xpcall` wrapper is Lua-5.1-compatible, reports through the standard
  handler path when available, and remains fail-closed without a logging system.
- The indicator is hidden before complex initialization, and no permanent
  `OnUpdate`/polling was introduced.

## Recommended next implementation step

Do **not** change runtime code from this audit alone. The next Codex prompt
should request only a live-Retail evidence pass that:

1. captures `GetBuildInfo()` and the SW:D API/tooltip/charge observations for
   each intended Priest spec and relevant talent choice;
2. uses EventTrace or a small disposable diagnostic copy to confirm the listed
   events, especially `SPELL_UPDATE_USABLE`, at the required transitions;
3. validates standard error UI plus BugSack/BugGrabber behaviour; and
4. updates this audit with the captured build, exact outputs, and only then
   proposes the smallest code change for a confirmed incompatibility.

Any subsequent implementation must preserve the existing combat gate,
Secret-safe health pipeline, GCD cache, own-cooldown/charge semantics, optional
glow fallback, SavedVariables, and event-driven design.
