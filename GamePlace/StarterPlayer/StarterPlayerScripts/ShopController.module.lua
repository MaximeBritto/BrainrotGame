--[[
    ShopController.module.lua
    Gère l'UI complète du Shop Robux côté client

    L'UI est créée entièrement en code (pas de ScreenGui pré-existant).
    Le shop est extensible : les onglets et produits sont générés
    dynamiquement depuis ShopProducts.module.lua.

    Méthodes publiques:
    - ShopController:Init()   → Crée l'UI et connecte les events
    - ShopController:Open()   → Ouvre le shop avec animation
    - ShopController:Close()  → Ferme le shop avec animation
    - ShopController:Toggle() → Ouvre ou ferme
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Data = ReplicatedStorage:WaitForChild("Data")
local ShopProducts = require(Data:WaitForChild("ShopProducts.module"))

-- Responsive
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ResponsiveScale = require(Shared["ResponsiveScale.module"])

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- État
local isOpen = false
local currentTab = nil
local ownedOneTimePurchases = {}
local dailyPurchases = {}
local dailyCountdownLabel = nil

-- Références UI (créées dans Init)
local screenGui = nil
local mainFrame = nil
local overlay = nil
local contentScroll = nil
local tabButtons = {}

-- ═══════════════════════════════════════════════════════
-- CONSTANTES VISUELLES
-- ═══════════════════════════════════════════════════════

local COLORS = {
    Overlay = Color3.fromRGB(0, 0, 0),
    OverlayTransparency = 0.4,

    PanelBg = Color3.fromRGB(30, 40, 50),
    PanelStroke = Color3.fromRGB(50, 70, 90),
    HeaderBg = Color3.fromRGB(25, 35, 45),

    TabActive = Color3.fromRGB(0, 170, 170),
    TabInactive = Color3.fromRGB(45, 55, 65),
    TabText = Color3.fromRGB(255, 255, 255),

    CloseBtn = Color3.fromRGB(220, 50, 50),
    CloseBtnHover = Color3.fromRGB(240, 70, 70),

    -- Couleurs par type de produit
    CardCash = Color3.fromRGB(35, 110, 55),
    CardCashStroke = Color3.fromRGB(50, 140, 70),
    CardLucky = Color3.fromRGB(140, 120, 20),
    CardLuckyStroke = Color3.fromRGB(180, 155, 30),
    CardSpin = Color3.fromRGB(130, 50, 130),
    CardSpinStroke = Color3.fromRGB(170, 70, 170),
    CardStarter = Color3.fromRGB(30, 80, 150),
    CardStarterStroke = Color3.fromRGB(50, 110, 190),
    CardBoost = Color3.fromRGB(35, 110, 55),
    CardBoostStroke = Color3.fromRGB(50, 140, 70),

    RobuxBtnBg = Color3.fromRGB(40, 190, 170),
    RobuxBtnHover = Color3.fromRGB(50, 220, 195),

    White = Color3.fromRGB(255, 255, 255),
    SectionTitle = Color3.fromRGB(200, 210, 220),
    SubText = Color3.fromRGB(180, 200, 190),
    GoldText = Color3.fromRGB(255, 220, 80),
}

local SIZES = {
    Panel = UDim2.new(0, 720, 0, 520),
    PanelClosed = UDim2.new(0, 0, 0, 0),
    Header = UDim2.new(1, 0, 0, 60),
    TabBar = UDim2.new(1, 0, 0, 50),
    CornerRadius = UDim.new(0, 16),
    SmallCorner = UDim.new(0, 12),
    TinyCorner = UDim.new(0, 8),
    PillCorner = UDim.new(0, 18),
}

-- Tab icons (emoji + text)
local TAB_ICONS = {
    Extras = "\xE2\x9A\xA1",       -- ⚡
    Money  = "\xF0\x9F\x92\xB0",   -- 💰
    Daily  = "\xF0\x9F\x8C\x9F",   -- 🌟
}

-- Couleurs spécifiques au Daily tab
local DAILY_COLORS = {
    CardLucky      = Color3.fromRGB(140, 120, 20),
    CardLuckyStroke= Color3.fromRGB(180, 155, 30),
    CardSpin       = Color3.fromRGB(130, 50, 130),
    CardSpinStroke = Color3.fromRGB(170, 70, 170),
    CardMult       = Color3.fromRGB(30, 90, 160),
    CardMultStroke = Color3.fromRGB(50, 120, 200),
    CardCash       = Color3.fromRGB(35, 110, 55),
    CardCashStroke = Color3.fromRGB(50, 140, 70),
    BuyBtn         = Color3.fromRGB(255, 185, 0),
    BuyBtnHover    = Color3.fromRGB(255, 210, 50),
    BoughtBtn      = Color3.fromRGB(60, 60, 60),
    Countdown      = Color3.fromRGB(180, 200, 220),
    BadgeBg        = Color3.fromRGB(200, 50, 50),
    StrikeText     = Color3.fromRGB(160, 160, 160),
}

local ShopController = {}

-- ═══════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════

function ShopController:Init()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RobuxShopUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 10
    screenGui.Enabled = false
    screenGui.Parent = playerGui
    ResponsiveScale.Apply(screenGui)

    -- Overlay
    overlay = Instance.new("TextButton")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = COLORS.Overlay
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = screenGui

    overlay.MouseButton1Click:Connect(function()
        self:Close()
    end)

    -- Panneau principal
    mainFrame = Instance.new("TextButton")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = SIZES.PanelClosed
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = COLORS.PanelBg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Text = ""
    mainFrame.AutoButtonColor = false
    mainFrame.Parent = overlay

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = SIZES.CornerRadius
    mainCorner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.PanelStroke
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = mainFrame

    -- Header
    self:_CreateHeader()

    -- TabBar
    self:_CreateTabBar()

    -- Zone de contenu
    self:_CreateContentArea()

    -- Sélectionner le premier onglet (EXTRAS first since it's Order 2 but we want it first visually)
    if #ShopProducts.Categories > 0 then
        local sorted = {}
        for _, cat in ipairs(ShopProducts.Categories) do
            table.insert(sorted, cat)
        end
        table.sort(sorted, function(a, b) return (a.Order or 99) < (b.Order or 99) end)
        self:SwitchTab(sorted[1].Id)
    end

    -- Écouter les mises à jour de SyncPlayerData pour OwnedOneTimePurchases
    local syncPlayerData = Remotes:FindFirstChild("SyncPlayerData")
    if syncPlayerData then
        syncPlayerData.OnClientEvent:Connect(function(data)
            if data.OwnedOneTimePurchases then
                ownedOneTimePurchases = data.OwnedOneTimePurchases
                if currentTab then
                    self:SwitchTab(currentTab)
                end
            end
        end)
    end

    -- Écouter les mises à jour du Daily Shop
    local syncDailyPurchases = Remotes:FindFirstChild("SyncDailyPurchases")
    if syncDailyPurchases then
        syncDailyPurchases.OnClientEvent:Connect(function(data)
            dailyPurchases = data or {}
            if currentTab == "Daily" then
                self:SwitchTab("Daily")
            end
        end)
    end

    -- Charger les données initiales
    task.spawn(function()
        local getFullPlayerData = Remotes:FindFirstChild("GetFullPlayerData")
        if getFullPlayerData then
            local fullData = getFullPlayerData:InvokeServer()
            if fullData then
                if fullData.OwnedOneTimePurchases then
                    ownedOneTimePurchases = fullData.OwnedOneTimePurchases
                end
                if fullData.DailyPurchases then
                    dailyPurchases = fullData.DailyPurchases
                end
                if currentTab then
                    self:SwitchTab(currentTab)
                end
            end
        end
    end)

    -- Countdown de minuit (mis à jour chaque seconde)
    task.spawn(function()
        while true do
            task.wait(1)
            if dailyCountdownLabel and dailyCountdownLabel.Parent then
                local t = os.date("*t")
                local secs = (23 - t.hour) * 3600 + (59 - t.min) * 60 + (60 - t.sec)
                local h = math.floor(secs / 3600)
                local m = math.floor((secs % 3600) / 60)
                local s = secs % 60
                dailyCountdownLabel.Text = string.format(
                    "Resets in: %02d:%02d:%02d", h, m, s)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════
-- CRÉATION DES ÉLÉMENTS UI
-- ═══════════════════════════════════════════════════════

function ShopController:_CreateHeader()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = SIZES.Header
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = COLORS.HeaderBg
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    -- Corner top only (clip bottom)
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = SIZES.CornerRadius
    headerCorner.Parent = header

    -- Cover bottom corners
    local bottomCover = Instance.new("Frame")
    bottomCover.Name = "BottomCover"
    bottomCover.Size = UDim2.new(1, 0, 0, 16)
    bottomCover.Position = UDim2.new(0, 0, 1, -16)
    bottomCover.BackgroundColor3 = COLORS.HeaderBg
    bottomCover.BorderSizePixel = 0
    bottomCover.Parent = header

    -- Titre SHOP
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 24, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "SHOP"
    title.TextColor3 = COLORS.White
    title.TextSize = 30
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Bouton X circulaire
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

    -- Cercle parfait
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(1, 0)
    closeBtnCorner.Parent = closeBtn

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

function ShopController:_CreateTabBar()
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = SIZES.TabBar
    tabBar.Position = UDim2.new(0, 0, 0, 60)
    tabBar.BackgroundColor3 = COLORS.HeaderBg
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    -- Pill container centré (taille adaptée au nombre d'onglets)
    local tabCount = #ShopProducts.Categories
    local pillWidth = math.max(340, tabCount * 160 + (tabCount - 1) * 4 + 6)
    local pillContainer = Instance.new("Frame")
    pillContainer.Name = "PillContainer"
    pillContainer.Size = UDim2.new(0, pillWidth, 0, 38)
    pillContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    pillContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    pillContainer.BackgroundColor3 = COLORS.TabInactive
    pillContainer.BorderSizePixel = 0
    pillContainer.Parent = tabBar

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = SIZES.PillCorner
    pillCorner.Parent = pillContainer

    -- Layout horizontal pour les tabs
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

    -- Trier les catégories
    local sorted = {}
    for _, cat in ipairs(ShopProducts.Categories) do
        table.insert(sorted, cat)
    end
    table.sort(sorted, function(a, b) return (a.Order or 99) < (b.Order or 99) end)

    tabButtons = {}
    for _, category in ipairs(sorted) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "Tab_" .. category.Id
        tabBtn.Size = UDim2.new(0, 160, 0, 32)
        tabBtn.BackgroundColor3 = COLORS.TabInactive
        tabBtn.BackgroundTransparency = 1
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = ""
        tabBtn.AutoButtonColor = false
        tabBtn.Parent = pillContainer

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = SIZES.PillCorner
        tabCorner.Parent = tabBtn

        -- Inner fill (colored when active)
        local tabFill = Instance.new("Frame")
        tabFill.Name = "Fill"
        tabFill.Size = UDim2.new(1, 0, 1, 0)
        tabFill.BackgroundColor3 = COLORS.TabActive
        tabFill.BackgroundTransparency = 1
        tabFill.BorderSizePixel = 0
        tabFill.Parent = tabBtn

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = SIZES.PillCorner
        fillCorner.Parent = tabFill

        -- Icon + text label
        local icon = TAB_ICONS[category.Id] or ""
        local tabLabel = Instance.new("TextLabel")
        tabLabel.Name = "Label"
        tabLabel.Size = UDim2.new(1, 0, 1, 0)
        tabLabel.BackgroundTransparency = 1
        tabLabel.Text = icon .. " " .. category.DisplayName
        tabLabel.TextColor3 = COLORS.TabText
        tabLabel.TextSize = 15
        tabLabel.Font = Enum.Font.GothamBold
        tabLabel.ZIndex = 2
        tabLabel.Parent = tabBtn

        tabBtn.MouseButton1Click:Connect(function()
            self:SwitchTab(category.Id)
        end)

        tabButtons[category.Id] = {button = tabBtn, fill = tabFill}
    end
end

function ShopController:_CreateContentArea()
    contentScroll = Instance.new("ScrollingFrame")
    contentScroll.Name = "ContentScroll"
    contentScroll.Size = UDim2.new(1, -40, 1, -125)
    contentScroll.Position = UDim2.new(0, 20, 0, 115)
    contentScroll.BackgroundTransparency = 1
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 5
    contentScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 100, 120)
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentScroll.Parent = mainFrame
end

-- ═══════════════════════════════════════════════════════
-- ONGLETS ET CONTENU
-- ═══════════════════════════════════════════════════════

function ShopController:SwitchTab(categoryId)
    currentTab = categoryId

    for id, tabData in pairs(tabButtons) do
        if id == categoryId then
            tabData.fill.BackgroundTransparency = 0
        else
            tabData.fill.BackgroundTransparency = 1
        end
    end

    local category = nil
    for _, cat in ipairs(ShopProducts.Categories) do
        if cat.Id == categoryId then
            category = cat
            break
        end
    end

    if not category then
        warn("[ShopController] Catégorie introuvable: " .. categoryId)
        return
    end

    self:_BuildProductCards(category)
end

function ShopController:_BuildProductCards(category)
    -- Vider le contenu actuel
    for _, child in ipairs(contentScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local scrollWidth = 680

    -- Daily tab → rendu spécial
    if category.Id == "Daily" then
        self:_BuildDailyGrid(category, scrollWidth)
        return
    end

    -- Vérifier si la catégorie a des produits avec des Sections
    local hasSections = false
    for _, product in ipairs(category.Products) do
        if product.Section then
            hasSections = true
            break
        end
    end

    if not hasSections then
        self:_BuildSimpleGrid(category, scrollWidth)
    else
        self:_BuildSectionedGrid(category, scrollWidth)
    end
end

-- ═══════════════════════════════════════════════════════
-- DAILY GRID
-- ═══════════════════════════════════════════════════════

function ShopController:_BuildDailyGrid(category, scrollWidth)
    -- Vider contenu
    for _, child in ipairs(contentScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local yOffset = 8

    -- Titre
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "DailyTitle"
    titleLabel.Size = UDim2.new(1, 0, 0, 28)
    titleLabel.Position = UDim2.new(0, 0, 0, yOffset)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "DAILY OFFERS  \xF0\x9F\x8C\x9F"
    titleLabel.TextColor3 = COLORS.GoldText
    titleLabel.TextSize = 20
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = contentScroll
    yOffset = yOffset + 32

    -- Countdown reset (badge style)
    local countdownFrame = Instance.new("Frame")
    countdownFrame.Name = "CountdownFrame"
    countdownFrame.Size = UDim2.new(1, 0, 0, 36)
    countdownFrame.Position = UDim2.new(0, 0, 0, yOffset)
    countdownFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 45)
    countdownFrame.BorderSizePixel = 0
    countdownFrame.Parent = contentScroll
    Instance.new("UICorner", countdownFrame).CornerRadius = UDim.new(0, 8)

    local countdownStroke = Instance.new("UIStroke")
    countdownStroke.Color = Color3.fromRGB(255, 185, 0)
    countdownStroke.Thickness = 1.5
    countdownStroke.Parent = countdownFrame

    local clockIcon = Instance.new("TextLabel")
    clockIcon.Name = "ClockIcon"
    clockIcon.Size = UDim2.new(0, 30, 1, 0)
    clockIcon.Position = UDim2.new(0, 8, 0, 0)
    clockIcon.BackgroundTransparency = 1
    clockIcon.Text = "\xE2\x8F\xB0"
    clockIcon.TextSize = 18
    clockIcon.Font = Enum.Font.GothamBold
    clockIcon.Parent = countdownFrame

    local countdownLabel = Instance.new("TextLabel")
    countdownLabel.Name = "Countdown"
    countdownLabel.Size = UDim2.new(1, -42, 1, 0)
    countdownLabel.Position = UDim2.new(0, 38, 0, 0)
    countdownLabel.BackgroundTransparency = 1
    countdownLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    countdownLabel.TextSize = 17
    countdownLabel.Font = Enum.Font.GothamBold
    countdownLabel.TextXAlignment = Enum.TextXAlignment.Left
    countdownLabel.Parent = countdownFrame
    dailyCountdownLabel = countdownLabel

    -- Afficher immédiatement
    local t = os.date("*t")
    local secs = (23 - t.hour) * 3600 + (59 - t.min) * 60 + (60 - t.sec)
    countdownLabel.Text = string.format("Resets in: %02d:%02d:%02d",
        math.floor(secs / 3600), math.floor((secs % 3600) / 60), secs % 60)

    yOffset = yOffset + 44

    -- Grille 2×2
    local cols = 2
    local spacing = 14
    local cardW = math.floor((scrollWidth - spacing) / cols)
    local cardH = 180

    for i, product in ipairs(category.Products) do
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        local xPos = col * (cardW + spacing)
        local yPos = row * (cardH + spacing)
        self:_CreateDailyCard(contentScroll, xPos, yOffset + yPos, cardW, cardH, product, i)
    end

    local rows = math.ceil(#category.Products / cols)
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset + rows * (cardH + spacing) + 20)
end

function ShopController:_CreateDailyCard(parent, xPos, yPos, width, height, product, productIndex)
    -- Couleurs selon le type de récompense
    local cardBg, cardStrokeColor
    if product.LuckyBlocks then
        cardBg = DAILY_COLORS.CardLucky
        cardStrokeColor = DAILY_COLORS.CardLuckyStroke
    elseif product.Spins then
        cardBg = DAILY_COLORS.CardSpin
        cardStrokeColor = DAILY_COLORS.CardSpinStroke
    elseif product.PermanentMultiplierBonus then
        cardBg = DAILY_COLORS.CardMult
        cardStrokeColor = DAILY_COLORS.CardMultStroke
    else
        cardBg = DAILY_COLORS.CardCash
        cardStrokeColor = DAILY_COLORS.CardCashStroke
    end

    local card = Instance.new("Frame")
    card.Name = "Daily_" .. (product.DailyKey or "?")
    card.Size = UDim2.new(0, width, 0, height)
    card.Position = UDim2.new(0, xPos, 0, yPos)
    card.BackgroundColor3 = cardBg
    card.BorderSizePixel = 0
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = SIZES.SmallCorner
    cardCorner.Parent = card

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)),
    })
    gradient.Rotation = 90
    gradient.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = cardStrokeColor
    cardStroke.Thickness = 1.5
    cardStroke.Transparency = 0.3
    cardStroke.Parent = card

    -- Icône
    local iconText = "$"
    if product.LuckyBlocks then
        iconText = "\xF0\x9F\x8D\x80"  -- 🍀
    elseif product.Spins then
        iconText = "\xF0\x9F\x8E\xB0"  -- 🎰
    elseif product.PermanentMultiplierBonus then
        iconText = "\xF0\x9F\x93\x88"  -- 📈
    elseif product.PermanentSpeedBonus then
        iconText = "\xE2\x9A\xA1"       -- ⚡
    end

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(1, 0, 0, 46)
    iconLabel.Position = UDim2.new(0, 0, 0, 8)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = iconText
    iconLabel.TextColor3 = Color3.fromRGB(80, 220, 80)
    iconLabel.TextSize = 36
    iconLabel.Font = Enum.Font.GothamBlack
    iconLabel.TextStrokeTransparency = 0.5
    iconLabel.TextStrokeColor3 = Color3.fromRGB(0, 30, 0)
    iconLabel.Parent = card

    -- Nom produit
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ProductName"
    nameLabel.Size = UDim2.new(1, -12, 0, 28)
    nameLabel.Position = UDim2.new(0, 6, 0, 54)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = product.DisplayName
    nameLabel.TextColor3 = COLORS.White
    nameLabel.TextSize = 17
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextStrokeTransparency = 0.6
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextWrapped = true
    nameLabel.Parent = card

    -- Prix barré (Robux normal)
    local strikeLabel = Instance.new("TextLabel")
    strikeLabel.Name = "StrikePrice"
    strikeLabel.Size = UDim2.new(0, 100, 0, 20)
    strikeLabel.Position = UDim2.new(0, 6, 0, 84)
    strikeLabel.BackgroundTransparency = 1
    strikeLabel.Text = utf8.char(0xE002) .. " " .. self:_FormatNumber(product.NormalRobux or 0)
    strikeLabel.TextColor3 = DAILY_COLORS.StrikeText
    strikeLabel.TextSize = 13
    strikeLabel.Font = Enum.Font.Gotham
    strikeLabel.TextXAlignment = Enum.TextXAlignment.Left
    strikeLabel.Parent = card

    -- Ligne de strike (barre horizontale sur le prix)
    local strikeLine = Instance.new("Frame")
    strikeLine.Name = "StrikeLine"
    strikeLine.Size = UDim2.new(0, 72, 0, 1)
    strikeLine.Position = UDim2.new(0, 6, 0, 93)
    strikeLine.BackgroundColor3 = DAILY_COLORS.StrikeText
    strikeLine.BorderSizePixel = 0
    strikeLine.Parent = card

    -- Badge -50%
    local badgeFrame = Instance.new("Frame")
    badgeFrame.Name = "Badge"
    badgeFrame.Size = UDim2.new(0, 50, 0, 20)
    badgeFrame.Position = UDim2.new(0, 84, 0, 84)
    badgeFrame.BackgroundColor3 = DAILY_COLORS.BadgeBg
    badgeFrame.BorderSizePixel = 0
    badgeFrame.Parent = card

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 6)
    badgeCorner.Parent = badgeFrame

    local badgeLabel = Instance.new("TextLabel")
    badgeLabel.Size = UDim2.new(1, 0, 1, 0)
    badgeLabel.BackgroundTransparency = 1
    badgeLabel.Text = "-50%"
    badgeLabel.TextColor3 = COLORS.White
    badgeLabel.TextSize = 12
    badgeLabel.Font = Enum.Font.GothamBold
    badgeLabel.Parent = badgeFrame

    -- Bouton Robux ou BOUGHT
    local isAlreadyBought = dailyPurchases[product.DailyPurchaseKey or ""] == true

    local buyBtn = Instance.new("TextButton")
    buyBtn.Name = "BuyButton"
    buyBtn.Size = UDim2.new(0.8, 0, 0, 34)
    buyBtn.Position = UDim2.new(0.1, 0, 1, -44)
    buyBtn.BorderSizePixel = 0
    buyBtn.AutoButtonColor = false
    buyBtn.Parent = card

    local buyCorner = Instance.new("UICorner")
    buyCorner.CornerRadius = SIZES.TinyCorner
    buyCorner.Parent = buyBtn

    if isAlreadyBought then
        buyBtn.BackgroundColor3 = DAILY_COLORS.BoughtBtn
        buyBtn.Active = false
        local boughtLabel = Instance.new("TextLabel")
        boughtLabel.Size = UDim2.new(1, 0, 1, 0)
        boughtLabel.BackgroundTransparency = 1
        boughtLabel.Text = "BOUGHT"
        boughtLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
        boughtLabel.TextSize = 15
        boughtLabel.Font = Enum.Font.GothamBold
        boughtLabel.Parent = buyBtn
    else
        buyBtn.BackgroundColor3 = COLORS.RobuxBtnBg

        local btnGradient = Instance.new("UIGradient")
        btnGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 180)),
        })
        btnGradient.Rotation = 90
        btnGradient.Parent = buyBtn

        local priceLabel = Instance.new("TextLabel")
        priceLabel.Size = UDim2.new(1, 0, 1, 0)
        priceLabel.BackgroundTransparency = 1
        priceLabel.Text = utf8.char(0xE002) .. " " .. self:_FormatNumber(product.Robux or 0)
        priceLabel.TextColor3 = COLORS.White
        priceLabel.TextSize = 15
        priceLabel.Font = Enum.Font.GothamBold
        priceLabel.TextStrokeTransparency = 0.6
        priceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        priceLabel.Parent = buyBtn

        buyBtn.MouseEnter:Connect(function()
            TweenService:Create(buyBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = COLORS.RobuxBtnHover
            }):Play()
        end)
        buyBtn.MouseLeave:Connect(function()
            TweenService:Create(buyBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = COLORS.RobuxBtnBg
            }):Play()
        end)
        buyBtn.MouseButton1Click:Connect(function()
            local remote = Remotes:FindFirstChild("RequestShopPurchase")
            if remote then
                remote:FireServer("Daily", productIndex)
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════
-- GRILLE SIMPLE (ex: CASH tab)
-- ═══════════════════════════════════════════════════════

function ShopController:_BuildSimpleGrid(category, scrollWidth)
    local yOffset = 10

    -- Titre de section
    local sectionTitle = Instance.new("TextLabel")
    sectionTitle.Name = "SectionTitle"
    sectionTitle.Size = UDim2.new(1, 0, 0, 35)
    sectionTitle.Position = UDim2.new(0, 0, 0, yOffset)
    sectionTitle.BackgroundTransparency = 1
    sectionTitle.Text = category.DisplayName
    sectionTitle.TextColor3 = COLORS.SectionTitle
    sectionTitle.TextSize = 22
    sectionTitle.Font = Enum.Font.GothamBold
    sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle.Parent = contentScroll

    yOffset = yOffset + 40

    local products = category.Products
    local cols = math.min(3, #products)
    local spacing = 14
    local cardW = math.floor((scrollWidth - (cols - 1) * spacing) / cols)
    local cardH = 160

    local gridContainer = Instance.new("Frame")
    gridContainer.Name = "GridContainer"
    gridContainer.Position = UDim2.new(0, 0, 0, yOffset)
    gridContainer.BackgroundTransparency = 1
    gridContainer.BorderSizePixel = 0
    gridContainer.Parent = contentScroll

    local totalProducts = #products
    local rows = math.ceil(totalProducts / cols)
    local totalGridHeight = rows * cardH + (rows - 1) * spacing
    gridContainer.Size = UDim2.new(1, 0, 0, totalGridHeight)

    for index, product in ipairs(products) do
        local row = math.floor((index - 1) / cols)
        local col = (index - 1) % cols

        local itemsOnThisRow = math.min(cols, totalProducts - row * cols)
        local thisCardW = cardW
        local rowTotalWidth = cols * cardW + (cols - 1) * spacing
        if itemsOnThisRow < cols then
            thisCardW = math.floor((scrollWidth - (itemsOnThisRow - 1) * spacing) / itemsOnThisRow)
            rowTotalWidth = itemsOnThisRow * thisCardW + (itemsOnThisRow - 1) * spacing
        end

        local leftOffset = math.floor((scrollWidth - rowTotalWidth) / 2)
        local xPos = leftOffset + col * (thisCardW + spacing)
        local yPos = row * (cardH + spacing)

        self:_CreateGridCard(gridContainer, xPos, yPos, thisCardW, cardH, category.Id, index, product)
    end

    contentScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset + totalGridHeight + 20)
end

-- ═══════════════════════════════════════════════════════
-- GRILLE AVEC SECTIONS (ex: EXTRAS tab)
-- ═══════════════════════════════════════════════════════

function ShopController:_BuildSectionedGrid(category, scrollWidth)
    -- Grouper les produits par section
    local sections = {}
    local currentSection = nil

    for index, product in ipairs(category.Products) do
        if product.Section then
            currentSection = { name = product.Section, products = {} }
            table.insert(sections, currentSection)
        end
        if currentSection then
            table.insert(currentSection.products, { index = index, product = product })
        end
    end

    local spacing = 14
    local SECTION_HEADER_HEIGHT = 30
    local SECTION_SPACING = 20
    local yOffset = 5

    for sectionIdx, section in ipairs(sections) do
        -- En-tête de section
        local header = Instance.new("TextLabel")
        header.Name = "SectionHeader_" .. sectionIdx
        header.Size = UDim2.new(1, 0, 0, SECTION_HEADER_HEIGHT)
        header.Position = UDim2.new(0, 0, 0, yOffset)
        header.BackgroundTransparency = 1
        header.Text = section.name
        header.TextColor3 = COLORS.SectionTitle
        header.TextSize = 18
        header.Font = Enum.Font.GothamBold
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = contentScroll

        yOffset = yOffset + SECTION_HEADER_HEIGHT + 8

        -- Déterminer le nombre de colonnes pour cette section
        local sectionProducts = section.products
        local totalProducts = #sectionProducts
        local cols
        if totalProducts == 1 then
            cols = 1
        elseif totalProducts == 2 then
            cols = 2
        else
            cols = math.min(3, totalProducts)
        end

        local cardW = math.floor((scrollWidth - (cols - 1) * spacing) / cols)
        local cardH = 170
        if cols == 1 then
            cardH = 150
        end

        -- Vérifier si la section contient un produit avec Description (ex: Starter Pack)
        for _, entry in ipairs(sectionProducts) do
            if entry.product.Description then
                cardH = 200
                break
            end
        end

        local gridContainer = Instance.new("Frame")
        gridContainer.Name = "Grid_" .. sectionIdx
        gridContainer.Position = UDim2.new(0, 0, 0, yOffset)
        gridContainer.BackgroundTransparency = 1
        gridContainer.BorderSizePixel = 0
        gridContainer.Parent = contentScroll

        local rows = math.ceil(totalProducts / cols)
        local totalGridHeight = rows * cardH + (rows - 1) * spacing
        gridContainer.Size = UDim2.new(1, 0, 0, totalGridHeight)

        for localIdx, entry in ipairs(sectionProducts) do
            local row = math.floor((localIdx - 1) / cols)
            local col = (localIdx - 1) % cols

            local itemsOnThisRow = math.min(cols, totalProducts - row * cols)
            local thisCardW = cardW
            local rowTotalWidth = cols * cardW + (cols - 1) * spacing
            if itemsOnThisRow < cols then
                thisCardW = math.floor((scrollWidth - (itemsOnThisRow - 1) * spacing) / itemsOnThisRow)
                rowTotalWidth = itemsOnThisRow * thisCardW + (itemsOnThisRow - 1) * spacing
            end

            local leftOffset = math.floor((scrollWidth - rowTotalWidth) / 2)
            local xPos = leftOffset + col * (thisCardW + spacing)
            local yPos = row * (cardH + spacing)

            self:_CreateGridCard(gridContainer, xPos, yPos, thisCardW, cardH, category.Id, entry.index, entry.product)
        end

        yOffset = yOffset + totalGridHeight + SECTION_SPACING
    end

    contentScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)
