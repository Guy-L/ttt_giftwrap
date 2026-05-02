CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"
CLGAMEMODESUBMENU.title = "gift_opt_appearance_title"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/menu/icon_gift")
CLGAMEMODESUBMENU.priority = 99
local utils = GW_Utils
local dbg   = GW_DBG

local mixerHeight = 150
local mixerShowPalette = false

function CLGAMEMODESUBMENU:Populate(parent)
    local gwRef = HELPSCRN._gwRef

    if not IsValid(gwRef) then
        local error_line = vgui.Create("DLabel", parent)
        error_line:SetPos(40, 40)
        error_line:SetFont("DermaLarge")
        error_line:SetText(LANG.TryTranslation("gift_opt_error"))
        error_line:SizeToContents()
        return
    end

    ------------------------------------------
    -- Gift Colors ---------------------------
    local colorForm = vgui.CreateTTT2Form(parent, "gift_opt_color_form")

    colorForm:MakeButton({
        label = "gift_opt_color_form_reroll_desc",
        buttonLabel = "gift_opt_color_form_reroll",
        OnClick = function(slf)
            net.Start(GIFTWRAP_REROLL_COLOR_MSG)
            net.WriteEntity(gwRef)
            net.SendToServer()
        end
    })

    local boxMixer = colorForm:MakeColorMixer({
        label = "gift_opt_color_form_box",
        initial = UnpackColor(gwRef:GetGiftBoxColor()),
        showPalette = mixerShowPalette,
        height = mixerHeight,
        OnChange = function(_, color)
            net.Start(GIFTWRAP_UPDATE_COLOR_MSG)
            net.WriteEntity(gwRef)
            net.WriteUInt(PackColor(color), 32)
            net.WriteBool(false)
            net.SendToServer()
        end
    }):GetChildren()[1]

    local ribbonMixer = colorForm:MakeColorMixer({
        label = "gift_opt_color_form_ribbon",
        initial = UnpackColor(gwRef:GetGiftRibbonColor()),
        showPalette = mixerShowPalette,
        height = mixerHeight,
        OnChange = function(_, color)
            net.Start(GIFTWRAP_UPDATE_COLOR_MSG)
            net.WriteEntity(gwRef)
            net.WriteUInt(PackColor(color), 32)
            net.WriteBool(true)
            net.SendToServer()
        end
    }):GetChildren()[1]

    net.Receive(GIFTWRAP_SYNC_COLORS_MSG, function()
        timer.Simple(0.01, function() -- safety sync wait
            local boxColor = gwRef:GetGiftBoxColor()
            local ribbonColor = gwRef:GetGiftRibbonColor()

            if IsValid(boxMixer) then boxMixer:SetColor(UnpackColor(boxColor)) end
            if IsValid(ribbonMixer) then ribbonMixer:SetColor(UnpackColor(ribbonColor)) end
        end)
    end)
end