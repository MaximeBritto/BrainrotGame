# PHASE 5 : CRAFTING & PLACEMENT - Guide Complet et Détaillé

**Date:** 2026-02-04  
**Status:** À faire (Phase 4 complétée)  
**Prérequis:** Phases 0, 1, 2, 3 et 4 complétées (SYNC 4 validé)

---

## Vue d'ensemble

La Phase 5 met en place le **système de crafting** et le **placement de Brainrots** :
- **DEV A** : Backend Crafting (CraftingSystem, PlacementSystem, validations, déblocage Codex, handlers)
- **DEV B** : Frontend Crafting (bouton Craft, animations, feedback visuel, notifications)

### Objectif final de la Phase 5

- Le joueur peut crafter un Brainrot en combinant 3 pièces (Head, Body, Legs)
- Le système valide que les 3 types sont différents
- Le Brainrot est automatiquement placé dans le premier slot libre
- Le set est débloqué dans le Codex
- Bonus si les 3 pièces sont du même set (set complet)
- L'inventaire est vidé après le craft
- L'UI est mise à jour en temps réel

---

## Résumé des tâches

### DEV A - Backend Crafting & Placement

| #   | Tâche                 | Dépendance | Fichier                                      | Temps estimé |
|-----|------------------------|------------|----------------------------------------------|--------------|
| A5.1 | CraftingSystem (base)  | Aucune     | `Systems/CraftingSystem.module.lua`           | 1h30         |
| A5.2 | PlacementSystem        | A5.1       | `Systems/PlacementSystem.module.lua`          | 1h           |
| A5.3 | Validation craft       | A5.1       | CraftingSystem                                | 30min        |
| A5.4 | Déblocage Codex        | A5.1       | CraftingSystem + DataService                  | 30min        |
| A5.5 | Handler Craft          | A5.1–A5.4  | `Handlers/NetworkHandler.module.lua`          | 30min        |
| A5.6 | Intégration GameServer | A5.1–A5.5  | `Core/GameServer.server.lua`                  | 20min        |

**Total DEV A :** ~4h30

### DEV B - Frontend Crafting

| #   | Tâche                 | Dépendance | Fichier / Lieu                         | Temps estimé |
|-----|------------------------|------------|----------------------------------------|--------------|
| B5.1 | Activation bouton Craft | Aucune    | UIController                           | 30min        |
| B5.2 | Animation craft        | B5.1       | UIController                           | 45min        |
| B5.3 | Notifications          | B5.1       | UIController                           | 30min        |
| B5.4 | Mise à jour UI         | B5.1–B5.3  | UIController + ClientMain              | 30min        |

**Total DEV B :** ~2h15

---

# DEV A - BACKEND CRAFTING & PLACEMENT

## A5.1 - CraftingSystem.module.lua (Base)

### Description

Service qui gère la logique de crafting : validation des pièces, création du Brainrot, déblocage Codex, bonus de set complet.

### Dépendances

- `ServerScriptService/Core/PlayerService`
- `ServerScriptService/Core/DataService`
- `ServerScriptService/Systems/InventorySystem`
- `ServerScriptService/Systems/PlacementSystem`
- `ReplicatedStorage/Config/GameConfig`
- `ReplicatedStorage/Data/BrainrotData`
- `ReplicatedStorage/Shared/Constants`

### Constantes à utiliser

- `GameConfig.Economy.SetCompletionBonus` — bonus pour set complet (1000)
- `Constants.ActionResult` — Success, MissingPieces, NoSlotAvailable
- `Constants.PieceType` — Head, Body, Legs

### Fichier : `ServerScriptService/Systems/CraftingSystem.module.lua`

**Responsabilités :**

1. **ValidateCraft(pieces)**  
   - Vérifier qu'il y a exactement 3 pièces
   - Vérifier que les 3 types sont présents (Head, Body, Legs)
   - Retourner `valid (boolean), errorMessage (string)`

2. **IsCompleteSet(pieces)**  
   - Vérifier si les 3 pièces ont le même `SetName`
   - Retourner `boolean`

