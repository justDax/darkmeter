
-------------------------------------------------------------
-- Interface class
-------------------------------------------------------------
-- this class is responsable for the rapresentation of the data to the user
-------------------------------------------------------------

local UI = {}
local DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage
local Fight = Apollo.GetPackage("DarkMeter:Fight").tPackage
local DarkMeter = nil

UI.minColWidth = 50

local MainForm = Apollo.GetPackage("DarkMeter:MainForm").tPackage             -- main form (the main window with all the bars etc..) 
local ResetForm = Apollo.GetPackage("DarkMeter:ResetForm").tPackage            -- prompt reset data form and all the correlated functions
UI.lastFight = nil           -- contains reference to the last merged fight
local ReportForm = Apollo.GetPackage("DarkMeter:ReportForm").tPackage           -- form used to report the addon data into ingame chat
local DeathRecapForm = Apollo.GetPackage("DarkMeter:DeathRecapForm").tPackage           -- form used to report a player's death
local SelectFight = Apollo.GetPackage("DarkMeter:SelectFight").tPackage           -- form to select which fight inspect
local SettingsForm = Apollo.GetPackage("DarkMeter:SettingsForm").tPackage
local PlayerDetails = Apollo.GetPackage("DarkMeter:PlayerDetails").tPackage

function UI:init()
  DarkMeter = Apollo.GetAddon("DarkMeter")

  self.needsUpdate = false
  self.lastUpdate = GameLib.GetGameTime()
  -- load our form file
  self.xmlDoc = XmlDoc.CreateFromFile("DarkMeter.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-- callback on xml loaded
function UI:OnDocLoaded()
  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then

    -- adds errors if any dependency has not been initialized yet

    if not MainForm then
      Apollo.AddAddonErrorText(DarkMeter, "MainForm is not loaded.")
    end
    if not ResetForm then
      Apollo.AddAddonErrorText(DarkMeter, "ResetForm is not loaded.")
    end
    if not ReportForm then
      Apollo.AddAddonErrorText(DarkMeter, "ReportForm is not loaded.")
    end
    if not SelectFight then
      Apollo.AddAddonErrorText(DarkMeter, "SelectFight is not loaded.")
    end
    if not SettingsForm then
      Apollo.AddAddonErrorText(DarkMeter, "SettingsForm is not loaded.")
    end

    MainForm:init(self.xmlDoc)
    ResetForm:init(self.xmlDoc)
    ReportForm:init(self.xmlDoc)
    DeathRecapForm:init(self.xmlDoc)
    SelectFight:init(self.xmlDoc)
    SettingsForm:init(self.xmlDoc)
    PlayerDetails:init(self.xmlDoc)
    
    if MainForm.initialLocation then -- location loaded from saved settings
      MainForm.form:MoveToLocation(WindowLocation.new(MainForm.initialLocation))
    end
    MainForm:initColumns()
    MainForm.wrapper:RecalculateContentExtents()
    MainForm.content:SetBGOpacity(DarkMeter.settings.bgOpacity/100)
  end
end



-------------------------------------------------------------
-- Row class
-------------------------------------------------------------
local Row = {}

function Row:new(parent, i)
  if not parent then
    Apollo.AddAddonErrorText(DarkMeter, "Row cannot have a nil prent.")
  end
  local row = {}
  row.bar = Apollo.LoadForm(UI.xmlDoc, "BarForm", parent, MainForm.controls)
  if not row.bar then
    Apollo.AddAddonErrorText(DarkMeter, "Cannot load BarForm from the xml file.")
  end
  local rowHeight = DarkMeter.settings.rowHeight
  local top = (1 * rowHeight ) * (i - 1) + 1;
  row.bar:SetAnchorOffsets( 1, top, -1, (top + rowHeight ) )
  row.index = i

  -- set row elements references and last used values to prevent updating elements with the same values
  row.currentHeight = DarkMeter.settings.rowHeight

  row.rank = row.bar:FindChild("Rank")
  row.rankVisible = false -- the rank is visible initially... but I set it to false to let the update function set the rank text correctly
  row.lastRank = 0

  row.icon = row.bar:FindChild("Icon")
  row.iconLeft = row.icon:GetAnchorOffsets() -- this is the initial left offset value for the icon and must not be changed, is for reference only
  row.iconMoveLeft = row.iconLeft
  row.iconVisible = true
  row.lastIcon = ""

  row.name = row.bar:FindChild("Name")
  row.nameVisible = true
  row.strName = row.name:GetText()
  row.nameLeft = row.name:GetAnchorOffsets() -- this is the initial left offset value for the icon and must not be changed, is for reference only
  row.nameMoveLeft = row.nameLeft

  row.bg = row.bar:FindChild("Background")
  row.bgVisible = true
  row.lastBg = ApolloColor.new("99555555")

  row.text = row.bar:FindChild("Data")
  row.lastText = row.text:GetText()
  row.textVisible = true

  row.currentWidth = false   -- set to false because the width needs to be initialized and depends on the form width/columns

  row.currentData = {}

  -- end variables

  -- center the icon vertically
  row.icon:SetAnchorOffsets( row.iconMoveLeft, math.ceil((DarkMeter.settings.rowHeight - 20) / 2), (row.iconMoveLeft + 20), (math.ceil((DarkMeter.settings.rowHeight - 20) / 2) + 20))

  self.__index = self
  return setmetatable(row, self)
end

function Row:update(options)
  local moveLeft = 0
  -- auto update row height if the height settings has been changed
  local heightChanged = false
  if self.currentHeight ~= DarkMeter.settings.rowHeight then
    local left, top, right, bot = self.bar:GetAnchorOffsets()
    top = (1 * DarkMeter.settings.rowHeight ) * (self.index - 1) + 1;
    self.bar:SetAnchorOffsets( left, top, right, (top + DarkMeter.settings.rowHeight))
    self.currentHeight = DarkMeter.settings.rowHeight
    heightChanged = true
  end
  
  -- RANK
  if DarkMeter.settings.showRanks and options.rank ~= false then
    if not self.rankVisible then
      self.rank:Show(true)
      self.rankVisible = true
    end
    -- update rank only if it changes
    if self.lastRank ~= options.rank and options.rank then
      self.rank:SetText(tostring(options.rank))
      
      if options.rank == 1 then
        self.rank:SetTextColor(ApolloColor.new("ffcec313"))
      elseif options.rank == 2 then
        self.rank:SetTextColor(ApolloColor.new("ffc3d5dc"))
      elseif options.rank == 3 then
        self.rank:SetTextColor(ApolloColor.new("ff783d1d"))
      else
        self.rank:SetTextColor(ApolloColor.new("ffffffff"))
      end
      self.lastRank = options.rank
    end
  else
    if self.rankVisible then
      self.rank:Show(false)
      self.rankVisible = false
    end
    moveLeft = moveLeft + 20
  end

  
  -- ICON
  if DarkMeter.settings.showClassIcon and options.icon ~= false then
    if not self.iconVisible then
      self.icon:Show(true)
      self.iconVisible = true
    end
    -- set fallback icon when the correct icon for this unit/pet is not available
    if options.icon == nil then options.icon = "BK3:sprHolo_Friends_Single" end
    -- update icon if has changed
    if self.lastIcon ~= options.icon then
      self.icon:SetSprite(options.icon)
      self.lastIcon = options.icon
    end
    -- update the position only if the moveLeft var has changed, this happens after unchecking the show ranks options
    if self.iconMoveLeft ~= (self.iconLeft - moveLeft) or heightChanged then
      self.icon:SetAnchorOffsets( (self.iconLeft - moveLeft), math.ceil((DarkMeter.settings.rowHeight - 20) / 2), ((self.iconLeft + 20) -  moveLeft), (math.ceil((DarkMeter.settings.rowHeight - 20) / 2) + 20))
      self.iconMoveLeft = moveLeft
    end
  else
    if self.iconVisible then
      self.icon:Show(false)
      self.iconVisible = false
    end
    moveLeft = moveLeft + 20
  end

  -- NAME
  if options.name then
    if not self.nameVisible then
      self.name:Show(true)
      self.nameVisible = true
    end
    -- set name text
    if self.strName ~= options.name then
      self.name:SetText(options.name)
      self.strName = options.name
    end
    -- move name window if the showranks or showicons options has changed
    if self.nameMoveLeft ~= (self.nameLeft - moveLeft) then
      local left, top, right, bot = self.name:GetAnchorOffsets()
      self.name:SetAnchorOffsets( (self.nameLeft - moveLeft), top, right, bot)
      self.nameMoveLeft = moveLeft
    end
  elseif self.nameVisible then
    self.name:Show(false)
    self.nameVisible = false
  end


  -- BACKGROUND
  if options.background then
    if not self.bgVisible then
      self.bg:Show(true)
    end

    if self.lastBg ~= options.background then
      self.bg:SetBGColor(options.background)
      self.lastBg = options.background
    end
  elseif self.bgVisible then
    self.bg:Show(false)
    self.bgVisible = false
  end


  -- TEXT
  if options.text then

    if not self.textVisible then
      self.text:Show(true)
      self.textVisible = true
    end

    if self.lastText ~= options.text then
      self.text:SetText(options.text)
      self.lastText = options.text
    end
  elseif self.textVisible then
    self.text:Show(false)
    self.textVisible = false
  end

  -- WIDTH
  if options.width then
    if self.currentWidth ~= options.width then
      local left, top, right, bot = self.bg:GetAnchorOffsets()
      self.bg:SetAnchorOffsets( left, top, options.width, bot)
      self.currentWidth = options.width
    end
  end

  -- sets unit reference
  local newData = options.unit
  
  -- set data only if the id has changed or the name has changed and the unit is a pet
  if newData and ( self.currentData.id ~= newData.id or (newData.pet and self.currentData.name ~= newData.name ))  then
    self.bar:SetData(newData)
    self.currentData = newData
  end
  
end



-------------------------------------------------------------
-- Misc functions
-------------------------------------------------------------

-- hides main window
function UI:show()
  MainForm.visible = true
  MainForm.form:Show(true)
end

-- hides main window
function UI:hide()
  MainForm.visible = false
  MainForm.form:Show(false)
end

-- ask the user to reset the data with a dialog
function UI:promptResetData()
  -- 1 - always reset the data
  if DarkMeter.settings.resetMapChange == 1 then
    UI:resetData()
  -- 2 - ask the user
  elseif DarkMeter.settings.resetMapChange == 2 then
    UI.ResetForm:show()
  end
  -- 3 - never reset data
end

-- if the user confirms to reset the data
function UI:resetData()
  DarkMeter:resetData()
  MainForm:clear()
  MainForm.fightTimer:SetText("-")
  UI.lastFight = nil
end



-- shows the desired data for the given fights
function UI:showDataForFight(fight)
  UI.lastFight = fight
  
  -- limit updates, updating the ui on every combatlog event kills fps
  if UI.needsUpdate and ( GameLib.GetGameTime() - UI.lastUpdate ) >= 0.3 then
    MainForm:showGroupStats()

    -- updates PlayerDetails if opened
    if UI.PlayerDetails.visible then
      local id = UI.PlayerDetails.unit.id
      if UI.lastFight.groupMembers[id] then
        UI.PlayerDetails:setPlayer(UI.lastFight.groupMembers[id])
      end
    end

    UI.needsUpdate = false
  end
end



UI.MainForm = MainForm
UI.ResetForm = ResetForm
UI.ReportForm = ReportForm
UI.DeathRecapForm = DeathRecapForm
UI.SelectFight = SelectFight
UI.SettingsForm = SettingsForm
UI.PlayerDetails = PlayerDetails
UI.Row = Row


Apollo.RegisterPackage(UI, "DarkMeter:UI", 1, {"DarkMeter:Utils", "DarkMeter:Fight"})