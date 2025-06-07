--Dispel Module for Gladius
--Mavvo
local Gladius = _G.Gladius
if not Gladius then
	DEFAULT_CHAT_FRAME:AddMessage(format("Module %s requires Gladius", "Dispel"))
end
local L = Gladius.L
local LSM

local CDList = LibStub("CDList-1.0")
local dispellList = CDList:GetSpellsByCategory("dispell")

-- Global functions
local _G = _G
local pairs = pairs
local ipairs = ipairs
local strfind = string.find
local strformat = string.format

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitGUID = UnitGUID
local UnitLevel = UnitLevel
local UnitName = UnitName
local GetSpellInfo = C_Spell.GetSpellInfo

local Dispel = Gladius:NewModule("Dispel", false, true, {
	dispellAttachTo = "Racial",
	dispellAnchor = "TOPLEFT",
	dispellRelativePoint = "TOPRIGHT",
	dispellGridStyleIcon = false,
	dispellGridStyleIconColor = {r = 0, g = 1, b = 0, a = 1},
	dispellGridStyleIconUsedColor = {r = 1, g = 0, b = 0, a = 1},
	dispellAdjustSize = false,
	dispellSize = 50,
	dispellOffsetX = 0,
	dispellOffsetY = 0,
	dispellFrameLevel = 1,
	dispellIconCrop = true,
	dispellCooldown = true,
	dispellCooldownReverse = false,
	dispellCooldownSwipeAlpha = 1,
	dispellCooldownEdge = false,
	dispellFaction = false,
	showCurse = false,
	showDisease = false,
	showMagic = true,
	showPoison = false,
},
{
	"Dispel icon",
	"Grid style health bar",
	"Grid style power bar",
})

function Dispel:OnEnable()
	--self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	LSM = Gladius.LSM
	if not self.frame then
		self.frame = { }
	end
end

function Dispel:OnDisable()
	self:UnregisterAllEvents()
	for unit in pairs(self.frame) do
		self.frame[unit]:SetAlpha(0)
	end
end

function Dispel:OnProfileChanged()
	if Gladius.dbi.profile.modules["Dispel"] then
		Gladius:EnableModule("Dispel")
	else
		Gladius:DisableModule("Dispel")
	end
end

function Dispel:GetAttachTo()
	return Gladius.db.dispellAttachTo
end

function Dispel:GetFrame(unit)
	return self.frame[unit]
end


function Dispel:COMBAT_LOG_EVENT_UNFILTERED(event)
	if not IsActiveBattlefieldArena() then
		return
	end
	self:CombatLogEvent(event, CombatLogGetCurrentEventInfo())
end


function Dispel:CombatLogEvent(event, timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, auraType)
    if eventType ~= "SPELL_DISPEL" then return end

    local showType = {
        curse = Gladius.db.showCurse,
        disease = Gladius.db.showDisease,
        magic = Gladius.db.showMagic,
        poison = Gladius.db.showPoison,
    }

    local arenaUnit
    for i = 1, 5 do
        local unit = "arena" .. i
        if UnitGUID(unit) == sourceGUID then
            arenaUnit = unit
            break
        end
    end

    if not arenaUnit then return end

    local spellData = dispellList[spellID]
    if not spellData then return end

    for _, dispellType in ipairs(spellData.subcategory) do
        if showType[dispellType] then
            self:UpdateDispel(arenaUnit, 8)
            break
        end
    end
end


