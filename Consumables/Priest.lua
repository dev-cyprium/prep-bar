-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.PRIEST
PrepBar_Consumables:Register("PRIEST", {
    [S.DISCIPLINE] = { flask = I.FLASK_BLOOD_KNIGHTS },
    [S.HOLY]       = { flask = I.FLASK_SHATTERED_SUN },
    [S.SHADOW]     = { flask = I.FLASK_MAGISTERS },
})
