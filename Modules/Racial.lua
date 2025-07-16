-- @@@@@@@@@@@@@@@@@@@@@@@@@@@ Racial Module @@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Originally written by: Resike and Firebunny. Original author: Proditor
-- Modified by: Pharmac1st
-- Game Version: 11.1.7
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

local Gladius = _G.Gladius
if not Gladius then
	DEFAULT_CHAT_FRAME:AddMessage(format("Module %s requires Gladius", "Racial"))
end
local L = Gladius.L
local LSM

local CDList = LibStub("CDList-1.0")
local racialList = CDList:GetSpellsByCategory("racial")

-- Global functions
local _G = _G

local format = format
local pairs = pairs
local select = select
local strfind = strfind
local string = string

local CreateFrame = CreateFrame
local GetSpellInfo = C_Spell.GetSpellInfo
local GetSpellTexture = C_Spell.GetSpellTexture
local GetSpellDescription = C_Spell.GetSpellDescription
local GetTime = GetTime
local IsInInstance = IsInInstance
local UnitClass = UnitClass
local UnitDebuff = C_UnitAuras.GetDebuffDataByIndex
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitRace = UnitRace


local GetUnitDebuff = function(uId, spellName)
	for i = 1, 40 do
		local bfaspellName = UnitDebuff(uId, i)
		if not bfaspellName then return end
		if spellName == bfaspellName then
			return UnitDebuff(uId, i)
		end
	end
end


-- @@@@@@@@@@@@@@@@@@@@@@@@ Helper Function @@@@@@@@@@@@@@@@@@@@@@@@@@@
local function CreateRacialTable()
	local racialTable = {}
	for spellID, spellData in pairs(racialList) do
		local unitRace = spellData.unitRace
		local cooldown = spellData.cooldown or 0
		local sharesCD = spellData.sharesCD or false
		if spellID and unitRace then
			racialTable[unitRace] = {cooldown = cooldown, spellID = spellID, sharesCD = sharesCD}
		end
	end
	return racialTable
end
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


local unitRaceCDs = CreateRacialTable()

local Racial = Gladius:NewModule("Racial", false, true, {
	RacialAttachTo = "Trinket",
	RacialAnchor = "TOPLEFT",
	RacialRelativePoint = "TOPRIGHT",
	RacialAdjustSize = false,
	RacialSize = 40,
	RacialOffsetX = 5,
	RacialOffsetY = 0,
	RacialFrameLevel = 1,
	RacialIconCrop = true,
	RacialCooldown = true,
	RacialCooldownReverse = false,
	RacialCooldownSwipeAlpha = 0.8,
	RacialCooldownEdge = true,
	RacialDetached = false,
	trackedRacials = {}
},
{
	"Racial icon", "Grid style health bar", "Grid style power bar"
})

function Racial:OnEnable()
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("UNIT_NAME_UPDATE")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	LSM = Gladius.LSM
	if not self.frame then
		self.frame = { }
	end
end

function Racial:OnDisable()
	self:UnregisterAllEvents()
	for unit in pairs(self.frame) do
		self.frame[unit]:SetAlpha(0)
	end
end

function Racial:GetAttachTo()
	return Gladius.db.RacialAttachTo
end

function Racial:IsDetached()
	return Gladius.db.RacialDetached
end

function Racial:GetFrame(unit)
	return self.frame[unit]
end

function Racial:UNIT_NAME_UPDATE(event, unit)
	-- Find Unit Race
	local _, instanceType = IsInInstance()
	if instanceType ~= "arena" or not strfind(unit, "arena") or strfind(unit, "pet") then
		return
	end
	local _, race =  UnitRace(unit)
	race = string.upper(race)
	local spellTexture = GetSpellTexture(unitRaceCDs[race].spellID)
	self.frame[unit].race = race
	self.frame[unit].texture:SetTexture(spellTexture)
end

