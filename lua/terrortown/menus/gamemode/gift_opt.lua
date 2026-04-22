--- @ignore
local utils = GW_Utils
local dbg   = GW_DBG

local HOOK_DETECT_RCLICK = "TTT_GiftWrap_DetectRightClickInMenu"
CLGAMEMODEMENU.base = "base_gamemodemenu"
CLGAMEMODEMENU.title = "gift_opt_title"

function CLGAMEMODEMENU:ShouldShow()
    return false
end

-- note: inspired by but mostly separate from the HELPSCRN menu,
--       only uses its table to store some references
local navWidth = 175
local frameWidth  = 800
local frameHeight = 500
local padding = 5

function OpenGiftOptions(gw)
    local ply = LocalPlayer()
    if not IsValid(ply) or IsValid(HELPSCRN._gwOptMenu) then
        return
    end

    dbg.Log("Opening gift options...")
    HELPSCRN._gwRef = gw -- Make gift reference global for menu (bad but idk)

    for _, menu in ipairs(menusIndexed) do
        if menu.type == "gift_opt" then
            local frame = vguihandler.GenerateFrame(frameWidth, frameHeight, "")
            frame:SetPadding(0, 0, 0, 0)
            HELPSCRN._gwOptMenu = frame

            -- Build nav & content areas
            local navArea = vgui.Create("DNavPanelTTT2", frame)
            navArea:SetWide(navWidth)
            navArea:SetPos(0, 0)
            navArea:DockPadding(0, 0, 1, 0)
            navArea:Dock(LEFT)

            local contentArea = vgui.Create("DContentPanelTTT2", frame)
            contentArea:SetSize(
                frameWidth - navWidth,
                frameHeight - vskin.GetHeaderHeight() - vskin.GetBorderSize()
            )
            contentArea:SetPos(navWidth, 0)
            contentArea:DockPadding(padding, padding, padding, padding)
            contentArea:Dock(TOP)

            -- Populate with submenus
            local submenuList = vgui.Create("DSubmenuListTTT2", navArea)
            submenuList:Dock(FILL)
            submenuList:SetPadding(padding)
            submenuList:SetBasemenuClass(menu, contentArea)

            -- Make submenu buttons change frame title
            local submenuBtns = utils.GetChildNamed(submenuList, "DScrollPanelTTT2")
            submenuBtns = utils.GetChildNamed(submenuBtns, "Panel")
            submenuBtns = utils.GetChildNamed(submenuBtns, "DIconLayout")

            for _, submenuButton in ipairs(submenuBtns:GetChildren()) do
                local smbTitle = submenuButton:GetTitle()
                if smbTitle == "gift_opt_contents_title" then
                    frame.contentsBtn = submenuButton
                end

                local ogDoClick = submenuButton.DoClick
                submenuButton.DoClick = function(self)
                    frame:SetTitle(smbTitle)
                    ogDoClick(self)
                end
            end
            submenuList:SelectFirst() -- to proc title change

            -- Full-screen right click catcher panel to close menu
            local catcher = vgui.Create("DPanel")
            catcher:SetPos(0, 0)
            catcher:SetSize(ScrW(), ScrH())
            catcher:SetPaintBackground(false)
            catcher:MouseCapture(true)

            catcher.OnMousePressed = function(self, code)
                if code == MOUSE_RIGHT then
                    HELPSCRN._gwOptMenu:Close()
                    return true
                end
            end

            -- Tell server client is in menu state
            net.Start(GIFTWRAP_IN_OPTS_MSG)
            net.WriteBool(true)
            net.SendToServer()

            -- Overwrite frame on-close to notify server & client
            function frame:OnClose()
                dbg.Log("Gift options menu closed")
                HELPSCRN._gwOptMenu = nil
                catcher:Remove()

                net.Start(GIFTWRAP_IN_OPTS_MSG)
                net.WriteBool(false)
                net.SendToServer()
            end
            break
        end
    end
end

function UpdateGiftContentMenu()
    if IsValid(HELPSCRN._gwOptMenu) and IsValid(HELPSCRN._gwOptMenu.contentsBtn) then
        dbg.Log("Reloading content menu due to change...")
        HELPSCRN._gwOptMenu.contentsBtn.DoClick(HELPSCRN._gwOptMenu.contentsBtn)
    end
end
