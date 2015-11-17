
---------------------------------------------------
-- Utilities module, used across all DarkMeter
---------------------------------------------------

require "Window"

local DMUtils = {}
DMUtils.__index = DMUtils



---------------------------
-- classes variable setup
---------------------------

-- will hold a table with each gameClass, its name and color, key is the class code
DMUtils.classes = {}

DMUtils.classes[1] = { name = "Warrior", 				color = { 0.8, 0.1, 0.1 } }
DMUtils.classes[2] = {	name = "Engineer", 			color = { 0.65, 0.65, 0 } }
DMUtils.classes[3] = {	name = "Esper",					color = { 0.1, 0.5, 0.7 }	} 
DMUtils.classes[4] = {	name = "Medic",					color = { 0.2, 0.6, 0.1 }	} 
DMUtils.classes[5] = {	name = "Stalker",				color = { 0.5, 0.1, 0.8 }	} 
DMUtils.classes[7] = {	name = "Spellslinger", 	color = { 0.9, 0.4, 0.0 } }


function DMUtils:iconForClass(unit)
	if self.classes[unit.classId] ~= nil then
    local iconSprite = self.classes[unit.classId].name
    return "BK3:UI_Icon_CharacterCreate_Class_" .. iconSprite
  -- pets icons
  elseif unit.pet then -- artillery bot
    if unit.name == "Artyllery Bot" then
    	return "IconSprites:Icon_SkillEngineer_Artillery_Bot"
    elseif unit.name == "Geist" then -- esper geist
    	return "IconSprites:Icon_SkillEsper_Geist"
    elseif unit.name == "Phantom" then -- esper phantom (wtf, no icon available for this skill on houston...)
    	return "IconSprites:Icon_Pets_Icon_PinkSquirgSquishling" -- return a pink squid pet icon...
    end
  end
  return nil
end


--------------------------
-- damage type
--------------------------
DMUtils.damageType = GameLib.CodeEnumDamageType

function DMUtils:titleForStat(stat, short)
	short = short or false
	if stat == "damageDone" then
		return short and "Dmg" or "Damage done"
	elseif stat == "healingDone" then
		return short and "Heal" or "Healing done"
	elseif stat == "overhealDone" then
		return short and "oHeal" or "Overheal done"
	elseif stat == "interrupts" then
		return short and "cc" or "Interrupts"
	elseif stat == "damageTaken" then
		return short and "DmgTk" or "Damage taken"
	elseif stat == "deaths" then
		return short and "Dth" or "Deaths"
  elseif stat == "dps" then
    return short and "Dps" or "Dps"
	-- TODO other stats
	end
end

function DMUtils.formatNumber(num, places)
  local ret
  local placeValue = ("%%.%df"):format(places or 0)
  if not num then
      return 0
  elseif num >= 1000000000000 then
      ret = placeValue:format(num / 1000000000000) .. " Tril" -- trillion
  elseif num >= 1000000000 then
      ret = placeValue:format(num / 1000000000) .. " Bil" -- billion
  elseif num >= 1000000 then
      ret = placeValue:format(num / 1000000) .. " Mil" -- million
  elseif num >= 1000 then
      ret = placeValue:format(num / 1000) .. "k" -- thousand
  else
      ret = num -- hundreds
  end
  return ret
end


--------------------------
-- Math utils
--------------------------

function DMUtils.roundToNthDecimal(num, n)
  local mult = 10^(n or 0)
  return math.floor(num * mult + 0.5) / mult
end

--------------------------
-- Tables utils
--------------------------

function DMUtils.mergeTables(t1, t2)
	for k, v in pairs(t2) do
		t1[k] = v
	end
	return t1
end

function DMUtils.sumLists(t1, t2)
	if #t2 > 0 then
		for i = 1, #t2 do
			t1[#t1 + 1] = t2[i]
		end
	end
	return t1
end

function DMUtils.tableLength(t)
	local size = 0
	for _ in pairs(t) do
		size = size +1
	end
	return size
end

-- deep-copy a table
function DMUtils.cloneTable(t) 
  if type(t) ~= "table" then return t end
  local meta = getmetatable(t)
  local target = {}
  for k, v in pairs(t) do
      if type(v) == "table" then
          target[k] = DMUtils.cloneTable(v)
      else
          target[k] = v
      end
  end
  setmetatable(target, meta)
  return target
end



Apollo.RegisterPackage(DMUtils, "DarkMeter:Utils", 1, {})