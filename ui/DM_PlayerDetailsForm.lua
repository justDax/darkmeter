
local PlayerDetails = {}            -- prompt reset data form and all the correlated functions
PlayerDetails.controls = {}         -- form controls
PlayerDetails.graphControls = {}    -- controls grid drawing functions
PlayerDetails.botControls = {}      -- controls the bottom container part
local UI
local DarkMeter
local DMUtils


function PlayerDetails:init(xmlDoc)
  self.xmlDoc = xmlDoc
  UI = Apollo.GetPackage("DarkMeter:UI").tPackage
  DarkMeter = Apollo.GetAddon("DarkMeter")
  DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage

  if xmlDoc ~= nil and xmlDoc:IsLoaded() then
    PlayerDetails.form = Apollo.LoadForm(xmlDoc, "PlayerDetailsForm", nil, PlayerDetails.controls)
    
    -- some useful form child windows
    PlayerDetails.dropdown = PlayerDetails.form:FindChild("Dropdown")
    PlayerDetails.content = PlayerDetails.form:FindChild("Content")
    PlayerDetails.ddBtn = PlayerDetails.content:FindChild("Tracked")
    PlayerDetails.graph = PlayerDetails.content:FindChild("Graph")
    PlayerDetails.portrait = PlayerDetails.content:FindChild("Portrait")
    PlayerDetails.level = PlayerDetails.content:FindChild("Level")
    PlayerDetails.bottom = PlayerDetails.content:FindChild("BottomContainer")
    -- overall windows
    PlayerDetails.overall = PlayerDetails.content:FindChild("OverallInfo")
    PlayerDetails.oTotal = PlayerDetails.overall:FindChild("Total")
    PlayerDetails.oCrit = PlayerDetails.overall:FindChild("Crit")
    PlayerDetails.oDeflect = PlayerDetails.overall:FindChild("Deflect")
    PlayerDetails.oMulti = PlayerDetails.overall:FindChild("MultiHit")
    PlayerDetails.oMultiCrit = PlayerDetails.overall:FindChild("MultiCrit")
    PlayerDetails.oAttacks = PlayerDetails.overall:FindChild("Attacks")

    -- bottom windows
    -- first is the initial tab
    PlayerDetails.first = PlayerDetails.bottom:FindChild("First")
    -- second is the tab that contains a skill's details
    PlayerDetails.second = PlayerDetails.bottom:FindChild("Second")
    PlayerDetails.table = PlayerDetails.second:FindChild("Table")
    -- third
    PlayerDetails.third = PlayerDetails.bottom:FindChild("Third")
    PlayerDetails.currentBotWindow = "first"
    -- fourth
    PlayerDetails.fourth = PlayerDetails.bottom:FindChild("Fourth")
    -- hides main form and dropdown window
    PlayerDetails.form:Show(false)
    PlayerDetails.dropdown:Show(false)

    -- sets default tracked to damageDone
    PlayerDetails.stat = "damageDone"
  else
    Apollo.AddAddonErrorText(DarkMeter, "Cannot initialize PlayerDetailsForm, xmlDoc is nil or not loaded.")
  end
end

function PlayerDetails:show()
  self.form:Show(true)
  self.visible = true
end

function PlayerDetails:hide()
  self.form:Show(false)
  self.visible = false
end


