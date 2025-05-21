-- @@@@@@@@@@@@@@@@@@@@@@@@@ Classicon Module @@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Originally written by: Resike and Firebunny. Original author: Proditor
-- Modified by: Pharmac1st
-- Game Version: 11.1.5
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

local Gladius = _G.Gladius
if not Gladius then
	DEFAULT_CHAT_FRAME:AddMessage(format("Module %s requires Gladius", "Class Icon"))
end
local L = Gladius.L


-- @@@@@@@@@@@@@@@@@@@@@@@@@ Deepcopy Function @@@@@@@@@@@@@@@@@@@@@@@@@@
local function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            return copies[orig]
        end
        copy = {}
        copies[orig] = copy
        for k, v in next, orig, nil do
            copy[deepcopy(k, copies)] = deepcopy(v, copies)
        end
        setmetatable(copy, deepcopy(getmetatable(orig), copies))
    else
        copy = orig
    end
    return copy
end
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


local CDList = LibStub("CDList-1.0")
local originalSpellTable = deepcopy(CDList.spellList)
local spellTable = CDList.spellList

-- Global Functions
local _G = _G
local pairs = pairs
local strfind = string.find
local tostring = tostring

local CreateFrame = CreateFrame
local GetSpecializationInfoByID = GetSpecializationInfoByID
local GetSpellInfo = C_Spell.GetSpellInfo
local GetNumClasses = GetNumClasses
local GetClassInfo = C_CreatureInfo.GetClassInfo
local GetSpellByID = C_TooltipInfo.GetSpellByID

local GetTime = GetTime
local UnitAura = UnitAura or function(unitToken, index, filter)
		local auraData = C_UnitAuras.GetAuraDataByIndex(unitToken, index, filter)
		if not auraData then
			return nil
		end

		return AuraUtil.UnpackAuraData(auraData)
	end

local CLASS_BUTTONS = CLASS_ICON_TCOORDS

local IsWrathClassic = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

local ClassIcon = Gladius:NewModule("ClassIcon", false, true, {
	classIconAttachTo = "Frame",
	classIconAnchor = "TOPRIGHT",
	classIconRelativePoint = "TOPLEFT",
	classIconAdjustSize = false,
	classIconSize = 50,
	classIconOffsetX = -1,
	classIconOffsetY = 0,
	classIconFrameLevel = 1,
	classIconGloss = false,
	classIconGlossColor = {r = 1, g = 1, b = 1, a = 0.4},
	classIconImportantAuras = true,
	classIconCrop = true,
	classIconCooldown = false,
	classIconCooldownReverse = false,
	classIconShowSpec = false,
	classIconDetached = false,
	classIconAuras = spellTable,
})


--@@@@@@@@@@@@@@@@@@@@ Testspells for Testmode @@@@@@@@@@@@@@@@@@@@@@
local testSpells = {
	arena1 = {spellID = 45438, duration = 10},  -- Ice Block
	arena2 = {spellID = 53480, duration = 12},  -- Roar of Sacrifice
	arena3 = {spellID = 1966,  duration = 6},  -- Feint
}
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


function ClassIcon:OnEnable()
	self:RegisterEvent("UNIT_AURA")
	self.version = 1
	LSM = Gladius.LSM
	if not self.frame then
		self.frame = { }
	end
	Gladius.db.auraVersion = self.version
	for spellID, _ in pairs(Gladius.db.classIconAuras) do
		if Gladius.dbi.profile.classIconAuras[spellID].enabled == nil then
			Gladius.dbi.profile.classIconAuras[spellID].enabled = true
		end
	end
end

function ClassIcon:OnDisable()
	self:UnregisterAllEvents()
	for unit in pairs(self.frame) do
		self.frame[unit]:SetAlpha(0)
	end
end

function ClassIcon:GetAttachTo()
	return Gladius.db.classIconAttachTo
end

function ClassIcon:IsDetached()
	return Gladius.db.classIconDetached
end

function ClassIcon:GetFrame(unit)
	return self.frame[unit]
end

function ClassIcon:UNIT_AURA(event, unit)
	if not Gladius:IsValidUnit(unit) then
		return
	end

	-- important auras
	self:UpdateAura(unit)
end

function ClassIcon:UpdateColors(unit)
	self.frame[unit].normalTexture:SetVertexColor(Gladius.db.classIconGlossColor.r, Gladius.db.classIconGlossColor.g, Gladius.db.classIconGlossColor.b, Gladius.db.classIconGloss and Gladius.db.classIconGlossColor.a or 0)
