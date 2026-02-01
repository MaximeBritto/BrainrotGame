# PHASE 1 : CORE SYSTEMS - Guide Ultra-Détaillé

## Vue d'ensemble

La Phase 1 établit les fondations du jeu :
- **DEV A** : Backend Core (DataService, PlayerService, NetworkHandler)
- **DEV B** : Client Core (UI de base, contrôleurs)

### Objectif Final de la Phase 1
- Un joueur peut rejoindre le jeu
- Ses données sont chargées/sauvegardées
- L'UI affiche son argent et ses pièces en main
- Les notifications s'affichent

---

## Prérequis (Phase 0 Complétée)

Avant de commencer, vérifier que ces fichiers existent :

| Fichier | Statut |
|---------|--------|
| `ReplicatedStorage/Config/GameConfig` | ✅ Existant |
| `ReplicatedStorage/Config/FeatureFlags` | ✅ Existant |
| `ReplicatedStorage/Data/BrainrotData` | ✅ Existant |
| `ReplicatedStorage/Data/SlotPrices` | ✅ Existant |
| `ReplicatedStorage/Data/DefaultPlayerData` | ✅ Existant |
| `ReplicatedStorage/Shared/Constants` | ✅ Existant |
| `ReplicatedStorage/Shared/Utils` | ✅ Existant |
| `ServerScriptService/Core/NetworkSetup` | ✅ Existant |

---

# DEV A - BACKEND CORE

## Résumé des Tâches

| # | Tâche | Dépendance | Fichier à créer |
|---|-------|------------|-----------------|
| A1.1 | 🟢 DataService | Aucune | `ServerScriptService/Core/DataService.module.lua` |
| A1.2 | 🟡 PlayerService | A1.1 | `ServerScriptService/Core/PlayerService.module.lua` |
| A1.3 | 🟡 GameServer | A1.1, A1.2 | `ServerScriptService/Core/GameServer.server.lua` |
| A1.4 | 🟡 NetworkHandler | A1.1, A1.2 | `ServerScriptService/Handlers/NetworkHandler.module.lua` |

---

## A1.1 - DataService.module.lua

### Description
Service de gestion des données joueur avec DataStore.

### Dépendances
- `ReplicatedStorage/Config/GameConfig`
- `ReplicatedStorage/Data/DefaultPlayerData`

### Fichier : `ServerScriptService/Core/DataService.module.lua`

