# PHASE 4 : ARENA & INVENTORY - Guide Complet et Détaillé

**Date:** 2026-02-04  
**Status:** À faire (Phase 3 complétée)  
**Prérequis:** Phases 0, 1, 2 et 3 complétées (SYNC 3 validé)

---

## Vue d'ensemble

La Phase 4 met en place le **système d'arène** et l'**inventaire de pièces** :
- **DEV A** : Backend Arena (ArenaSystem, InventorySystem, spawn des pièces, validations pickup, mort au Spinner, handlers)
- **DEV B** : Frontend Arena (vérification setup Studio, rotation Spinner, ArenaController, UI pièces en main)

### Objectif final de la Phase 4

- Les pièces (Head/Body/Legs) spawent régulièrement dans l'arène
- Le joueur peut ramasser des pièces (max 3 en main) via ProximityPrompt
- Le serveur valide chaque pickup (pièce existe, inventaire pas plein, etc.)
- Si le joueur touche le Spinner (barre mortelle), il meurt et perd ses pièces
- Le joueur peut volontairement lâcher ses pièces (DropPieces)
- L'UI affiche les 3 slots de pièces en main

---

## Résumé des tâches

### DEV A - Backend Arena & Inventory

| #   | Tâche                 | Dépendance | Fichier                                      | Temps estimé |
|-----|------------------------|------------|----------------------------------------------|--------------|
| A4.1 | ArenaSystem (base)     | Aucune     | `Systems/ArenaSystem.module.lua`              | 1h30         |
| A4.2 | InventorySystem        | A4.1       | `Systems/InventorySystem.module.lua`         | 45min        |
| A4.3 | TryPickupPiece (4 validations) | A4.1, A4.2 | (InventorySystem ou ArenaSystem) | 45min   |
| A4.4 | Spinner Kill           | A4.2       | GameServer ou ArenaSystem                     | 30min        |
| A4.5 | Handlers Arena         | A4.3       | `Handlers/NetworkHandler.module.lua`          | 30min        |
| A4.6 | Intégration GameServer | A4.1–A4.5  | `Core/GameServer.server.lua`                  | 20min        |

**Total DEV A :** ~4h30

### DEV B - Frontend Arena

| #   | Tâche                 | Dépendance | Fichier / Lieu                         | Temps estimé |
|-----|------------------------|------------|----------------------------------------|--------------|
| B4.1 | Vérification / complétion Arena Studio | Aucune | Workspace (Studio)                | 45min        |
| B4.2 | Spinner Rotation       | B4.1       | Script dans Spinner (Studio) ou client | 45min   |
| B4.3 | ArenaController        | B4.1       | `ArenaController.module.lua`           | 1h15         |
| B4.4 | UI Pièces en main      | B4.3       | MainHUD + UIController                 | 1h           |

**Total DEV B :** ~4h

---

# DEV A - BACKEND ARENA & INVENTORY

## A4.1 - ArenaSystem.module.lua (Base)

### Description

Service qui gère le spawn des pièces dans l'arène : boucle de spawn, nettoyage (lifetime), référence vers le template et la SpawnZone.

### Dépendances

- `ReplicatedStorage/Config/GameConfig`
- `ReplicatedStorage/Data/BrainrotData`
- `ReplicatedStorage/Assets/Pieces/Piece_Template` (Model)
- Workspace : `Arena/SpawnZone`, `ActivePieces` (Folder)

### Constantes à utiliser

- `GameConfig.Arena.SpawnInterval` — secondes entre chaque spawn
- `GameConfig.Arena.MaxPiecesInArena` — max 50 pièces
- `GameConfig.Arena.PieceLifetime` — secondes avant despawn (120)
- `Constants.WorkspaceNames.ArenaFolder`, `PiecesFolder`, `SpawnZone`

### Fichier : `ServerScriptService/Systems/ArenaSystem.module.lua`

**Responsabilités :**

