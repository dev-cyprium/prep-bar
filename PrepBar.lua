local ADDON_NAME = "PrepBar"

----------------------------------------------------------------------
-- Settings panel  (Esc → Options → AddOns → PrepBar)
----------------------------------------------------------------------
local settingsCategory

local function BuildSettingsPanel()
    local category, layout = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)
    settingsCategory = category

    if PrepBar_ConsumeBar then
        PrepBar_ConsumeBar:BuildSettings(category, layout)
    end

    Settings.RegisterAddOnCategory(category)

    SLASH_PREPBAR1 = "/pb"
    SLASH_PREPBAR2 = "/prepbar"
    SlashCmdList["PREPBAR"] = function()
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        PrepBarDB = PrepBarDB or {}
    elseif event == "PLAYER_LOGIN" then
        if PrepBar_ConsumeBar then PrepBar_ConsumeBar:Init() end
        BuildSettingsPanel()  -- after login so the current spec is known for the food dropdowns
    end
end)