```lua
--[[
    DataService.lua
    Gestion des données joueur avec DataStore
    
    Responsabilités:
    - Charger/Sauvegarder les données dans DataStore
    - Maintenir un cache en mémoire
    - Gérer les migrations de données
    - Auto-save périodique
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Config = ReplicatedStorage:WaitForChild("Config")
local Data = ReplicatedStorage:WaitForChild("Data")

local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefaultPlayerData = require(Data:WaitForChild("DefaultPlayerData"))

-- DataStore (désactivé en Studio si pas de API access)
local dataStore = nil
local isStudio = RunService:IsStudio()

local DataService = {}
DataService._cache = {} -- {[userId] = playerData}
DataService._initialized = false

-- Événements internes (BindableEvents)
DataService.OnPlayerDataLoaded = Instance.new("BindableEvent")
DataService.OnPlayerDataSaved = Instance.new("BindableEvent")
DataService.OnDataError = Instance.new("BindableEvent")

--[[
    Initialise le DataStore
]]
function DataService:Init()
    if self._initialized then
        warn("[DataService] Déjà initialisé!")
        return
    end
    
    print("[DataService] Initialisation...")
    
    -- Tenter de créer le DataStore
    local success, result = pcall(function()
        return DataStoreService:GetDataStore(GameConfig.DataStore.Name)
    end)
    
    if success then
        dataStore = result
        print("[DataService] DataStore connecté: " .. GameConfig.DataStore.Name)
    else
        warn("[DataService] Impossible de créer DataStore: " .. tostring(result))
        warn("[DataService] Mode hors-ligne activé (données non persistantes)")
    end
    
    -- Démarrer l'auto-save
    self:_StartAutoSave()
    
    self._initialized = true
    print("[DataService] Initialisé!")
end

--[[
    Charge les données d'un joueur
    @param player: Player
    @return table | nil
]]
function DataService:LoadPlayerData(player)
    local userId = player.UserId
    local key = "Player_" .. userId
    
    print("[DataService] Chargement des données pour " .. player.Name .. " (ID: " .. userId .. ")")
    
    -- Tenter de charger depuis DataStore
    local data = nil
    
    if dataStore then
        for attempt = 1, GameConfig.DataStore.RetryAttempts do
            local success, result = pcall(function()
                return dataStore:GetAsync(key)
            end)
            
            if success then
                data = result
                break
            else
                warn("[DataService] Tentative " .. attempt .. "/" .. GameConfig.DataStore.RetryAttempts .. " échouée: " .. tostring(result))
                
                if attempt < GameConfig.DataStore.RetryAttempts then
                    task.wait(GameConfig.DataStore.RetryDelay)
                end
            end
        end
    end
    
    -- Si pas de données, utiliser les données par défaut
    if data == nil then
        print("[DataService] Nouveau joueur ou données vides, utilisation des défauts")
        data = self:_DeepCopy(DefaultPlayerData)
    else
        -- Appliquer les migrations si nécessaire
        data = self:_MigrateData(data)
    end
    
    -- Mettre en cache
    self._cache[userId] = data
    
    print("[DataService] Données chargées pour " .. player.Name)
    self.OnPlayerDataLoaded:Fire(player, data)
    
    return data
end

--[[
    Sauvegarde les données d'un joueur
    @param player: Player
    @return boolean
]]
function DataService:SavePlayerData(player)
    local userId = player.UserId
    local key = "Player_" .. userId
    local data = self._cache[userId]
    
    if not data then
        warn("[DataService] Pas de données en cache pour " .. player.Name)
        return false
    end
    
    print("[DataService] Sauvegarde des données pour " .. player.Name)
    
    if not dataStore then
        print("[DataService] Mode hors-ligne, sauvegarde ignorée")
        return true -- Pas d'erreur, juste pas de DataStore
    end
    
    -- Tenter de sauvegarder
    for attempt = 1, GameConfig.DataStore.RetryAttempts do
        local success, result = pcall(function()
            dataStore:SetAsync(key, data)
        end)
        
        if success then
            print("[DataService] Données sauvegardées pour " .. player.Name)
            self.OnPlayerDataSaved:Fire(player)
            return true
        else
            warn("[DataService] Tentative sauvegarde " .. attempt .. "/" .. GameConfig.DataStore.RetryAttempts .. " échouée: " .. tostring(result))
            
            if attempt < GameConfig.DataStore.RetryAttempts then
                task.wait(GameConfig.DataStore.RetryDelay)
            end
        end
    end
    
    warn("[DataService] ÉCHEC SAUVEGARDE pour " .. player.Name)
    self.OnDataError:Fire(player, "Échec de sauvegarde après " .. GameConfig.DataStore.RetryAttempts .. " tentatives")
    return false
end

--[[
    Récupère les données en cache d'un joueur
    @param player: Player
    @return table | nil
]]
function DataService:GetPlayerData(player)
    return self._cache[player.UserId]
end

--[[
    Met à jour une valeur dans les données du joueur
    @param player: Player
    @param key: string - Clé à modifier (supporte "Stats.TotalCrafts" format)
    @param value: any
    @return boolean
]]
function DataService:UpdateValue(player, key, value)
    local data = self._cache[player.UserId]
    
    if not data then
        warn("[DataService] Pas de données pour " .. player.Name)
        return false
    end
    
    -- Gérer les clés imbriquées (ex: "Stats.TotalCrafts")
    local keys = string.split(key, ".")
    local current = data
    
    for i = 1, #keys - 1 do
        current = current[keys[i]]
        if not current then
            warn("[DataService] Clé invalide: " .. key)
            return false
        end
    end
    
    current[keys[#keys]] = value
    return true
end

--[[
    Incrémente une valeur numérique
    @param player: Player
    @param key: string
    @param amount: number
    @return number - Nouvelle valeur
]]
function DataService:IncrementValue(player, key, amount)
    local data = self._cache[player.UserId]
    
    if not data then
        warn("[DataService] Pas de données pour " .. player.Name)
        return 0
    end
    
    -- Gérer les clés imbriquées
    local keys = string.split(key, ".")
    local current = data
    
    for i = 1, #keys - 1 do
        current = current[keys[i]]
        if not current then
            warn("[DataService] Clé invalide: " .. key)
            return 0
        end
    end
    
    local finalKey = keys[#keys]
    local currentValue = current[finalKey] or 0
    local newValue = currentValue + amount
    current[finalKey] = newValue
    
    return newValue
end

--[[
    Nettoie les données d'un joueur (quand il quitte)
    @param player: Player
]]
function DataService:CleanupPlayer(player)
    self._cache[player.UserId] = nil
    print("[DataService] Cache nettoyé pour " .. player.Name)
end

--[[
    Migration des données si la version change
    @param data: table
    @return table - Données migrées
]]
function DataService:_MigrateData(data)
    local currentVersion = data.Version or 1
    local latestVersion = DefaultPlayerData.Version
    
    if currentVersion >= latestVersion then
        return data -- Pas de migration nécessaire
    end
    
    print("[DataService] Migration des données de v" .. currentVersion .. " vers v" .. latestVersion)
    
    -- Ajouter les nouvelles clés manquantes
    for key, value in pairs(DefaultPlayerData) do
        if data[key] == nil then
            data[key] = self:_DeepCopy(value)
            print("[DataService] Ajout de la clé manquante: " .. key)
        end
    end
    
    -- Mettre à jour la version
    data.Version = latestVersion
    
    return data
end

--[[
    Copie profonde d'une table
    @param original: table
    @return table
]]
function DataService:_DeepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = self:_DeepCopy(value)
    end
    
    return copy
end

--[[
    Démarre la boucle d'auto-save
]]
function DataService:_StartAutoSave()
    task.spawn(function()
        while true do
            task.wait(GameConfig.DataStore.AutoSaveInterval)
            
            print("[DataService] Auto-save en cours...")
            
            for _, player in ipairs(Players:GetPlayers()) do
                if self._cache[player.UserId] then
                    self:SavePlayerData(player)
                end
            end
            
            print("[DataService] Auto-save terminé")
        end
    end)
    
    print("[DataService] Auto-save démarré (intervalle: " .. GameConfig.DataStore.AutoSaveInterval .. "s)")
end

return DataService
```

### Tests de Validation A1.1
- [ ] Le module se charge sans erreur
- [ ] `DataService:Init()` s'exécute sans crash
- [ ] Le DataStore est créé (ou mode hors-ligne si Studio)
- [ ] Pas d'erreur dans la console

---

## A1.2 - PlayerService.module.lua

### Description
Gestion de la connexion/déconnexion des joueurs.

### Dépendances
- `DataService` (A1.1)
- `ReplicatedStorage/Shared/Constants`

### Fichier : `ServerScriptService/Core/PlayerService.module.lua`

