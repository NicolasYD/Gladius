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


-- @@@@@@@@@@@@@@@@@@@@@@@@@ Deepcopy Function @@@@@@@@@@@@@@@@@@@@@@@@@@@
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
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


local CDList = LibStub("CDList-1.0")
local defaultValues = CDList:GetDefensives()
local defensivesList = deepcopy(defaultValues)

-- Localizing commonly used global functions
local IsInInstance = IsInInstance
local strfind = string.find
local CreateFrame = CreateFrame
local pairs = pairs
local tostring = tostring
local tonumber = tonumber
local UnitClass = UnitClass
local GetArenaOpponentSpec = GetArenaOpponentSpec
local GetNumClasses = GetNumClasses
local GetSpellInfo = C_Spell.GetSpellInfo
local GetSpellTexture = C_Spell.GetSpellTexture
local GetClassInfo = C_CreatureInfo.GetClassInfo
local GetSpellByID = C_TooltipInfo.GetSpellByID


local Defensives = Gladius:NewModule("Defensives", false, true, {
	DefensivesAttachTo = "ClassIcon",
	DefensivesAnchor = "TOPLEFT",
	DefensivesRelativePoint = "BOTTOMLEFT",
	DefensivesAdjustSize = false,
	DefensivesMargin = 0,
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
	defensives = defaultValues,
})

-- @@@@@@@@@@@@@@@@@@@@@@@@ Helper Functions @@@@@@@@@@@@@@@@@@@@@@@@@@
function GetSortedClassIDs()

	-- Create table of all classes in the game
	local classes = {}
	for classID = 1, GetNumClasses() do
		local classInfo = GetClassInfo(classID)
		if classInfo then
			classes[classID] = classInfo
		end
	end

	-- Create a table where index == classID
	local sortedKeys = {}
	for classID in pairs(classes) do
		table.insert(sortedKeys, classID)
	end

	-- Sort table alphabetically by className
	table.sort(sortedKeys, function(a, b)
		return classes[a].className < classes[b].className
	end)

	local sortedClasses = {}
	sortedClasses[0] = {className = "General", classFile = "GENERAL", classID = nil}

	for index, classID in pairs(sortedKeys) do
		sortedClasses[index] = classes[classID]
	end


	return sortedClasses
end
local sortedClasses = GetSortedClassIDs()
local selectedSortedClass = 0


function Defensives:BuildOptions(options)
	if not options.auraList.args["GENERAL"] then
		options.auraList.args["GENERAL"] = self:SetupClass(nil, "General", 0)
	end

	for classID = 1, GetNumClasses() do
		local classInfo = GetClassInfo(classID)
		if classInfo and not options.auraList.args[classInfo.classFile] then
			options.auraList.args[classInfo.classFile] = self:SetupClass(classInfo.classFile, classInfo.className)
		end
	end

	for spellID, spellData in pairs(Gladius.dbi.profile.defensives) do
		if not spellData.deleted then
			local spellInfo = GetSpellInfo(spellID)
			local tooltip = ""
			local tooltipInfo = GetSpellByID(spellID, false, true, false, nil, true)

			if tooltipInfo and tooltipInfo.lines then
				for _, line in ipairs(tooltipInfo.lines) do
					tooltip = (line.leftText or "")
				end
			end

			if not spellData.class and spellData.priority and not options.auraList.args["GENERAL"].args.spells.args[tostring(spellID)] then
				options.auraList.args["GENERAL"].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.iconID, tooltip)

			elseif spellData.class and spellData.priority and not options.auraList.args[spellData.class].args.spells.args[tostring(spellID)] then
				options.auraList.args[spellData.class].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.iconID, tooltip)
			end
		end
	end
end
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


function Defensives:OnEnable()
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	LSM = Gladius.LSM
	if not self.frame then
		self.frame = { }
	end

	-- Activate auras in options by default
	for spellID, _ in pairs(Gladius.dbi.profile.defensives) do
		if Gladius.dbi.profile.defensives[spellID].enabled == nil then
			Gladius.dbi.profile.defensives[spellID].enabled = true
		end
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


