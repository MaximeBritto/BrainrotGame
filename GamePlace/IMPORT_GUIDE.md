# 📥 Guide d'Import - Phase 1 DEV A

## 🎯 Objectif

Importer les 4 fichiers backend de la Phase 1 dans Roblox Studio.

---

## 📋 Fichiers à Importer

### Core Services (3 fichiers)

| # | Fichier Source | Destination Studio |
|---|----------------|-------------------|
| 1 | `ServerScriptService/Core/DataService.module.lua` | `ServerScriptService > Core > DataService` |
| 2 | `ServerScriptService/Core/PlayerService.module.lua` | `ServerScriptService > Core > PlayerService` |
| 3 | `ServerScriptService/Core/GameServer.server.lua` | `ServerScriptService > Core > GameServer` |

### Handlers (1 fichier)

| # | Fichier Source | Destination Studio |
|---|----------------|-------------------|
| 4 | `ServerScriptService/Handlers/NetworkHandler.module.lua` | `ServerScriptService > Handlers > NetworkHandler` |

---

## 🔧 Méthode 1 : Import Manuel (Recommandé)

### Étape 1 : Préparer Studio

1. Ouvrir Roblox Studio
2. Ouvrir votre place (ou créer une nouvelle)
3. Ouvrir l'Explorer (View > Explorer)

### Étape 2 : Créer la Structure

Dans **ServerScriptService** :

1. **Créer le dossier Core** (s'il n'existe pas déjà)
   - Clic droit sur `ServerScriptService`
   - Insert Object > Folder
   - Renommer en `Core`

2. **Créer le dossier Handlers**
   - Clic droit sur `ServerScriptService`
   - Insert Object > Folder
   - Renommer en `Handlers`

### Étape 3 : Importer DataService

1. Dans `ServerScriptService > Core` :
   - Clic droit > Insert Object > ModuleScript
   - Renommer en `DataService`
2. Double-cliquer sur `DataService` pour ouvrir l'éditeur
3. **Supprimer tout le contenu** par défaut
4. Ouvrir `GamePlace/ServerScriptService/Core/DataService.module.lua`
5. **Copier tout le contenu** (Ctrl+A, Ctrl+C)
6. **Coller dans Studio** (Ctrl+V)
7. Sauvegarder (Ctrl+S)

### Étape 4 : Importer PlayerService

1. Dans `ServerScriptService > Core` :
   - Clic droit > Insert Object > ModuleScript
   - Renommer en `PlayerService`
2. Double-cliquer sur `PlayerService`
3. **Supprimer tout le contenu** par défaut
4. Ouvrir `GamePlace/ServerScriptService/Core/PlayerService.module.lua`
5. **Copier tout le contenu**
6. **Coller dans Studio**
7. Sauvegarder

### Étape 5 : Importer GameServer

⚠️ **ATTENTION : C'est un Script, pas un ModuleScript !**

1. Dans `ServerScriptService > Core` :
   - Clic droit > Insert Object > **Script** (pas ModuleScript)
   - Renommer en `GameServer`
2. Double-cliquer sur `GameServer`
3. **Supprimer tout le contenu** par défaut
4. Ouvrir `GamePlace/ServerScriptService/Core/GameServer.server.lua`
5. **Copier tout le contenu**
6. **Coller dans Studio**
7. Sauvegarder

### Étape 6 : Importer NetworkHandler

1. Dans `ServerScriptService > Handlers` :
   - Clic droit > Insert Object > ModuleScript
   - Renommer en `NetworkHandler`
2. Double-cliquer sur `NetworkHandler`
3. **Supprimer tout le contenu** par défaut
4. Ouvrir `GamePlace/ServerScriptService/Handlers/NetworkHandler.module.lua`
5. **Copier tout le contenu**
6. **Coller dans Studio**
7. Sauvegarder

---

## 🔧 Méthode 2 : Plugin Rojo (Avancé)

Si vous utilisez Rojo pour synchroniser automatiquement :

1. Installer Rojo : https://rojo.space/
2. Créer un fichier `default.project.json` à la racine
3. Configurer les chemins de synchronisation
4. Lancer `rojo serve`
5. Connecter depuis Studio avec le plugin Rojo

**Note :** Cette méthode est plus avancée et nécessite une configuration supplémentaire.

---

## ✅ Vérification

### Structure Finale dans Studio

```
ServerScriptService
├── Core (Folder)
│   ├── NetworkSetup (ModuleScript) [Existant Phase 0]
│   ├── DataService (ModuleScript) ✅ NOUVEAU
│   ├── PlayerService (ModuleScript) ✅ NOUVEAU
│   └── GameServer (Script) ✅ NOUVEAU
└── Handlers (Folder) ✅ NOUVEAU
    └── NetworkHandler (ModuleScript) ✅ NOUVEAU
```

### Checklist

- [ ] Dossier `Core` existe dans `ServerScriptService`
- [ ] Dossier `Handlers` existe dans `ServerScriptService`
- [ ] `DataService` est un **ModuleScript** dans `Core`
- [ ] `PlayerService` est un **ModuleScript** dans `Core`
- [ ] `GameServer` est un **Script** (pas ModuleScript) dans `Core`
- [ ] `NetworkHandler` est un **ModuleScript** dans `Handlers`
- [ ] Tous les fichiers ont leur contenu complet (pas de code par défaut)

---

## 🧪 Test de Fonctionnement

### Étape 1 : Lancer le Jeu

1. Cliquer sur **Play Solo** (F5)
2. Ouvrir l'**Output** (View > Output)

