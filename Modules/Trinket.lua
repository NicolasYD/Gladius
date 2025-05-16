local Gladius = _G.Gladius
if not Gladius then
	DEFAULT_CHAT_FRAME:AddMessage(format("Module %s requires Gladius", "Trinket"))
end
local L = Gladius.L
local LSM

-- Global Functions
local _G = _G
local pairs = pairs
local strfind = string.find
local strformat = string.format

local CreateFrame = CreateFrame
local GetSpellInfo = C_Spell.GetSpellInfo
local GetSpellTexture = C_Spell.GetSpellTexture
local IsInInstance = IsInInstance
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitLevel = UnitLevel
local UnitName = UnitName

local Trinket = Gladius:NewModule("Trinket", false, true, {
	trinketAttachTo = "Frame",
	trinketAnchor = "TOPLEFT",
	trinketRelativePoint = "TOPRIGHT",
	trinketGridStyleIcon = false,
	trinketGridStyleIconColor = {r = 0, g = 1, b = 0, a = 1},
	trinketGridStyleIconUsedColor = {r = 1, g = 0, b = 0, a = 1},
	trinketAdjustSize = false,
	trinketSize = 50,
	trinketOffsetX = 1,
	trinketOffsetY = 0,
	trinketFrameLevel = 1,
	trinketIconCrop = false,
	trinketGloss = false,
	trinketGlossColor = {r = 1, g = 1, b = 1, a = 0.4},
	trinketCooldown = true,
	trinketCooldownReverse = false,
	trinketFaction = false,
	trinketDetached = false
},
{
	"Trinket icon", "Grid style health bar", "Grid style power bar"
})


-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ Helper Functions @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- The helper functions below were copied from the AddOn WeakAuras by The WeakAuras Team
local UnitAura = UnitAura
if UnitAura == nil then
  --- Deprecated in 10.2.5
  UnitAura = function(unitToken, index, filter)
		local auraData = C_UnitAuras.GetAuraDataByIndex(unitToken, index, filter)
		if not auraData then
			return nil;
		end

		return AuraUtil.UnpackAuraData(auraData)
	end
end

-- Unit Aura functions that return info about the first Aura matching the spellName or spellID given on the unit.
local WA_GetUnitAura = function(unit, spell, filter)
  if filter and not filter:upper():find("FUL") then
      filter = filter.."|HELPFUL"
  end
  for i = 1, 255 do
    local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, filter)
    if not name then return end
    if spell == spellId or spell == name then
      return UnitAura(unit, i, filter)
    end
  end
end

local WA_GetUnitDebuff = function(unit, spell, filter)
  filter = filter and filter.."|HARMFUL" or "HARMFUL"
  return WA_GetUnitAura(unit, spell, filter)
end
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


function Trinket:OnEnable()
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("ARENA_CROWD_CONTROL_SPELL_UPDATE")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
	LSM = Gladius.LSM
	if not self.frame then
		self.frame = { }
	end
end

function Trinket:OnDisable()
	self:UnregisterAllEvents()
	for unit in pairs(self.frame) do
		self.frame[unit]:SetAlpha(0)
	end
end

function Trinket:GetAttachTo()
	return Gladius.db.trinketAttachTo
end

function Trinket:IsDetached()
	return Gladius.db.trinketDetached
end

function Trinket:GetFrame(unit)
	return self.frame[unit]
end

