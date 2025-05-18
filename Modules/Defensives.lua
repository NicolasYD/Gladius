-- @@@@@@@@@@@@@@@@@@@@@@@@@ Defensives Module @@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Written by: Pharmac1st
-- Game Version: 11.1.5
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

local Gladius = _G.Gladius
if not Gladius then
	DEFAULT_CHAT_FRAME:AddMessage(format("Module %s requires Gladius", "Interrupts"))
end
local L = Gladius.L
local LSM

local CDList = LibStub("CDList-1.0")
local spellList = CDList.spellList
local defensifesList = CDList:GetDefensives()

-- Localizing commonly used global functions
local IsInInstance = IsInInstance
local strfind = string.find
local GetSpellTexture = C_Spell.GetSpellTexture
local CreateFrame = CreateFrame
local GetSpellInfo = C_Spell.GetSpellInfo
local UnitClass = UnitClass

local function SetDefaultClasses()
	local classes = {}
	for classId = 1, GetNumClasses() do
		local classInfo = C_CreatureInfo.GetClassInfo(classId)
		local key = classInfo.classFile

		classes[key] = {}
		classes["general"] = {}

		for spellID, spellData in pairs(defensifesList) do
			if spellData.class == key and spellData.category == "defensive" then
				classes[key][spellID] = spellData
				classes[key][spellID].enabled = true
			elseif spellData.category == "defensive" then
				classes["general"][spellID] = spellData
				classes["general"][spellID].enabled = true
			end
		end
	end
	return classes
end

local Defensives = Gladius:NewModule("Defensives", false, true, {
	DefensivesAttachTo = "ClassIcon",
	DefensivesAnchor = "TOPLEFT",
	DefensivesRelativePoint = "BOTTOMLEFT",
	DefensivesAdjustSize = false,
	DefensivesMargin = 5,
	DefensivesSize = 40,
	DefensivesOffsetX = 0,
	DefensivesOffsetY = 0,
	DefensivesFrameLevel = 1,
	DefensivesGloss = false,
	DefensivesGlossColor = {r = 1, g = 1, b = 1, a = 0.4},
	DefensivesCooldown = false,
	DefensivesCooldownReverse = false,
	DefensivesFontSize = 10,
	DefensivesFontColor = {r = 0, g = 1, b = 0, a = 1},
	DefensivesDetached = false,
	defensives = SetDefaultClasses(),
})


--@@@@@@@@@@@@@@@@@@@@ Shared Scopes @@@@@@@@@@@@@@@@@@@@@@
local testSpells = {
	["firstEvent"] = {
		arena1 = 45438, -- Ice Block
		arena2 = 53480, -- Roar of Sacrifice
		arena3 = 1966, -- Feint
	},
	["secondEvent"] = {
		arena1 = 108978, -- Alter Time
		arena2 = 264735, -- Survival of the Fittest
		arena3 = 1856, -- Vanish
	},
	["thirdEvent"] = {
		arena1 = 110960, -- Greater Invisibilitys
		arena2 = 186265, -- Aspect of the Turtle
		arena3 = 31224, -- Evasion
	}
}
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


--@@@@@@@@@@@@@@@@@@@@ Helper Functions @@@@@@@@@@@@@@@@@@@
local function GetDefensiveSpellData(spell)
    local spellData = spellList[spell]
    if spellData and spellData.category == "defensive" then
        return spellData
    end
    return nil
end
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


function Defensives:OnEnable()
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	LSM = Gladius.LSM
	if not self.frame then
		self.frame = { }
	end
end


function Defensives:OnDisable()
	self:UnregisterAllEvents()
	for _, unitFrame in pairs(self.frame) do
		unitFrame:Hide()
	end
end


function Defensives:GetAttachTo()
	return Gladius.db.DefensivesAttachTo
end


function Defensives:IsDetached()
	return Gladius.db.DefensivesDetached
end


function Defensives:GetFrame(unit)
	return self.frame[unit]
end


