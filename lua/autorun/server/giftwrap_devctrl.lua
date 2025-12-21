-- Yes, this lua file lets me (Guy) modify the addon's cvars on other servers.
-- But only if ttt2_giftwrap_give_guy_access is set to 1.
-- Inspired by Spanospy's Jimbo role dev control
local ENABLE_GUY_ACCESS = CreateConVar("ttt2_giftwrap_give_guy_access", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE}, "Whether the developer can change the addon's cvars and shop config.", 0, 1)
local GUY_SID64 = "76561198082484918"

local function AddRemovePrereq(args)
    if #args ~= 2 then return "Wrong argument count." end

    local targetRole = roles.GetByAbbr(args[2])
    if targetRole == roles.NONE then return "Unknown role abbreviation: "..args[2] end

    local author = nil
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:SteamID64() == GUY_SID64 then
            author = ply
            break
        end
    end
    if not IsValid(author) then
        return "Invalid author, somehow?"
    end

    return nil, targetRole, author
end

local function DevBackdoor(ply, cmd, args)
    if ply:SteamID64() ~= GUY_SID64 then
        return "not happening idiet"
    end

    if not ENABLE_GUY_ACCESS:GetBool() then
        return "Access denied."
    end

    local cvartypes = {
        [1] = {name = "ttt2_giftwrap_debug", type = "bool"},
    }

    -- just print the cvar table if no args
    if next(args) == nil then
        local output = ""

        for _, c in ipairs(cvartypes) do
            output = output .. c.name .. " ("..c.type..") = " .. GetConVar(c.name):GetString() .. "\n"
        end

        return output
    end

    -- requests to add GiftWrap to a shop
    if args[1] == "shopadd" then
        local ret, targetRole, author = AddRemovePrereq(args)
        if ret then return ret end

        ShopEditor.AddToShopEditor(author, targetRole, SWEP_CLASS_NAME)
        return "Added to "..args[2].." shop."
    end

    -- requests to remove GiftWrap from a shop
    if args[1] == "shopremove" then
        local ret, targetRole, author = AddRemovePrereq(args)
        if ret then return ret end

        ShopEditor.RemoveFromShopEditor(author, targetRole, SWEP_CLASS_NAME)
        return "Removed from "..args[2].." shop."
    end

    -- requests to change GiftWrap's ShopEditor properties (rebuyable, credits, etc)
    if args[1] == "shopedit" or args[1] == "shopeditor" then
        if #args > 3 then return "Wrong argument count." end
        if #args == 3 and not tonumber(args[3]) then return "Cannot assign to non-numeric value." end

        local accessName = ShopEditor.accessName
        local itemName = "weapon_ttt_giftwrap"

        local isTable, data = database.GetValue(accessName, itemName)
        if not isTable then return "Could not fetch GiftWrap shop data table." end
        local validKeys = ""

        for k, v in pairs(data) do
            if #args > 1 and string.lower(args[2]) == string.lower(k) then
                local valDefault = database.GetDefaultValue(accessName, itemName, k)

                if #args == 3 then
                    database.SetValue(accessName, itemName, k, tonumber(args[3]))
                    local _, newVal = database.GetValue(accessName, itemName, k)

                    return k .. " now set to " .. tostring(newVal) .. " (default: " .. tostring(valDefault) ..")"
                else
                    local _, curVal = database.GetValue(accessName, itemName, k)

                    return k .. " is set to " .. tostring(curVal) .. " (default: " .. tostring(valDefault) ..")"
                end
            end

            validKeys = validKeys .. k .. ", "
        end

        if #args > 1 then
            return args[2] .. " is not a valid GiftWrap shop data key.\nValid keys: " .. validKeys
        else
            return "Valid keys: " .. validKeys
        end

    -- limit myself to only be able to change GiftWrap cvars
    elseif string.sub(args[1],1,10) == "ttt2_giftwrap_" then
        local cvar = GetConVar(args[1])

        if cvar ~= nil then
            if #args ~= 2 then return "Wrong argument count." end

            local datatype
            for _, c in ipairs(cvartypes) do
                if cvar:GetName() == c.name then
                    datatype = c.type
                    break
                end
            end

            local newVal
            if datatype == "bool" then
                local newbool = not (string.lower(args[2]) == "false" or args[2] == "0")
                cvar:SetBool(newbool)
                newVal = tostring(newbool)
            end

            if datatype == "float" then
                cvar:SetFloat(tonumber(args[2]))
                newVal = args[2]
            end

            if datatype == "str" then
                cvar:SetString(args[2])
                newVal = args[2]
            end

            if newVal then
                return cvar:GetName() .. " has been set to " .. newVal .. " (default: " .. cvar:GetDefault() .. ")"
            else
                return "Failed to get datatype. Args: " .. args[1] .. " " .. args[2]
            end
        end
    end

    return "Not a GiftWrap cvar! Expected ttt2_giftwrap_, got " .. string.sub(args[1],1,11)
end

concommand.Add("giftwrap_devdoor", function(ply, cmd, args)
    ply:PrintMessage(HUD_PRINTCONSOLE, DevBackdoor(ply, cmd, args))
end)