
-- creates dummy data for development and testing
  
local DarkMeter = Apollo.GetAddon("DarkMeter")
local DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage
local Unit = Apollo.GetPackage("DarkMeter:Unit").tPackage
local UI = Apollo.GetPackage("DarkMeter:UI").tPackage
local Fight = Apollo.GetPackage("DarkMeter:Fight").tPackage

local testFight = Fight:new()
testFight.forcedName = "Test fight"


-------------------------------------------
--- Fake Units
-------------------------------------------

-- dummy unit with static values
local testUnit = {
  pet = false
}
function testUnit:GetId()
  return 123
end
function testUnit:GetName()
  return "Pika pika"
end
function testUnit:GetUnitOwner()
  return nil
end
function testUnit:GetLevel()
  return 50
end
function testUnit:GetRank()
  return 5
end
function testUnit:GetClassId()
  return 2
end
function testUnit:IsInCombat()
  return false
end


-- dummy enemy with static values
local enemyUnit = {
  pet = false
}
function enemyUnit:GetId()
  return 456
end
function enemyUnit:GetName()
  return "Team rocket"
end
function enemyUnit:GetUnitOwner()
  return nil
end
function enemyUnit:GetLevel()
  return 50
end
function enemyUnit:GetRank()
  return 5
end
function enemyUnit:GetClassId()
  return 2
end
function enemyUnit:IsInCombat()
  return false
end


-------------------------------------------
--- Fake Spell
-------------------------------------------

local testAttack = {}
function testAttack:new()
  local dummyVals = {
    bPeriodic = false,
    bTargetKilled = false,
    bTargetVulnerable = false,
    eCombatResult = 2,
    eDamageType = 1,
    eEffectType = 8,
    nAssorbption = 0,
    nDamageAmount = math.random(1000, 1100),
    nGlanceAmount = 0,
    nOverkill = 0,
    nRawDamage = 3456,
    nShield = 0,
    name = "Thundershock",
    multihit = math.random(1, 10) == 10,
    typology = "damage"
  }

  local rnm = math.random(1, 100)

  if rnm < 5 then 
    dummyVals.state = GameLib.CodeEnumCombatResult.Avoid
  elseif rnm < 15 then
    dummyVals.state = GameLib.CodeEnumCombatResult.Critical
  else
    dummyVals.state = GameLib.CodeEnumCombatResult.Hit
  end

  self._index = self
  return setmetatable(dummyVals, self)
end


local testHeal = {}
function testHeal:new()
  local dummyVals = {
    bPeriodic = false,
    eCombatResult = 2,
    eEffectType = 10,
    nHealAmount = math.random(3000, 3600),
    nOverheal = math.random(0, 1600),
    name = "Super Potion",
    multihit = math.random(1, 10) == 10,
    typology = "healing"
  }

  local rnm = math.random(1, 100)

  if rnm < 15 then
    dummyVals.state = GameLib.CodeEnumCombatResult.Critical
  else
    dummyVals.state = GameLib.CodeEnumCombatResult.Hit
  end

  self._index = self
  return setmetatable(dummyVals, self)
end




local dummySkill = {}
function dummySkill(e)
  local tmp = {
    state = e.state,
    multihit = (e.multihit or false),
    damage = (e.nDamageAmount or 0) + (e.nAbsorption or 0) + (e.nShield or 0),
    typology = e.typology,
    heal = (e.nHealAmount or 0),
    overheal = (e.nOverheal or 0),
    owner = nil,
    targetkilled = false,
    caster = testUnit,
    casterId = testUnit:GetId(),
    casterName = testUnit:GetName(),
    target = enemyUnit,
    targetId = enemyUnit:GetId(),
    targetName = enemyUnit:GetName(),
    name = e.name
  }


  if e.state == GameLib.CodeEnumCombatResult.Critical then
    tmp.damage = tmp.damage * 2
    tmp.heal = tmp.heal * 2
    tmp.overheal = tmp.overheal * 2
  end

  return tmp
end







testFight:addUnit(testUnit, true)
-- add skills to units

for _k, unit in pairs(testFight.groupMembers) do
  for i = 1, 100 do
    unit:addSkill(dummySkill(testAttack:new()))
    unit:addSkill(dummySkill(testHeal:new()))
  end
end


_G.DarkMeter.testData = function()
  DarkMeter:addFightToArchive(testFight)
end