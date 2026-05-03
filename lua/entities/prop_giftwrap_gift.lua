local SNUFFLE_PRESENT_CLASS = "christmas_present"

local HOOK_GIFTWRAP_ENT_SPAWN   = "TTT_GiftWrap_EntSpawn"
local HOOK_GIFTWRAP_MARKER_UI   = "TTT_GiftWrap_MarkerVision"
local HOOK_GIFTWRAP_INTERACT_UI = "TTT_GiftWrap_InteractUI"
local HOOK_ROUND_START_TIME     = "TTT_GiftWrap_RoundStartTime"
local TREE_FOUND_MSG            = "TTT_GiftWrapSV_TreeFoundMsg"

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
ENT.Model = GIFT_PROPMODEL --purely for Contents menu rendering

local sounds = {
    bells1 = Sound("giftwrap/tf2_nm_bells1.wav"),
    bells2 = Sound("giftwrap/tf2_nm_bells2.wav"),
    bounce1 = Sound("physics/metal/paintcan_impact_soft1.wav"),
    bounce2 = Sound("physics/metal/paintcan_impact_soft2.wav"),
    bounce3 = Sound("physics/metal/paintcan_impact_soft3.wav"),
}

-- note: due to lazy design, all of these arrays must be of equal length
local normalDescriptionLines = {
    "Have you been a good terrorist this year?",
    "Hope you aren't on the naughty list.",
    "It's what you've always wanted!",
    "What could it be?",
    "Wonder what's inside...",
    "Merry Christmas!",
}

local selfDescriptionLines = {
    "Let's hope they like it!",
    "Do you think they'll like it?",
    "You can't open it, but maybe someone else will.",
    "You can't open it, but hopefully someone else will!",
    "Can be opened by any other terrorist.",
    "Can be opened by anyone else.",
}

local gifteeHintLines = {
    "Help it get delivered!",
    "Help it get delivered!",
    "Help it get delivered!",
    "Let them know!",
    "Let them know!",
    "Magneto it towards them!",
}

local deadGifteeHintLines = {
    "RIP...",
    "RIP...",
    "They can't open it anymore, so you can have it.",
    "They can't open it anymore (RIP), so you can have it.",
    "They can't open it anymore, so it's yours if you want it.",
    "They can't exactly open it anymore, so you can have it.",
}


