--[[
    UIController.lua (ModuleScript)
    Gère toutes les mises à jour de l'UI
    
    Responsabilités:
    - Mettre à jour l'affichage (Cash, Slots, Inventaire)
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

-- UI Elements
local mainHUD = playerGui:WaitForChild("MainHUD")
local notificationUI = playerGui:WaitForChild("NotificationUI")

-- MainHUD Elements
local topBar = mainHUD:WaitForChild("TopBar")
local cashDisplay = topBar:WaitForChild("CashDisplay")
local cashLabel = cashDisplay:WaitForChild("CashLabel")
local slotCashDisplay = topBar:WaitForChild("SlotCashDisplay")
local slotCashLabel = slotCashDisplay:WaitForChild("SlotCashLabel")

local inventoryDisplay = mainHUD:WaitForChild("InventoryDisplay")
local inventoryTitle = inventoryDisplay:WaitForChild("Title")
local craftButton = mainHUD:WaitForChild("CraftButton")

-- Slots d'inventaire
local inventorySlots = {
    inventoryDisplay:WaitForChild("Slot1"),
    inventoryDisplay:WaitForChild("Slot2"),
    inventoryDisplay:WaitForChild("Slot3"),
}

-- NotificationUI Elements
local notifContainer = notificationUI:WaitForChild("Container")
local notifTemplate = notifContainer:WaitForChild("Template")

-- État local
local currentPlayerData = {
    Cash = 0,
    OwnedSlots = 1,
    SlotCash = {},
    PiecesInHand = {},
}

local UIController = {}

-- Couleurs des notifications
local NOTIFICATION_COLORS = {
    Success = Color3.fromRGB(0, 150, 0),
    Error = Color3.fromRGB(200, 50, 50),
    Warning = Color3.fromRGB(200, 150, 0),
    Info = Color3.fromRGB(50, 100, 200),
}

-- Compteur pour LayoutOrder des notifications
local notificationCounter = 0

--[[
    Met à jour l'affichage de l'argent
    @param cash: number
]]
function UIController:UpdateCash(cash)
    currentPlayerData.Cash = cash
    cashLabel.Text = "$" .. self:FormatNumber(cash)
    
    -- Animation de pulse
    self:PulseElement(cashLabel)
end

--[[
    Met à jour l'affichage de l'argent stocké dans les slots
    @param slotCash: table - {[slotIndex] = amount}
]]
function UIController:UpdateSlotCash(slotCash)
    currentPlayerData.SlotCash = slotCash
    
    -- Calculer le total
    local total = 0
    for _, amount in pairs(slotCash) do
        total = total + amount
    end
    
    slotCashLabel.Text = "Slots: $" .. self:FormatNumber(total)
end

--[[
    Met à jour l'affichage de l'inventaire (pièces en main)
    @param pieces: table - Liste des PieceData
]]
function UIController:UpdateInventory(pieces)
    currentPlayerData.PiecesInHand = pieces
    
    -- Mettre à jour le titre
    inventoryTitle.Text = "Pieces in hand (" .. #pieces .. "/3)"
    
    -- Mettre à jour chaque slot
    for i, slot in ipairs(inventorySlots) do
        local label = slot:WaitForChild("Label")
        local piece = pieces[i]
        
        if piece then
            -- Slot occupé
            label.Text = piece.DisplayName .. "\n" .. piece.PieceType
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            slot.BackgroundColor3 = self:GetRarityColor(piece.SetName)
            slot.BackgroundTransparency = 0.3
        else
            -- Slot vide
            label.Text = "Empty"
            label.TextColor3 = Color3.fromRGB(150, 150, 150)
            slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            slot.BackgroundTransparency = 0.5
        end
    end
    
    -- Afficher/masquer le bouton Craft
    craftButton.Visible = (#pieces >= 3)
    
    -- Si 3 pièces, vérifier si on a les 3 types
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
            craftButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
            craftButton.Text = "CRAFT!"
        else
            craftButton.BackgroundColor3 = Color3.fromRGB(150, 150, 0)
            craftButton.Text = "Need 3 types"
        end
    end
end

--[[
    Met à jour toute l'UI avec les nouvelles données
    @param data: table - PlayerData complet ou partiel
]]
function UIController:UpdateAll(data)
    if data.Cash ~= nil then
        self:UpdateCash(data.Cash)
    end
    
    if data.SlotCash ~= nil then
        self:UpdateSlotCash(data.SlotCash)
    end
    
    if data.PiecesInHand ~= nil then
        self:UpdateInventory(data.PiecesInHand)
    end
    
    if data.OwnedSlots ~= nil then
        currentPlayerData.OwnedSlots = data.OwnedSlots
    end
    
    print("[UIController] UI updated")
end

--[[
    Affiche une notification toast
    @param notifType: string - "Success" | "Error" | "Warning" | "Info"
    @param message: string
    @param duration: number (secondes, défaut 3)
]]
function UIController:ShowNotification(notifType, message, duration)
    duration = duration or 3
    
    -- Cloner le template
    local notif = notifTemplate:Clone()
    notif.Name = "Notification_" .. notificationCounter
    notif.Visible = true
    notif.LayoutOrder = notificationCounter
    notificationCounter = notificationCounter + 1
    
    -- Configurer le contenu
    local messageLabel = notif:WaitForChild("Message")
    messageLabel.Text = message
    
    -- Configurer la couleur
    local color = NOTIFICATION_COLORS[notifType] or NOTIFICATION_COLORS.Info
    notif.BackgroundColor3 = color
    
    -- Positionner hors écran (pour animation)
    notif.Position = UDim2.new(-1, 0, 0, 0)
    notif.Parent = notifContainer
    
    -- Animation d'entrée
    local tweenIn = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    })
    tweenIn:Play()
    
    -- Attendre la durée
    task.delay(duration, function()
        -- Animation de sortie
        local tweenOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1
        })
        tweenOut:Play()
        
        tweenOut.Completed:Wait()
        notif:Destroy()
    end)
    
    print("[UIController] Notification: [" .. notifType .. "] " .. message)
end

--[[
    Animation de pulse sur un élément
    @param element: GuiObject
]]
function UIController:PulseElement(element)
    local originalSize = element.Size
    
    local tweenBig = TweenService:Create(element, TweenInfo.new(0.1), {
        Size = UDim2.new(originalSize.X.Scale * 1.1, originalSize.X.Offset, originalSize.Y.Scale * 1.1, originalSize.Y.Offset)
    })
    
    local tweenNormal = TweenService:Create(element, TweenInfo.new(0.1), {
        Size = originalSize
    })
    
    tweenBig:Play()
    tweenBig.Completed:Wait()
    tweenNormal:Play()
end

--[[
    Formate un nombre avec séparateurs de milliers
    @param number: number
    @return string
]]
function UIController:FormatNumber(number)
    local formatted = tostring(math.floor(number))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

--[[
    Récupère la couleur de rareté d'un set
    @param setName: string
    @return Color3
]]
function UIController:GetRarityColor(setName)
    -- TODO: Récupérer depuis BrainrotData
    -- Pour l'instant, couleur par défaut
    return Color3.fromRGB(100, 100, 200)
end

--[[
    Récupère le bouton Craft pour y connecter des événements
    @return TextButton
]]
function UIController:GetCraftButton()
    return craftButton
end

--[[
    Récupère l'état actuel des données locales
    @return table
]]
function UIController:GetCurrentData()
    return currentPlayerData
end

return UIController