end

-- ═══════════════════════════════════════════════════════
-- CARD CREATION
-- ═══════════════════════════════════════════════════════

function ShopController:_CreateGridCard(parent, xPos, yPos, width, height, categoryId, productIndex, product)
    -- Déterminer la couleur selon le type de produit
    local cardBg, cardStrokeColor
    if product.Description then
        -- Starter Pack → bleu
        cardBg = COLORS.CardStarter
        cardStrokeColor = COLORS.CardStarterStroke
    elseif product.LuckyBlocks then
        -- Lucky Blocks → jaune
        cardBg = COLORS.CardLucky
        cardStrokeColor = COLORS.CardLuckyStroke
    elseif product.Spins then
        -- Spins → violet
        cardBg = COLORS.CardSpin
        cardStrokeColor = COLORS.CardSpinStroke
    elseif product.MultiplierBoost then
        -- Boost → vert
        cardBg = COLORS.CardBoost
        cardStrokeColor = COLORS.CardBoostStroke
    else
        -- Cash → vert
        cardBg = COLORS.CardCash
        cardStrokeColor = COLORS.CardCashStroke
    end

    local card = Instance.new("Frame")
    card.Name = "Product_" .. productIndex
    card.Size = UDim2.new(0, width, 0, height)
    card.Position = UDim2.new(0, xPos, 0, yPos)
    card.BackgroundColor3 = cardBg
    card.BorderSizePixel = 0
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = SIZES.SmallCorner
    cardCorner.Parent = card

    -- Gradient subtil (plus clair en haut)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 180, 170)),
    })
    gradient.Rotation = 90
    gradient.Parent = card

    -- Bordure subtile
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = cardStrokeColor
    cardStroke.Thickness = 1.5
    cardStroke.Transparency = 0.3
    cardStroke.Parent = card

    -- Contenu de la carte
    local isWideCard = (width > 400)

    if product.Description then
        -- Carte avec description (ex: Starter Pack)
        self:_CreateDescriptionCardContent(card, width, height, product, isWideCard)
    elseif isWideCard then
        -- Carte large (ex: Boost seul dans sa section)
        self:_CreateWideCardContent(card, width, height, product)
    else
        -- Carte standard (ex: Lucky Block, Spin, Cash)
        self:_CreateStandardCardContent(card, width, height, product)
    end

    -- Vérifier si c'est un achat unique déjà possédé
    local isOwned = product.OneTimePurchaseKey and ownedOneTimePurchases[product.OneTimePurchaseKey] == true

    -- Bouton Robux
    self:_CreateRobuxButton(card, width, height, categoryId, productIndex, product, isOwned)

    -- Hover effect sur la carte (éclaircir la bordure)
    local hoverColor = Color3.fromRGB(
        math.min(255, math.floor(cardStrokeColor.R * 255 * 1.4)),
        math.min(255, math.floor(cardStrokeColor.G * 255 * 1.4)),
        math.min(255, math.floor(cardStrokeColor.B * 255 * 1.4))
    )
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(cardStroke, TweenInfo.new(0.2), {
                Color = hoverColor,
                Transparency = 0
            }):Play()
        end
    end)
    card.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(cardStroke, TweenInfo.new(0.2), {
                Color = cardStrokeColor,
                Transparency = 0.3
            }):Play()
        end
    end)