1. **SpawnRandomPiece()**  
   - Choisir un set et un type (Head/Body/Legs) selon les `SpawnWeight` dans `BrainrotData.Sets`.  
   - Cloner `ReplicatedStorage.Assets.Pieces.Piece_Template`.  
   - Définir sur le clone : nom unique (ex. `Piece_Skibidi_Head_12345`), attributs `SetName`, `PieceType`, `Price`, `DisplayName` (depuis BrainrotData).  
   - Mettre à jour les TextLabels du BillboardGui (NameLabel, PriceLabel) si présents.  
   - Position aléatoire dans la SpawnZone (Position + Vector3.random dans les bounds de Size).  
   - Parent : `Workspace.ActivePieces`.  
   - Stocker une référence (ex. `_pieces[pieceId] = clone`) avec un `PieceId` unique (attribut sur le modèle).  
   - Retourner le modèle cloné (ou son PieceId).

2. **SpawnLoop**  
   - Boucle `while true` : `task.wait(GameConfig.Arena.SpawnInterval)`.  
   - Compter les enfants de `Workspace.ActivePieces` (ou la table interne).  
   - Si count < `MaxPiecesInArena`, appeler `SpawnRandomPiece()`.

3. **CleanupLoop**  
   - Boucle qui tourne en parallèle : attendre un intervalle (ex. 10 s).  
   - Parcourir les pièces dans `ActivePieces` ; si une pièce a un attribut `SpawnedAt` (timestamp) et que `tick() - SpawnedAt > PieceLifetime`, la détruire et retirer de la table.

4. **GetPieceById(pieceId)**  
   - Retourner la pièce (Model) correspondant à `pieceId` (dans la table ou en trouvant l’instance dans ActivePieces avec l’attribut).

5. **RemovePiece(piece)**  
   - Retirer la pièce de la table interne, puis `piece:Destroy()`.

**Structure recommandée du module :**

- `ArenaSystem:Init(services)` — récupère GameConfig, BrainrotData, crée le folder ActivePieces s’il n’existe pas, récupère SpawnZone et Piece_Template, lance SpawnLoop et CleanupLoop.
- Utiliser un `PieceId` unique (ex. `tick() .. "_" .. math.random(1000,9999)`) stocké en attribut sur le Model pour que le client puisse envoyer cet id au serveur pour `PickupPiece`.

### Exemple de structure (à adapter à ton style)

```lua
--[[
    ArenaSystem.module.lua
    Gestion du spawn des pièces dans l'arène
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local GameConfig = nil
local BrainrotData = nil
local Constants = nil

local ArenaSystem = {}
ArenaSystem._initialized = false
ArenaSystem._pieces = {}  -- [pieceId] = piece (Model)
ArenaSystem._spawnLoopRunning = false
ArenaSystem._cleanupLoopRunning = false

function ArenaSystem:Init(services)
    if self._initialized then return end
    local Config = ReplicatedStorage:WaitForChild("Config")
    local Data = ReplicatedStorage:WaitForChild("Data")
    local Shared = ReplicatedStorage:WaitForChild("Shared")
    GameConfig = require(Config:WaitForChild("GameConfig.module"))
    BrainrotData = require(Data:WaitForChild("BrainrotData.module"))
    Constants = require(Shared:WaitForChild("Constants.module"))

    local arena = Workspace:FindFirstChild(Constants.WorkspaceNames.ArenaFolder)
    local spawnZone = arena and arena:FindFirstChild(Constants.WorkspaceNames.SpawnZone)
    local piecesFolder = Workspace:FindFirstChild(Constants.WorkspaceNames.PiecesFolder)
    if not piecesFolder then
        piecesFolder = Instance.new("Folder")
        piecesFolder.Name = Constants.WorkspaceNames.PiecesFolder
        piecesFolder.Parent = Workspace
    end

    self._spawnZone = spawnZone
    self._piecesFolder = piecesFolder
    self._template = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Pieces") and ReplicatedStorage.Assets.Pieces:FindFirstChild("Piece_Template")

    if not self._template or not self._spawnZone then
        warn("[ArenaSystem] Piece_Template ou SpawnZone manquant. Spawn désactivé.")
    else
        self:_StartSpawnLoop()
        self:_StartCleanupLoop()
    end

    self._initialized = true
    print("[ArenaSystem] Initialisé")
end

function ArenaSystem:SpawnRandomPiece()
    -- 1) Choisir set + pieceType selon SpawnWeight
    -- 2) Clone template, set attributes, position in SpawnZone, parent = _piecesFolder
    -- 3) Store in _pieces[pieceId], return piece
end

function ArenaSystem:GetPieceById(pieceId)
    return self._pieces[pieceId]
end

function ArenaSystem:RemovePiece(piece)
    local id = piece:GetAttribute("PieceId")
    if id then self._pieces[id] = nil end
    piece:Destroy()
end

function ArenaSystem:_StartSpawnLoop()
    -- while true; wait(SpawnInterval); if #pieces < MaxPiecesInArena then SpawnRandomPiece() end
end

function ArenaSystem:_StartCleanupLoop()
    -- every 10s, for each piece if tick()-SpawnedAt > PieceLifetime then RemovePiece(piece) end
end

return ArenaSystem
```

