local SNUFFLE_PRESENT_CLASS = "christmas_present"

local HOOK_GIFTWRAP_ENT_SPAWN   = "TTT_GiftWrap_EntSpawn"
local HOOK_GIFTWRAP_MARKER_UI   = "TTT_GiftWrap_MarkerVision"
local HOOK_GIFTWRAP_INTERACT_UI = "TTT_GiftWrap_MarkerVision"
local HOOK_ROUND_START_TIME     = "TTT_GiftWrap_RoundStartTime"
local TREE_FOUND_MSG            = "TTT_GiftWrap_TreeFoundMsg"

local dbg   = GW_DBG
local utils = GW_Utils

local ENABLE_RANDOM         = CreateConVar("ttt2_giftwrap_enable_random_gifts", "1",    GW_CVAR_FLAGS, "Whether to spawn random gifts when Snuffles' YoWaddup Fixes presents are found.", 0, 1)
local REPLACE_SNUFFLES_GIFT = CreateConVar("ttt2_giftwrap_replace_snuffles_gift", "1",  GW_CVAR_FLAGS, "Whether random gifts from Gift Wrap replace (rather than add to) naturally spawning gifts from Snuffles' YoWaddup General Fixes addon.", 0, 1)
local FULL_XMAS_CHIME_VOL   = CreateConVar("ttt2_giftwrap_all_served_chime_vol", "80", GW_CVAR_FLAGS, "Volume of the chime sound effect that plays from YoWaddup Christmas trees when as many gifts spawn as there are players at round start.", 0, 100)

ENT.Type = "anim"
ENT.PrintName = "Gift"
ENT.Information = "Gift from TTT2 Gift Wrap. Holds a random trinket!"
ENT.Purpose = "Gift from TTT2 Gift Wrap. Holds a random trinket!"
ENT.Category = "Utility"
ENT.Spawnable = true -- for sandbox ig
ENT.Author = "Guy"

local sounds = {
    bells1 = Sound("giftwrap/tf2_nm_bells1.wav"),
    bells2 = Sound("giftwrap/tf2_nm_bells2.wav"),
}

local normalDescriptionLines = {
    "Have you been a good terrorist this year?",
    "Hope you aren't on the naughty list.",
    "It's what you've always wanted!",
    "What could it be?",
    "Wonder what's inside...",
    "Merry Christmas!",
}

-- note: due to lazy design, this array must match the length of the above one
local selfDescriptionLines = {
    "Let's hope they like it!",
    "Do you think they'll like it?",
    "You can't open it, but maybe someone else will.",
    "You can't open it, but hopefully someone else will!",
    "Can be opened by any other terrorist.",
    "Can be opened by anyone else.",
}