end

function ShopController:_CreateWideCardContent(card, width, height, product)
    -- Icon $ à gauche
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(0, 90, 0, 80)
    iconLabel.Position = UDim2.new(0, 20, 0, 10)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "$"
    iconLabel.TextColor3 = Color3.fromRGB(80, 200, 80)
    iconLabel.TextSize = 60
    iconLabel.Font = Enum.Font.GothamBlack
    iconLabel.TextStrokeTransparency = 0.5
    iconLabel.TextStrokeColor3 = Color3.fromRGB(0, 40, 0)
    iconLabel.Parent = card

    -- Si c'est un boost, afficher le multiplicateur
    if product.MultiplierBoost then
        local multLabel = Instance.new("TextLabel")
        multLabel.Name = "MultiplierIcon"
        multLabel.Size = UDim2.new(0, 50, 0, 40)
        multLabel.Position = UDim2.new(0, 75, 0, 35)
        multLabel.BackgroundTransparency = 1
        multLabel.Text = "x" .. tostring(math.floor(product.MultiplierBoost))
        multLabel.TextColor3 = Color3.fromRGB(80, 200, 80)
        multLabel.TextSize = 30
        multLabel.Font = Enum.Font.GothamBlack
        multLabel.TextStrokeTransparency = 0.5
        multLabel.TextStrokeColor3 = Color3.fromRGB(0, 40, 0)
        multLabel.Parent = card
    end

    -- Nom du produit à droite
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ProductName"
    nameLabel.Size = UDim2.new(0, width - 180, 0, 50)
    nameLabel.Position = UDim2.new(0, 140, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = product.DisplayName
    nameLabel.TextColor3 = COLORS.White
    nameLabel.TextSize = 28
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextStrokeTransparency = 0.6
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextWrapped = true
    nameLabel.Parent = card
end

function ShopController:_CreateStandardCardContent(card, width, height, product)
    -- Icône $ centré en haut
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(1, 0, 0, 55)
    iconLabel.Position = UDim2.new(0, 0, 0, 10)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "$"
    iconLabel.TextColor3 = Color3.fromRGB(80, 200, 80)
    iconLabel.TextSize = 44
    iconLabel.Font = Enum.Font.GothamBlack
    iconLabel.TextStrokeTransparency = 0.5
    iconLabel.TextStrokeColor3 = Color3.fromRGB(0, 40, 0)
    iconLabel.Parent = card

    -- Lucky Block → trèfle 🍀
    if product.LuckyBlocks then
        iconLabel.Text = "\xF0\x9F\x8D\x80" -- 🍀
        iconLabel.TextColor3 = Color3.fromRGB(80, 220, 80)
    end

    -- Spin → roue 🎡
    if product.Spins then
        iconLabel.Text = "\xF0\x9F\x8E\xB0" -- 🎰
        iconLabel.TextColor3 = COLORS.White
    end

    -- Nom du produit
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ProductName"
    nameLabel.Size = UDim2.new(1, -16, 0, 35)
    nameLabel.Position = UDim2.new(0, 8, 0, 65)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = product.DisplayName
    nameLabel.TextColor3 = COLORS.White
    nameLabel.TextSize = 20
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextStrokeTransparency = 0.6
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextWrapped = true
    nameLabel.Parent = card
end

-- Mapping description text → icône
local DESC_ICONS = {
    Cash = "\xF0\x9F\x92\xB5",        -- 💵
    Lucky = "\xF0\x9F\x8D\x80",       -- 🍀
    Spin = "\xF0\x9F\x8E\xB0",        -- 🎰
    Multiplier = "\xF0\x9F\x93\x88",  -- 📈
    Speed = "\xE2\x9A\xA1",           -- ⚡
}

local function _GetDescIcon(text)
    if string.find(text, "Cash") then return DESC_ICONS.Cash end
    if string.find(text, "Lucky") then return DESC_ICONS.Lucky end
    if string.find(text, "Spin") then return DESC_ICONS.Spin end
    if string.find(text, "Speed") then return DESC_ICONS.Speed end
    if string.find(text, "Multiplier") then return DESC_ICONS.Multiplier end
    return "\xE2\x9C\xA8" -- ✨ fallback
end

function ShopController:_CreateDescriptionCardContent(card, width, height, product, isWideCard)
    -- Titre
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -16, 0, 30)
    titleLabel.Position = UDim2.new(0, 8, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = product.DisplayName
    titleLabel.TextColor3 = COLORS.GoldText
    titleLabel.TextSize = 22
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextStrokeTransparency = 0.5
    titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = card

    -- Container horizontal pour les éléments
    local itemsRow = Instance.new("Frame")
    itemsRow.Name = "ItemsRow"
    itemsRow.Size = UDim2.new(1, -16, 0, 70)
    itemsRow.Position = UDim2.new(0, 8, 0, 42)
    itemsRow.BackgroundTransparency = 1
    itemsRow.BorderSizePixel = 0
    itemsRow.Parent = card

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Padding = UDim.new(0, 6)
    rowLayout.Parent = itemsRow

    local items = product.Description or {}
    local itemCount = #items
    local itemWidth = math.floor((width - 16 - (itemCount - 1) * 6) / itemCount)

    for i, desc in ipairs(items) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Name = "Item_" .. i
        itemFrame.Size = UDim2.new(0, itemWidth, 1, 0)
        itemFrame.BackgroundColor3 = Color3.fromRGB(20, 50, 100)
        itemFrame.BackgroundTransparency = 0.4
        itemFrame.BorderSizePixel = 0
        itemFrame.LayoutOrder = i
        itemFrame.Parent = itemsRow

        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 8)
        itemCorner.Parent = itemFrame

        -- Icône
        local icon = Instance.new("TextLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(1, 0, 0, 30)
        icon.Position = UDim2.new(0, 0, 0, 6)
        icon.BackgroundTransparency = 1
        icon.Text = _GetDescIcon(desc)
        icon.TextSize = 22
        icon.Font = Enum.Font.GothamBold
        icon.Parent = itemFrame

        -- Texte
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, -6, 0, 28)
        label.Position = UDim2.new(0, 3, 0, 36)
        label.BackgroundTransparency = 1
        label.Text = desc
        label.TextColor3 = COLORS.SubText
        label.TextSize = 11
        label.Font = Enum.Font.GothamBold
        label.TextWrapped = true
        label.Parent = itemFrame
    end
