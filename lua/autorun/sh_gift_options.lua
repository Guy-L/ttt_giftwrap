include("sh_physics_utils.lua")
local utils = GW_Utils
local dbg   = GW_DBG

GIFTWRAP_DROP_CONT_MSG      = "TTT_GiftWrapCL_DropContentRequest"
GIFTWRAP_RANDOM_GIFT_MSG    = "TTT_GiftWrapCL_RandomContentRequest"
GIFTWRAP_UPDATE_GIFTEE_MSG  = "TTT_GiftWrapCL_UpdateGifteeMsg"
GIFTWRAP_UPDATE_NOTE_MSG    = "TTT_GiftWrapCL_UpdateNoteMsg"
GIFTWRAP_DELETE_SELF_MSG    = "TTT_GiftWrapCL_DebugDeleteSelfMsg"
GIFTWRAP_REMOVE_WRAPPER_MSG = "TTT_GiftWrapCL_DebugRemoveWrapperTagMsg"
GIFTWRAP_DBG_SELECT_MSG     = "TTT_GiftWrapCL_DebugSelectGiftLabelMsg"

local GIFTWRAP_CLEAR_BUY_MSG = "TTT_GiftWrapSV_ClearGiftBoughtFlag"
local GIFTWRAP_CLOSE_DMS_MSG = "TTT_GiftWrapSV_CloseDeathMatchShop"
local GIFTWRAP_IN_OPTS_MSG   = "TTT_GiftWrapCL_InOptionsMenu"
local HOOK_ORDER_EQUIPMENT   = "TTT_GiftWrapSV_OrderedEquipment"
local HOOK_INIT_FIXES        = "TTT_GiftWrapSV_InitDoFixes"


if CLIENT then
    -- note: inspired by but mostly separate from the HELPSCRN menu,
    --       only uses its table to store some references
    local navWidth = 175
    local frameWidth  = 800
    local frameHeight = 500
    local padding = 5

    function OpenGiftOptions(gw)
        if IsValid(HELPSCRN._gwOptMenu) then return end

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
                timer.Simple(0.4, function()
                    if IsValid(catcher) then
                        catcher:MouseCapture(false)
                    end
                end)

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

    function UpdateGiftContentMenu(owner)
        if IsValid(owner) and owner ~= LocalPlayer() then return end

        if IsValid(HELPSCRN._gwOptMenu) and IsValid(HELPSCRN._gwOptMenu.contentsBtn) then
            dbg.Log("Reloading content menu due to change for owner", owner)
            HELPSCRN._gwOptMenu.contentsBtn.DoClick(HELPSCRN._gwOptMenu.contentsBtn)
        end
    end

    function RemoveResetButton(panel)
        local reset = panel:GetResetButton()

        if IsValid(reset) then
            reset:Remove()
        end
    end

    net.Receive(GIFTWRAP_CLEAR_BUY_MSG, function()
        local equipmentName = net.ReadString()
        local ply = LocalPlayer()

        for i = #ply.bought, 1, -1 do
            if ply.bought[i] == equipmentName then
                table.remove(ply.bought, i)
            end
        end
        shop.buyTable[ply][equipmentName] = nil
    end)

    net.Receive(GIFTWRAP_CLOSE_DMS_MSG, function()
        for _, pnl in ipairs(vgui.GetWorldPanel():GetChildren()) do
            if pnl.GetTitle and pnl:GetTitle() == "Deathmatch Shop" then
                pnl:Close()
            end
        end
    end)


