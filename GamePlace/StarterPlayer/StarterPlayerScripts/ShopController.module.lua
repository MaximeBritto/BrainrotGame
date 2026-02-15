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

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- État
local isOpen = false
local currentTab = nil

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
    PanelBg = Color3.fromRGB(25, 30, 20),
    HeaderBg = Color3.fromRGB(20, 25, 15),
    TabActive = Color3.fromRGB(0, 160, 160),
    TabInactive = Color3.fromRGB(50, 60, 45),
    TabText = Color3.fromRGB(255, 255, 255),
    CloseBtn = Color3.fromRGB(200, 40, 40),
    CloseBtnHover = Color3.fromRGB(230, 60, 60),
    CardBg = Color3.fromRGB(20, 60, 20),
    CardBorder = Color3.fromRGB(40, 100, 40),
    RobuxBtnBg = Color3.fromRGB(120, 140, 40),
    RobuxBtnHover = Color3.fromRGB(140, 160, 50),
    White = Color3.fromRGB(255, 255, 255),
    SectionTitle = Color3.fromRGB(255, 255, 255),
}

local GRID = {
    Columns = 3,
    CardWidth = 200,
    CardHeight = 170,
    Spacing = 12,
}

local SIZES = {
    Panel = UDim2.new(0, 700, 0, 550),
    PanelClosed = UDim2.new(0, 0, 0, 0),
    Header = UDim2.new(1, 0, 0, 55),
    TabBar = UDim2.new(1, 0, 0, 40),
    CornerRadius = UDim.new(0, 10),
    SmallCorner = UDim.new(0, 8),
    TinyCorner = UDim.new(0, 6),
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
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = SIZES.PanelClosed
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = COLORS.PanelBg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = overlay

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = SIZES.CornerRadius
    mainCorner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 80, 40)
    stroke.Thickness = 2
    stroke.Parent = mainFrame

    -- Header
    self:_CreateHeader()

    -- TabBar
    self:_CreateTabBar()

    -- Zone de contenu
    self:_CreateContentArea()

    -- Sélectionner le premier onglet
    if #ShopProducts.Categories > 0 then
        local sorted = {}
        for _, cat in ipairs(ShopProducts.Categories) do
            table.insert(sorted, cat)
        end
        table.sort(sorted, function(a, b) return (a.Order or 99) < (b.Order or 99) end)
        self:SwitchTab(sorted[1].Id)
    end

    print("[ShopController] Initialisé!")
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

    -- Titre BOUTIQUE
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "SHOP"
    title.TextColor3 = COLORS.White
    title.TextSize = 32
    title.Font = Enum.Font.GothamBlack
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Bouton X
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 45, 0, 45)
    closeBtn.Position = UDim2.new(1, -50, 0, 5)
    closeBtn.BackgroundColor3 = COLORS.CloseBtn
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = COLORS.White
    closeBtn.TextSize = 24
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = SIZES.SmallCorner
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseEnter:Connect(function()
        closeBtn.BackgroundColor3 = COLORS.CloseBtnHover
    end)
    closeBtn.MouseLeave:Connect(function()
        closeBtn.BackgroundColor3 = COLORS.CloseBtn
    end)
    closeBtn.MouseButton1Click:Connect(function()
        self:Close()
    end)
end

function ShopController:_CreateTabBar()
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = SIZES.TabBar
    tabBar.Position = UDim2.new(0, 0, 0, 55)
    tabBar.BackgroundColor3 = COLORS.HeaderBg
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 4)
    layout.Parent = tabBar

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
        tabBtn.Size = UDim2.new(0, 160, 0, 34)
        tabBtn.BackgroundColor3 = COLORS.TabInactive
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = category.DisplayName
        tabBtn.TextColor3 = COLORS.TabText
        tabBtn.TextSize = 16
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.Parent = tabBar

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 6)
        tabCorner.Parent = tabBtn

        tabBtn.MouseButton1Click:Connect(function()
            self:SwitchTab(category.Id)
        end)

        tabButtons[category.Id] = tabBtn
    end
end

