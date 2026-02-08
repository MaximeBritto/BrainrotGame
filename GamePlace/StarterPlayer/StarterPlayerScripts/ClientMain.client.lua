--[[
    ClientMain.lua (LocalScript)
    Point d'entrée principal du client
    
    Ce script initialise tous les contrôleurs et connecte les RemoteEvents
]]

-- print("═══════════════════════════════════════════════")
-- print("   BRAINROT GAME - Client starting")
-- print("═══════════════════════════════════════════════")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])

-- Contrôleurs (charger depuis le même dossier)
local UIController = require(script.Parent:WaitForChild("UIController.module"))
local DoorController = require(script.Parent:WaitForChild("DoorController.module"))
local EconomyController = require(script.Parent:WaitForChild("EconomyController.module"))
local ArenaController = require(script.Parent:WaitForChild("ArenaController.module"))
local CodexController = require(script.Parent:WaitForChild("CodexController.module"))

-- Son (optionnel : si Assets/Sounds n'existe pas, pas d'erreur)
local SoundHelper = nil
do
    local ok, mod = pcall(function()
        return require(Shared:WaitForChild("SoundHelper.module"))
    end)
    if ok and mod then SoundHelper = mod end
end

-- Attendre les Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Phase 6 : CodexController (CodexUI, SyncCodex, bouton Fermer)
CodexController:Init()

-- ═══════════════════════════════════════════════════════
-- CONNEXION AUX REMOTES (Serveur → Client)
-- ═══════════════════════════════════════════════════════

-- SyncPlayerData: Reçoit les mises à jour des données joueur
local syncPlayerData = Remotes:WaitForChild("SyncPlayerData")
syncPlayerData.OnClientEvent:Connect(function(data)
    -- -- print("[ClientMain] SyncPlayerData received")
    UIController:UpdateAll(data)
    
    -- Mettre à jour EconomyController avec les données pertinentes
    if data.OwnedSlots or data.SlotCash or data.UnlockedFloor then
        EconomyController:UpdateData(data)
    end
    
    -- Animer les changements d'argent
    if data.Cash ~= nil then
        local oldCash = UIController:GetCurrentData().Cash
        if oldCash and oldCash ~= data.Cash then
            UIController:UpdateCashAnimated(data.Cash, oldCash)
        end
    end
end)

