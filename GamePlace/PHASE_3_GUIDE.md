# PHASE 3 : ECONOMY SYSTEM - Guide Ultra-Détaillé

**Date:** 2026-02-03  
**Status:** DEV A ✅ COMPLETE | DEV B 🔄 EN COURS (Code ✅, Studio ⏳)  
**Prérequis:** Phases 0, 1 et 2 complétées

**→ [Voir le statut détaillé](PHASE_3_STATUS.md)**

---

## Vue d'Ensemble

La Phase 3 établit le système économique complet du jeu :
- **DEV A** : Backend Economy (EconomySystem, Revenue Loop, Handlers)
- **DEV B** : Frontend Economy (ShopUI, Animations, Feedbacks visuels)

### Objectif Final de la Phase 3
- Les Brainrots placés génèrent des revenus passifs
- L'argent s'accumule dans les slots (SlotCash)
- Le joueur peut collecter l'argent accumulé
- Le joueur peut acheter de nouveaux slots
- Les étages se débloquent automatiquement (11 slots = Floor_1, 21 slots = Floor_2)

---

## Résumé des Tâches

### DEV A - Backend Economy

| # | Tâche | Dépendance | Fichier | Temps estimé |
|---|-------|------------|---------|--------------|
| A3.1 | 🟢 EconomySystem (Base) | Aucune | `Systems/EconomySystem.module.lua` | 1h |
| A3.2 | 🟡 Gestion SlotCash | A3.1 | (même fichier) | 30min |
| A3.3 | 🟡 Revenue Loop | A3.1, A3.2 | (même fichier) | 45min |
| A3.4 | 🟡 BuyNextSlot | A3.1 | (même fichier) | 30min |
| A3.5 | 🟡 Floor Unlock | A3.4, BaseSystem | (même fichier) | 30min |
| A3.6 | 🟡 Handlers Economy | A3.1-A3.5 | `Handlers/NetworkHandler.module.lua` | 45min |
| A3.7 | 🟡 Intégration GameServer | A3.1-A3.6 | `Core/GameServer.server.lua` | 15min |

**Total DEV A:** ~4h30

### DEV B - Frontend Economy

| # | Tâche | Dépendance | Fichier | Temps estimé |
|---|-------|------------|---------|--------------|
| B3.1 | 🟢 ShopUI ScreenGui | Aucune | `StarterGui/ShopUI` (Studio) | 1h |
| B3.2 | 🟢 CollectPad SurfaceGui | Aucune | Sur chaque Base (Studio) | 45min |
| B3.3 | 🟡 SlotShop Display Update | B3.2 | Script local dynamique | 30min |
| B3.4 | 🟡 Animations Argent | UIController | `UIController.module.lua` | 45min |
| B3.5 | 🟡 EconomyController | B3.1, B3.4 | `EconomyController.module.lua` | 1h |
| B3.6 | 🟡 Intégration ClientMain | B3.5 | `ClientMain.client.lua` | 30min |
| B3.7 | 🟡 Feedback Sonore | B3.4 | (sons dans Studio) | 30min |

**Total DEV B:** ~5h

---

# DEV A - BACKEND ECONOMY

## A3.1 - EconomySystem.module.lua (Base)

### Description
Service principal de gestion de l'économie du jeu.

### Dépendances
- `ReplicatedStorage/Config/GameConfig`
- `ReplicatedStorage/Data/SlotPrices`
- `ServerScriptService/Core/DataService`
- `ServerScriptService/Core/PlayerService`

### Fichier : `ServerScriptService/Systems/EconomySystem.module.lua`

