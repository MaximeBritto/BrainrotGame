# PHASE 6.5 : VOL DE BRAINROT & COMBAT - Guide Complet et Détaillé

**Date:** 2026-02-05  
**Status:** À faire (Phase 6 complétée)  
**Prérequis:** Phases 0, 1, 2, 3, 4, 5, 5.5 et 6 complétées (SYNC 6 validé)

---

## Vue d'ensemble

La Phase 6.5 ajoute le **vol de Brainrots** entre joueurs et un **système de combat** à la batte de baseball :
- **DEV A** : StealSystem, CombatSystem (batte), handlers réseau, logique serveur
- **DEV B** : UI vol (barre de progression E), Brainrot en main, batte 3D, feedback visuel

### Objectif final de la Phase 6.5

- Un joueur peut **voler un Brainrot** à un autre joueur en **maintenant E** pendant X secondes près du slot
- Pendant le vol, une **barre de progression** s'affiche
- Une fois volé, le joueur a le **Brainrot visuellement dans la main** et doit **retourner à sa base** pour le poser
- Tous les joueurs ont une **batte de baseball** (arme)
- Si un joueur **te frappe avec la batte** pendant que tu voles ou que tu portes un Brainrot volé : tu tombes, le Brainrot **retourne sur le slot** d'où tu l'as volé

---

## Résumé des tâches

### DEV A - Backend Vol & Combat

| #   | Tâche                              | Dépendance | Fichier                                      | Temps estimé |
|-----|------------------------------------|------------|----------------------------------------------|--------------|
| A6.5.1 | StealSystem (TryStartSteal, CompleteSteal, CancelSteal) | Aucune | Systems/StealSystem.module.lua | 3h |
| A6.5.2 | CombatSystem (batte, détection coup) | Aucune | Systems/CombatSystem.module.lua | 2h |
| A6.5.3 | Handlers réseau (StartSteal, CancelSteal, PlaceStolenBrainrot) | A6.5.1 | NetworkHandler | 1h |
| A6.5.4 | Intégration hit → annulation vol / retour Brainrot | A6.5.1, A6.5.2 | StealSystem + CombatSystem | 1h30 |
| A6.5.5 | GameServer, Constants, GameConfig | A6.5.1 | Modifications | 30min |

**Total DEV A :** ~8h

### DEV B - Frontend Vol & Combat

| #   | Tâche                              | Dépendance | Fichier / Lieu                    | Temps estimé |
|-----|------------------------------------|------------|-----------------------------------|--------------|
| B6.5.1 | StealController (hold E, barre progression) | Aucune | StealController.module.lua | 2h |
| B6.5.2 | Brainrot en main (visuel 3D) | B6.5.1 | StealController / StolenBrainrotVisual | 1h30 |
| B6.5.3 | Batte de baseball (Tool) | Aucune | StarterPack / ReplicatedStorage | 1h |
| B6.5.4 | Placement Brainrot volé (ProximityPrompt slot) | B6.5.1 | StealController + base | 1h |
| B6.5.5 | Sync et feedback (notifications, animations) | B6.5.1 | ClientMain, UIController | 1h |

**Total DEV B :** ~6h30

---

# Spécifications détaillées

## Flux de vol

```
1. Joueur A va dans la base de Joueur B
2. Joueur A s'approche d'un slot avec un Brainrot
3. Joueur A maintient E pendant X secondes (ex: 3s)
   → Barre de progression s'affiche
4a. Si complété : Brainrot retiré du slot de B, A le tient en main
4b. Si B (ou autre) frappe A avec la batte : annulation, Brainrot reste sur le slot
4c. Si A relâche E avant la fin : annulation
5. A retourne à SA base avec le Brainrot en main
6. A pose le Brainrot sur un de ses slots libres (ProximityPrompt ou zone)
7. Si A est frappé pendant le trajet (étapes 5-6) : Brainrot retourne sur le slot de B
```

## Flux combat (batte)

```
1. Tous les joueurs ont une batte de baseball (Tool)
2. Clic ou touche = coup
3. Si le coup touche un joueur qui :
   - est en train de voler (hold E en cours) → annule le vol
   - porte un Brainrot volé → fait tomber, Brainrot retourne au slot d'origine
4. Le joueur frappé subit une animation de chute (Ragdoll ou stun court)
```

---

# DEV A - BACKEND

## A6.5.1 - StealSystem.module.lua

### Responsabilités

