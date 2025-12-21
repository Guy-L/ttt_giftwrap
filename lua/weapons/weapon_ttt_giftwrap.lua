----------------------------------
------- CONSTANTS & CVARS --------
----------------------------------
local TryT  = LANG.TryTranslation
local dbg   = GW_DBG
local utils = GW_Utils
local WRAP_NAME = "Gift Wrap"
local GIFT_NAME = "Gift"

local GIFTWRAP_PICKUP_MSG    = "TTT_GiftWrap_PickUpMsg"
local GIFTWRAP_HL_CHAT_MSG   = "TTT_GiftWrap_HighlightChatMsg"
local HOOK_GIFTWRAP_PICKUP   = "TTT_GiftWrap_PickUp"
local HOOK_GIFTWRAP_TREE_USE = "TTT_GiftWrap_UseTree"
local HOOK_ANGLE_CORRECTION  = "TTT_GiftWrap_CorrectGiftAngle"
local HOOK_ROUND_RESET_OPENS = "TTT_GiftWrap_ResetOpenedRandomGiftCounts"
local HOOK_RELOAD_SOUNDS     = "TTT_GiftWrap_ReloadSounds"
local WRAPPED_GIFT_REMOVE    = "TTT_GiftWrap_WrappedGiftRemove"
local GIFTWRAP_REMOVE        = "TTT_GiftWrap_XMasBeaconRemove"

local GW_REGMETASWEP = GW_REGMETASWEP or SWEP
local GW_METASWEP    = SWEP

GW_sound = {
    swing           = Sound("Weapon_Crowbar.Single"),
    wrapping        = Sound("giftwrap/wrapping.mp3"),
    unwrap          = Sound("giftwrap/opening.mp3"),
    undo_wrap       = Sound("giftwrap/undo_wrap.mp3"),
    flourish_sl1    = Sound("garrysmod/save_load1.wav"),
    flourish_sl2    = Sound("garrysmod/save_load2.wav"),
    flourish_sl3    = Sound("garrysmod/save_load3.wav"),
    flourish_sl4    = Sound("garrysmod/save_load4.wav"),
    flourish_yippie = Sound("giftwrap/yippie.mp3"),
    generic_shake   = Sound("giftwrap/shake.mp3"),
    throw           = Sound("giftwrap/throw.mp3"),
    pop             = Sound("garrysmod/balloon_pop_cute.wav"),
}
local sounds = GW_sound