```lua
--[[
    EconomySystem.lua
    Gestion de l'économie du jeu
    
    Responsabilités:
    - Gérer l'argent des joueurs (Cash)
    - Gérer l'argent stocké dans les slots (SlotCash)
    - Générer les revenus passifs des Brainrots
    - Gérer l'achat de slots
    - Gérer le déblocage des étages
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules de configuration (chargés dans Init pour ne pas bloquer le require)
local GameConfig = nil
local SlotPrices = nil

-- Services (seront injectés)
local DataService = nil
local PlayerService = nil
local NetworkSetup = nil
local BaseSystem = nil

local EconomySystem = {}
EconomySystem._initialized = false
EconomySystem._revenueLoopRunning = false

--[[
    Initialise le système économique
    @param services: table - {DataService, PlayerService, NetworkSetup, BaseSystem}
]]
function EconomySystem:Init(services)
    if self._initialized then
        warn("[EconomySystem] Déjà initialisé!")
        return
    end
    
    print("[EconomySystem] Initialisation...")
    
    -- Charger Config/Data ici pour ne pas bloquer le require() du module
    local Config = ReplicatedStorage:WaitForChild("Config")
    local Data = ReplicatedStorage:WaitForChild("Data")
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    SlotPrices = require(Data:WaitForChild("SlotPrices.module"))
    
    -- Récupérer les services injectés
    DataService = services.DataService
    PlayerService = services.PlayerService
    NetworkSetup = services.NetworkSetup
    BaseSystem = services.BaseSystem
    
    if not DataService then
        error("[EconomySystem] DataService requis!")
    end
    
    if not PlayerService then
        error("[EconomySystem] PlayerService requis!")
    end
    
    -- Démarrer la loop de revenus
    self:_StartRevenueLoop()
    
    self._initialized = true
    print("[EconomySystem] Initialisé!")
end

-- ═══════════════════════════════════════════════════════
-- GESTION DE L'ARGENT (CASH)
-- ═══════════════════════════════════════════════════════

--[[
    Ajoute de l'argent au portefeuille d'un joueur
    @param player: Player
    @param amount: number - Montant à ajouter (positif)
    @return number - Nouveau solde
]]
function EconomySystem:AddCash(player, amount)
    if amount <= 0 then
        warn("[EconomySystem] Montant invalide: " .. tostring(amount))
        return self:GetCash(player)
    end
    
    local newAmount = DataService:IncrementValue(player, "Cash", amount)
    
    -- Incrémenter les stats
    DataService:IncrementValue(player, "Stats.TotalCashEarned", amount)
    
    print("[EconomySystem] " .. player.Name .. " +$" .. amount .. " (total: $" .. newAmount .. ")")
    
    -- Sync vers le client
    self:_SyncCash(player, newAmount)
    
    return newAmount
end

--[[
    Retire de l'argent du portefeuille d'un joueur
    @param player: Player
    @param amount: number - Montant à retirer (positif)
    @return boolean - true si succès (avait assez d'argent)
]]
function EconomySystem:RemoveCash(player, amount)
    if amount <= 0 then
        warn("[EconomySystem] Montant invalide: " .. tostring(amount))
        return false
    end
    
    local currentCash = self:GetCash(player)
    
    if currentCash < amount then
        print("[EconomySystem] " .. player.Name .. " n'a pas assez d'argent ($" .. currentCash .. " < $" .. amount .. ")")
        return false
    end
    
    local newAmount = DataService:IncrementValue(player, "Cash", -amount)
    
    print("[EconomySystem] " .. player.Name .. " -$" .. amount .. " (total: $" .. newAmount .. ")")
    
    -- Sync vers le client
    self:_SyncCash(player, newAmount)
    
    return true
end

--[[
    Vérifie si le joueur peut payer un montant
    @param player: Player
    @param amount: number
    @return boolean
]]
function EconomySystem:CanAfford(player, amount)
    local currentCash = self:GetCash(player)
    return currentCash >= amount
end

--[[
    Récupère l'argent actuel d'un joueur
    @param player: Player
    @return number
]]
function EconomySystem:GetCash(player)
    local data = DataService:GetPlayerData(player)
    return data and data.Cash or 0
end

-- ═══════════════════════════════════════════════════════
-- GESTION DE L'ARGENT STOCKÉ (SLOTCASH)
-- ═══════════════════════════════════════════════════════

--[[
    Ajoute de l'argent au stockage d'un slot spécifique
    @param player: Player
    @param slotIndex: number - Index du slot (1-30)
    @param amount: number - Montant à ajouter
    @return number - Nouveau montant dans ce slot
]]
function EconomySystem:AddSlotCash(player, slotIndex, amount)
    if amount <= 0 then return 0 end
    
    local data = DataService:GetPlayerData(player)
    if not data then return 0 end
    
    -- Initialiser si nécessaire
    if not data.SlotCash then
        data.SlotCash = {}
    end
    
    local currentAmount = data.SlotCash[slotIndex] or 0
    local newAmount = currentAmount + amount
    data.SlotCash[slotIndex] = newAmount
    
    return newAmount
end

--[[
    Collecte l'argent d'un slot spécifique et le transfère au portefeuille
    @param player: Player
    @param slotIndex: number - Index du slot (1-30)
    @return number - Montant collecté
]]
function EconomySystem:CollectSlotCash(player, slotIndex)
    local data = DataService:GetPlayerData(player)
    if not data then return 0 end
    
    if not data.SlotCash then return 0 end
    
    local amount = data.SlotCash[slotIndex] or 0
    
    if amount > 0 then
        -- Vider le slot
        data.SlotCash[slotIndex] = 0
        
        -- Ajouter au portefeuille
        self:AddCash(player, amount)
        
        print("[EconomySystem] " .. player.Name .. " a collecté $" .. amount .. " du slot " .. slotIndex)
        
        -- Sync le SlotCash vers le client
        self:_SyncSlotCash(player, data.SlotCash)
    end
    
    return amount
end

--[[
    Collecte tout l'argent stocké dans tous les slots
    @param player: Player
    @return number - Montant total collecté
]]
function EconomySystem:CollectAllSlotCash(player)
    local data = DataService:GetPlayerData(player)
    if not data or not data.SlotCash then return 0 end
    
    local totalCollected = 0
    
    for slotIndex, amount in pairs(data.SlotCash) do
        if amount > 0 then
            totalCollected = totalCollected + amount
            data.SlotCash[slotIndex] = 0
        end
    end
    
    if totalCollected > 0 then
        self:AddCash(player, totalCollected)
        print("[EconomySystem] " .. player.Name .. " a collecté un total de $" .. totalCollected)
        
        -- Sync le SlotCash vers le client
        self:_SyncSlotCash(player, data.SlotCash)
    end
    
    return totalCollected
end

--[[
    Récupère le total de l'argent stocké dans tous les slots
    @param player: Player
    @return number
]]
function EconomySystem:GetTotalSlotCash(player)
    local data = DataService:GetPlayerData(player)
    if not data or not data.SlotCash then return 0 end
    
    local total = 0
    for _, amount in pairs(data.SlotCash) do
        total = total + amount
    end
    
    return total
end

-- ═══════════════════════════════════════════════════════
-- REVENUS PASSIFS (REVENUE LOOP)
-- ═══════════════════════════════════════════════════════

--[[
    Démarre la boucle de génération de revenus
    (appelé automatiquement par Init)
]]
function EconomySystem:_StartRevenueLoop()
    if self._revenueLoopRunning then
        warn("[EconomySystem] Revenue loop déjà en cours!")
        return
    end
    
    self._revenueLoopRunning = true
    
    task.spawn(function()
        print("[EconomySystem] Revenue loop démarrée (tick: " .. GameConfig.Economy.RevenueTickRate .. "s)")
        
        while self._revenueLoopRunning do
            task.wait(GameConfig.Economy.RevenueTickRate)
            
            -- Traiter chaque joueur connecté
            for _, player in ipairs(Players:GetPlayers()) do
                self:_ProcessPlayerRevenue(player)
            end
        end
    end)
end

--[[
    Traite les revenus pour un joueur
    @param player: Player
]]
function EconomySystem:_ProcessPlayerRevenue(player)
    local data = DataService:GetPlayerData(player)
    if not data then return end
    
    -- Compter les Brainrots placés et calculer les revenus par slot
    if not data.PlacedBrainrots then return end
    
    local totalRevenue = 0
    local revenuePerBrainrot = GameConfig.Economy.RevenuePerBrainrot
    
    for slotIndex, brainrotData in pairs(data.PlacedBrainrots) do
        if brainrotData then
            -- Calculer le bonus de rareté (optionnel)
            local multiplier = self:_GetRarityMultiplier(brainrotData)
            local slotRevenue = revenuePerBrainrot * multiplier
            
            -- Ajouter au slot correspondant
            self:AddSlotCash(player, slotIndex, slotRevenue)
            totalRevenue = totalRevenue + slotRevenue
        end
    end
    
    -- Si des revenus ont été générés, sync vers le client
    if totalRevenue > 0 then
        self:_SyncSlotCash(player, data.SlotCash)
        -- print("[EconomySystem] " .. player.Name .. " revenus: +$" .. totalRevenue)
    end
end

--[[
    Calcule le multiplicateur de rareté pour un Brainrot
    @param brainrotData: table
    @return number
]]
function EconomySystem:_GetRarityMultiplier(brainrotData)
    -- TODO: Récupérer la rareté depuis BrainrotData et appliquer le multiplicateur
    -- Pour l'instant, retourne 1 (pas de bonus)
    return 1
end

-- ═══════════════════════════════════════════════════════
-- ACHAT DE SLOTS
-- ═══════════════════════════════════════════════════════

--[[
    Récupère le prix du prochain slot à acheter
    @param player: Player
    @return number | nil - Prix, ou nil si max atteint
]]
function EconomySystem:GetNextSlotPrice(player)
    local data = DataService:GetPlayerData(player)
    if not data then return nil end
    
    local currentSlots = data.OwnedSlots or 1
    local nextSlot = currentSlots + 1
    
    if nextSlot > GameConfig.Base.MaxSlots then
        return nil -- Max atteint
    end
    
    return SlotPrices[nextSlot] or 999999
end

--[[
    Tente d'acheter le prochain slot
    @param player: Player
    @return string - ActionResult (Success, NotEnoughMoney, MaxSlotsReached)
    @return number | nil - Nouveau nombre de slots si succès
]]
function EconomySystem:BuyNextSlot(player)
    local data = DataService:GetPlayerData(player)
    if not data then
        return "Error", nil
    end
    
    local currentSlots = data.OwnedSlots or 1
    local nextSlot = currentSlots + 1
    
    -- Vérifier le maximum
    if nextSlot > GameConfig.Base.MaxSlots then
        print("[EconomySystem] " .. player.Name .. " a déjà le maximum de slots (" .. GameConfig.Base.MaxSlots .. ")")
        return "MaxSlotsReached", nil
    end
    
    -- Récupérer le prix
    local price = SlotPrices[nextSlot]
    if not price then
        warn("[EconomySystem] Prix non défini pour le slot " .. nextSlot)
        return "Error", nil
    end
    
    -- Vérifier l'argent
    if not self:CanAfford(player, price) then
        print("[EconomySystem] " .. player.Name .. " n'a pas assez d'argent pour le slot " .. nextSlot .. " ($" .. price .. ")")
        return "NotEnoughMoney", nil
    end
    
    -- Débiter le joueur
    self:RemoveCash(player, price)
    
    -- Incrémenter les slots possédés
    local newSlotCount = DataService:IncrementValue(player, "OwnedSlots", 1)
    
    print("[EconomySystem] " .. player.Name .. " a acheté le slot " .. nextSlot .. " pour $" .. price .. " (total: " .. newSlotCount .. " slots)")
    
    -- Vérifier le déblocage d'étage
    local unlockedFloor = self:CheckFloorUnlock(player, newSlotCount)
    
    -- Sync vers le client
    self:_SyncOwnedSlots(player, newSlotCount, unlockedFloor)
    
    return "Success", newSlotCount
end

--[[
    Récupère le nombre de slots possédés
    @param player: Player
    @return number
]]
function EconomySystem:GetOwnedSlots(player)
    local data = DataService:GetPlayerData(player)
    return data and data.OwnedSlots or 1
end

-- ═══════════════════════════════════════════════════════
-- DÉBLOCAGE DES ÉTAGES
-- ═══════════════════════════════════════════════════════

--[[
    Vérifie et débloque les étages si nécessaire
    @param player: Player
    @param currentSlots: number - Nombre actuel de slots
    @return number | nil - Numéro de l'étage débloqué, ou nil
]]
function EconomySystem:CheckFloorUnlock(player, currentSlots)
    local thresholds = GameConfig.Base.FloorUnlockThresholds
    local unlockedFloor = nil
    
    for floor, requiredSlots in pairs(thresholds) do
        if currentSlots == requiredSlots then
            -- Étage atteint exactement maintenant!
            unlockedFloor = floor
            
            print("[EconomySystem] " .. player.Name .. " a débloqué l'étage " .. floor .. " !")
            
            -- Appeler BaseSystem pour afficher l'étage
            if BaseSystem and BaseSystem.UnlockFloor then
                BaseSystem:UnlockFloor(player, floor)
            end
            
            -- Envoyer une notification
            self:_SendNotification(player, "Success", "Étage " .. floor .. " débloqué !")
            
            break
        end
    end
    
    return unlockedFloor
end

-- ═══════════════════════════════════════════════════════
-- SYNCHRONISATION CLIENT
-- ═══════════════════════════════════════════════════════

--[[
    Sync le Cash vers le client
    @param player: Player
    @param cash: number
]]
function EconomySystem:_SyncCash(player, cash)
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, {
            Cash = cash
        })
    end
end

--[[
    Sync le SlotCash vers le client
    @param player: Player
    @param slotCash: table
]]
function EconomySystem:_SyncSlotCash(player, slotCash)
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, {
            SlotCash = slotCash
        })
    end
end

--[[
    Sync les OwnedSlots vers le client
    @param player: Player
    @param ownedSlots: number
    @param unlockedFloor: number | nil
]]
function EconomySystem:_SyncOwnedSlots(player, ownedSlots, unlockedFloor)
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes.SyncPlayerData then
        remotes.SyncPlayerData:FireClient(player, {
            OwnedSlots = ownedSlots,
            UnlockedFloor = unlockedFloor, -- Optionnel, pour animation client
        })
    end
end

--[[
    Envoie une notification au client
    @param player: Player
    @param notifType: string
    @param message: string
]]
function EconomySystem:_SendNotification(player, notifType, message)
    local remotes = NetworkSetup:GetAllRemotes()
    if remotes.Notification then
        remotes.Notification:FireClient(player, {
            Type = notifType,
            Message = message,
            Duration = 3,
        })
    end
end

return EconomySystem
```

