----------------------------------------------------------------------
-- Consumables registry + accessor
--   Data lives in per-class files under Consumables\, each of which
--   calls PrepBar_Consumables:Register(classToken, specTable).
--
--   classToken : what UnitClassBase returns (e.g. "MONK")
--   specTable  : spec ID (GetSpecializationInfo) -> slots
--   Each slot is a list of item IDs: { preferred, fallback, ... }
--   Item IDs are global; names resolve at runtime via C_Item.GetItemInfo
--   (async; nil on first call).
----------------------------------------------------------------------
local DATA = {}

local I = PrepBar_Items
local SHARED = {
    weaponOil   = I.OIL_PHOENIX,
    augmentRune = I.AUGMENT_RUNE,
    food        = I.FOOD_ROYAL_ROAST,
}

PrepBar_Consumables = {}

function PrepBar_Consumables:Register(classToken, specTable)
    DATA[classToken] = specTable
end

function PrepBar_Consumables:Get(classToken, specID)
    local byClass = DATA[classToken]
    local slots = byClass and byClass[specID]
    if not slots then return nil end
    for k, v in pairs(SHARED) do
        if slots[k] == nil then slots[k] = v end
    end
    return slots
end

function PrepBar_Consumables:GetForPlayer()
    local classToken = UnitClassBase("player")
    local specIndex = GetSpecialization()
    if not specIndex then return nil, classToken end
    local specID = GetSpecializationInfo(specIndex)
    return self:Get(classToken, specID), classToken, specID
end
