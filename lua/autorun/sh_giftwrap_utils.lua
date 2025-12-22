GW_DBG = {}
GW_DBG.Cvar = CreateConVar("ttt2_giftwrap_debug", 0, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables addon debug prints for client & server (should not be enabled for real play).", 0, 1)

function GW_DBG.Inspect(obj)
    if not GW_DBG.Cvar:GetBool() then return end
    GW_DBG.Log(obj, type(obj))

    if obj then
        if type(obj) == "table" then
            PrintTable(obj)

        elseif obj.GetTable and obj:GetTable() then
            PrintTable(obj:GetTable())
        end
   end
end

function GW_DBG.InspectUI(el, ind)
    if not GW_DBG.Cvar:GetBool() then return end

    if not ind then ind = 0 end
    local indS = string.rep("  ", ind)
    local class = el:GetClassName()

    if class == "Panel" then
        GW_DBG.Log(indS.."Panel "..el:GetName().." (#"..#el:GetChildren().." elements)", el)
        for _, c in ipairs(el:GetChildren()) do
            DebugInspectUI(c, ind + 1)
        end

    elseif class == "Label" then
        GW_DBG.Log(indS.."Label "..el:GetName()..": \""..el:GetText().."\"", el)
        for _, c in ipairs(el:GetChildren()) do
            DebugInspectUI(c, ind + 1)
        end

    else
        GW_DBG.Log(indS.."Element "..el:GetName(), el)
    end
end

function GW_DBG.Log(...)
    if not GW_DBG.Cvar:GetBool() then return end

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

    -- local print
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

function GW_Utils.GetEntChildAt(ent, i)
    local children = ent:GetChildren()

    if #children >= i then
        return children[i]
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




GW_DBG.Log("Utils initialized.")

-- multi-Lua defs I don't really want to make another file for
-- TODO: probably also gate these behind utils table
SWEP_CLASS_NAME = "weapon_ttt_giftwrap"
PROP_CLASS_NAME = "prop_giftwrap_gift" -- needs to be "prop_" for prop disguiser to work
MARKER_UI_LABEL = "giftwrap_gift_beacon_"

GIFTWRAP_ICON   = "vgui/ttt/icon_giftwrap"
WRAP_VIEWMODEL  = "models/ttt/giftwrap/v_giftwrap.mdl"
WRAP_WORLDMODEL = "models/ttt/giftwrap/w_giftwrap.mdl"
GIFT_VIEWMODEL  = "models/ttt/gift/v_gift.mdl"
GIFT_WORLDMODEL = "models/ttt/gift/w_gift.mdl"
SNUFFLE_TREE_MODEL = "models/props_snowville/tree_pine_small.mdl"

ERROR_ALREADY_OPENED = "You already opened a random gift this round!"
XMAS_DAY = 359

GW_CVAR_FLAGS = {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}