### Tests de Validation A3.1-A3.5
- [ ] Le module se charge sans erreur
- [ ] `EconomySystem:Init()` s'exécute sans crash
- [ ] `AddCash(player, 100)` ajoute correctement l'argent
- [ ] `RemoveCash(player, 50)` retire correctement l'argent
- [ ] `CanAfford(player, 1000)` retourne false si pas assez
- [ ] La revenue loop génère des revenus toutes les X secondes
- [ ] `BuyNextSlot()` débite et incrémente les slots
- [ ] L'étage se débloque au seuil correct (11, 21)

---

## A3.6 - Mise à jour NetworkHandler

### Description
Ajouter les handlers pour BuySlot et CollectSlotCash.

### Modifications : `ServerScriptService/Handlers/NetworkHandler.module.lua`

**Ajouter dans la section des services injectés :**

```lua
-- Ajouter dans les variables de service
local EconomySystem = nil
```

**Ajouter dans `NetworkHandler:Init()` :**

```lua
-- Récupérer EconomySystem
EconomySystem = services.EconomySystem
```

**Remplacer les handlers placeholder :**

```lua
--[[
    Handler: Achat de slot
    @param player: Player
]]
function NetworkHandler:_HandleBuySlot(player)
    print("[NetworkHandler] BuySlot reçu de " .. player.Name)
    
    if not EconomySystem then
        self:_SendNotification(player, "Error", "Système économique non initialisé")
        return
    end
    
    local result, newSlotCount = EconomySystem:BuyNextSlot(player)
    
    if result == "Success" then
        local nextPrice = EconomySystem:GetNextSlotPrice(player)
        local message = "Slot " .. newSlotCount .. " acheté!"
        if nextPrice then
            message = message .. " Prochain: $" .. nextPrice
        else
            message = message .. " (Maximum atteint)"
        end
        self:_SendNotification(player, "Success", message)
    elseif result == "NotEnoughMoney" then
        local nextPrice = EconomySystem:GetNextSlotPrice(player)
        self:_SendNotification(player, "Error", "Pas assez d'argent! ($" .. (nextPrice or 0) .. " requis)")
    elseif result == "MaxSlotsReached" then
        self:_SendNotification(player, "Warning", "Maximum de slots atteint!")
    else
        self:_SendNotification(player, "Error", "Erreur lors de l'achat")
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
        self:_SendNotification(player, "Error", "Système économique non initialisé")
        return
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
        self:_SendNotification(player, "Success", "+$" .. amount .. " collecté!")
    end
end
```

---

## A3.7 - Mise à jour GameServer

### Description
Intégrer EconomySystem dans le flux d'initialisation.

### Modifications : `ServerScriptService/Core/GameServer.server.lua`

