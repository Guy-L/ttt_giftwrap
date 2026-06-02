include("sh_physics_utils.lua")
local utils = GW_Utils
local dbg   = GW_DBG

local PROP_WEIGHT_NAME    = "ttt2_giftwrap_prop_weight"
local FLOOR_WEIGHT_NAME   = "ttt2_giftwrap_floor_weight"
local SHOP_WEIGHT_NAME    = "ttt2_giftwrap_shop_weight"
local SPECIAL_WEIGHT_NAME = "ttt2_giftwrap_special_weight"

local PROP_WEIGHT_MULT    = utils.Cvar(PROP_WEIGHT_NAME, "1.25", 0, 5, "Weight multiplier for props when picking random gift.")
local FLOOR_WEIGHT_MULT   = utils.Cvar(FLOOR_WEIGHT_NAME, "1", 0, 5,   "Weight multiplier for floor items when picking random gift.")
local SHOP_WEIGHT_MULT    = utils.Cvar(SHOP_WEIGHT_NAME, "0.5", 0, 5,  "Weight multiplier for shop items when picking random gift.")
local SPECIAL_WEIGHT_MULT = utils.Cvar(SPECIAL_WEIGHT_NAME, "1", 0, 5, "Weight multiplier for special entities (SENTs & NPCs) when picking random gift.")

local CORPSE_STINK_ENABLE = utils.Cvar("ttt2_giftwrap_corpse_stink_enable", "1", 0, 1, "Whether gifts containing fleshy ragdolls will start to stink (particles+sound).")
local CORPSE_STINK_DELAY  = utils.Cvar("ttt2_giftwrap_corpse_stink_delay", "15", 0, 120, "Delay before gifts containing fleshy ragdolls start to stink if enabled, in seconds.")

local PLACEHOLDER_DATA_REMOVE    = "GiftWrap_RemovePlaceholderGiftData"
local OVERRIDE_MV_HOOK           = "GiftWrapCL_OverrideMarkerVisionRenderHook"
local INVALID_ID                 = "GiftWrap_InvalidID"

-- cf. excel sheet in addon resources (GitHub)
local QUALITY_MAX  = 10
local XMAS_START   = 1.1
local XMAS_DIVISOR = 40
local XMAS_EXP     = 1.5
local XMAS_SUB     = 0.15
local SCORE_PARA_MAX  = 30
local SCORE_INTERCEPT = -5

GiftCategory = {
    PhysProp      = {id=1,  text="Prop",           icon="vgui/ttt/menu/icon_box",      weight=PROP_WEIGHT_NAME},
    PhysBox       = {id=2,  text="Map Prop",       icon="vgui/ttt/menu/icon_box",      weight=PROP_WEIGHT_NAME},
    SENT          = {id=3,  text="Special Entity", icon="vgui/ttt/menu/icon_sparkles", weight=SPECIAL_WEIGHT_NAME},
    NPC           = {id=4,  text="NPC",            icon="vgui/ttt/menu/icon_headcrab", weight=SPECIAL_WEIGHT_NAME},
    FloorSWEP     = {id=5,  text="Floor Weapon",   icon="vgui/ttt/menu/icon_gun",      weight=FLOOR_WEIGHT_NAME},
    WorldSWEP     = {id=6,  text="Shop Weapon",    icon="vgui/ttt/menu/icon_knife",    weight=SHOP_WEIGHT_NAME},
    AutoEquipSWEP = {id=7,  text="Shop Weapon",    icon="vgui/ttt/menu/icon_knife",    weight=SHOP_WEIGHT_NAME},
    Item          = {id=8,  text="Shop Item",      icon="vgui/ttt/menu/icon_bottle",   weight=SHOP_WEIGHT_NAME},
    Ammo          = {id=9,  text="Ammo Box",       icon="vgui/ttt/menu/icon_ammo",     weight=FLOOR_WEIGHT_NAME},
    Vehicle       = {id=10, text="Vehicle",        icon="vgui/ttt/menu/icon_car",      weight=SPECIAL_WEIGHT_NAME},
    Ragdoll       = {id=11, text="Ragdoll",        icon="vgui/ttt/menu/icon_ragdoll",  weight=SPECIAL_WEIGHT_NAME},
    Unknown       = {id=12, text="Unknown",        icon="vgui/ttt/menu/icon_question", weight=SPECIAL_WEIGHT_NAME},
}

GiftSound = {
    Squishy    = {snd="", desc="squishy"},
    Goopy      = {snd="", desc="goopy"},
    Metallic   = {snd="", desc="metallic"},
    Glass      = {snd="", desc="tinkly"},
    Creaky     = {snd="", desc="creaky"},
    Plastic    = {snd="", desc="plasticky"}, -- pretty much unused
    Fleshy     = {snd="", desc="fleshy"},
    Talking    = {snd="", desc="like it's talking"},
    Meowing    = {snd="", desc="like it's meowing"},
    Bleating   = {snd="", desc="like it's bleating"}, -- lambert only
    Mooing     = {snd="", desc="like it's mooing"}, -- cow only
    Oinking    = {snd="", desc="like it's oinking"}, -- pig only
    Thudding   = {snd="", desc="like it's thudding"},
    Whirring   = {snd="", desc="like it's whirring"},
    Revving    = {snd="", desc="like it's revving"},
    Beeping    = {snd="", desc="like it's beeping"},
    Granular   = {snd="", desc="granular"},
    Springy    = {snd="", desc="springy"},
    Musical    = {snd="", desc="musical"},
    Squeaky    = {snd="", desc="squeaky"}, --new, underused
    Hollow     = {snd="", desc="hollow"}, --new, underused
    Clicky     = {snd="", desc="clicky"}, --new, underused
    Rattling   = {snd="", desc="like it's rattling"}, --new, underused
    Hissing    = {snd="", desc="like it's hissing"}, --new, underused
    Ringing    = {snd="", desc="like it's ringing"}, --new, underused
    Splashing  = {snd="", desc="like it's splashing"},
    Squelching = {snd="", desc="like it's squelching"},
    Rustling   = {snd="", desc="like it's rustling"},
    Whooshing  = {snd="", desc="like it's whooshing"},
    Pulsing    = {snd="", desc="like it's pulsing"},
    Muffled    = {snd="", desc="muffled"}, --TODO: check for use on things other than duct tape + silenced guns
    Train      = {snd="", desc="like it's chugging along"},
    None       = nil -- should maybe see more use
}

GiftSize = {
    Mini     = 0.6,
    Small    = 0.8,
    Normal   = 1,
    Large    = 1.5,
    Larger   = 2,
    Big      = 2.5,
    Huge     = 3.5,
    Gigantic = 5,
    Max      = 7,
}

GiftSmell = {
    Rotten      = "rotten",
    Paint       = "freshly painted", -- underused
    Food        = "like food",
    Woody       = "woody",
    Oily        = "oily", -- underused
    Gunpowder   = "like gunpowder",
    Ash         = "like ash",
    Fur         = "like fur",
    Paper       = "like paper",
    Cardboard   = "like cardboard",
    Caffeine    = "like caffeine",
    Cotton      = "like cotton", -- currently props only
    Wool        = "like wool", -- new, underused
    Clay        = "like clay", -- new, underused
    Leather     = "like leather",
    Nice        = "nice",
    Stinky      = "stinky",
    Mineral     = "mineral",
    Toxic       = "toxic", -- underused
    Salty       = "salty",
    Sugary      = "sugary", -- currently root beer only
    Fizzy       = "fizzy", -- currently speed cola only
    Earthy      = "earthy",
    Dusty       = "dusty",
    Dry         = "dry",
    Rusty       = "rusty",
    Sterile     = "sterile",
    Metallic    = "metallic", -- new, super underused (high overlap with Sterile)
    Rubbery     = "rubbery",
    Strange     = "strange", -- not ideal
    Nondescript = nil,
}

GiftFeel = {
    Weightless    = "weightless", -- pretty much unused
    Light         = "light",
    Heavy         = "heavy",
    Massive       = "massive",
    VerySmall     = "mini",
    Hollow        = "hollow",
    Soft          = "soft",
    Hard          = "hard", -- pretty much unused
    Sharp         = "sharp",
    Icky          = "icky",
    Sticky        = "sticky",
    Electric      = "electric",
    Fresh         = "fresh",
    Cold          = "cold",
    ReallyCold    = "really cold", -- funky wordings possible
    Warm          = "warm",
    Hot           = "hot",
    Sturdy        = "sturdy",
    Formless      = "formless", -- pretty much unused (though not a good item descriptor)
    Round         = "round",
    Box           = "boxy", -- new, underused
    Fragile       = "fragile", -- new, underused
    Squishy       = "squishy",
    Alive         = "agitated",
    Moving        = "like it's moving", -- underused (3)
    Bursting      = "like it's bursting out", -- underused (3)
    Magical       = "magical",
    RealityWarp   = "reality-warping",
    Futuristic    = "futuristic",
    Scientific    = "scientific", -- new, underused
    Informative   = "informative", -- new, underused
    Negative      = "negative",
    Jolly         = "jolly",
    Ghostly       = "ghostly",
    Cursed        = "cursed",
    Long          = "long",
    Otherworldly  = "otherworldly",
    Bright        = "bright",
    Powerful      = "powerful",
    Random        = "random",
    Slippery      = "slippery", -- possibly underused
    Special       = "special", -- currently unused, very not ideal
    Meta          = "meta... or used to", -- used only for TEC-9 (joke)
    Sus           = "suspicious", -- used only for Wormhole-Vent (joke)
    Flat          = "flat", -- new, underused
    Indescribable = nil, -- should maybe see more use
}

local GiftData = {}
GiftData.__index = GiftData

GiftData.New = function(tbl)
    return setmetatable(tbl, GiftData)
end

--- zzzzzzzz
-------------------------------------
local DEBUG_TEST_GIFT  = nil
local DEBUG_TEST_MODEL = nil
-------------------------------------

