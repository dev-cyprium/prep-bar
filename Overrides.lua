-- Per-slot consumable overrides. A player-chosen item for a slot at spec beats
-- one for the class, which beats a global one, which beats the shipped default
-- (most specific wins). Choices are stored in PrepBarDB.overrides as
-- PrepBar_Items keys ("" = inherit). Covers flask, food and weapon oil.
PrepBar_Choices = {
    flask = {
        "FLASK_BLOOD_KNIGHTS",
        "FLASK_SHATTERED_SUN",
        "FLASK_THALASSIAN_RESISTANCE",
        "FLASK_MAGISTERS",
    },
    food = {
        "FOOD_ROYAL_ROAST",
        "FOOD_IMPOSSIBLY_ROYAL_ROAST",
        "FOOD_QUELDOREI_MEDLEY",
        "FOOD_BLOOMING_FEAST",
        "FOOD_CHAMPIONS_BENTO",
        "FOOD_SILVERMOON_PARADE",
        "FOOD_HARANDAR_CELEBRATION",
        "FOOD_FLORA_FRENZY",
    },
    oil = { "OIL_PHOENIX" },
}

-- Iteration order + each override slot's key in the Consumables slots table.
PrepBar_OverrideSlots = { "flask", "food", "oil" }
local DATA_KEY = { flask = "flask", food = "food", oil = "weaponOil" }

PrepBar_Overrides = {}

function PrepBar_Overrides:DataKey(slot)
    return DATA_KEY[slot]
end

function PrepBar_Overrides:EnsureDB()
    PrepBarDB.overrides = PrepBarDB.overrides or {}
    local o = PrepBarDB.overrides
    -- Migrate the old food-only table (PrepBarDB.food) into the unified store.
    if PrepBarDB.food and not o.food then
        o.food = PrepBarDB.food
        PrepBarDB.food = nil
    end
    for slot in pairs(PrepBar_Choices) do
        o[slot] = o[slot] or {}
        o[slot].class = o[slot].class or {}
        o[slot].spec  = o[slot].spec or {}
        if o[slot].global == nil then o[slot].global = "" end
    end
    return o
end

-- The override key for slot at the most specific set scope, or nil (inherit all).
function PrepBar_Overrides:Key(slot, classToken, specID)
    local o = PrepBarDB and PrepBarDB.overrides and PrepBarDB.overrides[slot]
    if not o then return nil end
    local key = (specID and o.spec and o.spec[tostring(specID)])
             or (classToken and o.class and o.class[classToken])
             or o.global
    if key == nil or key == "" then return nil end
    return key
end

-- The override's item tier list, or nil to fall back to the shipped default.
function PrepBar_Overrides:Resolve(slot, classToken, specID)
    local key = self:Key(slot, classToken, specID)
    return key and PrepBar_Items[key] or nil
end
