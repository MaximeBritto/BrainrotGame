# PHASE 8 : QUICKSTART - Démarrage Rapide

**Guide complet :** [PHASE_8_GUIDE.md](PHASE_8_GUIDE.md)

⚠️ **VERSION ULTRA-SIMPLIFIÉE** : ProximityPrompt natif + ragdoll naturel (pas d'UI custom)

---

## 🎯 Objectif

Ajouter le système de **vol de Brainrot** et de **combat à la batte**.

---

## 📦 Résumé

### Vol de Brainrot
1. S'approcher d'un Brainrot placé dans le slot d'un autre joueur
2. **ProximityPrompt natif** s'affiche : "Hold E - Voler Brainrot"
3. Maintenir **E** pendant 3 secondes (barre circulaire automatique)
4. Le Brainrot volé va dans l'inventaire
5. Retourner à sa base et le placer dans un slot libre

### Combat
1. Chaque joueur spawn avec une **batte**
2. Cliquer pour frapper un joueur (< 10 studs)
3. Joueur **tombe au sol** (ragdoll) pendant 5 secondes
4. Joueur **se relève automatiquement** après 5 secondes
5. Si le joueur assommé transporte un Brainrot volé, il le perd

---

## 🚀 Ordre d'Implémentation

### PHASE 1 : Backend (~2h) ✅ FAIT

```
1. Créer StealSystem.module.lua (version simplifiée)
   └─ ServerScriptService/Systems/StealSystem
   └─ Plus de tracking temporel, juste validation

2. Créer BatSystem.module.lua
   └─ ServerScriptService/Systems/BatSystem

3. Modifier PlacementSystem.module.lua ⚠️ CRITIQUE
   └─ Créer ProximityPrompt sur chaque Brainrot placé

4. Modifier NetworkSetup.module.lua
   └─ Ajouter 3 nouveaux RemoteEvents (au lieu de 5)

5. Modifier NetworkHandler.module.lua
   └─ Ajouter 2 handlers (vol et combat)

6. Modifier GameServer.server.lua
   └─ Init StealSystem et BatSystem

7. Modifier GameConfig.module.lua
   └─ Ajouter paramètres (durées, distances)
```

### PHASE 2 : Client (~1h) 🟡 EN COURS

```
1. Créer StealController.client.lua (~15min) ✅ FAIT
   └─ StarterPlayer/StarterPlayerScripts/Controllers/StealController
   └─ Ultra-simplifié : écoute ProximityPromptService (~30 lignes)

2. Créer la batte (Tool) (~30min) 🟡 EN COURS
   └─ Toolbox → Chercher "bat" → Placer dans ServerStorage
   └─ Ajouter BatScript au Tool

3. ~~BatController.client.lua~~ ❌ SUPPRIMÉ
   └─ Pas d'effets visuels nécessaires

4. ~~Créer UI StealProgressBar~~ ❌ SUPPRIMÉ
   └─ Remplacé par ProximityPrompt natif !

5. ~~Créer UI StunEffect~~ ❌ SUPPRIMÉ
   └─ Remplacé par ragdoll naturel de Roblox !
```

### PHASE 3 : Tests (30min-1h) ⬜ À FAIRE

```
1. Tester avec 2 joueurs minimum
   └─ Test → Players → 2 joueurs

2. Vérifier :
   ✅ ProximityPrompt s'affiche sur Brainrots placés
   ✅ Hold E pendant 3s vole le Brainrot
   ✅ Barre de progression circulaire native s'affiche
   ✅ Batte fait tomber le joueur au sol (ragdoll)
   ✅ Joueur se relève automatiquement après 5s
   ✅ Validations serveur fonctionnent
```

---

## 🎨 UI à Créer

### ~~StealProgressBar~~ ❌ SUPPRIMÉ

**Plus nécessaire !** Le ProximityPrompt natif gère automatiquement :
- Affichage "Hold E"
- Barre de progression circulaire
- Texte d'action et d'objet
- Compatible PC, mobile, console

### ~~StunEffect~~ ❌ SUPPRIMÉ

**Plus nécessaire !** Le ragdoll naturel de Roblox gère automatiquement :
- Le personnage **tombe au sol** visuellement
- Indication claire que le joueur est assommé
- Se relève automatiquement après la durée
- Pas besoin d'UI supplémentaire
- Notification simple via système existant

---

## 🔑 RemoteEvents à Ajouter

Ajouter dans `NetworkSetup.module.lua` :

```lua
"StealBrainrot",    -- Vol complété (après hold E 3s)
"BatHit",           -- Frappe avec la batte
"SyncStunState",    -- Sync état d'assommage
```

⚠️ **SIMPLIFICATION** : Seulement 3 RemoteEvents au lieu de 5 !

---

## 🐛 Debug Rapide

### Pas de logs dans Output ?
- Vérifier que GameServer.server.lua a bien les `Init()` des nouveaux systèmes

### Batte ne frappe pas ?
- Distance : moins de 10 studs
- Cooldown : 1 seconde entre chaque frappe
- Vérifier que BatHit RemoteEvent existe

### ProximityPrompt ne s'affiche pas ?
- Vérifier que PlacementSystem crée le ProximityPrompt (voir A8.3)
- Inspecter un Brainrot placé dans le Workspace
- Vérifier que le ProximityPrompt a les Attributes OwnerId et SlotId

### Joueur ne peut plus bouger après stun ?
- Vérifier que BatSystem:_RemoveStun() est appelé
- Vérifier que `humanoid.PlatformStand = false` est exécuté
- Attendre 5 secondes complètes
- En cas de problème, utiliser la console pour réinitialiser:
  ```lua
  local h = game.Players.LocalPlayer.Character.Humanoid
  h.PlatformStand = false
  h.WalkSpeed = 16
  h.JumpPower = 50
  ```

---

## 📊 Temps Estimé

| Phase | Temps Original | Temps Ultra-Simplifié |
|-------|----------------|-----------------------|
| Backend | 2-3h | ~2h ✅ |
| Client | 2-3h | ~45min 🟡 |
| Tests | 30min-1h | 30min |
| **TOTAL** | **5-7h** | **~3h** ✅ |

⚠️ **GAIN DE TEMPS** : Version ultra-simplifiée = 50%+ plus rapide !
- Pas de barre de progression custom
- Pas d'UI de stun custom
- Pas de BatController client

---

## 💡 Conseils

1. **Commencer par le backend** (serveur toujours en premier) ✅ Fait !
2. **PlacementSystem est CRITIQUE** : doit créer ProximityPrompt sur chaque Brainrot
3. **Utiliser l'Output** pour debug (logs détaillés)
4. **Tester en multi-joueurs** (Test → Players → 2)
5. **Ajuster les paramètres** dans GameConfig selon vos tests
6. **ProximityPrompt** : Modifier HoldDuration et MaxActivationDistance pour personnaliser

---

## 📖 Documentation Complète

Pour le code complet et les explications détaillées, voir :
- **[PHASE_8_GUIDE.md](PHASE_8_GUIDE.md)** - Guide complet avec tout le code
- **[PHASE_8_STATUS.md](PHASE_8_STATUS.md)** - Tracker de progression

---

**Bon développement ! 🚀**
