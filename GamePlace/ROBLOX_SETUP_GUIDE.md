# Guide de Setup Roblox Studio - Phase 0

Ce guide explique comment importer les fichiers Lua dans Roblox Studio et créer les éléments visuels.

## Convention de nommage des fichiers

- `.module.lua` → **ModuleScript** (code partagé/réutilisable)
- `.client.lua` → **LocalScript** (code client uniquement)
- `.server.lua` → **Script** (code serveur uniquement)

---

## Étape 1 : Créer la structure de base dans Roblox Studio

### 1.1 Structure dans ReplicatedStorage

Dans **ReplicatedStorage**, créer cette hiérarchie de **Folders** :

```
ReplicatedStorage/
├── Config/
│   ├── GameConfig (ModuleScript)
│   └── FeatureFlags (ModuleScript)
├── Data/
│   ├── BrainrotData (ModuleScript)
│   ├── SlotPrices (ModuleScript)
│   └── DefaultPlayerData (ModuleScript)
├── Shared/
│   ├── Constants (ModuleScript)
│   └── Utils (ModuleScript)
├── Assets/
│   └── Pieces/ (pour les modèles 3D plus tard)
└── Remotes/ (créé automatiquement par le code)
```

### 1.2 Structure dans ServerScriptService

```
ServerScriptService/
├── Core/
│   ├── NetworkSetup (ModuleScript)
│   ├── GameServer (Script) - à créer Phase 1
│   ├── DataService (ModuleScript) - à créer Phase 1
│   └── PlayerService (ModuleScript) - à créer Phase 1
├── Systems/ (vide pour l'instant)
└── Handlers/ (vide pour l'instant)
```

### 1.3 Structure dans Workspace

```
Workspace/
├── Bases/ (Folder)
│   └── Base_1/ (Model) - voir ci-dessous
├── Arena/ (Folder) - voir ci-dessous
├── ActivePieces/ (Folder vide)
└── SpawnLocation (Part)
```

---

## Étape 2 : Importer les scripts

Pour chaque fichier `.lua` du dossier `GamePlace/` :

1. Créer le type de script approprié dans Roblox Studio :
   - `.module.lua` → **ModuleScript**
   - `.client.lua` → **LocalScript**
   - `.server.lua` → **Script**
2. Copier le contenu du fichier `.lua`
3. Coller dans le script

### Fichiers à importer :

| Fichier local | Type | Emplacement Roblox Studio |
|--------------|------|---------------------------|
| `ReplicatedStorage/Config/GameConfig.module.lua` | ModuleScript | ReplicatedStorage > Config > GameConfig |
| `ReplicatedStorage/Config/FeatureFlags.module.lua` | ModuleScript | ReplicatedStorage > Config > FeatureFlags |
| `ReplicatedStorage/Data/BrainrotData.module.lua` | ModuleScript | ReplicatedStorage > Data > BrainrotData |
| `ReplicatedStorage/Data/SlotPrices.module.lua` | ModuleScript | ReplicatedStorage > Data > SlotPrices |
| `ReplicatedStorage/Data/DefaultPlayerData.module.lua` | ModuleScript | ReplicatedStorage > Data > DefaultPlayerData |
| `ReplicatedStorage/Shared/Constants.module.lua` | ModuleScript | ReplicatedStorage > Shared > Constants |
| `ReplicatedStorage/Shared/Utils.module.lua` | ModuleScript | ReplicatedStorage > Shared > Utils |
| `ServerScriptService/Core/NetworkSetup.module.lua` | ModuleScript | ServerScriptService > Core > NetworkSetup |

**Convention des noms dans le code :** Les fichiers `*.module.lua` correspondent à des ModuleScript dont le nom d’instance est `NomDuModule.module` (ex. `Constants.module`, `GameConfig.module`, `SlotPrices.module`). Dans les scripts, utiliser par exemple `Shared:WaitForChild("Constants.module")` et non `"Constants"` pour éviter un « Infinite yield possible ».

---

## Étape 3 : Créer la Base Template

### 3.1 Créer le Model Base_1

1. Créer un **Model** nommé `Base_1` dans `Workspace/Bases/`
2. Ajouter un **Attribut** au Model :
   - Nom: `OwnerUserId`
   - Type: `Number`
   - Valeur: `0`
3. Ajouter un autre **Attribut** :
   - Nom: `BaseIndex`
   - Type: `Number`
   - Valeur: `1`

### 3.2 Éléments de la Base

Créer ces éléments **à l'intérieur** de `Base_1` :

#### SpawnPoint
- Type: **Part**
- Nom: `SpawnPoint`
- Propriétés:
  - Anchored: ✓
  - CanCollide: ✗
  - Transparency: 1
  - Size: (4, 1, 4)
