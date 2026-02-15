# PHASE 9 : SHOP ROBUX - Guide Complet

**Date:** 2026-02-15
**Status:** En cours
**Prérequis:** Phases 0 à 8 complétées

---

## Vue d'Ensemble

La Phase 9 ajoute un **Shop Robux** permettant aux joueurs d'acheter de l'argent in-game ($Cash) avec des Robux. Le design est extensible pour ajouter facilement de nouvelles sections (gamepasses, items spéciaux, etc.) plus tard.

### Fonctionnalités

1. **Shop avec onglets** :
   - Interface plein écran avec fond semi-transparent
   - Barre d'onglets en haut (pour l'instant : "ARGENT")
   - Facile d'ajouter de nouveaux onglets plus tard

2. **Section Argent** :
   - 4 packs d'argent avec prix Robux croissants
   - Cartes colorées avec badges ("POPULAIRE", "MEILLEURE OFFRE")
   - Clic sur "Acheter" ouvre la fenêtre de confirmation Roblox native

3. **Sécurité** :
   - Achat via Developer Products (système officiel Roblox)
   - Serveur valide TOUT via `ProcessReceipt`
   - Impossible de tricher l'achat

### Objectifs de la Phase 9

- Shop UI en code (pas de ScreenGui pré-créé dans Studio)
- Système extensible avec catégories et onglets dynamiques
- Intégration MarketplaceService pour les vrais achats Robux
- Bouton "SHOP" dans le HUD principal
- Feedback utilisateur (notifications de succès/erreur)

---

## Résumé des Tâches

### DEV A - Backend Shop

| #    | Tâche                            | Fichier                                         | Temps |
|------|----------------------------------|------------------------------------------------|-------|
| A9.1 | ShopProducts (configuration)     | ReplicatedStorage/Data/ShopProducts.module.lua | 15min |
| A9.2 | ShopSystem (serveur)             | Systems/ShopSystem.module.lua                  | 1h    |
| A9.3 | Constants (nouveau remote)       | Shared/Constants.module.lua                    | 5min  |
| A9.4 | NetworkHandler (nouveau handler) | Handlers/NetworkHandler.module.lua             | 15min |
| A9.5 | GameServer (init)                | Core/GameServer.server.lua                     | 10min |
| A9.6 | FeatureFlags                     | Config/FeatureFlags.module.lua                 | 2min  |

**Total DEV A :** ~2h

### DEV B - Client & UI

| #    | Tâche                            | Fichier                                               | Temps |
|------|----------------------------------|------------------------------------------------------|-------|
| B9.1 | ShopController (UI complète)     | StarterPlayerScripts/ShopController.module.lua       | 2h    |
| B9.2 | Intégration ClientMain           | StarterPlayerScripts/ClientMain.client.lua           | 10min |

**Total DEV B :** ~2h30

### Roblox Studio

| #    | Tâche                            | Où dans Studio                                       | Temps |
|------|----------------------------------|------------------------------------------------------|-------|
| S9.1 | Créer Developer Products         | Page du jeu sur roblox.com > Developer Products     | 15min |
| S9.2 | Mettre les vrais ProductId       | ShopProducts.module.lua                              | 5min  |

**Total Studio :** ~20min

**TOTAL PHASE 9 :** ~5h

---

# ARCHITECTURE

## Flux de données

### Achat Robux (Developer Product)

```
CLIENT                                 SERVER                          ROBLOX
  │                                      │                               │
  │──Clique "Acheter $5,000"─────────────│                               │
  │  Fire RequestShopPurchase            │                               │
  │  (categoryId="Money", productIdx=2)  │                               │
  │                                      │                               │
  │                                      │──Validate:                    │
  │                                      │  • Category existe?           │
  │                                      │  • Product existe?            │
  │                                      │  • ProductId valide?          │
  │                                      │                               │
  │                                      │──PromptProductPurchase────────►│
  │                                      │  (player, productId)          │
  │                                      │                               │
  │◄─────────────────────────────────────│◄──Fenêtre Robux native───────│
  │  Joueur voit: "Acheter pour R$199?"  │                               │
  │                                      │                               │
  │──[Joueur confirme]───────────────────│                               │
  │                                      │                               │
  │                                      │◄──ProcessReceipt──────────────│
  │                                      │   receiptInfo:                │
  │                                      │   • PlayerId                  │
  │                                      │   • ProductId                 │
  │                                      │   • PurchaseId                │
  │                                      │                               │
  │                                      │──Lookup ProductId             │
  │                                      │──EconomySystem:AddCash()     │
  │                                      │──Return PurchaseGranted──────►│
  │                                      │                               │
  │◄─SyncPlayerData (Cash)───────────────│                               │
  │◄─Notification "Succès!"──────────────│                               │
  │                                      │                               │
  │  [Cash mis à jour dans le HUD]       │                               │
```

### Ouverture du Shop

```
CLIENT
  │
  │──Clique bouton "SHOP" (dans MainHUD)
  │  ou ShopController:Open()
  │
  │──ShopController crée l'UI en code
  │  (ScreenGui > MainFrame > Header > TabBar > Content)
  │
  │──Affiche onglet "ARGENT" par défaut
  │  Génère les cartes produits depuis ShopProducts
  │
  │──Joueur clique sur un produit
  │  Fire RequestShopPurchase au serveur
  │
  │──Serveur appelle PromptProductPurchase
  │──Fenêtre Robux native apparaît
```

## Nouveaux RemoteEvents

À ajouter dans `Constants.module.lua > RemoteNames` :

| Nom                   | Type        | Direction       | Description                              |
|-----------------------|-------------|-----------------|------------------------------------------|
| RequestShopPurchase   | RemoteEvent | Client → Server | Demande d'achat (categoryId, productIdx) |

Un seul remote suffit ! Le reste utilise les remotes existants :
- `SyncPlayerData` pour sync le cash après achat
- `Notification` pour les feedbacks succès/erreur

---

# FICHIERS

## Nouveaux fichiers à créer

```
ReplicatedStorage/
└── Data/
    └── ShopProducts.module.lua          ✅ NOUVEAU (configuration produits)

ServerScriptService/
└── Systems/
    └── ShopSystem.module.lua            ✅ NOUVEAU (logique serveur)

StarterPlayer/
└── StarterPlayerScripts/
    └── ShopController.module.lua        ✅ NOUVEAU (UI client complète)
```

## Fichiers à modifier

```
ReplicatedStorage/
└── Shared/
    └── Constants.module.lua             📝 MODIFIER (1 remote ajouté)
└── Config/
    └── FeatureFlags.module.lua          📝 MODIFIER (1 flag ajouté)

ServerScriptService/
├── Core/
│   └── GameServer.server.lua            📝 MODIFIER (init ShopSystem)
└── Handlers/
    └── NetworkHandler.module.lua        📝 MODIFIER (1 handler ajouté)

StarterPlayer/
└── StarterPlayerScripts/
    └── ClientMain.client.lua            📝 MODIFIER (init ShopController + bouton)
```