function Racial:AutoFixAll()
	local _, instanceType = IsInInstance()
	if instanceType ~= "arena" then return end
	for i = 1, 3 do
		local unit = 'arena'..i
		local _, race =  UnitRace(unit)
		race = string.upper(race or 'HUMAN')
		local spellTexture = GetSpellTexture(unitRaceCDs[race].spellID)
		if (self.frame[unit]) then
			self.frame[unit].race = race
			self.frame[unit].texture:SetTexture(spellTexture)
		end
	end
end

function Racial:UNIT_AURA(event, unit)
	local _, instanceType = IsInInstance()
	if instanceType ~= "arena" or not strfind(unit, "arena") or strfind(unit, "pet") then
		return
	end
	local race = self.frame[unit] and (self.frame[unit].race or string.upper(select(2, UnitRace(unit))))
	-- Set Racial CD on Adaptation
	if GetUnitDebuff(unit, "Adapted") then
		local _, _, _, _, _, t = GetUnitDebuff(unit, "Adapted")
		local g = t - GetTime()
		if g > 59 and unitRaceCDs[race].sharesCD then
			local sharedCD = (race == 'HUMAN' and 90) or 30
			local spellID = unitRaceCDs.spellID
			self:UpdateRacial(unit, sharedCD, spellID)
		end
	end
end

function Racial:UNIT_SPELLCAST_SUCCEEDED(event, unit, spellLineID, spell)
	self:AutoFixAll() --hacky way of fixing racial errors
	local _, instanceType = IsInInstance()
	if instanceType ~= "arena" or not strfind(unit, "arena") or strfind(unit, "pet") then
		return
	end
	local race = self.frame[unit] and (self.frame[unit].race or string.upper(select(2, UnitRace(unit))))
	if unitRaceCDs[race].sharesCD then
		local cd = self:GetRacialCD(unit)
		local sharedCD = (race == 'HUMAN' and 90) or 30
		local spellID = unitRaceCDs.spellID
		if (cd < sharedCD) then
			-- PVP Trinkets
			if spell == 42292 then
				self:UpdateRacial(unit, sharedCD, spellID)
			end
			-- Honorable Medallion
			if spell == 195710 then
				self:UpdateRacial(unit, sharedCD, spellID)
			end
			-- Gladiator's Medallion
			if spell == 208683 then
				self:UpdateRacial(unit, sharedCD, spellID)
			end
		end
	end

	-- all racials
	if spell == unitRaceCDs[race].spellID then
		local cooldown = unitRaceCDs[race].cooldown
		local spellID = unitRaceCDs[race].spellID
		self:UpdateRacial(unit, cooldown, spellID)
	end
end


function Racial:GROUP_ROSTER_UPDATE()
    Racial:ResetRacialShuffle()
end


function Racial:GetRacialCD(unit)
	local cd = 0
	local startTime, duration = self.frame[unit].cooldown:GetCooldownTimes()
	cd = ((startTime + duration) / 1000 - GetTime())
	return cd
end

function Racial:UpdateRacial(unit, duration, spellID)
	if Gladius.db.trackedRacials[spellID] ~= false then
		self.frame[unit]:Show()
		-- announcement
		if Gladius.db.announcements.Racial then
			Gladius:Call(Gladius.modules.Announcements, "Send", format(L["Racial USED: %s (%s)"], UnitName(unit) or "test", UnitClass(unit) or "test"), 2, unit)
		end
		if Gladius.db.announcements.Racial then
			self.frame[unit].timeleft = duration
			self.frame[unit]:SetScript("OnUpdate", function(f, elapsed)
				self.frame[unit].timeleft = self.frame[unit].timeleft - elapsed
				if self.frame[unit].timeleft <= 0 then
					self.frame[unit].timeleft = nil
					-- announcement
					if Gladius.db.announcements.Racial then
						Gladius:Call(Gladius.modules.Announcements, "Send", format(L["Racial READY: %s (%s)"], UnitName(unit) or "", UnitClass(unit) or ""), 2, unit)
					end
					self.frame[unit]:SetScript("OnUpdate", nil)
				end
			end)
		end
		if duration then
			-- cooldown
			if not Gladius.db.modules["Timer"] then
				self.frame[unit].cooldown:SetHideCountdownNumbers(false)
				self.frame[unit].cooldown:SetCooldown(GetTime(), duration)
			else
				Gladius:Call(Gladius.modules.Timer, "SetTimer", self.frame[unit], duration)
			end
		end
	else
		self.frame[unit]:Hide()
	end