3. **TryCraft(player)**  
   - Récupérer les pièces en main via `InventorySystem:GetPiecesInHand(player)`
   - Valider avec `ValidateCraft(pieces)`
   - Si invalide : retourner erreur
   - Trouver un slot libre via `PlacementSystem:FindAvailableSlot(player)`
   - Si pas de slot : retourner `NoSlotAvailable`
   - Déterminer le set crafté (prendre le SetName majoritaire ou le premier)
   - Créer les données du Brainrot : `{ SetName, SlotIndex, PlacedAt = os.time() }`
   - Placer via `PlacementSystem:PlaceBrainrot(player, slotIndex, brainrotData)`
   - Débloquer le set dans le Codex via `DataService:UnlockCodexEntry(player, setName)`
   - Si set complet : ajouter bonus `GameConfig.Economy.SetCompletionBonus`
   - Vider l'inventaire via `InventorySystem:ClearInventory(player)`
   - Retourner `Success` + données du craft (setName, slotIndex, bonus)

4. **GetCraftableSet(pieces)**  
   - Déterminer quel set sera crafté
   - Si set complet : retourner ce SetName
   - Sinon : retourner le SetName le plus fréquent ou "Mixed"

### Structure recommandée

```lua
--[[
    CraftingSystem.module.lua
    Gestion du crafting de Brainrots
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = nil
local BrainrotData = nil
local Constants = nil
local DataService = nil
local PlayerService = nil
local InventorySystem = nil
local PlacementSystem = nil

local CraftingSystem = {}
CraftingSystem._initialized = false

function CraftingSystem:Init(services)
    if self._initialized then
        warn("[CraftingSystem] Déjà initialisé!")
        return
    end
    
    print("[CraftingSystem] Initialisation...")
    
    -- Récupérer les services injectés
    DataService = services.DataService
    PlayerService = services.PlayerService
    InventorySystem = services.InventorySystem
    PlacementSystem = services.PlacementSystem
    
    -- Charger les modules de config
    local Config = ReplicatedStorage:WaitForChild("Config")
    local Data = ReplicatedStorage:WaitForChild("Data")
    local Shared = ReplicatedStorage:WaitForChild("Shared")
    
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    BrainrotData = require(Data:WaitForChild("BrainrotData.module"))
    Constants = require(Shared:WaitForChild("Constants.module"))
    
    self._initialized = true
    print("[CraftingSystem] Initialisé")
end

function CraftingSystem:ValidateCraft(pieces)
    -- Vérifier 3 pièces
    if #pieces ~= 3 then
        return false, "Need exactly 3 pieces"
    end
    
    -- Vérifier les 3 types
    local hasHead = false
    local hasBody = false
    local hasLegs = false
    
    for _, piece in ipairs(pieces) do
        if piece.PieceType == Constants.PieceType.Head then hasHead = true end
        if piece.PieceType == Constants.PieceType.Body then hasBody = true end
        if piece.PieceType == Constants.PieceType.Legs then hasLegs = true end
    end
    
    if not (hasHead and hasBody and hasLegs) then
        return false, "Need Head, Body and Legs"
    end
    
    return true, nil
end

function CraftingSystem:IsCompleteSet(pieces)
    if #pieces ~= 3 then return false end
    
    local setName = pieces[1].SetName
    for i = 2, 3 do
        if pieces[i].SetName ~= setName then
            return false
        end
    end
    
    return true
end

function CraftingSystem:GetCraftableSet(pieces)
    -- Si set complet, retourner le SetName
    if self:IsCompleteSet(pieces) then
        return pieces[1].SetName
    end
    
    -- Sinon, compter les occurrences
    local counts = {}
    for _, piece in ipairs(pieces) do
        counts[piece.SetName] = (counts[piece.SetName] or 0) + 1
    end
    
    -- Retourner le plus fréquent
    local maxCount = 0
    local maxSet = "Mixed"
    for setName, count in pairs(counts) do
        if count > maxCount then
            maxCount = count
            maxSet = setName
        end
    end
    
    return maxSet
end

function CraftingSystem:TryCraft(player)
    if not self._initialized then
        return false, Constants.ActionResult.InvalidPiece, nil
    end
    
    -- 1. Récupérer les pièces en main
    local pieces = InventorySystem:GetPiecesInHand(player)
    
    -- 2. Valider
    local valid, errorMsg = self:ValidateCraft(pieces)
    if not valid then
        return false, Constants.ActionResult.MissingPieces, nil
    end
    
    -- 3. Trouver un slot libre
    local slotIndex = PlacementSystem:FindAvailableSlot(player)
    if not slotIndex then
        return false, Constants.ActionResult.NoSlotAvailable, nil
    end
    
    -- 4. Déterminer le set crafté
    local setName = self:GetCraftableSet(pieces)
    local isCompleteSet = self:IsCompleteSet(pieces)
    
    -- 5. Créer les données du Brainrot
    local brainrotData = {
        SetName = setName,
        SlotIndex = slotIndex,
        PlacedAt = os.time(),
    }
    
    -- 6. Placer le Brainrot
    local placed = PlacementSystem:PlaceBrainrot(player, slotIndex, brainrotData)
    if not placed then
        return false, Constants.ActionResult.NoSlotAvailable, nil
    end
    
    -- 7. Débloquer dans le Codex
    DataService:UnlockCodexEntry(player, setName)
    
    -- 8. Bonus si set complet
    local bonus = 0
    if isCompleteSet then
        bonus = GameConfig.Economy.SetCompletionBonus
        DataService:IncrementValue(player, "Cash", bonus)
        print("[CraftingSystem] Set complet! Bonus: $" .. bonus)
    end
    
    -- 9. Vider l'inventaire
    InventorySystem:ClearInventory(player)
    
    print("[CraftingSystem] " .. player.Name .. " a crafté: " .. setName .. " dans slot " .. slotIndex)
    
    return true, Constants.ActionResult.Success, {
        SetName = setName,
        SlotIndex = slotIndex,
        IsCompleteSet = isCompleteSet,
        Bonus = bonus,
    }
end

return CraftingSystem
```

