require "Window"
-------------------------------------------------------------
-- Unit class
-------------------------------------------------------------
-- each instance is an ingame unit (player or mob)
-- depends on the Skill class
-------------------------------------------------------------

local Unit = {}

-- external classes
local Skill = Apollo.GetPackage("DarkMeter:Skill").tPackage
local DarkMeter

-- wsUnit is a wildstar Unit, check the api for more infos on the Unit API Type
function Unit:new(wsUnit)
  DarkMeter = Apollo.GetAddon("DarkMeter")

  local unit = {}
  unit.wsUnit = wsUnit -- keep reference to wildstar api Unit
  unit.id = wsUnit:GetId()
  unit.rank = wsUnit:GetRank()
  unit.classId = wsUnit:GetClassId()
  unit.name = wsUnit:GetName()
  unit.inCombat = wsUnit:IsInCombat()
  unit.skills = {}          -- all skill casted by that unit, key is the skill name, and the value is a Skill instance
  unit.skillsTaken = {}     -- all skills casted from enemies to the unit (key is the enemy name)
  unit.deathCount = 0
  unit.totalFightTime = 0
  unit.pets = {}            -- table:  key = pet name, value = Unit instance

  -- if the unit has an owner is a pet
  if wsUnit:GetUnitOwner() then
    unit.owner = wsUnit:GetUnitOwner()
    unit.ownerId = wsUnit:GetUnitOwner():GetId()
    unit.pet = true
  else
    unit.pet = false
  end

  self.__index = self
  return setmetatable(unit, self)
end


-- timer funtions used to calculate stats/second
function Unit:startFight()
  self.startTime = GameLib.GetGameTime()
  self.stopTime = nil
  for name, unit in pairs(self.pets) do
    unit:startFight()
  end
end

function Unit:stopFight()
  self.stopTime = GameLib.GetGameTime()
  self.totalFightTime = self.totalFightTime + (self.stopTime - self.startTime)
  for name, unit in pairs(self.pets) do
    unit:stopFight()
  end
end

function Unit:fightDuration()
  if self.startTime then
    if self.stopTime then
      return math.floor(self.totalFightTime)
    else
      return math.floor(self.totalFightTime + (GameLib.GetGameTime() - self.startTime) )
    end
  else
    return 0
  end
end



-- adds a pet to this unit
function Unit:addPet(wsUnit)
  local name = wsUnit:GetName()
  if self.pets[name] == nil then
    self.pets[name] = Unit:new(wsUnit)
    self.pets[name]:startFight()
    return true
  end
  return false
end


-- adds a skill to the caster unit
function Unit:addSkill(skill)
  -- special condition for falling damage
  if skill.fallingDamage then
    self:addSkillTaken(skill)
  else
    if not self.skills[skill.name] then
      self.skills[skill.name] = Skill:new()
    end
    self.skills[skill.name]:add(skill)
  end
end


-- adds a skill taken from an enemy
function Unit:addSkillTaken(skill)
  local name = skill.caster:GetName()
  if not self.skillsTaken[name] then
    self.skillsTaken[name] = {}
  end
  if not self.skillsTaken[name][skill.name] then
    self.skillsTaken[name][skill.name] = Skill:new()
  end
  self.skillsTaken[name][skill.name]:add(skill)

  if skill.targetkilled then
    self.deathCount = self.deathCount + 1
  end
end


-- -- returns total damage done as a number
-- function Unit:damageDone()
--   local dmg = 0
--   for k, v in pairs(self.skills) do
--     dmg = dmg + v.damageDone
--   end
--   return dmg
-- end

-- -- returns total damage done as a number
-- function Unit:healingDone()
--   local heal = 0
--   for k, v in pairs(self.skills) do
--     heal = heal + v.healingDone
--   end
--   return heal
-- end

-- -- returns total damage done as a number
-- function Unit:overhealDone()
--   local oheal = 0
--   for k, v in pairs(self.skills) do
--     oheal = oheal + v.overhealDone
--   end
--   return oheal
-- end

-- -- returns totalinterrupts as a number
-- function Unit:interrupts()
--   local total = 0
--   for k, v in pairs(self.skills) do
--     total = total + v.interrupts
--   end
--   return total
-- end

-- returns damage taken
function Unit:damageTaken()
  local total = 0
  for enemy, skills in pairs(self.skillsTaken) do
    for skillName, skill in pairs(skills) do
      total = total + skill.damageDone
    end
  end
  return total
end

local stats = {"damageDone", "healingDone", "overhealDone", "interrupts"}

for i = 1, #stats do
  Unit[stats[i]] = function(unit)
    local total = 0
    for k, skill in pairs(unit.skills) do
      total = total + skill[stats[i]]
    end
    if DarkMeter.settings.mergePets then
      for n, pet in pairs(unit.pets) do
        total = total + pet[stats[i]](pet)
      end
    end
    return total
  end
end

function Unit:deaths()
  return self.deathCount
end


function Unit:dps()
  if self:fightDuration() > 0 then
    return math.floor( self:damageDone() / self:fightDuration() )
  else
    return 0
  end
end


Apollo.RegisterPackage(Unit, "DarkMeter:Unit", 1, {"DarkMeter:Skill"})