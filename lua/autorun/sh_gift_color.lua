include("sh_physics_utils.lua")
local utils = GW_Utils
local dbg   = GW_DBG

local HOOK_GIFTWRAP_TRANSMIT = "TTT_GiftWrapCL_ReRenderGift"
GIFTWRAP_UPDATE_COLOR_MSG = "TTT_GiftWrapCL_UpdateColorMsg"
GIFTWRAP_REROLL_COLOR_MSG = "TTT_GiftWrapCL_RerollColorMsg"
GIFTWRAP_SYNC_COLORS_MSG  = "TTT_GiftWrapSV_UpdateColorMixers"


function PackColor(c)
    return bit.lshift(c.r, 16) + bit.lshift(c.g, 8) + c.b
end

function UnpackColor(i)
    return Color(
        bit.rshift(i, 16) % 256,
        bit.rshift(i, 8) % 256,
        i % 256
    )
end

if CLIENT then
    -- Original box red:        Hue = 5,  Sat = 0.592, Bright = 0.906
    -- Original ribbons yellow: Hue = 53, Sat = 0.690, Bright = 0.906
    local giftMatCache = {}

    function MakeGiftMaterial(baseMat, colorCode)
        local key = baseMat .. "_" .. colorCode
        if giftMatCache[key] then
            return giftMatCache[key]
        end

        local newColor = UnpackColor(colorCode)
        dbg.Log("Making new color from Red = "..newColor.r..", Green = "..newColor.g..", Blue = "..newColor.b)

        local giftMat = CreateMaterial(
            "gift_" .. util.CRC(key),
            "VertexLitGeneric", {
                ["$basetexture"] = "models/debug/debugwhite",
                ["$model"]      = 1,
                ["$phong"]      = 1,
                ["$phongboost"] = 1,
                ["$phongexponent"] = 20,
                ["$color2"] = "["
                    ..(newColor.r / 255).." "
                    ..(newColor.g / 255).." "
                    ..(newColor.b / 255).."]"
            }
        )

        giftMatCache[key] = giftMat
        return giftMat
    end

    function SetGiftColors(ent, boxColor, ribbonColor)
        local boxMat = MakeGiftMaterial("models/ttt/giftwrap/box", boxColor)
        local ribbonMat = MakeGiftMaterial("models/ttt/giftwrap/ribbons", ribbonColor)

        ent:SetSubMaterial(0, "!" .. ribbonMat:GetName())
        ent:SetSubMaterial(1, "!" .. boxMat:GetName())
    end

    function SyncGiftColors(ent, delay)
        if not delay then
            SetGiftColors(ent, ent:GetGiftBoxColor(), ent:GetGiftRibbonColor())

        else
            timer.Simple(delay, function()
                ent:SyncColors()
            end)
        end
    end

    function ClearGiftColors(ent)
        ent:SetSubMaterial(0, "")
        ent:SetSubMaterial(1, "")
    end

    -- gift leaving PVS makes it lose its materials, so we re-sync
    hook.Add("NotifyShouldTransmit", HOOK_GIFTWRAP_TRANSMIT, function(ent, shouldTransmit)
        if ent:GetClass() == PROP_CLASS_NAME and ent.GetGiftBoxColor and shouldTransmit then
            SyncGiftColors(ent)
        end
    end)


elseif SERVER then
    util.AddNetworkString(GIFTWRAP_UPDATE_COLOR_MSG)
    util.AddNetworkString(GIFTWRAP_REROLL_COLOR_MSG)
    util.AddNetworkString(GIFTWRAP_SYNC_COLORS_MSG)

    local hueBias = {
        {min = 200, max = 280, reroll = 0.6}, -- blue/purple
        {min = 60,  max = 120, reroll = 0.4}, -- orange to green
    }

    local function ShouldRerollHue(hue)
        for _, range in ipairs(hueBias) do
            if hue >= range.min and hue <= range.max then
                if math.random() < range.reroll then
                    return true
                end
            end
        end
        return false
    end

    function RollGiftColors(ent)
        local boxHue

        repeat
            boxHue = math.random(0, 360)
        until not ShouldRerollHue(boxHue)
        local ribbonHue = (boxHue + (math.random() <= 0.25 and math.random(180-50, 180+50) or 50)) % 360

        local boxColor = PackColor(HSVToColor(boxHue, 0.592, 0.906))
        local ribbonColor = PackColor(HSVToColor(ribbonHue, 0.690, 0.906))

        ent:SetGiftBoxColor(boxColor)
        ent:SetGiftRibbonColor(ribbonColor)

        -- done separately from network var update to prevent an infinite loop
        local owner = ent:GetOwner()

        if IsValid(owner) then
            net.Start(GIFTWRAP_SYNC_COLORS_MSG)
            net.Send(owner)
        end
    end

    net.Receive(GIFTWRAP_UPDATE_COLOR_MSG, function(len, ply)
        local giftEnt  = net.ReadEntity()
        local color    = net.ReadUInt(32)
        local isRibbon = net.ReadBool()

        if not IsValid(giftEnt) then return end
        if isRibbon then
            giftEnt:SetGiftRibbonColor(color)
        else
            giftEnt:SetGiftBoxColor(color)
        end
    end)

    net.Receive(GIFTWRAP_REROLL_COLOR_MSG, function(len, ply)
        local giftEnt = net.ReadEntity()
        if not IsValid(giftEnt) then return end

        RollGiftColors(giftEnt)
    end)
end
