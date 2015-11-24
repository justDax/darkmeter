
local Skill = {}
local DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage


function Skill:new()

  -- TODO how do I manage critical multihits?
  -- possible soltion: add a table called multicrit to damage and heals and add there critical multihits
  local initialValues = {
    name = "",
    damage = {
      deflects = 0,
      total = 0,
      hits = {},
      crits = {},
      multihits = {},
      multicrits = {}
    },
    heals = {
      total = 0,
      hits = {},
      crits = {},
      multihits = {},
      multicrits = {}
    },
    cc = {},
    -- quick reference values
    damageDone = 0,
    healingDone = 0,
    overhealDone = 0,
    interrupts = 0
  }
  self.__index = self
  return setmetatable(initialValues, self)
end


-- adds new input to the current skill
function Skill:add(formattedSkill)
  -- TODO don't increment total at each dot thick, this leads to an incorrect deflect percentage and crit count

  -- set skill name
  if self.name == "" and formattedSkill.name then
    self.name = formattedSkill.name
    -- I need to identify somehow if the skill belongs to a normal unit or a pet
    -- I do this by setting the ownerName, if is not nil, this skill has been casted by a pet
    self.casterName = formattedSkill.casterName
    self.ownerName = formattedSkill.ownerName
  end

  -- add skill icon
  if (self.icon == nil or self.icon == "") then
    local icon = DMUtils:GetSpellIconByName(self.name)

    if (icon == nil or icon == "") and formattedSkill.spell then
      icon = formattedSkill.spell:GetIcon()
    end
    
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


-- process a damaging skill
function Skill:ProcessDamage(skill)
  self.damage.total = self.damage.total + 1

  -- deflect
  if skill.state == GameLib.CodeEnumCombatResult.Avoid then
    self.damage.deflects = self.damage.deflects + 1
  -- crit
  elseif skill.state == GameLib.CodeEnumCombatResult.Critical then
    if skill.multihit then
      table.insert(self.damage.multicrits, skill.damage)
    else
      table.insert(self.damage.crits, skill.damage)
    end
    self.damageDone = self.damageDone + skill.damage
  -- normal hit
  elseif skill.state == GameLib.CodeEnumCombatResult.Hit then
    if skill.multihit then
      table.insert(self.damage.multihits, skill.damage)
    else
      table.insert(self.damage.hits, skill.damage)
    end
    self.damageDone = self.damageDone + skill.damage
  end
end


-- process an healing skill
function Skill:ProcessHeal(skill)
  self.heals.total = self.heals.total + 1

  -- crit
  if skill.state == GameLib.CodeEnumCombatResult.Critical then
    if skill.multihit then
      table.insert(self.heals.multicrits, skill.heal)
    else
      table.insert(self.heals.crits, skill.heal)
    end
  -- normal hit
  elseif skill.state == GameLib.CodeEnumCombatResult.Hit then
    if skill.multihit then
      table.insert(self.heals.multihits, skill.heal)
    else
      table.insert(self.heals.hits, skill.heal)
    end
  end

  self.healingDone = self.healingDone + skill.heal
  self.overhealDone = self.overhealDone + skill.overheal
end


function Skill:ProcessCC(skill)
  -- no need to archive an entire cc skill.. let's just increment the interrupts

  -- if skill.state == GameLib.CodeEnumCombatResult.Hit then
  --   table.insert(self.cc, skill)
  -- end

  self.interrupts = self.interrupts + skill.interrupts
end


function Skill:ProcessFallingDamage(skill)
  self.damageDone = self.damageDone + skill.damage
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
  else
    Apollo.AddAddonErrorText(DarkMeter, "Skill class cannot pull data for stat: " .. stat)
  end
end


-- returns integer percentage of multihit, crit, deflects...
function Skill:statsPercentages(bDamage)
  local key = bDamage and "damage" or "heals"
  local total = self[key].total
  local multi = #self[key].multihits
  local multicrit = #self[key].multicrits
  local crit = #self[key].crits
  local deflects
  if bDamage then
    deflects = self.damage.deflects
  end

  local percentages = {}
  if multi + multicrit > 0 then
    percentages.multihits = (multi + multicrit) / (total - multi - multicrit) *100
  else
    percentages.multihits = 0
  end
  if multicrit > 0 then
    percentages.multicrits = multicrit / (multi + multicrit) * 100
  else
    percentages.multicrits = 0
  end
  if crit + multicrit > 0 then
    percentages.crits = (crit + multicrit) / total * 100
  else
    percentages.crits = 0
  end
  if bDamage then
    percentages.deflects = deflects / total * 100
  end
  
  percentages.attacks = total
  return percentages
end






Apollo.RegisterPackage(Skill, "DarkMeter:Skill", 1, {"DarkMeter:Utils"})