--[[function Trinket:SetTemplate(template)
	if template == 1 then
		-- reset width
		if Gladius.db.targetBarAttachTo == "HealthBar" and not Gladius.db.healthBarAdjustWidth then
			Gladius.db.healthBarAdjustWidth = true
		end
		-- reset to default
		for k, v in pairs(self.defaults) do
			Gladius.db[k] = v
		end
	elseif template == 2 then
		if Gladius.db.modules["HealthBar"] then
			if (Gladius.db.healthBarAdjustWidth) then
				Gladius.db.healthBarAdjustWidth = false
				Gladius.db.healthBarWidth = Gladius.db.barWidth - Gladius.db.healthBarHeight
			else
				Gladius.db.healthBarWidth = Gladius.db.healthBarWidth - Gladius.db.healthBarHeight
			end
			Gladius.db.trinketGridStyleIcon = true
			Gladius.db.trinketAdjustHeight = false
			Gladius.db.trinketHeight = Gladius.db.healthBarHeight
			Gladius.db.trinketAttachTo = "HealthBar"
			Gladius.db.trinketAnchor = "TOPLEFT"
			Gladius.db.trinketRelativePoint = "TOPRIGHT"
			Gladius.db.trinketOffsetX = 0
			Gladius.db.trinketOffsetY = 0
		end
	else
		if Gladius.db.modules["PowerBar"] then
			if (Gladius.db.powerBarAdjustWidth) then
				Gladius.db.powerBarAdjustWidth = false
				Gladius.db.powerBarWidth = Gladius.db.powerBarWidth - Gladius.db.powerBarHeight
			else
				Gladius.db.powerBarWidth = Gladius.db.powerBarWidth - Gladius.db.powerBarHeight
			end
			Gladius.db.trinketGridStyleIcon = true
			Gladius.db.trinketAdjustHeight = false
			Gladius.db.trinketHeight = Gladius.db.powerBarHeight
			Gladius.db.trinketAttachTo = "PowerBar"
			Gladius.db.trinketAnchor = "TOPLEFT"
			Gladius.db.trinketRelativePoint = "TOPRIGHT"
			Gladius.db.trinketOffsetX = 0
			Gladius.db.trinketOffsetY = 0
		end
	end
end]]
function Trinket:ARENA_CROWD_CONTROL_SPELL_UPDATE(event, unit, spellID)
	if Gladius.db.trinketFaction then return end
	-- Find Correct Icon ty blizzard
	local _, instanceType = IsInInstance()
	if instanceType ~= "arena" or not strfind(unit, "arena") or strfind(unit, "pet") then
		return
	end
	if (spellID ~= self.frame[unit].spellID) then
		local spellTexture = GetSpellTexture(spellID);
		self.frame[unit].spellID = spellID;
		self.frame[unit].texture:SetTexture(spellTexture);
	end
end
function Trinket:UNIT_AURA(event, unit)
	local _, instanceType = IsInInstance()
	if instanceType ~= "arena" or not strfind(unit, "arena") or strfind(unit, "pet") then
		return
	end
	-- Set Trinket CD on Adaptation
	if WA_GetUnitDebuff(unit, "Adapted") then
		local _,_,_,_,_,t = WA_GetUnitDebuff(unit, "Adapted")
		local g = t-GetTime()
		if g > 59 then
			self:UpdateTrinket(unit, 60)
		end
	end
end

function Trinket:UNIT_SPELLCAST_SUCCEEDED(event, unit, spellLineID, spell)
	local _, instanceType = IsInInstance()
	if instanceType ~= "arena" or not strfind(unit, "arena") or strfind(unit, "pet") then
		return
	end
	-- PVP trinkets
	if spell == 42292 then
		self:UpdateTrinket(unit, 120)
	end
	-- Honorable Medallion
	if spell == 195710 then
		self:UpdateTrinket(unit, 180)
	end
	-- Gladiator's Medallion
	if spell == 208683 then
		self:UpdateTrinket(unit, 120)
	end

	-- Gladiator's Medallion 9.0.1
	if spell == 336126 then
		self:UpdateTrinket(unit, 120)
	end

	local cd = self:GetTrinketCD(unit)
	if cd < 90 then
		-- Every Man For Himself
		if spell == 59752 then
			if self:IsHealer(unit) then
				self:UpdateTrinket(unit, 60)
			else
				self:UpdateTrinket(unit, 90)
			end
		end
	end

	local sharedCD = 30
	if cd < sharedCD then
		-- Stoneform
		if spell == 20594 or spell == 265221 then
			self:UpdateTrinket(unit, sharedCD)
		end
		-- Will of the Forsaken
		if spell == 7744 then
			self:UpdateTrinket(unit, sharedCD)
		end
	end
end

function Trinket:GROUP_ROSTER_UPDATE()
    Trinket:ResetTrinketShuffle()
end


