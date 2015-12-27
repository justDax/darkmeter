
local Skill = {}
local DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage
local DarkMeter

-- skill result codes
local deflectCode = GameLib.CodeEnumCombatResult.Avoid
local critCode = GameLib.CodeEnumCombatResult.Critical
local hitCode = GameLib.CodeEnumCombatResult.Hit


function Skill:new()
  if DarkMeter == nil then
    DarkMeter = Apollo.GetAddon("DarkMeter")    
  end
  local initialValues = {
    name = "",
    fightId = nil,              -- key to retrieve the fight that this skill belongs to in the table DarkMeter.fights
    unitId = nil,               -- key to retrieve the unit that this skill belongs to in the table DarkMeter.units
    skillTaken = false,         -- false if this is a skill casted by the unit
    damage = {
      deflects = 0,
      total = 0,
      hits = {},
      crits = {},
      multihits = {},                 -- multihits can contain false values, these are added on multihit deflects
      multicrits = {}
    },
    heals = {
      total = 0,
      hits = {},                      -- stored as: {heal = n, oHeal = n}
      crits = {},
      multihits = {},
      multicrits = {}
    },
    -- quick reference values
    damageDone = 0,
    healingDone = 0,
    overhealDone = 0,
    interrupts = 0
  }
  self.__index = self
  return setmetatable(initialValues, self)
end

-- returns the fight that this skill blongs to
function Skill:fight()
  local fight = DarkMeter.fights[self.fightId]
  if fight == nil then
    Apollo.AddAddonErrorText(DarkMeter, "Cannot find global fight with id: " .. tostring(self.fightId) .. " - DarkMeter: " .. tostring(DarkMeter))
  end
  return fight
end

-- returns the unit that this skill blongs to
function Skill:unit()
  local unit = DarkMeter.units[self.unitId]
  if unit == nil then
    Apollo.AddAddonErrorText(DarkMeter, "Cannot find global unit with id: " .. tostring(self.unitId) .. " - DarkMeter: " .. tostring(DarkMeter))
  end
  return unit
end




-- adds new input to the current skill
function Skill:add(formattedSkill)
  -- set skill name
  if self.name == "" and formattedSkill.name then
    self.name = formattedSkill.name
    -- I need to identify somehow if the skill belongs to a normal unit or a pet
    -- I do this by setting the ownerName, if is not nil, this skill has been casted by a pet
    self.casterName = formattedSkill.casterName
    self.ownerName = formattedSkill.ownerName
  end

    -- set if skill is a dot
  if self.dot == nil then
    self.dot = formattedSkill.dot
    -- if the skill is a dot, also set the normal skill name
    if self.dot then
      self.originalName = string.gsub(self.name, " %(dot%)", "")
    end
  end

  -- add skill icon
  if (self.icon == nil or self.icon == "") then
    local icon = DMUtils:GetSpellIconByName(self.originalName or self.name)

    -- TODO commented this because I'm trying to remove the original spell table from the formattedskill
    -- if (icon == nil or icon == "") and formattedSkill.spell then
    --   icon = formattedSkill.spell:GetIcon()
    -- end
    
    self.icon = icon or false -- if icon is nil, a false value as fallback will prevent from searching the icon again on the next add
  end

  -- damage skill
  if formattedSkill.typology == "damage"and not formattedSkill.fallingDamage then
    self:ProcessDamage(formattedSkill)
  -- healing skill
  elseif formattedSkill.typology == "healing" then
    self:ProcessHeal(formattedSkill)
  -- cc effect
  elseif formattedSkill.interrupts ~= nil and formattedSkill.interrupts > 0 then
    self:ProcessCC(formattedSkill)
  -- falling damage
  elseif formattedSkill.fallingDamage then
    self:ProcessFallingDamage(formattedSkill)
  end
end

