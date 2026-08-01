-- Compact WoW API model for release-critical execute-indicator behavior.
-- This is deliberately not a general test framework or a replacement for a
-- live Retail smoke test.

local ADDON_DIRECTORY = "ShadowWordDeathExecute/"
local LOCALE_PATHS = {
	ADDON_DIRECTORY .. "Locales/enUS.lua",
	ADDON_DIRECTORY .. "Locales/ruRU.lua",
}
local ADDON_PATH = ADDON_DIRECTORY .. "ShadowWordDeathExecute.lua"

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function newAnimation()
	local animation = {}

	function animation:Play()
		self.playing = true
	end

	function animation:Stop()
		self.playing = false
	end

	return animation
end

local function newRegion()
	local region = { alpha = 1, shown = true }

	function region:Hide()
		self.shown = false
	end

	function region:Show()
		self.shown = true
	end

	function region:SetShown(shown)
		self.shown = shown and true or false
	end

	function region:SetAlpha(alpha)
		self.alpha = alpha
	end

	function region:SetAllPoints() end

	function region:SetPoint() end

	function region:SetSize() end

	function region:SetHeight() end

	function region:SetTexture() end

	function region:SetColorTexture() end

	function region:SetDesaturated(desaturated)
		self.desaturated = desaturated
	end

	function region:SetText(text)
		self.text = text
	end

	return region
end

local function newFrame(model, frameType, parent, template)
	local frame = {
		frameType = frameType,
		parent = parent,
		template = template,
		frameLevel = 1,
		height = 0,
		shown = true,
		width = 0,
	}

	function frame:SetSize(width, height)
		self.width = width
		self.height = height
	end

	function frame:GetWidth()
		return self.width
	end

	function frame:GetHeight()
		return self.height
	end

	function frame:SetPoint(point, relativeTo, relativePoint, x, y)
		self.point = { point, relativeTo, relativePoint, x, y }
	end

	function frame:SetAllPoints() end

	function frame:GetPoint()
		if self.point then
			return unpack(self.point)
		end
		return "CENTER", UIParent, "CENTER", 0, 0
	end

	function frame:ClearAllPoints()
		self.point = nil
	end

	function frame:SetMovable() end

	function frame:SetClampedToScreen() end

	function frame:RegisterForDrag() end

	function frame:RegisterEvent() end

	function frame:RegisterUnitEvent() end

	function frame:SetFrameLevel(level)
		self.frameLevel = level
	end

	function frame:GetFrameLevel()
		return self.frameLevel
	end

	function frame:EnableMouse(enabled)
		self.mouseEnabled = enabled
	end

	function frame:StartMoving() end

	function frame:StopMovingOrSizing() end

	function frame:Hide()
		self.shown = false
	end

	function frame:Show()
		self.shown = true
		if self.scripts and self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end

	function frame:IsShown()
		if self.isSettingsWindow and model.state.raiseSettingsError then
			error("model slash failure")
		end

		return self.shown
	end

	function frame:SetShown(shown)
		self.shown = shown and true or false
	end

	function frame:SetAlpha(alpha)
		self.alpha = alpha
	end

	function frame:SetBackdrop() end

	function frame:SetBackdropColor() end

	function frame:SetBackdropBorderColor() end

	function frame:SetOrientation() end

	function frame:SetMinMaxValues() end

	function frame:SetValueStep() end

	function frame:SetObeyStepOnDrag() end

	function frame:SetThumbTexture()
		self.thumbTexture = newRegion()
	end

	function frame:GetThumbTexture()
		return self.thumbTexture
	end

	function frame:SetValue(value)
		self.value = value
		if self.scripts and self.scripts.OnValueChanged then
			self.scripts.OnValueChanged(self, value)
		end
	end

	function frame:SetAutoFocus() end

	function frame:GetText()
		return self.text or ""
	end

	function frame:ClearFocus()
		if self.scripts and self.scripts.OnEditFocusLost then
			self.scripts.OnEditFocusLost(self)
		end
	end

	function frame:SetChecked(checked)
		self.checked = checked and true or false
	end

	function frame:GetChecked()
		return self.checked
	end

	function frame:SetNormalFontObject() end

	function frame:SetText(text)
		self.text = text
	end

	function frame:SetCooldownFromDurationObject(duration)
		self.duration = duration
	end

	function frame:SetScript(scriptName, callback)
		self.scripts = self.scripts or {}
		self.scripts[scriptName] = callback
	end

	function frame:CreateTexture()
		local texture = newRegion()
		self.textures = self.textures or {}
		table.insert(self.textures, texture)
		return texture
	end

	function frame:CreateFontString()
		local fontString = newRegion()
		self.fontStrings = self.fontStrings or {}
		table.insert(self.fontStrings, fontString)
		return fontString
	end

	if template == "ActionButtonSpellAlertTemplate" then
		frame.ProcStartAnim = newAnimation()
		frame.ProcLoop = newAnimation()
	end
	if template == "BackdropTemplate" then
		frame.isSettingsWindow = true
	end

	table.insert(model.frames, frame)
	if template == "UICheckButtonTemplate" then
		table.insert(model.checkboxes, frame)
	end
	return frame
