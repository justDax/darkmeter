-----------------------------------------------------------------------------------------------
-- DarkMeter
-----------------------------------------------------------------------------------------------
 
-- This addon uses a custom class called Unit, which is a "wrapper" of the Unit class coming from the API
-- variables called "unit" are usually instances of the cusom Unit class, while the Unit coming from the API is usually called "wsUnit" (wildstar unit)

require "Window"

local DarkMeter = {}
DarkMeter.version = "0.4.5"



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

DarkMeter.initialized = false							-- this flag will be set to true when the addon hasn been loaded and the ui initialized
DarkMeter.specificFight = nil 						-- reference to a specific fight instance, if the user is inspecting a single fight, if nil and overall is false, the currentFight is shown
DarkMeter.paused = false
DarkMeter.playerInPvPMatch =	false				-- true if player enters a pvp match, like bg or arena


-- list of the stats the user can monitor
DarkMeter.availableStats = {
	"damageDone",
	"overhealDone",
	"healingDone",
	"interrupts",
	"damageTaken",
	"deaths",
	"dps"
}

-- defaults settings, this table is overwritten on logins and stored on logouts
DarkMeter.defaults = {
	mainFormLocation = WindowLocation.new({
		fPoints = {0, 0, 0, 0},
    nOffsets = {200, 300, 600, 600}
	}),
	overall = true,
	mergePets = true,
	showRanks = true,
	showClassIcon = true,
	selectedStats = {							-- ordered values that I'm tracking
		"damageDone",
		"interrupts"
	},
	reportRows = 5,								-- number of rows reported in chat
	resetMapChange = 2,						-- integer value, can be: 1 (always), 2 (ask), 3 (never)
	rowHeight = 26,								-- mainform row height (from 20 to 50)
	mergePvpFights = true,				-- if enabled and inside a pvp match, the currentFight will last untill the match is over, even when going out of combat
	shortNumberFormat = true, 		-- if enabled, the number will be shown as 1.2Mil instead of 1.200,000
	mergeDots = false							-- if true, all the skills that create a dot effect will be merged with the dot damage part, this means that the number of attacks will also count each dot tick
}
DarkMeter.settings = {}


for k, v in pairs(DarkMeter.defaults) do
	DarkMeter.settings[k] = v
end


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
	-- load form file
	self.xmlDoc = XmlDoc.CreateFromFile("DarkMeter.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-- after form has been loaded
function DarkMeter:OnDocLoaded()
	Apollo.LoadSprites("DM_Sprites.xml", "DM_Sprites")

	-- external classes
	DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage
	Unit = Apollo.GetPackage("DarkMeter:Unit").tPackage
	UI = Apollo.GetPackage("DarkMeter:UI").tPackage
	Fight = Apollo.GetPackage("DarkMeter:Fight").tPackage


	Apollo.RegisterEventHandler("Group_Updated", "updateGroup", self)
	Apollo.RegisterEventHandler("Group_Left", "updateGroup", self)


	-- slash commands
	Apollo.RegisterSlashCommand("dm", "slashHandler", self)
	Apollo.RegisterSlashCommand("darkmeter", "slashHandler", self)
	
	-- asks it the user wants to reset the data on world change
	Apollo.RegisterEventHandler("ChangeWorld", "promptResetData", UI)
	-- stop all fights when changing zone, this is needed if a player accepts a dungeon, shiphand, bg invite etc. while in combat
	Apollo.RegisterEventHandler("ChangeWorld", "stopAllFights", self)
	-- updates the group when changing zone
	Apollo.RegisterEventHandler("ChangeWorld", "delayedUpdateGroup", self)
	-- updates the group when player changes (houston says: Fires when the player first logs in, that's not true, this event gets fired whenever the player unit changes for example when entering Star Comm-Basin )
	Apollo.RegisterEventHandler("PlayerChanged", "updateGroup", self)
	

	for i = 1, #combatLogEvents do
		Apollo.RegisterEventHandler(combatLogEvents[i], "On" .. combatLogEvents[i], DarkMeter)
	end

	-- this event must be handled even if the addon is paused to detect if the group exit combat
	-- in case this happens, it means that the addon has been paused in the middle of a fight that is now over and I need to instantiate a new currentFight when the addon is resumed
	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnUnitEnteredCombat", DarkMeter)

	-- register when a player enters a match, a match is:
	-- Battleground, Dungeon, Adventure, Arena, Warplot, RatedBattleground, OpenArena, Event, Shiphand 
	Apollo.RegisterEventHandler("MatchEntered", "OnMatchEntered", self)
	Apollo.RegisterEventHandler("MatchExited", "OnMatchExited", self)
	Apollo.RegisterEventHandler("MatchFinished", "OnMatchFinished", self)

	-- sets if the player is in a pvp match after loading the addon
	if MatchingGame:GetPVPMatchState() ~= nil then
		self.playerInPvPMatch = true
	else
		self.playerInPvPMatch = false
	end

	-- timer that auto refreshes the main form if necessary
	Apollo.CreateTimer("MainFormRefresher", 0.5, true)
	Apollo.RegisterTimerHandler("MainFormRefresher", "OnMainFormRefresher", self)

	-- timer that refreshes monitored fight duration
	Apollo.CreateTimer("MonitoredFightTimer", 0.5, true)
	Apollo.RegisterTimerHandler("MonitoredFightTimer", "OnMonitoredFightTimer", self)
	Apollo.StopTimer("MonitoredFightTimer")

	-- updates Group with a list of Unit instances, each unit is a group member
	Group = Apollo.GetPackage("DarkMeter:Group").tPackage:new()					-- no more Group must me instantiated from now
	self:updateGroup()

	UI:init()

	-- the xml file reference is no longer needed
	self.xmlDoc = nil
	self.initialized = true
	if not self.settingsLoaded then
		DarkMeter:restoreAfterInitialized()
	end
end

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
-- Functions
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------




function DarkMeter:checkCombatLogOthers()
	local disableOthers = Apollo.GetConsoleVariable("cmbtlog.disableOtherPlayers")
	if disableOthers then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "to work properly, I need the option \"Log OtherPlayers\" to be enabled.", "DarkMeter")
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Please press \"Esc\", click on the \"Combat Log\" button inside your left menu and check the first option.", "DarkMeter")
	end
