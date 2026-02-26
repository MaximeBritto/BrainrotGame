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
local TweenService = game:GetService("TweenService")

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
local PreviewBrainrotController = require(script.Parent:WaitForChild("PreviewBrainrotController.module"))
local ShopController = require(script.Parent:WaitForChild("ShopController.module"))

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

-- Preview Brainrot 3D (modèle qui suit le joueur)
PreviewBrainrotController:Init()

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
    -- Mettre à jour le preview 3D du brainrot qui suit le joueur
    PreviewBrainrotController:UpdatePreview(pieces)
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

-- SyncCodex: géré directement par CodexController:Init() (listener interne)

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
-- BOUTON SHOP (Phase 9) – Bouton pour ouvrir le Shop Robux
-- ═══════════════════════════════════════════════════════

if mainHUD then
    -- Créer le bouton SHOP carré à gauche de l'écran
    local shopButton = Instance.new("TextButton")
    shopButton.Name = "ShopButton"
    shopButton.Size = UDim2.new(0, 83, 0, 84)
    shopButton.Position = UDim2.new(0.008, 0, 0.52, 0)
    shopButton.AnchorPoint = Vector2.new(0, 0)
    shopButton.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
    shopButton.BorderSizePixel = 0
    shopButton.Text = "SHOP"
    shopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    shopButton.TextSize = 14
    shopButton.Font = Enum.Font.GothamBold
    shopButton.Parent = mainHUD

    local shopBtnCorner = Instance.new("UICorner")
    shopBtnCorner.CornerRadius = UDim.new(0, 8)
    shopBtnCorner.Parent = shopButton

    shopButton.MouseButton1Click:Connect(function()
        ShopController:Toggle()
    end)

    -- Hover effect
    shopButton.MouseEnter:Connect(function()
        shopButton.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    end)
    shopButton.MouseLeave:Connect(function()
        shopButton.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
    end)

    -- print("[ClientMain] Shop button créé")
end

-- ═══════════════════════════════════════════════════════
-- BOOST MULTIPLIER TIMER UI (X2)
-- ═══════════════════════════════════════════════════════

local boostTimerFrame = nil
local boostTimerLabel = nil
local boostRemainingSeconds = 0
local boostTimerActive = false

if mainHUD then
    -- Conteneur du timer boost
    boostTimerFrame = Instance.new("Frame")
    boostTimerFrame.Name = "BoostTimerFrame"
    boostTimerFrame.Size = UDim2.new(0, 160, 0, 40)
    boostTimerFrame.Position = UDim2.new(0, 10, 1, -100)
    boostTimerFrame.AnchorPoint = Vector2.new(0, 1)
    boostTimerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    boostTimerFrame.BackgroundTransparency = 0.3
    boostTimerFrame.BorderSizePixel = 0
    boostTimerFrame.Visible = false
    boostTimerFrame.Parent = mainHUD

    local boostCorner = Instance.new("UICorner")
    boostCorner.CornerRadius = UDim.new(0, 8)
    boostCorner.Parent = boostTimerFrame

    local boostStroke = Instance.new("UIStroke")
    boostStroke.Color = Color3.fromRGB(255, 215, 0)
    boostStroke.Thickness = 2
    boostStroke.Parent = boostTimerFrame

    -- Label "X2" à gauche
    local boostIcon = Instance.new("TextLabel")
    boostIcon.Name = "BoostIcon"
    boostIcon.Size = UDim2.new(0, 50, 1, 0)
    boostIcon.Position = UDim2.new(0, 5, 0, 0)
    boostIcon.BackgroundTransparency = 1
    boostIcon.Text = "X2"
    boostIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
    boostIcon.TextSize = 24
    boostIcon.Font = Enum.Font.GothamBlack
    boostIcon.TextXAlignment = Enum.TextXAlignment.Left
    boostIcon.Parent = boostTimerFrame

    -- Timer à droite
    boostTimerLabel = Instance.new("TextLabel")
    boostTimerLabel.Name = "BoostTimer"
    boostTimerLabel.Size = UDim2.new(0, 95, 1, 0)
    boostTimerLabel.Position = UDim2.new(1, -100, 0, 0)
    boostTimerLabel.BackgroundTransparency = 1
    boostTimerLabel.Text = "00:00"
    boostTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    boostTimerLabel.TextSize = 22
    boostTimerLabel.Font = Enum.Font.GothamBold
    boostTimerLabel.TextXAlignment = Enum.TextXAlignment.Right
    boostTimerLabel.Parent = boostTimerFrame