---

## A5.2 - PlacementSystem.module.lua

### Description

Service qui gère le placement des Brainrots dans les slots de la base du joueur.

### Dépendances

- `ServerScriptService/Core/DataService`
- `ServerScriptService/Core/PlayerService`
- `ServerScriptService/Systems/BaseSystem`
- `ReplicatedStorage/Config/GameConfig`

### Fichier : `ServerScriptService/Systems/PlacementSystem.module.lua`

**Responsabilités :**

1. **FindAvailableSlot(player)**  
   - Récupérer `OwnedSlots` du joueur via `DataService:GetPlayerData(player)`
   - Récupérer `PlacedBrainrots` (table `{[slotIndex] = brainrotData}`)
   - Parcourir de 1 à `OwnedSlots`
   - Retourner le premier index où `PlacedBrainrots[index]` est nil
   - Si aucun slot libre : retourner nil

2. **PlaceBrainrot(player, slotIndex, brainrotData)**  
   - Vérifier que le slot est libre
   - Vérifier que le joueur possède ce slot (slotIndex <= OwnedSlots)
   - Ajouter dans `PlacedBrainrots[slotIndex] = brainrotData`
   - Sauvegarder via `DataService:SetValue(player, "PlacedBrainrots", placedBrainrots)`
   - Créer le modèle visuel dans la base (Phase 6 - optionnel pour Phase 5)
   - Retourner `true` si succès, `false` sinon

3. **RemoveBrainrot(player, slotIndex)**  
   - Retirer de `PlacedBrainrots[slotIndex]`
   - Détruire le modèle visuel
   - Sauvegarder
   - Retourner `true` si succès

### Structure recommandée

```lua
--[[
    PlacementSystem.module.lua
    Gestion du placement des Brainrots dans les slots
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = nil
local DataService = nil
local PlayerService = nil
local BaseSystem = nil

local PlacementSystem = {}
PlacementSystem._initialized = false

function PlacementSystem:Init(services)
    if self._initialized then
        warn("[PlacementSystem] Déjà initialisé!")
        return
    end
    
    print("[PlacementSystem] Initialisation...")
    
    DataService = services.DataService
    PlayerService = services.PlayerService
    BaseSystem = services.BaseSystem
    
    local Config = ReplicatedStorage:WaitForChild("Config")
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    
    self._initialized = true
    print("[PlacementSystem] Initialisé")
end

function PlacementSystem:FindAvailableSlot(player)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return nil end
    
    local ownedSlots = playerData.OwnedSlots or GameConfig.Base.StartingSlots
    local placedBrainrots = playerData.PlacedBrainrots or {}
    
    -- Trouver le premier slot libre
    for i = 1, ownedSlots do
        if not placedBrainrots[tostring(i)] then
            return i
        end
    end
    
    return nil -- Aucun slot libre
end

function PlacementSystem:PlaceBrainrot(player, slotIndex, brainrotData)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return false end
    
    local ownedSlots = playerData.OwnedSlots or GameConfig.Base.StartingSlots
    
    -- Vérifier que le joueur possède ce slot
    if slotIndex > ownedSlots then
        warn("[PlacementSystem] Slot " .. slotIndex .. " non possédé par " .. player.Name)
        return false
    end
    
    -- Vérifier que le slot est libre
    local placedBrainrots = playerData.PlacedBrainrots or {}
    if placedBrainrots[tostring(slotIndex)] then
        warn("[PlacementSystem] Slot " .. slotIndex .. " déjà occupé")
        return false
    end
    
    -- Placer le Brainrot
    placedBrainrots[tostring(slotIndex)] = brainrotData
    DataService:SetValue(player, "PlacedBrainrots", placedBrainrots)
    
    print("[PlacementSystem] Brainrot placé: " .. player.Name .. " slot " .. slotIndex)
    
    -- TODO Phase 6: Créer le modèle visuel dans la base
    
    return true
end

function PlacementSystem:RemoveBrainrot(player, slotIndex)
    local playerData = DataService:GetPlayerData(player)
    if not playerData then return false end
    
    local placedBrainrots = playerData.PlacedBrainrots or {}
    
    if not placedBrainrots[tostring(slotIndex)] then
        warn("[PlacementSystem] Aucun Brainrot dans slot " .. slotIndex)
        return false
    end
    
    -- Retirer le Brainrot
    placedBrainrots[tostring(slotIndex)] = nil
    DataService:SetValue(player, "PlacedBrainrots", placedBrainrots)
    
    print("[PlacementSystem] Brainrot retiré: " .. player.Name .. " slot " .. slotIndex)
    
    return true
end

return PlacementSystem
```