```lua
--[[
    PlayerService.lua
    Gestion de la connexion/déconnexion des joueurs
    
    Responsabilités:
    - Charger les données à la connexion
    - Sauvegarder les données à la déconnexion
    - Maintenir les données runtime (non sauvegardées)
    - Gérer le respawn
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

-- Services (seront injectés)
local DataService = nil
local NetworkSetup = nil

local PlayerService = {}
PlayerService._runtimeData = {} -- {[userId] = RuntimeData}
PlayerService._initialized = false

-- Structure des données runtime (non sauvegardées)
local function CreateRuntimeData()
    return {
        -- Pièces en main (temporaire)
        PiecesInHand = {},
        
        -- Base assignée
        AssignedBase = nil,
        BaseIndex = nil,
        
        -- État de la porte
        DoorState = Constants.DoorState.Open,
        DoorCloseTime = 0,
        DoorReopenTime = 0,
        
        -- Session
        JoinTime = os.time(),
        LastSaveTime = os.time(),
    }
end

--[[
    Initialise le service
    @param services: table - {DataService = ..., NetworkSetup = ...}
]]
function PlayerService:Init(services)
    if self._initialized then
        warn("[PlayerService] Déjà initialisé!")
        return
    end
    
    print("[PlayerService] Initialisation...")
    
    -- Récupérer les services injectés
    DataService = services.DataService
    NetworkSetup = services.NetworkSetup
    
    if not DataService then
        error("[PlayerService] DataService requis!")
    end
    
    -- Connecter les événements
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoin(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeave(player)
    end)
    
    -- Gérer les joueurs déjà connectés (si script chargé en retard)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:OnPlayerJoin(player)
        end)
    end
    
    self._initialized = true
    print("[PlayerService] Initialisé!")
end

--[[
    Appelé quand un joueur rejoint
    @param player: Player
]]
function PlayerService:OnPlayerJoin(player)
    print("[PlayerService] Joueur rejoint: " .. player.Name)
    
    -- 1. Charger les données sauvegardées
    local playerData = DataService:LoadPlayerData(player)
    
    if not playerData then
        warn("[PlayerService] Échec chargement données pour " .. player.Name)
        player:Kick("Impossible de charger vos données. Veuillez réessayer.")
        return
    end
    
    -- 2. Créer les données runtime
    self._runtimeData[player.UserId] = CreateRuntimeData()
    
    -- 3. Configurer le respawn du personnage
    player.CharacterAdded:Connect(function(character)
        self:OnCharacterAdded(player, character)
    end)
    
    -- 4. Envoyer les données au client
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, playerData)
        print("[PlayerService] Données envoyées au client: " .. player.Name)
    end
    
    print("[PlayerService] Joueur initialisé: " .. player.Name)
end

--[[
    Appelé quand un joueur quitte
    @param player: Player
]]
function PlayerService:OnPlayerLeave(player)
    print("[PlayerService] Joueur quitte: " .. player.Name)
    
    -- 1. Sauvegarder les données
    DataService:SavePlayerData(player)
    
    -- 2. Nettoyer le cache DataService
    DataService:CleanupPlayer(player)
    
    -- 3. Nettoyer les données runtime
    self._runtimeData[player.UserId] = nil
    
    print("[PlayerService] Joueur nettoyé: " .. player.Name)
end

--[[
    Appelé quand le personnage d'un joueur spawn
    @param player: Player
    @param character: Model
]]
function PlayerService:OnCharacterAdded(player, character)
    print("[PlayerService] Personnage spawné: " .. player.Name)
    
    -- Attendre que le Humanoid soit prêt
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Connecter l'événement de mort
    humanoid.Died:Connect(function()
        self:OnPlayerDied(player)
    end)
    
    -- TODO Phase 2: Téléporter à la base assignée
    -- BaseSystem:SpawnPlayerAtBase(player)
end

--[[
    Appelé quand un joueur meurt
    @param player: Player
]]
function PlayerService:OnPlayerDied(player)
    print("[PlayerService] Joueur mort: " .. player.Name)
    
    -- Vider les pièces en main (elles sont perdues)
    local runtimeData = self._runtimeData[player.UserId]
    if runtimeData then
        local lostPieces = #runtimeData.PiecesInHand
        runtimeData.PiecesInHand = {}
        
        if lostPieces > 0 then
            print("[PlayerService] " .. player.Name .. " a perdu " .. lostPieces .. " pièces")
            
            -- Envoyer notification au client
            local remotes = NetworkSetup:GetAllRemotes()
            if remotes.SyncInventory then
                remotes.SyncInventory:FireClient(player, {})
            end
            if remotes.Notification then
                remotes.Notification:FireClient(player, {
                    Type = "Warning",
                    Message = "Vous êtes mort! " .. lostPieces .. " pièce(s) perdue(s).",
                    Duration = 3,
                })
            end
        end
    end
    
    -- Incrémenter les stats de mort
    DataService:IncrementValue(player, "Stats.TotalDeaths", 1)
end

--[[
    Récupère les données runtime d'un joueur
    @param player: Player
    @return RuntimeData | nil
]]
function PlayerService:GetRuntimeData(player)
    return self._runtimeData[player.UserId]
end

--[[
    Ajoute une pièce à l'inventaire runtime du joueur
    @param player: Player
    @param pieceData: table - {SetName, PieceType, Price, DisplayName}
    @return boolean
]]
function PlayerService:AddPieceToHand(player, pieceData)
    local runtimeData = self._runtimeData[player.UserId]
    if not runtimeData then return false end
    
    table.insert(runtimeData.PiecesInHand, pieceData)
    return true
end

--[[
    Vide les pièces en main d'un joueur
    @param player: Player
    @return table - Les pièces retirées
]]
function PlayerService:ClearPiecesInHand(player)
    local runtimeData = self._runtimeData[player.UserId]
    if not runtimeData then return {} end
    
    local pieces = runtimeData.PiecesInHand
    runtimeData.PiecesInHand = {}
    return pieces
end

--[[
    Récupère les pièces en main d'un joueur
    @param player: Player
    @return table
]]
function PlayerService:GetPiecesInHand(player)
    local runtimeData = self._runtimeData[player.UserId]
    if not runtimeData then return {} end
    
    return runtimeData.PiecesInHand
end

return PlayerService
```

### Tests de Validation A1.2
- [ ] Le module se charge sans erreur
- [ ] `PlayerService:Init()` s'exécute sans crash
- [ ] Quand un joueur rejoint, les logs s'affichent
- [ ] Les données runtime sont créées

---

## A1.3 - GameServer.server.lua

### Description
Point d'entrée principal du serveur, initialise tous les systèmes.

### Dépendances
- `NetworkSetup`
- `DataService` (A1.1)
- `PlayerService` (A1.2)

### Fichier : `ServerScriptService/Core/GameServer.server.lua`