end



-- called then the addon is loaded...
-- override defaults settings
-- set form position and columns
function DarkMeter:OnRestore(eType, data)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	for k, v in pairs(data) do
		self.settings[k] = v
	end
	-- if the main addon parts has been loaded, set the window location and tracked
	if self.initialized then
		self:restoreAfterInitialized()
	end
end

-- apply restored settings, this is called after the addon has been initialized AND after the onRestore event
function DarkMeter:restoreAfterInitialized()
	if self.settings.mainFormLocation ~= nil then
		-- if mainform window has been initialized, set its position, else set var and let the ui initialize the form position
		if UI.MainForm.form ~= nil then
			UI.MainForm.form:MoveToLocation(WindowLocation.new(self.settings.mainFormLocation))
			UI.MainForm:initColumns()
			UI.MainForm.wrapper:RecalculateContentExtents()
		else
			UI.MainForm.initialLocation = self.settings.mainFormLocation
		end
	end
	UI.MainForm:setTracked()
	self.settingsLoaded = true
	DarkMeter:checkCombatLogOthers()
end

-- save settings on logout / reloadui
function DarkMeter:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	self.settings.mainFormLocation = UI.MainForm.form:GetLocation():ToTable()
	return DMUtils.cloneTable(self.settings)
end


-- add a stat to track into the mainform
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

-- remove a stat to track into the mainform
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
-- slash commands
----------------------------------

function DarkMeter:slashHandler(cmd, arg)
	if DarkMeter.slashCommands[arg] ~= nil then
		DarkMeter.slashCommands[arg](self)
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "List of available commands:", "DarkMeter")
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "-----------------------------", "DarkMeter")
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "toggle (shows or hides the main window)", "DarkMeter")
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "restore (restore defaults settings)", "DarkMeter")
	end
end

DarkMeter.slashCommands = {}

function DarkMeter.slashCommands:toggle()
	self:toggle()
end

function DarkMeter.slashCommands:restore()
	self.settings = self.defaults

	-- hides every other window
	UI.PlayerDetails:hide()
	UI.ReportForm:hide()
	UI.ResetForm:hide()
	UI.SelectFight:hide()
	UI.SettingsForm:hide()

	UI.MainForm.form:MoveToLocation(self.settings.mainFormLocation)
	UI.MainForm:initColumns()
	UI.MainForm:showGroupStats()
	UI.MainForm.wrapper:RecalculateContentExtents()
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

	DarkMeter.paused = true
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

	DarkMeter.paused = false
end

