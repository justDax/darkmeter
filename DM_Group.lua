
-------------------------------------------------------------
-- Group class
-------------------------------------------------------------
-- only one instance of this class should be initialized
-- Group requires Unit class to instantiate group members
-- this is basically a list containing instances of Unit class
-- each instance represents a group member
-- a group instance always contains at least an instance of Unit, representing the current player, even if not in a group
-------------------------------------------------------------

local Group = {}

-- external classes
local Unit = Apollo.GetPackage("DarkMeter:Unit").tPackage


function Group:new()
  local group = {}

  self.members = {}
  self.__index = self
  return setmetatable(group, self)
end


-- return group members ids
function Group:membersIds()
  ids = {}
  for i = 1, #self.members do
    ids[i] = self.members[i].id
  end
  return ids
end


-- adds a unit to the group if not already in the group
function Group:addMember(wsUnit)
  local unitId = wsUnit:GetId()
  -- local membersIds = self:membersIds()

  -- if the unit is already in the group return false
  if self.members[unitId] ~= nil then return false end
  
  -- instantiate a new unit and add to the group
  local unit = Unit:new(wsUnit)
  self.members[unitId] = unit

  -- local Rover = Apollo.GetAddon("Rover")
  -- if Rover then
  --   Rover:AddWatch("group", self, nil)
  -- end

  return true
end

-- removes a member by id
function Group:removeMember(id)
  self.members[id] = nil
end

-- remove all members
function Group:removeAll()
  self.members = {}
end

-- returns true if at least one membaer is in combat
function Group:inCombat()
  for id, unit in pairs(self.members) do
    if unit.inCombat then return true end
  end
  return false
end



Apollo.RegisterPackage(Group, "DarkMeter:Group", 1, {"DarkMeter:Unit"})