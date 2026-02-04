# PHASE 6 : CODEX & PROGRESSION - Guide Complet et Détaillé

**Date:** 2026-02-04  
**Status:** À faire (Phase 5.5 complétée)  
**Prérequis:** Phases 0, 1, 2, 3, 4, 5 et 5.5 complétées (SYNC 5.5 validé)

---

## Vue d'ensemble

La Phase 6 met en place l’**interface Codex** et la **synchronisation dédiée** du Codex :
- **DEV A** : Backend Codex (envoi SyncCodex à la connexion et après chaque déblocage, optional CodexService si besoin)
- **DEV B** : Frontend Codex (CodexUI dans Studio, CodexController, ouverture/fermeture, affichage sets débloqués/verrouillés)

### Objectif final de la Phase 6

- Le joueur peut ouvrir un menu **Codex** via un **bouton dans le MainHUD** qui affiche tous les sets de Brainrots
- Les sets **débloqués** (craftés au moins une fois) sont visibles avec nom, rareté, et optionnellement visuel
- Les sets **verrouillés** sont affichés en grisé avec "???" ou icône cadenas
- Le serveur envoie **SyncCodex** à la connexion et après chaque `UnlockCodexEntry` pour que le client ait toujours le Codex à jour
- L’UI de progression (optionnel) peut afficher un résumé : X/Y sets débloqués

---

## Résumé des tâches

### DEV A - Backend Codex & Sync

| #   | Tâche                              | Dépendance | Fichier                                      | Temps estimé |
|-----|------------------------------------|------------|----------------------------------------------|--------------|
| A6.1 | Envoi SyncCodex à la connexion     | Aucune     | GameServer ou PlayerService                  | 30min        |
| A6.2 | Envoi SyncCodex après UnlockCodex  | A6.1       | DataService ou CraftingSystem / NetworkHandler | 30min     |
| A6.3 | (Optionnel) CodexService           | A6.1       | Systems/CodexService.module.lua              | 45min        |
| A6.4 | Vérification NetworkHandler        | A6.1–A6.2  | Handlers/NetworkHandler.module.lua           | 15min        |

**Total DEV A :** ~2h

### DEV B - Frontend Codex (UI & Controller)

| #   | Tâche                              | Dépendance | Fichier / Lieu                         | Temps estimé |
|-----|------------------------------------|------------|----------------------------------------|--------------|
| B6.1 | CodexUI ScreenGui (Studio)         | Aucune     | StarterGui                              | 1h           |
| B6.2 | CodexController.module.lua         | B6.1       | StarterPlayerScripts                    | 1h30         |
| B6.3 | Connexion ClientMain + SyncCodex   | B6.2       | ClientMain.client.lua                  | 30min        |
| B6.4 | Bouton Codex dans MainHUD          | B6.2       | MainHUD + CodexController / ClientMain | 30min        |
| B6.5 | Affichage sets (débloqués/verrouillés) | B6.2    | CodexController + BrainrotData         | 1h           |
| B6.6 | Polish (animations, rareté couleurs)| B6.5       | CodexController / CodexUI              | 45min        |

**Total DEV B :** ~5h15

---

# DEV A - BACKEND CODEX & SYNC

## A6.1 - Envoi SyncCodex à la connexion

### Description

Au moment où un joueur rejoint la partie et que ses données sont chargées, le serveur doit envoyer **SyncCodex** au client avec la table `CodexUnlocked` pour que l’UI Codex puisse s’afficher sans attendre une autre action.

### Où l’implémenter

- **Recommandé** : Dans **PlayerService.module.lua**, dans la fonction **OnPlayerJoined** (ou équivalent), immédiatement **après** l’envoi de `SyncPlayerData` au client. Les variables `player`, `playerData` et `remotes` sont déjà disponibles à cet endroit.

### Spécification

1. Dans la même fonction où vous faites `remotes.SyncPlayerData:FireClient(player, playerData)`.
2. Juste après, appeler `remotes.SyncCodex:FireClient(player, playerData.CodexUnlocked or {})`.
3. Vérifier que `remotes.SyncCodex` existe avant d’appeler (comme pour SyncPlayerData).

**Important :** Cet envoi a lieu une seule fois par connexion, après le chargement des données joueur.

### Exemple (dans PlayerService.module.lua, fonction OnPlayerJoined)