- Position: au centre de la base

#### Slots (Folder + Models)
- Créer un **Folder** nommé `Slots`
- À l'intérieur, créer 30 **Models** nommés `Slot_1`, `Slot_2`, ... `Slot_30`
- Structure de chaque Slot :
  ```
  Slot_X/ (Model)
  ├── Platform (Part)       ← Où le Brainrot est placé
  └── CollectPad (Part)     ← Dalle devant pour collecter
  ```

- `Platform` (Part) : Emplacement du Brainrot
  - Anchored: ✓
  - CanCollide: ✗
  - Size: (4, 0.5, 4)
  
  **Visibilité** :
  - **Slots 1-10** : `Transparency = 1` (invisible, juste une position de référence)
  - **Slots 11-20** : `Transparency = 1` (invisible, comme Floor_1)
  - **Slots 21-30** : `Transparency = 1` (invisible, comme Floor_2)
  
  Les Platforms sont toujours invisibles - ce sont juste des points de référence pour placer les Brainrots.

- `CollectPad` (Part) : Dalle de collecte devant le slot
  - Anchored: ✓
  - CanCollide: ✗ (pour que le joueur puisse marcher dessus)
  - Size: (4, 0.2, 4)
  - BrickColor: Bright green
  - Material: Neon
  - Position: juste devant Platform
  
  **IMPORTANT - Visibilité selon l'étage** :
  - **Slots 1-10** (Floor_0) : `Transparency = 0.5` (visible)
  - **Slots 11-20** (Floor_1) : `Transparency = 1` (invisible, comme Floor_1)
  - **Slots 21-30** (Floor_2) : `Transparency = 1` (invisible, comme Floor_2)
  
  Le code rendra les CollectPads visibles quand le Floor correspondant sera débloqué.

- **Attributs sur le Model Slot_X** :
  - `SlotIndex`: Number (1, 2, 3...)
  - `IsOccupied`: Boolean (false)
  - `StoredCash`: Number (0) ← Argent accumulé pour CE slot

- **Disposition** :
  - Slots 1-10 : Sur Floor_0 (toujours visible)
  - Slots 11-20 : Sur Floor_1 (invisible au départ)
  - Slots 21-30 : Sur Floor_2 (invisible au départ)
  
- La collecte se fait via l'événement `Touched` sur CollectPad

#### Door (Model)
- Créer un **Model** nommé `Door`
- Structure :
  ```
  Door/ (Model)
  ├── Bars/ (Model)         ← Conteneur des barreaux
  │   ├── Bar_1 (Part)
  │   ├── Bar_2 (Part)
  │   ├── Bar_3 (Part)
  │   └── ... (autant que tu veux)
  └── ActivationPad (Part)
  ```

- `Bars` (Model) : Conteneur des barreaux
  - Attribut `IsActive`: Boolean (false)  ← Sur le MODEL Bars, pas les Parts
  
- Chaque `Bar_X` (Part) : Un barreau individuel
  - Anchored: ✓
  - CanCollide: ✓
  - Size: (1, 10, 1) - fin et vertical
  - BrickColor: Really red ou Dark stone grey
  - Espacement : ~1.5 studs entre chaque barreau

- `ActivationPad` (Part) : Dalle au sol pour activer
  - Anchored: ✓
  - Size: (6, 0.5, 6)
  - BrickColor: Bright blue
  - Material: Neon
  - ProximityPrompt à l'intérieur :
    - ActionText: "Fermer la porte"
    - HoldDuration: 0
    - MaxActivationDistance: 8

#### CashCollector
- **SUPPRIMÉ** - Chaque slot a maintenant sa propre dalle de collecte (CollectPad)
- L'argent est collecté slot par slot en marchant sur les dalles vertes

#### SlotShop (Model)
- Créer un **Model** nommé `SlotShop` dans `Base_1`
- Position : près de l'entrée de la base, visible et accessible
- Structure :
  ```
  SlotShop/ (Model)
  ├── Sign (Part)              ← Panneau avec le texte
  │   └── SurfaceGui           ← "ACHETER SLOT"
  │   └── ProximityPrompt      ← Bouton E (directement sur le panneau)
  └── Display (Part)           ← Écran qui affiche le prix
      └── SurfaceGui           ← "$100" (prix dynamique)
  ```

##### Sign (Panneau principal)
| Propriété | Valeur |
|-----------|--------|
| **Name** | `Sign` |
| **Size** | (6, 3, 0.5) - panneau plat vertical |
| **Anchored** | ✓ |
| **CanCollide** | ✓ |
| **BrickColor** | Bright yellow |
| **Material** | SmoothPlastic |