**Ajouter après les require des Systems :**

```lua
local Systems = ServerScriptService:WaitForChild("Systems")
local BaseSystem = require(Systems["BaseSystem.module"])
local DoorSystem = require(Systems["DoorSystem.module"])
local EconomySystem, economyLoadErr
do
    local ok, mod = pcall(function()
        return require(Systems["EconomySystem.module"])
    end)
    if ok then EconomySystem = mod else economyLoadErr = mod end
end
```

**Ajouter dans la section INITIALISATION (après DoorSystem) :**

```lua
-- 7. EconomySystem (Phase 3) - optionnel si le chargement a échoué
if EconomySystem then
    EconomySystem:Init({
        DataService = DataService,
        PlayerService = PlayerService,
        NetworkSetup = NetworkSetup,
        BaseSystem = BaseSystem,
    })
    print("[GameServer] EconomySystem: OK")
    NetworkHandler:UpdateSystems({EconomySystem = EconomySystem})
else
    warn("[GameServer] EconomySystem non chargé (Phase 3 désactivée):", economyLoadErr or "inconnu")
end
```

**Mettre à jour l'init de NetworkHandler pour inclure EconomySystem :**

```lua
-- 4. NetworkHandler
NetworkHandler:Init({
    NetworkSetup = NetworkSetup,
    DataService = DataService,
    PlayerService = PlayerService,
    BaseSystem = BaseSystem,
    DoorSystem = DoorSystem,
    EconomySystem = EconomySystem, -- NOUVEAU
})
print("[GameServer] NetworkHandler: OK")
```

---

# DEV B - FRONTEND ECONOMY

**⚠️ NOTE IMPORTANTE:** Les scripts clients sont déjà créés ! Il ne reste que la création des UI dans Studio.

**Scripts créés:**
- ✅ `EconomyController.module.lua` - Gestion ShopUI et CollectPads
- ✅ `UIController.module.lua` - Animations argent ajoutées
- ✅ `ClientMain.client.lua` - Intégration complète

**À faire dans Studio:**
- ⏳ Créer le ShopUI ScreenGui (B3.1)
- ⏳ Créer les SurfaceGui sur CollectPads (B3.2)

---

## B3.1 - ShopUI ScreenGui

### Description
Interface d'achat de slots visible dans la base du joueur.

**⚠️ Le script `EconomyController.module.lua` est déjà créé et attend ce ShopUI !**

### Création dans Roblox Studio

1. Dans **StarterGui**, créer un **ScreenGui**
2. Renommer en `ShopUI`
3. Propriétés :
   - `ResetOnSpawn` = false
   - `IgnoreGuiInset` = false
   - `Enabled` = false (sera activé par proximité)

### Structure du ShopUI

```
ShopUI (ScreenGui)
├── Background (Frame)
│   ├── UICorner
│   ├── Title (TextLabel)
│   │   └── "SLOT SHOP"
│   ├── CurrentSlots (TextLabel)
│   │   └── "Slots: 1/30"
│   ├── PriceDisplay (Frame)
│   │   ├── PriceIcon (ImageLabel)
│   │   └── PriceLabel (TextLabel)
│   │       └── "$100"
│   ├── BuyButton (TextButton)
│   │   ├── UICorner
│   │   └── "ACHETER"
│   └── CloseButton (TextButton)
│       └── "X"
```

### Détails des éléments

#### Background (Frame)
| Propriété | Valeur |
|-----------|--------|
| Name | `Background` |
| Size | UDim2.new(0, 350, 0, 250) |
| Position | UDim2.new(0.5, -175, 0.5, -125) |
| BackgroundColor3 | (40, 40, 50) |
| BackgroundTransparency | 0.1 |
| BorderSizePixel | 0 |

#### UICorner (dans Background)
| Propriété | Valeur |
|-----------|--------|
| CornerRadius | UDim.new(0, 12) |

#### Title (TextLabel)
| Propriété | Valeur |
|-----------|--------|
| Name | `Title` |
| Size | UDim2.new(1, 0, 0, 40) |
| Position | UDim2.new(0, 0, 0, 10) |
| BackgroundTransparency | 1 |
| Text | `SLOT SHOP` |
| TextColor3 | (255, 215, 0) or |
| TextScaled | true |
| Font | GothamBold |

#### CurrentSlots (TextLabel)
| Propriété | Valeur |
|-----------|--------|
| Name | `CurrentSlots` |
| Size | UDim2.new(1, 0, 0, 30) |
| Position | UDim2.new(0, 0, 0, 55) |
| BackgroundTransparency | 1 |
| Text | `Slots: 1/30` |
| TextColor3 | (200, 200, 200) |
| TextScaled | true |
| Font | Gotham |

#### PriceDisplay (Frame)
| Propriété | Valeur |
|-----------|--------|
| Name | `PriceDisplay` |
| Size | UDim2.new(0.8, 0, 0, 50) |
| Position | UDim2.new(0.1, 0, 0, 95) |
| BackgroundColor3 | (30, 30, 35) |
| BackgroundTransparency | 0.5 |
| BorderSizePixel | 0 |

#### PriceLabel (TextLabel dans PriceDisplay)
| Propriété | Valeur |
|-----------|--------|
| Name | `PriceLabel` |
| Size | UDim2.new(0.8, 0, 1, 0) |
| Position | UDim2.new(0.2, 0, 0, 0) |
| BackgroundTransparency | 1 |
| Text | `$100` |
| TextColor3 | (0, 255, 100) vert |
| TextScaled | true |
| Font | GothamBold |

#### BuyButton (TextButton)
| Propriété | Valeur |
|-----------|--------|
| Name | `BuyButton` |
| Size | UDim2.new(0.7, 0, 0, 50) |
| Position | UDim2.new(0.15, 0, 0, 160) |
| BackgroundColor3 | (0, 150, 0) |
| BorderSizePixel | 0 |
| Text | `ACHETER` |
| TextColor3 | (255, 255, 255) |
| TextScaled | true |
| Font | GothamBold |

#### CloseButton (TextButton)
| Propriété | Valeur |
|-----------|--------|
| Name | `CloseButton` |
| Size | UDim2.new(0, 30, 0, 30) |
| Position | UDim2.new(1, -40, 0, 10) |
| BackgroundColor3 | (150, 50, 50) |
| BorderSizePixel | 0 |
| Text | `X` |
| TextColor3 | (255, 255, 255) |
| TextScaled | true |
| Font | GothamBold |

---

## B3.2 - CollectPad SurfaceGui

### Description
Affichage de l'argent accumulé sur chaque slot (sur le CollectPad de la base).

**⚠️ Le script `EconomyController.module.lua` met à jour automatiquement ces SurfaceGui.**

**Visibilité par étage :** Les SurfaceGui des CollectPads des **étages non débloqués** sont mis en `Enabled = false` par le script, afin qu'ils ne s'affichent pas dans le vide (slots non encore achetés). Seuls les CollectPads des slots possédés par le joueur affichent leur cash. Dès qu'un étage est débloqué (achat de slots), leurs CollectPads deviennent visibles.

### Configuration dans Studio

