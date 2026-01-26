# ⚡ Quick Start - Brainrot Assembly Chaos

## 🎯 Ce que vous devez faire (Checklist Rapide)

### ✅ Étape 1 : Vérifier les fichiers (2 min)

Assurez-vous d'avoir tous ces dossiers :
- [ ] `GamePlace/ReplicatedStorage/` (5 fichiers)
- [ ] `GamePlace/ServerScriptService/` (12 fichiers)
- [ ] `GamePlace/StarterPlayer/` (1 fichier)
- [ ] `GamePlace/StarterGui/` (3 fichiers)

### ✅ Étape 2 : Ouvrir Roblox Studio (1 min)

1. Lancez **Roblox Studio**
2. Créez un nouveau projet : **Baseplate**
3. Sauvegardez-le

### ✅ Étape 3 : Importer les scripts (15 min)

**ReplicatedStorage** (5 ModuleScripts) :
- [ ] GameConfig
- [ ] DataStructures
- [ ] NameFragments
- [ ] VFXSystem
- [ ] AudioSystem

**ServerScriptService** (12 scripts) :
- [ ] NetworkManager (Script)
- [ ] GameServer (Script)
- [ ] ArenaVisuals (Script)
- [ ] Arena (ModuleScript)
- [ ] CannonSystem (ModuleScript)
- [ ] CollectionSystem (ModuleScript)
- [ ] AssemblySystem (ModuleScript)
- [ ] CentralLaserSystem (ModuleScript)
- [ ] CombatSystem (ModuleScript)
- [ ] BaseProtectionSystem (ModuleScript)
- [ ] TheftSystem (ModuleScript)
- [ ] CodexSystem (ModuleScript)

**StarterPlayer/StarterPlayerScripts** (1 LocalScript) :
- [ ] PlayerController

**StarterGui** (3 LocalScripts) :
- [ ] CodexUI
- [ ] PlayerNameDisplay
- [ ] GameHUD

### ✅ Étape 4 : Créer l'arène (10 min)

1. **Sol** :
   - [ ] Part nommé `ArenaFloor`
   - [ ] Size : `100, 1, 100`
   - [ ] Position : `0, 0, 0`
   - [ ] Anchored : ✅

2. **Laser** :
   - [ ] Part nommé `CentralLaser`
   - [ ] Size : `50, 2, 2`
   - [ ] Position : `0, 5, 0`
   - [ ] Material : Neon
   - [ ] Color : Rouge
   - [ ] Anchored : ✅

### ✅ Étape 5 : Créer les cannons (15 min)

Créez 6 cannons autour de l'arène :
- [ ] Cannon1 à `(50, 5, 0)`
- [ ] Cannon2 à `(25, 5, 43.3)`
- [ ] Cannon3 à `(-25, 5, 43.3)`
- [ ] Cannon4 à `(-50, 5, 0)`
- [ ] Cannon5 à `(-25, 5, -43.3)`
- [ ] Cannon6 à `(25, 5, -43.3)`

Chaque cannon = Model avec :
- [ ] Base (Part 3×3×3)
- [ ] Barrel (Part 1×1×4)
- [ ] Orienté vers le centre

### ✅ Étape 6 : Créer les bases (20 min)

Créez 8 bases autour de l'arène :
- [ ] Base1 à `(35, 5, 0)`
- [ ] Base2 à `(24.7, 5, 24.7)`
- [ ] Base3 à `(0, 5, 35)`
- [ ] Base4 à `(-24.7, 5, 24.7)`
- [ ] Base5 à `(-35, 5, 0)`
- [ ] Base6 à `(-24.7, 5, -24.7)`
- [ ] Base7 à `(0, 5, -35)`
- [ ] Base8 à `(24.7, 5, -24.7)`

Chaque base = Folder avec :
- [ ] PressurePlate (Part 4×0.5×4, Neon vert)
- [ ] Pedestal1 (Part 2×3×2)
- [ ] Pedestal2 (Part 2×3×2)
- [ ] Pedestal3 (Part 2×3×2)

