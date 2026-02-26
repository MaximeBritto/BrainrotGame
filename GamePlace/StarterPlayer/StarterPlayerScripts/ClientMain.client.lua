--[[
    ClientMain.lua (LocalScript)
    Point d'entrée principal du client

    Ce script initialise tous les contrôleurs et connecte les RemoteEvents
]]

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

-- ═══════════════════════════════════════════════════════
-- INITIALISATION DU HUD (programmatique)
-- ═══════════════════════════════════════════════════════

-- Initialiser le HUD principal (crée le ScreenGui GameHUD)
UIController:Init()

-- Phase 6 : CodexController
CodexController:Init()

-- Preview Brainrot 3D
PreviewBrainrotController:Init()

-- ═══════════════════════════════════════════════════════
-- CONNEXION AUX REMOTES (Serveur → Client)
-- ═══════════════════════════════════════════════════════

-- SyncPlayerData
local syncPlayerData = Remotes:WaitForChild("SyncPlayerData")
syncPlayerData.OnClientEvent:Connect(function(data)
    UIController:UpdateAll(data)

    if data.OwnedSlots or data.SlotCash or data.UnlockedFloor then
        EconomyController:UpdateData(data)
    end

    if data.Cash ~= nil then
        local oldCash = UIController:GetCurrentData().Cash
        if oldCash and oldCash ~= data.Cash then
            UIController:UpdateCashAnimated(data.Cash, oldCash)
        end
    end
end)

-- SyncInventory
local syncInventory = Remotes:WaitForChild("SyncInventory")
syncInventory.OnClientEvent:Connect(function(pieces)
    UIController:UpdateInventory(pieces)
    PreviewBrainrotController:UpdatePreview(pieces)
end)