function Defensives:DefensiveUsed(unit, spell)
    local _, instanceType = IsInInstance()
    if not Gladius.test and (instanceType ~= "arena" or not unit:find("arena") or unit:find("pet")) then
        return
    end

    local classFile, specID
    if Gladius.test then
        local testData = Gladius.testing[unit]
        if not testData then return end
        classFile = testData.unitClass
        specID = testData.unitSpecId
    else
        local _, class = UnitClass(unit)
        classFile = class
        local number = unit:match("%d+")
        specID = GetArenaOpponentSpec(number)
    end

	if not Gladius.dbi.profile.defensives[spell]
		or not Gladius.dbi.profile.defensives[spell].enabled
		or Gladius.dbi.profile.defensives[spell].deleted then
        return
    end

    local unitFrame = self.frame[unit]
    if not unitFrame then
		return
	end

    local tracker = unitFrame.tracker[spell]
    if not tracker then
        tracker = CreateFrame("CheckButton", "Gladius"..self.name.."FrameCat"..spell..unit, unitFrame, "ActionButtonTemplate")
        tracker.IconMask:Hide()
        unitFrame.tracker[spell] = tracker
        self:UpdateIcon(unit, spell)
    end

    local cooldown = CDList:GetCooldownNumber(spell, specID)
    local icon = GetSpellTexture(spell)

    tracker.active = true
    tracker.timeLeft = cooldown
    tracker.texture:SetTexture(icon)

    Gladius:Call(Gladius.modules.Timer, "SetTimer", tracker, cooldown)

    tracker:SetAlpha(1)
    self:SortIcons(unit, classFile)

    -- Only use OnUpdate for this tracker (not the whole frame)
    tracker:SetScript("OnUpdate", function(f, elapsed)
        f.timeLeft = f.timeLeft - elapsed
        if f.timeLeft <= 0 then
            f.active = false
            Gladius:Call(Gladius.modules.Timer, "HideTimer", f)
            f:SetScript("OnUpdate", nil)  -- Stop this tracker's update loop
            self:SortIcons(unit, classFile)
        end
    end)
end


function Defensives:SortIcons(unit, classFile)
	if Gladius.test then
		classFile = Gladius.testing[unit].unitClass
	end

    local margin = Gladius.db.DefensivesMargin
    local baseFrame = self.frame[unit]
    local lastFrame = baseFrame

    -- Collect active icons
    local activeIcons = {}
    for spellID, frame in pairs(self.frame[unit].tracker) do
		local config = Gladius.dbi.profile.defensives[spellID]
		local priority = config and config.priority ~= nil and config.priority or defensivesList[spellID] and defensivesList[spellID].priority
        if frame.active then
            table.insert(activeIcons, {
                spellID = spellID,
				classFile = classFile,
                frame = frame,
                priority = priority
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

	if defaultValues[spellID] and (unit == "arena1" or unit == "arena2" or unit == "arena3") then
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


function Defensives:ResetModule()
	if not self.frame then
		return
	end

	for unit, _ in pairs(self.frame) do
		self:Reset(unit)
	end

	Gladius.dbi.profile.defensives = {}
	Gladius.dbi.profile.defensives = deepcopy(defensivesList)
	Gladius.options.args[self.name].args.auraList.args["GENERAL"].args.spells.args = {}
	for _, spellData in pairs(Gladius.dbi.profile.defensives) do
		if spellData.class then
			Gladius.options.args[self.name].args.auraList.args[spellData.class].args.spells.args = {}
		end
	end

	for spellID, spellData in pairs(Gladius.dbi.profile.defensives) do
		Gladius.dbi.profile.defensives[spellID].enabled = true
		local spellInfo = GetSpellInfo(spellID)
		if spellData.priority and spellData.class then
			Gladius.options.args[self.name].args.auraList.args[spellData.class].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.iconID)
		elseif spellData.priority then
			Gladius.options.args[self.name].args.auraList.args["GENERAL"].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.iconID)
		end
	end

	local newAura = Gladius.options.args[self.name].args.auraList.args.newAura
		Gladius.options.args[self.name].args.auraList.args = {
			newAura = newAura,
		}

	self:BuildOptions(Gladius.options.args[self.name].args)