```lua
--[[
    GameServer.lua
    Point d'entrée principal du serveur
    
    Ce script initialise tous les services et systèmes dans le bon ordre
    C'est LE SEUL Script (pas ModuleScript) côté serveur
]]

print("═══════════════════════════════════════════════")
print("   BRAINROT GAME - Démarrage du serveur")
print("═══════════════════════════════════════════════")

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ═══════════════════════════════════════════════════════
-- PHASE 1 : Charger les modules Core
-- ═══════════════════════════════════════════════════════

local Core = ServerScriptService:WaitForChild("Core")

-- NetworkSetup DOIT être initialisé en premier (crée les Remotes)
local NetworkSetup = require(Core:WaitForChild("NetworkSetup"))

-- Services Core
local DataService = require(Core:WaitForChild("DataService"))
local PlayerService = require(Core:WaitForChild("PlayerService"))

-- ═══════════════════════════════════════════════════════
-- PHASE 2 : Charger les handlers (sera ajouté plus tard)
-- ═══════════════════════════════════════════════════════

-- local Handlers = ServerScriptService:WaitForChild("Handlers")
-- local NetworkHandler = require(Handlers:WaitForChild("NetworkHandler"))

-- ═══════════════════════════════════════════════════════
-- PHASE 3 : Charger les systèmes (sera ajouté plus tard)
-- ═══════════════════════════════════════════════════════

-- local Systems = ServerScriptService:WaitForChild("Systems")
-- local BaseSystem = require(Systems:WaitForChild("BaseSystem"))
-- local EconomySystem = require(Systems:WaitForChild("EconomySystem"))
-- ...

-- ═══════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════

print("[GameServer] Initialisation des services...")

-- 1. NetworkSetup (crée les RemoteEvents/Functions)
local remotesFolder = NetworkSetup:Init()
print("[GameServer] NetworkSetup: OK")

-- 2. DataService (gestion DataStore)
DataService:Init()
print("[GameServer] DataService: OK")

-- 3. PlayerService (gestion connexion/déconnexion)
PlayerService:Init({
    DataService = DataService,
    NetworkSetup = NetworkSetup,
})
print("[GameServer] PlayerService: OK")

-- 4. NetworkHandler (sera ajouté en Phase 1.4)
-- NetworkHandler:Init({...})

-- 5. Systèmes de jeu (sera ajouté en Phase 2+)
-- BaseSystem:Init({...})
-- EconomySystem:Init({...})
-- ...

-- ═══════════════════════════════════════════════════════
-- TERMINÉ
-- ═══════════════════════════════════════════════════════

print("═══════════════════════════════════════════════")
print("   BRAINROT GAME - Serveur prêt!")
print("═══════════════════════════════════════════════")
```

### Tests de Validation A1.3
- [ ] Le serveur démarre sans erreur
- [ ] Tous les messages "OK" s'affichent
- [ ] Les Remotes sont créés dans ReplicatedStorage/Remotes
- [ ] Quand un joueur rejoint, ses données sont chargées

---

## A1.4 - NetworkHandler.module.lua

### Description
Gère tous les RemoteEvents entrants du client.

### Dépendances
- `NetworkSetup`
- `DataService` (A1.1)
- `PlayerService` (A1.2)
- `ReplicatedStorage/Shared/Constants`

### Fichier : `ServerScriptService/Handlers/NetworkHandler.module.lua`

**Note:** Créer le dossier `Handlers` dans `ServerScriptService` s'il n'existe pas.

```lua
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
local Constants = require(Shared:WaitForChild("Constants"))

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
```

### Mise à jour de GameServer.server.lua

Après avoir créé NetworkHandler, mettre à jour `GameServer.server.lua` :

```lua
-- Ajouter après les require existants:
local Handlers = ServerScriptService:WaitForChild("Handlers")
local NetworkHandler = require(Handlers:WaitForChild("NetworkHandler"))

-- Ajouter dans la section INITIALISATION (après PlayerService):
-- 4. NetworkHandler
NetworkHandler:Init({
    NetworkSetup = NetworkSetup,
    DataService = DataService,
    PlayerService = PlayerService,
})
print("[GameServer] NetworkHandler: OK")
```

### Tests de Validation A1.4
- [ ] Le dossier `Handlers` existe dans `ServerScriptService`
- [ ] `NetworkHandler` se charge sans erreur
- [ ] Les logs des handlers s'affichent quand on teste

---

# DEV B - CLIENT CORE

## Résumé des Tâches

| # | Tâche | Dépendance | Fichier à créer |
|---|-------|------------|-----------------|
| B1.1 | 🟢 MainHUD ScreenGui | Aucune | `StarterGui/MainHUD` (dans Studio) |
| B1.2 | 🟢 NotificationUI ScreenGui | Aucune | `StarterGui/NotificationUI` (dans Studio) |
| B1.3 | 🟡 UIController | B1.1, B1.2 | `StarterPlayerScripts/UIController.client.lua` |
| B1.4 | 🟡 ClientMain | B1.3 | `StarterPlayerScripts/ClientMain.client.lua` |

---

## B1.1 - MainHUD ScreenGui

### Description
Interface principale affichant l'argent, les pièces en main, etc.

### Création dans Roblox Studio

1. Dans **StarterGui**, créer un **ScreenGui**
2. Renommer en `MainHUD`
3. Propriétés :
   - `ResetOnSpawn` = false
   - `IgnoreGuiInset` = false

### Structure du MainHUD

```
MainHUD (ScreenGui)
├── TopBar (Frame)
│   ├── CashDisplay (Frame)
│   │   ├── CashIcon (ImageLabel)
│   │   └── CashLabel (TextLabel)
│   └── SlotCashDisplay (Frame)
│       ├── SlotCashIcon (ImageLabel)
│       └── SlotCashLabel (TextLabel)
│
├── InventoryDisplay (Frame)
│   ├── Title (TextLabel)
│   ├── Slot1 (Frame)
│   │   ├── Icon (ImageLabel)
│   │   └── Label (TextLabel)
│   ├── Slot2 (Frame)
│   │   ├── Icon (ImageLabel)
│   │   └── Label (TextLabel)
│   └── Slot3 (Frame)
│       ├── Icon (ImageLabel)
│       └── Label (TextLabel)
│
└── CraftButton (TextButton)
```

### Détails des éléments

#### TopBar (Frame)
| Propriété | Valeur |
|-----------|--------|
| Name | `TopBar` |
| Size | UDim2.new(1, 0, 0, 50) |
| Position | UDim2.new(0, 0, 0, 0) |
| BackgroundColor3 | (30, 30, 30) |
| BackgroundTransparency | 0.3 |
| BorderSizePixel | 0 |