function ShopController:_CreateContentArea()
    contentScroll = Instance.new("ScrollingFrame")
    contentScroll.Name = "ContentScroll"
    contentScroll.Size = UDim2.new(1, -20, 1, -105)
    contentScroll.Position = UDim2.new(0, 10, 0, 100)
    contentScroll.BackgroundTransparency = 1
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 6
    contentScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 100, 60)
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentScroll.Parent = mainFrame
end

-- ═══════════════════════════════════════════════════════
-- ONGLETS ET CONTENU
-- ═══════════════════════════════════════════════════════

function ShopController:SwitchTab(categoryId)
    currentTab = categoryId

    for id, btn in pairs(tabButtons) do
        if id == categoryId then
            btn.BackgroundColor3 = COLORS.TabActive
        else
            btn.BackgroundColor3 = COLORS.TabInactive
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

    -- Titre de la section
    local sectionTitle = Instance.new("TextLabel")
    sectionTitle.Name = "SectionTitle"
    sectionTitle.Size = UDim2.new(1, 0, 0, 45)
    sectionTitle.Position = UDim2.new(0, 0, 0, 5)
    sectionTitle.BackgroundTransparency = 1
    sectionTitle.Text = category.DisplayName
    sectionTitle.TextColor3 = COLORS.SectionTitle
    sectionTitle.TextSize = 30
    sectionTitle.Font = Enum.Font.GothamBlack
    sectionTitle.Parent = contentScroll

    -- Container pour la grille
    local gridContainer = Instance.new("Frame")
    gridContainer.Name = "GridContainer"
    gridContainer.Position = UDim2.new(0, 0, 0, 55)
    gridContainer.BackgroundTransparency = 1
    gridContainer.BorderSizePixel = 0
    gridContainer.Parent = contentScroll

    -- Calculer la taille de la grille
    local products = category.Products
    local totalProducts = #products
    local cols = GRID.Columns
    local rows = math.ceil(totalProducts / cols)

    local scrollWidth = 680  -- largeur du ScrollingFrame (panel 700 - 20 padding)
    local cardW = math.floor((scrollWidth - (cols - 1) * GRID.Spacing) / cols)
    local cardH = GRID.CardHeight

    local totalGridHeight = rows * cardH + (rows - 1) * GRID.Spacing
    gridContainer.Size = UDim2.new(1, 0, 0, totalGridHeight)

    -- Positionner chaque carte dans la grille (centrée)
    for index, product in ipairs(products) do
        local row = math.floor((index - 1) / cols)
        local col = (index - 1) % cols

        -- Calculer combien d'items restent sur cette rangée
        local itemsOnThisRow = math.min(cols, totalProducts - row * cols)
        local thisCardW = cardW
        local rowTotalWidth = cols * cardW + (cols - 1) * GRID.Spacing
        if itemsOnThisRow < cols then
            thisCardW = math.floor((scrollWidth - (itemsOnThisRow - 1) * GRID.Spacing) / itemsOnThisRow)
            rowTotalWidth = itemsOnThisRow * thisCardW + (itemsOnThisRow - 1) * GRID.Spacing
        end

        local leftOffset = math.floor((scrollWidth - rowTotalWidth) / 2)
        local xPos = leftOffset + col * (thisCardW + GRID.Spacing)
        local yPos = row * (cardH + GRID.Spacing)

        self:_CreateGridCard(gridContainer, xPos, yPos, thisCardW, cardH, category.Id, index, product)
    end

    -- Mettre à jour le canvas
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, 55 + totalGridHeight + 20)
end

