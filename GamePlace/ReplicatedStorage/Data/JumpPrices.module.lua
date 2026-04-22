--[[
    JumpPrices.lua
    Prix pour acheter chaque niveau du multiplicateur de saut.

    Niveau 0 = défaut (x1.0, bonus 0)
    Chaque niveau ajoute +0.2x (soit +10 de JumpPower, base = 50)
    Max = niveau 8 → x2.6 (JumpPower 130 = Jump.MaxPower)

    Index = numéro du niveau à acheter, Valeur = prix en $.
    Courbe géométrique alignée sur l'économie SaB (early → endgame).
]]

local JumpPrices = {
    [1] = 500,      -- x1.2
    [2] = 1500,     -- x1.4
    [3] = 4000,     -- x1.6
    [4] = 10000,    -- x1.8
    [5] = 30000,    -- x2.0
    [6] = 80000,    -- x2.2
    [7] = 200000,   -- x2.4
    [8] = 500000,   -- x2.6 (MAX)
}

return JumpPrices