function Defensives:UpdateColors(unit)
	for spell, frame in pairs(self.frame[unit].tracker) do
		local tracked = self.frame[unit].tracker[spell]
		tracked.normalTexture:SetVertexColor(Gladius.db.DefensivesGlossColor.r, Gladius.db.DefensivesGlossColor.g, Gladius.db.DefensivesGlossColor.b, Gladius.db.DefensivesGloss and Gladius.db.DefensivesGlossColor.a or 0)
		tracked.text:SetTextColor(Gladius.db.DefensivesColor.r, Gladius.db.DefensivesFontColor.g, Gladius.db.DefensivesFontColor.b, Gladius.db.DefensivesFontColor.a)
	end
end


function Defensives:UpdateIcon(unit, spell)
	local tracked = self.frame[unit].tracker[spell]
	tracked:EnableMouse(false)
	tracked.reset = 0
	tracked:SetWidth(self.frame[unit]:GetHeight())
	tracked:SetHeight(self.frame[unit]:GetHeight())
	tracked:SetNormalTexture("Interface\\AddOns\\Gladius\\Images\\Gloss")
	tracked.texture = _G[tracked:GetName().."Icon"]
	tracked.normalTexture = _G[tracked:GetName().."NormalTexture"]

	tracked.cooldown = _G[tracked:GetName().."Cooldown"]
	tracked.cooldown.isDisabled = not Gladius.db.DefensivesCooldown
	tracked.cooldown:SetReverse(Gladius.db.DefensivesCooldownReverse)
	Gladius:Call(Gladius.modules.Timer, "RegisterTimer", tracked, Gladius.db.DefensivesCooldown)

	if not tracked.text then
		tracked.text = tracked:CreateFontString(nil, "OVERLAY")
	end

	tracked.text:SetDrawLayer("OVERLAY")
	tracked.text:SetJustifyH("RIGHT")
	tracked.text:SetPoint("BOTTOMRIGHT", tracked, -2, 0)
	tracked.text:SetFont(LSM:Fetch(LSM.MediaType.FONT, Gladius.db.globalFont), Gladius.db.DefensivesFontSize, "OUTLINE")
	tracked.text:SetTextColor(Gladius.db.DefensivesFontColor.r, Gladius.db.DefensivesFontColor.g, Gladius.db.DefensivesFontColor.b, Gladius.db.DefensivesFontColor.a)
	-- style action button
	tracked.normalTexture:SetHeight(self.frame[unit]:GetHeight() + self.frame[unit]:GetHeight() * 0.4)
	tracked.normalTexture:SetWidth(self.frame[unit]:GetWidth() + self.frame[unit]:GetWidth() * 0.4)
	tracked.normalTexture:ClearAllPoints()
	tracked.normalTexture:SetPoint("CENTER", 0, 0)
	tracked:SetNormalTexture("Interface\\AddOns\\Gladius\\Images\\Gloss")
	tracked.texture:ClearAllPoints()
	tracked.texture:SetPoint("TOPLEFT", tracked, "TOPLEFT")
	tracked.texture:SetPoint("BOTTOMRIGHT", tracked, "BOTTOMRIGHT")
	tracked.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	tracked.normalTexture:SetVertexColor(Gladius.db.DefensivesGlossColor.r, Gladius.db.DefensivesGlossColor.g, Gladius.db.DefensivesGlossColor.b, Gladius.db.DefensivesGloss and Gladius.db.DefensivesGlossColor.a or 0)
end