function Trinket:GetTrinketCD(unit)
	local cd = 0
	local startTime, duration = self.frame[unit].cooldown:GetCooldownTimes()
	cd = ((startTime + duration)/1000 - GetTime())
	return cd
end


function Trinket:UpdateTrinket(unit, duration)
	-- grid style icon
	if Gladius.db.trinketGridStyleIcon then
		self.frame[unit].texture:SetVertexColor(Gladius.db.trinketGridStyleIconUsedColor.r, Gladius.db.trinketGridStyleIconUsedColor.g, Gladius.db.trinketGridStyleIconUsedColor.b, Gladius.db.trinketGridStyleIconUsedColor.a)
	end
	-- announcement
	if Gladius.db.announcements.trinket then
		Gladius:Call(Gladius.modules.Announcements, "Send", strformat(L["TRINKET USED: %s (%s)"], UnitName(unit) or "test", UnitClass(unit) or "test"), 2, unit)
	end
	if Gladius.db.announcements.trinket or Gladius.db.trinketGridStyleIcon then
		self.frame[unit].timeleft = duration
		self.frame[unit]:SetScript("OnUpdate", function(f, elapsed)
			self.frame[unit].timeleft = self.frame[unit].timeleft - elapsed
			if self.frame[unit].timeleft <= 0 then
				self.frame[unit].timeleft = nil
				-- trinket
				if Gladius.db.trinketGridStyleIcon then
					self.frame[unit].texture:SetVertexColor(Gladius.db.trinketGridStyleIconColor.r, Gladius.db.trinketGridStyleIconColor.g, Gladius.db.trinketGridStyleIconColor.b, Gladius.db.trinketGridStyleIconColor.a)
				end
				-- announcement
				if Gladius.db.announcements.trinket then
					Gladius:Call(Gladius.modules.Announcements, "Send", strformat(L["TRINKET READY: %s (%s)"], UnitName(unit) or "", UnitClass(unit) or ""), 2, unit)
				end
				self.frame[unit]:SetScript("OnUpdate", nil)
			end
		end)
	end
	-- cooldown
	if(self:IsHealer(unit)) then
		if(duration == 120) then
			duration = 90
		end
	end

	Gladius:Call(Gladius.modules.Timer, "SetTimer", self.frame[unit], duration)
end

function Trinket:IsHealer(unit)
	local id = string.match(unit, "arena(%d)")
	local specID = GetArenaOpponentSpec and GetArenaOpponentSpec(id)
	if(specID) then
		local id, name, description, icon, role, class = GetSpecializationInfoByID(specID)
		if(	
			id == 65 or 	-- Holy Paladin
			id == 105 or 	-- Restoration Druid
			id == 256 or	-- Discipline Priest
			id == 257 or	-- Holy Priest
			id == 264 or 	-- Restoration Shaman
			id == 270 or 	-- Mistweaver Monk
			id == 1468)		-- Preservation Evoker
			then return true
		end
		return false
	end
	return false
end

function Trinket:CreateFrame(unit)
	local button = Gladius.buttons[unit]
	if not button then
		return
	end
	-- create frame
	self.frame[unit] = CreateFrame("CheckButton", "Gladius"..self.name.."Frame"..unit, button, "ActionButtonTemplate")
	self.frame[unit]:EnableMouse(false)
	self.frame[unit]:SetNormalTexture("Interface\\AddOns\\Gladius\\Images\\Gloss")
	self.frame[unit].texture = _G[self.frame[unit]:GetName().."Icon"]
	self.frame[unit].normalTexture = _G[self.frame[unit]:GetName().."NormalTexture"]
	self.frame[unit].cooldown = _G[self.frame[unit]:GetName().."Cooldown"]

	-- secure
	local secure = CreateFrame("Button", "Gladius"..self.name.."SecureButton"..unit, button, "SecureActionButtonTemplate")
	secure:RegisterForClicks("AnyUp", "AnyDown")
	self.frame[unit].secure = secure
end