---

# DEV A - BACKEND SHOP

## A9.1 - ShopProducts (Configuration des Produits)

### Description
Fichier de configuration qui définit tous les produits disponibles dans le shop, organisés par catégories (onglets). Facile à étendre pour ajouter de nouvelles catégories.

### Créer le fichier

**Roblox Studio :**
1. `ReplicatedStorage` → Dossier `Data`
2. Clic droit → Insert Object → **ModuleScript**
3. Renommer : **ShopProducts**

### Code complet

```lua
--[[
    ShopProducts.module.lua
    Configuration des produits du Shop Robux

    Organisé par catégories (onglets dans le shop).
    Chaque catégorie contient une liste de produits.

    IMPORTANT: Les ProductId doivent correspondre aux Developer Products
    créés sur la page du jeu (roblox.com > Create > Your Game > Developer Products)

    Pour ajouter une nouvelle catégorie:
    1. Ajouter une entrée dans Categories
    2. Le shop génère automatiquement l'onglet et les cartes
]]

local ShopProducts = {
    -- ═══════════════════════════════════════
    -- CATÉGORIES (chaque catégorie = un onglet)
    -- ═══════════════════════════════════════
    Categories = {
        -- ─────────────────────────────────
        -- ARGENT (Cash Packs)
        -- ─────────────────────────────────
        {
            Id = "Money",
            DisplayName = "ARGENT",
            Icon = "rbxassetid://0",  -- Icône de l'onglet (optionnel)
            Order = 1,                -- Ordre d'affichage (1 = premier)
            Products = {
                {
                    ProductId = 0,          -- ⚠️ REMPLACER par le vrai Developer Product ID
                    Cash = 1000,            -- Montant de cash donné
                    Robux = 49,             -- Prix en Robux (pour affichage)
                    DisplayName = "$1,000",
                    Description = "Un petit boost pour démarrer",
                    Color = Color3.fromRGB(76, 175, 80),   -- Vert
                    Badge = nil,            -- Pas de badge
                },
                {
                    ProductId = 0,          -- ⚠️ REMPLACER par le vrai Developer Product ID
                    Cash = 5000,
                    Robux = 199,
                    DisplayName = "$5,000",
                    Description = "Achetez plusieurs slots d'un coup",
                    Color = Color3.fromRGB(33, 150, 243),   -- Bleu
                    Badge = nil,
                },
                {
                    ProductId = 0,          -- ⚠️ REMPLACER par le vrai Developer Product ID
                    Cash = 25000,
                    Robux = 799,
                    DisplayName = "$25,000",
                    Description = "Débloquez un étage entier",
                    Color = Color3.fromRGB(156, 39, 176),   -- Violet
                    Badge = "POPULAIRE",
                },
                {
                    ProductId = 0,          -- ⚠️ REMPLACER par le vrai Developer Product ID
                    Cash = 100000,
                    Robux = 2499,
                    DisplayName = "$100,000",
                    Description = "Devenez le plus riche du serveur",
                    Color = Color3.fromRGB(255, 152, 0),    -- Orange
                    Badge = "MEILLEURE OFFRE",
                },
            },
        },

        -- ─────────────────────────────────
        -- EXEMPLES DE FUTURES CATÉGORIES
        -- (décommenter quand prêt)
        -- ─────────────────────────────────

        --[[
        {
            Id = "GamePasses",
            DisplayName = "PASSES DE JEU",
            Icon = "rbxassetid://0",
            Order = 2,
            Products = {
                -- GamePasses utilisent MarketplaceService:PromptGamePassPurchase
                -- au lieu de PromptProductPurchase
            },
        },
        ]]

        --[[
        {
            Id = "Special",
            DisplayName = "SPÉCIAL",
            Icon = "rbxassetid://0",
            Order = 3,
            Products = {},
        },
        ]]
    },
}

return ShopProducts
```

### Vérifications
- [ ] Le fichier se charge sans erreur
- [ ] `ShopProducts.Categories` contient au moins 1 catégorie
- [ ] Chaque produit a un `ProductId`, `Cash`, `Robux`, `DisplayName`, `Color`

---

## A9.2 - ShopSystem (Serveur)

### Description
Système serveur qui gère les achats Robux via MarketplaceService. Configure le callback `ProcessReceipt` pour valider et accorder les achats.

### Créer le fichier

**Roblox Studio :**
1. `ServerScriptService` → Dossier `Systems`
2. Clic droit → Insert Object → **ModuleScript**
3. Renommer : **ShopSystem**

### Code complet

