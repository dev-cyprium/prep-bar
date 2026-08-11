local ADDON_NAME = "PrepBar"
local M = PrepBar_ConsumeBar
local SLOT_ORDER, SLOT_LABEL, DEFAULTS = M.SLOT_ORDER, M.SLOT_LABEL, M.DEFAULTS

-- Dropdown label for a food registry key: "|Ticon|t Item Name". Name comes from
-- cached item data (pre-warmed at login); falls back to the key until cached.
local function FoodLabel(key)
    local list = PrepBar_Items[key]
    local id = list and list[1]
    if not id then return key end
    local name = C_Item.GetItemInfo(id) or key
    local icon = select(5, C_Item.GetItemInfoInstant(id))
    if icon then return ("|T%d:16:16:0:0|t %s"):format(icon, name) end
    return name
end

local function ClassName(token)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
end

local function SpecsOfClass(token)
    local list = {}
    local specs = PrepBar_Specs and PrepBar_Specs[token]
    if specs then for _, id in pairs(specs) do list[#list + 1] = id end end
    table.sort(list)
    return list
end

local function SpecLabel(specID)
    local _, name, _, icon = GetSpecializationInfoForSpecID(specID)
    name = name or ("Spec " .. specID)
    if icon then return ("|T%d:16:16:0:0|t %s"):format(icon, name) end
    return name
end

-- Adds this module's controls to the shared PrepBar settings category.
function M:BuildSettings(category, layout)
    M.EnsureDB()
    local db = M.db
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Consumables Bar"))
    end

    local enabled = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_Enabled",
        "enabled", db, Settings.VarType.Boolean, "Show consumables bar", DEFAULTS.enabled)
    Settings.CreateCheckbox(category, enabled, "Show the consumables bar.")
    enabled:SetValueChangedCallback(function() M:Update() end)

    local proxy = { unlocked = false }  -- transient: never persisted, always starts locked
    local unlock = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_Unlock",
        "unlocked", proxy, Settings.VarType.Boolean, "Unlock bar (drag to move)", false)
    Settings.CreateCheckbox(category, unlock, "Show a drag handle to reposition the bar. Unlock to preview size and padding changes live.")
    unlock:SetValueChangedCallback(function(_, value) M:SetUnlocked(value) end)

    local size = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_ButtonSize",
        "buttonSize", db, Settings.VarType.Number, "Button size", DEFAULTS.buttonSize)
    local sizeOpts = Settings.CreateSliderOptions(16, 64, 2)
    if MinimalSliderWithSteppersMixin then
        sizeOpts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    Settings.CreateSlider(category, size, sizeOpts, "Size of each consumable button, in pixels.")
    size:SetValueChangedCallback(function() M:Update() end)

    local padding = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_ButtonGap",
        "buttonGap", db, Settings.VarType.Number, "Button padding", DEFAULTS.buttonGap)
    local padOpts = Settings.CreateSliderOptions(0, 24, 1)
    if MinimalSliderWithSteppersMixin then
        padOpts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    Settings.CreateSlider(category, padding, padOpts, "Space between buttons, in pixels.")
    padding:SetValueChangedCallback(function() M:Update() end)

    local threshold = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_LowThreshold",
        "lowThreshold", db, Settings.VarType.Number, "Low-stock glow threshold", DEFAULTS.lowThreshold)
    local options = Settings.CreateSliderOptions(0, 20, 1)
    if MinimalSliderWithSteppersMixin then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    Settings.CreateSlider(category, threshold, options, "Glow a button when you hold fewer than this many (0 = off).")
    threshold:SetValueChangedCallback(function() M.RefreshCounts() end)

    for _, slot in ipairs(SLOT_ORDER) do
        local s = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_Slot_" .. slot,
            slot, db.slots, Settings.VarType.Boolean, "Show " .. SLOT_LABEL[slot], true)
        Settings.CreateCheckbox(category, s, "Show the " .. SLOT_LABEL[slot]:lower() .. " button.")
        s:SetValueChangedCallback(function() M:Update() end)
    end

    self:BuildToggleSettings(category, layout)
    self:BuildFoodSettings(category, layout)
end

-- The per-slot overlay toggles: a master on/off plus which feast the food toggle swaps to.
function M:BuildToggleSettings(category, layout)
    local db = M.db
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Slot toggles"))
    end

    local show = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_ShowToggles",
        "showToggles", db, Settings.VarType.Boolean, "Show slot toggles", DEFAULTS.showToggles)
    Settings.CreateCheckbox(category, show,
        "Show small toggles on the flask (quality: Auto/Gold/Silver) and food (Current/Feast) buttons.")
    show:SetValueChangedCallback(function() M:Update() end)

    if PrepBar_Food and Settings.CreateDropdown then
        local feast = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_FeastFood",
            "feastFood", db, Settings.VarType.String, "Feast food", DEFAULTS.feastFood)
        Settings.CreateDropdown(category, feast, function()
            local c = Settings.CreateControlTextContainer()
            for _, key in ipairs(PrepBar_FoodChoices) do c:Add(key, FoodLabel(key)) end
            return c:GetData()
        end, "The food the food button's Feast toggle swaps to.")
        feast:SetValueChangedCallback(function() M:Update() end)
    end
