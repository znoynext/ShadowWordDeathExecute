local SPELL_ID = 32379 -- Shadow Word: Death
local EXECUTE_THRESHOLD = 0.20

local function CreateHealthAlphaCurve(lowHealthAlpha, highHealthAlpha)
	local curve = C_CurveUtil.CreateColorCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	curve:AddPoint(0, CreateColor(1, 1, 1, lowHealthAlpha))
	curve:AddPoint(EXECUTE_THRESHOLD + 0.0001, CreateColor(1, 1, 1, highHealthAlpha))
	return curve
end

local inactiveHealthCurve = CreateHealthAlphaCurve(0, 0.35)
local readyHealthCurve = CreateHealthAlphaCurve(1, 0)

local frame = CreateFrame("Frame", nil, UIParent)
frame:SetSize(48, 48)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

local spellTexture = C_Spell.GetSpellTexture(SPELL_ID)

local inactiveIcon = frame:CreateTexture(nil, "ARTWORK")
inactiveIcon:SetAllPoints()
inactiveIcon:SetTexture(spellTexture)
inactiveIcon:SetDesaturated(true)

local readyIcon = frame:CreateTexture(nil, "ARTWORK")
readyIcon:SetAllPoints()
readyIcon:SetTexture(spellTexture)

-- This invisible Cooldown receives the secret-safe DurationObject and signals
-- the exact end of a cooldown without reading its protected timing fields.
local cooldownWatcher = CreateFrame("Cooldown", nil, UIParent)
cooldownWatcher:SetSize(1, 1)
cooldownWatcher:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -1)
cooldownWatcher:SetAlpha(0)

local UpdateIndicator

local function HideIndicator()
	readyIcon:Hide()
	frame:Hide()
end

local function IsHostileLivingTarget()
	return UnitExists("target")
		and not UnitIsDeadOrGhost("target")
		and UnitCanAttack("player", "target")
end

local function ApplyHealthState()
	-- UnitHealthPercent evaluates the 20% threshold inside Blizzard's curve API,
	-- so this remains valid when target health is a Secret Value.
	local inactiveColor = UnitHealthPercent("target", true, inactiveHealthCurve)
	local readyColor = UnitHealthPercent("target", true, readyHealthCurve)
	inactiveIcon:SetAlpha(select(4, inactiveColor:GetRGBA()))
	readyIcon:SetAlpha(select(4, readyColor:GetRGBA()))
end

function UpdateIndicator()
	if select(2, UnitClass("player")) ~= "PRIEST" or not IsHostileLivingTarget() then
		HideIndicator()
		return
	end

	local maximumHealth = UnitHealthMax("target")
	if not issecretvalue(maximumHealth) and maximumHealth == 0 then
		HideIndicator()
		return
	end

	frame:Show()
	ApplyHealthState()

	local cooldownInfo = C_Spell.GetSpellCooldown(SPELL_ID)
	if cooldownInfo and cooldownInfo.isActive then
		readyIcon:Hide()
		cooldownWatcher:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(SPELL_ID))
		return
	end

	-- SetShown accepts Midnight Secret booleans, so this does not branch on
	-- protected spell-usability data.
	readyIcon:SetShown(C_Spell.IsSpellUsable(SPELL_ID))
end

cooldownWatcher:SetScript("OnCooldownDone", function()
	UpdateIndicator()
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterUnitEvent("UNIT_HEALTH", "target")
frame:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
frame:RegisterEvent("SPELL_UPDATE_USABLE")
frame:RegisterEvent("SPELLS_CHANGED")

frame:SetScript("OnEvent", function(_, event, unit)
	if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit ~= "target" then
		return
	end

	UpdateIndicator()
end)

frame:Hide()
