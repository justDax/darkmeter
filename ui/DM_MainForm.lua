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
  MainForm.tooltip = Apollo.LoadForm(xmlDoc, "TooltipForm", nil, MainForm.tooltipControls)
  MainForm.tooltip:Show(false)

  -- set main parts
  self.header = self.form:FindChild("Header")
  self.wrapper = self.form:FindChild("ContentWrapper")
  self.content = self.wrapper:FindChild("Content")
  self.mainCol = self.content:FindChild("MainCol")
  self.footer = self.form:FindChild("Footer")

  -- header parts
  self.title = self.header:FindChild("Title")
  self.tracked = self.header:FindChild("Tracked")

  -- footer parts
  self.resumeBtn = MainForm.footer:FindChild("Resume")
  self.pauseBtn = MainForm.footer:FindChild("Pause")
  self.captureBtn = MainForm.footer:FindChild("CaptureMode")
  self.fightDuration = self.footer:FindChild("FightDuration")
  self.fightTimer = self.fightDuration:FindChild("Timer")

  MainForm:initColumns()
  self:setTracked()
  self:setCaptureBtn()
  UI:show()
end



-- closes the main window, all subwindows and remove event listeners
function MainForm.controls:OnCancel()
  DarkMeter:pause()
  UI:hide()
end


-- shows the dialog to confirm data reset
function MainForm.controls:OnResetData()
  UI.ResetForm:show()
end

-- when resizing window
function MainForm.controls:OnResize(wndH, wndC)
  -- prevent reinitializing everything on drag
  if wndH == wndC and not MainForm.dragging then
    MainForm:initColumns()
    MainForm:showGroupStats()
  end
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
  local width = MainForm.form:GetWidth()
  local height = MainForm.form:GetHeight()
  MainForm.controls.startPosition = {
    x = x,
    y = y,
    width = width,
    height = height
  }
end

function MainForm.controls:OnStopDrag()
  MainForm.dragging = false
end

function MainForm.controls:OnMouseMove(wndH, wndC)
  if MainForm.dragging and wndH == wndC then
    local mousePos = Apollo.GetMouse()
    
    local newOffsetX = mousePos.x - MainForm.controls.mousePosition.x + MainForm.controls.startPosition.x
    local newOffsetY = mousePos.y - MainForm.controls.mousePosition.y + MainForm.controls.startPosition.y

    MainForm.form:SetAnchorOffsets(newOffsetX, newOffsetY, (newOffsetX + MainForm.controls.startPosition.width), (newOffsetY + MainForm.controls.startPosition.height) )
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




-- popup to report the inspected fight
function MainForm.controls:OnPause()
  DarkMeter:pause()
  MainForm.pauseBtn:Show(false)
  MainForm.resumeBtn:Show(true)
end

function MainForm.controls:OnResume()
  DarkMeter:resume()
  MainForm.pauseBtn:Show(true)
  MainForm.resumeBtn:Show(false)
end


-- changes mode between always / in combat
function MainForm.controls:OnCaptureModeChange()
  DarkMeter.settings.alwaysCapture = not DarkMeter.settings.alwaysCapture
  MainForm:setCaptureBtn()
end

function MainForm:setCaptureBtn()
  if DarkMeter.settings.alwaysCapture then
    self.captureBtn:SetText("ALWAYS")
    DarkMeter:startCombatIfNecessary()
  else
    self.captureBtn:SetText("COMBAT")
    DarkMeter:stopAllFightsIfNotInCombat()
  end
end


-------------------------------------------------------------
-- Display Utility functions
-------------------------------------------------------------


