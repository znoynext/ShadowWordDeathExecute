local SPELL_ID = 32379 -- Shadow Word: Death
local EXECUTE_THRESHOLD = 0.20
local DEFAULT_SIZE = 48
local MIN_SIZE = 24
local MAX_SIZE = 128
local MAX_OFFSET = 10000

local validPoints = {
	TOPLEFT = true,
	TOP = true,
	TOPRIGHT = true,
	LEFT = true,
	CENTER = true,
	RIGHT = true,
	BOTTOMLEFT = true,
	BOTTOM = true,
	BOTTOMRIGHT = true,
}

local function CreateExecuteAlphaCurve()
	local curve = C_CurveUtil.CreateColorCurve()
	curve:SetType(Enum.LuaCurveType.Step)
	curve:AddPoint(0, CreateColor(1, 1, 1, 1))
	curve:AddPoint(EXECUTE_THRESHOLD + 0.0001, CreateColor(1, 1, 1, 0))
	return curve
end

-- UnitHealthPercent evaluates this curve inside Blizzard's API. This keeps the
-- 20% test valid when target health is a Midnight Secret Value.
local executeHealthCurve = CreateExecuteAlphaCurve()

local indicator = CreateFrame("Frame", nil, UIParent)
indicator:SetSize(DEFAULT_SIZE, DEFAULT_SIZE)
indicator:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
indicator:SetMovable(true)
indicator:SetClampedToScreen(true)
indicator:RegisterForDrag("LeftButton")

local icon = indicator:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexture(C_Spell.GetSpellTexture(SPELL_ID))

-- This invisible Cooldown receives the secret-safe DurationObject and signals
-- the exact end of a cooldown without reading its protected timing fields.
local cooldownWatcher = CreateFrame("Cooldown", nil, UIParent)
cooldownWatcher:SetSize(1, 1)
cooldownWatcher:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -1)
cooldownWatcher:SetAlpha(0)

local database
local settings
local lockedCheck
local testCheck
local sizeText
local sizeSlider
local testMode = false
local UpdateIndicator

local function ClampNumber(value, minimum, maximum, fallback)
	value = tonumber(value)
	if not value or value ~= value then
		return fallback
	end

	return math.min(maximum, math.max(minimum, value))
end

local function InitializeDatabase()
	if type(SWDExecuteDB) ~= "table" then
		SWDExecuteDB = {}
	end

	database = SWDExecuteDB
	database.point = validPoints[database.point] and database.point or "CENTER"
	database.relativePoint = validPoints[database.relativePoint] and database.relativePoint or "CENTER"
	database.x = ClampNumber(database.x, -MAX_OFFSET, MAX_OFFSET, 0)
	database.y = ClampNumber(database.y, -MAX_OFFSET, MAX_OFFSET, 0)
	database.size = ClampNumber(database.size, MIN_SIZE, MAX_SIZE, DEFAULT_SIZE)
	if type(database.locked) ~= "boolean" then
		database.locked = true
	end
end

local function ApplySavedPosition()
	indicator:ClearAllPoints()
	indicator:SetPoint(database.point, UIParent, database.relativePoint, database.x, database.y)
end

local function SavePosition()
	local point, _, relativePoint, x, y = indicator:GetPoint()
	database.point = point
	database.relativePoint = relativePoint
	database.x = x
	database.y = y
end

local function SetIconSize(size)
	size = math.floor(ClampNumber(size, MIN_SIZE, MAX_SIZE, DEFAULT_SIZE))
	database.size = size
	indicator:SetSize(size, size)

	if sizeText then
		sizeText:SetText("Размер: " .. size)
	end
end

local function UpdateInteractionState()
	indicator:EnableMouse(testMode and not database.locked)
end

local function SetLocked(locked)
	database.locked = locked and true or false
	UpdateInteractionState()

	if lockedCheck then
		lockedCheck:SetChecked(database.locked)
	end
end

local function SetTestMode(enabled)
	testMode = enabled and true or false

	if testCheck then
		testCheck:SetChecked(testMode)
	end

	UpdateInteractionState()
	UpdateIndicator()
end

local function HideIndicator()
	indicator:Hide()
end

local function IsHostileLivingTarget()
	return UnitExists("target")
		and not UnitIsDeadOrGhost("target")
		and UnitCanAttack("player", "target")
end

local function ApplyExecuteHealthAlpha()
	local color = UnitHealthPercent("target", true, executeHealthCurve)
	icon:SetAlpha(select(4, color:GetRGBA()))
end

local function WatchSpellCooldown()
	local duration = C_Spell.GetSpellCooldownDuration(SPELL_ID)
	if not duration then
		duration = C_Spell.GetSpellChargeDuration(SPELL_ID)
	end

	if duration then
		cooldownWatcher:SetCooldownFromDurationObject(duration)
	end
end

UpdateIndicator = function()
	if testMode then
		icon:SetDesaturated(false)
		icon:SetAlpha(1)
		icon:Show()
		indicator:Show()
		return
	end

	if select(2, UnitClass("player")) ~= "PRIEST" or not IsHostileLivingTarget() then
		HideIndicator()
		return
	end

	local maximumHealth = UnitHealthMax("target")
	if not issecretvalue(maximumHealth) and maximumHealth == 0 then
		HideIndicator()
		return
	end

	ApplyExecuteHealthAlpha()
	icon:SetDesaturated(false)
	indicator:Show()
	-- SetShown accepts Midnight Secret booleans, so this does not branch on
	-- protected spell-usability data.
	icon:SetShown(C_Spell.IsSpellUsable(SPELL_ID))
	WatchSpellCooldown()