function Trinket:UpdateColors(unit)
	if Gladius.db.trinketGridStyleIcon then
		if not self.frame[unit].timeleft or (self.frame[unit].timeleft and self.frame[unit].timeleft <= 0) then
			self.frame[unit].texture:SetVertexColor(Gladius.db.trinketGridStyleIconColor.r, Gladius.db.trinketGridStyleIconColor.g, Gladius.db.trinketGridStyleIconColor.b, Gladius.db.trinketGridStyleIconColor.a)
		else
			self.frame[unit].texture:SetVertexColor(Gladius.db.trinketGridStyleIconUsedColor.r, Gladius.db.trinketGridStyleIconUsedColor.g, Gladius.db.trinketGridStyleIconUsedColor.b, Gladius.db.trinketGridStyleIconUsedColor.a)
		end
	end
	self.frame[unit].normalTexture:SetVertexColor(Gladius.db.trinketGlossColor.r, Gladius.db.trinketGlossColor.g, Gladius.db.trinketGlossColor.b, Gladius.db.trinketGloss and Gladius.db.trinketGlossColor.a or 0)
end

function Trinket:Update(unit)
	-- create frame
	if not self.frame[unit] then
		self:CreateFrame(unit)
	end

	local unitFrame = self.frame[unit]

	-- update frame
	unitFrame:ClearAllPoints()
	-- anchor point
	local parent = Gladius:GetParent(unit, Gladius.db.trinketAttachTo)
	unitFrame:SetPoint(Gladius.db.trinketAnchor, parent, Gladius.db.trinketRelativePoint, Gladius.db.trinketOffsetX, Gladius.db.trinketOffsetY)
	-- frame level
	unitFrame:SetFrameLevel(Gladius.db.trinketFrameLevel)
	if Gladius.db.trinketAdjustSize then
		if self:GetAttachTo() == "Frame" then
			local height = false
			-- need to rethink that
			--[[for _, module in pairs(Gladius.modules) do
				if (module:GetAttachTo() == self.name) then
					height = false
				end
			end]]
			if height then
				unitFrame:SetWidth(Gladius.buttons[unit].height)
				unitFrame:SetHeight(Gladius.buttons[unit].height)
			else
				unitFrame:SetWidth(Gladius.buttons[unit].frameHeight)
				unitFrame:SetHeight(Gladius.buttons[unit].frameHeight)
			end
		else
			unitFrame:SetWidth(Gladius:GetModule(self:GetAttachTo()).frame[unit]:GetHeight() or 1)
			unitFrame:SetHeight(Gladius:GetModule(self:GetAttachTo()).frame[unit]:GetHeight() or 1)
		end
	else
		unitFrame:SetWidth(Gladius.db.trinketSize)
		unitFrame:SetHeight(Gladius.db.trinketSize)
	end
	-- set frame mouse-interactable area
	if self:GetAttachTo() == "Frame" and not self.IsDetached() then
		local left, right, top, bottom = Gladius.buttons[unit]:GetHitRectInsets()
		if strfind(Gladius.db.trinketRelativePoint, "LEFT") then
			left = - unitFrame:GetWidth() + Gladius.db.trinketOffsetX
		else
			right = - unitFrame:GetWidth() + - Gladius.db.trinketOffsetX
		end
		-- search for an attached frame
		--[[for _, module in pairs(Gladius.modules) do
			if module.attachTo and module:GetAttachTo() == self.name and module.frame and module.frame[unit] then
				local attachedPoint = module.frame[unit]:GetPoint()
				if strfind(Gladius.db.trinketRelativePoint, "LEFT" and (not attachedPoint or (attachedPoint and strfind(attachedPoint, "RIGHT")))) then
					left = left - module.frame[unit]:GetWidth()
				elseif strfind(Gladius.db.trinketRelativePoint, "RIGHT" and (not attachedPoint or (attachedPoint and strfind(attachedPoint, "LEFT")))) then
					right = right - module.frame[unit]:GetWidth()
				end
			end
		end]]
		-- top / bottom
		if (unitFrame:GetHeight() > Gladius.buttons[unit]:GetHeight()) then
			bottom = -(unitFrame:GetHeight() - Gladius.buttons[unit]:GetHeight()) + Gladius.db.trinketOffsetY
		end
		Gladius.buttons[unit]:SetHitRectInsets(left, right, 0, 0)
		Gladius.buttons[unit].secure:SetHitRectInsets(left, right, 0, 0)
	end
	-- style action button
	unitFrame.normalTexture:SetHeight(unitFrame:GetHeight() + unitFrame:GetHeight() * 0.4)
	unitFrame.normalTexture:SetWidth(unitFrame:GetWidth() + unitFrame:GetWidth() * 0.4)
	unitFrame.normalTexture:ClearAllPoints()
	unitFrame.normalTexture:SetPoint("CENTER", 0, 0)
	unitFrame:SetNormalTexture("Interface\\AddOns\\Gladius\\Images\\Gloss")
	unitFrame.texture:ClearAllPoints()
	unitFrame.texture:SetPoint("TOPLEFT", unitFrame, "TOPLEFT")
	unitFrame.texture:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT")
	if not Gladius.db.trinketIconCrop and not Gladius.db.trinketGridStyleIcon then
		unitFrame.texture:SetTexCoord(0, 1, 0, 1)
	else
		unitFrame.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	unitFrame.normalTexture:SetVertexColor(Gladius.db.trinketGlossColor.r, Gladius.db.trinketGlossColor.g, Gladius.db.trinketGlossColor.b, Gladius.db.trinketGloss and Gladius.db.trinketGlossColor.a or 0)

	-- cooldown
	unitFrame.cooldown.isDisabled = not Gladius.db.trinketCooldown
	unitFrame.cooldown:SetReverse(Gladius.db.trinketCooldownReverse)
	Gladius:Call(Gladius.modules.Timer, "RegisterTimer", unitFrame, Gladius.db.trinketCooldown)

	-- Secure frame
	if self.IsDetached() then
		unitFrame.secure:SetAllPoints(unitFrame)
		unitFrame.secure:SetHeight(unitFrame:GetHeight())
		unitFrame.secure:SetWidth(unitFrame:GetWidth())
		unitFrame.secure:Show()
	else
		unitFrame.secure:Hide()
	end

	-- hide
	unitFrame:SetAlpha(0)
