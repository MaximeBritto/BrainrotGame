# PHASE 5.5 : VISUALISATION 3D DES PIÈCES - Guide Complet et Détaillé

**Date:** 2026-02-04  
**Status:** À faire (Phase 5 complétée)  
**Prérequis:** Phases 0, 1, 2, 3, 4 et 5 complétées

---

## Vue d'ensemble

La Phase 5.5 ajoute la **visualisation 3D des pièces** et l'**animation de craft** :
- **DEV A** : Backend Modèles (BrainrotModelSystem, création modèles dans slots)
- **DEV B** : Frontend Visualisation (pièces qui suivent le joueur, animation craft, déplacement vers slot)

### Objectif final de la Phase 5.5

- Les pièces en main s'affichent en 3D derrière le joueur
- Les pièces suivent le joueur en temps réel
- Quand on craft : animation d'assemblage des 3 pièces
- Le Brainrot crafté se déplace vers son slot dans la base
- Le Brainrot apparaît physiquement dans le slot
- Seul le propriétaire voit ses propres Brainrots

---

## Résumé des tâches

### DEV A - Backend Modèles 3D

| #   | Tâche                 | Dépendance | Fichier                                      | Temps estimé |
|-----|------------------------|------------|----------------------------------------------|--------------|
| A5.5.1 | BrainrotModelSystem    | Aucune     | `Systems/BrainrotModelSystem.module.lua`      | 2h           |
| A5.5.2 | Intégration Placement  | A5.5.1     | `Systems/PlacementSystem.module.lua`          | 30min        |
| A5.5.3 | Modèles 3D Studio      | Aucune     | ReplicatedStorage/Assets/Brainrots            | 1h (Studio)  |
| A5.5.4 | Visibilité par joueur  | A5.5.1     | BrainrotModelSystem                           | 30min        |

**Total DEV A :** ~4h

### DEV B - Frontend Visualisation

| #   | Tâche                 | Dépendance | Fichier / Lieu                         | Temps estimé |
|-----|------------------------|------------|----------------------------------------|--------------|
| B5.5.1 | PieceVisualization     | Aucune     | `PieceVisualizationController.module.lua` | 2h        |
| B5.5.2 | Positionnement pièces  | B5.5.1     | PieceVisualizationController           | 1h           |
| B5.5.3 | CraftAnimation         | B5.5.1     | `CraftAnimationController.module.lua`  | 2h           |
| B5.5.4 | BrainrotMovement       | B5.5.3     | `BrainrotMovementController.module.lua`| 1h30         |
| B5.5.5 | Intégration client     | B5.5.1-4   | ClientMain, ArenaController            | 30min        |

**Total DEV B :** ~7h

---

# DEV A - BACKEND MODÈLES 3D

## A5.5.1 - BrainrotModelSystem.module.lua

### Description

Service qui gère la création et la destruction des modèles 3D de Brainrots dans les slots des bases.

### Dépendances

- `ServerScriptService/Systems/BaseSystem`
- `ReplicatedStorage/Assets/Brainrots` (modèles 3D)
- `ReplicatedStorage/Data/BrainrotData`

### Fichier : `ServerScriptService/Systems/BrainrotModelSystem.module.lua`

**Responsabilités :**

1. **CreateBrainrotModel(player, slotIndex, brainrotData)**  
   - Récupérer la base du joueur via BaseSystem
   - Trouver le slot (Slot_X dans Slots folder)
   - Cloner le modèle 3D depuis ReplicatedStorage/Assets/Brainrots/[SetName]
   - Positionner le modèle sur la Platform du slot
   - Définir les attributs (SetName, SlotIndex, OwnerUserId)
   - Appliquer la visibilité (seul le propriétaire voit)
   - Stocker la référence (table interne)

2. **DestroyBrainrotModel(player, slotIndex)**  
   - Trouver le modèle dans le slot
   - Le détruire
   - Retirer de la table interne

3. **GetBrainrotModel(player, slotIndex)**  
   - Retourner le modèle 3D dans un slot

4. **ApplyOwnerVisibility(model, ownerUserId)**  
   - Utiliser LocalTransparencyModifier pour que seul le propriétaire voie
   - Ou utiliser un système de filtrage côté client

### Structure recommandée

