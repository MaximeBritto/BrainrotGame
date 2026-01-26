# TODO: Système de Piédestaux

## Changements nécessaires

### 1. Modifier le système d'assemblage (GameServer.server.lua)
- [ ] Quand un slot est complet, NE PAS appeler `codexSystem:RecordDiscovery()`
- [ ] Quand un slot est complet, NE PAS détruire les pièces
- [ ] Garder le Brainrot assemblé visuellement sur le joueur
- [ ] Marquer le slot comme "assemblé mais pas validé"

### 2. Ajouter des BillboardGui pour afficher les noms
- [ ] Créer un BillboardGui au-dessus de chaque slot
- [ ] Afficher le nom complet du Brainrot quand assemblé
- [ ] Positionner: Slot 1 (gauche), Slot 2 (centre), Slot 3 (droite)

### 3. Créer le système de piédestal
- [ ] Nouveau fichier: `PedestalSystem.lua`
- [ ] Détecter les piédestaux dans la base du joueur
- [ ] Vérifier si un piédestal est vide ou occupé
- [ ] Système d'interaction (touche F) pour poser un Brainrot

### 4. Modifier le système de laser
- [ ] Quand laser touche un joueur avec Brainrots assemblés
- [ ] Désassembler chaque Brainrot en 3 pièces
- [ ] Faire tomber les pièces au sol (récupérables)
- [ ] Supprimer les BillboardGui

### 5. Intégrer avec le Codex
- [ ] Enregistrer dans le Codex SEULEMENT quand posé sur piédestal
- [ ] Donner le point SEULEMENT à ce moment
- [ ] Afficher le Brainrot sur le piédestal

## Ordre d'implémentation

1. D'abord: Modifier l'assemblage pour ne pas auto-valider
2. Ensuite: Ajouter les BillboardGui pour voir les noms
3. Puis: Créer le système de piédestal
4. Enfin: Modifier le laser pour désassembler

## Notes
- Les piédestaux sont déjà créés dans Roblox Studio (voir ROBLOX_STUDIO_GUIDE.md)
- Chaque base a 3 piédestaux (Pedestal1, Pedestal2, Pedestal3)
- Format: `PlayerBases/Base1/Pedestal1`
