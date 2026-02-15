--[[
    ShopSystem.module.lua
    Gestion des achats Robux via MarketplaceService

    Responsabilités:
    - Configurer ProcessReceipt (callback d'achat)
    - Valider les demandes d'achat client
    - Accorder les récompenses (cash) après achat confirmé
    - Mapping ProductId → récompense

    Flux:
    1. Client fire RequestShopPurchase(categoryId, productIndex)
    2. Serveur valide et appelle PromptProductPurchase
    3. Roblox affiche la fenêtre de confirmation
    4. Si confirmé, ProcessReceipt est appelé par Roblox
    5. Serveur donne le cash et retourne PurchaseGranted
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules (chargés dans Init)
local ShopProducts = nil
local EconomySystem = nil
local NetworkSetup = nil
local DataService = nil

-- Mapping: ProductId → { Cash = number, CategoryId = string, DisplayName = string }
local _productMap = {}

local ShopSystem = {}
ShopSystem._initialized = false

--[[
    Initialise le système de shop
    @param services: table - {EconomySystem, NetworkSetup, DataService}
]]
function ShopSystem:Init(services)
    if self._initialized then
        warn("[ShopSystem] Déjà initialisé!")
        return
    end

    print("[ShopSystem] Initialisation...")

    -- Récupérer les services injectés
    EconomySystem = services.EconomySystem
    NetworkSetup = services.NetworkSetup
    DataService = services.DataService

    if not EconomySystem then
        warn("[ShopSystem] EconomySystem requis! Le shop ne fonctionnera pas sans.")
        return
    end

    -- Charger la configuration des produits
    local Data = ReplicatedStorage:WaitForChild("Data")
    ShopProducts = require(Data:WaitForChild("ShopProducts.module"))

    -- Construire le mapping ProductId → récompense
    self:_BuildProductMap()

    -- Configurer le callback ProcessReceipt
    self:_SetupProcessReceipt()

    self._initialized = true
    print("[ShopSystem] Initialisé! " .. self:_CountProducts() .. " produits enregistrés.")
end

-- ═══════════════════════════════════════════════════════
-- DEMANDE D'ACHAT (appelé par NetworkHandler)
-- ═══════════════════════════════════════════════════════

--[[
    Traite une demande d'achat du client
    @param player: Player
    @param categoryId: string - ID de la catégorie (ex: "Money")
    @param productIndex: number - Index du produit dans la catégorie (1-based)
]]
function ShopSystem:RequestPurchase(player, categoryId, productIndex)
    print(string.format("[ShopSystem] Demande d'achat de %s: catégorie=%s, index=%s",
        player.Name, tostring(categoryId), tostring(productIndex)))

    -- Validation des paramètres
    if type(categoryId) ~= "string" or categoryId == "" then
        self:_SendNotification(player, "Error", "Catégorie invalide.")
        return
    end

    if type(productIndex) ~= "number" or productIndex < 1 then
        self:_SendNotification(player, "Error", "Produit invalide.")
        return
    end

    -- Trouver la catégorie
    local category = self:_FindCategory(categoryId)
    if not category then
        self:_SendNotification(player, "Error", "Catégorie introuvable.")
        return
    end

    -- Trouver le produit
    local product = category.Products[productIndex]
    if not product then
        self:_SendNotification(player, "Error", "Produit introuvable.")
        return
    end

    -- Vérifier que le ProductId est configuré
    if not product.ProductId or product.ProductId == 0 then
        warn("[ShopSystem] ProductId non configuré pour " .. product.DisplayName)
        self:_SendNotification(player, "Error", "Ce produit n'est pas encore disponible.")
        return
    end

    -- Déclencher la fenêtre d'achat Roblox native
    local success, err = pcall(function()
        MarketplaceService:PromptProductPurchase(player, product.ProductId)
    end)

    if not success then
        warn("[ShopSystem] Erreur PromptProductPurchase: " .. tostring(err))
        self:_SendNotification(player, "Error", "Erreur lors de l'achat. Réessayez.")
    else
        print(string.format("[ShopSystem] Fenêtre d'achat ouverte pour %s (produit: %s, R$%d)",
            player.Name, product.DisplayName, product.Robux))
    end
end

-- ═══════════════════════════════════════════════════════
-- PROCESS RECEIPT (callback Roblox)
-- ═══════════════════════════════════════════════════════

--[[
    Configure le callback ProcessReceipt de MarketplaceService.
    Ce callback est appelé par Roblox après qu'un joueur confirme un achat.

    IMPORTANT: Ce callback DOIT retourner Enum.ProductPurchaseDecision.PurchaseGranted
    pour que l'achat soit finalisé. Si on retourne NotProcessedYet, Roblox
    réessaiera plus tard (utile si le joueur n'est plus connecté).
]]
function ShopSystem:_SetupProcessReceipt()
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        print(string.format("[ShopSystem] ProcessReceipt: PlayerId=%d, ProductId=%d, PurchaseId=%s",
            receiptInfo.PlayerId, receiptInfo.ProductId, receiptInfo.PurchaseId))

        -- 1. Trouver le joueur
        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        if not player then
            -- Le joueur n'est plus connecté, Roblox réessaiera plus tard
            warn("[ShopSystem] Joueur " .. receiptInfo.PlayerId .. " non trouvé, réessai plus tard")
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        -- 2. Trouver le produit
        local productInfo = _productMap[receiptInfo.ProductId]
        if not productInfo then
            warn("[ShopSystem] ProductId inconnu: " .. receiptInfo.ProductId)
            -- On retourne PurchaseGranted quand même pour ne pas bloquer
            -- (le produit n'existe pas dans notre config, possible erreur de config)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end

        -- 3. Accorder la récompense
        local success, err = pcall(function()
            if productInfo.Cash and productInfo.Cash > 0 then
                EconomySystem:AddCash(player, productInfo.Cash)
                print(string.format("[ShopSystem] +$%d accordé à %s (produit: %s)",
                    productInfo.Cash, player.Name, productInfo.DisplayName))
            end
        end)

        if not success then
            warn("[ShopSystem] Erreur lors de l'accord de la récompense: " .. tostring(err))
            -- On retourne NotProcessedYet pour que Roblox réessaie
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        -- 4. Notification de succès
        self:_SendNotification(player, "Success",
            "Achat réussi ! +" .. productInfo.DisplayName .. " ajouté à votre compte !")

        -- 5. Confirmer l'achat à Roblox
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    print("[ShopSystem] ProcessReceipt configuré")
end

-- ═══════════════════════════════════════════════════════
-- UTILITAIRES INTERNES
-- ═══════════════════════════════════════════════════════

--[[
    Construit le mapping ProductId → récompense à partir de ShopProducts
]]
function ShopSystem:_BuildProductMap()
    _productMap = {}

    for _, category in ipairs(ShopProducts.Categories) do
        for _, product in ipairs(category.Products) do
            if product.ProductId and product.ProductId > 0 then
                _productMap[product.ProductId] = {
                    Cash = product.Cash,
                    Robux = product.Robux,
                    DisplayName = product.DisplayName,
                    CategoryId = category.Id,
                }
            end
        end
    end
end

--[[
    Trouve une catégorie par son ID
    @param categoryId: string
    @return table | nil
]]
function ShopSystem:_FindCategory(categoryId)
    for _, category in ipairs(ShopProducts.Categories) do
        if category.Id == categoryId then
            return category
        end
    end
    return nil
end

--[[
    Compte le nombre total de produits avec un ProductId valide
    @return number
]]
function ShopSystem:_CountProducts()
    local count = 0
    for _ in pairs(_productMap) do
        count = count + 1
    end
    return count
end

--[[
    Envoie une notification au client
    @param player: Player
    @param notifType: string - "Success" | "Error" | "Info" | "Warning"
    @param message: string
]]
function ShopSystem:_SendNotification(player, notifType, message)
    if not NetworkSetup then return end

    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.Notification then
        remotes.Notification:FireClient(player, {
            Type = notifType,
            Message = message,
            Duration = 4,
        })
    end
end

return ShopSystem
