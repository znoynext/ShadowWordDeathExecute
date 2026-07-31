local SPELL_ID = 32379 -- Shadow Word: Death
local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"
local PRIEST_CLASS = "PRIEST"
local EXECUTE_THRESHOLD = 0.20
local DEFAULT_SIZE = 48
local MIN_SIZE = 24
local MAX_SIZE = 128
local MAX_OFFSET = 10000

local DATABASE_DEFAULTS = {
	point = "CENTER",
	relativePoint = "CENTER",
	x = 0,
	y = 0,
	size = DEFAULT_SIZE,
	locked = true,
	glowEnabled = false,
}

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

indicator:Hide()

-- The container receives the same Secret-safe alpha as the icon. The Blizzard
-- proc glow remains purely visual and never reimplements the protected HP check.
local glowContainer = CreateFrame("Frame", nil, indicator)
glowContainer:SetAllPoints()
glowContainer:SetFrameLevel(indicator:GetFrameLevel() + 1)
glowContainer:Hide()

local blizzardGlow
local blizzardGlowActive = false

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
local glowCheck
local sizeText
local sizeSlider
local testMode = false
local ownSpellCooldownActive = false
local spellOnGCD = false
local playerClass
local UpdateIndicator
local RequestIndicatorUpdate
local InitializeAddon
local addonInitialized = false

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
	database.point = validPoints[database.point] and database.point or DATABASE_DEFAULTS.point
	database.relativePoint = validPoints[database.relativePoint] and database.relativePoint or DATABASE_DEFAULTS.relativePoint
	database.x = ClampNumber(database.x, -MAX_OFFSET, MAX_OFFSET, DATABASE_DEFAULTS.x)
	database.y = ClampNumber(database.y, -MAX_OFFSET, MAX_OFFSET, DATABASE_DEFAULTS.y)
	database.size = ClampNumber(database.size, MIN_SIZE, MAX_SIZE, DATABASE_DEFAULTS.size)
	if type(database.locked) ~= "boolean" then
		database.locked = DATABASE_DEFAULTS.locked
	end
	if type(database.glowEnabled) ~= "boolean" then
		database.glowEnabled = database.glow == "blizzard" or database.glow == "pulse" or database.glow == "strong" or DATABASE_DEFAULTS.glowEnabled
	end
	database.glow = nil
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

local function UpdateGlowSize()
	if blizzardGlow then
		local size = indicator:GetWidth() * 1.4
		blizzardGlow:SetSize(size, size)
	end
end

local function SetIconSize(size)
	size = math.floor(ClampNumber(size, MIN_SIZE, MAX_SIZE, DEFAULT_SIZE))
	database.size = size
	indicator:SetSize(size, size)
	UpdateGlowSize()

	if sizeText then
		sizeText:SetText("Размер: " .. size)
	end
end

local function StopBlizzardGlow()
	if blizzardGlow then
		if blizzardGlow.ProcStartAnim then
			blizzardGlow.ProcStartAnim:Stop()
		end
		if blizzardGlow.ProcLoop then
			blizzardGlow.ProcLoop:Stop()
		end
		blizzardGlow:Hide()
	end
end

local function CreateBlizzardGlow()
	if blizzardGlow or not ActionButtonSpellAlertMixin then
		return blizzardGlow
	end

	-- This is Blizzard_ActionBar's Retail proc-glow template. It is purely
	-- visual and does not turn this indicator into a secure action button.
	local created, frame = pcall(CreateFrame, "Frame", nil, glowContainer, "ActionButtonSpellAlertTemplate")
	if not created or not frame then
		return nil
	end

	blizzardGlow = frame
	blizzardGlow:SetPoint("CENTER", indicator, "CENTER")
	UpdateGlowSize()
	return blizzardGlow
end

local function HideGlow()
	blizzardGlowActive = false
	StopBlizzardGlow()
	glowContainer:Hide()
end

local function ShowGlow()
	if not database or not database.glowEnabled then
		HideGlow()
		return
	end

	if blizzardGlowActive then
		return
	end

	local frame = CreateBlizzardGlow()
	if not frame then
		-- Glow is optional. A missing Blizzard template must not affect the icon.
		HideGlow()
		return
	end

	blizzardGlowActive = true
	glowContainer:Show()
	frame:Show()
	if frame.ProcStartAnim then
		frame.ProcStartAnim:Stop()
	end
	if frame.ProcLoop then
		frame.ProcLoop:Stop()
	end
	if frame.ProcStartAnim then
		frame.ProcStartAnim:Play()
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
	RequestIndicatorUpdate()
end

local function SetGlowEnabled(enabled)
	database.glowEnabled = enabled and true or false

	if glowCheck then
		glowCheck:SetChecked(database.glowEnabled)
	end

	RequestIndicatorUpdate()
