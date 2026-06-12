local SNUFFLE_PRESENT_CLASS = "christmas_present"

local HOOK_GIFTWRAP_MARKER_UI   = "TTT_GiftWrapCL_MarkerVision"
local HOOK_GIFTWRAP_INTERACT_UI = "TTT_GiftWrapCL_InteractUI"
local HOOK_GIFTWRAP_SPEC_USE    = "TTT_GiftWrapCL_SpectatorUseKey"
local HOOK_GIFTWRAP_BIND_VIEW   = "TTT_GiftWrapCL_ViewFromGiftPos"
local HOOK_GIFTWRAP_ENT_SPAWN   = "TTT_GiftWrapSV_EntSpawn"
local HOOK_VEHICLE_GIFT_PVS     = "TTT_GiftWrapSV_WrappedRiderPVSFix"
local HOOK_ON_EXIT_VEHICLE_GIFT = "TTT_GiftWrapSV_WrappedRiderVehicleExit"
local HOOK_EXIT_VEHICLE_GIFT    = "TTT_GiftWrapSV_WrappedRiderVehicleCanExit"
local HOOK_ROUND_START_TIME     = "TTT_GiftWrapSV_RoundStartTime"
local HOOK_EXTINGUISH           = "TTT_GiftWrapSV_Extinguish"
local TREE_FOUND_MSG            = "TTT_GiftWrapSV_TreeFoundMsg"

local dbg   = GW_DBG
local utils = GW_Utils

local ENABLE_RANDOM         = utils.Cvar("ttt2_giftwrap_enable_random_gifts", "1", 0, 1, "Whether to spawn random gifts when Snuffles' YoWaddup Fixes presents are found.")
local REPLACE_SNUFFLES_GIFT = utils.Cvar("ttt2_giftwrap_replace_snuffles_gift", "1", 0, 1, "Whether random gifts from Gift Wrap replace (rather than add to) naturally spawning gifts from Snuffles' YoWaddup General Fixes addon.")
local FULL_XMAS_CHIME_VOL   = utils.Cvar("ttt2_giftwrap_all_served_chime_vol", "80", 0, 100, "Volume of the chime sound effect that plays from YoWaddup Christmas trees when as many gifts spawn as there are players at round start.")

ENT.Type = "anim"
ENT.PrintName = "Gift"
ENT.Information = "Gift from TTT2 Gift Wrap. Holds a random trinket!"
ENT.Purpose = "Gift from TTT2 Gift Wrap. Holds a random trinket!"
ENT.Category = "Utility"
ENT.Spawnable = true -- for sandbox ig
ENT.Author = "Guy"
ENT.Model = GIFT_PROPMODEL --purely for Contents menu rendering

