-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@ Timer Module @@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Originally written by: Resike and Firebunny. Original author: Proditor
-- Modified by: Pharmac1st
-- Game Version: 11.1.5
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

local Gladius = _G.Gladius
if not Gladius then
	DEFAULT_CHAT_FRAME:AddMessage(format("Module %s requires Gladius", "Timer"))
end
local L = Gladius.L
local LSM

-- Global functions
local _G = _G
local floor = math.floor
local ceil = math.ceil
local pairs = pairs
local strformat = string.format
local type = type
local tostring = tostring

local CreateFrame = CreateFrame
local GetTime = GetTime
local IsInInstance = IsInInstance

local COOLDOWN_TYPE_NORMAL = COOLDOWN_TYPE_NORMAL

local Timer = Gladius:NewModule("Timer", false, false, {
	timerSoonFontSize = 20,
	timerSoonFontColor = {r = 1, g = 0, b = 0, a = 1},
	timerSecondsFontSize = 16,
	timerSecondsFontColor = {r = 1, g = 0.5, b = 0, a = 1},
	timerMinutesFontSize = 16,
	timerMinutesFontColor = {r = 1, g = 1, b = 0, a = 1},
	timerShortFontSize = 18,
	timerShortFontColor = {r = 0, g = 1, b = 0, a = 1},
	timerOmniCC = false,
	timerShort = true,
	shortFormatThreshold = 2,
})


function Timer:OnEnable()
	LSM = Gladius.LSM
	-- cooldown frames
	self.frames = self.frames or {}
end


function Timer:OnDisable()
	self:UnregisterAllEvents()
	self:Reset()
end


function Timer:Reset()
	-- It used to be left to each individual module to call
	-- HideTimer, however I feel that makes little sense and
	-- is very error prone.
	for frameName in pairs(self.frames) do
		self:HideTimer(_G[frameName])
	end
end


function Timer:GetAttachTo()
	return ""
end


function Timer:GetFrame(unit)
	return ""
end


function Timer:SetFormattedNumber(frame, number)
	local minutes = floor(number / 60)
	if minutes >= Gladius.db.shortFormatThreshold and Gladius.db.timerShort then
		local ceilMinutes = ceil(number / 60)
		frame:SetFont(LSM:Fetch(LSM.MediaType.FONT, Gladius.db.globalFont), Gladius.db.timerShortFontSize, "OUTLINE")
		frame:SetTextColor(Gladius.db.timerShortFontColor.r, Gladius.db.timerShortFontColor.g, Gladius.db.timerShortFontColor.b, Gladius.db.timerShortFontColor.a)
		frame:SetText(string.format("%dm", ceilMinutes))
	elseif minutes >= 1 then
		local seconds = number - minutes * 60
		frame:SetFont(LSM:Fetch(LSM.MediaType.FONT, Gladius.db.globalFont), Gladius.db.timerMinutesFontSize, "OUTLINE")
		frame:SetTextColor(Gladius.db.timerMinutesFontColor.r, Gladius.db.timerMinutesFontColor.g, Gladius.db.timerMinutesFontColor.b, Gladius.db.timerMinutesFontColor.a)
		frame:SetText(string.format("%d:%02d", minutes, seconds))
	else
		if number > 5 then
			frame:SetFont(LSM:Fetch(LSM.MediaType.FONT, Gladius.db.globalFont), Gladius.db.timerSecondsFontSize, "OUTLINE")
			frame:SetTextColor(Gladius.db.timerSecondsFontColor.r, Gladius.db.timerSecondsFontColor.g, Gladius.db.timerSecondsFontColor.b, Gladius.db.timerSecondsFontColor.a)
			frame:SetText(strformat("%.0f", number))
		else
			frame:SetFont(LSM:Fetch(LSM.MediaType.FONT, Gladius.db.globalFont), Gladius.db.timerSoonFontSize, "OUTLINE")
			frame:SetTextColor(Gladius.db.timerSoonFontColor.r, Gladius.db.timerSoonFontColor.g, Gladius.db.timerSoonFontColor.b, Gladius.db.timerSoonFontColor.a)
			if number == 0 then
				frame:SetText("")
			else
				frame:SetText(strformat("%.1f", number))
			end
		end
	end