- **TryStartSteal(player, targetOwnerUserId, targetSlotIndex)** : Démarre un vol. Valide : pas déjà en vol, pas déjà un Brainrot en main, slot valide, Brainrot présent.
- **CancelSteal(player)** : Annule le vol en cours (E relâché ou hit).
- **CompleteSteal(player)** : Termine le vol (timer écoulé). Retire le Brainrot du slot de la victime, met en état "porté" pour le voleur.
- **OnThiefHit(thief)** : Appelé par CombatSystem quand le voleur est frappé. Si vol en cours → CancelSteal. Si Brainrot porté → ReturnStolenBrainrot.
- **PlaceStolenBrainrot(player, slotIndex)** : Le voleur pose le Brainrot sur son slot. Valide : slot libre, dans sa base.
- **ReturnStolenBrainrot(thief)** : Remet le Brainrot sur le slot d'origine (chez la victime).

### État runtime (PlayerService ou StealSystem)

```lua
-- Par joueur (voleur)
StealInProgress = {
    targetOwnerUserId = 12345,
    targetSlotIndex = 2,
    targetBaseIndex = 1,  -- pour retrouver la base
    startTime = tick(),
}

StolenBrainrot = {
    brainrotData = {...},   -- données du Brainrot
    ownerUserId = 12345,    -- victime
    slotIndex = 2,          -- slot d'origine (pour retour)
    baseIndex = 1,          -- base d'origine
}
```

### Validations TryStartSteal

1. Le joueur n'est pas déjà en train de voler
2. Le joueur ne porte pas déjà un Brainrot volé
3. Le slot cible existe et contient un Brainrot
4. Le slot appartient à un autre joueur (pas sa propre base)
5. Le joueur est assez proche du slot (distance max, ex: 10 studs)

### Validations PlaceStolenBrainrot

1. Le joueur porte bien un Brainrot volé
2. Le joueur est dans SA base (pas celle d'un autre)
3. Le slot demandé est libre
4. Le slot est un slot possédé par le joueur

### Nouveaux Remotes

| Remote | Direction | Paramètres | Description |
|--------|-----------|------------|-------------|
| StartSteal | Client → Serveur | ownerUserId, slotIndex | Démarre le vol (E pressé) |
| CancelSteal | Client → Serveur | — | Annule (E relâché) |
| StealProgress | Serveur → Client | progress (0-1), slotIndex | Barre de progression |
| StealComplete | Serveur → Client | brainrotData | Vol réussi, afficher en main |
| StealCancelled | Serveur → Client | reason | Vol annulé |
| PlaceStolenBrainrot | Client → Serveur | slotIndex | Pose le Brainrot volé |
| StolenBrainrotReturned | Serveur → Client | — | Brainrot retourné (tu as été frappé) |

---

## A6.5.2 - CombatSystem.module.lua

### Responsabilités

- **OnPlayerHit(attacker, victim)** : Appelé quand la batte touche un joueur. Vérifie si victim est en train de voler ou porte un Brainrot → appelle StealSystem:OnThiefHit(victim).
- **GiveBatToPlayer(player)** : Donne la batte au joueur (à la connexion).

### Détection du coup

**Option 1 – Tool.Touched (recommandé)**  
- La batte est un **Tool** avec un **Handle** (Part).
- Sur `Handle.Touched`, vérifier si la Part touchée est dans un `Character` (Humanoid).
- Si oui, et que ce Character n'est pas celui du joueur qui tient la batte → `OnPlayerHit(attacker, victim)`.

**Option 2 – RemoteEvent (client autoritaire)**  
- Le client envoie `PlayerHit` (victimUserId) quand il "frappe".
- Le serveur valide la distance et la ligne de vue (raycast) pour éviter le cheat.

### Cooldown

- Un coup toutes les X secondes (ex: 1s) pour éviter le spam.

### Configuration GameConfig

```lua
-- À ajouter dans GameConfig.module.lua
Steal = {
    HoldDuration = 3,              -- Secondes pour maintenir E
    MaxDistance = 10,             -- Studs max du slot pour voler
    StealCooldown = 5,            -- Secondes avant de pouvoir revoler (optionnel)
},

Combat = {
    BatCooldown = 1,              -- Secondes entre deux coups
    StunDuration = 1.5,           -- Secondes de stun quand frappé
},
```

---

## A6.5.3 - NetworkHandler

### Handlers à ajouter

```lua
-- StartSteal : client envoie quand E est pressé
remotes.StartSteal.OnServerEvent:Connect(function(player, ownerUserId, slotIndex)
    local result = StealSystem:TryStartSteal(player, ownerUserId, slotIndex)
    if result ~= Constants.ActionResult.Success then
        remotes.Notification:FireClient(player, { Type = "Error", Message = result })
    end
end)

-- CancelSteal : client envoie quand E est relâché
remotes.CancelSteal.OnServerEvent:Connect(function(player)
    StealSystem:CancelSteal(player)
end)

-- PlaceStolenBrainrot : client envoie quand il pose dans sa base
remotes.PlaceStolenBrainrot.OnServerEvent:Connect(function(player, slotIndex)
    local result = PlacementSystem:PlaceStolenBrainrot(player, slotIndex)
    -- PlacementSystem doit déléguer à StealSystem ou gérer l'état StolenBrainrot
end)
```

### Intégration CombatSystem

- `CombatSystem` doit appeler `StealSystem:OnThiefHit(victim)` quand un joueur portant un Brainrot volé ou en train de voler est frappé.

---

## A6.5.4 - PlacementSystem extension

- **PlaceStolenBrainrot(player, slotIndex)** : Nouvelle fonction.
  - Vérifie que le joueur a `StolenBrainrot` en état.
  - Appelle la logique de placement (comme PlaceBrainrot) sur le slot du joueur.
  - Efface `StolenBrainrot` du joueur.
  - Sync SyncPlayerData aux deux joueurs (voleur et victime).

---

## A6.5.5 - Constants et GameConfig

### Constants.module.lua – à ajouter

```lua
ActionResult = {
    -- ... existants ...
    StealInProgress = "StealInProgress",
    AlreadyCarryingStolen = "AlreadyCarryingStolen",
    CannotStealOwnBase = "CannotStealOwnBase",
    SlotEmpty = "SlotEmpty",
    TooFarFromSlot = "TooFarFromSlot",
    NotInYourBase = "NotInYourBase",
},

RemoteNames = {
    -- ... existants ...
    StartSteal = "StartSteal",
    CancelSteal = "CancelSteal",
    StealProgress = "StealProgress",
    StealComplete = "StealComplete",
    StealCancelled = "StealCancelled",
    PlaceStolenBrainrot = "PlaceStolenBrainrot",
    StolenBrainrotReturned = "StolenBrainrotReturned",
},
```

---

# DEV B - FRONTEND

## B6.5.1 - StealController.module.lua

### Responsabilités

- Détecter la **proximité** d'un slot avec Brainrot (d'une autre base).
- Détecter **InputBegan** (E) et **InputEnded** (E relâché).
- Envoyer **StartSteal** quand E est pressé, **CancelSteal** quand E est relâché.
- Afficher une **barre de progression** pendant le hold.
- Écouter **StealComplete** → afficher le Brainrot en main.
- Écouter **StealCancelled** et **StolenBrainrotReturned** → masquer la barre / le Brainrot en main.

