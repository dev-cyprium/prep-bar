-- Food override hierarchy: a player-chosen food for the current spec beats one
-- for the class, which beats a global one, which beats the shipped default.
-- Choices are stored in PrepBarDB.food as PrepBar_Items keys ("" = inherit).
PrepBar_FoodChoices = {
    "FOOD_ROYAL_ROAST",
    "FOOD_IMPOSSIBLY_ROYAL_ROAST",
    "FOOD_QUELDOREI_MEDLEY",
    "FOOD_BLOOMING_FEAST",
    "FOOD_CHAMPIONS_BENTO",
    "FOOD_SILVERMOON_PARADE",
    "FOOD_HARANDAR_CELEBRATION",
    "FOOD_FLORA_FRENZY",
}

PrepBar_Food = {}

function PrepBar_Food:EnsureDB()
    PrepBarDB.food = PrepBarDB.food or {}
    local f = PrepBarDB.food
    f.class = f.class or {}
    f.spec  = f.spec or {}
    if f.global == nil then f.global = "" end
    return f
end

function PrepBar_Food:OverrideKey(classToken, specID)
    local f = PrepBarDB and PrepBarDB.food
    if not f then return nil end
    local key = (specID and f.spec and f.spec[tostring(specID)])
             or (classToken and f.class and f.class[classToken])
             or f.global
    if key == nil or key == "" then return nil end
    return key
end

-- The override's item tier list, or nil to fall back to the shipped default.
function PrepBar_Food:ResolveOverride(classToken, specID)
    local key = self:OverrideKey(classToken, specID)
    return key and PrepBar_Items[key] or nil
end