----------------------------------
--- SERVER REALM SETUP / HOOKS ---
----------------------------------
if SERVER then
    dbg.Log("Initializing....")

    AddCSLuaFile("weapon_ttt_giftwrap.lua")
    resource.AddFile("materials/"..GIFTWRAP_ICON..".vmt")

    util.AddNetworkString(GIFTWRAP_PICKUP_MSG)
    util.AddNetworkString(GIFTWRAP_HL_CHAT_MSG)
    util.PrecacheModel(WRAP_VIEWMODEL)
    util.PrecacheModel(WRAP_WORLDMODEL)
    util.PrecacheModel(GIFT_VIEWMODEL)
    util.PrecacheModel(GIFT_WORLDMODEL)

    hook.Add("TTTBeginRound", HOOK_ROUND_RESET_OPENS, function()
        for _, ply in ipairs(player.GetAll()) do
            ply.OpenedRandomGift = false
        end
    end)

    function GetWrapConstraint(ent)
        if not IsValid(ent) then return "Invalid object." end
        if ent:IsWeapon() then return nil end
        if ent.Base == "base_ammo_ttt" then return nil end
        if ent.GetExplodeTime then return nil end

        local phys  = ent:GetPhysicsObject()
        local class = ent:GetClass()

        -- TODO: Remove temp and implement properly (player ragdolls + seekgulls, other things)
        if class == "prop_ragdoll" then return "Haven't figured out how to allow this yet!" end

        local override_classes = {
            "ttt_chicken",
            "ttt_kfc",
            "glue_trap_paste",
        }

        -- check overrides
        if table.HasValue(override_classes, class) then
            return nil
        end

        local valid_classes = {
            "func_physbox",
            "func_physbox_multiplayer",
            "prop_physics",
            "prop_physics_multiplayer",
            "prop_physics_override",
            "prop_sphere",
            "ads", -- blocked later (affixed)
            --"npc_barnacle", -- TODO: bugged, need ownership check
            "ent_ttt_ttt2_camera", -- blocked later (affixed)
            "force_shield", -- blocked later (no phys, won't budge)
            "christmas_present",
            "ttt_cse_proj", -- TODO: ownership check (honor original design)
            "ttt_chomik",
            --"sent_controllable_manhack", -- TODO: bugged (SFX) + not balanced without ownership check
            "ttt_d20_proj",
            "deadly_ball",
            "ttt_dingus",
            "ttt_dingwell",
            "ttt_banana_peel",
            "ttt_banana_proj",
            "ttt_banana_split",
            "ttt_beacon", -- blocked later if affixed
            "ttt_decoy", -- blocked later if affixed
            "ttt_thrownflashbang",
            "ent_fortnitestructure", -- blocked later (affixed)
            --"ent_ttt_fan", -- TODO: bugged (wind remains), need ownership check
            --"sent_greendemon_box", --TODO: bugged (ui remains), needs ownership check, possible balance issue
            --"sent_greendemon", --TODO: bugged
            "env_headcrabcanister", -- blocked later (affixed)
            "npc_headcrab",
            "npc_headcrab_fast", -- bunger
            "ttt_health_station", -- TODO: ownership check
            "ttt_seekgull_bird", -- blocked later i'm fairly sure, TODO make work properly
            "ttt_knife_proj",
            "item_lethal_company_landmine", -- blocked later (affixed)
            "matryoshka", -- blocked later (affixed) (breaching charge)
            "ttt_minecraft_arrow", -- TODO: bugged, can't be selected
            "sent_molotov_timed",
            "sent_molotov",
            "moonball",
            "ent_moongrenade",
            --"ttt_paper_plane_proj", -- TODO: bugged (trails continues, probably still exists), needs ownership check
            "ttt_poison_station", -- TODO: ownership check
            "ttt_potofgreedier",
            --"ttt_radio", -- blocked later if affixed; TODO: bugged (markervision; can get permanent burning SFX?), need ownership check
            --"ttt_ragnana_peel", -- TODO: bugged (ui remains)
            --"sent_rcxd", -- TODO: bugged (lights remain)
            "shield_deployer",
            --"ttt_slam_satchel", -- TODO: bugged (ui remains), needs ownership check
            "ttt_shard_of_greed",
            "ttt2_hat_shellmet",
            "ttt_slam_tripmine", -- blocked later (affixed)
            "ttt_soap", -- blocked later (affixed); TODO consider making moveable with ownership check
            "ttt_springmine", -- blocked later (affixed); TODO consider making moveable with ownership check
            --"plasma_burster_nade", -- good luck wrapping that; TODO fix the whole thing being ass
            --"npc_turret_floor", -- TODO: bugged (still fires); needs ownership check
            --"ttt_wormhole", -- blocked later (affixed); TODO: bugged (angle is reset to parallel with ground on unwrap)
            "ttt_zombieball_proj", -- TODO: try wrapping an existing one somehow???
        }

        -- validity check
        if not table.HasValue(valid_classes, class) and string.sub(ent:GetClass(), 1, 5) ~= "prop_" then
            dbg.Log("Tried wrapping: "..class)
            return "Can't wrap this type of thing yet."
        end

        -- moveability check
        if not IsValid(phys) or not phys:IsMoveable() or not ent.CanPickup == false
          or phys:HasGameFlag(FVPHYSICS_NO_PLAYER_PICKUP) then
            return "It won't budge."
        end

        -- weight check
        if phys:GetMass() > 600 then
            dbg.Log("Tried wrapping "..class.." with mass "..phys:GetMass())
            return "It's too heavy, and you don't have enough wrapping paper."
        end
    end
    
    -- Tell clients to update UI when it enters their inventory (no reliable clientside hook?)
    hook.Add("AllowPlayerPickup", HOOK_GIFTWRAP_PICKUP, function(ply, ent)
        if utils.IsGiftWrap(ent) then
            net.Start(GIFTWRAP_PICKUP_MSG)
            net.Send(ply)
        end
    end)

    -- Allow clients to "use" trees to place gifts in the usual range
    hook.Add("PlayerUse", HOOK_GIFTWRAP_TREE_USE, function(ply, ent)
        if utils.IsLivingPlayer(ply) and IsValid(ent) 
          and ent:GetModel() == SNUFFLE_TREE_MODEL then
            local wep = ply:GetActiveWeapon()

            if utils.IsGiftWrap(wep) and wep:HeldByWrapper(ply) then
                local giftProp = wep:MakePropCopy(true)

                -- get pos similar like how snuffles does it
                local angle = math.rad(math.random(360))
                local distance = 60 -- from tree center
                local offset = Vector(math.cos(angle) * distance, math.sin(angle) * distance, 0)
                local giftPos = ent:GetPos() + offset
                
                local tr = util.TraceLine({
                    start = giftPos + Vector(0, 0, 50),
                    endpos = giftPos - Vector(0, 0, 100),
                    mask = MASK_SOLID
                })
                giftProp:SetPos(tr.HitPos + Vector(0, 0, 50))

                giftProp:Spawn()
                wep:Remove()
                ply:EmitSound(sounds["pop"], 75, math.random(90, 120))
            end
        end
    end)

----------------------------------
--- CLIENT REALM SETUP / HOOKS ---
----------------------------------
elseif CLIENT then
    dbg.Log("Initializing....")

    GW_METASWEP.Icon = GIFTWRAP_ICON
    GW_METASWEP.iconMaterial = GIFTWRAP_ICON
    GW_METASWEP.PrintName = WRAP_NAME
    GW_METASWEP.Author = "Guy"
    GW_METASWEP.EquipMenuData = {type = "Utility Weapon", desc = [[It's the season of giving!
• Gift Wrap: Left click to wrap something into a Gift for someone else to open.
• Gift: Left click to toss it out!
            Reload to undo the wrap.

While holding your Gift, you can place it neatly under a Christmas Tree with E.

Gifts made by others can be opened with LMB (while holding them or via crowbar), and shaken with RMB to get some hints as to what might be inside!]]}
    GW_METASWEP.Slot = 6

    GW_METASWEP.ViewModelFlip = false
    GW_METASWEP.ViewModelFOV  = 85
    GW_METASWEP.DrawCrosshair = false
    GW_METASWEP.UseHands      = true

    function UpdateLocalInventoryGiftWrap(reason)
        local ownedGiftwrap = utils.GetInventoryGiftwrap(LocalPlayer())

        if ownedGiftwrap then
            ownedGiftwrap:UpdateUI(reason)
            ownedGiftwrap:UpdateModel(reason)
            ownedGiftwrap:UpdateMarkerVision(reason)
        end
    end

    net.Receive(GIFTWRAP_PICKUP_MSG, function()
        timer.Simple(0.01, function() -- safety sync wait
            dbg.Log("Received pickup notif")
            UpdateLocalInventoryGiftWrap("pickup")
        end)
    end)

    local COLOR_NORMAL = Color(0, 128, 255)
    local COLOR_HIGHLIGHT = Color(146, 205, 248)

    net.Receive(GIFTWRAP_HL_CHAT_MSG, function()
        local preHighlight  = net.ReadString()
        local highlight     = net.ReadString()
        local postHighlight = net.ReadString()

        chat.AddText(
            COLOR_NORMAL,    preHighlight,
            COLOR_HIGHLIGHT, highlight,
            COLOR_NORMAL,    postHighlight
        )
    end)
end

----------------------------------
---- SHARED SWEP INIT & DEFS -----
----------------------------------
SWEP.Base         = "weapon_tttbase"
SWEP.HoldType     = "melee"
SWEP.idleResetFix = true

SWEP.Primary.Damage      = -1
SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Delay       = 0.5
SWEP.Primary.Ammo        = "none"

SWEP.Kind        = WEAPON_EQUIP
SWEP.CanBuy      = {ROLE_TRAITOR, ROLE_JACKAL}
SWEP.AllowDrop   = true
SWEP.DeploySpeed = 2

function SWEP:Initialize() --on buy
    self:UpdateModel("initialize")

    if CLIENT then
        self:UpdateUI("initialize")
        self:UpdateMarkerVision("initialize")

        self:CallOnRemove(GIFTWRAP_REMOVE, function(goneSelf)
            goneSelf:UpdateMarkerVision("swep removal")
        end)
    end

    return self.BaseClass.Initialize(self)
end

function SWEP:UpdateModel(reason)
    dbg.Log("Updating model... ("..reason..")")
    local vmChange = false

    if not self:HasGift() then
        if self.ViewModel ~= WRAP_VIEWMODEL then vmChange = true end
        self.ViewModel  = WRAP_VIEWMODEL
        self.WorldModel = WRAP_WORLDMODEL
        self:SetHoldType("melee")

    else
        if self.ViewModel ~= GIFT_VIEWMODEL then vmChange = true end
        self.ViewModel  = GIFT_VIEWMODEL
        self.WorldModel = GIFT_WORLDMODEL
        self:SetHoldType("physgun")
    end

    if vmChange then
        local owner = self:GetOwner()

        -- note: the GetViewModel function existance check is for Doppelganger lol
        if IsValid(owner) and owner.GetViewModel then 
            self:SetModel(self.ViewModel)
            self:ResetSequenceInfo()
            local vm = owner:GetViewModel()

            if IsValid(vm) then
                vm:SetModel(self.ViewModel)
                vm:ResetSequenceInfo()
            end

            timer.Simple(0.01, function()
                -- if done on the same frame as the change, it'll trigger the anim
                -- first and wait for it to complete before changing
                if self.Weapon then
                    self.Weapon:SendWeaponAnim(ACT_VM_DRAW)
                end
            end)
        end
    end
end

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "IsOpening")
    self:NetworkVar("Bool", 1, "IsShaking")
    self:NetworkVar("Bool", 2, "IsRandomGift")
    self:NetworkVar("String", 0, "WrapperSID")
    self:NetworkVar("Entity", 0, "StoredGift")

    self:NetworkVar("String", 1, "CachedDataLabel")
    self:NetworkVar("String", 2, "CachedDataSID")

    if CLIENT then
        self:NetworkVarNotify("StoredGift", function(name, old, new)
            timer.Simple(0.1, function() -- value isn't changed yet
                self:UpdateUI("storage update")
                self:UpdateModel("storage update")
                self:UpdateMarkerVision("storage update")

                if not self:HasGift() and not self:GetIsOpening() then
                    self:EmitSound(sounds["undo_wrap"], 150, math.random(90, 110))
                end
            end)
        end)
    end