```lua
-- 5. Envoyer les données au client
local remotes = NetworkSetup:GetAllRemotes()
if remotes.SyncPlayerData then
    remotes.SyncPlayerData:FireClient(player, playerData)
    print("[PlayerService] Données envoyées au client: " .. player.Name)
end
-- Phase 6: envoyer le Codex au client
if remotes.SyncCodex then
    remotes.SyncCodex:FireClient(player, playerData.CodexUnlocked or {})
end
```

---

## A6.2 - Envoi SyncCodex après UnlockCodexEntry

### Description

Chaque fois qu’une entrée du Codex est débloquée (`DataService:UnlockCodexEntry(player, setName)`), le serveur doit envoyer **SyncCodex** au joueur concerné avec la table **complète** à jour (`CodexUnlocked`), pour que le client mette à jour l’UI immédiatement après un craft.

### Où l’implémenter

- **Recommandé** : Dans **DataService:UnlockCodexEntry**, après avoir mis à jour `playerData.CodexUnlocked`. Pour cela, **DataService** doit avoir accès à **NetworkSetup** : modifier **DataService:Init(services)** pour accepter une table optionnelle `services` et stocker `self._networkSetup = services.NetworkSetup`. Dans **GameServer.server.lua**, passer NetworkSetup à DataService lors de l’init : `DataService:Init({ NetworkSetup = NetworkSetup })`.

### Spécification

1. Après `playerData.CodexUnlocked[setName] = true` (et le `print` existant).
2. Si `self._networkSetup` est défini : `local remotes = self._networkSetup:GetAllRemotes()` puis `remotes.SyncCodex:FireClient(player, playerData.CodexUnlocked)`.
3. Ne pas faire d’erreur si NetworkSetup est absent (rétrocompatibilité).

**Payload SyncCodex :** toujours une table `{[setName] = true}` pour tous les sets débloqués. Le client remplace sa copie locale par cette table.

### Exemple (dans DataService.module.lua)

**Init** — accepter une table optionnelle et stocker NetworkSetup :

```lua
function DataService:Init(services)
    if self._initialized then
        warn("[DataService] Déjà initialisé!")
        return
    end
    -- ... création DataStore, auto-save, etc. ...
    if services and services.NetworkSetup then
        self._networkSetup = services.NetworkSetup
    end
    self._initialized = true
    print("[DataService] Initialisé!")
end
```

**UnlockCodexEntry** — à la fin de la fonction, après avoir débloqué :

```lua
    playerData.CodexUnlocked[setName] = true
    print("[DataService] Codex débloqué: " .. player.Name .. " - " .. setName)

    -- Phase 6: notifier le client
    if self._networkSetup then
        local remotes = self._networkSetup:GetAllRemotes()
        if remotes and remotes.SyncCodex then
            remotes.SyncCodex:FireClient(player, playerData.CodexUnlocked)
        end
    end
    return true
end
```

**GameServer.server.lua** — modifier l’appel à DataService:Init :

```lua
DataService:Init({ NetworkSetup = NetworkSetup })
```

---

## A6.3 - (Optionnel) CodexService

### Description

Centraliser la logique “envoyer le Codex à un joueur” dans un module dédié pour éviter de dupliquer les appels à `SyncCodex` et pour pouvoir ajouter plus tard des règles (ex. filtrage, format étendu).

### Fichier : `ServerScriptService/Systems/CodexService.module.lua`

**Responsabilités :**

1. **SendCodexToPlayer(player)**  
   - Récupère `DataService:GetPlayerData(player).CodexUnlocked`.  
   - Envoie `SyncCodex:FireClient(player, codexUnlocked or {})`.  
   - Utilisé à la connexion et après `UnlockCodexEntry` (DataService ou CraftingSystem appelle `CodexService:SendCodexToPlayer(player)`).

**Init :**  
- `CodexService:Init(services)` avec `DataService` et `NetworkSetup` (ou accès aux Remotes).

Si vous préférez garder le serveur simple, A6.1 et A6.2 suffisent sans CodexService.

---

## A6.4 - Vérification NetworkHandler

### Description

- Vérifier que **aucun** handler existant n’écrase ou ne duplique la sémantique de SyncCodex.
- S’assurer que les données envoyées dans `SyncPlayerData` incluent bien `CodexUnlocked` (déjà le cas d’après le code existant) pour que le client puisse aussi se rafraîchir avec la synchro globale si besoin.
- Aucun nouveau Remote n’est requis : `SyncCodex` existe déjà dans `Constants.RemoteNames`.

---

# DEV B - FRONTEND CODEX (UI & CONTROLLER)

