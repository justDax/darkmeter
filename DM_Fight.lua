
-------------------------------------------------------------
-- Fight class
-------------------------------------------------------------
-- each instance is an ingame fight (in and out of combat)
-- contains references to players, their skills and dmg...
-------------------------------------------------------------

require "Window"

local Fight = {}

-- external classes
local Unit = Apollo.GetPackage("DarkMeter:Unit").tPackage
local Skill = Apollo.GetPackage("DarkMeter:Skill").tPackage
local DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage
local DarkMeter

function Fight:new()
  DarkMeter = Apollo.GetAddon("DarkMeter")

	local fight = {}
  fight.groupMembers = {}
  fight.enemies = {}
  fight.startTime = GameLib.GetGameTime()
  fight.forcedName = nil            -- this is used to force a fight name like "Current fight" or "Overall data"
  fight.totalDuration = 0

	self.__index = self
	return setmetatable(fight, self)
end


-- adds an unit to the current fight
-- groupMember is a boolean, if true the unit is added to the friendly units, if false is added to the enemies
-- return true if unit is added
-- return false if unit exists
function Fight:addUnit(wsUnit, groupMember)
  local unitId = wsUnit:GetId()
  local unitName = wsUnit:GetName()
  local unitTable = groupMember and "groupMembers" or "enemies"

  if self[unitTable][unitId] ~= nil then
    return false
  else
    -- if the unit is not a pet and a unit with this name exists among the actual group members, it might be a player that crashed with the same name, but after relog now has a different id
    -- tldr... merge groupMembers that are not pets with the same name
    if groupMember and not wsUnit:GetUnitOwner() then
      for id, unit in pairs(self.groupMembers) do
        if unit.name == unitName then
          local newUnit = Unit:new(wsUnit)
          newUnit.skills = DMUtils.cloneTable(unit.skills)
          self.groupMembers[id] = nil
          self.groupMembers[newUnit.id] = newUnit
        end
      end
    end

    self[unitTable][unitId] = Unit:new(wsUnit)
    if self[unitTable][unitId].pet then
      self:addUnit(self[unitTable][unitId].owner, groupMember)
    end
    if groupMember then
      self[unitTable][unitId]:startFight() -- used to calculate dps
    end
    return true
  end
end

-- duration of the fight
function Fight:duration()
  if not self.endTime then
    return math.floor(GameLib.GetGameTime() - self.startTime + self.totalDuration)
  else
    return math.floor(self.totalDuration)
  end
end

-- stops fight (combat end)
function Fight:stop()
  self.endTime = GameLib.GetGameTime()
  self.totalDuration = self.totalDuration + (self.endTime - self.startTime)

  for id, unit in pairs(self.groupMembers) do
    unit:stopFight()
  end
end


-- continue a fight, used to keep adding time to the overall fight between combats
function Fight:continue()
  self.startTime = GameLib.GetGameTime()
  self.endTime = nil
  for id, unit in pairs(self.groupMembers) do
    unit:startFight()
  end
end

function Fight:paused()
  return self.startTime and self.endTime
end



-- -- return damagedone by all members in this specific fight
-- function Fight:damageDone()
--   local totalDmg = 0
--   for id, unit in pairs(self.groupMembers) do
--     totalDmg = totalDmg + unit:damageDone()
--   end
--   return totalDmg
-- end

-- -- return healing done by all members in this specific fight
-- function Fight:healingDone()
--   local total = 0
--   for id, unit in pairs(self.groupMembers) do
--     total = total + unit:healingDone()
--   end
--   return total
-- end

-- -- return overhealing done by all members in this specific fight
-- function Fight:overhealDone()
--   local total = 0
--   for id, unit in pairs(self.groupMembers) do
--     total = total + unit:overhealDone()
--   end
--   return total
-- end

-- -- return interrupts done by all
-- function Fight:interrupts()
--   local total = 0
--   for id, unit in pairs(self.groupMembers) do
--     total = total + unit:interrupts()
--   end
--   return total
-- end

-- -- returns total damage taken
-- function Fight:damageTaken()
--   local total = 0
--   for id, unit in pairs(self.groupMembers) do
--     total = total + unit:damageTaken()
--   end
--   return total
-- end

-- -- returns total deaths
-- function Fight:deaths()
--   local total = 0
--   for id, unit in pairs(self.groupMembers) do
--     total = total + unit:deaths()
--   end
--   return total
-- end

local stats = {"damageDone", "healingDone", "overhealDone", "interrupts", "damageTaken", "deaths"}

for i = 1, #stats do
  Fight[stats[i]] = function(fight)
    local total = 0
    for id, unit in pairs(fight.groupMembers) do
      total = total + unit[stats[i]](unit)
      if DarkMeter.settings.mergePets == false then
        for name, pet in pairs(unit.pets) do
          total = total + pet[stats[i]](pet)
        end
      end
    end
    return total
  end
end

function Fight:dps()
  local total = 0
  for id, unit in pairs(self.groupMembers) do
    total = total + unit:damageDone()
  end
  return total / self:duration()
end




-- return an ordered list of all party members ordered by the diven stats
function Fight:orderMembersBy(stat)
  if Unit[stat] == nil then
    error("Cannot order fight members by " .. stat .. " Unit class doesn't have such method")
  end

  local function sortFunct(a, b)
    return a[stat](a) > b[stat](b)
  end

  local tmp = {}
  for id, unit in pairs(self.groupMembers) do
    table.insert(tmp, unit)
    if not DarkMeter.settings.mergePets then
      for name, pet in pairs(unit.pets) do
        table.insert(tmp, pet)
      end
    end
  end
  if #tmp > 1 then
    table.sort(tmp, sortFunct)
  end
  return tmp
end





-- returns the name of the most significative enemies
function Fight:name()
  if self.forcedName then
    return self.forcedName
  end
  local topUnit = nil
  for _, unit in pairs(self.enemies) do
    topUnit = topUnit or unit
    if unit.rank > topUnit.rank then
      topUnit = unit
    end
  end
  return topUnit and topUnit.name or "No enemies"
end

Apollo.RegisterPackage(Fight, "DarkMeter:Fight", 1, {"DarkMeter:Skill", "DarkMeter:Unit"})