end


function Racial:CreateFrame(unit)
	local button = Gladius.buttons[unit]
	if not button then
		return
	end

	-- Create a parent frame
	self.frame[unit] = CreateFrame("CheckButton", "Gladius"..self.name.."Frame"..unit, button)
	local frameName = self.frame[unit]:GetName()

	self.frame[unit]:EnableMouse(false)
	self.frame[unit]:SetSize(Gladius.db.RacialSize, Gladius.db.RacialSize)
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


function Racial:Update(unit)
	-- create frame
	if not self.frame[unit] then
		self:CreateFrame(unit)
	end

	local unitFrame = self.frame[unit]

	-- update frame
	unitFrame:ClearAllPoints()
	-- anchor point
	local parent = Gladius:GetParent(unit, Gladius.db.RacialAttachTo)
	unitFrame:SetPoint(Gladius.db.RacialAnchor, parent, Gladius.db.RacialRelativePoint, Gladius.db.RacialOffsetX, Gladius.db.RacialOffsetY)
	-- frame level
	unitFrame:SetFrameLevel(Gladius.db.RacialFrameLevel)
	if Gladius.db.RacialAdjustSize then
		if self:GetAttachTo() == "Frame" then
			local height = false

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
		unitFrame:SetWidth(Gladius.db.RacialSize)
		unitFrame:SetHeight(Gladius.db.RacialSize)
	end
	-- set frame mouse-interactable area
	if self:GetAttachTo() == "Frame" and not self:IsDetached() then
		local left, right, top, bottom = Gladius.buttons[unit]:GetHitRectInsets()
		if strfind(Gladius.db.RacialRelativePoint, "LEFT") then
			left = - unitFrame:GetWidth() + Gladius.db.RacialOffsetX
		else
			right = - unitFrame:GetWidth() + - Gladius.db.RacialOffsetX
		end

		-- top / bottom
		if (unitFrame:GetHeight() > Gladius.buttons[unit]:GetHeight()) then
			bottom = -(unitFrame:GetHeight() - Gladius.buttons[unit]:GetHeight()) + Gladius.db.RacialOffsetY
		end
		Gladius.buttons[unit]:SetHitRectInsets(left, right, 0, 0)
		Gladius.buttons[unit].secure:SetHitRectInsets(left, right, 0, 0)
	end

	if not Gladius.db.RacialIconCrop then
		unitFrame.texture:SetTexCoord(0, 1, 0, 1)
	else
		unitFrame.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end

	-- cooldown
	-- Optional styling
	unitFrame.cooldown:SetDrawSwipe(Gladius.db.RacialCooldown)
	unitFrame.cooldown:SetReverse(Gladius.db.RacialCooldownReverse)
	unitFrame.cooldown:SetSwipeColor(0, 0, 0, Gladius.db.RacialCooldownSwipeAlpha)
	unitFrame.cooldown:SetDrawEdge(Gladius.db.RacialCooldown and Gladius.db.RacialCooldownEdge)
	unitFrame.cooldown.isDisabled = not Gladius.db.RacialCooldown
	Gladius:Call(Gladius.modules.Timer, "RegisterTimer", unitFrame, Gladius.db.RacialCooldown)

	-- Secure frame
	if self:IsDetached() then
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

function Racial:Show(unit)
	local testing = Gladius.test
	-- show frame
	self.frame[unit]:SetAlpha(1)
	if testing then
		local unitRace = string.upper(Gladius.testing[unit].unitRace)
		local spellID = unitRaceCDs[unitRace].spellID
		local RacialIcon = C_Spell.GetSpellTexture(spellID)
		if (not self.frame[unit].race) and Gladius.db.trackedRacials[spellID] ~= false then
			self.frame[unit].texture:SetTexture(RacialIcon)
		end
		if Gladius.db.RacialIconCrop then
			self.frame[unit].texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		end
		self.frame[unit].texture:SetVertexColor(1, 1, 1, 1)
	end