-- redraw or updates all the form elements
-- usually called when changing the inspected unit
function PlayerDetails:updateForm()
  -- set player's generic info
  if self.unit ~= nil then
    -- set name
    local name = self.unit.name
    self.content:FindChild("UnitName"):SetText(name)
    -- set class icon
    local unitIcon = DMUtils:iconForClass(self.unit)
    self.content:FindChild("UnitIcon"):SetSprite(unitIcon)
    -- set portrait
    self.portrait:SetCostume(self.unit.wsUnit)
    self.portrait:Show(true)
    -- set level
    PlayerDetails.level:SetText(self.unit.level)

    -- regenerate fresh graph with axis
    PlayerDetails.graphControls:clear()
    PlayerDetails.graphControls:createAxes()

    -- prepare data for the graph
    local data = 0
    local unitSkills

    -- special case for damagetaken shows damage per unit
    if self.stat == "damageTaken" then
      unitSkills = self.unit:damageTakenOrderedByEnemies()
      for _, unit in pairs(unitSkills) do
        data = math.max(data, unit.damage)
      end
    -- special case for deaths
    elseif self.stat == "deaths" then
      unitSkills = self.unit.deathsRecap
    -- else shows the skills based on the selected stat
    else
      if self.unit[self.stat .. "Skills"] ~= nil then
        unitSkills = self.unit[self.stat .. "Skills"](self.unit)

        for _, skill in pairs(unitSkills) do
          data = math.max(data, skill:dataFor(self.stat))
        end
      end
    end
    
    if self.stat ~= "deaths" then
      PlayerDetails.graphControls:createYLabels(data)
      PlayerDetails.graphControls:createBars(unitSkills)
    end

    -- set overall infos
    if PlayerDetails.currentBotWindow == "first" then
      PlayerDetails.botControls:setBaseOverallInfos()
    end

    -- update skills bottom rows
    PlayerDetails.botControls:updateBottomPart(unitSkills)

    -- updates skills details if inspecting one
    if PlayerDetails.skillDetails then
      PlayerDetails.botControls:showDetailsForRow(PlayerDetails.skillDetails)
    end
    -- force recalc of row's occupied area, if this is not done, I won't be able to scroll the skills
    PlayerDetails.first:RecalculateContentExtents()
  end
end


function PlayerDetails:setPlayer(unit)
  PlayerDetails.unit = unit
  PlayerDetails:updateForm()
end


--------------------------------------
-- events
--------------------------------------


-- closes the form
function PlayerDetails.controls:OnCancel()
  PlayerDetails:hide()
end

-- pops dropdown menu
function PlayerDetails.controls:OnDropdownOpen()
  PlayerDetails.dropdown:Show(true)
end