```lua
--[[
    ShopSystem.module.lua
    Gestion des achats Robux via MarketplaceService

    Responsabilités:
    - Configurer ProcessReceipt (callback d'achat)
    - Valider les demandes d'achat client
    - Accorder les récompenses (cash) après achat confirmé
    - Mapping ProductId → récompense

    Flux:
    1. Client fire RequestShopPurchase(categoryId, productIndex)
    2. Serveur valide et appelle PromptProductPurchase
    3. Roblox affiche la fenêtre de confirmation
    4. Si confirmé, ProcessReceipt est appelé par Roblox
    5. Serveur donne le cash et retourne PurchaseGranted
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules (chargés dans Init)
local ShopProducts = nil
local EconomySystem = nil
local NetworkSetup = nil
local DataService = nil

-- Mapping: ProductId → { Cash = number, CategoryId = string, DisplayName = string }
local _productMap = {}

local ShopSystem = {}
ShopSystem._initialized = false

--[[
    Initialise le système de shop
    @param services: table - {EconomySystem, NetworkSetup, DataService}
]]
function ShopSystem:Init(services)
    if self._initialized then
        warn("[ShopSystem] Déjà initialisé!")
        return
    end

    print("[ShopSystem] Initialisation...")

    -- Récupérer les services injectés
    EconomySystem = services.EconomySystem
    NetworkSetup = services.NetworkSetup
    DataService = services.DataService

    if not EconomySystem then
        warn("[ShopSystem] EconomySystem requis! Le shop ne fonctionnera pas sans.")
        return
    end

    -- Charger la configuration des produits
    local Data = ReplicatedStorage:WaitForChild("Data")
    ShopProducts = require(Data:WaitForChild("ShopProducts.module"))

    -- Construire le mapping ProductId → récompense
    self:_BuildProductMap()

    -- Configurer le callback ProcessReceipt
    self:_SetupProcessReceipt()

    self._initialized = true
    print("[ShopSystem] Initialisé! " .. self:_CountProducts() .. " produits enregistrés.")
end

-- ═══════════════════════════════════════════════════════
-- DEMANDE D'ACHAT (appelé par NetworkHandler)
-- ═══════════════════════════════════════════════════════

--[[
    Traite une demande d'achat du client
    @param player: Player
    @param categoryId: string - ID de la catégorie (ex: "Money")
    @param productIndex: number - Index du produit dans la catégorie (1-based)
]]
function ShopSystem:RequestPurchase(player, categoryId, productIndex)
    print(string.format("[ShopSystem] Demande d'achat de %s: catégorie=%s, index=%s",
        player.Name, tostring(categoryId), tostring(productIndex)))

    -- Validation des paramètres
    if type(categoryId) ~= "string" or categoryId == "" then
        self:_SendNotification(player, "Error", "Catégorie invalide.")
        return
    end

    if type(productIndex) ~= "number" or productIndex < 1 then
        self:_SendNotification(player, "Error", "Produit invalide.")
        return
    end

    -- Trouver la catégorie
    local category = self:_FindCategory(categoryId)
    if not category then
        self:_SendNotification(player, "Error", "Catégorie introuvable.")
        return
    end

    -- Trouver le produit
    local product = category.Products[productIndex]
    if not product then
        self:_SendNotification(player, "Error", "Produit introuvable.")
        return
    end

    -- Vérifier que le ProductId est configuré
    if not product.ProductId or product.ProductId == 0 then
        warn("[ShopSystem] ProductId non configuré pour " .. product.DisplayName)
        self:_SendNotification(player, "Error", "Ce produit n'est pas encore disponible.")
        return
    end

    -- Déclencher la fenêtre d'achat Roblox native
    local success, err = pcall(function()
        MarketplaceService:PromptProductPurchase(player, product.ProductId)
    end)

    if not success then
        warn("[ShopSystem] Erreur PromptProductPurchase: " .. tostring(err))
        self:_SendNotification(player, "Error", "Erreur lors de l'achat. Réessayez.")
    else
        print(string.format("[ShopSystem] Fenêtre d'achat ouverte pour %s (produit: %s, R$%d)",
            player.Name, product.DisplayName, product.Robux))
    end
end

-- ═══════════════════════════════════════════════════════
-- PROCESS RECEIPT (callback Roblox)
-- ═══════════════════════════════════════════════════════

--[[
    Configure le callback ProcessReceipt de MarketplaceService.
    Ce callback est appelé par Roblox après qu'un joueur confirme un achat.

    IMPORTANT: Ce callback DOIT retourner Enum.ProductPurchaseDecision.PurchaseGranted
    pour que l'achat soit finalisé. Si on retourne NotProcessedYet, Roblox
    réessaiera plus tard (utile si le joueur n'est plus connecté).
]]
function ShopSystem:_SetupProcessReceipt()
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        print(string.format("[ShopSystem] ProcessReceipt: PlayerId=%d, ProductId=%d, PurchaseId=%s",
            receiptInfo.PlayerId, receiptInfo.ProductId, receiptInfo.PurchaseId))

        -- 1. Trouver le joueur
        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        if not player then
            -- Le joueur n'est plus connecté, Roblox réessaiera plus tard
            warn("[ShopSystem] Joueur " .. receiptInfo.PlayerId .. " non trouvé, réessai plus tard")
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        -- 2. Trouver le produit
        local productInfo = _productMap[receiptInfo.ProductId]
        if not productInfo then
            warn("[ShopSystem] ProductId inconnu: " .. receiptInfo.ProductId)
            -- On retourne PurchaseGranted quand même pour ne pas bloquer
            -- (le produit n'existe pas dans notre config, possible erreur de config)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end

        -- 3. Accorder la récompense
        local success, err = pcall(function()
            if productInfo.Cash and productInfo.Cash > 0 then
                EconomySystem:AddCash(player, productInfo.Cash)
                print(string.format("[ShopSystem] +$%d accordé à %s (produit: %s)",
                    productInfo.Cash, player.Name, productInfo.DisplayName))
            end
        end)

        if not success then
            warn("[ShopSystem] Erreur lors de l'accord de la récompense: " .. tostring(err))
            -- On retourne NotProcessedYet pour que Roblox réessaie
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        -- 4. Notification de succès
        self:_SendNotification(player, "Success",
            "Achat réussi ! +" .. productInfo.DisplayName .. " ajouté à votre compte !")

        -- 5. Confirmer l'achat à Roblox
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    print("[ShopSystem] ProcessReceipt configuré")
end

-- ═══════════════════════════════════════════════════════
-- UTILITAIRES INTERNES
-- ═══════════════════════════════════════════════════════

--[[
    Construit le mapping ProductId → récompense à partir de ShopProducts
]]
function ShopSystem:_BuildProductMap()
    _productMap = {}

    for _, category in ipairs(ShopProducts.Categories) do
        for _, product in ipairs(category.Products) do
            if product.ProductId and product.ProductId > 0 then
                _productMap[product.ProductId] = {
                    Cash = product.Cash,
                    Robux = product.Robux,
                    DisplayName = product.DisplayName,
                    CategoryId = category.Id,
                }
            end
        end
    end
end

--[[
    Trouve une catégorie par son ID
    @param categoryId: string
    @return table | nil
]]
function ShopSystem:_FindCategory(categoryId)
    for _, category in ipairs(ShopProducts.Categories) do
        if category.Id == categoryId then
            return category
        end
    end
    return nil
end

--[[
    Compte le nombre total de produits avec un ProductId valide
    @return number
]]
function ShopSystem:_CountProducts()
    local count = 0
    for _ in pairs(_productMap) do
        count = count + 1
    end
    return count
end

--[[
    Envoie une notification au client
    @param player: Player
    @param notifType: string - "Success" | "Error" | "Info" | "Warning"
    @param message: string
]]
function ShopSystem:_SendNotification(player, notifType, message)
    if not NetworkSetup then return end

    local remotes = NetworkSetup:GetAllRemotes()
    if remotes and remotes.Notification then
        remotes.Notification:FireClient(player, {
            Type = notifType,
            Message = message,
            Duration = 4,
        })
    end
end

return ShopSystem
```

### Vérifications
- [ ] Le module se charge sans erreur
- [ ] `ShopSystem:Init()` s'exécute sans crash
- [ ] `ProcessReceipt` est configuré (vérifier dans Output)
- [ ] Log affiché: `[ShopSystem] Initialisé! X produits enregistrés.`

---

## A9.3 - Constants (Nouveau Remote)

### Ouvrir le fichier

**Roblox Studio :**
1. `ReplicatedStorage` → `Shared` → `Constants`
2. Double-cliquer pour ouvrir

### Modification

Ajouter dans la section `RemoteNames`, dans les remotes **Client → Serveur** :

```lua
    RemoteNames = {
        -- Client → Serveur
        PickupPiece = "PickupPiece",
        DropPieces = "DropPieces",
        Craft = "Craft",
        BuySlot = "BuySlot",
        CollectSlotCash = "CollectSlotCash",
        ActivateDoor = "ActivateDoor",
        StealBrainrot = "StealBrainrot",
        PlaceStolenBrainrot = "PlaceStolenBrainrot",
        BatHit = "BatHit",
        RequestShopPurchase = "RequestShopPurchase",   -- Phase 9: Achat shop Robux

        -- Serveur → Client (existants, pas de changement)
        -- ...
    },
```

**Un seul remote à ajouter :** `RequestShopPurchase = "RequestShopPurchase",`

