--[[
    CodexController.module.lua
    Modern Codex UI — matches Shop/LuckyBlock/SpinWheel design language
    Pill tabs, overlay, animations, card strokes & gradients
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local BrainrotData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))

local CodexController = {}
CodexController._codexUnlocked = {}
CodexController._codexUI = nil
CodexController._initialized = false
CodexController._activeFilter = nil -- nil = all, or rarity string
CodexController._gridContainer = nil
CodexController._counterLabel = nil
CodexController._tabs = {}
CodexController._bottomText = nil
CodexController._progressFill = nil
CodexController._progressCount = nil
CodexController._isOpen = false
CodexController._mainFrame = nil
CodexController._overlay = nil

-- ══════════════════════════════════════════
-- Visual constants (matching Shop style)
-- ══════════════════════════════════════════

local COLORS = {
    Overlay = Color3.fromRGB(0, 0, 0),
    OverlayTransparency = 0.4,

    PanelBg = Color3.fromRGB(30, 40, 50),
    PanelStroke = Color3.fromRGB(50, 70, 90),
    HeaderBg = Color3.fromRGB(25, 35, 45),

    TabActive = Color3.fromRGB(0, 170, 170),
    TabPill = Color3.fromRGB(45, 55, 65),

    CloseBtn = Color3.fromRGB(220, 50, 50),
    CloseBtnHover = Color3.fromRGB(240, 70, 70),

    CardBg = Color3.fromRGB(35, 48, 62),
    CardLocked = Color3.fromRGB(28, 36, 46),
    CardStroke = Color3.fromRGB(55, 75, 95),
    CardStrokeHover = Color3.fromRGB(80, 110, 140),

    PreviewBg = Color3.fromRGB(22, 30, 40),

    ProgressBg = Color3.fromRGB(22, 30, 40),
    ProgressFill = Color3.fromRGB(0, 190, 170),
    BottomBg = Color3.fromRGB(25, 35, 45),
    BottomStroke = Color3.fromRGB(50, 70, 90),

    White = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(160, 175, 190),
    ScrollBar = Color3.fromRGB(80, 100, 120),
}

local SIZES = {
    Panel = UDim2.new(0, 780, 0, 540),
    PanelClosed = UDim2.new(0, 0, 0, 0),
    CornerRadius = UDim.new(0, 16),
    SmallCorner = UDim.new(0, 12),
    TinyCorner = UDim.new(0, 8),
    PillCorner = UDim.new(0, 18),
}

-- ══════════════════════════════════════════
-- Rarity display names
-- ══════════════════════════════════════════

local RARITY_DISPLAY = {
    Common = "Common",
    Rare = "Rare",
    Epic = "Epic",
    Legendary = "Legendary",
}

-- ══════════════════════════════════════════
-- Set display names (kept for reference)
-- ══════════════════════════════════════════

local SET_DISPLAY_NAMES = {
    brrbrrPatapim = "Brr Brr Patapim",
    TralaleroTralala = "Tralalero Tralala",
    CactoHipopoTamo = "Cacto Hipopo Tamo",
    PiccioneMacchina = "Piccione Macchina",
    GirafaCelestre = "Girafa Celestre",
    LiriliLarila = "Liril\xC3\xAC Laril\xC3\xA0",
    TripiTropiTropaTripa = "Tripi Tropi",
    Talpadifero = "Talpa di Fero",
    GraipusMedussi = "Graipus Medussi",
    BombardiroCrocodilo = "Bombardiro Crocodilo",
    SpioniroGolubiro = "Spioniro Golubiro",
    ZibraZubraZibralini = "Zibra Zubra Zibralini",
    TorrtuginniDragonfrutini = "Torrtuginni Dragonfrutini",
}

-- ══════════════════════════════════════════
-- Helpers
-- ══════════════════════════════════════════

local function getPartsUnlocked(unlocked, setName)
    local d = unlocked[setName]
    if d == true then return { Head = true, Body = true, Legs = true } end
    if type(d) == "table" then
        return { Head = d.Head == true, Body = d.Body == true, Legs = d.Legs == true }
    end
    return { Head = false, Body = false, Legs = false }
end

-- ══════════════════════════════════════════
-- Initialization
-- ══════════════════════════════════════════

