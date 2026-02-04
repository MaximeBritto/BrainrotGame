# 🎨 Phase 5.5 - Guide Studio : Création des Modèles 3D

**Date:** 2026-02-04  
**Objectif:** Créer les modèles 3D de Brainrots et de pièces individuelles dans Roblox Studio

---

## 📦 Structure à créer dans ReplicatedStorage

```
ReplicatedStorage/Assets/BodyPartTemplates/
├── HeadTemplate/
│   ├── brrbrr (Model)
│   │   ├── root.0.1 (MeshPart) [PrimaryPart]
│   │   │   └── BottomAttachment (Attachment)
│   │   ├── root.0.2 (MeshPart)
│   │   │   └── WeldConstraint → root.0.1
│   │   └── ... (autres parts soudées)
│   ├── lalelo (Model)
│   └── ... (autres heads)
│
├── BodyTemplate/
│   ├── lalero (Model)
│   │   ├── root.0.1 (MeshPart) [PrimaryPart]
│   │   │   ├── TopAttachment (Attachment)
│   │   │   └── BottomAttachment (Attachment)
│   │   ├── root.0.2 (MeshPart)
│   │   │   └── WeldConstraint → root.0.1
│   │   └── ... (autres parts soudées)
│   ├── pata (Model)
│   └── ... (autres bodies)
│
└── LegsTemplate/
    ├── patapim (Model)
    │   ├── root.0.1 (MeshPart) [PrimaryPart]
    │   │   └── TopAttachment (Attachment)
    │   ├── root.0.2 (MeshPart)
    │   │   └── WeldConstraint → root.0.1
    │   └── ... (autres parts soudées)
    ├── tralala (Model)
    └── ... (autres legs)
```

**Note:** Les Brainrots sont assemblés dynamiquement via Attachments!
Le système connecte automatiquement Head.BottomAttachment → Body.TopAttachment → Body.BottomAttachment → Legs.TopAttachment

---

## 🔧 Étape 1 : Vérifier la structure existante

D'après tes screenshots, tu as déjà:
- ✅ `BodyPartTemplates` folder
- ✅ `HeadTemplate`, `BodyTemplate`, `LegsTemplate` folders
- ✅ Models avec noms (brrbrr, lalero, patapim)
- ✅ PrimaryParts (root.0.1)
- ✅ WeldConstraints pour souder les parts
- ✅ TopAttachment dans les legs

**Il te manque juste 3 Attachments:**

---

## 🔗 Étape 2 : Ajouter les Attachments manquants

### 2.1 Head - Ajouter BottomAttachment

Pour chaque Model dans `HeadTemplate` (brrbrr, lalelo, etc.):

1. Sélectionner le **PrimaryPart** (root.0.1)
2. Clic droit → Insert Object → **Attachment**
3. Renommer en `BottomAttachment`
4. Position: `(0, -Size.Y/2, 0)` - En bas du head

### 2.2 Body - Ajouter TopAttachment

Pour chaque Model dans `BodyTemplate` (lalero, pata, etc.):

1. Sélectionner le **PrimaryPart** (root.0.1)
2. Clic droit → Insert Object → **Attachment**
3. Renommer en `TopAttachment`
4. Position: `(0, Size.Y/2, 0)` - En haut du body

### 2.3 Body - Ajouter BottomAttachment

Pour le même PrimaryPart:

1. Clic droit → Insert Object → **Attachment**
2. Renommer en `BottomAttachment`
3. Position: `(0, -Size.Y/2, 0)` - En bas du body

**Note:** Les Legs ont déjà TopAttachment d'après ton screenshot!

---

## 🎯 Étape 3 : Vérifier les connexions

Le système connectera automatiquement:
1. **Head.BottomAttachment** ↔ **Body.TopAttachment**
2. **Body.BottomAttachment** ↔ **Legs.TopAttachment**

### Positionnement automatique:
- Le code utilise `CFrame * Attachment.CFrame * Attachment.CFrame:Inverse()`
- Alignement parfait garanti!
- Rotation automatique

---

## ✅ Checklist de validation