### Vérification
- [ ] Pas d'erreur de syntaxe (virgule avant la ligne suivante)
- [ ] Le remote apparaît dans `ReplicatedStorage/Remotes` après le démarrage

---

## A9.4 - NetworkHandler (Nouveau Handler)

### Ouvrir le fichier

**Roblox Studio :**
1. `ServerScriptService` → `Handlers` → `NetworkHandler`
2. Double-cliquer pour ouvrir

### Modifications

#### 1. Ajouter la variable du système (en haut)

Après les autres déclarations de systèmes (Phase 8) :

```lua
-- Systèmes (Phase 8)
local StealSystem = nil
local BatSystem = nil

-- Systèmes (Phase 9)
local ShopSystem = nil
```

#### 2. Ajouter dans Init()

Dans `NetworkHandler:Init(services)`, après les récupérations Phase 8 :

```lua
    -- Récupérer les systèmes (Phase 8)
    StealSystem = services.StealSystem
    BatSystem = services.BatSystem

    -- Récupérer les systèmes (Phase 9)
    ShopSystem = services.ShopSystem
```

#### 3. Ajouter le handler dans _ConnectHandlers()

Après le handler `BatHit`, ajouter :

```lua
    -- Achat Shop Robux (Phase 9)
    if remotes.RequestShopPurchase then
        remotes.RequestShopPurchase.OnServerEvent:Connect(function(player, categoryId, productIndex)
            -- Convertir productIndex en nombre si nécessaire
            if type(productIndex) == "string" then
                productIndex = tonumber(productIndex)
            end

            local success, err = pcall(function()
                if ShopSystem then
                    ShopSystem:RequestPurchase(player, categoryId, productIndex)
                else
                    warn("[NetworkHandler] ShopSystem non initialisé!")
                end
            end)

            if not success then
                warn("[NetworkHandler] Erreur RequestShopPurchase: " .. tostring(err))
            end
        end)
    end
```

#### 4. Ajouter dans UpdateSystems()

Dans la fonction `NetworkHandler:UpdateSystems(systems)`, ajouter :

```lua
    if systems.ShopSystem then
        ShopSystem = systems.ShopSystem
    end
```

### Vérification
- [ ] Pas d'erreur de syntaxe
- [ ] Log `[NetworkHandler] Handlers connectés` toujours visible
- [ ] Le handler `RequestShopPurchase` est connecté

---

## A9.5 - GameServer (Initialisation)

### Ouvrir le fichier

**Roblox Studio :**
1. `ServerScriptService` → `Core` → `GameServer`
2. Double-cliquer pour ouvrir

### Modifications

#### 1. Ajouter le require (après les autres systèmes Phase 8)

Après les blocs `pcall` de StealSystem et BatSystem :

```lua
-- Phase 9: Shop Robux
local ShopSystem, shopLoadErr
do
    local ok, mod = pcall(function()
        return require(Systems["ShopSystem.module"])
    end)
    if ok then
        ShopSystem = mod
    else
        shopLoadErr = mod
    end
end
```

#### 2. Ajouter l'initialisation (après le bloc Phase 8)

Après le bloc `if StealSystem and BatSystem then ... end` :

```lua
-- 13. ShopSystem (Phase 9)
if ShopSystem and EconomySystem then
    ShopSystem:Init({
        EconomySystem = EconomySystem,
        NetworkSetup = NetworkSetup,
        DataService = DataService,
    })
    -- print("[GameServer] ShopSystem: OK")

    NetworkHandler:UpdateSystems({ShopSystem = ShopSystem})
else
    if not ShopSystem then
        warn("[GameServer] ShopSystem non chargé:", shopLoadErr or "inconnu")
    end
    if not EconomySystem then
        warn("[GameServer] ShopSystem nécessite EconomySystem!")
    end
end
```

### Vérification
- [ ] Le serveur démarre sans erreur
- [ ] Log `[ShopSystem] Initialisé!` visible dans Output
- [ ] Pas de crash au chargement

---

## A9.6 - FeatureFlags

### Ouvrir le fichier

**Roblox Studio :**
1. `ReplicatedStorage` → `Config` → `FeatureFlags`
2. Double-cliquer pour ouvrir

### Modification

Ajouter dans la section `FEATURES ACTIVES` :

```lua
    -- ═══════════════════════════════════════
    -- FEATURES ACTIVES
    -- ═══════════════════════════════════════
    DOOR_SYSTEM = true,
    CODEX_SYSTEM = true,
    REVENUE_SYSTEM = true,
    DEATH_ON_SPINNER = true,
    ROBUX_SHOP = true,               -- Phase 9: Shop Robux
```

---

# DEV B - CLIENT & UI

## B9.1 - ShopController (UI Complète)

### Description
Contrôleur client qui crée TOUTE l'UI du shop en code Lua (pas de ScreenGui pré-créé dans Studio). Le shop est un panneau plein écran avec des onglets et des cartes produits.

### Créer le fichier

**Roblox Studio :**
1. `StarterPlayer` → `StarterPlayerScripts`
2. Clic droit → Insert Object → **ModuleScript**
3. Renommer : **ShopController**

### Style visuel

Le shop reproduit un style inspiré du screenshot de référence :
- **Fond** : Overlay sombre semi-transparent sur tout l'écran
- **Panneau principal** : Frame centré (~600x500 px), coins arrondis, fond sombre
- **Header** : Titre "BOUTIQUE" en gros + bouton X rouge
- **Onglets** : Barre horizontale avec boutons cliquables ("ARGENT", etc.)
- **Contenu** : ScrollingFrame avec cartes produits
- **Cartes produits** : Fond coloré, nom du pack, montant, badge optionnel, bouton d'achat vert avec prix Robux
- **Animations** : Ouverture/fermeture avec TweenService

### Code complet

