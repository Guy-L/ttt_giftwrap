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

local PLACEHOLDER_DATA_REMOVE    = "GiftWrap_RemoveGiftData"
local CLUTTERBOMB_LIGHT_FIX_HOOK = "GiftWrap_ClutterbombLightFix"
local INIT_FIXES_HOOK            = "GiftWrap_InitialFixesSetup"
local OVERRIDE_MV_HOOK           = "GiftWrapCL_OverrideMarkerVisionRenderHook"
local ENT_TAKE_DAMAGE_HOOK       = "GiftWrapSV_VehicleOccupantsDamageFix"
local PLAYER_USE_HOOK            = "GiftWrapSV_InternalVehicleSeatFix"

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
    SENT          = {id=2,  text="Special Entity", icon="vgui/ttt/menu/icon_sparkles", weight=SPECIAL_WEIGHT_NAME},
    NPC           = {id=3,  text="NPC",            icon="vgui/ttt/menu/icon_headcrab", weight=SPECIAL_WEIGHT_NAME},
    FloorSWEP     = {id=4,  text="Floor Weapon",   icon="vgui/ttt/menu/icon_gun",      weight=FLOOR_WEIGHT_NAME},
    WorldSWEP     = {id=5,  text="Shop Weapon",    icon="vgui/ttt/menu/icon_knife",    weight=SHOP_WEIGHT_NAME},
    AutoEquipSWEP = {id=6,  text="Shop Weapon",    icon="vgui/ttt/menu/icon_knife",    weight=SHOP_WEIGHT_NAME},
    Item          = {id=7,  text="Shop Item",      icon="vgui/ttt/menu/icon_bottle",   weight=SHOP_WEIGHT_NAME},
    Ammo          = {id=8,  text="Ammo Box",       icon="vgui/ttt/menu/icon_ammo",     weight=FLOOR_WEIGHT_NAME},
    Vehicle       = {id=9,  text="Vehicle",        icon="vgui/ttt/menu/icon_car",      weight=SPECIAL_WEIGHT_NAME},
    Unknown       = {id=10, text="Unknown",        icon="vgui/ttt/menu/icon_question", weight=SPECIAL_WEIGHT_NAME},
}