Tu dois implémenter la logique complète de sélection pondérée (SpawnWeight) et du clone (attributs, labels, position).

---

## A4.2 - InventorySystem.module.lua

### Description

Module qui centralise la logique “inventaire de pièces en main” côté serveur. Il s’appuie sur **PlayerService** (GetPiecesInHand, AddPieceToHand, ClearPiecesInHand) et expose une méthode **TryPickupPiece** qui fait les validations puis ajoute la pièce et retire celle-ci de l’arène.

### Dépendances

- `ServerScriptService/Core/PlayerService`
- `ServerScriptService/Systems/ArenaSystem`
- `ReplicatedStorage/Config/GameConfig` (Inventory.MaxPiecesInHand = 3)
- `ReplicatedStorage/Shared/Constants` (ActionResult)

### Fichier : `ServerScriptService/Systems/InventorySystem.module.lua`

**Responsabilités :**

1. **GetPiecesInHand(player)** — délègue à `PlayerService:GetPiecesInHand(player)`.
2. **AddPiece(player, pieceData)** — délègue à `PlayerService:AddPieceToHand(player, pieceData)` (vérifier retour boolean).
3. **ClearInventory(player)** — délègue à `PlayerService:ClearPiecesInHand(player)`.
4. **TryPickupPiece(player, pieceId)** (cœur de A4.3) :
   - **Validation 1** : La pièce existe (ArenaSystem:GetPieceById(pieceId) non nil).
   - **Validation 2** : Le joueur n’a pas déjà 3 pièces (GetPiecesInHand(player) count < MaxPiecesInHand).
   - **Validation 3** : La pièce a les attributs requis (SetName, PieceType, Price, DisplayName).
   - **Validation 4** (optionnelle) : La pièce est bien dans ActivePieces (déjà garanti si GetPieceById la retourne).
   - Si tout est ok : construire `pieceData = { SetName, PieceType, Price, DisplayName }`, appeler `PlayerService:AddPieceToHand(player, pieceData)`, puis `ArenaSystem:RemovePiece(piece)`, et retourner `Constants.ActionResult.Success` + pieceData pour la sync client.
   - Sinon retourner un code d’erreur (InvalidPiece, InventoryFull, etc.).

Format de retour recommandé : `success (boolean), result (string ActionResult), pieceData (table ou nil)`.

---

## A4.3 - TryPickupPiece (4 validations)

Détail des validations à faire dans `InventorySystem:TryPickupPiece(player, pieceId)` :

| # | Validation            | Si échoué              | ActionResult        |
|---|------------------------|------------------------|---------------------|
| 1 | Pièce existe (GetPieceById) | Pièce déjà ramassée ou despawn | `InvalidPiece`   |
| 2 | Inventaire pas plein (< 3)  | Main déjà pleine        | `InventoryFull`    |
| 3 | Attributs valides sur la pièce | Données corrompues   | `InvalidPiece`     |
| 4 | Pièce bien dans ActivePieces | Déjà retirée          | `InvalidPiece`     |

Après succès : ajouter la pièce à la main du joueur, supprimer la pièce de l’arène, renvoyer Success + pieceData pour que le handler envoie SyncInventory au client.

---

## A4.4 - Spinner Kill

### Description

Quand un joueur touche la barre du Spinner (part avec attribut `Deadly = true`), il doit mourir et perdre ses pièces. La perte est déjà gérée dans **PlayerService:OnPlayerDied** (ClearPiecesInHand + SyncInventory + notification). Il reste à **déclencher la mort** depuis le Spinner.

### Options d’implémentation

