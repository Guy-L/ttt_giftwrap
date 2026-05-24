include("sh_physics_utils.lua")
local utils = GW_Utils
local dbg   = GW_DBG

local INIT_FIXES_HOOK            = "GiftWrap_InitThirdPartyChanges"
local CLUTTERBOMB_LIGHT_FIX_HOOK = "GiftWrap_ClutterbombLightFix"
local ENT_KILL_INPUT_HOOK        = "GiftWrapSV_PreventWrappedEntKillInputs"
local ENT_TAKE_DAMAGE_HOOK       = "GiftWrapSV_VehicleOccupantsDamageFix"
local PLAYER_USE_HOOK            = "GiftWrapSV_InternalVehicleSeatFix"

local VDFIX_MULT_DRIVER = utils.Cvar("ttt2_vehicle_damagefix_driver_mult",    30, 0, 100, "Damage multiplier for driver when hitting other parts of vehicle (%).")
local VDFIX_MULT_PASNGR = utils.Cvar("ttt2_vehicle_damagefix_passenger_mult", 20, 0, 100, "Damage multiplier for passengers when hitting any part of vehicle (%).")

local ChangeCategory = {
    SWEP      = "Scripted Weapon",
    SENT      = "Scripted Entity",
    Item      = "Passive Item",
    Metatable = "Global Namespace",
    Meta      = "Engine Meta",
    None      = nil,
}

local ChangeRealm = {
    CLIENT      = {name = "Client", val = CLIENT},
    SERVER      = {name = "Server", val = SERVER},
    SHARED      = {name = "Shared", val = true},
}

if not GW_InitChangesCache then
    GW_InitChangesCache = {}
end

-- Util methods for gifts that can be remotely detonated while wrapped
local function RemoteGiftDetonation(ent, fuse, sound, funcs)
    if ent._isSelfDestructing then return end
    ent._isSelfDestructing = true

    dbg.Log("Starting remote detonation for", ent)
    local parentGift, wrapLevel = utils.GetTopmostWrap(ent)

    if IsValid(parentGift) then
        local giftee = parentGift:GetOwner()

        if IsValid(giftee) then
            giftee:EmitSound(sound.path, sound.vol, sound.pitch)
            giftee:ChatPrint("Your gift is beeping!")
        else
            parentGift:EmitSound(sound.path, sound.vol, sound.pitch)
        end

        for _, ply in ipairs(player.GetAll()) do
            if ply ~= giftee then
                if ply:GetPos():Distance(parentGift:GetPos()) <= 300 then
                    ply:ChatPrint("A nearby gift is beeping!")
                end
            end
        end

        timer.Simple(fuse, function()
            if not IsValid(ent) then return end

            local newWrapLevel
            parentGift, newWrapLevel = utils.GetTopmostWrap(ent)

            if IsValid(parentGift) then
                if newWrapLevel > wrapLevel then
                    ent._isSelfDestructing = false
                    funcs.parry(ent)

                else
                    parentGift._PreventThrow = true
                    funcs.explosion(parentGift)
                    parentGift:Remove()
                end
            else
                funcs.explosion(ent)
                ent:Remove()
            end
        end)

    else
        funcs.ogDetonate(ent)
    end
end

-- Parry mechanic for detonatable entities wrapped mid-explosion
local function RemoteGiftExplosion(ent, ogExplode, parryFunc)
    dbg.Log("Confirming explosion for", ent)

    if IsValid(ent:GetNWEntity("WrappedByGift")) then
        ent._isSelfDestructing = false
        parryFunc(ent)
    else
        ogExplode(ent)
    end
end

-- Catch-all hook to prevent kill events on wrapped entities (used by Fireballs & others)
hook.Add("AcceptInput", ENT_KILL_INPUT_HOOK, function(ent, input, activator, caller, value)
    if input == "kill" and IsValid(ent) and IsValid(ent:GetNWEntity("WrappedByGift")) then
        dbg.Log("Prevented kill input for wrapped entity", ent)
        return true
    end
end)



