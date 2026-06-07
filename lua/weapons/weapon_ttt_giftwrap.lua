----------------------------------
------- CONSTANTS & CVARS --------
----------------------------------
local TryT  = LANG.TryTranslation
local dbg   = GW_DBG
local utils = GW_Utils
local WRAP_NAME = "Gift Wrap"
local GIFT_NAME = "Gift"

local HOOK_SPEC_ADD_AMMOTYPE = "TTT_GiftWrap_AddAmmoTypeInit"
local HOOK_SPEC_GIFT_INDIC   = "TTT_GiftWrapCL_DrawSpectatorGiftHUD"
local GIFTWRAP_PICKUP_MSG    = "TTT_GiftWrap_PickUpMsg"
local GIFTWRAP_HL_CHAT_MSG   = "TTT_GiftWrap_HighlightChatMsg"
local GIFTWRAP_GIFT_DATA_MSG = "TTT_GiftWrap_SendWrapperDataMsg"
local CLIENT_FLOURISH_MSG    = "TTT_GiftWrapSV_WrappedPlayerFlourishMsg"
local HOOK_GIFTWRAP_PICKUP   = "TTT_GiftWrap_PickUp"
local HOOK_GIFTWRAP_TREE_USE = "TTT_GiftWrap_UseTree"
local HOOK_ANGLE_CORRECTION  = "TTT_GiftWrap_CorrectGiftAngle"
local HOOK_ROUND_RESET_OPENS = "TTT_GiftWrapSV_ResetOpenedRandomGiftCounts"
local HOOK_ROUND_END         = "TTT_GiftWrapSV_RemoveGiftEntCallOnRemoves"
local HOOK_RELOAD_SOUNDS     = "TTT_GiftWrap_ReloadSounds"
local HOOK_RESET_VM_COLORS   = "TTT_GiftWrap_ResetVMColors"
local GIFTWRAP_REMOVE        = "TTT_GiftWrap_XMasBeaconRemove"
WRAPPED_GIFT_REMOVE          = "TTT_GiftWrap_WrappedGiftRemove"
TP_GIFT_MSG                  = "TTT_GiftWrapSV_TeleportGift"
WRAP_CONSTRAINT_QUERY_MSG    = "TTT_GiftWrapCL_WrapConstraintQueryMsg"
WRAP_CONSTRAINT_REPLY_MSG    = "TTT_GiftWrapSV_WrapConstraintResponseMsg"

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

game.AddParticles("particles/flies_fx.pcf")