-- mainform columns initialization or update
-- sets title, creates columns, prepare columns variables...
function MainForm:initColumns()
  self.contentWidth = self.content:GetWidth()
  self.colWidth = {}

  local rowHeight = DarkMeter.settings.rowHeight
  local stats = DarkMeter.settings.selectedStats
  local rowsQt = 0 
  if UI.lastFight and stats[1] then
    rowsQt = #UI.lastFight:orderMembersBy(stats[1])
  end

  -- for each selected stats initialize a column
  if stats[1] then
    -- remove the "No stats selected text"
    MainForm.content:SetText("")

    -- calculate columns widths
    local totalWidth = self.contentWidth
    local mainColWidth = (totalWidth - (#stats -1) * UI.minColWidth )
    local otherColsWidth = UI.minColWidth
    local nWrapperHeight = MainForm.wrapper:GetHeight()
    local nWrapperWidth = MainForm.wrapper:GetWidth()


    for i = 1, #stats do
      if self.cols[i] == nil then
        self.cols[i] = {}
      end
      -- sets the column with the right form template if it doesn't exists
      if not self.cols[i].column then
        self.cols[i].column = Apollo.LoadForm(UI.xmlDoc, "ColTemplate", MainForm.content, MainForm.controls)
      end

      local colWidth = i == 1 and mainColWidth or otherColsWidth

      local left = i == 1 and 0 or (mainColWidth + (i - 2) * otherColsWidth )
      local rowsHeight = ( (1 + rowHeight) * (rowsQt + 1) )
      local colHeight = math.max(nWrapperHeight, rowsHeight)

      if i == 1 then -- set container position only once
        local left, top, right, bot = MainForm.content:GetAnchorOffsets()
        MainForm.content:SetAnchorOffsets(left, top, (left + nWrapperWidth - 13), (top + colHeight) )
      end
      -- sets column position and size
      self.cols[i].column:SetAnchorOffsets(left, 0, (left + colWidth), colHeight)

      -- save current col width, used to calculate row width based on % of stat contribution
      self.colWidth[i] = self.cols[i].column:GetWidth()  
    end
    -- creates or updates columns headers
    MainForm:createTitles()

  -- if no stats are selected, just display a message
  else
    local colHeight = MainForm.wrapper:GetHeight()
    local x, y = MainForm.content:GetAnchorOffsets()
    MainForm.content:SetAnchorOffsets(x, y, (x + MainForm.wrapper:GetWidth() - 13), (y + colHeight) )
    MainForm.content:SetText("No Stats Selected")
  end
    
  -- delete no longer needed columns
  for i = #stats + 1, #self.cols do
    if self.cols[i].column then
      self.cols[i].column:Destroy()
      self.cols[i] = nil
    end
  end

end


-- update columns height, called when a row is added or removed
function MainForm:updateColsHeight()
  local nRowHeight = DarkMeter.settings.rowHeight
  local nWrapperHeight = MainForm.wrapper:GetHeight()
  local nColHeight = 0 -- set holheight here to have a reference later and set container's height

  for _, col in pairs(MainForm.cols) do
    local nRows = #col.rows
    local nTotalRowsHeight = ( (1 + nRowHeight) * (nRows + 1) )
    nColHeight = math.max(nWrapperHeight, nTotalRowsHeight)
    local left, top, right, bot = col.column:GetAnchorOffsets()
    col.column:SetAnchorOffsets(left, top, right, (top + nColHeight))
  end
  -- set columns container height
  local left, top, right, bot = MainForm.content:GetAnchorOffsets()
  MainForm.content:SetAnchorOffsets(left, top, right, (top + nColHeight) )

  self.wrapper:RecalculateContentExtents()
end

-- create or updates all titles
function MainForm:createTitles()
  for i = 1, #DarkMeter.settings.selectedStats do
    MainForm:createTitleForStat(i)
  end
end


-- create or update a specific title given a column index
function MainForm:createTitleForStat(i)
  local stats = DarkMeter.settings.selectedStats

  -- create column title if needed
  if self.cols[i].header == nil then
    self.cols[i].header = UI.Row:new(self.cols[i].column, 1)
  end
  
  -- update title with the correct infos
  MainForm.cols[i].header:update({
    icon = false,
    rank = false,
    name = i == 1 and "Name" or false,
    background = false,
    text = DMUtils:titleForStat(stats[i], (i ~= 1)),
    width = self.colWidth[i]
  })
end



-- returns the options to update a single bar texts, icons, color, data etc...
function MainForm:formatRowOptions(unit, tempFight, column, maxVal, rank)
  local stats = DarkMeter.settings.selectedStats
  local options = {}

  -- set unit and stat reference
  options.unit = {
    id = unit.id,
    name = unit.name,
    pet = unit.pet
  }

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
  options.background = ApolloColor.new("99555555")
  if DMUtils.classes[unit.classId] ~= nil then
    local bg = DMUtils.classes[unit.classId].color
    options.background = ApolloColor.new(bg[1], bg[2], bg[3], 0.3)
  end

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
    local num = DMUtils.formatNumber( value, 1 , DarkMeter.settings.shortNumberFormat )
    -- enable percentage only for the first column, if the value is bigger than 0 and is not the DPS stat
    if column == 1 and value > 0 and DarkMeter.settings.selectedStats[column] ~= "dps" then
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
  if DarkMeter and DarkMeter.initialized then
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
  local stats = DarkMeter.settings.selectedStats

  if UI.lastFight and stats[1] then
    local rowsNumberChanged = false

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
          rowsNumberChanged = true --  a new row has been added and I need to recalculate col heights
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
        end
        rowsNumberChanged = true --  one or more rows has been removed and I need to recalculate col heights
      end
    end

    if rowsNumberChanged then
      MainForm:updateColsHeight()
    end

  else
    MainForm:clear()
  end


  UI.lastUpdate = GameLib.GetGameTime()
end



-------------------------------------------------------------
-- MainForm row hover functions 
-------------------------------------------------------------

MainForm.tooltipControls = {}
MainForm.tooltipControls.visible = false

function MainForm.tooltipControls:hide()
  if MainForm.tooltipControls.visible then
    MainForm.tooltip:Show(false)
    MainForm.tooltipControls.visible = false
  end
end

function MainForm.tooltipControls:show()
  if not MainForm.tooltipControls.visible then
    MainForm.tooltip:Show(true)
    MainForm.tooltipControls.visible = true
  end
end

function MainForm.tooltipControls:move(x, y)
  if x then
    local width = MainForm.tooltip:GetWidth()
    local height = MainForm.tooltip:GetHeight()
    if not y then
      local top
      top, y = MainForm.tooltip:GetAnchorOffsets()
      y = y + height
    end
    MainForm.tooltip:SetAnchorOffsets( (x - width/2), (y - height), (x + width/2), y)
  end
end



-- set tooltip window text
function MainForm.tooltipControls:setText(lines)
  -- sets header
  local header = MainForm.tooltip:FindChild("Header")
  if lines.title then
    header:SetText(lines.title)
  else
    header:SetText("DarkMeter")
  end

  -- sets lines
  local mainStats = MainForm.tooltip:FindChild("MainStats")
  for i = 1, 3 do
    local lineWnd = mainStats:FindChild("Text" .. i)
    if lines[i] then
      lineWnd:SetText(lines[i])
    else
      lineWnd:SetText("")
    end
  end
end


-- handles mouseenter on rows, builds the data to show into the tooltip window and shows it
function MainForm.controls:OnRowMouseEnter(wndH, wndC, x, y)
  if wndH == wndC then
    local data = wndH:GetData()
    local unit = data.unit
    local stat = data.stat
    local totalStat = unit[stat](unit)
    local lines = {}

    if unit[stat.."Skills"] ~= nil then
      lines.title = DMUtils:titleForStat(stat, false)

      -- differentiate damageTaken from the other stats
      -- for damageTaken, list the enemies by their name and the % contribution to the toal dmg taken
      -- for the others stat, list the skill's names
      if stat == "damageTaken" then
        local enemies = unit:damageTakenOrderedByEnemies()

        for i = 1, 3 do
          if enemies[i] then
            local name = enemies[i].name
            local dmg = enemies[i].damage
            local percentage = DMUtils.roundToNthDecimal( (dmg / totalStat * 100), 1)
            lines[i] = percentage .. "%" .. " - " .. name
          end
        end

      -- now for the other stats ...
      else
        local skills = unit[stat.."Skills"](unit)

        -- for the first 3 skills pull name, flat stat and contribution percentage to the overall value of the stat
        for i = 1, 3 do
          local skill = skills[i]
          if skill then
            local skillValue = skill:dataFor(stat)
            local percentage = DMUtils.roundToNthDecimal( (skillValue / totalStat * 100), 1)
            
            lines[i] = percentage .. "%" .. " - " .. skill.name
            if skill.ownerName then
              lines[i] = lines[i] .. " (" .. skill.casterName .. ")"
            end
          end
        end
      end

      -- This is just ugly, but as I understand there's no other way to get a chil'd position relative to the game window
      -- so I have to iterate through and sud their relative offset top
      local totalTop = 0
      local win = wndH
      while win do
        local left, top, right, bottom = win:GetAnchorOffsets()
        totalTop = totalTop + top
        win = win:GetParent()
      end
      totalTop = totalTop - MainForm.wrapper:GetVScrollPos()

      MainForm.tooltipControls:setText(lines)
      MainForm.tooltipControls:show()
      local mousePos = Apollo.GetMouse()
      MainForm.tooltipControls:move(mousePos.x, totalTop)
    end
  end
end

function MainForm.controls:OnRowMouseMove(wndH, wndC, x, y)
  if wndH == wndC then
    local mousePos = Apollo.GetMouse()
    MainForm.tooltipControls:move(mousePos.x, false)
  end
end


function MainForm.controls:OnRowMouseExit(wndH, wndC, x, y)
  if wndH == wndC then
    MainForm.tooltipControls:hide()
  end  
end


function MainForm.controls:OnRowPlayerDetails(wndH, wndC, mouseBtn, x, y)
  if wndH == wndC and mouseBtn == 0 and UI.lastFight then
    local data = wndH:GetData()
    if data ~= nil then
      local unit = nil
      
      if data.pet then
        for id, u in pairs(UI.lastFight.groupMembers) do
          for petName, petUnit in pairs(u.pets) do
            if data.name == petName then
              unit = petUnit
              break
            end
          end
        end
      else
        unit = UI.lastFight.groupMembers[data.id]
      end

      if unit ~= nil then
        UI.PlayerDetails:setPlayer(unit)
        UI.PlayerDetails:show()
      end
    end
  end
end





Apollo.RegisterPackage(MainForm, "DarkMeter:MainForm", 1, {"DarkMeter:UI"})