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
local GIFTWRAP_GIFT_DATA_MSG = "TTT_GiftWrap_SendWrapperData"
local HOOK_GIFTWRAP_PICKUP   = "TTT_GiftWrap_PickUp"
local HOOK_GIFTWRAP_TREE_USE = "TTT_GiftWrap_UseTree"
local HOOK_ANGLE_CORRECTION  = "TTT_GiftWrap_CorrectGiftAngle"
local HOOK_ROUND_RESET_OPENS = "TTT_GiftWrap_ResetOpenedRandomGiftCounts"
local HOOK_RELOAD_SOUNDS     = "TTT_GiftWrap_ReloadSounds"
local HOOK_RESET_VM_COLORS   = "TTT_GiftWrap_ResetVMColors"
local WRAPPED_GIFT_REMOVE    = "TTT_GiftWrap_WrappedGiftRemove"
local GIFTWRAP_REMOVE        = "TTT_GiftWrap_XMasBeaconRemove"
TP_GIFT_MSG                  = "TTT_GiftWrapSV_TeleportGift"

local TIMEZONE_OFFSET_HOURS       = utils.Cvar("ttt2_giftwrap_timezone_offset", "0", -24, 24, "Adjusts the timezone used for determining whether it's Christmas (offset in hours).")
local SECOND_GIFT_CHANCE          = utils.Cvar("ttt2_giftwrap_second_gift_chance", "0.5", 0, 1, "Chance for a second random gift spawn per Snuffle gift replaced.")
local THIRD_GIFT_CHANCE           = utils.Cvar("ttt2_giftwrap_third_gift_chance",  "0.4", 0, 1, "Chance for a third random gift spawn if a second one spawned.")
local SECOND_GIFT_CHANCE_XMAS     = utils.Cvar("ttt2_giftwrap_second_gift_chance_xmas", "0.9", 0, 1, "Chance for a second random gift spawn per Snuffle gift replaced, on Christmas specifically.")
local THIRD_GIFT_CHANCE_XMAS      = utils.Cvar("ttt2_giftwrap_third_gift_chance_xmas",  "0.6", 0, 1, "Chance for a third random gift spawn if a second one spawned, on Christmas specifically.")
local GIFT_MATCH_PLAYERCOUNT      = utils.Cvar("ttt2_giftwrap_match_playercount",      "0.15", 0, 1, "Chance for as many gifts to spawn as there are players (overriding other chance logic).")
local GIFT_MATCH_PLAYERCOUNT_XMAS = utils.Cvar("ttt2_giftwrap_match_playercount_xmas", "0.66", 0, 1, "Chance for as many gifts to spawn as there are players (overriding other chance logic), on Christmas specifically.")

local GW_REGMETASWEP = GW_REGMETASWEP or SWEP
local GW_METASWEP    = SWEP