-- Notification
local notification = Remotes:WaitForChild("Notification")
notification.OnClientEvent:Connect(function(data)
    UIController:ShowNotification(data.Type, data.Message, data.Duration)
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

-- SyncDoorState
local syncDoorState = Remotes:WaitForChild("SyncDoorState")
syncDoorState.OnClientEvent:Connect(function(data)
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
        craft:FireServer()
    end)
end

-- ═══════════════════════════════════════════════════════
-- BOUTONS CODEX & SHOP (côté gauche, empilés)
-- ═══════════════════════════════════════════════════════

local hudGui = UIController:GetScreenGui()
if hudGui then
    -- Container pour les boutons latéraux
    local sideButtonsContainer = Instance.new("Frame")
    sideButtonsContainer.Name = "SideButtons"
    sideButtonsContainer.Size = UDim2.new(0, 170, 0, 125)
    sideButtonsContainer.Position = UDim2.new(0, 10, 0.5, -62)
    sideButtonsContainer.BackgroundTransparency = 1
    sideButtonsContainer.BorderSizePixel = 0
    sideButtonsContainer.Parent = hudGui

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.Parent = sideButtonsContainer

    -- ── BOUTON CODEX ──
    local codexButton = Instance.new("TextButton")
    codexButton.Name = "CodexButton"
    codexButton.Size = UDim2.new(1, 0, 0, 55)
    codexButton.LayoutOrder = 1
    codexButton.BackgroundColor3 = Color3.fromRGB(35, 60, 140)
    codexButton.BackgroundTransparency = 0.1
    codexButton.BorderSizePixel = 0
    codexButton.Text = ""
    codexButton.AutoButtonColor = false
    codexButton.Parent = sideButtonsContainer

    local codexCorner = Instance.new("UICorner")
    codexCorner.CornerRadius = UDim.new(0, 14)
    codexCorner.Parent = codexButton

    local codexStroke = Instance.new("UIStroke")
    codexStroke.Color = Color3.fromRGB(55, 90, 180)
    codexStroke.Thickness = 1.5
    codexStroke.Transparency = 0.3
    codexStroke.Parent = codexButton

    -- Icône livre
    local codexIcon = Instance.new("TextLabel")
    codexIcon.Name = "Icon"
    codexIcon.Size = UDim2.new(0, 35, 0, 35)
    codexIcon.Position = UDim2.new(0, 12, 0.5, 0)
    codexIcon.AnchorPoint = Vector2.new(0, 0.5)
    codexIcon.BackgroundTransparency = 1
    codexIcon.Text = "\xF0\x9F\x93\x96" -- 📖
    codexIcon.TextSize = 24
    codexIcon.Font = Enum.Font.GothamBold
    codexIcon.Parent = codexButton

    -- Texte "CODEX"
    local codexText = Instance.new("TextLabel")
    codexText.Name = "Label"
    codexText.Size = UDim2.new(0, 100, 1, 0)
    codexText.Position = UDim2.new(0, 48, 0, 0)
    codexText.BackgroundTransparency = 1
    codexText.Text = "CODEX"
    codexText.TextColor3 = Color3.fromRGB(255, 255, 255)
    codexText.TextSize = 18
    codexText.Font = Enum.Font.GothamBlack
    codexText.TextXAlignment = Enum.TextXAlignment.Left
    codexText.Parent = codexButton

    -- Hover
    codexButton.MouseEnter:Connect(function()
        TweenService:Create(codexButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(50, 80, 170)
        }):Play()
    end)
    codexButton.MouseLeave:Connect(function()
        TweenService:Create(codexButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(35, 60, 140)
        }):Play()
    end)

    codexButton.MouseButton1Click:Connect(function()
        CodexController:Open()
    end)

    -- ── BOUTON SHOP ──
    local shopButton = Instance.new("TextButton")
    shopButton.Name = "ShopButton"
    shopButton.Size = UDim2.new(1, 0, 0, 55)
    shopButton.LayoutOrder = 2
    shopButton.BackgroundColor3 = Color3.fromRGB(25, 120, 25)
    shopButton.BackgroundTransparency = 0.1
    shopButton.BorderSizePixel = 0
    shopButton.Text = ""
    shopButton.AutoButtonColor = false
    shopButton.Parent = sideButtonsContainer

    local shopCorner = Instance.new("UICorner")
    shopCorner.CornerRadius = UDim.new(0, 14)
    shopCorner.Parent = shopButton

    local shopStroke = Instance.new("UIStroke")
    shopStroke.Color = Color3.fromRGB(40, 160, 40)
    shopStroke.Thickness = 1.5
    shopStroke.Transparency = 0.3
    shopStroke.Parent = shopButton

    -- Icône panier
    local shopIcon = Instance.new("TextLabel")
    shopIcon.Name = "Icon"
    shopIcon.Size = UDim2.new(0, 35, 0, 35)
    shopIcon.Position = UDim2.new(0, 12, 0.5, 0)
    shopIcon.AnchorPoint = Vector2.new(0, 0.5)
    shopIcon.BackgroundTransparency = 1
    shopIcon.Text = "\xF0\x9F\x9B\x92" -- 🛒
    shopIcon.TextSize = 24
    shopIcon.Font = Enum.Font.GothamBold
    shopIcon.Parent = shopButton

    -- Texte "SHOP"
    local shopText = Instance.new("TextLabel")
    shopText.Name = "Label"
    shopText.Size = UDim2.new(0, 100, 1, 0)
    shopText.Position = UDim2.new(0, 48, 0, 0)
    shopText.BackgroundTransparency = 1
    shopText.Text = "SHOP"
    shopText.TextColor3 = Color3.fromRGB(255, 255, 255)
    shopText.TextSize = 18
    shopText.Font = Enum.Font.GothamBlack
    shopText.TextXAlignment = Enum.TextXAlignment.Left
    shopText.Parent = shopButton

    -- Hover
    shopButton.MouseEnter:Connect(function()
        TweenService:Create(shopButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(35, 150, 35)
        }):Play()
    end)
    shopButton.MouseLeave:Connect(function()
        TweenService:Create(shopButton, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(25, 120, 25)
        }):Play()
    end)

    shopButton.MouseButton1Click:Connect(function()
        ShopController:Toggle()
    end)
end

-- ═══════════════════════════════════════════════════════
-- BOOST MULTIPLIER TIMER UI (X2)
-- ═══════════════════════════════════════════════════════

local boostTimerFrame = nil
local boostTimerLabel = nil
local boostRemainingSeconds = 0
local boostTimerActive = false

