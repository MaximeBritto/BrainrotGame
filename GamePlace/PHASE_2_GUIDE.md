# 🏠 PHASE 2 : BASES & PORTES - Guide Complet

**Objectif:** Chaque joueur a sa base personnelle avec une porte sécurisée

---

## 📋 Vue d'Ensemble

### Ce qu'on va créer

**Backend (DEV A):**
- BaseSystem - Assignation et gestion des bases
- DoorSystem - Gestion des portes sécurisées

**Frontend (DEV B):**
- Setup des bases dans Workspace (Studio)
- BaseController - Interactions avec la base
- DoorController - Interactions avec la porte

**Temps estimé:** 6-8 heures

---

## 🎯 Fonctionnalités Phase 2

✅ **Assignation automatique** - Chaque joueur reçoit une base libre  
✅ **Téléportation** - Le joueur spawn à sa base  
✅ **Porte sécurisée** - Fermeture pendant 30 secondes  
✅ **Collision intelligente** - Propriétaire peut toujours passer  
✅ **Déblocage d'étages** - À 11 et 21 slots  
✅ **Placement Brainrots** - Sur les slots de la base  

---

## 📐 Architecture des Bases

### Structure Workspace

```
Workspace/Bases/
├── Base_1/
│   ├── SpawnPoint (Part)
│   ├── Door/
│   │   ├── Bars (Model)
│   │   └── ActivationPad (Part)
│   ├── Slots/ (Folder avec Slot_1 à Slot_30)
│   ├── SlotShop/
│   └── Floors/ (Floor_0, Floor_1, Floor_2)
├── Base_2/
└── ... (jusqu'à Base_8)
```

### Propriétés Importantes

**SpawnPoint:**
- Transparency = 1 (invisible)
- CanCollide = false
- Anchored = true

**Door/Bars:**
- CanCollide = false (par défaut, ouvert)
- Transparency = 0.5
- CollisionGroup = "DoorBars"

**ActivationPad:**
- CanCollide = true
- Touched event pour activer

---