end

function Racial:Reset(unit)
	if not self.frame[unit] then
		return
	end
	self.frame[unit].race = nil
	self.frame[unit].texture:SetTexture(nil)
	-- reset frame
	if Gladius.db.RacialIconCrop then
		self.frame[unit].texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	self.frame[unit]:SetScript("OnUpdate", nil)
	-- reset cooldown
	self.frame[unit].timeleft = nil
	self.frame[unit].cooldown:SetCooldown(0, 0)
	-- hide
	self.frame[unit]:SetAlpha(0)
end


function Racial:ResetRacialShuffle()
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


function Racial:ResetModule()
	Gladius.db.trackedRacials = {}
end


function Racial:Test(unit)
	local unitRace = string.upper(Gladius.testing[unit].unitRace)
	local spellID = unitRaceCDs[unitRace].spellID
	if unit == "arena1" then
		self:UpdateRacial(unit, 180, spellID)
	elseif unit == "arena2" then
		self:UpdateRacial(unit, 120, spellID)
	elseif unit == "arena3" then
		self:UpdateRacial(unit, nil, spellID)
	end
end

-- Add the announcement toggle
function Racial:OptionsLoad()
	Gladius.options.args.Announcements.args.general.args.announcements.args.Racial = {
		type = "toggle",
		name = L["Racial"],
		desc = L["Announces when an enemy uses a Racial."],
		disabled = function()
			return not Gladius.db.modules[self.name] or not Gladius.db.modules["Announcements"]
		end,
	}
end

