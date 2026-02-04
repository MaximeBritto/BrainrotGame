# 📊 Phase 6 - Status Report

**Date:** 2026-02-04  
**Phase:** 6 - Codex & Progression  
**Status:** ⏳ À faire (Phase 5.5 complétée)

---

## 📋 Vue d'ensemble

| Rôle | Scope | Statut |
|------|--------|--------|
| **DEV A** | SyncCodex à la connexion, après UnlockCodexEntry, optionnel CodexService | ⏳ |
| **DEV B** | CodexUI (Studio), CodexController, ClientMain, ouverture/affichage sets | ⏳ |

---

## ⏳ DEV A - Backend Codex & Sync

### Fichiers

| Fichier | Type | Statut |
|---------|------|--------|
| `Core/PlayerService.module.lua` | Modifié | ⏳ |
| `Core/DataService.module.lua` | Modifié | ⏳ |
| `Core/GameServer.server.lua` | Modifié (DataService:Init) | ⏳ |
| `Systems/CodexService.module.lua` | Optionnel | ⏳ |
| `Handlers/NetworkHandler.module.lua` | Vérification | ⏳ |

### Tâches

- [ ] A6.1 Envoi SyncCodex à la connexion (PlayerService)
- [ ] A6.2 Envoi SyncCodex après UnlockCodexEntry (DataService + Init NetworkSetup)
- [ ] A6.3 (Optionnel) CodexService
- [ ] A6.4 Vérification NetworkHandler

---

## ⏳ DEV B - Frontend Codex

### Fichiers / Studio

| Élément | Type | Statut |
|---------|------|--------|
| CodexUI (ScreenGui) | StarterGui | ⏳ |
| CodexController.module.lua | StarterPlayerScripts | ⏳ |
| ClientMain.client.lua | Modifié | ⏳ |
| MainHUD – bouton Codex (CodexButton) | StarterGui | ⏳ |

### Tâches

- [ ] B6.1 CodexUI ScreenGui (Studio)
- [ ] B6.2 CodexController.module.lua
- [ ] B6.3 Connexion ClientMain + SyncCodex
- [ ] B6.4 Bouton Codex dans MainHUD
- [ ] B6.5 Affichage sets (débloqués/verrouillés)
- [ ] B6.6 Polish (animations, couleurs rareté)

---

## 🔄 SYNC 6 – Checklist

- [ ] SyncCodex reçu à la connexion
- [ ] SyncCodex reçu après craft (déblocage set)
- [ ] Ouverture/fermeture Codex (bouton ou touche)
- [ ] Sets débloqués affichent nom + rareté
- [ ] Sets verrouillés affichent ??? / cadenas
- [ ] (Optionnel) Compteur X/Y et couleurs rareté

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| `PHASE_6_GUIDE.md` | Guide détaillé Phase 6 (DEV A & B) |
| `PHASE_6_STATUS.md` | Ce fichier – suivi d'avancement |

---

**Dernière mise à jour:** 2026-02-04
