--[[
    TEST_SERVER.client.lua
    Script de test pour les données SERVEUR (avec save)
    
    INSTRUCTIONS:
    1. Copier ce script dans StarterPlayerScripts
    2. Lancer le jeu (F5)
    3. Utiliser les boutons pour modifier les VRAIES données serveur
    4. Quitter et rejoindre pour vérifier que les données sont sauvegardées
    5. SUPPRIMER ce script après les tests
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Attendre les Remotes
task.wait(1)
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Créer un ScreenGui pour les boutons de test
local testGui = Instance.new("ScreenGui")
testGui.Name = "TestServerUI"
testGui.ResetOnSpawn = false
testGui.Parent = playerGui

-- Container pour les boutons
local container = Instance.new("Frame")
container.Name = "TestServerButtons"
container.Size = UDim2.new(0, 280, 0, 500)
container.Position = UDim2.new(1, -290, 0.5, -250)
container.BackgroundColor3 = Color3.fromRGB(40, 40, 100)
container.BackgroundTransparency = 0.2
container.Parent = testGui

-- UICorner
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = container

-- Titre
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 50)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "SERVER TEST\n(WITH SAVE)"
title.TextColor3 = Color3.fromRGB(255, 255, 100)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = container

-- ScrollingFrame pour les boutons
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ButtonScroll"
scrollFrame.Size = UDim2.new(1, 0, 1, -50)
scrollFrame.Position = UDim2.new(0, 0, 0, 50)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 8
scrollFrame.Parent = container

-- UIListLayout pour les boutons
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = scrollFrame

-- Fonction pour créer un bouton
local function CreateButton(name, text, color, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0.9, 0, 0, 50)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.Parent = scrollFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = button
    
    button.MouseButton1Click:Connect(callback)
    
    return button
end

-- Espacer le titre (pas nécessaire avec ScrollFrame)
-- Supprimer l'ancien spacer si présent

-- Attendre le RemoteEvent créé par le serveur
local testRemote = remotes:WaitForChild("TestServerData")

-- BOUTON 1: Ajouter $1000 (SERVEUR)
CreateButton("AddCashServer", "+ $1000 Cash\n(SERVER)", Color3.fromRGB(50, 200, 50), function()
    testRemote:FireServer("AddCash", 1000)
end).LayoutOrder = 1

-- BOUTON 2: Retirer $500 (SERVEUR)
CreateButton("RemoveCashServer", "- $500 Cash\n(SERVER)", Color3.fromRGB(200, 50, 50), function()
    testRemote:FireServer("RemoveCash", 500)
end).LayoutOrder = 2

-- BOUTON 3: Ajouter 1 slot (SERVEUR)
CreateButton("AddSlotServer", "+ 1 Slot\n(SERVER)", Color3.fromRGB(100, 150, 200), function()
    testRemote:FireServer("AddSlot", 1)
end).LayoutOrder = 3

-- BOUTON 4: Reset Cash à 100 (SERVEUR)
CreateButton("ResetCashServer", "Reset Cash = $100\n(SERVER)", Color3.fromRGB(150, 100, 50), function()
    testRemote:FireServer("SetCash", 100)
end).LayoutOrder = 4

-- BOUTON 5: Forcer Save NOW
CreateButton("ForceSave", "💾 FORCE SAVE NOW", Color3.fromRGB(200, 100, 200), function()
    testRemote:FireServer("ForceSave")
end).LayoutOrder = 5

-- BOUTON 6: Afficher données actuelles
CreateButton("ShowData", "📊 Show Current Data", Color3.fromRGB(100, 100, 200), function()
    testRemote:FireServer("ShowData")
end).LayoutOrder = 6

-- BOUTON 7: Test complet
CreateButton("FullTest", "🧪 FULL TEST\n(+$5000, +5 slots)", Color3.fromRGB(200, 150, 0), function()
    testRemote:FireServer("FullTest")
end).LayoutOrder = 7

-- BOUTON 8: Clear tous les Brainrots
CreateButton("ClearBrainrots", "🗑️ CLEAR ALL BRAINROTS", Color3.fromRGB(200, 50, 50), function()
    testRemote:FireServer("ClearBrainrots")
end).LayoutOrder = 8

-- BOUTON 9: Clear SlotCash
CreateButton("ClearSlotCash", "💰 CLEAR SLOT CASH", Color3.fromRGB(200, 100, 0), function()
    testRemote:FireServer("ClearSlotCash")
end).LayoutOrder = 9

-- BOUTON 11: Speed +10
CreateButton("SpeedBoost", "⚡ SPEED +10", Color3.fromRGB(100, 200, 255), function()
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = humanoid.WalkSpeed + 10
        end
    end
end).LayoutOrder = 11

-- Info label
local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "Info"
infoLabel.Size = UDim2.new(0.9, 0, 0, 80)
infoLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
infoLabel.BackgroundTransparency = 0.5
infoLabel.Text = "⚠️ Ces boutons modifient\nles VRAIES données serveur\nqui seront SAUVEGARDÉES!"
infoLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
infoLabel.TextScaled = true
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextWrapped = true
infoLabel.LayoutOrder = 12
infoLabel.Parent = scrollFrame

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoLabel

-- Ajuster la taille du canvas
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
end)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)

-- ═══════════════════════════════════════════════════════════════
-- CHEAT MENU - BRAINROT SPAWNER
-- ═══════════════════════════════════════════════════════════════

