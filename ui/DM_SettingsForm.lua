local SettingsForm = {}
SettingsForm.controls = {}
SettingsForm.boxControls = {}
SettingsForm.boxes = {
  tracked = {},
  untracked = {}
}

local UI
local DarkMeter
local DMUtils



function SettingsForm:init(xmlDoc)
  self.xmlDoc = xmlDoc
  UI = Apollo.GetPackage("DarkMeter:UI").tPackage
  DarkMeter = Apollo.GetAddon("DarkMeter")
  DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage

  if xmlDoc ~= nil and xmlDoc:IsLoaded() then
    SettingsForm.form = Apollo.LoadForm(xmlDoc, "SettingsForm", nil, SettingsForm.controls)
    SettingsForm.tracked = SettingsForm.form:FindChild("Tracked")
    SettingsForm.untracked = SettingsForm.form:FindChild("Untracked")
    SettingsForm.buttons = SettingsForm.form:FindChild("Buttons")

    SettingsForm.form:Show(false)
  else
    Apollo.AddAddonErrorText(DarkMeter, "Cannot initialize SettingsForm, xmlDoc is nil or not loaded.")
  end
end


function SettingsForm.controls:OnMergePets()
  local btn = SettingsForm.buttons:FindChild("MergePets")
  DarkMeter.settings.mergePets = btn:IsChecked()
  DarkMeter:updateUI()
end

function SettingsForm.controls:OnShowClassIcon()
  local btn = SettingsForm.buttons:FindChild("ShowClassIcon")
  DarkMeter.settings.showClassIcon = btn:IsChecked()
  DarkMeter:updateUI()
end

function SettingsForm.controls:OnShowRanks()
  local btn = SettingsForm.buttons:FindChild("ShowRanks")
  DarkMeter.settings.showRanks = btn:IsChecked()
  DarkMeter:updateUI()
end


-------------------------------------------------------------
-- Display functions
-------------------------------------------------------------

function SettingsForm:show()
  if not self.visible then
    self.visible = true
    local size = Apollo.GetDisplaySize()
    local screenHeight = size.nHeight
    local screenWidth = size.nWidth
    local winHeight = self.form:GetHeight()
    local winWidth = self.form:GetWidth()

    local left = (screenWidth - winWidth)/2
    local top = (screenHeight - winHeight)/2
 
    self.form:Move( left, top, winWidth, winHeight )
    self:setCheckBoxes()
    self:createDraggableBoxes()
    self.form:Show(true)
  end
end

-- hides form
function SettingsForm:hide()
  if self.visible then
    self.visible = false
    self.form:Show(false)
  end
end


-- just closes the settings form
function SettingsForm.controls:OnCancel()
  SettingsForm:hide()
end

-- sets initial checkboxes values
function SettingsForm:setCheckBoxes()
  self.buttons:FindChild("MergePets"):SetCheck(DarkMeter.settings.mergePets)
  self.buttons:FindChild("ShowRanks"):SetCheck(DarkMeter.settings.showRanks)
  self.buttons:FindChild("ShowClassIcon"):SetCheck(DarkMeter.settings.showClassIcon)
end





-------------------------------------------------------------
-- Drag and drop functions
-------------------------------------------------------------


function SettingsForm:createDraggableBoxes()
  local stats = DarkMeter.availableStats
  -- destroy old boxes
  for _, box in pairs(SettingsForm.boxes.tracked) do
    box:Destroy()
  end
  for _, box in pairs(SettingsForm.boxes.untracked) do
    box:Destroy()
  end
  
  SettingsForm.boxes.tracked = {}
  SettingsForm.boxes.untracked = {}

  local addedStats = {}
  for i = 1, #DarkMeter.settings.selectedStats do
    local stat = DarkMeter.settings.selectedStats[i]
    SettingsForm:createBox(stat)
    table.insert(addedStats, stat)
  end

  for i = 1, #stats do
    local added = false
    for index = 1, #addedStats do
      if stats[i] == addedStats[index] then
        added = true
      end
    end
    if not added then
      SettingsForm:createBox(stats[i])
    end
  end

end