end

local function trigger(indicator, event, unit)
	indicator.scripts.OnEvent(indicator, event, unit)
end

local function boot(savedVariables, hasGlowTemplate, locale)
	local state = {
		class = "PRIEST",
		cooldown = { isActive = false, isOnGCD = false },
		healthPercent = 0.20,
		healthMaximum = 100,
		inCombat = false,
		insufficientPower = false,
		targetExists = false,
		targetIsDead = false,
		usable = true,
	}
	local model = { checkboxes = {}, errorReports = {}, frames = {}, state = state }

	UIParent = newFrame({ checkboxes = {}, frames = {} }, "Frame")
	ActionButtonSpellAlertMixin = hasGlowTemplate == false and nil or {}
	C_CurveUtil = {
		CreateColorCurve = function()
			return {
				AddPoint = function() end,
				SetType = function() end,
			}
		end,
	}
	C_Spell = {
		GetSpellChargeDuration = function()
			return state.chargeDuration
		end,
		GetSpellCooldown = function()
			return state.cooldown
		end,
		GetSpellCooldownDuration = function()
			return state.cooldownDuration
		end,
		GetSpellTexture = function()
			return "test-texture"
		end,
		IsSpellUsable = function()
			return state.usable, state.insufficientPower
		end,
	}
	CreateColor = function(red, green, blue, alpha)
		return {
			GetRGBA = function()
				return red, green, blue, alpha
			end,
		}
	end
	CreateFrame = function(frameType, _, parent, template)
		return newFrame(model, frameType, parent, template)
	end
	Enum = { LuaCurveType = { Step = 1 } }
	GameFontNormal = {}
	GetLocale = function()
		return locale or "enUS"
	end
	geterrorhandler = function()
		return function(message)
			table.insert(model.errorReports, message)
			if state.raiseErrorHandlerError then
				error("model error-handler failure")
			end
		end
	end
	CallErrorHandler = function(message)
		return geterrorhandler()(message)
	end
	issecretvalue = function()
		return false
	end
	SlashCmdList = {}
	SWDExecuteDB = savedVariables or {}
	UnitAffectingCombat = function()
		return state.inCombat
	end
	UnitCanAttack = function()
		return state.targetExists
	end
	UnitClass = function()
		return "Priest", state.class
	end
	UnitExists = function()
		return state.targetExists
	end
	UnitHealthMax = function()
		return state.healthMaximum
	end
	UnitHealthPercent = function()
		local alpha = state.healthPercent <= 0.20 and 1 or 0
		return CreateColor(1, 1, 1, alpha)
	end
	UnitIsDeadOrGhost = function()
		return state.targetIsDead
	end

	local addon = {}
	for _, path in ipairs(LOCALE_PATHS) do
		local chunk, loadError = loadfile(path)
		expect(chunk, loadError)
		chunk("ShadowWordDeathExecute", addon)
	end
	local addonChunk, loadError = loadfile(ADDON_PATH)
	expect(addonChunk, loadError)
	addonChunk("ShadowWordDeathExecute", addon)

	local indicator = model.frames[1]
	expect(not indicator.shown, "startup must keep the indicator hidden")
	trigger(indicator, "PLAYER_LOGIN")
	return model, indicator, addon
end

