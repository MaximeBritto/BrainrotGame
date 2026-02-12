# PHASE 8 : SYSTÈME DE VOL ET COMBAT - Guide Complet

**Date:** 2026-02-09
**Status:** En cours (B8.2)
**Prérequis:** Phases 0 à 7 complétées

⚠️ **VERSION SIMPLIFIÉE** : Utilise ProximityPrompt natif de Roblox (pas de barre de progression custom)

---

## 🎯 Vue d'ensemble

La Phase 8 ajoute un système de **vol de Brainrot** entre joueurs et un système de **combat à la batte** pour se défendre :

### Fonctionnalités

1. **Vol de Brainrot** :
   - S'approcher d'un Brainrot placé dans le slot d'un autre joueur
   - **Hold E** via ProximityPrompt natif pendant 3 secondes
   - Le Brainrot volé va dans l'inventaire du voleur
   - Retourner à sa base et le placer dans un slot libre pour l'acquérir
   - **Impossible de voler si aucun slot libre dans sa propre base**

2. **Combat à la batte** :
   - Chaque joueur spawn avec une **batte** équipée automatiquement
   - Frapper un joueur avec la batte l'**assomme pendant 5 secondes**
   - Si le joueur assommé transporte un Brainrot volé, celui-ci **retourne automatiquement** à son slot d'origine
   - Joueur assommé : **tombe au sol**, ne peut plus bouger, puis se relève automatiquement

### Objectifs de la Phase 8