end

function SWEP:UpdateTransmitState()
    return TRANSMIT_ALWAYS -- update state for all clients
end

function SWEP:PrimaryAttack()
    if self:GetIsOpening() then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if not self:HasGift() then -- Wrap gift
        local tr = utils.GetEyeTrace(owner)
        local hitEnt = tr.Entity
        dbg.Log("GiftWrap Primary hit entity:", hitEnt)

        if tr.HitNonWorld and IsValid(hitEnt) 
          and owner:GetShootPos():Distance(tr.HitPos) <= 150 then
            self:SendWeaponAnim(ACT_VM_HITCENTER)
            self:EmitSound(sounds["wrapping"], 75, math.random(90, 110))

            if SERVER then
                owner:SetAnimation(PLAYER_ATTACK1)
                timer.Simple(0.2, function()
                    self:Wrap(hitEnt)
                end)
            end
        else
            self:EmitSound(sounds["swing"], 75, math.random(90, 110))
            self:SendWeaponAnim(ACT_VM_MISSCENTER)
        end

    else
        if self:OwnedByWrapper(owner) then -- Throw gift prop
            if SERVER then
                local giftProp = self:MakePropCopy(false)
                giftProp:SetPos(owner:GetShootPos())
                giftProp:Spawn()

                local phys = giftProp:GetPhysicsObject()
                if IsValid(phys) then
                    local throwVel = owner:GetAimVector()
                    --throwVel.z = 0.3 -- hardlock trajectory vertically
                    throwVel = throwVel * 800

                    phys:SetVelocity(throwVel)
                    phys:AddAngleVelocity(Vector(500, 0, 0))
                end

                self:Remove()
                owner:EmitSound(sounds["throw"], 75, math.random(90, 120))
            end

        else -- Open gift
            if SERVER then
                if owner.OpenedRandomGift then
                    utils.NonSpamMessage(owner, "OpenAttempt", ERROR_ALREADY_OPENED)
                    return
                end

                self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
                self:SetIsOpening(true)

                timer.Simple(0.9, function()
                    self:DropContents()
                    self:Remove()
                    owner.OpenedRandomGift = true
                end)
            else
                self:EmitSound(sounds["unwrap"], 100, math.random(90, 110))
            end
        end
    end