### ✅ Étape 7 : Créer les templates de parties (10 min)

Dans **ReplicatedStorage**, créez un Folder `BodyPartTemplates` :

- [ ] **HeadTemplate** (Model)
  - Part Ball 2×2×2, Neon cyan
  - PointLight cyan

- [ ] **BodyTemplate** (Model)
  - Part 2×3×1.5, Neon rose
  - PointLight rose

- [ ] **LegsTemplate** (Model)
  - Part 2×2×1, Neon jaune
  - PointLight jaune

### ✅ Étape 8 : Configurer l'éclairage (5 min)

Dans **Lighting** :
- [ ] Ajouter **Bloom** (Intensity: 0.5)
- [ ] Ajouter **ColorCorrection** (Saturation: 0.2)
- [ ] Brightness : `2`
- [ ] Ambient : `50, 50, 50`

### ✅ Étape 9 : Ajouter les sons (10 min)

Trouvez des Sound IDs sur Roblox et mettez-les dans `AudioSystem.lua` :
- [ ] completion (victoire)
- [ ] collection (pop)
- [ ] laserHit (zap)
- [ ] punchHit (pow)
- [ ] cannonFire (whoosh)
- [ ] barrierActivate (hum)
- [ ] theft (sneaky)

### ✅ Étape 10 : TESTER ! (5 min)

1. Cliquez sur **Play** (F5)
2. Vérifiez l'Output :
   ```
   ✓ Network Manager initialized
   ✓ Arena boundary created
   ✓ Initialized 6 cannons
   🎮 Server Initialized
   🚀 Match started!
   ```

3. Testez :
   - [ ] Les murs apparaissent
   - [ ] Le laser tourne
   - [ ] Les parties spawent
   - [ ] Vous pouvez collecter
   - [ ] L'assemblage fonctionne
   - [ ] Le HUD s'affiche

### ✅ Étape 11 : Test multijoueur (5 min)

1. **Test** > **Start Server and Players** (2-4 joueurs)
2. Testez :
   - [ ] Chaque joueur a sa base
   - [ ] Le punch fonctionne
   - [ ] Les barrières marchent
   - [ ] Le vol fonctionne

---

## ⏱️ Temps Total Estimé

- Import scripts : **15 min**
- Arène : **10 min**
- Cannons : **15 min**
- Bases : **20 min**
- Templates : **10 min**
- Éclairage : **5 min**
- Sons : **10 min**
- Tests : **10 min**

**TOTAL : ~1h30**

---

## 🆘 Problèmes Courants

### Les scripts ne se chargent pas
→ Vérifiez que `NetworkManager` est bien un **Script** (pas ModuleScript)

### Les parties ne spawent pas
→ Vérifiez que les templates existent dans `ReplicatedStorage/BodyPartTemplates`

### Le laser ne tourne pas
→ Vérifiez que `CentralLaser` existe dans `Workspace` et est Anchored

### L'UI ne s'affiche pas
→ Vérifiez que les LocalScripts sont dans `StarterGui`

### Erreur "RemoteEvents not found"
→ `NetworkManager` doit se lancer en premier (il crée le dossier)

---

## 📖 Besoin de Plus de Détails ?

Consultez **ROBLOX_STUDIO_GUIDE.md** pour le guide complet avec captures d'écran et explications détaillées !

---

## ✅ Checklist Finale

Avant de publier :
- [ ] Tous les scripts importés
- [ ] Arène créée
- [ ] 6 cannons placés
- [ ] 8 bases créées
- [ ] Templates de parties créés
- [ ] Éclairage configuré
- [ ] Sons ajoutés
- [ ] Test solo réussi
- [ ] Test multijoueur réussi
- [ ] 60 FPS maintenu

---

**Prêt ? C'est parti ! 🚀**

Si vous suivez cette checklist, votre jeu sera opérationnel en ~1h30 !