end

-- Formate les secondes en MM:SS
local function formatBoostTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

-- Met à jour l'affichage du timer boost
local function updateBoostTimerUI()
    if not boostTimerFrame or not boostTimerLabel then return end

    if boostTimerActive and boostRemainingSeconds > 0 then
        boostTimerFrame.Visible = true
        boostTimerLabel.Text = formatBoostTime(boostRemainingSeconds)
    else
        boostTimerFrame.Visible = false
        boostTimerActive = false
    end
end

-- Démarre le countdown local du boost
local function startBoostCountdown(seconds)
    boostRemainingSeconds = seconds
    boostTimerActive = true
    updateBoostTimerUI()

    -- Animation d'apparition
    if boostTimerFrame then
        boostTimerFrame.Size = UDim2.new(0, 0, 0, 0)
        boostTimerFrame.Visible = true
        TweenService:Create(boostTimerFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 160, 0, 40),
        }):Play()
    end
end

-- Arrête le boost timer
local function stopBoostTimer()
    boostTimerActive = false
    boostRemainingSeconds = 0
    if boostTimerFrame then
        local tweenOut = TweenService:Create(boostTimerFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
        })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            boostTimerFrame.Visible = false
        end)
    end
end

-- Boucle de countdown (chaque seconde)
task.spawn(function()
    while true do
        task.wait(1)
        if boostTimerActive and boostRemainingSeconds > 0 then
            boostRemainingSeconds = boostRemainingSeconds - 1
            updateBoostTimerUI()
            if boostRemainingSeconds <= 0 then
                stopBoostTimer()
            end
        end
    end
end)

-- SyncMultiplierBoost: Reçoit les mises à jour du boost multiplicateur
local syncMultiplierBoost = Remotes:FindFirstChild("SyncMultiplierBoost")
if syncMultiplierBoost then
    syncMultiplierBoost.OnClientEvent:Connect(function(data)
        if data.Active and data.RemainingSeconds and data.RemainingSeconds > 0 then
            startBoostCountdown(data.RemainingSeconds)
        else
            stopBoostTimer()
        end
    end)
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
        -- Mettre à jour le preview avec les pièces initiales (si le joueur en avait)
        if fullData.PiecesInHand then
            PreviewBrainrotController:UpdatePreview(fullData.PiecesInHand)
        end
        -- Initialiser le Codex avec les données sauvegardées
        if fullData.CodexUnlocked then
            CodexController:UpdateCodex(fullData.CodexUnlocked)
        end
        -- Initialiser le timer boost si un multiplicateur est actif
        if fullData.MultiplierBoostActive and fullData.MultiplierBoostRemaining and fullData.MultiplierBoostRemaining > 0 then
            startBoostCountdown(fullData.MultiplierBoostRemaining)
        end
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

-- Initialiser ShopController (Phase 9)
ShopController:Init()

-- ═══════════════════════════════════════════════════════
-- PROXIMITÉ SHOP ET COLLECTPADS (Phase 3)
-- ═══════════════════════════════════════════════════════

local ProximityPromptService = game:GetService("ProximityPromptService")

-- Vérifie si un objet appartient à la base du joueur local
local function isOnPlayerBase(instance)
    local current = instance
    while current do
        if current:GetAttribute("OwnerUserId") == player.UserId then
            return true
        end
        current = current.Parent
    end
    return false
end

-- Écouter tous les ProximityPrompts
ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
    if playerWhoTriggered ~= player then return end

    -- Ignorer si le prompt n'est pas sur la base du joueur
    if not isOnPlayerBase(prompt) then return end

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