end


function Timer:SetTimer(frame, duration, start, callback)
	if not self.frames or frame == nil then
		return
	end
	local start = start or GetTime()
	local frameName = frame:GetName()
	if not self.frames[frameName] then
		self:RegisterTimer(frame)
	end
	self:SetFormattedNumber(self.frames[frameName].text, duration)
	self.frames[frameName].duration = duration - (GetTime() - start)
	self.frames[frameName].text:SetAlpha(1)

	local cooldown = _G[frameName.."Cooldown"]
	cooldown:SetAlpha(self.frames[frameName].showSpiral and 1 or 0)

	if not cooldown.isDisabled then
		cooldown:SetCooldown(start, duration)
	end

	if duration > 0 and not Gladius.db.timerOmniCC and not self.frames[frameName].hideTimer then
		self.frames[frameName]:SetScript("OnUpdate", function(f, elapsed)
			f.duration = f.duration - elapsed
			if f.duration <= 0 then
				f.text:SetAlpha(0)
				f:SetScript("OnUpdate", nil)

				-- Call the callback if one was supplied.
				if type(callback) == 'function' then
					callback()
				end
			else
				self:SetFormattedNumber(f.text, f.duration)
			end
		end)
	end
end


function Timer:HideTimer(frame)
	if not self.frames then
		return
	end
	local frameName = frame:GetName()
	--_G[frameName.."Cooldown"]:SetCooldown(0, 0)
	_G[frameName.."Cooldown"]:Clear()

	if _G[frameName.."Cooldown"]:IsShown() then
		_G[frameName.."Cooldown"]:SetAlpha(0)
	end
	if self.frames[frameName] then
		self.frames[frameName]:SetScript("OnUpdate", nil)
		self.frames[frameName].text:SetAlpha(0)
	end
end


function Timer:RegisterTimer(frame, showSpiral, hideTimer)
	if not self.frames then
		return
	end

	local frameName = frame:GetName()
	local cooldown = _G[frameName.."Cooldown"]

	if not self.frames[frameName] then
		self.frames[frameName] = CreateFrame("Frame", "Gladius"..self.name..frameName, frame)
		self.frames[frameName].name = frameName
		self.frames[frameName].text = self.frames[frameName]:CreateFontString("Gladius"..self.name..frameName.."Text", "OVERLAY")
	end

	self.frames[frameName].showSpiral = showSpiral or false
	self.frames[frameName].hideTimer = hideTimer or false

	 -- Hide Blizzard countdown numbers
    if cooldown and cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(true)
    end

	-- Show module countdown numbers if Gladius.db.timerOmniCC is false and hideTimer is false
    if not Gladius.db.timerOmniCC and not hideTimer then
        self.frames[frameName].text:Show()
    else
        self.frames[frameName].text:Hide()
    end

	-- update frame
	self.frames[frameName]:SetAllPoints(frame)
	self.frames[frameName]:SetFrameStrata("HIGH")
	self.frames[frameName]:SetFrameLevel(100)
	self.frames[frameName].text:ClearAllPoints()
	self.frames[frameName].text:SetPoint("CENTER", self.frames[frameName])
	self.frames[frameName].text:SetShadowOffset(1, -1)
	self.frames[frameName].text:SetShadowColor(0, 0, 0, 1)
	-- hide
	self.frames[frameName].text:SetAlpha(0)
end


