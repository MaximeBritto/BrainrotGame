--[[
    BrainrotData.lua
    Registry de tous les sets de Brainrots et leurs pièces
    
    Pour ajouter un nouveau set, copier un bloc existant et modifier les valeurs
]]

local BrainrotData = {
    -- ═══════════════════════════════════════
    -- SETS DE BRAINROTS
    -- ═══════════════════════════════════════
    Sets = {
        ["brrbrrPatapim"] = {
            Rarity = "Common",
            Head = {
                Price = 50,
                DisplayName = "Brr Brr",
                ModelName = "brrbrrPatapim_Head",
                TemplateName = "brrbrr",  -- Template dans HeadTemplate folder
                SpawnWeight = 10,
            },
            Body = {
                Price = 75,
                DisplayName = "Brr Brr Body",
                ModelName = "brrbrrPatapim_Body",
                TemplateName = "",  -- Pas de template pour l'instant
                SpawnWeight = 0,  -- Pas de body pour l'instant
            },
            Legs = {
                Price = 60,
                DisplayName = "Pata Pim",
                ModelName = "brrbrrPatapim_Legs",
                TemplateName = "patapim",  -- Template dans LegsTemplate folder
                SpawnWeight = 10,
            },
        },
        
        ["TralaleroTralala"] = {
            Rarity = "Common",
            Head = {
                Price = 80,
                DisplayName = "Tra La La Head",
                ModelName = "TralaleroTralala_Head",
                TemplateName = "",  -- Pas de template pour l'instant
                SpawnWeight = 0,  -- Pas de head pour l'instant
            },
            Body = {
                Price = 100,
                DisplayName = "La Le Ro",
                ModelName = "TralaleroTralala_Body",
                TemplateName = "lalero",  -- Template dans BodyTemplate folder
                SpawnWeight = 10,
            },
            Legs = {
                Price = 90,
                DisplayName = "Tra La La Legs",
                ModelName = "TralaleroTralala_Legs",
                TemplateName = "",  -- Pas de template pour l'instant
                SpawnWeight = 0,  -- Pas de legs pour l'instant
            },
        },
    },
    
    -- ═══════════════════════════════════════
    -- RARETÉS
    -- ═══════════════════════════════════════
    Rarities = {
        Common = {
            Color = Color3.fromRGB(255, 255, 255),  -- Blanc
            BonusMultiplier = 1,
            DisplayOrder = 1,
        },
        Rare = {
            Color = Color3.fromRGB(0, 112, 221),    -- Bleu
            BonusMultiplier = 2,
            DisplayOrder = 2,
        },
        Epic = {
            Color = Color3.fromRGB(163, 53, 238),   -- Violet
            BonusMultiplier = 5,
            DisplayOrder = 3,
        },
        Legendary = {
            Color = Color3.fromRGB(255, 185, 0),    -- Or
            BonusMultiplier = 10,
            DisplayOrder = 4,
        },
    },
    
    -- ═══════════════════════════════════════
    -- TYPES DE PIÈCES
    -- ═══════════════════════════════════════
    PieceTypes = {"Head", "Body", "Legs"},
}

return BrainrotData
