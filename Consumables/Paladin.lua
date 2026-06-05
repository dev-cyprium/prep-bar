-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.PALADIN
PrepBar_Consumables:Register("PALADIN", {
    [S.HOLY]        = { flask = I.FLASK_MAGISTERS },
    [S.PROTECTION]  = { flask = I.FLASK_BLOOD_KNIGHTS },
    [S.RETRIBUTION] = { flask = I.FLASK_MAGISTERS },
})
