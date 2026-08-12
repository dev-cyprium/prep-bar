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
    local base = byClass and byClass[specID]
    if not base then return nil end
    -- Return a fresh table so overrides never mutate the registered spec data
    -- (which would go stale once an override is cleared).
    local slots = {}
    for k, v in pairs(base) do slots[k] = v end
    for k, v in pairs(SHARED) do
        if slots[k] == nil then slots[k] = v end
    end
    -- Per-slot global/class/spec override hierarchy wins over the above.
    if PrepBar_Overrides then
        for _, slot in ipairs(PrepBar_OverrideSlots) do
            local ov = PrepBar_Overrides:Resolve(slot, classToken, specID)
            if ov then slots[PrepBar_Overrides:DataKey(slot)] = ov end
        end
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