function Timer:GetOptions()
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
						timerOmniCC = {
							type = "toggle",
							name = L["Timer Use OmniCC"],
							desc = L["The timer module will use OmniCC for text display."],
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
						timerShort = {
							type = "toggle",
							name = L["Timer Use Short Format"],
							desc = L["The timer module will use the short 'Xm' format for text display if timeleft is greater than 'X' minutes."],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC
							end,
							order = 10,
						},
						shortFormatThreshold = {
							type = "input",
							name = L["Threshold In Minutes"],
							desc = L["Set the short format threshold in 'X' minutes."],
							get = function ()
								return tostring(Gladius.db.shortFormatThreshold)
							end,
							set = function (_, value)
								local number = tonumber(value)
								if number then
									Gladius.db.shortFormatThreshold = number
								end
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC or not Gladius.db.timerShort
							end,
							order = 15,
						},
						sep2 = {
							type = "description",
							name = "",
							width = "full",
							order = 18,
						},
						timerSoonFontColor = {
							type = "color",
							name = L["Timer Soon Color"],
							desc = L["Color of the timer when timeleft is less than 5 seconds."],
							get = function(info)
								return Gladius:GetColorOption(info)
							end,
							set = function(info, r, g, b)
								return Gladius:SetColorOption(info, r, g, b, 1)
							end,
							hasAlpha = false,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC
							end,
							order = 20,
						},
						timerSoonFontSize = {
							type = "range",
							name = L["Timer Soon Size"],
							desc = L["Text size of the timer when timeleft is less than 5 seconds."],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC
							end,
							min = 1,
							max = 30,
							step = 1,
							order = 25,
						},
						sep3 = {
							type = "description",
							name = "",
							width = "full",
							order = 28,
						},
						timerSecondsFontColor = {
							type = "color",
							name = L["Timer Seconds Color"],
							desc = L["Color of the timer when timeleft is less than 60 seconds."],
							get = function(info)
								return Gladius:GetColorOption(info)
							end,
							set = function(info, r, g, b)
								return Gladius:SetColorOption(info, r, g, b, 1)
							end,
							hasAlpha = false,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC
							end,
							order = 30,
						},
						timerSecondsFontSize = {
							type = "range",
							name = L["Timer Seconds Size"],
							desc = L["Text size of the timer when timeleft is less than 60 seconds."],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC
							end,
							min = 1,
							max = 30,
							step = 1,
							order = 35,
						},
						sep4 = {
							type = "description",
							name = "",
							width = "full",
							order = 38,
						},
						timerMinutesFontColor = {
							type = "color",
							name = L["Timer Minutes Color"],
							desc = L["Color of the timer when timeleft is greater than 60 seconds."],
							get = function(info)
								return Gladius:GetColorOption(info)
							end,
							set = function(info, r, g, b)
								return Gladius:SetColorOption(info, r, g, b, 1)
							end,
							hasAlpha = false,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC
							end,
							order = 40,
						},
						timerMinutesFontSize = {
							type = "range",
							name = L["Timer Minutes Size"],
							desc = L["Text size of the timer when timeleft is greater than 60 seconds."],
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC
							end,
							min = 1,
							max = 30,
							step = 1,
							order = 45,
						},
							sep5 = {
							type = "description",
							name = "",
							width = "full",
							order = 48,
						},
						timerShortFontColor = {
							type = "color",
							name = L["Timer Short Color"],
							desc = L["Color of the timer when timeleft is greater than the short format threshold."],
							get = function(info)
								return Gladius:GetColorOption(info)
							end,
							set = function(info, r, g, b)
								return Gladius:SetColorOption(info, r, g, b, 1)
							end,
							hasAlpha = false,
							hidden = function ()
								return not Gladius.db.timerShort
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC
							end,
							order = 50,
						},
						timerShortFontSize = {
							type = "range",
							name = L["Timer Short Size"],
							desc = L["Text size of the timer when timeleft is greater than the short format threshold."],
							hidden = function ()
								return not Gladius.db.timerShort
							end,
							disabled = function()
								return not Gladius.dbi.profile.modules[self.name] or Gladius.db.timerOmniCC
							end,
							min = 1,
							max = 30,
							step = 1,
							order = 55,
						},
					},
				},
			},
		},
	}
end