end

local function CreateCheckbox(parent, label, x, y)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

	local text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
	text:SetText(label)

	return checkbox
end

local function CreateSettingsWindow()
	settings = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	settings:SetSize(260, 210)
	settings:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	settings:SetMovable(true)
	settings:SetClampedToScreen(true)
	settings:EnableMouse(true)
	settings:RegisterForDrag("LeftButton")
	settings:SetScript("OnDragStart", settings.StartMoving)
	settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
	settings:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	settings:SetBackdropColor(0, 0, 0, 0.9)
	settings:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

	local title = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", settings, "TOPLEFT", 14, -14)
	title:SetText("Shadow Word: Death Execute")

	local closeButton = CreateFrame("Button", nil, settings, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", settings, "TOPRIGHT", 0, 0)

	lockedCheck = CreateCheckbox(settings, "Закрепить", 16, -48)
	lockedCheck:SetScript("OnClick", function(self)
		SetLocked(self:GetChecked())
	end)

	testCheck = CreateCheckbox(settings, "Тест", 16, -78)
	testCheck:SetScript("OnClick", function(self)
		SetTestMode(self:GetChecked())
	end)

	sizeText = settings:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sizeText:SetPoint("TOPLEFT", settings, "TOPLEFT", 16, -112)

	sizeSlider = CreateFrame("Slider", nil, settings)
	sizeSlider:SetSize(170, 16)
	sizeSlider:SetPoint("TOPLEFT", settings, "TOPLEFT", 16, -138)
	sizeSlider:SetOrientation("HORIZONTAL")
	sizeSlider:SetMinMaxValues(MIN_SIZE, MAX_SIZE)
	sizeSlider:SetValueStep(1)
	sizeSlider:SetObeyStepOnDrag(true)
	sizeSlider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
	sizeSlider:GetThumbTexture():SetSize(16, 16)

	local track = sizeSlider:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(0.25, 0.25, 0.25, 1)
	track:SetPoint("LEFT", sizeSlider, "LEFT", 0, 0)
	track:SetPoint("RIGHT", sizeSlider, "RIGHT", 0, 0)
	track:SetHeight(6)

	sizeSlider:SetScript("OnValueChanged", function(_, value)
		SetIconSize(value)
	end)
	sizeSlider:SetValue(database.size)

	local resetButton = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
	resetButton:SetSize(100, 22)
	resetButton:SetPoint("TOPLEFT", settings, "TOPLEFT", 16, -166)
	resetButton:SetText("Сбросить")
	resetButton:SetScript("OnClick", function()
		database.point = "CENTER"
		database.relativePoint = "CENTER"
		database.x = 0
		database.y = 0
		database.size = DEFAULT_SIZE
		ApplySavedPosition()
		SetIconSize(DEFAULT_SIZE)
		sizeSlider:SetValue(DEFAULT_SIZE)
	end)

	settings:SetScript("OnShow", function()
		lockedCheck:SetChecked(database.locked)
		testCheck:SetChecked(testMode)
		sizeSlider:SetValue(database.size)
	end)
	settings:SetScript("OnHide", function()
		SetTestMode(false)
	end)
	settings:Hide()
end

indicator:SetScript("OnDragStart", function(self)
	if testMode and not database.locked then
		self:StartMoving()
	end
end)

indicator:SetScript("OnDragStop", function(self)
	if testMode and not database.locked then
		self:StopMovingOrSizing()
		SavePosition()
	end
end)

cooldownWatcher:SetScript("OnCooldownDone", function()
	UpdateIndicator()
end)

SLASH_SHADOWWORDDEATHEXECUTE1 = "/swd"
SlashCmdList.SHADOWWORDDEATHEXECUTE = function()
	if settings:IsShown() then
		settings:Hide()
	else
		settings:Show()
	end
end

indicator:RegisterEvent("PLAYER_LOGIN")
indicator:RegisterEvent("PLAYER_ENTERING_WORLD")
indicator:RegisterEvent("PLAYER_TARGET_CHANGED")
indicator:RegisterUnitEvent("UNIT_HEALTH", "target")
indicator:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", "target")
indicator:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
indicator:RegisterUnitEvent("UNIT_FLAGS", "target")
indicator:RegisterUnitEvent("UNIT_FACTION", "target")
indicator:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
indicator:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
indicator:RegisterEvent("SPELL_UPDATE_COOLDOWN")
indicator:RegisterEvent("SPELL_UPDATE_USABLE")
indicator:RegisterEvent("SPELL_UPDATE_CHARGES")
indicator:RegisterEvent("SPELLS_CHANGED")

indicator:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_LOGIN" then
		InitializeDatabase()
		ApplySavedPosition()
		SetIconSize(database.size)
		SetLocked(database.locked)
		CreateSettingsWindow()
	elseif (event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" or event == "UNIT_FACTION") and unit ~= "target" then
		return
	elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_SPELLCAST_SUCCEEDED") and unit ~= "player" then
		return
	end

	UpdateIndicator()
end)

indicator:Hide()