- Position : à hauteur des yeux du joueur

###### SurfaceGui (sur Sign)
- Clic droit sur `Sign` → Insert Object → **SurfaceGui**

| Propriété | Valeur |
|-----------|--------|
| **Face** | Front |
| **SizingMode** | PixelsPerStud |
| **PixelsPerStud** | 50 |

- Dans SurfaceGui, ajouter un **TextLabel** :

| Propriété | Valeur |
|-----------|--------|
| **Name** | `TitleLabel` |
| **Size** | UDim2.new(1, 0, 1, 0) |
| **Position** | UDim2.new(0, 0, 0, 0) |
| **BackgroundTransparency** | 1 |
| **Text** | `ACHETER SLOT` |
| **TextColor3** | (0, 0, 0) noir |
| **TextScaled** | ✓ |
| **Font** | GothamBold |

###### ProximityPrompt (sur Sign)
- Clic droit sur `Sign` → Insert Object → **ProximityPrompt**

| Propriété | Valeur |
|-----------|--------|
| **ActionText** | `Acheter` |
| **ObjectText** | `Slot - $100` (mis à jour par code) |
| **HoldDuration** | `0` (achat instantané) |
| **MaxActivationDistance** | `10` |
| **KeyboardKeyCode** | `E` |
| **RequiresLineOfSight** | ✓ |
| **UIOffset** | (0, 0) |

##### Display (Écran de prix)
| Propriété | Valeur |
|-----------|--------|
| **Name** | `Display` |
| **Size** | (4, 2, 0.3) - écran plus petit |
| **Anchored** | ✓ |
| **CanCollide** | ✓ |
| **BrickColor** | Really black |
| **Material** | Neon |

- Position : juste sous le Sign

###### SurfaceGui (sur Display)
- Clic droit sur `Display` → Insert Object → **SurfaceGui**

| Propriété | Valeur |
|-----------|--------|
| **Face** | Front |
| **SizingMode** | PixelsPerStud |
| **PixelsPerStud** | 50 |

- Dans SurfaceGui, ajouter un **TextLabel** :

| Propriété | Valeur |
|-----------|--------|
| **Name** | `PriceLabel` |
| **Size** | UDim2.new(1, 0, 1, 0) |
| **BackgroundTransparency** | 1 |
| **Text** | `$100` |
| **TextColor3** | (0, 255, 0) vert |
| **TextScaled** | ✓ |
| **Font** | GothamBold |

- Le texte sera mis à jour par le code selon le prix du prochain slot

##### Visuel final du SlotShop
```
    ┌─────────────────┐
    │  ACHETER SLOT   │  ← Sign (panneau jaune)
    │    [E] Acheter  │  ← ProximityPrompt apparaît quand proche
    └─────────────────┘
    ┌─────────────────┐
    │     $100        │  ← Display (écran noir avec texte vert)
    └─────────────────┘
         ↑
       Joueur (appuie E pour acheter)
```

##### Comment ça fonctionne en jeu :
1. Le joueur s'approche du SlotShop (à moins de 10 studs)
2. Le ProximityPrompt apparaît : "Acheter - Slot - $100"
3. Il voit aussi le prix sur le Display
4. Il appuie **E**
5. Le serveur vérifie :
   - A-t-il assez d'argent ?
   - A-t-il déjà tous les slots (max 30) ?
6. Si OK : l'argent est débité, OwnedSlots augmente
7. Le Display et le ProximityPrompt se mettent à jour avec le nouveau prix

#### Floors (Folder)
- Créer un **Folder** nommé `Floors`
- À l'intérieur :
  - `Floor_0` (Model) : Rez-de-chaussée (toujours visible)
  - `Floor_1` (Model) : 1er étage (Transparency = 1 au départ)
  - `Floor_2` (Model) : 2ème étage (Transparency = 1 au départ)

---

## Étape 4 : Créer l'Arène

### 4.1 Structure Arena

Dans `Workspace`, créer un **Folder** nommé `Arena`.

---

### 4.2 SpawnZone (Zone de spawn des pièces)

La SpawnZone définit **où les pièces apparaissent** dans l'arène. C'est une zone invisible où le code va faire spawner les pièces aléatoirement.

#### Créer SpawnZone
- Dans `Workspace/Arena/`, créer une **Part**
- Renommer en `SpawnZone`

#### Propriétés de SpawnZone

| Propriété | Valeur | Explication |
|-----------|--------|-------------|
| **Name** | `SpawnZone` | Nom exact requis par le code |
| **Size** | (100, 1, 100) | Grande zone plate (100x100 studs) |
| **Anchored** | ✓ | Ne doit pas bouger |
| **CanCollide** | ✗ | Les pièces doivent pouvoir tomber à travers |
| **Transparency** | 1 | Invisible (zone de spawn, pas visuelle) |
| **BrickColor** | N'importe | Pas visible de toute façon |
| **Material** | SmoothPlastic | Par défaut |