```lua
--[[
    BrainrotModelSystem.module.lua
    Gestion des modèles 3D de Brainrots dans les slots
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BrainrotData = nil
local BaseSystem = nil

local BrainrotModelSystem = {}
BrainrotModelSystem._initialized = false
BrainrotModelSystem._models = {} -- [userId][slotIndex] = model

function BrainrotModelSystem:Init(services)
    if self._initialized then return end
    
    BaseSystem = services.BaseSystem
    
    local Data = ReplicatedStorage:WaitForChild("Data")
    BrainrotData = require(Data:WaitForChild("BrainrotData.module"))
    
    self._initialized = true
    print("[BrainrotModelSystem] Initialisé")
end

function BrainrotModelSystem:CreateBrainrotModel(player, slotIndex, brainrotData)
    -- 1. Récupérer la base du joueur
    local base = BaseSystem:GetPlayerBase(player)
    if not base then return false end
    
    -- 2. Trouver le slot
    local slotsFolder = base:FindFirstChild("Slots")
    if not slotsFolder then return false end
    
    local slot = slotsFolder:FindFirstChild("Slot_" .. slotIndex)
    if not slot then return false end
    
    local platform = slot:FindFirstChild("Platform")
    if not platform then return false end
    
    -- 3. Cloner le modèle 3D
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then return false end
    
    local brainrotsFolder = assetsFolder:FindFirstChild("Brainrots")
    if not brainrotsFolder then return false end
    
    local template = brainrotsFolder:FindFirstChild(brainrotData.SetName)
    if not template then
        warn("[BrainrotModelSystem] Modèle introuvable: " .. brainrotData.SetName)
        return false
    end
    
    local model = template:Clone()
    
    -- 4. Définir les attributs
    model:SetAttribute("SetName", brainrotData.SetName)
    model:SetAttribute("SlotIndex", slotIndex)
    model:SetAttribute("OwnerUserId", player.UserId)
    
    -- 5. Positionner sur la platform
    if model.PrimaryPart then
        model:SetPrimaryPartCFrame(platform.CFrame * CFrame.new(0, platform.Size.Y/2 + 1, 0))
    end
    
    model.Parent = slot
    
    -- 6. Stocker la référence
    if not self._models[player.UserId] then
        self._models[player.UserId] = {}
    end
    self._models[player.UserId][slotIndex] = model
    
    print("[BrainrotModelSystem] Modèle créé: " .. player.Name .. " slot " .. slotIndex .. " (" .. brainrotData.SetName .. ")")
    
    return true
end

function BrainrotModelSystem:DestroyBrainrotModel(player, slotIndex)
    if not self._models[player.UserId] then return false end
    
    local model = self._models[player.UserId][slotIndex]
    if not model then return false end
    
    model:Destroy()
    self._models[player.UserId][slotIndex] = nil
    
    print("[BrainrotModelSystem] Modèle détruit: " .. player.Name .. " slot " .. slotIndex)
    
    return true
end

function BrainrotModelSystem:GetBrainrotModel(player, slotIndex)
    if not self._models[player.UserId] then return nil end
    return self._models[player.UserId][slotIndex]
end

return BrainrotModelSystem
```

---

## A5.5.2 - Intégration avec PlacementSystem

Modifier **PlacementSystem:PlaceBrainrot** pour créer le modèle 3D :

```lua
-- Placer le Brainrot
placedBrainrots[tostring(slotIndex)] = brainrotData
DataService:UpdateValue(player, "PlacedBrainrots", placedBrainrots)

print("[PlacementSystem] Brainrot placé: " .. player.Name .. " slot " .. slotIndex)

-- Créer le modèle visuel (Phase 5.5)
if BrainrotModelSystem then
    BrainrotModelSystem:CreateBrainrotModel(player, slotIndex, brainrotData)
end

return true
```

Et dans **PlacementSystem:RemoveBrainrot** :

```lua
-- Retirer le Brainrot
placedBrainrots[tostring(slotIndex)] = nil
DataService:UpdateValue(player, "PlacedBrainrots", placedBrainrots)

-- Détruire le modèle visuel (Phase 5.5)
if BrainrotModelSystem then
    BrainrotModelSystem:DestroyBrainrotModel(player, slotIndex)
end

print("[PlacementSystem] Brainrot retiré: " .. player.Name .. " slot " .. slotIndex)

return true
```

---

## A5.5.3 - Modèles 3D dans Studio

### Structure à créer dans ReplicatedStorage

```
ReplicatedStorage
└── Assets
    ├── Pieces (déjà existant)
    └── Brainrots (nouveau)
        ├── Skibidi (Model)
        │   ├── Head (MeshPart ou Part)
        │   ├── Body (MeshPart ou Part)
        │   └── Legs (MeshPart ou Part)
        ├── Rizz (Model)
        ├── Fanum (Model)
        └── Gyatt (Model)
```

