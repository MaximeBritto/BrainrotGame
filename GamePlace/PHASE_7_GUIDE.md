# PHASE 7 : POLISH & TESTS - Guide Complet et Détaillé

**Date:** 2026-02-05  
**Status:** À faire (Phase 6.5 complétée)  
**Prérequis:** Phases 0, 1, 2, 3, 4, 5, 5.5, 6 et 6.5 complétées (SYNC 6.5 validé)

---

## Vue d'ensemble

La Phase 7 finalise le jeu avec du **polish visuel**, de la **robustesse** et des **tests end-to-end** :
- **DEV A** : Gestion des erreurs, logs structurés, tests multi-joueurs, équilibrage
- **DEV B** : Sons, particules, UI responsive, tutoriel basique

### Objectif final de la Phase 7

- Le jeu est **stable** et **sans bugs bloquants**
- Les **sons** accompagnent les actions clés (collecte, craft, achat, mort, porte)
- Les **particules** et effets visuels renforcent le feedback
- L'**UI** s'adapte correctement aux différentes résolutions
- Un **tutoriel basique** guide les nouveaux joueurs
- Les **performances** sont acceptables (pas de memory leaks sur 10 min de jeu)
- Le **multi-joueurs** est stable (pas de race conditions)

---

## Résumé des tâches

### DEV A - Robustesse & Tests

| #   | Tâche                              | Dépendance | Fichier / Lieu                    | Temps estimé |
|-----|------------------------------------|------------|-----------------------------------|--------------|
| A7.1 | Gestion erreurs complète           | Aucune     | Tous les modules serveur          | 2h           |
| A7.2 | Logs et debug structurés          | A7.1       | Tous les modules                  | 1h           |
| A7.3 | Tests multi-joueurs                | Aucune     | Studio (Test → Players)           | 1h30         |
| A7.4 | Équilibrage (prix, revenus, spawn) | Aucune     | GameConfig, SlotPrices            | 1h           |

**Total DEV A :** ~5h30

### DEV B - Polish Visuel

| #   | Tâche                              | Dépendance | Fichier / Lieu                    | Temps estimé |
|-----|------------------------------------|------------|-----------------------------------|--------------|
| B7.1 | Sons (collecte, craft, achat, mort, porte) | Aucune | SoundHelper, ReplicatedStorage/Assets/Sounds | 2h   |
| B7.2 | Particules et effets visuels       | Aucune     | UIController, EconomyController    | 1h30         |
| B7.3 | UI responsive                      | Aucune     | MainHUD, ShopUI, CodexUI           | 1h30         |
| B7.4 | Tutoriel basique                   | B7.1–B7.3  | TutorialUI, ClientMain            | 2h           |

**Total DEV B :** ~7h

---

# DEV A - ROBUSTESSE & TESTS

## A7.1 - Gestion erreurs complète

### Description

S'assurer que toutes les opérations critiques sont protégées par `pcall` et que les messages d'erreur sont clairs pour le debug.

### Zones à couvrir

1. **DataService** : LoadPlayerData, SavePlayerData, GetAsync, SetAsync
2. **NetworkHandler** : Chaque handler RemoteEvent (éviter les crashes si un System échoue)
3. **CraftingSystem** : TryCraft (validation des pièces, placement)
4. **EconomySystem** : AddCash, RemoveCash, BuyNextSlot
5. **InventorySystem** : TryPickupPiece (pièce disparue entre-temps)
6. **PlacementSystem** : PlaceBrainrot (slot invalide, modèle manquant)

### Exemple (NetworkHandler)

```lua
remotes.Craft.OnServerEvent:Connect(function(player)
    local ok, err = pcall(function()
        local result, brainrotData = CraftingSystem:TryCraft(player)
        if result == Constants.ActionResult.Success then
            remotes.Notification:FireClient(player, {
                Type = "Success",
                Message = "Brainrot crafted: " .. brainrotData.Name
            })
        else
            remotes.Notification:FireClient(player, {
                Type = "Error",
                Message = result
            })
        end
    end)
    if not ok then
        warn("[NetworkHandler] Craft error for " .. player.Name .. ": " .. tostring(err))
        remotes.Notification:FireClient(player, {
            Type = "Error",
            Message = "Une erreur s'est produite. Réessayez."
        })
    end
end)
```

### Checklist

- [ ] DataStore : pcall sur GetAsync/SetAsync, retry logic déjà en place
- [ ] Tous les handlers RemoteEvent dans un pcall
- [ ] Messages d'erreur utilisateur génériques (pas d'exposition technique)
- [ ] warn() avec contexte (nom joueur, action) pour le debug

---

## A7.2 - Logs et debug structurés

### Description

Uniformiser les logs avec un préfixe `[ModuleName]` et un niveau (info, warn, error) pour faciliter le debug.

### Convention