#### CashDisplay (Frame)
| Propriété | Valeur |
|-----------|--------|
| Name | `CashDisplay` |
| Size | UDim2.new(0, 200, 0, 40) |
| Position | UDim2.new(0, 10, 0.5, -20) |
| BackgroundColor3 | (50, 50, 50) |
| BackgroundTransparency | 0.5 |
| BorderSizePixel | 0 |

#### CashLabel (TextLabel dans CashDisplay)
| Propriété | Valeur |
|-----------|--------|
| Name | `CashLabel` |
| Size | UDim2.new(0.8, 0, 1, 0) |
| Position | UDim2.new(0.2, 0, 0, 0) |
| BackgroundTransparency | 1 |
| Text | `$100` |
| TextColor3 | (0, 255, 100) vert |
| TextScaled | true |
| Font | GothamBold |
| TextXAlignment | Left |

#### SlotCashDisplay (Frame)
| Propriété | Valeur |
|-----------|--------|
| Name | `SlotCashDisplay` |
| Size | UDim2.new(0, 200, 0, 40) |
| Position | UDim2.new(0, 220, 0.5, -20) |
| BackgroundColor3 | (50, 50, 50) |
| BackgroundTransparency | 0.5 |
| BorderSizePixel | 0 |

#### SlotCashLabel (TextLabel dans SlotCashDisplay)
| Propriété | Valeur |
|-----------|--------|
| Name | `SlotCashLabel` |
| Size | UDim2.new(0.8, 0, 1, 0) |
| Position | UDim2.new(0.2, 0, 0, 0) |
| BackgroundTransparency | 1 |
| Text | `Slots: $0` |
| TextColor3 | (255, 215, 0) or |
| TextScaled | true |
| Font | GothamBold |
| TextXAlignment | Left |

#### InventoryDisplay (Frame)
| Propriété | Valeur |
|-----------|--------|
| Name | `InventoryDisplay` |
| Size | UDim2.new(0, 250, 0, 150) |
| Position | UDim2.new(1, -260, 1, -160) |
| AnchorPoint | (0, 0) |
| BackgroundColor3 | (40, 40, 40) |
| BackgroundTransparency | 0.3 |
| BorderSizePixel | 0 |

#### Title (TextLabel dans InventoryDisplay)
| Propriété | Valeur |
|-----------|--------|
| Name | `Title` |
| Size | UDim2.new(1, 0, 0, 30) |
| Position | UDim2.new(0, 0, 0, 0) |
| BackgroundTransparency | 1 |
| Text | `Pièces en main (0/3)` |
| TextColor3 | (255, 255, 255) |
| TextScaled | true |
| Font | GothamBold |

#### Slot1, Slot2, Slot3 (Frames dans InventoryDisplay)
| Propriété | Valeur |
|-----------|--------|
| Name | `Slot1` / `Slot2` / `Slot3` |
| Size | UDim2.new(0.3, 0, 0, 80) |
| Position | Slot1: (0.02, 0, 0, 35), Slot2: (0.35, 0, 0, 35), Slot3: (0.68, 0, 0, 35) |
| BackgroundColor3 | (60, 60, 60) |
| BackgroundTransparency | 0.5 |
| BorderSizePixel | 2 |
| BorderColor3 | (100, 100, 100) |

#### Label (TextLabel dans chaque Slot)
| Propriété | Valeur |
|-----------|--------|
| Name | `Label` |
| Size | UDim2.new(1, 0, 0.4, 0) |
| Position | UDim2.new(0, 0, 0.6, 0) |
| BackgroundTransparency | 1 |
| Text | `Vide` |
| TextColor3 | (150, 150, 150) |
| TextScaled | true |
| Font | Gotham |

#### CraftButton (TextButton)
| Propriété | Valeur |
|-----------|--------|
| Name | `CraftButton` |
| Size | UDim2.new(0, 200, 0, 50) |
| Position | UDim2.new(0.5, -100, 1, -70) |
| BackgroundColor3 | (0, 150, 0) |
| BorderSizePixel | 0 |
| Text | `CRAFT` |
| TextColor3 | (255, 255, 255) |
| TextScaled | true |
| Font | GothamBold |
| Visible | false |

### Coins arrondis (UICorner)
Ajouter un **UICorner** avec `CornerRadius = UDim.new(0, 8)` à :
- TopBar
- CashDisplay
- SlotCashDisplay
- InventoryDisplay
- Slot1, Slot2, Slot3
- CraftButton

---

## B1.2 - NotificationUI ScreenGui

### Description
Système de notifications toast.

### Création dans Roblox Studio

1. Dans **StarterGui**, créer un **ScreenGui**
2. Renommer en `NotificationUI`
3. Propriétés :
   - `ResetOnSpawn` = false
   - `IgnoreGuiInset` = false
   - `DisplayOrder` = 10 (au-dessus des autres UI)

### Structure du NotificationUI

```
NotificationUI (ScreenGui)
├── Container (Frame)
│   └── Template (Frame)
│       ├── Icon (ImageLabel)
│       └── Message (TextLabel)
└── UIListLayout (dans Container)
```

### Détails des éléments

#### Container (Frame)
| Propriété | Valeur |
|-----------|--------|
| Name | `Container` |
| Size | UDim2.new(0, 400, 0, 300) |
| Position | UDim2.new(0.5, -200, 0, 100) |
| BackgroundTransparency | 1 |
| BorderSizePixel | 0 |
| ClipsDescendants | true |

#### UIListLayout (dans Container)
| Propriété | Valeur |
|-----------|--------|
| SortOrder | LayoutOrder |
| Padding | UDim.new(0, 10) |
| HorizontalAlignment | Center |
| VerticalAlignment | Top |

#### Template (Frame)
| Propriété | Valeur |
|-----------|--------|
| Name | `Template` |
| Size | UDim2.new(1, 0, 0, 60) |
| BackgroundColor3 | (50, 50, 50) |
| BackgroundTransparency | 0.2 |
| BorderSizePixel | 0 |
| Visible | false |
| LayoutOrder | 0 |