function ShopController:_CreateGridCard(parent, xPos, yPos, width, height, categoryId, productIndex, product)
    -- Carte
    local card = Instance.new("Frame")
    card.Name = "Product_" .. productIndex
    card.Size = UDim2.new(0, width, 0, height)
    card.Position = UDim2.new(0, xPos, 0, yPos)
    card.BackgroundColor3 = COLORS.CardBg
    card.BorderSizePixel = 0
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = SIZES.SmallCorner
    cardCorner.Parent = card

    -- Bordure verte subtile
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = COLORS.CardBorder
    cardStroke.Thickness = 2
    cardStroke.Parent = card

    -- Gradient subtil (plus clair en haut)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)),
    })
    gradient.Rotation = 90
    gradient.Parent = card

    -- Icône de cash (TextLabel avec symbole $)
    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IconFrame"
    iconFrame.Size = UDim2.new(0, 60, 0, 50)
    iconFrame.Position = UDim2.new(0, 10, 0, 15)
    iconFrame.BackgroundTransparency = 1
    iconFrame.Parent = card

    local cashIcon = Instance.new("TextLabel")
    cashIcon.Name = "CashIcon"
    cashIcon.Size = UDim2.new(1, 0, 1, 0)
    cashIcon.BackgroundTransparency = 1
    cashIcon.Text = "$"
    cashIcon.TextColor3 = Color3.fromRGB(100, 200, 100)
    cashIcon.TextSize = 40
    cashIcon.Font = Enum.Font.GothamBlack
    cashIcon.Parent = iconFrame

    -- Montant en gros
    local amountLabel = Instance.new("TextLabel")
    amountLabel.Name = "Amount"
    amountLabel.Size = UDim2.new(1, -10, 0, 40)
    amountLabel.Position = UDim2.new(0, 5, 0, 15)
    amountLabel.BackgroundTransparency = 1
    amountLabel.Text = product.DisplayName
    amountLabel.TextColor3 = COLORS.White
    amountLabel.TextSize = 28
    amountLabel.Font = Enum.Font.GothamBlack
    amountLabel.TextStrokeTransparency = 0.6
    amountLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    amountLabel.Parent = card

    -- Bouton Robux en bas
    local robuxBtn = Instance.new("TextButton")
    robuxBtn.Name = "RobuxButton"
    robuxBtn.Size = UDim2.new(0.7, 0, 0, 35)
    robuxBtn.Position = UDim2.new(0.15, 0, 1, -50)
    robuxBtn.BackgroundColor3 = COLORS.RobuxBtnBg
    robuxBtn.BorderSizePixel = 0
    robuxBtn.Text = ""
    robuxBtn.AutoButtonColor = false
    robuxBtn.Parent = card

    local robuxCorner = Instance.new("UICorner")
    robuxCorner.CornerRadius = SIZES.TinyCorner
    robuxCorner.Parent = robuxBtn

    -- Icône Robux (unicode) + prix
    local robuxText = Instance.new("TextLabel")
    robuxText.Name = "RobuxText"
    robuxText.Size = UDim2.new(1, 0, 1, 0)
    robuxText.BackgroundTransparency = 1
    robuxText.Text = utf8.char(0xE002) .. self:_FormatNumber(product.Robux)
    robuxText.TextColor3 = COLORS.White
    robuxText.TextSize = 18
    robuxText.Font = Enum.Font.GothamBold
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

    -- Hover sur toute la carte (léger brighten)
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(cardStroke, TweenInfo.new(0.15), {
                Color = Color3.fromRGB(80, 160, 80)
            }):Play()
        end
    end)
    card.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(cardStroke, TweenInfo.new(0.15), {
                Color = COLORS.CardBorder
            }):Play()
        end
    end)
end

-- ═══════════════════════════════════════════════════════
-- ACTIONS
-- ═══════════════════════════════════════════════════════

function ShopController:_OnBuyClicked(categoryId, productIndex, product)
    print(string.format("[ShopController] Achat cliqué: %s #%d (%s, R$%d)",
        categoryId, productIndex, product.DisplayName, product.Robux))

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

    overlay.BackgroundTransparency = 1
    TweenService:Create(overlay, TweenInfo.new(0.25), {
        BackgroundTransparency = COLORS.OverlayTransparency
    }):Play()

    mainFrame.Size = SIZES.PanelClosed
    local tweenOpen = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = SIZES.Panel,
    })
    tweenOpen:Play()

    print("[ShopController] Shop ouvert")
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

    print("[ShopController] Shop fermé")
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
    local formatted = tostring(math.floor(number))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

return ShopController
