# Méthodologie d'équilibrage — Steal a Brainrot clone

Ce document décrit les règles d'équilibrage économique du jeu. À consulter avant
d'ajouter un nouveau Brainrot, de toucher à `BrainrotData.module.lua`,
`SlotPrices.module.lua`, ou `GameConfig.module.lua`.

## 1. Philosophie

**Objectif** : expérience style *Steal a Brainrot* — premières heures attractives,
rétention long terme avec retours quotidiens.

**Principe cardinal** :

> **1 Brainrot crafté ici (H + B + L sommés) = 1 Brainrot SaB**

Cela signifie que la valeur d'un Brainrot SaB (prix pour l'acheter / revenu $/s)
doit être égale au **total des 3 pièces** côté code (somme de `Price` et de
`GainPerSec` entre Head, Body, Legs).

Les pièces individuelles valent donc environ **1/3** de la valeur SaB du
Brainrot équivalent.

## 2. Grille par rareté

Aligné sur les valeurs SaB (voir wiki : https://stealabrainrot.fandom.com/wiki/Brainrots).

| Rareté    | Total craft prix | Total craft GPS | ROI cible | Nb de tiers |
|-----------|------------------|-----------------|-----------|-------------|
| Common    | 30$ → 1700$      | 2 → 14 /s       | ~110-130s | 11          |
| Rare      | 2 000$ → 9 700$  | 15 → 75 /s      | ~130s     | 6           |
| Epic      | 10k$ → 47.5k$    | 75 → 325 /s     | ~140s     | 13          |
| Legendary | 35k$ → 347k$     | 200 → 1 900 /s  | ~175-185s | 10          |

**Règle ROI** : `prix_total / GPS_total` doit rester dans la fourchette cible.
Un ROI trop court (< 60s) ruine la rétention. Un ROI trop long (> 240s)
décourage l'achat.

## 3. Répartition H / B / L

Pour un set 3 pièces, distribuer la valeur totale du tier approximativement ainsi :

- Head  : ~35 %
- Body  : ~37 %
- Legs  : ~28 %

Les pièces 2-pièces (set avec H+L ou H+B seulement) gardent **le même total** que
les autres sets du même tier — la valeur absente est reportée sur les 2 pièces
présentes (~50 % chacune).

## 4. SpawnWeight

Varie **au sein d'une rareté** pour créer de la scarcity :

- Tier 1 (entrée de rareté)      : SpawnWeight élevé (20-25)
- Tier médian                    : SpawnWeight moyen (10-15)
- Tier final (top de rareté)     : SpawnWeight bas (2-5)

Un set incomplet (Body placeholder) garde `SpawnWeight = 0` sur la pièce absente.

## 5. Zones d'arène (`GameConfig.SpawnZones`)

**Chaque zone tourne sa propre boucle** (indépendante) à son `SpawnInterval`.
Le champ `Weight` par zone est **dead code en gameplay normal** (uniquement
utilisé par la fonction debug `SpawnRandomPiece`).

**Zones additives** : chaque zone inclut sa rareté *spécialité* (poids 1.0) et
les raretés inférieures en filler (poids décroissants).

| Zone       | Interval | MaxPieces | Lifetime | Common | Rare | Epic | Legendary | Spécialité |
|------------|----------|-----------|----------|--------|------|------|-----------|------------|
| SpawnZone1 | 3s       | 40        | 90s      | 1.0    | 0.0  | 0.0  | 0.0       | Common     |
| SpawnZone2 | 6s       | 15        | 60s      | 0.5    | 1.0  | 0.0  | 0.0       | Rare       |
| SpawnZone3 | 15s      | 6         | 45s      | 0.2    | 0.5  | 1.0  | 0.0       | Epic       |
| SpawnZone4 | 60s      | 2         | 30s      | 0.1    | 0.2  | 0.5  | 1.0       | Legendary  |

Poids effectif d'une pièce dans une zone = `piece.SpawnWeight × zone.RarityWeights[piece.rarity]`.

**Distributions approximatives** (avec grille SpawnWeight actuelle) :
- Zone 2 : ~50 % Common, ~50 % Rare
- Zone 3 : ~16 % Common, ~20 % Rare, ~64 % Epic
- Zone 4 : ~8 % Common, ~8 % Rare, ~34 % Epic, ~50 % Legendary

**Invariant** : la rareté Legendary doit rester un *événement*. Lifetime court +
spawn rare (60s) + max faible (2) → tension PvP, tout le serveur se précipite
sur un Legendary qui apparaît en Zone 4.

## 6. Courbe de slots (`SlotPrices.module.lua`)

Courbe géométrique pour pousser le joueur à progresser en rareté avant d'acheter.

- **Floor 0** (1-10) : gratuits, remplis de Commons en session 1
- **Floor 1** (11-20) : 500$ → 15 000$, déblocage avec Commons mid-tier + Rares
- **Floor 2** (21-30) : 30 000$ → 500 000$, déblocage avec Epics + Legendaries

Dernier slot = ~1.5× un Legendary mid-tier → feel endgame.

## 7. Bonus de complétion de set (`GameConfig.Economy.SetCompletionBonus`)

Table par rareté — bonus ≈ coût d'un craft du tier, soit une « craft gratuite » :

```lua
Common    = 500
Rare      = 5000
Epic      = 25000
Legendary = 150000
```

Appliqué uniquement quand H+B+L viennent du **même set**. Lookup dans
`CraftingSystem.module.lua` via `BrainrotData.Sets[setName].Rarity`.

## 8. Multiplicateur Codex

Défini dans `GameConfig.Economy.Multiplier` :
- Base    : ×1.0
- +0.5× à chaque rareté dont ≥ 75 % des sets sont découverts
- 4 raretés → max ×3.0 via Codex uniquement

Cumulé avec `TemporaryMultiplier` (Spin Wheel, Shop Boost) et
`PermanentMultiplierBonus` (Fusion milestones).

## 9. Ajouter un nouveau Brainrot

1. Choisir sa **rareté** (fréquence de drop souhaitée)
2. Choisir son **tier dans la rareté** — détermine prix/GPS total (voir grille §2)
3. Calculer `prix_total` et `GPS_total` pour le tier, en géométrique entre min et max
4. Répartir sur H / B / L selon §3
5. Attribuer un `SpawnWeight` selon §4
6. Vérifier que le **ROI reste dans la fourchette** de la rareté

## 10. Invariants à ne PAS casser

- **ROI monotone** : ROI d'un tier supérieur ≥ ROI du tier inférieur, sinon le
  joueur n'a pas intérêt à progresser
- **Continuité entre raretés** : top-tier Common (14 GPS) < entry Rare (15 GPS).
  Idem Rare→Epic, Epic→Legendary. Pas de "trou" ni de chevauchement inversé
- **Total craft = valeur SaB** — si on rebalance, on relit le wiki
- **Legendary reste rare** : si on touche à SpawnZone4, ne jamais dépasser
  `MaxPieces = 3` ou `SpawnInterval < 45s`
- **Slot 30 > revenu horaire d'un setup Epic** : force le joueur à pousser
  vers Legendary pour terminer la base

## 11. Récompenses Fusion (`GameConfig.Fusion.Milestones`)

Fusions = combinaisons uniques H+B+L découvertes par le joueur. Récompenses
calibrées pour représenter **~1-3 min de revenu** au moment du déblocage.

| Palier | Récompense | Équivalent économique                     |
|--------|------------|-------------------------------------------|
| 3      | $2K        | ~1 min early game (40$/s)                 |
| 5      | $5K        | ~2 min early                              |
| 10     | $15K       | Acheter 1 Rare mid-tier                   |
| 15     | $35K       | Floor 2 débloqué (slot 21)                |
| 25     | $75K       | ~1 Epic low-tier                          |
| 60     | $500K      | 1 Legendary tier 1 + slot 30              |
| 80     | $1.5M      | ~5 Legendaries mid-tier                   |
| 130    | $5M        | Catalyseur endgame                        |

Récompenses **Speed** (+0.2) et **Multiplier** (+0.1x, +0.25x) restent
inchangées — ce sont des stats permanentes, pas du cash scale.

## 12. Roue de la chance (`GameConfig.SpinWheel.Rewards`)

1 tour gratuit / 24h. Paliers de cash couvrent tout le spectre pour rester
pertinents du tout début à l'endgame.

| Récompense   | Weight | Probabilité | Contexte                        |
|--------------|--------|-------------|---------------------------------|
| $10K         | 40     | 40 %        | early game burst                |
| $100K        | 25     | 25 %        | mid game (Epic low-tier)        |
| $1M          | 10     | 10 %        | late game (3× Legendary tier 1) |
| $10M         | 2      | 2 %         | jackpot endgame                 |
| x2 (15 min)  | 10     | 10 %        | toujours utile                  |
| 1 LuckyBlock | 8      | 8 %         | toujours utile                  |
| +0.2 Speed   | 5      | 5 %         | permanent                       |

Espérance de cash par spin ≈ $565K. Speed bonus (permanent) = 5% * 0.2 =
+0.01 WalkSpeed par spin en moyenne — lent mais existant.

## 13. Leviers de rétention (par priorité)

1. **Scarcity des Legendaries** : SpawnZone4 tight
2. **Codex multiplicateur** : +0.5× par rareté 75% complétée → chasse aux sets
3. **Fusion milestones** : récompenses cumulatives sur découvertes uniques
4. **Daily Spin Wheel** : cooldown 24h → retour quotidien
5. **Steal/PvP** : pression sociale sur les bases adverses
6. **Slot 30** : objectif long terme chiffré
