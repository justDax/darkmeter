-----------------------------------------------------------------------------------------------
-- DarkMeter
-----------------------------------------------------------------------------------------------
 
require "Window"

local DarkMeter = {}
DarkMeter.version = "0.3.1"



if _G.DarkMeter == nil then _G.DarkMeter = {} end
-- enable prints and rover debugging
_G.DarkMeter.Development = false

-----------------------------------------------------------------------------------------------
-- Class Variables
-----------------------------------------------------------------------------------------------
local	DMUtils
local Fight
local Unit
local UI

-----------------------------------------------------------------------------------------------
-- Common Variables
-----------------------------------------------------------------------------------------------

local currentFight 												-- reference to the current fight instance, nil when out of combat
local overallFight  											-- overall data
local fightsArchive = {}									-- table with all the previous fights (from the most recent to the first fight)
local Group 														  -- current group variable
local CombatUtils = {}


DarkMeter.availableStats = {							-- list of what the user can monitor
	"damageDone",
	"overhealDone",
	"healingDone",
	"interrupts",
	"damageTaken",
	"deaths",
	"dps"
}

-- settings, this is loaded and stored between logouts
DarkMeter.settings = {
	overall = true,
	mergePets = true,
	showRanks = true,
	showClassIcon = true,
	selectedStats = {							-- ordered values that I'm tracking
		"damageDone",
		"interrupts"
	},
	reportRows = 5								-- number of rows reported in chat
}

DarkMeter.specificFight = nil 					-- reference to a specific fight instance, if the user is inspecting a single fight, if nil and overall is false, the currentFight is shown
DarkMeter.paused = false

-- list containing all events to register/unregister
local combatLogEvents = {
	"CombatLogDamage",
	"CombatLogMultiHit",
	"CombatLogHeal",
	"CombatLogMultiHeal",
	"CombatLogDeflect",
	"CombatLogTransference",
	"CombatLogCCState",
	"CombatLogFallingDamage",
	"CombatLogReflect",
	"CombatLogMultiHitShields",
	"CombatLogDamageShields",
	"CombatLogLifeSteal"
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function DarkMeter:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    return o
end

function DarkMeter:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"DarkMeter:Fight",
		"DarkMeter:Group",
		"DarkMeter:UI",
		"DarkMeter:Utils",
		"DarkMeter:Unit"
	}
  Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
  
end
 

-----------------------------------------------------------------------------------------------
-- DarkMeter OnLoad
-----------------------------------------------------------------------------------------------
function DarkMeter:OnLoad()
	Apollo.LoadSprites("DM_Sprites.xml", "DM_Sprites")

	-- external classes
	DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage
	Unit = Apollo.GetPackage("DarkMeter:Unit").tPackage
	UI = Apollo.GetPackage("DarkMeter:UI").tPackage
	Fight = Apollo.GetPackage("DarkMeter:Fight").tPackage


	Apollo.RegisterEventHandler("Group_Updated", "updateGroup", self)
	Apollo.RegisterEventHandler("Group_Left", "updateGroup", self)


	-- slash commands
	Apollo.RegisterSlashCommand("dm", "toggle", self)
	Apollo.RegisterSlashCommand("darkmeter", "toggle", self)
	
	-- asks it the user wants to reset the data on world change
	Apollo.RegisterEventHandler("ChangeWorld", "promptResetData", UI)
	-- TODO - sometimes the group bugs when changing zone, pheraps the unit does't exists yet on the moment this event gets called? I need to test this one
	-- TODO - I might need to add a delay to the group update then...
	Apollo.RegisterEventHandler("ChangeWorld", "updateGroup", self)

	for i = 1, #combatLogEvents do
		Apollo.RegisterEventHandler(combatLogEvents[i], "On" .. combatLogEvents[i], DarkMeter)
	end

	-- this event must be handled even if the addon is paused to detect if the group exit combat
	-- in case this happens, it means that the addon has been paused in the middle of a fight that is now over and I need to instantiate a new currentFight when the addon is resumed
	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnUnitEnteredCombat", DarkMeter)


	Apollo.CreateTimer("MainFormRefresher", 1, true)
	Apollo.RegisterTimerHandler("MainFormRefresher", "OnMainFormRefresher", self)

	-- updates Group with a list of Unit instances, each unit is a group member
	Group = Apollo.GetPackage("DarkMeter:Group").tPackage:new()					-- no more Group must me instantiated from now

	self:updateGroup()
	UI:init()