```lua
--[[
    ShopController.module.lua
    Gère l'UI complète du Shop Robux côté client

    L'UI est créée entièrement en code (pas de ScreenGui pré-existant).
    Le shop est extensible : les onglets et produits sont générés
    dynamiquement depuis ShopProducts.module.lua.

    Méthodes publiques:
    - ShopController:Init()   → Crée l'UI et connecte les events
    - ShopController:Open()   → Ouvre le shop avec animation
    - ShopController:Close()  → Ferme le shop avec animation
    - ShopController:Toggle() → Ouvre ou ferme
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local Data = ReplicatedStorage:WaitForChild("Data")
local ShopProducts = require(Data:WaitForChild("ShopProducts.module"))

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- État
local isOpen = false
local currentTab = nil

-- Références UI (créées dans Init)
local screenGui = nil
local mainFrame = nil
local overlay = nil
local contentScroll = nil
local tabButtons = {}

-- ═══════════════════════════════════════════════════════
-- CONSTANTES VISUELLES
-- ═══════════════════════════════════════════════════════

local COLORS = {
    Overlay = Color3.fromRGB(0, 0, 0),
    OverlayTransparency = 0.4,
    PanelBg = Color3.fromRGB(30, 30, 40),
    HeaderBg = Color3.fromRGB(20, 20, 30),
    TabActive = Color3.fromRGB(50, 50, 70),
    TabInactive = Color3.fromRGB(35, 35, 50),
    TabText = Color3.fromRGB(255, 255, 255),
    CloseBtn = Color3.fromRGB(200, 50, 50),
    CloseBtnHover = Color3.fromRGB(230, 70, 70),
    BuyBtn = Color3.fromRGB(30, 120, 30),
    BuyBtnHover = Color3.fromRGB(40, 150, 40),
    White = Color3.fromRGB(255, 255, 255),
    LightGray = Color3.fromRGB(200, 200, 200),
    Gold = Color3.fromRGB(255, 215, 0),
    BadgeBg = Color3.fromRGB(255, 60, 60),
    RobuxIcon = Color3.fromRGB(255, 255, 255),
}

local SIZES = {
    Panel = UDim2.new(0, 620, 0, 520),
    PanelClosed = UDim2.new(0, 0, 0, 0),
    Header = UDim2.new(1, 0, 0, 50),
    TabBar = UDim2.new(1, 0, 0, 40),
    CardHeight = 100,
    CardSpacing = 10,
    CornerRadius = UDim.new(0, 12),
    SmallCorner = UDim.new(0, 8),
    TinyCorner = UDim.new(0, 6),
}

local ShopController = {}

-- ═══════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════

--[[
    Crée toute l'UI du shop et connecte les events
]]
function ShopController:Init()
    -- Créer le ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RobuxShopUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 10
    screenGui.Enabled = false
    screenGui.Parent = playerGui

    -- Overlay (fond semi-transparent)
    overlay = Instance.new("TextButton")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = COLORS.Overlay
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = screenGui

    -- Clic sur l'overlay ferme le shop
    overlay.MouseButton1Click:Connect(function()
        self:Close()
    end)

    -- Panneau principal
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = SIZES.PanelClosed
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = COLORS.PanelBg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = overlay

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = SIZES.CornerRadius
    mainCorner.Parent = mainFrame

    -- Ombre subtile (UIStroke)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 80)
    stroke.Thickness = 2
    stroke.Parent = mainFrame

    -- Header
    self:_CreateHeader()

    -- TabBar (onglets)
    self:_CreateTabBar()

    -- Zone de contenu (ScrollingFrame)
    self:_CreateContentArea()

    -- Sélectionner le premier onglet par défaut
    if #ShopProducts.Categories > 0 then
        -- Trier par Order
        local sorted = {}
        for _, cat in ipairs(ShopProducts.Categories) do
            table.insert(sorted, cat)
        end
        table.sort(sorted, function(a, b) return (a.Order or 99) < (b.Order or 99) end)
        self:SwitchTab(sorted[1].Id)
    end

    print("[ShopController] Initialisé!")
end

-- ═══════════════════════════════════════════════════════
-- CRÉATION DES ÉLÉMENTS UI
-- ═══════════════════════════════════════════════════════

--[[
    Crée le header (titre + bouton fermer)
]]
function ShopController:_CreateHeader()
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = SIZES.Header
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = COLORS.HeaderBg
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    -- Titre
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "BOUTIQUE"
    title.TextColor3 = COLORS.White
    title.TextSize = 28
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Bouton fermer (X)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -45, 0, 5)
    closeBtn.BackgroundColor3 = COLORS.CloseBtn
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = COLORS.White
    closeBtn.TextSize = 22
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = SIZES.SmallCorner
    closeBtnCorner.Parent = closeBtn

    -- Hover effect
    closeBtn.MouseEnter:Connect(function()
        closeBtn.BackgroundColor3 = COLORS.CloseBtnHover
    end)
    closeBtn.MouseLeave:Connect(function()
        closeBtn.BackgroundColor3 = COLORS.CloseBtn
    end)

    closeBtn.MouseButton1Click:Connect(function()
        self:Close()
    end)
end

--[[
    Crée la barre d'onglets
]]
function ShopController:_CreateTabBar()
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = SIZES.TabBar
    tabBar.Position = UDim2.new(0, 0, 0, 50)
    tabBar.BackgroundColor3 = COLORS.HeaderBg
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    -- Layout horizontal pour les onglets
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Padding = UDim.new(0, 2)
    layout.Parent = tabBar

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.Parent = tabBar

    -- Trier les catégories par Order
    local sorted = {}
    for _, cat in ipairs(ShopProducts.Categories) do
        table.insert(sorted, cat)
    end
    table.sort(sorted, function(a, b) return (a.Order or 99) < (b.Order or 99) end)

    -- Créer un bouton pour chaque catégorie
    tabButtons = {}
    for _, category in ipairs(sorted) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "Tab_" .. category.Id
        tabBtn.Size = UDim2.new(0, 140, 1, -4)
        tabBtn.BackgroundColor3 = COLORS.TabInactive
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = category.DisplayName
        tabBtn.TextColor3 = COLORS.TabText
        tabBtn.TextSize = 16
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.Parent = tabBar

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 8)
        tabCorner.Parent = tabBtn

        tabBtn.MouseButton1Click:Connect(function()
            self:SwitchTab(category.Id)
        end)

        tabButtons[category.Id] = tabBtn
    end
end

--[[
    Crée la zone de contenu scrollable
]]
function ShopController:_CreateContentArea()
    contentScroll = Instance.new("ScrollingFrame")
    contentScroll.Name = "ContentScroll"
    contentScroll.Size = UDim2.new(1, -20, 1, -100)
    contentScroll.Position = UDim2.new(0, 10, 0, 95)
    contentScroll.BackgroundTransparency = 1
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 6
    contentScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentScroll.Parent = mainFrame

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Name = "Layout"
    contentLayout.FillDirection = Enum.FillDirection.Vertical
    contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    contentLayout.Padding = UDim.new(0, SIZES.CardSpacing)
    contentLayout.Parent = contentScroll

    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingTop = UDim.new(0, 5)
    contentPadding.PaddingBottom = UDim.new(0, 10)
    contentPadding.Parent = contentScroll
end

-- ═══════════════════════════════════════════════════════
-- ONGLETS ET CONTENU
-- ═══════════════════════════════════════════════════════

--[[
    Change l'onglet actif et regénère le contenu
    @param categoryId: string - ID de la catégorie
]]
function ShopController:SwitchTab(categoryId)
    currentTab = categoryId

    -- Mettre à jour l'apparence des onglets
    for id, btn in pairs(tabButtons) do
        if id == categoryId then
            btn.BackgroundColor3 = COLORS.TabActive
            -- Indicateur actif (trait en bas)
        else
            btn.BackgroundColor3 = COLORS.TabInactive
        end
    end

    -- Trouver la catégorie
    local category = nil
    for _, cat in ipairs(ShopProducts.Categories) do
        if cat.Id == categoryId then
            category = cat
            break
        end
    end

    if not category then
        warn("[ShopController] Catégorie introuvable: " .. categoryId)
        return
    end

    -- Regénérer les cartes produits
    self:_BuildProductCards(category)
end

--[[
    Génère les cartes produits pour une catégorie
    @param category: table - La catégorie depuis ShopProducts
]]
function ShopController:_BuildProductCards(category)
    -- Vider le contenu actuel
    for _, child in ipairs(contentScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- Créer une carte pour chaque produit
    for index, product in ipairs(category.Products) do
        self:_CreateProductCard(category.Id, index, product)
    end
end

--[[
    Crée une carte produit individuelle
    @param categoryId: string
    @param productIndex: number
    @param product: table - Données du produit
]]
function ShopController:_CreateProductCard(categoryId, productIndex, product)
    -- Carte principale
    local card = Instance.new("Frame")
    card.Name = "Product_" .. productIndex
    card.Size = UDim2.new(1, -10, 0, SIZES.CardHeight)
    card.BackgroundColor3 = product.Color or COLORS.TabInactive
    card.BorderSizePixel = 0
    card.Parent = contentScroll

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = SIZES.SmallCorner
    cardCorner.Parent = card

    -- Gradient subtil sur la carte
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
    })
    gradient.Rotation = 90
    gradient.Parent = card

    -- Badge (optionnel : "POPULAIRE", "MEILLEURE OFFRE")
    if product.Badge then
        local badge = Instance.new("TextLabel")
        badge.Name = "Badge"
        badge.Size = UDim2.new(0, 140, 0, 22)
        badge.Position = UDim2.new(1, -145, 0, -2)
        badge.BackgroundColor3 = COLORS.BadgeBg
        badge.BorderSizePixel = 0
        badge.Text = product.Badge
        badge.TextColor3 = COLORS.White
        badge.TextSize = 12
        badge.Font = Enum.Font.GothamBold
        badge.Parent = card

        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = SIZES.TinyCorner
        badgeCorner.Parent = badge
    end

    -- Nom du produit (gros texte)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ProductName"
    nameLabel.Size = UDim2.new(0.5, -10, 0, 35)
    nameLabel.Position = UDim2.new(0, 15, 0, 15)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = product.DisplayName
    nameLabel.TextColor3 = COLORS.White
    nameLabel.TextSize = 26
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextStrokeTransparency = 0.7
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = card

    -- Description
    if product.Description then
        local descLabel = Instance.new("TextLabel")
        descLabel.Name = "Description"
        descLabel.Size = UDim2.new(0.5, -10, 0, 20)
        descLabel.Position = UDim2.new(0, 15, 0, 50)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = product.Description
        descLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
        descLabel.TextSize = 13
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextTransparency = 0.2
        descLabel.Parent = card
    end

    -- Bouton d'achat (à droite)
    local buyBtn = Instance.new("TextButton")
    buyBtn.Name = "BuyButton"
    buyBtn.Size = UDim2.new(0, 160, 0, 50)
    buyBtn.Position = UDim2.new(1, -175, 0.5, -25)
    buyBtn.BackgroundColor3 = COLORS.BuyBtn
    buyBtn.BorderSizePixel = 0
    buyBtn.Text = ""
    buyBtn.AutoButtonColor = false
    buyBtn.Parent = card

    local buyCorner = Instance.new("UICorner")
    buyCorner.CornerRadius = SIZES.SmallCorner
    buyCorner.Parent = buyBtn

    -- Icône Robux (texte R$) dans le bouton
    local robuxLabel = Instance.new("TextLabel")
    robuxLabel.Name = "RobuxPrice"
    robuxLabel.Size = UDim2.new(1, 0, 1, 0)
    robuxLabel.BackgroundTransparency = 1
    robuxLabel.Text = "R$ " .. self:_FormatNumber(product.Robux)
    robuxLabel.TextColor3 = COLORS.White
    robuxLabel.TextSize = 22
    robuxLabel.Font = Enum.Font.GothamBold
    robuxLabel.Parent = buyBtn

    -- Hover effect sur le bouton
    buyBtn.MouseEnter:Connect(function()
        TweenService:Create(buyBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.BuyBtnHover
        }):Play()
    end)
    buyBtn.MouseLeave:Connect(function()
        TweenService:Create(buyBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = COLORS.BuyBtn
        }):Play()
    end)

    -- Clic d'achat
    buyBtn.MouseButton1Click:Connect(function()
        self:_OnBuyClicked(categoryId, productIndex, product)
    end)
end

-- ═══════════════════════════════════════════════════════
-- ACTIONS
-- ═══════════════════════════════════════════════════════

--[[
    Appelé quand le joueur clique sur un bouton d'achat
    @param categoryId: string
    @param productIndex: number
    @param product: table
]]
function ShopController:_OnBuyClicked(categoryId, productIndex, product)
    print(string.format("[ShopController] Achat cliqué: %s #%d (%s, R$%d)",
        categoryId, productIndex, product.DisplayName, product.Robux))

    -- Envoyer la demande au serveur
    local requestRemote = Remotes:FindFirstChild("RequestShopPurchase")
    if requestRemote then
        requestRemote:FireServer(categoryId, productIndex)
    else
        warn("[ShopController] Remote RequestShopPurchase introuvable!")
    end
end

-- ═══════════════════════════════════════════════════════
-- OUVERTURE / FERMETURE
-- ═══════════════════════════════════════════════════════

--[[
    Ouvre le shop avec animation
]]
function ShopController:Open()
    if isOpen then return end
    if not screenGui then return end

    isOpen = true
    screenGui.Enabled = true

    -- Animer l'overlay (apparition)
    overlay.BackgroundTransparency = 1
    TweenService:Create(overlay, TweenInfo.new(0.25), {
        BackgroundTransparency = COLORS.OverlayTransparency
    }):Play()

    -- Animer le panneau (zoom depuis le centre)
    mainFrame.Size = SIZES.PanelClosed

    local tweenOpen = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = SIZES.Panel,
    })
    tweenOpen:Play()

    print("[ShopController] Shop ouvert")
end

--[[
    Ferme le shop avec animation
]]
function ShopController:Close()
    if not isOpen then return end
    if not screenGui then return end

    -- Animer l'overlay (disparition)
    TweenService:Create(overlay, TweenInfo.new(0.2), {
        BackgroundTransparency = 1
    }):Play()

    -- Animer le panneau (zoom vers le centre)
    local tweenClose = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = SIZES.PanelClosed,
    })
    tweenClose:Play()

    tweenClose.Completed:Connect(function()
        screenGui.Enabled = false
        isOpen = false
    end)

    print("[ShopController] Shop fermé")
end

--[[
    Toggle le shop (ouvre si fermé, ferme si ouvert)
]]
function ShopController:Toggle()
    if isOpen then
        self:Close()
    else
        self:Open()
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
function ShopController:_FormatNumber(number)
    local formatted = tostring(math.floor(number))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

return ShopController
```

