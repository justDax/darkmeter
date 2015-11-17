
local Skill = {}
local DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage


function Skill:new()

  -- TODO how do I manage critical multihits?
  -- possible soltion: add a table called multicrit to damage and heals and add there critical multihits
  local initialValues = {
    damage = {
      deflects = 0,
      total = 0,
      hits = {},
      crits = {},
      multihits = {}
    },
    heals = {
      total = 0,
      hits = {},
      crits = {},
      multihits = {}
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
  -- damage skill
  if formattedSkill.typology == 8 then
    self:ProcessDamage(formattedSkill)
  -- healing skill
  elseif formattedSkill.typology == 10 then
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
    table.insert(self.damage.crits, skill.damage)
    self.damageDone = self.damageDone + skill.damage
  -- normal hit
  elseif skill.state == GameLib.CodeEnumCombatResult.Hit then
    table.insert(self.damage.hits, skill.damage)
    self.damageDone = self.damageDone + skill.damage
  end
end


-- process an healing skill
function Skill:ProcessHeal(skill)
  self.heals.total = self.heals.total + 1

  -- crit
  if skill.state == GameLib.CodeEnumCombatResult.Critical then
    table.insert(self.heals.crits, skill.heal)
  -- normal hit
  elseif skill.state == GameLib.CodeEnumCombatResult.Hit then
    table.insert(self.heals.hits, skill.heal)
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



Apollo.RegisterPackage(Skill, "DarkMeter:Skill", 1, {"DarkMeter:Utils"})