---

## A5.3 - Validation craft

Les validations sont déjà implémentées dans `CraftingSystem:ValidateCraft(pieces)` :

1. ✅ Exactement 3 pièces
2. ✅ Les 3 types différents (Head, Body, Legs)

---

## A5.4 - Déblocage Codex

Le déblocage Codex est géré dans `CraftingSystem:TryCraft` via :

```lua
DataService:UnlockCodexEntry(player, setName)
```

Il faut ajouter cette méthode dans **DataService** :

### Ajout dans DataService.module.lua

```lua
--[[
    Débloque une entrée du Codex
    @param player: Player
    @param setName: string
]]
function DataService:UnlockCodexEntry(player, setName)
    local playerData = self:GetPlayerData(player)
    if not playerData then return false end
    
    -- Initialiser CodexUnlocked si nécessaire
    if not playerData.CodexUnlocked then
        playerData.CodexUnlocked = {}
    end
    
    -- Vérifier si déjà débloqué
    if playerData.CodexUnlocked[setName] then
        return false -- Déjà débloqué
    end
    
    -- Débloquer
    playerData.CodexUnlocked[setName] = true
    
    print("[DataService] Codex débloqué: " .. player.Name .. " - " .. setName)
    
    return true
end
```

---

## A5.5 - Handler Craft

### À modifier : `ServerScriptService/Handlers/NetworkHandler.module.lua`

Remplacer le placeholder `_HandleCraft` :

```lua
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
```

N'oublie pas d'ajouter `CraftingSystem` dans les variables locales en haut du fichier et dans `UpdateSystems`.

---

## A5.6 - Intégration GameServer

### Fichier : `ServerScriptService/Core/GameServer.server.lua`

Après ArenaSystem et InventorySystem :

```lua
-- 10. CraftingSystem & PlacementSystem (Phase 5)
local CraftingSystem, craftingLoadErr
local PlacementSystem, placementLoadErr
do
    local ok, mod = pcall(function()
        return require(Systems["CraftingSystem.module"])
    end)
    if ok then
        CraftingSystem = mod
    else
        craftingLoadErr = mod
    end
end
do
    local ok, mod = pcall(function()
        return require(Systems["PlacementSystem.module"])
    end)
    if ok then
        PlacementSystem = mod
    else
        placementLoadErr = mod
    end
end

if CraftingSystem and PlacementSystem then
    PlacementSystem:Init({
        DataService = DataService,
        PlayerService = PlayerService,
        BaseSystem = BaseSystem,
    })
    print("[GameServer] PlacementSystem: OK")
    
    CraftingSystem:Init({
        DataService = DataService,
        PlayerService = PlayerService,
        InventorySystem = InventorySystem,
        PlacementSystem = PlacementSystem,
    })
    print("[GameServer] CraftingSystem: OK")
    
    NetworkHandler:UpdateSystems({
        CraftingSystem = CraftingSystem,
        PlacementSystem = PlacementSystem,
    })
else
    if not CraftingSystem then
        warn("[GameServer] CraftingSystem non chargé:", craftingLoadErr or "inconnu")
    end
    if not PlacementSystem then
        warn("[GameServer] PlacementSystem non chargé:", placementLoadErr or "inconnu")
    end
end
```

---

# DEV B - FRONTEND CRAFTING

