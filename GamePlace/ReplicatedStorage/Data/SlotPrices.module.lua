--[[
    SlotPrices.lua
    Prix pour acheter chaque slot de la base

    Slots 1-10 = Floor 0, débloqués par défaut (non achetables).
    Premier slot à acheter = 11. Index = numéro du slot, Valeur = prix en $.

    Courbe géométrique alignée sur l'économie SaB :
    - Floor 1 (11-20) : 500$ → 15k$   (nécessite commons/rares placés)
    - Floor 2 (21-30) : 30k$ → 500k$  (nécessite epics/legendaries placés)

    Dernier slot = 500k$ ≈ 1.5 Legendary mid-tier (feel "endgame" SaB).
]]

local SlotPrices = {
    -- Floor 0 (slots 1-10) : donnés au départ, pas d'achat
    [1] = 0,
    [2] = 0,
    [3] = 0,
    [4] = 0,
    [5] = 0,
    [6] = 0,
    [7] = 0,
    [8] = 0,
    [9] = 0,
    [10] = 0,
    -- Floor 1 (slots 11-20) : achats commons/rares
    [11] = 500,
    [12] = 750,
    [13] = 1100,
    [14] = 1600,
    [15] = 2300,
    [16] = 3300,
    [17] = 4800,
    [18] = 7000,
    [19] = 10000,
    [20] = 15000,
    -- Floor 2 (slots 21-30) : achats epics/legendaries
    [21] = 30000,
    [22] = 42000,
    [23] = 58000,
    [24] = 80000,
    [25] = 110000,
    [26] = 150000,
    [27] = 210000,
    [28] = 290000,
    [29] = 400000,
    [30] = 500000,
}

return SlotPrices
