include("sh_giftwrap_utils.lua")
local utils = GW_Utils
local dbg   = GW_DBG

HIDE_MARK_MSG   = "TTT_GiftWrapSV_HideMark"
UNHIDE_MARK_MSG = "TTT_GiftWrapSV_UnHideMark"

GW_DBG.Red   = Color(255, 50, 50)
GW_DBG.Green = Color(50, 255, 50)
GW_DBG.Blue  = Color(50, 50, 255)

if SERVER then
    function GW_DBG.GoToGift(i) -- meant for local testing
        local gifts = ents.FindByClass(PROP_CLASS_NAME)
        PrintTable(gifts)

        if i ~= nil then
            player.GetAll()[1]:SetPos(gifts[i]:GetPos())
        end
    end

    function GW_DBG.NearbyEnts(radius, pattern, showTable) -- meant for local testing
        for _, ent in ipairs(ents.FindInSphere(player.GetAll()[1]:GetPos(), radius)) do
            local class = ent:GetClass()

            if not pattern or string.find(class, pattern, nil, true) then
                print(ent, ent:GetPos(), ent:GetModel())
                debugoverlay.Sphere(ent:GetPos(), 50, 7, GW_DBG.Red)

                if showTable then PrintTable(ent:GetSaveTable(true)) end
            end
        end
    end

    function GW_DBG.ShowNearbySpawns(radius, searchScale, life) --meant for local testing
        if not GW_DBG.Cvar:GetBool() or not radius then return end
        local cols = {GW_DBG.Red, GW_DBG.Green, GW_DBG.Blue}

        local plyPos = player.GetAll()[1]:GetPos()
        for _, spawn in ipairs(GW_Utils.NearestSpawns(plyPos, radius * searchScale)) do
            debugoverlay.Sphere(spawn.pos, radius, life, cols[spawn.grp])
        end
    end

    function GW_DBG.ShowSpawns(spawns, radius, life) --meant for local testing
        if not GW_DBG.Cvar:GetBool() or not radius then return end
        local cols = {GW_DBG.Red, GW_DBG.Green, GW_DBG.Blue}

        for _, spawn in ipairs(spawns) do
            debugoverlay.Sphere(spawn.pos, radius, life, cols[spawn.grp])
        end
    end

    function GW_DBG.DebugSpawns(giftEnt, radius, verbose) --meant for local testing, in ENT:Think()
        if not GW_DBG.Cvar:GetBool() then return end
        if ents.FindByClass("prop_giftwrap_gift")[1] ~= giftEnt then return end

        local plyPos = player.GetAll()[1]:GetPos()
        GW_DBG.ShowSpawns({GW_Utils.NearestSpawn(plyPos, false)}, 10, 0.2)

        if radius then
            local spacing = 100
            local half = 3

            for x = -half, half do
                for y = -half, half do
                    for z = -half, half do
                        local point = plyPos + Vector(x * spacing, y * spacing, z * spacing)

                        if not GW_Utils.IsNearAnySpawn(point, radius) then
                            debugoverlay.Cross(point, 10, 1, GW_DBG.Red)
                        end
                    end
                end
            end
        end

        local zones = GW_Utils.mapSpawnStats.zones
        if zones then
            for _, zone in ipairs(zones) do
                local maxDist = 50000
                local col

                if zone.type == "exit" then
                    col = Color(255, 50, 50, 1)
                elseif zone.type == "troom" then
                    col = Color(255, 50, 255, 1)
                else
                    col = Color(50, 255, 50, 1)
                end

                -- Axis-aligned box
                if zone.min and zone.max then
                    local origin = (zone.min + zone.max) / 2

                    if plyPos:Distance(origin) <= maxDist then
                        debugoverlay.Box(
                            origin,
                            zone.min - origin,
                            zone.max - origin,
                            1,
                            col
                        )
                    end

                -- Arbitrary extruded quad
                elseif zone.c1 and zone.c2 and zone.c3 and zone.c4 and zone.height then
                    local center = (zone.c1 + zone.c2 + zone.c3 + zone.c4) / 4

                    if plyPos:Distance(center) <= maxDist then
                        local up = Vector(0, 0, zone.height)

                        local top1 = zone.c1 + up
                        local top2 = zone.c2 + up
                        local top3 = zone.c3 + up
                        local top4 = zone.c4 + up

                        -- Base
                        debugoverlay.Line(zone.c1, zone.c2, 1, col, false)
                        debugoverlay.Line(zone.c2, zone.c4, 1, col, false)
                        debugoverlay.Line(zone.c4, zone.c3, 1, col, false)
                        debugoverlay.Line(zone.c3, zone.c1, 1, col, false)

                        -- Top
                        debugoverlay.Line(top1, top2, 1, col, false)
                        debugoverlay.Line(top2, top4, 1, col, false)
                        debugoverlay.Line(top4, top3, 1, col, false)
                        debugoverlay.Line(top3, top1, 1, col, false)

                        -- Vertical edges
                        debugoverlay.Line(zone.c1, top1, 1, col, false)
                        debugoverlay.Line(zone.c2, top2, 1, col, false)
                        debugoverlay.Line(zone.c3, top3, 1, col, false)
                        debugoverlay.Line(zone.c4, top4, 1, col, false)

                        -- Bottom face
                        debugoverlay.Triangle(zone.c1, zone.c2, zone.c4, 1, col, true)
                        debugoverlay.Triangle(zone.c1, zone.c4, zone.c3, 1, col, true)

                        -- Top face
                        debugoverlay.Triangle(top1, top2, top4, 1, col, true)
                        debugoverlay.Triangle(top1, top4, top3, 1, col, true)

                        -- Side 1
                        debugoverlay.Triangle(zone.c1, zone.c2, top2, 1, col, true)
                        debugoverlay.Triangle(zone.c1, top2, top1, 1, col, true)

                        -- Side 2
                        debugoverlay.Triangle(zone.c2, zone.c4, top4, 1, col, true)
                        debugoverlay.Triangle(zone.c2, top4, top2, 1, col, true)

                        -- Side 3
                        debugoverlay.Triangle(zone.c4, zone.c3, top3, 1, col, true)
                        debugoverlay.Triangle(zone.c4, top3, top4, 1, col, true)

                        -- Side 4
                        debugoverlay.Triangle(zone.c3, zone.c1, top1, 1, col, true)
                        debugoverlay.Triangle(zone.c3, top1, top3, 1, col, true)
                    end
                end
            end
        end

        if verbose and radius then
            local giftPos = giftEnt:GetPos()
            GW_DBG.Log("gift near spawn: "..tostring(GW_Utils.IsNearAnySpawn(giftPos, radius)).." (rad:"..radius.."; zones: "..(zones and #zones or 0).."; "..game.GetMap().."); is in world "..tostring(util.IsInWorld(giftPos)).."; water level "..giftEnt:WaterLevel())
            GW_DBG.Log(math.Round(plyPos.x)..", "..math.Round(plyPos.y)..", "..math.Round(plyPos.z+20).." ; player near spawn: "..tostring(GW_Utils.IsNearAnySpawn(plyPos, radius)).."; is in world "..tostring(util.IsInWorld(plyPos)).."; zone "..tostring(utils.PointZone(plyPos)))
        end
    end

    function GW_DBG.DebugWraps(skipUnwrappables)
        local wrappables = {}
        local unwrappables = {}

        for _, ent in ipairs(ents.GetAll()) do
            local wrapConstraint = GetWrapConstraint(ent, player.GetAll()[1], true)

            if wrapConstraint then
                table.insert(unwrappables, {ent = ent, reason = wrapConstraint})
            else
                table.insert(wrappables, ent)
            end
        end

        print("WRAPPABLE ENTITIES")
        local hasDataCnt = 0
        local classCounts  = {}
        local modelSetSizeND = 0
        local modelSetND = {}
        local modelSetSizeWD = 0
        local modelSetWD = {}

        for _, ent in ipairs(wrappables) do
            local giftLabel, giftData = GetEntGiftData(ent, true)
            local class = ent:GetClass()

            if string.StartsWith(class, "weapon_") or class == "ttt_banana" then
                class = "weapons"
            elseif string.StartsWith(class, "item_ammo_") or class == "item_box_buckshot_ttt" then
                class = "ammo boxes"
            end
            classCounts[class] = (classCounts[class] or 0) + 1
            local model = ent:GetModel()

            if giftData and giftData.autoGen then
                print("-> Missing data:", ent, GW_DBG.PosStr(ent:GetPos()), model)
                debugoverlay.Sphere(ent:GetPos(), 50, 15, GW_DBG.Green)

                if not modelSetND[model] then
                    modelSetND[model] = true
                    modelSetSizeND = modelSetSizeND + 1
                end
            else
                hasDataCnt = hasDataCnt + 1

                if not modelSetWD[model] then
                    modelSetWD[model] = true
                    modelSetSizeWD = modelSetSizeWD + 1
                end
            end
        end
        print("Has data: "..hasDataCnt.."/"..#wrappables .." ("..(string.format("%.1f", 100 * hasDataCnt / math.max(#wrappables, 1))).."%)")
        print("Unique models: "..modelSetSizeWD.."/"..(modelSetSizeND + modelSetSizeWD).." have data ("..modelSetSizeND.." missing)")

        local uniqueClasses = {}
        for class, count in pairs(classCounts) do
            table.insert(uniqueClasses, {class = class, count = count})
        end

        table.sort(uniqueClasses, function(a, b)
            return a.count > b.count
        end)

        local classStrings = {}
        for _, v in ipairs(uniqueClasses) do
            table.insert(classStrings, v.count .. " " .. v.class)
        end
        print("Entity classes: " .. table.concat(classStrings, ", "))

        ---------------------------------------
        ---------------------------------------
        if skipUnwrappables then return end
        print("\nUNWRAPPABLE ENTITIES")
        local relevantCnt = 0

        for _, unwrappable in ipairs(unwrappables) do
            local ent = unwrappable.ent

            if IsValid(ent) and ent:GetSolid() > 0 and not ent:IsPlayer() and not ent:IsWeapon()
              and not utils.IsMapClass(ent) and not IsValid(ent:GetNW2Entity("WrappedByGift")) then
                print("-> Unwrappable:", ent, GW_DBG.PosStr(ent:GetPos()), unwrappable.reason, "solid "..ent:GetSolid())
                debugoverlay.Sphere(ent:GetPos(), 10, 5, GW_DBG.Red)
                relevantCnt = relevantCnt + 1
            end
        end

        print("Relevant unwrappables:", relevantCnt)
    end

    function GW_DBG.UnwrappableTour(t)
        if not t or t < 1 then t = 3 end
        local unwrappables = {}
        local ply = player.GetAll()[1]

        for _, ent in ipairs(ents.GetAll()) do
            local wrapConstraint = GetWrapConstraint(ent, player.GetAll()[1], true)

            if wrapConstraint and IsValid(ent) and ent:GetSolid() > 0 and not ent:IsPlayer()
              and not ent:IsWeapon() and not utils.IsMapClass(ent) and not IsValid(ent:GetNW2Entity("WrappedByGift")) then
                table.insert(unwrappables, {ent = ent, reason = wrapConstraint})
            end
        end

        print("Touring through "..#unwrappables.." entities...")
        if ply:GetMoveType() ~= MOVETYPE_NOCLIP then
            RunConsoleCommand("ulx", "noclip", ply:Nick())
        end

        local entCnt = 1
        local function TourStep()
            local entry = unwrappables[entCnt]

            if not entry then
                timer.Remove("GW-DBG_IterUnwrappables")
                print("Tour complete!")
                return
            end

            local ent = entry.ent
            GW_Utils.TpViewing(ply, ent, 100, -50)
            debugoverlay.Sphere(ent:GetPos(), 10, t-1, GW_DBG.Red)

            print("Entity "..entCnt.."/"..#unwrappables..": "..tostring(ent).." ("..unwrappables[entCnt].reason..")")
            entCnt = entCnt + 1
        end

        TourStep()
        timer.Remove("GW-DBG_IterUnwrappables")
        timer.Create("GW-DBG_IterUnwrappables", t, 0, TourStep)
    end

    function GW_DBG.EndTour()
        timer.Remove("GW-DBG_IterUnwrappables")
        print("Tour cancelled.")
    end

    function GW_DBG.MyPos()
        GW_DBG.Log(GW_DBG.PosStr(player.GetAll()[1]:GetPos() + Vector(0, 0, 20)))
    end

    function GW_DBG.PosStr(pos)
        return math.Round(pos.x)..", "..math.Round(pos.y)..", "..math.Round(pos.z)
    end

    function GW_DBG.GoToEnt(entID)
        player.GetAll()[1]:SetPos(ents.GetByIndex(entID):GetPos())
    end
end



-----------------------------------------------------
--------------------- Utils -------------------------
-----------------------------------------------------

if SERVER then
    util.AddNetworkString(HIDE_MARK_MSG)
    util.AddNetworkString(UNHIDE_MARK_MSG)

    function GW_Utils.GetEntCenter(ent)
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            local mins, maxs = phys:GetAABB()
            return phys:LocalToWorld((mins + maxs) * 0.5) + Vector(0, 0, 10)
        end

        -- fallback (other centering methods are way off for my gift, fucked bbox)
        return ent:GetPos()
    end

    function GW_Utils.GetGroundHit(pos, filterEnt)
        return util.TraceLine({
            start  = pos + Vector(0, 0, 100),
            endpos = pos - Vector(0,0,1000),
            filter = filterEnt,
            mask   = MASK_NPCWORLDSTATIC,
        })
    end

    function GW_Utils.FindViewablePos(targetPos, radius, incRad)
        if not radius then radius = 100 end
        if not incRad then incRad = math.pi/8 end

        local trueRad = math.sqrt(2) * radius
        local startAng = math.random(0, 2 * math.pi)

        for ang = 0, 2 * math.pi, incRad do
            local x = trueRad * math.cos(startAng + ang)
            local y = trueRad * math.sin(startAng + ang)

            local pos = targetPos + Vector(x, y)
            local tr = util.TraceLine({
                start = targetPos,
                endpos = pos,
                mask = MASK_PLAYERSOLID_BRUSHONLY
            })

            if tr.Fraction >= 1 and util.IsInWorld(pos) then
                return pos
            end
        end

        return targetPos + Vector(100, 100, 0)
    end

    function GW_Utils.TpViewing(ply, targetEnt, radius, zOff)
        local entPos = targetEnt:GetPos()
        local pos = GW_Utils.FindViewablePos(entPos, radius)
        local ang = (entPos - pos):Angle()
        ply:SetPos(pos + Vector(0, 0, zOff or 0))
        ply:SetEyeAngles(ang)
    end

    function GW_Utils.GetRandomUpwardsVel(raise)
        local dir = VectorRand()
        dir.z = math.abs(dir.z + raise)
        return dir:GetNormalized()
    end

    function GW_Utils.ColorFromString(str)
        local r, g, b, a = str:match("(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
        return Color(tonumber(r), tonumber(g), tonumber(b), tonumber(a))
    end

    function GW_Utils.EnterStasis(giftObj, ent)
        ent:SetNoDraw(true)
        ent:SetNotSolid(true)

        ent:SetNW2Entity("WrappedByGift", giftObj)
        ent._GWStoredPos = ent:GetPos()
        ent._GWStoredColGroup = ent:GetCollisionGroup()
        ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        local minPos, maxPos = game.GetWorld():GetModelBounds()
        ent:SetPos(maxPos)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
            phys:SetPos(maxPos)
            ent:SetNWBool("GWPhysStasis", true)
        end

        -- otherwise clients may see old position for a frame or so
        -- (really should not need to do this tbh)
        net.Start(TP_GIFT_MSG)
        net.WriteEntity(ent)
        net.WriteVector(maxPos)
        net.Broadcast()

        -- hide connected map ropes so stasis pos doesn't show
        -- (other types may still be broken, will fix as I find them)
        for _, rope in ipairs(GW_Utils.FindConnectedRopes(ent)) do
            rope._storedWidth = rope:GetKeyValues()["Width"]
            rope:SetKeyValue("Width", "0")
        end

        -- hide & store connected sprite trails
        ent._childTrails = {}

        for _, child in ipairs(ent:GetChildren()) do
            if child:GetClass() == "env_spritetrail" then
                table.insert(ent._childTrails, {
                    trailEnt   = child,
                    attachID   = child:GetInternalVariable("m_iParentAttachment"),
                    color      = GW_Utils.ColorFromString(child:GetInternalVariable("rendercolor")),
                    additive   = true,
                    startWidth = child:GetInternalVariable("startwidth"),
                    endWidth   = child:GetInternalVariable("endwidth"),
                    lifetime   = child:GetInternalVariable("lifetime"),
                    textureRes = child:GetInternalVariable("m_flTextureRes"),
                    texture    = child:GetInternalVariable("model"),
                })
                child:SetNoDraw(true)

            elseif child:IsPlayer() then
                child:ChatPrint("Your vehicle has been wrapped!")
                child:SetNoDraw(true)

                timer.Simple(2.5, function()
                    if IsValid(child) then
                        child:ChatPrint("NOTE: You can free yourself from the giftbox by exiting the vehicle.")
                    end
                end)
            end
        end

        -- store data for connected physics objects
        if ent:IsRagdoll() then
            GW_Utils.PrepareRagdoll(ent, ent._GWStoredPos)

        elseif ent:IsNPC() then -- freeze NPC
            ent._GWStoredNPCState = ent:GetNPCState()
            ent._GWStoredSchedule = ent:GetCurrentSchedule()
            ent:SetNPCState(NPC_STATE_NONE)
            ent:SetSchedule(SCHED_NPC_FREEZE)
        end

        -- hide all markervisions client-side
        net.Start(HIDE_MARK_MSG)
        net.WriteEntity(ent)
        net.Broadcast()
    end

    function GW_Utils.PrepareRagdoll(rag, rootPos)
        if not rootPos then rootPos = rag:GetPos() end
        rag._GWStoredRelPos = {}

        rag:Fire("DisableMotion")
        constraint.RemoveConstraints(rag, "Rope") -- break magneto pin rope

        -- remove map phys_ragdollconstraint
        -- only known case is a kleiner on 67th way, if this breaks any map
        -- then we should simply prevent wrapping these instead!
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent:GetClass() == "phys_ragdollconstraint" then
                local ent1, ent2 = ent:GetConstrainedEntities()

                if ent1 == rag or ent2 == rag then
                    ent:Remove()
                end
            end
        end

        for i = 1, rag:GetPhysicsObjectCount() - 1 do
            local phys = rag:GetPhysicsObjectNum(i)

            if IsValid(phys) then
                rag._GWStoredRelPos[phys] = phys:GetPos() - rootPos
                phys:EnableMotion(false)
                phys:Sleep()
            end
        end
    end

    function GW_Utils.ExitStasis(ent, pos, stabilize)
        ent:SetPos(pos)
        ent:SetNoDraw(false)
        ent:SetNotSolid(false)

        ent:SetNW2Entity("WrappedByGift", nil)
        if ent._GWStoredColGroup then
            ent:SetCollisionGroup(ent._GWStoredColGroup)
        end

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetPos(pos)

            -- give things with move children a few extra ticks to propagate their new position
            -- before restarting physics (otherwise things like vehicles go flying off randomly)
            timer.Simple(stabilize and 0.25 or 0, function()
                ent:SetNWBool("GWPhysStasis", false)

                if IsValid(phys) and not ent._DontWake then
                    phys:EnableMotion(true)
                    phys:Wake()
                end
            end)
        end

        -- otherwise clients may see old position for a frame or so
        -- (really should not need to do this tbh)
        net.Start(TP_GIFT_MSG)
        net.WriteEntity(ent)
        net.WriteVector(pos)
        net.Broadcast()

        -- unhide connected ropes
        for _, rope in ipairs(GW_Utils.FindConnectedRopes(ent)) do
            if rope._storedWidth then
                rope:SetKeyValue("Width", tostring(rope._storedWidth))
            end
        end

        -- recreate connected sprite trails
        if ent._childTrails then
            for _, t in ipairs(ent._childTrails) do
                if IsValid(t.trailEnt) then t.trailEnt:Remove() end
                util.SpriteTrail(ent, t.attachID, t.color, t.additive, t.startWidth, t.endWidth, t.lifetime, t.textureRes, t.texture)
            end
        end

        -- move connected physics objects (used for ragdolls)
        ent:Fire("EnableMotion")
        if ent._GWStoredRelPos then
            for phys, relPos in pairs(ent._GWStoredRelPos) do
                if IsValid(phys) then
                    phys:SetPos(pos + relPos)
                end
            end
        end

        -- restore NPC schedule/state
        if ent:IsNPC() and ent._GWStoredSchedule then
            ent:SetSchedule(ent._GWStoredSchedule)
            ent:SetNPCState(ent._GWStoredNPCState)
        end

        -- unhide all markervisions client-side
        net.Start(UNHIDE_MARK_MSG)
        net.WriteEntity(ent)
        net.Broadcast()

        -- notify conected players
        for _, child in ipairs(ent:GetChildren()) do
            if child:IsPlayer() then
                child:ChatPrint("Your vehicle was unwrapped!")
                child:SetNoDraw(false)
            end
        end
    end

    function GW_Utils.FindConnectedRopes(ent)
        local ropes = {}

        local worldRopes = {}
        for _, e in ipairs(ents.GetAll()) do
            local c = e:GetClass()

            if c == "keyframe_rope" or c == "move_rope" then
                table.insert(worldRopes, e) -- equivalent types as per the source docs
            end
        end

        -- there's probably a better way to do this...
        for _, rope in ipairs(worldRopes) do
            if rope:GetParent() == ent then
                table.insert(ropes, rope)

                -- find connected endpoint
                for _, endPt in ipairs(worldRopes) do
                    if endPt:GetInternalVariable("m_hEndPoint") == rope then
                        table.insert(ropes, endPt)
                    end
                end
            end
        end

        return ropes
    end

    function GW_Utils.GetMapSpawns(filterWep, filterAmmo, filterPlayer, filterWater)
        local mapSpawns = entspawnscript.GetSpawns()
        local spawns = {}
        local filters = {filterWep, filterAmmo, filterPlayer }

        for i, spawnType in pairs(mapSpawns) do
            if not filters[i] then
                for _, spawnEntType in pairs(spawnType) do
                    for _, spawn in pairs(spawnEntType) do
                        local spawnPos = Vector(spawn.pos.x, spawn.pos.y, spawn.pos.z - 20)

                        if not (filterWater and bit.band(util.PointContents(spawnPos), CONTENTS_WATER) > 0) then
                            table.insert(spawns, {pos = spawnPos, grp = i})
                        end
                    end
                end
            end
        end

        return spawns
    end

    local function InitMapSpawns()
        print("[GiftWrap] Initialized map spawns list")
        GW_AllMapSpawns       = GW_Utils.GetMapSpawns()
        GW_AllNonWaterSpawns  = GW_Utils.GetMapSpawns(false, false, false, true)
        GW_WebAmmoSpawns      = GW_Utils.GetMapSpawns(false, false, true)
    end

    hook.Add("TTTInitPostEntity", "GiftWrap_FindSpawnsHook", function()
        timer.Simple(0, InitMapSpawns) -- let entspawnscript finish
    end)

    function GW_Utils.IsNearAnySpawn(pos, spawnRad)
        local radSqr = spawnRad * spawnRad

        for _, spawn in ipairs(GW_AllNonWaterSpawns) do
            if pos.z >= spawn.pos.z and pos:DistToSqr(spawn.pos) <= radSqr then
                return true
            end
        end

        return false
    end

    function GW_Utils.NearestSpawns(pos, radius)
        local nearSpawns = {}
        local radSqr = radius * radius

        for _, spawn in ipairs(GW_AllNonWaterSpawns) do
            if pos:DistToSqr(spawn.pos) <= radSqr then
                table.insert(nearSpawns, spawn)
            end
        end

        return nearSpawns
    end

    function GW_Utils.NearestSpawn(pos, verbose)
        local nearestSpawn
        local lowestDist = 9999999999

        for _, spawn in ipairs(GW_AllNonWaterSpawns) do
            local dist = pos:DistToSqr(spawn.pos)
            local zone = GW_Utils.PointZone(spawn.pos + Vector(0, 0, 15), verbose)

            if dist < lowestDist and not zone or zone == "safe" then
                lowestDist = dist
                nearestSpawn = spawn
            end
        end

        if verbose then GW_DBG.Log("Nearest spawn to", pos, "is", nearestSpawn.pos) end
        return nearestSpawn
    end

    function GW_Utils.IsPointInZone(pos, zone)
        -- AABB zone
        if zone.min and zone.max then
            local mins = Vector(
                math.min(zone.min.x, zone.max.x),
                math.min(zone.min.y, zone.max.y),
                math.min(zone.min.z, zone.max.z)
            )

            local maxs = Vector(
                math.max(zone.min.x, zone.max.x),
                math.max(zone.min.y, zone.max.y),
                math.max(zone.min.z, zone.max.z)
            )

            return pos.x >= mins.x and pos.x <= maxs.x
               and pos.y >= mins.y and pos.y <= maxs.y
               and pos.z >= mins.z and pos.z <= maxs.z
        end

        -- Quad extrusion
        if zone.c1 and zone.c2 and zone.c3 and zone.c4 and zone.height then
            local function PointInTri2D(p, a, b, c)
                local function Sign(p1, p2, p3)
                    return (p1.x - p3.x) * (p2.y - p3.y)
                         - (p2.x - p3.x) * (p1.y - p3.y)
                end

                local d1 = Sign(p, a, b)
                local d2 = Sign(p, b, c)
                local d3 = Sign(p, c, a)

                local hasNeg = (d1 < 0) or (d2 < 0) or (d3 < 0)
                local hasPos = (d1 > 0) or (d2 > 0) or (d3 > 0)

                return not (hasNeg and hasPos)
            end

            local function PlaneZ(x, y, a, b, c)
                local normal = (b - a):Cross(c - a)

                if math.abs(normal.z) < 0.001 then
                    return a.z
                end

                return a.z - (normal.x * (x - a.x) + normal.y * (y - a.y)) / normal.z
            end

            local baseZ

            if PointInTri2D(pos, zone.c1, zone.c2, zone.c4) then
                baseZ = PlaneZ(pos.x, pos.y, zone.c1, zone.c2, zone.c4)
            elseif PointInTri2D(pos, zone.c1, zone.c4, zone.c3) then
                baseZ = PlaneZ(pos.x, pos.y, zone.c1, zone.c4, zone.c3)
            else
                return false
            end

            return pos.z >= baseZ and pos.z <= baseZ + zone.height
        end

        return false
    end

    function GW_Utils.PointZone(pos)
        if not GW_Utils.mapSpawnStats.zones then return false end
        local foundZone
        local foundZoneBounce = false

        for _, zone in ipairs(GW_Utils.mapSpawnStats.zones) do
            if GW_Utils.IsPointInZone(pos, zone) then
                if zone.type == "troom" then
                    return zone.type, zone.bounce ~= false -- troom > safe > others

                elseif zone.type == "safe" or not foundZone then
                    foundZone = zone
                    foundZoneBounce = (zone.type == "exit" or zone.type == "troom") and zone.bounce ~= false
                end
            end
        end

        return foundZone and foundZone.type or false, foundZoneBounce
    end

    GW_Utils.mapSpawnStatsList = {
        ["ttt_5c_plaza"]                = { radius=1000, timeout=3,  zones = {
            { min = Vector(-2932, 837, -50), max = Vector(1322, 1305, 732),   type="exit" },
            { min = Vector(-2256, -1679, 4), max = Vector(-2128, -1535, 134), type="troom" },
            { min = Vector(54, -1244, 10),   max = Vector(161, -1038, 100),   type="troom" },
        }},
        ["ttt_67thway_v7"]              = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1284, -642, -454), max = Vector(-1154, -139, -324), type="troom" },
            { min = Vector(-1538, -262, -454), max = Vector(-909, 505, -324),   type="troom" },
            { min = Vector(-2180, -262, -454), max = Vector(-1538, 646, -324),  type="troom" },
        }},
        ["ttt_beachbar"]                = { radius=1000, timeout=3,  zones = {
            { min = Vector(-847, 2546, 378), max = Vector(-555, 2916, 515), type="troom" },
        }},
        ["ttt_annex"]                   = { radius=1000, timeout=3 },
        ["ttt_bestbuy"]                 = { radius=nil },
        ["ttt_ca_oilrig"]               = { radius=800,  timeout=3,  waterExit=true },
        ["ttt_canyon_labs"]             = { radius=1000, timeout=3 },
        ["ttt_casino_b2"]               = { radius=1000, timeout=3,  zones = {
            { min = Vector(1660, -956, -412), max = Vector(1700, -1007, -317), type="exit", bounce=false },
            { min = Vector(556, 1582, -400),  max = Vector(485, 1640, -300),   type="exit", bounce=false },
        }},
        ["ttt_castle"]                  = { radius=1000, timeout=5,  waterExit=true },
        --["ttt_charnel"]                 = { radius=1000, timeout=3,  zones = {
        --    { min = Vector(3409, -1007, 31), max = Vector(4078, -1689, 454), type="troom" }, --open to all once opened
        --}},
        ["ttt_christmas_bowling"]       = { radius=1000, timeout=3,  zones = {
            { min = Vector(830, 1743, 97),    max = Vector(1463, 2016, 294),   type="troom" },
            { min = Vector(-1477, -1601, 25), max = Vector(-716, -1455, 200),  type="troom" },
            { min = Vector(-1344, -1455, 25), max = Vector(-1197, -1305, 200), type="troom" },
            { min = Vector(-985, -1455, 25),  max = Vector(-834, -1305, 200),  type="troom" },
        }},
        ["ttt_clue_2018"]               = { radius=1000, timeout=10, zones = {
            { min = Vector(-143, -1306, -74), max = Vector(379, -680, 858), type="exit" },
        }},
        ["ttt_cobertura"]               = { radius=2000, timeout=3 },
        ["ttt_cottage"]                 = { radius=nil,  timeout=3,  zones = {
            { min = Vector(-536, -1437, -130), max = Vector(-330, -1360, 20), type="troom" },
        }, waterExit=true },
        ["ttt_cozy_cove"]               = { radius=nil,  timeout=15, waterExit=true },
        ["ttt_deepsea"]                 = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1539, 1996, 330), max = Vector(-1245, 2189, 507), type="troom" },
            { min = Vector(354, 4095, 330),   max = Vector(642, 4295, 494),   type="troom" },
        }},
        ["ttt_diescraper"]              = { radius=400,  timeout=3 },
        ["ttt_dog"]                     = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1780, -832, -136), max = Vector(-1392, -416, 0),   type="exit", bounce=false },
            { min = Vector(-64, -609, 330),    max = Vector(704, 192, 600),    type="exit" },
            { min = Vector(-1780, 116, 576),   max = Vector(-1480, 416, 750),  type="exit" },
            { min = Vector(-1780, -832, 260),  max = Vector(-1580, -664, 400), type="exit" },
            { min = Vector(1072, 48, 152),     max = Vector(1496, 416, 320),   type="exit" },
            { min = Vector(1232, 208, 0),      max = Vector(1496, 416, 152),   type="exit" },
            { min = Vector(-460, -477, -550),  max = Vector(1201, 387, -347),  type="safe" },
            { min = Vector(-524, -340, -176),  max = Vector(-288, 0, -52),     type="troom" },
            { min = Vector(-1768, 116, 132),   max = Vector(-1480, 404, 564),  type="troom" },
        }},
        ["ttt_emerald_empire"]          = { radius=1000, timeout=10, zones = {
            { min = Vector(1000, -2681, 880), max = Vector(1544, -1902, 1122), type="exit" },
        }},
        ["ttt_escher"]                  = { radius=1000, timeout=3 },
        ["ttt_fernwood_b1"]             = { radius=1000, timeout=3,  zones = {
            { min = Vector(-945, 1214, -107), max = Vector(-777, 1456, 75),   type="troom" },
            { min = Vector(-909, 1700, -373), max = Vector(-291, 2008, -200), type="troom" },
        }},
        ["ttt_forestpath_winter"]       = { radius=1100, timeout=5,  waterExit=true },
        ["ttt_fort_pvk"]                = { radius=1000, timeout=3,  waterExit=true },
        ["ttt_frg_angles"]              = { radius=2000, timeout=3 },
        ["ttt_frg_the_blue_wall"]       = { radius=nil,  timeout=3,  zones = {
            { min = Vector(-10, 2440, 1117), max = Vector(135, 2593, 1600), type="troom" },
            { min = Vector(-56, 2593, 1420), max = Vector(181, 2941, 1600), type="troom" },
        }},
        ["ttt_goldenplixprison"]        = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1016, 653, -21),  max = Vector(-776, 1013, 140),  type="troom" },
            { min = Vector(-934, -900, 400),  max = Vector(1178, -236, 730),  type="troom" },
            { min = Vector(-2563, 1523, 203), max = Vector(-2130, 1902, 376), type="exit" },
            { min = Vector(-2563, 1791, 376), max = Vector(-1534, 2434, 594), type="exit" },
            { type="exit", height = 218, c1 = Vector(-1793, 1791, 376), c2 = Vector(-2130, 1791, 376), c3 = Vector(-1793, 1523, 203), c4 = Vector(-2130, 1523, 203)},
        }},
        ["ttt_gsf_apartments"]          = { radius=1000, timeout=3 },
        ["ttt_gsf_topztower"]           = { radius=1000, timeout=3 },
        ["ttt_happyhome"]               = { radius=1150, timeout=1,  zones = {
            { min = Vector(-1953, 77, 800), max = Vector(-283, 1567, 1603), type="exit" },
            { min = Vector(-1536, 77, 800), max = Vector(-283, 1152, 931),  type="safe" },
            { min = Vector(992, 48, 407),   max = Vector(1168, 382, 800),   type="exit" },
            { min = Vector(-12, -209, 136), max = Vector(528, -140, 280),   type="troom" },
            { type="troom", height = 144, c1 = Vector(528, -209, 136), c2 = Vector(528, -140, 136), c3 = Vector(896, -81, 136), c4 = Vector(896, -11, 136)},
            { type="troom", height = 144, c1 = Vector(896, -81, 136),  c2 = Vector(896, -11, 136),  c3 = Vector(1090, 49, 136), c4 = Vector(992, 53, 136)},
            { min = Vector(1050, 544, 136), max = Vector(1128, 1250, 280),  type="troom" },
            { type="troom", height = 144, c1 = Vector(1050, 1523, 136), c2 = Vector(1128, 1523, 136), c3 = Vector(1054, 1664, 136),  c4 = Vector(1123, 1729, 136)},
            { type="troom", height = 144, c1 = Vector(1054, 1664, 136), c2 = Vector(1123, 1729, 136), c3 = Vector(894, 1820, 136),   c4 = Vector(961, 1892, 136)},
            { type="troom", height = 144, c1 = Vector(894, 1820, 136),  c2 = Vector(961, 1892, 136),  c3 = Vector(-1102, 1815, 136), c4 = Vector(-1102, 1891, 136)},
            { min = Vector(-1541, -112, 136), max = Vector(-1431, 529, 280), type="troom" },
            { type="troom", height = 144, c1 = Vector(-1541, -112, 136), c2 = Vector(-1431, -112, 136), c3 = Vector(-1444, -219, 136), c4 = Vector(-1407, -141, 136)},
            { type="troom", height = 144, c1 = Vector(-1444, -219, 136), c2 = Vector(-1407, -141, 136), c3 = Vector(-499, -219, 136),  c4 = Vector(-499, -141, 136)},
        }},
        ["ttt_hijacked_v1"]             = { radius=1000, timeout=3, zones = {
            { min = Vector(-1732, -460, 129),  max = Vector(-1406, 493, 263), type="exit" },
            { min = Vector(-2265, -430, -190), max = Vector(-1710, 430, 0),   type="safe" },
            { min = Vector(1788, 140, 178),    max = Vector(2129, 315, 308),  type="troom" },
            { min = Vector(-154, -89, 133),    max = Vector(77, 360, 308),    type="troom" },
            { min = Vector(411, 28, -127),     max = Vector(615, 162, 5),     type="troom" },
        }},
        ["ttt_hotwireslum2026"]         = { radius=1000, timeout=3,  zones = {
            { min = Vector(1692, 516, 0), max = Vector(1942, 903, 144), type="exit" },
        }},
        ["ttt_homie_hangout"]           = { radius=1000, timeout=3,  zones = {
            { min = Vector(490, -161, -12),   max = Vector(835, 194, 154),  type="troom" },
            { min = Vector(-200, -613, -340), max = Vector(21, -399, -127), type="troom" },
        }},
        ["ttt_innocentmotel"]           = { radius=1000, timeout=3,  zones = {
            { min = Vector(-448, 750, -250), max = Vector(-250, 950, -70),  type="exit", bounce=false },
            { min = Vector(536, 314, 0),     max = Vector(667, 847, 130),   type="exit" },
            { min = Vector(-404, -1844, 90), max = Vector(-92, -1590, 239), type="troom" },
            { min = Vector(-1227, 1016, 88), max = Vector(-970, 1284, 229), type="troom" },
            { min = Vector(-219, 340, 350),  max = Vector(200, 768, 470),   type="troom" },
            { min = Vector(124, 505, 129),   max = Vector(200, 578, 350),   type="troom" },
            { min = Vector(-541, 287, -226), max = Vector(515, 401, -18),   type="troom" },
            { min = Vector(-541, 97, -226),  max = Vector(-320, 287, -18),  type="troom" },
            { min = Vector(260, -197, -226), max = Vector(515, 287, -18),   type="troom" },
        }},
        ["ttt_intergalactic"]           = { radius=1000, timeout=5 },
        ["ttt_island_2024"]             = { radius=1200, timeout=15, zones = {
            { min = Vector(-4497, -4157, 1080), max = Vector(-3867, -3165, 1390), type="troom" },
        }, waterExit=true },
        ["ttt_islandstreets"]           = { radius=1000, timeout=15, waterExit=true },
        ["ttt_juniperlodge"]            = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1636, -1690, 0), max = Vector(-1131, -1309, 155), type="troom" },
            { min = Vector(828, -1150, 145), max = Vector(1120, -953, 285),   type="troom" },
        }},
        ["ttt_kakariko"]            = { radius=1500, timeout=10, zones = {
            { min = Vector(-2800, -330, 0),   max = Vector(-2180, -1500, 500), type="exit" },
            { min = Vector(-633, 1268, -390), max = Vector(718, 3030, -165),   type="troom" },
        }},
        ["ttt_kappukeki_streets"]       = { radius=1000, timeout=10, zones = {
            { min = Vector(315, -400, 400),   max = Vector(800, 325, 800),    type="exit" },
            { min = Vector(-940, 1290, -300), max = Vector(-1660, 1580, 0),   type="safe" },
            { min = Vector(-660, 255, -360),  max = Vector(-990, 1770, -120), type="safe" },
        }, waterExit=true },
        ["ttt_lighthouse"]              = { radius=1000, timeout=15, waterExit=true },
        ["ttt_lockout"]                 = { radius=1000, timeout=3 },
        ["ttt_magma"]                   = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1615, 114, -400),  max = Vector(-1152, 640, -63), type="exit", bounce=false },
            { min = Vector(-728, -1066, -577), max = Vector(99, -511, -135),  type="exit", bounce=false },
            { min = Vector(-1404, -579, 177),  max = Vector(-909, -375, 315), type="troom" },
            { min = Vector(-1026, -375, 50),   max = Vector(-799, 597, 315),  type="troom" },
        }},
        ["ttt_magma_gs"]                = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1635, 110, -500),  max = Vector(-1157, 634, -49), type="exit", bounce=false },
            { min = Vector(-724, -1044, -543), max = Vector(78, -565, -140),  type="exit", bounce=false },
        }},
        ["ttt_mc_summercamp"]           = { radius=nil,  timeout=3,  zones = {
            { min = Vector(-944, -784, -202),  max = Vector(-816, 216, -5),  type="troom" },
            { min = Vector(944, 224, -210),    max = Vector(817, 541, -5),   type="troom" },
            { min = Vector(-183, -1146, -207), max = Vector(-138, -664, -5), type="troom" },
        }},
        ["ttt_minecraft_b5"] = { radius=1000, timeout=3, zones = {
            { min = Vector(-1775, -1841, -3355), max = Vector(239, 163, -3270),   type="exit", bounce=false },
            { min = Vector(510, -642, 262),      max = Vector(674, -479, 408),    type="exit", bounce=false },
            { min = Vector(-71, -1032, 18),      max = Vector(99, -832, 57),      type="exit", bounce=false },
            { min = Vector(477, -481, 417),      max = Vector(521, -414, 447),    type="exit", bounce=false },
            { min = Vector(-352, -96, -64),      max = Vector(-128, 160, 32),     type="exit", bounce=false },
            { min = Vector(-2083, 413, -225),    max = Vector(-1851, 895, -33),   type="troom" },
            { min = Vector(-927.9, -160.1, -70), max = Vector(-832.5, -257, 287), type="troom" },
            { min = Vector(-927.9, -257, 30),    max = Vector(-769, -383.9, 287), type="troom" },
            { min = Vector(-927.9, -383.9, 30),  max = Vector(-833, -446, 159.9), type="troom" },
            { min = Vector(-927.9, -160.1, 88),  max = Vector(-896, -128, 129),   type="troom" },
        }, waterExit=true },
        ["ttt_minecraftcity"]        = { radius=1000, timeout=3,  zones = {
            { min = Vector(30, 416, 20),     max = Vector(179, 636, 130),   type="troom" },
            { min = Vector(-96, -1490, 24),  max = Vector(198, -1215, 150), type="troom" },
            { min = Vector(-228, -1425, -4), max = Vector(-126, -1307, 49), type="exit", bounce=false },
        }},
        ["ttt_missile_isles"]           = { radius=1000, timeout=6,  zones = {
            { min = Vector(1833, 1312, 110),   max = Vector(2519, 2012, 433),   type="safe" },
            { min = Vector(1289, -289, 92),    max = Vector(1588, 9, 326),      type="nospawn" },
            { min = Vector(-1491, -1406, 202), max = Vector(-1932, -1090, 390), type="troom" },
            { min = Vector(-1737, -600, -357), max = Vector(-326, -2190, -290), type="safe" },
        }},
        ["ttt_mttresort"]               = { radius=1000, timeout=3,  zones = {
            { min = Vector(-448, -566, -246), max = Vector(-335, -186, -90), type = "troom" },
        }},
        ["ttt_mw2_terminal"]            = { radius=nil },
        ["ttt_oldruins"]                = { radius=nil,  timeout=3,  waterExit=true },
        ["ttt_orange_v7"]               = { radius=1500, timeout=3,  zones = {
            { min = Vector(399, -273, -8),    max = Vector(510, -85, 127.9),  type = "troom" },
            { min = Vector(446, -323, -8),    max = Vector(636, -199, 127.9), type = "troom" },
            { min = Vector(-424, -1149, 400), max = Vector(505, -272, 572),   type = "exit", bounce=false },
        }},
        ["ttt_panorama"]                = { radius=1000, timeout=3,  zones = {
            { min = Vector(-2588, 543, -100), max = Vector(-960, 1466, 300), type="safe" },
        }},
        ["ttt_paradise_resort"]         = { radius=1000, timeout=15 },
        ["ttt_pigisland_nightswim"]     = { radius=1000, timeout=5,  zones = {
            { min = Vector(-909, -1099, 245), max = Vector(-1825, 513, 950), type="safe" },
        }},
        ["ttt_pelicantown"]             = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1814, -512, -8), max = Vector(-1597, -291, 165), type="troom" },
            { min = Vector(956, 1595, -3),   max = Vector(1218, 1779, 100),  type="troom" },
            { min = Vector(1084, 1446, -3),  max = Vector(1218, 1595, 100),  type="troom" },
            { min = Vector(-94, 602, 258),   max = Vector(40, 344, 360),     type="troom" },
            { min = Vector(72, 536, 258),    max = Vector(40, 602, 360),     type="troom" },
        }},
        ["ttt_polylith"]                = { radius=1100, timeout=3,  zones = {
            { min = Vector(-66, 215, -358),     max = Vector(1151, 1180, 8),    type="safe" },
            { min = Vector(1152, -1152, -139),  max = Vector(1536, -640, 1408), type="exit" },
            { min = Vector(516, -1155, -3),     max = Vector(1025, -532, 401),  type="troom" },
            { min = Vector(-235, 1101, -64),    max = Vector(128, 1664, 258),   type="troom" },
            { min = Vector(-320, 1344, -64),    max = Vector(-235, 1472, 258),   type="troom" },
        }},
        ["ttt_poolparty"]               = { radius=1000, timeout=3,  zones = {
            { min = Vector(-531, 3152, 3),  max = Vector(-155, 3413, 260), type="exit" },
            { min = Vector(63, 1197, -110), max = Vector(2226, 3911, 10),  type="safe" },
            { min = Vector(1823, 3261, 98), max = Vector(2181, 3546, 257), type="troom" },
            { min = Vector(2210, 854, 5),   max = Vector(2565, 696, 390),  type="troom" },
            { type="troom", height = 350, c1 = Vector(2008, 696, 304), c2 = Vector(2008, 535, 304), c3 = Vector(2565, 696, 40), c4 = Vector(2565, 535, 40)},
            { min = Vector(1853, 535, 320), max = Vector(2008, 696, 561),  type="troom" },
            { type="troom", height = 241, c1 = Vector(1853, 696, 320), c2 = Vector(2008, 696, 320), c3 = Vector(1853, 856, 400), c4 = Vector(2008, 856, 400)},
            { min = Vector(1853, 856, 400), max = Vector(2548, 1313, 660), type="troom" },
        }},
        ["ttt_raifucu_maru"]            = { radius=1000, timeout=5,  waterExit=true },
        ["ttt_rooftops"]                = { radius=1000, timeout=3 },
        ["ttt_rotburg"]                 = { radius=1300, timeout=3,  zones = {
            { min = Vector(2016, 384, -100), max = Vector(992, 192, 162), type="exit", bounce=false },
        }},
        ["ttt_roy_the_ship"]            = { radius=nil,  timeout=5,  waterExit=true },
        ["ttt_rpgvillage"]              = { radius=nil,  timeout=5,  zones = {
            { min = Vector(1266, -3670, -1182), max = Vector(1925, -1817, -370), type="exit", bounce=false },
            { min = Vector(-1260, 8, -1300),    max = Vector(-946, 423, -728),   type="exit", bounce=false },
            { min = Vector(1360, 2163, -492),   max = Vector(1895, 2606, -277),  type="troom" },
            { min = Vector(-2047, -798, 113),   max = Vector(-1762, -353, 224),  type="troom" },
        }},
        ["ttt_sandscraper"]             = { radius=1000, timeout=3 },
        ["ttt_seliana"]                 = { radius=1000, timeout=5,  zones = {
            { min = Vector(1136, 1637, 551),  max = Vector(1369, 1764, 779),  type="nospawn" },
        }, waterExit=true },
        ["ttt_sewer_below"]             = { radius=1000, timeout=3,  zones = {
            { min = Vector(-643, 285, -250), max = Vector(-251, 870, -96), type="troom" },
            { min = Vector(-752, -481, -80), max = Vector(-646, -285, 33), type="troom" },
            { min = Vector(-377, 760, 200),  max = Vector(-54, 1007, 341), type="troom" },
        }},
        ["ttt_silenthill"]              = { radius=1000, timeout=3,  zones = {
            { min = Vector(-607, 4100, -19), max = Vector(-288, 4471, 130), type="troom" },
        }},
        ["ttt_simple_otat1"]            = { radius=1000, timeout=3 },
        ["ttt_skycraftfinal_dark"]      = { radius=1500, timeout=3,  zones = {
            { min = Vector(5065, -494, 2233),  max = Vector(5141, -420, 2330),  type = "exit", bounce=false },
            { min = Vector(1300, -1480, 440),  max = Vector(1400, -1360, 600),  type = "troom" }, -- t-room 1
            { min = Vector(1120, -1280, 600),  max = Vector(1440, -1480, 840),  type = "troom" },
            { min = Vector(1120, -1320, 600),  max = Vector(1080, -1480, 920),  type = "troom" },
            { min = Vector(1160, -1240, 640),  max = Vector(1320, -1280, 920),  type = "troom" },
            { min = Vector(1120, -1280, 840),  max = Vector(1280, -1480, 1240), type = "troom" },
            { min = Vector(1120, -1480, 600),  max = Vector(1360, -1520, 800),  type = "troom" },
            { min = Vector(1280, -1280, 840),  max = Vector(1360, -1480, 1040), type = "troom" },
            { min = Vector(1360, -1320, 840),  max = Vector(1400, -1440, 960),  type = "troom" },
            { min = Vector(1360, -1320, 960),  max = Vector(1400, -1360, 1040), type = "troom" },
            { min = Vector(1280, -1440, 1040), max = Vector(1360, -1280, 1080), type = "troom" },
            { min = Vector(1280, -1400, 1080), max = Vector(1360, -1280, 1120), type = "troom" },
            { min = Vector(1280, -1400, 1120), max = Vector(1320, -1320, 1200), type = "troom" },
            { min = Vector(1120, -1440, 1240), max = Vector(1280, -1280, 1320), type = "troom" },
            { min = Vector(3920, -520, 680),   max = Vector(3760, -120, 880),   type = "troom" }, -- t-room 2
            { min = Vector(3880, -480, 880),   max = Vector(3760, -320, 1080),  type = "troom" },
            { min = Vector(3880, -480, 880),   max = Vector(3840, -520, 920),   type = "troom" },
            { min = Vector(3760, -440, 680),   max = Vector(3720, -240, 920),   type = "troom" },
            { min = Vector(3760, -320, 1080),  max = Vector(3880, -480, 1120),  type = "troom" },
            { min = Vector(3760, -360, 1120),  max = Vector(3880, -480, 1160),  type = "troom" },
            { min = Vector(3760, -320, 1120),  max = Vector(3840, -280, 880),   type = "troom" },
            { min = Vector(3840, -440, 1160),  max = Vector(3800, -360, 1240),  type = "troom" },
            { min = Vector(4080, 0, 680),      max = Vector(3800, -120, 760),   type = "troom" },
            { min = Vector(4040, 0, 760),      max = Vector(3800, -120, 880),   type = "troom" },
            { min = Vector(3920, -120, 680),   max = Vector(4000, -280, 1040),  type = "troom" },
            { min = Vector(3920, -120, 880),   max = Vector(3760, -280, 1040),  type = "troom" },
            { min = Vector(3840, 0, 880),      max = Vector(4000, -120, 1040),  type = "troom" },
            { min = Vector(4000, 0, 1040),     max = Vector(3880, -200, 1360),  type = "troom" },
            { min = Vector(3880, -200, 1040),  max = Vector(4000, -240, 1160),  type = "troom" },
            { min = Vector(3880, -120, 1040),  max = Vector(3800, -280, 1160),  type = "troom" },
            { min = Vector(3880, -160, 1160),  max = Vector(3840, -200, 1200),  type = "troom" },
        }},
        ["ttt_skyscraper"]              = { radius=400,  timeout=3 },
        ["ttt_sm64_big_boos_haunt"]     = { radius=nil,  timeout=3,  zones = {
            { min = Vector(2322, -558, 714), max = Vector(2690, 192, 892),    type="troom" },
            { type="troom", height = 178, c1 = Vector(2690, 192, 714), c2 = Vector(2690, -558, 714), c3 = Vector(2322, 192, 1124), c4 = Vector(2322, -558, 1124)},
            { min = Vector(2322, -558, 892), max = Vector(2530.2, 192, 1124), type="troom" },
            { min = Vector(3206, 275, -950), max = Vector(2982, 446, -540),   type="troom" },
        }},
        ["ttt_smellysubway"]            = { radius=1000, timeout=3,  zones = {
            { min = Vector(830, -385, 320),   max = Vector(1056, 463, 521),  type="exit" },
            { min = Vector(1056, 184, 272),   max = Vector(1160, 392, 372),  type="exit" },
            { min = Vector(-1027, -514, -90), max = Vector(-868, 6, 65),     type="troom" },
            { min = Vector(866, -321, 135),   max = Vector(1055, -127, 260), type="troom" },
            { min = Vector(160, -108, -167),  max = Vector(281, 95, -35),    type="troom" },
        }, spnHeight = 50},
        ["ttt_smellysubway2"]           = { radius=1000, timeout=3,  zones = {
            { min = Vector(-634, 69, 0),     max = Vector(0, 444, 120),      type="troom" },
            { min = Vector(1607, 702, -331), max = Vector(1860, 1092, -190), type="troom" },
            { min = Vector(252, 559, -472),  max = Vector(573, 749, -330),   type="troom" },
        }},
        ["ttt_snowtown"]                = { radius=1500, timeout=10, zones = {
            { min = Vector(-3500, 52, -147), max = Vector(-2054, 2067, 752), type="safe" },
        }},
        ["ttt_solitude"]                = { radius=1000, timeout=3,  zones = {
            { min = Vector(-103, 260, 192), max = Vector(96, 457, 340), type="troom" },
            { type="troom", height = 148, c1 = Vector(60, 260, 192),     c2 = Vector(60, 170, 192),    c3 = Vector(-107.5, 260, 192), c4 = Vector(-70.5, 170, 192) },
            { type="troom", height = 148, c1 = Vector(-107.5, 260, 192), c2 = Vector(-70.5, 170, 192), c3 = Vector(-256, 106, 192),   c4 = Vector(-176, 73, 192) },
            { type="troom", height = 148, c1 = Vector(-256, 106, 192),   c2 = Vector(-176, 73, 192),   c3 = Vector(-256, 44, 192),    c4 = Vector(-176, 44, 192) },
        }},
        ["ttt_spacescraper"]            = { radius=400,  timeout=1 },
        ["ttt_submachine"]              = { radius=500,  timeout=5,  zones = {
            { min = Vector(192, -640, 640), max = Vector(544, -64, 750),  type="exit" },
            { min = Vector(544, -520, 608), max = Vector(744, -184, 750), type="exit" },
            { min = Vector(528, 576, 576),  max = Vector(1296, 64, 700),  type="exit" },
        }},
        ["ttt_subnet"]                  = { radius=nil,  timeout=3,  zones = {
            { min = Vector(548, -811, 1103),  max = Vector(1995, 378, 1700),  type="exit", bounce=false },
            { min = Vector(2656, -752, 1160), max = Vector(2896, -512, 1285), type="exit" },
            { min = Vector(441, 664, 350),    max = Vector(692, 991, 500),    type="exit" },
            { min = Vector(435, 360, 200),    max = Vector(558, 451, 450),    type="exit" },
            { min = Vector(575, -149, 200),   max = Vector(808, -70, 520),    type="exit" },
            { min = Vector(2624, -16, 304),   max = Vector(2752, 144, 384),   type="exit" },
            { min = Vector(2784, -416, 368),  max = Vector(2880, -736, 544),  type="exit" },
            { min = Vector(848, 528, 1571),   max = Vector(1440, 1136, 1700), type="exit" },
            { min = Vector(2474, -289, 330),  max = Vector(2571, -102, 532),  type="nospawn" },
            { min = Vector(956, 133, 243),    max = Vector(1213, 522, 437),   type="troom" },
            { min = Vector(431, 748, -250),   max = Vector(896, 912, -60),    type="troom" },
            { min = Vector(1455, 478, 649),   max = Vector(1791, 801, 900),   type="troom" },
            { min = Vector(2174, -961, -247), max = Vector(2304, -17, -94),   type="troom" },
        }},
        ["ttt_teenroom_2022"]           = { radius=nil,  timeout=3,  zones = {
            { min = Vector(863, -891, 329), max = Vector(1319, -308, 450), type="troom" },
        }},
        ["ttt_theroot"]                 = { radius=nil,  timeout=3,  zones = {
            { min = Vector(270, -129, 358), max = Vector(512, 128, 500),   type="exit", bounce=false },
            { min = Vector(-1233, 142, 95), max = Vector(-979, 517, 2115), type="troom" },
            { min = Vector(-979, 517, 95),  max = Vector(-786, 287, 240),  type="troom" },
        }},
        ["ttt_tinytown"]                = { radius=1000, timeout=15, spnHeight=150, waterExit=true },
        ["ttt_tokyodistrict"]           = { radius=1000, timeout=3,  zones = {
            { min = Vector(-4877, 925, 555),  max = Vector(-4814, 1018, 687), type="exit" },
            { min = Vector(-3990, 1866, 599), max = Vector(-3833, 2023, 733), type="troom" },
            { min = Vector(-3895, 1866, 240), max = Vector(-3833, 1930, 599), type="troom" },
            { min = Vector(-4291, 1091, 92),  max = Vector(-3772, 1949, 240), type="troom" },
            { min = Vector(-4450, 870, 92),   max = Vector(-4291, 1949, 240), type="safe" },
        }},
        ["ttt_tower"]                   = { radius=500,  timeout=3 },
        ["ttt_trainstation"]            = { radius=1200, timeout=10 },
        ["ttt_unsupervised"]            = { radius=1000, timeout=3,  zones = {
            { type="exit", height = 148, c1 = Vector(-466, 706, 280), c2 = Vector(-466, 443, 280), c3 = Vector(0, 706, 440), c4 = Vector(0, 443, 440) },
            { min = Vector(1844, 116, -49), max = Vector(1418, -683, 204), type="exit" },
            { min = Vector(-322, 316, 7),   max = Vector(-593, 440, 200),  type="troom" },
            { min = Vector(-471, 440, 7),   max = Vector(-707, 737, 200),  type="troom" },
            { min = Vector(477, 541, -200), max = Vector(133, 418, 0),     type="troom" },
            { min = Vector(477, 418, -200), max = Vector(252, 217, 0),     type="troom" },
        }},
        ["ttt_upstate"]                 = { radius=1000, timeout=10, zones = {
            { min = Vector(140, 2585, 100), max = Vector(762, 3578, 250),  type="exit" },
        }},
        ["ttt_vessel"]                  = { radius=nil,  timeout=5,  zones = {
            { min = Vector(-60, -2510, 992), max = Vector(59, -2390, 1078), type="exit", bounce=false },
        }, waterExit=true },
        ["ttt_villa_gambit"]            = { radius=1000, timeout=3,  zones = {
            { min = Vector(1030, 906, -123),  max = Vector(1404, 1041, 50),  type="troom" },
            { min = Vector(1095, 906, 50),    max = Vector(882, 1041, 210),  type="troom" },
            { min = Vector(996, 1130, 50),    max = Vector(882, 1041, 210),  type="troom" },
            { min = Vector(1209, 1644, -290), max = Vector(1404, 906, -123), type="troom" },
            { min = Vector(-201, 2080, -307), max = Vector(1505, 871, -124), type="safe" },
        }},
        ["ttt_villageisland_mc"]        = { radius=1100, timeout=5,  zones = {
            { min = Vector(422, -1350, 49),   max = Vector(1781, -1886, 482), type="safe" },
            { min = Vector(2120, -2795, 120), max = Vector(2480, -2680, 200), type="troom" },
        }},
        ["ttt_wetlands"]                = { radius=1000, timeout=5,  zones = {
            { min = Vector(-1096, 1928, 190), max = Vector(-488, 2111, 800), type="exit" },
            { type="exit", height = 500, c1 = Vector(-118, 2712, 368), c2 = Vector(-118, 2088, 368), c3 = Vector(-1120, 2712, 250), c4 = Vector(-1120, 2088, 250)},
            { type="exit", height = 500, c1 = Vector(1288, 2254, 0),   c2 = Vector(1852, 1681, 0),   c3 = Vector(2114, 3060, 0),    c4 = Vector(2127, 1491, 0)},
            { type="exit", height = 500, c1 = Vector(1428, 2365, 0),   c2 = Vector(648, 3149, 0),    c3 = Vector(2137, 3072, 0),    c4 = Vector(1230, 3242, 0)},
        }},
        ["ttt_wetscraper"]              = { radius=1000, timeout=3,  zones = {
            { min = Vector(464, -641, -2605), max = Vector(952, -194, -2393),  type="troom" },
            { min = Vector(795, -910, -1991), max = Vector(1023, -146, -1723), type="troom" },
        }},
        ["ttt_windmill_sky"]            = { radius=1200, timeout=5,  zones = {
            { min = Vector(3222, -3601, 2575), max = Vector(3801, -2959, 2730), type="exit", bounce=false },
        }},
        ["ttt_worlds"]                  = { radius=1200, timeout=3 },
    }

    local map = game.GetMap()
    local mapStats = {radius=1000, timeout=10}

    if GW_Utils.mapSpawnStatsList[map] then
        print('direct match!')
        mapStats = GW_Utils.mapSpawnStatsList[map]
    else
        for mapPrefix, stats in pairs(GW_Utils.mapSpawnStatsList) do
            if string.StartWith(map, mapPrefix) then
                print(mapPrefix)
                mapStats = stats
            end
        end
    end

    GW_Utils.mapSpawnStats = mapStats
    if not GW_Utils.mapSpawnStats.spnHeight then GW_Utils.mapSpawnStats.spnHeight = 100 end

    --GW_DBG.Log("Map Stats for "..map.."...")
    --GW_DBG.Inspect(GW_Utils.mapSpawnStats)
    --if GW_AllNonWaterSpawns then GW_DBG.Log("Non-water spawns: ", #GW_AllNonWaterSpawns) end


elseif CLIENT then
    net.Receive(HIDE_MARK_MSG, function()
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        marks.Remove({ ent })
        ent._HideMarks = true -- handled in mv hook in prop lua
    end)

    net.Receive(UNHIDE_MARK_MSG, function()
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        ent._HideMarks = false
        local markColor = nil

        for _, mv in ipairs(markerVision.registry) do
            if mv:GetEnt() == ent then
                markColor = mv:GetColor()
            end
        end

        if markColor then
            marks.Add({ ent }, markColor)
        end
    end)
end