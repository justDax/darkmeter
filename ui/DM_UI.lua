
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
    SelectFight:init(self.xmlDoc)
    SettingsForm:init(self.xmlDoc)
    PlayerDetails:init(self.xmlDoc)

    -- TODO the window popping on the lens is nice but I have two problems to deal with:
    -- clicking on the selectfight form allow the user to drag the addon
    -- if the addons is placed on the top part of the screen the popup appears outsive and not completely visible

    -- local inspectBtn = MainForm.form:FindChild("Header"):FindChild("InspectFight")
    -- SelectFight.form = Apollo.LoadForm(self.xmlDoc, "SelectFightForm", inspectBtn, SelectFight.controls)

    -- for now I'll just place the form at the center of the screen, I'l implement a better popup in the future
    
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


  self.__index = self
  return setmetatable(row, self)
end

function Row:update(options)
  local rankWnd = self.bar:FindChild("Rank")
  local moveLeft = 0

  if DarkMeter.settings.showRanks then
    if options.rank then
      rankWnd:Show(true)
      rankWnd:SetText(tostring(options.rank))
      if options.rank == 1 then
        rankWnd:SetTextColor(ApolloColor.new("ffcec313"))
      elseif options.rank == 2 then
        rankWnd:SetTextColor(ApolloColor.new("ffc3d5dc"))
      elseif options.rank == 3 then
        rankWnd:SetTextColor(ApolloColor.new("ff783d1d"))
      else
        rankWnd:SetTextColor(ApolloColor.new("ffffffff"))
      end
    elseif options.rank == false then
      rankWnd:Show(false)
    end
  else
    rankWnd:Show(false)
    moveLeft = moveLeft + 25
  end

  if DarkMeter.settings.showClassIcon then
    if options.icon then
      local icon = self.bar:FindChild("Icon")
      icon:Show(true)
      icon:SetSprite(options.icon)
      icon:SetAnchorOffsets( (30 - moveLeft), math.ceil((DarkMeter.settings.rowHeight - 20) / 2), (50 -  moveLeft), (math.ceil((DarkMeter.settings.rowHeight - 20) / 2) + 20))
    elseif options.icon == false then
      self.bar:FindChild("Icon"):Show(false)
    end
  else
    self.bar:FindChild("Icon"):Show(false)
    moveLeft = moveLeft + 25
  end

  if options.name then
    local nameWindow = self.bar:FindChild("Name")
    nameWindow:Show(true)
    nameWindow:SetText(options.name)
    local left, top, right, bot = nameWindow:GetAnchorOffsets()
    nameWindow:SetAnchorOffsets( (55 - moveLeft), top, right, bot)
  elseif options.name == false then
    self.bar:FindChild("Name"):Show(false)
  end

  if options.background then
    local bgWindow = self.bar:FindChild("Background")
    bgWindow:Show(true)
    bgWindow:SetBGColor(options.background)
  elseif options.background == false then
    self.bar:FindChild("Background"):Show(false)
  end

  if options.text then
    local dataWindow = self.bar:FindChild("Data")
    dataWindow:Show(true)
    dataWindow:SetText(options.text)
  elseif options.text == false then
    self.bar:FindChild("Data"):Show(false)
  end

  -- width
  if options.width then
    local bg = self.bar:FindChild("Background")
    local newLocation = bg:GetLocation():ToTable()
    newLocation.nOffsets[3] = options.width
    bg:MoveToLocation(WindowLocation.new( newLocation ) )
  end


  -- sets unit reference
  if options.unit and options.stat then
    self.bar:SetData({
      unit = options.unit,
      stat = options.stat
    })
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
  if UI.needsUpdate and ( GameLib.GetGameTime() - UI.lastUpdate ) > 0.3 then
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
UI.SelectFight = SelectFight
UI.SettingsForm = SettingsForm
UI.PlayerDetails = PlayerDetails
UI.Row = Row


Apollo.RegisterPackage(UI, "DarkMeter:UI", 1, {"DarkMeter:Utils", "DarkMeter:Fight"})