-- Récupérer BrainrotData
local BrainrotData = require(ReplicatedStorage.Data["BrainrotData.module"])

-- Créer le menu de spawn
local spawnGui = Instance.new("ScreenGui")
spawnGui.Name = "BrainrotSpawnerUI"
spawnGui.ResetOnSpawn = false
spawnGui.Parent = playerGui

-- Container principal
local spawnContainer = Instance.new("Frame")
spawnContainer.Name = "SpawnerContainer"
spawnContainer.Size = UDim2.new(0, 600, 0, 400)
spawnContainer.Position = UDim2.new(0.5, -300, 0.5, -200)
spawnContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
spawnContainer.BackgroundTransparency = 0.1
spawnContainer.Visible = false  -- Caché par défaut
spawnContainer.Parent = spawnGui

local spawnCorner = Instance.new("UICorner")
spawnCorner.CornerRadius = UDim.new(0, 12)
spawnCorner.Parent = spawnContainer

-- Titre du spawner
local spawnTitle = Instance.new("TextLabel")
spawnTitle.Name = "SpawnerTitle"
spawnTitle.Size = UDim2.new(1, 0, 0, 50)
spawnTitle.Position = UDim2.new(0, 0, 0, 0)
spawnTitle.BackgroundTransparency = 1
spawnTitle.Text = "🎮 BRAINROT SPAWNER CHEAT MENU"
spawnTitle.TextColor3 = Color3.fromRGB(255, 100, 255)
spawnTitle.TextSize = 24
spawnTitle.Font = Enum.Font.GothamBold
spawnTitle.Parent = spawnContainer

-- Container pour les 3 listes
local listsContainer = Instance.new("Frame")
listsContainer.Name = "ListsContainer"
listsContainer.Size = UDim2.new(1, -20, 1, -70)
listsContainer.Position = UDim2.new(0, 10, 0, 60)
listsContainer.BackgroundTransparency = 1
listsContainer.Parent = spawnContainer

-- Layout horizontal pour les 3 colonnes
local horizontalLayout = Instance.new("UIListLayout")
horizontalLayout.FillDirection = Enum.FillDirection.Horizontal
horizontalLayout.Padding = UDim.new(0, 10)
horizontalLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
horizontalLayout.Parent = listsContainer

-- Fonction pour créer une colonne de scroll list
local function CreateScrollList(name, pieceType, color)
    local column = Instance.new("Frame")
    column.Name = name .. "Column"
    column.Size = UDim2.new(0.32, 0, 1, 0)
    column.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    column.Parent = listsContainer
    
    local columnCorner = Instance.new("UICorner")
    columnCorner.CornerRadius = UDim.new(0, 8)
    columnCorner.Parent = column
    
    -- Titre de la colonne
    local columnTitle = Instance.new("TextLabel")
    columnTitle.Name = "Title"
    columnTitle.Size = UDim2.new(1, 0, 0, 40)
    columnTitle.BackgroundColor3 = color
    columnTitle.Text = pieceType
    columnTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    columnTitle.TextSize = 18
    columnTitle.Font = Enum.Font.GothamBold
    columnTitle.Parent = column
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = columnTitle
    
    -- ScrollingFrame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, -10, 1, -50)
    scrollFrame.Position = UDim2.new(0, 5, 0, 45)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.Parent = column
    
    -- Layout pour les boutons
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = scrollFrame
    
    -- Parcourir tous les sets et ajouter les pièces disponibles
    for setName, setData in pairs(BrainrotData.Sets) do
        local pieceData = setData[pieceType]
        
        if pieceData and pieceData.TemplateName ~= "" and pieceData.SpawnWeight > 0 then
            -- Créer un bouton pour cette pièce
            local button = Instance.new("TextButton")
            button.Name = setName .. "_" .. pieceType
            button.Size = UDim2.new(0.95, 0, 0, 50)
            button.BackgroundColor3 = color
            button.Text = pieceData.DisplayName .. "\n$" .. pieceData.Price
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextSize = 14
            button.Font = Enum.Font.Gotham
            button.Parent = scrollFrame
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = button
            
            -- Action au clic
            button.MouseButton1Click:Connect(function()
                testRemote:FireServer("SpawnBrainrotPiece", {
                    SetName = setName,
                    PieceType = pieceType
                })
                
                -- Effet visuel
                button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                task.wait(0.1)
                button.BackgroundColor3 = color
            end)
        end
    end
    
    -- Ajuster la taille du canvas
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    
    return column
end

-- Créer les 3 colonnes
CreateScrollList("Head", "Head", Color3.fromRGB(255, 100, 100))
CreateScrollList("Body", "Body", Color3.fromRGB(100, 255, 100))
CreateScrollList("Legs", "Legs", Color3.fromRGB(100, 100, 255))

-- BOUTON 10: Toggle Brainrot Spawner (créé APRÈS spawnContainer)
local toggleButton
toggleButton = CreateButton("ToggleSpawner", "🎮 SHOW SPAWNER", Color3.fromRGB(150, 50, 200), function()
    spawnContainer.Visible = not spawnContainer.Visible
    if spawnContainer.Visible then
        toggleButton.Text = "🎮 HIDE SPAWNER"
        toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 150)
    else
        toggleButton.Text = "🎮 SHOW SPAWNER"
        toggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
    end
end)
toggleButton.LayoutOrder = 10
