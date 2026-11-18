local addonName = ...
local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    self:UnregisterEvent(event)
    print("|cffcc3333Mortal Enemy|r loaded successfully.")
end)