end

function SWEP:SecondaryAttack()
    if self:GetIsOpening() then return end

    if self:OwnedByWrapper() then -- gift options
        if dbg.Cvar:GetBool() then
            self:SetWrapperSID("WORLD") --DEBUG
            if CLIENT then self:UpdateUI("debug") end

        elseif SERVER then
            local owner = self:GetOwner()
            if not owner then return end

            utils.NonSpamMessage(owner, "RMBAttempt", "No options yet. Coming soon! (TM)")
        end

    elseif self:HasGift() and not self:GetIsShaking() then -- shake
        self:EmitSound(sounds["generic_shake"], 100, math.random(95, 105))
        self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)

        if SERVER then
            self:SetIsShaking(true)
            timer.Simple(1.25, function() 
                if IsValid(self) then self:SetIsShaking(false) end
            end)

            local owner = self:GetOwner()
            if not owner then return end

            local cachedData = GetCachedGiftData(self, owner)
            local firstPart, secondPart, thirdPart = cachedData:Inspect()

            net.Start(GIFTWRAP_HL_CHAT_MSG)
            net.WriteString(firstPart)
            net.WriteString(secondPart)
            net.WriteString(thirdPart)
            net.Send(owner)
        end
    end
end

function SWEP:HasGift()
    return IsValid(self:GetStoredGift()) or self:GetIsRandomGift()
