
local ResetForm = {}            -- prompt reset data form and all the correlated functions
ResetForm.controls = {}         -- form controls
local UI


function ResetForm:init(xmlDoc)
  UI = Apollo.GetPackage("DarkMeter:UI").tPackage
  
  if xmlDoc ~= nil and xmlDoc:IsLoaded() then
    ResetForm.form = Apollo.LoadForm(xmlDoc, "ResetForm", nil, ResetForm.controls)
    ResetForm.form:Show(false)
  else
    Apollo.AddAddonErrorText(DarkMeter, "Cannot initialize ResetForm, xmlDoc is nil or not loaded.")
  end
end



-------------------------------------------------------------
-- ResetForm functions
-------------------------------------------------------------

-- display do you want to reset the data?
function ResetForm:show()
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

-- hides reset form
function ResetForm:hide()
  if self.visible then
    self.visible = false
    self.form:Show(false)
  end
end

-- reset the data upon confirmation
function ResetForm.controls:OnOk()
  ResetForm:hide()
  UI:resetData()

end

-- just closes the reset form
function ResetForm.controls:OnCancel()
  ResetForm:hide()
end


Apollo.RegisterPackage(ResetForm, "DarkMeter:ResetForm", 1, {"DarkMeter:UI"})