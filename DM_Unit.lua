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
local DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage

-- wsUnit is a wildstar Unit, check the api for more infos on the Unit API Type
function Unit:new(wsUnit)
  DarkMeter = Apollo.GetAddon("DarkMeter")

  local unit = {}
  unit.wsUnit = wsUnit -- keep reference to wildstar api Unit
  unit.id = wsUnit:GetId()
  unit.level = wsUnit:GetLevel()
  unit.rank = wsUnit:GetRank()
  unit.classId = wsUnit:GetClassId()
  unit.name = wsUnit:GetName()
  unit.inCombat = wsUnit:IsInCombat()
  unit.skills = {}          -- all skill casted by that unit, key is the skill name, and the value is a Skill instance
  unit.damagingSkillsTaken = {}     -- all skills casted from enemies to the unit (storead as: {enemyName = {skillname = Skill, skillname2 = skill2}})
  unit.deathCount = 0
  unit.deathsRecap = {}                  -- array of tables, each table is like {timestamp = {GameLib.GetLocalTime()}, skills = array with the lasdt 10 skills taken}
  unit.totalFightTime = 0
  unit.pets = {}            -- table:  key = pet name, value = Unit instance
  unit.lastTenDamagingSkillsTaken = {} -- array of skills stored as formattedSkill NOT as a skill instance! used for death recap

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
  -- special condition, ignore falling damage, as it gets added also as skilltaken
  if not skill.fallingDamage then
    if not self.skills[skill.name] then
      self.skills[skill.name] = Skill:new()
    end
    self.skills[skill.name]:add(skill)
  end
end


-- adds a skill taken from an enemy
function Unit:addSkillTaken(skill)
  -- process damage taken
  if skill.typology == "damage" then
    local name = skill.fallingDamage and "Gravity" or skill.casterName
    
    if not self.damagingSkillsTaken[name] then
      self.damagingSkillsTaken[name] = {}
    end
    if not self.damagingSkillsTaken[name][skill.name] then
      self.damagingSkillsTaken[name][skill.name] = Skill:new()
    end
    self.damagingSkillsTaken[name][skill.name]:add(skill)
    
    -- add to the last 10 damage taken
    table.insert(self.lastTenDamagingSkillsTaken, 1, skill)
    self.lastTenDamagingSkillsTaken[11] = nil
    
    -- if this unit is killed while taking this damage
    if skill.targetkilled == true then
      -- increment death counter
      self.deathCount = self.deathCount + 1
      -- create death recap with timestamp and last 10 damaging skills taken
      local deathRecap = {
        timestamp = GameLib.GetLocalTime(),
        killerName = skill.casterName
      }
      deathRecap.skills = DMUtils.cloneTable(self.lastTenDamagingSkillsTaken)
      table.insert(self.deathsRecap, 1, deathRecap)
      self.lastTenDamagingSkillsTaken = {}
    end

  elseif skill.typology == "healing" then
    -- TODO process healing taken
    -- this might be a future trackable stat, I don't think is very useful for now
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
  for enemy, skills in pairs(self.damagingSkillsTaken) do
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


-- returns all the skills taken as an array of skills
function Unit:damageTakenSkills()
  local tmp = {}
  local function sortFunct(a, b)
    return a.damageDone > b.damageDone
  end

   for enemy, skills in pairs(self.damagingSkillsTaken) do
    for skillName, skill in pairs(skills) do
      if skill.damageDone > 0 then
        table.insert(tmp, skill)
      end  
    end
  end
  
  if #tmp > 1 then
    table.sort(tmp, sortFunct)
  end
  return tmp
end

-- returns a table {{name = strEnemyName, damage = nDamageDone}, ...}
function Unit:damageTakenOrderedByEnemies()
  local tmp = {}
  local function sortFunct(a, b)
    return a.damage > b.damage
  end

  for enemy, skills in pairs(self.damagingSkillsTaken) do
    local skilltotal = 0
    for skillName, skill in pairs(skills) do
      skilltotal = skilltotal + skill.damageDone
    end
    table.insert(tmp, {name = enemy, damage = skilltotal})
  end
  

  if #tmp > 1 then
    table.sort(tmp, sortFunct)
  end
  return tmp
end


-- returns integer percentage of crit, multihit, deflects...
function Unit:statsPercentages(sStat)
  local total = 0 -- total will hold the total number of skills thrown, crical and not + multihits + multicrits + deflects
  local multi = 0
  local multicrit = 0
  local crit = 0
  local deflects = 0

  local key
  if sStat == "damageDone" then
    key = "damage"
  elseif sStat == "healingDone" or sStat == "overhealDone" or sStat == "rawhealDone" then
    key = "heals"
  elseif sStat == "damageTaken" then
    key = "damagingSkillsTaken"
  end

  if key then
    if key == "damagingSkillsTaken" then
      for enemy, skills in pairs(self.damagingSkillsTaken) do
        for skName, skill in pairs(skills) do
          total = total + skill.damage.total
          multi = multi + #skill.damage.multihits
          multicrit = multicrit + #skill.damage.multicrits
          crit = crit + #skill.damage.crits

          if key == "damage" then
            deflects = deflects + skill.damage.deflects
          end
        end
      end
    else
      for skName, skill in pairs(self.skills) do
        total = total + skill[key].total
        multi = multi + #skill[key].multihits
        multicrit = multicrit + #skill[key].multicrits
        crit = crit + #skill[key].crits

        if key == "damage" then
          deflects = deflects + skill.damage.deflects
        end
      end
    end

    

    local percentages = {}
    if multi > 0 then
      percentages.multihits = multi / total *100
    else
      percentages.multihits = 0
    end
    if multicrit > 0 then
      percentages.multicrits = multicrit / multi * 100
    else
      percentages.multicrits = 0
    end
    if crit > 0 then
      percentages.crits = crit / total * 100
    else
      percentages.crits = 0
    end
    if key == "damage" then
      percentages.deflects = deflects / (total + multicrit + multi) * 100
    end
    percentages.attacks = total
    return percentages
  end
end


Apollo.RegisterPackage(Unit, "DarkMeter:Unit", 1, {"DarkMeter:Skill"})