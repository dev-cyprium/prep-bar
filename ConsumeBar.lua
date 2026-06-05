local ADDON_NAME = "PrepBar"

-- One movable bar holding secure item buttons for the player's spec consumables.
-- All four are out-of-combat items, so buttons are (re)configured only outside
-- combat (SetAttribute is protected); changes during combat are deferred.

local SLOT_ORDER = { "food", "flask", "augmentRune", "oil" }
local SLOT_LABEL = {
    food = "Food", flask = "Flask", augmentRune = "Augment Rune", oil = "Oil",
}
-- Map a bar slot to the Consumables data key(s), in priority order.
local SLOT_SOURCES = {
    food        = { "food" },
    flask       = { "flask" },  -- "flask" and "phial" are the same thing
    augmentRune = { "augmentRune" },
    oil         = { "weaponOil" },
}

local BUTTON_SIZE, BUTTON_GAP = 36, 4

local DEFAULTS = {
    enabled = true,
    point   = { "CENTER", "CENTER", 0, -140 },
    slots   = { food = true, flask = true, augmentRune = true, oil = true },
    lowThreshold = 2,  -- glow when bag count is below this (0 = never)
}

local M = {}
PrepBar_ConsumeBar = M

local db, bar, mover, buttons, pending

----------------------------------------------------------------------
-- Item helpers
----------------------------------------------------------------------
local function ItemIcon(id)
    return (select(5, C_Item.GetItemInfoInstant(id)))
end

-- Crafted-quality badge atlas, or nil for items with no quality.
-- Use the exact atlas baked into the item link (e.g.
-- "Professions-ChatIcon-Quality-12-Tier2", the Midnight gold/silver gem) rather
-- than rebuilding it -- "Professions-Icon-Quality-Tier2" is the OLD DF icon set.
-- GetItemCraftedQualityByItemInfo returns nil for these items, so parse the link.
-- Link may be nil until item data is cached.
local function ItemQualityAtlas(id)
    local link = select(2, C_Item.GetItemInfo(id))
    return link and link:match("|A:(Professions[^:]+):") or nil
end

-- The item to use for a slot: the first OWNED ID in priority order (so it falls
-- back, e.g. gold -> silver, when you run out). If none are owned, the preferred
-- (first) ID, so the button still shows it with count 0 and the low-stock glow.
local function RecommendedID(slot, data)
    if not data then return nil end
    local GetCount = C_Item.GetItemCount or GetItemCount
    local preferred
    for _, key in ipairs(SLOT_SOURCES[slot]) do
        for _, id in ipairs(data[key] or {}) do
            if id and id ~= 0 then
                preferred = preferred or id
                if (GetCount(id) or 0) > 0 then return id end
            end
        end
    end
    return preferred
end

----------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------
local function ApplyButton(b, id)
    if id then
        b:SetAttribute("type", "item")
        b:SetAttribute("item", "item:" .. id)
        b.icon:SetTexture(ItemIcon(id) or 134400)
        b.icon:SetDesaturated(false)
        b.itemID = id
    else
        b:SetAttribute("type", nil)
        b:SetAttribute("item", nil)
        b.icon:SetTexture(134400)  -- question mark
        b.icon:SetDesaturated(true)
        b.itemID = nil
    end
    -- Quality badge is set in RefreshCounts (needs item data cached).
end

local function CreateButton(slot, parent)
    local b = CreateFrame("Button", "PrepBarConsume_" .. slot, parent, "SecureActionButtonTemplate")
    b:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    -- Register both edges; the secure environment fires once per the
    -- ActionButtonUseKeyDown cvar (up-only never fires when that cvar is set).
    b:RegisterForClicks("AnyUp", "AnyDown")

    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetColorTexture(0, 0, 0, 0.6)
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetPoint("TOPLEFT", -6, 6)
    b.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    -- Spell-proc alert glow: art surrounds the icon and bleeds past its edges.
    b.glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    b.glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()
    b.glowAnim = b.glow:CreateAnimationGroup()
    b.glowAnim:SetLooping("BOUNCE")
    local pulse = b.glowAnim:CreateAnimation("Alpha")
    pulse:SetFromAlpha(1)
    pulse:SetToAlpha(0.25)
    pulse:SetDuration(0.6)

    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)

    b.quality = b:CreateTexture(nil, "OVERLAY")
    b.quality:SetPoint("TOPLEFT", 1, -1)
    b.quality:SetSize(14, 14)
    b.quality:Hide()

    b:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function SetGlow(b, on)
    if on then
        b.glow:Show()
        b.glowAnim:Play()
    else
        b.glowAnim:Stop()
        b.glow:Hide()
    end
end

