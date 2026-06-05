-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.WARRIOR
PrepBar_Consumables:Register("WARRIOR", {
    [S.ARMS]       = { flask = I.FLASK_SHATTERED_SUN },
    [S.FURY]       = { flask = I.FLASK_MAGISTERS },
    [S.PROTECTION] = { flask = I.FLASK_BLOOD_KNIGHTS },
})