function DarkMeter:toggle()
	if DarkMeter.paused then
		self:resume()
		UI:show()
	else
		self:pause()
		UI:hide()
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




-- main form refresh timer
function DarkMeter:OnMainFormRefresher()
	local deltaTime = GameLib.GetGameTime() - UI.lastUpdate
	if Group:inCombat() and deltaTime >= 0.5 then
		self:updateUI()
	end
end


-- set the timer responsable to refresh the main form's monitored fight duration
function DarkMeter:startMonitoredFightTimer()
	Apollo.StartTimer("MonitoredFightTimer")
end

-- destroy the monitored fight timer
function DarkMeter:stopMonitoredFightTimer()
	Apollo.StopTimer("MonitoredFightTimer")
end


-- function called by the monitored fight's timer to update the monitored fight duration
function DarkMeter:OnMonitoredFightTimer()
	local monitoredFight = nil
	if self.settings.overall and overallFight then
		monitoredFight = overallFight
	elseif not self.specificFight and currentFight then
		monitoredFight = currentFight
	elseif self.specificFight then
		monitoredFight = self.specificFight
	end

	if monitoredFight then
		local mf = monitoredFight:duration()
		local text = string.format("%.1d:%.2d:%.2d", mf/(60*60), mf/60%60, mf%60)
		UI.MainForm.fightTimer:SetText(text)
	end
end


----------------------------------
-- update group
----------------------------------

-- yet another timer to delay an action... the group is not fully loaded probably on the worldchange event trigger
function DarkMeter:delayedUpdateGroup()
	ApolloTimer.Create(0.3, false, "updateGroup", self)
end

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
			DarkMeter:stopAllFights()
		end
	end
	CombatUtils:updateCurrentFight()
end


----------------------------------
-- handle pvp instances
----------------------------------

-- register if a player is inside a pvp match
function DarkMeter:OnMatchEntered()
	self:updateGroup()
	self.playerInPvPMatch = DMUtils.playerInPvPMatch()
end

-- archives if the player leaves before the end of the match
function DarkMeter:OnMatchExited()
	if self.playerInPvPMatch then
		self.playerInPvPMatch = DMUtils.playerInPvPMatch()
		DarkMeter:stopAllFights()
	end
	self:updateGroup()
end

-- ensure that the pvp match is archived correctly at the end of the fight
function DarkMeter:OnMatchFinished()
	-- DarkMeter:stopAllFights()

	-- what an ugly workaround, but some combat events gets processed AFTER the match has finished...
	-- this will generate another fight lasting a fraction of a second, to prevent this I'll delay the stopallfights function
	ApolloTimer.Create(0.3, false, "stopAllFights", self)
end


----------------------------------
-- combat log utils
----------------------------------