function Dispel:UpdateDispel(unit, duration)
	if not unit or not self.frame[unit] or not duration then
		return
	end
	-- grid style icon
	if Gladius.db.dispellGridStyleIcon then
		self.frame[unit].texture:SetVertexColor(Gladius.db.dispellGridStyleIconUsedColor.r, Gladius.db.dispellGridStyleIconUsedColor.g, Gladius.db.dispellGridStyleIconUsedColor.b, Gladius.db.dispellGridStyleIconUsedColor.a)
	end
	-- announcement
	if Gladius.db.announcements.dispell then
		Gladius:Call(Gladius.modules.Announcements, "Send", strformat(L["DISPEL USED: %s (%s)"], UnitName(unit) or "test", UnitClass(unit) or "test"), 2, unit)
	end
	if Gladius.db.announcements.dispell or Gladius.db.dispellGridStyleIcon then
		self.frame[unit].timeleft = duration
		self.frame[unit]:SetScript("OnUpdate", function(f, elapsed)
			self.frame[unit].timeleft = self.frame[unit].timeleft - elapsed
			if self.frame[unit].timeleft <= 0 then
				-- dispel
				if Gladius.db.dispellGridStyleIcon then
					self.frame[unit].texture:SetVertexColor(Gladius.db.dispellGridStyleIconColor.r, Gladius.db.dispellGridStyleIconColor.g, Gladius.db.dispellGridStyleIconColor.b, Gladius.db.dispellGridStyleIconColor.a)
				end
				-- announcement
				if Gladius.db.announcements.dispell then
					Gladius:Call(Gladius.modules.Announcements, "Send", strformat(L["DISPEL READY: %s (%s)"], UnitName(unit) or "", UnitClass(unit) or ""), 2, unit)
				end
				self.frame[unit]:SetScript("OnUpdate", nil)
			end
		end)
	end
	-- cooldown
	if not Gladius.db.modules["Timer"] then
		self.frame[unit].cooldown:SetHideCountdownNumbers(false)
		self.frame[unit].cooldown:SetCooldown(GetTime(), duration)
	else
		Gladius:Call(Gladius.modules.Timer, "SetTimer", self.frame[unit], duration)
	end
end

function Dispel:UpdateColors(unit)
	if Gladius.db.dispellGridStyleIcon then
		self.frame[unit].texture:SetVertexColor(Gladius.db.dispellGridStyleIconUsedColor.r, Gladius.db.dispellGridStyleIconUsedColor.g, Gladius.db.dispellGridStyleIconUsedColor.b, Gladius.db.dispellGridStyleIconUsedColor.a)
	end
end

function Dispel:CreateFrame(unit)
	local button = Gladius.buttons[unit]
	if not button then
		return
	end

	-- Create a parent frame
	self.frame[unit] = CreateFrame("CheckButton", "Gladius"..self.name.."Frame"..unit, button)
	local frameName = self.frame[unit]:GetName()

	self.frame[unit]:EnableMouse(false)
	self.frame[unit]:SetSize(Gladius.db.dispellSize, Gladius.db.dispellSize)
	self.frame[unit]:SetPoint("CENTER")

	-- Create a texture frame
	self.frame[unit].texture = self.frame[unit]:CreateTexture(frameName .. "Icon", "BACKGROUND")
	self.frame[unit].texture:SetAllPoints() -- Makes it cover the frame

	-- Create a cooldown frame on top of the texture frame
	self.frame[unit].cooldown = CreateFrame("Cooldown", frameName .. "Cooldown", self.frame[unit], "CooldownFrameTemplate")
	self.frame[unit].cooldown:SetAllPoints() -- Makes it cover the texture frame

	-- secure
	local secure = CreateFrame("Button", "Gladius"..self.name.."SecureButton"..unit, button, "SecureActionButtonTemplate")
	secure:RegisterForClicks("AnyUp", "AnyDown")
	self.frame[unit].secure = secure
end