end

function Trinket:Show(unit)
	local testing = Gladius.test
	-- show frame
	self.frame[unit]:SetAlpha(1)
	if Gladius.db.trinketGridStyleIcon then
		self.frame[unit].texture:SetTexture(LSM:Fetch(LSM.MediaType.STATUSBAR, "Minimalist"))
		if not self.frame[unit].timeleft or (self.frame[unit].timeleft and self.frame[unit].timeleft <= 0) then
			self.frame[unit].texture:SetVertexColor(Gladius.db.trinketGridStyleIconColor.r, Gladius.db.trinketGridStyleIconColor.g, Gladius.db.trinketGridStyleIconColor.b, Gladius.db.trinketGridStyleIconColor.a)
		else
			self.frame[unit].texture:SetVertexColor(Gladius.db.trinketGridStyleIconUsedColor.r, Gladius.db.trinketGridStyleIconUsedColor.g, Gladius.db.trinketGridStyleIconUsedColor.b, Gladius.db.trinketGridStyleIconUsedColor.a)
		end
	else
		local trinketIcon
		if not testing then
			if Gladius.db.trinketFaction then
				if UnitFactionGroup(unit) == "Horde" then
					trinketIcon = "Interface\\Icons\\INV_Jewelry_Necklace_38"
				else
					trinketIcon = "Interface\\Icons\\INV_Jewelry_Necklace_37"
				end
			else
				trinketIcon = 1322720
			end
		else
			if Gladius.db.trinketFaction then
				if UnitFactionGroup("player") == "Horde" then
					trinketIcon = "Interface\\Icons\\INV_Jewelry_Necklace_38"
				else
					trinketIcon = "Interface\\Icons\\INV_Jewelry_Necklace_37"
				end
			else
				trinketIcon = 1322720
			end
		end
		if (not self.frame[unit].spellID) then
			self.frame[unit].texture:SetTexture(trinketIcon)
		end
		if Gladius.db.trinketIconCrop then
			self.frame[unit].texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		end
		self.frame[unit].texture:SetVertexColor(1, 1, 1, 1)
	end
end

