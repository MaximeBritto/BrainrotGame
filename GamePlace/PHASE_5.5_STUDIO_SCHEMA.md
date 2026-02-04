# 📐 Schéma Studio - Structure Complète Phase 5.5

**Date:** 2026-02-04  
**Objectif:** Visualisation claire de la structure à avoir dans Roblox Studio

---

## 🗂️ Structure Complète dans ReplicatedStorage

```
ReplicatedStorage
└── 📁 Assets
    └── 📁 BodyPartTemplates
        ├── 📁 HeadTemplate
        │   ├── 🎭 brrbrr (Model)
        │   │   ├── 🧊 root.0.1 (MeshPart) ⭐ [PrimaryPart]
        │   │   │   └── 🔗 BottomAttachment (Attachment) ⚠️ À AJOUTER
        │   │   ├── 🧊 root.0.2 (MeshPart)
        │   │   │   └── 🔧 WeldConstraint → root.0.1
        │   │   ├── 🧊 root.0.3 (MeshPart)
        │   │   │   └── 🔧 WeldConstraint → root.0.1
        │   │   └── ... (autres parts)
        │   │
        │   ├── 🎭 lalelo (Model)
        │   │   └── ... (même structure)
        │   │
        │   └── 🎭 ... (autres heads)
        │
        ├── 📁 BodyTemplate
        │   ├── 🎭 lalero (Model)
        │   │   ├── 🧊 root.0.1 (MeshPart) ⭐ [PrimaryPart]
        │   │   │   ├── 🔗 TopAttachment (Attachment) ⚠️ À AJOUTER
        │   │   │   └── 🔗 BottomAttachment (Attachment) ⚠️ À AJOUTER
        │   │   ├── 🧊 root.0.2 (MeshPart)
        │   │   │   └── 🔧 WeldConstraint → root.0.1
        │   │   ├── 🧊 root.0.3 (MeshPart)
        │   │   │   └── 🔧 WeldConstraint → root.0.1
        │   │   └── ... (autres parts)
        │   │
        │   ├── 🎭 pata (Model)
        │   │   └── ... (même structure)
        │   │
        │   └── 🎭 ... (autres bodies)
        │
        └── 📁 LegsTemplate
            ├── 🎭 patapim (Model)
            │   ├── 🧊 root.0.1 (MeshPart) ⭐ [PrimaryPart]
            │   │   └── 🔗 TopAttachment (Attachment) ✅ DÉJÀ FAIT
            │   ├── 🧊 root.0.2 (MeshPart)
            │   │   └── 🔧 WeldConstraint → root.0.1
            │   ├── 🧊 root.0.3 (MeshPart)
            │   │   └── 🔧 WeldConstraint → root.0.1
            │   └── ... (autres parts)
            │
            ├── 🎭 tralala (Model)
            │   └── ... (même structure)
            │
            └── 🎭 ... (autres legs)
```

---

## 🔍 Vue Détaillée - Exemple HeadTemplate/brrbrr

```
🎭 brrbrr (Model)
│
├── Properties:
│   └── PrimaryPart = root.0.1 ⭐
│
├── 🧊 root.0.1 (MeshPart) ⭐ [PrimaryPart]
│   │
│   ├── Properties:
│   │   ├── Size: Vector3 (ex: 2, 2, 2)
│   │   ├── Position: Vector3
│   │   └── ... (autres propriétés)
│   │
│   └── 🔗 BottomAttachment (Attachment) ⚠️ À AJOUTER
│       └── Properties:
│           └── Position: Vector3(0, -Size.Y/2, 0)
│               Exemple: Si Size.Y = 2, alors Position = (0, -1, 0)
│
├── 🧊 root.0.2 (MeshPart)
│   └── 🔧 WeldConstraint
│       ├── Part0 = root.0.1
│       └── Part1 = root.0.2
│
├── 🧊 root.0.3 (MeshPart)
│   └── 🔧 WeldConstraint
│       ├── Part0 = root.0.1
│       └── Part1 = root.0.3
│
└── ... (autres parts avec WeldConstraints)
```

---

## 🔍 Vue Détaillée - Exemple BodyTemplate/lalero

```
🎭 lalero (Model)
│
├── Properties:
│   └── PrimaryPart = root.0.1 ⭐
│
├── 🧊 root.0.1 (MeshPart) ⭐ [PrimaryPart]
│   │
│   ├── Properties:
│   │   ├── Size: Vector3 (ex: 2, 3, 2)
│   │   ├── Position: Vector3
│   │   └── ... (autres propriétés)
│   │
│   ├── 🔗 TopAttachment (Attachment) ⚠️ À AJOUTER
│   │   └── Properties:
│   │       └── Position: Vector3(0, Size.Y/2, 0)
│   │           Exemple: Si Size.Y = 3, alors Position = (0, 1.5, 0)
│   │
│   └── 🔗 BottomAttachment (Attachment) ⚠️ À AJOUTER
│       └── Properties:
│           └── Position: Vector3(0, -Size.Y/2, 0)
│               Exemple: Si Size.Y = 3, alors Position = (0, -1.5, 0)
│
├── 🧊 root.0.2 (MeshPart)
│   └── 🔧 WeldConstraint
│       ├── Part0 = root.0.1
│       └── Part1 = root.0.2
│
└── ... (autres parts avec WeldConstraints)
```

---

## 🔍 Vue Détaillée - Exemple LegsTemplate/patapim

