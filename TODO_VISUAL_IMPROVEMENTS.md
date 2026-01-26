# 🎨 Améliorations Visuelles à Faire

## État Actuel
✅ Les body parts spawent depuis les cannons
✅ Tu peux ramasser les parts (elles disparaissent)
✅ L'inventaire s'affiche dans l'UI
✅ Le laser tourne et détecte les collisions
✅ L'assemblage automatique fonctionne

## ❌ Problèmes à Corriger

### 1. Les modèles ne s'affichent PAS sur le personnage
**Problème** : Quand tu ramasses une part, elle disparaît mais tu ne la vois pas sur ton personnage.

**Solution** : Il faut attacher les modèles au personnage avec des Attachments/Welds.

**Fichiers à modifier** :
- `GamePlace/ServerScriptService/GameServer.server.lua` (callback de collection)
- Créer un nouveau système pour gérer l'affichage visuel des parts sur le joueur

### 2. Le laser ne tue PAS le joueur
**Problème** : Le laser applique juste un knockback, mais le joueur ne meurt pas.

**Solution** : Quand le laser touche le joueur, il faut :
- Tuer le joueur (Humanoid.Health = 0)
- Faire tomber toutes les pièces au sol
- Respawn le joueur à sa base

**Fichiers à modifier** :
- `GamePlace/ServerScriptService/GameServer.server.lua` (callback du laser)

### 3. Les pièces ne tombent PAS au sol visuellement
**Problème** : Quand le laser te touche, l'inventaire se vide mais les pièces ne réapparaissent pas au sol.

**Solution** : Il faut re-spawner les modèles physiques au sol quand le joueur perd ses pièces.

**Fichiers à modifier** :
- `GamePlace/ServerScriptService/GameServer.server.lua` (callback du laser)
- `GamePlace/ServerScriptService/CannonSystem.lua` (fonction pour spawner une part à une position donnée)

## 📝 Plan d'Action

### Étape 1 : Afficher les parts sur le personnage
1. Quand une part est ramassée, ne pas la détruire
2. L'attacher au personnage du joueur (au-dessus de la tête)
3. Empiler les parts verticalement

### Étape 2 : Faire tuer le joueur par le laser
1. Modifier le callback du laser pour tuer le joueur
2. Faire tomber les parts au sol avant la mort
3. Respawn le joueur à sa base

### Étape 3 : Faire tomber les parts visuellement
1. Détacher les parts du personnage
2. Les faire tomber au sol avec la physique
3. Les rendre ramassables à nouveau

## 🎯 Résultat Final Attendu

Quand tu ramasses des parts :
- Tu vois les modèles 3D s'empiler au-dessus de ta tête
- Chaque part a sa couleur (cyan, rose, jaune)
- Elles flottent/suivent ton personnage

Quand le laser te touche :
- Tu meurs instantanément
- Les parts tombent au sol autour de toi
- Tu respawn à ta base
- Les autres joueurs peuvent ramasser tes parts

## 🔧 Complexité Estimée

- **Affichage des parts** : Moyen (1-2 heures)
- **Laser qui tue** : Facile (30 minutes)
- **Parts qui tombent** : Moyen (1 heure)

**Total** : ~3 heures de développement