GiftSound = {
    Squishy    = {snd="", desc="squishy"},
    Goopy      = {snd="", desc="goopy"},
    Metallic   = {snd="", desc="metallic"},
    Glass      = {snd="", desc="tinkly"},
    Wooden     = {snd="", desc="creaky"},
    Plastic    = {snd="", desc="plasticky"}, -- pretty much unused
    Fleshy     = {snd="", desc="fleshy"},
    Talking    = {snd="", desc="like it's talking"},
    Meowing    = {snd="", desc="like it's meowing"},
    Bleating   = {snd="", desc="like it's bleating"}, -- lambert only
    Thudding   = {snd="", desc="like it's thudding"},
    Whirring   = {snd="", desc="like it's whirring"},
    Revving    = {snd="", desc="like it's revving"},
    Beeping    = {snd="", desc="like it's beeping"},
    Granular   = {snd="", desc="granular"},
    Springy    = {snd="", desc="springy"},
    Musical    = {snd="", desc="musical"},
    Squeaky    = {snd="", desc="squeaky"}, --new, underused
    Hollow     = {snd="", desc="hollow"}, --new, underused
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
        category = GiftCategory.PhysProp, identifier = "models/drm/argemia_plush.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Meowing,  attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Otherworldly,
    },
    car_wreck = GiftData.New {
        name     = "Car Wreck",           desc       = "a broken down car",
        category = GiftCategory.PhysProp, identifier = "models/props_vehicles/car005b_physics.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Massive,
    },
    cirno_fumo = GiftData.New {
        name     = "Cirno Fumo",          desc       = "a fumo",
        category = GiftCategory.PhysProp, identifier = "models/asianbop/coolprops/u8/cirno.mdl",
        can_be_random_gift = false,
        --factor_rarity = 0.9, factor_quality = 9,
        attrib_sound = GiftSound.None,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Cotton, attrib_feel = GiftFeel.Cold,
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
    dead_bunger = GiftData.New {
        name     = "Dead Bunger",         desc       = "a dead Bunger",
        category = GiftCategory.PhysProp, identifier = "models/betterbunger.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Squishy,
    },
    explosive_barrel = GiftData.New {
        name     = "Explosive Barrel",    desc       = "an explosive barrel",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/oildrum001_explosive.mdl",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -9,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Round,
        special_setup = "explo_barrel_setup"
    },
    goober = GiftData.New {
        name     = "Goober",              desc       = "a goober",
        category = GiftCategory.PhysProp, identifier = "models/propper/ttt_unsung_star_a3/goober_0.mdl",
        can_be_random_gift = false,
        --factor_rarity = 2, factor_quality = 8,
        attrib_sound = GiftSound.None,   attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky, attrib_feel = GiftFeel.Flat,
    },
    lambert = GiftData.New {
        name     = "Lambert Plushie",     desc       = "a sacrificial lamb",
        category = GiftCategory.PhysProp, identifier = "models/asianbop/coolprops/u14/lambert.mdl",
        can_be_random_gift = false,
        --factor_rarity = 1, factor_quality = 6,
        attrib_sound = GiftSound.Bleating, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Wool,     attrib_feel = GiftFeel.Otherworldly,
    },
    maxwell_prop = GiftData.New {
        name     = "Maxwell",             desc       = "a dapper gentleman",
        category = GiftCategory.PhysProp, identifier = "models/dingus/dingus.mdl",
        --can_be_random_gift = false,
        --factor_rarity = 2, factor_quality = 7,
        attrib_sound = GiftSound.Meowing, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Fur,     attrib_feel = GiftFeel.Soft,
    },
    neco_arc = GiftData.New {
        name     = "Neco Arc Plushie",    desc       = "a weird cat",
        category = GiftCategory.PhysProp, identifier = "models/drm/neko_arc_plush.mdl",
        can_be_random_gift = false,
        --factor_rarity = 1, factor_quality = 3,
        attrib_sound = GiftSound.Meowing, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Otherworldly,
    },
    plush_turtle = GiftData.New {
        name     = "Plush Turtle",        desc       = "a turtle plushie",
        category = GiftCategory.PhysProp, identifier = "models/props/de_tides/vending_turtle.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 8,
        attrib_sound = GiftSound.None,     attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Cotton,   attrib_feel = GiftFeel.Squishy,
    },
    rat = GiftData.New {
        name     = "Rat",                desc       = "a rat",
        category = GiftCategory.PhysProp, identifier = "models/asianbop/coolprops/u1/rat/rat.mdl",
        can_be_random_gift = false,
        --factor_rarity = 1, factor_quality = -5,
        attrib_sound = GiftSound.Squeaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Alive,
    },
    seal = GiftData.New {
        name     = "Seal",                desc       = "a seal",
        category = GiftCategory.PhysProp, identifier = "models/niko/niko.mdl",
        can_be_random_gift = false,
        --factor_rarity = 1, factor_quality = 5,
        attrib_sound = GiftSound.Squeaky, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Fur,     attrib_feel = GiftFeel.Slippery,
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
        attrib_smell = GiftSmell.Salty,  attrib_feel = GiftFeel.Cursed,
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

    ----------------------------------------------------------------------
    -- SENTs / NPCs
    ads = GiftData.New {
        name     = "Live ADS",        desc       = "a defensive sentry bot",
        category = GiftCategory.SENT, identifier = "ads",
        can_be_random_gift = false,
        --factor_rarity = 3, factor_quality = 6,
        attrib_sound = GiftSound.Beeping,   attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Electric,
        stick_to_ground = true
    },
    banana_peel = GiftData.New { --TODO link to swep
        name     = "Banana Peel",     desc       = "an old banana peel",
        category = GiftCategory.SENT, identifier = "ttt_banana_peel",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -5,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Rotten,  attrib_feel = GiftFeel.Slippery,
        adjAngle = Angle(90, 0, 0)
    },
    banana_bomb = GiftData.New {
        name     = "Live Banana Bomb", desc       = "an explosive bunch",
        category = GiftCategory.SENT,  identifier = "ttt_banana_proj",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy,   attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Fresh,
        special_setup = "grenade", explosion_delay = 2, set_owner = true
    },
    banana_split = GiftData.New {
        name     = "Live Banana Split", desc      = "dangerous levels of potassium",
        category = GiftCategory.SENT,  identifier = "ttt_banana_split",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = -7,
        attrib_sound = GiftSound.Squishy,   attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Fresh,
        special_setup = "grenade_auto", explosion_delay = 2, set_owner = true
    },
    barnacle = GiftData.New {
        name     = "Live Barnacle",  desc       = "a hungry barnacle",
        category = GiftCategory.NPC, identifier = "npc_barnacle",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = -9,
        attrib_sound = GiftSound.Fleshy, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Rotten, attrib_feel = GiftFeel.Alive,
        special_setup = "barnacle_setup"
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
        factor_rarity = 6, factor_quality = 2,
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
        attrib_sound = GiftSound.Fleshy, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Rotten, attrib_feel = GiftFeel.Alive,
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
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Woody,     attrib_feel = GiftFeel.Otherworldly,
    },
    molotov_grenade = GiftData.New {
        name     = "Molotov Cocktail (Grenade)", desc       = "a spicy cocktail",
        category = GiftCategory.SENT,            identifier = "sent_molotov_timed",
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
    shard_of_greed = GiftData.New {
        name     = "Shard of Greed",  desc       = "an ominous shard",
        category = GiftCategory.SENT, identifier = "ttt_shard_of_greed",
        can_be_random_gift = true,
        factor_rarity = 0.7, factor_quality = 2,
        attrib_sound = GiftSound.Glass,  attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Earthy, attrib_feel = GiftFeel.Cursed,
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
    -- FloorSWEPs
    ares_shrike = GiftData.New {
        name     = "Ares Shrike",          desc       = "an Ares Shrike",
        category = GiftCategory.FloorSWEP, identifier = "weapon_hp_ares_shrike",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -1,
        attrib_sound = GiftSound.Revving,  attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Heavy,
    },
    banana_item = GiftData.New {
        name     = "Banana",               desc       = "a fresh banana",
        category = GiftCategory.FloorSWEP, identifier = "ttt_banana",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Fresh,
    },
    huge = GiftData.New {
        name     = "H.U.G.E-249",          desc       = "a H.U.G.E",
        category = GiftCategory.FloorSWEP, identifier = "weapon_zm_sledge",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -1,
        attrib_sound = GiftSound.Revving,  attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Heavy,
    },
    honey_badger = GiftData.New {
        name     = "Honey Badger",          desc       = "a Honey Badger",
        category = GiftCategory.FloorSWEP, identifier = "weapon_ap_hbadger",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 0,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,     attrib_feel = GiftFeel.Cold,
    },
    meow_catgun = GiftData.New {
        name     = "M1A0 Cat Gun",         desc       = "a stray catgun",
        category = GiftCategory.FloorSWEP, identifier = "weapon_catgun",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 2,
        attrib_sound = GiftSound.Meowing, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Fur,     attrib_feel = GiftFeel.Alive,
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
    ads_item = GiftData.New {
        name     = "ADS",                  desc       = "a defensive sentry bot",
        category = GiftCategory.WorldSWEP, identifier = "adsplacer",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping,   attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Electric,
    },
    banana_bomb_item = GiftData.New {
        name     = "Banana Bomb",          desc       = "an explosive bunch",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_banana",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy,   attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Fresh,
    },
    barnacle_item = GiftData.New {
        name     = "Barnacle",             desc       = "a hungry pet barnacle",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_barnacle",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Fleshy, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Rotten, attrib_feel = GiftFeel.Alive,
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
    chainsaw = GiftData.New {
        name     = "Chainsaw",             desc       = "a sick chainsaw",
        category = GiftCategory.WorldSWEP, identifier = "weapon_chainsaw_new",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Revving, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Sharp,
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
        name     = "Defibrillator",        desc       = "live-saving medical equipment",
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
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Electric,
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
        name     = "Eagleflight Gun",      desc       = "a gun that shoots yourself",
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
    fireball = GiftData.New {
        name     = "Fireball",                 desc       = "fire magic",
        category = GiftCategory.AutoEquipSWEP, identifier = "weapon_firemagic",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Ash,       attrib_feel = GiftFeel.Magical,
    },
    flare_gun = GiftData.New {
        name     = "Flare Gun",            desc       = "a Flare Gun",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_flaregun",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Ash,      attrib_feel = GiftFeel.Cold,
    },
    fortnite = GiftData.New {
        name     = "Fortnite Building",        desc       = "a Fortnite Battle Pass",
        category = GiftCategory.AutoEquipSWEP, identifier = "weapon_ttt_fortnite_building",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding,  attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Cardboard, attrib_feel = GiftFeel.Otherworldly,
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
    hand_cannon = GiftData.New {
        name     = "Hand Canon",           desc       = "an old-timey hand cannon",
        category = GiftCategory.WorldSWEP, identifier = "weapon_hcannon",
        can_be_random_gift = true,
        factor_rarity = 6, factor_quality = 5,
        attrib_sound = GiftSound.Wooden, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Salty,  attrib_feel = GiftFeel.Hollow,
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
    --jammifier = GiftData.New { TODO fix paps
    --    name     = "Jammifier",            desc       = "the gift of jam",
    --    category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_wpnjammer",
    --    can_be_random_gift = false,
    --    attrib_sound = GiftSound.Glass, attrib_size = GiftSize.Normal,
    --    attrib_smell = GiftSmell.Food,  attrib_feel = GiftFeel.Sticky,
    --},
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
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Large,
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
        name     = "Prop Exploder v2",        desc       = "an explosive chip",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_propexploderv2",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Long,
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
        factor_rarity = 10, factor_quality = 9,
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
        attrib_smell = GiftSmell.Rotten,   attrib_feel = GiftFeel.Otherworldly,
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
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,      attrib_feel = GiftFeel.Cold,
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
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Earthy,    attrib_feel = GiftFeel.Magical,
    },
    disguiser = GiftData.New {
        name     = "Disguiser",       desc       = "a poorly crafted disguise kit",
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
    pog_instant = GiftData.New { -- weird bug (og addon): will always try giving you a pap upgrade if holding something that doesn't have one lol
        name     = "Pot of Greedier (Instant)", desc       = "Pot of Greed, which lets you draw two additional gifts from your deck",
        category = GiftCategory.Item,           identifier = "item_ttt_potofgreedier",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass,  attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Earthy, attrib_feel = GiftFeel.Random,
        can_get_multiple = true,
    },
    pap = GiftData.New {
        name     = "Pack-a-Punch",    desc       = "a fresh coat of paint for your crowbar",
        category = GiftCategory.Item, identifier = "ttt2_pap_item",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 5,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Paint,   attrib_feel = GiftFeel.Powerful,
        special_setup = "pap_setup",
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
        can_be_random_gift = false,
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
    Other   = nil,
}

-- to populate the list with standard (non-random / equiprobable) gun data
local standardGuns = {
    ak47          = {cat = GiftCategory.WorldSWEP, name = "AK47",            id = "weapon_ttt_ak47",          an=true,  random=false,                       type = GunType.Other,   smell = GiftSmell.Woody},
    aug           = {cat = GiftCategory.FloorSWEP, name = "AUG",             id = "weapon_ttt_aug",           an=true,  random=true, rarity=1, quality=1,   type = GunType.Other},
    blunderbus    = {cat = GiftCategory.WorldSWEP, name = "Blunderbus",      id = "weapon_ttt_blunderbus",    an=false, random=false,                       type = GunType.Other,   sound = GiftSound.Thudding, smell = GiftSmell.Dusty, feel = GiftFeel.Powerful}, --maybe move from here?
    deagle        = {cat = GiftCategory.FloorSWEP, name = "Deagle",          id = "weapon_zm_revolver",       an=false, random=true, rarity=1, quality=3,   type = GunType.Pistol,  pistol = true},
    double_barrel = {cat = GiftCategory.WorldSWEP, name = "Double Barrel",   id = "weapon_sp_dbarrel",        an=false, random=false,                       type = GunType.Shotgun, feel = GiftFeel.Powerful},
    famas         = {cat = GiftCategory.FloorSWEP, name = "Famas",           id = "weapon_ttt_famas",         an=false, random=true, rarity=1, quality=1,   type = GunType.Other},
    g3sg1         = {cat = GiftCategory.FloorSWEP, name = "G3SG1",           id = "weapon_ttt_g3sg1",         an=false, random=true, rarity=1, quality=1,   type = GunType.Rifle},
    galil         = {cat = GiftCategory.FloorSWEP, name = "Galil",           id = "weapon_ttt_galil",         an=false, random=true, rarity=1, quality=1,   type = GunType.Other},
    glock         = {cat = GiftCategory.FloorSWEP, name = "Glock",           id = "weapon_ttt_glock",         an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol},
    hmt           = {cat = GiftCategory.FloorSWEP, name = "HMT-10",          id = "weapon_ttt_milk_hmt10",    an=true,  random=true, rarity=1, quality=0,   type = GunType.Pistol},
    kr_vector     = {cat = GiftCategory.FloorSWEP, name = "Kriss Vector",    id = "weapon_ap_vector",         an=false, random=true, rarity=1, quality=1,   type = GunType.Other,   feel = GiftFeel.Futuristic},
    ksg           = {cat = GiftCategory.FloorSWEP, name = "KSG",             id = "weapon_ttt_ksg",           an=false, random=true, rarity=1, quality=1,   type = GunType.Shotgun},
    m16           = {cat = GiftCategory.FloorSWEP, name = "M16",             id = "weapon_ttt_m16",           an=true,  random=true, rarity=1, quality=0,   type = GunType.Other},
    m3s90         = {cat = GiftCategory.FloorSWEP, name = "M3S90",           id = "weapon_ttt_m3s90",         an=true,  random=true, rarity=1, quality=1,   type = GunType.Shotgun, sound = GiftSound.Thudding},
    mac10         = {cat = GiftCategory.FloorSWEP, name = "MAC10",           id = "weapon_zm_mac10",          an=false, random=true, rarity=1, quality=0,   type = GunType.Other},
    mauser        = {cat = GiftCategory.FloorSWEP, name = "Mauser C96",      id = "weapon_mauser",            an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol,  smell = GiftSmell.Woody, feel = GiftFeel.Bursting},
    mp5           = {cat = GiftCategory.FloorSWEP, name = "MP5 Navy",        id = "weapon_ttt_mp5",           an=true,  random=true, rarity=1, quality=0,   type = GunType.Other},
    mp5k          = {cat = GiftCategory.WorldSWEP, name = "MP5K",            id = "weapon_ttt_mp5k",          an=true,  random=false, rarity=1, quality=3,  type = GunType.Other},
    mp7           = {cat = GiftCategory.FloorSWEP, name = "MP7",             id = "weapon_ttt_smg",           an=true,  random=true, rarity=1, quality=0,   type = GunType.Other},
    mrca1         = {cat = GiftCategory.FloorSWEP, name = "MR-CA1",          id = "weapon_ap_mrca1",          an=true,  random=true, rarity=1, quality=0,   type = GunType.Other},
    p228          = {cat = GiftCategory.FloorSWEP, name = "P228",            id = "weapon_ttt_p228",          an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol},
    p90           = {cat = GiftCategory.WorldSWEP, name = "P90",             id = "weapon_ttt_p90",           an=false, random=true, rarity=3, quality=6,   type = GunType.Other},
    pistol        = {cat = GiftCategory.FloorSWEP, name = "Pistol",          id = "weapon_zm_pistol",         an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol},
    pocket_rifle  = {cat = GiftCategory.FloorSWEP, name = "Pocket Rifle",    id = "weapon_rp_pocket",         an=false, random=true, rarity=1, quality=1,   type = GunType.Rifle,   size = GiftSize.Mini, feel = GiftFeel.VerySmall},
    pp19          = {cat = GiftCategory.FloorSWEP, name = "PP-19 Bizon",     id = "weapon_ap_pp19",           an=false, random=true, rarity=1, quality=0,   type = GunType.Other},
    pump_shotgun  = {cat = GiftCategory.FloorSWEP, name = "Pump Shotgun",    id = "weapon_ttt_pump",          an=false, random=true, rarity=1, quality=0,   type = GunType.Shotgun, smell = GiftSmell.Dusty},
    raging_bull   = {cat = GiftCategory.FloorSWEP, name = "Raging Bull",     id = "weapon_pp_rbull",          an=false, random=true, rarity=1, quality=1,   type = GunType.Pistol,  smell = GiftSmell.Dusty},
    railgun       = {cat = GiftCategory.WorldSWEP, name = "Railgun",         id = "weapon_rp_railgun",        an=false, random=true, rarity=6, quality=8,   type = GunType.Rifle,   sound = GiftSound.Revving},
    railrifle     = {cat = GiftCategory.WorldSWEP, name = "Railrifle",       id = "weapon_ttt_railslug",      an=false, random=false,                       type = GunType.Rifle,   sound = GiftSound.Revving},
    reming_pistol = {cat = GiftCategory.FloorSWEP, name = "Remington 1858",  id = "weapon_pp_remington",      an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol,  smell = GiftSmell.Dusty},
    reming_shgun  = {cat = GiftCategory.FloorSWEP, name = "Remington AE870", id = "weapon_ttt_milk_870",      an=false, random=true, rarity=1, quality=1,   type = GunType.Shotgun, smell = GiftSmell.Woody},
    rifle         = {cat = GiftCategory.FloorSWEP, name = "Rifle",           id = "weapon_zm_rifle",          an=false, random=true, rarity=1, quality=2,   type = GunType.Rifle},
    s357          = {cat = GiftCategory.WorldSWEP, name = "'SUPER' 357",     id = "weapon_ttt_s357",          an=false, random=false, rarity=1, quality=-8, type = GunType.Pistol,  feel = GiftFeel.Cursed},
    sw500         = {cat = GiftCategory.WorldSWEP, name = "S&W 500",         id = "weapon_ttt_revolver",      an=true,  random=false,                       type = GunType.Pistol,  feel = GiftFeel.Powerful},
    sg550         = {cat = GiftCategory.FloorSWEP, name = "SG-550",          id = "weapon_ttt_sg550",         an=true,  random=true, rarity=1, quality=0,   type = GunType.Rifle},
    shotgun       = {cat = GiftCategory.FloorSWEP, name = "Shotgun",         id = "weapon_zm_shotgun",        an=false, random=true, rarity=1, quality=0,   type = GunType.Shotgun},
    silent_awp    = {cat = GiftCategory.WorldSWEP, name = "Silenced AWP",    id = "weapon_ttt_awp",           an=false, random=false,                       type = GunType.Rifle,   silenced = true},
    silent_m4a1   = {cat = GiftCategory.WorldSWEP, name = "Silenced M4A1",   id = "weapon_ttt_silm4a1",       an=false, random=false,                       type = GunType.Other,   silenced = true},
    silent_pistol = {cat = GiftCategory.WorldSWEP, name = "Silenced Pistol", id = "weapon_ttt_sipistol",      an=false, random=false,                       type = GunType.Pistol,  silenced = true},
    silent_smg    = {cat = GiftCategory.FloorSWEP, name = "Silent Fox",      id = "weapon_ttt_tmp_s",         an=false, random=true, rarity=5, quality=3,   type = GunType.Other,   silenced = true, smell = GiftSmell.Fur},
    striker       = {cat = GiftCategory.WorldSWEP, name = "Striker-12",      id = "weapon_sp_striker",        an=false, random=true, rarity=5, quality=3,   type = GunType.Other},
    tec9          = {cat = GiftCategory.FloorSWEP, name = "TEC-9",           id = "weapon_ap_tec9",           an=false, random=true, rarity=1, quality=3,   type = GunType.Other,   feel = GiftFeel.Meta},
    thompson      = {cat = GiftCategory.FloorSWEP, name = "1928 Thompson",   id = "weapon_ttt_milk_tommygun", an=false, random=true, rarity=1, quality=0,   type = GunType.Other,   smell = GiftSmell.Woody},
    tmp           = {cat = GiftCategory.FloorSWEP, name = "TMP",             id = "weapon_ttt_tmp",           an=false, random=true, rarity=1, quality=2,   type = GunType.Other,   feel = GiftFeel.Muffled},
    typhon        = {cat = GiftCategory.WorldSWEP, name = "'TYHPHON' AMR",   id = "weapon_ttt_typhon",        an=false, random=false,                       type = GunType.Rifle,   feel = GiftFeel.Powerful},
    us_dmr        = {cat = GiftCategory.FloorSWEP, name = "U.S DMR",         id = "weapon_ttt_m14",           an=false, random=true, rarity=1, quality=1,   type = GunType.Shotgun}, --shhh
    ump_prototype = {cat = GiftCategory.WorldSWEP, name = "UMP Prototype",   id = "weapon_ttt_stungun",       an=false, random=true, rarity=8, quality=7, type = GunType.Other,     sound = GiftSound.Whirring, feel = GiftFeel.Electric},
    usp           = {cat = GiftCategory.FloorSWEP, name = "USP",             id = "weapon_ttt_pistol",        an=false, random=true, rarity=1, quality=0,   type = GunType.Pistol},
    winchester    = {cat = GiftCategory.FloorSWEP, name = "Winchester 1873", id = "weapon_sp_winchester",     an=false, random=true, rarity=1, quality=1,   type = GunType.Shotgun, sound = GiftSound.Wooden, smell = GiftSmell.Dusty},
}

for label, data in pairs(standardGuns) do
    local SWEPSound = data.sound or (data.silenced and GiftSound.Muffled or GiftSound.Metallic)
    local SWEPSmell = data.smell or GiftSmell.Gunpowder

    local isLong  = (data.type == GunType.Rifle or data.type == GunType.Shotgun)
    local isSmall = (data.type == GunType.Pistol)
    
    local SWEPFeel = data.feel
    if not SWEPFeel then
        if isLong then
            SWEPFeel = GiftFeel.Long
        elseif isSmall then
            SWEPFeel = GiftFeel.Light
        else
            SWEPFeel = GiftFeel.Cold
        end
    end

    local SWEPSize  = data.size
    if not SWEPSize then
        if isLong then
            SWEPSize = GiftSize.Big
        elseif isSmall then
            SWEPSize = GiftSize.Small
        else
            SWEPSize = GiftSize.Large
        end
    end

    UpdateCatalog(label, GiftData.New {
        name     = data.name, desc       = (data.an and "an " or "a ")..data.name,
        category = data.cat,  identifier = data.id,
        can_be_random_gift = data.random,
        factor_rarity  = data.random and data.rarity  or nil,
        factor_quality = data.random and data.quality or nil,
        attrib_sound = SWEPSound, attrib_size = SWEPSize,
        attrib_smell = SWEPSmell, attrib_feel = SWEPFeel,
    })

    --TODO: some standard guns don't use this system only because I couldn't set shake attributes before (ie minigun floor sweps, catgun), bring em here
end


-- to populate the list with SWEPs that also have a SENT tied to them (cf. ADS, which should be using this)
local deployableSWEPs = {
    baron_hat = GiftData.New {name = "Baron Hat", desc = "a bougie hat",
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
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Larger, -- (todo check if it comes back)
               sound = GiftSound.Metallic, smell = GiftSmell.Gunpowder, feel = GiftFeel.Electric},

    c4      = {name = "C4", desc = "a bomb",
               SENT_id = "ttt_c4", SWEP_id = "weapon_ttt_c4",
               SENT_setup = "grenade", SENT_setup_var = {k = "explosion_delay", v = 10}, --TODO throws Lua errors
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

    conc_mine = {name = "Concussion Mine", desc = "a powerful whoopie cushion",
               SENT_id = "ttt_conmine", SWEP_id = "weapon_ttt_concussionmine",
               SENT_random = false, SWEP_random = false, --TODO add
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
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini, -- (todo check if it comes back)
               sound = GiftSound.Glass, smell = GiftSmell.Mineral, feel = GiftFeel.Random},

    decoy   = {name = "Decoy",        desc = "a high-tech decoy",
               SENT_id = "ttt_decoy", SWEP_id = "weapon_ttt_decoy",
               SWEP_setup_var = {k = "worldmodel_fix"},
               SENT_random = false,   SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whirring, smell = GiftSmell.Sterile, feel = GiftFeel.Electric},

    force_shield = {name = "Deployable Force Shield", desc = "a next-gen force shield",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "shield_deployer", SWEP_id = "weapon_ttt_force_shield",
               SENT_setup = "shield_deployer_setup",
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Pulsing, smell = GiftSmell.Strange, feel = GiftFeel.Bright},

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
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,  -- (todo check if it comes back)
               sound = GiftSound.Pulsing, smell = GiftSmell.Nondescript, feel = GiftFeel.Electric},

    fan     = {name = "Fan", desc = "a powerful fan",
               SENT_id = "ent_ttt_fan", SWEP_id = "weapon_fan",
               SENT_setup = "fan_setup", SENT_setup_var = {{k = "ambush_giftee"}, {k = "ambush_angle", v = -90}, {k = "ambush_yoff", v = 18}},
               SENT_random = true, SENT_rarity = 3, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whirring, smell = GiftSmell.Dusty, feel = GiftFeel.Moving},

    flashbang = {name = "Flashbang", desc = "a 5-second blinding stew",
               SENT_id = "ttt_thrownflashbang", SWEP_id = "weapon_ttt_flashbang",
               SENT_setup = "grenade_auto", SENT_setup_var = {k = "explosion_delay", v = 2},
               SENT_random = true, SENT_rarity = 4, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Metallic, smell = GiftSmell.Food, feel = GiftFeel.Bright,
               SWEP_desc = "a flashbang"},

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
               SENT_setup_var = {k = "mv_hook", v = "TTT_GiftWrap_MarkerVision"},
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
               SENT_setup = "grenade", --todo fix stuff remaining active on wrap
               SENT_random = true, SENT_rarity = 4, SENT_quality = -5,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Musical, smell = GiftSmell.Nondescript, feel = GiftFeel.Bright},

    health_station = {name = "Health Station", desc = "a healing microwave",
               SENT_id = "ttt_health_station", SWEP_id = "weapon_ttt_health_station",
               SENT_random = true, SENT_rarity = 5, SENT_quality = 9,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Huge,
               sound = GiftSound.Beeping, smell = GiftSmell.Nice, feel = GiftFeel.Warm},

    hwapoon = GiftData.New {name = "Hwapoon", desc = "a harpoon", 
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_setup_var = {k = "set_owner"}, --TODO DOUBLE CHECK WRAPPING THE ENT WORKS
               SENT_id = "hwapoon_arrow", SWEP_id = "weapon_ttt_hwapoon",
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Gigantic, SWEP_size = GiftSize.Gigantic,
               sound = GiftSound.Metallic, smell = GiftSmell.Rusty, feel = GiftFeel.Long},

    ice_grenade = {name = "Ice Grenade", desc = "an explosive snowball",
               SENT_id = "icegrenade_proj", SWEP_id = "icegrenade", -- todo fix remaining active on wrap
               SENT_setup_var = {k = "set_owner"},
               SENT_random = true, SENT_rarity = 5, SENT_quality = -5,
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

    killer_bungers = {name = "Bunger Grenade", desc = "a bunch of friendly Bungers",
               SENT_id = "ttt_bungernade_proj", SWEP_id = "weapon_ttt_bungernade",
               SENT_setup = "grenade", --TODO fix not being able to wrap sent nade
               SENT_random = true, SENT_rarity = 5, SENT_quality = -8,
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
               SENT_id = "item_lethal_company_landmine", SWEP_id = "weapon_ttt_lethalmine",
               SENT_setup_var = {{k = "stick_to_ground"}, {k = "move_to_giftee"}}, --TODO fix: magnetoable, slides off slanted ground (not properly ground-stuck)
               SENT_random = true, SENT_rarity = 10, SENT_quality = -10,
               SWEP_random = false,
               SENT_size = GiftSize.Big, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Beeping, smell = GiftSmell.Gunpowder, feel = GiftFeel.Round},

    m4_slam  = {name = "M4 Slam", desc = "a SLAM",
               SENT_id = "ttt_slam_satchel", SWEP_id = "weapon_ttt_slam",
               SENT_setup = "slam_setup",
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
               SENT_setup = "moon_grenade_setup",
               SENT_random = true, SENT_rarity = 2, SENT_quality = -3,
               SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Springy, smell = GiftSmell.Mineral, feel = GiftFeel.Otherworldly},

    paper_plane = {name = "Paper Plane", desc = "an origami plane",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ttt_paper_plane_proj", SWEP_id = "weapon_ttt_paper_plane",
               SENT_setup_var = {k = "set_thrower"},
               SENT_random = false, SWEP_random = false, --todo fix targetting & make SENT wrappabble
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Larger,
               sound = GiftSound.Whooshing, smell = GiftSmell.Paper, feel = GiftFeel.Moving},

    poison_station = {name = "Poison Station", desc = "a healing microwave",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ttt_poison_station", SWEP_id = "weapon_ttt_poison_station",
               SENT_setup_var = {k = "set_thrower"},
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
               SENT_random = true, SENT_rarity = 5, SENT_quality = 10,
               SWEP_random = false,
               SENT_size = GiftSize.Big, SWEP_size = GiftSize.Big,
               sound = GiftSound.Glass, smell = GiftSmell.Earthy, feel = GiftFeel.Cursed},

    radio   = {name = "Radio", desc = "a toy radio",
               SENT_id = "ttt_radio", SWEP_id = "weapon_ttt_radio",
               SENT_setup_var = {k = "set_thrower"},
               SWEP_setup_var = {k = "worldmodel_fix"},
               SENT_random = true, SENT_rarity = 1, SENT_quality = 2,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Musical, smell = GiftSmell.Sterile, feel = GiftFeel.Electric},

    ragnana = {name = "Ragnana",           desc = "an old banana peel",
               SENT_id = "ttt_ragnana_peel", SWEP_id = "ttt_ragnana",
               SENT_random = false, --SENT_rarity = 4, SENT_quality = -9,
               SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal, -- (todo check if it comes back)
               sound = GiftSound.Squishy, smell = GiftSmell.Rotten, feel = GiftFeel.Slippery,
               SWEP_desc = "an extremely slippery banana"},

    rcxd    = {name = "RCXD",         desc = "an RC car toy",
               SENT_id = "sent_rcxd", SWEP_id = "weapon_ttt_rcxd",
               --SENT_setup_var = {k = "set_owner"}, -- doesn't work (would need to give SWEP); TODO make harmless version to give innos
               SENT_random = false, --SENT_rarity = 2, SENT_quality = 5,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large, -- (todo check if it comes back)
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

    seekgull = {name = "Seekgull in a Can", desc = "a seagull in a can", --TODO: fix trail showing up connecting wrap spot to unwrap spot? (also happens with chomik)
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
               SENT_setup_var = {{k = "move_to_giftee"}, {k = "stick_to_ground"}, {k = "set_thrower"}},
               SENT_random = true, SENT_rarity = 0.8, SENT_quality = -3,
               SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Goopy, smell = GiftSmell.Nice, feel = GiftFeel.Slippery},

    spring_mine = {name = "Spring Mine", desc = "a comically large spring",
               SENT_id = "ttt_springmine", SWEP_id = "weapon_ttt_springmine",
               SENT_setup_var = {{k = "stick_to_ground"}, {k = "set_thrower"}},
               SENT_random = true, SENT_rarity = 5, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Springy, smell = GiftSmell.Rubbery, feel = GiftFeel.Round},

    --star_burster = {name = "Star Burster", desc = "a cosmic magical ball", --TODO fix SWEP drops having fucked ammo count on client
    --           SENT_id = "plasma_burster_nade", SWEP_id = "ttt_plasma_burster_nade",
    --           --SWEP_setup = "star_burster_setup",
    --           --SENT_setup_var = {{k = "stick_to_ground"}, {k = "set_thrower"}},
    --           --SWEP_setup_var = {{k = "set_owner"}},
    --           SENT_random = false,
    --           SWEP_random = false,
    --           SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Normal,
    --           sound = GiftSound.Whooshing, smell = GiftSmell.Strange, feel = GiftFeel.Magical,
    --           SWEP_desc = "cosmic magical balls"},

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
               SENT_setup = "grenade", -- TODO test wrapping existing one midair (SOMEHOW)
               SENT_setup_var = {{k = "up_vel", v = 1000}, {k = "up_min", v = 1}, {k = "up_max", v = 4}},
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
               SENT_setup_var = {{k = "stick_to_ground"}}, --TODO fix angle not applying
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 9, SWEP_quality = 6,
               SENT_size = GiftSize.Big, SWEP_size = GiftSize.Big,
               sound = GiftSound.Metallic, smell = GiftSmell.Dusty, feel = GiftFeel.Sus,
               SWEP_desc = "the gift of venting"},

    zombie_ball = {name = "Zombie Ball", desc = "a pile of rotting flesh",
               SENT_id = "ttt_zombieball_proj", SWEP_id = "weapon_ttt_zombieball",
               SENT_random = false, --SENT_rarity = 6, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large, -- (todo check if it comes back)
               sound = GiftSound.Talking, smell = GiftSmell.Rotten, feel = GiftFeel.Round,
               SWEP_desc = "a necromancy kit"},

}

for label, data in pairs(deployableSWEPs) do
    -- add SENT entry
    local SENTName     = data.SENT_name or "Live "..data.name
    local SENTCategory = data.SENT_category or GiftCategory.SENT

    UpdateCatalog(label, GiftData.New {
        name     = SENTName,     desc       = data.desc,
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
    local SWEPDesc  = data.SWEP_desc or data.desc
    local SWEPSmell = data.SWEP_smell or data.smell

    UpdateCatalog(label.."_item", GiftData.New {
        name     = data.name,     desc       = SWEPDesc,
        category = SWEPCategory,  identifier = data.SWEP_id,
        can_be_random_gift = data.SWEP_random,
        factor_rarity  = data.SWEP_random and data.SWEP_rarity or nil,
        factor_quality = data.SWEP_random and data.SWEP_quality or nil,
        attrib_sound = data.sound, attrib_size = data.SWEP_size or GiftSize.Small,
        attrib_smell = SWEPSmell,  attrib_feel = data.feel,
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
        if self.attrib_sound then
            return "It sounds "..qualifier, self.attrib_sound.desc, "..."
        else
            return noSound[math.random(#noSound)], "", ""
        end

    elseif self.lastCheckType == 1 then -- smell
        if self.attrib_smell then
            return "It smells "..qualifier, self.attrib_smell, "..."
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

function GiftData:IsSpawnable(giftee)
    local gifteeAlive = utils.IsLivingPlayer(giftee)

    if self.unless_has_item and gifteeAlive
      and giftee:HasEquipmentItem(self.unless_has_item)
        then return false end

    if self.special_setup then
        if self.special_setup == "snuffles_present_setup"
          and utils.RoundStartTime and CurTime() <= utils.RoundStartTime + 10 then
            return false

        elseif self.special_setup == "pap_setup" then
            local foundCrowbar = false

            for _, wep in ipairs(giftee:GetWeapons()) do
                if IsValid(wep) and wep:GetClass() == "weapon_zm_improvised" then
                    if wep.PAPUpgrade ~= nil then
                        return false
                    else
                        foundCrowbar = true
                        break
                    end
                end
            end

            if not foundCrowbar then return false end
        end
    end

    local category   = self.category
    local identifier = self.identifier

    if category == GiftCategory.PhysProp or category == GiftCategory.Vehicle then
        return util.IsValidModel(identifier)

    elseif category == GiftCategory.SENT or category == GiftCategory.Ammo then
        return scripted_ents.GetStored(identifier) ~= nil

    elseif category == GiftCategory.NPC then
        return list.Get("NPC")[identifier] ~= nil

    elseif category == GiftCategory.WorldSWEP
      or category == GiftCategory.FloorSWEP then
        return weapons.GetStored(identifier) ~= nil

    elseif category == GiftCategory.AutoEquipSWEP then
        return gifteeAlive and weapons.GetStored(identifier) ~= nil
          and not giftee:HasWeapon(identifier)
          and giftee:CanCarryType(WEPS.TypeForWeapon(identifier))

    elseif category == GiftCategory.Item then
        return gifteeAlive and items.GetStored(identifier) ~= nil
          and (self.can_get_multiple or not giftee:HasEquipmentItem(self.identifier))
    end

    return false
end

function GiftData:IsDropBlocked()
    return self.category == GiftCategory.SENT
      or self.category == GiftCategory.NPC
      --or self.category == GiftCategory.Vehicle
      or self.category == GiftCategory.Unknown
end

function GiftData:ApplyOnWrapAdjustments(wrappedEnt, giftObj)
    if self.break_constraints then
        constraint.RemoveAll(wrappedEnt)
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
        end
    end

    if wrappedEnt:IsOnFire() then
        wrappedEnt:Extinguish()
        giftObj:SetIsContentsOnFire(true)
    end
end

function GiftData:ApplyOnAutoWrapAdjustments(giftObj)
    if self.special_setup == "explo_barrel_setup" then
        if math.random() < 0.6 then
            giftObj:SetIsContentsOnFire(true)
        end
    end
end

function GiftData:ApplyPreSpawnAdjustments(wrappedEnt, giftee)
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
        wrappedEnt.FixInternalSeats = true

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
             -- required to have its final position set properly before being spawned/activated
            wrappedEnt:SetPos(giftee:GetPos() + Vector(0, 0, 100))

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
            -- note: copied from pap's OrderedEquipment hook (i would've called it directly,
            --       but I need to know the old numeric ID EQUIP_PAP which somehow becomes nil over the namespace
            giftee:SelectWeapon("weapon_zm_improvised")
            TTTPAP:OrderPAP(giftee, true)

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
        end
    end
end

function GiftData:ApplyPostUnwrapAdjustments(wrappedEnt, giftee, giftObj, isUndo)
    if self.move_to_giftee then
        local curMoveType = wrappedEnt:GetMoveType()
        wrappedEnt:SetMoveType(MOVETYPE_VPHYSICS)
        wrappedEnt:SetPos(giftee:GetPos())
        wrappedEnt:SetMoveType(curMoveType)
    end

    if self.stick_to_ground and not wrappedEnt:IsOnGround() then
        local groundTr = utils.GetGroundHit(utils.GetEntCenter(wrappedEnt), wrappedEnt)

        if groundTr.Hit then
            wrappedEnt:SetPos(groundTr.HitPos)
            wrappedEnt:SetAngles(groundTr.HitNormal:Angle() + Angle(90, 0, 0))
            if wrappedEnt.WeldToSurface then wrappedEnt:WeldToSurface(true) end
            wrappedEnt:SetMoveType(MOVETYPE_NONE)
            wrappedEnt:GetPhysicsObject():AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
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
            wrappedEnt:SetPos(giftee:GetPos() + Vector(0, 0, 100))
            wrappedEnt:SetDamageOwner(giftee)
            wrappedEnt:Activate()
            wrappedEnt:SetHealth(30)
            giftee:ChatPrint("NOTE: You CAN shoot it to escape!")

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
        end
    end

    if self.up_vel then
        local upMin = self.up_min or 10
        local upMax = self.up_max or upMin
        local upAmt = math.Rand(upMin, upMax)

        local phys = wrappedEnt:GetPhysicsObject()
        phys:SetVelocity(utils.GetRandomUpwardsVel(upAmt) * self.up_vel)

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

function GiftData:GetName(giftee)
    if self.special_setup == "poison_station_desc" then
        if PS2_Utils and PS2_Utils.IsMainEvil(giftee) then
            return "Live Poison Station"
        else
            return "Live Health Station"
        end
    end

    return self.name
end

function GiftData:GetDesc(wrappedEnt, giftee)
    if self.special_setup then
        if self.special_setup == "giftwrap_desc" then
            if wrappedEnt.HasGift and wrappedEnt:HasGift() then
                return "another gift"
            else
                return "more wrapping paper"
            end

        elseif self.special_setup == "sopd_setup" then
            if giftee:SteamID64() == swordTarget.SID64 then
                return "a sword meant just for you"
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
        end
    end

    return self.desc
end

function GiftData:Spawn(giftee)
    if self:IsSpawnable(giftee) then
        local category   = self.category
        local identifier = self.identifier

        -- PhysProp / Vehicle
        if category == GiftCategory.PhysProp or category == GiftCategory.Vehicle then
            local giftEnt = ents.Create(self.entity_class or "prop_physics")

            giftEnt:SetModel(identifier)
            self:ApplyPreSpawnAdjustments(giftEnt, giftee)
            giftEnt:Spawn()

            local phys = giftEnt:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
                phys:Sleep()
            end

            return giftEnt

        -- SENT / NPC / FloorSWEP / WorldSWEP / Ammo
        elseif category == GiftCategory.SENT or category == GiftCategory.NPC or category == GiftCategory.Ammo
          or category == GiftCategory.WorldSWEP or category == GiftCategory.FloorSWEP then
            local giftEnt = ents.Create(identifier)

            self:ApplyPreSpawnAdjustments(giftEnt, giftee)
            giftEnt:Spawn()

            return giftEnt

        elseif category == GiftCategory.AutoEquipSWEP then -- AutoEquipSWEP
            giftee:Give(identifier)
            giftee:SelectWeapon(identifier)

        elseif category == GiftCategory.Item then -- Item
            self:ApplyPreSpawnAdjustments(nil, giftee)
            giftee:GiveEquipmentItem(identifier)

            -- apply perk (blocked when buying for gift)
            if self.special_setup == "perk_bottle" then
                items.GetStored(identifier):Bought(giftee)
            end
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
        breakdown[label.."_spawnable"] = giftData:IsSpawnable(LocalPlayer())
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
    function GiftData:GetVisuals()
        local category = self.category

        if category == GiftCategory.PhysProp or category == GiftCategory.Vehicle then
            return self.identifier

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

                hook.Add("TTT2RenderMarkerVisionInfo", giftData.mv_hook, function(mvData)
                    local ent = mvData:GetEntity()

                    if not ent._HideMarks then
                        ogHook(mvData)
                    else
                        mvData.drawInfo = false
                    end
                end)
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
    ["wood"]     = {sound=GiftSound.Wooden,   smell=GiftSmell.Woody,   feel=GiftFeel.Sturdy},
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
    ["pottery"]             = {sound=GiftSound.Thudding,   smell=GiftSmell.Paint,     feel=GiftFeel.Hollow},
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

function GetEntGiftData(ent)
    local entIdentifier = ent:GetClass()
    local entModel = ent:GetModel()

    if string.find(entIdentifier, "prop_physics", nil, true)
      or string.StartsWith(entIdentifier, "prop_vehicle")
      or entIdentifier == "func_physbox" then
        entIdentifier = entModel
    end

    for label, giftData in pairs(giftDataCatalog) do
        if giftData.identifier == entIdentifier then
            return label, giftData
        end
    end

    -- Generating placeholder data from entity attributes
    dbg.Log("Could not find gift data for "..tostring(ent).."; generating placeholder...")
    dbg.Log("=> Model path: ", entModel)
    local placeholderData = GiftData.New({})
    local placeholderLabel = "gift_ent_"..tostring(ent:EntIndex())
    placeholderData.identifier = entIdentifier

    placeholderData.autoGen = true
    if weapons.GetStored(entIdentifier) or items.GetStored(entIdentifier) then
        placeholderData.placeholderEquip = true
    end

    -- Detect category
    if entIdentifier == entModel then
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
    local name = "gift"

    if ent.PrintName and ent.PrintName ~= "" then
        name = ent.PrintName

    elseif ent.GetName then
        local entName = ent:GetName()

        if entName and entName ~= "" then
            name = entName
        end
    end

    if name == "gift" then
        placeholderData.name = string.match(string.StripExtension(entModel), "[^/\\]+$")
        placeholderData.desc = "a " .. name

    else
        placeholderData.name = name:gsub("^%l", string.upper)
        placeholderData.desc = "a " .. placeholderData.name
    end

    -- Set sound/smell/feel from material
    placeholderData.attrib_sound = GiftSound.None
    placeholderData.attrib_smell = GiftSmell.Nondescript
    placeholderData.attrib_feel  = GiftFeel.Indescribable

    local phys = ent:GetPhysicsObject()
    local surfacePropName = utils.GetEntSurfaceProp(ent, phys)
    dbg.Log("Found surface prop name:", surfacePropName)

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

local VDFIX_ENABLE      = utils.Cvar("ttt2_vehicle_damagefix_enable", 1, 0, 1, "Whether to enable the fix for vehicle drivers/passengers being invincible.")
local VDFIX_MULT_DRIVER = utils.Cvar("ttt2_vehicle_damagefix_driver_mult", 30, 0, 100, "Damage multiplier for driver when hitting other parts of vehicle (%).")
local VDFIX_MULT_PASNGR = utils.Cvar("ttt2_vehicle_damagefix_passenger_mult", 20, 0, 100, "Damage multiplier for passengers when hitting any part of vehicle (%).")


hook.Add("Initialize", INIT_FIXES_HOOK, function()
    -- Fix for invisible clutterbombs continuing their warning light effect
    hook.Remove("PreRender", "ClutterbombProj_DynamicLight")
    hook.Remove("PreRender", "RClutterbombProj_DynamicLight")

    -- same code, just made common for both addons & checking NoDraw
    hook.Add("PreRender", CLUTTERBOMB_LIGHT_FIX_HOOK, function()
        local clutterbombs = ents.FindByClass("ttt_clutterbomb_proj")
        table.Add(clutterbombs, ents.FindByClass("ttt_rclutterbomb_proj"))

        for _, ent in pairs(clutterbombs) do
            local dlight = DynamicLight(ent:EntIndex())

            if dlight and not ent:GetNoDraw() then
                dlight.pos = ent:GetPos()
                dlight.r = 255
                dlight.g = 111
                dlight.b = 0
                dlight.brightness = 4
                dlight.Decay = 258
                dlight.Size = 258
                dlight.DieTime = CurTime() + 0.1
                dlight.Style = 4
            end
        end
    end)

    -- Fix for Pot of Greedier not defaulting to Detective shop for non-shopping role pots
    if PotOfGreedier then
        PotOfGreedier._OGGetEquipmentFunc = PotOfGreedier._OGGetEquipmentFunc or PotOfGreedier.GetEquipmentServerSided
        --PotOfGreedier.GetEquipmentServerSided = PotOfGreedier._OGGetEquipmentFunc --restore

        PotOfGreedier.GetEquipmentServerSided = function(ply, subRole, noModification)
            local subRoleData = utils.GetSubRoleData(subRole)

            if not subRoleData or not subRoleData:IsShoppingRole() then
                return PotOfGreedier._OGGetEquipmentFunc(ply, ROLE_DETECTIVE, noModification)
            else
                return PotOfGreedier._OGGetEquipmentFunc(ply, subRole, noModification)
            end
        end
    end

    -- Change perk bottle item Bought functions to prevent effects happening
    -- before we can intercept them (if buying for gift)
    if SERVER then
        for label, _ in pairs(perks) do
            local perkItem = items.GetStored("item_ttt_"..label)

            if perkItem then
                local ogBoughtFunc = perkItem.Bought

                perkItem.Bought = function(self, ply)
                    if not ply._gwInOptMenu then
                        ogBoughtFunc(self, ply)
                    end
                end
            end
        end
    end

    -- Fix seats inside of vehicles being inaccessible even if main seat occupied (opt-in)
    hook.Add("PlayerUse", PLAYER_USE_HOOK, function(ply, ent)
        if IsValid(ent) and ent:IsVehicle() and ent.FixInternalSeats and IsValid(ent:GetDriver()) then
            local eyePos = ply:EyePos()

            local tr = util.TraceLine({
                start  = eyePos,
                endpos = eyePos + ply:EyeAngles():Forward() * 80,
                filter = function(ent)
                    return (IsValid(ent) and ent:IsVehicle() and not ent.FixInternalSeats)
                end
            })

            if IsValid(tr.Entity) then
                --ply:EnterVehicle(tr.Entity) --instant
                tr.Entity:Use(ply)
            end
        end
    end)

    -- Fix driver taking almost no damage & other riders being invincible
    hook.Add("EntityTakeDamage", ENT_TAKE_DAMAGE_HOOK, function(target, dmgInfo)
        if not VDFIX_ENABLE:GetBool() then return end
        local dmg = dmgInfo:GetDamage()

        if IsValid(target) and target:IsVehicle() then
            if dmg < 0.01 then
                dmg = math.floor(dmg * 10000 + 0.5)
                dmgInfo:SetDamage(dmg * VDFIX_MULT_DRIVER:GetFloat()/100)

                local driver = target:GetDriver()
                if IsValid(driver) then
                    dbg.Log("Corrected near-zero damage for driver", driver, dmgInfo)
                end
            end

            -- apply damage to passenger seats (one layer down)
            for _, child in ipairs(target:GetChildren()) do
                if IsValid(child) and child:IsVehicle() then
                    local seatDmg = DamageInfo()
                    seatDmg:SetDamage(dmg * VDFIX_MULT_PASNGR:GetFloat()/100)
                    seatDmg:SetAttacker(dmgInfo:GetAttacker())
                    child:TakeDamageInfo(seatDmg)

                    local seatPsgr = child:GetDriver()
                    if IsValid(seatPsgr) then
                        dbg.Log("Applied damage to passenger", seatPsgr, seatDmg)
                    end
                end
            end
        end
    end)

    -- Extend Killer Bungers damage method to conditionally disable damage
    if SERVER and TurtleNadeDamage then
        hook.Add("EntityTakeDamage", "TurtlenadeDmgHandle", function(victim, dmg)
            local attacker = dmg:GetAttacker()

            if attacker:IsValid() and attacker:GetNWBool("GWFriendlyBunger") then
                TurtleInnocentDamage = 0
                TurtleTraitorDamage  = 0

            elseif victim:IsValid() and victim:GetNWBool("GWFriendlyBunger") then
                if dmg:GetInflictor():GetClass() == "weapon_zm_improvised" then
                    dmg:SetInflictor(game.GetWorld())
                end

                local bunger = utils.GetEntChildAt(victim, 1)

                if IsValid(bunger) then
                    local hat = utils.GetEntChildAt(bunger, 1)

                    if IsValid(hat) then
                        local oldHealth = victim:Health() - 980
                        local newHealth = oldHealth - dmg:GetDamage()
                        local maxHealth = victim:GetMaxHealth() - 980

                        if oldHealth > maxHealth*0.75 and newHealth <= maxHealth*0.75 then
                            hat:SetSequence("spin_fast")
                            hat:ResetSequence("spin_fast")

                        elseif oldHealth > maxHealth*0.5 and newHealth <= maxHealth*0.5 then
                            hat:SetSequence("spin_med")
                            hat:ResetSequence("spin_med")

                        elseif oldHealth > maxHealth*0.25 and newHealth <= maxHealth*0.25 then
                            hat:SetSequence("spin_slow")
                            hat:ResetSequence("spin_slow")
                        end
                    end
                end
            end

            TurtleNadeDamage(victim, dmg)
            TurtleInnocentDamage = 20 -- defaults
            TurtleTraitorDamage  = 5
        end)
    end

    if SERVER then
        -- Disable manhack right click while it's in the giftbox
        local manhackWep = weapons.GetStored("weapon_controllable_manhack")

        if manhackWep then
            local OGManhackSecondary = manhackWep.SecondaryAttack

            manhackWep.SecondaryAttack = function(slf)
                local manhack = slf:GetSpawnedManhack()

                if IsValid(manhack) then
                    if not IsValid(manhack:GetNWEntity("WrappedByGift")) then
                        OGManhackSecondary(slf)
                    else
                        utils.NonSpamMessage(slf:GetOwner(), "wrapped_manhack", "Sorry, your manhack is wrapped inside a giftbox.")
                    end
                end
            end
        end

        -- Explode giftbox when self-desturcting
        local manhackSENT = scripted_ents.GetStored("sent_controllable_manhack")

        if manhackSENT then
            manhackSENT = manhackSENT.t
            local OGManhackSelfDestruct = manhackSENT.SelfDestruct

            manhackSENT.SelfDestruct = function(self)
                local parentGift = self:GetNWEntity("WrappedByGift")

                if IsValid(parentGift) then
                    if self.isSelfDestructing then return end
                    self.isSelfDestructing = true

                    local giftee = parentGift:GetOwner()
                    if IsValid(giftee) then
                        giftee:EmitSound(self.SoundStunned)
                        giftee:ChatPrint("Your gift is beeping!")
                    else
                        parentGift:EmitSound(self.SoundStunned)
                    end

                    timer.Simple(3, function()
                        if not IsValid(self) then return end
                        parentGift = self:GetNWEntity("WrappedByGift")

                        if IsValid(parentGift) then
                            local explode = ents.Create("env_explosion")
                            explode:SetPos(utils.GetEntCenter(parentGift))
                            explode:SetOwner(self:GetPlayerController())
                            explode:Spawn()
                            explode:SetKeyValue("iMagnitude", self.ExplosionSize)
                            explode:Fire("Explode", 0, 0)
                            parentGift:Remove()

                        else
                            self:Remove()
                        end
                    end)

                else
                    OGManhackSelfDestruct(self)
                end
            end
        end
    end

    -- Green demon fixes
    local sent_greendemon = scripted_ents.GetStored("sent_greendemon")

    if sent_greendemon then
        -- Make visible z coordinate of Green Demon SENT more intuitively match hitbox
        sent_greendemon = sent_greendemon.t
        sent_greendemon.SparkleHeightOffset = 4

        if CLIENT then
            local OGGreenDemonDraw = sent_greendemon.DrawTortuga

            sent_greendemon.DrawTortuga = function(self)
                local ogPos = self:GetPos()
                self:SetPos(ogPos - Vector(0, 0, 8))
                OGGreenDemonDraw(self)
                self:SetPos(ogPos)
            end
        end
    end
end)


if SERVER then
    local initTotalWeight, initGiftCount = GetTotalWeight()
    dbg.Log("Gift data loaded ("..initGiftCount.." gifts, totalling "..initTotalWeight.." weight).")
    --dbg.Inspect(GetCategoryWeightBreakdown())

    -- precache prop/vehicle models (can add other types if needed)
    for label, data in pairs(giftDataCatalog) do
        if data.category == GiftCategory.PhysProp or data.category == GiftCategory.Vehicle then
            util.PrecacheModel(data.identifier)
        end
    end
end