#### UICorner (dans Template)
| Propriété | Valeur |
|-----------|--------|
| CornerRadius | UDim.new(0, 10) |

#### Message (TextLabel dans Template)
| Propriété | Valeur |
|-----------|--------|
| Name | `Message` |
| Size | UDim2.new(0.85, 0, 1, 0) |
| Position | UDim2.new(0.15, 0, 0, 0) |
| BackgroundTransparency | 1 |
| Text | `Notification` |
| TextColor3 | (255, 255, 255) |
| TextScaled | true |
| Font | Gotham |
| TextXAlignment | Left |
| TextWrapped | true |

#### Icon (ImageLabel dans Template)
| Propriété | Valeur |
|-----------|--------|
| Name | `Icon` |
| Size | UDim2.new(0, 40, 0, 40) |
| Position | UDim2.new(0, 10, 0.5, -20) |
| BackgroundTransparency | 1 |
| Image | `` (sera défini par code) |
| ScaleType | Fit |

### Couleurs par type de notification (pour le code)

| Type | BackgroundColor3 | Icône |
|------|------------------|-------|
| Success | (0, 150, 0) vert | ✓ ou rbxassetid://... |
| Error | (200, 50, 50) rouge | ✗ |
| Warning | (200, 150, 0) orange | ⚠ |
| Info | (50, 100, 200) bleu | ℹ |

---

## B1.3 - UIController.client.lua

### Description
Gère toutes les mises à jour de l'UI.

### Dépendances
- MainHUD (B1.1)
- NotificationUI (B1.2)
- `ReplicatedStorage/Shared/Constants`

### Fichier : `StarterPlayerScripts/UIController.client.lua`

```lua
--[[
    UIController.lua (LocalScript)
    Gère toutes les mises à jour de l'UI
    
    Responsabilités:
    - Mettre à jour l'affichage (Cash, Slots, Inventaire)
    - Afficher les notifications
    - Gérer les animations UI
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

-- UI Elements
local mainHUD = playerGui:WaitForChild("MainHUD")
local notificationUI = playerGui:WaitForChild("NotificationUI")

-- MainHUD Elements
local topBar = mainHUD:WaitForChild("TopBar")
local cashDisplay = topBar:WaitForChild("CashDisplay")
local cashLabel = cashDisplay:WaitForChild("CashLabel")
local slotCashDisplay = topBar:WaitForChild("SlotCashDisplay")
local slotCashLabel = slotCashDisplay:WaitForChild("SlotCashLabel")

local inventoryDisplay = mainHUD:WaitForChild("InventoryDisplay")
local inventoryTitle = inventoryDisplay:WaitForChild("Title")
local craftButton = mainHUD:WaitForChild("CraftButton")

-- Slots d'inventaire
local inventorySlots = {
    inventoryDisplay:WaitForChild("Slot1"),
    inventoryDisplay:WaitForChild("Slot2"),
    inventoryDisplay:WaitForChild("Slot3"),
}

-- NotificationUI Elements
local notifContainer = notificationUI:WaitForChild("Container")
local notifTemplate = notifContainer:WaitForChild("Template")

-- État local
local currentPlayerData = {
    Cash = 0,
    OwnedSlots = 1,
    SlotCash = {},
    PiecesInHand = {},
}

local UIController = {}

-- Couleurs des notifications
local NOTIFICATION_COLORS = {
    Success = Color3.fromRGB(0, 150, 0),
    Error = Color3.fromRGB(200, 50, 50),
    Warning = Color3.fromRGB(200, 150, 0),
    Info = Color3.fromRGB(50, 100, 200),
}

-- Compteur pour LayoutOrder des notifications
local notificationCounter = 0

--[[
    Met à jour l'affichage de l'argent
    @param cash: number
]]
function UIController:UpdateCash(cash)
    currentPlayerData.Cash = cash
    cashLabel.Text = "$" .. self:FormatNumber(cash)
    
    -- Animation de pulse
    self:PulseElement(cashLabel)
end

--[[
    Met à jour l'affichage de l'argent stocké dans les slots
    @param slotCash: table - {[slotIndex] = amount}
]]
function UIController:UpdateSlotCash(slotCash)
    currentPlayerData.SlotCash = slotCash
    
    -- Calculer le total
    local total = 0
    for _, amount in pairs(slotCash) do
        total = total + amount
    end
    
    slotCashLabel.Text = "Slots: $" .. self:FormatNumber(total)
end

--[[
    Met à jour l'affichage de l'inventaire (pièces en main)
    @param pieces: table - Liste des PieceData
]]
function UIController:UpdateInventory(pieces)
    currentPlayerData.PiecesInHand = pieces
    
    -- Mettre à jour le titre
    inventoryTitle.Text = "Pièces en main (" .. #pieces .. "/3)"
    
    -- Mettre à jour chaque slot
    for i, slot in ipairs(inventorySlots) do
        local label = slot:WaitForChild("Label")
        local piece = pieces[i]
        
        if piece then
            -- Slot occupé
            label.Text = piece.DisplayName .. "\n" .. piece.PieceType
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            slot.BackgroundColor3 = self:GetRarityColor(piece.SetName)
            slot.BackgroundTransparency = 0.3
        else
            -- Slot vide
            label.Text = "Vide"
            label.TextColor3 = Color3.fromRGB(150, 150, 150)
            slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            slot.BackgroundTransparency = 0.5
        end
    end
    
    -- Afficher/masquer le bouton Craft
    craftButton.Visible = (#pieces >= 3)
    
    -- Si 3 pièces, vérifier si on a les 3 types
    if #pieces >= 3 then
        local hasHead = false
        local hasBody = false
        local hasLegs = false
        
        for _, piece in ipairs(pieces) do
            if piece.PieceType == Constants.PieceType.Head then hasHead = true end
            if piece.PieceType == Constants.PieceType.Body then hasBody = true end
            if piece.PieceType == Constants.PieceType.Legs then hasLegs = true end
        end
        
        if hasHead and hasBody and hasLegs then
            craftButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
            craftButton.Text = "CRAFT!"
        else
            craftButton.BackgroundColor3 = Color3.fromRGB(150, 150, 0)
            craftButton.Text = "Besoin 3 types"
        end
    end
end

--[[
    Met à jour toute l'UI avec les nouvelles données
    @param data: table - PlayerData complet ou partiel
]]
function UIController:UpdateAll(data)
    if data.Cash ~= nil then
        self:UpdateCash(data.Cash)
    end
    
    if data.SlotCash ~= nil then
        self:UpdateSlotCash(data.SlotCash)
    end
    
    if data.PiecesInHand ~= nil then
        self:UpdateInventory(data.PiecesInHand)
    end
    
    if data.OwnedSlots ~= nil then
        currentPlayerData.OwnedSlots = data.OwnedSlots
    end
    
    print("[UIController] UI mise à jour")
end

--[[
    Affiche une notification toast
    @param notifType: string - "Success" | "Error" | "Warning" | "Info"
    @param message: string
    @param duration: number (secondes, défaut 3)
]]
function UIController:ShowNotification(notifType, message, duration)
    duration = duration or 3
    
    -- Cloner le template
    local notif = notifTemplate:Clone()
    notif.Name = "Notification_" .. notificationCounter
    notif.Visible = true
    notif.LayoutOrder = notificationCounter
    notificationCounter = notificationCounter + 1
    
    -- Configurer le contenu
    local messageLabel = notif:WaitForChild("Message")
    messageLabel.Text = message
    
    -- Configurer la couleur
    local color = NOTIFICATION_COLORS[notifType] or NOTIFICATION_COLORS.Info
    notif.BackgroundColor3 = color
    
    -- Positionner hors écran (pour animation)
    notif.Position = UDim2.new(-1, 0, 0, 0)
    notif.Parent = notifContainer
    
    -- Animation d'entrée
    local tweenIn = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    })
    tweenIn:Play()
    
    -- Attendre la durée
    task.delay(duration, function()
        -- Animation de sortie
        local tweenOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1
        })
        tweenOut:Play()
        
        tweenOut.Completed:Wait()
        notif:Destroy()
    end)
    
    print("[UIController] Notification: [" .. notifType .. "] " .. message)
end

--[[
    Animation de pulse sur un élément
    @param element: GuiObject
]]
function UIController:PulseElement(element)
    local originalSize = element.Size
    
    local tweenBig = TweenService:Create(element, TweenInfo.new(0.1), {
        Size = UDim2.new(originalSize.X.Scale * 1.1, originalSize.X.Offset, originalSize.Y.Scale * 1.1, originalSize.Y.Offset)
    })
    
    local tweenNormal = TweenService:Create(element, TweenInfo.new(0.1), {
        Size = originalSize
    })
    
    tweenBig:Play()
    tweenBig.Completed:Wait()
    tweenNormal:Play()
end

--[[
    Formate un nombre avec séparateurs de milliers
    @param number: number
    @return string
]]
function UIController:FormatNumber(number)
    local formatted = tostring(math.floor(number))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

--[[
    Récupère la couleur de rareté d'un set
    @param setName: string
    @return Color3
]]
function UIController:GetRarityColor(setName)
    -- TODO: Récupérer depuis BrainrotData
    -- Pour l'instant, couleur par défaut
    return Color3.fromRGB(100, 100, 200)
end

--[[
    Récupère le bouton Craft pour y connecter des événements
    @return TextButton
]]
function UIController:GetCraftButton()
    return craftButton
end

--[[
    Récupère l'état actuel des données locales
    @return table
]]
function UIController:GetCurrentData()
    return currentPlayerData
end

return UIController
```

