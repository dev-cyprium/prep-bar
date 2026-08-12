local M = PrepBar_ConsumeBar
local SLOT_ORDER = M.SLOT_ORDER

local function SavePosition()
    local point, _, rel, px, py = M.bar:GetPoint(1)
    M.db.point = { point, rel, px, py }
end

function M:Update()
    local bar, db, buttons = M.bar, M.db, M.buttons
    if not bar then return end
    if InCombatLockdown() then M.pending = true; return end
    M.pending = false

    if not db.enabled then
        UnregisterStateDriver(bar, "visibility")
        bar:Hide()
        if M.mover then M.mover:Hide() end
        return
    end
    -- Consumables are out-of-combat only, so hide the whole bar in combat. A
    -- secure visibility driver does the toggle, so we never Hide() a frame with
    -- protected buttons mid-fight (which would taint / error).
    RegisterStateDriver(bar, "visibility", "[combat] hide; show")

    local size, gap = db.buttonSize, db.buttonGap
    local data = PrepBar_Consumables and PrepBar_Consumables:GetForPlayer()
    local x, n = 0, 0
    for _, slot in ipairs(SLOT_ORDER) do
        local b = buttons[slot]
        if db.slots[slot] then
            M.ApplyButton(b, M.RecommendedID(slot, data))
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", x, 0)
            b:Show()
            x = x + size + gap
            n = n + 1
        else
            b:Hide()
        end
    end
    bar:SetSize(n > 0 and (n * size + (n - 1) * gap) or size, size)
    M.RefreshCounts()
end

function M:SetUnlocked(unlocked)
    local bar = M.bar
    if not bar then return end
    if M.mover then M.mover:SetShown(unlocked and M.db.enabled) end
    -- While unlocked, float the bar above the (fullscreen) settings panel so size
    -- and padding changes are visible live as you drag the sliders.
    bar:SetFrameStrata(unlocked and "FULLSCREEN_DIALOG" or "MEDIUM")
end

function M:Init()
    if M.bar then return end
    M.EnsureDB()
    if PrepBar_Overrides then
        PrepBar_Overrides:EnsureDB()
        for _, keys in pairs(PrepBar_Choices) do  -- cache names/icons for the settings dropdowns
            for _, key in ipairs(keys) do
                local id = PrepBar_Items[key] and PrepBar_Items[key][1]
                if id then C_Item.RequestLoadItemDataByID(id) end
            end
        end
    end

    local bar = CreateFrame("Frame", "PrepBarConsumeBar", UIParent)
    M.bar = bar
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:SetSize(M.db.buttonSize, M.db.buttonSize)
    bar:ClearAllPoints()
    bar:SetPoint(M.db.point[1], UIParent, M.db.point[2], M.db.point[3], M.db.point[4])

    M.buttons = {}
    for _, slot in ipairs(SLOT_ORDER) do
        M.buttons[slot] = M.CreateButton(slot, bar)
    end
    -- Per-slot overlays: quality on flask, feast on food.
    M.buttons.flask.toggle = M.CreateToggleOverlay(M.buttons.flask, "flask")
    M.buttons.food.toggle = M.CreateToggleOverlay(M.buttons.food, "food")

    local mover = CreateFrame("Frame", nil, bar)
    M.mover = mover
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
            if M.pending then M:Update() end
        else
            M:Update()  -- re-pick (fall back when preferred runs out); defers in combat
        end
    end)

    M:Update()
end
