-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.WARLOCK
PrepBar_Consumables:Register("WARLOCK", {
    [S.AFFLICTION] = { flask = I.FLASK_SHATTERED_SUN },
    [S.DEMONOLOGY] = { flask = I.FLASK_SHATTERED_SUN },
    [S.DESTRUCTION] = { flask = I.FLASK_SHATTERED_SUN },
})
