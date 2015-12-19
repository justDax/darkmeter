
local DeathRecapForm = {}            -- prompt reset data form and all the correlated functions
DeathRecapForm.controls = {}         -- form controls
DeathRecapForm.death = nil
local UI
local DarkMeter


function DeathRecapForm:init(xmlDoc)
  UI = Apollo.GetPackage("DarkMeter:UI").tPackage
  DarkMeter = Apollo.GetAddon("DarkMeter")

  if xmlDoc ~= nil and xmlDoc:IsLoaded() then
    DeathRecapForm.form = Apollo.LoadForm(xmlDoc, "DeathRecapForm", nil, DeathRecapForm.controls)
    DeathRecapForm.form:Show(false)
  else
    Apollo.AddAddonErrorText(DarkMeter, "Cannot initialize DeathRecapForm, xmlDoc is nil or not loaded.")
  end
end


-------------------------------------------------------------
-- DeathRecapForm
-------------------------------------------------------------

function DeathRecapForm:show()
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

    self.form:Show(true)
  end
end

function DeathRecapForm:hide()
  if self.visible then
    self.visible = false
    self.form:Show(false)
  end
end


function DeathRecapForm.controls:OnCancel()
  DeathRecapForm:hide()
end

-- quick report button - say
function DeathRecapForm.controls:OnSay()
  DeathRecapForm.report("s")
end

-- quick report button - instance
function DeathRecapForm.controls:OnInstance()
  DeathRecapForm.report("i")
end

-- quick report button - guild
function DeathRecapForm.controls:OnGuild()
  DeathRecapForm.report("g")
end

-- quick report button - other channel
function DeathRecapForm.controls:OnOther()
  local channel = DeathRecapForm.form:FindChild("Channels"):FindChild("OtherChannel"):GetText()
  if string.len(channel) == 0 then
    ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Please select a channel", "DarkMeter")
  end
  DeathRecapForm.report(channel)
end

-- quick report button - whisper
function DeathRecapForm.controls:OnWhisper()
  local target = DeathRecapForm.form:FindChild("Channels"):FindChild("WhisperTo"):GetText()
  if string.len(target) == 0 then
    ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "Please write the name of the target to whisper to", "DarkMeter")
    return
  end
  DeathRecapForm.report("w " .. target)
end

-- write report on chat
function DeathRecapForm.report(channel)
  if not DeathRecapForm.death then
    ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "No death to report", "DarkMeter")
    return 
  end

  local reportText = {}
  
  local data = DeathRecapForm.death
  local counter = 0
  local targetName = data.skills[1].targetName
  local time = ("%02d"):format(data.timestamp.nHour) .. ":" .. ("%02d"):format(data.timestamp.nMinute)
  reportText[1] = "DarkMeter - Death recap for: " .. targetName .. " (" .. time .. ")"

  for i = #data.skills, 1, -1 do
    counter = counter + 1
    local skill = data.skills[i]
    local text = skill.name
    if i == 1 then
      text = "[R.I.P.] " .. text
    end

    reportText[counter + 1] = counter .. ") " .. text .. " - " .. skill.damage
  end

  DeathRecapForm:hide()

  for i = 1, #reportText do
    ChatSystemLib.Command("/" .. channel .. " " .. reportText[i])
  end
end

Apollo.RegisterPackage(DeathRecapForm, "DarkMeter:DeathRecapForm", 1, {"DarkMeter:UI"})