## B5.1 - Activation bouton Craft

Le bouton Craft est déjà géré dans **UIController:UpdateInventory** :

```lua
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
        craftButton.Text = "Need 3 types"
    end
end
```

Le bouton est déjà connecté dans **ClientMain** :

```lua
local craftButton = UIController:GetCraftButton()
if craftButton then
    craftButton.MouseButton1Click:Connect(function()
        print("[ClientMain] Craft button clicked")
        craft:FireServer()
    end)
end
```

✅ Déjà implémenté !

---

## B5.2 - Animation craft

Ajouter une animation visuelle quand le craft est réussi. Dans **UIController**, ajouter :

```lua
--[[
    Animation de craft réussi
]]
function UIController:AnimateCraftSuccess()
    -- Animation du bouton Craft
    local originalSize = craftButton.Size
    local originalColor = craftButton.BackgroundColor3
    
    -- Flash vert
    craftButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    
    local tweenBig = TweenService:Create(craftButton, TweenInfo.new(0.2, Enum.EasingStyle.Bounce), {
        Size = UDim2.new(originalSize.X.Scale * 1.2, 0, originalSize.Y.Scale * 1.2, 0)
    })
    
    local tweenNormal = TweenService:Create(craftButton, TweenInfo.new(0.2), {
        Size = originalSize,
        BackgroundColor3 = originalColor,
    })
    
    tweenBig:Play()
    tweenBig.Completed:Wait()
    tweenNormal:Play()
    
    -- Masquer le bouton après craft
    craftButton.Visible = false
end
```

Appeler cette fonction depuis **ClientMain** quand une notification "crafted" est reçue.

---

## B5.3 - Notifications

Les notifications sont déjà gérées par le serveur via `NetworkHandler:_SendNotification`.

Le client les affiche via `UIController:ShowNotification`.

✅ Déjà implémenté !

---

## B5.4 - Mise à jour UI

Après un craft réussi, l'UI doit se mettre à jour :

1. ✅ Inventaire vide (via SyncInventory)
2. ✅ Cash mis à jour (via SyncPlayerData)
3. ✅ Bouton Craft masqué (via UpdateInventory)
4. ⏳ Slot occupé visible (Phase 6 - modèles visuels)

---

# SYNC 5 - Test Crafting Complet

## Checklist de validation

- [ ] Bouton Craft visible avec 3 pièces
- [ ] Bouton vert si 3 types différents, jaune sinon
- [ ] Clic sur Craft envoie la requête au serveur
- [ ] Validation serveur : 3 types différents
- [ ] Craft consomme les 3 pièces (inventaire vide)
- [ ] Brainrot placé dans le premier slot libre
- [ ] Notification "X Brainrot crafted!"
- [ ] Bonus "$1000" si set complet (3 pièces du même set)
- [ ] Codex débloqué pour le set crafté
- [ ] UI mise à jour (inventaire vide, cash +bonus)

---

# Récapitulatif des fichiers

| Rôle   | Fichier                                  | Action      |
|--------|------------------------------------------|------------|
| DEV A  | `ServerScriptService/Systems/CraftingSystem.module.lua`  | Créer      |
| DEV A  | `ServerScriptService/Systems/PlacementSystem.module.lua` | Créer      |
| DEV A  | `ServerScriptService/Core/DataService.module.lua`        | Modifier (UnlockCodexEntry) |
| DEV A  | `ServerScriptService/Handlers/NetworkHandler.module.lua` | Modifier (_HandleCraft) |
| DEV A  | `ServerScriptService/Core/GameServer.server.lua`         | Modifier (init systèmes) |
| DEV B  | `StarterPlayer/StarterPlayerScripts/UIController.module.lua` | Modifier (AnimateCraftSuccess) |
| DEV B  | `StarterPlayer/StarterPlayerScripts/ClientMain.client.lua` | Vérifier (déjà connecté) |

---

# Références rapides

- **GameConfig.Economy** : SetCompletionBonus = 1000
- **GameConfig.Base** : StartingSlots = 10
- **Constants.ActionResult** : Success, MissingPieces, NoSlotAvailable
- **Constants.PieceType** : Head, Body, Legs
- **BrainrotData.Sets** : [setName].Rarity, Head/Body/Legs
- **DataService** : UnlockCodexEntry, SetValue, GetPlayerData
- **InventorySystem** : GetPiecesInHand, ClearInventory
- **PlacementSystem** : FindAvailableSlot, PlaceBrainrot

---

**Fin du Guide Phase 5**