```
🎭 patapim (Model)
│
├── Properties:
│   └── PrimaryPart = root.0.1 ⭐
│
├── 🧊 root.0.1 (MeshPart) ⭐ [PrimaryPart]
│   │
│   ├── Properties:
│   │   ├── Size: Vector3 (ex: 2, 2.5, 2)
│   │   ├── Position: Vector3
│   │   └── ... (autres propriétés)
│   │
│   └── 🔗 TopAttachment (Attachment) ✅ DÉJÀ FAIT
│       └── Properties:
│           └── Position: Vector3(0, Size.Y/2, 0)
│               Exemple: Si Size.Y = 2.5, alors Position = (0, 1.25, 0)
│
├── 🧊 root.0.2 (MeshPart)
│   └── 🔧 WeldConstraint
│       ├── Part0 = root.0.1
│       └── Part1 = root.0.2
│
└── ... (autres parts avec WeldConstraints)
```

---

## 🔗 Schéma de Connexion - Assemblage Final

```
┌─────────────────────────────────────────────────────────┐
│                    BRAINROT ASSEMBLÉ                     │
└─────────────────────────────────────────────────────────┘

        🎭 HEAD (brrbrr)
        ┌─────────────────┐
        │   root.0.1      │
        │   root.0.2      │
        │   root.0.3      │
        └────────┬────────┘
                 │
                 │ 🔗 BottomAttachment
                 ↓
                 ↑ 🔗 TopAttachment
                 │
        ┌────────┴────────┐
        │   root.0.1      │ 🎭 BODY (lalero)
        │   root.0.2      │
        │   root.0.3      │
        └────────┬────────┘
                 │
                 │ 🔗 BottomAttachment
                 ↓
                 ↑ 🔗 TopAttachment
                 │
        ┌────────┴────────┐
        │   root.0.1      │ 🎭 LEGS (patapim)
        │   root.0.2      │
        │   root.0.3      │
        └─────────────────┘
```

---

## 📋 Checklist Complète

### ✅ Structure de Base (Déjà Fait)
- [x] Dossier `ReplicatedStorage/Assets/BodyPartTemplates`
- [x] Sous-dossiers: `HeadTemplate`, `BodyTemplate`, `LegsTemplate`
- [x] Models avec noms uniques (brrbrr, lalero, patapim, etc.)
- [x] PrimaryParts définis (root.0.1)
- [x] WeldConstraints pour souder les parts internes
- [x] TopAttachment dans LegsTemplate

### ⚠️ À Ajouter (3 Attachments)

#### HeadTemplate - Pour CHAQUE Model (brrbrr, lalelo, etc.)
- [ ] Sélectionner `root.0.1` (PrimaryPart)
- [ ] Clic droit → Insert Object → **Attachment**
- [ ] Renommer en `BottomAttachment`
- [ ] Position: `(0, -Size.Y/2, 0)`

#### BodyTemplate - Pour CHAQUE Model (lalero, pata, etc.)
- [ ] Sélectionner `root.0.1` (PrimaryPart)
- [ ] Clic droit → Insert Object → **Attachment**
- [ ] Renommer en `TopAttachment`
- [ ] Position: `(0, Size.Y/2, 0)`
- [ ] Clic droit → Insert Object → **Attachment** (2ème)
- [ ] Renommer en `BottomAttachment`
- [ ] Position: `(0, -Size.Y/2, 0)`

---

## 🎯 Exemple Concret - Calcul Position

### Si ton Body (lalero) a une Size de (2, 3, 2):

**TopAttachment:**
- Position X: 0
- Position Y: 3 / 2 = **1.5**
- Position Z: 0
- **Résultat: (0, 1.5, 0)**

**BottomAttachment:**
- Position X: 0
- Position Y: -3 / 2 = **-1.5**
- Position Z: 0
- **Résultat: (0, -1.5, 0)**

---

## 🧪 Test Visuel dans Studio

### Comment vérifier que c'est bon:

1. **Sélectionner un Model** (ex: brrbrr)
2. **Vérifier PrimaryPart** est défini
3. **Ouvrir le PrimaryPart** (root.0.1)
4. **Chercher les Attachments** requis
5. **Vérifier Position** des Attachments

### Attachments visibles:
- Les Attachments apparaissent comme des petites **croix bleues** dans Studio
- Position doit être au **centre haut** (TopAttachment) ou **centre bas** (BottomAttachment)

---

## 💡 Astuces Studio

### Créer un Attachment:
1. Sélectionner le PrimaryPart (root.0.1)
2. Clic droit dans l'Explorer
3. Insert Object → Attachment
4. Renommer (TopAttachment ou BottomAttachment)
5. Ajuster Position dans Properties

### Calculer Position rapidement:
- **Top**: Regarder Size.Y du part, diviser par 2
- **Bottom**: Même chose mais négatif
- Exemple: Size.Y = 4 → Top = 2, Bottom = -2

### Copier-Coller:
- Tu peux copier un Attachment d'un Model à l'autre
- Juste vérifier que la Position est correcte pour chaque Size

---

## 🚀 Résultat Final

Une fois les 3 Attachments ajoutés, le code assemblera automatiquement:

```
brrbrr (Head) + lalero (Body) + patapim (Legs)
         ↓
   Brainrot parfaitement aligné dans le slot!
```

**Alignement garanti par les Attachments!**

---

**Prochaine étape:** Ajouter les 3 Attachments, puis tester le craft en jeu!