end

-- Food override hierarchy (global < class < spec). Class/Spec picker dropdowns
-- default to the logged-in character but let you configure any class/spec.
-- A food value of "" means inherit, so a level falls through to the next.
function M:BuildFoodSettings(category, layout)
    if not (PrepBar_Food and Settings.CreateDropdown) then return end
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Food"))
    end
    local foodDB = PrepBar_Food:EnsureDB()

    local classes = {}
    for token in pairs(PrepBar_Specs) do classes[#classes + 1] = token end
    table.sort(classes, function(a, b) return ClassName(a) < ClassName(b) end)

    local curClass = UnitClassBase("player") or classes[1]
    local curSpecIndex = GetSpecialization and GetSpecialization()
    local curSpec = curSpecIndex and GetSpecializationInfo(curSpecIndex) or SpecsOfClass(curClass)[1]

    -- transient UI state: which class/spec the food dropdowns currently edit
    local proxy = {
        selClass  = curClass,
        selSpec   = curSpec or 0,
        classFood = foodDB.class[curClass] or "",
        specFood  = (curSpec and foodDB.spec[tostring(curSpec)]) or "",
    }

    local function FoodOptions(inheritLabel)
        return function()
            local c = Settings.CreateControlTextContainer()
            c:Add("", inheritLabel)
            for _, key in ipairs(PrepBar_FoodChoices) do
                c:Add(key, FoodLabel(key))
            end
            return c:GetData()
        end
    end

    -- Global food
    local g = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Food_Global",
        "global", foodDB, Settings.VarType.String, "Global food", "")
    Settings.CreateDropdown(category, g, FoodOptions("Default (Royal Roast)"),
        "Food used when no class or spec override is set.")
    g:SetValueChangedCallback(function() M:Update() end)

    -- Class picker + class food
    local clsPick = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Food_SelClass",
        "selClass", proxy, Settings.VarType.String, "Configure class", proxy.selClass)
    Settings.CreateDropdown(category, clsPick, function()
        local c = Settings.CreateControlTextContainer()
        for _, token in ipairs(classes) do c:Add(token, ClassName(token)) end
        return c:GetData()
    end, "Which class to set food for. Defaults to your current class.")

    local clsFood = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Food_Class",
        "classFood", proxy, Settings.VarType.String, "Class food", "")
    Settings.CreateDropdown(category, clsFood, FoodOptions("Inherit (global)"),
        "Food for every spec of the selected class. Overrides the global food.")
    clsFood:SetValueChangedCallback(function(_, v)
        foodDB.class[proxy.selClass] = (v ~= "") and v or nil
        M:Update()
    end)

    -- Spec picker + spec food
    local specPick = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Food_SelSpec",
        "selSpec", proxy, Settings.VarType.Number, "Configure spec", proxy.selSpec)
    Settings.CreateDropdown(category, specPick, function()
        local c = Settings.CreateControlTextContainer()
        for _, id in ipairs(SpecsOfClass(proxy.selClass)) do c:Add(id, SpecLabel(id)) end
        return c:GetData()
    end, "Which spec to set food for. Defaults to your current spec.")

    local specFood = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Food_Spec",
        "specFood", proxy, Settings.VarType.String, "Spec food", "")
    Settings.CreateDropdown(category, specFood, FoodOptions("Inherit (class)"),
        "Food for the selected spec. Overrides class and global.")
    specFood:SetValueChangedCallback(function(_, v)
        if proxy.selSpec and proxy.selSpec ~= 0 then
            foodDB.spec[tostring(proxy.selSpec)] = (v ~= "") and v or nil
        end
        M:Update()
    end)

    -- Switching class repoints both food dropdowns (and resets the spec picker).
    clsPick:SetValueChangedCallback(function(_, token)
        proxy.selClass = token
        local first = SpecsOfClass(token)[1] or 0
        proxy.selSpec = first
        specPick:SetValue(first)
        clsFood:SetValue(foodDB.class[token] or "")
        specFood:SetValue((first ~= 0 and foodDB.spec[tostring(first)]) or "")
    end)

    -- Switching spec repoints the spec food dropdown.
    specPick:SetValueChangedCallback(function(_, id)
        proxy.selSpec = id
        specFood:SetValue((id ~= 0 and foodDB.spec[tostring(id)]) or "")
    end)
end