-- ATTENTION this function is critical, any changed to the skill class may break the merge funct
-- merge two skills data together (used to merge a skill with its separate dot skill's data)
function Skill:merge(skill)
  for _, typology in pairs({"damage", "heals"}) do
    for stat, val in pairs(self[typology]) do
      if type(val) == "number" then
        self[typology][stat] = self[typology][stat] + skill[typology][stat]
      elseif type(val) == "table" then
        self[typology][stat] = DMUtils.sumLists(val, skill[typology][stat])
      end
    end
  end

    -- quick reference values
  self.damageDone = self.damageDone + skill.damageDone
  self.healingDone = self.healingDone + skill.healingDone
  self.overhealDone = self.overhealDone + skill.overhealDone
  self.interrupts = self.interrupts + skill.interrupts
end


-- process a damaging skill
function Skill:ProcessDamage(skill)
  if not skill.multihit then
    self.damage.total = self.damage.total + 1
  end

  -- deflect
  if skill.state == deflectCode then
    self.damage.deflects = self.damage.deflects + 1
    -- if the deflected hit is a multihit, I have to keep track of the multihits counts, but I must also eliminate the deflects from the average, max and min damage calculations
    -- I'll add the special value false to the array of multihits damages, this value will be ignored when calcumating a skill's max, min and avg damage
    if skill.multihit then
      self.damage.multihits[#self.damage.multihits + 1] = false
    end
  -- crit
  elseif skill.state == critCode then
    if skill.multihit then
      self.damage.multicrits[#self.damage.multicrits + 1] = skill.damage
    else
      self.damage.crits[#self.damage.crits + 1] = skill.damage
    end
    -- add the damage to itself
    self.damageDone = self.damageDone + skill.damage
    -- add the damage to the skill's fight
    local fight = self:fight()
    local unit = self:unit()
    if fight and unit and not unit.enemy then
      if self.skillTaken then
        fight.damageTakenTotal = fight.damageTakenTotal + skill.damage
      else
        fight.damageDoneTotal = fight.damageDoneTotal + skill.damage
      end
    end
  -- normal hit
  elseif skill.state == hitCode then
    if skill.multihit then
      self.damage.multihits[#self.damage.multihits + 1] = skill.damage
    else
      self.damage.hits[#self.damage.hits + 1] = skill.damage
    end
    -- add the damage to itself
    self.damageDone = self.damageDone + skill.damage
    -- add the damage to the skill's fight
    local fight = self:fight()
    local unit = self:unit()
    if fight and unit and not unit.enemy then
      if self.skillTaken then
        fight.damageTakenTotal = fight.damageTakenTotal + skill.damage
      else
        fight.damageDoneTotal = fight.damageDoneTotal + skill.damage
      end
    end
  end
end


-- process an healing skill
function Skill:ProcessHeal(skill)
  if not skill.multihit then
    self.heals.total = self.heals.total + 1
  end
  
  local tmpSkill = {}
  tmpSkill.heal = skill.heal
  tmpSkill.oHeal = skill.overheal

  -- crit
  if skill.state == critCode then
    if skill.multihit then
      self.heals.multicrits[#self.heals.multicrits + 1] = tmpSkill
    else
      self.heals.crits[#self.heals.crits + 1] = tmpSkill
    end
  -- normal hit
  elseif skill.state == hitCode then
    if skill.multihit then
      self.heals.multihits[#self.heals.multihits + 1] = tmpSkill
    else
      self.heals.hits[#self.heals.hits + 1] = tmpSkill
    end
  end

  self.healingDone = self.healingDone + skill.heal
  self.overhealDone = self.overhealDone + skill.overheal
  -- adds healings to the skill's fight
  local fight = self:fight()
  local unit = self:unit()
  if fight and unit and not unit.enemy and not self.skillTaken then
    -- don't process healing taken as they should be added to the global count by the caster
    fight.healingDoneTotal = fight.healingDoneTotal + skill.heal
    fight.overhealDoneTotal = fight.overhealDoneTotal + skill.overheal
  end
end


function Skill:ProcessCC(skill)
  self.interrupts = self.interrupts + skill.interrupts
  -- adds interrupts the skill's fight
  local fight = self:fight()
  local unit = self:unit()
  if fight and unit and not unit.enemy and not self.skillTaken then
    fight.interruptsTotal = fight.interruptsTotal + skill.interrupts
  end
end


function Skill:ProcessFallingDamage(skill)
  self.damageDone = self.damageDone + skill.damage

  local fight = self:fight()
  local unit = self:unit()
  if fight and unit and not unit.enemy and self.skillTaken then
    fight.damageTakenTotal = fight.damageTakenTotal + skill.damage
  end
end


------------------------------------------
--   stats processing functon
------------------------------------------
-- this function is just an helper to dynamically get the needed stat amount

function Skill:dataFor(stat)
  if stat == "damageDone" then
    return self.damageDone
  elseif stat == "damageTaken" then
    -- yep, to calculate damage taken I need the damageDone by a skill
    return self.damageDone
  elseif stat == "healingDone" then
    return self.healingDone
  elseif stat == "overhealDone" then
    return self.overhealDone
  elseif stat == "interrupts" then
    return self.interrupts
  elseif stat == "rawhealDone" then
    return self.healingDone + self.overhealDone
  else
    Apollo.AddAddonErrorText(DarkMeter, "Skill class cannot pull data for stat: " .. stat)
  end
end


-- returns integer percentage of multihit, crit, deflects...
function Skill:statsPercentages(sStat)
  local key
  if sStat == "damageDone" or sStat == "damageTaken" then
    key = "damage"
  elseif sStat == "healingDone" or sStat == "overhealDone" or sStat == "rawhealDone" then
    key = "heals"
  end

  if key then
    local total = self[key].total
    local multi = #self[key].multihits
    local multicrit = #self[key].multicrits
    local crit = #self[key].crits

    local percentages = {}
    if multi > 0 then
      percentages.multihitsCount = multi
      percentages.multihits = multi / total *100
    else
      percentages.multihitsCount = 0
      percentages.multihits = 0
    end
    if multicrit > 0 then
      percentages.multicritsCount = multicrit
      percentages.multicrits = multicrit / total * 100
    else
      percentages.multicritsCount = 0
      percentages.multicrits = 0
    end
    if crit > 0 then
      percentages.critsCount = crit
      percentages.crits = crit / total * 100
    else
      percentages.critsCount = 0
      percentages.crits = 0
    end
    if key == "damage" and self.damage.deflects > 0 then
      percentages.deflectsCount = self.damage.deflects
      percentages.deflects = self.damage.deflects / (total + multi + multicrit) * 100
    elseif key == "damage" then
      percentages.deflectsCount = 0
      percentages.deflects = 0
    end
    
    percentages.attacks = total
    return percentages
  end
  return nil
end


-------------------------------------------------
-- Min, Max and Avg functions for each stat
-------------------------------------------------

-- returns a table with avg hit, crit, multihit and multicrit
for _, st in pairs({"damageDone", "healingDone", "overhealDone", "rawhealDone"}) do
  
  Skill[st .. "Avg"] = function (self)
    local tmp = {}
    local tble = st == "damageDone" and self.damage or self.heals
    
    for k, v in pairs(tble) do
      if type(v) == "table" then
        local i = 0
        tmp[k] = 0
        for _, amount in pairs(v) do
          if amount ~= false then
            if st == "damageDone" then
              tmp[k] = tmp[k] + amount
            elseif st == "healingDone" then
              tmp[k] = tmp[k] + amount.heal
            elseif st == "overhealDone" then
              tmp[k] = tmp[k] + amount.oHeal
            elseif st == "rawhealDone" then
              tmp[k] = tmp[k] + amount.heal + amount.oHeal
            end

            i = i + 1
          end
        end
        if tmp[k] > 0 then
          tmp[k] = tmp[k] / i
        end
      end
    end
    return tmp
  end


  Skill[st .. "Max"] = function(self)
    local tmp = {}
    local tble = st == "damageDone" and self.damage or self.heals

    for k, v in pairs(tble) do
      if type(v) == "table" then
        local arr = {}

        for _, amount in pairs(v) do
          if amount ~= false then
            if st == "damageDone" then
              arr[#arr + 1] = amount
            elseif st == "healingDone" then
              arr[#arr + 1] = amount.heal
            elseif st == "overhealDone" then
              arr[#arr + 1] = amount.oHeal
            elseif st == "rawhealDone" then
              arr[#arr + 1] = (amount.heal + amount.oHeal)
            end
          end
        end
        if #arr > 0 then
          tmp[k] = math.max(unpack(arr))
        end

      end
    end
    return tmp
  end


  Skill[st .. "Min"] = function(self)
    local tmp = {}
    local tble = st == "damageDone" and self.damage or self.heals

    for k, v in pairs(tble) do
      if type(v) == "table" then
        local arr = {}

        for _, amount in pairs(v) do
          if amount ~= false then
            if st == "damageDone" then
              arr[#arr + 1] = amount
            elseif st == "healingDone" then
              arr[#arr + 1] = amount.heal
            elseif st == "overhealDone" then
              arr[#arr + 1] = amount.oHeal
            elseif st == "rawhealDone" then
              arr[#arr + 1] = (amount.heal + amount.oHeal)
            end
          end
        end
        if #arr > 0 then
          tmp[k] = math.min(unpack(arr))
        end

      end
    end
    return tmp
  end

end






Apollo.RegisterPackage(Skill, "DarkMeter:Skill", 1, {"DarkMeter:Utils"})