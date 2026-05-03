GW_DBG = {}
GW_DBG.Cvar = CreateConVar("ttt2_giftwrap_debug", 0, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables addon debug prints for client & server (should not be enabled for real play).", 0, 1)

function GW_DBG.Inspect(obj, noMeta)
    if not GW_DBG.Cvar:GetBool() then return end
    GW_DBG.Log(obj, ", of type "..type(obj))

    if obj and not (type(obj) == "number") then
        if type(obj) == "table" then
            PrintTable(obj)

        elseif obj.GetTable and obj:GetTable() then
            PrintTable(obj:GetTable())
        end

        if not noMeta then
            local meta = getmetatable(obj)
            if meta then
                print("Metatable found:")
                PrintTable(meta)
            else
                print("No metatable")
            end
        end
   end
end

function GW_DBG.InspectUI(el, ind, depthLimit)
    if not GW_DBG.Cvar:GetBool() then return end

    if not ind then ind = 0 end
    if not depthLimit then depthLimit = 999 end
    local indS = string.rep("  ", ind)
    local class = el:GetClassName()

    if class == "Panel" or el.GetChildren then
        GW_DBG.Log(indS.."Panel "..el:GetName().." (#"..#el:GetChildren().." elements)", el, el:GetSize())
        if ind < depthLimit then
            for _, c in ipairs(el:GetChildren()) do
                GW_DBG.InspectUI(c, ind + 1, depthLimit)
            end
        end

    elseif class == "Label" then
        GW_DBG.Log(indS.."Label "..el:GetName()..": \""..el:GetText().."\"", el)
        if ind < depthLimit then
            for _, c in ipairs(el:GetChildren()) do
                GW_DBG.InspectUI(c, ind + 1, depthLimit)
            end
        end

    else
        GW_DBG.Log(indS.."Element "..el:GetName(), el)
    end
end

function GW_DBG.HighlightUI(el)
    local highlight = Color(200, 90, 95, 255)

    el:SetPaintBackground(true)
    el:SetBackgroundColor(highlight)
    el.Paint = function(self, w, h)
        surface.SetDrawColor(highlight)
        surface.DrawRect(0, 0, w, h)
    end
end

local function ReconstructMsg(...)
        --reconstruct string for server relay
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end

    local msg
    if CLIENT then
        msg = "[GiftWrap Client] "
    elseif SERVER then
        msg = "[GiftWrap Server] "
    else
        msg = "[GiftWrap] "
    end
    msg = msg .. table.concat(parts, "\t")

    return msg
end

function GW_DBG.Log(...)
    if not GW_DBG.Cvar:GetBool() then return end

    local msg = ReconstructMsg(...)
    print(msg)

    --server relay to all clients except host
    if SERVER then
        for _, ply in ipairs(player.GetAll()) do
            if not ply:IsListenServerHost() then
                ply:PrintMessage(HUD_PRINTCONSOLE, "[Server Relay] " .. msg)
            end
        end
    end
end

local gwLog = ""
function GW_DBG.LogAppend(...)
    if not GW_DBG.Cvar:GetBool() then return end
    gwLog = gwLog .. "[Dump] " .. ReconstructMsg(...) .. "\n"
end

function GW_DBG.LogDump()
    print(gwLog)
    gwLog = ""
end

-- make whichever bot you're looking at switch to the weapon
-- and fire it (giving it if they don't have it yet)
function GW_DBG.MakeBotFireClass(ply, class)
    if CLIENT or not IsValid(ply) then return end
    local tr = GW_Utils.GetEyeTrace(ply)
    local hitEnt = tr.Entity

    if IsValid(hitEnt) and hitEnt:GetClass() == "player" then
        if not hitEnt:HasWeapon(class) then hitEnt:Give(class) end
        hitEnt:SelectWeapon(class)
        hitEnt:GetActiveWeapon():PrimaryAttack() 
    end
end

function GW_DBG.ProfileStart()
    GW_DBG.profileStart = os.clock()
    GW_DBG.profileLast  = GW_DBG.profileStart
end

function GW_DBG.Profile(checkpointName)
    GW_DBG.Log("[Profile - "..checkpointName.."] Time:", string.format("%.4f", (os.clock() - GW_DBG.profileStart)), "("..string.format("%.4f", (os.clock() - GW_DBG.profileLast)).." since last)")
    GW_DBG.profileLast = os.clock()
end

function GW_DBG.AllowDebugMenu()
    return GW_DBG.Cvar:GetBool() or GetGlobalBool("ttt2_deathmatch_active", false)
end

-----------------------------------------------------
--------------------- Utils -------------------------
-----------------------------------------------------
GW_Utils = {}

function GW_Utils.IsLivingPlayer(ply)
    return IsPlayer(ply) and ply:Alive() and not ply:IsSpec()
end

function GW_Utils.IsGiftWrap(wep)
    return IsValid(wep) and wep:GetClass() == SWEP_CLASS_NAME
end

function GW_Utils.GetInventoryGiftwrap(ply)
    if not ply then
        if SERVER then return end
        ply = LocalPlayer()
    end
    if not IsValid(ply) then return end

    for _, wep in ipairs(ply:GetWeapons()) do
        if GW_Utils.IsGiftWrap(wep) then
            -- assumption that player can only have one
            return wep
        end
    end
end

function GW_Utils.GetEquipment(ply, equipmentName)
    for _, wep in ipairs(ply:GetWeapons()) do
        if wep:GetClass() == equipmentName then
            return wep, false
        end
    end

    for _, itm in ipairs(ply:GetEquipmentItems()) do
        if itm == equipmentName then
            return itm, true
        end
    end
end

function GW_Utils.GetEntChildAt(ent, i)
    local children = ent:GetChildren()

    if #children >= i then
        return children[i]
    end
end

function GW_Utils.GetChildNamed(panel, name)
    for _, el in ipairs(panel:GetChildren()) do
        if el:GetName() == name then
            return el
        end
    end
end

function GW_Utils.GetEyeTrace(ply)
    ply:LagCompensation(true)
    local tr = ply:GetEyeTrace(MASK_SHOT)
    ply:LagCompensation(false)
    return tr
end

function GW_Utils.GetRandomUpwardsVel(raise)
    local dir = VectorRand()
    dir.z = math.abs(dir.z + raise)
    return dir:GetNormalized()
end

-- how is this not a function in base TTT2 
-- port of plymeta:GetSubRoleData() (sh_player_ext.lua)
function GW_Utils.GetSubRoleData(subRoleID)
    local rlsList = roles.GetList()

    for i = 1, #rlsList do
        if rlsList[i].index ~= subRoleID then
            continue
        end

        return rlsList[i]
    end

    return roles.NONE
end

function GW_Utils.GetEntCenter(ent)
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        local mins, maxs = phys:GetAABB()
        return phys:LocalToWorld((mins + maxs) * 0.5) + Vector(0, 0, 10)
    end

    -- fallback (other centering methods are way off for my gift, fucked bbox)
    return ent:GetPos()
end

function GW_Utils.GetEntSurfaceProp(ent, phys)
    if not IsValid(ent) then return nil end
    if not phys then phys = ent:GetPhysicsObject() end

    -- 1. Physics object (should work in most cases but I'm not certain!!)
    if IsValid(phys) then
        local mat = phys:GetMaterial()
        if mat and mat ~= "" then
            GW_DBG.Log("Retrieved surfaceProp from physics object:", mat)
            return mat
        end
    end

    -- 2. Model surfaceprop
    local mdl = ent:GetModel()
    if mdl then
        local info = util.GetModelInfo(mdl)
        
        if info then
            local propName = info.SurfacePropName or (info.KeyValues and info.KeyValues.surfaceprop)
            GW_DBG.Log("Retrieved surfaceProp from model info:", propName)
            return propName
        end
    end

    -- 3. Render material
    local mats = ent:GetMaterials()
    if mats and mats[1] then
        local iMat = Material(mats[1])

        if iMat then
            local surfaceProp = iMat:GetString("$surfaceProp")

            GW_DBG.Log("Retrieved surfaceProp from materials:", surfaceProp)
            return surfaceProp
        end
    end

    -- 4. Trace hitting entity
    local trCenter = ent:LocalToWorld(ent:OBBCenter())
    local tr = util.TraceLine({
        start  = trCenter,
        endpos = trCenter + Vector(0,0,1),
        filter = function(e) return e ~= ent end
    })
    if tr.HitEnt == ent then
        GW_DBG.Log("Retrieved surfaceProp from trace hit:", tr.SurfaceProps)
        return tr.SurfaceProps
    end

    GW_DBG.Log("Failed to retrieve surfaceProp from", ent)
    return nil
end

function GW_Utils.NonSpamMessage(ply, id, msg, acceptClient)
    if CLIENT and not acceptClient then return end

    if not ply["Last"..id] or CurTime() > ply["Last"..id] + 1 then
        ply:ChatPrint(msg)
        ply["Last"..id] = CurTime()
    end
end

function GW_Utils.DumpAllModelPaths()
    local out = {}

    local function CollectModels(dir)
        local files, folders = file.Find(dir .. "/*", "GAME")

        for _, f in ipairs(files) do
            if string.EndsWith(f, ".mdl") then
                local path = dir .. "/" .. f
                out[#out + 1] = path
                --GW_DBG.Log(path)
            end
        end
        out[#out + 1] = ""

        for _, folder in ipairs(folders) do
            CollectModels(dir .. "/" .. folder)
        end
    end

    CollectModels("models")
    file.Write("all_models.txt", table.concat(out, "\n"))
    GW_DBG.Log("Saved dump to all_models.txt.")
end

function GW_Utils.TL(label) --shorthand
    return LANG.TryTranslation(label)
end

function GW_Utils.GetAvatar(sid, size)
    if not size then size = "small" end
    local avatarMat = draw.GetAvatarMaterial(sid, size)
    local avatarTex = avatarMat:GetTexture("$basetexture")

    if avatarMat and avatarTex -- only return valid avatars
      and avatarMat:GetName() ~= "vgui/ttt/b-draw/icon_avatar_default"
      and avatarMat:GetName() ~= "vgui/ttt/b-draw/icon_avatar_bot"
      and not avatarTex:IsError()
      and not avatarTex:IsErrorTexture() then
        return avatarMat, avatarTex
    end
end

function GW_Utils.ConfirmedDead(ply, other)
    if not IsValid(ply) or not IsValid(other) then return false end
    return not other:TTT2NETGetBool("player_was_active_in_round", false) -- spectator
        or other:TTT2NETGetBool("body_found", false) -- confirmed dead
        or (not other:Alive() and ply:GetSubRoleData().isOmniscientRole) -- omniscient player
end

if SERVER then
    function GW_Utils.EnterStasis(ent)
        ent:SetNoDraw(true)
        ent:SetNotSolid(true)

        local minPos, maxPos = game.GetWorld():GetCollisionBounds()
        ent:SetPos(maxPos)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end

        -- hide connected map ropes so stasis pos doesn't show
        -- (other types may still be broken, will fix as I find them)
        for _, rope in ipairs(GW_Utils.FindConnectedRopes(ent)) do
            rope._storedWidth = rope:GetKeyValues()["Width"]
            rope:SetKeyValue("Width", "0")
        end
    end

    function GW_Utils.ExitStasis(ent, pos)
        ent:SetNoDraw(false)
        ent:SetNotSolid(false)
        ent:SetPos(pos)

        ent:PhysWake()
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end

        for _, rope in ipairs(GW_Utils.FindConnectedRopes(ent)) do
            if rope._storedWidth then
                rope:SetKeyValue("Width", tostring(rope._storedWidth))
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
end

function GW_Utils.GetWrapper(giftEnt)
    if not IsValid(giftEnt) then return nil end
    return player.GetBySteamID64(giftEnt:GetWrapperSID())
end

GW_Utils.sharedNetTable = {
    { type = "Bool",   name = "IsRandomGift" },
    { type = "Bool",   name = "IsContentsOnFire" },
    { type = "Int",    name = "GiftBoxColor" },
    { type = "Int",    name = "GiftRibbonColor" },
    { type = "String", name = "WrapperSID" },
    { type = "String", name = "CachedDataLabel" },
    { type = "String", name = "UnwrapNote" },
    { type = "Entity", name = "StoredGift" },
    { type = "Entity", name = "Giftee" },
}

-- must be called in SetupDataTables
function GW_Utils.SetupSharedTable(giftEnt)
    local boolCnt, intCnt, stringCnt, entCnt = 0, 0, 0, 0

    for _, var in ipairs(GW_Utils.sharedNetTable) do
        if var.type == "Bool" then
            giftEnt:NetworkVar(var.type, boolCnt, var.name)
            boolCnt = boolCnt + 1

        elseif var.type == "Int" then
            giftEnt:NetworkVar(var.type, intCnt, var.name)
            intCnt = intCnt + 1

        elseif var.type == "String" then
            giftEnt:NetworkVar(var.type, stringCnt, var.name)
            stringCnt = stringCnt + 1

        elseif var.type == "Entity" then
            giftEnt:NetworkVar(var.type, entCnt, var.name)
            entCnt = entCnt + 1
        end
    end

    return boolCnt, intCnt, stringCnt, entCnt
end

function GW_Utils.TransferNetVars(fromGift, toGift)
    for _, var in ipairs(GW_Utils.sharedNetTable) do
        toGift["Set"..var.name](toGift, fromGift["Get"..var.name](fromGift))
    end
end

GW_DBG.Log("Utils initialized.")


-- multi-Lua defs I don't really want to make another file for
-- TODO: probably also gate these behind utils table
SWEP_CLASS_NAME = "weapon_ttt_giftwrap"
PROP_CLASS_NAME = "prop_giftwrap_gift" -- needs to be "prop_" for prop disguiser to work
MV_TREE_LABEL   = "giftwrap_gift_beacon_"
MV_GIFTEE_LABEL = "giftwrap_giftee"

GIFTWRAP_ICON   = "vgui/ttt/icon_giftwrap"
WRAP_VIEWMODEL  = "models/ttt/giftwrap/v_giftwrap.mdl"
WRAP_WORLDMODEL = "models/ttt/giftwrap/w_giftwrap.mdl"
GIFT_VIEWMODEL  = "models/ttt/gift/v_gift.mdl"
GIFT_WORLDMODEL = "models/ttt/gift/w_gift.mdl"
GIFT_PROPMODEL  = "models/ttt/gift/prop_gift.mdl"
SNUFFLE_TREE_MODEL = "models/props_snowville/tree_pine_small.mdl"

ERROR_ALREADY_OPENED = "You already opened a random gift this round!"
XMAS_DAY = 359

GW_CVAR_FLAGS = {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}