Pour chaque `CollectPad` dans les bases :

1. Créer un **SurfaceGui** enfant du CollectPad
2. Propriétés du SurfaceGui :
   - `Face` = Top
   - `SizingMode` = PixelsPerStud
   - `PixelsPerStud` = 50
   - `Enabled` = true (le script le désactivera pour les étages non débloqués)

### Structure du SurfaceGui

```
SurfaceGui (sur CollectPad)
├── CashDisplay (Frame)
│   ├── UICorner
│   ├── CashIcon (ImageLabel)
│   └── CashLabel (TextLabel)
│       └── "$0"
```

#### CashDisplay (Frame)
| Propriété | Valeur |
|-----------|--------|
| Name | `CashDisplay` |
| Size | UDim2.new(0.8, 0, 0.8, 0) |
| Position | UDim2.new(0.1, 0, 0.1, 0) |
| BackgroundColor3 | (40, 40, 40) |
| BackgroundTransparency | 0.3 |

#### CashLabel (TextLabel)
| Propriété | Valeur |
|-----------|--------|
| Name | `CashLabel` |
| Size | UDim2.new(1, 0, 0.6, 0) |
| Position | UDim2.new(0, 0, 0.2, 0) |
| BackgroundTransparency | 1 |
| Text | `$0` |
| TextColor3 | (0, 255, 100) vert |
| TextScaled | true |
| Font | GothamBold |

**Note:** Ces SurfaceGui sont mis à jour par `EconomyController:UpdateCollectPads()`, qui écoute les sync du serveur et masque (`surfaceGui.Enabled = false`) ceux des slots dont l'index est supérieur à `currentOwnedSlots`.

---

## B3.3 - SlotShop Display dans la Base

### Description
Mise à jour dynamique du panneau SlotShop dans la base pour afficher le prix actuel.

### Configuration dans Studio

Dans chaque Base, le **SlotShop/Display** doit avoir un SurfaceGui :

```
SlotShop/ (Model dans Base)
├── Sign (Part avec ProximityPrompt)
└── Display (Part)
    └── SurfaceGui
        └── PriceFrame (Frame)
            └── PriceLabel (TextLabel)
                └── "$100"
```

---

## B3.4 - Mise à jour UIController (Animations Argent)

### Description
Ajouter les animations pour les gains/pertes d'argent.

**✅ DÉJÀ FAIT !** Les fonctions suivantes ont été ajoutées à `UIController.module.lua` :
- `AnimateCashGain()` - Animation de gain d'argent
- `AnimateCashLoss()` - Animation de perte d'argent
- `UpdateCashAnimated()` - Mise à jour avec animation

### Modifications : `StarterPlayerScripts/UIController.module.lua`

**Note:** Ces modifications sont déjà appliquées dans le fichier.

**Ajouter ces fonctions :**

```lua
--[[
    Animation de gain d'argent (nombre qui monte)
    @param amount: number - Montant gagné
    @param sourcePosition: Vector3 | nil - Position 3D source (optionnel)
]]
function UIController:AnimateCashGain(amount, sourcePosition)
    -- Créer un TextLabel temporaire
    local floatingText = Instance.new("TextLabel")
    floatingText.Name = "CashGain"
    floatingText.Size = UDim2.new(0, 150, 0, 40)
    floatingText.Position = UDim2.new(0.5, -75, 0.4, 0)
    floatingText.BackgroundTransparency = 1
    floatingText.Text = "+$" .. self:FormatNumber(amount)
    floatingText.TextColor3 = Color3.fromRGB(0, 255, 100)
    floatingText.TextScaled = true
    floatingText.Font = Enum.Font.GothamBold
    floatingText.TextStrokeTransparency = 0.5
    floatingText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    floatingText.Parent = mainHUD
    
    -- Animation: monter et disparaître
    local tweenUp = TweenService:Create(floatingText, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -75, 0.2, 0),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })
    
    tweenUp:Play()
    tweenUp.Completed:Connect(function()
        floatingText:Destroy()
    end)
end

--[[
    Animation de perte d'argent
    @param amount: number - Montant perdu
]]
function UIController:AnimateCashLoss(amount)
    local floatingText = Instance.new("TextLabel")
    floatingText.Name = "CashLoss"
    floatingText.Size = UDim2.new(0, 150, 0, 40)
    floatingText.Position = UDim2.new(0.5, -75, 0.4, 0)
    floatingText.BackgroundTransparency = 1
    floatingText.Text = "-$" .. self:FormatNumber(amount)
    floatingText.TextColor3 = Color3.fromRGB(255, 80, 80)
    floatingText.TextScaled = true
    floatingText.Font = Enum.Font.GothamBold
    floatingText.TextStrokeTransparency = 0.5
    floatingText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    floatingText.Parent = mainHUD
    
    -- Animation: descendre et disparaître
    local tweenDown = TweenService:Create(floatingText, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -75, 0.6, 0),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })
    
    tweenDown:Play()
    tweenDown.Completed:Connect(function()
        floatingText:Destroy()
    end)
end

--[[
    Met à jour l'affichage de l'argent avec animation
    @param newCash: number
    @param oldCash: number | nil
]]
function UIController:UpdateCashAnimated(newCash, oldCash)
    oldCash = oldCash or currentPlayerData.Cash
    
    local difference = newCash - oldCash
    
    -- Mettre à jour l'affichage
    self:UpdateCash(newCash)
    
    -- Animer si changement significatif
    if difference > 0 then
        self:AnimateCashGain(difference)
    elseif difference < 0 then
        self:AnimateCashLoss(math.abs(difference))
    end
end
```

---

## B3.5 - EconomyController.module.lua

### Description
Contrôleur client pour les interactions économiques.

**✅ DÉJÀ CRÉÉ !** Le fichier `EconomyController.module.lua` existe déjà avec toutes les fonctionnalités.

### Fichier : `StarterPlayerScripts/EconomyController.module.lua`

**Note:** Ce fichier est déjà créé et fonctionnel. Il attend seulement les UI Studio.

