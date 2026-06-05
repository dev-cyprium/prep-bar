-- Central item registry. Each item is a quality-ordered list { best, ...worse };
-- single-quality items (no craft tiers) are just { id }. Reference an item by
-- its name in the data files; the bar uses the best variant you actually own.
PrepBar_Items = {
    FLASK_BLOOD_KNIGHTS = { 241324, 241325 },
    FLASK_SHATTERED_SUN = { 241326, 241327 },
    FLASK_THALASSIAN_RESISTANCE = { 241320, 241321 },
    FLASK_MAGISTERS = { 241322, 241323 },

    OIL_PHOENIX = { 243734, 243733 },

    FOOD_ROYAL_ROAST = { 242747, 242275 },

    AUGMENT_RUNE = { 259085 },
}
