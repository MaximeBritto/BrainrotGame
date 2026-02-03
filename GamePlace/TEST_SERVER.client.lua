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

print("═══════════════════════════════════════════════")
print("   TEST SERVER - Boutons de test serveur créés")
print("═══════════════════════════════════════════════")

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

-- UIListLayout pour les boutons
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = container

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
    button.Parent = container
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = button
    
    button.MouseButton1Click:Connect(callback)
    
    return button
end

-- Espacer le titre
local spacer = Instance.new("Frame")
spacer.Size = UDim2.new(1, 0, 0, 10)
spacer.BackgroundTransparency = 1
spacer.LayoutOrder = 0
spacer.Parent = container

title.LayoutOrder = -1

-- Attendre le RemoteEvent créé par le serveur
local testRemote = remotes:WaitForChild("TestServerData")

-- BOUTON 1: Ajouter $1000 (SERVEUR)
CreateButton("AddCashServer", "+ $1000 Cash\n(SERVER)", Color3.fromRGB(50, 200, 50), function()
    testRemote:FireServer("AddCash", 1000)
    print("[TEST SERVER] Demande +$1000 au serveur")
end).LayoutOrder = 1

-- BOUTON 2: Retirer $500 (SERVEUR)
CreateButton("RemoveCashServer", "- $500 Cash\n(SERVER)", Color3.fromRGB(200, 50, 50), function()
    testRemote:FireServer("RemoveCash", 500)
    print("[TEST SERVER] Demande -$500 au serveur")
end).LayoutOrder = 2

-- BOUTON 3: Ajouter 1 slot (SERVEUR)
CreateButton("AddSlotServer", "+ 1 Slot\n(SERVER)", Color3.fromRGB(100, 150, 200), function()
    testRemote:FireServer("AddSlot", 1)
    print("[TEST SERVER] Demande +1 slot au serveur")
end).LayoutOrder = 3

-- BOUTON 4: Reset Cash à 100 (SERVEUR)
CreateButton("ResetCashServer", "Reset Cash = $100\n(SERVER)", Color3.fromRGB(150, 100, 50), function()
    testRemote:FireServer("SetCash", 100)
    print("[TEST SERVER] Reset cash à $100")
end).LayoutOrder = 4

-- BOUTON 5: Forcer Save NOW
CreateButton("ForceSave", "💾 FORCE SAVE NOW", Color3.fromRGB(200, 100, 200), function()
    testRemote:FireServer("ForceSave")
    print("[TEST SERVER] Force save demandé")
end).LayoutOrder = 5

-- BOUTON 6: Afficher données actuelles
CreateButton("ShowData", "📊 Show Current Data", Color3.fromRGB(100, 100, 200), function()
    testRemote:FireServer("ShowData")
    print("[TEST SERVER] Affichage données demandé")
end).LayoutOrder = 6

-- BOUTON 7: Test complet
CreateButton("FullTest", "🧪 FULL TEST\n(+$5000, +5 slots)", Color3.fromRGB(200, 150, 0), function()
    testRemote:FireServer("FullTest")
    print("[TEST SERVER] Test complet lancé")
end).LayoutOrder = 7

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
infoLabel.LayoutOrder = 8
infoLabel.Parent = container

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoLabel

print("═══════════════════════════════════════════════")
print("   TEST SERVER - Ready! Use buttons on the right")
print("   Quit and rejoin to verify save!")
print("═══════════════════════════════════════════════")