function CodexController:Init()
    if self._initialized then return end

    local gui = player:WaitForChild("PlayerGui")
    self._codexUI = gui:WaitForChild("CodexUI")

    -- Remove old UI
    for _, child in ipairs(self._codexUI:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    -- Build new UI
    self:_BuildUI()

    -- Connect SyncCodex
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local syncCodex = Remotes:WaitForChild("SyncCodex")
    syncCodex.OnClientEvent:Connect(function(codexUnlocked)
        self:UpdateCodex(codexUnlocked or {})
    end)

    self._initialized = true
end

-- ══════════════════════════════════════════
-- UI Construction
-- ══════════════════════════════════════════

function CodexController:_BuildUI()
    local screenGui = self._codexUI

    -- ═══ OVERLAY ═══
    local overlay = Instance.new("TextButton")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = COLORS.Overlay
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = screenGui
    self._overlay = overlay

    overlay.MouseButton1Click:Connect(function()
        self:Close()
    end)

    -- ═══ MAIN FRAME ═══
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = SIZES.PanelClosed
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = COLORS.PanelBg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = overlay
    self._mainFrame = mainFrame

    Instance.new("UICorner", mainFrame).CornerRadius = SIZES.CornerRadius

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.PanelStroke
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = mainFrame

    -- ═══ HEADER ═══
    self:_BuildHeader(mainFrame)

    -- ═══ TAB BAR ═══
    self:_BuildTabBar(mainFrame)

    -- ═══ GRID ═══
    self:_BuildGrid(mainFrame)

    -- ═══ BOTTOM BAR ═══
    self:_BuildBottomBar(mainFrame)
end

-- ══════════════════════════════════════════
-- Header
-- ══════════════════════════════════════════

function CodexController:_BuildHeader(mainFrame)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = COLORS.HeaderBg
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    Instance.new("UICorner", header).CornerRadius = SIZES.CornerRadius

    -- Cover bottom corners
    local bottomCover = Instance.new("Frame")
    bottomCover.Size = UDim2.new(1, 0, 0, 16)
    bottomCover.Position = UDim2.new(0, 0, 1, -16)
    bottomCover.BackgroundColor3 = COLORS.HeaderBg
    bottomCover.BorderSizePixel = 0
    bottomCover.Parent = header

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 24, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "CODEX"
    title.TextColor3 = COLORS.White
    title.TextSize = 30
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Counter (right of title)
    local counter = Instance.new("TextLabel")
    counter.Name = "Counter"
    counter.Size = UDim2.new(0, 100, 1, 0)
    counter.Position = UDim2.new(1, -150, 0, 0)
    counter.BackgroundTransparency = 1
    counter.Text = "0/0"
    counter.TextColor3 = COLORS.SubText
    counter.TextSize = 20
    counter.Font = Enum.Font.GothamBold
    counter.TextXAlignment = Enum.TextXAlignment.Right
    counter.Parent = header
    self._counterLabel = counter

    -- Close button (circular, like Shop)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 38, 0, 38)
    closeBtn.Position = UDim2.new(1, -50, 0.5, 0)
    closeBtn.AnchorPoint = Vector2.new(0, 0.5)
    closeBtn.BackgroundColor3 = COLORS.CloseBtn
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = COLORS.White
    closeBtn.TextSize = 20
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = header

    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.CloseBtnHover
        }):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.CloseBtn
        }):Play()
    end)
    closeBtn.MouseButton1Click:Connect(function()
        self:Close()
    end)
end

-- ══════════════════════════════════════════
-- Tab Bar (pill-shaped, like Shop)
-- ══════════════════════════════════════════