end


-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
-- Functions
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------


function DarkMeter:OnRestore(eType, data)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	for k, v in pairs(data) do
		self.settings[k] = v
	end

	self.loaded = true

	if data.mainFormLocation ~= nil then
		-- if mainform window has been initialized, set its position, else set var and let the ui initialize the form position
		if UI.MainForm.form ~= nil then
			UI.MainForm.form:MoveToLocation(WindowLocation:new(MainForm.initialLocation))
		else
			UI.MainForm.initialLocation = data.mainFormLocation
		end
	end
	UI.MainForm:setTracked()
end

function DarkMeter:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	self.settings.mainFormLocation = UI.MainForm.form:GetLocation():ToTable()
	return DMUtils.cloneTable(self.settings)
end


function DarkMeter:addTracked(name, index)
	for i = 1, #self.settings.selectedStats do
		if self.settings.selectedStats[i] == name then
			table.remove(self.settings.selectedStats, i)
		end
	end
	if index > (#self.settings.selectedStats + 1) then
		index = #self.settings.selectedStats + 1
	end
	table.insert(self.settings.selectedStats, index, name)
	UI.MainForm:initColumns()
	self:updateUI()
end

function DarkMeter:removeTracked(name)
	local stats = self.settings.selectedStats
	for i = 1, #stats do
		if stats[i] == name then
			table.remove(self.settings.selectedStats, i)
			UI.MainForm:initColumns()
			self:updateUI()
			break
		end
	end
end


----------------------------------
-- Start / pause / reset
----------------------------------


-- pause DarkMeter
-- removes combat log event handlers, hides ui and pause fights
function DarkMeter:pause()
	for i = 1, #combatLogEvents do
		Apollo.RemoveEventHandler(combatLogEvents[i], DarkMeter)
	end
	Apollo.StopTimer("MainFormRefresher")
	
	-- pause all the fights
	-- if the combat ends while the addon is paused, currentFight should be archived and set to nil as usual
	for _, fight in pairs({currentFight, overallFight}) do
		fight:stop()
	end

	self.paused = true
	UI:hide()

end

function DarkMeter:resume()
	for i = 1, #combatLogEvents do
		Apollo.RegisterEventHandler(combatLogEvents[i], "On" .. combatLogEvents[i], DarkMeter)
	end
	Apollo.StartTimer("MainFormRefresher")

	-- resume the fight if the group is in combat
	if Group:inCombat() then
		self:startCombatIfNecessary()
	end

	self.paused = false
	UI:show()
end

function DarkMeter:toggle()
	if self.paused then
		self:resume()
	else
		self:pause()
	end
end



-- reset current fight and fight archive and calls ui clean
function DarkMeter:resetData()
	fightsArchive = {}
	currentFight = nil
	overallFight = nil
	if Group:inCombat() then
		DarkMeter:startCombatIfNecessary()
	end
end


-- calls ui prompt reset dialog (bound on world change)
function DarkMeter:promptResetData()
	UI.ResetForm:show()
end


-- main form refresh timer
function DarkMeter:OnMainFormRefresher()
	local deltaTime = GameLib.GetGameTime() - UI.lastUpdate
	if Group:inCombat() and deltaTime >= 1 then
		self:updateUI()
	end
end


----------------------------------
-- update group
----------------------------------
function DarkMeter:updateGroup()
	local groupMembersCount = GroupLib.GetMemberCount()

	-- if inside a group
	if groupMembersCount > 0 then
		local newMembersIds = {}
		
		if _G.DarkMeter.Development then
			Print(tostring(groupMembersCount))
		end

		-- try to add all members to the group
		for i = 1, groupMembersCount do
			local unit = GroupLib.GetUnitForGroupMember(i)
			if unit ~= nil then
				Group:addMember(unit)
				table.insert(newMembersIds, unit:GetId())
			end
		end

		-- remove members that are no longer in the group
		for id, unit in pairs(Group.members) do
			local delete = true
			for i = 1, #newMembersIds do
				if id == newMembersIds[i] then 
					delete = false
					break 
				end
			end

			if delete then Group.members[id] = nil end
		end
	else
		Group:removeAll()
		
		-- GetPlayerUnit() hack -- when loging in or transitioning the addon is loaded before the character
		if GameLib:GetPlayerUnit() then
			Group:addMember(GameLib:GetPlayerUnit())
			Apollo.RemoveEventHandler("CharacterCreated", self)
		else
			Apollo.RegisterEventHandler("CharacterCreated", "updateGroup", self)
		end
	end
	
	if _G.DarkMeter.Development then
		SendVarToRover("group", Group)
	end
end

-- called whenever a nearby player changes it's combat status
function DarkMeter:OnUnitEnteredCombat(unit, inCombat)
	local unitId = unit:GetId()
	
	-- if the unitID is in the current group
	if Group.members[unitId] ~= nil then
		if inCombat then
			if _G.DarkMeter.Development then
				Print("Group member entered combat !!!")
			end
			Group.members[unitId].inCombat = true
		else
			if _G.DarkMeter.Development then
				Print("Group member left combat")
			end
			Group.members[unitId].inCombat = false
		end
		
		if Group:inCombat() then
			DarkMeter:startCombatIfNecessary()
		elseif not Group:inCombat() and currentFight then
			DarkMeter:stopCurrentFight()
		end
	end
	CombatUtils:updateCurrentFight()
end

----------------------------------
-- combat log utils
----------------------------------

CombatUtils.Events = {}

-- debug function only, not necessary
function CombatUtils:updateCurrentFight()
	if _G.DarkMeter.Development then
		SendVarToRover("overallFight", overallFight)
		SendVarToRover("currentFight", currentFight)
		SendVarToRover("fightsArchive", fightsArchive)
	end
end



-- return a formatted combat action table
function CombatUtils:formatCombatAction(e, customValues)
	table.insert(CombatUtils.Events, 1, e)
	CombatUtils.Events[11] = nil
	if _G.DarkMeter.Development then
		SendVarToRover("CapturedEvents", CombatUtils.Events)
		SendVarToRover("lastLogEvent", e)
	end
	
	customValues = customValues or {}

	-- initialize common useful values
	local event = {
		state = e.eCombatResult,
		multihit = false,
		damage = (e.nDamageAmount or 0) + (e.nAbsorption or 0) + (e.nShield or 0),
		typology = e.eEffectType,
		heal = (e.nHealAmount or 0),
		overheal = (e.nOverheal or 0),
		owner = e.unitCasterOwner,
		targetkilled = e.bTargetKilled
	}

	-- add info about the caster
	if e.unitCaster then
		event.caster = e.unitCaster
		event.casterId = e.unitCaster:GetId()
		event.casterName = e.unitCaster:GetName()
	end

	-- add info about the target
	if e.unitTarget then
		event.target = e.unitTarget
		event.targetId = e.unitTarget:GetId()
		event.targetName = e.unitTarget:GetName()
	end

	-- add info on the spell itself
	if e.splCallingSpell then
		event.spell = e.splCallingSpell
		event.name = e.splCallingSpell:GetName()
	end

	-- add pet info
	if event.owner then
		event.ownerId = event.owner:GetId()
		event.ownerName = event.owner:GetName()
	end

	event.__index = event
	setmetatable(customValues, event)
	
	if _G.DarkMeter.Development then
		SendVarToRover("formattedSkill", customValues)
	end
	return customValues
end

-- add the caster or the target of a skill, if a group member is involved (is the caster or the target)
function CombatUtils:addUnitsToFight(skill)
	for _, fight in pairs({currentFight, overallFight}) do
		-- if the caster is a group member
		if Group.members[skill.casterId] ~= nil then
			fight:addUnit(skill.caster, true)
			fight:addUnit(skill.target, false)
		-- the target is the pet of a group member
		elseif skill.ownerId ~= nil and Group.members[skill.ownerId] ~= nil then
			-- add owner
			if Group.members[skill.ownerId] ~= nil then
				fight:addUnit(skill.owner, true)
			end
			fight.groupMembers[skill.ownerId]:addPet(skill.caster)
			fight:addUnit(skill.target, false)

		-- if the target is a group member, the caster is an enemy
		elseif Group.members[skill.targetId] ~= nil then
			fight:addUnit(skill.caster, false)
			fight:addUnit(skill.target, true)
		end
	end
end

-- adds the skill casted to the caster
function CombatUtils:addSkillToUnit(skill)
	for _, fight in pairs({currentFight, overallFight}) do
		if fight.groupMembers[skill.casterId] ~= nil then
			fight.groupMembers[skill.casterId]:addSkill(skill)
			-- if the skill belongs to a pet
		elseif skill.ownerId ~= nil and fight.groupMembers[skill.ownerId] ~= nil then
			local petUnit = fight.groupMembers[skill.ownerId].pets[skill.casterName]
			if petUnit ~= nil then
				petUnit:addSkill(skill)
			end
		end

		-- don't add skill casted to the enemies for now
		-- I'll leave those lines commented here, maybe I can implement this in a future, but I don't think this can be an useful feature outside arenas
		-- elseif fight.enemies[skill.casterId] ~= nil then
		-- 	fight.enemies[skill.casterId]:addSkill(skill)
		if fight.groupMembers[skill.targetId] ~= nil then
			fight.groupMembers[skill.targetId]:addSkillTaken(skill)
		end
	end
end

-- process formatted skill action
function CombatUtils:processFormattedSkill(skill)
	if Group:inCombat() then
		CombatUtils:addUnitsToFight(skill)								-- adds this unit to the currentFight if not already added
		CombatUtils:addSkillToUnit(skill)									-- adds the casted skill to the caster
		CombatUtils:updateCurrentFight()
		UI.needsUpdate = true
		DarkMeter:updateUI()
	end
end


-- instantiate a new Fight instance to create the currentFight if necessary
function DarkMeter:startCombatIfNecessary()
	-- instantiate a new fight if out of combat
	if not currentFight then
		currentFight = Fight:new()
		currentFight.forcedName = "Current fight"
	elseif currentFight:paused() then
		currentFight:continue()
	end
	if not overallFight then
		overallFight = Fight:new()
		overallFight.forcedName = "Overall fights"
	elseif overallFight:paused() then
		overallFight:continue()
	end
end

-- archive currentFight and sets it to nil
function DarkMeter:stopCurrentFight()
	currentFight:stop()
	overallFight:stop()

	currentFight.forcedName = nil
	-- check that the fight has at least a member to prevent inserting fights when nothing happens (a mob that aggro then evades without hitting)
	if DMUtils.tableLength(currentFight.groupMembers) > 0 then
		table.insert(fightsArchive, 1, DMUtils.cloneTable(currentFight))
	end
	currentFight = nil
	-- after 0.6 sec call an updateUI to check if the interface needs an update
	ApolloTimer.Create(0.6, false, "updateUI", DarkMeter)
end


----------------------------------
-- on combat log events
----------------------------------


-- This event fires whenever a normal attack lands
function DarkMeter:OnCombatLogDamage(e)
	-- force combat start if player is in combat (fix for a reloadui when in combat)
	if Group.members[GameLib.GetPlayerUnit():GetId()].inCombat then
		DarkMeter:startCombatIfNecessary()
	end
	
	if _G.DarkMeter.Development then
		Print("DAMEIG!")
	end
	local skill = CombatUtils:formatCombatAction(e)
	CombatUtils:processFormattedSkill(skill)
end

-- This event fires whenever an attack gets a Multi-Hit proc.
function DarkMeter:OnCombatLogMultiHit(e)
	if _G.DarkMeter.Development then
		Print("MultiHit!")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		multihit = true,
		typology = 8  -- force all multihits with the same code as a damaging spell
	})
	CombatUtils:processFormattedSkill(skill)
