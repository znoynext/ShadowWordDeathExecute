-- Compact WoW API model for release-critical execute-indicator behavior.
-- This is deliberately not a general test framework or a replacement for a
-- live Retail smoke test.

local ADDON_PATH = "ShadowWordDeathExecute/ShadowWordDeathExecute.lua"

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

local function newFrame(model, frameType, template)
	local frame = {
		frameType = frameType,
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
	end

	function frame:IsShown()
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
		return newRegion()
	end

	if template == "ActionButtonSpellAlertTemplate" then
		frame.ProcStartAnim = newAnimation()
		frame.ProcLoop = newAnimation()
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

local function boot(savedVariables, hasGlowTemplate)
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
	local model = { checkboxes = {}, frames = {}, state = state }

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
	CreateFrame = function(frameType, _, _, template)
		return newFrame(model, frameType, template)
	end
	Enum = { LuaCurveType = { Step = 1 } }
	GameFontNormal = {}
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

	dofile(ADDON_PATH)

	local indicator = model.frames[1]
	expect(not indicator.shown, "startup must keep the indicator hidden")
	trigger(indicator, "PLAYER_LOGIN")
	return model, indicator
end

local function setExecuteTarget(state)
	state.inCombat = true
	state.targetExists = true
	state.targetIsDead = false
	state.healthPercent = 0.20
	state.usable = true
	state.insufficientPower = false
end

local model, indicator = boot({})
local state = model.state
local icon = indicator.textures[1]

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

print("ShadowWordDeathExecute model checks passed.")