**Option 1 – Dans GameServer (recommandé)**  
Après l’init des systèmes, récupérer `Workspace.Arena.Spinner`. Trouver la Part “Bar” (ou la première avec attribut `Deadly`). Connecter `Bar.Touched` : si l’objet touché est un caractère (Humanoid), récupérer le Player et faire `character.Humanoid.Health = 0` (ou `Humanoid:TakeDamage(9999)`). Ainsi `Humanoid.Died` sera déclenché et `PlayerService:OnPlayerDied` fera le reste (vider les pièces, notification, respawn à la base).

**Option 2 – Dans ArenaSystem**  
Exposer une méthode `ArenaSystem:RegisterSpinnerKill(spinnerModel)` qui fait la même logique Touched → kill. Appelée depuis GameServer après Init.

### Points d’attention

- Vérifier que la Part a l’attribut `Deadly == true` pour éviter de tuer sur d’autres murs.
- Ne pas tuer deux fois (debounce court ou vérifier que Humanoid.Health > 0 avant d’appliquer les dégâts).

---

## A4.5 - Handlers Arena (NetworkHandler)

### À modifier : `ServerScriptService/Handlers/NetworkHandler.module.lua`

1. **Injecter ArenaSystem et InventorySystem**  
   Dans `Init` / `UpdateSystems`, accepter `ArenaSystem` et `InventorySystem` et les stocker en local (comme pour EconomySystem).

2. **_HandlePickupPiece(player, pieceId)**  
   - Remplacer le placeholder actuel par :  
     `local success, result, pieceData = InventorySystem:TryPickupPiece(player, pieceId)`  
   - Si success : envoyer au client `SyncInventory` avec la nouvelle liste (GetPiecesInHand), et une notification “Piece picked up!” (ou SuccessMessages.PiecePickedUp).  
   - Si échec : envoyer une notification avec le message d’erreur correspondant (ErrorMessages.InventoryFull, InvalidPiece, etc.).

3. **_HandleDropPieces(player)**  
   - Déjà implémenté (PlayerService:ClearPiecesInHand + SyncInventory). Rien à changer sauf si tu veux ajouter une logique côté Arena (ex. faire réapparaître les pièces au sol) ; pour la Phase 4, “lâcher” = simplement vider la main et sync.

S’assurer que les Remotes `PickupPiece` et `DropPieces` sont bien connectés (déjà le cas d’après le code existant).

---

## A4.6 - Intégration GameServer

### Fichier : `ServerScriptService/Core/GameServer.server.lua`

- Après EconomySystem (et après la section CollectPad si présente) :
  1. Charger `ArenaSystem` et `InventorySystem` depuis `Systems` (avec pcall si tu veux désactiver proprement en cas d’erreur).
  2. Appeler `ArenaSystem:Init({ ... })` avec les services nécessaires (au minimum les refs vers ReplicatedStorage/Workspace si besoin ; pas obligatoire si les modules utilisent game:GetService).
  3. Appeler `InventorySystem:Init({ PlayerService, ArenaSystem })`.
  4. Mettre à jour NetworkHandler avec `UpdateSystems({ ArenaSystem = ..., InventorySystem = ... })`.
  5. Ajouter la logique **Spinner Kill** (Touched sur la Bar Deadly → Humanoid.Health = 0 ou TakeDamage).

Ordre suggéré :  
`ArenaSystem:Init` → `InventorySystem:Init` → `NetworkHandler:UpdateSystems` → connexion Spinner.Touched.

---

# DEV B - FRONTEND ARENA

## B4.1 - Vérification / complétion Arena Studio

### À vérifier dans Roblox Studio

- **Workspace**
  - `Arena` (Folder) avec :
    - `SpawnZone` (Part) : Size/Position pour couvrir la zone de spawn, Transparency = 1, CanCollide = false si besoin.
    - `Spinner` (Model) : `Center` (Part), `Bar` (Part) avec **attribut Deadly = true**.
    - Optionnel : `Canon`, `Boundaries`.
  - `ActivePieces` (Folder) — vide au départ, créable par le serveur si absent.
- **ReplicatedStorage**
  - `Assets/Pieces/Piece_Template` (Model) avec :
    - `MainPart` (PrimaryPart), BillboardGui avec `NameLabel`, `PriceLabel`.
    - `Visual`, `PickupZone` avec **ProximityPrompt** (ActionText "Ramasser", HoldDuration 0).