end


function Defensives:Test(unit)
    local testSpellDelay = 10
    local classFile = Gladius.testing[unit] and Gladius.testing[unit].unitClass

    -- Get a list of all spellIDs in the table
    local defensives = {}
    for spellID, spellData in pairs(defaultValues) do
		if (spellData.class == classFile or spellData.class == nil) then
			table.insert(defensives, spellID)
		end
    end

    local function triggerRandomSpell()
        if not Gladius.test then
            return
        end

        local randomIndex = math.random(1, #defensives)
        local randomSpellID = defensives[randomIndex]

		for spellID, _ in pairs(self.frame[unit].tracker) do
			if randomSpellID == spellID and self.frame[unit].tracker[randomSpellID].active then
				randomSpellID = nil
			end
		end

        if randomSpellID then
            self:DefensiveUsed(unit, randomSpellID)
        end

        -- Schedule the next spell cast
        C_Timer.After(testSpellDelay, triggerRandomSpell)
    end

    -- Start the testing loop
    triggerRandomSpell()
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
--[[ 						DefensivesCooldown = {
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
						}, ]]
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

		auraList = {
			type = "group",
			name = L["Defensives"],
			childGroups = "tree",
			order = 3,
			args = {
				newAura = {
					type = "group",
					name = L["Custom Spell"],
					inline = true,
					order = 1,
					args = {
						class = {
							type = "select",
							name = "Class",
							desc = "Choose the class of the tracked spell",
							values = (function ()
								local dropdown = {}
								for index, classData in pairs(sortedClasses) do
									local _, _, _, argbHex = GetClassColor(classData.classFile)
									if index == 0 then
										dropdown[index] = "|TInterface\\Icons\\INV_Misc_QuestionMark:20:20|t " .. classData.className
									else
										dropdown[index] = "|A:classicon-" .. string.lower(classData.classFile) .. ":20:20|a " .. " |c" .. argbHex .. classData.className .. "|r"
									end
								end

								return dropdown
							end)(),
							get = function(info)
								for index, classData in pairs(sortedClasses) do
									if index == selectedSortedClass then
										self.newClassFile = classData.classFile
									end
								end
								return selectedSortedClass
							end,
							set = function (_, value)
								selectedSortedClass = value
							end,
							order = 1,
						},
						spell = {
							type = "input",
							name = L["Spell ID"],
							desc = L["Spell ID of the spell that you want to track"],
							get = function()
								if self.newAuraID then
									return tostring(self.newAuraID)
								end
							end,
							set = function(info, value)
								self.newAuraID = tonumber(value)
							end,
							order = 2,
						},
						priority = {
							type = "range",
							name = L["Priority"],
							desc = L["Select what priority the tracked spell should have - higher equals more priority"],
							get = function()
								return self.newAuraPriority or 0
							end,
							set = function(info, value)
								self.newAuraPriority = value
							end,
							min = 0,
							max = 20,
							step = 1,
							order = 3,
						},
						add = {
							type = "execute",
							name = L["Add Spell"],
							func = function(info)
								if not self.newAuraID then
									return
								end

								if not self.newAuraPriority then
									self.newAuraPriority = 0
								end

								local spellInfo = GetSpellInfo(self.newAuraID)
								Gladius.options.args[self.name].args.auraList.args[self.newClassFile].args.spells.args[self.newAuraID] = self:SetupAura(self.newAuraID, self.newAuraPriority, spellInfo.name, spellInfo.iconID)
								if self.newClassFile == "GENERAL" then
									Gladius.dbi.profile.defensives[tonumber(self.newAuraID)] = {priority = self.newAuraPriority, name = spellInfo.name, iconID = spellInfo.iconID, enabled = true, deleted = false}
								else
									Gladius.dbi.profile.defensives[tonumber(self.newAuraID)] = {priority = self.newAuraPriority, class = self.newClassFile, name = spellInfo.name, iconID = spellInfo.iconID, enabled = true, deleted = false}
								end
								self.newAuraID = nil
							end,
							order = 4,
						},
						newAuraPreview = {
							type = "description",
							name = function()
								local spellData = Gladius.dbi.profile.defensives[self.newAuraID]
								local id = self.newAuraID
								local classes = {}

								for classID = 1, GetNumClasses() do
									local classInfo = GetClassInfo(classID)
									if classInfo then
										classes[classInfo.classFile] = classInfo.className
									end
								end

								if id and GetSpellInfo(id) then
									local spellName = GetSpellInfo(id).name
									local icon = GetSpellInfo(id).iconID

									if spellData and spellData.class then
										local classIcon = "|A:classicon-" .. string.lower(spellData.class) .. ":20:20|a "
										local _, _, _, argbHex = GetClassColor(spellData.class)
										return "|T" .. icon .. ":16:16|t " .. spellName .. "\n" .. "|cffff0000Error:|r " .. "This Spell is already being tracked for " .. classIcon .. " |c" .. argbHex .. (classes[spellData.class] or "General") .. "|r"
									end

									return "|T" .. icon .. ":16:16|t " .. spellName .. " (" .. id .. ")"
								else
									return "Invalid spell ID entered."
								end
							end,
							order = 5,
							fontSize = "medium",
							hidden = function()
								return not self.newAuraID
							end,
						},
					},
				}
			},
		},
	}

	self:BuildOptions(options)

	return options
