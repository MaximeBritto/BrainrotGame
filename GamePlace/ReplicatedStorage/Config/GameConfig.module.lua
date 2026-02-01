--[[
    GameConfig.lua
    Configuration centrale du jeu - Toutes les constantes gameplay
    
    ATTENTION: Modifier ces valeurs affecte l'équilibrage du jeu
]]

local GameConfig = {
    -- ═══════════════════════════════════════
    -- ÉCONOMIE
    -- ═══════════════════════════════════════
    Economy = {
        StartingCash = 100,                 -- Argent de départ nouveau joueur
        RevenuePerBrainrot = 5,             -- $ par seconde par Brainrot placé
        RevenueTickRate = 1,                -- Intervalle en secondes
        SetCompletionBonus = 1000,          -- Bonus pour compléter un set
    },
    
    -- ═══════════════════════════════════════
    -- BASE
    -- ═══════════════════════════════════════
    Base = {
        MaxSlots = 30,                      -- Maximum de slots achetables
        SlotsPerFloor = 10,                 -- Slots par étage
        StartingSlots = 1,                  -- Slots au départ
        
        -- Étages débloqués automatiquement
        FloorUnlockThresholds = {
            [1] = 11,                       -- Floor_1 à 11 slots
            [2] = 21,                       -- Floor_2 à 21 slots
        },
    },
    
    -- ═══════════════════════════════════════
    -- PORTE
    -- ═══════════════════════════════════════
    Door = {
        CloseDuration = 30,                 -- Durée fermeture en secondes
        CooldownAfterOpen = 0,              -- Cooldown après ouverture (0 = immédiat)
    },
    
    -- ═══════════════════════════════════════
    -- ARÈNE
    -- ═══════════════════════════════════════
    Arena = {
        SpawnInterval = 3,                  -- Secondes entre chaque spawn
        MaxPiecesInArena = 50,              -- Limite de pièces simultanées
        PieceLifetime = 120,                -- Secondes avant despawn auto
        SpinnerSpeed = 2,                   -- Tours par seconde
    },
    
    -- ═══════════════════════════════════════
    -- INVENTAIRE JOUEUR (pièces en main)
    -- ═══════════════════════════════════════
    Inventory = {
        MaxPiecesInHand = 3,                -- Maximum de pièces portables
    },
    
    -- ═══════════════════════════════════════
    -- DATASTORE
    -- ═══════════════════════════════════════
    DataStore = {
        Name = "BrainrotGameData_v1",       -- Nom du DataStore
        AutoSaveInterval = 60,              -- Secondes entre auto-saves
        RetryAttempts = 3,                  -- Tentatives en cas d'échec
        RetryDelay = 2,                     -- Secondes entre tentatives
    },
}

return GameConfig
