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
local interruptsList = CDList:GetSpellsByCategory("interrupt")
local spellTableUnordered = CDList:GetPrioritySpells()
local spellTable = CDList:OrderAlphabetically(spellTableUnordered)
local originalSpellTable = deepcopy(spellTable)

-- Global Functions
local _G = _G
local pairs = pairs
local strfind = string.find
local tostring = tostring
local tonumber = tonumber

local CreateFrame = CreateFrame
local GetSpecializationInfoByID = GetSpecializationInfoByID
local GetNumClasses = GetNumClasses
local GetTime = GetTime
local UnitGUID = UnitGUID
local GetSpellInfo = C_Spell.GetSpellInfo
local GetSpellDescription = C_Spell.GetSpellDescription
local RequestLoadSpellData = C_Spell.RequestLoadSpellData
local GetClassInfo = C_CreatureInfo.GetClassInfo
local UnitAura = C_UnitAuras.GetAuraDataByIndex

local CLASS_BUTTONS = CLASS_ICON_TCOORDS

local IsWrathClassic = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

local ClassIcon = Gladius:NewModule("ClassIcon", false, true, {
	classIconAttachTo = "Frame",
	classIconAnchor = "TOPRIGHT",
	classIconRelativePoint = "TOPLEFT",
	classIconAdjustSize = false,
	classIconSize = 50,
	classIconOffsetX = 0,
	classIconOffsetY = 0,
	classIconFrameLevel = 1,
	classIconImportantAuras = true,
	classIconCrop = true,
	classIconCooldown = true,
	classIconCooldownReverse = true,
	classIconCooldownSwipeAlpha = 0.4,
	classIconCooldownEdge = true,
	classIconShowSpec = true,
	classIconDetached = false,
	classIconAuras = spellTable,
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


local descriptions = CreateFrame("Frame")
descriptions.cache = {}
descriptions:SetScript("OnEvent", function(self, event, spellID, success)
    if success then
        self.cache[spellID] = GetSpellDescription(spellID)
    end
end)
descriptions:RegisterEvent("SPELL_DATA_LOAD_RESULT")


function ClassIcon:BuildOptions(options)
	if not options.auraList.args["GENERAL"] then
		options.auraList.args["GENERAL"] = self:SetupClass(nil, "General", 0)
	end

	for classID = 1, GetNumClasses() do
		local classInfo = GetClassInfo(classID)
		if classInfo and not options.auraList.args[classInfo.classFile] then
			options.auraList.args[classInfo.classFile] = self:SetupClass(classInfo.classFile, classInfo.className)
		end
	end

	for spellID, spellData in pairs(Gladius.dbi.profile.classIconAuras) do
		if not descriptions.cache[spellID] then
			RequestLoadSpellData(spellID)
		end

		if not spellData.deleted then
			local spellInfo = GetSpellInfo(spellID)
			if not spellData.parent then
				if not spellData.class and not options.auraList.args["GENERAL"].args.spells.args[tostring(spellID)] then
					options.auraList.args["GENERAL"].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.originalIconID, spellData.order)

				elseif spellData.class and not options.auraList.args[spellData.class].args.spells.args[tostring(spellID)] then
					options.auraList.args[spellData.class].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.originalIconID, spellData.order)
				end
			elseif spellData.priority then
				local class = spellTable[spellData.parent].class
				if not class and not options.auraList.args["GENERAL"].args.spells.args[tostring(spellID)] then
					options.auraList.args["GENERAL"].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.originalIconID, spellData.order)

				elseif class and not options.auraList.args[class].args.spells.args[tostring(spellID)] then
					options.auraList.args[class].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.originalIconID, spellData.order)
				end
			end
		end
	end
end
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


function ClassIcon:OnEnable()
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self.version = 1
	LSM = Gladius.LSM
	if not self.frame then
		self.frame = { }
	end
	Gladius.db.auraVersion = self.version

	-- Activate auras in options by default
	for spellID, _ in pairs(Gladius.dbi.profile.classIconAuras) do
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