end

function SWEP:OwnedByWrapper(owner)
    if not owner then owner = self:GetOwner() end
    if not utils.IsLivingPlayer(owner) then return false end

    return owner:SteamID64() == self:GetWrapperSID()
end

function SWEP:HeldByWrapper(owner)
    if not owner then owner = self:GetOwner() end
    if not self:OwnedByWrapper(owner) then return false end

    return owner:GetActiveWeapon() == self
end

function SWEP:OnRemove()
    if CLIENT and IsValid(self:GetOwner())
      and self:GetOwner() == LocalPlayer()
      and utils.IsLivingPlayer(self:GetOwner()) then
        RunConsoleCommand("lastinv")
    end
end

function SWEP:Deploy()
    self.Weapon:SendWeaponAnim(ACT_VM_DRAW)
    self:UpdateModel("deploy")

    if CLIENT then 
        self:UpdateUI("deploy")
        self:UpdateMarkerVision("deploy")
    end
end

----------------------------------
----- SERVER REALM SWEP DEFS -----
----------------------------------
if SERVER then
    function SWEP:Equip(newOwner)
        self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay * 1.5))
    end

    function SWEP:PreDrop()
        self.fingerprints = {}
    end

    -- non-SWEP; for use by both SWEP and prop gift
    -- can be called without giftee for non-random gifts
    function GetCachedGiftData(giftObj, giftee)
        local cachedDataLabel = giftObj:GetCachedDataLabel()

        -- if non-random, cached data does not depend on giftee but may not have been initialized yet
        -- if random, cached data may not be initialized AND may not be valid for current player

        if not giftObj:GetIsRandomGift() then -- preset gift
            if cachedDataLabel ~= "" then -- use cache
                dbg.Log("Requesting preset gift info; using cached", cachedDataLabel)
                return GetGiftDataFromLabel(cachedDataLabel)

            else -- cache it
                local newLabel, newData = GetEntGiftData(giftObj:GetStoredGift())
                giftObj:SetCachedDataLabel(newLabel)

                dbg.Log("Requesting preset gift info; cached", newLabel)
                return newData
            end

        else -- random gift
            local cachedData = nil
            local cachedDataSID = giftObj:GetCachedDataSID()
            local gifteeSID = giftee:SteamID64() -- giftee assumed valid

            -- valid cache if initialized and cached by player
            if cachedDataLabel ~= "" and gifteeSID == cachedDataSID then 
                cachedData = GetGiftDataFromLabel(cachedDataLabel)
            end

             -- make new cached data (or reuse)
            if not (cachedData and cachedData:IsSpawnable(giftee)) then
                cachedDataLabel, cachedData = GetRandomGiftData(giftee)
                giftObj:SetCachedDataLabel(cachedDataLabel)
                giftObj:SetCachedDataSID(gifteeSID)

                dbg.Log("Requesting random gift info; cached new", cachedDataLabel)
            else
                dbg.Log("Requesting random gift info; using cached", cachedDataLabel)
            end

            return cachedData
        end
    end

    local superRare   = {
        "You got a super rare item!",
        "You pulled a super rare!",
        "You found a super rare gift!",
        "It's super rare!",
        "L U C K Y!",
    }
    local niceList = {
        "For being such a good terrorist this year!",
        "For being such a nice terrorist...",
        "Seems you're on the nice list!",
        "It's what you've always wanted!",
        --"For all your hard work...",
    }
    local naughtyList = {
        --"You've been such a bad terrorist this year...",
        "Santa's mad...",
        "For being such a naughty terrorist...",
        "Seems you're on the naughty list!",
        "Have you been traitorous this year?",
    }

    -- non-SWEP; for use in prop entity lua file
    function SpawnGiftEnt(gifteePly, giftObj, spawnPos)
        if not IsValid(giftObj) then return end
        if not utils.IsLivingPlayer(gifteePly) and not spawnPos then return end

        local giftEnt = giftObj:GetStoredGift()
        local giftData = GetCachedGiftData(giftObj, gifteePly)

        if giftObj:GetIsRandomGift() or not IsValid(giftEnt) then
            giftEnt = giftData:Spawn(gifteePly)
        end

        if IsValid(giftEnt) then
            if not spawnPos then -- raycast to spawn in front of giftee
                local tr = utils.GetEyeTrace(gifteePly)
                dbg.Log("GiftWrap DropContent hit:", tr.HitEnt, tr.HitPos)

                local hitPos = tr.HitPos
                if gifteePly:EyePos():Distance(hitPos) > 80 then --clamp
                    hitPos = gifteePly:EyePos() + gifteePly:GetAimVector() * 80
                end

                -- Maximum extent along the hit normal (how far it sticks out in that direction)
                local mins, maxs = giftEnt:OBBMins(), giftEnt:OBBMaxs()
                local extent = math.max(mins:Dot(tr.HitNormal * -1),
                                        maxs:Dot(tr.HitNormal * -1))

                spawnPos = hitPos + tr.HitNormal * extent
            end

            -- Plop back into world
            giftEnt:SetNoDraw(false)
            giftEnt:SetNotSolid(false)
            giftEnt:SetPos(spawnPos)
            giftEnt:PhysWake()
            local giftPhys = giftEnt:GetPhysicsObject()
            if IsValid(giftPhys) then giftPhys:Wake() end

            giftData:ApplyPostUnwrapAdjustments(giftEnt, gifteePly)

        else -- for particle position later
            spawnPos = gifteePly:GetShootPos()
        end

        -- Chat Notif
        if giftEnt ~= false then
            if giftObj:GetIsRandomGift() then
                if giftData.factor_rarity and giftData.factor_rarity >= 5
                  and giftData.factor_quality and giftData.factor_quality > 0
                  and math.random() <= 0.8 then
                    gifteePly:ChatPrint(superRare[math.random(#superRare)])

                elseif giftData.factor_quality then
                    if giftData.factor_quality >= 7 then
                        gifteePly:ChatPrint(niceList[math.random(#niceList)])

                    elseif giftData.factor_quality <= -7 then
                        gifteePly:ChatPrint(naughtyList[math.random(#naughtyList)])
                    end
                end
            end

            net.Start(GIFTWRAP_HL_CHAT_MSG)
            net.WriteString("You unwrapped ")
            net.WriteString(giftData:GetDesc(giftEnt, gifteePly))
            net.WriteString("!")
            net.Send(gifteePly)
        else
            net.Start(GIFTWRAP_HL_CHAT_MSG)
            net.WriteString("You were meant to unwrap ")
            net.WriteString(giftData.desc .. " (" .. giftData.name ..")")
            net.WriteString(", but it couldn't be spawned.")
            net.Send(gifteePly)
            return
        end

        -- Sound
        local sndOrigin = IsValid(giftEnt) and giftEnt or gifteePly

        if IsValid(sndOrigin) then
            local dropSnd = "pop"
            local dropVol = 0.5
            local dropPitch = math.random(90, 120)

            if giftObj:GetClass() == PROP_CLASS_NAME or giftObj:GetIsOpening() then
                local flourishType = math.random(5)
                if flourishType == 5 then
                    dropSnd = "flourish_yippie"
                else
                    dropSnd = "flourish_sl" .. flourishType
                end

                dropVol = 0.75
                dropPitch = 100
            end

            local openSnd = CreateSound(sndOrigin, sounds[dropSnd])
            openSnd:PlayEx(dropVol, dropPitch)
        end

        -- Particle effect
        local effectData = EffectData()
        effectData:SetOrigin(spawnPos)
        effectData:SetMagnitude(10)
        effectData:SetScale(0.01)
        effectData:SetRadius(50)
        util.Effect("Sparks", effectData)
    end

    function SWEP:DropContents()
        local owner = self:GetOwner()

        if IsValid(owner) and self:HasGift() then
            SpawnGiftEnt(owner, self, nil)

            dbg.Log("Dropped gift contents")
            self:SetWrapperSID("")
            self:SetStoredGift(nil)
            self:SetCachedDataLabel("")
            self:SetCachedDataSID("")
            self:UpdateModel("dropped gift")
        end
    end

    function SWEP:MakePropCopy(notRetrievable)
        -- note: yeah, you could technically save from having to do that
        --       by having the prop hold a reference to the SWEP and not deleting it
        --       but it's messy either way and this works!
        local giftProp = ents.Create(PROP_CLASS_NAME)
        giftProp:SetIsRandomGift(self:GetIsRandomGift())
        giftProp:SetWrapperSID(self:GetWrapperSID())
        giftProp:SetStoredGift(self:GetStoredGift())
        giftProp:SetCachedDataLabel(self:GetCachedDataLabel())
        giftProp:SetCachedDataSID(self:GetCachedDataSID())
        giftProp:SetNotRetrievable(notRetrievable)

        return giftProp
    end

    function SWEP:Reload()
        local owner = self:GetOwner()

        if self:OwnedByWrapper(owner) and not self:GetIsOpening() and not self:GetIsRandomGift() then
            local giftData = GetCachedGiftData(self, owner)

            if giftData.category == GiftCategory.SENT or giftData.category == GiftCategory.NPC then
                utils.NonSpamMessage(owner, "ReloadAttempt", "Undoing wrap for special entities is currently disabled as a precaution.")
            else
                self:DropContents()
            end
        end
    end

    function SWEP:Wrap(ent)
        dbg.Log("Wrap attempt on:", ent)
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local wrapCheckRet = GetWrapConstraint(ent)

        if wrapCheckRet then
            owner:ChatPrint(wrapCheckRet)

        else
            ent:SetNoDraw(true)
            ent:SetNotSolid(true)

            self:SetWrapperSID(owner:SteamID64())
            self:SetStoredGift(ent)

            GetCachedGiftData(self):ApplyOnWrapAdjustments(ent)
            ent:CallOnRemove(WRAPPED_GIFT_REMOVE, function()
                if IsValid(self) and IsValid(owner) then
                    local invGiftWrap = utils.GetInventoryGiftwrap(owner)

                    if invGiftWrap and invGiftWrap:HasGift() then
                        owner:ChatPrint("The gift somehow disappeared, leaving the wrapping paper behind.")
                    end
                end
            end)
            self:UpdateModel("wrapped gift")
        end
    end

----------------------------------
----- CLIENT REALM SWEP DEFS -----
----------------------------------
elseif CLIENT then
    function SWEP:UpdateUI(reason)
        dbg.Log("Updating UI... ("..reason..")")

        if not self:HasGift() then
            self.PrintName = WRAP_NAME
        else
            self.PrintName = GIFT_NAME
        end

        -- no need to update tooltips if the sword is not in someone's inventory
        local owner = self:GetOwner()
        self:ClearHUDHelp()

        if not self:HasGift() then
            self:AddTTT2HUDHelp("wrap_instruction_lmb", "giftwrap_instruction_rmb")
        else
            if not IsValid(owner) or not self:OwnedByWrapper(owner) then
                self:AddTTT2HUDHelp("gift_instruction_all_lmb", "gift_instruction_all_rmb")
            else
                self:AddTTT2HUDHelp("gift_instruction_wrapper_lmb", "giftwrap_instruction_rmb")
                if not self:GetIsRandomGift() then
                    self:AddHUDHelpLine("wrap_instruction_r", Key("+reload", "R"))
                end
            end
        end
    end

    local TREE_COLOR = Color(15, 155, 10)
    function SWEP:UpdateMarkerVision(reason)
        if christmasTree then
            dbg.Log("Updating tree beacon... ("..reason..")")
            local mvLabel = MARKER_UI_LABEL..self:EntIndex()
            local mv = christmasTree:GetMarkerVision(mvLabel)

            if mv then -- keep MV so long as still owned by wrapper
                if self:HeldByWrapper() then return
                else christmasTree:RemoveMarkerVision(mvLabel) end

            else -- create MV if owned by wrapper
                local owner = self:GetOwner()

                if self:HeldByWrapper(owner) then
                    local treeBeacon = christmasTree:AddMarkerVision(mvLabel)
                    treeBeacon:SetVisibleFor(VISIBLE_FOR_PLAYER)
                    treeBeacon:SetOwner(owner)

                    christmasTree:CallOnRemove(MARKER_UI_LABEL, function(goneEnt)
                        goneEnt:RemoveMarkerVision(mvLabel)
                    end)

                    marks.Add({christmasTree}, TREE_COLOR)
                end
            end
        end
    end

    function SWEP:Holster()
        self:UpdateMarkerVision("holster")
    end

    function SWEP:AddToSettingsMenu(parent)
        local formRNGift = vgui.CreateTTT2Form(parent, "label_giftwrap_random_gifts_form")
        formRNGift:MakeHelp({
            label = "label_giftwrap_random_gifts_desc"
        })
        formRNGift:MakeCheckBox({
            serverConvar = "ttt2_giftwrap_enable_random_gifts",
            label = "label_giftwrap_enable_random_gifts"
        })
        formRNGift:MakeCheckBox({
            serverConvar = "ttt2_giftwrap_replace_snuffles_gift",
            label = "label_giftwrap_replace_snuffles_gift"
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_extra_gift_chance",
            label = "label_giftwrap_extra_gift_chance",
            min = 0, max = 1, decimal = 2
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_extra_gift_chance_xmas",
            label = "label_giftwrap_extra_gift_chance_xmas",
            min = 0, max = 1, decimal = 2
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_timezone_offset",
            label = "label_giftwrap_timezone_offset",
            min = -24, max = 24, decimal = 0
        })
        formRNGift:MakeHelp({
            label = "label_giftwrap_weights_desc"
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_prop_weight",
            label = "label_giftwrap_prop_weight",
            min = 0, max = 5, decimal = 2
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_floor_weight",
            label = "label_giftwrap_floor_weight",
            min = 0, max = 5, decimal = 2
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_special_weight",
            label = "label_giftwrap_special_weight",
            min = 0, max = 5, decimal = 2
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_shop_weight",
            label = "label_giftwrap_shop_weight",
            min = 0, max = 5, decimal = 2
        })

        local formMisc = vgui.CreateTTT2Form(parent, "label_giftwrap_misc_form")
        formMisc:MakeCheckBox({
            serverConvar = "ttt2_giftwrap_give_guy_access",
            label = "label_giftwrap_give_guy_access"
        })
        formMisc:MakeCheckBox({
            serverConvar = "ttt2_giftwrap_debug",
            label = "label_giftwrap_debug"
        })
    end
end

-- for hot reloading
if CLIENT then
    UpdateLocalInventoryGiftWrap("hot reload")
end