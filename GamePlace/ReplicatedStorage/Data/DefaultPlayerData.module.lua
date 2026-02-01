--[[
    DefaultPlayerData.lua
    Structure par défaut des données d'un joueur
    
    Ces données sont sauvegardées dans le DataStore
    Utilisé quand un nouveau joueur rejoint pour la première fois
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))

local DefaultPlayerData = {
    -- Version pour migrations futures
    Version = 1,
    
    -- ═══════════════════════════════════════
    -- ÉCONOMIE
    -- ═══════════════════════════════════════
    Cash = GameConfig.Economy.StartingCash,  -- Argent en poche
    -- StoredCash est maintenant par slot (voir SlotCash ci-dessous)
    
    -- ═══════════════════════════════════════
    -- BASE
    -- ═══════════════════════════════════════
    OwnedSlots = GameConfig.Base.StartingSlots,  -- Nombre de slots possédés
    
    -- Brainrots placés sur les slots
    -- Format: {[slotIndex] = BrainrotData}
    -- BrainrotData = {
    --     Name = "Skibidi Rizz Fanum",      -- Nom chimérique
    --     HeadSet = "Skibidi",              -- Set de la tête
    --     BodySet = "Rizz",                 -- Set du corps
    --     LegsSet = "Fanum",                -- Set des jambes
    --     CreatedAt = 1234567890,           -- Timestamp création
    -- }
    PlacedBrainrots = {},
    
    -- Argent stocké par slot (collecté en marchant sur CollectPad)
    -- Format: {[slotIndex] = amount}
    -- Exemple: {[1] = 150, [2] = 75, [3] = 0}
    SlotCash = {},
    
    -- ═══════════════════════════════════════
    -- CODEX (Collection)
    -- ═══════════════════════════════════════
    -- Liste des pièces débloquées
    -- Format: {"SetName_PieceType", ...}
    -- Exemple: {"Skibidi_Head", "Skibidi_Body", "Rizz_Legs"}
    CodexUnlocked = {},
    
    -- Sets complétés (pour éviter de donner la récompense 2 fois)
    CompletedSets = {},
    
    -- ═══════════════════════════════════════
    -- STATISTIQUES
    -- ═══════════════════════════════════════
    Stats = {
        TotalCrafts = 0,            -- Nombre total de fusions
        TotalDeaths = 0,            -- Morts dans l'arène
        TotalCashEarned = 0,        -- Argent total gagné
        TotalPiecesCollected = 0,   -- Pièces ramassées au total
        PlayTime = 0,               -- Temps de jeu en secondes
    },
    
    -- ═══════════════════════════════════════
    -- RÉSERVÉ POUR FUTURES FEATURES
    -- ═══════════════════════════════════════
    Inventory = {},                 -- Items spéciaux
    Achievements = {},              -- Succès
    DailyData = {                   -- Données journalières
        LastLogin = 0,
        DailyStreak = 0,
    },
}

return DefaultPlayerData
