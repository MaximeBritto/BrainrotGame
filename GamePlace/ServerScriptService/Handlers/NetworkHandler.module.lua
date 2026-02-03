--[[
    NetworkHandler.lua
    Gère tous les RemoteEvents reçus du client
    
    Responsabilités:
    - Recevoir les requêtes client
    - Valider les données
    - Appeler les bons systèmes
    - Renvoyer les résultats
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared["Constants.module"])

-- Services (seront injectés)
local NetworkSetup = nil
local DataService = nil
local PlayerService = nil

-- Systèmes (seront ajoutés dans les phases suivantes)
-- local BaseSystem = nil
-- local EconomySystem = nil
-- local InventorySystem = nil
-- local CraftingSystem = nil
-- local DoorSystem = nil

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
    
    -- Récupérer les systèmes (sera ajouté plus tard)
    -- BaseSystem = services.BaseSystem
    -- EconomySystem = services.EconomySystem
    -- ...
    
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
    -- Phase 4: InventorySystem:TryPickupPiece(player, piece)
    print("[NetworkHandler] PickupPiece reçu de " .. player.Name .. " pour " .. tostring(pieceId))
    
    -- Placeholder: envoyer une notification
    self:_SendNotification(player, "Info", "Pickup non implémenté (Phase 4)")
end

function NetworkHandler:_HandleCraft(player)
    -- Phase 5: CraftingSystem:TryCraft(player)
    print("[NetworkHandler] Craft reçu de " .. player.Name)
    
    self:_SendNotification(player, "Info", "Craft non implémenté (Phase 5)")
end

function NetworkHandler:_HandleBuySlot(player)
    -- Phase 3: EconomySystem:BuyNextSlot(player)
    print("[NetworkHandler] BuySlot reçu de " .. player.Name)
    
    self:_SendNotification(player, "Info", "Achat slot non implémenté (Phase 3)")
end

function NetworkHandler:_HandleCollectSlotCash(player, slotIndex)
    -- Phase 3: EconomySystem:CollectSlotCash(player, slotIndex)
    print("[NetworkHandler] CollectSlotCash reçu de " .. player.Name .. " pour slot " .. tostring(slotIndex))
    
    self:_SendNotification(player, "Info", "Collecte non implémentée (Phase 3)")
end

function NetworkHandler:_HandleActivateDoor(player)
    -- Phase 2: DoorSystem:ActivateDoor(player)
    print("[NetworkHandler] ActivateDoor reçu de " .. player.Name)
    
    self:_SendNotification(player, "Info", "Porte non implémentée (Phase 2)")
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
        self:_SendNotification(player, "Info", #pieces .. " pièce(s) lâchée(s)")
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
        OwnedSlots = playerData and playerData.OwnedSlots or 1,
        PlacedBrainrots = playerData and playerData.PlacedBrainrots or {},
        SlotCash = playerData and playerData.SlotCash or {},
        CodexUnlocked = playerData and playerData.CodexUnlocked or {},
        CompletedSets = playerData and playerData.CompletedSets or {},
        Stats = playerData and playerData.Stats or {},
        
        -- Données runtime
        PiecesInHand = runtimeData and runtimeData.PiecesInHand or {},
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

return NetworkHandler
