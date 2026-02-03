# Steal a Brainrot - Documentation Technique Complète

## 🎉 Phase 1 DEV A - COMPLÉTÉE!

**Date:** 2026-02-02  
**Status:** Backend Core Systems ✅ OPÉRATIONNEL

### Dernières Mises à Jour
- ✅ DataService avec auto-save (60s)
- ✅ PlayerService avec gestion connexion/déconnexion
- ✅ GameServer (point d'entrée)
- ✅ NetworkHandler (12 RemoteEvents/Functions)
- ✅ Mode hors-ligne pour Studio
- ✅ Tests validés

**→ [Voir le résumé Phase 1](PHASE_1_SUMMARY.md)**  
**→ [Guide d'import](GamePlace/IMPORT_GUIDE.md)**  
**→ [Documentation complète](GamePlace/INDEX.md)**

---

## Vue d'ensemble

Jeu Roblox de type tycoon/collecte où les joueurs récupèrent des pièces de Brainrot dans une arène, les fusionnent pour créer des monstres chimériques, et les placent dans leur base pour générer des revenus passifs.

---

# PARTIE 1 : ARCHITECTURE

## Structure du Projet

```
GamePlace/
├── ReplicatedStorage/
│   ├── Config/
│   │   ├── GameConfig.lua          -- Constantes gameplay
│   │   └── FeatureFlags.lua        -- Activer/désactiver features
│   │
│   ├── Data/
│   │   ├── BrainrotData.lua        -- Registry des sets
│   │   └── SlotPrices.lua          -- Prix des slots
│   │
│   ├── Shared/
│   │   ├── Constants.lua           -- Enums partagés
│   │   └── Utils.lua               -- Fonctions utilitaires
│   │
│   └── Network/
│       └── Remotes/                -- Dossier contenant les RemoteEvents/Functions
│
├── ServerScriptService/
│   ├── Core/
│   │   ├── GameServer.lua          -- Point d'entrée serveur
│   │   ├── PlayerService.lua       -- Connexion/déconnexion
│   │   └── DataService.lua         -- DataStore
│   │
│   ├── Systems/
│   │   ├── BaseSystem.lua          -- Gestion des bases
│   │   ├── DoorSystem.lua          -- Portes sécurisées
│   │   ├── EconomySystem.lua       -- Argent
│   │   ├── ArenaSystem.lua         -- Spawn pièces
│   │   ├── InventorySystem.lua     -- Pièces en main
│   │   ├── CraftingSystem.lua      -- Fusion
│   │   └── CodexSystem.lua         -- Collection
│   │
│   └── Handlers/
│       └── NetworkHandler.lua      -- Gestion RemoteEvents
│
├── StarterPlayerScripts/
│   ├── ClientMain.lua              -- Point d'entrée client
│   ├── InputController.lua         -- Inputs joueur
│   ├── BaseController.lua          -- Interactions base
│   ├── ArenaController.lua         -- Interactions arène
│   └── UIController.lua            -- Gestion UI
│
└── StarterGui/
    ├── MainHUD/                    -- HUD principal
    ├── CodexUI/                    -- Interface collection
    ├── ShopUI/                     -- Achat slots
    └── NotificationUI/             -- Notifications
```

---

## Principes d'Architecture

### 1. Séparation Client/Serveur

```
CLIENT                              SERVEUR
───────                             ───────
Détecte les inputs          →       Valide TOUT
Envoie des requêtes         →       Exécute la logique
Affiche les résultats       ←       Envoie les mises à jour
Ne fait JAMAIS confiance    →       Source de vérité unique
```

### 2. Flux de Communication

```
[Client] Input utilisateur
    │
    ▼
[Client] Envoie RemoteEvent avec données minimales
    │
    ▼
[Serveur] NetworkHandler reçoit
    │
    ▼
[Serveur] Appelle le System approprié
    │
    ▼
[Serveur] System valide + exécute
    │
    ▼
[Serveur] Fire RemoteEvent de sync vers client(s)
    │
    ▼
[Client] UIController met à jour l'affichage
```

---

# PARTIE 2 : SPÉCIFICATIONS DES DONNÉES

## GameConfig.lua

```lua
local GameConfig = {
    -- ═══════════════════════════════════════
    -- ÉCONOMIE
    -- ═══════════════════════════════════════
    Economy = {
        StartingCash = 100,                 -- Argent de départ nouveau joueur
        RevenuePerBrainrot = 5,             -- $ par seconde par Brainrot placé
        RevenueTickRate = 1,                -- Intervalle en secondes
        SetCompletionBonus = 1000,          -- Bonus pour compléter un set
    },
    
    -- ═══════════════════════════════════════
    -- BASE
    -- ═══════════════════════════════════════
    Base = {
        MaxSlots = 30,                      -- Maximum de slots achetables
        SlotsPerFloor = 10,                 -- Slots par étage
        StartingSlots = 1,                  -- Slots au départ
        
        -- Étages débloqués automatiquement
        FloorUnlockThresholds = {
            [1] = 11,                       -- Floor_1 à 11 slots
            [2] = 21,                       -- Floor_2 à 21 slots
        },
    },
    
    -- ═══════════════════════════════════════
    -- PORTE
    -- ═══════════════════════════════════════
    Door = {
        CloseDuration = 30,                 -- Durée fermeture en secondes
        CooldownAfterOpen = 0,              -- Cooldown après ouverture (0 = immédiat)
    },
    
    -- ═══════════════════════════════════════
    -- ARÈNE
    -- ═══════════════════════════════════════
    Arena = {
        SpawnInterval = 3,                  -- Secondes entre chaque spawn
        MaxPiecesInArena = 50,              -- Limite de pièces simultanées
        PieceLifetime = 120,                -- Secondes avant despawn auto
        SpinnerSpeed = 2,                   -- Tours par seconde
    },
    
    -- ═══════════════════════════════════════
    -- INVENTAIRE JOUEUR (pièces en main)
    -- ═══════════════════════════════════════
    Inventory = {
        MaxPiecesInHand = 3,                -- Maximum de pièces portables
    },
    
    -- ═══════════════════════════════════════
    -- DATASTORE
    -- ═══════════════════════════════════════
    DataStore = {
        Name = "BrainrotGameData_v1",       -- Nom du DataStore
        AutoSaveInterval = 60,              -- Secondes entre auto-saves
        RetryAttempts = 3,                  -- Tentatives en cas d'échec
        RetryDelay = 2,                     -- Secondes entre tentatives
    },
}

return GameConfig
```

---

## SlotPrices.lua

```lua
-- Prix pour acheter le slot N (index = numéro du slot)
local SlotPrices = {
    [1] = 0,        -- Slot 1 gratuit (déjà possédé)
    [2] = 100,
    [3] = 150,
    [4] = 200,
    [5] = 275,
    [6] = 350,
    [7] = 450,
    [8] = 575,
    [9] = 700,
    [10] = 850,     -- Fin rez-de-chaussée
    [11] = 1000,    -- Début 1er étage
    [12] = 1200,
    [13] = 1400,
    [14] = 1650,
    [15] = 1900,
    [16] = 2200,
    [17] = 2500,
    [18] = 2850,
    [19] = 3200,
    [20] = 3600,    -- Fin 1er étage
    [21] = 4000,    -- Début 2ème étage
    [22] = 4500,
    [23] = 5000,
    [24] = 5600,
    [25] = 6200,
    [26] = 6900,
    [27] = 7600,
    [28] = 8400,
    [29] = 9200,
    [30] = 10000,   -- Dernier slot
}

return SlotPrices
```

---

## BrainrotData.lua

```lua
local BrainrotData = {
    -- ═══════════════════════════════════════
    -- SETS DE BRAINROTS
    -- ═══════════════════════════════════════
    Sets = {
        ["Skibidi"] = {
            Rarity = "Common",
            Head = {
                Price = 50,
                DisplayName = "Skibidi",
                ModelName = "Skibidi_Head",     -- Nom dans ReplicatedStorage/Assets/Pieces
                SpawnWeight = 10,               -- Probabilité relative de spawn
            },
            Body = {
                Price = 75,
                DisplayName = "Skibidi",
                ModelName = "Skibidi_Body",
                SpawnWeight = 10,
            },
            Legs = {
                Price = 60,
                DisplayName = "Skibidi",
                ModelName = "Skibidi_Legs",
                SpawnWeight = 10,
            },
        },
        
        ["Rizz"] = {
            Rarity = "Common",
            Head = {
                Price = 80,
                DisplayName = "Rizz",
                ModelName = "Rizz_Head",
                SpawnWeight = 10,
            },
            Body = {
                Price = 100,
                DisplayName = "Rizz",
                ModelName = "Rizz_Body",
                SpawnWeight = 10,
            },
            Legs = {
                Price = 90,
                DisplayName = "Rizz",
                ModelName = "Rizz_Legs",
                SpawnWeight = 10,
            },
        },
        
        ["Fanum"] = {
            Rarity = "Rare",
            Head = {
                Price = 150,
                DisplayName = "Fanum",
                ModelName = "Fanum_Head",
                SpawnWeight = 5,                -- Plus rare
            },
            Body = {
                Price = 200,
                DisplayName = "Fanum",
                ModelName = "Fanum_Body",
                SpawnWeight = 5,
            },
            Legs = {
                Price = 175,
                DisplayName = "Fanum",
                ModelName = "Fanum_Legs",
                SpawnWeight = 5,
            },
        },
        
        ["Gyatt"] = {
            Rarity = "Epic",
            Head = {
                Price = 400,
                DisplayName = "Gyatt",
                ModelName = "Gyatt_Head",
                SpawnWeight = 2,
            },
            Body = {
                Price = 500,
                DisplayName = "Gyatt",
                ModelName = "Gyatt_Body",
                SpawnWeight = 2,
            },
            Legs = {
                Price = 450,
                DisplayName = "Gyatt",
                ModelName = "Gyatt_Legs",
                SpawnWeight = 2,
            },
        },
    },
    
    -- ═══════════════════════════════════════
    -- RARETÉS
    -- ═══════════════════════════════════════
    Rarities = {
        Common = {
            Color = Color3.fromRGB(255, 255, 255),  -- Blanc
            BonusMultiplier = 1,
            DisplayOrder = 1,
        },
        Rare = {
            Color = Color3.fromRGB(0, 112, 221),    -- Bleu
            BonusMultiplier = 2,
            DisplayOrder = 2,
        },
        Epic = {
            Color = Color3.fromRGB(163, 53, 238),   -- Violet
            BonusMultiplier = 5,
            DisplayOrder = 3,
        },
        Legendary = {
            Color = Color3.fromRGB(255, 185, 0),    -- Or
            BonusMultiplier = 10,
            DisplayOrder = 4,
        },
    },
    
    -- ═══════════════════════════════════════
    -- TYPES DE PIÈCES
    -- ═══════════════════════════════════════
    PieceTypes = {"Head", "Body", "Legs"},
}

return BrainrotData
```

---

## Constants.lua

```lua
local Constants = {
    -- ═══════════════════════════════════════
    -- ÉTATS DE LA PORTE
    -- ═══════════════════════════════════════
    DoorState = {
        Open = "Open",
        Closed = "Closed",
    },
    
    -- ═══════════════════════════════════════
    -- TYPES DE PIÈCES
    -- ═══════════════════════════════════════
    PieceType = {
        Head = "Head",
        Body = "Body",
        Legs = "Legs",
    },
    
    -- ═══════════════════════════════════════
    -- RÉSULTATS D'ACTIONS
    -- ═══════════════════════════════════════
    ActionResult = {
        Success = "Success",
        NotEnoughMoney = "NotEnoughMoney",
        NoSlotAvailable = "NoSlotAvailable",
        InventoryFull = "InventoryFull",
        InvalidPiece = "InvalidPiece",
        MissingPieces = "MissingPieces",
        AlreadyOwned = "AlreadyOwned",
        MaxSlotsReached = "MaxSlotsReached",
        OnCooldown = "OnCooldown",
        NotOwner = "NotOwner",
    },
    
    -- ═══════════════════════════════════════
    -- COLLISION GROUPS
    -- ═══════════════════════════════════════
    CollisionGroup = {
        Default = "Default",
        Players = "Players",
        DoorBars = "DoorBars",
        Pieces = "Pieces",
    },
    
    -- ═══════════════════════════════════════
    -- NOMS DES REMOTES
    -- ═══════════════════════════════════════
    RemoteNames = {
        -- Client → Serveur
        PickupPiece = "PickupPiece",
        DropPieces = "DropPieces",
        Craft = "Craft",
        BuySlot = "BuySlot",
        CollectSlotCash = "CollectSlotCash",  -- slotIndex en paramètre
        ActivateDoor = "ActivateDoor",
        
        -- Serveur → Client
        SyncPlayerData = "SyncPlayerData",
        SyncInventory = "SyncInventory",
        SyncCodex = "SyncCodex",
        SyncDoorState = "SyncDoorState",
        Notification = "Notification",
        
        -- RemoteFunctions
        GetFullPlayerData = "GetFullPlayerData",
    },
    
    -- ═══════════════════════════════════════
    -- NOMS WORKSPACE
    -- ═══════════════════════════════════════
    WorkspaceNames = {
        BasesFolder = "Bases",
        ArenaFolder = "Arena",
        PiecesFolder = "ActivePieces",
        
        -- Dans une Base
        SpawnPoint = "SpawnPoint",
        SlotsFolder = "Slots",
        DoorFolder = "Door",
        DoorBars = "Bars",
        DoorPad = "ActivationPad",
        SlotShop = "SlotShop",
        SlotShopSign = "Sign",        -- Le panneau avec ProximityPrompt
        SlotShopDisplay = "Display",  -- L'écran avec le prix
        FloorsFolder = "Floors",
        
        -- Dans un Slot
        SlotPlatform = "Platform",
        SlotCollectPad = "CollectPad",
        
        -- Dans l'Arène
        Canon = "Canon",
        Spinner = "Spinner",
        SpawnZone = "SpawnZone",
    },
}

return Constants
```

---

## Structure des Données Joueur (DataService)

```lua
-- Structure complète sauvegardée dans DataStore
local DEFAULT_PLAYER_DATA = {
    -- Version pour migrations futures
    Version = 1,
    
    -- ═══════════════════════════════════════
    -- ÉCONOMIE
    -- ═══════════════════════════════════════
    Cash = 100,                     -- Argent en poche (GameConfig.Economy.StartingCash)
    
    -- Argent stocké par slot (collecté en marchant sur CollectPad)
    -- Format: {[slotIndex] = amount}
    SlotCash = {},
    
    -- ═══════════════════════════════════════
    -- BASE
    -- ═══════════════════════════════════════
    OwnedSlots = 1,                 -- Nombre de slots possédés
    
    -- Brainrots placés sur les slots
    -- Format: {[slotIndex] = BrainrotData}
    PlacedBrainrots = {
        -- Exemple:
        -- [1] = {
        --     Name = "Skibidi Rizz Fanum",      -- Nom chimérique
        --     HeadSet = "Skibidi",              -- Set de la tête
        --     BodySet = "Rizz",                 -- Set du corps
        --     LegsSet = "Fanum",                -- Set des jambes
        --     CreatedAt = 1234567890,           -- Timestamp création
        -- }
    },
    
    -- ═══════════════════════════════════════
    -- CODEX (Collection)
    -- ═══════════════════════════════════════
    -- Liste des pièces débloquées
    -- Format: {"SetName_PieceType", ...}
    CodexUnlocked = {
        -- Exemple: {"Skibidi_Head", "Skibidi_Body", "Rizz_Legs"}
    },
    
    -- Sets complétés (pour éviter de donner la récompense 2 fois)
    CompletedSets = {
        -- Exemple: {"Skibidi"}
    },
    
    -- ═══════════════════════════════════════
    -- STATISTIQUES (pour futures features)
    -- ═══════════════════════════════════════
    Stats = {
        TotalCrafts = 0,            -- Nombre total de fusions
        TotalDeaths = 0,            -- Morts dans l'arène
        TotalCashEarned = 0,        -- Argent total gagné
        TotalPiecesCollected = 0,   -- Pièces ramassées au total
        PlayTime = 0,               -- Temps de jeu en secondes
    },
    
    -- ═══════════════════════════════════════
    -- RÉSERVÉ POUR FUTURES FEATURES
    -- ═══════════════════════════════════════
    Inventory = {},                 -- Items spéciaux
    Achievements = {},              -- Succès
    DailyData = {                   -- Données journalières
        LastLogin = 0,
        DailyStreak = 0,
    },
}
```

---

## Structure Données Runtime (non sauvegardées)

```lua
-- Données temporaires par joueur (en mémoire serveur uniquement)
local PlayerRuntimeData = {
    -- ═══════════════════════════════════════
    -- PIÈCES EN MAIN
    -- ═══════════════════════════════════════
    -- Format: Liste de PieceData
    PiecesInHand = {
        -- Exemple:
        -- {
        --     SetName = "Skibidi",
        --     PieceType = "Head",          -- "Head" | "Body" | "Legs"
        --     Price = 50,
        --     DisplayName = "Skibidi",
        -- }
    },
    
    -- ═══════════════════════════════════════
    -- BASE ASSIGNÉE
    -- ═══════════════════════════════════════
    AssignedBase = nil,             -- Référence à l'objet Base dans Workspace
    BaseIndex = nil,                -- Index de la base (1, 2, 3...)
    
    -- ═══════════════════════════════════════
    -- ÉTAT DE LA PORTE
    -- ═══════════════════════════════════════
    DoorState = "Open",             -- "Open" | "Closed"
    DoorCloseTime = 0,              -- Timestamp de fermeture
    DoorReopenTime = 0,             -- Timestamp de réouverture prévue
    
    -- ═══════════════════════════════════════
    -- SESSION
    -- ═══════════════════════════════════════
    JoinTime = 0,                   -- Timestamp de connexion
    LastSaveTime = 0,               -- Dernier auto-save
}
```

---

# PARTIE 3 : API DES MODULES

## DataService.lua

### Fonctions Publiques

```lua
--[[
    Initialise le service et configure le DataStore
    @return void
]]
function DataService:Init()

--[[
    Charge les données d'un joueur depuis le DataStore
    Applique les migrations si nécessaire
    Crée des données par défaut si nouveau joueur
    
    @param player: Player - Le joueur Roblox
    @return PlayerData | nil - Les données chargées, ou nil si échec
]]
function DataService:LoadPlayerData(player: Player): PlayerData?

--[[
    Sauvegarde les données d'un joueur dans le DataStore
    
    @param player: Player - Le joueur Roblox
    @return boolean - true si succès, false sinon
]]
function DataService:SavePlayerData(player: Player): boolean

--[[
    Récupère les données en cache d'un joueur (lecture seule)
    
    @param player: Player - Le joueur Roblox
    @return PlayerData | nil - Les données en cache
]]
function DataService:GetPlayerData(player: Player): PlayerData?

--[[
    Met à jour une valeur dans les données du joueur
    Ne sauvegarde PAS immédiatement (attendre auto-save ou SavePlayerData)
    
    @param player: Player - Le joueur Roblox
    @param key: string - Clé à modifier (ex: "Cash", "OwnedSlots")
    @param value: any - Nouvelle valeur
    @return boolean - true si succès
]]
function DataService:UpdateValue(player: Player, key: string, value: any): boolean

--[[
    Ajoute une valeur à un champ numérique
    
    @param player: Player
    @param key: string - Clé numérique (ex: "Cash")
    @param amount: number - Montant à ajouter (peut être négatif)
    @return number - Nouvelle valeur
]]
function DataService:IncrementValue(player: Player, key: string, amount: number): number
```

### Événements Internes

```lua
-- Appelé après chargement réussi des données
DataService.OnPlayerDataLoaded:Fire(player, playerData)

-- Appelé après sauvegarde réussie
DataService.OnPlayerDataSaved:Fire(player)

-- Appelé si échec de chargement/sauvegarde
DataService.OnDataError:Fire(player, errorMessage)
```

---

## PlayerService.lua

### Fonctions Publiques

```lua
--[[
    Initialise le service, connecte les événements de joueur
    @return void
]]
function PlayerService:Init()

--[[
    Appelé quand un joueur rejoint
    - Charge ses données via DataService
    - Lui assigne une base via BaseSystem
    - Initialise ses données runtime
    - Le téléporte à sa base
    
    @param player: Player
    @return void
]]
function PlayerService:OnPlayerJoin(player: Player)

--[[
    Appelé quand un joueur quitte
    - Sauvegarde ses données
    - Libère sa base
    - Nettoie ses données runtime
    
    @param player: Player
    @return void
]]
function PlayerService:OnPlayerLeave(player: Player)

--[[
    Récupère les données runtime d'un joueur
    
    @param player: Player
    @return RuntimeData | nil
]]
function PlayerService:GetRuntimeData(player: Player): RuntimeData?
```

---

## BaseSystem.lua

### Fonctions Publiques

```lua
--[[
    Initialise le système, prépare les bases dans Workspace
    @return void
]]
function BaseSystem:Init()

--[[
    Assigne une base libre à un joueur
    
    @param player: Player
    @return Model | nil - La base assignée, ou nil si aucune disponible
]]
function BaseSystem:AssignBase(player: Player): Model?

--[[
    Libère la base d'un joueur (quand il quitte)
    Nettoie les Brainrots visuels
    
    @param player: Player
    @return void
]]
function BaseSystem:ReleaseBase(player: Player)

--[[
    Récupère la base d'un joueur
    
    @param player: Player
    @return Model | nil
]]
function BaseSystem:GetPlayerBase(player: Player): Model?

--[[
    Téléporte le joueur à sa base
    
    @param player: Player
    @return boolean - true si succès
]]
function BaseSystem:SpawnPlayerAtBase(player: Player): boolean

--[[
    Récupère le premier slot libre dans la base d'un joueur
    
    @param player: Player
    @return number | nil - Index du slot libre, ou nil si tous occupés
]]
function BaseSystem:GetFirstFreeSlot(player: Player): number?

--[[
    Place un Brainrot sur un slot
    
    @param player: Player
    @param slotIndex: number - Index du slot (1-30)
    @param brainrotData: table - Données du Brainrot
    @return boolean - true si succès
]]
function BaseSystem:PlaceBrainrotOnSlot(player: Player, slotIndex: number, brainrotData: table): boolean

--[[
    Vérifie et débloque les étages si nécessaire
    
    @param player: Player
    @return number | nil - Numéro de l'étage débloqué, ou nil
]]
function BaseSystem:CheckFloorUnlock(player: Player): number?

--[[
    Compte le nombre de Brainrots placés dans la base
    
    @param player: Player
    @return number
]]
function BaseSystem:GetPlacedBrainrotCount(player: Player): number
```

---

## DoorSystem.lua

### Fonctions Publiques

```lua
--[[
    Initialise le système, configure les CollisionGroups
    @return void
]]
function DoorSystem:Init()

--[[
    Active la porte d'une base (la ferme)
    
    @param player: Player - Le propriétaire de la base
    @return ActionResult - Success, OnCooldown, ou NotOwner
]]
function DoorSystem:ActivateDoor(player: Player): string

--[[
    Récupère l'état actuel de la porte d'un joueur
    
    @param player: Player
    @return {state: string, remainingTime: number}
]]
function DoorSystem:GetDoorState(player: Player): {state: string, remainingTime: number}

--[[
    Vérifie si un joueur peut traverser une porte
    
    @param player: Player - Joueur qui veut traverser
    @param base: Model - La base avec la porte
    @return boolean - true si peut traverser (propriétaire ou porte ouverte)
]]
function DoorSystem:CanPlayerPass(player: Player, base: Model): boolean
```

### Configuration CollisionGroups

```lua
-- À exécuter une fois au démarrage du serveur
local PhysicsService = game:GetService("PhysicsService")

-- Créer les groupes
PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:RegisterCollisionGroup("DoorBars")

-- Par défaut, tout collisionne avec tout
-- On désactive collision DoorBars <-> Players du propriétaire dynamiquement
```

---

## EconomySystem.lua

### Fonctions Publiques

```lua
--[[
    Initialise le système, démarre la loop de revenus
    @return void
]]
function EconomySystem:Init()

--[[
    Ajoute de l'argent au portefeuille d'un joueur
    
    @param player: Player
    @param amount: number - Montant à ajouter
    @return number - Nouveau solde
]]
function EconomySystem:AddCash(player: Player, amount: number): number

--[[
    Retire de l'argent du portefeuille
    
    @param player: Player
    @param amount: number - Montant à retirer
    @return boolean - true si succès (avait assez)
]]
function EconomySystem:RemoveCash(player: Player, amount: number): boolean

--[[
    Vérifie si le joueur peut payer un montant
    
    @param player: Player
    @param amount: number
    @return boolean
]]
function EconomySystem:CanAfford(player: Player, amount: number): boolean

--[[
    Ajoute de l'argent au stockage de la base
    
    @param player: Player
    @param amount: number
    @return number - Nouveau montant stocké
]]
function EconomySystem:AddStoredCash(player: Player, amount: number): number

--[[
    Transfère l'argent stocké vers le portefeuille
    
    @param player: Player
    @return number - Montant transféré
]]
function EconomySystem:CollectStoredCash(player: Player): number

--[[
    Tente d'acheter le prochain slot
    
    @param player: Player
    @return ActionResult - Success, NotEnoughMoney, MaxSlotsReached
]]
function EconomySystem:BuyNextSlot(player: Player): string

--[[
    Récupère le prix du prochain slot à acheter
    
    @param player: Player
    @return number | nil - Prix, ou nil si max atteint
]]
function EconomySystem:GetNextSlotPrice(player: Player): number?
```

### Loop de Revenus (interne)

```lua
-- Pseudo-code de la loop
function EconomySystem:_StartRevenueLoop()
    while true do
        wait(GameConfig.Economy.RevenueTickRate)
        
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataService:GetPlayerData(player)
            if data then
                local brainrotCount = #data.PlacedBrainrots
                local revenue = brainrotCount * GameConfig.Economy.RevenuePerBrainrot
                
                if revenue > 0 then
                    self:AddStoredCash(player, revenue)
                    -- Sync vers client
                    Remotes.SyncPlayerData:FireClient(player, {StoredCash = data.StoredCash})
                end
            end
        end
    end
end
```

---

## ArenaSystem.lua

### Fonctions Publiques

```lua
--[[
    Initialise le système, démarre les loops de spawn
    @return void
]]
function ArenaSystem:Init()

--[[
    Spawn une pièce aléatoire dans l'arène
    
    @return Model | nil - La pièce créée
]]
function ArenaSystem:SpawnRandomPiece(): Model?

--[[
    Récupère les données d'une pièce (depuis ses Attributes)
    
    @param piece: Model - Le modèle de la pièce
    @return PieceData | nil
]]
function ArenaSystem:GetPieceData(piece: Model): PieceData?

--[[
    Supprime une pièce de l'arène
    
    @param piece: Model
    @return void
]]
function ArenaSystem:RemovePiece(piece: Model)

--[[
    Compte le nombre de pièces actives dans l'arène
    
    @return number
]]
function ArenaSystem:GetActivePieceCount(): number

--[[
    Gère la mort d'un joueur par le Spinner
    
    @param player: Player
    @return void
]]
function ArenaSystem:OnPlayerKilledBySpinner(player: Player)
```

### Structure d'une Pièce Spawnée

```lua
-- Attributes sur le Model
piece:SetAttribute("SetName", "Skibidi")
piece:SetAttribute("PieceType", "Head")         -- "Head" | "Body" | "Legs"
piece:SetAttribute("Price", 50)
piece:SetAttribute("DisplayName", "Skibidi")
piece:SetAttribute("SpawnTime", os.time())

-- Hiérarchie du Model
--[[
Piece_Skibidi_Head/
├── PrimaryPart (Part)      -- Part principale, position de la pièce
│   ├── BillboardGui        -- UI flottante
│   │   ├── NameLabel       -- TextLabel avec le nom
│   │   └── PriceLabel      -- TextLabel avec le prix
├── Visual (MeshPart)       -- Le visuel 3D
└── PickupZone (Part)       -- Zone de détection, CanCollide = false, Transparency = 1
]]
```

---

## InventorySystem.lua

### Fonctions Publiques

```lua
--[[
    Initialise le système
    @return void
]]
function InventorySystem:Init()

--[[
    Tente d'ajouter une pièce à l'inventaire d'un joueur
    Effectue TOUTES les validations
    
    @param player: Player
    @param piece: Model - La pièce dans l'arène
    @return ActionResult - Success, InventoryFull, NotEnoughMoney, NoSlotAvailable, InvalidPiece
]]
function InventorySystem:TryPickupPiece(player: Player, piece: Model): string

--[[
    Récupère les pièces en main d'un joueur
    
    @param player: Player
    @return {PieceData} - Liste des pièces
]]
function InventorySystem:GetPiecesInHand(player: Player): {PieceData}

--[[
    Vérifie si le joueur a les 3 types de pièces
    
    @param player: Player
    @return boolean
]]
function InventorySystem:HasFullSet(player: Player): boolean

--[[
    Vide l'inventaire du joueur (mort, craft)
    
    @param player: Player
    @return {PieceData} - Les pièces retirées
]]
function InventorySystem:ClearInventory(player: Player): {PieceData}

--[[
    Calcule le prix total des pièces en main
    
    @param player: Player
    @return number
]]
function InventorySystem:GetTotalPrice(player: Player): number

--[[
    Vérifie si le joueur a une pièce d'un type spécifique
    
    @param player: Player
    @param pieceType: string - "Head" | "Body" | "Legs"
    @return boolean
]]
function InventorySystem:HasPieceType(player: Player, pieceType: string): boolean
```

### Logique de Validation Pickup

```lua
function InventorySystem:TryPickupPiece(player, piece)
    -- 1. Vérifier que la pièce existe encore
    if not piece or not piece.Parent then
        return Constants.ActionResult.InvalidPiece
    end
    
    -- 2. Vérifier que l'inventaire n'est pas plein
    local piecesInHand = self:GetPiecesInHand(player)
    if #piecesInHand >= GameConfig.Inventory.MaxPiecesInHand then
        return Constants.ActionResult.InventoryFull
    end
    
    -- 3. Récupérer les données de la pièce
    local pieceData = ArenaSystem:GetPieceData(piece)
    if not pieceData then
        return Constants.ActionResult.InvalidPiece
    end
    
    -- 4. Vérifier que le joueur a assez d'argent (sans débiter)
    if not EconomySystem:CanAfford(player, pieceData.Price) then
        return Constants.ActionResult.NotEnoughMoney
    end
    
    -- 5. Vérifier qu'il y a au moins un slot libre dans la base
    local playerData = DataService:GetPlayerData(player)
    local placedCount = BaseSystem:GetPlacedBrainrotCount(player)
    if placedCount >= playerData.OwnedSlots then
        return Constants.ActionResult.NoSlotAvailable
    end
    
    -- 6. Tout est OK, ajouter la pièce
    table.insert(piecesInHand, pieceData)
    
    -- 7. Supprimer la pièce de l'arène
    ArenaSystem:RemovePiece(piece)
    
    -- 8. Sync vers client
    Remotes.SyncInventory:FireClient(player, piecesInHand)
    
    return Constants.ActionResult.Success
end
```

---

## CraftingSystem.lua

### Fonctions Publiques

```lua
--[[
    Initialise le système
    @return void
]]
function CraftingSystem:Init()

--[[
    Tente de crafter un Brainrot
    
    @param player: Player
    @return ActionResult, BrainrotData? - Résultat et données du Brainrot créé
]]
function CraftingSystem:TryCraft(player: Player): (string, table?)

--[[
    Génère le nom chimérique à partir des 3 pièces
    
    @param headPiece: PieceData
    @param bodyPiece: PieceData
    @param legsPiece: PieceData
    @return string - Ex: "Skibidi Rizz Fanum"
]]
function CraftingSystem:GenerateChimeraName(headPiece: PieceData, bodyPiece: PieceData, legsPiece: PieceData): string

--[[
    Crée les données du Brainrot
    
    @param headPiece: PieceData
    @param bodyPiece: PieceData  
    @param legsPiece: PieceData
    @return BrainrotData
]]
function CraftingSystem:CreateBrainrotData(headPiece: PieceData, bodyPiece: PieceData, legsPiece: PieceData): table
```

### Logique de Craft

```lua
function CraftingSystem:TryCraft(player)
    -- 1. Vérifier que le joueur a les 3 types de pièces
    if not InventorySystem:HasFullSet(player) then
        return Constants.ActionResult.MissingPieces, nil
    end
    
    -- 2. Calculer le prix total
    local totalPrice = InventorySystem:GetTotalPrice(player)
    
    -- 3. Vérifier que le joueur peut payer
    if not EconomySystem:CanAfford(player, totalPrice) then
        return Constants.ActionResult.NotEnoughMoney, nil
    end
    
    -- 4. Trouver un slot libre
    local freeSlot = BaseSystem:GetFirstFreeSlot(player)
    if not freeSlot then
        return Constants.ActionResult.NoSlotAvailable, nil
    end
    
    -- 5. Récupérer les pièces
    local pieces = InventorySystem:GetPiecesInHand(player)
    local headPiece, bodyPiece, legsPiece
    for _, piece in ipairs(pieces) do
        if piece.PieceType == "Head" then headPiece = piece
        elseif piece.PieceType == "Body" then bodyPiece = piece
        elseif piece.PieceType == "Legs" then legsPiece = piece
        end
    end
    
    -- 6. Débiter le joueur
    EconomySystem:RemoveCash(player, totalPrice)
    
    -- 7. Créer les données du Brainrot
    local brainrotData = self:CreateBrainrotData(headPiece, bodyPiece, legsPiece)
    
    -- 8. Vider l'inventaire
    InventorySystem:ClearInventory(player)
    
    -- 9. Débloquer les pièces dans le Codex
    CodexSystem:UnlockPiece(player, headPiece.SetName, headPiece.PieceType)
    CodexSystem:UnlockPiece(player, bodyPiece.SetName, bodyPiece.PieceType)
    CodexSystem:UnlockPiece(player, legsPiece.SetName, legsPiece.PieceType)
    
    -- 10. Placer le Brainrot sur le slot
    BaseSystem:PlaceBrainrotOnSlot(player, freeSlot, brainrotData)
    
    -- 11. Incrémenter les stats
    DataService:IncrementValue(player, "Stats.TotalCrafts", 1)
    
    -- 12. Sync vers client
    Remotes.SyncPlayerData:FireClient(player, DataService:GetPlayerData(player))
    Remotes.SyncInventory:FireClient(player, {})
    
    return Constants.ActionResult.Success, brainrotData
end
```

---

## CodexSystem.lua

### Fonctions Publiques

```lua
--[[
    Initialise le système
    @return void
]]
function CodexSystem:Init()

--[[
    Débloque une pièce dans le Codex
    Vérifie si le set est complété et donne la récompense
    
    @param player: Player
    @param setName: string - Ex: "Skibidi"
    @param pieceType: string - "Head" | "Body" | "Legs"
    @return boolean - true si nouvelle pièce débloquée
]]
function CodexSystem:UnlockPiece(player: Player, setName: string, pieceType: string): boolean

--[[
    Vérifie si une pièce est débloquée
    
    @param player: Player
    @param setName: string
    @param pieceType: string
    @return boolean
]]
function CodexSystem:IsPieceUnlocked(player: Player, setName: string, pieceType: string): boolean

--[[
    Récupère la progression d'un set
    
    @param player: Player
    @param setName: string
    @return {unlocked: number, total: number, pieces: {Head: bool, Body: bool, Legs: bool}}
]]
function CodexSystem:GetSetProgress(player: Player, setName: string): table

--[[
    Vérifie si un set est complété
    
    @param player: Player
    @param setName: string
    @return boolean
]]
function CodexSystem:IsSetComplete(player: Player, setName: string): boolean

--[[
    Récupère tout le Codex d'un joueur
    
    @param player: Player
    @return {[setName]: SetProgress}
]]
function CodexSystem:GetFullCodex(player: Player): table

--[[
    Donne la récompense de complétion d'un set
    
    @param player: Player
    @param setName: string
    @return number - Montant de la récompense
]]
function CodexSystem:GiveSetCompletionReward(player: Player, setName: string): number
```

---

## NetworkHandler.lua

### Structure

```lua
local NetworkHandler = {}

function NetworkHandler:Init()
    -- Créer les RemoteEvents/Functions
    self:_CreateRemotes()
    
    -- Connecter les handlers
    self:_ConnectHandlers()
end

function NetworkHandler:_CreateRemotes()
    local remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
    
    -- Créer chaque Remote selon Constants.RemoteNames
    for name, _ in pairs(Constants.RemoteNames) do
        if name:find("Get") then
            -- RemoteFunction
            local remote = Instance.new("RemoteFunction")
            remote.Name = name
            remote.Parent = remotesFolder
        else
            -- RemoteEvent
            local remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = remotesFolder
        end
    end
end

function NetworkHandler:_ConnectHandlers()
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    
    -- PickupPiece
    remotes.PickupPiece.OnServerEvent:Connect(function(player, pieceId)
        local piece = workspace.ActivePieces:FindFirstChild(pieceId)
        local result = InventorySystem:TryPickupPiece(player, piece)
        
        if result ~= Constants.ActionResult.Success then
            remotes.Notification:FireClient(player, {
                Type = "Error",
                Message = result
            })
        end
    end)
    
    -- Craft
    remotes.Craft.OnServerEvent:Connect(function(player)
        local result, brainrotData = CraftingSystem:TryCraft(player)
        
        if result == Constants.ActionResult.Success then
            remotes.Notification:FireClient(player, {
                Type = "Success",
                Message = "Brainrot créé: " .. brainrotData.Name
            })
        else
            remotes.Notification:FireClient(player, {
                Type = "Error",
                Message = result
            })
        end
    end)
    
    -- BuySlot
    remotes.BuySlot.OnServerEvent:Connect(function(player)
        local result = EconomySystem:BuyNextSlot(player)
        -- ... notification
    end)
    
    -- CollectSlotCash (détecté via Touched sur CollectPad, ou RemoteEvent)
    -- Si RemoteEvent utilisé:
    remotes.CollectSlotCash.OnServerEvent:Connect(function(player, slotIndex)
        local amount = EconomySystem:CollectSlotCash(player, slotIndex)
        -- ... notification si amount > 0
    end)
    
    -- ActivateDoor
    remotes.ActivateDoor.OnServerEvent:Connect(function(player)
        local result = DoorSystem:ActivateDoor(player)
        -- ... sync door state
    end)
    
    -- GetFullPlayerData
    remotes.GetFullPlayerData.OnServerInvoke = function(player)
        return DataService:GetPlayerData(player)
    end
end

return NetworkHandler
```

---

# PARTIE 4 : CONTRATS REMOTE EVENTS

## Client → Serveur

### PickupPiece

```lua
-- Client envoie:
Remotes.PickupPiece:FireServer(pieceId)

-- pieceId: string - Le Name unique de la pièce dans workspace.ActivePieces
-- Exemple: "Piece_Skibidi_Head_12345"
```

### Craft

```lua
-- Client envoie:
Remotes.Craft:FireServer()

-- Aucun paramètre, le serveur utilise l'inventaire du joueur
```

### BuySlot

```lua
-- Client envoie:
Remotes.BuySlot:FireServer()

-- Aucun paramètre, le serveur achète le prochain slot
```

### CollectSlotCash

```lua
-- Option 1: Détection automatique (Touched sur CollectPad)
-- Le serveur détecte directement quand le joueur marche sur CollectPad
-- Pas besoin de RemoteEvent dans ce cas

-- Option 2: Via RemoteEvent (si bouton UI)
-- Client envoie:
Remotes.CollectSlotCash:FireServer(slotIndex)

-- slotIndex: number - Le numéro du slot (1-30)
```

### ActivateDoor

```lua
-- Client envoie:
Remotes.ActivateDoor:FireServer()

-- Aucun paramètre
```

### DropPieces

```lua
-- Client envoie:
Remotes.DropPieces:FireServer()

-- Aucun paramètre, le serveur vide l'inventaire (volontaire)
```

---

## Serveur → Client

### SyncPlayerData

```lua
-- Serveur envoie:
Remotes.SyncPlayerData:FireClient(player, {
    Cash = 1500,            -- Optionnel, seulement les champs modifiés
    StoredCash = 250,
    OwnedSlots = 5,
})

-- Client reçoit: table partielle avec les champs mis à jour
```

### SyncInventory

```lua
-- Serveur envoie:
Remotes.SyncInventory:FireClient(player, {
    {SetName = "Skibidi", PieceType = "Head", Price = 50, DisplayName = "Skibidi"},
    {SetName = "Rizz", PieceType = "Body", Price = 100, DisplayName = "Rizz"},
})

-- Client reçoit: liste complète des pièces en main
```

### SyncCodex

```lua
-- Serveur envoie:
Remotes.SyncCodex:FireClient(player, {
    UnlockedPiece = "Skibidi_Head",     -- Nouvelle pièce débloquée
    SetCompleted = "Skibidi",            -- Optionnel, si set complété
    RewardAmount = 1000,                 -- Optionnel, montant de la récompense
})

-- Client reçoit: info sur le déblocage
```

### SyncDoorState

```lua
-- Serveur envoie:
Remotes.SyncDoorState:FireClient(player, {
    State = "Closed",           -- "Open" | "Closed"
    RemainingTime = 25.5,       -- Secondes restantes (si Closed)
})

-- Client reçoit: état de la porte
```

### Notification

```lua
-- Serveur envoie:
Remotes.Notification:FireClient(player, {
    Type = "Success",           -- "Success" | "Error" | "Info" | "Warning"
    Message = "Brainrot créé!", -- Message à afficher
    Duration = 3,               -- Optionnel, durée en secondes (défaut: 3)
})

-- Client reçoit: notification à afficher
```

---

## RemoteFunctions

### GetFullPlayerData

```lua
-- Client demande:
local playerData = Remotes.GetFullPlayerData:InvokeServer()

-- Client reçoit: table complète PlayerData
-- Utilisé au chargement initial
```

---

# PARTIE 5 : STRUCTURE WORKSPACE

## Vue d'ensemble

```
Workspace/
├── Bases/                          -- Folder contenant toutes les bases
│   ├── Base_1/
│   ├── Base_2/
│   └── ... (8-12 bases)
│
├── Arena/                          -- Zone de jeu principale
│   ├── Canon/                      -- Machine qui spawn les pièces
│   ├── Spinner/                    -- Barre rotative mortelle
│   ├── SpawnZone/                  -- Zone où les pièces apparaissent (Part invisible)
│   └── Boundaries/                 -- Murs de l'arène
│
├── ActivePieces/                   -- Folder des pièces actives (géré par code)
│
└── SpawnLocation                   -- Spawn temporaire (téléporté ensuite)
```

---

## Structure d'une Base

```
Base_X/                             -- Model, attribut "OwnerUserId" = 0 par défaut
│
├── SpawnPoint (Part)               -- Position de spawn, Transparency = 1, CanCollide = false
│   └── Attachment                  -- Pour le spawn
│
├── Slots/ (Folder)
│   ├── Slot_1/ (Model)             -- Chaque slot est un Model
│   │   ├── Platform (Part)         -- Où le Brainrot est placé
│   │   └── CollectPad (Part)       -- Dalle devant (Touched = collecte argent)
│   ├── Slot_2/ (Model)
│   ├── Slot_3/ (Model)
│   └── ... jusqu'à Slot_30
│
├── Door/ (Model)
│   ├── Bars/ (Model)               -- Conteneur des barreaux
│   │   ├── Bar_1 (Part)            -- Barreau individuel
│   │   ├── Bar_2 (Part)
│   │   └── ...
│   │   └── Attribut "IsActive" = false (sur le Model Bars)
│   └── ActivationPad (Part)        -- Dalle au sol
│       └── ProximityPrompt         -- "Fermer la porte"
│
├── SlotShop/ (Model)
│   ├── Sign (Part)                 -- Panneau "ACHETER SLOT"
│   │   ├── SurfaceGui              -- Texte du panneau
│   │   └── ProximityPrompt         -- "Acheter" (appuyer E)
│   └── Display (Part)              -- Écran avec le prix
│       └── SurfaceGui              -- Affiche "$100"
│
└── Floors/ (Folder)
    ├── Floor_0 (Model)             -- Rez-de-chaussée, toujours visible
    │   ├── Ground (Part)
    │   ├── Walls (Model)
    │   └── Decorations (Model)
    │
    ├── Floor_1 (Model)             -- 1er étage, Transparency = 1 au départ
    │   ├── Platform (Part)
    │   ├── Stairs_0_to_1 (Model)   -- Escaliers
    │   └── Walls (Model)
    │
    └── Floor_2 (Model)             -- 2ème étage, Transparency = 1 au départ
        ├── Platform (Part)
        ├── Stairs_1_to_2 (Model)
        └── Walls (Model)
```

### Attributs sur Base_X

```lua
Base:SetAttribute("OwnerUserId", 0)     -- 0 = libre, sinon UserId du propriétaire
Base:SetAttribute("BaseIndex", 1)        -- Index unique de la base
```

### Attributs sur Slots

```lua
-- Sur le Model Slot_X
Slot:SetAttribute("SlotIndex", 1)        -- Index du slot (1-30)
Slot:SetAttribute("IsOccupied", false)   -- true si un Brainrot est placé
Slot:SetAttribute("StoredCash", 0)       -- Argent accumulé pour ce slot
```

---

## Structure de l'Arène

```
Arena/ (Folder)
│
├── Canon (Model)
│   ├── Base (Part)                 -- Support du canon
│   ├── Barrel (Part)               -- Le canon lui-même
│   └── FirePoint (Attachment)      -- Point d'où partent les pièces
│
├── Spinner (Model)
│   ├── Center (Part)               -- Pivot central, Anchored = true
│   ├── Bar (Part)                  -- La barre mortelle
│   │   ├── Touched event           -- Connecté pour kill
│   │   └── Attribut "Deadly" = true
│   └── HingeConstraint             -- Pour la rotation
│
├── SpawnZone (Part)                -- Zone invisible définissant où les pièces spawn
│   ├── Transparency = 1
│   ├── CanCollide = false
│   └── Size = (100, 1, 100)        -- Grande zone plate
│
└── Boundaries/ (Folder)
    ├── Wall_North (Part)
    ├── Wall_South (Part)
    ├── Wall_East (Part)
    └── Wall_West (Part)
```

---

## Structure d'une Pièce (Template)

```
-- Dans ReplicatedStorage/Assets/Pieces/

Piece_Template (Model)              -- Cloné et configuré au spawn
│
├── PrimaryPart → MainPart
│
├── MainPart (Part)                 -- Part principale
│   ├── Size = (3, 3, 3)
│   ├── CanCollide = true
│   ├── Anchored = false            -- Pour la physique au spawn
│   └── BillboardGui
│       ├── Size = UDim2.new(0, 100, 0, 50)
│       ├── StudsOffset = (0, 3, 0)
│       ├── NameLabel (TextLabel)
│       │   └── Text = ""           -- Rempli au spawn
│       └── PriceLabel (TextLabel)
│           └── Text = ""           -- Rempli au spawn
│
├── Visual (MeshPart)               -- Le mesh 3D de la pièce
│   └── (Configuré selon le set/type)
│
└── PickupZone (Part)               -- Zone de détection élargie
    ├── Size = (5, 5, 5)
    ├── Transparency = 1
    ├── CanCollide = false
    └── ProximityPrompt
        ├── ActionText = "Ramasser"
        ├── ObjectText = ""         -- Rempli au spawn: "Skibidi Head - 50$"
        └── HoldDuration = 0
```

### Configuration au Spawn

```lua
-- Quand ArenaSystem:SpawnRandomPiece() crée une pièce:
local piece = PieceTemplate:Clone()
piece.Name = "Piece_" .. setName .. "_" .. pieceType .. "_" .. HttpService:GenerateGUID(false)

-- Attributs
piece:SetAttribute("SetName", setName)
piece:SetAttribute("PieceType", pieceType)
piece:SetAttribute("Price", price)
piece:SetAttribute("DisplayName", displayName)
piece:SetAttribute("SpawnTime", os.time())

-- UI
piece.MainPart.BillboardGui.NameLabel.Text = displayName .. " " .. pieceType
piece.MainPart.BillboardGui.PriceLabel.Text = "$" .. price

-- ProximityPrompt
piece.PickupZone.ProximityPrompt.ObjectText = displayName .. " " .. pieceType .. " - $" .. price

-- Position aléatoire
local spawnZone = workspace.Arena.SpawnZone
local randomPos = Vector3.new(
    spawnZone.Position.X + math.random(-spawnZone.Size.X/2, spawnZone.Size.X/2),
    spawnZone.Position.Y + 10,  -- Au-dessus pour tomber
    spawnZone.Position.Z + math.random(-spawnZone.Size.Z/2, spawnZone.Size.Z/2)
)
piece:SetPrimaryPartCFrame(CFrame.new(randomPos))

-- Parent
piece.Parent = workspace.ActivePieces
```

---

## Structure d'un Brainrot Placé

```
-- Créé quand CraftingSystem place un Brainrot

Brainrot_[Name]_[GUID] (Model)
│
├── PrimaryPart → Base
│
├── Base (Part)                     -- Socle
│   └── Anchored = true
│
├── Visual (Model)                  -- Assemblage des 3 visuels
│   ├── Head (MeshPart)             -- Clone du mesh Head du set
│   ├── Body (MeshPart)             -- Clone du mesh Body du set
│   └── Legs (MeshPart)             -- Clone du mesh Legs du set
│
├── NameDisplay (BillboardGui)
│   └── NameLabel (TextLabel)
│       └── Text = "Skibidi Rizz Fanum"
│
└── Attributes:
    - Name = "Skibidi Rizz Fanum"
    - HeadSet = "Skibidi"
    - BodySet = "Rizz"
    - LegsSet = "Fanum"
    - SlotIndex = 1
    - OwnerUserId = 12345
```

---

# PARTIE 6 : FLUX DE JEU DÉTAILLÉS

## Flux 1 : Connexion d'un Joueur

```
┌─────────────────────────────────────────────────────────────────────┐
│                         JOUEUR REJOINT                               │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ PlayerService:OnPlayerJoin(player)                                   │
│                                                                      │
│   1. DataService:LoadPlayerData(player)                              │
│      ├─ Tente de charger depuis DataStore                           │
│      ├─ Si nouveau joueur → crée DEFAULT_PLAYER_DATA                │
│      └─ Si existant → applique migrations si Version < LATEST       │
│                                                                      │
│   2. BaseSystem:AssignBase(player)                                   │
│      ├─ Parcourt Bases/, trouve première avec OwnerUserId = 0       │
│      ├─ SetAttribute("OwnerUserId", player.UserId)                  │
│      └─ Stocke référence dans RuntimeData                           │
│                                                                      │
│   3. BaseSystem:RestorePlacedBrainrots(player)                       │
│      └─ Pour chaque Brainrot dans PlacedBrainrots → crée le Model   │
│                                                                      │
│   4. BaseSystem:RestoreFloors(player)                                │
│      └─ Si OwnedSlots >= 11 → affiche Floor_1, etc.                 │
│                                                                      │
│   5. BaseSystem:SpawnPlayerAtBase(player)                            │
│      └─ Téléporte le Character au SpawnPoint de la base             │
│                                                                      │
│   6. Remotes.SyncPlayerData:FireClient(player, fullData)             │
│      └─ Envoie toutes les données au client                         │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ CLIENT: ClientMain reçoit SyncPlayerData                             │
│                                                                      │
│   1. UIController:UpdateAllUI(data)                                  │
│      ├─ MainHUD: affiche Cash, StoredCash                           │
│      ├─ ShopUI: affiche prix prochain slot                          │
│      └─ CodexUI: charge progression                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Flux 2 : Ramassage d'une Pièce

```
┌─────────────────────────────────────────────────────────────────────┐
│ CLIENT: Joueur appuie E près d'une pièce                             │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ArenaController:OnProximityPromptTriggered(piece)                    │
│                                                                      │
│   1. Récupère le Name de la pièce (ID unique)                       │
│   2. Remotes.PickupPiece:FireServer(piece.Name)                     │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ SERVEUR: NetworkHandler reçoit PickupPiece                           │
│                                                                      │
│   1. Trouve la pièce dans workspace.ActivePieces                    │
│   2. Appelle InventorySystem:TryPickupPiece(player, piece)          │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ InventorySystem:TryPickupPiece(player, piece)                        │
│                                                                      │
│   VALIDATION 1: La pièce existe-t-elle encore?                      │
│   ├─ if not piece or not piece.Parent then                          │
│   └─ return ActionResult.InvalidPiece                               │
│                                                                      │
│   VALIDATION 2: Inventaire plein?                                   │
│   ├─ if #piecesInHand >= MaxPiecesInHand then                       │
│   └─ return ActionResult.InventoryFull                              │
│                                                                      │
│   VALIDATION 3: Assez d'argent? (sans débiter)                      │
│   ├─ if Cash < piece.Price then                                     │
│   └─ return ActionResult.NotEnoughMoney                             │
│                                                                      │
│   VALIDATION 4: Slot disponible dans la base?                       │
│   ├─ if PlacedCount >= OwnedSlots then                              │
│   └─ return ActionResult.NoSlotAvailable                            │
│                                                                      │
│   SUCCÈS:                                                            │
│   1. Ajoute pieceData à RuntimeData.PiecesInHand                    │
│   2. piece:Destroy()                                                 │
│   3. return ActionResult.Success                                     │
└─────────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
            [Si Success]            [Si Échec]
                    │                       │
                    ▼                       ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│ Remotes.SyncInventory    │  │ Remotes.Notification     │
│ :FireClient(player,      │  │ :FireClient(player, {    │
│   piecesInHand)          │  │   Type = "Error",        │
│                          │  │   Message = result       │
│                          │  │ })                       │
└──────────────────────────┘  └──────────────────────────┘
                    │                       │
                    ▼                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│ CLIENT: UIController                                                 │
│                                                                      │
│ - Met à jour l'affichage des pièces en main                         │
│ - OU affiche notification d'erreur                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Flux 3 : Craft d'un Brainrot

```
┌─────────────────────────────────────────────────────────────────────┐
│ CLIENT: Joueur a 3 pièces en main et appuie sur bouton "Craft"      │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ UIController:OnCraftButtonClicked()                                 │
│                                                                      │
│   1. Vérifie localement si 3 pièces (pour UX)                       │
│   2. Remotes.Craft:FireServer()                                     │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ SERVEUR: CraftingSystem:TryCraft(player)                             │
│                                                                      │
│   VALIDATION 1: A les 3 types de pièces?                            │
│   ├─ if not HasFullSet(player) then                                 │
│   └─ return ActionResult.MissingPieces                              │
│                                                                      │
│   VALIDATION 2: Peut payer le total?                                │
│   ├─ totalPrice = sum of all piece prices                           │
│   ├─ if Cash < totalPrice then                                      │
│   └─ return ActionResult.NotEnoughMoney                             │
│                                                                      │
│   VALIDATION 3: Slot libre?                                         │
│   ├─ freeSlot = BaseSystem:GetFirstFreeSlot(player)                 │
│   ├─ if not freeSlot then                                           │
│   └─ return ActionResult.NoSlotAvailable                            │
│                                                                      │
│   EXÉCUTION:                                                         │
│   1. EconomySystem:RemoveCash(player, totalPrice)                   │
│   2. brainrotData = CreateBrainrotData(head, body, legs)            │
│   3. InventorySystem:ClearInventory(player)                         │
│   4. CodexSystem:UnlockPiece() x3                                   │
│   5. BaseSystem:PlaceBrainrotOnSlot(player, freeSlot, brainrotData) │
│   6. DataService:UpdateValue(player, "Stats.TotalCrafts", +1)       │
│                                                                      │
│   return ActionResult.Success, brainrotData                          │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ SERVEUR: Sync vers Client                                            │
│                                                                      │
│   1. Remotes.SyncPlayerData:FireClient(player, {Cash, OwnedSlots})  │
│   2. Remotes.SyncInventory:FireClient(player, {})  -- Vidé          │
│   3. Remotes.SyncCodex:FireClient(player, {pièces débloquées})      │
│   4. Remotes.Notification:FireClient(player, {Success, nom})        │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ CLIENT: Animation d'Envol                                            │
│                                                                      │
│   1. Reçoit les données du Brainrot créé                            │
│   2. Crée un Model temporaire à la position du joueur               │
│   3. TweenService: déplace vers le slot de la base                  │
│   4. À la fin du tween: le Model serveur est déjà en place          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Flux 4 : Mort au Spinner

```
┌─────────────────────────────────────────────────────────────────────┐
│ SERVEUR: Spinner.Bar.Touched:Connect()                               │
│                                                                      │
│   1. Vérifie si c'est un joueur (GetPlayerFromCharacter)            │
│   2. ArenaSystem:OnPlayerKilledBySpinner(player)                    │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ArenaSystem:OnPlayerKilledBySpinner(player)                          │
│                                                                      │
│   1. InventorySystem:ClearInventory(player)                         │
│      └─ Les pièces sont perdues (pas respawnées)                    │
│                                                                      │
│   2. DataService:IncrementValue(player, "Stats.TotalDeaths", 1)     │
│                                                                      │
│   3. player.Character.Humanoid.Health = 0                           │
│      └─ Déclenche la mort et le respawn Roblox standard             │
│                                                                      │
│   4. Remotes.SyncInventory:FireClient(player, {})                   │
│                                                                      │
│   5. Remotes.Notification:FireClient(player, {                      │
│         Type = "Warning",                                            │
│         Message = "Vous êtes mort! Pièces perdues."                 │
│      })                                                              │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ ROBLOX: Respawn automatique                                          │
│                                                                      │
│   1. Joueur respawn au SpawnLocation par défaut                     │
│   2. PlayerService:OnCharacterAdded(character)                       │
│      └─ Retéléporte le joueur à sa base                             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Flux 5 : Achat de Slot

```
┌─────────────────────────────────────────────────────────────────────┐
│ CLIENT: Joueur active ProximityPrompt du SlotShop (Sign)             │
│                                                                      │
│   Remotes.BuySlot:FireServer()                                      │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│ SERVEUR: EconomySystem:BuyNextSlot(player)                           │
│                                                                      │
│   1. nextSlot = OwnedSlots + 1                                      │
│                                                                      │
│   VALIDATION 1: Max atteint?                                        │
│   ├─ if nextSlot > MaxSlots then                                    │
│   └─ return ActionResult.MaxSlotsReached                            │
│                                                                      │
│   2. price = SlotPrices[nextSlot]                                   │
│                                                                      │
│   VALIDATION 2: Assez d'argent?                                     │
│   ├─ if Cash < price then                                           │
│   └─ return ActionResult.NotEnoughMoney                             │
│                                                                      │
│   EXÉCUTION:                                                         │
│   1. EconomySystem:RemoveCash(player, price)                        │
│   2. DataService:IncrementValue(player, "OwnedSlots", 1)            │
│   3. unlockedFloor = BaseSystem:CheckFloorUnlock(player)            │
│                                                                      │
│   return ActionResult.Success                                        │
└─────────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
            [Si Floor débloqué]     [Sync normal]
                    │                       │
                    ▼                       ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│ BaseSystem:UnlockFloor() │  │ Remotes.SyncPlayerData   │
│                          │  │ :FireClient(player, {    │
│ - Floor_X visible        │  │   Cash = newCash,        │
│ - Escaliers visibles     │  │   OwnedSlots = newCount  │
│                          │  │ })                       │
└──────────────────────────┘  └──────────────────────────┘
```

---

# PARTIE 7 : GESTION DES ERREURS

## DataStore

```lua
-- Dans DataService:LoadPlayerData
function DataService:LoadPlayerData(player)
    local success, result
    
    for attempt = 1, GameConfig.DataStore.RetryAttempts do
        success, result = pcall(function()
            return self._dataStore:GetAsync("Player_" .. player.UserId)
        end)
        
        if success then
            break
        end
        
        warn("[DataService] Tentative " .. attempt .. " échouée pour " .. player.Name)
        
        if attempt < GameConfig.DataStore.RetryAttempts then
            wait(GameConfig.DataStore.RetryDelay)
        end
    end
    
    if not success then
        -- CRITIQUE: Impossible de charger les données
        warn("[DataService] ÉCHEC TOTAL pour " .. player.Name .. ": " .. tostring(result))
        
        -- Option 1: Kick le joueur avec message
        player:Kick("Impossible de charger vos données. Veuillez réessayer.")
        return nil
        
        -- Option 2: Utiliser données par défaut (DANGEREUX - peut écraser)
        -- return table.clone(DEFAULT_PLAYER_DATA)
    end
    
    -- Données chargées ou nil (nouveau joueur)
    if result == nil then
        result = table.clone(DEFAULT_PLAYER_DATA)
    end
    
    -- Appliquer migrations
    result = self:_MigrateData(result)
    
    -- Mettre en cache
    self._cache[player.UserId] = result
    
    return result
end
```

## Pièce Disparue

```lua
-- Dans InventorySystem:TryPickupPiece
-- La pièce peut disparaître entre le moment où le client clique et le serveur traite

if not piece or not piece.Parent then
    return Constants.ActionResult.InvalidPiece
end

-- Double vérification après les autres validations (race condition)
if not piece:IsDescendantOf(workspace) then
    return Constants.ActionResult.InvalidPiece
end
```

## Déconnexion Pendant Craft

```lua
-- Dans CraftingSystem:TryCraft
-- Si le joueur se déconnecte au milieu, les données sont déjà modifiées en mémoire
-- Le PlayerService:OnPlayerLeave sauvegarde automatiquement

-- Pas de gestion spéciale nécessaire, mais s'assurer que toutes les opérations
-- sont atomiques (tout ou rien)
```

## Base Non Disponible

```lua
-- Dans BaseSystem:AssignBase
function BaseSystem:AssignBase(player)
    local basesFolder = workspace:FindFirstChild(Constants.WorkspaceNames.BasesFolder)
    
    if not basesFolder then
        error("[BaseSystem] Folder Bases non trouvé dans Workspace!")
        return nil
    end
    
    for _, base in ipairs(basesFolder:GetChildren()) do
        if base:GetAttribute("OwnerUserId") == 0 then
            -- Assigner
            base:SetAttribute("OwnerUserId", player.UserId)
            return base
        end
    end
    
    -- Aucune base libre
    warn("[BaseSystem] Aucune base disponible pour " .. player.Name)
    
    -- Option 1: Kick avec message
    player:Kick("Serveur plein, aucune base disponible.")
    return nil
    
    -- Option 2: File d'attente (complexe, pas recommandé pour MVP)
end
```

---

# PARTIE 8 : PLAN DE DÉVELOPPEMENT PARALLÉLISÉ

## Principe de Répartition

**DEV A** et **DEV B** travaillent sur des **tâches indépendantes** qui ne se bloquent pas mutuellement. Ils peuvent travailler à des moments différents (pas nécessairement en simultané).

Les **points de synchronisation** indiquent quand les deux devs doivent avoir terminé leurs tâches respectives pour pouvoir tester l'intégration.

---

## Légende

| Symbole | Signification |
|---------|---------------|
| 🟢 | Tâche indépendante, peut commencer immédiatement |
| 🟡 | Dépend d'une tâche précédente du même dev |
| 🔴 | Dépend d'une tâche de l'autre dev |
| 🔄 | Point de synchronisation (test commun) |

---

## PHASE 0 : Setup Initial (Ensemble, 1 session)

Les deux devs travaillent ensemble pour établir les bases communes.

| Tâche | Description |
|-------|-------------|
| Créer structure dossiers | Arborescence complète dans Roblox Studio |
| GameConfig.lua | Toutes les constantes définies |
| BrainrotData.lua | 3-4 sets de base |
| SlotPrices.lua | Prix des 30 slots |
| Constants.lua | Tous les enums |
| Template Base | 1 base complète dans Studio |
| Template Pièce | 1 pièce template dans ReplicatedStorage |
| Template Brainrot | 1 brainrot template dans ReplicatedStorage |
| Folder Remotes | Créer le folder avec tous les RemoteEvents vides |

**Résultat :** Les deux devs peuvent maintenant travailler indépendamment.

---

## PHASE 1 : Core Systems

### DEV A - Backend Core

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| A1.1 | 🟢 DataService.lua | - | Load/Save DataStore, cache, migrations |
| A1.2 | 🟡 PlayerService.lua | A1.1 | OnPlayerJoin, OnPlayerLeave, RuntimeData |
| A1.3 | 🟡 NetworkHandler.lua (structure) | A1.2 | Création des Remotes, structure des handlers |

### DEV B - Client Core

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| B1.1 | 🟢 MainHUD UI | - | Frames: Cash, StoredCash, PiecesInHand |
| B1.2 | 🟢 NotificationUI | - | Système de notifications (toast) |
| B1.3 | 🟡 UIController.lua | B1.1, B1.2 | Fonctions Update pour chaque élément |
| B1.4 | 🟡 ClientMain.lua | B1.3 | Connexion Remotes, écoute SyncPlayerData |

### 🔄 SYNC 1 : Test Data + UI

**Test :** DEV A envoie `SyncPlayerData` avec données test → DEV B vérifie que l'UI affiche correctement.

---

## PHASE 2 : Base System

### DEV A - Base Backend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| A2.1 | 🟢 BaseSystem.lua | - | AssignBase, ReleaseBase, GetPlayerBase |
| A2.2 | 🟡 Intégration PlayerService | A1.2, A2.1 | Appeler BaseSystem dans OnJoin/Leave |
| A2.3 | 🟢 DoorSystem.lua | - | ActivateDoor, CollisionGroups, Timer |
| A2.4 | 🟡 Handler ActivateDoor | A1.3, A2.3 | NetworkHandler gère le Remote |

### DEV B - Base Frontend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| B2.1 | 🟢 Setup Bases Studio | - | Dupliquer template, 6-8 bases, slots nommés |
| B2.2 | 🟢 Setup Étages | - | Floor_0 visible, Floor_1/2 invisibles |
| B2.3 | 🟡 BaseController.lua | B1.4 | Détection dalles (ProximityPrompt) |
| B2.4 | 🟡 Feedback Porte | B2.3 | Animation visuelle, indicateur cooldown |

### 🔄 SYNC 2 : Test Base + Porte

**Test :** Joueur rejoint → spawn dans base → active porte → collision fonctionne.

---

## PHASE 3 : Economy System

### DEV A - Economy Backend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| A3.1 | 🟢 EconomySystem.lua | - | AddCash, RemoveCash, CanAfford |
| A3.2 | 🟡 StoredCash + Collect | A3.1 | AddStoredCash, CollectStoredCash |
| A3.3 | 🟡 Revenue Loop | A3.1, A2.1 | Loop qui ajoute revenus par Brainrot |
| A3.4 | 🟡 BuyNextSlot | A3.1 | Logique d'achat de slot |
| A3.5 | 🟡 Floor Unlock | A3.4, A2.1 | Déblocage étages automatique |
| A3.6 | 🟡 Handlers Economy | A1.3, A3.2, A3.4 | CollectSlotCash (Touched), BuySlot dans NetworkHandler |

### DEV B - Economy Frontend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| B3.1 | 🟢 ShopUI | - | Affichage prix, bouton achat |
| B3.2 | 🟢 CashCollector Display | - | SurfaceGui sur la machine |
| B3.3 | 🟡 Animations Argent | B1.3 | Particules collecte, nombre animé |
| B3.4 | 🟡 Intégration ShopUI | B3.1, B2.3 | ProximityPrompt → FireServer |

### 🔄 SYNC 3 : Test Economy Complet

**Test :** Revenus s'accumulent → Collecte fonctionne → Achat slot → Étage se débloque.

---

## PHASE 4 : Arena System

### DEV A - Arena Backend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| A4.1 | 🟢 ArenaSystem.lua | - | SpawnRandomPiece, SpawnLoop, CleanupLoop |
| A4.2 | 🟢 InventorySystem.lua | - | PiecesInHand, AddPiece, ClearInventory |
| A4.3 | 🟡 TryPickupPiece | A4.1, A4.2, A3.1 | 4 validations serveur |
| A4.4 | 🟡 Spinner Kill | A4.2 | OnPlayerKilledBySpinner |
| A4.5 | 🟡 Handlers Arena | A1.3, A4.3 | PickupPiece dans NetworkHandler |

### DEV B - Arena Frontend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| B4.1 | 🟢 Setup Arena Studio | - | Zone, Canon, Spinner, SpawnZone |
| B4.2 | 🟢 Spinner Rotation | - | Script local de rotation continue |
| B4.3 | 🟡 ArenaController.lua | B1.4 | Détection ProximityPrompt pièces |
| B4.4 | 🟡 UI Pièces en main | B1.3 | 3 slots visuels, icônes, animations |

### 🔄 SYNC 4 : Test Arena Complet

**Test :** Pièces spawn → Ramassage avec validations → Mort spinner → Pièces perdues.

---

## PHASE 5 : Crafting System

### DEV A - Crafting Backend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| A5.1 | 🟡 CraftingSystem.lua | A4.2, A3.1, A2.1 | TryCraft, validations, paiement |
| A5.2 | 🟡 PlaceBrainrotOnSlot | A5.1, A2.1 | Création Model, placement sur slot |
| A5.3 | 🟡 Handler Craft | A1.3, A5.1 | Craft dans NetworkHandler |

### DEV B - Crafting Frontend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| B5.1 | 🟢 Craft Button UI | B1.1 | Bouton "Craft" dans MainHUD |
| B5.2 | 🟡 CraftController.lua | B5.1 | Gestion du bouton, vérification 3 pièces |
| B5.3 | 🟡 Animation Envol | B5.2 | TweenService, particules |

### 🔄 SYNC 5 : Test Craft Complet

**Test :** 3 pièces → Zone craft → Animation → Brainrot sur slot → Génère revenus.

---

## PHASE 6 : Codex System

### DEV A - Codex Backend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| A6.1 | 🟡 CodexSystem.lua | A5.1 | UnlockPiece, GetSetProgress, IsSetComplete |
| A6.2 | 🟡 Set Completion Reward | A6.1, A3.1 | GiveSetCompletionReward |
| A6.3 | 🟡 Intégration Craft | A6.1, A5.1 | Appeler UnlockPiece dans TryCraft |
| A6.4 | 🟡 Handler GetCodex | A1.3, A6.1 | RemoteFunction GetFullPlayerData |

### DEV B - Codex Frontend

| # | Tâche | Dépendance | Description |
|---|-------|------------|-------------|
| B6.1 | 🟢 CodexUI Layout | - | ScrollingFrame, template set (3 images) |
| B6.2 | 🟡 CodexUI Logic | B6.1, B1.4 | Chargement données, mise à jour |
| B6.3 | 🟡 États Visuels | B6.2 | Locked (silhouette), unlocked, doré |
| B6.4 | 🟡 Animation Déblocage | B6.2 | Effet quand nouvelle pièce |

### 🔄 SYNC 6 : Test Codex Complet

**Test :** Craft → Pièces dans Codex → Compléter set → Récompense → Page dorée.

---

## PHASE 7 : Polish & Tests

### DEV A - Robustesse

| # | Tâche | Description |
|---|-------|-------------|
| A7.1 | Gestion erreurs complète | pcall partout, messages clairs |
| A7.2 | Logs et debug | Warn/print structurés |
| A7.3 | Tests multi-joueurs | Vérifier race conditions |
| A7.4 | Équilibrage | Ajuster prix, revenus, spawn rates |

### DEV B - Polish Visuel

| # | Tâche | Description |
|---|-------|-------------|
| B7.1 | Sons | Collecte, craft, achat, mort, porte |
| B7.2 | Particules | Tous les feedbacks visuels |
| B7.3 | Responsive UI | Test différentes résolutions |
| B7.4 | Tutorial basique | Indications pour nouveaux joueurs |

### 🔄 SYNC FINAL : Test End-to-End

**Test complet du flow de jeu par les deux devs.**

---

## Tableau Récapitulatif des Dépendances

```
PHASE 0 ─────────────────────────────────────────
         (Setup ensemble)
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
┌───────┐           ┌───────┐
│ DEV A │           │ DEV B │
│       │           │       │
│ A1.1  │           │ B1.1  │ ◄── Indépendants
│ A1.2  │           │ B1.2  │
│ A1.3  │           │ B1.3  │
│       │           │ B1.4  │
└───┬───┘           └───┬───┘
    │                   │
    └─────────┬─────────┘
              │
         🔄 SYNC 1
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
┌───────┐           ┌───────┐
│ A2.1  │           │ B2.1  │ ◄── Indépendants
│ A2.2  │           │ B2.2  │
│ A2.3  │           │ B2.3  │
│ A2.4  │           │ B2.4  │
└───┬───┘           └───┬───┘
    │                   │
    └─────────┬─────────┘
              │
         🔄 SYNC 2
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
┌───────┐           ┌───────┐
│ A3.x  │           │ B3.x  │
└───┬───┘           └───┬───┘
    │                   │
    └─────────┬─────────┘
              │
         🔄 SYNC 3
              │
            (etc.)
```

---

## Fichiers Partagés - Règles

| Fichier | Qui modifie | Règle |
|---------|-------------|-------|
| `GameConfig.lua` | Les deux | Communiquer avant |
| `BrainrotData.lua` | Les deux | Ajouter à la fin |
| `SlotPrices.lua` | DEV A | DEV B ne touche pas |
| `Constants.lua` | Les deux | Ajouter à la fin |
| `Remotes/` | DEV A crée | DEV B utilise |

---

## Règles de Communication

1. **Avant de commencer une phase** : Vérifier que l'autre a fini la phase précédente
2. **Si bloqué par l'autre** : Message immédiat, ne pas attendre
3. **Fin de session** : Résumé de ce qui est fait / ce qui reste
4. **Modifications shared** : Prévenir avant de toucher aux fichiers partagés

---

# PARTIE 9 : CHECKLIST DE VALIDATION

## Par Phase

### Phase 1 ✅
- [ ] DataStore save/load fonctionne (tester rejoin)
- [ ] Données en cache accessibles
- [ ] UI MainHUD affiche Cash, StoredCash
- [ ] Notifications s'affichent correctement
- [ ] Pas d'erreurs console

### Phase 2 ✅
- [ ] Joueur spawn dans sa base assignée
- [ ] Base libérée quand joueur quitte
- [ ] Porte se ferme pendant 30s
- [ ] Propriétaire traverse, autres bloqués
- [ ] Cooldown respecté

### Phase 3 ✅
- [ ] Revenus s'accumulent (1$/sec par Brainrot)
- [ ] Collecte transfère vers Cash
- [ ] Achat slot déduit l'argent
- [ ] Prix correct affiché
- [ ] Étage 1 apparaît au slot 11
- [ ] Étage 2 apparaît au slot 21
- [ ] Impossible d'acheter au-delà de 30

### Phase 4 ✅
- [ ] Pièces spawn régulièrement
- [ ] Maximum 50 pièces respecté
- [ ] Pickup: validation argent fonctionne
- [ ] Pickup: validation inventaire plein fonctionne
- [ ] Pickup: validation slot libre fonctionne
- [ ] Pièce disparaît après pickup
- [ ] UI pièces en main se met à jour
- [ ] Mort au spinner = pièces perdues
- [ ] Respawn à la base après mort

### Phase 5 ✅
- [ ] Craft nécessite 3 types différents
- [ ] Craft débite le bon montant
- [ ] Brainrot apparaît sur le slot
- [ ] Nom chimérique correct
- [ ] Animation d'envol visible
- [ ] Inventaire vidé après craft
- [ ] Revenus augmentent après craft

### Phase 6 ✅
- [ ] Codex accessible via UI
- [ ] Pièces se débloquent au craft
- [ ] Progression X/3 correcte
- [ ] Set complet = récompense donnée
- [ ] Récompense donnée une seule fois
- [ ] Page dorée après complétion

### Phase 7 ✅
- [ ] Pas de bugs bloquants
- [ ] Performance acceptable
- [ ] Sons fonctionnent
- [ ] Pas de memory leaks (jouer 10 min)
- [ ] Multi-joueurs stable

---

# PARTIE 10 : EXTENSIONS FUTURES

## Features Prévues (Désactivées)

Ces features sont prises en compte dans l'architecture mais pas implémentées :

| Feature | Complexité | Impact Architecture |
|---------|------------|---------------------|
| Trading | Moyenne | Nouveau TradingSystem + UI |
| Daily Rewards | Facile | DailyData dans PlayerData |
| Leaderboard | Facile | Nouveau DataStore global |
| Événements | Moyenne | EventManager + configs temporaires |
| Nouveaux Sets | Très Facile | Juste BrainrotData.lua |
| Nouveaux Étages | Facile | GameConfig + Floor_3, etc. |
| Pets | Moyenne | PetSystem + PetData |
| Gamepass | Facile | MarketplaceService checks |

## Comment Ajouter un Set

```lua
-- Dans BrainrotData.lua, ajouter :
["NouveauSet"] = {
    Rarity = "Epic",
    Head = {Price = 300, DisplayName = "Nouveau", ModelName = "NouveauSet_Head", SpawnWeight = 3},
    Body = {Price = 350, DisplayName = "Nouveau", ModelName = "NouveauSet_Body", SpawnWeight = 3},
    Legs = {Price = 325, DisplayName = "Nouveau", ModelName = "NouveauSet_Legs", SpawnWeight = 3},
},

-- Puis créer les Models dans ReplicatedStorage/Assets/Pieces/
```

## Comment Activer une Feature

```lua
-- Dans FeatureFlags.lua :
TRADING_SYSTEM = true,  -- Était false

-- Puis implémenter TradingSystem.lua et TradingUI
```

---

## Licence

Projet privé - Tous droits réservés
