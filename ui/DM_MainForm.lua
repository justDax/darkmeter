-- TODO
-- This requires a lot of work to be detached from the UI file

-------------------------------------------------------------
-- MainForm Controls
-------------------------------------------------------------
local MainForm = {}
MainForm.controls = {}
MainForm.rows = {}              -- list with all the rows inside the addon window
MainForm.cols = {}

local DarkMeter
local UI
local DMUtils
local Fight


-- initialize main window
function MainForm:init(xmlDoc)
  UI = Apollo.GetPackage("DarkMeter:UI").tPackage
  Fight = Apollo.GetPackage("DarkMeter:Fight").tPackage
  DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage
  DarkMeter = Apollo.GetAddon("DarkMeter")

  MainForm.form = Apollo.LoadForm(xmlDoc, "DarkMeterForm", nil, MainForm.controls)
  -- set main parts
  self.header = self.form:FindChild("Header")
  self.wrapper = self.form:FindChild("ContentWrapper")
  self.content = self.wrapper:FindChild("Content")
  self.mainCol = self.content:FindChild("MainCol")
  self.footer = self.form:FindChild("Footer")

  -- header parts
  self.title = self.header:FindChild("Title")
  self.tracked = self.header:FindChild("Tracked")

  MainForm:initColumns()
  self:setTracked()
  UI:show()
end



-- closes the main window, all subwindows and remove event listeners
function MainForm.controls:OnCancel()
  Print("TODO: Close window and pause the addon")
end


-- shows the dialog to confirm data reset
function MainForm.controls:OnResetData()
  UI.ResetForm:show()
end

-- when resizing window
function MainForm.controls:OnResize()
  MainForm:initColumns()
  MainForm:showGroupStats()
end

-- drag window functions

function MainForm.controls:OnStartDrag()
  MainForm.dragging = true
  
  local mousePos = Apollo.GetMouse()
  MainForm.controls.mousePosition = {
    x = mousePos.x,
    y = mousePos.y
  }

  local x, y = MainForm.form:GetAnchorOffsets()
  MainForm.controls.startPosition = {
    x = x,
    y = y
  }
end

function MainForm.controls:OnStopDrag()
  MainForm.dragging = false
end

function MainForm.controls:OnMouseMove()
  if MainForm.dragging then
    local mousePos = Apollo.GetMouse()
    
    local newOffsetX = mousePos.x - MainForm.controls.mousePosition.x + MainForm.controls.startPosition.x
    local newOffsetY = mousePos.y - MainForm.controls.mousePosition.y + MainForm.controls.startPosition.y

    MainForm.form:SetAnchorOffsets(newOffsetX, newOffsetY, (newOffsetX + MainForm.form:GetWidth()), (newOffsetY + MainForm.form:GetHeight()) )
  end
end

-- end drag window functions




-- popup to select which fight the user wanna see (overall, current and a list of the past fights)
function MainForm.controls:OnSelectFight()
  UI.SelectFight:show()
end

-- popup to edit the general settings
function MainForm.controls:OnEditSettings()
  UI.SettingsForm:show()
end

-- popup to report the inspected fight
function MainForm.controls:OnReportFight()
  UI.ReportForm:show()
end





-------------------------------------------------------------
-- Display Utility functions
-------------------------------------------------------------