function Trinket:Reset(unit)
	if not self.frame[unit] then
		return
	end
	-- reset frame
	local trinketIcon
	if UnitFactionGroup("player") == "Horde" and Gladius.db.trinketFaction then
		trinketIcon = "Interface\\Icons\\INV_Jewelry_Necklace_38"
	else
		trinketIcon = "Interface\\Icons\\INV_Jewelry_Necklace_37"
	end
	if (not self.frame[unit].spellID) then
		self.frame[unit].texture:SetTexture(trinketIcon)
	end
	if Gladius.db.trinketIconCrop then
		self.frame[unit].texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	self.frame[unit]:SetScript("OnUpdate", nil)
	if Gladius.db.trinketGridStyleIcon then
		self.frame[unit].texture:SetVertexColor(Gladius.db.trinketGridStyleIconColor.r, Gladius.db.trinketGridStyleIconColor.g, Gladius.db.trinketGridStyleIconColor.b, Gladius.db.trinketGridStyleIconColor.a)
	end
	-- reset cooldown
	self.frame[unit].timeleft = nil
	self.frame[unit].cooldown:SetCooldown(0, 0)
	-- hide
	self.frame[unit]:SetAlpha(0)
end

function Trinket:ResetTrinketShuffle()
    for i = 1, 3 do
        local unit = "arena"..i
        local frame = self.frame[unit]
        if frame then
            frame.timeleft = nil
            frame:SetScript("OnUpdate", nil)
            Gladius:Call(Gladius.modules.Timer, "SetTimer", frame, 0)
            frame.cooldown:Clear()
        end
    end
end

function Trinket:Test(unit)
	if unit == "arena1" then
		self:UpdateTrinket(unit, 120)
	elseif unit == "arena2" then
		self:UpdateTrinket(unit, 30)
	end
end

-- Add the announcement toggle
function Trinket:OptionsLoad()
	Gladius.options.args.Announcements.args.general.args.announcements.args.trinket = {
		type = "toggle",
		name = L["Trinket"],
		desc = L["Announces when an enemy uses a PvP trinket."],
		disabled = function()
			return not Gladius.db.modules[self.name] or not Gladius.db.modules["Announcements"]
		end,
	}
end

