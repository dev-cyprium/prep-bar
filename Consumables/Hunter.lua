-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.HUNTER
PrepBar_Consumables:Register("HUNTER", {
    [S.BEAST_MASTERY] = { flask = I.FLASK_MAGISTERS },
    [S.MARKSMANSHIP]  = { flask = I.FLASK_SHATTERED_SUN },
    [S.SURVIVAL]      = { flask = I.FLASK_MAGISTERS },
})
