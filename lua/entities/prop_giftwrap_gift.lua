local SNUFFLE_PRESENT_CLASS = "christmas_present"

local HOOK_GIFTWRAP_ENT_SPAWN   = "TTT_GiftWrap_EntSpawn"
local HOOK_GIFTWRAP_MARKER_UI   = "TTT_GiftWrap_MarkerVision"
local HOOK_GIFTWRAP_INTERACT_UI = "TTT_GiftWrap_MarkerVision"
local HOOK_ROUND_START_TIME     = "TTT_GiftWrap_RoundStartTime"
local TREE_FOUND_MSG            = "TTT_GiftWrap_TreeFoundMsg"

local dbg   = GW_DBG
local utils = GW_Utils

local ENABLE_RANDOM           = CreateConVar("ttt2_giftwrap_enable_random_gifts", "1",       GW_CVAR_FLAGS, "Whether to spawn random gifts when Snuffles' YoWaddup Fixes presents are found.", 0, 1)
local REPLACE_SNUFFLES_GIFT   = CreateConVar("ttt2_giftwrap_replace_snuffles_gift", "1",     GW_CVAR_FLAGS, "Whether random gifts from Gift Wrap replace (rather than add to) naturally spawning gifts from Snuffles' YoWaddup General Fixes addon.", 0, 1)
local SECOND_GIFT_CHANCE      = CreateConVar("ttt2_giftwrap_second_gift_chance", "0.5",      GW_CVAR_FLAGS, "Chance for a second random gift spawn per Snuffle gift replaced.", 0, 1)
local THIRD_GIFT_CHANCE       = CreateConVar("ttt2_giftwrap_third_gift_chance", "0.4",       GW_CVAR_FLAGS, "Chance for a third random gift spawn if a second one spawned.", 0, 1)
local SECOND_GIFT_CHANCE_XMAS = CreateConVar("ttt2_giftwrap_second_gift_chance_xmas", "0.9", GW_CVAR_FLAGS, "Chance for a second random gift spawn per Snuffle gift replaced, on Christmas specifically.", 0, 1)
local THIRD_GIFT_CHANCE_XMAS  = CreateConVar("ttt2_giftwrap_third_gift_chance_xmas", "0.6",  GW_CVAR_FLAGS, "Chance for a third random gift spawn if a second one spawned, on Christmas specifically.", 0, 1)
local TIMEZONE_OFFSET_HOURS   = CreateConVar("ttt2_giftwrap_timezone_offset", "0",           GW_CVAR_FLAGS, "Adjusts the timezone used for determining whether it's Christmas (offset in hours).", -24, 24)

ENT.Type = "anim"
ENT.PrintName = "Gift"
ENT.Information = "Gift from TTT2 Gift Wrap. Holds a random trinket!"
ENT.Purpose = "Gift from TTT2 Gift Wrap. Holds a random trinket!"
ENT.Category = "Utility"
ENT.Spawnable = true -- for sandbox ig
ENT.Author = "Guy"

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

        if utils.IsLivingPlayer(attacker) and inflictor and inflictor:GetClass() == "weapon_zm_improvised" then
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
    self:NetworkVar("Entity", 0, "StoredGift")
    self:NetworkVar("String", 1, "CachedDataLabel")
    self:NetworkVar("String", 2, "CachedDataSID")

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
        if self:GetNotRetrievable() then return end
        local ownedGiftwrap = utils.GetInventoryGiftwrap(activator)

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
            newGift:SetCachedDataSID(self:GetCachedDataSID())

            activator:PickupWeapon(newGift)
            activator:SelectWeapon(SWEP_CLASS_NAME)
            self:Remove()
        end
    end

    -- spawn random gifts next to / instead of Snuffles gifts
    hook.Add("OnEntityCreated", HOOK_GIFTWRAP_ENT_SPAWN, function(ent)
        if IsValid(ent) and ENABLE_RANDOM:GetBool() then
            -- replace/spawn near present
            if ent:GetClass() == SNUFFLE_PRESENT_CLASS then
                if utils.RoundStartTime and CurTime() > utils.RoundStartTime + 10 then
                    return
                end

                local adjTime = os.time(os.date("!*t")) + (TIMEZONE_OFFSET_HOURS:GetFloat() * 3600)
                local dayOfYear = tonumber(os.date("!%j", adjTime))

                local isChristmas = (dayOfYear == XMAS_DAY)
                local secondGiftChance = (isChristmas and SECOND_GIFT_CHANCE_XMAS or SECOND_GIFT_CHANCE):GetFloat()
                local thirdGiftChance = (isChristmas and THIRD_GIFT_CHANCE_XMAS or THIRD_GIFT_CHANCE):GetFloat()

                dbg.Log("Day of Year:", dayOfYear, "; Hour", os.date("!%H", adjTime), "; Christmas:", isChristmas,
                        "; second gift chance:", secondGiftChance, "; third gift chance:", thirdGiftChance)

                timer.Simple(0.1, function()
                    local giftCnt = 1

                    if math.random() <= secondGiftChance then
                        if math.random() <= thirdGiftChance then
                            giftCnt = giftCnt + 1
                        end

                        giftCnt = giftCnt + 1
                    end
                    dbg.Log("Spawning "..tostring(giftCnt).." gifts.")

                    for i = 1, giftCnt do
                        newGift = ents.Create(PROP_CLASS_NAME)
                        newGift:SetPos(ent:GetPos() + Vector(0, 0, 100))
                        newGift:SetIsRandomGift(true)
                        newGift:SetWrapperSID("WORLD")
                        newGift:Spawn()
                    end

                    if REPLACE_SNUFFLES_GIFT:GetBool() then
                        ent:Remove()
                    end
                end)

            -- setup UI indicator for placing gift near tree
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
                    tData:AddDescriptionLine("Can also open with crowbar.")
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