### Tests de Validation B1.3
- [ ] Le script se charge sans erreur
- [ ] Les références UI sont trouvées
- [ ] `UpdateCash(500)` change l'affichage
- [ ] `ShowNotification("Success", "Test")` affiche une notification

---

## B1.4 - ClientMain.client.lua

### Description
Point d'entrée principal du client, connecte les RemoteEvents.

### Dépendances
- UIController (B1.3)
- `ReplicatedStorage/Shared/Constants`

### Fichier : `StarterPlayerScripts/ClientMain.client.lua`

```lua
--[[
    ClientMain.lua (LocalScript)
    Point d'entrée principal du client
    
    Ce script initialise tous les contrôleurs et connecte les RemoteEvents
]]

print("═══════════════════════════════════════════════")
print("   BRAINROT GAME - Démarrage du client")
print("═══════════════════════════════════════════════")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

-- Contrôleurs (charger depuis le même dossier)
local UIController = require(script.Parent:WaitForChild("UIController"))

-- Attendre les Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ═══════════════════════════════════════════════════════
-- CONNEXION AUX REMOTES (Serveur → Client)
-- ═══════════════════════════════════════════════════════

-- SyncPlayerData: Reçoit les mises à jour des données joueur
local syncPlayerData = Remotes:WaitForChild("SyncPlayerData")
syncPlayerData.OnClientEvent:Connect(function(data)
    print("[ClientMain] SyncPlayerData reçu")
    UIController:UpdateAll(data)
end)

-- SyncInventory: Reçoit les mises à jour de l'inventaire (pièces en main)
local syncInventory = Remotes:WaitForChild("SyncInventory")
syncInventory.OnClientEvent:Connect(function(pieces)
    print("[ClientMain] SyncInventory reçu (" .. #pieces .. " pièces)")
    UIController:UpdateInventory(pieces)
end)

-- Notification: Reçoit les notifications à afficher
local notification = Remotes:WaitForChild("Notification")
notification.OnClientEvent:Connect(function(data)
    print("[ClientMain] Notification reçue: " .. data.Type .. " - " .. data.Message)
    UIController:ShowNotification(data.Type, data.Message, data.Duration)
end)

-- SyncCodex: Reçoit les mises à jour du Codex (Phase 6)
local syncCodex = Remotes:WaitForChild("SyncCodex")
syncCodex.OnClientEvent:Connect(function(data)
    print("[ClientMain] SyncCodex reçu")
    -- TODO Phase 6: CodexController:UpdateCodex(data)
end)

-- SyncDoorState: Reçoit les mises à jour de l'état de la porte (Phase 2)
local syncDoorState = Remotes:WaitForChild("SyncDoorState")
syncDoorState.OnClientEvent:Connect(function(data)
    print("[ClientMain] SyncDoorState reçu: " .. data.State)
    -- TODO Phase 2: DoorController:UpdateDoorState(data)
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
        print("[ClientMain] Bouton Craft cliqué")
        craft:FireServer()
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
    print("[ClientMain] Requête pickup: " .. pieceId)
    pickupPiece:FireServer(pieceId)
end

--[[
    Envoie une requête de craft au serveur
]]
function ClientMain:RequestCraft()
    print("[ClientMain] Requête craft")
    craft:FireServer()
end

--[[
    Envoie une requête d'achat de slot au serveur
]]
function ClientMain:RequestBuySlot()
    print("[ClientMain] Requête achat slot")
    buySlot:FireServer()
end

--[[
    Envoie une requête d'activation de porte au serveur
]]
function ClientMain:RequestActivateDoor()
    print("[ClientMain] Requête activation porte")
    activateDoor:FireServer()
end

--[[
    Envoie une requête pour lâcher les pièces
]]
function ClientMain:RequestDropPieces()
    print("[ClientMain] Requête drop pièces")
    dropPieces:FireServer()
end

--[[
    Envoie une requête de collecte d'argent de slot
    @param slotIndex: number
]]
function ClientMain:RequestCollectSlotCash(slotIndex)
    print("[ClientMain] Requête collecte slot " .. slotIndex)
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
    
    print("[ClientMain] Demande des données initiales...")
    local fullData = ClientMain:GetFullPlayerData()
    
    if fullData then
        print("[ClientMain] Données reçues, mise à jour UI")
        UIController:UpdateAll(fullData)
    else
        warn("[ClientMain] Pas de données reçues du serveur")
    end
end)

-- ═══════════════════════════════════════════════════════
-- TERMINÉ
-- ═══════════════════════════════════════════════════════

print("═══════════════════════════════════════════════")
print("   BRAINROT GAME - Client prêt!")
print("═══════════════════════════════════════════════")

-- Exporter le module (optionnel, pour les autres scripts qui auraient besoin)
return ClientMain
```

