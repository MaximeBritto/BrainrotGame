--[[
    TEST_UI.client.lua
    Script de test pour l'interface utilisateur
    
    INSTRUCTIONS:
    1. Copier ce script dans StarterPlayerScripts
    2. Lancer le jeu
    3. Utiliser les boutons pour tester l'UI
    4. SUPPRIMER ce script après les tests
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Attendre UIController avec un délai
task.wait(1)
local UIController = require(script.Parent:WaitForChild("UIController.module"))

print("═══════════════════════════════════════════════")
print("   TEST UI - Boutons de test créés")
print("═══════════════════════════════════════════════")

-- Créer un ScreenGui pour les boutons de test
local testGui = Instance.new("ScreenGui")
testGui.Name = "TestUI"
testGui.ResetOnSpawn = false
testGui.Parent = playerGui

-- Container pour les boutons
local container = Instance.new("Frame")
container.Name = "TestButtons"
container.Size = UDim2.new(0, 250, 0, 400)
container.Position = UDim2.new(0, 10, 0.5, -200)
container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
container.BackgroundTransparency = 0.2
container.Parent = testGui

-- UICorner
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = container

-- Titre
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "UI TEST BUTTONS"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = container

-- UIListLayout pour les boutons
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = container

-- Fonction pour créer un bouton
local function CreateButton(name, text, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0.9, 0, 0, 50)
    button.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
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

-- Variables de test
local testCash = 100
local testSlotCash = 0
local testPieces = {}

-- BOUTON 1: Ajouter $500
CreateButton("AddCash", "+ $500 Cash", function()
    testCash = testCash + 500
    UIController:UpdateCash(testCash)
    UIController:ShowNotification("Success", "Added $500!", 2)
    print("[TEST] Cash: " .. testCash)
end).LayoutOrder = 1

-- BOUTON 2: Ajouter $100 SlotCash
CreateButton("AddSlotCash", "+ $100 Slot Cash", function()
    testSlotCash = testSlotCash + 100
    UIController:UpdateSlotCash({[1] = testSlotCash})
    UIController:ShowNotification("Info", "Slot cash increased!", 2)
    print("[TEST] SlotCash: " .. testSlotCash)
end).LayoutOrder = 2

-- BOUTON 3: Ajouter une pièce
CreateButton("AddPiece", "+ Add Piece", function()
    if #testPieces >= 3 then
        UIController:ShowNotification("Warning", "Inventory full!", 2)
        return
    end
    
    local pieceTypes = {"Head", "Body", "Legs"}
    local setNames = {"Skibidi", "Rizz", "Fanum"}
    
    local randomType = pieceTypes[math.random(1, #pieceTypes)]
    local randomSet = setNames[math.random(1, #setNames)]
    
    table.insert(testPieces, {
        SetName = randomSet,
        PieceType = randomType,
        DisplayName = randomSet,
        Price = 50
    })
    
    UIController:UpdateInventory(testPieces)
    UIController:ShowNotification("Success", "Picked up " .. randomSet .. " " .. randomType .. "!", 2)
    print("[TEST] Pieces: " .. #testPieces)
end).LayoutOrder = 3

-- BOUTON 4: Vider l'inventaire
CreateButton("ClearInventory", "Clear Inventory", function()
    testPieces = {}
    UIController:UpdateInventory(testPieces)
    UIController:ShowNotification("Info", "Inventory cleared", 2)
    print("[TEST] Inventory cleared")
end).LayoutOrder = 4

-- BOUTON 5: Test notification Error
CreateButton("TestError", "Test Error Notif", function()
    UIController:ShowNotification("Error", "This is an error message!", 3)
end).LayoutOrder = 5

-- BOUTON 6: Test notification Warning
CreateButton("TestWarning", "Test Warning Notif", function()
    UIController:ShowNotification("Warning", "This is a warning!", 3)
end).LayoutOrder = 6

-- BOUTON 7: Reset tout
CreateButton("ResetAll", "RESET ALL", function()
    testCash = 100
    testSlotCash = 0
    testPieces = {}
    
    UIController:UpdateCash(testCash)
    UIController:UpdateSlotCash({})
    UIController:UpdateInventory(testPieces)
    UIController:ShowNotification("Info", "Everything reset!", 2)
    print("[TEST] Reset all")
end).LayoutOrder = 7

print("═══════════════════════════════════════════════")
print("   TEST UI - Ready! Use buttons on the left")
print("═══════════════════════════════════════════════")
