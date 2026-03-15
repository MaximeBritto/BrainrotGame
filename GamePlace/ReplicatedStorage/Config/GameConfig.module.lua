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

        -- Multiplicateur de revenus (basé sur le Codex)
        Multiplier = {
            BaseMultiplier = 1.0,           -- Multiplicateur de départ
            CodexRarityThreshold = 0.75,    -- 75% d'une rareté pour le bonus
            CodexRarityBonus = 0.5,         -- +0.5x par rareté complétée à 75%
        },
    },

    -- ═══════════════════════════════════════
    -- VITESSE DE DÉPLACEMENT
    -- ═══════════════════════════════════════
    MoveSpeed = {
        BaseSpeed = 16,                     -- Vitesse de déplacement par défaut (Roblox default)
        MaxSpeed = 100,                     -- Vitesse maximale
    },
    
    -- ═══════════════════════════════════════
    -- BASE
    -- ═══════════════════════════════════════
    Base = {
        MaxSlots = 30,                      -- Total slots (1-30)
        SlotsPerFloor = 10,                 -- Slots par étage
        StartingSlots = 10,                 -- Floor 0 : slots 1-10 débloqués par défaut. Premier achat = slot 11
        
        -- Étages débloqués automatiquement (seuils = nombre total de slots possédés)
        FloorUnlockThresholds = {
            [1] = 11,                       -- Floor_1 débloqué à 11 slots (1er achat)
            [2] = 21,                       -- Floor_2 débloqué à 21 slots
        },
    },
    
    -- ═══════════════════════════════════════
    -- PORTE
    -- ═══════════════════════════════════════
    Door = {
        CloseDuration = 30,                 -- Durée fermeture en secondes
        CooldownAfterOpen = 0,              -- Cooldown après ouverture (0 = immédiat)
        DoorOpenProductId = 3544540787,              -- Developer Product ID (à créer sur roblox.com, 80 Robux)
        DoorOpenRobux = 80,                 -- Prix en Robux pour ouvrir la porte d'un autre joueur
    },
    
    -- ═══════════════════════════════════════
    -- ARÈNE
    -- ═══════════════════════════════════════
    Arena = {
        SpawnInterval = 3,                  -- Secondes entre chaque spawn
        MaxPiecesInArena = 50,              -- Limite de pièces simultanées
        PieceLifetime = 120,                -- Secondes avant despawn auto
        SpinnerSpeed = 0.1,                 -- Tours par seconde du Spinner principal
        -- Spinners supplémentaires (dans Workspace.Arena: Spinner2, Spinner3, etc.)
        ExtraSpinners = {
            { Name = "Spinner2", Speed = 0.2 },   -- Plus rapide, placer dans Arena
            { Name = "Spinner3", Speed = 0.25 },   -- Encore plus rapide
        },
    },

    -- ═══════════════════════════════════════
    -- ZONES DE SPAWN (SpawnZone1, SpawnZone2, ...)
    -- Chaque zone a des multiplicateurs de rareté (0 = jamais, 1 = normal, >1 = boosté)
    -- Si une zone n'est pas listée ici, elle utilise DefaultZone
    -- ═══════════════════════════════════════
    SpawnZones = {
        -- Weight        = probabilité relative d'être choisie (60/20/15/5 ≈ 60%, 20%, 15%, 5%)
        -- SpawnInterval = secondes entre chaque spawn dans cette zone
        -- MaxPieces     = nombre max de pièces simultanées dans cette zone
        -- PieceLifetime = secondes avant qu'une pièce disparaisse dans cette zone
        -- KillWall :
        --   Speed       = degrés/seconde de rotation
        --   Height      = hauteur du mur (studs)
        --   WallWidth   = épaisseur du bras (studs)
        --   InnerRadius = rayon intérieur (nil = auto-détection)
        --   OuterRadius = rayon extérieur (nil = auto-détection)
        --   SweepAngle  = degrés balayés avant reset (180 pour demi-cercle)
        --   StartAngle  = angle de départ en degrés (ajuster selon orientation de la map)
        DefaultZone = { Weight = 60, SpawnInterval = 3,  MaxPieces = 40, PieceLifetime = 120, RarityWeights = { Common = 1.0, Rare = 0.0, Epic = 0.0, Legendary = 0.0 }, KillWall = { Enabled = false, Speed = 30,  Height = 30, WallWidth = 5, InnerRadius = nil, OuterRadius = nil, SweepAngle = 180, StartAngle = -90 } },
        SpawnZone1  = { Weight = 60, SpawnInterval = 3,  MaxPieces = 40, PieceLifetime = 120, RarityWeights = { Common = 1.0, Rare = 0.0, Epic = 0.0, Legendary = 0.0 }, KillWall = { Enabled = true,  Speed = 30,  Height = 5,  WallWidth = 5, InnerRadius = nil, OuterRadius = nil, SweepAngle = 180, StartAngle = -90 } },
        SpawnZone2  = { Weight = 20, SpawnInterval = 5,  MaxPieces = 20, PieceLifetime = 90,  RarityWeights = { Common = 0.0, Rare = 1.0, Epic = 0.0, Legendary = 0.0 }, KillWall = { Enabled = true,  Speed = 45,  Height = 5,  WallWidth = 5, InnerRadius = 450, OuterRadius = nil, SweepAngle = 180, StartAngle = -90 } },
        SpawnZone3  = { Weight = 15, SpawnInterval = 8,  MaxPieces = 10, PieceLifetime = 60,  RarityWeights = { Common = 0.0, Rare = 0.0, Epic = 1.0, Legendary = 0.0 }, KillWall = { Enabled = true,  Speed = 65,  Height = 5,  WallWidth = 5, InnerRadius = 320, OuterRadius = 440, SweepAngle = 180, StartAngle = -90 } },
        SpawnZone4  = { Weight =  5, SpawnInterval = 15, MaxPieces =  4, PieceLifetime = 45,  RarityWeights = { Common = 0.0, Rare = 0.0, Epic = 0.0, Legendary = 1.0 }, KillWall = { Enabled = true,  Speed = 110, Height = 5,  WallWidth = 5, InnerRadius = 0,  OuterRadius = 300, SweepAngle = 180, StartAngle = -90 } },
    },
    
    -- ═══════════════════════════════════════
    -- CANONS (tir de pièces dans l'arène)
    -- ═══════════════════════════════════════
    Cannon = {
        LaunchAngleMin = 55,                -- Angle de tir minimum (degrés)
        LaunchAngleMax = 70,                -- Angle de tir maximum (degrés)
        VelocityMin = 50,                   -- Vitesse minimale du projectile
        VelocityMax = 200,                  -- Vitesse maximale du projectile
        ProjectileSize = 3,                 -- Taille du projectile visuel
        MaxFlightTime = 10,                 -- Temps max de vol avant cleanup (secondes)
        MuzzleFlashDuration = 0.5,          -- Durée du flash au canon
        SmokeDuration = 1.0,               -- Durée de la fumée
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

    -- ═══════════════════════════════════════
    -- VENTE DE BRAINROT
    -- ═══════════════════════════════════════
    Sell = {
        HoldDuration = 1,                      -- Secondes de hold pour vendre
        PriceMultiplier = 0.6,                 -- 60% du prix d'achat des parties
    },

    -- ═══════════════════════════════════════
    -- VOL DE BRAINROT (Phase 8)
    -- ═══════════════════════════════════════
    StealDuration = 3,                      -- Secondes pour voler
    StealMaxDistance = 15,                  -- Distance max (studs)

    -- ═══════════════════════════════════════
    -- COMBAT (Phase 8)
    -- ═══════════════════════════════════════
    StunDuration = 5,                       -- Secondes d'assommage
    BatCooldown = 1,                        -- Cooldown entre 2 coups (secondes)
    BatMaxDistance = 10,                    -- Distance max pour frapper (studs)

    -- ═══════════════════════════════════════
    -- ROUE DE LA CHANCE (Spin Wheel)
    -- ═══════════════════════════════════════
    SpinWheel = {
        FreeCooldown = 86400,               -- 24h en secondes entre chaque tour gratuit
        MultiplierBoost = 2.0,              -- Multiplicateur temporaire (x2)
        MultiplierDuration = 900,           -- Durée du boost en secondes (15 min)
        Rewards = {
            { Type = "Cash",        Value = 25000,  Weight = 50, DisplayName = "$25K" },
            { Type = "Cash",        Value = 100000, Weight = 30, DisplayName = "$100K" },
            { Type = "Cash",        Value = 1000000,Weight = 5,  DisplayName = "$1M" },
            { Type = "Multiplier",  Value = 2,      Weight = 5,  DisplayName = "x2 (15 min)" },
            { Type = "LuckyBlock",  Value = 1,      Weight = 5,  DisplayName = "1 Lucky Block" },
            { Type = "Speed",       Value = 0.2,    Weight = 5,  DisplayName = "+0.2 Speed" },
        },
    },
    -- ═══════════════════════════════════════
    -- FUSION (Codex Fusion Tab)
    -- ═══════════════════════════════════════
    Fusion = {
        Milestones = {
            { Required = 3,   Type = "Cash",       Value = 500,     DisplayName = "$500" },
            { Required = 5,   Type = "Cash",       Value = 2000,    DisplayName = "$2K" },
            { Required = 8,   Type = "Speed",      Value = 0.2,     DisplayName = "+0.2 Speed" },
            { Required = 10,  Type = "Cash",       Value = 10000,   DisplayName = "$10K" },
            { Required = 15,  Type = "Cash",       Value = 25000,   DisplayName = "$25K" },
            { Required = 20,  Type = "Speed",      Value = 0.2,     DisplayName = "+0.2 Speed" },
            { Required = 25,  Type = "Cash",       Value = 50000,   DisplayName = "$50K" },
            { Required = 35,  Type = "Speed",      Value = 0.2,     DisplayName = "+0.2 Speed" },
            { Required = 40,  Type = "Multiplier", Value = 0.1,     DisplayName = "+0.1x" },
            { Required = 50,  Type = "Speed",      Value = 0.2,     DisplayName = "+0.2 Speed" },
            { Required = 60,  Type = "Cash",       Value = 250000,  DisplayName = "$250K" },
            { Required = 70,  Type = "Speed",      Value = 0.2,     DisplayName = "+0.2 Speed" },
            { Required = 80,  Type = "Cash",       Value = 500000,  DisplayName = "$500K" },
            { Required = 90,  Type = "Speed",      Value = 0.2,     DisplayName = "+0.2 Speed" },
            { Required = 100, Type = "Multiplier", Value = 0.25,    DisplayName = "+0.25x" },
            { Required = 115, Type = "Speed",      Value = 0.2,     DisplayName = "+0.2 Speed" },
            { Required = 130, Type = "Cash",       Value = 1000000, DisplayName = "$1M" },
        },
    },
}

return GameConfig
