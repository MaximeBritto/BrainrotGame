--[[
    UIController.lua (ModuleScript)
    Gère toutes les mises à jour de l'UI - HUD entièrement programmatique

    Responsabilités:
    - Créer le HUD complet (Cash, Inventaire, Notifications)
    - Mettre à jour l'affichage
    - Afficher les notifications
    - Gérer les animations UI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])
local BrainrotData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))
local ResponsiveScale = require(Shared["ResponsiveScale.module"])

-- ═══════════════════════════════════════════════════════
-- CONSTANTES VISUELLES
-- ═══════════════════════════════════════════════════════

local COLORS = {
    HudBg = Color3.fromRGB(30, 30, 40),
    HudBgLight = Color3.fromRGB(45, 45, 55),
    CashBg = Color3.fromRGB(25, 100, 25),
    CashBgHover = Color3.fromRGB(30, 120, 30),
    CashIcon = Color3.fromRGB(255, 220, 50),
    SlotEmpty = Color3.fromRGB(55, 55, 65),
    SlotEmptyText = Color3.fromRGB(120, 120, 130),
    White = Color3.fromRGB(255, 255, 255),
    CraftGreen = Color3.fromRGB(0, 200, 0),
    CraftYellow = Color3.fromRGB(150, 150, 0),
    DropRed = Color3.fromRGB(180, 40, 40),
}

local FONTS = {
    Bold = Enum.Font.GothamBold,
    Black = Enum.Font.GothamBlack,
    Regular = Enum.Font.Gotham,
}

-- Icônes de type par slot (slot 1=Head, 2=Body, 3=Legs)
-- Couleurs nude/neutres, distinctes des raretés (blanc, bleu, violet, or)
local SLOT_TYPE_INFO = {
    [1] = { Symbol = "▲", Color = Color3.fromRGB(195, 150, 130), Label = "HEAD" },  -- terracotta rosé
    [2] = { Symbol = "■", Color = Color3.fromRGB(165, 155, 135), Label = "BODY" },  -- pierre/taupe
    [3] = { Symbol = "●", Color = Color3.fromRGB(140, 155, 160), Label = "LEGS" },  -- ardoise gris-bleu (très désaturé)
}

-- ═══════════════════════════════════════════════════════
-- ÉTAT LOCAL
-- ═══════════════════════════════════════════════════════

local currentPlayerData = {
    Cash = 0,
    OwnedSlots = 10,
    PiecesInHand = {},
}

local UIController = {}

-- Références UI
UIController._screenGui = nil
UIController._cashLabel = nil
UIController._inventoryTitle = nil
UIController._inventorySlots = {}
UIController._craftLabel = nil
UIController._dropButton = nil
UIController._notifContainer = nil
UIController._notifTemplate = nil
UIController._initialized = false

-- Couleurs des notifications
local NOTIFICATION_COLORS = {
    Success = Color3.fromRGB(0, 150, 0),
    Error = Color3.fromRGB(200, 50, 50),
    Warning = Color3.fromRGB(200, 150, 0),
    Info = Color3.fromRGB(50, 100, 200),
}

local notificationCounter = 0

-- ═══════════════════════════════════════════════════════
-- INITIALISATION - Crée tout le HUD
-- ═══════════════════════════════════════════════════════

function UIController:Init()
    if self._initialized then return end

    -- ScreenGui principal
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GameHUD"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 5
    screenGui.Parent = playerGui
    self._screenGui = screenGui

    -- Responsive scaling
    ResponsiveScale.Apply(screenGui)

    -- Créer les éléments du HUD
    self:_CreateCashDisplay(screenGui)
    self:_CreateInventoryDisplay(screenGui)

    -- Notifications: utiliser le NotificationUI pré-existant
    local notificationUI = playerGui:WaitForChild("NotificationUI")
    ResponsiveScale.Apply(notificationUI)
    self._notifContainer = notificationUI:WaitForChild("Container")
    self._notifTemplate = self._notifContainer:WaitForChild("Template")

    -- Centrer les notifications au milieu, au-dessus de l'inventaire
    self._notifContainer.AnchorPoint = Vector2.new(0.5, 1)
    self._notifContainer.Position = UDim2.new(0.5, 0, 0.75, 0)

    self._initialized = true
end

-- ═══════════════════════════════════════════════════════
-- CASH DISPLAY (bas-gauche)
-- ═══════════════════════════════════════════════════════