## B6.1 - CodexUI ScreenGui (Studio)

### Description

Créer dans **StarterGui** un **ScreenGui** nommé **CodexUI**, désactivé par défaut (`Enabled = false`), qui sera affiché par le CodexController. Les noms des instances doivent correspondre exactement à ceux utilisés dans le CodexController (Background, CloseButton, ListContainer, Subtitle, etc.).

### Structure de la hiérarchie

```
StarterGui
└── CodexUI (ScreenGui)
    └── Background (Frame)
        ├── UICorner
        ├── Title (TextLabel)
        ├── Subtitle (TextLabel)
        ├── ListContainer (ScrollingFrame)
        │   └── UIGridLayout
        ├── CloseButton (TextButton)
        └── (optionnel) SetEntryTemplate (Frame, Visible = false)
            ├── SetName (TextLabel)
            ├── Rarity (TextLabel)
            └── LockedOverlay (Frame)
```

---

### Création pas à pas dans Studio

#### Étape 1 – ScreenGui

1. Dans l’explorateur : **StarterGui** → Clic droit → **Insert Object** → **ScreenGui**.
2. Renommer en **CodexUI**.
3. Propriétés à régler :

| Propriété      | Valeur        | Note |
|----------------|---------------|------|
| **Name**       | `CodexUI`     | Obligatoire pour le script |
| **Enabled**    | `false`       | Masqué au démarrage, ouvert par le bouton Codex |
| **IgnoreGuiInset** | `false` | Optionnel |
| **DisplayOrder**   | `10`      | Optionnel (au-dessus des autres UI) |

---

#### Étape 2 – Frame principale (Background)

1. Clic droit sur **CodexUI** → **Insert Object** → **Frame**.
2. Renommer en **Background**.
3. Propriétés :

| Propriété          | Valeur | Note |
|--------------------|--------|------|
| **Name**           | `Background` | Utilisé par CodexController |
| **Size**           | `{0.5, 0}, {0.65, 0}` | 50 % largeur, 65 % hauteur (ou `Scale` 0.5 / 0.65) |
| **Position**       | `{0.25, 0}, {0.175, 0}` | Centré (25 % + 50/2, 17.5 % + 65/2) |
| **AnchorPoint**    | `0.5, 0.5` | Centrage |
| **BackgroundColor3**| `0.12, 0.12, 0.18` (RGB) ou thème sombre | Fond du panneau |
| **BackgroundTransparency** | `0.1` | Légèrement opaque |
| **BorderSizePixel**| `0` | Pas de bordure |
| **ClipsDescendants** | `true` | Pour ScrollFrame à l’intérieur |

4. **UICorner** : Clic droit sur **Background** → **Insert Object** → **UICorner**.
   - **CornerRadius** : `{0, 12}` (12 px d’arrondi).

---

#### Étape 3 – Titre (Title)

1. Clic droit sur **Background** → **Insert Object** → **TextLabel**.
2. Renommer en **Title**.

| Propriété          | Valeur | Note |
|--------------------|--------|------|
| **Name**           | `Title` | |
| **Size**           | `{1, 0}, {0, 50}` | Pleine largeur, 50 px de haut |
| **Position**       | `{0, 0}, {0, 0}` | En haut |
| **AnchorPoint**    | `0.5, 0` | |
| **BackgroundTransparency** | `1` | Transparent |
| **Text**           | `BRAINROT CODEX` ou `CODEX` | |
| **TextColor3**     | Blanc ou accent (ex. 1, 0.85, 0.4) | |
| **TextSize**       | `24` ou `28` | |
| **Font**           | `GothamBold` ou `GothamBlack` | |
| **TextXAlignment** | `Center` | |
| **TextYAlignment** | `Center` | |

---

#### Étape 4 – Sous-titre (Subtitle) – compteur X / Y

1. **Insert Object** → **TextLabel** dans **Background**.
2. Renommer en **Subtitle**.

| Propriété          | Valeur | Note |
|--------------------|--------|------|
| **Name**           | `Subtitle` | Mis à jour par RefreshList (B6.5) |
| **Size**           | `{1, 0}, {0, 22}` | |
| **Position**       | `{0.5, 0}, {0, 48}` | Juste sous le titre |
| **AnchorPoint**    | `0.5, 0` | |
| **BackgroundTransparency** | `1` | |
| **Text**           | `0 / 0 sets unlocked` | Valeur par défaut |
| **TextColor3**     | Gris clair (ex. 0.7, 0.7, 0.7) | |
| **TextSize**       | `14` | |
| **Font**           | `Gotham` | |
| **TextXAlignment** | `Center` | |