function SettingsForm:createBox(stat)
  local statTracked = false
  local parent
  for _, name in pairs(DarkMeter.settings.selectedStats) do
    if stat == name then
      statTracked = true
    end
  end

  if statTracked then
    parent = SettingsForm.tracked
  else
    parent = SettingsForm.untracked
  end

  local box = Apollo.LoadForm(self.xmlDoc, "SettingsDraggable", parent, SettingsForm.boxControls)
  box:SetText( DMUtils:titleForStat(stat, false) )
  box:SetData(stat)


  if statTracked then
    local index = 0
    for j = 0, #DarkMeter.settings.selectedStats do
      local tStat = DarkMeter.settings.selectedStats[j]
      if tStat == stat then
        index = j - 1
      end
    end
    SettingsForm.boxControls:moveToPos(box, index, statTracked)
    table.insert(SettingsForm.boxes.tracked, box)
  else
    SettingsForm.boxControls:moveToPos(box, #SettingsForm.boxes.untracked, statTracked)
    table.insert(SettingsForm.boxes.untracked, box)
  end
end


-------------------------------------------------------------
-- Drag buttons
-------------------------------------------------------------

function SettingsForm.boxControls:OnStartDrag(wnd)
  SettingsForm.boxControls.dragging = true
  SettingsForm.boxControls.draggingBox = wnd
  SettingsForm.boxControls.startLocation = SettingsForm.boxControls.draggingBox:GetLocation()

  if SettingsForm.boxControls.clone ~= nil then
    SettingsForm.boxControls.clone:Destroy()
  end
  SettingsForm.boxControls.clone = SettingsForm.boxControls:createShadowClone(wnd)

  local mousePos = Apollo.GetMouse()
  SettingsForm.boxControls.mousePosition = {
    x = mousePos.x,
    y = mousePos.y
  }

  local x, y = SettingsForm.boxControls.draggingBox:GetAnchorOffsets()
  SettingsForm.boxControls.startPosition = {
    x = x,
    y = y
  }
end

function SettingsForm.boxControls:OnStopDrag()
  SettingsForm.boxControls.dragging = false
  
  local x, y = SettingsForm.boxControls.draggingBox:GetAnchorOffsets()
  local midX = x + ( SettingsForm.boxControls.draggingBox:GetWidth() / 2 )
  local midY = y + ( SettingsForm.boxControls.draggingBox:GetHeight() / 2 )
  local redraw = false

  if SettingsForm.tracked:ContainsMouse() then
    local data = SettingsForm.boxControls.draggingBox:GetData()
    local i = 1
    if SettingsForm.boxControls.draggingIndex then
      i = SettingsForm.boxControls.draggingIndex
    end
    DarkMeter:addTracked(data, i)
  elseif SettingsForm.untracked:ContainsMouse() then
    local data = SettingsForm.boxControls.draggingBox:GetData()
    DarkMeter:removeTracked(data)
  else
    -- The animation is not showing because I redraw every single box, I'll just comment for now
    -- SettingsForm.boxControls.draggingBox:TransitionMove(SettingsForm.boxControls.startLocation, 0.25)
  end
  
  SettingsForm.boxControls.clone:Destroy()
  SettingsForm.boxControls.clone = nil

  SettingsForm.boxControls.draggingBox = nil

  SettingsForm:createDraggableBoxes()

end

function SettingsForm.boxControls:OnMouseMove()
  if SettingsForm.boxControls.dragging and SettingsForm.boxControls.draggingBox then
    local mousePos = Apollo.GetMouse()
    
    local newOffsetX = mousePos.x - SettingsForm.boxControls.mousePosition.x + SettingsForm.boxControls.startPosition.x
    local newOffsetY = mousePos.y - SettingsForm.boxControls.mousePosition.y + SettingsForm.boxControls.startPosition.y
    
    SettingsForm.boxControls.draggingBox:SetAnchorOffsets(newOffsetX, newOffsetY, (newOffsetX + SettingsForm.boxControls.draggingBox:GetWidth()), (newOffsetY + SettingsForm.boxControls.draggingBox:GetHeight()) )
    local index, container = SettingsForm.boxControls:draggingBoxPosition()
    SettingsForm.boxControls.draggingIndex = index
    SettingsForm.boxControls:moveShadowTo(index, container)
  end
end


function SettingsForm.boxControls:moveToPos(box, i, tracked)
  SettingsForm.boxWidth = box:GetWidth()
  SettingsForm.boxHeight = box:GetHeight()
  SettingsForm.boxMargin = 5
  local contHeight = tracked and SettingsForm.tracked:GetHeight() or SettingsForm.untracked:GetHeight()
  local top = (contHeight - SettingsForm.boxHeight) / 2
  local left = SettingsForm.boxMargin + ( (SettingsForm.boxWidth + SettingsForm.boxMargin * 2) * i)
  box:SetAnchorOffsets(left, top, (left + SettingsForm.boxWidth), (top + SettingsForm.boxHeight))
end


function SettingsForm.boxControls:createShadowClone(box)
  local location = box:GetLocation()
  local parent = box:GetParent()
  local clone = Apollo.LoadForm(SettingsForm.xmlDoc, "SettingsDraggable", parent, {})
  clone:SetText("")
  -- TODO for now i set the bg to transparent because I have to fix the shadow that doesn't move from tracked to the untracked container
  clone:SetBGColor(ApolloColor.new("00000000"))
  clone:MoveToLocation(location)
  return clone
end


function SettingsForm.boxControls:draggingBoxPosition()
  local container

  if SettingsForm.tracked:ContainsMouse() then
    container = SettingsForm.tracked
  elseif SettingsForm.untracked:ContainsMouse() then
    container = SettingsForm.untracked
  else
    return
  end

  local boxLeft, BoxTop = SettingsForm.boxControls.draggingBox:GetAnchorOffsets()
  local boxSpace = SettingsForm.boxMargin * 2 + SettingsForm.boxWidth
  local left = boxLeft + boxSpace / 2

  if left <= boxSpace*1 then
    return 1, container
  else
    return (1 + math.ceil((left - boxSpace*1) / boxSpace) ), container
  end

end


function SettingsForm.boxControls:moveShadowTo(index, container)
  if SettingsForm.boxControls.clone ~= nil then
    local name = string.lower(container:GetName())
    local boxes = SettingsForm.boxes[name]
    local boxPassed = false

    SettingsForm.boxControls:moveToPos(SettingsForm.boxControls.clone, (index -1), (name == "tracked") )
    for i = 1, #boxes do
      if boxes[i] == SettingsForm.boxControls.draggingBox then
        boxPassed = true
      else
        local pos
        if i >= index then
          pos = i + 1
        else
          pos = i
        end
        if boxPassed then
          pos = pos - 1
        end
        SettingsForm.boxControls:moveToPos(boxes[i], (pos - 1), (name == "tracked") )
      end
      
    end

  end
end


-------------------------------------------------------------
-- End drag and drop functions
-------------------------------------------------------------










Apollo.RegisterPackage(SettingsForm, "DarkMeter:SettingsForm", 1, {"DarkMeter:UI"})