### Vérifications
- [ ] Le module se charge sans erreur
- [ ] `ShopController:Init()` crée l'UI dans PlayerGui
- [ ] `ShopController:Open()` affiche le shop avec animation
- [ ] `ShopController:Close()` ferme le shop avec animation
- [ ] Les onglets fonctionnent
- [ ] Les cartes produits s'affichent correctement
- [ ] Le clic sur "Acheter" envoie le remote au serveur

---

## B9.2 - Intégration ClientMain

### Ouvrir le fichier

**Roblox Studio :**
1. `StarterPlayer` → `StarterPlayerScripts` → `ClientMain`
2. Double-cliquer pour ouvrir

### Modifications

#### 1. Ajouter le require (après les autres contrôleurs)

Après la ligne `local PreviewBrainrotController = require(...)` :

```lua
local ShopController = require(script.Parent:WaitForChild("ShopController.module"))
```

#### 2. Initialiser le contrôleur (après les autres Init)

Après `ArenaController:Init()` :

```lua
-- Initialiser ShopController (Phase 9)
ShopController:Init()
```

#### 3. Ajouter le bouton SHOP dans le MainHUD

Après la section du bouton Codex, ajouter :

```lua
-- ═══════════════════════════════════════════════════════
-- BOUTON SHOP (Phase 9) – Bouton pour ouvrir le Shop Robux
-- ═══════════════════════════════════════════════════════

if mainHUD then
    -- Créer le bouton SHOP en code (à côté du bouton Codex)
    local shopButton = Instance.new("TextButton")
    shopButton.Name = "ShopButton"
    shopButton.Size = UDim2.new(0, 90, 0, 35)
    shopButton.Position = UDim2.new(1, -200, 0, 10)
    shopButton.AnchorPoint = Vector2.new(0, 0)
    shopButton.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
    shopButton.BorderSizePixel = 0
    shopButton.Text = "SHOP"
    shopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    shopButton.TextSize = 18
    shopButton.Font = Enum.Font.GothamBold
    shopButton.Parent = mainHUD

    local shopBtnCorner = Instance.new("UICorner")
    shopBtnCorner.CornerRadius = UDim.new(0, 8)
    shopBtnCorner.Parent = shopButton

    shopButton.MouseButton1Click:Connect(function()
        ShopController:Toggle()
    end)

    -- Hover effect
    shopButton.MouseEnter:Connect(function()
        shopButton.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    end)
    shopButton.MouseLeave:Connect(function()
        shopButton.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
    end)

    -- print("[ClientMain] Shop button créé")
end
```