#### Position et orientation

- **Position** : Au centre de l'arène, au niveau du sol
- **CFrame** : Rotation par défaut (0, 0, 0)
- **Exemple** : Si l'arène est à Y = 0, mettre SpawnZone à Y = 0.5 (juste au-dessus du sol)

#### Comment ça fonctionne en jeu

Le code va :
1. Prendre la **Position** et **Size** de SpawnZone
2. Générer une position aléatoire **dans cette zone** :
   ```lua
   -- Pseudo-code
   local randomX = math.random(-SpawnZone.Size.X/2, SpawnZone.Size.X/2)
   local randomZ = math.random(-SpawnZone.Size.Z/2, SpawnZone.Size.Z/2)
   local spawnPos = SpawnZone.Position + Vector3.new(randomX, 10, randomZ)
   -- Le +10 en Y fait spawner au-dessus pour que ça tombe
   ```
3. Faire apparaître la pièce à cette position

#### Visuel de la SpawnZone

```
        Vue de dessus :
        
    ┌─────────────────────────┐
    │                         │
    │                         │
    │      SpawnZone          │  ← Zone invisible 100x100
    │   (Transparency = 1)    │
    │                         │
    │                         │
    └─────────────────────────┘
    
    Les pièces spawnent aléatoirement dans cette zone
```

#### Conseils de placement

- **Taille** : Ajuste selon la taille de ton arène
  - Petite arène : (50, 1, 50)
  - Grande arène : (150, 1, 150)
- **Hauteur** : Place-la légèrement au-dessus du sol (Y + 0.5) pour éviter les collisions
- **Position** : Centre de l'arène pour une distribution équitable
- **Évite** : De la placer trop près des murs ou du Spinner

#### Vérification

Pour tester visuellement (temporaire) :
- Mettre **Transparency = 0.5** et **BrickColor = Bright green**
- Tu verras la zone verte où les pièces vont spawner
- Remettre **Transparency = 1** après

#### CraftZone
- **SUPPRIMÉ** - Le craft se fait via un bouton dans l'UI quand le joueur a 3 pièces en main
- Pas besoin de zone physique dans l'arène

---

### 4.3 Spinner (Barre mortelle rotative)

Le Spinner est une **barre qui tourne** et qui **tue les joueurs** qui la touchent. C'est un obstacle mortel dans l'arène.

#### Créer le Model Spinner
- Dans `Workspace/Arena/`, créer un **Model**
- Renommer en `Spinner`
- Position : au centre de l'arène (ou où tu veux)

#### Structure du Spinner
```
Spinner/ (Model)
├── Center (Part)           ← Pivot central (ne bouge pas)
└── Bar (Part)              ← La barre qui tourne
    └── Attribut "Deadly"    ← Indique que c'est mortel
```

#### Center (Pivot central)

| Propriété | Valeur | Explication |
|-----------|--------|-------------|
| **Name** | `Center` | Nom exact requis |
| **Size** | (2, 2, 2) | Petite base solide |
| **Anchored** | ✓ | **CRUCIAL** - Ne doit jamais bouger |
| **CanCollide** | ✓ | Solide |
| **BrickColor** | Really black | Base sombre |
| **Material** | Metal | Matériau solide |

- **Position** : Au centre de l'arène, au niveau du sol
- C'est le **point de rotation** - la Bar tourne autour de ce point

#### Bar (La barre mortelle)

| Propriété | Valeur | Explication |
|-----------|--------|-------------|
| **Name** | `Bar` | Nom exact requis |
| **Size** | (2, 4, 50) | Longue barre (50 studs de long) |
| **Anchored** | ✗ | **CRUCIAL** - Doit être libre pour tourner |
| **CanCollide** | ✓ | Bloque et tue les joueurs |
| **BrickColor** | Really red | Rouge = danger |
| **Material** | Neon | Brille pour être visible |
| **Transparency** | 0 | Visible |

- **Position** : Au-dessus du Center, alignée horizontalement
- **Rotation** : Parallèle au sol (Rotation X = 0, Y = 0, Z = 0)

##### Attribut Deadly
- Clic sur `Bar` → Properties → Attributes → **+**
- **Name** : `Deadly`
- **Type** : `Boolean`
- **Value** : `true`

Le code vérifiera cet attribut pour savoir si la barre tue.

#### Rotation (Phase 4 - Pas encore implémenté)

**IMPORTANT** : En Phase 0, le Spinner ne tourne pas encore. C'est normal !