function CodexController:_BuildTabBar(mainFrame)
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, 0, 0, 50)
    tabBar.Position = UDim2.new(0, 0, 0, 60)
    tabBar.BackgroundColor3 = COLORS.HeaderBg
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    -- Pill container
    local pillContainer = Instance.new("Frame")
    pillContainer.Name = "PillContainer"
    pillContainer.Size = UDim2.new(0, 460, 0, 38)
    pillContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    pillContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    pillContainer.BackgroundColor3 = COLORS.TabPill
    pillContainer.BorderSizePixel = 0
    pillContainer.Parent = tabBar

    Instance.new("UICorner", pillContainer).CornerRadius = SIZES.PillCorner

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 4)
    layout.Parent = pillContainer

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 3)
    padding.PaddingRight = UDim.new(0, 3)
    padding.Parent = pillContainer

    -- Sort rarities by DisplayOrder
    local rarityOrder = {}
    for rarity, info in pairs(BrainrotData.Rarities) do
        table.insert(rarityOrder, { name = rarity, order = info.DisplayOrder, color = info.Color })
    end
    table.sort(rarityOrder, function(a, b) return a.order < b.order end)

    -- Build tabs: "All" + each rarity
    local allTabs = { { name = nil, display = "All" } }
    for _, r in ipairs(rarityOrder) do
        table.insert(allTabs, { name = r.name, display = RARITY_DISPLAY[r.name] or r.name, color = r.color })
    end

    local tabWidth = math.floor(454 / #allTabs)
    self._tabs = {}

    for i, tabInfo in ipairs(allTabs) do
        local rarity = tabInfo.name
        local displayName = tabInfo.display

        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "Tab_" .. (rarity or "All")
        tabBtn.Size = UDim2.new(0, tabWidth, 0, 32)
        tabBtn.BackgroundTransparency = 1
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = ""
        tabBtn.AutoButtonColor = false
        tabBtn.LayoutOrder = i
        tabBtn.Parent = pillContainer

        Instance.new("UICorner", tabBtn).CornerRadius = SIZES.PillCorner

        -- Fill (visible when active)
        local tabFill = Instance.new("Frame")
        tabFill.Name = "Fill"
        tabFill.Size = UDim2.new(1, 0, 1, 0)
        tabFill.BackgroundColor3 = COLORS.TabActive
        tabFill.BackgroundTransparency = (rarity == nil) and 0 or 1 -- "All" active by default
        tabFill.BorderSizePixel = 0
        tabFill.Parent = tabBtn

        Instance.new("UICorner", tabFill).CornerRadius = SIZES.PillCorner

        -- Label
        local tabLabel = Instance.new("TextLabel")
        tabLabel.Name = "Label"
        tabLabel.Size = UDim2.new(1, 0, 1, 0)
        tabLabel.BackgroundTransparency = 1
        tabLabel.Text = displayName
        tabLabel.TextColor3 = COLORS.White
        tabLabel.TextSize = 14
        tabLabel.Font = Enum.Font.GothamBold
        tabLabel.ZIndex = 2
        tabLabel.Parent = tabBtn

        tabBtn.MouseButton1Click:Connect(function()
            self:SetFilter(rarity)
        end)

        self._tabs[rarity or "_all"] = { button = tabBtn, fill = tabFill }
    end
end

-- ══════════════════════════════════════════
-- Grid
-- ══════════════════════════════════════════

function CodexController:_BuildGrid(mainFrame)
    local gridScroll = Instance.new("ScrollingFrame")
    gridScroll.Name = "GridScroll"
    gridScroll.Size = UDim2.new(1, -40, 1, -175)
    gridScroll.Position = UDim2.new(0, 20, 0, 115)
    gridScroll.BackgroundTransparency = 1
    gridScroll.BorderSizePixel = 0
    gridScroll.ScrollBarThickness = 5
    gridScroll.ScrollBarImageColor3 = COLORS.ScrollBar
    gridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    gridScroll.Parent = mainFrame

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 170, 0, 220)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.Parent = gridScroll

    local gridPad = Instance.new("UIPadding")
    gridPad.PaddingTop = UDim.new(0, 5)
    gridPad.PaddingBottom = UDim.new(0, 5)
    gridPad.Parent = gridScroll

    self._gridContainer = gridScroll
end

-- ══════════════════════════════════════════
-- Bottom Bar
-- ══════════════════════════════════════════