---

#### Étape 5 – Conteneur de la liste (ListContainer) – Option B : ScrollFrame + UIGridLayout

Utiliser un **ScrollingFrame** avec **UIGridLayout** pour afficher les sets avec scroll vertical si la liste est longue.

1. **Insert Object** → **ScrollingFrame** dans **Background**, nom : **ListContainer**.
2. Propriétés du **ScrollingFrame** :

| Propriété          | Valeur | Note |
|--------------------|--------|------|
| **Name**           | `ListContainer` | CodexController utilise ce nom |
| **Size**           | `{1, -24}, {1, -140}` | Pleine largeur/hauteur moins titre + bouton (ajuster -140 selon votre layout) |
| **Position**       | `{0, 0}, {0, 72}` | Sous Title + Subtitle (50+22) |
| **AnchorPoint**    | `0, 0` | |
| **BackgroundTransparency** | `1` ou léger fond | |
| **CanvasSize**     | `{0, 0}, {0, 0}` | Mis à jour par RefreshList (B6.5) |
| **ScrollBarThickness** | `6` | Épaisseur de la barre de scroll |
| **ScrollBarImageColor3** | Gris ou couleur accent | |
| **ClipsDescendants** | `true` | Coupe le contenu qui dépasse |

3. Dans **ListContainer** (le ScrollingFrame) : **Insert Object** → **UIGridLayout**.
4. Propriétés du **UIGridLayout** :

| Propriété          | Valeur | Note |
|--------------------|--------|------|
| **CellSize**       | `{1, 0}, {0, 56}` | Taille de chaque cellule : 100 % largeur, 56 px de haut (3 slots Head/Body/Legs par ligne) |
| **CellPadding**    | `{0, 4}, {0, 4}` | 4 px d’espace horizontal et vertical entre les cellules |
| **FillDirection**  | `Vertical` | Les entrées s’empilent en colonne (une par ligne) |
| **HorizontalAlignment** | `Center` | Centrage horizontal des cellules |
| **VerticalAlignment** | `Top` | Aligner en haut |
| **SortOrder**      | `LayoutOrder` | Les entrées créées en script doivent avoir un **LayoutOrder** (1, 2, 3…) |

**Remarque CellSize :** en Studio, UDim2 s’affiche comme `{1, 0}, {0, 44}` (scale 1 = 100 % largeur, offset 44 pour la hauteur en px).

5. **RefreshList** (B6.5) doit mettre à jour **CanvasSize** du ScrollingFrame en fonction du contenu (voir l’exemple avec `layout.AbsoluteContentSize.Y`).

**Option A – Frame + UIGridLayout (sans scroll)** : si vous préférez une simple Frame sans scroll, créez une **Frame** nommée **ListContainer** avec les mêmes Size/Position, puis ajoutez le **UIGridLayout** à l’intérieur. Pas besoin de mettre à jour CanvasSize dans RefreshList.

---

#### Étape 6 – Bouton Fermer (CloseButton)

1. **Insert Object** → **TextButton** dans **Background**.
2. Renommer en **CloseButton**.

| Propriété          | Valeur | Note |
|--------------------|--------|------|
| **Name**           | `CloseButton` | Connecté dans CodexController |
| **Size**           | `{0, 44}, {0, 44}` | 44×44 px |
| **Position**       | `{1, 0}, {0, 8}` | Coin supérieur droit (avec marge 8) |
| **AnchorPoint**    | `1, 0` | |
| **BackgroundColor3**| Rouge léger ou gris (ex. 0.6, 0.2, 0.2) | |
| **BackgroundTransparency** | `0` ou `0.3` | |
| **Text**           | `X` ou `Fermer` | |
| **TextColor3**     | Blanc | |
| **TextSize**       | `18` ou `22` | |
| **Font**           | `GothamBold` | |

8. **UICorner** sur le bouton : **CornerRadius** `{0, 8}`.

---

#### Étape 7 – (Optionnel) Template d’entrée SetEntry

Si vous préférez un template à cloner au lieu de créer les Frames en Lua (B6.5), créez une Frame exemple **dans** **ListContainer** (ou ailleurs et déplacez-la) :