function ClassIcon:COMBAT_LOG_EVENT_UNFILTERED(event)
	local _, subEvent, _, _, _, _, _, destGUID, _, _, _, spellID, _, _, _, _, _, _ = CombatLogGetCurrentEventInfo()

    if subEvent == "SPELL_INTERRUPT" then
        for spell, data in pairs(interruptsList) do
            if spellID == spell then
				local spellInfo = GetSpellInfo(spellID)
				for i = 1, GetNumArenaOpponents() do
					local unit = "arena" .. i
					if destGUID == UnitGUID(unit) then
						local time = GetTime()
						local config = Gladius.dbi.profile.classIconAuras[spellID]
						local aura = {
							name = spellInfo.name,
							icon = spellInfo.originalIconID,
							duration = data.duration or 0,
							expires = data.duration and (time + data.duration) or 0,
							spellid = spellID,
							priority = data.priority or 0,
							enabled = config.enabled ~= false, -- Defaults to true, unless explicitly false
							deleted = config.deleted == true, -- Defaults to false, unless explicitly true
						}
						self:ShowAura(unit, aura)
					end
				end
            end
        end
    end
end


function ClassIcon:UpdateAura(unit, spell, duration)
	local unitFrame = self.frame[unit]
	local auraList = Gladius.dbi.profile.classIconAuras
	local aura

	if not unitFrame or not auraList then
		return
	end

	for _, auraType in pairs({'HELPFUL', 'HARMFUL'}) do
		for i = 1, 40 do
			local auraData = UnitAura(unit, i, auraType)

			if Gladius.test and testSpell and i == 1 then
				local spellInfo = GetSpellInfo(testSpell.spellID)
				auraData = {
					name = spellInfo.name,
					icon = spellInfo.originalIconID,
					duration = testSpell.duration or 5,
					expirationTime = testSpell.expirationTime or GetTime() + 5,
					spellId = spellInfo.spellID
				}
			end

			if not auraData then
				break
			end

            local config = auraList[auraData.spellId]
			if config and (not aura or aura.priority < (config.priority or 0)) then
				aura = {
					name = auraData.name,
					icon = auraData.icon,
					duration = auraData.duration,
					expires = auraData.expirationTime,
					spellid = auraData.spellId,
					priority = config.priority or (config.parent and auraList[config.parent].priority) or 0,
					enabled = config.enabled,
					deleted = config.deleted
				}
			end
		end
	end

	if aura and aura.enabled and not aura.deleted and (not unitFrame.aura or (unitFrame.aura.id ~= aura or unitFrame.aura.expires ~= aura.expires)) then
		self:ShowAura(unit, aura)
	elseif not aura then
		self.frame[unit].aura = nil
		self:SetClassIcon(unit)
	end
end


function ClassIcon:ShowAura(unit, aura)
	local unitFrame = self.frame[unit]
	local time = GetTime() or 0

	if unitFrame and unitFrame.priority and aura and aura.priority then
		if unitFrame.priority > aura.priority and time < unitFrame.expires then
			return
		end
	end

	unitFrame.priority = aura.priority
	unitFrame.expires = aura.expires
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
		local timeLeft = aura.expires > 0 and (aura.expires - time) or 0
		start = aura.duration and (time - (aura.duration - timeLeft)) or 0
	end
	-- cooldown
	if not Gladius.db.modules["Timer"] then
		self.frame[unit].cooldown:SetHideCountdownNumbers(false)
		self.frame[unit].cooldown:SetCooldown(GetTime(), aura.duration)
	else
		Gladius:Call(Gladius.modules.Timer, "SetTimer", unitFrame, aura.duration or 0, start)
	end

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

	-- Create a parent frame
	self.frame[unit] = CreateFrame("CheckButton", "Gladius"..self.name.."Frame"..unit, button)
	local frameName = self.frame[unit]:GetName()

	self.frame[unit]:EnableMouse(false)
	self.frame[unit]:SetSize(Gladius.db.classIconSize, Gladius.db.classIconSize)
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