function CodexController:_BuildBottomBar(mainFrame)
    local bottomBar = Instance.new("Frame")
    bottomBar.Name = "BottomBar"
    bottomBar.Size = UDim2.new(1, -40, 0, 46)
    bottomBar.Position = UDim2.new(0, 20, 1, -56)
    bottomBar.BackgroundColor3 = COLORS.BottomBg
    bottomBar.BorderSizePixel = 0
    bottomBar.Parent = mainFrame

    Instance.new("UICorner", bottomBar).CornerRadius = SIZES.SmallCorner

    local bottomStroke = Instance.new("UIStroke")
    bottomStroke.Color = COLORS.BottomStroke
    bottomStroke.Thickness = 1.5
    bottomStroke.Transparency = 0.3
    bottomStroke.Parent = bottomBar

    -- Text
    local bottomText = Instance.new("TextLabel")
    bottomText.Size = UDim2.new(0.6, -10, 0, 18)
    bottomText.Position = UDim2.new(0, 14, 0, 5)
    bottomText.BackgroundTransparency = 1
    bottomText.Text = "Collect Brainrots to unlock bonuses!"
    bottomText.TextColor3 = COLORS.SubText
    bottomText.TextSize = 12
    bottomText.Font = Enum.Font.GothamBold
    bottomText.TextXAlignment = Enum.TextXAlignment.Left
    bottomText.TextTruncate = Enum.TextTruncate.AtEnd
    bottomText.Parent = bottomBar
    self._bottomText = bottomText

    -- Progress bar
    local progBg = Instance.new("Frame")
    progBg.Size = UDim2.new(1, -28, 0, 14)
    progBg.Position = UDim2.new(0, 14, 0, 26)
    progBg.BackgroundColor3 = COLORS.ProgressBg
    progBg.BorderSizePixel = 0
    progBg.Parent = bottomBar

    Instance.new("UICorner", progBg).CornerRadius = UDim.new(0, 7)

    local progFill = Instance.new("Frame")
    progFill.Size = UDim2.new(0, 0, 1, 0)
    progFill.BackgroundColor3 = COLORS.ProgressFill
    progFill.BorderSizePixel = 0
    progFill.Parent = progBg

    Instance.new("UICorner", progFill).CornerRadius = UDim.new(0, 7)
    self._progressFill = progFill

    -- Progress count on the right
    local progCount = Instance.new("TextLabel")
    progCount.Size = UDim2.new(1, -8, 1, 0)
    progCount.BackgroundTransparency = 1
    progCount.Text = "0/0"
    progCount.TextColor3 = COLORS.White
    progCount.TextSize = 10
    progCount.Font = Enum.Font.GothamBold
    progCount.TextXAlignment = Enum.TextXAlignment.Right
    progCount.Parent = progBg
    self._progressCount = progCount
end

-- ══════════════════════════════════════════
-- Tab switching
-- ══════════════════════════════════════════

function CodexController:SetFilter(rarity)
    self._activeFilter = rarity

    for key, tabData in pairs(self._tabs) do
        local isActive = (key == "_all" and rarity == nil) or (key == rarity)
        TweenService:Create(tabData.fill, TweenInfo.new(0.15), {
            BackgroundTransparency = isActive and 0 or 1
        }):Play()
    end

    self:RefreshList()
end

-- ══════════════════════════════════════════
-- 3D Assembly for ViewportFrame
-- ══════════════════════════════════════════

