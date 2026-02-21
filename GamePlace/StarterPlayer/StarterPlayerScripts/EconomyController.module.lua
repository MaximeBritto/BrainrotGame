--[[
    EconomyController.lua (ModuleScript)
    Gère les interactions économiques côté client
    
    Responsabilités:
    - Gérer l'UI du ShopUI
    - Gérer les interactions ProximityPrompt du SlotShop
    - Mettre à jour les affichages des CollectPads
    - Mettre à jour le Display du SlotShop dynamiquement
    - Animations économiques
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")
local Data = ReplicatedStorage:WaitForChild("Data")

local Constants = require(Shared:WaitForChild("Constants.module"))
local GameConfig = require(Config:WaitForChild("GameConfig.module"))
local SlotPrices = require(Data:WaitForChild("SlotPrices.module"))

-- Son (optionnel)
local SoundHelper = nil
do
    local ok, mod = pcall(function()
        return require(Shared:WaitForChild("SoundHelper.module"))
    end)
    if ok and mod then SoundHelper = mod end
end

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local buySlot = Remotes:WaitForChild("BuySlot")
local collectSlotCash = Remotes:WaitForChild("CollectSlotCash")
local getFullPlayerData = Remotes:WaitForChild("GetFullPlayerData")

-- UI Elements (seront initialisés si ShopUI existe)
local shopUI = nil
local shopBackground = nil
local shopTitle = nil
local shopCurrentSlots = nil
local shopPriceLabel = nil
local shopBuyButton = nil
local shopCloseButton = nil

-- État local (défaut = Floor 0 débloqué = 10 slots)
local currentOwnedSlots = GameConfig.Base.StartingSlots
local currentSlotCash = {}
local isShopOpen = false
local playerBase = nil

local EconomyController = {}

--[[
    Initialise le contrôleur
    @param uiController: module - Référence à UIController
]]
function EconomyController:Init(uiController)
    self._uiController = uiController
    
    -- Essayer de charger le ShopUI (peut ne pas exister encore)
    pcall(function()
        shopUI = playerGui:WaitForChild("ShopUI", 1)
        if shopUI then
            shopBackground = shopUI:WaitForChild("Background")
            shopTitle = shopBackground:WaitForChild("Title")
            shopCurrentSlots = shopBackground:WaitForChild("CurrentSlots")
            shopPriceLabel = shopBackground:WaitForChild("PriceDisplay"):WaitForChild("PriceLabel")
            shopBuyButton = shopBackground:WaitForChild("BuyButton")
            shopCloseButton = shopBackground:WaitForChild("CloseButton")
            
            -- Connecter les boutons du shop
            shopBuyButton.MouseButton1Click:Connect(function()
                self:OnBuyButtonClicked()
            end)
            
            shopCloseButton.MouseButton1Click:Connect(function()
                self:CloseShop()
            end)
            
            -- Fermer le shop au départ
            shopUI.Enabled = false
        end
    end)
    
    -- Trouver la base du joueur
    self:_FindPlayerBase()
    
    -- print("[EconomyController] Initialisé!")
end

--[[
    Trouve la base du joueur dans Workspace
]]
function EconomyController:_FindPlayerBase()
    task.spawn(function()
        local basesFolder = Workspace:WaitForChild("Bases", 5)
        if not basesFolder then return end
        
        -- Attendre que la base soit assignée
        while not playerBase do
            for _, base in ipairs(basesFolder:GetChildren()) do
                if base:GetAttribute("OwnerUserId") == player.UserId then
                    playerBase = base
                    -- print("[EconomyController] Base trouvée: " .. base.Name)
                    break
                end
            end
            task.wait(0.5)
        end
        
        -- Mettre à jour le Display du SlotShop et les CollectPads (au cas où SlotCash a été reçu avant que la base soit trouvée)
        self:UpdateSlotShopDisplay()
        self:UpdateCollectPads(currentSlotCash)
    end)
end

-- ═══════════════════════════════════════════════════════
-- SHOP UI
-- ═══════════════════════════════════════════════════════

--[[
    Ouvre le menu du shop
]]
function EconomyController:OpenShop()
    if not shopUI then
        warn("[EconomyController] ShopUI non trouvé!")
        return
    end
    
    if isShopOpen then return end
    
    isShopOpen = true
    self:UpdateShopDisplay()
    
    -- Animation d'ouverture
    shopUI.Enabled = true
    shopBackground.Size = UDim2.new(0, 0, 0, 0)
    shopBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    local tweenOpen = TweenService:Create(shopBackground, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 350, 0, 250),
        Position = UDim2.new(0.5, -175, 0.5, -125),
    })
    tweenOpen:Play()
    
    -- print("[EconomyController] Shop ouvert")