```lua
--[[
    EconomyController.lua (ModuleScript)
    Gère les interactions économiques côté client
    
    Responsabilités:
    - Gérer l'UI du ShopUI
    - Gérer les interactions ProximityPrompt du SlotShop
    - Mettre à jour les affichages des CollectPads
    - Animations économiques
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = ReplicatedStorage:WaitForChild("Config")

local Constants = require(Shared:WaitForChild("Constants.module"))
local GameConfig = require(Config:WaitForChild("GameConfig.module"))
local Data = ReplicatedStorage:WaitForChild("Data")
local SlotPrices = require(Data:WaitForChild("SlotPrices.module"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local buySlot = Remotes:WaitForChild("BuySlot")
local collectSlotCash = Remotes:WaitForChild("CollectSlotCash")

-- UI Elements
local shopUI = playerGui:WaitForChild("ShopUI")
local shopBackground = shopUI:WaitForChild("Background")
local shopTitle = shopBackground:WaitForChild("Title")
local shopCurrentSlots = shopBackground:WaitForChild("CurrentSlots")
local shopPriceLabel = shopBackground:WaitForChild("PriceDisplay"):WaitForChild("PriceLabel")
local shopBuyButton = shopBackground:WaitForChild("BuyButton")
local shopCloseButton = shopBackground:WaitForChild("CloseButton")

-- État local
local currentOwnedSlots = 1
local currentSlotCash = {}
local isShopOpen = false

local EconomyController = {}

--[[
    Initialise le contrôleur
    @param uiController: module - Référence à UIController
]]
function EconomyController:Init(uiController)
    self._uiController = uiController
    
    -- Connecter les boutons du shop
    shopBuyButton.MouseButton1Click:Connect(function()
        self:OnBuyButtonClicked()
    end)
    
    shopCloseButton.MouseButton1Click:Connect(function()
        self:CloseShop()
    end)
    
    print("[EconomyController] Initialisé!")
end

-- ═══════════════════════════════════════════════════════
-- SHOP UI
-- ═══════════════════════════════════════════════════════

--[[
    Ouvre le menu du shop
]]
function EconomyController:OpenShop()
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
    
    print("[EconomyController] Shop ouvert")
end

--[[
    Ferme le menu du shop
]]
function EconomyController:CloseShop()
    if not isShopOpen then return end
    
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
    
    print("[EconomyController] Shop fermé")
end

--[[
    Met à jour l'affichage du shop
]]
function EconomyController:UpdateShopDisplay()
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
    print("[EconomyController] Bouton Acheter cliqué")
    
    -- Vérifier si on peut acheter (localement)
    local nextSlot = currentOwnedSlots + 1
    if nextSlot > GameConfig.Base.MaxSlots then
        return
    end
    
    -- Envoyer la requête au serveur
    buySlot:FireServer()
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
function EconomyController:UpdateCollectPads(slotCash)
    currentSlotCash = slotCash or {}
    
    if not playerBase then return end
    
    local slotsFolder = playerBase:FindFirstChild("Slots")
    if not slotsFolder then return end
    
    for _, slot in ipairs(slotsFolder:GetChildren()) do
        if slot:IsA("Model") then
            local slotIndex = slot:GetAttribute("SlotIndex")
            if slotIndex then
                local collectPad = slot:FindFirstChild("CollectPad")
                if collectPad then
                    local surfaceGui = collectPad:FindFirstChild("SurfaceGui")
                    if surfaceGui then
                        -- Cacher l'affichage des slots des étages non débloqués
                        local isUnlocked = (slotIndex <= currentOwnedSlots)
                        surfaceGui.Enabled = isUnlocked
                        
                        if isUnlocked then
                            local cashLabel = surfaceGui:FindFirstChild("CashLabel")
                            if cashLabel then
                                local amount = currentSlotCash[slotIndex] or 0
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
    
    print("[EconomyController] CollectPads mis à jour")
end

--[[
    Demande la collecte d'un slot spécifique
    @param slotIndex: number
]]
function EconomyController:RequestCollectSlot(slotIndex)
    print("[EconomyController] Demande collecte slot " .. slotIndex)
    collectSlotCash:FireServer(slotIndex)
end

--[[
    Demande la collecte de tous les slots
]]
function EconomyController:RequestCollectAll()
    print("[EconomyController] Demande collecte tous les slots")
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
    print("[EconomyController] Étage " .. floorNumber .. " débloqué!")
    
    -- Notification + TODO: animation spéciale (particules, etc.)
    if self._uiController then
        self._uiController:ShowNotification("Success", "Étage " .. floorNumber .. " débloqué ! 🎉", 5)
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
```

---

## B3.6 - Mise à jour ClientMain

### Description
Intégrer EconomyController et gérer les ProximityPrompts.

**✅ DÉJÀ FAIT !** Les modifications suivantes ont été appliquées :
- Import d'EconomyController
- Initialisation d'EconomyController
- Gestion des ProximityPrompts (SlotShop et CollectPads)
- Animations automatiques lors des changements d'argent

### Modifications : `StarterPlayerScripts/ClientMain.client.lua`

**Note:** Ces modifications sont déjà appliquées dans le fichier.

**Ajouter après les require existants :**

```lua
-- Contrôleurs
local UIController = require(script.Parent:WaitForChild("UIController"))
local EconomyController = require(script.Parent:WaitForChild("EconomyController")) -- NOUVEAU

-- Si DoorController existe
local DoorController = nil
pcall(function()
    DoorController = require(script.Parent:WaitForChild("DoorController"))
end)
```

**Ajouter dans la section d'initialisation :**

```lua
-- Initialiser EconomyController
EconomyController:Init(UIController)
```

**Modifier le handler SyncPlayerData pour inclure l'économie :**

```lua
-- SyncPlayerData: Reçoit les mises à jour des données joueur
syncPlayerData.OnClientEvent:Connect(function(data)
    print("[ClientMain] SyncPlayerData reçu")
    UIController:UpdateAll(data)
    
    -- Mettre à jour EconomyController avec les données pertinentes
    if data.OwnedSlots or data.SlotCash or data.UnlockedFloor then
        EconomyController:UpdateData(data)
    end
end)
```

**Ajouter la gestion des ProximityPrompts pour le SlotShop :**

```lua
-- ═══════════════════════════════════════════════════════
-- PROXIMITÉ SHOP (SlotShop dans la base)
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
            print("[ClientMain] SlotShop ProximityPrompt déclenché")
            EconomyController:OpenShop()
        end
    end
    
    -- Vérifier si c'est un CollectPad (pour collecter l'argent d'un slot)
    if parent and parent.Name == "CollectPad" then
        local slot = parent.Parent
        if slot then
            local slotIndex = slot:GetAttribute("SlotIndex")
            if slotIndex then
                print("[ClientMain] CollectPad ProximityPrompt déclenché pour slot " .. slotIndex)
                EconomyController:RequestCollectSlot(slotIndex)
            end
        end
    end
end)
```

---

## B3.7 - Sons (Optionnel)

### Description
Ajouter des effets sonores pour les interactions économiques (collecte d’argent, achat de slot, déblocage d’étage, erreur « pas assez d’argent »). Les sons sont joués côté **client** pour éviter la latence et garder le gameplay réactif.

---

### 1. Structure dans Roblox Studio

1. **Créer le dossier des sons**
   - Dans **ReplicatedStorage**, créer un **Folder** nommé `Assets`.
   - Dans `Assets`, créer un **Folder** nommé `Sounds`.

2. **Créer ou importer les Sound**
   - Dans `ReplicatedStorage/Assets/Sounds`, créer **4 instances Sound** (clic droit > Insert Object > Sound).
   - Nommer chaque Sound exactement comme ci‑dessous (le code les retrouve par nom).

| Nom de l’instance | Déclencheur | Volume suggéré | SoundId |
|-------------------|-------------|----------------|---------|
| `CashCollect`     | Collecte d’argent (marcher sur CollectPad) | 0.5 | À définir (voir ci‑dessous) |
| `SlotBuy`         | Achat d’un slot réussi | 0.7 | À définir |
| `FloorUnlock`     | Déblocage d’un étage (11 ou 21 slots) | 0.8 | À définir |
| `NotEnoughMoney`  | Erreur « Pas assez d’argent » | 0.4 | À définir |