1. **Frame** nommée **SetEntryTemplate**.
2. **Visible** = `false` pour qu’elle ne s’affiche pas telle quelle (le script clonera et affichera).
3. **Size** : `{1, -20}, {0, 40}` (hauteur 40 px).
4. **BackgroundColor3** : gris moyen ; **BackgroundTransparency** : `0.5`.
5. À l’intérieur :
   - **SetName** (TextLabel) : Position `{0, 8}, {0, 4}`, Size `{0.6, -16}, {1, -8}`, Text `"Set Name"`, TextXAlignment Left, TextSize 14.
   - **Rarity** (TextLabel) : Position `{0.6, 8}, {0, 4}`, Size `{0.35, -16}, {1, -8}`, Text `"Common"`, TextXAlignment Right, TextSize 12.
   - **LockedOverlay** (Frame) : couvre toute la Frame, BackgroundTransparency 0.5, Visible = false par défaut ; le script l’affichera pour les sets verrouillés.

Le CodexController (B6.5) peut soit créer les entrées en Lua sans template, soit cloner **SetEntryTemplate** et remplir **SetName** / **Rarity** / **LockedOverlay**.

---

### Récapitulatif des noms obligatoires

| Instance       | Parent      | Nom exact       | Utilisation |
|---------------|-------------|-----------------|-------------|
| ScreenGui     | StarterGui  | `CodexUI`       | Référence dans CodexController |
| Frame         | CodexUI     | `Background`    | Conteneur principal |
| TextLabel     | Background  | `Title`         | Titre |
| TextLabel     | Background  | `Subtitle`      | Compteur (RefreshList) |
| ScrollingFrame     | Background | `ListContainer` | Conteneur des lignes de sets (avec scroll) |
| TextButton    | Background  | `CloseButton`   | Fermer (clic → Close()) |

---

### Propriétés suggérées (résumé)

- **Background** : fond semi-transparent, centré (AnchorPoint 0.5, 0.5), taille ~50 % × 65 %.
- **ListContainer** : **ScrollingFrame** avec **UIGridLayout** (CellSize, CellPadding, FillDirection Vertical, SortOrder LayoutOrder). RefreshList met à jour **CanvasSize** pour le scroll.
- Les entrées de sets peuvent être **générées entièrement en Lua** (B6.5) ; le template **SetEntryTemplate** est optionnel.

---

## B6.2 - CodexController.module.lua

### Description

Module **client** qui :
- Reçoit les mises à jour du Codex via l’événement **SyncCodex**.
- Affiche / masque le **CodexUI** (ouvrir / fermer).
- Construit ou met à jour la liste des sets (débloqués / verrouillés) à partir de `BrainrotData.Sets` et de la table `CodexUnlocked` reçue du serveur.

### Dépendances

- `ReplicatedStorage/Data/BrainrotData.module`
- `ReplicatedStorage/Shared/Constants.module`
- `ReplicatedStorage/Remotes` (SyncCodex)
- CodexUI dans StarterGui (référencé par nom "CodexUI")

### API recommandée

| Méthode / rôle | Description |
|----------------|-------------|
| **CodexController:Init()** | Récupère les refs (CodexUI, BrainrotData, Remotes), connecte SyncCodex.OnClientEvent à UpdateCodex. |
| **CodexController:UpdateCodex(codexUnlocked)** | Reçoit `{[setName] = true}`. Stocke en local, appelle RefreshList() pour mettre à jour l’affichage. |
| **CodexController:Open()** | Affiche le Codex (Enabled = true, ou Visible selon structure). Optionnel : demander les données au serveur si vous ajoutez un GetCodex. |
| **CodexController:Close()** | Cache le Codex (Enabled = false). |
| **CodexController:RefreshList()** | Parcourt `BrainrotData.Sets`, pour chaque set crée ou met à jour une entrée (nom, rareté, locked/unlocked). |
| **CodexController:IsOpen()** | Retourne true/false selon l’état d’affichage. |

### Stockage local

- `self._codexUnlocked = {}` — table reçue par SyncCodex, mise à jour dans `UpdateCodex`.

### Exemple de structure (Init + UpdateCodex + Open/Close)