CombatUtils.Events = {}
CombatUtils.formattedSkills = {}

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
	-- list of last 10 processed combat events, for development
	table.insert(CombatUtils.Events, 1, e)
	-- CombatUtils.Events[11] = nil
	if _G.DarkMeter.Development then
		SendVarToRover("CapturedEvents", CombatUtils.Events)
		SendVarToRover("lastLogEvent", e)
	end


	-- force combat start if player is in combat (fix for a reloadui when in combat)
	if Group.members[GameLib.GetPlayerUnit():GetId()].inCombat then
		DarkMeter:startCombatIfNecessary()
	end

	customValues = customValues or {}

	-- initialize common useful values
	local event = {
		state = e.eCombatResult,
		multihit = false,
		damage = (e.nDamageAmount or 0) + (e.nAbsorption or 0) + (e.nShield or 0),
		typology = "undefined",
		heal = (e.nHealAmount or 0),
		overheal = (e.nOverheal or 0),
		owner = e.unitCasterOwner,
		targetkilled = e.bTargetKilled,
		selfDamage = false,
		dot = e.bPeriodic
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
		if event.dot then
			event.name = e.splCallingSpell:GetName() .. " (dot)"
		else
			event.name = e.splCallingSpell:GetName()
		end
	end

	-- add pet info
	if event.owner then
		event.ownerId = event.owner:GetId()
		event.ownerName = event.owner:GetName()
	end

	event.__index = event
	setmetatable(customValues, event)
	
	-- checks if the skill is a self damaging skill
	if customValues.typology == "damage" and customValues.target and customValues.caster and customValues.targetId == customValues.casterId then
		customValues.selfDamage = true
	end

	if _G.DarkMeter.Development then
		table.insert(CombatUtils.formattedSkills, 1, customValues)
		-- CombatUtils.formattedSkills[11] = nil
		SendVarToRover("formattedSkill", customValues)
		SendVarToRover("10formattedSkills", CombatUtils.formattedSkills)
	end
	return customValues
end

-- add the caster or the target of a skill, if a group member is involved (is the caster or the target)
function CombatUtils:addUnitsToFight(skill)
	for _, fight in pairs({currentFight, overallFight}) do

		-- process a skill's caster
		if skill.caster then
			-- if the target is a group member
			if Group.members[skill.casterId] ~= nil then
				fight:addUnit(skill.caster, true)
			-- if the caster is a pet and the owner is a group member
			elseif skill.ownerId ~= nil and Group.members[skill.ownerId] ~= nil then
				-- add owner
				fight:addUnit(skill.owner, true)
				-- add pet
				fight.groupMembers[skill.ownerId]:addPet(skill.caster)
			
			-- the caster is an enemy (this is not completely true, let's take the case where another friendly player heals you and he is not grouped with you, he will be added as an enemy but since his contribution to your damage received is 0, he'll never appear among the enemies)
			else
				-- if is an enemy's pet
				if skill.ownerId ~= nil then
					-- add pet's owner
					fight:addUnit(skill.owner, false)
					-- add pet
					fight.enemies[skill.ownerId]:addPet(skill.caster)
				-- if the caster is a common enemy
				else
					fight:addUnit(skill.caster, false)
				end

			end
		end

		-- process skill's target
		if skill.target then
			local targetOwner = skill.target:GetUnitOwner()
			-- if the target is a group member
			if Group.members[skill.targetId] ~= nil then
				-- add the target to the fight's members
				fight:addUnit(skill.target, true)
			
			-- if the target is a pet of a group member, add both
			elseif targetOwner and Group.members[targetOwner:GetId()] then
				-- add pet's owner
					fight:addUnit(targetOwner, true)
					-- add pet
					fight.groupMembers[targetOwner:GetId()]:addPet(skill.target)

			-- if the caster or the caster's owner is not a group member, then the spell's target is an
			else
				-- if is an enemy's pet
				if targetOwner then
					-- add pet's owner
					fight:addUnit(targetOwner, false)
					-- add pet
					fight.enemies[targetOwner:GetId()]:addPet(skill.target)
				-- if the caster is a common enemy
				else
					fight:addUnit(skill.target, false)
				end
			end
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
	-- TODO skill.targetKilled will probably add the skill and unit only to the overall fight
	-- as the currentFight should already be archived
	if Group:inCombat() or skill.targetkilled then			-- usually the combat ends before the last damage gets processed
		-- process the skill only if the a group member or a group member's pet is involved
		if Group.members[skill.casterId] ~= nil or ( skill.ownerId ~= nil and Group.members[skill.ownerId] ~= nil ) or (skill.targetId ~= nil and Group.members[skill.targetId] ~= nil) then
			CombatUtils:addUnitsToFight(skill)								-- adds this unit to the currentFight if not already added
			CombatUtils:addSkillToUnit(skill)									-- adds the casted skill to the caster
			CombatUtils:updateCurrentFight()
			UI.needsUpdate = true
			DarkMeter:updateUI()			
		end
	end
end


-- instantiate a new Fight instance to create the currentFight if necessary
function DarkMeter:startCombatIfNecessary()
	if DarkMeter.paused then return end

	-- instantiate a new fight if out of combat
	if not currentFight then
		currentFight = Fight:new()
		currentFight.forcedName = "Current fight"

		-- set pvpMatch to true if necessary
		-- I test directly against a DMUtils.playerInPvPMatch() in case the player has reloaded the ui after entering the pvp match
		if (self.playerInPvPMatch or DMUtils.playerInPvPMatch() ) and self.settings.mergePvpFights then
			currentFight.pvpMatch = true
			-- force current fight's name to a generic "PVP match" with local time
			local time = GameLib.GetLocalTime()
			local matchName = "PvP Match (" .. time.nHour .. ":" .. time.nMinute .. ")"

			-- try to set current fight's name to the specific match's type (es. "Arena (10:11)")
			local matchType = MatchingGame:GetMatchingGameType()
			for name, code in pairs(MatchingGame.MatchType) do
				if code == matchType then
					matchName = name .. " (" .. time.nHour .. ":" .. time.nMinute .. ")"
				end
			end

			currentFight.forcedName = matchName
		end

	elseif currentFight:paused() then
		currentFight:continue()
	end
	if not overallFight then
		overallFight = Fight:new()
		overallFight.forcedName = "Overall fights"
	elseif overallFight:paused() then
		overallFight:continue()
	end

	self:startMonitoredFightTimer()
end


function DarkMeter:stopAllFightsIfNotInCombat()
	if not Group:inCombat() then
		DarkMeter:stopAllFights()
	end
end


-- archive currentFight and sets it to nil
function DarkMeter:stopAllFights()
	if overallFight ~= nil then
		overallFight:stop()
	end
	if currentFight ~= nil then
		currentFight:stop()
		
		-- if the player is in a pvp match and has chosen to treat the entire pvp match as an unique fight
		-- opposite condition... need to check if the player is not in pvp or is in pvp but doesn't want to treat the match as an entire fight to reset the data
		if not self.playerInPvPMatch or not self.settings.mergePvpFights then
			if not currentFight.pvpMatch then
				currentFight.forcedName = nil	
			end
			
			-- check that the fight has at least a member to prevent inserting fights when nothing happens (a mob that aggro then evades without hitting)
			if DMUtils.tableLength(currentFight.groupMembers) > 0 then
				table.insert(fightsArchive, 1, DMUtils.cloneTable(currentFight))
			end
			currentFight = nil	
		end
	end

	-- after 0.6 sec call an updateUI to check if the interface needs an update
	ApolloTimer.Create(0.6, false, "updateUI", DarkMeter)
	DarkMeter:stopMonitoredFightTimer()
end

-- used to add dummy testing data to the archived fights
function DarkMeter:addFightToArchive(fight)
	table.insert(fightsArchive, 1, DMUtils.cloneTable(fight))
end


----------------------------------
-- on combat log events
----------------------------------


-- This event fires whenever a normal attack lands
function DarkMeter:OnCombatLogDamage(e)
	if _G.DarkMeter.Development then
		Print("DAMEIG!")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		typology = "damage"
	})
	CombatUtils:processFormattedSkill(skill)
