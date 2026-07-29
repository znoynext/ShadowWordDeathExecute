local SPELL_ID = 32379 -- Shadow Word: Death
local EXECUTE_THRESHOLD = 0.20
local DEFAULT_SIZE = 48
local MIN_SIZE = 24
local MAX_SIZE = 128
local MAX_OFFSET = 10000

local GLOW_NONE = "none"
local GLOW_BLIZZARD = "blizzard"
local GLOW_PULSE = "pulse"
local GLOW_STRONG = "strong"

local glowOptions = {
	{ value = GLOW_NONE, text = "Нет" },
	{ value = GLOW_BLIZZARD, text = "Blizzard" },
	{ value = GLOW_PULSE, text = "Pulse" },
	{ value = GLOW_STRONG, text = "Strong Pulse" },
}

local validGlowModes = {
	[GLOW_NONE] = true,
	[GLOW_BLIZZARD] = true,
	[GLOW_PULSE] = true,
	[GLOW_STRONG] = true,
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

-- The container receives the same Secret-safe alpha as the icon. Its child
-- animations can pulse without ever reimplementing the protected HP check.
local glowContainer = CreateFrame("Frame", nil, indicator)
glowContainer:SetAllPoints()
glowContainer:SetFrameLevel(indicator:GetFrameLevel() + 1)
glowContainer:Hide()

local pulseGlow = glowContainer:CreateTexture(nil, "ARTWORK")
pulseGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
pulseGlow:SetBlendMode("ADD")
pulseGlow:SetVertexColor(0.72, 0.35, 1.0, 1.0)
pulseGlow:SetPoint("TOPLEFT", indicator, "TOPLEFT", -4, 4)
pulseGlow:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", 4, -4)
pulseGlow:Hide()

local strongPulseGlow = glowContainer:CreateTexture(nil, "ARTWORK")
strongPulseGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
strongPulseGlow:SetBlendMode("ADD")
strongPulseGlow:SetVertexColor(0.85, 0.45, 1.0, 1.0)
strongPulseGlow:SetPoint("TOPLEFT", indicator, "TOPLEFT", -10, 10)
strongPulseGlow:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", 10, -10)
strongPulseGlow:Hide()

local function CreatePulseAnimation(texture, lowAlpha, highAlpha, halfCycle)
	local animation = texture:CreateAnimationGroup()
	animation:SetLooping("REPEAT")

	local fadeIn = animation:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(lowAlpha)
	fadeIn:SetToAlpha(highAlpha)
	fadeIn:SetDuration(halfCycle)
	fadeIn:SetOrder(1)

	local fadeOut = animation:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(highAlpha)
	fadeOut:SetToAlpha(lowAlpha)
	fadeOut:SetDuration(halfCycle)
	fadeOut:SetOrder(2)

	return animation, lowAlpha
end

local pulseAnimation, pulseRestingAlpha = CreatePulseAnimation(pulseGlow, 0.30, 0.80, 0.50)
local strongPulseAnimation, strongPulseRestingAlpha = CreatePulseAnimation(strongPulseGlow, 0.35, 1.00, 0.40)

local blizzardGlow
local activeGlowMode
local glowActive = false

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
local glowDropDown
local testMode = false
local ownSpellCooldownActive = false
local spellOnGCD = false
local UpdateIndicator
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
	database.point = validPoints[database.point] and database.point or "CENTER"
	database.relativePoint = validPoints[database.relativePoint] and database.relativePoint or "CENTER"
	database.x = ClampNumber(database.x, -MAX_OFFSET, MAX_OFFSET, 0)
	database.y = ClampNumber(database.y, -MAX_OFFSET, MAX_OFFSET, 0)
	database.size = ClampNumber(database.size, MIN_SIZE, MAX_SIZE, DEFAULT_SIZE)
	if type(database.locked) ~= "boolean" then
		database.locked = true
	end
	database.glow = validGlowModes[database.glow] and database.glow or GLOW_NONE
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

local function StopAllGlowEffects()
	if pulseAnimation:IsPlaying() then
		pulseAnimation:Stop()
	end
	pulseGlow:SetAlpha(pulseRestingAlpha)
	pulseGlow:Hide()

	if strongPulseAnimation:IsPlaying() then
		strongPulseAnimation:Stop()
	end
	strongPulseGlow:SetAlpha(strongPulseRestingAlpha)
	strongPulseGlow:Hide()

	if blizzardGlow then
		blizzardGlow.ProcStartAnim:Stop()
		blizzardGlow.ProcLoop:Stop()
		blizzardGlow:Hide()
	end
end

local function CreateBlizzardGlow()
	if blizzardGlow or not ActionButtonSpellAlertMixin then
		return blizzardGlow
	end

	-- This is Blizzard_ActionBar's Retail proc-glow template. It is purely
	-- visual and does not turn this indicator into a secure action button.
	blizzardGlow = CreateFrame("Frame", nil, glowContainer, "ActionButtonSpellAlertTemplate")
	blizzardGlow:SetPoint("CENTER", indicator, "CENTER")
	UpdateGlowSize()
	return blizzardGlow
end

local function StartBlizzardGlow()
	local frame = CreateBlizzardGlow()
	if not frame then
		return
	end

	frame:Show()
	frame.ProcStartAnim:Stop()
	frame.ProcLoop:Stop()
	frame.ProcStartAnim:Play()
end

local function StartPulseGlow(texture, animation, restingAlpha)
	texture:SetAlpha(restingAlpha)
	texture:Show()
	if not animation:IsPlaying() then
		animation:Play()
	end
end

local function HideGlow()
	glowActive = false
	activeGlowMode = nil
	StopAllGlowEffects()
	glowContainer:Hide()
end

local function ShowGlow()
	local mode = database.glow
	if mode == GLOW_NONE then
		HideGlow()
		return
	end

	if not glowActive then
		glowActive = true
		glowContainer:Show()
	end

	if activeGlowMode == mode then
		return
	end

	StopAllGlowEffects()
	activeGlowMode = mode

	if mode == GLOW_BLIZZARD then
		StartBlizzardGlow()
	elseif mode == GLOW_PULSE then
		StartPulseGlow(pulseGlow, pulseAnimation, pulseRestingAlpha)
	elseif mode == GLOW_STRONG then
		StartPulseGlow(strongPulseGlow, strongPulseAnimation, strongPulseRestingAlpha)
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
	HideGlow()
	indicator:Hide()
end

local function IsHostileLivingTarget()
	return UnitExists("target") and not UnitIsDeadOrGhost("target") and UnitCanAttack("player", "target")
end

local function ApplyExecuteHealthAlpha()
	local color = UnitHealthPercent("target", true, executeHealthCurve)
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
	if testMode then
		icon:SetDesaturated(false)
		icon:SetAlpha(1)
		icon:Show()
		glowContainer:SetAlpha(1)
		indicator:Show()
		ShowGlow()
		return
	end

	if not UnitAffectingCombat("player") or select(2, UnitClass("player")) ~= "PRIEST" or not IsHostileLivingTarget() then
		HideIndicator()
		return
	end

	local maximumHealth = UnitHealthMax("target")
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
	if glowActive then
		-- Keep glow and icon synchronized through the same visual-safe operation.
		glowContainer:SetShown(usable)
	end
	if spellOnGCD and not insufficientPower then
		-- The cooldown-event cache proves that the spell cooldown is GCD-only.
		-- Keep the documented insufficient-power usability gate intact.
		icon:Show()
		if glowActive then
			glowContainer:Show()
		end
	end
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

local function GetGlowText(mode)
	for _, option in ipairs(glowOptions) do
		if option.value == mode then
			return option.text
		end
	end

	return "Нет"
end

local function RefreshGlowDropDown()
	if glowDropDown then
		UIDropDownMenu_SetSelectedValue(glowDropDown, database.glow)
		UIDropDownMenu_SetText(glowDropDown, GetGlowText(database.glow))
	end
end

local function SetGlowMode(mode)
	database.glow = validGlowModes[mode] and mode or GLOW_NONE
	RefreshGlowDropDown()
	UpdateIndicator()
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
	settings:SetSize(270, 262)
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

	local glowLabel = settings:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	glowLabel:SetPoint("TOPLEFT", settings, "TOPLEFT", 16, -168)
	glowLabel:SetText("Свечение:")

	glowDropDown = CreateFrame("Frame", nil, settings, "UIDropDownMenuTemplate")
	glowDropDown:SetPoint("TOPLEFT", settings, "TOPLEFT", 4, -184)
	UIDropDownMenu_SetWidth(glowDropDown, 170)
	UIDropDownMenu_Initialize(glowDropDown, function(_, level)
		if level ~= 1 then
			return
		end

		for _, option in ipairs(glowOptions) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option.text
			info.value = option.value
			info.checked = database.glow == option.value
			info.func = function(button)
				SetGlowMode(button.value)
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)
	RefreshGlowDropDown()

	local resetButton = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
	resetButton:SetSize(100, 22)
	resetButton:SetPoint("TOPLEFT", settings, "TOPLEFT", 16, -226)
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
		RefreshGlowDropDown()
	end)
	settings:Hide()
end

InitializeAddon = function()
	if not addonInitialized then
		InitializeDatabase()
		ApplySavedPosition()
		SetIconSize(database.size)
		SetLocked(database.locked)
	end

	CreateSettingsWindow()
	addonInitialized = true
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
	InitializeAddon()

	if settings:IsShown() then
		CloseSettings()
	else
		settings:Show()
	end
end

indicator:RegisterEvent("PLAYER_LOGIN")
indicator:RegisterEvent("PLAYER_ENTERING_WORLD")
indicator:RegisterEvent("PLAYER_TARGET_CHANGED")
indicator:RegisterEvent("PLAYER_REGEN_DISABLED")
indicator:RegisterEvent("PLAYER_REGEN_ENABLED")
indicator:RegisterUnitEvent("UNIT_HEALTH", "target")
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
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		InitializeAddon()
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		UpdateSpellCooldownState()
	elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS" or event == "UNIT_FACTION") and unit ~= "target" then
		return
	elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_SPELLCAST_SUCCEEDED") and unit ~= "player" then
		return
	end

	UpdateIndicator()
end)