end

local function HideIndicator()
	HideGlow()
	indicator:Hide()
end

local function ReportCoreError(message)
	-- xpcall invokes this before unwinding the callback stack. Hide first so a
	-- failed update cannot leave a stale execute indicator on screen, then pass
	-- the original error to WoW's current handler while that stack is available.
	-- Each operation is protected to avoid an error loop during cleanup/reporting.
	pcall(HideIndicator)

	-- Retail's CallErrorHandler adjusts the callstack height and dispatches to
	-- geterrorhandler(). The direct path keeps error reporting available if that
	-- Blizzard helper is unavailable during an unusual load/API failure.
	if type(CallErrorHandler) == "function" then
		pcall(CallErrorHandler, message)
	else
		local foundHandler, errorHandler = pcall(geterrorhandler)
		if foundHandler and type(errorHandler) == "function" then
			pcall(errorHandler, message)
		end
	end

	return message
end

local function RunCoreCallback(callback, ...)
	-- Retail uses Lua 5.1-style xpcall, so capture arguments in a closure rather
	-- than relying on xpcall argument forwarding.
	local arguments = { ... }
	local argumentCount = select("#", ...)
	local function invoke()
		return callback(unpack(arguments, 1, argumentCount))
	end

	return xpcall(invoke, ReportCoreError)
end

local function IsHostileLivingTarget()
	return UnitExists(TARGET_UNIT) and not UnitIsDeadOrGhost(TARGET_UNIT) and UnitCanAttack(PLAYER_UNIT, TARGET_UNIT)
end

local function ApplyExecuteHealthAlpha()
	local color = UnitHealthPercent(TARGET_UNIT, true, executeHealthCurve)
	local alpha = select(4, color:GetRGBA())
	icon:SetAlpha(alpha)
	glowContainer:SetAlpha(alpha)
end

local function GetOwnSpellCooldownDuration()
	-- ignoreGCD keeps this watcher on SW:D cooldown/recharge rather than GCD.
	return C_Spell.GetSpellCooldownDuration(SPELL_ID, true)
end

local function UpdateSpellCooldownState()
	-- isOnGCD is only reliable while handling SPELL_UPDATE_COOLDOWN. Both it
	-- and isActive are documented NeverSecret fields, so this cache is safe to
	-- use from the other indicator events.
	local cooldownInfo = C_Spell.GetSpellCooldown(SPELL_ID)
	spellOnGCD = cooldownInfo and cooldownInfo.isOnGCD and true or false
	ownSpellCooldownActive = cooldownInfo and cooldownInfo.isActive and not spellOnGCD
end

local function IsSpellReadyNow()
	-- A charge recharge can have a DurationObject while another charge remains
	-- usable. The cached cooldown state represents only an unavailable SW:D.
	return not ownSpellCooldownActive
end

local function WatchSpellCooldown()
	local duration = GetOwnSpellCooldownDuration()
	if not duration then
		duration = C_Spell.GetSpellChargeDuration(SPELL_ID)
	end

	if duration then
		cooldownWatcher:SetCooldownFromDurationObject(duration)
	end
end

UpdateIndicator = function()
	-- Events can arrive before PLAYER_LOGIN. Until initialization succeeds, keep
	-- the early-hidden frame fail-closed instead of evaluating partial state.
	if not addonInitialized then
		HideIndicator()
		return
	end

	if testMode then
		icon:SetDesaturated(false)
		icon:SetAlpha(1)
		icon:Show()
		glowContainer:SetAlpha(1)
		indicator:Show()
		ShowGlow()
		return
	end

	if not UnitAffectingCombat(PLAYER_UNIT) or playerClass ~= PRIEST_CLASS or not IsHostileLivingTarget() then
		HideIndicator()
		return
	end

	local maximumHealth = UnitHealthMax(TARGET_UNIT)
	if not issecretvalue(maximumHealth) and maximumHealth == 0 then
		HideIndicator()
		return
	end

	if not IsSpellReadyNow() then
		HideIndicator()
		WatchSpellCooldown()
		return
	end

	ApplyExecuteHealthAlpha()
	icon:SetDesaturated(false)
	indicator:Show()
	ShowGlow()

	-- Cooldown and GCD are handled above. Preserve learned/resource usability.
	local usable, insufficientPower = C_Spell.IsSpellUsable(SPELL_ID)
	icon:SetShown(usable)
	if database.glowEnabled then
		-- Keep glow and icon synchronized through the same visual-safe operation.
		glowContainer:SetShown(usable)
	end
	if spellOnGCD and not insufficientPower then
		-- The cooldown-event cache proves that the spell cooldown is GCD-only.
		-- Keep the documented insufficient-power usability gate intact.
		icon:Show()
		if database.glowEnabled then
			glowContainer:Show()
		end
	end
	WatchSpellCooldown()
