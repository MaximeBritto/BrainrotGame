# Lucky Block — Spécification & Plan d'Action

## Vue d'ensemble

Les Lucky Blocks sont achetés avec des **Robux** (Developer Products Roblox).
Après achat, le joueur accumule des crédits Lucky Block dans ses données persistantes.
Ouvrir un Lucky Block roule un Brainrot aléatoire (Head + Body + Legs indépendants)
et le place directement dans un slot libre de sa base.

---

## Gameplay Flow

```
[Monde] workspace.Shops.LuckyBlockBase
    └── ProximityPrompt (E, instantané) → ouvre l'UI Lucky Block

[UI] LuckyBlock Panel
    ├── Compteur : "Tu possèdes : N Lucky Blocks"
    ├── [Acheter 1  — R$XX]   → PromptProductPurchase (ProductId_1)
    ├── [Acheter 3  — R$XX]   → PromptProductPurchase (ProductId_3)  (discount)
    └── [Ouvrir un Lucky Block]
            grisé si : 0 Lucky Blocks  OU  aucun slot libre

[Animation] Slot Machine (3 colonnes, client-side, décoratif)
    HEAD : défile rapidement → ralentit → résultat
    BODY : idem, s'arrête 0.5s après HEAD
    LEGS : idem, s'arrête 0.5s après BODY
    → Affiche : "Brainrot placé dans ta base !"

[Résultat] Brainrot assemblé et placé côté serveur (avant animation)
```

---

## Règles de validation (serveur)

| Action        | Condition bloquante                                          |
|---------------|--------------------------------------------------------------|
| Ouvrir        | `LuckyBlocks == 0`                                           |
| Ouvrir        | Aucun slot libre (`PlacementSystem:FindAvailableSlot == nil`)|
| Ouvrir        | Joueur stunné ou transporte un Brainrot volé                 |
| Achat Robux   | ProductId non configuré (sécurité)                          |

---

## Architecture réseau

### Nouveaux RemoteEvents à ajouter dans `Constants.module.lua > RemoteNames`

**Client → Serveur**

| Remote           | Paramètres          | Rôle                                          |
|------------------|---------------------|-----------------------------------------------|
| `BuyLuckyBlock`  | `amount: number`    | Déclenche PromptProductPurchase (1 ou 3)      |
| `OpenLuckyBlock` | *(aucun)*           | Ouvre 1 Lucky Block, roule et place           |

**Serveur → Client**

| Remote              | Paramètres                              | Rôle                                  |
|---------------------|-----------------------------------------|---------------------------------------|
| `SyncLuckyBlockData`| `{ Count: number }`                     | Met à jour le compteur dans l'UI      |
| `LuckyBlockReveal`  | `{ HeadSet, BodySet, LegsSet, SlotIndex }` | Lance l'animation slot machine     |

---

## Flux d'achat Robux

```
Client: BuyLuckyBlock(1 ou 3)
    ↓
Server: LuckyBlockSystem:RequestBuy(player, amount)
    → appelle MarketplaceService:PromptProductPurchase(player, productId)

Roblox: fenêtre d'achat native s'affiche

Joueur confirme
    ↓
ShopSystem.ProcessReceipt (déjà en place)
    → détecte productInfo.LuckyBlocks > 0
    → appelle LuckyBlockSystem:AddLuckyBlocks(player, amount)
    → LuckyBlockSystem sauvegarde dans DataService et fire SyncLuckyBlockData
```

