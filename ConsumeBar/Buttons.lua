local M = PrepBar_ConsumeBar
local SLOT_ORDER = M.SLOT_ORDER

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

function M.ApplyButton(b, id)
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

function M.CreateButton(slot, parent)
    local b = CreateFrame("Button", "PrepBarConsume_" .. slot, parent, "SecureActionButtonTemplate")
    b:SetSize(M.db.buttonSize, M.db.buttonSize)
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

-- A small click-to-toggle overlay in the top-right corner of a slot button.
-- Non-secure (like the mover), so its OnClick only writes saved vars + Update();
-- it never calls SetAttribute. flask = cycle Auto/Gold/Silver, food = Current/Feast.
function M.CreateToggleOverlay(b, slot)
    local t = CreateFrame("Button", nil, b)
    t:SetSize(14, 14)
    t:SetFrameLevel(b:GetFrameLevel() + 5)
    t:SetPoint("TOPRIGHT", 1, 1)

    local bg = t:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.75)

    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.label:SetPoint("CENTER", 0, 0)

    t:SetScript("OnClick", function()
        local ov = M.db.overrides
        if slot == "flask" then
            ov.flask.tier = (ov.flask.tier + 1) % 3  -- Auto -> Gold -> Silver -> Auto
        else
            ov.food.feast = not ov.food.feast
        end
        M:Update()
    end)
    t:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if slot == "flask" then
            GameTooltip:AddLine("Flask quality")
            GameTooltip:AddLine("Click to cycle Auto -> Gold -> Silver.", 1, 1, 1)
            GameTooltip:AddLine("Auto uses the best you own. Forcing a tier you don't own shows 0 with no fallback.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("Food: Current / Feast")
            GameTooltip:AddLine("Click to toggle between your spec food and the feast.", 1, 1, 1)
            local list = M.db.feastFood and PrepBar_Items[M.db.feastFood]
            local fname = list and list[1] and C_Item.GetItemInfo(list[1])
            if fname then GameTooltip:AddLine("Feast: " .. fname, 0.8, 0.8, 0.8) end
        end
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", GameTooltip_Hide)
    return t
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

-- Show/label the flask and food overlays based on current state.
local function RefreshToggles()
    local buttons, db = M.buttons, M.db
    if not buttons then return end
    for _, slot in ipairs({ "flask", "food" }) do
        local b = buttons[slot]
        local t = b and b.toggle
        if t then
            if db.showToggles and db.slots[slot] then
                if slot == "flask" then
                    local tier = db.overrides.flask.tier
                    t.label:SetText(tier == 0 and "A" or (tier == 1 and "G" or "S"))
                else
                    t.label:SetText(db.overrides.food.feast and "F" or "C")
                end
                t:Show()
            else
                t:Hide()
            end
        end
    end
end

-- Bag count + low-stock glow. Touches only textures/fontstrings, so it is
-- safe to run in combat (unlike the secure attribute set in M:Update).
function M.RefreshCounts()
    local buttons, db = M.buttons, M.db
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
    RefreshToggles()
end