function UIController:_CreateCashDisplay(parent)
    -- Container principal - pilule verte
    local cashFrame = Instance.new("Frame")
    cashFrame.Name = "CashDisplay"
    cashFrame.Size = UDim2.new(0, 220, 0, 50)
    cashFrame.Position = UDim2.new(0, 15, 1, -20)
    cashFrame.AnchorPoint = Vector2.new(0, 1)
    cashFrame.BackgroundColor3 = COLORS.CashBg
    cashFrame.BackgroundTransparency = 0.15
    cashFrame.BorderSizePixel = 0
    cashFrame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = cashFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 140, 40)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = cashFrame

    -- Icône dollar
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "CashIcon"
    iconLabel.Size = UDim2.new(0, 40, 0, 40)
    iconLabel.Position = UDim2.new(0, 8, 0.5, 0)
    iconLabel.AnchorPoint = Vector2.new(0, 0.5)
    iconLabel.BackgroundColor3 = COLORS.CashIcon
    iconLabel.BackgroundTransparency = 0
    iconLabel.Text = "$"
    iconLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
    iconLabel.TextSize = 22
    iconLabel.Font = FONTS.Black
    iconLabel.BorderSizePixel = 0
    iconLabel.Parent = cashFrame

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 10)
    iconCorner.Parent = iconLabel

    -- Montant
    local cashLabel = Instance.new("TextLabel")
    cashLabel.Name = "CashLabel"
    cashLabel.Size = UDim2.new(1, -60, 1, 0)
    cashLabel.Position = UDim2.new(0, 55, 0, 0)
    cashLabel.BackgroundTransparency = 1
    cashLabel.Text = "$100"
    cashLabel.TextColor3 = COLORS.White
    cashLabel.TextSize = 22
    cashLabel.Font = FONTS.Black
    cashLabel.TextXAlignment = Enum.TextXAlignment.Left
    cashLabel.TextTruncate = Enum.TextTruncate.AtEnd
    cashLabel.Parent = cashFrame

    self._cashLabel = cashLabel
    self._cashFrame = cashFrame

end

-- ═══════════════════════════════════════════════════════
-- INVENTORY DISPLAY (bas-droite)
-- ═══════════════════════════════════════════════════════

