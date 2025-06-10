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
local defaultValues = CDList:GetSpellsByCategory("defensive")
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
	DefensivesAttachTo = "CastBar",
	DefensivesAnchor = "TOPLEFT",
	DefensivesRelativePoint = "TOPRIGHT",
	DefensivesAdjustSize = false,
	DefensivesMargin = 5,
	DefensivesSize = 40,
	DefensivesOffsetX = 0,
	DefensivesOffsetY = 0,
	DefensivesFrameLevel = 1,
	DefensivesIconCrop = true,
	DefensivesCooldown = true,
	DefensivesCooldownReverse = false,
	DefensivesCooldownSwipeAlpha = 0.5,
	DefensivesCooldownEdge = true,
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

	for spellID, spellData in pairs(Gladius.db.defensives) do
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
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	LSM = Gladius.LSM
	if not self.frame then
		self.frame = { }
	end

	-- Activate auras in options by default
	for spellID, _ in pairs(Gladius.db.defensives) do
		if Gladius.db.defensives[spellID].enabled == nil then
			Gladius.db.defensives[spellID].enabled = true
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


function Defensives:UNIT_SPELLCAST_SUCCEEDED(event, unit, _, spellID)
	if not unit then
		return
	end

	if defaultValues[spellID] and (unit == "arena1" or unit == "arena2" or unit == "arena3") then
		self:DefensiveUsed(unit, spellID)
	end
end


function Defensives:GROUP_ROSTER_UPDATE()
	self:ResetDefensivesShuffle()
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

    local spellConfig = Gladius.db.defensives[spell]
    if not spellConfig or not spellConfig.enabled or spellConfig.deleted then
        return
    end

    if not self.frame[unit] or not self.frame[unit].spells then return end

    local spells = self.frame[unit].spells
    local anchor = self.frame[unit]
    local frame = spells[spell]

    if not frame then
        -- Create new spell frame
        frame = CreateFrame("Frame", "Gladius"..self.name.."SpellFrame"..unit..spell, anchor)
        frame:SetSize(Gladius.db.DefensivesSize, Gladius.db.DefensivesSize)

        local frameName = frame:GetName()

        frame.texture = frame:CreateTexture(frameName .. "Icon", "BACKGROUND")
        frame.texture:SetAllPoints()
        frame.texture:SetTexture(GetSpellTexture(spell))

        -- Create cooldown overlay
        frame.cooldown = CreateFrame("Cooldown", frameName .. "Cooldown", frame, "CooldownFrameTemplate")
        frame.cooldown:SetAllPoints()

        spells[spell] = frame
    end

	-- Frame styling
	if Gladius.db.DefensivesIconCrop then
		frame.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	else
		frame.texture:SetTexCoord(0, 1, 0, 1)
	end

	frame.cooldown:SetDrawBling(false)
	frame.cooldown:SetDrawSwipe(Gladius.db.DefensivesCooldown)
	frame.cooldown:SetDrawEdge(Gladius.db.DefensivesCooldownEdge)
	frame.cooldown:SetSwipeColor(0, 0, 0, Gladius.db.DefensivesCooldownSwipeAlpha)
	frame.cooldown:SetReverse(Gladius.db.DefensivesCooldownReverse)
	frame.cooldown.isDisabled = not Gladius.db.DefensivesCooldown

	-- Assign priority for each frame
	frame.priority = Gladius.db.defensives[spell].priority

    -- Timer setup
    local cooldown = CDList:GetCooldownNumber(spell, specID)
    frame.timeLeft = cooldown
    frame.active = true

    Gladius:Call(Gladius.modules.Timer, "RegisterTimer", frame, Gladius.db.DefensivesCooldown)
    Gladius:Call(Gladius.modules.Timer, "SetTimer", frame, cooldown)

    -- OnUpdate for expiration
    frame:SetScript("OnUpdate", function(f, elapsed)
        f.timeLeft = f.timeLeft - elapsed
        if f.timeLeft <= 0 then
            f:SetScript("OnUpdate", nil)
            f.active = false
            f:SetAlpha(0)
            Gladius:Call(Gladius.modules.Timer, "HideTimer", f)
            self:SortIcons(unit)
        end
    end)

    self:SortIcons(unit)