-- Bag count + low-stock glow. Touches only textures/fontstrings, so it is
-- safe to run in combat (unlike the secure attribute set in M:Update).
local function RefreshCounts()
    if not buttons then return end
    local GetCount = C_Item.GetItemCount or GetItemCount
    for _, slot in ipairs(SLOT_ORDER) do
        local b = buttons[slot]
        if db.enabled and db.slots[slot] and b.itemID then
            local count = GetCount(b.itemID) or 0
            b.count:SetText(count)
            SetGlow(b, count < (db.lowThreshold or 0))
            local atlas = ItemQualityAtlas(b.itemID)
            if atlas then b.quality:SetAtlas(atlas, false) end
            b.quality:SetShown(atlas ~= nil)
        else
            b.count:SetText("")
            SetGlow(b, false)
            b.quality:Hide()
        end
    end
end

----------------------------------------------------------------------
-- Bar
----------------------------------------------------------------------
local function EnsureDB()
    PrepBarDB.consumeBar = PrepBarDB.consumeBar or {}
    db = PrepBarDB.consumeBar
    if db.enabled == nil then db.enabled = DEFAULTS.enabled end
    db.point = db.point or { unpack(DEFAULTS.point) }
    db.slots = db.slots or {}
    for k, v in pairs(DEFAULTS.slots) do
        if db.slots[k] == nil then db.slots[k] = v end
    end
    if db.lowThreshold == nil then db.lowThreshold = DEFAULTS.lowThreshold end
end

function M:Update()
    if not bar then return end
    if InCombatLockdown() then pending = true; return end
    pending = false

    if not db.enabled then
        UnregisterStateDriver(bar, "visibility")
        bar:Hide()
        if mover then mover:Hide() end
        return
    end
    -- Consumables are out-of-combat only, so hide the whole bar in combat. A
    -- secure visibility driver does the toggle, so we never Hide() a frame with
    -- protected buttons mid-fight (which would taint / error).
    RegisterStateDriver(bar, "visibility", "[combat] hide; show")

    local data = PrepBar_Consumables and PrepBar_Consumables:GetForPlayer()
    local x, n = 0, 0
    for _, slot in ipairs(SLOT_ORDER) do
        local b = buttons[slot]
        if db.slots[slot] then
            ApplyButton(b, RecommendedID(slot, data))
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", x, 0)
            b:Show()
            x = x + BUTTON_SIZE + BUTTON_GAP
            n = n + 1
        else
            b:Hide()
        end
    end
    bar:SetSize(n > 0 and (n * BUTTON_SIZE + (n - 1) * BUTTON_GAP) or BUTTON_SIZE, BUTTON_SIZE)
    RefreshCounts()
end

function M:SetUnlocked(unlocked)
    if mover then mover:SetShown(unlocked and db.enabled) end
end

local function SavePosition()
    local point, _, rel, px, py = bar:GetPoint(1)
    db.point = { point, rel, px, py }
end

function M:Init()
    if bar then return end
    EnsureDB()

    bar = CreateFrame("Frame", "PrepBarConsumeBar", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    bar:ClearAllPoints()
    bar:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])

    buttons = {}
    for _, slot in ipairs(SLOT_ORDER) do
        buttons[slot] = CreateButton(slot, bar)
    end

    mover = CreateFrame("Frame", nil, bar)
    mover:SetAllPoints()
    mover:SetFrameLevel(bar:GetFrameLevel() + 10)  -- above the buttons so it gets the drag
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()
    local bg = mover:CreateTexture(nil, "OVERLAY")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.6, 1, 0.35)
    local label = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetText("drag")
    mover:SetScript("OnDragStart", function()
        if not InCombatLockdown() then bar:StartMoving() end
    end)
    mover:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        SavePosition()
    end)

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pending then M:Update() end
        elseif event == "BAG_UPDATE_DELAYED" then
            M:Update()  -- re-pick (fall back when preferred runs out); defers in combat
        else
            M:Update()
        end
    end)

    M:Update()
end

-- Adds this module's controls to the shared PrepBar settings category.
function M:BuildSettings(category, layout)
    EnsureDB()
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
    Settings.CreateCheckbox(category, unlock, "Show a drag handle to reposition the bar. Re-lock when done.")
    unlock:SetValueChangedCallback(function(_, value) M:SetUnlocked(value) end)

    local threshold = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_LowThreshold",
        "lowThreshold", db, Settings.VarType.Number, "Low-stock glow threshold", DEFAULTS.lowThreshold)
    local options = Settings.CreateSliderOptions(0, 20, 1)
    if MinimalSliderWithSteppersMixin then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    Settings.CreateSlider(category, threshold, options, "Glow a button when you hold fewer than this many (0 = off).")
    threshold:SetValueChangedCallback(function() RefreshCounts() end)

    for _, slot in ipairs(SLOT_ORDER) do
        local s = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_ConsumeBar_Slot_" .. slot,
            slot, db.slots, Settings.VarType.Boolean, "Show " .. SLOT_LABEL[slot], true)
        Settings.CreateCheckbox(category, s, "Show the " .. SLOT_LABEL[slot]:lower() .. " button.")
        s:SetValueChangedCallback(function() M:Update() end)
    end
end