if hudGui then
    -- Conteneur du timer boost (au-dessus du cash display)
    boostTimerFrame = Instance.new("Frame")
    boostTimerFrame.Name = "BoostTimerFrame"
    boostTimerFrame.Size = UDim2.new(0, 170, 0, 40)
    boostTimerFrame.Position = UDim2.new(0, 15, 1, -78)
    boostTimerFrame.AnchorPoint = Vector2.new(0, 1)
    boostTimerFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    boostTimerFrame.BackgroundTransparency = 0.2
    boostTimerFrame.BorderSizePixel = 0
    boostTimerFrame.Visible = false
    boostTimerFrame.Parent = hudGui

    local boostCorner = Instance.new("UICorner")
    boostCorner.CornerRadius = UDim.new(0, 10)
    boostCorner.Parent = boostTimerFrame

    local boostStroke = Instance.new("UIStroke")
    boostStroke.Color = Color3.fromRGB(255, 215, 0)
    boostStroke.Thickness = 2
    boostStroke.Parent = boostTimerFrame

    -- Label "X2" à gauche
    local boostIcon = Instance.new("TextLabel")
    boostIcon.Name = "BoostIcon"
    boostIcon.Size = UDim2.new(0, 55, 1, 0)
    boostIcon.Position = UDim2.new(0, 8, 0, 0)
    boostIcon.BackgroundTransparency = 1
    boostIcon.Text = "$ X2"
    boostIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
    boostIcon.TextSize = 22
    boostIcon.Font = Enum.Font.GothamBlack
    boostIcon.TextXAlignment = Enum.TextXAlignment.Left
    boostIcon.Parent = boostTimerFrame

    -- Timer à droite
    boostTimerLabel = Instance.new("TextLabel")
    boostTimerLabel.Name = "BoostTimer"
    boostTimerLabel.Size = UDim2.new(0, 90, 1, 0)
    boostTimerLabel.Position = UDim2.new(1, -95, 0, 0)
    boostTimerLabel.BackgroundTransparency = 1
    boostTimerLabel.Text = "00:00"
    boostTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    boostTimerLabel.TextSize = 20
    boostTimerLabel.Font = Enum.Font.GothamBold
    boostTimerLabel.TextXAlignment = Enum.TextXAlignment.Right
    boostTimerLabel.Parent = boostTimerFrame
end

local function formatBoostTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

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

local function startBoostCountdown(seconds)
    boostRemainingSeconds = seconds
    boostTimerActive = true
    updateBoostTimerUI()

    if boostTimerFrame then
        boostTimerFrame.Size = UDim2.new(0, 0, 0, 0)
        boostTimerFrame.Visible = true
        TweenService:Create(boostTimerFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 170, 0, 40),
        }):Play()
    end
end

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

-- Boucle de countdown
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

-- SyncMultiplierBoost
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
-- FONCTIONS PUBLIQUES
-- ═══════════════════════════════════════════════════════

local ClientMain = {}

function ClientMain:RequestPickupPiece(pieceId)
    pickupPiece:FireServer(pieceId)
end

function ClientMain:RequestCraft()
    craft:FireServer()
end

function ClientMain:RequestBuySlot()
    buySlot:FireServer()
end

function ClientMain:RequestActivateDoor()
    activateDoor:FireServer()
end

function ClientMain:RequestDropPieces()
    dropPieces:FireServer()
end

function ClientMain:RequestCollectSlotCash(slotIndex)
    collectSlotCash:FireServer(slotIndex)
end

function ClientMain:GetFullPlayerData()
    local getFullPlayerData = Remotes:WaitForChild("GetFullPlayerData")
    return getFullPlayerData:InvokeServer()
end

-- ═══════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════

-- Demander les données initiales au serveur
task.spawn(function()
    task.wait(1)

    local fullData = ClientMain:GetFullPlayerData()

    if fullData then
        UIController:UpdateAll(fullData)
        if fullData.PiecesInHand then
            PreviewBrainrotController:UpdatePreview(fullData.PiecesInHand)
        end
        if fullData.CodexUnlocked then
            CodexController:UpdateCodex(fullData.CodexUnlocked)
        end
        if fullData.MultiplierBoostActive and fullData.MultiplierBoostRemaining and fullData.MultiplierBoostRemaining > 0 then
            startBoostCountdown(fullData.MultiplierBoostRemaining)
        end
    else
        warn("[ClientMain] No data received from server")
    end
end)

-- ═══════════════════════════════════════════════════════
-- TERMINÉ - Initialiser les autres contrôleurs
-- ═══════════════════════════════════════════════════════

DoorController:Init()
EconomyController:Init(UIController)
ArenaController:Init()
ShopController:Init()

-- ═══════════════════════════════════════════════════════
-- PROXIMITÉ SHOP ET COLLECTPADS
-- ═══════════════════════════════════════════════════════

local ProximityPromptService = game:GetService("ProximityPromptService")

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

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
    if playerWhoTriggered ~= player then return end

    if not isOnPlayerBase(prompt) then return end

    local parent = prompt.Parent

    if parent and parent.Name == "Sign" then
        local grandParent = parent.Parent
        if grandParent and grandParent.Name == "SlotShop" then
            EconomyController:OpenShop()
        end
    end

    if parent and parent.Name == "CollectPad" then
        local slot = parent.Parent
        if slot then
            local slotIndex = slot:GetAttribute("SlotIndex")
            if not slotIndex and slot.Name:match("^Slot_(%d+)$") then
                slotIndex = tonumber(slot.Name:match("^Slot_(%d+)$"))
            end
            if slotIndex then
                EconomyController:RequestCollectSlot(slotIndex)
            end
        end
    end
end)

return ClientMain