```lua
--[[
    CodexController.module.lua
    Gère l'affichage du Codex (sets débloqués / verrouillés)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local BrainrotData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("BrainrotData.module"))

local CodexController = {}
CodexController._codexUnlocked = {}
CodexController._codexUI = nil
CodexController._initialized = false

function CodexController:Init()
    if self._initialized then return end

    local gui = player:WaitForChild("PlayerGui")
    self._codexUI = gui:WaitForChild("CodexUI")
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local syncCodex = Remotes:WaitForChild("SyncCodex")
    syncCodex.OnClientEvent:Connect(function(codexUnlocked)
        self:UpdateCodex(codexUnlocked or {})
    end)

    -- Close button
    local closeBtn = self._codexUI:FindFirstChild("Background") and self._codexUI.Background:FindFirstChild("CloseButton")
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(function()
            self:Close()
        end)
    end

    self._initialized = true
    print("[CodexController] Initialized")
end

function CodexController:UpdateCodex(codexUnlocked)
    self._codexUnlocked = codexUnlocked or {}
    self:RefreshList()
end

function CodexController:Open()
    if self._codexUI then
        self._codexUI.Enabled = true
    end
end

function CodexController:Close()
    if self._codexUI then
        self._codexUI.Enabled = false
    end
end

function CodexController:IsOpen()
    return self._codexUI and self._codexUI.Enabled
end

function CodexController:RefreshList()
    -- À implémenter : parcourir BrainrotData.Sets, créer/mettre à jour les entrées
    -- Voir B6.5
end

return CodexController
```

---

## B6.3 - Connexion ClientMain + SyncCodex

### Description

- Dans **ClientMain.client.lua**, charger **CodexController** et appeler **CodexController:Init()** au démarrage.
- Remplacer le TODO Phase 6 existant : quand **SyncCodex** est reçu, appeler `CodexController:UpdateCodex(data)` au lieu de laisser le bloc vide.

### Modifications dans ClientMain.client.lua

1. Ajouter le require :  
   `local CodexController = require(script.Parent:WaitForChild("CodexController.module"))`

2. Après l’initialisation des autres contrôleurs, appeler :  
   `CodexController:Init()`

3. Dans le connecteur de **SyncCodex**, appeler :  
   `CodexController:UpdateCodex(data)`  
   (et supprimer le commentaire TODO Phase 6.)

---

## B6.4 - Bouton Codex dans le MainHUD (option 1)

### Description

Un **bouton** dans le MainHUD ouvre le Codex au clic : il appelle `CodexController:Open()`.

### Création du bouton Codex dans Studio (MainHUD)

1. Dans l’explorateur : **StarterGui** → **MainHUD** (ScreenGui). Si MainHUD n’existe pas, le créer (ScreenGui nommé `MainHUD`).
2. Ouvrir le **Frame** ou conteneur principal du HUD (souvent une Frame type "TopBar" ou "Background").
3. Clic droit sur ce conteneur → **Insert Object** → **TextButton**.
4. Renommer le bouton en **CodexButton** (ce nom est utilisé dans ClientMain).

Propriétés recommandées pour le bouton :

| Propriété          | Valeur | Note |
|--------------------|--------|------|
| **Name**           | `CodexButton` | Obligatoire pour FindFirstChild |
| **Size**           | `{0, 120}, {0, 36}` | 120×36 px (ajuster selon votre HUD) |
| **Position**       | À définir (ex. en haut à droite : AnchorPoint 1,0 et Position 1,0 avec offset) | À côté du Cash ou en barre supérieure |
| **AnchorPoint**    | `1, 0` si coin droit ; `0, 0` si gauche | |
| **BackgroundColor3**| Couleur secondaire (ex. 0.25, 0.4, 0.6) | Pour le distinguer du bouton Craft |
| **BackgroundTransparency** | `0` ou `0.2` | |
| **Text**           | `Codex` ou `📖 Codex` | |
| **TextColor3**     | Blanc (1, 1, 1) | |
| **TextSize**       | `16` ou `18` | |
| **Font**           | `Gotham` ou `GothamBold` | |

5. **UICorner** sur le bouton : CornerRadius `{0, 6}` pour coins arrondis.
6. Si le bouton est dans une Frame imbriquée (ex. MainHUD → Background → TopBar), le script ClientMain devra chercher dans la bonne hiérarchie (ex. `mainHUD:FindFirstChild("Background")` puis `:FindFirstChild("CodexButton")` ou équivalent).

### Connexion du clic (script)

- Dans **ClientMain.client.lua** : après l’init de CodexController, récupérer le bouton (par ex. `mainHUD:FindFirstChild("CodexButton")` ou en parcourant la hiérarchie si besoin) et connecter `MouseButton1Click` à `CodexController:Open()`.
- Alternative : exposer dans **UIController** une fonction qui retourne le bouton Codex (comme pour le bouton Craft), puis dans ClientMain connecter ce bouton à `CodexController:Open()`.

### Exemple (ClientMain.client.lua)