La rotation sera implémentée en **Phase 4** avec le système Arena.

Pour l'instant, crée juste la structure visuelle :
- Center (Part ancrée)
- Bar (Part avec attribut `Deadly`)

**Optionnel** : Si tu veux tester la rotation maintenant, tu peux utiliser le script `SpinnerRotation.server.lua` (créé dans ServerScriptService), mais ce n'est **pas obligatoire** pour la Phase 0.

#### Visuel du Spinner

```
        Vue de dessus :
        
        ┌─────────────────────────────┐
        │                             │
        │         ┌───┐               │
        │         │ C │               │  ← Center (pivot)
        │         └───┘               │
        │         │ B │               │  ← Bar (tourne)
        │         │ B │               │
        │         │ B │               │
        │         │ B │               │
        │         │ B │               │
        │         └───┘               │
        │                             │
        └─────────────────────────────┘
        
        La Bar tourne autour du Center
```

#### Comment ça fonctionnera en jeu (Phase 4)

1. Le système Arena fera tourner la Bar automatiquement autour du Center
2. Quand un joueur touche la Bar :
   - Le code détecte via `Bar.Touched` event
   - Vérifie l'attribut `Deadly` = true
   - Tue le joueur et vide son inventaire

**Pour l'instant (Phase 0)** : Le Spinner est juste un modèle statique. Il ne fait rien encore.

#### Conseils de placement

- **Position** : Centre de l'arène pour maximiser le danger
- **Hauteur** : La Bar doit être à hauteur du joueur (Y = 3-5)
- **Longueur** : Ajuste selon la taille de l'arène
  - Petite arène : 30 studs
  - Grande arène : 60-80 studs
- **Vitesse** : Sera configurée en Phase 4 via `GameConfig.Arena.SpinnerSpeed`

---

### 4.4 Canon (Visuel décoratif)

Le Canon est **purement décoratif** - il représente visuellement d'où viennent les pièces. Le code n'en a pas besoin, mais c'est plus immersif !

#### Créer le Model Canon
- Dans `Workspace/Arena/`, créer un **Model**
- Renommer en `Canon`
- Position : Sur le bord de l'arène, pointant vers le centre

#### Structure du Canon
```
Canon/ (Model)
├── Base (Part)            ← Support du canon
├── Barrel (Part)          ← Le tube du canon
└── FirePoint (Attachment) ← Point d'où "sortent" les pièces
```

#### Base (Support)

| Propriété | Valeur |
|-----------|--------|
| **Name** | `Base` |
| **Size** | (6, 2, 6) |
| **Anchored** | ✓ |
| **CanCollide** | ✓ |
| **BrickColor** | Dark stone grey |
| **Material** | Metal |
| **Shape** | Block |

- Position : Au sol, sur le bord de l'arène

#### Barrel (Tube du canon)

| Propriété | Valeur |
|-----------|--------|
| **Name** | `Barrel` |
| **Size** | (3, 3, 12) |
| **Anchored** | ✓ |
| **CanCollide** | ✓ |
| **BrickColor** | Really black |
| **Material** | Metal |
| **Shape** | Cylinder |

- Position : Sur la Base, incliné vers le centre de l'arène
- Rotation : Incliné à ~30-45° vers le haut

#### FirePoint (Point de tir)

- Clic droit sur `Barrel` → Insert Object → **Attachment**
- Renommer en `FirePoint`

| Propriété | Valeur |
|-----------|--------|
| **Name** | `FirePoint` |
| **Position** | (0, 0, -6) - À l'extrémité du Barrel |

**Note** : Le code peut utiliser ce FirePoint pour faire spawner les pièces depuis le canon, mais ce n'est pas obligatoire.

#### Visuel du Canon

```
        Vue de côté :
        
        ┌─────┐
        │Base │  ← Support au sol
        └─────┘
          │
          │  ╱
          │ ╱ Barrel  ← Tube incliné
          │╱
          ● FirePoint ← D'où sortent les pièces
```

#### Optionnel : Animation

Tu peux ajouter une animation de recul quand une pièce spawn :
- Créer un script local qui fait bouger le Barrel légèrement en arrière puis revient

---

### 4.5 Boundaries (Murs de l'arène)

Les Boundaries sont les **murs invisibles ou visibles** qui délimitent l'arène et empêchent les joueurs de sortir.

#### Créer le Folder Boundaries
- Dans `Workspace/Arena/`, créer un **Folder**
- Renommer en `Boundaries`

#### Structure des Boundaries
```
Boundaries/ (Folder)
├── Wall_North (Part)    ← Mur nord
├── Wall_South (Part)    ← Mur sud
├── Wall_East (Part)     ← Mur est
└── Wall_West (Part)     ← Mur ouest
```