3. **Configurer chaque Sound**
   - **SoundId** : soit importer un fichier audio (clic droit sur le Sound > Import), soit mettre un ID Roblox (ex. `rbxassetid://123456789`). Pour des placeholders, tu peux utiliser des sons de la bibliothèque Roblox (Catalog > Audio).
   - **Volume** : valeur indiquée dans le tableau (ex. `0.5`).
   - **Looped** : `false` pour tous.
   - **RollOffMode** : laisser par défaut (les sons dans ReplicatedStorage seront clonés et joués dans le client, pas en 3D).

---

### 2. Où jouer chaque son (côté client)

| Son | Moment | Fichier / fonction |
|-----|--------|---------------------|
| **CashCollect** | Quand le serveur envoie la notification « +$X collecté! » | Dans le handler du Remote `Notification` : si `data.Type == "Success"` et `data.Message` contient `"collecté"`, jouer `CashCollect`. |
| **SlotBuy** | Quand l’achat d’un slot réussit (notification Success type « Slot X acheté ») | Même handler `Notification` : si message contient `"acheté"` (ou `"Slot"`), jouer `SlotBuy`. |
| **NotEnoughMoney** | Quand le serveur envoie une erreur « Pas assez d’argent » | Handler `Notification` : si `data.Type == "Error"` et message contient `"argent"`, jouer `NotEnoughMoney`. |
| **FloorUnlock** | Quand un étage est débloqué (11 ou 21 slots) | Dans `EconomyController:OnFloorUnlocked(floorNumber)` : jouer `FloorUnlock` au début de la fonction. |

---

### 3. Helper pour jouer un son (ReplicatedStorage)

Créer un **ModuleScript** dans `ReplicatedStorage/Shared` nommé `SoundHelper.module.lua` (ou un autre nom cohérent avec ton projet). Ce module centralise la lecture des sons pour éviter de dupliquer le code.

```lua
--[[
    SoundHelper.module.lua
    Joue des sons depuis ReplicatedStorage/Assets/Sounds par nom.
    Usage: SoundHelper.Play("CashCollect")
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:FindFirstChild("Assets")
local SoundsFolder = Assets and Assets:FindFirstChild("Sounds")
if not SoundsFolder then
    warn("[SoundHelper] ReplicatedStorage/Assets/Sounds non trouvé")
end

local SoundHelper = {}

function SoundHelper.Play(soundName)
    if not SoundsFolder then return end
    local template = SoundsFolder:FindFirstChild(soundName)
    if not template or not template:IsA("Sound") then
        warn("[SoundHelper] Son non trouvé: " .. tostring(soundName))
        return
    end
    local sound = template:Clone()
    sound.Parent = game:GetService("SoundService")
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
end

return SoundHelper
```

---

### 4. Brancher les sons dans le client

**4.1 Notification (CashCollect, SlotBuy, NotEnoughMoney)**

Dans **ClientMain.client.lua**, là où le Remote `Notification` est connecté, charger le SoundHelper et appeler `SoundHelper.Play(...)` selon le type et le message :

```lua
-- En haut avec les autres requires
local SoundHelper = nil
local ok, mod = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundHelper.module"))
end)
if ok then SoundHelper = mod end

-- Dans le handler de Notification (à l’endroit où tu appelles UIController:ShowNotification)
notification.OnClientEvent:Connect(function(data)
    print("[ClientMain] Notification received: " .. data.Type .. " - " .. data.Message)
    UIController:ShowNotification(data.Type, data.Message, data.Duration)
    -- Sons économiques (optionnel)
    if SoundHelper then
        local msg = data.Message or ""
        if data.Type == "Success" then
            if string.find(msg, "collecté") then
                SoundHelper.Play("CashCollect")
            elseif string.find(msg, "acheté") or string.find(msg, "Slot") then
                SoundHelper.Play("SlotBuy")
            end
        elseif data.Type == "Error" and string.find(msg, "argent") then
            SoundHelper.Play("NotEnoughMoney")
        end
    end
end)
```

**4.2 Déblocage d’étage (FloorUnlock)**

Dans **EconomyController.module.lua** :

- En haut du fichier (avec les autres `require`), ajouter optionnellement :  
  `local SoundHelper = require(Shared:WaitForChild("SoundHelper.module"))`  
  (avec un `pcall` si le module est optionnel, pour ne pas bloquer si `SoundHelper` n’existe pas.)
- Dans `OnFloorUnlocked`, appeler le son après la notification :

```lua
function EconomyController:OnFloorUnlocked(floorNumber)
    print("[EconomyController] Étage " .. floorNumber .. " débloqué!")
    if self._uiController then
        self._uiController:ShowNotification("Success", "Étage " .. floorNumber .. " débloqué ! 🎉", 5)
    end
    if SoundHelper then SoundHelper.Play("FloorUnlock") end
end
```

---

### 5. Récap et checklist

- [ ] Créer `ReplicatedStorage/Assets/Sounds` et les 4 Sound (`CashCollect`, `SlotBuy`, `FloorUnlock`, `NotEnoughMoney`).
- [ ] Renseigner les **SoundId** (import ou `rbxassetid://...`) et les **Volume**.
- [ ] Créer `SoundHelper.module.lua` dans `Shared` et l’utiliser pour `Play(nom)`.
- [ ] Dans **ClientMain** : dans le handler de `Notification`, appeler `SoundHelper.Play("CashCollect")`, `"SlotBuy"` ou `"NotEnoughMoney"` selon le type/message.
- [ ] Dans **EconomyController:OnFloorUnlocked** : appeler `SoundHelper.Play("FloorUnlock")`.

Si `Assets/Sounds` n’existe pas ou qu’un son manque, le SoundHelper peut simplement ne rien faire (ou afficher un `warn`), sans faire planter le jeu.

---

# POINT DE SYNCHRONISATION 3

## Checklist de Test

### Backend (DEV A)
- [x] EconomySystem se charge sans erreur ✅
- [x] Revenue loop génère des revenus toutes les secondes ✅
- [x] AddCash ajoute correctement l'argent ✅
- [x] RemoveCash retire correctement l'argent ✅
- [x] CanAfford fonctionne correctement ✅
- [x] BuyNextSlot débite et incrémente OwnedSlots ✅
- [x] CheckFloorUnlock détecte les seuils (11, 21) ✅
- [x] Handlers BuySlot et CollectSlotCash fonctionnent ✅

### Frontend (DEV B - Code)
- [x] EconomyController créé et fonctionnel ✅
- [x] Animations argent implémentées ✅
- [x] Intégration ClientMain complétée ✅
- [x] Gestion ProximityPrompts implémentée ✅
- [x] Mise à jour dynamique Display SlotShop ✅
- [x] Mise à jour dynamique CollectPads ✅

