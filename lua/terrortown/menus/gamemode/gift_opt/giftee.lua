CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"
CLGAMEMODESUBMENU.title = "gift_opt_giftee_title"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/menu/icon_label")
CLGAMEMODESUBMENU.priority = 98
local utils = GW_Utils
local dbg   = GW_DBG


function CLGAMEMODESUBMENU:Populate(parent)
    local gwRef = HELPSCRN._gwRef

    if not IsValid(gwRef) then
        local error_line = vgui.Create("DLabel", parent)
        error_line:SetPos(40, 40)
        error_line:SetFont("DermaLarge")
        error_line:SetText(utils.TL("gift_opt_error"))
        error_line:SizeToContents()
        return
    end

    ------------------------------------
    -- Giftee Selection ----------------
    local client = LocalPlayer()
    local gifteeForm = vgui.CreateTTT2Form(parent, "gift_opt_giftee_form")
    local gifteeFormAnyName = utils.TL("gift_opt_giftee_form_any")
    local prevGiftee = gwRef:GetGiftee()

    local gifteeChoices = {
        { title = gifteeFormAnyName, value = "any" }
    }

    for _, ply in ipairs(player.GetAll()) do
        if ply != client and not utils.ConfirmedDead(client, ply) then
            table.insert(gifteeChoices, {
                title = ply:Nick(),
                value = ply:SteamID64(),
                select = prevGiftee == ply
            })
        end
    end

    gifteeForm:MakeHelp({
        label = "gift_opt_giftee_form_select_desc"
    })
    local gifteeSelect = gifteeForm:MakeComboBox({
        label = "gift_opt_giftee_form_select",
        choices = gifteeChoices,
        default = "any"
    })

    gifteeSelect:SetSortItems(false)
    gifteeSelect.OnSelect = function(slf, index, value, extraData)
        gifteeSelect:GetResetButton():SetEnabled(value != "any")

        net.Start(GIFTWRAP_UPDATE_GIFTEE_MSG)
        net.WriteEntity(gwRef)
        net.WriteString(value)
        net.SendToServer()
    end

    if(gifteeSelect:GetText() == "") then
        gifteeSelect:ChooseOptionID(1)
    end

    -- this is fucking stupid but there's no other way to set
    -- dropdown select icons to be arbitrary pathless materials
    local ogOpenFunc = gifteeSelect.OpenMenu
    gifteeSelect.OpenMenu = function(self, pControlOpener)
        ogOpenFunc(self, pControlOpener)

        for _, el in ipairs(utils.GetChildNamed(self.menu, "Panel"):GetChildren()) do
            local optName = el:GetText()

            if optName == gifteeFormAnyName then
                el:SetIcon("vgui/ttt/menu/icon_globe")

            else
                for _, ply in ipairs(player.GetAll()) do
                    if ply:Nick() == optName then
                        local pfpM, pfpT = utils.GetAvatar(ply:SteamID64())
                        el:SetMaterial(pfpM)
                    end
                end
            end
        end
    end


    ------------------------------------
    -- On-Open Effects -----------------
    local unwrapForm = vgui.CreateTTT2Form(parent, "gift_opt_unwrap_form")

    local left, right = unwrapForm:MakeTextEntry({
        label = "gift_opt_unwrap_form_note",
        initial = gwRef:GetUnwrapNote(),
        OnChange = function(slf, val)
            net.Start(GIFTWRAP_UPDATE_NOTE_MSG)
            net.WriteEntity(gwRef)
            net.WriteString(val)
            net.SendToServer()
        end
    })

    right:SetUpdateOnType(true)
    RemoveResetButton(right)
end