function ENT:Initialize()
    dbg.Log("(prop) Initializing gift entity")

    self:SetModel(GIFT_WORLDMODEL)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)

    self:SetCollisionGroup(COLLISION_GROUP_WEAPON) --prevent player collision while thrown
    timer.Simple(1, function()
        if IsValid(self) then
            self:SetCollisionGroup(COLLISION_GROUP_NONE)
        end
    end)

    if SERVER then
        self:PrecacheGibs()

        local scale = math.Rand(0.8 , 3.5)
        self:SetAngles(Angle(90, math.random(0, 360), 0))
        self.LastUprightCheck = CurTime()
        self.UprightCheckFreq = 2
        self:SetGiftScale(scale)
        self:UpdateScale(scale)
        self:SetDescriptionLine(math.random(#normalDescriptionLines))

    elseif CLIENT then
        self:UpdateScale(self:GetGiftScale())
    end
end

function ENT:OnTakeDamage(dmgInfo)
    self:TakePhysicsDamage(dmgInfo)

    if SERVER then
        local attacker = dmgInfo:GetAttacker()
        local attackerOpenedRandomGift = attacker:GetNWBool("OpenedRandomGift")
        local inflictor = dmgInfo:GetInflictor()

        if utils.IsLivingPlayer(attacker) and inflictor
          and (inflictor:GetClass() == "weapon_zm_improvised" or inflictor:GetClass() == "weapon_ttt_inf_fists") then
            if attacker:SteamID64() == self:GetWrapperSID() then
                utils.NonSpamMessage(attacker, "OpenAttempt", "You can't open your own gift.")

            elseif attackerOpenedRandomGift and self:GetIsRandomGift() and not dbg.Cvar:GetBool() then
                utils.NonSpamMessage(attacker, "OpenAttempt", ERROR_ALREADY_OPENED)

            else
                -- TODO: Proper gibbing?
                --self:GibBreakClient(Vector(0,0,10))
                --self:GibBreakServer(Vector(0,0,10))
                SpawnGiftEnt(attacker, self, self:GetPos())
                self:Remove()

                if self:GetIsRandomGift() and not attackerOpenedRandomGift then
                    dbg.Log(attacker:Nick() .. " opened a random gift!")
                    attacker:SetNWBool("OpenedRandomGift", true)
                end
            end
        end
    end
end

function ENT:UpdateScale(scale)
    dbg.Log("(prop) Setting gift model scale to:", scale)
    self:SetModelScale(scale)
    self:Activate()
    self:RefreshPhysics()
end

function ENT:RefreshPhysics()
    dbg.Log("(prop) Refreshing physics")
    self:PhysWake() -- should only need to do this, but just to be safe..
    local phys = self:GetPhysicsObject()

    if IsValid(phys) then
        phys:EnableMotion(true)
        phys:Wake()
    end
end

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "GiftScale")
    self:NetworkVar("Float", 1, "GroundPitch")
    self:NetworkVar("Int", 0, "DescriptionLine")
    self:NetworkVar("Bool", 0, "NotRetrievable")

    self:NetworkVar("Bool", 1, "IsRandomGift")
    self:NetworkVar("String", 0, "WrapperSID")
    self:NetworkVar("String", 1, "CachedDataLabel")
    self:NetworkVar("Entity", 0, "StoredGift")

    self:NetworkVarNotify("GroundPitch", function(ent, name, old, new)
        local giftAngles = self:GetAngles()
        giftAngles.pitch = new + 170
        self:SetAngles(giftAngles)

        local giftPos = self:GetPos()
        local mins, maxs = ent:GetModelBounds()
        local height = (maxs.z - mins.z) * self:GetGiftScale()
        self:SetPos(giftPos + Vector(0, 0, height))

        self:RefreshPhysics()
    end)
end

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString(TREE_FOUND_MSG)

    function ENT:GetGroundAngle()
        local tr = util.TraceLine({
            start  = self:GetPos(),
            endpos = self:GetPos() - Vector(0, 0, 50),
            filter = self
        })

        if tr.Hit then
            return tr.HitNormal:Angle()
        end
    end

    function ENT:Think() -- readjust angle if fallen on its side
        local curTime = CurTime()

        if curTime >= self.LastUprightCheck + self.UprightCheckFreq then
            self.LastUprightCheck = curTime

            local phys = self:GetPhysicsObject()
            if not IsValid(phys) then return end

            local vel = phys:GetVelocity()
            if not vel then return end

            if vel:Length() < 0.1 then
                local groundAngle = self:GetGroundAngle()

                if groundAngle then
                    local pitchDiff = self:GetAngles().pitch - groundAngle.pitch + 190
                    if math.abs(pitchDiff) > 30 then
                        self:SetGroundPitch(groundAngle.pitch)
                    end
                end
            end
        end
    end

    function ENT:Use(activator)
        if self:GetCollisionGroup() ~= COLLISION_GROUP_NONE then return end
        local ownedGiftwrap = utils.GetInventoryGiftwrap(activator)

        if self:GetNotRetrievable() and activator:SteamID64() == self:GetWrapperSID() then
            utils.NonSpamMessage(activator, "GiftPickupAttempt", "Let's keep it neat and tidy here.")
            return
        end

        if ownedGiftwrap then
            if ownedGiftwrap:HasGift() then
                utils.NonSpamMessage(activator, "GiftPickupAttempt", "You already have a gift!")
            else
                utils.NonSpamMessage(activator, "GiftPickupAttempt", "You can't hold both gift and wrap at the same time.")
            end

            return
        end

        local newGift = ents.Create(SWEP_CLASS_NAME)

        if IsValid(newGift) then
            newGift:SetClip1(-1)
            newGift:SetIsRandomGift(self:GetIsRandomGift())
            newGift:SetWrapperSID(self:GetWrapperSID())
            newGift:SetStoredGift(self:GetStoredGift())
            newGift:SetCachedDataLabel(self:GetCachedDataLabel())

            activator:PickupWeapon(newGift)
            activator:SelectWeapon(SWEP_CLASS_NAME)
            self:Remove()
        end
    end

    local function GetWorldGiftPropCount()
        local count = 0

        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent:GetClass() == PROP_CLASS_NAME then
                count = count + 1
            end
        end

        return count
    end

    -- filters out spectators (including sourceTV hopefully)
    function GetLivingPlayerPool()
        local livingPlayers = {}

        for _, ply in ipairs(player.GetAll()) do
            if ply:GetRole() ~= ROLE_NONE and utils.IsLivingPlayer(ply) then
                table.insert(livingPlayers, ply)
            end
        end

        return livingPlayers
    end

    -- spawn random gifts next to / instead of Snuffles gifts
    hook.Add("OnEntityCreated", HOOK_GIFTWRAP_ENT_SPAWN, function(ent)
        if IsValid(ent) and ENABLE_RANDOM:GetBool() then
            -- replace/spawn near present
            if ent:GetClass() == SNUFFLE_PRESENT_CLASS then
                if utils.RoundStartTime and CurTime() > utils.RoundStartTime + 10 then
                    return
                end

                timer.Simple(0.1, function()
                    local worldGiftCnt = GetWorldGiftPropCount()
                    local realPlayerCnt = #GetLivingPlayerPool()

                    if not GW_matchPlayerCountRound and worldGiftCnt < realPlayerCnt then
                        local giftCnt = 1

                        if math.random() <= GW_secondGiftChance then
                            if math.random() <= GW_thirdGiftChance then
                                giftCnt = giftCnt + 1
                            end

                            giftCnt = giftCnt + 1
                        end
                        giftCnt = math.min(giftCnt, realPlayerCnt - worldGiftCnt)
                        dbg.Log("Spawning "..tostring(giftCnt).." gifts.")

                        for i = 1, giftCnt do
                            local newGift = ents.Create(PROP_CLASS_NAME)
                            newGift:SetPos(ent:GetPos() + Vector(0, 0, 100))
                            newGift:SetIsRandomGift(true)
                            newGift:SetWrapperSID("WORLD")
                            newGift:Spawn()
                        end
                    end

                    if REPLACE_SNUFFLES_GIFT:GetBool() then
                        ent:Remove()
                    end
                end)

            -- setup UI indicator for placing gift near tree & do matched player count rounds
            elseif ent:GetClass() == "prop_dynamic" then
                timer.Simple(0.1, function()
                    if ent:GetModel() == SNUFFLE_TREE_MODEL then
                        dbg.Log("Located christmas tree:", ent)
                        christmasTree = ent

                        -- adjust bbox to not be IMMENSE
                        christmasTree:SetCollisionBounds(
                            Vector(-50, -50, 0),
                            Vector(50,   50, 125)
                        )

                        -- play chime from tree if full xmas (everyone can get a gift)
                        timer.Simple(1, function()
                            if IsValid(christmasTree) and GetWorldGiftPropCount() >= #GetLivingPlayerPool() then
                                local bellSFX = math.random() < 0.33 and "bells1" or "bells2"
                                christmasTree:BroadcastSound(sounds[bellSFX], 0, math.random(95, 105), FULL_XMAS_CHIME_VOL:GetFloat()/100) -- everyone hears

                                dbg.Log("Full Christmas round - Played SFX: "..bellSFX..".")
                            end
                        end)

                        -- spawn as many gifts as there are players if special round procced
                        if GW_matchPlayerCountRound then
                            local treePos = christmasTree:GetPos()
                            local realPlayers = GetLivingPlayerPool()
                            dbg.Log("Special round - Placing "..#realPlayers.." gifts.")

                            -- TODO label each gift as being meant for their associated player
                            for i, ply in ipairs(realPlayers) do
                                local overPrevious = (math.random() < 0.2 and -1 or 0)
                                local angle = math.rad(((i + overPrevious) / #realPlayers) * 360)
                                local distance = math.random(55, 60)
                                local presentPos = treePos + Vector(math.cos(angle) * distance, math.sin(angle) * distance, 0)

                                -- Trace down to find ground for gift
                                local tr = util.TraceLine({
                                    start = presentPos + Vector(0, 0, 50),
                                    endpos = presentPos - Vector(0, 0, 100),
                                    --mask = MASK_SOLID
                                })

                                local newGift = ents.Create(PROP_CLASS_NAME)
                                newGift:SetIsRandomGift(true)
                                newGift:SetWrapperSID("WORLD")
                                newGift:SetPos(tr.HitPos + Vector(0, 0, overPrevious and 150 or 75))
                                newGift:SetAngles(Angle(0, angle, 0))
                                newGift:Spawn()
                                dbg.Log("Spawned gift for "..ply:Nick().."! (angle "..tostring(angle)..")")
                            end
                        end

                        net.Start(TREE_FOUND_MSG)
                        net.WriteEntity(christmasTree)
                        net.Broadcast()
                    end
                end)
            end
        end
    end)

    hook.Add("TTTBeginRound", HOOK_ROUND_START_TIME, function()
        utils.RoundStartTime = CurTime()
    end)

elseif CLIENT then
    local matTreeIcon = Material("vgui/ttt/marker_vision/c4")

    net.Receive(TREE_FOUND_MSG, function()
        christmasTree = net.ReadEntity()
    end)

    hook.Add("TTT2RenderMarkerVisionInfo", HOOK_GIFTWRAP_MARKER_UI, function(mvData)
        local ent = mvData:GetEntity()
        local mvObject = mvData:GetMarkerVisionObject()

        if string.sub(mvObject:GetIdentifier(), 1, 21) == MARKER_UI_LABEL then
            mvData:EnableText()
            mvData:SetTitle("Christmas Tree")

            local dist = mvData:GetEntityDistance()

            if dist <= 100 then
                mvData:SetSubtitle("Press ["..Key("+use", "USE").."] to place with others gifts")
            else
                mvData:SetSubtitle("Get closer to place the gift down!")
            end

            mvData:AddDescriptionLine(LANG.GetParamTranslation("marker_vision_distance", {
                distance = util.DistanceToString(dist, 1)
            }))

            mvData:AddIcon(matTreeIcon, COLOR_GREEN)
        end
    end)

    hook.Add("TTTRenderEntityInfo", HOOK_GIFTWRAP_INTERACT_UI, function(tData)
        local client = LocalPlayer()
        if not utils.IsLivingPlayer(client) then return end

        local ent = tData:GetEntity()
        if not IsValid(ent) then return end

        -- picking up prop gift
        if ent:GetClass() == PROP_CLASS_NAME then
            if not ent:GetNotRetrievable() and tData:GetEntityDistance() <= 93.7 then
                tData:EnableText()
                tData:EnableOutline()
                tData:SetOutlineColor(COLOR_GREEN) --TODO: should match gift color2
                tData:SetTitle("Gift")
                tData:SetKeyBinding("+use")
                tData:SetSubtitle(LANG.GetParamTranslation("target_pickup", {
                    usekey = Key("+use", "USE")
                }))

                if client:SteamID64() == ent:GetWrapperSID() then
                    tData:AddDescriptionLine("You wrapped this gift.")
                    tData:AddDescriptionLine(selfDescriptionLines[ent:GetDescriptionLine()])

                -- works, but allows some innos to tell whether a gift is random free of risk which kinda blows
                --elseif client:GetNWBool("OpenedRandomGift") and ent:GetIsRandomGift() and not dbg.Cvar:GetBool() then
                --    tData:AddDescriptionLine("You already opened a random gift.")
                --    tData:AddDescriptionLine("You can unwrap another one next round!")

                else
                    tData:AddDescriptionLine("Can also open with melee attack.")
                    tData:AddDescriptionLine(normalDescriptionLines[ent:GetDescriptionLine()])
                end
            end

        -- placing down gift at tree
        elseif ent:GetModel() == SNUFFLE_TREE_MODEL then
            local wep = client:GetActiveWeapon()

            if utils.IsGiftWrap(wep) and wep:HeldByWrapper(client)
              and tData:GetEntityDistance() <= 84 then
                tData:EnableText()
                tData:EnableOutline()
                tData:SetOutlineColor(COLOR_GREEN)
                tData:SetTitle("Place gift")
                tData:SetKeyBinding("+use")
                tData:SetSubtitle("Press ["..Key("+use", "USE").."] to place with other gifts")
                tData:AddDescriptionLine("Ho ho ho!")
            end
        end
    end)
end

dbg.Log("(prop) Initialized gift entity Lua")