function Trinket:GetOptions()
	return {
		general = {
			type = "group",
			name = L["General"],
			order = 1,
			args = {
				widget = {
					type = "group",
					name = L["Widget"],
					desc = L["Widget settings"],
					inline = true,
					order = 1,
					args = {
						trinketGridStyleIcon = {
							type = "toggle",
							name = L["Trinket Grid Style Icon"],
							desc = L["Toggle trinket grid style icon"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 5,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 7,
						},
						trinketGridStyleIconColor = {
							type = "color",
							name = L["Trinket Grid Style Icon Color"],
							desc = L["Color of the trinket grid style icon"],
							hasAlpha = true,
							get = function(info)
								return Gladius:GetColorOption(info)
							end,
							set = function(info, r, g, b, a)
								return Gladius:SetColorOption(info, r, g, b, a)
							end,
							disabled = function()
								return not Gladius.dbi.profile.trinketGridStyleIcon or not Gladius.dbi.profile.modules[self.name]
							end,
							order = 10,
						},
						trinketGridStyleIconUsedColor = {
							type = "color",
							name = L["Trinket Grid Style Icon Used Color"],
							desc = L["Color of the trinket grid style icon when it's on cooldown"],
							hasAlpha = true,
							get = function(info)
								return Gladius:GetColorOption(info)
							end,
							set = function(info, r, g, b, a)
								return Gladius:SetColorOption(info, r, g, b, a)
							end,
							disabled = function()
								return not Gladius.dbi.profile.trinketGridStyleIcon or not Gladius.dbi.profile.modules[self.name]
							end,
							order = 12,
						},
						sep1 = {
							type = "description",
							name = "",
							width = "full",
							order = 13,
						},
						trinketCooldown = {
							type = "toggle",
							name = L["Trinket Cooldown Spiral"],
							desc = L["Display the cooldown spiral for important auras"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 15,
						},
						trinketCooldownReverse = {
							type = "toggle",
							name = L["Trinket Cooldown Reverse"],
							desc = L["Invert the dark/bright part of the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 20,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							order = 23,
						},
						trinketGloss = {
							type = "toggle",
							name = L["Trinket Gloss"],
							desc = L["Toggle gloss on the trinket icon"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 25,
						},
						trinketGlossColor = {
							type = "color",
							name = L["Trinket Gloss Color"],
							desc = L["Color of the trinket icon gloss"],
							get = function(info)
								return Gladius:GetColorOption(info)
							end,
							set = function(info, r, g, b, a)
								return Gladius:SetColorOption(info, r, g, b, a)
							end,
							hasAlpha = true,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 30,
						},
						sep3 = {
							type = "description",
							name = "",
							width = "full",
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 33,
						},
						trinketIconCrop = {
							type = "toggle",
							name = L["Trinket Icon Border Crop"],
							desc = L["Toggle if the borders of the trinket icon should be cropped"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 35,
						},
						trinketFaction = {
							type = "toggle",
							name = L["Trinket Icon Faction"],
							desc = L["Toggle if the trinket icon should be changing based on the opponents faction"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 40,
						},
						sep3 = {
							type = "description",
							name = "",
							width = "full",
							order = 43,
						},
						trinketFrameLevel = {
							type = "range",
							name = L["Trinket Frame Level"],
							desc = L["Frame level of the trinket"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							min = 1,
							max = 5,
							step = 1,
							width = "double",
							order = 45,
						},
					},
				},
				size = {
					type = "group",
					name = L["Size"],
					desc = L["Size settings"],
					inline = true,
					order = 2,
					args = {
						trinketAdjustSize = {
							type = "toggle",
							name = L["Trinket Adjust Size"],
							desc = L["Adjust trinket size to the frame size"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 5,
						},
						trinketSize = {
							type = "range",
							name = L["Trinket Size"],
							desc = L["Size of the trinket"],
							min = 10,
							max = 100,
							step = 1,
							disabled = function()
								return Gladius.dbi.profile.trinketAdjustSize or not Gladius.dbi.profile.modules[self.name]
							end,
							order = 10,
						},
					},
				},
				position = {
					type = "group",
					name = L["Position"],
					desc = L["Position settings"],
					inline = true,
					order = 3,
					args = {
						trinketAttachTo = {
							type = "select",
							name = L["Trinket Attach To"],
							desc = L["Attach trinket to the given frame"],
							values = function()
								return Gladius:GetModules(self.name)
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							arg = "general",
							order = 5,
						},
						trinketDetached = {
							type = "toggle",
							name = L["Detached from frame"],
							desc = L["Detach the module from the frame itself"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 6,
						},
						trinketPosition = {
							type = "select",
							name = L["Trinket Position"],
							desc = L["Position of the trinket"],
							values = {["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
							get = function()
								return strfind(Gladius.db.trinketAnchor, "RIGHT") and "LEFT" or "RIGHT"
							end,
							set = function(info, value)
								if (value == "LEFT") then
									Gladius.db.trinketAnchor = "TOPRIGHT"
									Gladius.db.trinketRelativePoint = "TOPLEFT"
								else
									Gladius.db.trinketAnchor = "TOPLEFT"
									Gladius.db.trinketRelativePoint = "TOPRIGHT"
								end
								Gladius:UpdateFrame(info[1])
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return Gladius.db.advancedOptions
							end,
							order = 7,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 8,
						},
						trinketAnchor = {
							type = "select",
							name = L["Trinket Anchor"],
							desc = L["Anchor of the trinket"],
							values = function()
								return Gladius:GetPositions()
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 10,
						},
						trinketRelativePoint = {
							type = "select",
							name = L["Trinket Relative Point"],
							desc = L["Relative point of the trinket"],
							values = function()
								return Gladius:GetPositions()
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 15,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							order = 17,
						},
						trinketOffsetX = {
							type = "range",
							name = L["Trinket Offset X"],
							desc = L["X offset of the trinket"],
							min = - 100,
							max = 100,
							step = 1,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 20,
						},
						trinketOffsetY = {
							type = "range",
							name = L["Trinket Offset Y"],
							desc = L["Y offset of the trinket"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							min = - 50,
							max = 50,
							step = 1,
							order = 25,
						},
					},
				},
			},
		},
	}
end