> **Note sur la position :** `Position = UDim2.new(1, -200, 0, 10)` place le bouton en haut à droite, à 200px du bord droit. Ajustez cette position selon votre HUD existant. Si vous avez déjà un bouton Codex à cet endroit, décalez l'un des deux.

### Vérification
- [ ] Le bouton "SHOP" apparaît dans le MainHUD
- [ ] Cliquer le bouton ouvre le shop
- [ ] Cliquer à nouveau (ou sur X ou sur l'overlay) ferme le shop
- [ ] Pas de conflit avec le bouton Codex

---

# ROBLOX STUDIO - CONFIGURATION

## S9.1 - Créer les Developer Products

### Description
Les Developer Products sont les produits achetables avec des Robux. Ils doivent être créés sur la page du jeu sur roblox.com.

### Étapes

1. Aller sur **roblox.com** > **Create** > Sélectionner votre jeu
2. Cliquer sur **Monetization** dans le menu de gauche
3. Cliquer sur **Developer Products**
4. Cliquer **Create a Developer Product**
5. Créer 4 produits :

| Nom du produit | Prix (Robux) | Description |
|---------------|-------------|-------------|
| Cash Pack $1,000 | 49 | 1,000 in-game cash |
| Cash Pack $5,000 | 199 | 5,000 in-game cash |
| Cash Pack $25,000 | 799 | 25,000 in-game cash |
| Cash Pack $100,000 | 2,499 | 100,000 in-game cash |

6. **Noter les Product IDs** générés par Roblox (nombre dans l'URL après la création)

### Important
- Les prix Robux sont définis sur le site Roblox, PAS dans le code
- Le code affiche les prix depuis `ShopProducts` mais le vrai prix est celui de Roblox
- Les deux doivent correspondre !

---

## S9.2 - Mettre les vrais ProductId

### Étapes

1. Ouvrir `ReplicatedStorage/Data/ShopProducts`
2. Remplacer les `ProductId = 0` par les vrais IDs :

```lua
Products = {
    {
        ProductId = 123456789,  -- ← Votre vrai ID pour Cash Pack $1,000
        Cash = 1000,
        Robux = 49,
        -- ...
    },
    {
        ProductId = 123456790,  -- ← Votre vrai ID pour Cash Pack $5,000
        Cash = 5000,
        Robux = 199,
        -- ...
    },
    -- etc.
},
```

### Important
- Tant que `ProductId = 0`, le bouton d'achat affichera une erreur "Ce produit n'est pas encore disponible"
- C'est normal en développement ! Les achats ne fonctionnent qu'avec de vrais IDs
- En Studio (Play Solo), les achats ne fonctionneront pas car MarketplaceService n'est pas disponible. Il faut tester sur un serveur Roblox réel

---

# TESTS & VALIDATION

## Test 1 : Ouverture du Shop

### Étapes
1. Lancer Play Solo dans Studio
2. Vérifier que le bouton "SHOP" apparaît en haut à droite du HUD
3. Cliquer sur "SHOP"

### Résultats attendus
- Le shop s'ouvre avec une animation de zoom
- Le fond s'assombrit (overlay)
- L'onglet "ARGENT" est sélectionné par défaut
- 4 cartes produits visibles avec les bons prix

### Vérifications Output
```
[ShopController] Initialisé!
[ShopController] Shop ouvert
```

---

## Test 2 : Fermeture du Shop

### Étapes (3 méthodes)
1. Cliquer sur le bouton "X" rouge
2. Cliquer sur l'overlay (fond sombre)
3. Cliquer à nouveau sur le bouton "SHOP"

### Résultats attendus
- Le shop se ferme avec une animation de zoom inverse
- L'overlay disparaît

---

## Test 3 : Achat (avec ProductId = 0)

### Étapes
1. Ouvrir le shop
2. Cliquer sur un bouton "R$ 49"

### Résultats attendus
- Le serveur reçoit la demande
- Notification d'erreur : "Ce produit n'est pas encore disponible."
- (Normal ! Les ProductId sont à 0)

### Vérifications Output
```
[ShopController] Achat cliqué: Money #1 ($1,000, R$49)
[ShopSystem] Demande d'achat de Player: catégorie=Money, index=1
[ShopSystem] ProductId non configuré pour $1,000
```

---

## Test 4 : Achat réel (après S9.1 et S9.2)

### Prérequis
- Developer Products créés sur roblox.com
- Vrais ProductIds dans ShopProducts
- Jeu publié et lancé sur un serveur réel (pas Studio)

### Étapes
1. Ouvrir le shop
2. Cliquer sur un bouton d'achat
3. La fenêtre Roblox native apparaît : "Acheter pour R$X ?"
4. Confirmer l'achat

### Résultats attendus
- Cash du joueur augmente du montant acheté
- Notification : "Achat réussi ! +$X ajouté à votre compte !"
- Le HUD met à jour le cash automatiquement

### Vérifications Output
```
[ShopSystem] Fenêtre d'achat ouverte pour Player (produit: $5,000, R$199)
[ShopSystem] ProcessReceipt: PlayerId=123, ProductId=456, PurchaseId=abc
[ShopSystem] +$5000 accordé à Player (produit: $5,000)
[EconomySystem] Player +$5000 (total: $X)
```

---

## Test 5 : Onglets (futur)

### Description
Quand vous ajouterez une nouvelle catégorie dans `ShopProducts.Categories`, le shop devra automatiquement créer un nouvel onglet.

### Étapes (pour tester)
1. Décommenter la catégorie "GamePasses" dans ShopProducts
2. Relancer le jeu
3. Vérifier qu'un 2ème onglet "PASSES DE JEU" apparaît

---

# PROBLÈMES COURANTS

## Le bouton SHOP n'apparaît pas

**Cause :** Le MainHUD n'existe pas ou n'est pas trouvé.

**Solution :**
1. Vérifier que `StarterGui` contient un ScreenGui nommé `MainHUD`
2. Vérifier que `playerGui:WaitForChild("MainHUD", 10)` réussit dans ClientMain
3. Vérifier l'Output pour des erreurs de chargement

---

## Le shop s'ouvre mais est vide

**Cause :** ShopProducts n'est pas chargé correctement.

**Solution :**
1. Vérifier que `ReplicatedStorage/Data/ShopProducts` existe en tant que ModuleScript
2. Vérifier qu'il n'y a pas d'erreur de syntaxe dans ShopProducts
3. Vérifier que `ShopProducts.Categories` n'est pas vide

---

## "Ce produit n'est pas encore disponible"

**Cause :** Les `ProductId` sont à 0 (valeur placeholder).

**Solution :**
1. Créer les Developer Products sur roblox.com (voir S9.1)
2. Mettre les vrais IDs dans ShopProducts (voir S9.2)
3. C'est NORMAL en développement tant que les produits ne sont pas créés

---

## Erreur "ProcessReceipt" déjà défini

**Cause :** Un autre script définit déjà `MarketplaceService.ProcessReceipt`.

**Solution :**
1. Vérifier qu'aucun autre script ne définit `ProcessReceipt`
2. Si oui, fusionner les deux callbacks dans ShopSystem
3. Il ne peut y avoir qu'UN SEUL callback `ProcessReceipt` par serveur !

---

## L'achat ne donne pas le cash

**Cause :** ProcessReceipt n'est pas appelé ou retourne une erreur.

**Solution :**
1. Vérifier les logs serveur pour `[ShopSystem] ProcessReceipt:`
2. Si le log n'apparaît pas, le callback n'est pas configuré
3. Vérifier que ShopSystem est bien initialisé AVANT qu'un joueur achète
4. Vérifier que EconomySystem est injecté correctement

---

# CHECKLIST FINALE

## Backend (DEV A)

- [ ] ShopProducts créé avec 4 produits (A9.1)
- [ ] ShopSystem créé et fonctionnel (A9.2)
- [ ] ProcessReceipt configuré
- [ ] Constants modifié (1 remote ajouté) (A9.3)
- [ ] NetworkHandler modifié (1 handler ajouté) (A9.4)
- [ ] GameServer modifié (init ShopSystem) (A9.5)
- [ ] FeatureFlags modifié (ROBUX_SHOP) (A9.6)

## Client (DEV B)

- [ ] ShopController créé (UI complète en code) (B9.1)
- [ ] ClientMain modifié (init + bouton SHOP) (B9.2)
- [ ] Le shop s'ouvre et se ferme avec animation
- [ ] Les onglets fonctionnent
- [ ] Les cartes produits s'affichent
- [ ] Le clic d'achat envoie le remote

## Roblox Studio

- [ ] Developer Products créés sur roblox.com (S9.1)
- [ ] Vrais ProductIds dans ShopProducts (S9.2)

## Tests

- [ ] Test 1 : Ouverture du shop
- [ ] Test 2 : Fermeture du shop (3 méthodes)
- [ ] Test 3 : Achat avec ProductId = 0 (erreur attendue)
- [ ] Test 4 : Achat réel (serveur Roblox)
- [ ] Test 5 : Ajout d'onglet (extensibilité)

---

# POUR AJOUTER UNE NOUVELLE SECTION PLUS TARD

Le système est conçu pour être extensible. Voici comment ajouter une nouvelle section :

### 1. Ajouter la catégorie dans ShopProducts

```lua
{
    Id = "Boosts",
    DisplayName = "BOOSTS",
    Icon = "rbxassetid://0",
    Order = 2,  -- Après "ARGENT"
    Products = {
        {
            ProductId = 999999,  -- Vrai ID
            Cash = 0,            -- Pas de cash pour un boost
            Robux = 99,
            DisplayName = "2x Revenue",
            Description = "Double vos revenus pendant 1 heure",
            Color = Color3.fromRGB(255, 200, 0),
            Badge = "NOUVEAU",
        },
    },
},
```

### 2. Adapter ShopSystem si nécessaire

Si la nouvelle catégorie donne autre chose que du Cash (boost, gamepass, etc.), modifier `ProcessReceipt` pour gérer le nouveau type de récompense :

```lua
-- Dans ProcessReceipt
if productInfo.CategoryId == "Money" then
    EconomySystem:AddCash(player, productInfo.Cash)
elseif productInfo.CategoryId == "Boosts" then
    -- Accorder le boost
    BoostSystem:ActivateBoost(player, productInfo.BoostType, productInfo.Duration)
end
```

### 3. C'est tout !

Le ShopController génère automatiquement le nouvel onglet et les cartes.

---

# RÉCAPITULATIF DES FICHIERS

| Fichier | Emplacement | Action |
|---------|-------------|--------|
| `ShopProducts.module.lua` | `ReplicatedStorage/Data/` | CRÉER |
| `ShopSystem.module.lua` | `ServerScriptService/Systems/` | CRÉER |
| `ShopController.module.lua` | `StarterPlayerScripts/` | CRÉER |
| `Constants.module.lua` | `ReplicatedStorage/Shared/` | MODIFIER (+1 remote) |
| `FeatureFlags.module.lua` | `ReplicatedStorage/Config/` | MODIFIER (+1 flag) |
| `NetworkHandler.module.lua` | `ServerScriptService/Handlers/` | MODIFIER (+1 handler) |
| `GameServer.server.lua` | `ServerScriptService/Core/` | MODIFIER (+init) |
| `ClientMain.client.lua` | `StarterPlayerScripts/` | MODIFIER (+init +bouton) |

---

**Fin du Guide Phase 9**