end

--[[
    Ferme le menu du shop
]]
function EconomyController:CloseShop()
    if not shopUI or not isShopOpen then return end
    
    -- Animation de fermeture
    local tweenClose = TweenService:Create(shopBackground, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    })
    tweenClose:Play()
    
    tweenClose.Completed:Connect(function()
        shopUI.Enabled = false
        isShopOpen = false
    end)
    
    -- print("[EconomyController] Shop fermé")
end

--[[
    Met à jour l'affichage du shop
]]
function EconomyController:UpdateShopDisplay()
    if not shopUI then return end
    
    -- Mettre à jour les slots
    shopCurrentSlots.Text = "Slots: " .. currentOwnedSlots .. "/" .. GameConfig.Base.MaxSlots
    
    -- Mettre à jour le prix
    local nextSlot = currentOwnedSlots + 1
    if nextSlot > GameConfig.Base.MaxSlots then
        shopPriceLabel.Text = "MAX"
        shopBuyButton.Text = "COMPLET"
        shopBuyButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    else
        local price = SlotPrices[nextSlot] or 0
        shopPriceLabel.Text = "$" .. self:FormatNumber(price)
        shopBuyButton.Text = "ACHETER"
        shopBuyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    end
end

--[[
    Appelé quand le bouton Acheter est cliqué
]]
function EconomyController:OnBuyButtonClicked()
    -- print("[EconomyController] Bouton Acheter cliqué")
    
    -- Vérifier si on peut acheter (localement)
    local nextSlot = currentOwnedSlots + 1
    if nextSlot > GameConfig.Base.MaxSlots then
        return
    end
    
    -- Envoyer la requête au serveur
    buySlot:FireServer()
    
    -- Fermer le shop après l'achat
    task.wait(0.5)
    self:CloseShop()
end

-- ═══════════════════════════════════════════════════════
-- SLOTSHOP DISPLAY (mise à jour dynamique)
-- ═══════════════════════════════════════════════════════

--[[
    Met à jour le Display du SlotShop dans la base avec le prix actuel
]]
function EconomyController:UpdateSlotShopDisplay()
    if not playerBase then return end
    
    local slotShop = playerBase:FindFirstChild("SlotShop")
    if not slotShop then return end
    
    local display = slotShop:FindFirstChild("Display")
    if not display then return end
    
    local surfaceGui = display:FindFirstChild("SurfaceGui")
    if not surfaceGui then return end
    
    local priceLabel = surfaceGui:FindFirstChild("PriceLabel")
    if not priceLabel then return end
    
    -- Calculer le prix du prochain slot
    local nextSlot = currentOwnedSlots + 1
    if nextSlot > GameConfig.Base.MaxSlots then
        priceLabel.Text = "MAX"
        priceLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    else
        local price = SlotPrices[nextSlot] or 0
        priceLabel.Text = "$" .. self:FormatNumber(price)
        priceLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    end
    
    -- Mettre à jour aussi le ProximityPrompt
    local sign = slotShop:FindFirstChild("Sign")
    if sign then
        local prompt = sign:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            if nextSlot > GameConfig.Base.MaxSlots then
                prompt.ObjectText = "Max reached"
            else
                prompt.ObjectText = "Slot " .. nextSlot .. " - $" .. (SlotPrices[nextSlot] or 0)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════
-- COLLECTPADS
-- ═══════════════════════════════════════════════════════

--[[
    Met à jour l'affichage des CollectPads dans la base.
    Masque le SurfaceGui (cash display) des slots des étages non débloqués
    pour éviter qu'ils flottent dans le vide.
    @param slotCash: table - {[slotIndex] = amount}
]]
function EconomyController:_GetOrCreateBillboard(collectPad)
    local billboard = collectPad:FindFirstChild("CashBillboard")
    if billboard then return billboard end

    -- Créer un BillboardGui flottant au-dessus du pad
    billboard = Instance.new("BillboardGui")
    billboard.Name = "CashBillboard"
    billboard.Adornee = collectPad
    billboard.Size = UDim2.new(4, 0, 1.5, 0)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 50
    billboard.Parent = collectPad

    -- Désactiver l'ancien SurfaceGui s'il existe
    local oldGui = collectPad:FindFirstChild("SurfaceGui")
    if oldGui then
        oldGui.Enabled = false
    end

    -- TextLabel pour le montant
    local cashLabel = Instance.new("TextLabel")
    cashLabel.Name = "CashLabel"
    cashLabel.Size = UDim2.new(1, 0, 1, 0)
    cashLabel.BackgroundTransparency = 1
    cashLabel.Font = Enum.Font.GothamBold
    cashLabel.TextScaled = true
    cashLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    cashLabel.TextStrokeTransparency = 0.3
    cashLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    cashLabel.Text = "$0"
    cashLabel.Parent = billboard

    return billboard
