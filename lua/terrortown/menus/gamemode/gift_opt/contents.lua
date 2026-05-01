--- @ignore
CLGAMEMODESUBMENU.base  = "base_gamemodesubmenu"
CLGAMEMODESUBMENU.title = "gift_opt_contents_title"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/menu_icon_box_hole")
CLGAMEMODESUBMENU.priority = 100
local utils = GW_Utils
local dbg   = GW_DBG
local TL    = LANG.TryTranslation

local curcont_bg = Color(90, 90, 95, 255)
local curcont_graytext = Color(150, 150, 150)
local curcont_pad = 20

local queuedSpawnIcons = {}
local lastRequestingImg = nil

local function GenerateSpawnIcon(model)
    dbg.Log("Building icon for "..model.."...")

    local wipSpawnIcon = vgui.Create("SpawnIcon", HELPSCRN._gwOptMenu)
    wipSpawnIcon:SetPos(-1000, -1000)
    wipSpawnIcon:SetModel(model)
    wipSpawnIcon:RebuildSpawnIcon()
    queuedSpawnIcons[model] = wipSpawnIcon
end

hook.Add("SpawniconGenerated", "TEST_GW_SPAWNICON", function(lastModel, imageName, modelsLeft)
    if queuedSpawnIcons[lastModel] then
        queuedSpawnIcons[lastModel]:Remove() -- TODO: broken, currently "fixed" by hiding wip icon off-screen (-1000, -1000)
        queuedSpawnIcons[lastModel] = nil

        -- if still available, set the image of the lastRequesting canvas to the generated image
        if IsValid(lastRequestingImg) then
            local imgPath = "spawnicons/" .. string.StripExtension(lastModel) .. ".png"

            if file.Exists("materials/" .. imgPath, "GAME") then
                lastRequestingImg:SetImage(imgPath)
            end
        end
    end
end)

function SetModelImage(dImage, ent, giftData)
    local entModel

    if IsValid(ent) then
        entModel = ent:GetModel()
        dbg.Log("Got preview image from live model:", entModel)

    elseif giftData then
        local giftImgPath, isMat = giftData:GetVisuals()

        if giftImgPath then
            dbg.Log("Got preview image from data:", giftImgPath)
            entModel = giftImgPath

            if isMat then
                dImage:SetImage(entModel)
                return
            end
        else
            dbg.Log("Failed to retrieve preview image from data")
        end
    end

    if not entModel then
        dImage:SetImage("vgui/ttt/vskin/icon_cross")
        return
    end

    local imgPath = "spawnicons/" .. string.StripExtension(entModel) .. ".png"

    if file.Exists("materials/"..imgPath, "GAME") then
        dImage:SetImage(imgPath)

    else
        dImage:SetImage("icon16/help.png")
        lastRequestingImg = dImage
        GenerateSpawnIcon(entModel)
    end
end

function CreateStatusTable(parent, statusTable)
    parent:SetWide(200)
    local rowTall = 40

    for i, status in ipairs(statusTable) do
        local row = vgui.Create("DPanel", parent)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 6)
        row:SetTall(rowTall)
        row.Paint = nil

        -- LEFT: icon container
        local iconPanel = vgui.Create("DPanel", row)
        iconPanel:Dock(LEFT)
        iconPanel:SetWide(rowTall)
        iconPanel.Paint = nil

        local icon = vgui.Create("DImage", iconPanel)
        icon:SetImage(status.icon)
        icon:SetSize(24, 24)

        icon.PerformLayout = function(self)
            local pw, ph = self:GetParent():GetSize()
            self:SetPos((pw - self:GetWide()) / 2, (ph - self:GetTall()) / 2)
        end

        -- RIGHT: multiline text container
        local textPanel = vgui.Create("DPanel", row)
        textPanel:Dock(FILL)
        textPanel.Paint = nil

        local label = vgui.Create("DLabel", textPanel)
        label:Dock(FILL)
        label:SetText(utils.TL(status.text))
        label:SetWrap(true)
        label:SetFont("HudHintTextLarge")
        label:SetContentAlignment(4)
    end
end

