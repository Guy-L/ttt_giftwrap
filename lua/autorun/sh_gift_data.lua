include("sh_giftwrap_utils.lua")
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

local PLACEHOLDER_DATA_REMOVE    = "GiftWrap_RemovePlaceholderGiftData"
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
    PhysProp      = {id=1,  text="Prop",           icon="vgui/ttt/menu/icon_box",      weight=PROP_WEIGHT_NAME,    paper=5},
    PhysBox       = {id=2,  text="Map Prop",       icon="vgui/ttt/menu/icon_box",      weight=PROP_WEIGHT_NAME,    paper=5},
    SENT          = {id=3,  text="Special Entity", icon="vgui/ttt/menu/icon_sparkles", weight=SPECIAL_WEIGHT_NAME, paper=20},
    NPC           = {id=4,  text="NPC",            icon="vgui/ttt/menu/icon_headcrab", weight=SPECIAL_WEIGHT_NAME, paper=30},
    FloorSWEP     = {id=5,  text="Floor Weapon",   icon="vgui/ttt/menu/icon_gun",      weight=FLOOR_WEIGHT_NAME,   paper=1},
    WorldSWEP     = {id=6,  text="Shop Weapon",    icon="vgui/ttt/menu/icon_knife",    weight=SHOP_WEIGHT_NAME,    paper=15},
    AutoEquipSWEP = {id=7,  text="Shop Weapon",    icon="vgui/ttt/menu/icon_knife",    weight=SHOP_WEIGHT_NAME,    paper=nil},
    Item          = {id=8,  text="Shop Item",      icon="vgui/ttt/menu/icon_bottle",   weight=SHOP_WEIGHT_NAME,    paper=nil},
    Ammo          = {id=9,  text="Ammo Box",       icon="vgui/ttt/menu/icon_ammo",     weight=FLOOR_WEIGHT_NAME,   paper=1},
    Vehicle       = {id=10, text="Vehicle",        icon="vgui/ttt/menu/icon_car",      weight=SPECIAL_WEIGHT_NAME, paper=50},
    Ragdoll       = {id=11, text="Ragdoll",        icon="vgui/ttt/menu/icon_ragdoll",  weight=SPECIAL_WEIGHT_NAME, paper=25},
    Unknown       = {id=12, text="Unknown",        icon="vgui/ttt/menu/icon_question", weight=SPECIAL_WEIGHT_NAME, paper=25},
}