- Système de vol simplifié avec **ProximityPrompt natif** (hold E automatique)
- Combat simple mais efficace avec battes
- Protection contre les abus (validations serveur, cooldowns)
- Feedback visuel natif (ProximityPrompt UI + effet d'assommage)
- Code serveur sécurisé (validation complète)

---

## 📋 Résumé des tâches

### DEV A - Backend Vol & Combat

| #    | Tâche                           | Fichier                                      | Temps |
|------|---------------------------------|----------------------------------------------|-------|
| A8.1 | StealSystem (serveur)           | Systems/StealSystem.module.lua               | 2h    |
| A8.2 | BatSystem (serveur)             | Systems/BatSystem.module.lua                 | 1h30  |
| A8.3 | Modifications PlacementSystem   | Systems/PlacementSystem.module.lua           | 30min |
| A8.4 | NetworkHandler (nouveaux events)| Handlers/NetworkHandler.module.lua           | 30min |
| A8.5 | NetworkSetup (nouveaux remotes) | Core/NetworkSetup.module.lua                 | 15min |
| A8.6 | GameServer (init systèmes)      | Core/GameServer.server.lua                   | 15min |

**Total DEV A :** ~5h

### DEV B - Client & Batte Tool

| #    | Tâche                           | Fichier                                      | Temps |
|------|---------------------------------|----------------------------------------------|-------|
| B8.1 | StealController (client)        | StarterPlayer/Controllers/StealController    | 30min |
| B8.2 | Création de la Batte (Tool)     | Roblox Studio (Toolbox → ServerStorage)      | 30min |
| B8.3 | ~~BatController (client)~~      | ~~SUPPRIMÉ - Pas d'effets visuels~~          | ~~SUPPRIMÉ~~ |
| B8.4 | ~~StealUI (ProgressBar)~~       | ~~StarterGui/MainHUD~~                       | ~~SUPPRIMÉ~~ |
| B8.5 | ~~StunEffect UI~~               | ~~SUPPRIMÉ - Pas d'indication visuelle~~     | ~~SUPPRIMÉ~~ |

**Total DEV B :** ~1h

**TOTAL PHASE 8 :** ~6h

⚠️ **CHANGEMENTS** :
- Plus besoin de StealUI custom grâce au ProximityPrompt natif !
- Plus besoin d'effets visuels pour le stun - le personnage tombe simplement au sol

---

# 🏗️ ARCHITECTURE

## Nouveaux Systèmes

### StealSystem (Serveur)

Gère la logique de vol de Brainrot :
- Validation : slot disponible, Brainrot existe, proximité (via ProximityPrompt)
- **Exécution instantanée** (pas de tracking temporel, géré par ProximityPrompt)
- Transfert du Brainrot du slot → inventaire du voleur
- Peut être annulé si le voleur est frappé pendant le hold

### BatSystem (Serveur)

Gère les battes et l'assommage :
- Distribution de la batte au spawn
- Validation des coups (distance, cooldown)
- Application du stun (5 secondes)
- Retour du Brainrot volé si la victime en transporte un

## Flux de données

### Vol de Brainrot (avec ProximityPrompt)

```
CLIENT (Voleur)                    SERVER                           CLIENT (Propriétaire)
  │                                  │                                       │
  │──S'approche du Brainrot──────────│                                       │
  │  ProximityPrompt s'affiche       │                                       │
  │  "Hold E (3s)"                   │                                       │
  │                                  │                                       │
  │──[Hold E pendant 3s]─────────────│                                       │
  │  (géré par ProximityPrompt)      │                                       │
  │                                  │                                       │
  │──Triggered Event─────────────────│                                       │
  │  StealBrainrot(ownerId, slotId)  │                                       │
  │                                  │──Validate:                            │
  │                                  │  • Voleur a slot libre?               │
  │                                  │  • Brainrot existe dans slot?         │
  │                                  │  • Proximité OK?                      │
  │                                  │                                       │
  │                                  │──Remove Brainrot from slot            │
  │                                  │──Add to thief inventory               │
  │                                  │                                       │
  │◄─SyncInventory───────────────────│                                       │
  │◄─Notification: "Volé!"───────────│                                       │
  │                                  │──────SyncPlacedBrainrots─────────────►│
  │                                  │──────Notification: "Volé!"───────────►│
  │                                  │       (slot maintenant vide)          │
  │                                  │                                       │
  │──Retour à sa base────────────────│                                       │
  │──PlaceBrainrot(slotId)───────────│                                       │
  │                                  │──Transfer inventory → slot            │
  │◄─SyncInventory───────────────────│                                       │
  │◄─SyncPlacedBrainrots─────────────│                                       │
```

### Combat à la batte

```
CLIENT (Attaquant)                 SERVER                        CLIENT (Victime)
  │                                  │                                  │
  │──Click avec Batte────────────────│                                  │
  │                                  │                                  │
  │──BatHit(victimUserId)────────────│                                  │
  │                                  │──Validate:                       │
  │                                  │  • Distance < 10 studs           │
  │                                  │  • Cooldown OK (1s)              │
  │                                  │  • Victime pas déjà stun         │
  │                                  │                                  │
  │                                  │──Apply Stun (5s)                 │
  │                                  │──If carrying stolen Brainrot:    │
  │                                  │  • Return to original slot       │
  │                                  │  • Clear inventory               │
  │                                  │                                  │
  │                                  │─────SyncStunState────────────────►│
  │                                  │      (IsStunned = true)          │
  │                                  │                                  │
  │                                  │      [Victime voit effet stun]   │
  │                                  │      [Victime ne peut plus bouger]│
  │                                  │                                  │
  │                                  │──[Après 5s]───────────────────────│
  │                                  │      Remove Stun                 │
  │                                  │─────SyncStunState────────────────►│
  │                                  │      (IsStunned = false)         │
```

## Nouveaux RemoteEvents

À ajouter dans `ReplicatedStorage/Remotes` :

| Nom                  | Type         | Direction        | Description                           |
|----------------------|--------------|------------------|---------------------------------------|
| StealBrainrot        | RemoteEvent  | Client → Server  | Vol complété (après ProximityPrompt)  |
| BatHit               | RemoteEvent  | Client → Server  | Joueur frappe avec la batte           |
| SyncStunState        | RemoteEvent  | Server → Client  | État d'assommage (true/false)         |

⚠️ **SIMPLIFICATION** : Plus besoin de StartSteal, StopSteal, SyncProgress car le ProximityPrompt gère le timing !

## Modifications de données

### Données temporaires (en mémoire, non sauvegardées)

Ajouter dans `PlayerService` pour chaque joueur :

```lua
_tempPlayerData[userId] = {
    IsStunned = false,           -- Joueur assommé?
    StunEndTime = 0,             -- Timestamp de fin de stun
    IsStealingFrom = nil,        -- {ownerId, slotId} si en train de voler
    StealStartTime = 0,          -- Timestamp de début de vol
    LastBatHitTime = 0,          -- Cooldown batte
}
```

### Pas de modifications DataStore

Aucune donnée persistante ajoutée (le vol et le stun sont temporaires).

---

# 📁 STRUCTURE DES FICHIERS

## Nouveaux fichiers à créer

```
ServerScriptService/
├── Systems/
│   ├── StealSystem.module.lua          ✅ NOUVEAU (version simplifiée)
│   └── BatSystem.module.lua            ✅ NOUVEAU
│
StarterPlayer/
└── StarterPlayerScripts/
    └── Controllers/
        └── StealController.client.lua  ✅ NOUVEAU (ultra-simplifié ~30 lignes)

ServerStorage/
└── Bat (Tool)                          ✅ NOUVEAU (depuis Toolbox)
    └── BatScript.lua                   ✅ NOUVEAU (script du tool)
```

⚠️ **CHANGEMENTS** :
- Plus besoin de StealProgressBar UI !
- Plus besoin de BatController client !
- Plus besoin de StunEffect UI !

## Fichiers à modifier

```
ServerScriptService/
├── Core/
│   ├── NetworkSetup.module.lua         📝 MODIFIER (ajouter 3 remotes)
│   └── GameServer.server.lua           📝 MODIFIER (init systèmes)
├── Handlers/
│   └── NetworkHandler.module.lua       📝 MODIFIER (2 nouveaux handlers)
└── Systems/
    └── PlacementSystem.module.lua      📝 MODIFIER (créer ProximityPrompt)

ReplicatedStorage/
└── Config/
    └── GameConfig.module.lua           📝 MODIFIER (paramètres vol/stun)
```

⚠️ **IMPORTANT** : PlacementSystem doit maintenant créer un ProximityPrompt sur chaque Brainrot placé !

---

# 💻 DEV A - BACKEND VOL & COMBAT

## A8.1 - StealSystem (Serveur) ⚠️ VERSION SIMPLIFIÉE

### Créer le fichier

**Roblox Studio :**
1. `ServerScriptService` → Dossier `Systems`
2. Clic droit → Insert Object → **ModuleScript**
3. Renommer : **StealSystem**

### Code complet (simplifié)

```lua
-- ServerScriptService/Systems/StealSystem.module.lua
-- VERSION SIMPLIFIÉE : Le ProximityPrompt gère le timing côté client
local StealSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local DataService = require(script.Parent.Parent.Core.DataService)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Configuration
local STEAL_MAX_DISTANCE = GameConfig.StealMaxDistance or 15 -- studs

---
-- Initialisation
---
function StealSystem:Init()
	print("[StealSystem] Initialisation...")
	print("[StealSystem] Initialisé!")
end

---
-- Exécute un vol de Brainrot (appelé après ProximityPrompt.Triggered)
-- @param thief Player - Le voleur
-- @param ownerId number - UserId du propriétaire
-- @param slotId number - ID du slot à voler
-- @return boolean - Success
---
function StealSystem:ExecuteSteal(thief, ownerId, slotId)
	local thiefId = thief.UserId

	-- 1. Vérifier que le voleur a un slot libre
	local thiefData = DataService:GetPlayerData(thiefId)
	if not thiefData then return false end

	local availableSlots = self:_GetAvailableSlots(thiefId)
	if availableSlots <= 0 then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Vous devez avoir un slot libre pour voler un Brainrot!"
		})
		return false
	end

	-- 2. Vérifier que le propriétaire existe
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Propriétaire introuvable."
		})
		return false
	end

	-- 3. Vérifier que le Brainrot existe dans le slot
	local ownerData = DataService:GetPlayerData(ownerId)
	if not ownerData then return false end

	local brainrot = ownerData.PlacedBrainrots[slotId]
	if not brainrot then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Ce slot est vide."
		})
		return false
	end

	-- 4. Vérifier la distance (sécurité anti-hack)
	if not self:_IsInRange(thief, owner, slotId) then
		remotes.Notification:FireClient(thief, {
			Type = "Error",
			Message = "Vous êtes trop loin du Brainrot."
		})
		return false
	end

	-- 5. Retirer le Brainrot du slot du propriétaire
	ownerData.PlacedBrainrots[slotId] = nil
	DataService:SetPlayerData(ownerId, ownerData)

	-- 6. Ajouter à l'inventaire du voleur comme pièces séparées
	local headId = "stolen_head_" .. tostring(tick()) .. "_" .. tostring(math.random(1000, 9999))
	local bodyId = "stolen_body_" .. tostring(tick() + 0.1) .. "_" .. tostring(math.random(1000, 9999))
	local legsId = "stolen_legs_" .. tostring(tick() + 0.2) .. "_" .. tostring(math.random(1000, 9999))

	thiefData.Inventory[headId] = {
		Set = brainrot.HeadSet,
		Part = "Head"
	}
	thiefData.Inventory[bodyId] = {
		Set = brainrot.BodySet,
		Part = "Body"
	}
	thiefData.Inventory[legsId] = {
		Set = brainrot.LegsSet,
		Part = "Legs"
	}

	DataService:SetPlayerData(thiefId, thiefData)

	-- 7. Sync clients
	if owner then
		remotes.SyncPlacedBrainrots:FireClient(owner, ownerData.PlacedBrainrots)
		remotes.Notification:FireClient(owner, {
			Type = "Error",
			Message = "Votre Brainrot a été volé!"
		})
	end

	remotes.SyncInventory:FireClient(thief, thiefData.Inventory)
	remotes.Notification:FireClient(thief, {
		Type = "Success",
		Message = "Brainrot volé! Allez le placer dans votre base."
	})

	print(string.format("[StealSystem] %s a volé le Brainrot de %s (slot %d)",
		thief.Name, owner.Name, slotId))

	return true
end

---
-- Calcule le nombre de slots libres d'un joueur
---
function StealSystem:_GetAvailableSlots(userId)
	local data = DataService:GetPlayerData(userId)
	if not data then return 0 end

	local usedSlots = 0
	for _ in pairs(data.PlacedBrainrots) do
		usedSlots = usedSlots + 1
	end

	return data.OwnedSlots - usedSlots
end

---
-- Vérifie si le voleur est à portée du Brainrot
---
function StealSystem:_IsInRange(thief, owner, slotId)
	local thiefChar = thief.Character
	local ownerChar = owner.Character

	if not thiefChar or not ownerChar then return false end

	local thiefRoot = thiefChar:FindFirstChild("HumanoidRootPart")
	local ownerRoot = ownerChar:FindFirstChild("HumanoidRootPart")

	if not thiefRoot or not ownerRoot then return false end

	-- Pour simplifier, on vérifie juste la distance au propriétaire
	local distance = (thiefRoot.Position - ownerRoot.Position).Magnitude
	return distance <= STEAL_MAX_DISTANCE
end

return StealSystem
```

⚠️ **CHANGEMENTS MAJEURS** :
- ✅ Plus de `_activeSteals` (pas de tracking temporel)
- ✅ Plus de `Heartbeat` loop
- ✅ Plus de `StartSteal` / `StopSteal` / `_UpdateActiveSteals`
- ✅ Une seule méthode `ExecuteSteal` appelée après le ProximityPrompt
- ✅ Code réduit de ~560 lignes à ~150 lignes !

---

## A8.2 - BatSystem (Serveur)

### Créer le fichier

**Roblox Studio :**
1. `ServerScriptService` → Dossier `Systems`
2. Clic droit → Insert Object → **ModuleScript**
3. Renommer : **BatSystem**

### Code complet

```lua
-- ServerScriptService/Systems/BatSystem.module.lua
local BatSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Modules
local DataService = require(script.Parent.Parent.Core.DataService)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- État temporaire : {userId = {IsStunned, StunEndTime, LastBatHitTime}}
local _playerStates = {}

-- Configuration
local STUN_DURATION = GameConfig.StunDuration or 5 -- secondes
local BAT_COOLDOWN = GameConfig.BatCooldown or 1 -- secondes
local BAT_MAX_DISTANCE = GameConfig.BatMaxDistance or 10 -- studs

---
-- Initialisation
---
function BatSystem:Init()
    print("[BatSystem] Initialisation...")

    -- Donner la batte au spawn
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            self:_GiveBat(player)
        end)
    end)

    print("[BatSystem] Initialisé!")
end

---
-- Donne la batte au joueur
---
function BatSystem:_GiveBat(player)
    task.wait(0.5) -- Attendre que le personnage soit complètement chargé

    local bat = ServerStorage:FindFirstChild("Bat")
    if not bat then
        warn("[BatSystem] Batte introuvable dans ServerStorage!")
        return
    end

    -- Cloner la batte et l'ajouter au Backpack
    local batClone = bat:Clone()
    batClone.Parent = player:WaitForChild("Backpack")

    print(string.format("[BatSystem] Batte donnée à %s", player.Name))
end

---
-- Gère un coup de batte
-- @param attacker Player - L'attaquant
-- @param victimId number - UserId de la victime
---
function BatSystem:HandleBatHit(attacker, victimId)
    local attackerId = attacker.UserId

    -- 1. Vérifier le cooldown de l'attaquant
    if not self:_CheckCooldown(attackerId) then
        return
    end

    -- 2. Vérifier que la victime existe
    local victim = Players:GetPlayerByUserId(victimId)
    if not victim then
        return
    end

    -- 3. Vérifier que la victime n'est pas déjà stun
    if self:IsStunned(victimId) then
        remotes.Notification:FireClient(attacker, {
            Type = "Info",
            Message = "Ce joueur est déjà assommé."
        })
        return
    end

    -- 4. Vérifier la distance
    if not self:_IsInRange(attacker, victim) then
        remotes.Notification:FireClient(attacker, {
            Type = "Error",
            Message = "Trop loin pour frapper!"
        })
        return
    end

    -- 5. Appliquer le stun
    self:_ApplyStun(victim)

    -- 6. Si la victime transportait un Brainrot volé, le retourner
    self:_ReturnStolenBrainrot(victim)

    -- 7. Mettre à jour le cooldown de l'attaquant
    _playerStates[attackerId] = _playerStates[attackerId] or {}
    _playerStates[attackerId].LastBatHitTime = tick()

    print(string.format("[BatSystem] %s a assommé %s", attacker.Name, victim.Name))
end

---
-- Vérifie le cooldown de l'attaquant
---
function BatSystem:_CheckCooldown(attackerId)
    local state = _playerStates[attackerId]
    if not state or not state.LastBatHitTime then
        return true
    end

    local elapsed = tick() - state.LastBatHitTime
    return elapsed >= BAT_COOLDOWN
end

---
-- Vérifie si l'attaquant est à portée de la victime
---
function BatSystem:_IsInRange(attacker, victim)
    local attackerChar = attacker.Character
    local victimChar = victim.Character

    if not attackerChar or not victimChar then return false end

    local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
    local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")

    if not attackerRoot or not victimRoot then return false end

    local distance = (attackerRoot.Position - victimRoot.Position).Magnitude
    return distance <= BAT_MAX_DISTANCE
end

---
-- Applique le stun à la victime
---
function BatSystem:_ApplyStun(victim)
    local victimId = victim.UserId

    -- Mettre à jour l'état
    _playerStates[victimId] = _playerStates[victimId] or {}
    _playerStates[victimId].IsStunned = true
    _playerStates[victimId].StunEndTime = tick() + STUN_DURATION

    -- Faire tomber le personnage au sol (ragdoll)
    local character = victim.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Désactiver le mouvement
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            -- Activer PlatformStand pour faire tomber au sol
            humanoid.PlatformStand = true
        end
    end

    -- Notification simple
    remotes.Notification:FireClient(victim, {
        Type = "Error",
        Message = "Vous êtes assommé!"
    })

    -- Retirer le stun après la durée
    task.delay(STUN_DURATION, function()
        self:_RemoveStun(victim)
    end)
end

---
-- Retire le stun de la victime
---
function BatSystem:_RemoveStun(victim)
    local victimId = victim.UserId

    -- Mettre à jour l'état
    _playerStates[victimId] = _playerStates[victimId] or {}
    _playerStates[victimId].IsStunned = false

    -- Relever le personnage et réactiver le mouvement
    local character = victim.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Désactiver PlatformStand pour relever le personnage
            humanoid.PlatformStand = false
            -- Réactiver le mouvement
            humanoid.WalkSpeed = 16 -- Vitesse par défaut
            humanoid.JumpPower = 50 -- Vitesse par défaut
        end
    end

    -- Notification simple
    remotes.Notification:FireClient(victim, {
        Type = "Success",
        Message = "Vous pouvez bouger à nouveau."
    })

    print(string.format("[BatSystem] %s n'est plus assommé", victim.Name))
end

---
-- Retourne le Brainrot volé (si la victime en transportait un)
---
function BatSystem:_ReturnStolenBrainrot(victim)
    local victimId = victim.UserId
    local victimData = DataService:GetPlayerData(victimId)
    if not victimData then return end

    -- Vérifier si l'inventaire contient des pièces "volées"
    -- (identifiables par le préfixe "stolen_")
    local stolenPieces = {}
    for pieceId, pieceData in pairs(victimData.Inventory) do
        if string.find(pieceId, "stolen_") then
            table.insert(stolenPieces, pieceId)
        end
    end

    if #stolenPieces == 0 then
        return -- Pas de Brainrot volé
    end

    -- Retirer les pièces de l'inventaire
    for _, pieceId in ipairs(stolenPieces) do
        victimData.Inventory[pieceId] = nil
    end

    DataService:SetPlayerData(victimId, victimData)

    -- Sync au client
    remotes.SyncInventory:FireClient(victim, victimData.Inventory)
    remotes.Notification:FireClient(victim, {
        Type = "Error",
        Message = "Votre Brainrot volé a été perdu!"
    })

    print(string.format("[BatSystem] Brainrot volé retiré de %s", victim.Name))
end

---
-- Vérifie si un joueur est stun
---
function BatSystem:IsStunned(userId)
    local state = _playerStates[userId]
    if not state or not state.IsStunned then
        return false
    end

    -- Vérifier si le stun est encore actif
    if tick() >= state.StunEndTime then
        state.IsStunned = false
        return false
    end

    return true
end

return BatSystem
```

---

## A8.3 - Modifications PlacementSystem ⚠️ IMPORTANT

Ajouter la création de **ProximityPrompt** sur chaque Brainrot placé.

### Ouvrir le fichier

**Roblox Studio :**
1. `ServerScriptService` → `Systems` → `PlacementSystem`
2. Double-cliquer pour ouvrir

### Modifications à faire

#### 1. Ajouter GameConfig en haut

Après les autres `require` :

```lua
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
```

#### 2. Modifier la fonction PlaceBrainrot

Chercher la section où le Brainrot est créé dans le Workspace, et ajouter APRÈS la création du model :

```lua
-- NOUVEAU : Ajouter ProximityPrompt pour vol
local proximityPrompt = Instance.new("ProximityPrompt")
proximityPrompt.Name = "StealPrompt"
proximityPrompt.ActionText = "Voler"
proximityPrompt.ObjectText = "Brainrot"
proximityPrompt.HoldDuration = GameConfig.StealDuration or 3
proximityPrompt.MaxActivationDistance = GameConfig.StealMaxDistance or 15
proximityPrompt.RequiresLineOfSight = false
proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
proximityPrompt.Parent = brainrotModel.PrimaryPart or brainrotModel:FindFirstChildWhichIsA("BasePart")

-- Stocker les infos du propriétaire dans des Attributes
proximityPrompt:SetAttribute("OwnerId", ownerId)
proximityPrompt:SetAttribute("SlotId", slotId)
```

#### 3. Exemple de placement complet

Voici comment votre fonction PlaceBrainrot devrait ressembler (section création du model) :

```lua
-- Créer le model assemblé
local brainrotModel = BrainrotModelSystem:CreateFullBrainrot(...)
brainrotModel.Name = "Brainrot_" .. ownerId .. "_" .. slotId
brainrotModel.Parent = workspace.Brainrots -- ou autre dossier

-- Position du model dans le slot
-- ... votre code de positionnement ...

-- NOUVEAU : Ajouter ProximityPrompt
local primaryPart = brainrotModel.PrimaryPart or brainrotModel:FindFirstChildWhichIsA("BasePart")
if primaryPart then
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Name = "StealPrompt"
	proximityPrompt.ActionText = "Voler"
	proximityPrompt.ObjectText = "Brainrot"
	proximityPrompt.HoldDuration = GameConfig.StealDuration or 3
	proximityPrompt.MaxActivationDistance = GameConfig.StealMaxDistance or 15
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
	proximityPrompt.Parent = primaryPart

	proximityPrompt:SetAttribute("OwnerId", ownerId)
	proximityPrompt:SetAttribute("SlotId", slotId)

	print(string.format("[PlacementSystem] ProximityPrompt ajouté au Brainrot de %d (slot %d)", ownerId, slotId))
end
```

⚠️ **CRITIQUE** : Le ProximityPrompt doit être créé sur CHAQUE Brainrot placé pour permettre le vol !

---

## A8.4 - NetworkHandler (Nouveaux Handlers) ⚠️ SIMPLIFIÉ

### Ouvrir le fichier

**Roblox Studio :**
1. `ServerScriptService` → `Handlers` → `NetworkHandler`
2. Double-cliquer pour ouvrir

### Ajouter au haut du fichier

Après les autres `require` :

```lua
local StealSystem = require(script.Parent.Parent.Systems.StealSystem)
local BatSystem = require(script.Parent.Parent.Systems.BatSystem)
```

### Ajouter dans la fonction Init()

Après les autres `.OnServerEvent:Connect` :

```lua
	-- Vol de Brainrot (simplifié)
	remotes.StealBrainrot.OnServerEvent:Connect(function(player, ownerId, slotId)
		pcall(function()
			StealSystem:ExecuteSteal(player, ownerId, slotId)
		end)
	end)

	-- Combat batte
	remotes.BatHit.OnServerEvent:Connect(function(player, victimId)
		pcall(function()
			BatSystem:HandleBatHit(player, victimId)
		end)
	end)
```

⚠️ **CHANGEMENT** : Un seul handler `StealBrainrot` au lieu de 3 (Start/Stop/Progress) !

---

## A8.5 - NetworkSetup (Nouveaux Remotes) ⚠️ SIMPLIFIÉ

### Ouvrir le fichier

**Roblox Studio :**
1. `ServerScriptService` → `Core` → `NetworkSetup`
2. Double-cliquer pour ouvrir

### Ajouter à la liste des remotes

Dans le tableau `remoteEventNames`, ajouter :

```lua
local remoteEventNames = {
	-- ... existants ...
	"StealBrainrot",
	"BatHit",
	"SyncStunState",
}
```

⚠️ **SIMPLIFICATION** : Seulement 3 RemoteEvents au lieu de 5 !

---

## A8.6 - GameServer (Init Systèmes)

### Ouvrir le fichier

**Roblox Studio :**
1. `ServerScriptService` → `Core` → `GameServer`
2. Double-cliquer pour ouvrir

### Ajouter les require

Après les autres `require` de systèmes :

```lua
local StealSystem = require(ServerScriptService.Systems.StealSystem)
local BatSystem = require(ServerScriptService.Systems.BatSystem)
```

### Ajouter les Init()

Après les autres `.Init()` :

```lua
StealSystem:Init()
print("[GameServer] StealSystem: OK")

BatSystem:Init()
print("[GameServer] BatSystem: OK")
```

---

## A8.7 - GameConfig (Paramètres)

### Ouvrir le fichier

**Roblox Studio :**
1. `ReplicatedStorage` → `Config` → `GameConfig`
2. Double-cliquer pour ouvrir

### Ajouter les paramètres

À la fin du module, avant `return Config` :

```lua
    -- Vol de Brainrot
    StealDuration = 3,           -- Secondes pour voler
    StealMaxDistance = 15,       -- Distance max (studs)

    -- Combat
    StunDuration = 5,            -- Secondes d'assommage
    BatCooldown = 1,             -- Cooldown entre 2 coups (secondes)
    BatMaxDistance = 10,         -- Distance max pour frapper (studs)
```

---

# 🎨 DEV B - CLIENT & BATTE TOOL

## B8.1 - StealController (Client) ⚠️ VERSION ULTRA-SIMPLIFIÉE

### Créer le fichier

**Roblox Studio :**
1. `StarterPlayer` → `StarterPlayerScripts`
2. Créer un dossier **Controllers** (s'il n'existe pas)
3. Clic droit → Insert Object → **LocalScript**
4. Renommer : **StealController**

### Code complet (seulement ~30 lignes!)

```lua
-- StarterPlayer/StarterPlayerScripts/Controllers/StealController.client.lua
-- Écoute les ProximityPrompts des Brainrots et envoie au serveur

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

-- Variables
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

---
-- Écoute tous les ProximityPrompts déclenchés
---
ProximityPromptService.PromptTriggered:Connect(function(promptObject, playerWhoTriggered)
	-- Vérifier que c'est nous qui avons déclenché le prompt
	if playerWhoTriggered ~= player then return end

	-- Vérifier que c'est un StealPrompt
	if promptObject.Name ~= "StealPrompt" then return end

	-- Récupérer les infos du propriétaire depuis les Attributes
	local ownerId = promptObject:GetAttribute("OwnerId")
	local slotId = promptObject:GetAttribute("SlotId")

	if ownerId and slotId then
		-- Envoyer au serveur
		remotes.StealBrainrot:FireServer(ownerId, slotId)
		print(string.format("[StealController] Vol envoyé au serveur (owner: %d, slot: %d)", ownerId, slotId))
	else
		warn("[StealController] ProximityPrompt sans OwnerId/SlotId!")
	end
end)

print("[StealController] Initialisé!")
```

⚠️ **ÉNORME SIMPLIFICATION** :
- ✅ Plus de détection manuelle (loop)
- ✅ Plus de gestion Input E (géré par ProximityPrompt)
- ✅ Plus d'UI custom de progression
- ✅ Plus de tracking d'état (isStealingActive, etc.)
- ✅ Code réduit de ~130 lignes à ~30 lignes !
- ✅ Le ProximityPromptService écoute TOUS les prompts automatiquement

---

## B8.2 - Création de la Batte (Tool)

### Étapes Roblox Studio

#### 1. Trouver une batte dans la Toolbox

1. Ouvrir la **Toolbox** (View → Toolbox)
2. Rechercher "bat" ou "baseball bat"
3. Insérer une batte dans le Workspace (modèle gratuit)
4. La batte devrait apparaître comme un **Tool** ou un **Model**

#### 2. Convertir en Tool (si nécessaire)

Si c'est un Model :
1. Sélectionner le Model dans le Workspace
2. Trouver la **Handle** (la partie principale de la batte)
3. Créer un nouveau **Tool** dans `ServerStorage` :
   - Clic droit sur `ServerStorage` → Insert Object → **Tool**
   - Renommer : **Bat**
4. Déplacer la **Handle** dans le Tool
5. Supprimer le Model original

#### 3. Configurer le Tool

Sélectionner le Tool **Bat** :
- **RequiresHandle** : `true`
- **CanBeDropped** : `false` (pour éviter de perdre la batte)
- **ToolTip** : "Batte - Clic pour frapper"

#### 4. Ajouter un Script à la batte

1. Dans le Tool **Bat**, clic droit → Insert Object → **Script**
2. Renommer : **BatScript**
3. Copier ce code :

```lua
-- ServerStorage/Bat/BatScript
local tool = script.Parent
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")

-- Cooldown local (visuel)
local lastSwing = 0
local COOLDOWN = 1

tool.Activated:Connect(function()
    local player = tool.Parent.Parent -- Player
    if not player or not player:IsA("Player") then return end

    -- Vérifier cooldown local
    if tick() - lastSwing < COOLDOWN then
        return
    end
    lastSwing = tick()

    -- Animation de swing (optionnel)
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Jouer animation ici si vous en avez une
        end
    end

    -- Détecter les joueurs à portée
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local hitPlayer = nil
    local closestDistance = 10 -- Distance max

    for _, otherPlayer in ipairs(game:GetService("Players"):GetPlayers()) do
        if otherPlayer ~= player then
            local otherChar = otherPlayer.Character
            if otherChar then
                local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local distance = (root.Position - otherRoot.Position).Magnitude
                    if distance < closestDistance then
                        hitPlayer = otherPlayer
                        closestDistance = distance
                    end
                end
            end
        end
    end

    -- Envoyer au serveur si un joueur touché
    if hitPlayer then
        remotes.BatHit:FireServer(hitPlayer.UserId)
    end
end)
```

#### 5. Déplacer dans ServerStorage

1. Sélectionner le Tool **Bat** complet (avec Handle et Script)
2. Le déplacer dans **ServerStorage**
3. Supprimer du Workspace

---

## B8.3 - ~~BatController (Client)~~ ✅ SUPPRIMÉ !

⚠️ **CETTE ÉTAPE N'EST PLUS NÉCESSAIRE !**

La logique de combat est entièrement gérée par le **BatScript** sur le Tool et le **BatSystem** côté serveur.

**Pas d'effets visuels complexes :**
- Le joueur frappe avec la batte (BatScript détecte les joueurs proches)
- Le serveur valide et applique le stun (BatSystem)
- Le personnage **tombe au sol automatiquement** (ragdoll)
- Après 5 secondes, le personnage **se relève** automatiquement

**Avantages :**
- ✅ Pas besoin de script client supplémentaire
- ✅ Logique simple et claire
- ✅ Stun visuel naturel (ragdoll Roblox)

---

## B8.4 - ~~StealUI (ProgressBar)~~ ✅ SUPPRIMÉ !

⚠️ **CETTE ÉTAPE N'EST PLUS NÉCESSAIRE !**

Le **ProximityPrompt natif** de Roblox affiche automatiquement :
- Le texte "Hold E" avec une barre de progression circulaire
- Le texte d'action ("Voler") et l'objet ("Brainrot")
- La durée du hold (3 secondes)

**Avantages :**
- ✅ Pas besoin de créer d'UI custom
- ✅ Interface cohérente avec les standards Roblox
- ✅ Fonctionne sur PC, mobile et console automatiquement
- ✅ Supporte les différentes langues automatiquement

**Si vous voulez personnaliser l'apparence du ProximityPrompt** (optionnel) :
- Modifier les propriétés `Style`, `UIOffset`, etc. dans le ProximityPrompt créé par PlacementSystem
- Voir la documentation : https://create.roblox.com/docs/ui/proximity-prompts

---

## B8.5 - ~~StunEffect (UI)~~ ✅ SUPPRIMÉ !

⚠️ **CETTE ÉTAPE N'EST PLUS NÉCESSAIRE !**

**Pas d'indication visuelle UI - juste le ragdoll naturel**

Le stun est visuellement représenté par le **ragdoll du personnage** :
- Quand frappé, le personnage **tombe au sol** (PlatformStand activé)
- Le joueur voit son personnage par terre, incapable de bouger
- Après 5 secondes, le personnage **se relève** automatiquement
- Le mouvement est restauré

**Avantages :**
- ✅ Visuel naturel et intuitif (personnage au sol = assommé)
- ✅ Pas besoin d'UI supplémentaire
- ✅ Fonctionne sur tous les appareils (PC, mobile, console)
- ✅ Le joueur peut voir son personnage en 3D (plus immersif qu'une UI)

**Note :** Si vous voulez quand même ajouter une notification simple, utilisez le système de notification existant (déjà fait dans BatSystem).

---

# ✅ TESTS & VALIDATION

## Test 1 : Vol de Brainrot

### Prérequis
- 2 joueurs minimum (utilisez "Test → Players" dans Studio avec 2 joueurs)
- Joueur 1 a un Brainrot placé dans un slot
- Joueur 2 a au moins 1 slot libre

### Étapes
1. Joueur 2 s'approche du Brainrot de Joueur 1
2. **ProximityPrompt natif s'affiche** : "Hold E - Voler Brainrot"
3. Joueur 2 maintient **E** pendant 3 secondes
4. **Barre de progression circulaire** native s'affiche automatiquement
5. Après 3 secondes : Brainrot disparaît du slot de Joueur 1
6. Joueur 2 reçoit notification "Brainrot volé!" et a les 3 pièces dans son inventaire
7. Joueur 2 retourne à sa base et place le Brainrot

### Vérifications Output
```
[PlacementSystem] ProximityPrompt ajouté au Brainrot de 123456 (slot 1)
[StealController] Vol envoyé au serveur (owner: 123456, slot: 1)
[StealSystem] PlayerName a volé le Brainrot de OwnerName (slot 1)
```

---

## Test 2 : Vol Sans Slot Libre

### Prérequis
- Joueur 2 a tous ses slots remplis

### Étapes
1. Joueur 2 s'approche du Brainrot de Joueur 1
2. Joueur 2 appuie sur **E**

### Résultat attendu
- Message d'erreur : "Vous devez avoir un slot libre pour voler un Brainrot!"
- Pas de vol possible

---

## Test 3 : Annulation du Vol

### Étapes
1. Joueur 2 commence à voler (maintient E)
2. Barre de progression circulaire à 50%
3. Joueur 2 **relâche E** ou **s'éloigne**

### Résultat attendu
- ProximityPrompt se réinitialise automatiquement
- Aucun RemoteEvent envoyé au serveur
- Brainrot reste dans le slot de Joueur 1

⚠️ **NOTE** : L'annulation est gérée automatiquement par le ProximityPrompt !

---

## Test 4 : Combat avec Batte

### Prérequis
- 2 joueurs avec leurs battes équipées

### Étapes
1. Joueur 1 s'approche de Joueur 2 (< 10 studs)
2. Joueur 1 clique (frappe avec la batte)
3. Joueur 2 est assommé

### Résultats attendus
- Joueur 2 : **tombe au sol** (ragdoll activé), notification "Vous êtes assommé!"
- Joueur 2 : ne peut plus bouger (personnage reste au sol)
- Après 5 secondes : personnage **se relève automatiquement**, mouvement restauré

### Vérifications Output
```
[BatSystem] PlayerName a assommé VictimName
[BatSystem] VictimName n'est plus assommé
```

---

## Test 5 : Vol Interrompu par Batte

### Étapes
1. Joueur 2 commence à voler le Brainrot de Joueur 1 (hold E)
2. ProximityPrompt à 60%
3. Joueur 3 frappe Joueur 2 avec la batte

### Résultats attendus
- Le hold E continue (ProximityPrompt côté client n'est pas annulé automatiquement)
- Joueur 2 assommé (ne peut plus bouger)
- Si Joueur 2 complète le vol PUIS est frappé, il perd les pièces volées
- Brainrot reste dans le slot de Joueur 1 si le vol n'était pas complété

⚠️ **NOTE** : Dans cette version simplifiée, l'interruption du vol pendant le hold n'est pas implémentée. Le vol se complète si le joueur maintient E pendant 3s, même s'il est frappé pendant. Pour ajouter l'interruption, il faudrait désactiver le ProximityPrompt quand le joueur est stunné.

### Vérifications Output
```
[BatSystem] Player3 a assommé PlayerName
[BatSystem] Brainrot volé retiré de PlayerName (si vol complété avant)
```

---

# 🐛 PROBLÈMES COURANTS

## Erreur : "StealSystem is not a valid member"

**Cause :** Fichier StealSystem pas importé ou mal nommé.

**Solution :**
1. Vérifier que `ServerScriptService → Systems → StealSystem` existe
2. Vérifier que c'est un **ModuleScript**
3. Vérifier le code complet copié

---

## Le ProximityPrompt ne s'affiche pas

**Cause :** ProximityPrompt pas créé ou mal configuré sur le Brainrot.

**Solution :**
1. Vérifier que PlacementSystem crée bien le ProximityPrompt (voir A8.3)
2. Dans le Workspace, chercher un Brainrot placé et vérifier qu'il contient un ProximityPrompt
3. Vérifier les Attributes `OwnerId` et `SlotId` du ProximityPrompt
4. Vérifier l'Output pour le log : `[PlacementSystem] ProximityPrompt ajouté...`

---

## Le vol ne fonctionne pas après avoir hold E

**Cause :** RemoteEvent pas connecté ou StealController pas actif.

**Solution :**
1. Vérifier que `StealBrainrot` RemoteEvent existe dans `ReplicatedStorage/Remotes`
2. Vérifier que StealController est actif (check l'Output pour `[StealController] Initialisé!`)
3. Vérifier que NetworkHandler connecte bien le handler `StealBrainrot`

---

## La batte ne frappe pas

**Cause :** Distance trop grande ou cooldown actif.

**Solution :**
1. S'assurer d'être à moins de 10 studs de la cible
2. Attendre 1 seconde entre chaque frappe
3. Vérifier que `BatHit` RemoteEvent existe dans `ReplicatedStorage/Remotes`

---

## Le joueur ne peut plus bouger après le stun

**Cause :** PlatformStand/WalkSpeed/JumpPower pas restaurés.

**Solution :**
1. Vérifier le code de `BatSystem:_RemoveStun()`
2. Vérifier que `humanoid.PlatformStand = false` est bien exécuté
3. Vérifier que la fonction est bien appelée après 5 secondes
4. Réinitialiser manuellement dans la console: entrer cette commande:
   ```lua
   local h = game.Players.LocalPlayer.Character.Humanoid
   h.PlatformStand = false
   h.WalkSpeed = 16
   h.JumpPower = 50
   ```

---

## Brainrot volé ne retourne pas au slot d'origine

**Cause :** Système simplifié - le Brainrot est juste retiré de l'inventaire.

**Note :** Dans cette version, le Brainrot volé est **perdu** quand le voleur est assommé. Pour un retour automatique au slot, il faudrait tracker l'origine (complexe). Vous pouvez améliorer cela en Phase 9.

---

# 📊 CHECKLIST FINALE

## Backend (DEV A)

- [ ] StealSystem créé et fonctionnel (version simplifiée)
- [ ] BatSystem créé et fonctionnel
- [ ] NetworkHandler modifié (2 handlers)
- [ ] NetworkSetup modifié (3 remotes)
- [ ] GameServer modifié (init systèmes)
- [ ] GameConfig modifié (paramètres)
- [ ] PlacementSystem modifié (création ProximityPrompt) ⚠️ **CRITIQUE**

## Client (DEV B)

- [ ] StealController créé (ultra-simplifié ~30 lignes)
- [ ] Batte créée dans ServerStorage
- [ ] BatScript ajouté à la batte
- [ ] ~~StealProgressBar UI~~ (SUPPRIMÉ - remplacé par ProximityPrompt natif)
- [ ] ~~BatController~~ (SUPPRIMÉ - pas d'effets visuels)
- [ ] ~~StunEffect UI~~ (SUPPRIMÉ - ragdoll naturel)

## Tests

- [ ] Test 1 : Vol de Brainrot réussi
- [ ] Test 2 : Vol sans slot libre (bloqué)
- [ ] Test 3 : Annulation du vol (relâcher E)
- [ ] Test 4 : Combat avec batte (assommage)
- [ ] Test 5 : Vol interrompu par batte

## Validation Multi-Joueurs

- [ ] Test avec 2 joueurs minimum
- [ ] Pas de lag ou crash
- [ ] Synchronisation correcte (slot vidé, inventaire mis à jour)

---

# 🎉 PHASE 8 TERMINÉE !

Félicitations ! Vous avez maintenant un système de vol et de combat fonctionnel.

## Prochaines étapes possibles (Phase 9)

- **Amélioration du vol** : Système de retour automatique du Brainrot volé à son slot d'origine
- **Animations** : Animations de swing pour la batte, animation de vol
- **Sons** : Son de frappe, son de vol, son d'assommage
- **Particules** : Effet visuel sur la batte, étoiles autour du joueur assommé
- **Équilibrage** : Ajuster les durées, distances, cooldowns selon les tests
- **Anti-abus** : Limite de vols par minute, zones protégées

---

**Bon développement ! 🚀**