function ENT:Initialize()
    dbg.Log("(prop) Initializing gift entity")

    self:SetModel(GIFT_PROPMODEL)
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

        self:SetAngles(Angle(0, math.random(0, 360), 0))
        self.LastUprightCheck = CurTime()
        self.UprightCheckFreq = 2
        self:UpdateScale(scale)
        self._LastBounce = 0

        self:SetDescriptionLine(math.random(#normalDescriptionLines))

        -- if clients receive the MV too early, the entity
        -- might not have been created yet and thus be null
        timer.Simple(0.1, function()
            local giftee = self:GetGiftee()

            if IsValid(giftee) then
                local mvObject = self:AddMarkerVision(MV_GIFTEE_LABEL)
                mvObject:SetOwner(giftee)
                mvObject:SetVisibleFor(VISIBLE_FOR_PLAYER)
                mvObject:SyncToClients()
            end
        end)

    elseif CLIENT then
        self:UpdateScale()
        SyncGiftColors(self)
        self.LastGifteeJingleCheck = CurTime() + math.random(1, 10)
        self.GifteeJingleCheckFreq = 20

        self._spawning = true -- bs to make sync work on real servers
        timer.Simple(1, function() self._spawning = false end)
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
            local giftee = self:GetGiftee()

            if attacker:SteamID64() == self:GetWrapperSID() then
                utils.NonSpamMessage(attacker, "OpenAttempt", "You can't open your own gift.")

            elseif IsValid(giftee) and giftee != attacker and not utils.ConfirmedDead(attacker, giftee) then
                notifyHasGiftee(attacker, giftee)

            elseif attackerOpenedRandomGift and self:GetIsRandomGift() and not dbg.Cvar:GetBool() then
                utils.NonSpamMessage(attacker, "OpenAttempt", ERROR_ALREADY_OPENED)

            else
                -- TODO: Proper gibbing?
                --self:GibBreakClient(Vector(0,0,10))
                --self:GibBreakServer(Vector(0,0,10))
                SpawnGiftEnt(attacker, self, utils.GetEntCenter(self))
                self:RemoveMarkerVision(MV_GIFTEE_LABEL)
                self:Remove()

                if self:GetIsRandomGift() and not attackerOpenedRandomGift then
                    dbg.Log(attacker:Nick() .. " opened a random gift!")
                    attacker:SetNWBool("OpenedRandomGift", true)
                end
            end
        end
    end
end

function ENT:GetGiftScale()
    local giftLabel = self:GetCachedDataLabel()
    local giftData  = GetGiftDataFromLabel(giftLabel)

    if giftLabel == "giftwrap" then
        local storedGiftBox = self:GetStoredGift()

        if IsValid(storedGiftBox) then
            -- one of the weirdest recursions I've ever written :D
            return storedGiftBox:GetGiftScale() * 1.25
        end
    end

    if not giftData then
        dbg.Log("[WARNING] Gift prop has no valid data attached; using default size; label: '"..giftLabel.."'")
    end
    return giftData and giftData.attrib_size or 1.5
end

function ENT:UpdateScale()
    local scale = self:GetGiftScale()

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
    local boolCnt, intCnt, stringCnt, entCnt = utils.SetupSharedTable(self)
    self:NetworkVar("Bool", boolCnt, "NotRetrievable")
    self:NetworkVar("Int", intCnt, "DescriptionLine")
end



----------------------------------
----- SERVER REALM SENT DEFS -----
----------------------------------
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

    function ENT:HandleClipbrushCollision(curTime) -- (inspired by corv's Teleport Grenade code)
        local vel     = self:GetVelocity()
        local curPos  = self:GetPos()
        self._LastPos = self._LastPos or curPos

        local filter = { self }
        for _, ply in ipairs(player.GetAll()) do
            table.insert(filter, ply)
        end

        local tr = util.TraceHull({
            start       = self._LastPos,
            endpos      = curPos,
            mask        = MASK_PLAYERSOLID,
            ignoreworld = false,
            filter      = filter
        })

        --debugoverlay.Line(self._LastPos, curPos, 3, Color(255,0,0), true)
        --if tr.Hit then print(tr.Hit, tr.Entity) end

        if tr.Hit and tr.HitPos and not tr.StartSolid and not tr.AllSolid
          and vel:Dot(tr.HitNormal) < 0 and curTime >= self._LastBounce + 0.1 then
            local speed = vel:Length()
            local phys = self:GetPhysicsObject()

            local incoming = tr.HitPos - self._LastPos
            incoming:Normalize()

            self:SetPos(tr.HitPos + incoming)
            phys:SetVelocity(incoming * speed * -1)

            -- un-magneto prop
            if phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) then
                for _, magneto in ipairs(ents.FindByClass("weapon_zm_carry")) do
                    if magneto:GetCarryTarget() == self then
                        magneto:Drop()
                        timer.Simple(0, function() phys:SetVelocity(incoming * speed * -1) end)
                        break
                    end
                end
            end

            local bounceVol   = math.max(0.1, speed/720)
            local bouncePitch = math.max(30, -12*self:GetGiftScale() + 130)

            dbg.Log("Playing bounce sound w/ vol "..bounceVol.."% (speed: "..speed..") & pitch "..bouncePitch.."% (scale: "..self:GetGiftScale()..")")
            self:EmitSound(sounds["bounce"..math.random(3)], 75, bouncePitch, bounceVol)
            self._LastBounce = curTime
        end

        self._LastPos = curPos
    end

    function ENT:UprightCheck() -- Readjust angle if fallen on its side
        local phys = self:GetPhysicsObject()
        if not IsValid(phys) then return end
        if phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) then return end

        local vel = phys:GetVelocity()
        if not vel then return end

        if vel:Length() < 0.1 then
            local startPos = self:GetPos()
            local tr = util.TraceLine({
                start = startPos,
                endpos = startPos - Vector(0, 0, 100),
                filter = self
            })
            if not tr.Hit then return end
            local dot = self:GetUp():Dot(tr.HitNormal)

            if dot < 0.9 then
                local ang = tr.HitNormal:Angle()
                ang:RotateAroundAxis(ang:Right(), -90)
                self:SetAngles(ang)

                local mins, maxs = self:GetModelBounds()
                local height = math.abs(maxs.z - mins.z) * self:GetGiftScale()

                self:SetPos(self:GetPos() + Vector(0, 0, height))
                self:RefreshPhysics()
            end
        end
    end

    function ENT:Think()
        local curTime = CurTime()

        if curTime >= self.LastUprightCheck + self.UprightCheckFreq then
            self.LastUprightCheck = curTime
            self:UprightCheck()
        end

        self:HandleClipbrushCollision(curTime)
    end

    function notifyHasGiftee(ply, giftee)
        utils.NonSpamMessage(ply, "GiftPickupAttempt", "It's meant for "..giftee:Nick()..". "..gifteeHintLines[math.random(#gifteeHintLines)])
    end

    function ENT:Use(activator)
        if self:GetCollisionGroup() ~= COLLISION_GROUP_NONE then return end
        local ownedGiftwrap = utils.GetInventoryGiftwrap(activator)
        local pickupByWrapper = activator:SteamID64() == self:GetWrapperSID()

        if self:GetNotRetrievable() and pickupByWrapper then
            utils.NonSpamMessage(activator, "GiftPickupAttempt", "Let's keep it neat and tidy here.")
            return
        end

        if ownedGiftwrap then
            if ownedGiftwrap:HasGift() then
                utils.NonSpamMessage(activator, "GiftPickupAttempt", "You already have a gift!")
            else
                utils.NonSpamMessage(activator, "GiftPickupAttempt", "You can't hold both gift and wrap at the same time.")
            end

            return --TODO: try throwing out held one instead to allow pickup
        end

        if not pickupByWrapper then
            local giftee = self:GetGiftee()
            if IsValid(giftee) and activator != giftee and not utils.ConfirmedDead(activator, giftee) then
                notifyHasGiftee(activator, giftee)
                return
            end
        end

        local newGift = ents.Create(SWEP_CLASS_NAME)

        if IsValid(newGift) then
            utils.TransferNetVars(self, newGift)
            newGift:SetClip1(-1)

            activator:PickupWeapon(newGift)
            activator:SelectWeapon(SWEP_CLASS_NAME)
            self:RemoveMarkerVision(MV_GIFTEE_LABEL)
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
                    if IsValid(ent) and ent:GetModel() == SNUFFLE_TREE_MODEL then
                        dbg.Log("Located christmas tree:", ent)
                        christmasTree = ent

                        -- adjust bbox to not be IMMENSE
                        christmasTree:SetCollisionBounds(
                            Vector(-50, -50, 0),
                            Vector(50,   50, 125)
                        )

                        -- play chime from tree if full xmas (everyone can get a gift)
                        timer.Simple(1, function()
                            local livingPlayerCount = #GetLivingPlayerPool()

                            if IsValid(christmasTree) and livingPlayerCount >= 5
                              and GetWorldGiftPropCount() >= livingPlayerCount then
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




----------------------------------
----- CLIENT REALM SENT DEFS -----
----------------------------------
elseif CLIENT then
    local matTreeIcon = Material("vgui/ttt/marker_vision/c4")
    local giftIcon = Material("vgui/ttt/menu/icon_gift")

    net.Receive(TREE_FOUND_MSG, function()
        christmasTree = net.ReadEntity()
    end)

    function ENT:Think() -- periodic jingle noise if there's a gift meant for you out there
        local curTime = CurTime()

        if curTime >= self.LastGifteeJingleCheck + self.GifteeJingleCheckFreq then
            self.LastGifteeJingleCheck = curTime + math.random(-5, 3)

            local ply = LocalPlayer()
            if ply == self:GetGiftee() then
                LANG.ShowStyledMsg("Someone left you a present!", LANG.GetStyle(nil, MSG_MSTACK_PLAIN))
                local bellSFX = math.random() < 0.33 and "bells1" or "bells2"
                self:EmitSound(sounds[bellSFX], SNDLVL_180dB, math.random(95, 105), 100)
            end
        end
    end

    hook.Add("TTT2RenderMarkerVisionInfo", HOOK_GIFTWRAP_MARKER_UI, function(mvData)
        local ent = mvData:GetEntity()
        local mvObject = mvData:GetMarkerVisionObject()

        if mvObject:IsObjectFor(ent, MV_GIFTEE_LABEL) then
            local dist = mvData:GetEntityDistance()
            if dist < 150 then return end

            mvData:AddIcon(giftIcon, COLOR_WHITE)
            mvData:EnableText()
            mvData:SetTitle("A gift just for you!")

            mvData:AddDescriptionLine(LANG.GetParamTranslation("marker_vision_distance", {
                distance = util.DistanceToString(dist, 1)
            }))

        elseif string.sub(mvObject:GetIdentifier(), 1, 21) == MV_TREE_LABEL then
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
                local giftee = ent:GetGiftee()
                local isGiftee = not IsValid(giftee) or client == giftee
                local knownDeadGiftee = utils.ConfirmedDead(client, giftee)
                local isWrapper  = client:SteamID64() == ent:GetWrapperSID()

                tData:EnableText()
                tData:EnableOutline()
                tData:SetOutlineColor(UnpackColor(ent:GetGiftRibbonColor()))
                tData:SetTitle(not isGiftee and ("Gift for "..giftee:Nick()) or "Gift")

                if isGiftee or isWrapper or knownDeadGiftee then
                    tData:SetKeyBinding("+use")
                    tData:SetSubtitle(LANG.GetParamTranslation("target_pickup", {
                        usekey = Key("+use", "USE")
                    }))
                end

                if isWrapper then
                    tData:AddDescriptionLine("You wrapped this gift.")
                    tData:AddDescriptionLine(selfDescriptionLines[ent:GetDescriptionLine()])

                else
                    if not isGiftee then
                        tData:AddDescriptionLine("The gift tag reads \""..giftee:Nick().."\"")

                        if knownDeadGiftee then
                            tData:AddDescriptionLine(deadGifteeHintLines[ent:GetDescriptionLine()])
                        else
                            tData:AddDescriptionLine(gifteeHintLines[ent:GetDescriptionLine()])
                        end

                    else
                        tData:AddDescriptionLine("Can also open with melee attack.")
                        tData:AddDescriptionLine(normalDescriptionLines[ent:GetDescriptionLine()])
                    end
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

    -- ugly; unfortunately needed to work on external servers
    function ENT:Draw()
        if self._spawning then
            SyncGiftColors(self)
        end

        self:DrawModel()
    end
end

dbg.Log("(prop) Initialized gift entity Lua")