end

function EconomyController:UpdateCollectPads(slotCash)
    currentSlotCash = slotCash or {}

    if not playerBase then return end

    local slotsFolder = playerBase:FindFirstChild("Slots")
    if not slotsFolder then return end

    for _, slot in ipairs(slotsFolder:GetChildren()) do
        if slot:IsA("Model") then
            -- SlotIndex : attribut ou déduit du nom (Slot_1 -> 1)
            local slotIndex = slot:GetAttribute("SlotIndex")
            if not slotIndex and slot.Name:match("^Slot_(%d+)$") then
                slotIndex = tonumber(slot.Name:match("^Slot_(%d+)$"))
            end
            if slotIndex then
                local collectPad = slot:FindFirstChild("CollectPad")
                if collectPad then
                    local isUnlocked = (slotIndex <= currentOwnedSlots)

                    local billboard = self:_GetOrCreateBillboard(collectPad)
                    billboard.Enabled = isUnlocked

                    if isUnlocked then
                        local cashLabel = billboard:FindFirstChild("CashLabel")
                        if cashLabel then
                            -- Clés numériques ou string selon la sérialisation Remote
                            local amount = currentSlotCash[slotIndex] or currentSlotCash[tostring(slotIndex)] or 0
                            if amount > 0 then
                                cashLabel.Text = "$" .. self:FormatNumber(amount)
                                cashLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
                            else
                                cashLabel.Text = "$0"
                                cashLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                            end
                        end
                    end
                end
            end
        end
    end
end

--[[
    Demande la collecte d'un slot spécifique
    @param slotIndex: number
]]
function EconomyController:RequestCollectSlot(slotIndex)
    -- print("[EconomyController] Demande collecte slot " .. slotIndex)
    collectSlotCash:FireServer(slotIndex)
end

--[[
    Demande la collecte de tous les slots
]]
function EconomyController:RequestCollectAll()
    -- print("[EconomyController] Demande collecte tous les slots")
    collectSlotCash:FireServer(nil) -- nil = tous
end

-- ═══════════════════════════════════════════════════════
-- SYNCHRONISATION
-- ═══════════════════════════════════════════════════════

--[[
    Met à jour les données économiques locales
    @param data: table - {OwnedSlots, SlotCash, etc.}
]]
function EconomyController:UpdateData(data)
    if data.OwnedSlots then
        local oldSlots = currentOwnedSlots
        currentOwnedSlots = data.OwnedSlots
        
        -- Si le shop est ouvert, mettre à jour
        if isShopOpen then
            self:UpdateShopDisplay()
        end
        
        -- Mettre à jour le Display du SlotShop
        self:UpdateSlotShopDisplay()
        
        -- Rafraîchir la visibilité des CollectPads (étages débloqués)
        self:UpdateCollectPads(currentSlotCash)
        
        -- Si un étage a été débloqué
        if data.UnlockedFloor then
            self:OnFloorUnlocked(data.UnlockedFloor)
        end
    end
    
    if data.SlotCash then
        self:UpdateCollectPads(data.SlotCash)
    end
end

--[[
    Appelé quand un étage est débloqué
    @param floorNumber: number
]]
function EconomyController:OnFloorUnlocked(floorNumber)
    -- print("[EconomyController] Étage " .. floorNumber .. " débloqué!")
    
    if self._uiController then
        self._uiController:ShowNotification("Success", "Floor " .. floorNumber .. " unlocked! 🎉", 5)
    end
    
    if SoundHelper then
        SoundHelper.Play("FloorUnlock")
    end
end

-- ═══════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════

--[[
    Formate un nombre avec séparateurs de milliers
    @param number: number
    @return string
]]
function EconomyController:FormatNumber(number)
    local formatted = tostring(math.floor(number))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

return EconomyController