end

function ClassIcon:UpdateAura(unit)
	local unitFrame = self.frame[unit]

	if not unitFrame then
		return
	end

	if not Gladius.db.classIconAuras then
		return
	end

	local aura

	for _, auraType in pairs({'HELPFUL', 'HARMFUL'}) do
		for i = 1, 40 do
			local name, icon, _, _, duration, expires, _, _, _, spellid = UnitAura(unit, i, auraType)

			if not name then
				break
			end
			local auraList = Gladius.db.classIconAuras
			local priority = auraList[spellid].priority
			local enabled = Gladius.dbi.profile.classIconAuras[spellid].enabled

			if priority and (not aura or aura.priority < priority)  then
				aura = {
					name = name,
					icon = icon,
					duration = duration,
					expires = expires,
					spellid = spellid,
					priority = priority,
					enabled = enabled
				}
			end
		end
	end

	if aura and aura.enabled and (not unitFrame.aura or (unitFrame.aura.id ~= aura or unitFrame.aura.expires ~= aura.expires)) then
		self:ShowAura(unit, aura)
	elseif not aura then
		self.frame[unit].aura = nil
		self:SetClassIcon(unit)
	end
end

function ClassIcon:ShowAura(unit, aura)
	local unitFrame = self.frame[unit]
	unitFrame.aura = aura

	-- display aura
	unitFrame.texture:SetTexture(aura.icon)
	if Gladius.db.classIconCrop then
		unitFrame.texture:SetTexCoord(0.075, 0.925, 0.075, 0.925)
	else
		unitFrame.texture:SetTexCoord(0, 1, 0, 1)
	end

	local start

	if aura.expires then
		local timeLeft = aura.expires > 0 and aura.expires - GetTime() or 0
		start = GetTime() - (aura.duration - timeLeft)
	end

	Gladius:Call(Gladius.modules.Timer, "SetTimer", unitFrame, aura.duration, start)
end

function ClassIcon:SetClassIcon(unit)
	if not self.frame[unit] then
		return
	end
	Gladius:Call(Gladius.modules.Timer, "HideTimer", self.frame[unit])
	-- get unit class
	local class
	local specIcon
	if not Gladius.test then
		local frame = Gladius:GetUnitFrame(unit)
		class = frame.class
		specIcon = frame.specIcon
	else
		class = Gladius.testing[unit].unitClass
		if not IsWrathClassic then
			local _, _, _, icon = GetSpecializationInfoByID(Gladius.testing[unit].unitSpecId)
			specIcon = icon
		end
	end
	if Gladius.db.classIconShowSpec and not IsWrathClassic then
		if specIcon then
			self.frame[unit].texture:SetTexture(specIcon)
			local left, right, top, bottom = 0, 1, 0, 1
			-- Crop class icon borders
			if Gladius.db.classIconCrop then
				left = left + (right - left) * 0.075
				right = right - (right - left) * 0.075
				top = top + (bottom - top) * 0.075
				bottom = bottom - (bottom - top) * 0.075
			end
			self.frame[unit].texture:SetTexCoord(left, right, top, bottom)
		end
	else
		if class then
			self.frame[unit].texture:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
			local left, right, top, bottom = unpack(CLASS_BUTTONS[class])
			-- Crop class icon borders
			if Gladius.db.classIconCrop then
				left = left + (right - left) * 0.075
				right = right - (right - left) * 0.075
				top = top + (bottom - top) * 0.075
				bottom = bottom - (bottom - top) * 0.075
			end
			self.frame[unit].texture:SetTexCoord(left, right, top, bottom)
		end
	end
end

function ClassIcon:CreateFrame(unit)
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
	self.frame[unit].IconMask:Hide()

	-- secure
	local secure = CreateFrame("Button", "Gladius"..self.name.."SecureButton"..unit, button, "SecureActionButtonTemplate")
	secure:RegisterForClicks("AnyUp")
	self.frame[unit].secure = secure
end

