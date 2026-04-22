CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"
CLGAMEMODESUBMENU.title = "gift_opt_debug_title"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/vskin/helpscreen/administration")
CLGAMEMODESUBMENU.priority = 0
local utils = GW_Utils
local dbg   = GW_DBG

function CLGAMEMODESUBMENU:ShouldShow()
    return dbg.Cvar:GetBool() or GetGlobalBool("ttt2_deathmatch_active", false)
end

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

    ------------------------------------
    -- Debug ---------------------------
    local debugForm = vgui.CreateTTT2Form(parent, "gift_opt_debug_form")

    local anonBtn = debugForm:MakeButton({
        label = "gift_opt_debug_form_anonymize_desc",
        buttonLabel = "gift_opt_debug_form_anonymize",
        OnClick = function(slf)
            net.Start(GIFTWRAP_REMOVE_WRAPPER_MSG)
            net.WriteEntity(gwRef)
            net.SendToServer()
            HELPSCRN._gwOptMenu:Close()
        end
    })

    if not gwRef:HasGift() then
        anonBtn:SetEnabled(false)
        anonBtn:SetTooltip(LANG.TryTranslation("gift_opt_change_form_drop_error_none"))
    end
end