### Détection de proximité

- Utiliser des **ProximityPrompts** sur les slots (Platform ou CollectPad) des bases des autres joueurs.
- Ou : **raycast** / **distance** depuis le joueur vers les slots des autres bases.
- Le slot doit avoir un **Attribute** ou un **nom** permettant d'identifier `ownerUserId` et `slotIndex`.

### Barre de progression

- **StealProgressUI** : ScreenGui avec une Frame (barre) qui se remplit de 0 à 1 sur X secondes.
- Position : au centre ou au-dessus du joueur.
- Le serveur envoie **StealProgress** à intervalles (ex: 0.1s) avec le progress actuel, ou le client peut interpoler localement en attendant **StealComplete** / **StealCancelled**.

### Simplification possible

- Le client peut gérer la barre en local : au StartSteal, lancer un Tween de 3s. Si **StealComplete** arrive avant la fin → succès. Si **StealCancelled** ou **StolenBrainrotReturned** → annuler le Tween.

---

## B6.5.2 - Brainrot en main (visuel 3D)

### Description

- Quand **StealComplete** est reçu, créer un **modèle** du Brainrot et l’**attacher** à la main du personnage (RightHand ou LeftHand).
- Utiliser **WeldConstraint** ou **Weld** pour que le modèle suive la main.
- Le modèle peut être un clone du Brainrot (Head+Body+Legs) ou une version simplifiée.

### Implémentation

- **BrainrotModelSystem** ou **ReplicatedStorage/Assets/Brainrots** : récupérer le modèle correspondant aux données (HeadSet, BodySet, LegsSet).
- Cloner, positionner dans la main, welder.
- À **StolenBrainrotReturned** ou **PlaceStolenBrainrot** réussi : détruire le modèle.

---

## B6.5.3 - Batte de baseball (Tool)

### Structure Studio

- Créer un **Tool** nommé `BaseballBat`.
- **Handle** : Part (forme de batte ou mesh).
- **Grip** : CFrame pour la prise en main.
- Le Tool est dans **StarterPack** ou donné par **CombatSystem** à la connexion via `player.Backpack` ou `player.Character`.

### Script serveur (ou CombatSystem)

