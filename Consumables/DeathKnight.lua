-- Slots: flask  (weaponOil, food, augmentRune are shared). See Monk.lua.
local I = PrepBar_Items
local S = PrepBar_Specs.DEATHKNIGHT
PrepBar_Consumables:Register("DEATHKNIGHT", {
    [S.BLOOD]  = { flask = I.FLASK_THALASSIAN_RESISTANCE },
    [S.FROST]  = { flask = I.FLASK_SHATTERED_SUN },
    [S.UNHOLY] = { flask = I.FLASK_MAGISTERS },
})