#### Dimensions recommandées

Pour une arène de **100x100 studs** :

| Mur | Position X | Position Z | Size X | Size Z | Size Y |
|-----|------------|------------|--------|--------|--------|
| **North** | 0 | +50 | 100 | 2 | 20 |
| **South** | 0 | -50 | 100 | 2 | 20 |
| **East** | +50 | 0 | 2 | 100 | 20 |
| **West** | -50 | 0 | 2 | 100 | 20 |

#### Propriétés communes à tous les murs

| Propriété | Valeur | Explication |
|-----------|--------|-------------|
| **Anchored** | ✓ | Ne doivent pas bouger |
| **CanCollide** | ✓ | Bloquent les joueurs |
| **Material** | SmoothPlastic | Par défaut |

#### Option 1 : Murs invisibles

Pour des murs invisibles (barrière invisible) :

| Propriété | Valeur |
|-----------|--------|
| **Transparency** | 1 |
| **CanCollide** | ✓ |

Les joueurs ne les verront pas mais seront bloqués.

#### Option 2 : Murs visibles

Pour des murs visibles (plus immersif) :

| Propriété | Valeur |
|-----------|--------|
| **Transparency** | 0 |
| **BrickColor** | Medium stone grey |
| **Material** | Concrete |

#### Option 3 : Murs avec texture

Pour des murs stylisés :
- Utiliser des **MeshParts** avec des textures
- Ou créer des murs avec plusieurs Parts pour un look personnalisé

#### Exemple : Wall_North

| Propriété | Valeur |
|-----------|--------|
| **Name** | `Wall_North` |
| **Size** | (100, 20, 2) |
| **Position** | (0, 10, 50) |
| **Anchored** | ✓ |
| **CanCollide** | ✓ |
| **Transparency** | 0 ou 1 (selon option) |

Répéter pour les 3 autres murs en ajustant Position et Size.

#### Visuel des Boundaries

```
        Vue de dessus :
        
    ┌─────────────────────────┐
    │   Wall_North            │  ← Mur nord
    │                         │
    │                         │
│   │                         │   │
│ W │      ARÈNE             │ E │  ← Murs est/ouest
│ e │                         │ a │
│ s │                         │ s │
│ t │                         │ t │
    │                         │
    │   Wall_South            │  ← Mur sud
    └─────────────────────────┘
```

#### Conseils

- **Hauteur** : 20 studs minimum pour éviter que les joueurs sautent par-dessus
- **Épaisseur** : 2 studs minimum pour éviter les bugs de collision
- **Position** : Juste à l'extérieur de SpawnZone pour délimiter clairement
- **Couleur** : Si visibles, utilise des couleurs sombres pour ne pas distraire

#### Optionnel : Portes d'entrée

Tu peux créer des **ouvertures** dans les murs pour les entrées :
- Créer un mur avec un trou au milieu
- Ou utiliser 2 Parts séparées avec un espace entre

---

## Récapitulatif Arena

Structure finale de l'Arena :

```
Arena/ (Folder)
├── SpawnZone (Part)        ← Zone de spawn (invisible)
├── Spinner/ (Model)        ← Barre mortelle rotative
│   ├── Center (Part)
│   └── Bar (Part)
├── Canon/ (Model)          ← Visuel décoratif (optionnel)
│   ├── Base (Part)
│   ├── Barrel (Part)
│   └── FirePoint (Attachment)
└── Boundaries/ (Folder)    ← Murs de l'arène
    ├── Wall_North (Part)
    ├── Wall_South (Part)
    ├── Wall_East (Part)
    └── Wall_West (Part)
```

---

## Étape 5 : Créer le Template de Pièce

Le **Piece_Template** est un modèle réutilisable qui sera cloné pour créer chaque pièce dans l'arène. Le code modifiera son nom, son visuel et ses attributs au spawn.

### 5.1 Créer la structure de base

Dans `ReplicatedStorage/Assets/Pieces/`, créer un **Model** nommé `Piece_Template`.

#### Structure du Template
```
Piece_Template/ (Model)
├── MainPart (Part)           ← PrimaryPart (point de référence)
│   └── BillboardGui          ← UI flottante avec nom et prix
│       ├── NameLabel         ← "Skibidi Head"
│       └── PriceLabel         ← "$50"
├── Visual (Part/MeshPart)    ← Le visuel 3D de la pièce
└── PickupZone (Part)         ← Zone de détection invisible
    └── ProximityPrompt       ← Bouton E pour ramasser
```

---

### 5.2 MainPart (Part principale)

La MainPart est la **PrimaryPart** du Model. C'est le point de référence pour positionner la pièce.

