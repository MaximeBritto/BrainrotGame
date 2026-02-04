--[[
    SlotPrices.lua
    Prix pour acheter chaque slot de la base
    
    Slots 1-10 = Floor 0, débloqués par défaut (non achetables).
    Premier slot à acheter = 11. Index = numéro du slot, Valeur = prix en $.
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
    -- À partir du slot 11 = premier achat, puis Floor 1
    [11] = 1000,    -- Premier slot achetable, débloque Floor_1
    [12] = 1200,
    [13] = 1400,
    [14] = 1650,
    [15] = 1900,
    [16] = 2200,
    [17] = 2500,
    [18] = 2850,
    [19] = 3200,
    [20] = 3600,    -- Fin 1er étage
    [21] = 4000,    -- Début 2ème étage
    [22] = 4500,
    [23] = 5000,
    [24] = 5600,
    [25] = 6200,
    [26] = 6900,
    [27] = 7600,
    [28] = 8400,
    [29] = 9200,
    [30] = 10000,   -- Dernier slot
}

return SlotPrices