function CodexController:_AssemblePreviewModel(setName)
    local setData = BrainrotData.Sets[setName]
    if not setData then return nil end

    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then return nil end
    local templatesFolder = assetsFolder:FindFirstChild("BodyPartTemplates")
    if not templatesFolder then return nil end

    local headFolder = templatesFolder:FindFirstChild("HeadTemplate")
    local bodyFolder = templatesFolder:FindFirstChild("BodyTemplate")
    local legsFolder = templatesFolder:FindFirstChild("LegsTemplate")

    local headTN = setData.Head and setData.Head.TemplateName or ""
    local bodyTN = setData.Body and setData.Body.TemplateName or ""
    local legsTN = setData.Legs and setData.Legs.TemplateName or ""

    local headSrc = (headTN ~= "" and headFolder) and headFolder:FindFirstChild(headTN) or nil
    local bodySrc = (bodyTN ~= "" and bodyFolder) and bodyFolder:FindFirstChild(bodyTN) or nil
    local legsSrc = (legsTN ~= "" and legsFolder) and legsFolder:FindFirstChild(legsTN) or nil

    if not headSrc and not bodySrc and not legsSrc then return nil end

    local headModel = headSrc and headSrc:Clone() or nil
    local bodyModel = bodySrc and bodySrc:Clone() or nil
    local legsModel = legsSrc and legsSrc:Clone() or nil

    local headPart = headModel and headModel.PrimaryPart
    local bodyPart = bodyModel and bodyModel.PrimaryPart
    local legsPart = legsModel and legsModel.PrimaryPart

    local function cleanModel(m)
        if not m then return end
        for _, desc in ipairs(m:GetDescendants()) do
            if desc:IsA("BillboardGui") then
                desc:Destroy()
            elseif desc:IsA("BasePart") then
                desc.Anchored = true
                desc.CanCollide = false
            end
        end
    end

    cleanModel(headModel)
    cleanModel(bodyModel)
    cleanModel(legsModel)

    local function repositionModel(subModel, primaryPart, targetCFrame)
        if not subModel or not primaryPart then return end
        local delta = targetCFrame * primaryPart.CFrame:Inverse()
        for _, desc in ipairs(subModel:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.CFrame = delta * desc.CFrame
            end
        end
    end

    -- Position Legs at origin
    if legsModel and legsPart then
        local legsTopAtt = legsPart:FindFirstChild("TopAttachment")
        local legsOrientation = legsTopAtt and legsTopAtt.CFrame.Rotation or CFrame.new()
        repositionModel(legsModel, legsPart, CFrame.new(0, legsPart.Size.Y / 2, 0) * legsOrientation)
    end

    -- Body -> Legs via Attachments
    if bodyModel and bodyPart then
        if legsPart then
            local bba = bodyPart:FindFirstChild("BottomAttachment")
            local lta = legsPart:FindFirstChild("TopAttachment")
            if bba and lta then
                local targetCF = legsPart.CFrame * lta.CFrame * bba.CFrame:Inverse()
                repositionModel(bodyModel, bodyPart, targetCF)
            else
                repositionModel(bodyModel, bodyPart, CFrame.new(0, legsPart.Size.Y + bodyPart.Size.Y / 2, 0))
            end
        else
            repositionModel(bodyModel, bodyPart, CFrame.new(0, bodyPart.Size.Y / 2, 0))
        end
    end

    -- Head -> Body via Attachments
    if headModel and headPart then
        if bodyPart then
            local hba = headPart:FindFirstChild("BottomAttachment")
            local bta = bodyPart:FindFirstChild("TopAttachment")
            if hba and bta then
                local targetCF = bodyPart.CFrame * bta.CFrame * hba.CFrame:Inverse()
                repositionModel(headModel, headPart, targetCF)
            else
                repositionModel(headModel, headPart, bodyPart.CFrame * CFrame.new(0, bodyPart.Size.Y / 2 + headPart.Size.Y / 2, 0))
            end
        elseif legsPart then
            repositionModel(headModel, headPart, CFrame.new(0, legsPart.Size.Y + headPart.Size.Y / 2, 0))
        else
            repositionModel(headModel, headPart, CFrame.new(0, headPart.Size.Y / 2, 0))
        end
    end

    local model = Instance.new("Model")
    model.Name = "Preview_" .. setName

    if legsModel then legsModel.Parent = model end
    if bodyModel then bodyModel.Parent = model end
    if headModel then headModel.Parent = model end

    model.PrimaryPart = bodyPart or headPart or legsPart

    return model, headModel, bodyModel, legsModel
end

-- ══════════════════════════════════════════
-- Card creation (modern style)
-- ══════════════════════════════════════════

function CodexController:_CreateCard(setName, setData, isDiscovered, layoutOrder, unlockedParts, totalParts, partsUnlocked)
    unlockedParts = unlockedParts or 0
    totalParts = totalParts or 3
    local rarity = setData.Rarity or "Common"
    local rarityInfo = BrainrotData.Rarities[rarity] or {}
    local rarityColor = rarityInfo.Color or Color3.new(1, 1, 1)
    local rarityDisplay = RARITY_DISPLAY[rarity] or rarity

    -- Build name from unlocked parts
    local nameParts = {}
    for _, partType in ipairs({"Head", "Body", "Legs"}) do
        local partInfo = setData[partType]
        if partInfo and partInfo.TemplateName and partInfo.TemplateName ~= "" then
            if partsUnlocked and partsUnlocked[partType] then
                table.insert(nameParts, partInfo.DisplayName)
            else
                table.insert(nameParts, "???")
            end
        end
    end
    local dynamicName = table.concat(nameParts, " ")

    local cardBg = isDiscovered and COLORS.CardBg or COLORS.CardLocked

    local card = Instance.new("Frame")
    card.Name = "Card_" .. setName
    card.LayoutOrder = layoutOrder
    card.BackgroundColor3 = cardBg
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = SIZES.SmallCorner

    -- Card stroke
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = COLORS.CardStroke
    cardStroke.Thickness = 1.5
    cardStroke.Transparency = 0.3
    cardStroke.Parent = card

    -- Subtle gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 210, 220)),
    })
    gradient.Rotation = 90
    gradient.Parent = card

    -- Hover effect
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(cardStroke, TweenInfo.new(0.2), {
                Color = COLORS.CardStrokeHover,
                Transparency = 0
            }):Play()
        end
    end)
    card.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(cardStroke, TweenInfo.new(0.2), {
                Color = COLORS.CardStroke,
                Transparency = 0.3
            }):Play()
        end
    end)

    -- 3D preview area
    local previewFrame = Instance.new("Frame")
    previewFrame.Name = "PreviewFrame"
    previewFrame.Size = UDim2.new(1, -16, 0, 130)
    previewFrame.Position = UDim2.new(0, 8, 0, 8)
    previewFrame.BackgroundColor3 = COLORS.PreviewBg
    previewFrame.BorderSizePixel = 0
    previewFrame.ClipsDescendants = true
    previewFrame.Parent = card
    Instance.new("UICorner", previewFrame).CornerRadius = SIZES.TinyCorner

    -- ViewportFrame
    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(1, 0, 1, 0)
    viewport.BackgroundTransparency = 1
    viewport.Ambient = Color3.fromRGB(200, 200, 200)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(-1, -1, -1)
    viewport.Parent = previewFrame

    local previewModel, headSubModel, bodySubModel, legsSubModel = self:_AssemblePreviewModel(setName)
    if previewModel then
        local function applyBlackout(subModel)
            if not subModel then return end
            for _, desc in ipairs(subModel:GetDescendants()) do
                if desc:IsA("BasePart") then
                    desc.Color = Color3.fromRGB(15, 20, 30)
                    desc.Material = Enum.Material.SmoothPlastic
                    if desc:IsA("MeshPart") then
                        desc.TextureID = ""
                    end
                    for _, c in ipairs(desc:GetChildren()) do
                        if c:IsA("Decal") or c:IsA("Texture") or c:IsA("SurfaceGui") then
                            c:Destroy()
                        elseif c:IsA("SpecialMesh") then
                            c.TextureId = ""
                        end
                    end
                end
            end
        end

        local pl = partsUnlocked or {}
        if not pl.Head then applyBlackout(headSubModel) end
        if not pl.Body then applyBlackout(bodySubModel) end
        if not pl.Legs then applyBlackout(legsSubModel) end

        previewModel.Parent = viewport

        local camera = Instance.new("Camera")
        viewport.CurrentCamera = camera
        camera.Parent = viewport
        camera.FieldOfView = 50

        local primary = previewModel.PrimaryPart
        if primary then
            local cf, size = previewModel:GetBoundingBox()
            local maxDim = math.max(size.X, size.Y, size.Z)
            local dist = maxDim * 1.2
            camera.CFrame = CFrame.new(
                cf.Position + Vector3.new(dist * 0.3, dist * 0.2, dist),
                cf.Position
            )
        end
    else
        local ph = Instance.new("TextLabel")
        ph.Size = UDim2.new(1, 0, 1, 0)
        ph.BackgroundTransparency = 1
        ph.Text = "?"
        ph.TextColor3 = Color3.fromRGB(60, 75, 90)
        ph.TextSize = 40
        ph.Font = Enum.Font.GothamBlack
        ph.Parent = previewFrame
    end

    -- Brainrot name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -16, 0, 20)
    nameLabel.Position = UDim2.new(0, 8, 0, 142)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = dynamicName
    nameLabel.TextColor3 = COLORS.White
    nameLabel.TextSize = 13
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.TextStrokeTransparency = 0.7
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = card

    -- Rarity pill
    local rarityPill = Instance.new("Frame")
    rarityPill.Name = "RarityPill"
    rarityPill.Size = UDim2.new(0, 0, 0, 20)
    rarityPill.Position = UDim2.new(0, 8, 0, 166)
    rarityPill.BackgroundColor3 = rarityColor
    rarityPill.BackgroundTransparency = 0.75
    rarityPill.BorderSizePixel = 0
    rarityPill.AutomaticSize = Enum.AutomaticSize.X
    rarityPill.Parent = card

    Instance.new("UICorner", rarityPill).CornerRadius = UDim.new(0, 10)

    local rarityPillPad = Instance.new("UIPadding")
    rarityPillPad.PaddingLeft = UDim.new(0, 8)
    rarityPillPad.PaddingRight = UDim.new(0, 8)
    rarityPillPad.Parent = rarityPill

    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Name = "RarityLabel"
    rarityLabel.Size = UDim2.new(0, 0, 1, 0)
    rarityLabel.AutomaticSize = Enum.AutomaticSize.X
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = rarityDisplay
    rarityLabel.TextColor3 = rarityColor
    rarityLabel.TextSize = 11
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.Parent = rarityPill

    -- Parts counter pill (right side)
    local partsPill = Instance.new("Frame")
    partsPill.Name = "PartsPill"
    partsPill.Size = UDim2.new(0, 0, 0, 20)
    partsPill.Position = UDim2.new(1, -8, 0, 166)
    partsPill.AnchorPoint = Vector2.new(1, 0)
    partsPill.BackgroundColor3 = (unlockedParts >= totalParts and totalParts > 0)
        and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(60, 75, 90)
    partsPill.BackgroundTransparency = 0.6
    partsPill.BorderSizePixel = 0
    partsPill.AutomaticSize = Enum.AutomaticSize.X
    partsPill.Parent = card

    Instance.new("UICorner", partsPill).CornerRadius = UDim.new(0, 10)

    local partsPillPad = Instance.new("UIPadding")
    partsPillPad.PaddingLeft = UDim.new(0, 8)
    partsPillPad.PaddingRight = UDim.new(0, 8)
    partsPillPad.Parent = partsPill

    local partsLabel = Instance.new("TextLabel")
    partsLabel.Name = "PartsLabel"
    partsLabel.Size = UDim2.new(0, 0, 1, 0)
    partsLabel.AutomaticSize = Enum.AutomaticSize.X
    partsLabel.BackgroundTransparency = 1
    partsLabel.Text = unlockedParts .. "/" .. totalParts
    partsLabel.TextColor3 = (unlockedParts >= totalParts and totalParts > 0)
        and Color3.fromRGB(100, 255, 130) or COLORS.SubText
    partsLabel.TextSize = 11
    partsLabel.Font = Enum.Font.GothamBold
    partsLabel.Parent = partsPill

    -- Completed checkmark overlay
    if unlockedParts >= totalParts and totalParts > 0 then
        local checkBadge = Instance.new("Frame")
        checkBadge.Name = "CheckBadge"
        checkBadge.Size = UDim2.new(0, 24, 0, 24)
        checkBadge.Position = UDim2.new(1, -6, 0, -6)
        checkBadge.AnchorPoint = Vector2.new(1, 0)
        checkBadge.BackgroundColor3 = Color3.fromRGB(0, 190, 100)
        checkBadge.BorderSizePixel = 0
        checkBadge.ZIndex = 3
        checkBadge.Parent = card

        Instance.new("UICorner", checkBadge).CornerRadius = UDim.new(1, 0)

        local checkMark = Instance.new("TextLabel")
        checkMark.Size = UDim2.new(1, 0, 1, 0)
        checkMark.BackgroundTransparency = 1
        checkMark.Text = "\xE2\x9C\x93" -- ✓
        checkMark.TextColor3 = COLORS.White
        checkMark.TextSize = 16
        checkMark.Font = Enum.Font.GothamBlack
        checkMark.ZIndex = 4
        checkMark.Parent = checkBadge
    end

    return card