#### Créer MainPart
- Dans `Piece_Template`, créer une **Part**
- Renommer en `MainPart`

#### Propriétés de MainPart

| Propriété | Valeur | Explication |
|-----------|--------|-------------|
| **Name** | `MainPart` | Nom exact requis |
| **Size** | (3, 3, 3) | Taille de base (ajustable) |
| **Anchored** | ✗ | Libre pour tomber au spawn |
| **CanCollide** | ✓ | Collision avec le sol |
| **BrickColor** | Medium stone grey | Couleur de base |
| **Material** | SmoothPlastic | Par défaut |
| **Transparency** | 0.5 | Semi-visible pour debug (mettre à 1 si invisible) |

#### Définir MainPart comme PrimaryPart

**IMPORTANT** : Le Model doit avoir une PrimaryPart définie.

1. Sélectionner le **Model** `Piece_Template`
2. Dans Properties, trouver **PrimaryPart**
3. Cliquer sur le champ → Sélectionner `MainPart`

Ou via script (dans la console) :
```lua
game.ReplicatedStorage.Assets.Pieces.Piece_Template.PrimaryPart = game.ReplicatedStorage.Assets.Pieces.Piece_Template.MainPart
```

---

### 5.3 BillboardGui (UI flottante)

Le BillboardGui affiche le nom et le prix de la pièce au-dessus d'elle.

#### Créer le BillboardGui
- Clic droit sur `MainPart` → Insert Object → **BillboardGui**

#### Propriétés du BillboardGui

| Propriété | Valeur |
|-----------|--------|
| **Name** | `BillboardGui` |
| **Size** | UDim2.new(0, 200, 0, 80) |
| **StudsOffset** | (0, 3, 0) - 3 studs au-dessus |
| **AlwaysOnTop** | ✓ |
| **LightInfluence** | 0 |
| **MaxDistance** | 100 |

#### NameLabel (Nom de la pièce)

Dans BillboardGui, créer un **TextLabel** :

| Propriété | Valeur |
|-----------|--------|
| **Name** | `NameLabel` |
| **Size** | UDim2.new(1, 0, 0.6, 0) |
| **Position** | UDim2.new(0, 0, 0, 0) |
| **BackgroundTransparency** | 1 |
| **Text** | `Pièce` (sera remplacé par code) |
| **TextColor3** | (255, 255, 255) blanc |
| **TextScaled** | ✓ |
| **Font** | GothamBold |
| **TextStrokeTransparency** | 0.5 |

#### PriceLabel (Prix)

Dans BillboardGui, créer un autre **TextLabel** :

| Propriété | Valeur |
|-----------|--------|
| **Name** | `PriceLabel` |
| **Size** | UDim2.new(1, 0, 0.4, 0) |
| **Position** | UDim2.new(0, 0, 0.6, 0) |
| **BackgroundTransparency** | 1 |
| **Text** | `$0` (sera remplacé par code) |
| **TextColor3** | (0, 255, 0) vert |
| **TextScaled** | ✓ |
| **Font** | GothamBold |
| **TextStrokeTransparency** | 0.3 |

#### Visuel du BillboardGui

```
    ┌─────────────────────┐
    │   Skibidi Head      │  ← NameLabel (blanc)
    │      $50            │  ← PriceLabel (vert)
    └─────────────────────┘
           │
           │ (3 studs au-dessus)
           ▼
      [MainPart]
```

---

### 5.4 Visual (Le visuel 3D)

Le Visual est le modèle 3D visible de la pièce. Pour l'instant, on crée un placeholder simple.

#### Créer Visual
- Dans `Piece_Template`, créer une **Part** ou **MeshPart**
- Renommer en `Visual`

#### Option A : Part simple (placeholder)

| Propriété | Valeur |
|-----------|--------|
| **Name** | `Visual` |
| **Size** | (2, 2, 2) |
| **Anchored** | ✗ |
| **CanCollide** | ✗ |
| **BrickColor** | Bright yellow |
| **Material** | Neon |
| **Position** | Même position que MainPart |

#### Option B : MeshPart (pour plus tard)

Quand tu auras les vrais modèles 3D :
- Utiliser un **MeshPart**
- Importer le mesh depuis la Toolbox ou un fichier .fbx
- Le code remplacera ce Visual par le bon mesh selon le set

#### Position du Visual

- **Position** : Même position que MainPart (ou légèrement décalé)
- Ou utiliser un **WeldConstraint** pour l'attacher à MainPart

---

### 5.5 PickupZone (Zone de détection)

La PickupZone est une zone invisible plus grande que la pièce pour faciliter le ramassage.

