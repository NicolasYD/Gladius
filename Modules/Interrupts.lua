-- @@@@@@@@@@@@@@@@@@@@ Interrupts Module @@@@@@@@@@@@@@@@@@@@
-- Originally written by: Jax
-- Modified by: Pharmac1st
-- Game Version: 11.1.5
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


local Gladius = _G.Gladius
if not Gladius then
	DEFAULT_CHAT_FRAME:AddMessage(format("Module %s requires Gladius", "Interrupts"))
end
local L = Gladius.L
local LSM

local CDList = LibStub("CDList-1.0")
local spellList = CDList.spellList

local interruptsList = {}
local iDurations = {}
for spellId, spellData in pairs(spellList) do
    if spellData and spellData.category == "interrupt" then
        table.insert(interruptsList, spellId)
        iDurations[spellId] = spellData.duration
    end
end

-- Global Functions
local GetSpellInfo = C_Spell.GetSpellInfo

local Interrupts = Gladius:NewModule("Interrupts", false, false, {InterruptsFrameLevel = 5},{
})

-- @@@@@@@@@@@@@@@@@@@@@ Helper Functions @@@@@@@@@@@@@@@@@@@@@
-- Functions copied from WeakAuras AddOn by The WeakAuras Team
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


local WA_GetUnitBuff = function(unit, spell, filter)
  filter = filter and filter.."|HELPFUL" or "HELPFUL"
  return WA_GetUnitAura(unit, spell, filter)
end


local WA_GetUnitDebuff = function(unit, spell, filter)
  filter = filter and filter.."|HARMFUL" or "HARMFUL"
  return WA_GetUnitAura(unit, spell, filter)
end
-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


function Interrupts:OnInitialize()
	self.frame = { }
end


function Interrupts:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end


function Interrupts:OnDisable()
	self:UnregisterAllEvents()
	for unit in pairs(self.frame) do
		self.frame[unit]:SetAlpha(0)
	end
end


function Interrupts:GetAttachTo()
    return
end


function Interrupts:UpdateInterrupts(unit, duration)
    Gladius:Call(Gladius.modules.Timer, "SetTimer", self.frame[unit], duration)
    ClassIcon = Gladius.modules["ClassIcon"]
    ClassIcon:ShowAura(unitt, {icon = select(3, GetSpellInfo(sp)), duration=d});
    table.insert(canOverWrite, {unit=unitt, time=GetTime()+d});
end


function Interrupts:Interrupted()
    return
end


function Interrupts:COMBAT_LOG_EVENT_UNFILTERED(event)
    local _,subEvent,_,sourceGUID,sourceName,_,_,destGUID,destName,destFlags,destRaidFlags,spellID,spellName,_,auraType,extraSpellName,_,auraType2 = CombatLogGetCurrentEventInfo()
    local _, instanceType = IsInInstance()
    ---Lockout icons over the gladius frame--
    --Channel--
    if subEvent == "SPELL_CAST_SUCCESS" then
        goFar = false
        for index, value in ipairs (interruptsList) do
            if value == spellID then
                goFar = true
            end
        end
        if goFar then
            for i=1,GetNumArenaOpponents() do
                if destGUID == UnitGUID("arena"..i) and select(7,UnitChannelInfo("arena"..i))==false then
                    unit="arena"..i
                    local d = iDurations[spellID]
                    self:UpdateInterrupts("arena"..i, spellID, d)
                end

            end
        end
    end



    --Casted--
    if subEvent == "SPELL_INTERRUPT" then
        goFar = false
        for index, value in ipairs (interruptsList) do
            if value == spellID then
                goFar = true
            end
        end

        if goFar then
            for i=1,GetNumArenaOpponents() do
                if destGUID == UnitGUID("arena"..i) then
                    unit="arena"..i
                    local d = iDurations[spellID]
                    self:UpdateInterrupts("arena"..i, spellID, d)
                end

            end
        end
    end
end


function Interrupts:CreateFrame(unit)
    return
end


CreateFrame("Frame"):SetScript("OnUpdate",
function()
        for i=#canOverWrite,1,-1 do
                    if GetTime() - canOverWrite[i].time > 0 then
                            local u = canOverWrite[i].unit
                            table.remove(canOverWrite,i);
                            ClassIcon:UpdateAura(u);
                    end
        end
end)


function Interrupts:Update(unit)
    return
end


function Interrupts:Show(unit)
    self.frame[unit]:SetAlpha(1)
end


function Interrupts:Reset(unit)
    return
end


function Interrupts:Test(unit)
	self:UpdateInterrupts("arena1", interruptsList[1], iDurations[interruptsList[1]])
	self:UpdateInterrupts("arena2", interruptsList[6], iDurations[interruptsList[6]])
	self:UpdateInterrupts("arena3", interruptsList[12], iDurations[interruptsList[12]])
end


function Interrupts:GetOptions()
	return {
		general = {
			type = "group",
			name = L["General"],
			order = 1,
			args = {
                sep2 = {
                    type = "description",
                    name = "This module shows interrupt durations over the Arena Enemy Class Icons when they are interrupted.",
                    width = "full",
                    order = 17,
                },
								InterruptFrameLevel = {
									type = "range",
									name = L["Interrupt Frame Level"],
									desc = L["Frame level of the Interrupt"],
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
									order = 46,
								},
							},
        },
    }
end