-- SyncInventory: Reçoit les mises à jour de l'inventaire (pièces en main)
local syncInventory = Remotes:WaitForChild("SyncInventory")
syncInventory.OnClientEvent:Connect(function(pieces)
    -- print("[ClientMain] SyncInventory received (" .. #pieces .. " pieces)")
    UIController:UpdateInventory(pieces)
end)

-- Notification: Reçoit les notifications à afficher
local notification = Remotes:WaitForChild("Notification")
notification.OnClientEvent:Connect(function(data)
    -- print("[ClientMain] Notification received: " .. data.Type .. " - " .. data.Message)
    UIController:ShowNotification(data.Type, data.Message, data.Duration)
    -- Sons économiques (Phase 3)
    if SoundHelper then
        local msg = data.Message or ""
        if data.Type == "Success" then
            if string.find(msg, "collected") then
                SoundHelper.Play("CashCollect")
            elseif string.find(msg, "purchased") or string.find(msg, "Slot") then
                SoundHelper.Play("SlotBuy")
            end
        elseif data.Type == "Error" and string.find(msg, "money") then
            SoundHelper.Play("NotEnoughMoney")
        end
    end
end)

-- SyncCodex: Reçoit les mises à jour du Codex (Phase 6)
local syncCodex = Remotes:WaitForChild("SyncCodex")
syncCodex.OnClientEvent:Connect(function(data)
    -- print("[ClientMain] SyncCodex received")
    CodexController:UpdateCodex(data)
end)

-- SyncDoorState: Reçoit les mises à jour de l'état de la porte (Phase 2)
local syncDoorState = Remotes:WaitForChild("SyncDoorState")
syncDoorState.OnClientEvent:Connect(function(data)
    -- print("[ClientMain] SyncDoorState received: " .. data.State)
    DoorController:UpdateDoorState(data.State, data.ReopenTime)
end)

-- ═══════════════════════════════════════════════════════
-- REMOTES (Client → Serveur)
-- ═══════════════════════════════════════════════════════

local pickupPiece = Remotes:WaitForChild("PickupPiece")
local craft = Remotes:WaitForChild("Craft")
local buySlot = Remotes:WaitForChild("BuySlot")
local activateDoor = Remotes:WaitForChild("ActivateDoor")
local dropPieces = Remotes:WaitForChild("DropPieces")
local collectSlotCash = Remotes:WaitForChild("CollectSlotCash")

-- ═══════════════════════════════════════════════════════
-- BOUTON CRAFT
-- ═══════════════════════════════════════════════════════

local craftButton = UIController:GetCraftButton()
if craftButton then
    craftButton.MouseButton1Click:Connect(function()
        -- print("[ClientMain] Craft button clicked")
        craft:FireServer()
    end)
end

-- ═══════════════════════════════════════════════════════
-- BOUTON CODEX (Phase 6) – CodexButton est enfant direct de MainHUD
-- ═══════════════════════════════════════════════════════

local playerGui = player:WaitForChild("PlayerGui")
local mainHUD = playerGui:WaitForChild("MainHUD", 10)
if mainHUD then
    local codexButton = mainHUD:FindFirstChild("CodexButton") or mainHUD:FindFirstChild("Codex")
    if codexButton and codexButton:IsA("TextButton") then
        codexButton.MouseButton1Click:Connect(function()
            CodexController:Open()
        end)
        -- print("[ClientMain] Codex button connected")
    end
end

-- ═══════════════════════════════════════════════════════
-- FONCTIONS PUBLIQUES (pour les autres contrôleurs)
-- ═══════════════════════════════════════════════════════

local ClientMain = {}

--[[
    Envoie une requête de pickup au serveur
    @param pieceId: string - Nom unique de la pièce
]]
function ClientMain:RequestPickupPiece(pieceId)
    -- print("[ClientMain] Request pickup: " .. pieceId)
    pickupPiece:FireServer(pieceId)
end

--[[
    Envoie une requête de craft au serveur
]]
function ClientMain:RequestCraft()
    -- print("[ClientMain] Request craft")
    craft:FireServer()
end

--[[
    Envoie une requête d'achat de slot au serveur
]]
function ClientMain:RequestBuySlot()
    -- print("[ClientMain] Request buy slot")
    buySlot:FireServer()
end

--[[
    Envoie une requête d'activation de porte au serveur
]]
function ClientMain:RequestActivateDoor()
    -- print("[ClientMain] Request activate door")
    activateDoor:FireServer()
end

--[[
    Envoie une requête pour lâcher les pièces
]]
function ClientMain:RequestDropPieces()
    -- print("[ClientMain] Request drop pieces")
    dropPieces:FireServer()
end

--[[
    Envoie une requête de collecte d'argent de slot
    @param slotIndex: number
]]
function ClientMain:RequestCollectSlotCash(slotIndex)
    -- print("[ClientMain] Request collect slot " .. slotIndex)
    collectSlotCash:FireServer(slotIndex)
end

--[[
    Demande les données complètes du joueur au serveur
    @return table - PlayerData complet
]]
function ClientMain:GetFullPlayerData()
    local getFullPlayerData = Remotes:WaitForChild("GetFullPlayerData")
    return getFullPlayerData:InvokeServer()
end

-- ═══════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════

-- Demander les données initiales au serveur
task.spawn(function()
    -- Attendre un peu que le serveur soit prêt
    task.wait(1)
    
    -- print("[ClientMain] Requesting initial data...")
    local fullData = ClientMain:GetFullPlayerData()
    
    if fullData then
        -- print("[ClientMain] Data received, updating UI")
        UIController:UpdateAll(fullData)
    else
        warn("[ClientMain] No data received from server")
    end
end)

-- ═══════════════════════════════════════════════════════
-- TERMINÉ
-- ═══════════════════════════════════════════════════════

-- Initialiser DoorController
DoorController:Init()

-- Initialiser EconomyController
EconomyController:Init(UIController)

-- Initialiser ArenaController (Phase 4)
ArenaController:Init()

-- ═══════════════════════════════════════════════════════
-- PROXIMITÉ SHOP ET COLLECTPADS (Phase 3)
-- ═══════════════════════════════════════════════════════

local ProximityPromptService = game:GetService("ProximityPromptService")

-- Écouter tous les ProximityPrompts
ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
    if playerWhoTriggered ~= player then return end
    
    local parent = prompt.Parent
    
    -- Vérifier si c'est un SlotShop
    if parent and parent.Name == "Sign" then
        local grandParent = parent.Parent
        if grandParent and grandParent.Name == "SlotShop" then
            -- print("[ClientMain] SlotShop ProximityPrompt déclenché")
            EconomyController:OpenShop()
        end
    end
    
    -- Vérifier si c'est un CollectPad (pour collecter l'argent d'un slot)
    if parent and parent.Name == "CollectPad" then
        local slot = parent.Parent
        if slot then
            local slotIndex = slot:GetAttribute("SlotIndex")
            if not slotIndex and slot.Name:match("^Slot_(%d+)$") then
                slotIndex = tonumber(slot.Name:match("^Slot_(%d+)$"))
            end
            if slotIndex then
                -- print("[ClientMain] CollectPad ProximityPrompt déclenché pour slot " .. slotIndex)
                EconomyController:RequestCollectSlot(slotIndex)
            end
        end
    end
end)

-- print("═══════════════════════════════════════════════")
-- print("   BRAINROT GAME - Client ready!")
-- print("═══════════════════════════════════════════════")

-- Exporter le module (optionnel, pour les autres scripts qui auraient besoin)
return ClientMain