### Frontend (DEV B - Studio)
- [ ] ShopUI créé dans StarterGui ⏳
- [ ] ShopUI s'affiche correctement ⏳
- [ ] ShopUI s'ouvre/ferme avec animations ⏳
- [ ] Prix du prochain slot affiché correctement ⏳
- [ ] Bouton Acheter envoie la requête ⏳
- [ ] CollectPads créés avec SurfaceGui ⏳
- [ ] CollectPads affichent l'argent accumulé ⏳
- [ ] CollectPads des étages non débloqués masqués (SurfaceGui.Enabled = false) ⏳

### Simulation manuelle (sans Phase 5 – rien à placer)

Pour tester la Phase 3 sans avoir de Brainrot à placer, utilise le **TEST SERVER** (scripts `TEST_SERVER_HANDLER.server.lua` et `TEST_SERVER.client.lua`).

1. **S'assurer que les scripts de test sont en place**
   - `ServerScriptService/TEST_SERVER_HANDLER.server.lua`
   - `StarterPlayer/StarterPlayerScripts/` ou le dossier où tu mets le client : un **LocalScript** qui crée l’UI de test et appelle le Remote `TestServerData` (comme dans `TEST_SERVER.client.lua` du repo).

2. **Deux façons de simuler :**

   - **+ $50 SlotCash (slot 1)**  
     Envoie au serveur `AddSlotCash` avec la valeur `50`.  
     → Le slot 1 reçoit 50 $ de SlotCash, le CollectPad du slot 1 doit afficher ce montant. Tu peux ensuite tester la collecte (marcher sur le CollectPad).

   - **Simulate Brainrot (slot 1)**  
     Envoie au serveur `SimulateBrainrot` avec le slot index `1`.  
     → Un faux Brainrot est ajouté sur le slot 1. La **revenue loop** du serveur ajoute alors environ 5 $/s (voir `GameConfig.Economy.RevenuePerBrainrot`) au SlotCash du slot 1. Attendre quelques secondes puis vérifier le CollectPad et la collecte.

3. **Boutons dans l’UI de test (ex. TEST_SERVER.client.lua)**  
   - `+ $50 SlotCash (slot 1, Phase 3)` → `FireServer("AddSlotCash", 50)`  
   - `Simulate Brainrot (slot 1, revenue)` → `FireServer("SimulateBrainrot", 1)`

4. **Show Data**  
   Le bouton « Show Current Data » affiche aussi `SlotCash` et si des PlacedBrainrots sont présents, pour vérifier l’état côté serveur.

### Test d'Intégration
1. [ ] Placer un Brainrot (Phase 5) ou simuler avec **AddSlotCash** / **Simulate Brainrot** (ci‑dessus)
2. [ ] Attendre quelques secondes (si tu as utilisé Simulate Brainrot)
3. [ ] Vérifier que SlotCash augmente
4. [ ] Collecter l'argent (marcher sur CollectPad)
5. [ ] Vérifier que Cash augmente
6. [ ] Ouvrir le SlotShop (ProximityPrompt)
7. [ ] Acheter un slot
8. [ ] Vérifier que Cash diminue et OwnedSlots augmente
9. [ ] Acheter jusqu'à 11 slots
10. [ ] Vérifier que Floor_1 se débloque
11. [ ] Vérifier que les CollectPads du nouvel étage deviennent visibles
12. [ ] Continuer jusqu'à 21 slots
13. [ ] Vérifier que Floor_2 se débloque

---

# RÉCAPITULATIF DES FICHIERS

## DEV A - Backend

| Fichier | Emplacement | Status |
|---------|-------------|--------|
| `EconomySystem.module.lua` | `ServerScriptService/Systems/` | ✅ CRÉÉ |
| `NetworkHandler.module.lua` | `ServerScriptService/Handlers/` | ✅ MODIFIÉ |
| `GameServer.server.lua` | `ServerScriptService/Core/` | ✅ MODIFIÉ |

## DEV B - Frontend

| Fichier | Emplacement | Status |
|---------|-------------|--------|
| `ShopUI` (ScreenGui) | `StarterGui/` | ⏳ À créer (Studio) |
| `CollectPad SurfaceGui` | Dans chaque Base | ⏳ À créer (Studio) |
| `UIController.module.lua` | `StarterPlayerScripts/` | ✅ MODIFIÉ |
| `EconomyController.module.lua` | `StarterPlayerScripts/` | ✅ CRÉÉ |
| `ClientMain.client.lua` | `StarterPlayerScripts/` | ✅ MODIFIÉ |

**Note:** Tous les scripts sont créés et fonctionnels. Il ne reste que la création des UI dans Studio.  
**CollectPads :** Le script masque automatiquement le SurfaceGui des CollectPads des étages non débloqués (`surfaceGui.Enabled = false` pour les slots dont l'index > `currentOwnedSlots`).

---

# DIAGRAMME DE FLUX ÉCONOMIQUE

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FLUX ÉCONOMIQUE - REVENUS                         │
└─────────────────────────────────────────────────────────────────────┘

     ┌───────────────────┐
     │ Brainrot Placé    │
     │ sur Slot #X       │
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ Revenue Loop      │  (toutes les X secondes)
     │ EconomySystem     │
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ +$5 → SlotCash[X] │  (par Brainrot)
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ SyncSlotCash      │
     │ vers Client       │
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ CollectPad        │
     │ affiche montant   │
     └─────────┬─────────┘
               │
               │ (Joueur marche sur CollectPad)
               ▼
     ┌───────────────────┐
     │ CollectSlotCash   │
     │ Remote Event      │
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ SlotCash[X] → 0   │
     │ Cash += montant   │
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ SyncCash + Notif  │
     │ Animation client  │
     └───────────────────┘
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FLUX ÉCONOMIQUE - ACHAT SLOT                      │
└─────────────────────────────────────────────────────────────────────┘

     ┌───────────────────┐
     │ Joueur approche   │
     │ du SlotShop       │
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ ProximityPrompt   │
     │ déclenché         │
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ ShopUI s'ouvre    │
     │ Prix affiché      │
     └─────────┬─────────┘
               │
               │ (Joueur clique ACHETER)
               ▼
     ┌───────────────────┐
     │ BuySlot Remote    │
     │ vers Serveur      │
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ VALIDATIONS:      │
     │ - Max slots?      │
     │ - Assez d'argent? │
     └─────────┬─────────┘
               │
               ├── [ÉCHEC] → Notification Erreur
               │
               ▼ [SUCCÈS]
     ┌───────────────────┐
     │ Cash -= prix      │
     │ OwnedSlots += 1   │
     └─────────┬─────────┘
               │
               ▼
     ┌───────────────────┐
     │ CheckFloorUnlock  │
     │ (11 ou 21 slots?) │
     └─────────┬─────────┘
               │
               ├── [OUI] → BaseSystem:UnlockFloor()
               │           → Notification "Étage débloqué!"
               ▼
     ┌───────────────────┐
     │ SyncOwnedSlots    │
     │ Notification OK   │
     │ UI mise à jour    │
     └───────────────────┘
```

---

# PROCHAINE ÉTAPE : PHASE 4

Après validation de la Phase 3, passer à la Phase 4 :
- **DEV A** : ArenaSystem, InventorySystem
- **DEV B** : Setup Arena Studio, ArenaController

---

**Fin du Guide Phase 3**