function UIController:_CreateInventoryDisplay(parent)
    -- Container
    local invContainer = Instance.new("Frame")
    invContainer.Name = "InventoryDisplay"
    invContainer.Size = UDim2.new(0, 310, 0, 170)
    invContainer.Position = UDim2.new(1, -15, 1, -15)
    invContainer.AnchorPoint = Vector2.new(1, 1)
    invContainer.BackgroundTransparency = 1
    invContainer.BorderSizePixel = 0
    invContainer.Parent = parent

    -- Titre "PIECES IN HAND (0/3)"
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 22)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "PIECES IN HAND (0/3)"
    title.TextColor3 = Color3.fromRGB(200, 200, 210)
    title.TextSize = 14
    title.Font = FONTS.Black
    title.TextXAlignment = Enum.TextXAlignment.Right
    title.Parent = invContainer

    self._inventoryTitle = title

    -- Label prix total (en dessous du titre)
    local priceTotalLabel = Instance.new("TextLabel")
    priceTotalLabel.Name = "PriceTotalLabel"
    priceTotalLabel.Size = UDim2.new(1, 0, 0, 28)
    priceTotalLabel.Position = UDim2.new(0, 0, 0, 20)
    priceTotalLabel.BackgroundTransparency = 1
    priceTotalLabel.Text = ""
    priceTotalLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
    priceTotalLabel.TextSize = 22
    priceTotalLabel.Font = FONTS.Black
    priceTotalLabel.TextXAlignment = Enum.TextXAlignment.Right
    priceTotalLabel.TextStrokeTransparency = 0.5
    priceTotalLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    priceTotalLabel.Visible = false
    priceTotalLabel.Parent = invContainer

    self._priceTotalLabel = priceTotalLabel

    -- Container pour les 3 slots
    local slotsContainer = Instance.new("Frame")
    slotsContainer.Name = "SlotsContainer"
    slotsContainer.Size = UDim2.new(1, 0, 0, 115)
    slotsContainer.Position = UDim2.new(0, 0, 0, 50)
    slotsContainer.BackgroundTransparency = 1
    slotsContainer.Parent = invContainer

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = slotsContainer

    -- Créer 3 slots
    self._inventorySlots = {}
    for i = 1, 3 do
        local slot = self:_CreateInventorySlot(slotsContainer, i)
        self._inventorySlots[i] = slot
    end

    -- Message Craft (au-dessus de l'inventaire, centré) - remplace l'ancien bouton
    local craftLabel = Instance.new("TextLabel")
    craftLabel.Name = "CraftLabel"
    craftLabel.Size = UDim2.new(1, 0, 0, 40)
    craftLabel.Position = UDim2.new(0, 0, 0, -48)
    craftLabel.AnchorPoint = Vector2.new(0, 0)
    craftLabel.BackgroundColor3 = COLORS.CraftGreen
    craftLabel.BackgroundTransparency = 0.15
    craftLabel.BorderSizePixel = 0
    craftLabel.Text = "Go place your Brainrot at your base!"
    craftLabel.TextColor3 = COLORS.White
    craftLabel.TextSize = 16
    craftLabel.Font = FONTS.Black
    craftLabel.Visible = false
    craftLabel.Parent = invContainer

    local craftCorner = Instance.new("UICorner")
    craftCorner.CornerRadius = UDim.new(0, 10)
    craftCorner.Parent = craftLabel

    local craftStroke = Instance.new("UIStroke")
    craftStroke.Color = Color3.fromRGB(0, 255, 0)
    craftStroke.Thickness = 2
    craftStroke.Transparency = 0.5
    craftStroke.Parent = craftLabel

    self._craftLabel = craftLabel

    -- Bouton Drop (à gauche du Craft, visible dès 1 pièce)
    local dropButton = Instance.new("TextButton")
    dropButton.Name = "DropButton"
    dropButton.Size = UDim2.new(1, 0, 0, 40)
    dropButton.Position = UDim2.new(0, 0, 0, -96)
    dropButton.AnchorPoint = Vector2.new(0, 0)
    dropButton.BackgroundColor3 = COLORS.DropRed
    dropButton.BorderSizePixel = 0
    dropButton.Text = "DROP"
    dropButton.TextColor3 = COLORS.White
    dropButton.TextSize = 18
    dropButton.Font = FONTS.Black
    dropButton.Visible = false
    dropButton.AutoButtonColor = false
    dropButton.Parent = invContainer

    local dropCorner = Instance.new("UICorner")
    dropCorner.CornerRadius = UDim.new(0, 10)
    dropCorner.Parent = dropButton

    local dropStroke = Instance.new("UIStroke")
    dropStroke.Color = Color3.fromRGB(220, 60, 60)
    dropStroke.Thickness = 2
    dropStroke.Transparency = 0.5
    dropStroke.Parent = dropButton

    -- Hover effect
    dropButton.MouseEnter:Connect(function()
        TweenService:Create(dropButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(210, 50, 50)
        }):Play()
    end)
    dropButton.MouseLeave:Connect(function()
        TweenService:Create(dropButton, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.DropRed
        }):Play()
    end)

    self._dropButton = dropButton
end