end


function Defensives:SortIcons(unit)
	local baseFrame = self.frame[unit]
	if not baseFrame or not baseFrame.spells then return end

	local activeFrames = {}

	-- Collect active frames
	for spell, frame in pairs(baseFrame.spells) do
		if frame.active and Gladius.db.defensives[spell].enabled then
			-- Assign priority from spell config or default to 0
			local spellConfig = Gladius.dbi.profile.defensives[spell]
			frame.priority = (spellConfig and spellConfig.priority) or 0
			table.insert(activeFrames, frame)
		else
			frame:SetAlpha(0)
		end
	end

	-- Sort by priority descending (highest priority first)
	table.sort(activeFrames, function(a, b)
		return a.priority > b.priority
	end)

	-- Anchor sorted icons
	local lastFrame = baseFrame
	for i, frame in ipairs(activeFrames) do
		frame:ClearAllPoints()
		frame:SetPoint(
			Gladius.db.DefensivesAnchor,
			lastFrame,
			lastFrame == baseFrame and Gladius.db.DefensivesAnchor or Gladius.db.DefensivesRelativePoint,
			strfind(Gladius.db.DefensivesAnchor, "LEFT") and Gladius.db.DefensivesMargin or -Gladius.db.DefensivesMargin,
			0
		)
		lastFrame = frame
		frame:SetAlpha(1)
	end
end


function Defensives:CreateFrame(unit)
	local button = Gladius.buttons[unit]
	if not button then
		return
	end

	-- Create a parent frame
	self.frame[unit] = CreateFrame("CheckButton", "Gladius"..self.name.."Frame"..unit, button)
	self.frame[unit]:EnableMouse(false)

	-- Prepare a table to hold per-spell frames if it doesn't exist
    self.frame[unit].spells = self.frame[unit].spells or {}
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
end


function Defensives:Reset(unit)
	if not self.frame[unit] then
		return
	end
	-- hide icons
	for _, frame in pairs(self.frame[unit].spells) do
		frame.active = false

		-- Stop any active timers and updates
		frame:SetScript("OnUpdate", nil)
		Gladius:Call(Gladius.modules.Timer, "HideTimer", frame)
		frame:SetAlpha(0)
	end
end


function Defensives:ResetDefensivesShuffle()
    for i = 1, 3 do
        local unit = "arena"..i

		-- Cleanup old frame if it exists
		if self.frame[unit] then
			-- Hide and unparent old spell frames
			if self.frame[unit].spells then
				for spell, frame in pairs(self.frame[unit].spells) do
					frame:Hide()
					frame:SetParent(nil)
					frame:UnregisterAllEvents()
				end
				self.frame[unit].spells = nil
			end

			-- Hide and unparent the parent frame
			self.frame[unit]:Hide()
			self.frame[unit]:SetParent(nil)
			self.frame[unit]:UnregisterAllEvents()
			self.frame[unit] = nil
		end

		self:CreateFrame(unit)
    end
end


