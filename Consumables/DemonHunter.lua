-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.DEMONHUNTER
PrepBar_Consumables:Register("DEMONHUNTER", {
    [S.HAVOC]     = { flask = I.FLASK_SHATTERED_SUN },
    [S.VENGEANCE] = { flask = I.FLASK_BLOOD_KNIGHTS },
    [S.DEVOURER]  = { flask = I.FLASK_MAGISTERS },
})