elseif SERVER then
    util.AddNetworkString(GIFTWRAP_CLEAR_BUY_MSG)
    util.AddNetworkString(GIFTWRAP_CLOSE_DMS_MSG)
    util.AddNetworkString(GIFTWRAP_DROP_CONT_MSG)
    util.AddNetworkString(GIFTWRAP_RANDOM_GIFT_MSG)
    util.AddNetworkString(GIFTWRAP_UPDATE_GIFTEE_MSG)
    util.AddNetworkString(GIFTWRAP_UPDATE_NOTE_MSG)
    util.AddNetworkString(GIFTWRAP_DELETE_SELF_MSG)
    util.AddNetworkString(GIFTWRAP_REMOVE_WRAPPER_MSG)
    util.AddNetworkString(GIFTWRAP_DBG_SELECT_MSG)
    util.AddNetworkString(GIFTWRAP_IN_OPTS_MSG)

    net.Receive(GIFTWRAP_DROP_CONT_MSG, function(len, ply)
        local giftEnt = net.ReadEntity()
        if not IsValid(giftEnt) then return end

        giftEnt:Reload()
    end)

    net.Receive(GIFTWRAP_RANDOM_GIFT_MSG, function(len, ply)
        local giftEnt = net.ReadEntity()
        if not IsValid(giftEnt) then return end
        dbg.Log("Random gift request by "..ply:Nick())

        if ply:GetCredits() > 0 or GetGlobalBool("ttt2_deathmatch_active", false) then
            local newLabel, newData = GetRandomGiftData(ply, 20)
            giftEnt:AutoWrap(newLabel, newData)
            ply:AddCredits(-1)
        end
    end)

    net.Receive(GIFTWRAP_UPDATE_GIFTEE_MSG, function(len, ply)
        local giftEnt = net.ReadEntity()
        local gifteeSID = net.ReadString()
        if not IsValid(giftEnt) then return end

        local gifteePly = player.GetBySteamID64(gifteeSID)
        local isPlayer = IsValid(gifteePly)

        if not isPlayer and gifteeSID != "any" then
            dbg.Log("Rejected invalid giftee selection:", gifteeSID)
            return
        end

        giftEnt:SetGiftee(isPlayer and gifteePly or NULL)
    end)

    net.Receive(GIFTWRAP_UPDATE_NOTE_MSG, function(len, ply)
        local giftEnt = net.ReadEntity()
        local giftNote = net.ReadString()
        if not IsValid(giftEnt) then return end

        giftEnt:SetUnwrapNote(giftNote)
    end)

    net.Receive(GIFTWRAP_DELETE_SELF_MSG, function(len, ply)
        local giftEnt = net.ReadEntity()
        if not IsValid(giftEnt) then return end
        if not dbg.AllowDebugMenu() then return end

        giftEnt:Remove()
    end)

    net.Receive(GIFTWRAP_REMOVE_WRAPPER_MSG, function(len, ply)
        local giftEnt = net.ReadEntity()
        if not IsValid(giftEnt) then return end
        if not dbg.AllowDebugMenu() then return end

        giftEnt:SetWrapperSID("WORLD")
    end)

    net.Receive(GIFTWRAP_DBG_SELECT_MSG, function(len, ply)
        local giftEnt = net.ReadEntity()
        local giftLabel = net.ReadString()
        if not IsValid(giftEnt) then return end
        if not dbg.AllowDebugMenu() then return end

        local giftData = GetGiftDataFromLabel(giftLabel):Furnish(ply)
        if giftData then
            giftEnt:AutoWrap(giftLabel, giftData)
        else
            dbg.Log("(Debug) Invalid label received for wrapping: "..giftLabel)
        end
    end)

    net.Receive(GIFTWRAP_IN_OPTS_MSG, function(len, ply)
        ply._gwInOptMenu = net.ReadBool()
    end)

    -- handle ordering equipment for gift
    local function InterceptPurchaseForGift(ply, equipmentName, isItem)
        if not ply._gwInOptMenu then return false end
        local giftEnt = utils.GetInventoryGiftwrap(ply)
        if not giftEnt or giftEnt:HasGift() then return false end

        dbg.Log(ply:Nick()..": Wrapping "..equipmentName.." into gift...")
        local equip = utils.GetEquipment(ply, equipmentName)
        if not equip then return false end

        if isItem then
            local newLabel, newData = GetItemGiftData(equipmentName)
            giftEnt:AutoWrap(newLabel, newData)
            ply:RemoveEquipmentItem(equip)
            newData:ApplyPostGiftPurchaseAdjustments(ply)

        else
            giftEnt:AutoWrap(GetSWEPGiftData(equipmentName))

            if equipmentName ~= SWEP_CLASS_NAME then
                equip:Remove()
            end
        end

        if shop.buyTable[ply] then -- clear bought flag in shop
            shop.buyTable[ply][equipmentName] = false

            net.Start(GIFTWRAP_CLEAR_BUY_MSG)
            net.WriteString(equipmentName)
            net.Send(ply)
        end

        return true
    end

    hook.Add("TTT2OrderedEquipment", HOOK_ORDER_EQUIPMENT, function(ply, equipmentName, isItem, credits, ignoreCost)
        InterceptPurchaseForGift(ply, equipmentName, isItem)

        -- give 1cred on 1st giftwrap purchase for roles starting with 1 credits
        if not ply._gwInOptMenu and equipmentName == SWEP_CLASS_NAME and not ply:GetNWBool("GotFirstTimeSample") then
            local startCreds = ply:GetSubRoleData():GetStartingCredits()

            if startCreds <= 2 then
                ply:AddCredits(1)
                ply:SetNWBool("GotFirstTimeSample", true)
            end
        end
    end)

    local function extendDeathmatchBuy()
        -- hack to extend original Snuffles Deathmatch buy receiver (no hook)
        _gwOGBoughRec = _gwOGBoughRec or net.Receivers["dm_customshop_buy"]

        net.Receive("dm_customshop_buy", function(len, ply)
            local class, isItem
            _gwOGReadString = _gwOGReadString or net.ReadString
            _gwOGReadBool = _gwOGReadBool or net.ReadBool

            -- intercept data into this scope when OG addon reads it
            net.ReadString = function()
                class = _gwOGReadString()
                return class
            end

            net.ReadBool = function()
                isItem = _gwOGReadBool()
                return isItem
            end

            _gwOGBoughRec(len, ply)
            net.ReadString = _gwOGReadString
            net.ReadBool = _gwOGReadBool

            if InterceptPurchaseForGift(ply, class, isItem) then
                net.Start(GIFTWRAP_CLOSE_DMS_MSG)
                net.Send(ply)
            end
        end)
    end

    hook.Add("InitPostEntity", HOOK_INIT_FIXES, function()
        extendDeathmatchBuy()
    end)

    extendDeathmatchBuy() --delme, move contents to HOOK
end