function CreateCurrentContentsBox(storedEnt, giftData, parent)
    local curContents = vgui.Create("DPanel", parent)
    curContents:SetPaintBackground(true)
    curContents:SetBackgroundColor(curcont_bg)
    curContents.Paint = function(self, w, h)
        surface.SetDrawColor(curcont_bg)
        surface.DrawRect(0, 0, w, h)
    end
    curContents:Dock(TOP)
    curContents:DockMargin(curcont_pad, curcont_pad, curcont_pad, curcont_pad)
    curContents:SetTall(giftData and 150 or 100)

    -- HEADER
    local header = vgui.Create("DPanel", curContents)
    header:Dock(TOP)
    header:SetTall(30)

    header.Paint = function(self, w, h)
        surface.SetDrawColor(60, 60, 65, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local headerLabel = vgui.Create("DLabel", header)
    headerLabel:Dock(LEFT)
    headerLabel:DockMargin(10, 0, 0, 0)

    headerLabel:SetFont("DermaDefaultBold")
    headerLabel:SetText(TL("gift_opt_current_content"))
    headerLabel:SizeToContents()
    headerLabel:SetContentAlignment(4)

    -- LEFT: image preview container
    local imgPanel = vgui.Create("DPanel", curContents)
    imgPanel:Dock(LEFT)
    imgPanel:DockMargin(10, 10, 10, 10)
    imgPanel.PerformLayout = function(self, w, h)
        local size = h * 0.7
        self:SetWide(size)
        self:SetTall(size)
    end
    imgPanel.Paint = nil

    local contentImg = vgui.Create("DImage", imgPanel)
    contentImg:Dock(FILL)
    SetModelImage(contentImg, storedEnt, giftData)
    contentImg:SetKeepAspect(true)

    -- RIGHT: status container
    local statusPanel = vgui.Create("DPanel", curContents)
    statusPanel:Dock(RIGHT)
    statusPanel:DockPadding(5, 10, 10, 10)
    statusPanel:SetWide(0)

    local statusTable = giftData and giftData:GetStatusTable(storedEnt) or {}
    if #statusTable > 0 then
        CreateStatusTable(statusPanel, statusTable)
    end

    -- MIDDLE: info text container
    local textPanel = vgui.Create("DPanel", curContents)
    textPanel:Dock(FILL)
    textPanel:DockPadding(5, 10, 10, 10)
    textPanel.Paint = nil

    local name = vgui.Create("DLabel", textPanel)
    name:Dock(TOP)
    name:SetFont("DermaLarge")
    name:SetText(giftData and giftData:GetName() or "Nothing yet")
    name:SetTall(30)

    if giftData and giftData.placeholderEquip then
        local desc = vgui.Create("DLabel", textPanel)
        desc:Dock(TOP)
        desc:SetText("(auto-generated)\n" .. giftData:GetDesc(storedEnt, LocalPlayer()))
        desc:SetWrap(true)
        desc:SetAutoStretchVertical(true)
        desc:SetTextColor(curcont_graytext)
        desc:SetTall(20)

    else
        local desc
        if giftData then
            local giftDesc = giftData:GetDesc(storedEnt, LocalPlayer())
            desc = FancyLine(textPanel, "It's ", giftDesc, giftData.autoGen and "! (auto-generated)" or "!")
        else
            desc = FancyLine(textPanel, "Go find something they'll ", "love", "!")
        end
        desc:SetTall(20)
        desc:DockMargin(0, 0, 0, 4)
        desc:SetWrap(true)

        if giftData then
            AttributeLine(textPanel, "sounds", giftData.attrib_sound and giftData.attrib_sound.desc or nil, "It doesn't make a distinct sound")
            AttributeLine(textPanel, "smells", giftData.attrib_smell, "It doesn't smell like anything")
            AttributeLine(textPanel, "feels",  giftData.attrib_feel, "Just holding it doesn't tell you much")
        end
    end
end

function FancyLine(parent, leftGrayText, whiteText, rightGrayText)
    local line = vgui.Create("DPanel", parent)
    line:Dock(TOP)

    local leftPart = vgui.Create("DLabel", line)
    leftPart:Dock(LEFT)
    leftPart:SetText(leftGrayText)
    leftPart:SetTextColor(curcont_graytext)
    leftPart:SizeToContents()

    if whiteText then
        local whitePart = vgui.Create("DLabel", line)
        whitePart:Dock(LEFT)
        whitePart:SetText(whiteText)
        whitePart:SetTextColor(color_white)
        whitePart:SizeToContents()
    end

    if rightGrayText then
        local rightPart = vgui.Create("DLabel", line)
        rightPart:Dock(LEFT)
        rightPart:SetText(rightGrayText)
        rightPart:SetTextColor(curcont_graytext)
        rightPart:SizeToContents()
    end

    line:SetTall(leftPart:GetTall())
    return line
end

function AttributeLine(parent, verb, value, placeholder)
    local attrLine

    if value then
        attrLine = FancyLine(parent, "→ It "..verb.." ", value, "...")
    else
        attrLine = FancyLine(parent, "→ "..placeholder.."...")
    end

    attrLine:SizeToContentsY()
    attrLine:DockMargin(0, 0, 0, 2)

    return attrLine
end

function CLGAMEMODESUBMENU:Populate(parent)
    local gwRef = HELPSCRN._gwRef

    if not IsValid(gwRef) then
        local error_line = vgui.Create("DLabel", parent)
        error_line:SetPos(40, 40)
        error_line:SetFont("DermaLarge")
        error_line:SetText(TL("gift_opt_error"))
        error_line:SizeToContents()
        return
    end

    -----------------------------------------------
    -- Current Contents ---------------------------
    local giftEnt  = gwRef:GetStoredGift()
    local giftData = GetGiftDataFromLabel(gwRef:GetCachedDataLabel())
    CreateCurrentContentsBox(giftEnt, giftData, parent)

    ------------------------------------------------
    ---- Change Contents ---------------------------
    local wrapForm = vgui.CreateTTT2Form(parent, "gift_opt_change_content_form")
    local dropBtn = wrapForm:MakeButton({
        label = "gift_opt_change_form_drop_desc",
        buttonLabel = "gift_opt_change_form_drop",
        OnClick = function(slf)
            net.Start(GIFTWRAP_DROP_CONT_MSG)
            net.WriteEntity(gwRef)
            net.SendToServer()
        end
    })

    if not gwRef:HasGift() then
        dropBtn:SetEnabled(false)
        dropBtn:SetTooltip(TL("gift_opt_change_form_drop_error_none"))

    elseif not giftData or giftData:IsDropBlocked() or gwRef:GetIsOpening() then
        dropBtn:SetEnabled(false)
        dropBtn:SetTooltip(TL("gift_opt_change_form_drop_error_block"))

    elseif not gwRef:OwnedByWrapper(owner) or gwRef:GetIsRandomGift() then
        dropBtn:SetEnabled(false)
        dropBtn:SetTooltip(TL("gift_opt_change_form_drop_error_random"))
    end


    local randomBtn = wrapForm:MakeButton({
        label = "gift_opt_change_form_random_desc",
        buttonLabel = "gift_opt_change_form_random",
        OnClick = function(slf)
            net.Start(GIFTWRAP_RANDOM_GIFT_MSG)
            net.WriteEntity(gwRef)
            net.SendToServer()
        end
    })

    local shopBtn = wrapForm:MakeButton({
        label = "gift_opt_change_form_shop_desc",
        buttonLabel = "gift_opt_change_form_shop",
        OnClick = function(slf)
            if GetGlobalBool("ttt2_deathmatch_active", false) then
                RunConsoleCommand("dm_shop")
            else
                RunConsoleCommand("ttt_cl_traitorpopup")
            end
        end
    })

    if gwRef:HasGift() then
        randomBtn:SetEnabled(false)
        randomBtn:SetTooltip(TL("gift_opt_change_form_error_full"))
        shopBtn:SetEnabled(false)
        shopBtn:SetTooltip(TL("gift_opt_change_form_error_full"))

    elseif not GetGlobalBool("ttt2_deathmatch_active", false) then
        local ply = LocalPlayer()
        local rd = roles.GetByIndex(GetShopFallback(ply:GetSubRole()))
        local noShop = GetGlobalString("ttt_" .. rd.abbr .. "_shop_fallback") == SHOP_DISABLED
        local noCreds = ply:GetCredits() <= 0

        if noCreds then
            randomBtn:SetEnabled(false)
            randomBtn:SetTooltip(TL("gift_opt_change_form_error_nocred"))
        end

        if noShop then
            shopBtn:SetEnabled(false)
            shopBtn:SetTooltip(TL("gift_opt_change_form_shop_error_role"))
        elseif noCreds then
            shopBtn:SetEnabled(false)
            shopBtn:SetTooltip(TL("gift_opt_change_form_error_nocred"))
        end
    end
end