Si quelque chose manque, le créer selon `ROBLOX_SETUP_GUIDE.md` (sections Arena, Piece_Template).

---

## B4.2 - Spinner Rotation

### Description

La barre du Spinner doit tourner en continu pour représenter le danger. La vitesse est dans `GameConfig.Arena.SpinnerSpeed` (tours par seconde).

### Implémentation

- **Option A – Script côté client**  
  Un LocalScript dans `StarterPlayer.StarterPlayerScripts` (ou dans `StarterCharacterScripts`) qui trouve une fois `Workspace.Arena.Spinner` et la Part `Bar`, puis dans un RenderStepped ou une boucle avec `RunService.Heartbeat` applique une rotation incrémentale à `Bar` autour du `Center` (CFrame du Center comme pivot, rotation en Y par exemple : `Bar.CFrame = center.CFrame * CFrame.Angles(0, angle, 0) * offset`).

- **Option B – Script côté serveur**  
  Un script dans `ServerScriptService` qui fait la même chose sur le Spinner pour que tout le monde voie la même rotation (plus cohérent pour le hitbox).

Formule : `angle = angle + (deltaTime * 2 * math.pi * GameConfig.Arena.SpinnerSpeed)` (2π = 1 tour).

Tu peux récupérer GameConfig côté client via un require du module (ReplicatedStorage.Config.GameConfig).

---

## B4.3 - ArenaController.module.lua

### Description

Contrôleur client qui écoute les ProximityPrompts des pièces dans l’arène et appelle le serveur pour ramasser une pièce (PickupPiece), et qui écoute SyncInventory pour mettre à jour l’UI.

### Fichier : `StarterPlayer/StarterPlayerScripts/ArenaController.module.lua`

**Responsabilités :**

1. **Initialisation**  
   - Attendre que `Workspace.ActivePieces` existe (ou le créer côté client n’est pas nécessaire ; le serveur le crée).  
   - S’abonner à `ActivePieces.ChildAdded` : pour chaque nouvelle pièce (Model), trouver le ProximityPrompt (ex. dans PickupZone) et connecter `Triggered`. Dans `Triggered`, récupérer le `PieceId` (attribut sur le modèle) et appeler `RemoteEvents.PickupPiece:FireServer(pieceId)`.

2. **Pièces déjà présentes**  
   - Au chargement, parcourir les enfants existants de `ActivePieces` et connecter leurs ProximityPrompts de la même façon.

3. **SyncInventory**  
   - Écouter le Remote `SyncInventory` (OnClientEvent). Quand le serveur envoie la liste des pièces en main, stocker localement et mettre à jour l’UI (voir B4.4).

4. **Bouton / raccourci “Lâcher les pièces”**  
   - Si tu as une touche ou un bouton “Drop”, appeler `DropPieces:FireServer()`.

Structure possible :

```lua
-- ArenaController.module.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaController = {}
local _remotes = nil
local _inventory = {} -- cache local des pièces en main

function ArenaController:Init()
    local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
    _remotes = {
        PickupPiece = remotesFolder:WaitForChild("PickupPiece"),
        DropPieces = remotesFolder:WaitForChild("DropPieces"),
        SyncInventory = remotesFolder:WaitForChild("SyncInventory"),
    }
    _remotes.SyncInventory.OnClientEvent:Connect(function(pieces)
        _inventory = pieces or {}
        -- Notifier l'UI (UIController ou bindings)
    end)
    self:_ConnectActivePieces()
end

function ArenaController:_ConnectActivePieces()
    local piecesFolder = Workspace:WaitForChild("ActivePieces", 10)
    if not piecesFolder then return end
    local function connectPrompt(piece)
        local pickupZone = piece:FindFirstChild("PickupZone")
        if not pickupZone then return end
        local prompt = pickupZone:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then return end
        prompt.Triggered:Connect(function(player)
            local pieceId = piece:GetAttribute("PieceId")
            if pieceId then
                _remotes.PickupPiece:FireServer(pieceId)
            end
        end)
    end
    for _, piece in ipairs(piecesFolder:GetChildren()) do
        connectPrompt(piece)
    end
    piecesFolder.ChildAdded:Connect(connectPrompt)
end

function ArenaController:GetInventory()
    return _inventory
end

return ArenaController
```

