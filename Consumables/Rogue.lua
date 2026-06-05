-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.ROGUE
PrepBar_Consumables:Register("ROGUE", {
    [S.ASSASSINATION] = { flask = I.FLASK_SHATTERED_SUN },
    [S.OUTLAW]        = { flask = I.FLASK_BLOOD_KNIGHTS },
    [S.SUBTLETY]      = { flask = I.FLASK_MAGISTERS },
})