GiftSound = {
    Squishy    = {snd="physics/flesh/flesh_squishy_impact_hard1.wav",     desc="squishy"},
    Goopy      = {snd="player/footsteps/mud3.wav",                        desc="goopy"},
    Metallic   = {snd={"physics/metal/metal_box_impact_soft1.wav","physics/metal/metal_box_impact_soft2.wav","physics/metal/metal_box_impact_soft3.wav"}, desc="metallic"},
    Glass      = {snd="physics/glass/glass_bottle_impact_hard3.wav",      desc="tinkly"},
    Creaky     = {snd={"physics/wood/wood_strain4.wav","physics/wood/wood_strain6.wav"}, desc="creaky"},
    Plastic    = {snd="physics/plastic/plastic_barrel_impact_soft1.wav",  desc="plasticky"}, -- pretty much unused
    Fleshy     = {snd="physics/flesh/flesh_squishy_impact_hard4.wav",     desc="fleshy"},
    Talking    = {desc="like it's talking", bst=-0.5, snd = {
        "vo/k_lab/al_hmm.wav", "vo/npc/alyx/hurt06.wav",
        "vo/npc/alyx/uggh01.wav", "vo/npc/male01/help01.wav",
        "vo/npc/male01/help01.wav", "vo/streetwar/alyx_gate/al_hey.wav"
    }},
    Meowing    = {snd={"giftwrap/meow1.mp3","giftwrap/meow2.mp3"}, bst=2, desc="like it's meowing"},
    Bleating   = {snd="giftwrap/bleating.mp3", bst=2,                     desc="like it's bleating"}, -- lambert only
    Mooing     = {snd="giftwrap/moo.mp3",                                 desc="like it's mooing"}, -- cow only
    Oinking    = {snd="giftwrap/oink.mp3", bst=3,                         desc="like it's oinking"}, -- pig only
    Thudding   = {snd="phx/epicmetal_hard.wav",                           desc="like it's thudding"},
    Whirring   = {snd="giftwrap/whirring.mp3", bst=6,                     desc="like it's whirring"},
    Revving    = {snd="vehicles/v8/v8_stop1.wav",                         desc="like it's revving"},
    Beeping    = {snd="buttons/blip2.wav",                                desc="like it's beeping"},
    Granular   = {snd="player/footsteps/gravel3.wav",                     desc="granular"},
    Springy    = {snd="giftwrap/boing.mp3",                               desc="springy"},
    Musical    = {snd="giftwrap/harp.mp3",                                desc="musical"},
    Squeaky    = {snd="npc/headcrab_poison/ph_idle1.wav",                 desc="squeaky"}, --new, underused
    Hollow     = {snd="physics/cardboard/cardboard_box_impact_soft6.wav", desc="hollow"},
    Clicky     = {snd="weapons/pistol/pistol_empty.wav",                  desc="clicky"}, --new, underused
    Rattling   = {snd="giftwrap/rattling.mp3", bst=2,                     desc="like it's rattling"}, --new, underused
    Hissing    = {snd="npc/headcrab_poison/ph_rattle2.wav",               desc="like it's hissing"}, --new, underused
    Ringing    = {snd="hl1/fvox/bell.wav",                                desc="like it's ringing"}, --new, underused
    Splashing  = {snd="player/footsteps/slosh2.wav",                      desc="like it's splashing"},
    Squelching = {snd="player/footsteps/mud1.wav",                        desc="like it's squelching"},
    Rustling   = {snd="player/footsteps/grass2.wav",                      desc="like it's rustling"},
    Whooshing  = {snd={"foley/eli_sit_on_couch.wav","npc/fast_zombie/claw_miss1.wav"}, desc="like it's whooshing"},
    Pulsing    = {snd="weapons/physcannon/energy_bounce1.wav",            desc="like it's pulsing"},
    Muffled    = {snd={"foley/alyx_sit_on_couch.wav","npc/zombie/foot_slide2.wav"}, desc="muffled"},
    Train      = {snd="giftwrap/choochoo.mp3",                            desc="like it's chugging along"},
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
    Bloody      = "bloody",
    Paint       = "like paint",
    Food        = "like food",
    Medicine    = "like medicine", -- new
    Woody       = "woody",
    Oily        = "oily",
    Gunpowder   = "like gunpowder",
    Ash         = "like ash",
    Fur         = "like fur",
    Paper       = "like paper",
    Cardboard   = "like cardboard",
    Caffeine    = "like caffeine",
    Alcohol     = "like alcohol",
    Cotton      = "like cotton", -- currently props only
    Wool        = "like wool", -- new, underused
    Clay        = "like clay", -- new, underused
    Leather     = "like leather",
    Nice        = "nice",
    Stinky      = "stinky",
    Mineral     = "mineral",
    Toxic       = "toxic", -- underused
    Salty       = "salty",
    Fizzy       = "fizzy",
    Earthy      = "earthy",
    Dusty       = "dusty",
    Dry         = "dry",
    Rusty       = "rusty",
    Sterile     = "sterile",
    Metallic    = "metallic", -- high overlap with Sterile
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
    Box           = "boxy",
    Fragile       = "fragile",
    Squishy       = "squishy",
    Alive         = "agitated",
    Moving        = "like it's moving", -- underused (3)
    Bursting      = "like it's bursting out", -- underused (3)
    Magical       = "magical",
    RealityWarp   = "reality-warping",
    Futuristic    = "futuristic",
    Scientific    = "scientific", -- new, underused
    Informative   = "informative", -- new, very underused
    Medieval      = "medieval", -- new, very underused
    Negative      = "negative",
    Jolly         = "jolly",
    Spooky        = "spooky",
    Cursed        = "cursed",
    Long          = "long",
    Otherworldly  = "otherworldly",
    Bright        = "bright",
    Powerful      = "powerful",
    Random        = "random",
    Slippery      = "slippery", -- possibly underused
    Special       = "special", -- currently unused, very not ideal
    Nostalgic     = "nostalgic", -- used for picture frame
    Meta          = "meta... or used to", -- used only for TEC-9 (joke)
    Sus           = "suspicious", -- used only for Wormhole-Vent (joke)
    Flat          = "flat",
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

local giftDataCatalog = {}

table.Merge(giftDataCatalog, { -- PhysProps
    argemia = GiftData.New {
        name     = "Argemia Plushie",     desc       = "an Ariral plushie",
        category = GiftCategory.PhysProp, identifier = "models/goobers/argemia/argemia_plush.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Meowing,  attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Otherworldly,
    },
    ammo_crate = GiftData.New {
        name     = "Ammo Crate",          desc       = "a large ammo crate",
        category = GiftCategory.PhysProp, identifier = "models/items/ammocrate_smg1.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rattling,  attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Box,
    },
    ammo_stack = GiftData.New {
        name     = "Ammo Crate Stack",    desc       = "a stack of ammo crates",
        category = GiftCategory.PhysProp, identifier = "models/props/de_prodigy/ammo_can_03.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding,  attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Box,
    },
    banana_bunch = GiftData.New {
        name     = "Banana Bunch",        desc       = "bananas",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_italy/bananna_bunch.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Fresh,
    },
    banana_prop = GiftData.New {
        name     = "Banana (Prop)",       desc       = "a banana",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_italy/bananna.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Fresh,
    },
    barrel = GiftData.New {
        name     = "Barrel",              desc       = "a barrel",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/oildrum001.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 4.3,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Round,
    },
    barrel_toxic = GiftData.New {
        name     = "Toxic Waste Barrel",  desc       = "nuclear waste",
        category = GiftCategory.PhysProp, identifier = "models/props/de_train/barrel.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 4.3,
        attrib_smell = GiftSmell.Toxic,    attrib_feel = GiftFeel.Round,
    },
    barricade = GiftData.New {
        name     = "Barricade",           desc       = "a barricade",
        category = GiftCategory.PhysProp, identifier = "models/props_wasteland/barricade001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Paint,  attrib_feel = GiftFeel.Sturdy,
    },
    bed_frame = GiftData.New {
        name     = "Bed Frame",           desc       = "a bed frame",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/furniturebed001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky,   attrib_size = 6,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Hollow,
    },
    bed = GiftData.New {
        name     = "Bed",                 desc       = "a bed",
        category = GiftCategory.PhysProp, identifier = "models/props/de_inferno/bed.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Cotton,  attrib_feel = GiftFeel.Flat,
    },
    beer_case = GiftData.New {
        name     = "Beer Case",           desc       = "a case of beer",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_militia/caseofbeer01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Alcohol,   attrib_feel = GiftFeel.Heavy,
    },
    bench_cafeteria = GiftData.New {
        name     = "Cafeteria Bench",     desc       = "a cafeteria bench",
        category = GiftCategory.PhysProp, identifier = "models/props_wasteland/cafeteria_bench001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Long,
    },
    bicycle = GiftData.New {
        name     = "Bicycle",             desc       = "a bicycle",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/bicycle01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Moving,
    },
    bikinibottom_bottle = GiftData.New {
        name     = "Condiment Bottle",    desc       = "a condiment bottle",
        category = GiftCategory.PhysProp, identifier = "models/props/de_bikibot/ketchup.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Soft,
        only_on_map = "ttt_bikinibottom"
    },
    bikinibottom_formula = GiftData.New {
        name     = "Secret Formula",      desc       = "the secret formula",
        category = GiftCategory.PhysProp, identifier = INVALID_ID,
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Food,  attrib_feel = GiftFeel.Special,
        only_on_map = "ttt_bikinibottom",
        adjustments = { secret_formula_detect = { is_secret = true } },
    },
    bikinibottom_key = GiftData.New {
        name     = "Secret Formula Key",  desc       = "the key",
        category = GiftCategory.PhysProp, identifier = "models/spartex117/key.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Clicky,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Special,
        only_on_map = "ttt_bikinibottom"
    },
    bikinibottom_pencil = GiftData.New {
        name     = "Doodlebob Pencil",    desc       = "the pencil",
        category = GiftCategory.PhysProp, identifier = "models/para_pen/para_pen.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Woody,   attrib_feel = GiftFeel.Powerful,
        only_on_map = "ttt_bikinibottom",
        adjustments = { up_throw = { vel = 300, min = 3, max = 4 }, },
    },
    bikinibottom_plankton = GiftData.New {
        name     = "Sheldon J. Plankton", desc       = "Plankton",
        category = GiftCategory.PhysProp, identifier = "models/spongebob/plankton/plankton.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Talking, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Salty,   attrib_feel = GiftFeel.Alive,
        only_on_map = "ttt_bikinibottom"
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
        attrib_smell = GiftSmell.Paper,   attrib_feel = GiftFeel.Informative,
    },
    boat_wreck = GiftData.New {
        name     = "Wrecked Boat",        desc        = "a wrecked boat",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_canal/boat001a.mdl",
            "models/props_canal/boat001b.mdl",
            "models/props_canal/boat002b.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Salty,  attrib_feel = GiftFeel.Sharp,
    },
    bowling_ball = GiftData.New {
        name     = "Bowling Ball",        desc       = "a bowling ball",
        category = GiftCategory.PhysProp, identifier = "models/bowling/bowling_ball.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Round,
        only_on_map = "ttt_christmas_bowling",
    },
    bowling_pin = GiftData.New {
        name     = "Bowling Pin",         desc       = "a bowling pin",
        category = GiftCategory.PhysProp, identifier = "models/bowling/bowling_pin.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Paint,   attrib_feel = GiftFeel.Sturdy,
        only_on_map = "ttt_christmas_bowling",
    },
    bread_loaf = GiftData.New {
        name     = "Bread Loaf",          desc        = "a loaf of bread",
        category = GiftCategory.PhysProp, identifiers = {
            "models/foodnhouseholditems/bread-2.mdl",
            "models/foodnhouseholditems/bread-4.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Granular, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Food,     attrib_feel = GiftFeel.Squishy,
        only_on_map = "ttt_5c_plaza",
    },
    briefcase = GiftData.New {
        name     = "Briefcase",           desc        = "a briefcase",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_c17/suitcase_passenger_physics.mdl",
            {mdl="models/props_c17/suitcase001a.mdl", size = 2.7},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Dusty,  attrib_feel = GiftFeel.Box,
    },
    briefcase_leather = GiftData.New {
        name     = "Leather Briefcase",   desc       = "a briefcase",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/briefcase001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow,  attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Leather, attrib_feel = GiftFeel.Soft,
    },
    bucket_metal = GiftData.New {
        name     = "Metal Bucket",        desc       = "a bucket",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/metalbucket01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Round,
    },
    bucket_paint = GiftData.New {
        name     = "Paint Bucket",        desc       = "a paint bucket",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_militia/paintbucket01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Paint,  attrib_feel = GiftFeel.Round,
    },
    bullet_tray = GiftData.New {
        name     = "Bullet Tray",         desc       = "a bullet tray",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_militia/reload_bullet_tray.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic,   attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Light,
    },
    bust_breen = GiftData.New {
        name     = "Bust of Dr. Breen",   desc       = "a bust",
        category = GiftCategory.PhysProp, identifier = "models/props_combine/breenbust.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Mineral,  attrib_feel = GiftFeel.Powerful,
    },
    c4_prop = GiftData.New {
        name     = "C4 (Prop)",           desc       = "a fake C4",
        category = GiftCategory.PhysProp, identifier = "models/weapons/w_c4_planted.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping,   attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Light,
    },
    cannonball_prop = GiftData.New {
        name     = "Used Cannonball",     desc       = "an inert cannonball",
        category = GiftCategory.PhysProp, identifier = "models/props_phx/misc/smallcannonball.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding,  attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Round,
    },
    can_soda = GiftData.New {
        name     = "Soda Can",            desc        = "a soda can",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_office/trash_can_p7.mdl",
            "models/props_junk/popcan01a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Fizzy,  attrib_feel = GiftFeel.Cold,
    },
    can_paint = GiftData.New {
        name     = "Paint Can",           desc       = "a paint can",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/metal_paintcan001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Paint,     attrib_feel = GiftFeel.Round,
    },
    can_spray_paint = GiftData.New {
        name     = "Spray Paint Can",     desc       = "a spray paint can",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/garbage_spraypaintcan01a.mdl", -- not global
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Paint,     attrib_feel = GiftFeel.Round,
    },
    candy_cane = GiftData.New {
        name     = "Candy Cane",          desc       = "a candy cane",
        category = GiftCategory.PhysProp, identifier = "models/christmas/candycane_tiny.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.None, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food, attrib_feel = GiftFeel.Jolly,
        only_on_map = "ttt_christmas_bowling",
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
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = 6,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Massive,
    },
    cardboard_box = GiftData.New {
        name     = "Cardboard Box",       desc        = "a cardboard box",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/props_junk/cardboard_box001a.mdl", size=4},
            {mdl="models/props_junk/cardboard_box001b.mdl", size=4},
            {mdl="models/props_junk/cardboard_box002a.mdl", size=GiftSize.Huge},
            {mdl="models/props_junk/cardboard_box002b.mdl", size=GiftSize.Huge},
            {mdl="models/props_junk/cardboard_box003b.mdl", size=3},
            {mdl="models/props_junk/cardboard_box004a.mdl", size=GiftSize.Large},
            "models/props_junk/cardboard_box003a.mdl",
            {mdl="models/props_lab/box01a.mdl", size=GiftSize.Normal},
            "models/props/cs_office/cardboard_box01.mdl",
            {mdl="models/props/cs_office/cardboard_box02.mdl", size=GiftSize.Large},
            "models/props/cs_office/cardboard_box03.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.None,      attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Cardboard, attrib_feel = GiftFeel.Fragile,
    },
    carousel = GiftData.New {
        name     = "Playground Carousel", desc       = "a carousel",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/playground_carousel01.mdl",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = 4,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Round,
    },
    cash_register = GiftData.New {
        name     = "Cash Register",       desc       = "a cash register",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/cashregister01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Clicky, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Paper,  attrib_feel = GiftFeel.Heavy,
    },
    chair_armchair = GiftData.New {
        name     = "Armchair",            desc       = "an armchair",
        category = GiftCategory.PhysProp, identifier = "models/props/de_inferno/furniture_couch02a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = 4,
        attrib_smell = GiftSmell.Cotton,  attrib_feel = GiftFeel.Heavy,
    },
    chair_armchair_uggo = GiftData.New {
        name     = "Gaudy Armchair",      desc       = "an armchair",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/furniturearmchair001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Cotton,   attrib_feel = GiftFeel.Heavy,
    },
    chair_cafeteria = GiftData.New {
        name     = "Cafeteria Chair",     desc       = "a cafeteria chair",
        category = GiftCategory.PhysProp, identifier = "models/props_interiors/chair_cafeteria.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic,  attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Light,
    },
    chair_desk = GiftData.New {
        name     = "Desk Chair",          desc        = "a discount desk chair",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_c17/chair_office01a.mdl",
            "models/nova/chair_office01.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky,   attrib_feel = GiftFeel.Soft,
    },
    chair_office = GiftData.New {
        name     = "Office Chair",        desc       = "an office chair",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/chair_office.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squeaky, attrib_size = 4,
        attrib_smell = GiftSmell.Leather, attrib_feel = GiftFeel.Heavy,
    },
    chair_office_fancy = GiftData.New {
        name     = "Fancy Office Chair",  desc        = "a fancy office chair",
        category = GiftCategory.PhysProp, identifiers = {
            "models/nova/chair_office02.mdl",
            "models/props_combine/breenchair.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squeaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Leather, attrib_feel = GiftFeel.Heavy,
    },
    chair_metal = GiftData.New {
        name     = "Metal Chair",         desc        = "a metal chair",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_c17/chair02a.mdl",
            "models/props_interiors/furniture_chair03a.mdl",
            {mdl="models/props_wasteland/controlroom_chair001a.mdl", size=GiftSize.Huge},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 3,
        attrib_smell = GiftSmell.Leather,  attrib_feel = GiftFeel.Light,
    },
    chair_patio = GiftData.New {
        name     = "Patio Chair",         desc       = "a metal chair",
        category = GiftCategory.PhysProp, identifier = "models/props/de_tides/patio_chair2.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow,   attrib_size = 4,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Hard,
    },
    chair_rush = GiftData.New {
        name     = "Rush-Seat Chair",     desc        = "a chair",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_c17/furniturechair001a.mdl",
            {mdl="models/props/de_tides/patio_chair.mdl", size=GiftSize.Gigantic},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 3,
        attrib_smell = GiftSmell.Dusty,  attrib_feel = GiftFeel.Sturdy,
    },
    chandelier = GiftData.New {
        name     = "Chandelier",          desc       = "a chandelier",
        category = GiftCategory.PhysProp, identifier = "models/props/de_chateau/light_chandelier02.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Bright,
    },
    cinder_block = GiftData.New {
        name     = "Cinder Block",        desc        = "a cinder block",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/de_inferno/cinderblock.mdl",
            "models/props_junk/cinderblock01a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Mineral,  attrib_feel = GiftFeel.Heavy,
    },
    circular_saw = GiftData.New {
        name     = "Circular Saw",        desc       = "a circular saw",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_militia/circularsaw01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Revving, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Dusty,   attrib_feel = GiftFeel.Sharp,
    },
    cirno_fumo = GiftData.New {
        name     = "Cirno Fumo",          desc       = "a fumo",
        category = GiftCategory.PhysProp, identifier = "models/goobers/cirno/cirno.mdl",
        can_be_random_gift = true,
        factor_rarity = 0.9, factor_quality = 9,
        attrib_sound = GiftSound.None,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Cotton, attrib_feel = GiftFeel.Cold,
        adjustments = { set_mass = 40 },
    },
    citizen_radio = GiftData.New {
        name     = "Citizen Radio",       desc       = "a ham radio",
        category = GiftCategory.PhysProp, identifier = "models/props_lab/citizenradio.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Dusty,   attrib_feel = GiftFeel.Electric,
    },
    clay_pot = GiftData.New {
        name     = "Large Clay Pot",      desc        = "a clay pot",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/props/de_inferno/claypot01.mdl", size=GiftSize.Huge},
            "models/props/de_inferno/claypot02.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Clay,   attrib_feel = GiftFeel.Round,
    },
    clipboard = GiftData.New {
        name     = "Clipboard",           desc       = "a clipboard",
        category = GiftCategory.PhysProp, identifier = "models/props_lab/clipboard.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Paper,  attrib_feel = GiftFeel.Flat,
    },
    clock_desk = GiftData.New {
        name     = "Desk Clock",         desc       = "a desk clock",
        category = GiftCategory.PhysProp, identifier = "models/props_combine/breenclock.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Clicky, attrib_size = 1.7,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Sturdy,
    },
    clock_wall = GiftData.New {
        name     = "Wall Clock",          desc       = "a wall clock",
        category = GiftCategory.PhysProp, identifier = "models/props/de_inferno/clock01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Clicky, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Round,
    },
    coffee_maker = GiftData.New {
        name     = "Coffee Maker",        desc       = "a coffee maker",
        category = GiftCategory.PhysProp, identifier = "models/props_interiors/coffee_maker.mdl", -- not global
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Caffeine,  attrib_feel = GiftFeel.Electric,
    },
    coffee_mug = GiftData.New {
        name     = "Coffee Mug",          desc        = "a coffee mug",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/garbage_coffeemug001a.mdl",
            "models/props/cs_office/coffee_mug.mdl",
            "models/props/cs_office/coffee_mug2.mdl",
            "models/props/cs_office/coffee_mug3.mdl",
            "models/props_junk/garbage_coffeemug001a_fullsheet.mdl", -- not global
        },
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
    computer_case = GiftData.New {
        name     = "Computer Tower",      desc        = "a computer case",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/props_lab/harddrive02.mdl", size=GiftSize.Larger},
            "models/props/cs_office/computer_caseb.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Box,
    },
    computer_keyboard = GiftData.New {
        name     = "Keyboard",            desc        = "a keyboard",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_c17/computer01_keyboard.mdl",
            "models/props/cs_office/computer_keyboard.mdl",
            "models/props/cs_office/computer_keyboard_p2.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Clicky,   attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Caffeine, attrib_feel = GiftFeel.Flat,
    },
    computer_monitor_crt = GiftData.New {
        name     = "CRT Monitor",          desc       = "a CRT monitor",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_lab/monitor01a.mdl",
            "models/props_lab/monitor02.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Electric,
    },
    computer_monitor_new = GiftData.New {
        name     = "Computer Monitor",    desc        = "a monitor",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_office/computer_monitor.mdl",
            "models/props/cs_office/computer_monitor_p1.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Bright,
    },
    computer_mouse = GiftData.New {
        name     = "Computer Mouse",      desc       = "a mouse",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/computer_mouse.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Clicky,  attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Round,
    },
    computer = GiftData.New {
        name     = "Desktop Computer",    desc       = "a desktop computer",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/computer.mdl",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 3,
        attrib_sound = GiftSound.Clicky,  attrib_size = 3.2,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Bright,
    },
    concrete_barrier = GiftData.New {
        name     = "Concrete Barrier",    desc       = "a concrete barrier",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/concrete_barrier001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Mineral,  attrib_feel = GiftFeel.Hard,
    },
    console = GiftData.New {
        name     = "Control Console",     desc       = "a console",
        category = GiftCategory.PhysProp, identifier = "models/props/de_prodigy/desk_console1.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Ringing,  attrib_size = 4,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Heavy,
    },
    corkboard = GiftData.New {
        name     = "Office Corkboard",    desc       = "a corkboard",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/offcorkboarda.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.None,      attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Cardboard, attrib_feel = GiftFeel.Flat,
    },
    couch = GiftData.New {
        name     = "Couch",               desc        = "a couch",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/props/cs_militia/couch.mdl", size=GiftSize.Max},
            {mdl="models/props/de_inferno/furniture_couch01a.mdl", size=6},
            {mdl="models/props_c17/furniturecouch001a.mdl", size=6},
            {mdl="models/props_interiors/furniture_couch01a.mdl", size=6},
            "models/props_c17/furniturecouch002a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = 4.5,
        attrib_smell = GiftSmell.Cotton,  attrib_feel = GiftFeel.Massive,
    },
    crowbar_prop = GiftData.New {
        name     = "Crowbar (Prop)",      desc       = "a crowbar",
        category = GiftCategory.PhysProp, identifier = "models/weapons/w_crowbar.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 3,
        attrib_smell = GiftSmell.Woody,    attrib_feel = GiftFeel.Sharp,
    },
    cup_stack = GiftData.New {
        name     = "Paper Cup Stacks",     desc       = "four stacks of paper cups",
        category = GiftCategory.PhysProp, identifier = "models/props_interiors/styrofoam_cups.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Paper,  attrib_feel = GiftFeel.Long,
    },
    dead_bunger = GiftData.New {
        name     = "Dead Bunger",         desc       = "a dead Bunger",
        category = GiftCategory.PhysProp, identifier = "models/betterbunger.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Squishy,
    },
    defuser_prop = GiftData.New {
        name     = "Bomb Defusal Kit",    desc       = "a bomb defusal kit",
        category = GiftCategory.PhysProp, identifier = "models/weapons/w_defuser.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rattling,  attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Soft,
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
    detergent_bottle = GiftData.New {
        name     = "Detergent Bottle",     desc       = "an old bottle of detergent",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/props_junk/garbage_plasticbottle001a.mdl", size=GiftSize.Larger},
            "models/props_junk/garbage_plasticbottle002a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Toxic,   attrib_feel = GiftFeel.Hollow,
    },
    doll_baby = GiftData.New {
        name     = "Creepy Baby Doll",    desc       = "a creepy baby doll",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/doll01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 1.25,
        attrib_smell = GiftSmell.Stinky, attrib_feel = GiftFeel.Cursed,
    },
    door = GiftData.New {
        name     = "Door",                desc       = "a door",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/door01_left.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Paint,  attrib_feel = GiftFeel.Flat,
    },
    egg_prop = GiftData.New {
        name     = "Egg",              desc       = "an egg",
        category = GiftCategory.PhysProp, identifier = "models/props_phx/misc/egg.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,  attrib_feel = GiftFeel.Round,
    },
    electronic_oscillator = GiftData.New {
        name     = "Electronic Oscillator", desc       = "an oscillator",
        category = GiftCategory.PhysProp,   identifier = "models/props_c17/consolebox03a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Electric,
    },
    electronic_something = GiftData.New {
        name     = "Generic Device",      desc       = "some sort of device",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/consolebox01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = 2.8,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Electric,
    },
    explosive_barrel = GiftData.New {
        name     = "Explosive Barrel",    desc       = "an explosive barrel",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/oildrum001_explosive.mdl",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -9,
        attrib_sound = GiftSound.Metallic, attrib_size = 4.3,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Round,
        adjustments = {
            auto_fire_chance = 0.6,
            explo_barrel_unwrap = true,
        },
    },
    file_box = GiftData.New {
        name     = "File Box",            desc        = "a box of files",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_office/file_box.mdl",
            "models/props/cs_office/file_box_p1.mdl",
            "models/props/cs_office/file_box_p2.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Paper,    attrib_feel = GiftFeel.Box,
    },
    file_cabinet = GiftData.New {
        name     = "File Cabinet",        desc        = "a file cabinet",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_wasteland/controlroom_filecabinet002a.mdl",
            "models/props/cs_office/file_cabinet1.mdl",
            "models/props/cs_office/file_cabinet1_group.mdl",
            "models/props/cs_office/file_cabinet2.mdl",
            {mdl="models/props/cs_office/file_cabinet3.mdl", size=4},
            {mdl="models/props_lab/filecabinet02.mdl", size=3},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Paper,    attrib_feel = GiftFeel.Massive,
    },
    fire_extinguisher = GiftData.New {
        name     = "Fire Extinguisher",   desc       = "a fire extinguisher",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/fire_extinguisher.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Toxic,    attrib_feel = GiftFeel.Hollow,
    },
    foam_finger = GiftData.New {
        name     = "Foam Finger",         desc       = "a foam finger",
        category = GiftCategory.PhysProp, identifier = "models/weapons/w_thehandcannon.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Muffled, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Rubbery, attrib_feel = GiftFeel.Soft,
    },
    food_burger = GiftData.New {
        name     = "Hamburger",           desc       = "a burger",
        category = GiftCategory.PhysProp, identifier = "models/food/burger.mdl",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 7,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Warm,
    },
    food_hotdog = GiftData.New {
        name     = "Hotdog",              desc       = "a hotdog",
        category = GiftCategory.PhysProp, identifier = "models/food/hotdog.mdl",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 5,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Long,
    },
    food_stack = GiftData.New {
        name     = "Food Crate Stack",    desc       = "a bunch of food crates",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_militia/food_stack.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Food,     attrib_feel = GiftFeel.Massive,
    },
    fruit_crate = GiftData.New {
        name     = "Fruit Crate",         desc       = "a fruit crate",
        category = GiftCategory.PhysProp, identifier = "models/props/de_inferno/crate_fruit_break.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 4,
        attrib_smell = GiftSmell.Food,   attrib_feel = GiftFeel.Heavy,
    },
    fruit_stack = GiftData.New {
        name     = "Fruit Crate Stack",   desc       = "a huge stack of fruit crates",
        category = GiftCategory.PhysProp, identifier = "models/props/de_inferno/crates_fruit1.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 10,
        attrib_smell = GiftSmell.Food,   attrib_feel = GiftFeel.Massive,
    },
    fulton_prop = GiftData.New {
        name     = "Package with Camera", desc       = "a suspicious package",
        category = GiftCategory.PhysProp, identifier = "models/weapons/w_package.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Muffled, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Sus,
    },
    gas_can = GiftData.New {
        name     = "Gas Can",             desc        = "a gas can",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/gascan001a.mdl",
            "models/props_junk/metalgascan.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Oily,      attrib_feel = GiftFeel.Heavy,
    },
    glass_bottle = GiftData.New {
        name     = "Glass Bottle",        desc        = "a bottle",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/garbage_glassbottle001a.mdl",
            "models/props_junk/garbage_glassbottle003a.mdl",
            "models/props_junk/glassbottle01a.mdl",
            "models/props_junk/glassjug01.mdl",
            "models/props/cs_militia/bottle01.mdl",
            "models/props/cs_militia/bottle03.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Alcohol, attrib_feel = GiftFeel.Fragile,
        adjustments = { secret_formula_detect = { is_secret = false } },
    },
    globe_antique = GiftData.New {
        name     = "Antique Globe",       desc       = "an antique globe",
        category = GiftCategory.PhysProp, identifier = "models/props_combine/breenglobe.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Paper,  attrib_feel = GiftFeel.Round,
    },
    gnome = GiftData.New {
        name     = "Garden Gnome",        desc       = "a gnome",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/gnome.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = -3,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Paint,  attrib_feel = GiftFeel.Jolly,
    },
    goober = GiftData.New {
        name     = "Goober",              desc       = "a goober",
        category = GiftCategory.PhysProp, identifier = "models/goobers/goober/goober_0.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 8,
        attrib_sound = GiftSound.None,   attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky, attrib_feel = GiftFeel.Flat,
    },
    health_kit = GiftData.New {
        name     = "Health Kit",          desc       = "a health kit",
        category = GiftCategory.PhysProp, identifier = "models/items/healthkit.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping,  attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Medicine, attrib_feel = GiftFeel.Futuristic,
    },
    health_vial = GiftData.New {
        name     = "Health Vial",          desc      = "a health vial",
        category = GiftCategory.PhysProp, identifier = "models/healthvial.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Medicine,  attrib_feel = GiftFeel.Futuristic,
    },
    hula_doll = GiftData.New {
        name     = "Hula Girl Doll",      desc       = "a hula doll",
        category = GiftCategory.PhysProp, identifier = "models/props_lab/huladoll.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Mini,
        attrib_smell = GiftSmell.Paint,   attrib_feel = GiftFeel.Warm,
    },
    kitchen_counter = GiftData.New {
        name     = "Kitchen Counter",     desc        = "a kitchen counter",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/props_wasteland/kitchen_counter001b.mdl", size=GiftSize.Gigantic},
            "models/props_wasteland/kitchen_counter001d.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 8,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Hollow,
    },
    ladder = GiftData.New {
        name     = "Aliminium Ladder",    desc       = "a ladder",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_assault/ladderaluminium128.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow,   attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Long,
    },
    lambert = GiftData.New {
        name     = "Lambert Plushie",     desc       = "a sacrificial lamb",
        category = GiftCategory.PhysProp, identifier = "models/goobers/lambert/lambert.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 6,
        attrib_sound = GiftSound.Bleating, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Wool,     attrib_feel = GiftFeel.Otherworldly,
        adjustments = { set_mass = 40 },
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
        name     = "Hanging Lamp",        desc        = "a lamp",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_wasteland/prison_lamp001c.mdl",
            "models/props/de_inferno/wall_lamp2.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass,    attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Bright,
    },
    lamp_table = GiftData.New {
        name     = "Table Lamp",          desc       = "a table lamp",
        category = GiftCategory.PhysProp, identifier = "models/props_interiors/lamp_table02.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Paper,  attrib_feel = GiftFeel.Bright,
    },
    laundry_cart = GiftData.New {
        name     = "Corroded Laundry Cart", desc        = "a laundry cart",
        category = GiftCategory.PhysProp,   identifiers = {
            "models/props_wasteland/laundry_cart001.mdl",
            {mdl="models/props_wasteland/laundry_cart002.mdl", size=4.5},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Hollow,
    },
    market_bean_tray = GiftData.New {
        name     = "Market Bean Tray",    desc        = "a bean tray",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_italy/it_mkt_container1a.mdl",
            "models/props/cs_italy/it_mkt_container3a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Food,   attrib_feel = GiftFeel.Box,
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
        only_on_map = "ttt_minecraftcity",
    },
    menu_stand = GiftData.New {
        name     = "Menu Stand",          desc       = "a menu stand",
        category = GiftCategory.PhysProp, identifier = "models/props/de_tides/menu_stand.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Food,   attrib_feel = GiftFeel.Sturdy,
    },
    metal_closet = GiftData.New {
        name     = "Metal Closet",        desc       = "a metal closet",
        category = GiftCategory.PhysProp, identifier = "models/props_wasteland/controlroom_storagecloset001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Hollow,
    },
    metal_lockers = GiftData.New {
        name     = "Metal Lockers",       desc       = "a set of metal lockers",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/lockers001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Massive,
    },
    metal_pan = GiftData.New {
        name     = "Metal Pan",           desc        = "a cooking pan",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_c17/metalpot002a.mdl",
            "models/props_misc/pan-2.mdl", -- may be unique to ttt_bikinibottom
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Ash,      attrib_feel = GiftFeel.Flat,
    },
    metal_panel = GiftData.New {
        name     = "Metal Panel",         desc       = "a panel",
        category = GiftCategory.PhysProp, identifier = "models/props_debris/metal_panel01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Flat,
    },
    metal_pot = GiftData.New {
        name     = "Metal Pot",           desc        = "a metal pot",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_c17/metalpot001a.mdl",
            "models/props_interiors/pot02a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Hollow,
    },
    metal_stool = GiftData.New {
        name     = "Metal Stool",         desc       = "a stool",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/chair_stool01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic,    attrib_size = 3,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Round,
    },
    microwave = GiftData.New {
        name     = "Microwave",           desc        = "a microwave",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_office/microwave.mdl",
            {mdl="models/props/cs_militia/microwave01.mdl", size=GiftSize.Huge},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Box,
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
    mop_bucket = GiftData.New {
        name     = "Mobile Mop Bucket",   desc       = "a mop bucket",
        category = GiftCategory.PhysProp, identifier = "models/props_unique/mopbucket01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = 4.5,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Sticky,
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
        attrib_smell = GiftSmell.Paper,    attrib_feel = GiftFeel.Informative,
    },
    newspaper_page = GiftData.New {
        name     = "Newspaper Clipping",  desc       = "a newspaper clipping",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/paper01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Paper,    attrib_feel = GiftFeel.Informative,
    },
    orange = GiftData.New {
        name     = "Orange",              desc       = "an orange",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_italy/orange.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Mini,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Round,
    },
    osrs_axe = GiftData.New {
        name     = "Lumbridge Hatchet",       desc       = "a hatchet",
        category = GiftCategory.PhysProp, identifier = "models/osrs/axe.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Bloody,   attrib_feel = GiftFeel.Sharp,
        only_on_map = "ttt_lumbridge"
    },
    osrs_flour = GiftData.New {
        name     = "Lumbridge Flour",     desc       = "flour",
        category = GiftCategory.PhysProp, identifier = "models/osrs/flour.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Granular, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Food,     attrib_feel = GiftFeel.Soft,
        only_on_map = "ttt_lumbridge"
    },
    osrs_milk = GiftData.New {
        name     = "Lumbridge Milk",      desc       = "milk",
        category = GiftCategory.PhysProp, identifier = "models/osrs/milk_bucket.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Food,      attrib_feel = GiftFeel.Heavy,
        only_on_map = "ttt_lumbridge"
    },
    painting = GiftData.New {
        name     = "Painting",            desc        = "a painting",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/de_inferno/picture1.mdl",
            "models/props/de_inferno/picture2.mdl",
            "models/props/de_inferno/picture3.mdl",
            {mdl="models/props/cs_office/offpaintinga.mdl", size=3.6},
            {mdl="models/props/cs_office/offpaintingb.mdl", size=3.3},
            {mdl="models/props/cs_office/offpaintingd.mdl", size=3.3},
            {mdl="models/props/cs_office/offpaintinge.mdl", size=3},
            {mdl="models/props/cs_office/offpaintingf.mdl", size=3.8},
            {mdl="models/props/cs_office/offpaintingg.mdl", size=3.3},
            {mdl="models/props/cs_office/offpaintingi.mdl", size=3.5},
            {mdl="models/props/cs_office/offpaintingj.mdl", size=3.3},
            {mdl="models/props/cs_office/offpaintingk.mdl", size=3},
            {mdl="models/props/cs_office/offpaintingl.mdl", size=3.8},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Paint,  attrib_feel = GiftFeel.Flat,
    },
    painting_motivational = GiftData.New {
        name     = "Motivational Poster", desc        = "a motivational poster",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_office/offinspa.mdl",
            "models/props/cs_office/offinspb.mdl",
            "models/props/cs_office/offinspc.mdl",
            "models/props/cs_office/offinspd.mdl",
            "models/props/cs_office/offinspf.mdl",
            "models/props/cs_office/offinspg.mdl",
        },
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -3,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Paper,  attrib_feel = GiftFeel.Flat,
    },
    paper_towel = GiftData.New {
        name     = "Paper Towel",         desc       = "a paper towel",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/paper_towels.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Muffled, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Paper,   attrib_feel = GiftFeel.Round,
    },
    phone_office = GiftData.New {
        name     = "Office Phone",        desc       = "an office phone",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/phone.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Ringing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Fragile,
    },
    picture_frame = GiftData.New {
        name     = "Old Picture Frame",   desc       = "an old picture frame",
        category = GiftCategory.PhysProp, identifier = "models/props_lab/frame002a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.None,  attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Dusty, attrib_feel = GiftFeel.Nostalgic,
    },
    plastic_barrel = GiftData.New {
        name     = "Plastic Barrel",      desc       = "a barrel",
        category = GiftCategory.PhysProp, identifier = "models/props_borealis/bluebarrel001.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = 4.5,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Round,
    },
    plastic_bottle = GiftData.New {
        name     = "Plastic Bottle",      desc       = "a plastic bottle",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/garbage_plasticbottle003a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Long,
    },
    plastic_bottle_paper = GiftData.New {
        name     = "Wrapped Plastic Bottle", desc       = "a plastic bottle wrapped in paper",
        category = GiftCategory.PhysProp,    identifier = "models/props_junk/garbage_glassbottle002a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Paper,   attrib_feel = GiftFeel.Long,
    },
    plastic_crate = GiftData.New {
        name     = "Plastic Crate",       desc       = "a plastic crate",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/plasticcrate01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Hollow,
    },
    platform_cart = GiftData.New {
        name     = "Platform Cart",       desc        = "a platform cart",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/pushcart01a.mdl",
            "models/props/de_prodigy/pushcart.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 6,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Flat,
    },
    plush_alligator = GiftData.New { -- only available on diescraper :(
        name     = "Plush Alligator",     desc       = "an alligator plushie",
        category = GiftCategory.PhysProp, identifier = "models/props_fairgrounds/alligator.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.None,     attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Cotton,   attrib_feel = GiftFeel.Squishy,
    },
    plush_elephant = GiftData.New { -- only available on poolparty & diescraper :(
        name     = "Plush Elephant",      desc       = "an elephant plushie",
        category = GiftCategory.PhysProp, identifier = "models/props_fairgrounds/elephant.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.None,     attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Cotton,   attrib_feel = GiftFeel.Squishy,
    },
    plush_giraffe = GiftData.New {  -- only available on poolparty & diescraper :(
        name     = "Plush Giraffe",       desc       = "a giraffe plushie",
        category = GiftCategory.PhysProp, identifier = "models/props_fairgrounds/giraffe.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.None,     attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Cotton,   attrib_feel = GiftFeel.Squishy,
    },
    plush_turtle = GiftData.New {
        name     = "Plush Turtle",        desc       = "a turtle plushie",
        category = GiftCategory.PhysProp, identifier = "models/props/de_tides/vending_turtle.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 8,
        attrib_sound = GiftSound.None,     attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Cotton,   attrib_feel = GiftFeel.Squishy,
    },
    plush_turtle_cap = GiftData.New {
        name     = "Plush Turtle Cap",    desc       = "an \"I Love Turtle\" cap",
        category = GiftCategory.PhysProp, identifier = "models/props/de_tides/vending_hat.mdl",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 3,
        attrib_sound = GiftSound.None,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Cotton, attrib_feel = GiftFeel.Round,
        adjustments = { turtle_cap_desc = true },
    },
    potless_plant = GiftData.New {
        name     = "Potless Plant",       desc      = "a plant",
        category = GiftCategory.PhysProp, identifier = "models/props/de_inferno/potted_plant1_p1.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Earthy,   attrib_feel = GiftFeel.Heavy,
    },
    potted_plant = GiftData.New {
        name     = "Potted Plant",        desc        = "a potted plant",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_office/plant01.mdl",
            {mdl="models/props/de_inferno/claypot03.mdl", size=GiftSize.Big},
            "models/props/de_inferno/potted_plant1.mdl",
            "models/props/de_inferno/potted_plant2.mdl",
            "models/props/de_inferno/potted_plant3.mdl",
            {mdl="models/props/de_inferno/pot_big.mdl", size=GiftSize.Gigantic},
            "models/props_foliage/potted_plant1.mdl", -- not global, from ttt_trainstation
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Clay,     attrib_feel = GiftFeel.Round,
    },
    potted_plant_wood = GiftData.New {
        name     = "Flower Barrel",       desc       = "a flower barrel",
        category = GiftCategory.PhysProp, identifier = "models/props/de_inferno/flower_barrel.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Woody,    attrib_feel = GiftFeel.Round,
    },
    potted_cactus = GiftData.New {
        name     = "Potted Cactus",        desc      = "a cactus",
        category = GiftCategory.PhysProp, identifier = "models/props_lab/cactus.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Clay,     attrib_feel = GiftFeel.Sharp,
    },
    present_prop = GiftData.New {
        name     = "Present (Prop)",      desc        = "a fake present",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/katharsmodels/present/type-1/big/present3.mdl", size=GiftSize.Gigantic},
            "models/katharsmodels/present/type-2/normal/present1.mdl",
            "models/katharsmodels/present/type-2/normal/present2.mdl",
            "models/katharsmodels/present/type-2/normal/present3.mdl",
            {mdl="models/katharsmodels/present/type-2/big/present1.mdl", size=GiftSize.Huge},
            {mdl="models/katharsmodels/present/type-2/big/present2.mdl", size=GiftSize.Huge},
            {mdl="models/katharsmodels/present/type-2/big/present3.mdl", size=GiftSize.Huge},
            {mdl="models/katharsmodels/present/type-2/small/present1.mdl", size=GiftSize.Mini},
            {mdl="models/katharsmodels/present/type-2/small/present2.mdl", size=GiftSize.Mini},
            {mdl="models/katharsmodels/present/type-2/small/present3.mdl", size=GiftSize.Mini},
            {mdl="models/props_modest_christmas/present01.mdl", size=GiftSize.Huge},
            {mdl="models/props_modest_christmas/present02.mdl", size=GiftSize.Gigantic},
            {mdl="models/props_modest_christmas/present03.mdl", size=GiftSize.Big},
            {mdl="models/props_modest_christmas/present05.mdl", size=GiftSize.Big},
            {mdl="models/zombiexmas/gift1_static.mdl", size=GiftSize.Large},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Paper,    attrib_feel = GiftFeel.Jolly,
        only_on_map = "ttt_christmas_bowling",
    },
    prop_radio = GiftData.New {
        name     = "Radio (Prop)",        desc       = "a broken radio",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/radio.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Fragile,
    },
    propane_canister = GiftData.New {
        name     = "Propane Canister",    desc       = "a propane canister",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/propanecanister001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Round,
    },
    propane_tank = GiftData.New {
        name     = "Propane Tank",        desc       = "a propane tank",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/propane_tank001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 3,
        attrib_smell = GiftSmell.Oily,     attrib_feel = GiftFeel.Long,
    },
    radio_receiver = GiftData.New {
        name     = "Radio Receiver",      desc        = "a radio receiver",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_lab/reciever01a.mdl",
            "models/props_lab/reciever01b.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Box,
    },
    radio_receiver_cart = GiftData.New {
        name     = "Receiver Cart",       desc       = "a receiver cart",
        category = GiftCategory.PhysProp, identifier = "models/props_lab/reciever_cart.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = 5.5,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Massive,
    },
    rat = GiftData.New {
        name     = "Rat",                 desc       = "a rat",
        category = GiftCategory.PhysProp, identifier = "models/goobers/jermarat/rat.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -5,
        attrib_sound = GiftSound.Squeaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Alive,
        adjustments = { set_mass = 40 },
    },
    rock = GiftData.New {
        name     = "Rock",                desc       = "a rock",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/rock001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Mineral,  attrib_feel = GiftFeel.Hard,
    },
    rollermine_prop = GiftData.New {
        name     = "Rollermine (Prop)",   desc       = "an inactive rollermine",
        category = GiftCategory.PhysProp, identifier = "models/roller.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Beeping, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Round,
    },
    seal = GiftData.New {
        name     = "Seal",                desc       = "a seal",
        category = GiftCategory.PhysProp, identifier = "models/goobers/niko/niko.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 5,
        attrib_sound = GiftSound.Squeaky, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Fur,     attrib_feel = GiftFeel.Slippery,
    },
    sign_ravenholm = GiftData.New {
        name     = "Ravenholm Sign",      desc       = "a doomed city's sign",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/ravenholmsign.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Spooky,
    },
    shoe = GiftData.New {
        name     = "Worn Shoe",           desc       = "a shoe",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/shoe001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squeaky, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Leather, attrib_feel = GiftFeel.Soft,
    },
    shovel = GiftData.New {
        name     = "Shovel",              desc       = "a shovel",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/shovel01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Earthy,   attrib_feel = GiftFeel.Long,
    },
    siffrin = GiftData.New {
        name     = "Siffrin Plushie",     desc       = "a Siffrin plushie",
        category = GiftCategory.PhysProp, identifier = "models/goobers/siffrin/siffrin.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 3,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Cotton,  attrib_feel = GiftFeel.Otherworldly,
    },
    skeleton_rib = GiftData.New {
        name     = "Rib",                 desc       = "a rib",
        category = GiftCategory.PhysProp, identifier = "models/gibs/hgibs_rib.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rattling, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Dry  ,    attrib_feel = GiftFeel.Sharp,
    },
    snowman_face = GiftData.New {
        name     = "Snowman's Face",      desc       = "a snowman's face",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/snowman_face.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Muffled, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Nice,    attrib_feel = GiftFeel.Cold,
    },
    soccer_ball = GiftData.New {
        name     = "Soccer Ball",         desc       = "a brand-new soccer ball",
        category = GiftCategory.PhysProp, identifier = "models/props_phx/misc/soccerball.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 2,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Leather,  attrib_feel = GiftFeel.Round,
    },
    spool_big = GiftData.New {
        name     = "Large Wire Spool",    desc       = "a large spool",
        category = GiftCategory.PhysProp, identifier = "models/props/de_prodigy/spoolwire.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Woody,    attrib_feel = GiftFeel.Electric,
    },
    storage_rack = GiftData.New {
        name     = "Cafeteria Storage Rack", desc        = "a storage rack",
        category = GiftCategory.PhysProp,    identifiers = {
            "models/props_wasteland/kitchen_shelf001a.mdl",
            {mdl="models/props_wasteland/kitchen_shelf002a.mdl", size=6},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 8,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Massive,
    },
    supply_jar = GiftData.New {
        name     = "Supply Jar",          desc       = "a jar of supplies",
        category = GiftCategory.PhysProp, identifier = "models/props_lab/jar01b.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic,  attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Medicine, attrib_feel = GiftFeel.Round,
    },
    table_cafeteria = GiftData.New {
        name     = "Cafeteria Table",     desc       = "a cafeteria table",
        category = GiftCategory.PhysProp, identifier = "models/props_wasteland/cafeteria_table001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Long,
    },
    table_coffee = GiftData.New {
        name     = "Coffee Table",        desc        = "a coffee table",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_office/table_coffee.mdl",
            {mdl="models/props/de_inferno/tablecoffee.mdl", size=GiftSize.Gigantic},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 4,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Flat,
    },
    table_wooden = GiftData.New {
        name     = "Wooden Table",        desc        = "a table",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/props_c17/furnituretable001a.mdl", size=4},
            "models/props_c17/furnituretable002a.mdl",
            "models/props_c17/furnituretable003a.mdl",
            "models/props/cs_militia/wood_table.mdl",
            {mdl="models/props/de_inferno/tableantique.mdl", size=3.7},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Flat,
    },
    table_wooden_cloth = GiftData.New {
        name     = "Wooden Table with Cloth", desc       = "a table",
        category = GiftCategory.PhysProp,     identifier = "models/props_furniture/r_table1.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Wool,   attrib_feel = GiftFeel.Flat,
        only_on_map = "ttt_snowtown",
    },
    takeout_carton = GiftData.New {
        name     = "Asian Takeout Carton", desc       = "some takeout",
        category = GiftCategory.PhysProp,  identifier = "models/props_junk/garbage_takeoutcarton001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squelching, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,       attrib_feel = GiftFeel.Warm,
    },
    tin_can = GiftData.New {
        name     = "Tin Can",             desc        = "a tin can",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/garbage_metalcan001a.mdl",
            "models/props_junk/garbage_metalcan002a.mdl",
            "models/props_junk/garbage_beancan01a.mdl", -- not global
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow,   attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Light,
    },
    tire_car = GiftData.New {
        name     = "Car Tire",            desc        = "a tire",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/props_vehicles/apc_tire001.mdl", size=GiftSize.Gigantic},
            "models/props_vehicles/carparts_tire01a.mdl",
            "models/props_vehicles/carparts_wheel01a.mdl",
            "models/props_vehicles/tire001c_car.mdl",
            {mdl="models/props/de_prodigy/tire1.mdl", size=4},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = 3,
        attrib_smell = GiftSmell.Rubbery, attrib_feel = GiftFeel.Round,
    },
    toaster = GiftData.New {
        name     = "Toaster",             desc       = "a toaster",
        category = GiftCategory.PhysProp, identifier = "models/props_interiors/toaster.mdl", -- not global
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Food,     attrib_feel = GiftFeel.Hot,
    },
    tools_pliers = GiftData.New {
        name     = "Pliers",              desc       = "a pair of pliers",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/tools_pliers01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Sharp,
    },
    tools_wrench = GiftData.New {
        name     = "Wrench",              desc       = "a wrench",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/tools_wrench01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Sturdy,
    },
    toy_train = GiftData.New {
        name     = "Toy Train",           desc       = "a toy train",
        category = GiftCategory.PhysProp, identifier = "models/quarterlife/fsd-overrun-toy.mdl",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 8,
        attrib_sound = GiftSound.Train,   attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Plastic, attrib_feel = GiftFeel.Long,
        adjustments = { set_mass = 40 },
    },
    traffic_barrier = GiftData.New {
        name     = "Traffic Barrier",     desc       = "a traffic barrier",
        category = GiftCategory.PhysProp, identifier = "models/props_fortifications/traffic_barrier001.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = 4,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Flat,
    },
    traffic_cone = GiftData.New {
        name     = "Traffic Cone",       desc        = "a traffic cone",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/trafficcone001a.mdl",
            "models/csgo/props_junk/trafficcone001a.mdl", --not global; from ttt_trainstation
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Rubbery, attrib_feel = GiftFeel.Light,
    },
    trash_bag = GiftData.New {
        name     = "Dirty Bag",           desc       = "a crumpled up bag",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/garbage_bag001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Stinky,   attrib_feel = GiftFeel.Icky,
    },
    trash_bin = GiftData.New {
        name     = "Recycling Bin",       desc       = "a recycling bin",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/trashbin01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Hollow,
    },
    trash_can = GiftData.New {
        name     = "Trash Can",           desc        = "a trash can",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_office/trash_can.mdl",
            "models/props/cs_office/trash_can_p.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Hollow,
    },
    trash_can_kitchen = GiftData.New {
        name     = "Modern Trash Can",     desc       = "a trash can",
        category = GiftCategory.PhysProp, identifier = "models/props_interiors/trashcankitchen01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Plastic, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Hollow,
    },
    trash_dumpster = GiftData.New {
        name     = "Dumpster",            desc       = "a dumpster",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/trashdumpster01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = 6,
        attrib_smell = GiftSmell.Stinky,   attrib_feel = GiftFeel.Massive,
    },
    tv_monitor_plasma = GiftData.New {
        name     = "Plasma TV Monitor",   desc        = "a flat screen TV",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_office/tv_plasma.mdl",
            "models/props/de_train/hr_t/hr_tv_plasma/hr_tv_plasma.mdl", -- not global
        },
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = 9,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Flat,
    },
    tv_monitor_old = GiftData.New {
        name     = "Retro TV Monitor",    desc        = "a retro TV",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/de_inferno/tv_monitor01.mdl",
            "models/props_c17/tv_monitor01.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Electric,
    },
    unsung_star_battery = GiftData.New {
        name     = "Healing Booth Battery", desc       = "a healing booth battery",
        category = GiftCategory.PhysProp,   identifier = "models/lt_c/sci_fi/dm_container_small.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Pulsing,  attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Electric,
        only_on_map = "ttt_unsung_star"
    },
    used_knife = GiftData.New {
        name     = "Used Knife",          desc       = "a bloodied knife",
        category = GiftCategory.PhysProp, identifier = "models/weapons/w_knife_t.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Bloody,   attrib_feel = GiftFeel.Sharp,
        adjustments = { break_constraints = true },
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
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Bloody,   attrib_feel = GiftFeel.Sharp,
        adjustments = {
            sopd_spawn = true,
            break_constraints = true
        },
    },
    vase_pottery = GiftData.New {
        name     = "Pottery Vase",        desc       = "a vase",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/pottery04a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Clay,   attrib_feel = GiftFeel.Round,
    },
    vending_machine = GiftData.New {
        name     = "Vending Machine",     desc        = "a vending machine",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_interiors/vendingmachinesoda01a.mdl",
            "models/props/cs_office/vending_machine.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = 8,
        attrib_smell = GiftSmell.Fizzy,    attrib_feel = GiftFeel.Massive,
    },
    vent_grate = GiftData.New {
        name     = "Vent Grate",          desc       = "a vent",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/vent001.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow,   attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Sus,
    },
    washtub_metal = GiftData.New {
        name     = "Metal Wash Tub",      desc       = "a wash tub",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/metalbucket02a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow,   attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Round,
    },
    watermelon = GiftData.New {
        name     = "Watermelon",          desc       = "a watermelon",
        category = GiftCategory.PhysProp, identifier = "models/props_junk/watermelon01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Round,
        adjustments = { holy_watermelon_detect = { is_holy = false } },
    },
    watermelon_unbreakable = GiftData.New {
        name     = "Unbreakable Watermelon", desc       = "an invincible watermelon",
        category = GiftCategory.PhysProp,    identifier = "models/foodnhouseholditems/watermelon_unbreakable.mdl", -- ttt_5c_plaza
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Sturdy,
    },
    water_bottle = GiftData.New {
        name     = "Water Bottle",        desc       = "a water bottle",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_office/water_bottle.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing,   attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Fresh,
    },
    washing_machine = GiftData.New {
        name     = "Washing Machine",     desc       = "a washing machine",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/furniturewashingmachine001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Nice,   attrib_feel = GiftFeel.Electric,
    },
    wooden_barrel = GiftData.New {
        name     = "Wooden Barrel",       desc        = "a wooden barrel",
        category = GiftCategory.PhysProp, identifiers = {
            {mdl="models/props/de_inferno/wine_barrel.mdl", size=4.5},
            "models/props_c17/woodbarrel001.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Round,
    },
    wooden_bench = GiftData.New {
        name     = "Wooden Bench",        desc        = "a bench",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/cs_militia/wood_bench.mdl",
            {mdl="models/props_c17/bench01a.mdl", size=6},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Flat,
    },
    wooden_chair = GiftData.New {
        name     = "Wooden Chair",        desc        = "a wooden chair",
        category = GiftCategory.PhysProp, identifiers = {
            "models/nova/chair_wood01.mdl",
            "models/props/de_inferno/chairantique.mdl",
            "models/props_interiors/furniture_chair01a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Light,
    },
    wooden_chair_bbh = GiftData.New {
        name     = "Wooden Chair",        desc       = "a wooden chair",
        category = GiftCategory.PhysProp, identifier = "models/big_boos_haunt/chair.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 4.5,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Spooky,
        only_on_map = "ttt_sm64_big_boos_haunt"
    },
    wooden_closet = GiftData.New {
        name     = "Wooden Closet",       desc       = "a closet",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/furnituredresser001a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 6.5,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Hollow,
    },
    wooden_crate = GiftData.New {
        name     = "Wooden Crate",        desc        = "a wooden crate",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/wood_crate001a.mdl",
            "models/props_junk/wood_crate001a_damaged.mdl",
            "models/props_junk/wood_crate001a_damagedmax.mdl",
            "models/props_lab/dogobject_wood_crate001a_damagedmax.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 4,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Box,
    },
    wooden_crate_big = GiftData.New {
        name     = "Wooden Crate (Big)",  desc        = "a large wooden crate",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/wood_crate002a.mdl",
            {mdl="models/props/de_nuke/crate_large.mdl", size=8},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 6,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Massive,
    },
    wooden_desk = GiftData.New {
        name     = "Wooden Desk",         desc       = "a desk",
        category = GiftCategory.PhysProp, identifier = "models/props_interiors/furniture_desk01a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Nice,   attrib_feel = GiftFeel.Flat,
    },
    wooden_drawer = GiftData.New {
        name     = "Wooden Drawer",       desc        = "a drawer",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props/de_inferno/furnituredrawer001a.mdl",
            "models/props_c17/furnituredrawer001a.mdl",
            "models/props_c17/furnituredrawer003a.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 4,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Sturdy,
    },
    wooden_nightstand = GiftData.New {
        name     = "Wooden Nightstand",   desc       = "a nightstand",
        category = GiftCategory.PhysProp, identifier = "models/props_c17/furnituredrawer002a.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Light,
    },
    wooden_pallet = GiftData.New {
        name     = "Wooden Pallet",       desc        = "a wooden pallet",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_junk/wood_pallet001a.mdl",
            "models/props/de_prodigy/wood_pallet_01.mdl",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Flat,
    },
    wooden_sawhorse = GiftData.New {
        name     = "Wooden Sawhorse",     desc       = "a sawhorse",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_militia/sawhorse.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Dusty,  attrib_feel = GiftFeel.Sturdy,
    },
    wooden_shelf = GiftData.New {
        name     = "Wooden Shelf",        desc        = "a shelf",
        category = GiftCategory.PhysProp, identifiers = {
            "models/props_c17/furnituredrawer001a.mdl",
            {mdl="models/props_c17/furnitureshelf001a.mdl", size=6.5},
            {mdl="models/props_c17/shelfunit01a.mdl", size=GiftSize.Max},
            {mdl="models/props_interiors/furniture_shelf01a.mdl", size=GiftSize.Max},
            {mdl="models/props_wasteland/prison_shelf002a.mdl", size=3},
            {mdl="models/props/cs_militia/furniture_shelf01a.mdl", size=GiftSize.Max},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Hollow,
    },
    wooden_stool = GiftData.New {
        name     = "Wooden Stool",        desc       = "a bar stool",
        category = GiftCategory.PhysProp, identifier = "models/props/cs_militia/barstool01.mdl",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 3,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Round,
    },
    xbox = GiftData.New {
        name     = "Xbox",                desc       = "a classic Xbox",
        category = GiftCategory.PhysProp, identifier = "models/executive/hr_model_xbox.mdl",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 10,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Box,
    },
})

table.Merge(giftDataCatalog, { -- Func PhysBoxes (map-bound model-less props)
    _67thway_wall_bit = GiftData.New {
        name     = "Broken Wall Piece",  desc        = "a broken piece of wall",
        category = GiftCategory.PhysBox, identifiers = {
            {mdl="*40", size=10},
            {mdl="*41", size=GiftSize.Gigantic},
            {mdl="*42", size=GiftSize.Max},
            {mdl="*43", size=9},
            {mdl="*44", size=GiftSize.Big},
            {mdl="*45", size=6},
            {mdl="*46", size=6},
            {mdl="*47", size=3},
            {mdl="*48", size=GiftSize.Max},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Mineral,  attrib_feel = GiftFeel.Flat,
        only_on_map = "ttt_67thway",
    },
    bbh_bridge_block = GiftData.New {
        name     = "Bridge Block",       desc        = "part of the bridge",
        category = GiftCategory.PhysBox, identifiers = {
            "bridge_1", "bridge_2", "bridge_3", "bridge_4", "bridge_5",
            "bridge_6", "bridge_7", "bridge_8", "bridge_9", "bridge_10"
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Box,
        only_on_map = "ttt_sm64_big_boos_haunt"
    },
    bestbuy_dolby_larger = GiftData.New {
        name     = "Dolby Digital Speakers", desc        = "surround sound speakers",
        category = GiftCategory.PhysBox,     identifiers = {
            "*57", "*62", "*67", "*69", "*72", "*75",
            "*80", "*82", "*85", "*87", "*89", "*93",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Musical, attrib_size = 4.5,
        attrib_smell = GiftSmell.Woody,   attrib_feel = GiftFeel.Box,
        only_on_map = "ttt_bestbuy",
    },
    bestbuy_dolby_smaller = GiftData.New {
        name     = "Dolby Digital Speakers", desc        = "surround sound speakers",
        category = GiftCategory.PhysBox,     identifiers = {
            "*58", "*63", "*66", "*70", "*71", "*76",
            "*81", "*83", "*84", "*88", "*90", "*94",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Woody,   attrib_feel = GiftFeel.Box,
        only_on_map = "ttt_bestbuy",
    },
    bestbuy_sony_tv_box = GiftData.New {
        name     = "Sony TV Box",        desc        = "a TV box",
        category = GiftCategory.PhysBox, identifiers = {"*64", "*74"},
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Box,
        only_on_map = "ttt_bestbuy",
    },
    bestbuy_sony_tv_monitor = GiftData.New {
        name     = "Sony TV Monitor",    desc        = "a large Sony TV",
        category = GiftCategory.PhysBox, identifiers = {
            "*59", "*73", "*86", "*91",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = 4.5,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Heavy,
        only_on_map = "ttt_bestbuy",
    },
    bestbuy_tmobile = GiftData.New {
        name     = "T-Mobile® Sign",     desc       = "the T-Mobile sign",
        category = GiftCategory.PhysBox, identifier = "Tmobilesign",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing, attrib_size = 4.5,
        attrib_smell = GiftSmell.Cardboard, attrib_feel = GiftFeel.Flat,
        only_on_map = "ttt_bestbuy",
    },
    cobertura_wall_bit = GiftData.New {
        name     = "Broken Wall Bit",    desc        = "a broken bit of wall",
        category = GiftCategory.PhysBox, identifiers = {
            {mdl="*18", size=5.2},
            {mdl="*19", size=5.2},
            {mdl="*20", size=3.2},
            {mdl="*21", size=3.6},
            {mdl="*22", size=3.2},
            {mdl="*23", size=3.8},
            {mdl="*24", size=3.8},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass,   attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Mineral, attrib_feel = GiftFeel.Sharp,
        only_on_map = "ttt_cobertura",
    },
    innomotel_key = GiftData.New {
        name     = "Innocent Motel Key",          desc       = "a key",
        category = GiftCategory.PhysBox, identifier = "key",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Rusty,    attrib_feel = GiftFeel.Box,
        only_on_map = "ttt_innocentmotel",
    },
    innomotel_tv = GiftData.New {
        name     = "TV Screen",          desc        = "a TV",
        category = GiftCategory.PhysBox, identifiers = {
            "*104", "*107", "*110", "*113", "*116",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whirring, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Flat,
        only_on_map = "ttt_innocentmotel",
    },
    kakariko_boulder = GiftData.New { -- TODO: disappears in giftbox (timer-based)
        name     = "Tumbling Boulder",   desc        = "a heavy boulder",
        category = GiftCategory.PhysBox, identifiers = {"ball1", "ball2"},
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Earthy,   attrib_feel = GiftFeel.Round,
        only_on_map = "ttt_kakariko",
    },
    mc_city_tnt = GiftData.New {
        name     = "TNT Block",          desc        = "a TNT block",
        category = GiftCategory.PhysBox, identifiers = {
            "TNT01",
            "TNT02",
            "TNT03",
            "", -- not relevant since we get the moveParent of each block; added for coverage
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hissing,   attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Box,
        only_on_map = "ttt_minecraftcity", paper_cost = 30,
    },
    mc_b5_dia_ore = GiftData.New {
        name     = "Diamonde Ore Block", desc        = "a diamond ore",
        category = GiftCategory.PhysBox, identifiers = {
            "DiaOre_1", "DiaOre_2", "DiaOre_3", "DiaOre_4",
            "DiaOre_5", "DiaOre_6", "DiaOre_7", "DiaOre_8",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Glass,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Mineral, attrib_feel = GiftFeel.Box,
        only_on_map = "ttt_minecraft_b5",
    },
    mc_b5_gold = GiftData.New {
        name     = "Gold Block",         desc       = "a gold block",
        category = GiftCategory.PhysBox, identifier = "GoldBlock",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Mineral,  attrib_feel = GiftFeel.Box,
        only_on_map = "ttt_minecraft_b5",
    },
    mc_b5_cd = GiftData.New {
        name     = "Music Disc (cat)",   desc        = "a music disc",
        category = GiftCategory.PhysBox, identifiers = {
            "Music_CD_01", "Music_CD_02", "Music_CD_03",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Mineral, attrib_feel = GiftFeel.Flat,
        only_on_map = "ttt_minecraft_b5",
    },
    oldruins_tankard = GiftData.New {
        name     = "Tavern Tankard",     desc        = "a wooden tankard",
        category = GiftCategory.PhysBox, identifiers = {
            "*12", "*13", "*14", "*15", "*17", "*18", "*19", "*20",
            "*21", "*22", "*23", "*24", "*25", "*33", "*35", "*37"
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Alcohol,   attrib_feel = GiftFeel.Medieval,
        only_on_map = "ttt_oldruins",
    },
    rpg_village_dynamite = GiftData.New {
        name     = "Dynamite",           desc        = "dynamite",
        category = GiftCategory.PhysBox, identifiers = {
            "dynamite1", "dynamite2", "dynamite3", "dynamite4",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hissing,   attrib_size = GiftSize.Large,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Powerful,
        adjustments = {
            visual_override = { path = "custom/rpg_dynamite", type = "sprite" }
        },
        only_on_map = "ttt_rpgvillage", paper_cost = 30,
    },
    rpg_village_firekey = GiftData.New {
        name     = "Burning Rod",        desc       = "a torch",
        category = GiftCategory.PhysBox, identifier = "firekey",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Ash,       attrib_feel = GiftFeel.Long,
        only_on_map = "ttt_rpgvillage",
    },
    seliana_carpet = GiftData.New {
        name     = "Carpet",             desc       = "a fancy carpet",
        category = GiftCategory.PhysBox, identifier = "Carpet",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Max,
        attrib_smell = GiftSmell.Dusty,    attrib_feel = GiftFeel.Soft,
        only_on_map = "ttt_seliana",
    },
    ski_resort_cereal = GiftData.New {
        name     = "Cereal Box",         desc       = "a cereal box",
        category = GiftCategory.PhysBox, identifier = "cereal_box",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Granular, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Food,     attrib_feel = GiftFeel.Box,
        only_on_map = "ttt_ski_resort",
    },
    ski_resort_holy_watermelon = GiftData.New {
        name     = "Holy Watermelon",    desc       = "the holy watermelon",
        category = GiftCategory.PhysBox, identifier = "godcrown",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Magical,
        only_on_map = "ttt_ski_resort",
        adjustments = { holy_watermelon_detect = { is_holy = true } },
    },
    townstreets_cutting_board = GiftData.New {
        name     = "Cutting Board",      desc       = "a cutting board",
        category = GiftCategory.PhysBox, identifier = "*62",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Food,   attrib_feel = GiftFeel.Flat,
        only_on_map = "ttt_townstreets",
    },
    vessel_floor_bit = GiftData.New {
        name     = "Metal Floor Bit",    desc        = "a broken bit of floor",
        category = GiftCategory.PhysBox, identifiers = {
            {mdl="*20", size=GiftSize.Larger},
            {mdl="*21", size=2.3},
            {mdl="*22", size=3},
            {mdl="*23", size=GiftSize.Big},
            {mdl="*24", size=3},
            {mdl="*25", size=3},
            {mdl="*26", size=3},
            {mdl="*27", size=GiftSize.Big},
            {mdl="*28", size=GiftSize.Big},
            {mdl="*29", size=2.6},
            {mdl="*31", size=3},
            {mdl="*33", size=GiftSize.Larger},
            {mdl="*30", size=2.3},
            {mdl="*32", size=2.3},
            {mdl="*91", size=2.3},
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Thudding, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Flat,
        only_on_map = "ttt_vessel",
    },
    vessel_ship_wheel = GiftData.New {
        name     = "Ship's Wheel",       desc       = "the ship's wheel",
        category = GiftCategory.PhysBox, identifier = "wheel",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Creaky, attrib_size = 4.5,
        attrib_smell = GiftSmell.Salty,  attrib_feel = GiftFeel.Round,
        only_on_map = "ttt_vessel",
    },
    yesterwind_barrel = GiftData.New {
        name     = "Yesterwind Barrel",  desc        = "a large barrel",
        category = GiftCategory.PhysBox, identifiers = {
            "*3", "*4", "*5", "*6", "*7", "*11",
        },
        can_be_random_gift = false,
        attrib_sound = GiftSound.Hollow, attrib_size = 4.5,
        attrib_smell = GiftSmell.Woody,  attrib_feel = GiftFeel.Round,
        only_on_map = "ttt_yesterwind",
    },
})

table.Merge(giftDataCatalog, { -- Ragdolls
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
    citizen_corpse = GiftData.New {
        name     = "Dead Citizen",       desc        = "a body",
        category = GiftCategory.Ragdoll, identifiers = {
            "models/player/group01/male_01.mdl",
            "models/player/group01/male_02.mdl",
            "models/player/group01/male_03.mdl",
            "models/player/group01/male_04.mdl",
            "models/player/group01/male_05.mdl",
            "models/player/group01/male_06.mdl",
            "models/player/group01/male_07.mdl",
            "models/player/group01/male_08.mdl",
            "models/player/group01/male_09.mdl",
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
    mossman_corpse = GiftData.New {
        name     = "Dead Mossman",       desc       = "Mossman's body",
        category = GiftCategory.Ragdoll, identifier = "models/mossman.mdl",
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
        name     = "Dead G-Man",         desc        = "the G-Man's body",
        category = GiftCategory.Ragdoll, identifiers = {
            "models/gman.mdl",
            "models/player/gman_high.mdl",
        },
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
        only_on_map = "ttt_unsung_star",
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
        attrib_smell = GiftSmell.Dry,      attrib_feel = GiftFeel.Spooky,
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
})

table.Merge(giftDataCatalog, { -- Vehicles & Seats
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
        adjustments = {
            set_angles = Angle(-90, 0, 0),
            auto_drive = true
        },
    },

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
        adjustments = { auto_drive = true },
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
        adjustments = { auto_drive = true },
    },
})

table.Merge(giftDataCatalog, { -- Scripted Entities
    banana_split = GiftData.New {
        name     = "Live Banana Split", desc      = "dangerous levels of potassium",
        category = GiftCategory.SENT,  identifier = "ttt_banana_split",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -7,
        attrib_sound = GiftSound.Squishy,   attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Gunpowder, attrib_feel = GiftFeel.Fresh,
        adjustments = {
            grenade_auto = { explosion_delay = 2 },
            set_owner = true
        }
    },
    bouncy_ball = GiftData.New {
        name     = "Bouncy Ball",     desc       = "a colorful ball",
        category = GiftCategory.SENT, identifier = "sent_ball",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 1,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Strange, attrib_feel = GiftFeel.Round,
        adjustments = {
            bouncy_ball_random_size = true,
            visual_override = { path = "sprites/sent_ball", type = "sprite" }
        },
    },
    bouncy_ball_deadly = GiftData.New {
        name     = "Harmful Bouncy Ball", desc       = "a colorful ball",
        category = GiftCategory.SENT,     identifier = "deadly_ball",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Strange, attrib_feel = GiftFeel.Round,
        adjustments = {
            bouncy_ball_random_size = true,
            visual_override = { path = "sprites/sent_ball", type = "sprite" }
        },
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
        adjustments = {
            up_throw = { vel = 400, min = 0, max = 2 }
        },
    },
    det_hat = GiftData.New {
        name     = "Detective Hat",   desc       = "a hat",
        category = GiftCategory.SENT, identifier = "ttt_hat_deerstalker",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 4,
        attrib_sound = GiftSound.None, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Wool, attrib_feel = GiftFeel.Sus,
        paper_cost = 10,
    },
    flame = GiftData.New {
        name     = "Flame",           desc       = "a flame",
        category = GiftCategory.SENT, identifier = "ttt_flame",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = -3,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Ash,       attrib_feel = GiftFeel.Hot,
        adjustments = {
            flame_wrap = true,
            visual_override = { path = "particles/flamelet4", type = "sprite" },
            up_throw = { vel = 300, min = 1, max = 2 },
        },
    },
    force_shield = GiftData.New {
        name     = "Live Force Shield", desc       = "a next-gen force shield",
        category = GiftCategory.SENT,   identifier = "force_shield",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Pulsing,     attrib_size = 10,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Futuristic,
        adjustments = {
            mark_invalid  = true,
            ambush_giftee = { angle = 90, face_wrapper = true },
            force_shield_sfx = true,
        },
        paper_cost = 15
    },
    green_demon = GiftData.New {
        name     = "Live Green Demon", desc       = "a 1-UP",
        category = GiftCategory.SENT,  identifier = "sent_greendemon",
        can_be_random_gift = true,
        factor_rarity = 10, factor_quality = -10,
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Cursed,
        adjustments = {
            green_demon_wrap = true,
            set_owner = true,
            visual_override = { path = "models/entities/entities/sent_greendemon/gd.png", type = "sprite" },
        },
    },
    kfc = GiftData.New {
        name     = "KFC Bucket",      desc       = "a bucket o' chicken",
        category = GiftCategory.SENT, identifier = "ttt_kfc",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 6,
        attrib_sound = GiftSound.Squishy, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Warm,
        paper_cost = 10,
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
        adjustments = {
            up_throw = { vel = 800, min = 1, max = 3, angvel = 0 }
        },
        paper_cost = 5,
    },
    molotov_grenade = GiftData.New {
        name     = "Live Molotov Cocktail (Timed)", desc       = "a spicy cocktail",
        category = GiftCategory.SENT,               identifier = "sent_molotov_timed",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Oily,      attrib_feel = GiftFeel.Hot,
        adjustments = {
            timed_molotov_wrap = true,
            set_owner = true,
        },
        paper_cost = 100,
    },
    moonball = GiftData.New {
        name     = "Moonball",        desc       = "a bouncy marble",
        category = GiftCategory.SENT, identifier = "moonball",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = -1,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Mini,
        attrib_smell = GiftSmell.Mineral, attrib_feel = GiftFeel.Round,
        adjustments = {
            moonball_spawn = true,
            up_throw = { vel = 200 },
        },
        paper_cost = 5,
    },
    present = GiftData.New {
        name     = "Present",         desc       = "a different type of gift",
        category = GiftCategory.SENT, identifier = "christmas_present",
        can_be_random_gift = true,
        factor_rarity = 0.8, factor_quality = 4,
        attrib_sound = GiftSound.Rustling, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Paper,    attrib_feel = GiftFeel.Jolly,
        adjustments = { snuffles_present_spawn = true },
    },
    seekgull = GiftData.New {
        name     = "Live Seekgull",   desc       = "a homing seagull",
        category = GiftCategory.SENT, identifier = "ttt_seekgull_bird",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -5,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Salty,     attrib_feel = GiftFeel.Alive,
        adjustments = { set_owner = true, seekgull_wrap = true },
    },
    shard_of_greed = GiftData.New {
        name     = "Shard of Greed",  desc       = "an ominous shard",
        category = GiftCategory.SENT, identifier = "ttt_shard_of_greed",
        can_be_random_gift = true,
        factor_rarity = 0.7, factor_quality = 2,
        attrib_sound = GiftSound.Glass, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Clay,  attrib_feel = GiftFeel.Cursed,
        adjustments = {
            up_throw = { vel = 400, min = 0, max = 2 },
            pog_shard_role = true,
        },
        paper_cost = 5,
    },
})

table.Merge(giftDataCatalog, { -- NPCs
    alyx = GiftData.New {
        name     = "Alyx Vance",     desc       = "Alyx",
        category = GiftCategory.NPC, identifier = "npc_alyx",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Talking, attrib_size = 6,
        attrib_smell = GiftSmell.Leather, attrib_feel = GiftFeel.Alive,
    },
    bunger = GiftData.New {
        name     = "Live Bunger",    desc       = "a Bunger",
        category = GiftCategory.NPC, identifier = "npc_headcrab_fast",
        can_be_random_gift = true,
        factor_rarity = 0.7, factor_quality = 10,
        attrib_sound = GiftSound.Springy, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Food,    attrib_feel = GiftFeel.Alive,
        adjustments = {
            bunger_setup = true,
            visual_override = { path = "models/betterbunger.mdl", type = "model" },
            spawn_info = { msg = "This Bunger is friendly and won't damage anyone!\nThe speed of its propeller hat reflects its health, which is refilled on unwrap.", post_spawn = true },
        },
    },
    breen = GiftData.New {
        name     = "Dr. Wallace Breen", desc       = "Dr. Breen",
        category = GiftCategory.NPC,    identifier = "npc_breen",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Talking, attrib_size = 6,
        attrib_smell = GiftSmell.Cotton,  attrib_feel = GiftFeel.Powerful,
    },
    citizen = GiftData.New {
        name     = "Citizen",        desc       = "a friend",
        category = GiftCategory.NPC, identifier = "npc_citizen",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = 8,
        attrib_sound = GiftSound.Talking, attrib_size = 6,
        attrib_smell = GiftSmell.Nice,    attrib_feel = GiftFeel.Alive,
    },
    city_scanner = GiftData.New {
        name     = "City Scanner",   desc       = "a self-flying drone",
        category = GiftCategory.NPC, identifier = "npc_cscanner",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = -3,
        attrib_sound = GiftSound.Clicky,  attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Bright,
        adjustments = { cscanner_mute = true },
    },
    eli = GiftData.New {
        name     = "Dr. Eli Vance",  desc       = "Eli",
        category = GiftCategory.NPC, identifier = "npc_eli",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Talking,  attrib_size = 6,
        attrib_smell = GiftSmell.Metallic, attrib_feel = GiftFeel.Alive,
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
    headcrab_lamarr = GiftData.New {
        name     = "Lamarr the Headcrab", desc       = "an friendly pet crab",
        category = GiftCategory.NPC,      identifier = "monster_generic", -- will need stronger detection if other maps have this class for other mobs
        can_be_random_gift = false,
        attrib_sound = GiftSound.Fleshy, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Rotten, attrib_feel = GiftFeel.Alive,
    },
    kleiner = GiftData.New {
        name     = "Dr. Isaac Kleiner", desc       = "Dr. Kleiner",
        category = GiftCategory.NPC,    identifier = "npc_kleiner",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = 5,
        attrib_sound = GiftSound.Talking, attrib_size = 6,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Scientific,
    },
    rollermine = GiftData.New {
        name     = "Rollermine",     desc       = "a rollermine",
        category = GiftCategory.NPC, identifier = "npc_rollermine",
        can_be_random_gift = true,
        factor_rarity = 3, factor_quality = -9,
        attrib_sound = GiftSound.Pulsing, attrib_size = GiftSize.Big,
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Electric,
        adjustments = { rollermine_mute = true },
    },
    zombie = GiftData.New {
        name     = "Zombie",          desc       = "a zombie",
        category = GiftCategory.NPC, identifier = "npc_zombie",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = -7,
        attrib_sound = GiftSound.Fleshy, attrib_size = GiftSize.Gigantic,
        attrib_smell = GiftSmell.Rotten, attrib_feel = GiftFeel.Alive,
    },
})

table.Merge(giftDataCatalog, { -- WorldSWEPs / AutoEquipSWEPs
    boomerang = GiftData.New {
        name     = "Boomerang",            desc       = "a brand-new boomerang",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_boomerang",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Paint,     attrib_feel = GiftFeel.Light,
        adjustments = { set_angles = Angle(0, 0, 90) },
    },
    binoculars = GiftData.New {
        name     = "Binoculars",           desc       = "a pair of binoculars",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_binoculars",
        can_be_random_gift = true,
        factor_rarity = 1, factor_quality = 3,
        attrib_sound = GiftSound.Glass,       attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Sturdy,
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
        attrib_smell = GiftSmell.Medicine, attrib_feel = GiftFeel.Electric,
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
        attrib_smell = GiftSmell.Bloody,  attrib_feel = GiftFeel.Scientific,
    },
    doppelganger = GiftData.New {
        name     = "Doppelganger",         desc       = "a hologram maker",
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
        attrib_sound = GiftSound.Muffled, attrib_size = GiftSize.Larger,
        attrib_smell = GiftSmell.Stinky,  attrib_feel = GiftFeel.Round,
        adjustments = { visual_override = { path = "models/props/cs_office/paper_towels.mdl", type = "model" } },
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
        attrib_smell = GiftSmell.Sterile, attrib_feel = GiftFeel.Spooky,
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
        attrib_smell = GiftSmell.Medicine, attrib_feel = GiftFeel.Electric,
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
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Spooky,
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
        adjustments = {
            sandwich_spoil = true,
            spawn_info = { msg = "Will spoil 2 to 5 seconds after being spawned.", post_spawn = false },
        },
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
        attrib_sound = GiftSound.Musical, attrib_size = GiftSize.Huge,
        attrib_smell = GiftSmell.Strange, attrib_feel = GiftFeel.Sharp, -- could also go with Cursed but Sharp is underused
        adjustments = { sopd_spawn = true },
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
        adjustments = {
            visual_override = { path = "models/weapons/w_stunbaton", type = "model" }
        },
    },
    teleporter = GiftData.New {
        name     = "Teleporter",           desc       = "a high-tech flip phone",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_teleport",
        can_be_random_gift = true,
        factor_rarity = 2, factor_quality = 4,
        attrib_sound = GiftSound.Beeping,     attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Nondescript, attrib_feel = GiftFeel.Futuristic,
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
        name     = "Viral Syringe",        desc       = "a disease",
        category = GiftCategory.WorldSWEP, identifier = "weapon_ttt_virussyringe",
        can_be_random_gift = false,
        attrib_sound = GiftSound.Metallic, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Medicine, attrib_feel = GiftFeel.Sharp,
    },
    weapon_jammer = GiftData.New {
        name     = "Weapon Jammer",            desc       = "a Weapon Jammer",
        category = GiftCategory.AutoEquipSWEP, identifier = "weapon_ttt_wpnjammer",
        can_be_random_gift = true,
        factor_rarity = 7, factor_quality = 6,
        attrib_sound = GiftSound.Muffled, attrib_size = GiftSize.Normal,
        attrib_smell = GiftSmell.Sterile,  attrib_feel = GiftFeel.Negative,
    },
})

table.Merge(giftDataCatalog, { -- Shop Items
    amaterasu = GiftData.New {
        name     = "Amaterasu",       desc       = "Naruto-branded contacts",
        category = GiftCategory.Item, identifier = "amaterasu_name",
        can_be_random_gift = true,
        factor_rarity = 4, factor_quality = -8,
        attrib_sound = GiftSound.Whooshing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Ash,       attrib_feel = GiftFeel.Cursed,
        adjustments = { amaterasu_buy = true },
    },
    blue_bull = GiftData.New {
        name     = "Blue Bull",       desc       = "wings",
        category = GiftCategory.Item, identifier = "item_ttt_blue_bull",
        can_be_random_gift = true,
        factor_rarity = 6, factor_quality = 9,
        attrib_sound = GiftSound.Splashing, attrib_size = GiftSize.Small,
        attrib_smell = GiftSmell.Food,      attrib_feel = GiftFeel.Cold,
        adjustments = { item_buy = "item_ttt_blue_bull" },
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
        adjustments = { pap_setup = true },
        can_get_multiple = true
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
})


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
               SENT_adj = { stick_to_ground = true },
               SENT_random = false, --SENT_rarity = 3, SENT_quality = 6,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Small,
               sound = GiftSound.Beeping, smell = GiftSmell.Gunpowder, feel = GiftFeel.Electric},

    banana  = {SENT_name = "Banana Peel", SENT_desc = "an old banana peel",
               SWEP_name = "Banana",      SWEP_desc = "a fresh banana",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_banana_peel", SWEP_id = "ttt_banana",
               SENT_adj = {
                   set_angles = Angle(90, 0, 0),
                   produce_flies = true,
               },
               SENT_cost = 10,
               SWEP_adj = { visual_override = { path = "models/props/cs_italy/bananna", type = "model" }},
               SENT_random = true, SENT_rarity = 1, SENT_quality = -5,
               SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Small,
               sound = GiftSound.Squishy, smell = GiftSmell.Rotten, feel = GiftFeel.Slippery,
               SWEP_smell = GiftSmell.Food, SWEP_feel = GiftFeel.Fresh},

    banana_bomb = {name = "Banana Bomb", desc = "an explosive bunch",
               SENT_id = "ttt_banana_proj", SWEP_id = "weapon_ttt_banana",
               SENT_adj = {
                   grenade   = { explosion_delay = 2 },
                   set_owner = true,
               },
               SENT_cost = 100,
               SWEP_adj = { visual_override = { path = "models/props/cs_italy/bananna_bunch.mdl", type = "model"}},
               SENT_random = true, SENT_rarity = 6, SENT_quality = -10,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Large,
               sound = GiftSound.Springy, smell = GiftSmell.Gunpowder, feel = GiftFeel.Fresh},

    barnacle  = {name = "Barnacle", desc = "a hungry barnacle",
               SWEP_desc = "a hungry pet barnacle",
               SENT_category = GiftCategory.NPC,
               SENT_id = "npc_barnacle", SWEP_id = "weapon_ttt_barnacle",
               SENT_adj = {
                   barnacle_setup = true,
                   produce_flies = true,
               },
               SENT_random = true, SENT_rarity = 3, SENT_quality = -9,
               SWEP_random = false,
               SENT_size = GiftSize.Gigantic, SWEP_size = GiftSize.Large,
               sound = GiftSound.Fleshy, smell = GiftSmell.Rotten, feel = GiftFeel.Alive},

    baron_hat = {name = "Baron Hat", desc = "a bougie hat",
               SWEP_category = GiftCategory.Item,
               SENT_id = "ttt2_hat_baron", SWEP_id = "item_ttt2_baron_hat",
               SENT_adj = { baron_hat_drop = true },
               SWEP_adj = { baron_hat_buy = true },
               SENT_random = true, SENT_rarity = 1, SENT_quality = 8,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.None, smell = GiftSmell.Leather, feel = GiftFeel.Round},

    beacon  = {name = "Beacon", desc = "a high-tech beacon",
               SENT_id = "ttt_beacon", SWEP_id = "weapon_ttt_beacon",
               SENT_adj = { set_thrower = true },
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
               SENT_adj = {
                   c4_wrap = true,
                   follow_gift = true,
               },
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
               SENT_adj = { set_owner = true },
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Glass, smell = GiftSmell.Food, feel = GiftFeel.Round},

    clusterbomb = {name = "Clusterbomb", desc = "a furniture bomb",
               SENT_id = "ttt_rclutterbomb_proj", SWEP_id = "weapon_ttt_rclutterbomb",
               SENT_adj = { grenade = true },
               SENT_random = true, SENT_rarity = 3, SENT_quality = -6,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Beeping, smell = GiftSmell.Dusty, feel = GiftFeel.Random,
               SWEP_desc = "a rigged furniture bomb"},

    clutterbomb = {name = "Clutterbomb", desc = "a furniture bomb",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_clutterbomb_proj", SWEP_id = "weapon_ttt_clutterbomb",
               SENT_adj = { grenade = true },
               SENT_random = true, SENT_rarity = 1, SENT_quality = -3,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = -1,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Thudding, smell = GiftSmell.Dusty, feel = GiftFeel.Random},

    conc_mine = {name = "Concussion Mine", desc = "a whoopie cushion",
               SENT_id = "ttt_conmine", SWEP_id = "weapon_ttt_concussionmine",
               SENT_adj = {
                   conc_mine_wrap = true,
                   set_owner = true,
               },
               SENT_cost = 35,
               SENT_random = true, SENT_rarity = 4, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Beeping, smell = GiftSmell.Sterile, feel = GiftFeel.Hollow},

    ctrl_manhack = {name = "Controllable Manhack", desc = "a remote-control drone",
               SENT_id = "sent_controllable_manhack", SWEP_id = "weapon_controllable_manhack",
               SENT_adj = { manhack_stop_control = true },
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 2, SWEP_quality = 6,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Whirring, smell = GiftSmell.Rusty, feel = GiftFeel.Bursting},

    d20     = {name = "D20",             desc = "a DND dice",
               SENT_id = "ttt_d20_proj", SWEP_id = "ttt_d20",
               SENT_adj = { grenade = true },
               SENT_random = false, --SENT_rarity = 20, SENT_quality = 0,
               SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Glass, smell = GiftSmell.Mineral, feel = GiftFeel.Random},

    decoy   = {name = "Decoy",        desc = "a high-tech decoy",
               SENT_id = "ttt_decoy", SWEP_id = "weapon_ttt_decoy",
               SENT_adj = { follow_gift = true },
               SENT_random = false,   SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whirring, smell = GiftSmell.Sterile, feel = GiftFeel.Scientific},

    deployable_force_shield = {name = "Deployable Force Shield", desc = "a next-gen force shield",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "shield_deployer", SWEP_id = "weapon_ttt_force_shield",
               SENT_adj = { shield_deployer_spawn = true },
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Pulsing, smell = GiftSmell.Nondescript, feel = GiftFeel.Bright,
               SWEP_smell = GiftSmell.Sterile},

    discombob = {name = "Discombobulator", desc = "an air-filled grenade",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_confgrenade_proj", SWEP_id = "weapon_ttt_confgrenade",
               SENT_adj = { grenade = {explosion_delay = 0.2} },
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Whooshing, smell = GiftSmell.Gunpowder, feel = GiftFeel.Hollow},

    emp     = {name = "EMP Grenade", desc = "an EMP grenade",
               SENT_id = "ttt_emp_proj", SWEP_id = "weapon_ttt_emp",
               SENT_adj = { grenade = {explosion_delay = 3} },
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Pulsing, smell = GiftSmell.Nondescript, feel = GiftFeel.Electric},

    fan     = {name = "Fan", desc = "a powerful fan",
               SENT_id = "ent_ttt_fan", SWEP_id = "weapon_fan",
               SENT_adj = {
                   fan_spawn = true,
                   ambush_giftee = { angle = -90, y_off = 18 },
               },
               SENT_cost = 35,
               SENT_random = true, SENT_rarity = 3, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whooshing, smell = GiftSmell.Sterile, feel = GiftFeel.Moving},

    fart_grenade = {name = "Fart Grenade", desc = "bad gas",
               SENT_id = INVALID_ID, SWEP_id = "weapon_fartgrenade",
               SENT_adj = {
                   fart_grenade_setup = true,
                   visual_override = { path = "models/weapons/w_grenade.mdl", type = "model" },
               },
               SENT_random = true, SENT_rarity = 2, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Muffled, smell = GiftSmell.Rotten, feel = GiftFeel.Bursting,
               SWEP_desc = "a cupped fart"},

    fireball = {name = "Fireball", desc = "a fireball", SWEP_desc = "fire magic",
               SENT_category = GiftCategory.PhysProp, SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = INVALID_ID, SWEP_id = "weapon_firemagic",
               SENT_adj = {
                   fireball_wrap = true,
                   unwrap_throw = { delay = 0, rngMult = 0.3, up_only = true, force = 1000 },
                   visual_override = { path = "effects/flame", type = "sprite" },
               },
               SENT_random = false,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Whooshing, smell = GiftSmell.Ash, feel = GiftFeel.Magical},

    flashbang = {name = "Flashbang", desc = "a 5-second blinding stew",
               SENT_id = "ttt_thrownflashbang", SWEP_id = "weapon_ttt_flashbang",
               SENT_adj = {
                   grenade_auto = { explosion_delay = 2 },
               },
               SENT_random = true, SENT_rarity = 4, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Metallic, smell = GiftSmell.Food, feel = GiftFeel.Bright,
               SWEP_desc = "a flashbang"},

    fortnite = {name = "Fortnite Building", desc = "a Fortnite structure",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ent_fortnitestructure", SWEP_id = "weapon_ttt_fortnite_building",
               SENT_adj = {
                   fortnite_struct_setup = true,
                   visual_override = true,
                   no_physwake = true,
               },
               SENT_cost = 10,
               SENT_random = true, SENT_rarity = 1, SENT_quality = 1,
               SWEP_random = true, SWEP_rarity = 7, SWEP_quality = 9,
               SENT_size = 10, SWEP_size = GiftSize.Large,
               sound = GiftSound.Thudding, smell = GiftSmell.Cardboard, feel = GiftFeel.Otherworldly,
               SWEP_desc = "a Fortnite Battle Pass", SENT_name = "Fortnite Structure"},

    frag_grenade = {name = "Frag Grenade", desc = "an actual grenade",
               SENT_id = "ttt_frag_proj", SWEP_id = "weapon_ttt_frag",
               SENT_adj = { grenade = true },
               SENT_cost = 100,
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Thudding, smell = GiftSmell.Gunpowder, feel = GiftFeel.Round},

    giftwrap = {name = "Gift Wrap", desc = "another gift",
               SENT_id = PROP_CLASS_NAME, SWEP_id = SWEP_CLASS_NAME,
               SENT_name = "Wrapped Gift",
               SENT_adj = {
                   random_gift_spawn = true,
                   follow_gift = true,
               },
               SWEP_adj = { giftwrap_desc = true },
               SENT_random = true, SENT_rarity = 0.8, SENT_quality = 2,
               SWEP_random = true, SWEP_rarity = 2,   SWEP_quality = 4,
               SWEP_size = GiftSize.Huge,
               sound = GiftSound.Rustling, smell = GiftSmell.Paper, feel = GiftFeel.Jolly},

    glue_trap = {name = "Glue Trap", desc = "a sticky prank toy", SENT_desc = "glue",
               SENT_id = "glue_trap_paste", SWEP_id = "weapon_ttt_glue_trap",
               SENT_adj = {
                   under_giftee = true,
                   stick_to_ground = true,
               },
               SENT_random = true, SENT_rarity = 1, SENT_quality = -6,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 5,
               SENT_size = GiftSize.Gigantic, SWEP_size = GiftSize.Large,
               sound = GiftSound.Goopy, smell = GiftSmell.Cardboard, feel = GiftFeel.Sticky},

    green_demon_box = {name = "Green Demon Box", desc = "a 1-UP",
               SENT_id = "sent_greendemon_box", SWEP_id = "weapon_ttt_greendemon",
               SENT_adj = {
                   set_owner = true,
                   under_giftee = true,
                   spawn_info = { msg = "Won't trigger until the trap is stepped on a second time." },
               },
               SENT_random = false,
               SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Large,
               sound = GiftSound.Musical, smell = GiftSmell.Food, feel = GiftFeel.Cursed,
               SWEP_desc = "a 1-UP box"},

    groovitron = {name = "Groovitron", desc = "a disco ball",
               SENT_id = "ttt_pap_groovitron_proj", SWEP_id = "ttt_pap_groovitron",
               SENT_adj = {
                   groovitron_wrap = true,
                   mark_invalid = true,
                   grenade = { no_info = true },
               },
               SENT_random = true, SENT_rarity = 3, SENT_quality = -5,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Musical, smell = GiftSmell.Nondescript, feel = GiftFeel.Bright},

    hand_cannon = {
               SENT_name = "Live Cannonball", SENT_desc = "a cannonball",
               SWEP_name = "Hand Cannon",     SWEP_desc = "an old-timey hand cannon",
               SENT_id = "cannon_ent", SWEP_id = "weapon_hcannon",
               SENT_adj = {
                   auto_fire_chance = 1,
                   cannonball_wrap = true,
                   unwrap_throw = { delay = 0, rngMult = 0.1, up_only = true, force = 1000 },
               },
               SWEP_adj = { visual_override = { path = "models/props_phx/cannon.mdl", type = "model" }},
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
               sound = GiftSound.Beeping, smell = GiftSmell.Medicine, feel = GiftFeel.Warm},

    hwapoon = {name = "Hwapoon", desc = "a harpoon",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "hwapoon_arrow", SWEP_id = "weapon_ttt_hwapoon",
               SENT_adj = {
                   set_owner = true,
                   harpoon_unwrap = true,
                   unwrap_throw = { delay = 0.8, rngMult = 0.3, up_only = true, force = 1000 },
               },
               SENT_random = true, SENT_rarity = 4, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Gigantic, SWEP_size = GiftSize.Gigantic,
               sound = GiftSound.Metallic, smell = GiftSmell.Rusty, feel = GiftFeel.Long},

    ice_grenade = {name = "Ice Grenade",    desc    = "an ice trap",
               SENT_id = "icegrenade_proj", SWEP_id = "icegrenade",
               SENT_adj = {
                   set_owner = true,
                   icegrenade_wrap = true,
               },
               SENT_random = true, SENT_rarity = 3, SENT_quality = -5,
               SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Thudding, smell = GiftSmell.Gunpowder, feel = GiftFeel.ReallyCold},

    id_swap_grenade = {name = "Identity Swap Grenade", desc = "a confusion grenade",
               SENT_id = "ttt_id_swap_grenade_proj", SWEP_id = "weapon_ttt_identity_swap_grenade",
               SENT_adj = { grenade = true },
               SENT_random = true, SENT_rarity = 4, SENT_quality = -1,
               SWEP_random = true, SWEP_rarity = 3, SWEP_quality = 1,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Thudding, smell = GiftSmell.Gunpowder, feel = GiftFeel.RealityWarp},

    incend  = {name = "Incendiary Grenade", desc = "a fiery grenade",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_firegrenade_proj", SWEP_id = "weapon_zm_molotov",
               SENT_adj = { grenade = { explosion_delay = 2 } },
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Thudding, smell = GiftSmell.Ash, feel = GiftFeel.Hot},

    jarate  = {name = "Jarate", desc = "a jar of piss",
               SENT_id = "ttt_jarate_proj", SWEP_id = "weapon_ttt_jarate",
               SENT_adj = { set_owner = true, set_thrower = true },
               SENT_random = true, SENT_rarity = 2, SENT_quality = -5,
               SWEP_random = true, SWEP_rarity = 2, SWEP_quality = 4,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Splashing, smell = GiftSmell.Stinky, feel = GiftFeel.Warm},

    killer_bungers = {name = "Bunger Grenade", desc = "a bunch of angry Bungers",
               SENT_id = "ttt_bungernade_proj", SWEP_id = "weapon_ttt_bungernade",
               SENT_adj = { grenade = {explosion_delay = 2} },
               SENT_random = true, SENT_rarity = 5, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Gigantic, SWEP_size = GiftSize.Large,
               sound = GiftSound.Springy, smell = GiftSmell.Food, feel = GiftFeel.Otherworldly},

    knife   = {name = "Knife", desc = "a slick knife",
               SENT_name = "Live Thrown Knife",
               SENT_id = "ttt_knife_proj", SWEP_id = "weapon_ttt_knife",
               SENT_adj = {
                   set_owner = true,
                   break_constraints = true,
               },
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Metallic, smell = GiftSmell.Sterile, feel = GiftFeel.Sharp},

    lethal_mine = {name = "Lethal Mine", desc = "a landmine",
               SWEP_desc = "a landmine gun",
               SENT_id = "item_lethal_company_landmine", SWEP_id = "weapon_ttt_lethalmine",
               SENT_adj = { mark_invalid = true },
               SENT_adj = {
                   under_giftee = true,
                   stick_to_ground = true
               },
               SENT_random = true, SENT_rarity = 10, SENT_quality = -10,
               SWEP_random = false,
               SENT_size = GiftSize.Big, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Beeping, smell = GiftSmell.Gunpowder, feel = GiftFeel.Flat},

    m4_slam  = {name = "M4 SLAM", desc = "a SLAM",
               SENT_id = "ttt_slam_satchel", SWEP_id = "weapon_ttt_slam",
               SENT_adj = { slam_spawn = true },
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Beeping, smell = GiftSmell.Gunpowder, feel = GiftFeel.Electric},

    molotov  = {name = "Molotov Cocktail", desc = "a spicy cocktail",
               SENT_id = "sent_molotov", SWEP_id = "molotov_cocktail_for_ttt",
               SENT_adj = {
                   set_owner = true,
                   unwrap_throw = { delay = 0, rngMult = 0.3, up_only = true, force = 3000 },
               },
               SENT_random = false, SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Splashing, smell = GiftSmell.Oily, feel = GiftFeel.Hot},

    moon_grenade = {name = "Moon Grenade", desc = "a bag of marbles",
               SENT_id = "ent_moongrenade", SWEP_id = "weapon_ttt_moongrenade",
               SENT_adj = {
                   moon_grenade_setup = true,
                   visual_override = { type = "model", path = "models/weapons/moongrenade/moongrenade.mdl" },
               },
               SENT_random = true, SENT_rarity = 2, SENT_quality = -3,
               SWEP_random = false,
               SENT_size = GiftSize.Normal, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Springy, smell = GiftSmell.Mineral, feel = GiftFeel.Otherworldly},

    paper_plane = {name = "Paper Plane", desc = "an origami plane",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ttt_paper_plane_proj", SWEP_id = "weapon_ttt_paper_plane",
               SENT_adj = {
                   paper_plane_mass = true,
                   set_thrower = true,
                   spawn_info = { msg = "Can target anyone other than the player who spawns it, including their teammates!", post_spawn = true, warn = true },
               },
               SENT_random = true, SENT_rarity = 2, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Larger,
               sound = GiftSound.Whooshing, smell = GiftSmell.Paper, feel = GiftFeel.Moving},

    poison_station = {name = "Poison Station", desc = "a healing microwave",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ttt_poison_station", SWEP_id = "weapon_ttt_poison_station",
               SENT_adj = { set_thrower = true },
               SENT_random = false,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Huge,
               sound = GiftSound.Beeping, smell = GiftSmell.Medicine, feel = GiftFeel.Warm,
               SWEP_desc = "a damaging microwave", SWEP_smell = GiftSmell.Toxic},

    poison_station_v2 = {name = "Poison Station v2",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "prop_poison_station_v2", SWEP_id = "weapon_ttt_poison_station_v2",
               SENT_adj = { poison_station_desc = true },
               SENT_random = true, SENT_rarity = 4, SENT_quality = -5,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Huge,
               sound = GiftSound.Beeping, smell = GiftSmell.Medicine, feel = GiftFeel.Warm,
               SWEP_desc = "a poisonous microwave", SWEP_smell = GiftSmell.Toxic},

    pog     = {name = "Pot of Greedier", desc = "Pot of Greed, which lets you draw two additional gifts from your deck",
               SENT_id = "ttt_potofgreedier", SWEP_id = "weapon_ttt_potofgreedier",
               SENT_adj = { pog_set_role = true },
               SENT_random = true, SENT_rarity = 2, SENT_quality = 7,
               SWEP_random = false,
               SENT_size = GiftSize.Big, SWEP_size = GiftSize.Big,
               sound = GiftSound.Glass, smell = GiftSmell.Clay, feel = GiftFeel.Cursed},

    radio   = {name = "Radio", desc = "a toy radio",
               SENT_id = "ttt_radio", SWEP_id = "weapon_ttt_radio",
               SENT_adj = { set_thrower = true },
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
               SWEP_desc = "an RC car in a can",
               SENT_id = "sent_rcxd", SWEP_id = "weapon_ttt_rcxd",
               --SENT_adj = { set_owner = true }, -- doesn't work (would need to give SWEP)
               SENT_random = false, --SENT_rarity = 2, SENT_quality = 5,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Revving, smell = GiftSmell.Rusty, feel = GiftFeel.Electric},

    shellmet = {name = "Shellmet", desc = "a shiny helmet",
               SWEP_category = GiftCategory.Item,
               SENT_id = "ttt2_hat_shellmet", SWEP_id = "item_ttt2_shellmet",
               SENT_adj = {
                   shellmet_phys = true,
                   up_throw = { vel = 200 },
               },
               SENT_cost = 10,
               SENT_random = true, SENT_rarity = 0.8, SENT_quality = 5,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Thudding, smell = GiftSmell.Mineral, feel = GiftFeel.Hollow},

    seekgull_can = {name = "Seekgull in a Can", desc = "a seagull in a can",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_seekgull_proj", SWEP_id = "weapon_ttt_seekgull",
               SENT_adj = { grenade = true, set_owner = true },
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Whooshing, smell = GiftSmell.Salty, feel = GiftFeel.Alive},

    smoke   = {name = "Smoke Grenade", desc = "a pocket fog machine",
               SWEP_category = GiftCategory.FloorSWEP,
               SENT_id = "ttt_smokegrenade_proj", SWEP_id = "weapon_ttt_smokegrenade",
               SENT_adj = { grenade = true },
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 1, SWEP_quality = 0,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Muffled, smell = GiftSmell.Ash, feel = GiftFeel.Hollow},

    soap    = {name = "Soap", desc = "a bar of soap",
               SENT_id = "ttt_soap", SWEP_id = "weapon_ttt_soap",
               SENT_adj = {
                   under_giftee = true,
                   stick_to_ground = true,
                   set_thrower = true,
               },
               SENT_random = true, SENT_rarity = 0.8, SENT_quality = -3,
               SWEP_random = false,
               SENT_size = GiftSize.Mini, SWEP_size = GiftSize.Mini,
               sound = GiftSound.Goopy, smell = GiftSmell.Nice, feel = GiftFeel.Slippery},

    spring_mine = {name = "Spring Mine", desc = "a comically large spring",
               SENT_id = "ttt_springmine", SWEP_id = "weapon_ttt_springmine",
               SENT_adj = {
                   under_giftee = true,
                   stick_to_ground = true,
                   set_thrower = true,
               },
               SENT_random = true, SENT_rarity = 5, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Springy, smell = GiftSmell.Rubbery, feel = GiftFeel.Round},

    star_burster = {name = "Star Burster", desc = "a shooting star",
               SENT_id = "plasma_burster_nade", SWEP_id = "ttt_plasma_burster_nade",
               SENT_adj = {
                   set_owner = true,
                   starburst_ent_wrap = true,
                   unwrap_throw = { delay = 0.3, rngMult = 0.1, force = 1500 },
               },
               SENT_random = true, SENT_rarity = 2, SENT_quality = -4,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Normal,
               sound = GiftSound.Whooshing, smell = GiftSmell.Strange, feel = GiftFeel.Bursting},

    super_discombob = {name = "Super Discombobulator", desc = "an air-packed grenade",
               SENT_id = "ttt_confgrenade_proj_super", SWEP_id = "weapon_ttt_confgrenade_s",
               SENT_adj = { grenade = { explosion_delay = 2 } },
               SENT_cost = 100,
               SENT_random = true, SENT_rarity = 4, SENT_quality = -7,
               SWEP_random = false,
               SENT_size = GiftSize.Huge, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whooshing, smell = GiftSmell.Gunpowder, feel = GiftFeel.Massive},

    super_smoke = {name = "Super Smoke Grenade", desc = "a smog machine from London",
               SENT_id = "ttt_supersmokegrenade_proj", SWEP_id = "weapon_ttt_supersmoke",
               SENT_adj = { grenade = true },
               SENT_random = true, SENT_rarity = 6, SENT_quality = -4,
               SWEP_random = false,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Muffled, smell = GiftSmell.Ash, feel = GiftFeel.Massive},

    teleport_grenade = {name = "Teleport Grenade", desc = "an Ender Pearl",
               SENT_id = "ttt_teleportgren_proj", SWEP_id = "weapon_ttt_teleportgren",
               SENT_adj = {
                   wrap_sleep = true,
                   grenade = { no_info = true },
                   mark_invalid = true,
                   up_throw = { vel = 1000, min = 1, max = 4 },
               },
               SENT_random = true, SENT_rarity = 1,   SENT_quality = 0,
               SWEP_random = true, SWEP_rarity = 0.6, SWEP_quality = 3,
               SENT_size = GiftSize.Small, SWEP_size = GiftSize.Small,
               sound = GiftSound.Pulsing, smell = GiftSmell.Strange, feel = GiftFeel.Otherworldly},

    tesla_bow = {SENT_name = "Live Tesla Bolt", SENT_desc = "an electric bolt",
               SWEP_name   = "Tesla Bow",  SWEP_desc = "an electric bow",
               SENT_id = "sent_teslabow_arrow", SWEP_id = "weapon_ttt_teslabow",
               SENT_adj = {
                   unwrap_throw = { delay = 0.1, rngMult = 0.3, up_only = true, force = 3000 },
                   visual_override = { path = "models/crossbow_bolt.mdl", type = "model" },
                   tesla_bolt_wrap = true,
                   set_owner = true,
               },
               SENT_random = false,
               SWEP_random = true, SWEP_rarity = 10, SWEP_quality = 8,
               SENT_size = GiftSize.Larger, SWEP_size = GiftSize.Huge, SWEP_sound = GiftSound.Springy,
               sound = GiftSound.Whooshing, smell = GiftSmell.Sterile, feel = GiftFeel.Electric },

    turret  = {name = "Turret", desc = "a next-gen turret",
               SENT_category = GiftCategory.NPC,
               SENT_id = "npc_turret_floor", SWEP_id = "weapon_ttt_turret",
               SENT_adj = { ambush_giftee = true },
               SENT_cost = 30,
               SENT_random = true, SENT_rarity = 4, SENT_quality = -8,
               SWEP_random = false,
               SENT_size = GiftSize.Max, SWEP_size = GiftSize.Small,
               sound = GiftSound.Beeping, smell = GiftSmell.Sterile, feel = GiftFeel.Moving},

    visualizer = {name = "Visualizer", desc = "a high-tech crime visualizer",
               SENT_id = "ttt_cse_proj", SWEP_id = "weapon_ttt_cse",
               SENT_adj = { set_thrower = true }, SENT_cost = 10,
               SENT_random = true, SENT_rarity = 1, SENT_quality = -2,
               SWEP_random = false,
               SENT_size = GiftSize.Large, SWEP_size = GiftSize.Large,
               sound = GiftSound.Whirring, smell = GiftSmell.Sterile, feel = GiftFeel.Bright},

    wormhole_vent = {name = "Wormhole-Vent", desc = "a suspicious grate",
               SWEP_category = GiftCategory.AutoEquipSWEP,
               SENT_id = "ttt_wormhole", SWEP_id = "ttt_wormholecaller",
               SENT_adj = {
                   stick_to_ground = { ground_angles = Angle(0, 0, 0) }
               },
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
        adjustments = data.SENT_adj,
        paper_cost = data.SENT_cost,
    })

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
        adjustments = data.SWEP_adj,
    })
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
    juggernog = {name="Juggernog",           adj="an invigorating", random=true,  rarity = 6, quality = 9, smell = GiftSmell.Medicine},
    phd       = {name="PHD Flopper",         adj="an explosive",    random=false, smell = GiftSmell.Gunpowder},
    doubletap = {name="Doubletap Root Beer", adj="a sweet-tasting", random=false, smell = GiftSmell.Alcohol},
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
        adjustments = { item_buy = "item_ttt_"..label },
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

    -- play extra sound
    local sound = self:GetSound(giftObj)

    if sound and sound.snd ~= "" then
        timer.Simple(0.3, function()
            if IsValid(giftObj) then
                local sndPath = (type(sound.snd) == "table" and sound.snd[math.random(#sound.snd)] or sound.snd)
                local volume = (self.lastCheckType == 0 and 0.3 or 0.1) + (sound.bst and sound.bst/10 or 0)
                giftObj:EmitSound(sndPath, 75, math.random(98, 102), volume, CHAN_STATIC)
            end
        end)
    end

    if self.lastCheckType == 0 then -- sound
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
        local idData = self.identifiers[chosenID > 0 and chosenID or math.random(#self.identifiers)]

        return idData.mdl and idData.mdl or idData
    else
        return self.identifier
    end
end

function GiftData:GetSize(giftObj, wrappedEnt)
    if self.identifiers and IsValid(giftObj) then
        local idData = self.identifiers[giftObj:GetNW2Int("chosen_id")]

        if idData and idData.size then
            return idData.size
        end
    end

    if not wrappedEnt and IsValid(giftObj) then
        wrappedEnt = giftObj:GetStoredGift()
    end

    if IsValid(wrappedEnt) and wrappedEnt:GetClass() == PROP_CLASS_NAME then
        return wrappedEnt:GetGiftScale()
    end

    return self.attrib_size
end

function GiftData:IsSpawnable(giftee, giftObj, anyID)
    if self.only_on_map then
        return string.StartsWith(game.GetMap(), self.only_on_map)
    end

    local canSpawn = utils.AdjustmentRun("can_spawn", nil, self.adjustments, giftObj, giftee)
    if canSpawn ~= nil then
        return canSpawn
    end

    -- model collection
    if self.identifiers and IsValid(giftObj) and anyID then
        for _, idData in ipairs(self.identifiers) do
            if util.IsValidModel(idData.mdl or idData) then
                return true
            end
        end

        return false
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

function GiftData:GetPaperAmount(giftObj, wrappedEnt)
    if not wrappedEnt and IsValid(giftObj) then
        wrappedEnt = giftObj:GetStoredGift()
    end

    if IsValid(wrappedEnt) and wrappedEnt:IsRagdoll()
      and CORPSE.IsValidBody(wrappedEnt) and CORPSE.IsRealPlayerCorpse(wrappedEnt) then
        return 100 -- unwrappable
    end

    if self.paper_cost then
        return self.paper_cost
    end

    local size = self:GetSize(giftObj, wrappedEnt) -- formula calibrated via f(1) = 5, f(7) = 20
    return math.Round(2.5 * (size+1)) + (self.category.paper or 5)
end

function GiftData:ApplyOnWrapAdjustments(wrappedEnt, giftObj)
    if self.identifiers and wrappedEnt.GetModel then
        local mdl = wrappedEnt:GetModel()

        for i, idData in ipairs(self.identifiers) do
            if mdl == (idData.mdl and idData.mdl or idData) then
                giftObj:SetNW2Int("chosen_id", i)
                break
            end
        end
    end

    if wrappedEnt.IsADisguise then
        wrappedEnt.TiedPly:SetParent(wrappedEnt)
        wrappedEnt.TiedPly.StoredTimeLeft = wrappedEnt.TiedPly:GetNWFloat("PD_TimeLeft") - CurTime()
        timer.Pause(wrappedEnt.TiedPly:SteamID().."_DisguiseTime")

        wrappedEnt.TiedPly:ChatPrint("Your disguise has been wrapped!")
        timer.Simple(2, function()
            if IsValid(wrappedEnt) and IsValid(wrappedEnt.TiedPly) then
                wrappedEnt.TiedPly:ChatPrint("NOTE: You can free yourself from the giftbox by undisguising.")
            end
        end)
    end

    if self.category == GiftCategory.Vehicle or wrappedEnt.IsADisguise then
        utils.adjustments.follow_gift.on_wrap(wrappedEnt)
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
                cannibal:ChatPrint("Your meal was interrupted by Gift Wrap.")
            end
        end

        if not self.disable_flies or isValidBody then
            utils.adjustments.produce_flies.on_wrap(wrappedEnt)
        end
    end

    if wrappedEnt:IsOnFire() then
        wrappedEnt:Extinguish()
        giftObj:SetIsContentsOnFire(true)
    end

    ----------------------------------------------
    utils.ApplyAdjustments("wrap", wrappedEnt, giftee, self.adjustments)
end

function GiftData:ApplyOnAutoWrapAdjustments(giftObj)
    if self.identifiers then
        local validIDs = {}

        for id, idData in ipairs(self.identifiers) do
            if util.IsValidModel(idData.mdl or idData) then
                table.insert(validIDs, id)
            end
        end

        giftObj:SetNW2Int("chosen_id", validIDs[math.random(#validIDs)])
    end

    if self.category == GiftCategory.Ragdoll and not self.disable_flies then
        utils.adjustments.produce_flies.on_autowrap(nil, nil, { giftbox = giftObj })
    end

    ---------------------------------------------
    utils.ApplyAdjustments("autowrap", nil, nil, self.adjustments, giftObj)
end

function GiftData:ApplyPreSpawnAdjustments(wrappedEnt, giftee, giftObj)
    if IsValid(wrappedEnt) then
        wrappedEnt:SetNWEntity("GW_Spawner", giftee)
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

    ---------------------------------------------
    return utils.ApplyAdjustments("spawn", wrappedEnt, giftee, self.adjustments, giftObj)
end

function GiftData:ApplyPostUnwrapAdjustments(wrappedEnt, giftee, giftObj, isUndo)
    if IsValid(wrappedEnt) then
        wrappedEnt:SetNWEntity("GW_Wrapper", giftee)

        if wrappedEnt:GetNW2Bool("GWStinky") then -- particles need refreshing for some reason
            ParticleEffectAttach("flies_fx", PATTACH_ABSORIGIN_FOLLOW, wrappedEnt, 0)
        end

        if wrappedEnt.IsADisguise then
            wrappedEnt.TiedPly:SetParent(NULL)
            timer.UnPause(wrappedEnt.TiedPly:SteamID().."_DisguiseTime")
        end

        if self.category == GiftCategory.Vehicle or wrappedEnt.IsADisguise then
            utils.adjustments.follow_gift.on_unwrap(wrappedEnt)
        end
    end

    if self.category == GiftCategory.Ragdoll then
        utils.adjustments.produce_flies.on_unwrap(wrappedEnt)
    end

    if IsValid(giftObj) and giftObj:GetIsContentsOnFire() then
        wrappedEnt:Ignite(60, 100)
        giftObj:SetIsContentsOnFire(false)
    end

    ---------------------------------------------
    utils.ApplyAdjustments({name="unwrap", state=isUndo}, wrappedEnt, giftee, self.adjustments, giftObj)
end

function GiftData:ApplyPostGiftPurchaseAdjustments(giftObj, giftee)
    utils.ApplyAdjustments("purchase", nil, giftee, self.adjustments, giftObj)
end

function GiftData:GetName(giftEnt, giftee)
    local wrappedEnt = giftEnt:GetStoredGift()

    if IsValid(wrappedEnt) and self.category == GiftCategory.Ragdoll then
        local storedTeam = wrappedEnt:GetNWString("GWStoredTeam")

        if storedTeam ~= "" and (CORPSE.GetFound(wrappedEnt) or utils.IsOmniscient(giftee)) then
            return "Dead "..storedTeam
        end
    end

    local customName = utils.AdjustmentRun("gift_name", wrappedEnt, self.adjustments, giftEnt, giftee)
    if customName then
        return customName
    end

    return self.name
end

function GiftData:GetDesc(giftEnt, giftee, forOthers, forMenu)
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

    local desc = self.desc

    local customDesc = utils.AdjustmentRun("gift_desc", wrappedEnt, self.adjustments, giftEnt, giftee, {
        for_others = forOthers,
        for_menu = forMenu,
    })

    if customDesc then
        desc = customDesc
    end

    if forOthers then
        desc = desc:gsub("lets you", "lets them")
                   :gsub("for you", "for them")
                   :gsub("your", "their")
                   :gsub("you", "they")
    end

    return desc
end

function GiftData:GetSound(giftEnt)
    if self.category == GiftCategory.Ragdoll then
        local wrappedEnt = giftEnt:GetStoredGift()

        if CORPSE.IsValidBody(wrappedEnt) then
            -- player-dependent easter eggs
            local deadPlyNick = string.lower(CORPSE.GetPlayerNick(wrappedEnt))
            local deadPlyID = wrappedEnt:GetNWString("GWStoredSID")

            if string.find(deadPlyNick, "cow", nil, true) then
                return GiftSound.Mooing

            elseif string.find(deadPlyNick, "cat", nil, true) or
              deadPlyID == "76561197999258534" or -- Max
              deadPlyID == "76561198068281034" then --EvKem
                return GiftSound.Meowing

            elseif string.find(deadPlyNick, "sheep", nil, true) then
                return GiftSound.Bleating

            elseif string.find(deadPlyNick, "pig", nil, true) then
                return GiftSound.Oinking
            end
        end
    end

    return self.attrib_sound
end

function GiftData:GetSmell(giftEnt)
    local customSmell = utils.AdjustmentRun("gift_smell", giftEnt:GetStoredGift(), self.adjustments, giftEnt)
    if customSmell then
        return customSmell
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
        breakdown[label.."_spawnable"] = giftData:IsSpawnable(LocalPlayer and LocalPlayer() or player.GetAll()[1], nil, true)
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
        if giftData:IsSpawnable(giftee, nil, true) then
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
        if self.adjustments and self.adjustments.visual_override then return self end

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

            if previewEnt.SetOwner then previewEnt:SetOwner(ply) end
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

        local customVis = utils.AdjustmentRun("gift_visuals", _, self.adjustments, giftEnt)
        if customVis then
            return customVis
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

    function GiftData:GetSizeStr(giftObj)
        local closestDesc = "Unknown"
        local closestDiff = math.huge
        local giftSize = self:GetSize(giftObj)

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
    if self.only_on_map and not string.StartsWith(game.GetMap(), self.only_on_map) then
        return false
    end

    local detectResult = utils.AdjustmentRun("detect", ent, self.adjustments)
    if detectResult ~= nil then
        return detectResult
    end

    if self.identifiers then
        for _, id in ipairs(self.identifiers) do
            if id.mdl and id.mdl == entIdentifier or id == entIdentifier then
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

    elseif string.StartsWith(entIdentifier, "func_physbox") then
        entIdentifier = entName ~= "" and entName or entModel
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

    elseif string.StartsWith(entClass, "func_physbox") then
        placeholderData.category = GiftCategory.PhysBox

    elseif entIdentifier == entModel then
        placeholderData.category = GiftCategory.PhysProp

    elseif ent.Base == "base_ammo_ttt" then
        placeholderData.category = GiftCategory.Ammo

    elseif list.Get("NPC")[entIdentifier] or entClass == "monster_generic" then
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
        placeholderData.name = string.match(string.StripExtension(entModel), "[^/\\]+$"):gsub("_", " ")
                                     :gsub("(%l)(%w*)", function(a, b) return string.upper(a) .. b end)

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
        placeholderData.adjustments = { grenade = {} }
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
                for _, id in ipairs(data.identifiers) do
                    util.PrecacheModel(id.mdl and id.mdl or id)
                end
            end
        end
    end
end