function UIController:_CreateInventorySlot(parent, index)
    local slot = Instance.new("Frame")
    slot.Name = "Slot" .. index
    slot.Size = UDim2.new(0, 93, 0, 115)
    slot.LayoutOrder = index
    slot.BackgroundColor3 = COLORS.SlotEmpty
    slot.BackgroundTransparency = 0.2
    slot.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = slot

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(75, 75, 85)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = slot

    -- Icône de type (▲/■/●) visible quand vide
    local typeInfo = SLOT_TYPE_INFO[index] or { Symbol = "?", Color = Color3.fromRGB(75, 75, 85), Label = "EMPTY" }
    local dimColor = Color3.fromRGB(
        math.floor(typeInfo.Color.R * 255 * 0.35),
        math.floor(typeInfo.Color.G * 255 * 0.35),
        math.floor(typeInfo.Color.B * 255 * 0.35)
    )

    local questionIcon = Instance.new("TextLabel")
    questionIcon.Name = "QuestionIcon"
    questionIcon.Size = UDim2.new(0, 44, 0, 44)
    questionIcon.Position = UDim2.new(0.5, 0, 0.38, 0)
    questionIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    questionIcon.BackgroundColor3 = dimColor
    questionIcon.BackgroundTransparency = 0.2
    questionIcon.Text = typeInfo.Symbol
    questionIcon.TextColor3 = typeInfo.Color
    questionIcon.TextSize = 22
    questionIcon.Font = FONTS.Black
    questionIcon.BorderSizePixel = 0
    questionIcon.Parent = slot

    local qCorner = Instance.new("UICorner")
    qCorner.CornerRadius = UDim.new(0, 10)
    qCorner.Parent = questionIcon

    -- Label du type (HEAD/BODY/LEGS) visible quand vide
    local emptyLabel = Instance.new("TextLabel")
    emptyLabel.Name = "EmptyLabel"
    emptyLabel.Size = UDim2.new(1, 0, 0, 18)
    emptyLabel.Position = UDim2.new(0, 0, 1, -25)
    emptyLabel.BackgroundTransparency = 1
    emptyLabel.Text = typeInfo.Label
    emptyLabel.TextColor3 = typeInfo.Color
    emptyLabel.TextSize = 11
    emptyLabel.Font = FONTS.Bold
    emptyLabel.Parent = slot

    -- Label pour pièce (visible quand occupé)
    local pieceLabel = Instance.new("TextLabel")
    pieceLabel.Name = "PieceLabel"
    pieceLabel.Size = UDim2.new(1, -8, 0, 40)
    pieceLabel.Position = UDim2.new(0, 4, 0.5, -5)
    pieceLabel.AnchorPoint = Vector2.new(0, 0.5)
    pieceLabel.BackgroundTransparency = 1
    pieceLabel.Text = ""
    pieceLabel.TextColor3 = COLORS.White
    pieceLabel.TextSize = 12
    pieceLabel.Font = FONTS.Bold
    pieceLabel.TextWrapped = true
    pieceLabel.Visible = false
    pieceLabel.Parent = slot

    -- Type de pièce (Head/Body/Legs)
    local typeLabel = Instance.new("TextLabel")
    typeLabel.Name = "TypeLabel"
    typeLabel.Size = UDim2.new(1, 0, 0, 16)
    typeLabel.Position = UDim2.new(0, 0, 1, -22)
    typeLabel.BackgroundTransparency = 1
    typeLabel.Text = ""
    typeLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    typeLabel.TextSize = 10
    typeLabel.Font = FONTS.Regular
    typeLabel.Visible = false
    typeLabel.Parent = slot

    slot.Parent = parent

    return {
        Frame = slot,
        QuestionIcon = questionIcon,
        EmptyLabel = emptyLabel,
        PieceLabel = pieceLabel,
        TypeLabel = typeLabel,
        Stroke = stroke,
    }
end

-- ═══════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════

-- _CreateNotificationArea supprimé: on utilise le NotificationUI pré-existant

-- ═══════════════════════════════════════════════════════
-- MISE À JOUR DU CASH
-- ═══════════════════════════════════════════════════════

function UIController:UpdateCash(cash)
    currentPlayerData.Cash = cash
    if self._cashLabel then
        self._cashLabel.Text = "$" .. self:FormatNumber(cash)
    end

    -- Animation de pulse
    if self._cashFrame then
        self:PulseElement(self._cashFrame)
    end
end


-- ═══════════════════════════════════════════════════════
-- MISE À JOUR DE L'INVENTAIRE
-- ═══════════════════════════════════════════════════════

