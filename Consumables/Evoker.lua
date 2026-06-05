-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.EVOKER
PrepBar_Consumables:Register("EVOKER", {
    [S.DEVASTATION]  = { flask = I.FLASK_SHATTERED_SUN },
    [S.PRESERVATION] = { flask = I.FLASK_MAGISTERS },
    [S.AUGMENTATION] = { flask = I.FLASK_SHATTERED_SUN },
})