#### Créer PickupZone
- Dans `Piece_Template`, créer une **Part**
- Renommer en `PickupZone`

#### Propriétés de PickupZone

| Propriété | Valeur | Explication |
|-----------|--------|-------------|
| **Name** | `PickupZone` | Nom exact requis |
| **Size** | (5, 5, 5) | Plus grand que MainPart pour faciliter le pickup |
| **Anchored** | ✗ | Suit MainPart |
| **CanCollide** | ✗ | Ne bloque pas |
| **Transparency** | 1 | Invisible |
| **BrickColor** | N'importe | Pas visible de toute façon |

#### Position de PickupZone

- **Position** : Même position que MainPart
- Ou utiliser un **WeldConstraint** pour l'attacher à MainPart

#### ProximityPrompt (Bouton E)

Dans PickupZone, créer un **ProximityPrompt** :

| Propriété | Valeur |
|-----------|--------|
| **Name** | `ProximityPrompt` |
| **ActionText** | `Ramasser` |
| **ObjectText** | `Pièce - $0` (sera mis à jour par code) |
| **HoldDuration** | `0` (instantané) |
| **MaxActivationDistance** | `10` |
| **KeyboardKeyCode** | `E` |
| **RequiresLineOfSight** | ✗ |

---

### 5.6 Structure finale du Template

```
Piece_Template/ (Model)
│
├── PrimaryPart → MainPart
│
├── MainPart (Part)              ← Part principale
│   ├── Size: (3, 3, 3)
│   ├── Anchored: false
│   ├── CanCollide: true
│   └── BillboardGui
│       ├── Size: (200, 80)
│       ├── StudsOffset: (0, 3, 0)
│       ├── NameLabel (TextLabel)
│       │   └── Text: "Pièce"
│       └── PriceLabel (TextLabel)
│           └── Text: "$0"
│
├── Visual (Part/MeshPart)        ← Visuel 3D
│   ├── Size: (2, 2, 2)
│   └── Position: Même que MainPart
│
└── PickupZone (Part)             ← Zone de détection
    ├── Size: (5, 5, 5)
    ├── Transparency: 1
    ├── CanCollide: false
    └── ProximityPrompt
        ├── ActionText: "Ramasser"
        └── HoldDuration: 0
```

---

### 5.7 Comment ça fonctionnera en jeu (Phase 4)

Quand une pièce spawn dans l'arène :

1. Le code clone `Piece_Template`
2. Renomme le clone : `Piece_Skibidi_Head_12345` (nom unique)
3. Modifie les Attributs :
   - `SetName` = "Skibidi"
   - `PieceType` = "Head"
   - `Price` = 50
   - `DisplayName` = "Skibidi"
4. Met à jour les TextLabels :
   - `NameLabel.Text` = "Skibidi Head"
   - `PriceLabel.Text` = "$50"
5. Remplace le Visual par le bon mesh (si disponible)
6. Positionne la pièce dans SpawnZone
7. Place dans `Workspace/ActivePieces/`

---

### 5.8 Conseils

- **MainPart** : Garde-la simple, c'est juste un point de référence
- **Visual** : Pour l'instant, un cube coloré suffit. Tu remplaceras par les vrais modèles plus tard
- **PickupZone** : Plus grande = plus facile à ramasser, mais pas trop (5x5x5 est bien)
- **BillboardGui** : Teste différentes tailles selon tes besoins
- **PrimaryPart** : **CRUCIAL** - Sans ça, le code ne pourra pas positionner la pièce

---

### 5.9 Vérification

Avant de continuer, vérifier :

- [ ] Piece_Template existe dans `ReplicatedStorage/Assets/Pieces/`
- [ ] MainPart est définie comme PrimaryPart
- [ ] BillboardGui contient NameLabel et PriceLabel
- [ ] PickupZone contient un ProximityPrompt
- [ ] Visual existe (même si c'est juste un placeholder)

---

## Étape 6 : Dupliquer les bases

Une fois `Base_1` complète :

1. Dupliquer `Base_1` → `Base_2`, `Base_3`, ... jusqu'à `Base_8` (ou plus)
2. Pour chaque copie :
   - Changer l'attribut `BaseIndex` (2, 3, 4...)
   - Repositionner la base

---

## Vérification finale

Avant de passer à la Phase 1, vérifier :

- [ ] Tous les ModuleScripts sont importés sans erreur
- [ ] La structure des dossiers est correcte
- [ ] Au moins une Base_1 complète existe
- [ ] L'Arena existe avec SpawnZone, Spinner
- [ ] Le Folder ActivePieces existe (vide)
- [ ] Le Piece_Template existe dans ReplicatedStorage/Assets/Pieces/
- [ ] Tous les ProximityPrompts sont configurés
