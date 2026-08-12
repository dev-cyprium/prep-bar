local ADDON_NAME = "PrepBar"
local M = PrepBar_ConsumeBar
local SLOT_ORDER, SLOT_LABEL, DEFAULTS = M.SLOT_ORDER, M.SLOT_LABEL, M.DEFAULTS

-- Override slots exposed in the settings UI, in display order.
local OV_SLOTS = {
    { slot = "flask", label = "Flask" },
    { slot = "food",  label = "Food" },
    { slot = "oil",   label = "Oil" },
}

-- Dropdown label for a registry key: "|Ticon|t Item Name". Name comes from
-- cached item data (pre-warmed at login); falls back to the key until cached.
local function ItemLabel(key)
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

local function ChoiceOptions(slot, inheritLabel)
    return function()
        local c = Settings.CreateControlTextContainer()
        c:Add("", inheritLabel)
        for _, key in ipairs(PrepBar_Choices[slot]) do c:Add(key, ItemLabel(key)) end
        return c:GetData()
    end
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
    self:BuildOverrideSettings(category, layout)
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

    if PrepBar_Overrides and Settings.CreateDropdown then
        local feast = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_FeastFood",
            "feastFood", db, Settings.VarType.String, "Feast food", DEFAULTS.feastFood)
        Settings.CreateDropdown(category, feast, function()
            local c = Settings.CreateControlTextContainer()
            for _, key in ipairs(PrepBar_Choices.food) do c:Add(key, ItemLabel(key)) end
            return c:GetData()
        end, "The food the food button's Feast toggle swaps to.")
        feast:SetValueChangedCallback(function() M:Update() end)
    end
end

-- Per-slot override hierarchy (global < class < spec) for flask, food and oil.
-- Class/Spec picker dropdowns default to the logged-in character but let you
-- configure any class/spec. A value of "" means inherit from the next level.
function M:BuildOverrideSettings(category, layout)
    if not (PrepBar_Overrides and Settings.CreateDropdown) then return end
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Consumable overrides"))
    end
    local ov = PrepBar_Overrides:EnsureDB()

    local classes = {}
    for token in pairs(PrepBar_Specs) do classes[#classes + 1] = token end
    table.sort(classes, function(a, b) return ClassName(a) < ClassName(b) end)

    local curClass = UnitClassBase("player") or classes[1]
    local curSpecIndex = GetSpecialization and GetSpecialization()
    local curSpec = curSpecIndex and GetSpecializationInfo(curSpecIndex) or SpecsOfClass(curClass)[1]

    -- transient UI state: which class/spec the class/spec dropdowns edit, plus
    -- the currently-shown value for each slot's class and spec dropdown.
    local proxy = { selClass = curClass, selSpec = curSpec or 0, classVal = {}, specVal = {} }
    for _, s in ipairs(OV_SLOTS) do
        proxy.classVal[s.slot] = ov[s.slot].class[curClass] or ""
        proxy.specVal[s.slot]  = (curSpec and ov[s.slot].spec[tostring(curSpec)]) or ""
    end

    local classDrops, specDrops = {}, {}

    -- Global scope: one dropdown per slot, bound straight to ov[slot].global.
    for _, s in ipairs(OV_SLOTS) do
        local set = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Ov_Global_" .. s.slot,
            "global", ov[s.slot], Settings.VarType.String, "Global " .. s.label, "")
        Settings.CreateDropdown(category, set, ChoiceOptions(s.slot, "Default (shipped)"),
            "Global " .. s.label:lower() .. ", used when no class or spec override is set.")
        set:SetValueChangedCallback(function() M:Update() end)
    end

    -- Class picker + one dropdown per slot (written through to ov[slot].class[selClass]).
    local clsPick = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Ov_SelClass",
        "selClass", proxy, Settings.VarType.String, "Configure class", proxy.selClass)
    Settings.CreateDropdown(category, clsPick, function()
        local c = Settings.CreateControlTextContainer()
        for _, token in ipairs(classes) do c:Add(token, ClassName(token)) end
        return c:GetData()
    end, "Which class to set overrides for. Defaults to your current class.")

    for _, s in ipairs(OV_SLOTS) do
        local set = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Ov_Class_" .. s.slot,
            s.slot, proxy.classVal, Settings.VarType.String, s.label .. " (class)", "")
        Settings.CreateDropdown(category, set, ChoiceOptions(s.slot, "Inherit (global)"),
            s.label .. " for every spec of the selected class.")
        set:SetValueChangedCallback(function(_, v)
            ov[s.slot].class[proxy.selClass] = (v ~= "") and v or nil
            M:Update()
        end)
        classDrops[s.slot] = set
    end

    -- Spec picker + one dropdown per slot (written through to ov[slot].spec[selSpec]).
    local specPick = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Ov_SelSpec",
        "selSpec", proxy, Settings.VarType.Number, "Configure spec", proxy.selSpec)
    Settings.CreateDropdown(category, specPick, function()
        local c = Settings.CreateControlTextContainer()
        for _, id in ipairs(SpecsOfClass(proxy.selClass)) do c:Add(id, SpecLabel(id)) end
        return c:GetData()
    end, "Which spec to set overrides for. Defaults to your current spec.")

    for _, s in ipairs(OV_SLOTS) do
        local set = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_Ov_Spec_" .. s.slot,
            s.slot, proxy.specVal, Settings.VarType.String, s.label .. " (spec)", "")
        Settings.CreateDropdown(category, set, ChoiceOptions(s.slot, "Inherit (class)"),
            s.label .. " for the selected spec. Overrides class and global.")
        set:SetValueChangedCallback(function(_, v)
            if proxy.selSpec and proxy.selSpec ~= 0 then
                ov[s.slot].spec[tostring(proxy.selSpec)] = (v ~= "") and v or nil
            end
            M:Update()
        end)
        specDrops[s.slot] = set
    end

    -- Switching class resets the spec picker and repoints every class/spec dropdown.
    clsPick:SetValueChangedCallback(function(_, token)
        proxy.selClass = token
        local first = SpecsOfClass(token)[1] or 0
        proxy.selSpec = first
        specPick:SetValue(first)
        for _, s in ipairs(OV_SLOTS) do
            proxy.classVal[s.slot] = ov[s.slot].class[token] or ""
            classDrops[s.slot]:SetValue(proxy.classVal[s.slot])
            proxy.specVal[s.slot] = (first ~= 0 and ov[s.slot].spec[tostring(first)]) or ""
            specDrops[s.slot]:SetValue(proxy.specVal[s.slot])
        end
    end)

    -- Switching spec repoints every spec dropdown.
    specPick:SetValueChangedCallback(function(_, id)
        proxy.selSpec = id
        for _, s in ipairs(OV_SLOTS) do
            proxy.specVal[s.slot] = (id ~= 0 and ov[s.slot].spec[tostring(id)]) or ""
            specDrops[s.slot]:SetValue(proxy.specVal[s.slot])
        end
    end)
end