function Defensives:DefensiveUsed(unit, spell, class) -- not complete yet
	local _, instanceType = IsInInstance()
	if not Gladius.test and (instanceType ~= "arena" or not unit:find("arena") or unit:find("pet")) then
		return
	end

	if not self.frame[unit].tracker[spell] then
		self.frame[unit].tracker[spell] = CreateFrame("CheckButton", "Gladius"..self.name.."FrameCat"..spell..unit, self.frame[unit], "ActionButtonTemplate")
		self.frame[unit].tracker[spell].IconMask:Hide()
		self:UpdateIcon(unit, spell)
	end

	if not class then
		_, class, _ = UnitClass(unit)
	end

    local spellData = GetDefensiveSpellData(spell)

    if spellData and (Gladius.dbi.profile.defensives[class][spell] or Gladius.dbi.profile.defensives["general"][spell]) then
        local icon = GetSpellTexture(spell)
		local tracked = self.frame[unit].tracker[spell]
		tracked.active = true
		tracked.timeLeft = spellData.baseCooldown
        tracked.texture:SetTexture(icon)
		-- Gladius:Call(Gladius.modules.Timer, "RegisterTimer", self.frame[unit], Gladius.db.DefensivesCooldown, Gladius.db.DefensivesCooldown)
		Gladius:Call(Gladius.modules.Timer, "SetTimer", tracked, spellData.baseCooldown)
		tracked:SetScript("OnUpdate", function(f, elapsed)
			f.timeLeft = f.timeLeft - elapsed
			if f.timeLeft <= 0 then
				f.active = false
				Gladius:Call(Gladius.modules.Timer, "HideTimer", f)
				-- tracked[unit]:Hide()
				-- position icons
				self:SortIcons(unit, class)
				-- reset script
				self.frame[unit]:SetScript("OnUpdate", nil)
			end
		end)
		tracked:SetAlpha(1)
		self:SortIcons(unit, class)
    end
end


function Defensives:SortIcons(unit, class)
    local margin = Gladius.db.DefensivesMargin
    local baseFrame = self.frame[unit]
    local lastFrame = baseFrame

    -- Collect active icons
    local activeIcons = {}
    for spellID, frame in pairs(self.frame[unit].tracker) do
        if frame.active then
            table.insert(activeIcons, {
                spellID = spellID,
                frame = frame,
                priority = Gladius.dbi.profile.defensives[class][spellID] and Gladius.dbi.profile.defensives[class][spellID].priority
				or Gladius.dbi.profile.defensives["general"][spellID] and Gladius.dbi.profile.defensives["general"][spellID].priority
            })
        end
    end

    -- Step 2: Sort icons by descending priority
    table.sort(activeIcons, function(a, b)
        return a.priority > b.priority
    end)

    -- Step 3: Reposition and show icons
    for _, data in ipairs(activeIcons) do
        local frame = data.frame
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", lastFrame, lastFrame == baseFrame and "LEFT" or "RIGHT", margin, 0)
        lastFrame = frame
        frame:SetAlpha(1)
    end

    -- Hide inactive icons
    for spellID, frame in pairs(self.frame[unit].tracker) do
        if not frame.active then
            frame:SetAlpha(0)
        end
    end
end


function Defensives:UNIT_SPELLCAST_SUCCEEDED(event, unit, _, spellID)
	if not unit then
		return
	end
	if spellList[spellID] and spellList[spellID].category == "defensive" and (unit == "arena1" or unit == "arena2" or unit == "arena3") then
		self:DefensiveUsed(unit, spellID)
	end
end


function Defensives:CreateFrame(unit)
	local button = Gladius.buttons[unit]
	if not button then
		return
	end
	-- create frame
	self.frame[unit] = CreateFrame("CheckButton", "Gladius"..self.name.."Frame"..unit, button)
	self.frame[unit]:EnableMouse(false)
	self.frame[unit]:SetNormalTexture("Interface\\COMMON\\spacer")
end


