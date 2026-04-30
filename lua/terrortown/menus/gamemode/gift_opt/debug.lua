CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"
CLGAMEMODESUBMENU.title = "gift_opt_debug_title"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/vskin/helpscreen/administration")
CLGAMEMODESUBMENU.priority = 0
local utils = GW_Utils
local dbg   = GW_DBG

function CLGAMEMODESUBMENU:ShouldShow()
    return dbg.AllowDebugMenu()
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

    -- prepare gift choices (check spawnable)
    local giftChoices = {}
    for label, giftData in pairs(GetGiftCatalog()) do
        if giftData:IsSpawnable(LocalPlayer()) then
            table.insert(giftChoices, {
                title = giftData.name,
                value = label
            })
        end
    end

    labelSelectVal = nil
    local labelSelect = debugForm:MakeComboBox({
        label = "gift_opt_debug_form_select_label",
        choices = giftChoices,
        enableRun = true,
        OnChange = function(val)
            labelSelectVal = val
        end,
        OnClickRun = function(slf)
            if labelSelectVal then
                net.Start(GIFTWRAP_DBG_SELECT_MSG)
                net.WriteEntity(gwRef)
                net.WriteString(labelSelectVal)
                net.SendToServer()
                HELPSCRN._gwOptMenu:Close()
            end
        end
    })
    RemoveResetButton(labelSelect)

    if gwRef:HasGift() then -- disable all
        for _, el in ipairs(labelSelect:GetParent():GetChildren()) do
            el:SetEnabled(false)
            el:SetTooltip(LANG.TryTranslation("gift_opt_change_form_error_full"))
        end
    end
end