### Étape 2 : Vérifier les Logs

Vous devriez voir dans l'Output :

```
═══════════════════════════════════════════════
   BRAINROT GAME - Démarrage du serveur
═══════════════════════════════════════════════
[GameServer] Initialisation des services...
[NetworkSetup] Création des Remotes...
[NetworkSetup] RemoteEvent créé: PickupPiece
[NetworkSetup] RemoteEvent créé: Craft
[NetworkSetup] RemoteEvent créé: BuySlot
[NetworkSetup] RemoteEvent créé: CollectSlotCash
[NetworkSetup] RemoteEvent créé: ActivateDoor
[NetworkSetup] RemoteEvent créé: DropPieces
[NetworkSetup] RemoteEvent créé: SyncPlayerData
[NetworkSetup] RemoteEvent créé: SyncInventory
[NetworkSetup] RemoteEvent créé: SyncCodex
[NetworkSetup] RemoteEvent créé: SyncDoorState
[NetworkSetup] RemoteEvent créé: Notification
[NetworkSetup] RemoteFunction créée: GetFullPlayerData
[NetworkSetup] Tous les Remotes sont prêts!
[GameServer] NetworkSetup: OK
[DataService] Initialisation...
[DataService] Impossible de créer DataStore: ... (NORMAL EN STUDIO)
[DataService] Mode hors-ligne activé (données non persistantes)
[DataService] Auto-save démarré (intervalle: 60s)
[DataService] Initialisé!
[GameServer] DataService: OK
[PlayerService] Initialisation...
[PlayerService] Initialisé!
[GameServer] PlayerService: OK
[NetworkHandler] Initialisation...
[NetworkHandler] Handlers connectés
[NetworkHandler] Initialisé!
[GameServer] NetworkHandler: OK
═══════════════════════════════════════════════
   BRAINROT GAME - Serveur prêt!
═══════════════════════════════════════════════
[PlayerService] Joueur rejoint: YourUsername
[DataService] Chargement des données pour YourUsername (ID: ...)
[DataService] Nouveau joueur ou données vides, utilisation des défauts
[DataService] Données chargées pour YourUsername
[PlayerService] Données envoyées au client: YourUsername
[PlayerService] Joueur initialisé: YourUsername
[PlayerService] Personnage spawné: YourUsername
```

### Étape 3 : Vérifier les Remotes

1. Dans l'Explorer, aller dans `ReplicatedStorage`
2. Vérifier qu'un dossier `Remotes` a été créé
3. Il doit contenir 12 RemoteEvents/Functions :
   - PickupPiece (RemoteEvent)
   - Craft (RemoteEvent)
   - BuySlot (RemoteEvent)
   - CollectSlotCash (RemoteEvent)
   - ActivateDoor (RemoteEvent)
   - DropPieces (RemoteEvent)
   - SyncPlayerData (RemoteEvent)
   - SyncInventory (RemoteEvent)
   - SyncCodex (RemoteEvent)
   - SyncDoorState (RemoteEvent)
   - Notification (RemoteEvent)
   - GetFullPlayerData (RemoteFunction)

---

## ❌ Problèmes Courants

### Erreur : "NetworkSetup is not a valid member"

**Cause :** Le fichier `NetworkSetup.module.lua` de Phase 0 n'existe pas.

**Solution :**
1. Vérifier que `ServerScriptService > Core > NetworkSetup` existe
2. Si non, créer le fichier depuis Phase 0

### Erreur : "attempt to call a nil value"

**Cause :** Un fichier n'a pas été importé correctement ou est vide.

**Solution :**
1. Vérifier que tous les fichiers ont du contenu (pas juste `return {}`)
2. Vérifier les noms des fichiers (sensible à la casse)
3. Vérifier que `GameServer` est un **Script** et pas un ModuleScript

### Erreur : "DataStore request was rejected"

**Cause :** Normal en Studio sans API access.

**Solution :** Aucune, c'est normal. Le mode hors-ligne s'active automatiquement.

### Pas de Logs dans Output

**Cause :** Le script `GameServer` ne s'exécute pas.

**Solution :**
1. Vérifier que `GameServer` est bien un **Script** (icône bleue avec engrenage)
2. Vérifier qu'il est dans `ServerScriptService > Core`
3. Vérifier que le contenu est bien copié
4. Redémarrer le jeu (Stop puis Play)

---

## 🎯 Prochaines Étapes

Après avoir importé et testé avec succès :

1. **Arrêter le jeu** (Stop)
2. **Passer à Phase 1 DEV B** (création UI)
3. Suivre le guide dans `PHASE_1_README.md` section DEV B

---

## 📚 Ressources

- `PHASE_1_README.md` - Guide complet Phase 1
- `PHASE_1_DEV_A_COMPLETE.md` - Résumé de ce qui a été fait
- `CHANGELOG.md` - Historique des modifications
- `ROBLOX_SETUP_GUIDE.md` - Guide général Studio

---

## 💡 Conseils

### Sauvegarde

Avant d'importer, sauvegarder votre place :
- File > Save to Roblox
- Ou File > Save to File (backup local)

### Organisation

Garder la même structure de dossiers que dans le code source pour faciliter les mises à jour futures.

### Tests Progressifs

Importer et tester un fichier à la fois pour identifier rapidement les problèmes.

### Output

Toujours avoir l'Output ouvert pendant les tests pour voir les logs et erreurs.

---

**Bon import ! 🚀**

Si vous rencontrez des problèmes, vérifiez d'abord la section "Problèmes Courants" ci-dessus.
