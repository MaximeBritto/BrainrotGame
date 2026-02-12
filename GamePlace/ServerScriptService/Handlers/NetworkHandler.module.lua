--[[
    NetworkHandler.lua
    Gère tous les RemoteEvents reçus du client
    
    Responsabilités:
    - Recevoir les requêtes client
    - Valider les données
    - Appeler les bons systèmes
    - Renvoyer les résultats
    
    Phase 6 (A6.4) - Vérification Codex:
    - SyncCodex est envoyé par CodexService/DataService/PlayerService (pas par NetworkHandler)
    - SyncPlayerData inclut CodexUnlocked pour synchro globale (GetFullPlayerData, Craft, etc.)
    - Aucun handler n'écrase ou ne duplique SyncCodex
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])

-- Services (seront injectés)
local NetworkSetup = nil
local DataService = nil
local PlayerService = nil

-- Systèmes (Phase 2+)
local BaseSystem = nil
local DoorSystem = nil
local EconomySystem = nil

-- Systèmes (Phase 4)
local ArenaSystem = nil
local InventorySystem = nil

-- Systèmes (Phase 5)
local CraftingSystem = nil
local PlacementSystem = nil

-- Systèmes (Phase 8)
local StealSystem = nil
local BatSystem = nil

local NetworkHandler = {}
NetworkHandler._initialized = false

--[[
    Initialise le handler et connecte tous les événements
    @param services: table
]]
function NetworkHandler:Init(services)
    if self._initialized then
        warn("[NetworkHandler] Déjà initialisé!")
        return
    end
    
    print("[NetworkHandler] Initialisation...")
    
    -- Récupérer les services
    NetworkSetup = services.NetworkSetup
    DataService = services.DataService
    PlayerService = services.PlayerService
    
    -- Récupérer les systèmes (Phase 2+)
    BaseSystem = services.BaseSystem
    DoorSystem = services.DoorSystem
    EconomySystem = services.EconomySystem
    
    -- Récupérer les systèmes (Phase 4)
    ArenaSystem = services.ArenaSystem
    InventorySystem = services.InventorySystem
    
    -- Récupérer les systèmes (Phase 5)
    CraftingSystem = services.CraftingSystem
    PlacementSystem = services.PlacementSystem

    -- Récupérer les systèmes (Phase 8)
    StealSystem = services.StealSystem
    BatSystem = services.BatSystem

    -- Connecter les handlers
    self:_ConnectHandlers()
    
    self._initialized = true
    print("[NetworkHandler] Initialisé!")
end

