# 📊 Phase 6.5 - Status Report

**Date:** 2026-02-05  
**Phase:** 6.5 - Vol de Brainrot & Combat  
**Status:** ⏳ À faire (Phase 6 complétée)

---

## 📋 Vue d'ensemble

| Rôle | Scope | Statut |
|------|--------|--------|
| **DEV A** | StealSystem, CombatSystem, Handlers, PlacementSystem | ⏳ |
| **DEV B** | StealController, Brainrot en main, Batte, UI progression | ⏳ |

---

## ⏳ DEV A - Backend Vol & Combat

### Fichiers

| Fichier | Type | Statut |
|---------|------|--------|
| `Systems/StealSystem.module.lua` | ModuleScript | ⏳ |
| `Systems/CombatSystem.module.lua` | ModuleScript | ⏳ |
| `Handlers/NetworkHandler.module.lua` | Modifié | ⏳ |
| `Systems/PlacementSystem.module.lua` | Modifié | ⏳ |
| `Core/GameServer.server.lua` | Modifié | ⏳ |
| `Constants.module.lua` | Modifié | ⏳ |
| `GameConfig.module.lua` | Modifié | ⏳ |

### Tâches

- [ ] A6.5.1 StealSystem (TryStartSteal, CompleteSteal, CancelSteal, OnThiefHit, ReturnStolenBrainrot)
- [ ] A6.5.2 CombatSystem (batte, détection coup, GiveBatToPlayer)
- [ ] A6.5.3 Handlers réseau (StartSteal, CancelSteal, PlaceStolenBrainrot)
- [ ] A6.5.4 Intégration hit → annulation vol / retour Brainrot
- [ ] A6.5.5 GameConfig (Steal.HoldDuration, Combat.BatCooldown, etc.)

---

## ⏳ DEV B - Frontend Vol & Combat

### Fichiers / Studio

| Élément | Type | Statut |
|---------|------|--------|
| `StealController.module.lua` | ModuleScript | ⏳ |
| StealProgressUI (barre hold E) | ScreenGui | ⏳ |
| Brainrot en main (visuel 3D) | Attaché à Character | ⏳ |
| BaseballBat (Tool) | StarterPack / ReplicatedStorage | ⏳ |
| ProximityPrompts sur slots (autres bases) | Studio | ⏳ |
| Zone placement Brainrot volé (sa base) | Studio | ⏳ |

### Tâches

- [ ] B6.5.1 StealController (hold E, StartSteal, CancelSteal, barre progression)
- [ ] B6.5.2 Brainrot visuel en main (clone, weld sur RightHand)
- [ ] B6.5.3 Batte de baseball (Tool, Touched/Activated)
- [ ] B6.5.4 Placement Brainrot volé (ProximityPrompt dans sa base)
- [ ] B6.5.5 Notifications et feedback (vol réussi, annulé, frappé)

---

## 🔄 SYNC 6.5 – Checklist

- [ ] Maintenir E près d'un slot (autre base) démarre le vol
- [ ] Barre de progression pendant le hold
- [ ] Vol complété : Brainrot en main, disparaît du slot victime
- [ ] Relâcher E annule le vol
- [ ] Être frappé pendant le vol → annulation
- [ ] Être frappé en portant le Brainrot → chute, Brainrot retourne au slot
- [ ] Poser le Brainrot dans sa base fonctionne
- [ ] Tous les joueurs ont une batte
- [ ] La batte frappe et interrompt le voleur

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| `PHASE_6.5_GUIDE.md` | Guide détaillé Phase 6.5 (DEV A & B) |
| `PHASE_6.5_STATUS.md` | Ce fichier – suivi d'avancement |

---

**Dernière mise à jour:** 2026-02-05
