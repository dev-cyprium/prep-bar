-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.MAGE
PrepBar_Consumables:Register("MAGE", {
    [S.ARCANE] = { flask = I.FLASK_MAGISTERS },
    [S.FIRE]   = { flask = I.FLASK_MAGISTERS },
    [S.FROST]  = { flask = I.FLASK_SHATTERED_SUN },
})