local function findGlowContainer(model, indicator)
	for _, frame in ipairs(model.frames) do
		if frame.parent == indicator and frame.frameType == "Frame" and not frame.template then
			return frame
		end
	end
end

local function setExecuteTarget(state)
	state.inCombat = true
	state.targetExists = true
	state.targetIsDead = false
	state.healthPercent = 0.20
	state.usable = true
	state.insufficientPower = false
end

local REQUIRED_LOCALE_KEYS = {
	"TITLE",
	"LOCK",
	"TEST",
	"POSITION",
	"X",
	"Y",
	"SIZE",
	"GLOW",
	"RESET",
}

local function findSettings(model)
	for _, frame in ipairs(model.frames) do
		if frame.isSettingsWindow then
			return frame
		end
	end
end

local function checkLocale(locale, expected)
	local localeModel, _, addon = boot({}, true, locale)
	local settings = findSettings(localeModel)
	expect(settings, "settings UI must be created for " .. locale)

	for _, key in ipairs(REQUIRED_LOCALE_KEYS) do
		expect(addon.Locales.enUS[key], "enUS locale must contain " .. key)
		expect(addon.Locales.ruRU[key], "ruRU locale must contain " .. key)
	end

	expect(settings.fontStrings[1].text == expected.TITLE, "settings title must use the selected locale")
	expect(localeModel.checkboxes[1].fontStrings[1].text == expected.LOCK, "lock label must use the selected locale")
	expect(localeModel.checkboxes[2].fontStrings[1].text == expected.TEST, "test label must use the selected locale")
	expect(settings.fontStrings[2].text == expected.POSITION, "position label must use the selected locale")
	expect(settings.fontStrings[3].text == expected.X, "X label must use the selected locale")
	expect(settings.fontStrings[4].text == expected.Y, "Y label must use the selected locale")
	expect(settings.fontStrings[5].text == expected.SIZE, "size label must use the selected locale")
	expect(localeModel.checkboxes[3].fontStrings[1].text == expected.GLOW, "glow label must use the selected locale")
	local resetButton
	for _, frame in ipairs(localeModel.frames) do
		if frame.parent == settings and frame.template == "UIPanelButtonTemplate" then
			resetButton = frame
			break
		end
	end
	expect(resetButton and resetButton.text == expected.RESET, "reset label must use the selected locale")
end

local enUS = {
	TITLE = "Shadow Word: Death Execute",
	LOCK = "Lock",
	TEST = "Test",
	POSITION = "Position",
	X = "X:",
	Y = "Y:",
	SIZE = "Size",
	GLOW = "Glow",
	RESET = "Reset",
}
local ruRU = {
	TITLE = "Shadow Word: Death Execute",
	LOCK = "Закрепить",
	TEST = "Тест",
	POSITION = "Позиция",
	X = "X:",
	Y = "Y:",
	SIZE = "Размер",
	GLOW = "Свечение",
	RESET = "Сбросить",
}

checkLocale("enUS", enUS)
checkLocale("ruRU", ruRU)
checkLocale("deDE", enUS)

local model, indicator = boot({ size = 40, x = 17, y = -23 })
local state = model.state
local icon = indicator.textures[1]
SlashCmdList.SHADOWWORDDEATHEXECUTE()
local inputs = {}
for _, frame in ipairs(model.frames) do
	if frame.frameType == "EditBox" then
		table.insert(inputs, frame)
	end