### Tests de Validation B1.4
- [ ] Le client démarre sans erreur
- [ ] Les messages "Client prêt!" s'affichent
- [ ] L'UI se met à jour avec les données du serveur
- [ ] Le bouton Craft envoie une requête au serveur

---

# POINT DE SYNCHRONISATION 1

## Test d'Intégration

### Prérequis
- DEV A a terminé A1.1, A1.2, A1.3, A1.4
- DEV B a terminé B1.1, B1.2, B1.3, B1.4

### Tests à Effectuer

1. **Test de Connexion**
   - [ ] Lancer le jeu en Play Solo
   - [ ] Vérifier les messages serveur dans Output :
     ```
     [NetworkSetup] Tous les Remotes sont prêts!
     [DataService] Initialisé!
     [PlayerService] Initialisé!
     [NetworkHandler] Initialisé!
     [GameServer] Serveur prêt!
     ```
   - [ ] Vérifier les messages client dans Output :
     ```
     [ClientMain] Client prêt!
     [ClientMain] Données reçues, mise à jour UI
     ```

2. **Test UI**
   - [ ] L'argent s'affiche ($100 par défaut)
   - [ ] L'inventaire affiche "Pièces en main (0/3)"
   - [ ] Le bouton Craft est masqué

3. **Test Notifications**
   - [ ] Cliquer sur le bouton Craft (via code ou bouton test)
   - [ ] Une notification s'affiche "Craft non implémenté (Phase 5)"

4. **Test Sauvegarde**
   - [ ] Modifier les données manuellement via console serveur :
     ```lua
     local DataService = require(game.ServerScriptService.Core.DataService)
     local player = game.Players:GetPlayers()[1]
     DataService:IncrementValue(player, "Cash", 500)
     ```
   - [ ] Quitter et relancer le jeu
   - [ ] Vérifier que l'argent est sauvegardé (si DataStore activé)

---

# RÉCAPITULATIF DES FICHIERS

## DEV A - Backend

| Fichier | Emplacement |
|---------|-------------|
| `DataService.module.lua` | `ServerScriptService/Core/` |
| `PlayerService.module.lua` | `ServerScriptService/Core/` |
| `GameServer.server.lua` | `ServerScriptService/Core/` |
| `NetworkHandler.module.lua` | `ServerScriptService/Handlers/` |

## DEV B - Frontend

| Fichier | Emplacement |
|---------|-------------|
| `MainHUD` (ScreenGui) | `StarterGui/` |
| `NotificationUI` (ScreenGui) | `StarterGui/` |
| `UIController.client.lua` | `StarterPlayerScripts/` |
| `ClientMain.client.lua` | `StarterPlayerScripts/` |

---

# DIAGRAMME DE DÉPENDANCES

```
PHASE 0 (Existant)
    │
    ├── GameConfig ────────────────┐
    ├── Constants ─────────────────┤
    ├── DefaultPlayerData ─────────┤
    └── NetworkSetup ──────────────┤
                                   │
                                   ▼
    ┌──────────────────────────────────────────────────┐
    │                    PHASE 1                        │
    │                                                  │
    │  DEV A                          DEV B            │
    │  ─────                          ─────            │
    │                                                  │
    │  A1.1 DataService               B1.1 MainHUD    │
    │       │                              │           │
    │       ▼                              │           │
    │  A1.2 PlayerService             B1.2 NotificationUI
    │       │                              │           │
    │       ▼                              ▼           │
    │  A1.3 GameServer               B1.3 UIController │
    │       │                              │           │
    │       ▼                              ▼           │
    │  A1.4 NetworkHandler           B1.4 ClientMain  │
    │                                                  │
    └──────────────────────────────────────────────────┘
                        │
                        ▼
                   🔄 SYNC 1
                   Test d'intégration
```

---

# PROCHAINE ÉTAPE : PHASE 2

Après validation de la Phase 1, passer à la Phase 2 :
- **DEV A** : BaseSystem, DoorSystem
- **DEV B** : Setup Bases Studio, BaseController

---

**Fin du Guide Phase 1**