end

function ShopController:_CreateRobuxButton(card, width, height, categoryId, productIndex, product, isOwned)
    local robuxBtn = Instance.new("TextButton")
    robuxBtn.Name = "RobuxButton"
    robuxBtn.Size = UDim2.new(0.75, 0, 0, 36)
    robuxBtn.Position = UDim2.new(0.125, 0, 1, -48)
    robuxBtn.BorderSizePixel = 0
    robuxBtn.Text = ""
    robuxBtn.AutoButtonColor = false
    robuxBtn.Parent = card

    local robuxCorner = Instance.new("UICorner")
    robuxCorner.CornerRadius = SIZES.TinyCorner
    robuxCorner.Parent = robuxBtn

    if isOwned then
        robuxBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        robuxBtn.Active = false

        local boughtText = Instance.new("TextLabel")
        boughtText.Name = "BoughtText"
        boughtText.Size = UDim2.new(1, 0, 1, 0)
        boughtText.BackgroundTransparency = 1
        boughtText.Text = "BOUGHT"
        boughtText.TextColor3 = Color3.fromRGB(140, 140, 140)
        boughtText.TextSize = 16
        boughtText.Font = Enum.Font.GothamBold
        boughtText.Parent = robuxBtn
    else
        robuxBtn.BackgroundColor3 = COLORS.RobuxBtnBg

        -- Gradient subtil sur le bouton
        local btnGradient = Instance.new("UIGradient")
        btnGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 180)),
        })
        btnGradient.Rotation = 90
        btnGradient.Parent = robuxBtn

        local robuxText = Instance.new("TextLabel")
        robuxText.Name = "RobuxText"
        robuxText.Size = UDim2.new(1, 0, 1, 0)
        robuxText.BackgroundTransparency = 1
        robuxText.Text = utf8.char(0xE002) .. " " .. self:_FormatNumber(product.Robux)
        robuxText.TextColor3 = COLORS.White
        robuxText.TextSize = 17
        robuxText.Font = Enum.Font.GothamBold
        robuxText.TextStrokeTransparency = 0.6
        robuxText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        robuxText.Parent = robuxBtn

        -- Hover
        robuxBtn.MouseEnter:Connect(function()
            TweenService:Create(robuxBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = COLORS.RobuxBtnHover
            }):Play()
        end)
        robuxBtn.MouseLeave:Connect(function()
            TweenService:Create(robuxBtn, TweenInfo.new(0.15), {
                BackgroundColor3 = COLORS.RobuxBtnBg
            }):Play()
        end)

        -- Clic achat
        robuxBtn.MouseButton1Click:Connect(function()
            self:_OnBuyClicked(categoryId, productIndex, product)
        end)
    end