-- mainform columns initialization
-- sets title, creates columns, prepare columns variables...
function MainForm:initColumns()
  self.contentWidth = self.content:GetWidth()
  self.colWidth = {}

  local stats = DarkMeter.settings.selectedStats
  if not stats then
    Apollo.AddAddonErrorText(DarkMeter, "Cannot initialize columns, invalid value for stats variable.")
  end

  -- for each selected stats initialize a column
  for i = 1, #stats do
    if self.cols[i] == nil then
      self.cols[i] = {}
    end
    -- sets the column with the right form template
    if not self.cols[i].column then
      self.cols[i].column = Apollo.LoadForm(UI.xmlDoc, "ColTemplate", MainForm.content, MainForm.controls)
    end

    local totalWidth = self.contentWidth
    local mainColWidth = (totalWidth - (#stats -1) * UI.minColWidth )
    local otherColsWidth = UI.minColWidth
    local colWidth = i == 1 and mainColWidth or otherColsWidth
    local left = i == 1 and 0 or (mainColWidth + (i - 2) * otherColsWidth )
    local rowsHeight = self.cols[i].rows ~= nil and (21 * (#self.cols[i].rows + 1) ) or 0
    local colHeight = math.max(MainForm.wrapper:GetHeight(), rowsHeight)

    if i == 1 then -- set container position only once
      local x, y = MainForm.content:GetAnchorOffsets()
      MainForm.content:SetAnchorOffsets(x, y, (x + MainForm.wrapper:GetWidth() - 13), (y + colHeight) )
    end

    local newLocation = WindowLocation.new({ fPoints = {0, 0, 0, 0}, nOffsets = {left, 0, (left + colWidth), colHeight} })


    self.cols[i].column:MoveToLocation(newLocation)

    -- save current col width
    self.colWidth[i] = self.cols[i].column:GetWidth()
    -- create column title
    if self.cols[i].header == nil then
      self.cols[i].header = UI.Row:new(self.cols[i].column, 1)
    end
    
    -- update title with the correct infos
    MainForm.cols[i].header:update({
      icon = false,
      title = i == 1 and "Name" or false,
      background = false,
      text = i == 1 and DMUtils:titleForStat(stats[i]) or DMUtils:titleForStat(stats[i], true),
      width = self.colWidth[i]
    })
  end
    
  -- delete no longer needed columns
  for i = #stats + 1, #self.cols do
    if self.cols[i].column then
      self.cols[i].column:Destroy()
      self.cols[i] = nil
    end
  end
end


-- returns the options to update a single bar texts, icons, color, data etc...
function MainForm:formatRowOptions(unit, tempFight, column, maxVal, rank)
  local stats = DarkMeter.settings.selectedStats
  local options = {}

  -- set rank
  if rank ~= nil and column == 1 then
    options.rank = rank
  else
    options.rank = false
  end

  -- set icon
  if column == 1 then
    options.icon = DMUtils:iconForClass(unit)
  else
    options.icon = false
  end

  -- set background
  local bg = {0.3, 0.3, 0.3}
  if DMUtils.classes[unit.classId] ~= nil then
    bg = DMUtils.classes[unit.classId].color
  end
  options.background = ApolloColor.new(bg[1], bg[2], bg[3], 0.3)

  -- set name
  if column == 1 then
    options.name = unit.name
    if unit.pet then
      local owner = tempFight.groupMembers[unit.ownerId]
      if owner then
        options.name = options.name .. " (" .. owner.name .. ")"
      end
    end
  else
    options.name = false
  end
  --| update bar data | --
  
  local i = column

  

  if unit[stats[i]] == nil then
    Apollo.AddAddonErrorText(DarkMeter, "Unit class has no method: " .. stats[i])
  elseif tempFight[stats[i]] == nil then
    Apollo.AddAddonErrorText(DarkMeter, "Fight class has no method: " .. stats[i])
  else
    local value = unit[stats[i]](unit)
    
    -- sets bar text
    local num = DMUtils.formatNumber( value, 1 )
    if column == 1 and value > 0 then
      local percent = DMUtils.roundToNthDecimal( value / tempFight[stats[i]](tempFight) * 100, 1 )
      options.text = num .. " (" .. percent .. "%)"
    else
      options.text = num
    end
    -- sets bar width
    if maxVal > 0 then
      local percentage = value / maxVal * 100
      options.width = math.floor( self.colWidth[i] * percentage / 100 )
    else
      options.width = 0
    end
    
  end

  --| end update bar data | --

  return options
end

-------------------------------------------------------------
-- MainForm Display functions
-------------------------------------------------------------

function MainForm:clear()
  if MainForm.cols then
    for index = 1, #MainForm.cols do
      
      if MainForm.cols[index].rows then
        for i = 1, #MainForm.cols[index].rows do
          MainForm.cols[index].rows[i].bar:Destroy()
          MainForm.cols[index].rows[i] = nil
        end
      end

    end
  end
end

-- sets the current tracked fight
function MainForm:setTracked()
  local text = ""
  if DarkMeter and DarkMeter.loaded then
    if DarkMeter.settings.overall then
      text = "- Overall"
    elseif not DarkMeter.specificFight then
      text = "- Current fight"
    else
      text = "- Fight: " .. DarkMeter.specificFight:name()
    end
    MainForm.tracked:SetText(text)
  end
end

-- used to display the selected stats of the lastFight
function MainForm:showGroupStats()
  if UI.lastFight then
    local stats = DarkMeter.settings.selectedStats

    -- sort all group members by the main stat being monitored
    local orderedUnits = UI.lastFight:orderMembersBy(stats[1])
    -- local maxVal = orderedUnits[1][stats[1]](orderedUnits[1]) -- the first (highest) value of the stats passes, used to calculate bar width for others party members
    
    for index = 1, #stats do
      -- calculate max stat among group members
      local maxVal = 0
      for i = 1, #orderedUnits do
        maxVal = math.max(maxVal, orderedUnits[i][stats[index]](orderedUnits[i]) )
      end

      MainForm.cols[index] = MainForm.cols[index] or {}
      MainForm.cols[index].rows = MainForm.cols[index].rows or {}

      for i = 1, #orderedUnits do
        if MainForm.cols[index].rows[i] == nil then
          MainForm.cols[index].rows[i] = UI.Row:new(MainForm.cols[index].column, i + 1)
          MainForm:initColumns() --  a new row has been added and I need to recalculate col heights
        end
        local options = MainForm:formatRowOptions(orderedUnits[i], UI.lastFight, index, maxVal, i)
        MainForm.cols[index].rows[i]:update(options)
      end

    end

    -- delete not needed rows from cols
    for i = 1, #MainForm.cols do
      if #orderedUnits < #MainForm.cols[i].rows then
        for index = #orderedUnits +1, #MainForm.cols[i].rows do
          MainForm.cols[i].rows[index].bar:Destroy()
          MainForm.cols[i].rows[index] = nil
          MainForm:initColumns() --  a row has been removed and I need to recalculate col heights
        end
      end
    end
  else
    MainForm:clear()
  end

  UI.lastUpdate = GameLib.GetGameTime()
end



Apollo.RegisterPackage(MainForm, "DarkMeter:MainForm", 1, {"DarkMeter:UI"})