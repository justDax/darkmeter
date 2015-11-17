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


------------------------------------------
--   skills processing functons
------------------------------------------
-- those functions sum all the player's skills and return a number
-- representing the amount of this unit's stat (like damageDone for example)


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

-- define functions to return the stats in this array, since they share the same logic
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


------------------------------------------
--   skills order function
------------------------------------------
-- those functions will sort all unit's skills based on their contribution to a particolar stat score and return them as an array
-- all the skills that give 0 contribution to that stat are excluded from the resulting array


for i = 1, #stats do
  Unit[stats[i] .. "Skills"] = function(unit)
    local tmp = {}

    local function sortFunct(a, b)
      return a[stats[i]] > b[stats[i]]
    end

    for k, skill in pairs(unit.skills) do
      local amount = skill[stats[i]]
      if amount > 0 then
        table.insert(tmp, skill)
      end
    end

    -- add pet's skills if pets are merged with the owner
    if DarkMeter.settings.mergePets then
      for n, pet in pairs(unit.pets) do
        for k, skill in pairs(pet.skills) do
          local amount = skill[stats[i]]
          if amount > 0 then
            table.insert(tmp, skill)
          end
        end
      end
    end

    if #tmp > 1 then
      table.sort(tmp, sortFunct)
    end
    return tmp
  end
end


Apollo.RegisterPackage(Unit, "DarkMeter:Unit", 1, {"DarkMeter:Skill"})