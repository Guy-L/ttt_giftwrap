CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"
CLGAMEMODESUBMENU.title = "gift_opt_appearance_title"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/menu_icon_gift")
CLGAMEMODESUBMENU.priority = 100
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

    gwRef:NetworkVarNotify("GiftBoxColor", function(e, name, old, new)
        if not IsValid(boxMixer) then return end
        boxMixer:SetColor(UnpackColor(new))
    end)

    gwRef:NetworkVarNotify("GiftRibbonColor", function(e, name, old, new)
        if not IsValid(ribbonMixer) then return end
        ribbonMixer:SetColor(UnpackColor(new))
    end)
end