end

-- ══════════════════════════════════════════
-- Refresh grid
-- ══════════════════════════════════════════

function CodexController:RefreshList()
    local grid = self._gridContainer
    if not grid then return end

    -- Clear old cards
    for _, child in ipairs(grid:GetChildren()) do
        if child:IsA("Frame") and child.Name:match("^Card_") then
            child:Destroy()
        end
    end

    local Sets = BrainrotData.Sets or {}
    local unlocked = self._codexUnlocked or {}
    local Rarities = BrainrotData.Rarities or {}

    -- Sort by rarity then alphabetical name
    local setNames = {}
    for name in pairs(Sets) do table.insert(setNames, name) end
    table.sort(setNames, function(a, b)
        local ra = Sets[a] and Sets[a].Rarity or "Common"
        local rb = Sets[b] and Sets[b].Rarity or "Common"
        local oa = Rarities[ra] and Rarities[ra].DisplayOrder or 99
        local ob = Rarities[rb] and Rarities[rb].DisplayOrder or 99
        if oa ~= ob then return oa < ob end
        return a < b
    end)

    local totalSets = 0
    local discoveredSets = 0
    local filteredTotal = 0
    local filteredDiscovered = 0
    local layoutOrder = 0

    for _, setName in ipairs(setNames) do
        local setData = Sets[setName]
        if not setData then continue end

        local parts = getPartsUnlocked(unlocked, setName)
        local rarity = setData.Rarity or "Common"

        local totalParts = 0
        local unlockedParts = 0
        for _, partType in ipairs({"Head", "Body", "Legs"}) do
            local partData = setData[partType]
            if partData and partData.TemplateName and partData.TemplateName ~= "" then
                totalParts = totalParts + 1
                if parts[partType] then
                    unlockedParts = unlockedParts + 1
                end
            end
        end

        local isDiscovered = totalParts > 0 and unlockedParts == totalParts

        totalSets = totalSets + 1
        if isDiscovered then discoveredSets = discoveredSets + 1 end

        -- Active filter
        if self._activeFilter and rarity ~= self._activeFilter then continue end

        filteredTotal = filteredTotal + 1
        if isDiscovered then filteredDiscovered = filteredDiscovered + 1 end

        layoutOrder = layoutOrder + 1
        local card = self:_CreateCard(setName, setData, isDiscovered, layoutOrder, unlockedParts, totalParts, parts)
        card.Parent = grid
    end

    -- Global counter
    if self._counterLabel then
        self._counterLabel.Text = discoveredSets .. "/" .. totalSets
    end

    -- Progress bar
    if self._progressFill and self._progressCount and self._bottomText then
        local pct = filteredTotal > 0 and (filteredDiscovered / filteredTotal) or 0

        -- Animate progress bar
        TweenService:Create(self._progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
        }):Play()

        self._progressCount.Text = filteredDiscovered .. "/" .. filteredTotal

        local filterName = self._activeFilter and (RARITY_DISPLAY[self._activeFilter] or self._activeFilter) or ""
        if filterName ~= "" then
            self._bottomText.Text = string.format(
                "Collect 75%% of %s Brainrots for +0.5x base multiplier",
                filterName
            )
        else
            self._bottomText.Text = "Collect Brainrots to unlock bonuses!"
        end
    end
