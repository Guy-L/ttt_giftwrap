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
        GW_DBG.ShowSpawns({GW_Utils.NearestSpawn(plyPos, false)}, 100, 0.2)

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
                local col = zone.type == "exit"
                    and Color(255, 50, 50, 1)
                    or Color(50, 255, 50, 1)

                -- Axis-aligned box
                if zone.min and zone.max then
                    local origin = (zone.min + zone.max) / 2

                    if plyPos:Distance(origin) <= 1500 then
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

                    if plyPos:Distance(center) <= 1500 then
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
                    end
                end
            end
        end

        if verbose and radius then
            local giftPos = giftEnt:GetPos()
            GW_DBG.Log("gift near spawn: "..tostring(GW_Utils.IsNearAnySpawn(giftPos, radius)).." (rad:"..radius.."; zones: "..(zones and #zones or 0).."; "..game.GetMap().."); is in world "..tostring(util.IsInWorld(giftPos)).."; water level "..giftEnt:WaterLevel())
            GW_DBG.Log(math.Round(plyPos.x)..", "..math.Round(plyPos.y)..", "..math.Round(plyPos.z).."; player near spawn: "..tostring(GW_Utils.IsNearAnySpawn(plyPos, radius)).."; is in world "..tostring(util.IsInWorld(plyPos)).."; zone "..tostring(utils.PointZone(plyPos)))
        end
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

        ent:SetNWEntity("WrappedByGift", giftObj)
        ent._GWStoredColGroup = ent:GetCollisionGroup()
        ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        local minPos, maxPos = game.GetWorld():GetCollisionBounds()
        ent:SetPos(maxPos)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
            phys:SetPos(maxPos)
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
            end
        end

        -- hide all markervisions client-side
        net.Start(HIDE_MARK_MSG)
        net.WriteEntity(ent)
        net.Broadcast()
    end

    function GW_Utils.ExitStasis(ent, pos, stabilize)
        ent:SetPos(pos)
        ent:SetNoDraw(false)
        ent:SetNotSolid(false)

        ent:SetNWEntity("WrappedByGift", nil)
        if ent._GWStoredColGroup then
            ent:SetCollisionGroup(ent._GWStoredColGroup)
        end

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetPos(pos)

            -- give things with move children a few extra ticks to propagate their new position
            -- before restarting physics (otherwise things like vehicles go flying off randomly)
            timer.Simple(stabilize and 0.25 or 0, function()
                if IsValid(phys) then
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
                t.trailEnt:Remove()
                util.SpriteTrail(ent, t.attachID, t.color, t.additive, t.startWidth, t.endWidth, t.lifetime, t.textureRes, t.texture)
            end
        end

        -- unhide all markervisions client-side
        net.Start(UNHIDE_MARK_MSG)
        net.WriteEntity(ent)
        net.Broadcast()
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

            if dist < lowestDist and GW_Utils.PointZone(spawn.pos, verbose) ~= "nospawn" then
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

        for _, zone in ipairs(GW_Utils.mapSpawnStats.zones) do
            if GW_Utils.IsPointInZone(pos, zone) then
                return zone.type
            end
        end

        return false
    end

    -- TODO: post-teleport visibility (MV or otherwise)
    GW_Utils.mapSpawnStatsList = {
        ["ttt_bestbuy"]                = { radius=nil },
        ["ttt_ca_oilrig_edit"]         = { radius=800,  timeout=3,  waterExit=true },
        ["ttt_canyon_labs"]            = { radius=1000, timeout=3 },
        ["ttt_castle"]                 = { radius=1000, timeout=5,  waterExit=true },
        ["ttt_cobertura"]              = { radius=2000, timeout=3 },
        ["ttt_cottage"]                = { radius=nil,  timeout=3,  waterExit=true },
        ["ttt_cozy_cove"]              = { radius=nil,  timeout=15, waterExit=true },
        ["ttt_diescraper"]             = { radius=400,  timeout=3 },
        ["ttt_escher_nmp8_d"]          = { radius=1000, timeout=3 },
        ["ttt_forestpath_winter"]      = { radius=1100, timeout=5,  waterExit=true },
        ["ttt_fort_pvk"]               = { radius=1000, timeout=3,  waterExit=true },
        ["ttt_frg_angles"]             = { radius=2000, timeout=3 },
        ["ttt_frg_angles_nm"]          = { radius=2000, timeout=3 },
        ["ttt_frg_the_blue_wall_v1-1"] = { radius=nil },
        ["ttt_gsf_apartments_b1"]      = { radius=1000, timeout=3 },
        ["ttt_gsf_topztower"]          = { radius=1000, timeout=3 },
        ["ttt_happyhome"]              = { radius=1150, timeout=1 },
        ["ttt_hijacked_v1"]            = { radius=1000, timeout=3 },
        ["ttt_innocentmotel_v1"]       = { radius=1000, timeout=3,  zones = {
            { min = Vector(-440, 750, -250), max = Vector(-250, 950, -70), type="exit" }
        }},
        ["ttt_intergalactic"]          = { radius=1000, timeout=5 },
        ["ttt_island_2024"]            = { radius=1200, timeout=15, waterExit=true },
        ["ttt_islandstreets"]          = { radius=1000, timeout=15, waterExit=true },
        ["ttt_kakariko_v4a"]           = { radius=1500, timeout=10, zones = {
            { min = Vector(-2800, -330, 0), max = Vector(-2180, -1500, 500), type="exit" }
        }},
        ["ttt_kappukeki_streets"]      = { radius=1000, timeout=10, zones = {
            { min = Vector(315, -400, 400),   max = Vector(800, 325, 800),    type="exit" },
            { min = Vector(-940, 1290, -300), max = Vector(-1660, 1580, 0),   type="safe" },
            { min = Vector(-660, 255, -360),  max = Vector(-990, 1770, -120), type="safe" },
        }, waterExit=true },
        ["ttt_lighthouse"]             = { radius=1000, timeout=15, waterExit=true },
        ["ttt_lockout"]                = { radius=1000, timeout=3 },
        ["ttt_magma"]                  = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1615, 114, -400),  max = Vector(-1152, 640, -63), type="exit" },
            { min = Vector(-728, -1066, -577), max = Vector(99, -511, -135),  type="exit" },
        }},
        ["ttt_magma_gs"]               = { radius=1000, timeout=3,  zones = {
            { min = Vector(-1635, 110, -500),  max = Vector(-1157, 634, -49), type="exit" },
            { min = Vector(-724, -1044, -543), max = Vector(78, -565, -140),  type="exit" },
        }},
        ["ttt_mc_summercamp_v2"]       = { radius=nil },
        ["ttt_minecraft_b5_fish_n_ships_nocheese"] = { radius=1000, timeout=3, zones = {
            { min = Vector(-1775, -1841, -3355), max = Vector(239, 163, -3270), type="exit" },
        }, waterExit=true },
        ["ttt_missile_isles"]          = { radius=1000, timeout=6,  zones = {
            { min = Vector(1833, 1312, 110), max = Vector(2519, 2012, 433), type="safe" },
            { min = Vector(1289, -289, 92),  max = Vector(1588, 9, 326),    type="nospawn" },
        }},
        ["ttt_mttresort_v2"]           = { radius=1000, timeout=3 },
        ["ttt_mw2_terminal"]           = { radius=nil },
        ["ttt_oldruins"]               = { radius=nil,  timeout=3,  waterExit=true },
        ["ttt_orange_v7"]              = { radius=1500, timeout=3 },
        ["ttt_panorama"]               = { radius=1000, timeout=3,  zones = {
            { min = Vector(-2588, 543, -100), max = Vector(-960, 1466, 300), type="safe" },
        }},
        ["ttt_paradise_resort"]        = { radius=1000, timeout=15 },
        ["ttt_raifucu_maru"]           = { radius=1000, timeout=5,  waterExit=true },
        ["ttt_rooftops_a2_f1"]         = { radius=1000, timeout=3 },
        ["ttt_roy_the_ship"]           = { radius=nil,  timeout=5,  waterExit=true },
        ["ttt_rpgvillage_edit"]        = { radius=nil,  timeout=5,  zones = {
            { min = Vector(1266, -3670, -1182), max = Vector(1925, -1817, -370), type="exit" },
            { min = Vector(-1260, 8, -1300),    max = Vector(-946, 423, -728), type="exit" },
        }},
        ["ttt_seliana"]                = { radius=1000, timeout=5,  zones = {
            { min = Vector(1136, 1637, 551),  max = Vector(1369, 1764, 779),  type="nospawn" },
        }, waterExit=true },
        ["ttt_simple_otat1"]           = { radius=1000, timeout=3 },
        ["ttt_skycraftfinal_dark_r6"]  = { radius=1500, timeout=3 },
        ["ttt_skyscraper"]             = { radius=400,  timeout=3 },
        ["ttt_sm64_big_boos_haunt"]    = { radius=nil },
        ["ttt_snowtown_001e"]          = { radius=1500, timeout=10, zones = {
            { min = Vector(-3500, 52, -147), max = Vector(-2054, 2067, 752), type="safe" },
        }},
        ["ttt_spacescraper"]           = { radius=400,  timeout=1 },
        ["ttt_submachine"]             = { radius=500,  timeout=5 },
        ["ttt_subnet_final"]           = { radius=nil,  timeout=3,  zones = {
            { min = Vector(548, -811, 1103),  max = Vector(1995, 378, 1250),  type="exit" },
            { min = Vector(2617, -790, 1100), max = Vector(2973, -449, 1285), type="exit" },
            { min = Vector(441, 664, 350),    max = Vector(692, 991, 500),    type="exit" },
            { min = Vector(435, 360, 200),    max = Vector(558, 451, 450),    type="exit" },
            { min = Vector(575, -149, 200),   max = Vector(808, -70, 443),    type="exit" },
            { min = Vector(2623, -11, 250),   max = Vector(2773, 186, 390),   type="exit" },
            { min = Vector(2784, -421, 350),  max = Vector(2897, -744, 530),  type="exit" },
            { min = Vector(2474, -289, 330),  max = Vector(2571, -102, 532),  type="nospawn" },
        }},
        ["ttt_teenroom_2022_v2"]       = { radius=nil },
        ["ttt_theroot_b1"]             = { radius=nil },
        ["ttt_tinytown"]               = { radius=1000, timeout=15, spnHeight=150, waterExit=true },
        ["ttt_tower"]                  = { radius=500,  timeout=3 },
        ["ttt_trainstation_a5"]        = { radius=1200, timeout=10 },
        ["ttt_upstate"]                = { radius=1000, timeout=10, zones = {
            { min = Vector(140, 2585, 100), max = Vector(762, 3578, 250),  type="exit" },
        }},
        ["ttt_vessel"]                 = { radius=nil,  timeout=5,  zones = {
            { min = Vector(-60, -2510, 992), max = Vector(59, -2390, 1078), type="exit" },
        }, waterExit=true },
        ["ttt_villageisland_mc"]       = { radius=1100, timeout=5,  zones = {
            { min = Vector(422, -1350, 49), max = Vector(1781, -1886, 482), type="safe" },
        }},
        ["ttt_wetlands"]               = { radius=1000, timeout=5,  zones = {
            { min = Vector(-1095, 1927, 190), max = Vector(-493, 2111, 276), type="exit" },
            { type="exit", height = 200, c1 = Vector(-118, 2712, 368), c2 = Vector(-118, 2088, 368), c3 = Vector(-1120, 2712, 250), c4 = Vector(-1120, 2088, 250)},
            { type="exit", height = 500, c1 = Vector(1288, 2254, 0),   c2 = Vector(1852, 1681, 0),   c3 = Vector(2114, 3060, 0),    c4 = Vector(2127, 1491, 0)},
            { type="exit", height = 500, c1 = Vector(1428, 2365, 0),   c2 = Vector(648, 3149, 0),    c3 = Vector(2137, 3072, 0),    c4 = Vector(1230, 3242, 0)},
        }},
        ["ttt_windmill_sky"]           = { radius=1200, timeout=10, zones = {
            { min = Vector(3222, -3601, 2575), max = Vector(3801, -2959, 2730), type="exit" },
        }},
        ["ttt_worlds"]                 = { radius=1200, timeout=3 },
    }

    local map = game.GetMap()
    GW_Utils.mapSpawnStats = GW_Utils.mapSpawnStatsList[map] or {radius=1000, timeout=10}
    if not GW_Utils.mapSpawnStats.spnHeight then GW_Utils.mapSpawnStats.spnHeight = 100 end

    --GW_DBG.Log("Map Stats for "..map.."...")
    --GW_DBG.Inspect(GW_Utils.mapSpawnStats)
    if GW_AllNonWaterSpawns then GW_DBG.Log("Non-water spawns: ", #GW_AllNonWaterSpawns) end


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