end

function DarkMeter:OnCombatLogHeal(e)
	if _G.DarkMeter.Development then 
		Print("Heal") 
	end
	local skill = CombatUtils:formatCombatAction(e)
	CombatUtils:processFormattedSkill(skill)
end

function DarkMeter:OnCombatLogMultiHeal(e)
	if _G.DarkMeter.Development then
		Print("MultiHeal!")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		multihit = true,
		typology = 10
	})
	CombatUtils:processFormattedSkill(skill)
end

function DarkMeter:OnCombatLogDeflect(e)
	if _G.DarkMeter.Development then
		Print("deflect...")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		typology = 8  -- force all deflects with the same code as a damaging spell
	})
	CombatUtils:processFormattedSkill(skill)
end

-- handles transference (skills that deals damage AND heals the user such as stalker's nano field)
function DarkMeter:OnCombatLogTransference(e)
	if _G.DarkMeter.Development then
		Print("Log Transference")
	end

	-- TODO! need to test this part better
	local skill = CombatUtils:formatCombatAction(e, {
		typology = 8
	})
	CombatUtils:processFormattedSkill(skill)

	if e.tHealData then
		for i = 1, #e.tHealData do
			-- create a new spell and process it separately to consider the healing effect
			-- this spell has most of its values taken from its damaging portion
			local healEffect = CombatUtils:formatCombatAction(e.tHealData[i], {
				state = e.eCombatResult,
				owner = e.unitCasterOwner,
				caster = skill.caster,
				casterId = skill.casterId,
				casterName = skill.casterName,
				target = e.tHealData[i].unitHealed,
			 	targetId = e.tHealData[i].unitHealed:GetId(),
			 	targetName = e.tHealData[i].unitHealed:GetName(),
			 	spell = skill.splCallingSpell,
				name = skill.name,
				ownerId = skill.ownerIdm,
				ownerName = skill.onwerName,
				multihit = skill.multihit,
				typology = 10,
				
				-- TODO keep track of this part, I think it might get changed in the future
				-- manually calculate heal and overheal beause the api is kinda illogical here
				-- while on the CombatLogHeal event the heal returned is the real value with overheals subtracted
				-- for this event (for no reason at all) I need to manually subtract the overhealing portion from the heal
				overheal = e.tHealData[i].nOverheal,
				heal = e.tHealData[i].nHealAmount - e.tHealData[i].nOverheal
			})
			CombatUtils:processFormattedSkill(healEffect)
		end
	end

end

function DarkMeter:OnCombatLogCCState(e)
	if _G.DarkMeter.Development then
		Print("CC <--")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		interrupts = e.nInterruptArmorHit
	})

	if not e.bRemoved and e.nInterruptArmorHit > 0 then
		CombatUtils:processFormattedSkill(skill)
	end