function UIController:UpdateInventory(pieces)
    currentPlayerData.PiecesInHand = pieces

    -- Mettre à jour le titre
    if self._inventoryTitle then
        self._inventoryTitle.Text = "PIECES IN HAND (" .. #pieces .. "/3)"
    end

    -- Trier les pièces par type : Head → slot 1, Body → slot 2, Legs → slot 3
    local sortedPieces = {nil, nil, nil}
    for _, piece in ipairs(pieces) do
        if piece.PieceType == Constants.PieceType.Head then
            sortedPieces[1] = piece
        elseif piece.PieceType == Constants.PieceType.Body then
            sortedPieces[2] = piece
        elseif piece.PieceType == Constants.PieceType.Legs then
            sortedPieces[3] = piece
        end
    end

    -- Mettre à jour chaque slot
    for i, slotData in ipairs(self._inventorySlots) do
        local piece = sortedPieces[i]

        if piece then
            -- Slot occupé - fond sombre, couleur de rareté sur le contour et le type
            slotData.QuestionIcon.Visible = false
            slotData.EmptyLabel.Visible = false
            slotData.PieceLabel.Visible = true
            slotData.PieceLabel.Text = piece.DisplayName
            slotData.TypeLabel.Visible = true
            slotData.TypeLabel.Text = piece.PieceType

            local rarityColor = self:GetRarityColor(piece.SetName)
            slotData.Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            slotData.Frame.BackgroundTransparency = 0.1
            slotData.Stroke.Color = rarityColor
            slotData.Stroke.Transparency = 0
            slotData.TypeLabel.TextColor3 = rarityColor
        else
            -- Slot vide
            slotData.QuestionIcon.Visible = true
            slotData.EmptyLabel.Visible = true
            slotData.PieceLabel.Visible = false
            slotData.TypeLabel.Visible = false

            local typeInfo = SLOT_TYPE_INFO[i]
            slotData.Frame.BackgroundColor3 = COLORS.SlotEmpty
            slotData.Frame.BackgroundTransparency = 0.2
            if typeInfo then
                local dimColor = Color3.fromRGB(
                    math.floor(typeInfo.Color.R * 255 * 0.35),
                    math.floor(typeInfo.Color.G * 255 * 0.35),
                    math.floor(typeInfo.Color.B * 255 * 0.35)
                )
                slotData.Stroke.Color = dimColor
                slotData.Stroke.Transparency = 0.1
            else
                slotData.Stroke.Color = Color3.fromRGB(75, 75, 85)
                slotData.Stroke.Transparency = 0.3
            end
            slotData.TypeLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
        end
    end

    -- Afficher/masquer le prix total cumulé
    if self._priceTotalLabel then
        if #pieces >= 1 then
            local total = 0
            for _, piece in ipairs(pieces) do
                total = total + (piece.Price or 0)
            end
            self._priceTotalLabel.Text = "Craft cost: $" .. self:FormatNumber(total)
            self._priceTotalLabel.Visible = true
        else
            self._priceTotalLabel.Visible = false
        end
    end

    -- Afficher/masquer le bouton Drop (dès 1 pièce)
    if self._dropButton then
        self._dropButton.Visible = (#pieces >= 1)
    end

    -- Afficher/masquer le message Craft
    if self._craftLabel then
        self._craftLabel.Visible = (#pieces >= 3)

        if #pieces >= 3 then
            local hasHead = false
            local hasBody = false
            local hasLegs = false

            for _, piece in ipairs(pieces) do
                if piece.PieceType == Constants.PieceType.Head then hasHead = true end
                if piece.PieceType == Constants.PieceType.Body then hasBody = true end
                if piece.PieceType == Constants.PieceType.Legs then hasLegs = true end
            end

            if hasHead and hasBody and hasLegs then
                self._craftLabel.BackgroundColor3 = COLORS.CraftGreen
                self._craftLabel.Text = "Go place your Brainrot at your base!"
                self._craftReady = true
            else
                self._craftLabel.BackgroundColor3 = COLORS.CraftYellow
                self._craftLabel.Text = "Need 3 different types!"
                self._craftReady = false
            end
        else
            self._craftReady = false
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- MISE À JOUR GLOBALE
-- ═══════════════════════════════════════════════════════

function UIController:UpdateAll(data)
    if data.Cash ~= nil then
        self:UpdateCash(data.Cash)
    end


    if data.PiecesInHand ~= nil then
        self:UpdateInventory(data.PiecesInHand)
    end

    if data.OwnedSlots ~= nil then
        currentPlayerData.OwnedSlots = data.OwnedSlots
    end
end

-- ═══════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════

function UIController:ShowNotification(notifType, message, duration)
    duration = duration or 3

    if not self._notifContainer or not self._notifTemplate then return end

    -- Cloner le template
    local notif = self._notifTemplate:Clone()
    notif.Name = "Notification_" .. notificationCounter
    notif.Visible = true
    notif.LayoutOrder = notificationCounter
    notificationCounter = notificationCounter + 1

    -- Configurer le contenu
    local messageLabel = notif:FindFirstChild("Message")
    if not messageLabel then return end
    messageLabel.Text = message

    -- Configurer la couleur
    local color = NOTIFICATION_COLORS[notifType] or NOTIFICATION_COLORS.Info
    notif.BackgroundColor3 = color

    -- Positionner hors écran (apparition par le bas)
    notif.Position = UDim2.new(0, 0, 0, 20)
    notif.Parent = self._notifContainer

    -- Animation d'entrée (fade in + slide up)
    local tweenIn = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0),
    })
    tweenIn:Play()

    -- Attendre la durée
    task.delay(duration, function()
        -- Animation de sortie (fade out + slide up)
        local tweenOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0, 0, 0, -20),
            BackgroundTransparency = 1
        })
        tweenOut:Play()

        tweenOut.Completed:Wait()
        notif:Destroy()
    end)
