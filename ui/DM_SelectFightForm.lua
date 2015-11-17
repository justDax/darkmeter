
local SelectFight = {}            -- prompt reset data form and all the correlated functions
SelectFight.controls = {}         -- form controls
local UI
local DarkMeter


function SelectFight:init(xmlDoc)
  UI = Apollo.GetPackage("DarkMeter:UI").tPackage
  DarkMeter = Apollo.GetAddon("DarkMeter")

  if xmlDoc ~= nil and xmlDoc:IsLoaded() then
    SelectFight.form = Apollo.LoadForm(xmlDoc, "SelectFightForm", nil, SelectFight.controls)
    SelectFight.form:Show(false)
  else
    Apollo.AddAddonErrorText(DarkMeter, "Cannot initialize SelectFightForm, xmlDoc is nil or not loaded.")
  end
end


-------------------------------------------------------------
-- SelectFight functions
-------------------------------------------------------------

-- display form
function SelectFight:show()
  local size = Apollo.GetDisplaySize()
  local screenHeight = size.nHeight
  local screenWidth = size.nWidth
  local winHeight = self.form:GetHeight()
  local winWidth = self.form:GetWidth()

  local left = (screenWidth - winWidth)/2
  local top = (screenHeight - winHeight)/2

  self.form:Move( left, top, winWidth, winHeight )

  -- set text buttons
  local buttons = self.form:FindChild("Buttons")
  for i = 1, 5 do
    local button = buttons:FindChild("Fight"..i)
    local fight = DarkMeter:specificFightByIndex(i)

    if fight ~= nil then
      SelectFight.controls:enableButton(button)
      local text = button:FindChild("Name")
      text:SetText( fight:name() )
    else
      SelectFight.controls:disableButton(button)
    end
  end

  self.form:Show(true)
end

function SelectFight:hide()
  self.form:Show(false)
end


function SelectFight.controls:enableButton(button)
  button:Enable(true)
  local bgHover = button:FindChild("Bg")
  local color = ApolloColor.new("ffe8d60d")
  local colorHover = ApolloColor.new("ff8f840a")
  button:SetBGColor(color)
  bgHover:SetBGColor(colorHover)
end

function SelectFight.controls:disableButton(button)
  local text = button:FindChild("Name")
  text:SetText("")
  button:SetBGColor( ApolloColor.new("ff666666") )
  button:Enable(false)
end


function SelectFight.controls:OnOverall()
  DarkMeter.settings.overall = true
  DarkMeter.specificFight = nil
  DarkMeter:updateUI()
  UI.MainForm:setTracked()
end

function SelectFight.controls:OnCurrent()
  DarkMeter.settings.overall = false
  DarkMeter.specificFight = nil
  DarkMeter:updateUI()
  UI.MainForm:setTracked()
end

-- btn functions from 1 to 5
for i = 1, 5 do
  SelectFight.controls["OnFightBtn"..i] = function()
    DarkMeter.settings.overall = false
    DarkMeter.specificFight = DarkMeter:specificFightByIndex(i)
    DarkMeter:updateUI()
    UI.MainForm:setTracked()
  end
end

Apollo.RegisterPackage(SelectFight, "DarkMeter:SelectFight", 1, {"DarkMeter:UI"})