end

-- This event fires whenever an attack gets a Multi-Hit proc, but is completely absorbed by shields
-- TODO check this event if gets processed normally, as there's no documentation on Houston
function DarkMeter:OnCombatLogMultiHitShields(e)
	if _G.DarkMeter.Development then
		Print("Multihit! Absorbed!")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		multihit = true,
		typology = 8  -- force all multihits with the same code as a damaging spell
	})
	CombatUtils:processFormattedSkill(skill)
end

-- This event fires whenever a player gets fallng damages
function DarkMeter:OnCombatLogFallingDamage(e)
	if _G.DarkMeter.Development then
		Print("Falling Damage")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		target = e.unitCaster,
		targetId = e.unitCaster:GetId(),
		fallingDamage = true,
		name = "Falling damage"
	})
	CombatUtils:processFormattedSkill(skill)
end

-- This event fires whenever an attack is completely absorbed by shields.
-- TODO check this event if gets processed normally, as there's no documentation on Houston
function DarkMeter:OnCombatLogDamageShields(e)
	if _G.DarkMeter.Development then
		Print("DAMEIG! Absorbed!")
	end
	local skill = CombatUtils:formatCombatAction(e)
	CombatUtils:processFormattedSkill(skill)
end

-- This event fires whenever a spell is reflected back on its caster.
function DarkMeter:OnCombatLogReflect(e)
	if _G.DarkMeter.Development then
		Print("REFLECT!!!!")
	end
	-- TODO process reflects
end


function DarkMeter:OnCombatLogLifeSteal(e)
	if _G.DarkMeter.Development then
		Print("LIFESTEAL!!!")
	end
	-- TODO I don't know if implement this or not, because this event only returns a flat number
	-- representing the health stolen and the unit caster
	-- no overheal, no skill used...
end



-----------------------------------------------------------------------------------------------
-- UI Functions
-----------------------------------------------------------------------------------------------

function DarkMeter:updateUI()
	if self.settings.overall then
		-- show overall data
		if overallFight then
			UI:showDataForFight(overallFight)
		end
	else
		-- if the user is not inspecting a specific fight, show currentFight
		if not self.specificFight then
			if not currentFight then
				UI.MainForm:clear()
			else
				UI:showDataForFight(currentFight)
			end
		-- show specific fight
		else
			UI:showDataForFight(self.specificFight)
		end
	end
end

function DarkMeter:specificFightByIndex(i)
	return fightsArchive[i]
end


-----------------------------------------------------------------------------------------------
-- DarkMeter Instance
-----------------------------------------------------------------------------------------------
local DarkMeterInst = DarkMeter:new()
DarkMeterInst:Init()
