
local ReportForm = {}            -- prompt reset data form and all the correlated functions
ReportForm.controls = {}         -- form controls
local UI
local Fight
local DarkMeter
local DMUtils


function ReportForm:init(xmlDoc)
  UI = Apollo.GetPackage("DarkMeter:UI").tPackage
  Fight = Apollo.GetPackage("DarkMeter:Fight").tPackage
  DMUtils = Apollo.GetPackage("DarkMeter:Utils").tPackage
  DarkMeter = Apollo.GetAddon("DarkMeter")

  if xmlDoc ~= nil and xmlDoc:IsLoaded() then
    ReportForm.form = Apollo.LoadForm(xmlDoc, "ReportForm", nil, ReportForm.controls)
    ReportForm.form:Show(false)
  else
    Apollo.AddAddonErrorText(DarkMeter, "Cannot initialize ReportForm, xmlDoc is nil or not loaded.")
  end
  ReportForm.maxRows = ReportForm.form:FindChild("RowsN")
end


-------------------------------------------------------------
-- ReportForm
-------------------------------------------------------------

function ReportForm:show()
  if not self.visible then
    self.visible = true
    self.rowsn = self.form:FindChild("RowsN")
    self.rowsn:SetText( tostring(DarkMeter.settings.reportRows) )

    local size = Apollo.GetDisplaySize()
    local screenHeight = size.nHeight
    local screenWidth = size.nWidth
    local winHeight = self.form:GetHeight()
    local winWidth = self.form:GetWidth()

    local left = (screenWidth - winWidth)/2
    local top = (screenHeight - winHeight)/2
 
    self.form:Move( left, top, winWidth, winHeight )

    self.form:Show(true)
  end
end

function ReportForm:hide()
  if self.visible then
    self.visible = false
    self.form:Show(false)
    local rowsN = tonumber( self.form:FindChild("RowsN"):GetText() )
    if rowsN and rowsN > 0 and rowsN <= 20 then
      DarkMeter.settings.reportRows = rowsN
    end
  end
end

function ReportForm:report(channel)

end


function ReportForm.controls:OnCancel()
  ReportForm:hide()
end

-- quick report button - say
function ReportForm.controls:OnSay()
  ReportForm.report("s")
end

-- quick report button - instance
function ReportForm.controls:OnInstance()
  ReportForm.report("i")
end

-- quick report button - guild
function ReportForm.controls:OnGuild()
  ReportForm.report("g")
end

-- quick report button - other channel
function ReportForm.controls:OnOther()
  local channel = ReportForm.form:FindChild("Channels"):FindChild("OtherChannel"):GetText()
  if string.len(channel) == 0 then
    Print("Please select a channel")
  end
  ReportForm.report(channel)
end

-- quick report button - whisper
function ReportForm.controls:OnWhisper()
  local target = ReportForm.form:FindChild("Channels"):FindChild("WhisperTo"):GetText()
  if string.len(target) == 0 then
    Print("Please select a target to whisper to")
    return
  end
  ReportForm.report("w " .. target)
end

-- write report on chat
function ReportForm.report(channel)
  if not UI.lastFight then 
    Print("No last fight!")
    return 
  end

  local stats = DarkMeter.settings.selectedStats
  local reportText = {}

  reportText[1] = "DarkMeter - " .. DMUtils:titleForStat(stats[1], false) .. " - " .. UI.lastFight:name()

    
  -- sort all group members by the main stat being monitored
  local orderedUnits = UI.lastFight:orderMembersBy(stats[1])
  
  local maxVal = 0
  for i = 1, #orderedUnits do
    maxVal = math.max(maxVal, orderedUnits[i][stats[1]](orderedUnits[i]) )
  end

  local rowsToReport = tonumber(ReportForm.maxRows:GetText())
  for i = 1, #orderedUnits do
    if i <= rowsToReport then
      local options = UI.MainForm:formatRowOptions(orderedUnits[i], UI.lastFight, 1, maxVal)
      reportText[i+1] = tostring(i) .. ") " .. options.name .. " - " .. options.text
    end
  end

  ReportForm:hide()

  for i = 1, #reportText do
    ChatSystemLib.Command("/" .. channel .. " " .. reportText[i])
  end
end

Apollo.RegisterPackage(ReportForm, "DarkMeter:ReportForm", 1, {"DarkMeter:UI"})