- À `PlayerService:OnPlayerJoined`, donner la batte :  
  `local bat = ReplicatedStorage.Assets.Tools.BaseballBat:Clone()`  
  `bat.Parent = player.Backpack`

### Détection du coup

- Sur le serveur, dans un script attaché au Tool ou dans CombatSystem :
  - `tool.Activated` ou `tool.Handle.Touched`
  - Si Touched : vérifier que c’est un Humanoid d’un autre joueur.
  - Appeler `CombatSystem:OnPlayerHit(attacker, victim)`.

---

## B6.5.4 - Placement du Brainrot volé

### Description

- Quand le joueur porte un Brainrot volé et entre dans **sa** base, il doit pouvoir le poser sur un slot.
- **ProximityPrompt** sur les slots de sa base (Platform ou CollectPad) : "Poser Brainrot (E)".
- Ou : zone dédiée "DropZone" dans sa base.
- Au déclenchement : envoyer **PlaceStolenBrainrot** avec le `slotIndex` du slot survolé.

### Identification du slot

- Chaque slot a un **Attribute** `SlotIndex` ou un nom `Slot_1`, `Slot_2`, etc.
- Le **ProximityPrompt** doit être sur un élément qui permet de récupérer le slotIndex (parent ou attribut).

---

## B6.5.5 - Sync et feedback

### Notifications

- Vol réussi : "Brainrot volé ! Retourne à ta base pour le poser."
- Vol annulé (frappé) : "Tu as été frappé ! Le Brainrot est retourné."
- Placement réussi : "Brainrot posé !"
- Erreur : "Tu dois être dans ta base pour poser."

### Animations (optionnel)

- **Stun** : quand frappé, désactiver les contrôles 1.5s ou jouer une animation de chute.
- **Porter** : animation de marche avec objet en main (si l’animation existe).

---

# Structure Workspace / Studio

## Slots des autres bases

- Pour que le client sache qu’un slot appartient à un autre joueur :
  - Chaque base a un **Attribute** `OwnerUserId`.
  - Chaque slot a un **Attribute** `SlotIndex`.
  - Le **StealController** peut parcourir les bases, ignorer celle du joueur local, et pour chaque slot avec un Brainrot afficher un ProximityPrompt "Voler (maintenir E)".

## ProximityPrompt sur les slots

- Sur **Platform** ou **CollectPad** de chaque slot :
  - **ActionText** : "Voler (maintenir E)"
  - **ObjectText** : nom du Brainrot (optionnel)
  - **HoldDuration** : 0 (on gère le hold manuellement côté client)
  - **RequiresLineOfSight** : false
  - Le prompt doit être **désactivé** pour le propriétaire du slot (vérifier OwnerUserId de la base).

---

# SYNC 6.5 – Checklist

- [ ] Maintenir E près d’un slot (autre base) démarre le vol
- [ ] Barre de progression s’affiche pendant le hold
- [ ] Vol complété : Brainrot disparaît du slot, apparaît en main du voleur
- [ ] Relâcher E annule le vol
- [ ] Être frappé pendant le vol annule le vol
- [ ] Être frappé en portant le Brainrot : chute, Brainrot retourne sur le slot
- [ ] Poser le Brainrot dans sa base fonctionne
- [ ] Tous les joueurs ont une batte
- [ ] La batte peut frapper les autres joueurs
- [ ] Pas de vol dans sa propre base

---

# Récapitulatif des fichiers

| Rôle | Fichier | Action |
|------|---------|--------|
| DEV A | `Systems/StealSystem.module.lua` | Créer |
| DEV A | `Systems/CombatSystem.module.lua` | Créer |
| DEV A | `Handlers/NetworkHandler.module.lua` | Modifier (nouveaux handlers) |
| DEV A | `Systems/PlacementSystem.module.lua` | Modifier (PlaceStolenBrainrot) |
| DEV A | `Core/GameServer.server.lua` | Modifier (init StealSystem, CombatSystem) |
| DEV A | `ReplicatedStorage/Shared/Constants.module.lua` | Modifier (Remotes, ActionResult) |
| DEV A | `ReplicatedStorage/Config/GameConfig.module.lua` | Modifier (Steal, Combat) |
| DEV B | `StarterPlayerScripts/StealController.module.lua` | Créer |
| DEV B | `StarterPlayerScripts/ClientMain.client.lua` | Modifier (StealController, Remotes) |
| DEV B | `ReplicatedStorage/Assets/Tools/BaseballBat` | Créer (Studio) |
| DEV B | StealProgressUI (ScreenGui) | Créer (Studio) |
| DEV B | ProximityPrompts sur slots (autres bases) | Créer (Studio) |

---

**Fin du Guide Phase 6.5**