Chaque modèle de Brainrot doit :
- Être un **Model**
- Avoir un **PrimaryPart** défini
- Contenir les 3 parties assemblées (Head, Body, Legs)
- Être à l'échelle appropriée pour le slot

---

## A5.5.4 - Visibilité par joueur

Pour que seul le propriétaire voie ses Brainrots, deux options :

**Option 1 - Côté serveur (LocalTransparencyModifier)** :
```lua
-- Rendre invisible pour les autres joueurs
for _, part in ipairs(model:GetDescendants()) do
    if part:IsA("BasePart") then
        part.LocalTransparencyModifier = 1 -- Invisible localement
    end
end
```

**Option 2 - Côté client (filtrage)** :
Le client affiche seulement les Brainrots avec `OwnerUserId == player.UserId`.

---

# DEV B - FRONTEND VISUALISATION

## B5.5.1 - PieceVisualizationController.module.lua

### Description

Contrôleur client qui affiche les pièces en 3D derrière le joueur et les fait suivre.

### Fichier : `StarterPlayer/StarterPlayerScripts/PieceVisualizationController.module.lua`

**Responsabilités :**

1. **ShowPieces(pieces)**  
   - Pour chaque pièce en main, créer un modèle 3D
   - Positionner derrière le joueur (Head en haut, Body milieu, Legs bas)
   - Utiliser RunService.Heartbeat pour suivre le joueur

2. **HidePieces()**  
   - Détruire tous les modèles 3D affichés

3. **UpdatePiecePositions()**  
   - Mettre à jour la position des pièces pour suivre le joueur
   - Décalage derrière le joueur (ex: -5 studs en Z)
   - Espacement vertical (Head +3, Body 0, Legs -3)

### Structure recommandée

```lua
--[[
    PieceVisualizationController.module.lua
    Affichage 3D des pièces en main derrière le joueur
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local PieceVisualizationController = {}
local _displayedPieces = {} -- {[index] = model}
local _updateConnection = nil

-- Décalages pour chaque type de pièce
local PIECE_OFFSETS = {
    Head = Vector3.new(0, 3, -5),
    Body = Vector3.new(0, 0, -5),
    Legs = Vector3.new(0, -3, -5),
}

function PieceVisualizationController:Init()
    print("[PieceVisualizationController] Initialisé")
end

function PieceVisualizationController:ShowPieces(pieces)
    -- Nettoyer les anciens modèles
    self:HidePieces()
    
    if #pieces == 0 then return end
    
    -- Créer les nouveaux modèles
    for i, pieceData in ipairs(pieces) do
        local model = self:_CreatePieceModel(pieceData)
        if model then
            _displayedPieces[i] = {
                Model = model,
                PieceType = pieceData.PieceType,
            }
        end
    end
    
    -- Démarrer la mise à jour des positions
    if not _updateConnection then
        _updateConnection = RunService.Heartbeat:Connect(function()
            self:_UpdatePiecePositions()
        end)
    end
end

function PieceVisualizationController:HidePieces()
    -- Détruire tous les modèles
    for _, data in pairs(_displayedPieces) do
        if data.Model then
            data.Model:Destroy()
        end
    end
    _displayedPieces = {}
    
    -- Arrêter la mise à jour
    if _updateConnection then
        _updateConnection:Disconnect()
        _updateConnection = nil
    end
end

function PieceVisualizationController:_CreatePieceModel(pieceData)
    -- Cloner le modèle depuis ReplicatedStorage
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then return nil end
    
    local piecesFolder = assetsFolder:FindFirstChild("Pieces")
    if not piecesFolder then return nil end
    
    -- Chercher le modèle de la pièce (ex: Skibidi_Head)
    local modelName = pieceData.SetName .. "_" .. pieceData.PieceType
    local template = piecesFolder:FindFirstChild(modelName)
    
    if not template then
        warn("[PieceVisualizationController] Modèle introuvable: " .. modelName)
        return nil
    end
    
    local model = template:Clone()
    model.Parent = workspace
    
    return model
end

function PieceVisualizationController:_UpdatePiecePositions()
    local character = player.Character
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    -- Mettre à jour chaque pièce
    for _, data in pairs(_displayedPieces) do
        if data.Model and data.Model.PrimaryPart then
            local offset = PIECE_OFFSETS[data.PieceType] or Vector3.new(0, 0, -5)
            
            -- Position relative au joueur
            local targetCFrame = rootPart.CFrame * CFrame.new(offset)
            
            -- Appliquer la position
            data.Model:SetPrimaryPartCFrame(targetCFrame)
        end
    end
end

return PieceVisualizationController
```