function Dispel:Update(unit)
	-- create frame
	if not self.frame[unit] then
		self:CreateFrame(unit)
	end
	-- update frame
	self.frame[unit]:ClearAllPoints()
	-- anchor point
	local parent = Gladius:GetParent(unit, Gladius.db.dispellAttachTo)
	self.frame[unit]:SetPoint(Gladius.db.dispellAnchor, parent, Gladius.db.dispellRelativePoint, Gladius.db.dispellOffsetX, Gladius.db.dispellOffsetY)
	-- frame level
	self.frame[unit]:SetFrameLevel(Gladius.db.dispellFrameLevel)
	if Gladius.db.dispellAdjustSize then
		if self:GetAttachTo() == "Frame" then
			local height = false
			-- need to rethink that
			--[[for _, module in pairs(Gladius.modules) do
				if (module:GetAttachTo() == self.name) then
					height = false
				end
			end]]
			if height then
				self.frame[unit]:SetWidth(Gladius.buttons[unit].height)
				self.frame[unit]:SetHeight(Gladius.buttons[unit].height)
			else
				self.frame[unit]:SetWidth(Gladius.buttons[unit].frameHeight)
				self.frame[unit]:SetHeight(Gladius.buttons[unit].frameHeight)
			end
		else
			local defaultValue = nil
			if not Gladius:GetModule(self:GetAttachTo()).frame[unit] == nil then
				defaultValue = Gladius:GetModule(self:GetAttachTo()).frame[unit]:GetHeight()
			else
				defaultValue = 1
			end
			
			self.frame[unit]:SetWidth(defaultValue)
			self.frame[unit]:SetHeight(defaultValue)
		end
	else
		self.frame[unit]:SetWidth(Gladius.db.dispellSize)
		self.frame[unit]:SetHeight(Gladius.db.dispellSize)
	end
	-- set frame mouse-interactable area
	if self:GetAttachTo() == "Frame" then
	local left, right, top, bottom = Gladius.buttons[unit]:GetHitRectInsets()
	if strfind(Gladius.db.dispellRelativePoint, "LEFT") then
		left = - self.frame[unit]:GetWidth() + Gladius.db.dispellOffsetX
	else
		right = - self.frame[unit]:GetWidth() + - Gladius.db.dispellOffsetX
	end

	-- top / bottom
	if self.frame[unit]:GetHeight() > Gladius.buttons[unit]:GetHeight() then
		bottom = - (self.frame[unit]:GetHeight() - Gladius.buttons[unit]:GetHeight()) + Gladius.db.dispellOffsetY
	end
		Gladius.buttons[unit]:SetHitRectInsets(left, right, 0, 0)
		Gladius.buttons[unit].secure:SetHitRectInsets(left, right, 0, 0)
	end

	if not Gladius.db.dispellIconCrop and not Gladius.db.dispellGridStyleIcon then
		self.frame[unit].texture:SetTexCoord(0, 1, 0, 1)
	else
		self.frame[unit].texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end

	-- cooldown
	-- Optional styling
	self.frame[unit].cooldown:SetDrawSwipe(Gladius.db.dispellCooldown)
	self.frame[unit].cooldown:SetDrawEdge(Gladius.db.dispellCooldownEdge)
	self.frame[unit].cooldown:SetSwipeColor(0, 0, 0, Gladius.db.dispellCooldownSwipeAlpha)
	if Gladius.db.dispellCooldown then
		self.frame[unit].cooldown:Show()
	else
		self.frame[unit].cooldown:Hide()
	end
	self.frame[unit].cooldown:SetReverse(Gladius.db.dispellCooldownReverse)
	Gladius:Call(Gladius.modules.Timer, "RegisterTimer", self.frame[unit], Gladius.db.dispellCooldown)
	-- hide
	self.frame[unit]:SetAlpha(0)
end


function Dispel:Show(unit)
	-- show frame
	self.frame[unit]:SetAlpha(1)
	if Gladius.db.dispellGridStyleIcon then
		self.frame[unit].texture:SetTexture(LSM:Fetch(LSM.MediaType.STATUSBAR, "Minimalist"))
		self.frame[unit].texture:SetVertexColor(Gladius.db.dispellGridStyleIconColor.r, Gladius.db.dispellGridStyleIconColor.g, Gladius.db.dispellGridStyleIconColor.b, Gladius.db.dispellGridStyleIconColor.a)
	else
		local testing = Gladius.test
		local class, specID
		local dispellIcon

		if testing then
			class = Gladius.testing[unit].unitClass
			specID = Gladius.testing[unit].unitSpecId
		else
			_, class = UnitClass(unit)
			specID = Gladius.buttons[unit].specID
		end

		-- Find the correct dispell icon for the class and spec of "unit"
		local showType = {
			curse = Gladius.db.showCurse,
			disease = Gladius.db.showDisease,
			magic = Gladius.db.showMagic,
			poison = Gladius.db.showPoison,
		}

		for spellID, spellData in pairs(dispellList) do
			for _, dispellType in ipairs(spellData.subcategory) do
				if showType[dispellType] then
					if spellData.class == class and (not spellData.specID or tContains(spellData.specID, specID)) then
						dispellIcon = GetSpellInfo(spellID).originalIconID
						break
					end
				end
			end
			if dispellIcon then break end
		end

		if dispellIcon then
			self.frame[unit].texture:SetTexture(dispellIcon)
		else
			self.frame[unit].texture:SetTexture("")
			self.frame[unit]:SetAlpha(0)
		end
		if Gladius.db.dispellIconCrop then
			self.frame[unit].texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		end
		self.frame[unit].texture:SetVertexColor(1, 1, 1, 1)
	end