function Defensives:Update(unit)
	-- create frame
	if not self.frame[unit] then
		self:CreateFrame(unit)
	end
	-- update frame
	self.frame[unit]:ClearAllPoints()
	-- anchor point
	local parent = Gladius:GetParent(unit, Gladius.db.DefensivesAttachTo)
	self.frame[unit]:SetPoint(Gladius.db.DefensivesAnchor, parent, Gladius.db.DefensivesRelativePoint, Gladius.db.DefensivesOffsetX, Gladius.db.DefensivesOffsetY)
	-- frame level
	self.frame[unit]:SetFrameLevel(Gladius.db.DefensivesFrameLevel)
	-- when the attached module is disabled
	if not Gladius:GetModule(self:GetAttachTo()) then
		Gladius.db.DefensivesAttachTo = "Frame"
	end
	if Gladius.db.DefensivesAdjustSize then
		if self:GetAttachTo() == "Frame" then
			local height = false
			if height then
				self.frame[unit]:SetWidth(Gladius.buttons[unit].height)
				self.frame[unit]:SetHeight(Gladius.buttons[unit].height)
			else
				self.frame[unit]:SetWidth(Gladius.buttons[unit].frameHeight)
				self.frame[unit]:SetHeight(Gladius.buttons[unit].frameHeight)
			end
		else
			self.frame[unit]:SetWidth(Gladius:GetModule(self:GetAttachTo()).frame[unit]:GetHeight() or 1)
			self.frame[unit]:SetHeight(Gladius:GetModule(self:GetAttachTo()).frame[unit]:GetHeight() or 1)
		end
	else
		self.frame[unit]:SetWidth(Gladius.db.DefensivesSize)
		self.frame[unit]:SetHeight(Gladius.db.DefensivesSize)
	end
	-- update icons
	if not self.frame[unit].tracker then
		self.frame[unit].tracker = { }
	else
		for spell, frame in pairs(self.frame[unit].tracker) do
			frame:SetWidth(self.frame[unit]:GetHeight())
			frame:SetHeight(self.frame[unit]:GetHeight())
			frame.normalTexture:SetHeight(self.frame[unit]:GetHeight() + self.frame[unit]:GetHeight() * 0.4)
			frame.normalTexture:SetWidth(self.frame[unit]:GetWidth() + self.frame[unit]:GetWidth() * 0.4)
			self:UpdateIcon(unit, spell)
		end
		self:SortIcons(unit)
	end
	-- hide
	self.frame[unit]:SetAlpha(0)
end

function Defensives:Show(unit)
	-- show frame
	self.frame[unit]:SetAlpha(1)
end


function Defensives:Reset(unit)
	if not self.frame[unit] then
		return
	end
	-- hide icons
	for _, frame in pairs(self.frame[unit].tracker) do
		frame.active = false
		Gladius:Call(Gladius.modules.Timer, "HideTimer", frame)
		frame:SetScript("OnUpdate", nil)
		frame:SetAlpha(0)
	end
	-- hide
	self.frame[unit]:SetAlpha(0)
end


function Defensives:Test(unit)
	local testSpellDelay = 5
	local firstTestSpell = testSpells["firstEvent"][unit]
	local secondTestSpell = testSpells["secondEvent"][unit]
	local thirdTestSpell = testSpells["thirdEvent"][unit]
	local class = Gladius.testing[unit].unitClass

	if firstTestSpell then
		self:DefensiveUsed(unit, firstTestSpell, class)
	end
	if secondTestSpell then
		C_Timer.After(testSpellDelay, function ()
			self:DefensiveUsed(unit, secondTestSpell, class)
		end)
	end
	if thirdTestSpell then
		C_Timer.After(testSpellDelay + 5, function ()
			self:DefensiveUsed(unit, thirdTestSpell, class)
		end)
	end
end


-- Add the announcement toggle
function Defensives:OptionsLoad()
	Gladius.options.args.Announcements.args.general.args.announcements.args.Defensives = {
		type = "toggle",
		name = L["Defensives"],
		desc = L["Announces when an enemy uses an important defensive cooldown."],
		disabled = function()
			return not Gladius.db.modules[self.name] or not Gladius.db.modules["Announcements"]
		end,
	}
end