local sounds = {
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

----------------------------------
--- SERVER REALM SETUP / HOOKS ---
----------------------------------
if SERVER then
    dbg.Log("Initializing....")

    AddCSLuaFile("weapon_ttt_giftwrap.lua")
    resource.AddFile("materials/"..GIFTWRAP_ICON..".vmt")

    util.AddNetworkString(GIFTWRAP_PICKUP_MSG)
    util.AddNetworkString(GIFTWRAP_HL_CHAT_MSG)
    util.AddNetworkString(GIFTWRAP_GIFT_DATA_MSG)
    util.AddNetworkString(TP_GIFT_MSG)
    util.PrecacheModel(WRAP_VIEWMODEL)
    util.PrecacheModel(WRAP_WORLDMODEL)
    util.PrecacheModel(GIFT_VIEWMODEL)
    util.PrecacheModel(GIFT_WORLDMODEL)

    -- reset "opened gift" states & determine random gift spawn parameters
    hook.Add("TTTBeginRound", HOOK_ROUND_RESET_OPENS, function()
        for _, ply in ipairs(player.GetAll()) do
            ply:SetNWBool("OpenedRandomGift", false)
            ply:SetNWBool("GotFirstTimeSample", false)
        end

        local adjTime = os.time(os.date("!*t")) + (TIMEZONE_OFFSET_HOURS:GetFloat() * 3600)
        local dayOfYear = tonumber(os.date("!%j", adjTime))

        isChristmas = (dayOfYear == XMAS_DAY)
        GW_secondGiftChance = (isChristmas and SECOND_GIFT_CHANCE_XMAS or SECOND_GIFT_CHANCE):GetFloat()
        GW_thirdGiftChance  = (isChristmas and THIRD_GIFT_CHANCE_XMAS or THIRD_GIFT_CHANCE):GetFloat()

        local mpcrChance = (isChristmas and GIFT_MATCH_PLAYERCOUNT_XMAS or GIFT_MATCH_PLAYERCOUNT):GetFloat()
        GW_matchPlayerCountRound = (math.random() <= mpcrChance)

        dbg.Log("Day of Year:", dayOfYear, "; Hour", os.date("!%H", adjTime),
            "; Christmas:", isChristmas, "; matched playercount round:", GW_matchPlayerCountRound,
            "; second gift chance:", GW_secondGiftChance, "; third gift chance:", GW_thirdGiftChance)
    end)

    function GetWrapConstraint(ent, wrapper)
        if not IsValid(ent) then return "Invalid object." end
        if ent.Base == "base_ammo_ttt" then return nil end
        if ent.GetExplodeTime then return nil end

        local phys  = ent:GetPhysicsObject()
        local class = ent:GetClass()

        -- TODO: Remove temp and implement properly (player ragdolls + seekgulls, other things)
        if class == "prop_ragdoll" then return "Haven't figured out how to allow this yet!" end

        -- weapon that's in an inventory check
        if ent:IsWeapon() then
            local entOwner = ent:GetOwner()

            if entOwner:IsPlayer() then
                return "Can't wrap; it already entered "..(entOwner == wrapper and "your" or "someone's").." inventory."
            else
                return nil
            end
        end

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
            "ttt_cse_proj",
            "ttt_chomik",
            "sent_controllable_manhack",
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
            "ent_ttt_fan",
            --"ttt_flame", --TODO: bugged
            --"sent_greendemon_box", --TODO: bugged (ui remains), needs ownership check, possible balance issue
            --"sent_greendemon", --TODO: bugged
            "ttt_hat_deerstalker",
            "env_headcrabcanister", -- blocked later (affixed)
            "npc_headcrab",
            "npc_headcrab_fast", -- bunger
            "ttt_health_station", -- TODO: ownership check
            "ttt_seekgull_bird", -- blocked later i'm fairly sure, TODO make work properly
            "ttt_knife_proj",
            "item_lethal_company_landmine", -- blocked later (affixed)
            "matryoshka", -- blocked later (affixed) (breaching charge)
            "npc_metropolice", -- wraps SuperCop, should be PaP only
            "ttt_minecraft_arrow", -- TODO: bugged, can't be selected
            "sent_molotov_timed",
            "sent_molotov",
            "moonball",
            "ent_moongrenade",
            --"ttt_paper_plane_proj", -- TODO: bugged (trails continues, probably still exists), needs ownership check
            "ttt_poison_station", -- TODO: ownership check
            "ttt_potofgreedier",
            --"ttt_radio", -- blocked later if affixed; TODO: bugged (markervision; can get permanent burning SFX?), need ownership check
            --"ttt_ragnana_peel",
            --"sent_rcxd",
            "shield_deployer",
            --"ttt_slam_satchel", -- TODO: bugged (ui remains), needs ownership check
            "ttt_shard_of_greed",
            "ttt2_hat_shellmet",
            "ttt_slam_tripmine", -- blocked later (affixed)
            "ttt_soap", -- blocked later (affixed); TODO consider making moveable with ownership check
            "ttt_springmine", -- blocked later (affixed); TODO consider making moveable with ownership check
            --"plasma_burster_nade", -- good luck wrapping that; TODO fix the whole thing being ass
            "npc_turret_floor",
            --"ttt_wormhole", -- blocked later (affixed); TODO: bugged (angle is reset to parallel with ground on unwrap)
            "ttt_zombieball_proj", -- TODO: try wrapping an existing one somehow???
            "npc_zombie",
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
        if phys:GetMass() > 700 then
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

            if utils.IsGiftWrap(wep) and wep:HeldByWrapper(ply)
              and (not ply.LastGiftPlace or CurTime() > ply.LastGiftPlace + 1) then
                 -- not really sure why I wanted these not to be retrievable, odd
                local giftProp = wep:MakePropCopy(false)

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
                ply.LastGiftPlace = CurTime() -- wep:Remove() can apparently fail to immediately mean the owner doesn't hold it on real servers, so this is needed
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
    GW_METASWEP.WorldModel    = WRAP_WORLDMODEL --purely for Contents menu rendering

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

    elseif SERVER then
        RollGiftColors(self)
    end

    return self.BaseClass.Initialize(self)
end

function SWEP:UpdateModel(reason)
    local hasGiftNow = self:HasGift()
    dbg.Log("Updating model... ("..(hasGiftNow and "-> Gift" or "Wrap").." model; "..reason..")")
    local vmChange = false

    if not hasGiftNow then
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

    if CLIENT then
        if hasGiftNow then
            SetGiftColors(self, self:GetGiftBoxColor(), self:GetGiftRibbonColor())
        else
            ClearGiftColors(self)
        end
    end

    if vmChange then
        dbg.Log(" => Attempting to change viewmodel")
        local owner = self:GetOwner()

        -- note: the GetViewModel function existence check is for Doppelganger lol
        if IsValid(owner) and owner.GetViewModel then
            self:SetModel(self.ViewModel)
            self:ResetSequenceInfo()
            local vm = owner:GetViewModel()

            if IsValid(vm) then
                dbg.Log(" => Changing to "..self.ViewModel)
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
    local boolCnt, intCnt, stringCnt, entCnt = utils.SetupSharedTable(self)
    self:NetworkVar("Bool", boolCnt, "IsOpening")
    self:NetworkVar("Bool", boolCnt+1, "IsShaking")

    if CLIENT then
        self:NetworkVarNotify("StoredGift", function(ent, name, old, new)
            timer.Simple(0.1, function() -- value isn't changed yet
                if not IsValid(self) then return end
                self:UpdateUI("storage update")
                self:UpdateModel("storage update")
                self:UpdateMarkerVision("storage update")

                if not self:HasGift() and not self:GetIsOpening() then
                    self:EmitSound(sounds["undo_wrap"], 150, math.random(90, 110))
                end

                UpdateGiftContentMenu()
            end)
        end)

        local function UpdateUIAndMenu(ent, name, old, new)
            timer.Simple(0.1, function()
                if IsValid(self) then
                    self:UpdateUI(name.." update")
                    UpdateGiftContentMenu()
                end
            end)
        end

        self:NetworkVarNotify("IsRandomGift", UpdateUIAndMenu)
        self:NetworkVarNotify("WrapperSID", UpdateUIAndMenu)

        local function InvalidateVMColor(ent, name, old, new)
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            ply:GetViewModel()._gwColorsApplied = false
        end

        self:NetworkVarNotify("GiftBoxColor", InvalidateVMColor)
        self:NetworkVarNotify("GiftRibbonColor", InvalidateVMColor)
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

        if tr.HitNonWorld and IsValid(hitEnt) and owner:GetShootPos():Distance(tr.HitPos) <= 150 then
            self:SendWeaponAnim(ACT_VM_HITCENTER)
            self:EmitSound(sounds["wrapping"], 75, math.random(90, 110))

            if SERVER then
                owner:SetAnimation(PLAYER_ATTACK1)
                timer.Simple(0.2, function()
                    if IsValid(hitEnt) then
                        self:Wrap(hitEnt)
                    end
                end)
            end
        else
            self:EmitSound(sounds["swing"], 75, math.random(90, 110))
            self:SendWeaponAnim(ACT_VM_MISSCENTER)
        end

    else
        if self:OwnedByWrapper(owner) then -- Throw gift prop
            self:Throw(owner)

        else -- Try to open gift
            local ownerOpenedRandomGift = owner:GetNWBool("OpenedRandomGift")
            local giftee = self:GetGiftee()

            -- Throw if not allowed due to opening a second random gift; TODO: only natural random gifts
            --[[if ownerOpenedRandomGift and self:GetIsRandomGift() and not dbg.Cvar:GetBool() then
                utils.NonSpamMessage(owner, "OpenAttempt", ERROR_ALREADY_OPENED)
                self:Throw(owner)

            -- Throw if not allowed due to not being giftee (failsafe)
            else]]if IsValid(giftee) and owner != giftee and not utils.ConfirmedDead(owner, giftee) then
                if SERVER then notifyHasGiftee(owner, giftee) end
                self:Throw(owner)

            else -- Open gift
                if SERVER then
                    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
                    self:SetIsOpening(true)

                    timer.Simple(0.9, function()
                        if not IsValid(self) then return end
                        self:DropContents()
                        self:Remove()

                        if self:GetIsRandomGift() and not ownerOpenedRandomGift then
                            dbg.Log(owner:Nick() .. " opened a random gift!")
                            owner:SetNWBool("OpenedRandomGift", true)
                        end
                    end)
                else
                    self:EmitSound(sounds["unwrap"], 100, math.random(90, 110))
                end
            end
        end
    end
end

function SWEP:SecondaryAttack()
    if self:GetIsOpening() then return end
    local owner = self:GetOwner()
    if not owner then return end

    if not self:HasGift() or self:OwnedByWrapper() then -- gift options
        if CLIENT then OpenGiftOptions(self) end

    elseif not self:GetIsShaking() then -- shake
        self:EmitSound(sounds["generic_shake"], 100, math.random(95, 105))
        self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)

        if SERVER then
            self:SetIsShaking(true)
            timer.Simple(1.25, function() 
                if IsValid(self) then self:SetIsShaking(false) end
            end)

            local cachedData = GetCachedGiftData(self, owner)
            local firstPart, secondPart, thirdPart = cachedData:Inspect(self)

            net.Start(GIFTWRAP_HL_CHAT_MSG)
            net.WriteString(firstPart)
            net.WriteString(secondPart)
            net.WriteString(thirdPart)
            net.Send(owner)
        end
    end