end


function Dispel:Reset(unit)
	if not self.frame[unit] then
		return
	end
	-- reset frame
	local dispellIcon
	if UnitFactionGroup("player") == "Horde" and Gladius.db.dispellFaction then
		dispellIcon = "Interface\\Icons\\INV_Jewelry_Necklace_38"
	else
		dispellIcon = "Interface\\Icons\\INV_Jewelry_Necklace_37"
	end
	self.frame[unit].texture:SetTexture(dispellIcon)
	if Gladius.db.dispellIconCrop then
		self.frame[unit].texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	self.frame[unit]:SetScript("OnUpdate", nil)
	-- reset cooldown
	Gladius:Call(Gladius.modules.Timer, "HideTimer", self.frame[unit])
	-- hide
	self.frame[unit]:SetAlpha(0)
end

function Dispel:Test(unit)
	if unit == "arena1" then
		self:UpdateDispel(unit, 8)
	elseif unit == "arena2" then
		self:UpdateDispel(unit, 8)
	elseif unit == "arena3" then
		self:UpdateDispel(unit, 8)
	elseif unit == "arena4" then
		self:UpdateDispel(unit, 8)
	elseif unit == "arena5" then
		self:UpdateDispel(unit, 8)
	end
end

-- Add the announcement toggle
function Dispel:OptionsLoad()
	Gladius.options.args.Announcements.args.general.args.announcements.args.dispell = {
		type = "toggle",
		name = L["Dispel"],
		desc = L["Announces when an enemy cast a dispel."],
		disabled = function()
			return not Gladius.db.modules[self.name]
		end,
	}
end