> **Important** : `MarketplaceService.ProcessReceipt` ne peut être défini qu'une seule fois.
> Il est déjà géré par `ShopSystem`. On étend ce callback existant pour gérer les
> produits Lucky Block (ajout d'un champ `LuckyBlocks` dans `ShopProducts`).

---

## Flux d'ouverture

```
Client: OpenLuckyBlock()
    ↓
Server: LuckyBlockSystem:TryOpen(player)
    1. Valide LuckyBlocks > 0
    2. Valide slot libre disponible
    3. Roule Head / Body / Legs (pondéré par SpawnWeight de BrainrotData)
    4. Décrément LuckyBlocks count dans DataService
    5. Appelle PlacementSystem:PlaceBrainrot() + BrainrotModelSystem:CreateBrainrotModel()
    6. Fire LuckyBlockReveal → client (pour animation)
    7. Fire SyncPlacedBrainrots → tous les clients (mise à jour des bases)
    8. Fire SyncLuckyBlockData → client (compteur mis à jour)
    9. Fire SyncPlayerData → client
```

---

## Logique de roll

```lua
-- Roll indépendant pour Head, Body, Legs
-- Utilise les SpawnWeight existants de BrainrotData.Sets
-- Ex : brrbrr (weight=10), skibidi (weight=5), sigma (weight=2)
-- Résultat possible : Head=brrbrr, Body=sigma, Legs=skibidi (brainrot mixte, valide)
_RollPart(partType) → setName
_RollBrainrot()     → { HeadSet, BodySet, LegsSet }
```

Les poids sont ceux déjà utilisés par `ArenaSystem` pour le spawn des pièces.

---

## Structure des données

### Données persistantes (DataStore via DataService)

Ajout dans `DefaultPlayerData.module.lua` :
```lua
LuckyBlocks = 0,  -- nombre de Lucky Blocks disponibles
```

### Configuration produits

Nouvelle catégorie dans `ShopProducts.module.lua` :
```lua
{
    Id = "LuckyBlocks",
    DisplayName = "LUCKY BLOCKS",
    Icon = "rbxassetid://0",
    Order = 2,
    Products = {
        {
            ProductId = 0,        -- À renseigner après création sur Roblox
            LuckyBlocks = 1,
            Robux = 49,
            DisplayName = "1 Lucky Block",
        },
        {
            ProductId = 0,        -- À renseigner après création sur Roblox
            LuckyBlocks = 3,
            Robux = 99,           -- ~33% discount vs x3
            DisplayName = "3 Lucky Blocks",
        },
    },
},
```

### Configuration LuckyBlock

Nouveau fichier `ReplicatedStorage/Config/LuckyBlockConfig.module.lua` (ou dans GameConfig) :
```lua
{
    ProductId_1  = 0,   -- Developer Product ID pour 1 Lucky Block
    ProductId_3  = 0,   -- Developer Product ID pour 3 Lucky Blocks
}
```

---

## Fichiers à créer

| Fichier | Rôle |
|---------|------|
| `ServerScriptService/Systems/LuckyBlockSystem.module.lua` | Logique serveur : achat, ouverture, roll |
| `StarterPlayer/StarterPlayerScripts/Controllers/LuckyBlockController.client.lua` | ProximityPrompt + UI + animation slot machine |

---

## Fichiers à modifier

| Fichier | Modification |
|---------|-------------|
| `ReplicatedStorage/Shared/Constants.module.lua` | +4 RemoteNames : `BuyLuckyBlock`, `OpenLuckyBlock`, `SyncLuckyBlockData`, `LuckyBlockReveal` |
| `ReplicatedStorage/Data/DefaultPlayerData.module.lua` | `LuckyBlocks = 0` |
| `ReplicatedStorage/Data/ShopProducts.module.lua` | Nouvelle catégorie `LuckyBlocks` avec champ `LuckyBlocks` (pas `Cash`) |
| `ServerScriptService/Systems/ShopSystem.module.lua` | Injection de `LuckyBlockSystem`, gestion du champ `LuckyBlocks` dans `ProcessReceipt` |
| `ServerScriptService/Handlers/NetworkHandler.module.lua` | Router `BuyLuckyBlock` et `OpenLuckyBlock` → LuckyBlockSystem |
| `ServerScriptService/Core/GameServer.server.lua` | `LuckyBlockSystem:Init(services)` + injection dans ShopSystem |

---

## UI : LuckyBlockController

Créée entièrement en code (pattern ShopController existant) :

```
ScreenGui "LuckyBlockUI" (invisible par défaut)
└── MainFrame (centré, ~400x350)
    ├── Header
    │   ├── Title : "🎰 LUCKY BLOCK"
    │   └── CloseButton [X]
    ├── CountDisplay : "Tu possèdes : N Lucky Block(s)"
    ├── BuySection
    │   ├── BuyOneButton   "Acheter 1  — R$49"
    │   └── BuyThreeButton "Acheter 3  — R$99"
    ├── Divider
    └── OpenButton "Ouvrir un Lucky Block !"
        (couleur grisée + non-cliquable si Count=0 ou pas de slot)
```

**Slot Machine Frame** (remplace le contenu du MainFrame pendant l'animation) :
```
SlotMachineFrame
├── ColHead  : TextLabel défilant  → se stabilise sur HeadSet
├── ColBody  : TextLabel défilant  → se stabilise sur BodySet (+0.5s)
└── ColLegs  : TextLabel défilant  → se stabilise sur LegsSet (+1.0s)
ResultLabel : "Brainrot placé en Slot N !"  (apparaît après les 3 colonnes)
```

**Séquence animation (client) :**
1. Reçoit `LuckyBlockReveal { HeadSet, BodySet, LegsSet, SlotIndex }`
2. Lance `task.spawn` avec coroutine pour chaque colonne
3. `TweenService` réduit la fréquence de défilement (lerp interval 0.05s → 0.3s sur 2s)
4. Affiche `ResultLabel` après 3.5s
5. Ferme la SlotMachineFrame après 5s, retourne à l'UI principale

---

## ProximityPrompt sur LuckyBlockBase

`LuckyBlockController` scanne `workspace.Shops.LuckyBlockBase` au démarrage :

```lua
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText    = "Lucky Block"
prompt.HoldDuration  = 0
prompt.MaxActivationDistance = 8
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.Parent = workspace.Shops.LuckyBlockBase.PrimaryPart  -- ou BasePart principale
```

---

## Dépendances LuckyBlockSystem

```
LuckyBlockSystem
    ├── PlayerService      (GetData, runtime data)
    ├── DataService        (SetValue pour LuckyBlocks)
    ├── PlacementSystem    (FindAvailableSlot, PlaceBrainrot)
    ├── BrainrotModelSystem (CreateBrainrotModel)
    ├── NetworkSetup       (GetAllRemotes pour fire)
    └── lit : BrainrotData (SpawnWeights pour roll)
```

---

## Plan d'action (ordre d'implémentation)

### Étape 1 — Données & Config
- [ ] `DefaultPlayerData.module.lua` : ajouter `LuckyBlocks = 0`
- [ ] `ShopProducts.module.lua` : ajouter catégorie `LuckyBlocks` (ProductIds à 0 pour l'instant)
- [ ] `Constants.module.lua` : ajouter les 4 nouveaux RemoteNames

### Étape 2 — LuckyBlockSystem (serveur)
- [ ] Créer `LuckyBlockSystem.module.lua`
  - `Init(services)`
  - `AddLuckyBlocks(player, amount)` → DataService + SyncLuckyBlockData
  - `RequestBuy(player, amount)` → PromptProductPurchase
  - `TryOpen(player)` → validation + roll + placement + fires
  - `_RollBrainrot()` → Head/Body/Legs pondérés
  - `_GetWeightedRandom(partType)` → utilise BrainrotData.SpawnWeight

### Étape 3 — Intégration ShopSystem
- [ ] `ShopSystem.module.lua` : injecter `LuckyBlockSystem` dans Init
- [ ] `ShopSystem.ProcessReceipt` : gérer `productInfo.LuckyBlocks > 0`
- [ ] `ShopSystem._BuildProductMap` : inclure produits avec champ `LuckyBlocks`

### Étape 4 — Réseau
- [ ] `NetworkHandler.module.lua` : router `BuyLuckyBlock` et `OpenLuckyBlock`
- [ ] `GameServer.server.lua` : init LuckyBlockSystem + injection dans ShopSystem

### Étape 5 — Client : LuckyBlockController
- [ ] Créer `LuckyBlockController.client.lua`
  - ProximityPrompt sur `workspace.Shops.LuckyBlockBase`
  - Créer l'UI en code (MainFrame + boutons)
  - Écouter `SyncLuckyBlockData` → mettre à jour compteur et état du bouton Ouvrir
  - Écouter `LuckyBlockReveal` → lancer animation slot machine
  - Boutons Buy → fire `BuyLuckyBlock(amount)`
  - Bouton Open → fire `OpenLuckyBlock()`

### Étape 6 — Tests
- [ ] Tester achat Robux en Studio (mode Studio ignore MarketplaceService → tester via mock ou en vrai)
- [ ] Tester ouverture avec slot libre → Brainrot placé
- [ ] Tester ouverture sans slot → refus avec notification
- [ ] Tester ouverture avec 0 Lucky Block → bouton grisé
- [ ] Vérifier persistance du count entre sessions
- [ ] Vérifier animation slot machine (timing des 3 colonnes)

---

## Notes importantes

- **ProcessReceipt** ne peut être assigné qu'**une seule fois** dans tout le jeu.
  Il est déjà géré par ShopSystem — on l'étend, on ne le remplace pas.
- Les **ProductIds** doivent être créés sur le dashboard Roblox (Developer Products)
  avant d'être fonctionnels. En Studio, le `pcall` autour de `PromptProductPurchase`
  retournera une erreur silencieuse → tester en live ou avec le mock Studio.
- Le roll est **déterminé serveur-side avant l'animation**. L'animation est purement cosmétique.
  Le Brainrot est déjà placé quand le client joue le slot machine.
- `LuckyBlocks` est une **donnée persistante** (DataStore), pas runtime.
  Le joueur conserve ses crédits entre sessions.
