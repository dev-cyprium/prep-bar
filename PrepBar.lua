local ADDON_NAME = "PrepBar"

local SUPPORTED_BARS = {
    "MainMenuBar",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
    "StanceBar",
    "PetActionBar",
}

local DEFAULTS = {
    bars         = { MultiBar7 = true },  -- your original target on by default
    hiddenAlpha  = 0.05,
    shownAlpha   = 1,
    pollInterval = 0.1,
    hideDelay    = 0.15,
}

----------------------------------------------------------------------
-- Controller (one per bar)
----------------------------------------------------------------------
local controllers = {}

local function NewController(barName)
    local bar = _G[barName]
    if not bar then return nil end

    local self = { bar = bar, children = {}, accum = 0, hideAccum = 0, shown = true }

    local function RefreshChildren()
        wipe(self.children)
        for _, child in ipairs({ bar:GetChildren() }) do
            self.children[#self.children + 1] = child
        end
    end

    local function MouseIsOverBar()
        if MouseIsOver(bar) then return true end
        for i = 1, #self.children do
            local c = self.children[i]
            if c:IsShown() and MouseIsOver(c) then return true end
        end
        return false
    end

    self.updater = CreateFrame("Frame")
    self.updater:Hide()
    self.updater:SetScript("OnUpdate", function(_, dt)
        self.accum = self.accum + dt
        if self.accum < PrepBarDB.pollInterval then return end
        self.accum = 0

        if MouseIsOverBar() then
            self.hideAccum = 0
            if not self.shown then
                bar:SetAlpha(PrepBarDB.shownAlpha)
                self.shown = true
            end
        elseif self.shown then
            self.hideAccum = self.hideAccum + PrepBarDB.pollInterval
            if self.hideAccum >= PrepBarDB.hideDelay then
                bar:SetAlpha(PrepBarDB.hiddenAlpha)
                self.shown = false
            end
        end
    end)

    self.events = CreateFrame("Frame")
    for _, ev in ipairs({
        "PLAYER_ENTERING_WORLD", "UPDATE_BONUS_ACTIONBAR",
        "ACTIONBAR_PAGE_CHANGED", "UPDATE_VEHICLE_ACTIONBAR",
    }) do self.events:RegisterEvent(ev) end
    self.events:SetScript("OnEvent", RefreshChildren)

    function self:Enable()
        RefreshChildren()
        bar:SetAlpha(PrepBarDB.hiddenAlpha)
        self.shown = false
        self.updater:Show()
    end

    function self:Disable()
        self.updater:Hide()
        bar:SetAlpha(PrepBarDB.shownAlpha)
        self.shown = true
    end

    return self
end

local function ApplyBar(barName, enabled)
    local c = controllers[barName]
    if enabled then
        c = c or NewController(barName)
        if not c then return end
        controllers[barName] = c
        c:Enable()
    elseif c then
        c:Disable()
    end
end

local function ApplyAll()
    for _, name in ipairs(SUPPORTED_BARS) do
        ApplyBar(name, PrepBarDB.bars[name] == true)
    end
end

----------------------------------------------------------------------
-- Settings panel  (Esc → Options → AddOns → PrepBar)
----------------------------------------------------------------------
local settingsCategory

local function BuildSettingsPanel()
    local category, layout = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)
    settingsCategory = category

    for _, barName in ipairs(SUPPORTED_BARS) do
        local setting = Settings.RegisterAddOnSetting(
            category,
            ADDON_NAME .. "_" .. barName,
            barName,
            PrepBarDB.bars,
            Settings.VarType.Boolean,
            barName,
            false
        )
        Settings.CreateCheckbox(category, setting,
            "Fade " .. barName .. " unless the mouse is over it.")
        setting:SetValueChangedCallback(function(_, value)
            ApplyBar(barName, value)
        end)
    end

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
local function InitDB()
    PrepBarDB = PrepBarDB or {}
    for k, v in pairs(DEFAULTS) do
        if PrepBarDB[k] == nil then
            if type(v) == "table" then
                PrepBarDB[k] = {}
                for kk, vv in pairs(v) do PrepBarDB[k][kk] = vv end
            else
                PrepBarDB[k] = v
            end
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        InitDB()
        BuildSettingsPanel()
    elseif event == "PLAYER_LOGIN" then
        ApplyAll()
        if PrepBar_ConsumeBar then PrepBar_ConsumeBar:Init() end
    end
end)