end

-- ═══════════════════════════════════════════════════════
-- ACTIONS
-- ═══════════════════════════════════════════════════════

function ShopController:_OnBuyClicked(categoryId, productIndex, product)
    local requestRemote = Remotes:FindFirstChild("RequestShopPurchase")
    if requestRemote then
        requestRemote:FireServer(categoryId, productIndex)
    else
        warn("[ShopController] Remote RequestShopPurchase introuvable!")
    end
end

-- ═══════════════════════════════════════════════════════
-- OUVERTURE / FERMETURE
-- ═══════════════════════════════════════════════════════

function ShopController:Open()
    if isOpen then return end
    if not screenGui then return end

    isOpen = true
    screenGui.Enabled = true

    -- Rafraîchir l'onglet courant
    if currentTab then
        self:SwitchTab(currentTab)
    end

    overlay.BackgroundTransparency = 1
    TweenService:Create(overlay, TweenInfo.new(0.25), {
        BackgroundTransparency = COLORS.OverlayTransparency
    }):Play()

    mainFrame.Size = SIZES.PanelClosed
    local tweenOpen = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = SIZES.Panel,
    })
    tweenOpen:Play()
end

function ShopController:Close()
    if not isOpen then return end
    if not screenGui then return end

    TweenService:Create(overlay, TweenInfo.new(0.2), {
        BackgroundTransparency = 1
    }):Play()

    local tweenClose = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = SIZES.PanelClosed,
    })
    tweenClose:Play()

    tweenClose.Completed:Connect(function()
        screenGui.Enabled = false
        isOpen = false
    end)
end

function ShopController:Toggle()
    if isOpen then
        self:Close()
    else
        self:Open()
    end
end

-- ═══════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════

function ShopController:_FormatNumber(number)
    local n = math.floor(number)
    local negative = n < 0
    if negative then n = -n end
    local prefix = negative and "-" or ""

    if n >= 1e15 then
        return prefix .. string.format("%.1fQ", n / 1e15)
    elseif n >= 1e12 then
        return prefix .. string.format("%.1fT", n / 1e12)
    elseif n >= 1e9 then
        return prefix .. string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then
        return prefix .. string.format("%.1fM", n / 1e6)
    elseif n >= 100000 then
        return prefix .. string.format("%.1fK", n / 1e3)
    end

    local formatted = tostring(n)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return prefix .. formatted
end

return ShopController