end
expect(#inputs == 4, "settings must create X/Y edit boxes for position and size")
expect(inputs[1].text == "17" and inputs[2].text == "-23", "saved coordinates must populate the edit boxes")
expect(inputs[3].text == "40" and inputs[4].text == "40", "legacy square size must migrate to separate size inputs")
expect(SWDExecuteDB.size == nil and SWDExecuteDB.width == 40 and SWDExecuteDB.height == 40, "legacy size migration must persist dimensions")

inputs[1]:SetText("32")
inputs[1]:ClearFocus()
expect(indicator.point[4] == 32 and indicator.point[5] == -23, "manual coordinates must update the indicator position")
inputs[3]:SetText("64")
inputs[4]:SetText("72")
inputs[4]:ClearFocus()
expect(indicator.width == 64 and indicator.height == 72, "manual width and height must update the indicator size")

setExecuteTarget(state)
trigger(indicator, "SPELL_UPDATE_COOLDOWN")
expect(indicator.shown and icon.shown and icon.alpha == 1, "ready execute target must show the icon")

state.healthPercent = 0.21
trigger(indicator, "UNIT_HEALTH", "target")
expect(indicator.shown and icon.alpha == 0, "health above execute range must be visually hidden")

state.healthPercent = 0.20
state.cooldown = { isActive = true, isOnGCD = false }
trigger(indicator, "SPELL_UPDATE_COOLDOWN")
expect(not indicator.shown, "own Shadow Word: Death cooldown must hide the indicator")

state.cooldown = { isActive = false, isOnGCD = false }
trigger(indicator, "SPELL_UPDATE_COOLDOWN")
expect(indicator.shown, "indicator must recover after own cooldown")

state.cooldown = { isActive = true, isOnGCD = true }
state.usable = false
state.insufficientPower = false
trigger(indicator, "SPELL_UPDATE_COOLDOWN")
expect(indicator.shown and icon.shown, "GCD alone must not hide the indicator")

state.cooldown = { isActive = false, isOnGCD = false }
state.cooldownDuration = {}
state.usable = true
trigger(indicator, "SPELL_UPDATE_COOLDOWN")
expect(indicator.shown, "a recharge DurationObject with an available charge must stay usable")

state.inCombat = false
state.targetExists = false
local testCheckbox = model.checkboxes[2]
testCheckbox:SetChecked(true)
testCheckbox.scripts.OnClick(testCheckbox)
expect(indicator.shown and icon.shown, "test mode must bypass combat and target gates")

for legacyGlow, expectedEnabled in pairs({ none = false, blizzard = true, pulse = true, strong = true }) do
	local database = { glow = legacyGlow }
	boot(database)
	expect(database.glowEnabled == expectedEnabled, "legacy glow migration failed for " .. legacyGlow)
	expect(database.glow == nil, "legacy glow key must be removed after migration")
end

local noGlowModel, noGlowIndicator = boot({ glowEnabled = true }, false)
setExecuteTarget(noGlowModel.state)
trigger(noGlowIndicator, "SPELL_UPDATE_COOLDOWN")
expect(noGlowIndicator.shown, "missing optional glow must not hide the execute indicator")

local errorModel, errorIndicator = boot({ glowEnabled = true })
local errorState = errorModel.state
local errorGlowContainer = findGlowContainer(errorModel, errorIndicator)
expect(errorGlowContainer, "model must find the glow container")

setExecuteTarget(errorState)
trigger(errorIndicator, "SPELL_UPDATE_COOLDOWN")
expect(errorIndicator.shown and errorGlowContainer.shown, "error model must show the indicator and glow before a failure")

errorState.raiseUpdateError = true
UnitHealthPercent = function()
	if errorState.raiseUpdateError then
		error("model update failure")
	end

	return CreateColor(1, 1, 1, 1)
end
trigger(errorIndicator, "UNIT_HEALTH", "target")
expect(not errorIndicator.shown, "core update failure must hide the indicator")
expect(not errorGlowContainer.shown, "core update failure must hide the glow")
expect(#errorModel.errorReports == 1, "core update failure must reach the standard error handler once")
expect(string.find(errorModel.errorReports[1], "model update failure", 1, true), "core update failure must not be swallowed before error reporting")

errorState.raiseErrorHandlerError = true
trigger(errorIndicator, "UNIT_HEALTH", "target")
expect(#errorModel.errorReports == 2, "a broken error handler must not trigger an error-report loop")

errorState.raiseErrorHandlerError = false
errorState.raiseUpdateError = false
trigger(errorIndicator, "UNIT_HEALTH", "target")
expect(errorIndicator.shown, "normal updates must recover after a core failure")
expect(#errorModel.errorReports == 2, "successful recovery must not emit another error")

errorState.raiseSettingsError = true
SlashCmdList.SHADOWWORDDEATHEXECUTE()
expect(not errorIndicator.shown, "slash callback failure must hide the indicator")
expect(#errorModel.errorReports == 3, "slash callback failure must reach the standard error handler once")
errorState.raiseSettingsError = false

print("ShadowWordDeathExecute model checks passed.")
