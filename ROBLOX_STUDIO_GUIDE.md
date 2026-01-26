# 🎮 Brainrot Assembly Chaos - Guide Roblox Studio

## 📋 Table des Matières
1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Configuration initiale](#configuration-initiale)
4. [Structure du projet](#structure-du-projet)
5. [Étapes d'implémentation dans Studio](#étapes-dimplémentation-dans-studio)
6. [Configuration de l'arène](#configuration-de-larène)
7. [Placement des cannons](#placement-des-cannons)
8. [Configuration des bases de joueurs](#configuration-des-bases-de-joueurs)
9. [Ajout des effets visuels](#ajout-des-effets-visuels)
10. [Configuration audio](#configuration-audio)
11. [Tests et débogage](#tests-et-débogage)
12. [Optimisation](#optimisation)

---

## 🎯 Vue d'ensemble

Ce guide vous explique comment importer et configurer le jeu **Brainrot Assembly Chaos** dans Roblox Studio. Tous les scripts sont déjà créés dans le dossier `GamePlace/`, vous devez maintenant les importer et créer les éléments visuels dans Studio.

### Qu'est-ce qui est déjà fait ?
✅ Tous les scripts serveur (logique de jeu)
✅ Tous les scripts client (contrôles, UI)
✅ Systèmes de gameplay complets
✅ Configuration centralisée

### Ce que vous devez faire dans Studio :
🔨 Créer l'arène physique (terrain, murs)
🔨 Placer les cannons visuels
🔨 Créer les bases de joueurs avec piédestaux
🔨 Ajouter les modèles de parties de corps
🔨 Configurer les effets visuels
🔨 Ajouter les sons

---

## 🛠️ Prérequis

- **Roblox Studio** installé et à jour
- **Node.js** installé (pour server.js)
- Le dossier `GamePlace/` avec tous les scripts
- Accès à la bibliothèque d'assets Roblox (pour sons et textures)

---

## ⚙️ Configuration initiale

### 1. Démarrer le serveur de synchronisation

Ouvrez un terminal dans le dossier du projet et lancez :

```bash
node server.js
```

Le serveur devrait afficher :
```
Server listening on port 3000
WebSocket server listening on port 3001
```

### 2. Créer un nouveau projet Roblox

1. Ouvrez **Roblox Studio**
2. Créez un nouveau projet : **File > New > Baseplate**
3. Sauvegardez le projet : **File > Save to Roblox**

### 3. Configurer la synchronisation (optionnel)

Si vous utilisez un plugin de synchronisation de fichiers :
- Configurez-le pour pointer vers le dossier `GamePlace/`
- Sinon, vous devrez copier-coller les scripts manuellement

---

## 📁 Structure du projet

Voici comment organiser votre projet dans Roblox Studio :

```
Workspace/
├── Arena/                    # À créer
│   ├── Floor (Part)
│   ├── Boundary (Folder)    # Créé automatiquement par ArenaVisuals
│   └── CentralLaser (Part)  # À créer
│
├── Cannons/                  # À créer
│   ├── Cannon1 (Model)
│   ├── Cannon2 (Model)
│   └── ... (6 cannons total)
│
├── PlayerBases/              # À créer
│   ├── Base1 (Folder)
│   │   ├── PressurePlate (Part)
│   │   ├── Pedestal1 (Part)
│   │   ├── Pedestal2 (Part)
│   │   └── Pedestal3 (Part)
│   └── ... (8 bases max)
│
└── BodyParts/                # Dossier pour les parties spawned
    └── (vide au départ)

ReplicatedStorage/
├── GameConfig
├── DataStructures
├── NameFragments
├── VFXSystem
├── AudioSystem
└── RemoteEvents (Folder)    # Créé par NetworkManager

ServerScriptService/
├── NetworkManager
├── GameServer
├── Arena
├── ArenaVisuals
├── CannonSystem
├── CollectionSystem
├── AssemblySystem
├── CentralLaserSystem
├── CombatSystem
├── BaseProtectionSystem
├── TheftSystem
└── CodexSystem

StarterPlayer/
└── StarterPlayerScripts/
    └── PlayerController

StarterGui/
├── CodexUI
├── PlayerNameDisplay
└── GameHUD
```

---

## 🏗️ Étapes d'implémentation dans Studio

### ÉTAPE 1 : Importer les scripts

#### A. ReplicatedStorage

1. Dans l'Explorer, cliquez sur **ReplicatedStorage**
2. Insérez un **ModuleScript** (clic droit > Insert Object > ModuleScript)
3. Renommez-le `GameConfig`
4. Ouvrez le fichier `GamePlace/ReplicatedStorage/GameConfig.lua`
5. Copiez tout le contenu et collez-le dans le script Studio
6. Répétez pour :
   - `DataStructures.lua`
   - `NameFragments.lua`
   - `VFXSystem.lua`
   - `AudioSystem.lua`

#### B. ServerScriptService

1. Cliquez sur **ServerScriptService**
2. Pour chaque fichier `.lua` dans `GamePlace/ServerScriptService/` :
   - Si le nom se termine par `.server.lua` : Insérez un **Script**
   - Sinon : Insérez un **ModuleScript**
3. Copiez le contenu de chaque fichier

**Scripts à importer :**
- `NetworkManager.server.lua` → Script
- `GameServer.server.lua` → Script
- `ArenaVisuals.server.lua` → Script
- `Arena.lua` → ModuleScript
- `CannonSystem.lua` → ModuleScript
- `CollectionSystem.lua` → ModuleScript
- `AssemblySystem.lua` → ModuleScript
- `CentralLaserSystem.lua` → ModuleScript
- `CombatSystem.lua` → ModuleScript
- `BaseProtectionSystem.lua` → ModuleScript
- `TheftSystem.lua` → ModuleScript
- `CodexSystem.lua` → ModuleScript

#### C. StarterPlayer

1. Cliquez sur **StarterPlayer > StarterPlayerScripts**
2. Insérez un **LocalScript** nommé `PlayerController`
3. Copiez le contenu de `GamePlace/StarterPlayer/StarterPlayerScripts/PlayerController.client.lua`

#### D. StarterGui

1. Cliquez sur **StarterGui**
2. Pour chaque fichier `.client.lua` :
   - Insérez un **LocalScript**
   - Copiez le contenu

**Scripts à importer :**
- `CodexUI.client.lua` → LocalScript
- `PlayerNameDisplay.client.lua` → LocalScript
- `GameHUD.client.lua` → LocalScript

---

### ÉTAPE 2 : Créer l'arène physique

#### A. Sol de l'arène

1. Dans **Workspace**, insérez un **Part**
2. Renommez-le `ArenaFloor`
3. Configurez :
   - **Size** : `100, 1, 100` (pour un rayon de 50 studs)
   - **Position** : `0, 0, 0`
   - **Anchored** : ✅ Coché
   - **Material** : `Concrete` ou `Slate`
   - **Color** : Gris foncé
4. Ajoutez une **Texture** ou **Decal** pour plus de style (optionnel)

#### B. Créer un dossier Arena

1. Dans **Workspace**, insérez un **Folder**
2. Renommez-le `Arena`
3. Déplacez `ArenaFloor` dans ce dossier

#### C. Les murs de frontière seront créés automatiquement

Le script `ArenaVisuals.server.lua` créera automatiquement les murs néon autour de l'arène au démarrage du serveur.

---

### ÉTAPE 3 : Créer le laser central

1. Dans **Workspace > Arena**, insérez un **Part**
2. Renommez-le `CentralLaser`
3. Configurez :
   - **Size** : `50, 2, 2` (longueur = rayon de l'arène)
   - **Position** : `0, 5, 0`
   - **Anchored** : ✅ Coché
   - **CanCollide** : ❌ Décoché (la collision est gérée par script)
   - **Material** : `Neon`
   - **Color** : Rouge vif `255, 0, 0`
   - **Transparency** : `0.3`

4. Ajoutez un **PointLight** au laser :
   - **Brightness** : `3`
   - **Color** : Rouge
   - **Range** : `20`

5. Ajoutez un **ParticleEmitter** pour l'effet de traînée :
   - **Texture** : `rbxasset://textures/particles/sparkles_main.dds`
   - **Color** : Rouge
   - **Lifetime** : `0.5, 1`
   - **Rate** : `50`
   - **Speed** : `5, 10`

---

### ÉTAPE 4 : Créer les cannons

#### A. Modèle de cannon (à répéter 6 fois)

1. Dans **Workspace**, insérez un **Folder** nommé `Cannons`

2. Pour chaque cannon :
   - Insérez un **Model** dans `Cannons`
   - Renommez-le `Cannon1`, `Cannon2`, etc.

3. Dans chaque Model, créez :

**Base du cannon :**
- **Part** nommé `Base`
- **Size** : `3, 3, 3`
- **Material** : `Metal`
- **Color** : Gris métallique
- **Anchored** : ✅

**Tube du cannon :**
- **Part** nommé `Barrel`
- **Size** : `1, 1, 4`
- **Material** : `Metal`
- **Color** : Gris foncé
- **Anchored** : ✅
- Positionnez-le pour qu'il sorte de la base

**Effet visuel :**
- Ajoutez un **ParticleEmitter** au bout du tube
- **Texture** : Fumée ou étincelles
- **Enabled** : ❌ (sera activé par script lors du tir)

#### B. Placement des cannons

Les cannons doivent être placés autour de l'arène. Pour un rayon de 50 studs :

**Positions suggérées (6 cannons) :**
1. Cannon1 : `(50, 5, 0)` - Est
2. Cannon2 : `(25, 5, 43.3)` - Nord-Est
3. Cannon3 : `(-25, 5, 43.3)` - Nord-Ouest
4. Cannon4 : `(-50, 5, 0)` - Ouest
5. Cannon5 : `(-25, 5, -43.3)` - Sud-Ouest
6. Cannon6 : `(25, 5, -43.3)` - Sud-Est

**Orientation :**
- Chaque cannon doit pointer vers le centre `(0, 5, 0)`
- Utilisez l'outil **Rotate** pour orienter les barrels

---

### ÉTAPE 5 : Créer les bases de joueurs

#### A. Créer le dossier

1. Dans **Workspace**, insérez un **Folder** nommé `PlayerBases`

#### B. Créer une base (modèle à répéter 8 fois)

Pour chaque base :

1. Insérez un **Folder** dans `PlayerBases`
2. Renommez-le `Base1`, `Base2`, etc.

**Plaque de pression :**
- **Part** nommé `PressurePlate`
- **Size** : `4, 0.5, 4`
- **Position** : Autour de l'arène (voir positions ci-dessous)
- **Anchored** : ✅
- **Material** : `Neon`
- **Color** : Vert `0, 255, 0`
- **Transparency** : `0.5`

**Piédestaux (3 par base) :**
- **Part** nommé `Pedestal1`, `Pedestal2`, `Pedestal3`
- **Size** : `2, 3, 2`
- **Anchored** : ✅
- **Material** : `Marble`
- **Color** : Blanc
- Positionnez-les en triangle autour de la plaque

**Barrière (sera créée par script) :**
- Pas besoin de créer, le script `BaseProtectionSystem` la gère

#### C. Positions des bases (rayon 35 studs)

1. Base1 : `(35, 5, 0)`
2. Base2 : `(24.7, 5, 24.7)`
3. Base3 : `(0, 5, 35)`
4. Base4 : `(-24.7, 5, 24.7)`
5. Base5 : `(-35, 5, 0)`
6. Base6 : `(-24.7, 5, -24.7)`
7. Base7 : `(0, 5, -35)`
8. Base8 : `(24.7, 5, -24.7)`

---

### ÉTAPE 6 : Créer les modèles de parties de corps

#### A. Créer un dossier de templates

1. Dans **ReplicatedStorage**, insérez un **Folder** nommé `BodyPartTemplates`

#### B. Créer les 3 types de parties

**Tête (HEAD) :**
1. Insérez un **Model** nommé `HeadTemplate`
2. Ajoutez un **Part** :
   - **Size** : `2, 2, 2`
   - **Shape** : `Ball` (dans Properties)
   - **Material** : `Neon`
   - **Color** : Cyan `0, 255, 255`
   - **CanCollide** : ✅
3. Ajoutez un **PointLight** :
   - **Color** : Cyan
   - **Brightness** : `2`
   - **Range** : `10`

**Corps (BODY) :**
1. Insérez un **Model** nommé `BodyTemplate`
2. Ajoutez un **Part** :
   - **Size** : `2, 3, 1.5`
   - **Material** : `Neon`
   - **Color** : Rose/Magenta `255, 0, 255`
   - **CanCollide** : ✅
3. Ajoutez un **PointLight** (même config, couleur rose)

**Jambes (LEGS) :**
1. Insérez un **Model** nommé `LegsTemplate`
2. Ajoutez un **Part** :
   - **Size** : `2, 2, 1`
   - **Material** : `Neon`
   - **Color** : Jaune `255, 255, 0`
   - **CanCollide** : ✅
3. Ajoutez un **PointLight** (même config, couleur jaune)

---

### ÉTAPE 7 : Configuration des effets visuels

#### A. Activer les effets de post-traitement

1. Dans **Lighting**, insérez :
   - **Bloom** :
     - **Intensity** : `0.5`
     - **Size** : `24`
     - **Threshold** : `0.8`
   
   - **ColorCorrection** :
     - **Saturation** : `0.2` (pour des couleurs plus vives)
     - **Contrast** : `0.1`

#### B. Configurer l'éclairage

1. Dans **Lighting** :
   - **Ambient** : `50, 50, 50` (éclairage ambiant sombre)
   - **Brightness** : `2`
   - **OutdoorAmbient** : `70, 70, 70`
   - **Technology** : `ShadowMap` ou `Future`

2. Ajoutez un **Sky** (optionnel) :
   - Choisissez un skybox sombre/spatial pour l'ambiance

---

### ÉTAPE 8 : Configuration audio

#### A. Trouver les sons

Vous devez trouver des Sound IDs sur Roblox pour :
- ✅ Completion (victoire) - Son d'airhorn ou fanfare
- ✅ Collection - Pop ou ding
- ✅ Laser hit - Zap électrique
- ✅ Punch hit - Punch cartoon (boing/pow)
- ✅ Cannon fire - Whoosh
- ✅ Barrier activate - Bourdonnement de champ de force
- ✅ Theft - Son sournois

#### B. Mettre à jour AudioSystem

1. Ouvrez `ReplicatedStorage > AudioSystem`
2. Remplacez les `rbxassetid://0` par les vrais IDs :

```lua
AudioSystem.Sounds = {
    completion = "rbxassetid://VOTRE_ID_ICI",
    collection = "rbxassetid://VOTRE_ID_ICI",
    laserHit = "rbxassetid://VOTRE_ID_ICI",
    punchHit = "rbxassetid://VOTRE_ID_ICI",
    cannonFire = "rbxassetid://VOTRE_ID_ICI",
    barrierActivate = "rbxassetid://VOTRE_ID_ICI",
    theft = "rbxassetid://VOTRE_ID_ICI"
}
```

#### C. Musique de fond (optionnel)

1. Dans **Workspace**, insérez un **Sound**
2. Nommez-le `BackgroundMusic`
3. Configurez :
   - **SoundId** : ID d'une musique énergique
   - **Looped** : ✅
   - **Volume** : `0.3`
   - **Playing** : ✅

---

### ÉTAPE 9 : Configuration du spawn des joueurs

1. Dans **Workspace**, supprimez le **SpawnLocation** par défaut
2. Les joueurs spawneront automatiquement à leur base (géré par `GameServer.server.lua`)

---

### ÉTAPE 10 : Tests et débogage

#### A. Test en solo

1. Cliquez sur **Play** (F5) dans Studio
2. Vérifiez dans la **Output** :
   ```
   ✓ Network Manager initialized
   ✓ Arena boundary created: CIRCULAR
   ✓ Initialized 6 cannons around arena
   🎮 Brainrot Assembly Chaos - Server Initialized
   🚀 Match started!
   ```

3. Testez :
   - ✅ Les murs de l'arène apparaissent
   - ✅ Le laser tourne
   - ✅ Les cannons spawent des parties toutes les 2-5 secondes
   - ✅ Vous pouvez collecter les parties
   - ✅ L'assemblage se fait automatiquement
   - ✅ Le HUD s'affiche

#### B. Test multijoueur

1. Cliquez sur **Test** > **Start Server and Players**
2. Choisissez 2-4 joueurs
3. Testez :
   - ✅ Chaque joueur a sa propre base
   - ✅ Le combat fonctionne (punch)
   - ✅ Les barrières se activent
   - ✅ Le vol fonctionne

#### C. Débogage courant

**Problème : Les scripts ne se chargent pas**
- Vérifiez que `NetworkManager` se lance en premier
- Vérifiez l'Output pour les erreurs

**Problème : Les parties ne spawent pas**
- Vérifiez que les templates existent dans ReplicatedStorage
- Vérifiez les positions des cannons

**Problème : Le laser ne tourne pas**
- Vérifiez que `CentralLaser` existe dans Workspace
- Vérifiez qu'il est Anchored

**Problème : L'UI ne s'affiche pas**
- Vérifiez que les LocalScripts sont dans StarterGui
- Vérifiez que RemoteEvents existe dans ReplicatedStorage

---

### ÉTAPE 11 : Optimisation

#### A. Performance

1. **Streaming Enabled** :
   - Dans **Workspace** properties
   - Activez `StreamingEnabled` pour de meilleures performances
   - Configurez `StreamingMinRadius` : `128`
   - Configurez `StreamingTargetRadius` : `256`

2. **Collision Groups** :
   - Créez des groupes de collision pour optimiser
   - Body parts ne doivent pas collider entre eux

3. **LOD (Level of Detail)** :
   - Réduisez les détails des objets lointains
   - Utilisez `RenderFidelity` sur les MeshParts

#### B. Réseau

1. Limitez les RemoteEvent calls
2. Utilisez des buffers pour les updates fréquents
3. Compressez les données envoyées

---

## 🎨 Personnalisation

### Changer les couleurs

Modifiez `GameConfig.lua` :
```lua
GameConfig.NEON_COLORS = {
    HEAD = Color3.fromRGB(0, 255, 255), -- Cyan
    BODY = Color3.fromRGB(255, 0, 255), -- Rose
    LEGS = Color3.fromRGB(255, 255, 0)  -- Jaune
}
```

### Changer la taille de l'arène

Modifiez `GameConfig.lua` :
```lua
GameConfig.ARENA_RADIUS = 50 -- Changez cette valeur
```

Puis ajustez la taille du sol et repositionnez les cannons/bases.

### Ajouter plus de fragments de noms

Modifiez `NameFragments.lua` et ajoutez vos propres noms !

---

## 📝 Checklist finale

Avant de publier votre jeu :

- [ ] Tous les scripts sont importés
- [ ] L'arène est créée avec sol et murs
- [ ] Les 6 cannons sont placés et orientés
- [ ] Les 8 bases sont créées avec piédestaux
- [ ] Les templates de parties de corps existent
- [ ] Les effets visuels sont configurés
- [ ] Les sons sont ajoutés avec les bons IDs
- [ ] Le jeu a été testé en solo
- [ ] Le jeu a été testé en multijoueur
- [ ] Les performances sont bonnes (60 FPS)
- [ ] L'UI s'affiche correctement
- [ ] Le Codex fonctionne (touche C)
- [ ] Les contrôles fonctionnent (E pour punch, F pour voler)

---

## 🚀 Publication

1. **Testez une dernière fois** avec plusieurs joueurs
2. **Configurez les permissions** du jeu
3. **Ajoutez une description** et des images
4. **Publiez** : File > Publish to Roblox
5. **Configurez** les paramètres du jeu sur le site Roblox

---

## 🆘 Support

Si vous rencontrez des problèmes :

1. Vérifiez l'**Output** dans Studio pour les erreurs
2. Vérifiez que tous les scripts sont bien nommés
3. Vérifiez que la structure des dossiers est correcte
4. Testez chaque système individuellement

---

## 🎉 Félicitations !

Votre jeu **Brainrot Assembly Chaos** est maintenant prêt ! Amusez-vous bien et n'hésitez pas à personnaliser le jeu à votre goût !

**Bon développement ! 🚀**