Le `PieceId` doit être défini côté serveur sur chaque pièce spawnée et être l’identifiant envoyé au serveur (string ou number selon ce que tu utilises dans ArenaSystem).

---

## B4.4 - UI Pièces en main

### Description

Afficher les 3 emplacements “pièces en main” dans le MainHUD (ou une petite barre dédiée) : icône ou nom de la pièce, ou placeholder vide.

### Où

- Dans l’écran principal (MainHUD) : une ligne ou une rangée de 3 frames/slots.
- Chaque slot affiche soit vide, soit le nom/icône de la pièce (ex. “Skibidi Head”, “Rizz Body”).
- Les données viennent de **ArenaController:GetInventory()** ou d’un callback/callback émis quand SyncInventory est reçu.

### Implémentation

1. **StarterGui**  
   Créer 3 TextLabels ou ImageLabels (ou Frames avec un TextLabel) nommés par exemple `PieceSlot1`, `PieceSlot2`, `PieceSlot3`. Par défaut texte = "" ou "—".

2. **UIController (ou ArenaController)**  
   Quand SyncInventory est reçu, mettre à jour les 3 slots : pour chaque index 1–3, si `pieces[i]` existe, afficher `pieces[i].DisplayName .. " " .. pieces[i].PieceType` (ou une icône si tu en as), sinon laisser vide.

3. **Animations (optionnel)**  
   Petit effet quand une pièce est ajoutée (scale, couleur) pour feedback visuel.

Référence : `Constants.ErrorMessages.InventoryFull` pour afficher “Inventaire plein (max 3)” si le serveur renvoie InventoryFull.

---

# SYNC 4 - Test Arena Complet

## Checklist de validation

- [ ] Les pièces apparaissent dans l’arène à intervalle régulier (SpawnInterval).
- [ ] Le nombre de pièces ne dépasse pas MaxPiecesInArena (50).
- [ ] En appuyant sur E sur une pièce : pickup si place libre, sinon notification “Inventaire plein”.
- [ ] Après pickup, la pièce disparaît de l’arène et apparaît dans l’UI “pièces en main”.
- [ ] En touchant la barre du Spinner, le joueur meurt, perd ses pièces et respawn à sa base ; notification “You died! X piece(s) lost.”
- [ ] DropPieces (bouton ou touche) vide la main et met à jour l’UI.
- [ ] SyncInventory reçu au login / après respawn reflète bien l’état serveur (vide après mort).

---

# Récapitulatif des fichiers

| Rôle   | Fichier                                  | Action      |
|--------|------------------------------------------|------------|
| DEV A  | `ServerScriptService/Systems/ArenaSystem.module.lua`     | Créer      |
| DEV A  | `ServerScriptService/Systems/InventorySystem.module.lua` | Créer      |
| DEV A  | `ServerScriptService/Handlers/NetworkHandler.module.lua`   | Modifier   |
| DEV A  | `ServerScriptService/Core/GameServer.server.lua`         | Modifier   |
| DEV B  | Workspace Arena + ActivePieces + Piece_Template           | Vérifier/Créer (Studio) |
| DEV B  | Spinner rotation (script client ou serveur)              | Créer      |
| DEV B  | `StarterPlayer/StarterPlayerScripts/ArenaController.module.lua` | Créer  |
| DEV B  | MainHUD (3 slots pièces) + liaison SyncInventory         | Créer/Modifier |
| DEV B  | `StarterPlayer/StarterPlayerScripts/ClientMain.client.lua` | Modifier (init ArenaController) |

---

# Références rapides

- **GameConfig.Arena** : SpawnInterval, MaxPiecesInArena, PieceLifetime, SpinnerSpeed  
- **GameConfig.Inventory** : MaxPiecesInHand = 3  
- **Constants** : ActionResult (Success, InvalidPiece, InventoryFull), ErrorMessages, WorkspaceNames (ArenaFolder, SpawnZone, PiecesFolder), RemoteNames (PickupPiece, DropPieces, SyncInventory)  
- **BrainrotData** : Sets[setName].Head/Body/Legs (Price, DisplayName, ModelName, SpawnWeight)  
- **PlayerService** : GetPiecesInHand, AddPieceToHand, ClearPiecesInHand, OnPlayerDied (vide déjà les pièces + SyncInventory + notification)

---

**Fin du Guide Phase 4**