---

## B5.5.3 - CraftAnimationController.module.lua

### Description

Contrôleur qui gère l'animation d'assemblage des pièces lors du craft.

### Fichier : `StarterPlayer/StarterPlayerScripts/CraftAnimationController.module.lua`

**Responsabilités :**

1. **PlayCraftAnimation(pieces)**  
   - Récupérer les 3 modèles 3D affichés
   - Les faire se rapprocher et s'assembler
   - Animation de fusion (TweenService)
   - Créer le modèle du Brainrot complet
   - Retourner le modèle assemblé

### Structure recommandée

```lua
--[[
    CraftAnimationController.module.lua
    Animation d'assemblage des pièces lors du craft
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CraftAnimationController = {}

function CraftAnimationController:PlayCraftAnimation(pieceModels, setName)
    -- 1. Faire converger les 3 pièces vers un point central
    -- 2. Animation de rotation/fusion
    -- 3. Créer le Brainrot complet
    -- 4. Retourner le modèle du Brainrot
    
    print("[CraftAnimationController] Animation de craft pour: " .. setName)
    
    -- TODO: Implémenter l'animation
    
    return nil -- Retourner le modèle du Brainrot
end

return CraftAnimationController
```

---

## B5.5.4 - BrainrotMovementController.module.lua

### Description

Contrôleur qui gère le déplacement du Brainrot crafté vers son slot dans la base.

### Fichier : `StarterPlayer/StarterPlayerScripts/BrainrotMovementController.module.lua`

**Responsabilités :**

1. **MoveBrainrotToSlot(brainrotModel, slotIndex)**  
   - Récupérer la position du slot dans la base
   - Animer le déplacement avec TweenService
   - Détruire le modèle temporaire à l'arrivée

### Structure recommandée

```lua
--[[
    BrainrotMovementController.module.lua
    Déplacement du Brainrot vers son slot
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local BrainrotMovementController = {}

function BrainrotMovementController:MoveBrainrotToSlot(brainrotModel, slotIndex)
    -- 1. Trouver la base du joueur
    -- 2. Trouver le slot
    -- 3. Animer le déplacement
    -- 4. Détruire à l'arrivée
    
    print("[BrainrotMovementController] Déplacement vers slot: " .. slotIndex)
    
    -- TODO: Implémenter le déplacement
end

return BrainrotMovementController
```

---

## B5.5.5 - Intégration avec ArenaController

Modifier **ArenaController** pour utiliser PieceVisualizationController :

```lua
function ArenaController:_OnInventorySync(pieces)
    _inventory = pieces or {}
    print("[ArenaController] Inventaire synchronisé:", #_inventory, "pièce(s)")
    
    -- Mettre à jour la visualisation 3D (Phase 5.5)
    if PieceVisualizationController then
        PieceVisualizationController:ShowPieces(_inventory)
    end
end
```

---

# SYNC 5.5 - Test Visualisation Complète

## Checklist de validation

- [ ] Les pièces s'affichent en 3D derrière le joueur
- [ ] Les pièces suivent le joueur en temps réel
- [ ] Head en haut, Body au milieu, Legs en bas
- [ ] Animation d'assemblage lors du craft
- [ ] Le Brainrot se déplace vers le slot
- [ ] Le Brainrot apparaît dans le slot de la base
- [ ] Seul le propriétaire voit ses Brainrots
- [ ] Animations fluides et satisfaisantes

---

# Récapitulatif des fichiers

| Rôle   | Fichier                                  | Action      |
|--------|------------------------------------------|------------|
| DEV A  | `ServerScriptService/Systems/BrainrotModelSystem.module.lua` | Créer |
| DEV A  | `ServerScriptService/Systems/PlacementSystem.module.lua` | Modifier |
| DEV A  | `ServerScriptService/Core/GameServer.server.lua` | Modifier |
| DEV A  | ReplicatedStorage/Assets/Brainrots/[Sets] | Créer (Studio) |
| DEV B  | `StarterPlayerScripts/PieceVisualizationController.module.lua` | Créer |
| DEV B  | `StarterPlayerScripts/CraftAnimationController.module.lua` | Créer |
| DEV B  | `StarterPlayerScripts/BrainrotMovementController.module.lua` | Créer |
| DEV B  | `StarterPlayerScripts/ArenaController.module.lua` | Modifier |
| DEV B  | `StarterPlayerScripts/ClientMain.client.lua` | Modifier |

---

**Fin du Guide Phase 5.5**