function ClassIcon:Update(unit)
	if not Gladius.db.classIconImportantAuras then
		self:Reset(unit)
	end

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

	-- cooldown
	-- Optional styling
	unitFrame.cooldown:SetDrawBling(false)
	unitFrame.cooldown:SetDrawSwipe(Gladius.db.classIconCooldown)
	unitFrame.cooldown:SetReverse(Gladius.db.classIconCooldownReverse)
	unitFrame.cooldown:SetSwipeColor(0, 0, 0, Gladius.db.classIconCooldownSwipeAlpha)
	unitFrame.cooldown:SetDrawEdge(Gladius.db.classIconCooldown and Gladius.db.classIconCooldownEdge)
	Gladius:Call(Gladius.modules.Timer, "RegisterTimer", unitFrame, Gladius.db.classIconCooldown)

	-- Secure frame
	if self:IsDetached() then
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

		-- top / bottom
		if unitFrame:GetHeight() > Gladius.buttons[unit]:GetHeight() then
			bottom = -(unitFrame:GetHeight() - Gladius.buttons[unit]:GetHeight()) + Gladius.db.classIconOffsetY
		end
		Gladius.buttons[unit]:SetHitRectInsets(left, right, 0, 0)
		Gladius.buttons[unit].secure:SetHitRectInsets(left, right, 0, 0)
	end

	-- hide
	unitFrame:SetAlpha(0)
end


function ClassIcon:Show(unit)
	local testing = Gladius.test
	-- show frame
	self.frame[unit]:SetAlpha(1)
	-- set class icon
	self:UpdateAura(unit)
end


function ClassIcon:Reset(unit)
	-- Cancel testmode ticker
	if self.testTicker and self.testTicker[unit] then
		self.testTicker[unit]:Cancel()
		self.testTicker[unit] = nil
	end
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
	Gladius.dbi.profile.classIconAuras = {}
	Gladius.dbi.profile.classIconAuras = deepcopy(originalSpellTable)
	Gladius.options.args[self.name].args.auraList.args["GENERAL"].args.spells.args = {}
	for _, spellData in pairs(Gladius.dbi.profile.classIconAuras) do
		if spellData.class then
			Gladius.options.args[self.name].args.auraList.args[spellData.class].args.spells.args = {}
		end
	end

	for spellID, spellData in pairs(Gladius.dbi.profile.classIconAuras) do
		Gladius.dbi.profile.classIconAuras[spellID].enabled = true
		local spellInfo = GetSpellInfo(spellID)
		if spellData.priority and spellData.class then
			Gladius.options.args[self.name].args.auraList.args[spellData.class].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.originalIconID, spellData.order)
		elseif spellData.priority then
			Gladius.options.args[self.name].args.auraList.args["GENERAL"].args.spells.args[tostring(spellID)] = self:SetupAura(spellID, spellData.priority, spellInfo.name, spellInfo.originalIconID, spellData.order)
		end
	end

	local newAura = Gladius.options.args[self.name].args.auraList.args.newAura
		Gladius.options.args[self.name].args.auraList.args = {
			newAura = newAura,
		}

	self:BuildOptions(Gladius.options.args[self.name].args)
end


