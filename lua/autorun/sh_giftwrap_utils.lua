GW_DBG = {}
GW_DBG.Cvar = CreateConVar("ttt2_giftwrap_debug", 0, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables addon debug mode (should not be enabled for real play).", 0, 1)


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

function GW_DBG.InspectDamage(target, dmgInfo)
    if not GW_DBG.Cvar:GetBool() then return end

    GW_DBG.Log(target, dmgInfo)
    GW_DBG.Log("=> AmmoType", dmgInfo:GetAmmoType())
    GW_DBG.Log("=> Attacker", dmgInfo:GetAttacker())
    GW_DBG.Log("=> BaseDamage", dmgInfo:GetBaseDamage())
    GW_DBG.Log("=> Damage", dmgInfo:GetDamage())
    GW_DBG.Log("=> DamageBonus", dmgInfo:GetDamageBonus())
    GW_DBG.Log("=> DamageCustom", dmgInfo:GetDamageCustom())
    GW_DBG.Log("=> DamageForce", dmgInfo:GetDamageForce())
    GW_DBG.Log("=> DamagePosition", dmgInfo:GetDamagePosition())
    GW_DBG.Log("=> DamageType", dmgInfo:GetDamageType())
    GW_DBG.Log("=> Inflictor", dmgInfo:GetInflictor())
    GW_DBG.Log("=> MaxDamage", dmgInfo:GetMaxDamage())
    GW_DBG.Log("=> ReportedPosition", dmgInfo:GetReportedPosition())
    GW_DBG.Log("=> Weapon", dmgInfo:GetWeapon())
    GW_DBG.Log("=> IsBulletDamage", dmgInfo:IsBulletDamage())
    GW_DBG.Log("=> IsExplosionDamage", dmgInfo:IsExplosionDamage())
    GW_DBG.Log("=> IsFallDamage", dmgInfo:IsFallDamage())
end

function GW_DBG.DumpAllModelPaths()
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
    for _, ent in ipairs(ents.GetAll()) do
        if ent:GetCollisionGroup() == COLLISION_GROUP_IN_VEHICLE then
            GW_DBG.Log("Temporarily override collision group for", ent)
            ent._HadInVehicleCollision = true
            ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        end
    end

    ply:LagCompensation(true)
    local tr = ply:GetEyeTrace(MASK_SHOT)
    ply:LagCompensation(false)

    for _, ent in ipairs(ents.GetAll()) do
        if ent._HadInVehicleCollision then
            ent:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
            ent._HadInVehicleCollision = nil
        end
    end

     -- don't acknowledge wrap on dynamic map elements
    if IsValid(tr.Entity) and GW_Utils.IsMapClass(tr.Entity) then
        tr.Entity = game.GetWorld()
    end

    return tr
end

function GW_Utils.IsMapClass(ent)
    if not IsValid(ent) then return false end
    local class = ent:GetClass()

    return string.StartsWith(class, "func_breakable")
        or string.StartsWith(class, "func_door")
        or string.StartsWith(class, "prop_door")
        or string.StartsWith(class, "trigger")
        or class == "func_button"
        or class == "func_brush"
        or class == "func_clip_vphysics"
        or class == "func_movelinear"
        or class == "func_reflective_glass"
        or class == "func_rotating"
        or class == "func_tanktrain"
        or class == "func_tracktrain"
        or class == "func_water_analog"
        or class == "func_wall"
        or class == "fish"
        or class == "phys_bone_follower"
        or class == "ttt_traitor_button"
        or class == "ttt_traitor_check"
        or class == "momentary_rot_button"
        or class == "class C_BaseToggle" -- the hell even
        or class == "prop_dynamic"
        or GW_Utils.IsMapClass(ent:GetMoveParent())
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

function GW_Utils.GetEntSurfaceProp(ent, phys, silent)
    if not IsValid(ent) then return nil end
    if not phys then phys = ent:GetPhysicsObject() end

    -- 1. Physics object (should work in most cases but I'm not certain!!)
    if IsValid(phys) then
        local mat = phys:GetMaterial()
        if mat and mat ~= "" then
            if not silent then GW_DBG.Log("Retrieved surfaceProp from physics object:", mat) end
            return mat
        end
    end

    -- 2. Model surfaceprop
    local mdl = ent:GetModel()
    if mdl then
        local info = util.GetModelInfo(mdl)
        
        if info then
            local propName = info.SurfacePropName or (info.KeyValues and info.KeyValues.surfaceprop)
            if not silent then GW_DBG.Log("Retrieved surfaceProp from model info:", propName) end
            return propName
        end
    end

    -- 3. Render material
    local mats = ent:GetMaterials()
    if mats and mats[1] then
        local iMat = Material(mats[1])

        if iMat then
            local surfaceProp = iMat:GetString("$surfaceProp")

            if not silent then GW_DBG.Log("Retrieved surfaceProp from materials:", surfaceProp) end
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
        if not silent then GW_DBG.Log("Retrieved surfaceProp from trace hit:", tr.SurfaceProps) end
        return tr.SurfaceProps
    end

    if not silent then GW_DBG.Log("Failed to retrieve surfaceProp from", ent) end
    return nil
end

function GW_Utils.NonSpamMessage(ply, id, msg, acceptClient)
    if CLIENT and not acceptClient then return end
    local curTime = CurTime()

    if not ply["Last"..id] or curTime > ply["Last"..id] + 1 then
        ply:ChatPrint(msg)
        ply["Last"..id] = curTime
    end
end

function GW_Utils.TL(label) --shorthand
    return LANG.TryTranslation(label)
end

function GW_Utils.NearEquals(a, b, epsilon)
    return math.abs(a - b) < (epsilon or 0.0001)
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
        or (not other:Alive() and GW_Utils.IsOmniscient(ply)) -- omniscient player
end

function GW_Utils.GetWrapper(giftEnt)
    if not IsValid(giftEnt) then return nil end
    return player.GetBySteamID64(giftEnt:GetWrapperSID())
end

function GW_Utils.GetTopmostWrap(ent)
    if not IsValid(ent) then return nil end
    local wrappedBy = ent:GetNW2Entity("WrappedByGift")
    if not IsValid(wrappedBy) then return nil end
    wrapLevel = 0

    while IsValid(wrappedBy) do
        ent = wrappedBy
        wrappedBy = ent:GetNW2Entity("WrappedByGift")
        wrapLevel = wrapLevel + 1
    end

    return ent, wrapLevel
end

function GW_Utils.IsPlayerWrapped(ply)
    local parent = ply:GetParent()

    return IsValid(parent) and IsValid(parent:GetNW2Entity("WrappedByGift"))
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

    for k, v in pairs(fromGift:GetNW2VarTable()) do
        toGift:SetNW2Var(k, v.value)
    end

    local wrappedEnt = fromGift:GetStoredGift()
    if IsValid(wrappedEnt) then
        wrappedEnt:SetNW2Entity("WrappedByGift", toGift)
    end

    -- transfer Prop Exploder (v1) rig
    for _, ply in ipairs(player.GetAll()) do
        if ply.PEProp == fromGift then
            ply.PEProp = toGift
        end
    end

    -- transfer Prop Exploder (v2) rig
    if fromGift:GetNWBool("PEPlanted") then
        fromGift:RemoveCallOnRemove("PEEarlyRemove" .. fromGift:EntIndex())
        toGift:CallOnRemove("propexplodemarker_" .. toGift:EntIndex(), function(goneEnt) goneEnt:RemoveMarkerVision("propexplode_owner") end)
        toGift:SetNWBool("PEPlanted", true)

        local mvOwner = markerVision.Get(fromGift, "propexplode_owner"):GetOwner()
        timer.Simple(0.1, function() -- can't network MV before the client knows the ent exists
            if IsValid(mvOwner) then
                local mvObject = toGift:AddMarkerVision("propexplode_owner")
                mvObject:SetOwner(mvOwner)
                mvObject:SetVisibleFor(VISIBLE_FOR_TEAM)
                mvObject:SyncToClients()
            end
        end)

        for _, wep in ipairs(ents.GetAll()) do
            if wep:GetClass() == "weapon_ttt_propexploderv2" and wep.PEProp == fromGift then
                wep.PEProp = toGift
                toGift:CallOnRemove("PEEarlyRemove" .. toGift:EntIndex(), function() EnablePEAgain(wep, toGift) end)
            end
        end
    end

    -- transfer stink from ragdolls
    if fromGift:GetNW2Bool("GWStinky") then
        local fromOwner = fromGift:GetOwner()

        timer.Simple(0.1, function()
            if IsValid(toGift) then
                toGift.StinkSoundID = toGift:StartLoopingSound("giftwrap/flies_loop.wav")
                --toGift.StinkSoundID2 = toGift:StartLoopingSound("giftwrap/flies_loop.wav")

                if toGift:IsWeapon() then
                    GW_Utils.StinkAttachPlayer(toGift:GetOwner())

                else
                    if IsValid(fromOwner) then
                        fromOwner:StopParticles()
                    end

                    ParticleEffectAttach("flies_fx", PATTACH_ABSORIGIN_FOLLOW, toGift, 0)
                end
            end
        end)
    end
end

function GW_Utils.StartStink(giftEnt)
    if not IsValid(giftEnt) then return end

    giftEnt:SetNW2Bool("GWStinky", true)
    giftEnt.StinkSoundID = giftEnt:StartLoopingSound("giftwrap/flies_loop.wav")
    --giftEnt.StinkSoundID2 = giftEnt:StartLoopingSound("giftwrap/flies_loop.wav")

    if giftEnt:IsWeapon() then
        local giftOwner = giftEnt:GetOwner()
        giftOwner:ChatPrint("Your gift is starting to stink...")
        GW_Utils.StinkAttachPlayer(giftOwner)
    else
        ParticleEffectAttach("flies_fx", PATTACH_ABSORIGIN_FOLLOW, giftEnt, 0)
    end
end

function GW_Utils.StinkAttachPlayer(ply)
    if not IsValid(ply) then return end
    local rhAttachmentID = GW_Utils.GetRHAttachmentID(ply)

    if rhAttachmentID then
        ParticleEffectAttach("flies_fx", PATTACH_POINT_FOLLOW, ply, rhAttachmentID)
        return
    end

    GW_DBG.Log("(Flies FX) Failed to find right hand for", ply, ply:GetModel())
    ParticleEffectAttach("flies_fx", PATTACH_ABSORIGIN_FOLLOW, ply, 0)
end

function GW_Utils.GetRHAttachmentID(ply)
    if not IsValid(ply) then return end
    local rhAttachmentNames = {
        "anim_attachment_RH",
        "primary",
    }

    for _, name in ipairs(rhAttachmentNames) do
        local id = ply:LookupAttachment(name)

        if id > 0 then
            return id
        end
    end
end

function GW_Utils.IsGiftBox(ent)
    local class = ent:GetClass()
    return class == PROP_CLASS_NAME or (class == SWEP_CLASS_NAME and ent:HasGift())
end

function GW_Utils.IsOmniscient(ply)
    return ply:GetSubRoleData().isOmniscientRole or not GW_Utils.IsLivingPlayer(ply)
end

GW_CvarList = GW_CvarList or { ["ttt2_giftwrap_debug"] = "bool" }
GW_Utils.CvarFlags = {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}

function GW_Utils.Cvar(name, default, min, max, desc)
    default = tonumber(default)
    min = tonumber(min)
    max = tonumber(max)
    local cvar = CreateConVar(name, default, GW_Utils.CvarFlags, desc, min, max)

    if min == 0 and max == 1 and (default == 0 or default == 1) then
        GW_CvarList[name] = "bool"
    else
        GW_CvarList[name] = "float"
    end

    return cvar
end

GW_DBG.Log("Utils initialized.")


-- multi-Lua defs I don't really want to make another file for
-- TODO: probably also gate these behind utils table
SWEP_CLASS_NAME  = "weapon_ttt_giftwrap"
PROP_CLASS_NAME  = "prop_giftwrap_gift" -- needs to be "prop_" for prop disguiser to work
MV_TREE_LABEL    = "giftwrap_gift_beacon_"
MV_WRAPPER_LABEL = "giftwrap_wrapper_tracking"
MV_GIFTEE_LABEL  = "giftwrap_giftee"
MV_GIFT_TP_LABEL = "giftwrap_gift_teleport"

GIFTWRAP_ICON   = "vgui/ttt/icon_giftwrap"
WRAP_VIEWMODEL  = "models/ttt/giftwrap/v_giftwrap.mdl"
WRAP_WORLDMODEL = "models/ttt/giftwrap/w_giftwrap.mdl"
GIFT_VIEWMODEL  = "models/ttt/gift/v_gift.mdl"
GIFT_WORLDMODEL = "models/ttt/gift/w_gift.mdl"
GIFT_PROPMODEL  = "models/ttt/gift/prop_gift.mdl"
SNUFFLE_TREE_MODEL = "models/props_snowville/tree_pine_small.mdl"

MAT_GIFT_ICON = Material("vgui/ttt/menu/icon_gift")

ERROR_ALREADY_OPENED = "You already opened a random gift this round!"
XMAS_DAY = 359