end

function SWEP:HasGift()
    return self:GetCachedDataLabel() ~= "" or self:GetIsRandomGift()
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

function SWEP:OnRemove()
    if self:GetMarkerVision(MV_WRAPPER_LABEL) then
        self:RemoveMarkerVision(MV_WRAPPER_LABEL)
    end
end

function SWEP:Throw(owner, force)
    if not owner then owner = self:GetOwner() end
    if not IsValid(owner) then return end

    if SERVER then
        local giftData = GetCachedGiftData(self, owner)
        local giftProp = self:MakePropCopy(false)
        if not IsValid(giftProp) then return end

        local spawnPos = owner:GetShootPos()
        giftProp._LastPos = spawnPos
        giftProp:SetPos(spawnPos)
        giftProp:Spawn()

        local phys = giftProp:GetPhysicsObject()
        if IsValid(phys) then
            if not force then force = 800 end
            local throwVel = owner:GetAimVector()
            --throwVel.z = 0.3 -- hardlock trajectory vertically
            throwVel = throwVel * (force + 150*(giftData.attrib_size or 1))

            phys:SetVelocity(throwVel)
            phys:AddAngleVelocity(Vector(0, 0, 500))
        end

        self._PreserveGift = true
        self:Remove()
        owner:EmitSound(sounds["throw"], 75, math.random(90, 120))

    elseif CLIENT then
        ClearVMColors(owner, "throw")
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

        if self:HasGift() then
            self:Throw(nil, 400)
        end
    end

    -- non-SWEP; for use by both SWEP and prop gift
    -- can be called without giftee for non-random gifts
    function GetCachedGiftData(giftObj, giftee)
        local cachedDataLabel = giftObj:GetCachedDataLabel()
        local cachedData = GetGiftDataFromLabel(cachedDataLabel)

        if not giftObj:GetIsRandomGift() then -- preset gift
            if not cachedData then -- cache it from stored gift
                local newLabel, newData = GetEntGiftData(giftObj:GetStoredGift())
                giftObj:SetCachedDataLabel(newLabel)

                dbg.Log("Requesting preset gift data; cached", newLabel)
                return newData

            else -- use cache
                dbg.Log("Requesting preset gift data; using cached", cachedDataLabel)
                return cachedData
            end

        else -- random gift
            if not (cachedData and cachedData:IsSpawnable(giftee)) then  -- cache random gift data
                local newLabel, newData = GetRandomGiftData(giftee)
                newData:ApplyOnAutoWrapAdjustments(giftObj)
                giftObj:SetCachedDataLabel(newLabel)

                dbg.Log("Requesting random gift data; cached new", newLabel)
                return newData

            else -- use cache
                dbg.Log("Requesting random gift data; using cached", cachedDataLabel)
                return cachedData
            end
        end
    end

    local superRare = {
        "You got a Super Rare item!",
        "You pulled a Super Rare!",
        "You found a Super Rare gift!",
        "It's a Super Rare!",
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
    function SpawnGiftEnt(gifteePly, giftObj, spawnPos, isUndo)
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
                    local scaleFactor = (giftData.attrib_size-3 or 0) * 12
                    hitPos = gifteePly:EyePos() + gifteePly:GetAimVector() * (80 + scaleFactor)
                end

                -- Maximum extent along the hit normal (how far it sticks out in that direction)
                local mins, maxs = giftEnt:OBBMins(), giftEnt:OBBMaxs()
                local extent = math.max(mins:Dot(tr.HitNormal * -1),
                                        maxs:Dot(tr.HitNormal * -1))

                spawnPos = hitPos + tr.HitNormal * extent
            end

            -- Plop back into world
            local doStabilize = #giftEnt:GetChildren() > 0 or giftData.category == GiftCategory.Vehicle
            utils.ExitStasis(giftEnt, spawnPos, doStabilize)
            giftData:ApplyPostUnwrapAdjustments(giftEnt, gifteePly, giftObj, isUndo)

        else -- for particle position later
            spawnPos = gifteePly:GetShootPos()
            giftData:ApplyPostUnwrapAdjustments(nil, gifteePly, isUndo)
        end

        -- Wrapper Toast Notif
        local wrapper = utils.GetWrapper(giftObj)

        if not isUndo and IsValid(wrapper) then
            LANG.Msg(wrapper, "gift_unwrap_notif_wrapper", {giftee = gifteePly:Nick()}, MSG_MSTACK_PLAIN)
        end

        -- Chat & Global Toast Notif
        if giftEnt ~= false then
            local isRandomGift = giftObj:GetIsRandomGift()

            if isRandomGift then
                if giftData.factor_rarity and giftData.factor_rarity >= 5 then
                    gifteePly:ChatPrint(superRare[math.random(#superRare)])

                elseif giftData.factor_quality then
                    if giftData.factor_quality >= 7 then
                        gifteePly:ChatPrint(niceList[math.random(#niceList)])

                    elseif giftData.factor_quality <= -7 then
                        gifteePly:ChatPrint(naughtyList[math.random(#naughtyList)])
                    end
                end
            end

            local uninvolvedPlayers = {}
            local nearbyPlayers = {}

            for _, ply in ipairs(player.GetAll()) do
                if ply ~= gifteePly and ply ~= wrapper then
                    table.insert(uninvolvedPlayers, ply)

                    if ply:GetPos():Distance(gifteePly:GetPos()) <= 300 then
                        table.insert(nearbyPlayers, ply)
                    end
                end
            end

            local intendedGiftee = giftObj:GetGiftee()
            local giftDesc = giftData:GetDesc(giftEnt, gifteePly)
            local rightText = "!"

            if not isUndo and IsValid(intendedGiftee) and gifteePly != intendedGiftee
              and utils.ConfirmedDead(gifteePly, intendedGiftee) then
                rightText = " meant for "..intendedGiftee:Nick().." (RIP)!"
            end

            net.Start(GIFTWRAP_HL_CHAT_MSG)
            net.WriteString("You unwrapped ")
            net.WriteString(giftDesc)
            net.WriteString(rightText)
            net.Send(gifteePly)

            net.Start(GIFTWRAP_HL_CHAT_MSG)
            net.WriteString("Someone nearby unwrapped ")
            net.WriteString(giftDesc)
            net.WriteString(rightText)
            net.Send(nearbyPlayers)

            local unwrapNote = giftObj:GetUnwrapNote()
            dbg.Log("Unwrap note: '"..unwrapNote.."'")

            if not isUndo and unwrapNote and unwrapNote != "" then
                timer.Simple(1, function()
                    net.Start(GIFTWRAP_HL_CHAT_MSG)
                    net.WriteString("A note was attached: \"")
                    net.WriteString(unwrapNote)
                    net.WriteString("\"")
                    net.Send(table.Add({gifteePly}, nearbyPlayers))
                end)
            end

            if not isUndo and isRandomGift then
                if giftData.factor_rarity and giftData.factor_rarity >= 5 then
                    LANG.Msg(uninvolvedPlayers, "gift_unwrap_notif_rare", nil, MSG_MSTACK_WARN)
                else
                    LANG.Msg(uninvolvedPlayers, "gift_unwrap_notif_random", nil, MSG_MSTACK_PLAIN)
                end
            end

        else
            net.Start(GIFTWRAP_HL_CHAT_MSG)
            net.WriteString("You were meant to unwrap ")
            net.WriteString(giftDesc .. " (" .. giftData.name ..")")
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
                local flourishType = math.random(4)
                dropSnd = "flourish_sl" .. flourishType
                dropVol = 0.75
                dropPitch = 100

                if math.random(5) == 5 then
                    timer.Simple(0.2, function()
                        sndOrigin:EmitSound(sounds["flourish_yippie"], 75, 100, 0.6)
                    end)
                end
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

    function SWEP:DropContents(isUndo)
        local owner = self:GetOwner()

        if IsValid(owner) and self:HasGift() then
            SpawnGiftEnt(owner, self, nil, isUndo)

            dbg.Log("Dropped gift contents")
            self:SetWrapperSID("")
            self:SetStoredGift(nil)
            self:SetCachedDataLabel("")
            self:UpdateModel("dropped gift")
        end
    end

    function SWEP:MakePropCopy(notRetrievable)
        if not self:HasGift(storedGift) then return nil end
        local giftProp = ents.Create(PROP_CLASS_NAME)

        utils.TransferNetVars(self, giftProp)
        giftProp:SetNotRetrievable(notRetrievable)

        return giftProp
    end

    function SWEP:Reload()
        local owner = self:GetOwner()

        if self:OwnedByWrapper(owner) and not self:GetIsOpening() and not self:GetIsRandomGift() then
            local giftData = GetCachedGiftData(self, owner)

            if not giftData:IsDropBlocked() then
                self:DropContents(true)
            else
                utils.NonSpamMessage(owner, "ReloadAttempt", "Undoing wrap for special entities is currently disabled as a precaution.")
            end
        end
    end

    function SWEP:Wrap(ent)
        dbg.Log("Wrap attempt on:", ent)
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

         -- check one layer up the parenting chain (useful for vehicles)
        local moveParent = ent:GetMoveParent()
        if IsValid(moveParent) then ent = moveParent end

        local wrapCheckRet = GetWrapConstraint(ent, owner)

        if wrapCheckRet then
            owner:ChatPrint(wrapCheckRet)

        else
            utils.EnterStasis(self, ent)
            self:SetWrapperSID(owner:SteamID64())
            self:SetStoredGift(ent)

            local newLabel, newData = GetEntGiftData(ent)
            self:SetCachedDataLabel(newLabel)
            newData:ApplyOnWrapAdjustments(ent, self)

            net.Start(GIFTWRAP_GIFT_DATA_MSG)
            net.WriteString(newLabel)
            net.WriteTable(newData)
            net.Broadcast()

            ent:CallOnRemove(WRAPPED_GIFT_REMOVE, function()
                if IsValid(self) and IsValid(owner) then
                    local invGiftWrap = utils.GetInventoryGiftwrap(owner)

                    if invGiftWrap and invGiftWrap:HasGift() and invGiftWrap:GetStoredGift() == ent then
                        owner:ChatPrint("The gift somehow disappeared, leaving the wrapping paper behind.")
                    end
                end
            end)

            self:UpdateModel("wrapped gift")
        end
    end

    function SWEP:AutoWrap(label, data)
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        self:SetCachedDataLabel(label)
        self:SetWrapperSID(owner:SteamID64())
        self:SetIsRandomGift(true)
        data:ApplyOnAutoWrapAdjustments(self)

        -- Note: I have no clue why I need to do this for the colors
        --       to update properly and I hate it (TODO clean up?)
        owner:SelectWeapon('weapon_zm_improvised')
        timer.Simple(0.1, function()
            owner:SelectWeapon('weapon_ttt_giftwrap')
        end)

        -- Send table data update, just in case
        net.Start(GIFTWRAP_GIFT_DATA_MSG)
        net.WriteString(label)
        net.WriteTable(data)
        net.Send(owner)
    end

    function SWEP:OnRemove()
        if self._PreserveGift then return end
        local storedGift = self:GetStoredGift()
        --dbg.Log("Removing gift w/ stored:", storedGift)

        if IsValid(storedGift) then
            dbg.Log("Removing stored gift:", storedGift)
            storedGift:RemoveCallOnRemove(WRAPPED_GIFT_REMOVE)
            storedGift:Remove()
        end
    end

----------------------------------
----- CLIENT REALM SWEP DEFS -----
----------------------------------
elseif CLIENT then
    function SWEP:PostDrawViewModel(vm, weapon, ply)
        if self:HasGift() then
            if not vm._gwColorsApplied then
                SetGiftColors(vm, self:GetGiftBoxColor(), self:GetGiftRibbonColor())
                vm._gwColorsApplied = true
            end

        else
            vm._gwColorsApplied = false
            ClearGiftColors(vm)
        end
    end

    function ClearVMColors(ply, reason)
        if not IsValid(ply) then return end

        local vm = ply:GetViewModel()
        if not vm._gwColorsApplied then return end
        dbg.Log("Clearing viewmodel colors for "..ply:Nick().." ("..reason..")")

        if IsValid(vm) then
            timer.Simple(0.1, function()
                ClearGiftColors(vm)
            end)
            vm._gwColorsApplied = false
        end
    end

    hook.Add("Think", HOOK_RESET_VM_COLORS, function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local heldWep = ply:GetActiveWeapon()

        if not utils.IsGiftWrap(heldWep) then
            ClearVMColors(ply, "watchdog hook")

            -- auto-close options menu (& shop if open)
            if IsValid(HELPSCRN._gwOptMenu) and
             (not IsValid(heldWep) or heldWep:GetClass() != 'weapon_zm_improvised') then --further jank due to the jank mentioned in AutoWrap
                HELPSCRN._gwOptMenu:Close()
                RunConsoleCommand("ttt_cl_traitorpopup_close")
            end
        end
    end)

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

    net.Receive(GIFTWRAP_GIFT_DATA_MSG, function()
        local label = net.ReadString()
        local giftData = NewGiftData(net.ReadTable())

        UpdateCatalog(label, giftData)
    end)

    local TREE_COLOR = Color(15, 155, 10)
    function SWEP:UpdateMarkerVision(reason)
        if christmasTree then
            dbg.Log("Updating tree beacon... ("..reason..")")
            local mvLabel = MV_TREE_LABEL..self:EntIndex()
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

                    christmasTree:CallOnRemove(MV_TREE_LABEL, function(goneEnt)
                        goneEnt:RemoveMarkerVision(mvLabel)
                    end)

                    marks.Add({christmasTree}, TREE_COLOR)
                end
            end
        end
    end

    function SWEP:Holster()
        self:UpdateMarkerVision("holster")
        ClearVMColors(self:GetOwner(), "holster")
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
            serverConvar = "ttt2_giftwrap_timezone_offset",
            label = "label_giftwrap_timezone_offset",
            min = -24, max = 24, decimal = 0
        })
        formRNGift:MakeHelp({
            label = "label_giftwrap_all_served_chime_vol_desc"
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_all_served_chime_vol",
            label = "label_giftwrap_all_served_chime_vol",
            min = 0, max = 100, decimal = 0
        })
        formRNGift:MakeHelp({
            label = "label_giftwrap_bonus_gifts_desc"
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_second_gift_chance",
            label = "label_giftwrap_second_gift_chance",
            min = 0, max = 1, decimal = 2
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_third_gift_chance",
            label = "label_giftwrap_third_gift_chance",
            min = 0, max = 1, decimal = 2
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_second_gift_chance_xmas",
            label = "label_giftwrap_second_gift_chance_xmas",
            min = 0, max = 1, decimal = 2
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_third_gift_chance_xmas",
            label = "label_giftwrap_third_gift_chance_xmas",
            min = 0, max = 1, decimal = 2
        })
        formRNGift:MakeHelp({
            label = "label_giftwrap_match_playercount_desc"
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_match_playercount",
            label = "label_giftwrap_match_playercount",
            min = 0, max = 1, decimal = 2
        })
        formRNGift:MakeSlider({
            serverConvar = "ttt2_giftwrap_match_playercount_xmas",
            label = "label_giftwrap_match_playercount_xmas",
            min = 0, max = 1, decimal = 2
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

        local formVDFix = vgui.CreateTTT2Form(parent, "label_giftwrap_vdfix_form")
        formVDFix:MakeHelp({
            label = "label_vehicle_damagefix_desc"
        })
        formVDFix:MakeCheckBox({
            serverConvar = "ttt2_vehicle_damagefix_enable",
            label = "label_vehicle_damagefix_enable"
        })
        formVDFix:MakeSlider({
            serverConvar = "ttt2_vehicle_damagefix_driver_mult",
            label = "label_vehicle_damagefix_driver_mult",
            min = 0, max = 100, decimal = 0
        })
        formVDFix:MakeSlider({
            serverConvar = "ttt2_vehicle_damagefix_passenger_mult",
            label = "label_vehicle_damagefix_passenger_mult",
            min = 0, max = 100, decimal = 0
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