function Racial:GetOptions()
	local options = {
		general = {
			type = "group",
			name = L["General"],
			order = 1,
			args = {
				trackedRacials = {
					type = "group",
					name = L["Racial Tracking"],
					desc = L["Racial Tracking settings"],
					inline = true,
					hidden = function()
						return not Gladius.db.advancedOptions
					end,
					order = 0,
					args = {}
				},
				widget = {
					type = "group",
					name = L["Widget"],
					desc = L["Widget settings"],
					inline = true,
					hidden = function()
						return not Gladius.db.advancedOptions
					end,
					order = 1,
					args = {
						RacialIconCrop = {
							type = "toggle",
							name = L["Racial Icon Border Crop"],
							desc = L["Toggle if the borders of the Racial icon should be cropped"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							width = "double",
							order = 5,
						},
						sep1 = {
							type = "description",
							name = "",
							width = "full",
							order = 8,
						},
						RacialCooldown = {
							type = "toggle",
							name = L["Racial Cooldown Spiral"],
							desc = L["Display the cooldown spiral for important auras"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							width = "double",
							order = 10,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							order = 13,
						},
						RacialCooldownReverse = {
							type = "toggle",
							name = L["Racial Cooldown Reverse"],
							desc = L["Invert the dark/bright part of the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.RacialCooldown
							end,
							width = "double",
							order = 15,
						},
						sep3 = {
							type = "description",
							name = "",
							width = "full",
							order = 18,
						},
						RacialCooldownEdge = {
							type = "toggle",
							name = L["Racial Cooldown Edge"],
							desc = L["Display the edge texture for the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.RacialCooldown
							end,
							width = "double",
							order = 20,
						},
						sep4 = {
							type = "description",
							name = "",
							width = "full",
							order = 23,
						},
						RacialCooldownSwipeAlpha = {
							type = "range",
							name = L["Racial Cooldown Swipe Alpha"],
							desc = L["Set the darkness of the cooldown swipe animation"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.RacialCooldown
							end,
							min = 0,
							max = 1,
							step = 0.1,
							width = "double",
							order = 25,
						},
						sep5 = {
							type = "description",
							name = "",
							width = "full",
							order = 28,
						},
						RacialFrameLevel = {
							type = "range",
							name = L["Racial Frame Level"],
							desc = L["Frame level of the Racial"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							min = 1,
							max = 5,
							step = 1,
							width = "double",
							order = 30,
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
						RacialAdjustSize = {
							type = "toggle",
							name = L["Racial Adjust Size"],
							desc = L["Adjust Racial size to the frame size"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 5,
						},
						RacialSize = {
							type = "range",
							name = L["Racial Size"],
							desc = L["Size of the Racial"],
							min = 10,
							max = 100,
							step = 1,
							disabled = function()
								return Gladius.dbi.profile.RacialAdjustSize or not Gladius.dbi.profile.modules[self.name]
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
						RacialAttachTo = {
							type = "select",
							name = L["Racial Attach To"],
							desc = L["Attach Racial to the given frame"],
							values = function()
								return Gladius:GetModules(self.name)
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							arg = "general",
							order = 5,
						},
						RacialDetached = {
							type = "toggle",
							name = L["Detached from frame"],
							desc = L["Detach the module from the frame itself"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return Gladius.db.RacialAttachTo ~= "Frame"
							end,
							order = 6,
						},
						RacialPosition = {
							type = "select",
							name = L["Racial Position"],
							desc = L["Position of the Racial"],
							values = {["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
							get = function()
								return strfind(Gladius.db.RacialAnchor, "RIGHT") and "LEFT" or "RIGHT"
							end,
							set = function(info, value)
								if (value == "LEFT") then
									Gladius.db.RacialAnchor = "TOPRIGHT"
									Gladius.db.RacialRelativePoint = "TOPLEFT"
								else
									Gladius.db.RacialAnchor = "TOPLEFT"
									Gladius.db.RacialRelativePoint = "TOPRIGHT"
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
						RacialAnchor = {
							type = "select",
							name = L["Racial Anchor"],
							desc = L["Anchor of the Racial"],
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
						RacialRelativePoint = {
							type = "select",
							name = L["Racial Relative Point"],
							desc = L["Relative point of the Racial"],
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
						RacialOffsetX = {
							type = "range",
							name = L["Racial Offset X"],
							desc = L["X offset of the Racial"],
							min = - 350,
							max = 350,
							step = 1,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 20,
						},
						RacialOffsetY = {
							type = "range",
							name = L["Racial Offset Y"],
							desc = L["Y offset of the Racial"],
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


	function AddOrderBySpellName(spellTable)
		-- Create a sortable list that will hold spellID and name
		local sortable = {}
		-- Populate the sortable table with spellID and name
		for spellID, _ in pairs(spellTable) do
			local spellInfo = GetSpellInfo(spellID)
			if spellInfo and spellInfo.name then
				table.insert(sortable, {spellID = spellID, name = spellInfo.name})
			end
		end
		-- Sort the spells alphabetically by their name
		table.sort(sortable, function(a, b)
			return a.name < b.name
		end)
		-- Assign the order to each spell in the original table
		for index, spell in ipairs(sortable) do
			spellTable[spell.spellID]["order"] = index
		end
		-- Return the sorted table with the updated order fields
		return spellTable
	end


	-- Dynamically populate racial tracking toggles
	local sortedRacialList = AddOrderBySpellName(racialList)
	for racial, data in pairs(sortedRacialList) do
		local spellInfo = GetSpellInfo(racial)
		local id = spellInfo.spellID
		local name = spellInfo.name
		local icon = spellInfo.originalIconID
		options.general.args.trackedRacials.args[tostring(racial)] = {
			type = "toggle",
			name = "|T" .. icon .. ":20:20|t " .. L[name],
			desc = function ()
					local description = GetSpellDescription(id)
					local extra = "\n\n|cffffd700".."Spell ID".."|r " .. id
					return description .. extra
				end,
			order = data.order,
			get = function()
				-- Set default value to true if no value assigned yet
				if Gladius.db.trackedRacials[racial] == nil then
					Gladius.db.trackedRacials[racial] = true
				end

				return Gladius.db.trackedRacials[racial]
			end,
			set = function(_, value)
				Gladius.db.trackedRacials[racial] = value
				Gladius:UpdateFrame()
			end
		}
	end

	return options
end