```lua
print("[GameServer] Système X initialisé")
warn("[DataService] Tentative " .. attempt .. " échouée pour " .. player.Name)
warn("[CraftingSystem] Pièce invalide: " .. tostring(piece))
```

### Checklist

- [ ] Tous les modules utilisent le préfixe `[NomModule]`
- [ ] Les erreurs utilisent `warn()` (pas `print()`)
- [ ] Les infos de démarrage utilisent `print()`
- [ ] Pas de `print` de debug oubliés en production

---

## A7.3 - Tests multi-joueurs

### Description

Tester le jeu avec 2 à 4 joueurs simultanés pour détecter les race conditions et les conflits.

### Scénarios à tester

1. **Deux joueurs rejoignent en même temps** : Chacun reçoit une base différente
2. **Deux joueurs ramassent la même pièce** : Un seul réussit, l'autre reçoit une notification d'erreur
3. **Un joueur achète un slot pendant qu'un autre craft** : Pas de conflit sur les données
4. **Un joueur se déconnecte pendant un craft** : Pas de crash, données cohérentes
5. **Portes** : Joueur A ferme sa porte, Joueur B ne peut pas traverser
6. **Bases** : Chaque joueur ne voit que ses propres Brainrots et son argent

### Configuration Studio

- **Test** → **Players** → **2 Players** (ou 4 Players)
- Lancer plusieurs sessions de 5–10 minutes

### Checklist

- [ ] Aucune base assignée deux fois
- [ ] Aucune pièce ramassée deux fois
- [ ] Déconnexion propre (base libérée, données sauvegardées)
- [ ] Pas d'erreurs dans l'Output

---

## A7.4 - Équilibrage

### Description

Ajuster les valeurs de GameConfig et SlotPrices pour un gameplay équilibré.

### Paramètres à revoir

| Paramètre | Fichier | Description |
|-----------|---------|-------------|
| StartingCash | GameConfig.Economy | Argent de départ |
| RevenuePerBrainrot | GameConfig.Economy | $ par tick par Brainrot |
| RevenueTickRate | GameConfig.Economy | Intervalle en secondes |
| SpawnInterval | GameConfig.Arena | Temps entre chaque spawn de pièce |
| MaxPiecesInArena | GameConfig.Arena | Limite de pièces |
| SlotPrices | SlotPrices.module | Prix des slots 1–30 |

### Méthodologie

1. Jouer une partie complète (30 min)
2. Noter : temps pour premier craft, premier slot acheté, sentiment de progression
3. Ajuster et re-tester

### Checklist

- [ ] Premier craft atteignable en 5–10 min
- [ ] Progression des slots ni trop rapide ni trop lente
- [ ] Revenus des Brainrots significatifs mais pas excessifs

---

# DEV B - POLISH VISUEL

## B7.1 - Sons

### Description

Ajouter des sons pour les actions clés du jeu.

### Sons à implémenter

| Action | Son | Emplacement |
|--------|-----|-------------|
| Collecte d'argent (CollectPad) | CashCollect | ClientMain (déjà branché si SoundHelper) |
| Achat de slot | SlotBuy | ClientMain (déjà branché) |
| Erreur "pas assez d'argent" | NotEnoughMoney | ClientMain (déjà branché) |
| Craft réussi | CraftSuccess | ClientMain → Notification Success + "craft" |
| Mort au Spinner | DeathSound | ArenaController ou Notification Warning |
| Porte fermée | DoorClose | DoorController |
| Porte ouverte | DoorOpen | DoorController |
| Pickup pièce | PickupSound | ArenaController |

### Structure ReplicatedStorage/Assets/Sounds

```
ReplicatedStorage/
└── Assets/
    └── Sounds/
        ├── CashCollect (Sound)
        ├── SlotBuy (Sound)
        ├── NotEnoughMoney (Sound)
        ├── CraftSuccess (Sound)
        ├── Death (Sound)
        ├── DoorClose (Sound)
        ├── DoorOpen (Sound)
        └── Pickup (Sound)
```

### SoundHelper.module.lua

Vérifier que SoundHelper existe et expose `SoundHelper.Play(soundName)`.

```lua
-- Exemple d'appel
if SoundHelper then
    SoundHelper.Play("CraftSuccess")
end
```

### Checklist

- [ ] Tous les sons créés dans ReplicatedStorage/Assets/Sounds
- [ ] SoundHelper.Play() appelé aux bons endroits
- [ ] Volume et durée raisonnables (pas de spam)

---

## B7.2 - Particules et effets visuels

### Description

Renforcer le feedback visuel avec des particules et animations.

### Zones à améliorer

1. **Collecte d'argent** : Particules de pièces ou d'étoiles au-dessus du CollectPad
2. **Craft réussi** : Flash ou particules autour du joueur
3. **Achat de slot** : Effet sur le SlotShop ou notification
4. **Pickup pièce** : Légère animation sur la pièce avant disparition
5. **Mort au Spinner** : Effet de mort (optionnel)

### Implémentation