local sounds = {
    bells1   = Sound("giftwrap/tf2_nm_bells1.wav"),
    bells2   = Sound("giftwrap/tf2_nm_bells2.wav"),
    bounce1  = Sound("physics/metal/paintcan_impact_soft1.wav"),
    bounce2  = Sound("physics/metal/paintcan_impact_soft2.wav"),
    bounce3  = Sound("physics/metal/paintcan_impact_soft3.wav"),
    teleport = Sound("giftwrap/teleport.mp3"),
    pop      = Sound("garrysmod/balloon_pop_cute.wav"),
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

        if self:GetCachedDataLabel() == "flame" then
            self:Ignite(3600)
        end

        -- if clients receive the MV too early, the entity
        -- might not have been created yet and thus be null
        timer.Simple(0.1, function()
            if not IsValid(self) then return end
            local giftee = self:GetGiftee()

            if IsValid(giftee) then
                local mvGiftee = self:AddMarkerVision(MV_GIFTEE_LABEL)
                mvGiftee:SetOwner(giftee)
                mvGiftee:SetVisibleFor(VISIBLE_FOR_PLAYER)
                mvGiftee:SetColor(UnpackColor(self:GetGiftBoxColor()))
                mvGiftee:SyncToClients()
            end

            local wrapper = utils.GetWrapper(self)

            if IsValid(wrapper) then
                local mvWrapper = self:AddMarkerVision(MV_WRAPPER_LABEL)
                mvWrapper:SetOwner(wrapper)
                mvWrapper:SetVisibleFor(VISIBLE_FOR_PLAYER)
                mvWrapper:SetColor(UnpackColor(self:GetGiftBoxColor()))
                mvWrapper:SyncToClients()
                self.mvWrapper = mvWrapper
            end
        end)

    elseif CLIENT then
        self:UpdateScale()
        SyncGiftColors(self)
        self.GifteeJingleCheckFreq = 20
        self.LastGifteeJingleCheck = CurTime() - (self.GifteeJingleCheckFreq - math.random(3, 5))

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

            --elseif attackerOpenedRandomGift and self:GetIsRandomGift() and not dbg.Cvar:GetBool() then
            --    utils.NonSpamMessage(attacker, "OpenAttempt", ERROR_ALREADY_OPENED)

            else
                -- TODO: Proper gibbing?
                --self:GibBreakClient(Vector(0,0,10))
                --self:GibBreakServer(Vector(0,0,10))
                SpawnGiftEnt(attacker, self, utils.GetEntCenter(self))
                self:RemoveMarkerVision(MV_WRAPPER_LABEL)
                self:RemoveMarkerVision(MV_GIFTEE_LABEL)
                self:RemoveMarkerVision(MV_GIFT_TP_LABEL)

                self._PreserveGift = true
                self:Remove()

                if self:GetIsRandomGift() and not attackerOpenedRandomGift then
                    dbg.Log(attacker:Nick() .. " opened a random gift!")
                    attacker:SetNWBool("OpenedRandomGift", true)
                end
            end
        end
    end
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS -- update state for all clients
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

    return giftData and giftData:GetSize(self) or 1.5
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
    self:NetworkVar("Float", 0, "TPNoticeDisableTime")
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
        local vel    = self:GetVelocity()
        local curPos = self:GetPos()
        local phys   = self:GetPhysicsObject()
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

        -- no timeout mechanism for magneto movement
        if phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) then
            self._LastBounce = 0
        end

        --debugoverlay.Line(self._LastPos, curPos, 3, Color(255,0,0), true)
        --if tr.Hit then print(tr.Hit, tr.Entity) end

        local _, startBounceZone = utils.PointZone(self._LastPos)
        local _, endBounceZone = utils.PointZone(curPos)

        local clipbrushCol = tr.Hit and tr.HitPos and not tr.StartSolid and not tr.AllSolid and vel:Dot(tr.HitNormal) < 0
        local oobZoneCol   = not startBounceZone and endBounceZone and self._LastPos:Distance(curPos) < 150

        if clipbrushCol or oobZoneCol then
            if curTime < self._LastBounce + (clipbrushCol and 1 or 0.5) then
                dbg.Log("Bounce detected but skipped due to cooldown; ", curTime, self._LastBounce)
                self._LastPos = curPos
                return
            end

            local speed = vel:Length()

            local incoming = tr.HitPos - self._LastPos
            incoming:Normalize()

            self:SetPos(tr.HitPos + incoming)
            phys:SetVelocity(incoming * speed * -1)

            -- un-magneto prop
            if phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) then
                for _, magneto in ipairs(ents.FindByClass("weapon_zm_carry")) do
                    if magneto:GetCarryTarget() == self then
                        magneto:Drop()
                        self._LastBounce = 0
                        timer.Simple(0, function() phys:SetVelocity(incoming * speed * -1) end)
                        break
                    end
                end
            end

            self:PlayBounceSFX(speed)
            self._LastBounce = curTime
        end

        self._LastPos = curPos
    end

    function ENT:PlayBounceSFX(speed)
        local scale = self:GetGiftScale()
        local bounceVol   = math.max(0.1, speed/720)
        local bouncePitch = math.max(30, -12*scale + 130)

        dbg.Log("Playing bounce sound w/ vol "..(bounceVol*100).."% (speed: "..speed..") & pitch "..bouncePitch.."% (scale: "..scale..")")
        self:EmitSound(sounds["bounce"..math.random(3)], 75, bouncePitch, bounceVol)
    end

    function ENT:GetZOffsetVec()
        local mins, maxs = self:GetModelBounds()
        local height = math.abs(maxs.z - mins.z) * self:GetGiftScale() * 0.5

        return Vector(0, 0, height)
    end

    function ENT:UprightCheck(verbose) -- Readjust angle if fallen on its side
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

            local upNormal = tr.Hit and tr.HitNormal or Vector(0,0,1)
            local dot = self:GetUp():Dot(upNormal)

            if dot < 0.9 then
                dbg.Log("Toppling detected; correcting")
                local ang = upNormal:Angle()
                ang:RotateAroundAxis(ang:Right(), -90)
                self:SetAngles(ang)

                local newPos = self:GetPos() + self:GetZOffsetVec()
                --debugoverlay.Cross(newPos, 10, 15, GW_DBG.Red)
                --print(util.IsInWorld(newPos))

                self:SetPos(newPos)
                self:RefreshPhysics()

            elseif verbose then
                dbg.Log("Upright check passed")
            end

        elseif verbose then
            dbg.Log("Upright check cancelled; velocity too high:", vel:Length())
        end
    end

    function ENT:HandleMapExitTimeout(curTime)
        local spawnRad = utils.mapSpawnStats.radius
        --print(utils.PointZone(self:GetPos()))
        --dbg.DebugSpawns(self, spawnRad, true)
        --dbg.ShowNearbySpawns(spawnRad, 2, 0.2)

        local exitedMap = function(curZone)
            local pos = self:GetPos()

            if not curZone then
                curZone = utils.PointZone(pos)
            end

            if curZone == "safe" then
                return false
            else
                return curZone == "exit" or curZone == "troom"
                  or (spawnRad and not utils.IsNearAnySpawn(pos, spawnRad))
                  or (utils.mapSpawnStats.waterExit and self:WaterLevel() > 0)
            end
        end

        if not self.LastMapExit then
            local curZone = utils.PointZone(self:GetPos())

            if exitedMap(curZone) then
                dbg.Log("Map exit check started...")
                self.LastMapExit = (curZone == "troom" and (curTime + 3) or curTime)
            end

        elseif curTime > self.LastMapExit + utils.mapSpawnStats.timeout then
            if exitedMap() then
                local curPos = self:GetPos()
                local spawnPos = utils.NearestSpawn(curPos).pos
                local spawnHeight = Vector(0, 0, utils.mapSpawnStats.spnHeight)
                local phys = self:GetPhysicsObject()

                local tr = util.TraceLine({
                    start  = spawnPos + spawnHeight,
                    endpos = spawnPos - spawnHeight,
                    mask = MASK_SOLID_BRUSHONLY
                })

                local newPos = (tr.Hit and tr.HitPos or spawnPos + Vector(0, 0, 20)) + self:GetZOffsetVec()
                local tpDist = curPos:Distance(newPos)
                dbg.Log("Map exit detected; moving to", newPos)

                self._LastPos = nil --invalidate
                self:SetPos(newPos)
                self:SetAngles(Angle(0, 0, 0))
                self:EmitSound(sounds["teleport"], 75, math.random(95, 100), 0.9)
                self:RefreshPhysics()

                -- notify magnetoing player if any
                if phys:HasGameFlag(FVPHYSICS_PLAYER_HELD) then
                    for _, magneto in ipairs(ents.FindByClass("weapon_zm_carry")) do
                        if magneto:GetCarryTarget() == self then
                            magneto:Drop()
                            utils.NonSpamMessage(magneto:GetOwner(), "GIFT_TP", "The gift you were holding seemed to be out of bounds and was teleported back in-bounds.")
                            break
                        end
                    end
                end

                -- I don't get why this is needed for the client
                -- not to freak out... (shouldn't setPos be enough?) (or phys:SetPos?)
                net.Start(TP_GIFT_MSG)
                net.WriteEntity(self)
                net.WriteVector(newPos)
                net.Broadcast()

                -- short-lived markervision to notify of position change
                local mvObject = self:AddMarkerVision(MV_GIFT_TP_LABEL)
                mvObject:SetOwner(0)
                mvObject:SetVisibleFor(VISIBLE_FOR_ALL)
                mvObject:SetColor(UnpackColor(self:GetGiftBoxColor()))
                mvObject:SyncToClients()

                local tpNoticeDisableTime = (tpDist > 1000) and 30 or 15
                self:SetTPNoticeDisableTime(curTime + tpNoticeDisableTime)
                timer.Simple(tpNoticeDisableTime, function()
                    if IsValid(self) then
                        dbg.Log("Turning off teleport notice for", self)
                        self:RemoveMarkerVision(MV_GIFT_TP_LABEL)

                        -- resync mark color in case gift had giftee
                        local giftee = self:GetGiftee()
                        if IsValid(giftee) then
                            net.Start(UNHIDE_MARK_MSG)
                            net.WriteEntity(self)
                            net.Send(giftee)
                        end
                    end
                end)

            else
                dbg.Log("Map exit cancelled")
            end

            self.LastMapExit = nil
        end
    end

    function ENT:Think()
        local curTime = CurTime()

        -- prevent updates from gifts currently wrapped in other gifts
        if IsValid(self:GetNW2Entity("WrappedByGift")) then
            self._LastPos = nil
            return
        end

        if curTime >= self.LastUprightCheck + self.UprightCheckFreq then
            self.LastUprightCheck = curTime
            self:UprightCheck(false)

            -- bandaid fix on cases of server-client position disagreement
            net.Start(TP_GIFT_MSG)
            net.WriteEntity(self)
            net.WriteVector(self:GetPos())
            net.Broadcast()
        end

        self:HandleClipbrushCollision(curTime)
        self:HandleMapExitTimeout(curTime)
    end

    function notifyHasGiftee(ply, giftee)
        utils.NonSpamMessage(ply, "GiftPickupAttempt", "It's meant for "..giftee:Nick()..". "..gifteeHintLines[math.random(#gifteeHintLines)])
    end

    function ENT:Use(activator)
        if self:GetCollisionGroup() ~= COLLISION_GROUP_NONE then return end
        if activator._DisableGiftUse then return end
        if utils.IsPlayerWrapped(activator) then return end
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
            newGift:SetClip1((pickupByWrapper and self:GetNW2Bool("ClipRevealed")) and self:GetRemainingPaper() or -1)

            if self.mvWrapper then
                if pickupByWrapper then
                    self:RemoveMarkerVision(MV_WRAPPER_LABEL)
                else
                    self.mvWrapper:SetEnt(newGift)
                    self.mvWrapper:SyncToClients()
                end
            end

            activator:PickupWeapon(newGift)
            self:RemoveMarkerVision(MV_GIFTEE_LABEL)
            self:RemoveMarkerVision(MV_GIFT_TP_LABEL)

            self._PreserveGift = true
            self:Remove()

            -- must delay this for the holdtype to be correct (nothing else I tried worked)
            timer.Simple(0, function()
                if IsValid(activator) then
                    activator:SelectWeapon(SWEP_CLASS_NAME)
                end
            end)
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
                            SpawnRandomGift(ent:GetPos() + Vector(0, 0, 100))
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

                                local spawnPos = tr.HitPos + Vector(0, 0, overPrevious and 150 or 75)
                                SpawnRandomGift(spawnPos, angle)
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
        utils.RoundStartTime = CurTime() --todo rework
    end)

    hook.Add("ExtinguisherDoExtinguish", HOOK_EXTINGUISH, function(prop)
        if IsValid(prop) and prop:GetClass() == PROP_CLASS_NAME and prop:GetCachedDataLabel() == "flame" then
            prop:BecomeBackWrap()
        end
    end)

    function ENT:BecomeBackWrap() -- edmund mcmillen you little fucker
        -- TODO: for some reason it doesn't use the right collision model?
        --       also should transfer color/note etc.
        local newWrap = ents.Create(SWEP_CLASS_NAME)
        newWrap:SetPos(self:GetPos() + Vector(0, 0, 10))
        newWrap:Spawn()

        self:Remove()
    end

    function ENT:OnRemove()
        if self._PreserveGift then return end
        local storedGift = self:GetStoredGift()

        if IsValid(storedGift) then
            dbg.Log("Removing stored gift:", storedGift)
            storedGift:Remove()
        end
    end

    function SpawnRandomGift(pos, angle)
        local newGift = ents.Create(PROP_CLASS_NAME)
        newGift:SetIsRandomGift(true)
        newGift:SetWrapperSID("WORLD")
        newGift:SetPos(pos)
        RollGiftColors(newGift)

        if angle then
            newGift:SetAngles(Angle(0, angle, 0))
        end

        newGift:Spawn()
        return newGift
    end

    -- technically unnecessary since vehicles follow giftbox pos, but good just in case
    hook.Add("SetupPlayerVisibility", HOOK_VEHICLE_GIFT_PVS, function(ply, viewEntity)
        local parent = ply:GetParent()
        if not IsValid(parent) then return end
        local parentGift = parent:GetNW2Entity("WrappedByGift")

        if IsValid(parentGift) then
            AddOriginToPVS(parentGift:GetPos())
        end
    end)

    hook.Add("PlayerLeaveVehicle", HOOK_ON_EXIT_VEHICLE_GIFT, function(ply, veh)
        local parentGift = veh:GetNW2Entity("WrappedByGift")

        if IsValid(parentGift) then
            utils.TpViewing(ply, parentGift, 80, 20)
            ply:EmitSound(sounds["pop"], 75, math.random(90, 110), 0.5)
            ply._DisableGiftUse = true

            timer.Simple(1, function()
                if IsValid(ply) then
                    ply._DisableGiftUse = false
                end
            end)
        end
    end)

    hook.Add("CanExitVehicle", HOOK_EXIT_VEHICLE_GIFT, function(veh, ply)
        local parentGift = veh:GetNW2Entity("WrappedByGift")

        if IsValid(parentGift) then
            ply:ExitVehicle()
        end
    end)



----------------------------------
----- CLIENT REALM SENT DEFS -----
----------------------------------
elseif CLIENT then
    local matTreeIcon = Material("vgui/ttt/marker_vision/c4")
    local gwInteractDist = 93.7 -- unsure why this number

    net.Receive(TREE_FOUND_MSG, function()
        christmasTree = net.ReadEntity()
    end)

    net.Receive(TP_GIFT_MSG, function()
        local giftEnt = net.ReadEntity()
        local newPos = net.ReadVector()

        if IsValid(giftEnt) then
            giftEnt:SetPos(newPos)
        end
    end)

    function ENT:Think() -- periodic jingle noise if there's a gift meant for you out there
        local curTime = CurTime()

        if curTime >= self.LastGifteeJingleCheck + self.GifteeJingleCheckFreq then
            self.LastGifteeJingleCheck = curTime + math.random(-5, 3)

            local ply = LocalPlayer()
            if ply == self:GetGiftee() and ply:Alive() then
                LANG.ShowStyledMsg("Someone left you a present!", LANG.GetStyle(nil, MSG_MSTACK_PLAIN))
                local bellSFX = math.random() < 0.33 and "bells1" or "bells2"
                self:EmitSound(sounds[bellSFX], SNDLVL_180dB, math.random(95, 105), 100)
            end
        end
    end

    hook.Add("TTT2RenderMarkerVisionInfo", HOOK_GIFTWRAP_MARKER_UI, function(mvData)
        local ent = mvData:GetEntity()
        if not utils.IsGiftBox(ent) then return end

        if ent._HideMarks or ent:GetNWBool("PEPlanted") then
            mvData.drawInfo = false
            return
        end

        local mvObject = mvData:GetMarkerVisionObject()

        if mvObject:IsObjectFor(ent, MV_WRAPPER_LABEL) then
            local dist = mvData:GetEntityDistance()
            if dist < 150 then return end

            local giftLabel = ent:GetCachedDataLabel()
            if giftLabel == "c4" then -- special exception
                local wrappedEnt = ent:GetStoredGift()

                if IsValid(wrappedEnt) and wrappedEnt:GetArmed() then
                    return
                end
            end

            mvData:AddIcon(MAT_GIFT_ICON, Color(150, 150, 150))
            mvData:EnableText()

            local giftee = ent:GetGiftee()
            if IsValid(giftee) then
                mvData:SetTitle(LANG.GetParamTranslation("gift_mv_wrapper_giftee", {
                    giftee = giftee:Nick()
                }))
            else
                mvData:SetTitle(utils.TL("gift_mv_wrapper"))
            end

            local giftData  = GetGiftDataFromLabel(giftLabel)
            mvData:AddDescriptionLine(LANG.GetParamTranslation("gift_mv_wrapper_contents", {
                content = giftData:GetName(ent, LocalPlayer())
            }))

            mvData:AddDescriptionLine(LANG.GetParamTranslation("marker_vision_distance", {
                distance = util.DistanceToString(dist, 1)
            }))

        elseif mvObject:IsObjectFor(ent, MV_GIFTEE_LABEL) then
            local dist = mvData:GetEntityDistance()
            if dist < 150 then return end

            mvData:AddIcon(MAT_GIFT_ICON, COLOR_WHITE)
            mvData:EnableText()
            mvData:SetTitle(utils.TL("gift_mv_giftee"))

            mvData:AddDescriptionLine(LANG.GetParamTranslation("marker_vision_distance", {
                distance = util.DistanceToString(dist, 1)
            }))

        elseif mvObject:IsObjectFor(ent, MV_GIFT_TP_LABEL) --prevent them rendering atop each other
          and not (ent:GetMarkerVision(MV_GIFTEE_LABEL) or ent:GetMarkerVision(MV_WRAPPER_LABEL)) then
            local timeLeft = ent:GetTPNoticeDisableTime() - CurTime()
            if timeLeft < 0 then return end

            mvData:AddIcon(MAT_GIFT_ICON, COLOR_WHITE)
            mvData:EnableText()
            mvData:SetTitle(utils.TL("gift_mv_tp"))
            mvData:AddDescriptionLine(utils.TL("gift_mv_tp_desc"))
            mvData:AddDescriptionLine(LANG.GetParamTranslation("gift_mv_tp_time", {
                timeLeft = math.Round(timeLeft)
            }))

        --[[elseif string.sub(mvObject:GetIdentifier(), 1, 21) == MV_TREE_LABEL then
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
        ]]end
    end)

    hook.Add("TTTRenderEntityInfo", HOOK_GIFTWRAP_INTERACT_UI, function(tData)
        local client = LocalPlayer()
        local clientAlive = utils.IsLivingPlayer(client)

        local ent = tData:GetEntity()
        if not IsValid(ent) then return end

        -- looking at thrown SENT gift
        if ent:GetClass() == PROP_CLASS_NAME then
            if not ent:GetNotRetrievable() and tData:GetEntityDistance() <= gwInteractDist and not utils.IsPlayerWrapped(client) then
                local giftee = ent:GetGiftee()
                local isGiftee = not IsValid(giftee) or client == giftee
                local knownDeadGiftee = utils.ConfirmedDead(client, giftee)
                local isWrapper  = client:SteamID64() == ent:GetWrapperSID()

                tData:EnableText()
                tData:EnableOutline()
                tData:SetOutlineColor(UnpackColor(ent:GetGiftRibbonColor()))
                tData:SetTitle(not isGiftee and ("Gift for "..giftee:Nick()) or "Gift")

                if isGiftee or isWrapper or knownDeadGiftee or not clientAlive then
                    tData:SetKeyBinding("+use")
                    tData:SetSubtitle(LANG.GetParamTranslation(clientAlive and "target_pickup" or "gift_instruction_spec", {
                        usekey = Key("+use", "USE")
                    }))
                end

                if isWrapper then
                    tData:AddDescriptionLine("You wrapped this gift.")

                    if clientAlive then
                        tData:AddDescriptionLine(selfDescriptionLines[ent:GetDescriptionLine()])
                    end

                else
                    if not isGiftee then
                        tData:AddDescriptionLine("The gift tag reads \""..giftee:Nick().."\"")

                        if clientAlive then
                            if knownDeadGiftee then
                                tData:AddDescriptionLine(deadGifteeHintLines[ent:GetDescriptionLine()])
                            else
                                tData:AddDescriptionLine(gifteeHintLines[ent:GetDescriptionLine()])
                            end
                        end

                    elseif clientAlive then
                        tData:AddDescriptionLine("Can also open with melee attack.")
                        tData:AddDescriptionLine(normalDescriptionLines[ent:GetDescriptionLine()])
                    end
                end
            end

        -- placing down gift at tree (deprecated)
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

        -- looking at wrap target
        local wep = client:GetActiveWeapon()

        if utils.IsGiftWrap(wep) and not wep:HasGift() and not utils.IsMapClass(ent)
          and tData:GetEntityDistance() <= 150 then
            local color = UnpackColor(wep:GetGiftBoxColor())
            tData:EnableOutline()

            local wrapConstraint, wrapPaper = QueryWrapData(ent)

            if wrapConstraint then
                local darker = 100
                color = Color(math.max(color.r-darker,0), math.max(color.g-darker,0), math.max(color.b-darker,0))
                tData:SetOutlineColor(color)
                tData:EnableText()

                --tData:AddDescriptionLine("Can't be wrapped!")
                tData:AddDescriptionLine(wrapConstraint, color)
            else
                tData:SetOutlineColor(color)

                if wrapPaper and wep:GetRemainingPaper() - wrapPaper <= 0 then
                    tData:EnableText()
                    tData:AddDescriptionLine("Requires all the paper on your roll (can't undo wrap!)", Color(255, 100, 100))
                end
            end
        end
    end)

    -- allow spectators to peek into gifts
    hook.Add("PlayerBindPress", HOOK_GIFTWRAP_SPEC_USE, function(ply, bind, pressed, code)
        if not pressed or utils.IsLivingPlayer(ply) then return end

        if bind == "+use" then
            local tr = utils.GetEyeTrace(ply)

            if IsValid(tr.Entity) and tr.Entity:GetClass() == PROP_CLASS_NAME and tr.StartPos:Distance(tr.HitPos) <= gwInteractDist then
                ToggleGiftOptions(tr.Entity)
            end

        elseif bind == "gm_showspare2" then
            tgt = ply:GetObserverTarget()
            if not IsValid(tgt) or not tgt:IsPlayer() then return end

            local gift = utils.GetInventoryGiftwrap(tgt)
            if not IsValid(gift) or not gift:HasGift() then return end

            ToggleGiftOptions(gift)
        end
    end)

    -- ask server for constraint data (needed; no phys on client) & cache it
    local GiftWrapDataQueryCache = {}

    function QueryWrapData(ent)
        local key = ent:EntIndex()
        local query = GiftWrapDataQueryCache[key]

        if query and CurTime() < query.time + 2 then
            return query.constraint, query.paper
        end

        net.Start(WRAP_CONSTRAINT_QUERY_MSG)
        net.WriteEntity(ent)
        net.SendToServer()

        local prevConstraint = query and query.constraint
        local prevPaper = query and query.paper

        GiftWrapDataQueryCache[key] = {
            time = CurTime(),
            constraint = prevConstraint,
            paper = prevPaper,
        }

        return prevConstraint, prevPaper
    end

    net.Receive(WRAP_CONSTRAINT_REPLY_MSG, function()
        local key        = net.ReadFloat()
        local constraint = net.ReadString()
        local paper      = net.ReadFloat()

        GiftWrapDataQueryCache[key].constraint = (constraint ~= "") and constraint
        GiftWrapDataQueryCache[key].paper = paper
    end)

    -- ugly; unfortunately needed to work on external servers
    function ENT:Draw()
        if self._spawning then
            SyncGiftColors(self)
        end

        self:DrawModel()
    end

    function ENT:OnRemove()
        if IsValid(HELPSCRN._gwOptMenu) and HELPSCRN._gwRef == self then
            HELPSCRN._gwOptMenu:Close()
        end
    end

    -- support for players in gifts seeing from inside the gift
    hook.Add("CalcView", HOOK_GIFTWRAP_BIND_VIEW, function(ply, pos, angles, fov, znear, zfar)
        local parent = ply:GetParent()
        if not IsValid(parent) then return end
        local parentGift = parent:GetNW2Entity("WrappedByGift")

        if IsValid(parentGift) then
            local viewPos = parentGift:GetPos()

            if parentGift:GetClass() == SWEP_CLASS_NAME then
                local giftOwner = parentGift:GetOwner()

                if IsValid(giftOwner) then
                    if giftOwner:GetActiveWeapon() == parentGift then
                        local attachmentID = utils.GetRHAttachmentID(giftOwner)

                        if attachmentID then
                            local attachment = giftOwner:GetAttachment(attachmentID)
                            local offset = Vector(0, -7, 1)
                            viewPos = attachment.Pos + attachment.Ang:Forward() * offset.x + attachment.Ang:Right() * offset.y + attachment.Ang:Up() * offset.z
                        end

                    else -- in the pocket
                        local pelvis = giftOwner:LookupBone("ValveBiped.Bip01_Pelvis")

                        if pelvis then
                            local bonePos, boneAng = giftOwner:GetBonePosition(pelvis)
                            viewPos = bonePos + boneAng:Forward() * -15
                        end
                    end
                end
            end

            return { origin = viewPos, znear = 1 }
        end
    end)
end

dbg.Log("(prop) Initialized gift entity Lua")