function Dispel:GetOptions()
	return {
		general = {
			type = "group",
			name = L["General"],
			order = 1,
			args = {
				dispells = {
					type = "group",
					name = L["Dispell Tracking"],
					desc = L["Dispell Tracking settings"],
					inline = true,
					order = 1,
					args = {
						showCurse = {
							type = "toggle",
							name = L["Curse Dispells"],
							desc = L["Toggle if you want to track dispells that remove Curse effects"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 45,
						},
						showDisease = {
							type = "toggle",
							name = L["Disease Dispells"],
							desc = L["Toggle if you want to track dispells that remove Disease effects"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 50,
						},
						showMagic = {
							type = "toggle",
							name = L["Magic Dispells"],
							desc = L["Toggle if you want to track dispells that remove Magic effects"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 55,
						},
						showPoison = {
							type = "toggle",
							name = L["Poison Dispells"],
							desc = L["Toggle if you want to track dispells that remove Poison effects"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 60,
						},
					}
				},
				widget = {
					type = "group",
					name = L["Widget"],
					desc = L["Widget settings"],
					inline = true,
					order = 2,
					args = {
						dispellGridStyleIcon = {
							type = "toggle",
							name = L["Dispel Grid Style Icon"],
							desc = L["Toggle dispel grid style icon"],
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
						dispellGridStyleIconColor = {
							type = "color",
							name = L["Dispel Grid Style Icon Color"],
							desc = L["Color of the dispel grid style icon"],
							hasAlpha = true,
							get = function(info)
								return Gladius:GetColorOption(info)
							end,
							set = function(info, r, g, b, a)
								return Gladius:SetColorOption(info, r, g, b, a)
							end,
							disabled = function()
								return not Gladius.dbi.profile.dispellGridStyleIcon or not Gladius.dbi.profile.modules[self.name]
							end,
							order = 10,
						},
						dispellGridStyleIconUsedColor = {
							type = "color",
							name = L["Dispel Grid Style Icon Used Color"],
							desc = L["Color of the dispel grid style icon when it's on cooldown"],
							hasAlpha = true,
							get = function(info)
								return Gladius:GetColorOption(info)
							end,
							set = function(info, r, g, b, a)
								return Gladius:SetColorOption(info, r, g, b, a)
							end,
							disabled = function()
								return not Gladius.dbi.profile.dispellGridStyleIcon or not Gladius.dbi.profile.modules[self.name]
							end,
							order = 12,
						},
						sep1 = {
							type = "description",
							name = "",
							width = "full",
							order = 13,
						},
						dispellCooldown = {
							type = "toggle",
							name = L["Dispel Cooldown Spiral"],
							desc = L["Display the cooldown spiral for important auras"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 15,
						},
						dispellCooldownReverse = {
							type = "toggle",
							name = L["Dispel Cooldown Reverse"],
							desc = L["Invert the dark/bright part of the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							width = "full",
							order = 20,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 23,
						},
						dispellCooldownEdge = {
							type = "toggle",
							name = L["Dispell Cooldown Edge"],
							desc = L["Display the edge texture for the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 25,
						},
						sep3 = {
							type = "description",
							name = "",
							width = "full",
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 28,
						},
						dispellIconCrop = {
							type = "toggle",
							name = L["Dispel Icon Border Crop"],
							desc = L["Toggle if the borders of the dispell icon should be cropped"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							width = "full",
							order = 30,
						},
						dispellFaction = {
							type = "toggle",
							name = L["Dispel Icon Faction"],
							desc = L["Toggle if the dispel icon should be changing based on the opponents faction"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 35,
						},
						sep4 = {
							type = "description",
							name = "",
							width = "full",
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 38,
						},
						dispellCooldownSwipeAlpha = {
							type = "range",
							name = L["Dispell Cooldown Swipe Alpha"],
							desc = L["Set the darkness of the cooldown swipe animation"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							min = 0.5,
							max = 1,
							step = 0.1,
							width = "double",
							order = 40,
						},
						sep5 = {
							type = "description",
							name = "",
							width = "full",
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 43,
						},
						dispellFrameLevel = {
							type = "range",
							name = L["Dispel Frame Level"],
							desc = L["Frame level of the dispel"],
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
					order = 3,
					args = {
						dispellAdjustSize = {
							type = "toggle",
							name = L["Dispel Adjust Size"],
							desc = L["Adjust dispel size to the frame size"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 5,
						},
						dispellSize = {
							type = "range",
							name = L["Dispel Size"],
							desc = L["Size of the dispel"],
							min = 10,
							max = 100,
							step = 1,
							disabled = function()
								return Gladius.dbi.profile.dispellAdjustSize or not Gladius.dbi.profile.modules[self.name]
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
						order = 4,
						args = {
						dispellAttachTo = {
							type = "select",
							name = L["Dispel Attach To"],
							desc = L["Attach dispel to the given frame"],
							values = function()
								return Gladius:GetModules(self.name)
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							arg = "general",
							order = 5,
						},
						dispellPosition = {
							type = "select",
							name = L["Dispel Position"],
							desc = L["Position of the dispel"],
							values = {["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
							get = function()
								return strfind(Gladius.db.dispellAnchor, "RIGHT") and "LEFT" or "RIGHT"
							end,
							set = function(info, value)
								if (value == "LEFT") then
									Gladius.db.dispellAnchor = "TOPRIGHT"
									Gladius.db.dispellRelativePoint = "TOPLEFT"
								else
									Gladius.db.dispellAnchor = "TOPLEFT"
									Gladius.db.dispellRelativePoint = "TOPRIGHT"
								end
								Gladius:UpdateFrame(info[1])
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return Gladius.db.advancedOptions
							end,
							order = 6,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 7,
						},
						dispellAnchor = {
							type = "select",
							name = L["Dispel Anchor"],
							desc = L["Anchor of the dispel"],
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
						dispellRelativePoint = {
							type = "select",
							name = L["Dispel Relative Point"],
							desc = L["Relative point of the dispel"],
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
						dispellOffsetX = {
							type = "range",
							name = L["Dispel Offset X"],
							desc = L["X offset of the dispel"],
							min = - 100,
							max = 100,
							step = 1,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 20,
						},
						dispellOffsetY = {
							type = "range",
							name = L["Dispel Offset Y"],
							desc = L["Y offset of the dispel"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							min = -50,
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