```lua
-- Après CodexController:Init()
local CodexController = require(script.Parent:WaitForChild("CodexController.module"))
CodexController:Init()

-- Bouton Codex dans MainHUD (le MainHUD est cloné dans PlayerGui au jeu)
local playerGui = player:WaitForChild("PlayerGui")
local mainHUD = playerGui:WaitForChild("MainHUD")
local codexButton = mainHUD:FindFirstChild("CodexButton") or mainHUD:FindFirstChild("Codex")
if codexButton and codexButton:IsA("TextButton") then
    codexButton.MouseButton1Click:Connect(function()
        CodexController:Open()
    end)
    print("[ClientMain] Codex button connected")
end
```

Si le MainHUD est à l’intérieur d’un Frame, adapter le chemin (ex. `mainHUD:FindFirstChild("Background"):FindFirstChild("CodexButton")` selon votre hiérarchie).

---

## B6.5 - Affichage des sets (débloqués / verrouillés)

### Description

Dans **CodexController:RefreshList()** :

1. Récupérer la liste des sets depuis **BrainrotData.Sets** (pairs ou ordre défini).
2. Pour chaque `setName, setData` :
   - Déterminer si débloqué : `self._codexUnlocked[setName] == true`.
   - Créer ou réutiliser une **Frame** (ou template) par set avec :
     - **SetName** : `setName` ou `setData` (ex. affichage lisible).
     - **Rarity** : `setData.Rarity` (Common, Rare, etc.) — peut être affiché en texte ou couleur (voir B6.6).
   - Si **verrouillé** : afficher "???" ou masquer le nom, et afficher une overlay (cadenas / grisé). Si **débloqué** : afficher le nom et la rareté.
3. Parent : le conteneur défini en B6.1 (ScrollFrame ou Frame avec Layout). Utiliser un **template** Clone() si vous avez créé un SetEntry template dans Studio, sinon créer les instances en Lua (Frame, TextLabels, etc.).

### Ordre d’affichage

- Suivre l’ordre des sets dans BrainrotData, ou trier par rareté (BrainrotData.Rarities[rarity].DisplayOrder) puis par nom.

### Données par set

- **BrainrotData.Sets[setName]** : `Rarity`, `Head`, `Body`, `Legs` (DisplayName, Price, etc.). Pour l’entrée Codex, le nom du set et la rareté suffisent pour un premier jet.

### Exemple RefreshList (CodexController) – avec UIGridLayout

Avec **UIGridLayout**, chaque entrée a une **Size** égale à la cellule (ex. `1, 0` en largeur et `0, 44` en hauteur) et un **LayoutOrder** pour l’ordre. Ne pas définir **Position** : le layout place les éléments.

```lua
function CodexController:RefreshList()
    local container = self._codexUI and self._codexUI:FindFirstChild("Background")
    if not container then return end
    local listContainer = container:FindFirstChild("ListContainer") or container:FindFirstChild("ScrollFrame")
    if not listContainer then return end

    -- Nettoyer les anciennes entrées (sauf template / UIGridLayout)
    for _, child in ipairs(listContainer:GetChildren()) do
        if child:IsA("Frame") and child.Name == "SetEntry" then
            child:Destroy()
        end
    end

    local Sets = BrainrotData.Sets or {}
    local Rarities = BrainrotData.Rarities or {}
    local unlocked = self._codexUnlocked or {}
    local entryHeight = 44   -- même hauteur que CellSize du UIGridLayout
    local layoutOrder = 0

    -- Ordre déterministe (ex. par nom de set) pour LayoutOrder
    local setNames = {}
    for setName in pairs(Sets) do
        table.insert(setNames, setName)
    end
    table.sort(setNames)

    for _, setName in ipairs(setNames) do
        local setData = Sets[setName]
        if not setData then continue end

        layoutOrder = layoutOrder + 1
        local isUnlocked = unlocked[setName] == true
        local rarity = setData.Rarity or "Common"
        local rarityInfo = Rarities[rarity] or {}
        local color = rarityInfo.Color or Color3.new(1, 1, 1)

        local entry = Instance.new("Frame")
        entry.Name = "SetEntry"
        -- Size = cellule du UIGridLayout (100 % largeur, hauteur 44)
        entry.Size = UDim2.new(1, 0, 0, entryHeight)
        entry.LayoutOrder = layoutOrder
        entry.BackgroundColor3 = isUnlocked and color or Color3.fromRGB(60, 60, 60)
        entry.BorderSizePixel = 0
        entry.Parent = listContainer

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.6, -10, 1, -4)
        nameLabel.Position = UDim2.new(0, 5, 0, 2)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = isUnlocked and setName or "???"
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.TextSize = 14
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = entry

        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size = UDim2.new(0.35, -10, 1, -4)
        rarityLabel.Position = UDim2.new(0.6, 5, 0, 2)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = isUnlocked and rarity or "?"
        rarityLabel.TextColor3 = isUnlocked and color or Color3.new(0.5, 0.5, 0.5)
        rarityLabel.TextSize = 12
        rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
        rarityLabel.Parent = entry
    end

    -- Mettre à jour le compteur X / Y
    local subtitle = container:FindFirstChild("Subtitle")
    if subtitle then
        local count = 0
        for _ in pairs(unlocked) do count = count + 1 end
        local total = 0
        for _ in pairs(Sets) do total = total + 1 end
        subtitle.Text = string.format("%d / %d sets unlocked", count, total)
    end

    -- Si ListContainer est un ScrollingFrame, mettre à jour CanvasSize
    if listContainer:IsA("ScrollingFrame") then
        local layout = listContainer:FindFirstChildOfClass("UIGridLayout")
        if layout then
            listContainer.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
        end
    end
end
```