-- set dropdown current selected options
function PlayerDetails.controls:updateSelected(wnd)
  local text = wnd:FindChild("Text"):GetText()
  if text then
    PlayerDetails.ddBtn:FindChild("Text"):SetText(text)
  end
  PlayerDetails.dropdown:Show(false)
  -- scrolls skills to the top
  PlayerDetails.first:SetVScrollPos(0)
  -- go back to the first window
  while (#PlayerDetails.prevWindows > 0) do
    PlayerDetails.controls:OnPrevWin()
  end
end





-- change inspected stat (dropdown options)

function PlayerDetails.controls:OnDamageDoneTab(wndH, wndC, mouseBtn)
  PlayerDetails.stat = "damageDone"
  PlayerDetails:updateForm()
  PlayerDetails.controls:updateSelected(wndH)
end

function PlayerDetails.controls:OnHealingDoneTab(wndH, wndC, mouseBtn)
  PlayerDetails.stat = "healingDone"
  PlayerDetails:updateForm()
  PlayerDetails.controls:updateSelected(wndH)
end

-- DPS tab has been removed as I've no reliable method to calculate the dps of a single skill
-- maybe I could display the contribution of a skill to the total dps? this sounds like an useless information
-- and too much work to calculate it
function PlayerDetails.controls:OnDpsTab(wndH, wndC, mouseBtn)
  PlayerDetails.stat = "dps"
  PlayerDetails:updateForm()
  PlayerDetails.controls:updateSelected(wndH)
end

function PlayerDetails.controls:OnOverhealDoneTab(wndH, wndC, mouseBtn)
  PlayerDetails.stat = "overhealDone"
  PlayerDetails:updateForm()
  PlayerDetails.controls:updateSelected(wndH)
end

function PlayerDetails.controls:OnDamageTakenTab(wndH, wndC, mouseBtn)
  PlayerDetails.stat = "damageTaken"
  PlayerDetails:updateForm()
  PlayerDetails.controls:updateSelected(wndH)
end

function PlayerDetails.controls:OnInterruptsTab(wndH, wndC, mouseBtn)
  PlayerDetails.stat = "interrupts"
  PlayerDetails:updateForm()
  PlayerDetails.controls:updateSelected(wndH)
end

function PlayerDetails.controls:OnDeathsTab(wndH, wndC, mouseBtn)
  PlayerDetails.stat = "deaths"
  PlayerDetails:updateForm()
  PlayerDetails.controls:updateSelected(wndH)
end

-- end dropdown options functions


---------------------------------------
-- overall infos
---------------------------------------
function PlayerDetails.controls.setOverallInfos(options, formatted)
  local iteration = {
    oCrit = "crit",
    oDeflect = "deflect",
    oMulti = "multihit",
    oMultiCrit = "multicrit"
  }
  -- total
  if options.total then
    PlayerDetails.oTotal:SetText( options.total )
  else
    PlayerDetails.oTotal:SetText("-")
  end
  -- attacks
  if options.attacks then
    PlayerDetails.oAttacks:SetText( options.attacks )
  else
    PlayerDetails.oAttacks:SetText( "-" )
  end
  -- others percentages
  for wndName, val in pairs(iteration) do
    if options[val] then
      if formatted == true then
        PlayerDetails[wndName]:SetText(options[val])
      else
        PlayerDetails[wndName]:SetText( DMUtils.roundToNthDecimal(options[val], 1) .. "%" )
      end
    else
      PlayerDetails[wndName]:SetText("-")
    end
  end
end



---------------------------------------
-- graph controls
---------------------------------------
PlayerDetails.graphControls.leftAbundance = 25
PlayerDetails.graphControls.botAbundance = 25
PlayerDetails.graphControls.distanceBetweenBars = 5
PlayerDetails.graphControls.maxBarWidth = 30

function PlayerDetails.graphControls:clear()
  PlayerDetails.graph:DestroyAllPixies()
  PlayerDetails.graphControls.maxValue = 0
end

function PlayerDetails.graphControls:createAxes()
  local opts = {
    bLine = true,
    fWidth = 2,
    strSprite = "BasicSprites:WhiteFill",
    cr = ApolloColor.new("ff404653")
  }
  -- create X axis
  opts.loc = {
    fPoints = {0, 1, 1, 1},
    nOffsets = {PlayerDetails.graphControls.leftAbundance, (-PlayerDetails.graphControls.botAbundance + 1), 0, (-PlayerDetails.graphControls.botAbundance + 1)}
  }
  PlayerDetails.graph:AddPixie(opts)

  -- create Y axis
  opts.loc = {
    fPoints = {0, 0, 0, 1},
    nOffsets = {PlayerDetails.graphControls.leftAbundance, 0, PlayerDetails.graphControls.leftAbundance, (-PlayerDetails.graphControls.botAbundance + 2)}
  }
  PlayerDetails.graph:AddPixie(opts)
end

-- creates y axis labels
function PlayerDetails.graphControls:createYLabels(maxVal)
  local multiplier = 1
  local n = maxVal
  while (n/10 >= 1) do
    n = n/10
    multiplier = multiplier * 10
  end
  
  local cycleEnd = math.ceil(maxVal/multiplier)
  PlayerDetails.graphControls.maxValue = cycleEnd * multiplier -- used to calculate bar heights later

  local labelDistance = (PlayerDetails.graph:GetHeight() - 5 - PlayerDetails.graphControls.botAbundance) / cycleEnd
  
  for i = 1, cycleEnd do
    local labelText = DMUtils.formatNumber(i * multiplier , 0)
    if cycleEnd > 5 and (i % 2 ~= 0) then
      labelText = false
    end
    
    PlayerDetails.graphControls:createYLabel( (labelDistance * i), labelText)
  end
end

-- creates a single Y label given distance from origin and text
function PlayerDetails.graphControls:createYLabel(distance, text)
  -- white line
  local opts = {
    bLine = true,
    fWidth = 1,
    strSprite = "BasicSprites:WhiteFill",
    cr = ApolloColor.new("ff404653"),
    loc = {
      fPoints = {0, 1, 0, 1},
      nOffsets = {PlayerDetails.graphControls.leftAbundance, (-distance - PlayerDetails.graphControls.botAbundance), (PlayerDetails.graphControls.leftAbundance + 5), (-distance - PlayerDetails.graphControls.botAbundance)}
    }
  }
  PlayerDetails.graph:AddPixie(opts)

  if text then
    -- label text
    opts = {
      bLine = false,
      cr = ApolloColor.new("00000000"),
      strText = text,
      strFont = "CRB_InterfaceTiny_BB",
      flagsText = { DT_RIGHT = true, DT_VCENTER = true },
      loc = {
        fPoints = {0, 1, 0, 1},
        nOffsets = {0, (0 - distance - 5 - PlayerDetails.graphControls.botAbundance), (PlayerDetails.graphControls.leftAbundance - 5), (0 - distance + 5 - PlayerDetails.graphControls.botAbundance)}
      }
    }
    PlayerDetails.graph:AddPixie(opts)
  end
end


-- makes calculations for creating bars and icons
function PlayerDetails.graphControls:createBars(unitSkills)
  -- this is the max col height
  local graphHeight = PlayerDetails.graph:GetHeight() - 5 - PlayerDetails.graphControls.botAbundance
  local graphWidth = PlayerDetails.graph:GetWidth() - 10 - PlayerDetails.graphControls.leftAbundance
  local skillsTotal = DMUtils.tableLength(unitSkills)
  
  if skillsTotal > 0 then
    local barWidth =  ( ( graphWidth - 3) / skillsTotal ) - PlayerDetails.graphControls.distanceBetweenBars
    local counter = 0
    
    for _, skill in pairs(unitSkills) do
      counter = counter + 1
      if counter <= 15 then -- limit bars to 15
        local skillValue
        
        if PlayerDetails.stat == "damageTaken" then
          skillValue = skill.damage
        else
          skillValue = skill:dataFor(PlayerDetails.stat)
        end
        
        local barHeight =  graphHeight * skillValue / PlayerDetails.graphControls.maxValue
        PlayerDetails.graphControls:createBar( barWidth, barHeight, counter )
        PlayerDetails.graphControls:createBarIcon( barWidth, counter, skill )
      end
    end
  end

end

-- creates a single graph bar
function PlayerDetails.graphControls:createBar( width, height, i)
  if PlayerDetails.graphControls.maxValue and PlayerDetails.graphControls.maxValue > 0 then
    local left = PlayerDetails.graphControls.leftAbundance + 10 + PlayerDetails.graphControls.distanceBetweenBars + ( (width + PlayerDetails.graphControls.distanceBetweenBars) * (i - 1) )
    if (width > PlayerDetails.graphControls.maxBarWidth) then
      width = PlayerDetails.graphControls.maxBarWidth
    end

    local color = ApolloColor.new("ff404653")
    if DMUtils.classes[PlayerDetails.unit.classId] then
      local bg = DMUtils.classes[PlayerDetails.unit.classId].color
      color = ApolloColor.new(bg[1], bg[2], bg[3], 0.8)
    end

    local opts = {
      strSprite = "BasicSprites:WhiteFill",
      cr = color,
      loc = {
        fPoints = {0, 1, 0, 1},
        nOffsets = {left, (-PlayerDetails.graphControls.botAbundance - height), (left + width), -PlayerDetails.graphControls.botAbundance}
      }
    }
    PlayerDetails.graph:AddPixie(opts)
  end
end

-- creates the skill icon below a single bar
function PlayerDetails.graphControls:createBarIcon(width, i, skill)
  if skill.name then
    local left = PlayerDetails.graphControls.leftAbundance + 10 + PlayerDetails.graphControls.distanceBetweenBars + ( (width + PlayerDetails.graphControls.distanceBetweenBars) * (i - 1) )
    local iconSize = 20
    if iconSize > width then
      iconSize = width
    else
      local w = width > PlayerDetails.graphControls.maxBarWidth and PlayerDetails.graphControls.maxBarWidth or width
      left = left + (w - iconSize) / 2
    end

    local opts = {
      strSprite = skill.icon,
      loc = {
        fPoints = {0, 1, 0, 1},
        nOffsets = {left, -iconSize, (left + iconSize), 0}
      }
    }
    PlayerDetails.graph:AddPixie(opts)
  end
end



-- updates the bottom part with percentage and skill name on the main visible window
function PlayerDetails.botControls:updateBottomPart(unitSkills)
  if PlayerDetails.botControls.firstRows == nil then
    PlayerDetails.botControls.firstRows = {}
  end

  local totalStat = PlayerDetails.unit[PlayerDetails.stat](PlayerDetails.unit)
  local index = 0
  -- iterates through skills and creates each row
  for _, skill in pairs(unitSkills) do
    index = index + 1
    if PlayerDetails.botControls.firstRows[index] == nil then
      PlayerDetails.botControls.firstRows[index] = PlayerDetails.botControls:createSingleBar(index, PlayerDetails.first)
    end
    local skillValue
    local dataToBind
    local percentage = ""
    local name = ""
    local value = ""

    if PlayerDetails.stat == "deaths" then
      percentage = skill.timestamp.nHour .. ":" .. skill.timestamp.nMinute
      name = skill.killerName
      dataToBind = skill
    else
      if PlayerDetails.stat == "damageTaken" then
        skillValue = skill.damage
        dataToBind = skill.name -- in this case bind enemy name used to retrieve the enemy's skills later
      elseif PlayerDetails.stat == "interrupts" then
        skillValue = skill:dataFor(PlayerDetails.stat)
        dataToBind = false
      else
        skillValue = skill:dataFor(PlayerDetails.stat)
        dataToBind = skill
      end

      percentage = DMUtils.roundToNthDecimal( (skillValue / totalStat * 100), 1) .. "%"
      name = skill.name
      value = DMUtils.formatNumber(skillValue, 2)
    end
    PlayerDetails.botControls:updateSingleSkill(PlayerDetails.botControls.firstRows[index], percentage, name, value, dataToBind)
  end

  -- destroy rows in excess, this is usually done when changing the currently monitored stat
  if #PlayerDetails.botControls.firstRows > index then
    while ( PlayerDetails.botControls.firstRows[index + 1] ~= nil ) do
      index = index + 1
      PlayerDetails.botControls.firstRows[index]:Destroy()
      PlayerDetails.botControls.firstRows[index] = nil
    end
  end
  
end

-- create a single row given it's index inside rows array and returns it
function PlayerDetails.botControls:createSingleBar(i, parent, marginTop)
  local row = Apollo.LoadForm(PlayerDetails.xmlDoc, "SkillBar", parent, PlayerDetails.botControls)
  local left, top, right, bottom = row:GetAnchorOffsets()
  local barHeight = row:GetHeight()
  marginTop = marginTop or 0
  top = 1 + (barHeight + 1) * (i - 1) + marginTop
  row:SetAnchorOffsets(left, top, right, ( top + barHeight) )
  return row
end

-- updates a single skill bar: percentage, skill name, text and binds the skill to the row's data, this is useful to grab infos when inspecting a single skill
function PlayerDetails.botControls:updateSingleSkill(row, percentage, name, skillValue, data)
  row:FindChild("Percentage"):SetText(percentage)
  row:FindChild("Data"):SetText(value)
  row:FindChild("Name"):SetText(name)
  if data == false then
    row:FindChild("Arrow"):Show(false)
  else
    row:FindChild("Arrow"):Show(true)
    row:SetData(data)
  end
end


-- this function gets called when the user clicks on a single skill to inspect its details
function PlayerDetails.botControls:InspectSingleSkill(wndH, wndC, eBtn, nX, nY)
  if wndH == wndC and eBtn == 0 then
    local data = wndH:GetData()
    if data then
      -- usually the second window is the one holding the skill details, in case of the damagetaken, the first one holds the enemies
      -- then I show the third one, which shows the skills casted to the player by a certain enemy and at last the second, when inspecting a skill
      -- tldt the order of the windows for damagetaken is: first => third => second
      if PlayerDetails.stat == "damageTaken" then
        -- if I'm on the first window, go to skills
        if PlayerDetails.currentBotWindow == "first" then
          PlayerDetails.botControls:goToWindow("third")
          -- form damagetaken skill should be the name of the enemy
          PlayerDetails.botControls:showOverallDoneBy(data)
          PlayerDetails.botControls:showDamgeDoneBy(data)
        -- if I'm on the third window go to skill details
        elseif PlayerDetails.currentBotWindow == "third" then
          PlayerDetails.botControls:goToWindow("second")
          PlayerDetails.botControls:showDetailsForRow(data)
        end
      elseif PlayerDetails.stat == "deaths" then
        PlayerDetails.botControls:goToWindow("fourth")
        PlayerDetails.botControls:deathRecapFor(data)
      else
        PlayerDetails.botControls:goToWindow("second")
        PlayerDetails.botControls:showDetailsForRow(data)
      end
    end
  end
end


PlayerDetails.prevWindows = {}
-- controls bot window, animates in the requested window by name
function PlayerDetails.botControls:goToWindow(name)
  if PlayerDetails.currentBotWindow == name then return end
  
  local isPrev = false  
  for _, win in pairs(PlayerDetails.prevWindows) do
    if win == name then isPrev = true end
  end

  local targetWndLocation = PlayerDetails[name]:GetLocation():ToTable()
  local currentWndLocation = PlayerDetails[PlayerDetails.currentBotWindow]:GetLocation():ToTable()
  local contWidth = PlayerDetails.bottom:GetWidth()
  targetWndLocation.nOffsets[1] = 0
  targetWndLocation.nOffsets[3] = name == "first" and 12 or 0

  if isPrev then
    -- if the requested window is between the previous windows animate in from the left
    currentWndLocation.nOffsets[1] = currentWndLocation.nOffsets[1] + contWidth
    currentWndLocation.nOffsets[3] = currentWndLocation.nOffsets[3] + contWidth
    for i = 1, #PlayerDetails.prevWindows do
      if PlayerDetails.prevWindows[i] == name then
        table.remove(PlayerDetails.prevWindows, i)
      end
    end
  else
    -- animate in from the right and add the old current window to the previous windows
    currentWndLocation.nOffsets[1] = currentWndLocation.nOffsets[1] - contWidth
    currentWndLocation.nOffsets[3] = currentWndLocation.nOffsets[3] - contWidth
    table.insert(PlayerDetails.prevWindows, PlayerDetails.currentBotWindow)
  end

  PlayerDetails[name]:TransitionMove(WindowLocation.new(targetWndLocation), 0.25)
  PlayerDetails[PlayerDetails.currentBotWindow]:TransitionMove(WindowLocation.new(currentWndLocation), 0.25)
  PlayerDetails.currentBotWindow = name
end

-- go back one window
function PlayerDetails.controls:OnPrevWin()
  PlayerDetails.skillDetails = nil
  if #PlayerDetails.prevWindows > 0 then
    PlayerDetails.botControls:goToWindow(PlayerDetails.prevWindows[#PlayerDetails.prevWindows])

    if PlayerDetails.currentBotWindow == "first" then 
      PlayerDetails.botControls:setBaseOverallInfos()
    end
  end
end



-- shows damagedone skills done by a certain unit
function PlayerDetails.botControls:showDamgeDoneBy(name)
  if PlayerDetails.botControls.thirdRows == nil then
    PlayerDetails.botControls.thirdRows = {}
  end

  PlayerDetails.third:FindChild("Name"):SetText(name)

  local totalStat = PlayerDetails.unit:damageTaken() 
  local index = 0
  
  if PlayerDetails.unit.damagingSkillsTaken[name] then
    for skillName, skill in pairs(PlayerDetails.unit.damagingSkillsTaken[name]) do
      index = index + 1
      if PlayerDetails.botControls.thirdRows[index] == nil then
        PlayerDetails.botControls.thirdRows[index] = PlayerDetails.botControls:createSingleBar(index, PlayerDetails.third, 30)
      end
      
      local percentage = DMUtils.roundToNthDecimal( (skill.damageDone / totalStat * 100), 1) .. "%"
      local name = skill.name
      local value = DMUtils.formatNumber(skill.damageDone, 2)
      local dataToBind = skill
      PlayerDetails.botControls:updateSingleSkill(PlayerDetails.botControls.thirdRows[index], percentage, name, value, dataToBind)
    end
  end

  -- destroy rows in excess, this is usually done when changing the currently monitored stat
  if #PlayerDetails.botControls.thirdRows > index then
    while ( PlayerDetails.botControls.thirdRows[index + 1] ~= nil ) do
      index = index + 1

      PlayerDetails.botControls.thirdRows[index]:Destroy()
      PlayerDetails.botControls.thirdRows[index] = nil
    end
  end
end



-- shows overall damage done by the enemy units with this name
function PlayerDetails.botControls:showOverallDoneBy(name)
  local skillsTaken = PlayerDetails.unit.damagingSkillsTaken[name]
  if skillsTaken then
    local total = 0
    local multi = 0
    local multicrit = 0
    local crit = 0
    local deflects = 0
    local damage = 0

    for skillName, skill in pairs(skillsTaken) do
      total = total + skill.damage.total
      multi = multi + #skill.damage.multihits
      multicrit = multicrit + #skill.damage.multicrits
      crit = crit + #skill.damage.crits
      deflects = deflects + skill.damage.deflects
      damage = damage + skill.damageDone
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

    percentages.deflects = deflects / total * 100
    percentages.attacks = total

    local overallInfos = {
      total = damage
    }
  
    if percents then
      overallInfos.crit = crits
      overallInfos.multihit = multihits
      overallInfos.multicrit = multicrits
      overallInfos.attacks = attacks
      overallInfos.deflect = deflects
    end
    PlayerDetails.controls.setOverallInfos(overallInfos)
  end
end



function PlayerDetails.botControls:setBaseOverallInfos()
  local overallInfos = {
    total = PlayerDetails.unit[PlayerDetails.stat](PlayerDetails.unit)
  }
  
  local percents = PlayerDetails.unit:statsPercentages(PlayerDetails.stat)
  if percents then
    overallInfos.crit = percents.crits
    overallInfos.multihit = percents.multihits
    overallInfos.multicrit = percents.multicrits
    overallInfos.attacks = percents.attacks
    overallInfos.deflect = percents.deflects
  end
  PlayerDetails.controls.setOverallInfos(overallInfos)
end


-- updates the second widow with the given skill
function PlayerDetails.botControls:showDetailsForRow(data)
  PlayerDetails.skillDetails = data
  -- sets overall infos for this specific skill
  local overallInfos = {
    total = data:dataFor(PlayerDetails.stat)
  }
  local percents = data:statsPercentages(PlayerDetails.stat)
  if percents then
    overallInfos.crit = percents.critsCount .. " - " .. DMUtils.roundToNthDecimal(percents.crits, 1) .. "%"
    overallInfos.multihit = percents.multihitsCount .. " - " .. DMUtils.roundToNthDecimal(percents.multihits, 1) .. "%"
    overallInfos.multicrit = percents.multicritsCount .. " - " .. DMUtils.roundToNthDecimal(percents.multicrits, 1) .. "%"
    overallInfos.attacks = tostring(percents.attacks)
    if percents.deflects and percents.deflectsCount then
        overallInfos.deflect = percents.deflectsCount .. " - " .. DMUtils.roundToNthDecimal(percents.deflects, 1) .. "%"
      end
  end

  PlayerDetails.controls.setOverallInfos(overallInfos, true)

  PlayerDetails.second:FindChild("Name"):SetText(data.name)

  local statType = nil
  if PlayerDetails.stat == "damageDone" or PlayerDetails.stat == "damageTaken" then
    statType = "damageDone"
  elseif PlayerDetails.stat == "healingDone" then
    statType = "healingDone"
  elseif PlayerDetails.stat == "overhealDone" then
    statType = "overhealDone"
  end
  -- sets table value
  local minCol = PlayerDetails.table:FindChild("MinCol")
  local avgCol = PlayerDetails.table:FindChild("AvgCol")
  local maxCol = PlayerDetails.table:FindChild("MaxCol")
  -- min col
  if statType then
    for k, col in pairs({Min = minCol, Avg = avgCol, Max = maxCol}) do
      local stat  = data[statType .. k](data)
      for wndName, tp in pairs({Normal = "hits", Critical = "crits", Multihit = "multihits", Multicrit = "multicrits"}) do
        local value = stat[tp]
        if not value then
          value = "-"
        else
          value = DMUtils.formatNumber( value, 2)
        end
        col:FindChild(wndName):SetText( value )
      end      
    end
  end

end


-- shows last 10 damage taken before death inside the fourth window
function PlayerDetails.botControls:deathRecapFor(data)
  -- local name = data.timestamp.nHour .. ":" .. data.timestamp.nMinute .. " (last 10 damage taken)"
  local name = "last 10 damage taken"
  PlayerDetails.fourth:FindChild("Name"):SetText(name)

  if PlayerDetails.botControls.deathRecapRows == nil then
    PlayerDetails.botControls.deathRecapRows = {}
  end
  for i = 1, #PlayerDetails.botControls.deathRecapRows do
    PlayerDetails.botControls.deathRecapRows[i]:destroy()
    PlayerDetails.botControls.deathRecapRows[i] = nil
  end


  local counter = 0
  for i = #data.skills, 1, -1 do
    counter = counter + 1
    PlayerDetails.botControls.deathRecapRows[counter] = PlayerDetails.botControls:createSingleBar(counter, PlayerDetails.fourth, 30)
    local skill = data.skills[i]
    local text = skill.name .. " - " .. skill.damage
    if i == 1 then
      text = "[R.I.P.] " .. text
    end

    PlayerDetails.botControls:updateSingleSkill(PlayerDetails.botControls.deathRecapRows[counter], counter .. ")", text, "", false)
  end
  -- TODO fourth wndow is not scrolling... even with a recalculate content extents, maybe the pixies gets ignored
  PlayerDetails.fourth:RecalculateContentExtents()
end



Apollo.RegisterPackage(PlayerDetails, "DarkMeter:PlayerDetails", 1, {"DarkMeter:UI"})