### Structure générale
- [ ] Dossier `ReplicatedStorage/Assets/BodyPartTemplates` existe
- [ ] 3 sous-dossiers: HeadTemplate, BodyTemplate, LegsTemplate

### Pour chaque template:
- [ ] Model avec nom unique (ex: "brrbrr", "lalero", "patapim")
- [ ] PrimaryPart défini (root.0.1)
- [ ] Autres parts soudées au PrimaryPart avec WeldConstraints

### Attachments requis:
- [ ] **HeadTemplate/[nom]/root.0.1** → BottomAttachment
- [ ] **BodyTemplate/[nom]/root.0.1** → TopAttachment
- [ ] **BodyTemplate/[nom]/root.0.1** → BottomAttachment
- [ ] **LegsTemplate/[nom]/root.0.1** → TopAttachment (déjà fait!)

---

## 🧪 Test rapide

### Test assemblage mix & match

1. Craft un Brainrot avec 3 pièces du même set
2. Vérifier qu'il apparaît assemblé dans le slot
3. Craft un Brainrot mixte (ex: brrbrr + lalero + patapim)
4. Vérifier que les 3 pièces différentes sont assemblées via Attachments
5. Vérifier l'alignement parfait (pas de gaps)

---

## 🎨 Étape 4 : Personnalisation visuelle

### Couleurs par set (recommandé)

- **Skibidi** : Bleu / Cyan
- **Rizz** : Rose / Magenta
- **Fanum** : Vert / Lime
- **Gyatt** : Jaune / Or

### Matériaux

- **Neon** pour un effet lumineux
- **SmoothPlastic** pour un look propre
- **ForceField** pour un effet holographique

### Textures (optionnel)

- Ajouter des **Decals** ou **Textures** pour plus de détails
- Utiliser des **SurfaceAppearance** pour des textures PBR

---

## ✅ Checklist finale

### Templates (structure existante)
- [ ] Dossier `ReplicatedStorage/Assets/BodyPartTemplates` créé
- [ ] 3 sous-dossiers: HeadTemplate, BodyTemplate, LegsTemplate
- [ ] Models avec noms uniques dans chaque dossier
- [ ] PrimaryParts définis pour tous les models
- [ ] WeldConstraints pour souder les parts internes

### Attachments (à ajouter)
- [ ] **HeadTemplate**: BottomAttachment dans chaque PrimaryPart
- [ ] **BodyTemplate**: TopAttachment + BottomAttachment dans chaque PrimaryPart
- [ ] **LegsTemplate**: TopAttachment dans chaque PrimaryPart (déjà fait!)

### Exemples de templates à créer:
- [ ] HeadTemplate: brrbrr, lalelo, etc.
- [ ] BodyTemplate: lalero, pata, etc.
- [ ] LegsTemplate: patapim, tralala, etc.

---

## 🧪 Test rapide

### Test assemblage mix & match

1. Craft un Brainrot avec 3 pièces du même set (ex: Skibidi complet)
2. Vérifier qu'il apparaît assemblé dans le slot
3. Craft un Brainrot mixte (ex: Skibidi_Head + Rizz_Body + Fanum_Legs)
4. Vérifier que les 3 pièces différentes sont assemblées ensemble
5. Vérifier que seul le propriétaire voit ses Brainrots

---

## 💡 Conseils

- **Structure existante**: Tu as déjà la bonne structure! Juste ajouter 3 Attachments
- **Positionnement Attachments**: Utilise les propriétés Position dans Studio
- **Test assemblage**: Le code a un fallback si Attachments manquent
- **Mix & Match**: Le système permet toutes les combinaisons possibles!
- **Optimiser**: Limiter le nombre de Parts pour de meilleures performances
- **Cohérence**: Garder un style visuel cohérent entre tous les templates

### Exemples de combinaisons possibles:
- **Même template:** brrbrr + lalero + patapim = Brainrot mixte
- **Mix complet:** brrbrr + brrbrr + brrbrr = Set complet (bonus $1000)
- **Créativité:** Toutes les combinaisons sont possibles!

---

**Prochaine étape :** Ajouter les 3 Attachments manquants, puis tester le craft en jeu!