**Résumé UIGridLayout :** pas de `Position` ni `yOffset` ; **Size** = taille de la cellule (ex. `UDim2.new(1, 0, 0, 44)`) ; **LayoutOrder** = ordre d’affichage (1, 2, 3…). Les sets sont triés par nom pour un ordre stable.

---

## B6.6 - Polish (animations, couleurs rareté)

### Description

- **Rareté** : utiliser **BrainrotData.Rarities[rarity].Color** pour la couleur du texte ou du fond de l’entrée (Common = blanc, Rare = bleu, Epic = violet, Legendary = or).
- **Ouverture / fermeture** : TweenService sur l’opacité ou la position du Background pour une ouverture/fermeture en douceur.
- **Compteur** : afficher "X / Y sets unlocked" dans le sous-titre du Codex (X = nombre de clés dans `_codexUnlocked`, Y = nombre de sets dans BrainrotData.Sets).

---

# SYNC 6 - Test Codex Complet

## Checklist de validation

- [ ] À la connexion, le client reçoit **SyncCodex** avec les sets déjà débloqués.
- [ ] Après un **craft** qui débloque un set, le client reçoit **SyncCodex** et l’UI se met à jour sans recharger.
- [ ] **Ouverture** du Codex (bouton Codex dans MainHUD) affiche le ScreenGui.
- [ ] **Fermeture** (bouton Fermer dans CodexUI) masque le Codex.
- [ ] Les sets **débloqués** affichent nom et rareté.
- [ ] Les sets **verrouillés** affichent un état "???" / cadenas / grisé.
- [ ] (Optionnel) Couleurs de rareté et compteur X/Y corrects.

---

# Récapitulatif des fichiers

| Rôle | Fichier | Action |
|------|---------|--------|
| DEV A | `ServerScriptService/Core/GameServer.server.lua` | Modifier (envoi SyncCodex à la connexion) |
| DEV A | `ServerScriptService/Core/DataService.module.lua` | Modifier (envoi SyncCodex après UnlockCodexEntry) |
| DEV A | `ServerScriptService/Systems/CodexService.module.lua` | Optionnel (créer) |
| DEV B | StarterGui **CodexUI** (ScreenGui + Background, titre, liste, CloseButton) | Créer (Studio) |
| DEV B | `StarterPlayer/StarterPlayerScripts/CodexController.module.lua` | Créer |
| DEV B | `StarterPlayer/StarterPlayerScripts/ClientMain.client.lua` | Modifier (CodexController, SyncCodex) |
| DEV B | MainHUD (CodexButton) | Modifier (ajouter bouton Codex + connexion clic) |

---

# Références rapides

- **Constants.RemoteNames.SyncCodex** : "SyncCodex" (RemoteEvent, serveur → client).
- **DataService:UnlockCodexEntry(player, setName)** : débloque et doit déclencher SyncCodex.
- **BrainrotData.Sets** : `[setName] = { Rarity, Head, Body, Legs }`.
- **BrainrotData.Rarities** : `[Rarity] = { Color, DisplayOrder, BonusMultiplier }`.
- **DefaultPlayerData.CodexUnlocked** : `{[setName] = true}`.

---

**Fin du Guide Phase 6**