end

RequestIndicatorUpdate = function()
	RunCoreCallback(UpdateIndicator)
end

local function CreateCheckbox(parent, label, x, y)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

	local text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
	text:SetText(label)

	return checkbox
end

local function CloseSettings()
	SetTestMode(false)
	if settings then
		settings:Hide()
	end
end

local function CreateSettingsWindow()
	if settings then
		return
	end

	settings = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	settings:SetSize(270, 234)
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

	local closeButton = CreateFrame("Button", nil, settings)
	closeButton:SetSize(24, 24)
	closeButton:SetPoint("TOPRIGHT", settings, "TOPRIGHT", -8, -8)
	closeButton:SetNormalFontObject(GameFontNormal)
	closeButton:SetText("X")
	closeButton:SetScript("OnClick", CloseSettings)

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

	glowCheck = CreateCheckbox(settings, "Свечение", 16, -168)
	glowCheck:SetScript("OnClick", function(self)
		SetGlowEnabled(self:GetChecked())
	end)

	local resetButton = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
	resetButton:SetSize(100, 22)
	resetButton:SetPoint("TOPLEFT", settings, "TOPLEFT", 16, -198)
	resetButton:SetText("Сбросить")
	resetButton:SetScript("OnClick", function()
		database.point = DATABASE_DEFAULTS.point
		database.relativePoint = DATABASE_DEFAULTS.relativePoint
		database.x = DATABASE_DEFAULTS.x
		database.y = DATABASE_DEFAULTS.y
		database.size = DATABASE_DEFAULTS.size
		ApplySavedPosition()
		SetIconSize(DATABASE_DEFAULTS.size)
		sizeSlider:SetValue(DATABASE_DEFAULTS.size)
	end)

	settings:SetScript("OnShow", function()
		lockedCheck:SetChecked(database.locked)
		testCheck:SetChecked(testMode)
		glowCheck:SetChecked(database.glowEnabled)
		sizeSlider:SetValue(database.size)
	end)
	settings:Hide()
end

InitializeAddon = function()
	if addonInitialized then
		return true
	end

	InitializeDatabase()
	ApplySavedPosition()
	SetIconSize(database.size)
	SetLocked(database.locked)
	CreateSettingsWindow()
	playerClass = select(2, UnitClass(PLAYER_UNIT))
	addonInitialized = settings ~= nil
	return addonInitialized
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
	RequestIndicatorUpdate()
end)

SLASH_SHADOWWORDDEATHEXECUTE1 = "/swd"
local function ToggleSettings()
	if not InitializeAddon() then
		HideIndicator()
		return
	end

	if settings:IsShown() then
		CloseSettings()
	else
		settings:Show()
	end
end

SlashCmdList.SHADOWWORDDEATHEXECUTE = function()
	RunCoreCallback(ToggleSettings)
end

indicator:RegisterEvent("PLAYER_LOGIN")
indicator:RegisterEvent("PLAYER_ENTERING_WORLD")
indicator:RegisterEvent("PLAYER_TARGET_CHANGED")
indicator:RegisterEvent("PLAYER_REGEN_DISABLED")
indicator:RegisterEvent("PLAYER_REGEN_ENABLED")
indicator:RegisterUnitEvent("UNIT_HEALTH", TARGET_UNIT)
indicator:RegisterUnitEvent("UNIT_MAXHEALTH", TARGET_UNIT)
indicator:RegisterUnitEvent("UNIT_FLAGS", TARGET_UNIT)
indicator:RegisterUnitEvent("UNIT_FACTION", TARGET_UNIT)
indicator:RegisterUnitEvent("UNIT_POWER_UPDATE", PLAYER_UNIT)
indicator:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", PLAYER_UNIT)
indicator:RegisterEvent("SPELL_UPDATE_COOLDOWN")
indicator:RegisterEvent("SPELL_UPDATE_USABLE")
indicator:RegisterEvent("SPELL_UPDATE_CHARGES")
indicator:RegisterEvent("SPELLS_CHANGED")

local targetEvents = {
	UNIT_HEALTH = true,
	UNIT_MAXHEALTH = true,
	UNIT_FLAGS = true,
	UNIT_FACTION = true,
}

local playerEvents = {
	UNIT_POWER_UPDATE = true,
	UNIT_SPELLCAST_SUCCEEDED = true,
}

local function HandleEvent(event, unit)
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		InitializeAddon()
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		UpdateSpellCooldownState()
	elseif targetEvents[event] and unit ~= TARGET_UNIT then
		return
	elseif playerEvents[event] and unit ~= PLAYER_UNIT then
		return
	end

	RequestIndicatorUpdate()
end

indicator:SetScript("OnEvent", function(_, event, unit)
	RunCoreCallback(HandleEvent, event, unit)
end)