----------------------------------
--- SERVER REALM SETUP / HOOKS ---
----------------------------------
if SERVER then
    dbg.Log("Initializing....")

    AddCSLuaFile("weapon_ttt_giftwrap.lua")
    resource.AddFile("materials/"..GIFTWRAP_ICON..".vmt")
    PrecacheParticleSystem("flies_fx")

    util.AddNetworkString(CLIENT_FLOURISH_MSG)
    util.AddNetworkString(GIFTWRAP_PICKUP_MSG)
    util.AddNetworkString(GIFTWRAP_HL_CHAT_MSG)
    util.AddNetworkString(GIFTWRAP_GIFT_DATA_MSG)
    util.AddNetworkString(WRAP_CONSTRAINT_QUERY_MSG)
    util.AddNetworkString(WRAP_CONSTRAINT_REPLY_MSG)
    util.AddNetworkString(TP_GIFT_MSG)
    util.PrecacheModel(WRAP_VIEWMODEL)
    util.PrecacheModel(WRAP_WORLDMODEL)
    util.PrecacheModel(GIFT_VIEWMODEL)
    util.PrecacheModel(GIFT_WORLDMODEL)
    util.PrecacheSound("giftwrap/flies_loop.wav")

    -- reset "opened gift" states & determine random gift spawn parameters
    hook.Add("TTTBeginRound", HOOK_ROUND_RESET_OPENS, function()
        for _, ply in ipairs(player.GetAll()) do
            ply:SetNWBool("OpenedRandomGift", false)
            ply:SetNWBool("GotFirstTimeSample", false)
            ply:StopParticles()
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

    hook.Add("PreCleanupMap", HOOK_ROUND_END, function()
        -- otherwise entities that are removed before weapons (i.e. ragdolls)
        -- trigger the OnRemove chat message
        for _, wep in ipairs(ents.FindByClass(SWEP_CLASS_NAME)) do
            local storedEnt = wep:GetStoredGift()

            if IsValid(storedEnt) then
                storedEnt:RemoveCallOnRemove(WRAPPED_GIFT_REMOVE)
            end
        end
    end)

    function GetWrapConstraint(ent, wrapper, silent)
        if not IsValid(ent) then return "Invalid object." end
        if ent.Base == "base_ammo_ttt" then return nil end
        if ent.GetExplodeTime then return nil end

        local phys  = ent:GetPhysicsObject()
        local class = ent:GetClass()

        -- weapon that's in an inventory check
        if ent:IsWeapon() then
            local entOwner = ent:GetOwner()

            if entOwner:IsPlayer() then
                return "Can't wrap; it already entered "..(entOwner == wrapper and "your" or "someone's").." inventory."
            else
                return nil
            end
        end

        -- func_breakables (usually filtered out, can be move parent)
        if utils.IsMapClass(ent) then
            return "This is too important to wrap."
        end

        local override_classes = {
            "ttt_chicken",
            "force_shield",
            "ent_fortnitestructure",
            "glue_trap_paste",
            "hwapoon_arrow",
            "ttt_kfc",
            "item_lethal_company_landmine",
            "ttt_seekgull_bird",
            "ttt_soap",
            "ttt_springmine",
            "ttt_wormhole"
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
            "npc_barnacle",
            "ent_ttt_ttt2_camera", -- blocked later (affixed)
            "cannon_ent",
            "ttt_conmine",
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
            "ttt_bungernade_proj",
            "ttt_decoy", -- blocked later if affixed
            "ttt_thrownflashbang",
            "ent_fortnitestructure",
            "ent_ttt_fan",
            "ttt_flame",
            "force_shield", -- blocked later (no phys, won't budge)
            "sent_greendemon_box",
            "sent_greendemon",
            "ttt2_hat_baron",
            "ttt_hat_deerstalker",
            "env_headcrabcanister", -- blocked later (affixed)
            "npc_headcrab",
            "npc_headcrab_black",
            "npc_headcrab_fast", -- bunger
            "ttt_health_station",
            "hwapoon_arrow",
            "icegrenade_proj",
            "ttt_seekgull_bird",
            "ttt_knife_proj",
            "item_lethal_company_landmine",
            "matryoshka", -- blocked later (affixed) (breaching charge)
            --"npc_metropolice", -- wraps SuperCop, should be PaP only
            "ttt_minecraft_arrow",
            "sent_molotov_timed",
            "sent_molotov",
            "moonball",
            "ent_moongrenade",
            "ttt_paper_plane_proj",
            "ttt_poison_station",
            "ttt_potofgreedier",
            "ttt_radio",
            "ttt_ragnana_peel",
            "sent_rcxd",
            "shield_deployer",
            "ttt_slam_satchel",
            "ttt_shard_of_greed",
            "ttt2_hat_shellmet",
            "ttt_slam_tripmine", -- blocked later (affixed)
            "ttt_soap",
            "ttt_springmine",
            "plasma_burster_nade",
            "npc_turret_floor",
            "ttt_wormhole",
            "ttt_zombieball_proj",
            "npc_zombie",
        }

        -- living player check
        if ent:IsPlayer() then
            return "You can't wrap a living player!"

        elseif ent:GetClass() == "prop_ragdoll" then
            for _, child in ipairs(ent:GetChildren()) do
                if child:IsPlayer() then
                    return "You can't wrap a living player!"
                end
            end
        end

        -- validity check
        if not table.HasValue(valid_classes, class) and string.sub(ent:GetClass(), 1, 5) ~= "prop_" then
            if not silent then dbg.Log("Tried wrapping: "..class) end
            return "Can't wrap this type of thing yet."
        end

        -- moveability check
        if not IsValid(phys) or not phys:IsMoveable() or ent.CanPickup == false
          or phys:HasGameFlag(FVPHYSICS_NO_PLAYER_PICKUP) then
            return "It won't budge."
        end

        -- weight check
        if phys:GetMass() > 700 then
            if not silent then dbg.Log("Tried wrapping "..class.." with mass "..phys:GetMass()) end
            return "It's too heavy, and you don't have enough wrapping paper."
        end
    end

    net.Receive(WRAP_CONSTRAINT_QUERY_MSG, function(_, ply)
        local ent = net.ReadEntity()

        net.Start(WRAP_CONSTRAINT_REPLY_MSG)
        net.WriteFloat(ent:EntIndex())

        -- same operation performed when wrapping
        local moveParent = ent:GetMoveParent()
        if IsValid(moveParent) and not ent:IsWeapon() then ent = moveParent end

        local constraint  = GetWrapConstraint(ent, ply, true)
        local _, giftData = GetEntGiftData(ent, true)

        net.WriteString((constraint and not ent:GetNWBool("GWPhysStasis")) and constraint or "")
        net.WriteFloat(giftData:GetPaperAmount(nil, ent))
        net.Send(ply)
    end)

    -- Tell clients to update UI when it enters their inventory (no reliable clientside hook?)
    hook.Add("WeaponEquip", HOOK_GIFTWRAP_PICKUP, function(wep, ply)
        if utils.IsGiftWrap(wep) then
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
            Reload to discard the wrap.

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
            ownedGiftwrap:UpdateAmmo(reason)
        end
    end

    net.Receive(GIFTWRAP_PICKUP_MSG, function()
        timer.Simple(0.01, function() -- safety sync wait
            dbg.Log("Received pickup notif")
            UpdateLocalInventoryGiftWrap("pickup")
        end)
    end)

    net.Receive(CLIENT_FLOURISH_MSG, function()
        local sound = net.ReadString()
        LocalPlayer():EmitSound(sounds[sound], 75, 100, 0.8)
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

    hook.Add("HUDPaint", HOOK_SPEC_GIFT_INDIC, function()
        local ply = LocalPlayer()
        local tgt = ply:GetObserverTarget()
        if utils.IsLivingPlayer(ply) or not IsValid(tgt) or not tgt:IsPlayer() then return end

        local gift = utils.GetInventoryGiftwrap(tgt)
        if not IsValid(gift) or not gift:HasGift() then return end

        -- checks passed, start drawing gift indicator
        local curHUD = HUDManager.GetHUD()
        local hud = huds.GetStored(curHUD)

        -- positioning & drawing background box
        local x = 10
        local y = ScrH() - 230
        local bgSize = 30
        local iconScale = 0.59
        local textScale = 0.7
        local bgCol = Color(49, 71, 94)
        local xOffset = 0

        if curHUD == "pure_skin" then
            local playerInfoHUD = hudelements.GetStored("pure_skin_playerinfo")
            local infoPos = playerInfoHUD:GetPos()
            local infoSize = playerInfoHUD:GetSize()
            infoPos.y = infoPos.y + infoSize.h - playerInfoHUD.lpw
            infoSize.h = playerInfoHUD.lpw

            x = infoPos.x + infoSize.w + playerInfoHUD.pad
            y = infoPos.y
            bgSize = infoSize.h
            bgCol = hud.basecolor

        elseif curHUD == "old_ttt" then
            local playerInfoHUD = hudelements.GetStored("old_ttt_info")
            local infoPos = playerInfoHUD:GetPos()
            local infoSize = playerInfoHUD:GetSize()

            x = infoPos.x + infoSize.w + 10
            y = infoPos.y + infoSize.h - bgSize
            bgCol = playerInfoHUD.bg_colors.background_main
            xOffset = 1
        end

        surface.SetDrawColor(clr(bgCol))
        if curHUD ~= "old_ttt" then
            surface.DrawRect(x, y, bgSize, bgSize)
            DrawHUDElementLines(x, y, bgSize, bgSize, 255)
        else
            draw.RoundedBox(8, x, y, bgSize, bgSize, bgCol)
        end

        -- drawing gift icon
        draw.FilteredShadowedTexture(
            x + (bgSize/2) * (1 - iconScale) + xOffset,
            y + 2,
            bgSize * iconScale, bgSize * iconScale,
            MAT_GIFT_ICON, 255, COLOR_WHITE, 1
        )

        -- drawing keybind
        draw.AdvancedText(
            Key("gm_showspare2"),
            "weapon_hud_help_key",
            x + (bgSize/2) - 1 + xOffset,
            y + bgSize - 10,
            COLOR_WHITE,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP,
            true, textScale
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
SWEP.Primary.Automatic   = -1
SWEP.Primary.Delay       = 0.5
SWEP.Primary.Ammo        = "wrap_paper"

SWEP.Kind        = WEAPON_EQUIP
SWEP.CanBuy      = {ROLE_TRAITOR, ROLE_JACKAL}
SWEP.AllowDrop   = true
SWEP.DeploySpeed = 2

hook.Add("Initialize", HOOK_SPEC_ADD_AMMOTYPE, function()
    -- only added due to annoying extra checks Advanced Spectator does
    -- when retrieving the ammo icon
    game.AddAmmoType({name = "wrap_paper"})
end)

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
        self:SetRemainingPaper(100)
    end

    return self.BaseClass.Initialize(self)
end

function SWEP:UpdateModel(reason)
    local hasGiftNow = self:HasGift()
    dbg.Log("Updating model... (-> "..(hasGiftNow and "Gift" or "Wrap").." model; "..reason..")")
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
    elseif SERVER then
        if hasGiftNow and self:GetCachedDataLabel() == "flame" then
            self:Ignite(3600)
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

                UpdateGiftContentMenu(self:GetOwner())
            end)
        end)

        local function UpdateUIAndMenu(ent, name, old, new)
            timer.Simple(0.1, function()
                if IsValid(self) then
                    self:UpdateUI(name.." update")
                    self:UpdateModel(name.." update")
                    UpdateGiftContentMenu(self:GetOwner())
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
    if self:GetMarkerVision(MV_WRAPPER_LABEL) then
        self:RemoveMarkerVision(MV_WRAPPER_LABEL)
    end

    if SERVER and not self._PreserveGift then
        local storedGift = self:GetStoredGift()

        if IsValid(storedGift) then
            dbg.Log("Removing stored gift:", storedGift)
            storedGift:RemoveCallOnRemove(WRAPPED_GIFT_REMOVE)
            storedGift:Remove()

            local owner = self:GetOwner()
            if self:GetNW2Bool("GWStinky") and IsValid(owner) then
                owner:StopParticles()
            end
        end

    elseif CLIENT then
        if IsValid(HELPSCRN._gwOptMenu) and HELPSCRN._gwRef == self then
            HELPSCRN._gwOptMenu:Close()
        end
    end
end

function SWEP:Deploy()
    self.Weapon:SendWeaponAnim(ACT_VM_DRAW)
    self:UpdateModel("deploy")

    if CLIENT then 
        self:UpdateUI("deploy")
        self:UpdateMarkerVision("deploy")

    elseif SERVER then
        if self:GetGiftee() == self:GetOwner() and not self:HasGift() then
            self:SetGiftee(NULL)
        end
    end
end

function SWEP:Throw(owner, force)
    if not owner then owner = self:GetOwner() end
    if not IsValid(owner) then return end

    if SERVER and not self._PreventThrow then
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
            throwVel = throwVel * (force + 150*(giftData:GetSize(self) or 1))

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

function SWEP:GetPaperOnUndo()
    if not self:HasGift() then return end

    local giftData  = GetGiftDataFromLabel(self:GetCachedDataLabel())
    local paperCost = giftData:GetPaperAmount(self)

    return math.max(0, self:GetRemainingPaper() - paperCost), paperCost
end

 -- will also reveal ammo if it was hidden
function SWEP:UpdateAmmo(reason, remainingPaper)
    if not remainingPaper then remainingPaper = self:GetRemainingPaper() end
    self:SetClip1(remainingPaper)

    dbg.Log("Updating ammo ("..reason.."): "..remainingPaper)

    if self:GetMaxClip1() == -1 then
        dbg.Log(" => Revealing clip size")
        self.Primary.ClipSize = 100
        self:SetNW2Bool("ClipRevealed", true)
    end
end

function SWEP:Reload()
    local curTime = CurTime()
    if self._LastReload and curTime < self._LastReload + 1 then return end
    self._LastReload = curTime

    if not self:HasGift() and self:GetMaxClip1() == -1 then
        self:UpdateAmmo("dry reload")
    end

    local owner = self:GetOwner()

    if self:OwnedByWrapper(owner) and not self:GetIsOpening() and not self:GetIsRandomGift() then
        local curPaper = self:GetRemainingPaper()
        local paperOnUndo, paperCost = self:GetPaperOnUndo()

        if SERVER then
            if paperOnUndo > 0 then
                self:DropContents(true)
                self:SetRemainingPaper(paperOnUndo)

            else
                owner:ChatPrint("There wouldn't be any paper left on the roll (costs "..(paperCost)..").")
                owner:EmitSound("weapons/pistol/pistol_empty.wav", 50, math.random(90, 105))
            end
        end

        self:UpdateAmmo("discard attempt", paperOnUndo > 0 and paperOnUndo or curPaper)
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
            giftEnt = giftData:Spawn(gifteePly, giftObj)
        end

        if IsValid(giftEnt) then
            if not spawnPos then -- raycast to spawn in front of giftee
                local tr = utils.GetEyeTrace(gifteePly)
                dbg.Log("GiftWrap DropContent hit:", tr.HitEnt, tr.HitPos)

                local hitPos = tr.HitPos
                if gifteePly:EyePos():Distance(hitPos) > 80 then --clamp
                    local scaleFactor = (giftData:GetSize(giftObj)-3 or 0) * 12
                    hitPos = gifteePly:EyePos() + gifteePly:GetAimVector() * (80 + scaleFactor)
                end

                local extent = 20 -- safe default
                if giftData.category ~= GiftCategory.Ragdoll then
                    -- Maximum extent along the hit normal (how far it sticks out in that direction)
                    local mins, maxs = giftEnt:OBBMins(), giftEnt:OBBMaxs()
                    extent = math.max(mins:Dot(tr.HitNormal * -1),
                                      maxs:Dot(tr.HitNormal * -1))
                end

                spawnPos = hitPos + tr.HitNormal * extent
            end

            -- Plop back into world
            local doStabilize = #giftEnt:GetChildren() > 0 or giftData.category == GiftCategory.Vehicle or giftData.stabilize
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
                if ply ~= gifteePly then
                    if ply ~= wrapper then
                        table.insert(uninvolvedPlayers, ply)
                    end

                    if ply:GetPos():Distance(gifteePly:GetPos()) <= 300 then
                        table.insert(nearbyPlayers, ply)
                    end
                end
            end

            local intendedGiftee = giftObj:GetGiftee()
            local rightText = (isUndo and "." or "!")

            if not isUndo and IsValid(intendedGiftee) and gifteePly != intendedGiftee
              and utils.ConfirmedDead(gifteePly, intendedGiftee) then
                rightText = " meant for "..intendedGiftee:Nick().." (RIP)"..rightText
            end

            net.Start(GIFTWRAP_HL_CHAT_MSG)
            net.WriteString(isUndo and "You discarded the wrap containing " or "You unwrapped ")
            net.WriteString(giftData:GetDesc(giftObj, gifteePly))
            net.WriteString(rightText)
            net.Send(gifteePly)

            if not isUndo then
                net.Start(GIFTWRAP_HL_CHAT_MSG)
                net.WriteString("Someone nearby unwrapped ")
                net.WriteString(giftData:GetDesc(giftObj, gifteePly, true))
                net.WriteString(rightText)
                net.Send(nearbyPlayers)

                local unwrapNote = giftObj:GetUnwrapNote()
                dbg.Log("Unwrap note: '"..unwrapNote.."'")

                if unwrapNote and unwrapNote != "" then
                    timer.Simple(1, function()
                        net.Start(GIFTWRAP_HL_CHAT_MSG)
                        net.WriteString("A note was attached: \"")
                        net.WriteString(unwrapNote)
                        net.WriteString("\"")
                        net.Send(table.Add({gifteePly}, nearbyPlayers))
                    end)
                end

                if isRandomGift then
                    if giftData.factor_rarity and giftData.factor_rarity >= 5 then
                        LANG.Msg(uninvolvedPlayers, "gift_unwrap_notif_rare", nil, MSG_MSTACK_WARN)
                    else
                        LANG.Msg(uninvolvedPlayers, "gift_unwrap_notif_random", nil, MSG_MSTACK_PLAIN)
                    end
                end
            end

        else
            net.Start(GIFTWRAP_HL_CHAT_MSG)
            net.WriteString("You were meant to unwrap ")
            net.WriteString(giftData:GetDesc(giftObj, gifteePly) .. " (" .. giftData:GetName(giftObj, gifteePly) ..")")
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
                        if IsValid(sndOrigin) then
                            sndOrigin:EmitSound(sounds["flourish_yippie"], 75, 100, 0.6)
                        end
                    end)
                end
            end

            local openSnd = CreateSound(sndOrigin, sounds[dropSnd])
            openSnd:PlayEx(dropVol, dropPitch)

            if sndOrigin == giftEnt then
                for _, child in ipairs(giftEnt:GetChildren()) do
                    if child:IsPlayer() then
                        net.Start(CLIENT_FLOURISH_MSG)
                        net.WriteString(dropSnd)
                        net.Send(child)
                    end
                end
            end
        end

        -- Particle effect
        local effectData = EffectData()
        effectData:SetOrigin(spawnPos)
        effectData:SetMagnitude(10)
        effectData:SetScale(0.01)
        effectData:SetRadius(50)
        util.Effect("Sparks", effectData)
    end

    -- for use on either type of gift
    function EmptyGift(giftEnt)
        giftEnt:SetWrapperSID("")
        giftEnt:SetStoredGift(nil)
        giftEnt:SetCachedDataLabel("")

        if giftEnt:GetNW2Bool("GWStinky") then
            if giftEnt:IsWeapon() then
                timer.Simple(0, function()
                    local owner = giftEnt:GetOwner()

                    if IsValid(owner) then
                        owner:StopParticles()
                    end
                end)
            else
                giftEnt:StopParticles()
            end

            giftEnt:SetNW2Bool("GWStinky", false)
            giftEnt:StopLoopingSound(giftEnt.StinkSoundID)
            --giftEnt:StopLoopingSound(giftEnt.StinkSoundID2)
        end

        if giftEnt:IsWeapon() then
            giftEnt:UpdateModel("dropped gift")
        else
            giftEnt:BecomeBackWrap()
        end
    end

    function SWEP:DropContents(isUndo)
        local owner = self:GetOwner()

        if IsValid(owner) and self:HasGift() and not self._PreserveGift then
            SpawnGiftEnt(owner, self, nil, isUndo)

            dbg.Log("Dropped gift contents")
            EmptyGift(self)
            self:Extinguish()
        end
    end

    function SWEP:MakePropCopy(notRetrievable)
        if not self:HasGift(storedGift) then return nil end
        local giftProp = ents.Create(PROP_CLASS_NAME)

        utils.TransferNetVars(self, giftProp)
        giftProp:SetNotRetrievable(notRetrievable)

        return giftProp
    end

    function SWEP:Wrap(ent)
        dbg.Log("Wrap attempt on:", ent)
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

         -- check one layer up the parenting chain (useful for vehicles)
        local moveParent = ent:GetMoveParent()
        if IsValid(moveParent) and not ent:IsWeapon() then ent = moveParent end

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
                local wrappedBy = ent:GetNW2Entity("WrappedByGift")

                if IsValid(wrappedBy) then
                    EmptyGift(wrappedBy)
                    local owner = wrappedBy:GetOwner()

                    if IsValid(owner) then
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
        self:SetClip1(-1)
        self:SetNW2Bool("ClipRevealed", false)

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

    function SWEP:DoDrawCrosshair(xCenter, yCenter, shouldDraw)
        self.BaseClass.DoDrawCrosshair(self, xCenter, yCenter, shouldDraw and not self:HasGift())
    end

    hook.Add("Think", HOOK_RESET_VM_COLORS, function()
        local ply = LocalPlayer()
        if not utils.IsLivingPlayer(ply) then return end
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

                if not self:GetIsRandomGift() and self:GetPaperOnUndo() > 0 then
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
        local formBalance = vgui.CreateTTT2Form(parent, "label_giftwrap_balance_form")
        local stinkToggle = formBalance:MakeCheckBox({
            serverConvar = "ttt2_giftwrap_corpse_stink_enable",
            label = "label_giftwrap_corpse_stink_enable"
        })
        formBalance:MakeSlider({
            serverConvar = "ttt2_giftwrap_corpse_stink_delay",
            label = "label_giftwrap_corpse_stink_delay",
            min = 0, max = 120, decimal = 0, master = stinkToggle
        })

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

        GiftWrapThirdPartySettings(parent)

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