local initChanges = {
    --[[
    {   addon = "Addon Name",
        desc = "Template change", realm = ChangeRealm.SHARED,
        identifier = "identifier", category = ChangeCategory.SENT,
        original_keys = {},
        apply = function(sent, og)
        end
    },]]

    {   name = "fix_extra_seat_entry",
        addon = "TTT2 (Base)", icon = "vgui/ttt/icon_halp",
        desc = "Fix seats inside of vehicles being inaccessible even if main seat occupied", realm = ChangeRealm.SERVER,
        identifier = "fix_extra_seat_entry", category = ChangeCategory.None,
        apply = function()

            hook.Add("PlayerUse", PLAYER_USE_HOOK, function(ply, ent)
                if IsValid(ent) and ent:IsVehicle() and IsValid(ent:GetDriver()) then
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
        end
    },

    {   name = "fix_vehicle_damage",
        addon = "TTT2 (Base)", icon = "vgui/ttt/icon_halp",
        desc = "Fix driver taking almost no damage & other riders being invincible", realm = ChangeRealm.SERVER,
        identifier = "fix_vehicle_damage", category = ChangeCategory.None,
        cvars = {VDFIX_MULT_DRIVER, VDFIX_MULT_PASNGR},
        apply = function()

            hook.Add("EntityTakeDamage", ENT_TAKE_DAMAGE_HOOK, function(target, dmgInfo)
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
        end
    },

    {   name = "pog_default_det",
        addon = "Pot of Greed", icon = "vgui/ttt/icon_weapon_ttt_potofgreedier",
        desc = "Fix for Pot of Greedier not defaulting to Detective shop for non-shopping role pots", realm = ChangeRealm.SHARED,
        identifier = "PotOfGreedier", category = ChangeCategory.Metatable,
        original_keys = {"GetEquipmentServerSided"},
        apply = function(meta, og)

            meta.GetEquipmentServerSided = function(ply, subRole, noModification)
                local subRoleData = utils.GetSubRoleData(subRole)

                if not subRoleData or not subRoleData:IsShoppingRole() then
                    return og.GetEquipmentServerSided(ply, ROLE_DETECTIVE, noModification)
                else
                    return og.GetEquipmentServerSided(ply, subRole, noModification)
                end
            end
        end
    },

    {   name = "manhack_disable_wrapped",
        addon = "Controllable Manhack", icon = "controllable_manhack/manhack",
        desc = "Disable right click while it's in a Gift Wrap giftbox", realm = ChangeRealm.SERVER,
        identifier = "weapon_controllable_manhack", category = ChangeCategory.SWEP,
        original_keys = {"SecondaryAttack"},
        apply = function(swep, og)

            swep.SecondaryAttack = function(slf)
                local manhack = slf:GetSpawnedManhack()

                if IsValid(manhack) then
                    if not IsValid(manhack:GetNWEntity("WrappedByGift")) then
                        og.SecondaryAttack(slf)
                    else
                        utils.NonSpamMessage(slf:GetOwner(), "wrapped_manhack", "Sorry, your manhack is wrapped inside a giftbox.")
                    end
                end
            end
        end
    },

    {   name = "manhack_explode_wrap",
        addon = "Controllable Manhack", icon = "controllable_manhack/manhack",
        desc = "Explode giftbox when self-destructing + wrap to parry", realm = ChangeRealm.SERVER,
        identifier = "sent_controllable_manhack", category = ChangeCategory.SENT,
        original_keys = {"SelfDestruct", "Explode"},
        apply = function(sent, og)

            local function manhackParry(self)
                local owner = self:GetPlayerController()
                if not IsValid(owner) then owner = self.damageInfoPlayer end

                owner:ChatPrint("Detonation was parried by Gift Wrap!")
                self:SetPlayerController(owner)
                self:SetHealth(ControllableManhack.ConVarHealth())
                self.isSelfDestructing = false
            end

            sent.SelfDestruct = function(self)
                RemoteGiftDetonation(self, 3, {path = self.SoundStunned}, {
                    explosion = function(parentEnt)
                        local explode = ents.Create("env_explosion")
                        explode:SetPos(utils.GetEntCenter(parentEnt))
                        explode:SetOwner(self:GetPlayerController())
                        explode:Spawn()
                        explode:SetKeyValue("iMagnitude", self.ExplosionSize)
                        explode:Fire("Explode", 0, 0)
                    end,

                    ogDetonate = og.SelfDestruct,
                    parry = manhackParry,
                })
            end

            sent.Explode = function(self)
                RemoteGiftExplosion(self, og.Explode, manhackParry)
            end
        end
    },

    {   name = "slam_explode_wrap",
        addon = "M4 SLAM", icon = "vgui/ttt/icon_slam",
        desc = "Explode giftbox when self-destructing + wrap to parry", realm = ChangeRealm.SHARED,
        identifier = "ttt_slam_base", category = ChangeCategory.SENT,
        original_keys = {"StartExplode", "Explode"},
        apply = function(sent, og)

            local function slamParry(self)
                self:GetPlacer():ChatPrint("Detonation was parried by Gift Wrap!")
            end

            sent.StartExplode = function(self)
                RemoteGiftDetonation(self, 1.5, {path = self.PreExplosionSound}, {
                    explosion = function(parentEnt)
                        local pos = parentEnt:GetPos()
                        local radius = self.BlastRadius
                        local damage = self.BlastDamage

                        local effect = EffectData()
                        effect:SetStart(pos)
                        effect:SetOrigin(pos)
                        effect:SetScale(radius)
                        effect:SetRadius(radius)
                        effect:SetMagnitude(damage)
                        util.Effect("Explosion", effect, true, true)
                        util.BlastDamage(parentEnt, self:GetPlacer(), pos, radius, damage)
                        parentEnt:EmitSound(self.ExplosionSound, 60, math.random(125, 150))
                    end,

                    ogDetonate = og.StartExplode,
                    parry = slamParry,
                })

            end

            sent.Explode = function(self)
                RemoteGiftExplosion(self, og.Explode, slamParry)
            end
        end
    },

    {   name = "paper_plane_gift_targetting",
        addon = "Paper Plane", icon = "vgui/ttt/paper_plane_icon",
        desc = "Override targetting behavior for random gift planes", realm = ChangeRealm.SHARED,
        identifier = "ttt_paper_plane_proj", category = ChangeCategory.SENT,
        original_keys = {"GetClosestPlayer"},
        apply = function(sent, og)

            sent.GetClosestPlayer = function(self, ent, plys)
                local spawner = self:GetNWEntity("GW_Spawner")

                if IsValid(spawner) then
                    local sphere = ents.FindInSphere(self:GetPos(), 5000)
                    local possibleTargets = {}

                    for key, v in pairs(sphere) do
                        if v:IsPlayer() and v:Alive() and not v:IsSpec() and v ~= spawner then
                            table.insert(possibleTargets, v)
                        end
                    end

                    return og.GetClosestPlayer(self, ent, possibleTargets)
                else
                    return og.GetClosestPlayer(self, ent, plys)
                end
            end
        end
    },

    {   name = "star_burster_ammo_fix",
        addon = "Star Burster", icon = "vgui/ttt/ttt_plasma_icon.png",
        desc = "Fix clipsize discrepancy & related Lua error when spawning as worldmodel", realm = ChangeRealm.CLIENT,
        identifier = "ttt_plasma_burster_nade", category = ChangeCategory.SWEP,
        original_keys = {"Initialize"},
        apply = function(swep, og)

            swep.Initialize = function(self)
                local defaultClip = GetConVar("ttt_plasmaburster_ammo"):GetFloat()
                self.Primary.ClipSize = defaultClip
                self:SetClip1(defaultClip)
                og.Initialize(self)
            end
        end
    },

    {   name = "star_burster_wrap_fix",
        addon = "Star Burster", icon = "vgui/ttt/ttt_plasma_icon.png",
        desc = "Make Star Burster entity wrappable", realm = ChangeRealm.SHARED,
        identifier = "plasma_burster_nade", category = ChangeCategory.SENT,
        original_keys = {"Initialize"},
        apply = function(sent, og)

            sent.Initialize = function(self)
                og.Initialize(self)

                -- need to do this for collisions to work, surprisingly the box size doesn't change anything
                self:SetCollisionBounds(Vector(-1, -1, -1), Vector(1, 1, 1))
            end
        end
    },

    {   name = "minecraft_arrow_wrap_fix",
        addon = "Minecraft Bow", icon = "vgui/ttt/icon_minecraft_bow.png",
        desc = "Make Minecraft arrow entity wrappable", realm = ChangeRealm.SHARED,
        identifier = "ttt_minecraft_arrow", category = ChangeCategory.SENT,
        original_keys = {"Think"},
        apply = function(sent, og)

            sent.Think = function(self)
                og.Think(self)

                if self.Disabled and not self:IsSolid() then
                    self:SetMoveType(MOVETYPE_VPHYSICS)
                    self:SetNotSolid(false)
                    self:SetColor(Color(180, 180, 180))
                end
            end
        end
    },

    {   name = "isvalid_condition",
        addon = "Garry's Mod", icon = "vgui/titlebaricon",
        desc = "Allow marking arbitrary entities as not valid (used by Lethal Mine & Force Shield wraps)", realm = ChangeRealm.SHARED,
        identifier = "Entity", category = ChangeCategory.Meta,
        original_keys = {"IsValid"},
        apply = function(meta, og)

            meta.IsValid = function(self)
                if self._Invalid then return false end
                return og.IsValid(self)
            end
        end
    },

--[[ -- seems unneeded due to above change? (mine can be set off more than once without issue)
    {   addon = "Lethal Mine",
        desc = "Prevent Lethal Mines exploding in giftbox", realm = ChangeRealm.SHARED,
        identifier = "item_lethal_company_landmine", category = ChangeCategory.SENT,
        original_keys = {"EndTouch"},
        apply = function(sent, og)

            sent.EndTouch = function(self, ent)
                if IsValid(self:GetNWEntity("WrappedByGift")) then return end
                og.EndTouch(self, ent)
            end
        end
    },]]

    {   name = "hwapoon_wrap_fix",
        addon = "Hwapoon", icon = "vgui/ttt/tttharpoonicon.png",
        desc = "Make Hwapoon arrows wrappable & prevent them from disappearing", realm = ChangeRealm.SERVER,
        identifier = "hwapoon_arrow", category = ChangeCategory.SENT,
        original_keys = {"PhysicsCollide"},
        apply = function(sent, og)

            sent.PhysicsCollide = function(self, data, physObj)
                og.PhysicsCollide(self, data, physObj)

                if self:GetSolid() == SOLID_NONE then
                    self:SetSolid(SOLID_VPHYSICS)
                end
            end

            sent.AcceptInput = function(self, inputName, activator, caller, param)
                if inputName == "kill" then
                    return true
                end
            end
        end
    },

    {   name = "ice_grenade_wrap_fix",
        addon = "Ice Grenade", icon = "vgui/ttt/icon_64_icegrenade.png",
        desc = "Allow ice grenade explosion to be interrupted by wrap", realm = ChangeRealm.SERVER,
        identifier = "icegrenade_proj", category = ChangeCategory.SENT,
        apply = function(sent)

            sent.iceexplode = function(self, delay)
                timer.Create(self:EntIndex().."_timer", delay or 1.8, 1, function()
                    if IsValid(self) then
                        ParticleEffect("ice_explosion", self:GetPos(), Angle(0, 0, 0))
                        self:EmitSound("ice_explosion.wav", 85, 90, 1, CHAN_AUTO)
                        self:FreezeAll()
                        self:Remove()
                    end
                end)
            end
        end
    },

    {   name = "bunger_grenade_wrap_fix",
        addon = "Killer Bungers", icon = "vgui/ttt/bungericon.png",
        desc = "Make Bunger Grenade collision box match scale", realm = ChangeRealm.SHARED,
        identifier = "ttt_bungernade_proj", category = ChangeCategory.SENT,
        original_keys = {"Initialize", "Explode"},
        apply = function(sent, og)

            sent.Initialize = function(self)
                self.Entity:SetModelScale(2, 0)
                og.Initialize(self)

                self:SetSolid(SOLID_VPHYSICS)
                self:SetMoveType(MOVETYPE_VPHYSICS)
                self:PhysicsInit(SOLID_VPHYSICS)
                self.Entity:Activate()
            end

            -- this functions code is really fucking stupid (it RELIES on a client/server mismatch over the scale)
            sent.Explode = function(self, tr)
                self.Entity:SetModelScale(2, 0)
                og.Explode(self, tr)
            end
        end
    },

    {   name = "bunger_pet_dmg",
        addon = "Killer Bungers", icon = "vgui/ttt/bungericon.png",
        desc = "Extend Killer Bungers damage method to conditionally disable damage (pet bunger)", realm = ChangeRealm.SERVER,
        identifier = "weapon_ttt_bungernade", category = ChangeCategory.SWEP,
        apply = function()

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
    },

    {   name = "fortnite_font_fix",
        addon = "Fortnite Building", icon = "vgui/ttt_fortnite_icon.png",
        desc = "Ensure clients can render the custom font for structures even without SWEP init", realm = ChangeRealm.CLIENT,
        identifier = "weapon_ttt_fortnite_building", category = ChangeCategory.SWEP,
        apply = function()

            -- What the original addon does on SWEP init; gives a warning but works out?
            -- (CreateFont *should* only be ran once but outside debugging, it will be, so it's fine)
            surface.CreateFont("Fortnite_Structure_Font", {font = "Trebuchet24", size = 18, weight = 750})
            surface.CreateFont("Fortnite_HUD_Font", {font = "Trebuchet24", size = 20, weight = 1250})
        end
    },

    {   name = "prop_exploder_wrap_fix",
        addon = "Prop Exploder", icon = "vgui/ttt/icon_propexploder",
        desc = "Explode giftbox when self-destructing + wrap to parry + rigging giftboxes", realm = ChangeRealm.SERVER,
        identifier = "weapon_ttt_propexploder", category = ChangeCategory.SWEP,
        original_keys = {"SecondaryAttack"},
        apply = function(swep, og)

            -- this function may look overly complex, but given all the ways a rigged prop can interact with giftwrap
            -- (and the ways a rigged giftbox can be interacted with), it's actually just as complex as it needs to be

            local function OGPropExploderExplosion(ent, owner)
                local expl = ents.Create("env_explosion")
                expl:SetPos(ent:GetPos())
                expl:Spawn()
                expl:SetOwner(owner)
                expl:SetKeyValue("iMagnitude", "0")
                expl:Fire("Explode", 0, 0)
                expl:EmitSound("siege/big_explosion.wav", 400, 200)
                util.BlastDamage(ent, owner, ent:GetPos(), 400, 200)
            end

            swep.SecondaryAttack = function(self)
                RemoteGiftDetonation(self.Owner.PEProp, 1.2, {path = "weapons/gamefreak/wtf.mp3", vol = 400, pitch = 200}, {
                    explosion = function(parentEnt)
                        self:SendPEMessage("Exploded")
                        self.Owner.PEProp = nil

                        OGPropExploderExplosion(parentEnt, self.Owner)
                        self:Remove()
                    end,

                    ogDetonate = function(ent)
                        if IsValid(ent) then
                            og.SecondaryAttack(self)

                            if ent:IsWeapon() then -- should only be possible for giftboxes
                                local entOwner = ent:GetOwner()
                                entOwner:EmitSound("weapons/gamefreak/wtf.mp3", 400, 200)
                                entOwner:ChatPrint("Your gift is exploding!")
                            end

                            local exploTimerName = "PEPlanting" .. ent:EntIndex()
                            local owner = self.Owner

                            timer.Simple(timer.TimeLeft(exploTimerName), function()
                                if not IsValid(owner) then return end

                                -- if the prop was a giftbox, it could've switched state & thus not be the same entity (PEProp is transferred though)
                                if owner.PEProp ~= ent then ent = owner.PEProp end
                                owner.PEProp = nil

                                if IsValid(ent) then
                                    if IsValid(ent:GetNWEntity("WrappedByGift")) then
                                        owner:ChatPrint("Detonation was parried by Gift Wrap!")

                                    else
                                        ent._PreventThrow = true -- in case its a giftbox
                                        OGPropExploderExplosion(ent, owner)
                                        ent:Remove()
                                    end
                                end
                            end)

                            timer.Remove(exploTimerName)
                        else
                            utils.NonSpamMessage(self.Owner, "PropExploderDet", "No prop selected!")
                        end
                    end,

                    parry = function()
                        self.Owner:ChatPrint("Detonation was parried by Gift Wrap!")
                    end,
                })
            end
        end
    },
}

-- Add similar fixes for COD perk bottles
local perkItems = {
    doubletap = "Doubletap Root Beer",
    juggernog = "Juggernog",
    phd = "PHD Flopper",
    speedcola = "Speed Cola",
    staminup = "Stamin-Up",
}

for itemID, itemName in pairs(perkItems) do
    table.insert(initChanges, {
        name = itemID.."_wrap_fix",
        addon = itemName, icon = "vgui/ttt/ic_"..itemID,
        desc = "Prevent effects happening when buying for gift", realm = ChangeRealm.SERVER,
        identifier = "item_ttt_"..itemID, category = ChangeCategory.Item,
        original_keys = {"Bought"},
        apply = function(item, og)

            item.Bought = function(self, ply)
                if not ply._gwInOptMenu then
                    og.Bought(self, ply)
                end
            end
        end
    })
end

-- Add cvars for toggling each change
for _, change in ipairs(initChanges) do
    utils.Cvar("ttt2_giftwrap_tweak_"..change.name, 1, 0, 1, "[Tweak for "..change.addon.."] "..change.desc)
end


--------------------------------
--------------------------------
-- Apply all third-party changes
local function GetBaseMeta(change)
    if change.category == ChangeCategory.SENT then
        local baseMeta = scripted_ents.GetStored(change.identifier)
        return baseMeta and baseMeta.t or nil

    elseif change.category == ChangeCategory.SWEP then
        return weapons.GetStored(change.identifier)

    elseif change.category == ChangeCategory.Item then
        return items.GetStored(change.identifier)

    elseif change.category == ChangeCategory.None then
        return true

    elseif change.category == ChangeCategory.Meta then
        return FindMetaTable(change.identifier)

    elseif change.category == ChangeCategory.Metatable then
        return _G[change.identifier]
    end
end

hook.Add("Initialize", INIT_FIXES_HOOK, function()
    if SERVER and not dbg.Cvar:GetBool() then
        print("[Notice] Gift Wrap is applying "..#initChanges.." changes to make third party addons work better with itself.")
        print("         To see a full list of changes instead of this notice, turn on the ttt2_giftwrap_debug cvar.")
        print("         You can also toggle them in Gift Wrap's settings menu if necessary.")
    end

    for i, change in ipairs(initChanges) do
        if change.realm.val and GetConVar("ttt2_giftwrap_tweak_"..change.name):GetBool() then
            local baseMeta = GetBaseMeta(change)

            if baseMeta then
                dbg.Log("[Change #" .. i .. "] " ..change.addon.. ": " .. change.desc)

                if change.category then
                    -- store original functions of addon overriden by Gift Wrap
                    -- for idempotency when debugging changes
                    if change.original_keys and not GW_InitChangesCache[change.identifier] then
                        GW_InitChangesCache[change.identifier] = {}

                        for _, key in ipairs(change.original_keys) do
                            GW_InitChangesCache[change.identifier][key] = baseMeta[key]
                        end
                    end

                    change.apply(baseMeta, GW_InitChangesCache[change.identifier])
                else
                    change.apply()
                end
            end
        end
    end

    print("Loaded all " ..#initChanges.. " third-party adjustments.")
end)

-- List changes in addon's settings menu
function GiftWrapThirdPartySettings(parent)
    local form = vgui.CreateTTT2Form(parent, "label_giftwrap_tweaks_form")

    form:MakeHelp({
        label = "label_giftwrap_tweaks_desc"
    })

    local boxTall = 48
    local boxPad = 3
    local checkBoxTall = 32
    local cvarTall = 24
    local materialReset = Material("vgui/ttt/vskin/icon_reset")

    for _, change in ipairs(initChanges) do
        if GetBaseMeta(change) then
            local changeBox = vgui.Create("DPanel", form)
            changeBox:Dock(TOP)
            changeBox:DockMargin(10, 5, 10, 2)
            changeBox:DockPadding(boxPad, boxPad, boxPad, 0)
            changeBox:SetTall(boxTall + (change.cvars and (cvarTall*1.1) * #change.cvars or 0))

            changeBox.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, util.GetChangedColor(vskin.GetBackgroundColor(), 20))
            end

            local iconSize = boxTall - boxPad
            local iconWrap = vgui.Create("DPanel", changeBox)
            iconWrap:Dock(LEFT)
            iconWrap:DockMargin(8, 0, 0, 0)
            iconWrap:DockPadding(0, 0, 0, 0)
            iconWrap:SetWide(iconSize)
            iconWrap.Paint = nil
            --dbg.HighlightUI(iconWrap)

            local icon = vgui.Create("DImage", iconWrap)
            icon:SetSize(iconSize, iconSize)
            icon:SetImage(change.icon or "vgui/ttt/menu/icon_question")
            if change.cvars then
                icon:SetPos(0, (changeBox:GetTall() - iconSize) * 0.5)
            end

            local content = vgui.Create("DPanel", changeBox)
            content:Dock(FILL)
            content:DockMargin(8, 0, 1, boxPad)
            content.Paint = nil

            local titleRow = vgui.Create("DPanel", content)
            titleRow:Dock(TOP)
            titleRow:SetTall(16)
            titleRow:DockMargin(0, 0, 0, 2)
            titleRow.Paint = nil

            local addonName = vgui.Create("DLabel", titleRow)
            addonName:Dock(LEFT)
            addonName:SetText(change.addon)
            addonName:SetFont("DermaDefaultBold")
            addonName:SetTextColor(Color(180, 180, 180))
            addonName:SizeToContents()

            local info = ""
            if change.category then
                info = info.." • "..change.category
            end
            info = info.." • "..change.realm.name

            local rightText = vgui.Create("DLabel", titleRow)
            rightText:Dock(LEFT)
            rightText:SetText(info)
            rightText:SetFont("DermaDefault")
            rightText:SetTextColor(Color(120, 120, 120))
            rightText:SizeToContents()
            rightText:SetPos(addonName:GetWide() + 6, 0)

            local toggleRow = vgui.Create("DPanel", content)
            toggleRow:Dock(TOP)
            toggleRow.Paint = nil

            local toggle = vgui.Create("DCheckBoxLabelTTT2", toggleRow)
            toggle:Dock(FILL)
            toggle.roundedCorner = true

            local toggleReset = vgui.Create("DButtonTTT2", toggleRow)
            toggleReset:SetText("button_default")
            toggleReset:SetWide(boxTall - boxPad - 18)
            toggleReset.Paint = function(slf, w, h)
                derma.SkinHook("Paint", "FormButtonIconTTT2", slf, w-3, h)
                return true
            end
            toggleReset.iconMaterial = materialReset
            toggleReset.roundedCorner = true
            toggleReset:Dock(RIGHT)

            toggle:SetResetButton(toggleReset)
            toggle:SetServerConVar("ttt2_giftwrap_tweak_"..change.name)
            toggle:SetText(change.desc)

            if change.cvars then
                local controls = {}

                for _, cv in ipairs(change.cvars) do
                    local cvBox = vgui.Create("DPanel", content)
                    cvBox:Dock(TOP)
                    cvBox:DockMargin(0, 2, 3, 0)
                    cvBox.Paint = nil

                    local left = vgui.Create("DLabelTTT2", cvBox)
                    left:SetText(cv:GetHelpText())
                    left.Paint = function(slf, w, h)
                        derma.SkinHook("Paint", "FormLabelTTT2", slf, w, h)
                        return true
                    end
                    left:Dock(LEFT)
                    left:SetWide(425)

                    local right = vgui.Create("DNumSliderTTT2", cvBox)
                    right:SetMinMax(cv:GetMin(), cv:GetMax())
                    right:SetDecimals(0)
                    right:Dock(FILL)
                    right:SetValue(cv:GetFloat())
                    right:SetServerConVar(cv:GetName())

                    local reset = vgui.Create("DButtonTTT2", cvBox)
                    reset:SetText("button_default")
                    reset:SetWide(cvarTall)
                    reset.Paint = function(slf, w, h)
                        derma.SkinHook("Paint", "FormButtonIconTTT2", slf, w, h)
                        return true
                    end
                    reset.iconMaterial = materialReset
                    reset.roundedCorner = true
                    reset:Dock(RIGHT)
                    right:SetResetButton(reset)

                    local cvarEnabled = GetConVar("ttt2_giftwrap_tweak_"..change.name):GetBool()
                    right.Slider:SetEnabled(cvarEnabled)
                    reset:SetEnabled(cvarEnabled)
                    table.insert(controls, right.Slider)
                    table.insert(controls, reset)
                end

                local ogOnChange = toggle.OnChange
                toggle.OnChange = function(self, val)
                    ogOnChange(self, val)

                    for _, ctrl in ipairs(controls) do
                        ctrl:SetEnabled(val)
                    end
                end
            end
        end
    end
end

-- used when debugging only
--hook.GetTable()["Initialize"][INIT_FIXES_HOOK]()