--[[
    Connecte tous les handlers aux RemoteEvents
]]
function NetworkHandler:_ConnectHandlers()
    local remotes = NetworkSetup:GetAllRemotes()
    
    -- ═══════════════════════════════════════
    -- CLIENT → SERVEUR (RemoteEvents)
    -- ═══════════════════════════════════════
    
    -- PickupPiece (Phase 4)
    if remotes.PickupPiece then
        remotes.PickupPiece.OnServerEvent:Connect(function(player, pieceId)
            self:_HandlePickupPiece(player, pieceId)
        end)
    end
    
    -- Craft (Phase 5)
    if remotes.Craft then
        remotes.Craft.OnServerEvent:Connect(function(player)
            self:_HandleCraft(player)
        end)
    end
    
    -- BuySlot (Phase 3)
    if remotes.BuySlot then
        remotes.BuySlot.OnServerEvent:Connect(function(player)
            self:_HandleBuySlot(player)
        end)
    end
    
    -- CollectSlotCash (Phase 3)
    if remotes.CollectSlotCash then
        remotes.CollectSlotCash.OnServerEvent:Connect(function(player, slotIndex)
            self:_HandleCollectSlotCash(player, slotIndex)
        end)
    end
    
    -- ActivateDoor (Phase 2)
    if remotes.ActivateDoor then
        remotes.ActivateDoor.OnServerEvent:Connect(function(player)
            self:_HandleActivateDoor(player)
        end)
    end
    
    -- DropPieces (Phase 4)
    if remotes.DropPieces then
        remotes.DropPieces.OnServerEvent:Connect(function(player)
            self:_HandleDropPieces(player)
        end)
    end

    -- Vol de Brainrot (Phase 8 - Version simplifiée)
    if remotes.StealBrainrot then
        remotes.StealBrainrot.OnServerEvent:Connect(function(player, ownerId, slotId)
            print(string.format("[NetworkHandler] StealBrainrot reçu - player: %s, ownerId: %s (type: %s), slotId: %s (type: %s)",
                player.Name, tostring(ownerId), type(ownerId), tostring(slotId), type(slotId)))

            -- Convertir les paramètres en nombres si nécessaire
            if type(ownerId) == "string" then
                ownerId = tonumber(ownerId)
            end
            if type(slotId) == "string" then
                slotId = tonumber(slotId)
            end

            local success, err = pcall(function()
                if StealSystem then
                    StealSystem:ExecuteSteal(player, ownerId, slotId)
                else
                    warn("[NetworkHandler] StealSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur StealBrainrot: " .. tostring(err))
            end
        end)
    end

    -- Placer brainrot volé sur un slot (Phase 8 v2)
    if remotes.PlaceStolenBrainrot then
        remotes.PlaceStolenBrainrot.OnServerEvent:Connect(function(player, slotIndex)
            if type(slotIndex) == "string" then
                slotIndex = tonumber(slotIndex)
            end
            if not slotIndex or type(slotIndex) ~= "number" then return end

            local success, err = pcall(function()
                if StealSystem then
                    StealSystem:PlaceStolenBrainrot(player, slotIndex)
                else
                    warn("[NetworkHandler] StealSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur PlaceStolenBrainrot: " .. tostring(err))
            end
        end)
    end

    -- Combat batte (Phase 8)
    if remotes.BatHit then
        remotes.BatHit.OnServerEvent:Connect(function(player, victimId)
            pcall(function()
                if BatSystem then
                    BatSystem:HandleBatHit(player, victimId)
                end
            end)
        end)
    end

    -- ═══════════════════════════════════════
    -- REMOTE FUNCTIONS
    -- ═══════════════════════════════════════
    
    -- GetFullPlayerData
    if remotes.GetFullPlayerData then
        remotes.GetFullPlayerData.OnServerInvoke = function(player)
            return self:_HandleGetFullPlayerData(player)
        end
    end
    
    print("[NetworkHandler] Handlers connectés")
end

-- ═══════════════════════════════════════════════════════
-- HANDLERS (Placeholders - seront complétés dans les phases suivantes)
-- ═══════════════════════════════════════════════════════

function NetworkHandler:_HandlePickupPiece(player, pieceId)
    print("[NetworkHandler] PickupPiece reçu de " .. player.Name .. " pour " .. tostring(pieceId))
    
    if not InventorySystem then
        self:_SendNotification(player, "Error", "Inventory system not initialized")
        return
    end
    
    -- Tenter de ramasser la pièce (4 validations)
    local success, result, pieceData = InventorySystem:TryPickupPiece(player, pieceId)
    
    if success then
        -- Sync l'inventaire avec le client
        self:SyncInventory(player)
        
        -- Phase 6: débloquer la partie dans le Codex (Head/Body/Legs)
        if pieceData and DataService and pieceData.SetName and pieceData.PieceType then
            DataService:UnlockCodexPart(player, pieceData.SetName, pieceData.PieceType)
        end
        
        -- Notification de succès
        local message = Constants.SuccessMessages.PiecePickedUp
        if pieceData then
            message = pieceData.DisplayName .. " " .. pieceData.PieceType .. " picked up!"
        end
        self:_SendNotification(player, "Success", message, 2)
    else
        -- Notification d'erreur
        local errorMessage = Constants.ErrorMessages[result] or "Cannot pickup this piece"
        self:_SendNotification(player, "Error", errorMessage, 2)
    end
end

function NetworkHandler:_HandleCraft(player)
    print("[NetworkHandler] Craft reçu de " .. player.Name)
    
    if not CraftingSystem then
        self:_SendNotification(player, "Error", "Crafting system not initialized")
        return
    end
    
    -- Tenter de crafter
    local success, result, craftData = CraftingSystem:TryCraft(player)
    
    if success then
        -- Construire le message
        local message = craftData.SetName .. " Brainrot crafted!"
        if craftData.IsCompleteSet then
            message = message .. " Complete set! +$" .. craftData.Bonus
        end
        
        -- Notifier le succès
        self:_SendNotification(player, "Success", message, 4)
        
        -- Sync l'inventaire (vide)
        self:SyncInventory(player)
        
        -- Sync les données (cash, PlacedBrainrots, Codex)
        local playerData = DataService:GetPlayerData(player)
        if playerData then
            self:SyncPlayerData(player, {
                Cash = playerData.Cash,
                PlacedBrainrots = playerData.PlacedBrainrots,
                CodexUnlocked = playerData.CodexUnlocked,
            })
        end
    else
        -- Notifier l'échec
        local errorMessage = Constants.ErrorMessages[result] or "Cannot craft"
        self:_SendNotification(player, "Error", errorMessage, 3)
    end
end

--[[
    Handler: Achat de slot
    @param player: Player
]]
function NetworkHandler:_HandleBuySlot(player)
    print("[NetworkHandler] BuySlot reçu de " .. player.Name)
    
    if not EconomySystem then
        self:_SendNotification(player, "Error", "Economy system not initialized")
        return
    end
    
    local result, newSlotCount = EconomySystem:BuyNextSlot(player)
    
    if result == "Success" then
        local nextPrice = EconomySystem:GetNextSlotPrice(player)
        local message = "Slot " .. newSlotCount .. " purchased!"
        if nextPrice then
            message = message .. " Next: $" .. nextPrice
        else
            message = message .. " (Max reached)"
        end
        self:_SendNotification(player, "Success", message)
    elseif result == "NotEnoughMoney" then
        local nextPrice = EconomySystem:GetNextSlotPrice(player)
        self:_SendNotification(player, "Error", "Not enough money! ($" .. (nextPrice or 0) .. " required)")
    elseif result == "MaxSlotsReached" then
        self:_SendNotification(player, "Warning", "Maximum slots reached!")
    else
        self:_SendNotification(player, "Error", "Purchase error")
    end
end

--[[
    Handler: Collecte de l'argent d'un slot
    @param player: Player
    @param slotIndex: number | nil - Si nil, collecte tout
]]
function NetworkHandler:_HandleCollectSlotCash(player, slotIndex)
    print("[NetworkHandler] CollectSlotCash reçu de " .. player.Name .. " pour slot " .. tostring(slotIndex))

    if not EconomySystem then
        self:_SendNotification(player, "Error", "Economy system not initialized")
        return
    end

    -- Accepter slotIndex en number ou string (sérialisation Remote)
    if type(slotIndex) == "string" and slotIndex ~= "" then
        slotIndex = tonumber(slotIndex)
    end

    -- Valider que le slot appartient bien au joueur
    if slotIndex and type(slotIndex) == "number" then
        local playerData = DataService:GetPlayerData(player)
        if not playerData then return end
        local ownedSlots = playerData.OwnedSlots or 1
        if slotIndex < 1 or slotIndex > ownedSlots then
            self:_SendNotification(player, "Error", "Invalid slot!", 2)
            return
        end
    end

    local amount

    if slotIndex and type(slotIndex) == "number" then
        -- Collecter un slot spécifique
        amount = EconomySystem:CollectSlotCash(player, slotIndex)
    else
        -- Collecter tous les slots
        amount = EconomySystem:CollectAllSlotCash(player)
    end

    if amount > 0 then
        self:_SendNotification(player, "Success", "+$" .. amount .. " collected!")
    end
end

function NetworkHandler:_HandleActivateDoor(player)
    -- Phase 2: DoorSystem:ActivateDoor(player)
    print("[NetworkHandler] ActivateDoor reçu de " .. player.Name)
    
    if not DoorSystem then
        self:_SendNotification(player, "Info", "Door system not loaded")
        return
    end
    
    local result = DoorSystem:ActivateDoor(player)
    
    if result == Constants.ActionResult.Success then
        self:_SendNotification(player, "Success", "Door closed for 30 seconds!", 3)
    elseif result == Constants.ActionResult.OnCooldown then
        local doorState = DoorSystem:GetDoorState(player)
        self:_SendNotification(player, "Warning", "Door already closed! " .. doorState.RemainingTime .. "s remaining", 2)
    elseif result == Constants.ActionResult.NotOwner then
        self:_SendNotification(player, "Error", "This is not your base!", 2)
    end
end

function NetworkHandler:_HandleDropPieces(player)
    -- Phase 4: Vider les pièces en main volontairement
    print("[NetworkHandler] DropPieces reçu de " .. player.Name)
    
    local pieces = PlayerService:ClearPiecesInHand(player)
    print("[NetworkHandler] " .. player.Name .. " a lâché " .. #pieces .. " pièces")
    
    -- Sync avec le client
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes.SyncInventory then
        remotes.SyncInventory:FireClient(player, {})
    end
    
    if #pieces > 0 then
        self:_SendNotification(player, "Info", #pieces .. " piece(s) dropped")
    end
end

function NetworkHandler:_HandleGetFullPlayerData(player)
    -- Renvoie toutes les données du joueur
    print("[NetworkHandler] GetFullPlayerData demandé par " .. player.Name)
    
    local playerData = DataService:GetPlayerData(player)
    local runtimeData = PlayerService:GetRuntimeData(player)
    
    -- Combiner les données sauvegardées et runtime
    local fullData = {
        -- Données sauvegardées
        Cash = playerData and playerData.Cash or 0,
        OwnedSlots = playerData and (playerData.OwnedSlots or 10),
        PlacedBrainrots = playerData and playerData.PlacedBrainrots or {},
        SlotCash = playerData and playerData.SlotCash or {},
        CodexUnlocked = playerData and playerData.CodexUnlocked or {},
        CompletedSets = playerData and playerData.CompletedSets or {},
        Stats = playerData and playerData.Stats or {},
        
        -- Données runtime
        PiecesInHand = runtimeData and runtimeData.PiecesInHand or {},
        CarriedBrainrot = runtimeData and runtimeData.CarriedBrainrot or nil,
        DoorState = runtimeData and runtimeData.DoorState or Constants.DoorState.Open,
    }
    
    return fullData
end

-- ═══════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════

--[[
    Envoie une notification au client
    @param player: Player
    @param notifType: string - "Success" | "Error" | "Info" | "Warning"
    @param message: string
    @param duration: number (optionnel, défaut 3)
]]
function NetworkHandler:_SendNotification(player, notifType, message, duration)
    local remotes = NetworkSetup:GetAllRemotes()
    
    if remotes.Notification then
        remotes.Notification:FireClient(player, {
            Type = notifType,
            Message = message,
            Duration = duration or 3,
        })
    end
end

--[[
    Sync les données joueur vers le client
    @param player: Player
    @param data: table (partiel ou complet)
]]
function NetworkHandler:SyncPlayerData(player, data)
    local remotes = NetworkSetup:GetAllRemotes()
    
    if remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, data)
    end
end

--[[
    Sync l'inventaire vers le client
    @param player: Player
]]
function NetworkHandler:SyncInventory(player)
    local remotes = NetworkSetup:GetAllRemotes()
    local piecesInHand = PlayerService:GetPiecesInHand(player)
    
    if remotes.SyncInventory then
        remotes.SyncInventory:FireClient(player, piecesInHand)
    end
end

--[[
    Met à jour les systèmes après leur initialisation
    @param systems: table - {BaseSystem, DoorSystem, EconomySystem, ArenaSystem, InventorySystem, CraftingSystem, PlacementSystem, ...}
]]
function NetworkHandler:UpdateSystems(systems)
    if systems.BaseSystem then
        BaseSystem = systems.BaseSystem
    end
    if systems.DoorSystem then
        DoorSystem = systems.DoorSystem
    end
    if systems.EconomySystem then
        EconomySystem = systems.EconomySystem
    end
    if systems.ArenaSystem then
        ArenaSystem = systems.ArenaSystem
    end
    if systems.InventorySystem then
        InventorySystem = systems.InventorySystem
    end
    if systems.CraftingSystem then
        CraftingSystem = systems.CraftingSystem
    end
    if systems.PlacementSystem then
        PlacementSystem = systems.PlacementSystem
    end
    if systems.StealSystem then
        StealSystem = systems.StealSystem
    end
    if systems.BatSystem then
        BatSystem = systems.BatSystem
    end

    print("[NetworkHandler] Systèmes mis à jour")
end

return NetworkHandler