end

-- ══════════════════════════════════════════
-- Public API
-- ══════════════════════════════════════════

function CodexController:UpdateCodex(codexUnlocked)
    self._codexUnlocked = codexUnlocked or {}
    self:RefreshList()
end

function CodexController:Open()
    if self._isOpen then return end
    if not self._codexUI then return end

    self._isOpen = true
    self._codexUI.Enabled = true

    -- Refresh content
    self:RefreshList()

    -- Animate overlay fade in
    self._overlay.BackgroundTransparency = 1
    TweenService:Create(self._overlay, TweenInfo.new(0.25), {
        BackgroundTransparency = COLORS.OverlayTransparency
    }):Play()

    -- Animate panel open
    self._mainFrame.Size = SIZES.PanelClosed
    TweenService:Create(self._mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = SIZES.Panel
    }):Play()
end

function CodexController:Close()
    if not self._isOpen then return end
    if not self._codexUI then return end

    -- Animate overlay fade out
    TweenService:Create(self._overlay, TweenInfo.new(0.2), {
        BackgroundTransparency = 1
    }):Play()

    -- Animate panel close
    local tweenClose = TweenService:Create(self._mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = SIZES.PanelClosed
    })
    tweenClose:Play()

    tweenClose.Completed:Connect(function()
        self._codexUI.Enabled = false
        self._isOpen = false
    end)
end

function CodexController:IsOpen()
    return self._isOpen
end

return CodexController