end


function Defensives:SetupClass(classFile, className, order)
	local icon
	local _, _, _, argbHex = GetClassColor(classFile)
	if classFile then
		icon = "|A:classicon-" .. string.lower(classFile) .. ":20:20|a "
	else
		icon = "|TInterface\\Icons\\INV_Misc_QuestionMark:20:20|t "
	end
	return {
		type = "group",
		name = icon .. "|c" .. argbHex .. className .. "|r",
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


function Defensives:SetupAura(spellID, priority, name, iconID, tooltip)
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
					if Gladius.dbi.profile.defensives[spellID] then
						return Gladius.dbi.profile.defensives[spellID].enabled
					end
				end,
				set = function (_, value)
					Gladius.dbi.profile.defensives[spellID].enabled = value
				end,
			},
			priority = {
				type = "range",
				name = L["Priority"],
				desc = L["Select what priority the tracked spell should have - higher equals more priority"],
				get = function ()
					if Gladius.dbi.profile.defensives[spellID] then
						return Gladius.dbi.profile.defensives[spellID].priority
					end
				end,
				set = function (_, value)
					Gladius.dbi.profile.defensives[spellID].priority = value
				end,
				min = 0,
				max = 20,
				step = 1,
				order = 2,
			},
			delete = {
				type = "execute",
				name = L["Delete Spell"],
				func = function(info)
					local spell = tonumber(info[#(info) - 1])
					if spell then
						Gladius.db.defensives[spell] = nil
						Gladius.db.defensives[spell] = {deleted = true}
					end

					local newAura = Gladius.options.args[self.name].args.auraList.args.newAura
					Gladius.options.args[self.name].args.auraList.args = {
						newAura = newAura,
					}

					self:BuildOptions(Gladius.options.args[self.name].args)

					for unit, _ in pairs(self.frame) do
						self:Reset(unit)
					end

					Gladius:UpdateFrame()
				end,
				order = 3,
			},
		},
	}
end