function ClassIcon:Update(unit)
	-- TODO: check why we need this >_<
	self.frame = self.frame or { }

	-- create frame
	if not self.frame[unit] then
		self:CreateFrame(unit)
	end

	local unitFrame = self.frame[unit]

	-- update frame
	unitFrame:ClearAllPoints()
	local parent = Gladius:GetParent(unit, Gladius.db.classIconAttachTo)
	unitFrame:SetPoint(Gladius.db.classIconAnchor, parent, Gladius.db.classIconRelativePoint, Gladius.db.classIconOffsetX, Gladius.db.classIconOffsetY)
	-- frame level
	unitFrame:SetFrameLevel(Gladius.db.classIconFrameLevel)
	if Gladius.db.classIconAdjustSize then
		local height = false
		-- need to rethink that
		--[[for _, module in pairs(Gladius.modules) do
			if module:GetAttachTo() == self.name then
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
		unitFrame:SetWidth(Gladius.db.classIconSize)
		unitFrame:SetHeight(Gladius.db.classIconSize)
	end

	-- Secure frame
	if self.IsDetached() then
		unitFrame.secure:SetAllPoints(unitFrame)
		unitFrame.secure:SetHeight(unitFrame:GetHeight())
		unitFrame.secure:SetWidth(unitFrame:GetWidth())
		unitFrame.secure:Show()
	else
		unitFrame.secure:Hide()
	end

	unitFrame.texture:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	-- set frame mouse-interactable area
	local left, right, top, bottom = Gladius.buttons[unit]:GetHitRectInsets()
	if self:GetAttachTo() == "Frame" and not self:IsDetached() then
		if strfind(Gladius.db.classIconRelativePoint, "LEFT") then
			left = - unitFrame:GetWidth() + Gladius.db.classIconOffsetX
		else
			right = - unitFrame:GetWidth() + - Gladius.db.classIconOffsetX
		end
		-- search for an attached frame
		--[[for _, module in pairs(Gladius.modules) do
			if (module.attachTo and module:GetAttachTo() == self.name and module.frame and module.frame[unit]) then
				local attachedPoint = module.frame[unit]:GetPoint()
				if (strfind(Gladius.db.classIconRelativePoint, "LEFT") and (not attachedPoint or (attachedPoint and strfind(attachedPoint, "RIGHT")))) then
					left = left - module.frame[unit]:GetWidth()
				elseif (strfind(Gladius.db.classIconRelativePoint, "LEFT") and (not attachedPoint or (attachedPoint and strfind(attachedPoint, "LEFT")))) then
					right = right - module.frame[unit]:GetWidth()
				end
			end
		end]]
		-- top / bottom
		if unitFrame:GetHeight() > Gladius.buttons[unit]:GetHeight() then
			bottom = -(unitFrame:GetHeight() - Gladius.buttons[unit]:GetHeight()) + Gladius.db.classIconOffsetY
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
	unitFrame.normalTexture:SetVertexColor(Gladius.db.classIconGlossColor.r, Gladius.db.classIconGlossColor.g, Gladius.db.classIconGlossColor.b, Gladius.db.classIconGloss and Gladius.db.classIconGlossColor.a or 0)
	unitFrame.texture:SetTexCoord(left, right, top, bottom)

	-- cooldown
	unitFrame.cooldown.isDisabled = not Gladius.db.classIconCooldown
	unitFrame.cooldown:SetReverse(Gladius.db.classIconCooldownReverse)
	Gladius:Call(Gladius.modules.Timer, "RegisterTimer", unitFrame, Gladius.db.classIconCooldown)

	-- hide
	unitFrame:SetAlpha(0)
	self.frame[unit] = unitFrame
end

function ClassIcon:Show(unit)
	local testing = Gladius.test
	-- show frame
	self.frame[unit]:SetAlpha(1)
	-- set class icon
	self:UpdateAura(unit)
end

function ClassIcon:Reset(unit)
	-- reset frame
	self.frame[unit].aura = nil
	self.frame[unit]:SetScript("OnUpdate", nil)
	-- reset cooldown
	self.frame[unit].cooldown:SetCooldown(0, 0)
	-- reset texture
	self.frame[unit].texture:SetTexture("")
	-- hide
	self.frame[unit]:SetAlpha(0)
end

function ClassIcon:ResetModule()
	Gladius.db.classIconAuras = deepcopy(originalSpellTable)

	for spellID, spellData in pairs(Gladius.db.classIconAuras) do
		Gladius.dbi.profile.classIconAuras[spellID].enabled = true
		if spellData.priority then
			local spellInfo = GetSpellInfo(spellID)
			Gladius.options.args[self.name].args.auraList.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.iconID)
		end
	end
end


function ClassIcon:Test(unit)
    if not Gladius.db.classIconImportantAuras then
		return
	end

    local data = testSpells[unit]

    if not data then
		return
	end

    local spellInfo = GetSpellInfo(data.spellID)
	local enabled = Gladius.dbi.profile.classIconAuras[data.spellID].enabled
    if spellInfo.iconID and enabled then
        self:ShowAura(unit, {
			icon = spellInfo.iconID,
			duration = data.duration,
			})
        C_Timer.After(data.duration, function()
            ClassIcon:UNIT_AURA("any", unit)
        end)
    end
end


function ClassIcon:GetOptions()
	local options = {
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
						classIconImportantAuras = {
							type = "toggle",
							name = L["Class Icon Important Auras"],
							desc = L["Show important auras instead of the class icon"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 5,
						},
						classIconCrop = {
							type = "toggle",
							name = L["Class Icon Crop Borders"],
							desc = L["Toggle if the class icon borders should be cropped or not."],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 6,
						},
						sep = {
							type = "description",
							name = "",
							width = "full",
							order = 7,
						},
						classIconCooldown = {
							type = "toggle",
							name = L["Class Icon Cooldown Spiral"],
							desc = L["Display the cooldown spiral for important auras"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 10,
						},
						classIconCooldownReverse = {
							type = "toggle",
							name = L["Class Icon Cooldown Reverse"],
							desc = L["Invert the dark/bright part of the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 15,
						},
						classIconShowSpec = {
							type = "toggle",
							name = L["Class Icon Spec Icon"],
							desc = L["Shows the specialization icon instead of the class icon"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 16,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							order = 17,
						},
						classIconGloss = {
							type = "toggle",
							name = L["Class Icon Gloss"],
							desc = L["Toggle gloss on the class icon"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 20,
						},
						classIconGlossColor = {
							type = "color",
							name = L["Class Icon Gloss Color"],
							desc = L["Color of the class icon gloss"],
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
							order = 25,
						},
						sep3 = {
							type = "description",
							name = "",
							width = "full",
							order = 27,
						},
						classIconFrameLevel = {
							type = "range",
							name = L["Class Icon Frame Level"],
							desc = L["Frame level of the class icon"],
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
						classIconAdjustSize = {
							type = "toggle",
							name = L["Class Icon Adjust Size"],
							desc = L["Adjust class icon size to the frame size"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 5,
						},
						classIconSize = {
							type = "range",
							name = L["Class Icon Size"],
							desc = L["Size of the class icon"],
							min = 10,
							max = 100,
							step = 1,
							disabled = function()
								return Gladius.dbi.profile.classIconAdjustSize or not Gladius.dbi.profile.modules[self.name]
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
						classIconAttachTo = {
							type = "select",
							name = L["Class Icon Attach To"],
							desc = L["Attach class icon to given frame"],
							values = function()
								return Gladius:GetModules(self.name)
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 5,
						},
						classIconDetached = {
							type = "toggle",
							name = L["Detached from frame"],
							desc = L["Detach the cast bar from the frame itself"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 6,
						},
						classIconPosition = {
							type = "select",
							name = L["Class Icon Position"],
							desc = L["Position of the class icon"],
							values={ ["LEFT"] = L["Left"], ["RIGHT"] = L["Right"] },
							get = function()
								return strfind(Gladius.db.classIconAnchor, "RIGHT") and "LEFT" or "RIGHT"
							end,
							set = function(info, value)
								if (value == "LEFT") then
									Gladius.db.classIconAnchor = "TOPRIGHT"
									Gladius.db.classIconRelativePoint = "TOPLEFT"
								else
									Gladius.db.classIconAnchor = "TOPLEFT"
									Gladius.db.classIconRelativePoint = "TOPRIGHT"
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
						classIconAnchor = {
							type = "select",
							name = L["Class Icon Anchor"],
							desc = L["Anchor of the class icon"],
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
						classIconRelativePoint = {
							type = "select",
							name = L["Class Icon Relative Point"],
							desc = L["Relative point of the class icon"],
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
						classIconOffsetX = {
							type = "range",
							name = L["Class Icon Offset X"],
							desc = L["X offset of the class icon"],
							min = - 100, max = 100, step = 1,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 20,
						},
						classIconOffsetY = {
							type = "range",
							name = L["Class Icon Offset Y"],
							desc = L["Y offset of the class icon"],
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
		auraList = {
			type = "group",
			name = L["Auras"],
			childGroups = "tree",
			order = 3,
			args = {
				newAura = {
					type = "group",
					name = L["New Aura"],
					desc = L["New Aura"],
					inline = true,
					order = 1,
					args = {
						spell = {
							type = "input",
							name = L["Spell ID"],
							desc = L["Spell ID of the aura"],
							get = function()
								return self.newAuraID or ""
							end,
							set = function(info, value)
								self.newAuraID = value
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconImportantAuras
							end,
							order = 1,
						},
						priority = {
							type = "range",
							name = L["Priority"],
							desc = L["Select what priority the aura should have - higher equals more priority"],
							get = function()
								return self.newAuraPriority or 0
							end,
							set = function(info, value)
								self.newAuraPriority = value
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconImportantAuras
							end,
							min = 0,
							max = 20,
							step = 1,
							order = 2,
						},
						add = {
							type = "execute",
							name = L["Add new Aura"],
							func = function(info)
								if not self.newAuraID or self.newAuraID == "" then
									return
								end

								if not self.newAuraPriority then
									self.newAuraPriority = 0
								end
								
								local spellInfo = GetSpellInfo(self.newAuraID) or self.newAuraID
								Gladius.options.args[self.name].args.auraList.args["general"].args.spells.args[self.newAuraID] = self:SetupAura(self.newAuraID, self.newAuraPriority, spellInfo.name, spellInfo.iconID)
								Gladius.dbi.profile.classIconAuras[self.newAuraID] = {priority = self.newAuraPriority, name = spellInfo.name, iconID = spellInfo.iconID}
								print(self.newAuraID, self.newAuraPriority)
								self.newAuraID = ""
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconImportantAuras or not self.newAuraID or self.newAuraID == ""
							end,
							order = 3,
						},
					},
				}
			},
		},
	}

	if not options.auraList.args["general"] then
		options.auraList.args["general"] = self:SetupClass(nil, "General", 0)
	end

	for spellID, spellData in pairs(Gladius.db.classIconAuras) do
		local spellInfo = GetSpellInfo(spellID)
		local tooltip = ""
		local tooltipInfo = GetSpellByID(spellID, false, true, false, nil, true)

		if tooltipInfo and tooltipInfo.lines then
			for _, line in ipairs(tooltipInfo.lines) do
				tooltip = (line.leftText or "")
			end
		end

		for classID = 1, GetNumClasses() do
			local classInfo = GetClassInfo(classID)

			if not options.auraList.args[classInfo.classFile] and classInfo.classFile and classInfo.className then
				options.auraList.args[classInfo.classFile] = self:SetupClass(classInfo.classFile, classInfo.className)
			end

			if not options.auraList.args[classInfo.classFile].args.spells.args[tostring(spellID)] and classInfo.classFile == spellData.class and spellData.priority then
				options.auraList.args[classInfo.classFile].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.iconID, tooltip)
			elseif not options.auraList.args["general"].args.spells.args[tostring(spellID)] and not spellData.class and spellData.priority then
				options.auraList.args["general"].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.iconID, tooltip)
			end
		end
	end

	return options
end


function ClassIcon:SetupClass(classFile, className, order)
	local icon
	if classFile then
		icon = "|A:classicon-" .. string.lower(classFile) .. ":20:20|a "
	else
		icon = "|TInterface\\Icons\\INV_Misc_QuestionMark:20:20|t "
	end
	return {
		type = "group",
		name = icon .. className,
		order = order,
		args = {
			spells = {
				type = "group",
				name = "Tracked Spells",
				inline = true,
				order = 1,
				args = {
				}
			},
		}
	}
end


function ClassIcon:SetupAura(spellID, priority, name, iconID, tooltip)
	return {
		type = "group",
		name = "",
		order = - priority - 1,
		args = {
			spell = {
				type = "toggle",
				name = "|T" .. iconID .. ":20:20:0:0:64:64:5:59:5:59|t " .. name,
				order = 1,
				desc = tooltip,
				get = function ()
					return Gladius.dbi.profile.classIconAuras[spellID].enabled
				end,
				set = function (_, value)
					Gladius.dbi.profile.classIconAuras[spellID].enabled = value
				end,
			},
			priority = {
				type = "range",
				name = L["Priority"],
				desc = L["Select what priority the aura should have - higher equals more priority"],
				get = function ()
					return Gladius.dbi.profile.classIconAuras[spellID].priority
				end,
				set = function (_, value)
					Gladius.dbi.profile.classIconAuras[spellID].priority = value
				end,
				min = 0,
				max = 20,
				step = 1,
				order = 2,
				disabled = function()
					return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconImportantAuras
				end,
			},
		},
	}
end
