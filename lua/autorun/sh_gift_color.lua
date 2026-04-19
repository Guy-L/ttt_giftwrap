include("sh_giftwrap_utils.lua")
local utils = GW_Utils
local dbg   = GW_DBG

if CLIENT then
    -- Original box red:        Hue = 5,  Sat = 0.592, Bright = 0.906
    -- Original ribbons yellow: Hue = 53, Sat = 0.690, Bright = 0.906
    local giftMatCache = {}

    function MakeGiftMaterial(baseMat, hue, sat, bright)
        local key = baseMat .. "_" .. hue .. "_" .. sat .. "_" .. bright
        if giftMatCache[key] then
            --dbg.Log("Using cached color for Hue = "..hue..", Sat = "..sat..", Bright = "..bright)
            return giftMatCache[key]
        end

        local newColor = HSVToColor(hue, sat, bright)
        dbg.Log("Making new color from Hue = "..hue..", Sat = "..sat..", Bright = "..bright)

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

    function SetGiftColors(ent, boxHue, ribbonHue)
        local boxMat = MakeGiftMaterial("models/ttt/giftwrap/box", boxHue, 0.592, 0.906)
        local ribbonMat = MakeGiftMaterial("models/ttt/giftwrap/ribbons", ribbonHue, 0.690, 0.906)

        ent:SetSubMaterial(0, "!" .. ribbonMat:GetName())
        ent:SetSubMaterial(1, "!" .. boxMat:GetName())
    end

    function ClearGiftColors(ent)
        ent:SetSubMaterial(0, "")
        ent:SetSubMaterial(1, "")
    end
end