end

-- ═══════════════════════════════════════════════════════
-- ANIMATIONS
-- ═══════════════════════════════════════════════════════

function UIController:PulseElement(element)
    local originalSize = element.Size

    local tweenBig = TweenService:Create(element, TweenInfo.new(0.1), {
        Size = UDim2.new(originalSize.X.Scale * 1.05, math.floor(originalSize.X.Offset * 1.05), originalSize.Y.Scale * 1.05, math.floor(originalSize.Y.Offset * 1.05))
    })

    local tweenNormal = TweenService:Create(element, TweenInfo.new(0.1), {
        Size = originalSize
    })

    tweenBig:Play()
    tweenBig.Completed:Wait()
    tweenNormal:Play()
end

function UIController:AnimateCashGain(amount)
    if not self._screenGui then return end

    local floatingText = Instance.new("TextLabel")
    floatingText.Name = "CashGain"
    floatingText.Size = UDim2.new(0, 150, 0, 40)
    floatingText.Position = UDim2.new(0.5, -75, 0.4, 0)
    floatingText.BackgroundTransparency = 1
    floatingText.Text = "+$" .. self:FormatNumber(amount)
    floatingText.TextColor3 = Color3.fromRGB(0, 255, 100)
    floatingText.TextScaled = true
    floatingText.Font = FONTS.Black
    floatingText.TextStrokeTransparency = 0.5
    floatingText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    floatingText.Parent = self._screenGui

    local tweenUp = TweenService:Create(floatingText, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -75, 0.2, 0),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })

    tweenUp:Play()
    tweenUp.Completed:Connect(function()
        floatingText:Destroy()
    end)
end

function UIController:AnimateCashLoss(amount)
    if not self._screenGui then return end

    local floatingText = Instance.new("TextLabel")
    floatingText.Name = "CashLoss"
    floatingText.Size = UDim2.new(0, 150, 0, 40)
    floatingText.Position = UDim2.new(0.5, -75, 0.4, 0)
    floatingText.BackgroundTransparency = 1
    floatingText.Text = "-$" .. self:FormatNumber(amount)
    floatingText.TextColor3 = Color3.fromRGB(255, 80, 80)
    floatingText.TextScaled = true
    floatingText.Font = FONTS.Black
    floatingText.TextStrokeTransparency = 0.5
    floatingText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    floatingText.Parent = self._screenGui

    local tweenDown = TweenService:Create(floatingText, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -75, 0.6, 0),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })

    tweenDown:Play()
    tweenDown.Completed:Connect(function()
        floatingText:Destroy()
    end)
end

function UIController:UpdateCashAnimated(newCash, oldCash)
    oldCash = oldCash or currentPlayerData.Cash

    local difference = newCash - oldCash

    self:UpdateCash(newCash)

    if difference > 0 then
        self:AnimateCashGain(difference)
    elseif difference < 0 then
        self:AnimateCashLoss(math.abs(difference))
    end
end

-- ═══════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════

function UIController:FormatNumber(number)
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

function UIController:GetRarityColor(setName)
    local setData = BrainrotData.Sets and BrainrotData.Sets[setName]
    if setData then
        local rarity = setData.Rarity or "Common"
        local rarityInfo = BrainrotData.Rarities and BrainrotData.Rarities[rarity]
        if rarityInfo and rarityInfo.Color then
            return rarityInfo.Color
        end
    end
    return Color3.fromRGB(100, 100, 200)
end

function UIController:IsCraftReady()
    return self._craftReady == true
end

function UIController:GetDropButton()
    return self._dropButton
end

function UIController:GetCurrentData()
    return currentPlayerData
end

function UIController:GetScreenGui()
    return self._screenGui
end

return UIController