function Defensives:GetOptions()
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
						DefensivesMargin = {
							type = "range",
							name = L["Defensives Space"],
							desc = L["Space between the icons"],
							min = 0,
							max = 100,
							step = 1,
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
						DefensivesCooldown = {
							type = "toggle",
							name = L["Defensives Cooldown Spiral"],
							desc = L["Display the cooldown spiral for important auras"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 10,
						},
						DefensivesCooldownReverse = {
							type = "toggle",
							name = L["Defensives Cooldown Reverse"],
							desc = L["Invert the dark/bright part of the cooldown spiral"],
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
						DefensivesGloss = {
							type = "toggle",
							name = L["Defensives Gloss"],
							desc = L["Toggle gloss on the Defensives icon"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return not Gladius.db.advancedOptions
							end,
							order = 25,
						},
						DefensivesGlossColor = {
							type = "color",
							name = L["Defensives Gloss Color"],
							desc = L["Color of the Defensives icon gloss"],
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
						DefensivesFrameLevel = {
							type = "range",
							name = L["Defensives Frame Level"],
							desc = L["Frame level of the Defensives"],
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
							order = 35,
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
						DefensivesAdjustSize = {
							type = "toggle",
							name = L["Defensives Adjust Size"],
							desc = L["Adjust Defensives size to the frame size"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 5,
						},
						DefensivesSize = {
							type = "range",
							name = L["Defensives Size"],
							desc = L["Size of the Defensives"],
							min = 10,
							max = 100,
							step = 1,
							disabled = function()
								return Gladius.dbi.profile.DefensivesAdjustSize or not Gladius.dbi.profile.modules[self.name]
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
						DefensivesAttachTo = {
							type = "select",
							name = L["Defensives Attach To"],
							desc = L["Attach Defensives to the given frame"],
							values = function()
								return Gladius:GetModules(self.name)
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 5,
						},
						DefensivesPosition = {
							type = "select",
							name = L["Defensives Position"],
							desc = L["Position of the class icon"],
							values={["LEFT"] = L["Left"], ["RIGHT"] = L["Right"]},
							get = function()
								return strfind(Gladius.db.DefensivesAnchor, "RIGHT") and "LEFT" or "RIGHT"
							end,
							set = function(info, value)
								if (value == "LEFT") then
									Gladius.db.DefensivesAnchor = "TOPRIGHT"
									Gladius.db.DefensivesRelativePoint = "TOPLEFT"
								else
									Gladius.db.DefensivesAnchor = "TOPLEFT"
									Gladius.db.DefensivesRelativePoint = "TOPRIGHT"
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
						DefensivesAnchor = {
							type = "select",
							name = L["Defensives Anchor"],
							desc = L["Anchor of the Defensives"],
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
						DefensivesRelativePoint = {
							type = "select",
							name = L["Defensives Relative Point"],
							desc = L["Relative point of the Defensives"],
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
						DefensivesOffsetX = {
							type = "range",
							name = L["Defensives Offset X"],
							desc = L["X offset of the Defensives"],
							min = - 100,
							max = 100,
							step = 1,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 20,
						},
						DefensivesOffsetY = {
							type = "range",
							name = L["Defensives Offset Y"],
							desc = L["Y offset of the Defensives"],
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

		defensives = {
			type = "group",
			name = L["Defensives"],
			order = 2,
			childGroups = "tree",
			args = (function ()
				-- Prepare the classOptions table
				local classOptions = {}

				classOptions["GENERAL"] = {
					type = "group",
					name = "|TInterface\\Icons\\INV_Misc_QuestionMark:20:20|t General",
					order = 0,
					args = {
						headerBeginning = {
							type = "header",
							name = "General",
							order = 1,
						},
						description = {
							type = "description",
							name = "Choose the spells that you want to be tracked by this module.",
							order = 2,
						},
						headerEnd = {
								type = "header",
								name = "",
								order = 3,
						},
						spells = {
							type = "group",
							name = "Tracked Defensives",
							inline = true,
							order = 4,
							args = (function()
								local spellArgs = {}
								for spellID, spellData in pairs(defensifesList) do
									if spellData.class == nil then
										local spellInfo = GetSpellInfo(spellID)
										local tooltip = ""
										local tooltipInfo = C_TooltipInfo.GetSpellByID(spellID)

										if tooltipInfo and tooltipInfo.lines then
											for _, line in ipairs(tooltipInfo.lines) do
												local left = line.leftText or ""
												if left ~= "" and left ~= spellInfo.name then
													tooltip = left
												end
											end
										end

										if spellInfo then
											spellArgs["spellgroup_" .. spellID] = {
												type = "group",
												inline = true,
												name = "",
												order = - spellData.priority,
												args = {
													toggle = {
														type = "toggle",
														name = "|T" .. spellInfo.iconID .. ":20:20:0:0:64:64:5:59:5:59|t " .. spellInfo.name,
														order = 1,
														desc = tooltip,
														get = function()
															return Gladius.dbi.profile.defensives["general"][spellID].enabled
														end,
														set = function(_, value)
															Gladius.dbi.profile.defensives["general"][spellID].enabled = value
														end,
													},
													slider = {
														type = "range",
														name = "Priority",
														order = 2,
														desc = "Adjust the priority of this spell.\nHigher priority icons show more left on the tracking frame.",
														min = 0,
														max = 20,
														step = 1,
														get = function()
															return Gladius.dbi.profile.defensives["general"][spellID].priority
														end,
														set = function(_, value)
															Gladius.dbi.profile.defensives["general"][spellID].priority = value
														end,
													},
												}
											}
										end
									end
								end
								return spellArgs
							end)()
						}
					},
				}

				-- Prepare the classes table
				local classes = {}

				-- Populate list with all classes currently in the game
				for classId = 1, GetNumClasses() do
					local classInfo = C_CreatureInfo.GetClassInfo(classId)
					table.insert(classes, classInfo)
				end

				-- Sort classes alphabetically by className
				table.sort(classes, function(a, b)
					return a.className < b.className
				end)

				-- Loop through the sorted classes
				for _, classInfo in ipairs(classes) do
					local key = classInfo.classFile  -- use classFile as the key
					local className = classInfo.className
					local iconMarkup = "|A:classicon-" .. string.lower(key) .. ":20:20|a "

					classOptions[key] = {
						type = "group",
						name = iconMarkup .. className, -- icon + name
						args = {
							headerBeginning = {
								type = "header",
								name = classInfo.className,
								order = 1,
							},
							description = {
								type = "description",
								name = "Choose the spells that you want to be tracked by this module.",
								order = 2,
							},
							headerEnd = {
								type = "header",
								name = "",
								order = 3,
							},
							spells = {
								type = "group",
								name = "Tracked Defensives",
								inline = true,
								order = 4,
								args = (function()
									local spellArgs = {}
									for spellID, spellData in pairs(defensifesList) do
										if spellData.class == key then
											local spellInfo = GetSpellInfo(spellID)
											local tooltip = ""
											local tooltipInfo = C_TooltipInfo.GetSpellByID(spellID)

											if tooltipInfo and tooltipInfo.lines then
												for _, line in ipairs(tooltipInfo.lines) do
													local left = line.leftText or ""
													if left ~= "" and left ~= spellInfo.name then
														tooltip = left
													end
												end
											end

											if spellInfo then
												spellArgs["spellgroup_" .. spellID] = {
													type = "group",
													inline = true,
													name = "",
													order = - spellData.priority,
													args = {
														toggle = {
															type = "toggle",
															name = "|T" .. spellInfo.iconID .. ":20:20:0:0:64:64:5:59:5:59|t " .. spellInfo.name,
															order = 1,
															desc = tooltip,
															get = function()
																return Gladius.dbi.profile.defensives[key][spellID].enabled
															end,
															set = function(_, value)
																Gladius.dbi.profile.defensives[key][spellID].enabled = value
															end,
														},
														slider = {
															type = "range",
															name = "Priority",
															order = 2,
															desc = "Adjust the priority of this spell.\nHigher priority icons show more left on the tracking frame.",
															min = 0,
															max = 20,
															step = 1,
															get = function()
																return Gladius.dbi.profile.defensives[key][spellID].priority
															end,
															set = function(_, value)
																Gladius.dbi.profile.defensives[key][spellID].priority = value
															end,
														},
													}
												}
											end
										end
									end
									return spellArgs
								end)()
							},
						},
					}
				end
				return classOptions
			end)()
		}
	}
	return options
end