function ClassIcon:Test(unit)
	local unitClass = Gladius.testing[unit].unitClass
	local unitSpecId = Gladius.testing[unit].unitSpecId
	local keys = {}

	if Gladius.db.classIconImportantAuras then
		for spellID, spellData in pairs(spellTable) do
			if spellData.class == unitClass and not spellData.specID then
				table.insert(keys, spellID)
			elseif spellData.specID then
				for _, specID in ipairs(spellData.specID) do
					if unitSpecId == specID then
						table.insert(keys, spellID)
					end
				end
			end
		end

		-- Pick a random spell
		local randomIndex = math.random(1, #keys)
		local randomSpellID = keys[randomIndex]

		local testDuration = 5
		local testSpell = {
			spellID = randomSpellID,
			duration = testDuration,
			expirationTime = GetTime() + testDuration
		}
		-- Apply test aura
		self:UpdateAura(unit, testSpell)

		-- Remove it after testDuration (seconds)
		C_Timer.After(testDuration, function()
			self:UpdateAura(unit)
		end)

		-- Create a repeating timer that triggers every testDuration + 6 seconds
		self.testTicker = self.testTicker or {}

		-- Cancel existing ticker if it exists
		if self.testTicker[unit] then
			self.testTicker[unit]:Cancel()
			self.testTicker[unit] = nil
		end

		-- Create a new ticker
		self.testTicker[unit] = C_Timer.NewTicker(testDuration + 6, function()
			if not Gladius.test then
				self.testTicker[unit]:Cancel()
				self.testTicker[unit] = nil
				return
			end

			-- Pick a random spell
			randomIndex = math.random(1, #keys)
			randomSpellID = keys[randomIndex]

			testSpell = {
				spellID = randomSpellID,
				duration = testDuration,
				expirationTime = GetTime() + testDuration,
				active = false
			}

			-- Apply test aura
			if testSpell.active == false then
				testSpell.active = true
				self:UpdateAura(unit, testSpell)
			end

			-- Remove it after testDuration (seconds)
			C_Timer.After(testDuration, function()
				if testSpell.active == true then
					testSpell.active = false
					self:UpdateAura(unit)
				end
			end)
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
					hidden = function()
						return not Gladius.db.advancedOptions
					end,
					order = 1,
					args = {
						classIconImportantAuras = {
							type = "toggle",
							name = L["Class Icon Important Auras"],
							desc = L["Show important auras instead of the class icon"],
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
						classIconShowSpec = {
							type = "toggle",
							name = L["Class Icon Spec Icon"],
							desc = L["Shows the specialization icon instead of the class icon"],
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
						classIconCrop = {
							type = "toggle",
							name = L["Class Icon Crop Borders"],
							desc = L["Toggle if the class icon borders should be cropped or not."],
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
						classIconCooldown = {
							type = "toggle",
							name = L["Class Icon Cooldown Spiral"],
							desc = L["Display the cooldown spiral for important auras"],
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
						classIconCooldownReverse = {
							type = "toggle",
							name = L["Class Icon Cooldown Reverse"],
							desc = L["Invert the dark/bright part of the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconCooldown
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
						classIconCooldownEdge = {
							type = "toggle",
							name = L["Class Icon Cooldown Edge"],
							desc = L["Display the edge texture for the cooldown spiral"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconCooldown
							end,
							width = "double",
							order = 30,
						},
						sep6 = {
							type = "description",
							name = "",
							width = "full",
							order = 33,
						},
						classIconCooldownSwipeAlpha = {
							type = "range",
							name = L["Class Icon Cooldown Swipe Alpha"],
							desc = L["Set the darkness of the cooldown swipe animation"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconCooldown
							end,
							min = 0,
							max = 1,
							step = 0.1,
							width = "double",
							order = 35,
						},
						sep7 = {
							type = "description",
							name = "",
							width = "full",
							order = 38,
						},
						classIconFrameLevel = {
							type = "range",
							name = L["Class Icon Frame Level"],
							desc = L["Frame level of the class icon"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							min = 1,
							max = 5,
							step = 1,
							width = "double",
							order = 40,
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
							order = 5,
						},
						sep1 = {
							type = "description",
							name = "",
							width = "full",
							order = 8,
						},
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
							order = 10,
						},
						classIconDetached = {
							type = "toggle",
							name = L["Detached from frame"],
							desc = L["Detach the class icon from the frame itself"],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							hidden = function()
								return Gladius.db.classIconAttachTo ~= "Frame"
							end,
							order = 15,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							order = 18,
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
							order = 20,
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
						order = 25,
						},
						sep3 = {
							type = "description",
							name = "",
							width = "full",
							order = 28,
						},
						classIconOffsetX = {
							type = "range",
							name = L["Class Icon Offset X"],
							desc = L["X offset of the class icon"],
							min = - 100, max = 100, step = 1,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name]
							end,
							order = 30,
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
							order = 35,
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
						class = {
							type = "select",
							name = "Class",
							desc = "Choose the class to which you want to add the custom aura",
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
							desc = L["Spell ID of the aura"],
							get = function()
								if self.newAuraID then
									return tostring(self.newAuraID)
								end
							end,
							set = function(info, value)
								self.newAuraID = tonumber(value)
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconImportantAuras
							end,
							order = 2,
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
							order = 3,
						},
						add = {
							type = "execute",
							name = L["Add new Aura"],
							func = function(info)
								if not self.newAuraID then
									return
								end

								if not self.newAuraPriority then
									self.newAuraPriority = 0
								end

								local spellInfo = GetSpellInfo(self.newAuraID)
								Gladius.options.args[self.name].args.auraList.args[self.newClassFile].args.spells.args[self.newAuraID] = self:SetupAura(self.newAuraID, self.newAuraPriority, spellInfo.name, spellInfo.originalIconID)
								if self.newClassFile == "GENERAL" then
									Gladius.dbi.profile.classIconAuras[tonumber(self.newAuraID)] = {priority = self.newAuraPriority, name = spellInfo.name, iconID = spellInfo.originalIconID, enabled = true, deleted = false}
								else
									Gladius.dbi.profile.classIconAuras[tonumber(self.newAuraID)] = {priority = self.newAuraPriority, class = self.newClassFile, name = spellInfo.name, iconID = spellInfo.originalIconID, enabled = true, deleted = false}
								end
								self.newAuraID = nil
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconImportantAuras or not self.newAuraID or not GetSpellInfo(self.newAuraID) or Gladius.dbi.profile.classIconAuras[self.newAuraID]
							end,
							order = 4,
						},
						newAuraPreview = {
							type = "description",
							name = function()
								local spellData = Gladius.dbi.profile.classIconAuras[self.newAuraID]
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
									local icon = GetSpellInfo(id).originalIconID

									if spellData and spellData.class then
										local classIcon = "|A:classicon-" .. string.lower(spellData.class) .. ":20:20|a "
										local _, _, _, argbHex = GetClassColor(spellData.class)
										return "|T" .. icon .. ":20:20|t " .. spellName .. "\n\n" .. "|cffff0000Error:|r " .. "This Spell is already being tracked for:" .. "\n\n" .. classIcon .. " |c" .. argbHex .. (classes[spellData.class] or "General") .. "|r"
									elseif spellData and spellData.parent then
										local parentID = spellData.parent
										local parentSpellInfo = GetSpellInfo(parentID)
										local parentIcon = parentSpellInfo.originalIconID
										local parentName = parentSpellInfo.name
										local parentSpellData = Gladius.dbi.profile.classIconAuras[parentID]
										local classIcon = "|A:classicon-" .. string.lower(parentSpellData.class) .. ":20:20|a "
										local _, _, _, argbHex = GetClassColor(parentSpellData.class)
										return "|T" .. icon .. ":20:20|t " .. spellName .. "\n\n" .. "|cffff0000Error:|r " .. "This Spell is already being tracked for:" .. "\n\n" .. classIcon .. " |c" .. argbHex .. (classes[parentSpellData.class] or "General") .. "|r" .. " with the parent spell:" .. "\n" .. "|T" .. parentIcon .. ":20:20|t " .. parentName
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


function ClassIcon:SetupClass(classFile, className, order)
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


function ClassIcon:SetupAura(spellID, priority, name, iconID, order)
	return {
		type = "group",
		name = "",
		order = order,
		args = {
			spell = {
				type = "toggle",
				name = "|T" .. iconID .. ":20:20:0:0:64:64:5:59:5:59|t " .. name,
				order = 1,
				desc = function()
					local spellDesc = descriptions.cache[spellID] or ""
					local extra = "\n\n|cffffd700 ".."Spell ID".."|r "..spellID
					return spellDesc..extra
				end,
				get = function ()
					if Gladius.dbi.profile.classIconAuras[spellID] then
						return Gladius.dbi.profile.classIconAuras[spellID].enabled
					end
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
					if Gladius.dbi.profile.classIconAuras[spellID] then
						return Gladius.dbi.profile.classIconAuras[spellID].priority
					end
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
			delete = {
				type = "execute",
				name = L["Delete"],
				func = function(info)
					local spell = tonumber(info[#(info) - 1])
					if spell then
						Gladius.db.classIconAuras[spell] = nil
						Gladius.db.classIconAuras[spell] = {deleted = true}
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
				disabled = function()
					return not Gladius.dbi.profile.modules[self.name] or not Gladius.db.classIconImportantAuras
				end,
				order = 3,
			},
		},
	}
end