local giftDataCatalog = {
    --TEST = GiftData.New {
    --    name     = "TEST PROP",           desc       = "a test prop (if you see this, I messed up)",
    --    category = GiftCategory.PhysProp, identifier = DEBUG_TEST_MODEL,
    --    can_be_random_gift = false,
    --    attrib_sound = GiftSound.None,        attrib_size = GiftSize.Normal,
    --    attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Indescribable,
    --},

    -- PhysProps
    argemia = GiftData.New {
        name     = "Argemia Plushie",     desc       = "an Ariral plushie",
        category = GiftCategory.PhysProp, identifier = "models/goobers/argemia/argemia_plush.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Meowing,  attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Otherworldly,
    },
    barrel = GiftData.New {
        name     = "Barrel",              desc       = "a barrel",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/oildrum001.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 4.3,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Round,
    },
    binder = GiftData.New {
        name     = "Binder",              desc       = "a binder",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_lab/binderblue.mdl",
            "models/props_lab/binderbluelabel.mdl",
            "models/props_lab/bindergraylabel01a.mdl",
            "models/props_lab/bindergraylabel01b.mdl",
            "models/props_lab/bindergreen.mdl",
            "models/props_lab/bindergreenlabel.mdl",
            "models/props_lab/binderredlabel.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Paper,   attrib_feel = GiftFeel.Heavy,
    },
    bread_loaf = GiftData.New {
        name     = "Bread Loaf",          desc        = "a loaf of bread",
        category = GiftCategory.PhysProp, identifiers = {
            "models/foodnhouseholditems/bread-2.mdl", -- ttt_5c_plaza
            "models/foodnhouseholditems/bread-4.mdl", -- ttt_5c_plaza
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Granular, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Food,     attrib_feel = GiftFeel.Squishy,
    },
    cannonball_prop = GiftData.New {
        name     = "Used Cannonball",     desc       = "an inert cannonball",
        category = GiftCategory.PhysProp, identifier = "models/props_phx/misc/smallcannonball.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding,  attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Round,
    },
    car_wreck = GiftData.New {
        name     = "Wrecked Car",         desc        = "a broken down car",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_vehicles/car002a_physics.mdl",
            "models/props_vehicles/car002b_physics.mdl",
            "models/props_vehicles/car003a_physics.mdl",
            "models/props_vehicles/car003b_physics.mdl",
            "models/props_vehicles/car004a_physics.mdl",
            "models/props_vehicles/car004b_physics.mdl",
            "models/props_vehicles/car005a_physics.mdl",
            "models/props_vehicles/car005b_physics.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Massive,
    },
    cardboard_box = GiftData.New {
        name     = "Cardboard Box",       desc       = "a cardboard box",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/cardboard_box001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.None,      attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Cardboard, attrib_feel = GiftFeel.Fragile,
    },
    chair_desk = GiftData.New {
        name     = "Desk Chair",          desc       = "a discount desk chair",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/chair_office01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky,   attrib_feel = GiftFeel.Soft,
    },
    cinder_block = GiftData.New {
        name     = "Cinder Block",        desc       = "a cinder block",
        category = GiftCategory.PhysProp, identifier = "models/props/de_inferno/cinderblock.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Mineral,  attrib_feel = GiftFeel.Heavy,
    },
    cirno_fumo = GiftData.New {
        name     = "Cirno Fumo",          desc       = "a fumo",
        category = GiftCategory.PhysProp, identifier = "models/goobers/cirno/cirno.mdl",
        can_be_random_gift = true,
        factor_rarity = 0.9, factor_quality = 9,
        attrib_sound = GiftSound.None,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Cotton, attrib_feel = GiftFeel.Cold,
        adjMass = 40,
    },
    coffee_mug = GiftData.New {
        name     = "Coffee Mug",          desc       = "a coffee mug",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/garbage_coffeemug001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass,    attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Caffeine, attrib_feel = GiftFeel.Round,
    },
    companion_doll = GiftData.New {
        name     = "Companion Doll",      desc       = "a plush doll",
        category = GiftCategory.PhysProp, identifier = "models/maxofs2d/companion_doll.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 4,
        attrib_sound = GiftSound.None,   attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Cotton, attrib_feel = GiftFeel.Soft,
    },
    companion_doll_big = GiftData.New {
        name     = "Companion Doll (Big)", desc       = "a room-sized plush doll",
        category = GiftCategory.PhysProp,  identifier = "models/maxofs2d/companion_doll_big.mdl",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 4,
        attrib_sound = GiftSound.None,   attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Cotton, attrib_feel = GiftFeel.Massive,
    },
    computer_keyboard = GiftData.New {
        name     = "Keyboard",         desc       = "a keyboard",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/computer01_keyboard.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Clicky,   attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Caffeine, attrib_feel = GiftFeel.Flat,
    },
    computer_monitor = GiftData.New {
        name     = "CRT Monitor",          desc       = "a CRT monitor",
        category = GiftCategory.PhysProp, identifier = "models/props_lab/monitor02.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Electric,
    },
    dead_bunger = GiftData.New {
        name     = "Dead Bunger",         desc       = "a dead Bunger",
        category = GiftCategory.PhysProp, identifier = "models/betterbunger.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Squishy,
    },
    desk = GiftData.New {
        name     = "Desk",                desc        = "an old desk",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_wasteland/controlroom_desk001a.mdl",
            "models/props_wasteland/controlroom_desk001b.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Long,
    },
    door = GiftData.New {
        name     = "Door",                desc       = "a door",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/door01_left.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Paint,  attrib_feel = GiftFeel.Flat,
    },
    explosive_barrel = GiftData.New {
        name     = "Explosive Barrel",    desc       = "an explosive barrel",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/oildrum001_explosive.mdl",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -9,
        attrib_sound = GiftSound.Metallic, attrib_size = 4.3,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Round,
        special_setup = "explo_barrel_setup"
    },
    file_cabinet = GiftData.New {
        name     = "File Cabinet",        desc       = "a file cabinet",
        category = GiftCategory.PhysProp, identifier = "models/props_wasteland/controlroom_filecabinet002a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Paper,    attrib_feel = GiftFeel.Massive,
    },
    goober = GiftData.New {
        name     = "Goober",              desc       = "a goober",
        category = GiftCategory.PhysProp, identifier = "models/goobers/goober/goober_0.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 8,
        attrib_sound = GiftSound.None,   attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky, attrib_feel = GiftFeel.Flat,
    },
    lambert = GiftData.New {
        name     = "Lambert Plushie",     desc       = "a sacrificial lamb",
        category = GiftCategory.PhysProp, identifier = "models/goobers/lambert/lambert.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 6,
        attrib_sound = GiftSound.Bleating, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Wool,     attrib_feel = GiftFeel.Otherworldly,
        adjMass = 40,
    },
    lamp_desk = GiftData.New {
        name     = "Desk Lamp",           desc       = "a desk lamp",
        category = GiftCategory.PhysProp, identifier = "models/props_lab/desklamp01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Paint,    attrib_feel = GiftFeel.Bright,
    },
    lamp_floor = GiftData.New {
        name     = "Floor Lamp",          desc       = "a lamp",
        category = GiftCategory.PhysProp, identifier = "models/props_interiors/furniture_lamp01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Bright,
    },
    lamp_hanging = GiftData.New {
        name     = "Hanging Lamp",        desc       = "a lamp",
        category = GiftCategory.PhysProp, identifier = "models/props_wasteland/prison_lamp001c.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass,    attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Bright,
    },
    maxwell_prop = GiftData.New {
        name     = "Maxwell",             desc       = "a dapper gentleman",
        category = GiftCategory.PhysProp, identifier = "models/goobers/dingus/dingus.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 7,
        attrib_sound = GiftSound.Meowing, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Fur,     attrib_feel = GiftFeel.Soft,
    },
    mc_pig = GiftData.New {
        name     = "Pig",                 desc       = "a pig",
        category = GiftCategory.PhysProp, identifier = "models/mcmodelpack/mobs/pig.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Oinking, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Alive,
    },
    metal_pan = GiftData.New {
        name     = "Metal Pan",           desc       = "a cooking pan",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/metalpot002a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Ash,      attrib_feel = GiftFeel.Flat,
    },
    metal_pot = GiftData.New {
        name     = "Metal Pot",           desc       = "a metal pot",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/metalpot001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Ash,      attrib_feel = GiftFeel.Hollow,
    },
    milk_jug = GiftData.New {
        name     = "Milk Jug",            desc        = "an old milk jug",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/garbage_milkcarton001a.mdl",
            "models/props_junk/garbage_milkcarton002a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Cold,
    },
    neco_arc = GiftData.New {
        name     = "Neco Arc Plushie",    desc       = "a weird cat",
        category = GiftCategory.PhysProp, identifier = "models/goobers/necoarc/neko_arc_plush.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 3,
        attrib_sound = GiftSound.Meowing, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Otherworldly,
    },
    newspaper = GiftData.New {
        name     = "Newspaper",           desc       = "the newspaper",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/garbage_newspaper001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Dry,      attrib_feel = GiftFeel.Informative,
    },
    phone_office = GiftData.New {
        name     = "Office Phone",      desc       = "an office phone",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/phone.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Ringing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Fragile,
    },
    plastic_crate = GiftData.New {
        name     = "Plastic Crate",       desc       = "a plastic crate",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/plasticcrate01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Hollow,
    },
    plush_turtle = GiftData.New {
        name     = "Plush Turtle",        desc       = "a turtle plushie",
        category = GiftCategory.PhysProp, identifier = "models/props/de_tides/vending_turtle.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 8,
        attrib_sound = GiftSound.None,     attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Cotton,   attrib_feel = GiftFeel.Squishy,
    },
    prop_radio = GiftData.New {
        name     = "Radio (Prop)",        desc       = "a broken radio",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/radio.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Fragile,
    },
    rat = GiftData.New {
        name     = "Rat",                 desc       = "a rat",
        category = GiftCategory.PhysProp, identifier = "models/goobers/jermarat/rat.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -5,
        attrib_sound = GiftSound.Squeaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Alive,
        adjMass = 40,
    },
    rock = GiftData.New {
        name     = "Rock",                desc       = "a rock",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/rock001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Mineral,  attrib_feel = GiftFeel.Hard,
    },
    seal = GiftData.New {
        name     = "Seal",                desc       = "a seal",
        category = GiftCategory.PhysProp, identifier = "models/goobers/niko/niko.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 5,
        attrib_sound = GiftSound.Squeaky, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Fur,     attrib_feel = GiftFeel.Slippery,
    },
    siffrin = GiftData.New {
        name     = "Siffrin Plushie",     desc       = "a Siffrin plushie",
        category = GiftCategory.PhysProp, identifier = "models/goobers/siffrin/siffrin.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 3,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Cotton,  attrib_feel = GiftFeel.Otherworldly,
    },
    soccer_ball = GiftData.New {
        name     = "Soccer Ball",         desc       = "a brand-new soccer ball",
        category = GiftCategory.PhysProp, identifier = "models/props_phx/misc/soccerball.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 0,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Leather,  attrib_feel = GiftFeel.Round,
    },
    toy_train = GiftData.New {
        name     = "Toy Train",           desc       = "a toy train",
        category = GiftCategory.PhysProp, identifier = "models/quarterlife/fsd-overrun-toy.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 8,
        attrib_sound = GiftSound.Train,   attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Plastic, attrib_feel = GiftFeel.Long,
        adjMass = 40,
    },
    used_knife = GiftData.New {
        name     = "Used Knife",          desc       = "a bloodied knife",
        category = GiftCategory.PhysProp, identifier = "models/weapons/w_knife_t.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Strange,  attrib_feel = GiftFeel.Sharp,
        break_constraints = true,
    },
    used_shark_idol = GiftData.New {
        name     = "Used Shark Idol",     desc       = "a golden relic",
        category = GiftCategory.PhysProp, identifier = "models/weapons/w_shark_idol.mdl",
        can_be_random_gift = true,
        factor_rarity = 5, factor_quality = 2,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Salty,    attrib_feel = GiftFeel.Cursed,
    },
    used_sopd = GiftData.New {
        name     = "Used Sword of Player Defeat",
        category = GiftCategory.PhysProp, identifier = "models/ttt/sopd/w_sopd.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Strange,  attrib_feel = GiftFeel.Sharp,
        special_setup = "sopd_setup", break_constraints = true,
    },
    watermelon = GiftData.New {
        name     = "Watermelon",          desc       = "a watermelon",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/watermelon01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Round,
    },
    watermelon_unbreakable = GiftData.New {
        name     = "Unbreakable Watermelon", desc       = "an invincible watermelon",
        category = GiftCategory.PhysProp,    identifier = "models/foodnhouseholditems/watermelon_unbreakable.mdl", -- ttt_5c_plaza
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Sturdy,
    },
    wooden_chair = GiftData.New {
        name     = "Wooden Chair",        desc        = "a wooden chair",
        category = GiftCategory.PhysProp, identifiers = {
            "models/nova/chair_wood01.mdl",
            "models/props_interiors/furniture_chair01a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Light,
    },
    wooden_crate = GiftData.New {
        name     = "Wooden Crate",        desc       = "a wooden crate",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/wood_crate001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Box,
    },
    wooden_crate_big = GiftData.New {
        name     = "Wooden Crate (Big)",  desc       = "a large wooden crate",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/wood_crate002a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 6,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Massive,
    },
    wooden_pallet = GiftData.New {
        name     = "Wooden Pallet",       desc       = "a wooden pallet",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/wood_pallet001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Flat,
    },

    ----------------------------------------------------------------------
    -- SENTs / NPCs
    banana_split = GiftData.New {
        name     = "Live Banana Split", desc      = "dangerous levels of potassium",
        category = GiftCategory.SENT,  identifier = "ttt_banana_split",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -7,
        attrib_sound = GiftSound.Squishy,   attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Fresh,
        special_setup = "grenade_auto", explosion_delay = 2, set_owner = true
    },
    bouncy_ball = GiftData.New {
        name     = "Bouncy Ball",     desc       = "a colorful ball",
        category = GiftCategory.SENT, identifier = "sent_ball",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 1,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Strange, attrib_feel = GiftFeel.Round,
        special_setup = "bouncy_ball_setup",
        visual_override = {path = "sprites/sent_ball", type = "sprite"}
    },
    bunger = GiftData.New {
        name     = "Live Bunger",    desc       = "a Bunger",
        category = GiftCategory.NPC, identifier = "npc_headcrab_fast",
        can_be_random_gift = true,
        factor_rarity = 0.7, factor_quality = 10,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Alive,
        special_setup = "bunger_setup",
        visual_override = {path = "models/betterbunger.mdl", type = "model"}
    },
    deadly_ball = GiftData.New {
        name     = "Harmful Bouncy Ball", desc       = "a colorful ball",
        category = GiftCategory.SENT,     identifier = "deadly_ball",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Strange, attrib_feel = GiftFeel.Round,
        special_setup = "bouncy_ball_setup",
        visual_override = {path = "sprites/sent_ball", type = "sprite"}
    },
    chicken = GiftData.New {
        name     = "Chicken",             desc       = "an aggressive pet chicken",
        category = GiftCategory.SENT,     identifier = "ttt_chicken",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = 2,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Food,     attrib_feel = GiftFeel.Alive,
    },
    chomik = GiftData.New {
        name     = "Chomik",          desc       = "a collectible",
        category = GiftCategory.SENT, identifier = "ttt_chomik",
        can_be_random_gift = false,
        --factor_rarity = 2, factor_quality = -1,
        attrib_sound = GiftSound.Muffled, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Strange, attrib_feel = GiftFeel.Flat,
        up_vel = 400, up_min = 0, up_max = 2,
    },
    det_hat = GiftData.New {
        name     = "Detective Hat",   desc       = "a hat",
        category = GiftCategory.SENT, identifier = "ttt_hat_deerstalker",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 4,
        attrib_sound = GiftSound.None, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Wool, attrib_feel = GiftFeel.Sus,
    },
    flame = GiftData.New {
        name     = "Flame",           desc       = "a flame",
        category = GiftCategory.SENT, identifier = "ttt_flame",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = -3,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Ash,       attrib_feel = GiftFeel.Hot,
        visual_override = {path = "particles/flamelet4", type = "sprite"},
        up_vel = 300, up_min = 1, up_max = 2,
        special_setup = "flame_setup"
    },
    force_shield = GiftData.New {
        name     = "Live Force Shield", desc       = "a next-gen force shield",
        category = GiftCategory.SENT,   identifier = "force_shield",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Pulsing,     attrib_size = 10,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Futuristic,
        ambush_giftee = true, ambush_angle = 90, mark_invalid = true,
        special_setup = "force_shield_setup"
    },
    green_demon = GiftData.New {
        name     = "Live Green Demon", desc       = "a 1-UP",
        category = GiftCategory.SENT,  identifier = "sent_greendemon",
        can_be_random_gift = true,
        factor_rarity = 10, factor_quality = -10,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Cursed,
        set_owner = true,
        mv_hook = "HUDDrawMarkerVisionGreenDemon",
        visual_override = {path = "models/entities/entities/sent_greendemon/gd.png", type = "sprite"},
        special_setup = "green_demon_setup"
    },
    headcrab = GiftData.New {
        name     = "Headcrab",       desc       = "an aggressive pet crab",
        category = GiftCategory.NPC, identifier = "npc_headcrab",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -8,
        attrib_sound = GiftSound.Fleshy, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Rotten, attrib_feel = GiftFeel.Alive,
    },
    headcrab_black = GiftData.New {
        name     = "Black Headcrab", desc       = "a poisonous crab",
        category = GiftCategory.NPC, identifier = "npc_headcrab_black",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Fleshy, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Toxic,  attrib_feel = GiftFeel.Alive,
    },
    kfc = GiftData.New {
        name     = "KFC Bucket",      desc       = "a bucket o' chicken",
        category = GiftCategory.SENT, identifier = "ttt_kfc",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 6,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Warm,
    },
    maxwell = GiftData.New {
        name     = "Maxwell",         desc       = "a dapper gentleman",
        category = GiftCategory.SENT, identifier = "ttt_dingus",
        can_be_random_gift = false,
        --factor_rarity = 4, factor_quality = 5,
        attrib_sound = GiftSound.Meowing, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Nice,    attrib_feel = GiftFeel.Soft,
    },
    max = GiftData.New {
        name     = "Max",             desc       = "Max",
        category = GiftCategory.SENT, identifier = "ttt_dingwell",
        can_be_random_gift = false,
        --factor_rarity = 5, factor_quality = 8,
        attrib_sound = GiftSound.Meowing, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Fur,     attrib_feel = GiftFeel.Soft,
    },
    mc_arrow = GiftData.New {
        name     = "Minecraft Arrow",  desc      = "a pixel arrow",
        category = GiftCategory.SENT, identifier = "ttt_minecraft_arrow",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = -4,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Woody,     attrib_feel = GiftFeel.Otherworldly,
        up_vel = 800, up_min = 1, up_max = 3, up_angvel = 0
    },
    molotov_grenade = GiftData.New {
        name     = "Live Molotov Cocktail (Timed)", desc       = "a spicy cocktail",
        category = GiftCategory.SENT,               identifier = "sent_molotov_timed",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Oily,      attrib_feel = GiftFeel.Hot,
        special_setup = "timed_molotov_setup", set_owner = true
    },
    moonball = GiftData.New { --TODO: look into error when walking on it
        name     = "Moonball",        desc       = "a bouncy marble",
        category = GiftCategory.SENT, identifier = "moonball",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -1,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Mini,
        attrib_smell = GiftSmell.Mineral, attrib_feel = GiftFeel.Round,
        special_setup = "moonball_setup", up_vel = 200
    },
    present = GiftData.New {
        name     = "Present",         desc       = "a different type of gift",
        category = GiftCategory.SENT, identifier = "christmas_present",
        can_be_random_gift = true,
        factor_rarity = 0.8, factor_quality = 4,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Paper,    attrib_feel = GiftFeel.Jolly,
        special_setup = "snuffles_present_setup"
    },
    seekgull = GiftData.New {
        name     = "Live Seekgull",   desc       = "a homing seagull",
        category = GiftCategory.SENT, identifier = "ttt_seekgull_bird",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -5,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Salty,     attrib_feel = GiftFeel.Alive,
        special_setup = "seekgull_setup", set_owner = true
    },
    shard_of_greed = GiftData.New {
        name     = "Shard of Greed",  desc       = "an ominous shard",
        category = GiftCategory.SENT, identifier = "ttt_shard_of_greed",
        can_be_random_gift = true,
        factor_rarity = 0.7, factor_quality = 2,
        attrib_sound = GiftSound.Glass, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Clay,  attrib_feel = GiftFeel.Cursed,
        special_setup = "pog_shard_setup", up_vel = 400, up_min = 0, up_max = 2,
    },
    zombie = GiftData.New {
        name     = "Zombie",          desc       = "a zombie",
        category = GiftCategory.NPC, identifier = "npc_zombie",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = -7,
        attrib_sound = GiftSound.Fleshy, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten, attrib_feel = GiftFeel.Alive,
    },

    ----------------------------------------------------------------------
    -- Func PhysBoxes (map-bound model-less props)
    seliana_carpet = GiftData.New {
        name     = "Carpet",             desc       = "a fancy carpet",
        category = GiftCategory.PhysBox, identifier = "Carpet",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Soft,
        available_on_map = "ttt_seliana",
    },
    mc_city_tnt = GiftData.New {
        name     = "TNT",                desc       = "a TNT block",
        category = GiftCategory.PhysBox, identifiers = {
            "TNT01",
            "TNT02",
            "TNT03",
            "", -- not relevant since we get the moveParent of each block; added for coverage
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hissing,   attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Box,
        available_on_map = "ttt_minecraftcity_v3",
    },

    ----------------------------------------------------------------------
    -- Ragdolls
    seekgull_corpse = GiftData.New {
        name     = "Dead Seekgull",      desc       = "a dead seagull",
        category = GiftCategory.Ragdoll, identifier = "models/seagull.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Salty,   attrib_feel = GiftFeel.Icky,
    },
    terror_corpse = GiftData.New {
        name     = "Dead Terrorist",     desc        = "a body",
        category = GiftCategory.Ragdoll, identifiers = {
            "models/player/leet.mdl",
            "models/player/phoenix.mdl",
            "models/player/arctic.mdl",
            "models/player/guerilla.mdl",
            --"models/captainbleysfire/swag_leet/swag_leet.mdl",
            --"models/hotlinemiami/russianmafia/mafia04pm.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Heavy,
    },
    detective_corpse = GiftData.New {
        name     = "Dead Detective",     desc       = "an important body",
        category = GiftCategory.Ragdoll, identifier = "models/player/elispolice/police.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Heavy,
    },
    hostage_corpse = GiftData.New {
        name     = "Dead Hostage",       desc        = "a body",
        category = GiftCategory.Ragdoll, identifiers = {
            "models/player/hostage/hostage_01.mdl",
            "models/player/hostage/hostage_02.mdl",
            "models/player/hostage/hostage_03.mdl",
            "models/player/hostage/hostage_04.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Heavy,
    },
    police_corpse = GiftData.New {
        name     = "Dead Metrocop"  ,    desc        = "a cop's body",
        category = GiftCategory.Ragdoll, identifiers = {
            "models/player/police.mdl",
            "models/player/policefem.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Heavy,
    },
    ct_corpse = GiftData.New {
        name     = "Dead Counter-Terrorist",       desc       = "a body",
        category = GiftCategory.Ragdoll, identifier = "models/player/urban.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Heavy,
    },
    kleiner_corpse = GiftData.New {
        name     = "Dead Kleiner",       desc        = "Kleiner's body",
        category = GiftCategory.Ragdoll, identifiers = {
            "models/player/kleiner.mdl",
            "models/kleiner.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Scientific,
    },
    gordon_corpse = GiftData.New {
        name     = "Dead Gordon",        desc       = "Gordon's body",
        category = GiftCategory.Ragdoll, identifier = "models/halflife1/gordon_freeman_pm.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Scientific,
    },
    gman_corpse = GiftData.New {
        name     = "Dead G-Man",         desc       = "the G-Man's body",
        category = GiftCategory.Ragdoll, identifier = "models/player/gman_high.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Powerful,
    },
    master_eng_corpse = GiftData.New {
        name     = "Dead Engineer",      desc       = "a body",
        category = GiftCategory.Ragdoll, identifier = "models/dotcoockie/mastereng.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Scientific,
    },
    catbine_corpse = GiftData.New {
        name     = "Dead Catbine",       desc       = "a body",
        category = GiftCategory.Ragdoll, identifier = "models/catbineelite.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Fur,      attrib_feel = GiftFeel.Heavy,
        available_on_map = "ttt_unsung_star",
    },
    infected_corpse = GiftData.New {
        name     = "Dead Infected",      desc        = "a dead undead",
        category = GiftCategory.Ragdoll, identifiers = {
            "models/player/corpse1.mdl",
            "models/humans/corpse1.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Fleshy, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten, attrib_feel = GiftFeel.Heavy,
    },
    charred_corpse = GiftData.New {
        name     = "Charred Corpse",     desc       = "a charred corpse",
        category = GiftCategory.Ragdoll, identifier = "models/humans/charple01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Ash,      attrib_feel = GiftFeel.Heavy,
        disable_flies = true,
    },
    skeleton = GiftData.New {
        name     = "Skeleton",           desc       = "a skeleton",
        category = GiftCategory.Ragdoll, identifier = "models/player/skeleton.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = -6,
        attrib_sound = GiftSound.Rattling, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Dry,      attrib_feel = GiftFeel.Ghostly,
        disable_flies = true,
    },
    mc_skeleton = GiftData.New {
        name     = "Skeleton",           desc       = "a skeleton",
        category = GiftCategory.Ragdoll, identifier = "models/mcmodelpack/mobs/skeleton.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rattling, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Dry,      attrib_feel = GiftFeel.Fragile,
        disable_flies = true,
    },
    mc_spider = GiftData.New {
        name     = "Spider",             desc       = "a spider",
        category = GiftCategory.Ragdoll, identifier = "models/mcmodelpack/mobs/spider.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hissing, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Fur,     attrib_feel = GiftFeel.Alive,
        disable_flies = true,
    },
    mc_cavespider = GiftData.New {
        name     = "Cave Spider",        desc       = "a cave spider",
        category = GiftCategory.Ragdoll, identifier = "models/mcmodelpack/mobs/cavespider.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hissing, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Toxic,   attrib_feel = GiftFeel.Alive,
        disable_flies = true,
    },
    mc_creeper = GiftData.New {
        name     = "Creeper",            desc       = "a creeper",
        category = GiftCategory.Ragdoll, identifier = "models/minecraft/mobs/creeper.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hissing,   attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Box,
        disable_flies = true,
    },
    mattress = GiftData.New {
        name     = "Mattress",           desc       = "an old mattress",
        category = GiftCategory.Ragdoll, identifier = "models/props_c17/furnituremattress001a.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -4,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Heavy,
        disable_flies = true,
    },

    ----------------------------------------------------------------------
    -- Vehicles
    airboat = GiftData.New {
        name     = "Airboat",            desc       = "an airboat",
        category = GiftCategory.Vehicle, identifier = "models/airboat.mdl",
        entity_class   = "prop_vehicle_airboat",
        vehicle_script = "scripts/vehicles/airboat.txt",
        can_be_random_gift = true,
        factor_rarity = 5, factor_quality = 10,
        attrib_sound = GiftSound.Revving, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Rusty,   attrib_feel = GiftFeel.Massive,
    },
    buggy = GiftData.New {
        name     = "Buggy",              desc       = "a buggy",
        category = GiftCategory.Vehicle, identifier = "models/buggy.mdl",
        entity_class   = "prop_vehicle_jeep",
        vehicle_script = "scripts/vehicles/jeep_test.txt",
        extra_seats = {
            { pos = Vector(15, -38, 19), angle = Angle(0, 0, 0), type="jeep" }
        },
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 8,
        attrib_sound = GiftSound.Revving, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Leather, attrib_feel = GiftFeel.Fragile,
    },
    golf_cart = GiftData.New {
        name     = "Golf Cart",          desc       = "a golf cart",
        category = GiftCategory.Vehicle, identifier = "models/caddy.mdl",
        entity_class   = "prop_vehicle_jeep",
        vehicle_script = "scripts/vehicles/caddy.txt",
        extra_seats = {
            { pos = Vector(13, -9, 36), angle = Angle(0, 0, 0), type="jeep" },
            { pos = Vector(4, -36, 33.6), angle = Angle(0, 180, 0), type="airboat" }
        },
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 10,
        attrib_sound = GiftSound.Revving, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Rusty,   attrib_feel = GiftFeel.Massive,
    },
    prisoner_pod = GiftData.New {
        name     = "Prisoner Pod",       desc       = "a human-sized cage",
        category = GiftCategory.Vehicle, identifier = "models/vehicles/prisoner_pod_inner.mdl",
        entity_class   = "prop_vehicle_prisoner_pod",
        vehicle_script = "scripts/vehicles/prisoner_pod.txt",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -5,
        attrib_sound = GiftSound.Hollow,   attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Heavy,
        adjAngle = Angle(-90, 0, 0), special_setup = "auto_drive"
    },

    ----------------------------------------------------------------------
    -- Vehicle Seats
    airboat_seat = GiftData.New {
        name     = "Airboat Seat",       desc       = "a seat",
        category = GiftCategory.Vehicle, identifier = "models/nova/airboat_seat.mdl",
        entity_class   = "prop_vehicle_prisoner_pod",
        vehicle_script = "scripts/vehicles/prisoner_pod.txt",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -2,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Leather, attrib_feel = GiftFeel.Soft,
    },
    jeep_seat = GiftData.New {
        name     = "Jeep Seat",          desc       = "a booster seat",
        category = GiftCategory.Vehicle, identifier = "models/nova/jeep_seat.mdl",
        entity_class   = "prop_vehicle_prisoner_pod",
        vehicle_script = "scripts/vehicles/prisoner_pod.txt",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -1,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Leather, attrib_feel = GiftFeel.Soft,
    },

    ----------------------------------------------------------------------
    -- WorldSWEPs / AutoEquipSWEPs
    boomerang = GiftData.New {
        name     = "Boomerang",            desc       = "a brand-new boomerang",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_boomerang",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Paint,     attrib_feel = GiftFeel.Light,
        adjAngle = Angle(0, 0, 90)
    },
    binoculars = GiftData.New {
        name     = "Binoculars",           desc       = "a pair of binoculars",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_binoculars",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 3,
        attrib_sound = GiftSound.Glass,       attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Sturdy,
        worldmodel_fix = true,
    },
    blink = GiftData.New {
        name     = "Blink",                desc       = "teleportation powers",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_minty_blink",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing,   attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Magical,
    },
    bb_launcher = GiftData.New {
        name     = "Bouncy Ball Launcher", desc       = "a colorful ball dispenser",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_bblauncher",
        can_be_random_gift = true,
        factor_rarity = 7, factor_quality = 5,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Strange,  attrib_feel = GiftFeel.Random,
    },
    cannibalism = GiftData.New {
        name     = "Cannibalism",          desc       = "a craving for flesh",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_cannibal",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Sharp,
    },
    chainsaw = GiftData.New {
        name     = "Chainsaw",             desc       = "a sick chainsaw",
        category = GiftCategory.WorldSWEP, identifier = "weapon_chainsaw_new",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Revving, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Rusty,   attrib_feel = GiftFeel.Sharp,
    },
    cigarette = GiftData.New {
        name     = "Cigarette",            desc       = "a cigarette",
        category = GiftCategory.WorldSWEP, identifier = "weapon_cigarro",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = -10,
        attrib_sound = GiftSound.None, attrib_size = GiftSize.Mini,
        attrib_smell = GiftSmell.Ash,  attrib_feel = GiftFeel.Cursed,
    },
    cloaker = GiftData.New {
        name     = "Cloaker Kick",         desc       = "a single, powerful boot",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_cloaker",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Leather,  attrib_feel = GiftFeel.Soft,
    },
    cloaking_device = GiftData.New {
        name     = "Cloaking Device",          desc       = "a cloak of invisiblity",
        category = GiftCategory.AutoEquipSWEP, identifier = "weapon_ttt_cloak",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring,    attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Magical,
    },
    corpse_launcher = GiftData.New {
        name     = "Corpse Launcher",      desc       = "a Corpse Launcher",
        category = GiftCategory.WorldSWEP, identifier = "corpselauncher",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Heavy,
    },
    dead_ringer = GiftData.New {
        name     = "Dead Ringer",          desc       = "an expensive watch",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_dead_ringer",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass,   attrib_size = GiftSize.Mini,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Round,
    },
    death_faker = GiftData.New {
        name     = "Death Faker",          desc       = "a DIY kit for faking your own death",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_fakedeath",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Cold,
    },
    defib = GiftData.New {
        name     = "Defibrillator",        desc       = "life-saving medical equipment",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_defibrillator",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Electric,
    },
    defuser = GiftData.New {
        name     = "Defuser",              desc       = "a real bomb squad toolkit",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_defuser",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic,  attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Electric,
    },
    dete_playercam = GiftData.New {
        name     = "Dete Playercam",       desc       = "a perception linker",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_dete_playercam",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 5,
        attrib_sound = GiftSound.Metallic,  attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile,   attrib_feel = GiftFeel.RealityWarp,
    },
    dna_scanner = GiftData.New {
        name     = "DNA Scanner",          desc       = "a portable DNA scanner",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_wtester",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Scientific,
    },
    doppelganger = GiftData.New {
        name     = "Doppelganger",         desc       = "a self-hologram maker",
        category = GiftCategory.WorldSWEP, identifier = "weapon_doppelganger",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -5,
        attrib_sound = GiftSound.Metallic,    attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Futuristic,
    },
    duct_tape = GiftData.New {
        name     = "Duct Tape",            desc       = "a roll of duct tape",
        category = GiftCategory.WorldSWEP, identifier = "ttt_duct_tape",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 2,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Muffled,
    },
    eagleflight = GiftData.New {
        name     = "Eagleflight Gun",      desc       = "a gun where you are the bullet",
        category = GiftCategory.WorldSWEP, identifier = "ttt_weapon_eagleflightgun",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Cursed,
    },
    extinguisher = GiftData.New {
        name     = "Extinguisher",         desc       = "a fire extinguisher",
        category = GiftCategory.WorldSWEP, identifier = "weapon_extinguisher",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 2,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Hollow,
    },
    flare_gun = GiftData.New {
        name     = "Flare Gun",            desc       = "a Flare Gun",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_flaregun",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Ash,      attrib_feel = GiftFeel.Cold,
    },
    freeze_gun = GiftData.New {
        name     = "Freeze Gun",           desc       = "a really cool gun",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_freezegun",
        can_be_random_gift = true,
        factor_rarity = 8, factor_quality = 8,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.ReallyCold,
    },
    fulton = GiftData.New {
        name     = "Fulton",               desc       = "an air lift",
        category = GiftCategory.WorldSWEP, identifier = "terror_fulton",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 4,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Leather,   attrib_feel = GiftFeel.Round,
    },
    gangsters = GiftData.New {
        name     = "Gangster's Judgement", desc       = "the Gangster's gun",
        category = GiftCategory.WorldSWEP, identifier = "weapon_gangstersjudge",
        can_be_random_gift = true,
        factor_rarity = 5, factor_quality = 3,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Cursed,
    },
    gsmb_mushroom = GiftData.New {
        name     = "Giant Super Mario Mushroom", desc       = "a massive powerup",
        category = GiftCategory.WorldSWEP,       identifier = "giantsupermariomushroom",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Otherworldly,
    },
    gold_dragon = GiftData.New {
        name     = "Gold Dragon",          desc       = "a Gold Dragon",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ap_golddragon",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic,  attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Hot,
    },
    grave_talk = GiftData.New {
        name     = "Gravetalk",            desc       = "a walkie-talkie",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_gravetalk",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -7,
        attrib_sound = GiftSound.Talking, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Ghostly,
    },
    gravity_hammer = GiftData.New {
        name     = "Gravity Hammer",        desc      = "a Gravity Hammer",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_gravityhammer",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Heavy,
    },
    headcrab_launcher = GiftData.New {
        name     = "Headcrab Launcher",    desc       = "a crab dispenser",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_headlauncher",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Otherworldly,
    },
    homerun_bat = GiftData.New {
        name     = "Homerun Bat",          desc       = "a baseball bat",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_homebat",
        can_be_random_gift = true,
        factor_rarity = 10, factor_quality = 10,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Woody,    attrib_feel = GiftFeel.Long,
    },
    hopium = GiftData.New {
        name     = "Hopium",               desc       = "HOPE",
        category = GiftCategory.WorldSWEP, identifier = "ttt_weapon_hopium",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Strange,   attrib_feel = GiftFeel.Otherworldly,
    },
    id_disguise = GiftData.New {
        name     = "Identity Disguiser",   desc       = "a disguise kit",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_identity_disguiser",
        can_be_random_gift = true,
        factor_rarity = 5, factor_quality = 7,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Sharp,
    },
    invert_gun = GiftData.New {
        name     = "Invert Gun",           desc       = "a concussive gun",
        category = GiftCategory.WorldSWEP, identifier = "weapon_invert_gun",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.RealityWarp,
    },
    jam = GiftData.New {
        name     = "Jam",                  desc       = "a jar of jam",
        category = GiftCategory.WorldSWEP, identifier = "ttt_pap_jam",
        can_be_random_gift = true,
        factor_rarity = 0.5, factor_quality = 2,
        attrib_sound = GiftSound.Squelching, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,       attrib_feel = GiftFeel.Sticky,
    },
    kf5 = GiftData.New {
        name     = "KF5 Dominator",        desc       = "a KF5 Dominator",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_assaultblaster",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding,  attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Heavy,
    },
    kamehameha = GiftData.New {
        name     = "Kamehameha",               desc       = "Saiyan powers",
        category = GiftCategory.AutoEquipSWEP, identifier = "ttt_kamehameha_swep",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing,   attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Otherworldly,
    },
    laser_huge = GiftData.New {
        name     = "Laser-249",            desc       = "a danmaku laser gun",
        category = GiftCategory.WorldSWEP, identifier = "ttt_laser_bullet",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding,  attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Magical,
    },
    laser_pointer = GiftData.New {
        name     = "Laser Pointer",         desc      = "a toy laser pointer",
        category = GiftCategory.WorldSWEP, identifier = "laserpointer",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring,  attrib_size = GiftSize.Mini,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Bright,
    },
    lens = GiftData.New {
        name     = "Lens",                 desc       = "a magnifying glass",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt2_lens",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = 3,
        attrib_sound = GiftSound.Glass,   attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Light,
    },
    lightning_ar1 = GiftData.New {
        name     = "Lightning AR1",        desc       = "an electric guitar",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_lightningar1",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Woody,   attrib_feel = GiftFeel.Hollow,
    },
    maclunkey = GiftData.New {
        name     = "Maclunkey",            desc       = "Han's gun",
        category = GiftCategory.WorldSWEP, identifier = "maclunkey",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Talking,   attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Cold,
    },
    magic_beans = GiftData.New {
        name     = "Magic Beans",              desc       = "a can of beans",
        category = GiftCategory.AutoEquipSWEP, identifier = "magicbeans",
        can_be_random_gift = true,
        factor_rarity = 7, factor_quality = 3,
        attrib_sound = GiftSound.Squelching, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,       attrib_feel = GiftFeel.Hot,
    },
    magic_glauncher = GiftData.New {
        name     = "Magic Grenade Launcher", desc       = "a magic grenade dispenser",
        category = GiftCategory.WorldSWEP,   identifier = "weapon_ttt_magicgl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Pulsing,   attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Magical, -- is also Bright
    },
    marker_defib = GiftData.New {
        name     = "Marker's Defib",       desc       = "life-saving medical equipment",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt2_markerdefi",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Electric,
    },
    masterton = GiftData.New {
        name     = "Masterton M-557",      desc       = "a Masterton",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_masterton",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding,  attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Powerful,
    },
    mc_bow = GiftData.New {
        name     = "Minecraft Bow",        desc       = "a bow and arrow",
        category = GiftCategory.WorldSWEP, identifier = "ttt_minecraft_bow",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Woody,   attrib_feel = GiftFeel.Otherworldly,
    },
    meatball = GiftData.New {
        name     = "Spicy Meatball",       desc       = "a spicy meat-a-ball",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_spicy_meatball",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,     attrib_feel = GiftFeel.Hot,
    },
    minifier = GiftData.New {
        name     = "Minifier",             desc       = "small mode",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_minifier",
        can_be_random_gift = true,
        factor_rarity = 5, factor_quality = 5,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Mini,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.VerySmall,
    },
    minigun = GiftData.New {
        name     = "Minigun",              desc       = "a minigun",
        category = GiftCategory.WorldSWEP, identifier = "m9k_minigun",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Revving,   attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Heavy,
    },
    newton_launcher = GiftData.New {
        name     = "Newton Launcher",      desc       = "a Newton Launcher",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_push",
        can_be_random_gift = true,
        factor_rarity = 7, factor_quality = 5,
        attrib_sound = GiftSound.Pulsing,     attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Powerful,
    },
    position_swapper = GiftData.New {
        name     = "Position Swapper",     desc       = "a Position Swapper",
        category = GiftCategory.WorldSWEP, identifier = "posswitch",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.RealityWarp,
    },
    prop_disguiser = GiftData.New {
        name     = "Prop Disguiser",       desc       = "a solid disguise",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_prop_disguiser",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = 5,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.RealityWarp,
    },
    prop_exploder_v2 = GiftData.New {
        name     = "Prop Exploder v2",     desc       = "an explosive chip",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_propexploderv2",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Long,
        mv_hook = "HUDDrawMarkerVisionPropExploder",
    },
    prop_exploder = GiftData.New {
        name     = "Prop Exploder",        desc       = "an explosive chip",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_propexploder",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Long,
    },
    prop_rain = GiftData.New {
        name     = "Prop Rain",                desc       = "a furniture airdrop",
        category = GiftCategory.AutoEquipSWEP, identifier = "weapon_prop_rain",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Leather, attrib_feel = GiftFeel.Random,
    },
    poltergeist = GiftData.New {
        name     = "Poltergeist",          desc       = "a force from beyond",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_phammer",
        can_be_random_gift = true,
        factor_rarity = 7, factor_quality = 7,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Ghostly,
    },
    remove_tool = GiftData.New {
        name     = "Remove Tool",          desc       = "a level editor",
        category = GiftCategory.WorldSWEP, identifier = "ttt_pap_remove_tool",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.RealityWarp,
    },
    rng_launcher = GiftData.New {
        name     = "RNG Launcher",         desc       = "a grenade dispenser",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_rnglauncher",
        can_be_random_gift = true,
        factor_rarity = 7, factor_quality = 5,
        attrib_sound = GiftSound.Thudding,  attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Random,
    },
    rocket_jumper = GiftData.New {
        name     = "Rocket Jumper",        desc       = "a Rocket Jumper",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_rocket_jumper",
        can_be_random_gift = true,
        factor_rarity = 8, factor_quality = 9,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Heavy,
    },
    sandwich = GiftData.New {
        name     = "Sandwich",             desc       = "a decomposing sandwich",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_sandwich",
        can_be_random_gift = true,
        factor_rarity = 0.7, factor_quality = 4,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Fresh,
        special_setup = "sandwich_setup",
    },
    shark_idol = GiftData.New {
        name     = "Shark Idol",           desc       = "a golden relic",
        category = GiftCategory.WorldSWEP, identifier = "weapon_shark_idol",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Salty,  attrib_feel = GiftFeel.Cursed,
    },
    sopd = GiftData.New {
        name     = "Sword of Player Defeat",
        category = GiftCategory.WorldSWEP,   identifier = "weapon_ttt_sopd",
        can_be_random_gift = true,
        factor_rarity = 15, factor_quality = 7,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Strange, attrib_feel = GiftFeel.Sharp, -- could also go with Cursed but Sharp is underused
        special_setup = "sopd_setup",
    },
    speedgun = GiftData.New {
        name     = "Speedgun",             desc       = "a caffeine gun",
        category = GiftCategory.WorldSWEP, identifier = "speedgun",
        can_be_random_gift = true,
        factor_rarity = 6, factor_quality = 5,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Caffeine,  attrib_feel = GiftFeel.Warm,
    },
    stungun = GiftData.New {
        name     = "Stungun",              desc       = "a Stungun",
        category = GiftCategory.WorldSWEP, identifier = "stungun",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 7,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Electric,
    },
    suicide_bomb = GiftData.New {
        name     = "Suicide Bomb",         desc       = "a suicide vest",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_suicide",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Cursed, -- on the fence for this pick
    },
    super_magneto = GiftData.New {
        name     = "Super Magneto-Stick",  desc       = "a magic wand",
        category = GiftCategory.WorldSWEP, identifier = "weapon_super_carry",
        can_be_random_gift = true,
        factor_rarity = 7, factor_quality = 6,
        attrib_sound = GiftSound.None,  attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Woody, attrib_feel = GiftFeel.Powerful,
        visual_override = {path = "models/weapons/w_stunbaton.mdl", type = "model"}
    },
    teleporter = GiftData.New {
        name     = "Teleporter",           desc       = "a high-tech flip phone",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_teleport",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 4,
        attrib_sound = GiftSound.Beeping,     attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Futuristic,
    },
    tesla_bow = GiftData.New {
        name     = "Tesla Bow",            desc       = "an electric bow",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_teslabow",
        can_be_random_gift = true,
        factor_rarity = 10, factor_quality = 8,
        attrib_sound = GiftSound.Beeping, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Futuristic,
    },
    thermal_rifle = GiftData.New {
        name     = "Thermal Rifle",        desc       = "a gun-mounted heat vision goggle",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_thermalrifle",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 5,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Ash,      attrib_feel = GiftFeel.Long,
    },
    thruster_gun = GiftData.New {
        name     = "Thruster Gun",         desc       = "a Thruster Gun",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_thruster",
        can_be_random_gift = false,
        --factor_rarity = 9, factor_quality = 5,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Dusty,     attrib_feel = GiftFeel.Hot,
    },
    trigger_finger = GiftData.New {
        name     = "Trigger-Finger Chip",  desc       = "a high-tech brain chip",
        category = GiftCategory.WorldSWEP, identifier = "traitor_chip",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -4,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Mini,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.VerySmall,
    },
    up_n_atomizer = GiftData.New {
        name     = "Up-n-Atomizer",        desc       = "an atom blaster",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_upnatomizer",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Pulsing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Otherworldly,
    },
    viral_syringe = GiftData.New {
        name     = "Viral Syringe",        desc       = "the gift of virality",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_virussyringe",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Scientific,
    },
    weapon_jammer = GiftData.New {
        name     = "Weapon Jammer",            desc       = "a Weapon Jammer",
        category = GiftCategory.AutoEquipSWEP, identifier = "weapon_ttt_wpnjammer",
        can_be_random_gift = true,
        factor_rarity = 7, factor_quality = 6,
        attrib_sound = GiftSound.Muffled, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Negative,
    },

    ----------------------------------------------------------------------
    -- Items
    amaterasu = GiftData.New {
        name     = "Amaterasu",       desc       = "Naruto-branded contacts",
        category = GiftCategory.Item, identifier = "amaterasu_name",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = -8,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Ash,       attrib_feel = GiftFeel.Cursed,
        special_setup = "amaterasu_setup",
    },
    blue_bull = GiftData.New {
        name     = "Blue Bull",       desc       = "wings",
        category = GiftCategory.Item, identifier = "item_ttt_blue_bull",
        can_be_random_gift = true,
        factor_rarity = 6, factor_quality = 9,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,      attrib_feel = GiftFeel.Cold,
        special_setup = "perk_bottle",
    },
    body_armor = GiftData.New {
        name     = "Body Armor",      desc       = "some stylish armor",
        category = GiftCategory.Item, identifier = "item_ttt_armor",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 5,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Nice,     attrib_feel = GiftFeel.Sturdy,
        can_get_multiple = true,
    },
    climb = GiftData.New {
        name     = "Climb",           desc       = "parkour skills",
        category = GiftCategory.Item, identifier = "item_ttt_climb",
        can_be_random_gift = true,
        factor_rarity = 5, factor_quality = 10,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Earthy,    attrib_feel = GiftFeel.Magical,
    },
    disguiser = GiftData.New {
        name     = "Disguiser",       desc       = "a basic disguise kit",
        category = GiftCategory.Item, identifier = "item_ttt_disguiser",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping,     attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Magical,
    },
    flatline_det = GiftData.New {
        name     = "Flatline Detector", desc       = "a corpse radar",
        category = GiftCategory.Item,   identifier = "item_ttt_corpseradar",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 4,
        attrib_sound = GiftSound.Beeping, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Rotten,  attrib_feel = GiftFeel.Electric,
    },
    glider = GiftData.New {
        name     = "Glider",           desc      = "a parachute in your favorite color",
        category = GiftCategory.Item, identifier = "item_ttt_glider",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 6,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Rubbery,   attrib_feel = GiftFeel.Sturdy,
    },
    juggernaut_suit = GiftData.New {
        name     = "Juggernaut Suit", desc       = "heavy armor",
        category = GiftCategory.Item, identifier = "item_ttt_juggernaut_suit",
        can_be_random_gift = true,
        factor_rarity = 5, factor_quality = 8,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Heavy,
    },
    pog_instant = GiftData.New { -- weird bug (og addon): will always try giving you a pap upgrade if holding something that doesn't have one lol
        name     = "Pot of Greedier (Instant)", desc       = "Pot of Greed, which lets you draw two additional gifts from your deck",
        category = GiftCategory.Item,           identifier = "item_ttt_potofgreedier",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Clay,  attrib_feel = GiftFeel.Random,
        can_get_multiple = true,
    },
    pap = GiftData.New {
        name     = "Pack-a-Punch",    desc       = "a fresh coat of paint",
        category = GiftCategory.Item, identifier = "ttt2_pap_item",
        can_be_random_gift = true,
        factor_rarity = 5, factor_quality = 5,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Paint,   attrib_feel = GiftFeel.Powerful,
        special_setup = "pap_setup", can_get_multiple = true
    },
    radar = GiftData.New {
        name     = "Radar",           desc       = "a toy radar",
        category = GiftCategory.Item, identifier = "item_ttt_radar",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 6,
        attrib_sound = GiftSound.Beeping,     attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Electric,
    },
    speedrun = GiftData.New {
        name     = "Speedrun",        desc       = "an upgraded run button",
        category = GiftCategory.Item, identifier = "item_ttt_speedrun",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = 8,
        attrib_sound = GiftSound.Whooshing,   attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Slippery,
    },
    wormpack = GiftData.New {
        name     = "Wormpack",        desc       = "a jetpack",
        category = GiftCategory.Item, identifier = "item_ttt_worm_jetpack",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = 8,
        attrib_sound = GiftSound.Revving, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Ash,     attrib_feel = GiftFeel.Warm,
    },
}



-------------------------------
-- Catalog-related public utils
-------------------------------

-- defined explicitly for use by other addons
function NewGiftData(tbl)
    local newGift = GiftData.New(tbl)

    -- correct references to static tables for identity checks
    for category, data in pairs(GiftCategory) do
        if data.id == tbl.category.id then
            newGift.category = data
            break
        end
    end

    -- client-side furnish with client-only SWEP/Item info
    if CLIENT and newGift.placeholderEquip then
        local swep = weapons.GetStored(newGift.identifier)
        local item = items.GetStored(newGift.identifier)

        if swep then
            if swep.PrintName then newGift.name = utils.TL(swep.PrintName) end
            if swep.desc then newGift.desc = utils.TL(swep.desc) end

        elseif item then
            if item.PrintName then newGift.name = utils.TL(item.PrintName) end
            if item.desc then newGift.desc = utils.TL(item.desc) end
        end
    end

    return newGift
end

function GetGiftCatalog()
    return giftDataCatalog
end

function UpdateCatalog(label, giftData)
    giftDataCatalog[label] = giftData
end

function GetGiftDataFromLabel(giftLabel)
    if not giftLabel then return nil end

    for label, giftData in pairs(giftDataCatalog) do
        if label == giftLabel then
            return giftData
        end
    end
end

local GunType = {
    Pistol  = "pistol",
    Shotgun = "shotgun",
    Rifle   = "rifle",
    Minigun = "minigun",
    Other   = nil,
}

-- to populate the list with standard (non-random / equiprobable) gun data
local standardGuns = {
    ares_shrike   = {cat = GiftCategory.FloorSWEP, name = "Ares Shrike",     id = "weapon_hp_ares_shrike",      an=true,  random=true, rarity=1, quality=-1,  type = GunType.Minigun},
    ak47          = {cat = GiftCategory.WorldSWEP, name = "AK47",            id = "weapon_ttt_ak47",            an=true,  random=false,                       type = GunType.Other,   smell = GiftSmell.Woody},
    aug           = {cat = GiftCategory.FloorSWEP, name = "AUG",             id = "weapon_ttt_aug",             an=true,  random=true, rarity=1, quality=1,   type = GunType.Other},
    blunderbus    = {cat = GiftCategory.WorldSWEP, name = "Blunderbus",      id = "weapon_ttt_blunderbus",      an=false, random=false,                       type = GunType.Other,   sound = GiftSound.Thudding, smell = GiftSmell.Dusty, feel = GiftFeel.Powerful},
    catgun        = {cat = GiftCategory.FloorSWEP, name = "M1A0 Cat Gun",    id = "weapon_catgun",              an=false, random=true, rarity=1, quality=2,   type = GunType.Other,   sound = GiftSound.Meowing, smell = GiftSmell.Fur, feel = GiftFeel.Alive, altname = "stray catgun"},
    dance_gun     = {cat = GiftCategory.FloorSWEP, name = "Dance Gun",       id = "dancedead",                  an=false, random=false,                       type = GunType.Pistol,  sound = GiftSound.Musical, smell = GiftSmell.Sterile},
    deagle        = {cat = GiftCategory.FloorSWEP, name = "Deagle",          id = "weapon_zm_revolver",         an=false, random=true, rarity=1, quality=3,   type = GunType.Pistol,  pistol = true},
    double_barrel = {cat = GiftCategory.WorldSWEP, name = "Double Barrel",   id = "weapon_sp_dbarrel",          an=false, random=false,                       type = GunType.Shotgun, feel = GiftFeel.Powerful},
    famas         = {cat = GiftCategory.FloorSWEP, name = "Famas",           id = "weapon_ttt_famas",           an=false, random=true, rarity=1, quality=1,   type = GunType.Other},
    g3sg1         = {cat = GiftCategory.FloorSWEP, name = "G3SG1",           id = "weapon_ttt_g3sg1",           an=false, random=true, rarity=1, quality=1,   type = GunType.Rifle},
    galil         = {cat = GiftCategory.FloorSWEP, name = "Galil",           id = "weapon_ttt_galil",           an=false, random=true, rarity=1, quality=1,   type = GunType.Other},
    glock         = {cat = GiftCategory.FloorSWEP, name = "Glock",           id = "weapon_ttt_glock",           an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol},
    hmt           = {cat = GiftCategory.FloorSWEP, name = "HMT-10",          id = "weapon_ttt_milk_hmt10",      an=true,  random=true, rarity=1, quality=0,   type = GunType.Pistol},
    honey_badger  = {cat = GiftCategory.FloorSWEP, name = "Honey Badger",    id = "weapon_ap_hbadger",          an=false, random=true, rarity=1, quality=0,   type = GunType.Other,   smell = GiftSmell.Food},
    huge          = {cat = GiftCategory.FloorSWEP, name = "H.U.G.E-249",     id = "weapon_zm_sledge",           an=false, random=true, rarity=1, quality=-1,  type = GunType.Minigun, size = GiftSize.Huge, altname = "H.U.G.E"},
    kr_vector     = {cat = GiftCategory.FloorSWEP, name = "Kriss Vector",    id = "weapon_ap_vector",           an=false, random=true, rarity=1, quality=1,   type = GunType.Other,   feel = GiftFeel.Futuristic},
    ksg           = {cat = GiftCategory.FloorSWEP, name = "KSG",             id = "weapon_ttt_ksg",             an=false, random=true, rarity=1, quality=1,   type = GunType.Shotgun},
    m16           = {cat = GiftCategory.FloorSWEP, name = "M16",             id = "weapon_ttt_m16",             an=true,  random=true, rarity=1, quality=0,   type = GunType.Other},
    m3s90         = {cat = GiftCategory.FloorSWEP, name = "M3S90",           id = "weapon_ttt_m3s90",           an=true,  random=true, rarity=1, quality=1,   type = GunType.Shotgun, sound = GiftSound.Thudding},
    mac10         = {cat = GiftCategory.FloorSWEP, name = "MAC10",           id = "weapon_zm_mac10",            an=false, random=true, rarity=1, quality=0,   type = GunType.Other},
    mauser        = {cat = GiftCategory.FloorSWEP, name = "Mauser C96",      id = "weapon_mauser",              an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol,  smell = GiftSmell.Woody, feel = GiftFeel.Bursting},
    mp5           = {cat = GiftCategory.FloorSWEP, name = "MP5 Navy",        id = "weapon_ttt_mp5",             an=true,  random=true, rarity=1, quality=0,   type = GunType.Other},
    mp5k          = {cat = GiftCategory.WorldSWEP, name = "MP5K",            id = "weapon_ttt_mp5k",            an=true,  random=false, rarity=1, quality=3,  type = GunType.Other},
    mp7           = {cat = GiftCategory.FloorSWEP, name = "MP7",             id = "weapon_ttt_smg",             an=true,  random=true, rarity=1, quality=0,   type = GunType.Other},
    mrca1         = {cat = GiftCategory.FloorSWEP, name = "MR-CA1",          id = "weapon_ap_mrca1",            an=true,  random=true, rarity=1, quality=0,   type = GunType.Other},
    p228          = {cat = GiftCategory.FloorSWEP, name = "P228",            id = "weapon_ttt_p228",            an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol},
    p90           = {cat = GiftCategory.WorldSWEP, name = "P90",             id = "weapon_ttt_p90",             an=false, random=true, rarity=3, quality=6,   type = GunType.Other},
    pistol        = {cat = GiftCategory.FloorSWEP, name = "Pistol",          id = "weapon_zm_pistol",           an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol},
    pocket_rifle  = {cat = GiftCategory.FloorSWEP, name = "Pocket Rifle",    id = "weapon_rp_pocket",           an=false, random=true, rarity=1, quality=1,   type = GunType.Rifle,   size = GiftSize.Mini, feel = GiftFeel.VerySmall},
    pp19          = {cat = GiftCategory.FloorSWEP, name = "PP-19 Bizon",     id = "weapon_ap_pp19",             an=false, random=true, rarity=1, quality=0,   type = GunType.Other},
    pump_shotgun  = {cat = GiftCategory.FloorSWEP, name = "Pump Shotgun",    id = "weapon_ttt_pump",            an=false, random=true, rarity=1, quality=0,   type = GunType.Shotgun, smell = GiftSmell.Dusty},
    r8_revolver   = {cat = GiftCategory.FloorSWEP, name = "R8 Revolver",     id = "weapon_ttt_csgo_r8revolver", an=true,  random=true, rarity=1, quality=0,   type = GunType.Pistol,  size = GiftSize.Normal},
    raging_bull   = {cat = GiftCategory.FloorSWEP, name = "Raging Bull",     id = "weapon_pp_rbull",            an=false, random=true, rarity=1, quality=1,   type = GunType.Pistol,  smell = GiftSmell.Dusty},
    railgun       = {cat = GiftCategory.WorldSWEP, name = "Railgun",         id = "weapon_rp_railgun",          an=false, random=true, rarity=6, quality=8,   type = GunType.Rifle,   sound = GiftSound.Revving},
    railrifle     = {cat = GiftCategory.WorldSWEP, name = "Railrifle",       id = "weapon_ttt_railslug",        an=false, random=false,                       type = GunType.Rifle,   sound = GiftSound.Revving},
    reming_pistol = {cat = GiftCategory.FloorSWEP, name = "Remington 1858",  id = "weapon_pp_remington",        an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol,  smell = GiftSmell.Dusty},
    reming_shgun  = {cat = GiftCategory.FloorSWEP, name = "Remington AE870", id = "weapon_ttt_milk_870",        an=false, random=true, rarity=1, quality=1,   type = GunType.Shotgun, smell = GiftSmell.Woody},
    rifle         = {cat = GiftCategory.FloorSWEP, name = "Rifle",           id = "weapon_zm_rifle",            an=false, random=true, rarity=1, quality=2,   type = GunType.Rifle},
    s357          = {cat = GiftCategory.WorldSWEP, name = "'SUPER' 357",     id = "weapon_ttt_s357",            an=false, random=false, rarity=1, quality=-8, type = GunType.Pistol,  feel = GiftFeel.Cursed},
    sw500         = {cat = GiftCategory.WorldSWEP, name = "S&W 500",         id = "weapon_ttt_revolver",        an=true,  random=false,                       type = GunType.Pistol,  feel = GiftFeel.Powerful},
    sg550         = {cat = GiftCategory.FloorSWEP, name = "SG-550",          id = "weapon_ttt_sg550",           an=true,  random=true, rarity=1, quality=0,   type = GunType.Rifle},
    shotgun       = {cat = GiftCategory.FloorSWEP, name = "Shotgun",         id = "weapon_zm_shotgun",          an=false, random=true, rarity=1, quality=0,   type = GunType.Shotgun},
    silent_awp    = {cat = GiftCategory.WorldSWEP, name = "Silenced AWP",    id = "weapon_ttt_awp",             an=false, random=false,                       type = GunType.Rifle,   silenced = true},
    silent_m4a1   = {cat = GiftCategory.WorldSWEP, name = "Silenced M4A1",   id = "weapon_ttt_silm4a1",         an=false, random=false,                       type = GunType.Other,   silenced = true},
    silent_pistol = {cat = GiftCategory.WorldSWEP, name = "Silenced Pistol", id = "weapon_ttt_sipistol",        an=false, random=false,                       type = GunType.Pistol,  silenced = true},
    silent_smg    = {cat = GiftCategory.FloorSWEP, name = "Silent Fox",      id = "weapon_ttt_tmp_s",           an=false, random=true, rarity=5, quality=3,   type = GunType.Other,   silenced = true, smell = GiftSmell.Fur},
    striker       = {cat = GiftCategory.WorldSWEP, name = "Striker-12",      id = "weapon_sp_striker",          an=false, random=true, rarity=5, quality=3,   type = GunType.Other},
    tec9          = {cat = GiftCategory.FloorSWEP, name = "TEC-9",           id = "weapon_ap_tec9",             an=false, random=true, rarity=1, quality=3,   type = GunType.Other,   feel = GiftFeel.Meta},
    thompson      = {cat = GiftCategory.FloorSWEP, name = "1928 Thompson",   id = "weapon_ttt_milk_tommygun",   an=false, random=true, rarity=1, quality=0,   type = GunType.Other,   smell = GiftSmell.Woody},
    tmp           = {cat = GiftCategory.FloorSWEP, name = "TMP",             id = "weapon_ttt_tmp",             an=false, random=true, rarity=1, quality=2,   type = GunType.Other,   feel = GiftFeel.Muffled},
    typhon        = {cat = GiftCategory.WorldSWEP, name = "'TYHPHON' AMR",   id = "weapon_ttt_typhon",          an=false, random=false,                       type = GunType.Rifle,   feel = GiftFeel.Powerful},
    us_dmr        = {cat = GiftCategory.FloorSWEP, name = "U.S DMR",         id = "weapon_ttt_m14",             an=false, random=true, rarity=1, quality=1,   type = GunType.Shotgun}, --shhh
    ump_prototype = {cat = GiftCategory.WorldSWEP, name = "UMP Prototype",   id = "weapon_ttt_stungun",         an=false, random=true, rarity=8, quality=7, type = GunType.Other,     sound = GiftSound.Whirring, feel = GiftFeel.Electric},
    usp           = {cat = GiftCategory.FloorSWEP, name = "USP",             id = "weapon_ttt_pistol",          an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol},
    winchester    = {cat = GiftCategory.FloorSWEP, name = "Winchester 1873", id = "weapon_sp_winchester",       an=false, random=true, rarity=1, quality=1,   type = GunType.Shotgun, sound = GiftSound.Creaky, smell = GiftSmell.Dusty},
}

for label, data in pairs(standardGuns) do
    local SWEPSmell = data.smell or GiftSmell.Gunpowder

    local isLong  = (data.type == GunType.Rifle or data.type == GunType.Shotgun)
    local isSmall = (data.type == GunType.Pistol)

    local SWEPSound = data.sound
    if not SWEPSound then
        if data.silenced then
            SWEPSound = GiftSound.Muffled
        elseif data.type == GunType.Minigun then
            SWEPSound = GiftSound.Revving
        else
            SWEPSound = GiftSound.Metallic
        end
    end

    local SWEPFeel = data.feel
    if not SWEPFeel then
        if isLong then
            SWEPFeel = GiftFeel.Long
        elseif isSmall then
            SWEPFeel = GiftFeel.Light
        elseif data.type == GunType.Minigun then
            SWEPFeel = GiftFeel.Heavy
        else
            SWEPFeel = GiftFeel.Cold
        end
    end

    local SWEPSize  = data.size
    if not SWEPSize then
        if isLong or data.type == GunType.Minigun then
            SWEPSize = GiftSize.Big
        elseif isSmall then
            SWEPSize = GiftSize.Small
        else
            SWEPSize = GiftSize.Large
        end
    end

    UpdateCatalog(label, GiftData.New {
        name     = data.name, desc       = (data.an and "an " or "a ")..(data.altname or data.name),
        category = data.cat,  identifier = data.id,
        can_be_random_gift = data.random,
        factor_rarity  = data.random and data.rarity  or nil,
        factor_quality = data.random and data.quality or nil,
        attrib_sound = SWEPSound, attrib_size = SWEPSize,
        attrib_smell = SWEPSmell, attrib_feel = SWEPFeel,
    })
end


-- to populate the list with SWEPs that also have a SENT tied to them (cf. ADS, which should be using this)
local deployableSWEPs = {
    ads     = {name = "ADS", desc = "a defensive sentry bot",
               SENT_id = "ads", SWEP_id = "adsplacer",
               SENT_setup_var = {k = "stick_to_ground"},
               SENT_random = false, --SENT_rarity = 3, SENT_quality = 6,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Small,
               sound = GiftSound.Beeping, smell = GiftSmell.Gunpowder, feel = GiftFeel.Electric},

    banana  = {SENT_name = "Banana Peel", SENT_desc = "an old banana peel",
               SWEP_name = "Banana",      SWEP_desc = "a fresh banana",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_banana_peel", SWEP_id = "ttt_banana",
               SWEP_setup_var = {k = "visual_override", v = {path = "models/props/cs_italy/bananna.mdl", type = "model"}},
               SENT_setup_var = {k = "adjAngle", v = Angle(90, 0, 0)},
               SENT_random = true, SENT_rarity = 1, SENT_quality = -5,
               SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Small,
               sound = GiftSound.Squishy, smell = GiftSmell.Rotten, feel = GiftFeel.Slippery,
               SWEP_smell = GiftSmell.Food, SWEP_feel = GiftFeel.Fresh},

    banana_bomb = {name = "Banana Bomb", desc = "an explosive bunch",
               SENT_id = "ttt_banana_proj", SWEP_id = "weapon_ttt_banana",
               SENT_setup = "grenade", SENT_setup_var = {{k = "set_owner"}, {k = "explosion_delay", v = 2}},
               SWEP_setup_var = {k = "visual_override", v = {path = "models/props/cs_italy/bananna_bunch.mdl", type = "model"}},
               SENT_random = true, SENT_rarity = 6, SENT_quality = -10,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Large,
               sound = GiftSound.Squishy, smell = GiftSmell.Gunpowder, feel = GiftFeel.Fresh},

    barnacle  = {name = "Barnacle", desc = "a hungry barnacle",
               SWEP_desc = "a hungry pet barnacle",
               SENT_category = GiftCategory.NPC,
               SENT_id = "npc_barnacle", SWEP_id = "weapon_ttt_barnacle",
               SENT_setup = "barnacle_setup", SENT_setup_var = {k = "mv_hook", v = "BarnacleMarkerVisionDisplay"},
               SENT_random = true, SENT_rarity = 3, SENT_quality = -9,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Large,
               sound = GiftSound.Fleshy, smell = GiftSmell.Rotten, feel = GiftFeel.Alive},

    baron_hat = {name = "Baron Hat", desc = "a bougie hat",
               SWEP_category = GiftCategory.Item,
               SENT_id = "ttt2_hat_baron", SWEP_id = "item_ttt2_baron_hat",
               SENT_setup = "baron_hat_drop", SWEP_setup = "baron_hat_setup",
               SENT_random = true, SENT_rarity = 1, SENT_quality = 8,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.None, smell = GiftSmell.Leather, feel = GiftFeel.Round},

    beacon  = {name = "Beacon", desc = "a high-tech beacon",
               SENT_id = "ttt_beacon", SWEP_id = "weapon_ttt_beacon",
               SENT_setup_var = {k = "set_thrower"},
               SWEP_setup_var = {k = "worldmodel_fix"},
               SENT_random = true, SENT_rarity = 1, SENT_quality = 3,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Larger,
               sound = GiftSound.Pulsing, smell = GiftSmell.Sterile, feel = GiftFeel.Bright},

    br_charge = {name = "Breaching Charge", desc = "a wall-mounted grenade dispenser",
               SENT_id = "matryoshka", SWEP_id = "matryoshkaplacer",
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Larger,
               sound = GiftSound.Metallic, smell = GiftSmell.Gunpowder, feel = GiftFeel.Electric},

    c4      = {name = "C4", desc = "a bomb",
               SENT_id = "ttt_c4", SWEP_id = "weapon_ttt_c4",
               SENT_setup = "c4_setup", SENT_setup_var = {k = "mv_hook", v = "HUDDrawMarkerVisionC4"},
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Beeping, smell = GiftSmell.Gunpowder, feel = GiftFeel.Heavy},

    camera  = {name = "Camera", desc = "a brand-new camera",
               SENT_id = "ent_ttt_ttt2_camera", SWEP_id = "weapon_ttt_ttt2_camera",
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 4,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Large,
               sound = GiftSound.Metallic, smell = GiftSmell.Glass, feel = GiftFeel.Sturdy},

    chicken_egg = {name = "Chicken Egg", desc = "an egg ready to hatch",
               SENT_id = "sent_egg", SWEP_id = "weapon_ttt_chickennade",
               SENT_setup_var = {k = "set_owner"},
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Glass, smell = GiftSmell.Food, feel = GiftFeel.Round},

    clutterbomb = {name = "Clutterbomb", desc = "a furniture bomb",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_clutterbomb_proj", SWEP_id = "weapon_ttt_clutterbomb",
               SENT_setup = "grenade",
               SENT_random = true, SENT_rarity = 1, SENT_quality = -3,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = -1,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Thudding, smell = GiftSmell.Dusty, feel = GiftFeel.Random},
    clusterbomb = {name = "Clusterbomb", desc = "a furniture bomb",
               SENT_id = "ttt_rclutterbomb_proj", SWEP_id = "weapon_ttt_rclutterbomb",
               SENT_setup = "grenade",
               SENT_random = true, SENT_rarity = 3, SENT_quality = -6,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Beeping, smell = GiftSmell.Dusty, feel = GiftFeel.Random,
               SWEP_desc = "a rigged furniture bomb"},

    conc_mine = {name = "Concussion Mine", desc = "a whoopie cushion",
               SENT_id = "ttt_conmine", SWEP_id = "weapon_ttt_concussionmine",
               SENT_setup = "conc_mine_setup", SENT_setup_var = {{k = "set_owner"}, {k = "mv_hook", v = "HUDDrawMarkerVisionConmine"}},
               SENT_random = true, SENT_rarity = 4, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Beeping, smell = GiftSmell.Sterile, feel = GiftFeel.Hollow},

    ctrl_manhack = {name = "Controllable Manhack", desc = "a remote-control drone",
               SENT_id = "sent_controllable_manhack", SWEP_id = "weapon_controllable_manhack",
               SENT_setup = "manhack_setup",
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 2, SWEP_quality = 6,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Whirring, smell = GiftSmell.Rusty, feel = GiftFeel.Bursting},

    d20     = {name = "D20",             desc = "a DND dice",
               SENT_id = "ttt_d20_proj", SWEP_id = "ttt_d20",
               SENT_setup = "grenade",
               SENT_random = false, --SENT_rarity = 20, SENT_quality = 0,
               SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Glass, smell = GiftSmell.Mineral, feel = GiftFeel.Random},

    decoy   = {name = "Decoy",        desc = "a high-tech decoy",
               SENT_id = "ttt_decoy", SWEP_id = "weapon_ttt_decoy",
               SWEP_setup_var = {k = "worldmodel_fix"},
               SENT_random = false,   SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whirring, smell = GiftSmell.Sterile, feel = GiftFeel.Scientific},

    deployable_force_shield = {name = "Deployable Force Shield", desc = "a next-gen force shield",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "shield_deployer", SWEP_id = "weapon_ttt_force_shield",
               SENT_setup = "shield_deployer_setup",
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Pulsing, smell = GiftSmell.Nondescript, feel = GiftFeel.Bright,
               SWEP_smell = GiftSmell.Sterile},

    discombob = {name = "Discombobulator", desc = "an air-filled grenade",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_confgrenade_proj", SWEP_id = "weapon_ttt_confgrenade",
               SENT_setup = "grenade", SENT_setup_var = {k = "explosion_delay", v = 0.2},
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Whooshing, smell = GiftSmell.Gunpowder, feel = GiftFeel.Hollow},

    emp     = {name = "EMP Grenade", desc = "an EMP grenade",
               SENT_id = "ttt_emp_proj", SWEP_id = "weapon_ttt_emp",
               SENT_setup = "grenade", SENT_setup_var = {k = "explosion_delay", v = 3},
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Pulsing, smell = GiftSmell.Nondescript, feel = GiftFeel.Electric},

    fan     = {name = "Fan", desc = "a powerful fan",
               SENT_id = "ent_ttt_fan", SWEP_id = "weapon_fan",
               SENT_setup = "fan_setup", SENT_setup_var = {{k = "ambush_giftee"}, {k = "ambush_angle", v = -90}, {k = "ambush_yoff", v = 18}, {k = "mv_hook", v = "FanMarkerVisionDisplay"}},
               SENT_random = true, SENT_rarity = 3, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whirring, smell = GiftSmell.Dusty, feel = GiftFeel.Moving},

    fart_grenade = {name = "Fart Grenade", desc = "gas",
               SENT_id = INVALID_ID, SWEP_id = "weapon_fartgrenade",
               SENT_setup = "fart_grenade_setup", SENT_setup_var = {k = "visual_override", v = {path = "models/weapons/w_grenade.mdl", type = "model"}},
               SENT_random = true, SENT_rarity = 2, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Muffled, smell = GiftSmell.Rotten, feel = GiftFeel.Bursting,
               SWEP_desc = "a cupped fart"},

    fireball = {name = "Fireball", desc = "a fireball", SWEP_desc = "fire magic",
               SENT_category = GiftCategory.PhysProp, SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = INVALID_ID, SWEP_id = "weapon_firemagic",
               SENT_setup = "fireball_setup", SENT_setup_var = {k = "visual_override", v = {path = "effects/flame", type = "sprite"}},
               SENT_random = false,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Whooshing, smell = GiftSmell.Ash, feel = GiftFeel.Magical},

    flashbang = {name = "Flashbang", desc = "a 5-second blinding stew",
               SENT_id = "ttt_thrownflashbang", SWEP_id = "weapon_ttt_flashbang",
               SENT_setup = "grenade_auto", SENT_setup_var = {k = "explosion_delay", v = 2},
               SENT_random = true, SENT_rarity = 4, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Metallic, smell = GiftSmell.Food, feel = GiftFeel.Bright,
               SWEP_desc = "a flashbang"},

    fortnite = {name = "Fortnite Building", desc = "a Fortnite structure",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ent_fortnitestructure", SWEP_id = "weapon_ttt_fortnite_building",
               SENT_setup = "fortnite_struct_setup", SENT_setup_var = {{k = "no_physwake"}, {k = "dont_furnish"}},
               SENT_random = true, SENT_rarity = 1, SENT_quality = 1,
               SWEP_random = true, SWEP_rarity = 7, SWEP_quality = 9,
               SENT_size = 10, SWEP_size = GiftSize.Large,
               sound = GiftSound.Thudding, smell = GiftSmell.Cardboard, feel = GiftFeel.Otherworldly,
               SWEP_desc = "a Fortnite Battle Pass", SENT_name = "Fortnite Structure"},

    frag_grenade = {name = "Frag Grenade", desc = "an actual grenade",
               SENT_id = "ttt_frag_proj", SWEP_id = "weapon_ttt_frag",
               SENT_setup = "grenade",
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Thudding, smell = GiftSmell.Gunpowder, feel = GiftFeel.Round},

    giftwrap = {name = "Gift Wrap", desc = "another gift",
               SENT_id = PROP_CLASS_NAME, SWEP_id = SWEP_CLASS_NAME,
               SENT_name = "Wrapped Gift",
               SENT_setup = "gift_setup", SWEP_setup = "giftwrap_desc",
               SENT_random = true, SENT_rarity = 0.8, SENT_quality = 2,
               SWEP_random = true, SWEP_rarity = 2,   SWEP_quality = 4,
               SWEP_size = GiftSize.Huge,
               sound = GiftSound.Rustling, smell = GiftSmell.Paper, feel = GiftFeel.Jolly},

    glue_trap = {name = "Glue Trap", desc = "a sticky prank toy",
               SENT_id = "glue_trap_paste", SWEP_id = "weapon_ttt_glue_trap",
               SENT_setup_var = {{k = "stick_to_ground"}, {k = "move_to_giftee"}},
               SENT_random = true, SENT_rarity = 1, SENT_quality = -6,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 5,
               SENT_size = GiftSize.Gigantic, SWEP_size = GiftSize.Large,
               sound = GiftSound.Goopy, smell = GiftSmell.Cardboard, feel = GiftFeel.Sticky},

    green_demon_box = {name = "Green Demon Box", desc = "a 1-UP",
               SENT_id = "sent_greendemon_box", SWEP_id = "weapon_ttt_greendemon",
               SENT_setup_var = {{k = "set_owner"}, {k = "move_to_giftee"}, {k = "mv_hook", v = "HUDDrawMarkerVisionGreenDemonBox"}},
               SWEP_setup_var = {k = "worldmodel_fix"},
               SENT_random = false,
               SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Large,
               sound = GiftSound.Musical, smell = GiftSmell.Food, feel = GiftFeel.Cursed,
               SWEP_desc = "a 1-UP box"},

    groovitron = {name = "Groovitron", desc = "a disco ball",
               SENT_id = "ttt_pap_groovitron_proj", SWEP_id = "ttt_pap_groovitron",
               SENT_setup = "grenade", SENT_setup_var = {{k = "special_setup2", v = "groovitron_setup"}, {k = "mark_invalid"}},
               SENT_random = true, SENT_rarity = 4, SENT_quality = -5,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Musical, smell = GiftSmell.Nondescript, feel = GiftFeel.Bright},

    hand_cannon = {
               SENT_name = "Live Cannonball", SENT_desc = "a cannonball",
               SWEP_name = "Hand Cannon",     SWEP_desc = "an old-timey hand cannon",
               SENT_id = "cannon_ent", SWEP_id = "weapon_hcannon",
               SENT_setup = "cannonball_setup",
               SWEP_setup_var = {k = "visual_override", v = {path = "models/props_phx/cannon.mdl", type = "model"}},
               SENT_random = true, SENT_rarity = 3, SENT_quality = -5,
               SWEP_random = true, SWEP_rarity = 5, SWEP_quality = 5,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Larger,
               sound = GiftSound.Thudding, smell = GiftSmell.Gunpowder, feel = GiftFeel.Round,
               SWEP_sound = GiftSound.Creaky, SWEP_smell = GiftSmell.Salty, SWEP_feel = GiftFeel.Hollow},

    health_station = {name = "Health Station", desc = "a healing microwave",
               SENT_id = "ttt_health_station", SWEP_id = "weapon_ttt_health_station",
               SENT_random = true, SENT_rarity = 5, SENT_quality = 9,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Huge,
               sound = GiftSound.Beeping, smell = GiftSmell.Nice, feel = GiftFeel.Warm},

    hwapoon = {name = "Hwapoon", desc = "a harpoon",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_setup = "harpoon_setup", SENT_setup_var = {k = "set_owner"},
               SENT_id = "hwapoon_arrow", SWEP_id = "weapon_ttt_hwapoon",
               SENT_random = true, SENT_rarity = 4, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Gigantic, SWEP_size = GiftSize.Gigantic,
               sound = GiftSound.Metallic, smell = GiftSmell.Rusty, feel = GiftFeel.Long},

    ice_grenade = {name = "Ice Grenade", desc = "an explosive snowball",
               SENT_id = "icegrenade_proj", SWEP_id = "icegrenade",
               SENT_setup = "icegrenade_setup", SENT_setup_var = {k = "set_owner"},
               SENT_random = true, SENT_rarity = 3, SENT_quality = -5,
               SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Thudding, smell = GiftSmell.Gunpowder, feel = GiftFeel.ReallyCold},

    id_swap_grenade = {name = "Identity Swap Grenade", desc = "a confusion grenade",
               SENT_id = "ttt_id_swap_grenade_proj", SWEP_id = "weapon_ttt_identity_swap_grenade",
               SENT_setup = "grenade",
               SENT_random = true, SENT_rarity = 4, SENT_quality = -1,
               SWEP_random = true, SWEP_rarity = 3, SWEP_quality = 1,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Thudding, smell = GiftSmell.Gunpowder, feel = GiftFeel.RealityWarp},

    incend  = {name = "Incendiary Grenade", desc = "a fiery grenade",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_firegrenade_proj", SWEP_id = "weapon_zm_molotov",
               SENT_setup = "grenade", SENT_setup_var = {k = "explosion_delay", v = 2},
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Thudding, smell = GiftSmell.Ash, feel = GiftFeel.Hot},

    jarate  = {name = "Jarate", desc = "a jar of piss",
               SENT_id = "ttt_jarate_proj", SWEP_id = "weapon_ttt_jarate",
               SENT_setup_var = {k = "set_thrower"},
               SENT_random = true, SENT_rarity = 2, SENT_quality = -5,
               SWEP_random = true, SWEP_rarity = 2, SWEP_quality = 4,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Splashing, smell = GiftSmell.Stinky, feel = GiftFeel.Warm},

    killer_bungers = {name = "Bunger Grenade", desc = "a bunch of angry Bungers",
               SENT_id = "ttt_bungernade_proj", SWEP_id = "weapon_ttt_bungernade",
               SENT_setup = "grenade", SENT_setup_var = {k = "explosion_delay", v = 2},
               SENT_random = false, --SENT_rarity = 5, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Gigantic, SWEP_size = GiftSize.Large,
               sound = GiftSound.Springy, smell = GiftSmell.Food, feel = GiftFeel.Otherworldly},

    knife   = {name = "Knife", desc = "a slick knife",
               SENT_id = "ttt_knife_proj", SWEP_id = "weapon_ttt_knife",
               SENT_setup_var = {k = "set_owner", k = "break_constraints"},
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Metallic, smell = GiftSmell.Sterile, feel = GiftFeel.Sharp},

    lethal_mine = {name = "Lethal Mine", desc = "a landmine",
               SWEP_desc = "a landmine gun",
               SENT_id = "item_lethal_company_landmine", SWEP_id = "weapon_ttt_lethalmine",
               SENT_setup_var = {{k = "stick_to_ground"}, {k = "move_to_giftee"}, {k = "mark_invalid"}, {k = "mv_hook", v = "LethalMineMarkerVisionDisplay"}},
               SENT_random = false, --SENT_rarity = 10, SENT_quality = -10,
               SWEP_random = false,
               SENT_size = GiftSize.Big, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Beeping, smell = GiftSmell.Gunpowder, feel = GiftFeel.Flat},

    m4_slam  = {name = "M4 SLAM", desc = "a SLAM",
               SENT_id = "ttt_slam_satchel", SWEP_id = "weapon_ttt_slam",
               SENT_setup = "slam_setup", SENT_setup_var = {k = "mv_hook", v = "SLAMMarkerVisionDisplay"},
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Beeping, smell = GiftSmell.Gunpowder, feel = GiftFeel.Electric},

    molotov  = {name = "Molotov Cocktail", desc = "a spicy cocktail",
               SENT_id = "sent_molotov", SWEP_id = "molotov_cocktail_for_ttt",
               SENT_setup_var = {k = "set_owner"},
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Splashing, smell = GiftSmell.Oily, feel = GiftFeel.Hot},

    moon_grenade = {name = "Moon Grenade", desc = "a bag of marbles",
               SENT_id = "ent_moongrenade", SWEP_id = "weapon_ttt_moongrenade",
               SENT_setup = "moon_grenade_setup", SENT_setup_var = {k = "visual_override", v = {path = "models/weapons/moongrenade/moongrenade.mdl", type = "model"}},
               SENT_random = true, SENT_rarity = 2, SENT_quality = -3,
               SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Springy, smell = GiftSmell.Mineral, feel = GiftFeel.Otherworldly},

    paper_plane = {name = "Paper Plane", desc = "an origami plane",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ttt_paper_plane_proj", SWEP_id = "weapon_ttt_paper_plane",
               SENT_setup = "paper_plane_setup", SENT_setup_var = {k = "set_thrower"},
               SENT_random = true, SENT_rarity = 2, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Larger,
               sound = GiftSound.Whooshing, smell = GiftSmell.Paper, feel = GiftFeel.Moving},

    poison_station = {name = "Poison Station", desc = "a healing microwave",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ttt_poison_station", SWEP_id = "weapon_ttt_poison_station",
               SENT_setup_var = {{k = "set_thrower"}, {k = "mv_hook", v = "PoisonStationMarkerVisionDisplay"}},
               SENT_random = false,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Huge,
               sound = GiftSound.Beeping, smell = GiftSmell.Nice, feel = GiftFeel.Warm,
               SWEP_desc = "a damaging microwave", SWEP_smell = GiftSmell.Toxic},

    poison_station_v2 = {name = "Poison Station v2",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "prop_poison_station_v2", SWEP_id = "weapon_ttt_poison_station_v2",
               SENT_setup = "poison_station_desc",
               SENT_random = true, SENT_rarity = 4, SENT_quality = -5,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Huge,
               sound = GiftSound.Beeping, smell = GiftSmell.Nice, feel = GiftFeel.Warm,
               SWEP_desc = "a poisonous microwave", SWEP_smell = GiftSmell.Toxic},

    pog     = {name = "Pot of Greedier", desc = "Pot of Greed, which lets you draw two additional gifts from your deck",
               SENT_id = "ttt_potofgreedier", SWEP_id = "weapon_ttt_potofgreedier",
               SENT_setup = "pog_setup",
               SENT_random = true, SENT_rarity = 2, SENT_quality = 7,
               SWEP_random = false,
               SENT_size = GiftSize.Big, SWEP_size = GiftSize.Big,
               sound = GiftSound.Glass, smell = GiftSmell.Clay, feel = GiftFeel.Cursed},

    radio   = {name = "Radio", desc = "a toy radio",
               SENT_id = "ttt_radio", SWEP_id = "weapon_ttt_radio",
               SENT_setup_var = {{k = "set_thrower"}, {k = "mv_hook", v = "HUDDrawMarkerVisionRadio"}},
               SWEP_setup_var = {k = "worldmodel_fix"},
               SENT_random = true, SENT_rarity = 1, SENT_quality = 2,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Musical, smell = GiftSmell.Sterile, feel = GiftFeel.Electric},

    ragnana = {name = "Ragnana",           desc = "an old banana peel",
               SENT_id = "ttt_ragnana_peel", SWEP_id = "ttt_ragnana",
               SENT_random = false, --SENT_rarity = 4, SENT_quality = -9,
               SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Squishy, smell = GiftSmell.Rotten, feel = GiftFeel.Slippery,
               SWEP_desc = "an extremely slippery banana"},

    rcxd    = {name = "RCXD",         desc = "an RC car toy",
               SENT_id = "sent_rcxd", SWEP_id = "weapon_ttt_rcxd",
               --SENT_setup_var = {k = "set_owner"}, -- doesn't work (would need to give SWEP)
               SENT_random = false, --SENT_rarity = 2, SENT_quality = 5,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Revving, smell = GiftSmell.Rusty, feel = GiftFeel.Electric,
               SWEP_desc = "an RC car in a can"},

    shellmet = {name = "Shellmet", desc = "a shiny helmet",
               SWEP_category = GiftCategory.Item,
               SENT_setup = "shellmet_setup", SENT_setup_var = {k = "up_vel", v = 200},
               SENT_id = "ttt2_hat_shellmet", SWEP_id = "item_ttt2_shellmet",
               SENT_random = true, SENT_rarity = 0.8, SENT_quality = 5,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Thudding, smell = GiftSmell.Mineral, feel = GiftFeel.Hollow},

    seekgull_can = {name = "Seekgull in a Can", desc = "a seagull in a can",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_seekgull_proj", SWEP_id = "weapon_ttt_seekgull",
               SENT_setup = "grenade", SENT_setup_var = {k = "set_owner"},
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Whooshing, smell = GiftSmell.Salty, feel = GiftFeel.Alive},

    smoke   = {name = "Smoke Grenade", desc = "a pocket fog machine",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_smokegrenade_proj", SWEP_id = "weapon_ttt_smokegrenade",
               SENT_setup = "grenade",
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Muffled, smell = GiftSmell.Ash, feel = GiftFeel.Hollow},

    soap    = {name = "Soap", desc = "a bar of soap",
               SENT_id = "ttt_soap", SWEP_id = "weapon_ttt_soap",
               SENT_setup_var = {{k = "move_to_giftee"}, {k = "stick_to_ground"}, {k = "set_thrower"}, {k = "mv_hook", v = "HUDDrawMarkerVisionSoap"}},
               SENT_random = true, SENT_rarity = 0.8, SENT_quality = -3,
               SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Goopy, smell = GiftSmell.Nice, feel = GiftFeel.Slippery},

    spring_mine = {name = "Spring Mine", desc = "a comically large spring",
               SENT_id = "ttt_springmine", SWEP_id = "weapon_ttt_springmine",
               SENT_setup_var = {{k = "move_to_giftee"}, {k = "stick_to_ground"}, {k = "set_thrower"}, {k = "mv_hook", v = "HUDDrawMarkerVisionSpringMine"}},
               SENT_random = true, SENT_rarity = 5, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Springy, smell = GiftSmell.Rubbery, feel = GiftFeel.Round},

    star_burster = {name = "Star Burster", desc = "a shooting star",
               SENT_id = "plasma_burster_nade", SWEP_id = "ttt_plasma_burster_nade",
               SENT_setup = "starburst_ent_setup", SENT_setup_var = {k = "set_owner"},
               SENT_random = true, SENT_rarity = 2, SENT_quality = -4,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Whooshing, smell = GiftSmell.Strange, feel = GiftFeel.Bursting},

    super_discombob = {name = "Super Discombobulator", desc = "an air-packed grenade",
               SENT_id = "ttt_confgrenade_proj_super", SWEP_id = "weapon_ttt_confgrenade_s",
               SENT_setup = "grenade", SENT_setup_var = {k = "explosion_delay", v = 2.5},
               SENT_random = true, SENT_rarity = 4, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whooshing, smell = GiftSmell.Gunpowder, feel = GiftFeel.Massive},

    super_smoke = {name = "Super Smoke Grenade", desc = "a smog machine from London",
               SENT_id = "ttt_supersmokegrenade_proj", SWEP_id = "weapon_ttt_supersmoke",
               SENT_setup = "grenade",
               SENT_random = true, SENT_rarity = 6, SENT_quality = -4,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Muffled, smell = GiftSmell.Ash, feel = GiftFeel.Massive},

    teleport_grenade = {name = "Teleport Grenade", desc = "an Ender Pearl",
               SENT_id = "ttt_teleportgren_proj", SWEP_id = "weapon_ttt_teleportgren",
               SENT_setup = "grenade",
               SENT_setup_var = {{k = "special_setup2", v = "tp_grenade_setup"}, {k = "mark_invalid"},
                    {k = "up_vel", v = 1000}, {k = "up_min", v = 1}, {k = "up_max", v = 4}},
               SENT_random = true, SENT_rarity = 1,   SENT_quality = 0,
               SWEP_random = true, SWEP_rarity = 0.6, SWEP_quality = 3,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Pulsing, smell = GiftSmell.Strange, feel = GiftFeel.Otherworldly},

    turret  = {name = "Turret", desc = "a next-gen turret",
               SENT_category = GiftCategory.NPC,
               SENT_id = "npc_turret_floor", SWEP_id = "weapon_ttt_turret",
               SENT_setup_var = {{k = "ambush_giftee"}},
               SENT_random = true, SENT_rarity = 4, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Max, SWEP_size = GiftSize.Small,
               sound = GiftSound.Beeping, smell = GiftSmell.Sterile, feel = GiftFeel.Moving},

    visualizer = {name = "Visualizer", desc = "a high-tech crime visualizer",
               SENT_id = "ttt_cse_proj", SWEP_id = "weapon_ttt_cse",
               SENT_setup_var = {k = "set_thrower"},
               SWEP_setup_var = {k = "worldmodel_fix"},
               SENT_random = true, SENT_rarity = 1, SENT_quality = -2,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whirring, smell = GiftSmell.Sterile, feel = GiftFeel.Bright},

    wormhole_vent = {name = "Wormhole-Vent", desc = "a suspicious grate",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ttt_wormhole", SWEP_id = "ttt_wormholecaller",
               SENT_setup_var = {{k = "stick_to_ground"}, {k = "ground_angles", v = Angle(0, 0, 0)}},
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 9, SWEP_quality = 6,
               SENT_size = GiftSize.Big, SWEP_size = GiftSize.Big,
               sound = GiftSound.Metallic, smell = GiftSmell.Dusty, feel = GiftFeel.Sus,
               SWEP_desc = "the gift of venting"},

    zombie_ball = {name = "Zombie Ball", desc = "a pile of rotting flesh",
               SENT_id = "ttt_zombieball_proj", SWEP_id = "weapon_ttt_zombieball",
               SENT_random = false, --SENT_rarity = 6, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Talking, smell = GiftSmell.Rotten, feel = GiftFeel.Round,
               SWEP_desc = "a necromancy kit"},

}

for label, data in pairs(deployableSWEPs) do
    -- add SENT entry
    local SENTCategory = data.SENT_category or GiftCategory.SENT
    local SENTName     = data.SENT_name or "Live "..data.name
    local SENTDesc     = data.SENT_desc or data.desc

    UpdateCatalog(label, GiftData.New {
        name     = SENTName,     desc       = SENTDesc,
        category = SENTCategory, identifier = data.SENT_id,
        can_be_random_gift = data.SENT_random,
        factor_rarity  = data.SENT_random and data.SENT_rarity or nil,
        factor_quality = data.SENT_random and data.SENT_quality or nil,
        attrib_sound = data.sound, attrib_size = data.SENT_size or GiftSize.Larger,
        attrib_smell = data.smell, attrib_feel = data.feel,
        special_setup = data.SENT_setup
    })
    if data.SENT_setup_var then
        if #data.SENT_setup_var == 0 then
            data.SENT_setup_var = {data.SENT_setup_var}
        end

        for _, pair in pairs(data.SENT_setup_var) do
            giftDataCatalog[label][pair.k] = pair.v or true
        end
    end

    -- add SWEP entry
    local SWEPCategory = data.SWEP_category or GiftCategory.WorldSWEP
    local SWEPName     = data.SWEP_name or data.name
    local SWEPDesc     = data.SWEP_desc or data.desc
    local SWEPSound    = data.SWEP_sound or data.sound
    local SWEPSmell    = data.SWEP_smell or data.smell
    local SWEPFeel     = data.SWEP_feel or data.feel

    UpdateCatalog(label.."_item", GiftData.New {
        name     = SWEPName,      desc       = SWEPDesc,
        category = SWEPCategory,  identifier = data.SWEP_id,
        can_be_random_gift = data.SWEP_random,
        factor_rarity  = data.SWEP_random and data.SWEP_rarity or nil,
        factor_quality = data.SWEP_random and data.SWEP_quality or nil,
        attrib_sound = SWEPSound, attrib_size = data.SWEP_size or GiftSize.Small,
        attrib_smell = SWEPSmell,  attrib_feel = SWEPFeel,
        special_setup = data.SWEP_setup
    })
    if data.SWEP_setup_var then
        if #data.SWEP_setup_var == 0 then
            data.SWEP_setup_var = {data.SWEP_setup_var}
        end

        for _, pair in pairs(data.SWEP_setup_var) do
            giftDataCatalog[label.."_item"][pair.k] = pair.v or true
        end
    end
    --TODO: there's a few catalog entries that could be using this sytem instead!
end

-- to populate the list with resistances
local resistances = {
    drowning  = {type = "Drowning",  smell = GiftSmell.Salty,     rarity = 3, quality = 3},
    energy    = {type = "Energy",    sound = GiftSound.Whirring,  rarity = 1, quality = -3},
    explosion = {type = "Explosion", smell = GiftSmell.Gunpowder, rarity = 7, quality = 8},
    fall      = {type = "Fall",      sound = GiftSound.Whooshing, rarity = 6, quality = 7},
    fire      = {type = "Fire",      smell = GiftSmell.Ash,       rarity = 6, quality = 7},
    hazard    = {type = "Hazard",    smell = GiftSmell.Toxic,     rarity = 1, quality = -3},
    prop      = {type = "Prop",      sound = GiftSound.Thudding,  rarity = 2, quality = 3},
}

for label, data in pairs(resistances) do
    UpdateCatalog("no_"..label.."_dmg", GiftData.New {
        name = "No "..data.type.." Damage", desc = "a resistance",
        category = GiftCategory.Item,       identifier = "item_ttt_no"..label.."dmg",
        can_be_random_gift = true,
        factor_rarity = data.rarity, factor_quality = data.quality,
        attrib_sound = data.sound, attrib_size = GiftSize.Small,
        attrib_smell = data.smell, attrib_feel = GiftFeel.Negative,
    })
end

-- to populate the list with perks
local perks = {
    juggernog = {name="Juggernog",           adj="an invigorating", random=true,  rarity = 6, quality = 9, smell = GiftSmell.Food},
    phd       = {name="PHD Flopper",         adj="an explosive",    random=false, smell = GiftSmell.Gunpowder},
    doubletap = {name="Doubletap Root Beer", adj="a sweet-tasting", random=false, smell = GiftSmell.Sugary},
    speedcola = {name="Speed Cola",          adj="a carbonated",    random=true,  rarity = 6, quality = 9, smell = GiftSmell.Fizzy},
    staminup  = {name="Stamin-Up",           adj="a caffeinated",   random=true,  rarity = 5, quality = 8, smell = GiftSmell.Caffeine},
}

for label, data in pairs(perks) do
    UpdateCatalog(label, GiftData.New {
        name     = data.name,         desc       = data.adj.." cold one",
        category = GiftCategory.Item, identifier = "item_ttt_"..label,
        can_be_random_gift = data.random,
        factor_rarity = data.rarity, factor_quality = data.quality,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Normal,
        attrib_smell = data.smell,          attrib_feel = GiftFeel.Cold,
        special_setup = "perk_bottle"
    })
end

-- to populate the list with ammo boxes
local ammoBoxes = {
    ammo_357      = {name="Rifle"},
    ammo_pistol   = {name="Pistol", size = GiftSize.Large},
    ammo_revolver = {name="Deagle"},
    ammo_smg1     = {name="SMG",    size = GiftSize.Larger},
    box_buckshot  = {name="Shotgun"},
}

for label, data in pairs(ammoBoxes) do
    UpdateCatalog(label, GiftData.New {
        name     = data.name.." Ammo", desc       = "an ammo box",
        category = GiftCategory.Ammo,  identifier = "item_"..label.."_ttt",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic,  attrib_size = data.size or GiftSize.Normal,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Box
    })
end

---------------------------------------------------------------------
---------------------------------------------------------------------
---------------------------------------------------------------------





local qualifiers = {"a bit", "", "a little", "slightly", "", "kinda", "", "quite", "vaguely", ""}
local noSmell = {"It doesn't really have a smell...", "It doesn't smell like anything..."}
local noSound = {"It doesn't make a distinct sound...", "It sounds generic...", "You can't make out a clear sound..."}
local noFeel =  {"Doesn't have a distinct feel to it...", "It feels pretty normal...", "Just holding it doesn't tell you much...", "It feels... indescribable."}

function GiftData:Inspect(giftObj)
    if not self.lastQualifierID then
        self.lastQualifierID = math.random(#qualifiers)
    end
    self.lastQualifierID = self.lastQualifierID % #qualifiers + 1

    local qualifier = qualifiers[self.lastQualifierID]
    if qualifier ~= "" then qualifier = qualifier .. " " end

    if not self.lastCheckType then
        self.lastCheckType = math.random(0, 2)
    end
    self.lastCheckType = (self.lastCheckType + 1) % 3

    if self.lastCheckType == 0 then -- sound
        local sound = self:GetSound(giftObj)

        if sound then
            return "It sounds "..qualifier, sound.desc, "..."
        else
            return noSound[math.random(#noSound)], "", ""
        end

    elseif self.lastCheckType == 1 then -- smell
        local smell = self:GetSmell(giftObj)

        if smell then
            return "It smells "..qualifier, smell, "..."
        else
            return noSmell[math.random(#noSmell)], "", ""
        end

    else -- feel
        local feel = self.attrib_feel
        if IsValid(giftObj) and giftObj:GetIsContentsOnFire() then
            feel = GiftFeel.Hot
        end

        if feel then
            return "It feels "..qualifier, feel, "..."
        else
            return noFeel[math.random(#noFeel)], "", ""
        end
    end
end

function GiftData:GetIdentifier(giftObj)
    if self.identifiers then
        local chosenID = IsValid(giftObj) and giftObj:GetNW2Int("chosen_id") or 0

        if chosenID > 0 then
            return self.identifiers[chosenID]
        else
            return self.identifiers[math.random(#self.identifiers)]
        end
    else
        return self.identifier
    end
end

function GiftData:IsSpawnable(giftee, giftObj)
    if self.available_on_map then
        return string.StartsWith(game.GetMap(), self.available_on_map)

    elseif self.special_setup then
        if self.special_setup == "snuffles_present_setup"
          and utils.RoundStartTime and CurTime() <= utils.RoundStartTime + 10 then
            return false

        elseif self.special_setup == "pap_setup" then
            -- player must have non-PaP crowbar or holstered
            local foundUpgradeable = false

            for _, wep in ipairs(giftee:GetWeapons()) do
                if IsValid(wep) and not wep.PAPUpgrade and wep:GetClass() == "weapon_zm_improvised"
                  or wep:GetClass() == "weapon_ttt_unarmed" then
                    foundUpgradeable = true
                    break
                end
            end

            if not foundUpgradeable then return false end

        elseif self.special_setup == "fart_grenade_setup" then
            return weapons.GetStored("weapon_fartgrenade") ~= nil
        end
    end

    local category   = self.category
    local identifier = self:GetIdentifier(giftObj)

    if category == GiftCategory.PhysProp or category == GiftCategory.Vehicle
      or category == GiftCategory.Ragdoll then
        return util.IsValidModel(identifier)

    elseif category == GiftCategory.SENT or category == GiftCategory.Ammo then
        return scripted_ents.GetStored(identifier) ~= nil

    elseif category == GiftCategory.NPC then
        return list.Get("NPC")[identifier] ~= nil

    elseif category == GiftCategory.WorldSWEP
      or category == GiftCategory.FloorSWEP then
        return weapons.GetStored(identifier) ~= nil

    elseif category == GiftCategory.AutoEquipSWEP then
        return weapons.GetStored(identifier) ~= nil
          and not giftee:HasWeapon(identifier)
          and giftee:CanCarryType(WEPS.TypeForWeapon(identifier))

    elseif category == GiftCategory.Item then
        return items.GetStored(identifier) ~= nil
          and (self.can_get_multiple or not giftee:HasEquipmentItem(identifier))
    end

    return false
end

function GiftData:IsDropBlocked()
    return self.category == GiftCategory.SENT
      or self.category == GiftCategory.NPC
      or self.category == GiftCategory.Vehicle
      or self.category == GiftCategory.Ragdoll
      or self.category == GiftCategory.Unknown
end

function GiftData:ApplyOnWrapAdjustments(wrappedEnt, giftObj)
    if self.break_constraints then
        constraint.RemoveAll(wrappedEnt)
    end

    if self.mark_invalid then
        wrappedEnt._Invalid = true
    end

    if self.category == GiftCategory.Ragdoll then
        local isValidBody = CORPSE.IsValidBody(wrappedEnt)

        if isValidBody then
            -- AFAIK this can only be retrieved server-side if
            -- the player disconnects, so we cache it here
            wrappedEnt:SetNWString("GWStoredTeam", roles.GetByIndex(CORPSE.GetPlayerRole(wrappedEnt)).name:gsub("^%l", string.upper))
            wrappedEnt:SetNWString("GWStoredSID", CORPSE.GetPlayerSID64(wrappedEnt))

            -- handling to cancel out cannibalism
            if wrappedEnt.BeingEaten then
                local cannibal = wrappedEnt.Cannibal

                timer.Remove("CannibalismHeal_"..wrappedEnt:EntIndex())
                timer.Remove("CannibalismEnd_"..wrappedEnt:EntIndex())
                cannibal:Freeze(false)
                cannibal:SetColor(Color(255, 255, 255, 255))
                cannibal:ChatPrint("Your meal was cut short by Gift Wrap.")
            end
        end

        -- Start up stink sequence
        if (not self.disable_flies or isValidBody) and CORPSE_STINK_ENABLE:GetBool() then
            timer.Create("GWCorpseStink"..wrappedEnt:EntIndex(), CORPSE_STINK_DELAY:GetFloat(), 1, function()
                if IsValid(wrappedEnt) then
                    utils.StartStink(wrappedEnt:GetNWEntity("WrappedByGift"))
                end
            end)
        end
    end

    if self.special_setup then
        if self.special_setup == "grenade" and wrappedEnt.SetExplodeTime then
            wrappedEnt.storedExplodeTime = wrappedEnt:GetExplodeTime() - CurTime()
            wrappedEnt:SetExplodeTime(CurTime() + 1e9)

        elseif self.special_setup == "grenade_auto" and wrappedEnt.Explode then
            wrappedEnt.storedExplode = wrappedEnt.Explode
            wrappedEnt.Explode = function(s) end

        elseif self.special_setup == "bunger_setup" then
            local bungerChild = utils.GetEntChildAt(wrappedEnt, 1)

            if IsValid(bungerChild) then
                bungerChild:SetNoDraw(true)
            end

        elseif self.special_setup == "timed_molotov_setup" then
            local curTime = CurTime()
            local minFuse = self.explosion_delay or 2.5

            wrappedEnt.storedFuse = math.max(minFuse, 5 - (curTime - wrappedEnt.SpawnTime))
            wrappedEnt.SpawnTime = curTime + 1e9

            local trail = utils.GetEntChildAt(wrappedEnt, 1)
            if IsValid(trail) then
                trail:Remove()
            end

        elseif self.special_setup == "moon_grenade_setup" then
            timer.Remove(wrappedEnt.FuseID)

        elseif self.special_setup == "manhack_setup" then
            wrappedEnt:StopControlling()

        elseif self.special_setup == "green_demon_setup" then
            if wrappedEnt.Solidified then
                wrappedEnt.LoopSound:Stop()
            else
                wrappedEnt.ActivateTime = CurTime() + 1e9
            end

        elseif self.special_setup == "seekgull_setup" then
            wrappedEnt.SecondsPerTick = 1e9

        elseif self.special_setup == "starburst_ent_setup" then
            wrappedEnt:NextThink(CurTime() + 1e9)
            timer.Remove("killPlasmaBurster2AfterTime")

        elseif self.special_setup == "barnacle_setup" then
            wrappedEnt:Fire("LetGo")
            local enemy = wrappedEnt:GetInternalVariable("m_hEnemy")

            if IsValid(enemy) and enemy:IsPlayer() and enemy:Alive() then
                enemy:RemoveEFlags(EFL_IS_BEING_LIFTED_BY_BARNACLE)
            end

        elseif self.special_setup == "force_shield_setup" then
            wrappedEnt:StopSound("ambient/machines/combine_shield_touch_loop1.wav")

        elseif self.special_setup == "icegrenade_setup" then
            local timerID = wrappedEnt:EntIndex().."_timer"
            wrappedEnt._storedTime = timer.TimeLeft(timerID) + 0.5
            timer.Remove(timerID)

        elseif self.special_setup == "flame_setup" then
            wrappedEnt:SetDieTime(CurTime() + 1e9)

        elseif self.special_setup == "fireball_setup" then
            wrappedEnt._StoredCallback = wrappedEnt:GetCallbacks("PhysicsCollide")[1]
            wrappedEnt:RemoveCallback("PhysicsCollide", 1)
            timer.Pause("FireBallLife"..wrappedEnt.Time)

        elseif self.special_setup == "fart_grenade_setup" then
            if timer.Exists("fartsmoke_"..wrappedEnt:EntIndex()) then
                timer.Pause("fartsmoke_"..wrappedEnt:EntIndex())
                wrappedEnt._FartingStarted = true

            else
                timer.Simple(2, function()
                    if IsValid(wrappedEnt) and timer.Exists("fartsmoke_"..wrappedEnt:EntIndex()) then
                        timer.Pause("fartsmoke_"..wrappedEnt:EntIndex())
                    end
                end)
            end

        elseif self.special_setup == "conc_mine_setup" then
            if wrappedEnt.setoff then
                wrappedEnt:NextThink(CurTime() + 1e9)
            end

        elseif self.special_setup == "cannonball_setup" then
            wrappedEnt.Stuck = true

        elseif self.special_setup == "c4_setup" then
            wrappedEnt:SetDetonateTimer(wrappedEnt:GetExplodeTime() - CurTime() + 10)
            wrappedEnt.LastPos = wrappedEnt:GetPos()
            wrappedEnt._OGThink = wrappedEnt.Think
            wrappedEnt._OGExplode = wrappedEnt.Explode

            wrappedEnt.Think = function(self)
                local wrap = utils.GetTopmostWrap(self)
                if IsValid(wrap) then
                    local wrapPos = wrap:GetPos()
                    self:SetPos(wrapPos)
                    self.LastPos = wrapPos
                end

                wrappedEnt._OGThink(self)
            end

            wrappedEnt.Explode = function(self, tr)
                local wrap = utils.GetTopmostWrap(self)
                self:RemoveCallOnRemove(WRAPPED_GIFT_REMOVE)
                wrappedEnt._OGExplode(self, tr)

                if IsValid(wrap) then
                    wrap:Remove()
                end
            end
        end
    end

    if self.special_setup2 then -- this blows but this stuff is getting refactored anyways! (soonTM)
        if self.special_setup2 == "groovitron_setup" then
            if wrappedEnt.Collided then
                wrappedEnt:StopSound(wrappedEnt.MusicName)
                wrappedEnt:StopSound(wrappedEnt.MusicName)

                for _, ent in ipairs(ents.FindInSphere(wrappedEnt._GWStoredPos, 3)) do
                    if ent:GetClass() == "beam_spotlight" then
                        ent:Remove()
                    end
                end
            end

        elseif self.special_setup2 == "tp_grenade_setup" then
            wrappedEnt:NextThink(CurTime() + 1e9)
        end
    end

    if wrappedEnt:IsOnFire() then
        wrappedEnt:Extinguish()
        giftObj:SetIsContentsOnFire(true)
    end
end

function GiftData:ApplyOnAutoWrapAdjustments(giftObj)
    if self.identifiers then
        giftObj:SetNW2Int("chosen_id", math.random(#self.identifiers))
    end

    if self.category == GiftCategory.Ragdoll and not self.disable_flies and CORPSE_STINK_ENABLE:GetBool() then
        utils.StartStink(giftObj)
    end

    if self.special_setup == "explo_barrel_setup" then
        if math.random() < 0.6 then
            giftObj:SetIsContentsOnFire(true)
        end

    elseif self.special_setup == "fortnite_struct_setup" then
        local mat = math.random(0, 2)
        local mode = math.max(math.random(-1, 3), 0) -- bias to wall
        if mode == FORTNITE_FLOOR then mode = 0 end  -- bias to wall + floors on the floor are weird

        local matStr = ({
            [FORTNITE_WOOD]  = "wood",
            [FORTNITE_STONE] = "brick",
            [FORTNITE_METAL] = "metal",
        })[mat]

        local modeStr = ({
            [FORTNITE_WALL]   = "wall",
            [FORTNITE_FLOOR]  = "floor",
            [FORTNITE_STAIRS] = "stairw",
            [FORTNITE_ROOF]   = "roofc",
        })[mode]

        giftObj:SetNW2String("fortnite_model", "models/fortnitea31/buildingparts/pbw/"..matStr .."/"..matStr.."_"..modeStr..".mdl")
        giftObj:SetNW2Int("fortnite_mode", mode)
        giftObj:SetNW2Int("fortnite_mat", mat)

    elseif self.special_setup == "cannonball_setup" then
        giftObj:SetIsContentsOnFire(true)
    end
end

function GiftData:ApplyPreSpawnAdjustments(wrappedEnt, giftee, giftObj)
    if IsValid(wrappedEnt) then
        wrappedEnt:SetNWEntity("GW_Spawner", giftee)
    end

    if self.adjAngle then
        wrappedEnt:SetAngles(self.adjAngle)
    end

    if self.set_owner then
        wrappedEnt:SetOwner(giftee)
        -- alternatives used by various addons
        wrappedEnt.Owner = giftee
        wrappedEnt.owner = giftee
    end

    if self.set_thrower then
        if wrappedEnt.SetThrower then wrappedEnt:SetThrower(giftee) end
        if wrappedEnt.SetOriginator then wrappedEnt:SetOriginator(giftee) end
    end

    -- Vehicle stuff
    if self.vehicle_script then
        wrappedEnt:SetKeyValue("vehiclescript", self.vehicle_script)
    end

    if self.extra_seats then
        for _, seatData in ipairs(self.extra_seats) do
            local seatMeta = giftDataCatalog[seatData.type.."_seat"]
            local seat = seatMeta:Spawn(giftee)

            seat:SetKeyValue("vehiclescript", seatMeta.vehicle_script)
            utils.ExitStasis(seat, wrappedEnt:GetPos() + seatData.pos)

            seat:SetParent(wrappedEnt)
            seat:SetAngles(seatData.angle)
            --seat:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        end
    end

    if self.special_setup then
        if self.special_setup == "barnacle_setup" then
            timer.Simple(1.5, function()
                if IsValid(giftee) and giftee:Alive() then
                    giftee:ChatPrint("NOTE: You CAN shoot it to escape!")
                end
            end)

        elseif self.special_setup == "bouncy_ball_setup" then
            wrappedEnt:SetBallSize(math.random(20,40))

        elseif self.special_setup == "shield_deployer_setup" then
            wrappedEnt.shieldDeployAngleYaw = giftee:GetEyeTrace().Normal:Angle().yaw

        elseif self.special_setup == "fan_setup" then
            wrappedEnt:SetName("ttt_fan")
            wrappedEnt.Owner = giftee -- for some reason set_owner messes with health setup

        elseif self.special_setup == "gift_setup" then
            wrappedEnt:SetIsRandomGift(true)
            wrappedEnt:SetWrapperSID("WORLD")
            RollGiftColors(wrappedEnt)

        elseif self.special_setup == "snuffles_present_setup" then
            local presentModels = {
                "models/katharsmodels/present/type-2/big/present.mdl",
                "models/katharsmodels/present/type-2/big/present2.mdl",
                "models/katharsmodels/present/type-2/big/present3.mdl"
            }

            wrappedEnt.Model = presentModels[math.random(#presentModels)]

        elseif self.special_setup == "bunger_setup" then
            -- copied from bunger addon
            wrappedEnt:SetNPCState(2)
            wrappedEnt:SetNoDraw(true)
            wrappedEnt:SetNWEntity("Thrower", giftee)
            wrappedEnt:SetNWBool("GWFriendlyBunger", true)

            local bunger = ents.Create("prop_dynamic")
            bunger:SetModel("models/betterbunger.mdl")
            bunger:SetPos(wrappedEnt:GetPos())
            bunger:SetAngles(Angle(0,270,0))
            bunger:SetParent(wrappedEnt)
            bunger:SetModelScale(2,0) -- for cute

            local hat = ents.Create("prop_dynamic")
            hat:SetModel("models/ttt/propeller_hat/propeller_hat.mdl")
            hat:SetPos(bunger:GetPos() + Vector(2,0,20.5))
            hat:SetAngles(Angle(0,270,1))
            hat:SetParent(bunger)
            hat:SetModelScale(3.5,0)

            hat:Spawn()
            hat:SetSequence("spin_max")
            hat:ResetSequence("spin_max")

        elseif self.special_setup == "slam_setup" then
            wrappedEnt:SetPlacer(giftee)

        elseif self.special_setup == "moon_grenade_setup" then
            wrappedEnt.GrenadeOwner = giftee

        elseif self.special_setup == "moonball_setup" then
            local skindex = math.random(0, 18) -- awesome var name from the original addon
            wrappedEnt:SetSkin(skindex)
            wrappedEnt:SetMoonballSkin(skindex)
            wrappedEnt:SetNWEntity("MoonballOwner", giftee)

            -- note: colliding with one will create an error, and I believe that error is part of the original addon
            --       (no weapon named "weapon_ttt_moonball" exists to give a player)
            -- TODO look into it more?

        elseif self.special_setup == "pog_setup" then
            wrappedEnt.gift_pot = true

        elseif self.special_setup == "pog_shard_setup" then
            local gifteeRole = giftee:GetSubRole()
            local gifteeRoleData = utils.GetSubRoleData(gifteeRole)

            if not subRoleData or not subRoleData:IsShoppingRole() then
                wrappedEnt.Role = ROLE_DETECTIVE
            else
                wrappedEnt.Role = gifteeRole
            end

        elseif self.special_setup == "pap_setup" then
            local preferredWepName = giftObj:GetClass() == SWEP_CLASS_NAME and "weapon_ttt_unarmed" or "weapon_zm_improvised"
            local preferredWep = giftee:GetWeapon(preferredWepName)

            if IsValid(preferredWep) and not preferredWep.PAPUpgrade then
                giftee:SelectWeapon(preferredWepName)
                giftee._UpgradeGiftWep = preferredWepName
            else
                giftee:SelectWeapon("weapon_zm_improvised")
                giftee._UpgradeGiftWep = "weapon_zm_improvised"
            end
            TTTPAP:OrderPAP(giftee, true)

            -- note: copied from pap's OrderedEquipment hook (i would've called it directly,
            --       but I need to know the old numeric ID EQUIP_PAP which somehow becomes nil over the namespace
            timer.Simple(0.1, function()
                if giftee.RemoveEquipmentItem then
                    giftee:RemoveEquipmentItem(self.identifier)
                else
                    giftee.equipment_items = bit.bxor(giftee.equipment_items, self.identifier)
                    giftee:SendEquipment()
                end
            end)

        elseif self.special_setup == "sopd_setup" then
            wrappedEnt:SetGrabbedFromCorpse(true)

        elseif self.special_setup == "baron_hat_drop" then
            timer.Simple(0, function() wrappedEnt:Drop() end)

        elseif self.special_setup == "perk_bottle" then
            items.GetStored(self.identifier):Bought(giftee)

        elseif self.special_setup == "fart_grenade_setup" then
            local fart_grenade = weapons.GetStored("weapon_fartgrenade")
            fart_grenade:CreateGrenade(Vector(0, 0, 0), Angle(0, 0, 0), Vector(0, 0, 0), Vector(0, 0, 0), giftee)
            return ents.GetAll()[#ents.GetAll()]

        elseif self.special_setup == "fortnite_struct_setup" then
            wrappedEnt:SetModel(giftObj:GetNW2String("fortnite_model", "models/fortnitea31/buildingparts/pbw/wood/wood_wall.mdl"))
            wrappedEnt.Mode     = giftObj:GetNW2Int("fortnite_mode", FORTNITE_WALL)
            wrappedEnt.Material = giftObj:GetNW2Int("fortnite_mat", FORTNITE_WOOD)
            wrappedEnt.Neighbours = {}
        end
    end
end

function GiftData:ApplyPostUnwrapAdjustments(wrappedEnt, giftee, giftObj, isUndo)
    if IsValid(wrappedEnt) then
        wrappedEnt:SetNWEntity("GW_Wrapper", giftee)

        if wrappedEnt._Invalid then
            wrappedEnt._Invalid = false
        end

        if wrappedEnt:GetNW2Bool("GWStinky") then -- particles need refreshing for some reason
            ParticleEffectAttach("flies_fx", PATTACH_ABSORIGIN_FOLLOW, wrappedEnt, 0)
        end
    end

    if self.move_to_giftee then
        local curMoveType = wrappedEnt:GetMoveType()
        wrappedEnt:SetMoveType(MOVETYPE_VPHYSICS)
        wrappedEnt:SetPos(giftee:GetPos())
        wrappedEnt:SetMoveType(curMoveType)
    end

    if self.adjMass then
        local phys = wrappedEnt:GetPhysicsObject()

        if IsValid(phys) then
            phys:SetMass(self.adjMass)
        end
    end

    if self.no_physwake then
        wrappedEnt._DontWake = true
    end

    if self.category == GiftCategory.Ragdoll then
        timer.Remove("GWCorpseStink"..wrappedEnt:EntIndex())
    end

    if self.stick_to_ground and not wrappedEnt:IsOnGround() then
        local groundTr = utils.GetGroundHit(utils.GetEntCenter(wrappedEnt), wrappedEnt)

        if groundTr.Hit then
            wrappedEnt:SetPos(groundTr.HitPos)
            timer.Simple(0, function()
                wrappedEnt:SetAngles(groundTr.HitNormal:Angle() + (self.ground_angles and self.ground_angles or Angle(90, 0, 0)))
                if wrappedEnt.WeldToSurface then wrappedEnt:WeldToSurface(true) end
            end)
            wrappedEnt:SetMoveType(MOVETYPE_NONE)

            local phys = wrappedEnt:GetPhysicsObject()
            if IsValid(phys) then
                phys:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
            end
        end
    end

    if self.ambush_giftee then
        local groundTr = utils.GetGroundHit(utils.GetEntCenter(wrappedEnt), wrappedEnt)

        if groundTr.Hit then
            local ang = groundTr.HitNormal:Angle() + Angle(90, 0, 0)

            local dir = (giftee:GetPos() - wrappedEnt:GetPos()):GetNormalized()
            dir = (dir - groundTr.HitNormal * dir:Dot(groundTr.HitNormal)):GetNormalized()

            local forward = ang:Forward()
            local rot = math.deg(math.atan2(
                forward:Cross(dir):Dot(groundTr.HitNormal),
                forward:Dot(dir)
            ))

            ang:RotateAroundAxis(groundTr.HitNormal, rot + (self.ambush_angle or 0))
            wrappedEnt:SetAngles(ang)
            wrappedEnt:SetPos(groundTr.HitPos + Vector(0, 0, self.ambush_yoff or 0))
        else
            wrappedEnt:SetAngles(Angle(0, ang.y - 90, 0))
        end
    end

    if IsValid(giftObj) and giftObj:GetIsContentsOnFire() then
        wrappedEnt:Ignite(60, 100)
        giftObj:SetIsContentsOnFire(false)

        local wrapper = utils.GetWrapper(giftObj)
        if self.special_setup == "explo_barrel_setup" and wrapper then
            local dmg = DamageInfo()
            dmg:SetDamage(0)
            dmg:SetAttacker(wrapper)
            wrappedEnt:TakeDamageInfo(dmg)
            wrappedEnt:SetHealth(math.min(wrappedEnt:Health() + 6, wrappedEnt:GetMaxHealth()))
        end
    end

    if self.special_setup then
        if self.special_setup == "barnacle_setup" then
            local ang = wrappedEnt:GetAngles()
            local owner = wrappedEnt:GetDamageOwner()
            wrappedEnt:Remove() --tried very hard to properly move it but it's too involved

            local startPos = giftee:GetPos()
            local upTr = util.TraceLine({
                start = startPos,
                endpos = startPos + Vector(0, 0, 10000),
                filter = ply,
                mask = MASK_SOLID_BRUSHONLY
            })

            local newPos = upTr.Hit and upTr.HitPos or startPos + Vector(0, 0, 100)
            local newBarnacleOwner = IsValid(owner) and owner or giftee
            local newBarnacle = ents.Create("npc_barnacle")
            newBarnacle:SetPos(newPos)
            newBarnacle:SetAngles(ang)
            newBarnacle:SetNWEntity("owner", newBarnacleOwner)
            newBarnacle:SetDamageOwner(newBarnacleOwner)
            newBarnacle:SetRenderMode(RENDERMODE_TRANSALPHA)
            newBarnacle:SetColor(Color(0,0,0,30))
            newBarnacle:SetKeyValue("RestDist",50)
            newBarnacle:Spawn()
            newBarnacle:Activate()
            newBarnacle:SetHealth(50)
            newBarnacle:Fire("SetDropTongueSpeed", 100)

            local timerName = newBarnacle:EntIndex().."_timer" --recreate barnacle addon logic
            timer.Create(timerName, 0.1, 0, function()
                if not IsValid(newBarnacle) then
                    timer.Remove(timerName)
                    return
                end

                local enemy = newBarnacle:GetInternalVariable("m_hEnemy")
                if IsValid(enemy) and enemy:IsPlayer() and enemy:Alive() then
                    newBarnacle:SetColor(Color(255, 255, 255, 255))
                    if IsValid(owner) then enemy:SelectWeapon('weapon_ttt_unarmed') end

                elseif not newBarnacle.Health or newBarnacle:Health() <= 0 then
                    newBarnacle:SetColor(Color(255, 255, 255, 255))
                    timer.Remove(timerName)

                else
                    newBarnacle:SetColor(Color(0, 0, 0, 25))
                end
            end)

        elseif self.special_setup == "grenade" then
            local storedExplodeTime = wrappedEnt.storedExplodeTime or 1.5
            local addedTime = self.explosion_delay or 1.5
            wrappedEnt:SetDetonateTimer(storedExplodeTime + addedTime)

            if wrappedEnt.GetThrower and not IsValid(wrappedEnt:GetThrower()) then
                wrappedEnt:SetThrower(giftee)
            end

        elseif self.special_setup == "grenade_auto" and wrappedEnt.storedExplode then
            local fuse = self.explosion_delay or 2
            wrappedEnt.Explode = wrappedEnt.storedExplode

            timer.Simple(fuse, function()
                if IsValid(wrappedEnt) then
                    wrappedEnt:Explode()
                end
            end)

        elseif self.special_setup == "bunger_setup" then
            local bungerChildren = wrappedEnt:GetChildren()
            if #bungerChildren <= 0 then return end
            local bungerChild = bungerChildren[1]

            if IsValid(bungerChild) then
                bungerChild:SetNoDraw(false)
                wrappedEnt:SetNoDraw(true)
            end

            -- npc health must be set after spawning
            if wrappedEnt:GetNWBool("GWFriendlyBunger") then
                wrappedEnt:SetMaxHealth(1200)
                wrappedEnt:SetHealth(1200)
            end

        elseif self.special_setup == "timed_molotov_setup" then
            if wrappedEnt.storedFuse then
                wrappedEnt.SpawnTime = CurTime() - wrappedEnt.storedFuse
            else
                wrappedEnt.SpawnTime = CurTime() - 1 -- 4s fuse
            end

            local trail = utils.GetEntChildAt(wrappedEnt, 1)
            if not IsValid(trail) then
                trail = ents.Create("env_fire_trail")
                trail:SetPos(wrappedEnt:GetPos())
                trail:SetParent(wrappedEnt)
                trail:Spawn()
                trail:Activate()
            end

        elseif self.special_setup == "moon_grenade_setup" then
            timer.Simple(math.max(1.5, wrappedEnt.FuseTime), function()
                wrappedEnt:DoBoom() -- dirty but im lazy rn
            end)

        elseif self.special_setup == "pog_setup" and wrappedEnt.gift_pot then
            wrappedEnt:SetRole(giftee:GetSubRole())
            wrappedEnt.gift_pot = false -- don't redo this on re-wrap

        elseif self.special_setup == "sandwich_setup" then
            giftee:ChatPrint("Grab it while it's still fresh! (5 seconds)")
            timer.Simple(5, function() wrappedEnt:OnDrop() end)

        elseif self.special_setup == "shellmet_setup" then
            -- commented out: making the shellmet spawn auto-equipped
            --if giftee:HasEquipmentItem("item_ttt2_shellmet") then
                -- lifted from addon
                wrappedEnt:SetBeingWorn(false)
                wrappedEnt:SetUseType(SIMPLE_USE)
                wrappedEnt:PhysicsInit(SOLID_VPHYSICS)
                wrappedEnt:SetSolid(SOLID_VPHYSICS)
                wrappedEnt:SetMoveType(MOVETYPE_VPHYSICS)

            --else
            --    wrappedEnt:WearHat(giftee)
            --end

        elseif self.special_setup == "amaterasu_setup" then
            giftee:SetNWBool("TTTAmaterasu", true)
            SetGlobalBool("TTTAmaterasuBought", true)

        elseif self.special_setup == "auto_use" and not isUndo then
            wrappedEnt:Use(giftee)

        elseif self.special_setup == "auto_drive" and not isUndo then
            giftee:EnterVehicle(wrappedEnt)

            timer.Simple(1.5, function()
                if giftee:InVehicle() then
                    utils.NonSpamMessage(giftee, "AutoDriveHint", "Hint: Press the use key to exit the vehicle.")
                end
            end)

        elseif self.special_setup == "fan_setup" then
            local health = wrappedEnt:GetNWInt("health")
            if not health or health == 0 then --newly spawned
                wrappedEnt:SetNWInt("health", TTT_FAN.CVARS.fan_health)
            end

        elseif self.special_setup == "green_demon_setup" then
            local wakeUpTime = GetConVar("sv_ttt2_greendemon_spawn_delay"):GetFloat()

            if wrappedEnt.Solidified then
                wrappedEnt.Solidified = false
                wakeUpTime = wakeUpTime / 2
            end

            wrappedEnt:EmitSound(wrappedEnt.SpawnSound)
            wrappedEnt.ActivateTime = CurTime() + wakeUpTime

        elseif self.special_setup == "seekgull_setup" then
            wrappedEnt.SecondsPerTick = 0.01
            wrappedEnt:NextThink(CurTime())

        elseif self.special_setup == "paper_plane_setup" then
            local phys = wrappedEnt:GetPhysicsObject()

            -- otherwise it'll zoom at mach speed towards its target
            if IsValid(phys) then
                phys:SetMass(200)
            end

        elseif self.special_setup == "starburst_ent_setup" then
            wrappedEnt.Trail = util.SpriteTrail(wrappedEnt, 0, Color(255, 100, 0), false, 32, 1, 0.3, 0.01, "trails/plasma.vmt")
            wrappedEnt.charges = GetConVar("ttt_plasmaburster_bounces"):GetInt()
            wrappedEnt:NextThink(CurTime() + 0.1)
            local phys = wrappedEnt:GetPhysicsObject()

            timer.Simple(0.3, function()
                if phys:IsValid() then
                    local aim = giftee:GetAimVector()
                    phys:SetVelocity((aim + VectorRand() * 0.1):GetNormalized() * 1500)
                    phys:Wake()
                end
            end)

        elseif self.special_setup == "force_shield_setup" then
            wrappedEnt:EmitSound("ambient/machines/combine_shield_touch_loop1.wav", 55)

        elseif self.special_setup == "harpoon_setup" then
            wrappedEnt:Initialize()
            local phys = wrappedEnt:GetPhysicsObject()
            local aim = giftee:GetAimVector()
            wrappedEnt:SetAngles(aim:Angle())

            local isParry = not wrappedEnt.dt.Collided and not IsValid(wrappedEnt:GetNWEntity("GW_Spawner"))
            local targetPos = giftee:EyePos() + Vector(aim.x, aim.y, 0):GetNormalized() * 150

            if phys:IsValid() then
                phys:Sleep()
                phys:SetPos(targetPos)

                timer.Simple(isParry and 0.1 or 0.8, function()
                    if IsValid(phys) then
                        local rngMult = isParry and 0 or 0.3
                        phys:SetVelocity((aim + utils.GetRandomUpwardsVel(0) * rngMult):GetNormalized() * 1000)
                        phys:Wake()
                    end
                end)
            end

        elseif self.special_setup == "icegrenade_setup" then
            wrappedEnt:iceexplode(wrappedEnt._storedTime)

        elseif self.special_setup == "flame_setup" then
            wrappedEnt:SetDieTime(CurTime() + 30)

        elseif self.special_setup == "fireball_setup" then
            local phys = wrappedEnt:GetPhysicsObject()

            timer.Simple(0, function()
                if phys:IsValid() then
                    local aim = giftee:GetAimVector()
                    phys:SetVelocity((aim + utils.GetRandomUpwardsVel(0) * 0.3):GetNormalized() * 1000)
                    phys:ApplyForceCenter(aim * GetConVar("ttt_fire_magic_speed"):GetInt())
                end
            end)

            wrappedEnt:AddCallback("PhysicsCollide", wrappedEnt._StoredCallback)
            timer.UnPause("FireBallLife"..wrappedEnt.Time)

        elseif self.special_setup == "fart_grenade_setup" then
            local delay = wrappedEnt._FartingStarted and 1.2 or 2.5
            dbg.Log("Resuming fart in", delay)

            timer.Simple(delay, function()
                if timer.Exists("fartsmoke_"..wrappedEnt:EntIndex()) then
                    timer.UnPause("fartsmoke_"..wrappedEnt:EntIndex())

                    ParticleEffect("fartsmoke", wrappedEnt:GetPos() + Vector(-80, -40, 0), Angle(0, 0, 0), nil)
                    wrappedEnt:EmitSound(Sound("fart_1.wav"))
                end
            end)

        elseif self.special_setup == "fortnite_struct_setup" then
            local model = IsValid(wrappedEnt) and wrappedEnt:GetModel() or giftEnt:GetNW2String("fortnite_model")
            local pushDist = string.EndsWith(model, "wall.mdl") and 150 or 300

            local aim = giftee:GetAimVector()
            local targetPos = giftee:EyePos() + Vector(aim.x, aim.y, 0):GetNormalized() * pushDist

            local yaw = (giftee:GetPos() - targetPos):Angle().y
            wrappedEnt:SetAngles(Angle(0, yaw, 0))

            local groundTr = utils.GetGroundHit(targetPos, wrappedEnt)
            if groundTr.Hit and groundTr.HitPos:Distance(targetPos) <= 150 then
                wrappedEnt:SetPos(groundTr.HitPos)

            else
                local yAdj = string.EndsWith(model, "wall.mdl") and 75 or 50
                wrappedEnt:SetPos(targetPos - Vector(0, 0, yAdj))
            end

        elseif self.special_setup == "conc_mine_setup" then
            if wrappedEnt.setoff then
                wrappedEnt:StartFuse()
                wrappedEnt:NextThink(CurTime() + 0.1)
            end

        elseif self.special_setup == "cannonball_setup" then
            local phys = wrappedEnt:GetPhysicsObject()
            wrappedEnt.StartPos = giftee:GetPos() + Vector(0, 0, 10000) -- ensure explosion
            wrappedEnt.Stuck = false

            timer.Simple(0, function()
                if phys:IsValid() then
                    local aim = giftee:GetAimVector()
                    phys:SetVelocity((aim + utils.GetRandomUpwardsVel(0) * 0.1):GetNormalized() * 1000)
                    phys:AddAngleVelocity(Vector(0, 2500, 0))
                end
            end)

        elseif self.special_setup == "c4_setup" then
            wrappedEnt.LastPos = wrappedEnt:GetPos()
            wrappedEnt.Think = wrappedEnt._OGThink
            wrappedEnt.Explode = wrappedEnt._OGExplode
        end
    end

    if self.special_setup2 then
        if self.special_setup2 == "tp_grenade_setup" then
            wrappedEnt:NextThink(CurTime())
        end
    end

    if self.up_vel then
        local upMin = self.up_min or 10
        local upMax = self.up_max or upMin
        local upAmt = math.Rand(upMin, upMax)
        local vel   = utils.GetRandomUpwardsVel(upAmt) * self.up_vel

        local phys = wrappedEnt:GetPhysicsObject()
        phys:SetVelocity(vel)
        wrappedEnt:SetAngles(vel:Angle())

        local angle_vel = self.up_angvel or -500
        phys:AddAngleVelocity(Vector(0, angle_vel, 0))
    end
end

function GiftData:ApplyPostGiftPurchaseAdjustments(giftee)
    if self.special_setup then
        if self.special_setup == "amaterasu_setup" then
            giftee:SetNWBool("TTTAmaterasu", false)

        elseif self.special_setup == "baron_hat_setup" then
            giftee.baron_hat:Remove()
            giftee.baron_hat = nil
            giftee:RemoveEquipmentItem("item_ttt2_baron_hat")
        end
    end
end

function GiftData:GetName(giftEnt, giftee)
    local wrappedEnt = giftEnt:GetStoredGift()

    if IsValid(wrappedEnt) and self.category == GiftCategory.Ragdoll then
        local storedTeam = wrappedEnt:GetNWString("GWStoredTeam")

        if storedTeam ~= "" and (CORPSE.GetFound(wrappedEnt) or utils.IsOmniscient(giftee)) then
            return "Dead "..storedTeam
        end
    end

    if self.special_setup == "poison_station_desc" then
        if PS2_Utils and PS2_Utils.IsMainEvil(giftee) then
            return "Live Poison Station"
        else
            return "Live Health Station"
        end
    end

    return self.name
end

function GiftData:GetDesc(giftEnt, giftee, forOthers)
    local wrappedEnt = giftEnt:GetStoredGift()

    if IsValid(wrappedEnt) and self.category == GiftCategory.Ragdoll and CORPSE.IsValidBody(wrappedEnt) then
        if CORPSE.GetFound(wrappedEnt) or (utils.IsOmniscient(giftee) and not forOthers) then
            if CORPSE.GetPlayer(wrappedEnt) == giftee then -- death faker
                return (forOthers and "their" or "your").." own body"
            else
                return CORPSE.GetPlayerNick(wrappedEnt).."'s body"
            end
        else
            return "an unidentified body"
        end
    end

    if self.special_setup then
        if self.special_setup == "giftwrap_desc" then
            if wrappedEnt.HasGift and wrappedEnt:HasGift() then
                return "another gift"
            else
                return "more wrapping paper"
            end

        elseif self.special_setup == "sopd_setup" then
            if giftee:SteamID64() == swordTarget.SID64 then
                return "a sword meant just for "..(forOthers and "them" or "you")
            elseif swordTarget.name and swordTarget.name ~= "" then
                if IsPlayer(swordTarget.player) 
                  and not utils.IsLivingPlayer(swordTarget.player) then
                    return "a posthumous gift for "..swordTarget.name
                else
                    return "a gift for "..swordTarget.name
                end
            else
                return "a highly-targeted gift"
            end

        elseif self.special_setup == "bunger_setup" then
            if not IsValid(wrappedEnt) or wrappedEnt:GetNWBool("GWFriendlyBunger") then
                return "a pet Bunger"
            else
                return "an angry Bunger"
            end

        elseif self.special_setup == "poison_station_desc" then
            if PS2_Utils and PS2_Utils.IsMainEvil(giftee) then
                return "a poisonous microwave"
            else
                return "a healing microwave"
            end

        elseif self.special_setup == "pap_setup" and giftee._UpgradeGiftWep then
            if giftee._UpgradeGiftWep == "weapon_zm_improvised" then
                return "a fresh coat of paint for "..(forOthers and "their" or "your").." crowbar"
            elseif giftee._UpgradeGiftWep == "weapon_ttt_unarmed" then
                return "yellow bodypaint"
            end

        elseif self.special_setup == "fortnite_struct_setup" then
            local model = IsValid(wrappedEnt) and wrappedEnt:GetModel() or giftEnt:GetNW2String("fortnite_model")

            if string.EndsWith(model, "wall.mdl") then
                return "a wall"
            elseif string.EndsWith(model, "floor.mdl") then
                return "a floor"
            elseif string.EndsWith(model, "stairw.mdl") then
                return "a staircase"
            elseif string.EndsWith(model, "roofc.mdl") then
                return "a roof"
            end
        end
    end

    return forOthers and self.desc:gsub("lets you", "lets them"):gsub("your", "their"):gsub("you", "they")
                      or self.desc
end

function GiftData:GetSound(giftEnt)
    if self.category == GiftCategory.Ragdoll then
        local wrappedEnt = giftEnt:GetStoredGift()

        if CORPSE.IsValidBody(wrappedEnt) then
            -- player-dependent easter eggs
            local deadPlyNick = CORPSE.GetPlayerNick(wrappedEnt)
            local deadPlyID = wrappedEnt:GetNWString("GWStoredSID")

            if string.find(deadPlyNick, "cow", nil, true) then
                return GiftSound.Mooing

            elseif string.find(deadPlyNick, "cat", nil, true) or
              deadPlyID == "76561197999258534" or -- Max
              deadPlyID == "76561198068281034" then --EvKem
                return GiftSound.Meowing

            elseif string.find(deadPlyNick, "sheep", nil, true) then
                return GiftSound.Bleating
            end
        end
    end

    return self.attrib_sound
end

function GiftData:GetSmell(giftEnt)
    if self.special_setup == "fortnite_struct_setup" then
        local wrappedEnt = giftEnt:GetStoredGift()
        local model = IsValid(wrappedEnt) and wrappedEnt:GetModel() or giftEnt:GetNW2String("fortnite_model")

        if string.StartsWith(model, "models/fortnitea31/buildingparts/pbw/wood") then
            return GiftSmell.Woody
        elseif string.StartsWith(model, "models/fortnitea31/buildingparts/pbw/brick") then
            return GiftSmell.Earthy
        elseif string.StartsWith(model, "models/fortnitea31/buildingparts/pbw/metal") then
            return GiftSmell.Metallic
        else
            return GiftSmell.Nondescript
        end
    end

    return self.attrib_smell
end

function GiftData:Spawn(giftee, giftObj)
    if self:IsSpawnable(giftee, giftObj) then
        local category   = self.category
        local identifier = self:GetIdentifier(giftObj)
        local isRagdoll  = category == GiftCategory.Ragdoll

        -- PhysProp / Vehicle
        if category == GiftCategory.PhysProp or category == GiftCategory.Vehicle or isRagdoll then
            local giftClass = isRagdoll and "prop_ragdoll" or "prop_physics"
            local giftEnt = ents.Create(self.entity_class or giftClass)
            if identifier ~= INVALID_ID then
                giftEnt:SetModel(identifier)
            end

            self:ApplyPreSpawnAdjustments(giftEnt, giftee, giftObj)
            giftEnt:Spawn()

            local phys = giftEnt:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
                phys:Sleep()
            end

            if isRagdoll then
                utils.PrepareRagdoll(giftEnt)
            end

            return giftEnt

        -- SENT / NPC / FloorSWEP / WorldSWEP / Ammo
        elseif category == GiftCategory.SENT or category == GiftCategory.NPC or category == GiftCategory.Ammo
          or category == GiftCategory.WorldSWEP or category == GiftCategory.FloorSWEP then
            local giftEnt = ents.Create(identifier)
            local ret = self:ApplyPreSpawnAdjustments(giftEnt, giftee, giftObj)

            if ret ~= nil then -- only in fringe cases like Fart Grenade
                if IsValid(giftEnt) then giftEnt:Remove() end
                giftEnt = ret
            end

            giftEnt:Spawn()
            return giftEnt

        elseif category == GiftCategory.AutoEquipSWEP then -- AutoEquipSWEP
            giftee:Give(identifier)
            giftee:SelectWeapon(identifier)

        elseif category == GiftCategory.Item then -- Item
            self:ApplyPreSpawnAdjustments(nil, giftee, giftObj)
            giftee:GiveEquipmentItem(identifier)
        end

        return nil
    end

    return false
end


-- cf. formulas sheet (link in GitHub readme)
function CalcQualityFactors(dayOfYear, score)
    if not dayOfYear then dayOfYear = tonumber(os.date("%j")) end

    local xmasDist = math.min(math.abs(XMAS_DAY - dayOfYear), 365 - math.abs(XMAS_DAY - dayOfYear))
    xmasFactor = math.max(0, XMAS_START - (xmasDist/XMAS_DIVISOR)) ^ XMAS_EXP - XMAS_SUB

    if not score then score = 0 end
    local r = (score + SCORE_INTERCEPT) / SCORE_PARA_MAX
    local scoreFactor = r * math.abs(r)

    dbg.Log("Calculated quality factors:")
    dbg.Log("Day", dayOfYear, "->", xmasFactor, "| Score", score, "->", scoreFactor)
    return xmasFactor, scoreFactor
end

-- cf. formulas sheet (link in GitHub readme)
function GiftData:CalcWeight(xmasFactor, scoreFactor, isBoosted)
    if not self.can_be_random_gift then return 0 end
    if not xmasFactor then xmasFactor = -XMAS_SUB end
    if not scoreFactor then scoreFactor = 0 end

    local categoryMult = GetConVar(self.category.weight):GetFloat()
    if self.category == GiftCategory.FloorSWEP and isBoosted then
        categoryMult = 0
    end

    local scaledQuality = self.factor_quality / QUALITY_MAX
    local qualityFactor = ((scaledQuality * scoreFactor) + (math.abs(scaledQuality) * xmasFactor) + 1) / 2

    return math.max(0, categoryMult * (qualityFactor / self.factor_rarity))
end

function GetTotalWeight(xmasFactor, scoreFactor, isBoosted)
    if not xmasFactor or not scoreFactor then
        xmasFactor, scoreFactor = CalcQualityFactors()
    end

    local total = 0
    local count = 0

    for label, giftData in pairs(giftDataCatalog) do
        total = total + giftData:CalcWeight(xmasFactor, scoreFactor, isBoosted)
        count = count + 1
    end

    return total, count
end

function GetPerGiftWeightBreakdown(xmasFactor, scoreFactor, isBoosted)
    if not xmasFactor or not scoreFactor then
        xmasFactor, scoreFactor = CalcQualityFactors()
    end

    local breakdown = {}

    for label, giftData in pairs(giftDataCatalog) do
        breakdown[label.."_spawnable"] = giftData:IsSpawnable(LocalPlayer and LocalPlayer() or player.GetAll()[1])
        breakdown[label.."_weight"]    = giftData:CalcWeight(xmasFactor, scoreFactor, isBoosted)
    end

    return breakdown
end

function GetCategoryWeightBreakdown(xmasFactor, scoreFactor, isBoosted)
    if not xmasFactor or not scoreFactor then
        xmasFactor, scoreFactor = CalcQualityFactors()
    end

    local breakdown = {}
    breakdown.propCnt    = 0
    breakdown.propWeight = 0
    breakdown.shopCnt    = 0
    breakdown.shopWeight = 0
    breakdown.floorCnt    = 0
    breakdown.floorWeight = 0
    breakdown.SENTCnt    = 0
    breakdown.SENTWeight = 0

    for label, giftData in pairs(giftDataCatalog) do
        if giftData.can_be_random_gift then
            local categoryWeight = giftData.category.weight
            local giftWeight = giftData:CalcWeight(xmasFactor, scoreFactor, isBoosted)

            if categoryWeight == PROP_WEIGHT_NAME then
                breakdown.propCnt = breakdown.propCnt + 1
                breakdown.propWeight = breakdown.propWeight + giftWeight

            elseif categoryWeight == SHOP_WEIGHT_NAME then
                breakdown.shopCnt = breakdown.shopCnt + 1
                breakdown.shopWeight = breakdown.shopWeight + giftWeight

            elseif categoryWeight == FLOOR_WEIGHT_NAME then
                breakdown.floorCnt = breakdown.floorCnt + 1
                breakdown.floorWeight = breakdown.floorWeight + giftWeight

            elseif categoryWeight == SPECIAL_WEIGHT_NAME then
                breakdown.SENTCnt = breakdown.SENTCnt + 1
                breakdown.SENTWeight = breakdown.SENTWeight + giftWeight

            else
                dbg.Log("(Warning) Unknown category cvar:", categoryWeight)
            end
        end
    end

    breakdown.totalWeight = GetTotalWeight(xmasFactor, scoreFactor)
    return breakdown
end

function GetRandomGiftData(giftee, scoreBonus)
    if dbg.Cvar:GetBool() and DEBUG_TEST_GIFT then
        return DEBUG_TEST_GIFT, giftDataCatalog[DEBUG_TEST_GIFT]:Furnish(giftee)
    end

    local score = 0
    if IsPlayer(giftee) then
        score = giftee:Frags()
    end

    local isBoosted = scoreBonus and scoreBonus > 0
    if isBoosted then
        score = score + scoreBonus
    end

    local dayOfYear = isBoosted and XMAS_DAY or tonumber(os.date("%j"))
    local xmasFactor, scoreFactor = CalcQualityFactors(dayOfYear, score)

    local totalWeight = 0
    for label, giftData in pairs(giftDataCatalog) do
        if giftData:IsSpawnable(giftee) then
            giftData.cachedWeight = giftData:CalcWeight(xmasFactor, scoreFactor, isBoosted)
        else
            giftData.cachedWeight = 0
        end

        totalWeight = totalWeight + giftData.cachedWeight
    end


    if totalWeight > 0 then
        local roll = math.random() * totalWeight
        local accum = 0

        for label, giftData in pairs(giftDataCatalog) do
            accum = accum + giftData.cachedWeight

            if roll <= accum then
                dbg.Log("Picked gift: "..label.." (weight: "..tostring(giftData.cachedWeight)..")")
                return label, giftData:Furnish(giftee)
            end
        end
    end

    dbg.Log("Failed to pick gift, defaulting to melon")
    return "melon", giftDataCatalog.melon
end

-- For things we can derive only server-side from gift data
-- and might want later (ply can be any player)
if SERVER then
    function GiftData:Furnish(ply)
        if self.visual_override or self.dont_furnish then return self end

        if not self.cachedModel and self.category == GiftCategory.SENT then
            local sent = scripted_ents.GetStored(self.identifier)

            if sent.Model then
                self.cachedModel = sent.Model
                return self
            elseif sent.t and sent.t.Model then
                self.cachedModel = sent.t.Model
                return self
            end
        end

        if not self.cachedModel and (self.category == GiftCategory.NPC or self.category == GiftCategory.SENT) then
            local previewEnt = ents.Create(self.identifier)

            if self.set_owner then previewEnt:SetOwner(ply) end
            if previewEnt.SetThrower then previewEnt:SetThrower(ply) end
            if previewEnt.SetOriginator then previewEnt:SetOriginator(ply) end

            if IsValid(previewEnt) then
                if previewEnt.Initialize then previewEnt:Initialize()
                else previewEnt:Spawn() end
                self.cachedModel = previewEnt:GetModel()
                previewEnt:Remove()
            end
        end

        return self
    end

elseif CLIENT then
    function GiftData:GetVisuals(giftEnt)
        local category = self.category

        if self.special_setup == "fortnite_struct_setup" then
            return giftEnt:GetNW2String("fortnite_model")
        end

        if category == GiftCategory.PhysProp or category == GiftCategory.Vehicle or category == GiftCategory.Ragdoll then
            return self:GetIdentifier(giftEnt)

        elseif category == GiftCategory.SENT or category == GiftCategory.Ammo then
            local sent = scripted_ents.GetStored(self.identifier)
            return sent.t.Model and sent.t.Model or self.cachedModel

        elseif category == GiftCategory.NPC then
            return self.cachedModel --cached server-side (can't retrieve client-side afaik)

        elseif category == GiftCategory.FloorSWEP or category == GiftCategory.WorldSWEP then
            local swep = weapons.GetStored(self.identifier)
            return swep.WorldModel

        elseif category == GiftCategory.AutoEquipSWEP then
            local swep = weapons.GetStored(self.identifier)
            return swep.material, true

        elseif category == GiftCategory.Item then
            local item = items.GetStored(self.identifier)
            return item.material, true
        end

        return nil
    end

    function GiftData:GetSizeStr(giftEnt)
        local closestDesc = "Unknown"
        local closestDiff = math.huge
        local giftSize = self.attrib_size

        if IsValid(giftEnt) and giftEnt:GetClass() == PROP_CLASS_NAME then
            giftSize = giftEnt:GetGiftScale()
        end

        for descriptor, size in pairs(GiftSize) do
            local diff = math.abs(giftSize - size)

            if diff < closestDiff then
                closestDiff = diff
                closestDesc = descriptor
            end
        end

        return closestDesc
    end

    local rarityStr = {
        [1]  = "gift_status_rarity_common",
        [2]  = "gift_status_rarity_uncommon",
        [3]  = "gift_status_rarity_rare",
        [4]  = "gift_status_rarity_very_rare",
        [5]  = "gift_status_rarity_super_rare",
        [6]  = "gift_status_rarity_super_rare",
        [7]  = "gift_status_rarity_legendary",
        [8]  = "gift_status_rarity_legendary",
        [9]  = "gift_status_rarity_mythical",
        [10] = "gift_status_rarity_mythical",
    }

    function GiftData:GetStatusTable(giftObj)
        local statusTable = {}

        table.insert(statusTable, {
            icon = self.category.icon,
            text = self.category.text,
            subtext = "gift_status_type",
        })

        if self.can_be_random_gift then
            local rarity = math.min(10, math.floor(self.factor_rarity + 0.5))

            table.insert(statusTable, {
                icon = "vgui/ttt/menu/icon_clover"..(rarity >= 3 and '4' or '3'),
                text = rarityStr[rarity],
                highlightText = (rarity >= 5),
                subtext = "gift_status_rarity",
            })
        end

        if IsValid(giftObj) then
            if giftObj:GetIsContentsOnFire() then
                table.insert(statusTable, {
                    icon = "vgui/ttt/menu/icon_fire",
                    text = "gift_status_fire"
                })
            end
        end

        return statusTable
    end

    hook.Add("InitPostEntity", OVERRIDE_MV_HOOK, function()
        for label, giftData in pairs(giftDataCatalog) do
        -- setup client-side markervision overrides
            if giftData.mv_hook then
                local ogHook = hook.GetTable()["TTT2RenderMarkerVisionInfo"][giftData.mv_hook]

                if ogHook then
                    hook.Add("TTT2RenderMarkerVisionInfo", giftData.mv_hook, function(mvData)
                        local ent = mvData:GetEntity()

                        if ent._HideMarks or (ent:GetClass() == SWEP_CLASS_NAME and ent:GetOwner() == LocalPlayer()) then
                            mvData.drawInfo = false
                        else
                            ogHook(mvData)
                        end
                    end)
                end
            end

            -- fix AddCustomWorldModel sweps being visually frozen after PVS exit
            -- (to be removed once https://github.com/TTT-2/TTT2/issues/1874 is fixed)
            if giftData.worldmodel_fix then
                local swep = weapons.GetStored(giftData.identifier)

                if swep then
                    swep.DrawWorldModel = function(self, flags)
                        self:DrawModel()
                    end
                end
            end
        end
    end)
end

local giftSurfaceTypeProps = {
    ["metal"]    = {sound=GiftSound.Metallic, smell=GiftSmell.Sterile, feel=GiftFeel.Cold},
    ["wood"]     = {sound=GiftSound.Creaky,   smell=GiftSmell.Woody,   feel=GiftFeel.Sturdy},
    ["slime"]    = {sound=GiftSound.Goopy,    smell=GiftSmell.Strange, feel=GiftFeel.Slippery},
    ["flesh"]    = {sound=GiftSound.Fleshy,   smell=GiftSmell.Rotten,  feel=GiftFeel.Squishy},
    ["glass"]    = {sound=GiftSound.Glass,                             feel=GiftFeel.Hollow},
    ["ice"]      = {sound=GiftSound.Glass,                             feel=GiftFeel.Cold},
    ["plastic"]  = {sound=GiftSound.Plastic,  smell=GiftSmell.Sterile, feel=GiftFeel.Light},
    ["tire"]     = {sound=GiftSound.Springy,  smell=GiftSmell.Rubbery, feel=GiftFeel.Round},
    ["rubber"]   = {sound=GiftSound.Springy,  smell=GiftSmell.Rubbery, feel=GiftFeel.Squishy},
    ["concrete"] = {sound=GiftSound.Thudding, smell=GiftSmell.Dry,     feel=GiftFeel.Hollow},
    ["paper"]    = {sound=GiftSound.Rustling, smell=GiftSmell.Paper,   feel=GiftFeel.Soft},
}

local giftSurfaceProps = {
    ["item"]                = {sound=GiftSound.Metallic,   smell=GiftSmell.Gunpowder},
    ["player"]              = {sound=GiftSound.Talking,    smell=GiftSmell.Stinky,    feel=GiftFeel.Alive},
    ["player_control_clip"] = {sound=GiftSound.Talking,    smell=GiftSmell.Stinky,    feel=GiftFeel.Alive},
    ["boulder"]             = {sound=GiftSound.Thudding,   smell=GiftSmell.Mineral,   feel=GiftFeel.Hard},
    ["brick"]               = {sound=GiftSound.Thudding,                              feel=GiftFeel.Hard},
    ["gravel"]              = {sound=GiftSound.Granular,   smell=GiftSmell.Dusty,     feel=GiftFeel.Formless},
    ["rock"]                = {sound=GiftSound.Thudding,   smell=GiftSmell.Mineral,   feel=GiftFeel.Hard},
    ["canister"]            = {sound=GiftSound.Metallic,   smell=GiftSmell.Oily,      feel=GiftFeel.Cold},
    ["chain"]               = {sound=GiftSound.Metallic,   smell=GiftSmell.Rusty,     feel=GiftFeel.Cold},
    ["chainlink"]           = {sound=GiftSound.Metallic,   smell=GiftSmell.Rusty,     feel=GiftFeel.Cold},
    ["grenade"]             = {sound=GiftSound.Metallic,   smell=GiftSmell.Gunpowder, feel=GiftFeel.Round},
    ["metal_bouncy"]        = {sound=GiftSound.Springy,                               feel=GiftFeel.Slippery},
    ["metalgrate"]          = {                            smell=GiftSmell.Rusty},
    ["metalvent"]           = {                            smell=GiftSmell.Dusty},
    ["paintcan"]            = {sound=GiftSound.Splashing,  smell=GiftSmell.Paint,     feel=GiftFeel.Cold},
    ["popcan"]              = {sound=GiftSound.Splashing,  smell=GiftSmell.Food,      feel=GiftFeel.Cold},
    ["roller"]              = {sound=GiftSound.Springy,    smell=GiftSmell.Sterile,   feel=GiftFeel.Alive},
    ["slipperymetal"]       = {sound=GiftSound.Goopy,                                 feel=GiftFeel.Slippery},
    ["weapon"]              = {sound=GiftSound.Metallic,   smell=GiftSmell.Gunpowder, feel=GiftFeel.Cold},
    ["wood_crate"]          = {                                                       feel=GiftFeel.Heavy},
    ["wood_lowdensity"]     = {                                                       feel=GiftFeel.Hollow},
    ["dirt"]                = {sound=GiftSound.Granular,   smell=GiftSmell.Earthy,    feel=GiftFeel.Formless},
    ["grass"]               = {sound=GiftSound.Rustling,   smell=GiftSmell.Earthy,    feel=GiftFeel.Weightless},
    ["mud"]                 = {sound=GiftSound.Squelching, smell=GiftSmell.Stinky,    feel=GiftFeel.Icky},
    ["quicksand"]           = {sound=GiftSound.Squelching, smell=GiftSmell.Earthy,    feel=GiftFeel.Icky},
    ["sand"]                = {sound=GiftSound.Granular,   smell=GiftSmell.Dusty,     feel=GiftFeel.Soft},
    ["water"]               = {sound=GiftSound.Splashing,                             feel=GiftFeel.Formless},
    ["wade"]                = {sound=GiftSound.Splashing,                             feel=GiftFeel.Formless},
    ["snow"]                = {sound=GiftSound.Thudding,   smell=GiftSmell.Nice,      feel=GiftFeel.Cold},
    ["alienflesh"]          = {                            smell=GiftSmell.Strange,   feel=GiftFeel.Otherworldly},
    ["foliage"]             = {sound=GiftSound.Rustling,   smell=GiftSmell.Earthy,    feel=GiftFeel.Soft},
    ["watermelon"]          = {sound=GiftSound.Squishy,    smell=GiftSmell.Food,      feel=GiftFeel.Round},
    ["glassbottle"]         = {                            smell=GiftSmell.Food,      feel=GiftFeel.Cold},
    ["tile"]                = {sound=GiftSound.Thudding,   smell=GiftSmell.Dusty,     feel=GiftFeel.Cold},
    ["papercup"]            = {                            smell=GiftSmell.Paper,     feel=GiftFeel.Light},
    ["cardboard"]           = {                            smell=GiftSmell.Cardboard, feel=GiftFeel.Light},
    ["plaster"]             = {sound=GiftSound.Thudding,   smell=GiftSmell.Paint,     feel=GiftFeel.Cold},
    ["plastic_barrel"]      = {                                                       feel=GiftFeel.Hollow},
    ["plastic_barrel_buoyant"] = {                                                    feel=GiftFeel.Hollow},
    ["porcelain"]           = {sound=GiftSound.Glass,      smell=GiftSmell.Sterile,   feel=GiftFeel.Cold},
    ["carpet"]              = {                            smell=GiftSmell.Dusty,     feel=GiftFeel.Soft},
    ["ceiling_tile"]        = {sound=GiftSound.Thudding,   smell=GiftSmell.Dusty,     feel=GiftFeel.Cold},
    ["computer"]            = {sound=GiftSound.Whirring,   smell=GiftSmell.Sterile,   feel=GiftFeel.Electric},
    ["pottery"]             = {sound=GiftSound.Thudding,   smell=GiftSmell.Clay,      feel=GiftFeel.Hollow},
    ["gmod_bouncy"]         = {sound=GiftSound.Springy},
    ["gm_ps_egg"]           = {                            smell=GiftSmell.Food,      feel=GiftFeel.Round},
    ["gm_ps_metaltire"]     = {                                                       feel=GiftFeel.Round},
    ["gm_ps_soccerball"]    = {                            smell=GiftSmell.Leather,   feel=GiftFeel.Round},
    ["gm_ps_woodentire"]    = {                                                       feel=GiftFeel.Round},
    ["gm_torpedo"]          = {sound=GiftSound.Metallic,   smell=GiftSmell.Gunpowder, feel=GiftFeel.Powerful},
    ["hay"]                 = {sound=GiftSound.Rustling,   smell=GiftSmell.Earthy,    feel=GiftFeel.Formless},
    ["phx_explosiveball"]   = {sound=GiftSound.Metallic,   smell=GiftSmell.Gunpowder, feel=GiftFeel.Round},
    ["phx_ww2bomb"]         = {sound=GiftSound.Metallic,   smell=GiftSmell.Gunpowder, feel=GiftFeel.Powerful},
    ["hunter"]              = {sound=GiftSound.Fleshy,     smell=GiftSmell.Strange,   feel=GiftFeel.Bursting},
    ["jalopy"]              = {sound=GiftSound.Revving,    smell=GiftSmell.Dusty,     feel=GiftFeel.Sturdy},
    ["plastic_barrel_verybuoyant"] = {                                                feel=GiftFeel.Hollow},
}

function GiftData:Detect(ent, entIdentifier)
    if self.special_setup == "fireball_setup" then
        return ent:GetName() == "Fireball"

    elseif self.special_setup == "fart_grenade_setup" then
        -- no better check unfortunately
        return ent:GetModel() == "models/weapons/w_grenade.mdl"
          and utils.NearEquals(ent:GetGravity(), 0.4)
          and utils.NearEquals(ent:GetFriction(), 0.2)
          and utils.NearEquals(ent:GetElasticity(), 0.45)
    end

    if self.identifiers then
        for _, mdl in ipairs(self.identifiers) do
            if mdl == entIdentifier then
                return true
            end
        end

        return false
    else
        return self.identifier == entIdentifier
    end
end

function GetEntGiftData(ent, silent)
    local entClass = ent:GetClass()
    local entIdentifier = entClass
    local entModel = ent:GetModel()
    local entName = ent:GetName()

    if string.find(entIdentifier, "prop_physics", nil, true)
      or string.StartsWith(entIdentifier, "prop_vehicle")
      or entIdentifier == "prop_ragdoll" then
        entIdentifier = entModel

    elseif entIdentifier == "func_physbox" then
        entIdentifier = entName
    end

    for label, giftData in pairs(giftDataCatalog) do
        if giftData:Detect(ent, entIdentifier) then
            return label, giftData
        end
    end

    -- Generating placeholder data from entity attributes
    if not silent then
        dbg.Log("Could not find gift data for "..tostring(ent).."; generating placeholder...")
        dbg.Log("=> Model path: ", entModel)
    end

    local placeholderData = GiftData.New({})
    local placeholderLabel = "gift_ent_"..tostring(ent:EntIndex())
    placeholderData.identifier = entIdentifier

    placeholderData.autoGen = true
    if weapons.GetStored(entIdentifier) or items.GetStored(entIdentifier) then
        placeholderData.placeholderEquip = true
    end

    -- Detect category
    if entClass == "prop_ragdoll" then
        placeholderData.category = GiftCategory.Ragdoll

    elseif entClass == "func_physbox" then
        placeholderData.category = GiftCategory.PhysBox

    elseif entIdentifier == entModel then
        placeholderData.category = GiftCategory.PhysProp

    elseif ent.Base == "base_ammo_ttt" then
        placeholderData.category = GiftCategory.Ammo

    elseif list.Get("NPC")[entIdentifier] then
        placeholderData.category = GiftCategory.NPC

    elseif weapons.GetStored(entIdentifier) then
        placeholderData.category = ent.AutoSpawnable and GiftCategory.FloorSWEP or GiftCategory.WorldSWEP

    elseif scripted_ents.GetStored(entIdentifier) then
        placeholderData.category = GiftCategory.SENT

    elseif ent:IsVehicle() then
        placeholderData.category = GiftCategory.Vehicle

    else
        placeholderData.category = GiftCategory.Unknown
    end

    -- Find & set name if available
    local name

    if ent.PrintName and ent.PrintName ~= "" then
        name = ent.PrintName

    elseif entName and entName ~= "" then
        name = entName
    end

    if not name then
        placeholderData.name = string.match(string.StripExtension(entModel), "[^/\\]+$"):gsub("^%l", string.upper)
        if entClass == "prop_ragdoll" then
            placeholderData.desc = "a body"
        else
            placeholderData.desc = "a gift"
        end

    else
        placeholderData.name = name:gsub("^%l", string.upper)
        placeholderData.desc = "a " .. placeholderData.name
    end

    -- Set sound/smell/feel from material
    placeholderData.attrib_sound = GiftSound.None
    placeholderData.attrib_smell = GiftSmell.Nondescript
    placeholderData.attrib_feel  = GiftFeel.Indescribable

    local phys = ent:GetPhysicsObject()
    local surfacePropName = utils.GetEntSurfaceProp(ent, phys, silent)
    if not silent then dbg.Log("Found surface prop name:", surfacePropName) end

    if surfacePropName then
        surfacePropName = string.lower(surfacePropName)

        -- inherit from surface type, if possible
        for skey, sval in pairs(giftSurfaceTypeProps) do
            if string.find(surfacePropName, skey, 1, true) then
                if sval.sound then placeholderData.attrib_sound = sval.sound end
                if sval.smell then placeholderData.attrib_smell = sval.smell end
                if sval.feel  then placeholderData.attrib_feel = sval.feel end
                break
            end
        end

        local surfaceProp = giftSurfaceProps[surfacePropName]
        if surfaceProp then
            if surfaceProp.sound then placeholderData.attrib_sound = surfaceProp.sound end
            if surfaceProp.smell then placeholderData.attrib_smell = surfaceProp.smell end
            if surfaceProp.feel  then placeholderData.attrib_feel = surfaceProp.feel end
        end
    end

    -- Set gift size (from bounds, or mass, or rng)
    --local mins, maxs = ent:GetModelBounds()
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()

    if mins and maxs then
        --local scale = ent.GetModelScale and ent:GetModelScale() or 1 -- included in OBB
        local size = maxs - mins
        local maxLen = math.max(size.x, size.y, size.z)
        placeholderData.attrib_size = math.min(7, maxLen * 0.07 + 0.5) -- cf. resource workfiles in repo

    elseif IsValid(phys) then
        local mass = phys:GetMass()

        -- Set size from weight (legacy code kept just in case; above branch should always be used)
        if mass <= 1      then placeholderData.attrib_size = GiftSize.Mini
        elseif mass <= 5  then placeholderData.attrib_size = GiftSize.Small
        elseif mass < 15  then placeholderData.attrib_size = GiftSize.Normal
        elseif mass < 18  then placeholderData.attrib_size = GiftSize.Large
        elseif mass < 30  then placeholderData.attrib_size = GiftSize.Larger
        elseif mass < 80  then placeholderData.attrib_size = GiftSize.Big
        elseif mass < 200 then placeholderData.attrib_size = GiftSize.Huge
        else                   placeholderData.attrib_size = GiftSize.Gigantic end

    else
        local GiftSizeList = {}
        for _, s in pairs(GiftSize) do
            GiftSizeList[#GiftSizeList + 1] = s
        end

        placeholderData.attrib_size = GiftSizeList[math.random(#GiftSizeList)]
    end

    -- Set feel from weight (if none found yet)
    if placeholderData.attrib_feel == GiftFeel.Indescribable and IsValid(phys) then
        local mass = phys:GetMass()

        if mass < 5      then placeholderData.attrib_feel = GiftFeel.Weightless
        elseif mass < 15 then placeholderData.attrib_feel = GiftFeel.Light
        elseif mass < 50 then placeholderData.attrib_feel = GiftFeel.Heavy
        else                  placeholderData.attrib_feel = GiftFeel.Massive end
    end

    -- Special handling for grenades
    if ent.GetExplodeTime then
        placeholderData.special_setup = "grenade"
    end

    -- Add to table for future lookup
    giftDataCatalog[placeholderLabel] = placeholderData
    ent:CallOnRemove(PLACEHOLDER_DATA_REMOVE, function()
        giftDataCatalog[placeholderLabel] = nil
    end)

    return placeholderLabel, placeholderData
end

function GetSWEPGiftData(swepID)
    for label, giftData in pairs(giftDataCatalog) do
        if giftData.identifier == swepID then
            return label, giftData
        end
    end

    local swep = weapons.GetStored(swepID)
    local placeholderData = GiftData.New {
        name     = swep.PrintName, -- likely not to be set server-side
        desc     = "a gift",
        category = GiftCategory.AutoEquipSWEP,
        identifier = swepID,
        placeholderEquip = true
    }

    UpdateCatalog(swepID, placeholderData)
    return swepID, placeholderData
end

function GetItemGiftData(itemID)
    for label, giftData in pairs(giftDataCatalog) do
        if giftData.identifier == itemID then
            return label, giftData
        end
    end

    local item = items.GetStored(itemID)
    local placeholderData = GiftData.New {
        name     = item.PrintName,
        desc     = item.desc,
        category = GiftCategory.Item,
        identifier = itemID,
        attrib_size = GiftSize.Small,
        placeholderEquip = true
    }

    UpdateCatalog(itemID, placeholderData)
    return itemID, placeholderData
end


if SERVER then
    local initTotalWeight, initGiftCount = GetTotalWeight()
    dbg.Log("Gift data loaded ("..initGiftCount.." gifts, totalling "..initTotalWeight.." weight).")
    --dbg.Inspect(GetCategoryWeightBreakdown())

    -- precache prop/vehicle models (can add other types if needed)
    for label, data in pairs(giftDataCatalog) do
        if data.category == GiftCategory.PhysProp or data.category == GiftCategory.Vehicle or data.category == GiftCategory.Ragdoll then
            if data.identifier then
                util.PrecacheModel(data.identifier)
            end

            if data.identifiers then
                for _, mdl in ipairs(data.identifiers) do
                    util.PrecacheModel(mdl)
                end
            end
        end
    end
end