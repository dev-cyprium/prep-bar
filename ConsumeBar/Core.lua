-- One movable bar holding secure item buttons for the player's spec consumables.
-- All four are out-of-combat items, so buttons are (re)configured only outside
-- combat (SetAttribute is protected); changes during combat are deferred.
--
-- The module is split across ConsumeBar\Core, Buttons, Bar and Settings; all
-- attach to this one table and share state through its fields (M.db, M.bar, ...).
local M = {}
PrepBar_ConsumeBar = M

M.SLOT_ORDER = { "food", "flask", "augmentRune", "oil" }
M.SLOT_LABEL = {
    food = "Food", flask = "Flask", augmentRune = "Augment Rune", oil = "Oil",
}
-- Map a bar slot to the Consumables data key(s), in priority order.
local SLOT_SOURCES = {
    food        = { "food" },
    flask       = { "flask" },
    augmentRune = { "augmentRune" },
    oil         = { "weaponOil" },
}

local DEFAULT_FEAST_KEY = "FOOD_BLOOMING_FEAST"

M.DEFAULTS = {
    enabled = true,
    point   = { "CENTER", "CENTER", 0, -140 },
    slots   = { food = true, flask = true, augmentRune = true, oil = true },
    lowThreshold = 2,  -- glow when bag count is below this (0 = never)
    buttonSize = 36,
    buttonGap  = 4,    -- padding between buttons
    showToggles = false,             -- master gate for the per-slot overlays
    feastFood   = DEFAULT_FEAST_KEY,  -- PrepBar_Items key the food feast swaps to
    overrides   = {
        flask = { tier = 0 },    -- 0 = Auto (best owned); 1 = Gold; 2 = Silver
        food  = { feast = false },
    },
}

function M.EnsureDB()
    PrepBarDB.consumeBar = PrepBarDB.consumeBar or {}
    local db = PrepBarDB.consumeBar
    M.db = db
    local D = M.DEFAULTS
    if db.enabled == nil then db.enabled = D.enabled end
    db.point = db.point or { unpack(D.point) }
    db.slots = db.slots or {}
    for k, v in pairs(D.slots) do
        if db.slots[k] == nil then db.slots[k] = v end
    end
    if db.lowThreshold == nil then db.lowThreshold = D.lowThreshold end
    if db.buttonSize == nil then db.buttonSize = D.buttonSize end
    if db.buttonGap == nil then db.buttonGap = D.buttonGap end
    if db.showToggles == nil then db.showToggles = D.showToggles end
    if db.feastFood == nil then db.feastFood = D.feastFood end
    db.overrides = db.overrides or {}
    db.overrides.flask = db.overrides.flask or {}
    if db.overrides.flask.tier == nil then db.overrides.flask.tier = 0 end
    db.overrides.food = db.overrides.food or {}
    if db.overrides.food.feast == nil then db.overrides.food.feast = false end
    return db
end

-- The candidate item IDs for a slot, honoring per-slot overrides:
--   flask + forced tier -> just that crafted tier (no auto fallback)
--   food + feast on     -> the feast food's tier list
-- Otherwise the slot's normal data keys. Always returns a fresh list, never the
-- registered spec table, so Consumables' in-place merge stays clean.
local function CandidateIDs(slot, data)
    local db = M.db
    local ov = db and db.overrides
    if slot == "flask" and ov and ov.flask.tier ~= 0 then
        local id = data and data.flask and data.flask[ov.flask.tier]
        if id then return { id } end
    elseif slot == "food" and ov and ov.food.feast then
        local list = PrepBar_Items[db.feastFood or DEFAULT_FEAST_KEY]
        if list then return list end
    end
    local out = {}
    for _, key in ipairs(SLOT_SOURCES[slot]) do
        for _, id in ipairs((data and data[key]) or {}) do out[#out + 1] = id end
    end
    return out
end

-- The item to use for a slot: the first OWNED ID in priority order (so it falls
-- back, e.g. gold -> silver, when you run out). If none are owned, the preferred
-- (first) ID, so the button still shows it with count 0 and the low-stock glow.
function M.RecommendedID(slot, data)
    if not data then return nil end
    local GetCount = C_Item.GetItemCount or GetItemCount
    local preferred
    for _, id in ipairs(CandidateIDs(slot, data)) do
        if id and id ~= 0 then
            preferred = preferred or id
            if (GetCount(id) or 0) > 0 then return id end
        end
    end
    return preferred
end
