CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"
CLGAMEMODESUBMENU.title = "gift_opt_giftee_title"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/menu_icon_label")
CLGAMEMODESUBMENU.priority = 98
local utils = GW_Utils
local dbg   = GW_DBG


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
    -- On-Open Effects -----------------
    local unwrapForm = vgui.CreateTTT2Form(parent, "gift_opt_unwrap_form")

    --local noteMaxLength = 150
    local left, right = unwrapForm:MakeTextEntry({
        label = "gift_opt_unwrap_form_note",
        initial = gwRef:GetUnwrapNote(),
        OnChange = function(slf, val)
            --if #val > noteMaxLength then
            --    val = string.sub(val, 1, noteMaxLength)
            --    slf:SetValue(val)
            --end

            net.Start(GIFTWRAP_UPDATE_NOTE_MSG)
            net.WriteEntity(gwRef)
            net.WriteString(val)
            net.SendToServer()
        end
    })

    right:SetUpdateOnType(true)
    RemoveResetButton(right)
end