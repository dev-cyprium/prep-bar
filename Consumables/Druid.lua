-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.DRUID
PrepBar_Consumables:Register("DRUID", {
    [S.BALANCE]     = { flask = I.FLASK_MAGISTERS },
    [S.FERAL]       = { flask = I.FLASK_MAGISTERS },
    [S.GUARDIAN]    = { flask = I.FLASK_BLOOD_KNIGHTS },
    [S.RESTORATION] = { flask = I.FLASK_BLOOD_KNIGHTS },
})