function Defensives:ResetModule()
	if not self.frame then
		return
	end

	for unit, _ in pairs(self.frame) do
		self:Reset(unit)
	end

	Gladius.db.defensives = {}
	Gladius.db.defensives = deepcopy(defensivesList)
	Gladius.options.args[self.name].args.auraList.args["GENERAL"].args.spells.args = {}
	for _, spellData in pairs(Gladius.db.defensives) do
		if spellData.class then
			Gladius.options.args[self.name].args.auraList.args[spellData.class].args.spells.args = {}
		end
	end

	for spellID, spellData in pairs(Gladius.db.defensives) do
		Gladius.db.defensives[spellID].enabled = true
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
	if not Gladius.test then
		return
	end

    local classFile = Gladius.testing[unit] and Gladius.testing[unit].unitClass
	local specID = Gladius.testing[unit] and Gladius.testing[unit].unitSpecId

    -- Get a list of all spellIDs in the table
    local defensives = {}
    for spellID, spellData in pairs(defaultValues) do
		if defaultValues[spellID]["specID"] then
			for _, value in pairs(defaultValues[spellID]["specID"]) do
				if (spellData.class == classFile or spellData.class == nil) and (value == specID or value == nil) then
					table.insert(defensives, spellID)
				end
			end
		else
			if (spellData.class == classFile or spellData.class == nil) then
				table.insert(defensives, spellID)
			end
		end
    end

	for index, spellID in ipairs(defensives) do
		self:DefensiveUsed(unit, defensives[index])
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
					hidden = function ()
						return not Gladius.db.advancedOptions
					end,
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
							width = "double",
							order = 5,
						},
						sep1 = {
							type = "description",
							name = "",
							width = "full",
							order = 8,
						},
						DefensivesIconCrop = {
							type = "toggle",
							name = L["Defensives Icon Border Crop"],
							desc = L["Toggle if the borders of the defensives icon should be cropped"],
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
						DefensivesCooldown = {
							type = "toggle",
							name = L["Defensives Cooldown Spiral"],
							desc = L["Display the cooldown spiral for important auras"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
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
						DefensivesCooldownReverse = {
							type = "toggle",
							name = L["Defensives Cooldown Reverse"],
							desc = L["Invert the dark/bright part of the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
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
						DefensivesCooldownEdge = {
							type = "toggle",
							name = L["Defensives Cooldown Edge"],
							desc = L["Display the edge texture for the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.DefensivesCooldown
							end,
							width = "double",
							order = 25,
						},
						sep5 = {
							type = "description",
							name = "",
							width = "full",
							order = 28,
						},
						DefensivesCooldownSwipeAlpha = {
							type = "range",
							name = L["Defensives Cooldown Swipe Alpha"],
							desc = L["Set the darkness of the cooldown swipe animation"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.DefensivesCooldown
							end,
							min = 0,
							max = 1,
							step = 0.1,
							width = "double",
							order = 30,
						},
						sep6 = {
							type = "description",
							name = "",
							width = "full",
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
							order = 5,
						},
						sep1 = {
							type = "description",
							name = "",
							width = "full",
							order = 8,
						},
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
							order = 10,
						},
						DefensivesDetached = {
							type = "toggle",
							name = L["Detached from frame"],
							desc = L["Detach the module from the frame itself"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function ()
								return Gladius.db.DefensivesAttachTo ~= "Frame"
							end,
							order = 15,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							order = 18,
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
							order = 20,
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
							order = 25,
						},
						sep3 = {
							type = "description",
							name = "",
							width = "full",
							order = 28,
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
							order = 30,
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
							order = 35,
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
									Gladius.db.defensives[tonumber(self.newAuraID)] = {priority = self.newAuraPriority, name = spellInfo.name, iconID = spellInfo.iconID, enabled = true, deleted = false}
								else
									Gladius.db.defensives[tonumber(self.newAuraID)] = {priority = self.newAuraPriority, class = self.newClassFile, name = spellInfo.name, iconID = spellInfo.iconID, enabled = true, deleted = false}
								end
								self.newAuraID = nil
								Gladius:UpdateFrame()
							end,
							order = 4,
						},
						newAuraPreview = {
							type = "description",
							name = function()
								local spellData = Gladius.db.defensives[self.newAuraID]
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
					if Gladius.db.defensives[spellID] then
						return Gladius.db.defensives[spellID].enabled
					end
				end,
				set = function (_, value)
					Gladius.db.defensives[spellID].enabled = value
					for i = 1, 3 do
        				local unit = "arena"..i
						self:SortIcons(unit)
					end
				end,
			},
			priority = {
				type = "range",
				name = L["Priority"],
				desc = L["Select what priority the tracked spell should have - higher equals more priority"],
				get = function ()
					if Gladius.db.defensives[spellID] then
						return Gladius.db.defensives[spellID].priority
					end
				end,
				set = function (_, value)
					Gladius.db.defensives[spellID].priority = value
					Gladius:UpdateFrame()
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
