-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.SHAMAN
PrepBar_Consumables:Register("SHAMAN", {
    [S.ELEMENTAL]   = { flask = I.FLASK_MAGISTERS },
    [S.ENHANCEMENT] = { flask = I.FLASK_MAGISTERS },
    [S.RESTORATION] = { flask = I.FLASK_SHATTERED_SUN },
})
