-- Slots: flask  (weaponOil, food, augmentRune are shared in Consumables.lua)
-- Item names come from Ids.lua. Each slot is { preferred, fallback, ... }.
local I = PrepBar_Items
local S = PrepBar_Specs.MONK
PrepBar_Consumables:Register("MONK", {
    [S.MISTWEAVER] = { flask = I.FLASK_BLOOD_KNIGHTS },
    [S.BREWMASTER] = { flask = I.FLASK_SHATTERED_SUN },
    [S.WINDWALKER] = { flask = I.FLASK_BLOOD_KNIGHTS },
})