end

-- This event fires whenever an attack gets a Multi-Hit proc.
function DarkMeter:OnCombatLogMultiHit(e)
	if _G.DarkMeter.Development then
		Print("MultiHit!")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		multihit = true,
		typology = "damage"
	})
	CombatUtils:processFormattedSkill(skill)
end

function DarkMeter:OnCombatLogHeal(e)
	if _G.DarkMeter.Development then 
		Print("Heal") 
	end
	local skill = CombatUtils:formatCombatAction(e, {
		typology = "healing"
	})
	CombatUtils:processFormattedSkill(skill)
end

function DarkMeter:OnCombatLogMultiHeal(e)
	if _G.DarkMeter.Development then
		Print("MultiHeal!")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		multihit = true,
		typology = "healing"
	})
	CombatUtils:processFormattedSkill(skill)
end

function DarkMeter:OnCombatLogDeflect(e)
	if _G.DarkMeter.Development then
		Print("deflect...")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		typology = "damage"
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
		typology = "damage"
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
				typology = "healing",
				
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
		skill.typology = "ccEffect"
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
		typology = "damage",
		damage = e.nShield,		-- for this event, the damages, being completely absorbed, are equal to the shield drained
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
		name = "Falling damage",
		typology = "damage"
	})
	CombatUtils:processFormattedSkill(skill)
end

-- This event fires whenever an attack is completely absorbed by shields.
-- TODO check this event if gets processed normally, as there's no documentation on Houston
function DarkMeter:OnCombatLogDamageShields(e)
	if _G.DarkMeter.Development then
		Print("DAMEIG! Absorbed!")
	end
	local skill = CombatUtils:formatCombatAction(e, {
		typology = "damage",
		damage = e.nShield,		-- for this event, the damages, being completely absorbed, are equal to the shield drained
	})
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

	-- updates MainForm
	if self.settings.overall then
		-- show overall data
		if overallFight then
			UI:showDataForFight(overallFight)
		end
	else
		-- if the user is not inspecting a specific fight, show currentFight
		if not self.specificFight then
			-- if the current fight is nil there are two cases
			if not currentFight then
				-- 1) the fight has just ended and the form need an update because tha last one was few milliseconds before the end of the fight
				-- in this case, refresh with the last archived fight
				if #fightsArchive > 0 then
					UI:showDataForFight(fightsArchive[1])
				-- 2) the updateUI has been called with no fights at all
				else
					UI.MainForm:clear()
				end
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