- Utiliser `Instance.new("ParticleEmitter")` sur les Parts concernées
- Ou créer des effets temporaires avec `TweenService`
- Les particules peuvent être pré-placées dans Studio (CollectPad, SlotShop) et activées/désactivées en script

### Checklist

- [ ] Collecte : effet visible
- [ ] Craft : feedback satisfaisant
- [ ] Pas de particules excessives (performance)

---

## B7.3 - UI responsive

### Description

S'assurer que l'UI s'adapte aux différentes résolutions (16:9, 4:3, mobile).

### Éléments à vérifier

1. **MainHUD** : Position des éléments (Cash, Inventaire, Boutons) avec UDim2 Scale
2. **ShopUI** : Taille relative, pas de débordement sur petit écran
3. **CodexUI** : ScrollFrame fonctionne, pas de texte coupé
4. **NotificationUI** : Centré, lisible sur toutes les résolutions

### Bonnes pratiques

- Utiliser `Scale` (0–1) plutôt que `Offset` en pixels pour les tailles principales
- `AnchorPoint` pour le positionnement (0.5, 0.5 = centre)
- Tester en changeant la résolution dans Studio : **File** → **Game Settings** → **Display**

### Checklist

- [ ] MainHUD visible et utilisable en 1920x1080 et 1280x720
- [ ] ShopUI et CodexUI ne débordent pas
- [ ] TextSize adapté (minimum 12 pour la lisibilité)

---

## B7.4 - Tutoriel basique

### Description

Créer un écran ou des indications pour guider les nouveaux joueurs.

### Contenu suggéré

1. **Écran de bienvenue** (première connexion uniquement)
   - "Bienvenue ! Récupère des pièces dans l'arène, craft des Brainrots et génère des revenus."
   - Bouton "Compris" pour fermer

2. **Indications contextuelles** (optionnel)
   - Flèche ou texte près du SlotShop : "Achète des slots ici"
   - Indication près de l'arène : "Ramasse des pièces (E)"

### Implémentation

- **TutorialUI** : ScreenGui dans StarterGui, désactivé par défaut
- **FirstTime** : Stocker dans PlayerData (ex. `HasSeenTutorial = true`) pour ne pas réafficher
- Afficher au premier Join si `HasSeenTutorial == false`

### Structure TutorialUI

```
TutorialUI (ScreenGui, Enabled = false)
└── Background (Frame)
    ├── Title (TextLabel) - "Bienvenue !"
    ├── Message (TextLabel) - Texte d'introduction
    └── GotItButton (TextButton) - "Compris"
```

### Checklist

- [ ] TutorialUI créé dans StarterGui
- [ ] Affiché une seule fois (HasSeenTutorial dans PlayerData)
- [ ] Bouton ferme l'UI et met HasSeenTutorial = true
- [ ] DataService : sauvegarder HasSeenTutorial

---

# SYNC 7 - Test End-to-End

## Checklist de validation

### Stabilité
- [ ] Pas de bugs bloquants
- [ ] Pas de crash en 10 minutes de jeu
- [ ] Déconnexion/reconnexion : données conservées

### Sons
- [ ] Collecte : son joué
- [ ] Craft : son joué
- [ ] Achat slot : son joué
- [ ] Erreur argent : son joué
- [ ] Porte : sons fermeture/ouverture (optionnel)

### Visuel
- [ ] Particules ou effets sur les actions clés
- [ ] UI lisible sur différentes résolutions

### Multi-joueurs
- [ ] 2–4 joueurs : pas de conflit
- [ ] Chacun a sa base, son argent, ses Brainrots

### Tutoriel
- [ ] Nouveau joueur voit le tutoriel
- [ ] Ancien joueur ne le revoit pas

---

# Récapitulatif des fichiers

| Rôle | Fichier / Lieu | Action |
|------|----------------|--------|
| DEV A | Tous les modules serveur | Ajouter pcall, logs structurés |
| DEV A | GameConfig.module.lua | Ajuster équilibrage |
| DEV A | SlotPrices.module.lua | Ajuster prix (optionnel) |
| DEV B | ReplicatedStorage/Assets/Sounds | Créer sons |
| DEV B | SoundHelper.module.lua | Vérifier/étendre |
| DEV B | ClientMain, EconomyController, DoorController | Brancher sons |
| DEV B | UIController, EconomyController | Particules |
| DEV B | MainHUD, ShopUI, CodexUI | Vérifier responsive |
| DEV B | TutorialUI (Studio) | Créer |
| DEV B | DataService, DefaultPlayerData | HasSeenTutorial |

---

# Références rapides

- **SoundHelper** : `SoundHelper.Play("SoundName")` si le module existe
- **GameConfig** : Economy, Arena, Base, Door
- **DefaultPlayerData** : Structure pour HasSeenTutorial
- **pcall** : `local ok, err = pcall(function() ... end)`

---

**Fin du Guide Phase 7**
